# Research Prompt 09: Match Importance Scoring

## Context

Our scoring model varies parameters based on match importance (High, Medium, Low, Sharpness). Currently, users manually select importance for each match. We want to provide automatic suggestions based on match context.

### Current Issue

Users must manually classify every match, which:
- Is tedious for a full season
- Requires knowledge of competition context
- May be inconsistent

## Research Objective

**Goal**: Design an automatic match importance classification system that:
1. Analyzes match context (competition, opponent, timing)
2. Suggests appropriate importance level
3. Considers squad situation and season objectives
4. Allows user override

## Match Importance Levels

| Level | Description | Usage |
|-------|-------------|-------|
| **High** | Must-win or critical match | Best XI, tolerate tiredness |
| **Medium** | Important but not critical | Balance quality and rotation |
| **Low** | Lower stakes, rotation opportunity | Rest key players, develop youth |
| **Sharpness** | Build match fitness | Prioritize rusty players |

## Factors Affecting Importance

### 1. Competition Type

**Tier 1 - Highest Stakes**:
- League title deciders (last 5 games if in contention)
- Major cup finals (FA Cup, Champions League Final)
- Promotion/Relegation deciders
- Derby matches

**Tier 2 - High Stakes**:
- Most league matches
- Cup semi-finals
- European group stage (close qualification)
- Local rivalries

**Tier 3 - Moderate Stakes**:
- Early cup rounds vs weaker opponents
- League matches with comfortable position
- European group stage (already qualified)

**Tier 4 - Lower Stakes**:
- Pre-season friendlies
- Early cup rounds vs much weaker opposition
- Dead rubbers (league position secured)

**Questions**:
- What competition hierarchy makes sense for different leagues?
- How do we determine "title contention" or "relegation battle"?
- Should cup rounds be importance-weighted by opponent strength?

### 2. Opponent Strength

**Relative Strength Calculation**:
```
relative_strength = opponent_reputation / team_reputation
```

| Relative Strength | Impact on Importance |
|-------------------|---------------------|
| > 1.3 | Increase importance (tough opponent) |
| 0.7 - 1.3 | Neutral |
| < 0.7 | Decrease importance (weaker opponent) |

**Questions**:
- Where do we get opponent reputation data?
- Should we use recent form or overall reputation?
- How much should opponent strength modify base importance?

### 3. League Position Context

**Title Race**:
- Within X points of leader → increase importance
- Leader with Y+ point gap → can reduce importance for some matches

**Relegation Battle**:
- Within X points of relegation zone → increase importance
- Safe with Y+ point gap → can reduce importance

**Mid-table**:
- No immediate consequences → moderate importance

**Questions**:
- What point gaps define "in contention" vs "safe"?
- How many games from season end triggers "must-win" classification?
- Should we consider goal difference implications?

### 4. Recent Form & Squad Situation

**Momentum Factors**:
- Losing streak → may need "statement" win (increase importance?)
- Winning streak → confidence allows rotation (decrease importance?)

**Squad Health**:
- Many injuries → may need to reduce importance to preserve remaining players
- Full squad available → can afford to push for high importance

**Questions**:
- Should recent form affect importance classification?
- How do we balance "need a win" vs "preserve squad"?

### 5. Schedule Context

**Fixture Congestion**:
- 3+ matches in 7 days → suggest at least one reduced importance
- Match before high-importance fixture → may reduce current match

**Cup Progression**:
- Far in cup competition → reduce some league importance
- Near cup final → heavily weight cup

**Questions**:
- How do we identify optimal "rest matches" in congestion?
- Should we automatically suggest Sharpness matches after gaps?

### 6. User Objectives (Configurable)

Different users have different priorities:
- **Win League**: League matches weighted higher
- **Cup Glory**: Cup matches weighted higher
- **Avoid Relegation**: All matches high importance
- **Develop Youth**: More low importance matches

**Questions**:
- What objective profiles should we support?
- How do objectives modify base importance?

## Expected Deliverables

### A. Competition Base Importance Table

| Competition Type | Base Importance | Notes |
|------------------|-----------------|-------|
| League (in title race) | High | |
| League (mid-table) | Medium | |
| League (relegation battle) | High | |
| League (dead rubber) | Low | |
| Cup Final | High | |
| Cup Semi-Final | High | |
| Cup Quarter-Final | Medium-High | |
| Cup Early Round (home vs weaker) | Low | |
| Cup Early Round (away vs similar) | Medium | |
| Champions League knockout | High | |
| Champions League group (must-win) | High | |
| Champions League group (safe) | Medium | |
| Friendly | Low/Sharpness | |

