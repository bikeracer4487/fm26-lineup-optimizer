# Physical condition mechanics in FM26 and their impact on match performance

Match sharpness is the most impactful factor on player performance in Football Manager 26, with a **10-percentage-point difference (90% vs 100%) causing a 33% reduction in win rate**—more significant than improving Pace and Acceleration from 10 to 18. Condition affects both performance and injury risk, with players at **70% condition experiencing approximately 32% performance degradation** compared to peak fitness. The core mechanics remain unchanged from FM24, making existing community research directly applicable to algorithm development.

## Condition operates on a 0-100% energy scale with predictable recovery

Condition represents a player's energy and freshness level, displayed as a percentage or heart icon in FM26. A player starting at 100% condition typically drops to **approximately 75% after a full 90-minute match**, though this varies based on tactical intensity, player roles, and individual attributes.

Recovery follows a consistent pattern documented by FM-Arena testing:

| Days Post-Match | Condition % |
|----------------|-------------|
| Match End | ~75% |
| Day 2 | 83% |
| Day 3 | 90% |
| Day 5 | 95% |
| Day 7 | 97% |
| Day 10 | 100% |

**Natural Fitness** is the primary attribute affecting recovery rate—players with 20 Natural Fitness recover to 74% immediately post-match, while those with low Natural Fitness recover to only 66%. **Stamina** affects in-match depletion rate rather than recovery. High Work Rate, Aggression, and pressing-intensive tactical instructions accelerate condition depletion during matches.

## Match sharpness determines competitive readiness and dominates performance calculations

Match sharpness represents how match-ready a player is, distinct from condition. While condition recovers within days through rest, sharpness is **only gained through actual match play** and decays without games.

**Sharpness gain rates per 90 minutes (EBFM testing):**
- Competitive matches: **9% maximum** (diminishing returns at higher levels)
- At 50-65% sharpness: 9% gain per match
- At 80% sharpness: 6% gain per match  
- At 90% sharpness: only 2% gain per match
- Friendlies: **5% maximum** (55% of competitive rate)

**Sharpness decay varies dramatically by Natural Fitness:**
- 10 Natural Fitness: loses 7% in 14 days, 22% in 4 weeks
- 20 Natural Fitness: loses only 2% in 3 weeks, 6% in 4 weeks

The critical finding for algorithm development: the **33% win rate difference between 90% and 100% sharpness** exceeds the impact of major attribute improvements. This makes sharpness the single most important factor after core ability.

## Jadedness is a hidden cumulative fatigue state with long recovery requirements

Unlike condition (visible, fast recovery), jadedness is a **hidden attribute ranging from approximately -500 to +1000** on an internal scale. Negative values indicate freshness; positive values indicate accumulated fatigue.

Players become jaded through:
- Playing consecutive competitive matches
- Heavy training loads
- Long travel distances
- Congested fixture schedules

**Young developing players and older players past physical peak accumulate jadedness faster** than those aged 22-33. Jaded players exhibit three compounding problems: performances suffer, condition drops faster during matches, and condition recovers more slowly afterward.

Recovery requires extended periods without matches—holidays and rest are most effective. The community-discovered "rest exploit" works in FM26: assigning one day of rest immediately post-match provides significant condition recovery and jadedness reduction.

## Quantitative attribute penalties follow approximately linear relationships

FM-Arena testing on FM23/24 (mechanics unchanged in FM26) provides the most rigorous quantitative data for algorithm development:

**Condition impact on season performance (38 matches):**
- 100% → 85% ("Good"): approximately 11% performance reduction (~6 league points)
- 100% → 70% ("Fair"): approximately **32% performance reduction** (~17 league points)

The relationship is non-linear—performance degradation accelerates below 80% condition.

**Attribute testing revealed clear hierarchies:**
Physical attributes dominate match outcomes. Pace and Acceleration from 8→20 each add **+64 league points** over a season. Stamina adds +19 points. Mental attributes like Anticipation (+18) and Work Rate (+12) show moderate impact. Notably, several mental attributes including Aggression, Bravery, Flair, and Teamwork showed **no measurable effect** in controlled testing—these appear largely decorative in the match engine.

Internal fatigue operates on a -500 to +1000 scale, with **optimal performance at approximately 0** (the Fresh/Low transition point). The "Rst" (rest needed) icon appears around 600+, indicating significant performance penalties.

## Performance modifiers for algorithm implementation

Based on synthesized community research, the following quantitative relationships can inform a Match Rating algorithm:

**Condition Modifier (estimated from testing):**
- 100%: 1.00 (baseline)
- 90%: ~0.95
- 85%: ~0.89
- 80%: ~0.80
- 70%: ~0.68

**Match Sharpness** has the largest confirmed impact but lacks granular testing data beyond the 90% vs 100% comparison. The 33% win rate difference suggests sharpness may function as a significant multiplier—conservatively, a **0.67 modifier at 90% relative to 100%** for match-critical calculations.

**Suggested formula structure:**
```
Effective_Performance = Base_Ability × Condition_Modifier × Sharpness_Modifier × (Minor: Morale, Consistency)
```

Where physical attributes (especially Pace, Acceleration, Stamina) should be weighted heavily in Base_Ability calculations.

## Critical thresholds and practical breakpoints

Community consensus and testing identify these operational thresholds:

- **85% condition minimum** for starting players (below this, injury risk increases significantly)
- **90%+ sharpness** for optimal performance (below 90% represents measurable degradation)
- **Natural Fitness 12+** recommended for regular starters (determines sustainable rotation frequency)
- **Internal fatigue 400-500+** triggers assistant manager warnings and elevated injury risk

For match sharpness maintenance: players with 10 Natural Fitness must play every 8 days; those with 20 Natural Fitness can maintain sharpness playing every 21 days.

## Conclusion: key parameters for algorithm design

The research reveals that **match sharpness is the dominant performance factor** often overlooked in favor of condition. A player at 95% condition but 85% sharpness will underperform relative to a player at 90% condition and 100% sharpness. 

For algorithm implementation, prioritize sharpness as the primary multiplier, condition as a secondary modifier with accelerating penalties below 80%, and weight physical attributes (Pace, Acceleration, Stamina) heavily in base calculations. The approximately linear relationship between attributes and performance simplifies modeling, though condition's non-linear degradation curve requires careful threshold handling.

FM26 uses identical mechanics to FM24—all quantitative findings from FM-Arena and EBFM testing apply directly. Known FM26 bugs affect UI display of sharpness but not underlying calculations.