# FM26 Lineup Optimizer - Research Progress Tracker

## Overall Status

| Phase | Status | Progress |
|-------|--------|----------|
| Phase 1: Core Algorithm Correction | **COMPLETE** | 4/4 |
| Phase 2: Multi-Match Planning | **COMPLETE** | 2/2 |
| Phase 3: Supporting Systems | **COMPLETE** | 3/3 |
| Phase 4: Validation & Calibration | **COMPLETE** | 2/2 |
| Phase 5: Implementation | Not Started | 0/1 |

**Overall Progress**: 11/12 steps complete (Phase 4 COMPLETE)

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
- **Status**: COMPLETE
- **Priority**: Medium
- **Prompt File**: `07-PROMPT-training-recommender.md`
- **Result File**: `07-RESULTS-training-recommender.md`
- **Dependencies**: Step 2
- **Goal**: Tactical gap analysis and training priorities

**Checklist**:
- [x] Prompt document created
- [x] Research executed
- [x] Results uploaded
- [x] Results reviewed
- [x] Ranking formula defined
- [x] Step marked complete

**Key Findings - Position Training Recommendation Engine (PTRE)**:

**Four-Phase Architecture**:
1. **TGIE** - Tactical Gap Identification Engine
2. **CSA** - Candidate Selection Algorithm
3. **Timeline Estimation** - Logistic growth model
4. **Prioritization** - Impact Score ranking

**Gap Severity Index (GSI)**:
$$GSI = (Scarcity_{pos} \times Weight_{pos}) + InjuryRisk_{starter} + ScheduleDensity$$

**Candidate Selection - Euclidean Distance**:
$$Distance(P, R) = \sqrt{\sum_{i=1}^{n} w_i (A_{P,i} - A_{R,i})^2}$$

**Retraining Efficiency Ratio (RER)**:
$$RER = \frac{\text{Sum of Weighted Attributes for Target Role}}{\text{Total Current Ability Usage}}$$
- High RER → Efficient conversion (minimal CA waste)
- Low RER → Avoid (bloated CA in irrelevant attributes)

**Age/Plasticity Factors**:
| Age Bracket | Plasticity | Strategy |
|-------------|------------|----------|
| 16-21 | 1.0 (High) | Radical conversions OK |
| 22-26 | 0.7 (Medium) | Adjacent moves only |
| 27-31 | 0.4 (Low) | Career extension roles |
| 32+ | 0.1 (Minimal) | Emergency swaps only |

**Familiarity Thresholds (0-20 scale)**:
| Status | Range | Efficiency |
|--------|-------|------------|
| Natural | 18-20 | 100% |
| Accomplished | 15-17 | ~95% (Match Ready) |
| Competent | 12-14 | ~85% (Emergency Use) |
| Unconvincing | 9-11 | ~70% |
| Awkward | 5-8 | ~50% |

**Retraining Difficulty Classes**:
| Class | Time (Weeks) | Examples |
|-------|--------------|----------|
| I (Fluid) | 4-8 | LB→LWB, DM→MC |
| II (Structural) | 12-20 | DM→CB, AMC→ST |
| III (Spatial) | 24-36 | AMR→MC, ST→AMR |
| IV (Inversion) | 52+/Impossible | ST→DR, MC→GK |

**Strategic Archetype Protocols**:
- **Mascherano** (DM→CB): High Tackling/Anticipation/Passing, JR > 12
- **Lahm** (FB→DM): Elite Decisions/Teamwork/Passing, Composure > 13
- **Firmino** (AMC→ST): High Work Rate/Technique/Off the Ball

**Current Code**: `ui/api/api_training_advisor.py`

---

#### Step 8: Player Removal Model
- **Status**: COMPLETE
- **Priority**: Medium
- **Prompt File**: `08-PROMPT-player-removal.md`
- **Result File**: `08-RESULTS-player-removal.md`
- **Dependencies**: None
- **Goal**: Multi-factor sell/loan/release decisions

**Checklist**:
- [x] Prompt document created
- [x] Research executed
- [x] Results uploaded
- [x] Results reviewed
- [x] Decision model finalized
- [x] Step marked complete

**Key Findings - Player Removal Decision Model:**

**Contribution Score Algorithm (0-100)**:
| Component | Weight | Source |
|-----------|--------|--------|
| Effective Ability | 45% | Weighted role attributes (not raw CA) |
| Reliability | 20% | Hidden attrs (Consistency, Important Matches, Pressure) |
| Performance | 25% | "Moneyball" metrics (Avg Rating >7.20 = Form Shield) |
| Scarcity | 10% | Spine/left-foot premium |

