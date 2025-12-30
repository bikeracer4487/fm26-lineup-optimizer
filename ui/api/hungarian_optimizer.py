"""
FM26 Hungarian Matrix Optimizer
===============================

Implements two-stage Hungarian algorithm for optimal lineup selection
based on Step 4 research findings.

Key Features:
1. Two-Stage Algorithm: Stage 1 (Starting XI), Stage 2 (Bench)
2. Big M Constraint Handling: Uses 10^6 (not infinity - causes SciPy errors)
3. Multi-Objective Scalarization: Weights for performance, development, rest
4. Condition Cliff Enforcement: Hard constraints on player condition

References:
- docs/new-research/04-RESULTS-hungarian-matrix.md (Step 4 Research)
- docs/new-research/12-IMPLEMENTATION-PLAN.md (consolidated specification)

Stage 1: Select Starting XI
- Maximize total GSS (Global Selection Score)
- Apply hard constraints (condition floor, injury, unavailability)
- Use Big M for forbidden assignments

Stage 2: Select Bench (after Stage 1)
- Make Stage 1 players unavailable
- Select from remaining players
- Apply same constraints with bench-specific weights
"""

import numpy as np
from typing import Dict, List, Tuple, Optional, Any
from dataclasses import dataclass
from scipy.optimize import linear_sum_assignment
import sys
import os

# Add parent to path for imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from scoring_parameters import (
    BIG_M,
    SCENARIO_WEIGHTS,
    CONDITION_CLIFF,
    get_condition_cliff_multiplier,
    CONDITION_FLOOR,
)


@dataclass
class HungarianResult:
    """Result from Hungarian optimization."""
    assignments: Dict[str, Tuple[str, float]]  # position -> (player_name, score)
    total_score: float
    stage: int  # 1 for Starting XI, 2 for Bench
    excluded_players: List[str]  # Players not available for this stage


@dataclass
class OptimizationConfig:
    """Configuration for Hungarian optimization."""
    scenario: str = 'league_grind'  # Scenario for scalarization weights
    enforce_condition_floor: bool = True  # Hard constraint on 91% condition
    use_big_m: bool = True  # Use Big M for forbidden assignments
    bench_size: int = 7  # Number of bench players to select
    debug: bool = False


def get_scenario_weights(scenario: str) -> Dict[str, float]:
    """
    Get scalarization weights for a scenario.

    Args:
        scenario: Scenario name ('cup_final', 'league_grind', 'dead_rubber', 'sharpness')

    Returns:
        Dict with 'perf', 'dev', 'rest' weights
    """
    return SCENARIO_WEIGHTS.get(scenario, SCENARIO_WEIGHTS['league_grind'])


def create_cost_matrix(
    players: List[Dict[str, Any]],
    positions: List[str],
    get_player_score: callable,
    config: OptimizationConfig,
    excluded_players: Optional[List[str]] = None
) -> Tuple[np.ndarray, List[str], List[str]]:
    """
    Create cost matrix for Hungarian algorithm.

    Args:
        players: List of player dictionaries with attributes
        positions: List of position identifiers
        get_player_score: Callable(player, position) -> score
        config: Optimization configuration
        excluded_players: Players to exclude (e.g., already selected in Stage 1)

    Returns:
        Tuple of (cost_matrix, player_names, position_names)
    """
    excluded = set(excluded_players or [])

    n_players = len(players)
    n_positions = len(positions)

    # Initialize with Big M (forbidden assignments)
    if config.use_big_m:
        cost_matrix = np.full((n_players, n_positions), BIG_M)
    else:
        cost_matrix = np.full((n_players, n_positions), 999.0)

    player_names = []

    for i, player in enumerate(players):
        player_name = player.get('Name', f'Player_{i}')
        player_names.append(player_name)

        # Skip excluded players (already selected or unavailable)
        if player_name in excluded:
            continue

        # Check hard constraints
        is_injured = player.get('Is Injured', False)
        if is_injured:
            continue  # Keep Big M for injured players

        # Get condition and check floor
        condition = player.get('Condition', 100)
        if condition > 100:
            condition = condition / 10000.0
        elif condition > 1:
            condition = condition / 100.0

        if config.enforce_condition_floor and condition < CONDITION_FLOOR:
            continue  # Keep Big M for players below condition floor

        # Calculate condition cliff multiplier
        cliff_mult = get_condition_cliff_multiplier(condition)
        if cliff_mult >= BIG_M:
            continue  # Keep Big M for forbidden condition

        for j, position in enumerate(positions):
            # Get base score for this player-position combination
            base_score = get_player_score(player, position)

            if base_score <= 0:
                continue  # Keep Big M for invalid assignments

            # Apply condition cliff multiplier
            adjusted_score = base_score * cliff_mult

            # Cost matrix uses negative scores (minimization problem)
            # So higher score = lower (more negative) cost = preferred
            cost_matrix[i, j] = -adjusted_score

    return cost_matrix, player_names, positions


def solve_hungarian(
    cost_matrix: np.ndarray,
    player_names: List[str],
    position_names: List[str],
    stage: int = 1,
    debug: bool = False
) -> HungarianResult:
    """
    Solve Hungarian assignment problem.

    Args:
        cost_matrix: Cost matrix (n_players x n_positions)
        player_names: List of player names
        position_names: List of position names
        stage: Stage number (1 for Starting XI, 2 for Bench)
        debug: Enable debug output

    Returns:
        HungarianResult with assignments
    """
    # Solve using scipy's linear_sum_assignment
    row_ind, col_ind = linear_sum_assignment(cost_matrix)

    assignments = {}
    total_score = 0.0
    assigned_players = []

    for i, j in zip(row_ind, col_ind):
        cost = cost_matrix[i, j]

        # Skip Big M assignments (forbidden)
        if cost >= BIG_M - 1:
            continue

        player_name = player_names[i]
        position = position_names[j]
        score = -cost  # Convert back from cost to score

        assignments[position] = (player_name, score)
        total_score += score
        assigned_players.append(player_name)

        if debug:
            print(f"  Stage {stage}: {position:8} <- {player_name:20} (score: {score:.1f})")

    return HungarianResult(
        assignments=assignments,
        total_score=total_score,
        stage=stage,
        excluded_players=assigned_players
    )


