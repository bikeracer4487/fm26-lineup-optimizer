# FM27 Lineup Optimizer: keeping earlier matches out of the way

Date: 20 November 2026
Status: written for the owner's approval. He chose the approach (the first of three, below) and said he has no reason to go back to old fixtures. Everything marked "this design's call" is the builder's, and is his to change.

## Intent

After a full season the owner has over 50 confirmed fixtures. Fixtures and Match Selection list every one, and nothing in the app knows what a season is. He wants earlier seasons out of the way on those two screens, and does not need to browse them.

The advice counts confirmed matches no further back than 60 days (`matchesHereWindowDays`; the planner's month and the crowded-schedule rule are shorter). The stability rule reads a player's last few starts whatever their age, so nothing is deleted.

## Goals

1. Fixtures and Match Selection show the matches of the last 60 days and every match still to play, and no others.
2. A new season needs no action from the owner: last season's matches drop out of view as the game's date moves on.
3. The owner is told that matches are hidden, how many, and can see them when he wants to.

## Non-goals

- A season as a thing the app knows: no season list, no season picker, no archive.
- Deleting old fixtures or confirmed lineups, by hand or by rule.
- Any change to a lineup, a plan or a piece of advice. The planner and the advisors are handed every fixture and every confirmed lineup, as now.
- The League screen, the league table and the command line.

## Anti-goals

- A match hidden with nothing on screen saying so.
- A match that is planned, or still to be played, hidden.
- A lineup or a suggestion that differs because matches are hidden.

## Approaches

1. **Show only the last two months (chosen).** A rule on what the two screens show, measured from today in the game. Nothing deleted, nothing to press, and it trims the current season as it goes, so the starts grid stays narrow all year. Against: by March the owner no longer sees August without pressing "Show", and the files keep every match.
2. **A "Start a new season" button** that deletes everything before today but the last few lineups the advice reads. Really removes them, but cannot be undone, has to be remembered each summer, and within a season the lists still grow to 50.
3. **Find the season from the summer gap** in the fixtures. Shows the whole current season with nothing to press, but it is a guess a gap in the entered fixtures could fool, and the lists still grow to 50.

The owner chose 1 on 20 November 2026: it fixes the clutter he has now and next season's, and risks nothing.

## The rule

A match is **earlier** when its date is before the first day of the window, and it is not planned. The window is the 60 days ending today in the game, today included, so its first day is today less 59 days: the same count the engine uses for `matchesHereWindowDays`, and the number is read from that parameter, not written again (this design's call: what is shown is then what still counts, and the two cannot drift).

- "Today in the game" is the date in the note at the top of every screen, not the day of the last import (this design's call: it is the date the owner sees and moves).
- Confirmed and never-confirmed matches before the window are both earlier. A missed match more than two months old changes no advice.
- A match with a planned lineup is never earlier, whatever its date. (The plan starts from the last import, which can be before the window if the owner has moved today a long way on without importing.)
- Moving today with "Day before", "Day after" or "Next match" moves the window with it. It is worked out each time it is read; nothing is saved.

## What the owner sees

**Fixtures.** The table lists the matches that are not earlier. While any are earlier, one line stands directly under the column headings, above the scrolling rows:

    48 matches from before Mon 21 Sep are not shown.   Show

("1 match from before Mon 21 Sep is not shown.") "Show" lists every match, and the line becomes:

    Showing 48 matches from before Mon 21 Sep.   Hide

With no earlier match there is no line. The table still opens with the next match in the middle. Everything else on the screen (the League situation menu, "Use it", the editor, deleting) works on whatever rows are listed. A fixture saved with a date before the window joins the earlier ones, and the count says so.

**Match Selection.** The notes across the top and the columns of the starts grid are the matches that are not earlier. With "Show" pressed on Fixtures they are every match (this design's call: one switch for both screens, so "Show" is the way back to an old lineup too; Match Selection has no control of its own).

When the plan is ready but every match is earlier (the summer, before next season's fixtures are entered), Match Selection shows its empty state with a sentence of its own and the button to Fixtures (this design's call):

    No match to play, and none played since Mon 21 Sep. Add the next matches on the Fixtures screen.

**The switch** is held in the model's memory only: off at every launch, never saved.

## Where it lives

- `LineupAppCore`: the window's first day, whether a fixture is earlier, the fixtures the table lists, the plans Match Selection shows, the line's words and its button's, the switch, and the empty state's sentence, with tests. `fixtures`, `history` and `planState` stay whole; everything that plans, advises or reads the league still reads them.
- `LineupAppUI`: the two screens read the filtered lists; the line and its button are layout only.
- `LineupEngine`: no change.
- No change to any saved file. Saved state from before this opens as it did.

## Tests and pictures

- The rule where it changes what is listed and where it does not: a match 59 days before today is shown and one 60 days before is not; a planned match before the window is shown; a match to play is always shown; moving today moves the window.
- The plan and the suggestions are the same with matches earlier as with "Show" on.
- The line's words for none, one and many, shown and hidden.
- Match Selection's chosen fixture, and the fixture shown after confirming, are among those listed.
- A sample with a season of confirmed matches behind it, and pictures of Fixtures (hidden, and with "Show" on), Match Selection's notes and starts grid, and the empty state when every match is earlier.

## Left to the builder

- Where in Core the filtered lists sit, and how the views that read `planState` directly today (`MatchSelectionScreen`, `RootView`) are moved to the filtered list.
- The line's place and tone in the table, to the visual direction, judged on the pictures.
- How the sample with a past season is built.
