# FM27 League Table Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The owner pastes his league's standings from FMRTE and enters the league's format once; the app says where he stands, works the league situation out from the table, and raises a league match against a side within 6 points of him.

**Architecture:** The engine gains a standings reader (columns from FMRTE's settings file, as for squads), a league format with its lines, and one function that reads where the club stands against each line. The importance suggestion is handed that reading beside the owner's choice by hand. The app keeps the table and the format in a file of their own, shows them on a new League screen, and turns a league fixture's opponent into a menu of the table's teams.

**Tech Stack:** Swift 6, macOS 26, SwiftUI and Observation, Swift Testing, Foundation only. Same packages and conventions as the earlier plans.

**Spec:** `docs/superpowers/specs/2026-11-19-fm27-league-table-design.md`. Read it before any task; its appendix holds the owner's table.

## Revision R1, accepted by the owner

**Sides he is battling are counted only in his last ten matches.** The design as first approved counted every side within 6 points at any time. At the start of a season every team is within 6 points of every other, so every league match would take the ×1.2 and be suggested High for the first weeks. The owner accepted on 19 November 2026 ("we'll keep your recommendation") that they are counted only when he has 10 matches or fewer left, the same line that gates "Title race or relegation fight". The design carries it, marked "revised". Tasks 2 and 3 build it; their tests for it are marked R1.

## Global Constraints

- Work on branch `fm27-native`. Never commit to `main`, merge, or open a pull request. Say why in every commit message.
- Other work may sit uncommitted in the tree. Stage only the files your task names (`git add <paths>`), never `git add -A` or `git commit -a`.
- The engine decides; the app shows. A view never computes a place, a gap, a situation or a reason. Every word about the reading (sentences, line names, refusals, warnings, evidence notes) comes from the engine and is shown as written. Core holds only plain labels and headings.
- No silent defaults. A missing column, or a blank or non-numeric cell, is an error that names the team and the column. Until the three numbers are entered there is no format.
- Every tunable number lives in `EngineParameters` with an evidence label and a source: margin 6, margin with one match left 3, 1 point for each match left, last 10 matches, factor 1.2, 3 points a win, 1 a draw.
- Team and club names are compared with `PlayerID.normalise` and nothing looser.
- Every rule gets a test where it changes an outcome and a test where it does not. Tests are written first. All league arithmetic is in whole numbers.
- Test output must be clean: no build warnings. Every `switch` over an engine enum, error or warning is exhaustive, with no `default`.
- Logic for a screen lives in `LineupAppCore` with tests. Views hold layout only. Every colour, typeface and measure comes from `Theme`. No condensed numerals in tables.
- Nothing the owner reads is an id or a code: fixtures are named by opponent and date.
- A file that cannot be read gives a notice and a fresh start for that file, and the unreadable file is kept aside. No test, picture run or sample-data run touches `~/Library/Application Support` or the real clipboard.
- A paste of the table saves the league file and clears the kept suggestions. It does not plan, and touches no fixture, squad, mark or other file.
- The old Python, `ui/` and root-level data files are reference only: do not modify them.
- After every task both packages build and their tests pass: `cd LineupEngine && swift test`, and `cd LineupApp && swift build && swift test` (about four and a half minutes).

## Review Focus

Conditions the spec does not spell out and that are most likely to bite, most likely first. Each has its test in the task named.

1. **The start of a season.** Every team has 0 points and 46 matches left. The reading must be "In contention" with nobody counted as a side he is battling (R1), not 23 rivals. Task 2, `atTheStartOfTheSeasonNobodyIsBattledAndTheSituationIsInContention`.
2. **The wrong thing on the clipboard.** A squad paste on the League screen, or text with no tabs. The paste is refused in a sentence and the table held is kept. Task 1, `aSquadPasteIsRefusedAsNoStandingsGrid`; Task 4, `aRefusedPasteKeepsTheTableHeld`.
3. **The club's name changes after a table is held** (the override in Settings, or another club's squad imported). The League screen says the club is not in the table, the suggestions are worked out as with no table, and putting the name back restores the reading. Task 4, `aClubNoLongerInTheTableStopsTheReadingAndSaysSo`.
4. **A new table the three numbers do not fit** (a league of 10 pasted over a format of 1, 6 and 4). The table is kept, the reading is replaced by the sentence about the numbers, and no suggestion uses it. Task 4, `aTableTheFormatDoesNotFitIsKeptAndSaysSo`.
5. **An opponent typed in another case or spacing, twice.** " buxton" on two league fixtures and one cup fixture: both league fixtures take the factor and the cup fixture does not. Task 3, `theFactorMatchesNamesAsTheSquadBookDoesAndOnlyInTheLeague`.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `tools/capture_fmrte_paste.sh` | modify | also saves the standings grids' layouts |
| `LineupEngine/Tests/LineupEngineTests/Fixtures/captures/league-table.tsv`, `league-table.grids.json`, `README.md` | create, create, modify | the owner's table, rebuilt from the spec's appendix |
| `LineupEngine/Sources/LineupEngine/Import/ClipboardText.swift` | modify | the splitter takes its floor on fields |
| `LineupEngine/Sources/LineupEngine/Import/FMRTEConfig.swift` | modify | `standingsGrids(from:)` |
| `LineupEngine/Sources/LineupEngine/Import/LeagueTableImporter.swift` | create | `LeagueTeam`, `LeagueTable`, `LeagueTableWarning`, `LeagueTableError`, `LeagueTableImporter.read` |
| `LineupEngine/Sources/LineupEngine/Advisors/League.swift` | create | `LeagueFormat`, `LeagueLine`, `LeagueFormatError`, `LineReading`, `LeagueRival`, `LeagueReading`, `LeagueContext`, `League.read`, `League.spokenFor` |
| `LineupEngine/Sources/LineupEngine/Parameters/EngineParameters.swift` | modify | `LeagueStandingRules`, `leagueStandingRules` |
| `LineupEngine/Sources/LineupEngine/Selection/FitnessModel.swift` | modify | the new numbers checked in `problems(in:)` |
| `LineupEngine/Sources/LineupEngine/Advisors/ImportanceSuggestion.swift` | modify | `suggest` takes the choice by hand and the league context |
| `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText+League.swift` | create | every sentence about the table |
| `LineupEngine/Sources/LineupEngine/Reporting/ErrorDescriptions.swift` | modify | `LeagueTableError`, `LeagueFormatError`, `LeagueTableWarning` in plain words |
| `LineupEngine/Sources/lineup-cli/main.swift` | modify | `advise --league-table --league-format` |
| `LineupEngine/Tests/LineupEngineTests/LeagueTableImporterTests.swift`, `LeagueTests.swift`, `LeagueTextTests.swift` | create | the reader's, the reading's and the words' tests |
| `LineupEngine/Tests/LineupEngineTests/ImportanceSuggestionTests.swift`, `Support/Fixtures.swift` | modify | the suggestion's league tests; the capture's accessors |
| `LineupApp/Sources/LineupAppCore/Store.swift`, `AppModel.swift` | modify | `StoreFile.league`; the model's `league` state |
| `LineupApp/Sources/LineupAppCore/LeagueState.swift` | create | `LeagueState`, `LeagueReadingState` |
| `LineupApp/Sources/LineupAppCore/AppModel+League.swift` | create | paste, remove, the format, the reading, the context |
| `LineupApp/Sources/LineupAppCore/LeaguePresentation.swift` | create | what the League screen shows |
| `LineupApp/Sources/LineupAppCore/AppModel+Advice.swift`, `AppModel+Fixtures.swift`, `FixturePresentation.swift`, `Screen.swift`, `SampleData.swift` | modify | the context to the suggestion; the menu's "From the table"; the draft's opponent menu; the new screen; a sample table |
| `LineupApp/Sources/LineupAppUI/League/LeagueScreen.swift` | create | the League screen |
| `LineupApp/Sources/LineupAppUI/Fixtures/FixturesScreen.swift`, `FixtureEditor.swift`, `RootView.swift`, `ScreenPictures.swift`, `Theme.swift`, `LineupApp/Sources/LineupApp/main.swift` | modify | the menu entry, the opponent menu, the route, the pictures |
| `LineupApp/Tests/LineupAppCoreTests/LeagueTests.swift`, `LeaguePresentationTests.swift` | create | the app's league tests |
| `LineupApp/Tests/LineupAppCoreTests/FixturePresentationTests.swift`, `StoreTests.swift`, `ScreenTests.swift`, `Support/TestModel.swift` | modify | the draft's menu; the new file; the new screen; the capture |
| `CLAUDE.md`, this plan, the spec | modify | Task 8 |

---

### Task 1: Reading the standings paste

**Files:**
- Modify: `tools/capture_fmrte_paste.sh`, `LineupEngine/Tests/LineupEngineTests/Fixtures/captures/README.md`, `LineupEngine/Sources/LineupEngine/Import/ClipboardText.swift`, `FMRTEConfig.swift`, `LineupEngine/Sources/LineupEngine/Reporting/ErrorDescriptions.swift`, `LineupEngine/Tests/LineupEngineTests/Support/Fixtures.swift`
- Create: `Fixtures/captures/league-table.tsv`, `Fixtures/captures/league-table.grids.json`, `LineupEngine/Sources/LineupEngine/Import/LeagueTableImporter.swift`
- Test: `LineupEngine/Tests/LineupEngineTests/LeagueTableImporterTests.swift`, `ClipboardTextTests.swift`, `FMRTEConfigTests.swift`, `ErrorDescriptionsTests.swift`

