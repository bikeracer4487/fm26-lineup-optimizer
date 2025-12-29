# Implementation Plan: Code Changes from Research

## Overview

This document translates research findings into staged code changes. It is updated as research steps complete.

**Status**: TEMPLATE - Updated after each research step

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
- Validate against test scenarios
- Regression test everything

### 4. Documentation Updates
- Update CLAUDE.md with final specifications
- Remove conflicting documentation
- Keep single source of truth

---

## Code Files Affected

### Core Algorithm Files

| File | Status | Changes Planned |
|------|--------|-----------------|
| `scoring_parameters.py` | Exists | Parameter value updates |
| `ui/api/scoring_model.py` | Exists | Multiplier formula refinements |
| `ui/api/state_simulation.py` | Exists | Propagation equation calibration |
| `ui/api/shadow_pricing.py` | Exists | Formula revision |
| `ui/api/stability.py` | Exists | Parameter tuning |

### Supporting System Files

| File | Status | Changes Planned |
|------|--------|-----------------|
| `ui/api/api_match_selector.py` | Exists | Hungarian matrix refactoring |
| `ui/api/api_training_advisor.py` | Exists | New algorithm implementation |
| `ui/api/api_player_removal.py` | Exists | New decision model |
| `ui/api/api_rest_advisor.py` | Exists | Policy implementation |
| `ui/api/explainability.py` | Exists | Template updates |

### Test Files

| File | Status | Changes Planned |
|------|--------|-----------------|
| `tests/test_validation_scenarios.py` | Exists | New test scenarios |
| `tests/test_scoring_model.py` | New | Unit tests for multipliers |
| `tests/test_state_simulation.py` | New | Propagation tests |
| `tests/test_calibration.py` | New | Calibration harness |

---

## Staged Implementation Plan

### Stage 1: Parameter Consolidation
**Dependencies**: Research Steps 1-2 complete
**Estimated Effort**: 2-3 hours

**Changes**:
1. Update `scoring_parameters.py` with unified values
2. Remove conflicting parameter definitions
3. Add inline documentation citing research

**Files Modified**:
- `scoring_parameters.py`

**Validation**:
- All existing tests pass
- Manual spot-check of multiplier outputs

---

### Stage 2: Scoring Model Updates
**Dependencies**: Stage 1 complete
**Estimated Effort**: 3-4 hours

**Changes**:
1. Update multiplier formulas in `scoring_model.py`
2. Ensure bounded sigmoid implementations match spec
3. Update sharpness calculation (power curve vs sigmoid decision)

**Files Modified**:
- `ui/api/scoring_model.py`

**Validation**:
- New unit tests for each multiplier
- Compare outputs to worked examples from research

---

### Stage 3: State Simulation Calibration
**Dependencies**: Research Step 3 complete
**Estimated Effort**: 2-3 hours

**Changes**:
1. Update propagation equations in `state_simulation.py`
2. Calibrate drain/recovery rates
3. Fix any position-specific rates

**Files Modified**:
- `ui/api/state_simulation.py`

**Validation**:
- Multi-match trajectory tests
- Verify condition/sharpness/fatigue projections

---

### Stage 4: Hungarian Matrix Refactoring
**Dependencies**: Research Step 4 complete, Stages 2-3
**Estimated Effort**: 4-5 hours

**Changes**:
1. Finalize REST slot implementation
2. Update cost matrix construction
3. Ensure constraint encoding is correct

**Files Modified**:
- `ui/api/api_match_selector.py`

**Validation**:
- All constraint scenarios pass
- REST behavior matches specification

---

### Stage 5: Shadow Pricing Revision
**Dependencies**: Research Step 5 complete, Stage 4
**Estimated Effort**: 2-3 hours

**Changes**:
1. Update shadow cost formula
2. Integrate with cost matrix correctly
3. Tune discount factor and weight

**Files Modified**:
- `ui/api/shadow_pricing.py`

**Validation**:
- Cup Final Protection scenario passes
- Shadow costs are sensible scale

---

### Stage 6: Fatigue & Rest Policy
**Dependencies**: Research Step 6 complete
**Estimated Effort**: 3-4 hours

**Changes**:
1. Implement rest policy decision tree
2. Add vacation recommendation logic
3. Update fatigue thresholds

**Files Modified**:
- `ui/api/api_rest_advisor.py`
- `ui/api/state_simulation.py`

**Validation**:
- Jadedness prevention scenarios
- Rest recommendations match policy

---

### Stage 7: Training Recommender
**Dependencies**: Research Step 7 complete
**Estimated Effort**: 4-5 hours

**Changes**:
1. Implement gap analysis algorithm
2. Add suitability scoring
3. Create timeline estimation
4. Build recommendation output

