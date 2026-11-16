# FM26 Instant-Result Game Plans: What They Contain, What Has Been Measured, and a Rule Your Tool Can Use

**Short answer: only one public test of FM26's preset game plans exists, and it backs one firm rule. Against a much stronger side, avoid "Settle for a draw", "Strangle the game" and "Smash and grab". In FRVR's ten-match test against Arsenal these three earned 1, 2 and 2 points from 10 games. "Play for the draw", "Play for the win" and "Leave it late" earned 10, 9 and 8. Nothing published tells the top three apart. Nothing published covers being the favourite, home against away, knockouts, or "No game plan" against a preset. I found no published list of what each FM26 preset contains: Sports Interactive has not documented them, and the only route to the template contents in earlier versions was the in-game Match Plan wizard (FM Touch and Console, up to FM24). Until you run the reload test at the end of this report, your tool should default to "Play for the win" or "No game plan" when you are the favourite, and to "Play for the draw" or "Play for the win" when you are a clear underdog. Mark every row except the underdog one as low confidence.**

## TL;DR

- **Measured [FM26-DATA]:** FRVR (Lewis White, 18 Dec 2025) ran 10 instant results per plan against a much stronger Arsenal. Points per plan: Play for the draw 10, Play for the win 9, Leave it late 8, Go for a big win 7, Pressure cooker 6, Smash and grab 2, Strangle the game 2, Settle for a draw 1. Pooled over 30 games each, the top three lost 15 and the bottom three lost 25. "No game plan" was not tested. The tester managed Oldham in the Premier League; venue and patch were not stated.
- **Contents [OFFICIAL, earlier versions]:** the presets are the old Match Plan templates. Each is a set of score-state and minute-range scenarios that change mentality and shape and decide substitutions, carried out by the assistant manager. SI staff pointed players to the "Create from Template" wizard rather than publishing the contents, and FM26 removed custom match plans. I could not recover the exact minute ranges or mentalities for any preset.
- **Action:** use the rule table below. Treat "avoid Settle, Strangle and Smash and grab when you are a big underdog" as the only medium-confidence row. Then run the save-and-reload test: about 30 instant results per plan to screen, and about 100 per plan to separate differences of half a point per game.

## Key Findings

