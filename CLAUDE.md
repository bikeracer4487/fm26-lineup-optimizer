# CLAUDE.md

## What this project is

The FM26 lineup optimizer is being rebuilt as a native Mac app for Football Manager 27: SwiftUI, with the selection engine rewritten in Swift, for one save on this Mac. The Python and Electron code in this repository is the old version. It is kept as reference while the new one is built, and it is removed at the end.

- Design: `docs/superpowers/specs/2026-11-12-fm27-native-app-design.md`
- Engine plan, complete (Tasks 1 to 18): `docs/superpowers/plans/2026-11-12-fm27-engine-foundation.md`. Its last two sections list the later plans (Planner, Advisors, the visual design pass, the App, Clean-up) and the notes and known small faults carried into them.
- Planner plan, complete (Tasks 1 to 10): `docs/superpowers/plans/2026-11-13-fm27-planner.md`. Its closing sections list the planner's known limits, the decisions that changed during the build, what the plan showed on the real squad, the small faults left, and what is carried into the app plan.
- Advisors plan, approved by the owner on 13 November 2026 and next to be built; nothing in it is built yet: `docs/superpowers/plans/2026-11-13-fm27-advisors.md`.
- App plan, first screens, complete (Tasks 1 to 10; Task 10 was built before Task 8): `docs/superpowers/plans/2026-11-13-fm27-app-first-screens.md`, to the visual direction in `docs/superpowers/specs/2026-11-13-fm27-app-visual-direction.md`. Squad, Tactics, Fixtures, Match Selection and Settings exist. The advisor screens come after the advisors plan.
- Research: `docs/Research/fm27-*.md` and `docs/Research/fm27_roles.json` are FM27; the other files in `docs/Research/` are FM26. Prefer FM27 evidence. Where it is silent, use the FM26 research and label it as carried over (the owner's rule: a lot carries over between game years). An attribute FM27 tested and found to have no effect is a finding, not a gap.

## New code: `LineupEngine/`

A Swift package (Swift 6, macOS 26, Swift Testing, Foundation only). Built so far: the domain model, the FMRTE clipboard importer, the squad book, the FM27 role catalogue and tactics, the rating core, fitness and risk rules, an exact assignment solver, lineup selection with a reason for every pick and omission, and the planner (looking ahead across fixtures). Not built yet: the advisors (First and Second XI, Depth, Rest, Training, Player Removal). The app is a second package, `LineupApp/`, described below. The engine has no UI and reads no files itself; it is handed data.

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

## New code: `LineupApp/`

The Mac app: a second Swift package beside the engine, depending on it by path (Swift 6, macOS 26, SwiftUI and Observation, Swift Testing, no third-party code). Three targets:

- `LineupAppCore`: the app's state and every action, with no views. `AppModel` (observable, on the main actor) holds the squads, tactics, fixtures, confirmed lineups and settings, saves each change through `Store` as versioned JSON, and works out the plan by calling the engine's `Planner`. Everything a screen shows that is built from data (labels, rows, which fixture is chosen, status words) is worked out here, with tests.
- `LineupAppUI`: the SwiftUI views and `Theme`. Views hold layout only.
- `LineupApp`: the few lines that start the app.

Build and test it with:

    cd LineupApp && swift build && swift test

The tests take about a minute: each plan of the sample data takes most of a second in a debug build, and many tests plan.

Run it:

- `cd LineupApp && swift run LineupApp --sample-data ..` opens it on the engine's captures in a temporary directory. It does not touch real data, the clipboard or FMRTE's file.
- `tools/build_app.sh`, from the repository root, builds `build/FM27 Lineup Optimizer.app` and checks it can load the engine's resources. That is the real app: it reads the clipboard and `~/Library/Application Support/FMRTE27/config.json`, and saves under `~/Library/Application Support/FM27 Lineup Optimizer/`. It is signed for this Mac only.

Draw the screens without opening a window:

    cd LineupApp && swift run -q LineupApp --sample-data .. --pictures .build/pictures

That writes a PNG of every screen and its variants (empty, failed, confirmed and so on), light and dark. A screen is not done until its pictures have been looked at. The pictures approximate the sidebar and draw buttons as an inactive window would; judge the real look in the running app.

Rules for the app:

- The engine decides; the app shows. A view never computes a rating, a reason or a rule. Sentences for errors, warnings and reasons are the engine's (`ErrorDescriptions.describe`, and the reasons on picks and omissions), shown as written. Where the engine has no sentence for something, add one to the engine.
- Logic for a screen lives in `LineupAppCore` with tests. If a view needs an `if` about data, that is a sign it belongs in Core.
- Every colour, typeface and measure comes from `Theme`, which holds the visual direction's tokens. No literal colour or font name in a view.
- Nothing the owner reads is an id or a code: slots are "D L" on a token and "left back" in a sentence; fixtures are named by opponent and date.
- A file that cannot be read gives a notice and a fresh start for that file, and the unreadable file is kept aside. Nothing in a test, a picture run or a sample-data run touches `~/Library/Application Support` or the real clipboard.
- Unsaved changes to a tactic are kept in the model until saved or reverted. Only the earliest planned fixture can be confirmed. A confirmed match keeps its load on its starters in later fixtures until their squad is imported again.

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
