"""
FM26 Player Role Rating Algorithm
=================================

Calculates a player's suitability for a specific position and role by combining:
1. Position Base Weights (FM Arena match engine testing - 60%)
2. Role Modifiers (In-game Key/Important attributes - 35%)
3. Consensus Adjustments (AI research convergence - 5%)

Usage:
    rating = calculate_role_rating(player_attrs, 'ST', 'Channel Forward', 'IP')
"""

import json
import os

# =============================================================================
# POSITION WEIGHTS (from FM Arena testing)
# =============================================================================

POSITION_WEIGHTS = {
    'GK': {
        'Agility': 0.140, 'Reflexes': 0.130, 'Aerial Reach': 0.110,
        'One On Ones': 0.095, 'Handling': 0.085, 'Positioning': 0.080,
        'Communication': 0.070, 'Decisions': 0.065, 'Throwing': 0.060,
        'Composure': 0.045, 'Kicking': 0.025, 'Anticipation': 0.020,
        'Concentration': 0.020, 'First Touch': 0.020, 'Passing': 0.015,
        'Command Of Area': 0.010, 'Rushing Out (Tendency)': 0.010,
    },
    'D(C)': {
        'Jumping Reach': 0.115, 'Pace': 0.095, 'Acceleration': 0.085,
        'Tackling': 0.080, 'Positioning': 0.080, 'Anticipation': 0.075,
        'Concentration': 0.065, 'Marking': 0.060, 'Heading': 0.055,
        'Strength': 0.050, 'Work Rate': 0.035, 'Composure': 0.030,
        'Decisions': 0.025, 'Bravery': 0.025, 'Passing': 0.025,
        'First Touch': 0.020, 'Aggression': 0.020, 'Determination': 0.020,
        'Technique': 0.020, 'Stamina': 0.020,
    },
    'D(L)': {  # Fullback Left
        'Pace': 0.130, 'Acceleration': 0.095, 'Jumping Reach': 0.080,
        'Tackling': 0.075, 'Anticipation': 0.070, 'Stamina': 0.065,
        'Concentration': 0.060, 'Crossing': 0.055, 'Positioning': 0.050,
        'Work Rate': 0.050, 'Composure': 0.035, 'Dribbling': 0.035,
        'Marking': 0.030, 'Passing': 0.025, 'Decisions': 0.025,
        'Teamwork': 0.025, 'First Touch': 0.020, 'Technique': 0.020,
        'Agility': 0.020, 'Strength': 0.020, 'Balance': 0.015,
    },
    'D(R)': {  # Fullback Right (same as Left)
        'Pace': 0.130, 'Acceleration': 0.095, 'Jumping Reach': 0.080,
        'Tackling': 0.075, 'Anticipation': 0.070, 'Stamina': 0.065,
        'Concentration': 0.060, 'Crossing': 0.055, 'Positioning': 0.050,
        'Work Rate': 0.050, 'Composure': 0.035, 'Dribbling': 0.035,
        'Marking': 0.030, 'Passing': 0.025, 'Decisions': 0.025,
        'Teamwork': 0.025, 'First Touch': 0.020, 'Technique': 0.020,
        'Agility': 0.020, 'Strength': 0.020, 'Balance': 0.015,
    },
    'WB(L)': {  # Wingback Left
        'Pace': 0.120, 'Acceleration': 0.115, 'Stamina': 0.090,
        'Crossing': 0.070, 'Jumping Reach': 0.065, 'Composure': 0.060,
        'Work Rate': 0.055, 'Vision': 0.050, 'Tackling': 0.045,
        'Dribbling': 0.045, 'Anticipation': 0.035, 'Positioning': 0.030,
        'Decisions': 0.030, 'Passing': 0.025, 'Technique': 0.025,
        'Off The Ball': 0.025, 'First Touch': 0.025, 'Determination': 0.020,
        'Marking': 0.020, 'Agility': 0.020, 'Balance': 0.015, 'Flair': 0.015,
    },
    'WB(R)': {  # Wingback Right (same as Left)
        'Pace': 0.120, 'Acceleration': 0.115, 'Stamina': 0.090,
        'Crossing': 0.070, 'Jumping Reach': 0.065, 'Composure': 0.060,
        'Work Rate': 0.055, 'Vision': 0.050, 'Tackling': 0.045,
        'Dribbling': 0.045, 'Anticipation': 0.035, 'Positioning': 0.030,
        'Decisions': 0.030, 'Passing': 0.025, 'Technique': 0.025,
        'Off The Ball': 0.025, 'First Touch': 0.025, 'Determination': 0.020,
        'Marking': 0.020, 'Agility': 0.020, 'Balance': 0.015, 'Flair': 0.015,
    },
    'DM': {
        'Acceleration': 0.120, 'Anticipation': 0.095, 'Tackling': 0.085,
        'Positioning': 0.080, 'Composure': 0.070, 'Passing': 0.065,
        'Stamina': 0.060, 'Jumping Reach': 0.055, 'Concentration': 0.050,
        'First Touch': 0.045, 'Decisions': 0.035, 'Marking': 0.030,
        'Dribbling': 0.030, 'Long Shots': 0.025, 'Strength': 0.025,
        'Work Rate': 0.025, 'Teamwork': 0.025, 'Vision': 0.020,
        'Pace': 0.020, 'Aggression': 0.020, 'Technique': 0.020,
    },
    'M(C)': {
        'Anticipation': 0.095, 'Acceleration': 0.090, 'Composure': 0.085,
        'Stamina': 0.080, 'Pace': 0.075, 'Passing': 0.070,
        'First Touch': 0.065, 'Decisions': 0.060, 'Dribbling': 0.055,
        'Work Rate': 0.050, 'Crossing': 0.035, 'Jumping Reach': 0.030,
        'Strength': 0.025, 'Technique': 0.025, 'Off The Ball': 0.025,
        'Positioning': 0.025, 'Vision': 0.020, 'Tackling': 0.020,
        'Teamwork': 0.020, 'Concentration': 0.020, 'Balance': 0.015,
        'Agility': 0.015,
    },
    'M(L)': {  # Wide Midfielder Left
        'Pace': 0.125, 'Dribbling': 0.095, 'Acceleration': 0.090,
        'Stamina': 0.080, 'Crossing': 0.070, 'Composure': 0.065,
        'Vision': 0.060, 'Jumping Reach': 0.050, 'Work Rate': 0.045,
        'Technique': 0.040, 'Agility': 0.040, 'Off The Ball': 0.035,
        'First Touch': 0.030, 'Positioning': 0.025, 'Balance': 0.025,
        'Passing': 0.025, 'Tackling': 0.025, 'Flair': 0.020,
        'Anticipation': 0.020, 'Finishing': 0.020, 'Concentration': 0.015,
    },
    'M(R)': {  # Wide Midfielder Right (same as Left)
        'Pace': 0.125, 'Dribbling': 0.095, 'Acceleration': 0.090,
        'Stamina': 0.080, 'Crossing': 0.070, 'Composure': 0.065,
        'Vision': 0.060, 'Jumping Reach': 0.050, 'Work Rate': 0.045,
        'Technique': 0.040, 'Agility': 0.040, 'Off The Ball': 0.035,
        'First Touch': 0.030, 'Positioning': 0.025, 'Balance': 0.025,
        'Passing': 0.025, 'Tackling': 0.025, 'Flair': 0.020,
        'Anticipation': 0.020, 'Finishing': 0.020, 'Concentration': 0.015,
    },
    'AM(C)': {
        'Pace': 0.100, 'Acceleration': 0.095, 'Vision': 0.085,
        'Passing': 0.080, 'Composure': 0.075, 'Technique': 0.070,
        'First Touch': 0.065, 'Concentration': 0.060, 'Decisions': 0.055,
        'Dribbling': 0.050, 'Long Shots': 0.040, 'Flair': 0.035,
        'Off The Ball': 0.035, 'Jumping Reach': 0.030, 'Anticipation': 0.030,
        'Finishing': 0.025, 'Agility': 0.025, 'Balance': 0.020,
        'Work Rate': 0.015, 'Teamwork': 0.010,
    },
    'AM(L)': {  # Winger Left
        'Pace': 0.140, 'Acceleration': 0.120, 'Dribbling': 0.090,
        'Crossing': 0.075, 'Agility': 0.065, 'Anticipation': 0.060,
        'Technique': 0.055, 'Composure': 0.050, 'Jumping Reach': 0.045,
        'Off The Ball': 0.040, 'Balance': 0.040, 'First Touch': 0.035,
        'Finishing': 0.035, 'Flair': 0.030, 'Long Shots': 0.025,
        'Decisions': 0.025, 'Work Rate': 0.020, 'Stamina': 0.020,
        'Vision': 0.015, 'Passing': 0.015,
    },
    'AM(R)': {  # Winger Right (same as Left)
        'Pace': 0.140, 'Acceleration': 0.120, 'Dribbling': 0.090,
        'Crossing': 0.075, 'Agility': 0.065, 'Anticipation': 0.060,
        'Technique': 0.055, 'Composure': 0.050, 'Jumping Reach': 0.045,
        'Off The Ball': 0.040, 'Balance': 0.040, 'First Touch': 0.035,
        'Finishing': 0.035, 'Flair': 0.030, 'Long Shots': 0.025,
        'Decisions': 0.025, 'Work Rate': 0.020, 'Stamina': 0.020,
        'Vision': 0.015, 'Passing': 0.015,
    },
    'ST': {
        'Finishing': 0.100, 'Pace': 0.095, 'Jumping Reach': 0.090,
        'Off The Ball': 0.085, 'Acceleration': 0.080, 'Composure': 0.075,
        'First Touch': 0.070, 'Concentration': 0.060, 'Anticipation': 0.055,
        'Balance': 0.050, 'Dribbling': 0.035, 'Technique': 0.030,
        'Decisions': 0.030, 'Heading': 0.030, 'Strength': 0.025,
        'Vision': 0.025, 'Passing': 0.020, 'Determination': 0.020,
        'Agility': 0.015, 'Work Rate': 0.010,
    },
}

