#!/usr/bin/env python3
"""
Resolve the offset conflicts by properly accounting for different shifts.

Key insight:
- Brix6/7/8/10 have shift +480 from Base
- Brix9 has shift +432 from Base (48 bytes different!)

When using relative offsets from Isaac's position, we're comparing DIFFERENT
absolute positions in Brix9 vs other saves.
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
    shift_diff = shift7 - shift9  # +48

    print(f"Base Isaac: {base_pos:,}")
    print(f"Brix7 Isaac: {pos7:,} (shift: {shift7:+})")
    print(f"Brix9 Isaac: {pos9:,} (shift: {shift9:+})")
    print(f"Shift difference: {shift_diff} bytes")

    print("\n" + "="*80)
    print("THE ACTUAL SITUATION")
    print("="*80)

    # Aggression in Brix7 at offset -4106
    # Let's find the ABSOLUTE position of Aggression
    aggression_relative_offset = -4106
    aggression_absolute_base = base_pos + aggression_relative_offset

    print(f"\nAGGRESSION (from Brix7 analysis):")
    print(f"  Relative offset from Isaac: {aggression_relative_offset}")
    print(f"  Absolute position in Base: {aggression_absolute_base:,}")

    # What's at that absolute position in each save?
    # Accounting for the shift properly
    val_base = base_data[aggression_absolute_base]
    val_7 = data7[aggression_absolute_base + shift7]
    val_9 = data9[aggression_absolute_base + shift9]

    print(f"  Value in Base: {val_base} ({val_base//5} in-game)")
    print(f"  Value in Brix7: {val_7} ({val_7//5} in-game) - CHANGED (Aggression 15→1)")
    print(f"  Value in Brix9: {val_9} ({val_9//5} in-game) - Should be unchanged")

    # Now let's find where position familiarity ACTUALLY is in Brix9
    # If the user changed ST to 14 (raw), we need to find where 14 appears
    print("\n" + "="*80)
    print("FINDING POSITION FAMILIARITY IN BRIX9 (correctly)")
    print("="*80)

    # Position familiarity in Brix9 - find changes from Base
    # Using proper alignment (same absolute position + shift9)
    print("\nSearching for position fam changes using ABSOLUTE positions:")

    # The user's changes for position familiarity:
    # ST: 1→14 (raw), so internal 5→70 or just raw 14
    # If it's raw 0-20 scale, we look for byte that changed to 14

    st_found = []
    for base_offset in range(-5000, 0):
        base_abs = base_pos + base_offset
        brix9_abs = base_abs + shift9  # Correct alignment!

        if brix9_abs < 0 or brix9_abs >= len(data9):
            continue

        base_val = base_data[base_abs]
        brix9_val = data9[brix9_abs]

        # Look for ST: original familiarity 1 (=5 internal or raw 1), changed to 14
        if brix9_val == 14:
            # Could be ST if base was 5 (0-100 scale) or 1 (raw scale)
            if base_val in [1, 5]:
                st_found.append((base_offset, base_val, brix9_val))

    print(f"\nPositions where value became 14 (ST familiarity):")
    print(f"  Found {len(st_found)} candidates")
    for off, old, new in st_found[:10]:
        print(f"    Base offset {off}: {old} → {new}")

    # Let's map ALL position familiarity using correct alignment
    print("\n" + "="*80)
    print("CORRECT POSITION FAMILIARITY MAPPING")
    print("Using absolute positions with proper shift")
    print("="*80)

    # Expected changes (in-game values): GK 1→1, DL 1→2, DC 20→3, DR 1→4, etc.
    # Internal scale: multiply by 5
    # Or if raw 0-20: use as-is
    position_changes = [
        ('GK', 1, 1),   # no change
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

    print("\nSearching for each position change:")
    found_positions = {}

    for pos_name, old_ig, new_ig in position_changes:
        if old_ig == new_ig:
            print(f"  {pos_name}: No change expected")
            continue

        # Try both scales
        # 0-100 scale: old_int = old_ig * 5, new_int = new_ig * 5
        # 0-20 raw: old_int = old_ig, new_int = new_ig
        old_100 = old_ig * 5
        new_100 = new_ig * 5

        for base_offset in range(-4200, -4000):
            base_abs = base_pos + base_offset
            brix9_abs = base_abs + shift9

            if brix9_abs < 0 or brix9_abs >= len(data9):
                continue

            base_val = base_data[base_abs]
            brix9_val = data9[brix9_abs]

            # Check 0-100 scale
            if base_val == old_100 and brix9_val == new_100:
                found_positions[pos_name] = (base_offset, '0-100', old_100, new_100)
                print(f"  {pos_name}: offset {base_offset} (0-100 scale: {old_100}→{new_100})")
                break
            # Check raw scale
            elif base_val == old_ig and brix9_val == new_ig:
                found_positions[pos_name] = (base_offset, 'raw', old_ig, new_ig)
                print(f"  {pos_name}: offset {base_offset} (raw scale: {old_ig}→{new_ig})")
                break
        else:
            print(f"  {pos_name}: NOT FOUND ({old_ig}→{new_ig})")

    print(f"\nTotal positions found: {len(found_positions)}/13")

    # Now verify mental attributes in Brix7 are SEPARATE from position familiarity
    print("\n" + "="*80)
    print("VERIFYING MENTAL ATTRIBUTES (Brix7) ARE SEPARATE")
    print("="*80)

    # Mental attributes we found earlier
    mental_attrs = {
        'Aggression': -4106,
        'Bravery': -4108,
        'Determination': -4100,
    }

    print("\nMental attribute offsets (from Base perspective):")
    for attr_name, offset in mental_attrs.items():
        base_abs = base_pos + offset
        base_val = base_data[base_abs]
        brix7_val = data7[base_abs + shift7]

        print(f"  {attr_name}: offset {offset}, Base={base_val} ({base_val//5}), Brix7={brix7_val} ({brix7_val//5})")

        # Check if this offset conflicts with position familiarity
        if offset in [v[0] for v in found_positions.values()]:
            conflict_pos = [k for k, v in found_positions.items() if v[0] == offset][0]
            print(f"    *** CONFLICT with {conflict_pos}! ***")
        else:
            print(f"    No conflict with position familiarity")


if __name__ == "__main__":
    main()
