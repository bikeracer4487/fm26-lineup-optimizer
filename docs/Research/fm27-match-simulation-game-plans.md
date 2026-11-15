# Football Manager 27 simulated-match game plans: what they do and which to pick

**I found no measured FM27 result for any game plan, so nothing yet supports picking one plan over another based on what the opponent is like. The only measured comparison of the plans is a small FM26 test: 10 instant results per plan against a single much stronger opponent (Arsenal).\[1\] In that test "Play for the draw" (10 pts) and "Play for the win" (9 pts) came out on top and "Settle for a draw" (1 pt) and "Smash and grab" (2 pts) came out worst. At that sample size the gap between the top plans is noise. Separately, measured FM27 engine data shows that defensive tactics and a more attacking mentality both cost points. It also shows that fitness and team selection matter far more than any tactical tweak: in the words of Fm-Match-Lab's author caiograco, "Nothing I changed on the tactics screen came anywhere near those." Until you run the test described below, your tool should default to "No game plan" (your own tested tactic, unchanged). It should never recommend the plans that sit deep or settle. Put the tool's real effort into who starts (condition and match sharpness) rather than into which plan is chosen.**

## TL;DR

- **Nothing in FM27 is measured.** No FM27 test of the simulate-match game plans exists that I could find: not from Fm-Match-Lab, FM-Arena, harvestgreen22, ZaZ or SI. The only measured comparison is FM26 (FRVR, 10 instant results per plan against one much stronger opponent). It ranked Play for the draw (10 pts) ≈ Play for the win (9 pts) > Leave it late (8) > Go for a big win (7) > Pressure cooker (6) > Smash and grab (2) > Settle for a draw (1).\[1\]
- **What a plan is:** the plans are fixed, non-editable presets of the old "match plan" templates. They switch mentality, shape and substitutions as the score and the clock change. In FM26 custom plans were removed for instant result,\[2\] and an FM27 Launch Preview user reports they are still disabled.\[3\] "No game plan" plays your tactic as set.\[4\]
- **What FM27 measurements do say:** the engine punishes sitting deep. Park the Bus scored 0.86 ppg against 1.80 for STORMBRINGER 27 BBMIW 424, the best tactic tested, and "Lock It Down" was negative from kick-off. Per caiograco (Fm-Match-Lab), starters at 50% match sharpness "cost a full point per game" (1.03 ppg), 75% sharpness cost about 0.37, and 80% condition cost 0.8 ppg. CA and reputation had no measurable effect. Attributes drive results, above all Pace and Acceleration at "about +0.07 ppg per point".
- **Rule for the tool:** default to "No game plan" in every situation. Exclude "Settle for a draw", "Strangle the game" and "Smash and grab". Treat "Play for the win" and "Play for the draw" as tied with "No game plan" (the evidence does not separate them). Spend the tool's logic on lineup freshness.
- **The cheapest way to settle it:** about 100 save-and-reload instant results per plan on one fixture, for 3 plans. That detects a difference of about 0.5 points per game; detecting about 0.3 ppg needs about 300 per plan. Log xG as well, so xPts can cut the sample size needed.\[5\]

## Key Findings

