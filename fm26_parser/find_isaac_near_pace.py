#!/usr/bin/env python3
"""
Find the Isaac record near the known Pace offset.

We know Isaac Smith's Pace is at offset 165,660,358 in Brixham.fm/Brixham2.fm.
Let's search for any identifying strings near that offset.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor


def find_strings_in_region(data: bytes, center: int, window: int = 5000) -> list:
    """Find all length-prefixed strings in a region."""
    strings = []
    start = max(0, center - window)
    end = min(len(data), center + window)

    pos = start
    while pos < end - 4:
        length = int.from_bytes(data[pos:pos+4], 'little')
        if 2 <= length <= 50:
            try:
                candidate = data[pos+4:pos+4+length].decode('utf-8')
                if all(c.isprintable() or c.isspace() for c in candidate):
                    strings.append({
                        'offset': pos + 4,
                        'relative': pos + 4 - center,
                        'length': length,
                        'string': candidate
                    })
                    pos += 4 + length
                    continue
            except:
                pass
        pos += 1

    return strings


def analyze_known_pace_region(data1, data2, data3, pace_offset: int, player_name: str):
    """Analyze region around known Pace offset."""
    print(f"\n{'='*70}")
    print(f"ANALYZING {player_name} REGION")
    print(f"Known Pace offset: {pace_offset:,} ({hex(pace_offset)})")
    print("="*70)

    # Show Pace byte across saves
    print(f"\nPace byte values:")
    print(f"  Brixham.fm:  {data1[pace_offset]:3d} (Pace ~{round(data1[pace_offset]/5)})")
    print(f"  Brixham2.fm: {data2[pace_offset]:3d} (Pace ~{round(data2[pace_offset]/5)})")
    if pace_offset < len(data3):
        print(f"  Brixham3.fm: {data3[pace_offset]:3d} (structure shifted, not Pace)")
    else:
        print(f"  Brixham3.fm: out of range")

    # Find strings near the Pace offset
    print(f"\nStrings within 5000 bytes of Pace offset:")
    strings = find_strings_in_region(data1, pace_offset, 5000)

    # Sort by proximity
    strings.sort(key=lambda s: abs(s['relative']))

    for s in strings[:30]:
        print(f"  {s['relative']:+6d}: '{s['string']}'")

    # Look for player-identifying patterns
    print(f"\nSearching for player record boundaries...")

    # Check bytes immediately around Pace for attribute-like values
    print(f"\nBytes around Pace offset (potential attributes):")
    print(f"{'Rel':>6} | {'Brix1':>5} | {'Brix2':>5} | {'Scaled1':>8} | Notes")
    print("-" * 60)

    for rel in range(-50, 51):
        abs_pos = pace_offset + rel
        if abs_pos < 0 or abs_pos >= len(data1) or abs_pos >= len(data2):
            continue

        v1 = data1[abs_pos]
        v2 = data2[abs_pos]

        notes = []
        if v1 != v2:
            notes.append(f"CHANGED: {v1}→{v2}")
        elif 20 <= v1 <= 100:
            notes.append(f"attr? (={round(v1/5)})")

        if rel == 0:
            notes.append("PACE")

        scaled = round(v1 / 5)
        note_str = ", ".join(notes)
        print(f"{rel:>+6} | {v1:>5} | {v2:>5} | {scaled:>8} | {note_str}")


def find_isaac_attr_region_in_brix3(data1, data2, data3, pace_offset_brix12: int):
    """
    Since Brix3 structure shifted, we need to find Isaac's attributes differently.

    Strategy: In Brix2, Isaac has Pace=100 and Accel=65.
              In Brix3, Isaac has Pace=100 and Accel=100.

    Find a region in Brix3 where:
    - Pace byte = 100
    - Nearby byte changed from ~65 to 100 (Acceleration)
    """
    print(f"\n{'='*70}")
    print("FINDING ISAAC'S ATTRIBUTES IN BRIXHAM3 (SHIFTED STRUCTURE)")
    print("="*70)

    # Since Brix1 and Brix2 have same structure, analyze Brix2 to understand
    # what attributes look like around the Pace offset

    # Get the attribute pattern from Brix2
    window = 50
    start = pace_offset_brix12 - window
    brix2_region = data2[start:start + window * 2]

    print(f"\nBrix2 region pattern (around Pace offset):")
    print(f"Bytes: {list(brix2_region)}")

    # Look for specific values that might be attributes
    # Isaac's known attributes (from FM26):
    # Pace: 20 (100 internal), Acceleration: 13 (65 internal)
    # We changed Accel to 20 (100 internal) in Brix3

    # Find the Acceleration byte in Brix2 (should be ~65)
    print(f"\nLooking for Acceleration (~65) near Pace (100) in Brix2:")
    for rel in range(-30, 31):
        abs_pos = pace_offset_brix12 + rel
        v2 = data2[abs_pos]
        v1 = data1[abs_pos]

        if 60 <= v2 <= 70:  # Potential Acceleration (~65 = 13 on 1-20 scale)
            print(f"  Offset {rel:+3d}: v1={v1}, v2={v2} (scaled ~{round(v2/5)})")

    # Now search Brix3 for a region where Pace=100 and a nearby byte=100
    # that was previously ~65
    print(f"\nSearching Brix3 for matching attribute pattern...")

    # This is tricky because structure shifted. Let's try to find
    # the sequence of attribute values that match Isaac's profile

    # Known attributes (approximate 0-100 scale):
    # We need more data points to identify the unique pattern

    # Alternative: compare total bytes changed between Brix2 and Brix3
    # There should be exactly ONE byte that changed to 100 (Acceleration)

    # Since sizes differ, let's look at the actual bytes that differ
    # when comparing equal-sized regions

    # Actually, let me try finding the Pace=100 + Accel=100 pattern in Brix3
    print("\nSearching for Pace=100 + nearby Accel=100 pattern in Brix3...")

    candidates = []
    for i in range(len(data3) - 50):
        if data3[i] == 100:  # Potential Pace
            # Check nearby bytes for another 100
            for offset in range(1, 30):
                if i + offset < len(data3) and data3[i + offset] == 100:
                    # Found two 100s nearby
                    # Check if this region matches Isaac's other attributes

                    # Get surrounding bytes
                    region_start = max(0, i - 20)
                    region = data3[region_start:i + 50]

                    # Count how many bytes are in attribute range (20-100)
                    attr_count = sum(1 for b in region if 20 <= b <= 100)

                    if attr_count >= 10:  # Looks like an attribute cluster
                        candidates.append({
                            'pos': i,
                            'offset_to_second_100': offset,
                            'attr_count': attr_count
                        })
                    break  # Only need first match

    print(f"Found {len(candidates)} potential attribute clusters")

    # For each candidate, check if the position existed in Brix2 and had the right pattern
    matches = []
    for c in candidates[:1000]:  # Check first 1000
        pos = c['pos']

        # Account for structure shift - try nearby positions in Brix2
        # The shift is about 951 bytes, so check within that range
        for shift in range(-1000, 1001):
            brix2_pos = pos + shift
            if brix2_pos < 0 or brix2_pos >= len(data2):
                continue

            if data2[brix2_pos] == 100:  # Pace was 100 in Brix2 too
                # Check if Acceleration position matches
                accel_pos_brix3 = pos + c['offset_to_second_100']
                accel_pos_brix2 = brix2_pos + c['offset_to_second_100']

                if accel_pos_brix2 < len(data2):
                    v2_accel = data2[accel_pos_brix2]
                    v3_accel = data3[accel_pos_brix3]

                    # Should be: ~65 in Brix2, 100 in Brix3
                    if 60 <= v2_accel <= 70 and v3_accel == 100:
                        matches.append({
                            'brix3_pace': pos,
                            'brix2_pace': brix2_pos,
                            'accel_offset': c['offset_to_second_100'],
                            'shift': shift,
                            'brix2_accel': v2_accel,
                            'brix3_accel': v3_accel
                        })

    print(f"\nFound {len(matches)} matching attribute patterns!")

    for m in matches[:10]:
        print(f"\n  Brix2 Pace at {m['brix2_pace']:,}")
        print(f"  Brix3 Pace at {m['brix3_pace']:,} (shift: {m['shift']:+d})")
        print(f"  Accel at offset +{m['accel_offset']}")
        print(f"  Accel change: {m['brix2_accel']} → {m['brix3_accel']}")


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
    print(f"Size difference (Brix3 - Brix2): {len(data3) - len(data2):+d} bytes")

    # Known Pace offset from original diff
    isaac_pace_offset = 165660358

    # Analyze the known region
    analyze_known_pace_region(data1, data2, data3, isaac_pace_offset, "ISAAC SMITH")

    # Try to find the same attributes in Brix3
    find_isaac_attr_region_in_brix3(data1, data2, data3, isaac_pace_offset)


if __name__ == "__main__":
    main()
