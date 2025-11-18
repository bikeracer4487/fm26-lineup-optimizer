# FM26 HTML Export Guide - Extract Player Data the Easy Way

This guide shows you how to extract player data from FM26 using the game's **built-in HTML export feature**. No Cheat Engine, no memory scanning, no reverse engineering needed!

## Why This Approach is Better

✅ **Uses official FM26 features** - Built-in export via Ctrl+P
✅ **Works immediately** - No configuration or address finding needed
✅ **Safe and reliable** - No memory manipulation
✅ **Patch-proof** - Doesn't break when FM26 updates
✅ **Cross-platform** - Works on Windows, Mac, and Linux (where FM26 runs)
✅ **Legal** - Uses only official game features

## Quick Start (5 Minutes)

### Step 1: Install Python Dependencies

```bash
pip install beautifulsoup4
```

Or install all dependencies:

```bash
pip install -r requirements.txt
```

### Step 2: Set Up Custom View in FM26

1. **Download the custom view file**: `fm26_lineup_optimizer_view.fmf` (in this repository)

2. **Launch FM26** and load your save game

3. **Go to Squad screen**

4. **Import the custom view:**
   - Right-click on any column header
   - Select **"Import View"**
   - Navigate to `fm26_lineup_optimizer_view.fmf`
   - Click **"Load"**

5. **Verify columns are showing:**
   - You should see: Name, Age, Position, CA, PA, and all position ratings
   - If some columns are missing, we'll fix that next

### Step 3: Export HTML from FM26

1. **Make sure you're on the Squad screen** with the custom view loaded

2. **Press Ctrl+P** (or go to menu → Print Screen)

3. **Save options dialog appears:**
   - Format: Select **"Web Page"** or **"HTML"**
   - Filename: e.g., `my_squad_export.html`
   - Location: Save somewhere you'll remember (e.g., same folder as this project)

4. **Click Save**

### Step 4: Convert HTML to CSV

```bash
python fm26_html_parser.py my_squad_export.html
```

This creates `players-extracted.csv` in the current directory!

### Step 5: Use with Lineup Optimizer

```bash
python fm_team_selector_optimal.py players-extracted.csv
```

Done! You now have your optimal Starting XI.

---

## Detailed Instructions

### Setting Up the Perfect Custom View

The included `.fmf` file should work, but if you want to customize it or create your own:

#### Required Columns (Must Have):

| Column Name | FM26 Field ID | Description |
|-------------|---------------|-------------|
| Name | `person_name` | Player name |
| Age | `person_age` | Player age |
| Best Position | `person_preferred_position` | Natural position |
| CA | `person_current_ability` | Current Ability |
| PA | `person_potential_ability` | Potential Ability |
| Striker | `person_position_rating_st` | ST rating |
| AM(L) | `person_position_rating_aml` | AML rating |
| AM(C) | `person_position_rating_amc` | AMC rating |
| AM(R) | `person_position_rating_amr` | AMR rating |
| DM(L) | `person_position_rating_dml` | DML rating |
| DM(R) | `person_position_rating_dmr` | DMR rating |
| D(C) | `person_position_rating_dc` | DC rating |
| D(R/L) | `person_position_rating_drl` | DR/DL rating |
| GK | `person_position_rating_gk` | GK rating |

#### Optional but Useful Columns:

| Column Name | FM26 Field ID | Description |
|-------------|---------------|-------------|
| Condition | `person_condition_percentage` | Current fitness |
| Match Sharpness | `person_match_sharpness` | Match readiness |
| Morale | `person_morale` | Player morale |

#### Creating a Custom View Manually:

If the `.fmf` file doesn't work or you want to add more columns:

1. **Go to Squad screen in FM26**

2. **Right-click column headers** → **"Add Column"**

3. **Search for and add each required column:**
   - Type "Current Ability" and add it
   - Type "Potential Ability" and add it
   - Type "Position Rating" and add ST, AML, AMC, AMR, etc.
   - Continue for all required columns

