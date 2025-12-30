"""
FM26 State Simulation Engine
============================

Simulates player state changes across multi-match planning horizons.
Used by the Receding Horizon Control (RHC) optimizer to project:
- Condition recovery and decay
- Sharpness gain from matches and decay from rest
- Fatigue accumulation and jadedness risk

References:
- docs/new-research/03-RESULTS-state-propagation.md (Step 3 Research)
- docs/new-research/12-IMPLEMENTATION-PLAN.md (consolidated specification)

Key Research Findings (Step 3):

1. R_pos Coefficients (Positional Drag):
   - GK: 0.20 (minimal drain, can play every match)
   - CB: 0.95 (low drain, can play consecutive matches)
   - WB: 1.65 (highest drain, needs 100% rotation)

2. 270-Minute Rule:
   - Window: 14 days (not 10!)
   - Threshold: 270 minutes
   - Penalty: 2.5x jadedness accumulation when exceeded

3. Seven-Day Cliff (Sharpness Decay):
   - Days 0-3: 0% decay (grace period)
   - Days 4-6: ~1.5%/day (gentle decline)
   - Days 7+:  ~6.5%/day (THE CLIFF!)

State Propagation Equations:
- Condition: C_{k+1} = min(100, C_k - ΔC_match + ΔC_recovery)
- Sharpness: Sh_{k+1} = Sh_k + ΔSh_gain - ΔSh_decay
- Fatigue: F_{k+1} = max(0, F_k + ΔF_match - ΔF_recovery)
"""

from dataclasses import dataclass
from typing import Dict, Any, Optional, List, Literal
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
    get_position_drain_rate,  # Legacy - kept for backward compatibility
    BASE_CONDITION_LOSS,
    BASE_CONDITION_RECOVERY,
    BASE_SHARPNESS_GAIN,
    BASE_SHARPNESS_DECAY,
    FATIGUE_THRESHOLD,
    SHARPNESS_GAIN_RATE,
    SHARPNESS_DECAY_RATE,
    MATCH_TYPE_SHARPNESS_FACTORS,
    FATIGUE_GAIN_PER_90,
    FATIGUE_RECOVERY_PER_DAY,
    INTENSITY_FACTORS,
    # New GSS-based parameters from Step 3 research
    get_r_pos,
    R_POS,
    MINUTES_WINDOW_DAYS,
    MINUTES_THRESHOLD,
    JADEDNESS_PENALTY_MULTIPLIER,
    get_sharpness_decay_rate,
    SHARPNESS_DECAY_RATES,
    get_jadedness_state,
    JADEDNESS_THRESHOLDS,
)

# Type for match types
MatchType = Literal['competitive', 'friendly', 'reserve']