| # | Finding | Label | Source and date |
|---|---|---|---|
| 1 | Against much stronger Arsenal, 10 games per plan, points were: Play for the draw 10 (W2 D4 L4), Play for the win 9, Leave it late 8 (W2 D2 L6), Go for a big win 7, Pressure cooker 6 (W1 D3 L6), Smash and grab 2 (W0 D2 L8), Strangle the game 2 (W0 D2 L8), Settle for a draw 1 (W0 D1 L9)\[1\] | [FM26-DATA] | FRVR, "Football Manager 26 Instant Results Ranked – why your Instant Results choices actually matter", by Lewis White, published 18 December 2025 |
| 2 | FRVR's own conclusion: "You get much better results when you 'Play for' something", and aggressive plans such as Pressure cooker and Go for a big win leave you "massively exposed at the back"\[1\] | [OPINION] (the author's reading of n=10 per plan) | FRVR, as above\[1\] |
| 3 | FRVR: "Sports Interactive haven't given any details about the mechanics behind the button"\[1\] | [OPINION] / absence of an official statement | FRVR, as above\[1\] |
| 4 | In FM26 the presets cannot be customised; custom match plans existed "last year" (FM24)\[2\] | [OPINION] (user reports, not contradicted) | SI forum "Match Plans Impact", topic 600478 (FM26 era) |
| 5 | Up to FM24, the plans were templates in Tactics > Match Plans > Create from Template, with scenarios by score state and minute (example from the FM24 manual: "Winning by 1+ goal" in "75-85 mins"), a defensive and attacking approach, a starting tactic, and performance-based substitution timing\[3\] | [OFFICIAL] [EARLIER-DATA: FM24 Touch/Console manual] | SI manual, FM24 Touch and Console, Tactics page (r4983)\[3\] |
| 6 | SI staff, FM18 Touch: "Do not use match plan" uses your tactics and team selection "for the duration of the match, with no changes. Except for injury subs"; with a plan, "subs are made"\[4\] | [OFFICIAL] [EARLIER-DATA: FM18 Touch] | SI admin Lucas, 4 Sep 2017, topic 407923\[4\] |
| 7 | FM23 Console bug: with a match plan, the assistant made no substitutions in instant result except for injuries; with no plan, it did.\[5\] SI said a fix was coming | [OFFICIAL] (bug acknowledged) [EARLIER-DATA: FM23 Console] | SI bug tracker r11747\[5\] |
| 8 | FM24 with an instant-result skin and no match plan, 30 Allsvenskan games: playing manually W18 D4 L8, 58 pts; instant result with a reload before each match W19 D5 L6, 62 pts; instant result for the whole season with delegation and Quick Pick W14 D3 L13, 45 pts\[6\] | [EARLIER-DATA: FM24] | Fuller FM, 18 Jul 2025 |
| 9 | Instant result in FM26 had bugs: it loaded the full match instead of simulating (SI reproduced this as caused by the spacebar with a legacy preference enabled); it froze in hotseat mode (fixed in 26.1.2, 19 Jan 2026); friendlies did not return to the portal (fixed in hotfix 26.0.4, 5 Nov 2025); random crashes were reported on 12 Dec 2025\[7\]\[8\]\[9\]\[10\] | [OFFICIAL] | SI bug tracker r37508, r43053; 26.1.2 and 26.0.4 patch notes |
| 10 | Players split on whether instant result beats managing yourself: final results from 2,633 votes, 22.3% "better", 21.6% "worse", 16.1% "about the same" (the label of the remaining 40% option was not shown in the retrieved snippet) | [OPINION] | Out of Context Football Manager (@nocontextfm1), X poll "Does the instant result button on FM26 give you...", replies dated 23–24 July 2026 |
| 11 | FM27 engine tool tests: defensive presets create about 1 xG less per game and still concede slightly more; "sitting deep didn't help even as an underdog"; "only Lock It Down has a clear effect everywhere: about −0.2 expected points a game, with fewer goals at both ends" (paired same-seed runs, counted as real at "t value of 3 or more"). Applied to FM26 this is inference only | [REASONED] (FM27 measurement, not FM26) | FM-Arena, caiograco, "FM27 match engine: what we know so far", Nov 2026 |
| 12 | FM27 user report: custom match plans are still disabled for instant result | [OPINION] | SI "Official FM27 Feedback Thread", topic 612416, Nov 2026\[11\] |

## What each plan contains

