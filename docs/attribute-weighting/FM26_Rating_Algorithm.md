# FM26 Player Role Rating Algorithm

## Overview

This algorithm calculates a player's suitability for a specific position and role by combining:

1. **Position Base Weights** — FM Arena match engine testing results (what actually wins matches)
2. **Role Modifiers** — In-game Key/Important attributes (what makes players execute role instructions)
3. **Consensus Adjustments** — Attributes where multiple AI research sources agree on importance not captured elsewhere

The algorithm produces a score from 0-100 representing how well a player fits the role.

---

## Core Formula

```
RoleRating = (PositionScore × 0.60) + (RoleScore × 0.35) + (ConsensusBonus × 0.05)
```

**Rationale for weights:**
- **60% Position**: Match engine testing shows physical/positional fundamentals drive outcomes regardless of role
- **35% Role**: Key attributes determine if player executes tactical instructions correctly  
- **5% Consensus**: Captures edge cases where research identified importance not in other sources

---

## Step 1: Calculate Position Score

Use the position-specific attribute weights from FM Arena testing. These represent what actually matters for match outcomes at each position.

### Position Weight Tables

#### GK — Goalkeeper
| Attribute | Weight |
|-----------|--------|
| Agility | 0.140 |
| Reflexes | 0.130 |
| Aerial Reach | 0.110 |
| One on Ones | 0.095 |
| Handling | 0.085 |
| Positioning | 0.080 |
| Communication | 0.070 |
| Decisions | 0.065 |
| Throwing | 0.060 |
| Composure | 0.045 |
| *Long-tail (combined)* | 0.120 |

**Long-tail breakdown:** Kicking (0.025), Anticipation (0.020), Concentration (0.020), First Touch (0.020), Passing (0.015), Command of Area (0.010), Rushing Out (0.010)

#### D(C) — Central Defender
| Attribute | Weight |
|-----------|--------|
| Jumping Reach | 0.115 |
| Pace | 0.095 |
| Acceleration | 0.085 |
| Tackling | 0.080 |
| Positioning | 0.080 |
| Anticipation | 0.075 |
| Concentration | 0.065 |
| Marking | 0.060 |
| Heading | 0.055 |
| Strength | 0.050 |
| *Long-tail (combined)* | 0.240 |

**Long-tail breakdown:** Work Rate (0.035), Composure (0.030), Decisions (0.025), Bravery (0.025), Passing (0.025), First Touch (0.020), Aggression (0.020), Determination (0.020), Technique (0.020), Stamina (0.020)

#### D(L/R) — Fullback
| Attribute | Weight |
|-----------|--------|
| Pace | 0.130 |
| Acceleration | 0.095 |
| Jumping Reach | 0.080 |
| Tackling | 0.075 |
| Anticipation | 0.070 |
| Stamina | 0.065 |
| Concentration | 0.060 |
| Crossing | 0.055 |
| Positioning | 0.050 |
| Work Rate | 0.050 |
| *Long-tail (combined)* | 0.270 |

**Long-tail breakdown:** Composure (0.035), Dribbling (0.035), Marking (0.030), Passing (0.025), Decisions (0.025), Teamwork (0.025), First Touch (0.020), Technique (0.020), Agility (0.020), Strength (0.020), Balance (0.015)

#### WB(L/R) — Wingback
| Attribute | Weight |
|-----------|--------|
| Pace | 0.120 |
| Acceleration | 0.115 |
| Stamina | 0.090 |
| Crossing | 0.070 |
| Jumping Reach | 0.065 |
| Composure | 0.060 |
| Work Rate | 0.055 |
| Vision | 0.050 |
| Tackling | 0.045 |
| Dribbling | 0.045 |
| *Long-tail (combined)* | 0.285 |

**Long-tail breakdown:** Anticipation (0.035), Positioning (0.030), Decisions (0.030), Passing (0.025), Technique (0.025), Off the Ball (0.025), First Touch (0.025), Determination (0.020), Marking (0.020), Agility (0.020), Balance (0.015), Flair (0.015)

