# FM27 Lineup Optimizer: league situation and the opponent's squad

Date: 15 November 2026
Status: approved by the owner on 15 November 2026 ("Keep the \"Use it\" button, design approved, write the build plan"). Revised the same day in two places, marked "revised" below, after the captured squads showed two faults; the owner accepted both revisions that day ("Both revisions accepted, go with subagent-driven").

## Intent

The suggested importance of a fixture rests on two things the tool cannot see today.

- **What the league match is worth.** Every league match starts from one value, the one for a club in contention. A match after the title is won is worth far less, and is the place to start young players; a match in a title race or a relegation fight is worth more. The owner asked for a way to say where the club stands.
- **How strong the opponent is.** "Their strength" is a menu of five steps the owner picks by judgement, and nothing helps him pick. He asked to paste the opponent's squad from FMRTE and have the tool set it.

A third request, a recommended game plan for a simulated match on Match Selection, had its research added on 15 November 2026 (`docs/Research/fm27-match-simulation-game-plans.md`) and has its own design to come. It is expected to read the opponent's strength this design records.

## Goals

1. The owner can say what the club's league matches are worth, in one place, and every league fixture's suggested importance follows it.
2. With "Nothing to play for", a league match is suggested Low, or Sharpness where the Sharpness rule already applies, so the young players' favour applies once the owner takes the suggestion.
3. The owner can paste an opponent's squad in the fixture editor, and the tool sets "Their strength" from it and shows the numbers it compared.
4. The owner can still pick "Their strength" by hand, before or after a paste.
5. Saved state from before this design opens with no notice and gives the same suggestions as before.

## Non-goals

- Working the situation out from a league table (position, points, matches left). The owner chose to say it himself: FMRTE exports no table, and the rules for promotion and play-offs differ by league.
- A situation for each fixture. One choice covers every league fixture still to play; the owner changes it when the club's position changes.
- A situation for cups (their round or stage). Not asked for.
- Changing a fixture's chosen importance for the owner. The suggestion is shown as now, and the owner's choice always wins.
- Keeping the opponent's players. Only what the comparison found is kept, on the fixture.
- Reusing a paste for another fixture against the same club. Squads change between the two league meetings; the owner pastes again.
- Working out the opponent's likely eleven, formation or tactic. FMRTE's player grid carries none of it.
- Home or away. A fixture does not record it today; the game plan design may add it.
- The game plan recommendation.

## Anti-goals

- The opponent's players entering the squad book, the plan or any advisor.
- A strength presented as fact. It is a comparison of two averages by lines of the tool's own choosing, and the screen shows the averages so the owner can judge.
- A paste that silently changes something other than the fixture being edited.

## Approaches considered

### League situation

1. **The owner says what is at stake. Chosen** by the owner on 15 November 2026. One choice of four, using the values of the old Python's importance table (`scoring_parameters.py`, `BASE_IMPORTANCE`, written but never called).
2. **The owner enters the table numbers and the tool works out what is at stake.** Dropped: more to type after every match, and the tool would need each league's rules.

### Measuring the opponent

The owner asked for the paste and left the measure to the builder. These are this design's calls.

1. **Average current ability of each side's best eleven, picked the same way on both sides. Chosen.** It needs no tactic for the opponent, uses the game's own measure of a player, and compares like with like. The eleven are the eleven fit players with the highest ability (revised: the approved text asked for a goalkeeper and ten outfield players; see "The best eleven").
2. **Rate the opponent's players with the rating engine at the owner's tactic.** Dropped: it measures how well they would play the owner's system, which they do not play.
3. **Club reputation from FMRTE's club grid.** Dropped by the owner, who asked for the squad; reputation also lags behind a side that has risen fast.

## The design

### League situation

- **The choice.** Four situations, with the base score a league match takes in each:

  | Situation | Base |
  |---|---|
  | Title race or relegation fight | 100 |
  | In contention | 80 |
  | Mid-table | 60 |
  | Nothing to play for | 20 |

  "In contention" is the value every league match has today, and is the situation when none has been chosen, so nothing changes until the owner chooses.
