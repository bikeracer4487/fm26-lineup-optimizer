#!/usr/bin/env python3
"""
Complete attribute dump comparing ALL saves to find remaining attributes.

Dumps bytes in the attribute range and identifies ALL differences between saves.
"""

import sys
from pathlib import Path
import struct

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

    print("Loading all saves...")
    saves = {}
    for save_name in ['Brixham.fm', 'Brixham6.fm', 'Brixham7.fm', 'Brixham8.fm', 'Brixham9.fm', 'Brixham10.fm']:
        dec = FM26Decompressor(base / save_name)
        dec.load()
        data = dec.decompress_main_database()
        pos = find_string_position(data, name)
        saves[save_name] = (data, pos)
        print(f"  {save_name}: Isaac at {pos:,}")

    base_data, base_pos = saves['Brixham.fm']

    # Test data from user
    test_data = {
        'Brixham6.fm': {
            'desc': 'TECHNICAL (0-100 scale)',
            'attrs': [
                ("Corners", 3, 1), ("Crossing", 3, 2), ("Dribbling", 11, 3),
                ("Finishing", 1, 4), ("First Touch", 12, 5), ("Free Kicks", 1, 6),
                ("Heading", 11, 7), ("Long Shots", 2, 8), ("Long Throws", 5, 9),
                ("Marking", 14, 10), ("Passing", 6, 11), ("Penalty Taking", 2, 12),
                ("Tackling", 13, 14), ("Technique", 7, 13),
            ]
        },
        'Brixham7.fm': {
            'desc': 'MENTAL (0-100 scale)',
            'attrs': [
                ("Aggression", 15, 1), ("Anticipation", 14, 2), ("Bravery", 15, 3),
                ("Composure", 11, 4), ("Concentration", 10, 5), ("Consistency", 20, 6),
                ("Decisions", 13, 7), ("Determination", 12, 8), ("Dirtiness", 8, 9),
                ("Flair", 6, 10), ("Important Matches", 7, 11), ("Leadership", 3, 12),
                ("Off The Ball", 5, 13), ("Positioning", 14, 15), ("Teamwork", 8, 14),
                ("Vision", 10, 16), ("Work Rate", 9, 17),
            ]
        },
        'Brixham8.fm': {
            'desc': 'PHYSICAL (0-100 scale)',
            'attrs': [
                ("Acceleration", 13, 1), ("Agility", 9, 2), ("Balance", 9, 3),
                ("Injury Proneness", 8, 4), ("Jumping Reach", 13, 5),
                ("Natural Fitness", 10, 6), ("Pace", 10, 7), ("Stamina", 9, 8),
                ("Strength", 10, 9),
            ]
        },
        'Brixham9.fm': {
            'desc': 'POSITION FAMILIARITY (raw 0-20)',
            'attrs': [
                ("GK", 1, 1), ("DL", 1, 2), ("DC", 20, 3), ("DR", 1, 4),
                ("WBL", 1, 5), ("WBR", 1, 6), ("DM", 16, 7), ("ML", 1, 8),
                ("MC", 1, 9), ("MR", 1, 10), ("AML", 1, 11), ("AMC", 1, 12),
                ("AMR", 1, 13), ("ST", 1, 14),
            ]
        },
    }

    print("\n" + "="*100)
    print("COMPREHENSIVE BYTE COMPARISON - Finding ALL Changed Bytes")
    print("="*100)

    # For each modified save, find ALL bytes that changed from base
    for save_name, info in test_data.items():
        if save_name not in saves:
            continue

        mod_data, mod_pos = saves[save_name]
        desc = info['desc']
        attrs = info['attrs']

        print(f"\n{'='*100}")
        print(f"{save_name}: {desc}")
        print(f"{'='*100}")

        # Find all changed bytes in range -4200 to -4000
        changes = []
        for offset in range(-4200, -4000):
            base_val = base_data[base_pos + offset]
            mod_val = mod_data[mod_pos + offset]
            if base_val != mod_val:
                changes.append((offset, base_val, mod_val))

        print(f"\nFound {len(changes)} changed bytes in range [-4200, -4000):")
        print(f"{'Offset':<10} {'Base':<8} {'New':<8} {'Base/5':<10} {'New/5':<10} {'Possible Attr'}")
        print("-" * 80)

        # Create lookup from expected values
        base_to_attr = {}
        new_to_attr = {}
        for attr_name, base_ig, new_ig in attrs:
            # 0-100 scale
            base_100 = base_ig * 5
            new_100 = new_ig * 5
            if base_100 not in base_to_attr:
                base_to_attr[base_100] = []
            base_to_attr[base_100].append((attr_name, new_100))

            # Also check raw values for position fam
            if base_ig not in base_to_attr:
                base_to_attr[base_ig] = []
            base_to_attr[base_ig].append((attr_name + " (raw)", new_ig))

        for offset, base_val, mod_val in changes:
            base_ig = base_val / 5
            mod_ig = mod_val / 5

            # Check if this matches any expected attribute
            matches = []
            if base_val in base_to_attr:
                for attr_name, expected_new in base_to_attr[base_val]:
                    if mod_val == expected_new or abs(mod_val - expected_new) <= 1:
                        matches.append(attr_name)

            match_str = ", ".join(matches) if matches else ""
            print(f"{offset:<10} {base_val:<8} {mod_val:<8} {base_ig:<10.1f} {mod_ig:<10.1f} {match_str}")

    # Now specifically look at Brix9 with position familiarity
    # Position fam values are stored raw (0-20) in edited saves
    print("\n" + "="*100)
    print("BRIX9 POSITION FAMILIARITY - DETAILED ANALYSIS")
    print("="*100)

    mod_data, mod_pos = saves['Brixham9.fm']

    # Find where we see the expected sequence of position fam values
    # After editing: GK=1, DL=2, DC=3, DR=4, WBL=5, WBR=6, DM=7, ML=8, MC=9, MR=10, AML=11, AMC=12, AMR=13, ST=14

    print("\nLooking for consecutive position values in Brix9...")

    # Search for patterns where we see values 1-14 in sequence (or close)
    for start_offset in range(-4200, -4050):
        values = [mod_data[mod_pos + start_offset + i] for i in range(14)]
        # Check if this looks like position fam (values in 1-20 range, roughly ascending)
        if all(1 <= v <= 20 for v in values):
            ascending = sum(1 for i in range(13) if values[i+1] >= values[i])
            if ascending >= 10:  # Mostly ascending
                print(f"\n  Starting at {start_offset}: {values}")
                print(f"    Base values: {[base_data[base_pos + start_offset + i] for i in range(14)]}")

    # Check the specific position fam offsets we thought we knew
    print("\n" + "="*100)
    print("VERIFYING PREVIOUS POSITION FAM OFFSETS")
    print("="*100)

    # From ATTRIBUTE_MAPPING.md, Brix9 offsets should be -4118 to -4104
    print("\nExpected Brix9 position fam offsets (-4118 to -4104):")
    print(f"{'Offset':<10} {'Base':<8} {'Brix9':<8} {'Expected Position'}")
    print("-" * 50)

    positions_ordered = ["GK", "DL", "DC", "DR", "WBL", "WBR", "ML", "MC", "MR", "AML", "AMC", "AMR", "ST", "DM"]
    for i, (offset, pos) in enumerate(zip(range(-4118, -4104), positions_ordered)):
        base_val = base_data[base_pos + offset]
        mod_val = mod_data[mod_pos + offset]
        print(f"{offset:<10} {base_val:<8} {mod_val:<8} {pos}")

    # Also try offset -4106 where we thought AMR/ST might be
    print("\nKey offsets around -4106:")
    for offset in range(-4120, -4095):
        base_val = base_data[base_pos + offset]
        brix7_val = saves['Brixham7.fm'][0][saves['Brixham7.fm'][1] + offset]
        brix9_val = mod_data[mod_pos + offset]
        note = ""
        if base_val != brix7_val:
            note += f" [Brix7 changed: {base_val}->{brix7_val}]"
        if base_val != brix9_val:
            note += f" [Brix9 changed: {base_val}->{brix9_val}]"
        if note:
            print(f"  {offset}: Base={base_val}, Brix7={brix7_val}, Brix9={brix9_val}{note}")


if __name__ == "__main__":
    main()
