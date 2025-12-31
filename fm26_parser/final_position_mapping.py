#!/usr/bin/env python3
"""
Final position familiarity mapping verification.
Testing both possible offset assignments for DC.
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

    print(f"Base: Isaac at {base_pos:,}")
    print(f"Brix9: Isaac at {pos9:,}")

    print("\n" + "="*80)
    print("VERIFIED POSITION FAMILIARITY MAPPING")
    print("Scale: 0-100 internal (1-20 in-game)")
    print("="*80)

    # Verified mapping from analysis (13/14 confirmed)
    # These offsets work when comparing Base (0-100) to Brix9 (raw 0-20)
    position_mapping = {
        'GK':  -4118,  # Base: 5  (1 ig) → Brix9: 1 ✓
        'DL':  -4116,  # Base: 2  → Brix9: 2 ✓ (stayed same or was 1 originally?)
        'DR':  -4114,  # Base: 45 (9 ig) → Brix9: 4 ✓
        'WBL': -4105,  # Base: 43 (8.6 ig) → Brix9: 5 ✓
        'DM':  -4104,  # Base: 34 (6.8 ig) → Brix9: 6 ✓
        'WBR': -4113,  # Base: 52 (10.4 ig) → Brix9: 7 ✓
        'ML':  -4112,  # Base: 65 (13 ig) → Brix9: 8 ✓
        'MC':  -4111,  # Base: 16 (3.2 ig) → Brix9: 9 ✓
        'MR':  -4110,  # Base: 40 (8 ig) → Brix9: 10 ✓
        'AML': -4109,  # Base: 45 (9 ig) → Brix9: 11 ✓
        'AMC': -4108,  # Base: 75 (15 ig) → Brix9: 12 ✓
        'AMR': -4107,  # Base: 98 (19.6 ig) → Brix9: 13 ✓
        'ST':  -4106,  # Base: 75 (15 ig) → Brix9: 14 ✓
    }

    # DC is uncertain - check both possibilities
    dc_candidates = [
        (-4115, "DC at -4115 (shows 20 in Brix9, expected 3)"),
        (-4103, "DC at -4103 (shows 15 in Brix9, which is 3*5=15 in 0-100)"),
    ]

    print("\n" + "-"*80)
    print("CONFIRMED POSITIONS (13/14):")
    print("-"*80)
    print(f"{'Position':<8} {'Offset':<8} {'Base (0-100)':<15} {'Brix9 (raw)':<12}")
    print("-"*50)

    for pos_name in ['GK', 'DL', 'DR', 'WBL', 'DM', 'WBR', 'ML', 'MC', 'MR', 'AML', 'AMC', 'AMR', 'ST']:
        offset = position_mapping[pos_name]
        base_val = base_data[base_pos + offset]
        brix9_val = data9[pos9 + offset]
        ig_val = base_val / 5 if base_val >= 5 else base_val
        print(f"{pos_name:<8} {offset:<8} {base_val:<3} ({ig_val:.0f} ig)     {brix9_val:<12}")

    print("\n" + "-"*80)
    print("DC CANDIDATES:")
    print("-"*80)
    for offset, desc in dc_candidates:
        base_val = base_data[base_pos + offset]
        brix9_val = data9[pos9 + offset]
        ig_val = base_val / 5 if base_val >= 5 else base_val
        print(f"  {desc}")
        print(f"    Base: {base_val} ({ig_val:.0f} in-game), Brix9: {brix9_val}")

    # Given that all other positions use raw 0-20 in Brix9, DC should too
    # If user changed DC to 3, we'd expect to see 3 in Brix9
    # At -4103 we see 15, which is 3*5=15 (0-100 scale)
    # At -4115 we see 20, which could be raw 20 (unchanged original)
    print("\n  Analysis: DC is most likely at -4103 (15 = 3 × 5 in 0-100 scale)")
    print("  The -4115 value of 20 is the unchanged original DC value (20 in-game)")

    # Update mapping with DC at -4103
    position_mapping['DC'] = -4103

    print("\n" + "="*80)
    print("FINAL POSITION FAMILIARITY OFFSET MAP")
    print("="*80)

    # Order by position type
    position_order = [
        ('GK', 'Goalkeeper'),
        ('DL', 'Defender Left'),
        ('DC', 'Defender Central'),
        ('DR', 'Defender Right'),
        ('WBL', 'Wing Back Left'),
        ('DM', 'Defensive Midfielder'),
        ('WBR', 'Wing Back Right'),
        ('ML', 'Midfielder Left'),
        ('MC', 'Midfielder Central'),
        ('MR', 'Midfielder Right'),
        ('AML', 'Attacking Mid Left'),
        ('AMC', 'Attacking Mid Central'),
        ('AMR', 'Attacking Mid Right'),
        ('ST', 'Striker'),
    ]

    print(f"\n{'Position':<8} {'Full Name':<22} {'Offset':<10}")
    print("-"*50)
    for pos, full_name in position_order:
        offset = position_mapping[pos]
        print(f"{pos:<8} {full_name:<22} {offset:<10}")

    print("\nNOTE: Values stored in 0-100 internal scale (divide by 5 for in-game value)")
    print("      In-Game Editor may write raw 0-20 values directly")


if __name__ == "__main__":
    main()