| # | Finding | Label | Source and date |
|---|---|---|---|
| 1 | No FM27 measurement of simulate-match game plans found in any community testing venue | — (gap) | Searches of FM-Arena, sortitoutsi, SI forums, FM Scout, Nov 2026 (27.0.1) |
| 2 | FM26, 10 instant results per plan vs Arsenal (user's team underdog): Play for the draw 10 pts, Play for the win 9, Leave it late 8, Go for a big win 7, Pressure cooker 6, Smash and grab 2, Settle for a draw 1\[1\] | [CARRY-OVER] | FRVR, FM26 (patch and date not stated) |
| 3 | FM26: the plans are fixed presets; custom match plans cannot be used with instant result; the match plan prompt pops up when using instant result\[2\] | [CARRY-OVER] | SI forum "Match Plans Impact", FM26 (user posts, no SI reply seen) |
| 4 | FM27: user reports custom match plans for instant result remain disabled ("last it was in FM24")\[3\] | [SPECULATION] (user report, unconfirmed by SI) | SI Official FM27 Feedback Thread p.1, Launch Preview, from 29 Oct 2026 |
| 5 | FM27 instant result: user reports "no substitutions at all" and no yellow cards visible\[6\] | [SPECULATION] (single user report; may be a display issue) | SI Official FM27 Feedback Thread p.20, Nov 2026 |
| 6 | In-match management by the AI manager instead of the assistant cost 0.56 ppg\[7\] | [FM27-DATA] | caiograco, Fm-Match-Lab, FM-Arena, 11–12 Nov 2026, 27.0.0/27.0.1 |
| 7 | Defensive presets performed worst: Park the Bus 0.86 ppg and Catenaccio 1.20, vs 1.80 for STORMBRINGER 27 BBMIW 424, the best tactic tested; about 1 xG less created per game and slightly more conceded ("Even as an underdog, sitting deep doesn't pay in this engine") | [FM27-DATA] | caiograco, Fm-Match-Lab, 11 Nov 2026, 27.0.0/27.0.1 |
| 8 | One step more attacking mentality cost a little xGD; points showed no clear change\[5\] | [FM27-DATA] (flagged as being rerun) | caiograco, Fm-Match-Lab, 11 Nov 2026 |
| 9 | Tactical Tweaks applied from kick-off to presets were mostly negative, especially "Lock It Down" (late-game use not tested)\[5\] | [FM27-DATA] | caiograco, Fm-Match-Lab study 08, 12 Nov 2026, 27.0.1 |
| 10 | Match sharpness 50% vs 100% cost 1.03 ppg and 75% cost 0.37; condition 80% cost 0.8; out-of-position starters cost 0.85\[5\]\[7\] | [FM27-DATA] | caiograco, Fm-Match-Lab, 11 Nov 2026 |
| 11 | CA, reputation, height and weight showed no measurable effect; the engine plays on attributes; Pace and Acceleration came out on top at "about +0.07 ppg per point", and "+5 Pace across the squad is worth around 13 points a season" | [FM27-DATA] | caiograco, FM-Arena "what we know so far" and "FM27 Match Lab" post #1, Nov 2026, 27.0.1 |
| 12 | Players gain about 10 match-sharpness units per minute played in an instant-result match (a substituted player gained 800, a full 90 gained 900)\[8\] | [FM27-DATA] (small in-game test) | ZaZ, SI forums "ZaZ – FM27", Nov 2026 |
| 13 | Holiday through a whole season scored 75 pts (7th) for a team predicted 17th; ZaZ won the league playing the matches himself\[9\] | [FM27-DATA] (n = 1 season each) | ZaZ, SI forums "ZaZ – FM 27 Preview", Launch Preview, Oct–Nov 2026 |
| 14 | 27.0.1 changed how often pushes lead to fouls and yellow cards; no patch note mentions instant result or match plans\[10\] | [OFFICIAL] | SI release notes via FM Scout, 10 Nov 2026, 27.0.1 |
| 15 | Older versions: "No match plan" uses your tactic as set; the assistant intervenes only for injury subs\[4\] | [CARRY-OVER] (forum explanation, FM Touch era) | SI forum "Instant result match plan", pre-FM26 |

## 1. What exists

**The list of plans.** I could not find a source that reproduces FM27's simulate-match menu word for word, and I found no tooltip text for any version. The preset names have stayed the same from the FM Touch/Console era through FM26:\[11\]

- Play For The Draw
- Settle For A Draw
- Play For The Win
- Go For A Big Win
- Smash And Grab
- Leave It Late
- Pressure Cooker
- Strangle The Game

Each also has a "do not use a match plan" option.\[12\]\[13\] FRVR's FM26 test uses the same eight names.\[1\] Your description of FM27 ("No game plan", "Play for the win", "Play for a draw") fits this list, but the exact FM27 labels and tooltip text are **unverified**. In older versions the descriptions were not tooltips: you saw them by creating a match plan from a template in the Match Plans wizard.\[11\]\[12\]\[14\] That wizard is gone, because FM26 dropped custom plans.

**Where the plan is chosen.**
- **Instant result:** FM26 shows the plan prompt when you click instant result (SI forum, FM26).\[2\] FM27 user reports describe instant result from the pre-match screen, and greyed out once a match has started (feedback thread p.20).\[6\] That FM27 behaviour is unconfirmed by SI.
- **Holiday and delegating matches to the assistant:** I found no evidence that you can choose a plan. On holiday, the assistant takes charge and gets the credit.\[15\]\[16\]\[17\]
- **Is the list the same in every case?** Unknown.

**What changed from FM26 to FM27.** I found no official statement. The only FM27 signal is a Launch Preview user complaint that custom match plans for instant result are disabled.\[3\] FM26 users had already reported that loss,\[2\] so the likeliest reading is "no change since FM26". Also, the plans were not new in FM26: they are the old match-plan templates, made non-editable when FM26 launched.

**FM27 patch notes.** The 27.0.1 notes (10 Nov 2026) say nothing about instant result or game plans. Neither does the 27.0.1 build 2503222 hotfix (12 Nov). SI says the first post-launch update, due "later this month", covers 3D match-engine behaviour.\[10\]

## 2. What each plan does

- **Mechanism (CARRY-OVER).** Each preset is a match-plan template: a set of scenarios keyed to score and time (drawing at 0–45, 45–70 and 70–90 minutes, leading, trailing).\[18\]\[19\] Each scenario can change mentality, shape, instructions and substitutions. Forum explanations describe instant result as "a set (or not, depending on Match Plan) of pre-set tactics and instructions … applied depending on the situation (time, scoreline)".\[19\] So a plan is **not** a modifier applied to the result; it changes in-match tactics. Nobody has published the FM26/FM27 contents of each preset.
- **"No game plan" (CARRY-OVER).** It uses your tactic exactly as set (mentality, shape, roles, instructions, set pieces). In older versions the assistant only stepped in for injury subs.\[4\]\[20\] Whether "No game plan" makes normal substitutions in FM27 is unverified; see section 4.
- **Full match engine or a quick calculation?** For your own matches, the evidence points to the full engine. Fm-Match-Lab drives FM27's own engine and its author describes it as "like doing an instant results in game".\[7\] FullerFM (FM24 era) states your team's matches always use the full engine, whether you play, holiday or instant result.\[15\] A modder claims FM27 picks player output for simulated matches from a statistical table (simatch.fmf) with only "two or three ability levels". His own test found no change on matches you watch,\[21\] and it is unclear whether that table applies to your instant-result matches or only to other teams' fixtures. Treat that as unresolved.
- **Is your eleven and tactic used as picked?**
  - FM26 Steam users report that instant result can field different players from the ones you selected. One reply says the assistant picks the squad just before kick-off; others call it a bug.\[22\] That is unresolved and FM26-only.
  - In the FM27 lab, the assistant is the in-match manager. Swapping it for the "AI manager" (which changes tactic and lineup) cost 0.56 ppg.\[7\]
  - The author says he understands that assistant mode equals instant result.\[7\] That is his inference, not something he decoded.

## 3. Which plan wins

**FM27: nothing measured.** That is a gap, not a finding of "no difference".

**FM26: one test (FRVR).**
- **Setup:** 10 instant results per plan from the same save, in one league fixture against a much stronger Arsenal side.\[1\] Home or away, the patch and the article date are not stated. The author also played the match himself once (2-2).\[1\]
- **Results** (W-D-L where the full list was readable):

| Plan | Points | Record |
|---|---|---|
| Play for the draw | 10 | 2-4-4, GF 16 / GA 19 |
| Play for the win | 9 | 2-3-5 |
| Leave it late | 8 | 2-2-6 |
| Go for a big win | 7 | 2-1-7 |
| Pressure cooker | 6 | one win |
| Smash and grab | 2 | 0-2-8 |
| Settle for a draw | 1 | 0-1-9 |
| Strangle the game | not legible | ranked level with Smash and grab |

- **What it can tell you.** With n = 10 the standard error of points per game is about 0.4. So the top four plans (0.7–1.0 ppg) are statistically indistinguishable. Only the gap between the best and worst plans (about 1.0 vs 0.1–0.2 ppg) is likely to be real.
- **One copying error in the sources.** Some copies of the article attach a "2 points" total to the wrong plan.\[1\] The game-by-game list for Play for the draw adds up to 10.\[1\]
- **Splits you asked for:** home/away, knockout vs league, two-legged ties, what's at stake, and opponents other than "much stronger" are **not tested anywhere** I could find.

**Indirect FM27 evidence (FM27-DATA, not a plan test).**
- Fm-Match-Lab replayed ten real Premier League matches 200–300 times each on paired seeds. The team was a newly promoted, mostly underdog side.\[5\] Results:
  - Sitting deep was heavily punished even as the underdog.\[5\]
  - "Lock It Down" from kick-off was negative.\[5\]
  - More attacking mentality slightly lowered xGD.\[5\]
- **Inference:** plans whose job is to drop deep or "kill" a game (Settle for a draw, Strangle the game, probably Smash and grab) are likely to cost points. That matches FM26's worst results. Plans that keep your tactic close to normal should do about as well as your own tactic.

**Forum opinion (SPECULATION, older versions).** One user's rule: "go for the win" against weaker and equal teams, "Smash and grab" or "Leave it late" against better ones.\[12\] Another reports that holiday did slightly better than instant result.\[23\] Neither is measured.

## 4. Side effects

- **Substitutions.**
  - FM27: one user reports no substitutions in instant result (unconfirmed; the FM27 match report also reportedly no longer lists subs clearly).\[6\]\[24\]
  - FM26: one user first said instant result made no substitutions, then corrected himself after checking ("instant results do substitutions").\[25\]
  - Older versions: some plans ("play for the draw", "settle for a draw") reportedly made no subs, and pressing instant result mid-match stops all subs.\[15\]\[26\]\[27\]
  - **Your tool should check minutes played after each simulated match.**
- **Sharpness and fringe minutes.** Players gain about 10 sharpness units per minute (ZaZ, FM27).\[8\] So whether a plan makes subs directly decides how much sharpness bench players gain. That matters because sharpness is among the largest measured effects (50% sharpness = −1.03 ppg).\[7\]
- **Condition, injuries, cards, ratings, morale.** No plan-specific data in any version. The 27.0.1 foul and yellow-card change affects all matches.\[10\]

## 5. Judging the opponent

- **How the game decides who is favourite:** I found nothing on how FM27 internally rates the favourite (odds, reputation, form).
- **What drives results (FM27-DATA):**
  - CA and reputation had no measurable effect on results with attributes held fixed.\[7\]
  - Results come from attributes. Biggest effects per point: Acceleration +0.068, Pace +0.062, Jumping Reach +0.035, Stamina +0.034 ppg.\[7\]
  - Starting condition and match sharpness at kick-off are among the largest effects measured.\[5\]
- **Recommendation (inference, not validated):** to predict a simulated result, build an attribute-weighted team score from both starting elevens (weighting Pace and Acceleration most) and adjust it for condition and sharpness. The pre-match odds or CA star rating are likely worse predictors. Nobody has tested which exportable measure predicts best, so check yours against your own results log.

## 6. Anything else that changes the answer

- **Tactics and formations.** In FM27 lab tests caiograco ran "23 tactics on the same ten matches: the 10 FM27 presets plus 13 tactics I'd downloaded", and "Every preset was worse". HIGHWAY STAR 27 BBM 4231 P90 and ZaZ Ace of Spades were "basically level" with STORMBRINGER. A plan that swaps your tested tactic for preset-style behaviour may therefore cost more with a strong custom tactic than with a preset. This is untested.
- **Familiarity.** According to caiograco, an untrained tactic "costs around 0.4 ppg", a well-trained one (about 75 per area) gains about 0.2, and going from low to high familiarity in every area is "worth about +0.5 ppg, about the same as +7 Pace for the whole squad". So mid-match switches into unfamiliar shapes could compound the loss. This is an inference.
- **Bugs and exploits.** There is the reported missing-subs problem. There is no known plan exploit. Third-party mods ("Super Vacation" retry-for-a-win, simatch.fmf replacements) change simulated outcomes and would contaminate any test.\[21\]\[28\]
- **Patches.** 27.0.1 (10 Nov) and hotfix build 2503222 (12 Nov) do not mention plans. The lab author found pre- and post-27.0.1 attribute effects correlated at r = 0.98.\[7\] The coming update targets 3D match-engine behaviour; re-test after it.\[10\]

## Rule the tool can compute

| Competition | Opponent vs you | Venue | At stake | Recommended plan | Evidence label | Confidence |
|---|---|---|---|---|---|---|
| League | Much stronger | Home or away | Any | No game plan; Play for the draw and Play for the win not separable from it | [CARRY-OVER] FRVR n=10 + [FM27-DATA] engine | Low |
| League | Stronger | Any | Any | No game plan (untested) | [FM27-DATA] indirect | Low |
| League | Similar | Any | Any | No game plan (untested) | [FM27-DATA] indirect | Low |
| League | Weaker / much weaker | Any | Any | No game plan; Play for the win not separable | [SPECULATION] | Low |
| League | Any | Any | Draw is enough | No game plan; avoid Settle for a draw / Strangle the game | [CARRY-OVER] + [FM27-DATA] (defensive shifts cost points) | Low–medium for the "avoid" part |
| Knockout (single leg, extra time/penalties) | Any | Any | Must win | No game plan; no evidence for any other plan | none | Very low |
| Two-legged tie | Any | Any | Protecting a lead | No game plan; avoid sit-deep plans | [FM27-DATA] indirect | Low |
| Any | Any | Any | Nothing at stake | No game plan + rotate for sharpness; check that subs happened | [FM27-DATA] (sharpness effects) | Medium for rotation, low for the plan |
| Any | Any | Any | Any | Never: Settle for a draw, Smash and grab (Strangle the game likely) | [CARRY-OVER] FRVR (0.1–0.2 ppg) + [FM27-DATA] | Low–medium |

## Evidence gaps and a test I can run

The biggest unknown is whether any FM27 plan beats "No game plan" in points.

**The cheapest test.**
1. Take one fixture where you are a clear underdog or a clear favourite, and save just before you click instant result.
2. For each of three plans (No game plan, Play for the win, Play for the draw), reload and simulate **100 times**.
3. Record the score, xG for and against, the substitutions made and minutes played, condition after the match, and cards.
4. Alternate the plans in the order of the reloads.
5. Disable mods.

**Why 100 repeats.** Points per match have a standard deviation of about 1.3. To detect a 0.5 ppg difference at α = 0.05 with 80% power needs n ≈ 2·(1.96+0.84)²·1.3²/0.5² ≈ 106 per plan. A 0.3 ppg difference needs about 295 per plan. An FM27 lab tester reports that xG-based expected points shrink the sample needed considerably, so compare plans on xPts first.\[5\]\[7\]

**The caveat.** If FM27 fixes the result before kick-off (one forum claim, unverified), reloads at the same point may repeat the same result.\[29\] Check the first 5 reloads for variation; if you get identical scores, advance one day before each run. Then repeat the test for the opposite strength band.

## Caveats

- Every FM27 engine number comes from tools that run the engine outside the game. The main one is Fm-Match-Lab (github.com/caiograco289/Fm-Match-Lab), a macOS port of lqf0624's FM Tactics Lab. Its author reports "about 190,000 matches" run on 27.0.0 and 27.0.1, with each change replayed 200–300 times on paired seeds, mostly on one newly promoted club's ten matches. For scale, he notes "+0.1 points per game is roughly 4 points over a season". The author says it is unclear whether in-game instant result matches the "assistant" setting he used.
- FRVR is a single fixture with 10 runs per plan, and its patch and date are unstated.
- Forum reports (missing subs, disabled custom plans) are individual users, not SI statements.\[3\]\[6\]
- I could not open the SI forum pages or FM-Arena's summary thread directly; some details come from search snippets.

## Sources

1. caiograco, "FM27 Match Lab (macOS): Tool to simulate matches outside the game", FM-Arena, 11–12 Nov 2026, FM27 27.0.0/27.0.1 (build 2503222) — https://fm-arena.com/threads/fm27-match-lab-macos-tool-to-simulate-matches-outside-the-game.96/
2. caiograco, "FM27 match engine: what we know so far", FM-Arena, Nov 2026, 27.0.1 — https://fm-arena.com/threads/fm27-match-engine-what-we-know-so-far.122/
3. FRVR, "Football Manager 26 Instant Results Ranked", FM26 (patch/date not stated) — https://frvr.com/blog/news/football-manager-26-instant-results-ranked-why-your-instant-results-choices-actually-matter/
4. SI Community, "Match Plans Impact", FM26 — https://community.sports-interactive.com/forums/topic/600478-match-plans-impact/
5. SI Community, "The Official FM27 Feedback Thread" p.1, Launch Preview, from 29 Oct 2026 — https://community.sports-interactive.com/forums/topic/612416-the-official-fm27-feedback-thread/
6. SI Community, "The Official FM27 Feedback Thread" p.20, Nov 2026 — https://community.sports-interactive.com/forums/topic/612416-the-official-fm27-feedback-thread/page/20/
7. FM Scout, "Football Manager 2027 Patch 27.0.1 – Update Beta to Final", 10 Nov 2026 — https://www.fmscout.com/a-fm27-update-27.0.1.html
8. SI Community, "ZaZ – FM27", Nov 2026 — https://community.sports-interactive.com/forums/topic/612941-zaz-fm27/
9. SI Community, "ZaZ – FM 27 Preview", Launch Preview, Oct–Nov 2026 — https://community.sports-interactive.com/forums/topic/612421-zaz-fm-27-preview/
10. SI Community, "Match Plans in the Simulate Match menu", FM Console/Touch era — https://community.sports-interactive.com/forums/topic/460669-match-plans-in-the-simulate-match-menu/
11. SI Community, "Instant result match plan", FM Touch era — https://community.sports-interactive.com/forums/topic/331189-instant-result-match-plan-instant-reults/
12. SI Community, "how does instant results work?", FM Touch era — https://community.sports-interactive.com/forums/topic/306272-how-does-instant-results-work/
13. Steam Community, "Instant result uses different players to the ones chosen", FM26 — https://steamcommunity.com/app/3551340/discussions/0/603044859897820826/
14. FullerFM, "The Instant Result Button: Click Here To Win?", 18 Jul 2025, FM24 — https://fullerfm.com/2025/07/18/the-instant-result-button-click-here-to-win/
15. FM Scout, "Realism Match Engine 2.0 – Simulated matches" (mod), Nov 2026, 27.0.1 — https://www.fmscout.com/a-realism-match-engine-mod-fm27.html
16. fm-base, "Instant Result settings" (forum opinion, older FM) — https://fm-base.co.uk/threads/instant-result-settings.134118/
17. lqf0624, FM Tactics Lab (GitHub), v1113.1 for 27.0.1+2503222, 12 Nov 2026 — https://github.com/lqf0624/fm-tactics-lab

## Sources

1. [Football Manager 26 Instant Results Ranked - why your Instant Results choices actually matter - FRVR](https://frvr.com/blog/news/football-manager-26-instant-results-ranked-why-your-instant-results-choices-actually-matter/)
2. [Match Plans Impact - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/600478-match-plans-impact/)
3. [The Official FM27 Feedback Thread - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612416-the-official-fm27-feedback-thread/)
4. [Instant result match plan - Instant reults - FM Console and FM Touch General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/331189-instant-result-match-plan-instant-reults/)
5. [FM27 Match Lab (macOS): Tool to simulate matches outside the game](https://fm-arena.com/threads/fm27-match-lab-macos-tool-to-simulate-matches-outside-the-game.96/)
6. [The Official FM27 Feedback Thread - Page 20 - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612416-the-official-fm27-feedback-thread/page/20/)
7. [FM27 match engine: what we know so far](https://fm-arena.com/threads/fm27-match-engine-what-we-know-so-far.122/)
8. [ZaZ - FM27 - Tactics Sharing Centre (Upload/Download) - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612941-zaz-fm27/)
9. [ZaZ - FM 27 Preview - Tactics Sharing Centre (Upload/Download) - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612421-zaz-fm-27-preview/)
10. [Football Manager 2027 Patch 27.0.1 - Update Beta to Final | FM Scout](https://www.fmscout.com/a-fm27-update-27.0.1.html)
11. [Match Plans in the Simulate Match menu - FM Console and FM Touch General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/460669-match-plans-in-the-simulate-match-menu/)
12. [Instant Result settings](https://fm-base.co.uk/threads/instant-result-settings.134118/)
13. [Instant result button](https://fm-base.co.uk/threads/instant-result-button.139002/)
14. [Instant Result Game Plans - FM Console and FM Touch General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/264237-instant-result-game-plans/)
15. [The Instant Result Button: Click Here To Win?](https://fullerfm.com/2025/07/18/the-instant-result-button-click-here-to-win/)
16. [Instant Result - General Discussion - FM27 - Football Manager 27](https://sortitoutsi.net/content/17539/instant-result)
17. [To Holiday or not to Holiday?](https://fm-base.co.uk/threads/to-holiday-or-not-to-holiday.112342/)
18. [FMC Instant Result.](https://fm-base.co.uk/threads/fmc-instant-result.102074/)
19. [how does instant results work? - FM Console and FM Touch General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/306272-how-does-instant-results-work/)
20. [Team instructions, match plans, and instant result - FM Console and FM Touch General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/340967-team-instructions-match-plans-and-instant-result/)
21. [REALISM MATCH ENGINE 2.0 Simulated matches](https://www.fmscout.com/a-realism-match-engine-mod-fm27.html)
22. [Instant result uses different players to the ones chosen. :: Football Manager 26 General Discussions](https://steamcommunity.com/app/3551340/discussions/0/603044859897820826/)
23. [Holiday Mode Verses Instant Result Verses Simulated Result Verses Playing the Game.](https://fm-base.co.uk/threads/holiday-mode-verses-instant-result-verses-simulated-result-verses-playing-the-game.151605/)
24. [The Official FM27 Feedback Thread - Page 17 - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612416-the-official-fm27-feedback-thread/page/17/)
25. [Official Football Manager 26 Feedback Thread - Page 275 - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/594137-official-football-manager-26-feedback-thread/page/275/)
26. [Instant result (simulate the game) - Assistant never does any subs - Gameplay Issues - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/previous-versions/football-manager-2023-console-edition-bugs-tracker/920_gameplay-issues/instant-result-simulate-the-game-assistant-never-does-any-subs-r11747/)
27. [Instant Result with subs? - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/432591-instant-result-with-subs/)
28. [FM27 mod "Super Vacation": test tactics, rotate squads, simulate seasons](https://fm-arena.com/threads/fm27-mod-super-vacation-test-tactics-rotate-squads-simulate-seasons.47/)
29. [Magician's tactical testing (new ME)](https://www.fmscout.com/q-34423-Magicians-tactical-testing-new-ME.html)
