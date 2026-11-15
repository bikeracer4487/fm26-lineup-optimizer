# Does Playing a Player Make AI Clubs Bid for Him or Ask to Loan Him in FM27?

**Nobody knows, and nobody has tested it. I found no controlled test in FM27, FM26, FM24 or any older version that counts clubs interested, offers received or time to first offer for played players against unplayed ones.** Sports Interactive has never said that appearances or average rating feed AI shortlists. What SI has said points to reputation, form (FM24), squad gaps, tactical fit, potential, and (new in FM27) experience and leadership. My best estimate is a small effect at most, carried indirectly through reputation and form. I hold that with low confidence. Your lineup tool should not spend results on "shop window" minutes. At most it should use them to break ties between near-equal players.

## TL;DR
- **Unknown, low confidence that any effect is large.** I found no test in any FM version comparing transfer or loan interest for played and unplayed players. The only played-vs-unplayed test (FM-Arena) measured development, not interest. The belief that "minutes put him in the shop window" is repeated advice, not tested fact.
- **What SI says drives AI targeting:** form and reputation "more so than ever before" plus squad-gap and tactical-fit shortlisting (FM24), and experience and leadership in shortlists (FM27). Each club's scouting knowledge also limits whom it can see. Appearances as such are never named. One SI community-team member rejected a bug report claiming that high average ratings don't produce offers without high CA and reputation, but he gave no mechanism.
- **For your tool:** ignore shop-window minutes as an objective. Give minutes to players you want to sell or loan only when the cost to results is near zero, preferring league starts. Then settle the question with a save-reload A/B test of about 5 players × 5 reloads per arm over roughly 8 league matches plus the first 4 weeks of the window.

## Key Findings

