# FM27 App, First Screens: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Mac app the owner can use today for what the engine already does: import each squad from FMRTE's clipboard, build tactics, keep a fixture list, and see the planned lineups for the next fixtures with every reason, with override, reject, confirm and unlock.

**Architecture:** A second Swift package, `LineupApp/`, beside the engine and depending on it. Three targets: `LineupAppCore` holds the app's state, its saved files and every action, with no views, and carries the tests; `LineupAppUI` holds the SwiftUI views and one `Theme`; `LineupApp` is the few lines that start the app. Views read an observable `AppModel` and call its actions; nothing in a view decides anything. A script assembles a double-clickable app. The app can also draw each screen to a picture file from sample data, so screens can be checked without anyone looking at a window.

**Tech Stack:** Swift 6, SwiftPM, SwiftUI and Observation on macOS 26, Swift Testing, AppKit only for the clipboard and for drawing pictures. No third-party dependencies.

**Spec:** `docs/superpowers/specs/2026-11-12-fm27-native-app-design.md`, sections 8.1 to 8.3, 8.6 ("User control"), 9, 10 and 11; and `docs/superpowers/specs/2026-11-13-fm27-app-visual-direction.md`. Read the visual direction before any task that draws a screen.

## Global Constraints

- The engine decides; the app shows. A view never computes a rating, a reason or a rule. Sentences for errors, warnings and reasons are the engine's (`ErrorDescriptions.describe` and the reasons on picks and omissions), shown as written.
- No silent wrong data (spec 4). A failed import changes nothing and says why, where the button was pressed.
- App state lives in `~/Library/Application Support/FM27 Lineup Optimizer/`, never in the repository. Files are JSON with a version number. A file that cannot be read gives a notice and a fresh start for that file; the unreadable file is kept beside it, renamed, never deleted (spec 9).
- The repository is public: no player data outside `LineupEngine/Tests/LineupEngineTests/Fixtures/`. Pictures of screens made from the captures go to a git-ignored directory. Nothing personal in the code: the bundle identifier is `local.fm27.lineup-optimizer`.
- The only thing read from another app's folder is FMRTE's `config.json`. The clipboard is read, never written.
- Every colour, typeface and measure comes from `Theme` (the visual direction's tokens). No literal colour or font name in a view.
- Words on screen are plain and in sentence case; a button says what it does; an empty screen says what is missing and offers the action that fixes it.
- The engine package is not changed by this plan except where a task says so. `cd LineupEngine && swift test` still passes.
- `cd LineupApp && swift build` has no warnings, and `swift test` passes, after every task.
- Do not modify Python, `ui/`, `.bat` files, existing fixtures or `README.md`.
- Paths in tasks are relative to `LineupApp/` unless they start with `LineupEngine/`, `tools/`, `docs/` or are `CLAUDE.md` or `.gitignore`.
- Not in this plan: the advisor screens (First XI, Second XI, Depth, Training, Rest, Player Removal), the importance suggestion, retraining, signing or distribution.

## Review Focus

Conditions the spec implies but does not spell out, most likely first. Each has a test in the task named.

1. **A state file that cannot be read**: cut short, not JSON, or from a newer version. Expected: a notice naming the file, that file starts fresh, the others load, and the bad file is kept under a new name. (Task 2)
2. **Import with nothing usable**: an empty clipboard, text that is not FMRTE rows, FMRTE's `config.json` missing. Expected: a plain sentence on the Squad screen, and the squad exactly as it was. (Task 3)
3. **Saved things that point at something gone**: a fixture whose tactic was deleted, an override or rejection naming a player who has left, a confirmed lineup naming players who have left. Expected: the fixture uses the primary tactic and says so; the override is reported as ignored with the engine's reason; the confirmed lineup still shows the names it was confirmed with. (Tasks 3 and 7)
4. **Nothing to plan with**: no squad, no tactic, or no fixtures. Expected: Match Selection says which is missing and offers the way there. (Tasks 7 and 8)
5. **The current date moved past a fixture that was never confirmed.** Expected: the plan stops with the engine's sentence naming the fixture, and the fixture is marked on the Fixtures screen. (Task 7)

---

### Task 1: The package, the theme and an app that opens

**Files:**
- Create: `Package.swift`, `Sources/LineupAppCore/Screen.swift`, `Sources/LineupAppUI/Theme.swift`, `Sources/LineupAppUI/RootView.swift`, `Sources/LineupAppUI/EmptyState.swift`, `Sources/LineupAppUI/ScreenPictures.swift`, `Sources/LineupApp/main.swift` (or `LineupApp.swift` with `@main`), `Tests/LineupAppCoreTests/ScreenTests.swift`, `tools/build_app.sh`
- Modify: `.gitignore` (add `LineupApp/.build/`, `build/`)

**Interfaces:**
- Produces:
  ```swift
  // LineupAppCore
  public enum Screen: String, CaseIterable, Identifiable, Sendable {
      case squad, tactics, fixtures, matchSelection, settings
      public var title: String        // "Squad", "Tactics", "Fixtures", "Match Selection", "Settings"
  }
  // LineupAppUI
  public enum Theme { /* colours, fonts, spacing: every token of the visual direction */ }
  public struct EmptyState: View { public init(_ message: String, action: String? = nil, perform: (() -> Void)? = nil) }
  public struct RootView: View { /* a NavigationSplitView: the sidebar lists Screen.allCases */ }
  public enum ScreenPictures {
      /// Draws each named screen at the given size, in light and in dark, and writes
      /// "<screen>-light.png" and "<screen>-dark.png" into `directory`.
      @MainActor public static func write(to directory: URL, size: CGSize) throws
  }
  ```
- Command line of the app: no arguments opens the window. `--pictures <directory>` writes the pictures and exits with status 0, or prints the problem and exits with 1. Later tasks add `--sample-data <repository root>`.

Decisions:

- `Package.swift`: tools version 6.0, platform macOS 26, a dependency on the engine by path (`../LineupEngine`), targets `LineupAppCore` (depends on `LineupEngine`), `LineupAppUI` (depends on both), `LineupApp` (executable, depends on both), `LineupAppCoreTests`.
- `Theme` holds the six named colours with their light and dark values, the two DIN faces with their fallback, the type scale 13, 16, 20, 25, 31, and a spacing scale of 4, 8, 12, 16, 24. A colour is made from its two hex values so it follows the system's appearance.
- The app is not a bundle when started with `swift run`, so on launch it makes itself a regular app (a Dock icon, a menu bar) and comes to the front.
- `tools/build_app.sh` builds the release configuration and assembles `build/FM27 Lineup Optimizer.app`: the executable, an `Info.plist` (bundle identifier `local.fm27.lineup-optimizer`, name "FM27 Lineup Optimizer", minimum system 26.0, high-resolution capable), and every SwiftPM resource bundle beside the executable copied into `Contents/Resources`. It signs the app ad hoc and prints the app's path.
- Each of the five screens shows its title and an `EmptyState` for now. The pictures are drawn by hosting the view in a window that is never shown.

- [ ] **Step 1: Write the failing test** — `ScreenTests`: the five screens in order, their titles as above.
- [ ] **Step 2: Run** `cd LineupApp && swift test` — expect FAIL (no package yet).
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `swift build 2>&1 | grep -c "warning:"` — expect 0; `swift test` — PASS.
- [ ] **Step 5: Run** `swift run -q LineupApp --pictures .build/pictures` — expect ten PNG files, each showing the sidebar and the screen's title, light and dark. Then `tools/build_app.sh` from the repository root — expect the app's path; run its executable with `--pictures` once to prove the bundle works.
- [ ] **Step 6: Commit** — "Start the Mac app: a package, a theme and five empty screens".

---

### Task 2: Saved files

**Files:**
- Create: `Sources/LineupAppCore/Store.swift`, `Sources/LineupAppCore/StoredTypes.swift`
- Test: `Tests/LineupAppCoreTests/StoreTests.swift`

**Interfaces:**
- Consumes: the engine's `Tactic`, `FixtureID`, `Day`, `Importance`, `SlotID`, `PlayerID`, `PlanSettings`, `SquadBook`, `Squad`, `ConfirmedLineup` (all `Codable`).
- Produces:
  ```swift
  public struct StoredTactic: Identifiable, Equatable, Codable, Sendable {
      public var id: UUID
      public var tactic: Tactic
  }
  public struct StoredFixture: Identifiable, Equatable, Codable, Sendable {
      public var id: FixtureID
      public var date: Day
      public var opponent: String
      public var importance: Importance
      public var tacticID: UUID?                 // nil: the primary tactic
      public var overrides: [SlotID: PlayerID]
      public var rejected: Set<PlayerID>
  }
  public struct ConfirmedRecord: Equatable, Codable, Sendable {
      public var lineup: ConfirmedLineup
      public var names: [PlayerID: String]       // as they were when confirmed
      public var tacticName: String
  }
  public struct AppSettings: Equatable, Codable, Sendable {
      public var currentDate: Day
      public var plan: PlanSettings
      public var clubName: String?               // overrides the club worked out from the squad
      public var primaryTacticID: UUID?
      public var conditionFloor: Double?         // nil: the engine's value
      public var fmrteConfigPath: String?        // nil: ~/Library/Application Support/FMRTE27/config.json
      public init(currentDate: Day)              // everything else at its default
  }
  public struct SquadState: Equatable, Codable, Sendable {
      public var book: SquadBook
      public var importedOn: [Squad: Day]
      public init()
  }
  public enum StoreFile: String, CaseIterable, Sendable { case settings, tactics, fixtures, history, squad }
  public struct Loaded<Value> { public let value: Value; public let notice: String? }
  public struct Store: Sendable {
      public init(directory: URL)
      public func load<Value: Codable>(_ file: StoreFile, as: Value.Type, otherwise fresh: Value) -> Loaded<Value>
      public func save<Value: Codable>(_ value: Value, to file: StoreFile) throws
  }
  ```

Rules:

- Each file is `<name>.json` holding `{"version": 1, "value": …}`, written whole to a temporary file and moved into place, with sorted keys so two saves of the same state are the same bytes.
- A missing file gives the fresh value. It gives a notice only when the directory already holds another of the app's files: "No saved fixtures were found, so the list starts empty."
- A file that is not readable JSON, does not decode, or has a version above 1 gives the fresh value and a notice naming the file and the reason in plain words, and is renamed to `<name>.unreadable-<n>.json` with the first free number (Review Focus 1).
- `save` creates the directory if it is missing.

- [ ] **Step 1: Write the failing tests** (each in its own temporary directory)
  - `everyStoredTypeRoundTrips`: one value of each of the five files' types.
  - `savingTwiceWritesTheSameBytes`.
  - `aFirstRunHasNoNotices`: an empty directory, all five loads give the fresh value and nil.
  - `aMissingFileBesideOthersIsNoticed`.
  - `aFileCutShortIsKeptAsideAndStartsFresh`; `aFileThatIsNotJSONIsKeptAsideAndStartsFresh`; `aFileFromANewerVersionIsKeptAsideAndStartsFresh`; `aSecondUnreadableFileGetsTheNextNumber`; `theOtherFilesStillLoad`.
  - `dictionariesKeyedBySlotAndPlayerAreJSONObjects`.
- [ ] **Step 2: Run** `swift test --filter StoreTests` — expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `swift test` — PASS; no build warnings.
- [ ] **Step 5: Commit** — "Save the app's state as versioned files that fail safely".

---

### Task 3: The app model: squads, tactics, fixtures and settings

**Files:**
- Create: `Sources/LineupAppCore/AppModel.swift`, `Sources/LineupAppCore/AppModel+Squad.swift`, `Sources/LineupAppCore/AppModel+Tactics.swift`, `Sources/LineupAppCore/AppModel+Fixtures.swift`, `Sources/LineupAppCore/SampleData.swift`
- Test: `Tests/LineupAppCoreTests/AppModelTests.swift`, `Tests/LineupAppCoreTests/Support/TestModel.swift`

**Interfaces:**
- Consumes: `Store` and the stored types; the engine's `Importer.importPlayers(clipboard:fmrteConfig:squad:)`, `SquadBook.apply`, `SquadBook.ownClub(override:)`, `SquadBook.warnings(override:)`, `RoleCatalog.fm27()`, `Tactic.problems(catalog:)`, `ErrorDescriptions.describe`.
- Produces:
  ```swift
  public struct Notice: Identifiable, Equatable, Sendable { public let id: UUID; public let text: String }
  public struct ImportSummary: Equatable, Sendable {
      public let squad: Squad
      public let grid: String                    // the FMRTE grid recognised
      public let playerCount: Int
      public let onLoan: [String]                // names of players out on loan
      public let warnings: [String]              // the engine's sentences
      public let change: SquadChange
  }
  public enum ImportOutcome: Equatable, Sendable { case imported(ImportSummary), failed(String) }
  public struct AppEnvironment: Sendable {      // not "Environment": SwiftUI has one
      public var today: @Sendable () -> Day
      public var clipboard: @Sendable () -> String?
      public var fmrteConfig: @Sendable (_ path: String?) throws -> Data     // nil: the default path
  }

  @MainActor @Observable public final class AppModel {
      public init(store: Store, environment: AppEnvironment)
      public private(set) var squad: SquadState
      public private(set) var tactics: [StoredTactic]
      public private(set) var fixtures: [StoredFixture]        // in date order, then id
      public private(set) var history: [ConfirmedRecord]
      public private(set) var settings: AppSettings
      public private(set) var notices: [Notice]
      public private(set) var lastImport: ImportOutcome?
      public let catalog: RoleCatalog

      public func dismiss(_ notice: Notice)

      // Squad
      public func importSquad(_ squad: Squad)
      public var players: [Player]               // every squad, by name
      public var ownClub: String?
      public var squadWarnings: [String]

      // Tactics
      public var primaryTactic: StoredTactic?
      @discardableResult public func addTactic(named name: String) -> UUID      // a 4-2-3-1 to start from
      public func update(_ tactic: StoredTactic)
      public func duplicateTactic(_ id: UUID) -> UUID?
      public func deleteTactic(_ id: UUID)
      public func makePrimary(_ id: UUID)
      public func problems(of tactic: Tactic) -> [String]

      // Fixtures and settings
      @discardableResult public func addFixture(date: Day, opponent: String, importance: Importance) -> FixtureID
      public func update(_ fixture: StoredFixture)
      public func deleteFixture(_ id: FixtureID)
      public func update(_ settings: AppSettings)
      public func tactic(for fixture: StoredFixture) -> StoredTactic?            // his own, else the primary
  }

  public enum SampleData {
      /// A model on a temporary directory, filled from the engine's captures under `repositoryRoot`:
      /// both squads, the sample 4-2-3-1 as the primary tactic, the five sample fixtures and the sample history.
      @MainActor public static func model(repositoryRoot: URL) throws -> AppModel
  }
  ```

Rules:

- **Loading.** `init` loads the five files, collects their notices, and uses `environment.today()` for a first run's current date.
- **Saving.** Every action that changes state saves the file concerned before it returns. A save that fails adds a notice with the reason; the change stays in memory.
- **Import.** Reads the clipboard and FMRTE's configuration through the environment and calls the engine's importer. On success the book takes the import, `importedOn[squad]` becomes the current date, and `lastImport` is the summary. On any failure nothing changes and `lastImport` is `.failed` with the sentence: the engine's for an engine error; "The clipboard is empty. Copy the rows in FMRTE first." for nothing on the clipboard; "FMRTE's settings file was not found at <path>. Open FMRTE once, or set its location in Settings." for a missing file (Review Focus 2).
- **Club.** `ownClub` is `squad.book.ownClub(override: settings.clubName)`; `squadWarnings` are the engine's squad warnings as sentences.
- **Tactics.** The first tactic added becomes the primary. Deleting the primary makes the first remaining tactic primary, or none. Deleting a tactic clears `tacticID` on the fixtures that used it and adds a notice naming them (Review Focus 3). `problems(of:)` gives the engine's sentences. `addTactic` starts from the same shape and roles as `LineupEngine/Tests/LineupEngineTests/Fixtures/tactics/sample-4231.json`, written out in code (the app does not read the engine's test fixtures).
- **Fixtures.** Ids are new UUID strings. `update` and `add` keep the list in date order. Deleting a fixture removes its record from `history` (spec 8.6).
- **Settings.** `update` refuses nothing; out-of-range plan settings are reported by the planner (Task 7).
- `SampleData` is the only code that reads the engine's fixtures, and only from the path it is given.

