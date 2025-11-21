import pandas as pd
import json
import sys

def extract_weights():
    try:
        print("Reading AttWeights from Excel...")
        df = pd.read_excel('FM26 Players.xlsx', sheet_name='AttWeights')
        
        # Create mapping of standard attribute names (Paste Full) to AttWeights columns
        # Map: PasteFull -> AttWeights
        attr_map = {
            'Acceleration': 'Acceleration',
            'Agility': 'Agility',
            'Balance': 'Balance',
            'Jumping': 'Jumping Reach',
            'Natural Fitness': 'Natural Fitness',
            'Pace': 'Pace',
            'Stamina': 'Stamina',
            'Strength': 'Strength',
            'Aerial Ability': 'Aerial Reach',
            'Command Of Area': 'Command Of Area', # Paste Full has 'Command Of Area' (Title Case?) Check.
            # Check inspect_excel.py output: 39: Command Of Area. OK.
            'Communication': 'Communication',
            'Eccentricity': 'Eccentricity',
            'Handling': 'Handling',
            'Kicking': 'Kicking',
            'One On Ones': 'One On Ones', # 44: One On Ones
            'Tendency To Punch': 'Punching (Tendency)', # 47: Tendency To Punch
            'Reflexes': 'Reflexes',
            'Rushing Out': 'Rushing Out (Tendency)', # 46: Rushing Out
            'Throwing': 'Throwing',
            'Aggression': 'Aggression',
            'Anticipation': 'Anticipation',
            'Bravery': 'Bravery',
            'Composure': 'Composure',
            'Concentration': 'Concentration',
            'Decisions': 'Decisions',
            'Determination': 'Determination',
            'Flair': 'Flair',
            'Leadership': 'Leadership',
            'Off The Ball': 'Off The Ball',
            'Positioning': 'Positioning',
            'Teamwork': 'Teamwork',
            'Vision': 'Vision',
            'Workrate': 'Work Rate', # 62: Workrate
            'Corners': 'Corners',
            'Crossing': 'Crossing',
            'Dribbling': 'Dribbling',
            'Finishing': 'Finishing',
            'First Touch': 'First Touch',
            'Freekicks': 'Free Kick Taking', # 68: Freekicks
            'Heading': 'Heading',
            'Long Shots': 'Long Shots',
            'Longthrows': 'Long Throws', # 71: Longthrows
            'Marking': 'Marking',
            'Passing': 'Passing',
            'Penalty Taking': 'Penalty Taking',
            'Tackling': 'Tackling',
            'Technique': 'Technique'
        }

        # Indices for positions in AttWeights dataframe
        # Based on inspect_excel.py output which matches row order
        pos_indices = {
            'GK': {'In': 0, 'Out': 9},
            'D(R/L)': {'In': 1, 'Out': 10},
            'D(C)': {'In': 2, 'Out': 11},
            'DM(L)': {'In': 4, 'Out': 12}, # DM-DLP + DM-SDM
            'DM(R)': {'In': 3, 'Out': 12}, # DM-DM + DM-SDM
            'AM(L)': {'In': 5, 'Out': 13}, # AM(L) IF + AM(L/R) TW
            'AM(C)': {'In': 6, 'Out': 14}, # AM(C) AM + AM(C) TAM
            'AM(R)': {'In': 7, 'Out': 13}, # AM(R) W + AM(L/R) TW
            'Striker': {'In': 8, 'Out': 15} # ST(C) CF + ST(C) CO
        }
        
        weights_json = {}
        
        for pos, indices in pos_indices.items():
            weights_json[pos] = {}
            
            for phase, idx in indices.items():
                phase_weights = {}
                row = df.iloc[idx]
                
                for pf_attr, aw_attr in attr_map.items():
                    if aw_attr in row:
                        phase_weights[pf_attr] = float(row[aw_attr])
                    else:
                        print(f"Warning: {aw_attr} not found in Excel columns for row {idx}")
                
                # Verify sum is not zero
                weight_sum = sum(phase_weights.values())
                if weight_sum == 0:
                     print(f"Warning: Zero weight sum for {pos} {phase}")
                
                weights_json[pos][phase] = phase_weights
                
        with open('attribute_weights.json', 'w') as f:
            json.dump(weights_json, f, indent=2)
            
        print("Successfully created attribute_weights.json")
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    extract_weights()

