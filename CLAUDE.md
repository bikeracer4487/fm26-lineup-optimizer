# CLAUDE.md

## What this project is

The FM26 lineup optimizer is being rebuilt as a native Mac app for Football Manager 27: SwiftUI, with the selection engine rewritten in Swift, for one save on this Mac. The Python and Electron code in this repository is the old version. It is kept as reference while the new one is built, and it is removed at the end.

- Design: `docs/superpowers/specs/2026-11-12-fm27-native-app-design.md`
- Engine plan, complete (Tasks 1 to 18): `docs/superpowers/plans/2026-11-12-fm27-engine-foundation.md`. Its last two sections list the later plans (Planner, Advisors, the visual design pass, the App, Clean-up) and the notes and known small faults carried into them.
- Planner plan, complete (Tasks 1 to 10): `docs/superpowers/plans/2026-11-13-fm27-planner.md`. Its closing sections list the planner's known limits, the decisions that changed during the build, what the plan showed on the real squad, the small faults left, and what is carried into the app plan.
- Advisors plan, complete (Tasks 1 to 8; Task 8 changed the rules that gave wrong advice on the real squad): `docs/superpowers/plans/2026-11-13-fm27-advisors.md`. Its closing sections list the decisions that changed during the build and the advisors' known limits for the owner.
- App plan, first screens, complete (Tasks 1 to 11; Task 10 was built before Task 8, and Task 11 restyled every screen). Its closing sections list the decisions that changed during the build and the limits and small faults left: `docs/superpowers/plans/2026-11-13-fm27-app-first-screens.md`, to the visual direction in `docs/superpowers/specs/2026-11-13-fm27-app-visual-direction.md`. Squad, Tactics, Fixtures, Match Selection and Settings exist.
- Advisor screens plan, complete (Tasks 1 to 10): `docs/superpowers/plans/2026-11-13-fm27-advisor-screens.md`. Its closing sections list the decisions that changed during the build and the limits and small faults left. What remains of the rebuild is the clean-up plan, not yet written.
- Sale and loan marks plan, complete (Tasks 1 to 5): `docs/superpowers/plans/2026-11-14-fm27-sale-marks.md`, to the design in `docs/superpowers/specs/2026-11-14-fm27-sale-marks-design.md`. Its closing sections list what changed during the build and the limits left.
- Mentoring plan, complete (Tasks 1 to 9, with an inserted task on youth contracts and release costs after Task 5): `docs/superpowers/plans/2026-11-14-fm27-mentoring.md`, to the design in `docs/superpowers/specs/2026-11-14-fm27-mentoring-design.md`. Its closing sections list what the advice showed on the captured squads, what changed during the build and the limits left. Its rules for who influences whom were replaced by the next plan.
- Mentoring arrows plan, complete (Tasks 1 to 8): `docs/superpowers/plans/2026-11-14-fm27-mentoring-arrows.md`, to the design in `docs/superpowers/specs/2026-11-14-fm27-mentoring-arrows-design.md`, which wins over the first mentoring design where they differ. It rebuilt the mentoring advice on the game's own influence arrows, as the owner read them. Its closing sections list what the advice showed on the owner's readings, what changed during the build and the limits left.
- Money as FMRTE shows it, built (no plan; one inserted task): the design in `docs/superpowers/specs/2026-11-14-fm27-money-as-fmrte-shows-it-design.md`. Wages are read in the period and currency FMRTE is set to, and money is shown the same way.
- Young players' development plan, complete (Tasks 1 to 10, with an inserted task on the rating's scale after Task 4 and another on players not worth developing after Task 9): `docs/superpowers/plans/2026-11-14-fm27-young-players-development.md`, to the design in `docs/superpowers/specs/2026-11-14-fm27-young-players-development-design.md`, built. It judges a player of 23 or under on where his ability could reach, in Player Removal and in the planner, and adds a Development setting. Its closing sections list what the advice showed on the captured squads, what changed during the build and the limits and small faults left; the install and the hands-on check of the real app are left to the owner. The research is `docs/Research/fm27-development-matches-vs-training.md`.
- Research: `docs/Research/fm27-*.md` and `docs/Research/fm27_roles.json` are FM27; the other files in `docs/Research/` are FM26. Prefer FM27 evidence. Where it is silent, use the FM26 research and label it as carried over (the owner's rule: a lot carries over between game years). An attribute FM27 tested and found to have no effect is a finding, not a gap.

## New code: `LineupEngine/`

A Swift package (Swift 6, macOS 26, Swift Testing, Foundation only). Built so far: the domain model, the FMRTE clipboard importer, the squad book, the FM27 role catalogue and tactics, the rating core, fitness and risk rules, an exact assignment solver, lineup selection with a reason for every pick and omission, the planner (looking ahead across fixtures), and the advisors (First and Second XI, Depth, Rest, Training, Player Removal, Mentoring, and a suggested importance for each fixture). The app is a second package, `LineupApp/`, described below. The engine has no UI and reads no files itself; it is handed data.

Test it with:

    cd LineupEngine && swift test

Run one suite or test with `swift test --filter <name>`. Test output must be clean: no build warnings.

Try it on the captured squad (prints the lineup with reasons; add `--profile both` to compare rating profiles):

    cd LineupEngine && swift run -q lineup-cli select \
      --grids Tests/LineupEngineTests/Fixtures/captures/first-team.grids.json \
      --tactic Tests/LineupEngineTests/Fixtures/tactics/sample-4231.json \
      --first-team Tests/LineupEngineTests/Fixtures/captures/first-team.tsv \
      --u21 Tests/LineupEngineTests/Fixtures/captures/u21.tsv --own-club "Oxford City"

Plan the next five fixtures for the same squad (prints each lineup with reasons, then who starts where; add `--saving 0` to turn off saving players for bigger fixtures, and `--development 0` to turn off the favour to young players; the default is 1):

    cd LineupEngine && swift run -q lineup-cli plan \
      --grids Tests/LineupEngineTests/Fixtures/captures/first-team.grids.json \
      --tactic Tests/LineupEngineTests/Fixtures/tactics/sample-4231.json \
      --first-team Tests/LineupEngineTests/Fixtures/captures/first-team.tsv \
      --u21 Tests/LineupEngineTests/Fixtures/captures/u21.tsv --own-club "Oxford City" \
      --fixtures Tests/LineupEngineTests/Fixtures/plans/sample-fixtures.json \
      --history Tests/LineupEngineTests/Fixtures/plans/sample-history.json --as-of 2026-11-13

Run every advisor on the same squad (prints the two elevens, depth at each slot, rest, retraining, who to move on and the loan review, then a suggested importance beside each fixture's own):

    cd LineupEngine && swift run -q lineup-cli advise \
      --grids Tests/LineupEngineTests/Fixtures/captures/first-team.grids.json \
      --tactic Tests/LineupEngineTests/Fixtures/tactics/sample-4231.json \
      --first-team Tests/LineupEngineTests/Fixtures/captures/first-team.tsv \
      --u21 Tests/LineupEngineTests/Fixtures/captures/u21.tsv --own-club "Oxford City" \
      --fixtures Tests/LineupEngineTests/Fixtures/plans/sample-fixtures-with-competitions.json \
      --history Tests/LineupEngineTests/Fixtures/plans/sample-history.json --as-of 2026-11-13

`advise` also prints mentoring groups. They are guesses from the hierarchy and ages, and none until a hierarchy is entered; the command line takes no arrow readings. Add `--standings <file>` to enter one: a JSON object from a player's key to his hierarchy level and social group (the format is described at the top of `main.swift`).

Usage is at the top of `LineupEngine/Sources/lineup-cli/main.swift`.

How the engine works, where it is not obvious:

- **Import.** FMRTE copies rows with no header. Column meaning comes from FMRTE's own `config.json` (`ColumnsSettings`), and the importer picks the grid whose column types fit the paste. Squads are imported one at a time (first team, U21, U18). Wages are read in the period FMRTE's settings file names (its top-level `Wages`: Weekly, Monthly or Yearly; none is weekly) and the currency symbol on the pasted amounts, which must be the same on every row. They are kept per week inside the engine (`Player.wagePerWeek`, not always whole), and shown as FMRTE shows them through the squad book's `moneyStyle` (`MoneyStyle`, `Display.wage`); squads held in different currencies raise a squad warning, since there is no exchange rate.
- **Identity.** A player's key is FMRTE's `Id` column when the pasted grid has it (`fmrte:<id>`); without it, players are identified by name, with a warning. `SquadBook` keeps keys stable across imports and detects moves between squads.
- **Rating profiles.** Ratings come from a `RatingProfile`, which `RatingEngine` and `LineupSelector` take explicitly. `RatingProfile.standard()` is "FM27 engine tests", the owner's chosen default: outfield weights and attribute curves from FM27 match-engine tests (`Resources/rating_profile_fm27.json`), with goalkeeper weights and the way weights differ between positions taken from the FM26 tables (`Resources/rating_tables.json`). "Carried over from FM26" is the old Python's weights, kept for comparison. Design section 8.4 has the formulas.
- **The port check.** The `.fm26Reference` configuration reproduces the old Python (role thresholds, current-ability factor, rounding) and is tested against 594 cases exported from it. Nothing else uses it.
- **Selection.** Rating times condition, sharpness and jadedness factors, solved exactly as an assignment problem, with manual overrides and risk rules that depend on match importance.
- **Planning.** `Planner` picks the lineups for the next fixtures in date order. Each player's value is adjusted, with a reason, by the importance rules (consecutive starts, sharpness, development, marked to sell or loan out, loans, retraining, stability) and by a cost for starting him when a bigger fixture follows soon. A player the owner has marked to sell or to loan out is favoured slightly (`shopWindowFactor`, ×1.03) in low and sharpness fixtures only; the size is the tool's own estimate, and whether playing a player brings offers is untested. A player of 23 or under with potential at least 1.15 times his ability, and a reach that is not markedly lower or a place as first choice at a slot he can play (see Advisors), is favoured in low and sharpness fixtures at every slot he can play, by age: ×1.10 at 21 to 23, ×1.07 at 18 to 20, ×1.02 at 17 or under (×1.04 at 17 or under with Professionalism 14 or under). A successor is favoured more, in place of that favour, at the slot where he is close to passing the first choice (a player of 18 to 23 who is close or on course; 17 or under only when close): ×1.15 in low and sharpness fixtures and ×1.05 in medium ones, never in high ones; in a medium fixture only the two closest successors who can be picked are favoured. A first choice at any slot is nobody's successor, a player on loan here gets no favour, and a successor who is also retraining at the slot gets the larger of the two favours, not both. Both favours fall to nothing once he has started four matches in the last thirty days, planned starts included, since the game reads only so much match time in a month (carried over from FM26). The Development setting, 0 to 1 and 1 by default, beside Stability and Saving players, scales each favour as 1 + (factor − 1) × the setting; at 0 no lineup changes, and no outlook is worked out, so a young player missing Professionalism, Ambition or Determination does not stop the plan. The sizes are derived from the research's growth per match by age; the outlooks are worked out once for each tactic with the same code Player Removal uses. Condition, sharpness and jadedness are projected from one fixture to the next; starters are assumed to play 90 minutes and nobody else plays.
- **Advisors.** They advise; the planner decides who starts. Each is a function of the data it is handed (`Advisors/`). `Elevens` gives the best and second-best elevens at full fitness, injured players kept in and marked; Depth, Training and Player Removal build on those tiers. Depth calls a slot thin when fewer than two players are solid there (familiarity 15 or over in both phases), not injured and not first choice elsewhere; a one-day dip in condition does not stop a player counting. Training recommends position retraining for thin slots; Rest flags players over their own jadedness limit, under the condition floor or on a run of starts; Player Removal scores every player of the club's own with a points reason for each rule, and reviews loans to the club; it reads a youth contract (FMRTE pastes `Youth`) and costs it like a full-time one, and a player on one can only be kept or released, at any age, never sold, terminated, loaned or marked (one engine function, `Removal.isOnYouthContract`, reads it; with 0 months left it is read as no contract). Player Removal costs a release as the wages for the months left plus half a month, because FMRTE's months left is rounded down. A player of 23 or under is judged on his reach, which is this tool's estimate and never a fact: his ability after each coming season is the growth for his age (18 points a season to 18, 14 to 20 and 12 to 26, from FM24 and FM26 tests) scaled for Professionalism, Ambition and Determination, never above his potential, and added up to age 26. The reach is compared, at each slot he can play, with the first and second choice there (a rating is taken to grow with ability from an offset, `ratingAbilityOffset`, fitted on the captured squads and loosely pinned, not in proportion). One line replaces the old elevens, weakest-30%, ability and prospect lines: could pass the first choice (−40), could make the second eleven (−20), could become cover (+15) or markedly lower (+70); a place in either eleven competes with that line, and a backup takes it. The bar between cover and markedly lower is 80% of the first choice's rating, 70% at 16 or under; below it he is markedly lower whoever the second choice is. His Professionalism and Ambition add no line, since his reach already counts them, and a short contract on a player worth developing (one who is first choice at a slot he can play, whatever his level at his other slots, could pass the first choice or make the second eleven, or has no level) says "renew it" at no points; for one not worth developing it keeps its words and points. The advice for him is one of four, with the engine's own sentences and each row showing its working (which says "now, fewer later" only when a later season's growth for his age is lower, at 20 or under, and not from 21, where it is the same every season): keep and develop (17 or under; or, when he is not getting his matches and is not needed as cover, on a youth contract or with twelve months or fewer left, or months unknown), keep and play (he is first choice, or has started a third of the confirmed matches of the last 60 days, or, with fewer than six confirmed, is a solid second choice), loan for matches (18 to 23, not on a youth contract, with more than twelve months left, worth developing, not getting his matches and not needed as cover) or watch (a player worth developing who is not getting his matches and is needed as cover, or one not worth developing who is not kept to play); one not worth developing (cover at best or markedly lower, and first choice at no slot he can play) is never developed or loaned, and is kept to play only when he is in an eleven and playing. A loan for matches is not a removal and is not counted among those advised to leave. These replaced the old prospect and false-prospect rules, except that a false prospect on a full-time contract is sold, not terminated. A player of 24 and over is scored as before; `ImportanceAdvisor` suggests an importance from the competition, the opponent and the schedule, and the owner's choice always wins; Mentoring (`Mentoring.report`) has its own entry point and is worked out per squad. It is handed the squad, the owner's entries (each player's hierarchy level and social group, and when they were entered), the groups the owner has recorded and the personality readings kept at each import, and it suggests groups of three from arrows. An arrow says how strongly one player of a group influences another (None, Light, Average or Significant, the game's words). The owner reads arrows off the game's screen and the engine keeps them for each pair of players; where none has been read it guesses, from the source's hierarchy level and the target's age (23 or under), and says on every line that it is a guess ("expected, not read") and, for one that was read, the day it was read. A group is any three players with no harmful arrow in it, where an arrow is harmful when it is above None and its source is worth less than its target on a counted attribute. A candidate's gain in a group is that of the one arrow into him with the greatest gain (a Light arrow from a much better player can beat a Significant one), never the sum. A player the owner's readings show takes nothing (None from at least three different sources at Influential or above, and nothing above None) is listed as not placed, and can still make up a group as its third member. Standing above a player by age, a lead for the group and the halving for a shared social group no longer exist. Values are shown as "Professionalism 8, towards 17". It predicts nothing: no gain or score is shown, only the strength and the two values. It also reviews recorded groups (what each member's values did, a warning when a group pulls someone down, a warning when all six of its arrows were read as None, and a warning when it has stopped working after thirteen weeks) and lists players it could not place, with a reason (takes nothing, nobody to influence him, nothing to gain because nobody who influences him is better anywhere it counts, too few players free, no third player free who could join him and a player who could help him without pulling anyone down, his possible influencers already taken, or every helpful group would pull someone down, which is also said when an influencer better in one value is worse by more in another). Every piece of advice carries the weakest evidence behind it, and most of the numbers are carried over from FM26 or the tool's own estimates.

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

