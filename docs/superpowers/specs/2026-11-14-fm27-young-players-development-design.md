# FM27 Lineup Optimizer: young players judged on where they could reach

Date: 14 November 2026
Status: approved by the owner on 14 November 2026 ("your young player development plan is approved, so please proceed"), with the defaults of section 12 as written. Not built.

Research behind it: `docs/Research/fm27-development-matches-vs-training.md` (the owner's, added 14 November 2026), `docs/Research/fm27-selling-and-loans.md`, and the FM26 files `skill-potential-factors.md`, `player-retention-strategy.md` and `player-rotation-guide.md`. No test of attribute growth exists for FM27; every growth number here is carried over from FM24 and FM26 tests, on the owner's rule that growth research carries over.

## 1. Intent

The owner wants the tool to encourage the growth of young players, most of all those likely to pass his current best players in their positions, in both places it gives advice: who to move on or loan out, and who starts.

Today it does neither well. Player Removal scores a young player on today's ability against the first team, so a 16-year-old on a youth contract came out "Critical: Loan": a loan the game does not allow, that the research says would not help him, on a scale meant for moving players on. The planner favours every player of 21 or under by the same small amount, in lesser fixtures only, whether he is two seasons from being the club's best player or will never improve.

The owner's instructions, in his words or close to them:

- A young player is not exempt from a release. He is "evaluated in a different way, with a greater emphasis on their potential and where their ability could realistically reach given the values of their attributes".
- A youth player "whose ability and/or potential (actual potential ability cap or just having a low potential because of low value development-related attributes) is markedly lower than other players in the squad and we don't need their depth in their position" should be recommended for termination.
- Players on a youth contract "can NOT be sold OR loaned, they can only be released".
- Development should count "both for loan/sell recommendations AND for match recommendations".

## 2. Goals

1. One estimate, **realistic reach**: the ability the tool expects a player to have when his growing years end, from his age, potential, Professionalism, Ambition and Determination. Always shown with its working and called this tool's estimate.
2. Player Removal judges a player of 23 or under on his reach against the first and second choice at his own position, not on today's ability against the first team.
3. A young player who is markedly below the squad even at his reach, and whose depth is not needed, is advised to go: a release on a youth contract, a sale or termination otherwise.
4. Loan advice follows the research by age: never at 17 or under, with care at 18, and from 19 for a player worth developing who is not getting matches here. It is advice to develop him, shown without a removal level.
5. The planner favours a young player more when he is on course to pass the first choice at the slot, a little in ordinary league matches too, never in the biggest matches, and stops once he has had his matches for the month.
6. A youth-contract player is never advised a sale or a loan and cannot be marked for either.

## 3. Non-goals

- Substitutes. The planner picks starters and assumes 90 minutes. The research says short substitute appearances add almost nothing, so nothing is lost.
- Matches the tool cannot see. It knows only the first team's confirmed lineups, not U21 or U18 matches.
- Entering the club's facilities or coaching. The research measured training facilities at level 10 as 97.4% of level 20 and found no test of coaching, so they would change nothing the tool computes.
- A bar that looks ahead to a promotion. "The squad" is today's squad.
- A favour for players of 24 to 26. The owner asked about young players.
- Changing the First and Second XI to use potential. They stay the best players today.
- An exception for a large transfer offer. The tool cannot see offers.

## 4. Anti-goals

- A release advised on an estimate presented as a fact. Every such row shows the working and says what the limit is: his potential, or his rate of growth.
- A favour large enough to cost a match that matters.
- A young player advised to leave by one rule and favoured for matches by another.

## 5. Approaches considered

1. **Exempt players of 17 and under from removal advice.** Queued, then withdrawn by the owner on 14 November 2026: he wants them judged differently, not exempted.
2. **Judge on potential alone** (rating scaled to potential against the first choice). One line to explain, but it passes exactly the players the research warns about: a large gap he will never close because his Professionalism is 5.
3. **Judge on realistic reach. Chosen.** It covers both of the owner's cases with one test: a low potential, and a decent potential he is not expected to reach.
4. **Keep today's point rules and add exceptions for young players.** Dropped: the prospect and false-prospect rules are each a part of reach, and keeping them beside it would count the same thing twice.

For matches: a flat favour for every young player (today) was kept as the floor, and a larger favour for a likely successor added on top, in preference to raising the flat favour for everyone, which would spend results on players who will not repay them.

## 6. Realistic reach

**Reach** = the smaller of his potential ability and (his current ability + the expected growth of each season from his age now up to and including the season he is 26).

**Expected growth in a season** = the season's base for his age × a factor for Professionalism × a factor for Ambition × a factor for Determination.

| Part | Number | Source | Label |
|---|---|---|---|
| Base, 18 and under | 18 points | EBFM tests: about 12 a season with no matches and 20 with 20 to 30; youth-team matches are worth about 75% of senior ones, so 12 + 0.75 × 8. It assumes he plays for his age group. | derived from carried-over figures |
| Base, 19 and 20 | 14 | EBFM: about 14 with 20 to 30 matches (5 with none) | carried over from FM26 |
| Base, 21 to 26 | 12 | EBFM: about 12 with matches (none without). An older test has growth falling through these years (8.4 a season at 21, 1.2 at 28); the newer figure is used, which errs toward keeping a player. | carried over from FM26 |
| Base, 27 and over | 0 | "Negligible either way" | carried over from FM26 |
| Professionalism | his rate ÷ 17, the rate being 17 at 20, 8.2 at 10, 2.4 at 1, straight lines between | `skill-potential-factors.md`; the bases are taken to be the rates of a player at Professionalism 20 | carried over from FM26; the division is derived |
| Ambition | 0.73 at 1, rising in a straight line to 1 at 10; 1 above | harvestgreen22's test | carried over from FM26 |
| Determination | 0.66 at 1, rising in a straight line to 1 at 10; 1 above | the same test | carried over from FM26 |

From 19 the bases assume he gets his matches, here or on loan. That is deliberate: reach answers "how good could he become if developed properly", and the loan and lineup advice below exist to get him those matches.

The older rule that an Ambition under 6 stops growth at 21 is not used: the measured figure (73% at Ambition 1) replaces it.

**As a rating at a slot.** Reach rating = his full-fitness rating at the slot × reach ÷ current ability. The slots considered are those where he is at least an option (familiarity 10 or over in both phases) or is retraining. His **best slot** is the one where his reach rating is the greatest share of the first choice's rating, leaving out any slot where he is the first choice himself. A player with no such slot is compared in ability points with the first team's average (section 7.1).

**Whom he is compared with.** The first and second choice at a slot are the engine's, with injured players kept in, in Player Removal and in the planner alike, so a player has the same band on both screens. Where the player he is compared with is himself 23 or under, that player's own reach rating is used in place of his rating today, everywhere: a youngster behind a young first choice is not said to be passing him when both will grow.

**Worked figures.** Aged 16, Professionalism 15, ability 55, potential 140: the Professionalism factor is 12.6 ÷ 17 = 0.74; three seasons at 13.3, two at 10.4, six at 8.9 add 114; 55 + 114 is above 140, so his reach is his potential. Aged 16, Professionalism 3, Ambition 4, Determination 10, ability 40, potential 130: factors 0.22 and 0.82; three seasons at 3.2, two at 2.5, six at 2.1 add 27; his reach is 67, about half his potential.

**The working is always shown**, in the engine's words: "Ability 55, potential 140. At 16 with Professionalism 15 this tool expects about 13 points a season now, fewer later: could reach his potential." Where reach is below potential the sentence says why: "At his Professionalism this tool expects about 3 points a season; mentoring could change that." Where potential is the limit: "His potential is the limit."

### On course to pass the first choice

For a player of 23 or under, at each slot he can play and is not first choice at, the tool walks forward a season at a time with the growth above (never past his potential) and notes the first season his rating at the slot is above the first choice's. A first choice who is himself 23 or under is walked forward the same way. The result is a band, in words:

- **Close**: ahead within one season.
- **On course**: ahead before he is 24.
- **Possible**: his potential is high enough, but he gets there at 24 or later, or his reach falls short.
- **Not expected**: his potential, as a rating, is below the first choice's rating (the first choice's own reach rating when he is 23 or under).

