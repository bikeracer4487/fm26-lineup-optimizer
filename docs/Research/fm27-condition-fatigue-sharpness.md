# FM27 Physical-Readiness Mechanics: Validation of the Lineup-Optimizer Rules

The core structure of your optimizer still holds in FM27: condition, match sharpness and jadedness are still the three readiness variables, and the internal scales are unchanged (condition and sharpness 0–10,000, jadedness about −500 to +1,000 with "Jaded" shown above 400). But early FM27 engine tests show that condition and sharpness cost far more than your current penalty curves assume. Only one of your five rule sets, the jadedness threshold of about 400, has direct FM27 confirmation. The age modifiers, positional multipliers and consecutive-start limits have no FM27 evidence at all.

## TL;DR
- **Confirmed for FM27:** the internal scales and the "Jaded" threshold above 400 on a −500 to 1,000 jadedness scale (FM27 editor data, Nov 2026). Sharpness is built by match minutes, about 10 internal points (0.1%) per minute played, and decays by 0.5% per day without training except the day after a match (ZaZ's FM27 tests on fm-arena, 10 Nov 2026).
- **Changed, or at least much steeper than assumed:** in an FM27 engine-replay study, starting at 80% condition cost 0.8 points per game, 75% sharpness cost about 0.37 ppg and 50% sharpness cost a full point per game (fm-arena, about 12 Nov 2026). SI officially says Stamina now has a stronger effect on in-match condition loss. Your "75–85% = medium" sharpness band and "small penalty below 90%" condition rule are too lenient.
- **Unknown in FM27:** the 85% injury-risk cliff, the 250 "accumulating" level, the age and attribute modifiers, the 1.2x/0.8x positional multipliers, the consecutive-start limits, per-day recovery rates, and any change to subs or bench sizes. No FM27 evidence was found for any of these. Treat them as FM26 carry-over (label c) until someone tests them.

## Key Findings: Summary Table

Evidence labels: (a) official SI material; (b) FM27 community testing with data; (c) FM26 knowledge assumed to carry over; (d) speculation.

| Assumption | FM26 rule | FM27 status | FM27 value if known | Evidence label | Source (URL, date) |
|---|---|---|---|---|---|
| Condition thresholds | Never start below 85%; small penalties below 90%; severe below 75% and 60% | **Changed (penalty steeper); injury threshold unknown** | 80% condition costs 0.8 ppg vs 100% in engine replays. No FM27 data for 85%/90%. Stamina officially has more effect on in-match condition loss.\[1\] | (b) for the penalty, (a) for the Stamina change, (c) for the 85% injury cliff | https://fm-arena.com/threads/fm27-match-lab-macos-tool-to-simulate-matches-outside-the-game.96/ (about 12 Nov 2026); https://community.sports-interactive.com/featured/ (SI match engine deep dive, 5 Oct 2026) |
| Fatigue/jadedness thresholds incl. age modifiers | About 400 = jaded; about 250 = accumulating; 32+ about 300; 30–32 or U19 about 350; shifts with NF/Stamina/Injury Proneness | **400 confirmed; everything else unknown** | Scale −500 to 1,000 (editor limits). "Jaded" label shown above 400.\[2\] Observed live range −500 to about 643.\[3\] Rest returns players to −500.\[4\]\[5\] | (b) | https://github.com/IamDejman/fm-lens/pull/138 (7 Nov 2026); https://github.com/tozmoz/FMLibreEditor/pull/48 (1 Nov 2026) |
| Positional load multipliers | FB/WB and DM about 1.2x; CB and GK about 0.8x | **Unknown** | No FM27 multiplier data. SI says wing-backs making long runs show visible exertion, which fits the high-load direction but gives no number.\[6\]\[7\] | (a) qualitative only; (c) for the values | https://sortitoutsi.net/content/77885/fm27-match-engine-and-tactical-tweaks (Oct 2026, summarising SI's deep dive) |
| Consecutive-start rotation limits | WB/DM 2–3; attackers 3–4; CB/GK 5–6 | **Unknown** | No FM27 data found | (c) | None for FM27 |
| Sharpness bands | <75% low; 75–85% medium; >85% high | **Changed (bands too lenient); exact bands unknown** | 75% sharpness costs about 0.37 ppg and 50% about 1.0 ppg.\[8\] Gain is about 10 internal points per minute played (about 9% per 90). Loss is about 0.5% per day without training.\[9\] | (b) | fm-arena Match Lab thread (about 12 Nov 2026); https://fm-arena.com/threads/training-schedules.60/ (10 Nov 2026) |

## Details

### 1. How condition, fatigue/jadedness, sharpness and injury risk work in FM27

**Platform context.** FM27 is a full annual release (launched 10 November 2026).\[10\]\[11\] It is not a data update. It builds on the Unity-engine overhaul that started with FM26:\[12\] FM27 on PC, Mac and console is "Made with Unity", while FM27 Mobile is not developed in Unity (a; https://www.footballmanager.com/fm27, Nov 2026; https://www.dlcompare.com/gaming-news/football-manager-27-release-date-platforms-editions-87666, Nov 2026).\[11\]\[13\] The day-one 27.0.1 patch did not change fitness. Its only related change was that you can no longer cancel a forced injury substitution, which used to leave you with ten players (a, via FM Scout's reproduction of SI's notes; https://www.fmscout.com/a-fm27-update-27.0.1.html, 10 Nov 2026).\[14\]

**Condition.**
- *Internal scale:* still 0–10,000. An FM27 live editor's change log records values such as "condition 9679 → 10000" and "condition 7700 → 10000" for named players (b; https://github.com/IamDejman/fm-lens/issues/110, Nov 2026, undated issue).\[4\]
- *What changed (official):* SI says Stamina now has a greater effect on covering ground and repeated sprints. Stamina is also "a stronger factor on how your player's condition deteriorates over the course of 90 minutes", so low-stamina players may struggle late in games and substitutes have more effect (a; SI match engine deep dive as reproduced on https://community.sports-interactive.com/featured/, 5 Oct 2026).\[1\] SI also says HawkEye data was used to rebuild movement and that "physical condition should have a more noticeable effect as matches progress" (a, via https://sortitoutsi.net/content/77885/fm27-match-engine-and-tactical-tweaks, Oct 2026).\[7\]
- *Measured effect:* an FM27 engine-replay study ran about 190,000 simulated matches on builds 27.0.0/27.0.1. It found that starting players at 80% condition cost 0.8 points per game, and called condition "one of the biggest effects the tests have measured".\[8\] The method was ten real matches from one newly promoted Premier League side, each replayed 200–300 times on fixed seeds (b; https://fm-arena.com/threads/fm27-match-lab-macos-tool-to-simulate-matches-outside-the-game.96/, about 12 Nov 2026).\[8\] Caveat: the author says the results come from "one club, mostly losing to better teams" and that the summaries were written with AI help, but he also says "The big ones (fitness, positions, AI manager) aren't going anywhere." No 85%, 90% or 95% figures were found because the detailed tables are in a GitHub repo I could not access.
- *Display:* the default FM27 skin appears to show condition as icons rather than percentages. Third-party FM27 skins advertise adding percentages back, for example CalmDark: "Condition and sharpness always read in the lists (no more falling back to FM's icons)" (b, inference from skin notes; https://www.fmscout.com/a-calmdark-fm27-skin.html, Nov 2026).\[15\] Users of the TangFu FM27 skin ask for "percentage condition" on more screens (https://www.fmscout.com/a-tangfu-fm27-skin.html, Nov 2026).\[16\] A "Physical Condition" squad-view column exists in FM27 (https://fmportugal.net/en/yoshialfie-skin-fm27/, Nov 2026).\[17\] SI removed exact percentages from the default skin several editions ago (c; SI forum discussion, https://community.sports-interactive.com/forums/topic/581072-player-fitness-condition-fm-is-unplayable/, undated).\[18\] **For your tool, read the raw 0–10,000 value from an editor rather than the in-game icon.**

**Fatigue/jadedness.**
- *Internal scale:* in FM27 jadedness is a signed 16-bit field stored between match sharpness and energy. Across a 59,301-player save it ranged from −500 to 252 early in the season, and 1,587 summer-rested players sat at exactly −500, "the least the game keeps". Editors accept −500 to 1,000 (b; https://github.com/tozmoz/FMLibreEditor/pull/48, 1 Nov 2026).\[5\] A Mac save showed −500 to 643 (b; FMLibreEditor PR #60, Nov 2026, search snippet only).\[3\]
- *Threshold:* the FM Lens FM27 editor labels a player "Jaded" above 400, "as FM does". In an Arsenal save dated 11 Dec 2027, Saka (404), Rice and Kvaratskhelia were all shown as "Jaded" (b; https://github.com/IamDejman/fm-lens/pull/138, 7 Nov 2026).\[2\] This matches your 400 threshold.
- *How it acts:* one FM27 engine tester found a per-player "fatigue" field in code that the engine overwrites during match preparation and that has no in-match effect. What the engine reads at kick-off is condition and match sharpness.\[8\] His view that jadedness works through recovery between matches and through injury risk is, in his words, "a guess, not something I've measured" (d; Match Lab thread, about 13 Nov 2026).\[8\] This fits the FM26 understanding that high jadedness reduces how much condition recovers (c; https://fm-arena.com/thread/16275-conditions-management-one-of-the-core-fm26-mechanics/, Dec 2025).\[19\]\[20\]
- *Not found for FM27:* the 250 "accumulating" level, the age-based thresholds (300 for 32+, 350 for 30–32 or under 19), and the Natural Fitness, Stamina and Injury Proneness modifiers. FMRTE 27 shipped on 30 Oct and was updated on 10 Nov 2026. Another free FM27 editor says condition, sharpness and jadedness are "stored differently" in FM27 and are read-only for now (b; https://sortitoutsi.net/content/78059/fm27eur0-v100-live-editor-for-fm27, Nov 2026).\[22\]

**Match sharpness.**
- *Internal scale:* 0–10,000. For example, "match_sharpness 8200 → 10000" in the FM Lens log (b; fm-lens issue #110).\[4\] One FM27 editor observed that sharpness never fell below about 35%: on 10 Jan 2027, 495 players sat at exactly 35% (b; FMLibreEditor PR #88, about 4 Nov 2026, search snippet only).\[23\]
- *Performance cost:* starting XI at 50% sharpness cost about 1 full point per game, and at 75% about 0.37 ppg (b; Match Lab thread, about 12 Nov 2026).\[8\] This alone shows that 75% is not a "medium, acceptable" level in FM27.

**Injury risk.**
- FM27 desktop has no published injury-model change apart from presentation. Fitness test messages now show all tests in one table, and there is a new concussion protocol: concussed players need neurologist clearance, and progress is tracked in the Medical Centre (a; https://www.footballmanager.com/fm27/features/fm27-2d-match-engine-game-editor-and-deeper-world-upgrades, Oct 2026).\[24\]
- Training now shows "how each session impacts player fatigue and injury risk" (a/secondary; https://realsport101.com/article/football-manager-27-overhauls-training-new-ui-tactical-effectiveness-complexity, Oct 2026).\[25\] SI's Training page says the interface has "greater visual cues about player load in the weeks ahead" (a; https://www.footballmanager.com/fm27/features/fm27-training-and-tactical-effectiveness, Oct 2026).\[26\]
- A per-player Physio Report covering condition, assessment, advice and recommendations, built from injury history, fitness, fatigue and match load, is officially documented **only for FM27 Mobile** (a; https://www.footballmanager.com/fm27/features/fm27-mobile-more-influence-your-fingertips, Oct 2026).\[1\]\[27\] Do not assume the desktop version has it.
- ZaZ's claim on fm-arena that injuries "are only rolled in days with training" is an untested assertion (d/b; https://fm-arena.com/threads/training-schedules.60/, 10 Nov 2026).

### 2. Assumption-by-assumption verdict
1. **Condition: changed (steeper), injury cliff unknown.** 80% costs 0.8 ppg (b). The "never below 85%" rule is safe to keep, but the "small penalty below 90%" part almost certainly understates the cost. No FM27 data shows whether injury risk rises sharply at 85% (c).
2. **Jadedness: 400 confirmed (b).** The 250 level, the age modifiers and the attribute shifts are all unknown (c).
3. **Positional load multipliers: unknown (c).** SI's wing-back exertion description is consistent with the direction of your multipliers, but gives no magnitude (a, qualitative).
4. **Consecutive-start limits: unknown (c).** No FM27 evidence.
5. **Sharpness bands: changed.** 75% costs about 0.37 ppg, so the 75–85% "medium" band should be treated as clearly penalised.\[8\] That gain comes from minutes and decays without them is confirmed (b).\[9\]

### 3. Recovery between matches
- **No FM27 per-day condition recovery data was found.** The best baseline is FM26: one full rest day takes condition from 7,000 to 8,240, from 8,000 to 8,813, and from 9,000 to 9,275 (at 0 jadedness and 10,000 sharpness). A player gains about 50–70 jadedness per match, and one full rest day removes about 20, so it takes about three rest days to clear one match (c; https://fm-arena.com/thread/16275-conditions-management-one-of-the-core-fm26-mechanics/, Dec 2025).\[19\]
- In an FM26 loop of three matches in about a week, jadedness kept climbing towards +500 and pre-match condition settled around 8,900 (c; https://fm-arena.com/thread/16417-part-2-conditions-management-one-of-the-core-fm26-mechanics/, Dec 2025).\[28\] The FM26 "1-day rest" exploit restored a large amount of condition (c; https://fm-arena.com/thread/16424-rest-exploit-fm26/, Dec 2025).\[29\] Nobody has re-tested it in FM27.
- FM27-specific: one tester says FM27 training intensity is "much lower" than FM26, so training at about 80% condition carries little injury risk (b, opinion; ZaZ, https://fm-arena.com/threads/training-schedules.60/, 12 Nov 2026).\[9\] Another found that Normal or Double intensity lowered match-day condition with no clear gain, and recommends Half intensity (b, no figures published; Match Lab thread, about 12 Nov 2026).\[8\] Days without training cost about 0.5% sharpness, except the day after a match (b; ZaZ, 10 Nov 2026).\[30\]
- **Two matches in 3–4 days:** no FM27 data. Use the FM26 numbers above. A starter recovering from about 7,000 over 2–3 days with jadedness above 0 will usually start the second match below 90% (c).

### 4. Sharpness gain and loss
- Gain: about 10 internal points per minute played, possibly in steps of 50 per 5 minutes. A player subbed off gained 800, and the same player playing the full match gained 900 (b; ZaZ, https://fm-arena.com/threads/training-schedules.60/, 10 Nov 2026).\[9\] That is about 9% per 90 minutes, which matches FM26 community data of about 9% per 90 at 50–65% sharpness falling to about 2% at 90% (c; https://fm-arena.com/thread/15972-how-to-optimize-player-fitness-and-why-it-s-crucial/). \[31\] Whether FM27 gains slow at high sharpness has not been tested.
- Loss: about 0.5% per day without training. A light-conditioning session keeps about 0.5% per week (b; ZaZ, 10–12 Nov 2026).\[9\]
- Friendlies, reserve/U21/B-team matches and substitute appearances: **no FM27 data.** FM26 and earlier evidence says friendlies give smaller gains than competitive matches (c).\[32\] Treat substitute minutes with the per-minute rate above (b).
- Performance cost: 50% sharpness about −1.0 ppg; 75% about −0.37 ppg (b).\[8\]

### 5. Substitutions, bench, sports science and injury modelling
- **Substitutions and bench size:** no official FM27 change was found. FM27 mods that raise benches to 12 and allow 5 subs exist, which suggests the defaults still follow each competition's real rules (b, inference; https://fmscout.com/a-european-regulations-and-squad-freedom-megapack-fm27.html, Nov 2026).\[33\] Real Premier League rule: 5 subs from a 9-man bench in 3 windows plus half-time (https://englishpremierleague.watch/guides/five-substitutions-rule/). \[34\]
- **Sports science / Medical Centre:** official FM27 changes are the concussion protocol, combined fitness-test messages, training-load visual cues and session-level fatigue and injury-risk information (a).\[26\]\[35\] The Physio Report is Mobile-only (a).\[1\]\[27\]
- **Engine:** Stamina has a stronger effect on in-match condition decay (a).\[36\] This makes late substitutions and rotation more valuable, especially in high-intensity tactics.\[37\]
- **Tactical Effectiveness:** this is the headline new system.\[38\] It builds on the old Tactical Familiarity and has four parts: Tactical Understanding, Player Ability, Player Buy-In and Next Match Information (a; SI Training page, Oct 2026).\[26\] In the Match Lab study, an untrained Tactical Understanding cost about 0.4 ppg, well trained (about 75 per area) gained about 0.2 ppg, and going from low to high in every area was worth about +0.5 ppg (b; caiograco, fm-arena Match Lab thread, 12 Nov 2026). So rotation now carries a cohesion and understanding cost that your tool does not model.

## Recommendations
1. **Keep** the 0–10,000 condition and sharpness scales and the jadedness scale (−500 to 1,000). **Keep** 400 as the hard "jaded, must rest" line.
2. **Steepen the condition penalty.** Make 80% roughly as costly as moving a starter out of position (0.8 ppg vs 0.85 ppg in the FM27 study). Keep 85% as a hard floor for starts, and treat 85–90% as a meaningful penalty rather than a small one.
3. **Re-band sharpness:** <75% = severe, 75–90% = clearly penalised, ≥90% = full. Exact bands are unverified; 75% → −0.37 ppg and 50% → −1.0 ppg are the only FM27 data points. Model gain as about 0.1% per minute played and decay as about 0.5% per non-training day.
4. **Weight stamina more heavily** in projected end-of-match condition, and favour planned substitutions for low-stamina starters (official FM27 change).
5. **Keep the positional multipliers, consecutive-start limits, the 250 level and the age modifiers as provisional FM26 values,** and flag them as unverified in the tool.
6. **Read values from FMRTE 27, FM Lens or FMLibreEditor** rather than the in-game icons. Some free FM27 editors cannot yet write fitness fields.\[22\]

## Caveats
- FM27 had been out three days at the time of writing. Every FM27 numeric claim here comes from a handful of community testers using single saves (label b). None of it is SI-confirmed.
- The Match Lab study's detailed tables (85%, 90%, 95% condition; 85%, 90% sharpness; positional splits) could not be retrieved.
- Several "FM27 guides" (for example footballmanagers27.wiki and fmtacticlab.com) make unsourced claims such as "a player at 92% condition is one sprint away from a hamstring injury".\[39\] I excluded them as speculation or relabelled generic content.
- **Still unverified for FM27:** the 85% injury cliff, the 250 jadedness level, the age and attribute modifiers, the positional multipliers, the consecutive-start limits, per-day condition recovery, the effect of two matches in 3–4 days, sharpness gains from friendlies and reserve games, and any change to the injury model.

## Sources

1. [Featured Content - Sports Interactive Community](https://community.sports-interactive.com/featured/)
2. [fix(app): Name the raw values FM Lens still showed by IamDejman · Pull Request #138 · IamDejman/fm-lens](https://github.com/IamDejman/fm-lens/pull/138)
3. [The Windows-first features on macOS by tozmoz · Pull Request #60 · tozmoz/FMLibreEditor · GitHub](https://github.com/tozmoz/FMLibreEditor/pull/60)
4. [All club actions like Insprire all, refresh all, max cohesion e.t.c a… · Issue #110 · IamDejman/fm-lens · GitHub](https://github.com/IamDejman/fm-lens/issues/110)
5. [Jadedness: read, edit and rest it by tozmoz · Pull Request #48 · tozmoz/FMLibreEditor](https://github.com/tozmoz/FMLibreEditor/pull/48)
6. [Football Manager 27 Feature Deep Dive: Enhanced Match Engine - Sakura Index](https://www.sakuraindex.jp/press-releases/football-manager-27-feature-deep-dive-enhanced-match-engine/)
7. [FM27: Match Engine and Tactical Tweaks - sortitoutsi.net News - FM27 - Football Manager 27](https://sortitoutsi.net/content/77885/fm27-match-engine-and-tactical-tweaks)
8. [FM27 Match Lab (macOS): Tool to simulate matches outside the game](https://fm-arena.com/threads/fm27-match-lab-macos-tool-to-simulate-matches-outside-the-game.96/)
9. [Training Schedules](https://fm-arena.com/threads/training-schedules.60/)
10. [FM27 New Features Guide: Everything New in Football Manager 2027](https://www.fmscout.com/a-football-manager-2027-new-features.html)
11. [Football Manager 27](https://www.footballmanager.com/fm27)
12. [Football Manager 27 Release Date, Platforms & Editions — Everything We Know](https://www.dlcompare.com/gaming-news/football-manager-27-release-date-platforms-editions-87666)
13. [Football Manager 26](https://en.wikipedia.org/wiki/Football_Manager_26)
14. [Football Manager 2027 Patch 27.0.1 - Update Beta to Final](https://www.fmscout.com/a-fm27-update-27.0.1.html)
15. [CalmDark FM27 Skin 0.28.2 (Windows) & 0.28.3 (MacOS)](https://www.fmscout.com/a-calmdark-fm27-skin.html)
16. [TangFu Skin V27.0.2](https://www.fmscout.com/a-tangfu-fm27-skin.html)
17. [YoshiAlfie FM27 skin](https://fmportugal.net/en/yoshialfie-skin-fm27/)
18. [Player Fitness Condition: FM is unplayable - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/581072-player-fitness-condition-fm-is-unplayable/)
19. [( Part 1 ) Conditions Management - one of the core FM26 mechanics](https://fm-arena.com/thread/16275-conditions-management-one-of-the-core-fm26-mechanics/)
20. [Upcoming changes to the configuration of FM-Arena tactic testing league.](https://fm-arena.com/thread/1979-upcoming-changes-to-the-configuration-of-fm-arena-tactic-testing-league/page-3/)
21. (private source removed)
22. [FM27€0 v1.1.0 - Live Editor for FM27 - General Discussion - FM27 - Football Manager 27](https://sortitoutsi.net/content/78059/fm27eur0-v100-live-editor-for-fm27)
23. [Keep live values editable after the youth intake by tozmoz · Pull Request #88 · tozmoz/FMLibreEditor · GitHub](https://github.com/tozmoz/FMLibreEditor/pull/88)
24. [FM27: 2D Match, In-Game Editor and more](https://www.footballmanager.com/fm27/features/fm27-2d-match-engine-game-editor-and-deeper-world-upgrades)
25. [Football Manager 27 Training Overhaul: New Features & Tactical Effectiveness Explained](https://realsport101.com/article/football-manager-27-overhauls-training-new-ui-tactical-effectiveness-complexity)
26. [FM27: Training and Tactical Effectiveness](https://www.footballmanager.com/fm27/features/fm27-training-and-tactical-effectiveness)
27. [Gameplay Upgrades in FM27 Mobile](https://www.footballmanager.com/fm27/features/fm27-mobile-more-influence-your-fingertips)
28. [( Part 2 ) Conditions Management - one of the core FM26 mechanics](https://fm-arena.com/thread/16417-part-2-conditions-management-one-of-the-core-fm26-mechanics/)
29. ["Rest" exploit - FM26](https://fm-arena.com/thread/16424-rest-exploit-fm26/)
30. [ZaZ - FM27 - Tactics Sharing Centre (Upload/Download) - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612941-zaz-fm27/)
31. [How to optimize player fitness and why it's crucial](https://fm-arena.com/thread/15972-how-to-optimize-player-fitness-and-why-it-s-crucial/)
32. [(Tentatively) New training schedule renderings based on attribute test results, welcome to propose more combination](https://fm-arena.com/thread/13712-tentatively-new-training-schedule-renderings-based-on-attribute-test-results-welcome-to-propose-more-combination/page-12/)
33. [European Regulations & Squad Freedom Megapack (FM27)](https://fmscout.com/a-european-regulations-and-squad-freedom-megapack-fm27.html)
34. [Five substitutions in the Premier League: how many subs…](https://englishpremierleague.watch/guides/five-substitutions-rule/)
35. [FM27: 2D Match Engine, IGE and Football World Depth - sortitoutsi.net News - FM27 - Football Manager 27](https://sortitoutsi.net/content/77939/fm27-2d-match-engine-ige-and-football-world-depth)
36. [FM27 Match Engine Deep Dive: What Actually Changes?](https://www.footballmanagerblog.org/2026/10/fm27-match-engine-deep-dive-tactical-tweaks.html)
37. [FM27 Match Engine: Speed, Stamina & Tactical Tweaks](https://fm27game.wiki/match-engine/)
38. [Football Manager 27 on Steam](https://store.steampowered.com/app/4530370/Football_Manager_27/)
39. [FM27 training guide](https://footballmanagers27.wiki/guides/fm27-training)
