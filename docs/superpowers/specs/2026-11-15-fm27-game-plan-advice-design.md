# FM27 Lineup Optimizer: which game plan to use when a match is simulated

Date: 15 November 2026
Status: built on the owner's word of 15 November 2026 ("I'd like the game plan advice shown in the Match Selection screen"), given after he was told what the research supports. He has not read this text; everything below marked as this design's call is the builder's, and is his to change.

Research behind it: `docs/Research/fm27-match-simulation-game-plans.md`.

## Intent

When the owner simulates a match the game asks for a game plan ("No game plan", "Play for the win", "Play for the draw" and so on). He believes different plans suit different opponents, does not know the rules, and asked for a recommendation on Match Selection.

The research found no test of the plans in FM27. The one test there is, in FM26, ran ten results a plan against a single much stronger side. So the honest recommendation is nearly the same for every match, and the screen says why.

## Goals

1. Match Selection says, for each fixture with a planned eleven, which game plan to use if the match is simulated, which to avoid, and how thin the evidence is.
2. When a measured result arrives (the owner's own test, or a published one), the advice changes in one place.

## Non-goals

- A different plan for each kind of opponent, competition or venue. Nothing measured separates them. The research's own table recommends "No game plan" in every row.
- Home or away. A fixture does not record it, and no evidence turns on it.
- Checking afterwards that substitutes got their minutes. The tool cannot see minutes played.
- The command line. `advise` does not print it.

## Anti-goals

- Advice that reads as measured when it is not.
- A plan recommended because it sounds right for the opponent ("Play for the draw" against a stronger side) with nothing behind it.

## Approaches considered

1. **The research's rule as it stands, shown with its evidence. Chosen.** One recommendation, a short list to avoid, and one extra sentence where the only test applies (a much stronger opponent).
2. **A rule by opponent strength taken from forum opinion** ("go for the win" against weaker sides, "Smash and grab" against stronger). Dropped: unmeasured, and "Smash and grab" was among the worst in the one test.
3. **Nothing until the owner has run the research's save-and-reload test.** Dropped by the owner, who asked for the advice to be shown.

## The design

- **The plans.** Nine, by the names FM26 used and the owner's "No game plan": No game plan, Play for the win, Play for the draw, Settle for a draw, Go for a big win, Smash and grab, Leave it late, Pressure cooker, Strangle the game. FM27's exact wording has not been checked against the game (the research could not find it); the owner should say if a name differs.
- **The rule (this design's call, from the research's table).**
  - Recommended, for every match: No game plan. It plays the owner's tactic as set, and no FM27 test shows any plan doing better.
  - To avoid, for every match: Settle for a draw, Smash and grab, Strangle the game. They did worst in the FM26 test, and plans that sit deep cost points in FM27 engine tests.
  - Against a Much stronger opponent only: the advice adds that Play for the draw and Play for the win came out best of the plans in the FM26 test, too close to call. That test was against a much stronger side, so the sentence is said nowhere else.
  - The opponent's strength is the one on the fixture, whether picked by hand or read from a pasted squad. Nothing else about the fixture is read.
- **The numbers.** There are none. The rule (the plan recommended, the plans to avoid, the plans level against a much stronger side) is one entry in `EngineParameters`, labelled carried over from FM26 (the weaker of its two sources), with the research file as its source. A rule that recommends a plan it also says to avoid, or lists a plan twice, is a parameter problem.
- **The words.** All from the engine (`AdvisorText`): the plans' names, the line naming the plan, and the sentences. The evidence note is the one other advice carries ("FM26-era numbers").
- **The screen.** For a fixture with a planned eleven only (not a confirmed or a missed one):
  - at the top of the column beside the pitch, one line: "If you simulate this match: No game plan". It was first put under the tactic's name in the heading; the pictures showed that the extra line there took height from the pitch whenever a fitness notice was showing, so it was moved;
  - lower in that column, under "Left out", a part headed "Game plan" with the sentences and the evidence note.

      If you simulate this match: No game plan
      (the chosen player's reasons, then "Left out")

      Game plan
      No game plan plays your tactic as you set it. No test of FM27's game plans exists, so nothing shows that
      any of them does better.
      Avoid Settle for a draw, Smash and grab and Strangle the game: they sit deep, which did worst in the one
      FM26 test of the plans and costs points in FM27 engine tests. (FM26-era numbers)

- **What does not happen.** Nothing is saved, and the plan is not worked out again. The advice does not read the importance, the competition or the league situation.

## Evidence

- No FM27 measurement of any game plan exists (the research's finding 1).
- The FM26 test (FRVR): ten instant results a plan in one league fixture against a much stronger side. Play for the draw 10 points, Play for the win 9, Leave it late 8, Go for a big win 7, Pressure cooker 6, Smash and grab 2, Settle for a draw 1, Strangle the game level with Smash and grab. At ten results a plan the top four cannot be told apart; only the gap to the worst is likely real. "No game plan" was not among the plans tested.
- FM27 engine tests (Fm-Match-Lab): defensive presets did worst, "even as an underdog"; a more attacking mentality cost a little. These are tests of tactics, not of the plans.
- The research's cheapest way to settle it: about 100 save-and-reload results a plan on one fixture, for three plans.

## Testing

- Engine: the advice is the same for every strength but Much stronger, and for none set; Much stronger adds the two level plans; a rule that contradicts itself is a parameter problem; the names and sentences are as written here.
- Core: a planned fixture has the note; a confirmed and a missed one do not; the note's words are the engine's.
- Pictures of Match Selection with the line and the part, light and dark, looked at before the work is called done.

## Left to the builder

- The types' names and the exact wording.
- Where the part sits in the column beside the pitch.

## Limits left

- The plans' names are FM26's. Nobody has checked them against FM27's menu.
- In a narrow window the column beside the pitch goes under it, so the line is below the pitch there.
- With a player selected, the "Game plan" part is below his reasons and "Left out", and may need scrolling to.
- The advice is the same for every match but one kind. It will stay so until a test of the plans exists.