- `LineupAppCore`: the app's state and every action, with no views. `AppModel` (observable, on the main actor) holds the squads, tactics, fixtures, confirmed lineups and settings, saves each change through `Store` as versioned JSON, and works out the plan by calling the engine's `Planner`. It works out the advice (the engine's `Advisors`, and each fixture's suggested importance) when it is first read after a change, and keeps it until the next. Everything a screen shows that is built from data (labels, rows, which fixture is chosen, status words) is worked out here, with tests.
- `LineupAppUI`: the SwiftUI views and `Theme`. Views hold layout only.
- `LineupApp`: the few lines that start the app.

Besides Squad, Tactics, Fixtures, Match Selection and Settings, the app has the advisor screens: Elevens (First XI, Second XI and Depth, for any saved tactic), Rest, Training (a Retraining tab: accept or turn down a recommended retraining, and follow its progress at each import; and a Mentoring tab, below) and Player Removal (with the loans to the club, and a Young players part showing each player of 23 or under with his reach and its working, his standing at his slot and his advice, stamped in the tone of his level's stamp in the table above; an opened row marks the player to sell or to loan out, except for a player on a youth contract, whose control is replaced by the engine's sentence saying he can only be kept or released, and a mark is dropped at the next import if he is on a youth contract, once every squad held has been imported without him, once he is on loan here, or, for a loan mark, once he is out on loan). Fixtures shows each fixture's suggested importance beside the one chosen. Settings has the Development slider beside Stability and Saving players. When a plan or the advice cannot be worked out, the notice leads to the screen that can put it right (a missing player value, or two players with one identity, to Squad, a fixture problem to Fixtures, bad settings to Settings) and offers no button where no screen can.