- **The rule.** The importance suggestion takes the situation as an input. A league fixture's base is the situation's value; every other competition is unchanged. The "bigger match follows" rule measures the next fixture with the same situation. The opponent, schedule and Sharpness rules apply after it as now.
- **The numbers.** The four bases live in the importance rules in `EngineParameters`, labelled carried over from FM26, with the old table as their source. The old table gave 100 only in the last ten league matches; this design leaves "when" to the owner and says so in the source.
- **The words.** The engine names the four situations (`AdvisorText`) and gives the reason line, which names the situation when it is not "In contention": "League match, nothing to play for: 20". "In contention" keeps today's line, "League match: 80".
- **Where it is kept.** In the app's settings, as a value that is absent in older files and read as "In contention".
- **The screen.** A "League situation" menu on the Fixtures screen, in the heading row beside "Add fixture", shown whenever there are fixtures. Changing it works the suggestions out again. It does not plan again, since no chosen importance changes.

      Fixtures   [ Add fixture ]            League situation  [ Nothing to play for ▾ ]

- **Taking a suggestion from the table (kept by the owner on 15 November 2026).** Today "Use it" is offered only in the fixture editor, so after choosing "Nothing to play for" the owner would open and save each remaining league fixture. The Fixtures table's suggestion line gains a "Use it" button, which sets that fixture's importance to the suggested one and plans again, as saving the editor does. It is offered wherever the line is shown, for any suggestion, not only league ones.
- **The command line.** `advise` takes `--league-situation` with the four values; without it, in contention.

### The opponent's squad

