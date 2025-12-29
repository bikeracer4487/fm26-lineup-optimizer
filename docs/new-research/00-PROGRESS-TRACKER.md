# FM26 Lineup Optimizer - Research Progress Tracker

## Overall Status

| Phase | Status | Progress |
|-------|--------|----------|
| Phase 1: Core Algorithm Correction | Not Started | 0/4 |
| Phase 2: Multi-Match Planning | Not Started | 0/2 |
| Phase 3: Supporting Systems | Not Started | 0/3 |
| Phase 4: Validation & Calibration | Not Started | 0/2 |
| Phase 5: Implementation | Not Started | 0/1 |

**Overall Progress**: 0/12 steps complete

---

## Detailed Step Tracking

### Phase 1: Core Algorithm Correction

#### Step 1: FM26 Game Mechanics Deep Dive
- **Status**: NOT STARTED
- **Priority**: Critical
- **Prompt File**: `01-PROMPT-fm26-mechanics.md`
- **Result File**: TBD
- **Goal**: Ground-truth verification of FM26 mechanics (condition, sharpness, fatigue, jadedness)

**Checklist**:
- [ ] Prompt document created
- [ ] Research executed
- [ ] Results uploaded
- [ ] Results reviewed
- [ ] Follow-up questions resolved
- [ ] Step marked complete

**Notes**: This is foundational - all other steps depend on accurate FM26 mechanics understanding.

---

#### Step 2: Unified Scoring Model
- **Status**: NOT STARTED
- **Priority**: Critical
- **Prompt File**: `02-PROMPT-unified-scoring.md`
- **Result File**: TBD
- **Dependencies**: Step 1
- **Goal**: Reconcile multiplier inconsistencies across documents #1-4

**Checklist**:
- [ ] Prompt document created
- [ ] Research executed
- [ ] Results uploaded
- [ ] Results reviewed
- [ ] Parameter table finalized
- [ ] Step marked complete

**Current Issues to Resolve**:
- Condition: Four different parameter sets across documents
- Sharpness: Power curve vs sigmoid disagreement
- Fatigue: Threshold calculation varies
- Familiarity: Parameters differ between docs

---

#### Step 3: State Propagation Calibration
- **Status**: NOT STARTED
- **Priority**: Critical
- **Prompt File**: `03-PROMPT-state-propagation.md`
- **Result File**: TBD
- **Dependencies**: Step 1
- **Goal**: Accurate condition/sharpness/fatigue simulation

**Checklist**:
- [ ] Prompt document created
- [ ] Research executed
- [ ] Results uploaded
- [ ] Results reviewed
- [ ] Propagation equations validated
- [ ] Step marked complete

**Current Code**: `ui/api/state_simulation.py`

---

#### Step 4: Hungarian Matrix Architecture
- **Status**: NOT STARTED
- **Priority**: High
- **Prompt File**: `04-PROMPT-hungarian-matrix.md`
- **Result File**: TBD
- **Dependencies**: Steps 2, 3
- **Goal**: Finalize cost matrix structure with REST slots

**Checklist**:
- [ ] Prompt document created
- [ ] Research executed
- [ ] Results uploaded
- [ ] Results reviewed
- [ ] REST slot behavior confirmed
- [ ] Constraint encoding finalized
- [ ] Step marked complete

---

### Phase 2: Multi-Match Planning

#### Step 5: Shadow Pricing Formula
- **Status**: NOT STARTED
- **Priority**: High
- **Prompt File**: `05-PROMPT-shadow-pricing.md`
- **Result File**: TBD
- **Dependencies**: Step 4
- **Goal**: Multi-match opportunity cost calculation

**Checklist**:
- [ ] Prompt document created
- [ ] Research executed
- [ ] Results uploaded
- [ ] Results reviewed
- [ ] Shadow cost formula finalized
- [ ] Step marked complete

**Current Code**: `ui/api/shadow_pricing.py`

---

#### Step 6: Fatigue Dynamics & Rest Policy
- **Status**: NOT STARTED
- **Priority**: High
- **Prompt File**: `06-PROMPT-fatigue-rest.md`
- **Result File**: TBD
- **Dependencies**: Steps 1, 3
- **Goal**: Thresholds, recovery, vacation recommendations

**Checklist**:
- [ ] Prompt document created
- [ ] Research executed
- [ ] Results uploaded
- [ ] Results reviewed
- [ ] Rest policy defined
- [ ] Vacation recommendations specified
- [ ] Step marked complete

---

### Phase 3: Supporting Systems

#### Step 7: Position Training Recommender
- **Status**: NOT STARTED
- **Priority**: Medium
- **Prompt File**: `07-PROMPT-training-recommender.md`
- **Result File**: TBD
- **Dependencies**: Step 2
- **Goal**: Tactical gap analysis and training priorities

**Checklist**:
- [ ] Prompt document created
- [ ] Research executed
- [ ] Results uploaded
- [ ] Results reviewed
- [ ] Ranking formula defined
- [ ] Step marked complete

