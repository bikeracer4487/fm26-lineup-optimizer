# Research Prompt 11: Parameter Calibration Methodology

## Context

Our scoring model has 20+ tunable parameters across multiplier functions. Without systematic calibration, we're guessing at values. This research defines how to find optimal parameters.

## CRITICAL: Step 2 Findings Override Previous Assumptions

Step 2 research has FINALIZED the multiplier formulas. The calibration task is now significantly simpler because:

1. **Condition**: Uses steep sigmoid (k=25, T=0.88) - FIXED
2. **Sharpness**: Uses bounded sigmoid (k=15, T=0.75) - FIXED
3. **Familiarity**: Is LINEAR (Θ = 0.7 + 0.3f) - NO k/T parameters to calibrate
4. **Fatigue**: Is a STEP FUNCTION - NO continuous parameters to calibrate

### Parameters Remaining for Calibration

**Condition Multiplier** (may vary by importance):
- k_condition: Step 2 suggests 25, but may vary by importance (High: 25, Low: 15?)
- T_condition: Step 2 suggests 0.88, but High importance might tolerate lower

**Sharpness Multiplier** (may vary by importance):
- k_sharpness: Step 2 suggests 15
- T_sharpness: Step 2 suggests 0.75

**Familiarity Multiplier** - FIXED:
- Linear formula: Θ = 0.7 + 0.3f
- No importance-level variation needed

**Fatigue Multiplier** - STEP FUNCTION:
- Fresh: 1.0, Match Fit: 0.9, Tired: 0.7, Jaded: 0.4
- May want to calibrate the 270-minute threshold

**Positional Drag Coefficients (NEW from Step 3)**:
| Position | R_pos | Calibration Range |
|----------|-------|-------------------|
| GK | 0.2 | 0.1 - 0.3 |
| CB | 0.95 | 0.8 - 1.1 |
| DM | 1.15 | 1.0 - 1.3 |
| CM (B2B) | 1.45 | 1.3 - 1.6 |
| AMC | 1.35 | 1.2 - 1.5 |
| Winger | 1.40 | 1.25 - 1.55 |
| Fullback/WB | **1.65** | 1.5 - 1.8 |

**Sharpness Decay Model (Step 3)**:
- Cliff threshold: Day 7 (calibrate range: 5-9 days)
- Pre-cliff decay: 1-2%/day
- Post-cliff decay: 5-8%/day

**Fatigue/Jadedness Model (CALIBRATED from Step 6)**:

*Jadedness Thresholds (0-1000 scale)*:
| State | J Range | Ω Multiplier | Calibration Range |
|-------|---------|--------------|-------------------|
| Fresh | 0-200 | 1.00 | FIXED |
| Match Fit | 201-400 | 0.90 | 0.88-0.92 |
| Tired | 401-700 | 0.70 | 0.65-0.75 |
| Jaded | 701+ | 0.40 | 0.35-0.45 |

*Recovery Rates*:
| Recovery Type | Points/Day | Calibration Range |
|---------------|------------|-------------------|
| Holiday | 50 | 40-60 |
| Rest at Club | 5 | 3-8 |
| Training (Half) | 3 | 2-5 |
| Training (Double) | -10 | -15 to -5 |

*Archetype Thresholds (NEW from Step 6)*:
| Archetype | Minute Cap (14d) | Calibration Range |
|-----------|------------------|-------------------|
| Standard | 270 | FIXED |
| Glass Cannon | 180 | 150-210 |
| Veteran (30+) | 180 | 150-210 |
| Workhorse | 360 | 300-400 |

*Training Integration*:
- Death Spiral Threshold: 2 matches/week + Double Intensity
- Auto-switch to Half when Condition < 90% (calibrate: 85-95%)

**Shadow Pricing (CALIBRATED from Step 5)**:
- γ (discount factor): Default 0.85, Range 0.70-0.95
- λ_shadow (weight): Default 1.0, Range 0.5-2.0
- λ_V (scarcity scaling): Default 2.0, Range 1.0-3.0

