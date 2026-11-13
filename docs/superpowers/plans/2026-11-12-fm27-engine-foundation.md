# FM27 Engine Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A tested Swift package that turns an FMRTE 27 clipboard paste and a tactic into the best available starting eleven for one fixture, with every pick explained, runnable from a command-line tool.

**Architecture:** A Swift package, `LineupEngine`, holding pure value types and functions: importer, domain model, role catalog, rating core, fitness and risk rules, an exact assignment solver and a single-fixture selector. It takes plain values in and returns plain values out, with no UI and no file access of its own. A small executable, `lineup-cli`, reads files and prints a lineup so the engine can be exercised on real data before the app exists.

**Tech Stack:** Swift 6, Swift Package Manager, Swift Testing (`import Testing`), Foundation only. Python 3 standard library for two one-off reference export scripts.

**Spec:** `docs/superpowers/specs/2026-11-12-fm27-native-app-design.md`. This plan implements steps 1 to 3 of its section 14. Read sections 4, 5, 8.2 to 8.5, 8.8, 11 and 13 before starting. The planner, advisors, app and clean-up are later plans (see the end of this document).

## Global Constraints

- macOS 26 on Apple Silicon, Xcode 27, Swift 6 language mode.
- No third-party run-time dependencies. Foundation is allowed in the engine; AppKit, SwiftUI and file or network access are not.
- FM27 only. The FM26 configuration of the rating core exists solely for the reference comparison in Task 10.
- Every tunable number lives in `EngineParameters` with an evidence label and a source. No numeric literal for a rule appears anywhere else in `Sources/LineupEngine`.
- No silent defaults. A missing column, an unknown role, a blank or out-of-range value is an error that names the player and the column.
- Every rule gets a test in which it changes an outcome and a test in which it does not.
- The repository is public. Nothing under `~/Library/Application Support` is copied into it except the grid-layout snapshots described in Task 2.
- All work is committed to branch `fm27-native`. Do not push.
- Run tests from the package directory: `cd LineupEngine && swift test`.

## Review Focus

Inputs the spec implies but does not spell out, most likely first. Each has a test in the task named.

1. **The clipboard holds something other than an FMRTE paste** (empty, a URL, a paragraph of text). The import must fail with a message saying it does not look like an FMRTE player grid. Task 4.
2. **Fewer than eleven players can be fielded, or nobody can play a slot** (both goalkeepers injured). The selector must return the best eleven it can, flag any pick below familiarity 10 as out of position, and list unfilled slots, never crash or return fewer picks without saying so. Task 13.
3. **Two players share a name** (common with generated youth players). Both must survive the import as separate players, with a warning. Task 6.
4. **FMRTE's configuration file is missing, unreadable or has a new shape** after an FMRTE update. The error must name the path and what was expected. Task 4.
5. **A fitness or attribute cell is blank or not a number.** The import must stop and name the player and column, not substitute a default. Task 6.

---

## File Structure

```
LineupEngine/
  Package.swift
  Sources/LineupEngine/
    Parameters/Evidence.swift            Evidence, Parameter<Value>
    Parameters/EngineParameters.swift    every tunable number, with EngineParameters.fm27
    Model/Attribute.swift                Attribute (62 cases), FMRTE path lookup
    Model/Position.swift                 Position (14), SlotID (24), Phase
    Model/Player.swift                   PlayerID, Squad, ContractType, LoanStatus, Player
    Import/FMRTEConfig.swift             GridLayout, FMRTEConfig.playerGrids
    Import/ClipboardText.swift           ClipboardText.rows
    Import/GridDetector.swift            type-fit rules, GridDetector.detect
    Import/Importer.swift                ImportResult, ImportWarning, ImportError, Importer.importPlayers
    Import/SquadBook.swift               per-squad snapshots, changes, own club, loan status
    Roles/RoleCatalog.swift              Role, RoleCatalog, FM27 and FM26 loaders
    Roles/Tactic.swift                   Tactic, SlotAssignment, TacticProblem
    Rating/RatingTables.swift            position weights, consensus bonuses, thresholds
    Rating/RatingEngine.swift            RatingConfiguration, PhaseRating, SlotRating, RatingEngine
    Selection/FitnessModel.swift         FitnessFactors, curve and step evaluation
    Selection/RiskRules.swift            Importance, Exclusion, RiskRules.exclusion
    Selection/AssignmentSolver.swift     AssignmentSolver.maximise
    Selection/LineupSelector.swift       SelectionRequest, Pick, Omission, Lineup, LineupSelector
    Resources/fm27_roles.json            copy of docs/Research/fm27_roles.json
    Resources/rating_tables.json         generated in Task 8
  Sources/lineup-cli/main.swift          argument parsing, file reading, printing
  Tests/LineupEngineTests/
    Support/PlayerFixture.swift          Player.fixture(...) builder for tests
    Support/Fixtures.swift               loads files from Fixtures/
    Fixtures/captures/                   real pastes and grid snapshots
    Fixtures/reference/                  FM26 roles file and rating reference outputs
    Fixtures/tactics/                    sample tactics
    <one test file per source file>
tools/
  capture_fmrte_paste.sh                 saves the clipboard and FMRTE's player-grid layouts
  export_rating_reference.py             writes rating_tables.json and the FM26 reference outputs
```

---

### Task 1: Repository preparation and package scaffold

