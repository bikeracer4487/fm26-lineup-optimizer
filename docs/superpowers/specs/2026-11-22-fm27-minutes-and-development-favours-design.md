# FM27 Lineup Optimizer: who the planner favours for minutes in a lesser fixture

Date: 22 November 2026
Status: asked for by the owner on 22 November 2026, with the findings of another session in front of him ("I'd like you to add both of the recommended fixes"). Built the same day as Tasks 7 and 8 of `docs/superpowers/plans/2026-11-22-fm27-scouting-best-five-and-hidden.md`, the work then under way. He chose both changes; the two calls marked "this design's call" are the builder's, and are his to change.

## Intent

In the owner's save the plan started Ben Porter in a low-importance cup match at left attacking midfield. He is a fringe young player (reach 58) who is not good enough for the side, and the plan did not pick him for being good. Two favours added up:

| Step | Value |
|---|---|
| His rating at the slot, familiarity 20 in both phases | 100.7 |
| Sharpness 46% | ×0.76 |
| "Needs minutes: sharpness 46%" | ×1.50 |
| "Young player with room to grow" | ×1.04 |
| His value in the match | 119 |

The usual starter there rates 119 and was being kept fresher for a bigger match, so 119 was enough.

Two rules gave the wrong answer.

1. **"Needs minutes" in a low fixture goes to everyone.** It was made so that an unsharp regular gets the low fixtures (the owner's rule of 13 November 2026). It never asked whether the player is a regular. A player who is unsharp because he never plays is favoured for exactly that, and at 46% the favour more than cancels his sharpness penalty: he is worth 14% more unsharp than sharp. In a sharpness fixture the same rule is already limited to the two elevens.
2. **The favour by age goes to players the tool's own advice would not develop.** The planner leaves out only a player whose reach is markedly lower. Player Removal also calls a player who could at best become cover not worth developing. This was listed as a fault left in the young players plan.

## Goals

1. In a low fixture, "Needs minutes" favours only a player in the first or second eleven for the fixture's tactic, or a successor the fixture favours: the rule a sharpness fixture already has.
2. The favour by age goes only to a player Player Removal calls worth developing.
3. Each player's reasons still say what moved his value. A player who loses a favour simply has no line for it.

## Non-goals

- The sizes of either favour, the sharpness factor, or where the line for "markedly lower" lies. The other session noted that line is easy to stay above; it is left as it is.
- A floor on current ability. The engine still goes by rating at the slot.
- The successor's favour, the retraining favour, the saving rule and high and medium fixtures.
- Player Removal's advice.

## Approaches

The owner was given the two changes as found, and "both, or just the first"; he chose both. For each there was one sensible way, since the engine already holds the rule being reused.

1. **Needs minutes.** Reuse the sharpness fixture's test (`needsSharpness` in `ImportanceRules`): in the elevens (`SquadTiers.slot(of:)`), or a successor this fixture favours and not fully sharp. Dropped: a new notion of "regular" from starts in confirmed matches, which would be a second definition beside the elevens and would fail early in a save.
2. **Favour by age.** Use Player Removal's own function (`Removal.isWorthDeveloping`) in place of "not markedly lower". Dropped: a second line in the planner, which could drift from the advice again.

## The rules

### Needs minutes in a low fixture

- A player gets "Needs minutes" in a low fixture only when he is in the first or second eleven for the fixture's tactic, or is a successor the fixture favours. Anyone else gets no line, whatever his sharpness.
- A successor counts (this design's call), as he does in a sharpness fixture: the plan is trying to give him matches at his slot, and he cannot be got sharp without them. Ben Porter is not one.
- The size is unchanged: up to ×1.50 at 50% sharpness or under (`sharpnessNeedStrengthLow`).
- A low fixture still marks nobody down for being sharp; that stays a sharpness fixture's rule.
- A player outside the elevens keeps his sharpness penalty and loses the favour that cancelled it, so an unsharp fringe player is now worth less than a sharp one, as he should be.

### The favour by age

- The favour (the "floor") goes to a player who is worth developing as Player Removal reads it: he is first choice at a slot he can play; or his reach could pass the first choice or make the second eleven; or he has no level, because no slot compares him with a first choice other than himself.
- A player whose reach is cover at best now gets none, as one markedly lower already got none.
- Everything else about it is unchanged: 23 or under, potential at least 1.15 times ability, low and sharpness fixtures only, at each slot he can play, by age, scaled by the Development setting, none after four starts in thirty days, none for a player advised to leave.
- The successor's favour is unchanged (this design's call). A successor is close to or on course to pass the first choice at his slot, so he is worth developing already.

## What changes for the owner

- Lineups for low fixtures change: fringe players who never play no longer rise on being unsharp, and cover-level young players lose the small favour by age.
- A young first-choice or second-eleven player who is unsharp is favoured exactly as before.
- The young players plan's fault ("The planner's favour by age still goes to a player who could only become cover") is closed.

## Limits

- Who is "in the elevens" is the best and second-best eleven for the fixture's tactic at full fitness. A regular who is third choice at his slot gets no "Needs minutes" in a low fixture.
- A player returning from a long injury who has dropped out of both elevens gets no "Needs minutes" until he is back in one; the owner can still choose him.
- The reach behind "worth developing" is this tool's estimate, as everywhere.

## Tests

- Needs minutes, low fixture: a player in the first eleven and one in the second are favoured as before; one in neither gets none; a favoured successor in neither is favoured; a sharp player in the elevens is still not marked down.
- Favour by age: could pass the first choice, could make the second eleven and no level are favoured; could be cover and markedly lower are not; a first choice whose level elsewhere is cover is favoured.
- Both suites run in full, since plans for the captured squad may change.
