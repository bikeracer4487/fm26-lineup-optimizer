"""
FM26 Operational Research Scoring Model
========================================

Implements the multiplicative Match Utility Score from the research framework:
    U_{i,s} = B_{i,s} * Phi(C_i) * Psi(Sh_i) * Theta(Fam_{i,s}) * Lambda(F_i)

Where:
- B_{i,s}: Base Effective Rating (Harmonic Mean of IP and OOP roles)
- Phi: Condition Multiplier (Physiology) - bounded sigmoid
- Psi: Sharpness Multiplier (Form) - power curve
- Theta: Familiarity Multiplier (Tactical) - bounded sigmoid
- Lambda: Fatigue/Jadedness Multiplier (Long-term health) - player-relative sigmoid

References:
- docs/new-research/FM26 #1 - System spec + decision model (foundation).md
- docs/new-research/FM26 #2 - Lineup Optimizer - Complete Mathematical Specification.md

All multipliers use bounded sigmoid: α + (1 - α) × σ(k × (x - T))
where σ(z) = 1 / (1 + e^(-z)) and α ensures minimum utility is never zero.
"""

from typing import Dict, Tuple, Optional, Any
from dataclasses import dataclass
import math
import sys
import os

# Add parent path to allow importing rating_calculator from root
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from scoring_parameters import (
    ScoringContext, get_context_parameters,
    get_familiarity_params, get_fatigue_params, get_condition_params,
    SHARPNESS_CURVE_PARAMS, get_fixture_density_factor
)


def sigmoid(z: float) -> float:
    """
    Bounded sigmoid function σ(z) = 1 / (1 + e^(-z)).

    Used for smooth transitions in all multiplier functions.
    Returns value in range (0, 1).

    Args:
        z: Input value

    Returns:
        σ(z) in range (0, 1)
    """
    # Clamp input to prevent overflow
    z = max(-20, min(20, z))
    return 1.0 / (1.0 + math.exp(-z))


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


def calculate_condition_multiplier(
    condition_pct: float,
    context: ScoringContext,
    days_to_next_match: Optional[int] = None
) -> float:
    """
    Calculate Condition Multiplier (Phi) using bounded sigmoid.

    Formula: Φ(C, Ω) = α + (1 - α) × σ(k × (C - T_safe))

    Parameters vary by importance (from FM26 #2 spec):
    | Importance | α (floor) | T_safe | k (slope) |
    |------------|-----------|--------|-----------|
    | High       | 0.40      | 75     | 0.12      |
    | Medium     | 0.35      | 82     | 0.10      |
    | Low        | 0.30      | 88     | 0.08      |
    | Sharpness  | 0.35      | 80     | 0.15      |

    Optionally applies fixture density adjustment when days_to_next_match is provided.

    Args:
        condition_pct: Player condition as percentage (0-100)
        context: Scoring context with importance-based parameters
        days_to_next_match: Optional days until next match for density adjustment

    Returns:
        Multiplier (α_floor to 1.0)

    Examples (High importance, α=0.40, T=75, k=0.12):
        C=72: 0.40 + 0.60 × σ(0.12 × -3) = 0.40 + 0.60 × 0.411 = 0.647
        C=82: 0.40 + 0.60 × σ(0.12 × 7) = 0.40 + 0.60 × 0.698 = 0.819
        C=90: 0.40 + 0.60 × σ(0.12 × 15) = 0.40 + 0.60 × 0.858 = 0.915
    """
    # Get importance-specific parameters
    params = get_condition_params(context.importance)
    alpha = params['alpha']
    threshold = params['threshold']
    k = params['slope']

    # Calculate bounded sigmoid multiplier
    z = k * (condition_pct - threshold)
    phi = alpha + (1.0 - alpha) * sigmoid(z)

    # Apply fixture density adjustment if provided
    if days_to_next_match is not None:
        density_factor = get_fixture_density_factor(days_to_next_match)
        phi *= density_factor

    return phi


