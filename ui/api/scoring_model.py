"""
FM26 Operational Research Scoring Model
========================================

Implements the multiplicative Match Utility Score from the research framework:
    U_{i,s} = B_{i,s} * Phi(C_i) * Psi(Sh_i) * Theta(Fam_{i,s}) * Lambda(F_i)

Where:
- B_{i,s}: Base Effective Rating (Harmonic Mean of IP and OOP roles)
- Phi: Condition Multiplier (Physiology)
- Psi: Sharpness Multiplier (Form)
- Theta: Familiarity Multiplier (Tactical)
- Lambda: Fatigue/Jadedness Multiplier (Long-term health)

Reference: docs/new-research/FM26 #1 - System spec + decision model (foundation).md
"""

from typing import Dict, Tuple, Optional, Any
from dataclasses import dataclass
import sys
import os

# Add parent path to allow importing rating_calculator from root
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from scoring_parameters import ScoringContext, get_context_parameters


@dataclass
class MultiplierBreakdown:
    """Stores individual multiplier values for explainability."""
    base_rating: float
    condition_mult: float
    sharpness_mult: float
    familiarity_mult: float
    fatigue_mult: float
    final_utility: float

    def to_dict(self) -> Dict[str, float]:
        return {
            'base': self.base_rating,
            'condition': self.condition_mult,
            'sharpness': self.sharpness_mult,
            'familiarity': self.familiarity_mult,
            'fatigue': self.fatigue_mult,
            'final': self.final_utility
        }


def calculate_harmonic_mean(r_ip: float, r_oop: float) -> float:
    """
    Calculate Harmonic Mean of IP and OOP ratings.

    B_{i,s} = 2 * R_IP * R_OOP / (R_IP + R_OOP)

    This penalizes imbalance:
    - Player with {180, 20} scores 36 (heavily penalized for defensive liability)
    - Player with {100, 100} scores 100 (balanced player)
    - Player with {150, 150} scores 150 (balanced AND skilled)

    The harmonic mean ensures that a player who excels at attacking (IP) but is
    terrible at defending (OOP) won't be selected over a more balanced player.

    Args:
        r_ip: In-Possession role rating (0-200 scale)
        r_oop: Out-of-Possession role rating (0-200 scale)

    Returns:
        Harmonic mean of the two ratings (0-200 scale)
    """
    if r_ip <= 0 or r_oop <= 0:
        return 0.0

    if r_ip + r_oop == 0:
        return 0.0

    return (2.0 * r_ip * r_oop) / (r_ip + r_oop)


def calculate_condition_multiplier(condition_pct: float, context: ScoringContext) -> float:
    """
    Calculate Condition Multiplier (Phi).

    Research-based piecewise function:
    - Phi(C) = 1.0                           if C >= 95%
    - Phi(C) = 1.0 - alpha * (95 - C)        if T_safe <= C < 95%
    - Phi(C) = P_critical (0.05)             if C < T_safe

    The Safety Threshold (T_safe) varies by match importance:
    - High: 80% (risk injury for quality in finals)
    - Medium: 91% (standard safety)
    - Low: 94% (no risk in friendlies)
    - Sharpness: 85% (moderate risk for development)

    Args:
        condition_pct: Player condition as percentage (0-100)
        context: Scoring context with importance-based parameters

    Returns:
        Multiplier (0.05 to 1.0)
    """
    t_safe = context.safety_threshold
    alpha = context.decay_slope
    p_critical = 0.05  # Severe penalty - effectively benches player

    if condition_pct >= 95:
        return 1.0
    elif condition_pct >= t_safe:
        # Linear decay from 1.0 at 95% down to (1.0 - alpha * (95 - t_safe)) at t_safe
        return 1.0 - alpha * (95 - condition_pct)
    else:
        # Below safety threshold - critical penalty
        return p_critical


def calculate_sharpness_multiplier(sharpness_pct: float, context: ScoringContext) -> float:
    """
    Calculate Sharpness Multiplier (Psi).

    Two modes based on match importance:

    STANDARD MODE (High/Medium/Low):
        Psi(Sh) = 0.7 + 0.003 * Sh  (Range: 0.7 at 0% -> 1.0 at 100%)

    SHARPNESS BUILD MODE (Sharpness priority matches):
        Psi(Sh) = 1.2  if 50 <= Sh <= 90  (target zone for building)
        Psi(Sh) = 1.0  if Sh > 90         (already sharp)
        Psi(Sh) = 0.8  if Sh < 50         (too rusty, risk)

    Args:
        sharpness_pct: Player match sharpness as percentage (0-100)
        context: Scoring context with sharpness mode

    Returns:
        Multiplier (0.7 to 1.2)
    """
    if context.sharpness_mode == 'build':
        # Sharpness Build Mode - prioritize players in recovery zone
        if 50 <= sharpness_pct <= 90:
            return 1.2  # Bonus for players needing minutes
        elif sharpness_pct > 90:
            return 1.0  # Already sharp, neutral
        else:
            return 0.8  # Too rusty (<50%), still some risk
    else:
        # Standard Mode - low sharpness is a penalty
        # Range: 0.7 at 0% -> 1.0 at 100%
        return 0.7 + 0.003 * sharpness_pct


