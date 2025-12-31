#!/usr/bin/env python3
"""
VERIFIED ATTRIBUTE MAPPING FOR FM26

Based on differential analysis:
- Brix1: Original save (Isaac: Pace=10, Accel=13)
- Brix2: Pace changed (Isaac: Pace=20, Accel=13)
- Brix3: Accel changed from original (Isaac: Pace=10, Accel=20)

CONFIRMED MAPPINGS:
- Pace: Relative offset 0 from anchor point
- Acceleration: Relative offset -4 from anchor point

INTERNAL SCALE:
- FM26 stores attributes on 0-100 scale internally
- In-game 1-20 maps to ~5-100 (multiply by 5)
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor


def find_string_position(data: bytes, target: str) -> int:
    """Find first occurrence of a length-prefixed string."""
    target_bytes = target.encode('utf-8')
    pattern = len(target_bytes).to_bytes(4, 'little') + target_bytes
    pos = data.find(pattern)
    return pos + 4 if pos != -1 else -1


def main():
    base = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games")

    print("="*70)
    print("FM26 ATTRIBUTE MAPPING VERIFICATION")
    print("="*70)

    print("\nLoading saves...")
    dec1 = FM26Decompressor(base / "Brixham.fm")
    dec1.load()
    data1 = dec1.decompress_main_database()

    dec2 = FM26Decompressor(base / "Brixham2.fm")
    dec2.load()
    data2 = dec2.decompress_main_database()

    dec3 = FM26Decompressor(base / "Brixham3.fm")
    dec3.load()
    data3 = dec3.decompress_main_database()

    # Find Isaac James Smith
    name = "Isaac James Smith"
    isaac_brix1 = find_string_position(data1, name)
    isaac_brix2 = find_string_position(data2, name)
    isaac_brix3 = find_string_position(data3, name)

    # The anchor point (Pace offset) is 4113 bytes before the name
    anchor_offset = 4113

    pace_brix1 = isaac_brix1 - anchor_offset
    pace_brix2 = isaac_brix2 - anchor_offset
    pace_brix3 = isaac_brix3 - anchor_offset

    print(f"\n{name}")
    print(f"  Name positions: {isaac_brix1:,} / {isaac_brix2:,} / {isaac_brix3:,}")
    print(f"  Pace positions: {pace_brix1:,} / {pace_brix2:,} / {pace_brix3:,}")

    print(f"\n{'='*70}")
    print("CONFIRMED ATTRIBUTE MAPPINGS")
    print("="*70)

    # Map of relative offsets to attribute names
    # Based on our differential analysis
    confirmed_attrs = {
        -4: "ACCELERATION",
        0: "PACE",
    }

    print(f"\n{'Offset':>8} | {'Attr':^15} | {'Brix1':>5} | {'Brix2':>5} | {'Brix3':>5} | {'Scaled (1-20)':^15} | Notes")
    print("-" * 100)

    for rel_offset in sorted(confirmed_attrs.keys()):
        attr_name = confirmed_attrs[rel_offset]

        v1 = data1[pace_brix1 + rel_offset]
        v2 = data2[pace_brix2 + rel_offset]
        v3 = data3[pace_brix3 + rel_offset]

        scaled_1 = round(v1 / 5)
        scaled_2 = round(v2 / 5)
        scaled_3 = round(v3 / 5)

        notes = []
        if v1 != v2:
            notes.append(f"Changed in Brix2")
        if v2 != v3:
            notes.append(f"Changed in Brix3")

        scaled_str = f"{scaled_1} → {scaled_2} → {scaled_3}"
        note_str = ", ".join(notes) if notes else "Unchanged"

        print(f"{rel_offset:>+8} | {attr_name:^15} | {v1:>5} | {v2:>5} | {v3:>5} | {scaled_str:^15} | {note_str}")

    print(f"\n{'='*70}")
    print("HYPOTHESIS: OTHER PHYSICAL ATTRIBUTES")
    print("="*70)

    # Physical attributes typically grouped: Pace, Acceleration, Agility, Balance,
    # Jumping Reach, Natural Fitness, Stamina, Strength

    print("\nLooking at surrounding bytes for other potential physical attributes:")
    print(f"\n{'Offset':>8} | {'Brix1':>5} | {'Scaled':>7} | Potential Attribute")
    print("-" * 60)

    # Check bytes around the confirmed attributes
    for rel in range(-20, 20):
        v1 = data1[pace_brix1 + rel]
        scaled = round(v1 / 5)

        if rel in confirmed_attrs:
            attr_guess = f"*** {confirmed_attrs[rel]} ***"
        elif 20 <= v1 <= 100:
            attr_guess = f"Physical attr? (scaled={scaled})"
        else:
            attr_guess = ""

        if rel in confirmed_attrs or 20 <= v1 <= 100:
            print(f"{rel:>+8} | {v1:>5} | {scaled:>7} | {attr_guess}")

    print(f"\n{'='*70}")
    print("SUMMARY")
    print("="*70)

    print("""
CONFIRMED MAPPING:
  - PACE: offset 0 from anchor (Name - 4113)
  - ACCELERATION: offset -4 from anchor

INTERNAL SCALE:
  - Attributes stored as 0-100 (not 1-20)
  - Conversion: internal_value / 5 ≈ in-game value

PLAYER RECORD STRUCTURE (partial):
  [other attrs...][-4: ACCEL][-3][-2][-1][0: PACE][+1][+2]...[+4113: NAME]

NEXT STEPS TO MAP MORE ATTRIBUTES:
  1. Use FM26 In-Game Editor to change another known attribute
  2. Save and diff to find new offset
  3. Build complete attribute schema
    """)


if __name__ == "__main__":
    main()