@dataclass
class PlayerState:
    """
    Represents a player's current physical and mental state.
    All values are normalized to 0-100 percentage scale.

    Updated for Step 3 research:
    - Added days_since_match for Seven-Day Cliff sharpness decay
    - Added minutes_in_window for 270-minute rule (14-day window)
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

    # New fields for Step 3 research
    days_since_match: int = 0         # Days since last competitive match (for sharpness cliff)
    minutes_in_window: int = 0        # Minutes played in 14-day window (for 270-min rule)

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
            injury_proneness=self.injury_proneness,
            days_since_match=self.days_since_match,
            minutes_in_window=self.minutes_in_window
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
        injury_proneness=player_data.get('Injury Proneness', 10),
        # Step 3 research fields
        days_since_match=player_data.get('Days_Since_Match', 0),
        minutes_in_window=player_data.get('Minutes_In_Window', 0)
    )


def simulate_match_impact(
    state: PlayerState,
    minutes_played: int,
    position: str = 'M(C)',
    context: Optional[ScoringContext] = None,
    match_type: MatchType = 'competitive',
    intensity: str = 'normal'
) -> PlayerState:
    """
    Simulate the impact of playing a match on player state.

    Updated for Step 3 research with R_pos coefficients and 270-minute rule.

    Formulas (Step 3 Research):

    Condition Update:
        ΔC_match = (minutes / 90) × R_pos × (1 - stamina/200)
        where R_pos is position-specific drag coefficient (GK: 0.20 to WB: 1.65)

    Sharpness Update (on 0-10000 internal scale, displayed as 0-100%):
        ΔSh_gain = (minutes / 90) × gain_rate × match_type_factor × (1 + NF/400)
        where gain_rate = 1500 per full competitive match

    Fatigue Update with 270-Minute Rule:
        ΔF_match = (minutes / 90) × fatigue_gain × intensity_factor × jadedness_mult
        where jadedness_mult = 2.5 if minutes_in_window > 270

    Args:
        state: Current player state
        minutes_played: Minutes played in the match (0-90+)
        position: Position played (affects drain rate and fatigue)
        context: Scoring context for training intensity modifier
        match_type: 'competitive', 'friendly', or 'reserve'
        intensity: 'normal', 'high_press', or 'rotation'

    Returns:
        New PlayerState after match impact
    """
    new_state = state.copy()

    if minutes_played <= 0:
        return new_state

    # Normalize minutes to 90-minute basis
    minutes_ratio = minutes_played / 90.0

    # --- Condition Loss (Step 3 Research: R_pos coefficients) ---
    # ΔC_match = (minutes / 90) × R_pos × (1 - stamina/200)
    # R_pos ranges from 0.20 (GK) to 1.65 (WB) - higher = faster drain
    r_pos = get_r_pos(position)
    stamina_modifier = 1.0 - (state.stamina / 200.0)  # Range: 0.5 to 0.95

    # Scale R_pos to condition percentage loss
    # R_pos of 1.0 corresponds to ~25% condition loss per 90 mins for avg stamina
    base_condition_drain = 25.0  # Base drain percentage
    condition_loss = minutes_ratio * r_pos * base_condition_drain * stamina_modifier

    new_state.condition = max(0, state.condition - condition_loss)

    # --- Sharpness Gain (FM26 #2 formula) ---
    # ΔSh_gain = (minutes / 90) × gain_rate × match_type_factor × (1 + NF/400)
    match_type_factor = MATCH_TYPE_SHARPNESS_FACTORS.get(match_type, 1.0)
    nf_sharpness_modifier = 1.0 + (state.natural_fitness / 400.0)  # Range: 1.025 to 1.05

    # Convert 0-100 scale to 0-10000 for calculation, then back
    current_sharpness_internal = state.sharpness * 100  # 0-10000
    sharpness_gain_internal = minutes_ratio * SHARPNESS_GAIN_RATE * match_type_factor * nf_sharpness_modifier
    new_sharpness_internal = min(10000, current_sharpness_internal + sharpness_gain_internal)
    new_state.sharpness = new_sharpness_internal / 100  # Back to 0-100

    # --- Reset days since match (player just played) ---
    new_state.days_since_match = 0

    # --- Update minutes in 14-day window ---
    new_state.minutes_in_window = state.minutes_in_window + minutes_played

    # --- Fatigue Accumulation (Step 3 Research: 270-minute rule) ---
    # ΔF_match = (minutes / 90) × fatigue_gain × intensity_factor × jadedness_mult
    intensity_factor = INTENSITY_FACTORS.get(intensity, 1.0)

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

    # Position multiplier for fatigue (using R_pos as proxy)
    position_mult = r_pos

    # 270-minute rule: 2.5x jadedness accumulation if over threshold
    if new_state.minutes_in_window > MINUTES_THRESHOLD:
        jadedness_penalty = JADEDNESS_PENALTY_MULTIPLIER
    else:
        jadedness_penalty = 1.0

    fatigue_gain = (
        minutes_ratio * FATIGUE_GAIN_PER_90 * intensity_factor *
        age_modifier * nf_modifier * position_mult * jadedness_penalty
    )
    new_state.fatigue += fatigue_gain

    # --- Recent Minutes ---
    new_state.recent_minutes += minutes_played

    # --- Jadedness Check (using new threshold system) ---
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

    Updated for Step 3 research with Seven-Day Cliff sharpness decay.

    Formulas (Step 3 Research):

    Condition Recovery:
        ΔC_recovery = days × recovery_rate × (natural_fitness/100)
        where recovery_rate = 12-18 per day (higher for higher NF)

    Sharpness Decay - Seven-Day Cliff:
        Days 0-3: 0% decay per day (grace period)
        Days 4-6: ~1.5% decay per day (gentle decline)
        Days 7+:  ~6.5% decay per day (THE CLIFF!)

    Fatigue Recovery:
        ΔF_recovery = days × recovery_rate × (1 + natural_fitness/100)
        where recovery_rate = 10 per rest day (base)

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

    # --- Condition Recovery (FM26 #2 formula) ---
    # ΔC_recovery = days × recovery_rate × (natural_fitness/100)
    # recovery_rate scales with NF: base 12 + (NF-10) * 0.6 → range 9-18
    base_recovery_rate = 12 + (state.natural_fitness - 10) * 0.6
    nf_recovery_modifier = state.natural_fitness / 100.0  # 0.1 to 0.2

    # Training intensity modifier from context
    training_modifier = context.recovery_modifier if context else 1.0

    condition_recovery = rest_days * base_recovery_rate * (0.5 + nf_recovery_modifier) * training_modifier
    new_state.condition = min(100, state.condition + condition_recovery)

    # --- Sharpness Decay (Step 3 Research: Seven-Day Cliff) ---
    # Calculate decay day-by-day to properly handle cliff transitions
    # Days 0-3: 0%, Days 4-6: 1.5%/day, Days 7+: 6.5%/day
    nf_decay_modifier = 1.0 - (state.natural_fitness / 200.0)  # Range: 0.5 to 0.9

    total_sharpness_decay = 0.0
    for day_offset in range(rest_days):
        current_day = state.days_since_match + day_offset
        daily_rate = get_sharpness_decay_rate(current_day)
        # Daily rate is a fraction (0.065 = 6.5%), convert to percentage points
        total_sharpness_decay += daily_rate * 100 * nf_decay_modifier

    new_sharpness = max(0, state.sharpness - total_sharpness_decay)
    new_state.sharpness = new_sharpness

    # Update days since match
    new_state.days_since_match = state.days_since_match + rest_days

    # --- Minutes in Window Decay ---
    # Minutes older than 14 days "fall off" the window
    # Approximate: reduce by (minutes_per_day × days) assuming uniform distribution
    minutes_decay_per_day = state.minutes_in_window / MINUTES_WINDOW_DAYS
    minutes_decay = min(state.minutes_in_window, int(minutes_decay_per_day * rest_days))
    new_state.minutes_in_window = max(0, state.minutes_in_window - minutes_decay)

    # --- Fatigue Recovery (FM26 #2 formula) ---
    # ΔF_recovery = days × recovery_rate × (1 + natural_fitness/100)
    nf_fatigue_recovery = 1.0 + (state.natural_fitness / 100.0)  # Range: 1.1 to 1.2
    fatigue_recovery = rest_days * FATIGUE_RECOVERY_PER_DAY * nf_fatigue_recovery * training_modifier
    new_state.fatigue = max(0, state.fatigue - fatigue_recovery)

    # --- Jadedness Recovery (using threshold system) ---
    # Jadedness state based on fatigue thresholds
    jadedness_state = get_jadedness_state(int(new_state.fatigue))
    if jadedness_state == 'fresh':
        new_state.is_jaded = False
    elif jadedness_state == 'jaded':
        new_state.is_jaded = True

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