**Files:**
- Create: `LineupEngine/Package.swift`, `LineupEngine/Sources/LineupEngine/Parameters/Evidence.swift`, `LineupEngine/Tests/LineupEngineTests/EvidenceTests.swift`
- Modify: `CLAUDE.md` (replace), `.gitignore` (append `LineupEngine/.build/`)
- Move: everything in `docs/superpowers/plans/assets/2026-11-12-captures/` to `LineupEngine/Tests/LineupEngineTests/Fixtures/captures/`. There are two real captures of the same six U21 players: `u21.tsv` with `u21.grids.json` (copied from FMRTE's search grid; the snapshot holds only the two player grids) and `u21-team-grid.tsv` with `u21-team-grid.grids.json` (copied from the team grid an hour later; the snapshot holds all ten grids that have a name column, staff grids included).

**Interfaces:**
- Produces: `Evidence`, `Parameter<Value>`; the package layout every later task builds in.

- [ ] **Step 1: Bring `main` up to the reference branch and start the work branch**

The working tree has an uncommitted rewrite of `CLAUDE.md` that described the old `main`. It is superseded; keep it recoverable in the stash.

```bash
git stash push -m "CLAUDE.md rewrite for old main (superseded)" -- CLAUDE.md
git merge --ff-only origin/customizable-tactics
git switch -c fm27-native
```

Expected: the merge reports "Fast-forward". If it refuses, stop and report; do not merge any other way.

- [ ] **Step 2: Replace `CLAUDE.md` with an interim guide**

It must say, in under 60 lines: the project is being rebuilt as a native Mac app for FM27; the spec and plan paths; that `LineupEngine/` is the new code and how to test it; that everything in Python, `ui/` and the `.bat` files is reference only, must not be modified, and is removed at the end; the list in spec section 7 of what the Python runs and what it wrote but never connected; and that player data and app state never go in the repository except test fixtures.

- [ ] **Step 3: Create the package**

`Package.swift`: `swift-tools-version: 6.0`; `platforms: [.macOS("26.0")]`; library target `LineupEngine` with `resources: [.process("Resources")]`; executable target `lineup-cli` depending on it; test target `LineupEngineTests` with `resources: [.copy("Fixtures")]`. Add a placeholder `main.swift` that prints usage.

- [ ] **Step 4: Write the failing test**

```swift
import Testing
@testable import LineupEngine

@Test func parameterCarriesItsEvidence() {
    let p = Parameter(0.85, .carriedOverFM26, source: "docs/Research/physical-condition.md")
    #expect(p.value == 0.85)
    #expect(p.evidence == .carriedOverFM26)
    #expect(!p.source.isEmpty)
}

@Test func evidenceHasFiveLevels() {
    #expect(Evidence.allCases.map(\.rawValue) ==
        ["fm27Measured", "fm27Official", "fm27Observation", "carriedOverFM26", "derived"])
}
```

- [ ] **Step 5: Run it and see it fail**

Run: `cd LineupEngine && swift test --filter EvidenceTests`
Expected: FAIL, `Parameter` and `Evidence` not found.

- [ ] **Step 6: Implement**

```swift
public enum Evidence: String, Sendable, CaseIterable, Codable {
    case fm27Measured, fm27Official, fm27Observation, carriedOverFM26, derived
}
public struct Parameter<Value: Sendable>: Sendable {
    public let value: Value
    public let evidence: Evidence
    public let source: String
    public init(_ value: Value, _ evidence: Evidence, source: String)
}
```

- [ ] **Step 7: Move the saved capture into the test fixtures, run tests, commit**

```bash
mkdir -p LineupEngine/Tests/LineupEngineTests/Fixtures/captures
mv docs/superpowers/plans/assets/2026-11-12-captures/* LineupEngine/Tests/LineupEngineTests/Fixtures/captures/
rmdir docs/superpowers/plans/assets/2026-11-12-captures docs/superpowers/plans/assets
(cd LineupEngine && swift test)
git add -A && git commit -m "Start FM27 native engine: package scaffold, evidence types, interim CLAUDE.md"
```

Expected: tests PASS. The commit includes the FM27 research docs, the spec and this plan, which were untracked.

---

### Task 2: Capture tool and first-team capture (needs the owner)

Tasks 3 to 13 do not depend on this task. Task 14 does.

**Files:**
- Create: `tools/capture_fmrte_paste.sh`
- Create (owner action): `LineupEngine/Tests/LineupEngineTests/Fixtures/captures/first-team.tsv`, `first-team.grids.json`

- [ ] **Step 1: Write `tools/capture_fmrte_paste.sh <name>`**

It writes the clipboard (`pbpaste`) to `Fixtures/captures/<name>.tsv` unchanged, and writes `<name>.grids.json` containing only `{"ColumnsSettings": {"Items": [...]}}` filtered to items whose `Columns` include a `Path` of `DisplayedName`, read from `~/Library/Application Support/FMRTE27/config.json`. It refuses to run if the clipboard has no tab character, and prints the row count and the field count of the first row.

- [ ] **Step 2: Check the layout filter against the live configuration**

Give the script a `--list-grids` mode that prints the `SettingsKey` and column count of each player grid it would save, without touching the clipboard or writing files.

Run: `tools/capture_fmrte_paste.sh --list-grids`
Expected: the list includes `SearchPlayersColumns` and `TeamPlayersColumns`.

- [ ] **Step 3: Owner action**

Ask the owner to open FMRTE 27 with the save loaded, select every first-team row in the team grid (the grid they normally copy from), press Cmd+C, and say so. Then run `tools/capture_fmrte_paste.sh first-team`. Expected output: 18 or more rows, 98 fields. The owner pasted these rows into the chat once already, but a chat paste turns tabs into spaces, and the fixture must be the exact clipboard bytes.

- [ ] **Step 4: Commit**

```bash
git add tools/capture_fmrte_paste.sh LineupEngine/Tests/LineupEngineTests/Fixtures/captures
git commit -m "Add FMRTE capture tool and first-team capture"
```

---

### Task 3: Attributes, positions and slots

**Files:**
- Create: `Model/Attribute.swift`, `Model/Position.swift`
- Test: `AttributeTests.swift`, `PositionTests.swift`

**Interfaces:**
- Produces:
  - `enum Attribute: String, CaseIterable, Codable, Sendable`, raw value the canonical name; `static func fromFMRTEPath(_ path: String) -> Attribute?`; `init?(catalogName: String)`
  - `enum Position: String, CaseIterable, Codable, Sendable`, raw values exactly `"GK", "D (L)", "D (C)", "D (R)", "WB (L)", "WB (R)", "DM", "M (L)", "M (C)", "M (R)", "AM (L)", "AM (C)", "AM (R)", "ST (C)"`; `var tableKey: String`; `static func fromFMRTEPath(_:) -> Position?`; `var isDefensive: Bool`
  - `enum Phase: String, Codable, Sendable { case inPossession = "ip", outOfPossession = "oop" }`
  - `enum SlotID: String, CaseIterable, Codable, Sendable`; `var position: Position`

Decisions:
- The 62 `Attribute` cases are the 62 attribute columns in the capture. The canonical name is the last component of the FMRTE path split into words at capital letters, with these exceptions: `AerialAbility` → `Aerial Reach`, `RushingOut` → `Rushing Out (Tendency)`, `TendencyToPunch` → `Punching (Tendency)`, `Jumping` → `Jumping Reach`, `Workrate` → `Work Rate`, `Freekicks` → `Free Kick Taking`, `Longthrows` → `Long Throws`, `InjuryProness` → `Injury Proneness`, `Professional` → `Professionalism`.
- An attribute path is one whose first component ends in `Attributes`.
- `Position.tableKey` is the raw value with spaces removed, except `ST (C)` → `ST`. `isDefensive` is true for `GK`, the three `D`, the two `WB` and `DM`.
- FMRTE position paths: `Positions.Goalkeeper`, `DefenderLeft`, `DefenderCentral`, `DefenderRight`, `WingBackLeft`, `WingBackRight`, `DefensiveMidfielder`, `MidfielderLeft`, `MidfielderCentral`, `MidfielderRight`, `AttackingMidLeft`, `AttackingMidCentral`, `AttackingMidRight`, `Striker`.
- `SlotID` cases, in this order (the order is the tie-break order in Task 12): `GK, D_L, D_CL, D_C, D_CR, D_R, WB_L, DM_L, DM_C, DM_R, WB_R, M_L, M_CL, M_C, M_CR, M_R, AM_L, AM_CL, AM_C, AM_CR, AM_R, ST_L, ST_C, ST_R`. `position`: `_L` and `_R` suffixes map to the left and right position of the line; `_CL`, `_C`, `_CR` map to the central one; all `DM_*` map to `DM`; all `ST_*` map to `ST (C)`.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func everyAttributeColumnInTheCaptureMapsToAnAttribute() throws {
    let paths = try Fixtures.gridColumns("u21", grid: "SearchPlayersColumns")
        .filter { $0.split(separator: ".").first?.hasSuffix("Attributes") == true }
    #expect(paths.count == 62)
    #expect(Set(paths.compactMap(Attribute.fromFMRTEPath)).count == 62)
    #expect(Attribute.allCases.count == 62)
}
@Test func renamedAttributesUseCanonicalNames() {
    #expect(Attribute.fromFMRTEPath("GoalKeeperAttributes.AerialAbility")?.rawValue == "Aerial Reach")
    #expect(Attribute.fromFMRTEPath("MentalAttributes.Workrate")?.rawValue == "Work Rate")
    #expect(Attribute.fromFMRTEPath("PhysicalAttributes.Jumping")?.rawValue == "Jumping Reach")
    #expect(Attribute.fromFMRTEPath("HiddenAttributes.InjuryProness")?.rawValue == "Injury Proneness")
    #expect(Attribute.fromFMRTEPath("Contract.Club") == nil)
}
@Test func fourteenPositionsWithTableKeys() {
    #expect(Position.allCases.count == 14)
    #expect(Position(rawValue: "AM (L)")?.tableKey == "AM(L)")
    #expect(Position(rawValue: "ST (C)")?.tableKey == "ST")
    #expect(Position.fromFMRTEPath("Positions.DefenderCentral") == .init(rawValue: "D (C)"))
    #expect(Position.fromFMRTEPath("Positions.PositionsDesc") == nil)
    #expect(Position.allCases.filter(\.isDefensive).count == 7)
}
@Test func twentyFourSlotsMapToPositions() {
    #expect(SlotID.allCases.count == 24)
    #expect(SlotID.allCases.first == .GK)
    #expect(SlotID.D_CL.position.rawValue == "D (C)")
    #expect(SlotID.DM_L.position.rawValue == "DM")
    #expect(SlotID.M_R.position.rawValue == "M (R)")
    #expect(SlotID.ST_L.position.rawValue == "ST (C)")
}
```

Add `Support/Fixtures.swift` with `Fixtures.text(_ name: String) throws -> String`, `Fixtures.data(_:)` and `Fixtures.gridColumns(_ capture: String, grid: String) throws -> [String]`, reading from the test bundle's `Fixtures` directory.

- [ ] **Step 2: Run and see them fail** — `swift test --filter AttributeTests --filter PositionTests`; expected: types not found.
- [ ] **Step 3: Implement the four enums as specified above.**
- [ ] **Step 4: Run and see them pass.**
- [ ] **Step 5: Commit** — `git commit -am "Add attributes, positions and tactic slots"` (after `git add`).

---

### Task 4: Reading FMRTE's grid layouts and the clipboard text

**Files:**
- Create: `Import/FMRTEConfig.swift`, `Import/ClipboardText.swift`, and `ImportError` in `Import/Importer.swift`
- Test: `FMRTEConfigTests.swift`, `ClipboardTextTests.swift`

**Interfaces:**
- Produces:
  - `struct GridLayout: Sendable, Equatable { let key: String; let columns: [String] }`
  - `enum FMRTEConfig { static func playerGrids(from data: Data) throws -> [GridLayout] }`
  - `enum ClipboardText { static func rows(_ text: String) throws -> [[String]] }`
  - ```swift
    public enum ImportError: Error, Equatable {
        case configUnreadable(reason: String)
        case noPlayerGrids
        case emptyClipboard
        case notAnFMRTEGrid(reason: String)
        case raggedRows(expected: Int, row: Int, found: Int)
        case noGridFits(fieldCount: Int, violationsByGrid: [String: Int])
        case ambiguousGrid(keys: [String])
        case missingColumns(grid: String, columns: [String])
        case invalidValue(player: String, column: String, value: String)
        case unexpectedScale(column: String)
    }
    ```

Decisions:
- A player grid is any item under `ColumnsSettings.Items` whose `Columns` contain a `Path` equal to `DisplayedName`. Grids with identical column lists are returned once, under the first key.
- `rows` splits on `\r\n` or `\n`, drops blank lines, splits each line on tab, and removes one pair of surrounding double quotes from each field. A field that is not quoted is kept as is.
- `rows` throws `.emptyClipboard` for empty or whitespace-only text, `.notAnFMRTEGrid` if the first non-blank line has no tab or fewer than 20 fields, and `.raggedRows` if any line's field count differs from the first. Row numbers in errors start at 1.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func readsBothPlayerGridsFromTheSnapshot() throws {
    let grids = try FMRTEConfig.playerGrids(from: Fixtures.data("captures/u21.grids.json"))
    #expect(grids.map(\.key).sorted() == ["SearchPlayersColumns", "TeamPlayersColumns"])
    #expect(grids.allSatisfy { $0.columns.count == 98 })
    #expect(grids.first { $0.key == "SearchPlayersColumns" }?.columns[1] == "DisplayedName")
}
@Test func configWithANewShapeNamesWhatWasExpected() {          // Review Focus 4
    #expect(throws: ImportError.configUnreadable(reason: "ColumnsSettings.Items not found")) {
        try FMRTEConfig.playerGrids(from: Data(#"{"Theme":"Dark"}"#.utf8))
    }
    #expect(throws: ImportError.self) { try FMRTEConfig.playerGrids(from: Data("not json".utf8)) }
}
@Test func splitsTheRealPasteIntoSixRowsOf98Fields() throws {
    let rows = try ClipboardText.rows(Fixtures.text("captures/u21.tsv"))
    #expect(rows.count == 6)
    #expect(rows.allSatisfy { $0.count == 98 })
    #expect(rows[0][1] == "Brayden Daniel")
    #expect(rows[0][0] == "")
}
@Test(arguments: ["", "   \n", "https://example.com", "Just a sentence someone copied."])
func clipboardThatIsNotAPasteIsRejected(_ text: String) {        // Review Focus 1
    #expect(throws: ImportError.self) { try ClipboardText.rows(text) }
}
@Test func raggedRowsNameTheRow() {
    let line = (0..<98).map { "\"\($0)\"" }.joined(separator: "\t")
    #expect(throws: ImportError.raggedRows(expected: 98, row: 2, found: 97)) {
        try ClipboardText.rows(line + "\r\n" + line.dropLast(5))
    }
}
```

- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement `FMRTEConfig.playerGrids`, `ClipboardText.rows` and `ImportError`.** Decode the config with `JSONSerialization` or minimal `Decodable` structs; unknown keys are ignored.
- [ ] **Step 4: Run and see them pass.**
- [ ] **Step 5: Commit** — "Read FMRTE grid layouts and clipboard rows".

---

### Task 5: Working out which grid a paste came from

**Files:**
- Create: `Import/GridDetector.swift`
- Test: `GridDetectorTests.swift`

**Interfaces:**
- Consumes: `GridLayout`, `ImportError`, `Attribute.fromFMRTEPath`, `Position.fromFMRTEPath`.
- Produces: `enum GridDetector { static func detect(rows: [[String]], grids: [GridLayout]) throws -> GridLayout; static func violations(rows: [[String]], layout: GridLayout) -> Int; static let requiredColumns: [String] }`

Decisions (spec 8.2 step 4):
- Candidates are layouts whose column count equals the field count. A candidate fits if it has zero violations over all rows.
- A cell violates its column's type when:
  - attribute path: after removing one leading currency symbol, it is not a whole number from 1 to 20. A leading currency symbol is itself a violation on every attribute except `PhysicalAttributes.Balance`.
  - position rating path: not a whole number from 1 to 20.
  - `IsInjured`, `IsBanned`: not `True` or `False`.
  - `Condition`, `MatchSharpness`: not a whole number from 0 to 10000.
  - `Jadedness`: not a whole number from -1000 to 1000.
  - `Age`: not 14 to 60. `CA`, `PA`: not 1 to 200.
  - `Contract.WagePerWeek`, `AskingPrice`: does not start with a currency symbol followed by digits and thousands separators.
  - `DisplayedName`: empty, or digits only.
  - any other path: never a violation.
- A currency symbol is any of `£`, `$`, `€`.
- Zero fits → `.noGridFits` with each candidate's violation count (empty dictionary if no candidate had the right column count). More than one fit → `.ambiguousGrid`. One fit that lacks a required column → `.missingColumns`.
- `requiredColumns` (`Contract.Club` and `AskingPrice` are optional, because the owner's team grid has neither): `DisplayedName`, `Age`, `CA`, `PA`, `Positions.PositionsDesc`, `IsInjured`, `IsBanned`, `Condition`, `Jadedness`, `MatchSharpness`, `Contract.ContractType`, `Contract.MonthsLeft`, `Contract.WagePerWeek`, `LoanContract.LoanedToTeam`, the 62 attribute paths and the 14 position rating paths.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func realPasteFitsTheSearchGridOnly() throws {
    let rows = try ClipboardText.rows(Fixtures.text("captures/u21.tsv"))
    let grids = try FMRTEConfig.playerGrids(from: Fixtures.data("captures/u21.grids.json"))
    #expect(try GridDetector.detect(rows: rows, grids: grids).key == "SearchPlayersColumns")
    let team = grids.first { $0.key == "TeamPlayersColumns" }!
    #expect(GridDetector.violations(rows: rows, layout: team) > 0)
}
@Test func balanceCurrencySignIsAcceptedOnBalanceAndNowhereElse() {
    let layout = GridLayout(key: "g", columns: ["DisplayedName", "PhysicalAttributes.Balance", "PhysicalAttributes.Pace"])
    #expect(GridDetector.violations(rows: [["A Player", "£11", "9"]], layout: layout) == 0)
    #expect(GridDetector.violations(rows: [["A Player", "11", "9"]], layout: layout) == 0)
    #expect(GridDetector.violations(rows: [["A Player", "11", "£9"]], layout: layout) == 1)
}
@Test func twoLayoutsThatBothFitAreAmbiguous() { /* two keys, same types in swapped order of two attribute columns → .ambiguousGrid(keys:) */ }
@Test func aPasteWithTheWrongFieldCountHasNoCandidates() { /* rows of 5 fields, layouts of 98 columns → .noGridFits(fieldCount: 5, violationsByGrid: [:]) */ }
@Test func noCandidateReportsViolationCounts() { /* rows of 3 fields, layouts of 3 columns that all fail → .noGridFits(fieldCount: 3, violationsByGrid: ["g": n]) */ }
@Test func teamGridPasteFitsTheTeamGridAmongTenGrids() throws {
    let rows = try ClipboardText.rows(Fixtures.text("captures/u21-team-grid.tsv"))
    let grids = try FMRTEConfig.playerGrids(from: Fixtures.data("captures/u21-team-grid.grids.json"))
    #expect(grids.count == 10)
    #expect(try GridDetector.detect(rows: rows, grids: grids).key == "TeamPlayersColumns")
}
@Test func fittingGridWithoutARequiredColumnNamesIt() throws {
    // build rows and a layout from the real search-grid capture with the Condition column removed from both
    // expect .missingColumns(grid: "SearchPlayersColumns", columns: ["Condition"])
}
@Test func clubAndAskingPriceAreNotRequired() {
    #expect(!GridDetector.requiredColumns.contains("Contract.Club"))
    #expect(!GridDetector.requiredColumns.contains("AskingPrice"))
    #expect(GridDetector.requiredColumns.count == 14 + 62 + 14)
}
@Test func reorderedColumnsStillDetect() throws {
    // reverse the column order of the search layout and of every row; detect must return that layout
}
```

Write the sketched tests in full; their inputs are small enough to build inline or by transforming the real capture.

- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement `GridDetector`.**
- [ ] **Step 4: Run and see them pass.**
- [ ] **Step 5: Commit** — "Detect which FMRTE grid a paste came from".

---

### Task 6: Parsing players

**Files:**
- Create: `Model/Player.swift`, rest of `Import/Importer.swift`
- Create: `Tests/.../Support/PlayerFixture.swift`
- Test: `ImporterTests.swift`

**Interfaces:**
- Consumes: Tasks 3 to 5.
- Produces:
  ```swift
  public struct PlayerID: Hashable, Codable, Sendable { public let key: String
      public static func normalise(_ name: String) -> String }
  public enum Squad: String, Codable, CaseIterable, Sendable { case firstTeam, u21, u18 }
  public enum ContractType: Equatable, Codable, Sendable { case fullTime, outOfContract, other(String) }
  public struct Player: Identifiable, Equatable, Codable, Sendable {
      public var id: PlayerID; public var name: String; public var squad: Squad
      public var age: Int; public var positionsText: String
      public var currentAbility: Int; public var potentialAbility: Int
      public var attributes: [Attribute: Int]; public var familiarity: [Position: Int]
      public var condition: Double      // 0...1
      public var sharpness: Double      // 0...1
      public var jadedness: Int
      public var isInjured: Bool; public var isBanned: Bool
      public var club: String?; public var loanedTo: String?
      public var contractType: ContractType; public var monthsLeft: Int?
      public var wagePerWeek: Int; public var askingPrice: Int?
      public var nationalities: [String]; public var extras: [String: String]
  }
  public enum ImportWarning: Equatable, Sendable { case duplicateName(String), outOfContract(String) }
  public struct ImportResult: Equatable, Sendable { public let grid: String; public let players: [Player]; public let warnings: [ImportWarning] }
  public enum Importer { public static func importPlayers(clipboard: String, fmrteConfig: Data, squad: Squad) throws -> ImportResult }
  ```
- Test support: `Player.fixture(name: String = "Test Player", squad: Squad = .firstTeam, age: Int = 25, all attributes: Int = 10, familiarity: [Position: Int] = [:], condition: Double = 1, sharpness: Double = 1, jadedness: Int = -500, ...) -> Player`, every attribute set to the `all` value unless overridden by an `attributes:` argument, every unspecified familiarity 1, club "Oxford City".

Decisions:
- Values are read by column path. `condition` and `sharpness` are the pasted value divided by 10,000.
- Currency: remove the symbol and thousands separators. Attribute values: remove one leading currency symbol (the Balance quirk).
- `positionsText` and names are trimmed. `nationalities` is the field split on commas.
- `contractType`: `FullTime` → `.fullTime`; `4` → `.outOfContract` plus an `.outOfContract(name)` warning; anything else → `.other(raw)`.
- `monthsLeft` is nil when the pasted value is negative.
- `loanedTo` is nil when the field is blank. `club` and `askingPrice` are nil when the grid has no such column.
- `PlayerID.normalise`: lowercased, diacritics folded with `String.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)`, inner whitespace collapsed to single spaces.
- Duplicate names within one import: each affected player's key becomes `<normalised name>#<age>`; if still not unique, `#<age>#<row number>`. One `.duplicateName` warning per name.
- Optional columns present in the grid but not modelled go into `extras` keyed by path.
- Any required cell that is blank or fails to parse throws `.invalidValue(player:column:value:)` with the row's display name.
- When `GridDetector.detect` throws `.noGridFits`, `Importer` looks at the candidate with the fewest violations. If that minimum is unique and no greater than the number of rows, the paste is taken to be from that grid with a few bad cells: the parser runs against it and its first `.invalidValue` is thrown. Otherwise `.noGridFits` is rethrown.
- Scale guard (spec section 4, "unexpected scale"): if every row's `Condition` is 100 or less, throw `.unexpectedScale(column: "Condition")`; the same for `MatchSharpness`. Real values are on a 0 to 10,000 scale, so a whole paste at or below 100 means percentages.
- A unique player ID column is not handled yet. Its path is unknown until the owner finds one in FMRTE (spec section 16).

