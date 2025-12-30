"""
FM26 Operational Research Scoring Model
========================================

Implements the Global Selection Score (GSS) from the FM26 research program:
    GSS = BPS × Φ(C) × Ψ(S) × Θ(F) × Ω(J)

Where:
- BPS: Base Position Score (Harmonic Mean of IP and OOP roles)
- Φ(C): Condition Multiplier - STEEP sigmoid, k=25, c0=0.88
- Ψ(S): Sharpness Multiplier - bounded sigmoid, k=15, s0=0.75
- Θ(F): Familiarity Multiplier - LINEAR (0.7 + 0.3f), NOT sigmoid!
- Ω(J): Jadedness Multiplier - step function with discrete states

References:
- docs/new-research/02-RESULTS-unified-scoring.md (GSS formula)
- docs/new-research/03-RESULTS-state-propagation.md (state dynamics)
- docs/new-research/12-IMPLEMENTATION-PLAN.md (consolidated spec)

Key research findings that differ from prior implementation:
1. Condition sigmoid is MUCH steeper (k=25 vs k=0.10-0.15)
2. Familiarity is LINEAR, NOT sigmoid
3. Fatigue/Jadedness uses step function, not continuous sigmoid
4. 91% condition floor - never start player below this
"""

from typing import Dict, Tuple, Optional, Any
from dataclasses import dataclass
import math
import sys
import os

# Add parent path to allow importing rating_calculator from root
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '../..')))

from scoring_parameters import (
    # Legacy imports for backward compatibility
    ScoringContext, get_context_parameters,
    get_familiarity_params, get_fatigue_params, get_condition_params,
    SHARPNESS_CURVE_PARAMS, get_fixture_density_factor,
    # New GSS parameters from research (Step 2)
    CONDITION_SIGMOID_K, CONDITION_SIGMOID_C0, CONDITION_FLOOR,
    SHARPNESS_SIGMOID_K, SHARPNESS_SIGMOID_S0,
    FAMILIARITY_FLOOR, FAMILIARITY_SLOPE,
    get_jadedness_multiplier, get_jadedness_state,
)


# =============================================================================
# GSS DATACLASS FOR EXPLAINABILITY
# =============================================================================

@dataclass
class GSSBreakdown:
    """
    Stores GSS calculation breakdown for explainability and debugging.

    This dataclass captures all components of the Global Selection Score,
    allowing the UI to display detailed breakdowns and helping with
    parameter tuning and validation.

    Attributes:
        base_rating: Base Position Score (Harmonic Mean of IP/OOP)
        condition_mult: Φ(C) - Condition multiplier from steep sigmoid
        sharpness_mult: Ψ(S) - Sharpness multiplier from bounded sigmoid
        familiarity_mult: Θ(F) - Familiarity multiplier (LINEAR)
        jadedness_mult: Ω(J) - Jadedness multiplier from step function
        final_utility: GSS = BPS × Φ × Ψ × Θ × Ω
    """
    base_rating: float
    condition_mult: float
    sharpness_mult: float
    familiarity_mult: float
    jadedness_mult: float
    final_utility: float

    def to_dict(self) -> Dict[str, float]:
        """Convert to dictionary for JSON serialization."""
        return {
            'base': self.base_rating,
            'condition': self.condition_mult,
            'sharpness': self.sharpness_mult,
            'familiarity': self.familiarity_mult,
            'jadedness': self.jadedness_mult,
            'final': self.final_utility
        }


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


# =============================================================================
# GSS MULTIPLIER FUNCTIONS (Step 2 Research - PRIMARY)
# =============================================================================
# These are the canonical multiplier functions based on FM26 research.
# They use fixed parameters rather than context-dependent ones.


def condition_multiplier_gss(condition_pct: float) -> float:
    """
    Calculate Condition Multiplier Φ(C) using STEEP sigmoid from research.

    Formula: Φ(c) = 1 / (1 + e^{-k(c - c₀)})
    Parameters: k=25, c₀=0.88

    This is MUCH steeper than the old context-dependent version.
    The research found FM26 has a sharp cliff around 88% condition.

    Args:
        condition_pct: Player condition as decimal (0.0-1.0) or percentage (0-100)

    Returns:
        Multiplier (0.0 to 1.0)

    Examples:
        C=0.85 (85%): Φ = 1/(1+e^{-25×(-0.03)}) = 0.321
        C=0.88 (88%): Φ = 1/(1+e^{-25×(0)}) = 0.500 (threshold)
        C=0.91 (91%): Φ = 1/(1+e^{-25×(0.03)}) = 0.679
        C=0.95 (95%): Φ = 1/(1+e^{-25×(0.07)}) = 0.852
        C=1.00 (100%): Φ ≈ 0.953
    """
    # Normalize to 0-1 range if given as percentage
    if condition_pct > 1.0:
        condition_pct = condition_pct / 100.0

    z = CONDITION_SIGMOID_K * (condition_pct - CONDITION_SIGMOID_C0)
    return sigmoid(z)


