"""
FM26 Scoring Parameters
=======================

Context-dependent parameters for the Match Utility Score based on match importance.

References:
- docs/new-research/FM26 #1 - System spec + decision model (foundation).md
- docs/new-research/FM26 #2 - Lineup Optimizer - Complete Mathematical Specification.md

The mathematical specification defines bounded sigmoid multipliers for smooth transitions:
    Multiplier(x) = α + (1 - α) × σ(k × (x - T))
    where σ(z) = 1 / (1 + e^(-z))

All multipliers map to range [α_floor, 1.0] where α_floor > 0 ensures emergency utility
is never zero.
"""

from dataclasses import dataclass
from typing import Literal

# Type for match importance levels
ImportanceLevel = Literal['High', 'Medium', 'Low', 'Sharpness']

# Type for training intensity levels
TrainingIntensity = Literal['Low', 'Medium', 'High']

# Type for sharpness mode
SharpnessMode = Literal['standard', 'build']


@dataclass
class ScoringContext:
    """
    Holds all context-dependent parameters for scoring a single match.

    These parameters are determined by match importance and affect how
    aggressively we filter/penalize players based on their physical state.
    """

    # Match importance level
    importance: ImportanceLevel

    # Condition Multiplier Parameters
    safety_threshold: float  # T_safe: Minimum condition % before critical penalty
    decay_slope: float       # alpha: Rate of penalty per % below 95

    # Familiarity Parameters
    familiarity_min: int     # Minimum familiarity (1-20) before extra penalty

    # Fatigue/Jadedness Parameters
    jadedness_penalty: float  # Multiplier applied to jaded players

    # Sharpness Mode
    sharpness_mode: SharpnessMode  # 'standard' or 'build'

    # Training Intensity (affects recovery projection)
    training_intensity: TrainingIntensity = 'Medium'

    # Recovery rate modifier based on training intensity
    @property
    def recovery_modifier(self) -> float:
        """
        Adjusts base recovery rate based on training intensity.
        Higher intensity = slower recovery (more fatigue from training).

        Returns:
            Multiplier (0.8 to 1.2)
        """
        modifiers = {
            'Low': 1.2,    # 20% faster recovery (light training)
            'Medium': 1.0,  # Standard recovery
            'High': 0.8    # 20% slower recovery (double intensity)
        }
        return modifiers.get(self.training_intensity, 1.0)


# Pre-defined parameter sets for each importance level
IMPORTANCE_PARAMETERS = {
    'High': {
        'safety_threshold': 80.0,
        'decay_slope': 0.005,
        'familiarity_min': 15,
        'jadedness_penalty': 0.9,
        'sharpness_mode': 'standard'
    },
    'Medium': {
        'safety_threshold': 91.0,
        'decay_slope': 0.015,
        'familiarity_min': 12,
        'jadedness_penalty': 0.6,
        'sharpness_mode': 'standard'
    },
    'Low': {
        'safety_threshold': 94.0,
        'decay_slope': 0.05,
        'familiarity_min': 5,
        'jadedness_penalty': 0.1,
        'sharpness_mode': 'standard'
    },
    'Sharpness': {
        'safety_threshold': 85.0,
        'decay_slope': 0.01,
        'familiarity_min': 10,
        'jadedness_penalty': 0.5,
        'sharpness_mode': 'build'
    }
}


def get_context_parameters(
    importance: ImportanceLevel,
    training_intensity: TrainingIntensity = 'Medium'
) -> ScoringContext:
    """
    Get the full ScoringContext for a given match importance level.

    Args:
        importance: Match importance ('High', 'Medium', 'Low', 'Sharpness')
        training_intensity: Club's training intensity setting

    Returns:
        ScoringContext with all parameters set appropriately
    """
    params = IMPORTANCE_PARAMETERS.get(importance, IMPORTANCE_PARAMETERS['Medium'])

    return ScoringContext(
        importance=importance,
        safety_threshold=params['safety_threshold'],
        decay_slope=params['decay_slope'],
        familiarity_min=params['familiarity_min'],
        jadedness_penalty=params['jadedness_penalty'],
        sharpness_mode=params['sharpness_mode'],
        training_intensity=training_intensity
    )


# =============================================================================
# IMPORTANCE WEIGHTS (for Shadow Pricing calculations)
# =============================================================================
# Updated per Mathematical Specification (FM26 #2) Section E

