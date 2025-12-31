#!/usr/bin/env python3
"""
Compare ALL frames between two FM26 saves to find attribute changes.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor


def find_frame_changes(data1: bytes, data2: bytes) -> list:
    """Find all byte differences between two data blocks."""
    changes = []
    min_len = min(len(data1), len(data2))

    for i in range(min_len):
        if data1[i] != data2[i]:
            changes.append({
                'offset': i,
                'old': data1[i],
                'new': data2[i],
                'delta': data2[i] - data1[i]
            })

    return changes


def main():
    save1_path = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games/Brixham.fm")
    save2_path = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games/Brixham2.fm")

    print("="*70)
    print("FM26 FULL FRAME COMPARISON")
    print("="*70)

    # Load both saves
    print("\nLoading saves...")
    dec1 = FM26Decompressor(save1_path)
    dec1.load()

    dec2 = FM26Decompressor(save2_path)
    dec2.load()

    print(f"Save 1 frames: {dec1.frame_count}")
    print(f"Save 2 frames: {dec2.frame_count}")

    # Target values we're looking for
    # Tegan Budd: Pace 8 → 20
    # Isaac Smith: Pace 10 → 20
    target_changes = [
        (8, 20, "Tegan Budd Pace"),
        (10, 20, "Isaac Smith Pace"),
    ]

    print("\nLooking for:")
    for old, new, desc in target_changes:
        print(f"  {old} -> {new} ({desc})")

    # Compare frame by frame
    print("\n" + "="*70)
    print("COMPARING FRAMES")
    print("="*70)

    frames_with_changes = []
    target_matches = []

    # Start with smaller frames first (faster), then do large ones
    frame_indices = list(range(min(dec1.frame_count, dec2.frame_count)))

    # Sort by size (check small frames first)
    frame_info_1 = {f['index']: f['compressed_size'] for f in dec1.get_frame_info()}

    for idx in sorted(frame_indices, key=lambda x: frame_info_1.get(x, 0)):
        try:
            data1 = dec1.decompress_frame(idx)
            data2 = dec2.decompress_frame(idx)

            if len(data1) != len(data2):
                print(f"Frame {idx}: Size mismatch ({len(data1)} vs {len(data2)})")
                continue

            changes = find_frame_changes(data1, data2)

            if changes:
                frames_with_changes.append({
                    'frame': idx,
                    'changes': len(changes),
                    'size': len(data1)
                })

                print(f"\nFrame {idx}: {len(changes)} changes (size: {len(data1):,} bytes)")

                # Check for our target changes
                for change in changes:
                    for old, new, desc in target_changes:
                        if change['old'] == old and change['new'] == new:
                            print(f"  *** MATCH: {desc} at offset {change['offset']} ({hex(change['offset'])})")
                            target_matches.append({
                                'frame': idx,
                                'offset': change['offset'],
                                'old': old,
                                'new': new,
                                'description': desc
                            })

                # Show first few changes
                for c in changes[:5]:
                    print(f"  Offset {c['offset']}: {c['old']} -> {c['new']} (delta: {c['delta']:+d})")
                if len(changes) > 5:
                    print(f"  ... and {len(changes) - 5} more")

        except Exception as e:
            # Skip frames that fail to decompress
            pass

        # Progress indicator for large frame sets
        if idx > 0 and idx % 1000 == 0:
            print(f"  Checked {idx} frames...")

    # Summary
    print("\n" + "="*70)
    print("SUMMARY")
    print("="*70)
    print(f"Frames with changes: {len(frames_with_changes)}")

    if target_matches:
        print(f"\n*** TARGET MATCHES FOUND: {len(target_matches)} ***")
        for m in target_matches:
            print(f"  Frame {m['frame']}, offset {m['offset']}: {m['description']}")
    else:
        print("\nNo exact target matches found.")
        print("Attributes may be stored in a different format (scaled, encoded, etc.)")

    # Show all changes for analysis
    if frames_with_changes:
        print("\nAll changed frames:")
        for f in frames_with_changes:
            print(f"  Frame {f['frame']}: {f['changes']} changes ({f['size']:,} bytes)")


if __name__ == "__main__":
    main()
