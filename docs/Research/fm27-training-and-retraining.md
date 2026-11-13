# FM27 Training & Position Retraining: What Changed, What Carries Over, and What Is Still Unknown (as of 12 November 2026)

FM27 rebuilt team training around match preparation and Tactical Effectiveness, but Sports Interactive has published nothing that changes how position retraining works: individual training still lets players "learn new traits, positions and more",\[1\] and every number your tool uses for retraining speed, timelines and familiarity thresholds is still FM24/FM26-era knowledge that has not been re-verified in FM27. The most useful new FM27 data point for your tool is a cost, not a speed: FM-Arena user caiograco's FM27 Match Lab simulation study (11 Nov 2026, run on FM27 27.0.0/27.0.1) reported that "Starters out of position (position ratings capped at 10) cost 0.85 ppg. Nothing I changed on the tactics screen came anywhere near those", where by his own scale "+0.1 points per game is roughly 4 points over a season". Keep your retraining logic, label it as carried over, and add separate in-possession and out-of-possession position checks.

**Evidence labels used throughout:**
- **[OFFICIAL]** official Sports Interactive material
- **[FM27-DATA]** FM27 community testing with data
- **[CARRY-OVER]** FM26 (or older) knowledge assumed to carry over
- **[SPECULATION]** speculation, unsourced or low-quality claims

## TL;DR

- **Training changed a lot in FM27; retraining, as far as anyone can show, did not.** SI moved Training to the main navigation bar, brought back copy/paste schedules, added multi-week load indicators, and replaced the old "Units" with match-preparation and tactical sessions that feed Tactical Effectiveness. Individual training for positions is explicitly retained.\[2\] No official or tested FM27 source describes any change to how fast players learn positions.
- **Your four assumptions:** speed factors (age, Versatility, proximity) and efficient pathways are *unknown in FM27*, so keep them as carry-over. The "12+ = Competent" minimum is *unverified and contested*: sources disagree on thresholds and FM27 shows familiarity only as coloured dots.\[3\] The training-load/fatigue/rest assumption is *confirmed in direction* by official load indicators and FM27 test data.
- **Biggest practical update:** in FM26/FM27, a player's in-possession (IP) and out-of-possession (OOP) positions can differ, OOP familiarity affects Tactical Effectiveness, and FM26 players reported that OOP position familiarity could not be trained properly.\[4\]\[5\]\[6\]\[7\]\[8\] Nothing confirms this was fixed in FM27, so your tool should check both phases and treat OOP retraining as unreliable.

## Key Findings

| # | Finding | Label | Source (URL, date) |
|---|---|---|---|
| 1 | Training moved to the primary nav bar; copy/paste of training schedules returned; the UI shows "visual indicators on the physical load… both for the current week and the longer period ahead" | [OFFICIAL] | https://www.footballmanager.com/fm27/features/fm27-training-and-tactical-effectiveness (FM27 deep dive, October 2026)\[2\] |
| 2 | "The previous Units system, primarily centred around developing player attributes, has been replaced with options and setups that focus on the goal of executing a tactical plan in the next match" | [OFFICIAL] | same page, October 2026\[2\] |
| 3 | Individual training retained: "Use personal training instructions to help players learn new traits, positions and more"\[9\] | [OFFICIAL] | same page, October 2026\[2\] |
| 4 | Tactical Effectiveness has four parts (Tactical Understanding, Player Ability, Player Buy-In, Next Match Information), builds on Tactical Familiarity, and appears as gauges in Tactics, Training and Recruitment\[9\] | [OFFICIAL] | same page, October 2026\[2\] |
| 5 | An FM-Arena tester says FM27's attribute-growth system "remains unchanged (Compare to fm24 and fm26)": growth comes from matches plus professionalism, ambition, age and facilities, then is allocated by training, intensity and focus | [FM27-DATA] | https://fm-arena.com/thread/20925-fm27-attribute-test-tactical-understanding-training/ (Launch Preview period, late Oct–early Nov 2026)\[10\] |
| 6 | Starters out of position (position ratings capped at 10) cost 0.85 ppg; 80% condition cost 0.8 ppg; 50% match sharpness cost about 1 ppg; 75% sharpness cost about 0.37 ppg | [FM27-DATA] | https://fm-arena.com/threads/fm27-match-lab-macos-tool-to-simulate-matches-outside-the-game.96/ (11 Nov 2026; caiograco: "I've thrown about 190,000 matches at it", built from "ten real matches of one club (a newly promoted PL side, so mostly underdog games)… replays all ten matches 200-300 times") |
| 7 | No FM27 source gives retraining timelines, familiarity thresholds, or the effects of age or Versatility | — | Gap (see Evidence Gaps) |

