#!/usr/bin/env python3
"""
Analyze the attribute block using the unique values from Brixham4.

The attribute region appears to be around offsets +22 to +122 from anchor.
Let's map each position to the expected attribute based on value matching.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor


def find_string_position(data: bytes, target: str) -> int:
    target_bytes = target.encode('utf-8')
    pattern = len(target_bytes).to_bytes(4, 'little') + target_bytes
    pos = data.find(pattern)
    return pos + 4 if pos != -1 else -1


# User's modified attributes with their NEW values (in-game 1-20 scale)
# We'll look for the internal 0-100 values
MODIFIED_ATTRS = {
    # Technical (14 attrs)
    'Corners': 1,
    'Crossing': 2,
    'Dribbling': 3,
    'Finishing': 4,
    'First Touch': 5,
    'Free Kicks': 6,
    'Heading': 7,
    'Long Shots': 8,
    'Long Throws': 9,
    'Marking': 10,
    'Passing': 11,
    'Penalty Taking': 12,
    'Tackling': 13,
    'Technique': 14,

    # Mental (17 attrs)
    'Aggression': 15,
    'Anticipation': 16,
    'Bravery': 17,
    'Composure': 18,
    'Concentration': 19,
    'Consistency': 20,
    'Decisions': 19,  # Same as Concentration
    'Determination': 18,  # Same as Composure
    'Dirtiness': 17,  # Same as Bravery
    'Flair': 16,  # Same as Anticipation
    'Important Matches': 15,  # Same as Aggression
    'Leadership': 14,  # Same as Technique
    'Off The Ball': 13,  # Same as Tackling
    'Positioning': 12,  # Same as Penalty Taking
    'Teamwork': 11,  # Same as Passing
    'Vision': 10,  # Same as Marking
    'Work Rate': 9,  # Same as Long Throws

    # Physical (9 attrs)
    'Acceleration': 8,  # Same as Long Shots
    'Agility': 7,  # Same as Heading
    'Balance': 6,  # Same as Free Kicks
    'Injury Proneness': 5,  # Same as First Touch
    'Jumping Reach': 4,  # Same as Finishing
    'Natural Fitness': 3,  # Same as Dribbling
    'Pace': 2,  # Same as Crossing
    'Stamina': 1,  # Same as Corners
    'Strength': 2,  # Same as Crossing, Pace

    # Position Familiarity (14 positions)
    'GK Familiarity': 1,
    'DL Familiarity': 4,
    'DC Familiarity': 6,
    'DR Familiarity': 8,
    'WBL Familiarity': 10,
    'WBR Familiarity': 12,
    'DM Familiarity': 14,
    'ML Familiarity': 12,
    'MC Familiarity': 10,
    'MR Familiarity': 8,
    'AML Familiarity': 6,
    'AMC Familiarity': 4,
    'AMR Familiarity': 2,
    'ST Familiarity': 4,

    # Feet
    'Left Foot': 20,
    'Right Foot': 17,

    # Hidden/General
    'Adaptability': 2,
    'Ambition': 4,
    'Controversy': 6,
    'Loyalty': 8,
    'Pressure': 12,
    'Professionalism': 14,
    'Sportsmanship': 16,
    'Temperament': 18,
    'Versatility': 20,
}

# Group by internal value for easier matching
VALUE_TO_ATTRS = {}
for attr, val in MODIFIED_ATTRS.items():
    internal_val = val * 5
    if internal_val not in VALUE_TO_ATTRS:
        VALUE_TO_ATTRS[internal_val] = []
    VALUE_TO_ATTRS[internal_val].append(attr)


def main():
    base = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")

    print("="*80)
    print("FM26 ATTRIBUTE BLOCK ANALYSIS")
    print("="*80)

    print("\nLoading Brixham4.fm...")
    dec4 = FM26Decompressor(base / "Brixham4.fm")
    dec4.load()
    data4 = dec4.decompress_main_database()

    # Find Isaac James Smith
    name = "Isaac James Smith"
    isaac_pos = find_string_position(data4, name)
    print(f"\n{name} at: {isaac_pos:,}")

    # The anchor (Pace) was 4113 bytes before name in original
    # But structure shifted - let's find the actual attribute block

    # Strategy: Look for a contiguous region with attribute-like values
    # The user set values 1-20 (internal 5-100) in specific patterns

    # Search backwards from name for the attribute block
    print("\n" + "="*80)
    print("SEARCHING FOR ATTRIBUTE BLOCK")
    print("="*80)

    # Expected pattern: many bytes with values 5, 10, 15, 20, ... 100
    # in the typical attribute range

    # Look at regions before the name
    best_region = None
    best_score = 0

    for test_offset in range(1000, 6000, 10):  # Search different anchor points
        region_start = isaac_pos - test_offset - 100
        region_end = isaac_pos - test_offset + 100

        if region_start < 0:
            continue

        region = data4[region_start:region_end]

        # Score: count how many bytes are multiples of 5 in range 5-100
        score = 0
        for b in region:
            if 5 <= b <= 100 and b % 5 == 0:
                score += 1

        if score > best_score:
            best_score = score
            best_region = (test_offset, region_start, score)

    if best_region:
        print(f"\nBest attribute region candidate:")
        print(f"  Offset from name: -{best_region[0]}")
        print(f"  Absolute position: {best_region[1]:,}")
        print(f"  Score (attribute-like bytes): {best_region[2]}")

    # Now let's look more specifically for the known pattern
    # We know several unique values:
    # - 45 (9): Long Throws, Work Rate
    # - 65 (13): Tackling, Off The Ball
    # - 75 (15): Aggression, Important Matches
    # - 95 (19): Concentration, Decisions

    print("\n" + "="*80)
    print("SEARCHING FOR SPECIFIC VALUE PATTERNS")
    print("="*80)

    # Search for value 95 (rare) followed by other attribute values
    search_region = data4[isaac_pos - 10000:isaac_pos]

    pattern_matches = []
    for i in range(len(search_region) - 50):
        if search_region[i] == 95:  # Concentration or Decisions (19)
            # Check if surrounded by other attribute values
            nearby = search_region[max(0, i-30):i+30]
            attr_count = sum(1 for b in nearby if 5 <= b <= 100 and b % 5 == 0)
            if attr_count > 15:  # High density of attributes
                pattern_matches.append({
                    'offset': i,
                    'abs_offset': isaac_pos - 10000 + i,
                    'nearby_attr_count': attr_count,
                    'relative_to_name': i - 10000
                })

    print(f"\nFound {len(pattern_matches)} potential attribute regions with value 95")

    for m in pattern_matches[:5]:
        print(f"\n  At name offset {m['relative_to_name']:+d} (abs: {m['abs_offset']:,}):")
        print(f"    Nearby attribute-like bytes: {m['nearby_attr_count']}")

        # Show the region
        region = data4[m['abs_offset']-20:m['abs_offset']+40]
        print(f"    Values: {list(region)}")

    # Let's also try finding by the ORIGINAL anchor calculation and see what changed
    print("\n" + "="*80)
    print("LOOKING AT ORIGINAL ANCHOR REGION (+22 to +100 from calculated position)")
    print("="*80)

    anchor = isaac_pos - 4113  # Original anchor calculation
    print(f"\nCalculated anchor (name - 4113): {anchor:,}")

    # The previous output showed attributes starting around +22 from anchor
    # Let's examine that region more carefully

    print("\nAttribute-like values from +22 to +100:")
    print(f"{'Offset':>6} | {'Value':>5} | {'Scaled':>6} | Possible Attributes")
    print("-" * 70)

    attr_region_start = 22
    attr_region_end = 130

    for rel in range(attr_region_start, attr_region_end):
        abs_pos = anchor + rel
        if abs_pos >= len(data4):
            break

        val = data4[abs_pos]

        if val % 5 == 0 and 5 <= val <= 100:
            scaled = val // 5
            attrs = VALUE_TO_ATTRS.get(val, [])
            attr_str = ", ".join(attrs[:4])
            if len(attrs) > 4:
                attr_str += f" (+{len(attrs)-4})"
            print(f"{rel:>+6} | {val:>5} | {scaled:>6} | {attr_str}")

    # Check fitness values (2-byte)
    print("\n" + "="*80)
    print("FITNESS VALUES (2-byte integers)")
    print("="*80)

    for rel in range(90, 140):
        abs_pos = anchor + rel
        if abs_pos + 1 >= len(data4):
            break

        val_16 = int.from_bytes(data4[abs_pos:abs_pos+2], 'little')
        if val_16 in [7500, 6500, 55, 5100, 9528]:  # Known fitness values
            print(f"  Offset {rel:+d}: {val_16}")


if __name__ == "__main__":
    main()