- [ ] **Step 1: Write the failing tests** (`TestModel` builds a model on a temporary directory with a scripted environment; the captures are read from `../LineupEngine/Tests/LineupEngineTests/Fixtures/captures` relative to the test file)
  - `aFirstRunStartsEmptyOnTodaysDate`.
  - `importingTheFirstTeamFillsTheSquadAndSummarisesIt` (the real first-team capture and its grids file: player count, grid name, the import date).
  - `importingTheU21sLeavesTheFirstTeamAlone`; `aSecondImportReportsWhatChanged`.
  - Review Focus 2: `anEmptyClipboardChangesNothingAndSaysSo`; `textThatIsNotFMRTERowsChangesNothingAndSaysWhy`; `aMissingFMRTEFileChangesNothingAndSaysWhere`.
  - `theClubNameSettingOverridesTheSquads`.
  - `theFirstTacticIsPrimary`; `deletingThePrimaryPromotesTheNext`; `deletingATacticAFixtureUsesFallsBackToThePrimaryAndSaysSo`; `aTacticWithTenPlayersReportsTheEnginesSentence`; `duplicatingCopiesUnderANewName`.
  - `fixturesStayInDateOrder`; `deletingAFixtureRemovesItsRecord`.
  - `everyChangeIsSaved`: after each kind of action, a second model on the same directory holds the same state.
  - `aSaveThatFailsIsNoticed` (a directory made read-only).
  - `sampleDataLoadsBothSquadsATacticAndFiveFixtures`.
