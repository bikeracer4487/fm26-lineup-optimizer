# CLAUDE.md

## What this project is

The FM26 lineup optimizer is being rebuilt as a native Mac app for Football Manager 27: SwiftUI, with the selection engine rewritten in Swift, for one save on this Mac. The Python and Electron code in this repository is the old version. It is kept as reference while the new one is built, and it is removed at the end.

- Design: `docs/superpowers/specs/2026-11-12-fm27-native-app-design.md`
- Engine plan, complete (Tasks 1 to 18): `docs/superpowers/plans/2026-11-12-fm27-engine-foundation.md`. Its last two sections list the later plans (Planner, Advisors, the visual design pass, the App, Clean-up) and the notes and known small faults carried into them.
- Planner plan, complete (Tasks 1 to 10): `docs/superpowers/plans/2026-11-13-fm27-planner.md`. Its closing sections list the planner's known limits, the decisions that changed during the build, what the plan showed on the real squad, the small faults left, and what is carried into the app plan.
- Advisors plan, approved by the owner on 13 November 2026 and to be built after the app's first screens; nothing in it is built yet: `docs/superpowers/plans/2026-11-13-fm27-advisors.md`.
- App plan, first screens (Squad, Tactics, Fixtures, Match Selection, Settings), being built: `docs/superpowers/plans/2026-11-13-fm27-app-first-screens.md`, to the visual direction in `docs/superpowers/specs/2026-11-13-fm27-app-visual-direction.md`. The owner asked on 13 November 2026 for a usable app before the advisors are built.
- Research: `docs/Research/fm27-*.md` and `docs/Research/fm27_roles.json` are FM27; the other files in `docs/Research/` are FM26. Prefer FM27 evidence. Where it is silent, use the FM26 research and label it as carried over (the owner's rule: a lot carries over between game years). An attribute FM27 tested and found to have no effect is a finding, not a gap.

## New code: `LineupEngine/`

A Swift package (Swift 6, macOS 26, Swift Testing, Foundation only). Built so far: the domain model, the FMRTE clipboard importer, the squad book, the FM27 role catalogue and tactics, the rating core, fitness and risk rules, an exact assignment solver, lineup selection with a reason for every pick and omission, and the planner (looking ahead across fixtures). Not built yet: the advisors (First and Second XI, Depth, Rest, Training, Player Removal), persistence and the app. The engine has no UI and reads no files itself; it is handed data.

Test it with:

    cd LineupEngine && swift test

Run one suite or test with `swift test --filter <name>`. Test output must be clean: no build warnings.

Try it on the captured squad (prints the lineup with reasons; add `--profile both` to compare rating profiles):

    cd LineupEngine && swift run -q lineup-cli select \
      --grids Tests/LineupEngineTests/Fixtures/captures/first-team.grids.json \
      --tactic Tests/LineupEngineTests/Fixtures/tactics/sample-4231.json \
      --first-team Tests/LineupEngineTests/Fixtures/captures/first-team.tsv \
      --u21 Tests/LineupEngineTests/Fixtures/captures/u21.tsv --own-club "Oxford City"

Plan the next five fixtures for the same squad (prints each lineup with reasons, then who starts where; add `--saving 0` to turn off saving players for bigger fixtures):

    cd LineupEngine && swift run -q lineup-cli plan \
      --grids Tests/LineupEngineTests/Fixtures/captures/first-team.grids.json \
      --tactic Tests/LineupEngineTests/Fixtures/tactics/sample-4231.json \
      --first-team Tests/LineupEngineTests/Fixtures/captures/first-team.tsv \
      --u21 Tests/LineupEngineTests/Fixtures/captures/u21.tsv --own-club "Oxford City" \
      --fixtures Tests/LineupEngineTests/Fixtures/plans/sample-fixtures.json \
      --history Tests/LineupEngineTests/Fixtures/plans/sample-history.json --as-of 2026-11-13

Usage is at the top of `LineupEngine/Sources/lineup-cli/main.swift`.

How the engine works, where it is not obvious:

- **Import.** FMRTE copies rows with no header. Column meaning comes from FMRTE's own `config.json` (`ColumnsSettings`), and the importer picks the grid whose column types fit the paste. Squads are imported one at a time (first team, U21, U18).
- **Identity.** A player's key is FMRTE's `Id` column when the pasted grid has it (`fmrte:<id>`); without it, players are identified by name, with a warning. `SquadBook` keeps keys stable across imports and detects moves between squads.
- **Rating profiles.** Ratings come from a `RatingProfile`, which `RatingEngine` and `LineupSelector` take explicitly. `RatingProfile.standard()` is "FM27 engine tests", the owner's chosen default: outfield weights and attribute curves from FM27 match-engine tests (`Resources/rating_profile_fm27.json`), with goalkeeper weights and the way weights differ between positions taken from the FM26 tables (`Resources/rating_tables.json`). "Carried over from FM26" is the old Python's weights, kept for comparison. Design section 8.4 has the formulas.
- **The port check.** The `.fm26Reference` configuration reproduces the old Python (role thresholds, current-ability factor, rounding) and is tested against 594 cases exported from it. Nothing else uses it.
- **Selection.** Rating times condition, sharpness and jadedness factors, solved exactly as an assignment problem, with manual overrides and risk rules that depend on match importance.
- **Planning.** `Planner` picks the lineups for the next fixtures in date order. Each player's value is adjusted, with a reason, by the importance rules (consecutive starts, sharpness, development, loans, retraining, stability) and by a cost for starting him when a bigger fixture follows soon. Condition, sharpness and jadedness are projected from one fixture to the next; starters are assumed to play 90 minutes and nobody else plays.

Tools:

- `tools/capture_fmrte_paste.sh <name>` saves the clipboard and FMRTE's player-grid column layouts as a test fixture. How each capture was taken: `LineupEngine/Tests/LineupEngineTests/Fixtures/captures/README.md`.
- `tools/export_rating_reference.py` regenerates `rating_tables.json` and the Python reference cases from the old code. Both outputs are tracked; do not re-run it without a reason.

Rules for the engine:

- No silent defaults. A missing column, unknown role, or blank or out-of-range value is an error that names the player and the column.
- Every tunable number for a rating or selection rule lives in `EngineParameters` or a `RatingProfile`, with an evidence label (FM27 measured, FM27 official, FM27 observation, carried over from FM26, derived) and a source.
- Every rule gets a test where it changes an outcome and a test where it does not.
- The same inputs always give the same lineup: sums run in a fixed order.
- Errors and warnings become plain-words sentences in `Reporting/ErrorDescriptions.swift`; every `switch` over them is exhaustive, with no `default`.

## Old code: reference only

Everything in Python (`*.py`, `fm26_parser/`, `tests/`), `ui/`, the `.bat` files and the root-level data and notes files is reference only. Read it; do not modify it. It is deleted at the end of the rebuild. `main` and `origin/customizable-tactics` are the same commit, the last version of the old app.

## What the old Python runs, and what it never connected

Runs (per a traced reading of the code):

- Rating core (`rating_calculator.py`): per-player, per-slot rating from position attribute weights, the role's key and secondary attributes, a familiarity factor per phase, and an in-possession/out-of-possession blend.
- Match selection (`ui/api/api_match_selector.py` over `fm_match_ready_selector.py`): that rating times condition, sharpness and jadedness factors, solved as an assignment problem, with manual overrides, per-match rejections, a lineup-stability term, consecutive-start counts from confirmed lineups, and auto-rest rules.
- Advisors: First and Second XI (`api_rotation_selector.py`), Rest (`api_rest_advisor.py`), Training (`api_training_advisor.py` over `fm_training_advisor.py`), Player Removal (`api_player_removal.py`).

Written but never connected (design references, not behaviour to match):

- `state_simulation.py`: forward simulation of fitness.
- `shadow_pricing.py`: shadow pricing beyond a display value.
- `explainability.py`: pick explanations.
- `match_importance.py`: automatic match importance.

The old 155 tests exercise the unconnected modules and parameter helpers. Nothing tests the path that produces lineups.

## Data and privacy

This repository is public. Player data and app state never go in it, except test fixtures under `LineupEngine/Tests/LineupEngineTests/Fixtures/`. The only thing taken from `~/Library/Application Support` is FMRTE's player-grid column layouts, which the capture tool saves beside each fixture; copy nothing else from there.

## Git

Work on branch `fm27-native`. Say why in commit messages. Leave `main` as it is and do not merge or open a pull request for the rewrite unless asked: the owner may move it to its own repository.