# Alias for positions with L/R variants
POSITION_WEIGHTS['D(L/R)'] = POSITION_WEIGHTS['D(L)']
POSITION_WEIGHTS['WB(L/R)'] = POSITION_WEIGHTS['WB(L)']
POSITION_WEIGHTS['M(L/R)'] = POSITION_WEIGHTS['M(L)']
POSITION_WEIGHTS['AM(L/R)'] = POSITION_WEIGHTS['AM(L)']


# =============================================================================
# ROLE ATTRIBUTES (In-game Key/Important)
# =============================================================================

ROLE_ATTRIBUTES = {}

def load_role_attributes():
    global ROLE_ATTRIBUTES
    try:
        json_path = os.path.join(os.path.dirname(__file__), 'docs', 'FM26_Roles_Attributes.json')
        if not os.path.exists(json_path):
            json_path = os.path.join('docs', 'FM26_Roles_Attributes.json')
            
        if os.path.exists(json_path):
            with open(json_path, 'r') as f:
                data = json.load(f)
                ROLE_ATTRIBUTES.clear()
                ROLE_ATTRIBUTES.update(data)
                return True
    except Exception as e:
        print(f"Warning: Could not load FM26_Roles_Attributes.json: {e}")
        return False

# =============================================================================
# CONSENSUS BONUSES (where AI sources agreed but in-game doesn't flag)
# =============================================================================

