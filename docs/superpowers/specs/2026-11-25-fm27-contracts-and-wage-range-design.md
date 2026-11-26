# FM27 Lineup Optimizer: a shorter top row, a Contracts screen and a reasonable wage range

25 November 2026. A project in three parts, built in this order: the menu, the Contracts screen, the wage range
(on Contracts and on Scouting's candidates). The research is `docs/Research/fm27-contract-wage-demands.md`.

## Intent

The owner asked for three things on 25 November 2026:

1. The top row is crowded. Tactics, Elevens, Rest, Offers and Settings are screens he visits less often, and he
   wants them moved into one menu.
2. He wants to be told when a player he wants to keep is in the last year of his contract.
3. He wants guidance on a reasonable salary for those players and for the players he pastes into Scouting, "to
   avoid signing or re-signing a player with unreasonable salary demands". He asked for it by age, ability,
   position and league, and asked for research first.

## What the research found, and what it changes

No test, datamine or Sports Interactive statement in any version gives the wage a player asks for from his
ability, reputation, age or division, and no tool shows the demand. The repository's own captures speak against
pricing by ability: among the owner's 27 full-time players the wage has a rank correlation of 0.11 with ability,
and among 49 paid players at other clubs, all of ability 60 to 75, it has none, with wages nineteen times apart
by club. What is official (carried over from FM26): the game holds a desired wage for each player and compares
it with a cap on one wage at the club, which FMRTE shows as "Max Wage (aprox.)"; the agent states the demand
before the owner commits; and a player in his last six months may talk to other clubs.

So the range is **not** worked out from age, ability, position or league. The owner was told this and chose the
approach below on 25 November 2026.

## Goals

- A top row of eight pills and a "More" pill, on one line wherever twelve fit today (revised during the build: the
  first text said nine, against the eight that section 1 lists).
- A count on the Contracts pill that he sees from every screen.
- A list of the players worth renewing, soonest first, each with the facts he weighs a renewal on.
- For each of them and for each pasted candidate, a range that says where it comes from, and a plain verdict on
  a figure (the agent's, typed; or a candidate's present wage) set against it.

## Non-goals

- A record of negotiations that measures the shares in the owner's own save (the research's candidate C). It
  can be added later on the same screen.
- The whole cost of a contract (signing-on fee, agent fee, yearly rises, appearance fees).
- Advice on contract length, clauses or playing time to offer.
- A typed quote for a pasted candidate: candidates are held in memory only.
- A command for it on the command line (left to the builder, below).

## Anti-goals

- Predicting what a player will ask. Nothing shown may read as a forecast of a demand.
- A range that looks measured. Everything but the club's own limits says "this tool's estimate" and names what
  it rests on.
- A number worked out from ability, reputation, age or value. The research's measurement contradicts it.

## Approaches

**The menu.** (A) One "More" pill that opens a menu, showing the current screen's name when it is one of the
five. (B) A "More" pill that opens a second row of pills. A sidebar was dropped: it breaks the Tactics-board
look. The owner chose A.

**The notice.** (A) A count on the Contracts pill. (B) A notice after an import. (C) The screen alone. The owner
chose A.

**Who is wanted.** (A) The tool works it out from the marks and Player Removal's advice, and he can dismiss a
player. (B) He marks the players to keep himself. The owner chose A.

**The range.** (A) What the owner's players in the same tier are paid now, alone. (B) The same, capped by a
share of his typed wage budget and by his Max Wage, with a verdict on a typed quote. (C) B plus a record of
negotiations. The owner chose B.

## 1. The menu

- `Screen` gains `contracts`, after `removal`. The row shows, in order: Squad, Fixtures, League, Match
  Selection, Training, Removal, Contracts, Scouting, then the "More" pill.
- The menu lists Tactics, Elevens, Rest, Offers and Settings, in that order. Which screens are in the menu is
  Core's (`Screen`), not the view's.
- The "More" pill reads "More" while a row screen is shown. While one of the five is shown it reads that
  screen's title and is drawn as the current pill. It carries a small mark that it opens a menu.
- Everything that already leads to one of the five (a notice's button to Settings, "Go to Fixtures" and the
  like) works as before.
