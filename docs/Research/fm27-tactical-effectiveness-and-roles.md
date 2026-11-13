# FM27 Tactical Effectiveness, roles, familiarity and cohesion: research for the lineup optimizer

Compiled 12 November 2026, two days after FM27's release (10 November 2026). The live game is version 27.0.1. Some sources tested the Launch Preview build (out from 29 October), and some worked from pre-release development footage. The source table at the end gives the date and build for each.

## How claims are labelled

| Label | Meaning |
|---|---|
| **[SI]** | Official Sports Interactive material: footballmanager.com features, The Dugout guides, SI forum FAQ posts |
| **[FM27-DATA]** | FM27 community testing that publishes data: engine experiments, reverse engineering, or data transcribed from the game |
| **[FM27-OBS]** | FM27 press or community descriptions of what the game shows, with no test data. *This is a fifth label I added.* These sources describe the FM27 UI, so they are neither SI material nor FM26 carry-over, and calling them "testing" would overstate them. |
| **[FM26-CARRY]** | FM26 (or older) knowledge assumed to still apply. No FM27 confirmation found. |
| **[SPEC]** | Speculation or inference, including mine. The reasoning is given each time. |

Where I found no FM27 evidence, the text says **NO FM27 EVIDENCE FOUND**.

---

## Summary for the optimizer

1. **The match engine reads per-player Tactical Understanding, not the role-suitability number.** The most rigorous FM27 engine study ran about 220,000 simulated matches on version 27.0.1. It found the engine reads, for each player, eight "tactical area" values plus tactical ability and tactic complexity. It ignores the Player Ability bytes (capability and role suitability) and the headline TE number. [FM27-DATA, Fm-Match-Lab, 10–11 Nov 2026] This comes from one club's matches, so treat it as strong but not final.
2. **Role key/preferable attribute lists drive the suitability *display*.** They are not direct engine weights. In engine tests, physical attributes (Pace, Acceleration, Jumping Reach, Stamina) dominate under every playing style, while many technical attributes show no clear single-match effect. [FM27-DATA] If you score roles only by in-game key attributes, you are reproducing SI's suitability rating, not match value.
3. **Positional familiarity matters a lot in FM27.** Capping every starter's position rating at 15 cost 0.26 points per game. Capping at 10 cost 0.85, roughly the cost of half the team being badly unsharp. [FM27-DATA] Only these two levels were tested. No per-tier curve exists yet.
4. **Familiarity is per phase, but the engine detail is unknown.** SI says a player's effectiveness can drop if his *out-of-possession* role needs positional familiarity he lacks. Scout reports show fit per position both with and without the ball. [SI / FM27-OBS] How the engine combines a player's IP and OOP position ratings: **NO FM27 EVIDENCE FOUND**.
5. **Tactical Understanding is per player and builds through training and starts.** Match exposure rises only for starters, about +2 per area per match. Training counts about twice as much as exposure, decays over weeks, and the benefit plateaus around the middle of the scale. [FM27-DATA]
6. **Team cohesion is a team-level value with a confirmed, moderate effect.** The match's highest versus lowest value is worth about +0.2 to +0.3 points per game. [FM27-DATA] Whether rotating the XI lowers cohesion in FM27: **NO FM27 EVIDENCE FOUND**.
7. **The FM27 role set has 79 roles (40 IP, 39 OOP) and no duties.** [FM27-DATA, transcribed from the game] SI has published no FM27 list of added, removed or renamed roles, and I could not build a reliable FM26-to-FM27 diff (see §3.3).

A machine-readable roles file accompanies this document: `fm27_roles.json`.

---

## 1. What Tactical Effectiveness is

### 1.1 Definition and inputs

- TE is an overarching FM27 feature that connects Training, Tactics, Scouting and more, and builds on FM26's Tactical Familiarity. Four areas feed it: **Tactical Understanding, Player Ability, Player Buy-In and Next Match Information**. **[SI]** (FM27 Training & Tactical Effectiveness feature and FAQ, posted 9 Oct 2026)
- **Tactical Complexity** is a new measure tied to TE. It reflects the volume of team, player and opposition instructions, and the positions you set. Simple plans work quickly but plateau. Complex plans take longer but have a higher ceiling. **[SI]** (same feature)
- TE fluctuates with your decisions, player performances and wider events. **[SI]** (same)
- SI's guide of 6 Nov 2026 lists the factors under each area. **[SI]** (The Dugout, "Tactical Effectiveness: Understanding FM27's Key New Feature", FM Stag)
  - **Tactical Understanding:** shape maintenance, defensive line height, pressing timing and intensity, patience in possession. Built by tactical training and by consistency over time. Familiarity with the manager carries over from previous clubs. You can prepare up to three tactics, but alternates are never as familiar as the primary one.
  - **Player Ability:** attributes, qualities, positional suitability, and comfort in both the in-possession and out-of-possession roles.
  - **Player Buy-In:** belief in and respect for the manager, squad relationships and cohesion, leadership, personality management, and the Hierarchy and Social Groups systems.
  - **Next Match Info:** quality of opposition scouting reports (scouting staff ability and the opposition-report responsibility), and knowledge of the opposition's players and league.
- The in-game factor names, from SI's development-build livestream and screenshots: **[FM27-OBS]** (FM Scout, 9 Oct 2026)
  - Tactical Understanding: eight tactic parts (In Possession Shape, Passing Style, Build Up, Chance Creation, Out Of Possession Shape, Line of Engagement, Pressing Intensity, Pressing Trap), players' tactical skill, and tactic complexity.
  - Player Ability: Player Capability, Player Role Suitability.
  - Player Buy-In: Managerial Support, Teammate and Staff Relationships, Manager Tendencies.
  - Next Match Info: Quality of the Next Opposition Report, Opposition Player Knowledge.
- That list totals 17 factors (8 + 2 + 2 + 3 + 2). This matches a community tool that reads the breakdown screen and describes it as "4 components, 17 key factors". **[SPEC: my count; the tool description is FM27-OBS]** (sortitoutsi FM27 Trainer thread, about 11 Nov 2026)
- Every AI club and manager also uses TE, which affects their performance and recruitment. **[SI]** (Dugout, 6 Nov 2026)

### 1.2 How it is calculated (community reverse engineering)

- **Headline TE** = 50% Tactical Understanding + 10% Player Ability + 25% Player Buy-In + 15% Next Match Info, on a 0–100 scale. **[FM27-DATA]** This was reverse-engineered by lqf0624 (playgm forum) and reposted by harvestgreen22 on sortitoutsi (about 9 Nov 2026). Fm-Match-Lab found these weights describe the *panel*, but the match itself does not read the headline number.
- **Each Tactical Understanding area** = player tactical ability + tactic simplicity + match exposure + training contribution for that area. **[FM27-DATA]**
  - Engine weights for one record mode: training 0.6, exposure 0.3, tactical ability 0.25, simplicity 0.25. Each area is capped at 100. (Fm-Match-Lab, Study 3)
  - A forum summary describes the four parts instead as 12.5% each of the 50% Understanding share. (ZaZ, SI forum and FM-Arena, about 10–11 Nov) The two descriptions differ, and Match-Lab's comes from decoded engine records.