**Importance Weights (from Step 5 - May Calibrate)**:
| Scenario | Default | Range | Notes |
|----------|---------|-------|-------|
| Cup Final | 10.0 | 8.0-12.0 | Highest priority |
| Continental KO | 5.0 | 4.0-6.0 | High leverage |
| Title Rival | 3.0 | 2.5-4.0 | "Six-pointer" |
| Standard League | 1.5 | 1.0-2.0 | Baseline |
| Cup (Early) | 0.8 | 0.5-1.0 | Low leverage |
| Dead Rubber | 0.1 | 0.05-0.2 | Negligible |

**Stability**:
- inertia_weight: 1 value
- base_switch_cost: 1 value
- continuity_bonus: 1 value

**REST Slots**:
- α, β, γ, δ coefficients: 4 × 4 = 16 values

**Multi-Objective Scalarization Weights (NEW from Step 4)**:
| Scenario | w1 (Perf) | w2 (Dev) | w3 (Rest) | Calibration Range |
|----------|-----------|----------|-----------|-------------------|
| Cup Final | 1.0 | 0.0 | 0.0 | FIXED |
| League Grind | 0.6 | 0.1 | 0.3 | w1: 0.5-0.7, w3: 0.2-0.4 |
| Dead Rubber | 0.2 | 0.5 | 0.3 | w2: 0.4-0.6 |
| Youth Cup | 0.3 | 0.7 | 0.0 | w2: 0.6-0.8 |

**Switching Costs (NEW from Step 4)**:
- Position change penalty: Calibrate range 0.02-0.10 (% utility loss)

**Position Training (CALIBRATED from Step 7)**:

*Age Plasticity Factors*:
| Age Bracket | Plasticity | Calibration Range | Strategy |
|-------------|------------|-------------------|----------|
| 16-21 | 1.0 | FIXED | Radical conversions OK |
| 22-26 | 0.7 | 0.6-0.8 | Adjacent moves only |
| 27-31 | 0.4 | 0.3-0.5 | Career extension roles |
| 32+ | 0.1 | 0.05-0.15 | Emergency swaps only |

*Familiarity Efficiency Thresholds (0-20 scale)*:
| Status | Range | Efficiency | Calibration Range |
|--------|-------|------------|-------------------|
| Natural | 18-20 | 1.00 | FIXED |
| Accomplished | 15-17 | 0.95 | 0.93-0.97 |
| Competent | 12-14 | 0.85 | 0.80-0.90 |
| Unconvincing | 9-11 | 0.70 | 0.65-0.75 |
| Awkward | 5-8 | 0.50 | 0.45-0.55 |

*Retraining Timeline (Weeks to Accomplished)*:
| Difficulty Class | Base Time | Calibration Range | Examples |
|------------------|-----------|-------------------|----------|
| I (Fluid) | 6 | 4-8 | LB→LWB, DM→MC |
| II (Structural) | 16 | 12-20 | DM→CB, AMC→ST |
| III (Spatial) | 30 | 24-36 | AMR→MC, ST→AMR |
| IV (Inversion) | ∞ | REJECT | ST→DR, MC→GK |

*Retraining Efficiency Ratio (RER) Thresholds*:
| RER Score | Decision | Calibration Range |
|-----------|----------|-------------------|
| > 0.8 | Recommend | 0.75-0.85 |
| 0.5-0.8 | Conditional | Fixed |
| < 0.5 | Reject | 0.45-0.55 |

*Strategic Archetype Attribute Thresholds*:
| Archetype | Key Attributes | Minimum Value | Calibration Range |
|-----------|----------------|---------------|-------------------|
| Mascherano (DM→CB) | Tackling, Anticipation, JR | 14, 13, 12 | ±1 each |
| Lahm (FB→DM) | Decisions, Teamwork, Composure | 15, 14, 13 | ±1 each |
| Firmino (AMC→ST) | Work Rate, Technique, OtB | 14, 13, 13 | ±1 each |

**Player Removal Model (CALIBRATED from Step 8)**:

