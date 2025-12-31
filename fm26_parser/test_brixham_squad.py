#!/usr/bin/env python3
"""
Test extraction of actual Brixham AFC squad from save file.
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

import pandas as pd
from fm26_parser.core.decompressor import FM26Decompressor
from fm26_parser.analysis.record_analyzer import RecordAnalyzer


def get_brixham_names():
    """Load actual Brixham squad names from CSV."""
    csv_path = Path("/Users/Douglas.Mason/Documents/GitHub/fm26-lineup-optimizer/players-current.csv")
    df = pd.read_csv(csv_path)

    names = []
    for full_name in df['Name'].dropna():
        parts = full_name.split()
        if parts:
            # Get last name (last part)
            last_name = parts[-1]
            # Get first name (all parts except last)
            first_name = " ".join(parts[:-1]) if len(parts) > 1 else None
            names.append({
                "full_name": full_name,
                "first_name": first_name,
                "last_name": last_name
            })

    return names


def main():
    save_path = Path("/Users/Douglas.Mason/Library/Application Support/Sports Interactive/Football Manager 26/cloud/games/Brixham.fm")

    print("="*70)
    print("BRIXHAM AFC SQUAD EXTRACTION TEST")
    print("="*70)

    # Get squad names
    squad_names = get_brixham_names()
    print(f"\nLoaded {len(squad_names)} players from CSV")

    # Decompress save
    print("\nDecompressing save file...")
    decompressor = FM26Decompressor(save_path)
    decompressor.load()
    db_data = decompressor.decompress_main_database()
    print(f"Database size: {len(db_data) / 1024 / 1024:.2f} MB")

    # Search for each player
    analyzer = RecordAnalyzer(db_data)

    print("\n" + "="*70)
    print("SEARCHING FOR BRIXHAM PLAYERS")
    print("="*70)

    found_players = []
    not_found = []

    for player in squad_names:
        last_name = player["last_name"]
        expected_first = player["first_name"]
        full_name = player["full_name"]

        # Search for last name
        records = analyzer.find_all_players([last_name])

        # Filter to records where we found first name
        matching = [r for r in records if r.first_name]

        # Try to find exact match
        exact_match = None
        for r in matching:
            if r.first_name and expected_first:
                # Check if first names match (handle partial matches)
                if r.first_name.lower() == expected_first.lower():
                    exact_match = r
                    break
                elif expected_first.lower() in r.first_name.lower() or r.first_name.lower() in expected_first.lower():
                    exact_match = r
                    break

        if exact_match:
            found_players.append({
                "csv_name": full_name,
                "found_name": exact_match.name,
                "offset": exact_match.offset,
                "first_name": exact_match.first_name,
                "last_name": exact_match.last_name,
                "attributes": list(exact_match.attributes_region[:50]) if exact_match.attributes_region else []
            })
            print(f"✓ {full_name:25s} -> Found: {exact_match.name} @ {hex(exact_match.offset)}")
        elif matching:
            # Found some records with first names, but not exact match
            found_names = [r.name for r in matching[:3]]
            print(f"? {full_name:25s} -> Partial: {found_names}")
            found_players.append({
                "csv_name": full_name,
                "found_name": matching[0].name,
                "offset": matching[0].offset,
                "first_name": matching[0].first_name,
                "last_name": matching[0].last_name,
                "partial_match": True,
                "attributes": list(matching[0].attributes_region[:50]) if matching[0].attributes_region else []
            })
        else:
            print(f"✗ {full_name:25s} -> Not found (no records with first name)")
            not_found.append(full_name)

    # Summary
    print("\n" + "="*70)
    print("SUMMARY")
    print("="*70)
    print(f"Found: {len(found_players)} / {len(squad_names)} players")
    print(f"Not found: {len(not_found)}")

    if not_found:
        print(f"\nPlayers not found:")
        for name in not_found:
            print(f"  - {name}")

    # Analyze attribute patterns for found players
    if found_players:
        print("\n" + "="*70)
        print("ATTRIBUTE ANALYSIS FOR FOUND PLAYERS")
        print("="*70)

        # Show first few bytes for each player
        print("\nFirst 30 bytes after name for each found player:")
        for p in found_players[:10]:
            if "attributes" in p and p["attributes"]:
                attrs = p["attributes"][:30]
                print(f"\n{p['csv_name']}:")
                print(f"  Bytes: {attrs}")
                # Try to interpret some fields
                if len(attrs) >= 8:
                    print(f"  Byte 4 (possibly age?): {attrs[4]}")
                    print(f"  Byte 7: {attrs[7]} ({hex(attrs[7])})")

    return found_players


if __name__ == "__main__":
    found = main()