CONSENSUS_BONUSES = {
    ('D(C)', 'Ball-Playing Centre-Back'): {
        'Technique': 0.020,
        'Vision': 0.020,
        'First Touch': 0.015,
        'Decisions': 0.015,
        'Concentration': 0.015,
    },
    ('ST', 'Central Outlet Centre Forward'): {
        'Acceleration': 0.030,
        'Pace': 0.030,
    },
    ('AM(C)', 'Attacking Midfielder'): {
        'Work Rate': 0.015,
    },
}


# =============================================================================
# THRESHOLDS (minimum viable attribute levels)
# =============================================================================

THRESHOLDS = {
    'Channel Forward': {
        'Acceleration': 14,
        'Pace': 14,
        'Off The Ball': 13,
    },
    'Ball-Playing Centre-Back': {
        'Passing': 14,
        'First Touch': 13,
        'Composure': 13,
    },
    'Central Outlet Centre Forward': {
        'Acceleration': 14,
        'Pace': 14,
        'Anticipation': 13,
    },
    'Deep-Lying Playmaker': {
        'Vision': 14,
        'Passing': 14,
        'First Touch': 13,
    },
    'Inside Forward': {
        'Dribbling': 14,
        'Finishing': 14,
        'Acceleration': 14,
    },
    'Winger': {
        'Pace': 15,
        'Acceleration': 15,
        'Dribbling': 14,
    },
    'Centre Forward': {
        'Finishing': 14,
        'Off The Ball': 13,
    },
}


