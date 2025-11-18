# Advanced Features Guide - FM26 Lineup Optimizer

This guide covers the advanced scripts that factor in player status attributes, match scheduling, and intelligent rotation planning.

## Overview

The FM26 Lineup Optimizer now includes two advanced scripts that go beyond simple position ratings:

1. **Training Distribution Advisor** (`fm_training_advisor.py`) - Analyzes squad depth and recommends which players should train which positions
2. **Match-Ready Selector** (`fm_match_ready_selector.py`) - Selects optimal lineups considering fatigue, condition, match sharpness, and fixture scheduling

## Prerequisites

### Required Data

Both scripts require a comprehensive player CSV export with the following columns:

**Player Information:**
- Name
- Age
- Positions
- CA (Current Ability)
- PA (Potential Ability)

**Status Attributes:**
- `Condition (%)` - Physical condition (0-100% or 0-10000 scale)
- `Fatigue` - Jadedness value (can be negative to ~1000)
- `Match Sharpness` - Match readiness (5000-10000 scale, where 10000 = 100%)
- `Is Injured` - Boolean indicating injury status
- `Banned` - Boolean indicating suspension status

**Positional Skill Ratings (1-20 scale):**
- GoalKeeper
- Defender Right
- Defender Center
- Defender Left
- Defensive Midfielder
- Attacking Mid. Right
- Attacking Mid. Center
- Attacking Mid. Left
- Striker

**Optional Attributes (improve recommendations):**
- Natural Fitness
- Versatility
- Professionalism
- Stamina
- Work Rate

### Exporting Player Data from FM26

To get this data from Football Manager 2026:

1. Go to Squad → Development
2. Add all required columns to the view
3. Export to CSV (right-click → Export)
4. Save as `players-current.csv` in the project directory

---

## 1. Training Distribution Advisor

### Purpose

Analyzes your squad's positional depth and quality, then recommends which players should train which positions to improve coverage across all positions in your 4-2-3-1 formation.

### How It Works

The advisor analyzes BOTH familiarity AND ability:
1. **Positional Skill Ratings** (1-20 familiarity scale) - How familiar players are with each position
2. **Role Ability Ratings** (calculated from attributes) - How GOOD players are at each position
3. Identifies positions with quality gaps (not just coverage, but actual ability)
4. Recommends players to train based on:
   - **Current ability at the position** - Players with good attributes but low familiarity
   - **Age** - Younger players (under 24) retrain faster
   - **Versatility** - Higher versatility = faster position learning
   - **Professionalism** - Higher professionalism = more effective training
   - **Training category**:
     - *Become Natural*: Players with good ability who should reach Natural (18+) familiarity
     - *Improve Natural*: Players already Natural but need to improve their ability
     - *Learn Position*: Players with potential who should train into a new position

### Required Data Files

The training advisor works best with **TWO separate CSV files**:

1. **players-current.csv** - Positional skill ratings + attributes + status
   - Export from: Squad → Development → Include ALL columns
   - Must have: Positional skill ratings (GoalKeeper, Defender Right, Defender Center, etc. on 1-20 scale)
   - Must have: Attributes (Age, Versatility, Professionalism, CA, PA, etc.)
   - Must have: Status (Condition, Fatigue, Match Sharpness)

2. **players.csv** - Role ability ratings
   - Export from: Squad view with role rating columns visible
   - Must have: Name, Striker, AM(L), AM(C), AM(R), DM(L), DM(R), D(C), D(R/L), GK
   - These are the calculated ratings showing how good each player is at each role based on their attributes

**Important:** Role ability ratings are DIFFERENT from positional skill ratings!
- **Positional skill rating** (1-20): How familiar/comfortable a player is with a position (Natural, Accomplished, etc.)
- **Role ability rating** (0-200): How good a player actually is at that role based on their attributes

**Quality Assessment Method:**
The advisor uses **squad-relative percentiles** to evaluate player quality, not absolute thresholds. This means:
- A rating of 140/200 might be "Excellent" in League Two but only "Adequate" in the Premier League
- Quality tiers (Excellent, Good, etc.) are determined by comparing each player to the rest of your squad
- This ensures recommendations are relevant regardless of what level you're playing at

