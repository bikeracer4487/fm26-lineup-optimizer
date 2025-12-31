#!/usr/bin/env python3
"""
Final attribute mapping using value counting and unique identification.

Strategy:
1. Count occurrences of each internal value in Brix5
2. Compare to expected counts from our Brix5 settings
3. Map unique values first, then use position clustering for ambiguous ones
"""

import sys
from pathlib import Path
import json
from collections import Counter

sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor


def find_string_position(data: bytes, target: str) -> int:
    target_bytes = target.encode('utf-8')
    pattern = len(target_bytes).to_bytes(4, 'little') + target_bytes
    pos = data.find(pattern)
    return pos + 4 if pos != -1 else -1


# Brixham5 settings organized by category
TECHNICAL = [
    ('Corners', 1), ('Crossing', 2), ('Dribbling', 3), ('Finishing', 4),
    ('First Touch', 5), ('Free Kicks', 6), ('Heading', 7), ('Long Shots', 8),
    ('Long Throws', 9), ('Marking', 10), ('Passing', 11), ('Penalty Taking', 12),
    ('Tackling', 13), ('Technique', 14)
]

MENTAL = [
    ('Aggression', 15), ('Anticipation', 16), ('Bravery', 17), ('Composure', 18),
    ('Concentration', 19), ('Decisions', 1), ('Determination', 2), ('Flair', 3),
    ('Leadership', 4), ('Off The Ball', 5), ('Positioning', 6), ('Teamwork', 7),
    ('Vision', 8), ('Work Rate', 9)
]

MENTAL_HIDDEN = [
    ('Consistency', 10), ('Dirtiness', 11), ('Important Matches', 12)
]

PHYSICAL = [
    ('Acceleration', 13), ('Agility', 14), ('Balance', 15), ('Jumping Reach', 17),
    ('Natural Fitness', 18), ('Pace', 19), ('Stamina', 20), ('Strength', 1)
]

PHYSICAL_HIDDEN = [('Injury Proneness', 16)]

POSITION_FAM = [
    ('GK Familiarity', 1), ('DL Familiarity', 2), ('DC Familiarity', 3),
    ('DR Familiarity', 4), ('WBL Familiarity', 5), ('WBR Familiarity', 6),
    ('DM Familiarity', 7), ('ML Familiarity', 8), ('MC Familiarity', 9),
    ('MR Familiarity', 10), ('AML Familiarity', 11), ('AMC Familiarity', 12),
    ('AMR Familiarity', 13), ('ST Familiarity', 14)
]

FEET = [('Left Foot', 20), ('Right Foot', 15)]

PERSONALITY = [
    ('Adaptability', 16), ('Ambition', 17), ('Controversy', 18), ('Loyalty', 19),
    ('Pressure', 2), ('Professionalism', 3), ('Sportsmanship', 4), ('Temperament', 5),
    ('Versatility', 6)
]

ALL_ATTRS = TECHNICAL + MENTAL + MENTAL_HIDDEN + PHYSICAL + PHYSICAL_HIDDEN + POSITION_FAM + FEET + PERSONALITY


