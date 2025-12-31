#!/usr/bin/env python3
"""
Exhaustive search for Isaac's modified attributes in Brix3.

The calculated offset shows original values (52, 65).
But if the save was actually modified, the changed values must be somewhere.

Let's search for ALL occurrences of the expected attribute pattern.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor


def find_string_position(data: bytes, target: str) -> list:
    """Find all occurrences of a length-prefixed string."""
    target_bytes = target.encode('utf-8')
    pattern = len(target_bytes).to_bytes(4, 'little') + target_bytes

    positions = []
    pos = 0
    while True:
        pos = data.find(pattern, pos)
        if pos == -1:
            break
        positions.append(pos + 4)
        pos += 1

    return positions


def main():
    base = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")

    print("Loading saves...")

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

    # Find Isaac James Smith
    name = "Isaac James Smith"
    isaac_positions = {
        'Brix1': find_string_position(data1, name),
        'Brix2': find_string_position(data2, name),
        'Brix3': find_string_position(data3, name),
    }

    print(f"\n{name} positions:")
    for save, positions in isaac_positions.items():
        print(f"  {save}: {positions}")

    # Get the attribute region from Brix2 (where we know Pace=100)
    # This is the "known good" pattern
    print(f"\n{'='*70}")
    print("KNOWN ATTRIBUTE PATTERN FROM BRIX2")
    print("="*70)

    isaac_name_brix2 = isaac_positions['Brix2'][0]
    pace_offset_brix2 = isaac_name_brix2 - 4113

    # Get a unique signature of Isaac's attributes (excluding Pace and Accel)
    # Use bytes from -50 to -5 (before Pace) and +5 to +15 (after Accel)
    attr_signature_before = data2[pace_offset_brix2 - 50:pace_offset_brix2 - 5]
    attr_signature_after = data2[pace_offset_brix2 + 5:pace_offset_brix2 + 16]

    print(f"\nSignature before Pace: {list(attr_signature_before)}")
    print(f"Signature after Accel: {list(attr_signature_after)}")

    # Search for this signature in Brix3
    print(f"\n{'='*70}")
    print("SEARCHING FOR ATTRIBUTE SIGNATURE IN BRIX3")
    print("="*70)

    sig_before_bytes = bytes(attr_signature_before)
    sig_after_bytes = bytes(attr_signature_after)

    # Search for the "before" signature
    print("\nSearching for 'before' signature...")
    before_matches = []
    pos = 0
    while True:
        pos = data3.find(sig_before_bytes, pos)
        if pos == -1:
            break
        before_matches.append(pos)
        pos += 1

    print(f"Found {len(before_matches)} matches for 'before' signature")

    # Search for the "after" signature
    print("\nSearching for 'after' signature...")
    after_matches = []
    pos = 0
    while True:
        pos = data3.find(sig_after_bytes, pos)
        if pos == -1:
            break
        after_matches.append(pos)
        pos += 1

    print(f"Found {len(after_matches)} matches for 'after' signature")

    # For each match, check the Pace and Accel positions
    print(f"\n{'='*70}")
    print("CHECKING PACE/ACCEL AT SIGNATURE MATCHES")
    print("="*70)

    for i, before_pos in enumerate(before_matches[:10]):
        # Pace would be at before_pos + 45 (since signature is -50 to -5)
        pace_pos = before_pos + 45

        if pace_pos + 2 < len(data3):
            pace_val = data3[pace_pos]
            accel_val = data3[pace_pos + 1]

            print(f"\nMatch {i+1} at {before_pos:,}:")
            print(f"  Calculated Pace offset: {pace_pos:,}")
            print(f"  Pace value: {pace_val} (expected: 100 if modified)")
            print(f"  Accel value: {accel_val} (expected: 100 if modified)")

            if pace_val == 100:
                print(f"  *** PACE=100 FOUND! ***")
            if accel_val == 100:
                print(f"  *** ACCEL=100 FOUND! ***")

    # Also compare Brix2 and Brix3 directly at the Pace offset to see what changed
    print(f"\n{'='*70}")
    print("DIRECT COMPARISON OF ISAAC'S ATTRIBUTE REGION")
    print("="*70)

    print("\nBrix1 vs Brix2 (Pace change only):")
    for rel in range(-5, 20):
        v1 = data1[pace_offset_brix2 + rel]
        v2 = data2[pace_offset_brix2 + rel]
        changed = " <-- CHANGED" if v1 != v2 else ""
        print(f"  Offset {rel:+3d}: {v1:3d} → {v2:3d}{changed}")

    # For Brix3, use the shifted position
    isaac_name_brix3 = isaac_positions['Brix3'][0]
    pace_offset_brix3 = isaac_name_brix3 - 4113

    print(f"\nBrix2 vs Brix3 (should show Accel change):")
    print(f"  (Brix2 offset: {pace_offset_brix2:,}, Brix3 offset: {pace_offset_brix3:,})")
    for rel in range(-5, 20):
        v2 = data2[pace_offset_brix2 + rel]
        v3 = data3[pace_offset_brix3 + rel]
        changed = " <-- CHANGED" if v2 != v3 else ""
        print(f"  Offset {rel:+3d}: {v2:3d} → {v3:3d}{changed}")

    # Let's also check if maybe there's a SECOND copy of attributes
    print(f"\n{'='*70}")
    print("CHECKING FOR DUPLICATE ATTRIBUTE STORAGE")
    print("="*70)

    # Search for Pace=100 anywhere near Isaac's name in Brix2
    print(f"\nSearching Brix2 for Pace=100 near Isaac's name...")
    isaac_region_start = max(0, isaac_name_brix2 - 20000)
    isaac_region_end = min(len(data2), isaac_name_brix2 + 5000)

    pace_100_positions = []
    for i in range(isaac_region_start, isaac_region_end):
        if data2[i] == 100:
            pace_100_positions.append(i - isaac_name_brix2)

    print(f"Found {len(pace_100_positions)} bytes with value 100")
    print(f"Relative positions: {pace_100_positions[:30]}...")


if __name__ == "__main__":
    main()