def optimize_two_stage(
    players: List[Dict[str, Any]],
    starting_positions: List[str],
    bench_positions: List[str],
    get_player_score: callable,
    config: Optional[OptimizationConfig] = None
) -> Tuple[HungarianResult, HungarianResult]:
    """
    Two-stage Hungarian optimization: Starting XI then Bench.

    Stage 1: Select optimal Starting XI (11 players)
    Stage 2: Select optimal Bench from remaining players

    Args:
        players: List of player dictionaries
        starting_positions: List of starting position identifiers
        bench_positions: List of bench position identifiers
        get_player_score: Callable(player, position) -> score
        config: Optimization configuration

    Returns:
        Tuple of (stage1_result, stage2_result)
    """
    if config is None:
        config = OptimizationConfig()

    if config.debug:
        print(f"\n=== Two-Stage Hungarian Optimization ===")
        print(f"Scenario: {config.scenario}")
        print(f"Players: {len(players)}, Starting positions: {len(starting_positions)}")

    # Stage 1: Starting XI
    if config.debug:
        print(f"\n--- Stage 1: Starting XI ---")

    cost_matrix_1, player_names, position_names = create_cost_matrix(
        players, starting_positions, get_player_score, config
    )

    stage1_result = solve_hungarian(
        cost_matrix_1, player_names, position_names, stage=1, debug=config.debug
    )

    if config.debug:
        print(f"Stage 1 total score: {stage1_result.total_score:.1f}")

    # Stage 2: Bench (exclude Stage 1 players)
    if config.debug:
        print(f"\n--- Stage 2: Bench (excluding {len(stage1_result.excluded_players)} Stage 1 players) ---")

    cost_matrix_2, player_names_2, position_names_2 = create_cost_matrix(
        players, bench_positions, get_player_score, config,
        excluded_players=stage1_result.excluded_players
    )

    stage2_result = solve_hungarian(
        cost_matrix_2, player_names_2, position_names_2, stage=2, debug=config.debug
    )

    if config.debug:
        print(f"Stage 2 total score: {stage2_result.total_score:.1f}")
        print(f"\nCombined score: {stage1_result.total_score + stage2_result.total_score:.1f}")

    return stage1_result, stage2_result


def create_scalarized_cost(
    perf_cost: float,
    dev_cost: float,
    rest_cost: float,
    scenario: str = 'league_grind'
) -> float:
    """
    Create scalarized cost from multi-objective components.

    Formula: C_total = w_perf × C_perf + w_dev × C_dev + w_rest × C_rest

    Args:
        perf_cost: Performance cost (higher = better player for position)
        dev_cost: Development cost (higher = better development opportunity)
        rest_cost: Rest cost (higher = player needs rest more)
        scenario: Scenario name for weight selection

    Returns:
        Scalarized total cost
    """
    weights = get_scenario_weights(scenario)
    return (
        weights['perf'] * perf_cost +
        weights['dev'] * dev_cost +
        weights['rest'] * rest_cost
    )


def apply_feasibility_constraints(
    cost_matrix: np.ndarray,
    players: List[Dict[str, Any]],
    positions: List[str],
    player_names: List[str]
) -> np.ndarray:
    """
    Apply feasibility constraints using Big M.

    Hard constraints that make assignments forbidden:
    1. Player injured
    2. Player condition below 75%
    3. Player unavailable (suspended, on loan, etc.)
    4. Player familiarity = 0 for position

    Args:
        cost_matrix: Current cost matrix
        players: List of player dictionaries
        positions: List of positions
        player_names: List of player names

    Returns:
        Updated cost matrix with Big M for forbidden assignments
    """
    for i, player in enumerate(players):
        player_name = player_names[i]

        # Check injury
        if player.get('Is Injured', False):
            cost_matrix[i, :] = BIG_M
            continue

        # Check unavailability
        if player.get('Unavailable', False) or player.get('On Loan', False):
            cost_matrix[i, :] = BIG_M
            continue

        # Check condition floor (75% absolute minimum)
        condition = player.get('Condition', 100)
        if condition > 100:
            condition = condition / 10000.0
        elif condition > 1:
            condition = condition / 100.0

        if condition < 0.75:
            cost_matrix[i, :] = BIG_M
            continue

        # Check per-position constraints (familiarity = 0)
        for j, position in enumerate(positions):
            familiarity = player.get(f'{position}_Familiarity', 1)
            if familiarity <= 0:
                cost_matrix[i, j] = BIG_M

    return cost_matrix


# Convenience function for single-stage optimization (backward compatibility)
def optimize_lineup(
    players: List[Dict[str, Any]],
    positions: List[str],
    get_player_score: callable,
    config: Optional[OptimizationConfig] = None
) -> HungarianResult:
    """
    Single-stage Hungarian optimization (backward compatible).

    Args:
        players: List of player dictionaries
        positions: List of position identifiers
        get_player_score: Callable(player, position) -> score
        config: Optimization configuration

    Returns:
        HungarianResult with assignments
    """
    if config is None:
        config = OptimizationConfig()

    cost_matrix, player_names, position_names = create_cost_matrix(
        players, positions, get_player_score, config
    )

    return solve_hungarian(
        cost_matrix, player_names, position_names, stage=1, debug=config.debug
    )
