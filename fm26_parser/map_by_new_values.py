#!/usr/bin/env python3
"""
Map attributes by NEW values only (ignoring original values).

Since we know exactly what values were set in Brixham5, we can find
bytes with those new internal values and map them to attributes.
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


# What we SET each attribute to in Brixham5 (in-game values)
BRIX5_VALUES = {
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

    # Mental (15-19, then 1-12)
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

    # Physical (13-20, then 1)
    'Acceleration': 13,
    'Agility': 14,
    'Balance': 15,
    'Injury Proneness': 16,
    'Jumping Reach': 17,
    'Natural Fitness': 18,
    'Pace': 19,
    'Stamina': 20,
    'Strength': 1,

    # Position Familiarity (1-14)
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

    # Personality (16-19, then 2-6)
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

# Category definitions
CATEGORIES = {
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


def main():
    base = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")

    print("="*80)
    print("FM26 ATTRIBUTE MAPPING BY NEW VALUES")
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

    # Find Isaac James Smith in both
    name = "Isaac James Smith"
    isaac1 = find_string_position(data1, name)
    isaac5 = find_string_position(data5, name)

    print(f"\n{name}")
    print(f"  Brix1: {isaac1:,}")
    print(f"  Brix5: {isaac5:,}")
    print(f"  Shift: {isaac5 - isaac1:+d} bytes")

    # Build lookup: internal value -> list of attributes
    NEW_VALUE_TO_ATTRS = {}
    for attr, ig_val in BRIX5_VALUES.items():
        internal = ig_val * 5
        if internal not in NEW_VALUE_TO_ATTRS:
            NEW_VALUE_TO_ATTRS[internal] = []
        NEW_VALUE_TO_ATTRS[internal].append(attr)

    # Find all bytes in Brix5 that changed AND have expected new values
    print("\n" + "="*80)
    print("SCANNING FOR CHANGED BYTES WITH EXPECTED NEW VALUES")
    print("="*80)

    changes = []
    for offset in range(3800, 4300):
        pos5 = isaac5 - offset
        pos1 = isaac1 - offset

        if pos5 < 0 or pos5 >= len(data5):
            continue
        if pos1 < 0 or pos1 >= len(data1):
            continue

        new_val = data5[pos5]
        old_val = data1[pos1]

        # Only include if value changed AND matches expected new value
        if old_val != new_val and new_val in NEW_VALUE_TO_ATTRS:
            changes.append({
                'offset': -offset,
                'old': old_val,
                'new': new_val,
                'old_ig': old_val / 5,
                'new_ig': new_val / 5,
                'candidates': NEW_VALUE_TO_ATTRS[new_val].copy()
            })

    print(f"\nFound {len(changes)} positions with expected new values that changed")

    # Sort by offset (most negative first)
    changes.sort(key=lambda x: x['offset'])

    # Show all changes grouped by new value
    print("\n" + "-"*80)
    print("ALL CHANGES (grouped by new internal value)")
    print("-"*80)

    by_new_val = {}
    for c in changes:
        nv = c['new']
        if nv not in by_new_val:
            by_new_val[nv] = []
        by_new_val[nv].append(c)

    for nv in sorted(by_new_val.keys()):
        items = by_new_val[nv]
        attrs = NEW_VALUE_TO_ATTRS[nv]
        print(f"\nInternal {nv} (in-game {nv//5}) -> {attrs}")
        for c in items:
            print(f"    {c['offset']:>+5}: was {c['old']:>3} ({c['old_ig']:>5.1f})")

    # Now identify sequences
    print("\n" + "="*80)
    print("IDENTIFYING ATTRIBUTE SEQUENCES")
    print("="*80)

    # Technical should be consecutive bytes with values 5,10,15,...,70
    # Let's find runs of 14 consecutive-ish bytes
    print("\nLooking for Technical sequence (14 consecutive attrs, values 5-70)...")

    # Get all offsets with technical-range values (5-70)
    tech_changes = [c for c in changes if 5 <= c['new'] <= 70]
    tech_changes.sort(key=lambda x: x['offset'])

    print(f"Found {len(tech_changes)} changes in technical range (5-70):")
    for c in tech_changes:
        # Filter candidates to technical only
        tech_cands = [a for a in c['candidates'] if a in CATEGORIES['Technical']]
        print(f"  {c['offset']:>+5}: new={c['new']:>2} ({c['new_ig']:>2.0f}) -> {tech_cands}")

    # Find the best consecutive run
    if len(tech_changes) >= 14:
        # Look for 14 bytes that form a sequence
        best_run = None
        best_score = 0

        for start_idx in range(len(tech_changes) - 13):
            run = tech_changes[start_idx:start_idx + 14]
            span = run[-1]['offset'] - run[0]['offset']

            # Check if we have all values 5,10,15...70
            new_values = set(c['new'] for c in run)
            expected_values = set(range(5, 75, 5))

            score = len(new_values & expected_values) - abs(span) / 20

            if score > best_score:
                best_score = score
                best_run = run

        if best_run:
            print(f"\nBest Technical run (span: {best_run[-1]['offset'] - best_run[0]['offset']}):")
            for c in best_run:
                ig_val = c['new'] // 5
                # Find technical attr with this value
                tech_attr = None
                for attr in CATEGORIES['Technical']:
                    if BRIX5_VALUES[attr] == ig_val:
                        tech_attr = attr
                        break
                print(f"  {c['offset']:>+5}: {c['new']:>2} -> {tech_attr}")

    # Position familiarity should also be 14 consecutive with values 5-70
    print("\n\nLooking for Position Familiarity sequence (14 positions, values 5-70)...")

    # These have the same value range as technical, so we need to find a SECOND run
    # Position familiarity is likely further from the name than technical

    mapped = {}

    # Map technical first (closer to name based on earlier findings)
    # Technical attrs seemed to be around -4072 to -4085
    print("\n" + "="*80)
    print("MAPPING BY OFFSET CLUSTERING")
    print("="*80)

    # Group changes into clusters
    print("\nAll changes by offset range:")
    print("-"*60)

    ranges = [
        (-4090, -4070, "Range A (likely Technical)"),
        (-4070, -4050, "Range B (likely Mental/Physical)"),
        (-4050, -4030, "Range C"),
        (-4030, -4010, "Range D"),
        (-4130, -4090, "Range E (further out)"),
    ]

    for start, end, label in ranges:
        in_range = [c for c in changes if start <= c['offset'] <= end]
        if in_range:
            print(f"\n{label}:")
            for c in in_range:
                print(f"  {c['offset']:>+5}: {c['new']:>3} ({c['new_ig']:>5.1f}) -> {c['candidates'][:3]}")

    # Try a simpler approach: map by finding the unique Technical sequence first
    print("\n" + "="*80)
    print("MAPPING TECHNICAL BY VALUE ORDER")
    print("="*80)

    # Find all positions with each expected technical value
    tech_mapping = {}
    for attr in CATEGORIES['Technical']:
        ig_val = BRIX5_VALUES[attr]
        internal = ig_val * 5

        # Find changes with this new value
        candidates = [c for c in changes if c['new'] == internal]

        if len(candidates) == 1:
            # Unique - definitely this attribute
            tech_mapping[attr] = candidates[0]['offset']
            print(f"UNIQUE: {attr} = {ig_val} at {candidates[0]['offset']}")
        elif len(candidates) > 1:
            # Ambiguous - need to pick one
            # Technical attrs likely to be in -4070 to -4090 range
            tech_likely = [c for c in candidates if -4090 <= c['offset'] <= -4065]
            if len(tech_likely) == 1:
                tech_mapping[attr] = tech_likely[0]['offset']
                print(f"LIKELY: {attr} = {ig_val} at {tech_likely[0]['offset']}")
            else:
                print(f"AMBIG:  {attr} = {ig_val} at {[c['offset'] for c in candidates]}")

    # Physical attributes
    print("\n" + "="*80)
    print("MAPPING PHYSICAL BY VALUE")
    print("="*80)

    phys_mapping = {}
    all_phys = CATEGORIES['Physical'] + CATEGORIES['Physical Hidden']

    for attr in all_phys:
        ig_val = BRIX5_VALUES[attr]
        internal = ig_val * 5

        # Find changes with this new value that aren't already mapped
        candidates = [c for c in changes if c['new'] == internal
                      and c['offset'] not in tech_mapping.values()]

        if len(candidates) == 1:
            phys_mapping[attr] = candidates[0]['offset']
            print(f"UNIQUE: {attr} = {ig_val} at {candidates[0]['offset']}")
        elif len(candidates) > 1:
            # Physical likely around -4050 to -4070 or so
            print(f"AMBIG:  {attr} = {ig_val} at {[c['offset'] for c in candidates]}")

    # Combine all mappings
    mapped.update(tech_mapping)
    mapped.update(phys_mapping)

    # Summary
    print("\n" + "="*80)
    print(f"FINAL MAPPING: {len(mapped)} attributes")
    print("="*80)

    for cat_name, attrs in CATEGORIES.items():
        mapped_in_cat = [a for a in attrs if a in mapped]
        print(f"\n{cat_name}: {len(mapped_in_cat)}/{len(attrs)}")
        for attr in sorted(attrs, key=lambda a: mapped.get(a, 0)):
            if attr in mapped:
                print(f"    {mapped[attr]:>+5}: {attr}")
            else:
                print(f"    ???: {attr}")

    # Save schema
    schema = {
        'version': '26.0',
        'description': 'FM26 Player Attribute Schema - Mapped via Brix5 new values',
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
        json.dump(schema, f, indent=2)

    print(f"\nSaved to: {output_path}")


if __name__ == "__main__":
    main()
