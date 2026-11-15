# Keep or Loan? What Actually Develops a Young Player in Football Manager 27

**Keep him: a 15–17-year-old at a club with top-level training facilities should almost never be loaned to a poorly equipped lower-league side, and the answer only changes at about 19, when match minutes become most of his growth.** No FM27-specific test of attribute growth existed by mid-November 2026. The best evidence is FM24 and FM26 testing plus an FM24 reverse-engineering of the development code (posted November 2026), and all of it points the same way. Under-18s get a guaranteed monthly "match experience" credit and grow about 60% of full speed with no matches at all.\[1\] Facilities cost little when they are poor. Minutes only start to dominate from about 19, and become essential from 21.\[2\]

## TL;DR

- **Under 18: keep him.** EBFM's tests, summarised on FM-Arena, show 14–18-year-olds reach "~60% (~12 CA/season)" with no matches; the same summary gives a yearly cap of "~12.5 CA without matches. ~25.5 CA with matches." For this age band, "u18/u23/II squad placement is ~95% of senior placement", and "u18/u23 friendlies are worth ~75% of proper senior matches". Developing on a poor training ground costs at most about 13.5% of the training effect. On top of that, the game appears to block loans of 16-year-olds in England. Your tool's rule of "loan anyone with room to grow who isn't first-team ready" is wrong for this age band [CARRY-OVER].
- **19–20 is the switch point.** With no matches, growth falls to about 35% of maximum, about 5 CA a season, against about 14 CA a season with 20–30 matches. At 21–26, no matches means almost no growth.\[1\] From 19, loan a player who will not get regular senior football at your club. The FM-Arena summary (thread 15934, p.24) says "21+ = Need at least 15 full matches (1350 minutes) per season to develop adequately, 25-35 is ideal", with 19–20 "Inbetween". Require him to be a regular starter at the highest level available, and treat the loan club's facilities as a minor tie-breaker [CARRY-OVER].
- **Occasional teenage minutes are worth almost nothing for development.** Tests find a short substitute appearance adds negligible growth. One test found that bringing players on after the 70th minute may be worse than not playing them.\[1\] For lineup choices, give little development weight to under-18s and the most to 19–23-year-olds [CARRY-OVER / SPECULATION where noted].

## Key Findings