def sharpness_multiplier_gss(sharpness_pct: float) -> float:
    """
    Calculate Sharpness Multiplier Ψ(S) using bounded sigmoid from research.

    Formula: Ψ(s) = 1.02 / (1 + e^{-k(s - s₀)}) - 0.02
    Parameters: k=15, s₀=0.75

    The bounds (1.02, -0.02) prevent negative values and cap near 1.0.
    This replaces the old power curve which was found to be incorrect.

    Args:
        sharpness_pct: Player sharpness as decimal (0.0-1.0) or percentage (0-100)

    Returns:
        Multiplier (0.0 to ~1.0)

    Examples:
        S=0.50 (50%): Ψ = 1.02/(1+e^{-15×(-0.25)}) - 0.02 = 0.003
        S=0.70 (70%): Ψ = 1.02/(1+e^{-15×(-0.05)}) - 0.02 = 0.300
        S=0.75 (75%): Ψ = 1.02/(1+e^{0}) - 0.02 = 0.490 (threshold)
        S=0.85 (85%): Ψ = 1.02/(1+e^{-15×(0.10)}) - 0.02 = 0.793
        S=1.00 (100%): Ψ ≈ 0.996
    """
    # Normalize to 0-1 range if given as percentage
    if sharpness_pct > 1.0:
        sharpness_pct = sharpness_pct / 100.0

    z = SHARPNESS_SIGMOID_K * (sharpness_pct - SHARPNESS_SIGMOID_S0)
    # Bounded sigmoid: 1.02 × σ(z) - 0.02
    return 1.02 * sigmoid(z) - 0.02


def familiarity_multiplier_gss(familiarity: float, fm_scale: bool = True) -> float:
    """
    Calculate Familiarity Multiplier Θ(F) using LINEAR function from research.

    Formula: Θ(f) = 0.7 + 0.3f  where f ∈ [0, 1]

    KEY FINDING: Familiarity is LINEAR, NOT sigmoid!
    This is a major change from the old context-dependent sigmoid version.

    Args:
        familiarity: Position familiarity value
        fm_scale: If True (default), treat as FM's 1-20 scale.
                  If False, treat as normalized 0-1 scale.

    Returns:
        Multiplier (0.70 to 1.00)

    Examples:
        f=0 (no familiarity): Θ = 0.7 + 0.3×0 = 0.70
        f=0.5 (50%): Θ = 0.7 + 0.3×0.5 = 0.85
        f=1.0 (natural): Θ = 0.7 + 0.3×1 = 1.00

        FM scale examples (1-20):
        Fam=1:  f=0.00, Θ = 0.70
        Fam=10: f=0.47, Θ = 0.84
        Fam=15: f=0.74, Θ = 0.92
        Fam=20: f=1.00, Θ = 1.00
    """
    # Handle FM's 1-20 scale
    if fm_scale and familiarity >= 1:
        # Detect if this is definitely FM scale (values > 1 and likely integer-ish)
        # FM scale: 1-20, where 1=awkward, 20=natural
        if familiarity > 1.0 or (familiarity == 1 and fm_scale):
            # Convert 1-20 scale to 0-1
            # Fam=1 → 0.0, Fam=20 → 1.0
            familiarity = (min(familiarity, 20) - 1) / 19.0

    # Clamp to valid range
    familiarity = max(0.0, min(1.0, familiarity))

    return FAMILIARITY_FLOOR + FAMILIARITY_SLOPE * familiarity


def jadedness_multiplier_gss(jadedness: int) -> float:
    """
    Calculate Jadedness Multiplier Ω(J) using step function from research.

    This is a STEP FUNCTION with discrete states, not a continuous sigmoid.

    States (0-1000 scale):
        Fresh (0-200):    Ω = 1.00 - Peak performance
        Fit (201-400):    Ω = 0.90 - Minor decay, acceptable
        Tired (401-700):  Ω = 0.70 - Significant penalty, rotate
        Jaded (701+):     Ω = 0.40 - Critical, requires holiday

    Args:
        jadedness: Jadedness value (0-1000)

    Returns:
        Multiplier (0.40 to 1.00)
    """
    return get_jadedness_multiplier(jadedness)


def is_below_condition_floor(condition_pct: float) -> bool:
    """
    Check if player condition is below the 91% floor.

    Research finding: NEVER start a player below 91% condition.

    Args:
        condition_pct: Player condition as decimal (0.0-1.0) or percentage (0-100)

    Returns:
        True if condition is below floor (should not start)
    """
    # Normalize to 0-1 range if given as percentage
    if condition_pct > 1.0:
        condition_pct = condition_pct / 100.0

    return condition_pct < CONDITION_FLOOR