## 1. What changed in training from FM26 to FM27

### FM26 baseline (so the comparison is accurate)
- **FM26 removed direct control of B-team and youth-team general training at launch**, which put more weight on individual training and loans. [CARRY-OVER] https://www.fm26tactics.com/guides/training-schedule-guide (FM26 season, 2025–26).\[11\] A community blogger reports that **FM26 Update 3 (20 November 2025, beta track) restored editing of youth teams' general training.** [CARRY-OVER] https://coffeehousefm.com/fmrensieblog/fm26-my-training-regime (late 2025)\[12\]
- **FM26 added a separate out-of-possession role to individual training** ("we can also select the out of possession role to train"). [CARRY-OVER] https://coffeehousefm.com/fmrensieblog/fm26-my-training-regime (late 2025)\[12\]
- **FM26 intensity and rest controls:** training intensity and rest were set per condition band (five levels), with options of Automatic, Half, Normal, Double, or "No pitch or gym work". [CARRY-OVER] https://www.passion4fm.com/master-football-manager-26-proven-hints-tips-to-elevate-your-game/ (FM26 season).\[13\] The FM-Arena community held that FM26 training mechanics were unchanged from FM24 ("Training has not changed in FM26"). [CARRY-OVER] https://fm-arena.com/thread/16161-what-is-the-best-training-schedule-in-fm26/ (FM26 season)\[14\]

### What FM27 changed (official)
All of the following come from https://www.footballmanager.com/fm27/features/fm27-training-and-tactical-effectiveness (October 2026) and are **[OFFICIAL]**:
- **Navigation and UI:** Training is a primary navigation area, there are fewer clicks for common actions, and you can choose which screen Training opens on.\[2\]
- **Schedules:** "the ability to copy and paste training plans is once again available."\[2\]
- **Load visibility:** more visual indicators of "the physical load that your training plan will have on the squad, both for the current week and the longer period ahead."\[2\]
- **Purpose per squad:** "each of your squads will have a specific purpose… Your senior squad is more attuned with match preparation, focusing more on team cohesion and tactical understanding."\[2\]\[9\]
- **Units replaced:** the old Units system is gone. Sessions now target tactical execution, for example "a team's ability to press high up the pitch, or sit in a low block."\[2\]\[9\]
- **Individual training:** retained for attributes, traits and positions, but "you'll now need to balance their long-term Individual Training and personal development priorities with your short-term need to win matches."\[2\]\[9\]
- **International camps:** you can now create training plans with an international team during a camp.\[2\]
- **Development-build caveat:** SI states the footage "is from a development build… subject to change before release."\[2\]

SI's separate FM27 round-up confirms that **Match Preparation, Training Review and Training Schedule messages were upgraded**: you can set the match-preparation type for every scheduled session before a game, and the regular training breakdown (with praise and criticism) returns.\[15\]\[16\] [OFFICIAL] https://www.footballmanager.com/fm27/features/fm27-2d-match-engine-game-editor-and-deeper-world-upgrades (October 2026)

**Intensity and rest controls in FM27:** no official source describes any change to the per-condition intensity and rest system. FM27 testers are using the same controls as FM26: "from very poor condition to excellent condition: no pitch or gym work x3, double intensity x2" [FM27-DATA] https://fm-arena.com/thread/20925-fm27-attribute-test-tactical-understanding-training/ (late Oct–early Nov 2026).\[10\] Asked whether intensity settings are "same as FM 26", the FM-Arena tester ZaZ replied "I recommend the same until proven wrong" [FM27-DATA, opinion not test] https://fm-arena.com/thread/20918-zaz-fm-27-preview/page-2/ (Launch Preview, ~Nov 2026).\[17\] Treat the control set as **carried over, with no official confirmation**.

**Console caveat:** in the SI forum's FM27 Console FAQ thread, a reply states that Console has "no tactical effectiveness system, but the Training is changed, mostly UI and some under the hood changes". Console match prep uses inbox messages covering three sessions.\[18\] [OFFICIAL for the FAQ text; the "no TE on console" reply has unverified authorship] https://community.sports-interactive.com/forums/topic/612658-fm27-console-faqs/ (FAQ reply quoted from a 2 Nov 2026 question). If your tool supports console saves, branch on platform.

