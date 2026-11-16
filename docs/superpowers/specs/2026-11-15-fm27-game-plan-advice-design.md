# FM27 Lineup Optimizer: which game plan to use when a match is simulated

Date: 15 November 2026
Status: built on the owner's word of 15 November 2026 ("I'd like the game plan advice shown in the Match Selection screen"). Revised the same day, after the owner said the first version leaned too hard on there being no evidence and added a second research file for FM26: the advice now differs by the opponent's strength, as that research's table does. He has not read this text; everything below marked as this design's call is the builder's, and is his to change.

Research behind it: `docs/Research/fm26-match-simulation-game-plans.md` (the rule) and `docs/Research/fm27-match-simulation-game-plans.md`.

## Intent

When the owner simulates a match the game asks for a game plan ("No game plan", "Play for the win", "Play for the draw" and so on). He believes different plans suit different opponents, does not know the rules, and asked for a recommendation on Match Selection.

Both research passes found one test of the plans: FRVR, in FM26, ten instant results a plan against a single much stronger side. The FM26 pass also says where it did not get to look (most communities that do not write in English, YouTube, Reddit directly), so a test may exist that neither found. From that one test and from FM27 engine tests of defensive tactics, the FM26 research reasons a rule for each strength of opponent. The tool shows that rule, and says on every match which part is measured and which is reasoning.

## Goals

1. Match Selection says, for each fixture with a planned eleven, which game plans to use if the match is simulated and which to avoid, by the opponent's strength on the fixture.
2. Every piece of the advice says what it rests on: a measurement, or reasoning from one.
3. When a new result arrives (the owner's own test, or a published one), the advice changes in one place.

## Non-goals

- The rows of the research's table that need what a fixture does not record: home or away, a second leg, whether a draw is enough, protecting a lead.
- Checking afterwards that substitutes got their minutes. The tool cannot see minutes played.
- The command line. `advise` does not print it.

## Anti-goals

- Advice that reads as measured when it is reasoning.
- One plan named where the evidence does not separate two.

## Approaches considered

1. **The FM26 research's table, by the opponent's strength, with its evidence shown. Chosen** after the owner's objection.
2. **"No game plan" for every match** (the FM27 research's table, and this design's first version). Dropped: it gave the owner the same line on every match, and "No game plan" was not in the one test, so it is no better founded than the plans that were.
3. **Nothing until the owner has run the research's save-and-reload test.** Dropped by the owner, who asked for the advice to be shown.

## The design

- **The plans.** Nine, by the names FM26 used and the owner's "No game plan": No game plan, Play for the win, Play for the draw, Settle for a draw, Go for a big win, Smash and grab, Leave it late, Pressure cooker, Strangle the game. FM27's exact wording has not been checked against the game; the owner should say if a name differs.
- **The rule (the FM26 research's table, read by opponent strength alone).** Where two plans are given, nothing separates them, and the line names both.

  | Their strength | Use | Avoid | Rests on |
  |---|---|---|---|
  | Much stronger | Play for the draw or Play for the win | Settle for a draw, Strangle the game, Smash and grab | the FM26 test |
  | Stronger | Play for the win or Play for the draw | Settle for a draw, Strangle the game | reasoning from that test |
  | Similar | Play for the win or No game plan | Settle for a draw | reasoning |
  | Weaker, much weaker | Play for the win or No game plan | Settle for a draw, Strangle the game | reasoning |
  | Not set | Play for the win | Settle for a draw | what every row above has in common (this design's call) |

  The research's "Leave it late similar" against a much stronger side and "Go for a big win only if goal difference matters" against a weaker one are left out of the line (this design's call: the first is a third plan nothing separates, the second needs something a fixture does not record).
- **The numbers.** The test's points for each plan (Play for the draw 10, Play for the win 9, Leave it late 8, Go for a big win 7, Pressure cooker 6, Smash and grab 2, Strangle the game 2, Settle for a draw 1, each from ten matches) are kept with the rule and quoted in the sentences. The rule and the points are one entry in `EngineParameters` (`gamePlanRules`), labelled carried over from FM26, with both research files as its source. The advice against a much stronger side carries that label; every other row carries "this tool's estimate", since it is reasoning. A rule with no plan to use, with a plan both to use and to avoid, or with a plan listed twice is a parameter problem.
- **The words.** All from the engine (`AdvisorText`): the plans' names, the line naming the plans to use, and the sentences. Against a much stronger side they give the test's points; against any other they say no test covers such a side and that the plans are reasoned choices; with no strength set they say how to get advice that fits the match. Where "No game plan" is not among the plans to use, they say it was not in the test.
- **The screen.** For a fixture with a planned eleven only (not a confirmed or a missed one):
  - at the top of the column beside the pitch, one line: "If you simulate this match: Play for the win or No game plan". It was first put under the tactic's name in the heading; the pictures showed that the extra line there took height from the pitch whenever a fitness notice was showing, so it was moved;
  - lower in that column, under "Left out", a part headed "Game plan" with the sentences and the evidence note.
- **What does not happen.** Nothing is saved, and the plan is not worked out again. The advice reads the opponent's strength on the fixture (picked by hand or read from a pasted squad) and nothing else.

## Evidence

- The FM26 test (FRVR, 18 December 2025): ten instant results a plan in one fixture against a much stronger side; venue and patch not stated. At ten results a plan the plans at the top cannot be told apart; the gap between the top three and the bottom three (27 points from 30 matches against 5) is the part likely to be real. "No game plan" was not tested, in this or any version.
- FM27 engine tests (Fm-Match-Lab): defensive presets did worst, "even as an underdog". These are tests of tactics, not of the plans; the research uses them as reasoning.
- Nothing measured covers a stronger, similar or weaker opponent, home against away, or a knockout.
- What each plan does inside a match has not been published for FM26 or FM27.
- The research's cheapest way to settle the biggest unknown (whether any plan beats "No game plan" as the favourite): about 30 save-and-reload results a plan to screen, 100 to confirm.

## Testing

- Engine: each strength gives its plans to use and to avoid; only the advice against a much stronger side is marked measured; a rule that contradicts itself is a parameter problem; the line and the sentences are as written for each strength and follow a changed rule.
- Core: a planned fixture has the note, in the engine's words, for its opponent's strength; a confirmed and a missed one do not.
- Pictures of Match Selection with the line and the part, light and dark, looked at before the work is called done.

## Limits left

- The plans' names are FM26's. Nobody has checked them against FM27's menu.
- Only one row of the rule is measured, and that from ten matches a plan in FM26.
- In a narrow window the column beside the pitch goes under it, so the line is below the pitch there.
- With a player selected, the "Game plan" part is below his reasons and "Left out", and may need scrolling to.
- A fixture's venue, leg and what is at stake are not recorded, so the research's rows for them are not used.

## Found while building

The engine's parameters were a 4.8 KB value handed down every call, and the engine's tests run on small stacks. Adding this rule's table tipped one planning test over the limit. Each parameter now keeps its value off the stack (`Parameter` is one pointer wide), which brings the set under 1 KB; a test holds it there.
