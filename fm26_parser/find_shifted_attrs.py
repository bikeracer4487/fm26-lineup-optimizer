#!/usr/bin/env python3
"""
Find where Aggression (75) is stored in Brix9.

User confirmed:
- Brix7: Aggression = 1, ST = 1
- Brix9: Aggression = 15, ST = 14

So in Brix9, Aggression should still be 75 somewhere (just not at -4106).
The 48-byte shift between saves might affect internal record structure.
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

    dec7 = FM26Decompressor(base / "Brixham7.fm")
    dec7.load()
    data7 = dec7.decompress_main_database()
    pos7 = find_string_position(data7, name)

    dec9 = FM26Decompressor(base / "Brixham9.fm")
    dec9.load()
    data9 = dec9.decompress_main_database()
    pos9 = find_string_position(data9, name)

    shift7 = pos7 - base_pos  # +480
    shift9 = pos9 - base_pos  # +432
    shift_diff = shift7 - shift9  # 48

    print(f"\nShifts: Brix7={shift7:+}, Brix9={shift9:+}, Difference={shift_diff}")

    print("\n" + "="*80)
    print("THEORY: Attributes shifted by 48 bytes between Brix7 and Brix9")
    print("="*80)

    # In Brix7, Aggression is at -4106 (confirmed: 75→5)
    # In Brix9, if shifted by 48, Aggression would be at -4106 + 48 = -4058
    # OR at -4106 - 48 = -4154

    print("\nAggression in Brix7 is at -4106 (value: 5 = Aggression 1)")
    print("\nIf shifted +48 in Brix9, Aggression would be at -4058")
    print("If shifted -48 in Brix9, Aggression would be at -4154")

    # Check what's at these offsets
    print("\n--- Checking potential Aggression locations in Brix9 ---")

    candidates = [
        (-4106, "Original offset"),
        (-4058, "Shifted +48"),
        (-4154, "Shifted -48"),
    ]

    for offset, desc in candidates:
        base_val = base_data[base_pos + offset]
        val9 = data9[pos9 + offset]
        print(f"  {offset} ({desc}): Base={base_val}, Brix9={val9}")
        if val9 == 75:
            print(f"    ^^^ This is 75 = Aggression 15! FOUND!")

    # Now check ST position
    print("\n" + "="*80)
    print("FINDING ST POSITION")
    print("="*80)

    print("\nOriginal ST = 1 (internal 5 if 0-100 scale)")
    print("In Brix9, ST changed to 14")
    print("\nIn Brix7, ST should still be 1 (unchanged)")

    # ST in Brix9 is at -4106 (value 14)
    # So in Brix7, ST should be at -4106 - 48 = -4154 (if shift works same way)
    # OR at -4106 + 48 = -4058

    print("\n--- Looking for ST=1 (value 5) in Base and Brix7 ---")

    # Search for value 5 in Base near -4106
    for offset in range(-4200, -4000):
        base_val = base_data[base_pos + offset]
        if base_val == 5:
            val7 = data7[pos7 + offset]
            val9 = data9[pos9 + offset]
            if val7 == 5:  # ST unchanged in Brix7
                print(f"  {offset}: Base=5, Brix7=5, Brix9={val9}")
                if val9 == 14:
                    print(f"    ^^^ Brix9={val9} - This could be where ST changed to 14!")

    print("\n" + "="*80)
    print("SYSTEMATIC COMPARISON")
    print("="*80)
    print("Looking for offsets where:")
    print("  - Base and Brix7 have same value (unchanged in mental edit)")
    print("  - Brix9 has different value (changed in position edit)")

    # These would be position familiarity offsets
    position_only_changes = []
    for offset in range(-4200, -4000):
        base_val = base_data[base_pos + offset]
        val7 = data7[pos7 + offset]
        val9 = data9[pos9 + offset]

        if base_val == val7 and base_val != val9:
            position_only_changes.append((offset, base_val, val9))

    print(f"\nFound {len(position_only_changes)} offsets changed ONLY in Brix9:")
    for offset, base_val, val9 in position_only_changes:
        # Check if val9 looks like position familiarity (1-20 raw)
        if 1 <= val9 <= 20:
            print(f"  {offset}: {base_val} → {val9} (position fam candidate)")

    print("\n" + "="*80)
    print("And offsets where:")
    print("  - Base and Brix9 have same value (unchanged in position edit)")
    print("  - Brix7 has different value (changed in mental edit)")
    print("="*80)

    # These would be mental attribute offsets
    mental_only_changes = []
    for offset in range(-4200, -4000):
        base_val = base_data[base_pos + offset]
        val7 = data7[pos7 + offset]
        val9 = data9[pos9 + offset]

        if base_val == val9 and base_val != val7:
            mental_only_changes.append((offset, base_val, val7))

    print(f"\nFound {len(mental_only_changes)} offsets changed ONLY in Brix7:")
    for offset, base_val, val7 in mental_only_changes:
        ig_old = base_val / 5 if base_val > 20 else base_val
        ig_new = val7 / 5 if val7 > 20 else val7
        print(f"  {offset}: {base_val} → {val7} ({ig_old:.0f} → {ig_new:.0f} ig)")


if __name__ == "__main__":
    main()