### How training connects to Tactical Effectiveness
- **Officially, TE has four pillars,** and Tactical Complexity (the volume of team, player and opposition instructions) trades off against squad ability: simple tactics are "instantly effective, but have limited potential", while complex tactics "struggle to have an impact initially… but have a higher long-term ceiling."\[2\] [OFFICIAL] https://www.footballmanager.com/fm27/features/fm27-training-and-tactical-effectiveness (October 2026). SI has not published pillar weights; ZaZ, in an FM-Arena "Training Schedules" thread, relays that "According to some research from chinese players, tactical effectiveness is composed by 50% of tactical understanding, 10% of player ability, 25% of player buy in, and 15% of next match info." [SPECULATION, secondhand]
- **SI's Dugout article links positions directly to TE:** if a player "is expected to become a Screening Defensive Midfielder Out of Possession without possessing the necessary familiarity or attributes, their effectiveness may suffer until they adapt… Play players in their natural positions both In and Out of Possession."\[8\] [OFFICIAL] https://www.footballmanager.com/the-dugout/tactical-effectiveness-understanding-fm27s-key-new-feature (FM27 cycle, Oct–Nov 2026)
- **Measured contribution of training to TE:** an FM-Arena tester who drove FM27's own match engine outside the game found that the Tactical Understanding pillar is driven about "twice as much" by training as by match exposure.\[19\] Untrained cost about 0.4 ppg, well-trained (about 75 per area) gained about 0.2 ppg, and there was no gain above that cap.\[19\] [FM27-DATA] https://fm-arena.com/threads/fm27-match-lab-macos-tool-to-simulate-matches-outside-the-game.96/ (11 Nov 2026; one newly promoted Premier League club, 10 real matches replayed 200–300 times per condition; AI-assisted write-up; small effects flagged as unconfirmed by the author)
- **A second tester in the same thread** (about 750 matches per level) reports that each Tactical Understanding session on a non-match day gives every player a "record" for that area.\[19\] Records decay: half value after about 3 weeks, about a sixth after about 3 months, zero after about 8 months. Player tactical ability, coach quality and time at the club act only as multipliers.\[19\] His routine of "12 Tactical Understanding sessions a week, covering all 8 areas" in his test save "reaches about 60 in 17 weeks and about 80 after a season." [FM27-DATA, partly from reading game data] same URL, 11 Nov 2026
- **A conflicting FM27 test** compared zero Tactical Understanding training with 8 sessions a week: per the sortitoutsi write-up of the same test, TU in the trained group "was approximately 30% higher than that of the first group, and the winning rate increased by 3.5%". That tester concluded TU training "isn't worth the effort" and "significantly increases the risk of injury", in contrast to position familiarity, "which has a major impact." [FM27-DATA] https://fm-arena.com/thread/20925-fm27-attribute-test-tactical-understanding-training/ (late Oct–early Nov 2026); https://sortitoutsi.net/content/78219/fm27-attribute-test-tactical-understanding-training-system-preset-tactics-ai-reverse-engineering-engine-for-test (early Nov 2026). **The two FM-Arena results disagree on whether TU training pays off; neither is a large multi-club sample.**

## 2. How position retraining works in FM27

### How it is started
- **Official:** through individual training ("personal training instructions to help players learn new traits, positions and more").\[1\]\[9\] SI has not published the exact FM27 menu path. [OFFICIAL] https://www.footballmanager.com/fm27/features/fm27-training-and-tactical-effectiveness (October 2026)
- **FM26 mechanism, likely carried over:** in FM26 you choose an IP position/role and, separately, an OOP role in individual training. FM26 bug reports state that the OOP selector offers only "generalized positional groups which can not train the player in a position only the role", so "it is impossible to improve a players OOP familiarity for a position without training them IP for this position."\[7\] [CARRY-OVER] https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/all-other-issues/there-is-currently-no-option-to-train-a-players-out-of-possession-position-the-way-you-can-with-in-possession-r33094/ (FM26, 2025)
- **The retraining mechanic still exists in FM27:** the FM27 achievement "They're a Natural" requires you to "Retrain a player until he becomes a natural in a new position". So reaching Natural in a new position is at least possible.\[20\] [OFFICIAL in-game content, reported secondhand] https://retrogems.fr/en/football-manager-27-achievements-list/ (Nov 2026)

