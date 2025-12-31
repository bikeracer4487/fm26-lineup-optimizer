#!/usr/bin/env python3
"""
Check the area around feet (which we know changed correctly).
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

    print(f"Base Isaac: {base_pos:,}")
    print(f"Brix10 Isaac: {pos10:,}")

    # We know:
    # Left Foot at -4127: 55 -> 100
    # Right Foot at -4126: 100 -> 95

    # Check ALL bytes from -4200 to -4050 with the nominal 480 byte shift
    print("\n" + "="*80)
    print("ALL CHANGES FROM -4200 to -4050")
    print("(using nominal 480 byte shift)")
    print("="*80)

    shift = pos10 - base_pos  # 480

    for offset in range(4200, 4050, -1):
        base_check = base_pos - offset
        mod_check = pos10 - offset

        if base_check < 0 or mod_check < 0:
            continue
        if mod_check >= len(data10):
            continue

        base_val = base_data[base_check]
        mod_val = data10[mod_check]

        if base_val != mod_val:
            # Check if it looks like an attribute change
            is_base_attr = (base_val % 5 == 0 and 5 <= base_val <= 100)
            is_mod_attr = (mod_val % 5 == 0 and 5 <= mod_val <= 100)

            if is_base_attr and is_mod_attr:
                marker = f"  ATTR: {base_val//5} -> {mod_val//5}"
            elif is_base_attr or is_mod_attr:
                marker = f"  partial attr"
            else:
                marker = ""

            print(f"  {-offset:>+5}: {base_val:>3} -> {mod_val:>3}{marker}")

    # Let's also check what's at the exact positions we expect personality
    # If original was 10 (internal 50) and we check positions that have 50 in base
    print("\n" + "="*80)
    print("POSITIONS WITH BASE VALUE 50 (potential personality)")
    print("="*80)

    for offset in range(4300, 4000, -1):
        base_check = base_pos - offset
        if base_check < 0:
            continue

        base_val = base_data[base_check]

        if base_val == 50:
            mod_check = pos10 - offset
            if 0 <= mod_check < len(data10):
                mod_val = data10[mod_check]
                print(f"  {-offset:>+5}: 50 -> {mod_val}")

    # Maybe personality is stored as a DIFFERENT data type (16-bit?)
    print("\n" + "="*80)
    print("CHECKING IF PERSONALITY MIGHT BE 16-BIT VALUES")
    print("Looking for 16-bit value 500 (10*50) or similar")
    print("="*80)

    # If personality uses a different scale, e.g., 0-1000 instead of 0-100
    # Then "10" might be stored as 500 or 100 or some other value

    for offset in range(4300, 4000, -1):
        base_check = base_pos - offset

        if base_check < 2:
            continue

        # Read as 16-bit
        base_16 = int.from_bytes(base_data[base_check:base_check+2], 'little')

        mod_check = pos10 - offset
        if mod_check < 2 or mod_check >= len(data10) - 1:
            continue

        mod_16 = int.from_bytes(data10[mod_check:mod_check+2], 'little')

        # Check for personality-like values (100-1000 range, multiples of 50 or 100)
        if base_16 != mod_16:
            if (100 <= base_16 <= 1000 and base_16 % 50 == 0) or \
               (100 <= mod_16 <= 1000 and mod_16 % 50 == 0):
                print(f"  {-offset:>+5}: {base_16} -> {mod_16}")


if __name__ == "__main__":
    main()
