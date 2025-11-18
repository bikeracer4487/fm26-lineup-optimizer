# Football Manager - Optimal Starting XI Selector

Automatically selects the best Starting XI for your Football Manager team based on position-specific ratings.

## 🆕 Advanced Features (NEW!)

**Two new scripts** now available that factor in match sharpness, physical condition, fatigue, and intelligent rotation:

- **fm_training_advisor.py** - Analyzes squad depth and recommends position training
- **fm_match_ready_selector.py** - Selects lineups considering fitness, fatigue, and fixture scheduling

**📚 [See the Advanced Features Guide](ADVANCED_FEATURES.md) for complete documentation**

---

## Core Selection Scripts

### 1. **fm_team_selector_optimal.py** (RECOMMENDED)
Uses the **Hungarian algorithm** to find the truly optimal player-position assignment that maximizes total team rating.
- ✅ Finds the mathematically optimal lineup
- ✅ Typically 1-3% better average rating
- ✅ Better player-position assignments
- ⏱️ Still very fast (< 1 second)

### 2. **fm_team_selector.py** (Basic)
Uses a **greedy algorithm** that selects the best available player for each position in order.
- ⚡ Slightly faster
- ⚠️ May not find the optimal solution
- 📊 Good for quick checks

**Recommendation:** Use `fm_team_selector_optimal.py` for your actual team selection!

## Formation

This script is configured for the following 4-2-3-1 formation:

```
         STC
  AML    AMC    AMR
      DM1  DM2
  DL  DC1  DC2  DR
         GK
```

## Requirements

- Python 3.6+
- pandas
- numpy
- scipy (for optimal version)
- openpyxl (for Excel files)

Install all requirements:
```bash
pip install -r requirements.txt
```

## Quick Start

### Using the Optimal Version (Recommended)
```bash
python fm_team_selector_optimal.py players.csv
```

### Using the Basic Version
```bash
python fm_team_selector.py players.csv
```

### Compare Both Approaches
```bash
python compare_selections.py players.csv
```

## Input File Format

Your spreadsheet should have the following columns:

- **Name**: Player name
- **Best Position**: Player's natural position
- **Age**: Player's age
- **CA**: Current Ability
- **PA**: Potential Ability
- **Striker**: Rating for Striker position
- **AM(L)**: Rating for Attacking Midfielder Left
- **AM(C)**: Rating for Attacking Midfielder Center
- **AM(R)**: Rating for Attacking Midfielder Right
- **DM(L)**: Rating for Defensive Midfielder Left
- **DM(R)**: Rating for Defensive Midfielder Right
- **D(C)**: Rating for Defender Center
- **D(R/L)**: Rating for Full Back (Right/Left)
- **GK**: Rating for Goalkeeper
- **Chosen Role**: (Optional) Current assigned role

## How It Works

1. **Greedy Selection Algorithm**: The script selects the best available player for each position based on their position-specific rating
2. **No Duplicates**: Each player can only be selected once
3. **DM Positions**: Uses the average of DM(L) and DM(R) ratings for both DM positions
4. **Full Back Positions**: Uses D(R/L) rating for both DL and DR positions

## Output

The script will:
1. Display the optimal Starting XI in the terminal with ratings
2. Calculate the average team rating
3. Export the Starting XI to `starting_xi.csv`

### Example Output:
```
============================================================
OPTIMAL STARTING XI
============================================================

Attack:
  STC   : Alan Hackney         (92.5)

Attacking Midfield:
  AML   : Daniel Willard       (78.2)
  AMC   : Marc Mitchell        (91.9)
  AMR   : Andrey Quintino      (93.1)

Defensive Midfield:
  DM1   : Ryan Penny           (80.8)
  DM2   : Hisashi Roddy        (89.0)

Defense:
  DL    : Taye Weir            (78.4)
  DC1   : Asa Hall             (87.1)
  DC2   : Jayden Batterbatch   (84.1)
  DR    : Hisashi Roddy        (91.6)

Goalkeeper:
  GK    : Ashley Sarahs        (89.3)

============================================================
Average Team Rating: 86.89
============================================================
```

## Customization

### Change Formation

To modify the formation, edit the `formation` list in the `main()` function:

```python
formation = [
    ('GK', 'GK'),
    ('DL', 'D(R/L)'),
    ('DC1', 'D(C)'),
    ('DC2', 'D(C)'),
    ('DR', 'D(R/L)'),
    ('DM1', 'DM_avg'),
    ('DM2', 'DM_avg'),
    ('AML', 'AM(L)'),
    ('AMC', 'AM(C)'),
    ('AMR', 'AM(R)'),
    ('STC', 'Striker')
]
```

### Change DM Selection Method

By default, DM positions use the average of DM(L) and DM(R). To change this:

**Option A: Use DM(L) for DM1 and DM(R) for DM2:**
```python
formation = [
    # ... other positions ...
    ('DM1', 'DM(L)'),
    ('DM2', 'DM(R)'),
    # ... other positions ...
]
```

**Option B: Use only DM(C) if you have that column:**
```python
formation = [
    # ... other positions ...
    ('DM1', 'DM(C)'),
    ('DM2', 'DM(C)'),
    # ... other positions ...
]
```

## Advanced Features

### Export Different Formats

Modify the export section to save in different formats:

```python
# Export as Excel
xi_df.to_excel('starting_xi.xlsx', index=False)

# Export as JSON
xi_df.to_json('starting_xi.json', orient='records')
```

### Consider Fitness/Condition

Add additional filtering before selection:

```python
# Only select players with good condition
available_players = available_players[available_players['Condition'] >= 90]
```

### Age-based Selection

Prefer younger players with similar ratings:

```python
# Add age weighting (younger = better when ratings are close)
available_players['weighted_rating'] = (
    available_players[position_column] + 
    (30 - available_players['Age']) * 0.1
)
```

## Troubleshooting

**Error: "Could not find file"**
- Make sure your spreadsheet is in the same directory as the script
- Or provide the full path: `python fm_team_selector.py /path/to/players.xlsx`

**Error: "KeyError: 'ColumnName'"**
- Check that your column names match exactly (case-sensitive)
- Ensure all required columns exist in your spreadsheet

**Players have NaN ratings**
- The script automatically skips players with missing ratings for specific positions
- Check your spreadsheet for empty cells

## All Available Scripts

| Script | Purpose | Use Case |
|--------|---------|----------|
| `fm_team_selector_optimal.py` | Optimal XI selection using ratings only | Finding the theoretical best lineup |
| `fm_team_selector.py` | Greedy XI selection | Quick selections, prototyping |
| `fm_rotation_selector.py` | Dual squad selection (First XI + Rotation XI) | Analyzing squad depth |
| `compare_selections.py` | Compare greedy vs optimal approaches | Validation and benchmarking |
| **`fm_training_advisor.py`** | **Training position recommendations** | **Improving squad depth** |
| **`fm_match_ready_selector.py`** | **Match-day lineup with fitness factors** | **Weekly match planning** |

**Bold** = Advanced features (see [ADVANCED_FEATURES.md](ADVANCED_FEATURES.md))

## License

Free to use and modify for your Football Manager adventures!

## Support

For issues or feature requests, please check:
- Column names match exactly
- Data is in proper numeric format
- File is not corrupted
- pandas and openpyxl are installed correctly
