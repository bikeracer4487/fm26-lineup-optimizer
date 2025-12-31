#!/usr/bin/env python3
"""
Just compare which offsets changed in Brix7 vs Brix9.
Focus on the -4200 to -4000 range where we expect player attributes.
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

    print(f"\nIsaac positions: Base={base_pos:,}, Brix7={pos7:,}, Brix9={pos9:,}")
    print(f"Shifts: Brix7={pos7-base_pos:+}, Brix9={pos9-base_pos:+}")

    # Focus on attribute area
    search_range = (-4200, -4000)

    # Find changes in each save
    brix7_changes = {}
    brix9_changes = {}

    for rel_offset in range(search_range[0], search_range[1]):
        base_val = base_data[base_pos + rel_offset]
        val7 = data7[pos7 + rel_offset]
        val9 = data9[pos9 + rel_offset]

        if base_val != val7:
            brix7_changes[rel_offset] = (base_val, val7)
        if base_val != val9:
            brix9_changes[rel_offset] = (base_val, val9)

    brix7_offsets = set(brix7_changes.keys())
    brix9_offsets = set(brix9_changes.keys())

    only_brix7 = brix7_offsets - brix9_offsets
    only_brix9 = brix9_offsets - brix7_offsets
    both = brix7_offsets & brix9_offsets

    print(f"\n" + "="*80)
    print(f"CHANGES IN RANGE {search_range}")
    print("="*80)
    print(f"\nBrix7-only changes (MENTAL ATTRIBUTES): {len(only_brix7)}")
    print(f"Brix9-only changes (POSITION FAMILIARITY): {len(only_brix9)}")
    print(f"Changed in BOTH: {len(both)}")

    print(f"\n--- BRIX7-ONLY (Mental Attributes) ---")
    for offset in sorted(only_brix7):
        base_val, mod_val = brix7_changes[offset]
        print(f"  {offset}: {base_val} → {mod_val} ({base_val/5:.0f} → {mod_val/5:.0f} ig)")

    print(f"\n--- BRIX9-ONLY (Position Familiarity) ---")
    for offset in sorted(only_brix9):
        base_val, mod_val = brix9_changes[offset]
        # Check if it looks like raw 0-20 or 0-100 scale
        if mod_val <= 20:
            print(f"  {offset}: {base_val} → {mod_val} (raw {mod_val})")
        else:
            print(f"  {offset}: {base_val} → {mod_val} ({base_val/5:.0f} → {mod_val/5:.0f} ig)")

    print(f"\n--- CHANGED IN BOTH (Need Investigation) ---")
    for offset in sorted(both):
        b7_base, b7_mod = brix7_changes[offset]
        b9_base, b9_mod = brix9_changes[offset]
        print(f"  {offset}: Base={b7_base}")
        print(f"         Brix7={b7_mod} ({b7_mod/5:.0f} ig)")
        print(f"         Brix9={b9_mod} (raw {b9_mod} or {b9_mod/5:.0f} ig)")

    # Key insight: If mental and position fam are at different offsets,
    # they should appear in different categories above
    print(f"\n" + "="*80)
    print("ANALYSIS")
    print("="*80)

    if only_brix7 and only_brix9:
        print(f"\n✓ There ARE offsets unique to each save:")
        print(f"  - {len(only_brix7)} offsets only changed in Brix7 (mental)")
        print(f"  - {len(only_brix9)} offsets only changed in Brix9 (position fam)")
        print(f"\nThis confirms mental attrs and position fam ARE at different offsets!")

    if both:
        print(f"\n⚠ {len(both)} offsets changed in BOTH saves.")
        print("  These could be:")
        print("  - Attributes that coincidentally have same values")
        print("  - Cascading changes from the editor")
        print("  - Structural metadata that changed")


if __name__ == "__main__":
    main()