- [ ] **Step 2: Run** `swift test --filter AppModelTests` — expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `swift test` — PASS; no build warnings.
- [ ] **Step 5: Commit** — "Hold the app's squads, tactics, fixtures and settings in one model".

---

### Task 4: The Squad screen

**Files:**
- Create: `Sources/LineupAppUI/Squad/SquadScreen.swift`, `Sources/LineupAppUI/Squad/ImportPanel.swift`, `Sources/LineupAppUI/Squad/PlayerTable.swift`, `Sources/LineupAppUI/LiveEnvironment.swift`
- Modify: `Sources/LineupAppUI/RootView.swift`, `Sources/LineupAppUI/ScreenPictures.swift`, the app's entry point

**Interfaces:**
- Consumes: `AppModel` (Task 3), `Theme`, `EmptyState`.
- Produces: `SquadScreen(model:)`; `LiveEnvironment.make() -> AppEnvironment` (the real clock, `NSPasteboard.general` read as a string, the file at the given or default path); `RootView(model:)`; the app builds its model from the live store directory and environment, or from `SampleData` when started with `--sample-data <repository root>`; `ScreenPictures.write(model:to:size:)` draws from the model it is given.

What the screen shows:

- **Import.** Three buttons: "Import first team", "Import U21s", "Import U18s", each with the date that squad was last imported ("imported 13 Nov" or "not imported yet"), and one line of instruction: "In FMRTE, select the squad's rows and copy them, then press the button for that squad."
- **After an import.** A summary where the buttons are: the grid recognised, the number of players, the players out on loan, what changed since the last import (added, removed, moved in from another squad, changed), and each warning as the engine wrote it. A failed import shows its sentence in claret in the same place, and the table below is unchanged.
- **The club.** "Club: Oxford City", or the engine's warning that it is not known with a button that goes to Settings.
- **The players.** A table of every squad: name, squad, age, positions, current and potential ability, condition, sharpness, jadedness, and a status (injured, banned, out on loan to a club, out of contract). A picker filters by squad and a search field by name. Numbers are right-aligned in the DIN face. Columns sort.
- **Empty.** "No squad yet. Copy your first team in FMRTE, then import it here."
- **Notices** from the model appear at the top of every screen (in `RootView`), each with a way to dismiss it.

