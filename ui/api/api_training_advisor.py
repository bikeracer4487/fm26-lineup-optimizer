"""
FM26 Training Advisor API
=========================

Provides position training recommendations using Step 7 research findings.

Key Features (Step 7 Research):
1. Gap Severity Index (GSI): Prioritizes positions by scarcity, injury risk, schedule
2. Age Plasticity: Adjusts retraining timelines based on player age
3. Difficulty Classes: I (Fluid) to IV (Inversion) for position transitions
4. Euclidean Distance: Finds best candidates by attribute similarity
5. Retraining Efficiency Ratio: Evaluates CA cost efficiency

References:
- docs/new-research/07-RESULTS-training-recommender.md (Step 7 Research)
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

from fm_training_advisor import TrainingAdvisor
import data_manager

# Import Step 7 Research parameters
from scoring_parameters import (
    AGE_PLASTICITY,
    get_age_plasticity,
    RETRAINING_DIFFICULTY,
    get_retraining_difficulty,
    POSITION_WEIGHTS_GSI,
    calculate_gsi,
    calculate_euclidean_distance,
    calculate_retraining_efficiency,
    estimate_retraining_weeks,
)


def load_tactic_config():
    """Load tactic configuration from app_state.json."""
    app_state_path = os.path.join(os.path.dirname(__file__), '..', 'data', 'app_state.json')
    if os.path.exists(app_state_path):
        with open(app_state_path, 'r', encoding='utf-8') as f:
            app_state = json.load(f)
            return app_state.get('tacticConfig', None)
    return None


def slot_to_position(slot_id):
    """Map a slot ID to a training position name.

    Slot IDs use underscore format (e.g., D_L, D_CL, AM_C, ST_C).
    - Positions ending in _L are left positions (D_L, AM_L, M_L, WB_L)
    - Positions ending in _R are right positions (D_R, AM_R, M_R, WB_R)
    - Positions ending in _C, _CL, _CR are center positions

    CRITICAL: Must use exact suffix matching, not 'L' in string,
    because D_CL/D_CR contain 'L'/'R' but are center positions.
    """
    if slot_id == 'GK':
        return 'GK'
    elif slot_id.startswith('ST_'):
        return 'ST'
    elif slot_id.startswith('AM_'):
        # AM_L = left, AM_R = right, AM_C/AM_CL/AM_CR = center
        if slot_id == 'AM_L':
            return 'AM(L)'
        elif slot_id == 'AM_R':
            return 'AM(R)'
        else:
            return 'AM(C)'
    elif slot_id.startswith('M_'):
        # M_L = left, M_R = right, M_C/M_CL/M_CR = center
        if slot_id == 'M_L':
            return 'M(L)'
        elif slot_id == 'M_R':
            return 'M(R)'
        else:
            return 'M(C)'
    elif slot_id.startswith('DM_'):
        return 'DM'
    elif slot_id.startswith('WB_'):
        # WB_L = left, WB_R = right
        if slot_id == 'WB_L':
            return 'WB(L)'
        elif slot_id == 'WB_R':
            return 'WB(R)'
        else:
            return 'WB(C)'  # Fallback for any center WB slot
    elif slot_id.startswith('D_'):
        # D_L = left fullback, D_R = right fullback
        # D_C, D_CL, D_CR = center-backs
        if slot_id == 'D_L':
            return 'D(L)'
        elif slot_id == 'D_R':
            return 'D(R)'
        else:
            return 'D(C)'
    return None


def get_tactic_positions(tactic_config):
    """
    Extract the set of position types needed by the tactic.
    Includes BOTH IP and OOP positions since players need training for both phases.

    Args:
        tactic_config: dict with ipPositions, oopPositions, mapping

    Returns:
        Set of position names like {'GK', 'D(L)', 'D(C)', 'DM', 'AM(L)', 'M(L)', 'ST'}
    """
    if not tactic_config:
        return None  # Return None to indicate no filtering

    ip_positions = tactic_config.get('ipPositions', {})
    oop_positions = tactic_config.get('oopPositions', {})

    if not ip_positions and not oop_positions:
        return None

    positions = set()

    # Add IP positions
    for slot_id, role in ip_positions.items():
        if role:
            pos = slot_to_position(slot_id)
            if pos:
                positions.add(pos)

    # Add OOP positions (players also need to train for these!)
    for slot_id, role in oop_positions.items():
        if role:
            pos = slot_to_position(slot_id)
            if pos:
                positions.add(pos)

    return positions if positions else None

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

class ApiTrainingAdvisor(TrainingAdvisor):
    """
    Wrapper around TrainingAdvisor to adapt it for the UI API.
    Suppresses stdout during initialization.
    """
    def __init__(self, status_filepath, abilities_filepath=None):
        with suppress_stdout():
            super().__init__(status_filepath, abilities_filepath)

        # Data Repair for Single-File Mode (Fixes column name collisions from merge)
        if self.has_abilities:
            # 1. Restore Ability Columns
            # The merge renamed columns to {col}_ability because they existed in both files
            # We need to copy them back to their original names so get_quality_tier works
            # List based on required_cols in fm_training_advisor.py
            merged_cols = ['AM(L)', 'AM(C)', 'AM(R)', 'DM(L)', 'DM(R)', 'D(C)', 'D(R/L)', 'GK', 'Striker']
            
            for col in merged_cols:
                ability_col = f"{col}_ability"
                if ability_col in self.df.columns:
                    self.df[col] = self.df[ability_col]
            
            # 2. Fix Striker Mapping
            # Striker (Familiarity) was renamed to 'Striker_Familiarity' in data_manager.py
            # to avoid being overwritten by Striker (Ability).
            # The parent class mapping expects 'Striker_skill' (which is currently Ability score ~140).
            # We must point it to the correct familiarity column.
            if 'Striker_Familiarity' in self.df.columns:
                # Update mapping: (Familiarity Column, Ability Column)
                # Use 'Striker' for ability because we restored it in step 1
                self.position_mapping['ST'] = ('Striker_Familiarity', 'Striker')

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
        with suppress_stdout():
            data_manager.update_player_data()
        
        # 2. Use players-current.csv for BOTH files
        status_file = 'players-current.csv'
        abilities_file = 'players-current.csv'
        
        rejected_map = data.get('rejected', {}) # { "Player Name": "GK" } -> Rejected training for this position

        # Load tactic config to filter recommendations by positions actually in use
        tactic_config = load_tactic_config()
        tactic_positions = get_tactic_positions(tactic_config)

        # Initialize wrapper
        advisor = ApiTrainingAdvisor(status_file, abilities_file)

        # Get recommendations using core logic
        recommendations = advisor.recommend_training()

        # Filter out rejected recommendations AND positions not in tactic
        filtered_recs = []
        for rec in recommendations:
            player_rejected_pos = rejected_map.get(rec['player'])
            if player_rejected_pos == rec['position']:
                continue  # Skip rejected

            # If tactic is configured, only include positions that are in the tactic
            if tactic_positions is not None and rec['position'] not in tactic_positions:
                continue  # Skip positions not in configured tactic

            filtered_recs.append(rec)
                
        # Enrich recommendations with strategic data
        universalists = advisor.identify_universalist_candidates()
        universalist_names = {u['name']: u['total_coverage'] for u in universalists}

        enriched_recs = []
        for rec in filtered_recs:
            player_name = rec['player']
            position = rec['position']

            # Get player data for Step 7 calculations
            player_data = advisor.df[advisor.df['Name'] == player_name]
            player_age = int(player_data['Age'].iloc[0]) if len(player_data) > 0 and 'Age' in player_data.columns else 25
            best_position = player_data['Best Position'].iloc[0] if len(player_data) > 0 and 'Best Position' in player_data.columns else None

            # --- Step 7: Age Plasticity ---
            plasticity = get_age_plasticity(player_age)
            plasticity_label = 'High' if plasticity >= 0.8 else 'Medium' if plasticity >= 0.5 else 'Low' if plasticity >= 0.2 else 'Minimal'

            # --- Step 7: Difficulty Class ---
            if best_position:
                # Map best position to our position format
                from_pos = best_position.replace('/', '(').replace(')', ')').replace('(L', '(L)').replace('(R', '(R)').replace('(C', '(C)')
                if from_pos and position:
                    difficulty = get_retraining_difficulty(from_pos, position)
                    difficulty_class = difficulty['name']
                    difficulty_weeks = f"{difficulty['weeks_min']}-{difficulty['weeks_max']} weeks"
                else:
                    difficulty_class = 'Unknown'
                    difficulty_weeks = 'N/A'
            else:
                difficulty_class = 'Unknown'
                difficulty_weeks = 'N/A'

            # --- Step 7: Estimated Timeline with Age/Versatility ---
            current_skill = rec['current_skill_rating']

            # Infer versatility from existing multi-positionality
            versatility_score = 0.5  # Default medium
            if is_universalist := player_name in universalist_names:
                versatility_score = min(1.0, universalist_names.get(player_name, 0) / 5)

            # Calculate estimated weeks using Step 7 formula
            if best_position and position:
                est_weeks = estimate_retraining_weeks(
                    from_pos=from_pos if best_position else 'M(C)',
                    to_pos=position,
                    age=player_age,
                    versatility=versatility_score,
                    match_exposure='cup_subs'  # Default assumption
                )

                # Adjust based on current skill level
                if current_skill >= 13:
                    est_weeks = max(4, est_weeks // 2)  # Already competent
                elif current_skill >= 10:
                    est_weeks = max(6, int(est_weeks * 0.7))  # Unconvincing but OK

                # Convert weeks to timeline string
                if est_weeks <= 8:
                    timeline = f'{est_weeks} weeks to Natural'
                elif est_weeks <= 16:
                    timeline = f'{est_weeks // 4}-{(est_weeks // 4) + 1} months to Accomplished'
                elif est_weeks <= 36:
                    timeline = f'{est_weeks // 4} months to Competent'
                else:
                    timeline = f'{est_weeks // 4}+ months (low plasticity)'
            else:
                # Fallback to old logic
                if current_skill >= 13:
                    timeline = '2-4 months to Natural'
                elif current_skill >= 10:
                    timeline = '6-9 months to Natural'
                elif current_skill >= 8:
                    timeline = '12+ months to Competent'
                else:
                    timeline = '18+ months (high versatility needed)'

            # Strategic Category
            strategic_category = rec.get('category', 'Standard')
            reason_lower = rec['reason'].lower()
            if 'winger' in reason_lower and position in ['D(R)', 'D(L)']:
                strategic_category += ' | Winger→WB Pipeline'
            elif 'aging' in reason_lower and 'playmaker' in reason_lower:
                strategic_category += ' | Aging AMC→DM'

            # Universalist
            is_universalist = player_name in universalist_names
            universalist_coverage = universalist_names.get(player_name, 0)

            # Variety
            variety_info = advisor.assess_positional_variety(position)
            fills_variety_gap = len(variety_info.get('needs', [])) > 0

            # Add new fields (including Step 7 additions)
            rec['strategic_category'] = strategic_category
            rec['estimated_timeline'] = timeline
            rec['is_universalist'] = is_universalist
            rec['universalist_coverage'] = universalist_coverage
            rec['fills_variety_gap'] = fills_variety_gap

            # Step 7 additions
            rec['age_plasticity'] = plasticity
            rec['plasticity_label'] = plasticity_label
            rec['difficulty_class'] = difficulty_class
            rec['difficulty_weeks'] = difficulty_weeks
            rec['player_age'] = player_age

            enriched_recs.append(rec)
            
        # 3. SAVE TO CSV for Match Selector
        # We save the *filtered* recommendations so user rejections are respected by the match engine
        output_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../training_recommendations.csv'))
        
        export_data = []
        for rec in enriched_recs:
            export_data.append({
                'Player': rec['player'],
                'Position': rec['position'],
                'Priority': rec['priority'],
                'Strategic_Category': rec['strategic_category'],
                'Current_Skill_Rating': rec['current_skill_rating'],
                'Ability_Tier': rec['ability_tier'],
                'Training_Score': rec['training_score']
            })
            
        if export_data:
            pd.DataFrame(export_data).to_csv(output_path, index=False, encoding='utf-8-sig')

        print(json.dumps({"success": True, "recommendations": enriched_recs}, cls=NumpyEncoder))
        
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))

if __name__ == '__main__':
    main()