### Usage

```bash
# Recommended: Provide both files for intelligent recommendations
python fm_training_advisor.py players-current.csv players.csv

# Limited mode: Only positional skill ratings (no quality analysis)
python fm_training_advisor.py players-current.csv
```

### Output

The script provides two main sections:

#### 1. Squad Depth & Quality Analysis

Shows all players capable of playing each position, with both familiarity and ability ratings:

**With both files (recommended):**
```
D(C)     (Need 2 in XI, want 2+ competent & 1+ good quality):
  ✓ ⭐ Jada Mawongo                Natural         (20.0/20) | Excellent  ability (165.0/200)
  ✓ ✓✓ Joe Cassidy                 Natural         (20.0/20) | Good       ability (142.0/200)
  ✓ → Sam Joce                     Natural         (20.0/20) | Adequate   ability (128.0/200)
  >>> QUALITY GAP: Need 1 more good-quality player(s)
```

**With status file only:**
```
D(C)     (Need 2 in XI, want 2+ competent):
  ✓ Jada Mawongo                   Natural         (20.0/20)
  ✓ Joe Cassidy                    Natural         (20.0/20)
  ✓ Sam Joce                       Natural         (20.0/20)
```

**Indicators:**
- ✓ = Competent or better (familiarity rating ≥ 10)
- ⚠ = Below competent (familiarity rating < 10)
- ⭐ = Excellent ability (17+)
- ✓✓ = Good ability (15+)
- → = Adequate ability (13+)
- ⚠ = Below standard ability

#### 2. Training Recommendations

Lists players who should train positions, categorized by type and prioritized by urgency:

**With both files (intelligent recommendations):**
```
HIGH PRIORITY (Address quality gaps):
  Player: Marc Mitchell            → Train as: DM       [Become Natural]
         Familiarity: Competent      (12.0/20) | Ability: Good       (148.0/200)
         Age: 16 | Training Score: 0.75 | Good ability, train to become natural | very young (16)

MEDIUM PRIORITY (Improve existing players):
  Player: Asa Hall                 → Train as: DM       [Improve Natural]
         Familiarity: Natural        (18.0/20) | Ability: Adequate   (132.0/200)
         Age: 39 | Training Score: 0.45 | Already natural, train to improve ability
```

**Without abilities file:**
```
⚠️  Cannot provide training recommendations without role ability data.

To get intelligent training recommendations:
  1. Export player role ability ratings from FM26
  2. Save as players.csv
  3. Run: python fm_training_advisor.py players-current.csv players.csv
```

### Interpretation

**Training Categories:**
- **Become Natural**: Player has good ability at the position (15+ rating) but isn't Natural yet (< 18 familiarity). Should train to reach Natural status for optimal performance.
- **Improve Natural**: Player is already Natural (18+ familiarity) but their ability at the position needs improvement (< 15 rating). Training the position will improve their attribute-based effectiveness.
- **Learn Position**: Player has potential at the position (13+ ability) but low familiarity (< 10). Longer-term investment for young players or those natural in similar positions.

**Positional Familiarity Tiers:**
- **Natural (18-20)**: Full ability, no performance penalty
- **Accomplished (13-17)**: ~10% performance reduction
- **Competent (10-12)**: ~15% performance reduction
- **Unconvincing (6-9)**: ~20% performance reduction
- **Awkward (5-8)**: ~35% performance reduction
- **Ineffectual (1-4)**: ~40% performance reduction

**Role Ability Quality Tiers (Squad-Relative Percentiles):**
- **Excellent**: Top 10% of your squad at this position (90th percentile+)
- **Good**: Top 25% of your squad at this position (75th percentile+)
- **Adequate**: Above squad median at this position (50th percentile+)
- **Poor**: Below squad median (25th-50th percentile)
- **Inadequate**: Bottom 25% of your squad (below 25th percentile)