*Contribution Score Component Weights*:
| Component | Default Weight | Calibration Range | Notes |
|-----------|----------------|-------------------|-------|
| Effective Ability | 0.45 | 0.40-0.50 | Role-weighted, not raw CA |
| Reliability | 0.20 | 0.15-0.25 | Hidden attributes impact |
| Performance | 0.25 | 0.20-0.30 | Moneyball metrics |
| Scarcity | 0.10 | 0.05-0.15 | Position rarity |

*Reliability Coefficient Weights*:
| Hidden Attribute | Weight | Calibration Range |
|------------------|--------|-------------------|
| Consistency | 0.40 | 0.35-0.45 |
| Important Matches | 0.30 | 0.25-0.35 |
| Pressure | 0.30 | 0.25-0.35 |

*Reliability Threshold*:
| Threshold | Default | Calibration Range | Implication |
|-----------|---------|-------------------|-------------|
| High Risk | 0.70 | 0.65-0.75 | Below this = "High Risk" flag |

*Form Shield Threshold*:
| Metric | Default | Calibration Range |
|--------|---------|-------------------|
| Avg Rating | 7.20 | 7.00-7.40 |
| Min Matches | 20 | 15-25 |

*Position-Specific Aging Curves*:
| Position | Peak Start | Peak End | Decline | Calibration |
|----------|------------|----------|---------|-------------|
| GK | 29 | 34 | 35 | ±1 year |
| DC | 27 | 31 | 32 | ±1 year |
| DL/DR | 25 | 29 | 30 | ±1 year |
| DM/MC | 26 | 30 | 32 | ±1 year |
| AM | 24 | 28 | 30 | ±1 year |
| ST | 25 | 29 | 31 | ±1 year |

*30-30-30-10 Wage Structure*:
| Tier | Slots | Budget Share | Calibration Range |
|------|-------|--------------|-------------------|
| Key | 4 | 30% | 25-35% |
| First Team | 7 | 30% | 25-35% |
| Rotation | 11 | 30% | 25-35% |
| Backup | 5 | 10% | 5-15% |

*Wage Efficiency Thresholds*:
| Threshold | Ratio | Calibration Range | Action |
|-----------|-------|-------------------|--------|
| Inefficient | 1.25 | 1.20-1.30 | Flag for review |
| Wage Dump | 1.50 | 1.40-1.60 | Urgent sale |

*Protection Rule Thresholds*:
| Rule | Default | Calibration Range | Notes |
|------|---------|-------------------|-------|
| Youth PA Threshold | 150 | 140-160 | Club stature dependent |
| Protected Count | 15 | 12-18 | Top N by contribution |
| Recent Signing Period | 180 days | 120-240 days | Adaptation window |
| Min HGC Count | 4 | FIXED (UEFA Rule) | Registration critical |
| Min Position Depth | 2 | 2-3 | Blocking threshold |

*Youth Loan Policy*:
| Age Range | Default Action | Calibration |
|-----------|----------------|-------------|
| 15-18 | KEEP | FIXED (Club Grown) |
| 18+ | LOAN if <20 matches | 15-25 matches threshold |

*Stalled Development Threshold*:
| Metric | Default | Calibration Range |
|--------|---------|-------------------|
| Progress Rate | 0.5 | 0.4-0.6 |
| PA-CA Headroom | 20 | 15-25 |

**Match Importance Classification (CALIBRATED from Step 9)**:

*Base Importance Scores (0-100)*:
| Competition | Stage | Default | Calibration Range |
|-------------|-------|---------|-------------------|
| League (Title/Relegation) | Last 10 | 100 | FIXED |
| League (Contention) | Regular | 80 | 75-85 |
| League (Mid-Table) | Any | 60 | 50-70 |
| League (Dead Rubber) | Last 5 | 20 | 15-25 |
| Champions League | KO (R16+) | 95 | 90-100 |
| Champions League | Group (Open) | 85 | 80-90 |
| Champions League | Group (Safe) | 50 | 40-60 |
| Domestic Cup (Major) | SF/Final | 100 | FIXED |
| Domestic Cup (Major) | Early | 40 | 30-50 |
| Secondary Cup | Late | 70 | 60-80 |
| Secondary Cup | Early | 30 | 20-40 |
| Friendlies | Any | 10 | 5-15 |

