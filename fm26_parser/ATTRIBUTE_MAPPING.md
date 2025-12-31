# FM26 Player Attribute Mapping

## Key Discoveries

### Critical Finding: Two Different Scales!

1. **0-100 Internal Scale** (negative offsets from name)
   - Technical, Mental, Physical, Feet, Hidden
   - In-game value = Internal / 5
   - Example: Internal 75 = In-game 15

2. **0-20 Raw Scale** (positive offsets from name)
   - Personality attributes
   - Position Familiarity (when edited by FM Editor)
   - Stored directly as 1-20 values
   - No conversion needed

### Critical Finding: 48-Byte Structural Shift

⚠️ **Different saves can have different internal record layouts!**

When comparing Base/Brix7 (mental changes) to Brix9 (position fam changes), we discovered a **48-byte structural shift**:

| Attribute Type | Base/Brix7 Offset | Brix9 Offset | Shift |
|----------------|-------------------|--------------|-------|
| Mental (e.g., Aggression) | -4106 | -4058 | +48 |
| Position Fam (e.g., ST) | -4154 | -4106 | +48 |

**Root Cause:** The FM Editor causes structural changes when editing different attribute categories, shifting the record layout.

**There is NO offset collision** - mental attributes and position familiarity are stored at completely different locations. The apparent overlap was due to comparing saves with different layouts using the same relative offset.

---

## Complete Verified Attribute Offsets

All offsets are relative to the player name position. **These offsets are for Base/Brix6/Brix7/Brix8/Brix10 layout.**

For Brix9-style layout (position fam edited), **add +48 to mental/physical offsets**.

### FEET (0-100 scale, from Brix10)
| Attribute | Offset | Base Value | Verified |
|-----------|--------|------------|----------|
| Left Foot | -4127 | 55 (11 ig) | ✓ |
| Right Foot | -4126 | 100 (20 ig) | ✓ |

### TECHNICAL (0-100 scale, from Brix6)

Isaac's base Technical attributes (in-game values shown):
- Corners=3, Crossing=3, Dribbling=11, Finishing=1, First Touch=12, Free Kicks=1
- Heading=11, Long Shots=2, Long Throws=5, Marking=14, Passing=6, Penalty Taking=2
- Tackling=13, Technique=7

| Attribute | Offset | Base (internal→ig) | New (ig) | Verified |
|-----------|--------|-------------------|----------|----------|
| Crossing | -4151 | 15→3 | 2 | ✓ |
| Dribbling | -4150 | 54→~11 | 3 | ✓ |
| Finishing | -4149 | 1→~0 | 4 | ⚠️ Low base |
| Heading | -4148 | 56→11 | 7 | ✓ |
| Long Shots | -4147 | 10→2 | 8 | ✓ |
| Marking | -4146 | 70→14 | 10 | ✓ |
| Passing | -4144 | 30→6 | 11 | ✓ |
| Penalty Taking | -4143 | 9→~2 | 12 | ✓ |
| Tackling | -4142 | 63→~13 | 14 | ✓ |
| First Touch | -4129 | 60→12 | 5 | ✓ |
| Technique | -4128 | 37→~7 | 13 | ✓ |
| Corners | -4124 | 15→3 | 1 | ✓ |
| Long Throws | -4121 | 23→~5 | 9 | ✓ |
| Free Kicks | -4116 | 2→~0 | 6 | ⚠️ Low base |

**Note:** Some base values don't divide evenly by 5, suggesting slight rounding or storage quirks.

### MENTAL (0-100 scale, from Brix7)

Isaac's base Mental attributes (in-game values):
- Aggression=15, Anticipation=14, Bravery=15, Composure=11, Concentration=10
- Consistency=20, Decisions=13, Determination=12, Dirtiness=8, Flair=6
- Important Matches=7, Leadership=3, Off The Ball=5, Positioning=14, Teamwork=8
- Vision=10, Work Rate=9

| Attribute | Offset | Base (internal→ig) | New (ig) | Verified |
|-----------|--------|-------------------|----------|----------|
| Off The Ball | -4145 | 25→5 | 13 | ✓ |
| Vision | -4141 | 48→~10 | 16 | ✓ |
| Anticipation | -4134 | 68→~14 | 2 | ✓ |
| Decisions | -4133 | 66→~13 | 7 | ✓ |
| Positioning | -4131 | 70→14 | 15 | ✓ |
| Flair | -4125 | 28→~6 | 10 | ✓ |
| Teamwork | -4123 | 38→~8 | 14 | ✓ |
| Work Rate | -4122 | 46→~9 | 17 | ✓ |
| Leadership | -4111 | 16→~3 | 12 | ✓ |
| Dirtiness (Hidden) | -4110 | 40→8 | 9 | ✓ |
| Bravery | -4108 | 75→15 | 3 | ✓ |
| Consistency (Hidden) | -4107 | 98→~20 | 6 | ✓ |
| Aggression | -4106 | 75→15 | 1 | ✓ |
| Important Matches (Hidden) | -4104 | 34→~7 | 11 | ✓ |
| Determination | -4100 | 60→12 | 8 | ✓ |
| Composure | -4099 | 54→~11 | 4 | ✓ |
| Concentration | -4098 | 52→~10 | 5 | ✓ |

