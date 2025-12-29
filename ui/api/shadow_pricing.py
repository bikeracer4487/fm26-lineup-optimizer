"""
FM26 Shadow Pricing for Receding Horizon Control
================================================

Implements the Shadow Pricing mechanism for 5-match planning optimization.

The core insight: Using a player today has an "opportunity cost" if they're
needed for a more important future match. Shadow pricing quantifies this cost
to enable proactive rotation planning.

Simple Shadow Cost Formula (from FM26 #2 spec Section E):
    Cost_shadow(p, k) = Sum_{m=k+1}^{4} (
        gamma^(m-k) * Imp_m * (Utility_rest(p,m) - Utility_play(p,m))
    )

Where:
- gamma: Discount factor (0.85 by default)
- Imp_m: Importance weight of future match m
- Utility_rest(p,m): Projected utility if player rests at match k
- Utility_play(p,m): Projected utility if player plays at match k

Updated Importance Weights (from FM26 #2 spec):
- High: 1.5
- Medium: 1.0
- Low: 0.6
- Sharpness: 0.8

References:
- docs/new-research/FM26 #1 - System spec + decision model (foundation).md
- docs/new-research/FM26 #2 - Lineup Optimizer - Complete Mathematical Specification.md
"""

from typing import Dict, List, Any, Tuple, Optional
from datetime import datetime
import sys
import os

# Add parent to path for imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from scoring_parameters import (
    get_importance_weight,
    get_context_parameters,
    KEY_PLAYER_CA_THRESHOLD,
    SHADOW_DISCOUNT_FACTOR,
    IMPORTANCE_WEIGHTS,
)
from ui.api.scoring_model import calculate_match_utility
from ui.api.state_simulation import (
    PlayerState, extract_player_state,
    simulate_match_impact, simulate_rest_recovery
)


def calculate_shadow_costs(
    players: List[Dict[str, Any]],
    matches: List[Dict[str, Any]],
    player_ratings: Dict[str, Dict[str, float]],
    training_intensity: str = 'Medium'
) -> Dict[str, List[float]]:
    """
    Calculate shadow costs for all players across all matches.

    The shadow cost represents the "opportunity cost" of using a player
    in the current match. High shadow cost means the player is valuable
    for an upcoming high-importance match and should be preserved.

    Args:
        players: List of player data dicts
        matches: List of match dicts with 'date', 'importance', 'opponent'
        player_ratings: Dict of player_name -> {position: rating}
        training_intensity: Club's training intensity

    Returns:
        Dict mapping player_name -> [cost_at_match_0, cost_at_match_1, ...]
    """
    shadow_costs: Dict[str, List[float]] = {}

    if not matches:
        return shadow_costs

    # Calculate average importance weight
    total_importance = sum(
        get_importance_weight(m.get('importance', 'Medium'))
        for m in matches
    )
    avg_importance = total_importance / len(matches) if matches else 1.0

    # Parse match dates
    match_dates = []
    for m in matches:
        try:
            date_str = m.get('date', '')
            match_dates.append(datetime.strptime(date_str, '%Y-%m-%d'))
        except (ValueError, TypeError):
            match_dates.append(datetime.now())

    for player_data in players:
        player_name = player_data.get('Name', '')
        player_ca = player_data.get('CA', 100)

        # Determine if this is a key player
        is_key_player = 1.0 if player_ca >= KEY_PLAYER_CA_THRESHOLD else 0.5

        # Get player's best rating (as proxy for general utility)
        player_rating_map = player_ratings.get(player_name, {})
        best_rating = max(player_rating_map.values()) if player_rating_map else 100

        costs = []

        for k in range(len(matches)):
            # Calculate shadow cost for match k
            cost = 0.0

            for m in range(k + 1, len(matches)):
                future_match = matches[m]
                future_importance = get_importance_weight(
                    future_match.get('importance', 'Medium')
                )

                # Importance ratio (how much more important is future match?)
                importance_ratio = future_importance / avg_importance

                # Days between matches
                delta_days = max(1, (match_dates[m] - match_dates[k]).days)

                # Estimated utility for future match
                # Use best rating as proxy (actual would require full calculation)
                future_utility = best_rating

                # Shadow cost contribution
                # Higher cost when: future match is important, player is key, matches are close
                cost_contribution = (
                    importance_ratio *
                    future_utility *
                    is_key_player /
                    delta_days
                )

                cost += cost_contribution

            costs.append(cost)

        shadow_costs[player_name] = costs

    return shadow_costs


