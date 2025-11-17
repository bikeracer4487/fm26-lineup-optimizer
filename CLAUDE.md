# CLAUDE.md - AI Assistant Guide for FM26 Lineup Optimizer

## Project Overview

This is a Football Manager 2026 lineup optimization tool that uses advanced algorithms to select the best Starting XI and rotation squads based on position-specific player ratings. The project was created for Brixham AFC save in FM2026.

**Primary Goal:** Automatically select optimal player lineups that maximize team ratings while respecting formation constraints and player availability.

**Key Algorithms:**
- Hungarian Algorithm (Munkres Assignment) for optimal player-position matching
- Greedy selection as a faster alternative
- Squad depth analysis for rotation planning

## Repository Structure

```
fm26-lineup-optimizer/
├── fm_team_selector_optimal.py    # RECOMMENDED: Optimal selector using Hungarian algorithm
├── fm_team_selector.py            # Basic greedy algorithm selector
├── fm_rotation_selector.py        # Dual squad selector (First XI + Rotation XI)
├── compare_selections.py          # Comparison tool for greedy vs optimal
├── requirements.txt               # Python dependencies
├── README.md                      # User-facing documentation
├── PROJECT_SUMMARY.md             # Project overview and features
├── QUICKSTART.md                  # Getting started guide
├── LICENSE.md                     # MIT License
└── .gitignore                     # Git ignore rules (excludes player data CSVs)
```

## Core Files and Components

### 1. fm_team_selector_optimal.py (PRIMARY IMPLEMENTATION)

**Class:** `OptimalTeamSelector`

**Algorithm:** Hungarian/Munkres assignment algorithm via `scipy.optimize.linear_sum_assignment`

**Key Methods:**
- `__init__(filepath)` - Loads player data from CSV/Excel, creates DM_avg column
- `select_optimal_xi(formation)` - Returns optimal XI using linear sum assignment
- `print_starting_xi()` - Displays formatted lineup with ratings and natural positions
- `export_to_csv()` - Exports selection to CSV with player metadata
- `suggest_substitutes(n_subs=7)` - Recommends bench players

**How It Works:**
1. Creates a cost matrix (players × positions) with negative ratings
2. Uses `linear_sum_assignment()` to find optimal assignment minimizing cost
3. Each player assigned to exactly one position, maximizing total team rating

**Location References:**
- Main selector logic: fm_team_selector_optimal.py:39-83
- Print formatting: fm_team_selector_optimal.py:85-137
- CSV export: fm_team_selector_optimal.py:139-170
- Substitute suggestions: fm_team_selector_optimal.py:172-198

### 2. fm_team_selector.py (GREEDY ALTERNATIVE)

**Class:** `TeamSelector`

**Algorithm:** Greedy selection (processes positions sequentially)

**Key Difference:**
- Processes positions in order, picking best available player for each
- Faster but may miss optimal global assignment
- Typically 1-3% lower average rating than optimal version

**Use Case:** Quick checks or when scipy not available

**Location References:**
- Greedy selection logic: fm_team_selector.py:38-70
- Main selection loop: fm_team_selector.py:72-97

### 3. fm_rotation_selector.py (DUAL SQUAD SELECTOR)

**Class:** `RotationSelector`

**Purpose:** Selects two complete XIs for rotation and squad depth

**Key Features:**
- Selects optimal First XI
- Selects optimal Rotation XI from remaining players
- Provides depth analysis by position
- Visualizes squad depth with percentage bars

**Special Methods:**
- `select_both_squads()` - Selects both teams sequentially
- `print_both_squads()` - Side-by-side display
- `compare_depth_by_position()` - Depth visualization with status indicators
- `suggest_additional_subs()` - Beyond the rotation squad

**Location References:**
- Dual selection: fm_rotation_selector.py:98-119
- Depth analysis: fm_rotation_selector.py:231-270

### 4. compare_selections.py (DIAGNOSTIC TOOL)

**Purpose:** Benchmarks greedy vs optimal approaches

**Output:**
- Shows both selections side-by-side
- Calculates improvement percentage
- Highlights player selection differences

**Use Case:** Testing and validation

## Data Format and Conventions

### Expected Input Columns

**Required columns in player spreadsheet:**
- `Name` - Player name (string)
- `Best Position` - Natural position (string)
- `Age` - Player age (numeric)
- `CA` - Current Ability (numeric)
- `PA` - Potential Ability (numeric)
- `Striker` - Striker rating (numeric)
- `AM(L)` - Attacking Mid Left rating (numeric)
- `AM(C)` - Attacking Mid Center rating (numeric)
- `AM(R)` - Attacking Mid Right rating (numeric)
- `DM(L)` - Defensive Mid Left rating (numeric)
- `DM(R)` - Defensive Mid Right rating (numeric)
- `D(C)` - Center Back rating (numeric)
- `D(R/L)` - Full Back rating (numeric)
- `GK` - Goalkeeper rating (numeric)