| # | Finding | Label | Source & date |
|---|---|---|---|
| 1 | No controlled test in any FM version compares clubs interested, offers or time to first offer for played vs unplayed players | [SPECULATION]: absence of evidence after a targeted search | Searches of FM-Arena, SI forums, Steam, FM Scout, sortitoutsi; 14 Nov 2026 |
| 2 | The only played-vs-unplayed controlled test measured development: a 76-match season, Group 1 played all matches, Group 2 none, Group 1 gained +2.7 CA (players aged 21, PA 160, Professionalism 5)\[1\] | [CARRY-OVER]: version not stated in the thread | fm-arena.com/thread/2671-player-development-and-training (date not shown) |
| 3 | FM27: target shortlists of AI managers and Directors of Football "re-evaluated" to prioritise experience and leadership in the dressing room | [OFFICIAL] | footballmanager.com/fm27/features/deeper-more-immersive-world, 25 Sep 2026\[2\] |
| 4 | FM27: agent offers are visible throughout the window and ramp up toward Deadline Day; young players weigh game time more when choosing a move; sell-on fees raise asking prices | [OFFICIAL] | Same FM27 deep dive, 25 Sep 2026\[3\] |
| 5 | FM27: "You'll also see AI managers be a little more lenient when they're looking to recall a loanee" | [OFFICIAL] | footballmanager.com/fm27/features/fm27-2d-match-engine-game-editor-and-deeper-world-upgrades, Oct 2026 |
| 6 | FM27 first post-launch update, "set to arrive later this month", is expected to include "AI transfer behaviour tweaks"; FM27 transfer AI is still changing | [OFFICIAL] | SI forum post "Details on FM27 Launch, Patch Notes, and First Post-Launch Update" (community.sports-interactive.com topic 612924), 9 Nov 2026 |
| 7 | FM26 Update 26.1.2 notes include "Tweaks to player reputation boosts following matches" and say users offering a player via an Intermediary "should receive more appropriate offers from AI Clubs". This is an FM26 patch note, not an FM27 launch note | [CARRY-OVER] (FM26) [OFFICIAL] | SI Community Featured Content, "FM26 Update (26.1.2) Out Now" |
| 8 | FM24: AI managers "consider factors like form and reputation more so than ever before"; they shortlist to fill attribute gaps and suit their tactical style; they prefer PA over CA for backup/rotation slots | [CARRY-OVER] (FM24) [OFFICIAL] | footballmanager.com/features/smarter-transfers-squad-building-and-finance, 19 Sep 2023\[4\] |
| 9 | FM24: interest is classed "Active" or "Rumoured", with a contextual reason shown (e.g. not first-choice target = Rumoured); "Offer via TransferRoom" is "not an instant option" | [CARRY-OVER] (FM24) [OFFICIAL] | footballmanager.com/features/introducing-intermediaries-and-offloading-players, 21 Sep 2023\[5\] |
| 10 | FM26 TransferRoom Requirements specify position, role, playing time, age and transfer type; you can offer surplus players against them | [CARRY-OVER] (FM26) [OFFICIAL/partner] | blog.transferroom.com (FM26 article), Oct 2025\[6\] |
| 11 | SI community-team member, replying to "AI clubs not interested in high average rating players if they don't have high CA and reputation": "I wouldn't really agree with this personally. We would need a save file…" | [CARRY-OVER] (FM24) [OFFICIAL]: opinion, no data | SI bug tracker r22950, FM24 Early Access (late 2023)\[7\] |
| 12 | "Clubs with no scouting range are restricted to only those players known by members of staff"; club knowledge comes from staff, region and affiliates | [CARRY-OVER] (FM24) [OFFICIAL]: written for the human club | SI FM24 manual, Transfers, Recruitment and Scouting\[8\] |
| 13 | FM26 known issue: a player shown as "interested" in a loan then rejects it | [CARRY-OVER] (FM26) [OFFICIAL] | SI bug tracker r26593, 24–26 Oct 2025\[9\] |
| 14 | FM26 patch 26.1.0: "Tweaks made to AI clubs loan offers… only make offers they can afford" | [CARRY-OVER] (FM26) [OFFICIAL] | fmscout.com/a-fm26-update-26.1.0.html\[10\] |
| 15 | User anecdote: "Players that have barely played will be hard to sell, as the AI looks at recent performances" | [SPECULATION] | SI forum topic 576963 (FM24 era)\[11\] |
| 16 | User anecdote against: loaning players out to generate interest "never really seen it work… players either have a lot of interest or they have none"; wages too high for CA may exclude them from AI shortlists | [SPECULATION] | SI forum topic 600462 (FM26 era)\[12\] |
| 17 | User anecdote against: Hungarian league winners and Europa League semi-finalists got "measly offers for precisely one player" | [SPECULATION] | SI forum topic 554509 (version not stated)\[13\] |
| 18 | FM26 AI targeting is pattern-driven: the same AI moves recur across saves (e.g. Lobotka to Newcastle in 5 of 5 holiday saves) | [CARRY-OVER] (FM26), n = 5 saves | sortitoutsi.net/content/76014\[14\] |
| 19 | EA FC 27 (a different game) explicitly uses goals, assists, average ratings and clean sheets in AI targeting. SI has made no such statement for FM | Context, not FM evidence | ea.com FC27 Career Mode deep dive, 2026\[15\] |

## Q1: How do AI clubs choose transfer and loan targets in FM27?

**What is official for FM27:** SI says this year's work is "part of a wider focus into transfers and transfer AI behaviour," and that the target shortlists of AI managers and Directors of Football "have been re-evaluated to better account for how they prioritise experience and leadership in the dressing room" [OFFICIAL, 25 Sep 2026].\[2\]\[16\]\[17\] Agent offers now appear on the Recruitment screen all window and ramp up toward Deadline Day.\[2\] Clubs ask more for players with sell-on fees.\[18\] Young players weigh game time more when deciding where to go [OFFICIAL].\[2\]\[16\] In its forum post "Details on FM27 Launch, Patch Notes, and First Post-Launch Update" (9 Nov 2026), SI said it expects the first post-launch update, "set to arrive later this month", to include "AI transfer behaviour tweaks" [OFFICIAL]. So FM27 transfer AI is still being changed. Anything measured on 27.0.x may shift.

