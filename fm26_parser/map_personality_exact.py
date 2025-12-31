#!/usr/bin/env python3
"""
Map exact personality attribute positions.
We found a window at -4151 containing all personality values.
Now find exact byte offsets for each personality attribute.
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
    print(f"Shift: {pos10 - base_pos:+}")

    # Expected personality changes (all from 10 = internal 50):
    # Adaptability: 10 → 1 (50 → 5)
    # Ambition: 10 → 2 (50 → 10)
    # Controversy: 10 → 3 (50 → 15)
    # Loyalty: 10 → 4 (50 → 20)
    # Pressure: 10 → 5 (50 → 25)
    # Professionalism: 10 → 6 (50 → 30)
    # Sportsmanship: 10 → 7 (50 → 35)
    # Temperament: 10 → 8 (50 → 40)
    # Versatility: 17 → 9 (85 → 45)

    expected_changes = [
        ('Adaptability', 50, 5),
        ('Ambition', 50, 10),
        ('Controversy', 50, 15),
        ('Loyalty', 50, 20),
        ('Pressure', 50, 25),
        ('Professionalism', 50, 30),
        ('Sportsmanship', 50, 35),
        ('Temperament', 50, 40),
        ('Versatility', 85, 45),
    ]

    print("\n" + "="*80)
    print("DETAILED SCAN OF OFFSET -4250 to -4050")
    print("Looking for exact personality matches")
    print("="*80)

    # Scan the region and show ALL values
    print("\nByte-by-byte comparison (Base vs Brix10):")
    print("-" * 80)

    found = {}

    for offset in range(4250, 4050, -1):
        base_check = base_pos - offset
        mod_check = pos10 - offset

        if base_check < 0 or mod_check < 0:
            continue
        if base_check >= len(base_data) or mod_check >= len(data10):
            continue

        base_val = base_data[base_check]
        mod_val = data10[mod_check]

        # Check if this matches any expected personality change
        for attr_name, exp_base, exp_mod in expected_changes:
            if base_val == exp_base and mod_val == exp_mod:
                found[attr_name] = (-offset, base_val, mod_val)
                print(f"  {-offset:>+5}: {base_val:>3} -> {mod_val:>3}  *** {attr_name} ***")
                break
        else:
            # Show if there's a change in personality range
            if base_val != mod_val and (base_val in [50, 85] or mod_val in [5, 10, 15, 20, 25, 30, 35, 40, 45]):
                print(f"  {-offset:>+5}: {base_val:>3} -> {mod_val:>3}  (potential match)")

    print("\n" + "="*80)
    print("PERSONALITY ATTRIBUTES MAPPED:")
    print("="*80)

    for attr_name, exp_base, exp_mod in expected_changes:
        if attr_name in found:
            offset, base_val, mod_val = found[attr_name]
            print(f"  {attr_name:20}: offset {offset:>+5} ({base_val} -> {mod_val})")
        else:
            print(f"  {attr_name:20}: NOT FOUND")

    print(f"\nTotal mapped: {len(found)}/9")

    # If we didn't find them all, let's try WITHOUT assuming the shift is correct
    if len(found) < 9:
        print("\n" + "="*80)
        print("TRYING DIFFERENT SHIFT ALIGNMENTS")
        print("="*80)

        # Maybe personality uses a different shift than 480
        for test_shift in range(0, 1000, 1):
            found_with_shift = {}

            for offset in range(4300, 4000, -1):
                base_check = base_pos - offset
                mod_check = base_check + test_shift

                if base_check < 0 or mod_check < 0:
                    continue
                if base_check >= len(base_data) or mod_check >= len(data10):
                    continue

                base_val = base_data[base_check]
                mod_val = data10[mod_check]

                for attr_name, exp_base, exp_mod in expected_changes:
                    if base_val == exp_base and mod_val == exp_mod:
                        found_with_shift[attr_name] = (-offset, base_val, mod_val)

            if len(found_with_shift) >= 5:
                print(f"\n  Shift +{test_shift}: Found {len(found_with_shift)} personality attributes")
                for attr_name in found_with_shift:
                    offset, base_val, mod_val = found_with_shift[attr_name]
                    print(f"    {attr_name}: offset {offset}")

    # Let's also check if personality might be at POSITIVE offset from name
    print("\n" + "="*80)
    print("CHECKING POSITIVE OFFSETS (AFTER name)")
    print("="*80)

    for offset in range(0, 5000):
        base_check = base_pos + offset
        mod_check = pos10 + offset

        if base_check >= len(base_data) or mod_check >= len(data10):
            continue

        base_val = base_data[base_check]
        mod_val = data10[mod_check]

        for attr_name, exp_base, exp_mod in expected_changes:
            if base_val == exp_base and mod_val == exp_mod:
                print(f"  +{offset}: {base_val} -> {mod_val}  *** {attr_name} ***")

    # Maybe the personality values are in Brix10 but with WRONG alignment
    # Let's search Brix10 directly for the sequence 5, 10, 15, 20, 25, 30, 35, 40, 45
    print("\n" + "="*80)
    print("DIRECT SEARCH IN BRIX10 FOR ALL 9 VALUES NEAR ISAAC")
    print("="*80)

    # Get the exact bytes around Isaac in Brix10
    start = pos10 - 5000
    end = pos10 + 5000

    # Find all positions where we have a personality value
    personality_positions = []
    for i in range(max(0, start), min(len(data10), end)):
        val = data10[i]
        if val in [5, 10, 15, 20, 25, 30, 35, 40, 45]:
            personality_positions.append((i, val))

    print(f"\nFound {len(personality_positions)} bytes with personality values in range")

    # Look for consecutive sequences
    sequences = []
    current_seq = []

    for i, (pos, val) in enumerate(personality_positions):
        if not current_seq:
            current_seq = [(pos, val)]
        elif pos - current_seq[-1][0] < 20:  # Within 20 bytes
            current_seq.append((pos, val))
        else:
            if len(current_seq) >= 8:
                sequences.append(current_seq)
            current_seq = [(pos, val)]

    if len(current_seq) >= 8:
        sequences.append(current_seq)

    print(f"\nFound {len(sequences)} sequences of 8+ personality values")

    for seq_idx, seq in enumerate(sequences[:5]):
        values = [v for _, v in seq]
        unique = sorted(set(values))
        if len(unique) >= 7:  # At least 7 different values
            start_pos = seq[0][0]
            dist = start_pos - pos10
            print(f"\n  Sequence {seq_idx+1} at {start_pos:,} (dist {dist:+,})")
            print(f"    Values: {unique}")
            print(f"    Details:")
            for pos, val in seq:
                d = pos - pos10
                print(f"      pos={pos:,} (offset {d:+,}): {val}")


if __name__ == "__main__":
    main()
