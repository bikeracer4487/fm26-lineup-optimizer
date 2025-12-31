# Brixham6 - Complete Unique Value Mapping

## The Problem
In Brixham5, multiple attributes shared the same value, making disambiguation impossible.
Example: Corners=1, Decisions=1, Strength=1, GK Familiarity=1

## The Solution
Set EVERY attribute to a UNIQUE value. Since we have ~65 attributes and only values 1-20,
we'll do this in ROUNDS. Each round changes ONE category, then we compare to previous save.

## Already Confirmed (from previous analysis)
| Attribute | Offset | Confidence |
|-----------|--------|------------|
| Sportsmanship | -4115 | High |
| Finishing | -4101 | High |
| First Touch | -4097 | High |
| Heading | -4100 | High |
| Marking | -4098 | High |
| Passing | -4096 | High |
| Penalty Taking | -4095 | High |
| Agility | -4057 | Medium |
| Stamina | -4066 | Medium |
| Injury Proneness | -4055 | Medium |

## Round 1: Technical Attributes Only (Brixham6)

Starting from **original Brixham.fm**, change ONLY Isaac James Smith's **Technical** attributes:

| Attribute | Set To |
|-----------|--------|
| Corners | **1** |
| Crossing | **2** |
| Dribbling | **3** |
| Finishing | **4** |
| First Touch | **5** |
| Free Kicks | **6** |
| Heading | **7** |
| Long Shots | **8** |
| Long Throws | **9** |
| Marking | **10** |
| Passing | **11** |
| Penalty Taking | **12** |
| Tackling | **13** |
| Technique | **14** |

**DO NOT CHANGE** any other attributes (Mental, Physical, Position, Feet, Personality).

Save as **Brixham6.fm**

---

## Round 2: Mental Attributes Only (Brixham7)

Starting from **original Brixham.fm** (NOT Brixham6), change ONLY Isaac's **Mental** attributes:

| Attribute | Set To |
|-----------|--------|
| Aggression | **1** |
| Anticipation | **2** |
| Bravery | **3** |
| Composure | **4** |
| Concentration | **5** |
| Decisions | **6** |
| Determination | **7** |
| Flair | **8** |
| Leadership | **9** |
| Off The Ball | **10** |
| Positioning | **11** |
| Teamwork | **12** |
| Vision | **13** |
| Work Rate | **14** |

Save as **Brixham7.fm**

---

## Round 3: Physical Attributes Only (Brixham8)

Starting from **original Brixham.fm**, change ONLY Isaac's **Physical** attributes:

| Attribute | Set To |
|-----------|--------|
| Acceleration | **1** |
| Agility | **2** |
| Balance | **3** |
| Jumping Reach | **4** |
| Natural Fitness | **5** |
| Pace | **6** |
| Stamina | **7** |
| Strength | **8** |

Save as **Brixham8.fm**

---

## Round 4: Position Familiarity Only (Brixham9)

Starting from **original Brixham.fm**, change ONLY Isaac's **Position Familiarity**:

| Position | Set To |
|----------|--------|
| GK | **1** |
| D(L) | **2** |
| D(C) | **3** |
| D(R) | **4** |
| WB(L) | **5** |
| WB(R) | **6** |
| DM | **7** |
| M(L) | **8** |
| M(C) | **9** |
| M(R) | **10** |
| AM(L) | **11** |
| AM(C) | **12** |
| AM(R) | **13** |
| ST | **14** |

Save as **Brixham9.fm**

---

## Round 5: Hidden + Feet + Personality (Brixham10)

Starting from **original Brixham.fm**, change these:

### Hidden Mental
| Attribute | Set To |
|-----------|--------|
| Consistency | **15** |
| Dirtiness | **16** |
| Important Matches | **17** |

### Hidden Physical
| Attribute | Set To |
|-----------|--------|
| Injury Proneness | **18** |

### Feet
| Attribute | Set To |
|-----------|--------|
| Left Foot | **19** |
| Right Foot | **20** |

### Personality
| Attribute | Set To |
|-----------|--------|
| Adaptability | **1** |
| Ambition | **2** |
| Controversy | **3** |
| Loyalty | **4** |
| Pressure | **5** |
| Professionalism | **6** |
| Sportsmanship | **7** |
| Temperament | **8** |
| Versatility | **9** |

Save as **Brixham10.fm**

---

## After Creating Each Save

Run the analysis script and I'll map the attributes for that category.
Each comparison will definitively map 14-17 attributes.

By the end of 5 rounds, we'll have ALL ~65 attributes mapped!
