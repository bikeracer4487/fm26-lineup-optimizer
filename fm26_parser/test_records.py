#!/usr/bin/env python3
"""
Test script for FM26 player record analysis.

Attempts to find full player names and analyze record structure.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from fm26_parser.core.decompressor import FM26Decompressor
from fm26_parser.analysis.record_analyzer import RecordAnalyzer, analyze_save


# Expanded list of known Brixham AFC player last names
BRIXHAM_LAST_NAMES = [
    "Mason",     # Your manager?
    "Budd",      # T. Budd
    "Ncube",     # N. Ncube
    "Hall",      # Allan Hall
    # Add more known last names from your squad here
]

# Also search for some Premier League players to verify we're finding real data
TEST_PLAYERS = [
    "Haaland",
    "Salah",
    "Saka",
    "Foden",
    "Palmer",
]


def main():
    save_path = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games/Brixham.fm")

    if not save_path.exists():
        print(f"Error: Save file not found: {save_path}")
        sys.exit(1)

    print("="*60)
    print("FM26 PLAYER RECORD ANALYSIS")
    print("="*60)

    # Decompress
    print("\nDecompressing save file...")
    decompressor = FM26Decompressor(save_path)
    decompressor.load()
    db_data = decompressor.decompress_main_database()
    print(f"Decompressed: {len(db_data) / 1024 / 1024:.2f} MB")

    # Analyze with Brixham players
    print("\n" + "="*60)
    print("BRIXHAM AFC PLAYERS")
    print("="*60)
    brixham_results = analyze_save(db_data, BRIXHAM_LAST_NAMES)

    # Analyze with test players
    print("\n" + "="*60)
    print("PREMIER LEAGUE TEST PLAYERS")
    print("="*60)
    pl_results = analyze_save(db_data, TEST_PLAYERS)

    # Print attribute analysis
    print("\n" + "="*60)
    print("ATTRIBUTE PATTERN ANALYSIS")
    print("="*60)

    # Combine all records for analysis
    all_records = brixham_results["records"] + pl_results["records"]
    analyzer = RecordAnalyzer(db_data)
    attr_analysis = analyzer.analyze_attribute_patterns(all_records)

    if "likely_attributes" in attr_analysis:
        print(f"\nPotential attribute positions (values in 1-20 range):")
        for attr in attr_analysis["likely_attributes"][:20]:
            print(f"  Offset +{attr['offset']}: range {attr['min']}-{attr['max']}")

    # Show raw position data for first 100 bytes
    print(f"\nFirst 50 byte positions after name:")
    for pos in range(50):
        if pos in attr_analysis.get("positions", {}):
            info = attr_analysis["positions"][pos]
            print(f"  +{pos:2d}: min={info['min']:3d} max={info['max']:3d} avg={info['avg']:5.1f} | sample: {info['sample']}")

    print("\n" + "="*60)
    print("SUMMARY")
    print("="*60)
    print(f"Brixham players found: {brixham_results['record_count']}")
    print(f"PL players found: {pl_results['record_count']}")
    print(f"Total records: {len(all_records)}")

    # Show some interesting players
    print("\nSample full player names found:")
    seen = set()
    for record in all_records:
        name = record.name
        if name not in seen and record.first_name:
            seen.add(name)
            print(f"  - {name}")
            if len(seen) >= 15:
                break


if __name__ == "__main__":
    main()