def main():
    base = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")

    print("="*80)
    print("FM26 FINAL ATTRIBUTE MAPPING")
    print("="*80)

    dec5 = FM26Decompressor(base / "Brixham5.fm")
    dec5.load()
    data5 = dec5.decompress_main_database()

    name = "Isaac James Smith"
    isaac5 = find_string_position(data5, name)
    print(f"\n{name} at: {isaac5:,}")

    # Count expected occurrences of each internal value
    expected_counts = Counter()
    value_to_attrs = {}
    for attr, ig_val in ALL_ATTRS:
        internal = ig_val * 5
        expected_counts[internal] += 1
        if internal not in value_to_attrs:
            value_to_attrs[internal] = []
        value_to_attrs[internal].append(attr)

    print("\n" + "="*80)
    print("EXPECTED VALUE COUNTS (from Brix5 settings)")
    print("="*80)
    for val in sorted(expected_counts.keys()):
        attrs = value_to_attrs[val]
        print(f"  Internal {val:>3} (in-game {val//5:>2}): expected {expected_counts[val]:>2}x -> {attrs}")

    # Scan for attribute bytes
    print("\n" + "="*80)
    print("SCANNING ATTRIBUTE REGION")
    print("="*80)

    # Find all bytes with valid attribute values
    attr_bytes = []
    for offset in range(4130, 4000, -1):
        pos = isaac5 - offset
        if pos < 0 or pos >= len(data5):
            continue
        val = data5[pos]
        if val >= 5 and val <= 100 and val % 5 == 0:
            attr_bytes.append((-offset, val))

    print(f"\nFound {len(attr_bytes)} attribute-like bytes")

    # Count actual occurrences
    actual_counts = Counter(val for _, val in attr_bytes)

    print("\n" + "="*80)
    print("COMPARING EXPECTED vs ACTUAL COUNTS")
    print("="*80)
    print(f"\n{'Value':>8} {'Expected':>10} {'Actual':>10} {'Match':>8}")
    print("-"*40)

    for val in sorted(set(expected_counts.keys()) | set(actual_counts.keys())):
        exp = expected_counts.get(val, 0)
        act = actual_counts.get(val, 0)
        match = "✓" if exp == act else "✗" if exp > 0 else "-"
        print(f"{val:>8} {exp:>10} {act:>10} {match:>8}")

    # Now map unique values (where count matches and is 1)
    print("\n" + "="*80)
    print("UNIQUE MAPPINGS (single occurrence matches)")
    print("="*80)

    mapped = {}

    for val in sorted(value_to_attrs.keys()):
        exp = expected_counts[val]
        act = actual_counts.get(val, 0)
        attrs = value_to_attrs[val]

        # Find positions with this value
        positions = [off for off, v in attr_bytes if v == val]

        if len(attrs) == 1 and len(positions) == 1:
            # Perfect unique match
            attr = attrs[0]
            offset = positions[0]
            mapped[attr] = offset
            print(f"  {offset:>+5}: {attr} = {val//5}")

    print(f"\nMapped {len(mapped)} unique attributes")

    # Now handle ambiguous cases by position clustering
    print("\n" + "="*80)
    print("AMBIGUOUS MAPPINGS (using position clustering)")
    print("="*80)

    # Group remaining positions by value
    remaining = {}
    for off, val in attr_bytes:
        if off not in mapped.values():
            if val not in remaining:
                remaining[val] = []
            remaining[val].append(off)

    # Define approximate regions based on what we've seen
    # Physical seems to be around -4066 to -4050
    # Technical/Position around -4105 to -4070
    # Personality around -4120 to -4105

    print("\n  Attempting to disambiguate by region...")

    # We know Sportsmanship = -4115 (confirmed)
    if 'Sportsmanship' not in mapped:
        mapped['Sportsmanship'] = -4115
        print(f"  CONFIRMED: -4115 = Sportsmanship")

    # Physical attributes likely in region -4066 to -4050
    # Values we expect: 65(Acc), 70(Agi), 75(Bal), 80(IP), 85(JR), 90(NF), 95(Pace), 100(Sta), 5(Str)
    phys_region = [ab for ab in attr_bytes if -4070 <= ab[0] <= -4050]
    print(f"\n  Physical region (-4070 to -4050): {len(phys_region)} bytes")

    for off, val in sorted(phys_region, key=lambda x: x[0], reverse=True):
        # Match to physical attributes
        ig_val = val // 5
        for attr, expected_val in PHYSICAL + PHYSICAL_HIDDEN:
            if expected_val == ig_val and attr not in mapped:
                # Check if this value appears only once in physical region
                count_in_region = sum(1 for o, v in phys_region if v == val)
                if count_in_region == 1:
                    mapped[attr] = off
                    print(f"    {off:>+5}: {attr} = {ig_val}")
                break

    # Position familiarity - should be 14 consecutive values 1-14
    # Look for a cluster with exactly these values
    print("\n  Looking for Position Familiarity cluster (14 values 1-14)...")

    # The technical range 1-14 and position familiarity range 1-14 overlap
    # We need to find TWO separate clusters

    # Cluster 1: around -4105 to -4095 (Technical)
    tech_region = [ab for ab in attr_bytes if -4110 <= ab[0] <= -4090]
    print(f"  Technical region (-4110 to -4090): {len(tech_region)} bytes")

    # Map technical by their values in this region
    for off, val in sorted(tech_region, key=lambda x: x[0], reverse=True):
        ig_val = val // 5
        for attr, expected_val in TECHNICAL:
            if expected_val == ig_val and attr not in mapped:
                count_in_region = sum(1 for o, v in tech_region if v == val)
                # Only map if unique in region OR if we have exact expected count
                if count_in_region == 1:
                    mapped[attr] = off
                    print(f"    {off:>+5}: {attr} = {ig_val}")
                break

    # Final summary
    print("\n" + "="*80)
    print(f"FINAL MAPPING: {len(mapped)} attributes")
    print("="*80)

    categories = [
        ('Technical', TECHNICAL),
        ('Mental', MENTAL),
        ('Mental Hidden', MENTAL_HIDDEN),
        ('Physical', PHYSICAL),
        ('Physical Hidden', PHYSICAL_HIDDEN),
        ('Position Familiarity', POSITION_FAM),
        ('Feet', FEET),
        ('Personality', PERSONALITY),
    ]

    for cat_name, attrs in categories:
        mapped_in_cat = [a for a, v in attrs if a in mapped]
        print(f"\n{cat_name}: {len(mapped_in_cat)}/{len(attrs)}")
        for attr, val in attrs:
            if attr in mapped:
                print(f"    {mapped[attr]:>+5}: {attr} = {val}")
            else:
                print(f"    ???: {attr} = {val}")

    # Save complete schema
    schema = {
        'version': '26.0',
        'description': 'FM26 Player Attribute Schema - Final Mapping',
        'anchor': 'Player full name (length-prefixed UTF-8)',
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

    for attr, offset in sorted(mapped.items(), key=lambda x: x[1]):
        schema['attributes'][attr] = {'offset': offset, 'type': 'uint8'}

    output_path = Path(__file__).parent / 'mappings' / 'schema_v26_complete.json'
    with open(output_path, 'w') as f:
        json.dump(schema, f, indent=2)

    print(f"\nSaved {len(mapped)} attributes to: {output_path}")

    # Show what's still missing
    print("\n" + "="*80)
    print("NEXT STEPS FOR REMAINING ATTRIBUTES")
    print("="*80)

    unmapped = [a for a, v in ALL_ATTRS if a not in mapped]
    print(f"\n{len(unmapped)} attributes still need mapping:")
    for attr in unmapped[:10]:
        print(f"  - {attr}")
    if len(unmapped) > 10:
        print(f"  ... and {len(unmapped) - 10} more")

    print("\nTo complete mapping, we need another test with COMPLETELY unique values.")
    print("Each attribute should have a value that no other attribute shares.")


if __name__ == "__main__":
    main()
