import pandas as pd
import json
import os
import sys
import numpy as np

# Constants for file paths
EXCEL_FILE = 'FM26 Players.xlsx'
WEIGHTS_FILE = 'attribute_weights.json'
OUTPUT_CSV = 'players-current.csv'

def load_weights():
    """Load attribute weights from JSON file."""
    if not os.path.exists(WEIGHTS_FILE):
        raise FileNotFoundError(f"{WEIGHTS_FILE} not found. Please run extract_weights.py first.")
    
    with open(WEIGHTS_FILE, 'r') as f:
        return json.load(f)

def calculate_position_skill(row, weights, pos_name):
    """
    Calculate skill rating for a specific position using the formula:
    Average(InPossessionScore, OutPossessionScore) * 10
    
    Where Score = Sum(Attr * Weight) / Sum(Weights)
    """
    pos_weights = weights.get(pos_name)
    if not pos_weights:
        return 0.0
        
    scores = []
    for phase in ['In', 'Out']:
        phase_weights = pos_weights.get(phase, {})
        if not phase_weights:
            continue
            
        total_weight = sum(phase_weights.values())
        if total_weight == 0:
            continue
            
        weighted_sum = 0
        for attr, weight in phase_weights.items():
            # Get attribute value from row
            # Handle potential missing values
            val = row.get(attr, 0)
            if pd.isna(val):
                val = 0
            elif isinstance(val, str):
                # Handle "-" or other non-numeric
                try:
                    val = float(val)
                except:
                    val = 0
            
            weighted_sum += val * weight
            
        scores.append(weighted_sum / total_weight)
    
    if not scores:
        return 0.0
        
    # Average of In and Out scores, multiplied by 10 (to get 0-200 scale)
    final_score = (sum(scores) / len(scores)) * 10
    return final_score

def update_player_data():
    """
    Read 'Paste Full' from Excel, calculate skills, handle loans, and save to CSV.
    """
    print(f"Updating player data from {EXCEL_FILE}...")
    
    # 1. Load Weights
    try:
        weights = load_weights()
    except Exception as e:
        print(f"Error loading weights: {e}")
        # Attempt to run extract_weights.py if json missing? 
        # For now, assume it exists or fail.
        return False

    # 2. Read Excel
    try:
        # Read 'Paste Full'
        # We assume row 0 is header
        df = pd.read_excel(EXCEL_FILE, sheet_name='Paste Full')
        
        # Filter out empty rows (if any)
        df = df.dropna(how='all')
        
        # Rename 'Striker' (Familiarity) to avoid overwrite by calculated 'Striker' (Ability)
        if 'Striker' in df.columns:
            df.rename(columns={'Striker': 'Striker_Familiarity'}, inplace=True)
        
    except Exception as e:
        print(f"Error reading Excel file: {e}")
        return False

    # 3. Calculate Skills
    print("Calculating skill ratings...")
    
    # Mapping of Output Column Name -> Weights Key
    # Output columns match those expected by fm_team_selector_optimal (e.g. GK, D(C))
    # Weights keys match those in attribute_weights.json
    
    skill_map = {
        'GK': 'GK',
        'D(R/L)': 'D(R/L)',
        'D(C)': 'D(C)',
        'DM(L)': 'DM(L)',
        'DM(R)': 'DM(R)',
        'AM(L)': 'AM(L)',
        'AM(C)': 'AM(C)',
        'AM(R)': 'AM(R)',
        'Striker': 'Striker'
    }
    
    for col_name, weight_key in skill_map.items():
        df[col_name] = df.apply(lambda row: calculate_position_skill(row, weights, weight_key), axis=1)
        
    # 4. Handle Loan Logic
    print("Processing loan status...")
    
    # Ensure Club column exists (it's usually index 86 "Club")
    if 'Club' not in df.columns:
        print("Warning: 'Club' column not found in DataFrame. Assuming no loans.")
        df['LoanStatus'] = 'Own'
    else:
        def get_loan_status(club):
            if pd.isna(club) or str(club).strip() == '':
                return 'Own'
            elif str(club).strip() == 'Brixham':
                return 'LoanedOut'
            else:
                return 'LoanedIn'
                
        df['LoanStatus'] = df['Club'].apply(get_loan_status)
        
    # Filter out LoanedOut players (Unavailable)
    # User: "unavailable for match selection or training" -> Remove from dataset
    initial_count = len(df)
    df = df[df['LoanStatus'] != 'LoanedOut']
    removed_count = initial_count - len(df)
    if removed_count > 0:
        print(f"Removed {removed_count} players loaned out to other clubs.")

    # 5. Save to CSV
    print(f"Saving to {OUTPUT_CSV}...")
    try:
        df.to_csv(OUTPUT_CSV, index=False, encoding='utf-8-sig')
        print("SUCCESS: Player data updated successfully.")
        return True
    except Exception as e:
        print(f"Error saving CSV: {e}")
        return False

if __name__ == "__main__":
    update_player_data()