4. **Arrange columns** by dragging headers to preferred order

5. **Save the view:**
   - Right-click column headers
   - Select **"Save View"**
   - Name it: "Lineup Optimizer Export"

6. **Now export** using Ctrl+P as described above

---

## Troubleshooting

### Problem: "No tables found in HTML file"

**Cause:** The HTML export might be empty or in an unexpected format.

**Solutions:**
1. Make sure you're exporting from the Squad screen (not other screens)
2. Try exporting again with **"Web Page, Complete"** format
3. Open the HTML file in a browser - you should see a table with player data
4. If the table looks good in browser but script fails, send the HTML file for debugging

### Problem: "Missing fields" warning after export

**Cause:** Some columns weren't included in the FM26 export.

**Solutions:**
1. Check which fields are missing in the script output
2. Go back to FM26 and add those columns to your view
3. Re-export the HTML
4. Run the parser again

### Problem: Position ratings show as 0 or blank

**Cause:** FM26 might not have calculated position ratings yet, or columns weren't included.

**Solutions:**
1. In FM26, go to **Preferences** → **Interface**
2. Enable **"Show Position Ratings"** or similar option
3. Wait for FM26 to calculate ratings (may take a game day)
4. Alternatively, manually add position rating columns to your view

### Problem: Can't find the .fmf custom view file

**Location:** The file `fm26_lineup_optimizer_view.fmf` should be in the root of this repository.

**If missing:**
1. Download it from the repository
2. Or create a custom view manually (see instructions above)
3. Or just add the required columns by hand - no .fmf needed

### Problem: Export includes youth/reserve players I don't want

**Solutions:**
1. **Filter the Squad view** in FM26 before exporting:
   - Use the filter dropdown (top of screen)
   - Select "First Team Squad Only"
   - Then export

2. **Or filter in the CSV** afterward:
   - Open `players-extracted.csv` in Excel
   - Delete rows you don't want
   - Save the file

---

## Advanced Usage

### Exporting Multiple Squads

Export each squad separately:

```bash
# Export First Team
# (In FM26: go to First Team squad, export HTML)
python fm26_html_parser.py first_team.html
mv players-extracted.csv players-first-team.csv

# Export U21s
# (In FM26: go to U21 squad, export HTML)
python fm26_html_parser.py u21_squad.html
mv players-extracted.csv players-u21.csv

# Combine if needed
cat players-first-team.csv <(tail -n +2 players-u21.csv) > players-all.csv
```

### Automated Workflow

Create a batch file or shell script:

**Windows (export_and_optimize.bat):**
```batch
@echo off
echo Parsing FM26 HTML export...
python fm26_html_parser.py squad_export.html

if %ERRORLEVEL% EQU 0 (
    echo Running lineup optimizer...
    python fm_team_selector_optimal.py players-extracted.csv
) else (
    echo Export failed. Check the log file.
)
pause
```

**Linux/Mac (export_and_optimize.sh):**
```bash
#!/bin/bash
echo "Parsing FM26 HTML export..."
python3 fm26_html_parser.py squad_export.html

if [ $? -eq 0 ]; then
    echo "Running lineup optimizer..."
    python3 fm_team_selector_optimal.py players-extracted.csv
else
    echo "Export failed. Check the log file."
fi
```

### Updating Data Regularly

Whenever your squad changes:

1. In FM26: **Ctrl+P** → overwrite previous HTML file
2. Run: `python fm26_html_parser.py squad_export.html`
3. Run: `python fm_team_selector_optimal.py players-extracted.csv`

Takes less than 30 seconds total!

### Comparing Different Game States

Track how your squad improves over a season:

