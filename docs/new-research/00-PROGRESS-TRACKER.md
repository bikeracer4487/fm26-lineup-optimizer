# FM26 Lineup Optimizer - Research Progress Tracker

## Overall Status

| Phase | Status | Progress |
|-------|--------|----------|
| Phase 1: Core Algorithm Correction | In Progress | 2/4 |
| Phase 2: Multi-Match Planning | Not Started | 0/2 |
| Phase 3: Supporting Systems | Not Started | 0/3 |
| Phase 4: Validation & Calibration | Not Started | 0/2 |
| Phase 5: Implementation | Not Started | 0/1 |

**Overall Progress**: 2/12 steps complete

---

## Detailed Step Tracking

### Phase 1: Core Algorithm Correction

#### Step 1: FM26 Game Mechanics Deep Dive
- **Status**: COMPLETE
- **Priority**: Critical
- **Prompt File**: `01-PROMPT-fm26-mechanics.md`
- **Result File**: `01-RESULTS-fm26-mechanics.md`
- **Goal**: Ground-truth verification of FM26 mechanics (condition, sharpness, fatigue, jadedness)

**Checklist**:
- [x] Prompt document created
- [x] Research executed
- [x] Results uploaded
- [x] Results reviewed
- [x] Follow-up questions resolved (incorporated into subsequent prompts)
- [x] Step marked complete

**Key Findings Applied to Future Steps**:
- Condition: 0-10,000 scale, 92% = "Match Fit", 95% = "Peak"
- Sharpness: "Seven-Day Cliff" - 3-5% decay/day (much faster than FM24)
- Jadedness: Only "Holiday" clears it, not standard "Rest"
- Dual IP/OOP familiarity evaluation is critical
- Physical attributes (Pace/Accel) have 1.25-1.5x weight in match engine

**Prompts Updated Based on Findings**:
- `02-PROMPT-unified-scoring.md` - Added verified thresholds, dual-familiarity requirement
- `03-PROMPT-state-propagation.md` - Added calibration targets
- `06-PROMPT-fatigue-rest.md` - Added jadedness/holiday mechanics

---

#### Step 2: Unified Scoring Model
- **Status**: COMPLETE
- **Priority**: Critical
- **Prompt File**: `02-PROMPT-unified-scoring.md`
- **Result File**: `02-RESULTS-unified-scoring.md`
- **Dependencies**: Step 1
- **Goal**: Reconcile multiplier inconsistencies across documents #1-4

**Checklist**:
- [x] Prompt document created
- [x] Research executed
- [x] Results uploaded
- [x] Results reviewed
- [x] Parameter table finalized
- [x] Step marked complete

**Key Findings - Global Selection Score (GSS)**:

The research produced a unified multiplicative model:
```
GSS = BPS × Φ(C) × Ψ(S) × Θ(F) × Ω(J)
```

**Definitive Parameter Values**:

| Multiplier | Formula | Parameters |
|------------|---------|------------|
| Condition Φ(c) | `1 / (1 + e^{-k(c - c₀)})` | k=25, c₀=0.88 |
| Sharpness Ψ(s) | `1.02 / (1 + e^{-k(s - s₀)}) - 0.02` | k=15, s₀=0.75 |
| Familiarity Θ(f) | `0.7 + 0.3f` | LINEAR (not sigmoid!) |
| Fatigue Ω(J) | Step function | Fresh=1.0, Fit=0.9, Tired=0.7, Jaded=0.4 |

**Operational Rules Discovered**:
1. **91% Floor**: Never start player < 91% condition
2. **85% Sharpness Gate**: Use U21/reserves first to build sharpness
3. **270-minute Rule**: >270 min in 10 days → 0.85 penalty regardless of UI
4. **Meta-Attributes**: Pace/Accel get 2.0x weight in BPS calculation

**Major Changes from Current Implementation**:
- Condition sigmoid MUCH steeper (k=25 vs our k=0.10-0.15)
- Sharpness uses bounded sigmoid, NOT power curve
- Familiarity is LINEAR, NOT sigmoid
- Fatigue uses step function with discrete states

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
| 1 | Yes | Yes | `01-RESULTS-fm26-mechanics.md` | Yes | Yes |
| 2 | Yes | Yes | `02-RESULTS-unified-scoring.md` | Yes | Yes |
| 3 | Yes | No | - | No | No |
| 4 | Yes | No | - | No | No |
| 5 | Yes | No | - | No | No |
| 6 | Yes | No | - | No | No |
| 7 | Yes | No | - | No | No |
| 8 | Yes | No | - | No | No |
| 9 | Yes | No | - | No | No |
| 10 | Yes | No | - | No | No |
| 11 | Yes | No | - | No | No |
| 12 | Yes | N/A | - | No | No |

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
| 2025-12-29 | 1 | Step 1 COMPLETE | FM26 mechanics verified, findings applied to prompts 02, 03, 06 |
| 2025-12-29 | 2 | Step 2 COMPLETE | GSS model finalized: k=25 condition, k=15 sharpness, linear familiarity |
| 2025-12-29 | - | Prompts 03-06 updated | Added Step 2 findings (GSS formula, 270-min rule, step function) |
| 2025-12-29 | - | Prompts 07, 10, 11 updated | Added linear familiarity, 91% thresholds, corrected calibration params |

---

*Last Updated: 2025-12-29*