def calculate_familiarity_multiplier(familiarity: float, context: ScoringContext) -> float:
    """
    Calculate Familiarity Multiplier (Theta).

    FM26 Familiarity Tiers (1-20 scale):
    - Natural (18-20): 1.00 (100%)
    - Accomplished (15-17): 0.95 (95%)
    - Competent (12-14): 0.80 (80%)
    - Unconvincing (9-11): 0.60 (60%)
    - Awkward (5-8): 0.35 (35%)
    - Ineffectual (1-4): 0.10 (10%)

    The minimum familiarity threshold varies by importance:
    - High: 15/20 (Accomplished minimum)
    - Medium: 12/20 (Competent minimum)
    - Low: 5/20 (Awkward acceptable for retraining)
    - Sharpness: 10/20 (Unconvincing acceptable)

    If below threshold, applies a 0.70 penalty multiplier on top of tier penalty.

    Args:
        familiarity: Position familiarity rating (1-20)
        context: Scoring context with familiarity minimum

    Returns:
        Multiplier (0.07 to 1.0)
    """
    # Get tier-based multiplier
    if familiarity >= 18:
        tier_mult = 1.00  # Natural
    elif familiarity >= 15:
        tier_mult = 0.95  # Accomplished
    elif familiarity >= 12:
        tier_mult = 0.80  # Competent
    elif familiarity >= 9:
        tier_mult = 0.60  # Unconvincing
    elif familiarity >= 5:
        tier_mult = 0.35  # Awkward
    else:
        tier_mult = 0.10  # Ineffectual

    # Apply threshold penalty if below minimum
    if familiarity < context.familiarity_min:
        tier_mult *= 0.70  # Additional 30% penalty for being below threshold

    return tier_mult


def calculate_fatigue_multiplier(
    fatigue_level: float,
    is_jaded: bool,
    context: ScoringContext,
    age: int = 25,
    natural_fitness: int = 10,
    stamina: int = 10,
    injury_proneness: int = 10
) -> float:
    """
    Calculate Fatigue/Jadedness Multiplier (Lambda).

    Uses personalized fatigue thresholds based on player attributes:
    - Base threshold: 400
    - Age adjustments: 32+ = 300, 30-32 = 350, <19 = 350
    - Natural Fitness: <10 = -50, >=15 = +50
    - Stamina: <10 = -50, >=15 = +30
    - Injury Proneness: >=15 = -100 (fragile), <=8 = +50 (robust)

    Jadedness penalty varies by importance (from research table):
    - High: 0.9 (play jaded players if needed)
    - Medium: 0.6 (significant penalty)
    - Low: 0.1 (essentially bench jaded players)
    - Sharpness: 0.5 (moderate penalty)

    Args:
        fatigue_level: Current fatigue value (0-1000+)
        is_jaded: Whether player has jadedness flag
        context: Scoring context with jadedness penalty
        age: Player age
        natural_fitness: Player natural fitness attribute (1-20)
        stamina: Player stamina attribute (1-20)
        injury_proneness: Player injury proneness attribute (1-20)

    Returns:
        Multiplier (0.1 to 1.0)
    """
    # Handle jadedness first - it's a separate concern from fatigue
    if is_jaded:
        return context.jadedness_penalty

    # Calculate personalized fatigue threshold
    threshold = 400  # Base threshold

    # Age adjustments
    if age >= 32:
        threshold = 300  # Highly sensitive
    elif age >= 30:
        threshold = 350  # More sensitive
    elif age < 19:
        threshold = 350  # Youth burnout risk

    # Natural Fitness modifiers
    if natural_fitness < 10:
        threshold -= 50
    elif natural_fitness >= 15:
        threshold += 50

    # Stamina modifiers
    if stamina < 10:
        threshold -= 50
    elif stamina >= 15:
        threshold += 30

    # Injury Proneness modifiers (CRITICAL)
    if injury_proneness >= 15:
        threshold -= 100  # Highly fragile
    elif injury_proneness <= 8:
        threshold += 50  # Robust

    # Clamp threshold to reasonable range
    threshold = max(200, min(550, threshold))

    # Calculate fatigue multiplier based on personalized threshold
    if fatigue_level >= threshold + 100:
        return 0.65  # Severe - well above threshold
    elif fatigue_level >= threshold:
        return 0.85  # Moderate - at threshold
    elif fatigue_level >= threshold - 50:
        return 0.95  # Minor - approaching threshold
    else:
        return 1.0  # Fresh


