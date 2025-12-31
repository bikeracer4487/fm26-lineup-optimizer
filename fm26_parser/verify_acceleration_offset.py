#!/usr/bin/env python3
"""
Verify that Acceleration is at offset +1 from Pace.

We found:
- Isaac's Pace at offset 165,660,358
- Isaac's name "Isaac James Smith" at offset +4113 from Pace
- Potential Acceleration at offset +1 from Pace (value 65 = 13 scaled)

In Brix3, we changed Isaac's Acceleration from 13 to 20.
If offset +1 is correct, it should now be 100 in Brix3.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor


def find_string_position(data: bytes, target: str) -> list:
    """Find all occurrences of a length-prefixed string."""
    target_bytes = target.encode('utf-8')
    pattern = len(target_bytes).to_bytes(4, 'little') + target_bytes

    positions = []
    pos = 0
    while True:
        pos = data.find(pattern, pos)
        if pos == -1:
            break
        positions.append(pos + 4)
        pos += 1

    return positions


def main():
    base = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")

    print("Loading all three saves...")

    dec1 = FM26Decompressor(base / "Brixham.fm")
    dec1.load()
    data1 = dec1.decompress_main_database()

    dec2 = FM26Decompressor(base / "Brixham2.fm")
    dec2.load()
    data2 = dec2.decompress_main_database()

    dec3 = FM26Decompressor(base / "Brixham3.fm")
    dec3.load()
    data3 = dec3.decompress_main_database()

    print(f"\nSizes: {len(data1):,} / {len(data2):,} / {len(data3):,}")

    # Find "Isaac James Smith" in each save
    print("\n" + "="*70)
    print("FINDING 'Isaac James Smith' IN EACH SAVE")
    print("="*70)

    name = "Isaac James Smith"
    pos1 = find_string_position(data1, name)
    pos2 = find_string_position(data2, name)
    pos3 = find_string_position(data3, name)

    print(f"\n{name}:")
    print(f"  Brixham.fm:  {len(pos1)} occurrence(s)")
    print(f"  Brixham2.fm: {len(pos2)} occurrence(s)")
    print(f"  Brixham3.fm: {len(pos3)} occurrence(s)")

    if pos1:
        print(f"\n  Positions in Brixham.fm:  {pos1[:5]}")
    if pos2:
        print(f"  Positions in Brixham2.fm: {pos2[:5]}")
    if pos3:
        print(f"  Positions in Brixham3.fm: {pos3[:5]}")

    # The name is at +4113 from Pace offset, so Pace is at name_pos - 4113
    # Let's verify by checking the known Pace offset
    known_pace_offset = 165660358
    expected_name_offset = known_pace_offset + 4113

    print(f"\n" + "="*70)
    print("VERIFYING PACE → NAME RELATIONSHIP")
    print("="*70)
    print(f"\nKnown Pace offset: {known_pace_offset:,}")
    print(f"Expected name offset: {expected_name_offset:,}")

    if pos1:
        closest = min(pos1, key=lambda p: abs(p - expected_name_offset))
        print(f"Closest name position in Brix1: {closest:,} (diff: {closest - expected_name_offset:+d})")

    # For each name occurrence, calculate where Pace would be (at offset -4113)
    # and check if the Acceleration byte (at Pace + 1) matches expected changes

    print(f"\n" + "="*70)
    print("CHECKING PACE AND ACCELERATION AT EACH NAME OCCURRENCE")
    print("="*70)

    for i, (p1, p2, p3) in enumerate(zip(pos1[:3], pos2[:3], pos3[:3])):
        pace_offset_1 = p1 - 4113
        pace_offset_2 = p2 - 4113
        pace_offset_3 = p3 - 4113

        if pace_offset_1 >= 0 and pace_offset_2 >= 0 and pace_offset_3 >= 0:
            pace_1 = data1[pace_offset_1]
            pace_2 = data2[pace_offset_2]
            pace_3 = data3[pace_offset_3]

            accel_1 = data1[pace_offset_1 + 1]
            accel_2 = data2[pace_offset_2 + 1]
            accel_3 = data3[pace_offset_3 + 1]

            print(f"\nOccurrence {i+1}:")
            print(f"  Name positions: {p1:,} / {p2:,} / {p3:,}")
            print(f"  Pace positions: {pace_offset_1:,} / {pace_offset_2:,} / {pace_offset_3:,}")
            print(f"  Pace values: {pace_1} → {pace_2} → {pace_3} (scaled: {round(pace_1/5)} → {round(pace_2/5)} → {round(pace_3/5)})")
            print(f"  Accel values: {accel_1} → {accel_2} → {accel_3} (scaled: {round(accel_1/5)} → {round(accel_2/5)} → {round(accel_3/5)})")

            # Check if this matches expected changes
            # Expected: Pace 52 → 100 → 100, Accel 65 → 65 → 100
            if pace_1 == 52 and pace_2 == 100 and pace_3 == 100:
                print(f"  *** PACE MATCHES EXPECTED PATTERN! ***")
            if accel_1 == 65 and accel_2 == 65 and accel_3 == 100:
                print(f"  *** ACCELERATION MATCHES EXPECTED PATTERN! ***")

    # Also check the specific known Pace offset directly
    print(f"\n" + "="*70)
    print("DIRECT CHECK AT KNOWN PACE OFFSET")
    print("="*70)

    print(f"\nAt offset {known_pace_offset:,}:")
    print(f"  Pace: {data1[known_pace_offset]} → {data2[known_pace_offset]} → (structure shifted)")
    print(f"  Accel (+1): {data1[known_pace_offset + 1]} → {data2[known_pace_offset + 1]} → (structure shifted)")

    # Now let's map out all the potential attribute offsets relative to Pace
    print(f"\n" + "="*70)
    print("MAPPING ATTRIBUTE OFFSETS RELATIVE TO PACE")
    print("="*70)

    # Using the Brix1 data at the known good offset
    pace_pos = known_pace_offset

    # Physical attributes (likely grouped together)
    # We know: Pace at 0, Acceleration at +1
    # Other physical: Agility, Balance, Jumping Reach, Natural Fitness, Stamina, Strength

    print("\nPotential attribute mapping (based on Brix1 values):")
    print(f"{'Offset':>8} | {'Value':>5} | {'Scaled':>7} | Possible Attribute")
    print("-" * 60)

    # Show bytes around Pace
    for rel in range(-5, 20):
        abs_pos = pace_pos + rel
        val = data1[abs_pos]
        scaled = round(val / 5)

        attr_guess = ""
        if rel == 0:
            attr_guess = "PACE (confirmed)"
        elif rel == 1:
            attr_guess = "ACCELERATION (likely!)"
        elif 20 <= val <= 100:
            attr_guess = f"? (value in attr range)"

        print(f"{rel:>+8} | {val:>5} | {scaled:>7} | {attr_guess}")


if __name__ == "__main__":
    main()
