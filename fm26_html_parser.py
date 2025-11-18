#!/usr/bin/env python3
"""
FM26 HTML Export Parser
Parses player data from FM26 HTML exports and converts to CSV

This tool parses HTML files exported from Football Manager 2026 using the
built-in Print Screen feature (Ctrl+P) and converts them to the CSV format
needed for the lineup optimizer.

Usage:
    python fm26_html_parser.py squad_export.html

Legal Disclaimer:
This tool only parses HTML files that YOU export from YOUR legitimate copy
of Football Manager 2026 using the game's built-in export features.
"""

import sys
import csv
import logging
import re
from pathlib import Path
from typing import List, Dict, Optional
from html.parser import HTMLParser

try:
    from bs4 import BeautifulSoup
except ImportError:
    print("ERROR: BeautifulSoup4 library not installed.")
    print("Install it with: pip install beautifulsoup4")
    sys.exit(1)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('fm26_html_parser.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class PlayerDataExtractor:
    """Extracts player data from FM26 HTML exports"""

    def __init__(self, html_file_path: str):
        """
        Initialize the extractor

        Args:
            html_file_path: Path to the HTML file exported from FM26
        """
        self.html_file_path = html_file_path
        self.players = []

    def parse_html(self) -> List[Dict]:
        """
        Parse the HTML file and extract player data

        Returns:
            List of dictionaries containing player data
        """
        try:
            with open(self.html_file_path, 'r', encoding='utf-8') as f:
                html_content = f.read()

            soup = BeautifulSoup(html_content, 'html.parser')

            # FM26 exports typically use tables
            tables = soup.find_all('table')

            if not tables:
                logger.error("No tables found in HTML file")
                return []

            logger.info(f"Found {len(tables)} table(s) in HTML file")

            # Process the first table (usually the main data table)
            main_table = tables[0]

            # Extract headers
            headers = self._extract_headers(main_table)
            logger.info(f"Found columns: {headers}")

            # Extract rows
            rows = main_table.find_all('tr')

            for row in rows[1:]:  # Skip header row
                cells = row.find_all(['td', 'th'])

                if len(cells) >= len(headers):
                    player_data = {}

                    for i, cell in enumerate(cells[:len(headers)]):
                        header = headers[i]
                        value = self._clean_cell_value(cell.get_text())
                        player_data[header] = value

                    # Only add if we got meaningful data
                    if player_data.get('Name', '').strip():
                        self.players.append(player_data)

            logger.info(f"Extracted {len(self.players)} players")
            return self.players

        except FileNotFoundError:
            logger.error(f"HTML file not found: {self.html_file_path}")
            return []
        except Exception as e:
            logger.error(f"Error parsing HTML: {e}", exc_info=True)
            return []

    def _extract_headers(self, table) -> List[str]:
        """Extract column headers from table"""
        headers = []

        # Try to find header row
        header_row = table.find('tr')
        if header_row:
            header_cells = header_row.find_all(['th', 'td'])
            for cell in header_cells:
                header_text = self._clean_cell_value(cell.get_text())
                headers.append(header_text)

        return headers

    def _clean_cell_value(self, value: str) -> str:
        """Clean and normalize cell values"""
        if not value:
            return ""

        # Remove extra whitespace
        value = ' '.join(value.split())

        # Remove non-breaking spaces and other special chars
        value = value.replace('\xa0', ' ')
        value = value.replace('\u200b', '')  # Zero-width space

        return value.strip()

    def map_to_csv_format(self) -> List[Dict]:
        """
        Map extracted player data to the expected CSV format

        Returns:
            List of dictionaries in the format expected by lineup optimizer
        """
        mapped_players = []

        for player in self.players:
            mapped_player = {
                'Name': '',
                'Best Position': '',
                'Age': '',
                'CA': '',
                'PA': '',
                'Striker': '',
                'AM(L)': '',
                'AM(C)': '',
                'AM(R)': '',
                'DM(L)': '',
                'DM(R)': '',
                'D(C)': '',
                'D(R/L)': '',
                'GK': '',
                'Chosen Role': ''
            }

            # Map common field names
            field_mappings = {
                'Name': ['Name', 'Player', 'Player Name'],
                'Best Position': ['Best Position', 'Position', 'Pos', 'Best Pos', 'Natural Position'],
                'Age': ['Age', 'Ag'],
                'CA': ['CA', 'Current Ability', 'Cur Abil', 'Ability'],
                'PA': ['PA', 'Potential Ability', 'Pot Abil', 'Potential'],
                'Striker': ['ST', 'Striker', 'ST Rating', 'Str'],
                'AM(L)': ['AML', 'AM L', 'AM (L)', 'Left AM', 'AMl'],
                'AM(C)': ['AMC', 'AM C', 'AM (C)', 'Central AM', 'AMc'],
                'AM(R)': ['AMR', 'AM R', 'AM (R)', 'Right AM', 'AMr'],
                'DM(L)': ['DML', 'DM L', 'DM (L)', 'Left DM', 'DMl'],
                'DM(R)': ['DMR', 'DM R', 'DM (R)', 'Right DM', 'DMr'],
                'D(C)': ['DC', 'D C', 'D (C)', 'Central Defender', 'CD', 'CB'],
                'D(R/L)': ['DR/DL', 'D R/L', 'D (R/L)', 'Full Back', 'FB', 'WB'],
                'GK': ['GK', 'Goalkeeper', 'Keeper'],
                'Chosen Role': ['Role', 'Current Role', 'Position', 'Chosen Role']
            }

            # Try to map each field
            for output_field, possible_inputs in field_mappings.items():
                for input_field in possible_inputs:
                    if input_field in player:
                        mapped_player[output_field] = player[input_field]
                        break

            # Clean numeric values
            for field in ['Age', 'CA', 'PA', 'Striker', 'AM(L)', 'AM(C)', 'AM(R)',
                         'DM(L)', 'DM(R)', 'D(C)', 'D(R/L)', 'GK']:
                mapped_player[field] = self._clean_numeric_value(mapped_player[field])

            mapped_players.append(mapped_player)

        return mapped_players

    def _clean_numeric_value(self, value: str) -> str:
        """Clean numeric values, removing any non-numeric characters"""
        if not value:
            return ''

        # Remove everything except digits, decimal points, and minus signs
        cleaned = re.sub(r'[^\d.\-]', '', value)

        # Validate it's a number
        try:
            float(cleaned) if '.' in cleaned else int(cleaned)
            return cleaned
        except (ValueError, TypeError):
            return ''

    def export_to_csv(self, output_file: str = "players-extracted.csv"):
        """
        Export mapped player data to CSV

        Args:
            output_file: Path to output CSV file
        """
        if not self.players:
            logger.warning("No player data to export")
            return

        mapped_players = self.map_to_csv_format()

        try:
            fieldnames = [
                'Name', 'Best Position', 'Age', 'CA', 'PA',
                'Striker', 'AM(L)', 'AM(C)', 'AM(R)',
                'DM(L)', 'DM(R)', 'D(C)', 'D(R/L)', 'GK',
                'Chosen Role'
            ]

            with open(output_file, 'w', newline='', encoding='utf-8') as csvfile:
                writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
                writer.writeheader()
                writer.writerows(mapped_players)

            logger.info(f"✓ Exported {len(mapped_players)} players to {output_file}")

            # Print summary
            print("\n" + "="*70)
            print("EXPORT SUMMARY")
            print("="*70)
            print(f"Players exported: {len(mapped_players)}")
            print(f"Output file: {output_file}")

            # Show which fields were found
            sample_player = mapped_players[0] if mapped_players else {}
            found_fields = [k for k, v in sample_player.items() if v]
            missing_fields = [k for k, v in sample_player.items() if not v]

            print(f"\nFound fields: {', '.join(found_fields)}")
            if missing_fields:
                print(f"Missing fields: {', '.join(missing_fields)}")
                print("\nNote: Missing fields may need to be added to your FM26 custom view.")

            print("="*70)

        except Exception as e:
            logger.error(f"Error exporting to CSV: {e}", exc_info=True)


def main():
    """Main entry point"""
    print("="*70)
    print("FM26 HTML Export Parser")
    print("="*70)
    print()

    # Check command line arguments
    if len(sys.argv) < 2:
        print("Usage: python fm26_html_parser.py <html_file>")
        print()
        print("Example:")
        print("  python fm26_html_parser.py squad_export.html")
        print()
        print("To export HTML from FM26:")
        print("  1. Go to Squad screen")
        print("  2. Set up custom view with all required columns")
        print("  3. Press Ctrl+P or use Print Screen")
        print("  4. Save as 'Web Page' (.html)")
        print("  5. Run this script on the saved HTML file")
        print()
        sys.exit(1)

    html_file = sys.argv[1]

    # Check file exists
    if not Path(html_file).exists():
        print(f"✗ Error: File not found: {html_file}")
        sys.exit(1)

    print(f"Input file: {html_file}")
    print()

    # Parse HTML
    print("1. Parsing HTML file...")
    extractor = PlayerDataExtractor(html_file)
    players = extractor.parse_html()

    if not players:
        print("✗ No player data found in HTML file")
        print()
        print("Troubleshooting:")
        print("  - Make sure the HTML file contains a table with player data")
        print("  - Check that your FM26 export includes player names")
        print("  - Try exporting again from FM26")
        sys.exit(1)

    print(f"✓ Found {len(players)} players")
    print()

    # Export to CSV
    print("2. Exporting to CSV...")
    extractor.export_to_csv()
    print()

    print("✓ Complete! You can now use the CSV file with the lineup optimizer:")
    print("  python fm_team_selector_optimal.py players-extracted.csv")
    print()


if __name__ == "__main__":
    main()