**Note:** These tiers adapt to your squad's level. A "Good" player in League Two has different absolute ratings than a "Good" player in the Premier League, but both are in the top 25% of their respective squads.

**Training Timelines:**
- Competent level: 6-9 months of training + match experience
- Accomplished level: 12 months total
- Natural level: 12-24 months (requires regular matches)

**Key Factors:**
- Younger players (under 24) learn faster
- High Versatility attribute accelerates retraining significantly
- High Professionalism improves training effectiveness
- Players need BOTH individual training AND match experience
- Similar positions retrain faster (e.g., DL → DR, AM(C) → ST)
- Training Score (0-1) combines age, versatility, professionalism, and growth potential

---

## 2. Match-Ready Selector

### Purpose

Selects optimal lineups for upcoming matches by considering player fitness status, match scheduling, and intelligent rotation to manage fatigue and match sharpness.

### How It Works

The selector calculates an **effective rating** for each player-position combination by factoring in:

1. **Base Positional Rating** - The player's skill rating for that position (1-20)
2. **Familiarity Penalty** - Based on positional tier (Natural = 0%, Ineffectual = 40%)
3. **Match Sharpness** - Players below 80% perform worse but NEED playing time
4. **Physical Condition** - Low condition increases injury risk and reduces performance
5. **Fatigue** - Critical threshold at 400 (warnings appear), significant penalties above 500
6. **Match Importance** - Penalties amplified for important matches
7. **Rotation Strategy** - Balances rest needs with sharpness development

### Usage

```bash
# Interactive mode (asks for match details)
python fm_match_ready_selector.py

# Or specify custom file
python fm_match_ready_selector.py path/to/your/players.csv
```

The script will prompt you for:
1. Current date (YYYY-MM-DD)
2. Next 3 match dates and importance levels (Low/Medium/High)

### Example Session

```
Enter current date (YYYY-MM-DD): 2025-01-15

Enter details for next 3 matches:

Match 1:
  Date (YYYY-MM-DD): 2025-01-18
  Importance (Low/Medium/High): High

Match 2:
  Date (YYYY-MM-DD): 2025-01-22
  Importance (Low/Medium/High): Medium

Match 3:
  Date (YYYY-MM-DD): 2025-01-25
  Importance (Low/Medium/High): Low
```

### Output

The script provides multiple sections:

#### 1. Match Schedule Overview

```
Current Date: 2025-01-15

Upcoming Matches:
  1. 2025-01-18 (3 days) - High importance
  2. 2025-01-22 (7 days) - Medium importance
  3. 2025-01-25 (10 days) - Low importance
```

#### 2. Lineup for Each Match

For each match, shows:

```
LINEUP FOR MATCH 1: 2025-01-18 (High importance, 3 days)

Starting XI:

Goalkeeper:
  GK    : Ashley Sarahs             (Eff: 20.0) [Cond:  92% | Fatigue:  101 | Sharp: 100%] ⭐

Defence:
  DL    : Junior McQuilken          (Eff: 19.0) [Cond:  95% | Fatigue: -103 | Sharp: 79%] 🔄
  ...

Team Average Effective Rating: 19.46
```

**Status Icons:**
- ⭐ Peak form (high condition, low fatigue, high sharpness)
- 💤 High fatigue (≥400, needs rest)
- ❤️ Low condition (<80%, injury risk)
- 🔄 Needs match sharpness (<80%)

#### 3. Rotation Summary

Shows how many matches each player appears in and identifies unused players who need sharpness development:

```
Player appearances across 3 matches:

  Asa Hall                  - 3 matches  (DM(R), DM(R), DM(R))
  Ashley Sarahs             - 3 matches  (GK, GK, GK)
  ...

Players not selected (consider for reserves/friendlies for sharpness):
  Bradley Lethbridge        - Sharpness: 75%
  Scott Aldridge            - Sharpness: 60%
```

#### 4. Training Recommendations

Suggests training focus based on overall squad status:

```
Squad Status:
  Players with high fatigue (≥400):     2
  Players with low condition (<80%):    8
  Players with low sharpness (<80%):    12

Recommendations:
  ⚠️  HIGH PRIORITY: Schedule rest sessions - many players fatigued
     Consider sending 1-2 most fatigued players on vacation
  ⚠️  MEDIUM PRIORITY: Schedule friendly matches for fringe players
     Consider match practice sessions in training
```

### Intelligent Rotation Features

The selector automatically:

1. **Rests High-Fatigue Players Before Important Matches**
   - If a high-importance match is coming within 3 days, fatigued players are rested

2. **Prioritizes Sharpness Development in Low-Importance Matches**
   - Low-sharpness players get a rating boost in unimportant matches
   - Helps maintain squad sharpness across the season

3. **Balances Match Fitness with Performance**
   - For important matches: Prioritizes best effective ratings (even if players need rest afterward)
   - For unimportant matches: Rotates in fringe players who need minutes

4. **Considers Recovery Time**
   - Tracks days between matches
   - Adjusts rotation strategy based on fixture congestion

---

## Understanding the Mechanics

### Match Sharpness

**Scale:** 5,000 - 10,000 (displayed as 50% - 100%)

**Effects:**
- Below 60%: Severe performance penalty, high injury risk
- 60-75%: Moderate performance penalty
- 75-85%: Minor performance penalty
- 85-100%: Optimal performance

**How to Improve:**
- Playing in matches (primary method)
  - ~10 minutes = +1% sharpness
  - ~25 minutes = +2% sharpness
  - ~45 minutes = +3% sharpness
  - 60+ minutes = +4% sharpness
- Friendlies and reserve matches
- Match Practice training sessions (limited effect)

**How It Declines:**
- Lack of game time
- Rest sessions (trade-off for condition recovery)
- Recovery sessions (slower decline than rest)

### Physical Condition

**Scale:** 0-100% (or 0-10,000 internally)

**Effects:**
- 100%: Peak performance
- 90-100%: Minimal impact
- 80-90%: Minor performance reduction
- 70-80%: Moderate reduction, increased injury risk
- Below 70%: Severe reduction, high injury risk

**Depletion:**
- 15-20% per match half
- Full match: ~75% final condition

**Recovery:**
- Natural recovery occurs daily at midnight
- Recovery rate depends on **Natural Fitness** attribute
- Rest sessions provide fastest recovery (~39% over 3 days)
- Standard training slows recovery
- Full recovery takes ~10 days

### Fatigue (Jadedness)

**Scale:** Negative values to ~1,000

**Critical Thresholds:**
- Below 0: Under-conditioned (negative fatigue)
- 0-350: Fresh, optimal performance
- 400-500: "Becoming Fatigued" warning appears
- 500+: Severe fatigue, significant penalties

**Effects at 400+ Fatigue:**
- Performance degradation
- Increased injury risk
- Slower condition recovery between matches

**How to Reduce:**
- **Vacation** (most effective): ~152 points recovery over 3 days with rest sessions
- Rest sessions: ~101 points over 3 days
- Recovery sessions: ~48-51 points over 3 days
- Manual rest: ~137 points over 3 days
- Reduce training intensity
- Avoid playing the player

**When to Rest Players:**
- Fatigue ≥ 400 (when warnings appear)
- Before important matches if fatigue > 300
- Proactive vacation during low-priority matches

---

## Best Practices

### Managing Match Sharpness

1. **Rotate intelligently** - Use all 3 substitutes each match to give fringe players minutes
2. **Schedule friendlies** - Arrange matches for non-first-team players
3. **Use recovery > rest** - Recovery sessions minimize sharpness loss while improving condition
4. **Monitor the 80% threshold** - Players below 80% should get minutes in less important matches

### Managing Fatigue

1. **Watch the 400 threshold** - When players hit 400 fatigue, they need rest
2. **Proactive vacations** - Send key players on 1-week vacations twice per season during low-priority matches
3. **Reduce training intensity during congested periods**
4. **Use rest sessions liberally** - Rest recovers fatigue ~2x faster than recovery sessions

