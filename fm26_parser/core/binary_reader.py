"""
Binary Reader utilities for FM26 save file parsing.

Provides convenient methods for reading various data types from binary data.
"""

import struct
from typing import Optional, Tuple


class BinaryReader:
    """
    Reader for binary data with position tracking.

    Supports reading common FM26 data types:
    - Integers (uint8, uint16, uint32, int8, int16, int32)
    - Floats (float32, float64)
    - Strings (length-prefixed, null-terminated)
    """

    def __init__(self, data: bytes, offset: int = 0):
        self.data = data
        self.offset = offset

    def __len__(self) -> int:
        return len(self.data)

    @property
    def remaining(self) -> int:
        """Bytes remaining from current position."""
        return len(self.data) - self.offset

    def seek(self, offset: int) -> None:
        """Set absolute position."""
        if offset < 0 or offset > len(self.data):
            raise ValueError(f"Invalid offset {offset} for data of length {len(self.data)}")
        self.offset = offset

    def skip(self, count: int) -> None:
        """Skip forward by count bytes."""
        self.offset += count

    def peek(self, count: int) -> bytes:
        """Peek at next count bytes without advancing position."""
        return self.data[self.offset:self.offset + count]

    def read_bytes(self, count: int) -> bytes:
        """Read count bytes and advance position."""
        result = self.data[self.offset:self.offset + count]
        self.offset += count
        return result

    # Integer readers (Little Endian)
    def read_uint8(self) -> int:
        """Read unsigned 8-bit integer."""
        val = self.data[self.offset]
        self.offset += 1
        return val

    def read_int8(self) -> int:
        """Read signed 8-bit integer."""
        val = struct.unpack_from("<b", self.data, self.offset)[0]
        self.offset += 1
        return val

    def read_uint16(self) -> int:
        """Read unsigned 16-bit little-endian integer."""
        val = struct.unpack_from("<H", self.data, self.offset)[0]
        self.offset += 2
        return val

    def read_int16(self) -> int:
        """Read signed 16-bit little-endian integer."""
        val = struct.unpack_from("<h", self.data, self.offset)[0]
        self.offset += 2
        return val

    def read_uint32(self) -> int:
        """Read unsigned 32-bit little-endian integer."""
        val = struct.unpack_from("<I", self.data, self.offset)[0]
        self.offset += 4
        return val

    def read_int32(self) -> int:
        """Read signed 32-bit little-endian integer."""
        val = struct.unpack_from("<i", self.data, self.offset)[0]
        self.offset += 4
        return val

    def read_uint64(self) -> int:
        """Read unsigned 64-bit little-endian integer."""
        val = struct.unpack_from("<Q", self.data, self.offset)[0]
        self.offset += 8
        return val

    # Float readers
    def read_float32(self) -> float:
        """Read 32-bit little-endian float."""
        val = struct.unpack_from("<f", self.data, self.offset)[0]
        self.offset += 4
        return val

    def read_float64(self) -> float:
        """Read 64-bit little-endian double."""
        val = struct.unpack_from("<d", self.data, self.offset)[0]
        self.offset += 8
        return val

    # String readers
    def read_string_prefixed(self, length_bytes: int = 2, encoding: str = "utf-8") -> str:
        """
        Read a length-prefixed string.

        Args:
            length_bytes: Size of length prefix (1, 2, or 4 bytes)
            encoding: String encoding (default UTF-8)

        Returns:
            Decoded string
        """
        if length_bytes == 1:
            length = self.read_uint8()
        elif length_bytes == 2:
            length = self.read_uint16()
        elif length_bytes == 4:
            length = self.read_uint32()
        else:
            raise ValueError(f"Invalid length_bytes: {length_bytes}")

        if length > self.remaining:
            raise ValueError(f"String length {length} exceeds remaining data {self.remaining}")

        string_bytes = self.read_bytes(length)
        return string_bytes.decode(encoding, errors="replace")

    def read_string_null_terminated(self, max_length: int = 256, encoding: str = "utf-8") -> str:
        """
        Read a null-terminated string.

        Args:
            max_length: Maximum bytes to read
            encoding: String encoding

        Returns:
            Decoded string (without null terminator)
        """
        end = min(self.offset + max_length, len(self.data))
        null_pos = self.data.find(b"\x00", self.offset, end)

        if null_pos == -1:
            # No null found, read up to max_length
            string_bytes = self.data[self.offset:end]
            self.offset = end
        else:
            string_bytes = self.data[self.offset:null_pos]
            self.offset = null_pos + 1  # Skip the null byte

        return string_bytes.decode(encoding, errors="replace")

    def read_string_fixed(self, length: int, encoding: str = "utf-8") -> str:
        """
        Read a fixed-length string, stripping null padding.

        Args:
            length: Number of bytes to read
            encoding: String encoding

        Returns:
            Decoded string with null bytes stripped
        """
        string_bytes = self.read_bytes(length)
        return string_bytes.rstrip(b"\x00").decode(encoding, errors="replace")

    # Search methods
    def find(self, pattern: bytes, start: Optional[int] = None, end: Optional[int] = None) -> int:
        """
        Find pattern in data.

        Args:
            pattern: Bytes to find
            start: Start offset (default: current position)
            end: End offset (default: end of data)

        Returns:
            Offset of pattern, or -1 if not found
        """
        start = start if start is not None else self.offset
        end = end if end is not None else len(self.data)
        return self.data.find(pattern, start, end)

    def find_all(self, pattern: bytes, start: Optional[int] = None, end: Optional[int] = None) -> list:
        """
        Find all occurrences of pattern in data.

        Returns:
            List of offsets where pattern was found
        """
        start = start if start is not None else 0
        end = end if end is not None else len(self.data)

        positions = []
        pos = start
        while True:
            pos = self.data.find(pattern, pos, end)
            if pos == -1:
                break
            positions.append(pos)
            pos += 1  # Move past this match
        return positions

    # Context extraction
    def get_context(self, offset: int, before: int = 32, after: int = 32) -> Tuple[bytes, int, int]:
        """
        Get bytes surrounding a given offset.

        Args:
            offset: Center offset
            before: Bytes to include before offset
            after: Bytes to include after offset

        Returns:
            Tuple of (context_bytes, start_offset, end_offset)
        """
        start = max(0, offset - before)
        end = min(len(self.data), offset + after)
        return self.data[start:end], start, end

    # Static read methods (don't advance position)
    def read_at(self, offset: int, size: int) -> bytes:
        """Read size bytes at specific offset without changing position."""
        return self.data[offset:offset + size]

    def read_uint8_at(self, offset: int) -> int:
        """Read uint8 at specific offset without changing position."""
        return self.data[offset]

    def read_uint16_at(self, offset: int) -> int:
        """Read uint16 at specific offset without changing position."""
        return struct.unpack_from("<H", self.data, offset)[0]

    def read_uint32_at(self, offset: int) -> int:
        """Read uint32 at specific offset without changing position."""
        return struct.unpack_from("<I", self.data, offset)[0]

    def read_float32_at(self, offset: int) -> float:
        """Read float32 at specific offset without changing position."""
        return struct.unpack_from("<f", self.data, offset)[0]