**Interfaces:**
- Produces:

```swift
public struct LeagueTeam: Equatable, Codable, Sendable {
    public var name: String
    public var played, won, drawn, lost, goalsFor, goalsAgainst, points: Int
    public var goalDifference: Int { get }
}
public enum LeagueTableWarning: Equatable, Codable, Sendable {
    case pointsDoNotFit(team: String, points: Int, fromResults: Int)
}
public struct LeagueTable: Equatable, Codable, Sendable {
    public var teams: [LeagueTeam]            // in place order: teams[0] is 1st
    public var orderWorkedOut: Bool           // true when the paste had no Position column
    public var warnings: [LeagueTableWarning]
    public var seasonMatches: Int { get }     // 2 × (teams.count − 1)
    public func place(of name: String) -> Int?       // 1-based, names by PlayerID.normalise
    public func team(named name: String) -> LeagueTeam?
}
public enum LeagueTableError: Error, Equatable {
    case noStandingsGrid
    case noGridFits(fieldCount: Int)
    case ambiguousGrid(keys: [String])
    case missingColumns(grid: String, columns: [String])
    case invalidValue(team: String, column: String, value: String)
    case tooFewTeams(found: Int)
    case duplicateTeam(String)
    case placesNotInOrder
    case resultsDoNotAddUp(team: String, played: Int, won: Int, drawn: Int, lost: Int)
    case playedTooMany(team: String, played: Int, season: Int)
    case noClubKnown
    case clubNotInTable(club: String, teams: Int)
}
public enum LeagueTableImporter {
    public static func read(clipboard: String, fmrteConfig: Data, ownClub: String?,
                            parameters: EngineParameters) throws -> LeagueTable
}
// ClipboardText.rows(_ text: String, minimumFields: Int = ClipboardText.minimumFieldCount)
// FMRTEConfig.standingsGrids(from data: Data) throws -> [GridLayout]
// ErrorDescriptions.describe(_: LeagueTableError) -> String, describe(_: LeagueTableWarning) -> String
// Fixtures (engine tests): leagueTable: String, leagueTableGrids: Data
```

- `read` also throws the `ImportError`s the splitter and the settings reader throw (`emptyClipboard`, `notAnFMRTEGrid`, `raggedRows`, `configUnreadable`). It takes `parameters` for the points a win and a draw are worth, which Task 2 adds; in this task use 3 and 1 through two private constants and leave a `// Task 2 moves these to EngineParameters` note that Task 2 removes.

- [ ] **Step 1: The fixture.** Write `league-table.tsv` from the spec's appendix: 24 rows, nine fields a row, every field in double quotes, one tab between fields, LF line ends, a final newline. Write `league-table.grids.json` in the shape the other `.grids.json` files have (`{"ColumnsSettings": {"Items": [...]}}`) with one item, `"SettingsKey": "CompetitionStandings"`, `"Sort": null`, and nine columns in the appendix's order, each `{"Name": null, "Path": <path>, "IsWritable": <false for Position and TeamName, else true>, "Converter": "None", "StringFormat": "Auto", "Width": null}`. Add `leagueTable` and `leagueTableGrids` to `Support/Fixtures.swift` beside the other captures.

- [ ] **Step 2: The capture tool.** In `tools/capture_fmrte_paste.sh`, `filtered_items` also keeps an item whose columns include both `TeamName` and `Points`; the header comment and `--list-grids` say "player and standings grids". In the captures' `README.md`, add an entry for `league-table` saying it was pasted into a conversation on 19 November 2026 and rebuilt from the design's appendix, not captured, and that a real capture should replace it. Run `tools/capture_fmrte_paste.sh --list-grids` only if FMRTE's file is present; it reads and prints, and writes nothing.

- [ ] **Step 3: Write the failing tests** in `LeagueTableImporterTests.swift` (and one each in `ClipboardTextTests`, `FMRTEConfigTests`):

| Test | Input | Expect |
|---|---|---|
| `theOwnersTableIsReadWhole` | the fixture, `ownClub: "Oxford City"` | 24 teams; `teams[0]` is Chester 42, 25, 12, 5, 65, 33, 87; `teams[4].name == "Oxford City"`; `teams[14].name == "King's Lynn"`; `orderWorkedOut == false`; no warnings; `seasonMatches == 46` |
| `rowsOutOfOrderAreSortedByTheirPlace` | the fixture's rows reversed | the same table |
| `withoutAPlaceColumnTheOrderIsWorkedOut` | grid and rows without `Position`, rows shuffled, two teams level on points | order by points, then goal difference, then goals for, then name; `orderWorkedOut == true` |
| `placesThatAreNotOneToTheCountAreRefused` | two rows with place "3" | `.placesNotInOrder` |
| `aBlankOrWordyCellNamesTheTeamAndColumn` | Buxton's points "" and then "x" | `.invalidValue(team: "Buxton", column: "Points", value: ...)` |
| `aMissingColumnIsNamed` | grid without `GoalsAllowed`, rows of eight fields | `.missingColumns(grid: "CompetitionStandings", columns: ["GoalsAllowed"])` |
| `resultsThatDoNotAddUpAreRefused` | Chester's played "43" | `.resultsDoNotAddUp(team: "Chester", played: 43, won: 25, drawn: 12, lost: 5)` |
| `moreMatchesThanASeasonHoldsIsRefused` | a team with 47 played, 47 = W+D+L | `.playedTooMany(team:, played: 47, season: 46)` |
| `pointsThatDoNotFitResultsAreKeptWithAWarning` | Marine's points "32" | table read, Marine on 32, `warnings == [.pointsDoNotFit(team: "Marine", points: 32, fromResults: 35)]` |
| `aTeamTwiceIsRefused` | "chester " as a second row's name | `.duplicateTeam("chester ")` or the first spelling; assert the case, not the spelling |
| `oneTeamIsTooFew` | one row | `.tooFewTeams(found: 1)` |
| `aClubNotInTheTableIsRefused` | `ownClub: "Banbury United"` | `.clubNotInTable(club: "Banbury United", teams: 24)` |
| `noClubKnownIsRefused` | `ownClub: nil` | `.noClubKnown` |
| `theClubIsFoundWhateverItsCaseAndSpacing` | `ownClub: " oxford  city"` | reads |
| `aSquadPasteIsRefusedAsNoStandingsGrid` | `Fixtures.firstTeam` with `Fixtures.firstTeamGrids` | `.noStandingsGrid`; with `leagueTableGrids`, `.noGridFits(fieldCount:)` with the squad paste's field count |
| `twoStandingsGridsOfTheSameWidthAndDifferentColumnsAreAmbiguous` | two nine-column standings grids in a different order | `.ambiguousGrid(keys:)`, keys sorted |
| `crlfUnquotedFieldsAndATrailingBlankLineAreRead` | the fixture with CRLF, quotes stripped, "\n\n" at the end | the same table |
| `ClipboardTextTests.aNarrowPasteIsSplitWhenTheFloorIsLowered` | "a\tb", `minimumFields: 2` | `[["a", "b"]]`; with the default floor, `notAnFMRTEGrid` as today |
| `FMRTEConfigTests.standingsGridsAreThoseWithATeamNameAndPoints` | `leagueTableGrids`; then `firstTeamGrids` | one grid of nine columns; then none; two grids with identical columns come back once |

- [ ] **Step 4: Run them to see them fail.** Run: `cd LineupEngine && swift test --filter LeagueTableImporterTests` Expected: does not build (no such type).

- [ ] **Step 5: Implement** the interfaces above. `read` splits with `minimumFields: 2`; takes `standingsGrids` (none: `.noStandingsGrid`); keeps those whose column count is the paste's field count (none: `.noGridFits`; more than one: `.ambiguousGrid`); requires the eight paths the spec lists; reads whole numbers only (a sign, a decimal point or a blank is `.invalidValue`); goes through the checks in the order of the table of tests above; orders the teams; finds the club last.

- [ ] **Step 6: The sentences.** Add `describe(_: LeagueTableError)` and `describe(_: LeagueTableWarning)` to `ErrorDescriptions`, and route `LeagueTableError` through `describe(_: Error)`. Models: "The pasted rows fit none of FMRTE's league table layouts: they have 106 columns." / "FMRTE's settings file has no league table layout." / "Buxton's Points is 'x', not a whole number." / "Chester's 25 wins, 12 draws and 5 losses do not add up to 43 matches played." / "Oxford City is not among the 24 teams pasted. Paste your own league's table, or correct the club's name in Settings." / "The club is not known yet. Import a squad first." / "Marine have 32 points where their results give 35; the table's points are used." Column names are said as FMRTE's paths spaced out ("Goals allowed"). One test per case in `ErrorDescriptionsTests`, asserting the whole sentence.

