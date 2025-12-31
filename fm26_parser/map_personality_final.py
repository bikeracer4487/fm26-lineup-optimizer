#!/usr/bin/env python3
"""
CONFIRMED: Personality is stored at POSITIVE offsets from name in raw 0-20 scale!

Map the exact offsets for all personality attributes and Versatility.
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

    # Expected personality changes (user provided):
    # Adaptability: 10 → 1
    # Ambition: 10 → 2
    # Controversy: 10 → 3
    # Loyalty: 10 → 4
    # Pressure: 10 → 5
    # Professionalism: 10 → 6
    # Sportsmanship: 10 → 7
    # Temperament: 10 → 8
    # Versatility: 17 → 9

    print("\n" + "="*80)
    print("PERSONALITY ATTRIBUTE MAPPING (0-20 raw scale)")
    print("="*80)

    # Map the personality values we found
    personality_mapping = {
        1: 'Adaptability',
        2: 'Ambition',
        3: 'Controversy',
        4: 'Loyalty',
        5: 'Pressure',
        6: 'Professionalism',
        7: 'Sportsmanship',
        8: 'Temperament',
        9: 'Versatility',
    }

    # Check +0 to +100 to find all personality attributes
    found_personality = {}
    found_versatility = None

    print("\nScanning positive offsets +0 to +100:")
    for offset in range(0, 100):
        base_check = base_pos + offset
        mod_check = pos10 + offset

        if base_check >= len(base_data) or mod_check >= len(data10):
            continue

        base_val = base_data[base_check]
        mod_val = data10[mod_check]

        if base_val != mod_val:
            # Check if this is a personality change
            if base_val == 10 and mod_val in personality_mapping:
                attr_name = personality_mapping[mod_val]
                found_personality[attr_name] = (offset, base_val, mod_val)
                print(f"  +{offset:>3}: {base_val:>2} -> {mod_val:<2}  ** {attr_name} **")
            # Check for Versatility (17 -> 9)
            elif base_val == 17 and mod_val == 9:
                found_versatility = (offset, base_val, mod_val)
                print(f"  +{offset:>3}: {base_val:>2} -> {mod_val:<2}  ** Versatility **")
            else:
                print(f"  +{offset:>3}: {base_val:>2} -> {mod_val:<2}")

    print("\n" + "="*80)
    print("FINAL PERSONALITY ATTRIBUTE OFFSETS")
    print("(All from player name position, raw 0-20 scale)")
    print("="*80)

    for attr_name in ['Adaptability', 'Ambition', 'Controversy', 'Loyalty',
                      'Pressure', 'Professionalism', 'Sportsmanship', 'Temperament']:
        if attr_name in found_personality:
            offset, base_val, mod_val = found_personality[attr_name]
            print(f"  {attr_name:20}: offset +{offset:>3} ({base_val} -> {mod_val})")
        else:
            print(f"  {attr_name:20}: NOT FOUND")

    if found_versatility:
        offset, base_val, mod_val = found_versatility
        print(f"  {'Versatility':20}: offset +{offset:>3} ({base_val} -> {mod_val})")
    else:
        print(f"  {'Versatility':20}: NOT FOUND")

    print(f"\nTotal mapped: {len(found_personality) + (1 if found_versatility else 0)}/9")

    # Show the raw bytes around the personality area for context
    print("\n" + "="*80)
    print("RAW BYTES +30 to +60 (personality area)")
    print("="*80)
    print("\nBase values:")
    for offset in range(30, 60):
        val = base_data[base_pos + offset]
        print(f"  +{offset}: {val:>3}", end="")
        if (offset + 1) % 10 == 0:
            print()
    print()

    print("\nBrix10 values:")
    for offset in range(30, 60):
        val = data10[pos10 + offset]
        print(f"  +{offset}: {val:>3}", end="")
        if (offset + 1) % 10 == 0:
            print()
    print()

    # Also check what's at -4102 (the 84->45 change we saw)
    print("\n" + "="*80)
    print("CHECKING THE -4102 CHANGE (84 -> 45)")
    print("="*80)
    print("This might be related to Versatility or another hidden attribute")
    base_val = base_data[base_pos - 4102]
    mod_val = data10[pos10 - 4102]
    print(f"  -4102: {base_val} -> {mod_val}")
    print(f"  Base/5 = {base_val/5}, Mod/5 = {mod_val/5}")
    print(f"  If 0-100 scale: {base_val//5} -> {mod_val//5} in-game")


if __name__ == "__main__":
    main()