**Likely carried over from FM24 and FM26:** AI managers weigh "form and reputation more so than ever before." They spot imbalances in their squad and shortlist to fill attribute gaps that suit their tactical style, and they lean on PA for backup and rotation slots [CARRY-OVER FM24, OFFICIAL].\[4\]\[19\]\[20\] Interest is split into Active and Rumoured, with a reason shown [CARRY-OVER FM24, OFFICIAL].\[5\] FM26 added TransferRoom Requirements and Pitch Opportunities. AI clubs post adverts specifying position, role, playing time, age and loan or transfer, and you can pitch surplus players directly against them [CARRY-OVER FM26, OFFICIAL/partner].\[6\] TransferRoom is still in FM27 [FM Scout, 21 Oct 2026].\[18\]

**Scouting knowledge:** the FM24 manual says a club's knowledge comes from its staff, region and affiliates, and that clubs with no scouting range see only players known to their staff [CARRY-OVER FM24, OFFICIAL].\[8\] It is written for your own club. SI does not say outright that AI clubs face the same limit, though users widely assume so [SPECULATION].

**Not supported by any official source:** a direct input from appearances, minutes or average rating. "Form" is named (FM24), but SI has never said how it is computed. It may come from recent match ratings, but that is inference. SI's FM26 Update 26.1.2 notes list "Tweaks to player reputation boosts following matches", which confirms that matches raise reputation in FM26 [CARRY-OVER FM26, OFFICIAL]. That is the most plausible channel: matches raise reputation, and reputation feeds AI interest. Nobody has measured how much it shifts AI interest, or whether it carries into FM27 unchanged [SPECULATION].

**Agent and TransferRoom activity:** asking the agent about market interest, hiring an intermediary, or offering via TransferRoom actively creates or surfaces interest, but with delay.\[5\] Users measured about a week for TransferRoom responses in FM24 [CARRY-OVER FM24, user report, fm-arena thread 11760].\[21\] These are the levers SI built specifically for selling players [OFFICIAL FM24].\[5\] Transfer status (listed vs unlisted) changes price more clearly than it changes interest [SPECULATION/user consensus].\[13\]\[22\]\[23\]

## Q2: Does a starter attract more interest or offers than the same player left out?

**No test exists.** I found no controlled comparison in FM27, FM26, FM24 or any older version that counts interested clubs, offers or time to first offer for played vs unplayed players. A dedicated subagent search reached the same conclusion. One gap remains: I could not search YouTube video content or Reddit directly, so an untranscribed video test cannot be ruled out.

What exists instead:
- **The right design, applied to the wrong outcome.** FM-Arena's development test ran 76 matches with one group playing every match and one playing none. It measured CA growth (+2.7 CA for the played group in Test 1) [CARRY-OVER].\[1\] It shows a played-vs-unplayed design is feasible, but it says nothing about interest.
- **Anecdotes for an effect:** "Players that have barely played will be hard to sell, as the AI looks at recent performances" (SI forum, FM24 era). "If they're barely playing… you'll have few clubs interested" (Steam, FM24) [SPECULATION].\[11\]\[24\]
- **Anecdotes against an effect:** loaning players out to build interest "never really seen it work"; Hungarian title winners and Europa League semi-finalists drew one offer; "Even championship topscorers never got an offer" (FM24) [SPECULATION].\[12\]\[13\]\[25\]
- **One SI community-team opinion.** Zachary Whyte disagreed with the claim that high average rating without high CA and reputation draws zero offers, and asked for a save file [CARRY-OVER FM24, OFFICIAL opinion].\[7\] That suggests ratings are not ignored. It is not data.