**Bottom line: nobody has published the FM26 contents.** What is known is the structure (from SI's FM24 Touch/Console manual and staff posts) and the names. The "Likely intent" column is inferred from the names and from user guesses on the SI forum. It is not game data.

| Plan | Game's own description (FM26) | Known structure [OFFICIAL, FM18–FM24 Touch/Console] | Likely intent from the name and user guesses [REASONED] / [OPINION] |
|---|---|---|---|
| No game plan | Not recovered | FM18 Touch, per SI: your tactic and team for the whole match, no changes, injury subs only. A user nevertheless saw 3 subs around 70', and staff suggested it reuses the default substitution instruction\[4\] | Neutral control arm; closest to "your tactic as set"\[4\] |
| Play for the win | Not recovered | Scenario-based template: score state × minute range → mentality/tactic; assistant-managed subs | Positive while level, protect when ahead |
| Play for the draw | Not recovered | Same | Cautious start, stays compact; one user asked how it differs from "Settle" and no answer was published\[12\] |
| Settle for a draw | Not recovered | Same | Accepts a draw. A user guessed it switches to protecting a draw once the game is level, even if the starting aim was to win\[12\] |
| Go for a big win | Not recovered | Same | Keeps attacking after taking a lead |
| Smash and grab | Not recovered | Same | A user guessed "Counter Attack?"; defensive base, hit on the break\[12\] |
| Leave it late | Not recovered | Same | A user guessed "Hold for a draw and then attack with about 10 mins left?"\[12\] |
| Pressure cooker | Not recovered | Same | Early high-intensity pressure (unconfirmed) |
| Strangle the game | Not recovered | Same | A user guessed "Keep possession?"; slows the game down, likely when ahead\[12\] |

FM24 manual wizard steps [OFFICIAL, FM24 Touch/Console]: choose a template ("when this Match Plan should come into effect"), choose a defensive approach, choose an attacking approach, save, choose the starting tactic, and decide "when, if at all, you want performance-based substitutions to be made."\[3\] The manual's example scenario is "Winning by 1+ goal" in "75-85 mins".\[3\] The FM21 Touch manual says that when you instant result, "you are presented with a set of Match Plans for your Assistant Manager to bring into play depending on any given match scenario."\[13\]

## Every test found

| Source | Version | Plans compared | Opponent strength | Venue | Sample size | Result |
|---|---|---|---|---|---|---|
| FRVR, "FM26 Instant Results Ranked" | FM26; patch not stated | 8 presets (not "No game plan") | Much stronger ("Pep Guardiola's Arsenal"); the tester's club was Oldham in the Premier League, "predicted to come 15th, but are flying high in 9th" | Not stated | 10 per plan, 80 total | Points (Arsenal's points in brackets): Play for the draw 10 (16), W2 D4 L4, GF 16 GA 20; Play for the win 9 (18), W2 D3 L5 by arithmetic; Leave it late 8 (20), W2 D2 L6, GF 8 GA 19; Go for a big win 7 (22), W2 D1 L7 by arithmetic; Pressure cooker 6 (21), W1 D3 L6, GF 9 GA 18; Smash and grab 2 (26), W0 D2 L8, GF 10 GA 24; Strangle the game 2 (26), W0 D2 L8, GF 8 GA 28; Settle for a draw 1 (28), W0 D1 L9, GF 6 GA 22\[1\] |
| Fuller FM, "The Instant Result Button: Click Here To Win?" (18 Jul 2025) | FM24 with the Wannachup instant-result skin | No plan used; manual play vs instant result per match (with reload) vs instant result for the whole season | Mixed league schedule (Nacka; media prediction 5th) | Home and away mixed | 30 league games per arm | Manual: W18 D4 L8, 53–28, 58 pts. Instant per match: W19 D5 L6, 63–30, 62 pts. Instant whole season (delegated, Quick Pick): W14 D3 L13, 58–49, 45 pts\[6\] |
| FM-Arena caiograco Match Lab | FM27 (27.0.1 era), engine run outside the game | Not game plans. Tactics presets, tweaks, assistant vs AI in-match management | Synthetic mid-table squads; Arsenal, Hull, Altrincham seasons | Both | Thousands of paired-seed matches | Assistant beats AI in-match management by 0.56 points per game; Park the Bus 0.92 PPG vs Gegenpress 1.39; Lock It Down about −0.2 xPts per game; home 1.54 vs away 1.18 points with identical sides\[14\] |

The FRVR W/D/L for "Play for the win" and "Go for a big win" come from solving the article's two point totals together (e.g. 9 for, 18 against, over 10 games, gives W2 D3 L5). The game-by-game lists for those two plans were not in the text I could retrieve. One FRVR search snippet shows "Total – 2 points (Arsenal 26 points)" next to a truncated "Play for the draw" list. That total matches the Smash and grab and Strangle the game totals (2 points, Arsenal 26), not Play for the draw, whose complete list adds up to 10 points. The full FRVR page fetch failed, so I could not check this beyond the snippet.

## Question 1: What each plan contains

- **Found:** the structure and the official way to read the templates in FM18–FM24 Touch/Console. SI admin Lucas (4 Dec 2018): "you can view what each of these do by going through the Wizard and choosing the appropriate template."\[15\] On FM14, an fm-base user posted a screenshot of the template descriptions, but its text is not readable on the page.\[16\]
- **Not found:** the FM26 dialog descriptions for the nine plans, any game-file extraction, and any screenshot transcription giving the minute ranges and mentalities. FM26 removed custom match plans, so the old wizard route no longer exists in FM26 [OPINION, user reports in topic 600478].\[2\]
- **Searched:** FRVR, SI forums (FM Console/Touch General, Tactics, General Discussion, bug tracker), the SI manual (FM21 and FM24 Touch/Console), fm-base, FM Scout, sortitoutsi, FM-Arena, Steam Workshop comments. The subagent also searched Reddit, YouTube guides and Steam guides and found no transcription.
- **Could not open:** SI forum topics 258137 and 600478 and the FM24 manual page (bot-blocked, so I used snippets); the FRVR full page (fetch error, so I used snippets); the fm-base attachment 380364 (image).

## Question 2: Which plan wins

