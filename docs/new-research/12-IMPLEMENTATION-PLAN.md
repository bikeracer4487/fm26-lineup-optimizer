# Implementation Plan: Code Changes from Research

## Overview

This document translates the research findings from Steps 1-11 into staged code changes for the FM26 Lineup Optimizer.

**Status**: FINALIZED
**Research Program**: COMPLETE (11/11 steps)
**Last Updated**: 2025-12-30

---

## Implementation Principles

### 1. Minimal Risk Changes
- One component at a time
- Keep old code until new code is validated
- Feature flags for gradual rollout

### 2. Backward Compatibility
- Don't break existing functionality
- Preserve user data formats
- Provide migration paths

### 3. Testing First
- Write tests before code changes
- Validate against test scenarios from Step 10
- Regression test everything

### 4. Documentation Updates
- Update CLAUDE.md with final specifications
- Remove conflicting documentation (FM26 #1-4 docs)
- Keep single source of truth

---

## Research Summary: Key Findings by Step

### Step 1: FM26 Game Mechanics
- Condition: 0-10,000 internal scale, 92% = Match Fit, 95% = Peak
- Sharpness: "Seven-Day Cliff" - 5-8%/day decay after 7 days
- Jadedness: Only "Holiday" clears it (50 pts/day vs 5 pts/day for Rest)
- Physical attributes (Pace/Accel): 1.25-1.5x weight in match engine

### Step 2: Unified Scoring Model (GSS)
```
GSS = BPS × Φ(C) × Ψ(S) × Θ(F) × Ω(J)
```
- Condition Φ(c): `1 / (1 + e^{-25(c - 0.88)})` - STEEP sigmoid
- Sharpness Ψ(s): `1.02 / (1 + e^{-15(s - 0.75)}) - 0.02` - bounded sigmoid
- Familiarity Θ(f): `0.7 + 0.3f` - LINEAR (not sigmoid!)
- Fatigue Ω(J): Step function [Fresh=1.0, Fit=0.9, Tired=0.7, Jaded=0.4]

**Critical Rules**:
- 91% Condition Floor: Never start player < 91%
- 85% Sharpness Gate: Build sharpness with U21/reserves first
- 270-Minute Rule: >270 min in 14 days → 0.85 penalty

### Step 3: State Propagation
**Positional Drag Coefficients (R_pos)**:
| Position | R_pos | Rotation Need |
|----------|-------|---------------|
| GK | 0.20 | Almost none |
| CB | 0.95 | Can play consecutive |
| DM | 1.15 | Moderate |
| CM (B2B) | 1.45 | High |
| AMC | 1.35 | High |
| Winger | 1.40 | High |
| **FB/WB** | **1.65** | **100% rotation** |

**Recovery Equation**:
```
C_{k+1} = C_k + (10000 - C_k) × β × (Natural_Fitness)^γ × (1 - J_penalty)
```

### Step 4: Hungarian Matrix Architecture
- Two-stage algorithm: Stage 1 (Starting XI), Stage 2 (Bench)
- Safe Big M = 10^6 (not infinity - causes SciPy errors)
- Multi-objective scalarization weights by scenario

| Scenario | w_perf | w_dev | w_rest |
|----------|--------|-------|--------|
| Cup Final | 1.0 | 0.0 | 0.0 |
| League Grind | 0.6 | 0.1 | 0.3 |
| Dead Rubber | 0.2 | 0.5 | 0.3 |

### Step 5: Shadow Pricing
**Shadow Cost Formula**:
```
λ_{p,t} = S_p^{VORP} × Σ_{k=t+1}^{T} (γ^{k-t} × I_k × max(0, ΔGSS_{p,k}))
```

**Parameters**:
| Parameter | Default | Range |
|-----------|---------|-------|
| γ (discount) | 0.85 | 0.70-0.95 |
| λ_shadow | 1.0 | 0.0-2.0 |
| λ_V (scarcity) | 2.0 | 1.0-3.0 |

**VORP Scarcity Index**:
```
α_scarcity = 1 + λ_V × min(0.5, (GSS_star - GSS_backup) / GSS_star)
```

**Importance Weights**:
| Scenario | Weight |
|----------|--------|
| Cup Final | 10.0 |
| Continental KO | 5.0 |
| Title Rival | 3.0 |
| Standard League | 1.5 |
| Cup Early | 0.8 |
| Dead Rubber | 0.1 |

### Step 6: Fatigue Dynamics & Rest Policy
**Jadedness Thresholds (0-1000 scale)**:
| State | J Range | Ω Multiplier |
|-------|---------|--------------|
| Fresh | 0-200 | 1.00 |
| Match Fit | 201-400 | 0.90 |
| Tired | 401-700 | 0.70 |
| Jaded | 701+ | 0.40 |

**Holiday Protocol**: When "Rst" icon appears → Training → Rest → Holiday (1 Week)

**Player Archetypes**:
| Archetype | Profile | Policy |
|-----------|---------|--------|
| Workhorse | NF 15+, Sta 15+ | Holiday every 15 matches |
| Glass Cannon | Inj Prone >12, NF <12 | Cap 180 mins/14d, sub at 60' |
| Veteran (30+) | Age >30 | One game per week max |
| Youngster (<19) | Age <19 | Limit 20-25 senior starts/season |

### Step 7: Position Training Recommender
**Gap Severity Index (GSI)**:
```
GSI = (Scarcity_pos × Weight_pos) + InjuryRisk_starter + ScheduleDensity
```

**Candidate Selection - Euclidean Distance**:
```
Distance(P, R) = sqrt(Σ w_i × (A_{P,i} - A_{R,i})^2)
```

**Age/Plasticity Factors**:
| Age | Plasticity | Strategy |
|-----|------------|----------|
| 16-21 | 1.0 | Radical conversions OK |
| 22-26 | 0.7 | Adjacent moves only |
| 27-31 | 0.4 | Career extension roles |
| 32+ | 0.1 | Emergency swaps only |

**Difficulty Classes**:
| Class | Time | Examples |
|-------|------|----------|
| I (Fluid) | 4-8 weeks | LB→LWB, DM→MC |
| II (Structural) | 12-20 weeks | DM→CB, AMC→ST |
| III (Spatial) | 24-36 weeks | AMR→MC, ST→AMR |
| IV (Inversion) | 52+ weeks | ST→DR, MC→GK |

### Step 8: Player Removal Model
**Contribution Score (0-100)**:
| Component | Weight |
|-----------|--------|
| Effective Ability | 45% |
| Performance | 25% |
| Reliability | 20% |
| Scarcity | 10% |

**Position-Specific Aging Curves**:
| Position | Peak Start | Peak End | Decline |
|----------|------------|----------|---------|
| GK | 29 | 34 | 35 |
| DC | 27 | 31 | 32 |
| DL/DR | 25 | 29 | 30 |
| DM/MC | 26 | 30 | 32 |
| AM | 24 | 28 | 30 |
| ST | 25 | 29 | 31 |

**30-30-30-10 Wage Structure**:
- Key Players (Top 4): 30%
- First Team (Next 7): 30%
- Rotation (Next 11): 30%
- Youth/Backup: 10%

### Step 9: Match Importance Scoring (AMICS)
**FIS Formula**:
```
FIS = (Base × M_opp × M_sched × M_user) + B_context
```

**Base Importance Table**:
| Competition | Stage | Base |
|-------------|-------|------|
| League (Title/Rel) | Last 10 | 100 |
| Champions League | KO (R16+) | 95 |
| League (Contention) | Regular | 80 |
| Domestic Cup (Major) | SF/Final | 100 |
| League (Mid-Table) | Any | 60 |
| Friendlies | Any | 10 |

**Opponent Modifier (M_opp)**:
| Relative Strength | Modifier |
|-------------------|----------|
| Titan (>1.3) | 1.2x |
| Superior (1.1-1.3) | 1.1x |
| Peer (0.9-1.1) | 1.0x |
| Inferior (0.6-0.9) | 0.8x |
| Minnow (<0.6) | 0.6x |

**Schedule Modifier (M_sched)**:
| Condition | Modifier |
|-----------|----------|
| Next High ≤3 days | 0.7x |
| 3rd match in 7 days | 0.8x |
| ≥7 days since last | 1.1x |

### Step 10: Validation Test Suite
**21 Validation Protocols** covering:
- GSS components (5 tests)
- State propagation (3 tests)
- Optimization engine (3 tests)
- Shadow pricing (3 tests)
- Supporting systems (7 tests)

**Key Metrics**:
- ATS: Aggregate Team Strength = Σ GSS(p)
- FVC: Fatigue Violation Count (Target: 0)
- RI: Rotation Index = Unique Starters / Squad Size

**Integration Tests**:
- Christmas Crunch: 5 matches in 13 days
- Death Spiral Prevention: Cascade injury response

### Step 11: Parameter Calibration
**Three-Phase Framework**:
1. Sobol Sensitivity Analysis: Reduce 50 → 20 critical parameters
2. BOHB Optimization: Tune biological parameters efficiently
3. Rolling Horizon: Calibrate shadow pricing dynamics

**Final Parameter Ranges**:
| Parameter | Symbol | Range |
|-----------|--------|-------|
| Sigmoid Steepness | k | 2.0-8.0 |
| Danger Threshold | T | 1.3-1.8 |
| Sharpness Half-life | H_sharp | 5-10 days |
| Discount Factor | γ | 0.85-0.98 |

---

## Code Files Affected

### Core Algorithm Files

| File | Changes | Source |
|------|---------|--------|
| `scoring_parameters.py` | Update all parameter values | Steps 2, 11 |
| `ui/api/scoring_model.py` | Replace sigmoid formulas | Step 2 |
| `ui/api/state_simulation.py` | Add R_pos, calibrate rates | Step 3 |
| `ui/api/shadow_pricing.py` | Implement VORP formula | Step 5 |
| `ui/api/stability.py` | Add switching costs | Step 4 |

### Supporting System Files

| File | Changes | Source |
|------|---------|--------|
| `ui/api/api_match_selector.py` | Two-stage Hungarian, Big M=10^6 | Step 4 |
| `ui/api/api_training_advisor.py` | GSI, Euclidean distance, plasticity | Step 7 |
| `ui/api/api_player_removal.py` | Contribution score, aging curves | Step 8 |
| `ui/api/api_rest_advisor.py` | Holiday Protocol, archetypes | Step 6 |
| `ui/api/match_importance.py` (NEW) | AMICS, FIS formula | Step 9 |

### Test Files

| File | Status | Source |
|------|--------|--------|
| `tests/test_validation_scenarios.py` | Update with 21 protocols | Step 10 |
| `tests/test_scoring_model.py` | Add multiplier tests | Step 2 |
| `tests/test_state_simulation.py` | Add propagation tests | Step 3 |
| `tests/calibration_harness.py` (NEW) | BOHB runner | Step 11 |

---

## Staged Implementation Plan

### Stage 1: Parameter Consolidation
**Source**: Steps 2, 11

**Changes to `scoring_parameters.py`**:
```python
# Condition Multiplier (Step 2)
CONDITION_SIGMOID_K = 25
CONDITION_SIGMOID_C0 = 0.88

# Sharpness Multiplier (Step 2)
SHARPNESS_SIGMOID_K = 15
SHARPNESS_SIGMOID_S0 = 0.75

# Familiarity - LINEAR not sigmoid! (Step 2)
FAMILIARITY_FLOOR = 0.7
FAMILIARITY_SLOPE = 0.3

# Fatigue Step Function Thresholds (Step 2)
JADEDNESS_THRESHOLDS = {
    'fresh': (0, 200),      # Ω = 1.0
    'fit': (201, 400),      # Ω = 0.9
    'tired': (401, 700),    # Ω = 0.7
    'jaded': (701, 1000)    # Ω = 0.4
}

# Condition Floor (Step 2)
CONDITION_FLOOR = 0.91  # Never start below 91%

# Shadow Pricing (Step 5)
SHADOW_DISCOUNT_GAMMA = 0.85
SHADOW_WEIGHT = 1.0
VORP_SCARCITY_LAMBDA = 2.0

# Importance Weights (Step 5)
IMPORTANCE_WEIGHTS = {
    'cup_final': 10.0,
    'continental_ko': 5.0,
    'title_rival': 3.0,
    'league_standard': 1.5,
    'cup_early': 0.8,
    'dead_rubber': 0.1
}
```

**Validation**: All existing tests pass

---

### Stage 2: Scoring Model Updates
**Source**: Step 2

**Changes to `ui/api/scoring_model.py`**:
```python
def condition_multiplier(condition: float) -> float:
    """
    Steep sigmoid - from Step 2 research.
    k=25, c0=0.88 (88% threshold)
    """
    k = CONDITION_SIGMOID_K  # 25
    c0 = CONDITION_SIGMOID_C0  # 0.88
    return 1 / (1 + math.exp(-k * (condition - c0)))

def sharpness_multiplier(sharpness: float) -> float:
    """
    Bounded sigmoid - from Step 2 research.
    k=15, s0=0.75, bounds to prevent negative values
    """
    k = SHARPNESS_SIGMOID_K  # 15
    s0 = SHARPNESS_SIGMOID_S0  # 0.75
    return 1.02 / (1 + math.exp(-k * (sharpness - s0))) - 0.02

def familiarity_multiplier(familiarity: float) -> float:
    """
    LINEAR function - NOT sigmoid!
    From Step 2 research: Θ(f) = 0.7 + 0.3f
    """
    return FAMILIARITY_FLOOR + FAMILIARITY_SLOPE * familiarity

def fatigue_multiplier(jadedness: int) -> float:
    """
    Step function with discrete states.
    From Step 2/Step 6 research.
    """
    if jadedness <= 200:
        return 1.0  # Fresh
    elif jadedness <= 400:
        return 0.9  # Match Fit
    elif jadedness <= 700:
        return 0.7  # Tired
    else:
        return 0.4  # Jaded
```

**Validation**: Compare outputs to worked examples from Step 2

---

### Stage 3: State Simulation Calibration
**Source**: Step 3

**Changes to `ui/api/state_simulation.py`**:
```python
# Positional Drag Coefficients (Step 3)
R_POS = {
    'GK': 0.20,
    'CB': 0.95,
    'DC': 0.95,
    'DM': 1.15,
    'CM': 1.45,
    'MC': 1.45,
    'AMC': 1.35,
    'AM': 1.35,
    'AML': 1.40,
    'AMR': 1.40,
    'Winger': 1.40,
    'ST': 1.40,
    'STC': 1.40,
    'DL': 1.65,
    'DR': 1.65,
    'FB': 1.65,
    'WB': 1.65,
    'WBL': 1.65,
    'WBR': 1.65,
}

# 270-Minute Rule (Step 3)
MINUTES_WINDOW_DAYS = 14  # Not 10!
MINUTES_THRESHOLD = 270
JADEDNESS_PENALTY_MULTIPLIER = 2.5  # When threshold exceeded

# Sharpness Decay (Step 3 - Seven-Day Cliff)
SHARPNESS_DECAY_RATES = {
    'day_0_3': 0.0,      # No decay
    'day_4_6': 0.015,    # ~1.5%/day
    'day_7_plus': 0.065  # ~6.5%/day (cliff)
}
```

**Validation**: Multi-match trajectory tests

---

### Stage 4: Hungarian Matrix Refactoring
**Source**: Step 4

**Changes to `ui/api/api_match_selector.py`**:
```python
# Safe Big M (Step 4)
BIG_M = 1e6  # Not infinity!

# Multi-objective weights by scenario
SCENARIO_WEIGHTS = {
    'cup_final': {'perf': 1.0, 'dev': 0.0, 'rest': 0.0},
    'league_grind': {'perf': 0.6, 'dev': 0.1, 'rest': 0.3},
    'dead_rubber': {'perf': 0.2, 'dev': 0.5, 'rest': 0.3},
}

# Condition Cliff (Step 4)
CONDITION_CLIFF = {
    'peak': (0.95, 1.00),      # ≥95%
    'startable': (0.90, 0.94), # 0.95 multiplier
    'risk': (0.80, 0.89),      # 0.80 multiplier
    'danger': (0.75, 0.79),    # 0.50 multiplier
    'forbidden': (0.0, 0.74),  # BIG_M penalty
}
```

**Validation**: All constraint scenarios pass

---

### Stage 5: Shadow Pricing Revision
**Source**: Step 5

**Changes to `ui/api/shadow_pricing.py`**:
```python
def calculate_vorp_scarcity(gss_star: float, gss_backup: float) -> float:
    """
    VORP Scarcity Index - from Step 5 research.
    Gap% > 10% means player is "Key"
    """
    if gss_star <= 0:
        return 1.0
    gap_pct = (gss_star - gss_backup) / gss_star
    return 1 + VORP_SCARCITY_LAMBDA * min(0.5, gap_pct)

def calculate_shadow_cost(
    player_id: str,
    current_match: int,
    future_matches: list,
    gss_if_play: list,
    gss_if_rest: list
) -> float:
    """
    Shadow Cost Formula - from Step 5 research.
    λ_{p,t} = S_p^{VORP} × Σ_{k=t+1}^{T} (γ^{k-t} × I_k × max(0, ΔGSS_{p,k}))
    """
    vorp = calculate_vorp_scarcity(...)
    shadow_cost = 0.0

    for k, match in enumerate(future_matches):
        time_discount = SHADOW_DISCOUNT_GAMMA ** (k + 1)
        importance = get_importance_weight(match)
        delta_gss = max(0, gss_if_rest[k] - gss_if_play[k])
        shadow_cost += time_discount * importance * delta_gss

    return vorp * shadow_cost
```

**Validation**: Cup Final Protection scenario passes

---

### Stage 6: Fatigue & Rest Policy
**Source**: Step 6

**Changes to `ui/api/api_rest_advisor.py`**:
```python
# Player Archetypes (Step 6)
def classify_archetype(player: dict) -> str:
    age = player['age']
    natural_fitness = player.get('natural_fitness', 10)
    stamina = player.get('stamina', 10)
    injury_prone = player.get('injury_proneness', 10)

    if age >= 30:
        return 'veteran'
    elif age < 19:
        return 'youngster'
    elif natural_fitness >= 15 and stamina >= 15:
        return 'workhorse'
    elif injury_prone > 12 or natural_fitness < 12:
        return 'glass_cannon'
    else:
        return 'standard'

# Rest Policy Thresholds (Step 6)
ARCHETYPE_POLICIES = {
    'workhorse': {'holiday_every': 15, 'max_mins_14d': 360},
    'glass_cannon': {'max_mins_14d': 180, 'sub_at_minute': 60},
    'veteran': {'max_matches_per_week': 1},
    'youngster': {'max_senior_starts_season': 25},
    'standard': {'max_mins_14d': 270},
}

# Holiday Protocol (Step 6)
def needs_holiday(jadedness: int, has_rst_icon: bool) -> bool:
    """
    Holiday clears ~50 J points/day (vs 5 for Rest).
    Required when jadedness > 400 or "Rst" icon appears.
    """
    return jadedness > 400 or has_rst_icon
```

**Validation**: Jadedness prevention scenarios

---

### Stage 7: Training Recommender
**Source**: Step 7

**Changes to `ui/api/api_training_advisor.py`**:
```python
# Age Plasticity (Step 7)
AGE_PLASTICITY = {
    (16, 21): 1.0,   # High - radical conversions OK
    (22, 26): 0.7,   # Medium - adjacent moves only
    (27, 31): 0.4,   # Low - career extension roles
    (32, 99): 0.1,   # Minimal - emergency only
}

# Difficulty Classes (Step 7)
RETRAINING_DIFFICULTY = {
    'I': {'weeks': (4, 8), 'examples': ['LB→LWB', 'DM→MC']},
    'II': {'weeks': (12, 20), 'examples': ['DM→CB', 'AMC→ST']},
    'III': {'weeks': (24, 36), 'examples': ['AMR→MC', 'ST→AMR']},
    'IV': {'weeks': (52, 999), 'examples': ['ST→DR', 'MC→GK']},
}

def calculate_gap_severity_index(
    position: str,
    scarcity: float,
    starter_injury_risk: float,
    schedule_density: float
) -> float:
    """
    GSI = (Scarcity × Weight) + InjuryRisk + ScheduleDensity
    From Step 7 research.
    """
    weight = POSITION_WEIGHTS.get(position, 1.0)
    return (scarcity * weight) + starter_injury_risk + schedule_density
```

**Validation**: Training recommendations are sensible

---

### Stage 8: Player Removal Model
**Source**: Step 8

**Changes to `ui/api/api_player_removal.py`**:
```python
# Contribution Score Weights (Step 8)
CONTRIBUTION_WEIGHTS = {
    'effective_ability': 0.45,
    'performance': 0.25,
    'reliability': 0.20,
    'scarcity': 0.10,
}

# Position Aging Curves (Step 8)
AGING_CURVES = {
    'GK': {'peak_start': 29, 'peak_end': 34, 'decline': 35},
    'DC': {'peak_start': 27, 'peak_end': 31, 'decline': 32},
    'DL': {'peak_start': 25, 'peak_end': 29, 'decline': 30},
    'DR': {'peak_start': 25, 'peak_end': 29, 'decline': 30},
    'DM': {'peak_start': 26, 'peak_end': 30, 'decline': 32},
    'MC': {'peak_start': 26, 'peak_end': 30, 'decline': 32},
    'AM': {'peak_start': 24, 'peak_end': 28, 'decline': 30},
    'ST': {'peak_start': 25, 'peak_end': 29, 'decline': 31},
}

# Wage Efficiency Thresholds (Step 8)
WAGE_EFFICIENCY_THRESHOLDS = {
    'inefficient': 1.25,
    'wage_dump': 1.50,  # Urgent
}
```

**Validation**: Removal recommendations protect critical players

---

### Stage 9: Match Importance Automation
**Source**: Step 9

**New File: `ui/api/match_importance.py`**:
```python
# Base Importance Table (Step 9)
BASE_IMPORTANCE = {
    ('league', 'title_race'): 100,
    ('league', 'contention'): 80,
    ('league', 'mid_table'): 60,
    ('league', 'dead_rubber'): 20,
    ('champions_league', 'knockout'): 95,
    ('champions_league', 'group'): 85,
    ('domestic_cup', 'final'): 100,
    ('domestic_cup', 'early'): 40,
    ('friendly', 'any'): 10,
}

# Opponent Modifiers (Step 9)
OPPONENT_MODIFIERS = {
    'titan': 1.2,      # > 1.3 relative strength
    'superior': 1.1,   # 1.1-1.3
    'peer': 1.0,       # 0.9-1.1
    'inferior': 0.8,   # 0.6-0.9
    'minnow': 0.6,     # < 0.6
}

# Schedule Modifiers (Step 9)
SCHEDULE_MODIFIERS = {
    'next_high_3_days': 0.7,
    'next_high_4_days': 0.9,
    '3rd_match_in_7_days': 0.8,
    'fresh_7_plus_days': 1.1,
}

# Contextual Bonuses (Step 9)
CONTEXT_BONUSES = {
    'rivalry': 20,
    'form_correction': 15,  # ≥3 consecutive losses
    'cup_run': 10,          # QF+ with objective
}

def calculate_fis(
    competition: str,
    stage: str,
    opponent_strength: float,
    schedule_context: str
) -> float:
    """
    FIS = (Base × M_opp × M_sched × M_user) + B_context
    From Step 9 research.
    """
    base = BASE_IMPORTANCE.get((competition, stage), 50)
    m_opp = classify_opponent(opponent_strength)
    m_sched = SCHEDULE_MODIFIERS.get(schedule_context, 1.0)
    return base * m_opp * m_sched
```

**Validation**: Importance suggestions match expectations

---

### Stage 10: Validation Suite
**Source**: Step 10

**Changes to `tests/test_validation_scenarios.py`**:
- Implement all 21 validation protocols
- Add ATS/FVC/RI metric calculations
- Add Christmas Crunch integration test
- Add Death Spiral prevention test

---

### Stage 11: Parameter Calibration Execution
**Source**: Step 11

**New File: `tests/calibration_harness.py`**:
- Implement Sobol sensitivity analysis
- Implement BOHB optimization loop
- Run calibration on parameter ranges from Step 11

---

### Stage 12: Documentation & Cleanup
**Final cleanup tasks**:
1. Update CLAUDE.md with final specifications
2. Archive old research documents (FM26 #1-4)
3. Remove conflicting parameter definitions
4. Update README if needed

---

## Pull Request Strategy

### PR 1: Parameter Foundation
**Stages**: 1
**Files**: `scoring_parameters.py`
**Risk**: Low

### PR 2: Scoring Model
**Stages**: 2, 3
**Files**: `scoring_model.py`, `state_simulation.py`
**Risk**: Medium

### PR 3: Assignment Matrix
**Stages**: 4, 5
**Files**: `api_match_selector.py`, `shadow_pricing.py`
**Risk**: Medium-High

### PR 4: Support Systems
**Stages**: 6, 7, 8, 9
**Files**: `api_rest_advisor.py`, `api_training_advisor.py`, `api_player_removal.py`, `match_importance.py`
**Risk**: Low

### PR 5: Validation & Calibration
**Stages**: 10, 11
**Files**: `test_validation_scenarios.py`, `calibration_harness.py`
**Risk**: Low

### PR 6: Documentation
**Stage**: 12
**Files**: `CLAUDE.md`, various
**Risk**: None

---

## Rollback Plan

If issues are discovered after deployment:

1. **Immediate**: Revert to previous parameter values
2. **Short-term**: Feature flag to disable new code path
3. **Medium-term**: Investigate root cause, fix, re-deploy

### Feature Flags

```python
FEATURE_FLAGS = {
    'use_new_scoring_model': True,
    'use_calibrated_params': True,
    'new_shadow_pricing': True,
    'new_rest_policy': True,
    'use_amics': True,
}
```

---

## Progress Tracking

| Stage | Status | Notes |
|-------|--------|-------|
| 1 | Complete | Parameters in `scoring_parameters.py` |
| 2 | Complete | Formulas in `scoring_model.py` |
| 3 | Complete | R_pos in `state_simulation.py` |
| 4 | Complete | Algorithm in `api_match_selector.py` |
| 5 | Complete | VORP in `shadow_pricing.py` |
| 6 | Complete | Archetypes in `api_rest_advisor.py` |
| 7 | Complete | GSI in `api_training_advisor.py` |
| 8 | Complete | Aging curves in `api_player_removal.py` |
| 9 | Complete | AMICS in `match_importance.py` |
| 10 | **IMPLEMENTED** | 91 tests in `test_validation_scenarios.py` |
| 11 | **IMPLEMENTED** | 43 tests in `calibration_harness.py` |
| 12 | **COMPLETE** | CLAUDE.md updated, old docs archived |

---

## Post-Implementation Monitoring

After all changes are deployed:

1. **User Feedback**: Collect reports of unexpected selections
2. **Performance Metrics**: Track computation time
3. **Regression Watch**: Monitor for any issues
4. **Parameter Tuning**: Adjust based on real-world usage

---

*Status: FINALIZED*
*Research Program: COMPLETE*
*Last Updated: 2025-12-30*
