#!/usr/bin/env python3
"""
Test script for FM26 save file extraction.

Tests decompression and player name finding on actual save file.
"""

import json
import sys
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor
from fm26_parser.extractors.name_finder import PlayerNameFinder, find_players_in_save


# Known Brixham AFC players to search for
BRIXHAM_PLAYERS = [
    "Mason",
    "T. Budd",
    "N. Ncube",
    "Allan Hall",
    "Brixham",
    # Add more known player names here
]


def test_decompression(save_path: Path) -> bytes:
    """Test save file decompression."""
    print(f"\n{'='*60}")
    print("STEP 1: Decompression Test")
    print(f"{'='*60}")
    print(f"Save file: {save_path}")
    print(f"File size: {save_path.stat().st_size / 1024 / 1024:.2f} MB")

    # Load and decompress
    decompressor = FM26Decompressor(save_path)
    decompressor.load()

    print(f"\nHeader Info:")
    print(f"  Magic prefix: {hex(decompressor.header.magic_prefix)}")
    print(f"  Signature: {decompressor.header.signature}")
    print(f"  Version byte: {hex(decompressor.header.version_byte)}")
    print(f"  Valid: {decompressor.header.is_valid}")

    print(f"\nFrames found: {decompressor.frame_count}")
    for frame in decompressor.get_frame_info()[:10]:  # Show first 10
        print(f"  Frame {frame['index']}: offset={frame['offset']}, size={frame['compressed_size'] / 1024:.1f} KB")

    if decompressor.frame_count > 10:
        print(f"  ... and {decompressor.frame_count - 10} more frames")

    # Decompress main database
    print("\nDecompressing main database...")
    db_data = decompressor.decompress_main_database()
    print(f"Decompressed size: {len(db_data) / 1024 / 1024:.2f} MB")

    return db_data


def test_name_finding(data: bytes, player_names: list) -> dict:
    """Test finding player names in decompressed data."""
    print(f"\n{'='*60}")
    print("STEP 2: Player Name Search")
    print(f"{'='*60}")
    print(f"Searching for {len(player_names)} known names...")

    finder = PlayerNameFinder(data)
    matches = finder.find_known_names(player_names)

    print(f"\nFound {len(matches)} matches:")
    for match in matches[:20]:  # Show first 20
        print(f"  '{match.name}' at offset {match.offset} ({hex(match.offset)}) "
              f"[prefix: {match.prefix_length} bytes]")

    if len(matches) > 20:
        print(f"  ... and {len(matches) - 20} more matches")

    return {
        "total_matches": len(matches),
        "matches": matches
    }


def test_spacing_analysis(data: bytes, player_names: list) -> dict:
    """Analyze spacing between player name matches."""
    print(f"\n{'='*60}")
    print("STEP 3: Spacing Analysis")
    print(f"{'='*60}")

    finder = PlayerNameFinder(data)
    finder.find_known_names(player_names)
    spacing = finder.analyze_spacing()

    print(f"\nSpacing between consecutive matches:")
    print(f"  Match count: {spacing.get('match_count', 0)}")
    print(f"  Min delta: {spacing.get('min_delta', 0):,} bytes")
    print(f"  Max delta: {spacing.get('max_delta', 0):,} bytes")
    print(f"  Avg delta: {spacing.get('avg_delta', 0):,.0f} bytes")

    if "deltas" in spacing and spacing["deltas"]:
        print("\n  Sample deltas:")
        for d in spacing["deltas"][:10]:
            print(f"    {d['from_name']} -> {d['to_name']}: {d['delta']:,} bytes")

    return spacing


def test_context_analysis(data: bytes, player_names: list) -> dict:
    """Analyze context around player names."""
    print(f"\n{'='*60}")
    print("STEP 4: Context Pattern Analysis")
    print(f"{'='*60}")

    finder = PlayerNameFinder(data)
    finder.find_known_names(player_names)
    contexts = finder.compare_contexts()

    if "contexts" in contexts:
        print(f"\nContext before each name (last 16 bytes):")
        for ctx in contexts["contexts"][:5]:
            print(f"  '{ctx['name']}': {ctx['context_bytes']}")

    if "common_suffix_candidates" in contexts and contexts["common_suffix_candidates"]:
        print("\nCommon patterns found before names:")
        for pattern in contexts["common_suffix_candidates"][:5]:
            print(f"  {pattern['hex']} (appears {pattern['count']} times)")

    return contexts


def search_for_more_strings(data: bytes, limit: int = 100) -> list:
    """Search for name-like strings in the database."""
    print(f"\n{'='*60}")
    print("STEP 5: Name-Like String Search")
    print(f"{'='*60}")

    finder = PlayerNameFinder(data)
    name_strings = finder.find_name_like_strings(min_length=5, max_length=30)

    print(f"\nFound {len(name_strings)} name-like strings")
    print(f"Sample (first {min(limit, len(name_strings))}):")

    # Filter to unique names
    seen = set()
    unique = []
    for offset, name in name_strings:
        if name not in seen:
            seen.add(name)
            unique.append((offset, name))

    for offset, name in unique[:limit]:
        print(f"  {hex(offset)}: '{name}'")

    return unique[:limit]


def main():
    """Run all tests."""
    # Default save file path
    save_path = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games/Brixham.fm")

    if not save_path.exists():
        print(f"Error: Save file not found: {save_path}")
        sys.exit(1)

    print("\n" + "="*60)
    print("FM26 SAVE FILE EXTRACTION TEST")
    print("="*60)

    # Step 1: Decompress
    db_data = test_decompression(save_path)

    # Step 2: Find known names
    results = test_name_finding(db_data, BRIXHAM_PLAYERS)

    # Step 3: Analyze spacing
    spacing = test_spacing_analysis(db_data, BRIXHAM_PLAYERS)

    # Step 4: Analyze context patterns
    contexts = test_context_analysis(db_data, BRIXHAM_PLAYERS)

    # Step 5: Search for more names
    name_strings = search_for_more_strings(db_data, limit=50)

    print(f"\n{'='*60}")
    print("SUMMARY")
    print(f"{'='*60}")
    print(f"Database size: {len(db_data) / 1024 / 1024:.2f} MB")
    print(f"Known names found: {results['total_matches']}")
    print(f"Name-like strings: {len(name_strings)}")

    print("\n✅ Phase 1 decompression and name finding working!")
    print("\nNext steps:")
    print("1. Add more known Brixham player names to improve matching")
    print("2. Analyze record boundaries using spacing patterns")
    print("3. Start mapping attribute byte offsets")


if __name__ == "__main__":
    main()
