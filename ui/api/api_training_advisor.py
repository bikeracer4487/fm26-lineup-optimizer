import sys
import os
import json
import contextlib
import pandas as pd
import numpy as np

# Add root directory to sys.path to allow importing from root scripts
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '../../')))

from fm_training_advisor import TrainingAdvisor

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
        
        status_file = data.get('files', {}).get('status', 'players-current.csv')
        abilities_file = data.get('files', {}).get('abilities', 'players.csv')
        rejected_map = data.get('rejected', {}) # { "Player Name": "GK" } -> Rejected training for this position
        
        # Initialize wrapper
        advisor = ApiTrainingAdvisor(status_file, abilities_file)
        
        # Get recommendations using core logic
        recommendations = advisor.recommend_training()
        
        # Filter out rejected recommendations
        filtered_recs = []
        for rec in recommendations:
            player_rejected_pos = rejected_map.get(rec['player'])
            if player_rejected_pos != rec['position']:
                filtered_recs.append(rec)
                
        # Enrich recommendations with strategic data
        universalists = advisor.identify_universalist_candidates()
        universalist_names = {u['name']: u['total_coverage'] for u in universalists}

        enriched_recs = []
        for rec in filtered_recs:
            player_name = rec['player']
            position = rec['position']
            
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
            
            # Timeline
            current_skill = rec['current_skill_rating']
            if current_skill >= 13:
                timeline = '2-4 months to Natural'
            elif current_skill >= 10:
                timeline = '6-9 months to Natural'
            elif current_skill >= 8:
                timeline = '12+ months to Competent'
            else:
                timeline = '18+ months (high versatility needed)'
                
            # Variety
            variety_info = advisor.assess_positional_variety(position)
            fills_variety_gap = len(variety_info.get('needs', [])) > 0

            # Add new fields
            rec['strategic_category'] = strategic_category
            rec['estimated_timeline'] = timeline
            rec['is_universalist'] = is_universalist
            rec['universalist_coverage'] = universalist_coverage
            rec['fills_variety_gap'] = fills_variety_gap
            
            enriched_recs.append(rec)
            
        print(json.dumps({"success": True, "recommendations": enriched_recs}, cls=NumpyEncoder))
        
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))

if __name__ == '__main__':
    main()
