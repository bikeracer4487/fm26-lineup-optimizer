# Mentoring in Football Manager 27: The Rules, What Personality Gains Are Worth, and the Data Your Tool Needs

Mentoring is still in FM27 and can move hidden personality attributes, but no source gives a rate you can compute with. Neither Sports Interactive nor any community tester has published a per-month change, a formula or a controlled FM27 experiment. Build the tool as a rules-based grouper plus a measurement harness, not a predictor. The only numbers it can trust are the ones your own re-imports produce.

## TL;DR

- **Is it worth optimising? Only a little, and only for some attributes.** Mentoring moves hidden personality slowly, a "nudge" in SI's own words, and FM21 onward each shift touches a random subset of attributes. In caiograco's FM27 match-engine tests (FM-Arena, 13 Nov 2026; paired matches on the same random seeds, significance at t ≥ 3), professionalism, ambition, loyalty and adaptability have no in-match effect. Pressure is the one attribute with a clear effect: a squad at Pressure 1 loses 0.15 expected points a game, about 6 points a season. Professionalism is worth raising for development (FM24/FM26 tests: Prof 20 grows CA about twice as fast as Prof 10 in training-only conditions). So aim at professionalism, then pressure below about 6, then determination and ambition up to about 10, and ignore the rest.
- **The rules are known only in outline.** The FM24 manual says a group "must feature a minimum of three players" before it can start, and groups can be built by hand or by the assistant. All members must be from the same squad. Influence depends on the gap in squad hierarchy, social-group compatibility, the mentee's age and career first-team appearances, and the mentor's age and importance. Influence can run both ways, and returns run out after a while. These come from the FM24 manual and an FM19-era SI-verified guide. Nothing official confirms them for FM27.
- **Can it be done from FMRTE data? Partly.** FMRTE 27 confirms a configurable grid with a column picker and a "Joined Club" column. Your existing personality and hidden-attribute columns are the outcome variables. Squad hierarchy and influence, social group, mentoring-group membership and traits could not be confirmed as grid columns, so plan to enter hierarchy and group membership by hand from the game's Dynamics and Mentoring screens.

## Key Findings