- **Player tactical ability** = median of Anticipation, Decisions, Composure, Concentration and Versatility (hidden), rescaled. **[FM27-DATA]** Match-Lab confirmed the formula exactly for all 44 players in two matches. Because it is a median, raising one of those attributes only helps if it moves the median.
- **Complexity cost:** in one save, a team-complexity value of 78 (against 4 for an AI opponent) cost every player about 20 points per area before training and exposure. **[FM27-DATA]** (Match-Lab)
- **Decay:** the training part fades between sessions. One tester reads the game's data as each session's contribution halving after about three weeks. A forum post gives 38 points per day of decay on a 10,000 scale, with about 300 points per match. **[FM27-DATA]** (Match-Lab Study 3 and its OTHER-TESTS page; ZaZ post)

### 1.3 Per player, per unit or per team?

- **Per player.** The engine builds a 33-byte effectiveness record for every player before kick-off and reads it during play. **[FM27-DATA]** (Match-Lab)
  - The record holds the eight area values (training and exposure parts), tactical ability, team and per-role complexity, capability, role suitability, buy-in and next-match info.
  - The AI side's record has no per-area detail: one value covers all IP areas and one covers all OOP areas.
- **Shown per player and per team.** A "Player View" shows each player's meter, and the Training menu shows an Overall Effectiveness meter for each tactic. **[FM27-OBS]** (FM Scout, 9 Oct, dev build) TheGamer (12 Nov) describes a per-player TE screen with staff recommendations, and a team TE that rises as individuals improve. **[FM27-OBS]**
- **Per unit:** **NO FM27 EVIDENCE FOUND** of a defence, midfield or attack breakdown.
- **Display format:**
  - Gauges, meters and segmented pies, with no number shown. **[SI / FM27-OBS / FM27-DATA]** Match-Lab matched pie fill to record bytes.
  - Tactics now carry Intensity, Complexity and Effectiveness ratings. **[FM27-OBS]** (FM Scout new-features page)
  - In Scout Reports you choose one of your tactics and see the player's fit for each position, with and without the ball. **[FM27-OBS]** (FM Scout, 9 Oct)

### 1.4 How much it affects match performance

All figures below are **[FM27-DATA]**.

| Finding | Source and method |
|---|---|
| All 8 areas at 0 → −0.33 ppg, −0.47 xGD. From 50 up: +0.2–0.3 ppg, +0.3–0.4 xGD. 90 and 100 produce identical matches (cap). Bottom to plateau ≈ +0.5 ppg. | Fm-Match-Lab Study 3: 27.0.1 engine run outside the game, one newly promoted EPL club's 10 real matches, 300 paired seeds per condition, about 15,000 matches |
| Training part 0 → −0.40 ppg. Training 75 → +0.21 ppg, then flat. Exposure matters about half as much as training. | same |
| Raising one area alone gives no clear gain. Untrained Pressing Intensity hurt most (−0.32 xGD) for this pressing side. | same |
| **The engine ignores Player Ability (capability, role suitability) and the overall value.** Buy-In and Next Match Info alone show no measurable single-match effect. | same. The authors note these may act through other paths when the game rebuilds records day by day. |
| Familiarity from low (20) to high (80) ≈ +0.52 ppg, about the same as +7 Pace across the whole squad. Attributes and familiarity add up rather than interact. | Match-Lab Study 4 |
| +30% Tactical Understanding (8 sessions/week against none) → +3.5% win rate. About 25 TE gives most of the benefit, and 50 adds only slightly. | harvestgreen22, in-game seasons with FMRTE (sortitoutsi and FM-Arena, about 3–9 Nov, likely Launch Preview) |

How the sources interpret this:

- SI frames TE as central, but publishes no numbers. **[SI]**
- Destructoid (5 Nov) calls it the biggest current influence on results. **[FM27-OBS]**
- The data says Tactical Understanding is worth real points (up to about half a point per game between untrained and trained). It is smaller than condition and sharpness, which cost 0.8–1.0 ppg at 80% condition or 50% sharpness. **[FM27-DATA]**
- The "only matters at low levels" reading (harvestgreen22) and the "worth +0.5 ppg" reading (Match-Lab) agree once you allow for the starting point. Topping up an already learned tactic gains little. An untrained tactic costs a lot.

---

## 2. Does it change how positional or role suitability should be judged?

**FM26 baseline [FM26-CARRY]**
- SI said a player's suitability for an OOP role depends on positional familiarity and the role's key attributes. Each IP and OOP role is star-rated. (SI FM26 feature, 2025)
- The Combined view averages a player's IP and OOP star ratings. (Passion4FM FM26 guide)

**What FM27 adds [SI]**
- Positional suitability and comfort in *both* the IP and OOP roles sit explicitly inside Player Ability. (Dugout, 6 Nov)
- SI's example: a central midfielder suits Channel Midfielder in possession, but loses effectiveness as a Screening Defensive Midfielder out of possession if he lacks the familiarity or attributes, until he adapts. (Dugout, 6 Nov)
- OOP roles now appear in the key-attributes section of the Player Database. (SI 2D Match Engine / IGE feature, late Oct 2026, page undated)