**Reliability Coefficient**:
$$R_{coef} = 0.4 \times Consistency + 0.3 \times ImportantMatches + 0.3 \times Pressure$$
- Multiplied by $(1 - InjuryPenalty)$
- If $R_{coef} < 0.7$ → "High Risk" flag

**Position-Specific Aging Curves**:
| Position | Peak Start | Peak End | Decline |
|----------|------------|----------|---------|
| GK | 29 | 34 | 35 |
| DC | 27 | 31 | 32 |
| DL/DR | 25 | 29 | 30 |
| DM/MC | 26 | 30 | 32 |
| AM | 24 | 28 | 30 |
| ST | 25 | 29 | 31 |

**30-30-30-10 Wage Structure Rule**:
- Key Players (Top 4): 30% of budget
- First Team (Next 7): 30%
- Rotation (Next 11): 30%
- Youth/Backup: 10%

**Wage Efficiency Thresholds**:
- Ratio > 1.25 → Financially inefficient
- Ratio > 1.50 → "Wage Dump" candidate (urgent)

**Protection Rules**:
1. High PA Youth (≤21, PA ≥150): Protected
2. Key Contributors (Top 15): Protected
3. Recent Signings (<180 days): Protected
4. HGC Quota Critical (<4 HGC): Protected

**Decision Gates (Priority Order)**:
1. **Deadwood**: Low score + no potential → Sell/Release
2. **Financial Burden**: Wage ratio >1.4 → Sell
3. **Peak Sell**: Decline imminent → Sell (asset maximization)
4. **Development Loan**: Age <22, PA >130, below threshold → Loan

**Youth Policy**:
- Age 15-18: KEEP (Club Grown accumulation)
- Age 18+: LOAN if not getting >20 matches/season

**Current Code**: `ui/api/api_player_removal.py`

---

#### Step 9: Match Importance Scoring
- **Status**: COMPLETE
- **Priority**: Medium
- **Prompt File**: `09-PROMPT-match-importance.md`
- **Result File**: `09-RESULTS-match-importance.md`
- **Dependencies**: None
- **Goal**: Automatic importance classification

**Checklist**:
- [x] Prompt document created
- [x] Research executed
- [x] Results uploaded
- [x] Results reviewed
- [x] Classification rules defined
- [x] Step marked complete

**Key Findings - Automated Match Importance Classification System (AMICS)**:

**Final Importance Score (FIS) Formula**:
$$FIS = (Base \times M_{opp} \times M_{sched} \times M_{user}) + B_{context}$$

**Base Importance Table (0-100)**:
| Competition | Stage | Base Score |
|-------------|-------|------------|
| League (Title/Relegation) | Last 10 | 100 |
| League (Contention) | Regular | 80 |
| League (Mid-Table) | Any | 60 |
| League (Dead Rubber) | Last 5 | 20 |
| Champions League | KO (R16+) | 95 |
| Champions League | Group (Open) | 85 |
| Domestic Cup (Major) | SF/Final | 100 |
| Domestic Cup (Major) | Early | 40 |
| Secondary Cup | Late | 70 |
| Secondary Cup | Early | 30 |
| Friendlies | Any | 10 |

**Opponent Strength Modifier (M_opp)**:
| Relative Strength | Classification | Modifier |
|-------------------|----------------|----------|
| > 1.3 | Titan | 1.2x |
| 1.1-1.3 | Superior | 1.1x |
| 0.9-1.1 | Peer | 1.0x |
| 0.6-0.9 | Inferior | 0.8x |
| < 0.6 | Minnow | 0.6x |

**Schedule Context Modifier (M_sched)**:
| Condition | Modifier | Rationale |
|-----------|----------|-----------|
| Next High ≤3 days | 0.7x | 72-hour recovery rule |
| Next High = 4 days | 0.9x | Slight rotation |
| 3rd match in 7 days | 0.8x | ACWR congestion |
| ≥7 days since last | 1.1x | Freshness bonus |

**Contextual Bonuses (B_context)**:
- Rivalry/Derby: +20
- Form Correction (≥3 losses): +15
- Cup Run (QF+ with objective): +10

**FIS Thresholds**:
- **High**: FIS ≥ 85 (Must Win)
- **Medium**: 50 ≤ FIS < 85 (Important)
- **Low**: FIS < 50 (Rotation)
- **Sharpness**: Override when Low AND ≥3 rusty key players

