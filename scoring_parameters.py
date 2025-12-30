"""
FM26 Scoring Parameters
=======================

Unified parameters for the Global Selection Score (GSS) model based on
comprehensive FM26 research program (Steps 1-11).

References:
- docs/new-research/02-RESULTS-unified-scoring.md (GSS formula, multipliers)
- docs/new-research/03-RESULTS-state-propagation.md (R_pos coefficients, 270-min rule)
- docs/new-research/05-RESULTS-shadow-pricing.md (importance weights, VORP)
- docs/new-research/06-RESULTS-fatigue-rest.md (jadedness thresholds, archetypes)
- docs/new-research/12-IMPLEMENTATION-PLAN.md (consolidated specification)

GSS Formula (Step 2):
    GSS = BPS × Φ(C) × Ψ(S) × Θ(F) × Ω(J)

    Where:
    - BPS: Base Position Score (role-weighted attributes)
    - Φ(C): Condition multiplier - STEEP sigmoid, k=25, c0=0.88
    - Ψ(S): Sharpness multiplier - bounded sigmoid, k=15, s0=0.75
    - Θ(F): Familiarity multiplier - LINEAR (0.7 + 0.3f), NOT sigmoid!
    - Ω(J): Jadedness multiplier - step function with discrete states
"""

from dataclasses import dataclass
from typing import Literal, Dict, Tuple

# Type for match importance levels
ImportanceLevel = Literal['High', 'Medium', 'Low', 'Sharpness']


# =============================================================================
# GSS MULTIPLIER PARAMETERS (Step 2 Research - CANONICAL VALUES)
# =============================================================================
# These are the PRIMARY parameters derived from FM26 research.
# They replace the context-dependent sigmoid parameters below.

# -----------------------------------------------------------------------------
# Condition Multiplier Φ(C) - STEEP Sigmoid
# -----------------------------------------------------------------------------
# Formula: Φ(c) = 1 / (1 + e^{-k(c - c₀)})
# Research finding: FM26 uses a MUCH steeper sigmoid than previously assumed
# k=25 creates a sharp cliff around 88% condition

CONDITION_SIGMOID_K = 25       # Steepness (MUCH steeper than old k=0.10-0.15)
CONDITION_SIGMOID_C0 = 0.88    # Threshold (88% condition)
CONDITION_FLOOR = 0.91         # NEVER start player below 91% condition

# -----------------------------------------------------------------------------
# Sharpness Multiplier Ψ(S) - Bounded Sigmoid
# -----------------------------------------------------------------------------
# Formula: Ψ(s) = 1.02 / (1 + e^{-k(s - s₀)}) - 0.02
# The bounds prevent negative values and cap at ~1.0

SHARPNESS_SIGMOID_K = 15       # Steepness
SHARPNESS_SIGMOID_S0 = 0.75    # Threshold (75% sharpness)
SHARPNESS_GATE = 0.85          # Build sharpness with U21/reserves first

# -----------------------------------------------------------------------------
# Familiarity Multiplier Θ(F) - LINEAR (NOT sigmoid!)
# -----------------------------------------------------------------------------
# Formula: Θ(f) = 0.7 + 0.3f  where f ∈ [0, 1]
# Research finding: Familiarity is LINEAR, not sigmoid as previously assumed
# Natural position (f=1.0) → 1.0, Completely unfamiliar (f=0) → 0.7

FAMILIARITY_FLOOR = 0.70       # Minimum multiplier at 0% familiarity
FAMILIARITY_SLOPE = 0.30       # Additional multiplier per unit familiarity

# -----------------------------------------------------------------------------
# Jadedness/Fatigue Multiplier Ω(J) - Step Function
# -----------------------------------------------------------------------------
# Research finding: FM26 uses discrete states, not continuous function
# Scale: 0-1000 internal jadedness points

JADEDNESS_THRESHOLDS: Dict[str, Tuple[int, int]] = {
    'fresh': (0, 200),         # Ω = 1.00 - Peak performance
    'fit': (201, 400),         # Ω = 0.90 - Minor decay, acceptable
    'tired': (401, 700),       # Ω = 0.70 - Significant penalty, rotate
    'jaded': (701, 1000)       # Ω = 0.40 - Critical - requires holiday
}

JADEDNESS_MULTIPLIERS: Dict[str, float] = {
    'fresh': 1.00,
    'fit': 0.90,
    'tired': 0.70,
    'jaded': 0.40
}


def get_jadedness_state(jadedness: int) -> str:
    """
    Get jadedness state name from jadedness value.

    Args:
        jadedness: Jadedness value (0-1000)

    Returns:
        State name ('fresh', 'fit', 'tired', 'jaded')
    """
    if jadedness <= 200:
        return 'fresh'
    elif jadedness <= 400:
        return 'fit'
    elif jadedness <= 700:
        return 'tired'
    else:
        return 'jaded'


def get_jadedness_multiplier(jadedness: int) -> float:
    """
    Get fatigue multiplier Ω(J) from jadedness value.

    Args:
        jadedness: Jadedness value (0-1000)

    Returns:
        Multiplier (0.40 to 1.00)
    """
    state = get_jadedness_state(jadedness)
    return JADEDNESS_MULTIPLIERS[state]


# =============================================================================
# POSITIONAL DRAG COEFFICIENTS (Step 3 Research - R_pos)
# =============================================================================
# These coefficients determine condition drain rate per 90 minutes.
# Higher R_pos = faster drain = more rotation needed
# Key insight: FB/WB have HIGHEST drain (1.65), need 100% rotation

R_POS: Dict[str, float] = {
    # Goalkeepers - minimal drain
    'GK': 0.20,

    # Center-backs - can play consecutive matches
    'CB': 0.95,
    'DC': 0.95,
    'D(C)': 0.95,

    # Defensive midfielders - moderate drain
    'DM': 1.15,
    'DM(L)': 1.15,
    'DM(R)': 1.15,

    # Central midfielders (B2B) - high drain
    'CM': 1.45,
    'MC': 1.45,
    'M(C)': 1.45,

    # Attacking midfielders - high drain
    'AMC': 1.35,
    'AM': 1.35,
    'AM(C)': 1.35,

    # Wide attacking players - high drain
    'AML': 1.40,
    'AMR': 1.40,
    'AM(L)': 1.40,
    'AM(R)': 1.40,
    'Winger': 1.40,
    'W': 1.40,
    'W(L)': 1.40,
    'W(R)': 1.40,

    # Strikers - high drain
    'ST': 1.40,
    'STC': 1.40,
    'ST(C)': 1.40,
    'Striker': 1.40,

    # Full-backs and Wing-backs - HIGHEST drain (100% rotation needed)
    'DL': 1.65,
    'DR': 1.65,
    'D(L)': 1.65,
    'D(R)': 1.65,
    'D(R/L)': 1.65,
    'FB': 1.65,
    'WB': 1.65,
    'WBL': 1.65,
    'WBR': 1.65,
    'WB(L)': 1.65,
    'WB(R)': 1.65,
}


