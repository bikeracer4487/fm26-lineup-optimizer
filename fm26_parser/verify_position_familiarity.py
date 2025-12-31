#!/usr/bin/env python3
"""
Verify position familiarity mapping.
Based on findings, it's at offsets -4118 to -4104, using raw 0-20 scale.
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

    dec9 = FM26Decompressor(base / "Brixham9.fm")
    dec9.load()
    data9 = dec9.decompress_main_database()
    pos9 = find_string_position(data9, name)

    # Also load Brix10 to check if position familiarity is there too
    dec10 = FM26Decompressor(base / "Brixham10.fm")
    dec10.load()
    data10 = dec10.decompress_main_database()
    pos10 = find_string_position(data10, name)

    print(f"Base: Isaac at {base_pos:,}")
    print(f"Brix9: Isaac at {pos9:,}")
    print(f"Brix10: Isaac at {pos10:,}")

    # Hypothesized position familiarity mapping (offsets from Isaac's name position)
    # Based on analysis of Brix9 data
    position_offsets = {
        'GK': -4118,
        'DL': -4116,
        'DC': -4115,
        'DR': -4114,
        'WBL': -4105,
        'DM': -4104,
        'WBR': -4113,
        'ML': -4112,
        'MC': -4111,
        'MR': -4110,
        'AML': -4109,
        'AMC': -4108,
        'AMR': -4107,
        'ST': -4106,
    }

    # User's expected changes for Brix9:
    expected_brix9 = {
        'GK': (1, 1),   # stayed same
        'DL': (1, 2),
        'DC': (20, 3),
        'DR': (1, 4),
        'WBL': (1, 5),
        'DM': (20, 6),
        'WBR': (1, 7),
        'ML': (1, 8),
        'MC': (20, 9),
        'MR': (1, 10),
        'AML': (1, 11),
        'AMC': (20, 12),
        'AMR': (1, 13),
        'ST': (1, 14),
    }

    print("\n" + "="*90)
    print("POSITION FAMILIARITY ANALYSIS")
    print("="*90)
    print(f"\n{'Position':<8} {'Offset':<8} {'Base':<12} {'Brix9':<12} {'Brix10':<12} {'Expected Brix9':<15}")
    print("-"*90)

    for pos_name in ['GK', 'DL', 'DC', 'DR', 'WBL', 'DM', 'WBR', 'ML', 'MC', 'MR', 'AML', 'AMC', 'AMR', 'ST']:
        offset = position_offsets[pos_name]
        exp_old, exp_new = expected_brix9[pos_name]

        base_val = base_data[base_pos + offset]
        brix9_val = data9[pos9 + offset]
        brix10_val = data10[pos10 + offset]

        # Check if it matches expected
        match = "✓" if brix9_val == exp_new else "✗"

        # Convert base to in-game if it's 0-100 scale
        if base_val <= 20:
            base_str = f"{base_val} (raw)"
        else:
            base_str = f"{base_val} ({base_val//5} ig)"

        print(f"{pos_name:<8} {offset:<8} {base_str:<12} {brix9_val:<12} {brix10_val:<12} {exp_new} {match}")

    # Check extended area for more context
    print("\n" + "="*90)
    print("EXTENDED AREA: -4125 to -4095")
    print("="*90)
    print(f"\n{'Offset':<8} {'Base':<8} {'Brix9':<8} {'Brix10':<8}")
    print("-"*50)

    for offset in range(-4125, -4095):
        base_val = base_data[base_pos + offset]
        brix9_val = data9[pos9 + offset]
        brix10_val = data10[pos10 + offset]

        # Mark if it looks like a position value
        is_pos = brix9_val in range(1, 21)
        marker = " *" if is_pos else ""

        print(f"{offset:<8} {base_val:<8} {brix9_val:<8} {brix10_val:<8}{marker}")

    # Also check if there's position data at positive offsets (like personality)
    print("\n" + "="*90)
    print("CHECKING POSITIVE OFFSETS FOR POSITION DATA")
    print("Looking at +46 to +80 (near personality)")
    print("="*90)

    for offset in range(46, 80):
        base_val = base_data[base_pos + offset]
        brix9_val = data9[pos9 + offset]
        brix10_val = data10[pos10 + offset]

        if base_val != brix9_val or base_val != brix10_val:
            print(f"  +{offset}: Base={base_val}, Brix9={brix9_val}, Brix10={brix10_val}")


if __name__ == "__main__":
    main()