### What speeds it up or slows it down
**No FM27 source, official or tested, quantifies any factor.** Everything below is carry-over:
- **Versatility** "directly governs the speed at which a player will learn and adapt to a new position"; existing partial familiarity speeds learning; playing time helps (the author admits this is anecdotal).\[21\] [CARRY-OVER] https://playingbetweenthelines.wordpress.com/2013/06/05/to-retrain-or-not-to-retrain/ (5 June 2013)
- **Age:** "an older player will have more difficulty to learn a new position"; high adaptability speeds learning.\[22\]\[23\] [CARRY-OVER] https://fminside.net/guides/basic-guides/18-player-positional-ability (undated, pre-FM26)
- **CA/PA headroom:** long-standing community belief is that learning positions consumes Current Ability budget, so players at their ceiling may stall. One forum user wrote that "learning a new position takes up PA and if a player doesn't have any free PA, then that might be why he isn't progressing."\[24\] [CARRY-OVER, unverified] https://community.sports-interactive.com/forums/topic/458065-training-new-position/ (FM19 era, 2018)
- **Training vs playing, contested even pre-FM27:** in one SI forum thread, one user says "Training a player in a new position will have no impact on his familiarity", while another says "Depending on their versatility they can get pretty high positional familiarity from just training… but match time in their new position is more efficient."\[25\] [CARRY-OVER, conflicting anecdotes] https://community.sports-interactive.com/forums/topic/580515-how-to-train-new-positions/ (FM24/FM26 era)

### Typical time to each familiarity level
- **No FM27 timings exist.** The only FM27 guidance found is generic: "Learning a new position takes many months, so start early."\[26\] [SPECULATION, no data] https://www.fmtacticlab.com/fm27-training-guide (undated, FM27 cycle)
- **Older estimate:** "approximately six to nine months to retrain a player in a brand new position… and about 12 months overall before… 'Natural'".\[27\] [CARRY-OVER] https://sortitoutsi.net/content/67473/fm24-guide-how-to-retrain-players-position (FM24 guide)
- **Older anecdote:** a very versatile player can take "around a month".\[28\] [CARRY-OVER, anecdote] https://fm-base.co.uk/threads/how-long-does-it-take-to-retrain-a-player-in-a-different-position.68061/ (old FM version)

### Familiarity tiers and numeric thresholds (conflicting)
| Tier | SI FM24 manual | FMInside (older) | FM27 community tool claim |
|---|---|---|---|
| Natural | 18–20 | 19–20 | 20 |
| Accomplished | 15–17 | 13–17 | 15–19 |
| Competent | 12–14 | 10–12 | 10–14 |
| Unconvincing | 9–11 | 6–8 | 5–9 |
| Awkward | 5–8* | 1–5 | 2–4 |
| Ineffectual | 0–1* | — | 1 |

Sources:
- SI FM24 manual: [CARRY-OVER, official but FM24] https://community.sports-interactive.com/sigames-manual/football-manager-2024/players-r4958/ (FM24, 2023).\[29\] *The Awkward and Ineffectual values come from the sortitoutsi FM24 retraining guide based on it, which lists "Awkward: 5-8, Makeshift: 2-4, Ineffectual: 0-1" and advises "Aim for getting at least 12 at desired position." https://sortitoutsi.net/content/67473/fm24-guide-how-to-retrain-players-position
- FMInside: [CARRY-OVER] https://fminside.net/guides/positional-guides/18-player-positional-ability (undated)\[23\]
- FM27 tool claim: [SPECULATION, unverified third-party code] https://github.com/StrawzyCode/FM27Manager (Nov 2026)\[30\]
- Another FM27 tool author notes that "FM27 shows it only as coloured dots, which no export contains" [FM27 community observation] https://github.com/Dixnnn/FM27-System-and-Tactic-Designer (Nov 2026).\[3\] **So the numeric thresholds are not visible in the FM27 UI and are not officially documented for FM27.**

### Do match minutes in the position matter?
- **For position familiarity: no FM27 evidence.** Older community consensus says match time accelerates learning and is needed to reach Natural ("I never had a player to reach natural without actually playing there").\[25\]\[31\]\[32\] [CARRY-OVER] https://community.sports-interactive.com/forums/topic/525276-training-new-positions/ (pre-FM26)
- **FM26 warning for OOP:** an FM26 bug report says a DM played out of possession at centre-back "for multiple years" gained "ZERO positional familiarity".\[4\] Other FM26 reports describe OOP familiarity "stuck with 0% progress" for about 20% of players.\[4\]\[5\] [CARRY-OVER] https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/1887_newgen-development-training/oop-position-familiarity-does-not-increase-r44901/ (FM26, March 2026); https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/1887_newgen-development-training/out-of-possession-familiarity-r42066/ (27 Nov 2025). **No FM27 patch note, SI reply or test confirms a fix.** The FM27 27.0/27.0.1 patch notes seen do not mention it. https://www.fmscout.com/a-fm27-update-27.0.1.html (10 Nov 2026); https://x.com/Passion4FM/status/2119839806171537466 (Nov 2026)\[33\]\[34\]

## 3. Assumption-by-assumption verdicts