# =============================================================================
# ATTRIBUTE NAME MAPPING
# Maps attribute names in roles.json to actual column names in player data CSV
# Some FM tools (FMRTE) use different naming conventions
# =============================================================================

ATTRIBUTE_NAME_MAP = {
    'Work Rate': 'Workrate',
    'Jumping Reach': 'Jumping',
    'Aerial Reach': 'Aerial Ability',
    'Rushing Out (Tendency)': 'Rushing Out',
}


def get_attribute_value(player_attributes, attribute_name):
    """
    Get attribute value from player data, handling name mapping.

    Args:
        player_attributes: Dict of player data
        attribute_name: Standard attribute name (from roles.json)

    Returns:
        Attribute value, or 10 (average) if not found
    """
    # First try the exact name
    if attribute_name in player_attributes:
        return player_attributes[attribute_name]

    # Try mapped name
    mapped_name = ATTRIBUTE_NAME_MAP.get(attribute_name)
    if mapped_name and mapped_name in player_attributes:
        return player_attributes[mapped_name]

    # Fall back to average value
    return 10


# =============================================================================
# CALCULATION FUNCTIONS
# =============================================================================

def normalize_attribute(value, min_val=1, max_val=20):
    """
    Normalize attribute value to 0-1 scale.

    Handles common data issues:
    - Dollar signs from FMRTE export (Balance column bug: "$14" instead of "14")
    - Currency formatting
    - Percentage signs
    - None/empty values
    """
    if value is None:
        value = 1

    # Handle string values with formatting characters
    if isinstance(value, str):
        # Strip common formatting: $, £, €, %, commas
        cleaned = value.replace('$', '').replace('£', '').replace('€', '')
        cleaned = cleaned.replace('%', '').replace(',', '').strip()
        try:
            value = float(cleaned) if cleaned else 1.0
        except ValueError:
            value = 1.0
    else:
        # Ensure value is numeric
        try:
            value = float(value)
        except (ValueError, TypeError):
            value = 1.0

    return (value - min_val) / (max_val - min_val)