IMPORTANCE_WEIGHTS = {
    'High': 1.5,      # High priority matches
    'Medium': 1.0,    # Medium priority matches (baseline)
    'Low': 0.6,       # Low priority matches
    'Sharpness': 0.8  # Sharpness/development matches
}

# Shadow pricing discount factor (gamma)
SHADOW_DISCOUNT_FACTOR = 0.85  # Future matches discounted by 15% per match


def get_importance_weight(importance: ImportanceLevel) -> float:
    """
    Get numerical weight for match importance (used in shadow pricing).

    Higher weights mean more "value" is assigned to performing well
    in that match, affecting opportunity cost calculations.

    Args:
        importance: Match importance level

    Returns:
        Weight multiplier (0.3 to 3.0)
    """
    return IMPORTANCE_WEIGHTS.get(importance, 1.0)


# =============================================================================
# CONSTANTS FOR STATE SIMULATION
# =============================================================================

# Base condition loss per 90 minutes played
BASE_CONDITION_LOSS = 15.0  # ~15% condition loss per full match

# Base condition recovery per rest day
BASE_CONDITION_RECOVERY = 5.0  # ~5% recovery per day base

# Sharpness gain per 90 minutes played
BASE_SHARPNESS_GAIN = 5.0  # ~5% sharpness gain per full match

# Sharpness decay per week of inactivity
BASE_SHARPNESS_DECAY = 2.0  # ~2% decay per week

# Fatigue threshold at which jadedness becomes a concern
FATIGUE_THRESHOLD = 400

# Key player CA threshold (for shadow pricing)
KEY_PLAYER_CA_THRESHOLD = 140

# Position-specific fatigue multipliers
# High-intensity positions accumulate fatigue faster
POSITION_FATIGUE_MULTIPLIERS = {
    'D(L)': 1.2, 'D(R)': 1.2,           # Full-backs run a lot
    'WB(L)': 1.2, 'WB(R)': 1.2,         # Wing-backs run even more
    'DM': 1.2, 'DM(L)': 1.2, 'DM(R)': 1.2,  # Defensive mids cover a lot
    'M(L)': 1.0, 'M(R)': 1.0, 'M(C)': 1.0,  # Central/wide mids
    'AM(L)': 1.0, 'AM(R)': 1.0, 'AM(C)': 1.0,  # Attacking mids/wingers
    'ST': 1.0, 'ST(L)': 1.0, 'ST(R)': 1.0, 'ST(C)': 1.0,  # Strikers
    'D(C)': 0.8,                         # Center-backs less running
    'GK': 0.8                            # Goalkeepers least physical
}


def get_position_fatigue_multiplier(position: str) -> float:
    """
    Get fatigue accumulation multiplier for a position.

    Args:
        position: Position key (e.g., 'D(L)', 'ST')

    Returns:
        Multiplier (0.8 to 1.2)
    """
    return POSITION_FATIGUE_MULTIPLIERS.get(position, 1.0)


# Position-specific rotation thresholds (consecutive matches before forced rest)
POSITION_ROTATION_THRESHOLDS = {
    # High-attrition positions - need more rest
    'D(L)': 3, 'D(R)': 3, 'WB(L)': 3, 'WB(R)': 3,
    'DM': 3, 'DM(L)': 3, 'DM(R)': 3,

    # Medium-attrition positions
    'M(L)': 4, 'M(R)': 4, 'M(C)': 4,
    'AM(L)': 4, 'AM(R)': 4, 'AM(C)': 4,
    'ST': 4, 'ST(L)': 4, 'ST(R)': 4, 'ST(C)': 4,

    # Low-attrition positions
    'D(C)': 5, 'GK': 6
}


def get_rotation_threshold(position: str) -> int:
    """
    Get maximum consecutive matches before rotation is advised.

    Args:
        position: Position key

    Returns:
        Maximum consecutive matches (3-6)
    """
    return POSITION_ROTATION_THRESHOLDS.get(position, 4)


# =============================================================================
# BOUNDED SIGMOID MULTIPLIER PARAMETERS
# =============================================================================
# Reference: FM26 #2 Mathematical Specification - Sections A, B, C
#
# All multipliers use bounded sigmoid: α + (1 - α) × σ(k × (x - T))
# where α = floor (minimum multiplier), T = threshold, k = steepness

