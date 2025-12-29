"""
FM26 State Simulation Engine
============================

Simulates player state changes across multi-match planning horizons.
Used by the Receding Horizon Control (RHC) optimizer to project:
- Condition recovery and decay
- Sharpness gain from matches and decay from rest
- Fatigue accumulation and jadedness risk

Reference: docs/new-research/FM26 #1 - System spec + decision model (foundation).md
"""

from dataclasses import dataclass
from typing import Dict, Any, Optional, List
from copy import deepcopy
from datetime import datetime, timedelta
import sys
import os

# Add parent to path for imports
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from scoring_parameters import (
    ScoringContext,
    get_context_parameters,
    get_position_fatigue_multiplier,
    BASE_CONDITION_LOSS,
    BASE_CONDITION_RECOVERY,
    BASE_SHARPNESS_GAIN,
    BASE_SHARPNESS_DECAY,
    FATIGUE_THRESHOLD,
)


@dataclass
class PlayerState:
    """
    Represents a player's current physical and mental state.
    All values are normalized to 0-100 percentage scale.
    """
    name: str
    condition: float           # Physical condition (0-100)
    sharpness: float          # Match sharpness (0-100)
    fatigue: float            # Fatigue level (raw value, 0-1000+)
    recent_minutes: int       # Minutes played in recent matches
    is_jaded: bool            # Whether player has jadedness flag

    # Physical attributes that affect recovery/fatigue
    age: int = 25
    natural_fitness: int = 10
    stamina: int = 10
    injury_proneness: int = 10

    def copy(self) -> 'PlayerState':
        """Create a deep copy of this state."""
        return PlayerState(
            name=self.name,
            condition=self.condition,
            sharpness=self.sharpness,
            fatigue=self.fatigue,
            recent_minutes=self.recent_minutes,
            is_jaded=self.is_jaded,
            age=self.age,
            natural_fitness=self.natural_fitness,
            stamina=self.stamina,
            injury_proneness=self.injury_proneness
        )


def extract_player_state(player_data: Dict[str, Any]) -> PlayerState:
    """
    Extract PlayerState from raw player data dictionary.

    Args:
        player_data: Dict with player attributes from CSV/API

    Returns:
        PlayerState object
    """
    # Handle various condition formats (0-100 or 0-10000)
    condition = player_data.get('Condition', 100)
    if condition > 100:
        condition = condition / 100

    # Handle various sharpness formats
    sharpness = player_data.get('Match Sharpness', 100)
    if sharpness > 100:
        sharpness = sharpness / 100

    return PlayerState(
        name=player_data.get('Name', 'Unknown'),
        condition=condition,
        sharpness=sharpness,
        fatigue=player_data.get('Fatigue', 0),
        recent_minutes=player_data.get('Recent_Minutes', 0),
        is_jaded=player_data.get('Is Jaded', False) or player_data.get('Jadedness', False),
        age=player_data.get('Age', 25),
        natural_fitness=player_data.get('Natural Fitness', 10),
        stamina=player_data.get('Stamina', 10),
        injury_proneness=player_data.get('Injury Proneness', 10)
    )


