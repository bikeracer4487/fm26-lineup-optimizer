"""
Test Suite for Calibration Harness (Stage 11)
==============================================

Tests the parameter calibration infrastructure based on Step 11 research.

Test Coverage:
1. Parameter Range Definitions (23 parameters)
2. Sobol Sensitivity Analysis utilities
3. BOHB Optimization structure
4. Stress Test Scenarios
5. Calibration Objective Function
"""

import pytest
import numpy as np
import sys
import os

# Add test directory and project root to path
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from calibration_harness import (
    # Parameter definitions
    ParameterRange,
    BIOLOGICAL_PARAMETERS,
    TACTICAL_PARAMETERS,
    STRATEGIC_PARAMETERS,
    ALL_PARAMETERS,
    CRITICAL_PARAMETERS,
    get_parameter_by_symbol,
    get_default_parameter_vector,
    get_parameter_bounds,
    # Sobol
    SobolResults,
    generate_sobol_samples,
    screen_parameters,
    _compute_sobol_fallback,
    # BOHB
    BOHBConfig,
    EvaluationResult,
    BOHBOptimizer,
    # Stress tests
    StressTestResult,
    christmas_crunch_scenario,
    death_spiral_scenario,
    run_all_stress_tests,
    # Objective
    calculate_calibration_objective,
)


# =============================================================================
# PARAMETER RANGE TESTS
# =============================================================================

class TestParameterRanges:
    """Tests for parameter range definitions."""

    def test_all_parameters_have_valid_ranges(self):
        """All parameters must have min < max."""
        for p in ALL_PARAMETERS:
            assert p.min_value < p.max_value, f"{p.symbol}: min >= max"

    def test_all_defaults_within_bounds(self):
        """All default values must be within [min, max]."""
        for p in ALL_PARAMETERS:
            assert p.min_value <= p.default_value <= p.max_value, \
                f"{p.symbol}: default {p.default_value} not in [{p.min_value}, {p.max_value}]"

    def test_total_parameter_count(self):
        """Step 11 research specifies 23 parameters total."""
        assert len(ALL_PARAMETERS) == 23

    def test_biological_parameter_count(self):
        """Step 11 specifies 9 biological parameters."""
        assert len(BIOLOGICAL_PARAMETERS) == 9

    def test_tactical_parameter_count(self):
        """Step 11 specifies 7 tactical parameters."""
        assert len(TACTICAL_PARAMETERS) == 7

    def test_strategic_parameter_count(self):
        """Step 11 specifies 7 strategic parameters."""
        assert len(STRATEGIC_PARAMETERS) == 7

    def test_critical_parameters_identified(self):
        """Critical parameters (S_Ti > 0.01) should be identified."""
        critical_count = len(CRITICAL_PARAMETERS)
        # Step 11 research: ~16 critical parameters
        assert 10 <= critical_count <= 20

    def test_parameter_categories(self):
        """All parameters must have valid categories."""
        valid_categories = {'biological', 'tactical', 'strategic'}
        for p in ALL_PARAMETERS:
            assert p.category in valid_categories, \
                f"{p.symbol}: invalid category '{p.category}'"


class TestParameterValues:
    """Tests for specific parameter values from Step 11 research."""

    def test_condition_sigmoid_steepness_k25(self):
        """k_condition default should be 25 (Step 11 research)."""
        p = get_parameter_by_symbol('k_condition')
        assert p is not None
        assert p.default_value == 25.0
        assert p.min_value == 15.0
        assert p.max_value == 35.0

    def test_gamma_shadow_discount_0_85(self):
        """gamma default should be 0.85 (Step 11 research)."""
        p = get_parameter_by_symbol('gamma')
        assert p is not None
        assert p.default_value == 0.85

    def test_r_pos_fb_1_65(self):
        """R_pos_FB default should be 1.65 (Step 3/11 research)."""
        p = get_parameter_by_symbol('R_pos_FB')
        assert p is not None
        assert p.default_value == 1.65

    def test_270_minute_window_14_days(self):
        """270-min window default should be 14 days (Step 11 research)."""
        p = get_parameter_by_symbol('mins_window')
        assert p is not None
        assert p.default_value == 14

    def test_congestion_multiplier_2_5(self):
        """Congestion multiplier default should be 2.5 (Step 11 research)."""
        p = get_parameter_by_symbol('congestion_mult')
        assert p is not None
        assert p.default_value == 2.5

    def test_jadedness_thresholds(self):
        """Jadedness thresholds should be 200/400/700 (Step 6/11 research)."""
        fresh = get_parameter_by_symbol('J_fresh')
        fit = get_parameter_by_symbol('J_fit')
        tired = get_parameter_by_symbol('J_tired')

        assert fresh.default_value == 200
        assert fit.default_value == 400
        assert tired.default_value == 700