| Assumption (FM26-based) | FM27 verdict | What the evidence says | Label | Source URL (date) |
|---|---|---|---|---|
| Retraining speed depends mainly on age, Versatility and proximity to known positions | **Unknown** (keep as carry-over) | No FM27 source mentions these factors. Older guides cite Versatility, age, existing familiarity and match time; CA headroom is a possible extra factor\[21\]\[22\] | [CARRY-OVER] | https://playingbetweenthelines.wordpress.com/2013/06/05/to-retrain-or-not-to-retrain/ (5 Jun 2013); https://fminside.net/guides/basic-guides/18-player-positional-ability (undated) |
| Efficient pathways: winger→wing-back; ageing AM→DM | **Unknown** | FM27 guides use winger→wing-back as an example but give no data.\[26\] Under IP/OOP, a winger can be a winger IP and a wing-back OOP, so the "pathway" now has two dimensions. SI advises natural positions "both In and Out of Possession" | [SPECULATION] for pathways; [OFFICIAL] for IP/OOP advice | https://www.fmtacticlab.com/fm27-training-guide (FM27 cycle); https://www.footballmanager.com/the-dugout/tactical-effectiveness-understanding-fm27s-key-new-feature (Oct–Nov 2026)\[8\]\[26\] |
| Familiarity 12+ ("Competent") is the minimum to field a player | **Unverified / contested** | Competent = 12–14 only in the FM24 official manual; other sources put Competent at 10–12 or 10–14. FM27 shows dots, not numbers. FM27 data: ratings capped at 10 cost 0.85 ppg, so 10 is clearly too low for starters | [CARRY-OVER] + [FM27-DATA] | https://community.sports-interactive.com/sigames-manual/football-manager-2024/players-r4958/ (FM24); https://fm-arena.com/threads/fm27-match-lab-macos-tool-to-simulate-matches-outside-the-game.96/ (11 Nov 2026)\[19\]\[23\]\[29\] |
| Training intensity and workload add fatigue and injury risk; rest days reduce both | **Confirmed in direction; details carried over** | SI shows multi-week physical-load indicators. FM27 tests: Normal and Double intensity "lowered match-day condition without a clear gain, and intensity also feeds the game's injury risk"; heavy TU training "significantly increases the risk of injury"\[10\] | [OFFICIAL] + [FM27-DATA] | https://www.footballmanager.com/fm27/features/fm27-training-and-tactical-effectiveness (Oct 2026); https://fm-arena.com/threads/fm27-match-lab-macos-tool-to-simulate-matches-outside-the-game.96/ (11 Nov 2026); https://fm-arena.com/thread/20925-fm27-attribute-test-tactical-understanding-training/ (late Oct–early Nov 2026)\[2\]\[10\]\[19\] |

## 4. Training load, condition, fatigue, injury risk and match sharpness

- **Load visibility (official):** physical-load indicators now cover the current week and the longer period ahead.\[2\] [OFFICIAL] https://www.footballmanager.com/fm27/features/fm27-training-and-tactical-effectiveness (October 2026)
- **Injury-risk explanation (official, Mobile):** SI's FM27 Mobile feature describes injury-risk advice "combining factors such as injury history, fitness, fatigue, and match load", with recommendations on selection and training intensity.\[35\] **This is documented for FM27 Mobile; it is not confirmed for PC/Mac.** [OFFICIAL] https://community.sports-interactive.com/featured/ ("FM27: More Influence At Your Fingertips", Oct 2026)
- **Concussion protocol (official, new):** concussed players need explicit clearance from a neurologist before returning, and you can track this in the Medical Centre.\[16\] [OFFICIAL] https://www.footballmanager.com/fm27/features/fm27-2d-match-engine-game-editor-and-deeper-world-upgrades (October 2026)
- **Condition and sharpness have a large effect on results (FM27 data):** 80% condition cost 0.8 ppg; 50% sharpness cost about 1 ppg; 75% sharpness cost about 0.37 ppg. "Nothing I changed on the tactics screen came anywhere near those."\[19\] [FM27-DATA] https://fm-arena.com/threads/fm27-match-lab-macos-tool-to-simulate-matches-outside-the-game.96/ (11 Nov 2026; one club, simulated)
- **Intensity (FM27 data):** one tester sets "Half for every fitness band" because Normal and Double "lowered match-day condition without a clear gain". Others still recommend the FM26 pattern of double intensity at full condition and no pitch/gym work below that, and ZaZ, in his SI forum "ZaZ - FM27" thread, adds a TE-based switch: "Use Tactical Understanding until you reach 50% tactical effectiveness, then use Growth when above that threshold." **These are conflicting FM27 recommendations; neither has season-long injury data.** The first tester notes that "a real fatigue test needs… a season-long in-game test".\[19\] [FM27-DATA] same URL (11 Nov 2026); https://fm-arena.com/thread/20925-fm27-attribute-test-tactical-understanding-training/ (late Oct–early Nov 2026)
- **Sharpness and training:** a shorter training schedule means players' match sharpness is not topped up by training.\[36\] [FM27-DATA, assertion] https://sortitoutsi.net/content/78219/fm27-attribute-test-tactical-understanding-training-system-preset-tactics-ai-reverse-engineering-engine-for-test (early Nov 2026, updated 3 Nov)
- **Rest:** in FM26, community testing held that full rest (3x rest / "super rest") beats recovery sessions for restoring condition and preventing injury.\[37\] [CARRY-OVER] https://fm-arena.com/thread/16424-rest-exploit-fm26/ (FM26 season). FM27 testers still recommend "a full rest day after matches".\[38\] [FM27-DATA, recommendation] https://fm-arena.com/thread/20918-zaz-fm-27-preview/ (Launch Preview, late Oct 2026)
- **Jadedness/accumulated fatigue:** **no FM27-specific source found.** One FM27 wiki claims "weekly load" and "long-term load" meters, and that a squad in the red for a month "will lose condition permanently".\[39\] It cites no source or test. [SPECULATION] https://footballmanagers27.wiki/guides/fm27-training (30 Oct 2026)

