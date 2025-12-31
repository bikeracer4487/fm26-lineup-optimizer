#!/usr/bin/env python3
"""
VERIFIED ATTRIBUTE MAPPING SUMMARY

This script verifies all attributes found across Brixham6-10 saves.
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

    print("="*80)
    print("FM26 PLAYER DATA ATTRIBUTE MAPPING - COMPLETE SUMMARY")
    print("="*80)

    # Load base and Brix10
    print("\nLoading saves for verification...")
    dec_base = FM26Decompressor(base / "Brixham.fm")
    dec_base.load()
    base_data = dec_base.decompress_main_database()
    base_pos = find_string_position(base_data, name)

    dec10 = FM26Decompressor(base / "Brixham10.fm")
    dec10.load()
    data10 = dec10.decompress_main_database()
    pos10 = find_string_position(data10, name)

    print(f"Base Isaac position: {base_pos:,}")
    print(f"Brix10 Isaac position: {pos10:,}")

    # =========================================================================
    # COMPREHENSIVE ATTRIBUTE MAP
    # =========================================================================

    print("\n" + "="*80)
    print("VERIFIED ATTRIBUTE OFFSETS")
    print("="*80)

    # Negative offsets use 0-100 internal scale (in-game 1-20 = internal 5-100)
    # Positive offsets use raw 0-20 scale

    attributes = {
        # FEET (from Brix10)
        'Left Foot': {'offset': -4127, 'scale': '0-100'},
        'Right Foot': {'offset': -4126, 'scale': '0-100'},

        # TECHNICAL (from Brix6)
        'Corners': {'offset': -4124, 'scale': '0-100'},
        'Crossing': {'offset': -4151, 'scale': '0-100'},
        'First Touch': {'offset': -4129, 'scale': '0-100'},
        'Long Shots': {'offset': -4147, 'scale': '0-100'},
        'Marking': {'offset': -4146, 'scale': '0-100'},
        'Passing': {'offset': -4144, 'scale': '0-100'},

        # MENTAL (from Brix7)
        'Aggression': {'offset': -4106, 'scale': '0-100'},
        'Bravery': {'offset': -4108, 'scale': '0-100'},
        'Determination': {'offset': -4100, 'scale': '0-100'},
        'Off The Ball': {'offset': -4145, 'scale': '0-100'},
        'Positioning': {'offset': -4131, 'scale': '0-100'},
        'Dirtiness': {'offset': -4110, 'scale': '0-100'},

        # PHYSICAL (from Brix8)
        'Balance': {'offset': -4109, 'scale': '0-100'},
        'Jumping Reach': {'offset': -4112, 'scale': '0-100'},
        'Stamina': {'offset': -4114, 'scale': '0-100'},
        'Injury Proneness': {'offset': -4103, 'scale': '0-100'},

        # FITNESS (from Brix10)
        'Condition': {'offset': -4080, 'scale': 'special'},  # 16-bit
        'Fatigue': {'offset': -4082, 'scale': 'special'},    # 16-bit
        'Sharpness': {'offset': -4084, 'scale': 'special'},  # 16-bit

        # VERSATILITY (from Brix10 - stored with other attrs)
        'Versatility': {'offset': -4102, 'scale': '0-100'},

        # PERSONALITY (from Brix10 - POSITIVE offset, raw 0-20 scale!)
        'Adaptability': {'offset': +38, 'scale': '0-20'},
        'Ambition': {'offset': +39, 'scale': '0-20'},
        'Loyalty': {'offset': +40, 'scale': '0-20'},
        'Pressure': {'offset': +41, 'scale': '0-20'},
        'Professionalism': {'offset': +42, 'scale': '0-20'},
        'Sportsmanship': {'offset': +43, 'scale': '0-20'},
        'Temperament': {'offset': +44, 'scale': '0-20'},
        'Controversy': {'offset': +45, 'scale': '0-20'},
    }

    # Group by category
    categories = {
        'FEET': ['Left Foot', 'Right Foot'],
        'TECHNICAL': ['Corners', 'Crossing', 'First Touch', 'Long Shots', 'Marking', 'Passing'],
        'MENTAL': ['Aggression', 'Bravery', 'Determination', 'Off The Ball', 'Positioning', 'Dirtiness'],
        'PHYSICAL': ['Balance', 'Jumping Reach', 'Stamina', 'Injury Proneness'],
        'FITNESS': ['Condition', 'Fatigue', 'Sharpness'],
        'HIDDEN': ['Versatility'],
        'PERSONALITY (raw 0-20)': ['Adaptability', 'Ambition', 'Loyalty', 'Pressure',
                                    'Professionalism', 'Sportsmanship', 'Temperament', 'Controversy'],
    }

    for cat_name, attr_list in categories.items():
        print(f"\n{cat_name}:")
        for attr_name in attr_list:
            info = attributes[attr_name]
            offset = info['offset']
            scale = info['scale']

            # Get values from both saves
            if offset > 0:
                base_check = base_pos + offset
                mod_check = pos10 + offset
            else:
                base_check = base_pos + offset
                mod_check = pos10 + offset

            base_val = base_data[base_check] if 0 <= base_check < len(base_data) else -1
            mod_val = data10[mod_check] if 0 <= mod_check < len(data10) else -1

            if scale == '0-100':
                in_game_base = base_val // 5 if base_val >= 0 else -1
                in_game_mod = mod_val // 5 if mod_val >= 0 else -1
                print(f"  {attr_name:20}: offset {offset:>+5} | Base: {base_val:>3} ({in_game_base:>2}) | Brix10: {mod_val:>3} ({in_game_mod:>2})")
            elif scale == '0-20':
                print(f"  {attr_name:20}: offset {offset:>+5} | Base: {base_val:>3}       | Brix10: {mod_val:>3}")
            else:  # special
                print(f"  {attr_name:20}: offset {offset:>+5} | Base: {base_val:>3}       | Brix10: {mod_val:>3} (16-bit)")

    print("\n" + "="*80)
    print("SUMMARY")
    print("="*80)
    print(f"\nTotal attributes mapped: {len(attributes)}")
    print("\nKey findings:")
    print("  - Most attributes stored BEFORE name (negative offsets)")
    print("  - Technical/Mental/Physical use 0-100 internal scale (1-20 = 5-100)")
    print("  - PERSONALITY stored AFTER name at +38 to +45 (raw 0-20 scale)")
    print("  - Fitness values appear to use 16-bit encoding")
    print("  - Feet use 0-100 scale at -4127 and -4126")

    print("\n" + "="*80)
    print("NOTES ON SCALE CONVERSION")
    print("="*80)
    print("\nFor 0-100 scale attributes:")
    print("  - Internal value 5  = In-game 1")
    print("  - Internal value 50 = In-game 10")
    print("  - Internal value 100 = In-game 20")
    print("  - Formula: in_game = internal / 5")
    print("\nFor 0-20 scale attributes (personality):")
    print("  - Values stored directly as 1-20")
    print("  - No conversion needed")


if __name__ == "__main__":
    main()
