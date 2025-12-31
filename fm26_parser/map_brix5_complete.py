#!/usr/bin/env python3
"""
Complete attribute mapping using Brixham5 with unique values per category.

Each attribute category has unique values, allowing definitive mapping.
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


# Brix5 attribute values (internal = in_game * 5)
BRIX5_ATTRS = {
    # Technical (1-14)
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

    # Mental (mixed to avoid conflicts)
    'Aggression': 15,
    'Anticipation': 16,
    'Bravery': 17,
    'Composure': 18,
    'Concentration': 19,
    'Decisions': 1,
    'Determination': 2,
    'Flair': 3,
    'Leadership': 4,
    'Off The Ball': 5,
    'Positioning': 6,
    'Teamwork': 7,
    'Vision': 8,
    'Work Rate': 9,
    'Consistency': 10,
    'Dirtiness': 11,
    'Important Matches': 12,

    # Physical
    'Acceleration': 13,
    'Agility': 14,
    'Balance': 15,
    'Injury Proneness': 16,
    'Jumping Reach': 17,
    'Natural Fitness': 18,
    'Pace': 19,
    'Stamina': 20,
    'Strength': 1,

    # Position Familiarity
    'GK Familiarity': 1,
    'DL Familiarity': 2,
    'DC Familiarity': 3,
    'DR Familiarity': 4,
    'WBL Familiarity': 5,
    'WBR Familiarity': 6,
    'DM Familiarity': 7,
    'ML Familiarity': 8,
    'MC Familiarity': 9,
    'MR Familiarity': 10,
    'AML Familiarity': 11,
    'AMC Familiarity': 12,
    'AMR Familiarity': 13,
    'ST Familiarity': 14,

    # Feet
    'Left Foot': 20,
    'Right Foot': 15,

    # Personality
    'Adaptability': 16,
    'Ambition': 17,
    'Controversy': 18,
    'Loyalty': 19,
    'Pressure': 2,
    'Professionalism': 3,
    'Sportsmanship': 4,
    'Temperament': 5,
    'Versatility': 6,
}

# Group by internal value for matching
VALUE_TO_ATTRS = {}
for attr, val in BRIX5_ATTRS.items():
    internal = val * 5
    if internal not in VALUE_TO_ATTRS:
        VALUE_TO_ATTRS[internal] = []
    VALUE_TO_ATTRS[internal].append(attr)


def main():
    base = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")

    print("="*80)
    print("FM26 COMPLETE ATTRIBUTE MAPPING - BRIXHAM5")
    print("="*80)

    print("\nLoading Brixham5.fm...")
    dec5 = FM26Decompressor(base / "Brixham5.fm")
    dec5.load()
    data5 = dec5.decompress_main_database()

    print(f"Size: {len(data5):,} bytes")

    # Find Isaac James Smith
    name = "Isaac James Smith"
    isaac5 = find_string_position(data5, name)

    if isaac5 == -1:
        print(f"ERROR: Could not find '{name}'")
        return

    print(f"\n{name} at: {isaac5:,}")

    # Scan the attribute region (name - 4200 to name - 3900)
    print("\n" + "="*80)
    print("SCANNING ATTRIBUTE REGION")
    print("="*80)

    # Find all attribute-like values
    attr_positions = []

    for offset in range(3900, 4200):
        pos = isaac5 - offset
        if pos < 0 or pos >= len(data5):
            continue

        val = data5[pos]

        # Check if this is an expected attribute value
        if val in VALUE_TO_ATTRS:
            attrs = VALUE_TO_ATTRS[val]
            attr_positions.append({
                'offset': -offset,
                'value': val,
                'scaled': val // 5,
                'candidates': attrs
            })

    print(f"\nFound {len(attr_positions)} positions with expected values")

    # Now identify unique mappings
    print("\n" + "="*80)
    print("IDENTIFYING ATTRIBUTES")
    print("="*80)

    # Sort by offset (most negative first = furthest from name)
    attr_positions.sort(key=lambda x: x['offset'])

    # Track which attributes we've already mapped
    mapped_attrs = {}
    used_offsets = set()

    # First pass: unique values (only one candidate)
    print("\n--- UNIQUE MAPPINGS (single candidate) ---")
    for ap in attr_positions:
        if len(ap['candidates']) == 1:
            attr = ap['candidates'][0]
            if attr not in mapped_attrs:
                mapped_attrs[attr] = ap['offset']
                used_offsets.add(ap['offset'])
                print(f"  {ap['offset']:>+5}: {attr} = {ap['scaled']}")

    # Second pass: disambiguate by position/context
    print("\n--- MULTI-CANDIDATE POSITIONS ---")
    for ap in attr_positions:
        if len(ap['candidates']) > 1 and ap['offset'] not in used_offsets:
            # Filter out already-mapped attributes
            remaining = [a for a in ap['candidates'] if a not in mapped_attrs]
            if len(remaining) == 1:
                attr = remaining[0]
                mapped_attrs[attr] = ap['offset']
                used_offsets.add(ap['offset'])
                print(f"  {ap['offset']:>+5}: {attr} = {ap['scaled']} (disambiguated)")
            elif len(remaining) > 1:
                print(f"  {ap['offset']:>+5}: {remaining} = {ap['scaled']} (ambiguous)")

    # Check for fitness values
    print("\n" + "="*80)
    print("FITNESS VALUES")
    print("="*80)

    for offset in range(3900, 4100):
        pos = isaac5 - offset
        if pos < 2 or pos + 2 >= len(data5):
            continue

        val_16 = int.from_bytes(data5[pos:pos+2], 'little')

        if val_16 == 8500:
            print(f"  Condition (8500) at offset {-offset:+d}")
        elif val_16 == 7200:
            print(f"  Sharpness (7200) at offset {-offset:+d}")
        elif val_16 == 100:
            # Could be many things, check context
            pass

    # Summary
    print("\n" + "="*80)
    print(f"MAPPING SUMMARY: {len(mapped_attrs)} attributes mapped")
    print("="*80)

    # Group by category
    categories = {
        'Technical': ['Corners', 'Crossing', 'Dribbling', 'Finishing', 'First Touch',
                      'Free Kicks', 'Heading', 'Long Shots', 'Long Throws', 'Marking',
                      'Passing', 'Penalty Taking', 'Tackling', 'Technique'],
        'Mental': ['Aggression', 'Anticipation', 'Bravery', 'Composure', 'Concentration',
                   'Decisions', 'Determination', 'Flair', 'Leadership', 'Off The Ball',
                   'Positioning', 'Teamwork', 'Vision', 'Work Rate'],
        'Mental Hidden': ['Consistency', 'Dirtiness', 'Important Matches'],
        'Physical': ['Acceleration', 'Agility', 'Balance', 'Jumping Reach',
                     'Natural Fitness', 'Pace', 'Stamina', 'Strength'],
        'Physical Hidden': ['Injury Proneness'],
        'Position Familiarity': ['GK Familiarity', 'DL Familiarity', 'DC Familiarity',
                                  'DR Familiarity', 'WBL Familiarity', 'WBR Familiarity',
                                  'DM Familiarity', 'ML Familiarity', 'MC Familiarity',
                                  'MR Familiarity', 'AML Familiarity', 'AMC Familiarity',
                                  'AMR Familiarity', 'ST Familiarity'],
        'Feet': ['Left Foot', 'Right Foot'],
        'Personality': ['Adaptability', 'Ambition', 'Controversy', 'Loyalty',
                        'Pressure', 'Professionalism', 'Sportsmanship', 'Temperament',
                        'Versatility'],
    }

    for cat_name, attrs in categories.items():
        mapped_in_cat = [a for a in attrs if a in mapped_attrs]
        print(f"\n{cat_name}: {len(mapped_in_cat)}/{len(attrs)} mapped")
        for attr in attrs:
            if attr in mapped_attrs:
                print(f"    {mapped_attrs[attr]:>+5}: {attr}")
            else:
                print(f"    ???: {attr} (not found)")

    # Save complete schema
    print("\n" + "="*80)
    print("SAVING COMPLETE SCHEMA")
    print("="*80)

    schema = {
        'version': '26.0',
        'description': 'FM26 Player Attribute Schema - Complete Mapping',
        'methodology': 'Differential analysis with unique values per attribute',
        'anchor': 'Player full name (length-prefixed UTF-8 string)',
        'scale': {
            'internal_range': [0, 100],
            'in_game_range': [1, 20],
            'conversion': 'in_game = internal / 5'
        },
        'attributes': {},
        'fitness': {
            'condition': {'offset': -4008, 'type': 'uint16_le'},
            'sharpness': {'offset': -4012, 'type': 'uint16_le'},
            'fatigue': {'offset': -4010, 'type': 'uint16_le'},
        }
    }

    for attr, offset in sorted(mapped_attrs.items(), key=lambda x: x[1]):
        schema['attributes'][attr] = {
            'offset': offset,
            'type': 'uint8'
        }

    output_path = Path(__file__).parent / 'mappings' / 'schema_v26_complete.json'
    with open(output_path, 'w') as f:
        json.dump(schema, f, indent=2)

    print(f"\nSaved to: {output_path}")


if __name__ == "__main__":
    main()