My reading: the anecdotes cancel out. The repeated advice ("minutes = shop window") is plausible because FM24's stated inputs include form and reputation, but its size is unknown and may be swamped by CA, wage, age, contract and price. That fits your earlier finding that playing time does little to the fee.

## Q3: If it matters, what counts?

**Nothing tested.** No source separates starts from substitute appearances, league from cup matches, or recency. None tests whether a poor average rating cancels the effect. Operation Sports' FM24 selling guide says a player "constantly putting up match ratings that are below the 6.7 threshold" probably won't "move the needle too much in terms of their value on the transfer market" [SPECULATION]. That claim is about transfer value, not AI interest, and it cites no test. If the mechanism is form and reputation, then starts in competitive league matches at the highest-reputation level available should matter most, and a run of poor ratings could hurt rather than help. That is reasoning, not evidence [SPECULATION]. FM24's official wording ("form") at least implies quality of performance counts, not just presence.

## Q4: Loan interest

**No evidence that AI loan offers depend on the loanee's match fitness or recent minutes.** SI's documented loan changes are about other things. FM24 brought "considered and contextual decisions concerning loans for young players," focused on the AI loaning out its own youngsters [CARRY-OVER FM24, OFFICIAL].\[4\]\[19\] FM26 patch 26.1.0 tweaked AI loan offers and affordability [CARRY-OVER FM26, OFFICIAL].\[10\] In FM27, SI's 2D match engine and In-Game Editor deep dive says "You'll also see AI managers be a little more lenient when they're looking to recall a loanee" [OFFICIAL]. Loan demand has known bugs: a player flagged "interested" in a loan who then rejects it was a known issue in FM26 [OFFICIAL, Oct 2025], and FM23 users reported very low AI loan demand.\[9\]\[26\]

Two user observations bear on loans more than sharpness does [SPECULATION]:
- Players signed with a "regular starter" squad status may not want to go on loan, and you may get no loan bids for them (SI forum topic 600462).\[12\] Here a promise of minutes works against loanability.
- On FM26 Mobile, moving loan candidates to the B team and letting the assistant handle loans worked for one user and failed for another.\[27\]\[28\] This is not PC evidence.

Bottom line for loans: unknown. If anything constrains loan interest, the documented candidates are status and wage fit plus bugs, not match sharpness.

## Q5: Lower leagues

**Untested.** Officially, scouting range and knowledge limit which players a club "knows" [CARRY-OVER FM24, OFFICIAL].\[8\] In FM26, one user's interest filters showed nothing meaningful until they hired scouts [CARRY-OVER FM26, user report].\[29\] If AI clubs work the same way, a lower-league player's main barrier is being known at all, and minutes cannot help him reach clubs that have no knowledge of your league. One user believes "it can take time for teams in your league to gain scouting knowledge of the player" [SPECULATION].\[12\] The tools that reach past knowledge limits by design are TransferRoom Pitch Opportunities, intermediaries (whose reach is geographic, e.g. Continental Europe) and agent "market interest" chats [OFFICIAL FM24/FM26].\[5\]\[30\] That is where effort is better spent in lower leagues [SPECULATION based on official feature design].

## What the Lineup Tool Should Do

