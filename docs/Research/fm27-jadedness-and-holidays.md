# FM27 jadedness and the holiday recommendation

Researched 21 November 2026, eleven days after release. Labels: (a) official SI, (b) FM27 test with data, (c) FM26 or earlier, carried over, (d) opinion or guess.

## Summary

1. At jadedness 183 and 108 the recommendation can be ignored when picking a team: no test in any version shows a cost below 400, and the only FM27 test shows nothing at all up to 0 and a modest cost at 500.
2. What it costs to ignore it is slower condition recovery, not worse play: in FM27 a player at 500 recovers 17% less condition over the same rest than one at 0 (9,225 against 9,574 from 7,500), and one at 1,000 recovers 43% less.
3. What triggers the game's message at 183 and 108 was not found. FM27's own jadedness status ("could do with a rest", Rst) was seen at 401 and 404 and not at 400, 397 or 302, so the message is probably not that status; it may be the Medical Centre's reading of match and training load, which nobody has tested.
4. The tool's model is wrong about the trend, not the line: a rest day's −20 belongs to full rest days only, and training days add jadedness. On the owner's own readings both players reach 400 within weeks if nothing changes.
5. The cheapest prevention is on the training side (a full rest day after each match, no pitch or gym work below full condition), not a holiday, which costs measured match sharpness (0.5% a day without training, plus the match missed).

## Findings