def simulate_match_impact(
    state: PlayerState,
    minutes_played: int,
    position: str = 'M(C)',
    context: Optional[ScoringContext] = None
) -> PlayerState:
    """
    Simulate the impact of playing a match on player state.

    Research-based formulas:
    - Condition loss: ~15% per 90 mins, modified by stamina
    - Sharpness gain: ~5% per 90 mins, capped at 100%
    - Fatigue accumulation: Based on position and physical attributes

    Args:
        state: Current player state
        minutes_played: Minutes played in the match (0-90+)
        position: Position played (affects fatigue)
        context: Scoring context for training intensity modifier

    Returns:
        New PlayerState after match impact
    """
    new_state = state.copy()

    if minutes_played <= 0:
        return new_state

    # Normalize minutes to 90-minute basis
    minutes_ratio = minutes_played / 90.0

    # --- Condition Loss ---
    # Base loss modified by stamina (low stamina = more loss)
    stamina_modifier = 1.0 + (10 - state.stamina) * 0.05  # -25% to +50%
    condition_loss = BASE_CONDITION_LOSS * minutes_ratio * stamina_modifier

    # Apply position fatigue multiplier
    position_mult = get_position_fatigue_multiplier(position)
    condition_loss *= position_mult

    new_state.condition = max(0, state.condition - condition_loss)

    # --- Sharpness Gain ---
    # Players gain sharpness from match time
    sharpness_gain = BASE_SHARPNESS_GAIN * minutes_ratio
    new_state.sharpness = min(100, state.sharpness + sharpness_gain)

    # --- Fatigue Accumulation ---
    # Base fatigue per 90 mins
    base_fatigue_gain = 100 * minutes_ratio

    # Age modifier (older and very young players accumulate faster)
    if state.age >= 32:
        age_modifier = 1.3
    elif state.age >= 30:
        age_modifier = 1.15
    elif state.age < 19:
        age_modifier = 1.1
    else:
        age_modifier = 1.0

    # Natural fitness modifier (high NF = less fatigue)
    nf_modifier = 1.0 - (state.natural_fitness - 10) * 0.03  # +30% to -30%

    fatigue_gain = base_fatigue_gain * age_modifier * nf_modifier * position_mult
    new_state.fatigue += fatigue_gain

    # --- Recent Minutes ---
    new_state.recent_minutes += minutes_played

    # --- Jadedness Check ---
    # Player becomes jaded if fatigue exceeds threshold with low natural fitness
    if new_state.fatigue > FATIGUE_THRESHOLD and state.natural_fitness < 12:
        new_state.is_jaded = True

    return new_state


def simulate_rest_recovery(
    state: PlayerState,
    rest_days: int,
    context: Optional[ScoringContext] = None
) -> PlayerState:
    """
    Simulate player recovery during rest days between matches.

    Research-based formulas:
    - Condition recovery: ~5% per day, modified by Natural Fitness
    - Sharpness decay: ~2% per week without playing
    - Fatigue reduction: Gradual reduction with rest

    Args:
        state: Current player state
        rest_days: Days until next match
        context: Scoring context for training intensity modifier

    Returns:
        New PlayerState after rest period
    """
    new_state = state.copy()

    if rest_days <= 0:
        return new_state

    # --- Condition Recovery ---
    # Natural Fitness affects recovery rate (0.8x to 1.2x)
    nf_modifier = 0.8 + (state.natural_fitness / 20) * 0.4

    # Training intensity modifier from context
    training_modifier = context.recovery_modifier if context else 1.0

    condition_recovery = BASE_CONDITION_RECOVERY * rest_days * nf_modifier * training_modifier
    new_state.condition = min(100, state.condition + condition_recovery)

    # --- Sharpness Decay ---
    # Players lose sharpness when not playing
    sharpness_decay = BASE_SHARPNESS_DECAY * (rest_days / 7)  # ~2% per week
    new_state.sharpness = max(0, state.sharpness - sharpness_decay)

    # --- Fatigue Recovery ---
    # Fatigue reduces with rest (faster with high NF)
    fatigue_recovery_rate = 30 + state.natural_fitness * 2  # 50-70 per day
    fatigue_recovery = fatigue_recovery_rate * rest_days * training_modifier
    new_state.fatigue = max(0, state.fatigue - fatigue_recovery)

    # --- Jadedness Recovery ---
    # Jadedness clears when fatigue drops below threshold
    if new_state.fatigue < FATIGUE_THRESHOLD * 0.5:
        new_state.is_jaded = False

    # --- Recent Minutes Decay ---
    # Recent minutes decay over time
    decay_per_day = 15
    new_state.recent_minutes = max(0, state.recent_minutes - (decay_per_day * rest_days))

    return new_state


