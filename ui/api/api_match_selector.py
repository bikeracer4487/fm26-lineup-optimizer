import sys
import os
import json
import contextlib
import pandas as pd
import numpy as np
from datetime import datetime
from copy import deepcopy

# Add root directory to sys.path to allow importing from root scripts
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../')))

from fm_match_ready_selector import MatchReadySelector, normalize_name
import data_manager
import rating_calculator

# Import new OR framework modules
from scoring_parameters import (
    get_context_parameters,
    get_importance_weight,
    ScoringContext
)
from ui.api.scoring_model import (
    calculate_match_utility,
    calculate_harmonic_mean,
    MultiplierBreakdown
)
from ui.api.state_simulation import (
    PlayerState,
    extract_player_state,
    simulate_match_impact,
    simulate_rest_recovery,
    project_condition_at_match
)
from ui.api.shadow_pricing import (
    calculate_shadow_costs,
    get_adjusted_utility,
    identify_players_to_preserve
)
from ui.api.explainability import (
    generate_selection_reason,
    generate_match_summary,
    SelectionExplanation
)
from ui.api.stability import (
    AssignmentHistory,
    AssignmentManager,
    compute_stability_costs,
    get_combined_stability_costs,
    StabilityConfig
)
from scoring_parameters import DEFAULT_STABILITY_CONFIG

@contextlib.contextmanager
def suppress_stdout():
    """Context manager to suppress stdout during initialization of parent class."""
    with open(os.devnull, 'w') as devnull:
        old_stdout = sys.stdout
        sys.stdout = devnull
        try:
            yield
        finally:
            sys.stdout = old_stdout

CONFIRMED_LINEUPS_PATH = os.path.join(os.path.dirname(__file__), '../data/confirmed_lineups.json')