A player who is first choice at a slot has no band there: his row reads "First choice at striker".

With the working: "Needs about 14 more ability points to match Smith at left back; this tool expects about 12 a season. On course." A first choice of 30 or over adds "Smith is 31" and nothing more: decline is not measured.

## 7. Player Removal

### 7.1 One line from reach

For a player of the club's own aged 23 or under, the three lines that compare today's ability with the first team (in neither eleven, among the weakest 30%, ability against the squad's average) and the prospect and false-prospect points are replaced by one line from his reach rating at his best slot:

| His reach rating at his best slot | Points | Sentence |
|---|---|---|
| At or above the first choice's rating | −40 | "Could pass Smith at left back", with the band |
| At or above the second choice's | −20 | "Could make the second eleven at left back" |
| At or above the bar (below) | +15 | "Could become cover at left back, no more" |
| Below the bar at every slot he can play: **markedly lower** | +70 | "Not expected to reach the level of the squad at any position" |

- **The bar** is 80% of the first choice's rating: the share Training already asks of a player worth retraining for a slot, from the research's "cover can be about 20% worse than the first choice" (carried over from FM26). **For a player of 16 or under it is 70%** (derived): the estimate adds up the most seasons for the youngest and is least reliable for them, and a release cannot be undone.
- −40, −20 and +15 are today's points for the first eleven, the second eleven and neither. +70 is what the three replaced lines give a weak player today.
- A player who is in the first or second eleven today keeps that line where it is the better of the two.
- **The Professionalism and Ambition lines carry no points for a player of 23 or under.** Reach already discounts both, and counting them again would advise a release on what is one weakness. They still show in his working.
- The stalling rule (today for ages 23 and 24) applies at 24 only: at 23 the reach line already says it.
- Every other line (contract, Consistency, Injury Proneness, Controversy and the rest) applies as now. The levels are unchanged. Players of 24 and over are scored as now.
- **With no slot he can play**, his reach is compared with the first team's average ability: at or above it, −20 ("Could reach the level of the first team"); at or above 85% of it, +15; under 85%, markedly lower, +70. There is no −40 and no band, since there is no first choice to pass.
- Player Removal is handed the retraining entries and the first team's confirmed lineups, which the advisors' request already holds.

### 7.2 "We don't need his depth"

No new rule. The engine already takes 30 points off a player who is first choice at a thin slot or counts as cover at a slot that would be thin without him. A markedly lower player who is needed scores 70 − 30 = 40 and is watched; one who is not scores 70 and is advised to go.

### 7.3 The advice for a player of 23 or under

| Advice | When |
|---|---|
| **Release** (youth contract), or **sell** or **terminate** as now (other contracts) | His score reaches the high level: in practice markedly lower and not needed for depth, or a lesser reach with other faults. |
| **Keep and develop** | Aged 17 or under, reach at or above the second choice's. The sentence says that at his age he grows mainly in training and a loan would add little. |
| **Keep and play** | Aged 18 to 23, reach at or above the second choice's, and getting matches here. |
| **Loan for matches** | Aged 18 to 23, not on a youth contract, reach at or above the second choice's, not getting matches here, not needed for depth, more than 12 months left on his contract. At 18 the sentence adds: "only where he will start regularly; otherwise he grows nearly as well here". |
| **Watch** | Everything between. |

The table is read from the top: a score at the high level wins over every row below it. Every player keeps a level from his score, as now, and stays in the main list; for a player of 23 or under the action shown beside it is the advice above. A player advised a loan for matches therefore sits at the keep level, not at high or critical.

- **Getting matches here**: he is first choice at a slot, or he started at least a third of the first team's confirmed matches in the last 60 days (a third is about the 15 full matches a season the research gives as the least a player of 21 or over needs). With fewer than 6 matches confirmed in that time there is too little to go on, and a first or second choice counts as getting matches.
- **Loan for matches is not a removal.** It never comes with the high or critical level, his wage is not counted in the wages at stake, and he is not treated as advised to leave, so Training can still recommend him for retraining. He is treated as leaving only once the owner marks him to loan out.
- **A false prospect is sold, not terminated.** Where the advice would be "sell or terminate" for a player on a full-time contract whose potential is far above his reach, it is "sell": buyers still pay for the potential. The old false-prospect test is kept for this and carries no points.
- **A short contract on a player worth keeping.** For a player whose reach line is −40 or −20, "contract ends in 5 months" carries no points and reads "renew it". For a markedly lower player it keeps its points: a contract running out is the cheapest way for him to go. A player who would be advised a loan but has 12 months or fewer left is advised to keep, with "renew his contract before a loan".

### 7.4 Youth contracts

A player on a youth contract can only be kept or released (the owner's statement; FM27 observation). Where the rules give a sale or a termination the advice is a release. Where they would give a loan for matches the advice is "Keep and develop", with the sentence that a loan needs a full-time contract. He cannot be marked to sell or to loan out: the app does not offer the control and shows the engine's sentence saying why in its place, the model ignores such a mark, a mark already held is dropped when he is next imported on a youth contract, and the planner ignores one.

## 8. The planner

All of this adjusts a player's value with a reason, as the other importance rules do. None of it acts at high importance.

1. **The floor, by age.** A player of 23 or under with potential at least 1.15 times his ability, who is not markedly lower (section 7.1) for the fixture's tactic, is favoured in low and sharpness fixtures, in any slot. The size follows what a match is worth to his growth: ×1.10 at 21 to 23, ×1.07 at 18 to 20, ×1.02 at 17 and under (×1.04 with Professionalism 14 or under, who gains more from playing). Today it is ×1.10 for everyone of 21 or under. Sizes derived from the research's growth per match by age (0.5, 0.35, 0.1 and 0.2 points per 90 minutes). A markedly lower player gets no development favour of either kind, so no player is advised to go by one rule and favoured by another. The planner works out reach, the slots' first choices and the bands for each fixture's tactic with the same code Player Removal uses.
2. **A successor is favoured more, at his slot.** A player of 18 to 23 whose band at a slot is Close or On course, and a player of 17 or under whose band is Close, is favoured at that slot in place of the floor: ×1.15 in low and sharpness fixtures (the size of the retraining favour) and **×1.05 in medium fixtures** (derived). The reason reads: "On course to pass Smith at left back: favoured for matches there".
3. **A new setting, Development**, from 0 to 1, beside Stability and Saving players: each favour above is 1 + (factor − 1) × the setting. At 1 it is as written; at 0 development changes no lineup. The default is 1, and saved settings from before this change read as 1, so nobody's present favour shrinks unasked.
4. **He has had his matches.** The favour falls to nothing once he has started 4 matches in the last 30 days: the game reads at most 150 match points a month, about four or five full matches (carried over from FM26).
5. **Guards.** At medium importance at most two successors are favoured in one lineup, the two closest to their first choices. The favour multiplies a value that already carries condition, sharpness and jadedness, so a tired or unsharp youngster is not started on it. The consecutive-starts rules still apply.
6. **With the other rules.** At one slot a player who is both retraining and a successor gets the larger of the two favours, not the product. A successor counts as in the elevens at a sharpness fixture for the favour to a player who needs sharpness, so he can be got sharp, and not for the mark-down of a player who is already fully sharp. At medium importance the retraining favour (×1.08) is the larger, so it is the one a retraining successor gets. The shop-window, stability and saving rules are unchanged.

An example of the medium favour: a successor whose match-day value is 100 against the first choice's 104 starts an ordinary league match (105 against 104); at 98 he does not.

## 9. The screens

- **Player Removal** gains a part, **Young players**: every player of the club's own aged 23 or under, each with his reach in words and its working, his band at his best slot, and his advice. The main list is unchanged in what it holds: every player of the club's own, with his level, under the same filters, and the mark controls on an opened row. For a player of 23 or under its action reads as section 7.3 gives it.

  ```
  YOUNG PLAYERS
  Tom Reed · 16 · striker                                        Keep and develop
    Ability 55, potential 140. At 16 with Professionalism 15 this tool expects
    about 13 points a season now, fewer later: could reach his potential.
    Could pass Smith at striker. On course.
    At his age he grows mainly in training; a loan would add little.

  Sam Hart · 19 · central midfield                               Loan for matches
    Ability 78, potential 115 … Could make the second eleven at central midfield.
    He has started 1 of the last 9 matches here.
  ```

- The mark controls on an opened row are not offered for a player on a youth contract; the engine's sentence says why.
- **Match Selection** shows the new reasons on picks as it shows every other reason.
- **Settings** gains Development beside the two settings it has.
- `lineup-cli advise` prints the Young players part.

Every word is the engine's.

## 10. Testing

- Engine: reach for each age step and each factor, at and beside every boundary; the cap at potential; each band; each row of 7.1, both bars; depth needed and not; each advice of 7.3 with a case that gets it and a near case that does not; a youth contract never sold, loaned or marked; a loan for matches not in advised-to-leave; each planner rule changing a pick and not changing one, at each importance; the setting at 0 and 1; the monthly stop; the cap of two.
- On the captured squads: what every player of 23 or under gets, looked at one by one and recorded in the plan. The 16-year-old on a youth contract is no longer "Critical: Loan".
- App: the rows of the new part, the mark refused, the setting saved and read back, saved state from before this change opening with no notice. Pictures of Player Removal with the new part, looked at.

## 11. Known limits

- The growth numbers come from FM24 and FM26 tests whose conditions are mostly not stated. If the bases were measured on average players and not on the most professional, reach is underestimated for everyone below Professionalism 20, which errs toward release. The lower bar for 16 and under and the working on every row are the guard.
- The estimate is weakest for the youngest, who have the most seasons to add up.
- Professionalism can be raised by mentoring; a low reach caused by it is softer than one caused by a low potential.
- A rating is assumed to rise in proportion to ability. Pace arrives early and stops near 21, so a slow 20-year-old is overrated.
- The bar is today's squad. After a promotion a "could become cover" player becomes "markedly lower".
- Depth is counted by familiarity, not quality, so a weak player who is the only cover is kept.
- The tool cannot see youth-team matches, loan offers, or the level of a club that would take a loanee.
- Whether a 16-year-old can be loaned in England in FM27 is community report only; the tool never advises it either way.

## 12. Decisions made here that are the owner's to change

These three were put to the owner; he approved the design with the default taken for each.

1. **How much result to trade in an ordinary league match for a successor**: about 5% (the medium favour), scaled by the Development setting.
2. **The bar for "markedly lower"**: 80% of today's first choice at his position, 70% for a player of 16 or under.
3. **Loan or keep and train**: by age, as the new research gives it; no facilities setting.

And smaller ones:

- The age at which a player stops counting as developing is 23, not 21.
- A player of 17 or under gets the successor's favour only when he is already Close.
- A player of 21 to 26 is expected to grow about 12 points a season at the most, the newer research's figure, in preference to an older test that has growth falling away from 24.
- The Professionalism and Ambition point lines do not count against a player of 23 or under, because reach already uses both.
- The Development setting starts at 1.

## 13. Left to the builder

- Types' and parameters' names; where reach is worked out so that Removal and the planner share it.
- The layout of the Young players part within the Tactics board direction, and whether it is a part of the screen or a tab on it.
- The exact wording of the sentences, in the engine.
- Whether the command line takes the Development setting.
