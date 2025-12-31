#!/usr/bin/env python3
"""
Confirm the 48-byte structural shift theory.

In Brix9, attributes are shifted +48 bytes compared to Base/Brix7.
So:
- Aggression: -4106 in Base/Brix7, -4058 in Brix9
- ST Position: -4154 in Base/Brix7, -4106 in Brix9
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
    saves = {}
    for save_name in ['Brixham.fm', 'Brixham7.fm', 'Brixham9.fm']:
        dec = FM26Decompressor(base / save_name)
        dec.load()
        data = dec.decompress_main_database()
        pos = find_string_position(data, name)
        saves[save_name] = (data, pos)
        print(f"  {save_name}: Isaac at {pos:,}")

    base_data, base_pos = saves['Brixham.fm']
    data7, pos7 = saves['Brixham7.fm']
    data9, pos9 = saves['Brixham9.fm']

    print("\n" + "="*80)
    print("THEORY: Brix9 has +48 byte structural shift from Base/Brix7")
    print("="*80)

    # Test: Read the SAME logical attribute from each save
    # using adjusted offsets for Brix9

    print("\n--- AGGRESSION (should be 15 in Base/Brix9, 1 in Brix7) ---")
    print(f"  Base at -4106:  {base_data[base_pos - 4106]} → {base_data[base_pos - 4106]/5:.0f} ig")
    print(f"  Brix7 at -4106: {data7[pos7 - 4106]} → {data7[pos7 - 4106]/5:.0f} ig (changed to 1)")
    print(f"  Brix9 at -4058: {data9[pos9 - 4058]} → {data9[pos9 - 4058]/5:.0f} ig (should be 15)")

    print("\n--- BRAVERY (should be 15 in Base/Brix9, 3 in Brix7) ---")
    print(f"  Base at -4108:  {base_data[base_pos - 4108]} → {base_data[base_pos - 4108]/5:.0f} ig")
    print(f"  Brix7 at -4108: {data7[pos7 - 4108]} → {data7[pos7 - 4108]/5:.0f} ig (changed to 3)")
    print(f"  Brix9 at -4060: {data9[pos9 - 4060]} → {data9[pos9 - 4060]/5:.0f} ig (should be 15)")

    print("\n--- ST POSITION (should be 1 in Base/Brix7, 14 in Brix9) ---")
    # If ST is at -4106 in Brix9, it would be at -4106-48 = -4154 in Base/Brix7
    print(f"  Base at -4154:  {base_data[base_pos - 4154]} (raw, should be ~1 or 5)")
    print(f"  Brix7 at -4154: {data7[pos7 - 4154]} (raw, should be ~1 or 5)")
    print(f"  Brix9 at -4106: {data9[pos9 - 4106]} (raw, changed to 14)")

    print("\n--- AMC POSITION (should be 20 in Base/Brix7, 12 in Brix9) ---")
    # AMC in Brix9 is at -4108, so in Base/Brix7 it's at -4108-48 = -4156
    print(f"  Base at -4156:  {base_data[base_pos - 4156]} (raw)")
    print(f"  Brix7 at -4156: {data7[pos7 - 4156]} (raw)")
    print(f"  Brix9 at -4108: {data9[pos9 - 4108]} (raw, changed to 12)")

    print("\n" + "="*80)
    print("MAPPING TABLE: Attribute offsets in each save layout")
    print("="*80)

    # Apply the +48 shift theory to map all confirmed mental attributes
    mental_attrs = [
        ("Aggression", -4106, 15, 1),   # (name, base_offset, base_val, brix7_val)
        ("Bravery", -4108, 15, 3),
        ("Determination", -4100, 12, 8),
        ("Off The Ball", -4145, 5, 13),
        ("Positioning", -4131, 14, 15),
    ]

    print("\nMENTAL ATTRIBUTES:")
    print(f"{'Attribute':<15} {'Base/Brix7 Offset':<18} {'Brix9 Offset':<15} {'Base':<8} {'Brix7':<8} {'Brix9':<8}")
    print("-"*80)

    for name, base_offset, expected_base, expected_b7 in mental_attrs:
        brix9_offset = base_offset + 48  # Apply shift

        base_val = base_data[base_pos + base_offset]
        val7 = data7[pos7 + base_offset]
        val9 = data9[pos9 + brix9_offset]

        base_ig = base_val / 5
        val7_ig = val7 / 5
        val9_ig = val9 / 5

        check_b = "✓" if int(base_ig) == expected_base else "✗"
        check_7 = "✓" if int(val7_ig) == expected_b7 else "✗"
        check_9 = "✓" if int(val9_ig) == expected_base else "✗"  # Should be unchanged in Brix9

        print(f"{name:<15} {base_offset:<18} {brix9_offset:<15} {base_ig:.0f} {check_b}    {val7_ig:.0f} {check_7}    {val9_ig:.0f} {check_9}")

    # Now map position familiarity (shifted -48 in Base/Brix7 relative to Brix9)
    print("\nPOSITION FAMILIARITY:")
    print("(Using Brix9 offsets as reference, Base/Brix7 shifted by -48)")
    print(f"{'Position':<8} {'Brix9 Offset':<15} {'Base/Brix7 Offset':<18} {'Base':<8} {'Brix7':<8} {'Brix9':<8}")
    print("-"*80)

    # Known position fam offsets from Brix9 (where changes were found)
    position_fam = [
        ("GK", -4118, 1),    # (name, brix9_offset, expected_brix9_value)
        ("ST", -4106, 14),
        ("AMC", -4108, 12),
        ("AMR", -4107, 13),
        ("AML", -4109, 11),
        ("MR", -4110, 10),
        ("MC", -4111, 9),
        ("ML", -4112, 8),
        ("WBR", -4113, 7),
        ("DR", -4114, 4),
    ]

    for name, brix9_offset, expected_b9 in position_fam:
        base_offset = brix9_offset - 48  # Shift back for Base/Brix7

        # Check if offset is in valid range
        if base_pos + base_offset < 0:
            continue

        base_val = base_data[base_pos + base_offset]
        val7 = data7[pos7 + base_offset]
        val9 = data9[pos9 + brix9_offset]

        # Position fam in Brix9 is raw 0-20, but Base/Brix7 might be 0-100 scale
        check_9 = "✓" if val9 == expected_b9 else "✗"

        print(f"{name:<8} {brix9_offset:<15} {base_offset:<18} {base_val:<8} {val7:<8} {val9:<3} {check_9}")


if __name__ == "__main__":
    main()