def calculate_detailed_shadow_cost(
    player_data: Dict[str, Any],
    current_match_idx: int,
    matches: List[Dict[str, Any]],
    get_player_utility: callable,
    training_intensity: str = 'Medium'
) -> Tuple[float, Dict[str, Any]]:
    """
    Calculate detailed shadow cost with breakdown for explainability.

    Args:
        player_data: Player's full data dict
        current_match_idx: Index of current match (k)
        matches: List of all matches
        get_player_utility: Function(player_data, match, context) -> utility
        training_intensity: Club's training intensity

    Returns:
        Tuple of (total_shadow_cost, breakdown_dict)
    """
    player_name = player_data.get('Name', '')
    player_ca = player_data.get('CA', 100)
    is_key_player = 1.0 if player_ca >= KEY_PLAYER_CA_THRESHOLD else 0.5

    # Parse match dates
    match_dates = []
    for m in matches:
        try:
            date_str = m.get('date', '')
            match_dates.append(datetime.strptime(date_str, '%Y-%m-%d'))
        except (ValueError, TypeError):
            match_dates.append(datetime.now())

    # Calculate average importance
    avg_importance = sum(
        get_importance_weight(m.get('importance', 'Medium'))
        for m in matches
    ) / len(matches) if matches else 1.0

    total_cost = 0.0
    breakdown = {
        'player': player_name,
        'is_key_player': player_ca >= KEY_PLAYER_CA_THRESHOLD,
        'current_match_idx': current_match_idx,
        'future_match_contributions': []
    }

    for m in range(current_match_idx + 1, len(matches)):
        future_match = matches[m]
        future_importance_raw = future_match.get('importance', 'Medium')
        future_importance = get_importance_weight(future_importance_raw)

        # Get context for future match
        context = get_context_parameters(future_importance_raw, training_intensity)

        # Calculate utility for future match
        future_utility = get_player_utility(player_data, future_match, context)

        # Days between matches
        delta_days = max(1, (match_dates[m] - match_dates[current_match_idx]).days)

        # Shadow cost contribution
        importance_ratio = future_importance / avg_importance
        cost_contribution = (
            importance_ratio *
            future_utility *
            is_key_player /
            delta_days
        )

        total_cost += cost_contribution

        breakdown['future_match_contributions'].append({
            'match_idx': m,
            'opponent': future_match.get('opponent', 'Unknown'),
            'importance': future_importance_raw,
            'days_away': delta_days,
            'utility': future_utility,
            'cost_contribution': cost_contribution
        })

    breakdown['total_shadow_cost'] = total_cost

    return total_cost, breakdown


def get_adjusted_utility(
    base_utility: float,
    shadow_cost: float,
    importance: str = 'Medium'
) -> float:
    """
    Calculate adjusted utility by subtracting shadow cost.

    For High importance matches, shadow cost is reduced (we want best XI).
    For Low importance matches, shadow cost has full effect (save players).

    Args:
        base_utility: Player's base match utility
        shadow_cost: Calculated shadow cost for this player/match
        importance: Current match importance

    Returns:
        Adjusted utility for cost matrix
    """
    # Scale shadow cost based on current match importance
    # High importance: We need best XI, so reduce shadow cost impact
    # Low importance: We can afford to save players, full shadow cost
    importance_scaling = {
        'High': 0.3,      # Only 30% of shadow cost applies
        'Medium': 0.7,    # 70% of shadow cost applies
        'Low': 1.0,       # Full shadow cost applies
        'Sharpness': 0.5  # Half shadow cost (development focus)
    }

    scaling = importance_scaling.get(importance, 0.7)
    adjusted_shadow = shadow_cost * scaling

    # Don't let shadow cost make utility negative
    return max(0, base_utility - adjusted_shadow)


def identify_players_to_preserve(
    shadow_costs: Dict[str, List[float]],
    current_match_idx: int,
    top_n: int = 5
) -> List[Tuple[str, float]]:
    """
    Identify players with highest shadow costs (most valuable to preserve).

    Args:
        shadow_costs: Dict of player_name -> [costs]
        current_match_idx: Current match index
        top_n: Number of top players to return

    Returns:
        List of (player_name, shadow_cost) tuples, sorted by cost descending
    """
    costs_at_current = []

    for player_name, costs in shadow_costs.items():
        if current_match_idx < len(costs):
            costs_at_current.append((player_name, costs[current_match_idx]))

    # Sort by shadow cost descending
    costs_at_current.sort(key=lambda x: x[1], reverse=True)

    return costs_at_current[:top_n]


def should_rest_player_for_shadow(
    player_name: str,
    shadow_costs: Dict[str, List[float]],
    current_match_idx: int,
    base_utility: float,
    importance: str = 'Medium',
    threshold_ratio: float = 0.5
) -> Tuple[bool, str]:
    """
    Determine if a player should be rested based on shadow pricing.

    If the shadow cost exceeds a threshold fraction of base utility,
    the player is valuable enough for future matches to consider resting.

    Args:
        player_name: Player to check
        shadow_costs: Shadow cost dict
        current_match_idx: Current match index
        base_utility: Player's utility for current match
        importance: Current match importance
        threshold_ratio: Shadow cost / utility ratio threshold

    Returns:
        Tuple of (should_rest: bool, reason: str)
    """
    if importance == 'High':
        # Never rest for shadow in High importance matches
        return False, ""

    costs = shadow_costs.get(player_name, [])
    if current_match_idx >= len(costs):
        return False, ""

    shadow_cost = costs[current_match_idx]

    if base_utility <= 0:
        return False, ""

    ratio = shadow_cost / base_utility

    if ratio >= threshold_ratio:
        return True, f"High future value (shadow cost ratio: {ratio:.2f})"

    return False, ""


