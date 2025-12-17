import sys
import os
import json
import contextlib
import pandas as pd
import numpy as np
from datetime import datetime

# Add root directory to sys.path to allow importing from root scripts
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../')))

from fm_match_ready_selector import MatchReadySelector, normalize_name
import data_manager
import rating_calculator

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
            
    def calculate_effective_rating(self, row: pd.Series, skill_col: str, ability_col: str = None,
                                   match_importance: str = 'Medium',
                                   prioritize_sharpness: bool = False,
                                   position_name: str = None,
                                   player_tier: str = None,
                                   position_tier: int = 3) -> float:
        """
        Override to apply loan logic penalties.
        """
        # Call parent method
        effective_rating = super().calculate_effective_rating(
            row, skill_col, ability_col, match_importance, prioritize_sharpness, position_name, player_tier,
            position_tier=position_tier
        )
        
        if effective_rating <= -998.0:
            return effective_rating
            
        # Apply Loan Logic
        # 'LoanStatus' added by data_manager.py ('Own' or 'LoanedIn')
        # Note: LoanedOut players are filtered out by data_manager
        loan_status = row.get('LoanStatus', 'Own')
        
        if loan_status == 'LoanedIn':
            if match_importance == 'Low':
                # Much lower priority
                effective_rating *= 0.85
            elif match_importance == 'Medium':
                # Slightly lower priority
                effective_rating *= 0.95
            # High importance: Unaffected
            
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
                
                if ip_role and oop_role:
                    # Calculate position keys for rating_calculator
                    # Extract base position from slot (e.g. D_L -> D(L))
                    # Or use SLOT_TO_DATA_KEY logic from frontend
                    # Helper to map slot to position key
                    def get_pos_key(s):
                        if s == 'GK': return 'GK'
                        if s.startswith('D_'): 
                            if 'L' in s: return 'D(L)'
                            if 'R' in s: return 'D(R)'
                            return 'D(C)'
                        if s.startswith('WB_'): return s.replace('_', '(').replace('L', 'L)').replace('R', 'R)')
                        if s.startswith('DM_'): return 'DM'
                        if s.startswith('M_'):
                            if 'L' in s: return 'M(L)'
                            if 'R' in s: return 'M(R)'
                            return 'M(C)'
                        if s.startswith('AM_'):
                            if 'L' in s: return 'AM(L)'
                            if 'R' in s: return 'AM(R)'
                            return 'AM(C)'
                        if s.startswith('ST_'): return 'ST'
                        return 'Unknown'

                    ip_pos_key = get_pos_key(slot)
                    oop_pos_key = get_pos_key(oop_slot)
                    
                    # Column name for this specific slot rating
                    rating_col = f"Rating_{slot}"
                    
                    # Calculate for all players
                    # Use apply with rows converted to dict
                    # Note: doing this in loop might be slow, but safe
                    # Vectorizing would be better but requires complex attribute mapping
                    self.df[rating_col] = self.df.apply(
                        lambda row: rating_calculator.calculate_combined_rating(
                            row.to_dict(), 
                            ip_pos_key, ip_role, 
                            oop_pos_key, oop_role
                        ), axis=1
                    )
                    
                    # Add to formation
                    # Display name: Use IP pos (e.g. D(L)) or combined if different?
                    # The frontend expects keys like 'DL', 'GK' to map results.
                    # We should use the SLOT ID as the key returned to frontend!
                    # e.g. 'D_L'. The frontend can then map that to display.
                    
                    # Tuple: (PositionName, SkillCol, AbilityCol)
                    # We use the calculated rating for both Skill and Ability
                    # Skill applies familiarity penalty (if we had specific familiarity column?)
                    # Wait, calculate_combined_rating uses ATTRIBUTES. It is "Ability".
                    # "Skill" usually means Ability * Familiarity.
                    # We need a Familiarity column for this slot.
                    
                    # Determine Familiarity Column from Excel data
                    # e.g. 'D(L)_Familiarity'
                    # We need to map slot -> Familiarity Column
                    fam_col = None
                    if slot == 'GK': fam_col = 'GK_Familiarity'
                    elif slot == 'D_L': fam_col = 'D(L)_Familiarity'
                    elif slot == 'D_R': fam_col = 'D(R)_Familiarity'
                    elif 'D_' in slot: fam_col = 'D(C)_Familiarity' # Center defs
                    elif 'WB_L' in slot: fam_col = 'WB(L)_Familiarity'
                    elif 'WB_R' in slot: fam_col = 'WB(R)_Familiarity'
                    elif 'DM_' in slot: fam_col = 'DM_Familiarity'
                    elif 'M_L' in slot: fam_col = 'M(L)_Familiarity'
                    elif 'M_R' in slot: fam_col = 'M(R)_Familiarity'
                    elif 'M_' in slot: fam_col = 'M(C)_Familiarity'
                    elif 'AM_L' in slot: fam_col = 'AM(L)_Familiarity'
                    elif 'AM_R' in slot: fam_col = 'AM(R)_Familiarity'
                    elif 'AM_' in slot: fam_col = 'AM(C)_Familiarity'
                    elif 'ST_' in slot: fam_col = 'ST_Familiarity'
                    
                    if fam_col and fam_col not in self.df.columns:
                        # Fallback if specific column missing
                        fam_col = None
                    
                    # If we have familiarity, use it for "Skill" col (MatchReadySelector logic applies penalty to it?)
                    # Actually MatchReadySelector.calculate_effective_rating uses skill_col.
                    # If skill_col is 0-20 (Familiarity), it treats it as such?
                    # Let's check calculate_effective_rating in fm_match_ready_selector.
                    # It treats skill_col as "Current Ability / Rating".
                    # It DOES NOT apply familiarity penalty automatically if we pass a Rating.
                    # Wait, `fm_match_ready_selector.py` line 1356 calls `calculate_effective_rating`.
                    # Inside that:
                    # It uses `skill_val = row[skill_col]`.
                    # Then applies penalties (condition, fatigue).
                    # It does NOT apply position familiarity penalty logic explicitly unless `position_familiarity` logic is there.
                    # Wait, `fm_match_ready_selector.py` usually assumes the input rating is ALREADY position-weighted?
                    # The standard `GK` rating from `data_manager` uses `attribute_weights`.
                    # It doesn't use familiarity.
                    
                    # BUT, `ip_oop_skill_simulation.md` says:
                    # "Match engine applies separate positional penalties... 100% for Natural, 87% for Accomplished..."
                    # We should apply this penalty!
                    
                    # If I use `Rating_D_L` (Attributes only), I get Potential Ability for that role.
                    # I should MULTIPLY it by Familiarity Factor.
                    
                    # So: `Effective_Rating = Attribute_Rating * Familiarity_Factor`
                    
                    # I will calculate `Rating_D_L_Final` which includes familiarity.
                    
                    final_col = f"Final_{slot}"
                    
                    def apply_fam(row, raw_rating, f_col):
                        if not f_col or f_col not in row: return raw_rating
                        fam = row.get(f_col, 20) # Default to 20 if missing
                        # Map 0-20 to factor
                        # 20=1.0, 15=0.87, 10=0.75?
                        # Rough approx: 20->1.0, 1->0.5?
                        # Using: 1.0 - (20-fam)*0.02 ? (Linear)
                        # Or simple table.
                        try:
                            f_val = float(fam)
                        except:
                            f_val = 20.0
                            
                        # FM26 approx: 20=1.0, 19=0.99, ... 10=0.8.
                        if f_val >= 19: factor = 1.0
                        elif f_val >= 15: factor = 0.95
                        elif f_val >= 12: factor = 0.90
                        elif f_val >= 10: factor = 0.85
                        else: factor = 0.70
                        
                        return raw_rating * factor

                    self.df[final_col] = self.df.apply(
                        lambda row: apply_fam(row, row[rating_col], fam_col), axis=1
                    )
                    
                    # Pass (SlotID, FinalCol, AttributeCol)
                    # AttributeCol (Ability) is used for "potential" or "raw skill" display?
                    # MatchReadySelector uses ability_col for sharpness prioritization (using raw ability).
                    new_formation.append((slot, final_col, rating_col))
            
            # Apply new formation
            self.formation = new_formation
            
        # ---------------------------------------------------------------------
        
        results = []

        # Get the current date from the first match (or use empty string if no matches)
        current_date = matches_data[0].get('date', '') if matches_data else ''

        # Initialize player_match_count from confirmed lineups history
        self.player_match_count = self._load_consecutive_counts_from_history(current_date)

        # For rotation logic, we might need to auto-rest players
        auto_rested_players = []

        # Default empty dict for manual overrides
        if manual_overrides_map is None:
            manual_overrides_map = {}

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

            # Select XI using parent logic (excluding overridden players)
            # select_match_xi returns: Dict[pos, (player_name, effective_rating, player_data)]
            selection_raw = self.select_match_xi(importance, prioritize_sharpness, current_rested)

            # Apply manual overrides - replace calculated selections with manual choices
            for pos, player_name in match_overrides.items():
                # Find player data for the overridden player (use Name_Normalized for Unicode-safe comparison)
                player_row = self.df[self.df['Name_Normalized'] == normalize_name(player_name)]
                if not player_row.empty:
                    player_data = player_row.iloc[0].to_dict()
                    # Use a dummy rating for manual selections (we don't recalculate)
                    selection_raw[pos] = (player_name, 0.0, player_data)
            
            # Transform to UI format
            selection_formatted = {}
            for pos, (name, rating, player_data) in selection_raw.items():
                # Normalize Condition to 0-1.0 range for UI display
                raw_condition = player_data.get('Condition', 100)
                normalized_condition = raw_condition / 10000.0 if raw_condition > 100 else raw_condition / 100.0

                selection_formatted[pos] = {
                    "name": name,
                    "nameNormalized": normalize_name(name),  # For frontend to use when storing rejections
                    "rating": rating,
                    "condition": normalized_condition,
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
