# CLAUDE.md - AI Assistant Guide for FM26 Lineup Optimizer

## Primary Interaction Method

**IMPORTANT: The UI application is the primary way to interact with this tool.**

The Electron/React UI app (`ui/` directory) provides:
- Visual fixture management and match planning
- Automatic lineup generation for upcoming matches (limited to next 5 for performance)
- Manual player overrides with visual indicators
- Lineup confirmation/locking to preserve selections
- Historical lineup tracking for rotation penalties
- Training recommendations and rest/rotation advice

CLI scripts (`fm_*.py`) are available for advanced users, automation, or when the UI is not suitable.

**Note:** The `player_match_tracking.json` file is NOT used by the UI. The UI tracks consecutive matches per-simulation and stores confirmed lineups separately in `ui/data/confirmed_lineups.json`.

## Project Overview

This is a Football Manager 2026 lineup optimization tool that uses advanced algorithms to select the best Starting XI and rotation squads based on position-specific player ratings. The project was created for Brixham AFC save in FM2026.

**Primary Goal:** Automatically select optimal player lineups that maximize team ratings while respecting formation constraints and player availability.

**Key Algorithms:**
- Hungarian Algorithm (Munkres Assignment) for optimal player-position matching
- Greedy selection as a faster alternative
- Squad depth analysis for rotation planning
- **Receding Horizon Control (RHC)** with Shadow Pricing for 5-match optimization

## Operational Research Framework

The project implements an advanced OR framework based on comprehensive research documented in `docs/new-research/` (Steps 1-12). The research supersedes earlier FM26 #1-4 documents.

**Research Reference**: See `docs/new-research/00-PROGRESS-TRACKER.md` for the complete 12-step research program and `docs/new-research/12-IMPLEMENTATION-PLAN.md` for consolidated specifications.

### Global Selection Score (GSS) - Step 2 Research

Player utility is calculated using a multiplicative model:

```
GSS = BPS × Φ(C) × Ψ(S) × Θ(F) × Ω(J)
```

Where:
- **BPS**: Base Player Score (position-specific rating)
- **Φ(C)**: Condition Multiplier - steep sigmoid
- **Ψ(S)**: Sharpness Multiplier - bounded sigmoid
- **Θ(F)**: Familiarity Multiplier - LINEAR (not sigmoid!)
- **Ω(J)**: Jadedness Multiplier - step function

### Condition Multiplier Φ(C) - Step 2

**Formula**: `Φ(c) = 1 / (1 + e^{-k(c - c₀)})`

| Parameter | Value | Description |
|-----------|-------|-------------|
| k         | 25    | Steep sigmoid slope |
| c₀        | 0.88  | Threshold (88% = FM26 "Match Fit") |

**Critical Rule - 91% Floor**: Never start a player below 91% condition.

### Sharpness Multiplier Ψ(S) - Step 2

**Formula**: `Ψ(s) = 1.02 / (1 + e^{-k(s - s₀)}) - 0.02`

| Parameter | Value | Description |
|-----------|-------|-------------|
| k         | 15    | Moderate sigmoid slope |
| s₀        | 0.75  | Threshold (75% = effectiveness cliff) |

**Seven-Day Cliff**: Sharpness decays 5-8%/day after 7 days without match play.

### Familiarity Multiplier Θ(F) - Step 2

**Formula**: `Θ(f) = 0.7 + 0.3f` (LINEAR, not sigmoid!)

| Familiarity | Multiplier |
|-------------|------------|
| 0% (Awkward) | 0.70 |
| 50% (Competent) | 0.85 |
| 100% (Natural) | 1.00 |

### Jadedness Multiplier Ω(J) - Step 2/6

**Formula**: Step function with discrete states (0-1000 scale)

| State | J Range | Ω Multiplier | Action |
|-------|---------|--------------|--------|
| Fresh | 0-200 | 1.00 | Peak performance |
| Fit | 201-400 | 0.90 | Monitor |
| Tired | 401-700 | 0.70 | Rotate/Rest |
| Jaded | 701+ | 0.40 | HOLIDAY REQUIRED |

**Holiday Protocol**: Only "Holiday" clears jadedness (50 pts/day vs 5 pts/day for Rest).

### Shadow Pricing - Step 5 Research

**Shadow Cost Formula**:
```
λ_{p,t} = S_p^{VORP} × Σ_{k=t+1}^{T} (γ^{k-t} × I_k × max(0, ΔGSS_{p,k}))
```

Where ΔGSS = GSS(rest trajectory) - GSS(play trajectory)

**Parameters**:
| Parameter | Symbol | Default | Range |
|-----------|--------|---------|-------|
| Discount Factor | γ | 0.85 | 0.70-0.95 |
| Shadow Weight | λ_shadow | 1.0 | 0.0-2.0 |
| Scarcity Scaling | λ_V | 2.0 | 1.0-3.0 |

**VORP Scarcity Index**:
```
α_scarcity = 1 + λ_V × min(0.5, (GSS_star - GSS_backup) / GSS_star)
```
Gap% > 10% means player is "Key" and gets shadow protection.

### Importance Weights - Step 5/9 Research

