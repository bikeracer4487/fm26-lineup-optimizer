# Football Manager - Optimal Starting XI Selector

Automatically selects the best Starting XI for your Football Manager team based on position-specific ratings.

## UI Application (Primary Method)

**The Electron/React UI application is the recommended way to use this tool.**

```bash
cd ui
npm install
npm run dev
```

The UI provides:
- **Fixture Management:** Add, edit, and organize matches with importance levels
- **Tactics Configuration:** IP/OOP formations with FM role mappings
- **Automatic Lineup Generation:** Optimal XI for next 5 matches
- **Manual Overrides:** Override algorithm selections with visual indicators
- **Lineup Confirmation:** Lock selections to prevent recalculation
- **Position Training:** Recommendations for squad versatility
- **Fatigue Monitoring:** Rest and vacation recommendations
- **Player Removal:** Identify players to sell, loan, or release
- **Squad Depth:** View First XI and Second XI analysis

See [QUICKSTART.md](QUICKSTART.md) for detailed setup instructions.

### UI Application Screens

The application features 8 main screens accessible via the left sidebar navigation:

---

#### 1. Fixture List

**Purpose:** Manage your season's upcoming and past matches.

**Features:**
- **Add Matches:** Create new fixtures with date, opponent name, and importance level
- **Edit/Delete:** Modify or remove existing matches
- **Importance Levels:** Assign priority to each match:
  - **High:** Selects the absolute best XI (pure match effectiveness, no rotation)
  - **Medium:** Balanced selection with some rotation and development considerations
  - **Low:** Emphasizes rotation and player development
  - **Sharpness:** Prioritizes players who need match time to build form
- **Chronological View:** Upcoming matches sorted by date at top
- **Past Matches Archive:** Collapsible section for completed fixtures

---

#### 2. Tactics Configuration

**Purpose:** Configure your In-Possession (IP) and Out-of-Possession (OOP) formations and role mappings.

**Features:**
- **In-Possession Tab:** Visual pitch grid to set attacking formation and player roles
- **Out-of-Possession Tab:** Separate defensive shape configuration
- **Role Mapping Tab:** Define which IP positions transition to which OOP positions
- **FM Role Database:** Select from authentic Football Manager roles for each position
- **Validation:** Ensures exactly 11 players in both phases with GK present
- **Save/Reset:** Persist configuration or revert to last saved state

**Settings:**
- **Training Intensity:** Low/Medium/High - affects player recovery rate projections
- **Stability Slider:** Controls lineup consistency (0-100%)
  - **0%:** Pure optimization - best player for each position regardless of history
  - **50%:** Balanced (default) - prefers keeping players in consistent positions
  - **100%:** Maximum stability - strongly prefers established positions

**Why Two Formations?** FM26's tactical system separates attacking and defensive shapes. A player might be an AMC in-possession but drop to DM out-of-possession.

---

#### 3. Match Selection

**Purpose:** Auto-generate optimal lineups for upcoming matches with manual override capability.

**Features:**

**Automatic Lineup Generation:**
- Generates lineups for next 5 upcoming matches using the Hungarian algorithm
- Factors in: position ratings, condition, match sharpness, fatigue, and match importance
- Recalculates automatically when fixtures or player data changes

**Player Cards Display:**
- Position, player name, and rating
- Condition % (color-coded: red if <90%, green if healthy)
- Match Sharpness % (blue if <80%, green if ready)
- Fatigue level indicator
- Status warnings (injury risk, vacation, low condition)

**Manual Override System:**
- Click edit icon on any player to open selection modal
- Choose replacement from available players (excludes rejected players)
- Override indicator shows when manual selection differs from algorithm
- Clear individual overrides or all at once

**Player Rejection:**
- Click X icon to reject a player from the lineup
- Rejected players excluded from auto-generation for that match
- Reset Rejections button to clear all

**Lineup Confirmation:**
- Confirm button locks the lineup, preventing recalculation
- Confirmed lineups show lock icon and persist across sessions
- Unlock button allows future recalculation if needed