def compute_shadow_costs_simple(
    players: List[Dict[str, Any]],
    matches: List[Dict[str, Any]],
    compute_utility_func: Optional[callable] = None,
    training_intensity: str = 'Medium',
    gamma: float = SHADOW_DISCOUNT_FACTOR
) -> Dict[str, List[float]]:
    """
    Simple shadow pricing based on future match importance (FM26 #2 spec).

    This is the recommended O(n x k) approach from the mathematical specification.

    Formula:
        Cost_shadow(p, k) = Sum_{m=k+1}^{horizon} (
            gamma^(m-k) * Imp_m * (Utility_rest(p,m) - Utility_play(p,m))
        )

    Args:
        players: List of player data dicts
        matches: List of match dicts with 'date', 'importance', 'opponent'
        compute_utility_func: Optional function(player_data, context) -> utility
                             If None, uses best_rating as proxy
        training_intensity: Club's training intensity
        gamma: Discount factor for future matches (default: 0.85)

    Returns:
        Dict mapping player_name -> [shadow_cost_at_match_0, ...]
    """
    shadow: Dict[str, List[float]] = {}

    if not matches:
        return shadow

    horizon = len(matches)

    # Parse match dates
    match_dates = []
    for m in matches:
        try:
            date_str = m.get('date', '')
            match_dates.append(datetime.strptime(date_str, '%Y-%m-%d'))
        except (ValueError, TypeError):
            match_dates.append(datetime.now())

    for player_data in players:
        player_name = player_data.get('Name', '')
        player_ca = player_data.get('CA', 100)

        # Key player multiplier
        is_key_player = 1.0 if player_ca >= KEY_PLAYER_CA_THRESHOLD else 0.5

        costs = []

        for k in range(horizon):
            future_value = 0.0

            for j in range(k + 1, horizon):
                future_match = matches[j]
                importance_raw = future_match.get('importance', 'Medium')
                imp_weight = get_importance_weight(importance_raw)

                # Days between current match k and future match j
                delta_days = max(1, (match_dates[j] - match_dates[k]).days)

                # Get context for future match
                future_context = get_context_parameters(importance_raw, training_intensity)

                if compute_utility_func is not None:
                    # Use provided utility function
                    # Project states if player plays vs rests at match k
                    state = extract_player_state(player_data)

                    # State if player plays at match k
                    state_if_play = simulate_match_impact(state, minutes_played=90)
                    state_if_play = simulate_rest_recovery(state_if_play, delta_days, future_context)

                    # State if player rests at match k
                    state_if_rest = simulate_rest_recovery(state, delta_days, future_context)

                    # Convert states back to player data for utility calculation
                    player_if_play = player_data.copy()
                    player_if_play['Condition'] = state_if_play.condition
                    player_if_play['Match Sharpness'] = state_if_play.sharpness
                    player_if_play['Fatigue'] = state_if_play.fatigue

                    player_if_rest = player_data.copy()
                    player_if_rest['Condition'] = state_if_rest.condition
                    player_if_rest['Match Sharpness'] = state_if_rest.sharpness
                    player_if_rest['Fatigue'] = state_if_rest.fatigue

                    util_if_play = compute_utility_func(player_if_play, future_context)
                    util_if_rest = compute_utility_func(player_if_rest, future_context)

                    utility_diff = util_if_rest - util_if_play
                else:
                    # Fallback: Use simple heuristic based on recovery time
                    # More rest = better condition = higher utility
                    recovery_bonus = min(15, delta_days * 3)  # Up to 15% recovery bonus
                    utility_diff = recovery_bonus * (player_ca / 150)  # Scale by ability

                # Apply discount and importance weighting
                discount = gamma ** (j - k)
                future_value += discount * imp_weight * utility_diff * is_key_player

            # Shadow cost is non-negative (opportunity cost can't be negative)
            costs.append(max(0, future_value))

        shadow[player_name] = costs

    return shadow


def compute_shadow_cost_for_match(
    player_data: Dict[str, Any],
    current_match_idx: int,
    matches: List[Dict[str, Any]],
    compute_utility_func: Optional[callable] = None,
    training_intensity: str = 'Medium',
    gamma: float = SHADOW_DISCOUNT_FACTOR
) -> float:
    """
    Compute shadow cost for a single player at a single match.

    Useful for on-demand calculation without computing the full matrix.

    Args:
        player_data: Player's full data dict
        current_match_idx: Index of current match (k)
        matches: List of all matches
        compute_utility_func: Optional utility function
        training_intensity: Club's training intensity
        gamma: Discount factor

    Returns:
        Shadow cost value (>= 0)
    """
    if current_match_idx >= len(matches):
        return 0.0

    # Compute shadow costs for this single player
    shadow = compute_shadow_costs_simple(
        players=[player_data],
        matches=matches,
        compute_utility_func=compute_utility_func,
        training_intensity=training_intensity,
        gamma=gamma
    )

    player_name = player_data.get('Name', '')
    costs = shadow.get(player_name, [])

    if current_match_idx < len(costs):
        return costs[current_match_idx]
    return 0.0