- [ ] **Step 7: Run the engine's tests.** Run: `cd LineupEngine && swift test` Expected: all pass, no warnings.

- [ ] **Step 8: Commit** the files this task names.

---

### Task 2: The format, the lines and where the club stands

**Files:**
- Create: `LineupEngine/Sources/LineupEngine/Advisors/League.swift`
- Modify: `Parameters/EngineParameters.swift`, `Selection/FitnessModel.swift`, `Import/LeagueTableImporter.swift` (the two constants go), `Reporting/ErrorDescriptions.swift`
- Test: `LineupEngine/Tests/LineupEngineTests/LeagueTests.swift`, `EngineParametersTests.swift`, `FitnessModelTests.swift`, `EvidenceTests.swift`, `ErrorDescriptionsTests.swift`

**Interfaces:**
- Consumes: `LeagueTable`, `LeagueTeam` (Task 1).
- Produces:

```swift
public struct LeagueStandingRules: Sendable, Equatable {
    public var marginPoints: Int                // 6
    public var marginPointsLastMatch: Int       // 3
    public var reachPointsPerMatch: Int         // 1
    public var topLevelInLastMatches: Int       // 10
    public var battlingInLastMatches: Int       // 10 (R1)
    public var battlingFactor: Double           // 1.2
    public var pointsForWin: Int                // 3
    public var pointsForDraw: Int               // 1
}
// EngineParameters.leagueStandingRules: Parameter<LeagueStandingRules>

public struct LeagueFormat: Equatable, Codable, Sendable {
    public var promoted, playOffs, relegated: Int
    public init(promoted: Int, playOffs: Int, relegated: Int)
    public var byes: Int { get }
    public func check(teams: Int?) throws                  // negatives always; the total against `teams` when given
    public func lines(teams: Int) throws -> [LeagueLine]   // checks, then promotion, bye, playOff, relegation; only those that exist
}
public enum LeagueFormatError: Error, Equatable {
    case negative(LeagueFormatField, Int)
    case tooMany(total: Int, teams: Int)
}
public enum LeagueFormatField: String, Sendable, CaseIterable { case promoted, playOffs, relegated }
public enum LeagueLineKind: String, Codable, CaseIterable, Sendable { case promotion, bye, playOff, relegation }
public struct LeagueLine: Equatable, Sendable { public let kind: LeagueLineKind; public let after: Int }

public enum LineState: Equatable, Sendable { case safe, outOfReach, close, withinReach, far }
public struct LineReading: Equatable, Sendable {
    public let line: LeagueLine
    public let isAbove: Bool          // the club's place is at or before `line.after`
    public let state: LineState
    public let gap: Int?              // nil when safe or out of reach
    public let other: LeagueTeam?     // above: the side in place after + 1; below: the side in place after; nil when safe
    public let otherPlace: Int?
}
public struct LeagueRival: Equatable, Sendable { public let name: String; public let pointsAhead: Int }  // negative: behind
public struct LeagueReading: Equatable, Sendable {
    public let club: String           // the table's spelling
    public let place, points, matchesLeft, mostReachable, margin: Int
    public let lines: [LineReading]
    public let situation: LeagueSituation?   // nil when matchesLeft is 0
    public let decidedBy: LineReading?       // the line behind a title-race or in-contention situation
    public let rivals: [LeagueRival]         // in table order
    public let basis: Evidence
    public var seasonIsOver: Bool { get }
}
public enum League {
    public static func read(table: LeagueTable, format: LeagueFormat, club: String,
                            parameters: EngineParameters) throws -> LeagueReading
}
```

- `read` throws `LeagueTableError.clubNotInTable`, `LeagueFormatError`, and `PlanError.badParameters` when `FitnessModel.problems(in:)` finds any.

- [ ] **Step 1: Write the failing tests** in `LeagueTests.swift`. Add a helper in the test file: `table(_ rows: [(String, played: Int, points: Int)]) -> LeagueTable`, rows in place order, wins `points / 3`, draws `points % 3`, losses the rest, no goals.

The format:

| Test | Expect |
|---|---|
| `byesAreTheNextPowerOfTwoLessTheCount` | play-offs 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 give byes 0, 0, 0, 1, 0, 3, 2, 1, 0, 7 |
| `theOwnersLeagueHasFourLines` | `LeagueFormat(1, 6, 4).lines(teams: 24)` is promotion after 1, bye after 3, playOff after 7, relegation after 20 |
| `aLineThatDoesNotExistIsLeftOut` | `(0, 4, 0).lines(teams: 24)` is playOff after 4 only; `(0, 0, 0)` is empty |
| `aFormatLargerThanTheTableIsRefused` | `(1, 6, 4).lines(teams: 10)` throws `.tooMany(total: 11, teams: 10)`; `(1, 6, 3)` on 10 teams does not |
| `aNegativeNumberIsRefused` | `(1, -1, 4)` throws `.negative(.playOffs, -1)` from `check(teams: nil)` and from `lines`; `(1, 30, 4).check(teams: nil)` does not throw |

The owner's table (`Fixtures.leagueTable`, format 1, 6, 4, club "Oxford City"), in `theOwnersTableReadsAsTheDesignSays`:

```swift
#expect(r.place == 5 && r.points == 74 && r.matchesLeft == 3 && r.mostReachable == 83 && r.margin == 6)
#expect(r.lines.map(\.state) == [.outOfReach, .close, .close, .safe])
#expect(r.lines.map(\.isAbove) == [false, false, true, true])
#expect(r.lines.map(\.gap) == [nil, 3, 6, nil])
#expect(r.lines.map { $0.other?.name } == ["Chester", "Spalding", "Morecambe", nil])
#expect(r.situation == .titleRaceOrRelegationFight)
#expect(r.decidedBy?.line.kind == .playOff)
#expect(r.rivals == [.init(name: "Spalding", pointsAhead: 3), .init(name: "Hednesford", pointsAhead: 1),
                     .init(name: "Buxton", pointsAhead: 0), .init(name: "Macclesfield", pointsAhead: -1),
                     .init(name: "Morecambe", pointsAhead: -6)])
#expect(r.basis == .derived)
```

Each rule, in a league of six (season 10, format 1, 2, 1: promotion after 1, play-off after 3, relegation after 5), the club "Me":

| Test | Table (name, played, points) | Expect |
|---|---|---|
| `aPlaceIsSafeWhenTooFewCanStillCatchHim` | A 9/20, B 9/16, Me 9/14, D 9/10, E 9/8, F 9/2 | play-off line `.safe` (D can reach 13) |
| `aSideThatCanOnlyDrawLevelCanStillCatchHim` | the same with D 9/11 | play-off line `.close`, gap 3, other D |
| `aLineIsOutOfReachWhenEnoughSidesAreBeyondHisMost` | A 9/20, Me 9/16, ... | promotion `.outOfReach` (his most is 19), other A |
| `levelWithHisMostIsNotOutOfReach` | A 9/19, Me 9/16, ... | promotion not `.outOfReach`; gap 3; `.close` |
| `theMarginIsThreeWithOneMatchLeft` | A 9/20, B 9/16, Me 9/14, D 8/10, E 9/8, F 9/2 (D has a match in hand, so can reach 16) | play-off line `.far`, gap 4 (over 3, and over 1 point for his 1 match); with D 8/11, `.close`, gap 3; `margin == 3` |
| `theMarginIsSixWithTwoMatchesLeft` | A 8/20, B 8/16, Me 8/14, D 8/8, E 8/5, F 8/2 | play-off line `.close`, gap 6, `margin == 6`; with D 7/7 (can reach 16), `.far`, gap 7 (over 6, and over 2) |
| `everythingSettledIsNothingToPlayFor` | every line safe or out of reach | `.nothingToPlayFor`, `decidedBy == nil` |
| `aSeasonThatIsOverHasNoSituationAndNobodyBattled` | Me on 10 played | `situation == nil`, `rivals == []`, `lines == []`, `seasonIsOver` |
| `noLinesIsNothingToPlayFor` | format 0, 0, 0 | `.nothingToPlayFor` |

In a league of 24 built with the helper (points chosen to give the gap; a line stays open only while enough sides can still reach his points, so give the side across the line a match in hand where the gap would otherwise settle it):

| Test | Expect |
|---|---|
| `aCloseLineIsTheTopSituationOnlyInTheLastTen` | play-off line close: 10 left is `.titleRaceOrRelegationFight`; 11 left is `.inContention` |
| `theByeLineAloneLiftsOnlyToInContention` | bye line close, the others far or settled, 3 left: `.inContention`, `decidedBy` the bye line |
| `aLineWithinAPointAMatchIsInContention` | nearest gap 9 with 9 left: `.withinReach`, `.inContention`; gap 10 with 9 left: `.far`, `.midTable` |
| `theNearestLineDecides` | promotion close at gap 5 and relegation close at gap 2: `decidedBy` relegation; equal gaps: the earlier line |
| `sidesWithinTheMarginAreBattledEitherWay` | 3 left: sides 6 ahead and 6 behind are in, 7 ahead and 7 behind are out |
| `withOneMatchLeftOnlySidesWithinThreeAreBattled` | 1 left: 3 behind in, 4 behind out |
| `nobodyIsBattledBeforeTheLastTen` (R1) | 11 left, a side level on points: `rivals == []`; 10 left: that side is in |
| `atTheStartOfTheSeasonNobodyIsBattledAndTheSituationIsInContention` (R1) | 24 teams on 0 played, 0 points: `.inContention`, `rivals == []` |
| `aClubNotInTheTableIsRefused` | club "Nobody": `.clubNotInTable(club: "Nobody", teams: 24)` |
| `aFormatThatDoesNotFitTheTableIsRefused` | format 1, 6, 4 on a table of 10: `.tooMany(total: 11, teams: 10)` |