**Match Sections:**
- **Matches 1-5:** Full lineup calculations with all player stats
- **Matches 6+:** Display "Lineup calculated when closer" (performance optimization)
- **Past Matches:** Read-only archive of historical lineups

---

#### 4. Position Training

**Purpose:** Identify which players should train at new positions to improve squad versatility and depth.

**Features:**

**Recommendation Tiers:**
- **High Priority:** Critical skill gaps, core squad prospects
- **Medium Priority:** Support role training, squad depth needs
- **Low Priority:** Utility training, nice-to-have versatility

**Training Card Information:**
- Player name with badges (UTIL = versatile, VAR = fills tactical gap)
- Target position to train (teal badge)
- Estimated timeline (e.g., "2-4 seasons")
- Potential ability tier and rating
- Training category and score
- Reason/explanation for the recommendation
- Strategic pathway indicators (purple highlight for position retraining pipelines)

**Interactions:**
- Reject button to dismiss recommendations
- Refresh to reload based on current player data
- Reset Rejections to restore dismissed suggestions

---

#### 5. Rest & Rotation (Fatigue Management)

**Purpose:** Monitor long-term player fatigue and provide rest recommendations.

**Key Concept:** Unlike condition (recovers in 1-2 days), fatigue is a hidden long-term metric that accumulates over weeks. High fatigue severely impacts performance and injury risk. Vacation is the only effective reset.

**Recommendation Tiers:**
- **VACATION REQUIRED (Urgent):** Fatigue at/over threshold - send on holiday immediately
- **Rest Needed (High):** At warning threshold - rotation or vacation needed
- **Watch List (Medium):** Accumulating fatigue - monitor and consider rotation
- **Monitoring (Low):** Early fatigue building - no action yet

**Fatigue Card Details:**
- Player name with status badge (Exhausted, Jaded, Accumulating, Building, etc.)
- Fatigue progress bar (visual fill with warning threshold at ~80%)
- Actual fatigue value and personal threshold
- Recovery action recommendation
- Days to recover estimate
- Match sharpness and fatigue percentage displays
- Reasons for the recommendation

**Color Coding:**
- Red: 100%+ or ≥100 fatigue (danger)
- Orange: 80-99%
- Yellow: 60-79%
- Green: <60%

---

#### 6. Player Removal

**Purpose:** Identify players to sell, loan, release, or terminate based on skill, age, contract, wages, and development potential.

**Features:**

**Summary Statistics:**
- Critical/High priority player counts
- Potential wage savings
- Starting XI / Second XI counts
- Protected prospects (U21 with 15%+ development headroom)
- Mentor candidates (high professionalism veterans)
- False prospects (young players with unrealistic growth requirements)
- Loaned player count

**Filter Bar:** Quick filter by priority level (All/Critical/High/Medium/Low)

**Loan Review Section:**
- Simplified cards for loaned-in players
- Priority levels: "End Early", "Monitor", or "Keep"
- Blue theme to distinguish from owned players

**Owned Player Cards:**

*Badges:*
- Priority (Critical/High/Medium/Low)
- Mentor, False Prospect, Prospect indicators
- Squad hierarchy (Starting XI, Second XI)
- Position role type

*Skill Comparison Grid:*
- CA vs squad average (color-coded)
- PA with development headroom percentage
- Position rank among squad
- Best skill rating and position

*Contract & Financial:*
- Contract type and months remaining
- Weekly wages and CA/$100 value metric
- Transfer value and release/termination costs

*Hidden Attributes (when available):*
- Performance: Consistency, Big Matches, Injury Proneness
- Development: Professionalism, Ambition, Determination
- Required CA/year growth rate for young players

*Recommended Action:* Suggested action with reasoning

---

#### 7. First XI

**Purpose:** View the mathematically optimal starting XI based purely on position ratings.

**Features:**
- **Team Summary:** Average team rating and player count
- **Position Groups:** Organized by line (GK, Defense, Midfield, Attack)
- **Player Information:**
  - Position badge (teal for IP, purple for IP→OOP dual positions)
  - Player name with natural position
  - Rating (bold, highlighted)
  - CA/PA metrics
  - Age
  - Condition % (color-coded)
  - Match Sharpness % (color-coded)
  - Fatigue level (color-coded)
