#!/usr/bin/env python3
"""
Detailed attribute mapping - shows ALL changes including ambiguous ones.
"""

import sys
from pathlib import Path
import json

sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor


def find_string_position(data: bytes, target: str) -> int:
    target_bytes = target.encode('utf-8')
    pattern = len(target_bytes).to_bytes(4, 'little') + target_bytes
    pos = data.find(pattern)
    return pos + 4 if pos != -1 else -1


def analyze_detailed(base_data, base_pos, mod_data, mod_pos, changes, category_name):
    """Show ALL changes in detail."""
    print(f"\n{'='*80}")
    print(f"{category_name}")
    print(f"{'='*80}")
    print(f"Base Isaac position: {base_pos:,}")
    print(f"Mod Isaac position: {mod_pos:,}")
    print(f"Shift: {mod_pos - base_pos:+,}")

    # Build lookup
    change_lookup = {}
    for attr, (old_ig, new_ig) in changes.items():
        old_int = old_ig * 5
        new_int = new_ig * 5
        key = (old_int, new_int)
        if key not in change_lookup:
            change_lookup[key] = []
        change_lookup[key].append(attr)

    print(f"\nExpected changes:")
    for key, attrs in sorted(change_lookup.items()):
        if key[0] != key[1]:  # Only show actual changes
            print(f"  ({key[0]:>3}, {key[1]:>3}) = ({key[0]//5:>2} -> {key[1]//5:>2}): {attrs}")

    # Find all changes in the attribute region
    print(f"\nActual changes found:")
    changes_found = []
    for offset in range(4200, 3800, -1):
        pos_base = base_pos - offset
        pos_mod = mod_pos - offset

        if pos_base < 0 or pos_mod < 0:
            continue
        if pos_base >= len(base_data) or pos_mod >= len(mod_data):
            continue

        old_val = base_data[pos_base]
        new_val = mod_data[pos_mod]

        if old_val != new_val:
            key = (old_val, new_val)
            attrs = change_lookup.get(key, [])

            # Check if this is a valid attribute change (multiples of 5)
            is_attr = (old_val % 5 == 0 and new_val % 5 == 0 and
                       5 <= old_val <= 100 and 5 <= new_val <= 100)

            if attrs:
                status = f"-> {attrs}"
            elif is_attr:
                status = f"(unmapped attr-like: {old_val//5} -> {new_val//5})"
            else:
                status = f"(non-attr: {old_val} -> {new_val})"

            changes_found.append({
                'offset': -offset,
                'old': old_val,
                'new': new_val,
                'attrs': attrs,
                'status': status
            })

            print(f"  {-offset:>+5}: ({old_val:>3}, {new_val:>3}) {status}")

    print(f"\nTotal changes found: {len(changes_found)}")

    # Map what we can
    mapped = {}

    # First pass: unique matches
    for c in changes_found:
        if len(c['attrs']) == 1:
            attr = c['attrs'][0]
            if attr not in mapped:
                mapped[attr] = c['offset']

    # Second pass: disambiguate
    for c in changes_found:
        if len(c['attrs']) > 1:
            remaining = [a for a in c['attrs'] if a not in mapped]
            if len(remaining) == 1:
                mapped[remaining[0]] = c['offset']

    return mapped


def main():
    base = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")
    name = "Isaac James Smith"

    # Load base and one modified save for detailed analysis
    print("Loading saves...")

    dec_base = FM26Decompressor(base / "Brixham.fm")
    dec_base.load()
    base_data = dec_base.decompress_main_database()
    base_pos = find_string_position(base_data, name)

    saves_to_analyze = [
        ('Brixham9.fm', 'Position Familiarity', {
            'GK Familiarity': (1, 1),
            'DL Familiarity': (1, 2),
            'DC Familiarity': (20, 3),
            'DR Familiarity': (1, 4),
            'WBL Familiarity': (1, 5),
            'WBR Familiarity': (1, 6),
            'DM Familiarity': (16, 7),
            'ML Familiarity': (1, 8),
            'MC Familiarity': (1, 9),
            'MR Familiarity': (1, 10),
            'AML Familiarity': (1, 11),
            'AMC Familiarity': (1, 12),
            'AMR Familiarity': (1, 13),
            'ST Familiarity': (1, 14),
        }),
        ('Brixham10.fm', 'Personality', {
            'Adaptability': (10, 1),
            'Ambition': (10, 2),
            'Controversy': (10, 3),
            'Loyalty': (10, 4),
            'Pressure': (10, 5),
            'Professionalism': (10, 6),
            'Sportsmanship': (10, 7),
            'Temperament': (10, 8),
            'Versatility': (17, 9),
            'Left Foot': (11, 20),
            'Right Foot': (20, 19),
        }),
    ]

    all_mapped = {}

    for save_name, category, changes in saves_to_analyze:
        dec = FM26Decompressor(base / save_name)
        dec.load()
        mod_data = dec.decompress_main_database()
        mod_pos = find_string_position(mod_data, name)

        mapped = analyze_detailed(base_data, base_pos, mod_data, mod_pos, changes, f"{save_name} - {category}")
        all_mapped.update(mapped)

    # Now let's look for personality changes more carefully
    print("\n" + "="*80)
    print("SCANNING FOR SPECIFIC VALUE PATTERNS IN BRIX10")
    print("="*80)

    dec10 = FM26Decompressor(base / "Brixham10.fm")
    dec10.load()
    data10 = dec10.decompress_main_database()
    pos10 = find_string_position(data10, name)

    print(f"\nLooking for (50, X) patterns where X is 5,10,15,20,25,30,35,40,45:")
    print("(This is personality: all original=10, changed to 1-9)")

    for offset in range(4200, 4000, -1):
        pos_b = base_pos - offset
        pos_m = pos10 - offset

        if pos_b < 0 or pos_m < 0:
            continue
        if pos_b >= len(base_data) or pos_m >= len(data10):
            continue

        old_val = base_data[pos_b]
        new_val = data10[pos_m]

        # Look for original=50 (in-game 10) changing to 5-45 (in-game 1-9)
        if old_val == 50 and 5 <= new_val <= 45 and new_val % 5 == 0:
            print(f"  {-offset:>+5}: 50 -> {new_val} (10 -> {new_val//5})")


if __name__ == "__main__":
    main()
