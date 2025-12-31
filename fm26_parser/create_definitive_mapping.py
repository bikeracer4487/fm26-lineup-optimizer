#!/usr/bin/env python3
"""
Create definitive attribute mapping by cross-referencing original and modified values.

Since multiple attributes have the same NEW value, we use the ORIGINAL values to disambiguate.
"""

import sys
from pathlib import Path
import json

sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor


def find_string_position(data: bytes, target: str) -> int:
    target_bytes = target.encode('utf-8')
    pattern = len(target_bytes).to_bytes(4, 'little') + target_bytes
    pos = data.find(pattern)
    return pos + 4 if pos != -1 else -1


# User's data: (original_value, new_value)
ATTR_CHANGES = {
    # Technical Attributes
    'Corners': (3, 1),
    'Crossing': (3, 2),
    'Dribbling': (11, 3),
    'Finishing': (1, 4),
    'First Touch': (12, 5),
    'Free Kicks': (1, 6),
    'Heading': (11, 7),
    'Long Shots': (2, 8),
    'Long Throws': (5, 9),
    'Marking': (14, 10),
    'Passing': (6, 11),
    'Penalty Taking': (2, 12),
    'Tackling': (13, 13),
    'Technique': (7, 14),

    # Mental Attributes
    'Aggression': (15, 15),
    'Anticipation': (14, 16),
    'Bravery': (15, 17),
    'Composure': (11, 18),
    'Concentration': (10, 19),
    'Consistency': (20, 20),  # Hidden
    'Decisions': (13, 19),
    'Determination': (12, 18),
    'Dirtiness': (8, 17),  # Hidden
    'Flair': (6, 16),
    'Important Matches': (7, 15),  # Hidden
    'Leadership': (3, 14),
    'Off The Ball': (5, 13),
    'Positioning': (14, 12),
    'Teamwork': (8, 11),
    'Vision': (10, 10),
    'Work Rate': (9, 9),

    # Physical Attributes
    'Acceleration': (13, 8),
    'Agility': (9, 7),
    'Balance': (9, 6),
    'Injury Proneness': (8, 5),  # Hidden
    'Jumping Reach': (13, 4),
    'Natural Fitness': (10, 3),
    'Pace': (10, 2),
    'Stamina': (9, 1),
    'Strength': (10, 2),

    # Position Familiarity
    'GK Familiarity': (1, 1),
    'DL Familiarity': (1, 4),
    'DC Familiarity': (20, 6),
    'DR Familiarity': (1, 8),
    'WBL Familiarity': (1, 10),
    'WBR Familiarity': (1, 12),
    'DM Familiarity': (16, 14),
    'ML Familiarity': (1, 12),
    'MC Familiarity': (1, 10),
    'MR Familiarity': (1, 8),
    'AML Familiarity': (1, 6),
    'AMC Familiarity': (1, 4),
    'AMR Familiarity': (1, 2),
    'ST Familiarity': (1, 4),

    # Feet
    'Left Foot': (11, 20),
    'Right Foot': (20, 17),

    # Hidden/General
    'Adaptability': (10, 2),
    'Ambition': (10, 4),
    'Controversy': (10, 6),
    'Loyalty': (10, 8),
    'Pressure': (10, 12),
    'Professionalism': (10, 14),
    'Sportsmanship': (10, 16),
    'Temperament': (10, 18),
    'Versatility': (17, 20),
}


