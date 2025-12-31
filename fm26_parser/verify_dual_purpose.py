#!/usr/bin/env python3
"""
Verify if the bytes serve dual purposes:
- Originally store position familiarity (0-100 scale)
- FM Editor overwrites with raw 0-20 values when editing

Theory: Isaac (AM(R)/AM(C) player) should have:
- AMR: ~100 (Natural, 20 in-game) - offset -4107 shows 98 ✓
- AMC: ~75-100 (Accomplished/Natural) - offset -4108 shows 75 ✓
- AML, ST: ~40-60 (Competent) - offsets -4109, -4106 show 45, 75
- Midfield: Medium values
- Defensive: Low values

If this is correct, the FM Editor bug overwrites these when editing position fam.
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

    print("Loading base save...")
    dec_base = FM26Decompressor(base / "Brixham.fm")
    dec_base.load()
    base_data = dec_base.decompress_main_database()
    isaac_pos = find_string_position(base_data, name)

    print(f"Isaac at: {isaac_pos:,}")
    print(f"Isaac's Best Position: AM(R), also plays AM(C)")

    print("\n" + "="*80)
    print("TESTING THEORY: Position Familiarity at -4118 to -4105")
    print("Reading Base save (unmodified by FM Editor for position fam)")
    print("="*80)

    # Hypothesized position familiarity mapping
    position_offsets = [
        (-4118, 'GK'),
        (-4117, '?'),
        (-4116, 'DL'),
        (-4115, 'DC'),
        (-4114, 'DR'),
        (-4113, 'WBR'),
        (-4112, 'ML'),
        (-4111, 'MC'),
        (-4110, 'MR'),
        (-4109, 'AML'),
        (-4108, 'AMC'),
        (-4107, 'AMR'),
        (-4106, 'ST'),
        (-4105, 'WBL'),
        (-4104, 'DM'),
    ]

    print(f"\n{'Offset':<8} {'Pos':<6} {'Raw':<6} {'In-Game':<10} {'Interpretation'}")
    print("-"*70)

    for offset, pos_name in position_offsets:
        val = base_data[isaac_pos + offset]
        ig_val = val / 5 if val >= 5 else val

        # Interpret based on Isaac being AM(R)/AM(C) player
        if pos_name == 'AMR':
            interpretation = "Natural? ✓" if ig_val >= 18 else "?"
        elif pos_name == 'AMC':
            interpretation = "Accomplished? ✓" if 14 <= ig_val <= 18 else "?"
        elif pos_name in ['AML', 'ST']:
            interpretation = "Competent?" if 8 <= ig_val <= 14 else "?"
        elif pos_name in ['ML', 'MC', 'MR']:
            interpretation = "Some ability?" if 5 <= ig_val <= 14 else "Low?" if ig_val < 5 else "?"
        elif pos_name in ['GK', 'DL', 'DC', 'DR', 'DM', 'WBL', 'WBR']:
            interpretation = "Low/None?" if ig_val <= 5 else "Some?" if ig_val <= 10 else "Medium+"
        else:
            interpretation = ""

        print(f"{offset:<8} {pos_name:<6} {val:<6} {ig_val:.0f}         {interpretation}")

    # Now check what we think are mental attributes
    print("\n" + "="*80)
    print("MENTAL ATTRIBUTES (Confirmed by Brix7 changes)")
    print("="*80)

    # User changed: Aggression 15→1, Bravery 15→3, Determination 12→8
    mental_changes = [
        (-4106, "Aggression", 15, 1),
        (-4108, "Bravery", 15, 3),
        (-4100, "Determination", 12, 8),
    ]

    print(f"\n{'Offset':<8} {'Attr':<15} {'Base Raw':<10} {'Base IG':<10} {'Expected':<10}")
    print("-"*70)

    for offset, attr, old_ig, new_ig in mental_changes:
        val = base_data[isaac_pos + offset]
        ig_val = val / 5 if val >= 5 else val
        expected = old_ig
        matches = "✓" if int(ig_val) == expected else "✗"
        print(f"{offset:<8} {attr:<15} {val:<10} {ig_val:.0f}         {expected:<10} {matches}")

    print("\n" + "="*80)
    print("CONCLUSION")
    print("="*80)

    print("""
KEY FINDINGS:

1. Offset -4107 (AMR): Base value 98 → 20 in-game
   - Isaac's BEST POSITION is AM(R) = should be 20 (Natural)
   - This CONFIRMS position familiarity is stored here!

2. Offset -4108 (AMC): Base value 75 → 15 in-game
   - Isaac also plays AM(C) = should be ~15 (Accomplished)
   - Also stores Bravery (which is 15 according to user)
   - These values MATCH - same byte, dual meaning?

3. Offset -4106 (ST): Base value 75 → 15 in-game
   - ST position familiarity
   - Also Aggression (which is 15 according to user)
   - These values MATCH TOO!

THEORY:
Either the game stores position familiarity AND mental attributes at the same
offsets (unlikely), OR these are actually POSITION FAMILIARITY bytes and the
user's mental attribute values (Aggression=15, Bravery=15) were coincidentally
the same as some position values.

The FM Editor when changing mental attrs writes to these bytes.
The FM Editor when changing position fam writes to these bytes.
Both overwrite each other!

FOR THE PARSER:
- These offsets store SOME player attribute on a 0-100 scale
- What attribute depends on what was last edited
- In clean saves, they likely store position familiarity
- Mental attributes may be elsewhere, or interleaved
    """)

    # Let's also check if there's a separate mental attribute block
    print("\n" + "="*80)
    print("SEARCHING FOR SEPARATE MENTAL ATTRIBUTE BLOCK")
    print("Looking at -4150 to -4130 (technical/mental area)")
    print("="*80)

    print(f"\n{'Offset':<8} {'Raw':<6} {'In-Game':<10}")
    print("-"*40)

    for offset in range(-4155, -4125):
        val = base_data[isaac_pos + offset]
        if val == 0 or val > 100:
            continue
        ig_val = val / 5 if val >= 5 else val
        if 1 <= ig_val <= 20:
            print(f"{offset:<8} {val:<6} {ig_val:.0f}")


if __name__ == "__main__":
    main()
