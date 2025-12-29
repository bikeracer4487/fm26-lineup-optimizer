# Research Prompt 03: State Propagation Calibration

## Context

Our lineup optimizer plans across a 5-match horizon. To do this, we must predict how player states (condition, sharpness, fatigue) evolve based on playing time and rest. Current equations exist in `state_simulation.py` but may not accurately reflect FM26 behavior.

### Current Implementation Summary

```python
# Condition
ΔC_match = (minutes / 90) × drain_rate × (1 - stamina/200)
ΔC_recovery = days × recovery_rate × (natural_fitness/100)

# Sharpness (on 0-10000 scale)
ΔSh_gain = (minutes / 90) × 1500 × match_type_factor × (1 + NF/400)
ΔSh_decay = days_since_match × 100 × (1 - NF/200)

# Fatigue
ΔF_match = (minutes / 90) × 20 × intensity_factor × age_modifier
ΔF_recovery = days × 10 × (1 + NF/100)
```

## Research Objective

**Goal**: Validate and calibrate state propagation equations against actual FM26 behavior. Produce equations that accurately predict player states after matches and rest periods.

## Specific Questions

### 1. Condition Dynamics

**Match Impact**:
- What is the typical condition drop after playing 90 minutes?
- How does position affect condition loss? (GK vs box-to-box midfielder)
- Does match intensity (opponent strength, tactical demands) affect loss?
- Does substitution timing affect condition loss linearly?

**Recovery**:
- What is the base daily recovery rate?
- How much does Natural Fitness affect recovery? (linear? diminishing?)
- Does training intensity (Light/Medium/Intense) affect recovery?
- Does age affect recovery speed?
- Is there a "recovery ceiling" where condition stops improving?

**Verification Questions**:
- Player with NF=20, Stamina=18 plays 90 min CM: post-match condition?
- Same player rests 4 days: predicted condition?
- Player with NF=8, Stamina=10 plays 90 min ST: post-match condition?

### 2. Sharpness Dynamics

**Match Gain**:
- How much sharpness does a full 90 competitive match provide?
- How does friendly vs competitive affect gain?
- Does reserve team match provide sharpness?
- Is sharpness gain linear with minutes or are there diminishing returns?
- Does match importance affect sharpness gain?

**Decay**:
- What is the daily decay rate without matches?
- Is decay constant or does it accelerate after prolonged rest?
- Does Natural Fitness affect decay rate?
- What is the minimum sharpness floor?

**Verification Questions**:
- Player at 50% sharpness plays 90 min competitive: new sharpness?
- Player at 85% sharpness rests 7 days: new sharpness?
- Player at 30% sharpness plays 60 min friendly: new sharpness?

### 3. Fatigue Dynamics

**Accumulation**:
- What causes fatigue to increase? (match minutes only? training?)
- How does match intensity/importance affect fatigue accumulation?
- Does position affect fatigue accumulation?
- Age effects: at what age does fatigue accumulate faster?
- How do Stamina and Natural Fitness interact?

**Recovery**:
- What is the base daily fatigue recovery?
- How does vacation affect recovery?
- Can jadedness be cleared with rest alone? How long?
- Does the "Needs a rest" flag require full rest days or just reduced minutes?

**Thresholds**:
- At what internal fatigue value do status indicators change?
- At what value is injury risk significantly elevated?
- At what value does "Jaded" status trigger?

### 4. Position-Specific Drain Rates

Current assumption:
| Position | Drain Rate |
|----------|------------|
| GK | 15 |
| CB, DM | 25 |
| FB, CM, AM | 30 |
| Winger, ST | 35 |

Questions:
- Are these approximately correct for FM26?
- Do tactical roles within a position matter? (BWM vs Regista)
- Does team mentality affect drain rates?

### 5. Natural Fitness & Stamina Interactions

These two attributes appear in multiple formulas:
- How exactly do they differ in function?
- NF seems to affect recovery; Stamina seems to affect match drain - correct?
- Are there interaction effects where high NF + low Stamina produces unexpected results?
- Does Work Rate attribute affect any dynamics?

### 6. Age Effects

- At what age thresholds do fatigue/recovery dynamics change?
- Is 30+ significantly different from 32+?
- Do young players (<19) have any special considerations?
- Does peak age (23-28) have any bonuses?

## Expected Deliverables

### A. Calibrated Equations

For each state variable, provide:

**Condition**:
```
C_{post-match} = C_{pre-match} - f(minutes, position, stamina, age, ...)
C_{after-rest} = min(100, C_{post-match} + g(days, NF, training_intensity, ...))
```

**Sharpness** (internal 0-10000 or 0-100):
```
Sh_{post-match} = min(MAX, Sh_{pre-match} + f(minutes, match_type, NF, ...))
Sh_{after-rest} = max(MIN, Sh_{post-match} - g(days, NF, ...))
```

**Fatigue** (internal scale):
```
F_{post-match} = F_{pre-match} + f(minutes, position, intensity, age, NF, stamina, ...)
F_{after-rest} = max(0, F_{post-match} - g(days, NF, vacation_bonus, ...))
```

### B. Parameter Table

| Parameter | Value | Unit | Source/Confidence |
|-----------|-------|------|-------------------|
| base_condition_drain | ? | % per 90 min | Verified/Estimated |
| stamina_drain_modifier | ? | multiplier | Verified/Estimated |
| position_drain_GK | ? | % per 90 min | Verified/Estimated |
| ... | ... | ... | ... |

### C. Verification Examples

5-match sequence simulation with specific player:
- Initial state: C=100, Sh=70, F=0
- Match 1: 90 min, 4 days rest
- Match 2: 75 min, 3 days rest
- Match 3: 0 min (rested), 5 days rest
- Match 4: 90 min, 2 days rest
- Match 5: 90 min

Expected state at each point with calculations shown.

### D. Edge Cases

- Player plays 120 min (extra time) - how does this affect equations?
- Player gets sent off at 20 min - still counts as match load?
- Player injured mid-match - any special considerations?
- Congested fixture period (3 games in 6 days) - any compound effects?

### E. Comparison with Current Implementation

Table showing:
| Scenario | Current Prediction | Calibrated Prediction | Difference |
|----------|-------------------|----------------------|------------|

## Validation Criteria

The calibration is successful if:
- Predictions match observed FM26 behavior within 5% for common scenarios
- Edge cases produce reasonable (not absurd) results
- Equations handle all player attribute ranges (1-20)
- Recovery timelines align with typical FM rotation patterns

## Output Format

1. **Final Equations**: Complete set with all parameters
2. **Parameter Justification**: Why each value was chosen
3. **Worked Examples**: At least 3 multi-match sequences
4. **Implementation Pseudocode**: Ready to update `state_simulation.py`
5. **Uncertainty Notes**: Which parameters need in-game testing