Parameters: `EngineParametersTests` asserts the eight values, `.derived`, and that the source names the owner's rule of 19 November 2026, "this tool's estimate" and the old app's table; `FitnessModelTests` asserts a problem for a negative margin, a last-match margin over the margin, a factor that is not a finite number above 0, and points for a win not over points for a draw; `EvidenceTests` asserts `Parameter<LeagueStandingRules>` is one pointer wide (the existing size test on `EngineParameters` must still pass).

- [ ] **Step 2: Run them to see them fail.** Run: `cd LineupEngine && swift test --filter LeagueTests` Expected: does not build.

- [ ] **Step 3: Implement.** The rules, exactly as the spec's "Where the owner stands" gives them, with *p* his points, *m* his matches left, a team's most as its points plus `pointsForWin` for each match it has left:
  - margin: `marginPointsLastMatch` when *m* is 1, else `marginPoints`;
  - above a line after *k*: safe when the other teams whose most is *p* or more number fewer than *k*; else gap = *p* − points of the side in place *k* + 1;
  - below: out of reach when the other teams with more points than his most number at least *k*; else gap = points of the side in place *k* − *p*;
  - close when gap ≤ margin; within reach when gap ≤ `reachPointsPerMatch` × *m*; else far;
  - situation, the first that holds: no lines or every line settled, nothing to play for; promotion, play-off or relegation close and *m* ≤ `topLevelInLastMatches`, title race or relegation fight; any line close or within reach, in contention; else mid-table;
  - `decidedBy`: for the top situation, the close line among promotion, play-off and relegation with the smallest gap; for in contention, the close line with the smallest gap, or with none close the line within reach with the smallest gap; ties to the earlier line; nil otherwise;
  - rivals: with *m* from 1 to `battlingInLastMatches`, every other team whose points are within the margin of *p*, in table order; otherwise none;
  - `basis`: the evidence of `leagueStandingRules`.
  One entry, `leagueStandingRules`, labelled `.derived` (the weakest of its numbers), whose source says which number rests on what: the margin and its last-match value on the owner's rule of 19 November 2026; one point a match and the factor on this tool's estimate with no test; the last ten matches carried over from the old app's table (`scoring_parameters.py`), used for both the top situation and, by this plan's R1, the sides he is battling; three points a win and one a draw as the game's rule. `LeagueTableImporter` takes its two numbers from it.

- [ ] **Step 4: The sentences for `LeagueFormatError`** in `ErrorDescriptions`: "The play-offs cannot have −1 teams." / "1 promoted, 6 in the play-offs and 4 relegated make 11, more than the 10 teams in the table." One test each.

- [ ] **Step 5: Run the engine's tests.** Run: `cd LineupEngine && swift test` Expected: all pass, no warnings.

- [ ] **Step 6: Commit** the files this task names.

---

### Task 3: The words, and the table in the suggested importance

**Files:**
- Create: `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText+League.swift`
- Create also: `LineupEngine/Tests/LineupEngineTests/Fixtures/captures/first-team-and-league.grids.json`
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/League.swift`, `Advisors/ImportanceSuggestion.swift`, `LineupEngine/Sources/lineup-cli/main.swift`, and, to compile only, `LineupApp/Sources/LineupAppCore/AppModel+Advice.swift`
- Test: `LineupEngine/Tests/LineupEngineTests/LeagueTextTests.swift`, `ImportanceSuggestionTests.swift`, `LeagueTests.swift`

**Interfaces:**
- Consumes: Task 2's types.
- Produces:

```swift
public struct LeagueContext: Equatable, Sendable {
    public let reading: LeagueReading
    public let speaksFor: Set<FixtureID>
    public init(reading: LeagueReading, speaksFor: Set<FixtureID>)
}
extension League {
    /// The ids of the first `matchesLeft` league fixtures, in date order then id, among those dated after `pastedOn`
    /// and those on it with no lineup confirmed.
    public static func spokenFor(matchesLeft: Int, pastedOn: Day,
                                 leagueFixtures: [(id: FixtureID, date: Day, isConfirmed: Bool)]) -> Set<FixtureID>
}
// ImportanceAdvisor.suggest(for:among:confirmed:players:tiers:situation: LeagueSituation?, league: LeagueContext?, parameters:)
//   `situation` is the owner's choice by hand, nil when he has made none.

