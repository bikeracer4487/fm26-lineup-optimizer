#!/usr/bin/env python3
"""
Investigate specific offsets to find player context.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor
from fm26_parser.core.binary_reader import BinaryReader


def find_strings_near(data: bytes, offset: int, search_range: int = 2000) -> list:
    """Find length-prefixed strings near an offset."""
    strings = []

    start = max(0, offset - search_range)
    end = min(len(data), offset + search_range)

    pos = start
    while pos < end - 4:
        # Try 4-byte length prefix
        length = int.from_bytes(data[pos:pos+4], 'little')
        if 2 <= length <= 50:
            try:
                candidate = data[pos+4:pos+4+length].decode('utf-8')
                if all(c.isprintable() or c.isspace() for c in candidate):
                    relative = pos - offset
                    strings.append({
                        'offset': pos,
                        'relative': relative,
                        'length': length,
                        'string': candidate
                    })
                    pos += 4 + length
                    continue
            except:
                pass
        pos += 1

    return strings


def show_offset_context(data: bytes, offset: int, name: str):
    """Show detailed context around an offset."""
    print(f"\n{'='*70}")
    print(f"OFFSET {offset:,} ({hex(offset)}) - {name}")
    print("="*70)

    # Show hex dump around offset
    window = 64
    start = max(0, offset - window)
    end = min(len(data), offset + window + 16)

    print(f"\nHex dump (offset {start} to {end}):")
    print(f"Target byte at relative position +{offset - start}")

    context = data[start:end]
    for i in range(0, len(context), 16):
        chunk = context[i:i+16]
        hex_str = ' '.join(f'{b:02x}' for b in chunk)
        ascii_str = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
        abs_offset = start + i
        marker = " <--" if offset >= abs_offset and offset < abs_offset + 16 else ""
        print(f"  {abs_offset:10d}: {hex_str:48s} {ascii_str}{marker}")

    # Find nearby strings
    print(f"\nStrings within 2000 bytes:")
    strings = find_strings_near(data, offset, 2000)

    # Sort by proximity to offset
    strings.sort(key=lambda s: abs(s['relative']))

    for s in strings[:20]:
        direction = "before" if s['relative'] < 0 else "after"
        print(f"  {s['relative']:+6d} bytes ({direction}): '{s['string']}'")

    # Check bytes at common attribute offsets relative to this position
    print(f"\nBytes around the change (possible attributes):")
    for rel in range(-20, 21):
        abs_pos = offset + rel
        if 0 <= abs_pos < len(data):
            val = data[abs_pos]
            # Highlight values in typical attribute range
            marker = " <-- TARGET" if rel == 0 else ""
            if 1 <= val <= 20:
                marker += " [1-20 range]"
            elif 30 <= val <= 100:
                marker += " [scaled attr?]"
            print(f"  Offset {rel:+3d}: {val:3d} (0x{val:02x}){marker}")


def main():
    save_path = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games/Brixham2.fm")

    print("Loading modified save...")
    dec = FM26Decompressor(save_path)
    dec.load()
    data = dec.decompress_main_database()
    print(f"Database size: {len(data):,} bytes")

    # The two offsets where values changed to 100
    offsets = [
        (165660358, "Change 1: 52 → 100 (possibly Isaac Smith Pace)"),
        (231627458, "Change 2: 38 → 100 (possibly Tegan Budd Pace)"),
    ]

    for offset, name in offsets:
        show_offset_context(data, offset, name)

    # Also check the other two changes
    print("\n" + "="*70)
    print("OTHER CHANGES (probably not attributes)")
    print("="*70)

    other_offsets = [
        (28453824, "Change: 144 → 174"),
        (28453825, "Change: 11 → 16"),
    ]

    for offset, name in other_offsets:
        strings = find_strings_near(data, offset, 500)
        print(f"\n{name} at offset {offset:,}:")
        for s in strings[:5]:
            print(f"  {s['relative']:+6d}: '{s['string']}'")


if __name__ == "__main__":
    main()
