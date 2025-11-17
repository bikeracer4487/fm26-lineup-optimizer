# FM26 Player Data Extractor - Documentation

This directory contains comprehensive documentation for extracting player data directly from Football Manager 2026's memory.

## 📚 Documentation Files

### 1. [EXTRACTOR_QUICKSTART.md](EXTRACTOR_QUICKSTART.md)
**Start here!** Quick start guide for using the FM26 player data extractor.

- Overview and benefits
- Setup process summary
- Basic usage instructions
- Troubleshooting common issues
- FAQ

### 2. [cheat-engine-finding-addresses.md](cheat-engine-finding-addresses.md)
**Detailed technical guide** for finding memory addresses with Cheat Engine.

- Step-by-step Cheat Engine tutorials
- Finding simple values (ages, ratings)
- Creating stable pointer chains
- Discovering player array structures
- Finding all required offsets
- Advanced techniques
- Testing and validation

### 3. [player-data-extraction-research.md](player-data-extraction-research.md)
**Research document** explaining the technical background and methodology.

- How FMRTE and Genie Scout work
- Memory scanning techniques
- Development tools and libraries
- Legal considerations
- Alternative extraction methods
- Community resources

## 🎯 Quick Navigation

**I want to...**

- **Get started quickly** → Read [EXTRACTOR_QUICKSTART.md](EXTRACTOR_QUICKSTART.md)
- **Learn how to use Cheat Engine** → Read [cheat-engine-finding-addresses.md](cheat-engine-finding-addresses.md)
- **Understand the technical background** → Read [player-data-extraction-research.md](player-data-extraction-research.md)
- **Just run the extractor** → See [Usage](#usage) below

## 🚀 Usage

### Prerequisites

1. Python 3.6+ with `pymem` installed (`pip install pymem`)
2. Cheat Engine 7.5+ installed
3. FM26 running with a save loaded
4. Memory addresses configured (see guides above)

### Quick Run

```bash
# Extract player data from FM26
python fm26_player_extractor.py

# Use with lineup optimizer
python fm_team_selector_optimal.py players-extracted.csv
```

## 📋 Process Overview

```
┌─────────────────────────────────────────────────────────────┐
│ Step 1: One-Time Setup (1-3 hours)                          │
├─────────────────────────────────────────────────────────────┤
│ 1. Install Cheat Engine                                     │
│ 2. Follow cheat-engine-finding-addresses.md guide          │
│ 3. Find memory addresses for player data                    │
│ 4. Update MemoryConfig in fm26_player_extractor.py         │
│ 5. Test extraction and verify data                          │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 2: Regular Use (minutes)                               │
├─────────────────────────────────────────────────────────────┤
│ 1. Start FM26 and load your save                           │
│ 2. Run: python fm26_player_extractor.py                    │
│ 3. Run: python fm_team_selector_optimal.py players-extracted.csv │
│ 4. View optimal lineup!                                     │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│ Step 3: After FM26 Updates (1-2 hours)                     │
├─────────────────────────────────────────────────────────────┤
│ 1. Re-verify pointer chains in Cheat Engine                 │
│ 2. Update any changed offsets in config                     │
│ 3. Test and validate extraction                             │
└─────────────────────────────────────────────────────────────┘
```

## ⚠️ Important Notes

- **Windows Only**: Memory reading only works on Windows
- **Configuration Required**: You MUST find memory addresses first
- **Game Version Specific**: Offsets may change with FM26 patches
- **Personal Use**: For single-player personal use only
- **No Guarantees**: May violate FM26's EULA, use at your own risk

## 🔧 Tools and Scripts

Located in parent directory:

- `fm26_player_extractor.py` - Main extraction script
- `fm_team_selector_optimal.py` - Optimal lineup selector (uses extracted data)
- `fm_rotation_selector.py` - Rotation squad selector
- `requirements.txt` - Python dependencies

## 📊 Expected Output

The extractor creates `players-extracted.csv` with this format:

```csv
Name,Best Position,Age,CA,PA,Striker,AM(L),AM(C),AM(R),DM(L),DM(R),D(C),D(R/L),GK,Chosen Role
John Smith,AM(C),22,145,165,15.0,18.5,19.2,17.8,14.2,14.5,12.0,13.5,8.0,Advanced Playmaker
...
```

This CSV can be directly used with all the lineup optimizer scripts.

## 🆘 Getting Help

### If extraction fails:

1. Check `fm26_extractor.log` for error messages
2. Verify FM26 is running with save loaded
3. Re-check your memory offsets in Cheat Engine
4. See troubleshooting sections in the guides

### If offsets break after update:

1. Check community forums for updated offsets:
   - SortItOutSI Forums (C# and Unity Development)
   - FearlessCheat Engine (FM26 tables)
2. Re-run Cheat Engine pointer scans
3. Update MemoryConfig with new values

### Community Resources:

- **SortItOutSI**: https://sortitoutsi.net/
- **FearlessCheat Engine**: https://fearlessrevolution.com/
- **GitHub**: Search "fm26" or "football manager"

## 📖 Learning Path

### For Beginners:

1. Start with [EXTRACTOR_QUICKSTART.md](EXTRACTOR_QUICKSTART.md)
2. Read first 3 sections of [cheat-engine-finding-addresses.md](cheat-engine-finding-addresses.md)
3. Try finding player age (simplest example)
4. Gradually work through other offsets
5. Ask for help in community forums

### For Experienced Users:

1. Skim [player-data-extraction-research.md](player-data-extraction-research.md) for methodology
2. Jump to advanced sections of [cheat-engine-finding-addresses.md](cheat-engine-finding-addresses.md)
3. Use ReClass.NET or x64dbg for faster structure mapping
4. Share findings with community

### For Developers:

1. Read full [player-data-extraction-research.md](player-data-extraction-research.md)
2. Study the extractor script architecture
3. Consider C# implementation for better performance
4. Contribute improvements via pull requests

## 🔒 Legal Disclaimer

This tool is provided for **educational and personal use only**.

- ⚠️ May violate Football Manager 2026's End User License Agreement
- ⚠️ No warranties or guarantees provided
- ✅ For single-player personal use only
- ✅ Does not include any game code or assets
- ✅ Based on 15+ year precedent of community tools (FMRTE, Genie Scout)

The authors assume no liability for your use of this tool. Use at your own risk.

## 🤝 Contributing

If you successfully configure the extractor for your FM26 version:

1. Save your Cheat Engine table (.CT file)
2. Document your offsets clearly
3. Share on community forums with version number
4. Consider submitting a pull request with version-specific configs

Help the community!

## 📝 Version History

- **v1.0** (2025-01-XX): Initial release
  - Complete extraction framework
  - Comprehensive Cheat Engine guides
  - Support for all position ratings
  - CSV export matching lineup optimizer format

## 📧 Questions?

- Check the FAQ in [EXTRACTOR_QUICKSTART.md](EXTRACTOR_QUICKSTART.md)
- Review troubleshooting sections in each guide
- Search community forums (links above)
- Open an issue in the repository

---

**Ready to start?** → Read [EXTRACTOR_QUICKSTART.md](EXTRACTOR_QUICKSTART.md)

**Need help with Cheat Engine?** → Read [cheat-engine-finding-addresses.md](cheat-engine-finding-addresses.md)

**Want technical background?** → Read [player-data-extraction-research.md](player-data-extraction-research.md)
