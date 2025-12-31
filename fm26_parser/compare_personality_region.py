#!/usr/bin/env python3
"""
Compare the personality region between Base and Brix10.
The personality values are at -4163 to -4082 in Brix10.
Let's see what Base has there.
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


def main():
    base = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")
    name = "Isaac James Smith"

    print("Loading saves...")
    dec_base = FM26Decompressor(base / "Brixham.fm")
    dec_base.load()
    base_data = dec_base.decompress_main_database()
    base_pos = find_string_position(base_data, name)

    dec10 = FM26Decompressor(base / "Brixham10.fm")
    dec10.load()
    data10 = dec10.decompress_main_database()
    pos10 = find_string_position(data10, name)

    print(f"Base: Isaac at {base_pos:,}")
    print(f"Brix10: Isaac at {pos10:,}")
    print(f"Shift: {pos10 - base_pos:+}")

    # Show side-by-side comparison at the personality region
    print("\n" + "="*90)
    print("SIDE-BY-SIDE COMPARISON: -4200 to -4050")
    print("Using same offset from each save's Isaac position")
    print("="*90)
    print(f"{'Offset':>8} | {'Base':>5} | {'Brix10':>6} | {'Change':>8} | Notes")
    print("-"*90)

    personality_new_vals = {5, 10, 15, 20, 25, 30, 35, 40, 45}

    for offset in range(4200, 4050, -1):
        base_check = base_pos - offset
        mod_check = pos10 - offset

        if base_check < 0 or mod_check < 0:
            continue
        if base_check >= len(base_data) or mod_check >= len(data10):
            continue

        base_val = base_data[base_check]
        mod_val = data10[mod_check]

        # Only show rows where:
        # 1. There's a change, OR
        # 2. Either value is in the personality range
        if base_val != mod_val or base_val in personality_new_vals or mod_val in personality_new_vals or base_val == 50 or base_val == 85:
            change = f"{base_val:>3} -> {mod_val:<3}" if base_val != mod_val else "     "

            notes = []
            if base_val == 50:
                notes.append("base=50")
            if base_val == 85:
                notes.append("base=85")
            if mod_val in personality_new_vals:
                notes.append(f"mod in personality range")

            print(f"  {-offset:>+5} | {base_val:>5} | {mod_val:>6} | {change:>8} | {', '.join(notes)}")

    # Now let's try a different approach:
    # Search for positions where Brix10 has personality values (5-45)
    # And check what Base has at the SAME ABSOLUTE position
    print("\n" + "="*90)
    print("CHECKING: Where Brix10 has 5-45, what does Base have at SAME ABSOLUTE position?")
    print("="*90)

    # Known personality positions in Brix10 (from previous search)
    brix10_personality_positions = [
        (165660788, 20),
        (165660800, 15),
        (165660804, 10),
        (165660806, 25),
        (165660807, 30),
        # etc.
    ]

    # Just scan the region directly
    for offset in range(4200, 4050, -1):
        mod_check = pos10 - offset
        if mod_check < 0 or mod_check >= len(data10):
            continue

        mod_val = data10[mod_check]

        # Check if Brix10 has a personality value here
        if mod_val in {5, 10, 15, 20, 25, 30, 35, 40, 45}:
            # What does Base have at the SAME absolute position?
            if mod_check < len(base_data):
                base_at_same_pos = base_data[mod_check]
            else:
                base_at_same_pos = -1

            # What does Base have at the OFFSET-relative position?
            base_check = base_pos - offset
            if 0 <= base_check < len(base_data):
                base_at_offset = base_data[base_check]
            else:
                base_at_offset = -1

            print(f"  offset {-offset:>+5}: Brix10={mod_val:>2}, Base@same_pos={base_at_same_pos:>3}, Base@offset={base_at_offset:>3}")

    # Let's look at it from the OTHER direction:
    # Where does Base have value 50 in this region?
    print("\n" + "="*90)
    print("WHERE DOES BASE HAVE VALUE 50 IN THE -4200 to -4050 RANGE?")
    print("="*90)

    for offset in range(4200, 4050, -1):
        base_check = base_pos - offset
        if base_check < 0 or base_check >= len(base_data):
            continue

        if base_data[base_check] == 50:
            # What does Brix10 have at matching offset AND at same absolute position?
            mod_at_offset = data10[pos10 - offset] if 0 <= pos10 - offset < len(data10) else -1
            mod_at_same = data10[base_check + 480] if 0 <= base_check + 480 < len(data10) else -1  # +480 is the shift

            print(f"  Base has 50 at offset {-offset:>+5}: Brix10@offset={mod_at_offset:>3}, Brix10@base+480={mod_at_same:>3}")

    # What if personality values moved by a DIFFERENT shift?
    print("\n" + "="*90)
    print("TRYING DIFFERENT SHIFTS FOR PERSONALITY REGION")
    print("Looking for shift where base 50 becomes brix10 {5,10,15,20,25,30,35,40}")
    print("="*90)

    for test_shift in range(400, 600):
        matches = 0
        for offset in range(4200, 4050, -1):
            base_check = base_pos - offset
            mod_check = base_check + test_shift

            if base_check < 0 or mod_check < 0:
                continue
            if base_check >= len(base_data) or mod_check >= len(data10):
                continue

            if base_data[base_check] == 50 and data10[mod_check] in {5, 10, 15, 20, 25, 30, 35, 40}:
                matches += 1

        if matches >= 3:
            print(f"  Shift +{test_shift}: {matches} personality matches")

            # Show the specific matches
            if matches >= 5:
                print("    Details:")
                for offset in range(4200, 4050, -1):
                    base_check = base_pos - offset
                    mod_check = base_check + test_shift

                    if base_check < 0 or mod_check < 0:
                        continue
                    if base_check >= len(base_data) or mod_check >= len(data10):
                        continue

                    if base_data[base_check] == 50 and data10[mod_check] in {5, 10, 15, 20, 25, 30, 35, 40}:
                        print(f"      base offset {-offset:>+5} -> brix10 value {data10[mod_check]}")


if __name__ == "__main__":
    main()
