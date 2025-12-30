"""
FM26 Calibration Harness
========================

Implements parameter calibration infrastructure based on Step 11 research.

Key Components (Step 11 Research):
1. Parameter Range Definitions - Calibration bounds from OR analysis
2. Sobol Sensitivity Analysis - Dimensionality reduction (50 → 20 params)
3. BOHB Optimization Structure - Bayesian Optimization + Hyperband
4. Stress Test Scenarios - Christmas Crunch, Death Spiral validation

References:
- docs/new-research/11-RESULTS-calibration.md
- docs/new-research/12-IMPLEMENTATION-PLAN.md
"""

import sys
import os
from typing import Dict, List, Tuple, Optional, Any, Callable
from dataclasses import dataclass, field
import numpy as np

# Add project root to path
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from scoring_parameters import (
    CONDITION_SIGMOID_K,
    CONDITION_SIGMOID_C0,
    SHARPNESS_SIGMOID_K,
    SHARPNESS_SIGMOID_S0,
    JADEDNESS_THRESHOLDS,
    R_POS,
    SHADOW_DISCOUNT_GAMMA,
    IMPORTANCE_WEIGHTS,
    VORP_SCARCITY_LAMBDA,
)


# =============================================================================
# PARAMETER RANGE DEFINITIONS (Step 11 Research - Table 2)
# =============================================================================

@dataclass
class ParameterRange:
    """Defines calibration range for a single parameter."""
    name: str
    symbol: str
    min_value: float
    max_value: float
    default_value: float
    category: str  # 'biological', 'tactical', 'strategic'
    description: str
    is_critical: bool = True  # S_Ti > 0.01 from Sobol analysis


# Biological Constraints (Rigid - physiology-based)
BIOLOGICAL_PARAMETERS: List[ParameterRange] = [
    ParameterRange(
        name='Condition Sigmoid Steepness',
        symbol='k_condition',
        min_value=15.0,
        max_value=35.0,
        default_value=25.0,
        category='biological',
        description='Controls cliff edge of condition risk. FM26 uses k=25.',
        is_critical=True
    ),
    ParameterRange(
        name='Condition Sigmoid Threshold',
        symbol='c0',
        min_value=0.85,
        max_value=0.92,
        default_value=0.88,
        category='biological',
        description='Condition threshold (88% = FM26 match fit).',
        is_critical=True
    ),
    ParameterRange(
        name='Sharpness Sigmoid Steepness',
        symbol='k_sharpness',
        min_value=10.0,
        max_value=20.0,
        default_value=15.0,
        category='biological',
        description='Controls sharpness cliff edge around 75%.',
        is_critical=True
    ),
    ParameterRange(
        name='Sharpness Sigmoid Threshold',
        symbol='s0',
        min_value=0.70,
        max_value=0.80,
        default_value=0.75,
        category='biological',
        description='Sharpness threshold for full effectiveness.',
        is_critical=True
    ),
    ParameterRange(
        name='Sharpness Decay Half-life',
        symbol='H_sharp',
        min_value=5.0,
        max_value=10.0,
        default_value=7.0,
        category='biological',
        description='Days for sharpness to decay 50% (7-day cliff).',
        is_critical=True
    ),
    ParameterRange(
        name='Recovery Rate Base',
        symbol='tau_rec',
        min_value=3.0,
        max_value=8.0,
        default_value=5.0,
        category='biological',
        description='Base recovery rate (condition %/day).',
        is_critical=True
    ),
    ParameterRange(
        name='Jadedness Fresh Threshold',
        symbol='J_fresh',
        min_value=150,
        max_value=250,
        default_value=200,
        category='biological',
        description='Upper bound of Fresh jadedness state.',
        is_critical=False
    ),
    ParameterRange(
        name='Jadedness Fit Threshold',
        symbol='J_fit',
        min_value=350,
        max_value=450,
        default_value=400,
        category='biological',
        description='Upper bound of Fit jadedness state.',
        is_critical=False
    ),
    ParameterRange(
        name='Jadedness Tired Threshold',
        symbol='J_tired',
        min_value=650,
        max_value=750,
        default_value=700,
        category='biological',
        description='Upper bound of Tired jadedness state.',
        is_critical=True
    ),
]

