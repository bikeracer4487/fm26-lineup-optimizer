#!/usr/bin/env python3
"""
Check known Pace offsets across all three saves to find Acceleration.

We know from Brixham→Brixham2 diff:
- Isaac Smith Pace at ~165,660,358 (52 → 100)
- Tegan Budd Pace at ~231,627,458 (38 → 100)

In Brixham3, we changed Isaac's Acceleration (13 → 20, scaled ~65 → 100).
The Acceleration byte should be near the Pace byte.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor


def load_save(path: Path) -> bytes:
    dec = FM26Decompressor(path)
    dec.load()
    return dec.decompress_main_database()


def show_region(data: bytes, center: int, name: str, window: int = 100):
    """Show bytes around an offset."""
    start = max(0, center - window)
    end = min(len(data), center + window)

    print(f"\n{name} - Region around offset {center:,} ({hex(center)}):")
    print(f"  Showing bytes {start:,} to {end:,}")

    # Show as rows of values
    region = data[start:end]
    for i in range(0, len(region), 20):
        row = region[i:i+20]
        offset = start + i
        values = ' '.join(f'{b:3d}' for b in row)
        relative = offset - center
        marker = ""
        if relative <= 0 < relative + 20:
            marker = " <-- CENTER"
        print(f"  {relative:+5d}: {values}{marker}")


def compare_at_offset(data1: bytes, data2: bytes, data3: bytes, offset: int, name: str):
    """Compare all three saves at a specific offset region."""
    print(f"\n{'='*70}")
    print(f"COMPARING {name} REGION")
    print("="*70)

    # Get region from each save (200 bytes around the offset)
    window = 100

    if offset >= len(data1) or offset >= len(data2) or offset >= len(data3):
        print(f"Offset {offset} out of range!")
        return

    region1 = data1[offset-window:offset+window]
    region2 = data2[offset-window:offset+window]
    region3 = data3[offset-window:offset+window]

    print(f"\nBytes at offset {offset}:")
    print(f"  Original (Brixham.fm):      {data1[offset]:3d}")
    print(f"  Pace changed (Brixham2.fm): {data2[offset]:3d}")
    print(f"  Accel changed (Brixham3.fm): {data3[offset]:3d}")

    # Find all differences between each pair
    print(f"\n{'='*50}")
    print("CHANGES FROM ORIGINAL TO PACE-CHANGED (Brixham→Brixham2)")
    print("="*50)

    changes_1_to_2 = []
    for i in range(len(region1)):
        if region1[i] != region2[i]:
            changes_1_to_2.append({
                'rel_offset': i - window,
                'orig': region1[i],
                'new': region2[i]
            })

    for c in changes_1_to_2:
        marker = " <-- PACE?" if c['new'] == 100 else ""
        print(f"  Offset {c['rel_offset']:+4d}: {c['orig']:3d} → {c['new']:3d}{marker}")

    print(f"\n{'='*50}")
    print("CHANGES FROM PACE-CHANGED TO ACCEL-CHANGED (Brixham2→Brixham3)")
    print("="*50)

    changes_2_to_3 = []
    for i in range(len(region2)):
        if region2[i] != region3[i]:
            changes_2_to_3.append({
                'rel_offset': i - window,
                'orig': region2[i],
                'new': region3[i]
            })

    for c in changes_2_to_3:
        marker = ""
        if c['new'] == 100:
            marker = " <-- ACCEL?"
        if c['orig'] == 100 and c['new'] != 100:
            marker = " <-- PACE stayed 100?"
        print(f"  Offset {c['rel_offset']:+4d}: {c['orig']:3d} → {c['new']:3d}{marker}")

    # Look for the Acceleration change specifically
    print(f"\n{'='*50}")
    print("COMPARING ALL THREE (looking for: orig ~65, pace-save 65, accel-save 100)")
    print("="*50)

    for i in range(len(region1)):
        v1, v2, v3 = region1[i], region2[i], region3[i]
        rel = i - window

        # We're looking for: v1 ≈ 65, v2 ≈ 65, v3 = 100 (Acceleration change)
        if v1 == v2 and v3 == 100 and 60 <= v1 <= 70:
            print(f"  *** ACCEL CANDIDATE at {rel:+4d}: {v1} → {v2} → {v3}")
        # Also Pace: v1 ≈ 50, v2 = 100, v3 = 100 (already changed)
        elif v2 == 100 and v3 == 100 and v1 != 100:
            print(f"  PACE at {rel:+4d}: {v1} → {v2} → {v3}")


def main():
    base = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")

    print("Loading all three saves...")
    print("  Brixham.fm  - Original")
    data1 = load_save(base / "Brixham.fm")
    print("  Brixham2.fm - Pace changed (Isaac=20, Tegan=20)")
    data2 = load_save(base / "Brixham2.fm")
    print("  Brixham3.fm - Acceleration changed (Isaac=20)")
    data3 = load_save(base / "Brixham3.fm")

    print(f"\nSizes: {len(data1):,} / {len(data2):,} / {len(data3):,}")

    # Known Pace change offsets from first diff
    # Isaac Smith Pace: 52 → 100 (was at offset ~165,660,358 in original→pace-changed diff)
    # Tegan Budd Pace: 38 → 100 (was at offset ~231,627,458)

    # Check Isaac Smith region
    isaac_pace_offset = 165660358
    compare_at_offset(data1, data2, data3, isaac_pace_offset, "ISAAC SMITH")

    # Check Tegan Budd region
    tegan_pace_offset = 231627458
    compare_at_offset(data1, data2, data3, tegan_pace_offset, "TEGAN BUDD")


if __name__ == "__main__":
    main()