*Opponent Strength Modifiers (M_opp)*:
| Relative Strength | Classification | Default | Calibration Range |
|-------------------|----------------|---------|-------------------|
| > 1.3 | Titan | 1.2x | 1.15-1.25 |
| 1.1-1.3 | Superior | 1.1x | 1.05-1.15 |
| 0.9-1.1 | Peer | 1.0x | FIXED |
| 0.6-0.9 | Inferior | 0.8x | 0.75-0.85 |
| < 0.6 | Minnow | 0.6x | 0.5-0.7 |

*Schedule Context Modifiers (M_sched)*:
| Condition | Default | Calibration Range | Notes |
|-----------|---------|-------------------|-------|
| Next High ≤3 days | 0.7x | 0.6-0.8 | 72-hour recovery |
| Next High = 4 days | 0.9x | 0.85-0.95 | Slight rotation |
| 3rd match in 7 days | 0.8x | 0.75-0.85 | ACWR congestion |
| ≥7 days rest | 1.1x | 1.05-1.15 | Freshness bonus |

*Contextual Bonuses (B_context)*:
| Bonus Type | Default | Calibration Range | Trigger |
|------------|---------|-------------------|---------|
| Rivalry/Derby | +20 | +15 to +25 | `is_derby` flag |
| Form Correction | +15 | +10 to +20 | `losing_streak >= 3` |
| Cup Run | +10 | +5 to +15 | QF+ with Cup objective |

*FIS Classification Thresholds*:
| Level | Threshold | Calibration Range | Meaning |
|-------|-----------|-------------------|---------|
| High | ≥ 85 | 80-90 | Must Win |
| Medium | 50-84 | 45-55 (low) | Important |
| Low | < 50 | 45-55 | Rotation |

*Sharpness Detection Thresholds*:
| Parameter | Default | Calibration Range | Notes |
|-----------|---------|-------------------|-------|
| FIS Threshold | < 50 | < 45-55 | Low importance required |
| Rusty Player Count | ≥ 3 | 2-4 | Key players with sharpness < 70% |
| Sharpness Threshold | 70% | 65-75% | Definition of "rusty" |

*Manager Profile Weights*:
| Profile | League | Major Cup | Secondary Cup | Continental |
|---------|--------|-----------|---------------|-------------|
| Balanced | 1.0 | 1.0 | 1.0 | 1.0 |
| Architect (Youth) | 1.0 | 0.8 | 0.5 | 1.2 |
| Pragmatist (Survival) | 1.3 | 0.6 | 0.6 | 0.6 |
| Glory Hunter (Cups) | 1.0 | 1.2 | 1.0 | 1.2 |

**Condition Cliff Heuristic (Step 4)**:
| Condition | Multiplier | Calibration Range |
|-----------|------------|-------------------|
| ≥ 95% | 1.00 | FIXED |
| 90-94% | 0.95 | 0.93-0.97 |
| 80-89% | 0.80 | 0.75-0.85 |
| < 80% | 0.50 | 0.40-0.60 |
| < 75% | Big M | Threshold: 72-78% |

**Safe Big M**: 10^6 (FIXED - numerical stability requirement)

**Validation-Derived Calibration (from Step 10)**:

*Validated Sigmoid Parameters*:
| Multiplier | Formula | Key Points |
|------------|---------|------------|
| Φ(C) Condition | 1/(1+e^(-25(c-0.88))) | Φ(0.91)≈0.68, Φ(0.88)=0.5 |
| Ψ(S) Sharpness | 1.02/(1+e^(-15(s-0.75)))-0.02 | Steep drop below 75% |

*Validated Thresholds*:
| Parameter | Validated Value | Protocol |
|-----------|-----------------|----------|
| Condition Floor | 91% | Protocol 3 |
| Sharpness Cliff | Day 7+ decay | Protocol 4 |
| Jadedness Fresh | J < 200 | Protocol 5 |
| Jadedness Jaded | J ≥ 700 | Protocol 5 |
| 270-Minute Penalty | 2.5x multiplier | Protocol 7 |
| Recovery (Holiday) | 50 pts/day | Protocol 8 |
| Recovery (Rest) | 5 pts/day | Protocol 8 |