def calculate_position_score(player_attributes, position):
    """
    Calculate position score based on FM Arena testing weights.
    
    Args:
        player_attributes: dict of {attribute_name: value (1-20)}
        position: string like 'D(C)', 'AM(L/R)', 'ST'
    
    Returns:
        float: Score from 0-100
    """
    # Handle position aliases
    if position in ['D(L)', 'D(R)']:
        position = 'D(L/R)'
    elif position in ['WB(L)', 'WB(R)']:
        position = 'WB(L/R)'
    elif position in ['M(L)', 'M(R)']:
        position = 'M(L/R)'
    elif position in ['AM(L)', 'AM(R)']:
        position = 'AM(L/R)'
    
    weights = POSITION_WEIGHTS.get(position, {})
    if not weights:
        # Fallback for DM(L/R) -> DM
        if position.startswith('DM'):
            weights = POSITION_WEIGHTS.get('DM', {})
        else:
            # Try removing (L)/(R) suffix if generic
            base_pos = position.split('(')[0]
            weights = POSITION_WEIGHTS.get(base_pos, {})
            if not weights:
                return 50.0
    
    weighted_sum = 0
    total_possible_weight = sum(weights.values())

    for attribute, weight in weights.items():
        player_value = get_attribute_value(player_attributes, attribute)
        normalized_value = normalize_attribute(player_value)
        weighted_sum += normalized_value * weight

    if total_possible_weight > 0:
        return (weighted_sum / total_possible_weight) * 100
    return 0


def calculate_role_score(player_attributes, role_key_attrs, role_important_attrs):
    """
    Calculate role score based on Key/Important attribute modifiers.
    """
    KEY_MULTIPLIER = 1.5
    IMPORTANT_MULTIPLIER = 1.2

    all_role_attrs = set(role_key_attrs) | set(role_important_attrs)

    if not all_role_attrs:
        return 50.0

    weighted_sum = 0
    total_weight = 0

    for attribute in all_role_attrs:
        player_value = get_attribute_value(player_attributes, attribute)
        normalized_value = normalize_attribute(player_value)

        if attribute in role_key_attrs:
            weight = KEY_MULTIPLIER
        elif attribute in role_important_attrs:
            weight = IMPORTANT_MULTIPLIER
        else:
            weight = 1.0

        weighted_sum += normalized_value * weight
        total_weight += weight

    return (weighted_sum / total_weight) * 100


def calculate_consensus_bonus(player_attributes, position, role,
                               role_key_attrs, role_important_attrs):
    """
    Calculate bonus for consensus attributes not flagged in role.
    """
    bonus = 0
    flagged_attrs = set(role_key_attrs) | set(role_important_attrs)

    consensus_attrs = CONSENSUS_BONUSES.get((position, role), {})

    for attribute, bonus_weight in consensus_attrs.items():
        if attribute not in flagged_attrs:
            player_value = get_attribute_value(player_attributes, attribute)
            normalized_value = normalize_attribute(player_value)
            bonus += normalized_value * bonus_weight

    if 'Balance' not in flagged_attrs and position != 'GK':
        player_balance = get_attribute_value(player_attributes, 'Balance')
        normalized_balance = normalize_attribute(player_balance)
        bonus += normalized_balance * 0.01

    return min(bonus * 100, 10)


def apply_threshold_penalties(rating, player_attributes, role):
    """
    Apply penalties when attributes fall below minimum thresholds.

    NOTE: Thresholds are tuned for elite players (top leagues). For lower-league
    squads, the penalties can be too harsh. We now apply a softer penalty curve
    and cap the total penalty at 20% (0.80 multiplier) instead of 50%.
    """
    thresholds = THRESHOLDS.get(role, {})
    penalty_multiplier = 1.0

    for attribute, min_value in thresholds.items():
        player_value = get_attribute_value(player_attributes, attribute)
        norm_val = 10
        try:
            # Handle string values with $ or other formatting
            if isinstance(player_value, str):
                cleaned = player_value.replace('$', '').replace(',', '').strip()
                norm_val = float(cleaned) if cleaned else 10
            else:
                norm_val = float(player_value)
        except (ValueError, TypeError):
            norm_val = 10

        if norm_val < min_value:
            shortfall = min_value - norm_val
            # Softer penalty: 2% per point below threshold (was 5%)
            penalty_multiplier *= (1 - 0.02 * shortfall)

    # Cap penalty at 20% reduction (was 50%)
    return rating * max(penalty_multiplier, 0.80)