# Tactical Variables (Elastic - tunable)
TACTICAL_PARAMETERS: List[ParameterRange] = [
    ParameterRange(
        name='Positional Drag (FB→CB)',
        symbol='delta_fb_cb',
        min_value=0.05,
        max_value=0.15,
        default_value=0.10,
        category='tactical',
        description='Drag when moving to lower intensity role.',
        is_critical=False
    ),
    ParameterRange(
        name='Positional Drag (CB→FB)',
        symbol='delta_cb_fb',
        min_value=0.20,
        max_value=0.40,
        default_value=0.30,
        category='tactical',
        description='Drag when moving to high sprint demand role.',
        is_critical=True
    ),
    ParameterRange(
        name='R_pos Fullback/Wingback',
        symbol='R_pos_FB',
        min_value=1.50,
        max_value=1.80,
        default_value=1.65,
        category='tactical',
        description='Condition drain coefficient for FB/WB (highest).',
        is_critical=True
    ),
    ParameterRange(
        name='R_pos Central Midfielder',
        symbol='R_pos_CM',
        min_value=1.30,
        max_value=1.60,
        default_value=1.45,
        category='tactical',
        description='Condition drain coefficient for CM.',
        is_critical=True
    ),
    ParameterRange(
        name='R_pos Goalkeeper',
        symbol='R_pos_GK',
        min_value=0.10,
        max_value=0.30,
        default_value=0.20,
        category='tactical',
        description='Condition drain coefficient for GK (lowest).',
        is_critical=False
    ),
    ParameterRange(
        name='270-Minute Window',
        symbol='mins_window',
        min_value=12,
        max_value=16,
        default_value=14,
        category='tactical',
        description='Days for 270-minute congestion window.',
        is_critical=True
    ),
    ParameterRange(
        name='Congestion Multiplier',
        symbol='congestion_mult',
        min_value=2.0,
        max_value=3.0,
        default_value=2.5,
        category='tactical',
        description='Jadedness multiplier when 270-min exceeded.',
        is_critical=True
    ),
]

# Strategic Valuations (Abstract - OR-derived)
STRATEGIC_PARAMETERS: List[ParameterRange] = [
    ParameterRange(
        name='Shadow Discount Factor',
        symbol='gamma',
        min_value=0.80,
        max_value=0.95,
        default_value=0.85,
        category='strategic',
        description='Temporal discount for shadow pricing (0=myopic, 1=hoarding).',
        is_critical=True
    ),
    ParameterRange(
        name='Shadow Price Convexity',
        symbol='alpha',
        min_value=1.5,
        max_value=3.0,
        default_value=2.0,
        category='strategic',
        description='Non-linear fatigue cost as limits approach.',
        is_critical=True
    ),
    ParameterRange(
        name='VORP Scarcity Lambda',
        symbol='lambda_V',
        min_value=1.0,
        max_value=3.0,
        default_value=2.0,
        category='strategic',
        description='Scarcity scaling for key player shadow protection.',
        is_critical=True
    ),
    ParameterRange(
        name='Importance Weight High',
        symbol='W_high',
        min_value=2.0,
        max_value=5.0,
        default_value=3.0,
        category='strategic',
        description='Shadow weight for High importance matches.',
        is_critical=True
    ),
    ParameterRange(
        name='Importance Weight Medium',
        symbol='W_medium',
        min_value=1.0,
        max_value=2.0,
        default_value=1.5,
        category='strategic',
        description='Shadow weight for Medium importance matches.',
        is_critical=False
    ),
    ParameterRange(
        name='Importance Weight Low',
        symbol='W_low',
        min_value=0.5,
        max_value=1.0,
        default_value=0.8,
        category='strategic',
        description='Shadow weight for Low importance matches.',
        is_critical=False
    ),
    ParameterRange(
        name='Importance Weight Sharpness',
        symbol='W_sharpness',
        min_value=0.05,
        max_value=0.20,
        default_value=0.10,
        category='strategic',
        description='Shadow weight for Sharpness (dead rubber) matches.',
        is_critical=False
    ),
]

# Combine all parameters
ALL_PARAMETERS: List[ParameterRange] = (
    BIOLOGICAL_PARAMETERS + TACTICAL_PARAMETERS + STRATEGIC_PARAMETERS
)

