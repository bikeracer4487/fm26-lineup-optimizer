# FM27 Advisor Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The advisors the engine already has, shown in the Mac app: an Elevens screen (First XI, Second XI and Depth), Rest, Training with accept and reject and progress, Player Removal with the loan review, and a suggested importance on Fixtures.

**Architecture:** Two small engine tasks first: the words and sentences a screen needs, written once in the engine, and one entry point that works out every advisor from one set of elevens. Then the app: `LineupAppCore` keeps what the owner accepts and rejects, hands it to the engine with the squad, and turns the engine's reports into rows; `LineupAppUI` draws them in the Tactics board look. Nothing in a view computes a rule.

**Tech Stack:** Swift 6, macOS 26, SwiftUI and Observation, Swift Testing, Foundation only. Same packages and conventions as the engine, planner, advisors and first-screens plans.

**Spec:** `docs/superpowers/specs/2026-11-12-fm27-native-app-design.md`, sections 8.7, 8.8, 9 and 10; and `docs/superpowers/specs/2026-11-13-fm27-app-visual-direction.md` for the look. The advisors plan's closing sections (`docs/superpowers/plans/2026-11-13-fm27-advisors.md`, "Carried into the advisor screens plan", "Known limits", "Questions for the owner") are this plan's starting list.

## Decisions for you

Each has my recommendation, which the plan below follows. Say if you want another.

1. **Where the screens go.** Recommended: four more pills in the top row, after Match Selection: **Elevens**, **Rest**, **Training**, **Removal**. Every advisor is one click away and always in view. By my measure of the current pills the nine should fit on one row at the default window width (Task 4 checks it in the pictures); narrower, they wrap as they do now. The other way: one **Advice** pill that opens a second row of tabs. It keeps the top row short but hides the advisors a level down.
2. **First XI, Second XI and Depth are one screen** with three views (the design left this to you). Recommended, because they are one calculation for one tactic: the Elevens screen has a tactic menu and three tabs. The other way: three pills.
3. **Positions in words.** The engine's advisor reasons say "Cover at D (L) is thin". Recommended: reasons use football words ("Cover at left back is thin"), in the advisors and in the planner's retraining reason, so nothing you read on a screen is a code. Pitch magnets and table columns keep the short codes. Cost: the command-line tool's wording changes with it.
4. **Accepting a retraining tells the planner.** Recommended, and what the design says: once you accept, the planner's existing preference for giving that player minutes in his new position starts to apply, and the app records his familiarity there at every import so you can see real progress. Stopping a retraining ends both.

## Global Constraints

- The engine decides; the app shows. A view never computes a rating, a reason, a level or a rule. Every word about advice (levels, actions, verdicts, evidence notes, sentences) comes from the engine.
- Logic for a screen lives in `LineupAppCore` with tests written first. Views hold layout only.
- Every colour, typeface and measure comes from `Theme`. No literal colour, font name or measure in a view. The look is the Tactics board: magnets, sticky notes, marker pitch, stamps, ink rules.
- Nothing the owner reads is an id or a code: slots are "D L" on a token and "left back" in a sentence; fixtures are named by opponent and date; players by name.
- Advice that rests on carried-over or derived numbers is marked, with the engine's own note, wherever it is shown (spec 8.8).
- No silent defaults in the engine; every tunable number in `EngineParameters` with an evidence label and a source; every `switch` over an engine error, warning, cause, level, action or verdict exhaustive, with no `default`.
- The same inputs give the same report whatever the order of the input arrays.
- Saved state is versioned JSON under the Store's directory. A file that cannot be read gives a notice and a fresh start for that file, and is kept, never saved over. A file written by an earlier version of the app still opens.
- Tests, picture runs and sample-data runs never touch `~/Library/Application Support` or the real clipboard. The clipboard is read, never written.
- The repository is public: no player data outside `LineupEngine/Tests/LineupEngineTests/Fixtures/`. Pictures go under `LineupApp/.build/`.
- No build warnings in either package. Engine: `cd LineupEngine && swift test` passes, including the 594-case reference check, unchanged. App: `cd LineupApp && swift build && swift test` passes.
- A screen is not done until its pictures (`--pictures`), light and dark, at the default size and at 760 points wide, have been looked at.
- Do not modify Python, `ui/`, `.bat` files, existing fixtures, `README.md`, `Resources/rating_tables.json` or `Resources/rating_profile_fm27.json`.