def get_r_pos(position: str) -> float:
    """
    Get positional drag coefficient R_pos for a position.

    Args:
        position: Position key (e.g., 'GK', 'D(C)', 'WB(L)')

    Returns:
        R_pos coefficient (0.20 to 1.65)
    """
    return R_POS.get(position, 1.0)  # Default to 1.0 for unknown positions


# =============================================================================
# 270-MINUTE RULE (Step 3 Research)
# =============================================================================
# Players exceeding 270 minutes in 14 days accumulate jadedness 2.5x faster

MINUTES_WINDOW_DAYS = 14       # Window is 14 days (not 10!)
MINUTES_THRESHOLD = 270        # Threshold in minutes
JADEDNESS_PENALTY_MULTIPLIER = 2.5  # Multiplier when threshold exceeded


# =============================================================================
# SHARPNESS DECAY - SEVEN-DAY CLIFF (Step 3 Research)
# =============================================================================
# Sharpness decay accelerates dramatically after 7 days without match

SHARPNESS_DECAY_RATES: Dict[str, float] = {
    'day_0_3': 0.00,           # No decay days 0-3
    'day_4_6': 0.015,          # ~1.5% per day, days 4-6
    'day_7_plus': 0.065        # ~6.5% per day after day 7 (THE CLIFF)
}


def get_sharpness_decay_rate(days_since_match: int) -> float:
    """
    Get sharpness decay rate based on days since last match.

    Args:
        days_since_match: Days since player last played

    Returns:
        Daily decay rate (0.00 to 0.065)
    """
    if days_since_match <= 3:
        return SHARPNESS_DECAY_RATES['day_0_3']
    elif days_since_match <= 6:
        return SHARPNESS_DECAY_RATES['day_4_6']
    else:
        return SHARPNESS_DECAY_RATES['day_7_plus']

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
# SHADOW PRICING PARAMETERS (Step 5 Research)
# =============================================================================
# Shadow pricing calculates opportunity cost of using a player now vs. future
# Formula: λ_{p,t} = S_p^{VORP} × Σ_{k=t+1}^{T} (γ^{k-t} × I_k × max(0, ΔGSS))

# Shadow pricing discount factor (gamma)
SHADOW_DISCOUNT_GAMMA = 0.85   # Future matches discounted by 15% per match

# Shadow pricing weight (how much shadow cost affects selection)
SHADOW_WEIGHT = 1.0            # Range: 0.0 (ignore) to 2.0 (heavy)

# VORP (Value Over Replacement Player) scarcity scaling
VORP_SCARCITY_LAMBDA = 2.0     # Range: 1.0-3.0
# Formula: α_scarcity = 1 + λ_V × min(0.5, (GSS_star - GSS_backup) / GSS_star)
# Gap% > 10% → player is "Key", gets higher shadow protection

# -----------------------------------------------------------------------------
# Importance Weights - EXPONENTIAL SCALE (Step 5 Research)
# -----------------------------------------------------------------------------
# These weights are MUCH more spread out than the old 0.6-1.5 scale
# Cup Final at 10.0 means shadow cost dominates for preceding matches

IMPORTANCE_WEIGHTS_DETAILED: Dict[str, float] = {
    # Critical matches - maximum shadow protection
    'cup_final': 10.0,
    'continental_ko': 5.0,      # Champions League knockout

    # Important matches - strong shadow protection
    'title_rival': 3.0,         # League match vs title competitor
    'league_standard': 1.5,     # Normal league match

    # Lower priority - allow rotation
    'cup_early': 0.8,           # Early cup rounds
    'dead_rubber': 0.1,         # Nothing to play for
    'friendly': 0.1,
}

# Mapping from ImportanceLevel to detailed weights
IMPORTANCE_WEIGHTS: Dict[str, float] = {
    'High': 3.0,      # Maps to title_rival level
    'Medium': 1.5,    # Maps to league_standard
    'Low': 0.8,       # Maps to cup_early
    'Sharpness': 0.1  # Maps to dead_rubber (rest stars, play youth)
}

# Legacy alias for backward compatibility
SHADOW_DISCOUNT_FACTOR = SHADOW_DISCOUNT_GAMMA


def get_importance_weight(importance: ImportanceLevel) -> float:
    """
    Get numerical weight for match importance (used in shadow pricing).

    Higher weights mean more "value" is assigned to performing well
    in that match, affecting opportunity cost calculations.

    Args:
        importance: Match importance level

    Returns:
        Weight multiplier (0.1 to 10.0)
    """
    return IMPORTANCE_WEIGHTS.get(importance, 1.5)


def get_detailed_importance_weight(match_type: str) -> float:
    """
    Get detailed importance weight for specific match types.

    Args:
        match_type: Specific match type (e.g., 'cup_final', 'title_rival')

    Returns:
        Weight multiplier (0.1 to 10.0)
    """
    return IMPORTANCE_WEIGHTS_DETAILED.get(match_type, 1.5)


def calculate_vorp_scarcity(gss_star: float, gss_backup: float) -> float:
    """
    Calculate VORP scarcity multiplier for a player.

    Players with large gaps to their backup get higher shadow protection.
    Gap% > 10% means player is "Key" and gets multiplied shadow cost.

    Args:
        gss_star: GSS of the starting player
        gss_backup: GSS of the best backup for that position

    Returns:
        Scarcity multiplier (1.0 to 2.0)
    """
    if gss_star <= 0:
        return 1.0
    gap_pct = (gss_star - gss_backup) / gss_star
    # Cap at 50% gap (prevents extreme values)
    return 1.0 + VORP_SCARCITY_LAMBDA * min(0.5, max(0.0, gap_pct))


# =============================================================================
# HUNGARIAN MATRIX PARAMETERS (Step 4 Research)
# =============================================================================
# Two-stage algorithm: Stage 1 (Starting XI), Stage 2 (Bench)

# Safe Big M value (Step 4) - NOT infinity, which causes SciPy errors
BIG_M = 1e6