**Sharpness Detection Logic**:
```
is_sharpness = (FIS < 50) AND (rusty_key_players >= 3) AND (sched_mod >= 1.0)
```

**Manager Profiles**:
- "The Architect" (Youth): Cup 0.8x/0.5x
- "The Pragmatist" (Survival): League 1.3x, Cup 0.6x
- "The Glory Hunter" (Cups): Cup 1.2x

---

### Phase 4: Validation & Calibration

#### Step 10: Validation Test Suite
- **Status**: COMPLETE
- **Priority**: High
- **Prompt File**: `10-PROMPT-validation-suite.md`
- **Result File**: `10-RESULTS-validation-suite.md`
- **Dependencies**: Steps 2-6
- **Goal**: Offline evaluation metrics and test cases

**Checklist**:
- [x] Prompt document created
- [x] Research executed
- [x] Results uploaded
- [x] Results reviewed
- [x] Test scenarios defined
- [x] Metrics finalized
- [x] Step marked complete

**Key Findings - Validation Framework:**

**21 Validation Protocols Defined:**

*GSS Component Tests (1-5):*
| Protocol | Focus | Key Metric |
|----------|-------|------------|
| 1 | Specialist vs Generalist | BPS(Specialist) > BPS(Generalist) |
| 2 | Reliability Coefficient | ρ = 1 - (20-Consistency)/40 |
| 3 | Condition Cliff (91% Floor) | Φ(0.91) ≈ 0.68 |
| 4 | Sharpness Seven-Day Cliff | Day 21 sharpness < 75% |
| 5 | Jadedness Step Function | Ω thresholds at 200/400/700 |

*State Propagation Tests (6-8):*
| Protocol | Focus | Key Metric |
|----------|-------|------------|
| 6 | Positional Drag | R_pos(WB)=1.65 vs R_pos(GK)=0.2 |
| 7 | 270-Minute Rule | 2.5x J penalty when exceeded |
| 8 | Holiday vs Rest | 50 pts/day vs 5 pts/day recovery |

*Optimization Engine Tests (9-11):*
| Protocol | Focus | Key Metric |
|----------|-------|------------|
| 9 | Solver Correctness | Global maximum found |
| 10 | Safe Big M | M = 10^6 (no overflow) |
| 11 | Scalarization Weights | Youth Rate monotonic with w₂ |

*Shadow Pricing Tests (12-14):*
| Protocol | Focus | Key Metric |
|----------|-------|------------|
| 12 | Lagrangian Dual | λ extraction via relaxation |
| 13 | Trajectory Bifurcation | ShadowCost > DirectUtility |
| 14 | VORP Scarcity Gap | Correlation r > 0.8 |

*Supporting System Tests (15-21):*
| Protocol | Focus | Key Metric |
|----------|-------|------------|
| 15 | Gap Severity Index | GSI > 0.9 triggers action |
| 16 | Mascherano Protocol | d(DM,CB) << d(ST,CB) |
| 17 | Age Plasticity | 32yo = Rejected |
| 18 | Effective Ability | Role fit > Raw CA |
| 19 | Wage Dump Trigger | Ratio > 1.5 = Urgent |
| 20 | Giant Killing FIS | 40 × 0.6 = 24 → Low |
| 21 | 72-Hour Rule | M_sched = 0.7 when gap ≤ 3 |

**Integration Test Scenarios:**
1. **Christmas Crunch** (5 matches in 13 days):
   - Rotation Index > 0.7
   - Condition Floor Violations = 0
   - No player crosses J=700

2. **Death Spiral Prevention**:
   - System accepts lower ATS over constraint violation
   - Youth call-ups to preserve health

**Key Metrics:**
- **ATS**: Aggregate Team Strength = Σ GSS(p)
- **FVC**: Fatigue Violation Count (Target: 0)
- **RI**: Rotation Index = Unique Starters / Squad Size

**Technical Implementation:**
- Pytest parametrization for curve testing
- PlayerState dataclass with full schema
- Process-based validation (not outcome-based)

**Current Code**: `tests/test_validation_scenarios.py`

---

#### Step 11: Parameter Calibration
- **Status**: COMPLETE
- **Priority**: High
- **Prompt File**: `11-PROMPT-calibration.md`
- **Result File**: `11-RESULTS-calibration.md`
- **Dependencies**: Step 10
- **Goal**: Grid search and sensitivity analysis

**Checklist**:
- [x] Prompt document created
- [x] Research executed
- [x] Results uploaded
- [x] Results reviewed
- [x] Default parameters finalized
- [x] Sensitivity analysis complete
- [x] Step marked complete