class TestParameterLookup:
    """Tests for parameter lookup utilities."""

    def test_get_parameter_by_symbol_found(self):
        """Should return parameter when found."""
        p = get_parameter_by_symbol('k_condition')
        assert p is not None
        assert p.symbol == 'k_condition'
        assert p.name == 'Condition Sigmoid Steepness'

    def test_get_parameter_by_symbol_not_found(self):
        """Should return None for unknown symbol."""
        p = get_parameter_by_symbol('unknown_param')
        assert p is None

    def test_get_default_parameter_vector(self):
        """Should return dict with all parameter defaults."""
        defaults = get_default_parameter_vector()
        assert len(defaults) == len(ALL_PARAMETERS)
        assert 'k_condition' in defaults
        assert defaults['k_condition'] == 25.0
        assert defaults['gamma'] == 0.85

    def test_get_parameter_bounds(self):
        """Should return dict with (min, max) tuples."""
        bounds = get_parameter_bounds()
        assert len(bounds) == len(ALL_PARAMETERS)
        assert bounds['k_condition'] == (15.0, 35.0)
        assert bounds['gamma'] == (0.80, 0.95)


# =============================================================================
# SOBOL SENSITIVITY ANALYSIS TESTS
# =============================================================================

class TestSobolSampling:
    """Tests for Sobol sampling functionality."""

    def test_generate_sobol_samples_shape(self):
        """Samples should have correct shape for Saltelli method."""
        n_samples = 100
        params = CRITICAL_PARAMETERS[:5]
        samples = generate_sobol_samples(n_samples, params)

        # Shape should be (n_samples * (k + 2), k)
        k = len(params)
        expected_rows = n_samples * (k + 2)
        assert samples.shape == (expected_rows, k)

    def test_generate_sobol_samples_bounds(self):
        """All samples should be within parameter bounds."""
        samples = generate_sobol_samples(100, CRITICAL_PARAMETERS[:3])
        params = CRITICAL_PARAMETERS[:3]

        for i, p in enumerate(params):
            col = samples[:, i]
            assert np.all(col >= p.min_value), f"{p.symbol} has values below min"
            assert np.all(col <= p.max_value), f"{p.symbol} has values above max"

    def test_sobol_fallback_computes_indices(self):
        """Fallback Sobol approximation should compute indices."""
        n_samples = 100
        params = CRITICAL_PARAMETERS[:3]
        samples = np.random.rand(n_samples, 3)

        # Scale samples
        for i, p in enumerate(params):
            samples[:, i] = p.min_value + samples[:, i] * (p.max_value - p.min_value)

        # Create synthetic outputs correlated with first parameter
        outputs = samples[:, 0] * 2 + np.random.randn(n_samples) * 0.1

        results = _compute_sobol_fallback(samples, outputs, params)

        assert len(results) == 3
        # First parameter should have highest sensitivity
        assert results[0].S_i > results[1].S_i
        assert results[0].S_i > results[2].S_i


class TestSobolScreening:
    """Tests for Sobol-based parameter screening."""

    def test_screen_parameters_separates_critical(self):
        """Should separate critical and non-critical parameters."""
        results = [
            SobolResults('p1', 0.3, 0.35, 0.05, True),   # Critical (S_Ti > 0.01)
            SobolResults('p2', 0.005, 0.008, 0.003, False),  # Non-critical
            SobolResults('p3', 0.1, 0.15, 0.05, True),   # Critical
        ]

        critical, non_critical = screen_parameters(results, threshold=0.01)

        assert 'p1' in critical
        assert 'p3' in critical
        assert 'p2' in non_critical

    def test_screen_parameters_custom_threshold(self):
        """Should respect custom threshold."""
        results = [
            SobolResults('p1', 0.3, 0.35, 0.05, True),
            SobolResults('p2', 0.05, 0.08, 0.03, True),
        ]

        critical, non_critical = screen_parameters(results, threshold=0.1)

        assert 'p1' in critical
        assert 'p2' in non_critical


# =============================================================================
# BOHB OPTIMIZER TESTS
# =============================================================================

class TestBOHBConfig:
    """Tests for BOHB configuration."""

    def test_default_config(self):
        """Default config should have sensible values."""
        config = BOHBConfig()
        assert config.max_epochs == 100
        assert config.min_budget == 5
        assert config.max_budget == 38  # Full season
        assert config.eta == 3  # Standard successive halving factor
        assert config.n_initial == 20
        assert config.n_iterations == 50


