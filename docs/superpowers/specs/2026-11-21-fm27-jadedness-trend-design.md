# FM27 Lineup Optimizer: each player's jadedness trend, measured from the imports

Date: 21 November 2026
Status: written for the owner's approval; not built. A reviewer read it as a builder on 21 November 2026, and its five questions are answered in the text (how a match is tied to a reading, when a rate counts as measured, the mixed cases on the Rest screen, the rest rule without measured rates, the jadedness steps). He chose the approach (the third of three, below) on 21 November 2026. Everything marked "this design's call" is the builder's, and is his to change.

Research: `docs/Research/fm27-jadedness-and-holidays.md` and `docs/Research/fm27-training-intensity-by-condition.md`, both of 21 November 2026.

## Intent

The owner's two most-used players were called "Very tired after last match" by the game, and he has had to send players on holiday more than once. He asked for one of two things: to be told the game's advice can be ignored, or for the tool to rotate players so they never get that tired.

The tool saw nothing wrong with either player, and could not have:

- Their jadedness was 183 and 108. The tool marks a player down only above 200 and leaves him out only above 400.
- The rule on a run of starts counts starts four days apart or less. The owner plays once a week.
- The projection expects jadedness to fall by about 50 in a week with one match (+60 a match, −16 a day at high training intensity). In the owner's save it rises for nearly everyone.

What the research and the save show:

- **No test in any version shows a cost under 400.** The game's own jaded status was seen at 401 and not at 400. "Very tired after last match" is taken to describe condition after a match, which clears in days; that is this design's reading of the wording, untested.
- **The one FM27 measurement is of recovery.** Over the same rest from 75% condition a player at jadedness 0 reached 95.7%, at 500 reached 92.3% and at 1,000 reached 86.9%. From −500 to 0 nothing changed.
- **The rates the tool carries were measured on full rest days.** Training adds jadedness, by an amount nobody has published for FM27.
- **In this save training, not matches, does most of it.** The game puts players at −500 over the summer. By 5 October first-team players with no start had risen by 200 to 300; the regular starters by 430 to 680; the U18s, who play no first-team matches, were the most jaded squad the owner has (73 to 196). A rough fit gives about 290 from the weeks alone and about 17 for each start. So leaving a player out of matches cannot, in this save as it is trained now, hold him under 400.

So neither of the owner's two answers is right as asked. Below 400 the game's message can be left alone, but his players are on course to pass 400 this season, and rotation alone will not stop it. The tool should measure what is happening to each player, say so, say which lever works, and plan with the measured rates.

## Goals

1. The app keeps each player's jadedness, condition and sharpness at every import, and works out from them how fast his jadedness moves: for each start, and for each day without one.
2. The plan projects jadedness with those rates in place of the fixed ones, and slows condition recovery above jadedness 0 as FM27 measured.
3. Where a match off would keep a player from being jaded for a coming fixture, the plan rests him in the fixture where that costs least, before he reaches 400, and says why.
4. The Rest screen shows each listed player's trend, when he is on course to pass 400, what a match off would save, and, when rest from matches cannot bring him down, that training is what to change.
5. The Rest screen says what the game's tiredness messages mean and when a holiday is and is not called for.

## Non-goals

- Substitutes. The plan still assumes each starter plays 90 minutes and nobody else plays. A substitute's minutes are inside his measured drift (below), which is why they need no entry by hand. Counting substitute appearances towards "getting his matches" in Player Removal and the planner's four starts a month is a separate change, not made here; FMRTE pastes the counts.
- Learning condition recovery or sharpness for each player. Only the measured slowing above jadedness 0 is added.
- Rest's levels and each player's own limit (the ages, Natural Fitness, Stamina and Injury Proneness changes). They are carried over from FM26 with no evidence in any version, and stay as they are.
- Reading the game's training settings, or advising on them beyond the sentences below. The settings to enter are in the training research.
- Predicting injuries.

## Anti-goals

