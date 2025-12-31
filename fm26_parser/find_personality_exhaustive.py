#!/usr/bin/env python3
"""
Exhaustive search for personality patterns.
Looking for 8 occurrences of (50 -> {5,10,15,20,25,30,35,40}) plus (85 -> 45) for Versatility.
These must be NEAR each other since they're for the same player.
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

    shift = pos10 - base_pos
    print(f"Base: Isaac at {base_pos:,}, Brix10: Isaac at {pos10:,}")
    print(f"Shift: {shift:+,}")
    print(f"Base size: {len(base_data):,}, Brix10 size: {len(data10):,}")
    print(f"Size diff: {len(data10) - len(base_data):+,}")

    # Search for ALL instances of (50 -> {5,10,15,...,40}) in the entire database
    personality_new_vals = {5, 10, 15, 20, 25, 30, 35, 40}

    print("\n" + "="*80)
    print("SEARCHING ENTIRE DATABASE FOR (50 -> personality value) CHANGES")
    print("Using the +480 shift between saves")
    print("="*80)

    all_changes = []

    # Scan ENTIRE database
    for i in range(len(base_data)):
        j = i + shift

        if j < 0 or j >= len(data10):
            continue

        old_val = base_data[i]
        new_val = data10[j]

        if old_val == 50 and new_val in personality_new_vals:
            all_changes.append((i, old_val, new_val))

    print(f"\nFound {len(all_changes)} total (50 -> personality) changes")

    # Now find CLUSTERS of 8 changes within 100 bytes of each other
    print("\n" + "="*80)
    print("LOOKING FOR CLUSTERS OF 8 CHANGES WITHIN 100 BYTES")
    print("="*80)

    if all_changes:
        # Sort by position
        all_changes.sort(key=lambda x: x[0])

        # Find clusters
        clusters = []
        current_cluster = [all_changes[0]]

        for i in range(1, len(all_changes)):
            pos, _, _ = all_changes[i]
            prev_pos, _, _ = all_changes[i-1]

            if pos - prev_pos < 100:
                current_cluster.append(all_changes[i])
            else:
                if len(current_cluster) >= 5:  # At least 5 personality changes together
                    clusters.append(current_cluster)
                current_cluster = [all_changes[i]]

        if len(current_cluster) >= 5:
            clusters.append(current_cluster)

        print(f"\nFound {len(clusters)} clusters of 5+ changes")

        for idx, cluster in enumerate(clusters):
            new_vals = sorted([v for _, _, v in cluster])
            print(f"\n  Cluster {idx+1}: {len(cluster)} changes")
            print(f"    Positions: {cluster[0][0]:,} to {cluster[-1][0]:,}")
            print(f"    New values: {new_vals}")

            # Check how far from Isaac's name
            avg_pos = sum(c[0] for c in cluster) // len(cluster)
            dist_from_name = base_pos - avg_pos
            print(f"    Distance from name: {dist_from_name:+,}")

            # Show individual changes
            for pos, old, new in cluster:
                offset = base_pos - pos
                print(f"      pos={pos:,} (offset {offset:+,}): {old} -> {new}")

    # Also search for Versatility: 85 -> 45
    print("\n" + "="*80)
    print("SEARCHING FOR VERSATILITY (85 -> 45)")
    print("="*80)

    versatility_matches = []
    for i in range(len(base_data)):
        j = i + shift

        if j < 0 or j >= len(data10):
            continue

        if base_data[i] == 85 and data10[j] == 45:
            versatility_matches.append(i)

    print(f"\nFound {len(versatility_matches)} instances of (85 -> 45)")

    for pos in versatility_matches[:20]:  # Show first 20
        offset = base_pos - pos
        print(f"  pos={pos:,} (offset {offset:+,})")

    # Check if versatility is near any personality cluster
    if clusters and versatility_matches:
        print("\n  Checking if any Versatility match is near a personality cluster...")
        for cluster in clusters:
            cluster_start = cluster[0][0]
            cluster_end = cluster[-1][0]

            for vm_pos in versatility_matches:
                if cluster_start - 100 <= vm_pos <= cluster_end + 100:
                    print(f"    FOUND! Versatility at {vm_pos:,} is within cluster {cluster_start:,}-{cluster_end:,}")

    # Maybe personality is NOT at fixed offset from name but at ABSOLUTE position?
    # Or maybe the shift is different for personality?
    print("\n" + "="*80)
    print("TRYING VARIABLE SHIFT SEARCH")
    print("="*80)

    # Search near base's personality location with variable shift
    # We know personality SHOULD be somewhere between -4200 and -4000 from name
    search_start = base_pos - 5000
    search_end = base_pos - 3000

    print(f"Searching base positions {search_start:,} to {search_end:,}")
    print("Looking for 50s that became personality values in Brix10 with ANY shift")

    found_personality_candidates = []

    for base_check in range(search_start, search_end):
        if base_check < 0:
            continue

        if base_data[base_check] == 50:
            # Try shifts from 0 to 1000
            for test_shift in range(0, 1000):
                mod_check = base_check + test_shift
                if mod_check >= len(data10):
                    continue

                mod_val = data10[mod_check]
                if mod_val in personality_new_vals:
                    found_personality_candidates.append((base_check, test_shift, mod_val))
                    break  # Only record first matching shift

    # Group by shift to find consistent alignment
    by_shift = {}
    for base_check, test_shift, mod_val in found_personality_candidates:
        if test_shift not in by_shift:
            by_shift[test_shift] = []
        by_shift[test_shift].append((base_check, mod_val))

    print(f"\nFound {len(found_personality_candidates)} candidates grouped by shift:")
    for s in sorted(by_shift.keys()):
        matches = by_shift[s]
        if len(matches) >= 4:  # At least 4 matches at this shift
            unique_vals = sorted(set(v for _, v in matches))
            print(f"\n  Shift +{s}: {len(matches)} matches, values: {unique_vals}")
            for pos, val in sorted(matches)[:10]:
                offset = base_pos - pos
                print(f"    base_pos={pos:,} (offset {offset:+,}): 50 -> {val}")


if __name__ == "__main__":
    main()
