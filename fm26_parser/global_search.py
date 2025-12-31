#!/usr/bin/env python3
"""
Global search for personality patterns anywhere in the database.
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

    dec10 = FM26Decompressor(base / "Brixham10.fm")
    dec10.load()
    data10 = dec10.decompress_main_database()
    pos10 = find_string_position(data10, name)

    print(f"Base: Isaac at {base_pos:,}, size={len(base_data):,}")
    print(f"Brix10: Isaac at {pos10:,}, size={len(data10):,}")

    # The personality changes should create a pattern of 8 bytes that were all 50
    # changing to 5, 10, 15, 20, 25, 30, 35, 40 (in some order)
    # Plus Versatility: 85 -> 45

    # Search a WIDE range around Isaac's position
    # Check +/- 50,000 bytes from Isaac's position

    print("\n" + "="*80)
    print("SEARCHING WIDE RANGE FOR (50 -> personality values)")
    print("="*80)

    search_start = max(0, base_pos - 50000)
    search_end = min(len(base_data), base_pos + 50000)

    # Adjust for the position shift between saves
    shift = pos10 - base_pos  # +480

    found_50_changes = []

    for i in range(search_start, search_end):
        j = i + shift  # Corresponding position in Brix10

        if j < 0 or j >= len(data10):
            continue

        old_val = base_data[i]
        new_val = data10[j]

        # Look for 50 -> 5/10/15/20/25/30/35/40
        if old_val == 50 and new_val in [5, 10, 15, 20, 25, 30, 35, 40]:
            offset_from_name = base_pos - i
            found_50_changes.append((offset_from_name, old_val, new_val))

    print(f"\nFound {len(found_50_changes)} instances of (50 -> personality value)")

    if found_50_changes:
        # Group by clusters
        found_50_changes.sort(key=lambda x: x[0])
        for off, old, new in found_50_changes[:50]:  # Show first 50
            print(f"  offset {off:>+6} from name: {old} -> {new} (10 -> {new//5})")

    # Also search for Versatility: 85 -> 45
    print("\n" + "="*80)
    print("SEARCHING FOR VERSATILITY (85 -> 45)")
    print("="*80)

    for i in range(search_start, search_end):
        j = i + shift

        if j < 0 or j >= len(data10):
            continue

        old_val = base_data[i]
        new_val = data10[j]

        if old_val == 85 and new_val == 45:
            offset_from_name = base_pos - i
            print(f"  offset {offset_from_name:>+6} from name: 85 -> 45")

    # Maybe personality isn't relative to name at all
    # Let's search for the PATTERN: 8 consecutive-ish bytes that are all 50 in base
    # and become 5,10,15,20,25,30,35,40 in brix10

    print("\n" + "="*80)
    print("SEARCHING FOR CLUSTER OF 8 CHANGES (50->5,10,15,20,25,30,35,40)")
    print("="*80)

    # Find all (50 -> X) changes and look for clusters
    all_50_changes = []
    for i in range(len(base_data) - 1):
        j = i + shift

        if j < 0 or j >= len(data10):
            continue

        old_val = base_data[i]
        new_val = data10[j]

        if old_val == 50 and new_val in [5, 10, 15, 20, 25, 30, 35, 40]:
            all_50_changes.append((i, new_val))

    print(f"\nTotal (50 -> personality) changes in entire DB: {len(all_50_changes)}")

    # Look for clusters of 8 within 100 bytes
    if all_50_changes:
        clusters = []
        current_cluster = [all_50_changes[0]]

        for i in range(1, len(all_50_changes)):
            pos, val = all_50_changes[i]
            prev_pos, _ = all_50_changes[i-1]

            if pos - prev_pos < 100:
                current_cluster.append((pos, val))
            else:
                if len(current_cluster) >= 5:
                    clusters.append(current_cluster)
                current_cluster = [(pos, val)]

        if len(current_cluster) >= 5:
            clusters.append(current_cluster)

        print(f"Found {len(clusters)} clusters of 5+ changes")

        for idx, cluster in enumerate(clusters[:5]):  # Show first 5 clusters
            print(f"\n  Cluster {idx+1}: {len(cluster)} changes")
            new_vals = sorted([v for _, v in cluster])
            print(f"    New values: {new_vals}")
            for pos, val in cluster:
                offset_from_name = base_pos - pos
                print(f"      pos={pos:,} (offset {offset_from_name:>+6}): 50 -> {val}")


if __name__ == "__main__":
    main()
