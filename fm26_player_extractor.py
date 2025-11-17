#!/usr/bin/env python3
"""
FM26 Player Data Extractor
Extracts player data from Football Manager 2026 memory and exports to CSV

IMPORTANT: This script requires you to find memory addresses using Cheat Engine first.
See the accompanying guide: docs/cheat-engine-finding-addresses.md

Legal Disclaimer:
This tool is provided for educational and personal use only. It may violate
Football Manager's EULA. Use at your own risk. The author assumes no liability.
This tool is for single-player use only.
"""

import sys
import csv
import logging
from typing import List, Dict, Optional, Any
from dataclasses import dataclass, field
from pathlib import Path

try:
    import pymem
    import pymem.process
except ImportError:
    print("ERROR: pymem library not installed. Install it with: pip install pymem")
    sys.exit(1)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('fm26_extractor.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


# ============================================================================
# CONFIGURATION SECTION - YOU MUST FILL THIS IN USING CHEAT ENGINE
# ============================================================================

class MemoryConfig:
    """
    Memory addresses and offsets for FM26 player data.

    YOU MUST UPDATE THESE VALUES USING CHEAT ENGINE!
    See docs/cheat-engine-finding-addresses.md for instructions.
    """

    # FM26 executable name
    PROCESS_NAME = "fm.exe"

    # Alternative full path if needed
    PROCESS_PATH = r"C:\Program Files (x86)\Steam\steamapps\common\Football Manager 26\fm.exe"

    # Module containing game logic (usually game_plugin.dll for FM26)
    GAME_MODULE = "game_plugin.dll"

    # ===== POINTER CHAINS TO FIND WITH CHEAT ENGINE =====
    # These are examples - you need to find the actual values for FM26

    # Base address for squad/team data (find using Cheat Engine)
    # Example format: base_module + offset
    SQUAD_BASE_OFFSET = 0x0  # PLACEHOLDER - FIND WITH CHEAT ENGINE

    # Pointer chain to player array
    # Format: [offset1, offset2, offset3, ...]
    # Each offset is applied sequentially after dereferencing
    PLAYER_ARRAY_OFFSETS = [
        0x0,  # PLACEHOLDER - FIND WITH CHEAT ENGINE
        0x0,  # PLACEHOLDER
        0x0,  # PLACEHOLDER
    ]

    # Pointer chain to player count
    PLAYER_COUNT_OFFSETS = [
        0x0,  # PLACEHOLDER - FIND WITH CHEAT ENGINE
    ]

    # ===== PLAYER STRUCTURE OFFSETS =====
    # Offsets within each player object (find by analyzing player structure)

    # Player information offsets
    PLAYER_NAME_OFFSET = 0x0  # PLACEHOLDER - pointer to string
    PLAYER_AGE_OFFSET = 0x0  # PLACEHOLDER - usually 4-byte integer
    PLAYER_CA_OFFSET = 0x0  # PLACEHOLDER - Current Ability (int)
    PLAYER_PA_OFFSET = 0x0  # PLACEHOLDER - Potential Ability (int)
    PLAYER_BEST_POS_OFFSET = 0x0  # PLACEHOLDER - pointer to position string

    # Position rating offsets (usually 1-20 scale, might be float or int)
    PLAYER_RATING_GK_OFFSET = 0x0  # PLACEHOLDER
    PLAYER_RATING_DC_OFFSET = 0x0  # PLACEHOLDER - Center Back
    PLAYER_RATING_DRL_OFFSET = 0x0  # PLACEHOLDER - Full Back (D(R/L))
    PLAYER_RATING_DML_OFFSET = 0x0  # PLACEHOLDER - Defensive Mid Left
    PLAYER_RATING_DMR_OFFSET = 0x0  # PLACEHOLDER - Defensive Mid Right
    PLAYER_RATING_AML_OFFSET = 0x0  # PLACEHOLDER - Attacking Mid Left
    PLAYER_RATING_AMC_OFFSET = 0x0  # PLACEHOLDER - Attacking Mid Center
    PLAYER_RATING_AMR_OFFSET = 0x0  # PLACEHOLDER - Attacking Mid Right
    PLAYER_RATING_ST_OFFSET = 0x0  # PLACEHOLDER - Striker

    # Current role/position (optional)
    PLAYER_CHOSEN_ROLE_OFFSET = 0x0  # PLACEHOLDER

    # Player object size (distance between consecutive players in array)
    PLAYER_OBJECT_SIZE = 0x0  # PLACEHOLDER - find by comparing adjacent players


# ============================================================================
# PLAYER DATA STRUCTURE
# ============================================================================

@dataclass
class PlayerData:
    """Represents a single player's data"""
    name: str = ""
    best_position: str = ""
    age: int = 0
    ca: int = 0  # Current Ability
    pa: int = 0  # Potential Ability
    rating_striker: float = 0.0
    rating_aml: float = 0.0
    rating_amc: float = 0.0
    rating_amr: float = 0.0
    rating_dml: float = 0.0
    rating_dmr: float = 0.0
    rating_dc: float = 0.0
    rating_drl: float = 0.0
    rating_gk: float = 0.0
    chosen_role: str = ""

    def to_csv_row(self) -> Dict[str, Any]:
        """Convert to CSV row format matching the expected schema"""
        return {
            'Name': self.name,
            'Best Position': self.best_position,
            'Age': self.age,
            'CA': self.ca,
            'PA': self.pa,
            'Striker': self.rating_striker,
            'AM(L)': self.rating_aml,
            'AM(C)': self.rating_amc,
            'AM(R)': self.rating_amr,
            'DM(L)': self.rating_dml,
            'DM(R)': self.rating_dmr,
            'D(C)': self.rating_dc,
            'D(R/L)': self.rating_drl,
            'GK': self.rating_gk,
            'Chosen Role': self.chosen_role
        }


# ============================================================================
# MEMORY READING UTILITIES
# ============================================================================

class FM26MemoryReader:
    """Handles all memory reading operations for FM26"""

    def __init__(self):
        self.pm: Optional[pymem.Pymem] = None
        self.game_module_base: int = 0

    def attach_to_process(self) -> bool:
        """
        Attach to the FM26 process

        Returns:
            bool: True if successful, False otherwise
        """
        try:
            logger.info(f"Attempting to attach to process: {MemoryConfig.PROCESS_NAME}")
            self.pm = pymem.Pymem(MemoryConfig.PROCESS_NAME)
            logger.info(f"Successfully attached to process (PID: {self.pm.process_id})")

            # Get base address of game module
            try:
                module = pymem.process.module_from_name(
                    self.pm.process_handle,
                    MemoryConfig.GAME_MODULE
                )
                self.game_module_base = module.lpBaseOfDll
                logger.info(f"Found {MemoryConfig.GAME_MODULE} at base address: 0x{self.game_module_base:X}")
            except Exception as e:
                logger.warning(f"Could not find {MemoryConfig.GAME_MODULE}: {e}")
                logger.info("Using main module base address instead")
                self.game_module_base = self.pm.process_base.lpBaseOfDll

            return True

        except pymem.exception.ProcessNotFound:
            logger.error(f"FM26 process not found. Make sure the game is running!")
            logger.error(f"Looking for: {MemoryConfig.PROCESS_NAME}")
            return False
        except Exception as e:
            logger.error(f"Error attaching to process: {e}")
            return False

    def read_pointer_chain(self, base_address: int, offsets: List[int]) -> int:
        """
        Follow a pointer chain to get final address

        Args:
            base_address: Starting address
            offsets: List of offsets to follow

        Returns:
            int: Final address after following all pointers
        """
        if not self.pm:
            raise RuntimeError("Not attached to process")

        address = base_address

        for i, offset in enumerate(offsets):
            try:
                # Read pointer at current address
                address = self.pm.read_longlong(address)
                # Add offset for next pointer
                if i < len(offsets) - 1:
                    address += offset
                else:
                    # Last offset - this is where our data is
                    address += offset

                logger.debug(f"Pointer chain step {i}: 0x{address:X}")

            except Exception as e:
                logger.error(f"Error reading pointer chain at step {i}: {e}")
                return 0

        return address

    def read_string(self, address: int, max_length: int = 100) -> str:
        """
        Read a null-terminated string from memory

        Args:
            address: Address to read from
            max_length: Maximum string length to read

        Returns:
            str: The string read from memory
        """
        if not self.pm or address == 0:
            return ""

        try:
            # Try to read as pointer first (common for strings)
            string_ptr = self.pm.read_longlong(address)
            if string_ptr != 0:
                address = string_ptr

            # Read bytes and decode
            bytes_data = self.pm.read_bytes(address, max_length)
            # Find null terminator
            null_index = bytes_data.find(b'\x00')
            if null_index != -1:
                bytes_data = bytes_data[:null_index]

            return bytes_data.decode('utf-8', errors='ignore')
        except Exception as e:
            logger.debug(f"Error reading string at 0x{address:X}: {e}")
            return ""

    def read_int(self, address: int) -> int:
        """Read a 4-byte integer"""
        if not self.pm or address == 0:
            return 0
        try:
            return self.pm.read_int(address)
        except Exception as e:
            logger.debug(f"Error reading int at 0x{address:X}: {e}")
            return 0

    def read_float(self, address: int) -> float:
        """Read a 4-byte float"""
        if not self.pm or address == 0:
            return 0.0
        try:
            return self.pm.read_float(address)
        except Exception as e:
            logger.debug(f"Error reading float at 0x{address:X}: {e}")
            return 0.0

    def read_player_data(self, player_base_address: int) -> PlayerData:
        """
        Read all data for a single player

        Args:
            player_base_address: Base address of player object

        Returns:
            PlayerData: Populated player data object
        """
        player = PlayerData()

        try:
            # Read player information
            player.name = self.read_string(
                player_base_address + MemoryConfig.PLAYER_NAME_OFFSET
            )
            player.age = self.read_int(
                player_base_address + MemoryConfig.PLAYER_AGE_OFFSET
            )
            player.ca = self.read_int(
                player_base_address + MemoryConfig.PLAYER_CA_OFFSET
            )
            player.pa = self.read_int(
                player_base_address + MemoryConfig.PLAYER_PA_OFFSET
            )
            player.best_position = self.read_string(
                player_base_address + MemoryConfig.PLAYER_BEST_POS_OFFSET
            )

            # Read position ratings (might be int or float - adjust as needed)
            player.rating_gk = self.read_float(
                player_base_address + MemoryConfig.PLAYER_RATING_GK_OFFSET
            )
            player.rating_dc = self.read_float(
                player_base_address + MemoryConfig.PLAYER_RATING_DC_OFFSET
            )
            player.rating_drl = self.read_float(
                player_base_address + MemoryConfig.PLAYER_RATING_DRL_OFFSET
            )
            player.rating_dml = self.read_float(
                player_base_address + MemoryConfig.PLAYER_RATING_DML_OFFSET
            )
            player.rating_dmr = self.read_float(
                player_base_address + MemoryConfig.PLAYER_RATING_DMR_OFFSET
            )
            player.rating_aml = self.read_float(
                player_base_address + MemoryConfig.PLAYER_RATING_AML_OFFSET
            )
            player.rating_amc = self.read_float(
                player_base_address + MemoryConfig.PLAYER_RATING_AMC_OFFSET
            )
            player.rating_amr = self.read_float(
                player_base_address + MemoryConfig.PLAYER_RATING_AMR_OFFSET
            )
            player.rating_striker = self.read_float(
                player_base_address + MemoryConfig.PLAYER_RATING_ST_OFFSET
            )

            # Read chosen role (optional)
            player.chosen_role = self.read_string(
                player_base_address + MemoryConfig.PLAYER_CHOSEN_ROLE_OFFSET
            )

            logger.debug(f"Read player: {player.name} (Age: {player.age}, CA: {player.ca})")

        except Exception as e:
            logger.error(f"Error reading player data at 0x{player_base_address:X}: {e}")

        return player

    def extract_all_players(self) -> List[PlayerData]:
        """
        Extract all players from the current squad

        Returns:
            List[PlayerData]: List of all players found
        """
        players = []

        try:
            # Get base address of squad data
            squad_base = self.game_module_base + MemoryConfig.SQUAD_BASE_OFFSET
            logger.info(f"Squad base address: 0x{squad_base:X}")

            # Follow pointer chain to player array
            player_array_address = self.read_pointer_chain(
                squad_base,
                MemoryConfig.PLAYER_ARRAY_OFFSETS
            )
            logger.info(f"Player array address: 0x{player_array_address:X}")

            # Get player count
            player_count_address = self.read_pointer_chain(
                squad_base,
                MemoryConfig.PLAYER_COUNT_OFFSETS
            )
            player_count = self.read_int(player_count_address)
            logger.info(f"Found {player_count} players")

            # Read each player
            for i in range(player_count):
                player_address = player_array_address + (i * MemoryConfig.PLAYER_OBJECT_SIZE)
                logger.info(f"Reading player {i+1}/{player_count}...")

                player_data = self.read_player_data(player_address)

                # Only add if we got valid data
                if player_data.name:
                    players.append(player_data)
                    logger.info(f"  ✓ {player_data.name}")
                else:
                    logger.warning(f"  ✗ Failed to read player at index {i}")

        except Exception as e:
            logger.error(f"Error extracting players: {e}")

        return players

    def close(self):
        """Close the process handle"""
        if self.pm:
            try:
                self.pm.close_process()
            except:
                pass


# ============================================================================
# CSV EXPORT
# ============================================================================

def export_to_csv(players: List[PlayerData], output_path: str = "players-extracted.csv"):
    """
    Export player data to CSV file

    Args:
        players: List of player data
        output_path: Path to output CSV file
    """
    if not players:
        logger.warning("No players to export!")
        return

    try:
        fieldnames = [
            'Name', 'Best Position', 'Age', 'CA', 'PA',
            'Striker', 'AM(L)', 'AM(C)', 'AM(R)',
            'DM(L)', 'DM(R)', 'D(C)', 'D(R/L)', 'GK',
            'Chosen Role'
        ]

        with open(output_path, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
            writer.writeheader()

            for player in players:
                writer.writerow(player.to_csv_row())

        logger.info(f"✓ Exported {len(players)} players to {output_path}")

    except Exception as e:
        logger.error(f"Error exporting to CSV: {e}")


# ============================================================================
# MAIN FUNCTION
# ============================================================================

def main():
    """Main entry point"""
    print("="*70)
    print("FM26 Player Data Extractor")
    print("="*70)
    print()

    # Check if configuration has been updated
    if MemoryConfig.SQUAD_BASE_OFFSET == 0x0:
        print("⚠️  WARNING: Memory configuration has not been set up!")
        print()
        print("You must first use Cheat Engine to find the memory addresses.")
        print("See: docs/cheat-engine-finding-addresses.md")
        print()
        response = input("Continue anyway? (y/n): ")
        if response.lower() != 'y':
            print("Exiting...")
            return

    # Create reader
    reader = FM26MemoryReader()

    try:
        # Attach to FM26
        print("\n1. Attaching to FM26 process...")
        if not reader.attach_to_process():
            print("✗ Failed to attach to FM26. Make sure the game is running!")
            return
        print("✓ Successfully attached to FM26")

        # Extract players
        print("\n2. Extracting player data from memory...")
        players = reader.extract_all_players()

        if not players:
            print("✗ No players found! Check your memory configuration.")
            return

        print(f"✓ Extracted {len(players)} players")

        # Export to CSV
        print("\n3. Exporting to CSV...")
        export_to_csv(players)
        print("✓ Export complete!")

        # Summary
        print("\n" + "="*70)
        print("EXTRACTION COMPLETE")
        print("="*70)
        print(f"Players extracted: {len(players)}")
        print(f"Output file: players-extracted.csv")
        print()
        print("You can now use this file with the lineup optimizer:")
        print("  python fm_team_selector_optimal.py players-extracted.csv")
        print("="*70)

    except KeyboardInterrupt:
        print("\n\nExtraction cancelled by user.")
    except Exception as e:
        logger.error(f"Unexpected error: {e}", exc_info=True)
    finally:
        reader.close()


if __name__ == "__main__":
    main()