- [ ] **Step 1: Implement the screen and the live environment.**
- [ ] **Step 2: Run** `swift build 2>&1 | grep -c "warning:"` — expect 0; `swift test` — PASS.
- [ ] **Step 3: Draw it** — `swift run -q LineupApp --sample-data .. --pictures .build/pictures`, then look at `squad-light.png` and `squad-dark.png`: the table is filled, numbers line up, nothing is cut off or overlapping at 1200 by 800. Also draw an empty model and a model whose last import failed, as `squad-empty-light.png` and `squad-failed-light.png`. Put what you saw in the report.
- [ ] **Step 4: Commit** — "Add the Squad screen: import from FMRTE and see who is in the squad".

---

### Task 5: The Tactics screen

**Files:**
- Create: `Sources/LineupAppCore/TacticDraft.swift`, `Sources/LineupAppUI/Tactics/TacticsScreen.swift`, `Sources/LineupAppUI/Tactics/TacticEditor.swift`, `Sources/LineupAppUI/Tactics/PitchGrid.swift`
- Modify: `Sources/LineupAppUI/RootView.swift`, `Sources/LineupAppUI/ScreenPictures.swift`
- Test: `Tests/LineupAppCoreTests/TacticDraftTests.swift`

**Interfaces:**
- Consumes: `AppModel`, the engine's `Tactic`, `SlotID` (with `position`), `Phase`, `RoleCatalog.roles(phase:at:)`.
- Produces:
  ```swift
  // LineupAppCore: the edits a tactic allows, kept out of the views so they can be tested
  public struct TacticDraft: Equatable, Sendable {
      public var tactic: Tactic
      public init(_ tactic: Tactic)
      /// Adds or removes a slot in a phase. A new slot takes the first role the catalogue lists for it.
      /// In possession, a new slot maps to the same slot out of possession when that slot is active.
      public mutating func toggle(_ slot: SlotID, in phase: Phase, catalog: RoleCatalog)
      public mutating func setRole(_ name: String, at slot: SlotID, in phase: Phase)
      public mutating func map(_ slot: SlotID, to target: SlotID)
      /// The out-of-possession slots no in-possession slot maps to.
      public var unmappedTargets: [SlotID]
  }
  // LineupAppUI
  public struct PitchGrid<Token: View>: View     // the 24 slots laid out as a pitch, attack at the top
  ```
- `PitchGrid` is reused by Match Selection (Task 8): it places a view for each slot it is given in six rows (strikers, attacking midfield, midfield, defensive midfield with the wing-backs outside, defence, goalkeeper) and five columns, on the turf colour with chalk markings.

What the screen shows:

- **The list** of saved tactics, the primary marked, with "New tactic", "Duplicate", "Delete" and "Make primary".
- **The editor** for the chosen tactic: its name; two pitches side by side, "In possession" and "Out of possession". Clicking an empty slot adds it and clicking a filled one selects it; a selected slot shows its role in a menu of the roles the catalogue allows there, a "Remove" button and, in possession, a menu "Becomes, out of possession" listing the active out-of-possession slots. Each pitch shows how many of eleven slots are filled.
- **Problems.** The engine's sentences for the draft, live, under the pitches. "Save" is disabled while there are any; "Revert" discards the draft.
- **Empty.** "No tactics yet. Start from a 4-2-3-1 and change it to yours." with "New tactic".

- [ ] **Step 1: Write the failing tests** — `TacticDraftTests`: `addingASlotGivesItTheFirstAllowedRole`; `removingASlotRemovesItsMapping`; `removingAnOutOfPossessionSlotClearsMappingsToIt`; `aNewInPossessionSlotMapsToItsOwnSlotWhenActive`; `settingARoleAndAMapping`; `unmappedTargetsAreListed`; `theSampleTacticHasNoProblemsAndBreakingItGivesTheEnginesSentence`.
- [ ] **Step 2: Run** `swift test --filter TacticDraftTests` — expect FAIL.
- [ ] **Step 3: Implement the draft, then the screen.**
- [ ] **Step 4: Run** `swift build 2>&1 | grep -c "warning:"` — expect 0; `swift test` — PASS.
- [ ] **Step 5: Draw it** — with `--sample-data`: `tactics-light.png` and `tactics-dark.png` with the sample tactic open and a slot selected; an empty model as `tactics-empty-light.png`. Check both pitches are legible and the slots sit where a football person expects. Put what you saw in the report.
- [ ] **Step 6: Commit** — "Add the Tactics screen: build both shapes, roles and the mapping between them".

---

### Task 6: The Fixtures and Settings screens

**Files:**
- Create: `Sources/LineupAppUI/Fixtures/FixturesScreen.swift`, `Sources/LineupAppUI/Fixtures/FixtureEditor.swift`, `Sources/LineupAppUI/Settings/SettingsScreen.swift`, `Sources/LineupAppUI/ImportanceBadge.swift`, `Sources/LineupAppCore/DayText.swift`
- Modify: `Sources/LineupAppUI/RootView.swift`, `Sources/LineupAppUI/ScreenPictures.swift`
- Test: `Tests/LineupAppCoreTests/DayTextTests.swift`

**Interfaces:**
- Consumes: `AppModel`, `StoredFixture`, `AppSettings`, `PlanSettings`, `TrainingIntensity`, `Importance`.
- Produces:
  ```swift
  // LineupAppCore
  public enum DayText {
      public static func short(_ day: Day) -> String       // "Sat 14 Nov"
      public static func long(_ day: Day) -> String        // "Saturday 14 November 2026"
      public static func weekday(_ day: Day) -> Int        // 1 Monday ... 7 Sunday, by arithmetic
  }
  // LineupAppUI
  public struct ImportanceBadge: View { public init(_ importance: Importance) }   // claret, amber, grey, teal
  ```

What the screens show:

- **Fixtures.** The current date at the top: "Today in the game: Friday 13 November 2026", with buttons for the day before, the day after and a date picker. Below, the fixtures in date order: date, opponent, importance badge, tactic (or "Primary: <name>"), and a state: "to play", "confirmed", or, for an unconfirmed fixture before today, "past and not confirmed" in amber. "Add fixture" opens the editor: date, opponent, importance, tactic. Rows can be edited and deleted; deleting asks first when the fixture is confirmed.
- **Empty.** "No fixtures yet. Add the next few matches to get a plan."
- **Settings.** Training intensity (low, medium, high); lineup stability, a slider from "Pure optimisation" to "Maximum stability"; saving players for bigger fixtures, a slider from "Off" to 2 with the value shown; how many fixtures to plan (1 to 10); the condition floor (a percentage, with "Use the engine's 85%"); the club name ("Leave empty to use the club most players belong to"); where FMRTE's settings file is. Each control has one line saying what it changes. Changes apply at once.

- [ ] **Step 1: Write the failing tests** — `DayTextTests`: 2026-11-14 is "Sat 14 Nov" and "Saturday 14 November 2026"; the weekday of 2026-11-13 is 5; 2028-02-29 is a Tuesday.
- [ ] **Step 2: Run** `swift test --filter DayTextTests` — expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `swift build 2>&1 | grep -c "warning:"` — expect 0; `swift test` — PASS.
- [ ] **Step 5: Draw them** — `fixtures-*.png` and `settings-*.png` with the sample data, and `fixtures-empty-light.png`. Put what you saw in the report.
- [ ] **Step 6: Commit** — "Add the Fixtures and Settings screens".

---

### Task 7: Planning in the model

**Files:**
- Create: `Sources/LineupAppCore/AppModel+Plan.swift`, `Sources/LineupAppCore/PlanState.swift`
- Modify: `Sources/LineupAppCore/AppModel.swift`; in the engine, `LineupEngine/Sources/LineupEngine/Reporting/ErrorDescriptions.swift` and `LineupEngine/Sources/lineup-cli/Report.swift` (see below)
- Test: `Tests/LineupAppCoreTests/PlanStateTests.swift`, `LineupEngine/Tests/LineupEngineTests/ErrorDescriptionsTests.swift`

Engine change: the sentences for an `Exclusion` ("injured", "on loan at <club>", "condition 78% is below the 85% floor" and the rest) and for an `OverrideProblem` live in the command-line tool's `Report.swift` today. Move them to `ErrorDescriptions` as `public static func describe(_ exclusion: Exclusion, parameters: EngineParameters) -> String` and `describe(_ problem: OverrideProblem, parameters: EngineParameters) -> String`, with the same wording and a test for every case, and have the tool call them. The app uses them for candidates who cannot play and for ignored overrides.

**Interfaces:**
- Consumes: the engine's `Planner`, `PlanRequest`, `Plan`, `PlannedFixture`, `Fixture`, `ConfirmedLineup`, `EngineParameters.fm27`, `RatingProfile.standard()`, `SquadTiers`, `ErrorDescriptions.describe`.
- Produces:
  ```swift
  public struct FixturePlan: Identifiable, Equatable, Sendable {
      public var id: FixtureID { fixture.id }
      public let fixture: StoredFixture
      public let tacticName: String
      public let usesPrimaryBecauseItsTacticWasDeleted: Bool
      public enum Body: Equatable, Sendable {
          case planned(Lineup, fitness: [PlayerID: ProjectedFitness])
          case confirmed(ConfirmedRecord)
      }
      public let body: Body
      public let ignoredOverrides: [String]      // "D_L: <the engine's reason>"
  }
  public enum PlanState: Equatable, Sendable {
      case needsSquad, needsTactic, needsFixtures
      case failed([String])                      // the engine's sentences
      case ready([FixturePlan])                  // confirmed and planned fixtures together, in date order
  }
  public struct Candidate: Identifiable, Equatable, Sendable {
      public var id: PlayerID { player }
      public let player: PlayerID
      public let name: String
      public let squad: Squad
      public let rating: Double                  // full-fitness rating in the slot
      public let unavailable: String?            // the engine's wording, nil when he can play
  }
  // AppModel gains:
  //   public private(set) var planState: PlanState
  //   public func candidates(for slot: SlotID, in fixture: FixtureID) -> [Candidate]     // best first
  //   public func setOverride(_ player: PlayerID?, at slot: SlotID, in fixture: FixtureID)
  //   public func reject(_ player: PlayerID, in fixture: FixtureID)
  //   public func allow(_ player: PlayerID, in fixture: FixtureID)                        // undo a rejection
  //   public func confirm(_ fixture: FixtureID)
  //   public func unlock(_ fixture: FixtureID)
  ```

Rules:

- **When.** `planState` is worked out again after every change to the squad, tactics, fixtures, history or settings. It is worked out on the main actor, in the action that made the change; the planner takes well under a second on the real squad.
- **What is planned.** Fixtures with no record in `history`, dated on or after the plan's starting day, each with its own tactic or the primary. The starting day (`asOf`) is the latest date in `squad.importedOn`. The confirmed lineups handed to the planner are `history`'s. Settings are `settings.plan`; when `settings.conditionFloor` is set, the parameters' `conditionFloor` takes that value, labelled as the owner's setting.
- **Missing things** (Review Focus 4), in this order: no players → `needsSquad`; no usable tactic (none saved, or the primary has problems and a fixture needs it) → `needsTactic`; no fixtures at all → `needsFixtures`.
- **Failure.** Any error the planner throws becomes `.failed` with its sentence. An unconfirmed fixture dated before the starting day is the engine's "before the squad was imported" sentence (Review Focus 5); out-of-range settings are the engine's sentences.
- **Ready.** One `FixturePlan` per saved fixture within reach: every confirmed fixture, then the planned ones up to the horizon, all in date order. A fixture whose `tacticID` names no saved tactic uses the primary and says so (Review Focus 3). The lineup's `ignoredOverrides` become sentences with the engine's reason.
- **Candidates.** Every player not out on loan, with his full-fitness rating in the slot for that fixture's tactic, best first, and why he cannot play today if he cannot (the engine's exclusion wording).
- **Override and reject** change the saved fixture and replan. Setting an override for a slot replaces the one there; nil clears it.
- **Confirm** stores a `ConfirmedRecord` for the fixture from its planned lineup: the starters by slot, the players' names as they are now, and the tactic's name. A fixture that is not `.planned` cannot be confirmed (nothing happens). **Unlock** removes the record.
- A confirmed fixture shows its record as saved, whatever has happened to the squad since (Review Focus 3).