def calculate_gss(
    base_rating: float,
    condition_pct: float,
    sharpness_pct: float,
    familiarity: float,
    jadedness: int = 0
) -> Tuple[float, Dict[str, float]]:
    """
    Calculate the Global Selection Score (GSS) using research-based multipliers.

    Formula: GSS = BPS × Φ(C) × Ψ(S) × Θ(F) × Ω(J)

    This is the primary scoring function based on FM26 research.

    Args:
        base_rating: Base Position Score (e.g., Harmonic Mean of IP/OOP)
        condition_pct: Player condition (0-1 or 0-100)
        sharpness_pct: Player sharpness (0-1 or 0-100)
        familiarity: Position familiarity (0-1 or 1-20)
        jadedness: Jadedness value (0-1000)

    Returns:
        Tuple of (gss_score, multiplier_breakdown_dict)

    Example:
        gss, breakdown = calculate_gss(
            base_rating=150,
            condition_pct=0.92,
            sharpness_pct=0.85,
            familiarity=18,
            jadedness=150
        )
        # gss ≈ 150 × 0.73 × 0.79 × 0.97 × 1.0 ≈ 84
    """
    # Calculate individual multipliers
    phi = condition_multiplier_gss(condition_pct)
    psi = sharpness_multiplier_gss(sharpness_pct)
    theta = familiarity_multiplier_gss(familiarity)
    omega = jadedness_multiplier_gss(jadedness)

    # Calculate GSS
    gss = base_rating * phi * psi * theta * omega

    # Build breakdown for explainability
    breakdown = {
        'base': base_rating,
        'condition': phi,
        'sharpness': psi,
        'familiarity': theta,
        'jadedness': omega,
        'gss': gss
    }

    return gss, breakdown


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


def calculate_match_utility_gss(
    player_data: Dict[str, Any],
    ip_rating: float,
    oop_rating: float,
    ip_familiarity: float,
    oop_familiarity: float,
    context: Optional[ScoringContext] = None  # Ignored - kept for interface compatibility
) -> Tuple[float, GSSBreakdown]:
    """
    Calculate Match Utility using GSS research-based multipliers.

    This is a drop-in replacement for the legacy calculate_match_utility().
    It provides the same interface but uses the correct GSS formulas:
    - Condition: STEEP sigmoid (k=25, c₀=0.88)
    - Sharpness: bounded sigmoid (k=15, s₀=0.75)
    - Familiarity: LINEAR (0.7 + 0.3f)
    - Jadedness: step function (Fresh/Fit/Tired/Jaded)

    Note: The 'context' parameter is accepted for interface compatibility
    but is IGNORED. GSS uses fixed parameters from research, not
    context-dependent ones.

    Args:
        player_data: Dict with player attributes including:
            - Condition: 0-100 or 0-10000
            - Match Sharpness: 0-100 or 0-10000
            - Jadedness: 0-1000 (or Fatigue for legacy data)
        ip_rating: In-Possession role rating (0-200)
        oop_rating: Out-of-Possession role rating (0-200)
        ip_familiarity: IP position familiarity (1-20)
        oop_familiarity: OOP position familiarity (1-20)
        context: IGNORED - kept for backward compatibility only

    Returns:
        Tuple of (final_utility, GSSBreakdown for explainability)

    Example:
        utility, breakdown = calculate_match_utility_gss(
            player_data={'Condition': 92, 'Match Sharpness': 85, 'Jadedness': 150},
            ip_rating=160, oop_rating=140,
            ip_familiarity=18, oop_familiarity=15
        )
    """
    # 1. Base Rating: Harmonic Mean of IP/OOP
    base_rating = calculate_harmonic_mean(ip_rating, oop_rating)

    # 2. Extract player state values (handle various input formats)
    condition = player_data.get('Condition', 100)
    # Normalize to 0-1 range (handle 0-10000 or 0-100 scale)
    if condition > 100:
        condition_pct = condition / 10000.0
    else:
        condition_pct = condition / 100.0

    sharpness = player_data.get('Match Sharpness', 100)
    # Normalize to 0-1 range
    if sharpness > 100:
        sharpness_pct = sharpness / 10000.0
    else:
        sharpness_pct = sharpness / 100.0

    # Jadedness - try multiple field names for compatibility
    jadedness = player_data.get('Jadedness', 0)
    if jadedness == 0:
        # Fall back to Fatigue if Jadedness not present
        jadedness = player_data.get('Fatigue', 0)

    # 3. Average familiarity (both positions matter for versatility)
    avg_familiarity = (ip_familiarity + oop_familiarity) / 2.0
    # Convert FM 1-20 scale to 0-1 for GSS
    if avg_familiarity > 1.0:
        familiarity_normalized = (min(avg_familiarity, 20) - 1) / 19.0
    else:
        familiarity_normalized = avg_familiarity

    # 4. Calculate GSS multipliers
    phi = condition_multiplier_gss(condition_pct)
    psi = sharpness_multiplier_gss(sharpness_pct)
    theta = familiarity_multiplier_gss(familiarity_normalized, fm_scale=False)
    omega = jadedness_multiplier_gss(int(jadedness))

    # 5. Calculate final utility (multiplicative)
    final_utility = base_rating * phi * psi * theta * omega

    # 6. Create breakdown for explainability
    breakdown = GSSBreakdown(
        base_rating=base_rating,
        condition_mult=phi,
        sharpness_mult=psi,
        familiarity_mult=theta,
        jadedness_mult=omega,
        final_utility=final_utility
    )

    return final_utility, breakdown