class ApiMatchReadySelector(MatchReadySelector):
    """
    Wrapper around MatchReadySelector to adapt it for the UI API.
    Suppresses stdout and formats output as JSON-compatible structures.
    """

    def _load_consecutive_counts_from_history(self, current_date: str) -> dict:
        """
        Load confirmed lineups and calculate consecutive match counts.

        Args:
            current_date: The simulation start date (YYYY-MM-DD). Only count lineups before this date.

        Returns:
            Dict of player_name -> consecutive_match_count
        """
        if not os.path.exists(CONFIRMED_LINEUPS_PATH):
            return {}

        try:
            with open(CONFIRMED_LINEUPS_PATH, 'r') as f:
                data = json.load(f)

            lineups = data.get('lineups', [])

            # Filter to lineups before current_date, sorted by date (ascending)
            past_lineups = sorted(
                [l for l in lineups if l.get('date', '') < current_date],
                key=lambda x: x.get('date', '')
            )

            if not past_lineups:
                return {}

            # Calculate consecutive match streaks (from most recent backwards)
            player_counts = {}

            # Start with the most recent lineup - all players have 1 match
            most_recent = past_lineups[-1]
            recent_players = set(most_recent.get('selection', {}).values())
            for player in recent_players:
                if player:
                    player_counts[player] = 1

            # Walk backwards through lineups to extend streaks
            for i in range(len(past_lineups) - 2, -1, -1):
                lineup = past_lineups[i]
                lineup_players = set(lineup.get('selection', {}).values())

                # Check each player still with an active streak
                players_to_check = list(player_counts.keys())
                for player in players_to_check:
                    if player in lineup_players:
                        player_counts[player] += 1
                    else:
                        # Player missed this match - streak is BROKEN, remove from tracking
                        del player_counts[player]

            return player_counts

        except Exception as e:
            # If anything goes wrong, return empty dict (no historical data)
            return {}

    def _load_assignment_history_from_lineups(self, current_date: str) -> None:
        """
        Load confirmed lineups and populate assignment history for stability calculations.

        This enables the polyvalent stability mechanism which prevents oscillating
        assignments for versatile players.

        Args:
            current_date: The simulation start date (YYYY-MM-DD). Only load lineups before this date.
        """
        if not os.path.exists(CONFIRMED_LINEUPS_PATH):
            return

        try:
            with open(CONFIRMED_LINEUPS_PATH, 'r') as f:
                data = json.load(f)

            lineups = data.get('lineups', [])

            # Filter to lineups before current_date, sorted by date (ascending)
            past_lineups = sorted(
                [l for l in lineups if l.get('date', '') < current_date],
                key=lambda x: x.get('date', '')
            )

            # Load into assignment history (most recent first for stability calculation)
            for lineup in reversed(past_lineups):
                match_id = lineup.get('matchId', lineup.get('date', ''))
                selection = lineup.get('selection', {})

                # Record each player's position assignment
                for slot_id, player_name in selection.items():
                    if player_name:
                        self.assignment_manager.history.add_assignment(
                            match_id, player_name, slot_id
                        )

        except Exception as e:
            # If anything goes wrong, continue without history
            pass
            
    def __init__(self, status_filepath, abilities_filepath=None, training_filepath=None):
        # Automatically look for training recommendations in root if not provided
        if not training_filepath:
            root_training = os.path.join(os.path.dirname(__file__), '../../training_recommendations.csv')
            if os.path.exists(root_training):
                training_filepath = root_training

        # Initialize parent with suppressed output
        with suppress_stdout():
            super().__init__(status_filepath, abilities_filepath, training_filepath)
            
        # Data Repair for Single-File Mode
        if self.has_abilities:
            # 1. Restore Ability Columns
            # The merge renamed columns to {col}_ability. We need them back as {col} for calculation logic.
            merged_cols = ['AM(L)', 'AM(C)', 'AM(R)', 'DM(L)', 'DM(R)', 'D(C)', 'D(R/L)', 'GK', 'Striker']
            
            for col in merged_cols:
                ability_col = f"{col}_ability"
                if ability_col in self.df.columns:
                    self.df[col] = self.df[ability_col]
                    
            # 2. Fix Formation Mapping (Striker)
            # MatchReadySelector uses ('STC', 'Striker_skill', 'Striker_ability') by default.
            # 'Striker_skill' (from merge) is currently Ability score (140) because of name collision.
            # We need to point it to 'Striker_Familiarity' which we preserved in data_manager.py.
            
            new_formation = []
            for pos in self.formation:
                pos_name = pos[0]
                if pos_name == 'STC':
                    # Point skill to Familiarity column, ability to Ability column
                    # Note: 'Striker' was restored in Step 1 to be the Ability Score
                    new_formation.append(('STC', 'Striker_Familiarity', 'Striker'))
                else:
                    new_formation.append(pos)
            self.formation = new_formation

        # Initialize stability tracking for polyvalent player management
        self.assignment_manager = AssignmentManager(config=DEFAULT_STABILITY_CONFIG)
            
    def calculate_effective_rating(self, row: pd.Series, skill_col: str, ability_col: str = None,
                                   match_importance: str = 'Medium',
                                   prioritize_sharpness: bool = False,
                                   position_name: str = None,
                                   player_tier: str = None,
                                   position_tier: int = 3) -> float:
        """
        Override to handle tactic-based pre-calculated ratings and loan logic.

        When using tactic config, skill_col is 'Final_XXX' containing a pre-calculated
        combined rating (0-200 scale) that already includes familiarity penalties.
        In that case, we use it directly and only apply condition/fatigue adjustments.
        """
        # Check if player is injured
        if row.get('Is Injured', False):
            return -999.0

        # TACTIC MODE: skill_col is a pre-calculated rating column (e.g., 'Final_D_L')
        # These already include IP/OOP role ratings and familiarity from rating_calculator
        if skill_col.startswith('Final_'):
            base_rating = row.get(skill_col, 0)
            if pd.isna(base_rating) or base_rating <= 0:
                return -999.0

            effective_rating = float(base_rating)

            # Apply condition penalty - research-based non-linear modifiers
            # Source: docs/Research/physical-condition-claude.md
            # Key thresholds: 100%=1.0, 90%=0.95, 85%=0.89, 80%=0.80, 70%=0.68
            condition = row.get('Condition', 10000)
            if pd.notna(condition):
                cond_pct = condition / 10000 if condition > 100 else condition / 100

                # Research-based modifiers (non-linear, accelerating penalty below 80%)
                if cond_pct >= 1.0:
                    cond_modifier = 1.00
                elif cond_pct >= 0.90:
                    # Linear interpolation: 90-100% → 0.95-1.00
                    cond_modifier = 0.95 + (cond_pct - 0.90) * 0.5
                elif cond_pct >= 0.85:
                    # Linear interpolation: 85-90% → 0.89-0.95
                    cond_modifier = 0.89 + (cond_pct - 0.85) * 1.2
                elif cond_pct >= 0.80:
                    # Linear interpolation: 80-85% → 0.80-0.89
                    cond_modifier = 0.80 + (cond_pct - 0.80) * 1.8
                elif cond_pct >= 0.70:
                    # Linear interpolation: 70-80% → 0.68-0.80
                    cond_modifier = 0.68 + (cond_pct - 0.70) * 1.2
                else:
                    # Below 70% - severe degradation
                    cond_modifier = 0.68 * (cond_pct / 0.70)

                # Additional match importance scaling for players below 85% threshold
                # Research: "85% condition minimum for starting players"
                if cond_pct < 0.85:
                    if match_importance == 'High':
                        cond_modifier *= 0.30  # Near-prohibition: 30% of already-penalized rating
                    elif match_importance == 'Medium':
                        cond_modifier *= 0.70  # Heavy penalty: 70% of already-penalized rating

                effective_rating *= cond_modifier

            # Apply fatigue penalty - personalized thresholds per player
            # Uses player attributes: age, natural fitness, stamina, injury proneness
            fatigue = row.get('Fatigue', 0)
            if pd.notna(fatigue) and fatigue > 0:
                age = row.get('Age', 25)
                natural_fitness = row.get('Natural Fitness', 10)
                stamina = row.get('Stamina', 10)
                injury_proneness = row.get('Injury Proneness', None)

                # Calculate personalized threshold (calls parent method)
                threshold = self._get_adjusted_fatigue_threshold(age, natural_fitness, stamina, injury_proneness)

                if fatigue >= threshold + 100:
                    effective_rating *= 0.65  # Severe - well above threshold
                elif fatigue >= threshold:
                    effective_rating *= 0.85  # Moderate - at threshold
                elif fatigue >= threshold - 50:
                    effective_rating *= 0.95  # Minor - approaching threshold

            # Apply match sharpness factor
            match_sharpness = row.get('Match Sharpness', 10000)
            if pd.notna(match_sharpness):
                sharpness_pct = match_sharpness / 10000 if match_sharpness > 100 else match_sharpness / 100
                if sharpness_pct < 0.60:
                    effective_rating *= 0.85  # Severe rust
                elif sharpness_pct < 0.80:
                    effective_rating *= 0.92  # Lacking sharpness
                elif sharpness_pct < 0.91:
                    effective_rating *= 0.97  # Not quite match ready

            # Apply loan logic
            loan_status = row.get('LoanStatus', 'Own')
            if loan_status == 'LoanedIn':
                if match_importance == 'Low':
                    effective_rating *= 0.85
                elif match_importance == 'Medium':
                    effective_rating *= 0.95

            return effective_rating

        # LEGACY MODE: Use parent's calculation for traditional familiarity-based ratings
        effective_rating = super().calculate_effective_rating(
            row, skill_col, ability_col, match_importance, prioritize_sharpness, position_name, player_tier,
            position_tier=position_tier
        )

        if effective_rating <= -998.0:
            return effective_rating

        # Apply Loan Logic
        loan_status = row.get('LoanStatus', 'Own')
        if loan_status == 'LoanedIn':
            if match_importance == 'Low':
                effective_rating *= 0.85
            elif match_importance == 'Medium':
                effective_rating *= 0.95

        return effective_rating
            
    def generate_plan(self, matches_data, rejected_players_map, manual_overrides_map=None, tactic_config=None):
        """
        Generate a match plan using the core logic from MatchReadySelector.

        Args:
            matches_data: List of dicts {id, date, importance, opponent, manualOverrides}
            rejected_players_map: Dict of match_id (str) -> list of player names (manual rejections)
            manual_overrides_map: Dict of match_id (str) -> dict of position -> player name
            tactic_config: Dict with ipPositions, oopPositions, mapping
        """
        
        # ---------------------------------------------------------------------
        # TACTICS CONFIGURATION LOGIC
        # ---------------------------------------------------------------------
        if tactic_config:
            # 1. Parse config
            ip_positions = tactic_config.get('ipPositions', {})
            oop_positions = tactic_config.get('oopPositions', {})
            mapping = tactic_config.get('mapping', {})

            # 2. Identify active slots (those with an IP role selected)
            active_slots = [slot for slot, role in ip_positions.items() if role]

            # If no active slots, fall back to default formation
            if not active_slots:
                pass  # Keep default formation from parent class
            else:
                # 3. Build new formation list and calculate ratings
                new_formation = []

                # Map for visual display names (standardized)
                slot_display_names = {
                    'GK': 'GK',
                    'D_L': 'D(L)', 'D_CL': 'D(C)L', 'D_C': 'D(C)', 'D_CR': 'D(C)R', 'D_R': 'D(R)',
                    'WB_L': 'WB(L)', 'DM_L': 'DM(L)', 'DM_C': 'DM(C)', 'DM_R': 'DM(R)', 'WB_R': 'WB(R)',
                    'M_L': 'M(L)', 'M_CL': 'M(C)L', 'M_C': 'M(C)', 'M_CR': 'M(C)R', 'M_R': 'M(R)',
                    'AM_L': 'AM(L)', 'AM_CL': 'AM(C)L', 'AM_C': 'AM(C)', 'AM_CR': 'AM(C)R', 'AM_R': 'AM(R)',
                    'ST_L': 'ST(L)', 'ST_C': 'ST(C)', 'ST_R': 'ST(R)'
                }

                for slot in active_slots:
                    ip_role = ip_positions.get(slot)
                    oop_slot = mapping.get(slot, slot) # Default to self if not mapped
                    oop_role = oop_positions.get(oop_slot)

                    # FALLBACK: If OOP role is missing, use IP role for both phases
                    # This handles configurations where only IP is set up
                    if ip_role and not oop_role:
                        oop_slot = slot
                        oop_role = ip_role

                    if ip_role and oop_role:
                        # Helper to map slot to position key for familiarity lookup
                        # IMPORTANT: Check exact endings, not just presence of L/R
                        # D_L = left fullback, D_R = right fullback
                        # D_CL, D_CR, D_C = center-backs (all use D(C) familiarity)
                        def get_pos_key(s):
                            if s == 'GK': return 'GK'
                            if s.startswith('D_'):
                                # D_L = left fullback, D_R = right fullback
                                # D_C, D_CL, D_CR = center-backs
                                if s == 'D_L': return 'D(L)'
                                if s == 'D_R': return 'D(R)'
                                return 'D(C)'  # D_C, D_CL, D_CR all map to center-back
                            if s.startswith('WB_'):
                                if s == 'WB_L': return 'WB(L)'
                                if s == 'WB_R': return 'WB(R)'
                                return 'WB(C)'
                            if s.startswith('DM_'): return 'DM'
                            if s.startswith('M_'):
                                if s == 'M_L': return 'M(L)'
                                if s == 'M_R': return 'M(R)'
                                return 'M(C)'  # M_C, M_CL, M_CR
                            if s.startswith('AM_'):
                                if s == 'AM_L': return 'AM(L)'
                                if s == 'AM_R': return 'AM(R)'
                                return 'AM(C)'  # AM_C, AM_CL, AM_CR
                            if s.startswith('ST_'): return 'ST'
                            return 'Unknown'

                        ip_pos_key = get_pos_key(slot)
                        oop_pos_key = get_pos_key(oop_slot)

                        # Calculate combined IP/OOP rating for all players
                        # rating_calculator.calculate_combined_rating() already includes:
                        # - Position base weights from FM Arena testing
                        # - Role-specific attribute modifiers
                        # - Familiarity penalties (added in rating_calculator.py)
                        # IMPORTANT: Use default arguments to capture values at definition time
                        final_col = f"Final_{slot}"

                        self.df[final_col] = self.df.apply(
                            lambda row, ip=ip_pos_key, ir=ip_role, op=oop_pos_key, orole=oop_role:
                                rating_calculator.calculate_combined_rating(
                                    row.to_dict(), ip, ir, op, orole
                                ), axis=1
                        )

                        # Formation tuple: (slot_id, rating_column, unused)
                        # The rating_column is used by calculate_effective_rating
                        new_formation.append((slot, final_col, None))

                # Apply new formation
                self.formation = new_formation
        # else: no tactic_config provided, use default formation from parent class

        # ---------------------------------------------------------------------

        results = []

        # Get the current date from the first match (or use empty string if no matches)
        current_date = matches_data[0].get('date', '') if matches_data else ''

        # Initialize player_match_count from confirmed lineups history
        self.player_match_count = self._load_consecutive_counts_from_history(current_date)

        # Load assignment history for stability calculations (polyvalent player management)
        self._load_assignment_history_from_lineups(current_date)

        # Configure stability settings from tactic config
        if tactic_config:
            inertia_weight = tactic_config.get('stabilityWeight', 0.5)
            # Update stability config with user preference
            self.assignment_manager.config = StabilityConfig(
                inertia_weight=inertia_weight,
                base_switch_cost=DEFAULT_STABILITY_CONFIG.base_switch_cost,
                continuity_bonus=DEFAULT_STABILITY_CONFIG.continuity_bonus,
                anchor_multiplier=DEFAULT_STABILITY_CONFIG.anchor_multiplier,
                anchor_threshold=DEFAULT_STABILITY_CONFIG.anchor_threshold
            )

        # For rotation logic, we might need to auto-rest players
        auto_rested_players = []

        # Default empty dict for manual overrides
        if manual_overrides_map is None:
            manual_overrides_map = {}

        # ---------------------------------------------------------------------
        # RHC SHADOW PRICING: Calculate shadow costs for all players
        # This enables proactive rotation by quantifying the "opportunity cost"
        # of using a player now vs. saving them for a future important match
        # ---------------------------------------------------------------------
        training_intensity = 'Medium'
        if tactic_config:
            training_intensity = tactic_config.get('trainingIntensity', 'Medium')

        shadow_costs = self._calculate_shadow_costs_for_plan(matches_data, training_intensity)

        # Identify players with highest shadow costs (most valuable to preserve)
        # Used for informational purposes in explanations
        players_to_preserve = identify_players_to_preserve(shadow_costs, 0, top_n=5)

        for i, match in enumerate(matches_data):
            # Get unique match ID for rejection/override lookups
            match_id = match.get('id', str(i))

            importance = match.get('importance', 'Medium')
            prioritize_sharpness = (importance in ['Low', 'Sharpness'])
            match_date_str = match.get('date')

            # Get manual overrides for this match (from match data or from map by match ID)
            match_overrides = match.get('manualOverrides', {}) or manual_overrides_map.get(match_id, {})

            # FIX: Clear proactive rests for High priority matches - we want best XI
            # auto_rested_players from previous iteration should not affect High priority selection
            if importance == 'High':
                auto_rested_players = []

            # Combine manual rejections (by match ID) with auto-rested players
            manual_rejections = rejected_players_map.get(match_id, [])
            current_rested = list(set(manual_rejections + auto_rested_players))

            # Also exclude manually overridden players from being selected for other positions
            overridden_players = list(match_overrides.values())
            current_rested = list(set(current_rested + overridden_players))

            # Look-ahead: Rest First XI players who won't recover for upcoming High priority match
            # Only applies to Low/Medium priority matches when next match is High
            if importance in ['Low', 'Medium'] and i < len(matches_data) - 1:
                next_match = matches_data[i + 1]
                if next_match.get('importance') == 'High':
                    # Get First XI player names from parent class
                    first_xi_names = self._get_first_xi_players()

                    for player_name in first_xi_names:
                        # Find player data
                        player_row = self.df[self.df['Name_Normalized'] == normalize_name(player_name)]
                        if not player_row.empty:
                            player = player_row.iloc[0]
                            if self._should_rest_for_upcoming_high_priority(player, i, matches_data, match):
                                if player_name not in current_rested:
                                    current_rested.append(player_name)

            # Filter formation to exclude overridden positions
            # This allows players who would be assigned to overridden positions
            # to be reassigned to other equivalent positions (e.g., DC2 when DC1 is overridden)
            overridden_positions = set(match_overrides.keys())
            filtered_formation = [pos for pos in self.formation if pos[0] not in overridden_positions]

            # Compute stability costs for polyvalent player management
            # This prevents oscillating assignments for versatile players
            formation_to_use = filtered_formation if overridden_positions else self.formation
            player_names = self.df['Name'].tolist()
            slot_ids = [pos[0] for pos in formation_to_use]

            prev_assignment = self.assignment_manager.get_previous_assignment_map()
            stability_cost_matrix = get_combined_stability_costs(
                player_names, slot_ids, prev_assignment,
                self.assignment_manager.history,
                self.assignment_manager.config
            )

            # Create index mappings for the cost matrix
            player_name_to_idx = {name: i for i, name in enumerate(player_names)}
            slot_id_to_idx = {slot: j for j, slot in enumerate(slot_ids)}

            # Select XI using parent logic with filtered formation and stability costs
            # select_match_xi returns: Dict[pos, (player_name, effective_rating, player_data)]
            selection_raw = self.select_match_xi(
                importance, prioritize_sharpness, current_rested,
                formation_override=filtered_formation if overridden_positions else None,
                stability_costs=stability_cost_matrix,
                player_name_to_idx=player_name_to_idx,
                slot_id_to_idx=slot_id_to_idx
            )

            # Apply manual overrides - merge into results after optimization
            for pos, player_name in match_overrides.items():
                # Find player data for the overridden player (use Name_Normalized for Unicode-safe comparison)
                player_row = self.df[self.df['Name_Normalized'] == normalize_name(player_name)]
                if not player_row.empty:
                    player_data = player_row.iloc[0].to_dict()
                    # Use a dummy rating for manual selections (we don't recalculate)
                    selection_raw[pos] = (player_name, 0.0, player_data)
            
            # Get scoring context for this match (used for explanations)
            scoring_context = get_context_parameters(importance, training_intensity)

            # Find next High importance match for explanation context
            next_high_match, next_high_idx = self._find_next_high_importance_match(matches_data, i)

            # Transform to UI format
            selection_formatted = {}
            for pos, (name, rating, player_data) in selection_raw.items():
                # Normalize Condition to 0-1.0 range for UI display
                raw_condition = player_data.get('Condition', 100)
                normalized_condition = raw_condition / 10000.0 if raw_condition > 100 else raw_condition / 100.0

                # Get player's shadow cost for this match
                player_shadow_cost = 0.0
                if name in shadow_costs and i < len(shadow_costs[name]):
                    player_shadow_cost = shadow_costs[name][i]

                selection_formatted[pos] = {
                    "name": name,
                    "nameNormalized": normalize_name(name),  # For frontend to use when storing rejections
                    "rating": rating,
                    "condition": normalized_condition,
                    "shadowCost": round(player_shadow_cost, 1),  # Include shadow cost for UI
                    "fatigue": player_data.get('Fatigue', 0),
                    "sharpness": player_data.get('Match Sharpness', 10000) / 10000,
                    "age": player_data.get('Age', 25),
                    "status": self._get_player_status_flags_ui(player_data)
                }
            
            results.append({
                "matchIndex": i,
                "matchId": match_id,  # Return match ID for frontend correlation
                "date": match_date_str,
                "importance": importance,
                "selection": selection_formatted
            })

            # Update consecutive counts (logic from parent class)
            self._update_consecutive_match_counts(selection_raw)

            # Record assignments for stability tracking (polyvalent player management)
            # This updates the assignment history for the next iteration's stability costs
            assignment_lineup = {pos: name for pos, (name, _, _) in selection_raw.items()}
            self.assignment_manager.record_match_assignments(match_id, assignment_lineup)
            
            # MATCH ROTATION LOGIC
            # Check if we should rest players for the NEXT match
            # Now includes PROACTIVE ROTATION - looks ahead for high priority matches
            auto_rested_players = [] # Reset for next iteration

            if i < len(matches_data) - 1:
                upcoming_matches = matches_data[i+1:]  # All future matches for lookahead

                # Pass upcoming matches to enable proactive rotation planning
                # This allows resting players who would hit rotation threshold by high priority match
                auto_rested_players = self._identify_players_to_rest(upcoming_matches=upcoming_matches)
                        
        return results

    def _get_player_status_flags_ui(self, player):
        """
        Generate status flags for the UI, matching logic in _print_match_selection.
        """
        flags = []
        fatigue = player.get('Fatigue', 0)
        
        condition = player.get('Condition', 100)
        if condition > 100: condition /= 100
        
        sharpness = player.get('Match Sharpness', 10000) / 10000
        age = player.get('Age', 25)
        stamina = player.get('Stamina', 15)
        natural_fitness = player.get('Natural Fitness', 15)
        injury_proneness = player.get('Injury Proneness', 10)
        
        # Calculate personalized fatigue threshold
        threshold = self._get_adjusted_fatigue_threshold(age, natural_fitness, stamina, injury_proneness)
        
        # Status mapping
        if fatigue >= threshold + 100:
            flags.append("Need Vacation")
        elif fatigue >= threshold:
            flags.append("Fatigued")
            
        if condition < 0.80:
            flags.append("Low Condition")
            
        if sharpness < 0.80:
            flags.append("Low Sharpness")
            
        # Peak form logic
        if sharpness >= 0.95 and condition >= 0.90 and fatigue < 200:
            flags.append("Peak Form")
        
        if pd.notna(age) and age >= 32:
            flags.append("Veteran Risk")
        
        # Check consecutive matches
        name = player['Name']
        if name in self.player_match_count:
            consecutive = self.player_match_count[name]
            if consecutive >= 3:
                flags.append("Rotation Risk") # Replaced "Overplayed"
                
        if pd.notna(stamina) and stamina < 10:
            flags.append("Low Stamina")
            
        if pd.notna(natural_fitness) and natural_fitness < 10:
            flags.append("Low Fitness")

        if pd.notna(injury_proneness) and injury_proneness >= 15:
             flags.append("Injury Prone")
            
        # Loan Status
        if player.get('LoanStatus') == 'LoanedIn':
            flags.append("Loaned In")

        return flags

    def _should_rest_for_upcoming_high_priority(self, player, current_match_idx: int,
                                                 matches_data: list, match: dict) -> bool:
        """
        Check if a First XI player should be rested to preserve condition for upcoming High match.

        Based on research from docs/Research/physical-condition-claude.md:
        - Post-match condition: ~75% (varies by Natural Fitness: 66-74%)
        - Recovery: Day 2 = 83%, Day 3 = 90%, Day 5 = 95%
        - Critical threshold: 85% condition minimum for starting players

        Only applies to:
        - Low/Medium priority current matches
        - When next match is High priority
        - First XI players (determined by caller)

        Args:
            player: Player row from DataFrame
            current_match_idx: Index of current match in matches_data
            matches_data: List of all matches
            match: Current match dict with 'date' and 'importance'

        Returns:
            True if player should be rested, False otherwise
        """
        from datetime import datetime

        # Only check if there's a next match
        if current_match_idx >= len(matches_data) - 1:
            return False

        next_match = matches_data[current_match_idx + 1]

        # Only apply for Low/Medium priority current matches
        current_importance = match.get('importance', 'Medium')
        if current_importance == 'High':
            return False

        # Only care if next match is High priority
        if next_match.get('importance') != 'High':
            return False

        # Calculate days between matches
        try:
            current_date = datetime.strptime(match.get('date', ''), '%Y-%m-%d')
            next_date = datetime.strptime(next_match.get('date', ''), '%Y-%m-%d')
            days_between = (next_date - current_date).days
        except (ValueError, TypeError):
            return False  # Can't parse dates, don't rest

        # If 3+ days between matches, player will recover to 90%+ (above 85% threshold)
        if days_between >= 3:
            return False

        # Estimate post-match condition based on Natural Fitness
        # Research: 20 NF = 74% post-match, low NF = 66% post-match
        natural_fitness = player.get('Natural Fitness', 10)
        if natural_fitness >= 18:
            post_match_condition = 0.74
        elif natural_fitness >= 14:
            post_match_condition = 0.72
        elif natural_fitness >= 10:
            post_match_condition = 0.70
        else:
            post_match_condition = 0.66

        # Project condition recovery based on days between matches
        # Recovery table: Day 2 = 83%, Day 3 = 90%, Day 5 = 95%
        if days_between >= 5:
            projected_condition = 0.95
        elif days_between >= 3:
            projected_condition = 0.90
        elif days_between >= 2:
            projected_condition = 0.83
        elif days_between == 1:
            # One day recovery - very limited
            projected_condition = post_match_condition + 0.05  # Rough estimate
        else:
            projected_condition = post_match_condition  # Same day or back-to-back

        # If projected condition < 85% threshold, rest the player
        return projected_condition < 0.85

    def _calculate_shadow_costs_for_plan(
        self,
        matches_data: list,
        training_intensity: str = 'Medium'
    ) -> dict:
        """
        Calculate shadow costs for all players across the match horizon.

        Shadow costs represent the "opportunity cost" of using a player now
        vs. saving them for a future high-importance match.

        Uses the formula from research:
        Cost_shadow(p, k) = Sum_{m=k+1}^{4} (
            (Imp_m / Imp_avg) * (Utility(p,m) / DeltaDays_{k,m}) * IsKeyPlayer(p)
        )

        Args:
            matches_data: List of match dicts
            training_intensity: Club's training intensity setting

        Returns:
            Dict of player_name -> [shadow_cost_at_match_0, ...]
        """
        players = self.df.to_dict('records')

        # Build player ratings dict (use CA as proxy for general utility)
        player_ratings = {}
        for player in players:
            name = player.get('Name', '')
            # Use CA as general utility proxy for shadow pricing
            player_ratings[name] = {'general': player.get('CA', 100)}

        return calculate_shadow_costs(
            players,
            matches_data,
            player_ratings,
            training_intensity
        )

    def _get_harmonic_mean_rating(
        self,
        player_data: dict,
        ip_rating: float,
        oop_rating: float
    ) -> float:
        """
        Calculate the Harmonic Mean of IP and OOP ratings.

        B_{i,s} = 2 * R_IP * R_OOP / (R_IP + R_OOP)

        This penalizes imbalance - a player with {180, 20} scores 36,
        while a balanced {100, 100} scores 100.

        Args:
            player_data: Player data dict (for potential attribute adjustments)
            ip_rating: In-Possession role rating (0-200)
            oop_rating: Out-of-Possession role rating (0-200)

        Returns:
            Harmonic mean rating (0-200)
        """
        return calculate_harmonic_mean(ip_rating, oop_rating)

    def _generate_explanation_for_player(
        self,
        player_data: dict,
        position: str,
        context: ScoringContext,
        multipliers: dict,
        is_selected: bool,
        shadow_cost: float = 0.0,
        next_high_match: dict = None,
        projected_condition: float = None
    ) -> dict:
        """
        Generate explanation for a player selection decision.

        Args:
            player_data: Player data dict
            position: Position considered
            context: Scoring context
            multipliers: Dict of multiplier values
            is_selected: Whether player was selected
            shadow_cost: Shadow pricing cost
            next_high_match: Next high importance match info
            projected_condition: Projected condition for next match

        Returns:
            Dict with explanation fields for UI display
        """
        explanation = generate_selection_reason(
            player_data,
            position,
            context,
            multipliers,
            is_selected,
            shadow_cost,
            next_high_match,
            projected_condition
        )

        return {
            'reason': explanation.primary_reason,
            'secondaryReasons': explanation.secondary_reasons,
            'warnings': explanation.warnings,
            'multipliers': explanation.multiplier_breakdown,
            'projectedCondition': explanation.projected_condition
        }

    def _find_next_high_importance_match(
        self,
        matches_data: list,
        current_idx: int
    ) -> tuple:
        """
        Find the next High importance match after current index.

        Args:
            matches_data: List of match dicts
            current_idx: Current match index

        Returns:
            Tuple of (match_dict, match_index) or (None, None)
        """
        for i in range(current_idx + 1, len(matches_data)):
            if matches_data[i].get('importance') == 'High':
                return matches_data[i], i
        return None, None

