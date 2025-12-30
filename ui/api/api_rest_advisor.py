"""
FM26 Rest Advisor API
=====================

Provides fatigue-based rest recommendations using Step 6 research findings.

Key Features (Step 6 Research):
1. Player Archetypes: Different rotation policies for different player types
2. Holiday Protocol: 10x faster recovery than rest (50 vs 5 J points/day)
3. Jadedness Thresholds: Fresh (0-200), Fit (201-400), Tired (401-700), Jaded (701+)
4. 270-Minute Rule: >270 mins in 14 days triggers accelerated jadedness

References:
- docs/new-research/06-RESULTS-fatigue-rest.md (Step 6 Research)
- docs/new-research/12-IMPLEMENTATION-PLAN.md (consolidated specification)
"""

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

# Import Step 6 Research parameters
from scoring_parameters import (
    PLAYER_ARCHETYPES,
    classify_player_archetype,
    HOLIDAY_RECOVERY_MULTIPLIER,
    HOLIDAY_JADEDNESS_THRESHOLD,
    JADEDNESS_THRESHOLDS,
    JADEDNESS_MULTIPLIERS,
    get_jadedness_state,
    get_jadedness_multiplier,
    MINUTES_THRESHOLD,
    MINUTES_WINDOW_DAYS,
)

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
        Generate fatigue-based rest recommendations using Step 6 research.

        Updated for Step 6 Research:
        - Player Archetypes: Different policies for workhorses, glass cannons, veterans, youngsters
        - Holiday Protocol: 10x faster recovery (50 vs 5 J points/day)
        - Jadedness States: Fresh (0-200), Fit (201-400), Tired (401-700), Jaded (701+)
        - 270-Minute Rule: Track minutes in 14-day window

        Archetype Policies (Step 6):
        - Workhorse: NF/Sta 15+, holiday every 15 matches, max 360 mins/14d
        - Glass Cannon: Inj Prone >12 or NF <12, max 180 mins/14d, sub at 60'
        - Veteran: Age 30+, max 1 match per week
        - Youngster: Age <19, max 25 senior starts per season
        - Standard: Max 270 mins/14d

        Recovery Rates (Step 6):
        - Holiday: ~50 J points/day (10x faster)
        - Rest: ~5 J points/day (standard)
        """
        recommendations = []

        for idx, row in self.df.iterrows():
            player_name = row['Name']
            age = int(row.get('Age', 25))
            fatigue = row.get('Fatigue', 0)
            condition = row.get('Condition', 100)
            natural_fitness = int(row.get('Natural Fitness', 10))
            stamina = int(row.get('Stamina', 10))
            injury_proneness = int(row.get('Injury Proneness', 10)) if pd.notna(row.get('Injury Proneness')) else 10
            match_sharpness = row.get('Match Sharpness', 10000)

            # Skip if fatigue data is missing or invalid
            if pd.isna(fatigue):
                continue

            fatigue = int(fatigue)

            # --- Step 6: Classify Player Archetype ---
            archetype = classify_player_archetype(age, natural_fitness, stamina, injury_proneness)
            archetype_config = PLAYER_ARCHETYPES.get(archetype, PLAYER_ARCHETYPES['standard'])

            # --- Step 6: Get Jadedness State ---
            jadedness_state = get_jadedness_state(fatigue)
            jadedness_multiplier = get_jadedness_multiplier(fatigue)

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

            # --- Step 6: Use Jadedness Thresholds ---
            if jadedness_state == 'jaded':
                # JADED (701+): Holiday required - 10x faster recovery
                status = "Jaded"
                priority = "Urgent"
                # Holiday recovers ~50 J/day, target is back to Fresh (<200)
                excess = fatigue - 200
                recovery_days = max(7, int(excess / 50) + 1)
                recovery_method = "holiday"
                action = f"Holiday ({recovery_days} days) - REQUIRED"
                reasons.append(f"Jadedness {fatigue:.0f} is in JADED state (>700)")
                reasons.append(f"Performance multiplier: {jadedness_multiplier:.0%} (severe penalty)")
                reasons.append(f"Only Holiday (not Rest) can recover effectively")

            elif jadedness_state == 'tired':
                # TIRED (401-700): Holiday strongly recommended
                status = "Tired"
                priority = "High"
                excess = fatigue - 200
                recovery_days = max(5, int(excess / 50) + 1)
                recovery_method = "holiday"
                action = f"Holiday ({recovery_days} days)"
                reasons.append(f"Jadedness {fatigue:.0f} is in TIRED state (401-700)")
                reasons.append(f"Performance multiplier: {jadedness_multiplier:.0%}")
                reasons.append(f"Holiday recommended to prevent Jaded state")

            elif jadedness_state == 'fit':
                # FIT (201-400): Monitor and rotate
                status = "Fit"
                priority = "Medium"
                recovery_method = "rotation"
                matches_until_tired = int((400 - fatigue) / 50)
                action = "Rotate in upcoming matches"
                reasons.append(f"Jadedness {fatigue:.0f} is in FIT state (201-400)")
                reasons.append(f"Performance multiplier: {jadedness_multiplier:.0%} (minor penalty)")
                reasons.append(f"~{max(1, matches_until_tired)} matches until TIRED state")

            else:
                # FRESH (0-200): All good
                status = "Fresh"
                priority = "Low"
                recovery_method = "none"
                action = "None"
                reasons.append(f"Jadedness {fatigue:.0f} is in FRESH state (<200)")
                reasons.append(f"Full performance, no action needed")

            # --- Step 6: Archetype-Specific Policies ---
            archetype_warning = None

            if archetype == 'veteran':
                archetype_warning = "Veteran (30+): Max 1 match per week recommended"
                if jadedness_state in ['fit', 'tired']:
                    priority = max_priority(priority, "High")
                    reasons.append(archetype_warning)

            elif archetype == 'glass_cannon':
                archetype_warning = f"Glass Cannon: Max {archetype_config.get('max_mins_14d', 180)} mins/14d, sub at 60'"
                if jadedness_state != 'fresh':
                    priority = max_priority(priority, "High")
                    reasons.append(archetype_warning)

            elif archetype == 'youngster':
                archetype_warning = f"Youngster (<19): Limit senior starts to ~25/season"
                if jadedness_state in ['tired', 'jaded']:
                    priority = max_priority(priority, "High")
                    reasons.append(archetype_warning)

            elif archetype == 'workhorse':
                archetype_warning = f"Workhorse: Can handle heavy load, holiday every ~15 matches"
                # Workhorses can handle more, so lower priority
                if jadedness_state == 'tired' and priority == "High":
                    priority = "Medium"
                reasons.append(archetype_warning)

            # Add consecutive match context if relevant
            if player_name in self.player_match_count:
                consecutive = self.player_match_count[player_name]
                rotation_threshold = self._get_archetype_rotation_threshold(archetype)
                if consecutive >= rotation_threshold:
                    reasons.append(f"{consecutive} consecutive starts (threshold: {rotation_threshold})")
                    if priority == "Low":
                        priority = "Medium"
                        status = "Heavy Usage"
                        action = "Rotate"

            # Only include players who need attention
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
                    "warning_threshold": warning_threshold,
                    # Step 6 additions
                    "archetype": archetype,
                    "jadedness_state": jadedness_state,
                    "jadedness_multiplier": jadedness_multiplier,
                })

        # Sort: Urgent > High > Medium > Low, then by fatigue descending
        priority_map = {"Urgent": 0, "High": 1, "Medium": 2, "Low": 3}
        recommendations.sort(key=lambda x: (priority_map.get(x["priority"], 4), -x["fatigue"]))

        return recommendations

    def _get_archetype_rotation_threshold(self, archetype: str) -> int:
        """
        Get consecutive match threshold before rotation based on archetype.

        Args:
            archetype: Player archetype

        Returns:
            Number of consecutive matches before rotation recommended
        """
        thresholds = {
            'workhorse': 5,      # Can handle more
            'glass_cannon': 2,  # Fragile
            'veteran': 1,       # One per week
            'youngster': 3,     # Moderate
            'standard': 3,      # Default
        }
        return thresholds.get(archetype, 3)


def max_priority(current: str, new: str) -> str:
    """Return the higher priority of two priority levels."""
    priority_order = {"Urgent": 0, "High": 1, "Medium": 2, "Low": 3}
    if priority_order.get(new, 4) < priority_order.get(current, 4):
        return new
    return current

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