The Mentoring tab shows, for one squad at a time, the hierarchy, suggested groups, the owner's recorded groups and the players who could not be placed. Each group is shown as its arrows, one line each. FMRTE exports neither the hierarchy, the groups nor the arrows, so the owner enters the hierarchy by hand (a level for each player; a social group is still entered and kept but changes nothing), chooses a group's three members in an editor, and reads the arrows off the game in the arrows sheet. The sheet opens three ways: "Record arrows" beside "Add a group", "Record arrows" on a suggested group that rests on guesses, and "Arrows" on a recorded group; it also opens on its own after a new group is saved. Its "Set the rest to None" button sets every arrow not yet read to None, since the game shows only those above None. A reading is kept for each pair in the mentoring file, with its day, and fills the same pair in any later group; a read arrow is shown bold and a guess muted. A personality reading of every player is kept at each import, so what a group changed can be shown. The mentoring advice is worked out apart from the other advice, so a failure in one does not hide the other, and entering or recording something does not plan again. Tests show that saved state from before this plan, and from before the arrows, still opens with no notice; opening the real app on such a state has not been checked by hand.

The owner's own readings are a test fixture in `LineupEngine/Tests/LineupEngineTests/Fixtures/mentoring/`: the arrows of 24 groups of the first team as the game showed them on 14 November 2026, and the first team's ages, levels and personality values that day. The guess is checked against them (it agrees exactly with 104 of 124 pairs), and so are the suggestions made from them. `README.md` there says how they were taken.