def get_role_attributes(position, role, phase='IP'):
    """
    Get Key and Important attributes for a role from the loaded JSON.
    """
    if not ROLE_ATTRIBUTES:
        load_role_attributes()
    
    # Normalize position key for JSON lookup
    pos_key = position
    if position in ['D(L)', 'D(R)']: pos_key = 'D(L/R)'
    elif position in ['WB(L)', 'WB(R)']: pos_key = 'WB(L/R)'
    elif position in ['M(L)', 'M(R)']: pos_key = 'M (L/R)'
    elif position in ['AM(L)', 'AM(R)']: pos_key = 'AM (L/R)'
    elif position == 'M(C)': pos_key = 'M(C)'
    elif position == 'AM(C)': pos_key = 'AM (C)'
    elif position.startswith('DM'): pos_key = 'DM'
    
    # Try direct lookup
    phase_data = ROLE_ATTRIBUTES.get(phase, {})
    pos_data = phase_data.get(pos_key, {})
    
    # Try fuzzy lookup if direct fails (spacing issues in JSON)
    if not pos_data:
        target_norm = pos_key.replace(' ', '').replace('(', '').replace(')', '').replace('/', '').lower()
        for k, v in phase_data.items():
            k_norm = k.replace(' ', '').replace('(', '').replace(')', '').replace('/', '').lower()
            if k_norm == target_norm:
                pos_data = v
                break
    
    role_data = pos_data.get(role, {})
    return role_data.get('key', []), role_data.get('important', [])


def get_ca_adjustment(ca_value, reference_ca=100):
    """
    Calculate CA-based adjustment to differentiate players with similar attributes.

    Higher CA players generally have better hidden attributes (consistency,
    important matches, etc.) that aren't captured in visible attributes.

    Args:
        ca_value: Player's Current Ability (0-200 scale)
        reference_ca: Reference point for neutral adjustment (default 100)

    Returns:
        Multiplier (0.90 to 1.15) - higher CA = higher multiplier
    """
    if ca_value is None:
        return 1.0

    try:
        ca = float(ca_value)
    except (ValueError, TypeError):
        return 1.0

    # Calculate adjustment: +/- 0.5% per CA point difference from reference
    # Example: CA 120 = +10% bonus, CA 80 = -10% penalty
    adjustment = 1.0 + ((ca - reference_ca) * 0.005)

    # Clamp to reasonable range (±15%)
    return max(0.85, min(1.15, adjustment))


def calculate_role_rating(player_attributes, position, role, phase='IP',
                          apply_thresholds=True, apply_ca_adjustment=True):
    """
    Calculate a player's rating for a specific position/role (0-100 scale).

    The rating combines:
    - Position score (60%): Based on FM Arena match engine testing
    - Role score (35%): Based on Key/Important attributes for the role
    - Consensus bonus (5%): AI research convergence adjustments
    - CA adjustment: Higher CA players get a boost (hidden attributes factor)
    - Threshold penalties: For critical attributes below minimum levels
    """
    role_key, role_important = get_role_attributes(position, role, phase)

    position_score = calculate_position_score(player_attributes, position)
    role_score = calculate_role_score(player_attributes, role_key, role_important)
    consensus_bonus = calculate_consensus_bonus(
        player_attributes, position, role, role_key, role_important
    )

    final_rating = (position_score * 0.60) + (role_score * 0.35) + (consensus_bonus * 0.05)

    if apply_thresholds:
        final_rating = apply_threshold_penalties(final_rating, player_attributes, role)

    # Apply CA adjustment - higher CA players should rate higher
    if apply_ca_adjustment:
        ca_value = player_attributes.get('CA')
        ca_factor = get_ca_adjustment(ca_value)
        final_rating *= ca_factor

    return round(final_rating, 1)


