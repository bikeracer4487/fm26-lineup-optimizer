"""
FM26 Scoring Parameters
=======================

Context-dependent parameters for the Match Utility Score based on match importance.

Reference: docs/new-research/FM26 #1 - System spec + decision model (foundation).md
Section 3.4: Recommended Parameter Values

Parameter Table:
| Parameter            | High | Medium | Low  | Sharpness |
|----------------------|------|--------|------|-----------|
| Safety Threshold     | 80%  | 91%    | 94%  | 85%       |
| Decay Slope (alpha)  | 0.005| 0.015  | 0.05 | 0.01      |
| Familiarity Min      | 15   | 12     | 5    | 10        |
| Jadedness Penalty    | 0.9  | 0.6    | 0.1  | 0.5       |
| Sharpness Mode       | std  | std    | std  | build     |
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

IMPORTANCE_WEIGHTS = {
    'High': 3.0,      # High priority matches worth 3x
    'Medium': 1.5,    # Medium priority matches worth 1.5x
    'Low': 0.5,       # Low priority matches worth 0.5x
    'Sharpness': 0.3  # Sharpness/development matches worth 0.3x
}


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
