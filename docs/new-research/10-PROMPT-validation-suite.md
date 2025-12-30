# Research Prompt 10: Validation Test Suite

## Context

We need a systematic way to validate that our algorithms behave correctly without running the actual FM26 game. This requires:
1. Defined test scenarios with expected outcomes
2. Metrics to measure algorithm quality
3. Regression tests to prevent bugs

Current tests exist in `tests/test_validation_scenarios.py` but need expansion.

## CRITICAL: Findings from Steps 1 & 2

### GSS Formula (Step 2)
All validation must use the finalized Global Selection Score:
$$GSS = BPS \times \Phi(C) \times \Psi(S) \times \Theta(F) \times \Omega(J)$$

### Key Thresholds to Validate
| Metric | Threshold | Rule |
|--------|-----------|------|
| Condition | 91% | Never start player below this ("91% Floor") |
| Sharpness | 85% | Below this, prefer reserves first ("85% Gate") |
| 10-day minutes | 270 | Above this, apply 0.85 penalty ("270-min Rule") |
| Fatigue state | Jaded | Ω = 0.4 penalty (step function) |

### Multiplier Formulas to Test
- **Condition**: $\Phi(c) = \frac{1}{1 + e^{-25(c - 0.88)}}$ (steep sigmoid, k=25)
- **Sharpness**: $\Psi(s) = \frac{1.02}{1 + e^{-15(s - 0.75)}} - 0.02$
- **Familiarity**: $\Theta(f) = 0.7 + 0.3f$ (LINEAR)
- **Fatigue**: $\Omega(J) = \{1.0, 0.9, 0.7, 0.4\}$ (step function)

## CRITICAL: Findings from State Propagation Research (Step 3)

### Positional Drag Coefficients to Validate
| Position | R_pos | Test Focus |
|----------|-------|------------|
| GK | 0.2 | Should rarely trigger fatigue issues |
| CB | 0.9-1.0 | Can play consecutive without issues |
| Fullback/WB | **1.65** | Should trigger rotation in congested fixtures |

### Sharpness "Seven-Day Cliff" Model
- Day 0-3: No decay
- Day 4-6: ~1-2%/day
- Day 7+: **5-8%/day** (cliff)

**Test**: Player resting 10 days should show severe sharpness decay (40-50% drop from peak)

### 270-Minute Rule (REFINED)
- Window: **14 days** (not 10)
- Multiplier: **2.5x** jadedness when exceeded

**Test**: Player at 270+ mins in 14-day window should trigger jadedness warnings

## CRITICAL: Findings from Hungarian Matrix Research (Step 4)

### Two-Stage Algorithm Tests
1. **Stage 1 (Starting XI)**: Verify optimal 11 selected using Peak Utility
2. **Stage 2 (Bench)**: Verify bench uses Coverage Utility (versatility rewarded)

**Test**: Versatile player (4+ positions) should be selected for bench over specialist with higher CA

### Safe Big M Validation
- Forbidden assignments should use Big M = 10^6 (not infinity)
- **Test**: Verify solver doesn't crash with forbidden slots

### Multi-Objective Scalarization Tests
| Scenario | Expected Behavior |
|----------|-------------------|
| Cup Final (w1=1.0) | Best XI regardless of fatigue |
| Dead Rubber (w2=0.5) | Youth players prioritized |
| League Grind (w3=0.3) | Rotation triggered for tired players |

### Condition Cliff Heuristic Tests
| Condition | Expected Multiplier |
|-----------|---------------------|
| 96% | 1.00 (Peak) |
| 92% | 0.95 (Startable) |
| 82% | 0.80 (Risk) |
| 72% | Big M (Forbidden) |

### Switching Cost Tests
**Test**: Player changing position from previous match should incur penalty

### Lagrangian Relaxation Tests
**Test**: "Min 4 Club-Grown" quota should be satisfied via iterative subsidy

## CRITICAL: Findings from Shadow Pricing Research (Step 5)

### Shadow Pricing Validation Tests
1. **Trajectory Bifurcation**: Verify GSS(rest) vs GSS(play) correctly projected
2. **VORP Scarcity**: Key player (Gap% > 10%) has higher shadow cost than non-key
3. **Discount Factor**: γ=0.85 correctly decays future match influence
4. **Importance Weighting**: Cup Final (10.0) overrides 4 Low matches (0.8 each)

### Shadow Pricing Test Parameters
| Parameter | Default | Test Values |
|-----------|---------|-------------|
| γ (discount) | 0.85 | 0.70, 0.85, 0.95 |
| λ_shadow | 1.0 | 0.5, 1.0, 2.0 |
| λ_V (scarcity) | 2.0 | 1.0, 2.0, 3.0 |

