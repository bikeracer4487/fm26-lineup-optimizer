"""
FM26 Shadow Pricing for Receding Horizon Control
================================================

Implements the Shadow Pricing mechanism for 5-match planning optimization.

The core insight: Using a player today has an "opportunity cost" if they're
needed for a more important future match. Shadow pricing quantifies this cost
to enable proactive rotation planning.

Updated Shadow Cost Formula (Step 5 Research):
    λ_{p,t} = S_p^{VORP} × Σ_{k=t+1}^{T} (γ^{k-t} × I_k × max(0, ΔGSS_{p,k}))

Where:
- S_p^{VORP}: VORP scarcity index (1.0 to 2.0) - key players get more protection
- γ (gamma): Discount factor (0.85) - future matches worth less
- I_k: Importance weight of match k (0.1 to 10.0)
- ΔGSS: GSS improvement from resting (GSS_if_rest - GSS_if_play)

VORP Scarcity Index (Step 5 Research):
    α_scarcity = 1 + λ_V × min(0.5, (GSS_star - GSS_backup) / GSS_star)

    Gap% > 10% means player is "Key" and gets higher shadow protection.

Importance Weights (Step 5 Research):
| Scenario        | Weight |
|-----------------|--------|
| Cup Final       | 10.0   |
| Continental KO  | 5.0    |
| Title Rival     | 3.0    |
| Standard League | 1.5    |
| Cup Early       | 0.8    |
| Dead Rubber     | 0.1    |

References:
- docs/new-research/05-RESULTS-shadow-pricing.md (Step 5 Research)
- docs/new-research/12-IMPLEMENTATION-PLAN.md (consolidated specification)
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
    # New Step 5 Research imports
    SHADOW_DISCOUNT_GAMMA,
    SHADOW_WEIGHT,
    VORP_SCARCITY_LAMBDA,
    calculate_vorp_scarcity,
    get_detailed_importance_weight,
    IMPORTANCE_WEIGHTS_DETAILED,
)
from ui.api.scoring_model import calculate_match_utility_gss as calculate_match_utility
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


# =============================================================================
# STEP 5 RESEARCH: GSS-BASED SHADOW PRICING WITH VORP SCARCITY
# =============================================================================

def calculate_shadow_cost_gss(
    player_gss: float,
    backup_gss: float,
    current_match_idx: int,
    matches: List[Dict[str, Any]],
    gss_if_play: List[float],
    gss_if_rest: List[float],
    gamma: float = SHADOW_DISCOUNT_GAMMA
) -> Tuple[float, Dict[str, Any]]:
    """
    Calculate shadow cost using Step 5 research formula with VORP scarcity.

    Formula:
        λ_{p,t} = S_p^{VORP} × Σ_{k=t+1}^{T} (γ^{k-t} × I_k × max(0, ΔGSS_{p,k}))

    Args:
        player_gss: Player's current GSS (Global Selection Score)
        backup_gss: Best backup's GSS for the same position
        current_match_idx: Index of current match (t)
        matches: List of all matches in planning horizon
        gss_if_play: List of projected GSS if player plays at current match
        gss_if_rest: List of projected GSS if player rests at current match
        gamma: Discount factor (default 0.85)

    Returns:
        Tuple of (shadow_cost, breakdown_dict)
    """
    # Calculate VORP scarcity multiplier
    vorp_scarcity = calculate_vorp_scarcity(player_gss, backup_gss)

    shadow_cost = 0.0
    contributions = []

    # Sum over future matches
    for k in range(current_match_idx + 1, len(matches)):
        if k >= len(gss_if_play) or k >= len(gss_if_rest):
            break

        match = matches[k]
        importance_raw = match.get('importance', 'Medium')

        # Get detailed importance weight (Step 5 research)
        # Try match type first, fall back to importance level
        match_type = match.get('match_type', importance_raw.lower())
        try:
            importance_weight = get_detailed_importance_weight(match_type)
        except (KeyError, AttributeError):
            importance_weight = get_importance_weight(importance_raw)

        # Calculate GSS difference (benefit of resting)
        delta_gss = max(0, gss_if_rest[k] - gss_if_play[k])

        # Apply discount factor
        time_discount = gamma ** (k - current_match_idx)

        # Shadow cost contribution for this future match
        contribution = time_discount * importance_weight * delta_gss

        shadow_cost += contribution

        contributions.append({
            'match_idx': k,
            'opponent': match.get('opponent', 'Unknown'),
            'importance': importance_raw,
            'importance_weight': importance_weight,
            'time_discount': time_discount,
            'delta_gss': delta_gss,
            'contribution': contribution
        })

    # Apply VORP scarcity multiplier
    final_shadow_cost = vorp_scarcity * shadow_cost

    breakdown = {
        'player_gss': player_gss,
        'backup_gss': backup_gss,
        'vorp_scarcity': vorp_scarcity,
        'raw_shadow_cost': shadow_cost,
        'final_shadow_cost': final_shadow_cost,
        'contributions': contributions
    }

    return final_shadow_cost, breakdown


def compute_shadow_costs_gss(
    players: List[Dict[str, Any]],
    matches: List[Dict[str, Any]],
    compute_gss_func: callable,
    get_backup_gss_func: callable,
    training_intensity: str = 'Medium',
    gamma: float = SHADOW_DISCOUNT_GAMMA
) -> Dict[str, List[float]]:
    """
    Compute GSS-based shadow costs for all players across all matches.

    This is the Step 5 research implementation using VORP scarcity.

    Args:
        players: List of player data dicts
        matches: List of match dicts
        compute_gss_func: Function(player_data, match_idx, played_at_match_k) -> GSS
        get_backup_gss_func: Function(player_name, position) -> backup GSS
        training_intensity: Club's training intensity
        gamma: Discount factor

    Returns:
        Dict mapping player_name -> [shadow_cost_at_match_0, ...]
    """
    shadow_costs: Dict[str, List[float]] = {}

    if not matches:
        return shadow_costs

    horizon = len(matches)

    for player_data in players:
        player_name = player_data.get('Name', '')
        player_position = player_data.get('Best Position', 'M(C)')

        # Get player's current GSS and backup's GSS
        player_gss = compute_gss_func(player_data, 0, False)
        backup_gss = get_backup_gss_func(player_name, player_position)

        costs = []

        for k in range(horizon):
            # Project GSS for future matches if player plays vs rests at match k
            gss_if_play = []
            gss_if_rest = []

            for j in range(horizon):
                if j <= k:
                    # Matches before or at current - use actual current GSS
                    gss_if_play.append(player_gss)
                    gss_if_rest.append(player_gss)
                else:
                    # Future matches - project based on play/rest decision
                    # If player plays at match k, they're more fatigued at match j
                    gss_if_play.append(compute_gss_func(player_data, j, True))
                    gss_if_rest.append(compute_gss_func(player_data, j, False))

            # Calculate shadow cost at match k
            shadow_cost, _ = calculate_shadow_cost_gss(
                player_gss, backup_gss, k, matches,
                gss_if_play, gss_if_rest, gamma
            )

            costs.append(shadow_cost)

        shadow_costs[player_name] = costs

    return shadow_costs


def get_adjusted_utility_gss(
    base_gss: float,
    shadow_cost: float,
    importance: str = 'Medium',
    shadow_weight: float = SHADOW_WEIGHT
) -> float:
    """
    Calculate adjusted GSS by subtracting weighted shadow cost.

    For High importance matches, shadow cost has reduced effect (need best XI).
    For Low importance matches, shadow cost has full effect (preserve players).

    Args:
        base_gss: Player's base GSS for current match
        shadow_cost: Calculated shadow cost
        importance: Current match importance
        shadow_weight: Global shadow pricing weight (0-2)

    Returns:
        Adjusted GSS for selection
    """
    # Importance-based scaling of shadow cost effect
    importance_scaling = {
        'High': 0.2,       # Only 20% shadow effect - need best XI
        'Medium': 0.6,     # 60% shadow effect - balanced
        'Low': 1.0,        # Full shadow effect - preserve players
        'Sharpness': 0.4,  # 40% shadow effect - development focus
    }

    scaling = importance_scaling.get(importance, 0.6)
    effective_shadow = shadow_cost * scaling * shadow_weight

    # Don't let shadow cost make GSS negative
    return max(0, base_gss - effective_shadow)


def identify_key_players_vorp(
    players: List[Dict[str, Any]],
    compute_gss_func: callable,
    get_backup_gss_func: callable,
    key_threshold: float = 0.10
) -> List[Tuple[str, float, float]]:
    """
    Identify key players based on VORP gap to backup.

    Key player = Gap% > 10% (configurable threshold)

    Args:
        players: List of player data dicts
        compute_gss_func: Function(player_data, match_idx, played) -> GSS
        get_backup_gss_func: Function(player_name, position) -> backup GSS
        key_threshold: Gap% threshold to be considered "Key" (default 10%)

    Returns:
        List of (player_name, gap_pct, vorp_scarcity) for key players only
    """
    key_players = []

    for player_data in players:
        player_name = player_data.get('Name', '')
        player_position = player_data.get('Best Position', 'M(C)')

        player_gss = compute_gss_func(player_data, 0, False)
        backup_gss = get_backup_gss_func(player_name, player_position)

        if player_gss <= 0:
            continue

        gap_pct = (player_gss - backup_gss) / player_gss
        vorp_scarcity = calculate_vorp_scarcity(player_gss, backup_gss)

        if gap_pct >= key_threshold:
            key_players.append((player_name, gap_pct, vorp_scarcity))

    # Sort by gap percentage (most irreplaceable first)
    key_players.sort(key=lambda x: x[1], reverse=True)

    return key_players


def should_preserve_for_cup_final(
    player_name: str,
    shadow_costs: Dict[str, List[float]],
    current_match_idx: int,
    matches: List[Dict[str, Any]],
    threshold_multiplier: float = 2.0
) -> Tuple[bool, str]:
    """
    Check if player should be preserved for an upcoming Cup Final.

    Cup Finals have importance weight 10.0, so shadow cost will be
    significantly elevated if a Cup Final is in the planning horizon.

    Args:
        player_name: Player to check
        shadow_costs: Shadow cost dict
        current_match_idx: Current match index
        matches: List of all matches
        threshold_multiplier: How many times higher than average triggers preservation

    Returns:
        Tuple of (should_preserve, reason)
    """
    costs = shadow_costs.get(player_name, [])
    if current_match_idx >= len(costs):
        return False, ""

    player_cost = costs[current_match_idx]

    # Calculate average shadow cost for this match across all players
    all_costs_at_match = [
        costs[current_match_idx]
        for costs in shadow_costs.values()
        if current_match_idx < len(costs)
    ]

    if not all_costs_at_match:
        return False, ""

    avg_cost = sum(all_costs_at_match) / len(all_costs_at_match)

    if avg_cost <= 0:
        return False, ""

    # Check if this player's shadow cost is significantly above average
    if player_cost >= avg_cost * threshold_multiplier:
        # Find the Cup Final causing high shadow cost
        for m in range(current_match_idx + 1, len(matches)):
            match = matches[m]
            match_type = match.get('match_type', '').lower()
            importance = match.get('importance', '')

            if 'cup_final' in match_type or 'final' in match_type.lower():
                return True, f"Preserve for Cup Final vs {match.get('opponent', 'TBD')}"
            elif importance == 'High':
                return True, f"Preserve for High importance match vs {match.get('opponent', 'TBD')}"

    return False, ""
