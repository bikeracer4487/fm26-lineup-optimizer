import pandas as pd
import json
import os
import sys
import numpy as np
import rating_calculator

# Constants for file paths
EXCEL_FILE = 'FM26 Players.xlsx'
OUTPUT_CSV = 'players-current.csv'

def calculate_generic_position_rating(row, pos_key):
    """
    Calculate a generic rating (0-200) for a position using base weights.
    This serves as a baseline skill for the CSV.
    """
    # Convert row to dict for rating_calculator
    # Ensure keys match (rating_calculator expects 'Acceleration' etc)
    # The Excel columns match standard attributes (Title Case)
    attrs = row.to_dict()
    
    # Use the base position score from FM Arena weights (0-100)
    score_100 = rating_calculator.calculate_position_score(attrs, pos_key)
    
    # Scale to 0-200
    return score_100 * 2

def update_player_data():
    """
    Read 'Paste Full' from Excel, calculate generic skills, handle loans, and save to CSV.
    """
    print(f"Updating player data from {EXCEL_FILE}...")
    
    # 1. Read Excel
    try:
        # Read 'Paste Full'
        df = pd.read_excel(EXCEL_FILE, sheet_name='Paste Full')
        
        # Filter out empty rows
        df = df.dropna(how='all')

        # Remove duplicate player entries
        if 'Name' in df.columns:
            initial_count = len(df)
            df = df.drop_duplicates(subset=['Name'], keep='first')
            dup_count = initial_count - len(df)
            if dup_count > 0:
                print(f"Removed {dup_count} duplicate player entries.")

        # Rename 'Striker' (Familiarity) to avoid overwrite by calculated 'Striker' (Ability)
        if 'Striker' in df.columns:
            df.rename(columns={'Striker': 'Striker_Familiarity'}, inplace=True)
            
        # Rename other familiarity columns to standard format if they exist
        # This preserves them while allowing us to calculate new 'Ability' columns
        fam_map = {
            'GoalKeeper': 'GK_Familiarity',
            'Defender Right': 'D(R)_Familiarity',
            'Defender Center': 'D(C)_Familiarity',
            'Defender Left': 'D(L)_Familiarity',
            'Defensive Midfielder': 'DM_Familiarity',
            'Attacking Mid. Right': 'AM(R)_Familiarity',
            'Attacking Mid. Center': 'AM(C)_Familiarity',
            'Attacking Mid. Left': 'AM(L)_Familiarity',
            # New columns from user
            'Midfielder Center': 'M(C)_Familiarity',
            'Midfielder Left': 'M(L)_Familiarity',
            'Midfielder Right': 'M(R)_Familiarity',
            'Wingback Left': 'WB(L)_Familiarity',
            'Wingback Right': 'WB(R)_Familiarity',
        }
        
        # Check for fuzzy matches if exact match not found
        current_cols = list(df.columns)
        rename_dict = {}
        
        for excel_name, csv_name in fam_map.items():
            if excel_name in current_cols:
                rename_dict[excel_name] = csv_name
            else:
                # Simple fuzzy check (case insensitive, ignore spaces)
                norm_excel = excel_name.lower().replace(' ', '').replace('.', '')
                found = False
                for col in current_cols:
                    norm_col = str(col).lower().replace(' ', '').replace('.', '')
                    if norm_col == norm_excel:
                        rename_dict[col] = csv_name
                        found = True
                        break
                if not found:
                    print(f"Warning: Column '{excel_name}' not found in Excel (Familiarity data)")

        if rename_dict:
            print(f"Renaming familiarity columns: {list(rename_dict.keys())} -> ...")
            df.rename(columns=rename_dict, inplace=True)
        
    except Exception as e:
        print(f"Error reading Excel file: {e}")
        return False

    # 2. Calculate Generic Skills (0-200)
    print("Calculating generic skill ratings...")
    
    # Mapping of Output Column Name -> Position Key (for weighting)
    # These will be the "Ability" columns
    skill_map = {
        'GK': 'GK',
        'D(R)': 'D(R)',
        'D(L)': 'D(L)',
        'D(R/L)': 'D(L/R)', # Legacy/Combined
        'D(C)': 'D(C)',
        'DM(L)': 'DM', # Use generic DM weights
        'DM(R)': 'DM',
        'WB(L)': 'WB(L)',
        'WB(R)': 'WB(R)',
        'M(C)': 'M(C)',
        'M(L)': 'M(L)',
        'M(R)': 'M(R)',
        'AM(L)': 'AM(L)',
        'AM(C)': 'AM(C)',
        'AM(R)': 'AM(R)',
        'Striker': 'ST'
    }
    
    for col_name, pos_key in skill_map.items():
        df[col_name] = df.apply(lambda row: calculate_generic_position_rating(row, pos_key), axis=1)
        
    # 3. Handle Loan Logic
    print("Processing loan status...")
    
    if 'Club' not in df.columns:
        print("Warning: 'Club' column not found in DataFrame. Assuming no loans.")
        df['LoanStatus'] = 'Own'
    else:
        def get_loan_status(club):
            if pd.isna(club) or str(club).strip() == '':
                return 'Own'
            elif str(club).strip() == 'Brixham':
                return 'LoanedIn'
            else:
                return 'LoanedOut'
                
        df['LoanStatus'] = df['Club'].apply(get_loan_status)
        
    # Filter out LoanedOut players
    initial_count = len(df)
    df = df[df['LoanStatus'] != 'LoanedOut']
    removed_count = initial_count - len(df)
    if removed_count > 0:
        print(f"Removed {removed_count} players loaned out to other clubs.")

    # 4. Save to CSV
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
