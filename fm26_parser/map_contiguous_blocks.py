#!/usr/bin/env python3
"""
Map attributes by finding contiguous blocks.

Key insight: Attributes are stored in contiguous blocks.
When original = new value, there's no change, creating gaps.
We can identify blocks by looking at spacing patterns.
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


# Brixham5 values (in-game)
BRIX5_VALUES = {
    'Corners': 1, 'Crossing': 2, 'Dribbling': 3, 'Finishing': 4, 'First Touch': 5,
    'Free Kicks': 6, 'Heading': 7, 'Long Shots': 8, 'Long Throws': 9, 'Marking': 10,
    'Passing': 11, 'Penalty Taking': 12, 'Tackling': 13, 'Technique': 14,
    'Aggression': 15, 'Anticipation': 16, 'Bravery': 17, 'Composure': 18, 'Concentration': 19,
    'Decisions': 1, 'Determination': 2, 'Flair': 3, 'Leadership': 4, 'Off The Ball': 5,
    'Positioning': 6, 'Teamwork': 7, 'Vision': 8, 'Work Rate': 9,
    'Consistency': 10, 'Dirtiness': 11, 'Important Matches': 12,
    'Acceleration': 13, 'Agility': 14, 'Balance': 15, 'Injury Proneness': 16,
    'Jumping Reach': 17, 'Natural Fitness': 18, 'Pace': 19, 'Stamina': 20, 'Strength': 1,
    'GK Familiarity': 1, 'DL Familiarity': 2, 'DC Familiarity': 3, 'DR Familiarity': 4,
    'WBL Familiarity': 5, 'WBR Familiarity': 6, 'DM Familiarity': 7, 'ML Familiarity': 8,
    'MC Familiarity': 9, 'MR Familiarity': 10, 'AML Familiarity': 11, 'AMC Familiarity': 12,
    'AMR Familiarity': 13, 'ST Familiarity': 14,
    'Left Foot': 20, 'Right Foot': 15,
    'Adaptability': 16, 'Ambition': 17, 'Controversy': 18, 'Loyalty': 19,
    'Pressure': 2, 'Professionalism': 3, 'Sportsmanship': 4, 'Temperament': 5, 'Versatility': 6,
}

# Ordered attribute lists (game order)
TECHNICAL_ORDER = ['Corners', 'Crossing', 'Dribbling', 'Finishing', 'First Touch',
                   'Free Kicks', 'Heading', 'Long Shots', 'Long Throws', 'Marking',
                   'Passing', 'Penalty Taking', 'Tackling', 'Technique']

MENTAL_ORDER = ['Aggression', 'Anticipation', 'Bravery', 'Composure', 'Concentration',
                'Decisions', 'Determination', 'Flair', 'Leadership', 'Off The Ball',
                'Positioning', 'Teamwork', 'Vision', 'Work Rate']

PHYSICAL_ORDER = ['Acceleration', 'Agility', 'Balance', 'Jumping Reach',
                  'Natural Fitness', 'Pace', 'Stamina', 'Strength']

POSITION_ORDER = ['GK Familiarity', 'DL Familiarity', 'DC Familiarity', 'DR Familiarity',
                  'WBL Familiarity', 'WBR Familiarity', 'DM Familiarity', 'ML Familiarity',
                  'MC Familiarity', 'MR Familiarity', 'AML Familiarity', 'AMC Familiarity',
                  'AMR Familiarity', 'ST Familiarity']


def main():
    base = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")

    print("="*80)
    print("FM26 CONTIGUOUS BLOCK MAPPING")
    print("="*80)

    print("\nLoading saves...")
    dec5 = FM26Decompressor(base / "Brixham5.fm")
    dec5.load()
    data5 = dec5.decompress_main_database()

    name = "Isaac James Smith"
    isaac5 = find_string_position(data5, name)
    print(f"\n{name} at: {isaac5:,}")

    # Read all bytes in the attribute region
    print("\n" + "="*80)
    print("RAW BYTE DUMP (name - 4130 to name - 4040)")
    print("="*80)

    print("\nOffset    : Value (scaled)  Possible attrs if in-game 1-20")
    print("-"*80)

    for offset in range(4130, 4040, -1):
        pos = isaac5 - offset
        if pos < 0 or pos >= len(data5):
            continue

        val = data5[pos]
        scaled = val / 5

        # Check if it's a valid attribute value (5-100 in increments of 5)
        if val >= 5 and val <= 100 and val % 5 == 0:
            ig_val = val // 5
            marker = f" <-- in-game {ig_val}"
        elif val == 0:
            marker = " (zero)"
        else:
            marker = ""

        print(f"{-offset:>+5}     : {val:>3} ({scaled:>5.1f}){marker}")

    # Now specifically look for the Technical block
    print("\n" + "="*80)
    print("IDENTIFYING TECHNICAL BLOCK")
    print("="*80)

    # Technical should have values 1-14 (internal 5-70)
    # Look for 14 consecutive bytes with these values
    tech_values = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70]

    for start in range(4130, 4050):
        found = []
        for i, expected in enumerate(tech_values):
            pos = isaac5 - start + i
            if pos >= 0 and pos < len(data5):
                actual = data5[pos]
                found.append((actual, expected, actual == expected))

        matches = sum(1 for f in found if f[2])
        if matches >= 10:  # At least 10/14 match
            print(f"\nPotential Technical block at offset -{start}")
            for i, (actual, expected, match) in enumerate(found):
                attr = TECHNICAL_ORDER[i]
                orig_val = BRIX5_VALUES[attr]
                status = "✓" if match else "✗"
                print(f"  {i+1:2}. {-start+i:>+5}: actual={actual:>3}, expected={expected:>3} {status} ({attr}={orig_val})")

    # More targeted: Look for sequential 1-14 pattern
    print("\n" + "="*80)
    print("SEARCHING FOR SEQUENTIAL 1-14 PATTERN")
    print("="*80)

    for start in range(4130, 4040):
        # Check if we have values 5,10,15,20,25,30,35,40,45,50,55,60,65,70 in sequence
        values = []
        for i in range(14):
            pos = isaac5 - start + i
            if pos >= 0 and pos < len(data5):
                values.append(data5[pos])

        # Check if values match the technical sequence
        expected = [BRIX5_VALUES[a] * 5 for a in TECHNICAL_ORDER]
        if values == expected:
            print(f"EXACT MATCH at offset -{start}!")
            for i, v in enumerate(values):
                print(f"  {TECHNICAL_ORDER[i]:>15}: {-start+i:>+5} = {v} ({v//5})")

    # Alternative: Search backwards from known values
    print("\n" + "="*80)
    print("SEARCHING BACKWARDS FROM KNOWN FITNESS OFFSETS")
    print("="*80)

    # We know fitness is at -4008 to -4012
    # Attributes should be before that

    # Look at blocks of 14 bytes
    print("\nLooking for attribute blocks...")

    for block_start in range(4100, 4040):
        pos_start = isaac5 - block_start
        if pos_start < 0 or pos_start + 14 >= len(data5):
            continue

        block = [data5[pos_start + i] for i in range(14)]

        # Check if all values are in valid attribute range (5-100)
        if all(5 <= v <= 100 and v % 5 == 0 for v in block):
            # Convert to in-game values
            ig_values = [v // 5 for v in block]

            # Check if this matches Technical order
            expected_tech = [BRIX5_VALUES[a] for a in TECHNICAL_ORDER]

            match_count = sum(1 for a, b in zip(ig_values, expected_tech) if a == b)

            if match_count >= 10:
                print(f"\nPotential block at -{block_start} to -{block_start-13}:")
                print(f"  Values: {ig_values}")
                print(f"  Expected Technical: {expected_tech}")
                print(f"  Matches: {match_count}/14")

    # Let's try a different approach: look for the actual byte values we set
    print("\n" + "="*80)
    print("LOOKING FOR KNOWN VALUES AT SPECIFIC POSITIONS")
    print("="*80)

    # From the previous run, we found:
    # -4105: 5 (Corners=1)
    # -4102: 15 (Dribbling=3)
    # -4101: 20 (Finishing=4)
    # -4100: 35 (Heading=7)
    # -4099: 40 (Long Shots=8)
    # -4098: 50 (Marking=10)
    # -4097: 25 (First Touch=5)
    # -4096: 55 (Passing=11)
    # -4095: 60 (Penalty Taking=12)

    # This suggests Technical is NOT in alphabetical order - need to figure out game order

    # Let me check the raw sequence from -4110 to -4090
    print("\nBytes from -4110 to -4090 in Brix5:")
    for offset in range(4110, 4090, -1):
        pos = isaac5 - offset
        val = data5[pos]
        scaled = val / 5
        if val % 5 == 0 and 5 <= val <= 100:
            print(f"  {-offset:>+5}: {val:>3} (in-game {val//5})")
        else:
            print(f"  {-offset:>+5}: {val:>3} (not attribute: {scaled:.1f})")

    # Now let me look at a wider range
    print("\n\nAll attribute-like values from -4120 to -4040:")
    attr_bytes = []
    for offset in range(4120, 4040, -1):
        pos = isaac5 - offset
        val = data5[pos]
        if val % 5 == 0 and 5 <= val <= 100:
            attr_bytes.append((-offset, val, val // 5))
            print(f"  {-offset:>+5}: {val:>3} (in-game {val//5})")

    print(f"\n\nFound {len(attr_bytes)} attribute-like bytes")

    # Identify runs of exactly 14 attribute values
    print("\n" + "="*80)
    print("IDENTIFYING 14-BYTE RUNS")
    print("="*80)

    offsets_with_attrs = [x[0] for x in attr_bytes]

    # Find runs where offsets are consecutive
    runs = []
    current_run = [offsets_with_attrs[0]] if offsets_with_attrs else []

    for i in range(1, len(offsets_with_attrs)):
        if offsets_with_attrs[i] == offsets_with_attrs[i-1] - 1:
            current_run.append(offsets_with_attrs[i])
        else:
            if len(current_run) >= 5:
                runs.append(current_run)
            current_run = [offsets_with_attrs[i]]

    if len(current_run) >= 5:
        runs.append(current_run)

    for run in runs:
        print(f"\nRun of {len(run)} consecutive attrs: {run[0]} to {run[-1]}")
        values = []
        for offset in run:
            pos = isaac5 + offset  # offset is negative
            val = data5[pos]
            values.append(val // 5)
        print(f"  In-game values: {values}")


if __name__ == "__main__":
    main()
