#!/usr/bin/env python3
"""
FM26 Match-Ready Lineup Selector
Advanced lineup selection considering match sharpness, physical condition,
fatigue, positional skill ratings, and match scheduling for intelligent rotation.

Author: Doug Mason (2025)
"""

import sys
import pandas as pd
import numpy as np
from scipy.optimize import linear_sum_assignment
from datetime import datetime, timedelta
from typing import Dict, List, Tuple, Optional


class MatchReadySelector:
    """
    Intelligent team selector that factors in player condition, fatigue,
    match sharpness, and fixture scheduling for optimal rotation.
    """

    def __init__(self, status_filepath: str, abilities_filepath: Optional[str] = None,
                 training_recommendations_filepath: Optional[str] = None):
        """
        Initialize the selector with player data.

        Args:
            status_filepath: Path to CSV with positional skill ratings & status (players-current.csv)
            abilities_filepath: Optional path to CSV with role ability ratings (players.csv)
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

        # Load abilities file (players.csv)
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
            print("For best results, provide both files:")
            print("  python fm_match_ready_selector.py players-current.csv players.csv\n")

        # Convert numeric columns
        numeric_columns = [
            'Age', 'CA', 'PA', 'Condition', 'Fatigue', 'Match Sharpness',
            'Natural Fitness', 'Stamina', 'Work Rate',
            'GoalKeeper', 'Defender Right', 'Defender Center', 'Defender Left',
            'Defensive Midfielder', 'Attacking Mid. Right', 'Attacking Mid. Center',
            'Attacking Mid. Left', 'Striker'
        ]

        # Add role ability columns if they exist
        ability_columns = ['Striker', 'AM(L)', 'AM(C)', 'AM(R)', 'DM(L)', 'DM(R)',
                          'D(C)', 'D(R/L)', 'GK']
        for col in ability_columns:
            if col in self.df.columns:
                numeric_columns.append(col)

        for col in numeric_columns:
            if col in self.df.columns:
                self.df[col] = pd.to_numeric(self.df[col], errors='coerce')

        # Create DM_avg for abilities if we have them
        if 'DM(L)' in self.df.columns and 'DM(R)' in self.df.columns:
            self.df['DM_avg'] = (self.df['DM(L)'] + self.df['DM(R)']) / 2

        # Formation for 4-2-3-1
        # Format: (pos_name, skill_rating_column, ability_rating_column or None)
        if self.has_abilities:
            self.formation = [
                ('GK', 'GoalKeeper', 'GK'),
                ('DL', 'Defender Left', 'D(R/L)'),
                ('DC1', 'Defender Center', 'D(C)'),
                ('DC2', 'Defender Center', 'D(C)'),
                ('DR', 'Defender Right', 'D(R/L)'),
                ('DM(L)', 'Defensive Midfielder', 'DM_avg'),
                ('DM(R)', 'Defensive Midfielder', 'DM_avg'),
                ('AML', 'Attacking Mid. Left', 'AM(L)'),
                ('AMC', 'Attacking Mid. Center', 'AM(C)'),
                ('AMR', 'Attacking Mid. Right', 'AM(R)'),
                ('STC', 'Striker_skill', 'Striker_ability')  # Name collision handled
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

    def calculate_effective_rating(self, row: pd.Series, skill_col: str, ability_col: Optional[str] = None,
                                   match_importance: str = 'Medium',
                                   prioritize_sharpness: bool = False,
                                   position_name: Optional[str] = None) -> float:
        """
        Calculate effective rating considering familiarity, ability, and status factors.

        Args:
            row: Player data row
            skill_col: Positional skill rating column (1-20 familiarity)
            ability_col: Role ability rating column (0-200 quality) - optional
            match_importance: 'Low', 'Medium', or 'High'
            prioritize_sharpness: Give minutes to low-sharpness players
            position_name: Position being evaluated (for training bonus)

        Returns:
            Effective rating (lower is worse, can be negative)
        """
        # Check if player is available
        if row.get('Is Injured', False) or row.get('Banned', False):
            return -999.0

        # Get positional skill rating (familiarity 1-20)
        skill_rating = row.get(skill_col, 0)
        if pd.isna(skill_rating) or skill_rating < 1:
            return -999.0

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

        # 1. Apply positional familiarity penalty based on skill rating
        familiarity_penalty = self._get_familiarity_penalty(skill_rating)
        effective_rating *= (1 - familiarity_penalty)

        # 2. Match sharpness factor (5000-10000 scale)
        match_sharpness = row.get('Match Sharpness', 10000)
        if pd.notna(match_sharpness):
            sharpness_pct = match_sharpness / 10000

            if prioritize_sharpness and sharpness_pct < 0.85:
                # BOOST rating for low-sharpness players in unimportant matches
                effective_rating *= 1.1
            else:
                # Standard penalty for low sharpness
                if sharpness_pct < 0.60:
                    effective_rating *= 0.70
                elif sharpness_pct < 0.75:
                    effective_rating *= 0.85
                elif sharpness_pct < 0.85:
                    effective_rating *= 0.95

        # 3. Physical condition factor (percentage)
        condition = row.get('Condition', 100)
        if pd.notna(condition):
            # Normalize to 0-100 scale if stored as 0-10000
            if condition > 100:
                condition = condition / 100

            if condition < 60:
                effective_rating *= 0.60  # Severe penalty, injury risk
            elif condition < 75:
                effective_rating *= 0.80  # Moderate penalty
            elif condition < 90:
                effective_rating *= 0.95  # Minor penalty

        # 4. Fatigue penalty (critical threshold at 400)
        fatigue = row.get('Fatigue', 0)
        if pd.notna(fatigue):
            if fatigue >= 500:
                effective_rating *= 0.65  # Severe penalty
            elif fatigue >= 400:
                effective_rating *= 0.85  # Moderate penalty
            elif fatigue < -200:
                effective_rating *= 0.90

        # 5. Match importance modifier
        if match_importance == 'High':
            if fatigue >= 400 or condition < 80:
                effective_rating *= 0.85  # Extra penalty in important matches

        # 6. Training bonus for low/medium importance matches
        if (match_importance in ['Low', 'Medium'] and
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

        return effective_rating

    def _get_familiarity_penalty(self, rating: float) -> float:
        """Get penalty percentage based on positional rating tier."""
        if pd.isna(rating):
            return 0.40
        elif rating >= 18:  # Natural
            return 0.00
        elif rating >= 13:  # Accomplished
            return 0.10
        elif rating >= 10:  # Competent
            return 0.15
        elif rating >= 6:   # Unconvincing
            return 0.20
        elif rating >= 5:   # Awkward
            return 0.35
        else:               # Ineffectual
            return 0.40

    def select_match_xi(self, match_importance: str = 'Medium',
                       prioritize_sharpness: bool = False,
                       rested_players: List[str] = None,
                       debug: bool = False) -> Dict:
        """
        Select optimal XI for a specific match.

        Args:
            match_importance: 'Low', 'Medium', or 'High'
            prioritize_sharpness: Give playing time to low-sharpness players
            rested_players: List of player names to rest (avoid selecting)
            debug: Enable detailed debug output

        Returns:
            Dictionary mapping position to (player_name, effective_rating, player_data)
        """
        if rested_players is None:
            rested_players = []

        # Filter out unavailable players BEFORE creating cost matrix
        # Remove: injured, banned, and rested players
        unavailable_mask = (
            (self.df['Is Injured'] == True) |
            (self.df['Banned'] == True) |
            (self.df['Name'].isin(rested_players))
        )
        available_df = self.df[~unavailable_mask].copy()
        available_df = available_df.reset_index(drop=False)  # Keep original index in 'index' column

        n_players = len(available_df)
        n_positions = len(self.formation)

        if debug:
            injured = self.df[self.df['Is Injured'] == True]['Name'].tolist()
            banned = self.df[self.df['Banned'] == True]['Name'].tolist()
            print(f"\n[DEBUG] Injured players: {injured}")
            print(f"[DEBUG] Banned players: {banned}")
            print(f"[DEBUG] Rested players: {rested_players}")
            print(f"[DEBUG] Total available players (after filtering): {n_players}")
            print(f"[DEBUG] Total positions to fill: {n_positions}")

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

                effective_rating = self.calculate_effective_rating(
                    player, skill_col, ability_col, match_importance, prioritize_sharpness, pos_name
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

        # Plan selection for each match
        self.match_selections = []
        players_to_rest = []

        for i, (match_date, importance, days_until) in enumerate(match_dates):
            print(f"\n{'=' * 100}")
            print(f"LINEUP FOR MATCH {i+1}: {match_date.strftime('%Y-%m-%d')} ({importance} importance, {days_until} days)")
            print("=" * 100)

            # Determine selection strategy
            prioritize_sharpness = (importance == 'Low')

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

    def _identify_players_to_rest(self) -> List[str]:
        """Identify players who should be rested (high fatigue or low condition)."""
        rest_candidates = []

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

        return rest_candidates

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

                    # Status icons
                    status_icons = []
                    if fatigue >= 400:
                        status_icons.append('💤')  # Fatigued
                    if condition < 80:
                        status_icons.append('❤️')  # Low condition
                    if sharpness < 0.80:
                        status_icons.append('🔄')  # Needs sharpness
                    if sharpness >= 0.95 and condition >= 90 and fatigue < 200:
                        status_icons.append('⭐')  # Peak form

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
        if prioritize_sharpness:
            print("Strategy: Prioritizing match sharpness development for fringe players")
        print("=" * 100)

        # Legend
        print("\nSTATUS ICONS:")
        print("  ⭐ Peak form (high condition, low fatigue, sharp)")
        print("  💤 High fatigue (≥400, needs rest)")
        print("  ❤️  Low condition (<80%, injury risk)")
        print("  🔄 Needs match sharpness (<80%)")
        print("  🎓 In position training (priority shown)")

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
                player_data = self.df[self.df['Name'] == player].iloc[0]
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
        elif os.path.exists('players.csv'):
            status_file = 'players.csv'
        elif os.path.exists('players.xlsx'):
            status_file = 'players.xlsx'

        # Look for abilities file
        if os.path.exists('players.csv') and status_file != 'players.csv':
            abilities_file = 'players.csv'

    # Look for training recommendations file
    training_file = None
    if os.path.exists('training_recommendations.csv'):
        training_file = 'training_recommendations.csv'

    if not status_file:
        print("Error: No player data file found!")
        print("\nUsage:")
        print("  python fm_match_ready_selector.py players-current.csv players.csv")
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
            imp_input = input("  Importance (Low/Medium/High): ").strip().lower()

            if imp_input in ['l', 'low']:
                importance = 'Low'
            elif imp_input in ['h', 'high']:
                importance = 'High'
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
