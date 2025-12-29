# Research Prompt 06: Fatigue Dynamics & Rest Policy

## Context

Fatigue management is one of FM26's most challenging aspects. Poor fatigue management leads to:
- Injuries to key players at critical moments
- Jadedness that requires extended rest periods
- Performance degradation even when players "look" available

Our app needs a comprehensive fatigue model and clear rest policies.

### Current Implementation Gaps

- Fatigue thresholds are assumed, not validated
- No clear policy for when to recommend rest vs rotation vs vacation
- Jadedness handling is simplistic
- Age-based adjustments are rough estimates

## Research Objective

**Goal**: Create a complete fatigue management system that:
1. Accurately models FM26 fatigue accumulation and recovery
2. Provides clear rest/rotation/vacation recommendations
3. Prevents jadedness through proactive management
4. Handles player archetypes (veteran, youngster, workhorse, fragile)

## The Fatigue Model

### Internal vs Visible Fatigue

FM26 appears to have internal fatigue values that don't map directly to UI indicators.

**Questions**:
- What is the internal fatigue scale? (0-1000 as assumed?)
- How do the status indicators (Fresh, Needs Rest) relate to internal values?
- Is there a way to estimate internal fatigue from visible data?

### Fatigue Accumulation

**Factors to consider**:
- Minutes played per match
- Match intensity (tactical, opponent quality)
- Player attributes (Stamina, Natural Fitness)
- Position demands (high press midfielder vs deep defender)
- Age effects

**Research Questions**:
- Base fatigue gain per 90 minutes?
- How much do Stamina and Natural Fitness modify this?
- Does consecutive match frequency compound fatigue non-linearly?
- Does travel/fixture congestion add "hidden" fatigue?

### Fatigue Recovery

**Factors to consider**:
- Days of rest
- Natural Fitness attribute
- Training intensity setting
- Age
- Vacation status

**Research Questions**:
- Base recovery rate per day?
- How much faster is vacation recovery?
- Is recovery linear or does it plateau near "fully fresh"?
- Can a player be "over-rested" (negative effects)?

### Jadedness

Jadedness is a critical state that requires extended rest to clear.

**Questions**:
- What triggers jadedness? (Total fatigue? Consecutive matches? Both?)
- How long does jadedness take to clear?
- Does playing while jaded cause long-term harm?
- What are the performance penalties for jaded players?

## Rest Policy Framework

We need decision rules for when to recommend:

### 1. Standard Rotation
Normal match-by-match decisions using the scoring model.

**When**: Fatigue within acceptable range, upcoming matches manageable
**Action**: Use shadow pricing and multipliers to guide selection

### 2. Enforced Rest
Player should not start regardless of match importance.

**Triggers**:
- Fatigue above threshold X
- Condition below threshold Y
- Played N consecutive full matches
- Specific warning indicators

**Questions**:
- What should threshold X be?
- Should this be overridable for High importance matches?
- How many rest days should enforced rest require?

### 3. Reduced Minutes
Player can start but should be substituted early.

**Triggers**:
- Moderate fatigue level
- Upcoming important match within N days
- Recovery from recent enforced rest

**Questions**:
- What minute target for reduced play? (60? 70?)
- How do we communicate this to the user?

### 4. Vacation Recommendation
Player needs extended break beyond normal rest.

**Triggers**:
- Jadedness flag
- Sustained high fatigue over multiple weeks
- End of intense competition period

**Questions**:
- How long should recommended vacation be?
- Should vacation timing consider squad depth?
- What recovery rate should we assume during vacation?

## Player Archetypes

Different players have different fatigue profiles:

### The Workhorse
- High Stamina (15+), High Natural Fitness (15+)
- Can play congested schedules with minimal issues
- Risk: Over-reliance leads to eventual breakdown

### The Glass Cannon
- High ability, High Injury Proneness (15+)
- Needs careful management even when not visibly fatigued
- Risk: Single overuse causes long-term injury

### The Veteran (30+)
- Slower recovery, faster fatigue accumulation
- Needs strategic rest even if stats look fine
- Risk: Jadedness if played too often