### Managing Physical Condition

1. **Full recovery takes 10 days** - Plan rotation accordingly
2. **Never start players below 80% in important matches** - Injury risk is too high
3. **Natural Fitness matters** - Prioritize signing players with Natural Fitness 14+
4. **Balance training intensity** - Lower intensity during fixture congestion

### Fixture Congestion Strategy

**Multiple matches per week:**
1. Identify your most important match
2. Rest high-fatigue players before that match
3. Use low-importance matches for fringe players who need sharpness
4. Schedule rest sessions between matches
5. Consider sending 1-2 most fatigued players on vacation

**Example for 3 matches in 7 days:**
- Match 1 (Cup, High importance): Best XI, even if fatigued
- Match 2 (League, Medium): Rotate in 3-4 fresh players
- Match 3 (Friendly, Low): Full rotation squad, prioritize low-sharpness players

---

## Integration with Existing Scripts

### Workflow Recommendation

1. **Start of Season:**
   - Run `fm_training_advisor.py` to identify depth gaps
   - Set individual training for recommended players

2. **Weekly Match Planning:**
   - Run `fm_match_ready_selector.py` before each match week
   - Review upcoming fixtures and set rotation strategy

3. **Mid-Season Check:**
   - Re-run `fm_training_advisor.py` to reassess depth
   - Check if retrained players have progressed

4. **Optimal Selection Comparison:**
   - Run `fm_team_selector_optimal.py` to see theoretical best XI
   - Compare with match-ready selection to understand fitness impact
   - Use optimal selector for "dream team" scenarios

5. **Squad Depth Planning:**
   - Use `fm_rotation_selector.py` for dual-squad selection
   - Combine with match-ready selector for fixture congestion

---

## Troubleshooting

### "NO PLAYER FOUND" for a position

**Causes:**
1. All players at that position are injured or suspended
2. Position column name doesn't match data
3. No players have positive ratings for that position

**Solutions:**
- Check injury/suspension status in FM26
- Verify CSV column names match expected format
- Emergency retrain a player to cover the position

### Players with very low effective ratings

**Causes:**
- Multiple penalties stacking (low condition + high fatigue + low sharpness)
- Player is ineffectual at the position (rating < 5)

**Solutions:**
- Rest the player if fatigued
- Give playing time if sharpness is low
- Don't play players below 70% condition in important matches

### Script says "No training recommendations needed" but squad feels thin

**Possible reasons:**
- You have 2+ competent players per position (script threshold)
- Players are natural in multiple positions, providing hidden depth
- Some players can cover multiple positions effectively

**Check:**
- Run depth analysis to see actual ratings
- Consider that versatile players provide coverage across similar positions

---

## Technical Details

### Effective Rating Calculation Formula

```python
effective_rating = base_positional_rating
effective_rating *= (1 - familiarity_penalty)      # 0-40% based on tier
effective_rating *= sharpness_factor                # 0.70-1.10 based on sharpness & strategy
effective_rating *= condition_factor                # 0.60-1.00 based on condition
effective_rating *= fatigue_factor                  # 0.65-1.00 based on fatigue
effective_rating *= importance_modifier             # Extra penalty for unfit in important matches
```

### Algorithm

Both scripts use the **Hungarian Algorithm** (via `scipy.optimize.linear_sum_assignment`) to find the optimal player-position assignment that maximizes team effective rating while ensuring each player is assigned to exactly one position.

---

## See Also

- [README.md](README.md) - General usage guide
- [CLAUDE.md](CLAUDE.md) - Developer documentation
- [PROJECT_SUMMARY.md](PROJECT_SUMMARY.md) - Project overview
- [QUICKSTART.md](QUICKSTART.md) - Getting started guide

---

## Support

For issues or questions:
1. Check this documentation first
2. Verify your CSV has all required columns
3. Check column names match exactly (case-sensitive)
4. Ensure data is exported from FM26 (not FM25 or earlier)

## License

MIT License - See [LICENSE.md](LICENSE.md)

**Author:** Doug Mason (2025)