1. **Do not add a "shop window" objective.** Nothing tested supports trading points for exposure, and one known benefit of minutes, development, is small (+2.7 CA over a full 76-match season in FM-Arena's test).\[1\]
2. **Use it only as a tie-breaker.** When two options are within your tool's noise margin (say under 1–2% expected-points difference), prefer the player flagged for sale or loan, and prefer a league start over a cup start or a sub appearance. That follows from FM24's "form and reputation" wording and costs nothing [SPECULATION].
3. **Avoid shop-windowing a player in poor form.** If his recent ratings are low, extra minutes may hurt form-based interest [SPECULATION].
4. **Do not change squad-status promises to generate loans.** Users report "regular starter" players resist loans [SPECULATION].\[12\]
5. **Send selling effort outside the lineup.** Use agent market-interest chats, TransferRoom Pitch Opportunities and intermediaries, which SI built for this purpose [OFFICIAL].\[5\]\[6\]
6. **Leave a parameter slot open** (e.g. `shop_window_weight = 0`) and set it from your own test below.

## Cheapest Test to Settle It (Save-Reload A/B)

- **Players:** 5 surplus players in your squad, mixed positions, all willing to leave, with no injuries and no contract under 6 months.
- **Hold constant:** same save point, ideally about 6 weeks before the window opens. Keep the same transfer status (all unlisted, or all listed at the same price), the same squad status, no agent chats, no intermediaries and no TransferRoom pitches, so you measure organic interest. Use the same tactic and the same other XI. Don't touch wages or contracts.
- **Vary:** Arm A starts all 5 in every league match, about 8 matches. Arm B leaves all 5 out of the matchday squad. Run both arms from the same save, reloading for each run.
- **Reloads:** 5 per arm, giving 25 player-runs per arm. Paired comparison per player across arms.
- **Count per player:** clubs listed on the Transfer Status screen (Active vs Rumoured), transfer offers, loan offers, days from window opening to first offer, and offers in the first 4 weeks of the window. Also log average rating and reputation before and after, to test the mechanism.
- **Duration:** about 6 weeks of matches plus 4 weeks of the window, around 10 in-game weeks per run.
- **Decision rule:** if Arm A's mean offers per player exceed Arm B's by less than about 0.5, with overlapping spreads across reloads, set the weight to 0. If the gap is consistently larger, check whether it tracks average rating. If it does, weight minutes only for players likely to rate well.
- **Optional extension:** repeat with sub appearances only, or cup starts only, as a third arm. Retest after the first FM27 post-launch patch, because SI has flagged transfer-AI tweaks.

## Caveats
- FM27 is days old (launched 10 Nov 2026).\[31\] No FM27 community data exists yet, and SI has already announced transfer-AI tweaks.\[32\]
- I could not fetch SI forum pages directly, so some quotes come from search snippets without visible dates.
- The "Tweaks to player reputation boosts following matches" note is verified, but it comes from FM26 Update 26.1.2, not FM27. Whether FM27 keeps the same reputation-after-matches behaviour is unconfirmed.
- EA FC 27 explicitly uses league stats in AI targeting.\[15\] Don't let FC 27 coverage be mistaken for FM evidence.

## Sources

1. [Player Development and Training](https://fm-arena.com/thread/2671-player-development-and-training/)
2. [Football Manager 27 Features: The Most Significant Changes & Improvements for FM27 • Passion4FM](https://www.passion4fm.com/football-manager-27-features/)
3. [Football Manager 27 features explained: Deeper world, cup draws, transfer & more](https://khelnow.com/gaming/football-manager-27-features-explained-202609)
4. [Smarter Transfers, Squad Building and Finance](https://www.footballmanager.com/features/smarter-transfers-squad-building-and-finance)
5. [Introducing Intermediaries and Offloading Players](https://www.footballmanager.com/features/introducing-intermediaries-and-offloading-players)
6. [How TransferRoom’s shaping Football Manager recruitment in FM26](https://blog.transferroom.com/how-transferrooms-shaping-football-manager-recruitment-in-fm26)
7. [AI clubs not interested in high average rating players if they don't have high CA and reputation - All Other Issues - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/previous-versions/football-manager-2024-early-access-bugs-tracker/all-other-issues/ai-clubs-not-interested-in-high-average-rating-players-if-they-dont-have-high-ca-and-reputation-r22950/)
8. [Transfers, Recruitment, and Scouting - Football Manager 2024 - Sports Interactive Community](https://community.sports-interactive.com/sigames-manual/football-manager-2024/transfers-recruitment-and-scouting-r4962/)
9. [Player rejects loan even if they were 'interested' in the loan - Transfer, Scouting, Contracts & Intermediaries - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/1883_transfer-scouting-contracts-intermediaries/player-rejects-loan-even-if-they-were-interested-in-the-loan-r26593/)
10. [Football Manager 2026 Patch 26.1.0 - Hotfix Update for FM26](https://www.fmscout.com/a-fm26-update-26.1.0.html)
11. [How to get the biggest transfer fee for a player, and pay for the lowest for another clubs player? - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/576963-how-to-get-the-biggest-transfer-fee-for-a-player-and-pay-for-the-lowest-for-another-clubs-player/)
12. [Loaning Players Out To Generate Interest - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/600462-loaning-players-out-to-generate-interest)
13. [Generating player interest while playing in weaker leagues - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/554509-generating-player-interest-while-playing-in-weaker-leagues/)
14. [FM26: Which transfers do AI always make? - General Discussion - FM26 - Football Manager 26](https://sortitoutsi.net/content/76014/fm26-which-transfers-do-ai-always-make)
15. [EA SPORTS FC™ 27](https://www.ea.com/games/ea-sports-fc/fc-27/news/pitch-notes-fc27-career-mode-deep-dive)
16. [FM27: A Deeper, More Immersive Football World](https://www.footballmanager.com/fm27/features/deeper-more-immersive-world)
17. [Featured Content - Sports Interactive Community](https://community.sports-interactive.com/featured/)
18. [FM27 Transfers: What's New and How It Works | FM Scout](https://www.fmscout.com/a-fm27-transfers.html)
19. [What's New In FM24 - What's New in FM24 - Football Manager Graphics](https://footballmanagergraphics.com/blogs/entry/4-whats-new-in-fm24/)
20. [Football Manager 2024 New Features: Everything confirmed by Sports Interactive](https://realsport101.com/article/football-manager-2024-new-features)
21. [Is offer through Transfer room slower than offer out player from previous game versions?](https://fm-arena.com/thread/11760-is-offer-through-transfer-room-slower-than-offer-out-player-from-previous-game-versions/)
22. [Football Manager 2016](https://steamcommunity.com/app/378120/discussions/0/385428458162266706)
23. [How to manage transfers?](https://fm-arena.com/thread/12470-how-to-manage-transfers/)
24. [AI refuses transfer offers :: Football Manager 2024 General Discussions](https://steamcommunity.com/app/2252570/discussions/0/603020257754360005/)
25. [The transfer market has pretty much killed my interest in FM24 - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/585323-the-transfer-market-has-pretty-much-killed-my-interest-in-fm24/)
26. [Very low demand for loans, leads to poor development issues - Transfers and Contracts](https://community.sports-interactive.com/bugtracker/previous-versions/football-manager-2023-bugs-tracker/transfers-and-contracts/very-low-demand-for-loans-leads-to-poor-development-issues-r13351/)
27. [Transfer not working bug fix - Football Manager 26 Mobile - FMM Vibe](https://fmmvibe.com/forums/topic/50723-transfer-not-working-bug-fix/)
28. [youth listed for loan but no offer is coming - Football Manager 26 Mobile - FMM Vibe](https://fmmvibe.com/forums/topic/50561-youth-listed-for-loan-but-no-offer-is-coming/)
29. [Player Database "Player's interest" filter not activating - Recruitment UI Issues - Sports Interactive Community](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/user-interface/2170_recruitment-ui-issues/player-database-players-interest-filter-not-activating-r40295/)
30. [Football Manager 2026 Guide: Tactics & Transfers](https://www.switchbladegaming.com/football-manager/first-season-guide-2026/)
31. [FM27 launch patch notes and the first post-launch update - FMPortugal](https://fmportugal.net/en/fm27-patch-lancamento-primeira-atualizacao/)
32. [Football Manager 2027 Patch 27.0.1 - Update Beta to Final](https://www.fmscout.com/a-fm27-update-27.0.1.html)
