import sys
import os
import json
import contextlib
import pandas as pd
import numpy as np
from datetime import datetime

# Add root directory to sys.path to allow importing from root scripts
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../')))

from fm_match_ready_selector import MatchReadySelector
import data_manager

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

class ApiMatchReadySelector(MatchReadySelector):
    """
    Wrapper around MatchReadySelector to adapt it for the UI API.
    Suppresses stdout and formats output as JSON-compatible structures.
    """
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
                                   position_name: str = None) -> float:
        """
        Override to apply loan logic penalties.
        """
        # Call parent method
        effective_rating = super().calculate_effective_rating(
            row, skill_col, ability_col, match_importance, prioritize_sharpness, position_name
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
                effective_rating *= 0.70
            elif match_importance == 'Medium':
                # Slightly lower priority
                effective_rating *= 0.90
            # High importance: Unaffected
            
        return effective_rating
            
    def generate_plan(self, matches_data, rejected_players_map):
        """
        Generate a match plan using the core logic from MatchReadySelector.
        
        Args:
            matches_data: List of dicts {date, importance, opponent}
            rejected_players_map: Dict of match_index (str) -> list of player names (manual rejections)
            
        Returns:
            List of match plan items suitable for the UI
        """
        results = []
        
        # Reset internal match tracking state for this simulation run
        # We assume a clean slate for the simulation unless we want to persist state between UI runs
        self.player_match_count = {}
        
        # For rotation logic, we might need to auto-rest players
        auto_rested_players = []
        
        for i, match in enumerate(matches_data):
            importance = match.get('importance', 'Medium')
            prioritize_sharpness = (importance == 'Low')
            match_date_str = match.get('date')
            
            # Combine manual rejections with auto-rested players
            manual_rejections = rejected_players_map.get(str(i), [])
            current_rested = list(set(manual_rejections + auto_rested_players))
            
            # Select XI using parent logic
            # select_match_xi returns: Dict[pos, (player_name, effective_rating, player_data)]
            selection_raw = self.select_match_xi(importance, prioritize_sharpness, current_rested)
            
            # Transform to UI format
            selection_formatted = {}
            for pos, (name, rating, player_data) in selection_raw.items():
                # Normalize Condition to 0-1.0 range for UI display
                raw_condition = player_data.get('Condition', 100)
                normalized_condition = raw_condition / 10000.0 if raw_condition > 100 else raw_condition / 100.0
                
                selection_formatted[pos] = {
                    "name": name,
                    "rating": rating,
                    "condition": normalized_condition,
                    "fatigue": player_data.get('Fatigue', 0),
                    "sharpness": player_data.get('Match Sharpness', 10000) / 10000,
                    "age": player_data.get('Age', 25),
                    "status": self._get_player_status_flags_ui(player_data)
                }
            
            results.append({
                "matchIndex": i,
                "date": match_date_str,
                "importance": importance,
                "selection": selection_formatted
            })
            
            # Update consecutive counts (logic from parent class)
            self._update_consecutive_match_counts(selection_raw)
            
            # MATCH ROTATION LOGIC (Copied from plan_rotation in parent)
            # Check if we should rest players for the NEXT match
            auto_rested_players = [] # Reset for next iteration
            
            if i < len(matches_data) - 1:
                next_match = matches_data[i+1]
                next_importance = next_match.get('importance', 'Medium')
                
                if next_importance == 'High' and match_date_str and next_match.get('date'):
                    try:
                        curr_date = datetime.strptime(match_date_str, '%Y-%m-%d')
                        next_date = datetime.strptime(next_match['date'], '%Y-%m-%d')
                        days_until = (next_date - curr_date).days
                        
                        if days_until <= 3:
                            # Rest high-fatigue players before important match
                            auto_rested_players = self._identify_players_to_rest()
                    except (ValueError, TypeError):
                        # Ignore date parsing errors
                        pass
                        
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
        
        plan = selector.generate_plan(matches, rejected)
        
        print(json.dumps({"success": True, "plan": plan}, cls=NumpyEncoder))
        
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))

if __name__ == '__main__':
    main()