**Key Findings - Parameter Calibration Methodology:**

**Three-Phase Calibration Framework:**
1. **Phase 1: Sobol Sensitivity Analysis** - Reduce 50 → 20 critical parameters
2. **Phase 2: BOHB Optimization** - Tune biological parameters efficiently
3. **Phase 3: Rolling Horizon** - Calibrate shadow pricing dynamics

**Parameter Classification:**
| Category | Examples | Nature |
|----------|----------|--------|
| Biological Constraints | Sigmoid k, T | Rigid (physiology) |
| Tactical Variables | Positional drag | Elastic (tunable) |
| Strategic Valuations | Shadow prices, γ | Abstract (OR-derived) |

**Sobol Sensitivity Analysis:**
- Screen criteria: S_Ti < 0.01 → Non-Critical (fix to defaults)
- High S_Ti + Low S_i → Interaction-Dominant (dangerous)
- Requires N(k+2) evaluations (~52,000 for k=50)

**BOHB Algorithm Selection:**
| Method | Verdict | Reason |
|--------|---------|--------|
| Grid Search | Rejected | 5^50 combinations intractable |
| Genetic Algorithms | Rejected | Noisy fitness, local optima |
| **BOHB** | **Selected** | TPE + Hyperband = sample-efficient |

**Proposed Parameter Ranges:**
| Parameter | Symbol | Range | Justification |
|-----------|--------|-------|---------------|
| Sigmoid Steepness | k | 2.0-8.0 | Controls risk "cliff edge" |
| Danger Threshold | T | 1.3-1.8 | Aligns with ACWR danger zone |
| Sharpness Half-life | H_sharp | 5-10 days | Detraining effects |
| Drag (FB→CB) | δ | 0.05-0.15 | Lower intensity move |
| Drag (CB→FB) | δ | 0.20-0.40 | High sprint demand move |
| Discount Factor | γ | 0.85-0.98 | Myopic vs hoarding balance |
| Shadow Convexity | α | 1.5-3.0 | Non-linear fatigue cost |

**AHP Match Importance Weights:**
| Competition | Weight |
|-------------|--------|
| Champions League | 0.50 |
| Domestic League | 0.30 |
| FA Cup | 0.15 |
| League Cup | 0.05 |

**Validation Stress Tests:**
1. **Christmas Crunch**: 4 games in 10 days → must use >18 unique starters
2. **Death Spiral**: Cascade injuries → must prefer youth over OOP seniors

**Rolling Horizon Shadow Pricing:**
$$\lambda_{i,t} = f(\text{Importance}_t, \text{Scarcity}_i, \text{FutureLoad}_i)$$
- γ → 0: Myopic (play best XI now)
- γ → 1: Hoarding (rest stars excessively)
- Target: Match elite manager rotation frequency

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
| 7 | Yes | Yes | `07-RESULTS-training-recommender.md` | Yes | Yes |
| 8 | Yes | Yes | `08-RESULTS-player-removal.md` | Yes | Yes |
| 9 | Yes | Yes | `09-RESULTS-match-importance.md` | Yes | Yes |
| 10 | Yes | Yes | `10-RESULTS-validation-suite.md` | Yes | Yes |
| 11 | Yes | Yes | `11-RESULTS-calibration.md` | Yes | Yes |
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
| 2025-12-29 | 7 | Step 7 COMPLETE | PTRE architecture, GSI formula, age plasticity, difficulty classes |
| 2025-12-29 | - | Prompts 10, 11 updated | Added position training tests, calibration parameters |
| 2025-12-29 | 8 | Step 8 COMPLETE | Player removal model, contribution score, aging curves, wage structure |
| 2025-12-29 | - | Prompts 10, 11 updated | Added removal decision tests, financial calibration parameters |
| 2025-12-29 | 9 | Step 9 COMPLETE - PHASE 3 DONE | AMICS system, FIS formula, base importance table, modifiers |
| 2025-12-29 | - | Prompts 10, 11 updated | Added match importance tests, manager profiles, FIS calibration |
| 2025-12-30 | 10 | Step 10 COMPLETE | 21 validation protocols, integration tests, pytest framework |
| 2025-12-30 | - | Prompt 11 updated | Added validation-derived calibration recommendations |
| 2025-12-30 | 11 | Step 11 COMPLETE - PHASE 4 DONE | Sobol GSA, BOHB optimization, Rolling Horizon shadow pricing |

---

*Last Updated: 2025-12-30*