# -----------------------------------------------------------------------------
# A. FAMILIARITY MULTIPLIER (Θ) PARAMETERS
# -----------------------------------------------------------------------------
# Transforms FM's 1-20 familiarity rating into utility multiplier
# Higher steepness (k) = sharper transition at threshold

FAMILIARITY_SIGMOID_PARAMS = {
    'High': {
        'alpha': 0.30,      # Floor: 30% utility even for awkward positions
        'threshold': 12,    # Transition point (Competent level)
        'steepness': 0.55   # Strict: demands accomplished familiarity
    },
    'Medium': {
        'alpha': 0.40,
        'threshold': 10,
        'steepness': 0.45   # Balanced: competent is acceptable
    },
    'Low': {
        'alpha': 0.50,
        'threshold': 7,
        'steepness': 0.35   # Tolerant: experimentation allowed
    },
    'Sharpness': {
        'alpha': 0.25,
        'threshold': 14,
        'steepness': 0.70   # Development focus: needs confident players
    }
}

# -----------------------------------------------------------------------------
# B. FATIGUE MULTIPLIER (Λ) PARAMETERS
# -----------------------------------------------------------------------------
# Uses player-relative thresholds: Λ = α + (1-α) × (1 - σ(k × (F/T - r)))
# where F = fatigue, T = player threshold, r = ratio where penalties begin
# Key insight: High importance INCREASES α (allows fatigued players to push through)

FATIGUE_SIGMOID_PARAMS = {
    'High': {
        'alpha': 0.50,      # Push-through: 50% floor for crucial matches
        'ratio': 0.85,      # Penalties begin at 85% of threshold
        'steepness': 5.0    # Moderate transition
    },
    'Medium': {
        'alpha': 0.25,
        'ratio': 0.75,
        'steepness': 6.0    # Standard fatigue sensitivity
    },
    'Low': {
        'alpha': 0.15,
        'ratio': 0.65,
        'steepness': 8.0    # Aggressive rest for rotation matches
    },
    'Sharpness': {
        'alpha': 0.20,
        'ratio': 0.70,
        'steepness': 7.0    # Fresh only: low fatigue for sharpness building
    }
}

# -----------------------------------------------------------------------------
# C. CONDITION MULTIPLIER (Φ) PARAMETERS
# -----------------------------------------------------------------------------
# Φ = α + (1-α) × σ(k × (C - T_safe))
# High importance tolerates LOWER condition (must field best XI)
# Low importance demands HIGH condition (preserve players)

CONDITION_SIGMOID_PARAMS = {
    'High': {
        'alpha': 0.40,      # Floor: 40% for crucial matches
        'threshold': 75,    # Must field best XI even if tired
        'slope': 0.12       # Steeper curve
    },
    'Medium': {
        'alpha': 0.35,
        'threshold': 82,
        'slope': 0.10       # Standard balance
    },
    'Low': {
        'alpha': 0.30,
        'threshold': 88,
        'slope': 0.08       # Only fully fit should play
    },
    'Sharpness': {
        'alpha': 0.35,
        'threshold': 80,
        'slope': 0.15       # Need condition for effective sharpness building
    }
}

# -----------------------------------------------------------------------------
# D. SHARPNESS MULTIPLIER (Ψ) PARAMETERS
# -----------------------------------------------------------------------------
# Standard form: Ψ = 0.40 + 0.60 × (Sh/100)^0.8
# This power curve matches FM's internal sharpness-to-performance mapping

SHARPNESS_CURVE_PARAMS = {
    'floor': 0.40,          # Minimum 40% utility at 0% sharpness
    'ceiling_range': 0.60,  # Additional 60% available from sharpness
    'exponent': 0.8         # Power curve exponent (diminishing returns)
}


# =============================================================================
# FIXTURE DENSITY ADJUSTMENTS
# =============================================================================
# Reduces utility for players who would have insufficient recovery before next match

FIXTURE_DENSITY_FACTORS = {
    5: 1.00,    # 5+ days rest: full utility
    4: 0.95,    # 4 days: 95%
    3: 0.90,    # 3 days: 90%
    2: 0.85,    # 2 days: 85%
    1: 0.80,    # 1 day: 80%
    0: 0.75     # Same day (unlikely): 75%
}


def get_fixture_density_factor(days_to_next_match: int) -> float:
    """
    Get condition adjustment factor based on fixture density.

    Args:
        days_to_next_match: Days until next match

    Returns:
        Multiplier (0.75 to 1.00)
    """
    if days_to_next_match >= 5:
        return 1.00
    return FIXTURE_DENSITY_FACTORS.get(days_to_next_match, 0.85)