**What the engine actually uses [FM27-DATA]**
- The single-match engine does not read the role-suitability or capability values. Its inputs from the TE record are the Tactical Understanding areas, tactical ability and complexity. (Match-Lab)
- A player's on-pitch value therefore comes from his raw attributes, his position rating, his per-player Tactical Understanding, and condition and sharpness.
- Physical attributes dominate. +5 Pace across the squad ≈ 13 points a season. Passing-group attributes help direct styles but show no measurable gain for possession styles. Current ability, reputation and personality fields have no single-match effect. (Match-Lab Studies 1, 2 and 9; harvestgreen22's season tests agree on the top four attributes)

**Implications [SPEC]**
- In FM27 a role's key/preferable list tells you what SI's suitability stars and TE panel reward. Those affect the panel, scout grades, and plausibly Buy-In and the AI's recruiting, but not the match engine directly.
- For an optimizer whose goal is winning matches, I would:
  - keep the role-fit score but blend in an engine-value score weighted toward the attributes the tests found to matter;
  - add a per-player tactical-understanding modifier.
- One community FM27 tool does a 50/50 blend of role fit and Match-Lab-derived engine weights. (StrawzyCode/FM27Manager) That is a design choice, not SI guidance.

---

## 3. FM27 roles

### 3.1 Provenance

- **[FM27-DATA]** The role names, positions and key/preferable attributes were transcribed from FM27's own role screens by the FM-Player-Analyzer project (added 1 Nov 2026, so probably from the Launch Preview). Two independent FM27 tools carry the same data (commits of 10 and 12 Nov 2026).
  - All three agree on 79 roles: 40 IP and 39 OOP.
  - Attribute lists are identical except for one difference: IP Deep-Lying Playmaker, where Agility is preferable in two sources and missing in the third.
  - One of those tools credits FM-Player-Analyzer, so the sources are not fully independent.
- **[SI]** SI has published no FM27 role list. Before release, SI posts named no FM27 roles and confirmed none as added or removed. (FootballGPT FM27 tracker, 10 and 17 Oct; Wonderkid Finder, 14 Oct) The match-engine feature does not mention role changes. (SI, 5 Oct)
- **[FM27-DATA]** FM27 keeps FM26's structure: one IP role and one OOP role per player, separate IP and OOP formations, no duties.
- "Preferable" is FM's second attribute tier. Some tools call it "preferred" or "important".

### 3.2 Roles available at each position

Position codes follow FM's own. For a 4-2-3-1:
- GK = GK
- Full-backs = D (L/R)
- Centre-backs = D (C)
- The two holding midfielders = DM. FM27 has a single DM role list; left/right DM slots share it.
- Wide attackers = AM (L/R)
- No. 10 = AM (C)
- Striker = ST (C)

If your OOP shape drops the wide AMs to M (L/R) (a 4-4-1-1 block), their OOP roles come from the M (L/R) list.

| Position | In-possession roles | Out-of-possession roles |
|---|---|---|
| GK | Goalkeeper, Ball-Playing Goalkeeper, No-Nonsense Goalkeeper | Goalkeeper, Sweeper Keeper, Line-Holding Goalkeeper |
| D (L/R) | Full-Back, Wing-Back, Inside Full-Back, Inside Wing-Back, Playmaking Wing-Back | Full-Back, Pressing Full-Back, Holding Full-Back |
| WB (L/R) | Wing-Back, Advanced Wing-Back, Inside Wing-Back, Playmaking Wing-Back | Wing-Back, Pressing Wing-Back, Holding Wing-Back |
| D (C) | Centre-Back, Ball-Playing Centre-Back, Advanced Centre-Back, Overlapping Centre-Back, No-Nonsense Centre-Back, Wide Centre-Back* | Centre-Back, Stopping Centre-Back, Covering Centre-Back, Wide Centre-Back*, Stopping Wide Centre-Back*, Covering Wide Centre-Back* |
| DM | Defensive Midfielder, Deep-Lying Playmaker, Box-To-Box Midfielder, Box-To-Box Playmaker, Half Back | Defensive Midfielder, Screening Defensive Midfielder, Dropping Defensive Midfielder, Pressing Defensive Midfielder, Wide Covering Defensive Midfielder |
| M (C) | Central Midfielder, Midfield Playmaker, Advanced Playmaker, Wide Central Midfielder, Channel Midfielder, Attacking Midfielder | Central Midfielder, Screening Central Midfielder, Pressing Central Midfielder, Wide Covering Central Midfielder |
| M (L/R) | Wide Midfielder, Winger, Inside Winger, Playmaking Winger | Wide Midfielder, Tracking Wide Midfielder, Wide Outlet Wide Midfielder |
| AM (L/R) | Winger, Inside Winger, Inside Forward, Wide Forward, Playmaking Winger | Winger, Tracking Winger, Inside Outlet Winger, Wide Outlet Winger |
| AM (C) | Attacking Midfielder, Advanced Playmaker, Channel Midfielder, Free Role, Second Striker | Attacking Midfielder, Tracking Attacking Midfielder, Central Outlet Attacking Midfielder, Splitting Outlet Attacking Midfielder |
| ST (C) | Centre Forward, Poacher, Channel Forward, Deep-Lying Forward, False Nine, Target Forward | Centre Forward, Tracking Centre Forward, Central Outlet Centre Forward, Splitting Outlet Centre Forward |

\* The "wide" centre-back roles are, per one community tool, offered only on the outside spots of a back three. **[FM27-DATA, tool note; not verified]**

**Mapping to your nine position groups**

| Your group | FM27 IP list | FM27 OOP list |
|---|---|---|
| GK | GK | GK |
| Full-back | D (L/R) | D (L/R) |
| Centre-back | D (C) | D (C) |
| Left DM / Right DM | DM | DM |
| Left AM / Right AM | AM (L/R) | AM (L/R), or M (L/R) if they drop |
| Centre AM | AM (C) | AM (C) |
| Striker | ST (C) | ST (C) |

### 3.3 What changed since FM26

- **Added, removed or renamed according to SI:** **NO FM27 EVIDENCE FOUND.** No SI FM27 page lists role changes.
- **Diff against FM26: not reliable from public sources.**
  - Most public FM26 role lists come from an August 2025 database leak and pre-release coverage, and their naming is inconsistent.
  - For example, FM Scout's FM26 roles article uses "Wide Playmaker", "Inverting Outlet Winger" and "Half-Space Winger" in its tables, but "Playmaking Winger" and "Inside Outlet Winger" in its conversion section. (FM Scout, 12 Oct 2025, flags the leak as unofficial)
- **Names in FM26 pre-release lists that are absent from the FM27 data:**
  - Inverted Full-Back, Inverted Wing-Back, Half-Space Winger, Half-Space Forward, Wide Playmaker, Inverting Outlet Winger.
  - **[SPEC]** Some or all of these may never have shipped in FM26. The FM26 conversion guide already uses the FM27 names "Playmaking Winger" and "Inside Outlet Winger". Their absence does not prove FM27 removed anything.
- **Small naming differences:** "Line-Holding Keeper" (FM26 lists) vs "Line-Holding Goalkeeper" (FM27 data), and "Wide Outlet Midfielder" vs "Wide Outlet Wide Midfielder". **[SPEC]** These may be display-name differences only.
- **Position mapping to check:** in the FM27 data, Box-To-Box Midfielder and Box-To-Box Playmaker are DM-only IP roles, while FM26 articles list them under central midfield. **[FM27-DATA vs FM26 secondary sources]** I could not confirm whether FM26's final build already did this.
- **Recommendation:** your FM26 tool's own role table is the most reliable FM26 baseline. A programmatic diff of `fm27_roles.json` against it would settle this better than anything published.

### 3.4 Full role table with attributes

This is the same data as `fm27_roles.json`. † marks a role with a data note in the JSON.

#### In-possession roles (40)

| Role | Positions | Key attributes | Preferable attributes |
|---|---|---|---|
| Ball-Playing Goalkeeper | GK | Aerial Reach, Command Of Area, Communication, Handling, Kicking, Reflexes, Concentration, Positioning, Agility | Eccentricity, One On Ones, Passing, Throwing, Anticipation, Composure, Decisions |
| Goalkeeper | GK | Aerial Reach, Command Of Area, Communication, Handling, Reflexes, Concentration, Positioning, Agility | Kicking, One On Ones, Throwing, Anticipation, Decisions |
| No-Nonsense Goalkeeper | GK | Aerial Reach, Command Of Area, Communication, Handling, Reflexes, Concentration, Positioning, Agility | One On Ones, Anticipation, Decisions |
| Full-Back | D (L), D (R) | Marking, Tackling, Anticipation, Concentration, Positioning, Teamwork, Acceleration | Crossing, Dribbling, Passing, Technique, Decisions, Work Rate, Agility, Pace, Stamina |
| Inside Full-Back | D (L), D (R) | Heading, Marking, Tackling, Anticipation, Positioning, Strength | Dribbling, Aggression, Bravery, Composure, Concentration, Decisions, Work Rate, Acceleration, Agility, Jumping Reach, Pace, Stamina |
| Inside Wing-Back | D (L), D (R), WB (L), WB (R) | Passing, Tackling, Anticipation, Composure, Decisions, Positioning, Teamwork, Acceleration | First Touch, Marking, Technique, Concentration, Work Rate, Agility, Pace, Stamina |
| Playmaking Wing-Back | D (L), D (R), WB (L), WB (R) | First Touch, Passing, Tackling, Technique, Composure, Decisions, Teamwork, Vision, Acceleration | Crossing, Dribbling, Marking, Anticipation, Concentration, Off The Ball, Positioning, Work Rate, Agility, Pace, Stamina |
| Wing-Back | D (L), D (R), WB (L), WB (R) | Crossing, Marking, Tackling, Teamwork, Work Rate, Acceleration, Pace, Stamina | Dribbling, First Touch, Passing, Technique, Anticipation, Concentration, Decisions, Off The Ball, Positioning, Agility, Balance |
| Advanced Centre-Back | D (C) | Heading, Marking, Passing, Tackling, Technique, Anticipation, Composure, Decisions, Positioning, Teamwork, Jumping Reach, Strength | Dribbling, First Touch, Aggression, Bravery, Concentration, Vision, Pace, Stamina |
| Ball-Playing Centre-Back | D (C) | Heading, Marking, Passing, Tackling, Anticipation, Composure, Positioning, Jumping Reach, Strength | First Touch, Technique, Aggression, Bravery, Concentration, Decisions, Vision, Pace |
| Centre-Back | D (C) | Heading, Marking, Tackling, Anticipation, Positioning, Jumping Reach, Strength | Aggression, Bravery, Composure, Concentration, Decisions, Pace |
| No-Nonsense Centre-Back | D (C) | Heading, Marking, Tackling, Anticipation, Positioning, Jumping Reach, Strength | Aggression, Bravery, Concentration, Pace |
| Overlapping Centre-Back | D (C) | Crossing, Heading, Marking, Tackling, Anticipation, Work Rate, Jumping Reach, Pace, Stamina, Strength | Dribbling, Technique, Aggression, Bravery, Composure, Concentration, Decisions, Off The Ball, Positioning, Acceleration, Agility |
| Wide Centre-Back † | D (C) | Heading, Marking, Tackling, Anticipation, Positioning, Jumping Reach, Strength | Dribbling, Aggression, Bravery, Composure, Concentration, Decisions, Work Rate, Acceleration, Agility, Pace, Stamina |
| Advanced Wing-Back | WB (L), WB (R) | Crossing, Dribbling, Technique, Off The Ball, Teamwork, Work Rate, Acceleration, Agility, Pace, Stamina | First Touch, Marking, Passing, Tackling, Anticipation, Decisions, Flair, Positioning, Balance |
| Box-To-Box Midfielder | DM | Passing, Tackling, Off The Ball, Teamwork, Work Rate, Stamina | Dribbling, Finishing, First Touch, Long Shots, Technique, Aggression, Anticipation, Composure, Decisions, Positioning, Acceleration, Balance, Pace, Strength |
| Box-To-Box Playmaker | DM | First Touch, Passing, Technique, Composure, Decisions, Off The Ball, Teamwork, Vision, Work Rate, Stamina | Dribbling, Long Shots, Marking, Tackling, Anticipation, Positioning, Acceleration, Agility, Balance, Pace |
| Deep-Lying Playmaker † | DM | First Touch, Passing, Technique, Composure, Decisions, Teamwork, Vision | Marking, Tackling, Anticipation, Concentration, Off The Ball, Positioning, Work Rate, Agility, Balance, Stamina |
| Defensive Midfielder | DM | Tackling, Anticipation, Concentration, Positioning, Teamwork | First Touch, Marking, Passing, Aggression, Composure, Decisions, Work Rate, Stamina, Strength |
| Half Back | DM | Heading, Marking, Tackling, Anticipation, Concentration, Positioning, Teamwork, Jumping Reach, Strength | First Touch, Passing, Aggression, Bravery, Composure, Decisions, Work Rate, Stamina |
| Inside Winger | M (L), M (R), AM (L), AM (R) | Dribbling, First Touch, Technique, Composure, Teamwork, Acceleration, Agility | Crossing, Long Shots, Passing, Anticipation, Flair, Off The Ball, Vision, Work Rate, Balance, Pace, Stamina |
| Playmaking Winger | M (L), M (R), AM (L), AM (R) | Crossing, Dribbling, First Touch, Passing, Technique, Composure, Decisions, Off The Ball, Teamwork, Vision, Acceleration | Anticipation, Flair, Work Rate, Agility, Pace, Stamina |
| Wide Midfielder | M (L), M (R) | Crossing, Passing, Technique, Decisions, Teamwork, Work Rate, Pace, Stamina | Dribbling, First Touch, Anticipation, Composure, Off The Ball, Vision, Acceleration, Agility |
| Winger | M (L), M (R), AM (L), AM (R) | Crossing, Dribbling, Technique, Teamwork, Acceleration, Agility, Pace | First Touch, Passing, Anticipation, Flair, Off The Ball, Work Rate, Balance, Stamina |
| Advanced Playmaker | M (C), AM (C) | First Touch, Passing, Technique, Composure, Decisions, Off The Ball, Teamwork, Vision | Crossing, Dribbling, Anticipation, Flair, Acceleration, Agility |
| Attacking Midfielder | M (C), AM (C) | First Touch, Long Shots, Passing, Technique, Composure, Flair, Off The Ball | Crossing, Dribbling, Finishing, Anticipation, Decisions, Vision, Acceleration, Agility |
| Central Midfielder | M (C) | First Touch, Passing, Tackling, Decisions, Teamwork | Technique, Anticipation, Composure, Concentration, Off The Ball, Positioning, Vision, Work Rate, Stamina |
| Channel Midfielder | M (C), AM (C) | Crossing, First Touch, Passing, Technique, Composure, Off The Ball, Work Rate, Acceleration | Dribbling, Long Shots, Anticipation, Decisions, Flair, Vision, Agility, Pace, Stamina |
| Midfield Playmaker | M (C) | First Touch, Passing, Technique, Composure, Decisions, Off The Ball, Teamwork, Vision | Dribbling, Tackling, Anticipation, Flair, Positioning, Work Rate, Agility, Stamina |
| Wide Central Midfielder | M (C) | First Touch, Passing, Tackling, Decisions, Teamwork | Crossing, Dribbling, Technique, Anticipation, Composure, Concentration, Off The Ball, Positioning, Vision, Work Rate, Agility, Stamina |
| Inside Forward | AM (L), AM (R) | Dribbling, First Touch, Technique, Anticipation, Composure, Off The Ball, Acceleration, Agility | Crossing, Finishing, Long Shots, Passing, Flair, Vision, Work Rate, Balance, Pace, Stamina |
| Wide Forward | AM (L), AM (R) | Dribbling, First Touch, Technique, Anticipation, Off The Ball, Acceleration, Agility, Pace | Crossing, Finishing, Passing, Composure, Flair, Work Rate, Balance, Stamina |
| Free Role | AM (C) | Dribbling, First Touch, Long Shots, Passing, Technique, Composure, Flair, Off The Ball, Vision | Crossing, Finishing, Anticipation, Decisions, Acceleration, Agility |
| Second Striker | AM (C) | Finishing, First Touch, Anticipation, Composure, Off The Ball, Acceleration | Dribbling, Long Shots, Passing, Technique, Concentration, Decisions, Work Rate, Agility, Pace, Stamina |
| Centre Forward | ST (C) | Finishing, First Touch, Heading, Technique, Composure, Off The Ball, Acceleration, Strength | Dribbling, Passing, Anticipation, Decisions, Agility, Balance, Jumping Reach, Pace |
| Channel Forward | ST (C) | Dribbling, Finishing, First Touch, Technique, Composure, Off The Ball, Work Rate, Acceleration | Crossing, Heading, Passing, Anticipation, Decisions, Agility, Balance, Pace, Stamina |
| Deep-Lying Forward | ST (C) | Finishing, First Touch, Technique, Composure, Off The Ball, Strength | Dribbling, Passing, Anticipation, Decisions, Teamwork, Vision, Balance |
| False Nine | ST (C) | Dribbling, First Touch, Passing, Technique, Composure, Decisions, Off The Ball, Teamwork, Vision, Acceleration | Finishing, Anticipation, Flair, Agility, Balance |
| Poacher | ST (C) | Finishing, Heading, Anticipation, Composure, Concentration, Off The Ball, Acceleration | First Touch, Technique, Decisions, Balance |
| Target Forward | ST (C) | Finishing, Heading, Aggression, Bravery, Composure, Off The Ball, Balance, Jumping Reach, Strength | First Touch, Anticipation, Decisions, Teamwork |

#### Out-of-possession roles (39)

| Role | Positions | Key attributes | Preferable attributes |
|---|---|---|---|
| Goalkeeper | GK | Aerial Reach, Command Of Area, Communication, Handling, Reflexes, Concentration, Positioning, Agility | One On Ones, Rushing Out (Tendency), Anticipation, Decisions |
| Line-Holding Goalkeeper | GK | Aerial Reach, Command Of Area, Communication, Handling, Reflexes, Concentration, Positioning, Agility | One On Ones, Anticipation, Decisions |
| Sweeper Keeper | GK | Aerial Reach, Command Of Area, Communication, Handling, One On Ones, Reflexes, Rushing Out (Tendency), Anticipation, Decisions, Agility | Eccentricity, Concentration, Positioning, Acceleration |
| Full-Back | D (L), D (R) | Marking, Tackling, Anticipation, Positioning, Teamwork, Acceleration | Aggression, Concentration, Decisions, Work Rate, Agility, Pace, Stamina |
| Holding Full-Back | D (L), D (R) | Marking, Tackling, Anticipation, Concentration, Decisions, Positioning, Acceleration | Teamwork, Agility, Pace |
| Pressing Full-Back | D (L), D (R) | Marking, Tackling, Aggression, Anticipation, Positioning, Teamwork, Work Rate, Acceleration | Bravery, Concentration, Decisions, Agility, Pace, Stamina |
| Centre-Back | D (C) | Heading, Marking, Tackling, Anticipation, Positioning, Jumping Reach, Strength | Aggression, Bravery, Composure, Concentration, Decisions, Pace |
| Covering Centre-Back | D (C) | Heading, Marking, Tackling, Anticipation, Concentration, Decisions, Positioning, Jumping Reach, Pace, Strength | Bravery, Acceleration |
| Covering Wide Centre-Back | D (C) | Heading, Marking, Tackling, Anticipation, Concentration, Decisions, Positioning, Jumping Reach, Pace, Strength | Bravery, Acceleration, Agility |
| Stopping Centre-Back | D (C) | Heading, Marking, Tackling, Aggression, Anticipation, Bravery, Positioning, Jumping Reach, Strength | Concentration, Decisions, Pace |
| Stopping Wide Centre-Back | D (C) | Heading, Marking, Tackling, Aggression, Anticipation, Bravery, Positioning, Jumping Reach, Strength | Concentration, Decisions, Acceleration, Agility, Pace |
| Wide Centre-Back † | D (C) | Heading, Marking, Tackling, Anticipation, Positioning, Jumping Reach, Strength | Aggression, Bravery, Concentration, Decisions, Acceleration, Agility, Pace |
| Holding Wing-Back | WB (L), WB (R) | Marking, Tackling, Anticipation, Concentration, Decisions, Positioning, Acceleration | Teamwork, Agility, Pace, Stamina |
| Pressing Wing-Back | WB (L), WB (R) | Marking, Tackling, Aggression, Anticipation, Positioning, Teamwork, Work Rate, Acceleration, Stamina | Bravery, Concentration, Decisions, Agility, Pace |
| Wing-Back | WB (L), WB (R) | Marking, Tackling, Anticipation, Positioning, Teamwork, Acceleration, Stamina | Aggression, Concentration, Decisions, Work Rate, Agility, Pace |
| Defensive Midfielder | DM | Tackling, Anticipation, Decisions, Positioning, Teamwork, Work Rate | Marking, Aggression, Concentration, Stamina, Strength |
| Dropping Defensive Midfielder | DM | Marking, Tackling, Anticipation, Concentration, Decisions, Positioning, Teamwork, Work Rate, Jumping Reach, Strength | Aggression, Stamina |
| Pressing Defensive Midfielder | DM | Tackling, Aggression, Anticipation, Decisions, Positioning, Teamwork, Work Rate, Stamina | Marking, Concentration, Pace, Strength |
| Screening Defensive Midfielder | DM | Marking, Tackling, Anticipation, Concentration, Decisions, Positioning | Teamwork, Work Rate, Stamina, Strength |
| Wide Covering Defensive Midfielder | DM | Marking, Tackling, Anticipation, Decisions, Positioning, Teamwork, Work Rate, Agility, Stamina | Aggression, Concentration, Pace, Strength |
| Tracking Wide Midfielder | M (L), M (R) | Aggression, Anticipation, Decisions, Teamwork, Work Rate, Acceleration, Stamina | Marking, Tackling, Off The Ball, Positioning, Agility, Pace |
| Wide Midfielder | M (L), M (R) | Decisions, Teamwork, Work Rate, Acceleration | Marking, Aggression, Anticipation, Off The Ball, Agility, Pace, Stamina |
| Wide Outlet Wide Midfielder | M (L), M (R) | Anticipation, Concentration, Decisions, Off The Ball, Teamwork, Pace | Dribbling, First Touch, Marking, Composure, Acceleration, Agility |
| Central Midfielder | M (C) | Tackling, Decisions, Teamwork, Work Rate | Marking, Aggression, Anticipation, Concentration, Positioning, Stamina |
| Pressing Central Midfielder | M (C) | Tackling, Aggression, Anticipation, Decisions, Teamwork, Work Rate, Stamina | Marking, Concentration, Positioning, Pace, Strength |
| Screening Central Midfielder | M (C) | Marking, Tackling, Concentration, Decisions, Positioning | Anticipation, Teamwork, Work Rate, Stamina |
| Wide Covering Central Midfielder | M (C) | Marking, Tackling, Decisions, Teamwork, Work Rate, Agility, Stamina | Aggression, Anticipation, Concentration, Positioning, Pace |
| Inside Outlet Winger | AM (L), AM (R) | Anticipation, Concentration, Decisions, Off The Ball, Teamwork, Balance | Dribbling, First Touch, Marking, Composure, Acceleration, Strength |
| Tracking Winger | AM (L), AM (R) | Aggression, Anticipation, Decisions, Teamwork, Work Rate, Acceleration, Stamina | Marking, Tackling, Off The Ball, Positioning, Agility, Pace |
| Wide Outlet Winger | AM (L), AM (R) | Anticipation, Concentration, Decisions, Off The Ball, Teamwork, Pace | Dribbling, First Touch, Marking, Composure, Acceleration, Agility |
| Winger | AM (L), AM (R) | Anticipation, Decisions, Teamwork, Work Rate, Acceleration | Marking, Aggression, Off The Ball, Agility, Pace, Stamina |
| Attacking Midfielder | AM (C) | Anticipation, Decisions, Work Rate | Marking, Aggression, Off The Ball, Teamwork, Stamina |
| Central Outlet Attacking Midfielder | AM (C) | Anticipation, Concentration, Decisions, Off The Ball, Teamwork, Balance | First Touch, Marking, Composure, Strength |
| Splitting Outlet Attacking Midfielder | AM (C) | Anticipation, Concentration, Decisions, Off The Ball, Teamwork, Pace | First Touch, Marking, Composure, Acceleration |
| Tracking Attacking Midfielder | AM (C) | Aggression, Anticipation, Decisions, Teamwork, Work Rate, Stamina | Marking, Off The Ball, Positioning |
| Central Outlet Centre Forward | ST (C) | Anticipation, Concentration, Decisions, Off The Ball, Teamwork, Balance | First Touch, Marking, Composure, Strength |
| Centre Forward | ST (C) | Anticipation, Decisions, Work Rate | Marking, Aggression, Off The Ball, Teamwork, Stamina |
| Splitting Outlet Centre Forward | ST (C) | Anticipation, Concentration, Decisions, Off The Ball, Teamwork, Pace | First Touch, Marking, Composure, Acceleration |
| Tracking Centre Forward | ST (C) | Aggression, Anticipation, Decisions, Teamwork, Work Rate, Stamina | Marking, Off The Ball, Positioning |

---

## 4. Positional familiarity in FM27

### 4.1 Scale and display

- FM27 shows position familiarity as coloured dots. Exports do not include the underlying number. **[FM27-OBS]** (Dixnnn/FM27-System-and-Tactic-Designer README, 10 Nov 2026)
- Underneath there is a 1–20 position rating, which Match-Lab edits directly. **[FM27-DATA]**
- **Tier boundaries in FM27: NO SI FM27 SOURCE FOUND.** Published tables disagree:
  - FM27 tool README: Natural 20, Accomplished 15–19, Competent 10–14, Unconvincing 5–9, Awkward 2–4, Ineffectual 1. **[FM27-OBS: tool author's mapping, method not stated]** (StrawzyCode/FM27Manager)
  - Older SI-manual-derived table: Natural 18–20, Accomplished 15–17, Competent 12–14, Unconvincing 9–11, Awkward 5–8, Makeshift 2–4, Ineffectual 0–1. **[FM26-CARRY; actually FM24-era]** (sortitoutsi FM24 retraining guide, 2024; SI FM24 manual)
  - FMInside: Natural 19–20, Accomplished 13–17, Competent 10–12, Unconvincing 6–8, Awkward 1–5. **[FM26-CARRY; older]**
  - Your current tiers (none at 18+, about 10% at 12–14, severe below 9) follow the FM24-era table.

### 4.2 Performance cost

| Change (every outfield starter) | Points per game | xG difference | Label |
|---|---|---|---|
| Position ratings capped at 15 | −0.26 (t −2.5) | −0.22 (t −2.7) | [FM27-DATA] |
| Position ratings capped at 10 | −0.85 (t −8.8) | −1.03 (t −12.3) | [FM27-DATA] |
| Natural in *more* outfield positions (same slots) | ≈0 | ≈0 | [FM27-DATA] |

Source: Fm-Match-Lab Study 5, 11 Nov 2026, 27.0.1 engine, 300 paired matches per condition. A run that made outfielders "natural goalkeepers" distorted results, and the authors excluded it.

**Reading this for your penalty curve [SPEC]**
- Only two cap levels were tested, applied to all starters at once, so the numbers do not convert directly into a per-player percentage.
- Two points are firm:
  - The cost is steeply non-linear: going from a cap of 15 to a cap of 10 more than triples it.
  - A rating of 15 is **not** free for players whose true rating was higher. That supports a small penalty in the 15–17 band.
- Nothing measured contradicts your current shape: none at 18+, moderate in the low teens, severe below about 9.
- For comparison, 50% match sharpness cost 1.03 ppg and 80% condition cost 0.80 ppg on the same matches. Fitness-driven selection belongs in the optimizer at least as much as familiarity. **[FM27-DATA]**

**How the penalty works mechanically**
- Older guides say being out of position suppresses Positioning and Decisions. **[FM26-CARRY; older, unverified for FM27]** (FMInside; FM Dossier, citing it)
- **NO FM27 EVIDENCE FOUND** on the mechanism.

**Familiarity inside TE**
- Positional suitability feeds the Player Ability area of the TE panel. **[SI]**
- In single-match tests, the engine ignores Player Ability. **[FM27-DATA]**
- So the measured cost above comes from the position rating itself, not from TE.

### 4.3 Different positions in and out of possession

- **[SI]** SI's Dugout example (6 Nov 2026): a player whose OOP role needs familiarity he lacks will be less effective until he adapts. The OOP position is therefore assessed in its own right.
- **[FM27-OBS]** Scout Reports show a player's fit for each position both with and without the ball. (FM Scout, 9 Oct 2026, dev build)
- **[FM26-CARRY]** In FM26:
  - OOP role suitability = familiarity in that area of the pitch + key attributes. (SI FM26 feature)
  - The Combined view averages IP and OOP star ratings, and the game warns when a player's IP and OOP positions are too far apart. (Passion4FM FM26 guide)
- **How the engine weights the two positions** (one rating per phase, an average, or the IP rating only): **NO FM27 EVIDENCE FOUND.** Match-Lab capped all position ratings together, so phase-specific effects are untested.
- **[SPEC] Suggested modelling:** apply the familiarity penalty separately to the IP score (using the IP position) and the OOP score (using the OOP position), then average as you do now. This matches SI's stated framing and your existing IP/OOP split. For your fixed 4-2-3-1, this only matters if your OOP shape moves anyone, for example AM (L/R) dropping to M (L/R).

### 4.4 Retraining

- About 6–9 months to become usable in a new position, and about 12 months to reach Natural. **[FM26-CARRY; FM24-era guide]**
- FM27 keeps individual training for new positions. **[FM27-OBS]** (FM Scout, 9 Oct)
- FM27 retraining rates: **NO FM27 EVIDENCE FOUND.**

---

## 5. Tactical understanding and team cohesion

### 5.1 Tactical Understanding (FM26's tactical familiarity)

- **Scope: per player, per area.** **[FM27-DATA]** Each player carries eight area values (IP shape, passing style, build-up, chance creation, OOP shape, line of engagement, pressing intensity, pressing trap). Each value combines a training part and a match-exposure part. The UI aggregates these to a team figure. **[FM27-OBS]**
- **How it is gained:**
  - **Training** on the primary trained tactic. There are eight Tactical Understanding sessions, matching the eight areas. **[FM27-OBS / FM27-DATA]** (Destructoid, 5 Nov; FM-Arena training-schedules thread, about 10 Nov)
    - Training weighs about twice as much as match exposure in the engine. **[FM27-DATA]**
    - The training part decays without sessions. **[FM27-DATA]**
  - **Match exposure.** It rose by about 2 per area for every *starter* after a match, climbing toward the cap of 100. **[FM27-DATA]** (Match-Lab)
  - **Player tactical ability**, the median of five attributes (§1.2). **[FM27-DATA]**
  - **Lower complexity** raises it. **[SI / FM27-DATA]** However, changing complexity mid-match showed no clear effect in the engine; that is still open. **[FM27-DATA]**
  - Up to three tactics can be prepared. Alternates are always less familiar, and frequent switching hurts. **[SI]**
  - Familiarity with a manager's methods carries over from previous clubs. **[SI]**
- **Lower leagues:** base levels are lower and grow more slowly, because player and coach quality feed it. **[SI]** (Dugout) **[FM27-OBS]** (TheGamer, 12 Nov) One forum user reports a part-time side not reaching 50% within a season. **[FM27-OBS, anecdote]**

### 5.2 Team cohesion

- **Scope: per team.** **[FM27-DATA]** Match-Lab treats team cohesion as one team-level start-of-match value (62–84 across this squad's saved matches), separate from club cohesion.
  - Highest versus lowest team cohesion: **+0.21 ppg, +0.32 xGD** (900 paired matches, t 6.7, confirmed).
  - Club cohesion showed no effect.
- **[SI]** Cohesion appears in three places:
  - as a senior-squad training focus (Training feature);
  - inside Player Buy-In, as relationships within the squad (Dugout);
  - in the match engine, where poor cohesion makes runners double up and make poor decisions (Match Engine feature, 5 Oct).
- **How it is gained:**
  - Team Bonding sessions and keeping a settled XI. **[FM27-OBS]** (Destructoid, TheGamer)
  - Many signings in a short time reduce it. **[FM26-CARRY; older Passion4FM guide]**
  - FM27 numbers: **NO FM27 EVIDENCE FOUND.**

### 5.3 Does rotating the lineup harm them?

- **Tactical Understanding:**
  - Exposure accrues only to the players who start, so a heavily rotated player builds less of it than a regular starter. The training part is shared by everyone who trains. **[FM27-DATA, mechanism]**
  - **[SPEC]** Rotation's cost here is limited, because training outweighs exposure and the curve plateaus around 50.
  - No study has measured rotation directly: **NO FM27 EVIDENCE FOUND** for a rotation effect size.
- **Team cohesion:** whether XI changes lower it in FM27: **NO FM27 EVIDENCE FOUND.** Guides advise a settled XI without data. **[FM27-OBS]**
- **The other side of rotation [FM27-DATA]:** the same engine study found sharpness and condition are the largest controllable factors. Sharpness at 75% cost 0.37 ppg, and condition at 90% cost 0.28 ppg. Rotation that protects condition plausibly outweighs small understanding losses. **[SPEC on the trade-off]**

---

## 6. Suggested changes to the optimizer

All **[SPEC]**: my recommendations based on the evidence above.

1. **Replace group weights with role-specific weights** from `fm27_roles.json`, one IP role and one OOP role per slot.
   - One FM27 tool weights key attributes ×3 and preferable ×1.5. Another averages key attributes and uses preferable only as a tie-breaker. Neither scheme is SI's.
2. **Blend in an engine-value term** weighted toward Pace, Acceleration, Jumping Reach, Stamina, Anticipation, Concentration and Dribbling. The engine ignores role suitability, and these attributes carry measured match value. Tune the blend; 50/50 is one tool's default.
3. **Apply familiarity per phase**, using the IP position rating for the IP score and the OOP position rating for the OOP score. Keep the non-linear curve and consider a small penalty from 15–17.
4. **Optionally add a per-player tactical-understanding modifier** if you can read it. Failing that, use tactical ability (the median of Anticipation, Decisions, Composure, Concentration and Versatility) as a proxy, plus a "regular starter" bonus for exposure. Keep it small: the benefit saturates around the middle of the scale.
5. **Add availability inputs** (condition and sharpness). They dwarf most tactical effects in FM27 engine tests.
6. **Leave Buy-In, Next Match Info and cohesion out of per-player assignment.**
   - Buy-In and Next Match Info had no measurable single-match effect per player.
   - Cohesion is team-level. You could only use it as a tie-breaker that favours keeping an XI together, and there is no FM27 data to size that.

---

## 7. Open questions (no FM27 evidence found)

- Exact FM27 position-rating tier boundaries, and the penalty curve per tier.
- How the engine combines a player's IP and OOP position ratings.
- Whether lineup rotation lowers team cohesion, and by how much.
- Official FM26 → FM27 role additions, removals and renames.
- Whether Buy-In and Next Match Info affect matches through day-by-day record rebuilding, which the single-match tests could not capture.
- Whether Tactical Complexity's cost appears before kick-off (a save-based test is needed).
- Whether these results hold for dominant teams or other formations. All Match-Lab data is from one newly promoted Premier League side.

---

## Sources

| # | Source | URL | Date | Label | Notes |
|---|---|---|---|---|---|
| 1 | SI: FM27 Training & Tactical Effectiveness (feature + FAQ) | https://www.footballmanager.com/fm27/features/fm27-training-and-tactical-effectiveness | Page undated. Posted 9 Oct 2026 (FM Scout timeline; Steam news per FootballGPT). | SI | Development-build footage |
| 2 | SI forum: FM27 Training & Tactical Effectiveness FAQs | https://community.sports-interactive.com/forums/topic/612100-fm27-training-tactical-effectiveness-faqs/ | about 9 Oct 2026 | SI | Same FAQ text; mentions cohesion sessions |
| 3 | SI Dugout: Tactical Effectiveness: Understanding FM27's Key New Feature (FM Stag) | https://www.footballmanager.com/the-dugout/tactical-effectiveness-understanding-fm27s-key-new-feature | 6 Nov 2026 | SI | Sub-factors; IP/OOP familiarity example; AI uses TE |
| 4 | SI: FM27 Tactical Tweaks and Match Engine Upgrades | https://www.footballmanager.com/node/1108 | 5 Oct 2026 (per FootballGPT; page undated) | SI | Cohesion and box-run doubling; no role changes mentioned |
| 5 | SI: FM27 2D Match Engine, In-Game Editor and Deeper World Upgrades | https://www.footballmanager.com/node/1120 | Undated, about late Oct 2026 | SI | OOP roles added to Player Database key attributes |
| 6 | SI: In Possession, Out of Possession: FM26's New Tactical Evolution | https://www.footballmanager.com/fm26/features/possession-out-possession-fm26s-new-tactical-evolution | 2025 (FM26 pre-release) | FM26-CARRY | OOP suitability = familiarity + key attributes |
| 7 | Fm-Match-Lab (caiograco289): FINDINGS, Studies 1–9, OTHER-TESTS | https://github.com/caiograco289/Fm-Match-Lab (docs/FINDINGS.md, docs/studies/) | Studies 10–11 Nov 2026; repo commit 12 Nov 2026 | FM27-DATA | FM27 27.0.1 engine run outside the game; one club; about 220k matches |
| 8 | harvestgreen22: Full analysis and testing of TE and Tactical Understanding | https://sortitoutsi.net/content/78377/full-analysis-and-testing-of-tactical-effectiveness-and-tactical-understanding | about 9 Nov 2026 | FM27-DATA | Headline weights credited to lqf0624 (playgm). Read via search excerpts; the page blocked direct fetch. |
| 9 | harvestgreen22: FM27 Attribute Test + Tactical Understanding + Training | https://sortitoutsi.net/content/78219/fm27-attribute-test-tactical-understanding-training-system-preset-tactics-ai-reverse-engineering-engine-for-test and https://fm-arena.com/thread/20925-fm27-attribute-test-tactical-understanding-training/ | about 2–3 Nov 2026 | FM27-DATA | In-game seasons with FMRTE, likely Launch Preview. Read via search excerpts. |
| 10 | ZaZ: FM27 tactics thread, TE summary | https://community.sports-interactive.com/forums/topic/612941-zaz-fm27/ ; https://fm-arena.com/threads/training-schedules.60/ | about 10–11 Nov 2026 | FM27-DATA (secondhand) | Summarises playgm research. Read via search excerpts. |
| 11 | FM-Player-Analyzer: FM27 role data | https://github.com/ElectroHugin/FM-Player-Analyzer (desktop/data/fm27/rollen-fm27.csv) | Commit 1 Nov 2026 | FM27-DATA | Transcribed from in-game role screens |
| 12 | StrawzyCode/FM27Manager | https://github.com/StrawzyCode/FM27Manager (engine.js) | Commit 12 Nov 2026 | FM27-DATA / FM27-OBS | Cross-check of role data; its position tier mapping is the author's own |
| 13 | Dixnnn/FM27-System-and-Tactic-Designer | https://github.com/Dixnnn/FM27-System-and-Tactic-Designer (data/roles.json, README) | Commit 10 Nov 2026 | FM27-DATA / FM27-OBS | Credits #11; familiarity shown as dots |
| 14 | FM Scout: FM27 Tactical Effectiveness: How to Improve It | https://www.fmscout.com/a-fm27-tactical-effectiveness.html | 9 Oct 2026 | FM27-OBS | From SI livestream/dev build: factor names, Player View, scout report fit by position IP/OOP |
| 15 | FM Scout: FM27 New Features | https://www.fmscout.com/a-football-manager-2027-new-features.html | about 27 Oct 2026 | FM27-OBS | Intensity, Complexity and Effectiveness ratings; AI uses TE |
| 16 | TheGamer: Complete Guide to Tactical Effectiveness | https://www.thegamer.com/football-manager-27-complete-guide-to-tactical-effectiveness/ | 12 Nov 2026 | FM27-OBS | Per-player TE screen; lower-league base |
| 17 | Destructoid: How to get full TE in FM27 | https://www.destructoid.com/how-to-get-full-tactical-effectiveness-in-football-manager-27/ | 5 Nov 2026 | FM27-OBS | Eight TU training modules; pre-release build |
| 18 | FMPortugal: How to improve TE in FM27 | https://fmportugal.net/en/como-melhorar-eficacia-tatica-fm27/ | 6 Nov 2026 | FM27-OBS | Summary of #3 |
| 19 | FootballGPT: FM27 tactics / what's new trackers | https://footballgpt.co/fm/fm27/tactics ; https://footballgpt.co/fm/fm27/whats-new | 10 Oct and 17 Oct 2026 | FM27-OBS | No FM27 roles named by SI before release |
| 20 | Wonderkid Finder: FM27 release date & what's new | https://wonderkidfinder.com/fm27/release-date/ | 14 Oct 2026 status | FM27-OBS | No new role list announced |
| 21 | sortitoutsi: FM27 Trainer tool thread | https://sortitoutsi.net/content/78370/fm27-trainer-read-your-tactical-effectiveness-and-train-your-weakest-areas | about 11 Nov 2026 | FM27-OBS | "4 components, 17 key factors" |
| 22 | SI forum: The Basque Way (FM27) | https://community.sports-interactive.com/forums/topic/612495-the-basque-way-my-guide-to-simple-tactics-and-smart-defence-in-fm27/ | 12 Nov 2026 | FM27-OBS | Quotes the in-game definition of Tactical Complexity |
| 23 | FM Scout: FM26 Player Roles (leak-based) | https://www.fmscout.com/a-football-manager-2026-player-roles.html | 12 Oct 2025 | FM26-CARRY | Inconsistent leak-era names |
| 24 | FM Scout: How to convert FM24 tactics to FM26 | https://www.fmscout.com/a-how-to-convert-your-fm24-tactics-to-fm26.html | 2025 | FM26-CARRY | Uses Playmaking Winger and Inside Outlet Winger |
| 25 | Passion4FM: Beginners Guide to FM26 Tactics Creation | https://www.passion4fm.com/fm26-tactics-creation-beginners-guide/ | about Feb 2026 | FM26-CARRY | Combined-view star averaging; IP/OOP distance warning |
| 26 | sortitoutsi: FM24 Guide: How to Retrain Player's Position | https://sortitoutsi.net/content/67473/fm24-guide-how-to-retrain-players-position | 2024 | FM26-CARRY (older) | Position rating tiers; retraining time |
| 27 | FMInside: Player Positional Ability | https://fminside.net/guides/positional-guides/18-player-positional-ability | older (about 2025) | FM26-CARRY (older) | Alternative tier table |

**Reading notes**
- Forum pages on sortitoutsi, FM-Arena and the SI community blocked direct fetching. For #8–#10 I relied on search-result excerpts of those posts, and on Match-Lab's own comparison page, which re-reports them.
- The Match-Lab and role-data repositories were read in full.