### Importance Weights (NEW from Step 5)
| Scenario | Weight | Test Implication |
|----------|--------|------------------|
| Cup Final | 10.0 | Should override all prior matches |
| Continental KO | 5.0 | Strong preservation trigger |
| Title Rival | 3.0 | Moderate shadow increase |
| Standard League | 1.5 | Baseline weight |
| Cup (Early) | 0.8 | Below baseline |
| Dead Rubber | 0.1 | Near-zero weight |

### Additional Scenario: Shadow Pricing Effectiveness
**Scenario 2b: Shadow Price Calculation Verification**
- **Setup**: Same as Cup Final Protection (L,L,L,L,H)
- **Expected**: Shadow cost for star at Match 1 > utility at Match 1
- **Validation**:
  - `shadow_cost_match_1` > `current_utility` for key players
  - Star player rested in matches 3-4 due to shadow cost
  - Star player at 98%+ condition for Cup Final

### VORP Scarcity Index Test
**Scenario**: Two players at same position
- Player A: GSS = 85, Backup GSS = 60 → Gap% = 29% → Key Player
- Player B: GSS = 75, Backup GSS = 72 → Gap% = 4% → Not Key
- **Expected**: Shadow cost(A) > Shadow cost(B) by factor of ~1.5x

## CRITICAL: Findings from Fatigue Dynamics Research (Step 6)

### Dual-Variable Fatigue Model Tests
1. **Condition vs Jadedness**: Player with 95% Condition but J=600 should be flagged "Tired"
2. **270-Minute Trigger**: Player at 270+ mins in 14-day window should trigger 2.5x jadedness accumulation
3. **Holiday Protocol**: "Rst" status player → recommend Holiday, not just bench rest

### Jadedness Threshold Tests
| State | J Range | Expected Ω | Test Case |
|-------|---------|------------|-----------|
| Fresh | 0-200 | 1.00 | Player just returned from vacation |
| Match Fit | 201-400 | 0.90 | Regular rotation player |
| Tired | 401-700 | 0.70 | 3 matches in 10 days |
| Jaded | 701+ | 0.40 | "Rst" icon visible |

### Player Archetype Tests
**Scenario 9: Archetype-Specific Thresholds**
- **Glass Cannon** (Inj Prone >12): Should trigger rest at 180 mins/14d (not 270)
- **Veteran (30+)**: Should flag "risky" for midweek-weekend double header
- **Workhorse** (NF 15+): Can exceed 270 occasionally without immediate penalty
- **Youngster (<19)**: Flag if >25 starts approaching (development concern)

### Training Integration Tests
**Scenario 10: Death Spiral Detection**
- **Setup**: Player on "Double Intensity" with 2 matches this week
- **Expected**: System warns of irrecoverable fatigue debt
- **Validation**: `training_intensity_warning` = True

### Holiday Protocol Validation
**Scenario 11: Jadedness Recovery**
- **Setup**: Player with "Rst" status (J > 700)
- **Action A**: Bench for 1 match (stays at club)
- **Action B**: Send on Holiday (1 week)
- **Expected**: Action B reduces J by ~350 points vs ~35 for Action A
- **Validation**: `holiday_recovery_rate` ≈ 10x `bench_recovery_rate`

### Recovery Rate Tests
| Recovery Type | Points/Day | Test Validation |
|---------------|------------|-----------------|
| Holiday | ~50 | Player returns Fresh after 1 week (J: 700 → 350) |
| Rest at Club | ~5 | "Rst" status persists after 1 week bench |
| Training (Half) | ~3 | Slow recovery, sharpness maintained |
| Training (Double) | -10 | Jadedness INCREASES despite rest days |

## CRITICAL: Findings from Position Training Research (Step 7)

### Position Training Recommendation Tests

**Gap Severity Index (GSI) Validation**:
$$GSI = (Scarcity_{pos} \times Weight_{pos}) + InjuryRisk_{starter} + ScheduleDensity$$

| Test Case | Setup | Expected GSI | Notes |
|-----------|-------|--------------|-------|
| No LB backup | 1 Natural LB, 0 backups | High (>0.8) | Scarcity multiplier active |
| Deep CB pool | 4 Natural CBs, 2 backups | Low (<0.3) | No gap detected |
| Injury-prone starter | Natural fitness <10, Inj Prone >15 | Medium-High | Risk factor elevates |

