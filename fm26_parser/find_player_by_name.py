#!/usr/bin/env python3
"""
Find a specific player's record in each save independently.

Instead of comparing fixed offsets, find the player by name in each save,
then compare the attribute bytes relative to their record position.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor


def find_length_prefixed_string(data: bytes, target: str) -> list:
    """Find all occurrences of a length-prefixed string."""
    target_bytes = target.encode('utf-8')
    pattern = len(target_bytes).to_bytes(4, 'little') + target_bytes

    positions = []
    pos = 0
    while True:
        pos = data.find(pattern, pos)
        if pos == -1:
            break
        positions.append(pos + 4)  # Return position of actual string, not length prefix
        pos += 1

    return positions


def find_nearby_string(data: bytes, center: int, target: str, window: int = 200) -> list:
    """Find occurrences of a string near a given position."""
    target_bytes = target.encode('utf-8')
    pattern = len(target_bytes).to_bytes(4, 'little') + target_bytes

    start = max(0, center - window)
    end = min(len(data), center + window)
    region = data[start:end]

    matches = []
    pos = 0
    while True:
        pos = region.find(pattern, pos)
        if pos == -1:
            break
        matches.append({
            'absolute': start + pos + 4,
            'relative': start + pos + 4 - center,
            'string': target
        })
        pos += 1

    return matches


def show_region_with_ascii(data: bytes, start: int, length: int, title: str):
    """Show a region of bytes with ASCII interpretation."""
    print(f"\n{title}")
    print(f"Offset {start:,} to {start + length:,}")
    print("-" * 80)

    end = min(start + length, len(data))
    region = data[start:end]

    for i in range(0, len(region), 32):
        chunk = region[i:i+32]
        hex_str = ' '.join(f'{b:02x}' for b in chunk)
        ascii_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
        print(f"  {start+i:10d}: {ascii_str}")
        print(f"  {'':10s}  {hex_str}")


def find_smith_isaac_occurrences(data: bytes, save_name: str):
    """Find all occurrences where 'Isaac' and 'Smith' are close together."""
    print(f"\n{'='*70}")
    print(f"SEARCHING IN {save_name}")
    print("="*70)

    # Find all "Isaac" positions
    isaac_positions = find_length_prefixed_string(data, "Isaac")
    print(f"Found 'Isaac': {len(isaac_positions)} occurrences")

    # Find all "Smith" positions
    smith_positions = find_length_prefixed_string(data, "Smith")
    print(f"Found 'Smith': {len(smith_positions)} occurrences")

    # For each Isaac, check if Smith is nearby (within 100 bytes after)
    isaac_smith_pairs = []
    for isaac_pos in isaac_positions:
        for smith_pos in smith_positions:
            # Smith should come shortly after Isaac (first name, then last name)
            distance = smith_pos - isaac_pos
            if 5 < distance < 50:  # Smith should be 5-50 bytes after Isaac
                isaac_smith_pairs.append({
                    'isaac_pos': isaac_pos,
                    'smith_pos': smith_pos,
                    'distance': distance
                })

    print(f"Found 'Isaac' + 'Smith' pairs: {len(isaac_smith_pairs)}")

    return isaac_smith_pairs


def extract_player_region(data: bytes, isaac_pos: int, window_before: int = 100, window_after: int = 200):
    """Extract bytes around a player name occurrence."""
    start = max(0, isaac_pos - window_before)
    end = min(len(data), isaac_pos + window_after)
    return start, data[start:end]


def compare_isaac_smith_across_saves(data1, data2, data3):
    """Compare Isaac Smith's record across all three saves."""

    # Find Isaac+Smith in each save
    pairs1 = find_smith_isaac_occurrences(data1, "Brixham.fm (Original)")
    pairs2 = find_smith_isaac_occurrences(data2, "Brixham2.fm (Pace=100)")
    pairs3 = find_smith_isaac_occurrences(data3, "Brixham3.fm (Pace+Accel=100)")

    if not pairs1 or not pairs2 or not pairs3:
        print("\nCouldn't find Isaac Smith in all three saves!")

        # Try alternative search - just "Isaac" near attributes
        print("\nTrying alternative: searching for 'Isaac' near potential attributes...")
        for name, data in [("Brixham.fm", data1), ("Brixham2.fm", data2), ("Brixham3.fm", data3)]:
            isaac_positions = find_length_prefixed_string(data, "Isaac")
            print(f"\n{name}: {len(isaac_positions)} 'Isaac' occurrences")
            for pos in isaac_positions[:5]:
                # Show context and look for byte 100 nearby
                region_start = max(0, pos - 50)
                region = data[region_start:pos + 150]
                has_100 = 100 in region
                print(f"  At {pos:,}: has_100_nearby = {has_100}")
                if has_100:
                    # Find where the 100 is
                    for i, b in enumerate(region):
                        if b == 100:
                            rel = i - 50  # Relative to name position
                            print(f"    100 found at relative offset {rel:+d}")
        return

    # Compare the records
    print("\n" + "="*70)
    print("COMPARING ISAAC SMITH RECORDS")
    print("="*70)

    # Use first occurrence of each (assuming it's the player we want)
    # In practice, we'd need to verify this is the right Isaac Smith
    pair1 = pairs1[0]
    pair2 = pairs2[0]
    pair3 = pairs3[0]

    print(f"\nIsaac Smith positions:")
    print(f"  Brixham.fm:  Isaac at {pair1['isaac_pos']:,}, Smith at {pair1['smith_pos']:,}")
    print(f"  Brixham2.fm: Isaac at {pair2['isaac_pos']:,}, Smith at {pair2['smith_pos']:,}")
    print(f"  Brixham3.fm: Isaac at {pair3['isaac_pos']:,}, Smith at {pair3['smith_pos']:,}")

    # Extract regions around each player
    start1, region1 = extract_player_region(data1, pair1['isaac_pos'])
    start2, region2 = extract_player_region(data2, pair2['isaac_pos'])
    start3, region3 = extract_player_region(data3, pair3['isaac_pos'])

    print(f"\nRegion sizes: {len(region1)}, {len(region2)}, {len(region3)}")

    # Compare byte by byte from the name position (relative comparison)
    print("\nComparing bytes (relative to 'Isaac' position):")
    print(f"{'Rel':>6} | {'Brix1':>5} | {'Brix2':>5} | {'Brix3':>5} | Notes")
    print("-" * 70)

    min_len = min(len(region1), len(region2), len(region3))
    for i in range(100, min_len):  # Start after the name area
        rel = i - 100  # Relative to Isaac position
        v1 = region1[i]
        v2 = region2[i]
        v3 = region3[i]

        notes = []
        if v1 != v2:
            notes.append(f"1→2: {v1}→{v2}")
        if v2 != v3:
            notes.append(f"2→3: {v2}→{v3}")
        if v3 == 100 and v2 == 100 and v1 != 100:
            notes.append("PACE?")
        if v3 == 100 and v2 != 100:
            notes.append("ACCEL?")

        if notes:
            note_str = ", ".join(notes)
            print(f"{rel:>+6} | {v1:>5} | {v2:>5} | {v3:>5} | {note_str}")


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

    compare_isaac_smith_across_saves(data1, data2, data3)


if __name__ == "__main__":
    main()
