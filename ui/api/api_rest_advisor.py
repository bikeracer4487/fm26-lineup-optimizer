import sys
import os
import json
import contextlib
import pandas as pd
import numpy as np

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

class ApiRestAdvisor(MatchReadySelector):
    """
    Wrapper around MatchReadySelector to provide rest recommendations via API.
    """
    def __init__(self, status_filepath, abilities_filepath=None):
        with suppress_stdout():
            super().__init__(status_filepath, abilities_filepath)

    def get_rest_recommendations(self):
        """
        Generate rest recommendations based on research criteria.
        Returns a list of recommendation dictionaries.
        """
        recommendations = []

        for idx, row in self.df.iterrows():
            player_name = row['Name']
            age = row.get('Age', 25)
            fatigue = row.get('Fatigue', 0)
            condition = row.get('Condition', 100)
            natural_fitness = row.get('Natural Fitness', 15)
            stamina = row.get('Stamina', 15)
            injury_proneness = row.get('Injury Proneness', None)
            match_sharpness = row.get('Match Sharpness', 10000)

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

            # Determine status and action
            status = "Fresh"
            action = "None"
            priority = "Low"
            reasons = []

            # Fatigue Logic
            if pd.notna(fatigue):
                if fatigue >= threshold + 100:
                    status = "Exhausted"
                    action = "Vacation (1 week)"
                    priority = "Urgent"
                    reasons.append(f"Critical Fatigue: {fatigue:.0f} (Threshold: {threshold:.0f})")
                elif fatigue >= threshold:
                    status = "Jaded"
                    action = "Vacation (3 days) / Rest"
                    priority = "High"
                    reasons.append(f"High Fatigue: {fatigue:.0f} (Threshold: {threshold:.0f})")
                elif fatigue >= 250:
                    status = "Accumulating"
                    if condition < 80:
                        action = "Rest (1-2 days)"
                        priority = "Medium"
                        reasons.append(f"Accumulating Load & Low Condition")
                    else:
                        action = "Monitor / Rotate"
                        priority = "Medium"
                        reasons.append(f"Accumulating Load")

            # Condition Logic (if not already urgent)
            if priority != "Urgent":
                if pd.notna(condition) and condition < 75:
                    if priority == "Low": priority = "High"
                    reasons.append(f"Low Condition: {condition:.0f}%")
                    if action == "None": action = "Rest (2 days)"
                elif pd.notna(condition) and condition < 85:
                    if priority == "Low": priority = "Medium"
                    reasons.append(f"Suboptimal Condition: {condition:.0f}%")
                    if action == "None": action = "Light Training"

            # Consecutive Matches Logic
            if player_name in self.player_match_count:
                consecutive = self.player_match_count[player_name]
                if consecutive >= 3:
                    reasons.append(f"{consecutive} consecutive matches")
                    if priority == "Low": 
                        priority = "Medium"
                        action = "Rotate"

            if priority != "Low" or status != "Fresh":
                recommendations.append({
                    "name": player_name,
                    "fatigue": fatigue if pd.notna(fatigue) else 0,
                    "condition": condition if pd.notna(condition) else 100,
                    "sharpness": match_sharpness / 10000 if pd.notna(match_sharpness) else 1.0,
                    "status": status,
                    "action": action,
                    "priority": priority,
                    "reasons": reasons,
                    "threshold": threshold
                })

        # Sort: Urgent > High > Medium > Low
        priority_map = {"Urgent": 0, "High": 1, "Medium": 2, "Low": 3}
        recommendations.sort(key=lambda x: (priority_map.get(x["priority"], 4), -x["fatigue"]))

        return recommendations

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
        # Read JSON from stdin (if any needed, usually none for just getting list)
        input_str = sys.stdin.read()
        
        # 1. UPDATE DATA FROM EXCEL
        with suppress_stdout():
            data_manager.update_player_data()
        
        status_file = 'players-current.csv'
        abilities_file = 'players-current.csv'
        
        advisor = ApiRestAdvisor(status_file, abilities_file)
        recommendations = advisor.get_rest_recommendations()
        
        print(json.dumps({"success": True, "recommendations": recommendations}, cls=NumpyEncoder))
        
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))

if __name__ == '__main__':
    main()