# Multi-objective scalarization weights by scenario
# C_total = w_perf × C_perf + w_dev × C_dev + w_rest × C_rest
SCENARIO_WEIGHTS: Dict[str, Dict[str, float]] = {
    'cup_final': {'perf': 1.0, 'dev': 0.0, 'rest': 0.0},
    'league_grind': {'perf': 0.6, 'dev': 0.1, 'rest': 0.3},
    'dead_rubber': {'perf': 0.2, 'dev': 0.5, 'rest': 0.3},
    'sharpness': {'perf': 0.3, 'dev': 0.4, 'rest': 0.3},
}

# Condition cliff thresholds (Step 4)
# Defines multipliers based on condition percentage
CONDITION_CLIFF: Dict[str, Tuple[float, float, float]] = {
    # (min_condition, max_condition, multiplier)
    'peak': (0.95, 1.00, 1.00),      # ≥95%: full utility
    'startable': (0.90, 0.94, 0.95), # 90-94%: slight penalty
    'risk': (0.80, 0.89, 0.80),      # 80-89%: significant penalty
    'danger': (0.75, 0.79, 0.50),    # 75-79%: major penalty
    # Below 75%: BIG_M penalty (forbidden)
}


def get_condition_cliff_multiplier(condition: float) -> float:
    """
    Get condition cliff multiplier for Hungarian matrix.

    Args:
        condition: Player condition (0.0 to 1.0)

    Returns:
        Multiplier (0.50 to 1.00) or BIG_M for forbidden
    """
    if condition >= 0.95:
        return 1.00
    elif condition >= 0.90:
        return 0.95
    elif condition >= 0.80:
        return 0.80
    elif condition >= 0.75:
        return 0.50
    else:
        return BIG_M  # Forbidden


# =============================================================================
# PLAYER ARCHETYPES (Step 6 Research)
# =============================================================================
# Different player types require different rotation/rest policies

PLAYER_ARCHETYPES: Dict[str, Dict[str, any]] = {
    'workhorse': {
        'description': 'High NF/Sta, can handle heavy workload',
        'min_natural_fitness': 15,
        'min_stamina': 15,
        'holiday_every_matches': 15,
        'max_mins_14d': 360,
    },
    'glass_cannon': {
        'description': 'Injury prone or low NF, needs careful management',
        'max_injury_proneness': 12,  # Above this = glass cannon
        'max_natural_fitness': 12,   # Below this = glass cannon
        'max_mins_14d': 180,
        'sub_at_minute': 60,
    },
    'veteran': {
        'description': 'Age 30+, limited to one game per week',
        'min_age': 30,
        'max_matches_per_week': 1,
    },
    'youngster': {
        'description': 'Age <19, limit senior exposure',
        'max_age': 18,
        'max_senior_starts_season': 25,
    },
    'standard': {
        'description': 'Normal player, standard rotation',
        'max_mins_14d': 270,
    }
}


def classify_player_archetype(
    age: int,
    natural_fitness: int = 10,
    stamina: int = 10,
    injury_proneness: int = 10
) -> str:
    """
    Classify a player into an archetype for rest policy.

    Args:
        age: Player age
        natural_fitness: Natural Fitness attribute (1-20)
        stamina: Stamina attribute (1-20)
        injury_proneness: Injury Proneness attribute (1-20)

    Returns:
        Archetype name ('workhorse', 'glass_cannon', 'veteran', 'youngster', 'standard')
    """
    if age >= 30:
        return 'veteran'
    elif age < 19:
        return 'youngster'
    elif natural_fitness >= 15 and stamina >= 15:
        return 'workhorse'
    elif injury_proneness > 12 or natural_fitness < 12:
        return 'glass_cannon'
    else:
        return 'standard'


# Holiday Protocol (Step 6)
# Standard Rest: ~5 J points/day recovery
# Holiday: ~50 J points/day recovery (10x faster)
HOLIDAY_RECOVERY_MULTIPLIER = 10.0
HOLIDAY_JADEDNESS_THRESHOLD = 400  # Send on holiday if jadedness > 400


# =============================================================================
# CONSTANTS FOR STATE SIMULATION (Legacy - Being Replaced)
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
# BOUNDED SIGMOID MULTIPLIER PARAMETERS (DEPRECATED)
# =============================================================================
# DEPRECATED: These context-dependent sigmoid parameters are being replaced by
# the unified GSS parameters at the top of this file (Steps 2-3 research).
#
# The research found that FM26 uses:
# - Condition: Single steep sigmoid (k=25, c0=0.88), not context-dependent
# - Familiarity: LINEAR function (0.7 + 0.3f), NOT sigmoid
# - Jadedness: Step function with discrete states, not sigmoid
#
# These are kept for backward compatibility with existing code.
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


# =============================================================================
# TRAINING RECOMMENDER PARAMETERS (Step 7 Research)
# =============================================================================
# Position Training Recommendation Engine (PTRE) parameters
# Reference: docs/new-research/07-RESULTS-training-recommender.md

# -----------------------------------------------------------------------------
# Age Plasticity Factors (Step 7)
# -----------------------------------------------------------------------------
# Player plasticity (ability to learn new positions) decreases with age.
# Used to adjust retraining timeline estimates and candidate priority.

AGE_PLASTICITY: Dict[Tuple[int, int], float] = {
    (16, 21): 1.0,   # High - radical conversions OK (Wonderkid phase)
    (22, 26): 0.7,   # Medium - adjacent moves only (Prime phase)
    (27, 31): 0.4,   # Low - career extension roles (Peak/Late phase)
    (32, 99): 0.1,   # Minimal - emergency swaps only (Veteran phase)
}


def get_age_plasticity(age: int) -> float:
    """
    Get plasticity factor based on player age.

    Higher plasticity = faster position learning, more flexible retraining.

    Args:
        age: Player age

    Returns:
        Plasticity factor (0.1 to 1.0)
    """
    for (min_age, max_age), plasticity in AGE_PLASTICITY.items():
        if min_age <= age <= max_age:
            return plasticity
    return 0.1  # Default to minimal for edge cases


# -----------------------------------------------------------------------------
# Retraining Difficulty Classes (Step 7)
# -----------------------------------------------------------------------------
# Time estimates for retraining based on positional similarity.
# Class I (easy) to Class IV (nearly impossible).