- Advice to rest a player from matches when the measured rates say that will not bring him down.
- A player rested earlier than the evidence supports. Under 400 nothing is known to be lost by playing him, so a match off under 400 must buy something named: a coming fixture he would otherwise miss.
- A measured rate shown as a fact. Every trend line says how many readings it rests on, and that it is this tool's estimate.
- A plan that changes because readings exist but are too few to measure from.

## Approaches

1. **Explain only.** Rest says what the game's messages mean. Nothing changes in who is picked, and nobody is warned before 400.
2. **Correct the fixed rates.** Training days add, rest days remove. The size of the training effect would be a guess from two of the owner's readings, and it differs by player and by squad.
3. **Measure each player's trend from the imports (chosen).** No guess about training, age or substitutes: whatever moves his jadedness is in the readings. Against: it needs four imports before it says anything, and a change of training takes weeks to show unless the owner says to measure again.

The owner chose 3 on 21 November 2026.

## 1. Readings

A **reading** is one player on one import day: the day, his jadedness, condition and sharpness, whether he was injured, and **the matches it includes** (`includes`): the fixtures of the confirmed lineups that were waiting for his squad's import at that moment (the `awaitingImport` mark on a history record), taken before the import clears the mark.

- A second import of a squad on the same day replaces that day's reading and keeps the fixtures of the one replaced as well as its own.
- Readings are kept for 120 days (this design's call: nearly three times the window below) and older ones dropped when a reading is recorded.

The type is the engine's (`FitnessReading`, Codable). The app keeps the readings; the engine is handed them with the confirmed lineups.

## 2. Rates

**Which reading a match belongs to.** A confirmed lineup belongs to the first of a player's readings that is dated after it, or that includes its fixture. So a match on an import day counts as before or after the import as the app knew at the time, and a match dated before a reading always counts by that reading. Starts are counted from the confirmed lineups each time the rates are worked out, not when a reading is taken, so a lineup confirmed late or changed after an unlock is counted as it now stands.

An **interval** is two readings of one player with no reading of his between them. Its **starts** are his starts in the lineups that belong to the later reading. It is used when all of these hold:

- the later reading is no more than 42 days before the day the rates are asked for (the window);
- both readings are on or after the day the owner said to measure from, when he has (section 7);
- the readings are 1 to 14 days apart;
- he was injured at neither;
- neither jadedness is at the floor (−500), where the game holds a rested player.

Its **change** is the later jadedness less the earlier, and its **days** the days between. A **rest interval** has no start; a **start interval** has 1 or more.

**His trend as seen** needs no model: the sum of the changes of his used intervals over the sum of their days, times 7, with the starts in them. It is given when he has at least 3 used intervals (four imports).

**Drift**, the change for each day without a start:

- A rest interval's rate is its change over its days.
- A player's own drift is the median rate of his rest intervals, when he has at least 3.
- His squad's drift is the median rate of the rest intervals of every player imported in the same squad (first team, U21, U18), when there are at least 5 and they end on at least 3 different days.
- He takes his own, else his squad's, else none.

**Gain**, the change for each start:

- A start interval's gain is (its change − the player's drift × its days) ÷ its starts, with the drift he takes above. An interval of a player with no drift gives none.
- A player's own gain is the median over his start intervals, when he has at least 3.
- The club's gain is the median over every player's start intervals, all squads together, when there are at least 5 and they end on at least 3 different days. (A start is a start for the first team whichever squad he is imported in, and the youth squads alone would never have five.)
- He takes his own, else the club's, else none.

**A measured pair.** A player has measured rates when he has both a drift and a gain. They are used together or not at all: with either missing, the projection uses the two fixed figures the engine has now (`jadednessPerMatch`, and `jadednessRecoveryPerDay` scaled by training intensity, as a fall), never one measured and one fixed. Each rate says where it came from (his own and from how many intervals, his squad's, the club's).

A median of an even number of values is the mean of the middle two; values are sorted by value and then by player key and day, so the same readings always give the same rates. Nothing is clamped: a median already sets aside the odd interval with a holiday, a match the tool was not told of or a long lay-off.