def calculate_match_utility(
    player_data: Dict[str, Any],
    ip_rating: float,
    oop_rating: float,
    ip_familiarity: float,
    oop_familiarity: float,
    context: ScoringContext
) -> Tuple[float, MultiplierBreakdown]:
    """
    Calculate the complete Match Utility Score using multiplicative model.

    U_{i,s} = B_{i,s} * Phi(C_i) * Psi(Sh_i) * Theta(Fam_{i,s}) * Lambda(F_i)

    This is the core scoring function that replaces the old additive 9-layer system.
    The multiplicative approach ensures that a failure in any critical dimension
    (e.g., 50% condition) renders the player unusable, regardless of raw ability.

    Args:
        player_data: Dict with player attributes (Condition, Match Sharpness, Fatigue, Age, etc.)
        ip_rating: Pre-calculated In-Possession role rating (0-200)
        oop_rating: Pre-calculated Out-of-Possession role rating (0-200)
        ip_familiarity: IP position familiarity (1-20)
        oop_familiarity: OOP position familiarity (1-20)
        context: Scoring context with importance-based parameters

    Returns:
        Tuple of (final_utility, MultiplierBreakdown for explainability)
    """
    # 1. Base Rating: Harmonic Mean of IP/OOP
    base_rating = calculate_harmonic_mean(ip_rating, oop_rating)

    # 2. Extract player state values (handle various input formats)
    condition = player_data.get('Condition', 100)
    # Normalize to percentage (handle 0-10000 or 0-100 scale)
    condition_pct = condition / 100 if condition > 100 else condition

    sharpness = player_data.get('Match Sharpness', 10000)
    # Normalize to percentage
    sharpness_pct = sharpness / 100 if sharpness > 100 else sharpness

    fatigue = player_data.get('Fatigue', 0)
    is_jaded = player_data.get('Is Jaded', False) or player_data.get('Jadedness', False)

    age = player_data.get('Age', 25)
    natural_fitness = player_data.get('Natural Fitness', 10)
    stamina = player_data.get('Stamina', 10)
    injury_proneness = player_data.get('Injury Proneness', 10)

    # 3. Calculate individual multipliers
    condition_mult = calculate_condition_multiplier(condition_pct, context)
    sharpness_mult = calculate_sharpness_multiplier(sharpness_pct, context)

    # Average familiarity for combined multiplier (both positions matter)
    avg_familiarity = (ip_familiarity + oop_familiarity) / 2
    familiarity_mult = calculate_familiarity_multiplier(avg_familiarity, context)

    fatigue_mult = calculate_fatigue_multiplier(
        fatigue, is_jaded, context,
        age=age, natural_fitness=natural_fitness,
        stamina=stamina, injury_proneness=injury_proneness
    )

    # 4. Calculate final utility (multiplicative)
    final_utility = base_rating * condition_mult * sharpness_mult * familiarity_mult * fatigue_mult

    # 5. Create breakdown for explainability
    breakdown = MultiplierBreakdown(
        base_rating=base_rating,
        condition_mult=condition_mult,
        sharpness_mult=sharpness_mult,
        familiarity_mult=familiarity_mult,
        fatigue_mult=fatigue_mult,
        final_utility=final_utility
    )

    return final_utility, breakdown


def calculate_effective_rating_new(
    player_data: Dict[str, Any],
    ip_pos: str,
    ip_role: str,
    oop_pos: str,
    oop_role: str,
    context: ScoringContext
) -> Tuple[float, MultiplierBreakdown]:
    """
    Calculate effective rating using new scoring model with full role calculation.

    This function:
    1. Calculates IP and OOP role ratings using rating_calculator
    2. Gets familiarity values from player data
    3. Applies the multiplicative utility model

    Args:
        player_data: Dict with all player attributes
        ip_pos: In-Possession position key (e.g., 'D(L)')
        ip_role: In-Possession role name (e.g., 'Inverted Wingback')
        oop_pos: Out-of-Possession position key
        oop_role: Out-of-Possession role name
        context: Scoring context with importance parameters

    Returns:
        Tuple of (effective_rating, MultiplierBreakdown)
    """
    import rating_calculator

    # Calculate individual phase ratings (0-100 scale, then scaled)
    ip_rating = rating_calculator.calculate_role_rating(
        player_data, ip_pos, ip_role, 'IP'
    ) * 2  # Scale to 0-200

    oop_rating = rating_calculator.calculate_role_rating(
        player_data, oop_pos, oop_role, 'OOP'
    ) * 2  # Scale to 0-200

    # Get familiarity values
    ip_fam_col = rating_calculator.get_familiarity_column(ip_pos)
    oop_fam_col = rating_calculator.get_familiarity_column(oop_pos)

    ip_familiarity = player_data.get(ip_fam_col, 1)
    oop_familiarity = player_data.get(oop_fam_col, 1)

    # Ensure familiarity values are valid
    try:
        ip_familiarity = float(ip_familiarity) if ip_familiarity else 1
        oop_familiarity = float(oop_familiarity) if oop_familiarity else 1
    except (ValueError, TypeError):
        ip_familiarity = 1
        oop_familiarity = 1

    return calculate_match_utility(
        player_data,
        ip_rating, oop_rating,
        ip_familiarity, oop_familiarity,
        context
    )