## 5. Limits and costs of retraining

- **Losing old-position familiarity:** an SI staff member stated (in an older version) that "We have in fact introduced a feature this year that means a player can 'forget' an old position in order to help him learn a new one."\[40\] [CARRY-OVER, official but pre-FM26] https://community.sports-interactive.com/forums/topic/451020-bug-players-seem-unable-to-learn-new-positions/ (about 2018). In the same thread SI added advice for "when a player has reached his highest possible rating in a new position", meaning **not every player can reach Natural.**\[40\] Community reports agree that old-position familiarity "will go down… and will never recover" when a player is pushed to Natural elsewhere.\[32\] [CARRY-OVER, anecdote] https://community.sports-interactive.com/forums/topic/525276-training-new-positions/ (pre-FM26).\[32\] **No FM27 confirmation.**
- **Unhappiness:** FM26 users report that OOP individual training "only seems to result in the players becoming unhappy with training".\[41\] [CARRY-OVER] https://community.sports-interactive.com/forums/topic/596575-out-of-possession-training/ (FM26 season). Older guidance warns that an extra position adds workload and "they may become unhappy if they believe the workload is too great".\[21\] [CARRY-OVER] https://playingbetweenthelines.wordpress.com/2013/06/05/to-retrain-or-not-to-retrain/ (5 Jun 2013). **No FM27 evidence.**
- **Cost to Tactical Effectiveness:** officially, a player asked to play an OOP role without the familiarity "may suffer until they adapt".\[8\] [OFFICIAL] https://www.footballmanager.com/the-dugout/tactical-effectiveness-understanding-fm27s-key-new-feature (Oct–Nov 2026)
- **Short-term vs long-term tension:** SI says individual development must now be balanced "with your short-term need to win matches".\[2\] [OFFICIAL] https://www.footballmanager.com/fm27/features/fm27-training-and-tactical-effectiveness (October 2026)
- **Role/duty familiarity:** older guidance says role familiarity "does NOT exist" separately from position.\[42\] [CARRY-OVER] https://www.passion4fm.com/football-manager-youth-development-guide/ (pre-FM26). FM26/27 track IP and OOP roles separately, and FM27 TE has a role-related component, but **no FM27 source explains how role familiarity interacts with position retraining.**
- **Caps on how many players retrain at once:** **no source found, official or community.**
- **FM26 individual-training override bugs:** on FM26 console, mobile and Xbox, individual-training position selections were overwritten by staff when training was delegated. SI said "This is a known issue that we're looking to resolve in the next game update".\[43\]\[44\]\[45\] [CARRY-OVER] https://community.sports-interactive.com/bugtracker/2103_football-manager-26-console-bug-tracker/user-interface/xbox/setting-individual-training-for-any-player-gets-overridden-by-the-system-r42675/ (FM26 season). Whether this persists in FM27 is unknown.

## Recommendations for your tool

