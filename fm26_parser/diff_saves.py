#!/usr/bin/env python3
"""
Save File Diff Tool for FM26 Attribute Mapping.

Compares two FM26 saves to find byte changes from attribute modifications.
"""

import sys
from pathlib import Path
from typing import List, Tuple, Dict
from dataclasses import dataclass

sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor
from fm26_parser.core.binary_reader import BinaryReader


@dataclass
class ByteChange:
    """A single byte that changed between saves."""
    offset: int
    old_value: int
    new_value: int
    delta: int

    @property
    def offset_hex(self) -> str:
        return hex(self.offset)


def decompress_save(save_path: Path) -> bytes:
    """Decompress a save file and return the main database."""
    print(f"Decompressing: {save_path.name}")
    decompressor = FM26Decompressor(save_path)
    decompressor.load()
    return decompressor.decompress_main_database()


def find_changes(data_before: bytes, data_after: bytes,
                 expected_old: int = None, expected_new: int = None) -> List[ByteChange]:
    """
    Find all bytes that changed between two saves.

    Args:
        data_before: Original save data
        data_after: Modified save data
        expected_old: If provided, filter to changes FROM this value
        expected_new: If provided, filter to changes TO this value

    Returns:
        List of ByteChange objects
    """
    if len(data_before) != len(data_after):
        print(f"WARNING: Save sizes differ! Before: {len(data_before)}, After: {len(data_after)}")
        min_len = min(len(data_before), len(data_after))
    else:
        min_len = len(data_before)

    changes = []
    for i in range(min_len):
        if data_before[i] != data_after[i]:
            old_val = data_before[i]
            new_val = data_after[i]

            # Apply filters if specified
            if expected_old is not None and old_val != expected_old:
                continue
            if expected_new is not None and new_val != expected_new:
                continue

            changes.append(ByteChange(
                offset=i,
                old_value=old_val,
                new_value=new_val,
                delta=new_val - old_val
            ))

    return changes


def analyze_change_context(data: bytes, offset: int, window: int = 64) -> Dict:
    """Get context around a change to help identify what it belongs to."""
    reader = BinaryReader(data)

    start = max(0, offset - window)
    end = min(len(data), offset + window)
    context = data[start:end]

    # Look for nearby strings (potential player names)
    strings_found = []
    pos = start
    while pos < end - 4:
        # Try 4-byte length prefix
        length = int.from_bytes(data[pos:pos+4], 'little')
        if 2 <= length <= 50:
            try:
                candidate = data[pos+4:pos+4+length].decode('utf-8')
                if candidate.isprintable() and len(candidate) >= 2:
                    strings_found.append({
                        'offset': pos,
                        'relative': pos - offset,
                        'string': candidate
                    })
            except:
                pass
        pos += 1

    return {
        'context_hex': context.hex(),
        'context_start': start,
        'relative_offset': offset - start,
        'nearby_strings': strings_found[:5]  # First 5 strings found
    }


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description='Compare two FM26 saves to find attribute byte offsets',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Example usage:
  python diff_saves.py Brixham.fm Brixham_modified.fm --old 10 --new 20

This compares the saves and looks for bytes that changed from 10 to 20.
        """
    )

    parser.add_argument('save_before', type=Path, help='Original save file')
    parser.add_argument('save_after', type=Path, help='Modified save file')
    parser.add_argument('--old', type=int, help='Expected old value (filter)')
    parser.add_argument('--new', type=int, help='Expected new value (filter)')
    parser.add_argument('--limit', type=int, default=50, help='Max changes to show (default: 50)')
    parser.add_argument('--context', action='store_true', help='Show context around changes')

    args = parser.parse_args()

    if not args.save_before.exists():
        print(f"Error: {args.save_before} not found")
        sys.exit(1)
    if not args.save_after.exists():
        print(f"Error: {args.save_after} not found")
        sys.exit(1)

    print("="*70)
    print("FM26 SAVE FILE DIFF")
    print("="*70)

    # Decompress both saves
    print("\nStep 1: Decompressing saves...")
    data_before = decompress_save(args.save_before)
    data_after = decompress_save(args.save_after)

    print(f"\nBefore: {len(data_before):,} bytes")
    print(f"After:  {len(data_after):,} bytes")

    # Find changes
    print("\nStep 2: Finding changes...")
    changes = find_changes(data_before, data_after, args.old, args.new)

    print(f"\nTotal bytes changed: {len(changes)}")

    if args.old is not None or args.new is not None:
        filter_desc = []
        if args.old is not None:
            filter_desc.append(f"old={args.old}")
        if args.new is not None:
            filter_desc.append(f"new={args.new}")
        print(f"(Filtered by: {', '.join(filter_desc)})")

    if not changes:
        print("\nNo changes found matching criteria!")
        print("\nTry without --old/--new filters to see all changes.")
        return

    # Show changes
    print(f"\nShowing first {min(len(changes), args.limit)} changes:")
    print("-"*70)

    for i, change in enumerate(changes[:args.limit]):
        print(f"\n[{i+1}] Offset: {change.offset:,} ({change.offset_hex})")
        print(f"    Value: {change.old_value} -> {change.new_value} (delta: {change.delta:+d})")

        if args.context:
            ctx = analyze_change_context(data_after, change.offset)
            if ctx['nearby_strings']:
                print(f"    Nearby strings:")
                for s in ctx['nearby_strings']:
                    print(f"      {s['relative']:+d} bytes: '{s['string']}'")

    # Summary statistics
    if len(changes) > 1:
        print("\n" + "="*70)
        print("CHANGE STATISTICS")
        print("="*70)

        deltas = [c.delta for c in changes]
        old_vals = [c.old_value for c in changes]
        new_vals = [c.new_value for c in changes]

        print(f"\nDelta range: {min(deltas):+d} to {max(deltas):+d}")
        print(f"Old value range: {min(old_vals)} to {max(old_vals)}")
        print(f"New value range: {min(new_vals)} to {max(new_vals)}")

        # Group by delta value
        from collections import Counter
        delta_counts = Counter(deltas)
        print(f"\nMost common deltas:")
        for delta, count in delta_counts.most_common(5):
            print(f"  {delta:+d}: {count} occurrences")

    # If we found likely attribute changes, highlight them
    attribute_candidates = [c for c in changes
                          if 1 <= c.old_value <= 20 and 1 <= c.new_value <= 20]

    if attribute_candidates:
        print("\n" + "="*70)
        print("LIKELY ATTRIBUTE CHANGES (values in 1-20 range)")
        print("="*70)
        for c in attribute_candidates[:20]:
            print(f"  Offset {c.offset:,} ({c.offset_hex}): {c.old_value} -> {c.new_value}")


if __name__ == "__main__":
    main()