**Generated Columns:**
- `DM_avg` - Average of DM(L) and DM(R), created automatically

### Formation Specification

Formations are defined as lists of tuples: `(position_display_name, rating_column)`

**Default Formation (4-2-3-1):**
```python
formation = [
    ('GK', 'GK'),
    ('DL', 'D(R/L)'),
    ('DC1', 'D(C)'),
    ('DC2', 'D(C)'),
    ('DR', 'D(R/L)'),
    ('DM1', 'DM(L)'),      # or 'DM_avg'
    ('DM2', 'DM(R)'),      # or 'DM_avg'
    ('AML', 'AM(L)'),
    ('AMC', 'AM(C)'),
    ('AMR', 'AM(R)'),
    ('STC', 'Striker')
]
```

**Important:** Position display names are used for output formatting and must match the structure in `print_starting_xi()` methods.

## Code Patterns and Conventions

### 1. Class Structure Pattern

All selectors follow this pattern:
```python
class Selector:
    def __init__(self, filepath):
        # Load data
        # Type conversion for numeric columns
        # Create DM_avg column

    def select_*_xi(self, formation):
        # Selection logic
        # Returns dict: {position: (player, rating)}

    def print_*_xi(self):
        # Formatted terminal output

    def export_to_csv(self):
        # CSV export with metadata
```

### 2. Data Loading Convention

```python
# CSV vs Excel detection
if filepath.endswith('.csv'):
    self.df = pd.read_csv(filepath)
else:
    self.df = pd.read_excel(filepath)

# Always convert to numeric with error handling
for col in numeric_columns:
    if col in self.df.columns:
        self.df[col] = pd.to_numeric(self.df[col], errors='coerce')
```

**Why:** Handles both file types, ensures numeric operations work, NaN for invalid data

### 3. Output Formatting Convention

Terminal output follows this structure:
```
======================================================================
HEADER
======================================================================

Section Name:
  POS   : Player Name         [Natural Pos]  (Rating)

======================================================================
Average Team Rating: XX.XX
======================================================================
```

**Line width:** 70-120 characters depending on script
**Rating format:** One decimal place `(92.5)`
**Natural position:** Shown in brackets `[AM(C)]`

### 4. Cost Matrix Pattern (Optimal Selectors)

```python
# Initialize with very negative values (impossible assignments)
cost_matrix = np.full((n_players, n_positions), -999.0)

# Fill with negative ratings (minimization problem)
for i, player_idx in enumerate(self.df.index):
    for j, (pos_name, col_name) in enumerate(formation):
        rating = self.df.loc[player_idx, col_name]
        if pd.notna(rating):
            cost_matrix[i, j] = -rating  # NEGATIVE for minimization
```

**Critical:** Ratings must be negative because `linear_sum_assignment` minimizes cost

## Development Workflows

### Adding a New Formation

1. **Define the formation tuple list:**
   ```python
   formation = [
       ('GK', 'GK'),
       ('DC1', 'D(C)'),
       # ... add your positions
   ]
   ```

2. **Update the display dictionary** in `print_starting_xi()`:
   ```python
   formation_display = {
       'Your Section': ['POS1', 'POS2'],
       # ... group positions logically
   }
   ```

3. **Test with sample data** to ensure all positions are filled

### Adding a New Position Rating Column

1. **Update the numeric_columns list** in `__init__`:
   ```python
   numeric_columns = ['Striker', 'AM(L)', ..., 'YOUR_NEW_COLUMN']
   ```

2. **Add to the formation definition** where needed

3. **Update documentation** in README.md

### Modifying Selection Criteria

**For age-based selection:**
```python
# Add weight before creating cost matrix
weighted_ratings = ratings + (30 - age) * age_weight_factor
```

**For fitness filtering:**
```python
# Filter DataFrame before selection
available_df = self.df[self.df['Fitness'] >= 90].copy()
```

**Location to modify:** Before the cost matrix creation in optimal selectors, or in `get_best_player()` for greedy

### Adding New Export Formats

In `export_to_csv()` or similar methods:
```python
# Excel
xi_df.to_excel('starting_xi.xlsx', index=False)

# JSON
xi_df.to_json('starting_xi.json', orient='records')

# HTML
xi_df.to_html('starting_xi.html', index=False)
```

## Common Tasks for AI Assistants

### Task: Fix bugs in player selection

