"""
FM26 Shadow Pricing for Receding Horizon Control
================================================

Implements the Shadow Pricing mechanism for 5-match planning optimization.

The core insight: Using a player today has an "opportunity cost" if they're
needed for a more important future match. Shadow pricing quantifies this cost
to enable proactive rotation planning.

Shadow Cost Formula:
    Cost_shadow(p, k) = Sum_{m=k+1}^{4} (
        (Imp_m / Imp_avg) * (Utility(p,m) / DeltaDays_{k,m}) * IsKeyPlayer(p)
    )

Where:
- Imp_m: Importance weight of future match m
- Imp_avg: Average importance across all matches
- Utility(p,m): Player's utility for match m
- DeltaDays: Days between current match k and future match m
- IsKeyPlayer: 1.0 for key players, 0.5 for others

Reference: docs/new-research/FM26 #1 - System spec + decision model (foundation).md
"""

from typing import Dict, List, Any, Tuple
from datetime import datetime
import sys
import os

# Add parent to path for imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from scoring_parameters import (
    get_importance_weight,
    get_context_parameters,
    KEY_PLAYER_CA_THRESHOLD,
)
from ui.api.scoring_model import calculate_match_utility
from ui.api.state_simulation import PlayerState, simulate_match_impact, simulate_rest_recovery


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
