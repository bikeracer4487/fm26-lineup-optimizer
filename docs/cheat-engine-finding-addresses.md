# Finding FM26 Memory Addresses with Cheat Engine

This guide walks you through using Cheat Engine to find the memory addresses needed for the `fm26_player_extractor.py` script.

## Prerequisites

- Cheat Engine 7.5 or later installed
- Football Manager 2026 running with a save game loaded
- A squad/team view open in FM26 (so you can see player data)
- Basic understanding of hexadecimal numbers
- Patience - this process can take 1-3 hours for first-time users

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [Finding Simple Values (Player Age)](#finding-simple-values-player-age)
3. [Finding Pointer Chains](#finding-pointer-chains)
4. [Finding Player Array Structure](#finding-player-array-structure)
5. [Finding Player Object Offsets](#finding-player-object-offsets)
6. [Finding Position Ratings](#finding-position-ratings)
7. [Documenting Your Findings](#documenting-your-findings)
8. [Troubleshooting](#troubleshooting)

---

## Initial Setup

### 1. Launch Cheat Engine and Attach to FM26

1. Start Football Manager 2026
2. Load your save game
3. Navigate to your squad view (where you can see all your players)
4. Launch Cheat Engine
5. Click the computer icon (top left) to select a process
6. Find "fm.exe" in the process list and select it
7. Click "Open"

You should now see the FM26 process attached in Cheat Engine.

### 2. Understanding the Interface

Key elements:
- **Value**: The number you're searching for
- **Scan Type**: How to search (Exact Value, Unknown Initial Value, etc.)
- **Value Type**: Data type (4 Bytes, Float, String, etc.)
- **Address List**: Found addresses appear here (bottom panel)
- **Memory Viewer**: Right-click an address and select "Browse this memory region"

---

## Finding Simple Values (Player Age)

Start with something easy to verify your setup works.

### Step 1: Find a Player's Age

1. In FM26, select a player and note their age (e.g., 22)
2. In Cheat Engine:
   - Set **Value Type** to "4 Bytes" (ages are typically stored as integers)
   - Set **Scan Type** to "Exact Value"
   - Enter the age (22) in the **Value** field
   - Click **First Scan**

3. You'll see thousands of results in the left panel

### Step 2: Filter Results

1. In FM26, select a different player with a different age (e.g., 28)
2. In Cheat Engine:
   - Enter the new age (28) in the **Value** field
   - Click **Next Scan**

3. Repeat this process with 3-5 different players until you have fewer than 100 results

### Step 3: Identify the Correct Address

1. Select a specific player in FM26 (e.g., age 25)
2. In Cheat Engine, look through your remaining addresses
3. Double-click addresses to add them to the address list (bottom panel)
4. In the address list, try changing the value:
   - Double-click the "Value" column
   - Change it to a different number
   - If the player's age in FM26 changes, you found it!

**Record this address** - we'll use it to find the player structure.

### Important Note

The direct address (e.g., `0x12345678`) will change every time you restart FM26. That's why we need **pointer chains**.

---

## Finding Pointer Chains

Pointer chains provide stable access to data across game restarts.

### Step 1: Prepare for Pointer Scan

1. Make sure you have a valid player age address in your address list
2. **Save your game** in FM26 (we'll need to reload it)
3. In Cheat Engine, right-click the address and select "Pointer scan for this address"

### Step 2: Configure Pointer Scanner

A dialog will appear with options:

- **Max level**: Set to 5 (how many pointers deep to search)
- **Max offset**: Set to 2048 (maximum offset value)
- **Leave other options at default**
- Click OK

This will create a `.scandata` file. Save it somewhere you'll remember.

**Warning**: This scan can take 5-30 minutes and generate a large file (hundreds of MB).

### Step 3: Restart and Rescan

1. Once the scan completes, **close and restart FM26**
2. Load the same save game
3. Find the player age address again using the same method as before
   - It will be at a **different address** this time
4. In Cheat Engine, click "Pointer scanner" → "Rescan memory"
5. Enter the new address of the player's age
6. Click OK

### Step 4: Identify Stable Pointers

After rescanning, you should have far fewer results - ideally under 100.

Look for pointer chains with these characteristics:
- Start with a module name (like `game_plugin.dll+OFFSET`)
- Have offsets that are round numbers (0x10, 0x20, 0x100, etc.)
- Shorter chains are better (3-4 levels vs 7 levels)

**Example good pointer chain**:
```
game_plugin.dll+01A2B340
  → +0x18
  → +0xC0
  → +0x28
```

**Add these to your address list** and test them by:
1. Restarting FM26 again
2. Loading the save
3. Checking if the pointer still points to the correct value

**Record your working pointer chain** - this is what you'll put in the script configuration.

---

## Finding Player Array Structure

Now we need to find where the game stores the array/list of all players.

### Step 1: Find Multiple Player Ages

1. Use the same process as before to find ages for 3-4 consecutive players in your squad list
2. Add all these addresses to your address list
3. Note their addresses (e.g., `0x12345678`, `0x123456F8`, `0x12345778`)

### Step 2: Calculate Player Object Size

Look at the difference between consecutive player addresses:

```
Player 1: 0x12345678
Player 2: 0x123456F8
Difference: 0x80 (128 bytes)

Player 2: 0x123456F8
Player 3: 0x12345778
Difference: 0x80 (128 bytes)
```

If the differences are consistent, that's your **PLAYER_OBJECT_SIZE**.

**Record this value** - you'll need it in the script.

### Step 3: Find the Array Base

1. Take the address of the first player in your squad
2. Right-click → "Find out what accesses this address"
3. Click Yes to attach debugger
4. In FM26, scroll through your squad or select different players
5. Watch the debugger window - you should see instructions accessing the address

Look for patterns like:
```
mov eax, [rdi+10]     ; Reading from array
mov [rbx+rax*8], rcx  ; Writing to array
```

The register (`rdi`, `rbx`, etc.) often points to the array base.

### Step 4: Trace Back to Static Address

1. Note the register that seems to hold the array base (e.g., `rdi`)
2. In the debugger, click "Find out what writes to this address"
3. Keep tracing backward until you find a static address (module + offset)

This process is advanced - you may need to use the pointer scanner on the array base address instead.

---

## Finding Player Object Offsets

Now we need to find where each piece of data is stored within a player object.

### General Strategy

For each piece of data (name, CA, PA, ratings), follow this process:

1. **Search for the value** in Cheat Engine
2. **Filter results** by changing values
3. **Calculate the offset** from the player object base

### Example: Finding Current Ability (CA)

1. In FM26, select a player and note their CA (e.g., 145)
2. Search for this value:
   - Value Type: "4 Bytes" (CA is usually an integer)
   - Scan Type: "Exact Value"
   - Value: 145
   - Click "First Scan"

3. Select different players and use "Next Scan" with their CA values
4. Once you have a few results, find the one that changes correctly
5. Note the address (e.g., `0x123456C8`)

6. Calculate offset from player base:
   ```
   Player base: 0x12345678
   CA address:  0x123456C8
   Offset:      0x50 (80 bytes)
   ```

**Record: `PLAYER_CA_OFFSET = 0x50`**

### Finding Strings (Name, Position)

Strings are trickier because they're often stored as pointers.

1. Search for the player's name:
   - Value Type: "String"
   - Scan Type: "Exact Value"
   - Value: Player's name (e.g., "John Smith")
   - Click "First Scan"

2. You might find the string directly, or you might find a pointer to it

3. Right-click the address → "Pointer scan for this address"

4. Find a stable pointer chain, then calculate its offset from the player base

### Finding Position Ratings

Position ratings (1-20 scale) can be stored as:
- **Integers** (4 bytes): values 1-20
- **Floats** (4 bytes): values 1.0-20.0
- **Scaled integers**: values 10-200 (multiply by 10)

Try searching as **Float** first:

1. In FM26, look at a player's position rating (e.g., Striker: 15)
2. Search as "Float" with value "15.0"
3. Filter by checking other players
4. Find the address and calculate offset

If that doesn't work, try as "4 Bytes" integer with value 15, or 150.

**Repeat for all position ratings**:
- GK, D(C), D(R/L), DM(L), DM(R), AM(L), AM(C), AM(R), Striker

---

## Finding Advanced Structures

### Finding Player Count

The game likely stores how many players are in the squad. This is usually:
- A 4-byte integer
- Near the player array base
- Changes when you add/remove players (transfers)

Try:
1. Count your squad players (e.g., 28)
2. Search for "4 Bytes" value "28"
3. Filter results
4. Find the address that represents your squad size

### Finding Squad/Team Base

The squad base is the top-level structure that contains:
- Pointer to player array
- Player count
- Team information

This requires advanced reverse engineering:
1. Use the pointer scanner on your player array address
2. Look for pointers that start from `game_plugin.dll+OFFSET`
3. The earliest pointer in the chain is often the squad base

---

## Documenting Your Findings

As you find each value, update the `MemoryConfig` class in `fm26_player_extractor.py`:

```python
class MemoryConfig:
    # Example - replace with your actual values

    SQUAD_BASE_OFFSET = 0x01A2B340  # Found via pointer scan

    PLAYER_ARRAY_OFFSETS = [
        0x18,   # First pointer dereference
        0xC0,   # Second pointer dereference
        0x28,   # Third pointer dereference
    ]

    PLAYER_COUNT_OFFSETS = [
        0x18,
        0xC0,
        0x30,   # Just after player array usually
    ]

    PLAYER_NAME_OFFSET = 0x10
    PLAYER_AGE_OFFSET = 0x28
    PLAYER_CA_OFFSET = 0x50
    PLAYER_PA_OFFSET = 0x54
    PLAYER_BEST_POS_OFFSET = 0x60

    PLAYER_RATING_GK_OFFSET = 0x100
    PLAYER_RATING_DC_OFFSET = 0x104
    # ... etc

    PLAYER_OBJECT_SIZE = 0x80  # 128 bytes between players
```

### Create a Cheat Table

Save your findings in a Cheat Engine table file (.CT):

1. In Cheat Engine, click File → Save
2. Save as "fm26_player_data.CT"
3. Add comments to each address explaining what it is

This lets you quickly verify your findings after game updates.

---

## Testing Your Configuration

### Step 1: Quick Test

1. Update one or two offsets in the script
2. Run the script: `python fm26_player_extractor.py`
3. Check the log file: `fm26_extractor.log`
4. Look for errors or successful reads

### Step 2: Incremental Updates

Don't try to find everything at once:

1. **Week 1**: Find player age and name offsets
2. **Week 2**: Find CA, PA, and position
3. **Week 3**: Find all position ratings
4. **Week 4**: Find squad array and player count

Test after each addition.

### Step 3: Validation

Once you think you have everything:

1. Run the extractor
2. Check the output CSV
3. Compare with FM26 in-game data
4. Verify names, ages, and ratings match

---

## Troubleshooting

### Problem: "Process not found"

- Make sure FM26 is running
- Check the process name is exactly "fm.exe"
- Try running Cheat Engine as Administrator

### Problem: "Too many search results"

- Use more filter scans with different values
- Try searching for unique values (uncommon ages like 37)
- Use "Changed value" or "Unchanged value" scan types

### Problem: "Pointer chain breaks after restart"

- Try a deeper pointer scan (max level 6-7)
- Increase max offset to 4096
- Look for patterns in the offsets (often multiples of 0x10)

### Problem: "Can't find position ratings"

- Ratings might be stored differently (int vs float)
- Try searching for scaled values (15 → 150)
- Some ratings might be calculated on-the-fly, not stored

### Problem: "Script finds 0 players"

- Check `PLAYER_OBJECT_SIZE` is correct
- Verify `PLAYER_ARRAY_OFFSETS` point to the right place
- Make sure you're reading the count correctly

---

## Advanced Tips

### Use Hardware Breakpoints

Instead of "Find what accesses this address", try:
1. Right-click address → "Browse this memory region"
2. In Memory Viewer: Tools → "Find out what accesses this address"
3. Check "Break and trace instructions"

This gives more detailed information about how the game accesses memory.

### Analyze with Debugger

The Memory Viewer has a built-in disassembler:
1. Browse to a player object address
2. Look at the surrounding code
3. Identify patterns in how the game reads data
4. Find vtables (often at offset 0x00 of objects)

### Use ReClass.NET

For visualizing structures:
1. Export addresses from Cheat Engine
2. Open in ReClass.NET
3. Build visual representation of the Player class
4. Export as C++ header for reference

### Study Similar Games

FM19-FM25 structures are "nearly identical" according to community developers:
- Search for "fm19RTE GitHub" for example pointer chains
- Look at FMRTE forum discussions
- Check FearlessCheat Engine forums for FM26 tables

---

## Community Resources

- **SortItOutSI Forums**: C# and Unity Development section
  - Memory scanning discussions
  - Decompiling with IL2CppDumper

- **FearlessCheat Engine**: FM26 request threads
  - User-created cheat tables
  - Memory structure discussions

- **GitHub**: Search "fm26" or "football manager" for:
  - fm19RTE (example C++ implementation)
  - FMMLoader-26 (modding tools)
  - NameFixFM26 (community mods)

---

## Legal and Ethical Notes

- This is for **educational and personal use only**
- May violate FM26's EULA - use at your own risk
- **Single-player only** - never use for online/multiplayer
- No distribution of game code or assets
- Be prepared to stop if Sports Interactive objects

---

## Next Steps

Once you've found and configured all the memory addresses:

1. Update `fm26_player_extractor.py` with your values
2. Run the script: `python fm26_player_extractor.py`
3. Verify the output in `players-extracted.csv`
4. Use with the lineup optimizer: `python fm_team_selector_optimal.py players-extracted.csv`

Good luck! This is a challenging but rewarding process. Don't get discouraged if it takes time - even experienced reverse engineers spend hours on this.

---

## Quick Reference Checklist

- [ ] Cheat Engine installed and working
- [ ] FM26 running with save loaded
- [ ] Found player age address
- [ ] Created pointer scan for age
- [ ] Rescanned after restart - found stable pointers
- [ ] Found player object size (distance between players)
- [ ] Found player name offset
- [ ] Found CA offset
- [ ] Found PA offset
- [ ] Found best position offset
- [ ] Found GK rating offset
- [ ] Found D(C) rating offset
- [ ] Found D(R/L) rating offset
- [ ] Found DM(L) rating offset
- [ ] Found DM(R) rating offset
- [ ] Found AM(L) rating offset
- [ ] Found AM(C) rating offset
- [ ] Found AM(R) rating offset
- [ ] Found Striker rating offset
- [ ] Found player array base pointer chain
- [ ] Found player count pointer chain
- [ ] Updated fm26_player_extractor.py configuration
- [ ] Tested script with logging enabled
- [ ] Verified output CSV matches in-game data
- [ ] Saved Cheat Engine table (.CT file) for future reference

Print this checklist and check items off as you complete them!