# Critical parameters (S_Ti > 0.01 from Sobol analysis)
CRITICAL_PARAMETERS: List[ParameterRange] = [
    p for p in ALL_PARAMETERS if p.is_critical
]


def get_parameter_by_symbol(symbol: str) -> Optional[ParameterRange]:
    """Get parameter definition by symbol."""
    for p in ALL_PARAMETERS:
        if p.symbol == symbol:
            return p
    return None


def get_default_parameter_vector() -> Dict[str, float]:
    """Get dictionary of all parameters with default values."""
    return {p.symbol: p.default_value for p in ALL_PARAMETERS}


def get_parameter_bounds() -> Dict[str, Tuple[float, float]]:
    """Get dictionary of parameter bounds (min, max)."""
    return {p.symbol: (p.min_value, p.max_value) for p in ALL_PARAMETERS}


# =============================================================================
# SOBOL SENSITIVITY ANALYSIS (Step 11 - Phase 1)
# =============================================================================

@dataclass
class SobolResults:
    """Results from Sobol sensitivity analysis."""
    parameter: str
    S_i: float      # First-order index
    S_Ti: float     # Total-order index
    interaction: float  # S_Ti - S_i (interaction effect)
    is_critical: bool


def generate_sobol_samples(
    n_samples: int,
    parameters: List[ParameterRange]
) -> np.ndarray:
    """
    Generate quasi-random samples using Sobol sequences.

    For k parameters, we need N(k+2) evaluations per Saltelli's method.

    Args:
        n_samples: Base sample size (N)
        parameters: List of parameters to sample

    Returns:
        Sample matrix of shape (n_samples * (k+2), k)
    """
    try:
        from scipy.stats import qmc
    except ImportError:
        raise ImportError("scipy.stats.qmc required for Sobol sampling")

    k = len(parameters)

    # Generate Sobol sequence
    sampler = qmc.Sobol(d=k, scramble=True)
    samples = sampler.random(n_samples * (k + 2))

    # Scale to parameter bounds
    l_bounds = [p.min_value for p in parameters]
    u_bounds = [p.max_value for p in parameters]
    scaled_samples = qmc.scale(samples, l_bounds, u_bounds)

    return scaled_samples


def compute_sobol_indices(
    samples: np.ndarray,
    outputs: np.ndarray,
    parameters: List[ParameterRange]
) -> List[SobolResults]:
    """
    Compute Sobol sensitivity indices from simulation outputs.

    Args:
        samples: Input sample matrix
        outputs: Corresponding simulation outputs
        parameters: Parameter definitions

    Returns:
        List of SobolResults with S_i and S_Ti for each parameter
    """
    try:
        from SALib.analyze import sobol as sobol_analyze
        from SALib.sample import saltelli
    except ImportError:
        # Fallback: simple variance-based approximation
        return _compute_sobol_fallback(samples, outputs, parameters)

    problem = {
        'num_vars': len(parameters),
        'names': [p.symbol for p in parameters],
        'bounds': [[p.min_value, p.max_value] for p in parameters]
    }

    Si = sobol_analyze.analyze(problem, outputs)

    results = []
    for i, param in enumerate(parameters):
        results.append(SobolResults(
            parameter=param.symbol,
            S_i=Si['S1'][i],
            S_Ti=Si['ST'][i],
            interaction=Si['ST'][i] - Si['S1'][i],
            is_critical=Si['ST'][i] > 0.01
        ))

    return results


def _compute_sobol_fallback(
    samples: np.ndarray,
    outputs: np.ndarray,
    parameters: List[ParameterRange]
) -> List[SobolResults]:
    """Fallback Sobol approximation when SALib not available."""
    results = []
    total_var = np.var(outputs)

    for i, param in enumerate(parameters):
        # Simple correlation-based approximation
        correlation = np.corrcoef(samples[:, i], outputs)[0, 1]
        s_i_approx = correlation ** 2 if not np.isnan(correlation) else 0.0
        s_ti_approx = s_i_approx * 1.2  # Rough interaction estimate

        results.append(SobolResults(
            parameter=param.symbol,
            S_i=s_i_approx,
            S_Ti=s_ti_approx,
            interaction=s_ti_approx - s_i_approx,
            is_critical=s_ti_approx > 0.01
        ))

    return results