1. **Do not change the retraining-speed model yet; relabel it.** Mark age, Versatility and proximity weights as "FM24/26 carry-over, unverified in FM27". There is no FM27 basis for changing them, and none for trusting them more.
2. **Split position checks into IP and OOP.** SI's own advice is natural positions "both In and Out of Possession".\[8\] For each depth gap, check familiarity in both phases. Flag any recommendation that relies on OOP retraining as "low confidence (FM26 OOP training issue unresolved)".
3. **Replace the hard 12+ rule with tier-based logic plus a margin.** Use Competent or better as the minimum for rotation and Accomplished or better for regular starters. Treat numeric cut-offs as approximate, because FM27 shows coloured dots and sources disagree on whether Competent starts at 10 or 12. The FM27 finding that capping ratings at 10 costs about 0.85 ppg supports being stricter, not looser.
4. **Add a "can't reach Natural" outcome** and an "old position may decay" warning for players pushed toward Natural elsewhere, especially when the old position also covers a depth gap.
5. **Add a load penalty to retraining picks.** Prefer candidates who are not first-choice starters in congested periods. Condition and sharpness effects (about 0.8–1 ppg) dwarf most other levers in FM27 test data.
6. **Re-test in your own save.** Retrain 3–5 players with known starting dots and log the date of each tier change, with and without match minutes in the position. A few in-game months of tracking would give you better FM27 data than anything published so far.

## Evidence gaps (no FM27 evidence found)

- Exact FM27 menu flow for starting position retraining.
- Any FM27 timeline for any familiarity tier.
- Whether age, Versatility or position proximity effects changed in FM27.
- Whether match minutes in the position speed up FM27 familiarity gain (IP or OOP).
- Numeric familiarity thresholds in FM27, and whether "Makeshift" exists as a tier.
- Whether the FM26 OOP position-familiarity training issue is fixed.
- Loss of old-position familiarity and player unhappiness in FM27.
- Any cap on simultaneous retraining.
- Whether FM27 models accumulated fatigue/jadedness differently from FM26.
- Whether the per-condition intensity/rest controls changed in FM27, beyond community usage.
- Whether the Mobile injury-risk explanation also exists on PC/Mac.

## Caveats

- **Freshness:** FM27 has been out for two days, and FM-Arena had only just come back online (its users joined 10–11 Nov 2026). Most FM27 "testing" is from the Launch Preview or a single save. Methods are documented, but samples cover one club.
- **Relabelled content:** several "FM27 guides" (e.g. fmtacticlab.com, footballmanagers27.wiki, touchlinefm.com, fm27game.wiki) repeat generic or FM26-era advice with no data, and some admit they ran no FM27 experiments.\[46\] They are cited here only as [SPECULATION] or not at all.
- **Development-build footage:** SI's deep dive was based on a pre-release build and "subject to change".\[2\]

## Sources