#### DM — Defensive Midfielder
| Attribute | Weight |
|-----------|--------|
| Acceleration | 0.120 |
| Anticipation | 0.095 |
| Tackling | 0.085 |
| Positioning | 0.080 |
| Composure | 0.070 |
| Passing | 0.065 |
| Stamina | 0.060 |
| Jumping Reach | 0.055 |
| Concentration | 0.050 |
| First Touch | 0.045 |
| *Long-tail (combined)* | 0.275 |

**Long-tail breakdown:** Decisions (0.035), Marking (0.030), Dribbling (0.030), Long Shots (0.025), Strength (0.025), Work Rate (0.025), Teamwork (0.025), Vision (0.020), Pace (0.020), Aggression (0.020), Technique (0.020)

#### M(C) — Central Midfielder
| Attribute | Weight |
|-----------|--------|
| Anticipation | 0.095 |
| Acceleration | 0.090 |
| Composure | 0.085 |
| Stamina | 0.080 |
| Pace | 0.075 |
| Passing | 0.070 |
| First Touch | 0.065 |
| Decisions | 0.060 |
| Dribbling | 0.055 |
| Work Rate | 0.050 |
| *Long-tail (combined)* | 0.275 |

**Long-tail breakdown:** Crossing (0.035), Jumping Reach (0.030), Strength (0.025), Technique (0.025), Off the Ball (0.025), Positioning (0.025), Vision (0.020), Tackling (0.020), Teamwork (0.020), Concentration (0.020), Balance (0.015), Agility (0.015)

#### M(L/R) — Wide Midfielder
| Attribute | Weight |
|-----------|--------|
| Pace | 0.125 |
| Dribbling | 0.095 |
| Acceleration | 0.090 |
| Stamina | 0.080 |
| Crossing | 0.070 |
| Composure | 0.065 |
| Vision | 0.060 |
| Jumping Reach | 0.050 |
| Work Rate | 0.045 |
| Technique | 0.040 |
| *Long-tail (combined)* | 0.280 |

**Long-tail breakdown:** Agility (0.040), Off the Ball (0.035), First Touch (0.030), Positioning (0.025), Balance (0.025), Passing (0.025), Tackling (0.025), Flair (0.020), Anticipation (0.020), Finishing (0.020), Concentration (0.015)

#### AM(C) — Attacking Midfielder
| Attribute | Weight |
|-----------|--------|
| Pace | 0.100 |
| Acceleration | 0.095 |
| Vision | 0.085 |
| Passing | 0.080 |
| Composure | 0.075 |
| Technique | 0.070 |
| First Touch | 0.065 |
| Concentration | 0.060 |
| Decisions | 0.055 |
| Dribbling | 0.050 |
| *Long-tail (combined)* | 0.265 |

**Long-tail breakdown:** Long Shots (0.040), Flair (0.035), Off the Ball (0.035), Jumping Reach (0.030), Anticipation (0.030), Finishing (0.025), Agility (0.025), Balance (0.020), Work Rate (0.015), Teamwork (0.010)

#### AM(L/R) — Winger
| Attribute | Weight |
|-----------|--------|
| Pace | 0.140 |
| Acceleration | 0.120 |
| Dribbling | 0.090 |
| Crossing | 0.075 |
| Agility | 0.065 |
| Anticipation | 0.060 |
| Technique | 0.055 |
| Composure | 0.050 |
| Jumping Reach | 0.045 |
| Off the Ball | 0.040 |
| *Long-tail (combined)* | 0.260 |

**Long-tail breakdown:** Balance (0.040), First Touch (0.035), Finishing (0.035), Flair (0.030), Long Shots (0.025), Decisions (0.025), Work Rate (0.020), Stamina (0.020), Vision (0.015), Passing (0.015)

#### ST — Striker
| Attribute | Weight |
|-----------|--------|
| Finishing | 0.100 |
| Pace | 0.095 |
| Jumping Reach | 0.090 |
| Off the Ball | 0.085 |
| Acceleration | 0.080 |
| Composure | 0.075 |
| First Touch | 0.070 |
| Concentration | 0.060 |
| Anticipation | 0.055 |
| Balance | 0.050 |
| *Long-tail (combined)* | 0.240 |