| Scenario | Weight | Shadow Behavior |
|----------|--------|-----------------|
| Cup Final | 10.0 | Massive shadow zones |
| Continental KO | 5.0 | Strong preservation |
| Title Rival | 3.0 | Significant shadow cost |
| League (Standard) | 1.5 | Balanced rotation |
| Cup (Early) | 0.8 | High shadow for starters |
| Dead Rubber | 0.1 | Shadow blocks tired starters |

### Training Intensity Setting

A new Training Intensity setting (Low/Medium/High) in the Tactics tab adjusts recovery rate projections:
- **Low**: +20% recovery rate (light training)
- **Medium**: Standard recovery
- **High**: -20% recovery rate (double intensity training)

### State Propagation - Step 3 Research

Player state evolves according to calibrated equations from Step 3 research.

#### Positional Drag Coefficients (R_pos)

The key finding from Step 3: position determines condition drain rate.

| Position | R_pos | Rotation Need |
|----------|-------|---------------|
| GK | 0.20 | Almost none |
| CB/DC | 0.95 | Can play consecutive |
| DM | 1.15 | Moderate |
| CM/MC | 1.45 | High - rotate |
| AMC/AM | 1.35 | High |
| Winger (AML/AMR) | 1.40 | High |
| **FB/WB** | **1.65** | **100% rotation required** |
| ST/STC | 1.40 | High |

**Critical Finding**: Fullbacks/Wingbacks have the highest drain (1.65) and require 100% rotation.

#### Condition Propagation
```
C_{k+1} = C_k + (10000 - C_k) × β × (Natural_Fitness)^γ × (1 - J_penalty)
```
- Natural Fitness has increasing returns (γ > 1)
- Jadedness throttles recovery

#### 270-Minute Rule (Step 3 Refined)
- Window: **14 days** (not 10)
- Threshold: 270 minutes
- Penalty: **2.5x** jadedness accumulation when exceeded

#### Sharpness Seven-Day Cliff
| Days Without Match | Decay Rate |
|--------------------|------------|
| 0-3 days | ~0%/day |
| 4-6 days | ~1.5%/day |
| 7+ days | **5-8%/day** (cliff) |

**Operational Rule**: "Stamina wins the match, Natural Fitness wins the season"

### Polyvalent Stability Mechanisms (FM26 #2 Spec)

Prevents oscillating position assignments for versatile players using two mechanisms:

#### 1. Assignment Inertia Penalty
```
Stability_cost(player, slot) =
  - inertia_weight × continuity_bonus    (if same position as previous)
  + inertia_weight × base_switch_cost    (if different position)
```

**Default Parameters:**
- `inertia_weight`: 0.5 (configurable via Stability slider, 0-1)
- `continuity_bonus`: 0.05 (5% bonus for staying)
- `base_switch_cost`: 0.15 (15% penalty for switching)

#### 2. Soft-Lock Anchoring
After 3+ consecutive matches in the same position, a player becomes "anchored" with elevated switching costs:
```
Anchor_cost = anchor_multiplier × base_switch_cost
```

**Default Parameters:**
- `anchor_threshold`: 3 consecutive matches
- `anchor_multiplier`: 2.0 (doubles switching penalty)

### Stability Slider (New UI Feature)

A Stability slider in the Tactics tab controls `inertia_weight`:
- **0.0**: Pure optimization (no stability preference)
- **0.5**: Balanced (default - moderate stability)
- **1.0**: Maximum stability (strongly prefers consistent assignments)

### Core Files (OR Framework)

| File | Purpose | Research Source |
|------|---------|-----------------|
| `scoring_parameters.py` | All parameter values (GSS, jadedness, R_pos, etc.) | Steps 2, 3, 5, 6, 11 |
| `ui/api/scoring_model.py` | GSS multipliers (condition, sharpness, familiarity, jadedness) | Step 2 |
| `ui/api/state_simulation.py` | R_pos coefficients, state propagation, 270-min rule | Step 3 |
| `ui/api/shadow_pricing.py` | VORP scarcity index, shadow cost calculation | Step 5 |
| `ui/api/api_rest_advisor.py` | Jadedness thresholds, Holiday Protocol, archetypes | Step 6 |
| `ui/api/api_training_advisor.py` | GSI formula, age plasticity, difficulty classes | Step 7 |
| `ui/api/api_player_removal.py` | Contribution score, aging curves, wage structure | Step 8 |
| `ui/api/match_importance.py` | AMICS system, FIS formula, importance modifiers | Step 9 |
| `tests/test_validation_scenarios.py` | 21 validation protocols, integration tests | Step 10 |
| `tests/calibration_harness.py` | Sobol GSA, BOHB optimization, stress tests | Step 11 |

### Research Documentation

| File | Purpose |
|------|---------|
| `docs/new-research/00-PROGRESS-TRACKER.md` | Research program status (12/12 complete) |
| `docs/new-research/12-IMPLEMENTATION-PLAN.md` | Consolidated specifications, PR strategy |
| `docs/new-research/01-11-RESULTS-*.md` | Individual step research findings |

## Repository Structure