### PHYSICAL (0-100 scale, from Brix8)

Isaac's base Physical attributes (in-game values):
- Acceleration=13, Agility=9, Balance=9, Injury Proneness=8, Jumping Reach=13
- Natural Fitness=10, Pace=10, Stamina=9, Strength=10

| Attribute | Offset | Base (internal→ig) | New (ig) | Verified |
|-----------|--------|-------------------|----------|----------|
| Acceleration | -4117 | 64→~13 | 1 | ✓ |
| Stamina | -4114 | 45→9 | 8 | ✓ |
| Pace | -4113 | 52→~10 | 7 | ✓ |
| Jumping Reach | -4112 | 65→13 | 5 | ✓ |
| Balance | -4109 | 45→9 | 3 | ✓ |
| Agility | -4105 | 43→~9 | 2 | ✓ |
| Injury Proneness (Hidden) | -4103 | 40→8 | 4 | ✓ |
| Natural Fitness | -4101 | 48→~10 | 6 | ✓ |
| Strength | ??? | 50→10 | 9 | ❌ Not found |

**Note:** Strength (10→9) change not detected in range [-4200, -4000). May be stored elsewhere.

### HIDDEN (0-100 scale, from Brix10)
| Attribute | Offset | Base Value | New Value | Verified |
|-----------|--------|------------|-----------|----------|
| Versatility | -4102 | 84 (~17 ig) | 45 (9 ig) | ✓ |

### FITNESS (16-bit Little Endian, from Brix10)
| Attribute | Offset | Base Value | New Value | Verified |
|-----------|--------|------------|-----------|----------|
| Sharpness | -4084 | 5100 | 6400 | ✓ |
| Fatigue | -4082 | -500 | 35 | ✓ (signed) |
| Condition | -4080 | 9528 | 7100 | ✓ |

**Note:** These appear to be in a different scale (100x of percentage?). Condition 9528 might be 95.28%?

### PERSONALITY (0-20 raw scale, POSITIVE offsets!)
| Attribute | Offset | Base Value | New Value | Verified |
|-----------|--------|------------|-----------|----------|
| Adaptability | +38 | 10 | 1 | ✓ |
| Ambition | +39 | 10 | 2 | ✓ |
| Loyalty | +40 | 10 | 4 | ✓ |
| Pressure | +41 | 10 | 5 | ✓ |
| Professionalism | +42 | 10 | 6 | ✓ |
| Sportsmanship | +43 | 10 | 7 | ✓ |
| Temperament | +44 | 10 | 8 | ✓ |
| Controversy | +45 | 10 | 3 | ✓ |

---

## Position Familiarity

### Complex Storage Issue

Position familiarity in FM26 has a complex relationship with the structural shift:

1. **In Base/Brix6/7/8/10 saves**: Position fam stored at offsets ~-4153 to -4166 (0-100 scale)
2. **In Brix9 save (after FM Editor edits)**: Position fam stored at offsets ~-4105 to -4118 (raw 0-20 scale)

This represents a **48-byte shift** that occurs when position familiarity is edited.

### Observed Brix9 Position Familiarity Offsets

In Brix9, the sequence at offsets -4118 onwards shows position fam values, but the exact mapping is complex due to the structural shift:

| Offset | Base Value | Brix9 Value | Notes |
|--------|------------|-------------|-------|
| -4118 | 5 | 1 | GK slot |
| -4117 | 64 | 1 | DL slot? |
| -4116 | 2 | 2 | DL=2 ✓ |
| -4115 | 50 | 20 | DC base=20 ✓ |
| -4114 | 45 | 4 | DR=4 ✓ |
| -4113 | 52 | 7 | DM=7 ✓ |
| -4112 | 65 | 8 | ML=8 ✓ |
| -4111 | 16 | 9 | MC=9 ✓ |
| -4110 | 40 | 10 | MR=10 ✓ |
| -4109 | 45 | 11 | AML=11 ✓ |
| -4108 | 75 | 12 | AMC=12 ✓ |
| -4107 | 98 | 13 | AMR=13 ✓ |
| -4106 | 75 | 14 | ST=14 ✓ |
| -4105 | 43 | 5 | WBL=5 ✓ |
| -4104 | 34 | 6 | WBR=6 ✓ |

