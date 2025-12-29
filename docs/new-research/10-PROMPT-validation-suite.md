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
