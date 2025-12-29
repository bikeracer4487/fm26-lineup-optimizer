# Research Prompt 01: FM26 Game Mechanics Deep Dive

## Context

We are building a companion application for Football Manager 2026 (FM26) that recommends optimal lineups, training, and squad rotation. Before defining our algorithms, we need ground-truth understanding of how FM26 handles player fitness, sharpness, fatigue, and related mechanics.

Previous research documents have made assumptions that may not align with actual FM26 behavior. This research step establishes the factual foundation for all subsequent algorithm design.

## Research Objective

**Goal**: Verify and document the exact mechanics of player physical/mental state in Football Manager 2026, focusing on the factors that affect match performance and injury risk.

## Specific Questions to Answer

### 1. Condition System
- What is the exact range for player Condition in FM26? (0-100? 0-10000?)
- How does Condition affect in-match player performance? (Linear? Threshold-based?)
- At what Condition level does injury risk significantly increase?
- What is the "safe" Condition threshold for starting a player without injury risk?
- How does the Condition display differ from internal values?
- Is there a "condition cliff" where performance drops sharply?

### 2. Match Sharpness System
- What is the internal storage scale for Match Sharpness? (0-100? 0-10000?)
- How does Sharpness affect match performance? (Attribute penalties? Decision-making?)
- What is the Sharpness gain rate from competitive matches vs friendlies?
- What is the decay rate when a player doesn't play?
- Is there a minimum effective Sharpness below which players perform very poorly?
- How does Natural Fitness affect Sharpness gain/decay?

### 3. Fatigue & Jadedness
- Is fatigue a hidden attribute or visible in FM26?
- What causes the "Jaded" status? (Consecutive matches? Total minutes? Both?)
- How does the "Needs a rest" indicator relate to internal fatigue values?
- What player attributes affect fatigue accumulation (Stamina, Natural Fitness)?
- Does age affect fatigue accumulation or recovery rates?
- What are the thresholds for fatigue status indicators (green/yellow/orange/red)?

### 4. Recovery Mechanics
- What is the base recovery rate per day?
- How do Natural Fitness and Stamina affect recovery?
- Does training intensity affect recovery rates?
- Do vacations provide accelerated recovery?
- How quickly does fatigue/jadedness clear?

### 5. Position Familiarity
- What are the familiarity tiers in FM26? (Natural, Accomplished, Competent, etc.)
- What numeric ranges correspond to each tier (1-20 scale)?
- How does low familiarity affect performance? (Attribute penalties? Position-specific?)
- Can players play positions with 0 familiarity in emergencies?

### 6. Role Suitability
- How does role suitability (star rating) translate to match performance?
- Does playing in an unsuitable role have match performance penalties?
- How do In-Possession vs Out-of-Possession role ratings interact?

### 7. Age & Physical Attributes
- Does age directly affect match fatigue accumulation?
- At what ages do players become more susceptible to fatigue/injury?
- How do physical hidden attributes (Injury Proneness) factor in?

## Expected Deliverables

### A. Mechanics Reference Table
A table documenting each mechanic with:
- Internal scale/range
- Display scale/range
- Effect on match performance
- Effect on injury risk
- Key thresholds
- Relevant player attributes

### B. Condition-Performance Curve
Either:
- The exact formula FM uses
- A verified piecewise approximation with thresholds
- References to FM community research that has reverse-engineered this

### C. Sharpness Dynamics
- Gain formula (minutes played, match type, attributes)
- Decay formula (days without match, attributes)
- Performance impact curve

### D. Fatigue/Jadedness Model
- Accumulation triggers
- Recovery mechanics
- Attribute interactions
- Warning thresholds

### E. Familiarity Impact
- Tier definitions with numeric ranges
- Performance penalty per tier
- Which attributes are affected

## Sources to Consider

- Football Manager 2026 official documentation
- Sports Interactive community posts/dev blogs
- FMScout, FM Arena, and other community analysis
- Si Games forums discussions on mechanics
- YouTube content from FM researchers (Zealand, WorkTheSpace, etc.)
- Reddit r/footballmanagergames analysis posts
- Previous FM24 mechanics research (noting any FM26 changes)

## Output Format

Please provide:

1. **Executive Summary**: Key findings in 2-3 paragraphs
2. **Detailed Findings**: Organized by topic (Condition, Sharpness, Fatigue, etc.)
3. **Numeric Tables**: Specific thresholds and formulas where known
4. **Confidence Levels**: Mark findings as "Confirmed", "High Confidence", "Uncertain"
5. **Gaps**: What couldn't be determined and needs testing
6. **Sources**: Citations for key claims

## Validation Criteria

This research is successful if:
- We have specific numeric thresholds (not just "players need good condition")
- We understand the relationship between visible values and internal mechanics
- We can confidently set algorithm parameters based on factual FM behavior
- We identify what FM26 changed compared to FM24 (if anything)