1. **Check the cost matrix** - Are ratings negative? Are NaN values handled?
2. **Verify formation definition** - Do position names match display logic?
3. **Test with minimal data** - Create a 12-player CSV with known values
4. **Compare greedy vs optimal** - Use compare_selections.py to validate

### Task: Improve performance

1. **Profile the code** - Selection is already O(n³) which is acceptable
2. **Check DataFrame operations** - Avoid repeated df lookups
3. **Cache natural positions** - If used multiple times in output

**Current bottleneck:** Reading files is slower than selection algorithm

### Task: Add new features

**Always consider:**
- Does it fit the class structure pattern?
- Should it be in optimal, greedy, or both?
- Does it need new columns in the input data?
- How does it affect the cost matrix?
- Does the output formatting need updates?

### Task: Debug incorrect selections

**Common issues:**
1. **Wrong players selected** - Check if position column names match
2. **NaN ratings** - Verify numeric conversion in `__init__`
3. **Duplicate players** - Ensure assignment algorithm isn't reusing players
4. **Suboptimal results** - Make sure using optimal selector, not greedy

**Debugging locations:**
- Cost matrix creation: fm_team_selector_optimal.py:54-67
- Assignment logic: fm_team_selector_optimal.py:69-82
- Greedy selection: fm_team_selector.py:66-70

### Task: Modify output format

**Output locations:**
- Terminal output: `print_starting_xi()` and `print_both_squads()` methods
- CSV structure: `export_to_csv()` methods
- Formation display: `formation_display` dictionaries

**Formatting guidelines:**
- Keep output compact (terminal friendly)
- Show ratings to 1 decimal place
- Include natural positions for context
- Use dividers (=, -) for readability

## Testing Considerations

### Manual Testing

**Test cases to validate:**
1. **Empty dataset** - Should handle gracefully
2. **Missing columns** - Should raise clear errors
3. **All NaN ratings for a position** - Should report "NO PLAYER FOUND"
4. **11 players exactly** - Should select all 11
5. **Players with identical ratings** - Should pick any valid assignment
6. **Very large dataset (100+ players)** - Should complete in < 5 seconds

### Validation Tests

**Compare outputs:**
```bash
python compare_selections.py players.csv
```
Expected: Optimal rating >= Greedy rating (always)

**Check formation totals:**
- Count positions in formation list = 11
- Count selected players = 11
- No duplicate players in selection

### Edge Cases

1. **DM(L) and DM(R) both NaN** - DM_avg will be NaN, position unfilled
2. **Player excels at multiple positions** - Optimal should assign to best value position
3. **Only 10 players available** - One position will show "NO PLAYER FOUND"
4. **Excel vs CSV formats** - Both should produce identical results

## Important Gotchas

### 1. Column Name Case Sensitivity

Column names are **case-sensitive**: `AM(L)` ≠ `am(l)` ≠ `AM(l)`

**Always use exact column names** as defined in the formation tuple.

### 2. Index Handling in Cost Matrix

The optimal selector uses both DataFrame index and integer positions:
```python
# DON'T: Assume df.index == range(len(df))
rating = self.df.loc[df.index[i], col_name]

# DO: Reset index if needed or use iloc
available_df = available_df.reset_index(drop=True)
```

**Location:** fm_team_selector_optimal.py:62-67 and fm_rotation_selector.py:75-80

### 3. Negative Ratings in Cost Matrix

Hungarian algorithm minimizes cost, so ratings must be **negative**:
```python
cost_matrix[i, j] = -rating  # Negative!
```

**Never** use positive ratings or the algorithm will minimize team rating instead of maximizing.

### 4. DM_avg Creation

If `DM(L)` or `DM(R)` is missing, DM_avg will be NaN for that player:
```python
self.df['DM_avg'] = (self.df['DM(L)'] + self.df['DM(R)']) / 2
```

**Solution:** Check both columns exist before averaging, or handle NaN in selection.

### 5. File Path Handling

Scripts accept file paths as command-line arguments:
```bash
python fm_team_selector_optimal.py players.csv  # Relative path
python fm_team_selector_optimal.py /full/path/to/players.csv  # Absolute
```

**Default:** Falls back to 'players.csv' or 'players.xlsx' if no argument provided.

### 6. Output File Overwriting

All scripts overwrite output files without warning:
- `starting_xi.csv`
- `first_xi.csv`
- `rotation_xi.csv`

**No backup** is created. User data should be version controlled or backed up.

## Dependencies and Environment

### Required Python Packages

```
pandas>=1.3.0    # Data manipulation
numpy>=1.20.0    # Numerical operations
scipy>=1.7.0     # Hungarian algorithm (linear_sum_assignment)
openpyxl>=3.0.0  # Excel file support
```

**Install:** `pip install -r requirements.txt`

### Python Version

