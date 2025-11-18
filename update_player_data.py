"""
Update player CSV files from FM26 Players.xlsx

This script reads the FM26 Players.xlsx file and updates:
- players.csv with data from Planner sheet (columns A-N)
- players-current.csv with data from Paste Full sheet (columns A-CH)
"""

import pandas as pd
import sys
import os


def count_populated_rows(df):
    """
    Count the number of populated rows in a DataFrame.
    A row is considered populated if any cell contains a non-null value.
    """
    # Check each row - if all values are null, it's empty
    non_empty_rows = 0
    for idx, row in df.iterrows():
        if row.notna().any():
            non_empty_rows += 1
        else:
            # Once we hit an empty row, stop counting
            break
    return non_empty_rows


def main():
    excel_file = "FM26 Players.xlsx"

    # Check if Excel file exists
    if not os.path.exists(excel_file):
        print(f"ERROR: {excel_file} not found!")
        print(f"Current directory: {os.getcwd()}")
        sys.exit(1)

    print(f"Reading {excel_file}...")

    try:
        # Read the "Paste Full" sheet to count rows
        print("Reading 'Paste Full' sheet to count rows...")
        paste_full_df = pd.read_excel(excel_file, sheet_name='Paste Full', header=None)

        # Count populated rows
        num_rows = count_populated_rows(paste_full_df)
        print(f"Found {num_rows} populated rows in 'Paste Full' sheet")

        if num_rows == 0:
            print("ERROR: No populated rows found in 'Paste Full' sheet!")
            sys.exit(1)

        # Extract data from Planner sheet (columns A-N, rows 1 to num_rows)
        print(f"\nReading Planner sheet (A1:N{num_rows})...")
        planner_df = pd.read_excel(
            excel_file,
            sheet_name='Planner',
            usecols='A:N',  # Columns A through N
            nrows=num_rows,
            header=0  # First row is header
        )

        # Write to players.csv
        output_file = 'players.csv'
        print(f"Writing {len(planner_df)} rows to {output_file}...")
        planner_df.to_csv(output_file, index=False, encoding='utf-8-sig')
        print(f"✓ Successfully updated {output_file}")

        # Extract data from Paste Full sheet (columns A-CH, rows 1 to num_rows)
        print(f"\nReading 'Paste Full' sheet (A1:CH{num_rows})...")
        paste_full_df = pd.read_excel(
            excel_file,
            sheet_name='Paste Full',
            usecols='A:CH',  # Columns A through CH (86 columns)
            nrows=num_rows,
            header=0  # First row is header
        )

        # Write to players-current.csv
        output_file = 'players-current.csv'
        print(f"Writing {len(paste_full_df)} rows to {output_file}...")
        paste_full_df.to_csv(output_file, index=False, encoding='utf-8-sig')
        print(f"✓ Successfully updated {output_file}")

        print("\n" + "="*70)
        print("SUCCESS: Player data updated successfully!")
        print("="*70)

    except ValueError as e:
        print(f"\nERROR: Sheet not found or invalid range - {e}")
        print("\nAvailable sheets in the Excel file:")
        try:
            xl_file = pd.ExcelFile(excel_file)
            for sheet in xl_file.sheet_names:
                print(f"  - {sheet}")
        except Exception as list_error:
            print(f"Could not list sheets: {list_error}")
        sys.exit(1)

    except Exception as e:
        print(f"\nERROR: Failed to process Excel file - {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
