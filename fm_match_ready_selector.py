#!/usr/bin/env python3
"""
FM26 Match-Ready Lineup Selector
Advanced lineup selection considering match sharpness, physical condition,
fatigue, positional skill ratings, and match scheduling for intelligent rotation.

Author: Doug Mason (2025)
"""

import sys
import json
import pandas as pd
import numpy as np
from scipy.optimize import linear_sum_assignment
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional
from unidecode import unidecode

# Minimum positional familiarity required to be considered for a position
# 12 = "Competent" level (10% familiarity penalty)
# Players below this threshold will not be selected regardless of other bonuses
MIN_POSITION_FAMILIARITY = 12


def normalize_name(name):
    """Normalize player names for consistent string comparison.

    Uses ASCII transliteration to handle accented characters (e.g., Jose -> Jose).
    This eliminates all Unicode encoding ambiguity between CSV files and UI input.
    """
    if not name:
        return ''
    return unidecode(str(name)).lower().strip()


class MatchReadySelector:
    """
    FM26 Match-Ready Lineup Selector with Unity Engine Research Integration.

    Intelligent team selector that factors in player condition, fatigue,
    match sharpness, and fixture scheduling for optimal rotation.

    FM26 Unity Engine Enhancements (lineup-depth-strategy.md):
    =========================================================

    1. HIGH-ATTRITION ZONE MODELING:
       - Wing-backs (DL, DR) reclassified as highest attrition (equal to DMs)
       - Position-specific fatigue multipliers: WB/DM 1.2x, Attack 1.1x, CB/GK 1.0x

    2. POSITION-SPECIFIC ROTATION THRESHOLDS:
       - Wing-backs/DMs: Rotate after 2-3 consecutive matches
       - Attackers/Midfielders: Rotate after 3-4 consecutive matches
       - Center-backs/GK: Can sustain 5-6 consecutive matches

    3. INJURY RISK INTEGRATION:
       - Injury Proneness attribute integrated into fatigue thresholds
       - High proneness (15+): -100 to threshold (very fragile)
       - Low proneness (≤8): +50 to threshold (can handle higher load)

    4. 85% CONDITION FLOOR ENFORCEMENT:
       - FM26 Unity Engine: Exponential injury risk below 85% condition
       - High importance matches: 0.20x penalty (near-prohibition)
       - Medium importance: 0.50x penalty
       - Low importance: 0.70x penalty

    5. UNIVERSALIST/VERSATILITY BONUSES:
       - 3+ competent positions (15+ rating): 1.05x bonus (Tier 3 value)
       - 2 competent positions: 1.03x bonus
       - Rewards squad depth flexibility per 25+3 model

    6. STRATEGIC PATHWAY DETECTION:
       - Winger→Wing-Back: Young wingers (AMR/AML) with work rate → DL/DR (1.04x)
       - Aging AMC→DM: Playmakers losing pace with elite mentals → DM (1.03x)
       - Aligns with most efficient retraining pathways

    7. PERSONALIZED FATIGUE THRESHOLDS:
       - Base: 400, adjusted for age/natural fitness/stamina/injury proneness
       - Veterans (32+): 300, Aging (30-32): 350, Youth (<19): 350
       - Natural Fitness/Stamina/Injury Proneness modifiers: -100 to +50

    Usage:
        selector = MatchReadySelector('players-current.csv')
        selection = selector.select_optimal_xi(match_importance='High')
    """

    def __init__(self, status_filepath: str, abilities_filepath: Optional[str] = None,
                 training_recommendations_filepath: Optional[str] = None):
        """
        Initialize the selector with player data.

        Args:
            status_filepath: Path to CSV with positional skill ratings & status (players-current.csv)
            abilities_filepath: Optional path to CSV with role ability ratings
            training_recommendations_filepath: Optional path to CSV with training recommendations
        """
        # Load status/attributes file (players-current.csv)
        if status_filepath.endswith('.csv'):
            self.status_df = pd.read_csv(status_filepath, encoding='utf-8-sig')
        else:
            self.status_df = pd.read_excel(status_filepath)

        self.status_df.columns = self.status_df.columns.str.strip()

        # Normalize column names - FM exports use "Condition (%)" but we use "Condition"
        if 'Condition (%)' in self.status_df.columns:
            self.status_df.rename(columns={'Condition (%)': 'Condition'}, inplace=True)

        # Load abilities file if provided
        self.has_abilities = False
        if abilities_filepath:
            if abilities_filepath.endswith('.csv'):
                self.abilities_df = pd.read_csv(abilities_filepath, encoding='utf-8-sig')
            else:
                self.abilities_df = pd.read_excel(abilities_filepath)

            self.abilities_df.columns = self.abilities_df.columns.str.strip()

            # Check if abilities file has the required role ability columns
            required_cols = ['Name', 'Striker', 'AM(L)', 'AM(C)', 'AM(R)',
                           'DM(L)', 'DM(R)', 'D(C)', 'D(R/L)', 'GK']
            if all(col in self.abilities_df.columns for col in required_cols):
                # Merge on player name
                self.df = pd.merge(
                    self.status_df,
                    self.abilities_df[required_cols],
                    on='Name',
                    how='left',
                    suffixes=('_skill', '_ability')
                )
                self.has_abilities = True
                print(f"Loaded {len(self.df)} players with role abilities")
            else:
                print("\nWARNING: Abilities file missing required columns. Using status file only.")
                self.df = self.status_df.copy()
        else:
            self.df = self.status_df.copy()
            print("\nWARNING: No role abilities file provided. Selection based only on familiarity.")
            print("For best results, provide an abilities file as the second argument.\n")

        # Convert numeric columns
        numeric_columns = [
            'Age', 'CA', 'PA', 'Condition', 'Fatigue', 'Match Sharpness',
            'Natural Fitness', 'Stamina', 'Work Rate', 'Injury Proneness',
            'GoalKeeper', 'Defender Right', 'Defender Center', 'Defender Left',
            'Defensive Midfielder', 'Attacking Mid. Right', 'Attacking Mid. Center',
            'Attacking Mid. Left', 'Striker'
        ]

        # Add role ability columns if they exist (check both original and suffixed names)
        ability_columns_base = ['Striker', 'AM(L)', 'AM(C)', 'AM(R)', 'DM(L)', 'DM(R)',
                               'D(C)', 'D(R/L)', 'GK']
        for col in ability_columns_base:
            if col in self.df.columns:
                numeric_columns.append(col)
            if f'{col}_ability' in self.df.columns:
                numeric_columns.append(f'{col}_ability')
            if f'{col}_skill' in self.df.columns:
                numeric_columns.append(f'{col}_skill')

        for col in numeric_columns:
            if col in self.df.columns:
                self.df[col] = pd.to_numeric(self.df[col], errors='coerce')

        # Add normalized name column for efficient Unicode-safe comparisons
        self.df['Name_Normalized'] = self.df['Name'].apply(normalize_name)

        # Formation for 4-2-3-1
        # Format: (pos_name, skill_rating_column, ability_rating_column or None)
        # Note: DM(L) and DM(R) use separate ability columns since they have different tactical roles
        if self.has_abilities:
            self.formation = [
                ('GK', 'GoalKeeper', 'GK_ability'),
                ('DL', 'Defender Left', 'D(R/L)_ability'),
                ('DC1', 'Defender Center', 'D(C)_ability'),
                ('DC2', 'Defender Center', 'D(C)_ability'),
                ('DR', 'Defender Right', 'D(R/L)_ability'),
                ('DM(L)', 'Defensive Midfielder', 'DM(L)_ability'),
                ('DM(R)', 'Defensive Midfielder', 'DM(R)_ability'),
                ('AML', 'Attacking Mid. Left', 'AM(L)_ability'),
                ('AMC', 'Attacking Mid. Center', 'AM(C)_ability'),
                ('AMR', 'Attacking Mid. Right', 'AM(R)_ability'),
                ('STC', 'Striker_Familiarity', 'Striker_ability')
            ]
        else:
            self.formation = [
                ('GK', 'GoalKeeper', None),
                ('DL', 'Defender Left', None),
                ('DC1', 'Defender Center', None),
                ('DC2', 'Defender Center', None),
                ('DR', 'Defender Right', None),
                ('DM(L)', 'Defensive Midfielder', None),
                ('DM(R)', 'Defensive Midfielder', None),
                ('AML', 'Attacking Mid. Left', None),
                ('AMC', 'Attacking Mid. Center', None),
                ('AMR', 'Attacking Mid. Right', None),
                ('STC', 'Striker', None)
            ]

        # Load training recommendations if provided
        self.training_recommendations = {}
        if training_recommendations_filepath:
            try:
                training_df = pd.read_csv(training_recommendations_filepath, encoding='utf-8-sig')
                # Convert numeric columns
                if 'Current_Skill_Rating' in training_df.columns:
                    training_df['Current_Skill_Rating'] = pd.to_numeric(training_df['Current_Skill_Rating'], errors='coerce')
                if 'Training_Score' in training_df.columns:
                    training_df['Training_Score'] = pd.to_numeric(training_df['Training_Score'], errors='coerce')

                # Create lookup dictionary
                for idx, row in training_df.iterrows():
                    self.training_recommendations[row['Player']] = {
                        'position': row['Position'],
                        'priority': row['Priority'],
                        'skill_rating': row.get('Current_Skill_Rating', 0),
                        'ability_tier': row.get('Ability_Tier', 'Unknown'),
                        'training_score': row.get('Training_Score', 0)
                    }
                print(f"Loaded {len(self.training_recommendations)} training recommendations")
            except FileNotFoundError:
                print(f"Training recommendations file not found: {training_recommendations_filepath}")
            except Exception as e:
                print(f"Error loading training recommendations: {str(e)}")

        # Store selections for multiple matches
        self.match_selections = []

        # Cache for player hierarchy (position-specific rankings)
        self._player_hierarchy_cache = None

        # Load persistent match tracking from JSON file
        tracking_data = self._load_match_tracking()
        self.player_match_count = tracking_data.get('match_counts', {})
        self.last_match_counted = tracking_data.get('last_match_date', None)

        # Print status if data was loaded
        if self.last_match_counted:
            player_count = len([c for c in self.player_match_count.values() if c > 0])
            print(f"Loaded match tracking: Last match counted was {self.last_match_counted} ({player_count} players with active streaks)")

    def _calculate_pure_ability_rating(self, row: pd.Series, skill_col: str,
                                        ability_col: Optional[str] = None) -> float:
        """
        Calculate pure ability rating with familiarity penalty under ideal conditions.

        Used for hierarchy calculation (Starting XI / Second XI rankings).
        Assumes peak fitness/condition but applies familiarity penalty.

        NOTE: Injured players ARE included - this is for squad planning under ideal
        conditions, not match-day selection. Injuries are temporary.

        Args:
            row: Player data row
            skill_col: Positional skill rating column (1-20 familiarity)
            ability_col: Role ability rating column (0-200 quality)

        Returns:
            Effective ability rating (with familiarity penalty), or -999.0 if cannot play
        """
        # Get skill rating (familiarity) - required for position eligibility
        skill_rating = row.get(skill_col, 0)
        if pd.isna(skill_rating) or skill_rating < 1:
            return -999.0  # Cannot play this position at all

        # Check if below minimum familiarity threshold (12 = Competent)
        below_threshold = skill_rating < MIN_POSITION_FAMILIARITY

        # Get ability rating if available (keep full scale ~50-200)
        if ability_col and ability_col in row.index:
            ability_rating = row.get(ability_col, 0)
            if pd.notna(ability_rating) and ability_rating > 0:
                base_rating = float(ability_rating)
            else:
                # Fallback: scale familiarity to approximate ability range
                base_rating = float(skill_rating) * 5.0
        else:
            # Fallback: scale familiarity to approximate ability range
            base_rating = float(skill_rating) * 5.0

        # Apply familiarity penalty based on skill rating and Versatility
        versatility = row.get('Versatility', 10)
        familiarity_penalty = self._get_familiarity_penalty(skill_rating, versatility)
        effective_rating = base_rating * (1 - familiarity_penalty)

        # Apply heavy penalty for players below minimum familiarity threshold
        if below_threshold:
            effective_rating *= 0.30  # 70% penalty

        return effective_rating

    def _calculate_player_hierarchy(self) -> Dict[str, Dict[str, Tuple[str, float]]]:
        """
        Calculate Starting XI and Second XI for each position under ideal conditions.

        Uses Hungarian algorithm to ensure player exclusivity:
        - First run: Select optimal First XI (11 unique players)
        - Second run: Exclude First XI, select optimal Second XI (11 different players)

        This gives us the "theoretical best" lineup assuming everyone is at peak
        fitness with no penalties for fatigue, condition, sharpness, rotation,
        training, or any other factors.

        NOTE: Injured players ARE included - this is for squad planning under ideal
        conditions, not match-day selection. Injuries are temporary.

        Returns:
            Dict mapping position_name -> {
                'starting': (player_name, rating),
                'second': (player_name, rating)
            }
        """
        if self._player_hierarchy_cache is not None:
            return self._player_hierarchy_cache

        # Include ALL players (including injured) - this is for squad planning
        available_df = self.df.copy()
        available_df = available_df.reset_index(drop=True)

        n_players = len(available_df)
        n_positions = len(self.formation)

        # === FIRST XI SELECTION ===
        # Create cost matrix for pure ability ratings
        cost_matrix = np.full((n_players, n_positions), 999.0)

        for i in range(n_players):
            player = available_df.iloc[i]

            for j, pos_info in enumerate(self.formation):
                if len(pos_info) == 3:
                    pos_name, skill_col, ability_col = pos_info
                else:
                    pos_name, skill_col = pos_info
                    ability_col = None

                # Calculate pure ability rating (no modifiers)
                rating = self._calculate_pure_ability_rating(player, skill_col, ability_col)

                if rating > -999.0:
                    cost_matrix[i, j] = -rating  # Negative for minimization

        # Run Hungarian algorithm for First XI
        row_ind_first, col_ind_first = linear_sum_assignment(cost_matrix)

        # Build First XI selection
        first_xi = {}  # position -> (player_name, rating)
        first_xi_player_indices = set()

        for i, j in zip(row_ind_first, col_ind_first):
            if cost_matrix[i, j] < 900:  # Valid assignment
                pos_name = self.formation[j][0]
                player_name = available_df.iloc[i]['Name']
                rating = -cost_matrix[i, j]
                first_xi[pos_name] = (player_name, rating)
                first_xi_player_indices.add(i)

        # === SECOND XI SELECTION ===
        # Exclude First XI players from cost matrix
        cost_matrix_second = cost_matrix.copy()
        for i in first_xi_player_indices:
            cost_matrix_second[i, :] = 999.0  # Make First XI players unavailable

        # Run Hungarian algorithm for Second XI
        row_ind_second, col_ind_second = linear_sum_assignment(cost_matrix_second)

        # Build Second XI selection
        second_xi = {}  # position -> (player_name, rating)

        for i, j in zip(row_ind_second, col_ind_second):
            if cost_matrix_second[i, j] < 900:  # Valid assignment
                pos_name = self.formation[j][0]
                player_name = available_df.iloc[i]['Name']
                rating = -cost_matrix_second[i, j]
                second_xi[pos_name] = (player_name, rating)

        # === BUILD HIERARCHY STRUCTURE ===
        hierarchy = {}
        for pos_info in self.formation:
            pos_name = pos_info[0]
            hierarchy[pos_name] = {
                'starting': first_xi.get(pos_name, (None, 0)),
                'second': second_xi.get(pos_name, (None, 0))
            }

        self._player_hierarchy_cache = hierarchy
        return hierarchy

    def _get_first_xi_players(self) -> set:
        """Get set of player names in the First XI."""
        hierarchy = self._calculate_player_hierarchy()
        return {data['starting'][0] for data in hierarchy.values() if data['starting'][0]}

    def _get_second_xi_players(self) -> set:
        """Get set of player names in the Second XI."""
        hierarchy = self._calculate_player_hierarchy()
        return {data['second'][0] for data in hierarchy.values() if data['second'][0]}

    def _get_position_tier(self, player_name: str, position_name: str) -> int:
        """
        Get player's tier for a specific position based on hierarchy.

        Tiers:
        - 1 = Starting XI (best player at this position)
        - 2 = Second XI (second best player at this position)
        - 3 = Backup (all other players)

        Args:
            player_name: Name of the player
            position_name: Position to check (e.g., 'DC1', 'DM(L)')

        Returns:
            Integer tier (1, 2, or 3)
        """
        hierarchy = self._calculate_player_hierarchy()

        if position_name not in hierarchy:
            return 3

        pos_hierarchy = hierarchy[position_name]
        if pos_hierarchy['starting'][0] == player_name:
            return 1
        elif pos_hierarchy['second'][0] == player_name:
            return 2
        else:
            return 3

    def calculate_effective_rating(self, row: pd.Series, skill_col: str, ability_col: Optional[str] = None,
                                   match_importance: str = 'Medium',
                                   prioritize_sharpness: bool = False,
                                   position_name: Optional[str] = None,
                                   player_tier: Optional[str] = None,
                                   position_tier: int = 3) -> float:
        """
        Calculate effective rating considering familiarity, ability, and status factors.

        Args:
            row: Player data row
            skill_col: Positional skill rating column (1-20 familiarity)
            ability_col: Role ability rating column (0-200 quality) - optional
            match_importance: 'Low', 'Medium', 'High', or 'Sharpness'
            prioritize_sharpness: Give minutes to low-sharpness players
            position_name: Position being evaluated (for training bonus)
            player_tier: Player's tier for Sharpness mode ('starting_xi', 'top_backup', 'squad', or None)
            position_tier: Position-specific tier (1=Starting XI, 2=Second XI, 3=Backup)
                          For Low/Medium matches, Tier 3+ players don't get rotation penalties
                          or development bonuses - just actual performance-based penalties.

        Returns:
            Effective rating (lower is worse, can be negative)
        """
        # Check if player is available (injured only - banned players may be eligible for other competitions)
        if row.get('Is Injured', False):
            return -999.0

        # Get positional skill rating (familiarity 1-20)
        skill_rating = row.get(skill_col, 0)
        if pd.isna(skill_rating) or skill_rating < 1:
            return -999.0

        # Apply heavy penalty for players below minimum familiarity threshold in Low/Medium matches
        # This discourages selecting players who can't play the position, but allows it as last resort
        below_familiarity_threshold = (match_importance in ['Low', 'Medium'] and
                                       skill_rating < MIN_POSITION_FAMILIARITY)

        # Get role ability rating (quality 0-200) if available
        if ability_col and ability_col in row.index:
            ability_rating = row.get(ability_col, 0)
            if pd.isna(ability_rating) or ability_rating < 1:
                # No valid ability rating, fall back to skill only
                base_rating = float(skill_rating)
            else:
                # Use ability rating as base (0-200 scale)
                # Normalize to ~20 scale to match skill ratings for consistency
                base_rating = float(ability_rating) / 10.0
        else:
            # No ability data, use skill rating as base
            base_rating = float(skill_rating)

        effective_rating = base_rating

        # 1. Apply positional familiarity penalty based on skill rating and Versatility
        versatility = row.get('Versatility', 10)
        familiarity_penalty = self._get_familiarity_penalty(skill_rating, versatility)
        effective_rating *= (1 - familiarity_penalty)

        # 2. Match sharpness factor (0-10000 scale in database)
        # Based on FM26 Research (match-sharpness.md):
        # - 91%+ = Full Capacity (no penalties)
        # - 81-90% = Match Ready (negligible impact)
        # - 60-80% = Lacking Sharpness (moderate penalty, needs minutes)
        # - <60% = Severe Rust (severe penalty, high injury risk)
        match_sharpness = row.get('Match Sharpness', 10000)
        if pd.notna(match_sharpness):
            sharpness_pct = match_sharpness / 10000

            # === LOW PRIORITY MATCHES: Prioritize sharpness development ===
            if match_importance == 'Low' and position_tier <= 2:
                # HEAVILY boost Second XI players who need sharpness
                if sharpness_pct < 0.60:
                    # SEVERE RUST - critical need, but risky to play
                    effective_rating *= 1.30  # Boost but not too much (injury risk)
                elif sharpness_pct < 0.80:
                    # LACKING SHARPNESS - urgent need for minutes
                    effective_rating *= 1.40  # Strong boost - these players NEED to play
                elif sharpness_pct < 0.91:
                    # MATCH READY but not Full Capacity - should get minutes
                    effective_rating *= 1.20  # Moderate boost
                elif sharpness_pct >= 1.0:
                    # MAX SHARPNESS (100%) - they don't need minutes, rest them
                    effective_rating *= 0.70  # Significant penalty to rest sharp players

            # === MEDIUM PRIORITY MATCHES: Balance effectiveness with development ===
            elif match_importance == 'Medium' and position_tier <= 2:
                if sharpness_pct < 0.60:
                    # SEVERE RUST - still risky, moderate penalty
                    effective_rating *= 0.85
                elif sharpness_pct < 0.80:
                    # LACKING SHARPNESS - small boost to give them minutes
                    effective_rating *= 1.10
                elif sharpness_pct < 0.91:
                    # MATCH READY - slight boost
                    effective_rating *= 1.05
                elif sharpness_pct >= 1.0:
                    # MAX SHARPNESS - slight penalty to rotate
                    effective_rating *= 0.95

            # === HIGH PRIORITY MATCHES: Pure effectiveness, realistic penalties only ===
            elif match_importance == 'High':
                # No boosting - only apply realistic penalties for rusty players
                if sharpness_pct < 0.60:
                    effective_rating *= 0.70  # Severe penalty - player is rusty
                elif sharpness_pct < 0.80:
                    effective_rating *= 0.85  # Moderate penalty - lacking sharpness
                elif sharpness_pct < 0.91:
                    effective_rating *= 0.95  # Minor penalty - not at full capacity

            # === TIER 3+ PLAYERS (Squad depth) - Only apply penalties, no boosts ===
            elif position_tier > 2:
                if sharpness_pct < 0.60:
                    effective_rating *= 0.70
                elif sharpness_pct < 0.80:
                    effective_rating *= 0.85
                elif sharpness_pct < 0.91:
                    effective_rating *= 0.95

            # === SHARPNESS PRIORITY MODE: Maximize sharpness development ===
            if match_importance == 'Sharpness' and player_tier is not None:
                sharpness_need = self._calculate_sharpness_need_score(
                    sharpness_pct,
                    player_tier == 'starting_xi'
                )

                # Convert need score to rating multiplier
                # Higher need = higher boost, low/no need = penalty
                if sharpness_need >= 1000:
                    effective_rating *= 1.50  # LACKING sharpness - highest priority
                elif sharpness_need >= 900:
                    effective_rating *= 1.40  # LACKING sharpness backup
                elif sharpness_need >= 700:
                    effective_rating *= 1.25  # MATCH READY Starting XI
                elif sharpness_need >= 600:
                    effective_rating *= 1.15  # MATCH READY Backup
                elif sharpness_need >= 200:
                    effective_rating *= 0.60  # FULL CAPACITY - low priority
                elif sharpness_need >= 100:
                    effective_rating *= 0.50  # FULL CAPACITY backup - very low priority
                else:
                    effective_rating *= 0.25  # MAX sharpness (100%) - avoid

        # 3. Physical condition factor (percentage)
        # Research: "NEVER field players below 85% condition"
        condition = row.get('Condition', 100)
        if pd.notna(condition):
            # Normalize to 0-100 scale if stored as 0-10000
            if condition > 100:
                condition = condition / 100

            # ENHANCEMENT 1: Enforce 85% condition rule (FM26 Unity Engine)
            if condition < 85:
                # CRITICAL: FM26 Unity Engine has exponential injury risk below 85%
                if match_importance == 'High':
                    effective_rating *= 0.20  # NEAR-PROHIBITION for critical matches
                elif match_importance == 'Medium':
                    effective_rating *= 0.50  # Heavy penalty - absolute safety threshold
                else:
                    effective_rating *= 0.70  # Moderate penalty for Low importance
            elif condition < 60:
                effective_rating *= 0.40  # Catastrophic - should never play
            elif condition < 75:
                effective_rating *= 0.60  # Severe penalty
            elif condition < 90:
                effective_rating *= 0.90  # Minor penalty

        # 4. Fatigue penalty with research-based adjustments
        # ENHANCEMENTS 2, 3, 5, 6, 7: Age/fitness/stamina/injury-adjusted thresholds
        fatigue = row.get('Fatigue', 0)
        if pd.notna(fatigue):
            # Get player attributes for threshold calculation
            age = row.get('Age', 25)
            natural_fitness = row.get('Natural Fitness', 10)
            stamina = row.get('Stamina', 10)
            injury_proneness = row.get('Injury Proneness', None)

            # Calculate personalized fatigue threshold (200-550 range)
            fatigue_threshold = self._get_adjusted_fatigue_threshold(age, natural_fitness, stamina, injury_proneness)

            # Apply position-specific fatigue multiplier
            if position_name:
                position_multiplier = self._get_position_fatigue_multiplier(position_name)
                effective_fatigue = fatigue * position_multiplier
            else:
                effective_fatigue = fatigue

            # Apply penalties based on adjusted threshold
            if effective_fatigue >= fatigue_threshold + 100:
                effective_rating *= 0.65  # Severe penalty - well above threshold
            elif effective_fatigue >= fatigue_threshold:
                effective_rating *= 0.85  # Moderate penalty - at threshold
            elif effective_fatigue >= fatigue_threshold - 50:
                effective_rating *= 0.95  # Minor penalty - approaching threshold

            # ENHANCEMENT 6: Removed penalty for negative fatigue (under-conditioned, not rested)

        # 5. Consecutive match tracking penalty (position-specific)
        # ENHANCEMENT 4: Penalize players based on position-specific rotation needs
        # Research: Wing-backs/DMs need rotation after 2-3 matches, CBs can sustain 5+
        # NOTE: Penalties are skipped for high priority matches (proactive rotation should happen before)
        # NOTE: For Low/Medium matches, only apply to Tier 1-2 (Starting XI / Second XI)
        #       We care about rotating core players. Tier 3+ backups don't get rotation penalty -
        #       we don't care about keeping them fresh, just use them when needed.
        player_name = row.get('Name', '')
        if player_name in self.player_match_count:
            consecutive_matches = self.player_match_count[player_name]
            # Only apply rotation penalty to Tier 1-2 in Low/Medium matches
            # For Tier 3+, skip rotation penalty - we don't care about rotating them
            if position_tier <= 2 or match_importance == 'High':
                consecutive_penalty = self._get_consecutive_match_penalty(
                    consecutive_matches, position_name, match_importance
                )
                effective_rating *= consecutive_penalty

        # 6. Match importance modifier
        if match_importance == 'High':
            # Use dynamic threshold if we have fatigue data
            if pd.notna(fatigue) and 'fatigue_threshold' in locals():
                if effective_fatigue >= fatigue_threshold or condition < 80:
                    effective_rating *= 0.85  # Extra penalty in important matches
            elif condition < 80:
                effective_rating *= 0.85

        # 7. Training bonus for low/medium importance matches
        # NOTE: Only apply to Tier 1-2 (Starting XI / Second XI) - squad development feature
        #       Tier 3+ backups don't get training bonuses - we don't care about their development
        if (match_importance in ['Low', 'Medium'] and
            position_tier <= 2 and  # Only Tier 1-2 get training bonuses
            position_name and
            row['Name'] in self.training_recommendations):

            training_info = self.training_recommendations[row['Name']]
            training_pos = training_info['position']

            # Map position_name to training position format
            pos_map = {
                'STC': 'ST', 'AML': 'AM(L)', 'AMC': 'AM(C)', 'AMR': 'AM(R)',
                'DL': 'D(L)', 'DC1': 'D(C)', 'DC2': 'D(C)', 'DR': 'D(R)',
                'DM(L)': 'DM', 'DM(R)': 'DM', 'GK': 'GK'
            }

            mapped_pos = pos_map.get(position_name, position_name)

            # If this position matches training position
            if mapped_pos == training_pos:
                skill_rating = row.get(skill_col, 0)

                # Only boost if player is playable (≥10 Competent)
                if skill_rating >= 10:
                    priority = training_info['priority']

                    if match_importance == 'Low':
                        # Stronger boost in unimportant matches
                        if priority == 'High':
                            effective_rating *= 1.15  # 15% boost
                        elif priority == 'Medium':
                            effective_rating *= 1.10  # 10% boost
                        else:
                            effective_rating *= 1.05  # 5% boost

                    elif match_importance == 'Medium':
                        # Modest boost in medium matches
                        if priority == 'High':
                            effective_rating *= 1.08  # 8% boost
                        elif priority == 'Medium':
                            effective_rating *= 1.05  # 5% boost

        # 8. Universalist/Versatility bonus (FM26 25+3 squad model)
        # Reward players who can cover multiple positions (Tier 3 strategic value)
        # SKIP for High priority matches - we want the BEST player at each position
        # NOTE: Only apply to Tier 1-2 - versatility is a squad planning feature
        #       Tier 3+ backups don't get versatility bonuses
        if match_importance != 'High' and position_tier <= 2:
            competent_positions = self._get_player_competent_positions(row)
            if competent_positions >= 3:
                effective_rating *= 1.05  # 5% bonus for universalists (3+ positions)
            elif competent_positions == 2:
                effective_rating *= 1.03  # 3% bonus for dual-position players

        # 9. Strategic pathway bonus (FM26 positional conversion research)
        # Reward players who fit strategic retraining pathways (winger→WB, aging AMC→DM)
        # SKIP for High priority matches - we want the BEST player at each position
        # NOTE: Only apply to Tier 1-2 - pathway development is a squad planning feature
        #       Tier 3+ backups don't get pathway bonuses
        if match_importance != 'High' and position_tier <= 2:
            pathway_bonus = self._get_strategic_pathway_bonus(row, position_name)
            effective_rating *= pathway_bonus

        # Apply heavy penalty for players below minimum familiarity threshold
        # This is applied LAST so it heavily discourages but doesn't completely exclude
        # (allows selection as last resort if no better options exist)
        if below_familiarity_threshold:
            effective_rating *= 0.30  # 70% penalty for "Unconvincing" or worse players

        return effective_rating

    def _get_familiarity_penalty(self, skill_rating: float, versatility: float = 10) -> float:
        """
        Calculate penalty based on positional familiarity AND Versatility attribute.

        Research-backed from docs/Research/positional-skill-ratings.md:
        - Natural (18-20): 99-100% effectiveness → 0% penalty
        - Accomplished (15-17): 99% → 1% penalty
        - Competent (12-14): 85-95% → 10% penalty (middle)
        - Unconvincing (9-11): 70-80% → 25% penalty (middle)
        - Awkward (5-8): 50-60% → 45% penalty (middle)
        - Makeshift (1-4): <40% → 65% penalty

        Versatility modifier: High (15-20) reduces by up to 50%, Low (1-5) increases by up to 25%

        Args:
            skill_rating: Player's familiarity rating at this position (1-20)
            versatility: Player's Versatility hidden attribute (1-20)

        Returns:
            Penalty as decimal (0.0 = no penalty, 0.65 = 65% reduction)
        """
        if pd.isna(skill_rating) or skill_rating < 1:
            return 1.0  # Rating 0 or missing: Complete block

        # Base penalty from research effectiveness data
        if skill_rating >= 18:
            base_penalty = 0.00  # Natural: 100%
        elif skill_rating >= 15:
            base_penalty = 0.01  # Accomplished: 99%
        elif skill_rating >= 12:
            base_penalty = 0.10  # Competent: 90%
        elif skill_rating >= 9:
            base_penalty = 0.25  # Unconvincing: 75%
        elif skill_rating >= 5:
            base_penalty = 0.45  # Awkward: 55%
        else:
            base_penalty = 0.65  # Makeshift (1-4): 35%

        # Versatility modifier
        # vers 20 → modifier 0.5 (50% penalty reduction)
        # vers 10 → modifier 1.0 (no change)
        # vers 1 → modifier 1.25 (25% penalty increase)
        if pd.notna(versatility) and versatility > 0:
            versatility_modifier = 1.0 - ((versatility - 10) / 20)
            versatility_modifier = max(0.5, min(1.25, versatility_modifier))
        else:
            versatility_modifier = 1.0

        adjusted_penalty = base_penalty * versatility_modifier
        return min(adjusted_penalty, 0.80)  # Cap at 80% max penalty

    def _get_adjusted_fatigue_threshold(self, age: float, natural_fitness: float, stamina: float, injury_proneness: float = None) -> float:
        """
        Calculate age/fitness/stamina/injury-adjusted fatigue threshold.

        Research-based thresholds (FM26 Unity Engine):
        - Standard: 400
        - Ages 30-32: 350 (more sensitive)
        - Ages 32+: 300 (highly sensitive)
        - Under 19: 350 (burnout risk)
        - Low Natural Fitness (<10): -50
        - High Natural Fitness (≥15): +50
        - Low Stamina (<10): -50
        - High Stamina (≥15): +30
        - High Injury Proneness (≥15): -100 (CRITICAL: much more fragile)
        - Low Injury Proneness (≤8): +50 (robust, can handle load)

        Args:
            age: Player age
            natural_fitness: Natural Fitness attribute (0-20)
            stamina: Stamina attribute (0-20)
            injury_proneness: Injury Proneness attribute (0-20, higher = more injury prone)

        Returns:
            Adjusted fatigue threshold
        """
        # Start with base threshold
        threshold = 400.0

        # Age adjustments (applied first)
        if pd.notna(age):
            if age >= 32:
                threshold = 300.0  # Highly sensitive for veterans
            elif age >= 30:
                threshold = 350.0  # More sensitive for aging players
            elif age < 19:
                threshold = 350.0  # Burnout risk for youth

        # Natural Fitness modifiers
        if pd.notna(natural_fitness):
            if natural_fitness < 10:
                threshold -= 50  # Poor fitness = lower threshold
            elif natural_fitness >= 15:
                threshold += 50  # Excellent fitness = higher threshold

        # Stamina modifiers
        if pd.notna(stamina):
            if stamina < 10:
                threshold -= 50  # Poor stamina = tires faster
            elif stamina >= 15:
                threshold += 30  # Good stamina = sustains load better

        # Injury Proneness modifiers (FM26 Unity Engine - critical factor)
        if pd.notna(injury_proneness):
            if injury_proneness >= 15:
                threshold -= 100  # CRITICAL: Highly injury-prone players are fragile
            elif injury_proneness <= 8:
                threshold += 50  # Low injury risk = can handle higher load

        # Ensure threshold doesn't go below 200 or above 550
        return max(200.0, min(550.0, threshold))

    def _get_position_fatigue_multiplier(self, position_name: str) -> float:
        """
        Get position-specific fatigue sensitivity multiplier.

        FM26 Unity Engine Research (lineup-depth-strategy.md):
        - Wing-backs are THE highest attrition zone (Section 4.2)
        - Pressing Wing-Back role has equal/higher demands than Pressing DM
        - "Players in these high-intensity roles can reach critical fatigue levels as early as the 65th minute"

        Classification:
        - High-intensity (1.2x): Wing-Backs, Defensive Midfielders (most ground covered)
        - Medium-intensity (1.0x): Wingers, Attacking midfielders, Striker
        - Low-intensity (0.8x): Center-backs, Goalkeepers (positional roles)

        Args:
            position_name: Position code (e.g., 'STC', 'DM(L)', 'DC1')

        Returns:
            Fatigue multiplier (0.8 - 1.2)
        """
        # High-intensity positions - require more frequent rotation
        # CRITICAL: Wing-backs (DL, DR) reclassified as high-attrition based on FM26 research
        high_intensity = ['DL', 'DR', 'DM(L)', 'DM(R)']  # Wing-backs AND DMs

        # Medium-intensity positions - standard rotation
        medium_intensity = ['AML', 'AMC', 'AMR', 'STC']

        # Low-intensity positions - can sustain longer runs
        low_intensity = ['GK', 'DC1', 'DC2']

        if position_name in high_intensity:
            return 1.2
        elif position_name in low_intensity:
            return 0.8
        else:  # medium_intensity or unknown
            return 1.0

    def _get_consecutive_match_penalty(self, consecutive_matches: int, position_name: str,
                                       match_importance: str = 'Medium') -> float:
        """
        Position-specific consecutive match penalties based on attrition research.

        FM26 Unity Engine Research (lineup-depth-strategy.md):
        - Wing-backs/DMs are highest attrition zones (rotate after 2-3 matches)
        - Attackers/midfielders are medium attrition (rotate after 3-4 matches)
        - CBs/GK are low attrition (can play 5+ consecutive matches)
        - "Players in high-intensity roles can reach critical fatigue levels as early as the 65th minute"

        HIGH PRIORITY PROTECTION:
        - No consecutive match penalties for high priority matches
        - Best XI should play important games regardless of streak
        - Proactive rotation should happen in preceding low/medium matches instead

        Args:
            consecutive_matches: Number of consecutive matches played
            position_name: Position code (e.g., 'DL', 'AMC', 'DC1')
            match_importance: 'Low', 'Medium', or 'High'

        Returns:
            Penalty multiplier (0.60-1.0, where lower = heavier penalty)
        """
        # No consecutive match penalty for high priority matches - we want best XI
        if match_importance == 'High':
            return 1.0

        if position_name is None:
            position_name = ''

        # High-attrition positions (Wing-backs, Defensive midfielders)
        # Need rotation EARLIER than standard positions
        if position_name in ['DL', 'DR', 'DM(L)', 'DM(R)']:
            if consecutive_matches >= 4:
                return 0.60  # Severe - overworked, injury risk high
            elif consecutive_matches >= 3:
                return 0.75  # Heavy - rotation critical
            elif consecutive_matches >= 2:
                return 0.90  # Early warning - start planning rotation

        # Medium-attrition positions (Wingers, Attacking mids, Striker)
        # Standard rotation schedule
        elif position_name in ['AML', 'AMC', 'AMR', 'STC']:
            if consecutive_matches >= 5:
                return 0.70  # Severe - overworked
            elif consecutive_matches >= 4:
                return 0.80  # Heavy - rotation needed
            elif consecutive_matches >= 3:
                return 0.90  # Warning - consider rotation

        # Low-attrition positions (Center-backs, Goalkeeper)
        # Can sustain longer consecutive runs
        elif position_name in ['DC1', 'DC2', 'GK']:
            if consecutive_matches >= 6:
                return 0.80  # Even CBs need occasional rest
            elif consecutive_matches >= 5:
                return 0.90  # Minor warning

        return 1.0  # No penalty

    def _get_player_competent_positions(self, row) -> int:
        """
        Count how many positions a player can play at Accomplished/Natural level (15+).

        FM26 Strategic Value (lineup-depth-strategy.md):
        - Universalists (3+ positions) are Tier 3 emergency backup
        - Versatility is critical for squad depth in 25+3 model

        Args:
            row: Player data row

        Returns:
            Number of positions at 15+ familiarity (Accomplished or Natural)
        """
        position_columns = [
            'GoalKeeper', 'Defender Right', 'Defender Center', 'Defender Left',
            'Defensive Midfielder', 'Attacking Mid. Right', 'Attacking Mid. Center',
            'Attacking Mid. Left', 'Striker'
        ]

        competent_count = 0
        for col in position_columns:
            rating = row.get(col, 0)
            if pd.notna(rating) and rating >= 15:  # Accomplished (16) or Natural (18-20)
                competent_count += 1

        return competent_count

    def _get_strategic_pathway_bonus(self, row, position_name: str) -> float:
        """
        Detect and reward strategic positional conversion pathways (FM26 research).

        Strategic Pathways (lineup-depth-strategy.md):
        1. Winger→Wing-Back: Young wingers with work rate → full-backs (most efficient retraining)
        2. Aging AMC→DM: Playmakers losing pace → deep-lying midfielders (career extension)

        Args:
            row: Player data row
            position_name: Position being evaluated (DL, DR, DM(L), DM(R), etc.)

        Returns:
            Bonus multiplier (1.0 = no bonus, 1.02-1.04 for strategic fit)
        """
        if not position_name:
            return 1.0

        age = row.get('Age', 25)

        # PATHWAY 1: Winger → Wing-Back (for DL/DR positions)
        if position_name in ['DL', 'DR']:
            # Check if player is a winger (strong at AML/AMR)
            aml_rating = row.get('Attacking Mid. Left', 0)
            amr_rating = row.get('Attacking Mid. Right', 0)
            is_winger = (pd.notna(aml_rating) and aml_rating >= 13) or (pd.notna(amr_rating) and amr_rating >= 13)

            if is_winger and age < 26:  # Young winger
                work_rate = row.get('Work Rate', 10)
                if pd.notna(work_rate) and work_rate >= 12:
                    return 1.04  # Strategic pathway bonus

        # PATHWAY 2: Aging AMC → DM (for DM positions)
        elif position_name in ['DM(L)', 'DM(R)']:
            # Check if player is an aging playmaker (strong at AMC)
            amc_rating = row.get('Attacking Mid. Center', 0)
            is_playmaker = pd.notna(amc_rating) and amc_rating >= 15

            if is_playmaker and age >= 28:  # Aging playmaker
                # Check for elite mental attributes and pace decline
                vision = row.get('Vision', 10)
                passing = row.get('Passing', 10)
                decisions = row.get('Decisions', 10)
                pace = row.get('Pace', 10)
                acceleration = row.get('Acceleration', 10)

                has_elite_mentals = (pd.notna(vision) and vision >= 14 and
                                    pd.notna(passing) and passing >= 14 and
                                    pd.notna(decisions) and decisions >= 13)
                has_pace_decline = (pd.notna(pace) and pace <= 12) or (pd.notna(acceleration) and acceleration <= 12)

                if has_elite_mentals and has_pace_decline:
                    return 1.03  # Career extension pathway bonus

        return 1.0  # No strategic pathway detected

    def _calculate_sharpness_need_score(self, sharpness_pct: float, is_starting_xi: bool) -> float:
        """
        Calculate priority score for sharpness development (higher = needs more).

        Used by Sharpness priority mode to prioritize players who need match minutes
        to build sharpness over those already at maximum.

        Based on FM26 Research (match-sharpness.md):
        - 91%+ = Full Capacity (no penalties, no need for minutes)
        - 81-90% = Match Ready (negligible impact, should maintain)
        - 60-80% = Lacking Sharpness (moderate penalty, needs minutes urgently)
        - <60% = Severe Rust (severe penalty, critical need but high injury risk)

        Priority Order (based on returned score):
        1. Starting XI with LACKING sharpness (<80%): 1000+ points
        2. Backups with LACKING sharpness (<80%): 900+ points
        3. Starting XI with MATCH READY sharpness (80-90%): 700+ points
        4. Backups with MATCH READY sharpness (80-90%): 600+ points
        5. Starting XI at FULL CAPACITY but not max (91-99%): 200 points
        6. Backups at FULL CAPACITY but not max (91-99%): 100 points
        7. MAX sharpness (100%): 0 points (avoid - they don't need minutes)

        Args:
            sharpness_pct: Match sharpness as 0-1 scale (1.0 = 100%)
            is_starting_xi: True if player is in theoretical best XI

        Returns:
            Score 0-1100 (higher = needs more sharpness development)
        """
        if sharpness_pct >= 1.0:  # MAX (100%) - avoid, they don't need minutes
            return 0
        elif sharpness_pct >= 0.91:  # FULL CAPACITY (91-99%) - low priority
            tier_score = 200 if is_starting_xi else 100
        elif sharpness_pct >= 0.80:  # MATCH READY (80-90%) - moderate priority
            tier_score = 700 if is_starting_xi else 600
        elif sharpness_pct >= 0.60:  # LACKING SHARPNESS (60-79%) - high priority
            tier_score = 1000 if is_starting_xi else 900
        else:  # SEVERE RUST (<60%) - critical need (but injury risk)
            tier_score = 1100 if is_starting_xi else 1000

        # Fine-grained: lower sharpness = higher need (0-50 bonus)
        fine_score = (1.0 - sharpness_pct) * 50

        return tier_score + fine_score

    def _get_theoretical_best_xi_names(self, available_df: pd.DataFrame) -> set:
        """
        Run a quick High priority selection to determine theoretical best XI names.

        This identifies who WOULD be in the starting XI if we were playing a High
        priority match, ignoring sharpness considerations. Used to classify players
        into tiers for Sharpness priority mode.

        Args:
            available_df: DataFrame of available (non-injured, non-banned) players

        Returns:
            Set of player names who would be in the theoretical best XI
        """
        n_players = len(available_df)
        n_positions = len(self.formation)

        # Create cost matrix using High priority logic (pure ability, no sharpness boosts)
        cost_matrix = np.full((n_players, n_positions), -999.0)

        for i in range(n_players):
            player = available_df.iloc[i]

            for j, pos_info in enumerate(self.formation):
                if len(pos_info) == 3:
                    pos_name, skill_col, ability_col = pos_info
                else:
                    pos_name, skill_col = pos_info
                    ability_col = None

                # Use High priority for theoretical best XI (no tier needed, no sharpness boost)
                # position_tier doesn't matter for High priority - tier logic only applies to Low/Medium
                effective_rating = self.calculate_effective_rating(
                    player, skill_col, ability_col,
                    match_importance='High',
                    prioritize_sharpness=False,
                    position_name=pos_name,
                    player_tier=None,
                    position_tier=3  # Default - irrelevant for High priority
                )

                if effective_rating > -999.0:
                    cost_matrix[i, j] = -effective_rating

        # Solve assignment
        row_ind, col_ind = linear_sum_assignment(cost_matrix)

        # Collect names of best XI
        best_xi_names = set()
        for i, j in zip(row_ind, col_ind):
            if cost_matrix[i, j] > -998:  # Valid assignment
                player_name = available_df.iloc[i]['Name']
                best_xi_names.add(player_name)

        return best_xi_names

    def _calculate_player_tiers(self, available_df: pd.DataFrame) -> Dict[str, str]:
        """
        Identify which players are 'starting_xi', 'top_backup', or 'squad'.

        Uses pre-calculated hierarchy for Starting XI (guaranteed 11 unique players
        via Hungarian algorithm), then identifies top 6 non-starters by CA as
        top backups.

        Tiers:
        - 'starting_xi': Players in the optimal First XI (11 unique players)
        - 'top_backup': Top 6 non-starting players by CA (Current Ability)
        - 'squad': All other players

        Args:
            available_df: DataFrame of available players

        Returns:
            Dict mapping player name to tier string
        """
        # Get First XI from hierarchy (guaranteed 11 unique players via Hungarian algorithm)
        first_xi_names = self._get_first_xi_players()

        # Get top 6 non-starters by CA (Current Ability)
        backup_candidates = []
        for idx, row in available_df.iterrows():
            name = row['Name']
            if name not in first_xi_names:
                ca = row.get('CA', 0)
                if pd.notna(ca) and ca > 0:
                    backup_candidates.append((name, ca))

        # Sort by CA descending and take top 6
        backup_candidates.sort(key=lambda x: x[1], reverse=True)
        top_backup_names = set(name for name, _ in backup_candidates[:6])

        # Build tier mapping
        tiers = {}
        for idx, row in available_df.iterrows():
            name = row['Name']
            if name in first_xi_names:
                tiers[name] = 'starting_xi'
            elif name in top_backup_names:
                tiers[name] = 'top_backup'
            else:
                tiers[name] = 'squad'

        return tiers

    def _update_consecutive_match_counts(self, selection: Dict):
        """
        Update consecutive match tracking based on current selection.

        Args:
            selection: Dictionary mapping position to (player_name, rating, player_data)
        """
        # Get names of players selected this match
        selected_players = set(player_name for player_name, _, _ in selection.values())

        # Increment count for selected players
        for player_name in selected_players:
            if player_name in self.player_match_count:
                self.player_match_count[player_name] += 1
            else:
                self.player_match_count[player_name] = 1

        # Reset count for players not selected (they're getting rest)
        all_players = set(self.df['Name'].values)
        rested_players = all_players - selected_players
        for player_name in rested_players:
            if player_name in self.player_match_count:
                self.player_match_count[player_name] = 0

    def _load_match_tracking(self, filepath: str = 'player_match_tracking.json') -> dict:
        """
        Load match tracking data from JSON file.

        Args:
            filepath: Path to JSON tracking file

        Returns:
            Dictionary with 'match_counts', 'last_match_date', 'last_updated'
        """
        import os

        if not os.path.exists(filepath):
            # First run or file deleted - return empty structure
            return {
                'match_counts': {},
                'last_match_date': None,
                'last_updated': None
            }

        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                data = json.load(f)

            # Validate structure
            if not isinstance(data.get('match_counts', {}), dict):
                print(f"Warning: Invalid match_counts in {filepath}. Starting fresh.")
                return {'match_counts': {}, 'last_match_date': None, 'last_updated': None}

            # Validate date format if present
            if data.get('last_match_date'):
                try:
                    datetime.strptime(data['last_match_date'], '%Y-%m-%d')
                except ValueError:
                    print(f"Warning: Invalid date format in {filepath}. Starting fresh.")
                    data['last_match_date'] = None

            return data

        except json.JSONDecodeError:
            print(f"Warning: Could not load {filepath} (corrupted JSON). Starting fresh.")
            return {'match_counts': {}, 'last_match_date': None, 'last_updated': None}
        except Exception as e:
            print(f"Warning: Error loading {filepath}: {str(e)}. Starting fresh.")
            return {'match_counts': {}, 'last_match_date': None, 'last_updated': None}

    def _save_match_tracking(self, filepath: str = 'player_match_tracking.json'):
        """
        Save match tracking data to JSON file.

        Args:
            filepath: Path to JSON tracking file
        """
        data = {
            'last_match_date': self.last_match_counted,
            'last_updated': datetime.now().strftime('%Y-%m-%dT%H:%M:%S'),
            'match_counts': self.player_match_count
        }

        try:
            # Atomic write: write to temp file, then rename
            temp_filepath = filepath + '.tmp'
            with open(temp_filepath, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)

            # Rename temp file to actual file (atomic on most systems)
            import os
            if os.path.exists(filepath):
                os.remove(filepath)
            os.rename(temp_filepath, filepath)

        except Exception as e:
            print(f"Warning: Could not save match tracking to {filepath}: {str(e)}")

    def select_match_xi(self, match_importance: str = 'Medium',
                       prioritize_sharpness: bool = False,
                       rested_players: List[str] = None,
                       debug: bool = False) -> Dict:
        """
        Select optimal XI for a specific match.

        Args:
            match_importance: 'Low', 'Medium', 'High', or 'Sharpness'
            prioritize_sharpness: Give playing time to low-sharpness players
            rested_players: List of player names to rest (avoid selecting)
            debug: Enable detailed debug output

        Returns:
            Dictionary mapping position to (player_name, effective_rating, player_data)
        """
        if rested_players is None:
            rested_players = []

        # Filter out unavailable players BEFORE creating cost matrix
        # Remove: injured and rested players (banned players may be eligible for other competitions)
        # Use normalized names (ASCII transliteration) to handle accented characters (e.g., Jose Carlos)
        normalized_rested = [normalize_name(p) for p in rested_players]

        # DEBUG: Print rejection filtering details
        import sys
        if rested_players:
            print(f"[DEBUG REJECTION] Raw rested_players: {rested_players}", file=sys.stderr)
            print(f"[DEBUG REJECTION] Normalized rested: {normalized_rested}", file=sys.stderr)
            # Check if José Carlos is in the data
            jose_rows = self.df[self.df['Name'].str.contains('Carlos', case=False, na=False)]
            if not jose_rows.empty:
                for _, row in jose_rows.iterrows():
                    print(f"[DEBUG REJECTION] Found player: Name='{row['Name']}', Name_Normalized='{row['Name_Normalized']}'", file=sys.stderr)
                    is_match = row['Name_Normalized'] in normalized_rested
                    print(f"[DEBUG REJECTION] Is '{row['Name_Normalized']}' in {normalized_rested}? {is_match}", file=sys.stderr)

        unavailable_mask = (
            (self.df['Is Injured'] == True) |
            (self.df['Name_Normalized'].isin(normalized_rested))
        )
        available_df = self.df[~unavailable_mask].copy()
        available_df = available_df.reset_index(drop=False)  # Keep original index in 'index' column

        n_players = len(available_df)
        n_positions = len(self.formation)

        if debug:
            injured = self.df[self.df['Is Injured'] == True]['Name'].tolist()
            print(f"\n[DEBUG] Injured players: {injured}")
            print(f"[DEBUG] Rested players: {rested_players}")
            print(f"[DEBUG] Total available players (after filtering): {n_players}")
            print(f"[DEBUG] Total positions to fill: {n_positions}")

        # Calculate player tiers for Sharpness priority mode
        player_tiers = {}
        if match_importance == 'Sharpness':
            player_tiers = self._calculate_player_tiers(available_df)
            if debug:
                starting_xi = [n for n, t in player_tiers.items() if t == 'starting_xi']
                top_backups = [n for n, t in player_tiers.items() if t == 'top_backup']
                print(f"\n[DEBUG] Sharpness mode - Player tiers calculated:")
                print(f"  Starting XI: {starting_xi}")
                print(f"  Top 6 Backups: {top_backups}")

        # Create cost matrix (negative effective ratings for minimization)
        cost_matrix = np.full((n_players, n_positions), -999.0)

        # Track debug info for problematic positions
        debug_positions = {'DC2': 3, 'DM(R)': 6}  # Position indices
        position_ratings = {pos: [] for pos in debug_positions.keys()}

        # Fill cost matrix with only available players
        for i in range(n_players):
            player = available_df.iloc[i]

            for j, pos_info in enumerate(self.formation):
                if len(pos_info) == 3:
                    pos_name, skill_col, ability_col = pos_info
                else:
                    # Backwards compatibility if someone still uses old format
                    pos_name, skill_col = pos_info
                    ability_col = None

                # Get player tier for Sharpness mode (None for other modes)
                tier = player_tiers.get(player['Name']) if player_tiers else None

                # Get position-specific tier for Low/Medium matches (1=Starting, 2=Second, 3=Backup)
                # This determines whether rotation penalties and development bonuses apply
                position_tier = self._get_position_tier(player['Name'], pos_name)

                effective_rating = self.calculate_effective_rating(
                    player, skill_col, ability_col, match_importance, prioritize_sharpness, pos_name, tier,
                    position_tier=position_tier
                )

                if effective_rating > -999.0:
                    cost_matrix[i, j] = -effective_rating  # Negative for minimization

                # Debug logging for problematic positions
                if debug and pos_name in debug_positions:
                    skill_val = player.get(skill_col, 'N/A')
                    ability_val = player.get(ability_col, 'N/A') if ability_col else 'N/A'
                    position_ratings[pos_name].append({
                        'player': player['Name'],
                        'skill_col': skill_col,
                        'skill_val': skill_val,
                        'ability_col': ability_col,
                        'ability_val': ability_val,
                        'effective_rating': effective_rating,
                        'cost': -effective_rating if effective_rating > -999.0 else -999.0
                    })

        # Print debug info BEFORE assignment
        if debug:
            for pos_name, pos_idx in debug_positions.items():
                print(f"\n[DEBUG] Position {pos_name} (index {pos_idx}):")
                print(f"  Formation: {self.formation[pos_idx]}")

                # Show top candidates
                ratings = position_ratings[pos_name]
                valid_ratings = [r for r in ratings if r['effective_rating'] > -999.0]
                valid_ratings.sort(key=lambda x: x['effective_rating'], reverse=True)

                print(f"  Valid candidates: {len(valid_ratings)} / {n_players}")
                print(f"  Top 5 candidates:")
                for i, r in enumerate(valid_ratings[:5], 1):
                    print(f"    {i}. {r['player']:20} | Skill: {r['skill_val']:5} | "
                          f"Ability: {r['ability_val']:6.1f} | Effective: {r['effective_rating']:6.2f}")

                if len(valid_ratings) < 5:
                    print(f"  (Only {len(valid_ratings)} valid candidates found)")

        # Solve assignment problem
        row_ind, col_ind = linear_sum_assignment(cost_matrix)

        if debug:
            print(f"\n[DEBUG] Hungarian algorithm assignments:")
            for i, j in zip(row_ind, col_ind):
                player = available_df.iloc[i]
                pos_info = self.formation[j]
                pos_name = pos_info[0]
                cost = cost_matrix[i, j]
                eff_rating = -cost if cost > -998 else None
                print(f"  Player {i} ({player['Name']:20}) -> Position {j} ({pos_name:6}) | "
                      f"Cost: {cost:7.2f} | Eff Rating: {eff_rating}")

        # Build selection dictionary
        selection = {}
        for i, j in zip(row_ind, col_ind):
            if cost_matrix[i, j] > -998:  # Valid assignment
                player = available_df.iloc[i]
                pos_info = self.formation[j]
                pos_name = pos_info[0]
                effective_rating = -cost_matrix[i, j]

                selection[pos_name] = (player['Name'], effective_rating, player)

        return selection

    def plan_rotation(self, current_date_str: str, matches: List[Tuple[str, str]], debug: bool = False):
        """
        Plan rotation across multiple matches.

        Args:
            current_date_str: Current date in format 'YYYY-MM-DD' (converted from user's MM-DD-YYYY input)
            matches: List of (date_str, importance) tuples where date_str is 'YYYY-MM-DD' format
                     (converted from user's MM-DD input with automatic year inference)
            debug: Enable debug output for troubleshooting

        Note:
            Users input dates as MM-DD-YYYY (current) and MM-DD (matches).
            The main() function automatically infers years and converts to YYYY-MM-DD before calling this method.
        """
        print("\n" + "=" * 100)
        print("MATCH SCHEDULE AND ROTATION PLANNING")
        print("=" * 100)
        print(f"\nCurrent Date: {current_date_str}")
        print("\nUpcoming Matches:")

        try:
            current_date = datetime.strptime(current_date_str, '%Y-%m-%d')
        except ValueError:
            print("Error: Current date must be in YYYY-MM-DD format")
            return

        match_dates = []
        for i, (date_str, importance) in enumerate(matches, 1):
            try:
                match_date = datetime.strptime(date_str, '%Y-%m-%d')
                days_until = (match_date - current_date).days
                match_dates.append((match_date, importance, days_until))
                print(f"  {i}. {date_str} ({days_until} days) - {importance} importance")
            except ValueError:
                print(f"  Error: Match date '{date_str}' must be in YYYY-MM-DD format")
                return

        print("\n" + "=" * 100)

        # Determine if Match 1 is a new match (not already counted)
        first_match_date_str = match_dates[0][0].strftime('%Y-%m-%d')

        should_update_counts = False
        if self.last_match_counted is None:
            should_update_counts = True
            print(f"\n✓ Match on {first_match_date_str} is NEW. Match tracking will be updated.")
        elif first_match_date_str > self.last_match_counted:
            should_update_counts = True
            print(f"\n✓ Match on {first_match_date_str} is NEW (last counted: {self.last_match_counted}).")
            print("  Match tracking will be updated after Match 1 selection.")
        else:
            print(f"\n⚠️  Match on {first_match_date_str} already counted in tracking file.")
            print("  Re-planning lineup without updating consecutive match tracking.")
            print("  This prevents double-counting if you run the script multiple times.")

        print("=" * 100)

        # Plan selection for each match
        self.match_selections = []
        players_to_rest = []

        for i, (match_date, importance, days_until) in enumerate(match_dates):
            print(f"\n{'=' * 100}")
            print(f"LINEUP FOR MATCH {i+1}: {match_date.strftime('%Y-%m-%d')} ({importance} importance, {days_until} days)")
            print("=" * 100)

            # Determine selection strategy
            prioritize_sharpness = (importance in ['Low', 'Sharpness'])

            # If high-importance match is coming soon, rest high-fatigue players
            if i < len(match_dates) - 1:
                next_match_date, next_importance, next_days = match_dates[i + 1]
                if next_importance == 'High' and days_until <= 3:
                    # Rest high-fatigue players before important match
                    players_to_rest = self._identify_players_to_rest()
                    if players_to_rest:
                        print(f"\nResting players before important match on {next_match_date.strftime('%Y-%m-%d')}:")
                        for player_name in players_to_rest:
                            print(f"  ⚠ {player_name}")
                        print()

            # Select XI
            selection = self.select_match_xi(importance, prioritize_sharpness, players_to_rest, debug)
            self.match_selections.append((match_date, importance, selection))

            # CRITICAL: Only update match counts for Match 1, and only if it's a new match
            if i == 0 and should_update_counts:
                self._update_consecutive_match_counts(selection)
                self.last_match_counted = match_date.strftime('%Y-%m-%d')
                self._save_match_tracking()
                print(f"\n✓ Match tracking updated and saved to player_match_tracking.json")

            # Display selection
            self._print_match_selection(selection, importance, prioritize_sharpness)

            # Clear rest list for next iteration
            players_to_rest = []

        # Print rotation summary
        self._print_rotation_summary()

    def _infer_year(self, month_day_str: str, current_date: datetime) -> str:
        """
        Infer the year for a match date based on the current date.
        If the match month is earlier than the current month, assume next year.

        Args:
            month_day_str: Date string in MM-DD format (e.g., "12-25" or "01-05")
            current_date: Current date as datetime object

        Returns:
            Full date string in YYYY-MM-DD format
        """
        try:
            # Parse MM-DD format
            month, day = map(int, month_day_str.split('-'))

            # Get current year and month
            current_year = current_date.year
            current_month = current_date.month

            # If match month is earlier than current month, it's next year
            if month < current_month:
                year = current_year + 1
            else:
                year = current_year

            # Return in YYYY-MM-DD format
            return f"{year:04d}-{month:02d}-{day:02d}"
        except (ValueError, AttributeError) as e:
            raise ValueError(f"Invalid date format '{month_day_str}'. Expected MM-DD format.")

    def _identify_players_to_rest(self, upcoming_matches: List = None) -> List[str]:
        """
        Identify players who should be rested.

        Reasons for rest:
        1. High fatigue (>= 400)
        2. Low condition (< 75%)
        3. PROACTIVE ROTATION: Approaching rotation threshold with high priority match coming

        Args:
            upcoming_matches: List of upcoming match dicts with 'importance' key for lookahead
                              (used for proactive rotation planning)

        Returns:
            List of player names to rest
        """
        rest_candidates = []

        # 1. REST FOR FATIGUE/CONDITION
        for idx, row in self.df.iterrows():
            fatigue = row.get('Fatigue', 0)
            condition = row.get('Condition', 100)

            # Normalize condition if needed
            if pd.notna(condition) and condition > 100:
                condition = condition / 100

            # Data validation: condition should be reasonable (20-100%)
            # If below 20%, likely data corruption - skip this player
            if pd.notna(condition) and condition < 20:
                continue

            # Rest if fatigue >= 400 or condition < 75%
            should_rest_fatigue = pd.notna(fatigue) and fatigue >= 400
            should_rest_condition = pd.notna(condition) and condition < 75

            if should_rest_fatigue or should_rest_condition:
                rest_candidates.append(row['Name'])

        # 2. PROACTIVE ROTATION: Rest players approaching threshold before high priority matches
        if upcoming_matches:
            # Find the next high priority match
            matches_until_high_priority = None
            for i, match in enumerate(upcoming_matches):
                importance = match.get('importance', 'Medium')
                if importance == 'High':
                    matches_until_high_priority = i + 1  # +1 because index 0 = next match
                    break

            # If high priority match is coming and not the immediate next match
            if matches_until_high_priority is not None and matches_until_high_priority > 1:
                for player_name, consecutive in self.player_match_count.items():
                    if player_name in rest_candidates:
                        continue  # Already being rested

                    # Get position-specific rotation threshold
                    threshold = self._get_rotation_threshold_for_player(player_name)

                    # If player would hit threshold by the high priority match, rest them now
                    # This resets their consecutive count so they're fresh for the big game
                    projected_consecutive = consecutive + matches_until_high_priority
                    if projected_consecutive >= threshold:
                        rest_candidates.append(player_name)

        return rest_candidates

    def _get_rotation_threshold_for_player(self, player_name: str) -> int:
        """
        Get the consecutive match threshold where rotation penalties start for a player.

        Based on position-specific attrition zones (FM26 Unity Engine research):
        - GK/CB: Can sustain 5+ consecutive matches (low attrition)
        - DM/WB: Rotate after 2-3 matches (high attrition)
        - Attackers/Mids: Rotate after 3-4 matches (medium attrition)

        Args:
            player_name: Name of the player

        Returns:
            Threshold where rotation penalties start (lower = needs more frequent rest)
        """
        player = self.df[self.df['Name_Normalized'] == normalize_name(player_name)]
        if player.empty:
            return 4  # Default threshold

        positions = str(player.iloc[0].get('Positions', ''))

        # GK and center-backs have higher threshold (low attrition)
        if 'GK' in positions:
            return 5  # GKs can play 5+ before penalty kicks in
        elif 'D C' in positions or 'DC' in positions:
            return 5  # CBs can also play 5+

        # Wing-backs and DMs have lower threshold (high attrition)
        if 'WB' in positions:
            return 2  # Wing-backs need frequent rotation
        if 'DM' in positions:
            return 2  # Defensive mids need frequent rotation

        # Full-backs (D L, D R) - treat similar to wing-backs in FM26
        if ('D L' in positions or 'D R' in positions or
            'DL' in positions or 'DR' in positions):
            return 3  # Full-backs need some rotation

        # Attackers and midfielders - medium attrition
        return 3  # Default for AM, M, ST positions

    def _print_match_selection(self, selection: Dict, importance: str, prioritize_sharpness: bool):
        """Print formatted match selection."""
        if not selection:
            print("ERROR: Could not select a full team!")
            return

        # Calculate team average
        total_rating = sum(eff_rating for _, eff_rating, _ in selection.values())
        avg_rating = total_rating / len(selection) if selection else 0

        print("\nStarting XI:")
        print()

        # Group by formation sections
        formation_display = {
            'Goalkeeper': ['GK'],
            'Defence': ['DR', 'DC1', 'DC2', 'DL'],
            'Defensive Midfield': ['DM(R)', 'DM(L)'],
            'Attacking Midfield': ['AMR', 'AMC', 'AML'],
            'Striker': ['STC']
        }

        for section, positions in formation_display.items():
            print(f"{section}:")
            for pos in positions:
                if pos in selection:
                    player_name, eff_rating, player_data = selection[pos]

                    # Get status indicators
                    condition = player_data.get('Condition', 100)
                    if condition > 100:
                        condition = condition / 100
                    fatigue = player_data.get('Fatigue', 0)
                    sharpness = player_data.get('Match Sharpness', 10000) / 10000

                    # Status icons (existing + research-based warnings)
                    status_icons = []

                    # Existing indicators
                    if fatigue >= 400:
                        status_icons.append('💤')  # Fatigued
                    if condition < 80:
                        status_icons.append('❤️')  # Low condition
                    if sharpness < 0.80:
                        status_icons.append('🔄')  # Needs sharpness
                    if sharpness >= 0.95 and condition >= 90 and fatigue < 200:
                        status_icons.append('⭐')  # Peak form

                    # NEW: Research-based warning indicators
                    age = player_data.get('Age', 25)
                    if pd.notna(age) and age >= 32:
                        status_icons.append('⚠️')  # Age 32+ High Risk

                    if player_name in self.player_match_count:
                        consecutive = self.player_match_count[player_name]
                        if consecutive >= 3:
                            status_icons.append('⚡')  # Consecutive matches warning

                    stamina = player_data.get('Stamina', 15)
                    if pd.notna(stamina) and stamina < 10:
                        status_icons.append('🏃')  # Low Stamina

                    natural_fitness = player_data.get('Natural Fitness', 15)
                    if pd.notna(natural_fitness) and natural_fitness < 10:
                        status_icons.append('💪')  # Low Natural Fitness

                    status_str = ' '.join(status_icons) if status_icons else ''

                    # Check if player is in training for this position
                    training_indicator = ''
                    if player_name in self.training_recommendations:
                        training_info = self.training_recommendations[player_name]
                        # Map selector position to training position format
                        pos_map = {
                            'STC': 'ST', 'AML': 'AM(L)', 'AMC': 'AM(C)', 'AMR': 'AM(R)',
                            'DL': 'D(L)', 'DC1': 'D(C)', 'DC2': 'D(C)', 'DR': 'D(R)',
                            'DM(L)': 'DM', 'DM(R)': 'DM', 'GK': 'GK'
                        }
                        if pos_map.get(pos, pos) == training_info['position']:
                            training_indicator = f" 🎓[Training: {training_info['priority']}]"

                    print(f"  {pos:6}: {player_name:25} "
                          f"(Eff: {eff_rating:4.1f}) "
                          f"[Cond: {condition:3.0f}% | Fatigue: {fatigue:4.0f} | Sharp: {sharpness:3.0%}] "
                          f"{status_str}{training_indicator}")
                else:
                    print(f"  {pos:6}: NO PLAYER FOUND")
            print()

        print("=" * 100)
        print(f"Team Average Effective Rating: {avg_rating:.2f}")
        if importance == 'Sharpness':
            print("Strategy: SHARPNESS DEVELOPMENT - Maximizing minutes for Starting XI + Backups needing form")
        elif prioritize_sharpness:
            print("Strategy: Prioritizing match sharpness development for fringe players")
        print("=" * 100)

        # Legend
        print("\nSTATUS ICONS:")
        print("  ⭐ Peak form (high condition, low fatigue, sharp)")
        print("  💤 High fatigue (≥400, needs rest)")
        print("  ❤️  Low condition (<80%, injury risk)")
        print("  🔄 Needs match sharpness (<80% = Lacking Sharpness per FM26 research)")
        print("  ⚠️  Age 32+ (higher injury/fatigue risk)")
        print("  ⚡ 3+ consecutive matches (rotation needed)")
        print("  🏃 Low Stamina (<10, tires faster)")
        print("  💪 Low Natural Fitness (<10, recovers slower)")
        print("  🎓 In position training (priority shown)")

        # Add notable exclusions section
        self._print_notable_exclusions(selection, importance)

        # Add rest recommendations section
        self._print_rest_recommendations(selection)

    def _print_notable_exclusions(self, selection: Dict, match_importance: str):
        """
        Print explanation for high-quality players excluded due to fatigue/condition.

        Helps users understand why expected starters aren't selected.

        Args:
            selection: Current match selection
            match_importance: Match importance level
        """
        print("\n" + "=" * 100)
        print("NOTABLE EXCLUSIONS (High-Quality Players Not Selected)")
        print("=" * 100)

        # Get selected player names
        selected_names = {p for p, _, _ in selection.values()}

        # Find high-CA players who weren't selected
        exclusions = []

        for idx, row in self.df.iterrows():
            player_name = row['Name']
            ca = row.get('CA', 0)

            # Skip if selected or injured (banned players may be eligible for other competitions)
            if (player_name in selected_names or
                row.get('Is Injured', False)):
                continue

            # Only flag players with CA >= squad average (likely starters)
            squad_avg_ca = self.df['CA'].mean()
            if pd.notna(ca) and ca < squad_avg_ca * 0.9:  # 90% of average
                continue

            # Determine exclusion reasons
            age = row.get('Age', 25)
            fatigue = row.get('Fatigue', 0)
            condition = row.get('Condition', 100)
            natural_fitness = row.get('Natural Fitness', 15)
            stamina = row.get('Stamina', 15)
            injury_proneness = row.get('Injury Proneness', None)

            # Normalize condition
            if pd.notna(condition) and condition > 100:
                condition = condition / 100

            reasons = []

            # Calculate personalized threshold
            if pd.notna(fatigue):
                threshold = self._get_adjusted_fatigue_threshold(age, natural_fitness, stamina, injury_proneness)

                # Check if fatigue caused exclusion
                if fatigue >= threshold + 100:
                    reasons.append(f"CRITICAL FATIGUE: {fatigue:.0f} (threshold: {threshold:.0f}, needs VACATION)")
                elif fatigue >= threshold:
                    reasons.append(f"High fatigue: {fatigue:.0f} (threshold: {threshold:.0f})")
                elif fatigue >= threshold - 50:
                    reasons.append(f"Elevated fatigue: {fatigue:.0f} (approaching threshold {threshold:.0f})")

            # Consecutive matches
            if player_name in self.player_match_count:
                consecutive = self.player_match_count[player_name]
                if consecutive >= 5:
                    reasons.append(f"OVERWORKED: {consecutive} consecutive matches")
                elif consecutive >= 3:
                    reasons.append(f"{consecutive} consecutive matches (rotation needed)")

            # Low condition (only if severe)
            if pd.notna(condition) and condition < 80:
                reasons.append(f"Low condition: {condition:.0f}%")

            # Age + fatigue combination
            if pd.notna(age) and age >= 32 and pd.notna(fatigue) and fatigue >= 250:
                if not any('fatigue' in r.lower() for r in reasons):
                    reasons.append(f"Age {age} + fatigue {fatigue:.0f} (veterans tire faster)")

            if reasons:
                exclusions.append({
                    'player': player_name,
                    'ca': ca,
                    'position': row.get('Best Position', 'Unknown'),
                    'reasons': reasons
                })

        if not exclusions:
            print("\n✅ All high-quality players are available and selected.")
        else:
            # Sort by CA descending (most important players first)
            exclusions.sort(key=lambda x: x['ca'], reverse=True)

            print(f"\n{len(exclusions)} high-quality players excluded due to fitness:\n")
            for item in exclusions:
                print(f"  {item['player']:25} [CA: {item['ca']:3.0f}, {item['position']}]")
                for reason in item['reasons']:
                    print(f"      → {reason}")
                print()

        print("=" * 100)

    def _print_rest_recommendations(self, selection: Dict):
        """
        Print recommendations for players requiring rest based on research criteria.

        Args:
            selection: Current match selection
        """
        print("\n" + "=" * 100)
        print("REST RECOMMENDATIONS (Research-Based)")
        print("=" * 100)

        rest_needed = []

        for idx, row in self.df.iterrows():
            player_name = row['Name']
            age = row.get('Age', 25)
            fatigue = row.get('Fatigue', 0)
            condition = row.get('Condition', 100)
            natural_fitness = row.get('Natural Fitness', 15)
            stamina = row.get('Stamina', 15)
            injury_proneness = row.get('Injury Proneness', None)

            # Normalize condition
            if pd.notna(condition) and condition > 100:
                condition = condition / 100

            # Skip if data is invalid
            if pd.notna(condition) and condition < 20:
                continue

            # Calculate personalized fatigue threshold
            if pd.notna(fatigue):
                threshold = self._get_adjusted_fatigue_threshold(age, natural_fitness, stamina, injury_proneness)
            else:
                threshold = 400

            # Determine if rest is needed
            reasons = []

            # Fatigue above personalized threshold
            if pd.notna(fatigue) and fatigue >= threshold:
                reasons.append(f"Fatigue {fatigue:.0f} (threshold: {threshold:.0f})")

            # Age 32+ with any elevated fatigue
            if pd.notna(age) and age >= 32 and pd.notna(fatigue) and fatigue >= 250:
                reasons.append(f"Age {age} + fatigue {fatigue:.0f}")

            # 3+ consecutive matches
            if player_name in self.player_match_count and self.player_match_count[player_name] >= 3:
                consecutive = self.player_match_count[player_name]
                reasons.append(f"{consecutive} consecutive matches")

            # Add to list if any reasons exist
            if reasons:
                priority = "URGENT" if (fatigue >= threshold + 100) else "Recommended"
                rest_needed.append({
                    'player': player_name,
                    'priority': priority,
                    'reasons': reasons,
                    'fatigue': fatigue,
                    'threshold': threshold,
                    'age': age,
                    'natural_fitness': natural_fitness,
                    'stamina': stamina,
                    'in_xi': player_name in [p for p, _, _ in selection.values()]
                })

        if not rest_needed:
            print("\n✅ No players currently require rest - squad fitness is good!")
        else:
            # Sort by priority (URGENT first), then by number of reasons
            rest_needed.sort(key=lambda x: (x['priority'] != 'URGENT', -len(x['reasons'])))

            # Separate into vacation candidates vs regular rest
            vacation_candidates = []
            regular_rest = []

            for item in rest_needed:
                # Vacation criteria (from jadedness-fatigue.md):
                # - Fatigue >= threshold (400+ typically)
                # - Vacation recovers 152.4 points over 3 days (most effective method)
                needs_vacation = (
                    pd.notna(item['fatigue']) and item['fatigue'] >= item['threshold'] and
                    (item['priority'] == 'URGENT' or item['fatigue'] >= item['threshold'] + 100)
                )

                if needs_vacation:
                    vacation_candidates.append(item)
                else:
                    regular_rest.append(item)

            # Print vacation recommendations first (highest priority)
            if vacation_candidates:
                print("\n🏖️  VACATION RECOMMENDED (Most Effective Recovery):")
                print("    Research: Vacation + rest sessions recovers 152.4 fatigue points over 3 days\n")

                for item in vacation_candidates:
                    status = "[IN STARTING XI - SEND ASAP!]" if item['in_xi'] else "[Available - send now]"
                    print(f"  {item['player']:25} {status}")
                    print(f"      Fatigue: {item['fatigue']:.0f} (threshold: {item['threshold']:.0f})")
                    print(f"      Recommended: 3-day vacation with rest training sessions")
                    for reason in item['reasons']:
                        print(f"      → {reason}")
                    print()

            # Print regular rest recommendations
            if regular_rest:
                print("\n⚠️  REST RECOMMENDED (Regular Rotation):\n")
                for item in regular_rest:
                    status = "[IN STARTING XI - RISKY!]" if item['in_xi'] else "[Available for rest]"
                    print(f"  {item['priority']:11} | {item['player']:25} {status}")
                    for reason in item['reasons']:
                        print(f"             → {reason}")
                    print()

            # Add vacation instructions
            if vacation_candidates:
                print("\n📋 How to send on vacation (maximum recovery):")
                print("    1. Right-click player → Squad → Send On Holiday")
                print("    2. Set duration: 3 days")
                print("    3. Fill training schedule with REST sessions (not recovery)")
                print("    4. Expected recovery: ~152 fatigue points")
                print("    5. Player will return with significantly reduced jadedness\n")

        print("=" * 100)

    def _print_rotation_summary(self):
        """Print summary of player usage across matches."""
        print("\n" + "=" * 100)
        print("ROTATION SUMMARY")
        print("=" * 100)

        # Count appearances for each player
        player_appearances = {}

        for match_date, importance, selection in self.match_selections:
            for pos, (player_name, eff_rating, player_data) in selection.items():
                if player_name not in player_appearances:
                    player_appearances[player_name] = []
                player_appearances[player_name].append((match_date, pos))

        # Sort by number of appearances
        sorted_players = sorted(player_appearances.items(),
                               key=lambda x: len(x[1]), reverse=True)

        print(f"\nPlayer appearances across {len(self.match_selections)} matches:\n")

        for player_name, appearances in sorted_players:
            match_count = len(appearances)
            positions = ', '.join([pos for _, pos in appearances])
            print(f"  {player_name:25} - {match_count} matches  ({positions})")

        # Identify players who didn't play
        all_players = set(self.df['Name'].values)
        playing_players = set(player_appearances.keys())
        unused_players = all_players - playing_players

        if unused_players:
            print(f"\nPlayers not selected (consider for reserves/friendlies for sharpness):")
            for player in sorted(unused_players):
                player_data = self.df[self.df['Name_Normalized'] == normalize_name(player)].iloc[0]
                sharpness = player_data.get('Match Sharpness', 10000) / 10000
                print(f"  {player:25} - Sharpness: {sharpness:3.0%}")

        print("=" * 100)

    def suggest_training_focus(self):
        """Suggest training focus based on current squad status."""
        print("\n" + "=" * 100)
        print("TRAINING RECOMMENDATIONS")
        print("=" * 100)

        high_fatigue_count = 0
        low_condition_count = 0
        low_sharpness_count = 0

        for idx, row in self.df.iterrows():
            fatigue = row.get('Fatigue', 0)
            condition = row.get('Condition', 100)
            sharpness = row.get('Match Sharpness', 10000) / 10000

            if condition > 100:
                condition = condition / 100

            if fatigue >= 400:
                high_fatigue_count += 1
            if condition < 80:
                low_condition_count += 1
            if sharpness < 0.80:
                low_sharpness_count += 1

        print("\nSquad Status:")
        print(f"  Players with high fatigue (≥400):     {high_fatigue_count}")
        print(f"  Players with low condition (<80%):    {low_condition_count}")
        print(f"  Players with low sharpness (<80%):    {low_sharpness_count}")
        print()

        recommendations = []

        if high_fatigue_count >= 5:
            recommendations.append("⚠️  HIGH PRIORITY: Schedule rest sessions - many players fatigued")
            recommendations.append("   Consider sending 1-2 most fatigued players on vacation")

        if low_condition_count >= 5:
            recommendations.append("⚠️  MEDIUM PRIORITY: Reduce training intensity this week")
            recommendations.append("   Use recovery sessions instead of intensive training")

        if low_sharpness_count >= 8:
            recommendations.append("⚠️  MEDIUM PRIORITY: Schedule friendly matches for fringe players")
            recommendations.append("   Consider match practice sessions in training")

        if not recommendations:
            recommendations.append("✅ Squad fitness is good - continue current training schedule")

        print("Recommendations:")
        for rec in recommendations:
            print(f"  {rec}")

        print("\n" + "=" * 100)