def get_familiarity_column(position):
    """
    Map position key to familiarity column name in player data.

    Args:
        position: Position key like 'D(C)', 'AM(L)', 'ST'

    Returns:
        Column name like 'D(C)_Familiarity', 'Striker_Familiarity'
    """
    # Special cases where column name differs from position key
    if position == 'ST':
        return 'Striker_Familiarity'

    # DM variants all use same column (no DM(L)/DM(R) familiarity in data)
    if position.startswith('DM'):
        return 'DM_Familiarity'

    # Most positions follow pattern: Position_Familiarity
    # e.g., D(C) -> D(C)_Familiarity, AM(L) -> AM(L)_Familiarity
    return f'{position}_Familiarity'


def get_familiarity_factor(familiarity_rating):
    """
    Calculate multiplier based on position familiarity (1-20 scale).

    This is CRITICAL for ensuring players can't be selected for positions
    they're unfamiliar with, regardless of their attributes.

    FM26 Familiarity Tiers:
    - Natural (18-20): No penalty
    - Accomplished (13-17): Small penalty
    - Competent (10-12): Moderate penalty
    - Unconvincing (9): Significant penalty
    - Awkward (5-8): Large penalty
    - Ineffectual (1-4): Severe penalty - essentially unplayable
    """
    if familiarity_rating is None:
        return 0.10  # Unknown = treat as Ineffectual

    try:
        fam = float(familiarity_rating)
    except (ValueError, TypeError):
        return 0.10

    if fam >= 18:
        return 1.00  # Natural - full rating
    elif fam >= 15:
        return 0.95  # High Accomplished
    elif fam >= 13:
        return 0.90  # Accomplished
    elif fam >= 10:
        return 0.80  # Competent
    elif fam >= 8:
        return 0.60  # Awkward (high)
    elif fam >= 5:
        return 0.35  # Awkward (low)
    else:
        return 0.10  # Ineffectual - essentially unusable


def calculate_combined_rating(player_attributes, ip_pos, ip_role, oop_pos, oop_role):
    """
    Calculate combined weighted rating (0-200) for a tactic slot.

    IMPORTANT: Applies position familiarity penalties to ensure players
    can't be selected for positions they're unfamiliar with.

    Weights:
    - Defensive OOP (GK, DC, DM, WB, FB): 50% IP / 50% OOP
    - Attacking OOP (ST, AM, M, Winger): 70% IP / 30% OOP
    """
    # Calculate individual phase ratings (0-100)
    ip_rating = calculate_role_rating(player_attributes, ip_pos, ip_role, 'IP')
    oop_rating = calculate_role_rating(player_attributes, oop_pos, oop_role, 'OOP')

    # Get familiarity ratings and apply penalties
    ip_fam_col = get_familiarity_column(ip_pos)
    oop_fam_col = get_familiarity_column(oop_pos)

    ip_familiarity = player_attributes.get(ip_fam_col)
    oop_familiarity = player_attributes.get(oop_fam_col)

    ip_fam_factor = get_familiarity_factor(ip_familiarity)
    oop_fam_factor = get_familiarity_factor(oop_familiarity)

    # Apply familiarity penalties to each phase rating
    ip_rating *= ip_fam_factor
    oop_rating *= oop_fam_factor
    
    # Determine weights based on OOP position
    defensive_oop_positions = ['GK', 'D(C)', 'D(L)', 'D(R)', 'D(L/R)', 'WB(L)', 'WB(R)', 'WB(L/R)', 'DM', 'DM(L)', 'DM(R)']
    
    # Normalize oop_pos for check
    is_defensive = False
    if oop_pos in defensive_oop_positions:
        is_defensive = True
    elif oop_pos.startswith('D') or oop_pos.startswith('WB'):
        is_defensive = True
        
    if is_defensive:
        weight_ip = 0.5
        weight_oop = 0.5
    else:
        # Attacking/Midfield
        weight_ip = 0.7
        weight_oop = 0.3
        
    # Combined score (0-100)
    combined_100 = (ip_rating * weight_ip) + (oop_rating * weight_oop)
    
    # Return 0-200 scale
    return round(combined_100 * 2, 1)

# Helper to load data at module level
load_role_attributes()