| # | Finding | Label | Source and date |
|---|---|---|---|
| 1 | Mentoring groups need a minimum of three players.\[1\] | [CARRY-OVER] [OFFICIAL] | SI FM24 Touch/Console manual, Training, community.sports-interactive.com/sigames-manual/football-manager-2024-touch-and-console/training-r4984/ (FM24, 2023) |
| 2 | Influence is more likely the closer the players are "in profile", and depends on the senior player's age and squad importance and how well the group gets along. The FM24 manual says the longer players work together the more likely mentoring is to succeed, but it "isn't perpetual": at some point the return is maximised and is no further use to the younger player. The FM21 manual uses the same wording. | [CARRY-OVER] [OFFICIAL] | Same FM24 manual page |
| 3 | Mentees and mentors must be in the same squad.\[2\] Groups are about off-field dressing-room relationships, not training units. | [CARRY-OVER] [OFFICIAL] | SI's Zachary Whyte, FM23 bug tracker, community.sports-interactive.com (FM23 era)\[3\] |
| 4 | Factors: mentee age, mentee career first-team appearances, hierarchy difference, social-group standing. No fixed age limit. A captain can be dragged down. Traits pass between similar positions. "Welcome to club" acts as a short one-on-one mentoring.\[2\] | [CARRY-OVER] (SI-verified community guide) | "The Unofficially Official Training and Mentoring Guide", SI forums, Oct 2018 (updated for FM20/21), verified by SI's Seb Wassell\[4\] |
| 5 | From FM21 each personality shift changes only some attributes, chosen at random.\[5\] | [CARRY-OVER] (community observation) | Same guide thread, page 13; SI forum thread 590289\[6\] |
| 6 | Mentoring is "just a nudge"; changing personality takes time.\[7\] | [CARRY-OVER] [OFFICIAL] (dev forum post) | Seb Wassell, same guide thread, page 12\[8\] |
| 7 | FM27 replaced team-training Units with next-match preparation and moved Training into the main nav. Individual training (attributes, traits, positions) remains.\[9\]\[10\]\[11\] | [OFFICIAL] | footballmanager.com/fm27/features/fm27-training-and-tactical-effectiveness (2026)\[12\]\[13\] |
| 8 | No official FM27 text on mentoring rules was found. A third-party FM27 guide says mentoring sits in Training and admits FM27 weights are unmeasured.\[14\] | [SPECULATION]\[15\] | touchlinefm.com/guides/mentoring, updated 2 Nov 2026 |
| 9 | FM27 match engine: Pressure 1 costs about 0.15 xPts a game (about 6 points a season). Professionalism, ambition, loyalty and adaptability have no measurable in-match effect. caiograco's summary says Dirtiness and Temperament "change cards but not results", and his list of small effects puts Temperament 1 at about half a card a game. Full tables are in study 11 of his Fm-Match-Lab repository. | [FM27-DATA] | caiograco, FM-Arena, "FM27 match engine: what we know so far", 13 Nov 2026\[16\] |
| 10 | FM24: Pressure 1→18 changes win rate by 27.1%, of which 18.2% comes in the 1→6 band. | [CARRY-OVER] [data] | FM-Arena thread 18466 (FM24/FM26)\[17\] |
| 11 | In harvestgreen22's training-only tests (age 20, matches banned), Professionalism 20 roughly doubled seasonal CA growth over Professionalism 10: an average maximum of 12.5 CA against 6.5 CA a season. | [CARRY-OVER] [data] | harvestgreen22, FM-Arena thread 13508 ("Training is Fake…", FM24; another poster reports the same in FM26) |
| 12 | Professionalism 6/12/18 → 60/55/50 matches to learn a new position (age 22). | [CARRY-OVER] [data] | FM-Arena thread 18466\[17\] |
| 13 | FMRTE 27 has a data-grid column picker and a "Joined Club" column. Squad, staff and search lists are column grids.\[18\]\[19\] | [OFFICIAL] (tool vendor) | FMRTE 27 for Windows changelog, fmrte.com, builds 1–12, Oct–Nov 2026\[20\] |
| 14 | FMRTE 27 grid columns for hierarchy, social group, mentoring group, traits or personality label: not confirmed. | gap | FMRTE 27 docs and changelog, checked Nov 2026 |

## 1. Does mentoring exist in FM27, where is it, and what changed?

**Exists: yes, but only third-party sources confirm it.** I found no official SI FM27 feature page or manual entry on mentoring. The FM27 Touchline guide (updated 2 Nov 2026) says to open Training and find the squad's Mentoring view. It also says that SI's most recent published desktop explanation is FM24's and that FM27 weights, age cut-offs and timing are unmeasured [SPECULATION].\[14\] The FMRTE 27 changelog has no mentoring-related entries.

**What changed in FM27 (official, indirect):** SI rebuilt training. Training is now a primary nav area, and the old Units system was replaced by next-match preparation. Individual training of attributes, traits and positions continues [OFFICIAL, footballmanager.com FM27 Training & Tactical Effectiveness, 2026].\[9\]\[10\]\[11\] This matters because the FM19–FM24 guidance said influence was "further boosted" when players shared a mentoring group *and* a training unit [CARRY-OVER]. With Units gone, that boost either no longer exists or works differently. Nobody has documented which.

**FM26:** The Unity-era FM26 bug tracker logged "Mentoring group editing broken": selecting players reset the group, and cancelled groups were created empty [FM26, SI bug tracker r28198].\[21\] FM26 views also launched without a Personality column, reported as bugs.\[22\]\[23\]\[24\] Treat FM26-era community folklore cautiously. Mobile reports (FMM26) that a developer "reduced" mentoring effects apply to the mobile game, not desktop [CARRY-OVER, fmmvibe.com].\[25\]

**FM24 baseline:** Groups of at least three, assistant can auto-assign, influence ongoing but capped [OFFICIAL FM24 manual].\[1\]

