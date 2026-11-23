# Selling and loaning out players in FM27: does playing them first help, and is the "to sell / to loan" feature worth building?

No evidence shows that playing a player you plan to sell raises his fee in FM27. Nobody has published an FM27 test of it, and the best older evidence suggests the playing-time channel exists but is weak and slow. Reputation, contract length and how you put him on the market (listed or not) matter far more. Build the feature only as a small, capped tie-breaker, mainly for young players you plan to loan out or whose value depends on development. Do not build it as a lever for the fee.

## TL;DR

- **The hypothesis is mostly unproven and probably weak.** There is no FM27 test, and older community reports disagree. Playing time can only help a fee through a slow route: rating → form → reputation → value. Value is driven mainly by reputation bands set per nation in the database, plus contract length, club and league. How you sell him (transfer listing versus not, the agent's "Ask Agent About Market Interest" chat, which per SI reports his current market value and the most interested clubs, TransferRoom, intermediaries) and how long his contract runs move the fee much more [CARRY-OVER / SPECULATION].
- **Minutes help most through development, not price.** For players aged 18 and over, development comes mainly from first-team minutes. FM-Arena's reverse-engineering of FM24 found monthly "match points" are capped at 150, so playing beyond a point adds nothing. FM27 also makes young players weigh game time more when choosing a club, so promising and giving minutes matters for loans and contracts [OFFICIAL / CARRY-OVER].
- **Worth building only as a small, guarded rule:** a capped bonus in low-importance fixtures for players marked "to loan out" (age ≤ 23) or "to sell" who are short of sharpness. Turn it off when his ratings are poor, when a deal is agreed, or when the window shuts. Put most of the tool's effort into flagging the bigger levers: contract months left, transfer status and timing in the window.

## What FM27 actually shipped with (verified)

- **Release and versions.** FM27 released on 10 November 2026 on PC, Mac and consoles.\[1\]\[2\]\[3\] The 27.0.1 release-day update took the Launch Preview build to final, and SI said its first post-launch update, due "later this month", would include tweaks to how the AI handles transfers [OFFICIAL via FM Scout, 10 Nov 2026].\[4\] Any transfer behaviour measured on 27.0.1 may therefore shift within weeks.
- **Transfer changes against FM26:**
  - Transfer Deadline Day returns.\[5\]\[6\]\[7\]
  - Agent offers now appear on the Recruitment screen all window long, and SI says they "ramp up as it gets to the business end of the window".
  - SI's deep dive says young players "will now consider game time a lot more when looking at a transfer", so the "treat club as a stepping stone" promise carries more weight in contract talks.
  - Sell-on fees now show in Scout Reports, and SI says clubs "will want more money for those players".
  - AI managers and Directors of Football now prioritise experience and leadership.\[5\]\[7\]
  - New Squad Cost Ratio rules apply, and spending has been readjusted worldwide [OFFICIAL, SI deep dive "A Deeper, More Immersive Football World", Sept 2026].\[5\]\[7\]
- **TransferRoom and intermediaries.** TransferRoom is still in FM27, with a screen for agents. AI managers are "a little less strict" about recalling loanees. Monthly reports cover your young players out on loan. The Director of Football advises on fees and payment structures for transfers and loans [FM Scout summary of SI deep dives, 21 Oct 2026].\[7\]\[8\] An SI forum answer in the FM27 console FAQ says the console edition has no agents and intermediaries, which implies the PC/Mac edition keeps them [OFFICIAL-forum, FM27 console FAQ].\[9\] I found no source saying how intermediaries changed mechanically in FM27, so the FM24/FM26 description below is carried over.
- **FMRTE 27 on Mac.**
  - FMRTE 27 has a native macOS build that runs on Intel and Apple Silicon and no longer needs SIP turned off. It was at 27.0.1-build12 for FM 27.0.1 when checked.\[10\]\[11\]
  - The Windows and Mac changelogs list the same grid changes: a column picker, a transfer-status column fix and a fix for sorting by the "Loaned To Team" column.\[10\]\[12\]\[13\]
  - No FMRTE page states any difference in grid columns between the two builds.

## Key findings

| # | Finding | Label | Source (URL, date) |
|---|---|---|---|
| 1 | FM27 transfer AI changes: young players weigh game time more, sell-on fees raise AI asking prices, AI values experience and leadership, agent offers appear all window, Squad Cost Ratio | [OFFICIAL] | https://www.footballmanager.com/fm27/features/deeper-more-immersive-world (Sept 2026)\[5\]\[7\] |
| 2 | TransferRoom remains, loan recall is slightly less strict, monthly loan reports, DoF advises on fees | [OFFICIAL, secondary summary] | https://www.fmscout.com/a-fm27-transfers.html (21 Oct 2026)\[7\] |
| 3 | The 27.0.1 release-day patch shipped; the next update will tweak AI transfer handling | [OFFICIAL, secondary] | https://www.fmscout.com/a-fm27-update-27.0.1.html (10 Nov 2026)\[4\] |
| 4 | Value is anchored to reputation: the database sets value ranges per reputation band per nation, and one user's editor test gave a CA-10 player with maximum reputation a Messi-level value (n=1) | [CARRY-OVER] | https://community.sports-interactive.com/forums/topic/398864-player-value/ (pre-FM24, date not shown); https://community.sports-interactive.com/forums/topic/579647-player-valuations-still-make-no-sense-at-all-and-its-still-a-problem/page/2/ (FM24 era)\[14\] |
| 5 | Reputation and CA start aligned; reputation can outrun CA if a player performs well in a successful team | [CARRY-OVER] | SI forum, same thread as #4 (FM24 era)\[15\] |
| 6 | Asked whether more playing time raises market value, an experienced SI forum user answered "no" (opinion, not a test) | [CARRY-OVER] | https://community.sports-interactive.com/forums/topic/585056-playing-time-how-to-manage-best/ (FM24 era)\[16\] |
| 7 | Operation Sports' FM24 selling guide says a consistently played player's value "will gradually increase", yet concedes more minutes alone often won't raise it; it cites a 6.7 rating threshold (no data) | [CARRY-OVER, untested] | https://www.operationsports.com/how-to-sell-your-players-for-the-most-money-in-football-manager-24/ (FM24) |
| 8 | Transfer listing lowers perceived value and offers; unlisted players with time left on their contracts draw bids above asking | [CARRY-OVER, anecdotal] | https://sortitoutsi.net/content/75973/fm26-how-to-sell-players (FM26); https://community.sports-interactive.com/forums/topic/501798-whats-up-with-other-teams-lowballing-transfer-offers/ \[17\]\[18\]\[19\] |
| 9 | One FM26 bug report: TransferRoom offers came in at about 10% of value, and the displayed value then dropped to the offer | [CARRY-OVER, n=1 user report] | https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/1883_transfer-scouting-contracts-intermediaries/potential-market-issue-or-bug-r42816/ (FM26)\[20\] |
| 10 | Intermediary commission capped at 10%; better intermediaries find more and quicker interest; "ask agent about market interest" updates the displayed price tag for a limited time | [OFFICIAL, FM24 feature; carried into FM26/27] | https://www.footballmanager.com/features/introducing-intermediaries-and-offloading-players (21 Sep 2023)\[21\] |
| 11 | FM26 added TransferRoom Requirements and Pitch Opportunities | [OFFICIAL, FM26] | https://www.footballmanager.com/fm26/features/powered-transferroom-fm26s-recruitment-revamp (2025)\[22\] |
| 12 | FM26 patch 26.1.0 tweaked transfer values across nations and AI loan offers | [OFFICIAL, FM26] | https://www.footballmanager.com/blog summary at https://www.footballmanagerblog.org/2025/10/fm26-bug-fixes-hotfix-patch-notes.html (Nov 2025)\[23\] |
| 13 | Senior (21+) players get "basically all" development from playing time; monthly match points are clamped at 150; 45+ minutes earns extra; a 17-year-old earned 2.5× the points for a Premier League game compared with a U21 game (debugger study of one player) | [CARRY-OVER, FM24] | https://fm-arena.com/thread/20900-some-training-and-development-conventional-wisdom-for-fm24/ (2024)\[24\] |
| 14 | First-team minutes develop players more than reserve or youth football | [OFFICIAL, FM24 manual] | https://community.sports-interactive.com/sigames-manual/football-manager-2024/players-r4958/ \[25\] |
| 15 | In FM27, appearances count starts and sub appearances; very late subs get no rating; stats split into league, cups, continental and friendlies | [FM27-DATA, tool check on one save] | https://maclibero.com/blog/season-stats-tables/ (2026)\[26\] |
| 16 | Playing-time happiness tracks starts in competitive games, not sub appearances (e.g. Key Player ≈ 60% of starts) | [CARRY-OVER, FM19, community] | https://steamcommunity.com/app/872790/discussions/0/1777136225023141322 \[27\] |
| 17 | FMRTE 27 runs natively on Mac (Intel and Apple Silicon, no SIP); Mac build 27.0.1-build12 matches Windows grid changes | [FM27-DATA] | https://www.fmrte.com/files/file/185-fmrte-for-macos/ (Nov 2026); https://www.fmrte.com/ \[10\]\[11\] |
| 18 | FMRTE 27 grid: transfer status column confirmed; asking price is a player field (column unconfirmed); value, reputation, appearances, minutes, average rating and form not confirmed as grid columns (player-page stats only) | [FM27-DATA] | https://www.fmrte.com/files/category/54-football-manager-27/; https://docs.fmrte.com/players/statistics/ (Nov 2026)\[11\]\[12\]\[28\] |
| 19 | Lower league (FM24): one tier-6 sale for £100k + £70k add-ons + 20% sell-on, while players listed at £200–400k went for £20k | [CARRY-OVER, anecdotal n≈3] | https://steamcommunity.com/app/2252570/discussions/0/4029094770946930030 \[29\] |

## Q1. Does playing time change value, asking price or offers? Channel by channel

| Channel | Real? | Size | Evidence |
|---|---|---|---|
| **Reputation** (current/home/world) | **Yes, and it is the main driver of value** | Large, but it moves slowly through performances, honours and the club/league stage | Database value bands keyed to reputation; reputation can outrun CA when a player does well in a winning team [CARRY-OVER, findings 4–5]\[14\]\[15\]\[30\]\[31\] |
| **Appearances** | Indirect only | Small. Appearances feed ratings and visibility, which feed reputation | No test isolates appearances [SPECULATION] |
| **Average rating / form** | Plausible, short-lived | Small to moderate. Form is read from roughly the last five ratings and fades fast when he stops playing | SI forum users; guides claiming a ~6.7 rating threshold (untested) [CARRY-OVER]\[32\] |
| **Match sharpness** | No evidence it affects value | Probably none on the fee. It matters for how a loanee or new signing performs | No source links sharpness to value [SPECULATION] |
| **Playing-time happiness / morale** | Indirect, two-edged | An unhappy player can push for a move, which lowers his asking price when you are buying. When you are selling, unhappiness mainly causes trouble in the dressing room | SI forum: unsettling a player can lower AI asking prices [CARRY-OVER]\[33\] |
| **Development (CA growth)** | **Yes, for young players** | Real over a season or more, and capped per month | FM-Arena match points capped at 150; first-team minutes count most [CARRY-OVER, finding 13]\[24\] |

**My judgement:** the only playing-time effect on the fee that is large and well supported runs through development and reputation over months. In a window of a few weeks, extra starts in cup ties barely move a player's value. Evidence on the direct "minutes → value" link conflicts (finding 6 against finding 7). I trust the forum "no" slightly more for short horizons because it fits the reputation-band mechanism. Neither side has data.

## Q2. How much playing, and how soon?

- **Starts vs sub appearances.** Both count as appearances in FM27 stats. Very late sub appearances get no rating [FM27-DATA, finding 15].\[26\] Playing-time happiness is judged on starts in competitive games, and sub appearances are not counted [CARRY-OVER, FM19].\[27\]
- **Minutes.** FM26 guides say about 15 minutes earns a match rating and some development credit.\[34\]\[35\] FM-Arena's FM24 analysis gives extra credit at 45+ minutes [CARRY-OVER].\[24\]
- **Competition.** Stats are split into league, cups, continental and friendlies [FM27-DATA].\[26\] Development credit scales with match level: the senior game was worth 2.5× the U21 game for one tested player [CARRY-OVER].\[24\] No source shows friendlies building reputation, so treat them as worth roughly nothing for the fee [SPECULATION].
- **Ceiling.** Monthly match points are clamped at 150 in FM24, so past roughly a monthly quota, extra games add no development [CARRY-OVER].\[24\] No equivalent ceiling is documented for reputation.
- **Timing.** Form responds within about five matches.\[32\] Reputation and value respond over months and jump at honours or the season rollover [CARRY-OVER].\[36\]

## Q3. Can it backfire?

Yes, in three ways.
1. **Poor ratings.** A weak player starting against better sides will post low ratings. Low ratings hurt form and, if anything, reputation. Operation Sports' FM24 guide notes that ratings below about 6.7 do not help value [CARRY-OVER, untested].
2. **Results.** Each extra start for a below-par player is a weaker XI. In cup ties that still matter (for a National League club, the FA Cup proper and FA Trophy are among the biggest earners) this cost is real [SPECULATION].
3. **Listing and unhappiness.** GGRecon's FM24 selling guide calls transfer listing "the least likely way to sell a player" unless you list him well below value. Going over a reluctant player's agent to an intermediary can make him unhappy and disturb the dressing room [OFFICIAL FM24 feature text; CARRY-OVER].\[21\] Starting a player more often can also raise his expected playing time and wage demands at renewal [CARRY-OVER].\[16\]\[30\]

## Q4. Levers ranked by effect on the fee

1. **Reputation and club/league context:** the largest effect, but you cannot steer it in the short term [CARRY-OVER].\[31\]\[37\]\[38\]
2. **Contract length:** value falls as the contract runs down.\[31\]\[39\]\[40\] Sell with 2+ years left; in the last 12 months he is cheap or leaves for free [CARRY-OVER].
3. **How you go to market:** not listing the player, or using "Ask Agent About Market Interest", which SI says returns the player's current market value and the clubs most interested, beats transfer listing, which GGRecon's FM24 guide calls "the least likely way to sell a player" (findings 8–10). TransferRoom targets clubs with matching needs. Intermediaries cost up to 10% but generate interest where there is none [OFFICIAL / CARRY-OVER].\[17\]\[21\]\[22\]
4. **Deal structure:** sell-on clauses, instalments and add-ons. FM27 now makes AI clubs value sell-on obligations, so a sell-on clause protects future value [OFFICIAL].\[5\]\[7\]\[17\]
5. **Timing:** agent offers ramp up towards Deadline Day in FM27, so desperate late buyers may pay more.\[7\] Early in the window clubs have more money but are pickier [OFFICIAL / CARRY-OVER].\[5\]\[17\]
6. **Asking-price setting:** an asking price above value may be ignored, and a low one anchors bids low (anecdotal).
7. **Playing time:** last, apart from young players' development and loan appeal.

Playing time ranks last for the fee itself. It earns the tool's attention only for players marked "to loan out" and for young players marked "to sell".

## Q5. Loans out

- **What drives loan demand and terms.** AI loan offers were tuned in FM26 [OFFICIAL].\[23\] Offers come mostly from clubs with a squad gap the player fills.\[41\] You set the wage contribution, monthly fee, agreed playing time, recall and loan-to-buy options (optional, mandatory or after a number of matches), which FMRTE 27 also mirrors [FM27-DATA].\[10\]\[11\]\[12\] A community rule of thumb sets loan fees from his value: if four times his weekly wage is below value ÷ 48, ask 100% wage plus the difference as a monthly fee; otherwise ask a part share of the wage and no fee [CARRY-OVER, formula untested].\[42\] (Corrected on 22 November 2026: this line first said value ÷ 12, four times the article's own figure; see `fm27-sale-and-loan-offer-acceptance.md`.) Asking for "Regular Starter" playing time narrows the pool of interested clubs [CARRY-OVER].
- **Does playing him first help?** Not shown. Sharpness helps him perform once on loan, not the offer itself [SPECULATION].
- **Development: loan or keep?**
  - Ages 15–18 grow mainly through training.\[35\]
  - 18+ need first-team matches; JonasMorais's FM26 Training Guide on FM Scout says that in FM26 carefully chosen loans outperform reserve training "in almost every scenario" [CARRY-OVER].
  - A player who can get first-team minutes with you (cup ties, rotation) does not need a loan [CARRY-OVER].\[43\]
  - Loan club level: higher-level matches give more development credit, but only if he actually starts [CARRY-OVER].\[44\]
  - FM27 makes AI recall slightly less strict and adds monthly loan reports, so check the reports and recall if he is not playing [OFFICIAL].\[7\]

## Q6. Lower-league and semi-professional clubs (worked example: English National League)

- **Values and fees are small, and buyers rarely pay them.** One FM24 manager in tier 6 sold a player for £100k plus £70k add-ons and a 20% sell-on, while other players valued at £200–400k went for about £20k or did not move [CARRY-OVER, anecdotal].\[29\] Another user in the same Steam FM24 thread said CA-90 National League players mostly go to free agency after 1–2 years, with no buying or selling at £200–400k.
- **Sell-on percentage matters more than the fee.** Taking a smaller fee for a large sell-on clause is the standard non-league approach [CARRY-OVER].\[45\]\[46\]
- **Contract types.** Non-contract players can leave at any time if a club comes in, so the "to sell" flag is meaningless for them. Part-time players train less and develop more slowly [CARRY-OVER].\[46\]\[47\] Recently signed players can't be sold or loaned for the first months [CARRY-OVER, FM18].\[48\]
- **FM27 helps you buy.** The stepping-stone promise now weighs more with young players [OFFICIAL].\[5\]\[7\]\[49\] This makes lower-league clubs better at *attracting* loanees and youngsters than at extracting fees.
- **Implication for the tool.** At National League level, keep the "to sell" weighting off by default. Use "to loan out" for youngsters who won't start for you, and use your own lesser fixtures (FA Trophy early rounds, county cups) for development minutes [SPECULATION].

## Q7. What the tool needs to see, and whether FMRTE 27 shows it

| Field | Why it matters | FMRTE 27 grid? |
|---|---|---|
| Transfer status (listed / loan listed / not for sale) | Detects "to sell / to loan" and the listing penalty | **Yes** (column fix in Build 2, Windows and Mac)\[12\] |
| Asking price | Already in your feed; compare it with value | Player field; your feed already has it |
| Transfer value | The outcome you want to track | **Unconfirmed** as a grid column |
| Reputation (current/home/world) | The main driver of value | **Unconfirmed** as a grid column |
| Appearances, minutes, average rating, form | Rule inputs and stop conditions | **Player page only** (read-only Stats section); not confirmed as grid columns\[28\] |
| Months left on contract, wage, agreed playing time, happiness, loan club | Already in your feed | Yes |

**Workarounds on Mac:**
- MacLibero RT reads FM27 season stats on Mac.\[26\]
- The open-source FMSuperScout claims to read FM's real transfer value, reputation and transfer status from memory on Windows and Mac.\[50\]\[51\] It is a GitHub project with no independent verification, so treat its output with care.
- Check FMRTE 27's column picker in the app (Settings → Columns, page type Search results vs Clubs/Nations) before relying on any of these.\[52\]\[53\]

## Recommendations for the tool

**Rule (all numbers are [SPECULATION] unless labelled):**
1. **Scope.** Apply the bonus only to players flagged "to loan out" who are aged ≤ 23, and to "to sell" players aged ≤ 23 on full-time contracts with 12+ months left. For "to sell" players over 23, give no bonus apart from the sharpness logic you already have. [Basis: development is the only supported channel, CARRY-OVER findings 13–14.]\[24\]
2. **Fixtures.** Only fixtures your tool already rates as low importance: early cup rounds, dead rubbers, friendlies for sharpness only. Never league matches with promotion, play-off or relegation stakes.
3. **Size.** Add about +5% to the selection score: enough to break ties, not enough to start a clearly worse player. Hard cap: no more than one extra start per two low-importance fixtures.
4. **Minutes.** Aim for 45+ minutes when he plays [CARRY-OVER, FM24 FM-Arena]. Do not chase beyond about 4–5 appearances a month, given the monthly cap [CARRY-OVER].\[24\]
5. **Stop conditions:**
   - His average rating in the last 3 matches falls below 6.5. [The ~6.7 threshold claim is CARRY-OVER and untested.]
   - A transfer or loan is agreed.
   - The window closes and no window is due within 6 weeks.
   - His playing-time happiness turns negative because of shifting expectations.
6. **Surface the bigger levers instead.** Show alerts for: contract under 18 months, transfer listed (suggest unlisting and using market interest, TransferRoom or an intermediary instead), Deadline Day approaching, and no sell-on clause on young players.

## Evidence gaps, and a test to close the biggest one

**Gaps:**
- No FM27 test of minutes → value, asking price or number of offers.
- No FM27 description of intermediary mechanics.
- Grid availability of value and reputation in FMRTE 27 is unconfirmed.
- AI transfer tweaks are announced for the next patch.\[4\]

**Test (closes the main gap).** Paired-save experiment, about 10 players:
1. Choose five "to sell" and five "to loan" players. Mix ages, half of them under 23.
2. Save at a date 6–8 weeks before a window opens and duplicate the save (A/B).
3. In A, start each player in every low-importance fixture (aim for 6+ starts at 45+ minutes). In B, keep him on the bench.
4. On window opening day in both saves, record value, asking price, reputation (via FMSuperScout, FMRTE or the player page) and form.
5. Offer every player via TransferRoom at the same asking price on the same day. Count offers and record the best fee over 14 days.
6. Treat a gap in median best fee of under 10% between A and B as "no effect", and record it as a finding.
7. Re-run after the next FM27 patch, since SI says AI transfer handling will change.\[4\]

## Sources

1. [Football Manager 27 launches from 10 November](https://www.footballmanager.com/news/football-manager-27-launches-10-november)
2. [Football Manager 27 on Steam](https://store.steampowered.com/app/4530370/Football_Manager_27/)
3. [Football Manager 27 Release Date, Platforms & Editions — Everything We Know](https://www.dlcompare.com/gaming-news/football-manager-27-release-date-platforms-editions-87666)
4. [Football Manager 2027 Patch 27.0.1 - Update Beta to Final](https://www.fmscout.com/a-fm27-update-27.0.1.html)
5. [FM27: A Deeper, More Immersive Football World](https://www.footballmanager.com/fm27/features/deeper-more-immersive-world)
6. [FM27 New Features Guide: Everything New in Football Manager 2027](https://www.fmscout.com/a-football-manager-2027-new-features.html)
7. [FM27 Transfers: What's New and How It Works | FM Scout](https://www.fmscout.com/a-fm27-transfers.html)
8. [Starting an FM27 Save: What to Set Up Before You Continue - FMTweak](https://fmtweak.com/starting-an-fm27-save/)
9. [FM27](https://community.sports-interactive.com/forums/topic/612658-fm27-console-faqs/)
10. [FMRTE for macOS - Football Manager 27 - FMRTE](https://www.fmrte.com/files/file/185-fmrte-for-macos/)
11. [FMRTE 27: real-time editor for Football Manager 27 (FM27)](https://www.fmrte.com/)
12. [Football Manager 27](https://www.fmrte.com/files/category/54-football-manager-27/)
13. [FMRTE 27 for Windows - Football Manager 27 - FMRTE](https://www.fmrte.com/files/file/183-fmrte-27-for-windows/)
14. [Player Value - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/398864-player-value/)
15. [Player valuations still make no sense at all, and it's still a problem - Page 2 - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/579647-player-valuations-still-make-no-sense-at-all-and-its-still-a-problem/page/2/)
16. [Playing time - How to manage best??? - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/585056-playing-time-how-to-manage-best/)
17. [FM26: How to Sell Players - General Discussion - FM26 - Football Manager 26](https://sortitoutsi.net/content/75973/fm26-how-to-sell-players)
18. [What's up with other teams lowballing transfer offers? - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/501798-whats-up-with-other-teams-lowballing-transfer-offers/)
19. [How to sell players??? - Football Manager 26 Mobile - FMM Vibe](https://fmmvibe.com/forums/topic/51633-how-to-sell-players/)
20. [Potential market issue or bug - Transfer, Scouting, Contracts & Intermediaries](https://community.sports-interactive.com/bugtracker/1644_football-manager-26-bugs-tracker/1883_transfer-scouting-contracts-intermediaries/potential-market-issue-or-bug-r42816/)
21. [Introducing Intermediaries and Offloading Players | Football Manager 27](https://www.footballmanager.com/features/introducing-intermediaries-and-offloading-players)
22. [Powered by TransferRoom: FM26's Recruitment Revamp](https://www.footballmanager.com/fm26/features/powered-transferroom-fm26s-recruitment-revamp)
23. [Football Manager 2026 - All Bug Fixes and Hotfix Notes](https://www.footballmanagerblog.org/2025/10/fm26-bug-fixes-hotfix-patch-notes.html)
24. [Some training and development conventional wisdom for FM24](https://fm-arena.com/thread/20900-some-training-and-development-conventional-wisdom-for-fm24/)
25. [Players - Football Manager 2024 - Sports Interactive Community](https://community.sports-interactive.com/sigames-manual/football-manager-2024/players-r4958/)
26. [FM27 player stats for the season, plus league tables (Mac) — MacLibero RT](https://maclibero.com/blog/season-stats-tables/)
27. [Football Manager 2019](https://steamcommunity.com/app/872790/discussions/0/1777136225023141322)
28. [FMRTE 27 for Windows - Discussion and feedback - FMRTE](https://www.fmrte.com/forums/topic/13368-fmrte-27-for-windows/)
29. [Football Manager 2024](https://steamcommunity.com/app/2252570/discussions/0/4029094770946930030)
30. [Players being under valued :: Football Manager 2017 General Discussions](https://steamcommunity.com/app/482730/discussions/0/1291816880499387445/)
31. [My players value is ridiculously low](https://fm-base.co.uk/threads/my-players-value-is-ridiculously-low.114569/)
32. [Examining the Disconnect between Player Reputation, Attributes, and True Talent - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/590176-examining-the-disconnect-between-player-reputation-attributes-and-true-talent/)
33. [How are transfer values calculated? - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/581892-how-are-transfer-values-calculated/)
34. [FM26 Training Guide & Schedules by JonasMorais](https://www.fmscout.com/a-fm26-training-guide-and-schedules-by-jonasmorais.html)
35. [FM26 Training Schedules: Best Weekly Plans & Individual Training — FM26 Tactics Guide](https://www.fm26tactics.com/guides/training-schedule-guide)
36. [When does club reputation update at the end of each season? - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/584404-when-does-club-reputation-update-at-the-end-of-each-season/)
37. [How to Sell Your Players for the Most Money in Football Manager 24 - Operation Sports](https://www.operationsports.com/how-to-sell-your-players-for-the-most-money-in-football-manager-24/)
38. [Can anybody explains me the logic behind player values? - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/439322-can-anybody-explains-me-the-logic-behind-player-values/)
39. [Football Manager 2018](https://steamcommunity.com/app/624090/discussions/0/1736595227847132071/?l=tchinese)
40. [Player value decreasing... - Football Manager General Discussion - Sports Interactive Community](https://community.sports-interactive.com/forums/topic/292473-player-value-decreasing/)
41. [Football Manager 2016](https://steamcommunity.com/app/378120/discussions/0/385428458162266706)
42. [How To Loan Players Out For Profit](https://fmprojects.substack.com/p/how-to-loan-players-out-for-profit)
43. [FM26 Youth Development Guide: Youth Intake, Mentoring & Wonderkids — FM26 Tactics Guide](https://www.fm26tactics.com/guides/youth-development-guide)
44. [FM Youth Academy Guide - FM26 Tips](https://footballgpt.co/fm/fm-youth-academy)
45. [Steam Community :: 1st Season National League North & South Free Transfers Shortlist :: Comments](https://steamcommunity.com/sharedfiles/filedetails/comments/1557320772)
46. [Best FM Tips When Managing in Non-League - FMBrotherhood](https://fmbrotherhood.com/football-manager-guides-tips/best-tips-non-league/)
47. [FM27 lower league guide](https://footballmanagers27.wiki/guides/fm27-lower-league)
48. [Football Manager 2018](https://steamcommunity.com/app/624090/discussions/0/1752358461531539277)
49. [Deeper Football World: Increased Immersion in FM27|Football Manager 27](https://footballmanager.sega.com/asia-en/info/details/000176.html)
50. [GitHub - mavarobli/FMSuperScout: Free, open-source scouting tool for Football Manager 27 and 26, on Windows and Mac. Reads your whole save (60k+ players and staff) in seconds: real CA/PA, hidden attributes, instant filters, role ratings, squad analysis and development tracking. · GitHub](https://github.com/mavarobli/FMSuperScout)
51. [FMSuperScout/README.md at main · mavarobli/FMSuperScout · GitHub](https://github.com/mavarobli/FMSuperScout/blob/main/README.md)
52. [FMRTE column settings not tranlated into FMRTE team display - FMRTE for Windows - FMRTE](https://www.fmrte.com/bug-tracker/fmrte/windows/fmrte-column-settings-not-tranlated-into-fmrte-team-display-r552/)
53. [Missing columns - FMRTE for Windows](https://www.fmrte.com/bug-tracker/fmrte/windows/missing-columns-r788/)
