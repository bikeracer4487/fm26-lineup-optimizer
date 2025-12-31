#!/usr/bin/env python3
"""
Search for personality patterns independently in each file.
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


def find_all_string_positions(data: bytes, target: str) -> list:
    """Find ALL occurrences of a name in the data."""
    target_bytes = target.encode('utf-8')
    pattern = len(target_bytes).to_bytes(4, 'little') + target_bytes

    positions = []
    start = 0
    while True:
        pos = data.find(pattern, start)
        if pos == -1:
            break
        positions.append(pos + 4)  # Position after length prefix
        start = pos + 1

    return positions


def main():
    base = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")

    print("Loading saves...")
    dec_base = FM26Decompressor(base / "Brixham.fm")
    dec_base.load()
    base_data = dec_base.decompress_main_database()

    dec10 = FM26Decompressor(base / "Brixham10.fm")
    dec10.load()
    data10 = dec10.decompress_main_database()

    # Find all occurrences of "Isaac James Smith"
    name = "Isaac James Smith"
    base_positions = find_all_string_positions(base_data, name)
    brix10_positions = find_all_string_positions(data10, name)

    print(f"\n'{name}' occurrences:")
    print(f"  Base: {len(base_positions)} at {base_positions}")
    print(f"  Brix10: {len(brix10_positions)} at {brix10_positions}")

    # Personality pattern in Brix10: should have 8 consecutive bytes as 5,10,15,20,25,30,35,40
    # (in some order, not necessarily this order)
    personality_set = {5, 10, 15, 20, 25, 30, 35, 40}

    print("\n" + "="*80)
    print("SEARCHING FOR PERSONALITY PATTERN IN BRIX10")
    print("8 bytes within 50 bytes containing {5,10,15,20,25,30,35,40}")
    print("="*80)

    # Search near Isaac's position
    isaac_pos = brix10_positions[0]
    search_start = max(0, isaac_pos - 10000)
    search_end = min(len(data10), isaac_pos + 10000)

    found_clusters = []

    for i in range(search_start, search_end - 50):
        # Check a 50-byte window
        window = data10[i:i+50]
        matches = [b for b in window if b in personality_set]

        if len(set(matches)) >= 6:  # At least 6 unique personality values
            found_clusters.append((i, matches))

    print(f"\nFound {len(found_clusters)} potential personality clusters")

    for pos, matches in found_clusters[:10]:
        offset_from_name = isaac_pos - pos
        unique_vals = sorted(set(matches))
        print(f"  pos={pos:,} (offset {offset_from_name:>+6}): unique vals = {unique_vals}")

    # Alternative: search for the sequence [5, 10, 15, 20, 25, 30, 35, 40, 45]
    # These should be close together
    print("\n" + "="*80)
    print("SEARCHING FOR PERSONALITY VALUE SEQUENCE NEAR ISAAC")
    print("="*80)

    # Get bytes in range around Isaac
    isaac_base = base_positions[0]
    isaac_mod = brix10_positions[0]

    # Map out all bytes that could be personality in Brix10
    print("\nBytes with personality values (5-45 multiples of 5) near Isaac in Brix10:")

    for offset in range(5000, 3500, -1):
        pos = isaac_mod - offset
        if 0 <= pos < len(data10):
            val = data10[pos]
            if val in [5, 10, 15, 20, 25, 30, 35, 40, 45]:
                # Check what the base value was
                base_pos_check = isaac_base - offset
                if 0 <= base_pos_check < len(base_data):
                    base_val = base_data[base_pos_check]
                    if base_val == 50 or base_val == 85:  # Expected original values
                        attr = "Versatility" if base_val == 85 else f"Personality_{val//5}"
                        print(f"  {-offset:>+5}: {base_val} -> {val} ({attr})")

    # Also check if there are multiple Isaac records
    print("\n" + "="*80)
    print("CHECKING FOR MULTIPLE PLAYER RECORDS")
    print("="*80)

    # Sometimes FM stores multiple versions of player data
    # (e.g., current state, initial state, etc.)

    for idx, pos in enumerate(base_positions):
        print(f"\n  Occurrence {idx+1} at position {pos:,}")

        # Check surrounding context
        context_start = max(0, pos - 100)
        context = base_data[context_start:pos]

        # Look for common patterns before player names
        print(f"    20 bytes before: {list(context[-20:])}")


if __name__ == "__main__":
    main()
