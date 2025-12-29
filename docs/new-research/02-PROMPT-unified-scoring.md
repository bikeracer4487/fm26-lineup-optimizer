# Research Prompt 02: Unified Scoring Model Specification

## Context

We have FOUR existing research documents that each specify different parameters for the same scoring multipliers. This has created implementation confusion and potential bugs. We need ONE authoritative specification that reconciles these differences.

### Current Conflict Summary

**Condition Multiplier Parameters:**
| Document | Floor (α) | Threshold (T) | Steepness (k) |
|----------|-----------|---------------|---------------|
| FM26 #1 | Not specified | 80% | Not specified |
| FM26 #2 | 0.40 | 75% | 0.12 |
| FM26 #3 | 0.50 | 70% | 0.10 |
| FM26 #4 | 0.60 | 75% | 0.12 |

**Sharpness Approach:**
| Document | Method |
|----------|--------|
| FM26 #1 | Piecewise linear with "build mode" |
| FM26 #2 | Power curve: Ψ = 0.40 + 0.60 × (Sh/100)^0.8 |
| FM26 #3 | Logistic sigmoid with k=0.08-0.12 |
| FM26 #4 | Logistic sigmoid (different params) |

## Research Objective

**Goal**: Produce ONE definitive scoring model specification with justified parameter choices that supersedes all previous documents.

## Our Current Scoring Model

The utility of Player $i$ in Slot $s$ is:

$$U_{i,s} = B_{i,s} \times \Phi(C) \times \Psi(Sh) \times \Theta(Fam) \times \Lambda(F)$$

Where:
- $B_{i,s}$: Base Effective Rating (Harmonic Mean of IP/OOP roles)
- $\Phi$: Condition Multiplier
- $\Psi$: Sharpness Multiplier
- $\Theta$: Familiarity Multiplier
- $\Lambda$: Fatigue Multiplier

All multipliers use bounded sigmoid: $\alpha + (1 - \alpha) \times \sigma(k \times (x - T))$

## Questions to Resolve

### 1. Condition Multiplier Φ(C)
Given the FM26 mechanics findings from Step 1:
- What should the floor (α) be for each importance level?
- At what condition threshold (T) should penalties begin?
- How steep (k) should the transition be?
- Should we use sigmoid, piecewise, or another form?

**Constraints**:
- α must be > 0 (emergency utility never zero)
- High importance should tolerate lower condition (critical matches need best XI)
- Low importance should have stricter thresholds (preserve players)

### 2. Sharpness Multiplier Ψ(Sh)
- Should we use power curve or sigmoid?
- What matches FM's internal sharpness-performance relationship better?
- How should "Sharpness Build Mode" work? (prioritize rusty players)
- Should sharpness multiplier ever exceed 1.0?

**Trade-offs**:
- Power curve: Matches research showing diminishing returns at high sharpness
- Sigmoid: Provides smooth bounded transitions, consistent with other multipliers
- Build mode: Needs to boost low-sharpness players without being too aggressive

### 3. Familiarity Multiplier Θ(Fam)
- What is the minimum acceptable familiarity for each importance level?
- How severely should we penalize "Unconvincing" (6-9) players?
- Should "Awkward" (1-5) players ever be selected?

**FM26 Familiarity Tiers** (verify from Step 1):
- Natural: 19-20
- Accomplished: 13-18
- Competent: 10-12
- Unconvincing: 6-9
- Awkward: 1-5

### 4. Fatigue Multiplier Λ(F, T)
- How should player-specific threshold T be calculated?
- What factors affect threshold (age, NF, stamina, injury proneness)?
- At what fatigue/threshold ratio do penalties become severe?

### 5. Cross-Multiplier Interactions
- Do any multipliers interact in ways we're not modeling?
- Should condition and fatigue compound (double jeopardy) or should one dominate?
- Are there edge cases where the multiplicative model fails?

## Expected Deliverables

### A. Unified Parameter Tables
For each importance level (High, Medium, Low, Sharpness):

**Condition Φ**:
| Importance | α (floor) | T (threshold) | k (slope) | Rationale |
|------------|-----------|---------------|-----------|-----------|

**Sharpness Ψ**:
| Importance | Form | Parameters | Rationale |
|------------|------|------------|-----------|

**Familiarity Θ**:
| Importance | α (floor) | T (threshold) | k (steepness) | Rationale |
|------------|-----------|---------------|---------------|-----------|

**Fatigue Λ**:
| Importance | α (collapse) | r (ratio) | k (steepness) | Rationale |
|------------|--------------|-----------|---------------|-----------|

### B. Decision Rationale
For each parameter choice, explain:
- Why this value vs the alternatives in existing docs
- What FM behavior it models
- Sensitivity: how much does changing it by 10% matter?

### C. Worked Examples
Provide 4-5 worked examples showing:
- A peak-condition star player in High importance match
- A tired player being considered for Low importance match
- A rusty player being considered for Sharpness mode
- An out-of-position player in emergency cover
- A polyvalent player with options

### D. Edge Case Behavior
Specify what happens when:
- All players are tired (condition < 80%)
- No players have high familiarity for a position
- A player is jaded AND in poor condition
- Two players have near-identical utility

### E. Sharpness Build Mode Specification
Complete specification of how Sharpness mode works:
- Which players should be prioritized?
- What multiplier values to use?
- How does it interact with condition/fatigue?

## Validation Criteria

The unified model is successful if:
- There is ONE set of parameters per importance level
- All parameters have documented rationale
- Edge cases produce sensible results
- The model can be implemented without interpretation questions

## Output Format

1. **Recommended Parameters**: Final authoritative tables
2. **Rationale Document**: Justification for each decision
3. **Worked Examples**: Calculations showing expected behavior
4. **Implementation Notes**: Specific guidance for coding
5. **Deprecation Notes**: Which old parameter sets to remove