```
fm26-lineup-optimizer/
├── ui/                            # PRIMARY: Electron/React UI application
│   ├── src/                       # React frontend source
│   ├── electron/                  # Electron main process
│   ├── api/                       # Python API wrappers for UI
│   └── data/                      # UI state and confirmed lineups
├── fm_team_selector_optimal.py    # CLI: Optimal selector using Hungarian algorithm
├── fm_team_selector.py            # CLI: Basic greedy algorithm selector
├── fm_rotation_selector.py        # CLI: Dual squad selector (First XI + Rotation XI)
├── fm_match_ready_selector.py     # Core: Match-day selection with condition/fatigue
├── compare_selections.py          # CLI: Comparison tool for greedy vs optimal
├── data_manager.py                # Core: Excel to CSV data pipeline
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
- `__init__(filepath)` - Loads player data from CSV/Excel
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

**Note:** DM positions now use `DM(L)` and `DM(R)` separately rather than averaging them, allowing for better player differentiation.

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
    ('DM1', 'DM(L)'),      # Use DM(L) for better differentiation
    ('DM2', 'DM(R)'),      # Use DM(R) for better differentiation
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
python compare_selections.py players-current.csv
```
Expected: Optimal rating >= Greedy rating (always)

**Check formation totals:**
- Count positions in formation list = 11
- Count selected players = 11
- No duplicate players in selection

### Edge Cases

1. **DM(L) and DM(R) both NaN** - Position will be unfilled if no valid players available
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

### 4. DM Position Handling

DM positions use `DM(L)` and `DM(R)` columns separately rather than averaging them. This allows for better player differentiation - a player who excels at DM(L) but not DM(R) will be correctly prioritized for the left defensive midfield slot.

### 5. File Path Handling

Scripts accept file paths as command-line arguments:
```bash
python fm_team_selector_optimal.py players-current.csv  # Relative path
python fm_team_selector_optimal.py /full/path/to/players-current.csv  # Absolute
```

**Default:** Falls back to 'players-current.csv' or 'players.xlsx' if no argument provided.

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

- Main branch: `main`
- Feature branches should be created for significant changes
- Current active branch: Check with `git branch` before committing

### Ignored Files

Per .gitignore:
- `players-current.csv` - User's personal player data
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

## Match Importance-Based Selection Logic

The `fm_match_ready_selector.py` applies different selection strategies based on match importance:

### High Priority Matches (Pure Match Effectiveness)

For High priority matches, the selector uses **pure match effectiveness** - selecting the best possible lineup based only on factors that affect actual in-match performance:

**Factors APPLIED for High priority:**
- Base ability rating (position-specific skill)
- Familiarity penalty (natural position affects performance)
- Match sharpness penalty (affects match performance)
- Condition penalty (physical readiness)
- Fatigue penalty (energy levels)
- Match importance safety modifier (extra caution for high fatigue/low condition)

**Factors SKIPPED for High priority:**
- Consecutive match penalty (rotation feature)
- Training bonus (development feature)
- Versatility bonus (squad planning feature)
- Strategic pathway bonus (position retraining feature)
- Loan penalty (squad planning feature)

This ensures High priority matches get the absolute best XI based purely on match-day effectiveness.

### Medium/Low Priority Matches (Development & Rotation)

For Medium and Low priority matches, additional bonuses/penalties are applied to facilitate squad development and rotation:

- **Consecutive match penalty** - Players who've started many matches in a row get small penalties to encourage rotation
- **Training bonus** - Players actively training at a position get a small boost
- **Versatility bonus** - Players who can cover multiple positions get slight preference
- **Strategic pathway bonus** - Players fitting retraining pathways (e.g., winger→WB, AMC→DM) get preference
- **Loan penalty** - Loaned-in players are deprioritized in favor of owned players
- **Sharpness prioritization** (Low only) - Players needing match time get boosted

### Sharpness Priority Matches (Development Focus)

For Sharpness priority matches, the selector maximizes **match sharpness development** for the Starting XI and top backups:

**Two-Phase Selection:**
1. **Phase 1:** Calculate theoretical best XI using High priority logic, plus top 6 backups by CA
2. **Phase 2:** From that 18-player pool, prioritize players who need sharpness

**Priority Order (highest to lowest):**
1. Starting XI with LOW sharpness (<75%) - 1.50x boost
2. Starting XI with MEDIUM sharpness (75-85%) - 1.20x boost
3. Top 6 Backups with LOW sharpness - 1.30x boost
4. Top 6 Backups with MEDIUM sharpness - 1.10x boost
5. Starting XI with HIGH sharpness (85-99%) - 0.70x penalty
6. Top 6 Backups with HIGH sharpness - 0.60x penalty
7. MAX sharpness (100%) players - 0.30x penalty (avoid unless necessary)

**Use Case:** Schedule a "Sharpness" match (e.g., friendly) when key players need to build form before important fixtures.

**Safety:** Condition/fatigue penalties still apply - won't risk injury to build sharpness.

### Proactive Rotation

The selector also clears proactive rotation rests for High priority matches - if a player was scheduled to be rested, they're still available for selection in High priority matches where we need the best XI.

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