- [ ] **Step 1: Write the failing tests**

```swift
@Test func importsTheRealU21Paste() throws {
    let r = try Importer.importPlayers(clipboard: Fixtures.text("captures/u21.tsv"),
                                       fmrteConfig: Fixtures.data("captures/u21.grids.json"), squad: .u21)
    #expect(r.grid == "SearchPlayersColumns")
    #expect(r.players.count == 6)
    let daniel = try #require(r.players.first { $0.name == "Brayden Daniel" })
    #expect(daniel.squad == .u21 && daniel.age == 20)
    #expect(daniel.currentAbility == 50 && daniel.potentialAbility == 70)
    #expect(daniel.condition == 0.8167 && daniel.sharpness == 0.725 && daniel.jadedness == -122)
    #expect(daniel.attributes[.init(catalogName: "Balance")!] == 6)          // pasted as "£6"
    #expect(daniel.familiarity[.init(rawValue: "AM (R)")!] == 20)
    #expect(daniel.familiarity[.init(rawValue: "M (R)")!] == 15)
    #expect(daniel.askingPrice == 25_250 && daniel.wagePerWeek == 500)
    #expect(daniel.club == "Oxford City" && daniel.loanedTo == nil)
    #expect(daniel.attributes.count == 62 && daniel.familiarity.count == 14)
}
@Test func importsTheSamePlayersFromTheTeamGrid() throws {
    let r = try Importer.importPlayers(clipboard: Fixtures.text("captures/u21-team-grid.tsv"),
                                       fmrteConfig: Fixtures.data("captures/u21-team-grid.grids.json"), squad: .u21)
    #expect(r.grid == "TeamPlayersColumns" && r.players.count == 6)
    let daniel = try #require(r.players.first { $0.name == "Brayden Daniel" })
    #expect(daniel.condition == 0.8167 && daniel.sharpness == 0.725 && daniel.jadedness == -122)
    #expect(daniel.club == nil && daniel.askingPrice == nil)
    #expect(daniel.extras["Contract.AgreedPlayingTime"] == "Breakthrough Prospect")
    #expect(daniel.extras["Number"] == "23")
    #expect(daniel.attributes.count == 62 && daniel.familiarity.count == 14)
    #expect(try #require(r.players.first { $0.name == "Max Treml" }).loanedTo == "Wallingford")
}
@Test func loanedOutPlayerKeepsHisLoanClub() throws {
    let treml = try #require(u21().first { $0.name == "Max Treml" })
    #expect(treml.loanedTo == "Wallingford" && treml.jadedness == 0 && treml.condition == 0.978)
}
@Test func outOfContractPlayerIsFlaggedAndHasNoMonthsLeft() throws {
    let r = try importU21()
    let ulas = try #require(r.players.first { $0.name == "Aydin Ulas" })
    #expect(ulas.contractType == .outOfContract && ulas.monthsLeft == nil && ulas.wagePerWeek == 0)
    #expect(r.warnings.contains(.outOfContract("Aydin Ulas")))
}
@Test func severalNationalitiesAreSplit() throws {
    #expect(try #require(u21().first { $0.name.hasPrefix("Kauan") }).nationalities == ["Brazil", "England"])
}
@Test func namesAreNormalisedForIdentity() {
    #expect(PlayerID.normalise("  José   MARTÍNEZ ") == "jose martinez")
}
@Test func twoPlayersWithOneNameBothSurvive() throws {               // Review Focus 3
    // duplicate the first row of the real paste, changing only Age from 20 to 18
    // expect 7 players, ids "brayden daniel#20" and "brayden daniel#18", warning .duplicateName("Brayden Daniel")
}
@Test func blankConditionStopsTheImportAndNamesThePlayer() throws {  // Review Focus 5
    // blank the Condition field of row 0 of the real paste, keep the real two-grid config
    // expect .invalidValue(player: "Brayden Daniel", column: "Condition", value: "")
}
@Test func aNonNumericAttributeNamesThePlayerAndColumn() throws {
    // set Brayden Daniel's Pace field to "n/a" → .invalidValue(player: "Brayden Daniel", column: "PhysicalAttributes.Pace", value: "n/a")
}
@Test func aPasteFromAnUnknownLayoutIsNotBlamedOnOneCell() throws {
    // reverse every row's fields but keep the real config → .noGridFits (violations far exceed the row count)
}
@Test func percentageScaleConditionIsRejected() throws {
    // divide every row's Condition by 100 (8167 → "81") → .unexpectedScale(column: "Condition")
}
```

- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement `Player` and its supporting types, `Importer.importPlayers`, and `Player.fixture`.**
- [ ] **Step 4: Run and see them pass.**
- [ ] **Step 5: Commit** — "Import players from an FMRTE paste".

---

### Task 7: Squads, changes, club and loan status

**Files:**
- Create: `Import/SquadBook.swift`
- Test: `SquadBookTests.swift`

**Interfaces:**
- Consumes: `Player`, `Squad`, `ImportResult`.
- Produces:
  ```swift
  public enum LoanStatus: Equatable, Sendable {
      case own, loanedOut(to: String), loanedIn(from: String?)
      public static func of(_ player: Player, ownClub: String?) -> LoanStatus }
  public enum SquadWarning: Equatable, Sendable { case ownClubUnknown }
  public struct SquadChange: Equatable, Sendable {
      public let added: [PlayerID]; public let removed: [PlayerID]
      public let movedIn: [PlayerID]            // previously in another squad
      public let changed: [PlayerID]            // present before and after with any field different
  }
  public struct SquadBook: Equatable, Codable, Sendable {
      public init()
      public private(set) var current: [Squad: [Player]]
      public private(set) var previous: [Squad: [Player]]
      @discardableResult public mutating func apply(_ result: ImportResult, to squad: Squad) -> SquadChange
      public var allPlayers: [Player]           // first team, then U21, then U18, each in import order
      public func ownClub(override: String?) -> String?
      public func loanStatus(of player: Player, override: String?) -> LoanStatus
      public func warnings(override: String?) -> [SquadWarning]
  }
  ```

Decisions (spec 8.2 "Squads" and "Calls made here"):
- `apply` replaces that squad's list, saving the old list in `previous[squad]`. A player with the same id in another squad is removed from that other squad and reported in `movedIn`.
- `ownClub` is the override if non-empty, otherwise the most common non-nil `club` across `allPlayers`; ties go to the alphabetically first; nil when no player has a club (a team-grid import) or there are no players.
- `warnings` contains `.ownClubUnknown` when `ownClub` is nil and at least one player has `loanedTo` set.
- `LoanStatus.of`, first match wins: `loanedTo` set and equal to the own club → `.loanedIn(from: club)`; `loanedTo` set otherwise (including when the own club is unknown) → `.loanedOut(to:)`; own club and `club` both known and different → `.loanedIn(from: club)`; else `.own`. `SquadBook.loanStatus` calls it with `ownClub(override:)`.

- [ ] **Step 1: Write the failing tests** — names and assertions:
  - `importingASquadLeavesOtherSquadsAlone`: apply first team (3 fixtures) then U21 (2); `current[.firstTeam]?.count == 3`.
  - `reimportReplacesAndKeepsPrevious`: apply U21 twice with different players; `previous[.u21]` equals the first list; change reports `added` and `removed`.
  - `aPlayerInALaterImportOfAnotherSquadMoves`: same id in first team then U21; first team no longer has him; `movedIn == [id]`.
  - `changedListsPlayersWhoseFieldsDiffer`: same id, condition 1.0 then 0.9 → `changed == [id]`.
  - `ownClubIsTheMostCommonClubUnlessOverridden`: clubs Oxford City ×4, Reading ×1 → "Oxford City"; override "Reading" → "Reading"; empty book → nil.
  - `loanStatusFromClubAndLoanFields`, own club "Oxford City": loanedTo "Wallingford" → `.loanedOut(to: "Wallingford")`; loanedTo "Oxford City", club "Reading" → `.loanedIn(from: "Reading")`; loanedTo "Oxford City", club nil → `.loanedIn(from: nil)`; club "Reading", no loan → `.loanedIn(from: "Reading")`; otherwise `.own`. Own club nil: loanedTo "Wallingford" → `.loanedOut(to: "Wallingford")`; no loan → `.own`.
  - `teamGridBookHasNoClubUntilOverridden`: from the real team-grid capture, `ownClub(override: nil) == nil`, `warnings(override: nil) == [.ownClubUnknown]`, Max Treml is `.loanedOut(to: "Wallingford")`; with override "Oxford City", `ownClub` is "Oxford City" and `warnings` is empty.
  - `realU21BookFindsOxfordCityAndOneLoan`: from the real search-grid capture, `ownClub(override: nil) == "Oxford City"` and exactly one player is `.loanedOut`.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement `SquadBook`.**
