"""
Player Name Finder for FM26 save files.

Searches decompressed database for player names using various string encoding patterns.
"""

import re
from dataclasses import dataclass
from typing import List, Optional, Set, Tuple

from ..core.binary_reader import BinaryReader


@dataclass
class NameMatch:
    """A matched player name in the database."""
    name: str
    offset: int
    prefix_length: int  # Length prefix size (1, 2, or 4 bytes)
    context_before: bytes
    context_after: bytes

    @property
    def record_start_estimate(self) -> int:
        """Estimate where the player record might start (before the name)."""
        # Names are usually not at the very start of a record
        # Try to estimate based on common patterns
        return max(0, self.offset - 100)


class PlayerNameFinder:
    """
    Finds player names in decompressed FM26 database.

    Search strategies:
    1. Length-prefixed strings (most common in FM)
    2. Known player names as anchors
    3. Pattern matching for name-like strings
    """

    # Common FM26 string length prefix sizes
    LENGTH_PREFIXES = [1, 2, 4]

    def __init__(self, data: bytes):
        self.data = data
        self.reader = BinaryReader(data)
        self._matches: List[NameMatch] = []

    def find_known_names(self, names: List[str], context_size: int = 64) -> List[NameMatch]:
        """
        Search for specific known player names.

        Args:
            names: List of player names to search for
            context_size: Bytes of context to capture around each match

        Returns:
            List of NameMatch objects for found names
        """
        matches = []

        for name in names:
            name_bytes = name.encode("utf-8")

            # Try each length prefix size
            for prefix_len in self.LENGTH_PREFIXES:
                pattern = len(name_bytes).to_bytes(prefix_len, "little") + name_bytes
                positions = self.reader.find_all(pattern)

                for pos in positions:
                    # Capture context
                    start = max(0, pos - context_size)
                    end = min(len(self.data), pos + len(pattern) + context_size)

                    matches.append(NameMatch(
                        name=name,
                        offset=pos + prefix_len,  # Offset to actual name, not prefix
                        prefix_length=prefix_len,
                        context_before=self.data[start:pos],
                        context_after=self.data[pos + len(pattern):end]
                    ))

            # Also search for raw name without prefix (less reliable)
            raw_positions = self.reader.find_all(name_bytes)
            for pos in raw_positions:
                # Check if this was already found with a prefix
                already_found = any(
                    m.offset == pos for m in matches
                )
                if not already_found:
                    start = max(0, pos - context_size)
                    end = min(len(self.data), pos + len(name_bytes) + context_size)

                    matches.append(NameMatch(
                        name=name,
                        offset=pos,
                        prefix_length=0,  # No prefix
                        context_before=self.data[start:pos],
                        context_after=self.data[pos + len(name_bytes):end]
                    ))

        self._matches = matches
        return matches

    def find_name_like_strings(self, min_length: int = 3, max_length: int = 50) -> List[Tuple[int, str]]:
        """
        Find strings that look like player names.

        Heuristics:
        - Start with uppercase letter
        - Contains only letters, spaces, hyphens, apostrophes
        - Reasonable length

        Returns:
            List of (offset, string) tuples
        """
        results = []
        name_pattern = re.compile(r"^[A-Z][a-zA-Z'\-\s]+$")

        pos = 0
        while pos < len(self.data) - min_length:
            # Try 2-byte length prefix (most common)
            if pos + 2 < len(self.data):
                length = int.from_bytes(self.data[pos:pos+2], "little")

                if min_length <= length <= max_length:
                    string_start = pos + 2
                    string_end = string_start + length

                    if string_end <= len(self.data):
                        try:
                            candidate = self.data[string_start:string_end].decode("utf-8")
                            if name_pattern.match(candidate):
                                results.append((pos, candidate))
                        except (UnicodeDecodeError, ValueError):
                            pass
            pos += 1

        return results

    def analyze_spacing(self) -> dict:
        """
        Analyze spacing between found name matches.

        This helps identify record size and structure.

        Returns:
            Dictionary with spacing analysis
        """
        if len(self._matches) < 2:
            return {"error": "Need at least 2 matches for spacing analysis"}

        # Sort by offset
        sorted_matches = sorted(self._matches, key=lambda m: m.offset)

        # Calculate deltas between consecutive matches
        deltas = []
        for i in range(len(sorted_matches) - 1):
            delta = sorted_matches[i + 1].offset - sorted_matches[i].offset
            deltas.append({
                "from_name": sorted_matches[i].name,
                "to_name": sorted_matches[i + 1].name,
                "delta": delta,
                "from_offset": sorted_matches[i].offset,
                "to_offset": sorted_matches[i + 1].offset
            })

        # Look for common delta (might indicate fixed record size)
        delta_values = [d["delta"] for d in deltas]

        return {
            "match_count": len(sorted_matches),
            "deltas": deltas,
            "min_delta": min(delta_values) if delta_values else 0,
            "max_delta": max(delta_values) if delta_values else 0,
            "avg_delta": sum(delta_values) / len(delta_values) if delta_values else 0,
            "offset_range": (sorted_matches[0].offset, sorted_matches[-1].offset)
        }

    def get_context_pattern(self, match: NameMatch, before_bytes: int = 32) -> bytes:
        """
        Get the bytes immediately before a name match.

        These bytes often contain record headers, player IDs, etc.
        """
        start = max(0, match.offset - match.prefix_length - before_bytes)
        end = match.offset - match.prefix_length
        return self.data[start:end]

    def compare_contexts(self) -> dict:
        """
        Compare the context patterns around different name matches.

        Looking for common headers/prefixes that indicate record boundaries.
        """
        if not self._matches:
            return {"error": "No matches found"}

        contexts = []
        for match in self._matches:
            ctx = self.get_context_pattern(match, before_bytes=32)
            contexts.append({
                "name": match.name,
                "offset": match.offset,
                "context_hex": ctx.hex(),
                "context_bytes": list(ctx[-16:])  # Last 16 bytes before name
            })

        # Look for common suffix patterns in contexts
        suffixes_8 = [c["context_bytes"][-8:] for c in contexts if len(c["context_bytes"]) >= 8]

        return {
            "contexts": contexts,
            "common_suffix_candidates": self._find_common_patterns(suffixes_8)
        }

    def _find_common_patterns(self, byte_lists: List[list]) -> List[dict]:
        """Find common patterns across byte lists."""
        if not byte_lists:
            return []

        # Count occurrences of each unique pattern
        patterns = {}
        for bl in byte_lists:
            key = tuple(bl)
            patterns[key] = patterns.get(key, 0) + 1

        # Return patterns that appear more than once
        common = [
            {"pattern": list(k), "count": v, "hex": bytes(k).hex()}
            for k, v in patterns.items()
            if v > 1
        ]

        return sorted(common, key=lambda x: -x["count"])


def find_players_in_save(data: bytes, player_names: List[str]) -> dict:
    """
    Convenience function to find players in decompressed save data.

    Args:
        data: Decompressed FM26 database bytes
        player_names: List of player names to search for

    Returns:
        Dictionary with search results and analysis
    """
    finder = PlayerNameFinder(data)

    # Find known names
    matches = finder.find_known_names(player_names)

    # Analyze results
    spacing = finder.analyze_spacing()
    contexts = finder.compare_contexts()

    return {
        "found_count": len(matches),
        "matches": [
            {
                "name": m.name,
                "offset": m.offset,
                "prefix_length": m.prefix_length,
                "offset_hex": hex(m.offset)
            }
            for m in matches
        ],
        "spacing_analysis": spacing,
        "context_analysis": contexts
    }