**Files Modified**:
- `ui/api/api_training_advisor.py`

**Validation**:
- Training recommendations are sensible
- Timeline estimates are reasonable

---

### Stage 8: Player Removal Model
**Dependencies**: Research Step 8 complete
**Estimated Effort**: 4-5 hours

**Changes**:
1. Implement contribution scoring
2. Add future value assessment
3. Create protection rules
4. Build decision tree

**Files Modified**:
- `ui/api/api_player_removal.py`

**Validation**:
- Removal recommendations protect critical players
- Financial analysis is reasonable

---

### Stage 9: Match Importance Automation
**Dependencies**: Research Step 9 complete
**Estimated Effort**: 2-3 hours

**Changes**:
1. Implement base importance table
2. Add modifiers (opponent, position, schedule)
3. Create suggestion output

**Files New**:
- `ui/api/match_importance.py`

**Validation**:
- Importance suggestions match expectations
- Sharpness mode detection works

---

### Stage 10: Validation Suite
**Dependencies**: Research Step 10 complete
**Estimated Effort**: 4-5 hours

**Changes**:
1. Implement all test scenarios
2. Add metrics calculations
3. Create calibration harness
4. Build test runner

**Files Modified/New**:
- `tests/test_validation_scenarios.py`
- `tests/calibration_harness.py`

**Validation**:
- All scenarios have pass/fail criteria
- Harness runs successfully

---

### Stage 11: Parameter Calibration Execution
**Dependencies**: Stage 10 complete
**Estimated Effort**: 2-3 hours (mostly waiting for runs)

**Changes**:
1. Run calibration harness
2. Apply calibrated parameters
3. Document final values

**Files Modified**:
- `scoring_parameters.py`

**Validation**:
- Cross-validation passes
- Parameters improve aggregate score

---

### Stage 12: Documentation & Cleanup
**Dependencies**: All stages complete
**Estimated Effort**: 2-3 hours

**Changes**:
1. Update CLAUDE.md with final specifications
2. Remove/archive old research documents
3. Add code comments referencing specs
4. Update README if needed

**Files Modified**:
- `CLAUDE.md`
- Various code files (comments)
- `README.md`

**Validation**:
- CLAUDE.md is single source of truth
- No conflicting documentation remains

---

## Pull Request Strategy

### PR 1: Parameter Foundation
**Stages**: 1
**Description**: Consolidate parameters, no behavioral changes
**Risk**: Low
**Reviewers**: N/A (solo project)

### PR 2: Scoring Model
**Stages**: 2, 3
**Description**: Core algorithm updates
**Risk**: Medium (affects all selections)
**Validation**: Full test suite

### PR 3: Assignment Matrix
**Stages**: 4, 5
**Description**: Hungarian and shadow pricing updates
**Risk**: Medium-High
**Validation**: Scenario testing

### PR 4: Support Systems
**Stages**: 6, 7, 8, 9
**Description**: Advisor improvements
**Risk**: Low (independent features)
**Validation**: Feature-specific tests

### PR 5: Validation & Calibration
**Stages**: 10, 11
**Description**: Test infrastructure and tuning
**Risk**: Low
**Validation**: Self-validating

### PR 6: Documentation
**Stage**: 12
**Description**: Final cleanup
**Risk**: None
**Validation**: Review only

---

## Rollback Plan

If issues are discovered after deployment:

1. **Immediate**: Revert to previous parameter values
2. **Short-term**: Feature flag to disable new code path
3. **Medium-term**: Investigate root cause, fix, re-deploy

### Feature Flags (if needed)

```python
FEATURE_FLAGS = {
    'use_new_scoring_model': True,
    'use_calibrated_params': True,
    'new_shadow_pricing': True,
    'new_rest_policy': True,
}
```

---

## Progress Tracking

| Stage | Status | Started | Completed | Notes |
|-------|--------|---------|-----------|-------|
| 1 | Not Started | - | - | |
| 2 | Not Started | - | - | |
| 3 | Not Started | - | - | |
| 4 | Not Started | - | - | |
| 5 | Not Started | - | - | |
| 6 | Not Started | - | - | |
| 7 | Not Started | - | - | |
| 8 | Not Started | - | - | |
| 9 | Not Started | - | - | |
| 10 | Not Started | - | - | |
| 11 | Not Started | - | - | |
| 12 | Not Started | - | - | |

---

## Post-Implementation Monitoring

After all changes are deployed:

1. **User Feedback**: Collect reports of unexpected selections
2. **Performance Metrics**: Track computation time
3. **Regression Watch**: Monitor for any issues
4. **Parameter Tuning**: Adjust based on real-world usage

---

*Last Updated: 2025-12-29*
*Will be updated as research steps complete*
