# CLAUDE.md

## What this project is

The FM26 lineup optimizer is being rebuilt as a native Mac app for Football Manager 27. The Python and Electron code in this repository is the old version. It is kept as reference while the new one is built, and it is removed at the end.

- Spec: `docs/superpowers/specs/2026-11-12-fm27-native-app-design.md`
- Current plan (engine foundation): `docs/superpowers/plans/2026-11-12-fm27-engine-foundation.md`
- FM27 research: `docs/Research/fm27-*.md` and `docs/Research/fm27_roles.json`

## New code: `LineupEngine/`

A Swift package (Swift 6, macOS 26, Swift Testing). It holds the domain model, the FMRTE importer, the rating core and lineup selection; the advisors (rest, training, player removal) are not built yet. It has no UI and no file-system dependencies beyond what it is handed. No third-party run-time dependencies.

Test it with:

    cd LineupEngine && swift test

Run one suite or test with `swift test --filter <name>`. Test output must be clean: no build warnings.

- Ratings come from a `RatingProfile`, which `RatingEngine` and `LineupSelector` take explicitly; there is no default yet. "Carried over from FM26" is the old Python's weights; "FM27 engine tests" is built from `Resources/rating_profile_fm27.json` per `docs/Research/fm27-attribute-weights-and-role-thresholds.md`. Role thresholds apply only in the `.fm26Reference` configuration, which proves the port.
- `lineup-cli`, in the package, reads a grids snapshot, a tactic and squad pastes, and prints the explained lineup under both profiles with a comparison (`--profile` picks one; usage at the top of `LineupEngine/Sources/lineup-cli/main.swift`).
- `tools/capture_fmrte_paste.sh` saves the clipboard and FMRTE's grid layouts as test fixtures (how each was taken: `LineupEngine/Tests/LineupEngineTests/Fixtures/captures/README.md`); `tools/export_rating_reference.py` rewrites the rating tables and Python reference data (tracked files).
- A player's identity comes from FMRTE's `Id` column when the pasted grid has it; without it, players are identified by name, with a warning.

Rules for the engine:

- No silent defaults. A missing column, unknown role, or blank or out-of-range value is an error that names the player and the column.
- Every tunable number for a rating or selection rule lives in `EngineParameters` or a `RatingProfile`, with an evidence label and a source.
- Every rule gets a test where it changes an outcome and a test where it does not.

## Old code: reference only

Everything in Python (`*.py`, `fm26_parser/`, `tests/`), `ui/` and the `.bat` files is reference only. Read it; do not modify it. It is deleted at the end of the rebuild. The branch `origin/customizable-tactics` is the reference version; `main` has no commits it lacks.

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

This repository is public. Player data and app state never go in it, except test fixtures under `LineupEngine/Tests/LineupEngineTests/Fixtures/`. Never copy anything from `~/Library/Application Support` into it.

## Git

Work on branch `fm27-native`. Say why in commit messages.