*Reliability Coefficient Formula*:
$$\rho = 1 - \frac{20 - Consistency}{K_{cons}}$$
Where K_cons = 40 (calibration range: 35-45)

*Positional Drag Coefficients (Validated)*:
| Position | R_pos | Calibration Range |
|----------|-------|-------------------|
| GK | 0.20 | 0.15-0.25 |
| CB | 1.00 | FIXED (baseline) |
| WB | 1.65 | 1.50-1.80 |

*Integration Test Pass Criteria*:
| Test | Metric | Target |
|------|--------|--------|
| Christmas Crunch | Rotation Index | > 0.7 |
| Christmas Crunch | Condition Violations | 0 |
| Christmas Crunch | J > 700 violations | 0 (unless NF > 16) |
| Death Spiral | Youth Call-up | Triggered before constraints violated |

*Shadow Pricing Priority (Calibration Focus)*:
- Discount factor γ is the most sensitive parameter
- VORP correlation with shadow price should be r > 0.8
- Trajectory bifurcation must show ShadowCost > DirectUtility for Cup Final protection

**Total**: ~50+ parameters

## Research Objective

**Goal**: Define a calibration methodology that:
1. Identifies the most sensitive parameters
2. Finds optimal values systematically
3. Validates against test scenarios
4. Produces robust defaults that work across different squad types

## Calibration Approaches

### Approach 1: Grid Search

Exhaustive search over parameter combinations.

**Pros**: Finds global optimum (within grid)
**Cons**: Exponential complexity; 50 parameters with 3 values each = 3^50 combinations

**Practical Application**:
- Only grid search high-sensitivity parameters
- Fix low-sensitivity parameters at defaults
- Use coarse grid first, refine later

### Approach 2: Bayesian Optimization

Sequential model-based optimization.

**Pros**: Efficient sampling; handles many parameters
**Cons**: Requires surrogate model; may miss global optima

**Practical Application**:
- Use Gaussian Process to model objective function
- Sample next point where expected improvement is highest
- Typically finds good solutions in 50-200 evaluations

### Approach 3: Sensitivity Analysis First

Identify which parameters matter before optimizing.

**Method**:
1. Start with baseline parameters
2. Vary each parameter ±20% while holding others fixed
3. Measure impact on aggregate score
4. Rank parameters by sensitivity
5. Only calibrate top 10 most sensitive

### Approach 4: Staged Calibration

Calibrate parameters in groups.

**Stages**:
1. Multiplier floors (α values) - ensure emergency utility isn't zero
2. Thresholds (T values) - where penalties begin
3. Steepness (k values) - how fast penalties apply
4. Shadow/Stability weights - multi-match behavior
5. REST parameters - rotation behavior

## Proposed Methodology

### Phase 1: Sensitivity Analysis

```python
def sensitivity_analysis(baseline_params, param_ranges, test_scenarios):
    """
    One-at-a-time sensitivity analysis.

    Returns: Dict[param_name] -> sensitivity_score
    """
    baseline_score = evaluate(baseline_params, test_scenarios)
    sensitivity = {}

    for param_name, (low, high) in param_ranges.items():
        # Test low value
        low_params = baseline_params.copy()
        low_params[param_name] = low
        low_score = evaluate(low_params, test_scenarios)

        # Test high value
        high_params = baseline_params.copy()
        high_params[param_name] = high
        high_score = evaluate(high_params, test_scenarios)

        # Sensitivity = range of scores
        sensitivity[param_name] = max(high_score, low_score, baseline_score) - \
                                  min(high_score, low_score, baseline_score)

    return sensitivity
```

### Phase 2: Parameter Grouping

Based on sensitivity analysis, group parameters:

**Critical (always calibrate)**:
- Parameters with sensitivity > 10% of baseline score

**Important (calibrate if resources allow)**:
- Parameters with sensitivity 5-10%

**Low-Impact (use defaults)**:
- Parameters with sensitivity < 5%

### Phase 3: Coarse Grid Search

For critical parameters only:

