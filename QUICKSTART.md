# Quick Start Guide

## Getting Your Football Manager Team Selection Script Running

### Step 1: Install Python Dependencies

```bash
pip install -r requirements.txt
```

### Step 2: Prepare Your Data

You have two options:

**Option A: Export from your existing spreadsheet**
- Save your Football Manager spreadsheet as `players.csv` or `players.xlsx`
- Place it in the same folder as the Python scripts

**Option B: Use the sample data**
- The included `players.csv` contains sample data you can use for testing
- Replace it with your own data when ready

### Step 3: Run the Script

**For the best results (recommended):**
```bash
python fm_team_selector_optimal.py players.csv
```

**For a quick/simple selection:**
```bash
python fm_team_selector.py players.csv
```

**To compare both methods:**
```bash
python compare_selections.py players.csv
```

### Step 4: View Results

The script will:
1. Display your optimal Starting XI in the terminal
2. Show natural positions and ratings for each player
3. Suggest 7 substitutes
4. Export everything to `starting_xi.csv`

## Example Output

```
======================================================================
OPTIMAL STARTING XI
======================================================================

Attack:
  STC   : Alan Hackney         [AM(C)]   (92.5)

Attacking Midfield:
  AML   : Scott Little         [AM(R)]   (91.1)
  AMC   : Marc Mitchell        [AM(C)]   (91.9)
  AMR   : Paul Stroud          [AM(R)]   (90.2)

Defensive Midfield:
  DM1   : Andrey Quintino      [AM(R)]   (89.3)
  DM2   : Aydin Webb           [AM(C)]   (86.6)

Defense:
  DL    : Hisashi Roddy        [D(R/L)]  (91.6)
  DC1   : Asa Hall             [D(C)]    (87.1)
  DC2   : Jayden Batterbatch   [D(C)]    (84.1)
  DR    : Ryan Penny           [DM(L)]   (80.4)

Goalkeeper:
  GK    : Ashley Sarahs        [GK]      (89.3)

======================================================================
Average Team Rating: 88.55
======================================================================
```

## Customizing for Different Formations

To change the formation, edit the `formation` list in the script:

### Example: 4-4-2 Formation
```python
formation = [
    ('GK', 'GK'),
    ('DL', 'D(R/L)'),
    ('DC1', 'D(C)'),
    ('DC2', 'D(C)'),
    ('DR', 'D(R/L)'),
    ('ML', 'AM(L)'),   # Changed from AML
    ('MC1', 'DM_avg'), # Changed from DM1
    ('MC2', 'DM_avg'), # Changed from DM2
    ('MR', 'AM(R)'),   # Changed from AMR
    ('STC1', 'Striker'),
    ('STC2', 'Striker')
]
```

### Example: 3-5-2 Formation
```python
formation = [
    ('GK', 'GK'),
    ('DC1', 'D(C)'),
    ('DC2', 'D(C)'),
    ('DC3', 'D(C)'),
    ('WBL', 'D(R/L)'),  # Wing back left
    ('DM', 'DM_avg'),
    ('MC1', 'AM(C)'),
    ('MC2', 'AM(C)'),
    ('WBR', 'D(R/L)'),  # Wing back right
    ('STC1', 'Striker'),
    ('STC2', 'Striker')
]
```

## Troubleshooting

**"ModuleNotFoundError: No module named 'pandas'"**
- Run: `pip install -r requirements.txt`

**"FileNotFoundError: [Errno 2] No such file or directory: 'players.csv'"**
- Make sure your data file is in the same folder as the script
- Or provide the full path: `python fm_team_selector_optimal.py /path/to/players.csv`

**Players have weird ratings or missing data**
- Check your CSV/Excel file has the correct column names
- Column names are case-sensitive: `AM(L)` not `am(l)`

## Tips for Best Results

1. **Keep your spreadsheet updated** - Update player ratings as they develop
2. **Use the optimal version** - It's barely slower but gives much better results
3. **Check natural positions** - The script shows [Natural Position] so you can see who's playing out of position
4. **Review substitutes** - Good backup options are suggested automatically
5. **Export results** - The CSV export makes it easy to track your selections

## Need Help?

Check these files:
- `README.md` - Full documentation
- `compare_selections.py` - See the difference between greedy and optimal
- Sample data in `players.csv` - Example of correct format

Happy managing!