class TestBOHBOptimizer:
    """Tests for BOHB optimizer functionality."""

    @pytest.fixture
    def simple_optimizer(self):
        """Create optimizer with simple objective function."""
        def objective_fn(config, budget):
            # Simple quadratic loss centered at default values
            loss = 0
            for p in CRITICAL_PARAMETERS[:3]:
                diff = config.get(p.symbol, p.default_value) - p.default_value
                loss += diff ** 2
            return EvaluationResult(
                config=config,
                budget=budget,
                objective=loss,
                metrics={'loss': loss}
            )

        return BOHBOptimizer(
            parameters=CRITICAL_PARAMETERS[:3],
            objective_fn=objective_fn,
            config=BOHBConfig(n_iterations=2, n_initial=5)
        )

    def test_sample_random_config(self, simple_optimizer):
        """Random config should be within bounds."""
        config = simple_optimizer.sample_random_config()

        for p in CRITICAL_PARAMETERS[:3]:
            assert p.min_value <= config[p.symbol] <= p.max_value

    def test_sample_random_config_variability(self, simple_optimizer):
        """Multiple random samples should vary."""
        configs = [simple_optimizer.sample_random_config() for _ in range(10)]

        first_param = CRITICAL_PARAMETERS[0].symbol
        values = [c[first_param] for c in configs]

        # Check variance exists
        assert np.std(values) > 0

    def test_sample_tpe_initial_is_random(self, simple_optimizer):
        """TPE should use random sampling during warmup."""
        # History is empty, should use random
        config1 = simple_optimizer.sample_tpe_config()
        config2 = simple_optimizer.sample_tpe_config()

        # Both should be within bounds
        for p in CRITICAL_PARAMETERS[:3]:
            assert p.min_value <= config1[p.symbol] <= p.max_value
            assert p.min_value <= config2[p.symbol] <= p.max_value

    def test_successive_halving_reduces_candidates(self, simple_optimizer):
        """Successive halving should reduce candidates by factor eta."""
        configs = [simple_optimizer.sample_random_config() for _ in range(9)]
        budgets = [5, 15]

        results = simple_optimizer.run_successive_halving(configs, budgets)

        # Should have 9 / 3 = 3 survivors after first round
        # Then 3 / 3 = 1 survivor after second round
        assert len(results) == 1

    def test_optimizer_tracks_best(self, simple_optimizer):
        """Optimizer should track best config found."""
        config = simple_optimizer.sample_random_config()
        budgets = [5]

        simple_optimizer.run_successive_halving([config], budgets)

        assert simple_optimizer.best_config is not None
        assert simple_optimizer.best_objective < float('inf')


# =============================================================================
# STRESS TEST SCENARIO TESTS
# =============================================================================

class TestStressTestResult:
    """Tests for stress test result structure."""

    def test_stress_test_result_structure(self):
        """StressTestResult should have required fields."""
        result = StressTestResult(
            scenario_name='Test',
            passed=True,
            metrics={'key': 1.0},
            violations=[],
            config_used={'param': 1.0}
        )

        assert result.scenario_name == 'Test'
        assert result.passed is True
        assert 'key' in result.metrics
        assert len(result.violations) == 0


class TestChristmasCrunch:
    """Tests for Christmas Crunch stress test scenario."""

    def test_christmas_crunch_runs(self):
        """Christmas Crunch should run without error."""
        defaults = get_default_parameter_vector()
        result = christmas_crunch_scenario(defaults, None)

        assert result.scenario_name == 'Christmas Crunch'
        assert 'rotation_index' in result.metrics
        assert 'max_jadedness' in result.metrics
        assert 'condition_violations' in result.metrics

    def test_christmas_crunch_config_passed_through(self):
        """Config should be stored in result."""
        config = {'k_condition': 25.0, 'gamma': 0.85}
        result = christmas_crunch_scenario(config, None)

        assert result.config_used == config


class TestDeathSpiral:
    """Tests for Death Spiral stress test scenario."""

    def test_death_spiral_runs(self):
        """Death Spiral should run without error."""
        defaults = get_default_parameter_vector()
        result = death_spiral_scenario(defaults, None)

        assert result.scenario_name == 'Death Spiral'
        assert 'youth_call_ups' in result.metrics
        assert 'cascading_injuries' in result.metrics
        assert 'oop_minutes' in result.metrics

    def test_death_spiral_config_passed_through(self):
        """Config should be stored in result."""
        config = {'k_condition': 25.0, 'gamma': 0.85}
        result = death_spiral_scenario(config, None)

        assert result.config_used == config