- [ ] **Step 1: Write the failing tests** (with `SampleData` and `TestModel`)
  - Review Focus 4: `noSquadNeedsASquad`; `noTacticNeedsATactic`; `noFixturesNeedsFixtures`.
  - `theSampleDataPlansFiveFixtures`: five planned lineups in date order, eleven picks each.
  - `anOverridePutsThePlayerInTheSlotAndIsSaved`; `clearingAnOverrideRestoresThePick`; `aRejectedPlayerDoesNotStartThatFixtureOnly`; `allowingHimAgainRestoresThePick`.
  - `anOverrideNamingAPlayerWhoHasLeftIsReportedAsIgnored` (Review Focus 3).
  - `confirmingLocksTheLineupAndTakesItOutOfReplanning`: the record has eleven starters and their names; changing a setting afterwards leaves it as it was; the later fixtures now count it in their history (a player's run of starts grows).
  - `unlockingPlansItAgain`.
  - `aConfirmedLineupKeepsItsNamesAfterThePlayersLeave` (import a squad without them).
  - `aFixtureWhoseTacticWasDeletedUsesThePrimaryAndSaysSo`.
  - Review Focus 5: `movingTheDatePastAnUnconfirmedFixtureStopsThePlanWithTheEnginesSentence` (import after moving the date).
  - `aSettingOutOfRangeStopsThePlanWithTheEnginesSentence`; `theConditionFloorSettingChangesWhoIsLeftOut`.
  - `candidatesAreBestFirstAndSayWhoCannotPlay`.
  - `thePlanFollowsEveryChange`: after an import, a tactic edit, a fixture edit and a settings change, `planState` differs from before.
- [ ] **Step 2: Run** `swift test --filter PlanStateTests` — expect FAIL.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `swift test` — PASS; no build warnings.
- [ ] **Step 5: Commit** — "Plan the fixtures in the app model, with override, reject, confirm and unlock".

---

### Task 8: The Match Selection screen

**Files:**
- Create: `Sources/LineupAppUI/Match/MatchSelectionScreen.swift`, `Sources/LineupAppUI/Match/FixtureStrip.swift`, `Sources/LineupAppUI/Match/TeamSheet.swift`, `Sources/LineupAppUI/Match/PlayerToken.swift`, `Sources/LineupAppUI/Match/PickDetail.swift`, `Sources/LineupAppUI/Match/LeftOutList.swift`, `Sources/LineupAppUI/Match/StartsGrid.swift`, `Sources/LineupAppUI/Match/CandidatePicker.swift`
- Modify: `Sources/LineupAppUI/RootView.swift`, `Sources/LineupAppUI/ScreenPictures.swift`

**Interfaces:**
- Consumes: `AppModel.planState` and the plan actions (Task 7), `PitchGrid` (Task 5), `ImportanceBadge`, `DayText`, `Theme`.
- Produces: `MatchSelectionScreen(model:)`.

What the screen shows, following the visual direction's layout:

- **The fixture strip** across the top: one cell per fixture in the plan: the date in the DIN face, "v <opponent>", the importance badge, and a lock when confirmed. The chosen fixture is marked in hoop blue. The first fixture not yet confirmed is chosen to begin with.
- **The pitch** for the chosen fixture: a token in each slot with the player's surname, his match-day value in the DIN face, and marks for an override (a pin), a caution (amber: out of position, or a rule overridden) and a youth-squad player (U21 or U18). An unfilled slot is an empty outline. Clicking a token selects it.
- **The detail** beside the pitch for the selected pick: name, squad, slot and roles in both phases; rating, the three fitness factors and the value; then every reason, one per line, as the engine wrote it; then the actions: "Choose someone else…" (the candidate picker: best first, with those who cannot play greyed and why), "Clear override" when there is one, and "Leave him out of this match".
- **Left out**, under the detail: each omission with its reason; then "Left out by you" with the rejected players and "Allow" beside each; then any ignored overrides with their reasons.
- **Confirm.** "Confirm this lineup" for a planned fixture, with one line: "Locks this eleven as played. Later fixtures count it." A confirmed fixture shows its saved eleven on the pitch, without values or reasons, and "Unlock".
- **Starts.** A second view of the same plan, switched by a control above the pitch: a grid with a row per player who starts at least once and a column per fixture, showing his slot or a dash.
- **Not ready.** For `needsSquad`, `needsTactic` and `needsFixtures`, an `EmptyState` saying which is missing with a button that goes to that screen. For `failed`, the engine's sentences in claret and a button to Fixtures or Settings as fits.

- [ ] **Step 1: Implement.**
- [ ] **Step 2: Run** `swift build 2>&1 | grep -c "warning:"` — expect 0; `swift test` — PASS.
- [ ] **Step 3: Draw it** — with `--sample-data`: `match-light.png` and `match-dark.png` (the first fixture, a pick selected), `match-starts-light.png`, `match-confirmed-light.png` (after confirming the first fixture), `match-empty-light.png` and `match-failed-light.png`. Check: eleven tokens sit in a 4-2-3-1; names are not cut off; the reasons are readable in full; the strip shows five fixtures. Put what you saw in the report, with anything a football manager would find wrong.
- [ ] **Step 4: Commit** — "Add Match Selection: the planned elevens on a pitch, with every reason".

---

### Task 9: The app, built and checked on the real squad

**Files:**
- Modify: `CLAUDE.md`, `tools/build_app.sh` if needed
- Test: `Tests/LineupAppCoreTests/EndToEndTests.swift`

- [ ] **Step 1: Write the failing test** — `theWholeFlowOnTheRealCaptures`: a model on an empty directory; import the first team and the U21s through a scripted clipboard; add a tactic; add the five sample fixtures; the plan is ready with five lineups; override one slot, reject one player, confirm the first fixture; a second model on the same directory holds the same squad, tactic, fixtures, record and plan.
- [ ] **Step 2: Run** `swift test --filter EndToEndTests` — expect FAIL, then make it pass (it should need no new code; anything it finds is a fault to fix and report).
- [ ] **Step 3: Build and draw** — `tools/build_app.sh`; run the built app's executable with `--sample-data <repository root> --pictures <directory>`; list the pictures written. Start the built app with `--sample-data` and no `--pictures` for ten seconds, confirm the process is still running, then end it.
- [ ] **Step 4: `CLAUDE.md`** — add a short section "New code: `LineupApp/`": what the three targets are, how to build and test (`cd LineupApp && swift build && swift test`), how to run (`swift run LineupApp`, or `tools/build_app.sh` for the app), how to draw the screens (`--sample-data .. --pictures <directory>`), where the app keeps its state, and the two rules: the engine decides and the app shows; everything visual comes from `Theme`. Move the app from "not built yet" to what is built, saying the advisor screens are still to come. Name this plan and the visual direction.
- [ ] **Step 5: Commit** — "Check the whole app flow on the real squad and document the app".

---

### Task 10: A match played since the last import counts in fitness

Added after Task 7's review, and built before Task 8. Confirming a fixture takes it out of the fixtures the planner plans. The planner starts everyone's fitness from the last import and moves it forward only through the fixtures it plans, so once a match is confirmed its starters look fresh again in every later fixture, until the squad is imported after the match. The owner will often confirm a match and look at the next one before importing again.

**Files:**
- Modify (engine): `LineupEngine/Sources/LineupEngine/Planner/Planner.swift`, `LineupEngine/Sources/lineup-cli/Report.swift`
- Modify (app): `Sources/LineupAppCore/StoredTypes.swift`, `Sources/LineupAppCore/AppModel+Plan.swift`, `Sources/LineupAppCore/AppModel+Squad.swift`
- Test: `LineupEngine/Tests/LineupEngineTests/PlannerTests.swift`, `Tests/LineupAppCoreTests/PlanStateTests.swift`, `Tests/LineupAppCoreTests/StoreTests.swift`

**Interfaces:**
- Engine:
  ```swift
  // PlanRequest gains, defaulted to [] so every existing call compiles unchanged:
  //   public var played: [ConfirmedLineup]     // matches played since the squad was imported, which the
  //                                            // imported fitness does not include
  // PlannedFixture gains:
  //   public let fitnessIsProjected: Bool      // what the selector was told for this fixture
  ```
- App:
  ```swift
  // ConfirmedRecord gains:
  //   public var awaitingImport: Set<Squad>    // squads not imported since this lineup was confirmed
  // AppModel gains:
  //   public var fitnessNote: String?          // nil when no confirmed match awaits an import
  ```

Rules:

- **Engine.** Each lineup in `played` is a match in the projection: its starters take `FitnessProjection.afterMatch` at their slot's position (`SlotID.position`), and everyone takes `afterDays` between events, in date order with the planned fixtures. A played match on the same day as a planned fixture comes first. One dated before `asOf` is applied on `asOf`: the projection cannot go back. A starter who is not among `players` is ignored. `played` does not change the start history; that is still `confirmed`. `fitnessIsProjected` is true for a fixture when a day has passed since `asOf` or any match, played or planned, comes before it; the planner hands the same value to the selector, and the tool and the app read it instead of working it out again.
- **App.** Confirming sets the record's `awaitingImport` to every squad that has been imported. Importing a squad removes it from every record's `awaitingImport` and saves the history. The planner's `played` is, for each record still awaiting an import, its lineup with the starters cut down to players who are in the squad now and whose squad is still awaited. A history file saved before this field existed loads with nothing awaited.
- **The note.** `fitnessNote`, when any record awaits an import: "The match against Opponent A was confirmed after the squad was last imported. Its starters are counted as having played 90 minutes; import the squad again for their real fitness." With several, the opponents are listed.

- [ ] **Step 1: Write the failing tests**
  - Engine `PlannerTests`: `aMatchPlayedSinceTheImportLeavesItsStartersLessFresh` (a starter's fitness at the first fixture equals `FitnessProjection` applied by hand, within 1e-9; a player who did not start is as without it); `aPlayedMatchBeforeTheImportDayIsAppliedOnThatDay`; `aPlayedMatchOnAFixturesDayComesFirst`; `aPlayedStarterWhoHasLeftIsIgnored`; `playedMatchesDoNotChangeRunsOfStarts`; `aFixtureAfterAPlayedMatchHasProjectedFitnessEvenOnTheImportDay`; `inputOrderOfPlayedMatchesDoesNotMatter`; `withNothingPlayedThePlanIsAsBefore`.
  - App `PlanStateTests`: `confirmingAMatchKeepsItsLoadInLaterFixtures` (a starter of the first fixture has the same projected condition at the second fixture after confirming as before); `importingASquadAgainStopsCountingTheMatchForThatSquadOnly`; `unlockingRemovesTheLoadWithTheRecord`; `theNoteNamesTheMatchesAwaitingAnImport` and nil when none; `awaitingImportSurvivesAReload`.
  - App `StoreTests`: `aHistoryFileWithoutTheNewFieldLoadsWithNothingAwaited`.
- [ ] **Step 2: Run** the engine's `swift test --filter PlannerTests` and the app's `swift test --filter "PlanStateTests|StoreTests"` — expect FAIL.
- [ ] **Step 3: Implement**, engine first.
- [ ] **Step 4: Run** both packages' full `swift test` — PASS; no build warnings in either.
- [ ] **Step 5: Commit** — the engine change as "Count matches played since the import in projected fitness", then the app change as "Keep a confirmed match's load in later fixtures until the squad is imported again".

---

### Task 11: The Tactics board look

Added after the owner opened the app, found it bland and its numbers squashed, and chose the Tactics board from three mock-up directions. It runs after the final review's fixes.

**Files:**
- Create: `Sources/LineupAppUI/Resources/Fonts/` (the two typefaces and their licences), `Sources/LineupAppUI/Board/` (the shared pieces: the board frame and top navigation, magnets, sticky notes, the marker underline, meters, pills, button styles), `Sources/LineupAppCore/BoardPresentation.swift`
- Modify: `Package.swift` (the UI target's resources), `Sources/LineupAppUI/Theme.swift`, `Sources/LineupAppUI/RootView.swift`, every screen under `Sources/LineupAppUI/`, `Sources/LineupAppUI/ScreenPictures.swift`, the entry point, `tools/build_app.sh` if the fonts need it, `CLAUDE.md` (one paragraph)
- Test: `Tests/LineupAppCoreTests/BoardPresentationTests.swift`

**The direction** is `docs/superpowers/specs/2026-11-13-fm27-app-visual-direction.md`: read all of it. Every value in it goes into `Theme`; no view holds a literal colour, font name or measure.

What changes:

- **Fonts.** Bricolage Grotesque and Figtree (SIL Open Font License) are shipped as resources of the UI target with their licence files and registered when the app starts, for the real app, for sample-data runs and for picture runs alike. If a face cannot be registered the app says so once in a notice and falls back to the system typeface. DIN is gone.
- **The frame.** The window is the wall; the board sits on it; the sidebar goes. Navigation is the row of pills at the top of the board beside the club's name (the club's name from the model, "Lineup Optimizer" when it is not known), and the date in the game is a yellow note at the top right on every screen, with "Day before" and "Day after". Notices are pink notes under the top row.
- **Squad.** The three imports as outlined cards with a magnet each; the import's summary as a pink note; the table as in the direction: a magnet and the position, ability as "58 of a possible 100", five-block meters for condition and sharpness, status as a stamp.
- **Tactics.** Both pitches drawn in marker on the board; filled slots are magnets coloured by line with the slot's short name inside and the role beneath; empty slots are dashed circles.
- **Fixtures.** Each fixture is a row with a small sticky note for its importance; the editor is a card on the board.
- **Match Selection.** Fixtures as sticky notes across the top; the pitch with magnets, initials, surname and value; the detail written on the board: the name, the value in a hand-drawn blue ring, the four figures as outlined cards, each reason with a green plus or a red minus, "Left out" under a three-point rule. A confirmed or missed fixture's eleven uses the same magnets without values.
- **Settings.** The same controls, on the board, in the direction's type and buttons.
- **Core** (with tests, in `BoardPresentation.swift`): a player's initials (two letters: first name and surname, the surname as `surname` already finds it, one-word names give one letter); the line a position or slot belongs to (goalkeeper, defence, midfield, attack) from the engine's `Position`; which of a meter's five blocks are lit and at which of three levels (85 and over, 70 and over, below), with the thresholds as named values; whether a reason raised or lowered a value (from the adjustment's factor and cost, and for the fitness lines from the factor), so a view never parses a sentence; each note's tilt, fixed by its position in its row so pictures are repeatable.

Rules:

- The look is the same in light and dark system appearance.
- Text on a note or a magnet meets 4.5 to 1 against it; the direction's pairs do.
- The window still works at 760 by 560: pills wrap, the detail goes under the pitch.
- Nothing animates on its own.
- The picture code's workarounds for the sidebar (matching private AppKit class names) go if nothing needs them any more.

- [ ] **Step 1: Write the failing tests** — `BoardPresentationTests`: initials for "Evan Humphries" (EH), "Dillon De Silva" (DS), "Kauan Bitencourt de Oliveira" (KO), a one-word name; the line of each of the 14 positions; meter blocks for 100, 85, 84, 70, 69, 54, 9 and 0; a reason's direction for a factor above 1, below 1, exactly 1, a cost, and a fitness line; tilts repeat for the same position and differ between neighbours.
- [ ] **Step 2: Run** `swift test --filter BoardPresentationTests` — expect FAIL.
- [ ] **Step 3: Implement** Core, then the fonts and `Theme`, then the frame, then each screen.
- [ ] **Step 4: Run** `swift build 2>&1 | grep -c "warning:"` — 0; `swift test` — PASS.
- [ ] **Step 5: Draw every screen** with the sample data into `.build/pictures-board/` and look at each one: Bricolage Grotesque and Figtree are really in use (not a fallback), nothing is cut off or overlapping at 1200 by 800 or at 800 by 700, every colour pair is readable. Build the app with `tools/build_app.sh` and draw once from the built app to prove the fonts ship inside it. Put what you saw in the report.
- [ ] **Step 6: Commit** — "Give the app the Tactics board look".

---

## After this plan

The advisor screens follow the advisors plan: First XI, Second XI and Depth, Training with accept and reject, Rest, Player Removal, and the importance suggestion on Fixtures. The owner's reaction to the look changes `Theme` and the visual direction document.

Known limits of this plan, for the owner:

- The screens are checked from drawn pictures and by building, not by anyone using them. Expect rough edges in the first hour of real use; they are the next thing to fix.
- The app is not signed for distribution. It runs on this Mac from `tools/build_app.sh` or Xcode (open `LineupApp/Package.swift`).
- There is no undo. Deleting a tactic or a fixture is final; confirming can be unlocked.
- The plan is worked out again after every change. If that ever feels slow it moves off the main thread.

## Changes made while building

Decisions taken during the build that differ from, or add to, the tasks above. Each can be undone; the cost of being wrong is in brackets.

- The screens were built before any mock-ups, to a written direction. The owner found the result bland and the numbers cramped, was shown three directions, and chose the Tactics board; Task 11 restyled every screen. (Paid: one restyle.)
- The app is a second SwiftPM package with a script that assembles the `.app`; there is no Xcode project file. (An Xcode project can be added around the same sources.)
- The plan starts from the latest squad import date, not the current date. (One line in the model.)
- Sentences the engine lacked were added to the engine, not written in the app: squad warnings, why a player cannot play, a pick's warnings. The command-line tool's wording changed with them.
- The saved tactics are a menu above the editor, not a list beside it, so both pitches get the full width.
- Unsaved changes to a tactic are kept, and saved to their own file, until saved or reverted. (One more file.)
- A confirmed fixture's record follows a change of its date; its starters and tactic name stay as confirmed.
- An unconfirmed fixture dated before the last import is "missed": it is left out of the plan, which carries on. It keeps the eleven last planned for it, which can be corrected and confirmed as played. (A remembered eleven can be out of date if the plan was never looked at.)
- The app refuses two matches on one day itself, naming the opponents.
- Only the earliest planned fixture can be confirmed. Confirming moves the current date up to that fixture's date and shows the next fixture; unlocking stays where it is.
- A match confirmed since a squad's last import keeps its load on its starters until that squad is imported again (Task 10, with an engine change). A match dated before the plan's first day is applied on its own date and its starters then recover up to the first day.
- An import names the matches it leaves unconfirmed. The date control is on the Squad screen as well as Fixtures.
- Candidates who can play are listed first; surnames keep their particle ("De Silva"); slots are football words in sentences ("left back").
- The board look is the same in light and dark system appearance. (A dark variant would be added in `Theme`.)
- The squad and fixtures tables are hand-built rows, to take the look, so they do not have the system table's row-by-row keyboard movement. Menus, the date picker, sliders, steppers, the checkbox and alerts are still the system's.

## Known limits and small faults left

- Importing on a match day after the match, but before confirming it, replans that match on post-match fitness and replaces the remembered eleven. Confirm a match before importing after it; otherwise set the slots to who started before confirming.
- A match confirmed after an import made on the match day after the match is counted twice until the next import.
- Unlocking does not lower a current date that confirming raised.
- A fixture beyond the planning horizon that goes unconfirmed has no remembered eleven.
- A clash of two matches on one day beyond the horizon stops the plan; an opponent-only edit of a fixture that already shares a day cannot be saved until a date changes.
- The saving-players estimate does not see matches played between fixtures.
- The left-out list needs a scroll at the default window size. Some long surnames print smaller than their neighbours on a confirmed pitch, and an empty slot sits slightly high on a pitch that shows no values.
- A "could not be saved" notice is not cleared by a later save that works.
- Not checked in pictures, so to be looked at in the running app: the sliders' tint, menus in dark appearance, dragging the window by the board's frame, focus rings, the choices popover.