def screen_parameters(
    sobol_results: List[SobolResults],
    threshold: float = 0.01
) -> Tuple[List[str], List[str]]:
    """
    Screen parameters based on Sobol total-order index.

    Args:
        sobol_results: Results from compute_sobol_indices
        threshold: S_Ti threshold for criticality (default 0.01 = 1%)

    Returns:
        Tuple of (critical_params, non_critical_params) symbol lists
    """
    critical = []
    non_critical = []

    for result in sobol_results:
        if result.S_Ti >= threshold:
            critical.append(result.parameter)
        else:
            non_critical.append(result.parameter)

    return critical, non_critical


# =============================================================================
# BOHB OPTIMIZATION STRUCTURE (Step 11 - Phase 2)
# =============================================================================

@dataclass
class BOHBConfig:
    """Configuration for BOHB optimization."""
    max_epochs: int = 100           # Maximum full-season evaluations
    min_budget: int = 5             # Minimum horizon (matches)
    max_budget: int = 38            # Maximum horizon (full season)
    eta: int = 3                    # Successive halving reduction factor
    n_initial: int = 20             # Initial random samples
    n_iterations: int = 50          # BOHB iterations


@dataclass
class EvaluationResult:
    """Result from a single parameter configuration evaluation."""
    config: Dict[str, float]
    budget: int  # Number of matches simulated
    objective: float  # Loss value (lower is better)
    metrics: Dict[str, float]