```python
def coarse_grid_search(critical_params, param_grid, test_scenarios):
    """
    Grid search with 3-5 values per parameter.
    """
    best_params = None
    best_score = -inf

    for param_combo in itertools.product(*param_grid.values()):
        params = dict(zip(param_grid.keys(), param_combo))
        score = evaluate(params, test_scenarios)

        if score > best_score:
            best_score = score
            best_params = params

    return best_params, best_score
```

### Phase 4: Local Refinement

Around best coarse solution:

```python
def local_refinement(coarse_best, param_ranges, test_scenarios, iterations=50):
    """
    Local search to fine-tune parameters.
    """
    current = coarse_best.copy()
    current_score = evaluate(current, test_scenarios)

    for _ in range(iterations):
        # Pick random parameter
        param = random.choice(list(param_ranges.keys()))

        # Try small adjustment
        adjustment = random.uniform(-0.1, 0.1) * (param_ranges[param][1] - param_ranges[param][0])
        new_value = current[param] + adjustment
        new_value = max(param_ranges[param][0], min(param_ranges[param][1], new_value))

        # Evaluate
        candidate = current.copy()
        candidate[param] = new_value
        candidate_score = evaluate(candidate, test_scenarios)

        if candidate_score > current_score:
            current = candidate
            current_score = candidate_score

    return current, current_score
```

### Phase 5: Cross-Validation

Ensure parameters generalize:

```python
def cross_validate(params, all_scenarios, n_folds=5):
    """
    K-fold cross-validation on scenarios.
    """
    scenario_groups = split_into_folds(all_scenarios, n_folds)
    scores = []

    for i in range(n_folds):
        # Train on n-1 folds
        train_scenarios = [s for j, group in enumerate(scenario_groups) if j != i for s in group]
        test_scenarios = scenario_groups[i]

        # Calibrate on train
        calibrated = calibrate(params, train_scenarios)

        # Evaluate on test
        test_score = evaluate(calibrated, test_scenarios)
        scores.append(test_score)

    return {
        'mean': np.mean(scores),
        'std': np.std(scores),
        'min': np.min(scores),
        'max': np.max(scores)
    }
```

## Objective Function

What are we optimizing?

### Multi-Objective Score

```python
def aggregate_score(result):
    """
    Combine multiple metrics into single score.
    """
    return (
        0.40 * normalize(result.metrics['ATS']) +           # Team strength
        0.20 * (1 - result.metrics['FVC'] / 10) +           # Fatigue safety
        0.15 * result.metrics['KPA'] +                       # Key player availability
        0.10 * result.metrics['stability_score'] +           # Lineup stability
        0.10 * normalize(result.metrics['sharpness_efficiency']) +  # Sharpness management
        0.05 * (1 - result.metrics['rotation_excess'])       # Not over-rotating
    )
```

### Weight Justification

| Metric | Weight | Rationale |
|--------|--------|-----------|
| ATS | 0.40 | Primary goal: field strong teams in important matches |
| FVC | 0.20 | Safety: don't risk injuries |
| KPA | 0.15 | Stars available for big games |
| Stability | 0.10 | Avoid chaotic lineup changes |
| Sharpness | 0.10 | Maintain match fitness |
| Rotation | 0.05 | Use full squad appropriately |

## Parameter Ranges

### Baseline Values (Updated from Step 2 Research)

**IMPORTANT**: Step 2 research has provided DEFINITIVE values. These should be the starting point:

| Parameter | Step 2 Value | Test Range | Notes |
|-----------|--------------|------------|-------|
| k_condition | **25** | 15 - 30 | Very steep - NOT 0.08-0.15! |
| T_condition | **0.88** | 0.85 - 0.92 | 88% threshold |
| k_sharpness | **15** | 10 - 20 | Moderate steepness |
| T_sharpness | **0.75** | 0.70 - 0.80 | 75% threshold |
| Θ_floor | **0.70** | FIXED | Linear familiarity floor |
| Θ_slope | **0.30** | FIXED | Linear familiarity slope |
| Ω_fresh | **1.0** | FIXED | Step function value |
| Ω_fit | **0.9** | 0.85 - 0.95 | Step function value |
| Ω_tired | **0.7** | 0.6 - 0.8 | Step function value |
| Ω_jaded | **0.4** | 0.3 - 0.5 | Step function value |
| 270_min_threshold | **270** | 240 - 300 | Hidden fatigue rule |
| 270_min_penalty | **0.85** | 0.8 - 0.9 | Penalty factor |
| γ_shadow | 0.85 | 0.70 - 0.95 | Shadow discount |
| λ_shadow | 1.0 | 0.5 - 2.0 | Shadow weight |
| λ_V (scarcity) | 2.0 | 1.0 - 3.0 | VORP scarcity scaling (Step 5) |
| inertia_weight | 0.5 | 0.0 - 1.0 | Stability slider |

