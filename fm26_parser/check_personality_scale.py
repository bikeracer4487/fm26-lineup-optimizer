#!/usr/bin/env python3
"""
Try different scales for personality.
Maybe personality uses:
- 0-20 scale (like in-game display)
- 0-200 scale (double)
- Signed values (-100 to +100)
- Different multiplier (x10 instead of x5)
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

    # If personality is stored as 0-20 scale (raw in-game value):
    # Original 10 -> stored as 10
    # New values 1-9 -> stored as 1-9
    print("\n" + "="*80)
    print("TEST 1: Personality stored as 0-20 scale (raw in-game values)")
    print("Looking for: 10 -> {1,2,3,4,5,6,7,8,9}")
    print("="*80)

    changes_raw = []
    for offset in range(5000, 3500, -1):
        base_check = base_pos - offset
        mod_check = pos10 - offset

        if base_check < 0 or mod_check < 0:
            continue
        if base_check >= len(base_data) or mod_check >= len(data10):
            continue

        base_val = base_data[base_check]
        mod_val = data10[mod_check]

        if base_val == 10 and mod_val in {1, 2, 3, 4, 5, 6, 7, 8, 9}:
            changes_raw.append((-offset, mod_val))
            print(f"  offset {-offset:>+5}: 10 -> {mod_val}")

    print(f"\nFound {len(changes_raw)} matches")

    # If personality is stored as 0-200 scale:
    # Original 10 -> stored as 100
    # New values 1-9 -> stored as 10,20,30,40,50,60,70,80,90
    print("\n" + "="*80)
    print("TEST 2: Personality stored as 0-200 scale (x10)")
    print("Looking for: 100 -> {10,20,30,40,50,60,70,80,90}")
    print("="*80)

    changes_200 = []
    for offset in range(5000, 3500, -1):
        base_check = base_pos - offset
        mod_check = pos10 - offset

        if base_check < 0 or mod_check < 0:
            continue
        if base_check >= len(base_data) or mod_check >= len(data10):
            continue

        base_val = base_data[base_check]
        mod_val = data10[mod_check]

        if base_val == 100 and mod_val in {10, 20, 30, 40, 50, 60, 70, 80, 90}:
            changes_200.append((-offset, mod_val))
            print(f"  offset {-offset:>+5}: 100 -> {mod_val}")

    print(f"\nFound {len(changes_200)} matches")

    # What if we're just looking for ANY systematic change in the personality region?
    # Let's show ALL changes in a wider region
    print("\n" + "="*80)
    print("ALL BYTE CHANGES FROM -5000 to -3500")
    print("="*80)

    all_changes = []
    for offset in range(5000, 3500, -1):
        base_check = base_pos - offset
        mod_check = pos10 - offset

        if base_check < 0 or mod_check < 0:
            continue
        if base_check >= len(base_data) or mod_check >= len(data10):
            continue

        base_val = base_data[base_check]
        mod_val = data10[mod_check]

        if base_val != mod_val:
            all_changes.append((-offset, base_val, mod_val))

    print(f"Found {len(all_changes)} total changes")
    for off, base_val, mod_val in all_changes:
        # Annotate known changes
        note = ""
        if off == -4127:
            note = " (Left Foot)"
        elif off == -4126:
            note = " (Right Foot)"
        elif -4085 <= off <= -4079:
            note = " (Fitness area)"

        # Check if it could be personality
        if base_val % 5 == 0 and mod_val % 5 == 0 and base_val >= 5 and mod_val >= 5:
            internal_base = base_val // 5
            internal_mod = mod_val // 5
            if 1 <= internal_base <= 20 and 1 <= internal_mod <= 20:
                note = f" (could be attr: {internal_base} -> {internal_mod})"

        print(f"  offset {off:>+5}: {base_val:>3} -> {mod_val:<3}{note}")

    # What if personality isn't next to technical attributes but MUCH further away?
    print("\n" + "="*80)
    print("CHECKING EXTENDED RANGE: -10000 to -5000")
    print("="*80)

    for offset in range(10000, 5000, -1):
        base_check = base_pos - offset
        mod_check = pos10 - offset

        if base_check < 0 or mod_check < 0:
            continue
        if base_check >= len(base_data) or mod_check >= len(data10):
            continue

        base_val = base_data[base_check]
        mod_val = data10[mod_check]

        # Look for personality-like changes
        if base_val == 50 and mod_val in {5, 10, 15, 20, 25, 30, 35, 40}:
            print(f"  offset {-offset:>+5}: {base_val} -> {mod_val}")
        elif base_val == 85 and mod_val == 45:
            print(f"  offset {-offset:>+5}: {base_val} -> {mod_val} (Versatility!)")
        elif base_val == 10 and mod_val in {1, 2, 3, 4, 5, 6, 7, 8, 9}:
            print(f"  offset {-offset:>+5}: {base_val} -> {mod_val} (raw scale)")

    # Check POSITIVE offsets (after name)
    print("\n" + "="*80)
    print("CHECKING POSITIVE RANGE: +0 to +5000")
    print("="*80)

    for offset in range(0, 5000):
        base_check = base_pos + offset
        mod_check = pos10 + offset

        if base_check >= len(base_data) or mod_check >= len(data10):
            continue

        base_val = base_data[base_check]
        mod_val = data10[mod_check]

        # Look for personality-like changes
        if base_val == 50 and mod_val in {5, 10, 15, 20, 25, 30, 35, 40}:
            print(f"  offset +{offset}: {base_val} -> {mod_val}")
        elif base_val == 85 and mod_val == 45:
            print(f"  offset +{offset}: {base_val} -> {mod_val} (Versatility!)")
        elif base_val == 10 and mod_val in {1, 2, 3, 4, 5, 6, 7, 8, 9}:
            print(f"  offset +{offset}: {base_val} -> {mod_val} (raw scale)")


if __name__ == "__main__":
    main()
