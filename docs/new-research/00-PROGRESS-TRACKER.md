# FM26 Lineup Optimizer - Research Progress Tracker

## Overall Status

| Phase | Status | Progress |
|-------|--------|----------|
| Phase 1: Core Algorithm Correction | **COMPLETE** | 4/4 |
| Phase 2: Multi-Match Planning | **COMPLETE** | 2/2 |
| Phase 3: Supporting Systems | Not Started | 0/3 |
| Phase 4: Validation & Calibration | Not Started | 0/2 |
| Phase 5: Implementation | Not Started | 0/1 |

**Overall Progress**: 6/12 steps complete (Phase 2 COMPLETE)

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
- **Status**: COMPLETE
- **Priority**: Critical
- **Prompt File**: `03-PROMPT-state-propagation.md`
- **Result File**: `03-RESULTS-state-propagation.md`
- **Dependencies**: Step 1
- **Goal**: Accurate condition/sharpness/fatigue simulation

**Checklist**:
- [x] Prompt document created
- [x] Research executed
- [x] Results uploaded
- [x] Results reviewed
- [x] Propagation equations validated
- [x] Step marked complete

**Key Findings - State Propagation Equations**:

**Player State Vector**:
$$\mathbf{P}_t = [C_t, M_t, J_t, I_t]$$ (Condition, Sharpness, Jadedness, Injury Risk)

**Match Day Condition Decay**:
$$\frac{dC}{dt} = - \left[ \alpha \cdot I_{tac}(t) \cdot R_{pos} \cdot \frac{A_{wrk}}{A_{sta}} \cdot \phi(100 - C_t) \right]$$

**Positional Drag Coefficients (R_pos)** - MAJOR FINDING:
| Position | R_pos | Implication |
|----------|-------|-------------|
| GK | 0.2 | Almost no drain |
| CB | 0.9-1.0 | Can play consecutive |
| DM | 1.15 | Moderate |
| CM (B2B) | 1.45 | High - rotate |
| AMC | 1.35 | High |
| Winger | 1.40 | High |
| **Fullback/WB** | **1.65** | **Highest - 100% rotation needed** |

**Recovery Equation**:
$$C_{t+1} = C_t + (10000 - C_t) \cdot \beta \cdot (A_{nat})^\gamma \cdot (1 - \mathcal{J}(J_t))$$
- Natural Fitness has increasing returns (γ > 1)
- Jadedness throttles recovery

**270-Minute Rule REFINED**:
- Window: **14 days** (not 10)
- Multiplier: **2.5x** jadedness accumulation when exceeded

**Sharpness "Seven-Day Cliff"**:
- Day 0-3: No decay
- Day 4-6: ~1-2%/day
- Day 7+: **5-8%/day** (cliff)

**Operational Heuristics**:
- "Stamina wins the match, Natural Fitness wins the season"
- 60/30 Rule: Sub high-drain positions at 60' for 30-min sub play
- CBs can play consecutive; Fullbacks need 100% rotation

**Current Code**: `ui/api/state_simulation.py`

---

#### Step 4: Hungarian Matrix Architecture
- **Status**: COMPLETE
- **Priority**: High
- **Prompt File**: `04-PROMPT-hungarian-matrix.md`
- **Result File**: `04-RESULTS-hungarian-matrix.md`
- **Dependencies**: Steps 2, 3
- **Goal**: Finalize cost matrix structure with REST slots

**Checklist**:
- [x] Prompt document created
- [x] Research executed
- [x] Results uploaded
- [x] Results reviewed
- [x] REST slot behavior confirmed
- [x] Constraint encoding finalized
- [x] Step marked complete

**Key Findings - Hungarian Matrix Architecture**:

**Two-Stage Algorithm**:
1. **Stage 1 (Starting XI)**: 11 × M matrix using Peak Utility
2. **Stage 2 (Bench)**: K × (M-S) using Coverage Utility (rewards versatility)