- **Much stronger opponent, venue unknown, competition unknown [FM26-DATA]:** the only measurement is FRVR's. Its useful signal is the gap between clusters, not the ranking. Pooled, Play for the draw, Play for the win and Leave it late took 27 points from 30 games (0.90 per game) with 15 losses. Settle for a draw, Strangle the game and Smash and grab took 5 points from 30 (0.17 per game) with 25 losses. That gap is large enough to be unlikely to be chance even at this sample size, but I grouped the plans after seeing the results, so treat it as a strong hint rather than proof. The order inside the top cluster (10 vs 9 vs 8 points) is noise at n=10.
- **Stronger, similar, weaker, much weaker; home vs away; league vs single-leg vs two-legged; must-win vs protecting a lead:** no FM26 measurement found in the places searched.
- **No game plan and holiday vs instant result [EARLIER-DATA: FM24]:** Fuller FM found that instant result per match, without a plan, did slightly better than manual play (62 vs 58 points). Holiday-style delegation across the season did much worse (45 points), which the author put down to morale and the assistant's Quick Pick overplaying the same starters.\[6\] No test compares "No game plan" with any preset in any version.
- **FM26 opinion [OPINION]:** an SI forum user reported getting "consistently much better" results from instant result than from watching (topic 612198).\[17\] Another user called "Strangle the game" "ridiculously over-powered" (topic 594998).\[18\] That conflicts with FRVR, where Strangle earned 2 of 30 points as an underdog. FRVR is the better-supported of the two because it reports 10 recorded results against an anecdote, but the two may not even conflict: the forum user may have been the favourite, where a plan that protects a lead could help.
- **Earlier-version opinion [OPINION, FM14 PC with a skin]:** an fm-base user used "Go for the win" against equal or weaker teams and "Smash and Grab" or "Leave it late" against better teams. Another said Smash and grab "worked for me the few times I've done it."\[16\]

## Question 3: What can be reasoned from the contents

All of this is [REASONED]. None of it is FM26 measurement.

- **Defensive drift hurts.** In FM27's engine, defensive presets create about 1 xG less per game and still concede slightly more. caiograco's FM-Arena thread reports that "only Lock It Down has a clear effect everywhere: about −0.2 expected points a game, with fewer goals at both ends", from paired same-seed engine runs. If "Settle for a draw" and "Strangle the game" switch to defensive or time-wasting setups, as their names suggest, they should underperform as an underdog. That matches FRVR's FM26 numbers (1 and 2 points; Strangle conceded 28 in 10).\[1\]
- **When protecting a lead as the favourite**, the same evidence suggests that dropping deep gives back xG. That argues against switching to "Strangle" or "Settle" even when ahead, unless measurement shows otherwise.
- **Must-win knockout or second leg**: "Leave it late" and "Go for a big win" increase attacking late or keep attacking. FRVR shows neither collapsed as an underdog (8 and 7 points), so they are acceptable when only a win will do.\[1\]
- **Assistant control has value.** In FM27, the assistant managing in-match beat the AI manager by 0.56 points per game in caiograco's tool.\[14\] That is consistent with instant result (assistant-managed) being competitive with manual play, as Fuller FM found in FM24.

## Question 4: Side effects

- **Substitutions:** [OFFICIAL, FM18 Touch] plans make subs; "No game plan" makes injury subs only, according to staff, though a user saw 3 subs around 70'.\[4\] [OFFICIAL, FM23 Console] a bug stopped subs being made under match plans.\[4\]\[5\] [EARLIER-DATA/OPINION, FM24 skin] pressing instant result mid-match means "they won't make ANY subs at all" (Fuller FM).\[6\] The FM26 sub behaviour per plan was not measured anywhere I searched.
- **Bench minutes, condition, sharpness:** in FM24, the season-long instant result with Quick Pick "knackered our regular starting XI and left everyone else short of match fitness" [EARLIER-DATA: FM24].\[6\] In FM27's engine, 75% vs 100% match sharpness costs 0.37 points per game and 90% vs 100% condition costs 0.28 [REASONED from FM27].\[14\] Rotation therefore matters more than which plan you pick.
- **Morale, cards, injuries, ratings:** no plan-level data found. In FM27's engine, morale at kick-off had no measurable in-match effect.\[14\]

## Question 5: How instant result works in FM26

