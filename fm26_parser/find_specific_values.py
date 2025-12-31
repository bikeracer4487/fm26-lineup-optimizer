#!/usr/bin/env python3
"""
Find SPECIFIC value changes that the user made.

Instead of comparing all bytes, look for the exact value transitions:
- Brix7 Mental: Aggression 75→5 (15→1 ig), Bravery 75→15 (15→3 ig)
- Brix9 Position: ST ?→14, AMC ?→12, etc.

If these are at different offsets, we've found the real locations.
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


def find_value_change(base_data, base_pos, mod_data, mod_pos, expected_new, search_range):
    """Find offsets where value changed TO expected_new."""
    matches = []
    for rel_offset in range(search_range[0], search_range[1]):
        base_val = base_data[base_pos + rel_offset]
        mod_val = mod_data[mod_pos + rel_offset]
        if mod_val == expected_new and base_val != mod_val:
            matches.append((rel_offset, base_val, mod_val))
    return matches


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

    print(f"\nIsaac: Base={base_pos:,}, Brix7={pos7:,}, Brix9={pos9:,}")

    search_range = (-5000, 500)

    print("\n" + "="*80)
    print("BRIX7: Finding Aggression change (should be 75→5 or 15→1)")
    print("="*80)

    # Aggression was 15 (internal 75), changed to 1 (internal 5)
    agg_matches = find_value_change(base_data, base_pos, data7, pos7, 5, search_range)
    print(f"\nOffsets where value became 5 in Brix7:")
    for offset, old, new in agg_matches:
        ig_old = old / 5 if old > 20 else old
        print(f"  {offset}: {old} → {new} ({ig_old:.0f} → 1 ig)")

    print("\n" + "="*80)
    print("BRIX7: Finding Bravery change (should be 75→15 or 15→3)")
    print("="*80)

    # Bravery was 15 (internal 75), changed to 3 (internal 15)
    brav_matches = find_value_change(base_data, base_pos, data7, pos7, 15, search_range)
    print(f"\nOffsets where value became 15 in Brix7 (from different value):")
    for offset, old, new in brav_matches[:20]:  # Show first 20
        ig_old = old / 5 if old > 20 else old
        print(f"  {offset}: {old} → {new} ({ig_old:.0f} → 3 ig)")

    print("\n" + "="*80)
    print("BRIX9: Finding ST position change (should be ?→14)")
    print("="*80)

    # ST position was changed to 14 (raw)
    st_matches = find_value_change(base_data, base_pos, data9, pos9, 14, search_range)
    print(f"\nOffsets where value became 14 in Brix9:")
    for offset, old, new in st_matches:
        print(f"  {offset}: {old} → {new}")

    print("\n" + "="*80)
    print("BRIX9: Finding AMC position change (should be ?→12)")
    print("="*80)

    # AMC position was changed to 12 (raw)
    amc_matches = find_value_change(base_data, base_pos, data9, pos9, 12, search_range)
    print(f"\nOffsets where value became 12 in Brix9:")
    for offset, old, new in amc_matches[:20]:
        print(f"  {offset}: {old} → {new}")

    print("\n" + "="*80)
    print("KEY COMPARISON: Aggression vs ST Position")
    print("="*80)

    agg_offsets = {m[0] for m in agg_matches}
    st_offsets = {m[0] for m in st_matches}

    print(f"\nAggression (→5) found at offsets: {sorted(agg_offsets)}")
    print(f"ST Position (→14) found at offsets: {sorted(st_offsets)}")

    overlap = agg_offsets & st_offsets
    if overlap:
        print(f"\n⚠ OVERLAP at offsets: {sorted(overlap)}")
    else:
        print(f"\n✓ NO OVERLAP - These are different offsets!")

    # Check the specific offsets
    print("\n" + "="*80)
    print("DETAILED COMPARISON AT SUSPECT OFFSETS")
    print("="*80)

    suspect_offsets = [-4106, -4108, -4107, -4110, -4112, -4114]

    print(f"\n{'Offset':<10} {'Base':<8} {'Brix7':<8} {'Brix9':<8} {'Notes'}")
    print("-"*60)

    for offset in suspect_offsets:
        base_val = base_data[base_pos + offset]
        val7 = data7[pos7 + offset]
        val9 = data9[pos9 + offset]

        notes = []
        if val7 == 5 and base_val == 75:
            notes.append("Agg 15→1")
        if val7 == 15 and base_val == 75:
            notes.append("Brav 15→3")
        if val9 == 14:
            notes.append("ST→14?")
        if val9 == 12:
            notes.append("AMC→12?")

        note_str = ", ".join(notes) if notes else ""
        print(f"{offset:<10} {base_val:<8} {val7:<8} {val9:<8} {note_str}")


if __name__ == "__main__":
    main()
