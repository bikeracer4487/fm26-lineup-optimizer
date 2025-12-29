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

**Shadow Pricing**:
- γ (discount factor): 1 value
- λ_shadow (weight): 1 value

**Stability**:
- inertia_weight: 1 value
- base_switch_cost: 1 value
- continuity_bonus: 1 value

**REST Slots**:
- α, β, γ, δ coefficients: 4 × 4 = 16 values

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