RETRAINING_DIFFICULTY: Dict[str, Dict[str, any]] = {
    'I': {
        'name': 'Fluid',
        'description': 'High attribute overlap, same pitch area, minor duty shift',
        'weeks_min': 4,
        'weeks_max': 8,
        'examples': ['LB→LWB', 'DM→MC', 'AM(L)→M(L)', 'ST→AMC'],
    },
    'II': {
        'name': 'Structural',
        'description': 'Shared defensive/offensive responsibility, different spatial awareness',
        'weeks_min': 12,
        'weeks_max': 20,
        'examples': ['DM→CB', 'AMC→ST', 'WB→DM', 'MC→DM'],
    },
    'III': {
        'name': 'Spatial',
        'description': 'Significant change in pitch geography, compression of space',
        'weeks_min': 24,
        'weeks_max': 36,
        'examples': ['AMR→MC', 'ST→AMR', 'CB→DM', 'MC→AMC'],
    },
    'IV': {
        'name': 'Inversion',
        'description': 'Complete inversion of duty, nearly impossible',
        'weeks_min': 52,
        'weeks_max': 999,
        'examples': ['ST→DR', 'MC→GK', 'GK→Any'],
    },
}


# Position transition difficulty mappings
# Maps (from_position, to_position) to difficulty class
POSITION_TRANSITIONS: Dict[Tuple[str, str], str] = {
    # Class I - Fluid (4-8 weeks)
    ('D(L)', 'WB(L)'): 'I', ('D(R)', 'WB(R)'): 'I',
    ('WB(L)', 'D(L)'): 'I', ('WB(R)', 'D(R)'): 'I',
    ('DM', 'M(C)'): 'I', ('M(C)', 'DM'): 'I',
    ('AM(L)', 'M(L)'): 'I', ('AM(R)', 'M(R)'): 'I',
    ('M(L)', 'AM(L)'): 'I', ('M(R)', 'AM(R)'): 'I',
    ('AM(C)', 'M(C)'): 'I', ('M(C)', 'AM(C)'): 'I',
    ('ST', 'AM(C)'): 'I', ('AM(C)', 'ST'): 'I',

    # Class II - Structural (12-20 weeks)
    ('DM', 'D(C)'): 'II', ('D(C)', 'DM'): 'II',
    ('AM(C)', 'DM'): 'II', ('DM', 'AM(C)'): 'II',
    ('WB(L)', 'M(L)'): 'II', ('WB(R)', 'M(R)'): 'II',
    ('M(L)', 'WB(L)'): 'II', ('M(R)', 'WB(R)'): 'II',
    ('WB(L)', 'AM(L)'): 'II', ('WB(R)', 'AM(R)'): 'II',

    # Class III - Spatial (24-36 weeks)
    ('AM(R)', 'M(C)'): 'III', ('AM(L)', 'M(C)'): 'III',
    ('ST', 'AM(R)'): 'III', ('ST', 'AM(L)'): 'III',
    ('D(C)', 'ST'): 'III', ('ST', 'D(C)'): 'III',

    # Class IV - Inversion (52+ weeks / impossible)
    ('ST', 'D(R)'): 'IV', ('ST', 'D(L)'): 'IV',
    ('GK', 'D(C)'): 'IV', ('D(C)', 'GK'): 'IV',
    ('M(C)', 'GK'): 'IV',
}


def get_retraining_difficulty(from_pos: str, to_pos: str) -> Dict[str, any]:
    """
    Get retraining difficulty class for a position transition.

    Args:
        from_pos: Current position (e.g., 'DM', 'AM(L)')
        to_pos: Target position (e.g., 'D(C)', 'WB(L)')

    Returns:
        Difficulty class dict with name, weeks_min, weeks_max, examples
    """
    # Check direct mapping
    difficulty_class = POSITION_TRANSITIONS.get((from_pos, to_pos))

    if difficulty_class:
        return RETRAINING_DIFFICULTY[difficulty_class]

    # Default: estimate based on positional similarity
    # If both are defensive, or both are attacking, assume Class II
    defensive_positions = {'GK', 'D(L)', 'D(R)', 'D(C)', 'WB(L)', 'WB(R)', 'DM'}
    attacking_positions = {'ST', 'AM(L)', 'AM(R)', 'AM(C)'}

    if (from_pos in defensive_positions and to_pos in defensive_positions) or \
       (from_pos in attacking_positions and to_pos in attacking_positions):
        return RETRAINING_DIFFICULTY['II']

    # Mixed zone (midfield ↔ defense or midfield ↔ attack)
    return RETRAINING_DIFFICULTY['III']


# -----------------------------------------------------------------------------
# Gap Severity Index (GSI) Parameters (Step 7)
# -----------------------------------------------------------------------------
# GSI = (Scarcity × Weight) + InjuryRisk + ScheduleDensity
# Used to prioritize which positions most urgently need depth.

# Position weights for GSI calculation
# Higher weight = more critical to fill gaps at this position
POSITION_WEIGHTS_GSI: Dict[str, float] = {
    # Critical positions - hard to replace
    'GK': 1.5,
    'D(C)': 1.3,
    'DM': 1.2,

    # Important positions - need good depth
    'D(L)': 1.1, 'D(R)': 1.1,
    'WB(L)': 1.1, 'WB(R)': 1.1,
    'M(C)': 1.0,

    # Flexible positions - easier to cover
    'AM(L)': 0.9, 'AM(R)': 0.9, 'AM(C)': 0.9,
    'M(L)': 0.9, 'M(R)': 0.9,
    'ST': 0.8,
}


def calculate_gsi(
    scarcity: float,
    position: str,
    starter_injury_risk: float = 0.0,
    schedule_density: float = 0.0
) -> float:
    """
    Calculate Gap Severity Index for a position.

    GSI = (Scarcity × Weight) + InjuryRisk + ScheduleDensity

    Higher GSI = more urgent need for depth at this position.

    Args:
        scarcity: Position scarcity score (0.0 to 1.0)
            - 0.0 = plenty of depth
            - 1.0 = critical shortage
        position: Position key (e.g., 'D(C)', 'AM(L)')
        starter_injury_risk: Injury risk of current starter (0.0 to 1.0)
        schedule_density: Upcoming match density (0.0 to 1.0)

    Returns:
        GSI score (0.0 to ~3.0, higher = more urgent)
    """
    weight = POSITION_WEIGHTS_GSI.get(position, 1.0)
    return (scarcity * weight) + starter_injury_risk + schedule_density


# -----------------------------------------------------------------------------
# Euclidean Distance for Candidate Selection (Step 7)
# -----------------------------------------------------------------------------
# Used to find players whose attributes match a target role profile.

def calculate_euclidean_distance(
    player_attrs: Dict[str, float],
    target_attrs: Dict[str, float],
    weights: Optional[Dict[str, float]] = None
) -> float:
    """
    Calculate weighted Euclidean distance between player and target profile.

    Distance(P, R) = sqrt(Σ w_i × (A_{P,i} - A_{R,i})^2)

    Lower distance = better match for the target role.

    Args:
        player_attrs: Player's attribute values (e.g., {'Tackling': 14, 'Passing': 12})
        target_attrs: Target role's ideal attributes (same keys)
        weights: Optional attribute weights (default 1.0 for all)

    Returns:
        Euclidean distance (lower = better match)
    """
    if weights is None:
        weights = {}

    total = 0.0
    for attr, target_val in target_attrs.items():
        player_val = player_attrs.get(attr, 0)
        w = weights.get(attr, 1.0)
        total += w * ((player_val - target_val) ** 2)

    return total ** 0.5


