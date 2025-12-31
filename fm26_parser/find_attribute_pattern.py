#!/usr/bin/env python3
"""
Find player attribute patterns by searching for known attribute values.

Strategy: In Brixham3, Isaac Smith has both Pace=20 and Acceleration=20,
which means both should be stored as 100 (on internal 0-100 scale).
Search for regions where two 100 values are close together.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor


def find_double_100_regions(data: bytes, max_distance: int = 50) -> list:
    """Find regions where two bytes with value 100 are within max_distance of each other."""
    regions = []

    # Find all positions with value 100
    positions_100 = []
    for i in range(len(data)):
        if data[i] == 100:
            positions_100.append(i)

    print(f"Found {len(positions_100)} bytes with value 100")

    # Find pairs that are close together
    for i, pos1 in enumerate(positions_100):
        for pos2 in positions_100[i+1:]:
            distance = pos2 - pos1
            if distance > max_distance:
                break  # Sorted, so no more close pairs for this pos1

            regions.append({
                'pos1': pos1,
                'pos2': pos2,
                'distance': distance
            })

    return regions


def analyze_region(data: bytes, center: int, window: int = 30) -> dict:
    """Analyze bytes around a position."""
    start = max(0, center - window)
    end = min(len(data), center + window)
    region = data[start:end]

    # Look for potential attribute patterns (values in 0-100 range that make sense)
    potential_attrs = []
    for i, b in enumerate(region):
        if 20 <= b <= 100:  # Reasonable attribute range
            potential_attrs.append({
                'rel_offset': i - window,
                'value': b,
                'scaled_1_20': round(b / 5)  # Convert back to FM 1-20 scale
            })

    return {
        'start': start,
        'center': center,
        'region': list(region),
        'potential_attrs': potential_attrs
    }


def compare_regions(data1: bytes, data2: bytes, data3: bytes, region_start: int, size: int = 60):
    """Compare a region across all three saves."""
    print(f"\n{'='*70}")
    print(f"REGION AROUND {region_start:,} ({hex(region_start)})")
    print("="*70)

    # Ensure we don't go out of bounds
    end = min(region_start + size, len(data1), len(data2), len(data3))
    if region_start >= len(data1) or region_start >= len(data2) or region_start >= len(data3):
        print("Region out of bounds!")
        return

    region1 = data1[region_start:end]
    region2 = data2[region_start:end]
    region3 = data3[region_start:end]

    print(f"\nComparing {size} bytes:")
    print(f"{'Offset':>8} | {'Brix1':>5} | {'Brix2':>5} | {'Brix3':>5} | Notes")
    print("-" * 60)

    for i in range(len(region1)):
        v1, v2, v3 = region1[i], region2[i], region3[i]

        notes = []
        if v1 != v2:
            notes.append(f"1→2: {v1}→{v2}")
        if v2 != v3:
            notes.append(f"2→3: {v2}→{v3}")

        # Check if looks like attribute
        if 20 <= v3 <= 100 and v3 == 100:
            notes.append("=100 (attr?)")

        note_str = ", ".join(notes) if notes else ""

        if v1 != v2 or v2 != v3:  # Only show changed bytes
            print(f"{i:>8} | {v1:>5} | {v2:>5} | {v3:>5} | {note_str}")


def main():
    base = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")

    print("Loading all three saves...")

    dec1 = FM26Decompressor(base / "Brixham.fm")
    dec1.load()
    data1 = dec1.decompress_main_database()

    dec2 = FM26Decompressor(base / "Brixham2.fm")
    dec2.load()
    data2 = dec2.decompress_main_database()

    dec3 = FM26Decompressor(base / "Brixham3.fm")
    dec3.load()
    data3 = dec3.decompress_main_database()

    print(f"\nSizes: {len(data1):,} / {len(data2):,} / {len(data3):,}")

    # Since structures shifted, let's find Isaac Smith's record differently
    # Search for regions that changed from ~65 to 100 between Brixham2 and Brixham3
    # (This would be Acceleration)

    print("\n" + "="*70)
    print("SEARCHING FOR ACCELERATION CHANGE (65 → 100) IN BRIXHAM2 vs BRIXHAM3")
    print("="*70)

    # Since sizes differ, we can't do direct comparison
    # Instead, let's look for unique patterns

    # Strategy: In Brixham3, Isaac has Pace=100 AND Accel=100
    # These should be near each other in the player record
    # Search for pairs of 100s that are close together

    print("\nSearching Brixham3 for adjacent 100 values (Pace + Accel pattern)...")

    # Find all pairs of 100s within 20 bytes of each other
    pairs = []
    prev_100_pos = None
    for i in range(len(data3)):
        if data3[i] == 100:
            if prev_100_pos is not None and i - prev_100_pos <= 20:
                pairs.append((prev_100_pos, i, i - prev_100_pos))
            prev_100_pos = i

    print(f"Found {len(pairs)} pairs of 100s within 20 bytes of each other")

    # For each pair, check the surrounding context in all three saves
    # We're looking for a region where:
    # - Brix1 has value ~52 (Pace) and ~65 (Accel)
    # - Brix2 has value 100 (Pace changed) and ~65 (Accel same)
    # - Brix3 has value 100 (Pace) and 100 (Accel changed)

    print("\nAnalyzing pairs to find likely attribute patterns...")
    print("Looking for: Brix1 ~50-65, Brix2 changed, Brix3 = 100,100")

    candidates = []
    for pos1, pos2, dist in pairs[:500]:  # Check first 500 pairs
        # Only consider pairs where the distance makes sense for adjacent attrs
        if dist > 10:
            continue

        # Check if these positions exist in Brix1 and Brix2
        if pos1 >= len(data1) or pos2 >= len(data1):
            continue
        if pos1 >= len(data2) or pos2 >= len(data2):
            continue

        v1_1, v1_2 = data1[pos1], data1[pos2]
        v2_1, v2_2 = data2[pos1], data2[pos2]
        v3_1, v3_2 = data3[pos1], data3[pos2]

        # Look for Isaac's pattern:
        # pos1 (Pace): 52 → 100 → 100
        # pos2 (Accel): 65 → 65 → 100
        if (40 <= v1_1 <= 60 and v2_1 == 100 and v3_1 == 100 and
            60 <= v1_2 <= 70 and 60 <= v2_2 <= 70 and v3_2 == 100):
            candidates.append({
                'pace_pos': pos1,
                'accel_pos': pos2,
                'distance': dist,
                'pace_values': (v1_1, v2_1, v3_1),
                'accel_values': (v1_2, v2_2, v3_2)
            })

    if candidates:
        print(f"\n*** FOUND {len(candidates)} CANDIDATE ATTRIBUTE PAIRS ***")
        for c in candidates:
            print(f"\n  Pace at {c['pace_pos']:,}: {c['pace_values'][0]} → {c['pace_values'][1]} → {c['pace_values'][2]}")
            print(f"  Accel at {c['accel_pos']:,}: {c['accel_values'][0]} → {c['accel_values'][1]} → {c['accel_values'][2]}")
            print(f"  Distance between attrs: {c['distance']} bytes")

            # Show surrounding context
            compare_regions(data1, data2, data3, c['pace_pos'] - 10, 30)
    else:
        print("\nNo perfect matches found. Let's broaden the search...")

        # Try finding just regions where we see the pattern change
        # Search for bytes that: changed in Brix2 to 100, stayed 100 in Brix3
        pace_candidates = []
        for i in range(min(len(data1), len(data2), len(data3))):
            v1, v2, v3 = data1[i], data2[i], data3[i]
            if 40 <= v1 <= 60 and v2 == 100 and v3 == 100:
                pace_candidates.append(i)

        print(f"\nPace pattern (40-60 → 100 → 100): {len(pace_candidates)} candidates")

        for pos in pace_candidates[:20]:
            # Check nearby bytes for Acceleration pattern
            for offset in range(-20, 21):
                check_pos = pos + offset
                if check_pos < 0 or check_pos >= len(data1):
                    continue
                v1, v2, v3 = data1[check_pos], data2[check_pos], data3[check_pos]
                # Accel: ~65 → ~65 → 100
                if 60 <= v1 <= 70 and 60 <= v2 <= 70 and v3 == 100:
                    print(f"\n*** POTENTIAL MATCH ***")
                    print(f"  Pace at {pos:,}: {data1[pos]} → {data2[pos]} → {data3[pos]}")
                    print(f"  Accel at {check_pos:,} (offset {offset}): {v1} → {v2} → {v3}")


if __name__ == "__main__":
    main()
