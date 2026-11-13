# FM27 Lineup Tool Audit: Attribute Weights, Role Thresholds and Relative Scoring for a Lower-League Squad

**Drop the seven role thresholds.** No match-engine test in any Football Manager version shows a cliff at 13–15 in any of the attributes they gate. FM27's only data-backed "minimums" sit around 6, and they apply to different attributes (Work Rate, Pressure, Anticipation, Strength). Do not replace the thresholds with squad-median versions either. Instead, swap the linear (value − 1) / 19 scaling for range-aware curves built from harvestgreen22's FM27 test data. Give the engine-tested weights more of the blend than the in-game role attributes, because no FM27 test shows that role suitability itself moves results by much.

Evidence labels used throughout:
- **[SI]**: official Sports Interactive material.
- **[FM27-T]**: FM27 community testing with data.
- **[Carry]**: FM26 or earlier knowledge assumed to carry over.
- **[Spec]**: speculation or unsourced heuristic.

## TL;DR

- **Thresholds: drop them.** The seven fixed minimums match uncited community "tier" heuristics, not engine tests. FM27 tests find no step at 13–15. They also find that several gated attributes (Passing, First Touch, Vision, Off The Ball, Composure) have little or no measurable effect on results. On a squad rated 5–14, the penalty mostly adds noise that flips selections.
- **Relative scoring:** squad-relative thresholds only reward your squad's own weaknesses. The defensible reference is the opposition: FM27 tests measure gains against a fixed opponent baseline, and FM-Arena's engineers frame advantages as gaps over other players. But nobody has tested whether 8–12 players against 8–12 opponents behave like elite players against elite opponents. Use smooth curves, not penalties.
- **Weights:** no per-position FM27 weight table exists anywhere I could find. There is one squad-wide outfield table (harvestgreen22, about 51,000 matches) and one squad-wide xG table (Fm-Match-Lab, about 190,000 matches). Both put Pace and Acceleration first, then Jumping Reach and Stamina: harvestgreen22's FM-Arena summary says "Stamina is now the fourth most important attribute (still below Pace, Acceleration, and Jumping Reach)", and Fm-Match-Lab's order is "Jumping Reach, Stamina, Anticipation, Dribbling, Concentration". Your centre-back table is close. Your goalkeeper table appears to be FM24 regression data. Shift the 60/35/5 split towards about 70/30, using key role attributes only.

## Key Findings

### 1. What FM27 engine testing exists

**harvestgreen22, "FM27 Attribute Test + Tactical Understanding + Training…" (sortitoutsi thread 78219, with a summary on FM-Arena thread 20925; run on the Launch Preview build, late Oct to early Nov 2026) [FM27-T]**
- **Setup:**
  - All test players were 18 years old with 150 PA, 180 cm, 70 kg and every attribute at 12.\[1\]
  - Coaches had every attribute at 16; training facilities were 20.\[1\]\[2\]
  - The team used the preset Gegenpress tactic.\[1\]
  - Injuries and morale were locked with FMRTE.\[1\]\[3\]
- **Method:** one attribute at a time was set to 1, 6 or 18. Each case was 5 opponent formations × 100 matches (500 matches), about 51,000 matches in total.\[1\]
- **Ranking for outfield players:**
  1. Acceleration, Pace\[3\]
  2. Jumping Reach, Work Rate, Stamina
  3. Pressure, Anticipation, Strength
  4. Finishing, Determination, Concentration, Dribbling\[4\]
- **Other conclusions:**
  - On FM-Arena (thread 20925) he describes the FM27 nerf attribute by attribute: "Dribbling、Agility、Aggression、Composure: Severely weakened; the impact is less than a quarter of what it used to be. Balance、Finishing、Long Shots、Concentration: roughly halved or cut to one-third. Work Rate: …approximately three-quarters of its previous value."
  - "Technique, Tackling, Vision, and Off The Ball all significantly reduce the winning rate."\[3\]
  - Several attributes are "ineffective in the range from 12 to 18".\[3\]
- **Not tested:** goalkeeper attributes, set-piece attributes, Teamwork, Leadership.\[1\]
- **Tactic dependence:** he argues the results do not depend on tactic, based on testing every preset in FM24 and FM26. For FM27 he infers this rather than testing it, because "the core game engine remains unchanged" [Carry].\[4\]