# -----------------------------------------------------------------------------
# Retraining Efficiency Ratio (RER) (Step 7)
# -----------------------------------------------------------------------------
# Evaluates how efficiently a player's CA is used in the target role.

def calculate_retraining_efficiency(
    player_attrs: Dict[str, float],
    target_role_weights: Dict[str, float],
    total_ca: float
) -> float:
    """
    Calculate Retraining Efficiency Ratio.

    RER = (Sum of Weighted Attributes for Target Role) / Total CA Usage

    Higher RER = player's attributes are more suited to the new role.
    Low RER means a lot of CA is "wasted" on irrelevant attributes.

    Args:
        player_attrs: Player's attribute values
        target_role_weights: Weight of each attribute for target role (0.0 to 1.0)
        total_ca: Player's total Current Ability

    Returns:
        Efficiency ratio (0.0 to 1.0+)
    """
    if total_ca <= 0:
        return 0.0

    weighted_sum = 0.0
    for attr, weight in target_role_weights.items():
        player_val = player_attrs.get(attr, 0)
        weighted_sum += player_val * weight

    return weighted_sum / total_ca


def estimate_retraining_weeks(
    from_pos: str,
    to_pos: str,
    age: int,
    versatility: float = 0.5,
    match_exposure: str = 'cup_subs'
) -> int:
    """
    Estimate weeks to reach Accomplished familiarity in target position.

    T = (Base_Time × (1 + Age_Penalty)) / (Versatility_Factor × Match_Exposure)

    Args:
        from_pos: Current position
        to_pos: Target position
        age: Player age
        versatility: Inferred versatility (0.0 to 1.0)
        match_exposure: 'training_only', 'cup_subs', 'regular_starter'

    Returns:
        Estimated weeks to reach Accomplished (15+ familiarity)
    """
    # Get difficulty class
    difficulty = get_retraining_difficulty(from_pos, to_pos)
    base_weeks = (difficulty['weeks_min'] + difficulty['weeks_max']) / 2

    # Age penalty
    plasticity = get_age_plasticity(age)
    age_penalty = 1.0 - plasticity  # Lower plasticity = higher penalty

    # Versatility factor (0.5 to 1.5)
    versatility_factor = 0.5 + versatility

    # Match exposure multiplier
    exposure_multipliers = {
        'training_only': 0.5,
        'cup_subs': 1.0,
        'regular_starter': 2.0,
    }
    match_mult = exposure_multipliers.get(match_exposure, 1.0)

    # Calculate final estimate
    weeks = (base_weeks * (1 + age_penalty)) / (versatility_factor * match_mult)

    return max(4, int(weeks))  # Minimum 4 weeks


# =============================================================================
# PLAYER REMOVAL MODEL PARAMETERS (Step 8 Research)
# =============================================================================
# Multi-factor player removal decision model
# Reference: docs/new-research/08-RESULTS-player-removal.md

# -----------------------------------------------------------------------------
# Contribution Score Weights (Step 8)
# -----------------------------------------------------------------------------
# Formula: CS = (EA × 0.45) + (Perf × 0.25) + (Rel × 0.20) + (Scar × 0.10)
# Used to calculate each player's overall contribution to the squad.

CONTRIBUTION_WEIGHTS: Dict[str, float] = {
    'effective_ability': 0.45,  # Tactical fit, not raw CA
    'performance': 0.25,        # Actual stats (avg rating, xG, etc.)
    'reliability': 0.20,        # Hidden attrs: Consistency, Important Matches
    'scarcity': 0.10,           # Position scarcity, left-footed, etc.
}


# -----------------------------------------------------------------------------
# Position-Specific Aging Curves (Step 8)
# -----------------------------------------------------------------------------
# Based on biological performance data and match analysis.
# Peak is a plateau, not a point. Decline accelerates after 'decline' age.
#
# Physical positions (wingers, fullbacks) decline faster.
# Cognitive positions (CB, GK) retain value longer.

AGING_CURVES: Dict[str, Dict[str, int]] = {
    'GK': {'peak_start': 29, 'peak_end': 34, 'decline': 35},
    'DC': {'peak_start': 27, 'peak_end': 31, 'decline': 32},
    'DL': {'peak_start': 25, 'peak_end': 29, 'decline': 30},
    'DR': {'peak_start': 25, 'peak_end': 29, 'decline': 30},
    'WB': {'peak_start': 25, 'peak_end': 29, 'decline': 30},
    'DM': {'peak_start': 26, 'peak_end': 30, 'decline': 32},
    'MC': {'peak_start': 26, 'peak_end': 30, 'decline': 32},
    'AM': {'peak_start': 24, 'peak_end': 28, 'decline': 30},
    'WG': {'peak_start': 24, 'peak_end': 28, 'decline': 29},  # Wingers decline earliest
    'ST': {'peak_start': 25, 'peak_end': 29, 'decline': 31},
}


def get_aging_curve(position: str) -> Dict[str, int]:
    """
    Get aging curve for a position.

    Args:
        position: Position key (e.g., 'DC', 'AM', 'ST')

    Returns:
        Dict with 'peak_start', 'peak_end', 'decline' ages
    """
    # Normalize position format
    pos_key = position.upper()
    if pos_key.startswith('D(C'):
        pos_key = 'DC'
    elif pos_key.startswith('D(L') or pos_key.startswith('D(R'):
        pos_key = 'DL'
    elif pos_key.startswith('WB'):
        pos_key = 'WB'
    elif pos_key.startswith('DM'):
        pos_key = 'DM'
    elif pos_key.startswith('M('):
        pos_key = 'MC'
    elif pos_key.startswith('AM'):
        pos_key = 'AM'
    elif 'ST' in pos_key or 'STRIKER' in pos_key:
        pos_key = 'ST'

    return AGING_CURVES.get(pos_key, AGING_CURVES['MC'])  # Default to MC


def get_career_phase(age: int, position: str) -> str:
    """
    Determine player's career phase based on age and position.

    Args:
        age: Player age
        position: Position key

    Returns:
        Phase: 'rising', 'peak', or 'declining'
    """
    curve = get_aging_curve(position)

    if age < curve['peak_start']:
        return 'rising'
    elif age <= curve['peak_end']:
        return 'peak'
    else:
        return 'declining'