- [ ] **Step 4: Run and see them pass.**
- [ ] **Step 5: Commit** — "Keep per-squad snapshots with changes, club and loan status".

---

### Task 8: Role catalog and rating reference export

**Files:**
- Create: `Roles/RoleCatalog.swift`, `Rating/RatingTables.swift`, `tools/export_rating_reference.py`
- Create by copy: `Sources/LineupEngine/Resources/fm27_roles.json` from `docs/Research/fm27_roles.json`; `Tests/.../Fixtures/reference/fm26_roles.json` from `docs/FM26_Roles_Attributes.json`
- Generated: `Sources/LineupEngine/Resources/rating_tables.json`, `Tests/.../Fixtures/reference/rating_reference_fm26.json`
- Test: `RoleCatalogTests.swift`, `RatingTablesTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct Role: Equatable, Sendable {
      public let name: String; public let phase: Phase; public let positions: Set<Position>
      public let key: [Attribute]; public let preferable: [Attribute] }
  public enum CatalogError: Error, Equatable {
      case malformed(reason: String)
      case unknownAttribute(role: String, name: String)
      case unknownRole(name: String, phase: Phase, position: Position) }
  public struct RoleCatalog: Sendable {
      public init(fm27JSON: Data) throws
      public init(fm26JSON: Data) throws
      public static func fm27() throws -> RoleCatalog                 // bundled resource
      public func role(named: String, phase: Phase, at: Position) throws -> Role
      public func roles(phase: Phase, at: Position) -> [Role]         // sorted by name
      public var allRoles: [Role]                                     // one entry per phase and name
  }
  public struct RatingTables: Sendable {
      public let positionWeights: [Position: [Attribute: Double]]
      public let consensusBonuses: [String: [Attribute: Double]]      // key "<tableKey>|<role name>"
      public let thresholds: [String: [Attribute: Int]]               // key role name
      public init(json: Data) throws
      public static func bundled() throws -> RatingTables
  }
  ```

Decisions:
- FM27 file: `roles[]` entries with `name`, `phase` (`ip`/`oop`), `positions` (position codes), `key`, `preferable`. The catalog is keyed by phase, position and name.
- FM26 file: `{ "IP"|"OOP": { group: { role: { "key": [...], "important": [...] } } } }`. Groups map to positions: `D(L/R)` → D (L), D (R); `D(C)`; `WB(L/R)` → both WB; `DM`; `M (L/R)` → M (L), M (R); `M(C)`; `AM (L/R)` → AM (L), AM (R); `AM (C)`; `ST` → ST (C); `GK`. `important` becomes `preferable`.
- In both loaders, an attribute listed in both tiers counts as key only, and duplicates are removed keeping first occurrence. The FM26 file has two such roles (`Wing Back` in possession and `Holding Full-Back` out of possession at `D(L/R)`).
- An attribute name that is not an `Attribute` raw value throws `.unknownAttribute`. A lookup that finds nothing throws `.unknownRole`; there is no default role.
- `tools/export_rating_reference.py` uses only the standard library and imports `rating_calculator` from the repository root. It writes:
  1. `rating_tables.json`: `POSITION_WEIGHTS` for the 14 positions keyed by `Position` raw value, `CONSENSUS_BONUSES` keyed `"<table key>|<role>"`, `THRESHOLDS` keyed by role.
  2. `rating_reference_fm26.json`: for every row of `players-current.csv` (read with `csv.DictReader`, `utf-8-sig`) that has no blank among the columns used, and for every active slot of `tacticConfig` in `ui/data/app_state.json`: the player's name, `CA`, a dictionary of the 40 engine attributes by canonical name as resolved by `rating_calculator.get_attribute_value` and cleaned to a number, a dictionary of familiarity by position raw value, and for each slot the in-possession position and role, the out-of-possession position and role, and the outputs of `calculate_role_rating` for each phase and `calculate_combined_rating`.
  The slot-to-position rule is the one in Task 3. The out-of-possession slot is `mapping[slot]`.

- [ ] **Step 1: Write the export script and run it**

Run: `python3 tools/export_rating_reference.py`
Expected: prints the number of players and slots written (about 55 players, 11 slots) and creates both files. `rating_tables.json` has 14 position entries each summing to 1.0 within 0.001; the script asserts this.

- [ ] **Step 2: Write the failing tests**

```swift
@Test func fm27CatalogHas79RolesAndFindsThemByPosition() throws {
    let c = try RoleCatalog.fm27()
    let cb = try c.role(named: "Ball-Playing Centre-Back", phase: .inPossession, at: #require(Position(rawValue: "D (C)")))
    #expect(cb.key.map(\.rawValue).contains("Passing"))
    #expect(c.roles(phase: .inPossession, at: #require(Position(rawValue: "GK"))).count == 3)
    #expect(c.allRoles.filter { $0.phase == .inPossession }.count == 40)
    #expect(c.allRoles.filter { $0.phase == .outOfPossession }.count == 39)
}
@Test func unknownRoleIsAnErrorNotADefault() throws {
    let c = try RoleCatalog.fm27()
    #expect(throws: CatalogError.self) { try c.role(named: "Wing Back", phase: .inPossession, at: #require(Position(rawValue: "D (L)"))) }
}
@Test func fm26CatalogLoadsAndKeyWinsOverImportant() throws {
    let c = try RoleCatalog(fm26JSON: Fixtures.data("reference/fm26_roles.json"))
    let wb = try c.role(named: "Wing Back", phase: .inPossession, at: #require(Position(rawValue: "D (L)")))
    #expect(Set(wb.key).isDisjoint(with: wb.preferable))
    #expect(wb.preferable.count == Set(wb.preferable).count)
}
@Test func aRoleFileWithAMisspeltAttributeFailsToLoad() { /* minimal FM27 JSON with "Workrate" → .unknownAttribute */ }
@Test func bundledTablesCoverEveryPosition() throws {
    let t = try RatingTables.bundled()
    #expect(t.positionWeights.count == 14)
    for (_, w) in t.positionWeights { #expect(abs(w.values.reduce(0, +) - 1.0) < 0.001) }
    #expect(t.thresholds["Winger"]?[.init(catalogName: "Pace")!] == 15)
    #expect(t.consensusBonuses["ST|Central Outlet Centre Forward"] != nil)
}
```

Write the sketched test in full.

- [ ] **Step 3: Run and see them fail.**
- [ ] **Step 4: Implement `RoleCatalog` and `RatingTables`.**
- [ ] **Step 5: Run and see them pass.**
- [ ] **Step 6: Commit** — "Add role catalog, rating tables and the FM26 reference export".

---

### Task 9: Tactics

**Files:**
- Create: `Roles/Tactic.swift`, `Tests/.../Fixtures/tactics/sample-4231.json`
- Test: `TacticTests.swift`

**Interfaces:**
- Consumes: `SlotID`, `Phase`, `RoleCatalog`, `Role`.
- Produces:
  ```swift
  public struct Tactic: Equatable, Codable, Sendable {
      public var name: String
      public var inPossession: [SlotID: String]       // slot → role name
      public var outOfPossession: [SlotID: String]
      public var mapping: [SlotID: SlotID]            // in-possession slot → out-of-possession slot
      public func problems(catalog: RoleCatalog) -> [TacticProblem]
      public func assignments(catalog: RoleCatalog) throws -> [SlotAssignment]   // in SlotID order
  }
  public enum TacticProblem: Equatable, Sendable {
      case wrongSlotCount(Phase, Int), missingGoalkeeper(Phase)
      case unmapped(SlotID), mappingTargetInactive(from: SlotID, to: SlotID), duplicateMappingTarget(SlotID)
      case unknownRole(Phase, SlotID, String) }
  public struct TacticError: Error, Equatable { public let problems: [TacticProblem] }
  public struct SlotAssignment: Equatable, Sendable {
      public let slot: SlotID                         // the in-possession slot; identifies the pick
      public let ipPosition: Position; public let ipRole: Role
      public let oopSlot: SlotID; public let oopPosition: Position; public let oopRole: Role }
  ```

Decisions (spec 8.3): a valid tactic has exactly eleven slots per phase, `GK` in both, every in-possession slot mapped to an active out-of-possession slot, and no two in-possession slots mapped to the same target. `assignments` throws `TacticError` when `problems` is non-empty. Mapping entries for inactive in-possession slots are ignored.

The sample tactic, saved as JSON for tests and the CLI:

| In-possession slot | Role | Out-of-possession slot | Role |
|---|---|---|---|
| GK | Goalkeeper | GK | Sweeper Keeper |
| D_L, D_R | Wing-Back | D_L, D_R | Pressing Full-Back |
| D_CL, D_CR | Ball-Playing Centre-Back | D_CL, D_CR | Centre-Back |
| DM_L, DM_R | Defensive Midfielder | DM_L, DM_R | Defensive Midfielder |
| AM_L, AM_R | Inside Forward | M_L, M_R | Wide Midfielder |
| AM_C | Attacking Midfielder | AM_C | Attacking Midfielder |
| ST_C | Channel Forward | ST_C | Centre Forward |

- [ ] **Step 1: Write the failing tests** — names and assertions:
  - `sampleTacticIsValidAndYieldsElevenAssignments`: `problems.isEmpty`; 11 assignments in `SlotID` order starting with `GK`; the `AM_L` assignment has `oopSlot == .M_L`, `ipPosition` AM (L), `oopPosition` M (L), `oopRole.name == "Wide Midfielder"`.
  - `tenSlotsInPossessionIsReported`: remove `ST_C` → contains `.wrongSlotCount(.inPossession, 10)`.
  - `missingGoalkeeperIsReported`, `unmappedSlotIsReported`, `mappingToAnInactiveSlotIsReported`, `twoSlotsMappedToOneTargetIsReported`: one mutation each, one expected problem each.
  - `anFM26RoleNameIsAnUnknownRole`: set `D_L` to "Wing Back" → `.unknownRole(.inPossession, .D_L, "Wing Back")`.
  - `assignmentsThrowsWhenInvalid`: `#expect(throws: TacticError.self)`.
  - `tacticRoundTripsThroughJSON`.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement `Tactic` and write the fixture file.**
- [ ] **Step 4: Run and see them pass.**
- [ ] **Step 5: Commit** — "Add tactics with validation and slot assignments".

---

### Task 10: Rating core

**Files:**
- Create: `Parameters/EngineParameters.swift`, `Rating/RatingEngine.swift`
- Test: `RatingEngineTests.swift`, `RatingReferenceTests.swift`, `EngineParametersTests.swift`

**Interfaces:**
- Consumes: `Player`, `SlotAssignment`, `RatingTables`, `Parameter`.
- Produces:
  ```swift
  public struct FamiliarityStep: Sendable, Equatable { public let minimum: Int; public let factor: Double }
  public struct EngineParameters: Sendable {
      public static let fm27: EngineParameters
      public var positionShare, roleShare, consensusShare: Parameter<Double>
      public var keyWeight, preferableWeight: Parameter<Double>
      public var consensusCap, balanceBonus: Parameter<Double>
      public var thresholdPenaltyPerPoint, thresholdPenaltyFloor: Parameter<Double>
      public var familiaritySteps: Parameter<[FamiliarityStep]>
      public var defensivePhaseWeightIP, otherPhaseWeightIP: Parameter<Double>
      public var outOfPositionBelow: Parameter<Int>
      // Task 11 adds the fitness and risk parameters
      public var all: [(name: String, evidence: Evidence, source: String)]   // every parameter, for the evidence test
  }
  public struct RatingConfiguration: Sendable, Equatable {
      public var appliesCurrentAbilityFactor: Bool
      public var roundsLikeThePythonReference: Bool
      public static let fm27 = RatingConfiguration(appliesCurrentAbilityFactor: false, roundsLikeThePythonReference: false)
      public static let fm26Reference = RatingConfiguration(appliesCurrentAbilityFactor: true, roundsLikeThePythonReference: true)
  }
  public struct PhaseRating: Equatable, Sendable {
      public let positionScore, roleScore, consensusBonus, thresholdFactor: Double
      public let base: Double                 // 0...100 before familiarity
      public let familiarity: Int; public let familiarityFactor: Double
      public var value: Double { base * familiarityFactor } }
  public struct SlotRating: Equatable, Sendable {
      public let inPossession, outOfPossession: PhaseRating
      public let ipWeight: Double
      public let value: Double }              // 0...200
  public struct RatingEngine: Sendable {
      public init(tables: RatingTables, parameters: EngineParameters, configuration: RatingConfiguration)
      public func rating(for player: Player, in assignment: SlotAssignment) -> SlotRating
  }
  ```