```bash
# Week 1
python fm26_html_parser.py week1_export.html
mv players-extracted.csv players-week1.csv

# Week 10
python fm26_html_parser.py week10_export.html
mv players-extracted.csv players-week10.csv

# Week 20
python fm26_html_parser.py week20_export.html
mv players-extracted.csv players-week20.csv

# Now you can compare CA/PA changes over time
```

---

## Understanding the Output

After running the parser, check the summary:

```
======================================================================
EXPORT SUMMARY
======================================================================
Players exported: 28
Output file: players-extracted.csv

Found fields: Name, Age, Best Position, CA, PA, Striker, AM(L), AM(C),...
Missing fields: Chosen Role

Note: Missing fields may need to be added to your FM26 custom view.
======================================================================
```

**Found fields:** Successfully extracted from HTML
**Missing fields:** Weren't in the HTML export (add to custom view if needed)

### Validating the Data

Open `players-extracted.csv` and spot-check a few players:

1. **Names correct?** Should match FM26
2. **Ages match?** Quick sanity check
3. **Ratings reasonable?** Should be 0-20 scale
4. **All your players there?** Count should match FM26 squad size

If anything looks wrong, check the `fm26_html_parser.log` file for details.

---

## Comparison: HTML Export vs Memory Scanning

| Feature | HTML Export (This Method) | Memory Scanning (Previous) |
|---------|---------------------------|---------------------------|
| **Setup Time** | 5 minutes | 1-3 hours |
| **Difficulty** | Easy | Hard |
| **Requires** | BeautifulSoup4 | Cheat Engine, pymem |
| **Configuration** | None | Find memory addresses |
| **After FM26 Updates** | Still works | Usually breaks |
| **Cross-platform** | Yes (Windows/Mac/Linux) | Windows only |
| **Legal concerns** | None (uses official features) | May violate EULA |
| **Reliability** | Very high | Medium |

**Verdict:** HTML export is the clear winner for most users!

---

## FAQs

**Q: Do I need to re-export every time I play?**
A: Only when your squad changes (transfers, loans, etc.) or you want updated ratings.

**Q: Can I export opponent squads?**
A: Yes! Navigate to their squad screen and export the same way. Great for scouting.

**Q: What if FM26 doesn't have position ratings?**
A: Make sure they're enabled in game preferences. Or use the in-game editor to view them.

**Q: Can I edit the CSV before using it?**
A: Absolutely! Open in Excel, make changes, save, then run the optimizer.

**Q: Does this work with older FM versions?**
A: The HTML parser should work with FM24, FM25, etc. The export process is similar.

**Q: Can I export attributes like Pace, Passing, etc.?**
A: Yes! Add those columns to your custom view and the parser will include them in the CSV.

**Q: Why use this instead of just looking at the game?**
A: The optimizer finds mathematically optimal lineups you might miss. It considers all combinations.

---

## Next Steps

1. ✅ Set up custom view in FM26
2. ✅ Export HTML using Ctrl+P
3. ✅ Run the parser: `python fm26_html_parser.py your_export.html`
4. ✅ Run the optimizer: `python fm_team_selector_optimal.py players-extracted.csv`
5. 🎉 Enjoy your optimal Starting XI!

---

## Files You Need

```
fm26-lineup-optimizer/
├── fm26_html_parser.py              # The parser script (THIS TOOL)
├── fm26_lineup_optimizer_view.fmf   # Custom view to import (optional)
├── requirements.txt                 # Python dependencies
└── docs/
    └── HTML_EXPORT_GUIDE.md         # This guide
```

---

## Getting Help

**If you encounter issues:**

1. Check `fm26_html_parser.log` for error details
2. Verify the HTML file opens correctly in a web browser
3. Make sure BeautifulSoup4 is installed: `pip install beautifulsoup4`
4. Post your issue on the repository with:
   - The error message
   - Your FM26 version
   - A screenshot of your FM26 squad view

---

**Enjoy your optimal lineup selections!**

This method is simple, reliable, and doesn't require any reverse engineering.
Happy managing! ⚽