## 2. Group rules

| Rule | What is known | Label |
|---|---|---|
| Minimum size | 3 | [CARRY-OVER] [OFFICIAL] FM20–FM24 manuals |
| Maximum size | No official figure. FM26 UI shows "3/3 Selected" in one bug report, so a group cap may exist in the UI, but its value for FM27 is unknown.\[21\] | [SPECULATION] |
| Number of groups | No official limit documented. | gap |
| Same squad only | Yes. Players must be in the same squad (first team, U21 or U18). A first-teamer cannot mentor a U18 player unless one is moved.\[2\] | [CARRY-OVER] [OFFICIAL] (SI staff, FM23)\[4\]\[26\]\[27\] |
| On loan | No source. Logically excluded because the player leaves the squad; Touchline advises rebuilding when a mentee goes on loan.\[14\] | [SPECULATION] |
| Injured | No source. | gap |
| New signings | Eligible once in the squad. "Welcome to club" acts as a short one-on-one mentoring (personality only, no traits).\[2\] | [CARRY-OVER] (SI-verified guide)\[28\]\[29\] |
| Must train together | Pre-FM27: same squad required, with a boost if also in the same training unit. FM27 removed Units, so it is unknown. | [CARRY-OVER] / gap\[4\] |

## 3. What changes

- **Personality attributes:** Determination (visible) plus the hidden professionalism, ambition, loyalty, pressure, temperament, sportsmanship and controversy move towards the influencing player's values. Adaptability is not named in any mentoring source. [CARRY-OVER]\[6\]\[30\]
- **Direction:** Towards the influencer, so changes can be negative. A low-determination captain "could drag down" mentees, and a high-determination player was observed losing determination in a group with weaker influences. [CARRY-OVER, SI guide pages 3 and 7]\[31\]\[32\]
- **How much and how fast:** No measured figure exists. Forum estimates are "a point or 2 by season" and "it might take 1-2 seasons to move … 1-2 points". These are unsourced anecdotes [SPECULATION, SI guide p.12; FM-Arena thread 3218].\[15\] One reported example: a mentee went from 5 to 6 determination after four months in a "significant influence" group.\[8\]\[33\] Since FM21, each shift touches a random subset of attributes; one veteran reports seeing up to five change at once, never all [CARRY-OVER, community].\[5\]\[6\]
- **Consistency:** Claimed not mentorable and to rise with age from about 22 (FM-Arena 8940). This is an opinion, not a test [SPECULATION].\[34\]
- **Traits (PPMs):** They transfer more readily between players in similar positions and only if the mentee's attributes allow the trait. Unwanted traits can be picked up, because SI's position is that you cannot learn the mentality while ignoring the football habits [CARRY-OVER, SI guide p.2–3].\[27\]\[31\]\[35\] In FM27, traits can also be trained directly, and you can remove unwanted traits through individual training [OFFICIAL, FM27 training feature page; SI's trait-removal note is in FM27 Mobile material].\[10\]\[12\]\[36\]\[37\]

## 4. What decides the strength of the effect

| Factor | Evidence | Label |
|---|---|---|
| Hierarchy gap (mentor higher) | Named factor | [CARRY-OVER] SI-verified guide; FM24 manual ("importance within the squad")\[4\] |
| Social-group compatibility | Named factor ("how well they get along")\[1\] | [CARRY-OVER] [OFFICIAL] |
| Mentee age | Named factor, no hard cut-off ("no specific age limit") | [CARRY-OVER] |
| Mentee career first-team appearances | Named factor; fewer appearances means more receptive | [CARRY-OVER] |
| Mentor age | Named in FM24 manual\[1\] | [CARRY-OVER] [OFFICIAL] |
| Similarity "in profile" | FM24 manual: closer profile means more influence.\[1\] Undefined whether this means position, personality or nationality. | [CARRY-OVER] [OFFICIAL] |
| Time at club | Suggested by a guide author, not in the official factor list | [SPECULATION] |
| Reputation | Not in any official list | [SPECULATION] |
| Shared position | Matters for traits, not shown to matter for personality | [CARRY-OVER] |
| Nationality | No source; may act through social groups | [SPECULATION] |
| Target: average or most influential? | The game shows per-player influence ("significant", "some", "light"), and guides say "it's all about who influences the unit". This implies a pull towards the most influential members, not the group mean. | [CARRY-OVER] (inference)\[32\] |
| More mentors | Untested. "Less people the more effective" is an opinion.\[8\] | [SPECULATION] |
| Mentor dragged down | Possible, if the scoring factors favour it | [CARRY-OVER] |
| Cap | "There will be a point where the return has been maximised"\[1\] | [CARRY-OVER] [OFFICIAL] |
| Squad-wide influence | Players are influenced by squad personality and social groups even without mentoring\[5\]\[38\] | [CARRY-OVER] |

## 5. What is each attribute worth?

| Attribute | Development effect | Match effect (FM27) | Verdict |
|---|---|---|---|
| Professionalism | Strong. 20 vs 10 gives about 2× training-only CA growth [FM24/FM26 data, thread 13508].\[39\] A decompiled FM24 formula shows step changes at ≥15 and 6–14 [FM24, thread 20900].\[40\] Faster position learning [thread 18466]. 12→20 adds less than 1→12 [FM24/FM26 summary thread 15934]. | None measured [FM27-DATA] | **Top target**\[17\]\[39\]\[41\] |
| Ambition | Contributes with professionalism in old tests [thread 2671].\[42\] Diminishing above about 10 per secondary guides. | None measured [FM27-DATA] | Target to about 10\[30\]\[42\] |
| Determination | Contributes; community claims are equivalent to modest professionalism gains (not cleanly tested)\[43\] | GK campaign: no effect | Target to about 10\[16\] |
| Pressure | Not shown | **Pressure 1: −0.15 xPts a game** [FM27-DATA]. FM24: most of the effect is between 1 and 6. | Fix if below about 6\[16\]\[17\] |
| Temperament | None shown | Cards only, no result effect [FM27-DATA] | Low priority\[16\] |
| Loyalty, Adaptability | None shown | None [FM27-DATA] | Ignore for value\[16\] |
| Sportsmanship, Controversy | None tested | Sportsmanship none in GK campaign; controversy untested | Ignore (controversy may matter for media and morale, untested)\[16\] |

Caveat on the FM27 data: caiograco's tests run FM27's own engine outside the game on paired seeds, with a t≥3 significance threshold, measuring xPts. The no-effect result means "no effect inside a match". Effects through morale, happiness, training or transfers are explicitly outside what the tool can see.\[16\]

## 6. Costs and risks

- **Negative drift:** Mentees and even mentors can move the wrong way [CARRY-OVER].\[4\]
- **Squad placement:** Promoting youths to the first team just to mentor them can disrupt dynamics and cost minutes [CARRY-OVER, FMInside; Touchline FM27].\[14\]\[44\]
- **Silent endings:** Loans, transfers or moves to another squad remove the player. In FM26, editing groups could silently empty them [FM26 bug].\[21\] No FM27 confirmation either way.
- **Morale and dynamics costs of mentoring itself:** No source documents any.

## 7. Other routes to personality (for comparison)

The squad's overall personality and team leaders influence players without mentoring [CARRY-OVER].\[4\] Contract complacency, off-field events and completed targets also move personality [community, SI forum thread 590289].\[5\] The Head of Youth Development's personality shapes newgens. Operation Sports' Asad Khan reports an FM26 analysis of 800 newgens by Reddit user Real-Computer4320, run with five identical clubs in an Anguilla test league. In it, a HoYD with professionalism below 16 never produced a newgen above 15, and even a HoYD with 20 capped newgens at 18 [FM26 data]. Recruiting good personalities is repeatedly described as more reliable than fixing bad ones [FM-Arena 14187, opinion].\[45\]

## 8. Data the tool needs

| Field | Why | FMRTE 27 grid column? |
|---|---|---|
| Hidden personality attributes, determination, age, CA/PA | Outcome variables and mentee age | Already in your grid. FMRTE 24 allowed hidden attributes as columns; FMRTE 27 is presumed the same. |
| Joined club date | Proxy for time at club | **Yes: "Joined Club"** (FMRTE 27 changelog)\[18\]\[19\]\[20\] |
| Squad hierarchy / influence | Key factor | **Not confirmed.** Copy from in-game Dynamics. |
| Social group | Key factor | **Not confirmed.** Copy from Dynamics. |
| Career first-team appearances | Key mentee factor | Not confirmed. FMRTE 27 has read-only player statistics on the player page.\[19\]\[20\] |
| Traits (PPMs) | Risk of unwanted transfer | Not confirmed as column; player page has positions and preferred moves\[46\] |
| Existing mentoring groups | Ground truth | Not confirmed; no FMRTE changelog entry. Copy from the game. |
| Personality label | Sanity check | Not confirmed |
| Relationships | Compatibility | Player page only, confirmed in docs\[47\] |

Verify each by opening FMRTE 27's column picker; the docs page listing columns could not be retrieved.

## Model the tool can compute

No per-month numbers exist, so the model is a structure with priors to be replaced by your own estimates.

For mentee *m* in group *G*, attribute *a*, per month:

E[Δa_m] = p_shift(m,G) × q × Σ_k w_k(m) × (a_k − a_m) / Σ_k w_k(m)

- **w_k(m)** is the influence weight of member *k* on *m*. Base it on the hierarchy gap (k above m), social-group match, k's age, and k's squad importance. Set w = 0 when k is below m in the hierarchy. [Factors CARRY-OVER; functional form SPECULATION]
- **p_shift** is the monthly probability of a shift event. It rises when *m* is younger and has fewer career appearances, and is capped after a long tenure. Prior: about 0.1–0.3 a month, drawn from the anecdotal "1–2 points per season". [SPECULATION]
- **q** is the share of attributes touched per event. Prior: 0.3–0.5, from "random subset" reports. [SPECULATION]
- Step size: ±1 per event. [SPECULATION; matches observed single-point moves]
- Apply the same formula in reverse to mentors with low hierarchy to flag drag-down risk.
- Value per point: weight professionalism highest, pressure below 6 next, ambition and determination below 10 next, and others at zero. [Labels in section 5]

**Grouping rules:**
1. One clear top-hierarchy mentor per group, whose values exceed every mentee's on each target attribute. Never include a member who is worse on professionalism or pressure than any mentee.
2. Mentees: youngest, fewest appearances, lowest professionalism or pressure below 6.
3. Keep groups small (3–4) until your own data says otherwise; this is an untested opinion.\[8\]
4. Same squad and same social group where possible. Same position only if the mentor's traits are wanted.
5. Re-evaluate monthly. Regroup when a mentee stops moving for 3+ months (cap reached), after transfers, loans or squad moves, or when a mentor's values drop.

## Evidence gaps and a test you can run

**Gaps:** Official FM27 mentoring rules, the maximum group size, the number of groups, eligibility of loaned and injured players, the effect of removing Units, per-month rates, group-size effects, and FMRTE 27 column availability.

**Test design (save-branching, the strongest design available):**
1. Save game at date T0. Import all personality attributes.
2. Branch A: your mentoring groups. Branch B: identical, but groups disbanded. Sim 6 months each, without editing, importing monthly.
3. Reload T0 and repeat each branch 5+ times. Random seeds differ between runs, so the repeats give you variance.
4. Estimate, per attribute, Δ(A) − Δ(B) per month for mentees, mentors and non-members. Regress on hierarchy gap, age, appearances and social-group match to fit w and p_shift.
5. Variant runs: group size 3 vs 6; one mentor vs two; mentee aged 17 vs 21.

With about 20 mentees × 5 replicates × 6 months you should detect monthly effects of about 0.1 points. Smaller effects than that are practically irrelevant anyway.

## Caveats

FM27 has been out for days. All rules except the training redesign come from FM19–FM24 sources. The FM27 match-engine data is a single community tester working outside the game, and it is a few days old. Development figures are from FM24 and FM26.

## Sources

1. [Training - Football Manager 2024 Touch and Console Edition - Sports Interactive Community](https://community.sports-interactive.com/sigames-manual/football-manager-2024-touch-and-console/training-r4984/)
2. [Explain Training to me](https://fm-base.co.uk/threads/explain-training-to-me.160305/)
3. [Adding youth players to training unit - they still don't pop up on the "add players" list when you want to put them in a mentoring group - Medical and Development Centre, Training and Finances](https://community.sports-interactive.com/bugtracker/previous-versions/football-manager-2023-bugs-tracker/757_medical-and-development-centre-training-and-finances/adding-youth-players-to-training-unit-they-still-dont-pop-up-on-the-add-players-list-when-you-want-to-put-them-in-a-mentoring-group-r10022/)
4. <https://community.sports-interactive.com/forums/topic/452839-the-unofficially-official-training-and-mentoring-guide/>
5. [Why does my player randomly worsens his Determination attribute? - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/590289-why-does-my-player-randomly-worsens-his-determination-attribute/)
6. [The Unofficially Official Training and Mentoring Guide - Page 13 - Tactics, Training & Strategies Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/452839-the-unofficially-official-training-and-mentoring-guide/page/13/)
7. [Why does my young Unambitious player not change literally anything from Mentoring? - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/590862-why-does-my-young-unambitious-player-not-change-literally-anything-from-mentoring/)
8. [The Unofficially Official Training and Mentoring Guide - Page 12 - Tactics, Training & Strategies Discussion - Sports Interactive Community](https://community.sigames.com/forums/topic/452839-the-unofficially-official-training-and-mentoring-guide/page/12/)
9. [FM27 New Features Guide: Everything New in Football Manager 2027](https://www.fmscout.com/a-football-manager-2027-new-features.html)
10. [FM27: Training and Tactical Effectiveness](https://www.footballmanager.com/fm27/features/fm27-training-and-tactical-effectiveness)
11. [Football Manager 27 Deepens Training, Tactics, and Player Growth](https://www.techbarrista.com/football-manager-27-training/)
12. [FM27: Training and Tactics New System - sortitoutsi.net News - FM27 - Football Manager 27](https://sortitoutsi.net/content/77912/fm27-training-and-tactics-new-system)
13. [FM27 Training: What Sports Interactive Has Confirmed](https://footballgpt.co/fm/fm27/training)
14. [FM27 Mentoring Guide: Groups, Personality & Influence | Football Manager 2027](https://touchlinefm.com/guides/mentoring)
15. [The Unofficially Official Training and Mentoring Guide - Page 12 - Tactics, Training & Strategies Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/452839-the-unofficially-official-training-and-mentoring-guide/page/12/)
16. [FM27 match engine: what we know so far](https://fm-arena.com/threads/fm27-match-engine-what-we-know-so-far.122/)
17. <https://fm-arena.com/thread/18466-fm24-consistency-important-matches-pressure-fm24-fm26-how-to-develop-positional-proficiency/>
18. [Football Manager 27](https://www.fmrte.com/files/category/54-football-manager-27/)
19. [FMRTE for macOS - Football Manager 27 - FMRTE](https://www.fmrte.com/files/file/185-fmrte-for-macos/)
20. [FMRTE 27 for Windows](https://www.fmrte.com/files/file/183-fmrte-27-for-windows/)
21. [Mentoring group editing broken - Newgen Development & Training - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/1887_newgen-development-training/mentoring-group-editing-broken-r28198/)
22. [Can't add Personality or Media Handling Style columns - Recruitment UI Issues - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/user-interface/2166_advanced-access-betas-ui-issues/2077_recruitment-ui-issues/cant-add-personality-or-media-handling-style-columns-r25175/)
23. [Unable to add personality in the ‘recruitment’ menu - General UI Issues - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/user-interface/2166_advanced-access-betas-ui-issues/2074_general-user-interface-issues/unable-to-add-personality-in-the-recruitment-menu-r36173/)
24. [Cannot add Personality to the custom squad view - Squad UI Issues](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/user-interface/2166_advanced-access-betas-ui-issues/2076_squad-ui-issues/cannot-add-personality-to-the-custom-squad-view-r27138/)
25. [Has mentoring changed with FMM26? - Football Manager 26 Mobile - FMM Vibe](https://fmmvibe.com/forums/topic/51171-has-mentoring-changed-with-fmm26/)
26. [Mentoring On FM19 - Tactics, Training & Strategies Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/469309-mentoring-on-fm19/)
27. [Mentoring on FM19](https://emufm.wordpress.com/2019/03/28/mentoring-on-fm19/)
28. [The Unofficially Official Training and Mentoring Guide - Page 2 - Tactics, Training & Strategies Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/452839-the-unofficially-official-training-and-mentoring-guide/page/2/)
29. [The Unofficially Official Training and Mentoring Guide - Page 10 - Tactics, Training & Strategies Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/452839-the-unofficially-official-training-and-mentoring-guide/page/10/)
30. [FM Dossier — Football Manager Scouting & Squad Tool for FM26 and FM27](https://fmdossier.dev/guides/personality-and-development)
31. [The Unofficially Official Training and Mentoring Guide - Page 3 - Tactics, Training & Strategies Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/452839-the-unofficially-official-training-and-mentoring-guide/page/3/)
32. [The Unofficially Official Training and Mentoring Guide - Page 7 - Tactics, Training & Strategies Discussion - Sports Interactive Community](https://community.sigames.com/forums/topic/452839-the-unofficially-official-training-and-mentoring-guide/page/7/)
33. [Mentoring](https://fm-arena.com/thread/3218-mentoring/)
34. [Improving hidden attributes](https://fm-arena.com/thread/8940-improving-hidden-attributes/)
35. [The Unofficially Official Training and Mentoring Guide - Page 2 - Tactics, Training & Strategies Discussion - Sports Interactive Community](https://community.sigames.com/topic/452839-fm2019-the-unofficially-official-training-and-mentoring-guide/page/2/)
36. [FM27: More Influence At Your Fingertips - Football Manager Mobile General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/612822-fm27-more-influence-at-your-fingertips/)
37. [FMM27 Features: New Match Engine, xG and more - Football Manager 27 Mobile - FMM Vibe](https://fmmvibe.com/forums/topic/51781-fmm27-features-new-match-engine-xg-and-more/)
38. [Guide to Player Personalities on Football Manager](https://www.fmscout.com/a-guide-to-player-personalities-football-manager.html)
39. [Training is Fake, it just assigns attributes, not grows attributes: results based on a large number of tests](https://fm-arena.com/thread/13508-training-is-fake-it-just-assigns-attributes-not-grows-attributes-results-based-on-a-large-number-of-tests/)
40. [Some training and development conventional wisdom for FM24](https://fm-arena.com/thread/20900-some-training-and-development-conventional-wisdom-for-fm24/)
41. [Summary of recent findings for optimal play in FM24 & FM26](https://fm-arena.com/thread/15934-summary-of-recent-findings-for-optimal-play-in-fm24-amp-fm26/page-3/)
42. [Player Development and Training](https://fm-arena.com/thread/2671-player-development-and-training/)
43. [Summary of recent findings for optimal play in FM24 & FM26](https://fm-arena.com/thread/15934-summary-of-recent-findings-for-optimal-play-in-fm24-amp-fm26/page-2/)
44. [Player Personalities in Football Manager - FMInside Football Manager Community](https://fminside.net/guides/positional-guides/30-player-personalities-in-football-manager)
45. [Advice Needed for Maximizing Youth Development in FM](https://fm-arena.com/thread/14187-advice-needed-for-maximizing-youth-development-in-fm/)
46. [Transferring players | FMRTE Documentation](https://docs.fmrte.com/players/transfers/)
47. [Editing coaches and staff](https://docs.fmrte.com/staff-and-managers/staff/)
