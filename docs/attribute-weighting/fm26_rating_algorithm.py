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

# =============================================================================
# POSITION WEIGHTS (from FM Arena testing)
# =============================================================================

POSITION_WEIGHTS = {
    'GK': {
        'Agility': 0.140, 'Reflexes': 0.130, 'Aerial Reach': 0.110,
        'One on Ones': 0.095, 'Handling': 0.085, 'Positioning': 0.080,
        'Communication': 0.070, 'Decisions': 0.065, 'Throwing': 0.060,
        'Composure': 0.045, 'Kicking': 0.025, 'Anticipation': 0.020,
        'Concentration': 0.020, 'First Touch': 0.020, 'Passing': 0.015,
        'Command of Area': 0.010, 'Rushing Out': 0.010,
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

ROLE_ATTRIBUTES = {
    # IN-POSSESSION ROLES
    ('IP', 'Goalkeeper'): {
        'key': ['Aerial Reach', 'Command of Area', 'Communication', 'Handling', 
                'Reflexes', 'Concentration', 'Positioning', 'Agility'],
        'important': ['Kicking', 'One on Ones', 'Throwing', 'Anticipation', 'Decisions'],
    },
    ('IP', 'Full-Back'): {
        'key': ['Marking', 'Tackling', 'Concentration', 'Anticipation', 
                'Positioning', 'Teamwork', 'Acceleration'],
        'important': ['Crossing', 'Dribbling', 'Passing', 'Technique', 'Decisions', 
                      'Work Rate', 'Agility', 'Pace', 'Stamina'],
    },
    ('IP', 'Wing-Back'): {
        'key': ['Crossing', 'Marking', 'Tackling', 'Teamwork', 'Work Rate', 
                'Acceleration', 'Stamina', 'Pace'],
        'important': ['Dribbling', 'First Touch', 'Passing', 'Technique', 'Anticipation',
                      'Concentration', 'Decisions', 'Off The Ball', 'Positioning', 
                      'Agility', 'Balance'],
    },
    ('IP', 'Inside Wing-Back'): {
        'key': ['Passing', 'Tackling', 'Anticipation', 'Composure', 'Decisions', 
                'Positioning', 'Teamwork', 'Acceleration'],
        'important': ['First Touch', 'Marking', 'Technique', 'Concentration', 
                      'Work Rate', 'Agility', 'Pace', 'Stamina'],
    },
    ('IP', 'Ball-Playing Centre-Back'): {
        'key': ['Heading', 'Marking', 'Passing', 'Tackling', 'Anticipation', 
                'Composure', 'Positioning', 'Jumping Reach', 'Strength'],
        'important': [],  # In-game lists same as Key
    },
    ('IP', 'Defensive Midfielder'): {
        'key': ['Tackling', 'Anticipation', 'Concentration', 'Positioning', 'Teamwork'],
        'important': ['First Touch', 'Marking', 'Passing', 'Aggression', 'Composure', 
                      'Decisions', 'Work Rate', 'Stamina', 'Strength'],
    },
    ('IP', 'Deep-Lying Playmaker'): {
        'key': ['First Touch', 'Passing', 'Technique', 'Composure', 'Decisions', 
                'Teamwork', 'Vision'],
        'important': ['Marking', 'Tackling', 'Anticipation', 'Concentration', 
                      'Off The Ball', 'Positioning', 'Work Rate', 'Balance', 'Stamina'],
    },
    ('IP', 'Inside Forward'): {
        'key': ['Dribbling', 'First Touch', 'Technique', 'Anticipation', 'Composure', 
                'Off The Ball', 'Acceleration', 'Agility'],
        'important': ['Crossing', 'Finishing', 'Long Shots', 'Passing', 'Flair', 
                      'Vision', 'Work Rate', 'Balance', 'Pace', 'Stamina'],
    },
    ('IP', 'Winger'): {
        'key': ['Crossing', 'Dribbling', 'Technique', 'Teamwork', 'Acceleration', 
                'Agility', 'Pace'],
        'important': ['First Touch', 'Passing', 'Anticipation', 'Flair', 'Off The Ball', 
                      'Work Rate', 'Balance', 'Stamina'],
    },
    ('IP', 'Attacking Midfielder'): {
        'key': ['First Touch', 'Long Shots', 'Passing', 'Technique', 'Composure', 
                'Flair', 'Off The Ball'],
        'important': ['Crossing', 'Dribbling', 'Finishing', 'Anticipation', 'Decisions', 
                      'Vision', 'Acceleration', 'Agility'],
    },
    ('IP', 'Channel Forward'): {
        'key': ['Dribbling', 'Finishing', 'First Touch', 'Technique', 'Composure', 
                'Off The Ball', 'Work Rate', 'Acceleration'],
        'important': ['Crossing', 'Heading', 'Passing', 'Anticipation', 'Decisions', 
                      'Agility', 'Balance', 'Pace', 'Stamina'],
    },
    ('IP', 'Centre Forward'): {
        'key': ['Finishing', 'First Touch', 'Heading', 'Technique', 'Composure', 
                'Off The Ball', 'Acceleration', 'Strength'],
        'important': ['Dribbling', 'Passing', 'Anticipation', 'Decisions', 'Agility', 
                      'Balance', 'Jumping Reach', 'Pace'],
    },
    
    # OUT-OF-POSSESSION ROLES
    ('OOP', 'Goalkeeper'): {
        'key': ['Aerial Reach', 'Command of Area', 'Communication', 'Handling', 
                'Reflexes', 'Concentration', 'Positioning', 'Agility'],
        'important': ['One on Ones', 'Rushing Out', 'Anticipation', 'Decisions'],
    },
    ('OOP', 'Full Back'): {
        'key': ['Marking', 'Tackling', 'Anticipation', 'Positioning', 'Teamwork', 
                'Acceleration'],
        'important': ['Aggression', 'Concentration', 'Decisions', 'Work Rate', 
                      'Agility', 'Pace', 'Stamina'],
    },
    ('OOP', 'Pressing Full-Back'): {
        'key': ['Marking', 'Tackling', 'Aggression', 'Anticipation', 'Positioning', 
                'Teamwork', 'Work Rate', 'Acceleration'],
        'important': ['Bravery', 'Concentration', 'Decisions', 'Agility', 'Pace', 'Stamina'],
    },
    ('OOP', 'Centre Back'): {
        'key': ['Heading', 'Marking', 'Tackling', 'Anticipation', 'Positioning', 
                'Jumping Reach', 'Strength'],
        'important': ['Aggression', 'Bravery', 'Composure', 'Concentration', 
                      'Decisions', 'Pace'],
    },
    ('OOP', 'Screening Defensive Midfielder'): {
        'key': ['Marking', 'Tackling', 'Anticipation', 'Concentration', 'Decisions', 
                'Positioning'],
        'important': ['Teamwork', 'Work Rate', 'Stamina', 'Strength'],
    },
    ('OOP', 'Defensive Midfielder'): {
        'key': ['Tackling', 'Anticipation', 'Decisions', 'Positioning', 'Teamwork', 
                'Work Rate'],
        'important': ['Marking', 'Aggression', 'Concentration', 'Stamina', 'Strength'],
    },
    ('OOP', 'Wide Midfielder'): {
        'key': ['Decisions', 'Teamwork', 'Work Rate', 'Acceleration'],
        'important': ['Marking', 'Aggression', 'Anticipation', 'Off The Ball', 
                      'Agility', 'Pace', 'Stamina'],
    },
    ('OOP', 'Tracking Winger'): {
        'key': ['Aggression', 'Anticipation', 'Decisions', 'Teamwork', 'Work Rate', 
                'Acceleration', 'Stamina'],
        'important': ['Off The Ball', 'Positioning', 'Agility', 'Pace'],
    },
    ('OOP', 'Tracking Attacking Midfielder'): {
        'key': ['Aggression', 'Anticipation', 'Decisions', 'Teamwork', 'Work Rate', 
                'Stamina'],
        'important': ['Marking', 'Off The Ball', 'Positioning'],
    },
    ('OOP', 'Attacking Midfielder'): {
        'key': ['Anticipation', 'Decisions', 'Work Rate'],
        'important': ['Marking', 'Aggression', 'Off The Ball', 'Teamwork', 'Stamina'],
    },
    ('OOP', 'Central Outlet Centre Forward'): {
        'key': ['Anticipation', 'Concentration', 'Decisions', 'Off The Ball', 
                'Teamwork', 'Balance'],
        'important': ['First Touch', 'Marking', 'Composure', 'Strength'],
    },
    ('OOP', 'Centre Forward'): {
        'key': ['Anticipation', 'Decisions', 'Work Rate'],
        'important': ['Marking', 'Aggression', 'Off The Ball', 'Teamwork', 'Stamina'],
    },
}


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
        'Work Rate': 0.015,  # CSV rated high but R2 omitted - moderate bonus
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
# CALCULATION FUNCTIONS
# =============================================================================

def normalize_attribute(value, min_val=1, max_val=20):
    """Normalize attribute value to 0-1 scale."""
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
        raise ValueError(f"Unknown position: {position}")
    
    weighted_sum = 0
    for attribute, weight in weights.items():
        player_value = player_attributes.get(attribute, 10)  # Default to 10
        normalized_value = normalize_attribute(player_value)
        weighted_sum += normalized_value * weight
    
    return weighted_sum * 100


def calculate_role_score(player_attributes, role_key_attrs, role_important_attrs):
    """
    Calculate role score based on Key/Important attribute modifiers.
    
    Args:
        player_attributes: dict of {attribute_name: value (1-20)}
        role_key_attrs: list of key attribute names
        role_important_attrs: list of important attribute names
    
    Returns:
        float: Score from 0-100
    """
    KEY_MULTIPLIER = 1.5
    IMPORTANT_MULTIPLIER = 1.2
    
    all_role_attrs = set(role_key_attrs) | set(role_important_attrs)
    
    if not all_role_attrs:
        return 50.0  # Default if no role attributes defined
    
    weighted_sum = 0
    total_weight = 0
    
    for attribute in all_role_attrs:
        player_value = player_attributes.get(attribute, 10)
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
    
    Args:
        player_attributes: dict of {attribute_name: value (1-20)}
        position: string like 'D(C)', 'ST'
        role: string like 'Ball-Playing Centre-Back'
        role_key_attrs: list of key attribute names
        role_important_attrs: list of important attribute names
    
    Returns:
        float: Bonus score (0-10 scale)
    """
    bonus = 0
    flagged_attrs = set(role_key_attrs) | set(role_important_attrs)
    
    # Position/role specific consensus bonuses
    consensus_attrs = CONSENSUS_BONUSES.get((position, role), {})
    
    for attribute, bonus_weight in consensus_attrs.items():
        if attribute not in flagged_attrs:
            player_value = player_attributes.get(attribute, 10)
            normalized_value = normalize_attribute(player_value)
            bonus += normalized_value * bonus_weight
    
    # Universal Balance bonus for outfield players (if not already flagged)
    if 'Balance' not in flagged_attrs and position != 'GK':
        player_balance = player_attributes.get('Balance', 10)
        normalized_balance = normalize_attribute(player_balance)
        bonus += normalized_balance * 0.01
    
    # Normalize to 0-10 scale (cap at 10)
    return min(bonus * 100, 10)


def apply_threshold_penalties(rating, player_attributes, role):
    """
    Apply penalties when attributes fall below minimum thresholds.
    
    Args:
        rating: float, the calculated rating before penalties
        player_attributes: dict of {attribute_name: value (1-20)}
        role: string, the role name
    
    Returns:
        float: Rating after penalties applied
    """
    thresholds = THRESHOLDS.get(role, {})
    penalty_multiplier = 1.0
    
    for attribute, min_value in thresholds.items():
        player_value = player_attributes.get(attribute, 10)
        if player_value < min_value:
            # 5% penalty per point below threshold
            shortfall = min_value - player_value
            penalty_multiplier *= (1 - 0.05 * shortfall)
    
    # Cap maximum penalty at 50%
    return rating * max(penalty_multiplier, 0.5)


def get_role_attributes(role, phase='IP'):
    """
    Get Key and Important attributes for a role.
    
    Args:
        role: string, role name
        phase: 'IP' or 'OOP'
    
    Returns:
        tuple: (key_attrs, important_attrs)
    """
    role_data = ROLE_ATTRIBUTES.get((phase, role), {})
    return role_data.get('key', []), role_data.get('important', [])


def calculate_role_rating(player_attributes, position, role, phase='IP', 
                          apply_thresholds=True):
    """
    Calculate a player's rating for a specific position/role.
    
    Args:
        player_attributes: dict of {attribute_name: value (1-20)}
        position: string like 'D(C)', 'AM(L/R)', 'ST'
        role: string like 'Ball-Playing Centre-Back', 'Channel Forward'
        phase: 'IP' for In-Possession, 'OOP' for Out-of-Possession
        apply_thresholds: bool, whether to apply threshold penalties
    
    Returns:
        float: Rating from 0-100
    """
    # Get role's key and important attributes
    role_key, role_important = get_role_attributes(role, phase)
    
    # Step 1: Position Score (60% weight)
    position_score = calculate_position_score(player_attributes, position)
    
    # Step 2: Role Score (35% weight)
    role_score = calculate_role_score(player_attributes, role_key, role_important)
    
    # Step 3: Consensus Bonus (5% weight)
    consensus_bonus = calculate_consensus_bonus(
        player_attributes, position, role, role_key, role_important
    )
    
    # Combine with weights
    final_rating = (position_score * 0.60) + (role_score * 0.35) + (consensus_bonus * 0.05)
    
    # Apply threshold penalties if requested
    if apply_thresholds:
        final_rating = apply_threshold_penalties(final_rating, player_attributes, role)
    
    return round(final_rating, 1)


# =============================================================================
# EXAMPLE USAGE
# =============================================================================

if __name__ == '__main__':
    # Example player: A pacy but technically limited striker
    example_player = {
        'Finishing': 14,
        'First Touch': 12,
        'Heading': 11,
        'Technique': 11,
        'Composure': 13,
        'Off The Ball': 15,
        'Dribbling': 12,
        'Passing': 10,
        'Anticipation': 14,
        'Decisions': 12,
        'Work Rate': 16,
        'Acceleration': 18,
        'Pace': 17,
        'Agility': 15,
        'Balance': 14,
        'Jumping Reach': 12,
        'Strength': 11,
        'Stamina': 15,
    }
    
    # Calculate ratings for different roles
    print("Example Player Ratings:")
    print("-" * 50)
    
    # Channel Forward (IP) - should be high due to pace/work rate
    rating = calculate_role_rating(example_player, 'ST', 'Channel Forward', 'IP')
    print(f"Channel Forward (IP): {rating}")
    
    # Centre Forward (IP) - slightly lower due to heading/strength
    rating = calculate_role_rating(example_player, 'ST', 'Centre Forward', 'IP')
    print(f"Centre Forward (IP): {rating}")
    
    # Central Outlet CF (OOP) - should be high due to pace
    rating = calculate_role_rating(example_player, 'ST', 'Central Outlet Centre Forward', 'OOP')
    print(f"Central Outlet CF (OOP): {rating}")
    
    print("\n" + "=" * 50)
    print("Component Breakdown for Channel Forward:")
    print("=" * 50)
    
    role_key, role_imp = get_role_attributes('Channel Forward', 'IP')
    pos_score = calculate_position_score(example_player, 'ST')
    role_score = calculate_role_score(example_player, role_key, role_imp)
    consensus = calculate_consensus_bonus(example_player, 'ST', 'Channel Forward', role_key, role_imp)
    
    print(f"Position Score (60%): {pos_score:.1f}")
    print(f"Role Score (35%):     {role_score:.1f}")
    print(f"Consensus Bonus (5%): {consensus:.1f}")
    print(f"Weighted Total:       {(pos_score * 0.60) + (role_score * 0.35) + (consensus * 0.05):.1f}")
