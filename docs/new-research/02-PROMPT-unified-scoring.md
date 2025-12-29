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
- $\Theta$: Familiarity Multiplier (now must be DUAL: IP + OOP)
- $\Lambda$: Fatigue/Jadedness Multiplier

All multipliers use bounded sigmoid: $\alpha + (1 - \alpha) \times \sigma(k \times (x - T))$

## CRITICAL: Findings from FM26 Mechanics Research (Step 1)

The following verified findings MUST inform parameter choices:

### Scale Clarification
- **Condition**: Internal 0-10,000 scale (UI shows hearts, not percentages)
- **Sharpness**: Internal 0-10,000 scale (Green tick = >8,000, Orange = <7,000)
- **Our multipliers should work on 0-100 percentage scale** (divide by 100)

### Verified Thresholds
| Metric | Value | Meaning |
|--------|-------|---------|
| Condition 9,200+ (92%) | "Match Fit" | No micro-inefficiencies |
| Condition 9,500+ (95%) | "Peak" | Full attribute access |
| Condition <6,100 (61%) | "Critical" | Exponential injury risk |
| Sharpness >8,000 (80%) | "Sharp" | Green tick |
| Sharpness <7,000 (70%) | "Lacking" | Orange warning |
| Sharpness decay | 3-5% per day | "Seven-Day Cliff" phenomenon |

### Dual-Familiarity Requirement
FM26 evaluates familiarity for BOTH IP and OOP positions. The research suggests:
$$S_{composite} = (W_{IP} \times S_{IP}) + (W_{OOP} \times S_{OOP}) - C_{transition}$$

Our familiarity multiplier must account for this dual evaluation.

## Questions to Resolve

### 1. Condition Multiplier Φ(C)
Given the FM26 mechanics findings from Step 1:
- What should the floor (α) be for each importance level?
- At what condition threshold (T) should penalties begin?
- How steep (k) should the transition be?
- Should we use sigmoid, piecewise, or another form?

**VERIFIED THRESHOLDS from Step 1**:
- 92% = "Match Fit" (no micro-inefficiencies)
- 95% = "Peak" (full attribute access)
- 61% = "Critical" (exponential injury risk)
- Previous docs used 75-88% thresholds - these appear TOO LOW

**Constraints**:
- α must be > 0 (emergency utility never zero)
- High importance: threshold should be ~85-90% (tolerate some tiredness for key matches)
- Medium importance: threshold should be ~90-92% (standard "match fit")
- Low importance: threshold should be ~92-95% (only peak condition players)

### 2. Sharpness Multiplier Ψ(Sh)
- Should we use power curve or sigmoid?
- What matches FM's internal sharpness-performance relationship better?
- How should "Sharpness Build Mode" work? (prioritize rusty players)
- Should sharpness multiplier ever exceed 1.0?

**CRITICAL FINDING from Step 1 - "Seven-Day Cliff"**:
- Sharpness decays 3-5% PER DAY without match play (much faster than FM24!)
- Players need 45-60 minutes per week MINIMUM to maintain sharpness
- Green tick = >80%, Orange = <70%
- Low sharpness affects "decision latency" - mental attributes execute slower

**Trade-offs**:
- Power curve: Matches research showing diminishing returns at high sharpness
- Sigmoid: Provides smooth bounded transitions, consistent with other multipliers
- Build mode: Now MORE CRITICAL due to aggressive decay - must prioritize rusty players aggressively

**New constraint**: Sharpness penalties should be MORE SEVERE than in previous docs given the "latency" effect on Decisions attribute

### 3. Familiarity Multiplier Θ(Fam) - NOW DUAL IP/OOP
- What is the minimum acceptable familiarity for each importance level?
- How severely should we penalize "Unconvincing" (6-9) players?
- Should "Awkward" (1-5) players ever be selected?
- **NEW**: How do we combine IP and OOP familiarity into one multiplier?

**CRITICAL FINDING from Step 1 - Dual-Phase Evaluation**:
- FM26 evaluates familiarity for BOTH IP and OOP positions separately
- A player "Natural" at AMC (IP) but "Unconvincing" at MR (OOP) gets penalized during defensive transitions
- Penalty manifests as poor Positioning and Concentration
- Research suggests: $S_{composite} = (W_{IP} \times S_{IP}) + (W_{OOP} \times S_{OOP}) - C_{transition}$

**Proposed Approach**:
Instead of single familiarity value, calculate:
$$\Theta_{composite} = \min(\Theta(Fam_{IP}), \Theta(Fam_{OOP})) \times \beta$$
Or use weighted harmonic mean to penalize imbalance (similar to IP/OOP role ratings)

**FM26 Familiarity Tiers** (confirmed):
- Natural: 19-20
- Accomplished: 13-18 (OOP familiarity should be at least this)
- Competent: 10-12
- Unconvincing: 6-9 (triggers transition penalties)
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