- "Removal" stays shortened on its pill (this design's call).

## 2. Who is listed on Contracts

A player is listed when all of these hold. Each is this design's call unless marked the owner's.

- He is in a squad held and is the club's own: a player on loan here is never listed; one out on loan is.
- He has no mark to sell or to loan out, and Player Removal does not advise releasing, selling or terminating
  him (`RemovalReport.advisedToLeave`). The owner's choice A. A loan for matches and "watch" are not removals,
  so those players are listed.
- He is in his last year: with a contract end day, that day is within 12 months of today in the game (so the
  list moves with the date); without one, his months left at the import are 12 or fewer. A player with no
  contract to run down (out of contract, or months left below zero) is listed in a part of his own. With an end
  day, one rule sets both the part and the day the timing line names: he is in his last year from the end day
  less 12 months, and approachable from the end day less 6 months, each clamped to the end of a shorter month
  (revised after the whole-branch review: the part had been read from today plus the months, so for a contract
  ending on the 29th to 31st "can approach him from" named a day up to three days before he moved).
- A player on a youth contract (his contract type, whatever his months left; revised after the whole-branch
  review: `Removal.isOnYouthContract` is false at 0 months, which Player Removal reads as no contract, and FMRTE
  rounds months down, so for the whole last month every youth-contract player was listed and counted on the
  pill) or with no contract to run down is listed only
  when he is in the first or second eleven for the primary tactic or Player Removal calls him worth
  developing (`Removal.isWorthDeveloping`). The owner's choice of 25 November 2026: without it the count
  would be mostly youth-team players. One of them out on loan, who has no advice, is listed only when his
  best level (section 4) is would start or would make the second eleven. Everyone on any other contract is
  listed whatever his standing.
- The owner has not dismissed him.

The advice is worked out for the primary tactic, as Player Removal's is, and Contracts stands behind the same
gate as Player Removal. A player out on loan has no advice from Player Removal; he is listed on the other
rules alone.

**Parts, in order**, each soonest end first, the squad book's order on a tie:

1. "Other clubs can approach them now": six months or fewer left (carried over from FM26, official).
2. "In their last year".
3. "No contract": the engine's line says he can leave at any time (carried over from older versions, anecdotal).

Under them one line counts the players in their last year who are left out because they are marked or advised
to go, with a button to Player Removal. Then "Not renewing", closed at every launch behind a line with its
count: the dismissed players, each with "Show again".

**The count on the pill** is the players in parts 1 to 3. It is not shown at 0 or while the advice is not ready.

## 3. A player's row

- His name, with "Not renewing" at the trailing end of the name's line, as "Hide" stands on Scouting. It
  dismisses him at once with no question.
- The Player Removal facts on one line: age, positions, current and potential ability, salary by the year, and
  the day his contract ends or his months left (`PlayerFacts`). Where a player out on loan is, the standing
  line below says, with where he would stand (revised after the whole-branch review: "Out on loan at
  Wallingford" had ended the facts line too, so it was said twice).
- Why he is listed, one engine sentence from his tier and Player Removal's action: "First choice at left back.",
  "Second choice at striker.", "In neither eleven; Player Removal says keep and develop."
- The timing, one engine sentence: "Other clubs can approach him from Thu 31 Dec." before his last six months
  (only with an end day), "Other clubs can approach him now." in them.
- The wage range and its lines (section 4).
- A field, "The agent's figure", typed in FMRTE's wage period like every wage in the app, read by `TypedNumber`,
  with how it was read beside it and the day it was entered; then the verdict's lines (section 5).

A dismissal and a typed figure are kept under the player's key. Both are dropped at an import once his
contract no longer puts him in any of the three parts (he was renewed) or once every squad held has been
imported without him, as a mark is. A player with no contract stays dismissed while he has none.

## 4. The range

**The club's three figures** are typed once at the top of Contracts: "Wage budget", "Wages spent" and "Highest
wage you can offer" (FMRTE's club Finances page: Wage Budget, Wage Used, Max Wage (aprox.)), labelled in
FMRTE's wage period, kept by the week, shown with how each was read and the day entered. Each is optional; a
blank one is simply not used.

**A player's tier** for the tactic: first eleven, second eleven, or neither.

- One of the owner's players: his `SquadTier` in the elevens of the whole squad for the tactic (the Elevens
  screen's own, which Player Removal uses).
- A pasted candidate: his best level today at any slot of the tactic he is judged at, as Scouting judges it
  (against the players who stay). Would start is the first eleven; would make the second eleven is the
  second; would count as cover and below cover are neither. It is his best level, not his headline slot's,
  so a player headlined as cover at one slot who would start at another is not priced as a backup; the line
  names the slot ("He would start at right back.").
- A player out on loan: rated at each slot of the primary tactic where his familiarity is 10 or over in both
  phases, as a pasted player is, against the first and second choice of the whole squad's elevens, and given
  his best level by the same four tests. Contracts does not use Scouting's needs or its staying squad.

**The tier's wages** are always read from the whole squad's elevens for the tactic, on Contracts and on
Scouting alike ("what your first eleven are paid now"), whoever is going. They are the wages of the club's
own players in that tier who are paid a wage above 0 and are not on a youth contract (whatever its months
left, 0 included; revised after the whole-branch review), the player himself left out. Players on loan here are left out (the
wage pasted is not the owner's cost). With fewer than 3 such wages the squad gives no range for the tier.

**The range** is from the lower quartile of the tier's wages (the median of the lower half, the middle value
left out of both halves when the count is odd) to the highest of them. With a single wage, possible only when the
fewest wages is set to 1, the lower quartile is that wage (revised during the build: the lower half is then empty).

**The ceiling**, when the wage budget is typed, is the tier's share of it: 7.5% for the first eleven, 2.7% for
the second eleven and for neither. For the first eleven the line also gives 4.3%, since the rule keeps 7.5%
for four key players and gives the other seven starters 4.3%. The shares are one author's rule of thumb from
an article on Sports Interactive's site for FM23 (30% of the budget to four key players, 30% to seven
starters, 30% to eleven backups, 10% to the youth team), not a mechanic.

**The limit** is the highest wage he can offer. **The budget left** (wage budget less wages spent, never
below 0; for one of his own players his present wage is added back, since a renewal replaces it) is shown
beside it and is not a limit: the research found his club with none of its budget free on day one, and the
game lets a manager move money into the wage budget.

The top of the range is the smallest of the tier's highest wage, the ceiling and the highest wage he can
offer, each only when known. When that is below the lower quartile, there is no range, only "up to" that
figure, and the line says which cap set it. With no squad range and a budget typed, the ceiling alone is
shown. With neither, the line says no range can be given and asks for the wage budget; the highest wage he
can offer, when typed, is still given on its own line and makes no range by itself.

The lines, in the engine's words, with money through the squad book's `moneyStyle`:

    Most of your second eleven are paid $2,786 to $3,905 a month. (this tool's estimate of a reasonable range)
    A backup's share of your wage budget is $1,870 a month by one rule of thumb. (this tool's estimate)
    The most you can offer one player is $6,500 a month, and $2,140 a month of your wage budget is left.

The wording is the builder's to settle within those facts; each line names its source. Since the range starts
at the lower quartile, a line that gives it as what the tier is paid says "most of" ("Most of the rest of your
second eleven are paid …", "from what most of your second eleven are paid up to …", "below what most of your
second eleven are paid, $2,786 to $3,905 a month"), and every sentence says "are paid" of a tier (revised after
the whole-branch review: "Your second eleven are paid $2,661 to $7,483" was false for the quarter paid less, a
player in it being paid $1,912). Where both ends are written alike, "are all paid $3,269 a month" stays, since
it is true.

## 5. The verdict on a figure

For one of the owner's players the figure is the agent's, typed. For a pasted candidate it is his present wage
from the paste, with nothing typed. The engine gives these lines, in this order, each only when it applies:

1. It cannot be offered: above the highest wage he can offer. Stated as fact, not as an estimate.
2. It is above the tier's ceiling.
3. Where it falls against what the tier is paid, uncapped (lines 1 and 2 speak for the caps): above the
   tier's highest wage, from the lower quartile to the highest, or under the lower quartile. Left out when
   the tier has fewer than 3 wages.
4. It is more than the wage budget has left, by how much; a fact that calls for moving money or wages, not a
   refusal. Given only when both budget figures are typed.
5. For a renewal, how many times his present wage it is ("2.4 times his wage now"), as a fact with no
   judgement; left out when he is paid nothing.

For a candidate the lines end with one saying that what he would ask here is not known and that the agent's
figure is the one to check before bidding. A candidate paid no wage gets the range and that line only. A paste
in another currency than the squads' gets the range and a line saying the two cannot be compared; a paste in
another wage period is compared by the week.

Nothing here changes a candidate's level, part, order or cautions, or any other advice.

## 6. On Scouting

Each candidate's opened row carries the range for his tier, for the tactic shown, and the verdict on his
present wage. When line 1, line 2 or "above the tier's highest wage" applies, that line is also shown on the
closed row, in the caution style, so an expensive player is seen without opening him. The budget left never
puts a line on the closed row. The
evidence note on the Candidates tab gains the wage note's sentence. A hidden candidate has none of it.

## 7. The words and the evidence

Every sentence is the engine's (`Reporting/AdvisorText+Contracts.swift`), shown as written. An evidence note
stands at the foot of Contracts: the range is what the owner's own players are paid, not what a player will
ask; no test in any version says what a player asks; the shares are a rule of thumb for FM23; the limits are
the figures he typed from FMRTE (revised after the whole-branch review: the budget left is worked out, not
FMRTE's own); the six months are the game's rule.

Every number is one entry in `EngineParameters` (`wageRangeRules`), labelled derived, with a source saying
which rests on what: 12 months, 6 months, the three shares, the fewest wages for a range (3). Its problems are
checked with the others.

## 8. Where it lives

- Engine: `Advisors/Contracts.swift` (who is listed, the parts, the timing) and `Advisors/WageRange.swift`
  (the tier's wages, the range, the ceiling, the limits, the verdict), each a function of the data it is
  handed, with a test where each rule changes an outcome and one where it does not.
- Core: `ContractsState.swift` (the three figures with their day, the dismissed players, the typed figures),
  saved as `contracts.json` through `Store` like the others (absent is no notice; an unreadable file gives a
  notice and a fresh start and is kept aside; state from before it opens with no notice);
  `AppModel+Contracts.swift` for the actions, none of which plans or works other advice out again;
  `ContractsPresentation.swift` for the rows and the count.
- Views: `Advice/ContractsScreen.swift`, the "More" pill in `Board/BoardFrame.swift`, the candidate's line in
  `Advice/ScoutingCandidatesTab.swift`. Every colour and measure from `Theme`.
- "Not renewing" and "Show again" each take a row away, so both are ignored within half a second of the last
  of either, as Scouting's "Hide" is.

## 9. Tests and pictures

Sample data gains a case with players in each part, a dismissed player, the three figures typed and an agent's
figure typed. Pictures, looked at before the screen is called done: the top row with the count and with the
"More" pill naming a menu screen; Contracts empty (nobody in his last year), filled, with no figures typed,
with a figure that cannot be met, with "Not renewing" open, at the smallest window; Scouting's candidates with
the wage line on a closed row and in an opened one. The open menu and the look of the buttons are left to the
owner in the running app. (Revised during the build: no date empties either sample, so the empty picture is drawn
with every listed player set aside.)

## 10. Limits to say in the plan's closing sections

- The range is what his club pays now. After a promotion it runs low until wages are renewed or the budget is
  typed again; the ceiling moves with the budget, the squad's range does not.
- A tier has at most eleven wages, fewer once youth contracts and the player himself are left out.
- Whether FMRTE shows the club's wage figures in the period of its wage setting is not known (the same doubt
  as on Offers).
- Whether the wage budget also covers youth and non-playing staff is not known, so the shares may be generous.
- Without the expiry-date column the last year is counted from months left at the import, rounded down by
  FMRTE.
- A player out on loan is listed without Player Removal's judgement of him.
- The count on the pill reads the advice, so the advice is worked out whenever the top row is drawn after a
  change; the builder checks this does not slow an import or a launch that anyone would notice.

## Left to the builder

- Whether `advise` on the command line prints a Contracts part.
- The engine's exact sentences, within the facts each section names.
- How the count is drawn on the pill and what VoiceOver says of it, from `Theme`.
- The type the three figures are kept in (a new one, or part of `ClubFigures`).
- CLAUDE.md's new entries when the build is done.

## This design's calls, for the owner to check

1. "Last year" is 12 months, by the end day when the grid has it, else by months left.
2. Players with no contract are listed, in a part of their own, and counted, under the owner's rule for them
   and for youth contracts (in an eleven or worth developing).
3. A player out on loan is listed; one Player Removal says to watch is listed.
4. A dismissal and a typed figure are dropped once he is renewed or gone.
5. The range runs from the lower quartile to the top of what the tier is paid, and needs 3 wages.
6. The first eleven's ceiling is the key player's 7.5%, with the starter's 4.3% named beside it; the second
   eleven and everyone else take the backup's 2.7%.
7. Youth-contract wages are left out of every tier's wages.
8. On Scouting the wage line is on the closed row only when the candidate's present wage is over the highest
   wage he can offer, the ceiling or the top of the tier.
9. Player Removal keeps its "renew it" line.
10. Only the highest wage he can offer is a limit. The budget left is shown and compared, never a refusal.
11. A candidate, and a player out on loan, is priced at his best level at any slot, not his headline slot's.
12. A tier's wages come from the whole squad's elevens, on Scouting too, though a candidate's level is judged
    against the players who stay.