**Range breakdown of the same data** (FM-Player-Analyzer issue #17, opened 7 Nov 2026 by MaxenceSAUNIER) [FM27-T]
- The issue's author computed this from harvestgreen22's Excel file with an AI assistant.\[1\] harvestgreen22 did not publish it in this form.\[1\]
- Values are team-wide win-rate change in percentage points, with every player changed at once:

| Attribute | 1→18 | 1→6 | 6→12 | 12→18 |
|---|---|---|---|---|
| Pace | 59.4 | 13.2 | 26.8 | 19.4 |
| Acceleration | 48.1 | 12.6 | 21.4 | 14.1 |
| Stamina | 43.4 | 11.8 | 17.6 | 14.0 |
| Jumping Reach | 33.4 | 5.8 | 12.2 | 15.4 |
| Anticipation | 24.6 | 11.0 | 8.8 | 4.8 |
| Strength | 23.4 | 10.0 | 8.8 | 4.6 |
| Work Rate | 22.0 | 15.8 | 6.2 | 0.0 |
| Pressure (hidden) | 20.8 | 13.6 | 2.0 | 5.2 |
| Concentration | 17.8 | 7.8 | 5.6 | 4.4 |
| Natural Fitness | 15.4 | 8.6 | 4.0 | 2.8 |
| Balance | 14.2 | 6.0 | 8.2 | 0.0 |
| Dribbling | 10.4 | 3.0 | 3.8 | 3.6 |
| Finishing | 10.0 | 3.0 | 4.8 | 2.2 |
| Long Shots | 9.8 | 5.2 | 4.6 | 0.0 |
| Important Matches (hidden) | 8.8 | 3.8 | 5.0 | 0.0 |
| Determination | 8.8 | 6.0 | 0.0 | 2.8 |
| Agility | 8.6 | 5.2 | 3.2 | 0.2 |
| Consistency (hidden) | 7.6 | 4.4 | 2.0 | 1.2 |
| Heading | 6.8 | 5.2 | 1.6 | 0.0 |

- **Passing, Technique, First Touch, Tackling, Off The Ball:** around zero or slightly negative. The issue's author calls this "most likely noise".\[1\]
- **Precision:** the same author estimates a standard error of 2–3 points per difference, so values under about ±6 cannot be told apart from zero.\[1\]
- **Comparison with FM24:** Stamina went from about 21 to 43.4, and Work Rate fell from about 59 to 22.\[1\]

**caiograco289, Fm-Match-Lab (FM-Arena thread "FM27 Match Lab (macOS)", posted 12 Nov 2026; builds 27.0.0 and 27.0.1) [FM27-T]**
- **Method:** runs FM27's own engine outside the game. In the author's words: "So far I've thrown about 190,000 matches at it. Initially with the 27.0.0 version, but now also with the newest release 27.0.1". The tests use ten real matches from one newly promoted Premier League club, replaying "all ten matches 200-300 times" on fixed seeds.
- **Main result:** "+5 to each attribute across the squad" put Pace and Acceleration on top at "about +0.07 ppg per point". The author puts this in season terms: "+5 Pace across the squad is worth around 13 points a season", with "+0.1 points per game is roughly 4 points over a season". Next came Jumping Reach, Stamina, Anticipation, Dribbling and Concentration.
- **No measurable effect** (under about 0.1 ppg): Passing, Technique, First Touch, Crossing, Off the Ball, Tackling, Marking, Positioning.\[5\]
- **Goalkeeper Kicking** made results slightly worse.\[5\]
- **What the engine reads:** "Weight has exactly zero effect. CA, reputation and height showed nothing either. The engine plays on attributes, not on the CA number."\[5\]
- **Caveat that matters for interpreting the tests:** on a generic all-12 test match, mental attributes "looked close to worthless". On real matches, Anticipation and Concentration "clearly matter", and on the generic match most effects shrank "to about 40% of their real-match size".\[5\]
- **Per-point xG values:** the FM27Manager README quotes the Fm-Match-Lab per-point values as xG difference per game. These are Pace 0.10, Acceleration 0.09, Jumping Reach 0.07, Stamina 0.06, Anticipation 0.05, Dribbling 0.05, Concentration 0.04, Finishing 0.04, Balance 0.03, Composure 0.03, Work Rate 0.02 and Vision 0.02. Everything else showed "no clear effect".\[6\]

**Official Sports Interactive (match engine deep dive, 5 Oct 2026) [SI]**
- "Stamina now having a greater impact on your player's ability to both cover ground and make more repeated sprints with less recovery time. Stamina is also now a stronger factor on how your player's condition deteriorates over the course of 90 minutes." This matches the jump in Stamina in both FM27 tests.
- SI says it used Hawk-Eye data to recalibrate acceleration, turning, repeated sprinting and fatigue (as described by strikerless.com, 10 Oct 2026). SI's own deep-dive text, reposted on the SI Community forums, confirms the Stamina change quoted above.

**Breakdown by playing style:**
- No FM27 test splits attribute value by playing style.
- harvestgreen22's claim that "different tactics have different attribute requirements… has been proven incorrect" comes from FM24/FM26 testing [Carry].\[4\]
- The FM27 tests used Gegenpress (harvestgreen22) or one club's own 4-2-4 (Fm-Match-Lab).\[4\]\[5\]

**Per-position breakdown:**
- **I found no FM27 per-position weight table in any of the sources checked.** Both FM27 tests change the whole team at once.
- The closest per-position work is Orion's FM24 regression on FM-Arena ("Most important attributes for each respective positions with their coefficients") [Carry]. It gives goalkeeper coefficients of Agility 0.014640, Reflexes 0.012837, Aerial Reach 0.011812, Throwing 0.007465, Command of Area 0.007436, Handling 0.006255, Decisions 0.005089 and Rushing Out −0.003310.\[7\]
- Your goalkeeper weights (Agility 0.140 > Reflexes 0.130 > Aerial Reach 0.110) follow that order exactly. They are probably FM24 data relabelled as FM26 testing.
- Orion's model also regressed **match ratings**, not results, and used each attribute's **difference from the league average**.\[7\]\[8\]

**Comparison with FM26** (harvestgreen22, "I tested the attributes of FM26 and some other things", FM-Arena thread 15933) [Carry]

FM26 ranking:
1. Pace, Acceleration
2. Work Rate, Jumping Reach, Agility
3. Finishing, Dribbling, Concentration
4. Anticipation, Composure, Long Shots, Determination
5. Balance, Strength, Stamina, Aggression\[9\]

What changed in FM27:
- **Stamina** rose from tier 5 to joint third.
- **Work Rate** fell.
- **Agility** went from tier 2 to almost nothing (8.6).
- **Strength and Anticipation** rose.
- **Pace and Acceleration** stayed on top in both versions.

Your centre-back table (Jumping Reach 0.115, Pace 0.095, Acceleration 0.085, Tackling 0.080, Positioning 0.080, Anticipation 0.075):
- It roughly fits FM27 on Jumping Reach, Pace, Acceleration and Anticipation.
- It overweights Tackling and Positioning, which Fm-Match-Lab found had no measurable effect.\[5\]
- It is missing Stamina and Strength.

### 2. Linearity and cliffs

**Attribute value is not linear in FM27 [FM27-T].** Per point, from the table above (team-wide percentage points per +1):

| Attribute | 1–6 | 6–12 | 12–18 | Shape |
|---|---|---|---|---|
| Pace | 2.64 | 4.47 | 3.23 | steepest in mid-range |
| Acceleration | 2.52 | 3.57 | 2.35 | steepest in mid-range |
| Stamina | 2.36 | 2.93 | 2.33 | roughly linear |
| Jumping Reach | 1.16 | 2.03 | 2.57 | rises at the top |
| Anticipation | 2.20 | 1.47 | 0.80 | diminishing returns |
| Strength | 2.00 | 1.47 | 0.77 | diminishing returns |
| Work Rate | 3.16 | 1.03 | 0.00 | effect only at low values |
| Balance / Long Shots / Heading | — | — | ≈0 | worthless above 12 |

**What this means for your squad:**
- For Pace and Acceleration, going from 8 to 9 is worth more than going from 15 to 16. Your 5–14 squad sits in the steepest band.
- For Work Rate, Anticipation and Strength, the main danger is being very low, not failing to be high.\[1\]
- Interpret with care: with a standard error of about ±6 points per band, only the large shapes are reliable (Pace and Acceleration peaking mid-range, Work Rate's low-end effect, Jumping Reach rising).

**Evidence of minimum levels:**
- **FM27 [FM27-T]:** ZaZ's reading of harvestgreen22's data (SI forum "ZaZ – FM27" thread and FM-Arena "Player Attributes" thread, Nov 2026) gives "Minimum requirements: 6-12 (depending on your league) in Work Rate, Anticipation, and Strength. These hurt a lot when below 6, but do not improve as much above 12."\[10\]\[11\]
  - This is the only threshold-like FM27 finding I found.
  - It sits around 6, not 13–15.
  - It concerns attributes your thresholds do not gate.
  - It is a smooth drop in slope, not a cliff.
- **FM26 [Carry]:** harvestgreen22 said Decisions "must have more than 6 points; otherwise, it will greatly drag down the team's performance."\[9\]
- **FM24 [Carry]:** FM-Arena's admins concluded from their meta-attribute test (thread "FM24 – Meta Player Attributes") that "it doesn't seem there're minimal/optimal levels for other non-meta attributes that must be reached."\[12\]
- **Anecdotal [Spec]:** GeorgeFloydOverdosed reports that "'20' pace/acc will win games where even '17' pace/acc would see you get demolished". This was in extreme 1-CA test squads and is not a controlled test.\[13\]

**Where your thresholds come from:**
- Their shape (Winger Pace 15 / Acceleration 15 / Dribbling 14; Deep-Lying Playmaker Vision 14 / Passing 14; Centre Forward Finishing 14 / Off The Ball 13) matches uncited "minimum" lists on guide sites.
- footballgpt.co's FM26 attributes guide gives "Passing… (14+ minimum)", "Vision… (14+ minimum)", "Dribbling… (13+ minimum)", "Off The Ball (13+ minimum)" and "Finishing… (14+ minimum for elite)".\[14\]
- assman.ai gives "Inside Forward: Acceleration 15+, Off the Ball 14+, Dribbling 13+, Finishing 13+". It adds that these are "tier labels at the level you're playing at, not literal numbers across all leagues."\[15\]
- None of these cites a match-engine test.
- **My conclusion: your thresholds are a community heuristic aimed at elite squads, with no engine evidence behind them [Spec].** Worse, about half of the gated attributes (Passing, First Touch, Composure, Vision, Off The Ball) are ones FM27 tests find have little or no measurable effect on results.\[1\]\[5\]

### 3. Absolute or relative

**What the tests can and cannot say:**
- Every FM27 test changes your team while the opposition stays fixed (all-12 opponents, or a real Premier League fixture list).
- They measure an advantage over a given opponent. They cannot tell an absolute scale apart from a relative one.

**Pointers towards relative:**
- **FM-Arena admins [Carry]:** "when in our tactic testing league we set Acceleration attribute of a player to '20' then his Accelerating attribute will be 5-6 points higher than the Acceleration attribute any other player in the league."\[12\] Advantages are framed as gaps over others.
- **Orion's FM24 regression [Carry]:** subtracted the league average from every attribute.\[7\] Under that model "player from Vanarama National with low attributes might have the same average rating as other player with much higher attributes playing in English Premier League."\[7\]\[8\] This holds for match ratings, which may be normalised by design, so it does not prove the engine itself compares players relatively.
- **Reverse engineering of the old CM 97/98 engine** (johnnorthknowstoomuch, 2 Oct 2026) found "team and formation normalisation" before action resolution [Spec for FM27].\[16\] That is a different engine, nearly 30 years old.
- The claim on footballgpt.co that through-ball success depends on a "pace differential between attacker and defender" is unsourced [Spec].\[17\]

**Lower-league equivalence:**
- **Not tested in any version I could find.**
- FM-Arena's admins say they do not test lower-league settings "because the difficulty level in such environment is extremely low" [Carry, older thread].\[18\]
- They also say a test league with mental and technical attributes around 11–13 showed no "significant difference" in tactic rankings from their main league.\[19\] That covers tactic rankings, not role performance.
- Fm-Match-Lab's author warns his results come from "one club, mostly losing to better teams. A title-chasing side could look different."\[5\]

**Verdict:**
- The best working assumption is that duels are resolved relative to the opponent, because a race between a 10-pace striker and an 8-pace defender is decided by the gap. I label this [Spec] because it is untested.
- If thresholds are kept at all, they should be relative to the division, never absolute elite values.
- It is cleaner to drop them, because a smooth monotone curve already ranks your players correctly against each other.

### 4. How FM27 judges role suitability

**Star ratings [Carry]:**
- Long documented as squad-relative: "always relative to your own squad" (sortitoutsi FM26 guide; Passion4FM: "a five-star player in League Two might only be a single-star player in the Championship").\[20\]\[21\]
- FM27 scouting guides repeat this: "Stars are judged by your staff and compared with your own squad" (fmextratime, Nov 2026).\[22\]
- No official SI formula has been published.

**Role suitability within a role [FM27-T, small sample]:**
- FM27Manager's author found that a player's average over the role's **key attributes** (exact values) "put the roles in the game's order 92-95% of the time and picked a top-rated role every time". The test covered 20 role lists across 6 players.\[6\]
- In the same test, "every attribute beyond the key ones - preferable ones included - made the match worse".\[6\]
- FMRTE 27 claims "player role ratings using the game's formula" but does not publish the formula.\[23\]

**Player Role Suitability in Tactical Effectiveness [SI]:**
- SI lists four areas: Tactical Understanding, Player Ability, Player Buy-In and Next Match Information (FM27 Training and Tactical Effectiveness deep dive, 9 Oct 2026).\[24\]\[25\]
- Player Ability is split into Player Capability and Player Role Suitability.\[26\]\[27\]
- strikerless.com paraphrases SI as saying each component has "a separate and direct effect on match-engine performance".\[28\] I could not check this against SI's own wording.

**Size of the effect [FM27-T]:**
- **Composite formula (community reverse-engineering credited to lqf0624):** "'Tactical effectiveness' SCORE = ('Tactical Understanding' SCORE * 50%) + ('Player Ability' * 10%) + ('Player Buy-In' * 25%) + ('Next Match Info' * 15%)". Source: harvestgreen22, "Full analysis and testing of 'Tactical effectiveness' and 'Tactical Understanding'", sortitoutsi, Nov 2026.\[2\]\[29\] So Role Suitability is at most part of a 10% share.
- **Whole score:** ZaZ reports "about 3% improvement from 0 to 100% tactical effectiveness". On FM-Arena (thread 20925), harvestgreen22 had each group play 1,000 matches and concluded "Tactical Understanding only 3.5% increase in winrate so not important". The sources conflict, though: harvestgreen22's separate Tactical Effectiveness thread (sortitoutsi 78377) reports "0 → 20: Maximum profit zone, +15.3%", far above ZaZ's "about 3%".
- **Bigger levers measured by Fm-Match-Lab:**
  - Starters out of position (position ratings capped at 10) cost 0.85 ppg; capped at 15, 0.26 ppg.\[5\]\[6\]
  - 50% match sharpness cost a full point per game.\[5\] caiograco adds that "75% still cost about 0.37. Condition at 80% cost 0.8 ppg… Letting the AI manager run the match instead of your assistant cost 0.56 ppg."
- **No test isolates Role Suitability itself.** Fm-Match-Lab can edit roles but has not reported such a test.\[5\]
- **Conclusion:** the engine does read something called role suitability. Its measured contribution looks small next to position familiarity and the physical attributes, and there is no direct test.

### 5. What other FM27 tools do

| Tool (date) | Role-fit formula | Thresholds? | Normalisation |
|---|---|---|---|
| **FM27Manager / FM27Plus** (StrawzyCode README, Nov 2026) | Role fit = average of **key** attributes (exact 1–20 values); preferable attributes only a 5% tie-breaker. Default rating = 50% role fit (half in-possession, half out-of-possession) + 50% "match-engine fit" weighted by Fm-Match-Lab values, minus a position cost (0 at 20, 0.5 at 15, 2.0 at 10, 4.5 at 5, 7.2 at 1 attribute points), × footedness × availability. Goalkeepers use role fit only. | No | Absolute 1–20 |
| **FM-Player-Analyzer** (ElectroHugin, DWRS; PR #23 merged 11 Nov 2026) | Weighted average with key ×1.5 and preferred ×1.2 (the same multipliers as your tool). New FM27 profile uses "per-attribute curves from harvestgreen22's measurements" plus an optional 33% role share. No rating if less than 70% of the role's attribute weight is known.\[30\] | No | Absolute; squad-median comparison is a display colour option only |
| **FM27 System and Tactic Designer / FM27 Tactic Builder** (Dixnnn, v0.5–0.9, 10–11 Nov 2026) | Key ×3, preferred ×1.5, with engine-rewarded attributes (Pace, Acceleration, Anticipation, Decisions…) blended in; penalties for position and weak foot. Bands: 75+ excellent, 65+ good, 55+ usable.\[31\] | No | Fit scores "compare your own players with each other"; team instructions compare each unit with "its own general level (the average of all their outfield attributes), not with fixed numbers"\[31\] |
| **Genie Scout 27** (geniescout.com) | Role Rating for every FM role, in and out of possession; user-editable Rating Editor. Older documented formula: Σ(attribute × weight) / Σweights / 20 × position weight [Carry].\[32\]\[33\] | No | Absolute |

**None of these tools uses minimum thresholds.** The only squad-relative normalisation is the Tactic Builder's, and it is used for team instructions, not for player ratings.

## Recommendations

### A. Role thresholds: drop them (high confidence)

Remove all seven. Reasons:
1. There is no engine evidence for them in any version.
2. They gate attributes that FM27 finds nearly worthless.
3. They put a step at 13–15 where the data shows a smooth curve.
4. On your squad they collapse to the 80% floor, so they add a large, arbitrary multiplier that decides your striker choice.

If you want a floor, use the evidence-based one: a steep curve below 6 for Work Rate, Anticipation, Strength and (FM26) Decisions. This already comes out of the curves in section D.

### B. Relative thresholds: do not adopt (medium-high confidence)

If you ever reintroduce a reference point, here is what goes wrong with each choice:

- **Squad median:**
  - Half the squad fails each threshold by construction.
  - A uniformly slow squad sets a low pace bar, so the tool rewards your weaknesses.
  - The bar moves every time you sign or sell someone.
  - It adds nothing to ranking within the squad, which is all the selection step needs.
- **Best-XI average:** circular, because the XI depends on the rating that depends on the XI. It also collapses to "be as good as your starters", which penalises the bench for being the bench.
- **Division typical level:** the only one consistent with how duels probably work (relative to the opponent, [Spec]). You would need division-wide attribute data, which FM27Manager-style memory readers can supply.
  - Use it to **centre the curves** (subtract the division mean before applying the curve, as Orion did), not as a penalty.\[8\]
  - Even this is untested for lower leagues.

### C. The 60/35/5 split: move to about 70/30 (medium-low confidence)

- **The case for less role weight:** FM27 evidence says the engine rewards physical and a few mental attributes. No test isolates role suitability. Player Ability is reportedly 10% of a Tactical Effectiveness score worth about 3% win rate in total.
- **The case for keeping some:** role attributes still decide which role suits a player. FM-Player-Analyzer (33% role share) and FM27Manager (50%) both keep a substantial role share.\[30\]
- **Suggested change:**
  - 70% engine-weighted position score.
  - 30% role score built from **key attributes only**, with preferable attributes at most a 5% tie-breaker, following FM27Manager's star-rating match.
  - Fold the 5% bonus into the role score.
  - Keep your familiarity penalty, and calibrate it to Fm-Match-Lab: cap at 15 costs 0.26 ppg, cap at 10 costs 0.85 ppg.

### D. Revised weights (medium confidence for the base and curves; low for position multipliers)

**Outfield base weights** [FM27-T]:
- Built from harvestgreen22's 1→18 contributions, using visible attributes only and normalised to sum to 1.
- The hidden attributes Pressure, Important Matches and Consistency are dropped.
- Attributes with no measurable effect are set to 0.

**Curves:**
- Replace (v − 1) / 19 with the cumulative piecewise curve: the per-point slopes for 1–6, 6–12 and 12–18 from section 2, accumulated and divided by the 1→18 total.
- Extend 18–20 at the 12–18 slope.

**Position multipliers [Spec]:**
- These are not tested. They encode only ZaZ's note that Jumping Reach matters "especially for defenders" and the fact that Finishing and Long Shots matter only for players who shoot.\[11\]
- Apply them, then renormalise each position to sum to 1.

**Goalkeepers:**
- There is no FM27 data, so keep your current table [Carry; it is probably FM24 data].
- Consider setting Kicking to 0, because Fm-Match-Lab found it slightly negative.\[5\]

```json
{
  "version": "FM27-v1 (harvestgreen22 preview-build data; Fm-Match-Lab cross-check)",
  "outfield_base": {
    "Pace": 0.1668, "Acceleration": 0.1351, "Stamina": 0.1219, "JumpingReach": 0.0938,
    "Anticipation": 0.0691, "Strength": 0.0657, "WorkRate": 0.0618, "Concentration": 0.0500,
    "NaturalFitness": 0.0432, "Balance": 0.0399, "Dribbling": 0.0292, "Finishing": 0.0281,
    "LongShots": 0.0275, "Determination": 0.0247, "Agility": 0.0242, "Heading": 0.0191,
    "Passing": 0, "Technique": 0, "FirstTouch": 0, "Tackling": 0, "Marking": 0,
    "Positioning": 0, "OffTheBall": 0, "Crossing": 0, "Vision": 0, "Decisions": 0
  },
  "curve_slopes_per_point": {
    "Pace": [2.64, 4.47, 3.23], "Acceleration": [2.52, 3.57, 2.35], "Stamina": [2.36, 2.93, 2.33],
    "JumpingReach": [1.16, 2.03, 2.57], "Anticipation": [2.20, 1.47, 0.80], "Strength": [2.00, 1.47, 0.77],
    "WorkRate": [3.16, 1.03, 0.00], "Concentration": [1.56, 0.93, 0.73], "NaturalFitness": [1.72, 0.67, 0.47],
    "Balance": [1.20, 1.37, 0.00], "Dribbling": [0.60, 0.63, 0.60], "Finishing": [0.60, 0.80, 0.37],
    "LongShots": [1.04, 0.77, 0.00], "Determination": [1.20, 0.00, 0.47], "Agility": [1.04, 0.53, 0.03],
    "Heading": [1.04, 0.27, 0.00]
  },
  "curve_bands": [[1, 6], [6, 12], [12, 18]],
  "position_multipliers_SPECULATIVE": {
    "DC": {"JumpingReach": 1.5, "Heading": 1.5, "Strength": 1.25, "Finishing": 0, "LongShots": 0, "Dribbling": 0.5},
    "DL": {"Stamina": 1.25, "Finishing": 0.5, "LongShots": 0.5, "Heading": 0.5},
    "DR": {"Stamina": 1.25, "Finishing": 0.5, "LongShots": 0.5, "Heading": 0.5},
    "WBL": {"Stamina": 1.25, "Finishing": 0.5, "LongShots": 0.5, "Heading": 0.5},
    "WBR": {"Stamina": 1.25, "Finishing": 0.5, "LongShots": 0.5, "Heading": 0.5},
    "DM": {"Finishing": 0.5, "Heading": 0.75},
    "MC": {"Finishing": 0.5, "Heading": 0.75},
    "ML": {"JumpingReach": 0.75, "Heading": 0.5, "Dribbling": 1.5, "Finishing": 1.25},
    "MR": {"JumpingReach": 0.75, "Heading": 0.5, "Dribbling": 1.5, "Finishing": 1.25},
    "AML": {"JumpingReach": 0.75, "Heading": 0.5, "Dribbling": 1.5, "Finishing": 1.25},
    "AMC": {"JumpingReach": 0.75, "Heading": 0.5, "Dribbling": 1.5, "Finishing": 1.25},
    "AMR": {"JumpingReach": 0.75, "Heading": 0.5, "Dribbling": 1.5, "Finishing": 1.25},
    "ST": {"Finishing": 2.0, "Dribbling": 1.25, "Heading": 1.25}
  },
  "GK": "keep existing table (FM24/FM26 carry-over); set Kicking to 0",
  "blend": {"engine_position_score": 0.70, "role_key_attributes": 0.30, "role_preferable_tiebreak_within_role": 0.05},
  "thresholds": null
}
```

Note on the curve slopes: Fm-Match-Lab found mental effects shrink to about 40% on generic all-12 test matches.\[5\] harvestgreen22's figures for Anticipation and Concentration are therefore probably **understated**. Raising them by 1.5–2× is a reasonable [Spec] adjustment.

## Summary of Recommendations

| # | Recommendation | Confidence | Evidence label |
|---|---|---|---|
| 1 | Delete all seven fixed role thresholds | High | FM27-T (no cliffs; gated attributes near zero) + Spec (thresholds trace to uncited guides) |
| 2 | Do not use squad-median or best-XI thresholds | Medium-high | Spec (logic); Carry (tools don't do it) |
| 3 | If a reference point is wanted, centre curves on the division mean; never use absolute elite values | Medium-low | Carry (Orion FM24, FM-Arena framing) + Spec |
| 4 | Replace (v−1)/19 with range-aware curves; keep a soft floor below 6 for Work Rate, Anticipation, Strength | Medium | FM27-T (harvestgreen22, ZaZ) |
| 5 | Use the FM27 outfield base table; reweight Pace, Acceleration, Stamina, Jumping Reach up and Tackling, Positioning, Passing to zero | Medium | FM27-T (two independent tests agree on the top four) |
| 6 | Blend 70% engine / 30% role (key attributes only); fold in the 5% bonus | Medium-low | FM27-T (FM27Manager star match; Tactical Effectiveness ≈3%) + SI (role suitability exists) |
| 7 | Calibrate the familiarity penalty to −0.26 ppg at 15 and −0.85 ppg at 10 | Medium | FM27-T (Fm-Match-Lab) |
| 8 | Position multipliers are optional and untested | Low | Spec |
| 9 | Goalkeeper weights: keep, set Kicking to 0 | Low | Carry + FM27-T (Kicking slightly negative) |

## Caveats

- **Build:** harvestgreen22 ran his test on the Launch Preview build. He warned that "results may change with the final game version". Fm-Match-Lab used 27.0.0 and 27.0.1, and a hotfix (27.0.1 build 2503222) shipped on 12 Nov 2026.\[1\]\[5\]
- **Sample:** both FM27 datasets cover one tactic or one club. The Fm-Match-Lab club was a Premier League underdog, not a non-league side.\[1\]\[5\]
- **Derivation:** the range table was derived with AI help by a third party, not by harvestgreen22.\[1\]
- **Not checked directly:** I could not open the Fm-Match-Lab repository files or the official SI Tactical Effectiveness page. Those claims rest on the author's FM-Arena summary, tool READMEs and secondary sites.
- **Composite formula:** the Tactical Effectiveness weights (50/10/25/15) are community reverse-engineering, not SI.
- **What would settle the open questions:** run Fm-Match-Lab's `study.py` on ten of your own non-league matches. Test +5 Pace, a role swap for your two striker candidates, and a Winger versus Inside Forward choice. That would answer the lower-league and role-suitability questions for your save directly.

## Sources

1. [Feature request: update attribute weights for FM27 + allow user-editable weights · Issue #17 · ElectroHugin/FM-Player-Analyzer · GitHub](https://github.com/ElectroHugin/FM-Player-Analyzer/issues/17)
2. [harvestgreen22](https://sortitoutsi.net/user/profile/3257420)
3. [FM27 Attribute Test + Tactical understanding +Training system + preset tactics + "AI-reverse-engineering engine for test" - General Discussion - FM27 - Football Manager 27](https://sortitoutsi.net/content/78219/fm27-attribute-test-tactical-understanding-training-system-preset-tactics-ai-reverse-engineering-engine-for-test)
4. [FM27 Attribute Test + Tactical Understanding + Training](https://fm-arena.com/thread/20925-fm27-attribute-test-tactical-understanding-training/)
5. [FM27 Match Lab (macOS): Tool to simulate matches outside the game](https://fm-arena.com/threads/fm27-match-lab-macos-tool-to-simulate-matches-outside-the-game.96/)
6. [GitHub - StrawzyCode/FM27Manager](https://github.com/StrawzyCode/FM27Manager)
7. [\[FM24\] \[Experiment\] UPDATE - New match engines - Most important attributes for each respecitve positions with their coefficients](https://fm-arena.com/thread/14201-fm24-experiment-update-new-match-engines-most-important-attributes-for-each-respecitve-positions-with-their-coefficients/)
8. [\[FM24\] \[Experiment\] UPDATE - New match engines - Most important attributes for each respecitve positions with their coefficients](https://fm-arena.com/thread/14201-fm24-experiment-update-new-match-engines-most-important-attributes-for-each-respecitve-positions-with-their-coefficients/page-2/)
9. [I tested the attributes of FM26 and some other things](https://fm-arena.com/thread/15933-i-tested-the-attributes-of-fm26-and-some-other-things/)
10. [Player Attributes](https://fm-arena.com/threads/player-attributes.59/)
11. [ZaZ - FM27 - Tactics Sharing Centre (Upload/Download) - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612941-zaz-fm27/)
12. [FM24 - Meta Player Attributes](https://fm-arena.com/thread/8249-fm24-meta-player-attributes/)
13. [Understanding the match engine: Are meta tactics and meta attributes the cause or consequence of imbalances?](https://fm-arena.com/thread/16007-understanding-the-match-engine-are-meta-tactics-and-meta-attributes-the-cause-or-consequence-of-imbalances/)
14. [FM Player Attributes Guide - FM26 Tips](https://footballgpt.co/fm/fm-attributes)
15. [Reading FM Attributes for Tactical Fit](https://assman.ai/guides/reading-fm-attributes)
16. [CM 97/98 FAQ: What matters more, attributes or current ability?](https://johnnorthknowstoomuch.wordpress.com/2026/10/02/cm-97-98-faq-what-matters-more-attributes-or-current-ability/)
17. [FM Match Engine Tips - FM26 Tips](https://footballgpt.co/fm/fm-match-engine)
18. [\[FM24\] \[Experiment\] UPDATE - New match engines - Most important attributes for each respecitve positions with their coefficients](https://fm-arena.com/thread/14201-fm24-experiment-update-new-match-engines-most-important-attributes-for-each-respecitve-positions-with-their-coefficients/page-6/)
19. [Upcoming changes to the configuration of FM-Arena tactic testing league.](https://fm-arena.com/thread/1979-incoming-changes-to-the-configuration-of-fm-arena-tactic-testing-league/)
20. [FM26: How to Choose the Best Coach for Star Ratings and Reports - General Discussion - FM26 - Football Manager 26](https://sortitoutsi.net/content/75753/fm26-how-to-choose-the-best-coach-for-star-ratings-and-reports)
21. [All you need to know about STAR RATINGS on Football Manager • Passion4FM](https://www.passion4fm.com/football-manager-guide-star-ratings/)
22. [FM27 Scouting Guide: How to Find Great Players](https://fmextratime.com/articles/fm27-scouting-guide/)
23. [FMRTE 27 for Windows - Football Manager 27 - FMRTE](https://www.fmrte.com/files/file/183-fmrte-27-for-windows/)
24. [FM27](https://community.sports-interactive.com/forums/topic/612100-fm27-training-tactical-effectiveness-faqs/)
25. [FM27 Training and Tactical Effectiveness Explained](https://www.footballmanagerblog.org/2026/10/fm27-training-and-tactical.html)
26. [How to Deal with the New Tactical Effectiveness in FM27 - Ingenuity Fantasy Football](https://ingenuityfantasy.com/feature-articles/how-to-deal-with-the-new-tactical-effectiveness-in-fm27/)
27. [How Tactical Effectiveness & Complexity Revolutionize Squad Building & Recruitment in Football Manager • Passion4FM](https://www.passion4fm.com/fm27-guide-tactical-effectiveness-complexity/)
28. [Football Manager 27 Tactics and Training: What Looks Promising](https://strikerless.com/2026/10/10/football-manager-27-tactics-and-training-what-looks-promising/)
29. [Full analysis and testing of "Tactical effectiveness" and "Tactical Understanding" - General Discussion - FM27 - Football Manager 27](https://sortitoutsi.net/content/78377/full-analysis-and-testing-of-tactical-effectiveness-and-tactical-understanding)
30. [2.3.0-test.1: DWRS rating profiles per save, FM27 profile, colour tiers by ElectroHugin · Pull Request #23 · ElectroHugin/FM-Player-Analyzer](https://github.com/ElectroHugin/FM-Player-Analyzer/pull/23)
31. [GitHub - Dixnnn/FM27-System-and-Tactic-Designer](https://github.com/Dixnnn/FM27-System-and-Tactic-Designer)
32. [A Brand New Genie Scout rating system - Please Test!](https://fm-arena.com/thread/8500-a-brand-new-genie-scout-rating-system-please-test/page-2/)
33. [Genie Scout features for Football Manager](https://geniescout.com/features/)