## Review Focus

Inputs the spec implies but does not spell out, most likely first. Each has a test in the task named.

1. **No squad, no tactic, or a tactic the engine refuses.** Expected: every advisor screen says what is missing and has the button that fixes it, as Match Selection does. No empty table, no crash. (Task 4)
2. **A saved file from before this plan** (fixtures without a competition; no training file). Expected: it opens, the new fields are empty, nothing is lost. (Task 3)
3. **An accepted retraining whose player has left the squad, or moved between squads.** Expected: it is shown as "no longer in the squad" with its history and can be stopped; it is not handed to the planner or the advisors as a live retraining. (Tasks 3, 7)
4. **An import on the same day twice, or with the current date moved back.** Expected: one familiarity observation a day for each retraining, the later one; none dated before the retraining was accepted. (Task 3)
5. **Long lists and long names at 760 points wide.** Expected: reasons wrap, tables scroll down not sideways, nothing is cut off. (Tasks 5 to 9)

---

### Task 1: The engine's words for advice

**Files:**
- Create: `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText.swift`, `LineupEngine/Sources/LineupEngine/Reporting/PositionText.swift`
- Modify: `Advisors/Depth.swift`, `Advisors/Training.swift`, `Advisors/Removal.swift`, `Advisors/RetrainingTracker.swift`, `Planner/ImportanceRules.swift` (the retraining reason), `Selection/FitnessModel.swift`, `Sources/lineup-cli/Report.swift`
- Test: `AdvisorTextTests.swift`, `PositionTextTests.swift`, and the advisors' existing tests where wording changes

**Interfaces:**
- Produces:
  ```swift
  public enum PositionText {
      /// "left back", "centre-back", "defensive midfield", "left wing" … for a sentence.
      public static func plain(_ position: Position) -> String
      /// The same for a slot: "left centre-back" for D_CL.
      public static func plain(_ slot: SlotID) -> String
  }
  public enum AdvisorText {
      public static func name(_ level: RestLevel) -> String            // "Holiday", "Rest", "Watch"
      public static func name(_ level: RemovalLevel) -> String         // "Critical", "High", "Medium", "Keep"
      public static func name(_ action: RemovalAction) -> String       // "Release", "Loan out", "Terminate", "Sell", "Monitor", "Keep"
      public static func name(_ verdict: LoanVerdict) -> String        // "End early", "Do not extend", "Keep to the end", "Make permanent"
      public static func name(_ difficulty: RetrainingDifficulty) -> String
      public static func name(_ competition: Competition) -> String
      public static func name(_ strength: OpponentStrength) -> String
      /// nil for the three FM27 labels; "FM26-era numbers"; "this tool's estimate".
      public static func note(for basis: Evidence) -> String?
      public static func clear(in advice: RestAdvice) -> String?       // "Clear in about 3 days"; nil for watch
      public static func costs(of advice: RemovalAdvice) -> String     // "Releasing him costs £26,000; a mutual termination about £14,300"
      public static func why(_ action: RemovalAction, for advice: RemovalAdvice) -> String
      public static func cover(_ slot: SlotDepth, parameters: EngineParameters) -> String   // "1 solid player; 2 needed"
      public static func whatCoverCounts(_ parameters: EngineParameters) -> String
      public static func progress(_ progress: RetrainingProgress, toward position: Position, parameters: EngineParameters) -> String
  }
  ```
- Consumes: the advisors' reports as built.

Decisions:

- The app's slot words live in `LineupAppCore/SlotText.swift` today. The words move to the engine's `PositionText`; `SlotText.longName` calls it, so there is one list.
- Advisor reasons and the planner's retraining reason use `PositionText.plain`. Exact sentences change from "Cover at D (L) is thin in …" to "Cover at left back is thin in …", "In the first eleven at centre-back", "From right back: a structural change, about 21 weeks at his age and Versatility", and so on. Tests that pin sentences are changed to the new words.
- `why(_:for:)` gives the rule that chose the action, one sentence each: not full-time, a prospect, the contract ends within the year and no fee is likely, otherwise sell; monitor and keep.
- `progress` covers the four states: no observations yet; improving with the rate and weeks left; stalled; reached.
- `FitnessModel.problems(in:)` also reports `importanceRules.sharpnessBelow` outside 0 to 1 (left over from the advisors' last review).
- The command-line tool prints through `AdvisorText`; its own copies of these words are deleted.

- [ ] **Step 1: Write the failing tests**: every case of every `name` (exhaustive, by `allCases`); `note` for the five labels; `clear` for a holiday, rest with a known and an unknown day count, and watch; `costs` with known, unknown and zero costs; `why` for each action; `cover` at 0, 1 and at the line; `progress` for the four states; `PositionText` for every `Position` and every `SlotID`, with no two slots sharing a name; one advisor reason of each kind in words; the sharpness check.
- [ ] **Step 2: Run** `cd LineupEngine && swift test --filter "AdvisorTextTests|PositionTextTests"` — expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `swift test` in the engine, then `cd LineupApp && swift build && swift test` — all PASS, no warnings.
- [ ] **Step 5: Commit** — "Write the advisors' words once, in the engine, with positions in football words".

---

### Task 2: One entry point for every advisor

**Files:**
- Create: `LineupEngine/Sources/LineupEngine/Advisors/Advisors.swift`
- Modify: `Advisors/Depth.swift`, `Advisors/Training.swift`, `Advisors/Removal.swift` (internal overloads that take elevens and depth already worked out), `Sources/lineup-cli/main.swift`
- Test: `AdvisorsTests.swift`, `EndToEndTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct AdvisorsRequest: Sendable {
      public var primary: Tactic                 // Elevens, Depth and Player Removal judge against it
      public var tactics: [Tactic]               // every saved tactic, for Training's needs
      public var players: [Player]
      public var ownClub: String?
      public var history: StartHistory
      public var asOf: Day
      public var intensity: TrainingIntensity
      public var accepted: [Retraining]
      public var rejected: Set<RetrainingChoice>
  }
  public struct AdvisorsReport: Equatable, Sendable {
      public let elevens: ElevensReport
      public let depth: DepthReport
      public let rest: [RestAdvice]
      public let removal: RemovalReport
      public let training: TrainingReport        // never recommends removal.advisedToLeave
  }
  public enum Advisors {
      public static func report(_ request: AdvisorsRequest, catalog: RoleCatalog, profile: RatingProfile,
                                parameters: EngineParameters) throws -> AdvisorsReport
  }
  ```

Decisions:

- The elevens are solved once for the primary tactic and once for each other saved tactic, and handed to Depth, Removal and Training. Each public advisor function keeps working alone and gives the same answer as before.
- Player Removal runs before Training, and Training is handed `advisedToLeave`.
- The command-line `advise` calls `Advisors.report`.

- [ ] **Step 1: Write the failing tests**: `theReportEqualsTheAdvisorsCalledOneByOne` (on `PlannerFixture`'s squad and on the real captures); `trainingNeverRecommendsAPlayerRemovalWouldMoveOn`; `twoSavedTacticsGiveNeedsFromBoth`; `inputOrderDoesNotMatter`; a bad parameter throws `PlanError.badParameters` once.
- [ ] **Step 2: Run** `swift test --filter AdvisorsTests` — expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `swift test` — all PASS. Time `lineup-cli advise` on the captures before and after and put both in the report.
- [ ] **Step 5: Commit** — "Work out every advisor from one set of elevens".

---

### Task 3: What the app keeps for the advisors

**Files:**
- Create: `LineupApp/Sources/LineupAppCore/AppModel+Training.swift`
- Modify: `StoredTypes.swift`, `Store.swift` (a `training` file), `AppModel.swift`, `AppModel+Squad.swift` (observations at import), `AppModel+Fixtures.swift`, `AppModel+Plan.swift` (hand accepted retrainings to the planner), `FixturePresentation.swift` (`FixtureDraft`)
- Test: `StoreTests.swift`, `AppModelTests.swift`, `PlanStateTests.swift`, a new `TrainingStateTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct TrainingState: Equatable, Codable, Sendable {      // saved as training.json, version 1
      public var accepted: [Retraining]
      public var rejected: Set<RetrainingChoice>
      public var observations: [RetrainingChoice: [FamiliarityObservation]]   // saved in a fixed order
      public var names: [PlayerID: String]                          // as when accepted or rejected
  }
  // StoredFixture gains:  public var competition: Competition?;  public var opponentStrength: OpponentStrength?
  // FixtureDraft gains the same two fields.
  extension AppModel {
      public private(set) var training: TrainingState
      public func accept(_ choice: RetrainingChoice)         // dated with the current date; clears a rejection of the same pair
      public func reject(_ choice: RetrainingChoice)
      public func stopRetraining(_ choice: RetrainingChoice)  // forgets the acceptance and its observations
      public func allowAgain(_ choice: RetrainingChoice)      // undoes a rejection
  }
  ```

Rules:

- Accepting records the player's familiarity at that position today as the first observation.
- Every import of a squad records, for each accepted retraining of a player in that squad, his familiarity at the position, dated with the import's date: one observation a day, the later one replacing the earlier; none dated before the acceptance (Review Focus 4).
- The planner is handed the accepted retrainings of players who are still in the squad book (Review Focus 3).
- A fixtures file without the two new fields opens with both empty (Review Focus 2). The training file is new: missing means empty.
- Changing any of this works out the plan and the advice again.

- [ ] **Step 1: Write the failing tests**: the training file round-trips and saves in a fixed order; an old fixtures file opens; accept, reject, stop and allow-again and their effect on each other; the first observation; observations at import (same day twice, date moved back, a player not in the imported squad, a player who has left); the planner request carries accepted retrainings and a player's reason appears in the plan; an unreadable training file gives a notice and is kept.
- [ ] **Step 2: Run** `cd LineupApp && swift test --filter "TrainingStateTests|StoreTests"` — expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `swift build && swift test` — all PASS, no warnings.
- [ ] **Step 5: Commit** — "Keep accepted and rejected retrainings, their progress, and each fixture's competition".

---

### Task 4: The advice in the model, and the four screens' places

**Files:**
- Create: `LineupApp/Sources/LineupAppCore/AdviceState.swift`, `AppModel+Advice.swift`, `AdvicePresentation.swift`
- Modify: `Screen.swift`, `Navigation.swift`, `AppModel.swift`, `SampleData.swift`, `LineupAppUI/RootView.swift`, `ScreenPictures.swift`
- Create (UI): `LineupAppUI/Advice/AdviceGate.swift` (the shared "what is missing" state)
- Test: `AdviceStateTests.swift`, `ScreenTests.swift`

**Interfaces:**
- Produces:
  ```swift
  // Screen gains: elevens, rest, training, removal — after matchSelection, before settings.
  //   title: "Elevens", "Rest", "Training", "Player Removal";  pillTitle: the same except "Removal".
  public enum AdviceState: Equatable, Sendable {
      case needsSquad
      case needsTactic([String])                 // the engine's sentences for why the primary tactic cannot be used
      case failed([String], fix: Screen)
      case ready(AdvisorsReport)
  }
  extension AppModel {
      public var adviceState: AdviceState                      // worked out with the plan, from the same squad and date
      public var suggestions: [FixtureID: ImportanceSuggestion] // for fixtures not yet confirmed; empty when not ready
      public func elevens(for tacticID: UUID?) -> ElevensState   // nil: the primary
  }
  public enum ElevensState: Equatable, Sendable {
      case notReady(AdviceState)                 // no squad, or no usable primary tactic
      case failed([String])                      // the engine's sentences for this tactic
      case ready(ElevensReport, DepthReport)
  }
  // Navigation gains: elevensView (.first, .second, .depth), elevensTacticID: UUID?, elevensSlot: SlotID?,
  //   removalShown: Set<PlayerID> (rows opened), trainingShown.
  ```

Rules:

- The advice is worked out wherever the plan is, from the same players, club, date and history, with the primary tactic and every saved tactic that the engine accepts. The plan's own failure does not stop the advice, and the advice's does not stop the plan.
- If working it out makes the app's tests or a slider feel slow, it is worked out when first read after a change instead; say which in the report with the timings.
- The suggestion for a fixture uses the planner's tiers for that fixture's tactic.
- An advisor screen that is not ready shows the same kind of empty state as Match Selection, with the engine's sentence and the button for the screen that fixes it (Review Focus 1).
- `--sample-data` accepts one retraining and sets competitions on the sample fixtures, so every screen has something to draw.

- [ ] **Step 1: Write the failing tests**: each `AdviceState` case from the model's state; the advice changes after an import, a tactic edit, a confirmed lineup, an accepted retraining and a settings change; suggestions exist for unconfirmed fixtures only and use the fixture's own tactic; `elevens(for:)` for the primary and for another tactic, and its failure; the new screens' titles and order.
- [ ] **Step 2: Run** `swift test --filter "AdviceStateTests|ScreenTests"` — expect FAIL.
- [ ] **Step 3: Implement**, with the four new screens showing their gate or a heading only.
- [ ] **Step 4: Run** `swift build && swift test`; draw the pictures and look at the navigation at the default width and at 760 points: nine pills, none cut off.
- [ ] **Step 5: Commit** — "Work out the advice in the model and give the advisors their places".

---

### Task 5: The Elevens screen: First XI, Second XI and Depth

**Files:**
- Create: `LineupAppCore/ElevensPresentation.swift`, `LineupAppUI/Advice/ElevensScreen.swift`, `DepthPanel.swift`
- Modify: `Theme.swift`, `ScreenPictures.swift`
- Test: `ElevensPresentationTests.swift`

What it shows:

- A tactic menu (the primary by default) and three tabs in the style of the Squad screen's filter: **First XI**, **Second XI**, **Depth**.
- **First XI** and **Second XI**: the pitch, drawn as Match Selection's, with each player's magnet, surname and rating; an injured player's magnet carries the injured mark; an unfilled slot is the dashed circle. Beside it: the average rating as a figure card, and a list of the eleven with familiarity in each phase. A player far out of position (below the cover line in either phase) is marked "out of position".
- **Depth**: the same pitch, each slot's magnet showing its cover count, with a red stamp "Thin" on thin slots. Choosing a slot shows its options beside the pitch, best first: name, squad, rating, familiarity in each phase, a tick where he counts as cover, his mark when he cannot play today, and "also needed at left back" where the cover is shared. Under them, players out on loan, apart. Above the pitch: a sticky note "Recruit first: goalkeeper, left back"; and one line saying what cover counts (the engine's sentence) with the evidence note.

- [ ] **Step 1: Write the failing tests** for the rows, labels, marks, the selected slot (default: the thinnest), the recruit note's words, and the empty cases (an unfilled slot, a slot with no options).
- [ ] **Step 2: Run** — expect FAIL.
- [ ] **Step 3: Implement** Core, then the views.
- [ ] **Step 4: Run** `swift build && swift test`. Draw and look at: `elevens-first`, `elevens-second`, `elevens-depth`, `elevens-depth-small`, `elevens-empty`, light and dark.
- [ ] **Step 5: Commit** — "Show the first and second elevens and the cover for every slot".

---

### Task 6: The Rest screen

**Files:**
- Create: `LineupAppCore/RestPresentation.swift`, `LineupAppUI/Advice/RestScreen.swift`
- Modify: `ScreenPictures.swift`
- Test: `RestPresentationTests.swift`

What it shows: one row for each player the engine lists, most urgent first: a stamp (Holiday in red, Rest in amber, Watch in ink), his name and squad, jadedness against his own limit with the limit's notes, the condition meter, his run of starts, "Clear in about 3 days", and his reasons in full underneath. The evidence note sits beside each row's stamp. A line under the heading says the planner decides who starts and this screen says who needs a break. When nobody is listed: "Nobody needs rest today."

- [ ] **Step 1: Write the failing tests** for the rows, the stamp words and colours' names, the limit's notes, the empty state.
- [ ] **Step 2: Run** — expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run**; draw and look at `rest`, `rest-small`, `rest-nobody`.
- [ ] **Step 5: Commit** — "Show who needs a holiday, rest or watching".

---

### Task 7: The Training screen

**Files:**
- Create: `LineupAppCore/TrainingPresentation.swift`, `LineupAppUI/Advice/TrainingScreen.swift`, `RetrainingCard.swift`
- Modify: `ScreenPictures.swift`
- Test: `TrainingPresentationTests.swift`

What it shows, in four parts:

- **Recommended**: a card for each recommendation: the player and his age, "learn left back", the slots and tactics it would cover, his familiarity there now, the weeks, his reasons marked with a plus, his cautions marked as cautions, the evidence note, and two buttons: **Accept** (the screen's main action) and **Not him**.
- **Being retrained**: each accepted retraining with the day it was accepted, familiarity then and now on a small track from 1 to 20 with the solid line marked, the engine's progress sentence, and **Stop**. A player no longer in the squad is shown as such and can only be stopped (Review Focus 3).
- **Recruit instead**: the thin slots nobody suits, by tactic, and the slots already being retrained for.
- **Turned down**: rejected pairs, each with **Offer again**.

- [ ] **Step 1: Write the failing tests** for the four parts' rows, the buttons' effects through the model, the track's values, a departed player, and the empty states of each part.
- [ ] **Step 2: Run** — expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run**; draw and look at `training`, `training-small`, `training-accepted`, `training-none`.
- [ ] **Step 5: Commit** — "Recommend retraining, take the owner's answer and show the progress".

---

### Task 8: The Player Removal screen

**Files:**
- Create: `LineupAppCore/RemovalPresentation.swift`, `LineupAppUI/Advice/RemovalScreen.swift`
- Modify: `ScreenPictures.swift`
- Test: `RemovalPresentationTests.swift`

What it shows:

- Two figure cards: the first team's average ability, and the weekly wages of the critical and high players.
- A table, highest score first: a stamp for the level, the action in words, name, squad, age, score, and the costs sentence. Critical and high rows are open, showing every reason with its points (plus in red, minus in green: points against him and for him), the sentence for why that action, and the evidence note. Medium and keep rows are closed and open on a click. A filter in the Squad screen's style: All, Critical and high, Medium, Keep.
- **Loans to the club**: each loanee's verdict, score and reasons, or "Nobody is on loan here."
- One line under the heading: the advice judges players against the primary tactic.

- [ ] **Step 1: Write the failing tests** for the rows, the open and closed rule, the filter, the points' signs and colours' names, the loan review, the empty squad.
- [ ] **Step 2: Run** — expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run**; draw and look at `removal`, `removal-small`, `removal-all-open`.
- [ ] **Step 5: Commit** — "Show who to sell, loan out or release, with every reason".

---

### Task 9: The suggested importance on Fixtures

**Files:**
- Modify: `LineupAppCore/FixturePresentation.swift`, `AppModel+Fixtures.swift`, `LineupAppUI/Fixtures/FixturesScreen.swift`, `FixtureEditor.swift`, `ScreenPictures.swift`
- Test: `FixturePresentationTests.swift`

What changes:

- The fixture editor gains two menus, **Competition** and **Opponent**, each with "Not set". Under the importance menu it shows the suggestion for the fixture as it is being edited, with its reasons and the evidence note, and a button **Use it** when it differs from what is chosen.
- In the table, a fixture whose suggestion differs from its importance shows "Suggested: High" in muted ink under the importance note; hovering or clicking shows the reasons. A fixture that agrees shows nothing extra.
- The owner's choice always wins: nothing changes an importance but the owner.

- [ ] **Step 1: Write the failing tests** for the draft's two fields, the suggestion text and when it shows, **Use it**, and a fixture with nothing set (the schedule alone).
- [ ] **Step 2: Run** — expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run**; draw and look at `fixtures`, `fixtures-small`, `fixture-editor-suggestion`.
- [ ] **Step 5: Commit** — "Suggest an importance for each fixture and let the owner take it".

---

### Task 10: The app, built and checked

**Files:**
- Modify: `LineupApp/Tests/LineupAppCoreTests/EndToEndTests.swift`, `tools/build_app.sh` (only if the picture check needs the new names), `CLAUDE.md`
- Test: `EndToEndTests.swift`

- [ ] **Step 1: Write the failing test** `theAdvisorScreensWorkOnTheRealSquad`: on the engine's captures, the advice is ready; the Elevens rows match the engine's report; accepting the first recommendation moves it to "being retrained", gives the planner the retraining and survives reopening the model from the same directory; rejecting the next removes it and offers another or lists the need; an import records an observation; the fixtures' suggestions are present.
- [ ] **Step 2: Run** — expect FAIL, then make it pass.
- [ ] **Step 3: Build the app** with `tools/build_app.sh`; draw every picture from the built app; look at each advisor screen's pictures once more, light and dark, default and 760 wide.
- [ ] **Step 4: Update `CLAUDE.md`**: the app has the advisor screens; this plan is complete; the rule that the engine holds every word about advice. Nothing else.
- [ ] **Step 5: Commit** — "Check the advisor screens on the real squad and build the app".

---

## After this plan

What is left of the rebuild: the clean-up plan (removing the Electron app, the Python and the `.bat` files, and deciding where the rewrite lives).

Known limits of this plan, for the owner:

- The advice is only as current as the last import, like the plan.
- The advisor screens are checked from drawn pictures and by building, not by anyone using them.
- The questions at the end of the advisors plan (youth contract types, one retraining at a time, "months left 0") are still open; the screens show what the engine does today.
