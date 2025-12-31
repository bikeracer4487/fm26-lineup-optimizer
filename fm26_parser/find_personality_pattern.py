#!/usr/bin/env python3
"""
Search for personality pattern directly in Brix10.
Looking for sequence of {5,10,15,20,25,30,35,40} plus 45 (Versatility) within close proximity.
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

    print("Loading Brix10...")
    dec10 = FM26Decompressor(base / "Brixham10.fm")
    dec10.load()
    data10 = dec10.decompress_main_database()

    name = "Isaac James Smith"
    pos10 = find_string_position(data10, name)
    print(f"Isaac at {pos10:,} in Brix10")

    # Search for a window containing ALL of: 5, 10, 15, 20, 25, 30, 35, 40, 45
    personality_set = {5, 10, 15, 20, 25, 30, 35, 40, 45}

    print("\n" + "="*80)
    print("SEARCHING ENTIRE DATABASE FOR WINDOWS CONTAINING ALL 9 PERSONALITY VALUES")
    print("{5, 10, 15, 20, 25, 30, 35, 40, 45}")
    print("="*80)

    # This is expensive but we need to find the personality block
    window_size = 100  # Search in 100-byte windows
    found_windows = []

    for i in range(0, len(data10) - window_size, 10):  # Step by 10 for speed
        window = data10[i:i+window_size]
        values_found = set(b for b in window if b in personality_set)

        if len(values_found) >= 8:  # At least 8 of 9 values
            found_windows.append((i, values_found))

    print(f"\nFound {len(found_windows)} windows with 8+ personality values")

    # Show windows closest to Isaac's position
    found_windows.sort(key=lambda x: abs(x[0] - pos10))

    print("\n  Closest to Isaac's name:")
    for pos, vals in found_windows[:20]:
        dist = pos - pos10
        print(f"    pos={pos:,} (dist {dist:+,}): has {sorted(vals)}")

    # Also search for the EXACT sequence if they're stored contiguously
    print("\n" + "="*80)
    print("SEARCHING FOR BYTES 5-40 IN SEQUENCE (with small gaps)")
    print("="*80)

    # Look for runs where we have multiple personality values close together
    run_threshold = 5  # At least 5 values within 30 bytes

    for i in range(len(data10) - 30):
        window = data10[i:i+30]
        matches = [j for j, b in enumerate(window) if b in personality_set]

        if len(matches) >= run_threshold:
            values = [window[j] for j in matches]
            unique_vals = sorted(set(values))

            # Only report if we have diverse values (not all the same)
            if len(unique_vals) >= 5:
                dist = i - pos10
                if abs(dist) < 20000:  # Only if somewhat near Isaac
                    print(f"  pos={i:,} (dist {dist:+,}): values={unique_vals}")

    # Maybe Isaac's personality is linked by ID?
    # Let's search for Isaac's player ID
    print("\n" + "="*80)
    print("LOOKING FOR PLAYER ID PATTERNS")
    print("="*80)

    # Search for 4-byte patterns near Isaac that might be his ID
    # Then search for same pattern near personality clusters

    # First, get bytes around Isaac
    context_before = data10[pos10-50:pos10]
    print("\n50 bytes BEFORE Isaac's name (potential IDs/refs):")
    print(f"  {list(context_before)}")

    # Look for 4-byte sequences that could be IDs
    for offset in range(46, 0, -4):
        four_bytes = context_before[offset:offset+4]
        if len(four_bytes) == 4:
            val = int.from_bytes(four_bytes, 'little')
            if 1000 < val < 10000000:  # Reasonable ID range
                print(f"  offset -{50-offset}: 4-byte value = {val}")

    # Also check common FM patterns: byte before name length is often a marker
    print(f"\n  Byte at -1: {context_before[-1]}")  # Should be 16 (name length)
    print(f"  Byte at -2: {context_before[-2]}")
    print(f"  Byte at -5: {context_before[-5]}")
    print(f"  Bytes at -8 to -5: {list(context_before[-8:-4])}")

    # Search entire database for where personality might correlate
    # Let's look for a region that has CHANGED values matching all our expected values
    print("\n" + "="*80)
    print("LOADING BASE TO COMPARE - Looking for CHANGED regions with all personality values")
    print("="*80)

    dec_base = FM26Decompressor(base / "Brixham.fm")
    dec_base.load()
    base_data = dec_base.decompress_main_database()
    base_pos = find_string_position(base_data, name)

    shift = pos10 - base_pos
    print(f"Base Isaac at {base_pos:,}, shift={shift}")

    # Find ALL byte positions where (base==50 AND brix10 in {5,10,15,20,25,30,35,40})
    # Group these by proximity
    personality_changes = []

    for i in range(min(len(base_data), len(data10) - shift)):
        j = i + shift
        if j < 0 or j >= len(data10):
            continue

        if base_data[i] == 50 and data10[j] in {5, 10, 15, 20, 25, 30, 35, 40}:
            personality_changes.append((i, data10[j]))

    print(f"\nTotal 50->personality changes: {len(personality_changes)}")

    # Find the cluster CLOSEST to Isaac
    if personality_changes:
        personality_changes.sort(key=lambda x: abs(x[0] - base_pos))
        print("\nClosest 50->personality changes to Isaac's base position:")
        for pos, new_val in personality_changes[:30]:
            dist = base_pos - pos
            print(f"  base_pos={pos:,} (offset {dist:+,}): 50 -> {new_val}")

    # Check if there's any correlation with the known attribute positions
    print("\n" + "="*80)
    print("CHECKING KNOWN ATTRIBUTE AREA FOR PERSONALITY")
    print("Attributes are at -4100 to -4200 range")
    print("="*80)

    # Read larger area around known attributes
    for offset in range(4250, 4050, -1):
        base_check = base_pos - offset
        mod_check = pos10 - offset

        if base_check < 0 or mod_check < 0:
            continue
        if base_check >= len(base_data) or mod_check >= len(data10):
            continue

        base_val = base_data[base_check]
        mod_val = data10[mod_check]

        # Show if base was 50 (expected personality base)
        if base_val == 50:
            print(f"  {-offset:>+5}: 50 -> {mod_val:>3}")
        # Or if base was 85 (Versatility)
        elif base_val == 85:
            print(f"  {-offset:>+5}: 85 -> {mod_val:>3} (potential Versatility)")


if __name__ == "__main__":
    main()
