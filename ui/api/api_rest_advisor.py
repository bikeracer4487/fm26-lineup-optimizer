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
        Generate fatigue-based rest recommendations.

        This screen focuses EXCLUSIVELY on fatigue management (not condition).
        Condition recovers quickly with normal rest (1-2 days), but fatigue
        is a long-term load metric that requires intentional intervention.

        Fatigue Scale (from research):
        - Negative to 0: "Buffered" - Deep Freshness from pre-season/vacation
        - 0 to 250: "Neutral" - No concern, normal training
        - 250 to threshold*0.8: "Accumulating" - Monitor, consider rotation
        - threshold*0.8 to threshold: "Approaching Limit" - Rest from training
        - threshold to threshold+100: "Jaded" - Vacation needed (3-7 days)
        - threshold+100+: "Exhausted" - Extended vacation (1-2 weeks)

        Recovery Rates (per research, approximately):
        - Vacation: ~50 points/day
        - Rest from training: ~35-45 points/day
        - Recovery sessions: ~16-17 points/day
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

            # Skip if fatigue data is missing or invalid
            if pd.isna(fatigue):
                continue

            # Calculate personalized fatigue threshold based on player attributes
            threshold = self._get_adjusted_fatigue_threshold(age, natural_fitness, stamina, injury_proneness)

            # Calculate warning threshold (80% of personal threshold)
            warning_threshold = threshold * 0.8

            # Calculate fatigue zones relative to personal threshold
            fatigue_percentage = (fatigue / threshold) * 100 if threshold > 0 else 0

            # Determine status, action, and recovery estimates
            status = "Fresh"
            action = "None"
            priority = "Low"
            reasons = []
            recovery_days = 0
            recovery_method = ""

            # Fatigue-based logic (exclusive focus)
            if fatigue >= threshold + 100:
                # EXHAUSTED: Critical state, extended vacation required
                status = "Exhausted"
                priority = "Urgent"
                excess = fatigue - 250  # Target: back to neutral zone
                recovery_days = max(7, int(excess / 50) + 1)  # Vacation rate ~50/day
                recovery_method = "vacation"
                action = f"Vacation ({recovery_days}+ days)"
                reasons.append(f"Fatigue {fatigue:.0f} is {fatigue - threshold:.0f} points over your limit")
                reasons.append(f"Risk of injury and severe performance drop")
                reasons.append(f"Vacation required to reset fatigue buffer")

            elif fatigue >= threshold:
                # JADED: Over threshold, vacation recommended
                status = "Jaded"
                priority = "High"
                excess = fatigue - 250  # Target: back to neutral zone
                recovery_days = max(3, int(excess / 50) + 1)  # Vacation rate ~50/day
                recovery_method = "vacation"
                action = f"Vacation ({recovery_days} days)"
                reasons.append(f"Fatigue {fatigue:.0f} has reached your personal threshold ({threshold:.0f})")
                reasons.append(f"Performance and mental attributes are being suppressed")
                reasons.append(f"Vacation is the most effective recovery method")

            elif fatigue >= warning_threshold:
                # APPROACHING LIMIT: Close to threshold, proactive rest needed
                status = "Approaching Limit"
                priority = "High"
                buffer_remaining = threshold - fatigue
                recovery_days = max(2, int((fatigue - 250) / 40) + 1)  # Rest rate ~40/day
                recovery_method = "rest"
                action = f"Rest from training ({recovery_days} days)"
                reasons.append(f"Fatigue {fatigue:.0f} is approaching your limit ({threshold:.0f})")
                reasons.append(f"Only {buffer_remaining:.0f} points of buffer remaining")
                reasons.append(f"Rest now to avoid needing vacation later")

            elif fatigue >= 250:
                # ACCUMULATING: Building load, rotation recommended
                status = "Accumulating"
                priority = "Medium"
                recovery_method = "rotation"
                matches_until_threshold = int((warning_threshold - fatigue) / 50)  # ~50 fatigue per match
                action = "Rotate in upcoming matches"
                reasons.append(f"Fatigue {fatigue:.0f} is accumulating (neutral zone: <250)")
                reasons.append(f"Approximately {max(1, matches_until_threshold)} matches until rest needed")
                reasons.append(f"Consider resting in low-priority fixtures")

            elif fatigue >= 100:
                # BUILDING: Early accumulation, just monitor
                status = "Building"
                priority = "Low"
                recovery_method = "monitor"
                action = "Monitor"
                reasons.append(f"Fatigue {fatigue:.0f} - early accumulation phase")
                reasons.append(f"Normal training and rotation will manage this")

            # Add consecutive match context if relevant
            if player_name in self.player_match_count:
                consecutive = self.player_match_count[player_name]
                if consecutive >= 3:
                    reasons.append(f"{consecutive} consecutive starts - rotation recommended")
                    if priority == "Low":
                        priority = "Medium"
                        status = "Heavy Usage"
                        action = "Rotate"

            # Only include players who need attention (fatigue >= 100 or heavy usage)
            if priority != "Low" or fatigue >= 100:
                # Normalize sharpness and condition for display
                sharpness_pct = match_sharpness / 10000 if pd.notna(match_sharpness) else 1.0
                condition_pct = condition if pd.notna(condition) else 100
                if condition_pct > 100:
                    condition_pct = condition_pct / 100

                recommendations.append({
                    "name": player_name,
                    "fatigue": fatigue,
                    "condition": condition_pct,
                    "sharpness": sharpness_pct,
                    "status": status,
                    "action": action,
                    "priority": priority,
                    "reasons": reasons,
                    "threshold": threshold,
                    "recovery_days": recovery_days,
                    "recovery_method": recovery_method,
                    "fatigue_percentage": fatigue_percentage,
                    "warning_threshold": warning_threshold
                })

        # Sort: Urgent > High > Medium > Low, then by fatigue descending
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