### B. Importance Modifier Formula

```python
def calculate_match_importance(match, team_context, user_config):
    """
    Returns: ImportanceResult

    ImportanceResult:
        suggested_importance: str ('High', 'Medium', 'Low', 'Sharpness')
        confidence: float (0-1)
        reasoning: List[str]
        modifiers_applied: List[Modifier]
    """

    # Start with base importance from competition
    base = get_competition_base_importance(match.competition, match.round)

    # Apply modifiers
    modifiers = []

    # Opponent strength modifier
    opponent_mod = calculate_opponent_modifier(match.opponent, team_context.reputation)
    modifiers.append(opponent_mod)

    # League position modifier
    position_mod = calculate_position_modifier(team_context.league_position, team_context.games_remaining)
    modifiers.append(position_mod)

    # Schedule modifier
    schedule_mod = calculate_schedule_modifier(match, team_context.upcoming_fixtures)
    modifiers.append(schedule_mod)

    # User objective modifier
    objective_mod = calculate_objective_modifier(match, user_config.objectives)
    modifiers.append(objective_mod)

    # Combine modifiers
    final_importance = apply_modifiers(base, modifiers)

    return ImportanceResult(...)
```

### C. Modifier Definitions

**Opponent Modifier**:
| Condition | Modifier |
|-----------|----------|
| opponent_strength > 1.3 | +1 tier |
| opponent_strength > 1.1 | +0.5 tier |
| opponent_strength < 0.5 | -1 tier |
| opponent_strength < 0.7 | -0.5 tier |

**Position Modifier**:
| Condition | Modifier |
|-----------|----------|
| Title race (within 3 pts, <10 games left) | +1 tier |
| Relegation battle (within 3 pts of drop) | +1 tier |
| Safe mid-table | -0.5 tier |
| Champions on course | +0.5 tier to important games |

**Schedule Modifier**:
| Condition | Modifier |
|-----------|----------|
| Match before High importance within 3 days | -0.5 tier |
| 3rd match in 7 days | Consider -1 tier |
| No match for 7+ days prior | Consider Sharpness |

### D. Sharpness Match Detection

**Automatic Sharpness Suggestion**:
```python
def should_suggest_sharpness(match, squad_state):
    """
    Suggest Sharpness mode when:
    1. Match is Low base importance
    2. Multiple key players have sharpness < 70%
    3. No high-importance match within 3 days
    """
    conditions = [
        match.base_importance == 'Low',
        count_low_sharpness_key_players(squad_state) >= 3,
        next_high_importance_match(match) > 3 days
    ]
    return all(conditions)
```

### E. User Configuration

```json
{
  "season_objectives": {
    "primary": "Win League",
    "secondary": "FA Cup Glory",
    "tertiary": "Develop Youth"
  },
  "importance_preferences": {
    "league_weight": 1.2,
    "cup_weight": 1.0,
    "europe_weight": 0.8
  },
  "rotation_tolerance": "medium",
  "youth_development_priority": true
}
```

### F. UI Output Format

```json
{
  "match": {
    "opponent": "Manchester City",
    "competition": "Premier League",
    "date": "2026-03-15",
    "venue": "Home"
  },
  "suggestion": {
    "importance": "High",
    "confidence": 0.9,
    "reasoning": [
      "League match in title race (2 points behind leader)",
      "Strong opponent (+1 tier modifier)",
      "Only 8 games remaining"
    ],
    "alternative": {
      "importance": "Medium",
      "scenario": "If prioritizing upcoming Champions League quarter-final"
    }
  }
}
```

### G. Override Handling

When user overrides:
- Record the override for learning
- Warn if override seems problematic ("Setting Low importance for potential title decider - are you sure?")
- Allow bulk-set patterns ("All friendlies = Sharpness")

## Validation Criteria

The importance classification is successful if:
- Matches general FM community consensus on importance
- Correctly identifies must-win scenarios
- Suggests reasonable rotation opportunities
- Allows meaningful user customization
- Provides clear reasoning for suggestions

## Output Format

1. **Base Importance Tables**: Competition × stage mappings
2. **Modifier Formulas**: Complete calculation logic
3. **Sharpness Detection**: Automatic identification
4. **Configuration Schema**: User preference structure
5. **UI Specifications**: Suggestion display format
6. **Override Handling**: User interaction design
