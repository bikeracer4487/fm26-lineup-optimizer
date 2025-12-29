# Research Prompt 04: Hungarian Matrix Architecture

## Context

Our lineup optimizer uses the Hungarian (Munkres) algorithm to solve the player-to-slot assignment problem. The algorithm requires a cost matrix where we encode:
- Player utility for each slot
- REST slot behavior (players who should sit out)
- Constraints (injuries, bans, user locks)

Previous documents (#3 and #4) describe REST slot designs but differ in approach. We need a definitive architecture.

## CRITICAL: Findings from Unified Scoring Research (Step 2)

The Hungarian matrix must encode the finalized GSS (Global Selection Score) formula:

$$GSS = BPS \times \Phi(C) \times \Psi(S) \times \Theta(F) \times \Omega(J)$$

**Definitive Multiplier Formulas**:
- **Condition**: $\Phi(c) = \frac{1}{1 + e^{-25(c - 0.88)}}$ (k=25, c₀=0.88)
- **Sharpness**: $\Psi(s) = \frac{1.02}{1 + e^{-15(s - 0.75)}} - 0.02$ (k=15, s₀=0.75)
- **Familiarity**: $\Theta(f) = 0.7 + 0.3f$ (LINEAR, not sigmoid!)
- **Fatigue**: $\Omega(J) = \{1.0, 0.9, 0.7, 0.4\}$ (step function: Fresh, Fit, Tired, Jaded)

**Key Operational Rules**:
- 91% Floor: Players < 91% condition should have HIGH cost for playing slots
- 85% Sharpness Gate: Players < 85% sharpness should prefer REST slots
- 270-minute Rule: >270 min in 10 days → 0.85 penalty regardless of UI status

The cost matrix must correctly encode these multipliers and rules.

### Current Conflicts

**REST Slot Design**:
- Document #3: N-11 REST slots with `rest_cost(player, mode)` function
- Document #4: REST as "dummy positions" with complex utility formula

**Cost Calculation**:
- Document #3: `Cost = -Utility + ShadowCost + StabilityCost`
- Document #4: `Cost = MAX_UTILITY - Utility` (subtraction transform)

## Research Objective

**Goal**: Define the complete Hungarian matrix architecture including REST slot behavior, constraint encoding, and cost normalization.

## System Parameters

- **Squad Size (N)**: 25-40 players typically
- **Starting Slots (S)**: 11 (including GK)
- **Importance Modes**: High, Medium, Low, Sharpness
- **User Constraints**: Locks (player → slot), Rejections (player ≠ slot)

## Questions to Resolve

### 1. Matrix Dimensions

**Option A: Square Matrix (N × N)**
- Rows: Players
- Columns: 11 slots + (N-11) REST slots

**Option B: Rectangular with Padding**
- Let scipy handle non-square assignment

Questions:
- Which is more numerically stable?
- Which handles constraints more elegantly?
- Which is faster for typical squad sizes?

### 2. REST Slot Behavior

REST slots determine which players sit out. But REST isn't equally attractive to all players:
- Fatigued players WANT to rest
- Sharp, fit players should prefer to play
- Injured/banned players MUST rest

**Key Design Questions**:
- Should REST be one slot or multiple identical REST slots?
- How should REST utility be calculated?
- When should REST "win" over playing?

**Proposed REST Utility Formula** (from #4):
```
Utility_REST(p, Ω) = α(Ω) × AvgPositionalUtility(p)
                   + β(Ω) × FatigueRelief(p)
                   + γ(Ω) × SharpnessNeed(p)
                   + δ(Ω) × ConditionBonus(p)
```

Questions:
- Are these the right factors?
- What should α, β, γ, δ values be?
- How do we prevent "everyone rests" or "no one rests" failure modes?

### 3. Cost Normalization

Hungarian minimizes total cost. We want to maximize total utility.

**Options**:
1. Use `maximize=True` in scipy (if available)
2. Negate utilities: `Cost = -Utility`
3. Subtraction transform: `Cost = MAX_UTILITY - Utility`

Questions:
- Which approach is most robust?
- What should MAX_UTILITY be? (200? 250? Dynamic?)
- How do shadow/stability costs integrate with the transform?

### 4. Shadow Cost Integration

Shadow costs represent opportunity cost of using a player now vs saving them for future matches.

**Integration Options**:
1. Add to cost: `Cost = TransformUtility + ShadowCost`
2. Subtract from utility: `Utility - ShadowCost` then transform
3. Separate adjustment layer

Questions:
- Where in the formula does shadow cost belong?
- What scale should shadow costs be on? (0-20? 0-50?)
- Should shadow cost affect REST slots?

### 5. Stability Cost Integration

Stability costs penalize changing player positions between matches.

**Integration Options**:
1. Penalty for switching: `+switch_penalty` when not previous slot
2. Bonus for staying: `-continuity_bonus` when same as previous
3. Both (asymmetric)

Questions:
- Where in the formula does stability cost belong?
- What magnitude relative to utility? (5 points? 10 points?)
- Should stability affect REST assignments?

### 6. Constraint Encoding

**Hard Constraints** (must be satisfied):
- Injured → MUST REST
- Banned → MUST REST
- User locks → MUST be assigned to locked slot
- User rejections → CANNOT be assigned to rejected slot

**Encoding Options**:
1. Very high cost: FORBIDDEN = 1e9
2. Remove from matrix (problem reduction)
3. Combination approach

Questions:
- Problem reduction vs cost encoding - which is cleaner?
- How do we detect infeasibility?
- How do we handle conflicting constraints gracefully?

### 7. Goalkeeper Special Handling

GK is a unique position:
- Only GK-capable players should fill GK slot
- Non-GK players playing GK is emergency-only

Questions:
- Should GK have a separate eligibility check?
- How low can GK rating go before we forbid it entirely?
- What if all GKs are injured/banned?

## Expected Deliverables

### A. Matrix Architecture Specification

Complete specification:
```
Matrix[N × (S + R)] where:
- N = number of players
- S = 11 starting slots
- R = number of REST slots (N - S or 1?)

Cost[p][s] = ...
Cost[p][REST] = ...
```

### B. Cost Formula Hierarchy

Final formula with all components:
```
For playing slots:
  Cost[p][s] = f(Utility, ShadowCost, StabilityCost, constraints)

For REST slots:
  Cost[p][REST] = g(RestUtility, constraints)
```

### C. Parameter Tables

**REST Utility Parameters**:
| Importance | α | β | γ | δ |
|------------|---|---|---|---|
| High | ? | ? | ? | ? |
| Medium | ? | ? | ? | ? |
| Low | ? | ? | ? | ? |
| Sharpness | ? | ? | ? | ? |

**Constraint Constants**:
| Constant | Value | Purpose |
|----------|-------|---------|
| FORBIDDEN | ? | Cost for forbidden assignments |
| MAX_UTILITY | ? | Transformation constant |
| LOCK_BONUS | ? | Bonus for locked assignments |

### D. Failure Mode Prevention

For each failure mode:
1. "Everyone rests" - prevention mechanism
2. "No one rests" - prevention mechanism
3. "Infeasible constraints" - detection and handling
4. "Hungarian assigns forbidden" - verification step

### E. Implementation Pseudocode

Complete algorithm:
```python
def build_cost_matrix(players, slots, constraints, mode, ...):
    # Step 1: Initialize matrix
    # Step 2: Fill playing costs
    # Step 3: Fill REST costs
    # Step 4: Apply constraints
    # Step 5: Normalize
    return cost_matrix

def solve_and_verify(cost_matrix, ...):
    # Solve
    # Verify no forbidden assignments
    # Handle infeasibility
    return assignments
```

### F. Worked Examples

Example 1: 14 players, 11 slots, no constraints
Example 2: 25 players, 2 injured, 1 user lock
Example 3: All-tired squad (testing REST behavior)
Example 4: Conflicting constraints (detection)

## Validation Criteria

The architecture is successful if:
- Matrix construction is deterministic and unambiguous
- REST slots produce sensible rotation (not too much, not too little)
- All constraint types are properly encoded
- Edge cases (all injured, conflicts) are handled gracefully
- Performance is acceptable (< 100ms for 40 players)

## Output Format

1. **Architecture Diagram**: Visual representation of matrix structure
2. **Complete Formulas**: Every cost calculation defined
3. **Parameter Values**: All constants with justification
4. **Pseudocode**: Implementation-ready algorithm
5. **Test Cases**: Expected outputs for specific inputs
