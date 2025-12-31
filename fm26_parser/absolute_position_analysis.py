#!/usr/bin/env python3
"""
Compare using ABSOLUTE positions instead of relative offsets.

The 48-byte shift between Brix7 and Brix9 means "relative offset -4106"
refers to DIFFERENT absolute positions in each save.

If mental attrs and position fam are at different absolute positions,
they should NOT overlap when we align by absolute position.
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

    print(f"\nIsaac positions:")
    print(f"  Base:  {base_pos:,}")
    print(f"  Brix7: {pos7:,} (shift: {shift7:+})")
    print(f"  Brix9: {pos9:,} (shift: {shift9:+})")
    print(f"\nShift difference: {shift7 - shift9} bytes")

    print("\n" + "="*80)
    print("COMPARING BY ABSOLUTE POSITION")
    print("Using Base absolute positions as reference")
    print("="*80)

    # For each absolute position in Base's attribute area,
    # find the corresponding position in Brix7 and Brix9
    # (adjusted by their respective shifts)

    # Focus on area around attributes
    base_start = base_pos - 4200
    base_end = base_pos - 4000

    brix7_changes = {}  # absolute_pos -> (base_val, new_val)
    brix9_changes = {}

    for base_abs in range(base_start, base_end):
        base_rel = base_abs - base_pos  # Relative offset in Base

        # In Brix7, this same "field" would be at: base_abs + shift7
        brix7_abs = base_abs + shift7
        # In Brix9, this same "field" would be at: base_abs + shift9
        brix9_abs = base_abs + shift9

        base_val = base_data[base_abs]
        val7 = data7[brix7_abs] if 0 <= brix7_abs < len(data7) else None
        val9 = data9[brix9_abs] if 0 <= brix9_abs < len(data9) else None

        if val7 is not None and base_val != val7:
            brix7_changes[base_rel] = (base_val, val7)
        if val9 is not None and base_val != val9:
            brix9_changes[base_rel] = (base_val, val9)

    brix7_offsets = set(brix7_changes.keys())
    brix9_offsets = set(brix9_changes.keys())

    only_brix7 = brix7_offsets - brix9_offsets
    only_brix9 = brix9_offsets - brix7_offsets
    both = brix7_offsets & brix9_offsets

    print(f"\nUsing ABSOLUTE position alignment:")
    print(f"  Brix7-only changes (MENTAL): {len(only_brix7)}")
    print(f"  Brix9-only changes (POSITION FAM): {len(only_brix9)}")
    print(f"  Changed in BOTH: {len(both)}")

    if only_brix7:
        print(f"\n--- BRIX7-ONLY (Mental Attributes) ---")
        for offset in sorted(only_brix7):
            base_val, mod_val = brix7_changes[offset]
            print(f"  {offset}: {base_val} → {mod_val} ({base_val/5:.0f} → {mod_val/5:.0f} ig)")

    if only_brix9:
        print(f"\n--- BRIX9-ONLY (Position Familiarity) ---")
        for offset in sorted(only_brix9)[:30]:  # Show first 30
            base_val, mod_val = brix9_changes[offset]
            if mod_val <= 20:
                print(f"  {offset}: {base_val} → {mod_val} (raw {mod_val})")
            else:
                print(f"  {offset}: {base_val} → {mod_val}")
        if len(only_brix9) > 30:
            print(f"  ... and {len(only_brix9) - 30} more")

    if both:
        print(f"\n--- CHANGED IN BOTH (Overlap) ---")
        for offset in sorted(both):
            b7_base, b7_mod = brix7_changes[offset]
            b9_base, b9_mod = brix9_changes[offset]
            print(f"  {offset}: Base={b7_base}, Brix7={b7_mod}, Brix9={b9_mod}")

    print("\n" + "="*80)
    print("CONCLUSION")
    print("="*80)

    if only_brix7 and only_brix9 and len(both) == 0:
        print("""
✓ SUCCESS! When aligned by ABSOLUTE position:
  - Mental attributes (Brix7) and Position familiarity (Brix9)
    are at COMPLETELY DIFFERENT offsets!

  The apparent overlap in previous analysis was due to the 48-byte
  shift difference between saves. Using relative offsets from Isaac
  was comparing different absolute positions.

  CORRECT MAPPING:
  - Mental attributes: Use offsets from Base Isaac's position
  - Position familiarity: At different offsets (48 bytes shifted)
""")
    elif len(both) > 0:
        print(f"""
⚠ There are still {len(both)} overlapping offsets even with absolute alignment.
   This needs further investigation.
""")
    else:
        print("""
Unexpected result. Review the data.
""")


if __name__ == "__main__":
    main()
