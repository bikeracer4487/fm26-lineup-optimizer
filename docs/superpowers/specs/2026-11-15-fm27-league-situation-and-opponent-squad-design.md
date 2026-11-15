# FM27 Lineup Optimizer: league situation and the opponent's squad

Date: 15 November 2026
Status: approved by the owner on 15 November 2026 ("Keep the \"Use it\" button, design approved, write the build plan")

## Intent

The suggested importance of a fixture rests on two things the tool cannot see today.

- **What the league match is worth.** Every league match starts from one value, the one for a club in contention. A match after the title is won is worth far less, and is the place to start young players; a match in a title race or a relegation fight is worth more. The owner asked for a way to say where the club stands.
- **How strong the opponent is.** "Their strength" is a menu of five steps the owner picks by judgement, and nothing helps him pick. He asked to paste the opponent's squad from FMRTE and have the tool set it.

A third request, a recommended game plan for a simulated match on Match Selection, waits for its research (`docs/Research/fm27-match-simulation-game-plans.md`, not yet written) and has its own design after it. It is expected to read the opponent's strength this design records.

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

1. **Average current ability of each side's best eleven, picked the same way on both sides. Chosen.** It needs no tactic for the opponent, uses the game's own measure of a player, and compares like with like.
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
      From Banbury United's squad on 15 Nov 2026: their best eleven averages 74 ability, yours 68.

- **Their club.** The most common club among the pasted players, by the rule the squad book uses for the owner's club. It is shown in the note so the owner can see he pasted the right club. It is not matched against the fixture's opponent name, which the owner typed and may spell differently.
- **The best eleven.** For each side: the players who are not injured and not away on loan (a player on loan at the club counts for it); the goalkeeper with the highest current ability, then the ten outfield players with the highest current ability. The owner's side is every squad he holds, by the same rule. Injuries are as each side's latest paste showed them; pasting again brings the comparison up to date.
- **The comparison.** Their average divided by the owner's. Two lines, in `EngineParameters`, labelled derived, with a source saying no test stands behind them:

  | Their average against the owner's | Strength |
  |---|---|
  | 15% or more above | Much stronger |
  | 5% or more above | Stronger |
  | within 5% | Similar |
  | 5% or more below | Weaker |
  | 15% or more below | Much weaker |

  A ratio is used, not a difference in points, so the lines mean the same in a low division as in a high one.
- **What it sets.** A successful paste sets the draft's "Their strength" and records a reading on the fixture: the club read from the paste, the day (the game's current date), the two averages, and the strength it gave. The reading is shown under the menu in the engine's sentence. If the owner then picks another strength by hand, his pick stands and the reading stays as what the paste found. A later paste replaces the reading and sets the menu again.
- **Refusals.** Each is a plain sentence from the engine, shown in the editor, and none changes the draft:
  - the clipboard is empty, or the importer refuses the rows (its own sentences, as on the Squad screen);
  - the owner has no squad imported;
  - the pasted players are the owner's own club;
  - the pasted rows carry no club (the grid has no club column, or its cells are blank), since the club decides who is away on loan (this design's call);
  - either side has no fit goalkeeper, or fewer than ten fit outfield players.
- **The evidence note on a suggestion.** Unchanged. Once the fixture is saved the strength is the owner's choice, whether he picked it or took the paste's, so the engine's fixture does not record where it came from. The reading's own sentence carries the tool's-estimate label (this design's call).
- **What does not happen.** The squad book, the marks, the mentoring file and the personality readings are not touched. The plan is not worked out again by the paste; saving the fixture does what saving a fixture does now. Wages in a different currency from the owner's raise no warning, since no money is compared.
- **Older files.** A fixture saved before this design has no reading and opens as now.
- **The command line.** No change is required.

## Evidence

- League bases: carried over from FM26 (the old table, never called by the old app; nothing is published for FM27).
- Strength lines (5% and 15%): the tool's own estimate. The game plan research asks what the game itself uses to judge a favourite; the lines may change when it arrives.
- The measure (average ability of a best eleven): the tool's own choice.

## Testing

- Engine, league situation: each situation changes a league fixture's suggestion where its base crosses a line, and does not change a cup, minor cup or friendly fixture; "In contention" gives exactly today's suggestion and reasons; the "bigger match follows" rule reads the situation for the next fixture; "Nothing to play for" gives Sharpness where the Sharpness rule's conditions hold and Low where they do not.
- Engine, opponent: a squad on each side of each line gives the step expected, and one just inside does not; an injured player and a player away on loan are left out, and a player on loan at the club is counted; each refusal gives its sentence; the same inputs give the same reading.
- Core, the table's "Use it": it sets that fixture's importance and plans again; it is not offered on a confirmed or past fixture, where no suggestion line is shown.
- Core: the menu saved and read back; settings from before this design open with no notice as "In contention"; a paste sets the draft and its reading, and nothing is saved until the fixture is; a refusal leaves the draft as it was; a fixture file from before this design opens with no notice; the squad book is unchanged by a paste; no test touches the real clipboard.
- A captured opponent squad as a test fixture, taken with `tools/capture_fmrte_paste.sh` when the owner next has one on the clipboard. Until then the tests use the captures held, with the club's name changed. No real opponent squad has been through the importer, so the build ends with a hands-on check of the first real paste.
- Pictures of the Fixtures screen with the menu, and of the editor with a reading and with a refusal, light and dark, looked at before the work is called done.

## Left to the builder

- The types' names, and how the situation and the reading are handed to the engine and stored.
- How a goalkeeper is told from an outfield player in a paste.
- The exact wording of the sentences.
- Where the reading and a refusal sit in the editor, within the Tactics board direction.
- Whether the Fixtures table shows that a fixture's strength came from a paste.