def main():
    base = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")

    print("="*80)
    print("FM26 DEFINITIVE ATTRIBUTE MAPPING")
    print("="*80)

    print("\nLoading saves...")
    dec1 = FM26Decompressor(base / "Brixham.fm")
    dec1.load()
    data1 = dec1.decompress_main_database()

    dec4 = FM26Decompressor(base / "Brixham4.fm")
    dec4.load()
    data4 = dec4.decompress_main_database()

    # Find Isaac James Smith
    name = "Isaac James Smith"
    isaac1 = find_string_position(data1, name)
    isaac4 = find_string_position(data4, name)

    print(f"\n{name}")
    print(f"  Brix1: {isaac1:,}")
    print(f"  Brix4: {isaac4:,}")

    # Use the dense attribute region identified earlier
    # The region around name - 4061 to name - 4000 has the highest density
    # Let's scan the entire region from name - 5000 to name for changes

    print("\n" + "="*80)
    print("MAPPING ATTRIBUTES BY MATCHING ORIGINAL AND NEW VALUES")
    print("="*80)

    # Create lookup: (original_internal, new_internal) -> attribute name
    change_lookup = {}
    for attr, (orig, new) in ATTR_CHANGES.items():
        key = (orig * 5, new * 5)
        if key not in change_lookup:
            change_lookup[key] = []
        change_lookup[key].append(attr)

    # Scan region and match changes
    mapped = {}
    ambiguous = {}

    search_start = 3500  # Search from name - 3500 to name - 4500
    search_end = 4500

    for offset in range(search_start, search_end):
        pos1 = isaac1 - offset
        pos4 = isaac4 - offset

        if pos1 < 0 or pos4 < 0:
            continue
        if pos1 >= len(data1) or pos4 >= len(data4):
            continue

        v1 = data1[pos1]
        v4 = data4[pos4]

        if v1 == v4:
            continue  # No change

        key = (v1, v4)
        if key in change_lookup:
            attrs = change_lookup[key]
            relative_offset = -offset  # Negative offset from name

            if len(attrs) == 1:
                mapped[relative_offset] = {
                    'attribute': attrs[0],
                    'original': v1,
                    'new': v4,
                    'scaled_orig': v1 // 5,
                    'scaled_new': v4 // 5,
                }
            else:
                ambiguous[relative_offset] = {
                    'possible': attrs,
                    'original': v1,
                    'new': v4,
                    'scaled_orig': v1 // 5,
                    'scaled_new': v4 // 5,
                }

    print(f"\nUniquely mapped: {len(mapped)} attributes")
    print(f"Ambiguous: {len(ambiguous)} positions")

    # Print unique mappings
    print("\n" + "-"*80)
    print("UNIQUE MAPPINGS (sorted by offset)")
    print("-"*80)
    print(f"{'Offset':>8} | {'Attribute':<25} | {'Orig':>5} | {'New':>5}")
    print("-"*80)

    for offset in sorted(mapped.keys()):
        m = mapped[offset]
        print(f"{offset:>+8} | {m['attribute']:<25} | {m['scaled_orig']:>5} | {m['scaled_new']:>5}")

    # Print ambiguous
    if ambiguous:
        print("\n" + "-"*80)
        print("AMBIGUOUS (need further analysis)")
        print("-"*80)

        for offset in sorted(ambiguous.keys()):
            a = ambiguous[offset]
            print(f"\nOffset {offset:+d}: {a['scaled_orig']} → {a['scaled_new']}")
            for attr in a['possible']:
                orig, new = ATTR_CHANGES[attr]
                print(f"  - {attr} ({orig} → {new})")

    # Now let's check fitness values
    print("\n" + "="*80)
    print("FITNESS VALUES (multi-byte)")
    print("="*80)

    # Expected: Condition 9528→7500, Sharpness 5100→6500, Fatigue -500→55
    # These are likely stored as 2-byte or 4-byte integers

    # Search for these specific values
    print("\nSearching for fitness values in Brix4...")

    for offset in range(3500, 5000):
        pos4 = isaac4 - offset

        if pos4 < 2 or pos4 + 2 >= len(data4):
            continue

        # Check 2-byte value
        val_16 = int.from_bytes(data4[pos4:pos4+2], 'little')

        if val_16 == 7500:
            print(f"  Condition (7500) at offset {-offset:+d}")
        elif val_16 == 6500:
            print(f"  Sharpness (6500) at offset {-offset:+d}")

    # Save the mapping to a JSON file
    print("\n" + "="*80)
    print("SAVING MAPPING TO JSON")
    print("="*80)

    schema = {
        'description': 'FM26 Player Attribute Offsets (relative to player name position)',
        'scale_info': 'Internal values are 0-100, divide by 5 to get in-game 1-20 value',
        'anchor': 'Player name (length-prefixed string)',
        'attributes': {}
    }

    for offset, m in sorted(mapped.items()):
        schema['attributes'][m['attribute']] = {
            'offset': offset,
            'type': 'uint8',
            'scale': 5,
        }

    # Add fitness if found
    schema['fitness'] = {
        'description': '2-byte unsigned integers, search for specific values'
    }

    output_path = Path(__file__).parent / 'mappings' / 'schema_v26.json'
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with open(output_path, 'w') as f:
        json.dump(schema, f, indent=2)

    print(f"\nSaved to: {output_path}")
    print(f"Mapped {len(schema['attributes'])} attributes")


if __name__ == "__main__":
    main()
