# Quick Start Guide

## Using the UI Application (Recommended)

The UI application is the primary way to use this tool.

### Step 1: Install Dependencies

```bash
# Install Python dependencies
pip install -r requirements.txt

# Install Node.js dependencies for UI
cd ui
npm install
```

### Step 2: Prepare Your Data

1. Export your Football Manager player data from FMRTE to `FM26 Players.xlsx`
2. Place the file in the project root directory
3. The UI will automatically refresh player data when launched

### Step 3: Launch the UI

```bash
cd ui
npm run dev
```

This opens the Electron application with these tabs:

- **Fixture List** - Manage your upcoming matches
- **Match Selection** - View optimized lineups for each match
- **Position Training** - Training recommendations
- **Rest & Rotation** - Player fatigue management

### Step 4: Workflow

1. **Add Fixtures**: In the Fixture List tab, add your upcoming matches with dates and importance levels
2. **Generate Lineups**: Switch to Match Selection tab - lineups are auto-generated for the next 5 matches
3. **Manual Overrides**: Click the edit icon on any position to override with a different player
4. **Confirm Lineup**: Click "Confirm" to lock a lineup - this prevents automatic recalculation
5. **Advance Date**: Use the sidebar date picker to move through your season

### Match Importance Levels

- **High**: Best XI selected based purely on match effectiveness (no rotation penalties)
- **Medium**: Balanced selection with some rotation consideration
- **Low**: Development-focused, rotates players and considers training
- **Sharpness**: Prioritizes players who need match time to build form

### Key Features

- **5-Match Limit**: Only next 5 matches have lineups calculated (performance optimization)
- **Manual Overrides**: Override any position, shows "MANUAL" badge
- **Confirm/Lock**: Prevents recalculation of confirmed lineups
- **Historical Tracking**: Confirmed lineups are saved to track consecutive matches

---

## CLI Scripts (Advanced Users)

For automation or when the UI isn't suitable:

### Quick Selection

```bash
# Optimal lineup (recommended)
python fm_team_selector_optimal.py players-current.csv

# Basic greedy selection
python fm_team_selector.py players-current.csv

# Compare both methods
python compare_selections.py players-current.csv
```

### Match-Ready Selection (with fitness/fatigue)

```bash
python fm_match_ready_selector.py
```

### Training Advisor

```bash
python fm_training_advisor.py
```

See [ADVANCED_FEATURES.md](ADVANCED_FEATURES.md) for detailed CLI documentation.

---

## Troubleshooting

**UI won't start:**
- Ensure Node.js 18+ is installed
- Run `npm install` in the `ui/` directory
- Check the console for Python path errors

**No players shown:**
- Verify `FM26 Players.xlsx` exists in the project root
- Check that it has a "Paste Full" sheet with player data

**Wrong lineups:**
- Check match importance settings
- Verify player data is up to date (condition, fatigue, sharpness)
- Clear manual overrides if needed

**Rotation not working:**
- Confirm lineups to track consecutive matches
- Check `ui/data/confirmed_lineups.json` for history

## Need Help?

- `README.md` - Full documentation
- `CLAUDE.md` - Technical reference for AI assistants
- `ADVANCED_FEATURES.md` - CLI script documentation