### Euclidean Distance Candidate Selection Tests
**Scenario 12: Winger-to-Fullback Conversion**
- **Setup**: Need WB backup, squad has high-pace Winger with Work Rate 15+
- **Expected**: Winger recommended with Distance score < 5.0
- **Validation**: `candidate_distance` < threshold AND `pace > 14` AND `workrate > 13`

**Scenario 13: DM-to-CB Conversion (Mascherano Protocol)**
- **Setup**: CB gap, DM has Tackling 14+, Anticipation 13+, Passing 13+, JR > 12
- **Expected**: DM recommended as Class II conversion (12-20 weeks)
- **Validation**: `archetype_match` = "Mascherano" AND `difficulty_class` = 2

### Retraining Efficiency Ratio (RER) Tests
| Conversion | Expected RER | Result |
|------------|--------------|--------|
| DM → CB | High (>0.8) | Recommend (attribute overlap) |
| ST → Winger | Low (<0.4) | Reject (CA waste in Finishing/Heading) |
| AMC → ST (Firmino) | Medium (0.6-0.8) | Recommend conditionally |

### Age Plasticity Validation
| Age | Plasticity | Test Expectation |
|-----|------------|------------------|
| 18 | 1.0 | Class III conversions recommended |
| 25 | 0.7 | Only Class I-II recommended |
| 30 | 0.4 | Only Class I recommended |
| 33 | 0.1 | Emergency swaps only; Class II+ rejected |

### Familiarity Threshold Tests
| Status | Range | Expected Efficiency |
|--------|-------|---------------------|
| Natural | 18-20 | 1.00 (100%) |
| Accomplished | 15-17 | 0.95 (Match Ready) |
| Competent | 12-14 | 0.85 (Emergency Use) |
| Unconvincing | 9-11 | 0.70 |
| Awkward | 5-8 | 0.50 |

**Test**: Player at Familiarity 12 should have 85% efficiency multiplier

### Difficulty Class Timeline Tests
| Class | Description | Time (Weeks) | Test Validation |
|-------|-------------|--------------|-----------------|
| I (Fluid) | Same pitch area | 4-8 | LB→LWB in 6 weeks |
| II (Structural) | Different spatial | 12-20 | DM→CB in 16 weeks |
| III (Spatial) | Geography change | 24-36 | AMR→MC in 30 weeks |
| IV (Inversion) | Complete inversion | 52+/Impossible | ST→DR rejected |

### Strategic Archetype Protocol Tests
**Scenario 14: Archetype Detection**
- **Mascherano** (DM→CB): Tackling ≥14, Anticipation ≥13, JR >12
- **Lahm** (FB→DM): Decisions ≥15, Teamwork ≥14, Composure >13
- **Firmino** (AMC→ST): Work Rate ≥14, Technique ≥13, Off the Ball ≥13

**Validation**: System correctly identifies archetype and boosts priority score