**Long-tail breakdown:** Dribbling (0.035), Technique (0.030), Decisions (0.030), Heading (0.030), Strength (0.025), Vision (0.025), Passing (0.020), Determination (0.020), Agility (0.015), Work Rate (0.010)

### Position Score Calculation

```python
def calculate_position_score(player_attributes, position):
    weights = POSITION_WEIGHTS[position]
    
    weighted_sum = 0
    for attribute, weight in weights.items():
        player_value = player_attributes.get(attribute, 10)  # Default to 10 if missing
        # Normalize attribute to 0-1 scale (attributes range 1-20)
        normalized_value = (player_value - 1) / 19
        weighted_sum += normalized_value * weight
    
    # Convert to 0-100 scale
    return weighted_sum * 100
```

---

## Step 2: Calculate Role Score

Role score uses in-game Key and Important attributes with tiered multipliers.

### Role Modifier Values

| Attribute Type | Multiplier |
|----------------|------------|
| Key | 1.5 |
| Important | 1.2 |
| Unlisted | 1.0 |

### Role Score Calculation

```python
def calculate_role_score(player_attributes, role_key_attrs, role_important_attrs):
    # Get all attributes for the role's position
    all_role_attrs = set(role_key_attrs) | set(role_important_attrs)
    
    weighted_sum = 0
    total_weight = 0
    
    for attribute in all_role_attrs:
        player_value = player_attributes.get(attribute, 10)
        normalized_value = (player_value - 1) / 19
        
        if attribute in role_key_attrs:
            weight = 1.5
        elif attribute in role_important_attrs:
            weight = 1.2
        else:
            weight = 1.0
        
        weighted_sum += normalized_value * weight
        total_weight += weight
    
    # Normalize and convert to 0-100
    return (weighted_sum / total_weight) * 100
```

### Role Key/Important Attribute Reference

#### IN-POSSESSION ROLES

**GK - Goalkeeper**
- Key: Aerial Reach, Command Of Area, Communication, Handling, Reflexes, Concentration, Positioning, Agility
- Important: Kicking, One On Ones, Throwing, Anticipation, Decisions

**D(L/R) - Full-Back**
- Key: Marking, Tackling, Concentration, Anticipation, Positioning, Teamwork, Acceleration
- Important: Crossing, Dribbling, Passing, Technique, Decisions, Work Rate, Agility, Pace, Stamina

**D(L/R) - Wing-Back**
- Key: Crossing, Marking, Tackling, Teamwork, Work Rate, Acceleration, Stamina, Pace
- Important: Dribbling, First Touch, Passing, Technique, Anticipation, Concentration, Decisions, Off The Ball, Positioning, Agility, Balance

**D(L/R) - Inside Wing-Back**
- Key: Passing, Tackling, Anticipation, Composure, Decisions, Positioning, Teamwork, Acceleration
- Important: First Touch, Marking, Technique, Concentration, Work Rate, Agility, Pace, Stamina

**D(C) - Ball-Playing Centre-Back**
- Key: Heading, Marking, Passing, Tackling, Anticipation, Composure, Positioning, Jumping Reach, Strength
- Important: *(same as Key per in-game)*

**DM - Defensive Midfielder**
- Key: Tackling, Anticipation, Concentration, Positioning, Teamwork
- Important: First Touch, Marking, Passing, Aggression, Composure, Decisions, Work Rate, Stamina, Strength

**DM - Deep-Lying Playmaker**
- Key: First Touch, Passing, Technique, Composure, Decisions, Teamwork, Vision
- Important: Marking, Tackling, Anticipation, Concentration, Off The Ball, Positioning, Work Rate, Balance, Stamina

**AM(L/R) - Inside Forward**
- Key: Dribbling, First Touch, Technique, Anticipation, Composure, Off The Ball, Acceleration, Agility
- Important: Crossing, Finishing, Long Shots, Passing, Flair, Vision, Work Rate, Balance, Pace, Stamina

**AM(L/R) - Winger**
- Key: Crossing, Dribbling, Technique, Teamwork, Acceleration, Agility, Pace
- Important: First Touch, Passing, Anticipation, Flair, Off The Ball, Work Rate, Balance, Stamina