One function works all of this out for every player at once (`FitnessTrend.rates`, handed the readings, the confirmed lineups, each player's squad, the day, the measure-from day and the parameters). It returns each player's trend as seen and his measured pair, where he has them, and each squad's drift and the club's gain, for the Rest screen.

What is inside the drift, unnamed: training, rest days, minutes as a substitute, matches for another of the club's sides, and whatever age does. That is the point of measuring it.

## 3. The projection

`FitnessProjection` is handed a player's measured pair, when he has one.

- A start adds his gain (in place of `jadednessPerMatch`).
- A day without a match adds his drift, which may be above or below zero (in place of the fixed fall).
- With no measured pair both fixed figures are used, as now.
- Jadedness stays within −500 and 1,000.
- A day's condition recovery is multiplied by a factor for his jadedness at the start of that day: 1 up to 0, 0.832 at 500, 0.574 at 1,000, in straight lines between. These are FM27's measured recoveries (2,074, 1,725 and 1,190 from 7,500 over the same rest; Fishi, fm-arena, 13 November 2026). The label is derived: four values from one table, measured over one rest of unstated length and applied here day by day.

The planner hands the rates to every projection it makes: fixture to fixture, the matches played since the last import, and the saving of players for bigger fixtures. The slowing of recovery applies to every player, measured pair or not.

## 4. The jadedness factor

`jadednessSteps` loses its step at 200: a player is rated at ×1.00 up to 400. The steps above (×0.70 to 700, ×0.40 beyond) and the rule that leaves a player above 400 out of all but high-importance matches are unchanged.

Why: the ×0.90 from 200 to 400 came from the old Python with no source. No test in any version shows a cost under 400, and in FM24 a whole eleven held at 400 for a season lost 2.4 points, about a third of what five points of condition cost. What jadedness under 400 does cost, slower recovery and the approach of the line, is now counted where it falls (sections 3 and 5). This is this design's call, and it changes lineups from the day it is built for any player between 201 and 400.

There is one set of engine parameters, and the port check does not read jadedness, so the entry itself changes: its label becomes derived, the weakest of what it now rests on, its source says which step rests on what, and the tests that pin it to the old Python's table are changed with it.

## 5. Resting before the line

A new adjustment in the planner, applied where saving players is, and scaled by the same Saving players setting (at 0 it does nothing).

It applies only to a player with a measured pair. With the fixed figures, which the owner's save shows are wrong in direction, nobody is rested by this rule.

For such a player considered for a fixture F, with his projected jadedness before F:

1. Take the fixtures after F that the planner hands the saving rule. Project his jadedness before each, twice: **starting** F and every later one, and **resting** F and starting every later one. A fixture the owner has rejected him for is one he does not start, in both.
2. Find M: the first later fixture, of importance other than high, before which the starting projection is above `jadedThreshold`. With none, no cost.
3. If the resting projection is also above the line before M, no cost: a match off now does not save him. (Rest says so; section 6.)
4. If he is not in M's first eleven, or has no advantage there over the second-eleven player, no cost.
5. Otherwise the cost of starting him in F is his advantage at M × the importance weight of M ÷ that of F, times the setting, capped as the saving cost is.

The reason is the engine's: "Rested before he passes 400: at about +31 a start, starting today would leave him jaded for Buxton on Sat 14 Nov." The figure 400 is `jadedThreshold`, and the gain is the one he takes.

- Where this rule and the saving rule's "would break a risk rule" both name the same later fixture, only the larger cost is kept.
- The owner's choice of a player still beats every adjustment.
- The fixtures are taken in date order, so he is rested in the first fixture where his advantage is worth less than the weighted loss at M, not always the cheapest of all. If no fixture rests him, he reaches M jaded and is left out there, which is then the cheapest.
- It is a new `Adjustment` kind, after `savedForLater` in the order.

## 6. Rest

`Rest.advice` is handed what `FitnessTrend.rates` returned.

**Who is listed.** As now, and also, at the level watch, a player whose trend as seen is rising and would take him past `jadedThreshold` within 42 days: (400 − his jadedness) ÷ his weekly rise, in weeks, is 6 or fewer. The listing rests on his own readings alone, so no half-measured rate lists anybody.

**Each listed player's lines**, in the engine's sentences (`AdvisorText`), with the evidence note "this tool's estimate":

- His trend as seen: "Rising about 45 a week over the last 5 weeks, in which he started 6 matches (from 6 readings)." ("Falling about …", or "Holding steady over the last 5 weeks, …" within 5 a week either way; "in which he did not start a match" with none.)
- "At that rate he passes 400 around Sun 7 Nov." Only when rising, and only within 120 days.
- What a match off would do, only when he started a match in those weeks and has a measured pair:
  - with a drift below 0: "Without a start he falls about 30 a week, and a start adds about 61, so a match off saves about 61.";
  - with a drift of 0 or above: "He rises about 16 a week without a start, so leaving him out of matches will not bring it down. Lighter training, or rest from training, will."
  - Either says where a rate is not his own: "(the first team's rate without a start; his own rate for a start)".
- When he is rising and did not start in those weeks: "He has not started a match for you in that time: the rise is from training and any matches for another side."
- With no trend as seen: "His trend is not measured yet: it needs 4 imports of his squad, and has 2."

**Days until clear.** For a player over his limit the estimate uses the drift he takes (his own or his squad's) when he has one and it is below 0. When it is 0 or above there is no estimate, and the "will not bring it down" sentence is given in its place whether or not he started. With no drift the carried-over rate is used, as now. The holiday estimate keeps its carried-over rate.

**Each squad, above the rows**, when its drift is measured: "First team: a player who does not start rises about 16 a week (from 38 readings since Tue 24 Aug; this tool's estimate)." ("falls about", "holds steady".) When the club's gain is measured, one line for the club after the squads: "A start adds about 31." When a squad's drift is 0 or above, a caution under its line: "At this training load, leaving players out of matches cannot bring jadedness down."

**What the game's messages mean**, a note at the foot of the screen, each line with its evidence:

- "'Tired after last match' and 'Very tired after last match' describe condition after a match and clear in days. They are not a reason for a holiday. (this tool's reading of the wording)"
- "The game calls a player jaded above 400. No test in any version shows a cost below that; above 0, condition comes back more slowly. (FM27 tests)"
- "A holiday costs about 0.5% of sharpness a day and the matches missed. A full rest day after each match, and lighter training below full condition, cost less. (FM27 tests; the holiday's effect is carried over from FM24)"

The existing reasons and levels are unchanged.

## 7. The app

**Kept.** A new file through `Store`, `fitness.json` (`StoreFile.fitness`, `FitnessState`): the readings for each player, and the day to measure from, absent until the owner sets it. Its absence is no notice. Saved state from before this design opens with no notice and no readings.

**At an import** the app records a reading for each player of the imported squad, on the game's date, before the import clears `awaitingImport`. It then plans again, as an import does now.

**The rates** are worked out in Core from the state each time a plan or the advice is worked out, and handed to the planner (`PlanRequest`) and to the advisors. They are not saved.

**Rest screen** (`RestPresentation`, the Rest views): the squad lines under the heading; each row's trend lines under its reasons; the note at the foot. A line under the heading says what is measured from when ("Trend measured from Tue 24 Aug.") with a button, "Measure again from today", for when the owner changes training in the game: it sets the measure-from day to today in the game, saves the file, plans again and clears the kept advice. It asks first, since nothing is then measured until four more imports. It is offered once any reading is kept. (This design's call: without it a change of training takes about three weeks to show in a six-week median.)

**Match Selection** shows the new reason where it shows the saving reason, as written.

**Settings.** The Saving players slider keeps its name; its explanation gains "and resting them before they are jaded" (Core's label).

**Command line.** `plan` and `advise` take `--fitness-readings <file>`, a JSON object from a player's key to his readings, described at the top of `main.swift`. Without it the fixed figures are used and no trend is printed. `advise` prints the squad lines and the trend lines in its Rest part.

**Pictures**, in `.build/pictures-trend`: the Rest screen with trends falling (`rest-trend-*`), with a squad whose drift is above 0 and the caution (`rest-trend-rising-*`), with nothing measured yet (`rest-unmeasured-*`), and Match Selection with a player rested before the line (`match-restdue-*`). The sample data needs readings to draw them.

## 8. Parameters

One new entry, `jadednessTrendRules`, labelled derived (this design's choices, none tested), holding: the window, 42 days; the longest gap between two readings, 14 days; the fewest intervals for a player's own rate or trend, 3; the fewest for a squad's drift or the club's gain, 5, ending on at least 3 different days; the days ahead within which a player on course is listed, 42; the band called steady, 5 a week; the days readings are kept, 120. Its source says which is which.

Also: `conditionRecoveryByJadedness`, the four points of section 3 (derived, anchors FM27 measured); `jadednessCeiling`, 1,000 (FM27 observation, the editor's range); and `jadednessSteps` changed and relabelled as in section 4.

`FitnessModel.problems` checks the new entries (counts of 1 or more, days of 1 or more, a curve that does not rise, factors from 0 to 1). `EngineParameters` stays under its size limit.

## 9. Tests

The engine's rules for tests hold: for each rule a test where it changes an outcome and one where it does not. In particular:

- An interval left out for each of the five reasons in section 2, and one kept.
- A match on an import day counted before the import when the reading includes its fixture and after it when it does not; a lineup confirmed after a later import counted by date; a lineup changed after an unlock counted as it now stands.
- Own rate with 3 intervals and with 2 (falls back to the squad or the club); a squad's drift with 5 intervals on 3 days, with 4, and with 5 on 2 days (none); the club's gain the same; a drift with no gain, and a gain with no drift, give no measured pair and the fixed figures.
- The same readings in another order give the same rates.
- The projection with a measured pair, with none, at the floor and at the ceiling; recovery at jadedness −500, 0, 250, 500 and 1,000.
- Resting before the line: rests him in the cheaper of two fixtures; no cost when a match off does not save him; no cost when M is high; no cost at Saving players 0; no cost for a player with no measured pair; the larger of the two costs when the saving rule names the same fixture; the owner's choice still starts him.
- A player at 300 is rated the same as at 100.
- Rest: listed when on course within 42 days and not at 43, and not on a squad's rate alone; each sentence, with each mix of where the rates came from; no estimate of days when the drift is above 0.
- The app: a reading recorded at an import with the fixtures then waiting, taken before the mark is cleared; a second import the same day; readings older than 120 days dropped; state from before opens with no notice and plans as it did, the changes of sections 3 and 4 aside; "Measure again from today" leaves the kept readings in the file and takes them out of the rates.

## 10. Limits to say in the plan's closing sections

- Nothing is measured until a squad has been imported four times; until then the plan uses the fixed figures, which the owner's save shows are wrong in direction, and rests nobody before the line.
- A regular starter has no rest intervals, so his drift is his squad's: what a match off would save him is partly the squad's figure, and the line says so.
- A change of training shows slowly unless the owner presses "Measure again from today".
- A match played and never confirmed, a holiday and a lay-off each spoil one interval; the median sets aside a few, not many.
- Jadedness is taken to move at the same rate at every level; whether it clears faster from higher up is untested.
- The 400 line was read off five prime-age players. Whether the game's status comes earlier for teenagers or players over 30 is untested.
- Substitutes are still not planned for.

## Left to the builder

- Where the new types and functions live, and their names beyond those given.
- Whether the new adjustment is computed inside the saving rule or beside it.
- The Rest screen's layout, within the visual direction, checked in the pictures.
- The readings the sample data carries.
- The JSON format of `--fitness-readings`.

## This design's calls, for the owner to check

1. The ×0.90 between 200 and 400 goes (section 4).
2. The plan rests a player only when a match off keeps him from being jaded for a named fixture (section 5); it never rests him just for being high.
3. "Measure again from today" (section 7).
4. Six weeks of readings, and four imports before anything is measured (sections 2 and 8).
5. Substitutes are not entered by hand (non-goals).