- **Engine:** no SI statement found for FM26. [OPINION/blog, FM24] Fuller FM states your matches always use the Full Match Engine, whether played, holidayed or instant-resulted.\[6\] In FM27, caiograco's tool runs the native engine with assistant in-match management, which he likens to instant result.\[14\]
- **Who picks the eleven:** a Steam user says that choosing instant result before kick-off hands team selection to the assistant [OPINION, unconfirmed].\[19\] Fuller FM (FM24) says the assistant sticks to your tactic more rigidly than on holiday, and you keep the credit for the result.\[6\]\[20\]
- **Familiarity when a plan switches shape:** not documented. In FM27's engine, familiarity from low (20) to high (80) is worth +0.52 points per game, and most of the gain is in place by around 50 [REASONED from FM27].\[14\] A plan that switches to an untrained shape could cost points, but this is unmeasured.
- **Known bugs:** instant result loading the full match (beta reports r36991 and r37459; reproduced by SI in r37508 as the spacebar plus a legacy preference); result not shown afterwards (r37525); crashes (r43053, 12 Dec 2025); hotseat freeze (fixed in 26.1.2); friendlies (fixed in 26.0.4).\[7\]\[8\]\[9\]\[10\]\[21\]\[22\]\[23\] Instant result is reportedly unavailable for matches between two clubs you both manage [OPINION].\[24\] A Mobile forum user said FM26 Mobile had no instant-result button [OPINION].\[25\]

## Question 6: What changed

- **FM26 patches:** hotfix 26.0.4 (Steam beta, 5 Nov 2025) fixed instant result for friendlies; 26.1.2 (19 Jan 2026) fixed the hotseat freeze.\[9\]\[10\] 26.1.0, 26.2, 26.3 and 26.3.1 (international management, May 2026) list no change to the plans.\[26\] No patch note I found touched the plans' contents [OFFICIAL].
- **FM27:** a user in the official feedback thread complains that custom match plans for instant results are still disabled, "last it was in FM24" [OPINION].\[11\] I found no SI feature text on game plans.

## Rule the tool can compute

| Competition | Opponent vs you | Venue | At stake | Use | Avoid | Evidence | Confidence |
|---|---|---|---|---|---|---|---|
| Any | Much stronger | Any | Any | Play for the draw or Play for the win (no measured difference; Leave it late similar) | Settle for a draw, Strangle the game, Smash and grab | [FM26-DATA] FRVR | Medium for "avoid"; low for choosing among the top three |
| Any | Stronger | Any | Any | Play for the win or Play for the draw | Settle for a draw, Strangle the game | [REASONED] extrapolated from FRVR + FM27 defensive data | Low |
| League | Similar | Home or away | Nothing special | Play for the win or No game plan (not separated) | Settle for a draw | [REASONED] | Low |
| League | Weaker / much weaker | Any | Any | Play for the win or No game plan (not separated); Go for a big win only if goal difference matters | Settle for a draw, Strangle the game (defensive drift costs xG) | [REASONED] (FM27 Lock It Down and defensive presets) | Low |
| Single-leg knockout | Any | Any | Must win | Play for the win; Leave it late if a much stronger opponent | Settle for a draw | [FM26-DATA] for much stronger; else [REASONED] | Low–medium |
| Two-legged, second leg | Any | Any | A draw is enough | Play for the draw (best FM26 measured result as underdog) | Settle for a draw (worst measured) | [FM26-DATA] only for much stronger | Low–medium |
| Two-legged, second leg | Any | Any | Must win / chasing | Go for a big win or Leave it late (no measured difference) | Settle for a draw, Strangle the game | [REASONED] | Low |
| Any | Weaker | Any | Protecting a lead (e.g. aggregate) | Play for the win; evidence does not support switching to Strangle | Settle for a draw | [REASONED] + one [OPINION] that Strangle is strong | Low; sources disagree |
| Any | Any | Any | Fatigue or rotation concern | Any plan, but rotate the XI manually first | Season-long delegation with Quick Pick | [EARLIER-DATA: FM24] + [REASONED from FM27 sharpness/condition] | Medium |

## What carries over to FM27 and what may not

- **Likely carries over:** the preset-only design (a user reports custom plans are still disabled in FM27), the assistant carrying out plans, and the general engine finding that defensive set-ups give away xG.\[11\]
- **May not carry over:** FRVR's exact point totals, because the match engine, the assistant logic and possibly the preset contents have changed. FM27's Tactical Effectiveness/familiarity model is new, so plans that switch shape may cost differently.\[14\]\[27\] Re-run the test below on FM27.