- **The paste.** The fixture editor has a "Paste their squad" button beside the "Their strength" menu. It reads the clipboard through the same importer as the owner's squads, with the same FMRTE settings file, and hands the players to one engine function with the owner's players. Nothing is saved until the fixture is saved, like every other change in the editor.

      Their strength   [ Stronger ▾ ]   [ Paste their squad ]
      Squad pasted for Banbury United on Sun 15 Nov: their best eleven averages 74.2 ability, yours 68.5,
      which reads as Stronger (this tool's estimate). Left out as away on loan: players at Wallingford.

- **Their club (revised).** FMRTE's team grid, the one a club's squad is copied from, has no club column: it says only which club a player is loaned to. So their club is the most common club among the pasted players when the rows carry one (FMRTE's search grid does), by the rule the squad book uses for the owner's club; otherwise it is the opponent as the owner typed it on the fixture. A pasted player whose "loaned to" names their club is on loan there and counts; one whose "loaned to" names any other club is away on loan and is left out. Names are compared as the squad book compares them (case and spacing do not matter), and nothing looser. Because the owner may have typed the name differently from the game ("Banbury" for "Banbury United"), the reading lists the clubs the left-out players are at, so a player wrongly left out can be seen and put right by correcting the fixture's opponent and pasting again.
- **The best eleven (revised).** For each side: the players who are not injured and not away on loan; of those, the eleven with the highest current ability, whatever their positions. The owner's side is every squad he holds, with loans as the squad book reads them. Injuries are as each side's latest paste showed them; pasting again brings the comparison up to date. The approved text asked for one goalkeeper and ten outfield players and refused a side with no fit goalkeeper. On the day the owner's first team was captured its only goalkeeper was injured and the U21 goalkeeper was away on loan, so that rule would have refused every paste that day. Counting the eleven best fit players is the same on both sides and needs no rule for who is a goalkeeper; it ignores that a side with no fit goalkeeper is weaker than its eleven best players suggest.
- **The comparison.** Their average divided by the owner's. Two lines, in `EngineParameters`, labelled derived, with a source saying no test stands behind them:

  | Their average against the owner's | Strength |
  |---|---|
  | 15% or more above | Much stronger |
  | 5% or more above | Stronger |
  | within 5% | Similar |
  | 5% or more below | Weaker |
  | 15% or more below | Much weaker |

  A ratio is used, not a difference in points, so the lines mean the same in a low division as in a high one.
- **What it sets.** A successful paste sets the draft's "Their strength" and records a reading on the fixture: the club's name as used, the day (the game's current date), the two averages, the strength it gave, and the clubs its left-out players are away at. The reading is shown under the menu in the engine's sentence. If the owner then picks another strength by hand, his pick stands and the reading stays as what the paste found. A later paste replaces the reading and sets the menu again.
- **Refusals.** Each is a plain sentence from the engine, shown in the editor, and none changes the draft:
  - the clipboard is empty, or the importer refuses the rows (its own sentences, as on the Squad screen);
  - the owner has no squad imported;
  - the pasted players are the owner's own: more than half of them are players of his squads, by identity (revised: with no club column there is no club to compare), or rows that carry the owner's own club (added after the whole-branch review);
  - the pasted rows carry no club and the fixture's opponent is still blank, so there is no name to tell a loan there from a loan away (revised);
  - either side has fewer than eleven fit players who are not away on loan (revised).
- **The evidence note on a suggestion.** Unchanged. Once the fixture is saved the strength is the owner's choice, whether he picked it or took the paste's, so the engine's fixture does not record where it came from. The reading's own sentence carries the tool's-estimate label (this design's call).
- **What does not happen.** The squad book, the marks, the mentoring file and the personality readings are not touched. The plan is not worked out again by the paste; saving the fixture does what saving a fixture does now. Wages in a different currency from the owner's raise no warning, since no money is compared.
- **Older files.** A fixture saved before this design has no reading and opens as now.
- **The command line.** No change is required.

## Evidence

- League bases: carried over from FM26 (the old table, never called by the old app; nothing is published for FM27).
- Strength lines (5% and 15%): the tool's own estimate. The game plan research (`docs/Research/fm27-match-simulation-game-plans.md`, added 15 November 2026) found nothing on how the game judges a favourite, so the lines stay as they are.
- The measure (average ability of a best eleven): the tool's own choice. The same research reports FM27 engine tests in which current ability had no measurable effect on results once attributes were held fixed: results come from attributes. Ability is therefore a stand-in for the attributes it summarises, not what the engine reads, and nobody has tested which measure a player can export predicts results best. A measure built from attributes is a possible later change.

## Testing

- Engine, league situation: each situation changes a league fixture's suggestion where its base crosses a line, and does not change a cup, minor cup or friendly fixture; "In contention" gives exactly today's suggestion and reasons; the "bigger match follows" rule reads the situation for the next fixture; "Nothing to play for" gives Sharpness where the Sharpness rule's conditions hold and Low where they do not.
- Engine, opponent: a squad on each side of each line gives the step expected, and one just inside does not; an injured player and a player away on loan are left out, and a player on loan at the club is counted; their club is read from the rows when they carry one and from the name given when they do not; the clubs of the left-out players are listed; each refusal gives its sentence; the same inputs give the same reading.
- Core, the table's "Use it": it sets that fixture's importance and plans again; it is not offered on a confirmed or past fixture, where no suggestion line is shown.
- Core: the menu saved and read back; settings from before this design open with no notice as "In contention"; a paste sets the draft and its reading, and nothing is saved until the fixture is; a refusal leaves the draft as it was; a fixture file from before this design opens with no notice; the squad book is unchanged by a paste; no test touches the real clipboard.
- A captured opponent squad as a test fixture, taken with `tools/capture_fmrte_paste.sh` when the owner next has one on the clipboard. Until then the tests use the captures held: the first team captured with FMRTE's `Id` column as one side and the capture without it as the other, since the two are keyed differently and so read as different players. No real opponent squad has been through the importer, so the build ends with a hands-on check of the first real paste.
- Pictures of the Fixtures screen with the menu, and of the editor with a reading and with a refusal, light and dark, looked at before the work is called done.

## Left to the builder

- The types' names, and how the situation and the reading are handed to the engine and stored.
- The exact wording of the sentences.
- Where the reading and a refusal sit in the editor, within the Tactics board direction.
- Whether the Fixtures table shows that a fixture's strength came from a paste.
