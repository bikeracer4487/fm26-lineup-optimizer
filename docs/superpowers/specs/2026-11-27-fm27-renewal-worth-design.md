# FM27 Lineup Optimizer: who is worth renewing, and no credit for a shallow position

Date: 27 November 2026
Status: approved by the owner on 27 November 2026 ("Approved"), after a reviewer read it as a builder would and its four points were folded in. Built the same day to the plan `docs/superpowers/plans/2026-11-27-fm27-renewal-worth.md`; the passages the build or its whole-branch review changed are marked "revised", and the plan's closing sections say why.

It wins over `2026-11-25-fm27-contracts-and-wage-range-design.md` on who Contracts lists and in what order, and over the advisors' and scouting designs on the credit Player Removal gives for thin cover. The wage range is unchanged.

## Intent

The owner opened Contracts and found Christian N'Guessan (30, ability 70), Darnell Johnson, Kieran Petrie and Sammy Henia-Kamau listed as players to renew. Contracts does not judge a player: it lists everyone in his last year whom the owner has not marked and Player Removal does not advise moving on. Player Removal in turn counts a place in an eleven, and cover at a shallow position, as merit. So a player below the level of the squad is listed because nothing says "go".

The owner wants Contracts to show the players worth keeping, most important first, with the others behind a closed line with the reasons and a way to overrule the tool. And on Player Removal and Scouting as on Contracts, a shallow position must stop counting in a player's favour: he is judged on merit, and when he should go but is needed, the advice says to sign a replacement first.

He chose the measure on 27 November 2026: a player's best rating at a slot he can play, against the average of the first choices. He added that an older player's expected decline is counted against the present squad, not his age as such: "a 36-year-old player whose ability level still exceeds most of our Starting XI should obviously still be prioritized for renewal". The age decline starts at was to come from the research, not from his example.

## What the research gives (`docs/Research/fm27-age-decline.md`)

Decline starts at about 30 and is steep after 31 (an FM24 test of ten seasons, and the FM26 notes; nothing for FM27). No source measures how fast, in any version. So the age is carried over, and the size of the fall is this tool's estimate and says so.

## Goals

1. Contracts lists the players in their last year whom the tool expects the owner to want, most important first.
2. Every other player in his last year is under a closed line, "Not recommended for renewal", each with the reasons, and a button that overrules the tool.
3. A player's worth is one measure, used on Contracts and shown with its working: his level over a new contract against the first eleven's standard.
4. Player Removal gives no points for thin cover. A player advised to go who is needed says so: sign a replacement first.
5. Scouting counts a player who is not being renewed as going, so his slot shows as a need.

## Non-goals

- Changing the wage range, the club's figures or the agent's figure.
- A forecast of what a player will ask, or a single score for a squad.
- Changing Player Removal's other points, the Young players part, or the planner.
- Measuring decline from the owner's own imports (possible later; the research file says how).
- A lower line for backups (see "Calls this design makes").

## Anti-goals

- A player shown as worth keeping only because nobody else plays his position.
- A reason the owner cannot check: every verdict names the slot, the two figures compared and what was estimated.
- An estimate read as a fact: a reach and a decline are labelled this tool's estimate, as elsewhere.

## Approaches considered

1. **Against the first eleven's standard (chosen by the owner).** His best rating at a slot he can play, against the average rating of the outfield first choices; for 23 and under his reach, for 30 and over his ability after the decline expected.
2. **Current ability against the squad's average.** What the owner quoted. Simpler, but it ignores position and role, which the ratings exist for.
3. **Player Removal's score without the thin-cover points.** Least work, but the score still rewards holding a place in a weak slot, and mixes personality and wage into one number.

## Design

### 1. The standard and a player's worth (engine, new `Advisors/Worth.swift`)

**The standard** is that of the whole squad's first eleven for the primary tactic, as Contracts already reads the whole squad's elevens: the average full-fitness rating of the outfield first choices who are in position, and the average of (offset + ability) of the same players (`ratingAbilityOffset`). Scouting's weak line reads the same two averages on the squad that stays; one helper gives both.

**A player's worth** (`Worth.of`), for a player of the club's own, here or out on loan:

- He is rated at every slot of the tactic where his familiarity is 10 or over in both phases (`Scouting.playableSlots`), at full fitness. A player who can play none has no worth.
- **His ability over a new contract:**
  - 23 or under (`developingUpToAge`): his reach (`Reach.estimate`), as Player Removal and Scouting estimate it.
  - 24 or over: his ability after the next two seasons (`renewalSeasons`), each season taking the fall for the age he begins it at: nothing under 30, 3 points at 30 or 31, 6 at 32 to 34, 9 from 35. The seasons are the one he is in, at his age now, and the next, a year older. So a player of 28 or under loses nothing, one of 29 loses 3 and one of 30 loses 6: there is no step at a birthday beyond the table's own.
