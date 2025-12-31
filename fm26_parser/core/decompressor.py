"""
FM26 Save File Decompressor

Handles ZSTD multi-frame decompression of FM26 save files.
"""

import struct
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Tuple
import zstandard as zstd


# ZSTD magic bytes
ZSTD_MAGIC = bytes([0x28, 0xB5, 0x2F, 0xFD])

# FM26 header constants
FM_HEADER_SIZE = 26
FM_MAGIC = b"fmf."


@dataclass
class FM26Header:
    """Parsed FM26 save file header."""
    raw_bytes: bytes
    magic_prefix: int  # First 2 bytes
    signature: bytes   # "fmf." signature
    version_byte: int  # Version/type indicator

    @property
    def is_valid(self) -> bool:
        return self.signature == FM_MAGIC


@dataclass
class ZSTDFrame:
    """Information about a ZSTD frame in the save file."""
    offset: int           # Byte offset in file
    compressed_size: int  # Size of compressed data
    frame_index: int      # Frame number


class FM26Decompressor:
    """
    Decompresses FM26 save files.

    FM26 saves use a custom container format:
    - 26-byte header with "fmf." signature
    - Multiple concatenated ZSTD frames
    - Frame 4 contains the main game database (~282MB decompressed)
    """

    def __init__(self, save_path: Path):
        self.save_path = Path(save_path)
        self._raw_data: Optional[bytes] = None
        self._header: Optional[FM26Header] = None
        self._frames: List[ZSTDFrame] = []
        self._decompressor = zstd.ZstdDecompressor()

    def load(self) -> None:
        """Load the save file into memory."""
        with open(self.save_path, "rb") as f:
            self._raw_data = f.read()
        self._parse_header()
        self._find_frames()

    @property
    def header(self) -> FM26Header:
        """Get the parsed header."""
        if self._header is None:
            raise RuntimeError("Must call load() first")
        return self._header

    @property
    def frame_count(self) -> int:
        """Number of ZSTD frames found."""
        return len(self._frames)

    @property
    def file_size(self) -> int:
        """Size of save file in bytes."""
        if self._raw_data is None:
            return 0
        return len(self._raw_data)

    def _parse_header(self) -> None:
        """Parse the 26-byte FM26 header."""
        if self._raw_data is None or len(self._raw_data) < FM_HEADER_SIZE:
            raise ValueError("Invalid save file: too small")

        header_bytes = self._raw_data[:FM_HEADER_SIZE]

        self._header = FM26Header(
            raw_bytes=header_bytes,
            magic_prefix=struct.unpack("<H", header_bytes[0:2])[0],
            signature=header_bytes[2:6],
            version_byte=header_bytes[6]
        )

        if not self._header.is_valid:
            raise ValueError(f"Invalid FM26 save file: bad signature {self._header.signature!r}")

    def _find_frames(self) -> None:
        """Locate all ZSTD frames in the save file."""
        if self._raw_data is None:
            return

        self._frames = []
        pos = FM_HEADER_SIZE  # Start after header
        frame_idx = 0

        while pos < len(self._raw_data) - 4:
            # Look for ZSTD magic bytes
            if self._raw_data[pos:pos+4] == ZSTD_MAGIC:
                # Found a frame, estimate its size by finding next magic or EOF
                next_pos = self._find_next_frame(pos + 4)
                frame_size = next_pos - pos if next_pos else len(self._raw_data) - pos

                self._frames.append(ZSTDFrame(
                    offset=pos,
                    compressed_size=frame_size,
                    frame_index=frame_idx
                ))
                frame_idx += 1
                pos = next_pos if next_pos else len(self._raw_data)
            else:
                pos += 1

    def _find_next_frame(self, start: int) -> Optional[int]:
        """Find the offset of the next ZSTD frame after start."""
        if self._raw_data is None:
            return None

        pos = start
        while pos < len(self._raw_data) - 4:
            if self._raw_data[pos:pos+4] == ZSTD_MAGIC:
                return pos
            pos += 1
        return None

    def get_frame_info(self) -> List[dict]:
        """Get information about all frames."""
        return [
            {
                "index": f.frame_index,
                "offset": f.offset,
                "compressed_size": f.compressed_size
            }
            for f in self._frames
        ]

    def decompress_frame(self, frame_index: int) -> bytes:
        """
        Decompress a specific frame.

        Args:
            frame_index: Zero-based frame index

        Returns:
            Decompressed bytes
        """
        if self._raw_data is None:
            raise RuntimeError("Must call load() first")

        if frame_index >= len(self._frames):
            raise IndexError(f"Frame {frame_index} not found (only {len(self._frames)} frames)")

        frame = self._frames[frame_index]
        compressed_data = self._raw_data[frame.offset:frame.offset + frame.compressed_size]

        # Use streaming decompression to handle unknown output size
        stream_reader = self._decompressor.stream_reader(compressed_data)
        chunks = []
        while True:
            chunk = stream_reader.read(16 * 1024 * 1024)  # 16MB chunks
            if not chunk:
                break
            chunks.append(chunk)

        return b"".join(chunks)

    def decompress_main_database(self) -> bytes:
        """
        Decompress the main game database (Frame 4).

        This is where player data is stored.
        """
        # Frame 4 is typically the main database (index 3 in 0-based)
        # But let's find the largest frame as a heuristic
        if not self._frames:
            raise RuntimeError("No frames found")

        # Find the largest frame (likely the main database)
        largest_frame = max(self._frames, key=lambda f: f.compressed_size)

        print(f"Decompressing frame {largest_frame.frame_index} "
              f"({largest_frame.compressed_size / 1024 / 1024:.1f} MB compressed)...")

        return self.decompress_frame(largest_frame.frame_index)

    def decompress_all(self) -> List[Tuple[int, bytes]]:
        """
        Decompress all frames.

        Returns:
            List of (frame_index, decompressed_data) tuples
        """
        results = []
        for frame in self._frames:
            try:
                data = self.decompress_frame(frame.frame_index)
                results.append((frame.frame_index, data))
            except Exception as e:
                print(f"Warning: Failed to decompress frame {frame.frame_index}: {e}")
        return results


def decompress_save(save_path: Path) -> bytes:
    """
    Convenience function to decompress an FM26 save file.

    Args:
        save_path: Path to the .fm save file

    Returns:
        Decompressed main database bytes
    """
    decompressor = FM26Decompressor(save_path)
    decompressor.load()
    return decompressor.decompress_main_database()