**Disjoint Set Handling**:
- Split GK (1 × N_GK) and Outfield (10 × N_Outfield) for stability

**Safe Big M = 10^6** (not infinity - causes SciPy errors)

**Condition Cliff Heuristic**:
| Condition | Multiplier | Status |
|-----------|------------|--------|
| ≥ 95% | 1.00 | Peak |
| 90-94% | 0.95 | Startable |
| 80-89% | 0.80 | Risk |
| < 80% | 0.50 | Danger |
| < 75% | Big M | Forbidden |

**Multi-Objective Scalarization**:
$$C_{total} = w_1 C_{perf} + w_2 C_{dev} + w_3 C_{fatigue}$$

| Scenario | w1 (Perf) | w2 (Dev) | w3 (Rest) |
|----------|-----------|----------|-----------|
| Cup Final | 1.0 | 0.0 | 0.0 |
| League Grind | 0.6 | 0.1 | 0.3 |
| Dead Rubber | 0.2 | 0.5 | 0.3 |

**Additional Features**:
- Switching costs (penalty for position change from previous match)
- Lagrangian relaxation for registration quotas
- Quantize utilities to 2 decimal places for deterministic tie-breaking

---

### Phase 2: Multi-Match Planning

#### Step 5: Shadow Pricing Formula
- **Status**: COMPLETE
- **Priority**: High
- **Prompt File**: `05-PROMPT-shadow-pricing.md`
- **Result File**: `05-RESULTS-shadow-pricing.md`
- **Dependencies**: Step 4
- **Goal**: Multi-match opportunity cost calculation

**Checklist**:
- [x] Prompt document created
- [x] Research executed
- [x] Results uploaded
- [x] Results reviewed
- [x] Shadow cost formula finalized
- [x] Step marked complete

**Key Findings - Shadow Pricing**:

**Shadow Cost Formula (Trajectory Bifurcation)**:
$$\lambda_{p,t} = S_p^{VORP} \times \sum_{k=t+1}^{T} (\gamma^{k-t} \times I_k \times \max(0, \Delta GSS_{p,k}))$$

Where ΔGSS = GSS(rest trajectory) - GSS(play trajectory)

**Importance Weights (NEW Exponential Scale)**:
| Scenario | Weight | Shadow Behavior |
|----------|--------|-----------------|
| Cup Final | 10.0 | Massive shadow zones in preceding weeks |
| Continental KO | 5.0 | Strong preservation of key assets |
| League (Title Rival) | 3.0 | Significant shadow cost |
| League (Standard) | 1.5 | Balanced rotation |
| Cup (Early) | 0.8 | High shadow for starters (low gain) |
| Dead Rubber | 0.1 | Shadow blocks tired starters |

**Parameter Table**:
| Parameter | Symbol | Default | Range |
|-----------|--------|---------|-------|
| Discount Factor | γ | 0.85 | 0.70-0.95 |
| Shadow Weight | λ_shadow | 1.0 | 0.0-2.0 |
| Scarcity Scaling | λ_V | 2.0 | 1.0-3.0 |
| Jadedness Threshold | J_lim | 270 | Fixed |
| Rest Threshold | Φ_min | 91% | 85-95% |

**VORP Scarcity Index** (Key Player Identification):
$$\alpha_{scarcity} = 1 + \lambda_V \times \min(0.5, \frac{GSS_{star} - GSS_{backup}}{GSS_{star}})$$
- Gap% > 10% → player is "Key"
- Max scarcity multiplier: 2.0

**Algorithm**: O(N × H) heuristic lookahead (<1ms execution)
- Rejects Lagrangian Relaxation for performance
- Achieves >90% optimal solution quality

**Current Code**: `ui/api/shadow_pricing.py`

---

#### Step 6: Fatigue Dynamics & Rest Policy
- **Status**: COMPLETE
- **Priority**: High
- **Prompt File**: `06-PROMPT-fatigue-rest.md`
- **Result File**: `06-RESULTS-fatigue-rest.md`
- **Dependencies**: Steps 1, 3
- **Goal**: Thresholds, recovery, vacation recommendations