- **His share** at a slot is his rating there, scaled to that ability through the offset, over the standard's rating. When the ability is a reach above today's, he must clear by ability too, (offset + reach) over the standard's ability, and the lower of the two is his share: a rating scaled up to a potential can otherwise clear a line no first choice is near (the rule of 25 November 2026). Revised during the build: his share is never below his share today, since his reach is never below his ability; without that, one more point of potential could lower a young player's worth. One whose reach is not above his ability is measured as he is today. At the goalkeeper's slot the share is by ability alone, as Scouting measures a goalkeeper.
- His worth is his highest share and its slot (the tactic's order on a tie).
- **He meets the standard** when his worth clears `scoutingWeakShare`, 0.95, by Scouting's own rule (`Scouting.clearsWeakLine`): within 5% of the average of the first choices, the line Scouting already uses to call a first choice weak. Revised in the plan: a worth exactly 5% under does not meet it, as a first choice exactly 5% under is weak.

The decline numbers are one new entry, `declineRules` (the steps, each an age it applies from and a size, and the number of seasons), labelled derived, with a source saying the ages are carried over and the sizes are this tool's estimate with no test behind them; `FitnessModel.problems` checks it (ages rising, sizes 0 or more, at least one season).

**The words** (`AdvisorText`), each naming the slot:

- "Rates 2.9% above the average of your first eleven, at centre-back."
- "Rates 10.6% under the average of your first eleven, at right defensive midfield."
- 23 or under: "Ability 79, could reach about 109 (this tool's estimate): that would rate 7.8% above the average of your first eleven, at left attacking midfield."
- Revised after the whole-branch review: a gap that rounds to 0.0% reads "level with the average of your first eleven"; a gap under the standard that reads as the line's own, "5.0%", is written to two decimals ("4.96% under", "5.04% under"); a young player held at today's share reads "Ability 95, could reach about 98 (this tool's estimate), which by ability would rate lower than he rates today: 3.0% under the average of your first eleven, at left attacking midfield."; and at the goalkeeper's slot each sentence says "the average of your first eleven by ability".
- With a fall expected: "He is 30. This tool expects him to lose about 6 points of ability over the next two seasons, from 70 to about 64 (its own estimate: no test measures decline): that would rate 10.4% under the average of your first eleven, at right defensive midfield. Rates 6.4% under it today."

### 2. Contracts (engine `Advisors/Contracts.swift`, app `ContractsState`, `ContractsPresentation`, `ContractsScreen`)

Every player of the club's own in his last year or with no contract (the three parts, as now; a player on loan here never) is in exactly one of three places.

Revised after the whole-branch review: a line under the intro says where the line is, "A player is recommended when he would rate within 5% of the average of your outfield first choices over a new contract: on where his ability could reach at 23 or under, and after the fall expected from 30 (this tool's estimate: no test sets the line or measures the fall)."

**Recommended**, the list: he meets the standard, is not marked to sell, and Player Removal does not advise moving him on. Ordered by worth, highest first, then by the earlier end day, then the order handed in. The part headings go; each row keeps its timing line, drawn as a caution when other clubs can approach him now. Each row gains its worth line above the wage lines. The pill's count is this list.

**Not recommended for renewal**, closed at every launch behind "21 players not recommended for renewal": everyone else, in the same order, each with his name, his facts, his standing and his reasons, every one that applies, in this order:

1. "You have marked him to sell."
2. Player Removal's advice when it advises moving him on: "Player Removal advises selling him." ("releasing him"; for a termination, "ending his contract by agreement", revised during the build).
3. His worth line, when he does not meet the standard; or "He can play no slot of this tactic."; or, when the first eleven has no outfield player in position, "Your first eleven has no outfield player in position, so nobody can be measured against it." (added in the plan).
4. When he is first or second choice at a slot, or counts as cover or as a stand-in where Depth has no more than the line: "He is first choice at right defensive midfield: sign a replacement before he goes."

Each has a button, "Renew anyway". It moves him into the list, where his row says "The tool does not recommend renewing him; he is listed at your choice." with the same reasons under it and a button "Follow the advice" that undoes it. Revised after the whole-branch review: the sentence that says to sign a replacement is left off such a row, since he is not going. A choice stays saved while the tool recommends him, and holds again if it stops recommending him. The choice is saved in `contracts.json` (`wanted`, each with its day; absent in older files) and dropped at an import by the rule that drops a dismissal.

**Not renewing**, as now: a recommended player the owner sets aside with "Not renewing", shown again with "Show again".

What goes: the rule that a player on a youth contract or with none is listed only in an eleven or when worth developing (his worth decides now); the line counting those left out as going and its button (their reasons say it); the mark to loan out as a reason to leave a player off (he is coming back, so he is judged like anyone).

### 3. Player Removal (engine `Advisors/Removal.swift`, app `RemovalPresentation`)

The thin-cover points go, for the club's own players and for the loans reviewed, and the parameter `removalThinCoverPoints` with them. What they protected is still found, and kept on the advice (`neededAt`: the slot, and whether he is first choice where cover is thin, cover that would be missed, or a stand-in that would be missed). For a player advised to move on, or a loan to end early, the row carries a caution in the engine's words:

- "Sign a replacement at goalkeeper before he goes: he is first choice there and cover is thin."
- "Sign a replacement at left back before he goes: too few players can step in there without him."

All three cases lose the points and gain the caution, not only the first choice of a thin slot. On the captured squads this changes the advice (the only goalkeeper is again advised to go, now with the caution), and so who is counted as going by Training, Scouting and the planner; the plan re-reads the commands' output on the captures and records what moved.

A young player needed for cover is still watched and not loaned for matches: that rule is about this season, not his worth.

**The contract's own points follow his worth.** Player Removal adds points for a contract that is ending (15 at twelve months or fewer, 25 at six) and for no contract (50), which would have it advise moving a player on because he is on Contracts. Today a young player worth developing is spared the first of these and told "renew it". That test becomes his worth, at any age: a player who meets the standard gets "Contract ends in 8 months: renew it", or "No contract: offer him one", at no points; anyone else keeps the words and the points. Revised after the whole-branch review: when he is advised to go on his other points the line gives no instruction, "Contract ends in 8 months: not counted against him, as he meets the standard of your first eleven". Player Removal is handed each player's worth, which rests on the elevens and his reach and not on Player Removal, so nothing goes round in a circle. `Removal.isWorthDeveloping` is unchanged everywhere else (the young players' advice, the planner's favour).

He is in `advisedToLeave` like anyone advised to go, so Training does not count him as staying cover, Scouting counts him as going, and the planner gives him no favour.

### 4. Scouting (engine `Advisors/Scouting.swift`)

A fifth reason a player is going, after the four there are: in his last year and not being renewed (not recommended and not overruled, or set aside by the owner). The Needs tab names him with the others ("not being renewed") and judges the squad without him, so a first choice the owner will not renew shows as a need at his slot. The command line, which takes no marks, takes none of these either.

## What the rule showed on the owner's squad (27 November 2026, 33 players in a part)

The standard: an average rating of 130.9 and an average ability of 96 over ten outfield first choices.

- **Recommended (13):** Harry McGlinchey, David Crowley, Fuad Smith, Laolu Omobolaji, George McCormick, Kai Payne, Aimar Govea, Josh Lewis, Giovanni Parker, David McCabe, Deago Nelson, Sammy Bagan and, narrowly, Kieran Petrie (23, ability 69, reach about 89: 4.3% under by ability).
- **Not recommended (20):** Christian N'Guessan (6.4% under today, 10.4% under after two seasons), Darnell Johnson (7.8% under today, 11.8% after), Sammy Henia-Kamau (reach 80: 9.6% under), Dejan Tetek (26: 10.6% under), Ayman Benarous and fifteen players of 18 or under whose reach is 11% or more under.

Josh Lewis (22, reach 103) is advised "sell" by Player Removal today on exactly 50 points, 15 of them for his contract ending in 8 months. He meets the standard, so those points go, he is watched and not sold, and he is recommended.

Nobody in his squad carries the thin-cover points today, so removing them moves nobody there; N'Guessan is kept by his place in the first eleven alone. The list was worked out by a throwaway run of the engine on a copy of his saved state, not by the built rule, so it is a guide to what the build should show and not a test.

## Calls this design makes (each the owner's to change)

1. **One line, the first eleven's.** A backup of 24 or over who is under it is not recommended (Dejan Tetek). A lower line for backups would list more.
2. **Kieran Petrie is recommended**, on his reach. The owner named him as one not to renew; the row shows the working, and "Not renewing" sets him aside.
3. **The size of decline**: 3, 6 and 9 points a season from 30, 32 and 35, over two seasons. No test gives one.
4. **One age for every position.** Goalkeepers may last longer; nothing measured says how much.
5. **Natural Fitness and Professionalism are not counted** in the decline, since only their direction is known.
6. **The part headings go** from Contracts, for the order by worth.
7. **A mark to loan out no longer leaves a player off.**
8. **Scouting counts a player not being renewed as going.**
9. **Player Removal's other points stay**, the points for a place in an eleven among them.
10. **Player Removal's points for an ending contract follow the standard**, not "worth developing". A young player Player Removal would develop, whose reach is under the standard, is no longer told "renew it", is not recommended on Contracts, and is counted as going by Scouting. The sentence "renew his contract before a loan" in the young players' advice is left as it is.
11. **A fall is counted from a season begun at 30**, so a player of 29 is taken to lose 3 points over a two-season contract.

## Left to the builder

The types' names, the tests, the sample data and pictures, the wording of lines this design does not quote (in the engine, as every word about advice is), and the notes in `CLAUDE.md`.