**AM(C) - Attacking Midfielder**
- Key: First Touch, Long Shots, Passing, Technique, Composure, Flair, Off The Ball
- Important: Crossing, Dribbling, Finishing, Anticipation, Decisions, Vision, Acceleration, Agility

**ST - Channel Forward**
- Key: Dribbling, Finishing, First Touch, Technique, Composure, Off The Ball, Work Rate, Acceleration
- Important: Crossing, Heading, Passing, Anticipation, Decisions, Agility, Balance, Pace, Stamina

**ST - Centre Forward**
- Key: Finishing, First Touch, Heading, Technique, Composure, Off The Ball, Acceleration, Strength
- Important: Dribbling, Passing, Anticipation, Decisions, Agility, Balance, Jumping Reach, Pace

#### OUT-OF-POSSESSION ROLES

**GK - Goalkeeper**
- Key: Aerial Reach, Command Of Area, Communication, Handling, Reflexes, Concentration, Positioning, Agility
- Important: One On Ones, Rushing Out, Anticipation, Decisions

**D(L/R) - Full Back**
- Key: Marking, Tackling, Anticipation, Positioning, Teamwork, Acceleration
- Important: Aggression, Concentration, Decisions, Work Rate, Agility, Pace, Stamina

**D(L/R) - Pressing Full-Back**
- Key: Marking, Tackling, Aggression, Anticipation, Positioning, Teamwork, Work Rate, Acceleration
- Important: Bravery, Concentration, Decisions, Agility, Pace, Stamina

**D(C) - Centre Back**
- Key: Heading, Marking, Tackling, Anticipation, Positioning, Jumping Reach, Strength
- Important: Aggression, Bravery, Composure, Concentration, Decisions, Pace

**DM - Screening Defensive Midfielder**
- Key: Marking, Tackling, Anticipation, Concentration, Decisions, Positioning
- Important: Teamwork, Work Rate, Stamina, Strength

**DM - Defensive Midfielder**
- Key: Tackling, Anticipation, Decisions, Positioning, Teamwork, Work Rate
- Important: Marking, Aggression, Concentration, Stamina, Strength

**M(L/R) - Wide Midfielder**
- Key: Decisions, Teamwork, Work Rate, Acceleration
- Important: Marking, Aggression, Anticipation, Off The Ball, Agility, Pace, Stamina

**AM(L/R) - Tracking Winger**
- Key: Aggression, Anticipation, Decisions, Teamwork, Work Rate, Acceleration, Stamina
- Important: Off The Ball, Positioning, Agility, Pace

**AM(C) - Tracking Attacking Midfielder**
- Key: Aggression, Anticipation, Decisions, Teamwork, Work Rate, Stamina
- Important: Marking, Off The Ball, Positioning

**AM(C) - Attacking Midfielder**
- Key: Anticipation, Decisions, Work Rate
- Important: Marking, Aggression, Off The Ball, Teamwork, Stamina

**ST - Central Outlet Centre Forward**
- Key: Anticipation, Concentration, Decisions, Off The Ball, Teamwork, Balance
- Important: First Touch, Marking, Composure, Strength

**ST - Centre Forward**
- Key: Anticipation, Decisions, Work Rate
- Important: Marking, Aggression, Off The Ball, Teamwork, Stamina

---

## Step 3: Calculate Consensus Bonus

These are attributes where multiple AI research sources agreed on importance BUT the attribute is NOT listed as Key/Important for the role. This captures "hidden importance" validated by research convergence.

### Consensus Bonus Attributes by Position/Role

| Position/Role | Consensus Attributes | Bonus Per Attr |
|---------------|---------------------|----------------|
| D(C) Ball-Playing CB | Technique, Vision | +0.02 each |
| ST Central Outlet CF | Acceleration, Pace | +0.03 each |
| All Outfield | Balance (if not already Key/Imp) | +0.01 |

### Consensus Bonus Calculation

