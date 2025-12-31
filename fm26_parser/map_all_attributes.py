#!/usr/bin/env python3
"""
Map ALL attributes using the complete change data provided.

Each save changed specific attributes from known base values to known new values.
By finding where these exact value transitions occurred, we can map every attribute.
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


def find_change(base_data, base_pos, mod_data, mod_pos, base_val, new_val, search_range=(-5000, 500)):
    """Find offset where value changed from base_val to new_val."""
    matches = []
    for rel_offset in range(search_range[0], search_range[1]):
        bv = base_data[base_pos + rel_offset]
        mv = mod_data[mod_pos + rel_offset]
        if bv == base_val and mv == new_val:
            matches.append(rel_offset)
    return matches


def find_16bit_change(base_data, base_pos, mod_data, mod_pos, base_val, new_val, search_range=(-5000, 500)):
    """Find offset where 16-bit LE value changed from base_val to new_val."""
    matches = []
    for rel_offset in range(search_range[0], search_range[1]):
        bv = int.from_bytes(base_data[base_pos + rel_offset:base_pos + rel_offset + 2], 'little')
        mv = int.from_bytes(mod_data[mod_pos + rel_offset:mod_pos + rel_offset + 2], 'little')
        if bv == base_val and mv == new_val:
            matches.append(rel_offset)
    return matches


def find_signed_16bit_change(base_data, base_pos, mod_data, mod_pos, base_val, new_val, search_range=(-5000, 500)):
    """Find offset where signed 16-bit LE value changed."""
    matches = []
    for rel_offset in range(search_range[0], search_range[1]):
        bv = int.from_bytes(base_data[base_pos + rel_offset:base_pos + rel_offset + 2], 'little', signed=True)
        mv = int.from_bytes(mod_data[mod_pos + rel_offset:mod_pos + rel_offset + 2], 'little', signed=True)
        if bv == base_val and mv == new_val:
            matches.append(rel_offset)
    return matches


def main():
    base_path = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")
    name = "Isaac James Smith"

    print("Loading all saves...")
    saves = {}
    for save_name in ['Brixham.fm', 'Brixham6.fm', 'Brixham7.fm', 'Brixham8.fm', 'Brixham9.fm', 'Brixham10.fm']:
        dec = FM26Decompressor(base_path / save_name)
        dec.load()
        data = dec.decompress_main_database()
        pos = find_string_position(data, name)
        saves[save_name] = (data, pos)
        print(f"  {save_name}: Isaac at {pos:,}")

    base_data, base_pos = saves['Brixham.fm']

    results = {}

    # ==========================================================================
    # BRIX6: Technical Attributes (0-100 scale)
    # ==========================================================================
    print("\n" + "="*80)
    print("BRIXHAM6: TECHNICAL ATTRIBUTES")
    print("="*80)

    data6, pos6 = saves['Brixham6.fm']

    technical = [
        ("Corners", 3, 1),
        ("Crossing", 3, 2),
        ("Dribbling", 11, 3),
        ("Finishing", 1, 4),
        ("First Touch", 12, 5),
        ("Free Kicks", 1, 6),
        ("Heading", 11, 7),
        ("Long Shots", 2, 8),
        ("Long Throws", 5, 9),
        ("Marking", 14, 10),
        ("Passing", 6, 11),
        ("Penalty Taking", 2, 12),
        ("Tackling", 13, 14),
        ("Technique", 7, 13),
    ]

    print(f"\n{'Attribute':<18} {'Base':<6} {'New':<6} {'Offset':<10} {'Verified'}")
    print("-"*60)

    for attr_name, base_ig, new_ig in technical:
        base_internal = base_ig * 5
        new_internal = new_ig * 5
        matches = find_change(base_data, base_pos, data6, pos6, base_internal, new_internal)

        if len(matches) == 1:
            offset = matches[0]
            results[f"Technical.{attr_name}"] = offset
            print(f"{attr_name:<18} {base_ig:<6} {new_ig:<6} {offset:<10} ✓")
        elif len(matches) > 1:
            print(f"{attr_name:<18} {base_ig:<6} {new_ig:<6} {matches}  (multiple)")
        else:
            print(f"{attr_name:<18} {base_ig:<6} {new_ig:<6} NOT FOUND")

    # ==========================================================================
    # BRIX7: Mental Attributes (0-100 scale)
    # ==========================================================================
    print("\n" + "="*80)
    print("BRIXHAM7: MENTAL ATTRIBUTES")
    print("="*80)

    data7, pos7 = saves['Brixham7.fm']

    mental = [
        ("Aggression", 15, 1),
        ("Anticipation", 14, 2),
        ("Bravery", 15, 3),
        ("Composure", 11, 4),
        ("Concentration", 10, 5),
        ("Consistency", 20, 6),
        ("Decisions", 13, 7),
        ("Determination", 12, 8),
        ("Dirtiness", 8, 9),
        ("Flair", 6, 10),
        ("Important Matches", 7, 11),
        ("Leadership", 3, 12),
        ("Off The Ball", 5, 13),
        ("Positioning", 14, 15),
        ("Teamwork", 8, 14),
        ("Vision", 10, 16),
        ("Work Rate", 9, 17),
    ]

    print(f"\n{'Attribute':<20} {'Base':<6} {'New':<6} {'Offset':<10} {'Verified'}")
    print("-"*60)

    for attr_name, base_ig, new_ig in mental:
        base_internal = base_ig * 5
        new_internal = new_ig * 5
        matches = find_change(base_data, base_pos, data7, pos7, base_internal, new_internal)

        if len(matches) == 1:
            offset = matches[0]
            results[f"Mental.{attr_name}"] = offset
            print(f"{attr_name:<20} {base_ig:<6} {new_ig:<6} {offset:<10} ✓")
        elif len(matches) > 1:
            print(f"{attr_name:<20} {base_ig:<6} {new_ig:<6} {matches}  (multiple)")
        else:
            print(f"{attr_name:<20} {base_ig:<6} {new_ig:<6} NOT FOUND")

    # ==========================================================================
    # BRIX8: Physical Attributes (0-100 scale)
    # ==========================================================================
    print("\n" + "="*80)
    print("BRIXHAM8: PHYSICAL ATTRIBUTES")
    print("="*80)

    data8, pos8 = saves['Brixham8.fm']

    physical = [
        ("Acceleration", 13, 1),
        ("Agility", 9, 2),
        ("Balance", 9, 3),
        ("Injury Proneness", 8, 4),
        ("Jumping Reach", 13, 5),
        ("Natural Fitness", 10, 6),
        ("Pace", 10, 7),
        ("Stamina", 9, 8),
        ("Strength", 10, 9),
    ]

    print(f"\n{'Attribute':<20} {'Base':<6} {'New':<6} {'Offset':<10} {'Verified'}")
    print("-"*60)

    for attr_name, base_ig, new_ig in physical:
        base_internal = base_ig * 5
        new_internal = new_ig * 5
        matches = find_change(base_data, base_pos, data8, pos8, base_internal, new_internal)

        if len(matches) == 1:
            offset = matches[0]
            results[f"Physical.{attr_name}"] = offset
            print(f"{attr_name:<20} {base_ig:<6} {new_ig:<6} {offset:<10} ✓")
        elif len(matches) > 1:
            print(f"{attr_name:<20} {base_ig:<6} {new_ig:<6} {matches}  (multiple)")
        else:
            print(f"{attr_name:<20} {base_ig:<6} {new_ig:<6} NOT FOUND")

    # ==========================================================================
    # BRIX9: Position Familiarity
    # ==========================================================================
    print("\n" + "="*80)
    print("BRIXHAM9: POSITION FAMILIARITY")
    print("="*80)
    print("Note: Brix9 has 48-byte structural shift from Base")

    data9, pos9 = saves['Brixham9.fm']

    # Position familiarity - raw 0-20 values in Brix9
    position_fam = [
        ("GK", 1, 1),       # No change
        ("DL", 1, 2),
        ("DC", 20, 3),
        ("DR", 1, 4),
        ("WBL", 1, 5),
        ("WBR", 1, 6),
        ("DM", 16, 7),
        ("ML", 1, 8),
        ("MC", 1, 9),
        ("MR", 1, 10),
        ("AML", 1, 11),
        ("AMC", 1, 12),
        ("AMR", 1, 13),
        ("ST", 1, 14),
    ]

    print(f"\n{'Position':<8} {'Base':<6} {'New':<6} {'Brix9 Offset':<15} {'Base Offset':<15} {'Verified'}")
    print("-"*80)

    # For Brix9, we search for raw values (not *5)
    # And we need to account for the 48-byte shift
    for pos_name, base_ig, new_ig in position_fam:
        if base_ig == new_ig:
            print(f"{pos_name:<8} {base_ig:<6} {new_ig:<6} (no change)")
            continue

        # Search in Brix9 for the raw value change
        # Base value could be raw or *5, try both
        matches_raw = find_change(base_data, base_pos, data9, pos9, base_ig, new_ig)
        matches_scaled = find_change(base_data, base_pos, data9, pos9, base_ig * 5, new_ig)

        if len(matches_raw) == 1:
            brix9_offset = matches_raw[0]
            base_offset = brix9_offset - 48  # Account for shift
            results[f"Position.{pos_name}"] = {"brix9": brix9_offset, "base": base_offset}
            print(f"{pos_name:<8} {base_ig:<6} {new_ig:<6} {brix9_offset:<15} {base_offset:<15} ✓ (raw)")
        elif len(matches_scaled) == 1:
            brix9_offset = matches_scaled[0]
            base_offset = brix9_offset - 48
            results[f"Position.{pos_name}"] = {"brix9": brix9_offset, "base": base_offset}
            print(f"{pos_name:<8} {base_ig:<6} {new_ig:<6} {brix9_offset:<15} {base_offset:<15} ✓ (scaled)")
        elif matches_raw:
            print(f"{pos_name:<8} {base_ig:<6} {new_ig:<6} {matches_raw}  (multiple raw)")
        elif matches_scaled:
            print(f"{pos_name:<8} {base_ig:<6} {new_ig:<6} {matches_scaled}  (multiple scaled)")
        else:
            print(f"{pos_name:<8} {base_ig:<6} {new_ig:<6} NOT FOUND")

    # ==========================================================================
    # BRIX10: Feet, Fitness, Personality, Versatility
    # ==========================================================================
    print("\n" + "="*80)
    print("BRIXHAM10: FEET, FITNESS, PERSONALITY, VERSATILITY")
    print("="*80)

    data10, pos10 = saves['Brixham10.fm']

    # Feet (0-100 scale)
    print("\n--- FEET ---")
    feet = [
        ("Left Foot", 11, 20),
        ("Right Foot", 20, 19),
    ]

    for attr_name, base_ig, new_ig in feet:
        base_internal = base_ig * 5
        new_internal = new_ig * 5
        matches = find_change(base_data, base_pos, data10, pos10, base_internal, new_internal)

        if len(matches) == 1:
            offset = matches[0]
            results[f"Feet.{attr_name}"] = offset
            print(f"  {attr_name}: offset {offset} ✓")
        elif len(matches) > 1:
            print(f"  {attr_name}: {matches} (multiple)")
        else:
            print(f"  {attr_name}: NOT FOUND")

    # Fitness (16-bit values)
    print("\n--- FITNESS (16-bit) ---")
    fitness = [
        ("Condition", 9528, 7100),
        ("Sharpness", 5100, 6400),
    ]

    for attr_name, base_val, new_val in fitness:
        matches = find_16bit_change(base_data, base_pos, data10, pos10, base_val, new_val)

        if len(matches) == 1:
            offset = matches[0]
            results[f"Fitness.{attr_name}"] = offset
            print(f"  {attr_name}: offset {offset} ✓")
        elif len(matches) > 1:
            print(f"  {attr_name}: {matches} (multiple)")
        else:
            print(f"  {attr_name}: NOT FOUND")

    # Fatigue (signed 16-bit)
    print("\n--- FATIGUE (signed 16-bit) ---")
    fatigue_matches = find_signed_16bit_change(base_data, base_pos, data10, pos10, -500, 35)
    if len(fatigue_matches) == 1:
        results["Fitness.Fatigue"] = fatigue_matches[0]
        print(f"  Fatigue: offset {fatigue_matches[0]} ✓")
    elif len(fatigue_matches) > 1:
        print(f"  Fatigue: {fatigue_matches} (multiple)")
    else:
        # Try unsigned
        fatigue_matches = find_16bit_change(base_data, base_pos, data10, pos10, 65036, 35)  # -500 as unsigned
        if fatigue_matches:
            results["Fitness.Fatigue"] = fatigue_matches[0]
            print(f"  Fatigue: offset {fatigue_matches[0]} ✓ (unsigned)")
        else:
            print(f"  Fatigue: NOT FOUND")

    # Personality (raw 0-20, positive offsets)
    print("\n--- PERSONALITY (raw 0-20) ---")
    personality = [
        ("Adaptability", 10, 1),
        ("Ambition", 10, 2),
        ("Controversy", 10, 3),
        ("Loyalty", 10, 4),
        ("Pressure", 10, 5),
        ("Professionalism", 10, 6),
        ("Sportsmanship", 10, 7),
        ("Temperament", 10, 8),
    ]

    for attr_name, base_val, new_val in personality:
        matches = find_change(base_data, base_pos, data10, pos10, base_val, new_val)

        if len(matches) == 1:
            offset = matches[0]
            results[f"Personality.{attr_name}"] = offset
            print(f"  {attr_name}: offset {offset} ✓")
        elif len(matches) > 1:
            print(f"  {attr_name}: {matches} (multiple)")
        else:
            print(f"  {attr_name}: NOT FOUND")

    # Versatility (0-100 scale)
    print("\n--- VERSATILITY ---")
    vers_matches = find_change(base_data, base_pos, data10, pos10, 17 * 5, 9 * 5)
    if len(vers_matches) == 1:
        results["Hidden.Versatility"] = vers_matches[0]
        print(f"  Versatility: offset {vers_matches[0]} ✓")
    elif len(vers_matches) > 1:
        print(f"  Versatility: {vers_matches} (multiple)")
    else:
        print(f"  Versatility: NOT FOUND")

    # ==========================================================================
    # SUMMARY
    # ==========================================================================
    print("\n" + "="*80)
    print("COMPLETE ATTRIBUTE MAPPING")
    print("="*80)

    # Sort by offset
    sorted_results = sorted(
        [(k, v) for k, v in results.items() if not isinstance(v, dict)],
        key=lambda x: x[1]
    )

    print("\n--- By Offset (negative) ---")
    for attr, offset in sorted_results:
        if offset < 0:
            print(f"  {offset:>6}: {attr}")

    print("\n--- By Offset (positive) ---")
    for attr, offset in sorted_results:
        if offset >= 0:
            print(f"  {offset:>6}: {attr}")

    # Position familiarity (has both offsets)
    print("\n--- Position Familiarity (with shift) ---")
    for key, val in results.items():
        if isinstance(val, dict):
            print(f"  {key}: Brix9={val['brix9']}, Base={val['base']}")

    # Count
    total_mapped = len([v for v in results.values() if not isinstance(v, dict)])
    total_pos = len([v for v in results.values() if isinstance(v, dict)])
    print(f"\nTotal mapped: {total_mapped} single-offset + {total_pos} position fam = {total_mapped + total_pos}")


if __name__ == "__main__":
    main()
