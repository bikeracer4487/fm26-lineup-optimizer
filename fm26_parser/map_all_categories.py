#!/usr/bin/env python3
"""
Complete attribute mapping using Brixham6-10 (category-isolated saves).

Each save changes only ONE category, making mapping definitive.
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


# Changes made in each save (original -> new)
BRIX6_TECHNICAL = {
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
    'Tackling': (13, 14),  # Note: user swapped these
    'Technique': (7, 13),  # Note: user swapped these
}

BRIX7_MENTAL = {
    'Aggression': (15, 1),
    'Anticipation': (14, 2),
    'Bravery': (15, 3),
    'Composure': (11, 4),
    'Concentration': (10, 5),
    'Consistency': (20, 6),  # Hidden mental
    'Decisions': (13, 7),
    'Determination': (12, 8),
    'Dirtiness': (8, 9),  # Hidden mental
    'Flair': (6, 10),
    'Important Matches': (7, 11),  # Hidden mental
    'Leadership': (3, 12),
    'Off The Ball': (5, 13),
    'Positioning': (14, 15),
    'Teamwork': (8, 14),
    'Vision': (10, 16),
    'Work Rate': (9, 17),
}

BRIX8_PHYSICAL = {
    'Acceleration': (13, 1),
    'Agility': (9, 2),
    'Balance': (9, 3),
    'Injury Proneness': (8, 4),  # Hidden physical
    'Jumping Reach': (13, 5),
    'Natural Fitness': (10, 6),
    'Pace': (10, 7),
    'Stamina': (9, 8),
    'Strength': (10, 9),
}

BRIX9_POSITION = {
    'GK Familiarity': (1, 1),  # No change
    'DL Familiarity': (1, 2),
    'DC Familiarity': (20, 3),
    'DR Familiarity': (1, 4),
    'WBL Familiarity': (1, 5),
    'WBR Familiarity': (1, 6),
    'DM Familiarity': (16, 7),
    'ML Familiarity': (1, 8),
    'MC Familiarity': (1, 9),
    'MR Familiarity': (1, 10),
    'AML Familiarity': (1, 11),
    'AMC Familiarity': (1, 12),
    'AMR Familiarity': (1, 13),
    'ST Familiarity': (1, 14),
}

BRIX10_OTHER = {
    'Left Foot': (11, 20),
    'Right Foot': (20, 19),
    'Adaptability': (10, 1),
    'Ambition': (10, 2),
    'Controversy': (10, 3),
    'Loyalty': (10, 4),
    'Pressure': (10, 5),
    'Professionalism': (10, 6),
    'Sportsmanship': (10, 7),
    'Temperament': (10, 8),
    'Versatility': (17, 9),
}

# Fitness changes in Brix10
BRIX10_FITNESS = {
    'Condition': (9528, 7100),
    'Sharpness': (5100, 6400),
    'Fatigue': (-500, 35),
}


def analyze_save(base_data, base_pos, mod_data, mod_pos, changes, category_name):
    """Analyze a modified save against base to find attribute offsets."""
    print(f"\n{'='*80}")
    print(f"ANALYZING {category_name}")
    print(f"{'='*80}")

    # Build lookup: (old_internal, new_internal) -> attribute
    change_lookup = {}
    for attr, (old_ig, new_ig) in changes.items():
        old_int = old_ig * 5
        new_int = new_ig * 5
        if old_int != new_int:
            key = (old_int, new_int)
            if key not in change_lookup:
                change_lookup[key] = []
            change_lookup[key].append(attr)

    # Scan for changes
    mapped = {}
    unmapped_changes = []

    for offset in range(3800, 4300):
        pos_base = base_pos - offset
        pos_mod = mod_pos - offset

        if pos_base < 0 or pos_mod < 0:
            continue
        if pos_base >= len(base_data) or pos_mod >= len(mod_data):
            continue

        old_val = base_data[pos_base]
        new_val = mod_data[pos_mod]

        if old_val != new_val:
            key = (old_val, new_val)
            attrs = change_lookup.get(key, [])

            if len(attrs) == 1:
                attr = attrs[0]
                if attr not in mapped:
                    mapped[attr] = -offset
                    print(f"  {-offset:>+5}: {attr} ({old_val//5} -> {new_val//5})")
            elif len(attrs) > 1:
                unmapped_changes.append({
                    'offset': -offset,
                    'old': old_val,
                    'new': new_val,
                    'candidates': attrs
                })
            else:
                # No matching attribute - could be side effect or unrelated
                pass

    # Second pass: disambiguate
    for c in unmapped_changes:
        remaining = [a for a in c['candidates'] if a not in mapped]
        if len(remaining) == 1:
            attr = remaining[0]
            mapped[attr] = c['offset']
            print(f"  {c['offset']:>+5}: {attr} ({c['old']//5} -> {c['new']//5}) [disambiguated]")

    # Report unmapped
    all_attrs = set(changes.keys())
    found_attrs = set(mapped.keys())
    unchanged = {a for a, (old, new) in changes.items() if old == new}
    missing = all_attrs - found_attrs - unchanged

    print(f"\n  Mapped: {len(mapped)}/{len(all_attrs)}")
    if unchanged:
        print(f"  Unchanged (no diff possible): {list(unchanged)}")
    if missing:
        print(f"  Missing: {list(missing)}")

    return mapped


def analyze_fitness(base_data, base_pos, mod_data, mod_pos, fitness_changes):
    """Analyze fitness value changes (16-bit values)."""
    print(f"\n{'='*80}")
    print("ANALYZING FITNESS VALUES")
    print(f"{'='*80}")

    mapped = {}

    for offset in range(4000, 4050):
        pos_base = base_pos - offset
        pos_mod = mod_pos - offset

        if pos_base < 2 or pos_mod < 2:
            continue

        # Read as 16-bit little-endian
        old_16 = int.from_bytes(base_data[pos_base:pos_base+2], 'little', signed=True)
        new_16 = int.from_bytes(mod_data[pos_mod:pos_mod+2], 'little', signed=True)

        if old_16 != new_16:
            # Check against expected changes
            for name, (old_exp, new_exp) in fitness_changes.items():
                if old_16 == old_exp and new_16 == new_exp:
                    mapped[name] = -offset
                    print(f"  {-offset:>+5}: {name} ({old_16} -> {new_16})")
                    break

    return mapped


def main():
    base = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")
    name = "Isaac James Smith"

    print("="*80)
    print("FM26 COMPLETE ATTRIBUTE MAPPING")
    print("="*80)

    # Load all saves
    print("\nLoading saves...")

    saves = {}
    for n in ['Brixham.fm', 'Brixham6.fm', 'Brixham7.fm', 'Brixham8.fm', 'Brixham9.fm', 'Brixham10.fm']:
        dec = FM26Decompressor(base / n)
        dec.load()
        data = dec.decompress_main_database()
        pos = find_string_position(data, name)
        saves[n] = {'data': data, 'pos': pos}
        print(f"  {n}: size={len(data):,}, Isaac at {pos:,}")

    base_data = saves['Brixham.fm']['data']
    base_pos = saves['Brixham.fm']['pos']

    # Analyze each category
    all_mapped = {}

    # Technical (Brixham6)
    mapped = analyze_save(
        base_data, base_pos,
        saves['Brixham6.fm']['data'], saves['Brixham6.fm']['pos'],
        BRIX6_TECHNICAL, "TECHNICAL"
    )
    all_mapped.update(mapped)

    # Mental (Brixham7)
    mapped = analyze_save(
        base_data, base_pos,
        saves['Brixham7.fm']['data'], saves['Brixham7.fm']['pos'],
        BRIX7_MENTAL, "MENTAL"
    )
    all_mapped.update(mapped)

    # Physical (Brixham8)
    mapped = analyze_save(
        base_data, base_pos,
        saves['Brixham8.fm']['data'], saves['Brixham8.fm']['pos'],
        BRIX8_PHYSICAL, "PHYSICAL"
    )
    all_mapped.update(mapped)

    # Position Familiarity (Brixham9)
    mapped = analyze_save(
        base_data, base_pos,
        saves['Brixham9.fm']['data'], saves['Brixham9.fm']['pos'],
        BRIX9_POSITION, "POSITION FAMILIARITY"
    )
    all_mapped.update(mapped)

    # Other (Brixham10)
    mapped = analyze_save(
        base_data, base_pos,
        saves['Brixham10.fm']['data'], saves['Brixham10.fm']['pos'],
        BRIX10_OTHER, "FEET & PERSONALITY"
    )
    all_mapped.update(mapped)

    # Fitness (Brixham10)
    fitness_mapped = analyze_fitness(
        base_data, base_pos,
        saves['Brixham10.fm']['data'], saves['Brixham10.fm']['pos'],
        BRIX10_FITNESS
    )

    # Summary
    print("\n" + "="*80)
    print(f"COMPLETE MAPPING: {len(all_mapped)} attributes")
    print("="*80)

    # Group by category for display
    categories = {
        'Technical': list(BRIX6_TECHNICAL.keys()),
        'Mental': list(BRIX7_MENTAL.keys()),
        'Physical': list(BRIX8_PHYSICAL.keys()),
        'Position Familiarity': list(BRIX9_POSITION.keys()),
        'Feet & Personality': list(BRIX10_OTHER.keys()),
    }

    for cat_name, attrs in categories.items():
        mapped_in_cat = [a for a in attrs if a in all_mapped]
        print(f"\n{cat_name}: {len(mapped_in_cat)}/{len(attrs)}")
        for attr in sorted(attrs, key=lambda a: all_mapped.get(a, 0)):
            if attr in all_mapped:
                print(f"    {all_mapped[attr]:>+5}: {attr}")
            else:
                print(f"    ???: {attr}")

    print(f"\nFitness: {len(fitness_mapped)}/3")
    for name, offset in sorted(fitness_mapped.items(), key=lambda x: x[1]):
        print(f"    {offset:>+5}: {name}")

    # Save complete schema
    schema = {
        'version': '26.0',
        'description': 'FM26 Player Attribute Schema - Complete Mapping',
        'methodology': 'Category-isolated differential analysis (Brixham6-10)',
        'anchor': 'Player full name (length-prefixed UTF-8 string)',
        'scale': {
            'internal_range': [0, 100],
            'in_game_range': [1, 20],
            'conversion': 'in_game = internal / 5'
        },
        'fitness': {},
        'attributes': {}
    }

    for name, offset in fitness_mapped.items():
        schema['fitness'][name.lower()] = {'offset': offset, 'type': 'int16_le'}

    for attr, offset in sorted(all_mapped.items(), key=lambda x: x[1]):
        schema['attributes'][attr] = {'offset': offset, 'type': 'uint8'}

    output_path = Path(__file__).parent / 'mappings' / 'schema_v26_complete.json'
    with open(output_path, 'w') as f:
        json.dump(schema, f, indent=2)

    print(f"\n{'='*80}")
    print(f"Saved complete schema to: {output_path}")
    print(f"Total: {len(all_mapped)} attributes + {len(fitness_mapped)} fitness values")
    print(f"{'='*80}")


if __name__ == "__main__":
    main()