**Minimum:** Python 3.6+ (for f-strings and type hints)
**Recommended:** Python 3.8+

### No External Configuration

- No config files
- No environment variables
- No database connections
- All configuration via code modification

## Git Workflow

### Branches

- Main development branch: `claude/claude-md-mi2ie0ml8nj6n647-01MfTSDFSa5EJR5DwFcbtzt4`
- All commits and pushes should go to this branch

### Ignored Files

Per .gitignore:
- `players.csv` - User's personal player data
- `starting_xi.csv`, `first_xi.csv`, `rotation_xi.csv` - Generated output files
- Standard Python ignores: `__pycache__/`, `*.pyc`, etc.

### Commit Guidelines

When committing changes:
1. Use descriptive commit messages explaining "why" not just "what"
2. Group related changes together
3. Test with sample data before committing
4. Update README.md if user-facing behavior changes

## Performance Characteristics

### Algorithm Complexity

**Hungarian Algorithm (Optimal):**
- Time: O(n³) where n = number of positions (11)
- Space: O(n²) for cost matrix
- Runtime: < 1 second for typical datasets (< 100 players)

**Greedy Algorithm:**
- Time: O(n × m log m) where n = positions, m = players
- Space: O(m)
- Runtime: < 0.1 seconds

### Scalability

**Current scale:** 35-100 players typical
**Tested up to:** Not specified in code, but O(n³) handles 1000+ players fine
**Bottleneck:** File I/O (reading CSV/Excel) > Selection algorithm

## Future Enhancement Ideas

From PROJECT_SUMMARY.md, potential areas for expansion:

1. **Player development** - Factor in age and PA for long-term planning
2. **Fitness/condition** - Weight by current fitness for match-day selection
3. **Morale** - Include player morale in ratings
4. **Multiple tactics** - Support A-team vs B-team for different competitions
5. **Budget optimization** - Factor in wages/value
6. **Opposition analysis** - Adjust selection based on opponent
7. **Automated testing** - Unit tests for selection logic
8. **GUI interface** - Web or desktop interface for non-technical users

## When to Use Each Script

### Use `fm_team_selector_optimal.py` when:
- Selecting your actual match-day Starting XI
- Need the mathematically best lineup
- Have scipy installed
- Performance difference (< 1s) is acceptable

### Use `fm_team_selector.py` when:
- Quick testing or prototyping
- scipy not available
- Implementing new features (simpler codebase)

### Use `fm_rotation_selector.py` when:
- Planning squad rotation for fixture congestion
- Analyzing squad depth
- Preparing for multiple competitions
- Need to see quality drop-off between first and second choice

### Use `compare_selections.py` when:
- Validating algorithm improvements
- Demonstrating value of optimal approach
- Debugging selection issues
- Benchmarking performance

## Quick Reference: Key Code Locations

| Task | File | Line Range |
|------|------|------------|
| Optimal selection algorithm | fm_team_selector_optimal.py | 39-83 |
| Cost matrix creation | fm_team_selector_optimal.py | 54-67 |
| Greedy selection logic | fm_team_selector.py | 38-70 |
| Formation display structure | fm_team_selector_optimal.py | 98-104 |
| CSV export logic | fm_team_selector_optimal.py | 139-170 |
| Substitute suggestions | fm_team_selector_optimal.py | 172-198 |
| Rotation dual selection | fm_rotation_selector.py | 98-119 |
| Depth analysis visualization | fm_rotation_selector.py | 231-270 |
| Side-by-side squad display | fm_rotation_selector.py | 121-187 |
| Default formation | All main() functions | Search for `formation = [` |

## Support and Resources

**Documentation:**
- README.md - User guide and customization examples
- PROJECT_SUMMARY.md - Feature overview and performance comparison
- QUICKSTART.md - Step-by-step getting started guide

**License:** MIT License (see LICENSE.md)
- Free to use, modify, and distribute
- No warranty provided

**Author:** Doug Mason (2025)

---

## Summary for AI Assistants

When working on this codebase:

1. **Prefer the optimal selector** - It's the primary implementation
2. **Respect the class structure pattern** - All selectors follow it
3. **Test with both greedy and optimal** - Use compare_selections.py
4. **Remember negative ratings** - Cost matrices need negative values
5. **Handle NaN gracefully** - Player data may have missing ratings
6. **Update all display logic** - When changing formations or output
7. **Document user-facing changes** - Update README.md
8. **Keep terminal output compact** - Users run this from CLI
9. **Don't commit player data** - It's in .gitignore for privacy
10. **Follow git workflow** - Commit to the correct branch

This is a well-structured, focused project. The core algorithms are sound (Hungarian algorithm is mathematically optimal). Most enhancements should be additive features rather than changes to core selection logic.
