# Using the Player Data Update Batch File

## Overview

The `update_players.bat` batch file automates the process of updating player data from your Football Manager 2026 Excel export to the CSV files used by the lineup optimizer.

## Prerequisites

1. **Windows 11** (or Windows 10)
2. **Python 3.8+** installed and available in your PATH
3. **Required Python packages** installed:
   ```bash
   pip install -r requirements.txt
   ```
4. **FM26 Players.xlsx** file in the repository root directory

## How It Works

The batch file performs the following steps automatically:

1. **Reads FM26 Players.xlsx** and counts populated rows in the "Paste Full" sheet
2. **Updates players.csv** with data from the "Planner" sheet (columns A-N)
3. **Updates players-current.csv** with data from the "Paste Full" sheet (columns A-CH)
4. **Runs the match-ready team selector** using the updated data
5. **Pauses** so you can read the lineup results

## Usage

### Basic Usage

Simply double-click `update_players.bat` in Windows Explorer, or run from Command Prompt:

```cmd
update_players.bat
```

### Expected Excel File Structure

Your `FM26 Players.xlsx` file must contain:

- **"Planner" sheet** with columns A-N:
  - Name, Best Position, Age, CA, PA, Striker, AM(L), AM(C), AM(R), DM(L), DM(R), D(C), D(R/L), GK

- **"Paste Full" sheet** with columns A-CH (86 columns):
  - Complete player data including attributes, condition, injuries, etc.

### What Gets Updated

| File | Source | Columns | Purpose |
|------|--------|---------|---------|
| `players.csv` | Planner sheet | A-N (14 cols) | Basic player ratings for lineup selection |
| `players-current.csv` | Paste Full sheet | A-CH (86 cols) | Detailed player data including injuries, fitness, etc. |

## Output

The batch file will display:

1. **Progress messages** as it processes the Excel file
2. **Row count** from the Paste Full sheet
3. **Confirmation** of successful CSV updates
4. **Team selection results** from the match-ready selector
5. **A pause** allowing you to read the results before closing

## Troubleshooting

### "FM26 Players.xlsx not found"

- Ensure the Excel file is in the same directory as the batch file
- Check the filename matches exactly (case-sensitive)

### "Sheet not found"

- Verify your Excel file contains sheets named "Planner" and "Paste Full" (exact names)
- Check that sheet names don't have extra spaces

### "Python not recognized"

- Python is not in your system PATH
- Install Python from python.org and ensure "Add to PATH" is checked during installation

### Import errors (pandas, openpyxl, etc.)

Run this command to install all required packages:
```cmd
pip install -r requirements.txt
```

## Manual Alternative

If you prefer to run the steps manually:

```cmd
# Step 1: Update CSV files
python update_player_data.py

# Step 2: Run team selector
python fm_match_ready_selector.py players-current.csv players.csv
```

## How the Row Counting Works

The script automatically detects how many rows contain data in the "Paste Full" sheet:

- Scans rows from top to bottom
- A row is considered "populated" if any cell contains data
- Stops counting when it encounters a completely empty row
- Uses this count to extract the exact range from both sheets

This ensures you don't need to manually specify row numbers - it adapts to your squad size automatically.

## Privacy Note

The `FM26 Players.xlsx` file is excluded from Git (via `.gitignore`) to keep your player data private.

## Next Steps

After running the batch file:

1. Review the team selection output
2. Check for any injured or banned players flagged
3. Use the suggested lineup in your FM26 save
4. Enjoy your optimized team selection!

---

**Created by:** Doug Mason (2025)
**For:** FM26 Lineup Optimizer - Brixham AFC Save
