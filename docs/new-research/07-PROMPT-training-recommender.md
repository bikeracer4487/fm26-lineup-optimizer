# Research Prompt 07: Position Training Recommender

## Context

Our app includes a training advisor that recommends which players should train at which positions to improve tactical flexibility. Current implementation exists in `api_training_advisor.py` but lacks a rigorous algorithm.

### Current Implementation Issues

- No clear definition of "tactical gap"
- Arbitrary selection criteria
- Missing timeline estimates for familiarity gain
- No integration with squad analysis

## Research Objective

**Goal**: Design a position training recommendation algorithm that:
1. Identifies tactical gaps where position depth is weak
2. Selects players with high potential for position conversion
3. Estimates realistic training timelines
4. Prioritizes recommendations by impact

## The Position Training Problem

### Why Train Players at New Positions?

1. **Coverage**: Fill gaps when injuries/suspensions occur
2. **Tactical Flexibility**: Enable formation changes
3. **Squad Efficiency**: Maximize utility from limited squad size
4. **Development**: Help young players become more versatile

### Constraints

- Players have limited position training capacity
- Training takes time (weeks/months)
- Not all players can learn all positions
- Training too many positions dilutes development

## Questions to Resolve

### 1. Tactical Gap Analysis

**What is a "tactical gap"?**
- Position with only 1 player capable?
- Position where #2 is significantly worse than #1?
- Position where injury to #1 causes major problem?

**How do we measure gap severity?**
- Simple count: < 2 players = critical gap
- Quality-weighted: sum of ratings below threshold
- Probability-weighted: injury likelihood × impact

**Questions**:
- What positions should we analyze? (All 15? Only formation-specific?)
- Should we consider both IP and OOP requirements?
- How do we handle positions that overlap? (AM(C) vs M(C))

### 2. Player Selection Criteria

**Who should train at a new position?**

**Attribute-Based**:
- Physical attributes match position demands
- Mental attributes match position demands
- Technical attributes match position demands

**Learning Potential**:
- Young players learn faster
- Versatility attribute affects learning
- Determination/Professionalism affect training outcomes

**Proximity**:
- Similar positions easier (D(R) → D(L) easy)
- Cross-field (ST → CB) very hard
- Related positions (AM(C) → M(C)) moderate

**Questions**:
- What attribute weights determine position suitability?
- How much does age affect training speed?
- Is there data on position "distance" for training difficulty?

### 3. Training Timeline Estimation

**How long does it take to gain familiarity?**

FM mechanics suggest:
- Playing matches in position is primary familiarity source
- Training provides slower but consistent gain
- Versatility attribute affects speed

**Questions**:
- What is base familiarity gain per week of training?
- How much does a match in position provide?
- How long to go from 1/20 to 10/20 familiarity?
- How long to go from 10/20 to 15/20?

### 4. Recommendation Prioritization

**How do we rank recommendations?**

**Factors**:
- Gap severity (how badly do we need this?)
- Player suitability (how good will they be?)
- Timeline (how quickly will it pay off?)
- Opportunity cost (what else could this player do?)

**Questions**:
- What weights should each factor have?
- Should recommendations be position-centric or player-centric?
- How many recommendations is too many?

### 5. Strategic Training Pathways

Some position transitions are FM classics:
- Winger → Wingback (overlapping skills)
- AM(C) → M(C) (deeper version of same role)
- D(L/R) → D(C) (fullback to CB)
- DM → CB (defensive midfield to center back)

**Questions**:
- Should we encode known "easy" transitions?
- Are there transitions that should be discouraged?
- How do we surface these pathways to users?

### 6. Role vs Position

FM26 has split IP/OOP roles. Training affects:
- Position familiarity (geometric location)
- Role suitability (tactical instructions)

**Questions**:
- Does position training improve role suitability?
- Should recommendations specify role as well as position?
- How do we handle positions with many role options?

## Expected Deliverables

### A. Tactical Gap Algorithm

```python
def analyze_tactical_gaps(squad, formation):
    """
    Returns: List[TacticalGap] sorted by severity

    TacticalGap:
        position: str
        severity: float (0-1, higher = worse)
        current_options: List[PlayerOption]
        recommended_count: int (how many more we need)
    """
```

**Severity Formula**:
```
severity = f(num_capable_players, quality_gap, injury_risk, formation_importance)
```

### B. Position Suitability Score

