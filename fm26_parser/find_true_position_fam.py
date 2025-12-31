#!/usr/bin/env python3
"""
Find the TRUE position familiarity location.

The FM In-Game Editor appears to write position fam to mental attribute bytes.
This may be a bug. Let's find where position fam is ORIGINALLY stored.

Strategy: Compare a CLEAN save (with known position values) to identify
where position familiarity actually lives.
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
    base_pos = find_string_position(base_data, name)
    print(f"Base: Isaac at {base_pos:,}")

    # Isaac's known position familiarity from FM (ORIGINAL, before any edits):
    # Based on his Best Position being AM(R)/AM(C), his profile would have:
    # - AMR: Natural (20) = 100 internal or raw 20
    # - AMC: Accomplished (15-19?) ≈ 75-95 internal
    # - AML, ST: maybe Competent (10-14?)
    # - Wings: some ability
    # - Defensive positions: Low

    # We know his original Aggression and Bravery were 15 (internal 75)
    # Let's find ALL bytes in the -4200 to -4000 range that could represent
    # position familiarity values

    print("\n" + "="*90)
    print("SEARCHING FOR ORIGINAL POSITION FAMILIARITY")
    print("Looking for values that could be position fam (1-20 raw or 5-100 internal)")
    print("="*90)

    # Values we expect for an AM(R)/AM(C) player:
    # High for AMR, AMC (15-20)
    # Medium for adjacent positions (8-15)
    # Low for distant positions (1-7)

    # Mental attribute offsets (confirmed from Brix7):
    mental_offsets = {
        -4145: "Off The Ball",
        -4131: "Positioning",
        -4110: "Dirtiness",
        -4108: "Bravery",
        -4106: "Aggression",
        -4100: "Determination",
        -4099: "Composure?",
        -4098: "Teamwork?",
    }

    print("\n" + "-"*70)
    print("Values near Isaac that could be position familiarity:")
    print("-"*70)
    print(f"{'Offset':<8} {'Value':<8} {'0-100→ig':<12} {'Notes'}")
    print("-"*70)

    # Search a wider range
    potential_pos_fam = []
    for offset in range(-4200, -4050):
        val = base_data[base_pos + offset]

        # Skip unlikely values
        if val == 0 or val > 100:
            continue

        # Calculate in-game value if 0-100 scale
        ig_val = val / 5 if val >= 5 else val

        # Note if this conflicts with mental attributes
        conflict = mental_offsets.get(offset, "")

        # Only show values that look like position familiarity (1-20 range when scaled)
        if 1 <= ig_val <= 20:
            potential_pos_fam.append((offset, val, ig_val, conflict))

    # Show sorted by offset
    for offset, val, ig, conflict in sorted(potential_pos_fam):
        note = f"MENTAL: {conflict}" if conflict else ""
        print(f"{offset:<8} {val:<8} {ig:.0f}            {note}")

    # Now let's look for a block of 14 consecutive position-like values
    print("\n" + "="*90)
    print("SEARCHING FOR 14-VALUE POSITION FAMILIARITY BLOCK")
    print("Looking for 14 consecutive bytes that could all be position familiarity")
    print("="*90)

    best_blocks = []

    for start_offset in range(-4500, -4000):
        values = []
        valid = True
        for i in range(14):
            val = base_data[base_pos + start_offset + i]
            ig_val = val / 5 if val >= 5 else val
            if not (1 <= ig_val <= 20 or val == 0):  # Allow 0 for Awkward
                valid = False
                break
            values.append((val, ig_val))

        if valid and len(values) == 14:
            # Check if values look reasonable for a position fam block
            ig_values = [v[1] for v in values]
            max_ig = max(ig_values)
            min_ig = min(ig_values)

            # AMR/AMC player should have some high values and some low
            if max_ig >= 15 and min_ig <= 5:
                best_blocks.append((start_offset, values))

    print(f"\nFound {len(best_blocks)} potential 14-value blocks")

    # Show top candidates
    for start_off, values in best_blocks[:5]:
        print(f"\n  Block starting at {start_off}:")
        positions = ['GK', 'DL', 'DC', 'DR', 'WBL', 'DM', 'WBR', 'ML', 'MC', 'MR', 'AML', 'AMC', 'AMR', 'ST']
        for i, (raw, ig) in enumerate(values):
            conflict = mental_offsets.get(start_off + i, "")
            marker = " ***" if conflict else ""
            print(f"    {positions[i]}: {raw} ({ig:.0f} ig){marker}")

    # Alternative: Look at positive offsets (like personality)
    print("\n" + "="*90)
    print("CHECKING POSITIVE OFFSETS FOR POSITION FAMILIARITY")
    print("(Personality was found at +38 to +45)")
    print("="*90)

    # Search +50 to +100 for potential position fam
    print(f"\n{'Offset':<8} {'Value':<8} {'0-100→ig':<12}")
    print("-"*50)

    for offset in range(50, 120):
        val = base_data[base_pos + offset]
        if val == 0 or val > 100:
            continue
        ig_val = val / 5 if val >= 5 else val
        if 1 <= ig_val <= 20:
            print(f"+{offset:<7} {val:<8} {ig_val:.0f}")

    # Check if position familiarity might be stored with the personality block
    print("\n" + "="*90)
    print("THEORY: Position fam may be stored differently than we thought")
    print("="*90)

    print("""
Observations:
1. Brix7 changed mental attributes at offsets -4106, -4108, etc.
2. Brix9 changed position familiarity and wrote to THE SAME offsets
3. The FM In-Game Editor overwrites mental attrs when setting position fam

This suggests either:
A) FM editor has a bug (writes to wrong bytes)
B) Position fam and mental attrs share storage (unlikely - different categories)
C) Position fam is stored elsewhere, and editor's changes corrupt mental bytes

For our parser, we need to:
1. Use mental attribute offsets (-4106, -4108, etc.) for CLEAN saves
2. Be aware that FM editor-modified saves may have corrupted data
3. Find true position familiarity location from unmodified game data
    """)


if __name__ == "__main__":
    main()