def calculate_sharpness_multiplier(sharpness_pct: float, context: ScoringContext) -> float:
    """
    Calculate Sharpness Multiplier (Psi) using power curve.

    STANDARD MODE (High/Medium/Low):
        Formula: Ψ = floor + ceiling_range × (Sh/100)^exponent
        Default: Ψ = 0.40 + 0.60 × (Sh/100)^0.8

        This power curve matches FM's internal sharpness-to-performance mapping:
        - 0% sharpness → 0.40 (40% effectiveness)
        - 50% sharpness → 0.40 + 0.60 × 0.574 = 0.74
        - 75% sharpness → 0.40 + 0.60 × 0.811 = 0.89
        - 100% sharpness → 1.00 (full effectiveness)

    SHARPNESS BUILD MODE (Sharpness priority matches):
        Prioritizes players who need match time to build sharpness:
        - 50-90%: 1.20 (bonus for target zone)
        - >90%: 1.00 (already sharp, neutral)
        - <50%: 0.80 (too rusty, some risk)

    Args:
        sharpness_pct: Player match sharpness as percentage (0-100)
        context: Scoring context with sharpness mode

    Returns:
        Multiplier (0.40 to 1.20)

    Examples (standard mode):
        Sh=0%:  0.40 + 0.60 × 0^0.8 = 0.40
        Sh=50%: 0.40 + 0.60 × 0.5^0.8 = 0.40 + 0.60 × 0.574 = 0.74
        Sh=75%: 0.40 + 0.60 × 0.75^0.8 = 0.40 + 0.60 × 0.811 = 0.89
        Sh=100%: 0.40 + 0.60 × 1.0^0.8 = 1.00
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
        # Standard Mode - power curve matching FM's sharpness curve
        floor = SHARPNESS_CURVE_PARAMS['floor']
        ceiling_range = SHARPNESS_CURVE_PARAMS['ceiling_range']
        exponent = SHARPNESS_CURVE_PARAMS['exponent']

        # Normalize sharpness to 0-1 range
        sh_normalized = max(0, min(100, sharpness_pct)) / 100.0

        # Apply power curve: diminishing returns at high sharpness
        if sh_normalized <= 0:
            return floor
        return floor + ceiling_range * (sh_normalized ** exponent)


def calculate_familiarity_multiplier(familiarity: float, context: ScoringContext) -> float:
    """
    Calculate Familiarity Multiplier (Theta) using bounded sigmoid.

    Formula: Θ(Fam, Ω) = α + (1 - α) × σ(k × (Fam - T))

    Parameters vary by importance (from FM26 #2 spec):
    | Importance | α (floor) | T (threshold) | k (steepness) |
    |------------|-----------|---------------|---------------|
    | High       | 0.30      | 12            | 0.55          |
    | Medium     | 0.40      | 10            | 0.45          |
    | Low        | 0.50      | 7             | 0.35          |
    | Sharpness  | 0.25      | 14            | 0.70          |

    The sigmoid provides smooth transitions that avoid jitter at tier boundaries.
    Floor (α) ensures emergency utility is never zero - even an awkward player
    can contribute something in a crisis.

    Args:
        familiarity: Position familiarity rating (1-20)
        context: Scoring context with importance level

    Returns:
        Multiplier (α_floor to 1.0)

    Examples (High importance, α=0.30, T=12, k=0.55):
        Fam=6:  0.30 + 0.70 × σ(0.55 × -6) = 0.30 + 0.70 × 0.036 = 0.325
        Fam=10: 0.30 + 0.70 × σ(0.55 × -2) = 0.30 + 0.70 × 0.249 = 0.474
        Fam=14: 0.30 + 0.70 × σ(0.55 × 2) = 0.30 + 0.70 × 0.751 = 0.826
        Fam=18: 0.30 + 0.70 × σ(0.55 × 6) = 0.30 + 0.70 × 0.964 = 0.975
    """
    # Get importance-specific parameters
    params = get_familiarity_params(context.importance)
    alpha = params['alpha']
    threshold = params['threshold']
    k = params['steepness']

    # Calculate bounded sigmoid multiplier
    z = k * (familiarity - threshold)
    theta = alpha + (1.0 - alpha) * sigmoid(z)

    return theta


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
    Calculate Fatigue/Jadedness Multiplier (Lambda) using player-relative sigmoid.

    Formula: Λ(F, T, Ω) = α + (1 - α) × (1 - σ(k × (F/T - r)))

    Where:
    - F = current fatigue value
    - T = player-specific fatigue threshold
    - r = ratio at which penalties begin
    - α = floor (collapse value)
    - k = steepness of transition

    Parameters vary by importance (from FM26 #2 spec):
    | Importance | α (collapse) | r (ratio) | k (steepness) |
    |------------|--------------|-----------|---------------|
    | High       | 0.50         | 0.85      | 5.0           |
    | Medium     | 0.25         | 0.75      | 6.0           |
    | Low        | 0.15         | 0.65      | 8.0           |
    | Sharpness  | 0.20         | 0.70      | 7.0           |

    Key insight: High importance INCREASES α (floor), allowing fatigued players
    to still contribute - pushing through for crucial fixtures. Low importance
    DECREASES α and r, aggressively penalizing fatigue to preserve players.

    Player-specific threshold calculation:
    - Base: 400
    - Age: 32+ → 300, 30-32 → 350, <19 → 350
    - Natural Fitness: <10 → -50, >=15 → +50
    - Stamina: <10 → -50, >=15 → +30
    - Injury Proneness: >=15 → -100, <=8 → +50

    Args:
        fatigue_level: Current fatigue value (0-1000+)
        is_jaded: Whether player has jadedness flag
        context: Scoring context with importance level
        age: Player age
        natural_fitness: Player natural fitness attribute (1-20)
        stamina: Player stamina attribute (1-20)
        injury_proneness: Player injury proneness attribute (1-20)

    Returns:
        Multiplier (α_floor to 1.0)

    Examples (T=80, Medium importance, α=0.25, r=0.75, k=6.0):
        F=40 (F/T=0.50): 0.25 + 0.75 × (1 - σ(6 × -0.25)) = 0.25 + 0.75 × 0.82 = 0.87
        F=70 (F/T=0.875): 0.25 + 0.75 × (1 - σ(6 × 0.125)) = 0.25 + 0.75 × 0.32 = 0.49
        F=85 (F/T=1.0625): 0.25 + 0.75 × (1 - σ(6 × 0.3125)) = 0.25 + 0.75 × 0.13 = 0.35
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

    # Get importance-specific sigmoid parameters
    params = get_fatigue_params(context.importance)
    alpha = params['alpha']
    ratio = params['ratio']
    k = params['steepness']

    # Calculate fatigue ratio relative to player threshold
    fatigue_ratio = fatigue_level / threshold if threshold > 0 else 1.0

    # Calculate bounded sigmoid multiplier
    # Note: Using (1 - sigmoid) because higher fatigue = lower multiplier
    z = k * (fatigue_ratio - ratio)
    lambda_mult = alpha + (1.0 - alpha) * (1.0 - sigmoid(z))

    return lambda_mult


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