# =============================================================================
# POSITION-SPECIFIC DRAIN RATES
# =============================================================================
# Reference: FM26 #2 Section D - State Propagation Equations
# Condition drain per 90 minutes by position (affected by stamina)

POSITION_DRAIN_RATES = {
    # Goalkeepers - minimal physical exertion
    'GK': 15,

    # Center-backs and Defensive Midfielders - moderate
    'D(C)': 25,
    'DM': 25, 'DM(L)': 25, 'DM(R)': 25,

    # Full-backs and Midfielders - high workload
    'D(L)': 30, 'D(R)': 30, 'D(R/L)': 30,
    'WB(L)': 30, 'WB(R)': 30,
    'M(L)': 30, 'M(R)': 30, 'M(C)': 30,
    'CM': 30,
    'AM(L)': 30, 'AM(R)': 30, 'AM(C)': 30,

    # Wingers and Strikers - highest intensity
    'W': 35, 'W(L)': 35, 'W(R)': 35,
    'ST': 35, 'ST(C)': 35, 'ST(L)': 35, 'ST(R)': 35,
    'Striker': 35
}


def get_position_drain_rate(position: str) -> float:
    """
    Get condition drain rate for a position (per 90 minutes played).

    Args:
        position: Position key (e.g., 'GK', 'D(C)', 'Striker')

    Returns:
        Drain rate (15-35)
    """
    return POSITION_DRAIN_RATES.get(position, 25)  # Default to moderate


# =============================================================================
# STABILITY MECHANISM PARAMETERS
# =============================================================================
# Reference: FM26 #2 Section F - Polyvalent Stability

@dataclass
class StabilityConfig:
    """Configuration for assignment stability mechanisms."""

    # User-configurable slider: 0 = pure optimal, 1 = maximum stability
    inertia_weight: float = 0.5

    # Base penalty for switching positions (~15% utility penalty)
    base_switch_cost: float = 0.15

    # Bonus for staying in same position (~5% utility bonus)
    continuity_bonus: float = 0.05

    # Multiplier for anchor strength (3+ consecutive matches in same position)
    anchor_multiplier: float = 2.0

    # Minimum consecutive matches to establish anchor
    anchor_threshold: int = 3


# Default stability configuration
DEFAULT_STABILITY_CONFIG = StabilityConfig()


# =============================================================================
# SHARPNESS PROPAGATION PARAMETERS
# =============================================================================
# Reference: FM26 #2 Section D - Sharpness update

SHARPNESS_GAIN_RATE = 1500      # Per full competitive match (on 0-10000 scale)
SHARPNESS_DECAY_RATE = 100      # Per day without match

MATCH_TYPE_SHARPNESS_FACTORS = {
    'competitive': 1.0,
    'friendly': 0.7,
    'reserve': 0.5
}


# =============================================================================
# FATIGUE PROPAGATION PARAMETERS
# =============================================================================
# Reference: FM26 #2 Section D - Fatigue update

FATIGUE_GAIN_PER_90 = 20        # Base fatigue gain per full match
FATIGUE_RECOVERY_PER_DAY = 10   # Base recovery per rest day
VACATION_BONUS_MULTIPLIER = 5.0  # Additional recovery during vacation

INTENSITY_FACTORS = {
    'normal': 1.0,
    'high_press': 1.3,
    'rotation': 0.8
}


# =============================================================================
# HELPER FUNCTIONS FOR SIGMOID PARAMETERS
# =============================================================================

def get_familiarity_params(importance: ImportanceLevel) -> dict:
    """Get familiarity sigmoid parameters for given importance level."""
    return FAMILIARITY_SIGMOID_PARAMS.get(importance, FAMILIARITY_SIGMOID_PARAMS['Medium'])


def get_fatigue_params(importance: ImportanceLevel) -> dict:
    """Get fatigue sigmoid parameters for given importance level."""
    return FATIGUE_SIGMOID_PARAMS.get(importance, FATIGUE_SIGMOID_PARAMS['Medium'])


def get_condition_params(importance: ImportanceLevel) -> dict:
    """Get condition sigmoid parameters for given importance level."""
    return CONDITION_SIGMOID_PARAMS.get(importance, CONDITION_SIGMOID_PARAMS['Medium'])