1. [FM27](https://community.sports-interactive.com/forums/topic/612100-fm27-training-tactical-effectiveness-faqs/)
2. [FM27: Training and Tactical Effectiveness](https://www.footballmanager.com/fm27/features/fm27-training-and-tactical-effectiveness)
3. [GitHub - Dixnnn/FM27-System-and-Tactic-Designer · GitHub](https://github.com/Dixnnn/FM27-System-and-Tactic-Designer)
4. [OOP Position Familiarity Does NOT Increase - Newgen Development & Training - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/1887_newgen-development-training/oop-position-familiarity-does-not-increase-r44901/)
5. [Out of Possession Familiarity - Newgen Development & Training - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/1887_newgen-development-training/out-of-possession-familiarity-r42066/)
6. [Players not learning out-of-position training - Newgen Development & Training - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/1887_newgen-development-training/players-not-learning-out-of-position-training-r37324/)
7. [There is currently no option to train a players out of possession position the way you can with In Possession - All Other Issues - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/all-other-issues/there-is-currently-no-option-to-train-a-players-out-of-possession-position-the-way-you-can-with-in-possession-r33094/)
8. [Tactical Effectiveness: Understanding FM27's Key New Feature](https://www.footballmanager.com/the-dugout/tactical-effectiveness-understanding-fm27s-key-new-feature)
9. [FM27 New Features Guide: Everything New in Football Manager 2027](https://www.fmscout.com/a-football-manager-2027-new-features.html)
10. [FM27 Attribute Test + Tactical Understanding + Training](https://fm-arena.com/thread/20925-fm27-attribute-test-tactical-understanding-training/)
11. [FM26 Training Schedules: Best Weekly Plans & Individual Training — FM26 Tactics Guide](https://www.fm26tactics.com/guides/training-schedule-guide)
12. [FM26](https://coffeehousefm.com/fmrensieblog/fm26-my-training-regime)
13. [Master Football Manager 26: Proven Hints & Tips to Elevate Your Game • Passion4FM](https://www.passion4fm.com/master-football-manager-26-proven-hints-tips-to-elevate-your-game/)
14. [What is the best training schedule in FM26?](https://fm-arena.com/thread/16161-what-is-the-best-training-schedule-in-fm26/)
15. [FM27 New Features: 2D Match, Editor and Messages](https://fmslovakia.com/fm27s-small-changes-add-up-to-a-lot/)
16. [FM27: 2D Match, In-Game Editor and more](https://www.footballmanager.com/fm27/features/fm27-2d-match-engine-game-editor-and-deeper-world-upgrades)
17. [ZaZ - FM 27 Preview](https://fm-arena.com/thread/20918-zaz-fm-27-preview/page-2/)
18. [FM27](https://community.sports-interactive.com/forums/topic/612658-fm27-console-faqs/)
19. [FM27 Match Lab (macOS): Tool to simulate matches outside the game](https://fm-arena.com/threads/fm27-match-lab-macos-tool-to-simulate-matches-outside-the-game.96/)
20. [Football Manager 27 Guide: All 44 Trophies And 52 Achievements To Get The Platinum](https://retrogems.fr/en/football-manager-27-achievements-list/)
21. [To Retrain or Not To Retrain?](https://playingbetweenthelines.wordpress.com/2013/06/05/to-retrain-or-not-to-retrain/)
22. [Player Positional Ability - FMInside Football Manager Community](https://fminside.net/guides/basic-guides/18-player-positional-ability)
23. [Player Positional Ability - FMInside Football Manager Community](https://fminside.net/guides/positional-guides/18-player-positional-ability)
24. [Training new position - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/458065-training-new-position/)
25. [how to train new positions - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/580515-how-to-train-new-positions/)
26. [FM27 Training Guide](https://www.fmtacticlab.com/fm27-training-guide)
27. [FM24 Guide: How to Retrain Player's Position - General Discussion - FM24 - Football Manager 2024](https://sortitoutsi.net/content/67473/fm24-guide-how-to-retrain-players-position)
28. [How Long Does it take to retrain a player in a different position?](https://fm-base.co.uk/threads/how-long-does-it-take-to-retrain-a-player-in-a-different-position.68061/)
29. [Players - Football Manager 2024 - Sports Interactive Community](https://community.sports-interactive.com/sigames-manual/football-manager-2024/players-r4958/)
30. [GitHub - StrawzyCode/FM27Manager · GitHub](https://github.com/StrawzyCode/FM27Manager)
31. [Retraining Positions](https://fm-base.co.uk/threads/retraining-positions.51491/)
32. [Training New Positions - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/525276-training-new-positions/)
33. [Passion4FM on X: "#FM27 Launch will features these improvements: Patch Notes for 27.0 includes but are not limited to: 🇯🇵 Japanese (Men) national team is now playable ✅ fixed a bug where adding columns to a table would hide the default columns Other fixes are: Technical - Various crash and… / X](https://x.com/Passion4FM/status/2119839806171537466)
34. [Football Manager 2027 Patch 27.0.1 - Update Beta to Final](https://www.fmscout.com/a-fm27-update-27.0.1.html)
35. [Featured Content - Sports Interactive Community](https://community.sports-interactive.com/featured/)
36. [FM27 Attribute Test + Tactical understanding +Training system + preset tactics + "AI-reverse-engineering engine for test" - General Discussion - FM27 - Football Manager 27](https://sortitoutsi.net/content/78219/fm27-attribute-test-tactical-understanding-training-system-preset-tactics-ai-reverse-engineering-engine-for-test)
37. ["Rest" exploit - FM26](https://fm-arena.com/thread/16424-rest-exploit-fm26/)
38. [ZaZ - FM 27 Preview](https://fm-arena.com/thread/20918-zaz-fm-27-preview/)
39. [FM27 training guide](https://footballmanagers27.wiki/guides/fm27-training)
40. [Bug? Players seem unable to learn new positions - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/451020-bug-players-seem-unable-to-learn-new-positions/)
41. [Out of possession training - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/596575-out-of-possession-training/)
42. [The Ultimate Youth Development Guide](https://www.passion4fm.com/football-manager-youth-development-guide/)
43. [Setting individual training for any player gets overridden by the system. - Xbox - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/2103_football-manager-26-console-bug-tracker/user-interface/xbox/setting-individual-training-for-any-player-gets-overridden-by-the-system-r42675/)
44. [Individual Training Issue FM26 Console - FM Console and FM Touch General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/597509-individual-training-issue-fm26-console/)
45. [Individual Training Changes Automatically in Development Hub After Assignment (Potential Bug) - Android - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/2102_football-manager-26-mobile-bug-tracker/technical-support-and-crashes/android/individual-training-changes-automatically-in-development-hub-after-assignment-potential-bug-r44838/)
46. [FM27 Youth Development Guide: Under 17, Age 17 & 18+](https://touchlinefm.com/guides/youth-development)
