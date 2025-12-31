# FM26 Save File Parser

A Python library for extracting player data from Football Manager 2026 save files.

## Status: Phase 2 In Progress 🔄

### Major Discoveries

#### Attribute Storage Scale
- **Internal scale: 0-100** (not 1-20!)
- In-game value 1 = internal 5
- In-game value 20 = internal 100
- Conversion: `in_game = internal / 5`

#### Confirmed Attribute Offsets (relative to player name)
| Attribute | Offset | Type | Verification |
|-----------|--------|------|--------------|
| Pace | -4113 | uint8 | Brix1→Brix2 diff |
| Acceleration | -4117 | uint8 | Brix1→Brix3 diff |

#### Confirmed Fitness Offsets
| Value | Offset | Type | Notes |
|-------|--------|------|-------|
| Condition | -4008 | uint16_le | Range 0-10000 |
| Fatigue | -4010 | uint16_le | Can be negative |
| Sharpness | -4012 | uint16_le | Range 0-10000 |

#### Attribute Region
- Dense cluster from **name-4086** to **name-4010**
- ~76 bytes containing most player attributes
- Technical sequence (1-14) found at offset -4085

### What Works
- **ZSTD Decompression**: Successfully decompresses FM26 save files
- **Player Name Finding**: Locates players by name string matching
- **Differential Analysis**: Can detect byte changes between save versions
- **Fitness Extraction**: Can read Condition, Sharpness, Fatigue values
- **Attribute Region Identification**: Found the attribute block location

### Key Findings

#### Save File Format
- 26-byte custom header with "fmf." signature
- ~11,500 ZSTD compressed frames
- Frame 3 contains main database (~283MB decompressed)

#### Name Encoding
Full names stored as length-prefixed UTF-8:
```
[4-byte length][full_name_string]
Example: [17, 0, 0, 0]Isaac James Smith
```

#### Attribute Block Structure
Looking backwards from player name:
```
[...other data...][-4086: attrs start]...[-4012: sharpness][-4010: fatigue][-4008: condition]...[-4: name_len][name]
```

### Remaining Challenges

1. **Attribute Disambiguation**: Many attributes set to same values (e.g., value 5 = Corners OR Stamina OR GK Familiarity)
2. **Structure Shifts**: Save file structure changes between saves (+408 to +951 bytes)
3. **Generated Players**: Regens stored differently from database players

## Usage

```python
from fm26_parser.core.decompressor import FM26Decompressor

# Decompress save file
save_path = "/path/to/save.fm"
decompressor = FM26Decompressor(save_path)
decompressor.load()
db_data = decompressor.decompress_main_database()

# Find player by name
player_name = "Isaac James Smith"
name_bytes = player_name.encode('utf-8')
pattern = len(name_bytes).to_bytes(4, 'little') + name_bytes
name_pos = db_data.find(pattern) + 4

# Read fitness values
import struct
condition = struct.unpack('<H', db_data[name_pos-4008:name_pos-4006])[0]
sharpness = struct.unpack('<H', db_data[name_pos-4012:name_pos-4010])[0]

print(f"Condition: {condition/100:.1f}%")
print(f"Sharpness: {sharpness/100:.1f}%")
```

## Next Steps

1. **Complete Attribute Mapping**: Set one attribute to unique value (19) to disambiguate
2. **Test Multiple Players**: Verify offset consistency across different players
3. **Map Position Familiarity**: Likely stored as separate block
4. **Build Extraction API**: Create clean interface for reading all attributes

## Files

```
fm26_parser/
├── __init__.py
├── core/
│   ├── decompressor.py          # ZSTD frame handling
│   └── binary_reader.py         # Low-level byte operations
├── extractors/
│   └── name_finder.py           # Player name search
├── analysis/
│   └── record_analyzer.py       # Record structure analysis
├── mappings/
│   └── schema_v26.json          # Attribute offset schema
├── diff_saves.py                # Compare two saves
├── check_known_offsets.py       # Verify offsets across saves
├── map_all_attributes.py        # Comprehensive mapping
└── [other analysis scripts]
```

## Dependencies

```
zstandard>=0.22.0
pandas>=1.3.0
```