The formula, ported from `rating_calculator.py` (read it; it is short). With `n(v) = (v - 1) / 19`:

- Position score = `100 × Σ n(attr) × weight / Σ weight` over the position's weights.
- Role score = `100 ×` weighted mean of `n(attr)` over the role's attributes, key weight 1.5, preferable 1.2. A role with no attributes scores 50.
- Consensus bonus = `min(100 × (Σ n(attr) × bonus over the "<tableKey>|<role>" entries not in the role's attributes, plus 0.01 × n(Balance) if Balance is not a role attribute and the position is not GK), 10)`.
- Base = `0.60 × position + 0.35 × role + 0.05 × consensus`, times the threshold factor: the product over the role's thresholds of `1 - 0.02 × shortfall`, floored at 0.80. Thresholds apply by role name in either phase, as in the Python.
- FM26 reference only: times `clamp(1 + 0.005 × (CA - 100), 0.85, 1.15)`, then rounded to one decimal. These four numbers are private constants beside the reference configuration, not `EngineParameters`: they are not FM27 rules.
- Familiarity factor from the steps: 18 → 1.00, 15 → 0.95, 13 → 0.90, 10 → 0.80, 8 → 0.60, 5 → 0.35, below → 0.10.
- In-possession weight is 0.5 when the out-of-possession position `isDefensive`, otherwise 0.7.
- Value = `2 × (w × ip.value + (1 - w) × oop.value)`; rounded to one decimal in the FM26 reference only.

Evidence labels for `EngineParameters.fm27`: the shares, weights, caps, threshold figures and phase weights are `.carriedOverFM26`, source `rating_calculator.py (branch customizable-tactics)`. Familiarity steps are `.carriedOverFM26` with the note that FM27 Match Lab Study 5 (cap 15 costs 0.26 points per game, cap 10 costs 0.85) is consistent with 0.95 and 0.80. `outOfPositionBelow` is 10, `.derived`.

- [ ] **Step 1: Write the failing rule tests**

```swift
let engine = RatingEngine(tables: try RatingTables.bundled(), parameters: .fm27, configuration: .fm27)

@Test func allTensGivesAPositionScoreOfFortySevenPointFour() throws {
    // every attribute 10 → n = 9/19; a natural centre-back in the sample tactic's D_CL slot
    let cb = Player.fixture(all: 10, familiarity: [dc: 20])
    let r = engine.rating(for: cb, in: try slot(.D_CL))
    #expect(abs(r.inPossession.positionScore - 47.368) < 0.01)
    #expect(r.inPossession.familiarityFactor == 1.0 && r.ipWeight == 0.5)
}
@Test func higherKeyAttributeRaisesTheRating() { /* Passing 10 → 15 raises D_CL rating; Finishing 10 → 15 does not */ }
@Test func familiarityStepsApplyPerPhase() throws {
    // AM_L slot: in possession AM (L), out of possession M (L)
    let both = Player.fixture(familiarity: [aml: 20, ml: 20])
    let ipOnly = Player.fixture(familiarity: [aml: 20, ml: 9])
    let a = engine.rating(for: both, in: try slot(.AM_L)), b = engine.rating(for: ipOnly, in: try slot(.AM_L))
    #expect(b.inPossession.value == a.inPossession.value)
    #expect(b.outOfPossession.familiarityFactor == 0.60)
    #expect(b.value < a.value)
    #expect(a.ipWeight == 0.7)
}
@Test(arguments: [(20, 1.0), (18, 1.0), (17, 0.95), (15, 0.95), (14, 0.90), (13, 0.90), (12, 0.80), (10, 0.80), (9, 0.60), (8, 0.60), (7, 0.35), (5, 0.35), (4, 0.10), (1, 0.10)])
func familiarityFactorAtEachStep(_ familiarity: Int, _ factor: Double) { ... }
@Test func thresholdShortfallCostsTwoPercentPerPointDownToEightyPercent() {
    // Channel Forward thresholds: Acceleration 14, Pace 14, Off The Ball 13
    // Acceleration 12, others met → factor 0.96; all three at 1 → factor 0.80
}
@Test func currentAbilityDoesNotChangeAnFM27Rating() {
    // same attributes, CA 60 vs CA 140 → identical value under .fm27, different under .fm26Reference
}
@Test func everyParameterHasEvidenceAndASource() {
    #expect(EngineParameters.fm27.all.allSatisfy { !$0.source.isEmpty })
    #expect(EngineParameters.fm27.all.count >= 13)
}
```

Fill in the three sketched tests with the values given in their comments.

- [ ] **Step 2: Write the failing reference test**

```swift
@Test func matchesThePythonOnTheFM26Data() throws {
    let ref = try RatingReference.load()        // decodes Fixtures/reference/rating_reference_fm26.json
    let catalog = try RoleCatalog(fm26JSON: Fixtures.data("reference/fm26_roles.json"))
    let engine = RatingEngine(tables: try RatingTables.bundled(), parameters: .fm27, configuration: .fm26Reference)
    #expect(ref.cases.count > 400)
    for c in ref.cases {
        let r = engine.rating(for: c.player, in: try c.assignment(catalog))
        #expect(abs(r.inPossession.base - c.expectedIP) <= 0.1001, "\(c.player.name) \(c.slot) IP")
        #expect(abs(r.outOfPossession.base - c.expectedOOP) <= 0.1001, "\(c.player.name) \(c.slot) OOP")
        #expect(abs(r.value - c.expectedCombined) <= 0.2001, "\(c.player.name) \(c.slot)")
    }
}
```

The tolerances allow for Python's decimal rounding differing from binary rounding at exact ties. `RatingReference` lives in the test target. The reference player has only the 40 engine attributes; build it with `Player.fixture` and override those.

- [ ] **Step 3: Run and see both fail.**
- [ ] **Step 4: Implement `EngineParameters` (rating part) and `RatingEngine`.**
- [ ] **Step 5: Run and see them pass.** If the reference test fails for particular roles, compare against `rating_calculator.py` line by line before changing a tolerance. Do not widen tolerances.
- [ ] **Step 6: Commit** — "Port the rating core and check it against the Python on FM26 data".

---

### Task 11: Fitness factors and risk rules

**Files:**
- Create: `Selection/FitnessModel.swift`, `Selection/RiskRules.swift`
- Modify: `Parameters/EngineParameters.swift`
- Test: `FitnessModelTests.swift`, `RiskRulesTests.swift`

**Interfaces:**
- Consumes: `Player`, `LoanStatus`, `EngineParameters`.
- Produces:
  ```swift
  public struct CurvePoint: Sendable, Equatable { public let x: Double; public let factor: Double }
  public struct JadednessStep: Sendable, Equatable { public let upTo: Int; public let factor: Double }
  // added to EngineParameters:
  //   conditionCurve, sharpnessCurve: Parameter<[CurvePoint]>
  //   jadednessSteps: Parameter<[JadednessStep]>; jadednessAbove: Parameter<Double>
  //   conditionFloor: Parameter<Double>; jadedThreshold: Parameter<Int>
  public struct FitnessFactors: Equatable, Sendable {
      public let condition, sharpness, jadedness: Double
      public var product: Double { condition * sharpness * jadedness } }
  public enum FitnessModel {
      public static func factors(condition: Double, sharpness: Double, jadedness: Int, parameters: EngineParameters) -> FitnessFactors }
  public enum Importance: String, Codable, CaseIterable, Sendable { case high, medium, low, sharpness }
  public enum Exclusion: Equatable, Sendable {
      case injured, outOnLoan(to: String), banned, belowConditionFloor(Double), jaded(Int), rejected }
  public enum RiskRules {
      public static func exclusion(for player: Player, loan: LoanStatus, importance: Importance,
                                   isNextFixture: Bool, parameters: EngineParameters) -> Exclusion?
      public static func canBeOverridden(_ exclusion: Exclusion) -> Bool }
  ```

Values (spec 8.5):

| Parameter | Value | Evidence |
|---|---|---|
| `conditionCurve` | (1.00, 1.00), (0.90, 0.94), (0.80, 0.82), (0.60, 0.58), (0.00, 0.30) | `.derived`; anchors 90% and 80% from FM27 Match Lab (0.28 and 0.80 points per game) |
| `sharpnessCurve` | (1.00, 1.00), (0.75, 0.92), (0.50, 0.78), (0.35, 0.70), (0.00, 0.70) | `.derived`; anchors 75% and 50% from FM27 Match Lab (0.37 and 1.00) |
| `jadednessSteps` | up to 200 → 1.00, up to 400 → 0.90, up to 700 → 0.70 | `.carriedOverFM26` |
| `jadednessAbove` | 0.40 | `.carriedOverFM26` |
| `conditionFloor` | 0.85 | `.carriedOverFM26` |
| `jadedThreshold` | 400 | `.fm27Observation`, FM Lens labels players "Jaded" above 400 |

Curves are evaluated by straight-line interpolation between neighbouring points and clamped at the ends. Sources cite `docs/Research/fm27-condition-fatigue-sharpness.md`.

Rule order in `exclusion`, first match wins: injured; out on loan; banned and `isNextFixture`; condition below the floor; jadedness above the threshold unless importance is `.high`. `canBeOverridden` is false for `.injured` and `.outOnLoan`, true otherwise. `.rejected` is produced by the selector, not here.

- [ ] **Step 1: Write the failing tests**

```swift
@Test(arguments: [(1.0, 1.0), (0.95, 0.97), (0.90, 0.94), (0.85, 0.88), (0.80, 0.82), (0.70, 0.70), (0.60, 0.58), (0.0, 0.30)])
func conditionFactor(_ condition: Double, _ expected: Double) {
    #expect(abs(FitnessModel.factors(condition: condition, sharpness: 1, jadedness: -500, parameters: .fm27).condition - expected) < 0.0001)
}
@Test(arguments: [(1.0, 1.0), (0.75, 0.92), (0.625, 0.85), (0.50, 0.78), (0.35, 0.70), (0.10, 0.70)])
func sharpnessFactor(_ sharpness: Double, _ expected: Double) { ... }
@Test(arguments: [(-500, 1.0), (200, 1.0), (201, 0.9), (400, 0.9), (401, 0.7), (700, 0.7), (701, 0.4), (1000, 0.4)])
func jadednessFactor(_ jadedness: Int, _ expected: Double) { ... }
@Test func aFullyFitPlayerHasProductOne() { ... }

@Test func injuryComesFirstAndCannotBeOverridden() { /* injured + low condition → .injured; canBeOverridden false */ }
@Test func loanedOutPlayerIsExcluded() { /* .loanedOut(to: "Wallingford") → .outOnLoan(to: "Wallingford") */ }
@Test func aBanOnlyCountsForTheNextFixture() { /* isNextFixture true → .banned; false → nil */ }
@Test func conditionFloorAppliesAtEveryImportance() {
    for i in Importance.allCases { /* condition 0.84 → .belowConditionFloor(0.84); 0.85 → nil */ }
}
@Test func aJadedPlayerSitsOutEverythingExceptHigh() {
    /* jadedness 401: .medium, .low, .sharpness → .jaded(401); .high → nil; jadedness 400 → nil everywhere */
}
@Test func aFitOwnPlayerIsNotExcluded() { ... }
```

- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement.** Add the new parameters to `all`.
- [ ] **Step 4: Run and see them pass**, including `everyParameterHasEvidenceAndASource`.
- [ ] **Step 5: Commit** — "Add FM27-calibrated fitness factors and risk rules".

---

### Task 12: Assignment solver

**Files:**
- Create: `Selection/AssignmentSolver.swift`
- Test: `AssignmentSolverTests.swift`

**Interfaces:**
- Produces: `public enum AssignmentSolver { public static func maximise(values: [[Double?]]) -> [Int?] }`

`values[s][p]` is the value of candidate `p` in slot `s`; nil means the pairing is not allowed. The result has one entry per slot: the chosen candidate index, or nil if the slot cannot be filled. Each candidate is used at most once.

