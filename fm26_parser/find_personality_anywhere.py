#!/usr/bin/env python3
"""
Personality must be stored somewhere else entirely.
Search the ENTIRE database for the specific pattern:
- 8 bytes that were all 50 in Base
- Changed to 5, 10, 15, 20, 25, 30, 35, 40 in Brix10
Plus Versatility: 85 -> 45

These 9 changes MUST exist somewhere near each other.
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
    print(f"Base: Isaac at {base_pos:,}")
    print(f"Brix10: Isaac at {pos10:,}")
    print(f"Shift: {shift:+}")

    # Search for ALL positions where base=50 and brix10 is a personality value
    print("\n" + "="*80)
    print("SEARCHING ENTIRE DATABASE FOR (50 -> personality) CHANGES")
    print("="*80)

    personality_vals = {5, 10, 15, 20, 25, 30, 35, 40}
    all_matches = []

    for i in range(min(len(base_data), len(data10) - shift)):
        j = i + shift
        if j < 0 or j >= len(data10):
            continue

        if base_data[i] == 50 and data10[j] in personality_vals:
            all_matches.append((i, data10[j]))

    print(f"Found {len(all_matches)} total matches")

    # Look for clusters of exactly 8 matches within 100 bytes
    print("\n" + "="*80)
    print("LOOKING FOR CLUSTERS OF 8 PERSONALITY CHANGES (ideal)")
    print("="*80)

    # Find clusters
    if all_matches:
        all_matches.sort(key=lambda x: x[0])

        clusters = []
        current = [all_matches[0]]

        for i in range(1, len(all_matches)):
            pos, val = all_matches[i]
            prev_pos, _ = all_matches[i-1]

            if pos - prev_pos < 100:
                current.append((pos, val))
            else:
                if len(current) >= 6:
                    clusters.append(current)
                current = [(pos, val)]

        if len(current) >= 6:
            clusters.append(current)

        print(f"Found {len(clusters)} clusters of 6+ changes")

        for idx, cluster in enumerate(clusters):
            values = sorted([v for _, v in cluster])
            unique = sorted(set(values))

            # Check if this cluster has diverse values (not all the same)
            if len(unique) >= 5:
                start_pos = cluster[0][0]
                dist_from_name = base_pos - start_pos

                print(f"\n  Cluster {idx+1}: {len(cluster)} changes at positions {cluster[0][0]:,} - {cluster[-1][0]:,}")
                print(f"    Distance from Isaac's name: {dist_from_name:+,}")
                print(f"    Unique values: {unique}")

                # Check if Versatility (85->45) is nearby
                found_versatility = False
                for offset in range(-50, 50):
                    check_pos = cluster[0][0] + offset
                    if check_pos < 0 or check_pos >= len(base_data):
                        continue
                    check_brix = check_pos + shift
                    if check_brix < 0 or check_brix >= len(data10):
                        continue

                    if base_data[check_pos] == 85 and data10[check_brix] == 45:
                        print(f"    *** VERSATILITY FOUND nearby at offset {offset:+} from cluster start! ***")
                        found_versatility = True
                        break

                if found_versatility:
                    print("\n    THIS IS LIKELY ISAAC'S PERSONALITY BLOCK!")
                    print("\n    Details:")
                    for pos, val in cluster:
                        d = base_pos - pos
                        print(f"      pos={pos:,} (dist from name {d:+,}): 50 -> {val}")

    # Alternative: Maybe personality is stored with a DIFFERENT shift?
    print("\n" + "="*80)
    print("TRYING ALTERNATE SHIFTS")
    print("="*80)

    for test_shift in range(400, 600):
        personality_matches = []
        versatility_matches = []

        for i in range(len(base_data)):
            j = i + test_shift
            if j < 0 or j >= len(data10):
                continue

            if base_data[i] == 50 and data10[j] in personality_vals:
                personality_matches.append((i, data10[j]))
            if base_data[i] == 85 and data10[j] == 45:
                versatility_matches.append(i)

        # Look for clusters where personality AND versatility are close
        for vm_pos in versatility_matches:
            # Count personality matches within 100 bytes of Versatility
            nearby = [(p, v) for p, v in personality_matches if abs(p - vm_pos) < 100]
            if len(nearby) >= 6:
                unique_vals = sorted(set(v for _, v in nearby))
                if len(unique_vals) >= 5:
                    print(f"\n  Shift +{test_shift}: Found Versatility at {vm_pos:,} with {len(nearby)} personality matches nearby")
                    print(f"    Unique values: {unique_vals}")
                    print(f"    Distance from Isaac: {base_pos - vm_pos:+,}")

    # What if Isaac's player data has MULTIPLE sections?
    # Maybe personality is stored as part of a "person" table, not "player attributes"
    print("\n" + "="*80)
    print("SEARCHING FOR ISAAC'S NAME IN OTHER LOCATIONS")
    print("Maybe personality is in a different data structure")
    print("="*80)

    # Find ALL occurrences of "Isaac James Smith" in both files
    name_bytes = name.encode('utf-8')
    pattern = len(name_bytes).to_bytes(4, 'little') + name_bytes

    base_occurrences = []
    pos = 0
    while True:
        pos = base_data.find(pattern, pos)
        if pos == -1:
            break
        base_occurrences.append(pos + 4)  # Position after length prefix
        pos += 1

    brix10_occurrences = []
    pos = 0
    while True:
        pos = data10.find(pattern, pos)
        if pos == -1:
            break
        brix10_occurrences.append(pos + 4)
        pos += 1

    print(f"\n'Isaac James Smith' appears {len(base_occurrences)} times in Base:")
    for occ in base_occurrences:
        print(f"  position {occ:,}")

    print(f"\n'Isaac James Smith' appears {len(brix10_occurrences)} times in Brix10:")
    for occ in brix10_occurrences:
        print(f"  position {occ:,}")

    # For each occurrence of Isaac, check for personality changes nearby
    if len(base_occurrences) > 1:
        print("\n" + "="*80)
        print("CHECKING EACH ISAAC OCCURRENCE FOR PERSONALITY CHANGES")
        print("="*80)

        for idx, (base_occ, brix_occ) in enumerate(zip(base_occurrences, brix10_occurrences)):
            print(f"\n  Occurrence {idx+1}: Base={base_occ:,}, Brix10={brix_occ:,}")

            # Check -200 to +200 bytes around this occurrence
            found_50_to_personality = []
            found_85_to_45 = []

            for offset in range(-200, 200):
                base_check = base_occ - offset
                mod_check = brix_occ - offset

                if base_check < 0 or mod_check < 0:
                    continue
                if base_check >= len(base_data) or mod_check >= len(data10):
                    continue

                if base_data[base_check] == 50 and data10[mod_check] in personality_vals:
                    found_50_to_personality.append((-offset, data10[mod_check]))
                if base_data[base_check] == 85 and data10[mod_check] == 45:
                    found_85_to_45.append(-offset)

            if found_50_to_personality:
                print(f"    Found {len(found_50_to_personality)} (50 -> personality) changes:")
                unique = sorted(set(v for _, v in found_50_to_personality))
                print(f"      Unique new values: {unique}")
                for off, val in found_50_to_personality[:10]:
                    print(f"      offset {off:+}: 50 -> {val}")

            if found_85_to_45:
                print(f"    Found Versatility at offsets: {found_85_to_45}")


if __name__ == "__main__":
    main()
