#!/usr/bin/env python3
"""
Investigate the offset conflicts between position familiarity and other attributes.
A single byte can't be both Aggression AND Striker familiarity.
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

    print("Loading ALL saves for comparison...")
    saves = {}

    for save_name in ['Brixham.fm', 'Brixham6.fm', 'Brixham7.fm', 'Brixham8.fm', 'Brixham9.fm', 'Brixham10.fm']:
        dec = FM26Decompressor(base / save_name)
        dec.load()
        data = dec.decompress_main_database()
        pos = find_string_position(data, name)
        saves[save_name] = (data, pos)
        print(f"  {save_name}: Isaac at {pos:,}")

    base_data, base_pos = saves['Brixham.fm']

    # Conflicting offsets to investigate
    conflicts = [
        (-4103, 'DC (pos) vs Injury Proneness (phys)'),
        (-4106, 'ST (pos) vs Aggression (mental)'),
        (-4108, 'AMC (pos) vs Bravery (mental)'),
        (-4109, 'AML (pos) vs Balance (phys)'),
        (-4110, 'MR (pos) vs Dirtiness (mental)'),
        (-4112, 'ML (pos) vs Jumping Reach (phys)'),
        (-4114, 'DR (pos) vs Stamina (phys)'),
    ]

    print("\n" + "="*100)
    print("INVESTIGATING OFFSET CONFLICTS")
    print("="*100)
    print("\nExpected changes by save:")
    print("  Brix6: Technical attrs")
    print("  Brix7: Mental attrs (Aggression 15→1, Bravery 15→3)")
    print("  Brix8: Physical attrs (Balance 9→3, Jumping Reach 13→4, Stamina 9→6)")
    print("  Brix9: Position familiarity (ST 1→14, AMC 20→12, etc.)")
    print("  Brix10: Personality, feet, fitness")

    print("\n" + "-"*100)
    print(f"{'Offset':<10} {'Conflict':<35} {'Base':<8} {'Brix6':<8} {'Brix7':<8} {'Brix8':<8} {'Brix9':<8} {'Brix10':<8}")
    print("-"*100)

    for offset, desc in conflicts:
        values = []
        for save_name in ['Brixham.fm', 'Brixham6.fm', 'Brixham7.fm', 'Brixham8.fm', 'Brixham9.fm', 'Brixham10.fm']:
            data, pos = saves[save_name]
            val = data[pos + offset]
            values.append(val)

        # Format with change indicators
        row = f"{offset:<10} {desc:<35}"
        for i, val in enumerate(values):
            if i > 0 and val != values[0]:
                row += f" *{val:<6}"  # Mark changes with *
            else:
                row += f"  {val:<6}"
        print(row)

    # Now let's look at what ACTUALLY changed in each save
    print("\n" + "="*100)
    print("WHAT ACTUALLY CHANGED IN EACH SAVE (offsets -4120 to -4095)")
    print("="*100)

    for save_name in ['Brixham6.fm', 'Brixham7.fm', 'Brixham8.fm', 'Brixham9.fm', 'Brixham10.fm']:
        data, pos = saves[save_name]
        print(f"\n{save_name} changes from Base:")

        changes = []
        for offset in range(-4120, -4095):
            base_val = base_data[base_pos + offset]
            mod_val = data[pos + offset]
            if base_val != mod_val:
                changes.append((offset, base_val, mod_val))

        if changes:
            for off, old, new in changes:
                # Annotate with possible meaning
                note = ""
                if old % 5 == 0 and new % 5 == 0 and 5 <= old <= 100 and 5 <= new <= 100:
                    note = f" (attr: {old//5} → {new//5})"
                elif 1 <= new <= 20:
                    note = f" (raw: {new})"
                print(f"    {off}: {old:>3} → {new:<3}{note}")
        else:
            print("    No changes in this range")

    # The key insight: Brix7 and Brix9 should have changed DIFFERENT bytes
    # If they both show changes at the same offset, something is wrong
    print("\n" + "="*100)
    print("KEY TEST: Do Brix7 (mental) and Brix9 (position) change the SAME bytes?")
    print("="*100)

    data7, pos7 = saves['Brixham7.fm']
    data9, pos9 = saves['Brixham9.fm']

    brix7_changes = set()
    brix9_changes = set()

    for offset in range(-5000, 0):
        base_val = base_data[base_pos + offset]

        val7 = data7[pos7 + offset]
        val9 = data9[pos9 + offset]

        if base_val != val7:
            brix7_changes.add(offset)
        if base_val != val9:
            brix9_changes.add(offset)

    overlap = brix7_changes & brix9_changes
    print(f"\nBrix7 changed {len(brix7_changes)} bytes")
    print(f"Brix9 changed {len(brix9_changes)} bytes")
    print(f"Overlap (both changed same offset): {len(overlap)} bytes")

    if overlap:
        print("\nOverlapping changes (THIS SHOULDN'T HAPPEN):")
        for off in sorted(overlap):
            base_val = base_data[base_pos + off]
            val7 = data7[pos7 + off]
            val9 = data9[pos9 + off]
            print(f"  {off}: Base={base_val}, Brix7={val7}, Brix9={val9}")
    else:
        print("\nNo overlap - Brix7 and Brix9 changed completely different bytes. Good!")

    # Let's also check the ACTUAL position of Isaac in each save
    print("\n" + "="*100)
    print("ISAAC'S POSITION IN EACH SAVE")
    print("="*100)

    positions = []
    for save_name in ['Brixham.fm', 'Brixham6.fm', 'Brixham7.fm', 'Brixham8.fm', 'Brixham9.fm', 'Brixham10.fm']:
        data, pos = saves[save_name]
        positions.append((save_name, pos))

    base_p = positions[0][1]
    for save_name, pos in positions:
        shift = pos - base_p
        print(f"  {save_name}: {pos:,} (shift: {shift:+})")


if __name__ == "__main__":
    main()