- **Out-of-Position Indicators:** Yellow highlight when player not in natural position
- **Responsive Layout:** Table view on desktop, card view on mobile

---

#### 8. Second XI

**Purpose:** View the optimal rotation squad composed from players not in the First XI.

**Features:**
- Identical structure to First XI but with purple color scheme
- Shows average team rating for rotation squad
- Rating drop comparison vs First XI (in orange)
- Useful for assessing squad depth and identifying weaknesses

---

### Navigation and Workflow

**Typical User Journey:**
1. **Fixture List** → Add upcoming matches with importance levels
2. **Tactics Configuration** → Set up IP/OOP formations (one-time setup)
3. **Match Selection** → Review auto-generated lineups, make manual adjustments, confirm
4. **Position Training** → Identify players to develop for squad depth
5. **Rest & Rotation** → Monitor fatigue, rest key players before important matches
6. **Player Removal** → Identify deadwood to sell/release
7. **First XI / Second XI** → Review squad depth and rotation options

**Sidebar Features:**
- Date picker with arrow navigation for game date
- All 8 screens accessible via icon buttons
- Data source path visibility toggle

**Auto-Save:** All state persists automatically to `ui/data/app_state.json` and `ui/data/confirmed_lineups.json`.

---

## CLI Scripts (Advanced Users)

For automation or advanced use cases, CLI scripts are available:

### Advanced Features

**Two scripts** factor in match sharpness, physical condition, fatigue, and intelligent rotation:

- **fm_training_advisor.py** - Analyzes squad depth and recommends position training
- **fm_match_ready_selector.py** - Selects lineups considering fitness, fatigue, and fixture scheduling

**[See the Advanced Features Guide](ADVANCED_FEATURES.md) for complete documentation**

### Core Selection Scripts

### 1. **fm_team_selector_optimal.py** (RECOMMENDED)
Uses the **Hungarian algorithm** to find the truly optimal player-position assignment that maximizes total team rating.
- ✅ Finds the mathematically optimal lineup
- ✅ Typically 1-3% better average rating
- ✅ Better player-position assignments
- ⏱️ Still very fast (< 1 second)

### 2. **fm_team_selector.py** (Basic)
Uses a **greedy algorithm** that selects the best available player for each position in order.
- ⚡ Slightly faster
- ⚠️ May not find the optimal solution
- 📊 Good for quick checks

**Recommendation:** Use `fm_team_selector_optimal.py` for your actual team selection!

## Formation

This script is configured for the following 4-2-3-1 formation:

```
         STC
  AML    AMC    AMR
      DM1  DM2
  DL  DC1  DC2  DR
         GK
```

## Requirements

- Python 3.8+
- pandas (data manipulation)
- numpy (numerical operations)
- scipy (Hungarian algorithm for optimal selection)
- openpyxl (Excel file support)
- pywinauto (FMRTE automation - Windows only)
- pyperclip (clipboard operations for FMRTE)
- unidecode (character normalization)

Install all requirements:
```bash
pip install -r requirements.txt
```

**Note:** pywinauto and pyperclip are only needed for FMRTE integration scripts.

## Quick Start

### Using the Optimal Version (Recommended)
```bash
python fm_team_selector_optimal.py players-current.csv
```

### Using the Basic Version
```bash
python fm_team_selector.py players-current.csv
```

### Compare Both Approaches
```bash
python compare_selections.py players-current.csv
```

## Input File Format

The `players-current.csv` file is automatically generated by `data_manager.py` from the Excel file. It includes:

### Core Player Info
- **Name**: Player name
- **Positions**: Natural positions (e.g., "DM/M/AM C")
- **Age**: Player's age
- **CA**: Current Ability (0-200)
- **PA**: Potential Ability (0-200)

### Match Readiness
- **Condition (%)**: Physical condition percentage
- **Match Sharpness**: Match form (0-10000, displayed as %)
- **Fatigue**: Accumulated fatigue level
- **Is Injured**: Boolean injury status
- **Banned**: Suspension status

