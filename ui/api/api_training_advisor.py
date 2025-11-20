import sys
import json
import pandas as pd
import numpy as np
from typing import Dict, List, Optional

class TrainingAdvisor:
    def __init__(self, status_filepath: str, abilities_filepath: Optional[str] = None):
        if status_filepath.endswith('.csv'):
            self.status_df = pd.read_csv(status_filepath, encoding='utf-8-sig')
        else:
            self.status_df = pd.read_excel(status_filepath)
        self.status_df.columns = self.status_df.columns.str.strip()

        self.has_abilities = False
        if abilities_filepath:
            if abilities_filepath.endswith('.csv'):
                self.abilities_df = pd.read_csv(abilities_filepath, encoding='utf-8-sig')
            else:
                self.abilities_df = pd.read_excel(abilities_filepath)
            self.abilities_df.columns = self.abilities_df.columns.str.strip()
            
            required_cols = ['Name', 'Striker', 'AM(L)', 'AM(C)', 'AM(R)',
                           'DM(L)', 'DM(R)', 'D(C)', 'D(R/L)', 'GK']
            if all(col in self.abilities_df.columns for col in required_cols):
                self.df = pd.merge(
                    self.status_df,
                    self.abilities_df[required_cols],
                    on='Name',
                    how='left',
                    suffixes=('_skill', '_ability')
                )
                self.has_abilities = True
            else:
                self.df = self.status_df.copy()
        else:
            self.df = self.status_df.copy()

        numeric_columns = [
            'Age', 'CA', 'PA', 'Versatility', 'Professionalism', 'Determination',
            'Natural Fitness', 'Stamina', 'Work Rate', 'Adaptability',
            'GoalKeeper', 'Defender Right', 'Defender Center', 'Defender Left',
            'Defensive Midfielder', 'Attacking Mid. Right', 'Attacking Mid. Center',
            'Attacking Mid. Left', 'Striker'
        ]
        ability_columns = ['Striker', 'AM(L)', 'AM(C)', 'AM(R)', 'DM(L)', 'DM(R)',
                          'D(C)', 'D(R/L)', 'GK']
        for col in ability_columns:
            if col in self.df.columns:
                numeric_columns.append(col)
        
        for col in numeric_columns:
            if col in self.df.columns:
                self.df[col] = pd.to_numeric(self.df[col], errors='coerce')

        if 'DM(L)' in self.df.columns and 'DM(R)' in self.df.columns:
            self.df['DM_avg'] = (self.df['DM(L)'] + self.df['DM(R)']) / 2

        if self.has_abilities:
            self.position_mapping = {
                'GK': ('GoalKeeper', 'GK'),
                'D(R)': ('Defender Right', 'D(R/L)'),
                'D(C)': ('Defender Center', 'D(C)'),
                'D(L)': ('Defender Left', 'D(R/L)'),
                'DM': ('Defensive Midfielder', 'DM_avg'),
                'AM(R)': ('Attacking Mid. Right', 'AM(R)'),
                'AM(C)': ('Attacking Mid. Center', 'AM(C)'),
                'AM(L)': ('Attacking Mid. Left', 'AM(L)'),
                'ST': ('Striker_skill', 'Striker_ability')
            }
        else:
            self.position_mapping = {
                'GK': ('GoalKeeper', None),
                'D(R)': ('Defender Right', None),
                'D(C)': ('Defender Center', None),
                'D(L)': ('Defender Left', None),
                'DM': ('Defensive Midfielder', None),
                'AM(R)': ('Attacking Mid. Right', None),
                'AM(C)': ('Attacking Mid. Center', None),
                'AM(L)': ('Attacking Mid. Left', None),
                'ST': ('Striker', None)
            }

        self.formation_needs = {
            'GK': 1, 'D(R)': 1, 'D(C)': 2, 'D(L)': 1,
            'DM': 2, 'AM(R)': 1, 'AM(C)': 1, 'AM(L)': 1, 'ST': 1
        }

    # --- Helpers copied from original ---
    
    def get_positional_familiarity_tier(self, rating):
        if pd.isna(rating) or rating < 1: return 'Ineffectual'
        elif rating <= 4: return 'Ineffectual'
        elif rating <= 8: return 'Awkward'
        elif rating <= 9: return 'Unconvincing'
        elif rating <= 12: return 'Competent'
        elif rating <= 17: return 'Accomplished'
        else: return 'Natural'

    def calculate_position_percentiles(self, position_col):
        if position_col not in self.df.columns:
            return {'p90': 160, 'p75': 140, 'p50': 120, 'p25': 100}
        abilities = self.df[position_col].dropna()
        if len(abilities) == 0:
            return {'p90': 160, 'p75': 140, 'p50': 120, 'p25': 100}
        return {
            'p90': abilities.quantile(0.90),
            'p75': abilities.quantile(0.75),
            'p50': abilities.quantile(0.50),
            'p25': abilities.quantile(0.25)
        }

    def get_quality_tier(self, ability, percentiles):
        if pd.isna(ability): return 'Unknown'
        elif ability >= percentiles['p90']: return 'Excellent'
        elif ability >= percentiles['p75']: return 'Good'
        elif ability >= percentiles['p50']: return 'Adequate'
        elif ability >= percentiles['p25']: return 'Poor'
        else: return 'Inadequate'

    def analyze_squad_depth_quality(self):
        depth_analysis = {}
        for pos_name, (skill_col, ability_col) in self.position_mapping.items():
            players_data = []
            percentiles = self.calculate_position_percentiles(ability_col) if ability_col else None
            
            for idx, row in self.df.iterrows():
                skill_rating = row.get(skill_col, 0)
                ability_rating = row.get(ability_col, np.nan) if (ability_col and ability_col in self.df.columns) else np.nan
                skill_tier = self.get_positional_familiarity_tier(skill_rating)
                ability_tier = self.get_quality_tier(ability_rating, percentiles) if percentiles else 'Unknown'

                is_somewhat_familiar = pd.notna(skill_rating) and skill_rating >= 8
                is_training_candidate = ability_tier in ['Good', 'Excellent']

                if is_somewhat_familiar or is_training_candidate:
                    players_data.append((
                        row['Name'], skill_rating, ability_rating, skill_tier, ability_tier
                    ))
            
            def sort_key(x):
                skill = x[1] if pd.notna(x[1]) else 0
                ability = x[2] if pd.notna(x[2]) else 0
                if skill >= 18: composite = ability + 60
                elif skill >= 13: composite = ability + 35
                elif skill >= 10: composite = ability + 15
                elif skill >= 8: composite = ability + 5
                else: composite = ability * 0.4
                return (-composite, -skill, -ability)

            players_data.sort(key=sort_key)
            depth_analysis[pos_name] = players_data
        return depth_analysis

    def identify_quality_gaps(self, depth_analysis):
        gaps = {}
        for pos_name, needed_count in self.formation_needs.items():
            if pos_name not in depth_analysis: continue
            players_data = depth_analysis[pos_name]
            competent_players = [p for p in players_data if p[1] >= 10]
            usable_good_players = [p for p in players_data if p[1] >= 10 and p[4] in ['Good', 'Excellent']]
            good_but_not_competent = [p for p in players_data if p[1] < 10 and p[4] in ['Good', 'Excellent']]
            
            target_competent = max(2, needed_count)
            target_usable_good = needed_count
            
            competent_shortage = max(0, target_competent - len(competent_players))
            quality_shortage = max(0, target_usable_good - len(usable_good_players))
            has_training_potential = len(good_but_not_competent) > 0
            
            if competent_shortage > 0 or quality_shortage > 0 or has_training_potential:
                gaps[pos_name] = {
                    'total_shortage': competent_shortage,
                    'quality_shortage': quality_shortage,
                    'training_potential': len(good_but_not_competent)
                }
        return gaps

    def _get_player_current_positions(self, row):
        current_positions = []
        for pos_name, (skill_col, ability_col) in self.position_mapping.items():
            skill_rating = row.get(skill_col, 0)
            if pd.notna(skill_rating) and skill_rating >= 13:
                current_positions.append((pos_name, skill_rating))
        return current_positions

    def _should_retrain(self, row, target_pos, target_skill, gaps):
        if target_skill >= 18: return True
        if target_skill >= 13: return True
        current_positions = self._get_player_current_positions(row)
        if not current_positions: return True
        
        target_gap = gaps.get(target_pos, {})
        target_severity = (target_gap.get('quality_shortage', 0) * 3 + target_gap.get('total_shortage', 0) * 2)
        
        current_max_severity = 0
        player_is_critical = False
        
        for curr_pos, curr_skill in current_positions:
            curr_gap = gaps.get(curr_pos, {})
            curr_severity = (curr_gap.get('quality_shortage', 0) * 3 + curr_gap.get('total_shortage', 0) * 2)
            current_max_severity = max(current_max_severity, curr_severity)
            if curr_skill >= 18 and curr_gap.get('total_shortage', 0) >= 1:
                player_is_critical = True
                
        if player_is_critical: return False
        if target_severity <= current_max_severity: return False
        return True

    def _check_similar_positions(self, row, target_pos):
        similarity_groups = {
            'D(R)': ['Defender Right', 'Defender Left'],
            'D(L)': ['Defender Left', 'Defender Right'],
            'D(C)': ['Defender Center'],
            'DM': ['Defensive Midfielder', 'Defender Center'],
            'AM(R)': ['Attacking Mid. Right', 'Attacking Mid. Left', 'Attacking Mid. Center'],
            'AM(L)': ['Attacking Mid. Left', 'Attacking Mid. Right', 'Attacking Mid. Center'],
            'AM(C)': ['Attacking Mid. Center', 'Attacking Mid. Left', 'Attacking Mid. Right'],
            'ST': ['Striker', 'Attacking Mid. Center'],
            'GK': []
        }
        similar_cols = similarity_groups.get(target_pos, [])
        for col in similar_cols:
            if col in row and pd.notna(row[col]) and row[col] >= 18:
                return True
        return False

    def _generate_detailed_reason(self, candidate, position):
        reasons = []
        if candidate['reason']: reasons.append(candidate['reason'])
        if candidate['age'] < 21: reasons.append(f"very young ({candidate['age']})")
        elif candidate['age'] < 24: reasons.append(f"young ({candidate['age']})")
        if candidate['training_score'] >= 0.7: reasons.append("excellent training attributes")
        if candidate.get('ability_tier') in ['Excellent', 'Good']: reasons.append(f"{candidate['ability_tier'].lower()} ability")
        if candidate.get('has_similar'): reasons.append("natural in similar pos")
        return " | ".join(reasons)

    def recommend_training(self):
        depth_analysis = self.analyze_squad_depth_quality()
        gaps = self.identify_quality_gaps(depth_analysis)
        recommendations = []
        
        for pos_name, gap_info in gaps.items():
            skill_col, ability_col = self.position_mapping[pos_name]
            percentiles = self.calculate_position_percentiles(ability_col) if ability_col else None
            
            candidates = {'improve_natural': [], 'become_natural': [], 'learn_position': []}
            
            for idx, row in self.df.iterrows():
                name = row['Name']
                age = row.get('Age', 99)
                skill_rating = row.get(skill_col, 0)
                ability_rating = row.get(ability_col, np.nan) if (ability_col and ability_col in self.df.columns) else np.nan
                skill_tier = self.get_positional_familiarity_tier(skill_rating)
                ability_tier = self.get_quality_tier(ability_rating, percentiles) if percentiles else 'Unknown'
                
                versatility = row.get('Versatility', 10)
                professionalism = row.get('Professionalism', 10)
                ca = row.get('CA', 0)
                pa = row.get('PA', 0)
                
                age_factor = max(0, (28 - age) / 24) if pd.notna(age) else 0.5
                versatility_factor = versatility / 20 if pd.notna(versatility) else 0.5
                professionalism_factor = professionalism / 20 if pd.notna(professionalism) else 0.5
                growth_potential = (pa - ca) if pd.notna(pa) and pd.notna(ca) else 10
                
                training_score = (age_factor * 0.3 + versatility_factor * 0.3 + professionalism_factor * 0.3 + min(growth_potential/30, 1.0)*0.1)
                
                cand_data = {
                    'name': name, 'row': row, 'age': age, 
                    'skill_rating': skill_rating, 'skill_tier': skill_tier,
                    'ability_rating': ability_rating, 'ability_tier': ability_tier,
                    'training_score': training_score
                }

                if skill_rating >= 18:
                    if pd.notna(ability_rating) and ability_tier not in ['Good', 'Excellent']:
                        cand_data['reason'] = 'Already natural, improve ability'
                        candidates['improve_natural'].append(cand_data)
                elif skill_rating >= 10:
                    if pd.notna(ability_rating) and ability_tier in ['Adequate', 'Good', 'Excellent']:
                        if self._should_retrain(row, pos_name, skill_rating, gaps):
                            cand_data['reason'] = 'Good ability, become natural'
                            candidates['become_natural'].append(cand_data)
                else:
                    if pd.notna(ability_rating) and ability_tier in ['Adequate', 'Good', 'Excellent']:
                        has_similar = self._check_similar_positions(row, pos_name)
                        if age < 24 or has_similar or training_score > 0.6:
                            if self._should_retrain(row, pos_name, skill_rating, gaps):
                                cand_data['reason'] = 'Has potential, learn position'
                                cand_data['has_similar'] = has_similar
                                candidates['learn_position'].append(cand_data)

            for category in candidates.values():
                category.sort(key=lambda x: x['training_score'], reverse=True)

            gap_severity = (gap_info.get('quality_shortage', 0) * 3 + gap_info.get('total_shortage', 0) * 2)
            
            priority_order = ['become_natural', 'improve_natural', 'learn_position']
            
            for category_name in priority_order:
                category = candidates[category_name]
                if category_name == 'become_natural':
                    needed = gap_info['quality_shortage']; priority = 'High'; priority_score = 3
                elif category_name == 'improve_natural':
                    needed = min(2, gap_info['quality_shortage']); priority = 'Medium'; priority_score = 2
                else:
                    needed = min(1, gap_info['total_shortage']); priority = 'Low'; priority_score = 1
                
                for candidate in category[:needed + 1]:
                    rec = {
                        'player': candidate['name'],
                        'position': pos_name,
                        'category': category_name.replace('_', ' ').title(),
                        'current_skill': candidate['skill_tier'],
                        'ability_tier': candidate['ability_tier'],
                        'age': candidate['age'],
                        'training_score': float(candidate['training_score']),
                        'priority': priority,
                        'priority_score': priority_score,
                        'gap_severity': gap_severity,
                        'reason': self._generate_detailed_reason(candidate, pos_name)
                    }
                    recommendations.append(rec)

        # Deduplicate
        player_best_rec = {}
        for rec in recommendations:
            player_name = rec['player']
            if player_name not in player_best_rec:
                player_best_rec[player_name] = rec
            else:
                current = player_best_rec[player_name]
                if (rec['priority_score'] > current['priority_score'] or
                    (rec['priority_score'] == current['priority_score'] and rec['gap_severity'] > current['gap_severity']) or
                    (rec['priority_score'] == current['priority_score'] and rec['gap_severity'] == current['gap_severity'] and rec['training_score'] > current['training_score'])):
                    player_best_rec[player_name] = rec
        
        return list(player_best_rec.values())

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
        input_str = sys.stdin.read()
        if not input_str: return

        data = json.loads(input_str)
        status_file = data.get('files', {}).get('status', 'players-current.csv')
        abilities_file = data.get('files', {}).get('abilities', 'players.csv')
        rejected_map = data.get('rejected', {}) # { "Player Name": "GK" } -> Rejected training for this position
        
        advisor = TrainingAdvisor(status_file, abilities_file)
        recommendations = advisor.recommend_training()
        
        # Filter out rejected recommendations
        filtered_recs = []
        for rec in recommendations:
            player_rejected_pos = rejected_map.get(rec['player'])
            if player_rejected_pos != rec['position']:
                filtered_recs.append(rec)
                
        print(json.dumps({"success": True, "recommendations": filtered_recs}, cls=NumpyEncoder))
        
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))

if __name__ == '__main__':
    main()

