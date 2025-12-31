#!/usr/bin/env python3
"""
Find personality by checking if everything shifted by ~72 bytes.
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
    print(f"Position shift: {pos10 - base_pos:+,}")

    # Old fitness offsets vs new:
    # Old Condition: -4008 -> New: -4080 (shift of 72)
    # Old Sharpness: -4012 -> New: -4084 (shift of 72)
    # Old Fatigue: -4010 -> New: -4082 (shift of 72)

    # If Sportsmanship was at -4115, it might now be at -4115 - 72 = -4187
    # But wait - the offsets are MORE negative (further from name), not less

    # Actually, the old offsets (-4008 etc) were from earlier saves
    # The new offsets (-4080 etc) are from Brix10
    # So the data moved AWAY from the name by 72 bytes

    shift = 72

    print("\n" + "="*80)
    print(f"CHECKING FOR {shift}-BYTE ATTRIBUTE SHIFT")
    print("="*80)

    # Check if Sportsmanship moved to -4115 - 72 = -4187
    # Actually wait - in Brix10, fitness moved from ~-4008 to ~-4080
    # That means attributes are now 72 bytes MORE negative (further from name)

    # So if Sportsmanship was at -4115 in the old schema,
    # we need to check what offset in the BASE corresponds to offset-72 in Brix10

    # Actually, the simplest approach: scan for (50, 35) which is Sportsmanship 10->7
    print("\nScanning for Sportsmanship change (50 -> 35):")
    for offset in range(4300, 4000, -1):
        pos_b = base_pos - offset
        pos_m = pos10 - offset

        if pos_b < 0 or pos_m < 0:
            continue
        if pos_b >= len(base_data) or pos_m >= len(data10):
            continue

        old_val = base_data[pos_b]
        new_val = data10[pos_m]

        if old_val == 50 and new_val == 35:
            print(f"  FOUND at {-offset:>+5}: 50 -> 35 (Sportsmanship)")

    # Scan for all personality changes
    print("\nScanning for all personality changes (all were original 50):")
    print("Expected: 50->5(Adapt), 50->10(Amb), 50->15(Controv), 50->20(Loyal)")
    print("          50->25(Press), 50->30(Prof), 50->35(Sports), 50->40(Temp)")
    print("Also: 85->45 (Versatility)")

    personality_expected = [
        (50, 5, 'Adaptability'),
        (50, 10, 'Ambition'),
        (50, 15, 'Controversy'),
        (50, 20, 'Loyalty'),
        (50, 25, 'Pressure'),
        (50, 30, 'Professionalism'),
        (50, 35, 'Sportsmanship'),
        (50, 40, 'Temperament'),
        (85, 45, 'Versatility'),
    ]

    found = {}
    for offset in range(4300, 3900, -1):
        pos_b = base_pos - offset
        pos_m = pos10 - offset

        if pos_b < 0 or pos_m < 0:
            continue
        if pos_b >= len(base_data) or pos_m >= len(data10):
            continue

        old_val = base_data[pos_b]
        new_val = data10[pos_m]

        for old_exp, new_exp, name in personality_expected:
            if old_val == old_exp and new_val == new_exp:
                found[name] = -offset
                print(f"  {-offset:>+5}: {old_val} -> {new_val} ({name})")

    print(f"\nFound {len(found)}/9 personality attributes")

    # Also check around the new fitness location
    # Fitness is at -4080 to -4084
    # Nearby might be the personality block

    print("\n" + "="*80)
    print("BYTES AROUND FITNESS (-4095 to -4075)")
    print("="*80)

    print("\nBase values:")
    for offset in range(4095, 4075, -1):
        pos = base_pos - offset
        val = base_data[pos]
        if val % 5 == 0 and 5 <= val <= 100:
            print(f"  {-offset:>+5}: {val:>3} (in-game {val//5:>2})")
        elif val > 0:
            print(f"  {-offset:>+5}: {val:>3}")

    print("\nBrix10 values:")
    for offset in range(4095, 4075, -1):
        pos = pos10 - offset
        val = data10[pos]
        if val % 5 == 0 and 5 <= val <= 100:
            print(f"  {-offset:>+5}: {val:>3} (in-game {val//5:>2})")
        elif val > 0:
            print(f"  {-offset:>+5}: {val:>3}")


if __name__ == "__main__":
    main()