# --- Custom JSON Encoder to handle numpy types ---
class NumpyEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, (np.int_, np.intc, np.intp, np.int8,
                            np.int16, np.int32, np.int64, np.uint8,
                            np.uint16, np.uint32, np.uint64)):
            return int(obj)
        elif isinstance(obj, (np.float_, np.float16, np.float32, 
                              np.float64)):
            return float(obj)
        elif isinstance(obj, (np.ndarray,)):
            return obj.tolist()
        elif isinstance(obj, (np.bool_)):
            return bool(obj)
        return json.JSONEncoder.default(self, obj)

def main():
    try:
        # Read JSON from stdin
        input_str = sys.stdin.read()
        if not input_str:
            return

        data = json.loads(input_str)
        
        # 1. UPDATE DATA FROM EXCEL
        # Use the new data_manager to refresh from Paste Full sheet
        # This updates players-current.csv
        with suppress_stdout():
            data_manager.update_player_data()
        
        # 2. Use players-current.csv for BOTH status and abilities
        # data_manager.py now puts calculated skill ratings into players-current.csv
        status_file = 'players-current.csv'
        abilities_file = 'players-current.csv' 
        
        # Initialize wrapper
        selector = ApiMatchReadySelector(status_file, abilities_file)
        
        matches = data.get('matches', [])
        rejected = data.get('rejected', {}) # { "0": ["Player A"], "1": [] }
        tactic_config = data.get('tacticConfig', None)
        
        plan = selector.generate_plan(matches, rejected, tactic_config=tactic_config)
        
        print(json.dumps({"success": True, "plan": plan}, cls=NumpyEncoder))
        
    except Exception as e:
        import traceback
        print(json.dumps({"success": False, "error": f"{str(e)}: {traceback.format_exc()}"}))

if __name__ == '__main__':
    main()