extension AdvisorText {
    public static func name(_ kind: LeagueLineKind) -> String            // "promoted", "bye", "play-offs", "relegated"
    public static func byeLine(_ format: LeagueFormat) -> String?        // "2nd and 3rd get a bye."; nil with no byes
    public static func standingLines(_ reading: LeagueReading) -> [String]
    public static func leagueBaseReason(_ reading: LeagueReading) -> String   // without the ": 100"
    public static func battlingReason(_ rival: LeagueRival, factor: Double) -> String
    public static func tablePastedLine(on day: Day) -> String            // "Table pasted on Sat 18 Apr."
    public static let tableOutOfDate: String
    public static func tableStopsLine(matchesLeft: Int, beyond: Int) -> String
    public static func handChoiceLine(byHand: LeagueSituation, table: LeagueSituation) -> String
    public static func notInTheTable(_ opponent: String) -> String       // "Buxton FC is not in the league table."
    public static let orderWorkedOutLine: String
    public static let noFormatLine: String
    public static let noTableLines: [String]
    public static func fromTheTable(_ situation: LeagueSituation?) -> String  // "From the table (In contention)"; "From the table" with nil
    public static func leagueEvidenceNote(_ reading: LeagueReading) -> String
}
```

- [ ] **Step 1: Write the failing text tests** in `LeagueTextTests.swift`. For the owner's table, `standingLines` is exactly:

```
You are 5th on 74 points with 3 matches left.
Automatic promotion is out of reach: Chester have 87 points and the most you can reach is 83.
A bye in the play-offs is 3 points away: Spalding, in 3rd, have 77.
Your play-off place is not safe: Morecambe, in 8th, are 6 points behind you.
You cannot be relegated.
League matches read as Title race or relegation fight: your play-off place is within 6 points with 3 matches left (this tool's estimate).
Within 6 points of you: Spalding, Hednesford, Buxton, Macclesfield and Morecambe.
```

  Then one test for each case of each line, the builder writing each sentence to these models. Every line kind has a sentence for each of: above and safe ("You cannot be relegated." / "Your play-off place is safe." / "Your bye is safe." / "Promotion is certain."); above and open, with the gap and the side below named ("... is not safe: ..." when close, "Morecambe, in 8th, are 12 points behind your play-off place." when within reach or far); below and out of reach, with the side in the last place above and his most; below and open, with the gap and the side named ("... is 3 points away: ..."). The situation line names the situation, what decided it and "(this tool's estimate)"; for mid-table "nothing is within reach", for nothing to play for "nothing can change for you" with no estimate label, since that is arithmetic. With no rivals the last line is left out. With the season over the lines are the place and points, and "The season in this table is over. Paste the new season's table when it starts." "1 point" and "1 match" are singular; a side level on points is "level on points with you". `leagueBaseReason` on the owner's table is "League match, your play-off place is within 6 points"; the phrases by line are "your promotion place", "your bye", "your play-off place" and "the drop" when he is above, and "automatic promotion", "a bye", "a play-off place" and "safety" when below; within reach it is "League match, a play-off place is 9 points away with 9 matches left"; mid-table "League match, nothing within reach"; nothing to play for "League match, nothing left to settle". `battlingReason` gives "Buxton are level on points with you (×1.2)", "Spalding are 3 points ahead of you (×1.2)", "Morecambe are 6 points behind you (×1.2)". `tableStopsLine(matchesLeft: 3, beyond: 2)` is "The table has 3 matches left, so it is used for your next 3 league fixtures; the 2 after them are read without it." `tableOutOfDate` is "A league match has been played since; paste the table again."

- [ ] **Step 2: Write the failing rule tests.**

`LeagueTests`, `spokenFor`:

| Test | Expect |
|---|---|
| `aTableSpeaksForAsManyFixturesAsItHasMatchesLeft` | 3 left, five league fixtures after the day: the first three by date |
| `aFixtureOnTheDayCountsUnlessItWasConfirmed` | one on the day unconfirmed is in; confirmed is out and does not use up a match |
| `aConfirmedFixtureAfterTheDayUsesUpAMatch` | 3 left, the first after the day confirmed: it and the next two are in |
| `fixturesBeforeTheDayAreNeverSpokenFor` | none |
| `noMatchesLeftSpeaksForNothing` | empty |

`ImportanceSuggestionTests` (the existing `suggest` helper gains `league: LeagueContext? = nil`, and its `situation` becomes optional with the default `nil`; every existing test must pass unchanged where it passes `.inContention` or nothing). Use the owner's reading, and a fixture against "Rovers" unless said:

| Test | Expect |
|---|---|
| `withNoChoiceByHandACoveredLeagueFixtureTakesTheTablesSituation` | score 100; first reason "League match, your play-off place is within 6 points: 100" |
| `aChoiceByHandWinsOverTheTable` | `situation: .midTable`: score 60, first reason "League match, mid-table: 60" |
| `aFixtureTheTableDoesNotSpeakForIsReadWithoutIt` | not in `speaksFor`: score 80, "League match: 80", no battling reason even against Buxton |
| `aSideHeIsBattlingRaisesTheMatch` | opponent "Buxton", strength similar: score 120; reasons hold "Buxton are level on points with you (×1.2)" after the base and any opponent reason |
| `aSideOutsideTheMarginDoesNotRaiseIt` | opponent "Chester": score 100, no such reason |
| `theFactorAppliesUnderAChoiceByHandToo` | `situation: .inContention`, opponent "Buxton": score 96, `.high` |
| `theFactorMatchesNamesAsTheSquadBookDoesAndOnlyInTheLeague` | two covered league fixtures against " buxton": both 120; a cup fixture against "Buxton": 60 |
| `aBiggerMatchIsMeasuredWithTheFactorIn` | under `situation: .inContention`, this fixture against Rovers (80) and the next, two days on, against Buxton (96): this one takes "A bigger match follows in 2 days (×0.6)"; with the next against Chester (80) it does not |
| `aTableWhoseSeasonIsOverChangesNothing` | a reading with the season over and an empty `speaksFor`: the same suggestion as `league: nil` |
| `theBasisIsTheWeakerOfTheTwoRuleSets` | with the league used, `.derived`; with `league: nil`, as today |

- [ ] **Step 3: Run them to see them fail.** Run: `cd LineupEngine && swift test --filter "LeagueTextTests|ImportanceSuggestionTests|LeagueTests"` Expected: does not build.

- [ ] **Step 4: Implement.** In `suggest`, one private function gives a fixture's size (base times opponent factor times battling factor) and its reasons, and is used for this fixture and for the next one in the "bigger match follows" rule. A league fixture's situation is the choice by hand; else, when `league` speaks for it and its reading has a situation, the table's, with `leagueBaseReason` as the reason; else in contention. The battling factor applies to a league fixture the table speaks for whose opponent, by `PlayerID.normalise`, is one of the reading's rivals. Update the two callers in `LineupApp` only as far as compiling (`situation: settings.situation, league: nil`); Task 5 does the rest.

- [ ] **Step 5: The command line.** `advise` takes `--league-table <paste.tsv>` (read with `--grids`) and `--league-format <promoted>,<play-offs>,<relegated>`; one without the other is a usage error. With them `advise` prints a "League" part before the fixtures (the `standingLines`, the paste's warnings, the evidence note) and hands the suggestion a context whose `speaksFor` comes from `spokenFor` with `--as-of` as the day and the confirmed fixtures from `--history`. `--league-situation`, when given, is the choice by hand; when not given it is now nil, which without a table reads as in contention as before. Add both to the usage at the top of `main.swift`. Check by hand:

`--grids` must then hold both layouts, so write `Tests/LineupEngineTests/Fixtures/captures/first-team-and-league.grids.json`: the items of `first-team.grids.json` and of `league-table.grids.json` in one file.

Run: `cd LineupEngine && swift run -q lineup-cli advise --grids Tests/LineupEngineTests/Fixtures/captures/first-team-and-league.grids.json --tactic Tests/LineupEngineTests/Fixtures/tactics/sample-4231.json --first-team Tests/LineupEngineTests/Fixtures/captures/first-team.tsv --u21 Tests/LineupEngineTests/Fixtures/captures/u21.tsv --own-club "Oxford City" --fixtures Tests/LineupEngineTests/Fixtures/plans/sample-fixtures-with-competitions.json --history Tests/LineupEngineTests/Fixtures/plans/sample-history.json --as-of 2026-11-13 --league-table Tests/LineupEngineTests/Fixtures/captures/league-table.tsv --league-format 1,6,4`
Expected: the League part prints the seven lines above, and the first three league fixtures' suggestions start from 100. With `first-team.grids.json` in its place, it ends with the sentence for `.noStandingsGrid`.

- [ ] **Step 6: Run both packages' tests.** Run: `cd LineupEngine && swift test`, then `cd LineupApp && swift build && swift test` Expected: all pass, no warnings.

- [ ] **Step 7: Commit** the files this task names (the two app files touched to compile included).

---

### Task 4: The league in the app's state

**Files:**
- Create: `LineupApp/Sources/LineupAppCore/LeagueState.swift`, `AppModel+League.swift`
- Modify: `Store.swift`, `AppModel.swift`, `AppModel+Advice.swift`, `AppModel+Fixtures.swift`, `LineupApp/Tests/LineupAppCoreTests/Support/TestModel.swift`
- Test: `LineupApp/Tests/LineupAppCoreTests/LeagueTests.swift`, `StoreTests.swift`

**Interfaces:**
- Consumes: Tasks 1 to 3.
- Produces:

```swift
public struct LeagueState: Equatable, Codable, Sendable {
    public var format: LeagueFormat?
    public var table: LeagueTable?
    public var pastedOn: Day?
    public init()
}
public enum LeagueReadingState: Equatable, Sendable {
    case noTable, noFormat
    case read(LeagueReading)
    case failed(String)            // the engine's sentence
}
public struct LeagueFormatDraft: Equatable, Sendable { public var promoted, playOffs, relegated: Int? }
// StoreFile.league: "your league table", "the league starts with no table", "league table"; no notice when absent

extension AppModel {
    public internal(set) var league: LeagueState                // declared in AppModel.swift
    public internal(set) var leaguePasteProblem: String?        // not saved
    public internal(set) var leagueFormatDraft: LeagueFormatDraft   // not saved; starts from the saved format
    public internal(set) var leagueFormatProblem: String?       // not saved
    public func pasteLeagueTable()
    public func removeLeagueTable()
    public func setLeagueFormatDraft(_ draft: LeagueFormatDraft)
    public var leagueReading: LeagueReadingState { get }
    var leagueContext: LeagueContext? { get }
    public var leagueTableIsOutOfDate: Bool { get }
    public var leagueFixturesBeyondTheTable: Int { get }
    public func setLeagueSituation(_ situation: LeagueSituation?)   // nil: from the table
    public var leagueSituationChoices: [(value: LeagueSituation?, title: String)] { get }
    public var leagueSituationSelection: LeagueSituation? { get }   // nil: the menu is on "From the table"
}
// TestModel: Captures.leagueTable, Captures.leagueTableGrids; func pasteLeagueTable(_ paste: String? = nil) sets the
// scripted clipboard and settings file and calls model.pasteLeagueTable()
```

- [ ] **Step 1: Write the failing tests** in `LeagueTests.swift` (app). The model has the first team imported, so the club is Oxford City, and league fixtures added where a test needs them:

| Test | Expect |
|---|---|
| `aPasteIsKeptWithItsDayAndSaved` | `league.table` has 24 teams, `pastedOn` is today in the game; a reopened model holds the same |
| `aPasteDoesNotPlanAndClearsTheSuggestions` | `timesPlanned` unchanged; the fixtures' chosen importances unchanged; the kept suggestions are worked out again when next read |
| `aRefusedPasteKeepsTheTableHeld` | after a good paste, a squad paste: `leaguePasteProblem` is the engine's sentence, `league.table` unchanged; the next good paste clears the problem |
| `anEmptyClipboardOrMissingSettingsFileIsRefusedInASentence` | as the squad import's sentences |
| `theFormatIsSavedOnlyWhenAllThreeAreEnteredAndFit` | two of three entered: `league.format == nil`, no problem; all three (1, 6, 4): saved; then (1, 30, 4): `leagueFormatProblem` is the engine's sentence and the format stays 1, 6, 4 |
| `theReadingNeedsATableAndAFormat` | `.noTable`; after a paste `.noFormat`; after the format `.read` with place 5 |
| `theFirstReadingSwitchesTheMenuToTheTable` | `settings.leagueSituation = .midTable`, then paste and format: it is nil, and saved |
| `aPasteBeforeTheFormatLeavesAChoiceByHand` | choice by hand, paste only: still the choice; a league fixture's suggestion is still the hand's |
| `aLaterPasteOrFormatChangeLeavesTheMenuAlone` | reading held, choose `.midTable` by hand, paste again, change the format to 1, 4, 4: still `.midTable` |
| `removingTheTableKeepsTheFormatAndTheChoice` | `league.table == nil`, `league.format` kept, the choice by hand kept; a paste after it switches the menu to the table again |
| `theSuggestionsUseTheTable` | three league fixtures after today, against Buxton, Chester and Rovers: suggestions' first reasons are the table's, scores 120, 100 and 100 before schedule rules (pick dates a week apart and assert the reasons, not the final score) |
| `fixturesBeyondTheMatchesLeftAreReadWithoutIt` | five league fixtures: the fourth and fifth start "League match: 80"; `leagueFixturesBeyondTheTable == 2` |
| `theDraftsSuggestionUsesTheTableToo` | `suggestionNote(for:)` on a new league draft against Buxton dated tomorrow carries the battling reason |
| `theTableIsOutOfDateOnceALeagueMatchIsConfirmedAfterIt` | false after the paste; move today on, confirm a league fixture dated after `pastedOn`: true; a confirmed cup fixture: false |
| `aClubNoLongerInTheTableStopsTheReadingAndSaysSo` | set the club override to "Banbury United": `.failed` with the engine's sentence, `leagueContext == nil`, suggestions start "League match: 80"; clear the override: `.read` again |
| `aTableTheFormatDoesNotFitIsKeptAndSaysSo` | format 1, 6, 4, then paste a table of 10 that has the club: `league.table` has 10 teams, the reading is `.failed` with the sentence for `.tooMany`, `leagueContext == nil` |
| `anOlderStateOpensWithNoNoticeAndTheSameSuggestions` | a store with no league file: no notice, `.noTable`, suggestions as before this plan |
| `StoreTests.anUnreadableLeagueFileIsKeptAsideWithANotice` | the usual notice, a fresh `LeagueState` |

- [ ] **Step 2: Run them to see them fail.** Run: `cd LineupApp && swift test --filter LeagueTests` Expected: does not build.

- [ ] **Step 3: Implement.**
  - `StoreFile.league`, loaded in the model's `init` like `.marks` (absent is no notice), saved in `save(_:)`.
  - `setLeagueFormatDraft` keeps the draft; with all three entered it calls `check(teams:)` with the held table's count (nil with no table) and saves the format when it passes, or sets `leagueFormatProblem` and keeps the saved format when it does not.
  - `pasteLeagueTable` reads through `readClipboardAndConfig()` and `LeagueTableImporter.read` with `ownClub` and `planParameters`; on success sets the table and `pastedOn` to `settings.currentDate`, clears the problem, saves `.league`; on failure sets `leaguePasteProblem` and changes nothing else.
  - One private function, `leagueChanged(hadReading:)`, ends `pasteLeagueTable`, `removeLeagueTable` and a saved format: when there was no `.read` before and there is one now, it sets `settings.leagueSituation = nil` and saves the settings; in every case it sets `adviceCache?.suggestions = nil`. It never calls `replan()`.
  - `leagueReading` is worked out from the state each time it is read (24 rows; no cache): `.failed` carries `ErrorDescriptions.describe` of what `League.read` threw.
  - `leagueContext` is nil unless the reading is `.read`; its `speaksFor` is `League.spokenFor` over the stored fixtures whose competition is league, with `isConfirmed` from the history.
  - `leagueTableIsOutOfDate`: a stored league fixture with a confirmed lineup is dated after `pastedOn`. `leagueFixturesBeyondTheTable`: the stored league fixtures with no confirmed lineup, dated on or after `pastedOn`, that the context does not speak for; 0 with no context.
  - `workedOutSuggestions` and `suggestionNote(for:)` pass `situation: settings.leagueSituation` (the choice by hand, now optional) and `league: leagueContext`. For a draft not saved yet, the context is worked out with the draft among the league fixtures, under the draft's id.
  - `setLeagueSituation(nil)` is accepted only while the reading is `.read`. `AppModel.leagueSituationChoices` becomes an instance property: with a reading, a first entry `(nil, AdvisorText.fromTheTable(reading.situation))`, then the four; without, the four as today. `leagueSituationSelection` is `settings.leagueSituation` with a reading (nil is "From the table"), and `settings.situation` without one.
  - `update(_ settings:)`: a change of `clubOverride` also clears the kept suggestions (the reading depends on the club).
  - `TestModel`: the captures and `pasteLeagueTable`.

- [ ] **Step 4: Run the app's tests.** Run: `cd LineupApp && swift build && swift test` Expected: all pass, no warnings.

- [ ] **Step 5: Commit** the files this task names.

---

### Task 5: What the League screen and the editor show

**Files:**
- Create: `LineupApp/Sources/LineupAppCore/LeaguePresentation.swift`
- Modify: `FixturePresentation.swift`, `Screen.swift`, `SampleData.swift`
- Test: `LineupApp/Tests/LineupAppCoreTests/LeaguePresentationTests.swift`, `FixturePresentationTests.swift`, `ScreenTests.swift`

**Interfaces:**
- Consumes: Task 4.
- Produces:

```swift
// Screen.league, after .fixtures; title and pillTitle "League"
public struct LeagueRow: Identifiable, Equatable, Sendable {
    public let id: Int                 // the place
    public let place, team, played, won, drawn, lost, goalsFor, goalsAgainst, goalDifference, points: String
    public let isOwn, isBattled: Bool
    public let lineBelow: String?      // the engine's name of the line drawn under this row
}
public struct LeagueScreenContent: Equatable, Sendable {
    public let byeLine: String?
    public let pastedLine: String?
    public let cautions: [String]          // out of date; the paste's warnings; the order worked out; the table stops
    public let pasteProblem: String?
    public let formatProblem: String?
    public let handChoiceLine: String?     // with useTheTableTitle beside it
    public let sentences: [String]         // the reading, or the one line saying why there is none
    public let evidenceNote: String?
    public let fixturesNotInTheTable: [String]   // "Buxton FC on Sat 25 Apr"
    public let rows: [LeagueRow]
    public let emptyLines: [String]        // shown with no table
    public let offersRemove: Bool
}
extension AppModel { public var leagueScreen: LeagueScreenContent { get } }
// static labels: pasteTableTitle "Paste table", removeTableTitle "Remove table", useTheTableTitle "Use the table",
// promotedLabel "Promoted automatically", playOffsLabel "In the play-offs", relegatedLabel "Relegated",
// column headings "Pl", "W", "D", "L", "F", "A", "GD", "Pts", notInTableHeading "League fixtures against sides not in the table"

extension FixtureDraft {
    public var leagueTeams: [String]                 // the model fills it in, as it fills `otherMatches`
    public var opponentMenu: [String]?               // nil: show the text box
    public var opponentInTable: String?              // the table's spelling of the draft's opponent, when it matches
    public var opponentNotInTableText: String?       // the engine's caution, when it matches none and is not blank
    public mutating func pick(opponent team: String)
}
// SampleData.modelWithLeague(repositoryRoot:) and its variants for Task 6's pictures
```

- [ ] **Step 1: Write the failing tests.**

`LeaguePresentationTests`:

| Test | Expect |
|---|---|
| `theOwnersTableHasItsLinesAndMarks` | 24 rows; `rows[4].isOwn`; `isBattled` on places 3, 4, 6, 7 and 8 only; `lineBelow` is "promoted" on place 1, "bye" on 3, "play-offs" on 7, "relegated" on 20, nil elsewhere; `rows[0].goalDifference == "+32"`, a negative one "−29" with a true minus, zero "0" |
| `theSentencesAreTheEngines` | `sentences == AdvisorText.standingLines(reading)`; the evidence note is the engine's; `byeLine == "2nd and 3rd get a bye."` |
| `withNoTableThereAreOnlyTheEmptyLines` | `rows` empty, `emptyLines == AdvisorText.noTableLines`, `offersRemove == false` |
| `withATableAndNoFormatTheRowsHaveNoLines` | every `lineBelow` nil, no mark, `sentences == [AdvisorText.noFormatLine]` |
| `aFailedReadingShowsItsSentenceAndThePlainTable` | `sentences` is the one failure sentence; rows with no lines or marks |
| `theCautionsComeInOrder` | out of date, then the paste's warning, then the table stops |
| `aChoiceByHandThatDiffersIsSaidWithTheTables` | choice `.midTable`, table title race: `handChoiceLine == AdvisorText.handChoiceLine(...)`; nil when they agree or the menu is on the table |
| `leagueFixturesAgainstSidesNotInTheTableAreNamed` | a league fixture against "Buxton FC" on a date after today is listed as opponent and date; one against "buxton" is not; a confirmed one, a past one and a cup one are not |

`FixturePresentationTests`:

| Test | Expect |
|---|---|
| `aLeagueDraftOffersTheTablesTeamsWithoutTheClub` | competition league, table held: `opponentMenu` is the 23 other teams in alphabetical order ("AFC Telford" first), no "Oxford City" |
| `anyOtherCompetitionOrNoTableKeepsTheTextBox` | `opponentMenu == nil` for cup, for nil, and for league with no table; the opponent's text is kept across a change of competition |
| `aSavedOpponentThatMatchesShowsInTheTablesSpelling` | opponent " buxton": `opponentInTable == "Buxton"`, no caution |
| `oneThatMatchesNoneIsKeptWithACaution` | opponent "Buxton FC": `opponentInTable == nil`, `opponentNotInTableText == AdvisorText.notInTheTable("Buxton FC")`; a blank opponent has no caution; after `pick(opponent: "Buxton")` the opponent is "Buxton" and the caution is gone |
| `savingKeepsTheSpellingPicked` | the saved fixture's opponent is "Buxton" |

`ScreenTests`: `.league` comes straight after `.fixtures`, and every screen still has a title.

- [ ] **Step 2: Run them to see them fail.** Run: `cd LineupApp && swift test --filter "LeaguePresentationTests|FixturePresentationTests|ScreenTests"` Expected: does not build.

- [ ] **Step 3: Implement.** Adding `Screen.league` makes every `switch` over `Screen` fail to build; give each its case (in `RootView` a placeholder `EmptyView()` until Task 6). `newFixtureDraft()` and `fixtureDraft(for:)` fill `leagueTeams` from the table held. `SampleData.modelWithLeague` is the sample model with the league capture pasted through a scripted clipboard, the format 1, 6, 4, and three league fixtures after today against Buxton, Chester and "Buxton FC".

- [ ] **Step 4: Run the app's tests.** Run: `cd LineupApp && swift build && swift test` Expected: all pass, no warnings.

- [ ] **Step 5: Commit** the files this task names.

---

### Task 6: The screens

**Files:**
- Create: `LineupApp/Sources/LineupAppUI/League/LeagueScreen.swift`
- Modify: `LineupAppUI/RootView.swift`, `Fixtures/FixturesScreen.swift`, `Fixtures/FixtureEditor.swift`, `Theme.swift` (new measures only), `ScreenPictures.swift`, `LineupApp/Sources/LineupApp/main.swift` (the picture run), `LineupAppCore/SampleData.swift` (variants the pictures need)

**Interfaces:**
- Consumes: Tasks 4 and 5. No new logic: if a view needs an `if` about data, put it in Core with a test.

- [ ] **Step 1: The League screen**, to the spec's sketch and the look of the Fixtures screen. From the top: the heading with `pasteTableTitle`; the three numbers as whole-number fields bound through `model.leagueFormatDraft` and `model.setLeagueFormatDraft`, with `byeLine` under them and `formatProblem` in the style the editor's problem uses; `pastedLine` with `removeTableTitle` beside it when `offersRemove`; the cautions and `pasteProblem` as cautions are drawn on the Training cards; `handChoiceLine` with a `useTheTableTitle` button calling `model.setLeagueSituation(nil)`; the sentences; the evidence note as the other screens draw theirs; the fixtures not in the table under their heading; then the table, its numbers right-aligned in the body face (no condensed numerals), a rule with the line's name at its trailing end under each row that has `lineBelow`, the club's row in the accent the Fixtures table uses for the next match, and a small mark on the rows that are `isBattled`. With no table, the empty state the other screens use, with `emptyLines`. "Remove table" asks first, as deleting a fixture does.

- [ ] **Step 2: Fixtures.** The League situation menu takes `model.leagueSituationChoices` (now optional values) and calls `model.setLeagueSituation`. In the editor, where `draft.opponentMenu` is not nil, a menu in place of the opponent's text box: its entries the teams, its current entry `draft.opponentInTable`, or the typed name when that is nil; picking calls `draft.pick(opponent:)`; `draft.opponentNotInTableText` under it as the paste's refusal is drawn.

- [ ] **Step 3: The pictures.** Add to the picture run, in light and dark: `league` (the owner's table with the format), `league-empty`, `league-noformat`, `league-refused` (a squad paste after a good one), `league-stale` (a league match confirmed since, and five league fixtures so the table stops), `league-byhand` (a choice by hand that differs), `league-small` (the smallest window), `fixtures-fromtable` (Fixtures with the menu on "From the table" and the three league suggestions), `fixtures-editor-league` (the editor with the opponent menu) and `fixtures-editor-league-unmatched` ("Buxton FC").

Run: `cd LineupApp && swift run -q LineupApp --sample-data .. --pictures .build/pictures-league`
Expected: the run ends with no error and writes the new files.

- [ ] **Step 4: Look at the pictures.** Open each new picture, and `fixtures-*`, `fixtures-small-*` and `fixtures-editor-*` again. Check: eleven pills fit the top row in the smallest window without clipping (shorten a `pillTitle` in Core if not, with its test); the table's columns line up and the rules do not collide with the rows; the long situation sentence wraps; the menu's "From the table (Title race or relegation fight)" does not push the heading row out; the opponent menu is as wide as the text box was; nothing is clipped in dark. Put right what is wrong and draw again. A screen is not done until its pictures have been looked at.

- [ ] **Step 5: Run the app's tests.** Run: `cd LineupApp && swift build && swift test` Expected: all pass, no warnings.

- [ ] **Step 6: Commit** the files this task names, saying in the message which directory the pictures were checked in.

---

### Task 7: The whole thing on the sample data

**Files:**
- Test: `LineupApp/Tests/LineupAppCoreTests/EndToEndTests.swift`, `LineupEngine/Tests/LineupEngineTests/EndToEndTests.swift`

- [ ] **Step 1: Write one test in each package** that goes the whole way. Engine, `theOwnersTableReachesTheSuggestion`: the capture through `LeagueTableImporter.read`, `League.read` with 1, 6, 4, a context from `spokenFor`, and `ImportanceAdvisor.suggest` for a league fixture against Buxton: `.high`, with the base reason and the battling reason. App, `aSeasonsEndWithTheTable`: import the first team, add three league fixtures and a cup fixture, paste the table, enter the format; assert the menu reads "From the table (Title race or relegation fight)", the suggestions, "Use it" on the Buxton fixture sets it High and plans once; confirm that fixture, move today past it: the table is out of date and still used; paste again: not out of date; remove the table: suggestions start "League match: 80" again.

- [ ] **Step 2: Run both packages' tests.** Run: `cd LineupEngine && swift test`, then `cd LineupApp && swift build && swift test` Expected: all pass, no warnings. Put right whatever these find in the task that owns the code.

- [ ] **Step 3: Commit.**

---

### Task 8: Documents and the last check

**Files:**
- Modify: `CLAUDE.md`, this plan, `docs/superpowers/specs/2026-11-19-fm27-league-table-design.md`

- [ ] **Step 1: CLAUDE.md.** Add the plan and the design to the list under "What this project is". In the engine's part: the reader under **Import** (the standings grid's layout, the checks, the warning), and under **Advisors**, beside `ImportanceAdvisor`, the format, the byes, the lines, the states, the situation's table, the sides he is battling, which fixtures a table speaks for, and what is the owner's rule, carried over or this tool's estimate. Add `--league-table` and `--league-format` to the `advise` paragraph. In the app's part: the League screen, the menu's "From the table" and when it switches, the opponent menu, the league file, and the pictures' directory and names. Under "Data and privacy", widen the sentence on what is taken from `~/Library/Application Support` to FMRTE's column layouts for the player grids and the standings grid. Under "Tools", the capture tool's line.

- [ ] **Step 2: The design.** It already carries R1. Mark as "revised" anything else the build changed, as the earlier designs do.

- [ ] **Step 3: This plan's closing sections,** as the earlier plans have them: "Changes made while building", "Known limits and small faults left" (at least: the two settled tests ignore that the other sides play each other; matches in hand are not counted; an old table is used until replaced; the fixture was rebuilt, not captured) and "For the owner" (install with `tools/build_app.sh`; paste a real table and check it reads as the rebuilt one did; enter the three numbers; read the League screen against the game's own table).

- [ ] **Step 4: The last check.** Run: `cd LineupEngine && swift test`, `cd LineupApp && swift build && swift test`, and the picture run of Task 6. Expected: all pass, no warnings, the pictures drawn.

- [ ] **Step 5: Commit.**

---

## Changes made while building

1. **A blank team name is refused.** The first reader took a row with no name as a team. It is now refused in a sentence of its own, "A row of the table has no team name.", since there is no team to name. The design was revised.
2. **A line with no side across it is left out.** When promotion and the play-offs fill the table and nobody is relegated, the play-off line would lie after the last team, and reading it would look for a side below it that does not exist. Such a line is dropped. The design was revised.
3. **The sentence refusing three numbers too large for the table names all three**: "1 promoted, 6 in the play-offs and 4 relegated make 11, more than the 10 teams in the table." The plan's error carried only their total, so the sentence could not say which numbers the owner had entered. A negative number ("The play-offs cannot have −1 teams.") and a negative goal difference on the League screen ("−29") are written with a true minus.
4. **A table that the numbers or the club's name no longer fit is kept, and says why.** The design checked the numbers only as they were typed and the club only at the paste. A smaller league pasted over the three numbers, or a change of the club's name in Settings, now keeps the table, puts the engine's sentence in place of the reading, and leaves every suggestion as with no table until they fit again. This was the plan's (its review points 3 and 4); the design was revised to match.
5. **"From the table" is in the menu only while the table gives a reading**, not whenever a table and three numbers are held, so the menu follows what the League screen shows. The design was revised.
6. **A problem shown under the three numbers is cleared by a paste or a removal of the table.** It was found against the table that was held; a saved format that no longer fits a new table shows through the reading's own sentence instead.
7. **The club's own row is drawn in marker blue, bold, on a faint tint.** The plan asked for the accent the Fixtures table gives the next match, which does not exist.
8. **The command line's League part also prints the bye line, and a note when the order of the table was worked out**, besides the reading's sentences, the paste's warnings and the evidence note.
9. **The base reason when the table sets a match's situation is the table's phrase and its score**, "League match, your play-off place is within 6 points: 100"; the plan's end-to-end step named only the phrase. The end-to-end tests check the whole reason.
10. **The capture tool's `--list-grids` was run only against the rebuilt fixture's layout**, never FMRTE's own settings file, since nothing in this build reads `~/Library/Application Support`. Whether it finds the standings grid in the real file is the owner's to see.
11. **The last check moved.** This task changes documents only. Both packages' tests passed on the last code of the build at the end of Task 7 (the engine's 1,422, the app's 862, no warnings), and the pictures were drawn on the same views in Task 6. The whole-branch review follows, and both suites and the picture run are run after its fixes.

After the whole-branch review the design was revised on 20 November 2026 (its passages marked "revised during the build, 20 November 2026") and built in one round of fixes:

12. **A format with every team relegated no longer stops the app.** With 0 promoted, 0 in the play-offs and as many relegated as there are teams, the relegation line lay before the first place and reading it looked for the side above place 1; the app saved the format before reading it, so it stopped again at every start. A line nobody is above is now dropped, as one nobody is below already was, and a test reads every format the check accepts on a table of six, from every place.
13. **A club on negative points can be pasted.** The points column, and only it, takes one leading minus (a hyphen or a true minus); every other number is still digits only. Such a club carries the warning that its points do not fit its results, and is placed like any other. Points below zero are written with a true minus in the engine's sentences, the warning and the League table.
14. **A club in mid-table far clear of a line is told what he holds.** A leader 7 points clear with 5 matches left is neither close nor within reach, so he reads as Mid-table by the design's table, and was told "nothing is within reach". The words now name the highest line he is far above: "League matches read as Mid-table: your promotion place is 7 points clear with 5 matches left, and nothing else is within reach (this tool's estimate)." The situation and its numbers are unchanged.
15. **The relegation sentence takes the others' form**: "F, in 6th, are 23 points behind you, across the relegation line."
16. **The evidence note says what is the owner's rule.** "The places and points are the table's own. The margin of 6 points is your rule (3 with one match left). Which lines are within reach or far, and the ×1.2 for a side within the margin, are this tool's estimate, with no test behind them." Its figures come from the rules, not the reading, so the note says 6 with one match left too.
17. **Today's league match against a side not in the table is listed** on the League screen, until its lineup is confirmed; before, only matches after today were.
18. **A finished season draws its rules and no longer says the table stops.** The line "The table has 0 matches left, so it is used for your next 0 league fixtures …" is not shown once the reading's season is over, and the rows' rules come from the three numbers whenever they fit the table, not from the reading, so a finished season and a failed reading still draw them.
19. **The club's own row is marked by its name**, with or without the three numbers.
20. **The three numbers take effect as they are typed.** Each keystroke goes to the model; the digits typed are the number and text with no digit is blank (Core holds the conversion). While a field is blank or the numbers typed are refused, a line under the fields says which numbers the table is still read with ("The table is still read with 1 promoted, 6 in the play-offs and 4 relegated."), and a choice made by hand in the menu is not touched by an edit that passes through a blank field. A paste or a removal of the table checks the numbers in the fields again: refused numbers that still do not fit keep their sentence, and ones that now fit are saved. This replaces change 6.
21. **The mark on a side within the margin has a key** under the table, the dot and "Within 6 points of you" in the engine's words, and each marked row says it to VoiceOver.
22. **The opponent menu's entries, the one chosen, and the words of the question "Remove table" asks are worked out in Core.** The menu was to be made as wide as the text box it replaces; it could not be (see the small faults), and the view's comment now says so.
23. **Three paths of the suggestion are tested**: a next league fixture the table does not speak for takes the ordinary base in the "bigger match follows" rule; a suggestion that read the table only through the next fixture carries the table's evidence; a season that is over changes no suggestion even when it is handed fixtures to speak for.
24. **One more picture**, `fixtures-editor-league-battling`: the editor for the sample's league fixture against Buxton, which the table speaks for, whose suggestion reads from the table's base and carries "Buxton are level on points with you (×1.2)".

## Known limits and small faults left

The design's limits, as they stand after the build:

- **The two tests for a settled line ignore that the other sides play each other.** "Safe" and "out of reach" count what each side could reach alone, so a line can be called open that is in fact settled, never the other way round. The sentences say "can still", not "will".
- **Matches in hand are not counted** when choosing the sides he is battling, by the owner's rule as he gave it: a side 6 points behind with two matches in hand counts the same as one with none. The gaps on the lines are in points only, too; only the safe and out-of-reach tests count each side's matches left.
- **An old table is used until it is replaced.** The screen says it is out of date once a league match with a confirmed lineup is dated after the paste, and not before. The day of the paste is the app's day in the game, so a paste made while the app's day is behind the game's counts the fixtures in between as still to come.
- **The owner's table was rebuilt, not captured.** It was pasted into a conversation on 19 November 2026 and written out from the design's appendix, as the capture `scouting-search` was. The first real paste shows whether FMRTE's clipboard matches it.
- **A paste of part of the table is refused** as a team having played more matches than a season holds, since the length of the season is worked out from the rows pasted (12 rows of a league of 24 give a season of 22 matches). The sentence does not say that part of the table was pasted.
- **One league, played home and away by everyone.** Continental places, a relegation play-off, split seasons and groups are not covered, and play-off matches are not league matches; in a top division 1 "promoted automatically" can stand for the champion.
- **Most of the numbers are not measured.** The margin (6 points, 3 with one match left) and the byes are the owner's rules; the ten matches are carried over from the old app's table; one point a match for "within reach" and the factor of 1.2 are this tool's estimate, with no test behind them.
- **A league match played on the day the table was pasted is not counted as played since.** The tool cannot tell a paste made before the match from one made after it, so the table speaks for one fixture too many and "A league match has been played since" does not show until the next league match is confirmed (`AppModel+League.swift`, `leagueTableIsOutOfDate`; `League.spokenFor`). This follows the design's letter.
- **The League situation menu switches to "From the table" the first time a reading exists, not the first time a table and three numbers are both held.** A paste that the saved numbers do not fit, followed by numbers that fit, drops a choice made by hand; so does a first paste of a finished season.
- **A club comfortably clear of a line, or well short of one, reads as Mid-table (60)** by the design's table; the words now say what he holds. Whether such a club's matches should be worth more is the owner's to decide. Above the relegation line alone, the words are those the In contention line already used for it: "the drop is 13 points clear with 9 matches left".

Small faults, found during the build:

- **`league-small` shows nothing of the table**, since a picture does not scroll.
- **The opponent menu in the fixture editor is narrower than the text box it replaces**; it fits its longest team. On macOS 26 a popup takes the width of its widest entry whatever frame it is given: a menu framed at 393 points, framed to infinity, or built as a `Menu`, all drew at their content's width when measured in a window, and the Mentoring editors' menus, framed at 170 points, draw at 125 and 149. Making it as wide would need a control of the app's own.
- **The engine words the day the table was pasted itself** (`AdvisorText.tablePastedLine`), while Core has `DayText.short` for every other day; the two could drift.
- **The number fields are checked only by test and picture.** That a letter typed never shows rests on the field taking the model's text back after each keystroke; it has not been tried in the running app.
- **A change of the club's name that makes the table readable again does not switch the menu to "From the table"**; only a paste, the three numbers and a removal do. The design says the menu switches whenever a reading first exists.
- **When two lines lie after the same place**, which only an unusual format gives (relegation and the play-offs meeting), only the first is drawn on the table.
- **The line on a choice by hand gives the situations capitalised mid-sentence** ("You have set league matches to Mid-table; the table reads Title race or relegation fight.").
- **Some paths have no test of their own:** suggestions kept from before a change of the club's name; that clearing the suggestions on such a change does anything the replan it also causes does not. The app's end-to-end test checks that the table's base reason is still used after the table is out of date, not that the match is still High, and the engine's passes no other fixtures, so the schedule rules are not on its path.

## For the owner

- Install with `tools/build_app.sh` from the repository root. It closes the open copy of the app and replaces it. It was not run in this build.
- In FMRTE, copy the league's standings and press "Paste table" on the League screen. Check it reads as the rebuilt table did: every team, in the game's order, with no warning unless the game has deducted points. If it is refused, the sentence says why; say what it said.
- With the standings on the clipboard, run `tools/capture_fmrte_paste.sh --list-grids` to see that the standings grid is found, then `tools/capture_fmrte_paste.sh league-table` to replace the rebuilt capture with the clipboard's exact bytes.
- Enter the three numbers (1, 6 and 4 for this league), and check the bye line says "2nd and 3rd get a bye." and that the League situation menu on Fixtures has moved to "From the table".
- Read the League screen against the game's own table: the places and points, the lines drawn, each sentence, and the sides marked as within 6 points. Then read the suggested importance of the coming league fixtures, above all one against a side he is battling.
- Paste the table again after each round of league matches; the screen says when a league match has been played since.