def get_years_until_decline(age: int, position: str) -> int:
    """
    Calculate years until decline phase begins.

    Args:
        age: Player age
        position: Position key

    Returns:
        Years until decline (0 if already declining)
    """
    curve = get_aging_curve(position)
    return max(0, curve['decline'] - age)


# -----------------------------------------------------------------------------
# Wage Efficiency Thresholds (Step 8)
# -----------------------------------------------------------------------------
# Based on 30-30-30-10 wage structure principle.
# Ratio = Actual Wage / Target Wage for tier

WAGE_EFFICIENCY_THRESHOLDS: Dict[str, float] = {
    'efficient': 0.80,          # Earning < 80% of tier cap = high value
    'fair': 1.00,               # Earning tier cap = fair value
    'overpaid': 1.25,           # Earning 125% of tier cap = inefficient
    'wage_dump': 1.50,          # Earning 150% of tier cap = urgent sell
}


# -----------------------------------------------------------------------------
# 30-30-30-10 Wage Structure (Step 8)
# -----------------------------------------------------------------------------
# Optimal wage distribution for a healthy squad:
# - Top 4 (Key Players): 30% of budget
# - Next 7 (First Team): 30% of budget
# - Next 11 (Rotation): 30% of budget
# - Remaining (Youth/Backup): 10% of budget

WAGE_TIERS: Dict[str, Dict[str, any]] = {
    'key': {
        'slots': 4,
        'budget_share': 0.30,
        'description': 'Key Players (Top 4)',
    },
    'first_team': {
        'slots': 7,
        'budget_share': 0.30,
        'description': 'First Team (Next 7)',
    },
    'rotation': {
        'slots': 11,
        'budget_share': 0.30,
        'description': 'Rotation (Next 11)',
    },
    'backup': {
        'slots': 5,
        'budget_share': 0.10,
        'description': 'Youth/Backup',
    },
}


def get_wage_tier(contribution_rank: int) -> str:
    """
    Get wage tier based on player's contribution rank.

    Args:
        contribution_rank: Player's rank by contribution score (1 = best)

    Returns:
        Tier name: 'key', 'first_team', 'rotation', or 'backup'
    """
    if contribution_rank <= 4:
        return 'key'
    elif contribution_rank <= 11:
        return 'first_team'
    elif contribution_rank <= 22:
        return 'rotation'
    else:
        return 'backup'


def calculate_target_wage(
    contribution_rank: int,
    total_wage_budget: float
) -> float:
    """
    Calculate target wage for a player based on their contribution rank.

    Args:
        contribution_rank: Player's rank by contribution score
        total_wage_budget: Total weekly wage budget

    Returns:
        Target weekly wage for this tier
    """
    tier = get_wage_tier(contribution_rank)
    tier_config = WAGE_TIERS[tier]

    tier_budget = total_wage_budget * tier_config['budget_share']
    target_wage = tier_budget / tier_config['slots']

    return target_wage


def calculate_wage_efficiency_ratio(
    actual_wage: float,
    contribution_rank: int,
    total_wage_budget: float
) -> float:
    """
    Calculate wage efficiency ratio.

    Ratio > 1.0 means overpaid relative to contribution.
    Ratio < 1.0 means underpaid (high value).

    Args:
        actual_wage: Player's actual weekly wage
        contribution_rank: Player's rank by contribution score
        total_wage_budget: Total weekly wage budget

    Returns:
        Wage efficiency ratio
    """
    target = calculate_target_wage(contribution_rank, total_wage_budget)
    if target <= 0:
        return 1.0
    return actual_wage / target


def get_wage_recommendation(wage_ratio: float) -> str:
    """
    Get wage-based action recommendation.

    Args:
        wage_ratio: Wage efficiency ratio

    Returns:
        Recommendation string
    """
    if wage_ratio < WAGE_EFFICIENCY_THRESHOLDS['efficient']:
        return 'High Value Asset'
    elif wage_ratio <= WAGE_EFFICIENCY_THRESHOLDS['fair']:
        return 'Fair Value'
    elif wage_ratio <= WAGE_EFFICIENCY_THRESHOLDS['overpaid']:
        return 'Consider Selling'
    else:
        return 'Urgent Wage Dump'


# -----------------------------------------------------------------------------
# Reliability Coefficient (Step 8)
# -----------------------------------------------------------------------------
# R_coef = f(Consistency, ImportantMatches, 1/InjuryProneness)
# Players with R_coef < 0.7 are flagged as "High Risk"

RELIABILITY_THRESHOLD = 0.70


def calculate_reliability_coefficient(
    consistency: int = 10,
    important_matches: int = 10,
    pressure: int = 10,
    injury_proneness: int = 10
) -> float:
    """
    Calculate reliability coefficient from hidden attributes.

    Higher coefficient = more reliable player.

    Args:
        consistency: Consistency attribute (1-20)
        important_matches: Important Matches attribute (1-20)
        pressure: Pressure attribute (1-20)
        injury_proneness: Injury Proneness attribute (1-20)

    Returns:
        Reliability coefficient (0.0 to 1.0)
    """
    # Normalize to 0-1
    consistency_norm = consistency / 20.0
    imp_match_norm = important_matches / 20.0
    pressure_norm = pressure / 20.0

    # Injury penalty (higher proneness = lower reliability)
    injury_penalty = max(0, (injury_proneness - 10) / 20.0)

    # Weighted mix
    base_reliability = (
        consistency_norm * 0.4 +
        imp_match_norm * 0.3 +
        pressure_norm * 0.3
    )

    # Apply injury penalty
    return base_reliability * (1.0 - injury_penalty)


def is_high_risk_player(reliability_coef: float) -> bool:
    """Check if player is high risk based on reliability coefficient."""
    return reliability_coef < RELIABILITY_THRESHOLD


# -----------------------------------------------------------------------------
# Contribution Score Calculation (Step 8)
# -----------------------------------------------------------------------------

def calculate_contribution_score(
    effective_ability: float,
    performance_score: float,
    reliability_score: float,
    scarcity_score: float,
    position_multiplier: float = 1.0
) -> float:
    """
    Calculate overall contribution score (0-100).

    CS = (EA × 0.45 + Perf × 0.25 + Rel × 0.20 + Scar × 0.10) × PosMult

    Args:
        effective_ability: Tactical-fit ability score (0-100)
        performance_score: Statistical performance score (0-100)
        reliability_score: Hidden attribute reliability (0-100)
        scarcity_score: Position scarcity value (0-100)
        position_multiplier: Bonus for spine positions (1.0-1.15)

    Returns:
        Contribution score (0-100)
    """
    weights = CONTRIBUTION_WEIGHTS

    raw_score = (
        effective_ability * weights['effective_ability'] +
        performance_score * weights['performance'] +
        reliability_score * weights['reliability'] +
        scarcity_score * weights['scarcity']
    )

    return min(100.0, raw_score * position_multiplier)


