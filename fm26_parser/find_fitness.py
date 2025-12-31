#!/usr/bin/env python3
"""
Find fitness values in Brix10 to verify save worked correctly.
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

    # Fitness changes in Brix10:
    # Condition: 9528 -> 7100
    # Sharpness: 5100 -> 6400
    # Fatigue: -500 -> 35

    print("\n" + "="*80)
    print("SEARCHING FOR FITNESS VALUE CHANGES")
    print("="*80)

    # Search for 16-bit value pairs
    print("\nLooking for Condition: 9528 -> 7100")
    for offset in range(4100, 3900, -1):
        pos_b = base_pos - offset
        pos_m = pos10 - offset

        if pos_b < 2 or pos_m < 2:
            continue

        old_16 = int.from_bytes(base_data[pos_b:pos_b+2], 'little')
        new_16 = int.from_bytes(data10[pos_m:pos_m+2], 'little')

        if old_16 == 9528 and new_16 == 7100:
            print(f"  FOUND Condition at offset {-offset}")

        if abs(old_16 - 9528) < 100 or abs(new_16 - 7100) < 100:
            if old_16 != new_16:
                print(f"  {-offset:>+5}: {old_16:>6} -> {new_16:>6}")

    print("\nLooking for Sharpness: 5100 -> 6400")
    for offset in range(4100, 3900, -1):
        pos_b = base_pos - offset
        pos_m = pos10 - offset

        if pos_b < 2 or pos_m < 2:
            continue

        old_16 = int.from_bytes(base_data[pos_b:pos_b+2], 'little')
        new_16 = int.from_bytes(data10[pos_m:pos_m+2], 'little')

        if old_16 == 5100 and new_16 == 6400:
            print(f"  FOUND Sharpness at offset {-offset}")

        if abs(old_16 - 5100) < 100 or abs(new_16 - 6400) < 100:
            if old_16 != new_16:
                print(f"  {-offset:>+5}: {old_16:>6} -> {new_16:>6}")

    print("\nLooking for Fatigue: -500 -> 35 (as signed 16-bit)")
    for offset in range(4100, 3900, -1):
        pos_b = base_pos - offset
        pos_m = pos10 - offset

        if pos_b < 2 or pos_m < 2:
            continue

        old_16 = int.from_bytes(base_data[pos_b:pos_b+2], 'little', signed=True)
        new_16 = int.from_bytes(data10[pos_m:pos_m+2], 'little', signed=True)

        if old_16 == -500 and new_16 == 35:
            print(f"  FOUND Fatigue at offset {-offset}")

        if abs(old_16 - (-500)) < 100 or abs(new_16 - 35) < 100:
            if old_16 != new_16:
                print(f"  {-offset:>+5}: {old_16:>6} -> {new_16:>6}")

    # General scan for large 16-bit value changes
    print("\n" + "="*80)
    print("ALL SIGNIFICANT 16-BIT CHANGES (values > 1000)")
    print("="*80)

    for offset in range(4200, 3900, -1):
        pos_b = base_pos - offset
        pos_m = pos10 - offset

        if pos_b < 2 or pos_m < 2:
            continue

        old_16 = int.from_bytes(base_data[pos_b:pos_b+2], 'little', signed=True)
        new_16 = int.from_bytes(data10[pos_m:pos_m+2], 'little', signed=True)

        if old_16 != new_16 and (abs(old_16) > 1000 or abs(new_16) > 1000):
            print(f"  {-offset:>+5}: {old_16:>6} -> {new_16:>6}")

    # Also check if personality might be stored relative to a different anchor
    print("\n" + "="*80)
    print("CHECKING FOR PERSONALITY NEAR KNOWN LOCATIONS")
    print("="*80)

    # We know Sportsmanship was at -4115 in earlier tests
    # Check if it's still there
    pos_b = base_pos - 4115
    pos_m = pos10 - 4115

    old_val = base_data[pos_b]
    new_val = data10[pos_m]

    print(f"\nAt -4115 (expected Sportsmanship):")
    print(f"  Base: {old_val} ({old_val/5:.1f})")
    print(f"  Brix10: {new_val} ({new_val/5:.1f})")

    # In Brix10, Sportsmanship was changed 10 -> 7 (50 -> 35)
    # So we should see a change from 50 to 35

    if old_val == 50 and new_val == 35:
        print("  MATCH! Sportsmanship confirmed at -4115")


if __name__ == "__main__":
    main()