| # | Finding | Label | Source and date |
|---|---|---|---|
| 1 | FM27 training was overhauled. Senior squads focus on match preparation and youth squads on individual development. Individual training still develops attributes.\[3\] SI publishes no development rates. | [OFFICIAL] | SI, "FM27: Training & Tactical Effectiveness", footballmanager.com/fm27/features/fm27-training-and-tactical-effectiveness (Oct 2026) |
| 2 | FM27 replaced the old training Units system.\[3\] | [OFFICIAL] | Same SI page (Oct 2026) |
| 3 | Ages 14–18: "no matches will cap growth at ~60% (~12 CA/season)"; 20–30 matches gives about 20 CA. Ages 19–20: no matches about 35% (~5 CA); 20–30 matches about 14 CA. Ages 21–26: no matches about 0; 20–30 matches about 12 CA. The opening post adds: "CA gain cap per year is ~12.5 CA without matches. ~25.5 CA with matches." | [CARRY-OVER] (EBFM tests summarised for FM24/FM26) | FM-Arena "Summary of recent findings for optimal play in FM24 & FM26", page 2 and opening post, fm-arena.com/thread/15934 (thread started 31 Oct 2025) |
| 4 | Ages 14–18: "u18/u23/II squad placement is ~95% of senior placement", but "u18/u23 friendlies are worth ~75% of proper senior matches. For age 19-20, it's ~64%". | [CARRY-OVER] | Same, page 2 (citing EBFM) |
| 5 | Players under the "youth path" are credited with a minimum monthly match band whether or not they play: 60–100 points. Only match points above that band add growth. The development check reads at most 150 points a month.\[4\] | [CARRY-OVER] (FM24 memory analysis) | LightningFlik, FM-Arena "Some training and development conventional wisdom for FM24", fm-arena.com/thread/20900 (~8 Nov 2026) |
| 6 | Maximising match experience for an under-18 adds about 1.5–1.7 CA a month (measured on 2 players, 50 seeds each). A rebuttal found the boost appears once rather than compounding: over 36 months, 76→108 CA at 100 points vs 76→100 at 150.\[4\]\[5\] | [CARRY-OVER], disputed | LightningFlik thread (Nov 2026); GitHub issue on FM-24-Match-Harness (undated) |
| 7 | Match points = minutes × match weight × level ratio.\[4\] Minutes are counted in 5-minute steps, capped at 90. 45+ minutes gives ±1 step depending on team strength, plus 1 for player of the match.\[4\] A Premier League game gave a 17-year-old 2.5× the points of a U21 game. A U21 friendly against seniors gave 29 points.\[4\] | [CARRY-OVER] | LightningFlik thread (Nov 2026) |
| 8 | Training facilities: level 10 gives 97.4% of the effect of level 20, level 5 gives 92.1%, level 1 gives 86.5%.\[6\] | [CARRY-OVER] (FM24 test) | harvestgreen22, FM-Arena thread 13975 (FM24 era; posted early January, year not shown) |
| 9 | Matches per season (same test): 30 games gives 97.4% of the growth of 100 games, 20 gives 88.4%, 15 gives 80.6%, 0 gives 65.9%. About 25 games reaches 95%. League reputation 50–200: "no difference".\[6\] | [CARRY-OVER] | harvestgreen22, thread 13975 |
| 10 | Ambition 1 → 73.1% of growth, Ambition 20 → 104.9%. Determination 1 → 66%, Determination 20 → 101% (both relative to 10).\[6\] | [CARRY-OVER] | harvestgreen22, thread 13975 |
| 11 | When a player is on loan, the loan club's training facilities count, but only as a small slice. GeorgeFloydOverdosed's breakdown: "21% Competitive matches ---> 85% Division Reputation ---> 8% Loan club training facilities (if loaned out) ---> 7% Club Reputation", alongside "34% Natural growth 25% Randomness ... 20% Training". | [CARRY-OVER] (author's synthesis, figures "oversimplified") | GeorgeFloydOverdosed, FM-Arena thread 15934, opening post (31 Oct 2025) |
| 12 | Youth Facilities affect intake juniors only. All visible players, whatever their age, use Training Facilities.\[7\] | [CARRY-OVER] / community claim made for FM27 | SI forum, "The FM27 (!!!) Youth Academy Challenge" (Nov 2026) |
| 13 | In England, 16-year-olds reportedly cannot be loaned. Loans open at 17, and only for players on fixed-term contracts.\[8\]\[9\] | [SPECULATION] (community consensus, no SI confirmation) | SI forum topic 592561; Steam FM24 discussion; Passion4FM loans guide (undated) |
| 14 | FM27 Tactical Understanding: training counts about twice as much as match exposure. This is tactical familiarity, not attribute growth.\[10\] | [FM27-DATA] | FM-Arena "FM27 Match Lab (macOS)" thread (Nov 2026) |
| 15 | An older test claimed no development at all without competitive matches.\[11\] This is contradicted by every later test. | [CARRY-OVER], superseded | Zippo, FM-Arena thread 2671 (pre-FM24) |

## 1. What drives growth, by age band

**What FM27 confirms officially.** Sports Interactive's FM27 training feature describes a split of purpose. The senior squad is "more attuned with match preparation, focusing more on team cohesion and tactical understanding". You must now "balance their long-term Individual Training and personal development priorities with your short-term need to win matches." SI also says the "previous Units system, primarily centred around developing player attributes, has been replaced".\[3\] SI gives no rates. Nothing official says the age curve or the role of matches changed, so I assume the underlying growth model carried over from FM26. That model was itself described as "largely the same under the hood" as FM24 by the FM-Arena testers\[12\] [SPECULATION that it carries to FM27].

**Measured shares (FM24/FM26 tests, carry-over).** The best age-banded numbers are EBFM's tests, summarised on FM-Arena:

| Age | No matches | 20–30 matches/season | Share of growth that needs matches |
|---|---|---|---|
| 14–18 | ~60% of max (~12 CA/season) | ~20 CA/season | ~40% |
| 19–20 | ~35% (~5 CA/season) | ~14 CA/season | ~65% |
| 21–26 | ~0% | ~12 CA/season | ~100% |
| 27–28+ | negligible either way | +1–2 CA | n/a |

Sample sizes and held-constant conditions are not stated in the summary, so treat these as approximate. The 27+ row comes from an older FM-Arena test in which raising age from 21 to 28 cut a season's gain from +8.4 to +1.2 CA.\[11\]

**The mechanism (FM24 code analysis, carry-over).** LightningFlik's November 2026 reverse-engineering explains why youngsters grow without playing:
- Up to age 18 plus a hidden offset of 1–4 years, a player develops on a "youth path".\[4\]
- On that path he is automatically credited with a minimum match band each month, worth 60–100 points depending on professionalism.\[4\]
- Only match points above that free band add growth, and the monthly reading is capped at 150 points.\[4\]

His age table for Omari Kellyman shows how sharply growth falls once that path ends: about +1.26/+1.46/+1.46 CA a month at 16/17/18, then +0.28 at 19 and +0.26 at 20.\[4\]

**My view.** The two sources agree in direction: training plus the youth-path credit carries under-18s, and matches dominate from about 19. The older claim that "if players don't participate in competitive matches then they don't develop", from a pre-FM24 FM-Arena test,\[11\] is contradicted by every later test and the code analysis, so I discount it.\[11\] An older community line, from ZaZ in FM-Arena thread 2671, was: "Around the age of 18, it's around 50-50, and around the age of 23, match experience counts way more than training." That fits the measured numbers reasonably well.

## 2. What counts as a match, and how it is weighted

- **What counts.** EBFM's tests (summarised in FM-Arena thread 15934, page 2) separate squad placement from matches. For ages 14–18, "u18/u23/II squad placement is ~95% of senior placement", while "u18/u23 friendlies are worth ~75% of proper senior matches. For age 19-20, it's ~64%" [CARRY-OVER]. The code analysis shows youth and reserve games and friendlies all generate match points; a U21 friendly against the senior side gave 29 points\[4\] [CARRY-OVER].
- **Weighting.** Match points = minutes × match weight × level ratio [CARRY-OVER]:\[4\]
  - **Minutes:** min(minutes, 90) ÷ 5, rounded down, minimum 1.\[4\]
  - **Match weight:** depends on the average ability of everyone on the pitch, the competition level and the opponent's reputation.\[4\]
  - **Level ratio:** the competition's level divided by the highest level at which the player has "established himself" (11+ appearances in a domestic league season).\[4\]
  - **Example:** a Premier League game gave 17-year-old Kellyman 2.5× the points of a U21 game.\[4\]
  - **Implication:** for a player with no senior history, a League Two or National League game should score well above a U18 game. I have not seen this measured at lower-league levels [SPECULATION].
- **Thresholds.** There is no hard 45-minute threshold, because minutes count continuously in 5-minute steps. Playing 45+ minutes adds +1 step if his team is stronger (−1 if weaker), and +1 for player of the match\[4\] [CARRY-OVER].\[4\] The opening post of FM-Arena thread 15934 says "the game measures the minutes rather than appearances, so putting on the player for last 10 minutes will count as 10 minutes towards the full 2520 minutes that's optimal" [CARRY-OVER].
- **Monthly cap.** Yes. Development reads at most 150 match points per month and resets on the player's monthly development day\[4\] [CARRY-OVER].
- **Reputation.** harvestgreen22 found league reputation of 50–200 made "no difference" to growth in a controlled test\[6\] [CARRY-OVER, tested "no effect"]. A different FM-Arena synthesis says growth on loan is "hard-capped by division reputation" (thread 15934).\[2\]\[12\] The two conflict. I trust the controlled test more for growth rate. A ceiling effect at very low reputation is plausible but untested [SPECULATION].
- **Match rating and result.** The code analysis found match rating does not matter except player of the match, and the result does not matter.\[4\] EBFM likewise found winning rate irrelevant [CARRY-OVER, tested "no effect"].\[1\]

## 3. Training facilities, youth facilities and coaching

- **Training facilities: measured, and smaller than folklore says.** In harvestgreen22's FM24 test, level 10 gave 97.4% of the effect of level 20, level 5 gave 92.1%, and level 1 gave 86.5%\[6\] [CARRY-OVER]. The tester's conclusion: "a club with a level 10 training facility is basically growing at full speed."\[6\] The test's age and other conditions are not stated on the page I read; his related tests used age 20, Professionalism 20 and PA 200.\[13\]
- **Youth facilities: mainly affect the intake, not visible players.** A detailed FM27 forum guide states Youth Facilities apply to "Juniors (only)" and that "All visible players currently at the club use Training Facilities regardless of age"\[7\] [CARRY-OVER/community]. An FM-Arena synthesis rates Youth Facilities at about 1% of newgen quality.\[12\] The old FM22 manual says youth facilities give young players "many of the same benefits"\[14\] [OFFICIAL, FM22]. I trust the newer, test-based reading. For your tool, Training Facilities are the number that matters for a 16-year-old who is already in your squad.
- **Coaching quality and workload.** I found no controlled test of coach star ratings or workload on attribute growth in FM24, FM26 or FM27. That is a real gap.
  - SI-forum guidance from older versions holds that the lead coach's star rating sets a category's quality and that heavy workload reduces effectiveness (community, older versions).\[15\]\[16\]
  - FM26 removed direct control of B, reserve and youth training (FMScout, JonasMorais guide).\[17\]
  - FM27 replaced Units altogether.\[3\] So the category-coach mechanics may not apply in FM27 as before [SPECULATION].
  - Treat coaching as plausibly similar in size to facilities (a single-digit percentage), not a dominant factor.
- **First team vs youth teams.** Training facilities apply to every visible player. In FM27, SI says youth squads put more attention on individual development, while senior squads prepare for matches\[18\] [OFFICIAL]. So a 16-year-old in your U18s probably gets *more* individual-development training time than one sitting in the first team [SPECULATION based on official description].

## 4. On loan: whose facilities, and what it costs

- GeorgeFloydOverdosed's synthesis (FM-Arena thread 15934, opening post, 31 Oct 2025) says the loanee's growth uses the *loan club's* training facilities, but only as a small slice: "21% Competitive matches ---> 85% Division Reputation ---> 8% Loan club training facilities (if loaned out) ---> 7% Club Reputation". Community explanations agree a loaned player trains at the loan club [CARRY-OVER/community].
- **Size of the cost:** harvestgreen22's figures put the worst case at 86.5% vs 100% of the training effect (facility 1 vs 20).\[6\] For a typical National League or League Two ground (roughly mid-scale), the loss is probably 2–8% [CARRY-OVER plus SPECULATION on typical lower-league ratings].
- **Comparison with the gain from playing:**
  - For a **16–17-year-old**, matches only add growth above the free youth band. With high professionalism that band already sits at 100 points, so he needs 125+ points a month before minutes help at all.\[4\]
  - A full 90 minutes produces about 18 minute-steps. Multiplied by a match weight near 1 and a level ratio somewhat above 1, that is roughly 20–30 points a game. Four or five starts a month gives about 80–150 points.
  - So for a professional teenager, a lower-league loan *at best* adds about one band, worth up to roughly 1.5 CA a month. The rebuttal test suggests even that may be a one-off rather than monthly.\[5\]
  - My rough estimate is that the facilities cost and the minutes gain roughly cancel for a 16–17-year-old. The arithmetic applies the FM24 formula to assumed lower-league values [SPECULATION].
  - For a **19+-year-old** the free band is gone or shrinking, so minutes are worth far more than the facilities cost\[4\] [CARRY-OVER].

## 5. When regular lower-level football beats top facilities

- **Below 18:** a loan is a mistake by default. Growth without matches is about 60% of maximum. For 14–18-year-olds, "u18/u23/II squad placement is ~95% of senior placement" and "u18/u23 friendlies are worth ~75% of proper senior matches" (FM-Arena thread 15934, p.2). The youth-path credit already covers most of what minutes would add [CARRY-OVER].
- **18:** this is the borderline age. The youth path often lasts to 19–22 because of the hidden offset, but growth after 18 is visibly lower in the code analysis.\[4\] Loan only for a guaranteed regular-starter role [CARRY-OVER + SPECULATION].
- **19–20:** a loan wins whenever your club cannot give regular senior football. With no matches, growth falls to about 35%. FM-Arena thread 15934 (p.24) puts 19–20 "Inbetween" its under-18 rule and its 21+ rule of "at least 15 full matches (1350 minutes) per season" [CARRY-OVER].
- **21+:** "Must be playing competitively or loaned out."\[2\] Loan even to poor facilities. As the FM-Arena summary puts it, "21+ you should loan them out even if it's to a team with poor training facilities"\[1\]\[12\] [CARRY-OVER].
- **Ability.** No test ties the loan decision to CA as such. What matters is that he will actually start. The practical rule: loan only if he is good enough to be a regular starter at the loan club's level [SPECULATION].

## 6. Can a 16 or 17-year-old be loaned in FM27?

- **16:** community reports consistently say 16-year-olds cannot be loaned out in England in FM ("16 year-olds cannot be loaned out anywhere", SI forum topic 592561; "In UK you cannot send players on loan until they are 17", Steam FM24 discussion). Passion4FM says players over 17 can be loan-listed and that "some leagues" allow 16-year-olds\[8\]\[9\]\[19\] [SPECULATION/community; not confirmed by SI for FM27].
- **17:** loanable, but reportedly only on a fixed-term contract. Non-contract or month-to-month players cannot be loaned\[8\] [community].
- **Work experience loans:** FM models them. An FM23 league-rules screen quoted on the SI forum reads: "There are no restrictions on domestic loans of players on youth contracts that qualify for work experience loans" [OFFICIAL in-game text, FM23].\[20\] I could not confirm a separate FM27 menu option.
- **Real-world rules FM mirrors:** The FA Standardised Rules (6.6.5) say "Youth Loan Transfers apply to:- Scholars in their second or third (if that option is exercised) year of their Scholarship". They also say "The minimum period of a Youth Loan shall be 28 days" and that "Youth Loans cannot extend beyond the date of the Player's 21st birthday". Youth-loaned players can still train and play age-group football for the parent club.\[21\]\[22\] Whether FM27 lets a loanee keep training at the parent club is unknown.

## 7. Do occasional first-team minutes for a teenager help?

Barely.
- A 10-minute substitute appearance is worth 2 minute-steps, a few match points, against a free youth band of 60–100\[4\] [CARRY-OVER].
- EBFM found that bringing players on after the 70th minute "may actually make growth worse than no appearance, possibly due to foregone training" [CARRY-OVER].\[1\]
- Passion4FM's claim that 15 minutes or less is of limited development value agrees, but it is untested.\[19\]
- **The exception:** a full cup tie (45–90 minutes) at senior level scores several times a youth game, thanks to the level ratio.\[4\] It can help in a month where he is close to crossing a band [CARRY-OVER + SPECULATION].
- Folklore such as "even 15 minutes per match triggers growth" (several FM26 guides)\[23\] is not supported by any test I found.

## 8. Professionalism, ambition, determination

- **Professionalism** sets the youth player's free monthly band: 15+ gives band 4 (100 points), 6–14 gives band 3 (80 points), 5 or less gives nothing extra\[4\] [CARRY-OVER]. High professionalism therefore makes *minutes matter less* for under-18s. A low-professionalism teenager gains more from playing. Testers also call professionalism and game time "the two main contributors to growth".\[2\]\[12\]
- **Ambition:** 1 gives 73.1% of the growth at 10; 20 gives 104.9%\[6\] [CARRY-OVER]. Below 10 hurts; above 10 barely helps.\[6\]
- **Determination:** 1 gives 66%; 20 gives 101%\[6\] [CARRY-OVER]. A separate FM-Arena test found no direct effect above average.\[11\] Treat Determination below 10 as a penalty, not above-10 as a bonus.

## Recommendations for the tool

1. **Age gate for loan advice.**
   - **Age ≤16:** never advise a loan. It is probably impossible in England [SPECULATION/community], and he grows about 60% of maximum without matches [CARRY-OVER].
   - **Age 17:** advise "keep" by default when your Training Facilities are ≥ 10/20 [CARRY-OVER, facilities test]. Override to "loan" only if all of these hold:
     - (a) Professionalism ≤ 14, so his free band is ≤ 80 points;
     - (b) the loan offers Regular Starter status or better;
     - (c) the loan is in League Two or higher.
     This override is [SPECULATION] from the FM24 band arithmetic.
   - **Age 18:** advise a loan only for Regular Starter or better, at National League or higher, when he is projected for fewer than about 10 full games at your club [CARRY-OVER + SPECULATION].
   - **Age 19–20:** advise a loan if he is projected for less than regular senior football at your club. Use a threshold below the 21+ line: FM-Arena thread 15934 (p.24) sets "at least 15 full matches (1350 minutes) per season" for 21+ and puts 19–20 "Inbetween" [CARRY-OVER].
   - **Age 21–23:** advise a loan or sale if he is projected for fewer than 15 full games. Target 25+ games (≈95% of maximum growth) [CARRY-OVER].\[24\]
   - **Age 24+:** no development reason to loan. Growth is low and keeps falling toward 27–28 [CARRY-OVER].
2. **What to require of a loan.**
   - Expected minutes of at least 2,000 (about 22–25 full games) [CARRY-OVER: 25 games ≈ 95%].
   - Status of Regular Starter or better.
   - Treat loan-club Training Facilities as a tie-breaker only, with a floor around mid-scale. Below level 5 costs more than 8% [CARRY-OVER].
   - Prefer the highest division where he will still start, because the level ratio rewards it [CARRY-OVER].
3. **Lineup development bonus.** Express the bonus as expected CA gained per 90 minutes. These are derived from EBFM's per-season gaps divided by about 25 games [CARRY-OVER, derived]:
   - Ages 15–17: 0.1 per 90, and only for appearances of 45+ minutes. Set it to 0.2 if Professionalism ≤ 14.
   - Ages 18–20: 0.35.
   - Ages 21–23: 0.5.
   - Ages 24–26: 0.4.
   - Ages 27+: 0.
   - Give **zero** development credit for substitute appearances under 20 minutes [CARRY-OVER: EBFM late-sub finding].\[1\]
4. **Personality modifiers.** Multiply projected growth by 0.73–1.0 for Ambition below 10, and by 0.66–1.0 for Determination below 10 (linear). Apply no bonus above 10 [CARRY-OVER].

## Evidence gaps, and a test to close the biggest one

**Gaps:**
1. There is no FM27 attribute-growth test yet; every number above is carried over from FM24/FM26.
2. Nobody has tested directly whether a 16–17-year-old grows faster on a lower-league loan than at a top-facility parent club. This is your core decision.
3. Nobody has measured coach star rating or workload effects in recent versions, and FM27's removal of Units may have changed them.
4. Whether youth-path match points scale for League Two or National League games as the FM24 formula implies is unverified.
5. Whether a loaned teenager in FM27 keeps any parent-club training is unknown.

**A test for gap 2 in your own save:**
1. Take one 17-year-old with Professionalism 15+ and PA at least 30 above CA, and one with Professionalism ≤ 12. Save on the first day of a month before the loan window shuts.
2. **Branch A (keep):** keep him in your U18/U21 side, starting every youth fixture, with the same individual training.
3. **Branch B (loan):** loan him to a National League or League Two club as Regular Starter, with no recall.
4. Simulate four months, then record CA and the sum of attributes (use FMRTE or Genie Scout).
5. Reload and repeat at least 10 times per branch to average out randomness.
6. Hold constant: start date, your training facilities, individual training focus, and no injuries (discard runs with injuries over 2 weeks). Also record the loan club's Training Facilities level and his actual minutes.
7. If Branch B beats Branch A by more than 1 CA on average for the low-professionalism player but not for the high one, the band model above holds in FM27 and the tool's age-17 override is right.

## Sources

1. [Summary of recent findings for optimal play in FM24 & FM26](https://fm-arena.com/thread/15934-summary-of-recent-findings-for-optimal-play-in-fm24-amp-fm26/page-2/)
2. [Summary of recent findings for optimal play in FM24 & FM26](https://fm-arena.com/thread/15934-summary-of-recent-findings-for-optimal-play-in-fm24-amp-fm26/page-1/)
3. [FM27: Training and Tactical Effectiveness](https://www.footballmanager.com/fm27/features/fm27-training-and-tactical-effectiveness)
4. [Some training and development conventional wisdom for FM24](https://fm-arena.com/thread/20900-some-training-and-development-conventional-wisdom-for-fm24/)
5. [Training simulation issues · Issue #2 · PhilipArmstead/FM-24-Match-Harness · GitHub](https://github.com/PhilipArmstead/FM-24-Match-Harness/issues/2)
6. <https://fm-arena.com/thread/13975-how-training-facilities-match-played-height-league-reputation-ambition-determinationand-affect-attribute-growth/>
7. [The FM27 (!!!) Youth Academy Challenge - Challenges, Sign-Ups & Experiments - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612408-the-fm27-youth-academy-challenge/)
8. [Can’t offer player for loan - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/592561-can%E2%80%99t-offer-player-for-loan/)
9. [Loan question please.. :: Football Manager 2024 General Discussions](https://steamcommunity.com/app/2252570/discussions/0/4518883158017743770/)
10. [FM27 Match Lab (macOS): Tool to simulate matches outside the game](https://fm-arena.com/threads/fm27-match-lab-macos-tool-to-simulate-matches-outside-the-game.96/)
11. [Player Development and Training](https://fm-arena.com/thread/2671-player-development-and-training/)
12. [Summary of recent findings for optimal play in FM24 & FM26](https://fm-arena.com/thread/15934-summary-of-recent-findings-for-optimal-play-in-fm24-amp-fm26/)
13. [(Tentatively) New training schedule renderings based on attribute test results, welcome to propose more combination](https://fm-arena.com/thread/13712-tentatively-new-training-schedule-renderings-based-on-attribute-test-results-welcome-to-propose-more-combination/)
14. [Club Details and Board Performance - Football Manager 2022 Touch and Football Manager 2022 Xbox Edition - Sports Interactive Community](https://community.sports-interactive.com/sigames-manual/football-manager-2022-touch-and-football-manager-2022-xbox-edition/club-details-and-board-performance-r4533/)
15. [Coaches and their star ratings - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/439305-coaches-and-their-star-ratings/)
16. [Training Guide - Football Manager 2022 - Neoseeker](https://www.neoseeker.com/football-manager-2022/guides/Training)
17. [FM26 Training Guide & Schedules by JonasMorais](https://www.fmscout.com/a-fm26-training-guide-and-schedules-by-jonasmorais.html)
18. [Football Manager 27 Training and Tactical Effectiveness Details Revealed](https://www.operationsports.com/football-manager-27-training-and-tactical-effectiveness-details-revealed/)
19. [Using Loans to Improve Youth Development on Football Manager](https://www.passion4fm.com/using-loans-to-improve-youth-development-on-football-manager/)
20. [A Question For The Non-League Experts Regarding Vanorama Loan Rules - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/601560-a-question-for-the-non-league-experts-regarding-vanorama-loan-rules)
21. [Coping with the loan transition in professional association football - ScienceDirect](https://www.sciencedirect.com/science/article/pii/S1469029222000267)
22. [Joe Hugill](https://en.wikipedia.org/wiki/Joe_Hugill)
23. [FM26 Youth Development Guide: Youth Intake, Mentoring & Wonderkids — FM26 Tactics Guide](https://www.fm26tactics.com/guides/youth-development-guide)
24. [Summary of recent findings for optimal play in FM24 & FM26](https://fm-arena.com/thread/15934-summary-of-recent-findings-for-optimal-play-in-fm24-amp-fm26/page-24/)