# -----------------------------------------------------------------------------
# Future Value Assessment (Step 8)
# -----------------------------------------------------------------------------

def assess_asset_trajectory(
    age: int,
    position: str,
    ca: int,
    pa: int,
    recent_ca_growth: int = 0
) -> Dict[str, any]:
    """
    Assess player's asset trajectory (appreciating, stable, depreciating).

    Args:
        age: Player age
        position: Position key
        ca: Current Ability
        pa: Potential Ability
        recent_ca_growth: CA growth in last 12 months

    Returns:
        Dict with phase, trend, headroom, action timing
    """
    curve = get_aging_curve(position)
    phase = get_career_phase(age, position)
    years_until_decline = get_years_until_decline(age, position)
    pa_headroom = max(0, pa - ca)

    # Determine value trend
    if phase == 'rising':
        if recent_ca_growth < 2 and pa_headroom > 20:
            value_trend = 'stagnating'  # False prospect
        else:
            value_trend = 'increasing'
    elif phase == 'peak':
        value_trend = 'stable'
    else:
        value_trend = 'decreasing'

    # Action timing recommendation
    action_timing = 'keep'

    # Sell at end of peak for physical positions
    physical_positions = {'WG', 'AM', 'DL', 'DR', 'WB'}
    pos_key = position.upper()[:2]
    if pos_key in physical_positions and age == curve['peak_end']:
        action_timing = 'sell_peak_value'
    elif phase == 'declining':
        action_timing = 'sell_immediate'
    elif value_trend == 'stagnating' and pa_headroom > 30:
        action_timing = 'sell_speculative'  # Sell while PA looks high

    return {
        'current_phase': phase,
        'value_trend': value_trend,
        'pa_headroom': pa_headroom,
        'years_to_peak': max(0, curve['peak_start'] - age),
        'years_until_decline': years_until_decline,
        'recommended_action_timing': action_timing,
    }


# =============================================================================
# MATCH IMPORTANCE PARAMETERS (Step 9 Research - AMICS)
# =============================================================================
# Automated Match Importance Classification System
# Reference: docs/new-research/09-RESULTS-match-importance.md

# -----------------------------------------------------------------------------
# Base Importance Table (Step 9)
# -----------------------------------------------------------------------------
# Static values based on competition prestige and stage.
# Scale: 0-100

BASE_IMPORTANCE: Dict[Tuple[str, str], int] = {
    # League matches
    ('league', 'title_race'): 100,      # Last 10 games, title contention
    ('league', 'relegation'): 100,      # Last 10 games, relegation battle
    ('league', 'contention'): 80,       # Regular season, top 4 race
    ('league', 'mid_table'): 60,        # Mid-table, moderate stakes
    ('league', 'dead_rubber'): 20,      # Mathematically fixed position

    # Champions League
    ('champions_league', 'final'): 100,
    ('champions_league', 'knockout'): 95,  # R16+
    ('champions_league', 'group_open'): 85,
    ('champions_league', 'group_safe'): 50,  # Qualified/eliminated

    # Domestic Cup (Major - FA Cup, League Cup Final)
    ('domestic_cup', 'final'): 100,
    ('domestic_cup', 'semi_final'): 95,
    ('domestic_cup', 'quarter_final'): 75,
    ('domestic_cup', 'early'): 40,

    # Secondary Cup (EFL Trophy, etc.)
    ('secondary_cup', 'late'): 70,
    ('secondary_cup', 'early'): 30,

    # Europa League / Conference League
    ('europa', 'knockout'): 85,
    ('europa', 'group'): 70,
    ('conference', 'knockout'): 75,
    ('conference', 'group'): 55,

    # Friendlies
    ('friendly', 'any'): 10,
    ('friendly', 'preseason'): 15,
}


def get_base_importance(competition: str, stage: str) -> int:
    """
    Get base importance score for a competition/stage combination.

    Args:
        competition: Competition type ('league', 'champions_league', etc.)
        stage: Stage within competition ('title_race', 'knockout', etc.)

    Returns:
        Base importance score (0-100)
    """
    return BASE_IMPORTANCE.get((competition.lower(), stage.lower()), 50)


# -----------------------------------------------------------------------------
# Opponent Strength Modifiers (Step 9)
# -----------------------------------------------------------------------------
# Based on relative strength ratio: Opponent Rep / User Rep

OPPONENT_MODIFIERS: Dict[str, Dict[str, any]] = {
    'titan': {
        'modifier': 1.2,
        'threshold_min': 1.3,
        'description': 'Significantly stronger opponent',
    },
    'superior': {
        'modifier': 1.1,
        'threshold_min': 1.1,
        'threshold_max': 1.3,
        'description': 'Stronger opponent',
    },
    'peer': {
        'modifier': 1.0,
        'threshold_min': 0.9,
        'threshold_max': 1.1,
        'description': 'Similar strength opponent',
    },
    'inferior': {
        'modifier': 0.8,
        'threshold_min': 0.6,
        'threshold_max': 0.9,
        'description': 'Weaker opponent',
    },
    'minnow': {
        'modifier': 0.6,
        'threshold_max': 0.6,
        'description': 'Significantly weaker opponent',
    },
}


def classify_opponent_strength(relative_strength: float) -> str:
    """
    Classify opponent based on relative strength ratio.

    Args:
        relative_strength: Opponent reputation / User reputation

    Returns:
        Classification: 'titan', 'superior', 'peer', 'inferior', 'minnow'
    """
    if relative_strength > 1.3:
        return 'titan'
    elif relative_strength > 1.1:
        return 'superior'
    elif relative_strength > 0.9:
        return 'peer'
    elif relative_strength > 0.6:
        return 'inferior'
    else:
        return 'minnow'


def get_opponent_modifier(relative_strength: float) -> float:
    """
    Get opponent modifier based on relative strength.

    Args:
        relative_strength: Opponent reputation / User reputation

    Returns:
        Modifier value (0.6 to 1.2)
    """
    classification = classify_opponent_strength(relative_strength)
    return OPPONENT_MODIFIERS[classification]['modifier']


# -----------------------------------------------------------------------------
# Schedule Context Modifiers (Step 9)
# -----------------------------------------------------------------------------
# Based on physiological constraints (72-hour rule, ACWR)

