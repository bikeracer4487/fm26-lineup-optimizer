#!/usr/bin/env python3
"""
Compare Brixham.fm (original) to Brixham5.fm to map attributes by actual changes.

For each changed byte, we know:
- Original value (from Brix1)
- New value (from Brix5)
- What attribute that change represents
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


# Isaac's ORIGINAL values and what we changed them to
# Format: (original_ingame, new_ingame)
ATTR_CHANGES = {
    # Technical
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
    'Tackling': (13, 13),  # No change
    'Technique': (7, 14),

    # Mental
    'Aggression': (15, 15),  # No change
    'Anticipation': (14, 16),
    'Bravery': (15, 17),
    'Composure': (11, 18),
    'Concentration': (10, 19),
    'Decisions': (13, 1),
    'Determination': (12, 2),
    'Flair': (6, 3),
    'Leadership': (3, 4),
    'Off The Ball': (5, 5),  # No change
    'Positioning': (14, 6),
    'Teamwork': (8, 7),
    'Vision': (10, 8),
    'Work Rate': (9, 9),  # No change
    'Consistency': (20, 10),
    'Dirtiness': (8, 11),
    'Important Matches': (7, 12),

    # Physical
    'Acceleration': (13, 13),  # No change
    'Agility': (9, 14),
    'Balance': (9, 15),
    'Injury Proneness': (8, 16),
    'Jumping Reach': (13, 17),
    'Natural Fitness': (10, 18),
    'Pace': (10, 19),
    'Stamina': (9, 20),
    'Strength': (10, 1),

    # Position Familiarity
    'GK Familiarity': (1, 1),  # No change (constrained)
    'DL Familiarity': (1, 2),
    'DC Familiarity': (20, 3),
    'DR Familiarity': (1, 4),
    'WBL Familiarity': (1, 5),
    'WBR Familiarity': (1, 6),
    'DM Familiarity': (16, 7),
    'ML Familiarity': (1, 8),
    'MC Familiarity': (1, 9),
    'MR Familiarity': (1, 10),
    'AML Familiarity': (1, 6),
    'AMC Familiarity': (1, 12),
    'AMR Familiarity': (1, 13),
    'ST Familiarity': (1, 14),

    # Feet
    'Left Foot': (11, 20),
    'Right Foot': (20, 15),

    # Personality
    'Adaptability': (10, 16),
    'Ambition': (10, 17),
    'Controversy': (10, 18),
    'Loyalty': (10, 19),
    'Pressure': (10, 2),
    'Professionalism': (10, 3),
    'Sportsmanship': (10, 4),
    'Temperament': (10, 5),
    'Versatility': (17, 6),
}

# Create lookup by (old_internal, new_internal) -> attribute name
CHANGE_LOOKUP = {}
for attr, (old_ig, new_ig) in ATTR_CHANGES.items():
    old_int = old_ig * 5
    new_int = new_ig * 5
    if old_int != new_int:  # Only track actual changes
        key = (old_int, new_int)
        if key not in CHANGE_LOOKUP:
            CHANGE_LOOKUP[key] = []
        CHANGE_LOOKUP[key].append(attr)


def main():
    base = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")

    print("="*80)
    print("FM26 ATTRIBUTE MAPPING BY DIFFERENTIAL ANALYSIS")
    print("="*80)

    print("\nLoading saves...")
    dec1 = FM26Decompressor(base / "Brixham.fm")
    dec1.load()
    data1 = dec1.decompress_main_database()

    dec5 = FM26Decompressor(base / "Brixham5.fm")
    dec5.load()
    data5 = dec5.decompress_main_database()

    print(f"Brix1 size: {len(data1):,}")
    print(f"Brix5 size: {len(data5):,}")
    print(f"Difference: {len(data5) - len(data1):+d} bytes")

    # Find Isaac James Smith in both
    name = "Isaac James Smith"
    isaac1 = find_string_position(data1, name)
    isaac5 = find_string_position(data5, name)

    print(f"\n{name}")
    print(f"  Brix1: {isaac1:,}")
    print(f"  Brix5: {isaac5:,}")
    print(f"  Shift: {isaac5 - isaac1:+d} bytes")

    # Scan the attribute region and compare
    print("\n" + "="*80)
    print("COMPARING ATTRIBUTE REGIONS")
    print("="*80)

    # Find all changes in the attribute region
    changes = []

    for offset in range(3800, 4300):
        pos1 = isaac1 - offset
        pos5 = isaac5 - offset

        if pos1 < 0 or pos5 < 0:
            continue
        if pos1 >= len(data1) or pos5 >= len(data5):
            continue

        v1 = data1[pos1]
        v5 = data5[pos5]

        if v1 != v5:
            key = (v1, v5)
            attrs = CHANGE_LOOKUP.get(key, [])

            changes.append({
                'offset': -offset,
                'old': v1,
                'new': v5,
                'old_scaled': v1 // 5 if v1 % 5 == 0 else v1 / 5,
                'new_scaled': v5 // 5 if v5 % 5 == 0 else v5 / 5,
                'candidates': attrs
            })

    print(f"\nFound {len(changes)} changed bytes in attribute region")

    # First, handle unique mappings
    mapped = {}
    remaining_changes = []

    print("\n--- UNIQUE MAPPINGS (single candidate) ---")
    for c in changes:
        if len(c['candidates']) == 1:
            attr = c['candidates'][0]
            if attr not in mapped:
                mapped[attr] = c['offset']
                print(f"  {c['offset']:>+5}: {attr} ({c['old_scaled']} -> {c['new_scaled']})")
        else:
            remaining_changes.append(c)

    # Second pass: eliminate already-mapped attributes
    print("\n--- DISAMBIGUATED MAPPINGS ---")
    for c in remaining_changes:
        remaining_attrs = [a for a in c['candidates'] if a not in mapped]
        if len(remaining_attrs) == 1:
            attr = remaining_attrs[0]
            mapped[attr] = c['offset']
            print(f"  {c['offset']:>+5}: {attr} ({c['old_scaled']} -> {c['new_scaled']})")
        elif len(remaining_attrs) == 0:
            pass  # All candidates already mapped
        else:
            print(f"  {c['offset']:>+5}: {remaining_attrs} ({c['old_scaled']} -> {c['new_scaled']}) [AMBIGUOUS]")

    # Check for unmapped changes
    print("\n--- UNMAPPED CHANGES (no matching attribute) ---")
    for c in changes:
        if not c['candidates']:
            print(f"  {c['offset']:>+5}: {c['old']} -> {c['new']} ({c['old_scaled']} -> {c['new_scaled']})")

    # Fitness check
    print("\n" + "="*80)
    print("FITNESS VALUES (2-byte)")
    print("="*80)

    for offset in range(3800, 4200):
        pos5 = isaac5 - offset

        if pos5 < 2 or pos5 + 2 >= len(data5):
            continue

        val_16 = int.from_bytes(data5[pos5:pos5+2], 'little')

        if val_16 == 8500:
            print(f"  Condition (8500) at offset {-offset:+d}")
        elif val_16 == 7200:
            print(f"  Sharpness (7200) at offset {-offset:+d}")
        elif val_16 == 100:
            # Check if this is Fatigue
            pos1 = isaac1 - offset
            if pos1 >= 0 and pos1 + 1 < len(data1):
                old_16 = int.from_bytes(data1[pos1:pos1+2], 'little')
                # Original fatigue was around -500, might be stored differently
                pass

    # Summary
    print("\n" + "="*80)
    print(f"MAPPING SUMMARY: {len(mapped)} attributes mapped")
    print("="*80)

    # Sort by offset
    for attr in sorted(mapped.keys(), key=lambda a: mapped[a]):
        print(f"  {mapped[attr]:>+5}: {attr}")

    # Save complete schema
    schema = {
        'version': '26.0',
        'description': 'FM26 Player Attribute Schema - Mapped via Brix1->Brix5 diff',
        'anchor': 'Player full name (length-prefixed UTF-8)',
        'scale': {
            'internal_range': [0, 100],
            'in_game_range': [1, 20],
            'conversion': 'in_game = internal / 5'
        },
        'attributes': {},
        'fitness': {
            'condition': {'offset': -4032, 'type': 'uint16_le'},
            'sharpness': {'offset': -4036, 'type': 'uint16_le'},
        }
    }

    for attr, offset in sorted(mapped.items(), key=lambda x: x[1]):
        schema['attributes'][attr] = {'offset': offset, 'type': 'uint8'}

    output_path = Path(__file__).parent / 'mappings' / 'schema_v26_complete.json'
    with open(output_path, 'w') as f:
        json.dump(schema, f, indent=2, sort_keys=False)

    print(f"\nSaved to: {output_path}")

    # List unmapped attributes
    all_attrs = set(ATTR_CHANGES.keys())
    unmapped = all_attrs - set(mapped.keys())
    unchanged = {a for a, (old, new) in ATTR_CHANGES.items() if old == new}

    print(f"\nUnmapped (unchanged): {len(unchanged)}")
    for a in sorted(unchanged):
        print(f"  - {a}")

    still_missing = unmapped - unchanged
    print(f"\nStill missing (should have changed): {len(still_missing)}")
    for a in sorted(still_missing):
        old, new = ATTR_CHANGES[a]
        print(f"  - {a} ({old} -> {new})")


if __name__ == "__main__":
    main()
