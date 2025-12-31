#!/usr/bin/env python3
"""
Correct analysis: Find the ACTUAL offsets where changes occurred.

The game correctly reads back edited values, so mental attrs and position
familiarity MUST be stored at different locations. My previous analysis
must have methodological errors.

Approach:
1. For each modified save, find ALL bytes that changed from Base
2. Use the SAME relative offset calculation for fair comparison
3. Identify which offsets are unique to each category
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


def get_changes(base_data, base_pos, mod_data, mod_pos, offset_range):
    """Find all bytes that changed between base and modified save."""
    changes = {}
    for rel_offset in range(offset_range[0], offset_range[1]):
        base_val = base_data[base_pos + rel_offset]
        mod_val = mod_data[mod_pos + rel_offset]
        if base_val != mod_val:
            changes[rel_offset] = (base_val, mod_val)
    return changes


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

    print(f"\nIsaac positions:")
    print(f"  Base:  {base_pos:,}")
    print(f"  Brix7: {pos7:,} (shift: {pos7 - base_pos:+})")
    print(f"  Brix9: {pos9:,} (shift: {pos9 - base_pos:+})")

    # Find all changes in a wide range around Isaac
    search_range = (-5000, 500)

    print(f"\n" + "="*80)
    print(f"BRIX7 CHANGES (Mental Attributes)")
    print(f"Searching offsets {search_range[0]} to {search_range[1]} from Isaac")
    print("="*80)

    brix7_changes = get_changes(base_data, base_pos, data7, pos7, search_range)
    print(f"\nTotal changes: {len(brix7_changes)}")
    print(f"\n{'Offset':<10} {'Base':<8} {'Brix7':<8} {'Base IG':<10} {'Brix7 IG':<10}")
    print("-"*60)
    for offset in sorted(brix7_changes.keys()):
        base_val, mod_val = brix7_changes[offset]
        base_ig = base_val / 5 if base_val >= 5 else base_val
        mod_ig = mod_val / 5 if mod_val >= 5 else mod_val
        print(f"{offset:<10} {base_val:<8} {mod_val:<8} {base_ig:<10.1f} {mod_ig:<10.1f}")

    print(f"\n" + "="*80)
    print(f"BRIX9 CHANGES (Position Familiarity)")
    print(f"Searching offsets {search_range[0]} to {search_range[1]} from Isaac")
    print("="*80)

    brix9_changes = get_changes(base_data, base_pos, data9, pos9, search_range)
    print(f"\nTotal changes: {len(brix9_changes)}")
    print(f"\n{'Offset':<10} {'Base':<8} {'Brix9':<8} {'Base IG':<10} {'Brix9 IG':<10}")
    print("-"*60)
    for offset in sorted(brix9_changes.keys()):
        base_val, mod_val = brix9_changes[offset]
        base_ig = base_val / 5 if base_val >= 5 else base_val
        mod_ig = mod_val / 5 if mod_val >= 5 else mod_val
        print(f"{offset:<10} {base_val:<8} {mod_val:<8} {base_ig:<10.1f} {mod_ig:<10.1f}")

    # Key comparison: Which offsets are UNIQUE to each save?
    print(f"\n" + "="*80)
    print("OFFSET COMPARISON")
    print("="*80)

    brix7_offsets = set(brix7_changes.keys())
    brix9_offsets = set(brix9_changes.keys())

    only_brix7 = brix7_offsets - brix9_offsets
    only_brix9 = brix9_offsets - brix7_offsets
    both = brix7_offsets & brix9_offsets

    print(f"\nOffsets changed ONLY in Brix7 (mental): {len(only_brix7)}")
    print(f"Offsets changed ONLY in Brix9 (position): {len(only_brix9)}")
    print(f"Offsets changed in BOTH: {len(both)}")

    if only_brix7:
        print(f"\n--- Brix7-only offsets (these are mental attributes) ---")
        for offset in sorted(only_brix7):
            base_val, mod_val = brix7_changes[offset]
            print(f"  {offset}: {base_val} → {mod_val} ({base_val/5:.0f} → {mod_val/5:.0f} ig)")

    if only_brix9:
        print(f"\n--- Brix9-only offsets (these are position familiarity) ---")
        for offset in sorted(only_brix9):
            base_val, mod_val = brix9_changes[offset]
            # Position fam might be raw 0-20
            print(f"  {offset}: {base_val} → {mod_val}")

    if both:
        print(f"\n--- Offsets changed in BOTH saves (needs investigation) ---")
        for offset in sorted(both):
            b7_base, b7_mod = brix7_changes[offset]
            b9_base, b9_mod = brix9_changes[offset]
            print(f"  {offset}: Base={b7_base}, Brix7={b7_mod}, Brix9={b9_mod}")


if __name__ == "__main__":
    main()
