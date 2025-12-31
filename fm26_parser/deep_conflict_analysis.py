#!/usr/bin/env python3
"""
Deep analysis of the offset conflict.

Key question: Are Aggression and ST position at the SAME byte?

If at offset -4106 from Isaac:
- Base shows 75 (Aggression = 15 in-game, or original ST value?)
- Brix7 shows 5 (Aggression changed to 1)
- Brix9 shows 14 (ST changed to 14!)

This would mean: Either the attributes share a byte, OR the structure is dynamic.
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

    print("Loading all saves...")
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

    print("\n" + "="*90)
    print("DIRECT OFFSET COMPARISON")
    print("Comparing the SAME relative offset from each save's Isaac position")
    print("="*90)

    # Offsets of interest
    offsets_of_interest = [
        (-4106, "Aggression/ST?"),
        (-4108, "Bravery/AMC?"),
        (-4109, "Balance/AML?"),
        (-4110, "Dirtiness/MR?"),
        (-4112, "Jumping Reach/ML?"),
        (-4114, "Stamina/DR?"),
        (-4100, "Determination"),
        (-4118, "GK position"),
        (-4116, "DL position"),
    ]

    print(f"\n{'Offset':<10} {'Desc':<20} {'Base':<15} {'Brix7':<15} {'Brix9':<15}")
    print("-"*90)

    for offset, desc in offsets_of_interest:
        base_val = base_data[base_pos + offset]
        val7 = data7[pos7 + offset]
        val9 = data9[pos9 + offset]

        # Note what changed
        note_base = f"{base_val}"
        note7 = f"{val7}" + (" *CHANGED*" if val7 != base_val else "")
        note9 = f"{val9}" + (" *CHANGED*" if val9 != base_val else "")

        print(f"{offset:<10} {desc:<20} {note_base:<15} {note7:<15} {note9:<15}")

    # Now let's check: What were Isaac's ORIGINAL values?
    print("\n" + "="*90)
    print("ISAAC'S ORIGINAL VALUES (from Base save)")
    print("="*90)

    print("\nKnown from FM Editor before changes:")
    print("  Aggression: 15 (internal 75)")
    print("  ST position: 1 (internal 5 or raw 1?)")
    print("  AMC position: 20 (internal 100 or raw 20?)")
    print("")
    print("If ST and Aggression share offset -4106:")
    print("  - Base=75 could mean: Aggression=15, ST stored elsewhere")
    print("  - OR: Combined encoding somehow?")
    print("")
    print("Evidence from changes:")
    print("  - Brix7: Changed Aggression 15→1 at offset -4106 (75→5)")
    print("  - Brix9: Changed ST 1→14 - appears at -4106 as 14")

    # The smoking gun: What happens at -4106 in ALL saves?
    print("\n" + "="*90)
    print("THE KEY TEST: Check if Brix9's value 14 is actually ST")
    print("="*90)

    val_at_4106_base = base_data[base_pos - 4106]
    val_at_4106_brix7 = data7[pos7 - 4106]
    val_at_4106_brix9 = data9[pos9 - 4106]

    print(f"\nAt offset -4106 (relative to each Isaac):")
    print(f"  Base:  {val_at_4106_base} (Aggression=15 → internal 75)")
    print(f"  Brix7: {val_at_4106_brix7} (Aggression changed to 1 → internal 5)")
    print(f"  Brix9: {val_at_4106_brix9} (ST changed to 14...)")

    print("\n  Analysis:")
    if val_at_4106_brix9 == 14:
        print("  → Brix9 shows raw 14 at -4106, matching ST change!")
        print("  → This suggests position familiarity uses RAW 0-20 scale")
        print("  → And it DOES share the same byte as Aggression!")

    # Check what ST value was in Base and Brix7 (should be unchanged)
    print(f"\n  If -4106 is ST position fam:")
    print(f"    Base value 75 / 5 = 15 (but user said ST was 1?)")
    print(f"    Brix7 value 5 / 5 = 1 (matches original ST!)")
    print(f"    Brix9 value 14 = ST changed to 14 ✓")

    # Wait - this reveals something important!
    print("\n" + "="*90)
    print("THEORY: Could Aggression and ST be DIFFERENT in Base?")
    print("="*90)

    print("\nLet's check BOTH interpretations:")
    print("\nInterpretation 1: -4106 is Aggression only")
    print(f"  Base: {val_at_4106_base}/5 = {val_at_4106_base/5:.0f} (Aggression ✓)")
    print(f"  Brix7: {val_at_4106_brix7}/5 = {val_at_4106_brix7/5:.0f} (Changed Agg to 1 ✓)")
    print(f"  Brix9: {val_at_4106_brix9}/5 = {val_at_4106_brix9/5:.1f} (Should still be 15... ✗)")

    print("\nInterpretation 2: -4106 is ST position only")
    print(f"  Base: {val_at_4106_base}/5 = {val_at_4106_base/5:.0f} or raw {val_at_4106_base} (ST = 15 or 75?)")
    print(f"  Brix7: {val_at_4106_brix7} = 5 or 1 in-game (unchanged ST?)")
    print(f"  Brix9: {val_at_4106_brix9} = 14 raw (Changed ST to 14 ✓)")

    print("\nInterpretation 3: Different bytes for each save (shifted)")
    print("  Maybe the FM editor changes the byte position when editing?")

    # Let's look at the surrounding bytes for more context
    print("\n" + "="*90)
    print("SURROUNDING CONTEXT: Bytes around -4106")
    print("="*90)

    print(f"\n{'Offset':<8} {'Base':<8} {'Brix7':<8} {'Brix9':<8} {'Notes'}")
    print("-"*60)

    for offset in range(-4115, -4095):
        b = base_data[base_pos + offset]
        v7 = data7[pos7 + offset]
        v9 = data9[pos9 + offset]

        notes = []
        if v7 != b:
            notes.append(f"Brix7:{b}→{v7}")
        if v9 != b:
            notes.append(f"Brix9:{b}→{v9}")

        note_str = ", ".join(notes) if notes else ""
        marker = " ***" if notes else ""
        print(f"{offset:<8} {b:<8} {v7:<8} {v9:<8} {note_str}{marker}")

    # Final hypothesis
    print("\n" + "="*90)
    print("CONCLUSION")
    print("="*90)

    # Count changes in each save
    brix7_changes = []
    brix9_changes = []

    for offset in range(-4200, -4000):
        b = base_data[base_pos + offset]
        if data7[pos7 + offset] != b:
            brix7_changes.append(offset)
        if data9[pos9 + offset] != b:
            brix9_changes.append(offset)

    overlap = set(brix7_changes) & set(brix9_changes)

    print(f"\nBrix7 changes: {len(brix7_changes)} offsets")
    print(f"Brix9 changes: {len(brix9_changes)} offsets")
    print(f"Overlapping: {len(overlap)} offsets")

    if overlap:
        print(f"\nOverlapping offsets (both saves modified):")
        for off in sorted(overlap):
            b = base_data[base_pos + off]
            v7 = data7[pos7 + off]
            v9 = data9[pos9 + off]
            print(f"  {off}: Base={b}, Brix7={v7}, Brix9={v9}")


if __name__ == "__main__":
    main()
