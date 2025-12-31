#!/usr/bin/env python3
"""
Map Position Familiarity attributes from Brix9.

User's changes in Brix9:
- GK: 1 → 1 (no change expected)
- DL: 1 → 2
- DC: 20 → 3
- DR: 1 → 4
- WBL: 1 → 5
- DM: 20 → 6
- WBR: 1 → 7
- ML: 1 → 8
- MC: 20 → 9
- MR: 1 → 10
- AML: 1 → 11
- AMC: 20 → 12
- AMR: 1 → 13
- ST: 1 → 14

Internal scale: 1-20 in-game = 5-100 internal
So we're looking for:
- 5 → 5 (GK, no change)
- 5 → 10 (DL: 1→2)
- 100 → 15 (DC: 20→3)
- 5 → 20 (DR: 1→4)
- etc.
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

    dec9 = FM26Decompressor(base / "Brixham9.fm")
    dec9.load()
    data9 = dec9.decompress_main_database()
    pos9 = find_string_position(data9, name)

    shift = pos9 - base_pos
    print(f"Base: Isaac at {base_pos:,}")
    print(f"Brix9: Isaac at {pos9:,}")
    print(f"Shift: {shift:+}")
    print(f"Base size: {len(base_data):,}")
    print(f"Brix9 size: {len(data9):,}")
    print(f"Size diff: {len(data9) - len(base_data):+}")

    # Expected position familiarity changes (in-game → internal)
    # Original → New (in-game) → Internal change
    position_changes = [
        ('GK', 1, 1, 5, 5),      # No change
        ('DL', 1, 2, 5, 10),
        ('DC', 20, 3, 100, 15),
        ('DR', 1, 4, 5, 20),
        ('WBL', 1, 5, 5, 25),
        ('DM', 20, 6, 100, 30),
        ('WBR', 1, 7, 5, 35),
        ('ML', 1, 8, 5, 40),
        ('MC', 20, 9, 100, 45),
        ('MR', 1, 10, 5, 50),
        ('AML', 1, 11, 5, 55),
        ('AMC', 20, 12, 100, 60),
        ('AMR', 1, 13, 5, 65),
        ('ST', 1, 14, 5, 70),
    ]

    print("\n" + "="*80)
    print("SEARCHING FOR POSITION FAMILIARITY CHANGES")
    print("Using same offset from each Isaac position")
    print("="*80)

    # First, find ALL changes in the typical attribute range
    print("\nAll changes from -5000 to -3500:")
    all_changes = []
    for offset in range(5000, 3500, -1):
        base_check = base_pos - offset
        mod_check = pos9 - offset

        if base_check < 0 or mod_check < 0:
            continue
        if base_check >= len(base_data) or mod_check >= len(data9):
            continue

        base_val = base_data[base_check]
        mod_val = data9[mod_check]

        if base_val != mod_val:
            all_changes.append((-offset, base_val, mod_val))

    print(f"Found {len(all_changes)} changes")
    for off, base_val, mod_val in all_changes:
        # Check if this matches expected position change
        matched = None
        for pos_name, old_ig, new_ig, old_int, new_int in position_changes:
            if base_val == old_int and mod_val == new_int:
                matched = pos_name
                break

        note = f"  ** {matched} **" if matched else ""
        print(f"  {off:>+5}: {base_val:>3} -> {mod_val:<3}{note}")

    # Also search for position values specifically
    print("\n" + "="*80)
    print("SEARCHING FOR SPECIFIC POSITION CHANGES")
    print("="*80)

    found_positions = {}

    for pos_name, old_ig, new_ig, old_int, new_int in position_changes:
        if old_int == new_int:
            print(f"  {pos_name}: No change expected (both {old_int})")
            continue

        for offset in range(5000, 3500, -1):
            base_check = base_pos - offset
            mod_check = pos9 - offset

            if base_check < 0 or mod_check < 0:
                continue
            if base_check >= len(base_data) or mod_check >= len(data9):
                continue

            if base_data[base_check] == old_int and data9[mod_check] == new_int:
                found_positions[pos_name] = (-offset, old_int, new_int)
                print(f"  {pos_name:6}: offset {-offset:>+5} ({old_int} -> {new_int})")
                break
        else:
            print(f"  {pos_name:6}: NOT FOUND ({old_int} -> {new_int})")

    print(f"\nTotal found: {len(found_positions)}/13 (excluding GK no-change)")

    # Maybe position familiarity uses a different shift?
    print("\n" + "="*80)
    print("TRYING DIFFERENT ALIGNMENT SHIFTS")
    print("="*80)

    for test_shift in range(0, 600):
        matches = 0
        for pos_name, old_ig, new_ig, old_int, new_int in position_changes:
            if old_int == new_int:
                continue
            for offset in range(5000, 3500, -1):
                base_check = base_pos - offset
                mod_check = base_check + test_shift

                if base_check < 0 or mod_check < 0:
                    continue
                if base_check >= len(base_data) or mod_check >= len(data9):
                    continue

                if base_data[base_check] == old_int and data9[mod_check] == new_int:
                    matches += 1
                    break

        if matches >= 5:
            print(f"  Shift +{test_shift}: {matches} position matches")

    # Check if position familiarity might be at positive offsets like personality
    print("\n" + "="*80)
    print("CHECKING POSITIVE OFFSETS (like personality)")
    print("="*80)

    for offset in range(0, 200):
        base_check = base_pos + offset
        mod_check = pos9 + offset

        if base_check >= len(base_data) or mod_check >= len(data9):
            continue

        base_val = base_data[base_check]
        mod_val = data9[mod_check]

        if base_val != mod_val:
            # Check if matches position change
            for pos_name, old_ig, new_ig, old_int, new_int in position_changes:
                if base_val == old_int and mod_val == new_int:
                    print(f"  +{offset}: {base_val} -> {mod_val}  ** {pos_name} **")
                    break
            else:
                # Also check raw 0-20 scale
                for pos_name, old_ig, new_ig, old_int, new_int in position_changes:
                    if base_val == old_ig and mod_val == new_ig:
                        print(f"  +{offset}: {base_val} -> {mod_val}  ** {pos_name} (raw scale) **")
                        break
                else:
                    print(f"  +{offset}: {base_val} -> {mod_val}")

    # What if position is stored with 0-20 raw scale?
    print("\n" + "="*80)
    print("CHECKING 0-20 RAW SCALE FOR POSITIONS")
    print("Looking for: 1→2, 20→3, 1→4, etc.")
    print("="*80)

    raw_position_changes = [
        ('DL', 1, 2),
        ('DC', 20, 3),
        ('DR', 1, 4),
        ('WBL', 1, 5),
        ('DM', 20, 6),
        ('WBR', 1, 7),
        ('ML', 1, 8),
        ('MC', 20, 9),
        ('MR', 1, 10),
        ('AML', 1, 11),
        ('AMC', 20, 12),
        ('AMR', 1, 13),
        ('ST', 1, 14),
    ]

    for offset in range(5000, 0, -1):
        base_check = base_pos - offset
        mod_check = pos9 - offset

        if base_check < 0 or mod_check < 0:
            continue
        if base_check >= len(base_data) or mod_check >= len(data9):
            continue

        base_val = base_data[base_check]
        mod_val = data9[mod_check]

        for pos_name, old_raw, new_raw in raw_position_changes:
            if base_val == old_raw and mod_val == new_raw:
                print(f"  offset {-offset:>+5}: {base_val} -> {mod_val}  ** {pos_name} (raw 0-20) **")


if __name__ == "__main__":
    main()
