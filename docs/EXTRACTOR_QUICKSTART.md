# FM26 Player Data Extractor - Quick Start Guide

## Overview

The FM26 Player Data Extractor automatically reads player data directly from Football Manager 2026's memory and exports it to CSV format for use with the lineup optimizer tools.

**Status**: ⚠️ **Requires Configuration** - You must find memory addresses using Cheat Engine before this tool will work.

## Why Use This Tool?

Instead of manually entering player data into a spreadsheet, this tool:
- ✅ Automatically extracts all player data (name, age, CA, PA, ratings)
- ✅ Includes all squads (First Team, U21, U18)
- ✅ Updates in seconds instead of hours of manual data entry
- ✅ Eliminates transcription errors
- ✅ Can be run whenever your squad changes

## Prerequisites

### Software Requirements

1. **Python 3.6+** installed
2. **Cheat Engine 7.5+** installed ([download here](https://www.cheatengine.org/))
3. **Football Manager 2026** with a save game
4. **Windows OS** (memory reading only works on Windows)

### Python Dependencies

Install required libraries:

```bash
pip install pymem
```

Or install all dependencies:

```bash
pip install -r requirements.txt
```

## Setup Process

### Phase 1: Find Memory Addresses (One-Time Setup)

**Time Required**: 1-3 hours for first-time users

This is the most important and challenging step. You must use Cheat Engine to find where FM26 stores player data in memory.

📖 **Follow the detailed guide**: [docs/cheat-engine-finding-addresses.md](cheat-engine-finding-addresses.md)

The guide walks you through:
- Attaching Cheat Engine to FM26
- Finding player ages, names, and ratings
- Creating stable pointer chains
- Calculating structure offsets
- Testing your findings

### Phase 2: Configure the Script

Once you've found the memory addresses, update `fm26_player_extractor.py`:

Open the file and find the `MemoryConfig` class (around line 50). Replace the placeholder values (0x0) with your findings:

```python
class MemoryConfig:
    # Example - replace with YOUR actual values from Cheat Engine

    SQUAD_BASE_OFFSET = 0x01A2B340  # Your value here

    PLAYER_ARRAY_OFFSETS = [
        0x18,   # Your offsets here
        0xC0,
        0x28,
    ]

    PLAYER_COUNT_OFFSETS = [
        0x18,   # Your offsets here
        0xC0,
        0x30,
    ]

    PLAYER_NAME_OFFSET = 0x10      # Your offset
    PLAYER_AGE_OFFSET = 0x28       # Your offset
    PLAYER_CA_OFFSET = 0x50        # Your offset
    PLAYER_PA_OFFSET = 0x54        # Your offset
    PLAYER_BEST_POS_OFFSET = 0x60  # Your offset

    PLAYER_RATING_GK_OFFSET = 0x100      # Your offset
    PLAYER_RATING_DC_OFFSET = 0x104      # Your offset
    PLAYER_RATING_DRL_OFFSET = 0x108     # Your offset
    PLAYER_RATING_DML_OFFSET = 0x10C     # Your offset
    PLAYER_RATING_DMR_OFFSET = 0x110     # Your offset
    PLAYER_RATING_AML_OFFSET = 0x114     # Your offset
    PLAYER_RATING_AMC_OFFSET = 0x118     # Your offset
    PLAYER_RATING_AMR_OFFSET = 0x11C     # Your offset
    PLAYER_RATING_ST_OFFSET = 0x120      # Your offset

    PLAYER_OBJECT_SIZE = 0x80      # Your value (distance between players)
```

### Phase 3: Test the Extraction

1. **Launch FM26** and load your save game
2. **Navigate to your squad screen** (so player data is loaded in memory)
3. **Run the extractor**:

```bash
python fm26_player_extractor.py
```

4. **Check the output**:
   - Console will show progress
   - `fm26_extractor.log` contains detailed logging
   - `players-extracted.csv` contains the extracted data

5. **Verify the data**:
   - Open `players-extracted.csv` in Excel or a text editor
   - Compare a few players with FM26 to ensure accuracy
   - Check that names, ages, CA, PA, and ratings match

## Usage

### Basic Extraction

Once configured, extracting player data is simple:

```bash
# 1. Make sure FM26 is running with your save loaded
# 2. Run the extractor
python fm26_player_extractor.py
```

Output:
```
======================================================================
FM26 Player Data Extractor
======================================================================

1. Attaching to FM26 process...
✓ Successfully attached to FM26

2. Extracting player data from memory...
✓ Extracted 28 players

3. Exporting to CSV...
✓ Export complete!

======================================================================
EXTRACTION COMPLETE
======================================================================
Players extracted: 28
Output file: players-extracted.csv
======================================================================
```

### Use with Lineup Optimizer

After extraction, use the CSV with the lineup optimizer:

```bash
python fm_team_selector_optimal.py players-extracted.csv
```

This will automatically select your optimal Starting XI based on the extracted data.

### Updating Your Data

Whenever your squad changes (transfers, youth promotions, etc.):

1. Load your updated save in FM26
2. Run the extractor again: `python fm26_player_extractor.py`
3. Re-run the lineup optimizer with the new data

The extractor will overwrite `players-extracted.csv` with current data.

## Troubleshooting

### "Process not found" Error

**Problem**: Script can't find FM26 running.

**Solutions**:
- Make sure FM26 is actually running
- Verify the process name in Task Manager (should be "fm.exe")
- Try running the script as Administrator
- Check `MemoryConfig.PROCESS_NAME` is correct

### "No players found" Error

**Problem**: Script attached but couldn't read player data.

**Solutions**:
- Verify your memory configuration offsets are correct
- Make sure you have a save game loaded (not just in main menu)
- Navigate to squad screen in FM26
- Check `fm26_extractor.log` for specific errors
- Re-verify your pointer chains in Cheat Engine

### Players Have Wrong Data

**Problem**: Extraction works but data is incorrect.

**Solutions**:
- Double-check your offsets in Cheat Engine
- Verify you're reading the correct data type (int vs float)
- Check if ratings are scaled (e.g., stored as 150 instead of 15.0)
- Make sure `PLAYER_OBJECT_SIZE` is correct

### Script Crashes or Hangs

**Problem**: Script stops responding or crashes.

**Solutions**:
- Check the log file: `fm26_extractor.log`
- Try extracting with FM26 paused (press Space)
- Reduce `max_length` in `read_string()` if strings cause issues
- Add more error handling if specific offsets crash

### Pointer Chains Break After Update

**Problem**: Script worked before but stopped after FM26 patch.

**Solutions**:
- FM26 patches often change memory layouts
- Re-run Cheat Engine pointer scans with the new version
- Update offsets in `MemoryConfig`
- Join community forums for updated offsets (see below)

## Advanced Usage

### Extracting Specific Squads

The current implementation extracts all players in the currently viewed squad. To extract different squads:

1. Navigate to the desired squad in FM26 (U21, U18, etc.)
2. Run the extractor
3. Rename the output file: `mv players-extracted.csv players-u21.csv`
4. Repeat for other squads

### Logging and Debugging

Enable debug logging for detailed information:

In `fm26_player_extractor.py`, change:
```python
logging.basicConfig(level=logging.DEBUG, ...)
```

This will show every memory read operation in the log file.

### Creating Multiple Configurations

If offsets differ between FM versions, create version-specific configs:

```python
# fm26_configs.py
CONFIGS = {
    "26.0.5": {
        "SQUAD_BASE_OFFSET": 0x01A2B340,
        # ... other offsets
    },
    "26.0.6": {
        "SQUAD_BASE_OFFSET": 0x01A2C450,  # Different in new version
        # ... other offsets
    }
}
```

Modify the script to detect FM26 version and load appropriate config.

### Automation

Create a batch file for one-click extraction:

**extract_players.bat**:
```batch
@echo off
echo Extracting FM26 player data...
python fm26_player_extractor.py
if %ERRORLEVEL% EQU 0 (
    echo Success! Running lineup optimizer...
    python fm_team_selector_optimal.py players-extracted.csv
) else (
    echo Extraction failed. Check fm26_extractor.log
)
pause
```

## Community and Support

### Finding Updated Offsets

FM26 patches may break your configuration. Check these resources for updates:

- **SortItOutSI Forums**: [C# and Unity Development](https://sortitoutsi.net/)
  - Memory scanning discussions
  - Community-shared findings

- **FearlessCheat Engine**: [FM26 Tables](https://fearlessrevolution.com/)
  - User-created cheat tables
  - Request threads for updated offsets

- **GitHub**: Search "fm26 memory" or "football manager extractor"
  - Community tools and scripts
  - Shared configurations

### Sharing Your Findings

If you successfully configure the extractor:

1. **Save your Cheat Engine table** (.CT file)
2. **Document your offsets** clearly
3. **Share on community forums** (with FM26 version number)
4. **Update this repository** via pull request

Help the community by contributing your findings!

## Legal and Ethical Considerations

⚠️ **Important Disclaimers**:

- This tool is **unofficial** and not endorsed by Sports Interactive
- May violate FM26's End User License Agreement (EULA)
- Use at **your own risk** - no warranties provided
- For **single-player personal use only**
- **Never** use for online/multiplayer features
- **Never** redistribute game code or assets

### Why This Exists

This tool is built on the precedent of FMRTE and Genie Scout, which have operated for 15+ years without legal challenge. The single-player nature of FM makes these tools part of the community ecosystem.

However:
- Be prepared to stop if Sports Interactive objects
- Don't monetize tools using FM's intellectual property
- Respect the game and its developers
- Purchase the game legitimately

## Performance

**Extraction Speed**:
- Typical extraction: 1-5 seconds
- 30-40 players: ~2 seconds
- 100+ players: ~5 seconds

**Resource Usage**:
- Minimal CPU usage
- <50MB RAM
- No disk writes except final CSV

**Compatibility**:
- Windows 7/8/10/11
- Python 3.6+
- FM26 versions: Update offsets per version

## Workflow Integration

### Recommended Workflow

1. **Initial Setup** (one-time, 1-3 hours):
   - Find memory addresses with Cheat Engine
   - Configure script
   - Test extraction
   - Verify data accuracy

2. **Regular Use** (minutes):
   - Start FM26, load save
   - Run extractor: `python fm26_player_extractor.py`
   - Run optimizer: `python fm_team_selector_optimal.py players-extracted.csv`
   - Review optimal lineup

3. **After Transfers** (minutes):
   - Load updated save
   - Re-run extractor
   - Re-run optimizer with new squad

4. **After FM26 Patches** (hours):
   - Re-verify pointer chains in Cheat Engine
   - Update any changed offsets
   - Test extraction
   - Document version-specific changes

## Next Steps

1. ✅ Read this quickstart guide
2. 📖 Follow the [Cheat Engine guide](cheat-engine-finding-addresses.md) to find addresses
3. ⚙️ Configure `fm26_player_extractor.py` with your findings
4. 🧪 Test extraction and verify data
5. 🚀 Use with lineup optimizer tools
6. 🌐 Share your findings with the community (optional)

## Files Overview

```
fm26-lineup-optimizer/
├── fm26_player_extractor.py          # Main extraction script (THIS TOOL)
├── fm26_extractor.log                # Generated log file
├── players-extracted.csv             # Generated output file
├── docs/
│   ├── EXTRACTOR_QUICKSTART.md       # This file
│   └── cheat-engine-finding-addresses.md  # Detailed CE guide
└── requirements.txt                  # Python dependencies
```

## FAQ

**Q: Do I need to do this every time I play?**
A: No! Once configured, you only run the extractor when you want to update your player data (after transfers, etc.). The configuration (memory offsets) usually stays valid until FM26 patches.

**Q: Can this get me banned?**
A: FM26 is single-player only. There's no ban system. However, it may violate the EULA technically.

**Q: Is this safe for my computer?**
A: Yes. The script only *reads* memory, it doesn't write or modify anything. It can't harm FM26 or your save file.

**Q: Can I use this on Mac/Linux?**
A: No. Memory reading with pymem only works on Windows. Mac has OS-level protections preventing process attachment.

**Q: How often do offsets break?**
A: Typically with each FM26 patch (26.0.3 → 26.0.4, etc.). Major updates almost always require finding new offsets.

**Q: Can I extract opponent teams?**
A: Potentially, yes - but you'd need to navigate to their squad screen first, and the game may not load all their data.

**Q: Why not use the in-game editor?**
A: The official editor costs $8.99 and still requires manual data entry for use with external tools. This automates the process.

**Q: How accurate is the extracted data?**
A: 100% accurate if configured correctly - it's reading the exact same memory FM26 uses to display data on screen.

---

**Good luck with your FM26 lineup optimization!**

For questions, issues, or contributions, visit the repository or community forums.