def main():
    """Main execution function."""
    import os

    # Get file paths from command line or use defaults
    status_file = None
    abilities_file = None

    if len(sys.argv) > 1:
        status_file = sys.argv[1]
        if len(sys.argv) > 2:
            abilities_file = sys.argv[2]
    else:
        # Try common filenames
        if os.path.exists('players-current.csv'):
            status_file = 'players-current.csv'
        elif os.path.exists('players.xlsx'):
            status_file = 'players.xlsx'

    # Look for training recommendations file
    training_file = None
    if os.path.exists('training_recommendations.csv'):
        training_file = 'training_recommendations.csv'

    if not status_file:
        print("Error: No player data file found!")
        print("\nUsage:")
        print("  python fm_match_ready_selector.py players-current.csv")
        print("  python fm_match_ready_selector.py <status_file> [abilities_file]")
        sys.exit(1)

    print(f"\nLoading player status/attributes from: {status_file}")
    if abilities_file:
        print(f"Loading role abilities from: {abilities_file}")
    if training_file:
        print(f"Loading training recommendations from: {training_file}")

    try:
        selector = MatchReadySelector(status_file, abilities_file, training_file)

        # Interactive input for match planning
        print("\n" + "=" * 100)
        print("FM26 MATCH-READY LINEUP SELECTOR")
        print("=" * 100)

        # Get current date with year to establish reference
        current_date_input = input("\nEnter current date (MM-DD-YYYY): ").strip()

        # Parse current date to get year reference
        try:
            current_date_obj = datetime.strptime(current_date_input, '%m-%d-%Y')
            # Convert to YYYY-MM-DD format for plan_rotation
            current_date = current_date_obj.strftime('%Y-%m-%d')
        except ValueError:
            print(f"\nError: Current date must be in MM-DD-YYYY format (e.g., 11-19-2025)")
            sys.exit(1)

        matches = []
        print("\nEnter details for next 3 matches:")

        for i in range(3):
            print(f"\nMatch {i+1}:")
            match_date_input = input("  Date (MM-DD): ").strip()
            imp_input = input("  Importance (Low/Medium/High/Sharpness): ").strip().lower()

            if imp_input in ['l', 'low']:
                importance = 'Low'
            elif imp_input in ['h', 'high']:
                importance = 'High'
            elif imp_input in ['s', 'sharpness']:
                importance = 'Sharpness'
            else:
                importance = 'Medium'

            # Infer year and convert to YYYY-MM-DD format
            try:
                match_date = selector._infer_year(match_date_input, current_date_obj)
            except ValueError as e:
                print(f"\nError: {str(e)}")
                sys.exit(1)

            matches.append((match_date, importance))

        # Plan rotation
        selector.plan_rotation(current_date, matches)

        # Training recommendations
        selector.suggest_training_focus()

    except FileNotFoundError:
        print(f"\nError: File '{filepath}' not found!")
        sys.exit(1)
    except KeyboardInterrupt:
        print("\n\nOperation cancelled by user.")
        sys.exit(0)
    except Exception as e:
        print(f"\nError: {str(e)}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