## Evidence gaps and a test I can run

The biggest unknown is whether any preset beats "No game plan" when you are the favourite, the situation you will simulate most often.

**Cheapest test:**
1. Save just before a league match where you are clearly stronger (and ideally a second save where you are similar).
2. From the same save, instant result with "No game plan", "Play for the win", "Play for the draw" and "Settle for a draw". Reload after each result.
3. Record W/D/L, goals, xG for and against, and the substitution minutes from the match report.

**Repeats needed:**
- Screening: 30 per plan (120 reloads). Enough to see gaps around 0.9 points per game, the size of FRVR's top-vs-bottom gap.
- Confirmation: 100 per plan for the two best plans and "No game plan". Enough to detect about 0.5 points per game at conventional significance, assuming a per-match standard deviation of points of about 1.3.
- Use xG difference as your main measure, because it is less noisy than points.
- Repeat once as the underdog to check FRVR. Repeat once as an away second leg where a draw is enough.

## Where I searched

- **FRVR article:** found through search snippets. The full fetch failed twice (client error, then internal error).
- **SI community forums:** FM Console/Touch General (topics 460669, 264237, 407923, 306272), Tactics (258137, 612198), General Discussion (600478, 612678, 594998 via the subagent, FM27 feedback thread 612416), Knap thread (451185), FM26 bug tracker (r36991, r37459, r37508, r37525, r43053), FM23 Console bug tracker (r11747), FM24 Touch/Console manual (r4983), FM21 Touch manual. Many pages were bot-blocked, so I used snippets.
- **Patch notes:** fm-base, FM Scout (26.1.2), footballmanagerblog.org (all hotfixes), Steam (26.0.4), Operation Sports, the Chinese SI forum (26.1.0).
- **fm-base:** "FMC Instant Result" and "Instant result button" threads, and "Instant Result settings" (FM14; fetched).
- **FM Scout:** Wannachup FM17 and FM18 skin pages.
- **sortitoutsi:** FM15 instant-result thread; "Match plan screen?"
- **FM-Arena:** match plans thread 8906; FM24 match plan bug thread; FM27 Match Lab threads (fetched).
- **Fuller FM** (fetched). **X** poll by @nocontextfm1. **Steam:** Workshop instant-result skin comments.
- **Chinese:** a search for 足球经理26 即时结果 比赛计划 returned only store pages and patch notes.
- **Turkish:** a search for "anında sonuç" maç planı returned only patch-note translations.
- **Not searched, because the search budget ran out:** German (the query failed), Korean, Polish, Spanish, Portuguese, Italian, French, Bilibili, Tieba, playgm.cc, YouTube and Twitch directly, Dictate The Game, The Higher Tempo Press (it only appeared for an unrelated "Pressure Cooker" tactic), Reddit directly (only reached through the subagent).
- **Consequence:** I cannot say these plans are untested in those communities. I can only say no test surfaced in the places listed.

## Caveats

