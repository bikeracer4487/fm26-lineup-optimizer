# FM27 Lineup Optimizer

> Picks the starting eleven for Football Manager 27 fixtures and gives a reason for every pick and omission.

This repository is in the middle of a rewrite. The lineup optimizer started as a Python and Electron app for Football Manager 26 on Windows. It is being rebuilt as a native Mac app for Football Manager 27: SwiftUI, with the selection engine written in Swift.

**What works today is the engine, as a Swift package with a command-line tool. There is no app to launch yet.** The old Python and Electron code is still in the repository as reference and is removed at the end of the rewrite ([see below](#the-old-fm26-app)).

## Contents

- [Status](#status)
- [Requirements](#requirements)
- [Quick start](#quick-start)
- [The `lineup-cli` command](#the-lineup-cli-command)
- [Using your own squad](#using-your-own-squad)
- [How the engine works](#how-the-engine-works)
- [Repository layout](#repository-layout)
- [Development](#development)
- [The old FM26 app](#the-old-fm26-app)
- [License](#license)

## Status

| Part | State |
|---|---|
| Engine: domain model, FMRTE clipboard import, squad book, FM27 roles and tactics, rating, fitness and risk rules, exact assignment solver, single-fixture selection with reasons | Built and tested |
| Planner: lineups for the next several fixtures, with projected fitness, importance rules and saving players for bigger fixtures | In progress; the building blocks are in `LineupEngine/Sources/LineupEngine/Planner/`, the planner itself and its `plan` command are not finished |
| Advisors: First and Second XI, Depth, Rest, Training, Player Removal | Not started |
| Persistence and the SwiftUI app (ten screens) | Not started |

The design, and the order the work is done in, are in [`docs/superpowers/specs/2026-11-12-fm27-native-app-design.md`](docs/superpowers/specs/2026-11-12-fm27-native-app-design.md).

## Requirements

- macOS 26 on Apple Silicon
- A Swift 6 toolchain (Xcode, or the command-line tools)
- No third-party packages: the engine uses Foundation only

To run it on your own save you also need [FMRTE](https://www.fmrte.com) 27, to copy player rows from the game. The test fixtures in the repository are enough to try the engine without it.

## Quick start

Run the tests:

```bash
cd LineupEngine
swift test
```

Pick a lineup from the squad captured in the test fixtures:

```bash
cd LineupEngine
swift run -q lineup-cli select \
  --grids Tests/LineupEngineTests/Fixtures/captures/first-team.grids.json \
  --tactic Tests/LineupEngineTests/Fixtures/tactics/sample-4231.json \
  --first-team Tests/LineupEngineTests/Fixtures/captures/first-team.tsv \
  --u21 Tests/LineupEngineTests/Fixtures/captures/u21.tsv \
  --own-club "Oxford City"
```

This prints:

- an import summary: which FMRTE grid each paste matched, how many players it held, and any warnings (for example, a grid with no `Id` column, or a player out of contract)
- the lineup, one slot per line: the slot, its role in and out of possession, the player, their rating, the condition, sharpness and jadedness factors, and the resulting match-day value
- under each pick, the reasons: position familiarity in each phase, and any fitness factor that reduced the value
- unfilled slots, and the players left out of their best slot with the reason (injured, for example)

## The `lineup-cli` command

```
lineup-cli select --grids <fmrte config or grids snapshot> --tactic <tactic.json>
                  [--first-team <paste.tsv>] [--u21 <paste.tsv>] [--u18 <paste.tsv>]
                  [--importance high|medium|low|sharpness] [--own-club <name>]
                  [--profile fm27|carried-over|both]
```

| Option | Meaning |
|---|---|
| `--grids` | FMRTE's `config.json`, or a saved snapshot of its player-grid column layouts. Required. |
| `--tactic` | A tactic file. Required. |
| `--first-team`, `--u21`, `--u18` | Clipboard text copied from an FMRTE player grid, one file per squad. At least one is required. |
| `--importance` | Match importance: `high` (the default), `medium`, `low` or `sharpness`. It changes the risk rules. |
| `--own-club` | Your club's name, used to tell which players are out on loan. The engine works it out from the pastes when it can, and asks for this option when it cannot. |
| `--profile` | The rating profile: `fm27` (the default), `carried-over`, or `both`, which prints the FM27 lineup, then the carried-over one, and compares them. |

`select` is the only command so far.

A tactic file names a role for each slot in possession and out of possession. [`sample-4231.json`](LineupEngine/Tests/LineupEngineTests/Fixtures/tactics/sample-4231.json) is a working example. Role names come from the FM27 role list in `LineupEngine/Sources/LineupEngine/Resources/fm27_roles.json`.

## Using your own squad

FMRTE copies player rows to the clipboard with no header row. The meaning of each column comes from FMRTE's own configuration file, so the engine needs both.

1. In FMRTE 27, with your save loaded, open a squad in a player grid. Add the `Id` column to the grid if you can: with it, players are identified exactly; without it, they are identified by name and the import warns you.
2. Select the rows, copy them, and save the clipboard to a file:

   ```bash
   LC_ALL=en_US.UTF-8 pbpaste > ~/first-team.tsv
   ```

3. Repeat for the U21 and U18 squads if you want them considered. Squads are imported one at a time.
4. Run `lineup-cli select`, pointing `--grids` at FMRTE's configuration:

   ```bash
   cd LineupEngine
   swift run -q lineup-cli select \
     --grids "$HOME/Library/Application Support/FMRTE27/config.json" \
     --tactic Tests/LineupEngineTests/Fixtures/tactics/sample-4231.json \
     --first-team ~/first-team.tsv \
     --own-club "Your Club"
   ```

Keep your own pastes outside the repository. It is public, and player data does not belong in it.

## How the engine works

- **Import.** The importer reads FMRTE's column layouts and picks the grid whose column types fit the paste. A missing column, an unknown role, or a blank or out-of-range value is an error that names the player and the column. There are no silent defaults.
- **Identity.** A player's key is FMRTE's `Id` column when the grid has it. The squad book keeps keys stable from one import to the next and detects moves between squads.
- **Rating.** Each player gets a rating for each slot of the tactic, from position attribute weights, the role's attributes, and familiarity with the position in each phase. Ratings come from a rating profile. The default, "FM27 engine tests", takes outfield weights and attribute curves from FM27 match-engine tests, with goalkeeper weights and positional differences from the FM26 tables. "Carried over from FM26" uses the old app's weights and is kept for comparison.
- **Selection.** Rating is multiplied by condition, sharpness and jadedness factors to give a match-day value. The eleven is then solved exactly as an assignment problem, with manual overrides and risk rules that depend on match importance. The same inputs always give the same lineup.
- **Evidence.** Every tunable number lives in `EngineParameters` or a `RatingProfile` and carries a label saying where it came from: FM27 measured, FM27 official, FM27 observation, carried over from FM26, or derived.

The research behind the numbers is in [`docs/Research/`](docs/Research/). Files named `fm27-*` are FM27 research; the others are FM26 and are used only where the FM27 research is silent.

## Repository layout

```
LineupEngine/                  the Swift package
  Sources/LineupEngine/
    Import/                    FMRTE clipboard importer, grid detection, squad book
    Model/                     players, positions, attributes
    Roles/                     FM27 role catalogue and tactics
    Rating/                    rating engine, profiles and tables
    Selection/                 fitness model, risk rules, assignment solver, lineup selector
    Planner/                   looking ahead across fixtures (in progress)
    Parameters/                tunable numbers and their evidence labels
    Reporting/                 errors and warnings as plain-words sentences
    Resources/                 role list and rating data (JSON)
  Sources/lineup-cli/          the command-line tool
  Tests/LineupEngineTests/     tests and fixtures (captured pastes, tactics, reference cases)
docs/superpowers/specs/        the design
docs/superpowers/plans/        implementation plans
docs/Research/                 FM27 and FM26 research
tools/                         capture and export scripts
```

Everything else at the top level (`*.py`, `fm26_parser/`, `tests/`, `ui/`, the `.bat` files, and the data and notes files) belongs to the old app.

## Development

Work happens on the `fm27-native` branch. `main` is the last version of the old app and is left as it is.

```bash
cd LineupEngine
swift test                       # everything
swift test --filter <name>       # one suite or test
```

Test output must be clean, with no build warnings. Every rule gets a test where it changes an outcome and a test where it does not.

Two tools support the tests:

- `tools/capture_fmrte_paste.sh <name>` saves the clipboard and FMRTE's player-grid column layouts as a test fixture. How each existing capture was taken is in the [captures README](LineupEngine/Tests/LineupEngineTests/Fixtures/captures/README.md).
- `tools/export_rating_reference.py` regenerates the rating tables and the reference cases that check the Swift rating core against the old Python. Both outputs are tracked, so it rarely needs running.

[`CLAUDE.md`](CLAUDE.md) has the full set of rules for working on the engine, and the implementation plans are in [`docs/superpowers/plans/`](docs/superpowers/plans/).

## The old FM26 app

The Python scripts and the Electron app in `ui/` are the FM26 version, built for Windows. They are kept only as reference while the new app is built. They are not maintained, their dependencies are not being updated, and they are deleted at the end of the rewrite.

`QUICKSTART.md`, `ADVANCED_FEATURES.md`, `BATCH_FILE_USAGE.md` and `PROJECT_SUMMARY.md` describe the old app, as does `ui/README.md` (the unmodified Vite template). The old app's own README is on the `main` branch:

```bash
git show main:README.md
```

## License

Released under the MIT License. See [LICENSE.md](LICENSE.md).
