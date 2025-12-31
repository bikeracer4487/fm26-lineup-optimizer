#!/usr/bin/env python3
"""
Compare a specific player's record between two saves.

Instead of byte-by-byte file comparison, this finds the player by name
and compares the attribute bytes around them.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor
from fm26_parser.core.binary_reader import BinaryReader


def find_player_record(data: bytes, first_name: str, last_name: str) -> list:
    """Find all occurrences of a player by first + last name pattern."""
    records = []

    # Search pattern: [4-byte len][first_name][4-byte len][last_name]
    first_bytes = first_name.encode('utf-8')
    last_bytes = last_name.encode('utf-8')

    first_pattern = len(first_bytes).to_bytes(4, 'little') + first_bytes
    last_pattern = len(last_bytes).to_bytes(4, 'little') + last_bytes

    # Find all last name occurrences
    reader = BinaryReader(data)
    last_positions = reader.find_all(last_pattern)

    for last_pos in last_positions:
        # Check if first name is just before last name
        expected_first_pos = last_pos - len(first_pattern)

        if expected_first_pos >= 0:
            if data[expected_first_pos:expected_first_pos + len(first_pattern)] == first_pattern:
                # Found the player!
                records.append({
                    'first_name_offset': expected_first_pos + 4,  # After length prefix
                    'last_name_offset': last_pos + 4,  # After length prefix
                    'record_start': expected_first_pos,
                    'name_end': last_pos + 4 + len(last_bytes)
                })

    return records


def extract_attribute_region(data: bytes, name_end: int, size: int = 200) -> bytes:
    """Extract bytes after the player name (attribute region)."""
    end = min(len(data), name_end + size)
    return data[name_end:end]


def compare_attribute_regions(region1: bytes, region2: bytes) -> list:
    """Compare two attribute regions and return differences."""
    changes = []
    min_len = min(len(region1), len(region2))

    for i in range(min_len):
        if region1[i] != region2[i]:
            changes.append({
                'relative_offset': i,
                'save1_value': region1[i],
                'save2_value': region2[i],
                'delta': region2[i] - region1[i]
            })

    return changes


def main():
    save1_path = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games/Brixham2.fm")
    save2_path = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games/Brixham3.fm")

    # Player to compare
    first_name = "Isaac"
    last_name = "Smith"

    print("="*70)
    print(f"COMPARING {first_name} {last_name}'S RECORD BETWEEN SAVES")
    print("="*70)
    print(f"\nSave 1: {save1_path.name} (Pace=20, Acceleration=13)")
    print(f"Save 2: {save2_path.name} (Pace=20, Acceleration=20)")
    print(f"\nExpected change: Acceleration 13 -> 20 (scaled: ~65 -> 100)")

    # Load saves
    print("\nLoading saves...")
    dec1 = FM26Decompressor(save1_path)
    dec1.load()
    data1 = dec1.decompress_main_database()

    dec2 = FM26Decompressor(save2_path)
    dec2.load()
    data2 = dec2.decompress_main_database()

    print(f"Save 1 size: {len(data1):,} bytes")
    print(f"Save 2 size: {len(data2):,} bytes")

    # Find player in both saves
    print(f"\nSearching for {first_name} {last_name}...")

    records1 = find_player_record(data1, first_name, last_name)
    records2 = find_player_record(data2, first_name, last_name)

    print(f"Found in Save 1: {len(records1)} records")
    print(f"Found in Save 2: {len(records2)} records")

    if not records1 or not records2:
        print("ERROR: Player not found in one or both saves!")

        # Try to find by last name only
        print("\nTrying last name only search...")
        reader1 = BinaryReader(data1)
        last_pattern = len(last_name.encode()).to_bytes(4, 'little') + last_name.encode()
        positions = reader1.find_all(last_pattern)
        print(f"Found '{last_name}' {len(positions)} times in Save 1")

        # Show context of first few
        for pos in positions[:5]:
            context_start = max(0, pos - 20)
            context = data1[context_start:pos+len(last_pattern)+10]
            print(f"  Offset {pos}: {context}")
        return

    # Compare each matching pair
    print("\n" + "="*70)
    print("ATTRIBUTE REGION COMPARISON")
    print("="*70)

    for i, (rec1, rec2) in enumerate(zip(records1, records2)):
        print(f"\nRecord pair {i+1}:")
        print(f"  Save 1 offset: {rec1['record_start']:,} ({hex(rec1['record_start'])})")
        print(f"  Save 2 offset: {rec2['record_start']:,} ({hex(rec2['record_start'])})")

        # Extract attribute regions
        attr1 = extract_attribute_region(data1, rec1['name_end'], 200)
        attr2 = extract_attribute_region(data2, rec2['name_end'], 200)

        # Compare
        changes = compare_attribute_regions(attr1, attr2)

        if changes:
            print(f"\n  Changes found: {len(changes)}")
            for change in changes[:30]:
                marker = ""
                # Check if this could be Acceleration (65 -> 100)
                if change['save1_value'] == 65 and change['save2_value'] == 100:
                    marker = " <-- ACCELERATION (65 -> 100)!"
                elif change['delta'] == 35:
                    marker = " <-- delta +35 (possible attribute)"

                print(f"    Offset +{change['relative_offset']:3d}: "
                      f"{change['save1_value']:3d} -> {change['save2_value']:3d} "
                      f"(delta: {change['delta']:+4d}){marker}")

            # Show surrounding context for first change
            if changes:
                first_change = changes[0]
                print(f"\n  Context around first change (offset +{first_change['relative_offset']}):")
                print(f"  Save 1 bytes: {list(attr1[max(0,first_change['relative_offset']-10):first_change['relative_offset']+11])}")
                print(f"  Save 2 bytes: {list(attr2[max(0,first_change['relative_offset']-10):first_change['relative_offset']+11])}")
        else:
            print("  No changes in attribute region!")

        # Also show the raw attribute bytes for analysis
        print(f"\n  First 50 attribute bytes (Save 1):")
        print(f"  {list(attr1[:50])}")
        print(f"\n  First 50 attribute bytes (Save 2):")
        print(f"  {list(attr2[:50])}")


if __name__ == "__main__":
    main()
