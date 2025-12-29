# Research Prompt 05: Shadow Pricing Formula

## Context

Our lineup optimizer plans across a 5-match horizon using "shadow pricing" - a technique from operations research that assigns opportunity costs to using resources (players) now versus preserving them for future high-importance matches.

Current shadow pricing implementation exists in `shadow_pricing.py` but may need refinement.

### Current Formula (from FM26 #1)

```
Cost_shadow(p, k) = Σ_{m=k+1}^{4} (Imp_m/Imp_avg × Utility(p,m)/ΔDays × IsKeyPlayer(p))
```

This formula considers:
- Future match importance weights
- Player's projected utility at future matches
- Days between matches
- Whether player is a "key player"

## Research Objective

**Goal**: Define a mathematically rigorous and practically useful shadow pricing formula that:
1. Correctly identifies when to rest star players
2. Doesn't over-preserve players (causing current match weakness)
3. Handles edge cases (all matches same importance, very long gaps)

## The Core Problem

**Without Shadow Pricing**: Greedy selection plays best XI every match → fatigue spiral → key players unavailable for important matches.

**With Shadow Pricing**: System looks ahead and "reserves" key players for upcoming important matches by making them more expensive to use now.

## Questions to Resolve

### 1. What Should Shadow Cost Measure?

**Option A: Future Value Lost**
```
ShadowCost = Σ (utility_if_rested - utility_if_played) × importance_weight × discount
```
Direct measurement of what we lose by playing now.

**Option B: Opportunity Cost of Condition**
```
ShadowCost = condition_drop × future_match_value
```
Simpler: just cost the condition loss.

**Option C: Position Scarcity Adjusted**
```
ShadowCost = future_value × (1 / position_depth)
```
Higher cost if we have few alternatives for this position.

Questions:
- Which approach is most aligned with actual rotation decisions?
- Should we combine multiple factors?
- How do we avoid double-counting with the fatigue multiplier?

### 2. Importance Weighting

**Current Weights** (from FM26 #2):
| Importance | Weight |
|------------|--------|
| High | 1.5 |
| Medium | 1.0 |
| Low | 0.6 |
| Sharpness | 0.8 |

Questions:
- Are these weights correct?
- Should upcoming High importance cancel out current Low importance entirely?
- How do we handle consecutive High importance matches?

### 3. Time Decay / Discount Factor

**Current**: γ = 0.85 (15% discount per match into future)

Questions:
- Is 0.85 the right discount rate?
- Should discount be per-match or per-day?
- Does the discount apply before or after importance weighting?

### 4. Key Player Identification

Not all players benefit equally from shadow pricing. A depth player for position X shouldn't be "preserved" if a better player exists.

**Key Player Criteria Options**:
- Top N players by Current Ability
- Players above X rating for their primary position
- Players who are "best available" for any position
- Players with no quality backup

Questions:
- What makes a player "key"?
- Should shadow cost scale with key player importance?
- How do we handle polyvalent players (key for multiple positions)?

### 5. Position Scarcity

Shadow cost should be higher when:
- Few players can cover a position
- The gap between #1 and #2 for a position is large
- Multiple positions depend on the same player

Questions:
- How do we quantify "position scarcity"?
- Should we calculate positional depth dynamically?
- How does this interact with stability mechanisms?

### 6. Fixture Density Adjustment

Shadow pricing should be more aggressive when:
- Matches are closely packed (3 in 7 days)
- An important match follows immediately after several matches

Questions:
- How does fixture density affect shadow calculations?
- Should there be special handling for "congestion periods"?

### 7. Integration with Cost Matrix

Shadow costs must integrate cleanly with the Hungarian cost matrix:
```
Cost[p][s] = -Utility + λ_shadow × ShadowCost + ...
```

Questions:
- What should λ_shadow be? (1.0? Configurable?)
- Should shadow cost apply to REST slots?
- How do we scale shadow costs relative to utility (both on rating-point scale)?

### 8. Computational Approach

Two methods proposed:

**Simple Heuristic** (from FM26 #2):
```python
for i, player in enumerate(players):
    for k in range(horizon):
        future_value = 0.0
        for j in range(k + 1, horizon):
            future_value += γ^(j-k) × importance × (utility_rest - utility_play)
        shadow[i][k] = max(0, future_value)
```

**Lagrangian Relaxation** (more accurate but complex):
- Solve multi-period problem via subgradient optimization
- Produces true shadow prices from constraint relaxation

Questions:
- Is the simple heuristic sufficient?
- When would we need the Lagrangian approach?
- What's the performance impact of each?

## Expected Deliverables

### A. Final Shadow Cost Formula

Complete mathematical specification:
```
ShadowCost(player p, match k) = ...
```

With all terms defined and justified.

### B. Importance Weight Table

| Importance | Weight | Rationale |
|------------|--------|-----------|

### C. Parameter Table

| Parameter | Value | Range | Sensitivity |
|-----------|-------|-------|-------------|
| γ (discount) | ? | ? | ? |
| λ_shadow | ? | ? | ? |
| key_player_threshold | ? | ? | ? |

### D. Key Player Algorithm

```python
def identify_key_players(squad, positions):
    """
    Returns: Dict[player_id] -> key_player_weight (0 to 1)
    """
    ...
```

### E. Position Scarcity Algorithm

```python
def calculate_position_scarcity(squad, positions):
    """
    Returns: Dict[position] -> scarcity_weight (0 to 1)
    """
    ...
```

### F. Worked Examples

**Example 1: Cup Final Preparation**
- Matches: Low, Low, Low, Low, High (Cup Final)
- Expected: Star players heavily preserved for Match 5
- Show shadow costs at each match step

**Example 2: Congested Fixture Period**
- Matches: Med, High, Med, High, Med (all within 12 days)
- Expected: Rotation enforced, no player plays all 5
- Show shadow costs and resulting assignments

**Example 3: All Medium Importance**
- Matches: Med, Med, Med, Med, Med
- Expected: Minimal shadow pricing, normal rotation
- Show that shadow costs are modest

### G. Edge Case Handling

| Edge Case | Expected Behavior |
|-----------|-------------------|
| All matches same importance | Minimal shadow cost, normal rotation |
| All matches High importance | Some shadow for final match only |
| 7+ days between matches | Shadow cost approaches zero (full recovery) |
| Only 2 matches in horizon | Proportionally adjusted calculation |
| Player has no backup | Maximum shadow cost for preservation |

## Validation Criteria

The shadow pricing formula is successful if:
- It demonstrably preserves key players for high-importance matches
- It doesn't over-preserve (causing current match weakness)
- Shadow costs are on a sensible scale (not dominating utility)
- Computation completes in < 50ms for 40 players × 5 matches
- Edge cases produce reasonable results

## Output Format

1. **Mathematical Formula**: Complete, unambiguous specification
2. **Algorithm Pseudocode**: Implementation-ready code
3. **Parameter Justification**: Why each value was chosen
4. **Worked Examples**: At least 3 scenarios with calculations
5. **Integration Notes**: How to merge with existing cost matrix code
