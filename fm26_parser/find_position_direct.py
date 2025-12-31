#!/usr/bin/env python3
"""
Find position familiarity by searching for the expected NEW values pattern in Brix9.
We know: GK=1, DL=2, DC=3, DR=4, WBL=5, DM=6, WBR=7, ML=8, MC=9, MR=10, AML=11, AMC=12, AMR=13, ST=14
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

    print("Loading Brix9...")
    dec9 = FM26Decompressor(base / "Brixham9.fm")
    dec9.load()
    data9 = dec9.decompress_main_database()
    pos9 = find_string_position(data9, name)

    print(f"Brix9: Isaac at {pos9:,}")

    # Search for consecutive bytes containing: 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14
    # (or some subset in sequence)
    position_vals = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]

    print("\n" + "="*80)
    print("SEARCHING FOR POSITION FAMILIARITY SEQUENCE IN BRIX9")
    print("Looking for window with values {1,2,3,4,5,6,7,8,9,10,11,12,13,14}")
    print("="*80)

    # Search within +/- 10000 bytes of Isaac's name
    search_start = max(0, pos9 - 10000)
    search_end = min(len(data9), pos9 + 10000)

    best_matches = []

    for i in range(search_start, search_end - 20):
        window = data9[i:i+20]
        matches = [b for b in window if b in position_vals]
        unique = set(matches)

        if len(unique) >= 10:  # At least 10 of 14 position values
            best_matches.append((i, unique))

    print(f"\nFound {len(best_matches)} windows with 10+ unique position values")

    # Sort by distance from name
    best_matches.sort(key=lambda x: abs(x[0] - pos9))

    for pos, vals in best_matches[:10]:
        dist = pos - pos9
        print(f"\n  pos={pos:,} (offset {dist:+,})")
        print(f"    Unique values: {sorted(vals)}")
        print(f"    Raw bytes: {list(data9[pos:pos+20])}")

    # Also look for the EXACT sequence we expect
    print("\n" + "="*80)
    print("LOOKING FOR CONSECUTIVE ASCENDING VALUES 1-14")
    print("="*80)

    for i in range(search_start, search_end - 14):
        # Check if bytes form an ascending sequence
        window = list(data9[i:i+14])

        # Check various patterns
        if sorted(window) == list(range(1, 15)):
            dist = i - pos9
            print(f"  FOUND at pos={i:,} (offset {dist:+,}): {window}")

        # Also check if we have many position values in order
        ascending_count = sum(1 for j in range(len(window)-1) if window[j] < window[j+1])
        if ascending_count >= 10 and set(window) == set(range(1, 15)):
            dist = i - pos9
            print(f"  ASCENDING at pos={i:,} (offset {dist:+,}): {window}")

    # Let me look at the specific region we saw changes (-4115 to -4105)
    print("\n" + "="*80)
    print("RAW BYTES AT SUSPICIOUS REGION (-4120 to -4100)")
    print("="*80)

    print("\nBrix9 bytes:")
    for offset in range(-4120, -4100):
        val = data9[pos9 + offset]
        marker = "**" if val in position_vals else ""
        print(f"  {offset:>+5}: {val:>3} {marker}")

    # Load base to compare
    print("\nLoading Base for comparison...")
    dec_base = FM26Decompressor(base / "Brixham.fm")
    dec_base.load()
    base_data = dec_base.decompress_main_database()
    base_pos = find_string_position(base_data, name)

    print(f"\nBase: Isaac at {base_pos:,}")
    print(f"Shift: {pos9 - base_pos:+}")

    print("\nBase bytes at same offsets:")
    for offset in range(-4120, -4100):
        val = base_data[base_pos + offset]
        print(f"  {offset:>+5}: {val:>3}")

    # Let me try finding position familiarity by looking at what UNIQUE changes
    # exist between Base and Brix9 that result in values 1-14
    print("\n" + "="*80)
    print("FINDING ALL CHANGES WHERE NEW VALUE IS 1-14")
    print("(Using aligned offset from each Isaac position)")
    print("="*80)

    changes_to_positions = []
    for offset in range(-5000, 5000):
        base_check = base_pos + offset
        mod_check = pos9 + offset

        if base_check < 0 or mod_check < 0:
            continue
        if base_check >= len(base_data) or mod_check >= len(data9):
            continue

        base_val = base_data[base_check]
        mod_val = data9[mod_check]

        if mod_val in position_vals and base_val != mod_val:
            changes_to_positions.append((offset, base_val, mod_val))

    print(f"\nFound {len(changes_to_positions)} changes where new value is 1-14")

    # Group by new value
    by_new_val = {v: [] for v in range(1, 15)}
    for off, old, new in changes_to_positions:
        by_new_val[new].append((off, old))

    print("\nGrouped by new value:")
    for new_val in range(1, 15):
        matches = by_new_val[new_val]
        if matches:
            print(f"\n  New value {new_val:>2}: {len(matches)} changes")
            # Show the ones closest to expected position attribute region
            close_matches = [m for m in matches if -5000 < m[0] < 0]
            for off, old in close_matches[:5]:
                print(f"    offset {off:>+5}: {old:>3} -> {new_val}")


if __name__ == "__main__":
    main()