```python
def calculate_consensus_bonus(player_attributes, position, role, role_key_attrs, role_important_attrs):
    bonus = 0
    flagged_attrs = set(role_key_attrs) | set(role_important_attrs)
    
    # Position-specific consensus bonuses
    consensus_attrs = CONSENSUS_BONUSES.get((position, role), {})
    
    for attribute, bonus_weight in consensus_attrs.items():
        if attribute not in flagged_attrs:
            player_value = player_attributes.get(attribute, 10)
            normalized_value = (player_value - 1) / 19
            bonus += normalized_value * bonus_weight
    
    # Universal Balance bonus (if not already flagged)
    if 'Balance' not in flagged_attrs and position != 'GK':
        player_balance = player_attributes.get('Balance', 10)
        normalized_balance = (player_balance - 1) / 19
        bonus += normalized_balance * 0.01
    
    # Normalize to 0-100 scale (max possible bonus ~10 points)
    return min(bonus * 100, 10)

CONSENSUS_BONUSES = {
    ('D(C)', 'Ball-Playing Centre-Back'): {
        'Technique': 0.02,
        'Vision': 0.02,
        'First Touch': 0.015,
        'Decisions': 0.015,
        'Concentration': 0.015,
    },
    ('ST', 'Central Outlet Centre Forward'): {
        'Acceleration': 0.03,
        'Pace': 0.03,
    },
    # Add other position/role combinations as needed
}
```

---

## Complete Algorithm Implementation

```python
def calculate_role_rating(player_attributes, position, role, phase='IP'):
    """
    Calculate a player's rating for a specific position/role.
    
    Args:
        player_attributes: dict of {attribute_name: value (1-20)}
        position: string like 'D(C)', 'AM(L/R)', 'ST'
        role: string like 'Ball-Playing Centre-Back', 'Channel Forward'
        phase: 'IP' for In-Possession, 'OOP' for Out-of-Possession
    
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
    
    # Apply threshold penalties (optional - see below)
    final_rating = apply_threshold_penalties(final_rating, player_attributes, role)
    
    return round(final_rating, 1)
```

---

## Optional: Threshold Penalties

Critical thresholds can apply penalties when attributes fall below minimum viable levels.

```python
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
    # Add more as needed
}

def apply_threshold_penalties(rating, player_attributes, role):
    thresholds = THRESHOLDS.get(role, {})
    penalty_multiplier = 1.0
    
    for attribute, min_value in thresholds.items():
        player_value = player_attributes.get(attribute, 10)
        if player_value < min_value:
            # 5% penalty per point below threshold
            shortfall = min_value - player_value
            penalty_multiplier *= (1 - 0.05 * shortfall)
    
    return rating * max(penalty_multiplier, 0.5)  # Cap at 50% penalty
```

---

## Key Design Decisions

### Why 60/35/5 split?

1. **Position weights (60%)** come from match engine regression testing with thousands of simulated matches. They represent *what actually wins games*.

2. **Role weights (35%)** come from in-game Key/Important flags. They represent *what makes players execute tactical instructions correctly*. A player with perfect physical stats but wrong mental/technical profile won't play the role as intended.

3. **Consensus bonus (5%)** captures edge cases where multiple independent AI analyses identified importance not reflected elsewhere. This is a small hedge against blind spots in the main sources.

### Why not just use position weights?

FM Arena testing showed that attributes like Vision, Off The Ball, and Positioning had "zero measured impact" on league points. However, these attributes clearly affect:
- Which actions players *attempt* (role execution)
- Suitability ratings shown in-game
- Player behavior in specific tactical situations

A player with 20 Pace but 1 Vision might win matches in aggregate testing, but they won't play like a Deep-Lying Playmaker. The role score ensures tactical fit.

### Why include threshold penalties?

FM Arena testing noted: "A striker with 20 in everything but 5 Finishing will underperform despite high aggregate score." Certain attributes have minimum viable thresholds below which the role becomes dysfunctional. The penalty system captures this.

---

## Summary

| Component | Weight | Source | Purpose |
|-----------|--------|--------|---------|
| Position Score | 60% | FM Arena testing | Match engine performance reality |
| Role Score | 35% | In-game Key/Important | Tactical role execution |
| Consensus Bonus | 5% | AI research convergence | Hidden importance edge cases |
| Threshold Penalties | (modifier) | FM Arena + guides | Minimum viable attribute levels |

This algorithm balances the empirical reality that physical attributes dominate match outcomes with the practical need for players to execute specific tactical roles correctly.