- FRVR's test is one save, against one opponent, with 10 matches per plan, and no venue or patch given. Only the top-vs-bottom gap is meaningful.
- All preset-content descriptions are inferred. None is extracted from FM26.
- The FM27 tool results come from a community tool running the engine outside the game, and its author flags open issues.\[14\] I use them as reasoning, not as FM26 evidence.
- Several forum claims are anecdotes, and some conflict (Strangle "over-powered" vs FRVR's 2 points).
- The subagent found no SI staff explanation of FM26 game plans.

## Sources

Each source's link and date are given in the Key Findings table and the "Where I searched" log above:
- FRVR: frvr.com/blog/news/football-manager-26-instant-results-ranked-why-your-instant-results-choices-actually-matter/
- Fuller FM: fullerfm.com/2025/07/18/the-instant-result-button-click-here-to-win/
- FM-Arena: fm-arena.com/threads/fm27-match-engine-what-we-know-so-far.122/
- SI forums: community.sports-interactive.com topics 407923, 460669, 600478, 612198, 612416; bug tracker r37508, r43053, r11747; FM24 Touch/Console manual r4983
- fm-base: fm-base.co.uk/threads/instant-result-settings.134118/
- FM Scout: fmscout.com/a-fm26-update-26.1.2.html
- Steam: steamcommunity.com/app/3551340/discussions/0/670600125430806666/
- X: x.com/nocontextfm1/status/2080283539849769473

## Sources

1. [Football Manager 26 Instant Results Ranked - why your Instant Results choices actually matter - FRVR](https://frvr.com/blog/news/football-manager-26-instant-results-ranked-why-your-instant-results-choices-actually-matter/)
2. [Match Plans Impact - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/600478-match-plans-impact/)
3. [Tactics - Football Manager 2024 Touch and Console Edition - Sports Interactive Community](https://community.sports-interactive.com/sigames-manual/football-manager-2024-touch-and-console/tactics-r4983/)
4. [Match plan and instant results - FM Console and FM Touch General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/407923-match-plan-and-instant-results/)
5. [Instant result (simulate the game) - Assistant never does any subs - Gameplay Issues - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/previous-versions/football-manager-2023-console-edition-bugs-tracker/920_gameplay-issues/instant-result-simulate-the-game-assistant-never-does-any-subs-r11747/)
6. [The Instant Result Button: Click Here To Win?](https://fullerfm.com/2025/07/18/the-instant-result-button-click-here-to-win/)
7. [FULL GAME CRASH UPON USING INSTANT RESULT - Crash & Technical Issues - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/1873_crash-technical-issues/full-game-crash-upon-using-instant-result-r43053/)
8. [Instant Result takes you into the game does not simulate result - All Other Issues - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/all-other-issues/instant-result-takes-you-into-the-game-does-not-simulate-result-r37508/)
9. [Hotfix 26.0.4.2230011 (Patch notes from website) :: Football Manager 26 General Discussions](https://steamcommunity.com/app/3551340/discussions/0/670600125430806666/)
10. [Football Manager 2026 Patch 26.1.2 - Hotfix Update for FM26](https://www.fmscout.com/a-fm26-update-26.1.2.html)
11. [The Official FM27 Feedback Thread - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612416-the-official-fm27-feedback-thread/)
12. [Match Plans - Tactics, Training & Strategies Discussion - Sports Interactive Community](https://community.sigames.com/topic/258137-match-plans)
13. [Tactics - Football Manager 2021 Touch - Sports Interactive Community](https://community.sports-interactive.com/sigames-manual/football-manager-2021-touch/tactics-r4392/)
14. [FM27 match engine: what we know so far](https://fm-arena.com/threads/fm27-match-engine-what-we-know-so-far.122/)
15. <https://community.sports-interactive.com/forums/topic/460669-match-plans-in-the-simulate-match-menu/>
16. [Instant Result settings](https://fm-base.co.uk/threads/instant-result-settings.134118/)
17. [Why do I get much worse results when watching matches compared to using Instant Result in FM26? - Tactics, Training & Strategies Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612198-why-do-i-get-much-worse-results-when-watching-matches-compared-to-using-instant-result-in-fm26/)
18. [Things you're liking on FM26 - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/594998-things-youre-liking-on-fm26/)
19. [Instant result uses different players to the ones chosen. :: Football Manager 26 General Discussions](https://steamcommunity.com/app/3551340/discussions/0/603044859897820826/)
20. [Steam Workshop::Instant Result Button](https://steamcommunity.com/sharedfiles/filedetails/?id=3075962558)
21. [Instant Result outcome - All Other Issues - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/all-other-issues/instant-result-outcome-r37525)
22. [Instant Result option opens full match instead of showing result screen - Matchday Experience UI Issues](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/user-interface/2166_advanced-access-betas-ui-issues/2081_matchday-experience-ui-issues/instant-result-option-opens-full-match-instead-of-showing-result-screen-r36991/)
23. [‘Instant Result’ option starts full match instead of showing result - Advanced Access Beta's Crash & Technical Issues](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/1873_crash-technical-issues/2180_advanced-access-betas-crash-technical-issues/instant-result-option-starts-full-match-instead-of-showing-result-r37459/)
24. [The Official FM27 Feedback Thread - Page 27 - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612416-the-official-fm27-feedback-thread/page/27/)
25. [FM26 early thoughts - Football Manager Mobile General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/597736-fm26-early-thoughts/)
26. [Football Manager 26](https://en.wikipedia.org/wiki/Football_Manager_26)
27. [Load FM Writes](https://loadfm.wordpress.com/)
