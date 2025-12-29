# FM26 Lineup Optimizer - Master Research Plan

## Executive Summary

This document coordinates a systematic research program to correct and enhance all algorithms in the FM26 Lineup Optimizer. Previous research efforts (documents #1-#4) provided good conceptual frameworks but suffer from:

1. **Parameter Inconsistency**: Each document uses different values for the same functions
2. **Formula Variations**: Sharpness uses power curve in one doc, sigmoid in others
3. **Missing Validation**: No consolidated, tested parameter set
4. **Implementation Drift**: Current code may not match any specification exactly
5. **Incomplete Coverage**: Training, removal, rest policies lack detailed specifications

## Current State Assessment

### Documents Reviewed

| Document | Focus | Status | Key Issues |
|----------|-------|--------|------------|
| FM26 #1 | System Spec + Decision Model | Theoretical foundation | Good conceptual framework, but needs practical calibration |
| FM26 #2 | Complete Mathematical Spec | Detailed formulas | Parameters conflict with #3 and #4 |
| FM26 #3 | Lineup Optimization System | Implementation guide | Different multiplier approach than #2 |
| FM26 #4 | Hungarian Algorithm Spec | Ready-to-code spec | Yet another parameter set, most detailed |

### Critical Inconsistencies Found

#### Condition Multiplier Parameters
| Document | High α | High T | High k |
|----------|--------|--------|--------|
| #1 | Not specified | 80% | Not specified |
| #2 | 0.40 | 75% | 0.12 |
| #3 | 0.50 (Φ_min) | 70 | 0.10 |
| #4 | 0.60 | 75 | 0.12 |

#### Sharpness Approach
| Document | Approach |
|----------|----------|
| #1 | Piecewise (build mode) |
| #2 | Power curve (Ψ = 0.40 + 0.60 × (Sh/100)^0.8) |
| #3 | Logistic sigmoid |
| #4 | Logistic sigmoid (different params) |

### Implementation Status

| Component | Research Doc | Code File | Status |
|-----------|--------------|-----------|--------|
| Scoring Model | #2 | `scoring_model.py` | Partially aligned |
| State Simulation | #2 | `state_simulation.py` | Implemented |
| Shadow Pricing | #1, #2, #3 | `shadow_pricing.py` | Needs review |
| Stability | #2 | `stability.py` | Needs review |
| Training Advisor | None | `api_training_advisor.py` | Needs specification |
| Player Removal | None | `api_player_removal.py` | Needs specification |
| Rest Advisor | #1 (partial) | `api_rest_advisor.py` | Needs specification |

---

## Research Program Structure

### Phase 1: Core Algorithm Correction (Steps 1-4)
Establish accurate, validated formulas for the lineup selection core.

### Phase 2: Multi-Match Planning (Steps 5-6)
Perfect the 5-match horizon optimization and fatigue management.

### Phase 3: Supporting Systems (Steps 7-9)
Define algorithms for training, rest, and player removal recommendations.

### Phase 4: Validation & Calibration (Steps 10-11)
Create testing framework and tune parameters.

### Phase 5: Implementation (Step 12)
Staged code changes with minimal risk.

---

## Research Steps Overview

| Step | Title | Goal | Priority | Dependencies |
|------|-------|------|----------|--------------|
| 1 | FM26 Game Mechanics Deep Dive | Ground-truth verification of FM26 mechanics | Critical | None |
| 2 | Unified Scoring Model | Reconcile multiplier inconsistencies | Critical | Step 1 |
| 3 | State Propagation Calibration | Accurate condition/sharpness/fatigue simulation | Critical | Step 1 |
| 4 | Hungarian Matrix Architecture | Finalize cost matrix structure with REST slots | High | Steps 2, 3 |
| 5 | Shadow Pricing Formula | Multi-match opportunity cost calculation | High | Step 4 |
| 6 | Fatigue Dynamics & Rest Policy | Thresholds, recovery, vacation recommendations | High | Steps 1, 3 |
| 7 | Position Training Recommender | Tactical gap analysis and training priorities | Medium | Step 2 |
| 8 | Player Removal Model | Multi-factor sell/loan/release decisions | Medium | None |
| 9 | Match Importance Scoring | Automatic importance classification | Medium | None |
| 10 | Validation Test Suite | Offline evaluation metrics and test cases | High | Steps 2-6 |
| 11 | Parameter Calibration | Grid search and sensitivity analysis | High | Step 10 |
| 12 | Implementation Plan | Staged code changes and refactors | Final | Steps 2-11 |

---

## How This Research Program Works

### For Each Step:

1. **Preparation**: Review what we currently have and identify gaps
2. **Research Prompt**: Feed the prompt into a deep research AI
3. **Document Upload**: Save results to `docs/new-research/` with naming convention:
   - `FM26 #X - [Title].md` for research results
4. **Analysis**: Claude reviews results and identifies follow-up questions
5. **Iteration**: Refine if needed, then proceed to implementation notes
6. **Progress Update**: Mark step complete in `00-PROGRESS-TRACKER.md`

### Prompt Design Principles:

- **Specificity**: Each prompt targets ONE clear deliverable
- **Context**: Includes relevant FM26 mechanics and constraints
- **Validation Criteria**: Specifies what "success" looks like
- **Format**: Requests implementation-ready outputs (tables, formulas, pseudocode)
- **Cross-Reference**: References our existing code and data structures

---

## Files In This Research Directory

| File | Purpose |
|------|---------|
| `00-RESEARCH-MASTER-PLAN.md` | This document - overall coordination |
| `00-PROGRESS-TRACKER.md` | Status of each research step |
| `01-PROMPT-fm26-mechanics.md` | Deep dive into FM26 game mechanics |
| `02-PROMPT-unified-scoring.md` | Unified scoring model specification |
| `03-PROMPT-state-propagation.md` | State simulation calibration |
| `04-PROMPT-hungarian-matrix.md` | Cost matrix architecture |
| `05-PROMPT-shadow-pricing.md` | Multi-match shadow pricing |
| `06-PROMPT-fatigue-rest.md` | Fatigue dynamics and rest policy |
| `07-PROMPT-training-recommender.md` | Position training algorithm |
| `08-PROMPT-player-removal.md` | Sell/loan/release model |
| `09-PROMPT-match-importance.md` | Automatic importance scoring |
| `10-PROMPT-validation-suite.md` | Test case and metrics design |
| `11-PROMPT-calibration.md` | Parameter tuning methodology |
| `12-IMPLEMENTATION-PLAN.md` | Code change roadmap |
| `FM26 #1-4...` | Existing research (to be superseded) |
| `FM26 #5+...` | New research results (as produced) |

---

## Success Criteria

The research program is complete when:

1. **Single Source of Truth**: One consolidated specification with no conflicting values
2. **Validated Parameters**: All multipliers tested against expected behavior
3. **Complete Coverage**: Every algorithm (lineup, training, rest, removal) is specified
4. **Implementation Ready**: Clear pseudocode that maps directly to code changes
5. **Test Suite**: Automated validation that prevents regression
6. **Documentation**: CLAUDE.md updated to reflect final specifications

---

## Next Steps

1. Review `00-PROGRESS-TRACKER.md` for current status
2. Read the research prompt for the current active step
3. Execute the prompt in a deep research AI
4. Upload results and proceed through the workflow

---

*Last Updated: 2025-12-29*
*Research Coordinator: Claude Code*