### The Youngster (<19)
- Can handle high workloads physically
- May need managed minutes for development reasons
- Risk: Burnout affecting long-term potential

**Questions**:
- How should thresholds vary by archetype?
- Should the app auto-classify players into archetypes?
- How do we handle players who fit multiple archetypes?

## Integration Points

### With Scoring Model
- Fatigue multiplier Λ already exists
- Rest policy provides additional hard constraints

### With Shadow Pricing
- Rest recommendations should influence shadow costs
- "Must rest" players have infinite shadow cost for current match

### With UI
- Clear status indicators needed
- Recommendation cards for rest/vacation
- Timeline showing when player will be "ready"

## Expected Deliverables

### A. Fatigue Model Specification

**Accumulation Formula**:
```
F_new = F_old + fatigue_gain(minutes, position, age, NF, stamina, intensity)
```

**Recovery Formula**:
```
F_new = max(0, F_old - fatigue_recovery(days, NF, training, vacation))
```

**Jadedness Trigger**:
```
is_jaded = (fatigue > JADED_THRESHOLD and consecutive_matches > N) or ...
```

### B. Threshold Tables

**Fatigue Status Indicators** (internal scale → status):
| Internal Range | Status | UI Color | Recommendation |
|----------------|--------|----------|----------------|
| 0-X | Fresh | Green | Available |
| X-Y | OK | Yellow | Monitor |
| Y-Z | Tired | Orange | Consider rest |
| Z+ | Exhausted | Red | Must rest |

**By Player Archetype**:
| Archetype | Fresh Cap | Tired Threshold | Exhausted Threshold |
|-----------|-----------|-----------------|---------------------|

### C. Rest Policy Decision Tree

```
IF player.is_jaded:
    RECOMMEND: Vacation (X days)
ELIF player.fatigue > EXHAUSTED_THRESHOLD:
    IF match.importance == 'High' AND player.is_key_player:
        RECOMMEND: Play with caution (reduce minutes if possible)
    ELSE:
        RECOMMEND: Enforced rest
ELIF player.fatigue > TIRED_THRESHOLD:
    IF next_match.importance == 'High' AND days_until < 3:
        RECOMMEND: Rest now to preserve for important match
    ELSE:
        RECOMMEND: Consider rotation
ELSE:
    RECOMMEND: Available for selection
```

### D. Vacation Policy

| Trigger | Recommended Duration | Recovery Rate | Priority |
|---------|---------------------|---------------|----------|
| Jadedness | 7-14 days | 2x normal | Critical |
| Post-season | 14-21 days | Normal | Standard |
| Sustained fatigue | 5-7 days | 1.5x normal | Moderate |

### E. UI Recommendation Cards

Design spec for rest advisor output:
```json
{
  "player": "Player Name",
  "status": "Needs Rest",
  "severity": "warning",
  "recommendation": "Rest for next 2 matches",
  "reason": "Fatigue at 85% of threshold after 4 consecutive starts",
  "recovery_timeline": {
    "current_fatigue": 340,
    "threshold": 400,
    "days_to_fresh": 4,
    "matches_to_skip": 2
  }
}
```

### F. Worked Examples

**Example 1: The Christmas Crunch**
- 8 matches in 22 days
- Player plays first 5 matches
- Show fatigue accumulation and when rest should be enforced

**Example 2: The Fragile Star**
- High ability player with Injury Proneness 18
- Show more conservative thresholds in action

**Example 3: Jadedness Recovery**
- Player becomes jaded
- Show vacation recommendation and recovery timeline

## Validation Criteria

The fatigue model is successful if:
- Thresholds align with FM26 observable behavior
- Rest recommendations prevent jadedness (not reactive, proactive)
- Player archetypes receive appropriately different treatment
- Vacation timing is sensible (not mid-season for key players)
- UI recommendations are clear and actionable

## Output Format

1. **Mathematical Model**: Fatigue accumulation and recovery equations
2. **Threshold Tables**: All numeric cutoffs with justification
3. **Decision Tree**: Rest policy logic
4. **Archetype Definitions**: How to classify and handle different player types
5. **UI Specifications**: Recommendation card designs
6. **Worked Examples**: Scenarios showing the system in action
