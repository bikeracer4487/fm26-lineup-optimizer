# FM27: when a player's ability starts to fall, and how fast

Date: 27 November 2026. Asked by the owner, to decide from what age a player's age should count against renewing his contract, and by how much.

## Answer in short

- **When.** Decline starts at about 30 and becomes steep after 31. This rests on one test in FM24 (ten seasons simulated, reported second-hand) and on the FM26 notes already in this repository. Nothing was found for FM27 itself. [CARRY-OVER]
- **How fast.** Nothing measured was found, in any version: no source gives points of current ability lost per season at an age. Any rate the tool uses is its own estimate. [NOT MEASURED]
- **What slows it.** High Natural Fitness and Professionalism, by every account, with no number attached. [CARRY-OVER, direction only]
- **Position.** Goalkeepers and centre-backs peak later than wide players in the one test that split positions; it gives no later age for the start of their decline. [CARRY-OVER]

## Findings

| # | Finding | Label | Source |
|---|---------|-------|--------|
| 1 | In a ten-season simulation of FM24 with data exported each season, "most players reach their peak (maximum Current Ability) around age 24", the main range being 23 to 28, and "they all roughly peak around aged 24 and then slowly decline up to age 31 when the drop off in stats massively accelerates". | [CARRY-OVER] FM24 test, read second-hand: the page refused an automated read (HTTP 403), so the wording is from search results and from `skill-potential-factors.md`, which cites the same page | sortitoutsi.net, "When do players peak in Football Manager? (the advise from SI is a lie...)", by Futek [1] |
| 2 | The same test's peak ages by position: goalkeepers 28 (27 to 31), centre-backs 27 (26 to 31), full-backs 25 (25 to 29), central midfielders 25 (24 to 30), wide attackers 26 (23 to 29), strikers 27 (24 to 29). | [CARRY-OVER] as finding 1 | `skill-potential-factors.md`, "Position-Specific Peak Ages", citing [1] |
| 3 | "Decline typically begins around age 30-32", physical attributes first and mental ones last; it "accelerates sharply after age 31, and by age 35, even intensive physical training struggles to prevent CA reduction". | [CARRY-OVER] FM26 notes; a summary of community sources, no test of its own | `docs/Research/skill-potential-factors.md`, "Age-Related Decline" |
| 4 | Since FM22 players "decline more slowly, especially those with high Natural Fitness and Professionalism"; those without "will still struggle to continue past their mid-30s". In FM21, "once a player turned 32, their physical attributes would fall so fast that they'd be almost worthless by their 35th birthday". | [CARRY-OVER] FM22, the author's observation from two saves of about 30,000 players run to 2030; no rate measured | fullerfm.com, "FM22: The Age-Old Problem" [2] |
| 5 | Physical and technical attributes "start to drop, often noticeably from around 30 onward"; peaks given as wingers and forwards 22 to 27, full-backs 23 to 27, central midfielders 25 to 30, central defenders 28 to 32, goalkeepers 28 to 34. | [SPECULATION] a planning guide for FM26 with no method stated; the later peaks for defenders and goalkeepers are not in the FM24 test | fmdossier.dev, "Age curves and rebuilds" [3] |
| 6 | No rate of decline by age was found. Two FM-Arena threads that might hold one could not be read (HTTP 404 to an automated read): "Training and age: Golden Age / Declining Age" [4], which search results describe as a test of growth by age, and the "Summary of recent findings for optimal play in FM24 & FM26" [5]. | [NOT MEASURED] | searches of 27 November 2026 |
| 7 | The owner's own save: Christian N'Guessan had ability 73 at 29 in the capture of 23 November 2026 and 70 at 30 in the squad as imported on 27 November 2026, a fall of 3 within about a season of the game. One player, so it shows only that a fall before 31 happens and is small. | [FM27 observation] one player | the capture `first-team-with-expiry` and the owner's squad |

## What this supports

1. An age from which decline counts: **30**, the earliest age the sources give, with the steeper fall **from 32** ("after 31").
2. No size. A tool that projects an older player's ability has to choose one and say it is an estimate. A choice that fits what is written: a small fall a season at 30 and 31 (finding 1 says "slowly"; finding 7 saw 3), a larger one from 32, larger again from 35 (finding 3).
3. Natural Fitness and Professionalism can be named beside the estimate; counting them would put a number on a direction.
4. One age for every position: the only test that split positions (finding 2) ends every range between 29 and 31.

## How to measure it in the owner's save

The app keeps each squad as imported. A reading of every player's ability at each import, as the jadedness trend keeps his fitness, would give the fall per season for each player of 28 or over after a season of imports. Not built.

## Sources

1. https://sortitoutsi.net/content/67377/when-do-players-peak-in-football-manager-the-advise-from-si-is-a-lie
2. https://fullerfm.com/2022/05/02/fm22-the-age-old-problem/
3. https://fmdossier.dev/guides/age-curves-and-rebuilds
4. https://fm-arena.com/thread/13924-training-and-age-golden-age-declining-age/
5. https://fm-arena.com/thread/15934-summary-of-recent-findings-for-optimal-play-in-fm24-amp-fm26/