| Question | Finding | Value | Label | Source and date |
|---|---|---|---|---|
| 1 | FM27 shows "A little jaded and could do with a rest (Rst)" just above 400 | 401 Rst; 404 "Match fit but starting to get jaded"; 400 "Match fit"; 397 "Tired after last match"; 302 "Match fit" (five players, one save) | (b) | FM Lens `docs/EDITING-VALIDATION.md`, https://github.com/IamDejman/fm-lens (PR #138, 7 Nov 2026) |
| 1 | The wording above 400 seems to depend on condition too | 401 with energy 8,994 says Rst; 404 with energy 9,007 does not | (b), two players | Same |
| 1 | FM27 users in lower leagues report players who "need rest constantly", even after two weeks' rest | No numbers; no reply from SI | (d) | https://steamcommunity.com/app/4530370/discussions/0/569303380162465183/ (20 Nov 2026) |
| 1 | Reserve-side players can need a rest because of matches the fixture list does not show | SI: the games are in a league "below the FM database" | (a) for the hidden matches | https://steamcommunity.com/app/4530370/discussions/0/569303380162394522/ (19 Nov 2026) |
| 1 | A threshold near 250, or lower thresholds for teenagers and over-30s | No evidence found in any version with data | - | - |
| 2 | Jadedness slows condition recovery in FM27, and not at all between −500 and 0 | From 7,500, same rest: −500 → 9,574; 0 → 9,574; 500 → 9,225; 1,000 → 8,690 | (b), one table, four values | Fishi, post 19, https://fm-arena.com/threads/fm27-match-lab-macos-tool-to-simulate-matches-outside-the-game.96/ (13 Nov 2026) |
| 2 | A "fatigue" field found in the FM27 match engine has no effect in a match; the author doubts it is the real one | Overwritten in match preparation | (b), with the author's own doubt | caiograco, post 17, same thread (12 Nov 2026) |
| 2 | Fatigue is said to feed the odds of a pre-match "bad day" roll with Consistency and condition | Size not measured | (b) code reading, no number | caiograco, post 12, https://fm-arena.com/threads/inside-the-fm27-match-engine-how-it-actually-works.140/ (14 Nov 2026) |
| 2 | In FM24's engine, a whole eleven at fatigue 400 all season loses little | 400: −2.4 points a season; 600: −10.6. For scale: condition 95%: −6.0; sharpness 90%: −4.5 | (c), FM24, modded engine file | Forsti37, post 3, https://fm-arena.com/threads/summary-of-recent-findings-for-optimal-play-in-fm24.152/ (15 Nov 2026); tables at https://github.com/Forsti37/FM24-Companion `docs/findings/match-engine.md` |
| 2 | FM24 win rate and light injuries worsen between 400 and 500 | 38% → 33% wins; 107 → 130 light injuries per 1,000 matches | (c), FM24, taken from the repository's `jadedness-fatigue.md`; video not re-checked | https://www.youtube.com/watch?v=MProPfmJZ8o |
| 2 | Natural Fitness does nothing inside a match | 600 replays identical | (b) | Match Lab study 28, https://github.com/caiograco289/Fm-Match-Lab `docs/studies/28-stamina-natural-fitness.md` (Nov 2026) |
| 3 | Ignoring the recommendation: no test, no SI statement | - | no evidence found | - |
| 4 | Gain per match and loss per full rest day | +50 to +70 a match; −20 a full rest day | (c), FM26 | fm-arena "Conditions Management" parts 1 and 2 (Dec 2025; the pages are gone, see Sources) |
| 4 | Three days of different rest, FM24 | Rest sessions and holiday −152; rest sessions and manual rest −137; rest sessions only −101; recovery sessions −48 to −51; general training and holiday −69; general training and manual rest −57 | (c), FM24, from the repository's `jadedness-fatigue.md`; video not re-checked | https://www.youtube.com/watch?v=ujD4ol7Qviw |
| 4 | Every training session carries its own effect on fatigue in the game's data | Each session element −3 to +3 on condition, fatigue, injury risk, sharpness | (c), FM24 game file | FM24-Companion `docs/findings/training.md` |
| 4 | The game resets jadedness to −500 over the summer break | 1,587 of 59,301 players at exactly −500 early in the season | (b) | https://github.com/tozmoz/FMLibreEditor/pull/48 (1 Nov 2026) |
| 4 | Sharpness lost on a day without training | 0.5% a day, except the day after a match | (b) | ZaZ, post 1, https://fm-arena.com/threads/training-schedules.60/ (10 Nov 2026) |
| 5 | A full rest day after a match ("super-rest") is still used in FM27 | No FM27 numbers posted | (b) opinion from a tester | ZaZ, post 43, same thread, page 3 (15 Nov 2026) |
| 5 | Full rest days skip the training injury roll | Injury risk 13.8% → 4.0% with near-identical development | (b), second-hand: an AI-written summary of jamiebolden's test; the test itself not found | https://fm-arena.com/threads/fm27-playbook-27-1-0-what-the-tests-say-wins-matches-ai-analysis.221/ (18 Nov 2026) |
| 5 | Normal and Double intensity lowered match-day condition with no clear gain | No figures | (b), no data shown | nyutso, post 10, Match Lab thread (11 Nov 2026) |
| 5 | Training schedule barely changes development; double intensity adds a little | Every schedule within ±0.2 of pure rest in match value; double +1.7 CA a year | (c), FM24 | FM24-Companion `docs/findings/training.md` |

## 1. What makes the game recommend a rest or holiday

**The jadedness status fires just above 400 in FM27.** FM Lens's authors read the stored value beside the game's Fitness card for five players of one club in one save: 302 "Match fit", 397 "Tired after last match", 400 "Match fit", 401 "A little jaded and could do with a rest (Rst)", 404 "Match fit but starting to get jaded" (b). Their own conclusion: "a player is jaded above 400", with the wording past the line seeming to depend on condition as well. All five are prime-age players at a top club. Nobody has read the card for a teenager or a player over 30.

**So a recommendation at 183 and 108 is probably not that status.** Three other candidates, none tested:

- The Medical Centre's risk assessment. SI's own description of the condition tooltip lists "Overall Risk of Injury", "Match Load", "Training Load", "Injury Susceptibility" and "Fatigue" as separate inputs ((a), FM21 reveal, via https://realsport101.com/football-manager/football-manager-21-condition-fatigue-sharpness-changes-tooltip-injury-risk/, Nov 2020). A player who starts every match under high training intensity has a heavy match load and a heavy training load whatever his jadedness. That this is what recommends the holiday is a guess (d).
- Matches the first-team fixture list does not show. SI confirmed on 19 November 2026 that reserve-side players can be playing matches in a league below the database, which do not appear in the schedule, and the user reported those players "in need of a rest" with high match loads. A 16-year-old may also be playing for a youth side between first-team matches. Worth checking each player's own appearances (d).
- A fault. One FM27 user in League Two reports players who need rest constantly, again straight after a match even after two weeks' rest (20 Nov 2026, no reply). One report with no numbers (d).

**A level near 250, age-shifted thresholds (300 at 32 and over, 350 for teenagers), and shifts for Natural Fitness or Stamina:** no evidence found. They appear only in the unsourced FM26 guides already in the repository. International duty: no FM27 evidence found.

**What would settle it:** the exact words of the recommendation and the screen they appear on, with the player's Fitness card text and his Medical Centre match load and training load on the same day as the FMRTE reading.

## 2. What jadedness costs

**Condition recovery (FM27, measured).** Fishi set four fatigue values and rested the same time from condition 7,500: −500 and 0 both reached 9,574; 500 reached 9,225; 1,000 reached 8,690 (b). So nothing changes up to 0, a player at 500 is about 3.5 percentage points of condition short after that rest, and one at 1,000 about 8.8 points short. The length of the rest is not stated and only four values were tried. The loss from 500 to 1,000 (535) is larger than from 0 to 500 (349), so the curve steepens; a straight line from 0 gives at most about 1.3 points of condition lost at 183 and 0.8 at 108, and the true figures are likely lower (derived, d).

**Match performance.** Two FM27 sources from the same tester disagree in emphasis, and neither has a number:
- The engine does not read the "fatigue" field he found at kick-off, and changing it changes nothing in a replay; he doubts the field is the real one (b, 12 Nov 2026).
- Two days later, from reading the code: fatigue, with condition and the Consistency or Important Matches attribute, sets the odds of a random "bad day" taken off every attribute for the match. Size and odds unmeasured (b, 14 Nov 2026).

FM24 has numbers. Forsti37's engine harness, whole eleven held at the level, 10,000 seeds: fatigue 400 costs 2.4 points a season and 600 costs 10.6 (c). The same table puts 95% condition at −6.0 and 90% sharpness at −4.5, so an entire eleven at 400 costs less than half of what five points of condition does. His engine file was a mod (FM TWEAK v1.4), which he says gave almost the same results as the original before. The older FM24 win-rate test in the repository's notes (38% at 400, 33% at 500) points the same way: little at 400, more beyond. No test anywhere reports a cost below 400.

**Injury risk.** FM27: no measurement. FM24: light injuries 107 to 130 per 1,000 matches between 400 and 500 (c, not re-checked). Below 400: no evidence found.

**Condition lost during a match:** no evidence found for jadedness. In FM27 Stamina sets it (a player tires 2.5 − 0.075 × Stamina times as fast as a Stamina-20 player when running above 75% of top speed; caiograco's code reading, engine thread, 14 Nov 2026, b).

**Morale and complaints:** no evidence found.

**A young player's development:** no evidence found that jadedness slows it. What is measured (FM24, c) is that growth needs about 125 match points a month, four or five full matches, and falls away below about 100, so leaving a young player out costs growth directly.

## 3. What happens if the recommendation is ignored

No test and no developer statement was found, for any version. From section 2: below 400 nothing measurable is known to happen; between 400 and 600 the player recovers less condition between matches, and an FM24 team lost a few points a season; whether FM27 adds injuries or unhappiness is untested.

## 4. How jadedness builds and clears

- **Per match:** +50 to +70 (c, FM26). The owner's own three-day readings (+25 to +60 net for starters) fit this once the days around the match are counted. Per minute: no evidence found.
- **Age, Natural Fitness, Stamina, position, pressing, tempo:** no evidence found with data, in any version. Natural Fitness is confirmed unused inside a match in FM27 (b) and is assumed to act between matches (d).
- **Training.** The game stores a fatigue effect for every session element (c, FM24 file), and SI says FM27 shows how each session affects fatigue and injury risk (a, already in the repository's notes). So training alone can raise jadedness. No FM27 figure per day or per intensity was found. The FM24 three-day test shows the size of the difference: three days of rest sessions cleared 101, three days of general training with the player manually rested cleared 57, recovery sessions about 50 (c).
- **A full rest day:** −20 (c, FM26, fm-arena). The FM24 test gives 34 to 51 a day when the schedule is rest sessions (c). The two disagree; both have data, from different versions and probably different starting levels. Neither is about a training day.
- **Rest from training for a day after a match** ("no pitch or gym work" does the same): "an enormous amount of Conditions recovered and a massive Jadedness reduction", one day being the most that helps (c, Zippo, 13 Dec 2025, no numbers in the text). Still recommended for FM27 by ZaZ (15 Nov 2026), with no numbers.
- **Holiday:** FM24, about 50 a day when the schedule holds rest sessions, about 23 a day when it holds general training (c). The gap is the long-reported fault that a player on holiday is still counted as training. FM27: no evidence found, except that the summer break returns players to −500 (b).
- **Cost of a holiday:** 0.5% sharpness for each day without training (b, FM27), so about 3.5% for a week, plus the 9% a full match would have added (10 points a minute, b). Match Lab puts a team at 75% sharpness 0.37 points a game down (b). Condition: no cost found.
- **Patch 27.1.0 (17 Nov 2026):** its published changes list nothing on fatigue, rest or training load (https://www.fmscout.com/a-fm27-update-27.1.0.html). ZaZ reports it changed how a schedule treats a rest day after a match: a full rest day is replaced by individual sessions in a week with no match, or a recovery session is added (post 66, 17 Nov 2026). A schedule built before the patch should be checked.

## 5. What prevents it most cheaply

| Measure | Evidence | Cost |
|---|---|---|
| Full rest the day after each match, with players below full condition on no pitch or gym work | FM26 test, no figures in text (c); FM24 three-day figures (c); FM27 tester's opinion (b, no data) | 0 sharpness the day after a match (b); little development (FM24: every schedule within ±0.2 of pure rest, c) |
| Lower training intensity | FM27: Normal and Double lowered match-day condition with no clear gain, no figures (b); effect on jadedness not measured | Double adds about 1.7 CA a year in FM24 (c) |
| Fewer training days in the week | Second-hand FM27 figure: injury risk 13.8% → 4.0% (b, unverified) | 0.5% sharpness for each day without training (b) |
| Leaving a player out of one match in N | No test. Arithmetic only: saves 50 to 70 and the match's condition loss | About 9% sharpness not gained; development for a young player |
| Substituting at 60 to 70 minutes | No evidence found on jadedness per minute | - |
| A planned holiday | FM24 only, and only with rest sessions in the schedule (c) | A week's sharpness and a match |

Nothing compares these head to head in FM27. The first two cost least on the evidence there is.

## What this means for the tool

- **The 400 line: keep it.** FM27's status appears just above 400 (b), and FM24 puts a whole eleven at 400 only 2.4 points a season down (c). If anything it is strict: the evidence would support a growing penalty from 400 rather than a hard exclusion at it. No evidence supports a lower line.
- **The 200 step: nothing supports 200 in particular.** FM27 shows no effect up to 0 and a recovery loss at 500, with nothing measured between. Treating a player as fully fresh for selection up to 400 is consistent with every test found. What should change is the condition projection: recovery falls by about 0.7 condition points for each jadedness point above 0 over Fishi's rest period (derived from two points, label it derived).
- **+60 a match: keep it** (c, and it fits the owner's readings).
- **−20 a day: apply it to full rest days only.** It was measured on full rest days (c). The tool takes it off every day without a match, which is why it predicts a fall of 50 a week where the save shows a rise.
- **The ×0.8 scaling at high intensity: no evidence for it.** The evidence is that training adds its own fatigue, not that it scales recovery. Replace it with an amount added on each training day. No published FM27 figure exists; the owner's readings (about +50 over three days for some players who did not start, falls of 15 to 25 for others) are the only FM27 numbers, and they are small and mixed. Before using them, check whether the players who rose played for another side or came on as substitutes.
- **Age effects: none supported.** No test in any version shows jadedness building faster, or the line lying lower, for teenagers or players over 30.
- **Add a warning on the trend, not the level.** On the owner's readings a weekly starter gains somewhere between 50 and 100 a week under the present training, so 183 reaches 400 in two to four weeks and 108 in three to six (arithmetic on two readings, d). The tool can read successive imports and say when a player is on course to cross 400.

## Still untested

- What triggers the rest or holiday recommendation at values under 400, and whether age changes it.
- Any cost of jadedness between 0 and 500, and the shape of the recovery curve.
- FM27 gain per match and per minute, and its dependence on age, Natural Fitness, Stamina, position and tactics.
- What each FM27 training intensity and session adds a day, and what a full rest day, a rest from training and a holiday remove.
- Whether the holiday fault (still counted as training) is in FM27.
- Injury risk against jadedness in FM27, and the size of the "bad day" roll.
- Any effect on morale, complaints or development.

## Sources

Read for this report:
- Fishi and caiograco, "FM27 Match Lab", fm-arena, 11 to 13 Nov 2026: https://fm-arena.com/threads/fm27-match-lab-macos-tool-to-simulate-matches-outside-the-game.96/ (the fatigue table is an image attached to post 19)
- caiograco, "Inside the FM27 match engine", fm-arena, 14 Nov 2026: https://fm-arena.com/threads/inside-the-fm27-match-engine-how-it-actually-works.140/
- Match Lab studies, GitHub, Nov 2026: https://github.com/caiograco289/Fm-Match-Lab (`docs/FINDINGS.md`, `docs/studies/28-stamina-natural-fitness.md`)
- FM Lens, `docs/EDITING-VALIDATION.md` and `docs/EDITOR-FIELDS.md`: https://github.com/IamDejman/fm-lens
- FMLibreEditor PR 48, 1 Nov 2026: https://github.com/tozmoz/FMLibreEditor/pull/48
- ZaZ, "Training Schedules", fm-arena, 10 to 17 Nov 2026: https://fm-arena.com/threads/training-schedules.60/
- Forsti37, post 3 of "Summary of recent findings for optimal play in FM24", fm-arena, 15 Nov 2026: https://fm-arena.com/threads/summary-of-recent-findings-for-optimal-play-in-fm24.152/ and https://github.com/Forsti37/FM24-Companion (`docs/findings/`)
- "FM27 Playbook 27.1.0", fm-arena, 18 Nov 2026 (AI-written summary): https://fm-arena.com/threads/fm27-playbook-27-1-0-what-the-tests-say-wins-matches-ai-analysis.221/
- Zippo, "Rest exploit - FM26", fm-arena, 13 Dec 2025, archived copy of 26 Mar 2026: https://web.archive.org/web/2026/https://fm-arena.com/thread/16424-rest-exploit-fm26/
- Steam, Football Manager 27 discussions, 19 and 20 Nov 2026: https://steamcommunity.com/app/4530370/discussions/0/569303380162394522/ and https://steamcommunity.com/app/4530370/discussions/0/569303380162465183/
- FM27 update 27.1.0 notes, FM Scout: https://www.fmscout.com/a-fm27-update-27.1.0.html
- SI, "5 tips" article for FM26 (fatigue and the Medical Centre, no numbers): https://www.footballmanager.com/node/1067

Could not be read:
- community.sports-interactive.com refuses automated requests, so no SI forum thread or bug report was read.
- sortitoutsi.net refuses them too (the FM27 "Optimal training schedules" and attribute-test threads).
- fm-arena was rebuilt for FM27. Its old thread addresses, including the FM26 "Conditions Management" parts 1 and 2 cited in the repository's notes, now return "not found" and have no archived copy; their figures here are taken from the repository's notes.
- The two FM24 videos behind the rest and injury figures were not re-checked; their numbers are as the repository's `jadedness-fatigue.md` gives them.