class TestRunAllStressTests:
    """Tests for combined stress test runner."""

    def test_run_all_stress_tests_returns_all(self):
        """Should run all defined stress tests."""
        defaults = get_default_parameter_vector()
        results = run_all_stress_tests(defaults)

        assert len(results) == 2
        scenario_names = {r.scenario_name for r in results}
        assert 'Christmas Crunch' in scenario_names
        assert 'Death Spiral' in scenario_names


# =============================================================================
# CALIBRATION OBJECTIVE TESTS
# =============================================================================

class TestCalibrationObjective:
    """Tests for calibration objective function."""

    def test_objective_perfect_season(self):
        """Perfect season should have very negative (good) objective."""
        loss = calculate_calibration_objective(
            season_points=114,  # Maximum
            cup_rounds=7,       # Both finals
            injury_days=0,      # No injuries
            squad_stability=1.0  # Perfect stability
        )

        # Should be negative (we're maximizing performance)
        assert loss < 0

    def test_objective_disastrous_season(self):
        """Disastrous season should have positive (bad) objective."""
        loss = calculate_calibration_objective(
            season_points=0,     # Relegated
            cup_rounds=0,        # First round exits
            injury_days=500,     # Many injuries
            squad_stability=0.0  # Complete instability
        )

        # Should be positive (we penalize bad performance)
        assert loss > 0

    def test_objective_prefers_more_points(self):
        """More points should result in lower (better) objective."""
        loss_high = calculate_calibration_objective(
            season_points=90, cup_rounds=3, injury_days=50, squad_stability=0.7
        )
        loss_low = calculate_calibration_objective(
            season_points=60, cup_rounds=3, injury_days=50, squad_stability=0.7
        )

        assert loss_high < loss_low

    def test_objective_penalizes_injuries(self):
        """More injuries should result in higher (worse) objective."""
        loss_few = calculate_calibration_objective(
            season_points=80, cup_rounds=3, injury_days=20, squad_stability=0.7
        )
        loss_many = calculate_calibration_objective(
            season_points=80, cup_rounds=3, injury_days=200, squad_stability=0.7
        )

        assert loss_few < loss_many

    def test_objective_custom_weights(self):
        """Custom weights should affect objective."""
        base = calculate_calibration_objective(
            season_points=80, cup_rounds=3, injury_days=50, squad_stability=0.7
        )
        cups_heavy = calculate_calibration_objective(
            season_points=80, cup_rounds=3, injury_days=50, squad_stability=0.7,
            weights={'points': 1.0, 'cups': 5.0, 'injury': 0.3, 'stability': 0.2}
        )

        # Different weights should give different results
        assert base != cups_heavy


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

class TestCalibrationIntegration:
    """Integration tests for calibration workflow."""

    def test_full_parameter_workflow(self):
        """Test complete parameter lookup → bounds → default → validate flow."""
        # 1. Get all parameters
        params = ALL_PARAMETERS
        assert len(params) == 23

        # 2. Get bounds for all
        bounds = get_parameter_bounds()
        assert len(bounds) == 23

        # 3. Get defaults
        defaults = get_default_parameter_vector()
        assert len(defaults) == 23

        # 4. Validate all defaults within bounds
        for symbol, (min_val, max_val) in bounds.items():
            default = defaults[symbol]
            assert min_val <= default <= max_val, f"{symbol} default out of bounds"

    def test_sobol_to_screening_workflow(self):
        """Test Sobol sampling → screening workflow."""
        # 1. Generate samples
        params = CRITICAL_PARAMETERS[:5]
        samples = generate_sobol_samples(50, params)
        assert samples.shape[1] == 5

        # 2. Create mock outputs
        outputs = np.random.randn(samples.shape[0])

        # 3. Compute indices (fallback)
        results = _compute_sobol_fallback(samples, outputs, params)
        assert len(results) == 5

        # 4. Screen parameters
        critical, non_critical = screen_parameters(results)
        assert len(critical) + len(non_critical) == 5

    def test_stress_test_with_default_config(self):
        """Test stress tests with default parameter configuration."""
        defaults = get_default_parameter_vector()

        # Run all stress tests
        results = run_all_stress_tests(defaults)

        # All should run without exception
        assert len(results) == 2

        # Check structure
        for result in results:
            assert isinstance(result.scenario_name, str)
            assert isinstance(result.passed, bool)
            assert isinstance(result.metrics, dict)
            assert isinstance(result.violations, list)
            assert isinstance(result.config_used, dict)
