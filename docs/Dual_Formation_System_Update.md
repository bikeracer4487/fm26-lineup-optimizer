# Dual Formation (IP/OOP) System Implementation Details

## Overview
This document details the major update to the FM26 Lineup Optimizer to support the dual-formation system (In Possession / Out of Possession). This update allows for granular tactical configuration, more accurate player skill ratings based on specific role requirements for each phase of play, and separate positional familiarity penalties.

## 1. Tactics Configuration UI

### New Tactics Tab (`ui/src/tabs/TacticsTab.tsx`)
A dedicated interface has been created for configuring the team's tactical setup.
- **Three Sub-tabs**:
  1.  **In Possession (IP)**: Grid layout to select roles for the attacking formation.
  2.  **Out of Possession (OOP)**: Grid layout to select roles for the defensive formation.
  3.  **Role Mapping**: Interface to link IP positions to their corresponding OOP positions.
- **Grid Layout**: Represents the field from GK to Striker, with dropdowns populated dynamically from `roles.json`.
- **Validation Logic**:
  - Requires exactly 11 players for both IP and OOP phases.
  - Mandates a Goalkeeper selection in both phases.
  - Prevents saving until all active IP positions are mapped to valid OOP positions.
- **Data Source**: Roles and attributes are loaded from `ui/src/data/roles.json` (a copy of `docs/FM26_Roles_Attributes.json`).

### State Management
- **`TacticConfig` Interface**: Added to `ui/src/types.ts` and `AppState` to persist tactical choices.
  ```typescript
  export interface TacticConfig {
    ipPositions: Record<string, string | null>; // SlotID -> Role Name
    oopPositions: Record<string, string | null>; // SlotID -> Role Name
    mapping: Record<string, string | null>; // IP_SlotID -> OOP_SlotID
  }
  ```

## 2. Player Data Pipeline Updates

### Excel Import (`data_manager.py`)
- **Dynamic Header Parsing**: The import logic now scans column headers in `FM26 Players.xlsx` instead of relying on fixed indices. This improves robustness against column shifts.
- **New Positional Data**: Added support for importing and processing new positional skill columns:
  - Midfielder Center `M(C)`
  - Midfielder Left `M(L)`
  - Midfielder Right `M(R)`
  - Wingback Left `WB(L)`
  - Wingback Right `WB(R)`
- **Skill Calculation**: The `calculate_generic_position_rating` function was updated to use the new `rating_calculator` logic and scale ratings to a 0-200 range.

## 3. Advanced Skill Rating Algorithm

### `rating_calculator.py`
A new core calculation module was implemented to replace the legacy logic.
- **Dynamic Attribute Loading**: Loads `key` and `important` attributes directly from `docs/FM26_Roles_Attributes.json`.
- **Fuzzy Matching**: Implements robust key matching to handle inconsistencies in role naming (e.g., spacing in "M (L/R)").
- **Weighted IP/OOP Average**:
  The final player rating for a specific tactical slot is a weighted average of their IP Role Rating and OOP Role Rating. The weights depend on the **defensive responsibility** of the OOP position:
  - **Defensive OOP Roles** (GK, DC, DM, WB, FB): **50% IP / 50% OOP** (High penalty for defensive failure).
  - **Attacking OOP Roles** (ST, AM, M, Winger): **70% IP / 30% OOP** (Lower penalty for defensive failure).

### Positional Familiarity Integration
- **`api_match_selector.py`**:
  - Now accepts the `tactic_config` payload from the frontend.
  - Applies **Positional Familiarity Penalties** to the calculated rating.
  - Familiarity Mapping (approximate factors based on research):
    - 20 (Natural): 1.0
    - 15-19: ~0.95 - 0.98
    - 10-14: ~0.85 - 0.94
    - < 10: Scaling penalty down to 0.6
  - This ensures players playing out of position in either phase are penalized appropriately in the final selection logic.

## 4. Match Selection & Display

### Backend (`api_match_selector.py`)
- **Dynamic Formation Building**: The selector no longer uses a hardcoded 4-2-3-1 formation list. It builds the formation requirements dynamically based on the active slots in the user's `tactic_config`.
- **Combined Ratings**: Generates `Rating_{slot}` (raw combined skill) and `Final_{slot}` (skill × familiarity penalty) columns for the optimizer to maximize.

### Frontend Display (`ui/src/tabs/MatchSelectionTab.tsx`)
- **Combined Position Labels**: The Match Card now intelligently displays position names:
  - If IP and OOP positions are the same (e.g., `D(C)` -> `D(C)`): Displays `D(C)`.
  - If positions differ (e.g., `AM(L)` -> `M(L)`): Displays `AM(L) / M(L)`.
- **Dynamic Slots**: The lineup display renders only the slots configured in the current tactic.

## 5. Files Created/Modified
- **New Files**:
  - `ui/src/tabs/TacticsTab.tsx`: Main configuration UI.
  - `ui/src/data/roles.json`: Frontend data source for roles.
  - `rating_calculator.py`: Core rating logic (backend).
- **Modified Files**:
  - `data_manager.py`: Excel import and data processing.
  - `ui/api/api_match_selector.py`: Backend integration of tactics.
  - `ui/src/App.tsx`: Navigation and routing.
  - `ui/src/types.ts`: Type definitions.
  - `ui/src/hooks/useAppState.ts`: State persistence.
  - `ui/src/tabs/MatchSelectionTab.tsx`: Display logic.

