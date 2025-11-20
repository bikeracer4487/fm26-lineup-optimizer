import sys
import json
import pandas as pd
import numpy as np
from scipy.optimize import linear_sum_assignment
from datetime import datetime, timedelta

# --- Copy of MatchReadySelector Class with modifications for JSON output ---

class MatchReadySelector:
    """
    Intelligent team selector adapted for JSON API usage.
    """

    def __init__(self, status_filepath, abilities_filepath=None, training_filepath=None):
        # Load status/attributes file
        if status_filepath.endswith('.csv'):
            self.status_df = pd.read_csv(status_filepath, encoding='utf-8-sig')
        else:
            self.status_df = pd.read_excel(status_filepath)

        self.status_df.columns = self.status_df.columns.str.strip()

        # Normalize column names
        if 'Condition (%)' in self.status_df.columns:
            self.status_df.rename(columns={'Condition (%)': 'Condition'}, inplace=True)

        # Load abilities file
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

        # Convert numeric columns
        numeric_columns = [
            'Age', 'CA', 'PA', 'Condition', 'Fatigue', 'Match Sharpness',
            'Natural Fitness', 'Stamina', 'Work Rate',
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

        # Create DM_avg
        if 'DM(L)' in self.df.columns and 'DM(R)' in self.df.columns:
            self.df['DM_avg'] = (self.df['DM(L)'] + self.df['DM(R)']) / 2

        # Formation
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
                ('STC', 'Striker_skill', 'Striker_ability')
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

        self.training_recommendations = {}
        # (We skip loading training file for now unless passed explicitly, 
        #  can be added later if UI sends it)

        # Match tracking state (in-memory for this request)
        self.player_match_count = {} 
        self.last_match_counted = None

    # --- Helper Methods (Copied from original) ---

    def _get_familiarity_penalty(self, rating):
        if pd.isna(rating): return 0.40
        elif rating >= 18: return 0.00
        elif rating >= 13: return 0.10
        elif rating >= 10: return 0.15
        elif rating >= 6: return 0.20
        elif rating >= 5: return 0.35
        else: return 0.40

    def _get_adjusted_fatigue_threshold(self, age, natural_fitness, stamina):
        threshold = 400.0
        if pd.notna(age):
            if age >= 32: threshold = 300.0
            elif age >= 30: threshold = 350.0
            elif age < 19: threshold = 350.0
        
        if pd.notna(natural_fitness):
            if natural_fitness < 10: threshold -= 50
            elif natural_fitness >= 15: threshold += 50
            
        if pd.notna(stamina):
            if stamina < 10: threshold -= 50
            elif stamina >= 15: threshold += 30
            
        return max(200.0, min(550.0, threshold))

    def _get_position_fatigue_multiplier(self, position_name):
        high_intensity = ['DM(L)', 'DM(R)']
        low_intensity = ['GK', 'DC1', 'DC2']
        if position_name in high_intensity: return 1.2
        elif position_name in low_intensity: return 0.8
        return 1.0

    def calculate_effective_rating(self, row, skill_col, ability_col, match_importance, 
                                 prioritize_sharpness, position_name=None):
        # Availability check
        if row.get('Is Injured', False) or row.get('Banned', False):
            return -999.0

        skill_rating = row.get(skill_col, 0)
        if pd.isna(skill_rating) or skill_rating < 1:
            return -999.0

        if ability_col and ability_col in row.index:
            ability_rating = row.get(ability_col, 0)
            if pd.isna(ability_rating) or ability_rating < 1:
                base_rating = float(skill_rating)
            else:
                base_rating = float(ability_rating) / 10.0
        else:
            base_rating = float(skill_rating)

        effective_rating = base_rating
        
        # 1. Familiarity
        effective_rating *= (1 - self._get_familiarity_penalty(skill_rating))

        # 2. Match Sharpness
        match_sharpness = row.get('Match Sharpness', 10000)
        if pd.notna(match_sharpness):
            sharpness_pct = match_sharpness / 10000
            if prioritize_sharpness and sharpness_pct < 0.85:
                effective_rating *= 1.1
            else:
                if sharpness_pct < 0.60: effective_rating *= 0.70
                elif sharpness_pct < 0.75: effective_rating *= 0.85
                elif sharpness_pct < 0.85: effective_rating *= 0.95

        # 3. Condition
        condition = row.get('Condition', 100)
        if pd.notna(condition):
            if condition > 100: condition = condition / 100
            if condition < 85:
                if match_importance in ['Medium', 'High']: effective_rating *= 0.50
                else: effective_rating *= 0.70
            elif condition < 60: effective_rating *= 0.40
            elif condition < 75: effective_rating *= 0.60
            elif condition < 90: effective_rating *= 0.90

        # 4. Fatigue
        fatigue = row.get('Fatigue', 0)
        effective_fatigue = 0
        fatigue_threshold = 400
        
        if pd.notna(fatigue):
            age = row.get('Age', 25)
            nf = row.get('Natural Fitness', 10)
            stamina = row.get('Stamina', 10)
            fatigue_threshold = self._get_adjusted_fatigue_threshold(age, nf, stamina)
            
            if position_name:
                effective_fatigue = fatigue * self._get_position_fatigue_multiplier(position_name)
            else:
                effective_fatigue = fatigue
                
            if effective_fatigue >= fatigue_threshold + 100: effective_rating *= 0.65
            elif effective_fatigue >= fatigue_threshold: effective_rating *= 0.85
            elif effective_fatigue >= fatigue_threshold - 50: effective_rating *= 0.95

        # 5. Consecutive Matches (using internal state passed in)
        player_name = row.get('Name', '')
        if player_name in self.player_match_count:
            consecutive = self.player_match_count[player_name]
            if consecutive >= 5: effective_rating *= 0.70
            elif consecutive >= 4: effective_rating *= 0.80
            elif consecutive >= 3: effective_rating *= 0.90

        return effective_rating

    def select_match_xi(self, match_importance, prioritize_sharpness, rested_players):
        unavailable_mask = (
            (self.df['Is Injured'] == True) |
            (self.df['Banned'] == True) |
            (self.df['Name'].isin(rested_players))
        )
        available_df = self.df[~unavailable_mask].copy()
        available_df = available_df.reset_index(drop=False)
        
        n_players = len(available_df)
        n_positions = len(self.formation)
        
        cost_matrix = np.full((n_players, n_positions), -999.0)
        
        for i in range(n_players):
            player = available_df.iloc[i]
            for j, pos_info in enumerate(self.formation):
                if len(pos_info) == 3:
                    pos_name, skill_col, ability_col = pos_info
                else:
                    pos_name, skill_col = pos_info
                    ability_col = None
                
                eff_rating = self.calculate_effective_rating(
                    player, skill_col, ability_col, match_importance, prioritize_sharpness, pos_name
                )
                
                if eff_rating > -999.0:
                    cost_matrix[i, j] = -eff_rating

        row_ind, col_ind = linear_sum_assignment(cost_matrix)
        
        selection = {}
        for i, j in zip(row_ind, col_ind):
            if cost_matrix[i, j] > -998:
                player = available_df.iloc[i]
                pos_info = self.formation[j]
                pos_name = pos_info[0]
                effective_rating = -cost_matrix[i, j]
                # Normalize Condition to 0-1.0 range
                raw_condition = player.get('Condition', 10000)
                # FM uses 0-10000 scale usually, sometimes 0-100
                # If > 100, it's definitely 0-10000 scale
                # If <= 100, it might be 0-100 scale (or very poor 0-10000, but unlikely for a selected player)
                normalized_condition = raw_condition / 10000.0 if raw_condition > 100 else raw_condition / 100.0

                selection[pos_name] = {
                    "name": player['Name'],
                    "rating": effective_rating,
                    "condition": normalized_condition,
                    "fatigue": player.get('Fatigue', 0),
                    "sharpness": player.get('Match Sharpness', 10000) / 10000,
                    "age": player.get('Age', 25),
                    "status": self._get_player_status_flags(player)
                }
        
        return selection

    def _get_player_status_flags(self, player):
        flags = []
        fatigue = player.get('Fatigue', 0)
        condition = player.get('Condition', 100)
        if condition > 100: condition /= 100
        sharpness = player.get('Match Sharpness', 10000) / 10000
        age = player.get('Age', 25)
        
        if fatigue >= 400: flags.append("Fatigued")
        if condition < 0.80: flags.append("Low Condition")
        if sharpness < 0.80: flags.append("Low Sharpness")
        if age >= 32: flags.append("Veteran Risk")
        
        return flags

    def generate_plan(self, matches_data, rejected_players_map):
        """
        matches_data: List of dicts {date, importance, opponent}
        rejected_players_map: Dict of match_index (str) -> list of player names
        """
        results = []
        
        # Reset internal state
        self.player_match_count = {} # We assume clean slate for the simulation unless persistent data passed
        
        for i, match in enumerate(matches_data):
            importance = match.get('importance', 'Medium')
            prioritize_sharpness = (importance == 'Low')
            
            # Get rejected players for this specific match
            rejected_for_this_match = rejected_players_map.get(str(i), [])
            
            # Select XI
            selection = self.select_match_xi(importance, prioritize_sharpness, rejected_for_this_match)
            
            results.append({
                "matchIndex": i,
                "date": match.get('date'),
                "importance": importance,
                "selection": selection
            })
            
            # Update consecutive counts for next match in loop
            selected_names = [p['name'] for p in selection.values()]
            for name in selected_names:
                self.player_match_count[name] = self.player_match_count.get(name, 0) + 1
            
            all_names = set(self.df['Name'].values)
            rested = all_names - set(selected_names)
            for name in rested:
                self.player_match_count[name] = 0

        return results

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
        
        selector = MatchReadySelector(status_file, abilities_file)
        
        matches = data.get('matches', [])
        rejected = data.get('rejected', {}) # { "0": ["Player A"], "1": [] }
        
        plan = selector.generate_plan(matches, rejected)
        
        print(json.dumps({"success": True, "plan": plan}, cls=NumpyEncoder))
        
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))

if __name__ == '__main__':
    main()

