#!/usr/bin/env python3
"""
Find personality attributes by scanning a wider range.
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
    print(f"Shift: {pos10 - base_pos:+,}")

    # Personality changes: original all = 50 (in-game 10), new = 5,10,15,20,25,30,35,40 (in-game 1-8)
    # Versatility: 85 -> 45 (17 -> 9)

    print("\n" + "="*80)
    print("SCANNING WIDE RANGE FOR (50, X) PATTERNS")
    print("Where X is 5,10,15,20,25,30,35,40 (in-game 1-8)")
    print("="*80)

    found_50 = []
    for offset in range(5000, 3000, -1):
        pos_b = base_pos - offset
        pos_m = pos10 - offset

        if pos_b < 0 or pos_m < 0:
            continue
        if pos_b >= len(base_data) or pos_m >= len(data10):
            continue

        old_val = base_data[pos_b]
        new_val = data10[pos_m]

        if old_val == 50 and new_val in [5, 10, 15, 20, 25, 30, 35, 40]:
            found_50.append((-offset, old_val, new_val, new_val // 5))
            print(f"  {-offset:>+5}: 50 -> {new_val} (10 -> {new_val//5})")

    print(f"\nFound {len(found_50)} matches")

    # Also look for Versatility: 85 -> 45
    print("\n" + "="*80)
    print("SCANNING FOR VERSATILITY (85 -> 45)")
    print("="*80)

    for offset in range(5000, 3000, -1):
        pos_b = base_pos - offset
        pos_m = pos10 - offset

        if pos_b < 0 or pos_m < 0:
            continue
        if pos_b >= len(base_data) or pos_m >= len(data10):
            continue

        old_val = base_data[pos_b]
        new_val = data10[pos_m]

        if old_val == 85 and new_val == 45:
            print(f"  {-offset:>+5}: 85 -> 45 (Versatility)")

    # Maybe the original values aren't exactly 50?
    # Let's look for any value changing to our expected new values
    print("\n" + "="*80)
    print("SCANNING FOR ANY VALUE -> 5/10/15/20/25/30/35/40")
    print("="*80)

    for new_target in [5, 10, 15, 20, 25, 30, 35, 40]:
        matches = []
        for offset in range(4300, 4050, -1):
            pos_b = base_pos - offset
            pos_m = pos10 - offset

            if pos_b < 0 or pos_m < 0:
                continue
            if pos_b >= len(base_data) or pos_m >= len(data10):
                continue

            old_val = base_data[pos_b]
            new_val = data10[pos_m]

            if new_val == new_target and old_val != new_val:
                matches.append((-offset, old_val, new_val))

        if matches:
            print(f"\nChanges to {new_target} (in-game {new_target//5}):")
            for off, old, new in matches:
                print(f"  {off:>+5}: {old} -> {new}")

    # Finally, let's just look at all attribute-like changes
    print("\n" + "="*80)
    print("ALL ATTRIBUTE-LIKE CHANGES (multiples of 5, 5-100)")
    print("="*80)

    for offset in range(4200, 4050, -1):
        pos_b = base_pos - offset
        pos_m = pos10 - offset

        if pos_b < 0 or pos_m < 0:
            continue
        if pos_b >= len(base_data) or pos_m >= len(data10):
            continue

        old_val = base_data[pos_b]
        new_val = data10[pos_m]

        if old_val != new_val:
            is_old_attr = (old_val % 5 == 0 and 5 <= old_val <= 100)
            is_new_attr = (new_val % 5 == 0 and 5 <= new_val <= 100)

            if is_old_attr or is_new_attr:
                old_str = f"{old_val:>3} ({old_val//5:>2})" if is_old_attr else f"{old_val:>3}    "
                new_str = f"{new_val:>3} ({new_val//5:>2})" if is_new_attr else f"{new_val:>3}    "
                print(f"  {-offset:>+5}: {old_str} -> {new_str}")


if __name__ == "__main__":
    main()