**Current Code**: `ui/api/api_training_advisor.py`

---

#### Step 8: Player Removal Model
- **Status**: NOT STARTED
- **Priority**: Medium
- **Prompt File**: `08-PROMPT-player-removal.md`
- **Result File**: TBD
- **Dependencies**: None
- **Goal**: Multi-factor sell/loan/release decisions

**Checklist**:
- [ ] Prompt document created
- [ ] Research executed
- [ ] Results uploaded
- [ ] Results reviewed
- [ ] Decision model finalized
- [ ] Step marked complete

**Current Code**: `ui/api/api_player_removal.py`

---

#### Step 9: Match Importance Scoring
- **Status**: NOT STARTED
- **Priority**: Medium
- **Prompt File**: `09-PROMPT-match-importance.md`
- **Result File**: TBD
- **Dependencies**: None
- **Goal**: Automatic importance classification

**Checklist**:
- [ ] Prompt document created
- [ ] Research executed
- [ ] Results uploaded
- [ ] Results reviewed
- [ ] Classification rules defined
- [ ] Step marked complete

---

### Phase 4: Validation & Calibration

#### Step 10: Validation Test Suite
- **Status**: NOT STARTED
- **Priority**: High
- **Prompt File**: `10-PROMPT-validation-suite.md`
- **Result File**: TBD
- **Dependencies**: Steps 2-6
- **Goal**: Offline evaluation metrics and test cases

**Checklist**:
- [ ] Prompt document created
- [ ] Research executed
- [ ] Results uploaded
- [ ] Results reviewed
- [ ] Test scenarios defined
- [ ] Metrics finalized
- [ ] Step marked complete

**Current Code**: `tests/test_validation_scenarios.py`

---

#### Step 11: Parameter Calibration
- **Status**: NOT STARTED
- **Priority**: High
- **Prompt File**: `11-PROMPT-calibration.md`
- **Result File**: TBD
- **Dependencies**: Step 10
- **Goal**: Grid search and sensitivity analysis

**Checklist**:
- [ ] Prompt document created
- [ ] Research executed
- [ ] Results uploaded
- [ ] Results reviewed
- [ ] Default parameters finalized
- [ ] Sensitivity analysis complete
- [ ] Step marked complete

---

### Phase 5: Implementation

#### Step 12: Implementation Plan
- **Status**: NOT STARTED
- **Priority**: Final
- **Document File**: `12-IMPLEMENTATION-PLAN.md`
- **Dependencies**: Steps 2-11
- **Goal**: Staged code changes and refactors

**Checklist**:
- [ ] Document created
- [ ] PR plan defined
- [ ] Module boundaries identified
- [ ] Migration path documented
- [ ] Step marked complete

---

## Research Results Inventory

| Step | Prompt Created | Research Done | Result File | Reviewed | Finalized |
|------|----------------|---------------|-------------|----------|-----------|
| 1 | No | No | - | No | No |
| 2 | No | No | - | No | No |
| 3 | No | No | - | No | No |
| 4 | No | No | - | No | No |
| 5 | No | No | - | No | No |
| 6 | No | No | - | No | No |
| 7 | No | No | - | No | No |
| 8 | No | No | - | No | No |
| 9 | No | No | - | No | No |
| 10 | No | No | - | No | No |
| 11 | No | No | - | No | No |
| 12 | No | N/A | - | No | No |

---

## Existing Research Documents Status

These documents represent prior research that will be consolidated:

| Document | Status | Notes |
|----------|--------|-------|
| FM26 #1 - System spec + decision model | To Supersede | Good foundation but needs validation |
| FM26 #2 - Complete Mathematical Spec | To Supersede | Detailed but conflicts with #3/#4 |
| FM26 #3 - Lineup Optimization System | To Supersede | Different parameter approach |
| FM26 #4 - Hungarian Algorithm Spec | To Supersede | Most implementation-ready but unvalidated |

**After research program completion**: These will be archived and replaced with a single unified specification.

---

## Code Changes Tracking

| File | Current Status | Planned Changes | Priority |
|------|----------------|-----------------|----------|
| `scoring_parameters.py` | Exists | Parameter consolidation | High |
| `scoring_model.py` | Exists | Multiplier formula updates | High |
| `state_simulation.py` | Exists | Propagation calibration | High |
| `shadow_pricing.py` | Exists | Formula revision | Medium |
| `stability.py` | Exists | Parameter tuning | Medium |
| `api_training_advisor.py` | Exists | New algorithm | Medium |
| `api_player_removal.py` | Exists | New algorithm | Medium |
| `api_rest_advisor.py` | Exists | Policy implementation | Medium |
| `explainability.py` | Exists | Template updates | Low |
| `tests/test_validation_scenarios.py` | Exists | New test cases | High |

---

## Change Log

| Date | Step | Action | Notes |
|------|------|--------|-------|
| 2025-12-29 | - | Research program initiated | Master plan and tracker created |

---

*Last Updated: 2025-12-29*
