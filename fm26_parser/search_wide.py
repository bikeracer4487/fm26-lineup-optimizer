#!/usr/bin/env python3
"""
Search a much wider range with variable alignment compensation.
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

    print(f"Base: Isaac at {base_pos:,}")
    print(f"Brix10: Isaac at {pos10:,}")
    print(f"File size diff: {len(data10) - len(base_data):+,}")
    print(f"Position shift: {pos10 - base_pos:+,}")

    # The problem: file structure changed, so fixed offset doesn't work
    # Solution: for each position in base, try multiple alignment offsets

    print("\n" + "="*80)
    print("SEARCHING WITH VARIABLE ALIGNMENT")
    print("Checking base positions 0-15000 bytes before Isaac")
    print("With alignment offsets 0 to +1000")
    print("="*80)

    # Personality expected: 50 -> 5/10/15/20/25/30/35/40
    personality_targets = {5, 10, 15, 20, 25, 30, 35, 40}

    found_matches = []

    for offset in range(0, 15000):
        base_check_pos = base_pos - offset

        if base_check_pos < 0:
            continue

        base_val = base_data[base_check_pos]

        # Only check if base value is 50 (expected original personality)
        if base_val != 50:
            continue

        # Try different alignments in Brix10
        for align in range(0, 1000):
            mod_check_pos = pos10 - offset + align

            if mod_check_pos < 0 or mod_check_pos >= len(data10):
                continue

            mod_val = data10[mod_check_pos]

            if mod_val in personality_targets:
                found_matches.append((offset, align, mod_val))

    print(f"\nFound {len(found_matches)} potential matches")

    # Group by alignment to find consistent alignment
    by_align = {}
    for offset, align, val in found_matches:
        if align not in by_align:
            by_align[align] = []
        by_align[align].append((offset, val))

    print("\nMatches grouped by alignment offset:")
    for align in sorted(by_align.keys()):
        matches = by_align[align]
        if len(matches) >= 5:  # At least 5 matches at this alignment
            unique_vals = sorted(set(v for _, v in matches))
            print(f"\n  Alignment +{align}: {len(matches)} matches")
            print(f"    Unique target values: {unique_vals}")
            if len(unique_vals) >= 6:
                print(f"    *** LIKELY PERSONALITY BLOCK! ***")
                for off, val in sorted(matches)[:15]:
                    print(f"      offset -{off}: 50 -> {val} ({val//5})")

    # Also search specifically around offset 9800-10000 where we saw clusters
    print("\n" + "="*80)
    print("DETAILED SEARCH AROUND OFFSET 9800-10200")
    print("="*80)

    for offset in range(9800, 10200):
        base_check_pos = base_pos - offset

        if base_check_pos < 0:
            continue

        base_val = base_data[base_check_pos]

        # Check with alignment 480 (the nominal shift)
        mod_check_pos = pos10 - offset

        if mod_check_pos < 0 or mod_check_pos >= len(data10):
            continue

        mod_val = data10[mod_check_pos]

        if base_val != mod_val:
            is_base_attr = (base_val % 5 == 0 and 5 <= base_val <= 100)
            is_mod_attr = (mod_val % 5 == 0 and 5 <= mod_val <= 100)

            if is_base_attr or is_mod_attr:
                print(f"  -{offset}: {base_val} -> {mod_val}")


if __name__ == "__main__":
    main()