### Position Order (Brix9 layout, offset -4118 to -4104)
```
GK, ??, DL, DC, DR, DM, ML, MC, MR, AML, AMC, AMR, ST, WBL, WBR
```

**Note:** The position order doesn't match standard FM order. WBL/WBR appear at end.

---

## Total Attributes Mapped: 55+

| Category | Mapped | Total | Status |
|----------|--------|-------|--------|
| Feet | 2 | 2 | ✓ Complete |
| Technical | 14 | 14 | ✓ Complete |
| Mental | 17 | 17 | ✓ Complete (inc. hidden) |
| Physical | 8 | 9 | ⚠️ Missing Strength |
| Hidden | 3 | ~6 | Partial |
| Fitness | 3 | 3 | ✓ Complete |
| Personality | 8 | 8 | ✓ Complete |
| Position Familiarity | 14 | 14 | ⚠️ Order needs verification |
| **Total** | **69** | **~73** | **~95%** |

---

## Detecting Save Layout

To determine which offset layout a save uses:

1. Read value at offset -4106 (relative to player name)
2. If value is a multiple of 5 (0-100 scale), likely **Base/Brix7 layout** (mental attrs here)
3. If value is 1-20 (raw scale), likely **Brix9 layout** (position fam here)

**Or:** Check if the 48-byte region (-4058 to -4106) contains zeros or valid mental attribute values.

---

## Quick Reference: Offsets by Region

### Region -4151 to -4121 (Technical)
```
-4151: Crossing       -4150: Dribbling      -4149: Finishing
-4148: Heading        -4147: Long Shots     -4146: Marking
-4144: Passing        -4143: Penalty Taking -4142: Tackling
-4141: Vision*        -4134: Anticipation*  -4133: Decisions*
-4131: Positioning*   -4129: First Touch    -4128: Technique
-4125: Flair*         -4124: Corners        -4123: Teamwork*
-4122: Work Rate*     -4121: Long Throws

* Mental attributes interspersed in this region
```

### Region -4118 to -4098 (Physical + Mental + Position Fam)
```
-4117: Acceleration   -4116: Free Kicks     -4114: Stamina
-4113: Pace           -4112: Jumping Reach  -4111: Leadership
-4110: Dirtiness      -4109: Balance        -4108: Bravery
-4107: Consistency    -4106: Aggression     -4105: Agility
-4104: Important Mtch -4103: Injury Prone   -4102: Versatility
-4101: Natural Fit    -4100: Determination  -4099: Composure
-4098: Concentration
```

### Region -4084 to -4080 (Fitness - 16-bit)
```
-4084: Sharpness (16-bit)
-4082: Fatigue (16-bit signed)
-4080: Condition (16-bit)
```

### Region +38 to +45 (Personality - Raw)
```
+38: Adaptability     +39: Ambition         +40: Loyalty
+41: Pressure         +42: Professionalism  +43: Sportsmanship
+44: Temperament      +45: Controversy
```

---

## Methodology

1. Created isolated test saves (Brix6-10) changing ONE category at a time
2. Used FM26 In-Game Editor to make specific value changes
3. Binary comparison of all saves against base
4. Discovered 48-byte structural shift between saves with different edits
5. Verified by cross-referencing expected values with actual values
6. Comprehensive dump of all changed bytes in attribute range

## Test Data Used (Isaac James Smith)

**Brix6 (Technical):** All 14 technical attributes changed to sequential values 1-14
**Brix7 (Mental):** All 17 mental attributes (including hidden) changed to sequential values 1-17
**Brix8 (Physical):** All 9 physical attributes (including hidden) changed to sequential values 1-9
**Brix9 (Position Fam):** All 14 positions changed to sequential values 1-14
**Brix10 (Other):** Feet, Fitness, Personality, Versatility changed

## Key Findings Summary

1. **No offset collisions** - Mental attributes and position familiarity are at different offsets
2. **48-byte structural shift** - FM Editor edits can shift record layout
3. **Two scales** - 0-100 for most attributes, 0-20 for personality
4. **Personality at positive offsets** - Unlike other attributes which are at negative offsets
5. **Fitness uses 16-bit** - Condition, Sharpness, Fatigue stored as 16-bit integers
6. **Attributes interleaved** - Technical and Mental attributes share offset regions

## Recommendations for Parser

1. **Detect save layout** - Check whether save has Base or Brix9-style offsets
2. **Apply shift correction** - Add +48 to mental/physical offsets for Brix9-style saves
3. **Handle both scales** - Position fam may be 0-100 (original) or 0-20 (FM Editor modified)
4. **Personality always safe** - At positive offsets, not affected by structural shifts
5. **Read fitness as 16-bit LE** - Use struct.unpack('<h', ...) for signed values