Decisions:
- The solution fills as many slots as possible, and among those maximises the total value.
- Ties: subtract `1e-9 × p × (slotCount - s)` from each allowed value before solving. This settles the common tie, two slots with identical requirements such as the two centre-backs, in favour of the lower candidate index in the earlier slot. Values in this engine are 0 to 200, so the perturbation cannot change a real preference. Any tie that remains is settled by the algorithm, which must be deterministic for a given input; callers sort candidates first (Task 13).
- Use the Hungarian algorithm on a square matrix padded with dummy rows or columns. A disallowed pairing costs more than any complete assignment of allowed pairings could (use `1e6`), and a slot matched to a dummy or a disallowed candidate is reported as nil.
- Empty input returns an empty result. More slots than candidates is allowed.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func picksTheGloballyBestNotTheGreedyBest() {
    // slot 0: [10, 9], slot 1: [9, 1] → greedy gives 10 + 1; optimum is 9 + 9
    #expect(AssignmentSolver.maximise(values: [[10, 9], [9, 1]]) == [1, 0])
}
@Test func identicalColumnsBreakTiesByCandidateOrder() {
    #expect(AssignmentSolver.maximise(values: [[5, 5, 5], [5, 5, 5]]) == [0, 1])
}
@Test func aSlotNobodyCanPlayIsNil() {
    #expect(AssignmentSolver.maximise(values: [[nil, nil], [3, 4]]) == [nil, 1])
}
@Test func fillingMoreSlotsBeatsAHigherTotal() {
    // candidate 0 is the only one allowed in slot 1; putting him in slot 0 scores more but leaves slot 1 empty
    #expect(AssignmentSolver.maximise(values: [[100, 1], [50, nil]]) == [1, 0])
}
@Test func moreSlotsThanCandidatesLeavesTheWorstSlotEmpty() {
    #expect(AssignmentSolver.maximise(values: [[9], [5]]) == [0, nil])
}
@Test func matchesBruteForceOnTwoHundredRandomProblems() {
    // seeded linear congruential generator; sizes 1...5 slots by 1...7 candidates; 15% of pairings nil;
    // compare filled count exactly and total value within 1e-6 with exhaustive search; a second run returns the same result
}
@Test func elevenSlotsSixtyCandidatesSolvesQuickly() { /* completes; result has 11 distinct non-nil indices */ }
```

- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement `AssignmentSolver.maximise`.**
- [ ] **Step 4: Run and see them pass.**
- [ ] **Step 5: Commit** — "Add an exact, deterministic assignment solver".

---

### Task 13: Selecting a lineup for one fixture

**Files:**
- Create: `Selection/LineupSelector.swift`
- Test: `LineupSelectorTests.swift`

**Interfaces:**
- Consumes: everything above.
- Produces:
  ```swift
  public struct SelectionRequest: Sendable {
      public var tactic: Tactic
      public var players: [Player]
      public var ownClub: String?
      public var importance: Importance
      public var isNextFixture: Bool
      public var overrides: [SlotID: PlayerID]
      public var rejected: Set<PlayerID> }
  public enum PickWarning: Equatable, Sendable { case outOfPosition(Phase, familiarity: Int), overridesRule(Exclusion) }
  public enum FactorKind: String, Sendable { case condition, sharpness, jadedness }
  public struct Pick: Equatable, Sendable {
      public let slot: SlotID; public let player: PlayerID; public let name: String
      public let rating: SlotRating; public let fitness: FitnessFactors
      public let value: Double                       // rating.value × fitness.product
      public let isOverride: Bool
      public let warnings: [PickWarning]; public let reasons: [String] }
  public enum OmissionCause: Equatable, Sendable {
      case excluded(Exclusion)
      case lowerMatchDayValue(ideal: Double, today: Double, limiting: FactorKind) }
  public struct Omission: Equatable, Sendable {
      public let player: PlayerID; public let name: String; public let slot: SlotID
      public let cause: OmissionCause; public let reason: String }
  public enum OverrideProblem: Equatable, Sendable { case notInSquad, notAllowed(Exclusion), usedTwice }
  public struct Lineup: Equatable, Sendable {
      public let picks: [Pick]                       // SlotID order
      public let unfilled: [SlotID]
      public let omissions: [Omission]
      public let ignoredOverrides: [SlotID: OverrideProblem] }
  public struct LineupSelector: Sendable {
      public init(catalog: RoleCatalog, tables: RatingTables, parameters: EngineParameters, configuration: RatingConfiguration = .fm27)
      public func select(_ request: SelectionRequest) throws -> Lineup     // throws TacticError
  }
  ```

Decisions:
- Candidates are sorted by `PlayerID.key` before solving, so the result does not depend on input order.
- A player is unavailable if `RiskRules.exclusion` returns a value or he is in `rejected`. Unavailable players get nil in every slot.
- An override places the player in the slot before solving and removes both from the problem. It is ignored and reported when the player is not in `players`, when his exclusion cannot be overridden, or when the same player is overridden into two slots (both are ignored). An override of an excluded but overridable player carries `.overridesRule`.
- A pick's `value` is `rating.value × fitness.product`. The solver maximises the sum of values.
- A pick with familiarity below `outOfPositionBelow` in a phase carries `.outOfPosition` for that phase. Such pairings are allowed; they are how a short squad still fields eleven.
- `reasons` for a pick, in order: one line with the rating and each phase's familiarity; one line per fitness factor below 1.0 giving the input and the factor (for example "Condition 82% (×0.84)"); "Chosen by you" for an override, with "overrides: banned" and so on where it applies.
- Omissions: solve once more with every player not out on loan, at full fitness and with no exclusions, rejections or overrides. That is the ideal eleven. For each ideal pick who is not in the real lineup, add an omission for his ideal slot: `.excluded` with the exclusion (or `.rejected`) if he was unavailable, otherwise `.lowerMatchDayValue` with his ideal value, his match-day value in that slot, and the smallest of his three fitness factors as `limiting`.
- `reason` text for an omission states the cause in plain words, for example "Left out: jadedness 430 is above 400" or "Left out: condition 78% lowers him from 142.0 to 113.6".

Review Focus 2 lives here.

- [ ] **Step 1: Write the failing tests** — a helper builds a squad of eleven natural players for the sample tactic plus named extras, using `Player.fixture`. Names and assertions:
  - `fieldsElevenDistinctPlayersInSlotOrder`: 11 picks, slots equal the tactic's in `SlotID` order, no player twice, `unfilled.isEmpty`.
  - `theBetterPlayerStartsWhenBothAreFit`: two centre-backs differing in attributes; the stronger is picked.
  - `lowConditionCostsAStartWhenARivalIsClose`: stronger player at condition 0.86, rival at 1.0 with a rating 5% lower → rival starts; with the stronger player at 1.0 he starts. (The rule changes the outcome, and does not.)
  - `belowTheFloorDoesNotStartAtAnyImportance`: condition 0.84 → not picked; omission cause `.excluded(.belowConditionFloor(0.84))`.
  - `aJadedFirstChoiceStartsOnlyAHighFixture`: a first-choice player whose only cover is out of position, jadedness 430 → omitted at `.medium` with `.excluded(.jaded(430))`; picked at `.high` with jadedness factor 0.7 in `fitness`.
  - `injuredAndLoanedOutPlayersNeverStart`.
  - `aBannedPlayerMissesOnlyTheNextFixture`.
  - `aRejectedPlayerIsLeftOutAndSaysSo`: omission cause `.excluded(.rejected)`.
  - `anOverrideFixesThePlayerInTheSlot`: weaker player overridden into `ST_C` → picked there, `isOverride`, reasons contain "Chosen by you".
  - `anOverrideBeatsTheConditionFloorAndIsMarked`: overridden player at 0.80 → picked with warning `.overridesRule(.belowConditionFloor(0.80))`.
  - `anOverrideOfAnInjuredPlayerIsIgnoredAndReported`: `ignoredOverrides[.ST_C] == .notAllowed(.injured)`; the slot is filled by the solver.
  - `anOverrideForSomeoneNotInTheSquadIsIgnored`: `.notInSquad`.
  - `onePlayerOverriddenIntoTwoSlotsIsIgnoredInBoth`: `.usedTwice` for both.
  - `withBothGoalkeepersInjuredAnOutfielderIsFlaggedInGoal` (Review Focus 2): squad has at least one spare outfielder; 11 picks; the `GK` pick's warnings contain `.outOfPosition(.inPossession, familiarity: 1)`.
  - `aLoanedInPlayerIsAvailable`: `loanedTo` "Oxford City" with own club "Oxford City" → he can be picked (spec 8.2: loaned-in players must not be dropped).
  - `tenAvailablePlayersLeavesOneSlotUnfilled` (Review Focus 2): 10 picks and `unfilled.count == 1`.
  - `anEmptySquadReturnsElevenUnfilledSlots`.
  - `resultDoesNotDependOnInputOrder`: shuffled `players` gives an equal `Lineup`.
  - `aPickBelowFullFitnessExplainsWhy`: condition 0.90 → reasons contain a line starting "Condition 90%".
  - `anInvalidTacticThrows`.
- [ ] **Step 2: Run and see them fail.**
- [ ] **Step 3: Implement `LineupSelector`.**
- [ ] **Step 4: Run and see them pass.**
- [ ] **Step 5: Commit** — "Select and explain a lineup for one fixture".

---

### Task 14: Command-line tool and a run on real data

Depends on Task 2 for the first-team capture.

**Files:**
- Modify: `Sources/lineup-cli/main.swift`
- Test: `EndToEndTests.swift`

**Interfaces:**
- Consumes: `Importer`, `SquadBook`, `Tactic`, `LineupSelector`.

Usage:

```
lineup-cli select --grids <fmrte config or grids snapshot> --tactic <tactic.json>
                  [--first-team <paste.tsv>] [--u21 <paste.tsv>] [--u18 <paste.tsv>]
                  [--importance high|medium|low|sharpness] [--own-club <name>]