### Opportunity Cost Tests
**Scenario 15: Depth Impact Check**
- **Setup**: Player is 3rd choice in current position (low opportunity cost)
- **Expected**: High conversion score (moving them doesn't create new gap)
- **Anti-case**: Star player (1st choice) recommended for conversion
- **Expected**: Penalty applied OR recommendation rejected

## CRITICAL: Findings from Player Removal Research (Step 8)

### Contribution Score Validation Tests

**Component Weight Validation**:
| Component | Weight | Test Focus |
|-----------|--------|------------|
| Effective Ability | 45% | Weighted role attributes, not raw CA |
| Reliability | 20% | Hidden attrs (Consistency, Important Matches, Pressure) |
| Performance | 25% | "Moneyball" metrics (Avg Rating) |
| Scarcity | 10% | Spine/left-foot premium |

**Scenario 16: Effective Ability vs Raw CA**
- **Setup**: Player A (CA 150, poor role fit), Player B (CA 130, perfect role fit)
- **Expected**: Player B has higher Contribution Score despite lower CA
- **Validation**: `contribution_score_B` > `contribution_score_A`

**Scenario 17: Reliability Coefficient**
- **Setup**: Player with Consistency 8, Important Matches 6, Pressure 7, Injury Proneness 15
- **Expected**: $R_{coef} < 0.7$ → "High Risk" flag
- **Formula**: $R = (0.4 \times 8 + 0.3 \times 6 + 0.3 \times 7) / 20 \times (1 - 0.25) = 0.41$
- **Validation**: `reliability_coefficient` < 0.7 AND `high_risk_flag` = True

**Scenario 18: Form Shield Protection**
- **Setup**: Player with low CA but Avg Rating > 7.20 over 20 matches
- **Expected**: "Form Shield" active, removal blocked
- **Validation**: `form_shield` = True AND `protected` = True

### Aging Curve Tests

**Position-Specific Peak Validation**:
| Position | Peak Start | Peak End | Decline | Test Case |
|----------|------------|----------|---------|-----------|
| GK | 29 | 34 | 35 | 33yo GK = "peak" |
| DL/DR | 25 | 29 | 30 | 30yo FB = "declining" |
| AM | 24 | 28 | 30 | 29yo AM = "declining" |

**Scenario 19: Peak Sell Timing**
- **Setup**: 29yo Winger (AM position), Peak End = 28
- **Expected**: `action_timing` = "sell_peak_value"
- **Validation**: Future value model recommends sale BEFORE decline

**Scenario 20: Rising vs Stagnating Youth**
- **Setup A**: 20yo with PA-CA = 30, recent progress rate = 0.8
- **Setup B**: 20yo with PA-CA = 30, recent progress rate = 0.3
- **Expected A**: `value_trend` = "increasing"
- **Expected B**: `value_trend` = "stagnating" (False Prospect flag)

### Financial Analysis Tests

**30-30-30-10 Wage Structure Validation**:
| Tier | Slots | Budget Share | Test Focus |
|------|-------|--------------|------------|
| Key | 4 | 30% | Top 4 by contribution |
| First Team | 7 | 30% | Ranks 5-11 |
| Rotation | 11 | 30% | Ranks 12-22 |
| Backup | 5 | 10% | Ranks 23+ |

**Scenario 21: Wage Efficiency Ratio**
- **Setup**: Player ranked #15 (Rotation tier), earning Key Player wages
- **Expected**: `wage_vs_tier_cap_ratio` > 1.5 → "Wage Dump" recommendation
- **Validation**: `recommendation` = "Urgent Wage Dump"

**Scenario 22: Book Value vs Market Value**
- **Setup**: Player bought for £50M, 3 years remaining on 5-year contract
- **Expected**: `book_value` = £30M
- **If** Market Value < Book Value → Recommend Loan (avoid loss)
- **Validation**: `amortization_check` flags financial risk

### Protection Rule Tests

**Scenario 23: Youth Protection Rules**
- **Setup**: 19yo with PA = 160, Professionalism = 15
- **Expected**: Protected (High Potential Asset)
- **Anti-case**: 19yo with PA = 160, Professionalism = 6, stalled development
- **Expected**: NOT Protected ("Ravel Morrison" rule)

**Scenario 24: Recent Signing Protection**
- **Setup**: Player signed 90 days ago
- **Expected**: Protected (Recent Signing, <180 days)
- **Validation**: `protection_type` = "Financial"

**Scenario 25: HGC Quota Critical**
- **Setup**: Squad has exactly 4 HGC players, considering removing one
- **Expected**: Protected (Registration Critical)
- **Validation**: `blocking_reason` = "HGC Quota Failure"

### Squad Balance Tests

**Scenario 26: Positional Depth Check**
- **Setup**: Only 2 players at LB position, considering removing one
- **Expected**: `blocking_issue` = True, removal blocked
- **Validation**: `depth_warnings` contains "Critical Lack of Depth at LB"

**Scenario 27: Leadership Void Risk**
- **Setup**: Removing team captain/leader
- **Expected**: Warning flagged (not blocking but noted)
- **Validation**: `depth_warnings` contains "Leadership Void Risk"

### Decision Gate Tests

**Gate Priority Order Validation**:
1. Deadwood (Priority 1): Low score + no potential
2. Financial Burden (Priority 2): Wage ratio > 1.4
3. Peak Sell (Priority 3): Decline imminent
4. Development Loan (Priority 4): Age <22, high PA, below threshold

**Scenario 28: Gate Prioritization**
- **Setup**: Player matches both Gate 2 (wage burden) and Gate 3 (peak sell)
- **Expected**: Classified as Priority 2 (higher priority gate wins)
- **Validation**: `priority` = 2, `reason` contains "Wage Efficiency"

### Youth Loan Policy Tests

**Scenario 29: Age-Based Youth Policy**
- **Setup A**: 17yo with high PA
- **Expected A**: KEEP (Club Grown accumulation, 15-21 window)
- **Setup B**: 19yo with high PA, <20 matches this season
- **Expected B**: LOAN (needs first team minutes)
- **Validation**: `action` reflects age-appropriate policy

## CRITICAL: Findings from Match Importance Research (Step 9)

### Final Importance Score (FIS) Validation Tests

**Master Formula**:
$$FIS = (Base \times M_{opp} \times M_{sched} \times M_{user}) + B_{context}$$

### Base Importance Table Tests

**Scenario 30: Competition Base Score Lookup**
| Test Case | Competition | Stage | Expected Base |
|-----------|-------------|-------|---------------|
| Title decider | League (Title Race) | Last 10 | 100 |
| Mid-table clash | League (Mid-Table) | Any | 60 |
| Dead rubber | League (Dead Rubber) | Last 5 | 20 |
| CL knockout | Champions League | R16+ | 95 |
| Cup early | Domestic Cup (Major) | Early | 40 |
| Friendly | Friendly | Any | 10 |

**Validation**: `get_competition_base_score()` returns correct values

### Opponent Strength Modifier Tests

**Scenario 31: Relative Strength Calculation**
- **Setup**: User Rep = 8000, Opponent Rep = 10500
- **Expected**: Rs = 10500/8000 = 1.31 → Classification = "Titan" → M_opp = 1.2x
- **Validation**: `opponent_modifier` = 1.2

**Scenario 32: Minnow Detection**
- **Setup**: User Rep = 9000, Opponent Rep = 4000
- **Expected**: Rs = 4000/9000 = 0.44 → Classification = "Minnow" → M_opp = 0.6x
- **Validation**: `opponent_modifier` = 0.6

| Rs Range | Classification | M_opp | Test Case |
|----------|----------------|-------|-----------|
| > 1.3 | Titan | 1.2x | Champions vs User |
| 0.9-1.1 | Peer | 1.0x | Same-tier opponent |
| < 0.6 | Minnow | 0.6x | Lower league cup opponent |

### Schedule Context Modifier Tests

**Scenario 33: 72-Hour Recovery Rule**
- **Setup**: League match Wednesday, CL Semi-Final Saturday (3 days gap)
- **Expected**: CL base ≥ 80 AND gap ≤ 3 → M_sched = 0.7x
- **Validation**: `schedule_modifier` = 0.7 AND `reasoning` contains "recovery"

**Scenario 34: Fixture Congestion (ACWR)**
- **Setup**: 3rd match in 7 days
- **Expected**: M_sched *= 0.8 (congestion penalty)
- **Validation**: `schedule_modifier` includes 0.8 multiplier

**Scenario 35: Freshness Bonus**
- **Setup**: 8 days since last match
- **Expected**: M_sched = 1.1x (freshness bonus)
- **Validation**: `schedule_modifier` = 1.1

| Condition | M_sched | Test Validation |
|-----------|---------|-----------------|
| Next High ≤3 days | 0.7x | 72-hour rule active |
| Next High = 4 days | 0.9x | Slight rotation |
| 3rd in 7 days | 0.8x | ACWR congestion |
| ≥7 days rest | 1.1x | Freshness bonus |

### Contextual Bonus Tests

**Scenario 36: Rivalry/Derby Bonus**
- **Setup**: Match flagged as derby, FIS = 60
- **Expected**: FIS += 20 → Final FIS = 80
- **Validation**: `is_derby` = True AND `fis_raw` increased by 20

**Scenario 37: Form Correction Bonus**
- **Setup**: Team on 4-match losing streak
- **Expected**: B_context += 15
- **Validation**: `losing_streak >= 3` triggers +15 bonus

**Scenario 38: Cup Run Bonus**
- **Setup**: User objective includes "Cup Glory", match is QF
- **Expected**: B_context += 10
- **Validation**: Bonus applied when `round >= QF` AND `objective_includes_cup`

| Bonus Type | Value | Trigger Condition |
|------------|-------|-------------------|
| Rivalry/Derby | +20 | `is_derby` = True |
| Form Correction | +15 | `losing_streak >= 3` |
| Cup Run | +10 | QF+ with Cup objective |

### FIS Threshold Classification Tests

**Scenario 39: Threshold Boundary Tests**
| FIS Score | Expected Level | Test Case |
|-----------|----------------|-----------|
| 95 | High | Title decider vs Titan |
| 85 | High | Boundary test (exactly 85) |
| 84 | Medium | Just below High threshold |
| 50 | Medium | Boundary test (exactly 50) |
| 49 | Low | Just below Medium threshold |
| 25 | Low | Dead rubber vs Minnow |

**Validation**: Classification matches threshold rules exactly

### Sharpness Detection Tests

**Scenario 40: Sharpness Override Logic**
- **Setup**: FIS = 30 (Low), 4 key players with sharpness < 70%, 7 days until next match
- **Expected**: `is_sharpness_candidate` = True → Level = "Sharpness"
- **Conditions Met**:
  1. FIS < 50? ✓ (30)
  2. Rusty key players >= 3? ✓ (4)
  3. sched_mod >= 1.0? ✓ (recovery time available)
- **Validation**: `level` = "Sharpness" AND `reasoning` mentions "match fitness"

**Scenario 41: Sharpness Rejected (Congestion)**
- **Setup**: FIS = 30, 4 rusty players, BUT sched_mod = 0.7 (CL in 3 days)
- **Expected**: `is_sharpness_candidate` = False (recovery time not available)
- **Validation**: `level` = "Low" (not Sharpness)

### Manager Profile Tests

**Scenario 42: Youth Developer Profile**
- **Setup**: Manager persona = "The Architect", Cup early round
- **Expected**: `user_mod` = 0.5 (secondary cup weight)
- **Impact**: FIS lowered, more likely to classify as Low → youth play

**Scenario 43: Glory Hunter Profile**
- **Setup**: Manager persona = "The Glory Hunter", Cup QF
- **Expected**: `user_mod` = 1.2 (cup weight)
- **Impact**: FIS elevated, more likely to classify as High

| Profile | League | Major Cup | Secondary Cup | Continental |
|---------|--------|-----------|---------------|-------------|
| Architect | 1.0 | 0.8 | 0.5 | 1.2 |
| Pragmatist | 1.3 | 0.6 | 0.6 | 0.6 |
| Glory Hunter | 1.0 | 1.2 | 1.0 | 1.2 |

### Integration Test Scenarios

**Scenario 44: Giant Killing Setup (Full Calculation)**
- **Setup**: FA Cup 3rd Round, PL team vs League Two, standard week
- **Calculation**: Base(40) × M_opp(0.6) × M_sched(1.0) = 24
- **Expected**: FIS = 24 → Level = "Low"
- **Validation**: Heavy rotation recommended

**Scenario 45: Congestion Crunch (Full Calculation)**
- **Setup**: League match (Contention), peer opponent, CL QF in 3 days
- **Calculation**: Base(80) × M_opp(1.0) × M_sched(0.7) = 56
- **Expected**: FIS = 56 → Level = "Medium"
- **Validation**: Partial rotation, not full strength

**Scenario 46: Must-Win Derby (Full Calculation)**
- **Setup**: Title race, derby match, team on losing streak
- **Calculation**: Base(100) × M_opp(1.0) × M_sched(1.0) + Derby(20) + Form(15) = 135
- **Expected**: FIS = 135 → Level = "High" (confident)
- **Validation**: Best XI mandatory, confidence meter = 100%

### Override Warning Tests

**Scenario 47: User Override Warning**
- **Setup**: System suggests High, user selects Low
- **Expected**: Warning modal displays with win probability delta
- **Validation**: `warning_triggered` = True AND `message` contains probability impact

## Research Objective

**Goal**: Design a comprehensive validation test suite that:
1. Covers all algorithm components (scoring, simulation, shadow pricing, etc.)
2. Uses realistic FM26 data
3. Provides clear pass/fail criteria
4. Enables iterative parameter tuning

## Validation Philosophy

### What Makes a Good Lineup?

We can't directly measure "wins" (FM's match engine is stochastic). Instead, we validate against proxy metrics:

1. **Utility Maximization**: Did we pick the highest-utility XI?
2. **Constraint Satisfaction**: Are all rules respected?
3. **Rotation Efficiency**: Did we manage fatigue appropriately?
4. **Key Player Availability**: Are stars fresh for big matches?
5. **Consistency**: Does the same input produce the same output?

### Test Categories

| Category | What We Test | How |
|----------|--------------|-----|
| Unit Tests | Individual functions | Expected output for known input |
| Scenario Tests | Full algorithm | Expected behavior in realistic situations |
| Regression Tests | Bug prevention | Historical cases that failed |
| Edge Case Tests | Boundary conditions | Extreme inputs that might break |

## Test Scenarios to Define

### Scenario 1: The Christmas Crunch
**Setup**: 5 matches in 13 days, all Medium importance
**Expected Behavior**:
- High rotation (Rotation Index > 0.7)
- No player starts > 3 consecutive matches
- Condition stays above 91% for all starters (per Step 2's "91% Floor" rule)
- No player exceeds 270 minutes in any 10-day window

**Validation Metrics**:
- `rotation_index = unique_starters / squad_size`
- `max_consecutive_starts` for any player
- `min_condition_at_kickoff` across all matches (threshold: 91%, not 80%)
- `max_10day_minutes` for any player (threshold: 270 minutes)

### Scenario 2: Cup Final Protection
**Setup**: Low, Low, Low, Low, High (Cup Final)
**Expected Behavior**:
- Top XI fully rested for Match 5 (Condition > 98%)
- Shadow pricing prevents star usage in Matches 3-4
- Best XI available and selected for Match 5

**Validation Metrics**:
- `key_player_condition_match_5` >= 98%
- `key_player_selected_match_5` = True for top 11
- `shadow_cost_effectiveness` (did it actually preserve them?)

### Scenario 3: Injury Crisis
**Setup**: All natural left-backs injured
**Expected Behavior**:
- System finds best "out of position" candidate
- Familiarity penalty is applied but selection proceeds
- No slot left empty, no crash

**Validation Metrics**:
- `position_filled` = True for LB
- `familiarity_of_selected` documented
- `no_runtime_errors` = True

### Scenario 4: Sharpness Building
**Setup**: Sharpness mode match, several low-sharpness key players
**Expected Behavior**:
- Low-sharpness players prioritized
- Already-sharp players deprioritized
- Post-match sharpness improves for selected players

**Validation Metrics**:
- `low_sharpness_player_selected_rate` > 60%
- `high_sharpness_player_rest_rate` > 50%
- `avg_sharpness_gain` for selected players

### Scenario 5: User Override Conflict
**Setup**: User locks injured player into lineup
**Expected Behavior**:
- System detects conflict
- Appropriate error message generated
- Suggestion to remove lock

**Validation Metrics**:
- `conflict_detected` = True
- `error_message_appropriate` = True
- `graceful_handling` (no crash)

### Scenario 6: Perfect Storm (All Constraints Active)
**Setup**: Multiple injuries, bans, locks, rejections, tight schedule, mixed importance
**Expected Behavior**:
- Valid lineup produced (or clear infeasibility message)
- All hard constraints satisfied
- Best available XI selected

**Validation Metrics**:
- `all_hard_constraints_satisfied` = True
- `infeasibility_correctly_detected` if applicable
- `utility_is_optimal` among feasible solutions

### Scenario 7: The Polyvalent Player
**Setup**: Player capable of 6+ positions, similar utility in each
**Expected Behavior**:
- Stability mechanism prevents excessive position swapping
- Player anchored to primary position after consistent use
- Shadow pricing doesn't over-penalize versatility

**Validation Metrics**:
- `position_consistency` across 5 matches
- `stability_bonus_applied` when appropriate
- `utility_loss_from_stability` < 5%

### Scenario 8: Season Simulation
**Setup**: 38 match league season with realistic fixture congestion
**Expected Behavior**:
- No player suffers extended jadedness
- Key players available for majority of high-importance matches
- Squad depth utilized appropriately

**Validation Metrics**:
- `jadedness_occurrences` = 0 (or minimal)
- `key_player_availability_rate` > 90% for high-importance
- `squad_utilization_spread` (Gini coefficient)

## Metrics Definitions

### 1. Aggregate Team Strength (ATS)
```python
ATS = sum(importance_weight[k] * sum(utility[p] for p in XI[k]) for k in matches)
```
**Goal**: Maximize (higher = better lineups in important matches)

### 2. Fatigue Violation Count (FVC)
```python
FVC = count(matches where any starter had condition < threshold)
```
**Goal**: Minimize to 0

### 3. Key Player Availability (KPA)
```python
KPA = count(high_imp_matches where key_players_available >= 3) / total_high_imp_matches
```
**Goal**: Maximize (target: > 95%)

### 4. Rotation Index (RI)
```python
RI = unique_starters_across_window / squad_size
```
**Goal**: Target range 0.5-0.8 (depends on fixture density)

### 5. Sharpness Efficiency (SE)
```python
SE = std_dev(sharpness_at_end) - std_dev(sharpness_at_start)
```
**Goal**: Negative (sharpness should equalize across squad)

### 6. Stability Score (SS)
```python
SS = count(same_slot_as_previous) / (11 * num_matches)
```
**Goal**: Target range 0.6-0.8 (some stability, some rotation)

### 7. Constraint Satisfaction Rate (CSR)
```python
CSR = count(constraints_satisfied) / count(total_constraints)
```
**Goal**: Must be 100% for hard constraints

## Test Data Requirements

### Squad Snapshot Format
```python
@dataclass
class TestSquadSnapshot:
    date: datetime
    players: List[PlayerState]  # All player stats
    fixtures: List[Fixture]      # Next N matches
    constraints: ConstraintSet   # Locks, rejections, injuries

@dataclass
class PlayerState:
    id: str
    name: str
    role_ratings: Dict[str, int]  # slot_name -> rating
    condition: float
    sharpness: float
    fatigue: float
    age: int
    natural_fitness: int
    stamina: int
    injury_proneness: int
    injured: bool
    banned: bool
```

### Expected Output Format
```python
@dataclass
class ValidationResult:
    passed: bool
    metrics: Dict[str, float]
    violations: List[str]
    lineups: List[List[Tuple[str, str]]]  # player_id, slot
    state_trajectory: Dict[str, List[PlayerState]]
```

## Test Implementation Structure

```python
class TestScenario:
    def __init__(self, name: str, description: str):
        self.name = name
        self.description = description

    def setup(self) -> TestSquadSnapshot:
        """Create test data"""
        raise NotImplementedError

    def run(self, optimizer) -> ValidationResult:
        """Execute optimization"""
        snapshot = self.setup()
        return optimizer.plan_horizon(snapshot.players, snapshot.fixtures)

    def validate(self, result: ValidationResult) -> List[str]:
        """Check expectations, return list of failures"""
        raise NotImplementedError


class ChristmasCrunchScenario(TestScenario):
    def setup(self):
        # Create 35-player squad
        # Create 5 matches in 13 days
        # All Medium importance
        ...

    def validate(self, result):
        failures = []
        if result.metrics['rotation_index'] < 0.7:
            failures.append(f"Rotation too low: {result.metrics['rotation_index']}")
        if result.metrics['max_consecutive'] > 3:
            failures.append(f"Player overused: {result.metrics['max_consecutive']} consecutive")
        ...
        return failures
```

## Calibration Harness

```python
class CalibrationHarness:
    def __init__(self, scenarios: List[TestScenario], param_grid: Dict):
        self.scenarios = scenarios
        self.param_grid = param_grid

    def run_calibration(self) -> CalibrationResult:
        results = []

        for params in self.param_grid:
            optimizer = Optimizer(**params)
            scenario_results = []

            for scenario in self.scenarios:
                result = scenario.run(optimizer)
                validation = scenario.validate(result)
                scenario_results.append({
                    'scenario': scenario.name,
                    'passed': len(validation) == 0,
                    'violations': validation,
                    'metrics': result.metrics
                })

            results.append({
                'params': params,
                'scenarios': scenario_results,
                'aggregate_score': self.compute_aggregate_score(scenario_results)
            })

        return CalibrationResult(
            best_params=max(results, key=lambda r: r['aggregate_score'])['params'],
            all_results=results,
            sensitivity=self.compute_sensitivity(results)
        )
```

## Expected Deliverables

### A. Complete Scenario Definitions

For each scenario:
- Setup data (JSON or Python)
- Expected behavior (qualitative)
- Pass criteria (quantitative thresholds)

### B. Metrics Library

```python
class ValidationMetrics:
    @staticmethod
    def aggregate_team_strength(lineups, importance_weights): ...

    @staticmethod
    def fatigue_violation_count(lineups, states, thresholds): ...

    @staticmethod
    def key_player_availability(lineups, key_players, high_imp_matches): ...

    # ... etc
```

### C. Test Data Generator

```python
def generate_test_squad(
    size: int = 35,
    avg_ability: int = 130,
    injury_rate: float = 0.1,
    fatigue_distribution: str = 'normal'
) -> TestSquadSnapshot:
    """Generate realistic test data"""
```

### D. Pass/Fail Thresholds

| Metric | Pass | Warn | Fail |
|--------|------|------|------|
| FVC | 0 | 1-2 | >2 |
| KPA | >0.95 | 0.85-0.95 | <0.85 |
| RI | 0.5-0.8 | 0.4-0.5 or 0.8-0.9 | <0.4 or >0.9 |
| CSR | 1.0 | N/A | <1.0 |

### E. Regression Test Catalog

| Test ID | Description | Issue It Catches |
|---------|-------------|------------------|
| REG001 | Empty squad handling | Crash on empty input |
| REG002 | All players injured | Infeasibility handling |
| REG003 | Conflicting locks | Constraint conflict detection |
| ... | ... | ... |

## Validation Criteria

The test suite is successful if:
- All defined scenarios have clear pass/fail criteria
- Metrics cover all important aspects of algorithm quality
- Test data is realistic and representative
- Running all tests takes < 60 seconds
- New bugs can be captured as regression tests

## Output Format

1. **Scenario Specifications**: Complete test case definitions
2. **Metrics Implementation**: Code for all metrics
3. **Data Generation**: Functions to create test data
4. **Threshold Tables**: Pass/warn/fail criteria
5. **Test Runner**: Script to execute all tests
6. **Report Format**: How results are displayed