def project_condition_at_match(
    current_condition: float,
    days_until_match: int,
    played_today: bool,
    natural_fitness: int = 10,
    training_intensity: str = 'Medium'
) -> float:
    """
    Quick projection of condition at a future match.

    Used for lookahead decisions in selection logic.

    Args:
        current_condition: Current condition (0-100)
        days_until_match: Days until the target match
        played_today: Whether player is playing in current match
        natural_fitness: Player's Natural Fitness attribute
        training_intensity: Club's training intensity

    Returns:
        Projected condition percentage at future match
    """
    # If playing today, estimate post-match condition
    if played_today:
        # Research: Post-match condition varies by NF (66-74%)
        if natural_fitness >= 18:
            post_match = 74
        elif natural_fitness >= 14:
            post_match = 72
        elif natural_fitness >= 10:
            post_match = 70
        else:
            post_match = 66
        starting_condition = post_match
    else:
        starting_condition = current_condition

    # Apply recovery for rest days
    context = get_context_parameters('Medium', training_intensity)
    nf_modifier = 0.8 + (natural_fitness / 20) * 0.4

    recovery = BASE_CONDITION_RECOVERY * days_until_match * nf_modifier * context.recovery_modifier
    projected = min(100, starting_condition + recovery)

    return projected


def simulate_match_sequence(
    initial_states: Dict[str, PlayerState],
    lineups: List[Dict[str, str]],
    match_dates: List[datetime],
    positions_played: List[Dict[str, str]],
    context: Optional[ScoringContext] = None
) -> List[Dict[str, PlayerState]]:
    """
    Simulate state trajectory across a sequence of matches.

    Args:
        initial_states: Dict of player_name -> initial PlayerState
        lineups: List of lineup dicts (position -> player_name) for each match
        match_dates: List of match datetimes
        positions_played: List of dicts mapping player_name -> position for each match
        context: Scoring context for training intensity

    Returns:
        List of state dicts after each match (length = len(lineups))
    """
    current_states = {name: state.copy() for name, state in initial_states.items()}
    state_trajectory = []

    for i, (lineup, match_date, positions) in enumerate(zip(lineups, match_dates, positions_played)):
        # Get players who played
        playing_players = set(lineup.values())

        # Apply match impact to playing players
        for player_name in playing_players:
            if player_name in current_states:
                position = positions.get(player_name, 'M(C)')
                current_states[player_name] = simulate_match_impact(
                    current_states[player_name],
                    minutes_played=90,  # Assume full match
                    position=position,
                    context=context
                )

        # Calculate rest days until next match
        if i < len(match_dates) - 1:
            rest_days = (match_dates[i + 1] - match_date).days
        else:
            rest_days = 3  # Default for last match

        # Apply rest recovery to all players (including those who played)
        for player_name in current_states:
            current_states[player_name] = simulate_rest_recovery(
                current_states[player_name],
                rest_days=rest_days,
                context=context
            )

        # Store snapshot of states after this match
        state_trajectory.append({
            name: state.copy() for name, state in current_states.items()
        })

    return state_trajectory


def get_recovery_timeline(
    player_state: PlayerState,
    target_condition: float = 85.0,
    training_intensity: str = 'Medium'
) -> int:
    """
    Calculate days needed to recover to a target condition level.

    Args:
        player_state: Current player state
        target_condition: Target condition to reach (default 85%)
        training_intensity: Club's training intensity

    Returns:
        Estimated days to reach target condition
    """
    if player_state.condition >= target_condition:
        return 0

    deficit = target_condition - player_state.condition

    # Calculate daily recovery rate
    context = get_context_parameters('Medium', training_intensity)
    nf_modifier = 0.8 + (player_state.natural_fitness / 20) * 0.4
    daily_recovery = BASE_CONDITION_RECOVERY * nf_modifier * context.recovery_modifier

    if daily_recovery <= 0:
        return 99  # Can't recover

    days_needed = int(deficit / daily_recovery) + 1
    return min(days_needed, 14)  # Cap at 2 weeks