### Calculated Position Ratings (0-200 scale)
- **GK**: Goalkeeper rating
- **D(R)**, **D(L)**, **D(R/L)**, **D(C)**: Defender ratings
- **DM(L)**, **DM(R)**: Defensive Midfielder ratings
- **WB(L)**, **WB(R)**: Wing-Back ratings
- **M(C)**, **M(L)**, **M(R)**: Central/Wide Midfielder ratings
- **AM(L)**, **AM(C)**, **AM(R)**: Attacking Midfielder ratings
- **Striker**: Striker rating

### Position Familiarity (1-20)
- **GK_Familiarity**, **D(R)_Familiarity**, etc.: Natural position comfort level

### Hidden Attributes
- **Consistency**, **Important Matches**, **Injury Proneness**: Performance hidden attributes
- **Professionalism**, **Ambition**, **Determination**: Development hidden attributes
- **Versatility**, **Adaptability**: Tactical hidden attributes

### Contract Info
- **Club**, **Contract Type**, **Wages**, **Months Left (Contract)**
- **Asking Price**: Transfer value
- **LoanStatus**: "Own", "LoanedIn", or "LoanedOut"

**Data Pipeline:** Export from FMRTE → `FM26 Players.xlsx` → Run `data_manager.py` → `players-current.csv`

## How It Works

### Optimal Selector (Hungarian Algorithm)
1. **Cost Matrix**: Creates a matrix of players × positions with negative ratings
2. **Linear Sum Assignment**: Uses `scipy.optimize.linear_sum_assignment` to find the optimal assignment
3. **Result**: Each player assigned to exactly one position, maximizing total team rating

### Match-Ready Selector (Advanced)
The UI and `fm_match_ready_selector.py` add additional factors:
1. **Base Rating**: Position-specific skill rating (Harmonic Mean of IP/OOP)
2. **Condition Multiplier**: Bounded sigmoid function with importance-specific thresholds
3. **Fatigue Multiplier**: Player-relative sigmoid based on personal fatigue threshold
4. **Sharpness Multiplier**: Power curve matching FM's in-game sharpness impact
5. **Familiarity Multiplier**: Sigmoid-based penalty for unfamiliar positions
6. **Match Importance**: Context-dependent parameters for High/Medium/Low/Sharpness matches
7. **Shadow Pricing**: 5-match lookahead to preserve players for upcoming important matches
8. **Polyvalent Stability**: Prevents oscillating positions for versatile players

### General Rules
- **No Duplicates**: Each player can only be selected once
- **DM Positions**: Uses `DM(L)` and `DM(R)` ratings separately for better player differentiation
- **Full Back Positions**: Uses D(R/L) rating for both DL and DR positions

## Output

The script will:
1. Display the optimal Starting XI in the terminal with ratings
2. Calculate the average team rating
3. Export the Starting XI to `starting_xi.csv`

### Example Output:
```
============================================================
OPTIMAL STARTING XI
============================================================

Attack:
  STC   : Alan Hackney         (92.5)

Attacking Midfield:
  AML   : Daniel Willard       (78.2)
  AMC   : Marc Mitchell        (91.9)
  AMR   : Andrey Quintino      (93.1)

Defensive Midfield:
  DM1   : Ryan Penny           (80.8)
  DM2   : Hisashi Roddy        (89.0)

Defense:
  DL    : Taye Weir            (78.4)
  DC1   : Asa Hall             (87.1)
  DC2   : Jayden Batterbatch   (84.1)
  DR    : Hisashi Roddy        (91.6)

Goalkeeper:
  GK    : Ashley Sarahs        (89.3)

============================================================
Average Team Rating: 86.89
============================================================
```

## Customization

### Change Formation

To modify the formation, edit the `formation` list in the `main()` function:

```python
formation = [
    ('GK', 'GK'),
    ('DL', 'D(R/L)'),
    ('DC1', 'D(C)'),
    ('DC2', 'D(C)'),
    ('DR', 'D(R/L)'),
    ('DM1', 'DM(L)'),
    ('DM2', 'DM(R)'),
    ('AML', 'AM(L)'),
    ('AMC', 'AM(C)'),
    ('AMR', 'AM(R)'),
    ('STC', 'Striker')
]
```