Build and test it with:

    cd LineupApp && swift build && swift test

The tests take about three and a half minutes: each plan of the sample data takes most of a second in a debug build, and many tests plan.

Run it:

- `cd LineupApp && swift run LineupApp --sample-data ..` opens it on the engine's captures in a temporary directory. It does not touch real data, the clipboard or FMRTE's file.
- `tools/build_app.sh`, from the repository root, builds `build/FM27 Lineup Optimizer.app`, checks it can load the engine's resources, closes any open copy of the app and installs the build as `/Applications/FM27 Lineup Optimizer.app`, replacing what is there; if it closed an open copy, it opens the new one. That is the real app: it reads the clipboard and `~/Library/Application Support/FMRTE27/config.json`, and saves under `~/Library/Application Support/FM27 Lineup Optimizer/`. It is signed for this Mac only.

Draw the screens without opening a window:

    cd LineupApp && swift run -q LineupApp --sample-data .. --pictures .build/pictures

That writes a PNG of every screen and its variants (empty, failed, confirmed and so on), light and dark. A screen is not done until its pictures have been looked at. The pictures draw buttons as an inactive window would; judge the real look in the running app. The advisor screens were checked in `.build/pictures-advice`: `elevens-*`, `rest-*`, `training-*`, `removal-*`, and the suggestions in `fixtures-*` and `fixture-editor-suggestion-*`. The Young players part of Player Removal and the Development setting were checked in `.build/pictures-development`: `removal-young*` and `settings-*`. The Mentoring tab was checked in `.build/pictures-mentoring`: `training-mentoring-*`, including its two editors. The arrows sheet and the cards with read and guessed arrows were checked in `.build/pictures-arrows`: `training-mentoring-arrows-*`.

Rules for the app:

- The engine decides; the app shows. A view never computes a rating, a reason or a rule. Sentences for errors, warnings and reasons are the engine's (`ErrorDescriptions.describe`, and the reasons on picks and omissions), shown as written. Where the engine has no sentence for something, add one to the engine.
- Every word about advice (level names, actions, verdicts, evidence notes and sentences) comes from the engine (`AdvisorText`, `PositionText`, and the reasons on the reports), shown as written. Core holds only plain labels and headings.
- The Training screen ignores a training action within half a second of the end of the last one (`AppModel.trainingActionInterval`): accepting or turning down a card moves the next card's buttons under the pointer, so a double-click would otherwise act on the next player too.
- Logic for a screen lives in `LineupAppCore` with tests. If a view needs an `if` about data, that is a sign it belongs in Core.
- The look is the Tactics board in `docs/superpowers/specs/2026-11-13-fm27-app-visual-direction.md`. Its two typefaces, Bricolage Grotesque and Figtree, ship with their licences in `LineupAppUI`'s resources and are registered when the app starts. Every colour, typeface and measure comes from `Theme`; no view holds a literal colour, font name or measure.
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