**Note**: Familiarity and base fatigue step function values are FIXED from Step 2 and should NOT be calibrated.

### Constraints on Parameters

- All α (floor) values must be > 0
- All k (steepness) values must be > 0
- Thresholds must be within valid input ranges
- Shadow discount γ must be in (0, 1)

## Expected Deliverables

### A. Sensitivity Ranking

Table of all parameters ranked by sensitivity:

| Rank | Parameter | Sensitivity Score | Category |
|------|-----------|-------------------|----------|
| 1 | T_condition_high | 0.15 | Critical |
| 2 | γ_shadow | 0.12 | Critical |
| 3 | α_fatigue_medium | 0.09 | Important |
| ... | ... | ... | ... |

### B. Parameter Grid Definition

```python
CALIBRATION_GRID = {
    # Critical parameters (3-5 values each)
    'T_condition_high': [70, 75, 80, 85],
    'γ_shadow': [0.75, 0.85, 0.95],
    'inertia_weight': [0.3, 0.5, 0.7],

    # Important parameters (3 values each)
    'α_condition_high': [0.35, 0.45, 0.55],
    ...
}
```

### C. Calibration Script

```python
def main_calibration():
    # Load test scenarios
    scenarios = load_all_scenarios()

    # Phase 1: Sensitivity
    sensitivity = sensitivity_analysis(BASELINE, PARAM_RANGES, scenarios)
    critical_params = [p for p, s in sensitivity.items() if s > 0.05]

    # Phase 2: Coarse grid
    grid = {p: CALIBRATION_GRID[p] for p in critical_params}
    coarse_best, coarse_score = coarse_grid_search(critical_params, grid, scenarios)

    # Phase 3: Refinement
    refined, refined_score = local_refinement(coarse_best, PARAM_RANGES, scenarios)

    # Phase 4: Validation
    cv_result = cross_validate(refined, scenarios)

    # Output
    print(f"Best parameters: {refined}")
    print(f"Score: {refined_score}")
    print(f"Cross-validation: mean={cv_result['mean']}, std={cv_result['std']}")

    return refined
```

### D. Robustness Analysis

Test calibrated parameters on:
1. Different squad sizes (25, 35, 45 players)
2. Different fixture densities (light, congested)
3. Different squad qualities (top team, mid-table, weak team)
4. Different injury rates (low, normal, high)

### E. Final Parameter Tables

After calibration, produce final tables:

**Condition Multiplier**:
| Importance | α | T | k | Confidence |
|------------|---|---|---|------------|
| High | X.XX | XX | X.XX | High |
| Medium | X.XX | XX | X.XX | High |
| Low | X.XX | XX | X.XX | Medium |
| Sharpness | X.XX | XX | X.XX | Medium |

(Repeat for all multiplier types)

### F. Documentation

For each calibrated parameter:
- Final value
- Sensitivity score
- Test scenarios that drove the value
- Robustness across different conditions
- Recommendations for user adjustment

## Validation Criteria

The calibration is successful if:
- Sensitivity analysis correctly identifies critical parameters
- Calibrated parameters improve score by > 10% vs baseline
- Cross-validation shows < 10% variance across folds
- Parameters generalize across different squad types
- Final parameters are documented with justification

## Output Format

1. **Sensitivity Report**: Ranked parameter list
2. **Calibration Log**: All parameter combinations tested with scores
3. **Final Parameters**: Production-ready values
4. **Robustness Report**: Performance across conditions
5. **User Guidance**: Which parameters users might want to adjust