SCHEDULE_MODIFIERS: Dict[str, float] = {
    'next_high_2_days': 0.6,    # Next high-importance match in 2 days
    'next_high_3_days': 0.7,    # Next high-importance match in 3 days
    'next_high_4_days': 0.9,    # Next high-importance match in 4 days
    '3rd_match_in_7_days': 0.8, # Fixture congestion (ACWR concern)
    'fresh_7_plus_days': 1.1,   # Well rested (7+ days since last)
    'standard': 1.0,            # Normal schedule
}


def get_schedule_modifier(
    days_to_next: int,
    next_match_importance: int,
    matches_in_last_7_days: int = 0,
    days_since_last: int = 3
) -> Tuple[float, str]:
    """
    Calculate schedule modifier based on upcoming fixtures.

    Args:
        days_to_next: Days until next match
        next_match_importance: Base importance of next match (0-100)
        matches_in_last_7_days: Number of matches played in last 7 days
        days_since_last: Days since last match

    Returns:
        Tuple of (modifier, reason_string)
    """
    reasons = []
    modifier = 1.0

    # 72-hour rule: If next match is high importance and soon
    if next_match_importance >= 80:
        if days_to_next <= 2:
            modifier *= SCHEDULE_MODIFIERS['next_high_2_days']
            reasons.append(f'High-importance match in {days_to_next} days (×0.6)')
        elif days_to_next <= 3:
            modifier *= SCHEDULE_MODIFIERS['next_high_3_days']
            reasons.append(f'High-importance match in {days_to_next} days (×0.7)')
        elif days_to_next <= 4:
            modifier *= SCHEDULE_MODIFIERS['next_high_4_days']
            reasons.append(f'High-importance match in {days_to_next} days (×0.9)')

    # ACWR concern: 3rd match in 7 days
    if matches_in_last_7_days >= 2:
        modifier *= SCHEDULE_MODIFIERS['3rd_match_in_7_days']
        reasons.append('Fixture congestion (3rd match in 7 days) (×0.8)')

    # Freshness bonus
    if days_since_last >= 7 and modifier >= 1.0:
        modifier *= SCHEDULE_MODIFIERS['fresh_7_plus_days']
        reasons.append('Well rested (7+ days since last) (×1.1)')

    reason = '; '.join(reasons) if reasons else 'Standard schedule'
    return modifier, reason


# -----------------------------------------------------------------------------
# Contextual Bonuses (Step 9)
# -----------------------------------------------------------------------------
# Additive bonuses for special circumstances

CONTEXT_BONUSES: Dict[str, int] = {
    'rivalry': 20,          # Derby/rivalry match
    'form_correction': 15,  # 3+ consecutive losses
    'cup_run': 10,          # QF+ with cup objective
    'title_decider': 25,    # Could win/lose title this match
    'relegation_six_pointer': 20,  # Direct relegation rival
}


# -----------------------------------------------------------------------------
# FIS Classification Thresholds (Step 9)
# -----------------------------------------------------------------------------
# Maps continuous FIS score to discrete importance levels

FIS_THRESHOLDS: Dict[str, int] = {
    'high': 85,      # FIS >= 85 → High importance
    'medium': 50,    # FIS >= 50 → Medium importance
    'low': 0,        # FIS < 50 → Low importance (or Sharpness)
}


def classify_importance_level(fis: float) -> str:
    """
    Classify FIS score into importance level.

    Args:
        fis: Final Importance Score

    Returns:
        Level: 'High', 'Medium', or 'Low'
    """
    if fis >= FIS_THRESHOLDS['high']:
        return 'High'
    elif fis >= FIS_THRESHOLDS['medium']:
        return 'Medium'
    else:
        return 'Low'


# -----------------------------------------------------------------------------
# Manager Profiles (Step 9)
# -----------------------------------------------------------------------------
# User configuration presets that adjust competition weights

MANAGER_PROFILES: Dict[str, Dict[str, any]] = {
    'balanced': {
        'name': 'The Pragmatist',
        'description': 'Balanced approach to all competitions',
        'weights': {
            'league': 1.0,
            'champions_league': 1.0,
            'europa': 1.0,
            'domestic_cup': 1.0,
            'secondary_cup': 0.8,
            'friendly': 0.5,
        },
        'rotation_tolerance': 'medium',
    },
    'league_focused': {
        'name': 'The Title Hunter',
        'description': 'Prioritizes league success above all',
        'weights': {
            'league': 1.2,
            'champions_league': 0.9,
            'europa': 0.7,
            'domestic_cup': 0.8,
            'secondary_cup': 0.5,
            'friendly': 0.3,
        },
        'rotation_tolerance': 'high',
    },
    'cup_specialist': {
        'name': 'The Glory Hunter',
        'description': 'Prioritizes cup competitions for trophies',
        'weights': {
            'league': 0.9,
            'champions_league': 1.2,
            'europa': 1.1,
            'domestic_cup': 1.2,
            'secondary_cup': 1.0,
            'friendly': 0.5,
        },
        'rotation_tolerance': 'low',
    },
    'youth_developer': {
        'name': 'The Architect',
        'description': 'Prioritizes youth development opportunities',
        'weights': {
            'league': 1.0,
            'champions_league': 1.0,
            'europa': 0.8,
            'domestic_cup': 0.7,
            'secondary_cup': 0.5,
            'friendly': 1.0,  # Higher for youth minutes
        },
        'rotation_tolerance': 'very_high',
    },
    'survival': {
        'name': 'The Firefighter',
        'description': 'Relegation battle - league is everything',
        'weights': {
            'league': 1.3,
            'champions_league': 0.6,
            'europa': 0.5,
            'domestic_cup': 0.6,
            'secondary_cup': 0.3,
            'friendly': 0.2,
        },
        'rotation_tolerance': 'medium',
    },
}


def get_manager_profile(profile_id: str) -> Dict[str, any]:
    """Get manager profile by ID."""
    return MANAGER_PROFILES.get(profile_id, MANAGER_PROFILES['balanced'])


def get_profile_weight(profile_id: str, competition: str) -> float:
    """Get competition weight for a manager profile."""
    profile = get_manager_profile(profile_id)
    return profile['weights'].get(competition, 1.0)


# -----------------------------------------------------------------------------
# Sharpness Detection Parameters (Step 9)
# -----------------------------------------------------------------------------

SHARPNESS_DETECTION: Dict[str, any] = {
    'min_rusty_players': 3,      # At least 3 key players with low sharpness
    'sharpness_threshold': 70,   # Players below 70% are "rusty"
    'fis_threshold': 50,         # Only suggest for low-importance matches
    'min_recovery_days': 4,      # Need recovery time after sharpness match
}