**Checklist**:
- [x] Prompt document created
- [x] Research executed
- [x] Results uploaded
- [x] Results reviewed
- [x] Rest policy defined
- [x] Vacation recommendations specified
- [x] Step marked complete

**Key Findings - Fatigue Dynamics & Rest Policy**:

**Dual-Variable State Space**:
$$\Phi_t = \begin{bmatrix} C_t \\ J_t \end{bmatrix}$$
- Condition (C): Visible, recovers in 2-3 days
- Jadedness (J): Hidden accumulator, requires specific intervention

**Jadedness Thresholds (0-1000 scale)**:
| State | J Range | Ω Multiplier | Operational Effect |
|-------|---------|--------------|-------------------|
| Fresh | 0-200 | 1.00 | Peak performance |
| Match Fit | 201-400 | 0.90 | Minor decay, no penalty |
| Tired | 401-700 | 0.70 | Significant penalty, high injury risk |
| Jaded | 701+ | 0.40 | Critical - Consistency penalty active |

**The Holiday Protocol** (CRITICAL):
- Standard rest clears ~5 J points/day (insufficient)
- Holiday clears ~50 J points/day (10x faster)
- **When "Rst" icon appears**: Training → Rest → Send on Holiday (1 Week)

**Player Archetypes**:
| Archetype | Profile | Policy |
|-----------|---------|--------|
| Workhorse | NF 15+, Sta 15+ | Holiday every 15 matches |
| Glass Cannon | Inj Prone >12, NF <12 | Cap 180 mins/14d, sub at 60' |
| Veteran (30+) | Age >30 | One game per week max |
| Youngster (<19) | Age <19 | Limit 20-25 senior starts/season |

**Training Integration**:
- "Double Intensity" + 2 matches/week = death spiral
- Rule: If 2+ matches in week → Training = "Half" or "Rest"

**Rest Policy Decision Tree**:
1. **Jaded?** → MANDATORY VACATION (1 week)
2. **Red Zone?** (>270 mins/14d OR <91% condition) → ENFORCED REST
3. **Tired?** (91-94% OR 180-270 mins) → ROTATION/BENCH
4. **Fresh?** (>95% AND <180 mins) → AVAILABLE

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
| 3 | Yes | Yes | `03-RESULTS-state-propagation.md` | Yes | Yes |
| 4 | Yes | Yes | `04-RESULTS-hungarian-matrix.md` | Yes | Yes |
| 5 | Yes | Yes | `05-RESULTS-shadow-pricing.md` | Yes | Yes |
| 6 | Yes | Yes | `06-RESULTS-fatigue-rest.md` | Yes | Yes |
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
| 2025-12-29 | 3 | Step 3 COMPLETE | Positional drag coefficients, 14-day/270-min rule, sharpness cliff model |
| 2025-12-29 | - | Prompts 04-06, 10-11 updated | Added R_pos coefficients, 14-day window, sharpness cliff tests |
| 2025-12-29 | 4 | Step 4 COMPLETE - PHASE 1 DONE | Two-stage algorithm, Big M=10^6, multi-objective scalarization |
| 2025-12-29 | - | Prompts 05, 10, 11 updated | Added scenario weights, switching costs, bench selection tests |
| 2025-12-29 | 5 | Step 5 COMPLETE | Shadow cost formula, VORP scarcity index, O(N×H) heuristic |
| 2025-12-29 | - | Prompts 06, 10, 11 updated | Added importance weights (0.1-10.0), shadow pricing parameters |
| 2025-12-29 | 6 | Step 6 COMPLETE - PHASE 2 DONE | Dual-variable fatigue model, Holiday Protocol, player archetypes |
| 2025-12-29 | - | Prompts 10, 11 updated | Added jadedness thresholds, archetype tests, training integration |

---

*Last Updated: 2025-12-29*
