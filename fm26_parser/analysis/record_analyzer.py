"""
Record Analyzer for FM26 save files.

Analyzes byte patterns around player names to identify record structure.
"""

import struct
from dataclasses import dataclass
from typing import List, Optional, Tuple, Dict
from collections import defaultdict

from ..core.binary_reader import BinaryReader


@dataclass
class PlayerRecord:
    """A discovered player record."""
    offset: int  # Start of record (or name)
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    full_name: Optional[str] = None
    raw_context: bytes = b""
    attributes_region: bytes = b""

    @property
    def name(self) -> str:
        if self.full_name:
            return self.full_name
        parts = []
        if self.first_name:
            parts.append(self.first_name)
        if self.last_name:
            parts.append(self.last_name)
        return " ".join(parts) if parts else f"Unknown@{hex(self.offset)}"


class RecordAnalyzer:
    """
    Analyzes FM26 database to discover player record structure.

    Strategy:
    1. Find known last names
    2. Look backwards for first names (length-prefixed strings)
    3. Look further back for record headers
    4. Look forwards for attribute data
    """

    def __init__(self, data: bytes):
        self.data = data
        self.reader = BinaryReader(data)

    def decode_string_at(self, offset: int, prefix_len: int = 4) -> Tuple[str, int]:
        """
        Decode a length-prefixed string at the given offset.

        Returns:
            Tuple of (decoded_string, total_bytes_consumed)
        """
        if offset < 0 or offset + prefix_len >= len(self.data):
            return "", 0

        if prefix_len == 1:
            length = self.data[offset]
        elif prefix_len == 2:
            length = struct.unpack_from("<H", self.data, offset)[0]
        elif prefix_len == 4:
            length = struct.unpack_from("<I", self.data, offset)[0]
        else:
            return "", 0

        # Sanity check on length
        if length > 200 or length == 0:
            return "", 0

        string_start = offset + prefix_len
        string_end = string_start + length

        if string_end > len(self.data):
            return "", 0

        try:
            decoded = self.data[string_start:string_end].decode("utf-8")
            # Validate it looks like a name (printable, reasonable chars)
            if all(c.isprintable() or c.isspace() for c in decoded):
                return decoded, prefix_len + length
            return "", 0
        except (UnicodeDecodeError, ValueError):
            return "", 0

    def find_name_at(self, last_name_offset: int, last_name: str) -> PlayerRecord:
        """
        Given a known last name location, try to find the full player name.

        FM format appears to be: [first_name_len][first_name][last_name_len][last_name]
        """
        record = PlayerRecord(offset=last_name_offset, last_name=last_name)

        # The last name offset is AFTER the length prefix, so go back
        # to find the length prefix and then look for first name before that

        # Check different prefix sizes
        for prefix_len in [4, 2, 1]:
            # This is where the last name length prefix would be
            last_name_prefix_offset = last_name_offset - prefix_len

            if last_name_prefix_offset < 0:
                continue

            # Verify the length matches
            if prefix_len == 4:
                expected_len = struct.unpack_from("<I", self.data, last_name_prefix_offset)[0]
            elif prefix_len == 2:
                expected_len = struct.unpack_from("<H", self.data, last_name_prefix_offset)[0]
            else:
                expected_len = self.data[last_name_prefix_offset]

            if expected_len != len(last_name):
                continue

            # Found correct prefix! Now look for first name before this
            # Try searching backwards for another string
            for first_prefix_len in [4, 2, 1]:
                # Maximum reasonable first name length
                for search_back in range(4, 50):
                    potential_first_start = last_name_prefix_offset - search_back

                    if potential_first_start < 0:
                        break

                    first_name, consumed = self.decode_string_at(potential_first_start, first_prefix_len)

                    # Check if this string ends right at our last name prefix
                    if first_name and potential_first_start + consumed == last_name_prefix_offset:
                        record.first_name = first_name
                        record.offset = potential_first_start
                        break

                if record.first_name:
                    break

            if record.first_name:
                break

        # Capture context around the record
        context_start = max(0, record.offset - 64)
        context_end = min(len(self.data), last_name_offset + len(last_name) + 128)
        record.raw_context = self.data[context_start:context_end]

        # The region after the name likely contains attributes
        attr_start = last_name_offset + len(last_name)
        attr_end = min(len(self.data), attr_start + 200)
        record.attributes_region = self.data[attr_start:attr_end]

        return record

    def find_all_players(self, last_names: List[str]) -> List[PlayerRecord]:
        """
        Find all players matching the given last names.

        Args:
            last_names: List of last names to search for

        Returns:
            List of PlayerRecord objects
        """
        records = []

        for last_name in last_names:
            name_bytes = last_name.encode("utf-8")

            # Search with 4-byte length prefix (most common based on test)
            for prefix_len in [4]:
                pattern = len(name_bytes).to_bytes(prefix_len, "little") + name_bytes
                positions = self.reader.find_all(pattern)

                for pos in positions:
                    name_offset = pos + prefix_len  # Offset to actual name
                    record = self.find_name_at(name_offset, last_name)
                    records.append(record)

        return records

    def analyze_attribute_patterns(self, records: List[PlayerRecord]) -> Dict:
        """
        Analyze the bytes after player names to find attribute patterns.

        Returns:
            Analysis of attribute region patterns
        """
        if not records:
            return {"error": "No records to analyze"}

        # Look at first N bytes after each name
        byte_patterns = defaultdict(list)

        for record in records:
            if len(record.attributes_region) < 50:
                continue

            # Record byte values at each position
            for i, byte_val in enumerate(record.attributes_region[:100]):
                byte_patterns[i].append(byte_val)

        # Analyze each position
        analysis = {
            "positions": {},
            "likely_attributes": []
        }

        for pos, values in sorted(byte_patterns.items()):
            if not values:
                continue

            min_val = min(values)
            max_val = max(values)
            avg_val = sum(values) / len(values)

            analysis["positions"][pos] = {
                "min": min_val,
                "max": max_val,
                "avg": round(avg_val, 1),
                "range": max_val - min_val,
                "sample": values[:5]
            }

            # Heuristic: FM attributes are 1-20
            if 1 <= min_val <= 20 and 1 <= max_val <= 20 and max_val - min_val <= 19:
                analysis["likely_attributes"].append({
                    "offset": pos,
                    "min": min_val,
                    "max": max_val,
                    "likely_attribute": True
                })

        return analysis

    def print_record_details(self, record: PlayerRecord, show_hex: bool = True) -> None:
        """Print detailed information about a player record."""
        print(f"\nPlayer: {record.name}")
        print(f"  Record offset: {record.offset} ({hex(record.offset)})")
        print(f"  First name: {record.first_name}")
        print(f"  Last name: {record.last_name}")

        if show_hex and record.attributes_region:
            print(f"  Attributes region (first 50 bytes):")
            hex_str = record.attributes_region[:50].hex()
            # Format as groups of 2 chars
            formatted = " ".join(hex_str[i:i+2] for i in range(0, len(hex_str), 2))
            print(f"    {formatted}")

            # Also show as integers for attribute analysis
            print(f"  As integers (first 30 bytes):")
            ints = list(record.attributes_region[:30])
            print(f"    {ints}")


def analyze_save(data: bytes, search_names: List[str]) -> Dict:
    """
    Main analysis function for FM26 save data.

    Args:
        data: Decompressed FM26 database bytes
        search_names: List of last names to search for

    Returns:
        Analysis results
    """
    analyzer = RecordAnalyzer(data)

    # Find all matching players
    records = analyzer.find_all_players(search_names)

    # Filter to unique players (by full name)
    unique_records = {}
    for record in records:
        key = record.name
        if key not in unique_records:
            unique_records[key] = record

    records = list(unique_records.values())

    # Print details
    print(f"\nFound {len(records)} unique player records:")
    for record in records[:20]:
        analyzer.print_record_details(record)

    # Analyze attribute patterns
    attr_analysis = analyzer.analyze_attribute_patterns(records)

    return {
        "record_count": len(records),
        "records": records,
        "attribute_analysis": attr_analysis
    }