```

It prints: the grid recognised and player count per squad; import warnings; own club and players out on loan; then one line per slot with slot, role names, player, squad, rating, fitness factors and value, followed by each pick's warnings; then unfilled slots; then omissions with their reasons. Errors print the `ImportError`, `CatalogError` or `TacticError` in plain words and exit with status 1. Arguments are parsed by hand; no argument-parsing package.

- [ ] **Step 1: Write the failing end-to-end test**

```swift
@Test func realSquadsProduceAFullExplainedLineup() throws {
    var book = SquadBook()
    let grids = try Fixtures.data("captures/first-team.grids.json")
    book.apply(try Importer.importPlayers(clipboard: Fixtures.text("captures/first-team.tsv"), fmrteConfig: grids, squad: .firstTeam), to: .firstTeam)
    book.apply(try Importer.importPlayers(clipboard: Fixtures.text("captures/u21.tsv"),
                                          fmrteConfig: Fixtures.data("captures/u21.grids.json"), squad: .u21), to: .u21)
    let ownClub = book.ownClub(override: "Oxford City")      // the first-team capture is from the team grid, which has no club column
    let tactic = try JSONDecoder().decode(Tactic.self, from: Fixtures.data("tactics/sample-4231.json"))
    let selector = LineupSelector(catalog: try .fm27(), tables: try .bundled(), parameters: .fm27)
    let lineup = try selector.select(.init(tactic: tactic, players: book.allPlayers, ownClub: ownClub,
                                           importance: .high, isNextFixture: true, overrides: [:], rejected: []))
    #expect(lineup.picks.count + lineup.unfilled.count == 11)
    #expect(Set(lineup.picks.map(\.player)).count == lineup.picks.count)
    let names = Set(lineup.picks.map(\.name))
    #expect(!names.contains("Max Treml"))                                   // out on loan
    for p in book.allPlayers where p.isInjured { #expect(!names.contains(p.name)) }
    #expect(lineup.picks.allSatisfy { !$0.reasons.isEmpty })
}
```

- [ ] **Step 2: Run and see it fail** (the CLI and possibly the fixture path are missing).
- [ ] **Step 3: Implement the CLI.**
- [ ] **Step 4: Run the whole suite**

Run: `cd LineupEngine && swift test`
Expected: all tests PASS.

- [ ] **Step 5: Run the tool on the real captures and show the owner**

```bash
cd LineupEngine && swift run lineup-cli select \
  --grids Tests/LineupEngineTests/Fixtures/captures/first-team.grids.json \
  --tactic Tests/LineupEngineTests/Fixtures/tactics/sample-4231.json \
  --first-team Tests/LineupEngineTests/Fixtures/captures/first-team.tsv \
  --u21 Tests/LineupEngineTests/Fixtures/captures/u21.tsv --importance high --own-club "Oxford City"
```

Expected: a lineup of Oxford City players with ratings, fitness factors and reasons. Paste the output to the owner and ask whether the picks look sensible for that tactic. Their answer is input to the next plan, not a gate on this one.

- [ ] **Step 6: Commit** — "Add lineup-cli and an end-to-end test on real captures".

---

### Task 15: Drop role thresholds for FM27 and add a second rating profile

Added after the whole-branch review, on the owner's decision of 13 November 2026, following the research in `docs/Research/fm27-attribute-weights-and-role-thresholds.md`. Read that document's "Recommendations" and its JSON block before starting.

Two changes:

1. **Role thresholds no longer apply in the FM27 configuration.** No engine test in any version supports them, and on a lower-league squad they flip picks. They remain only in the FM26 reference configuration, so the port check against the Python keeps working.
2. **A second rating profile built from FM27 engine tests**, alongside the existing one. Neither is the default yet: the tool prints the lineup under both so the owner can compare and choose.

**Files:**
- Create: `Sources/LineupEngine/Rating/RatingProfile.swift`, `Sources/LineupEngine/Resources/rating_profile_fm27.json`
- Modify: `Sources/LineupEngine/Rating/RatingEngine.swift`, `Sources/LineupEngine/Rating/RatingTables.swift`, `Sources/LineupEngine/Parameters/EngineParameters.swift`, `Sources/LineupEngine/Selection/LineupSelector.swift`, `Sources/lineup-cli/main.swift`, `Sources/lineup-cli/Report.swift`, `CLAUDE.md`
- Test: `RatingProfileTests.swift`, and updates to `RatingEngineTests.swift`, `RatingReferenceTests.swift`, `EngineParametersTests.swift`, `LineupSelectorTests.swift`, `EndToEndTests.swift`

**Interfaces:**
- Consumes: `RatingTables`, `CurvePoint`, `Parameter`, `Evidence`, `Attribute`, `Position`, `Role`, `EngineParameters`, `RatingConfiguration`, `RatingEngine`, `LineupSelector`.
- Produces:
  ```swift
  public enum RoleScoreRule: Sendable, Equatable {
      /// Weighted mean over the union of key and preferable attributes (the carried-over rule).
      case weightedUnion(keyWeight: Double, preferableWeight: Double)
      /// Mean of the key attributes, with the preferable attributes' mean blended in at `preferableShare`.
      case keyWithPreferableTieBreak(preferableShare: Double)
  }
  public struct RatingProfile: Sendable {
      public let id: String                      // "carried-over" or "fm27-engine-tests"
      public let name: String                    // "Carried over from FM26" or "FM27 engine tests"
      public let tables: RatingTables
      public let curves: [Attribute: [CurvePoint]]   // attribute value 1...20 → 0...1; no entry means the straight line (v - 1) / 19
      public let positionShare: Parameter<Double>
      public let roleShare: Parameter<Double>
      public let consensusShare: Parameter<Double>
      public let roleScoreRule: Parameter<RoleScoreRule>
      public let evidence: [(name: String, evidence: Evidence, source: String)]   // every table and number in the profile
      public static func carriedOver() throws -> RatingProfile
      public static func fm27EngineTests() throws -> RatingProfile
      public static func all() throws -> [RatingProfile]     // carried over first
      public func scaled(_ value: Int, for attribute: Attribute) -> Double
  }
  // RatingConfiguration gains: public var appliesRoleThresholds: Bool
  //   .fm27          → false, false, false   (no current-ability factor, no rounding, no thresholds)
  //   .fm26Reference → true, true, true
  // RatingEngine.init(profile: RatingProfile, parameters: EngineParameters, configuration: RatingConfiguration)
  // LineupSelector.init(catalog: RoleCatalog, profile: RatingProfile, parameters: EngineParameters, configuration: RatingConfiguration = .fm27)
  ```

Decisions:

- **What moves out of `EngineParameters`:** `positionShare`, `roleShare`, `consensusShare`, `keyWeight` and `preferableWeight` belong to a profile now and leave `EngineParameters`. Everything else stays: familiarity steps, phase weights, consensus cap, Balance bonus, threshold penalty figures, empty-role score, the fitness and risk parameters.
- **`RatingTables.evidence`** (added by the review fixes) becomes part of the carried-over profile's `evidence`; remove the separate static list.
- **Carried-over profile:** exactly today's behaviour apart from thresholds. Tables from `rating_tables.json`; no curves; shares 0.60, 0.35, 0.05; `.weightedUnion(keyWeight: 1.5, preferableWeight: 1.2)`; all `.carriedOverFM26`.
- **FM27 engine-tests profile**, built from `rating_profile_fm27.json`:
  - The resource holds the research's source numbers under the engine's own names (`Attribute` and `Position` raw values): the outfield base weights, the per-band slopes, the bands, the position multipliers, and the goalkeeper rule. Copy the numbers from the research document's JSON block; translate its names ("JumpingReach" → "Jumping Reach", "WorkRate" → "Work Rate", "NaturalFitness" → "Natural Fitness", "LongShots" → "Long Shots"; "DC" → "D (C)", "DL" → "D (L)", "WBL" → "WB (L)", "MC" → "M (C)", "AML" → "AM (L)", "ST" → "ST (C)" and so on). Attributes the research lists with weight 0 are omitted.
  - Position weights for each of the 13 outfield positions: base weight times that position's multiplier (1 where none is given), then renormalised so each position sums to 1. A weight of 0 after the multiplier is dropped.
  - Goalkeeper weights: the carried-over goalkeeper table with Kicking removed, renormalised to sum to 1. Goalkeeper attributes have no curves.
  - Curves, for the 16 attributes with slopes: cumulative value from 1 using the band slopes (1 to 6, 6 to 12, 12 to 18), continuing from 18 to 20 at the 12-to-18 slope, divided by the cumulative value at 20, so every curve runs from 0 at 1 to 1 at 20. An attribute whose slopes are all zero is not given a curve. `scaled(_:for:)` evaluates the curve by straight-line interpolation between whole-number points, and uses the straight line `(v - 1) / 19` for an attribute with no curve.
  - Curves apply wherever the profile scales an attribute: the position score, the role score and the consensus bonus.
  - Shares 0.70 position, 0.30 role, 0 consensus. `.keyWithPreferableTieBreak(preferableShare: 0.05)`.
  - No consensus bonuses and no thresholds in this profile's tables.
  - Evidence: base weights and slopes `.fm27Measured` (source: harvestgreen22's FM27 attribute test as tabulated in FM-Player-Analyzer issue 17, cross-checked against Fm-Match-Lab; note in the source text that the per-band table was derived by a third party and its standard error is two to three points); position multipliers `.derived` (the research labels them speculative); shares and role rule `.derived`; goalkeeper weights `.carriedOverFM26`. Every source cites `docs/Research/fm27-attribute-weights-and-role-thresholds.md`.
  - The research's optional 1.5 to 2 times uplift for Anticipation and Concentration is not applied.
- **Role score under `.keyWithPreferableTieBreak(preferableShare: t)`:** `(1 - t) × mean(key) + t × mean(preferable)`, each mean over the scaled attribute values. With no preferable attributes it is the key mean alone; with no key attributes, the preferable mean alone; with neither, `emptyRoleScore`.
- **Thresholds:** `RatingEngine` applies the threshold factor only when `configuration.appliesRoleThresholds` is true. `PhaseRating.thresholdFactor` is 1.0 otherwise.
- **Balance bonus:** it is part of the consensus bonus, so with a consensus share of 0 it has no effect in the FM27 profile. That is intended.
- **No default profile.** `RatingEngine` and `LineupSelector` take the profile explicitly.
- **Command-line tool:** new option `--profile carried-over | fm27 | both`, default `both`. For `both` it prints the lineup for each profile under a heading with the profile's name, then a comparison: one line per slot with the player picked under each profile and a marker where they differ, and the number of slots that differ. An unknown profile name is a usage error.

- [ ] **Step 1: Write the failing tests**

  `RatingProfileTests.swift`:
  - `bothProfilesLoadAndAreListedCarriedOverFirst`: `all()` returns two, ids `["carried-over", "fm27-engine-tests"]`.
  - `fm27PositionWeightsSumToOneForAllFourteenPositions` (within 1e-9), and none contains an attribute with weight 0.
  - `fm27StrikerWeightsFinishingTwiceAsHeavilyAsItsBaseShare`: for "ST (C)", weight(Finishing) / weight(Pace) equals `(0.0281 × 2.0) / 0.1668` within 1e-9; for "D (C)", Finishing and Long Shots are absent.
  - `fm27GoalkeeperWeightsDropKicking`: no Kicking; the other goalkeeper weights keep their carried-over ratios (Agility to Reflexes is 0.140 to 0.130).
  - `curvesRunFromZeroAtOneToOneAtTwenty`: for every curve, `scaled(1) == 0` and `scaled(20) == 1` within 1e-9, and the curve never decreases.
  - `paceIsSteepestInTheMiddleBand`: `scaled(9) - scaled(8)` for Pace is greater than `scaled(16) - scaled(15)` and greater than `scaled(4) - scaled(3)`.
  - `workRateIsFlatAboveTwelve`: `scaled(12) == scaled(18) == scaled(20)` for Work Rate, and `scaled(6) > 0.9`.
  - `anAttributeWithoutACurveIsLinear`: Passing in the FM27 profile and Pace in the carried-over profile give `(v - 1) / 19`.
  - `everyProfileNumberHasEvidenceAndASource`: each profile's `evidence` is non-empty, no source is empty, the FM27 profile has at least one `.fm27Measured` and one `.derived` entry, and the carried-over profile has only `.carriedOverFM26`.

  `RatingEngineTests.swift`:
  - `thresholdsDoNotApplyInTheFM27Configuration`: a Channel Forward with Acceleration 12 has `thresholdFactor == 1.0` under `.fm27` and 0.96 under a configuration with `appliesRoleThresholds: true`. Replace the existing threshold test's use of `.fm27` accordingly, keeping its 0.96 and 0.80 assertions under the thresholds-on configuration.
  - `aPlayerBelowAThresholdNoLongerLosesHisPlaceBecauseOfIt`: two strikers, one better on the position and role attributes but below the Channel Forward thresholds; under `.fm27` he rates higher, under thresholds-on he rates lower.
  - `keyOnlyRoleScoreIgnoresPreferableExceptAsATieBreak`: under the FM27 profile, raising a preferable attribute from 10 to 20 moves the role score by at most 5 points, while raising a key attribute does so by more; two players equal on key attributes are ordered by their preferable attributes.
  - `theTwoProfilesRateAFastWeakPasserDifferently`: a player with Pace and Acceleration 18 and Passing and Technique 5 rates relatively better under the FM27 profile than a player with the reverse, and the order is the opposite or closer under the carried-over profile for a passing role (pick the Deep-Lying Playmaker at DM).
  - Existing tests are updated to construct `RatingEngine(profile:parameters:configuration:)`; tests of the consensus bonus and Balance run against the carried-over profile.

  `RatingReferenceTests.swift`: unchanged in what it asserts; it builds the engine from the carried-over profile with `.fm26Reference`. All 594 cases must still pass with the same tolerances.

  `LineupSelectorTests.swift`: update construction; add `theSelectorUsesTheProfileItIsGiven`: the same squad gives a different lineup or different ratings under the two profiles for a pair of players constructed to differ.

  `EndToEndTests.swift`: run the real captures under both profiles. For each: eleven slots accounted for, no player twice, no injured or loaned-out player picked, every pick has reasons. Re-pin the carried-over profile's three picks to what it now selects without thresholds, and pin three picks for the FM27 profile, after checking both lineups by eye; record both lineups in the report.

- [ ] **Step 2: Run them and see them fail**

  Run: `cd LineupEngine && swift test --filter RatingProfileTests`
  Expected: FAIL, `RatingProfile` not found.

- [ ] **Step 3: Implement**

  Create the resource and `RatingProfile`; change `RatingEngine` to take a profile and to scale attributes through `profile.scaled`; add the configuration flag; move the five parameters; update `LineupSelector`, the command-line tool and `CLAUDE.md` (one paragraph on profiles).

- [ ] **Step 4: Run the whole suite**

  Run: `cd LineupEngine && swift test`
  Expected: all tests PASS, no build warnings.

- [ ] **Step 5: Run the tool on the real captures under both profiles**

  ```bash
  cd LineupEngine && swift run -q lineup-cli select \
    --grids Tests/LineupEngineTests/Fixtures/captures/first-team.grids.json \
    --tactic Tests/LineupEngineTests/Fixtures/tactics/sample-4231.json \
    --first-team Tests/LineupEngineTests/Fixtures/captures/first-team.tsv \
    --u21 Tests/LineupEngineTests/Fixtures/captures/u21.tsv --own-club "Oxford City" --profile both
  ```

  Expected: two lineups and a comparison. Paste the full output into the report.

- [ ] **Step 6: Commit** — "Drop role thresholds for FM27 and add an FM27 engine-test rating profile".

---

### Task 16: Keep a player's identity when namesakes join, leave or move

Added after the re-review of the whole-branch fixes. Identity is name-based until the owner confirms whether FMRTE offers a unique ID column (spec section 16). The re-review found one remaining fault and one instability in that scheme:

- **A real move can duplicate a player.** Import U21 first, so its Brayden Daniel (potential ability 70) holds the plain key. Import a first team containing a different Brayden Daniel (120), who becomes `brayden daniel#120`. Import the first team again, now also containing the 70 player, who has moved up. The importer keys him `brayden daniel#70`; `SquadBook` only tries keys built from that incoming key, never the plain one he already holds in U21, so it sees no move. The book then holds him in both squads under two keys, and one person can fill two slots.
- **A key changes when a namesake joins or leaves.** When a namesake joins a player's paste the importer re-keys him (`brayden daniel` becomes `brayden daniel#120`); when the namesake leaves, he reverts. Each change is reported as one player removed and one added, and anything later stored by `PlayerID` would lose him.

**Files:**
- Modify: `Sources/LineupEngine/Import/SquadBook.swift`, `Sources/LineupEngine/Parameters/EngineParameters.swift`, `Sources/LineupEngine/Selection/FitnessModel.swift` or `Selection/LineupSelector.swift` (see the last decision)
- Test: `SquadBookTests.swift`, `EngineParametersTests.swift`

**Interfaces:**
- Consumes: `SquadBook`, `ImportResult`, `Player`, `PlayerID`, `SquadChange`, `SquadWarning`.
- Produces: no new types. `SquadBook.apply(_:to:)` keeps its signature.

Decisions. "The same person" means equal normalised name, equal `potentialAbility` and equal `nationalities`. When `apply` decides the key for each incoming player, the first rule that matches wins:

1. **He is already in this squad.** If this squad's current list holds the same person, the incoming player takes that player's existing key, whatever key the importer gave him.
2. **He is in another squad.** If another squad holds the same person, the incoming player takes that key, the holder is removed from the other squad, and he is reported in `movedIn`.
3. **Otherwise** the existing rules apply: his importer key, re-keyed if a different person elsewhere already holds it.

Details:
- An existing key can be claimed by only one incoming player in one import. If two incoming players are the same person as one existing player (indistinguishable namesakes), the first in paste order takes the existing key and the other falls through to the next rule.
- When several existing players qualify under one rule, take the first in `allPlayers` order.
- After keys are decided, they must be unique within the import. If rule 1 or 2 gives a player a key that another incoming player's importer key equals, the other player is the one re-keyed, by the existing rules.
- `SquadChange`: a player who keeps his key under rule 1 is not `added` or `removed`; he is `changed` only if a field other than `id` differs.
- Two small fixes from the same re-review, in this task because they are one line each: the source of `conditionFloor` in `EngineParameters` cites `docs/Research/physical-condition.md`, but the line it quotes is in `docs/Research/physical-condition-claude.md`; correct the path there and in the test that asserts it. `FitnessFactors.product` is now unused and duplicates the multiplication inside the selector's match-day value helper; make that helper use `product`.

- [ ] **Step 1: Write the failing tests** in `SquadBookTests.swift`:
  - `aRealMoveIsSeenEvenWhenANamesakeIsInTheDestinationPaste`: the scenario above with "Tyrone Marsh" (potential ability 90 in U21 with the plain key; first-team import holding Marsh 120 and Marsh 90). Expect `movedIn` to hold the U21 player's original key, U21 no longer to hold him, exactly two Marshes in `allPlayers`, and their two keys distinct.
  - `aNamesakeJoiningThePasteDoesNotChangeAnExistingPlayersKey`: first team holds Marsh 120 with the plain key; re-import the first team with a second, different Marsh 90 added. The 120 player's key is unchanged, he is not in `added` or `removed`, and the newcomer has a different key.
  - `aNamesakeLeavingDoesNotChangeTheRemainingPlayersKey`: the reverse; the remaining player keeps whatever key he had.
  - `theSameSequenceInEitherImportOrderLosesNobody`: both orders of first team and U21 with a cross-squad namesake, then the move; in each, every person appears exactly once.
  - `indistinguishableNamesakesDoNotBothClaimOneExistingKey`: two incoming players identical in name, potential ability and nationalities against one existing player; keys end up distinct and both players survive.
  - `aPlayerWithNoNationalityStillGetsAStableKey`: the numbered fallback is reached and both players survive with distinct keys.
- [ ] **Step 2: Run them and see them fail** — `cd LineupEngine && swift test --filter SquadBookTests`.
- [ ] **Step 3: Implement the three rules in `SquadBook.apply`, and the two small fixes.**
- [ ] **Step 4: Run the whole suite** — `cd LineupEngine && swift test`; expected: all PASS, no build warnings. Run the real-data command from Task 14 and confirm its output is unchanged.
- [ ] **Step 5: Commit** — "Keep a player's identity when namesakes join, leave or move".

---

### Task 17: Identify players by FMRTE's Id column when the grid has it

Added on 13 November 2026, when the owner found that FMRTE's player grids offer an `Id` column (column path `Id`) and added it to the team grid. The value is a whole number, unique for each player, and does not change with name, age, squad or grid order. It replaces name-based identity whenever it is present. Name-based identity (Task 16) stays as the fallback for a paste from a grid without the column, and says so with a warning.

**Files:**
- Modify: `Sources/LineupEngine/Import/GridDetector.swift`, `Sources/LineupEngine/Import/Importer.swift`, `Sources/LineupEngine/Import/SquadBook.swift`, `Sources/LineupEngine/Model/Player.swift`, `Sources/LineupEngine/Reporting/ErrorDescriptions.swift`, `Sources/lineup-cli/Report.swift`, `Tests/LineupEngineTests/Fixtures/captures/README.md`, `CLAUDE.md`
- Create by copy: `Tests/LineupEngineTests/Fixtures/captures/first-team-with-id.tsv` and `first-team-with-id.grids.json`, from `.superpowers/sdd/2026-11-12-fm27-engine-foundation/captures-with-id/` (exact clipboard bytes and the grid snapshot taken with them; do not alter them)
- Test: `ImporterTests.swift`, `GridDetectorTests.swift`, `SquadBookTests.swift`, `EndToEndTests.swift`, `ErrorDescriptionsTests.swift`

**Interfaces:**
- Consumes: `GridDetector`, `Importer`, `ImportError`, `ImportWarning`, `PlayerID`, `SquadBook`.
- Produces:
  ```swift
  // PlayerID
  public static func fmrte(_ id: Int) -> PlayerID        // key "fmrte:<id>"
  public var fmrteID: Int? { get }                       // the number when the key has that form, else nil
  // ImportError gains:   case duplicateID(id: String, players: [String])
  // ImportWarning gains: case identifiedByName
  ```

Decisions:

- **The column is optional.** `Id` is not added to `GridDetector.requiredColumns`. Its type rule in the detector: a whole number of 1 or more, with no sign, separator or currency symbol.
- **When the fitting grid has the `Id` column:** every player's key is `fmrte:<id>`. A blank or non-numeric `Id` throws `.invalidValue` naming the player and the column. Two rows with the same `Id` throw `.duplicateID` naming the id and both players. The duplicate-name handling is skipped entirely: no `#` keys, no `.duplicateName` or `.indistinguishable` warnings.
- **When it does not:** behaviour is exactly as today, plus one `.identifiedByName` warning per import.
- **`SquadBook`:** two players with the same `fmrte:` key are the same person, whatever their names, potential ability or nationalities. Task 16's same-person test (name, potential ability and nationalities) applies only when at least one of the two keys is name-based. Then:
  - An incoming player with an `fmrte:` key whose key is held in another squad has moved; the holder is removed there and he is in `movedIn`.
  - An incoming player with an `fmrte:` key who is the same person, by Task 16's test, as an existing player with a name-based key (in this squad or another) takes over from him: the name-keyed entry is removed, the incoming player keeps his `fmrte:` key, and if the old entry was in another squad he is in `movedIn`. Within the same squad he is reported in `changed`, not as one removed and one added.
  - An incoming player with a name-based key who is the same person as an existing player with an `fmrte:` key takes that existing key. Task 16's rules 1 and 2 already do this; add tests.
  - `SquadWarning.sharedName` is raised only for names that have more than one name-based key. Players with `fmrte:` keys never trigger it.
- **Sentences:** `.duplicateID` reads "Two rows have the same FMRTE Id <id>: <name> and <name>". `.identifiedByName` reads "This grid has no Id column, so players are identified by name. Add the Id column in FMRTE for exact identity." The command-line tool prints the warning once per squad imported without the column.
- **The new capture** was taken after a match: ten of the eighteen players are below the 85% condition floor and three are injured. It is added beside the existing `first-team` capture, which stays. Update the captures README: `first-team-with-id` is exact clipboard bytes from the team grid with the `Id` column (99 columns).

- [ ] **Step 1: Copy the capture into the fixtures and write the failing tests**
  - `GridDetectorTests`: `aPasteWithAnIdColumnFitsTheTeamGrid` (the new capture detects `TeamPlayersColumns`, 99 columns); `idIsNotARequiredColumn`; `anIdMustBeAWholePositiveNumber` (accepted "146837"; rejected "", "0", "-5", "12a", "£12", "1,234").
  - `ImporterTests`: `playersFromAGridWithIdsAreKeyedById` (new capture: 18 players, Alfie Potter's id key is `fmrte:146837` and `fmrteID == 146837`, every key has the `fmrte:` prefix, no `.identifiedByName`, `.duplicateName` or `.indistinguishable` warning); `twoNamesakesWithDifferentIdsNeedNoNameHandling` (duplicate a row of the new capture changing only its `Id`: both import, keys are the two ids, no name warnings); `twoRowsWithOneIdStopTheImport` (`.duplicateID(id: "146837", players: [...])`); `aBlankIdNamesThePlayer`; `aGridWithoutIdsWarnsThatIdentityIsByName` (the `u21` capture: exactly one `.identifiedByName`, keys as before).
  - `SquadBookTests`: `aPlayerWithAnIdMovesBetweenSquadsByIdAlone` (same id, different name spelling and potential ability: still one person, moved); `aNamesakeWithADifferentIdIsADifferentPerson` (no warning, both kept); `importingWithIdsTakesOverFromNameKeyedEntries` (import first team without ids, then the same players with ids: same count, every key now `fmrte:`, nobody in `added` or `removed`); `importingWithoutIdsAfterIdsKeepsTheIdKeys` (the reverse: keys stay `fmrte:`); `sharedNameIsNotRaisedForPlayersWithIds`.
  - `EndToEndTests`: `thePostMatchSnapshotFieldsWhoItCan`: import the new capture as the first team and the `u21` capture as U21, own club "Oxford City", sample tactic, importance high. Eleven slots accounted for, no player twice, no injured or loaned-out player picked, every first-team pick's key has the `fmrte:` prefix, and no pick has condition below the floor. Record the lineup and the unfilled slots in the report.
  - `ErrorDescriptionsTests`: the two new sentences.
- [ ] **Step 2: Run them and see them fail** — `cd LineupEngine && swift test --filter ImporterTests`.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run the whole suite** — expected: all PASS, no build warnings. The real-data command from Task 14 (which uses captures without the column) must print the same lineup as before, plus the new identified-by-name warning lines.
- [ ] **Step 5: Run the tool on the new capture**

  ```bash
  cd LineupEngine && swift run -q lineup-cli select \
    --grids Tests/LineupEngineTests/Fixtures/captures/first-team-with-id.grids.json \
    --tactic Tests/LineupEngineTests/Fixtures/tactics/sample-4231.json \
    --first-team Tests/LineupEngineTests/Fixtures/captures/first-team-with-id.tsv \
    --u21 Tests/LineupEngineTests/Fixtures/captures/u21.tsv --own-club "Oxford City"
  ```

  Paste the full output into the report.
- [ ] **Step 6: Commit** — "Identify players by FMRTE's Id column when the grid has it".

---

## Later plans

Each is written when the one before it is done, because each depends on interfaces and findings from the last.

| Plan | Spec sections | Depends on |
|---|---|---|
| 2. Planner | 8.6: projection, the importance table, development and retraining preferences, saving players for bigger fixtures, stability, confirmed-lineup history | this plan |
| 3. Advisors | 8.7: First and Second XI, squad tiers, Depth, Rest, Training with accepted retraining, Player Removal, importance suggestion | plans 1 and 2 |
| Visual design pass | 12: direction and mock-ups, its own short design document | approval of the spec; runs alongside plans 1 to 3 |
| 4. App | 9 and 10: persistence, clipboard, the ten screens and settings | plans 1 to 3 and the visual design |
| 5. Clean-up | 14 step 7: remove Electron, Python, Windows scripts, workbook and `fm26_parser/`; final `CLAUDE.md` and README | owner sign-off of the app |