```python
def calculate_position_suitability(player, target_position):
    """
    Returns: float (0-100)

    Based on:
    - Current attributes vs position requirements
    - Learning potential (age, versatility)
    - Current familiarity
    """
```

**Attribute Weights by Position** (example):
| Position | Key Physical | Key Mental | Key Technical |
|----------|--------------|------------|---------------|
| D(C) | Jumping, Strength | Positioning, Concentration | Marking, Tackling |
| M(C) | Stamina, Balance | Decisions, Teamwork | Passing, First Touch |
| AM(C) | Agility, Acceleration | Vision, Off the Ball | Technique, Dribbling |

### C. Training Timeline Model

```python
def estimate_training_timeline(player, from_familiarity, to_familiarity, target_position):
    """
    Returns: TimelineEstimate

    TimelineEstimate:
        weeks_training_only: int
        weeks_with_matches: int
        confidence: str ('high', 'medium', 'low')
        factors: List[str]
    """
```

**Base Timeline Table**:
| From → To | Base Weeks | Young (<21) | Old (>28) |
|-----------|------------|-------------|-----------|
| 1 → 5 | 8 | 5 | 12 |
| 5 → 10 | 12 | 8 | 18 |
| 10 → 15 | 16 | 10 | 24 |
| 15 → 18 | 20 | 12 | 30+ |

### D. Position Distance Matrix

Matrix showing how "easy" transitions are:

```
         D(C)  D(L)  D(R)  DM   M(C)  M(L)  M(R)  AM(C) AM(L) AM(R) ST
D(C)      0     2     2    1     3     4     4     5     5     5    5
D(L)      2     0     1    2     3     2     3     4     3     4    5
...
```

Lower number = easier transition = faster training.

### E. Recommendation Output Format

```json
{
  "recommendations": [
    {
      "priority": 1,
      "player": "John Smith",
      "target_position": "D(L)",
      "current_familiarity": 3,
      "target_familiarity": 12,
      "reason": "Critical gap: only 1 capable left-back, high injury risk to starter",
      "suitability_score": 78,
      "timeline": {
        "weeks_estimate": 10,
        "method": "Position training + cup match opportunities"
      },
      "confidence": "high",
      "alternative_candidates": ["Jane Doe (72)", "Bob Wilson (65)"]
    }
  ],
  "summary": {
    "critical_gaps": 2,
    "moderate_gaps": 3,
    "total_recommendations": 5
  }
}
```

### F. Strategic Pathway Encoding

```python
TRAINING_PATHWAYS = {
    'winger_to_wingback': {
        'from': ['AM(L)', 'AM(R)', 'M(L)', 'M(R)'],
        'to': ['D(L)', 'D(R)'],
        'difficulty': 'moderate',
        'key_attributes': ['Stamina', 'Tackling', 'Positioning'],
        'typical_weeks': 12
    },
    'amc_to_mc': {
        'from': ['AM(C)'],
        'to': ['M(C)'],
        'difficulty': 'easy',
        'key_attributes': ['Stamina', 'Work Rate', 'Tackling'],
        'typical_weeks': 8
    },
    ...
}
```

### G. UI Recommendation Cards

Design spec for training advisor output:
```
┌─────────────────────────────────────────────────┐
│ TRAINING RECOMMENDATION                    ★★★  │
│ ─────────────────────────────────────────────── │
│ Player: John Smith (23, M(C))                   │
│ Target: D(L) - Left Back                        │
│                                                 │
│ Why: Critical gap - only 1 left-back available  │
│ Suitability: 78/100 ████████░░                  │
│ Timeline: ~10 weeks to competent (12/20)        │
│                                                 │
│ Attributes: Good Stamina (15), needs Tackling   │
│             improvement (8 → 12 recommended)     │
│                                                 │
│ [Start Training]  [See Alternatives]            │
└─────────────────────────────────────────────────┘
```

## Validation Criteria

The training recommender is successful if:
- Identifies actual tactical gaps that would cause problems
- Recommends players who can realistically convert
- Provides timeline estimates within ±30% of actual
- Prioritizes high-impact, high-probability conversions
- Doesn't recommend impossible conversions (e.g., GK → ST)

## Output Format

1. **Gap Analysis Algorithm**: Complete specification
2. **Suitability Scoring**: Attribute weights by position
3. **Timeline Model**: Familiarity gain rates and modifiers
4. **Distance Matrix**: Position transition difficulty
5. **Recommendation Logic**: Full decision tree/algorithm
6. **UI Specifications**: Card design and data structure