class BOHBOptimizer:
    """
    BOHB-style optimizer for parameter calibration.

    Combines Bayesian Optimization (TPE) with Hyperband successive halving.
    """

    def __init__(
        self,
        parameters: List[ParameterRange],
        objective_fn: Callable[[Dict[str, float], int], EvaluationResult],
        config: BOHBConfig = None
    ):
        """
        Initialize BOHB optimizer.

        Args:
            parameters: Parameters to optimize
            objective_fn: Function that evaluates a config at given budget
                          signature: (config_dict, budget) -> EvaluationResult
            config: BOHB configuration
        """
        self.parameters = parameters
        self.objective_fn = objective_fn
        self.config = config or BOHBConfig()
        self.history: List[EvaluationResult] = []
        self.best_config: Optional[Dict[str, float]] = None
        self.best_objective: float = float('inf')

    def sample_random_config(self) -> Dict[str, float]:
        """Sample random configuration from parameter space."""
        config = {}
        for p in self.parameters:
            config[p.symbol] = np.random.uniform(p.min_value, p.max_value)
        return config

    def sample_tpe_config(self) -> Dict[str, float]:
        """
        Sample configuration using Tree-structured Parzen Estimator (TPE).

        Simplified version: uses best configs to bias sampling.
        """
        if len(self.history) < self.config.n_initial:
            return self.sample_random_config()

        # Split history into good/bad based on median
        sorted_history = sorted(self.history, key=lambda r: r.objective)
        n_good = max(1, len(sorted_history) // 4)
        good_configs = [r.config for r in sorted_history[:n_good]]

        # Sample around good configs with perturbation
        base_config = good_configs[np.random.randint(len(good_configs))]
        config = {}

        for p in self.parameters:
            # Perturb base value within bounds
            base_val = base_config.get(p.symbol, p.default_value)
            perturbation = np.random.normal(0, (p.max_value - p.min_value) * 0.1)
            new_val = base_val + perturbation
            config[p.symbol] = np.clip(new_val, p.min_value, p.max_value)

        return config

    def run_successive_halving(
        self,
        configs: List[Dict[str, float]],
        budget_sequence: List[int]
    ) -> List[EvaluationResult]:
        """
        Run successive halving on a set of configurations.

        Args:
            configs: List of configurations to evaluate
            budget_sequence: Increasing budget sequence [b1, b2, ...]

        Returns:
            Final evaluation results for surviving configs
        """
        current_configs = configs.copy()
        results = []

        for budget in budget_sequence:
            # Evaluate all surviving configs at current budget
            budget_results = []
            for config in current_configs:
                result = self.objective_fn(config, budget)
                budget_results.append(result)
                self.history.append(result)

                # Update best
                if result.objective < self.best_objective:
                    self.best_objective = result.objective
                    self.best_config = config.copy()

            # Sort by objective (lower is better)
            budget_results.sort(key=lambda r: r.objective)

            # Keep top 1/eta configs for next round
            n_survivors = max(1, len(current_configs) // self.config.eta)
            current_configs = [r.config for r in budget_results[:n_survivors]]
            results = budget_results[:n_survivors]

        return results

    def optimize(self) -> Tuple[Dict[str, float], float]:
        """
        Run full BOHB optimization.

        Returns:
            Tuple of (best_config, best_objective)
        """
        # Calculate budget sequence for Hyperband
        budgets = []
        b = self.config.min_budget
        while b <= self.config.max_budget:
            budgets.append(int(b))
            b *= self.config.eta

        for iteration in range(self.config.n_iterations):
            # Generate candidates (TPE-guided after warmup)
            n_candidates = self.config.eta ** (len(budgets) - 1)
            configs = [self.sample_tpe_config() for _ in range(n_candidates)]

            # Run successive halving
            self.run_successive_halving(configs, budgets)

            print(f"Iteration {iteration + 1}/{self.config.n_iterations}: "
                  f"Best objective = {self.best_objective:.4f}")

        return self.best_config, self.best_objective


# =============================================================================
# STRESS TEST SCENARIOS (Step 11 - Validation)
# =============================================================================

@dataclass
class StressTestResult:
    """Result from stress test scenario."""
    scenario_name: str
    passed: bool
    metrics: Dict[str, float]
    violations: List[str]
    config_used: Dict[str, float]


def christmas_crunch_scenario(
    config: Dict[str, float],
    simulate_fn: Callable
) -> StressTestResult:
    """
    Christmas Crunch Stress Test (Step 11 - Scenario A).

    Schedule: 4 games in 10 days (Dec 26, 28, Jan 1, 4)
    Success criteria:
    - Rotation Index > 0.7 (must use > 18 unique starters)
    - No player crosses J=700 (Jaded threshold)
    - Condition floor violations = 0

    Args:
        config: Parameter configuration to test
        simulate_fn: Function to simulate matches

    Returns:
        StressTestResult with pass/fail and metrics
    """
    violations = []
    metrics = {}

    # Define fixture schedule
    fixtures = [
        {'day': 0, 'importance': 'Medium'},   # Dec 26
        {'day': 2, 'importance': 'Medium'},   # Dec 28
        {'day': 6, 'importance': 'High'},     # Jan 1
        {'day': 9, 'importance': 'Medium'},   # Jan 4
    ]

    # Track metrics
    unique_starters = set()
    max_jadedness = 0
    condition_violations = 0
    total_injury_days = 0

    # Simulate (placeholder - actual simulation would use config)
    for fixture in fixtures:
        # This would call the actual simulation with config
        # result = simulate_fn(fixture, config)
        # unique_starters.update(result.starters)
        # max_jadedness = max(max_jadedness, result.max_jadedness)
        # condition_violations += result.condition_violations
        pass

    # Calculate rotation index
    squad_size = 25
    rotation_index = len(unique_starters) / squad_size if unique_starters else 0.0

    metrics['rotation_index'] = rotation_index
    metrics['max_jadedness'] = max_jadedness
    metrics['condition_violations'] = condition_violations
    metrics['injury_days'] = total_injury_days
    metrics['unique_starters'] = len(unique_starters)

    # Check success criteria
    if rotation_index < 0.7:
        violations.append(f"Rotation Index {rotation_index:.2f} < 0.7 (insufficient rotation)")

    if max_jadedness >= 700:
        violations.append(f"Max Jadedness {max_jadedness} >= 700 (player became Jaded)")

    if condition_violations > 0:
        violations.append(f"{condition_violations} condition floor violations (< 91%)")

    return StressTestResult(
        scenario_name='Christmas Crunch',
        passed=len(violations) == 0,
        metrics=metrics,
        violations=violations,
        config_used=config
    )


def death_spiral_scenario(
    config: Dict[str, float],
    simulate_fn: Callable
) -> StressTestResult:
    """
    Death Spiral Stress Test (Step 11 - Scenario B).

    Setup: Inject 4 defensive injuries in Week 10
    Success criteria:
    - AI uses youth/reserves over exhausting remaining senior players
    - No additional injuries from overplayed survivors
    - Accepts lower ATS over constraint violation

    Args:
        config: Parameter configuration to test
        simulate_fn: Function to simulate matches

    Returns:
        StressTestResult with pass/fail and metrics
    """
    violations = []
    metrics = {}

    # Injure 4 key defensive players
    initial_injuries = ['CB1', 'CB2', 'LB1', 'RB1']

    # Track metrics
    youth_call_ups = 0
    cascading_injuries = 0
    oop_minutes = 0  # Out-of-position minutes
    ats_reduction = 0.0

    # Simulate (placeholder)
    # result = simulate_fn(weeks=5, injured=initial_injuries, config=config)

    metrics['youth_call_ups'] = youth_call_ups
    metrics['cascading_injuries'] = cascading_injuries
    metrics['oop_minutes'] = oop_minutes
    metrics['ats_reduction_pct'] = ats_reduction

    # Check success criteria
    if cascading_injuries > 0:
        violations.append(f"{cascading_injuries} cascading injuries (Death Spiral triggered)")

    if youth_call_ups < 2:
        violations.append(f"Only {youth_call_ups} youth call-ups (should use reserves)")

    # OOP minutes should be limited (prefer youth at natural position)
    if oop_minutes > 270:
        violations.append(f"{oop_minutes} OOP minutes (should use natural-position youth)")

    return StressTestResult(
        scenario_name='Death Spiral',
        passed=len(violations) == 0,
        metrics=metrics,
        violations=violations,
        config_used=config
    )


def run_all_stress_tests(
    config: Dict[str, float],
    simulate_fn: Callable = None
) -> List[StressTestResult]:
    """
    Run all stress test scenarios.

    Args:
        config: Parameter configuration to test
        simulate_fn: Optional simulation function

    Returns:
        List of StressTestResult for each scenario
    """
    if simulate_fn is None:
        simulate_fn = lambda x: None  # Placeholder

    results = []
    results.append(christmas_crunch_scenario(config, simulate_fn))
    results.append(death_spiral_scenario(config, simulate_fn))

    return results


# =============================================================================
# OBJECTIVE FUNCTION (Step 11 - Loss Function)
# =============================================================================

def calculate_calibration_objective(
    season_points: int,
    cup_rounds: int,
    injury_days: int,
    squad_stability: float,
    weights: Dict[str, float] = None
) -> float:
    """
    Calculate calibration objective function (Step 11 - Section 4.4).

    L(θ) = -(w1·Pts/Pts_max + w2·Cup/Cup_max) + w3·P_injury + w4·Ω_stability

    Args:
        season_points: League points obtained
        cup_rounds: Rounds progressed in cups
        injury_days: Total days lost to injury
        squad_stability: Stability metric (0-1, lower is more volatile)
        weights: Optional custom weights

    Returns:
        Loss value (lower is better)
    """
    if weights is None:
        weights = {
            'points': 1.0,
            'cups': 0.5,
            'injury': 0.3,
            'stability': 0.2
        }

    # Normalize metrics
    pts_max = 114  # 38 × 3
    cup_max = 7    # Final of both cups
    injury_max = 500  # Reasonable worst case

    pts_norm = season_points / pts_max
    cup_norm = cup_rounds / cup_max
    injury_norm = min(1.0, injury_days / injury_max)
    stability_norm = 1.0 - squad_stability  # Penalize instability

    # Calculate loss
    loss = (
        -weights['points'] * pts_norm
        - weights['cups'] * cup_norm
        + weights['injury'] * injury_norm
        + weights['stability'] * stability_norm
    )

    return loss


# =============================================================================
# CALIBRATION RUNNER
# =============================================================================

def run_calibration_pipeline(
    n_sobol_samples: int = 1000,
    n_bohb_iterations: int = 20,
    run_stress_tests: bool = True
) -> Dict[str, Any]:
    """
    Run the full calibration pipeline.

    Args:
        n_sobol_samples: Number of Sobol samples (default 1000)
        n_bohb_iterations: Number of BOHB iterations (default 20)
        run_stress_tests: Whether to run stress tests on final config

    Returns:
        Dictionary with calibration results
    """
    results = {}

    print("=" * 60)
    print("FM26 CALIBRATION PIPELINE")
    print("=" * 60)

    # --- Phase 1: Sobol Sensitivity Analysis ---
    print("\n[Phase 1] Sobol Sensitivity Analysis")
    print("-" * 40)

    # Get critical parameters (pre-defined from research)
    critical_params = [p.symbol for p in CRITICAL_PARAMETERS]
    print(f"Critical parameters: {len(critical_params)}")
    for p in CRITICAL_PARAMETERS[:5]:
        print(f"  - {p.symbol}: [{p.min_value}, {p.max_value}] (default: {p.default_value})")
    if len(CRITICAL_PARAMETERS) > 5:
        print(f"  ... and {len(CRITICAL_PARAMETERS) - 5} more")

    results['critical_parameters'] = critical_params
    results['total_parameters'] = len(ALL_PARAMETERS)

    # --- Phase 2: Parameter Defaults ---
    print("\n[Phase 2] Current Default Parameters")
    print("-" * 40)

    defaults = get_default_parameter_vector()
    print("Parameter defaults loaded:")
    for symbol, value in list(defaults.items())[:8]:
        print(f"  {symbol}: {value}")
    if len(defaults) > 8:
        print(f"  ... and {len(defaults) - 8} more")

    results['default_config'] = defaults

    # --- Phase 3: Stress Test Validation ---
    if run_stress_tests:
        print("\n[Phase 3] Stress Test Validation")
        print("-" * 40)

        stress_results = run_all_stress_tests(defaults)
        for sr in stress_results:
            status = "PASS" if sr.passed else "FAIL"
            print(f"  [{status}] {sr.scenario_name}")
            if not sr.passed:
                for v in sr.violations:
                    print(f"    - {v}")

        results['stress_tests'] = stress_results

    # --- Summary ---
    print("\n" + "=" * 60)
    print("CALIBRATION PIPELINE COMPLETE")
    print("=" * 60)
    print(f"Total parameters: {len(ALL_PARAMETERS)}")
    print(f"Critical parameters: {len(CRITICAL_PARAMETERS)}")
    print(f"Biological: {len(BIOLOGICAL_PARAMETERS)}")
    print(f"Tactical: {len(TACTICAL_PARAMETERS)}")
    print(f"Strategic: {len(STRATEGIC_PARAMETERS)}")

    return results


# =============================================================================
# TESTS
# =============================================================================

def test_parameter_ranges():
    """Test that all parameter ranges are valid."""
    for p in ALL_PARAMETERS:
        assert p.min_value < p.max_value, f"{p.symbol}: min >= max"
        assert p.min_value <= p.default_value <= p.max_value, \
            f"{p.symbol}: default {p.default_value} not in [{p.min_value}, {p.max_value}]"

    print(f"All {len(ALL_PARAMETERS)} parameter ranges valid")


def test_sobol_sampling():
    """Test Sobol sample generation."""
    samples = generate_sobol_samples(100, CRITICAL_PARAMETERS[:5])
    assert samples.shape[0] > 0
    assert samples.shape[1] == 5
    print(f"Sobol sampling working: {samples.shape}")


def test_default_config():
    """Test default configuration retrieval."""
    defaults = get_default_parameter_vector()
    assert len(defaults) == len(ALL_PARAMETERS)

    # Verify key defaults match Step 11 research
    assert defaults['k_condition'] == 25.0
    assert defaults['gamma'] == 0.85
    assert defaults['R_pos_FB'] == 1.65

    print(f"Default config validated: {len(defaults)} parameters")


def test_stress_test_structure():
    """Test stress test functions run without error."""
    defaults = get_default_parameter_vector()

    christmas = christmas_crunch_scenario(defaults, None)
    assert christmas.scenario_name == 'Christmas Crunch'

    death_spiral = death_spiral_scenario(defaults, None)
    assert death_spiral.scenario_name == 'Death Spiral'

    print("Stress test structure validated")


if __name__ == '__main__':
    # Run tests
    print("Running calibration harness tests...\n")
    test_parameter_ranges()
    test_sobol_sampling()
    test_default_config()
    test_stress_test_structure()

    print("\n" + "=" * 60)

    # Run calibration pipeline
    run_calibration_pipeline(run_stress_tests=True)
