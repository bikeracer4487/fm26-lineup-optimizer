#!/usr/bin/env python3
"""
Find what ACTUALLY changed between Brix2 and Brix3.

Something's off - we expected Acceleration to change from 65 to 100,
but the calculated offset shows the original values.

Let's find ALL differences between Brix2 and Brix3 near Isaac's record.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor


def find_string_position(data: bytes, target: str) -> int:
    """Find first occurrence of a length-prefixed string."""
    target_bytes = target.encode('utf-8')
    pattern = len(target_bytes).to_bytes(4, 'little') + target_bytes
    pos = data.find(pattern)
    return pos + 4 if pos != -1 else -1


def main():
    base = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")

    print("Loading saves...")

    dec2 = FM26Decompressor(base / "Brixham2.fm")
    dec2.load()
    data2 = dec2.decompress_main_database()

    dec3 = FM26Decompressor(base / "Brixham3.fm")
    dec3.load()
    data3 = dec3.decompress_main_database()

    print(f"\nSizes: Brix2={len(data2):,}, Brix3={len(data3):,}")
    print(f"Size difference: {len(data3) - len(data2):+d} bytes")

    # Find Isaac James Smith in both saves
    name = "Isaac James Smith"
    isaac_pos_2 = find_string_position(data2, name)
    isaac_pos_3 = find_string_position(data3, name)

    print(f"\n{name} positions:")
    print(f"  Brix2: {isaac_pos_2:,}")
    print(f"  Brix3: {isaac_pos_3:,}")
    print(f"  Shift: {isaac_pos_3 - isaac_pos_2:+d} bytes")

    # The Pace offset in Brix2 is at isaac_pos - 4113
    pace_offset_brix2 = isaac_pos_2 - 4113

    # Check values in Brix2 around the Pace
    print(f"\n{'='*70}")
    print(f"BRIX2 VALUES AROUND PACE OFFSET ({pace_offset_brix2:,})")
    print("="*70)

    print(f"\nBrix2 Pace and nearby bytes:")
    for rel in range(-10, 20):
        pos = pace_offset_brix2 + rel
        val = data2[pos]
        attr_note = ""
        if rel == 0:
            attr_note = " <-- PACE (should be 100)"
        elif rel == 1:
            attr_note = " <-- Expected ACCEL (should be 65)"
        elif 20 <= val <= 100:
            attr_note = f" (attr? ={round(val/5)})"
        print(f"  Offset {rel:+3d}: {val:3d}{attr_note}")

    # Find ALL bytes that changed from 65 to 100 between Brix2 and Brix3
    print(f"\n{'='*70}")
    print("SEARCHING FOR 65 → 100 CHANGES (ACCELERATION CANDIDATES)")
    print("="*70)

    accel_candidates = []
    min_len = min(len(data2), len(data3))

    # This is slow but thorough
    print("\nSearching (this may take a moment)...")
    for i in range(min_len):
        if data2[i] == 65 and data3[i] == 100:
            accel_candidates.append(i)

        if i > 0 and i % 50000000 == 0:
            print(f"  Checked {i:,} bytes...")

    print(f"\nFound {len(accel_candidates)} positions where 65 → 100")

    for pos in accel_candidates[:20]:
        # Check context
        context_2 = list(data2[max(0, pos-5):pos+6])
        context_3 = list(data3[max(0, pos-5):pos+6])

        # Check if this is near Isaac
        near_isaac = abs(pos - isaac_pos_2) < 10000
        marker = " *** NEAR ISAAC ***" if near_isaac else ""

        print(f"\n  Position {pos:,}{marker}")
        print(f"    Brix2 context: {context_2}")
        print(f"    Brix3 context: {context_3}")

    # Also check: did Brix3 actually have the Acceleration change?
    # Let's look at what values exist at the expected locations
    print(f"\n{'='*70}")
    print("CHECKING IF ACCELERATION ACTUALLY CHANGED")
    print("="*70)

    # In Brix3, at the SAME absolute offset as Brix2's Pace
    # This won't be right due to structure shift, but let's see
    print(f"\nAt Brix2's Pace offset ({pace_offset_brix2:,}) in Brix3:")
    if pace_offset_brix2 < len(data3):
        print(f"  Brix3 value: {data3[pace_offset_brix2]}")
    else:
        print(f"  Out of range")

    # At the shifted offset based on name position
    pace_offset_brix3 = isaac_pos_3 - 4113
    print(f"\nAt calculated Brix3 Pace offset ({pace_offset_brix3:,}):")
    print(f"  Brix3 value: {data3[pace_offset_brix3]} (should be 100 if Pace stayed at 20)")
    print(f"  Brix3 +1 value: {data3[pace_offset_brix3 + 1]} (should be 100 if Accel changed to 20)")

    # Let's also search for where both 100,100 (Pace, Accel) appear in Brix3
    # near Isaac's name
    print(f"\n{'='*70}")
    print("SEARCHING NEAR ISAAC'S NAME IN BRIX3 FOR 100,100 PATTERN")
    print("="*70)

    search_start = max(0, isaac_pos_3 - 10000)
    search_end = min(len(data3), isaac_pos_3 + 1000)

    patterns_found = []
    for i in range(search_start, search_end - 1):
        if data3[i] == 100 and data3[i+1] == 100:
            rel = i - isaac_pos_3
            patterns_found.append((i, rel))

    print(f"\nFound {len(patterns_found)} occurrences of 100,100 near Isaac:")
    for pos, rel in patterns_found[:20]:
        context = list(data3[max(0, pos-3):pos+5])
        print(f"  At {pos:,} (rel to name: {rel:+d}): {context}")


if __name__ == "__main__":
    main()