### Change DM Selection Method

By default, DM positions use `DM(L)` and `DM(R)` separately for better player differentiation. Alternative options:

**Option A: Use DM(C) if you have that column:**
```python
formation = [
    # ... other positions ...
    ('DM1', 'DM(C)'),
    ('DM2', 'DM(C)'),
    # ... other positions ...
]
```

## Advanced Features

### Export Different Formats

Modify the export section to save in different formats:

```python
# Export as Excel
xi_df.to_excel('starting_xi.xlsx', index=False)

# Export as JSON
xi_df.to_json('starting_xi.json', orient='records')
```

### Consider Fitness/Condition

Add additional filtering before selection:

```python
# Only select players with good condition
available_players = available_players[available_players['Condition'] >= 90]
```

### Age-based Selection

Prefer younger players with similar ratings:

```python
# Add age weighting (younger = better when ratings are close)
available_players['weighted_rating'] = (
    available_players[position_column] + 
    (30 - available_players['Age']) * 0.1
)
```

## Troubleshooting

**Error: "Could not find file"**
- Make sure your spreadsheet is in the same directory as the script
- Or provide the full path: `python fm_team_selector.py /path/to/players.xlsx`

**Error: "KeyError: 'ColumnName'"**
- Check that your column names match exactly (case-sensitive)
- Ensure all required columns exist in your spreadsheet

**Players have NaN ratings**
- The script automatically skips players with missing ratings for specific positions
- Check your spreadsheet for empty cells

## All Available Scripts

### Selection Scripts

| Script | Purpose | Use Case |
|--------|---------|----------|
| `fm_team_selector_optimal.py` | Optimal XI selection using ratings only | Finding the theoretical best lineup |
| `fm_team_selector.py` | Greedy XI selection | Quick selections, prototyping |
| `fm_rotation_selector.py` | Dual squad selection (First XI + Rotation XI) | Analyzing squad depth |
| `compare_selections.py` | Compare greedy vs optimal approaches | Validation and benchmarking |

### Advanced Features

| Script | Purpose | Use Case |
|--------|---------|----------|
| `fm_match_ready_selector.py` | Match-day lineup with fitness/fatigue factors | Weekly match planning via UI |
| `fm_training_advisor.py` | Training position recommendations | Improving squad depth via UI |

See [ADVANCED_FEATURES.md](ADVANCED_FEATURES.md) for complete documentation.

### Data Pipeline

| Script | Purpose | Use Case |
|--------|---------|----------|
| `data_manager.py` | Excel to CSV conversion with calculated ratings | Refresh player data after FMRTE export |
| `rating_calculator.py` | Position rating calculations (FM Arena weights) | Core dependency for data_manager |
| `fmrte_to_excel.py` | Automated FMRTE data extraction (Windows) | Batch export from FMRTE to Excel |
| `fmrte_to_excel-remote.py` | Remote version of FMRTE extraction | Alternative FMRTE workflow |
| `extract_weights.py` | Extract position weights from FM Arena | Updating rating formulas |

### UI API Scripts (ui/api/)

| Script | Purpose |
|--------|---------|
| `api_match_selector.py` | Python backend for Match Selection screen |
| `api_rotation_selector.py` | Python backend for First XI / Second XI screens |
| `api_training_advisor.py` | Python backend for Position Training screen |
| `api_rest_advisor.py` | Python backend for Rest & Rotation screen |
| `api_player_removal.py` | Python backend for Player Removal screen |
| `scoring_model.py` | Bounded sigmoid multipliers and utility calculation |
| `state_simulation.py` | Player state propagation across matches |
| `shadow_pricing.py` | 5-match lookahead opportunity cost calculation |
| `stability.py` | Polyvalent stability (prevents position oscillation) |
| `explainability.py` | Selection reason generation for UI |

## License

Free to use and modify for your Football Manager adventures!

## Support

For issues or feature requests, please check:
- Column names match exactly
- Data is in proper numeric format
- File is not corrupted
- pandas and openpyxl are installed correctly
