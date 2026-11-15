# FM27 League Situation and Opponent Squad Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The owner can say what the club's league matches are worth, paste an opponent's squad to set "Their strength", and take a suggested importance from the Fixtures table.

**Architecture:** The engine's importance suggestion takes a league situation, which picks the base score of a league fixture. A new engine function compares the eleven best fit players of a pasted squad with the owner's by current ability and returns a reading; the opponent's players are never kept. The app keeps the situation in its settings and the reading on the fixture, and the Fixtures screen gains a menu, a "Use it" button on each suggestion line and a "Paste their squad" button in the editor.

**Tech Stack:** Swift 6, macOS 26, SwiftUI and Observation, Swift Testing, Foundation only. Same packages and conventions as the earlier plans.

**Spec:** `docs/superpowers/specs/2026-11-15-fm27-league-situation-and-opponent-squad-design.md`. Read it before any task.

## Global Constraints

- Work on branch `fm27-native`. Never commit to `main`, merge, or open a pull request. Say why in every commit message.
- The engine decides; the app shows. A view never computes a rating, a reason or a rule. Every word about advice (the situations' names, the reason lines, the reading, the refusals) comes from the engine and is shown as written. Core holds only plain labels and headings.
- No silent defaults. A missing column, or a blank or out-of-range value, is an error that names the player and the column.
- Every tunable number lives in `EngineParameters` with an evidence label and a source. League bases: 100, 80, 60, 20, `.carriedOverFM26`. Strength lines: 5 and 15 (whole percentages), `.derived`.
- Every rule gets a test where it changes an outcome and a test where it does not. Tests are written first.
- The same inputs always give the same result: sums run in a fixed order. The strength comparison is done in whole numbers.
- Test output must be clean: no build warnings. Every `switch` over an engine enum, error or warning is exhaustive, with no `default`.
- Logic for a screen lives in `LineupAppCore` with tests. Views hold layout only. Every colour, typeface and measure comes from `Theme`.
- Nothing the owner reads is an id or a code.
- A file that cannot be read gives a notice and a fresh start for that file, and the unreadable file is kept aside. No test, picture run or sample-data run touches `~/Library/Application Support` or the real clipboard.
- The opponent's players never enter the squad book, the marks, the mentoring file, the personality readings, the plan or any advisor.
- The old Python, `ui/` and root-level data files are reference only: do not modify them.
- After every task both packages build and their tests pass: `cd LineupEngine && swift test`, and `cd LineupApp && swift build && swift test` (about four and a half minutes).

## Review Focus

Conditions the spec does not spell out and that are most likely to bite, most likely first. Each has its test in the task named.

1. **A double-click on "Use it" in the table.** Taking a suggestion removes that row's suggestion line, so the next row moves up under the pointer. The second click must not take the next fixture's suggestion. Task 4, `aSecondUseItWithinHalfASecondDoesNothing`.
2. **"Use it" in the table while that fixture's editor is open.** The editor's draft still holds the old importance and would write it back on save. The table offers no "Use it" for the fixture being edited; the editor has its own. Task 4, `theTableOffersNoUseItForTheFixtureBeingEdited`.
3. **The opponent's name typed differently from the game's** ("Banbury" for "Banbury United"). FMRTE's team grid has no club column, so the typed name decides who is on loan there. A loanee is then wrongly left out; the reading must list his club so the owner can see it. Task 2, `aNameTypedDifferentlyLeavesTheLoaneeOutAndListsHisClub`. The same goes for a player on loan between the two clubs, who counts once, for the club he plays for: Task 2, `aPlayerOnLoanBetweenTheClubsCountsForTheClubHePlaysFor`.
4. **A settings file holding a situation this version does not know** (hand-edited, or written by a later version). The owner gets the usual notice and a fresh start for settings, with the file kept aside, not a crash. Task 3, `aSettingsFileWithAnUnknownSituationIsKeptAsideWithANotice`.
5. **An opponent paste from a grid with no `Id` column.** The importer warns that players are identified by name. For an opponent that warning means nothing: the paste is read, and no warning is shown. Task 5, `aPasteWithoutAnIdColumnIsReadWithNoWarning`.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `LineupEngine/Sources/LineupEngine/Planner/PlanInputs.swift` | modify | `LeagueSituation`, beside `Competition` |
| `LineupEngine/Sources/LineupEngine/Parameters/EngineParameters.swift` | modify | three league bases in `ImportanceSuggestionRules`; `OpponentStrengthLines` and `opponentStrengthLines` |
| `LineupEngine/Sources/LineupEngine/Selection/FitnessModel.swift` | modify | the three new bases checked in `problems(in:)` |
| `LineupEngine/Sources/LineupEngine/Advisors/ImportanceSuggestion.swift` | modify | `suggest` takes the situation |
| `LineupEngine/Sources/LineupEngine/Advisors/OpponentReading.swift` | create | `OpponentReading`, `OpponentSide`, `OpponentReadingError`, `OpponentAdvisor.read` |
| `LineupEngine/Sources/LineupEngine/Import/SquadBook.swift` | modify | `SquadBook.commonClub(among:)`, taken out of `ownClub(override:)` |
| `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText.swift` | modify | the situations' names; the reading's sentence |
| `LineupEngine/Sources/LineupEngine/Reporting/ErrorDescriptions.swift` | modify | `OpponentReadingError` in plain words |
| `LineupEngine/Sources/lineup-cli/main.swift` | modify | `advise --league-situation` |
| `LineupEngine/Tests/LineupEngineTests/ImportanceSuggestionTests.swift` | modify | the situation's tests |
| `LineupEngine/Tests/LineupEngineTests/OpponentReadingTests.swift` | create | the reading's tests |
| `LineupApp/Sources/LineupAppCore/StoredTypes.swift` | modify | `AppSettings.leagueSituation`, `StoredFixture.opponentReading` |
| `LineupApp/Sources/LineupAppCore/AppModel+Advice.swift` | modify | hands the situation to the suggestion |
| `LineupApp/Sources/LineupAppCore/AppModel+Fixtures.swift` | modify | `setLeagueSituation`, `useSuggestion(for:)` |
| `LineupApp/Sources/LineupAppCore/AppModel+Opponent.swift` | create | `pasteOpponentSquad(into:)` |
| `LineupApp/Sources/LineupAppCore/FixturePresentation.swift` | modify | the menu's choices and label; the draft's reading and paste problem; whether the table offers "Use it" |
| `LineupApp/Sources/LineupAppUI/Fixtures/FixturesScreen.swift` | modify | the menu; "Use it" on a suggestion line |
| `LineupApp/Sources/LineupAppUI/Fixtures/FixtureEditor.swift` | modify | "Paste their squad", the reading, a refusal |
| `LineupApp/Sources/LineupAppUI/ScreenPictures.swift`, `LineupApp/Sources/LineupApp/` (the picture run) | modify | the `fixtures-situation`, `fixtures-editor-reading` and `fixtures-editor-refused` pictures |
| `LineupApp/Tests/LineupAppCoreTests/FixturePresentationTests.swift` | modify | Core tests for Tasks 3 to 5 |
| `CLAUDE.md`, this plan | modify | what the suggestion, the Fixtures screen and the editor now do; the closing sections |

---

### Task 1: The league situation in the suggested importance

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Planner/PlanInputs.swift`, `Parameters/EngineParameters.swift`, `Selection/FitnessModel.swift`, `Advisors/ImportanceSuggestion.swift`, `Reporting/AdvisorText.swift`, `LineupEngine/Sources/lineup-cli/main.swift`
- Modify (call sites only): `LineupApp/Sources/LineupAppCore/AppModel+Advice.swift`
- Test: `LineupEngine/Tests/LineupEngineTests/ImportanceSuggestionTests.swift`, `AdvisorTextTests.swift`, `FitnessModelTests.swift`

**Interfaces:**
- Produces:
  - `public enum LeagueSituation: String, Codable, CaseIterable, Sendable { case titleRaceOrRelegationFight, inContention, midTable, nothingToPlayFor }`
  - `ImportanceSuggestionRules` gains `leagueTitleRaceBase: Double` (100), `leagueMidTableBase: Double` (60), `leagueNothingToPlayForBase: Double` (20). `leagueBase` (80) stays and is the in-contention value; say so in its comment.
  - `ImportanceAdvisor.suggest(for:among:confirmed:players:tiers:situation:parameters:)`, with `situation: LeagueSituation` a required argument before `parameters`.
  - `AdvisorText.name(_ situation: LeagueSituation) -> String`

- [x] **Step 1: Write the failing tests** in `ImportanceSuggestionTests`. Give the suite's `suggest` helper a `situation: LeagueSituation = .inContention` argument that it passes on.

```swift
@Test func eachSituationSetsALeagueMatchsBase() throws {
    #expect(try suggest(fixture(), situation: .titleRaceOrRelegationFight).importance == .high)   // 100
    #expect(try suggest(fixture(), situation: .inContention).importance == .medium)               // 80
    #expect(try suggest(fixture(), situation: .midTable).importance == .medium)                   // 60
    #expect(try suggest(fixture(), situation: .nothingToPlayFor).importance == .low)              // 20
    #expect(try suggest(fixture(), situation: .midTable).score == 60)
}

@Test func theSituationDoesNotTouchOtherCompetitions() throws {
    for competition in [Competition.cup, .minorCup, .friendly, nil] {
        let usual = try suggest(fixture(competition: competition))
        for situation in LeagueSituation.allCases {
            #expect(try suggest(fixture(competition: competition), situation: situation) == usual)
        }
    }
}

@Test func inContentionReadsAsBefore() throws {
    #expect(try suggest(fixture()).reasons.first == "League match: 80")
}

@Test func theReasonNamesAnyOtherSituation() throws {
    #expect(try suggest(fixture(), situation: .titleRaceOrRelegationFight).reasons.first
            == "League match, title race or relegation fight: 100")
    #expect(try suggest(fixture(), situation: .midTable).reasons.first == "League match, mid-table: 60")
    #expect(try suggest(fixture(), situation: .nothingToPlayFor).reasons.first == "League match, nothing to play for: 20")
}

/// A cup match (60) is followed two days later by a league match: bigger at 80, not bigger at 20.
@Test func theBiggerMatchRuleReadsTheSituationForTheNextFixture() throws {
    let cup = fixture(competition: .cup)
    let league = fixture("next", daysFromToday: 2)
    #expect(try suggest(cup, among: [league]).score == 36)                                  // 60 × 0.6
    #expect(try suggest(cup, among: [league], situation: .nothingToPlayFor).score == 60)
}

@Test func nothingToPlayForIsSharpnessWhereTheSharpnessRuleHolds() throws {
    let unsharp = try suggest(fixture(), sharpness: [0.5, 0.5, 0.5], situation: .nothingToPlayFor)
    #expect(unsharp.importance == .sharpness)
    #expect(try suggest(fixture(), sharpness: [0.5, 0.5], situation: .nothingToPlayFor).importance == .low)
}

/// 20 × 1.2 (much stronger) × 1.1 (rested) = 26.4, the largest it can reach.
@Test func nothingToPlayForNeverReachesMedium() throws {
    let rested = try suggest(fixture(opponent: .muchStronger), confirmed: [confirmed("last", daysFromToday: -8)],
                             situation: .nothingToPlayFor)
    #expect(rested.importance == .low)
}
```

In `AdvisorTextTests`: the four names are "Title race or relegation fight", "In contention", "Mid-table", "Nothing to play for". In `FitnessModelTests`, beside the existing test of a base that is not finite: each of the three new bases set to `.infinity` gives a problem naming it.

- [x] **Step 2: Run them and see them fail to compile**

Run: `cd LineupEngine && swift test --filter ImportanceSuggestionTests`
Expected: build errors for `LeagueSituation` and the `situation:` argument.

- [x] **Step 3: Implement.**
  - `LeagueSituation` in `PlanInputs.swift` under `Competition`, with a one-line comment.
  - The three bases in `ImportanceSuggestionRules` and its initialiser, with the values above in `EngineParameters.fm27`. Rewrite the end of the parameter's source: the league bases are the old table's four league values (title race or relegation 100, contention 80, mid-table 60, dead rubber 20); the old table gave 100 only in the last ten league matches, and here the owner says when.
  - `FitnessModel.problems(in:)`: add the three to the list of bases checked for being finite.
  - `baseScore(competition:situation:rules:)`: for `.league`, the base and the reason by situation, exactly as the tests read. Both calls to it (this fixture and the next) pass the situation.
  - `AdvisorText.name(_:)` for the situation.
  - `main.swift`: `advise` accepts `--league-situation` with `title-race`, `in-contention`, `mid-table` or `nothing-to-play-for` (default in contention, as the usage text must say); any other value is a `UsageError` listing the four. Add it to the usage comment at the top of the file.
  - `AppModel+Advice.swift`: both calls pass `situation: .inContention` for now. Task 3 replaces it.

- [x] **Step 4: Run every test**

Run: `cd LineupEngine && swift test` then `cd ../LineupApp && swift build`
Expected: all pass, no warnings; the app builds.

- [x] **Step 5: Try the command line**

Run the `advise` command from `CLAUDE.md` twice, once as written and once with `--league-situation nothing-to-play-for`.
Expected: without the flag the output is unchanged from before this task (compare with `git stash` or a saved copy); with it, every league fixture's suggestion reads Low or Sharpness with the reason "League match, nothing to play for: 20".

- [x] **Step 6: Commit** the engine and the app call sites, saying that a league match's worth depends on where the club stands and that in contention keeps every existing suggestion.

---

### Task 2: Reading an opponent's strength from his squad

**Files:**
- Create: `LineupEngine/Sources/LineupEngine/Advisors/OpponentReading.swift`
- Modify: `Parameters/EngineParameters.swift`, `Import/SquadBook.swift`, `Reporting/AdvisorText.swift`, `Reporting/ErrorDescriptions.swift`
- Test: create `LineupEngine/Tests/LineupEngineTests/OpponentReadingTests.swift`; modify `ErrorDescriptionsTests.swift`, `AdvisorTextTests.swift`, `SquadBookTests.swift`

**Interfaces:**
- Produces:

```swift
/// What a pasted opponent squad was found to be worth beside the owner's. The players themselves are not kept.
public struct OpponentReading: Equatable, Codable, Sendable {
    public let club: String            // their club's name as used: from the rows, or as the owner typed it
    public let day: Day                // the game's date when it was pasted
    public let theirTotal: Int         // current ability summed over their best eleven
    public let ownTotal: Int           // the same for the owner's
    public let strength: OpponentStrength
    public let awayOnLoanAt: [String]  // the clubs their left-out players are at: each once, as first spelt, A to Z
    public var theirAverage: Double { Double(theirTotal) / 11 }
    public var ownAverage: Double { Double(ownTotal) / 11 }
}

public enum OpponentSide: Equatable, Sendable { case theirs(club: String), own }

public enum OpponentReadingError: Error, Equatable, Sendable {
    case noOwnSquad
    case ownSquadPasted
    case noClubName
    case tooFewPlayers(OpponentSide, found: Int)
}

public enum OpponentAdvisor {
    /// `named` is the opponent as the owner typed it on the fixture, used when the rows carry no club.
    public static func read(theirs: [Player], named: String, own: [Player], ownClub: String?, on day: Day,
                            parameters: EngineParameters) throws -> OpponentReading
}

public struct OpponentStrengthLines: Sendable, Equatable {
    public var strongerFromPercent: Int       // 5
    public var muchStrongerFromPercent: Int   // 15
}
// EngineParameters.opponentStrengthLines: Parameter<OpponentStrengthLines>, .derived

extension SquadBook { public static func commonClub(among players: [Player]) -> String? }
extension AdvisorText { public static func opponentReading(_ reading: OpponentReading, on day: String) -> String }
```

**The rule** (the spec's "Their club", "The best eleven" and "The comparison"), in this order:
1. Lines that are not `0 < s < m < 100` throw `PlanError.badParameters` with one sentence naming `opponentStrengthLines`.
2. `own` empty: `.noOwnSquad`.
3. More than half of `theirs` have an id that a player of `own` has: `.ownSquadPasted`.
4. Their club is `SquadBook.commonClub(among: theirs)`; when that is nil, `named` without the spaces around it; when that is blank too, `.noClubName`.
5. A side's players are those who are not injured and whose `LoanStatus.of(player, ownClub: that side's club)` is not `.loanedOut`. The owner's side uses `ownClub` as given, nil included. A banned player counts.
6. The best eleven are the eleven with the highest current ability, whatever their positions. Fewer than eleven: `.tooFewPlayers(side, found:)`, the opponent's side checked first.
7. With `T` their total, `O` the owner's, `s` and `m` the two lines, in whole numbers and in this order: `T × 100 ≥ O × (100 + m)` much stronger; `T × 100 ≥ O × (100 + s)` stronger; `T × 100 ≤ O × (100 − m)` much weaker; `T × 100 ≤ O × (100 − s)` weaker; otherwise similar.
8. `awayOnLoanAt` is the "loaned to" of every pasted player who reads as `.loanedOut`, injured or not.

- [x] **Step 1: Write the failing tests** in `OpponentReadingTests`. A helper `side(club:loanedTo:abilities:)` builds players with distinct names and `club` as given (nil for FMRTE's team grid, which has no club column). The owner's side is eleven players with club nil, all at ability 100, so `ownTotal` is 1100; `ownClub` is "Oxford City"; `named` is "Banbury United" unless a test says otherwise.

```swift
@Test func eachLineGivesItsStep() throws {
    // Their eleven all at one ability, then with one player a point the other way.
    #expect(try strength(all: 115) == .muchStronger)
    #expect(try strength(all: 115, oneAt: 114) == .stronger)
    #expect(try strength(all: 105) == .stronger)
    #expect(try strength(all: 105, oneAt: 104) == .similar)
    #expect(try strength(all: 100) == .similar)
    #expect(try strength(all: 95, oneAt: 96) == .similar)
    #expect(try strength(all: 95) == .weaker)
    #expect(try strength(all: 85, oneAt: 86) == .weaker)
    #expect(try strength(all: 85) == .muchWeaker)
}

@Test func theReadingCarriesWhatItCompared() throws {
    #expect(try read(theirs: eleven(all: 105))
            == OpponentReading(club: "Banbury United", day: today, theirTotal: 1155, ownTotal: 1100,
                               strength: .stronger, awayOnLoanAt: []))
}

@Test func onlyTheBestElevenCount() throws           // a twelfth player at 60 on either side changes nothing
@Test func anInjuredPlayerIsLeftOut() throws         // their best player injured, a twelfth at 60: the total falls by the difference
@Test func aBannedPlayerStillCounts() throws
@Test func positionsDoNotMatter() throws             // eleven players with no goalkeeper among them give a reading

@Test func withNoClubOnTheRowsTheNameGivenIsTheirClub() throws
    // named " Banbury United ": reading.club == "Banbury United"; a twelfth player at 190 with loanedTo "banbury united"
    // is on loan there and is counted.
@Test func theirClubComesFromTheRowsWhenTheyCarryOne() throws
    // Every row's club "Banbury United", named "Banbury": reading.club == "Banbury United".
@Test func aPlayerAwayOnLoanIsLeftOutAndHisClubListed() throws
    // Players at 190 with loanedTo "Wallingford", "Reading" and "reading": the total is unchanged and
    // awayOnLoanAt == ["Reading", "Wallingford"].
@Test func aNameTypedDifferentlyLeavesTheLoaneeOutAndListsHisClub() throws
    // named "Banbury", a player with loanedTo "Banbury United": left out, awayOnLoanAt == ["Banbury United"].
@Test func aPlayerOnLoanBetweenTheClubsCountsForTheClubHePlaysFor() throws
    // The same player, at 190 with loanedTo "Banbury United", is in `own` and in `theirs`:
    // ownTotal is 1100 without him and theirTotal includes him.
@Test func theOwnersInjuredAndLoanedOutPlayersAreLeftOut() throws
@Test func aPlayerOnLoanAtTheOwnersClubCountsForTheOwner() throws     // loanedTo "Oxford City" in `own`
@Test func withNoOwnClubKnownEveryLoanOfTheOwnersReadsAsAway() throws // ownClub nil: the squad book's rule, unchanged
@Test func inputOrderDoesNotMatter() throws                           // both sides shuffled give an equal reading

@Test func refusals() throws {
    #expect(throws: OpponentReadingError.noOwnSquad) { try read(theirs: eleven(all: 100), own: []) }
    #expect(throws: OpponentReadingError.ownSquadPasted) { try read(theirs: own) }
    #expect(throws: OpponentReadingError.noClubName) { try read(theirs: eleven(all: 100), named: "  ") }
    #expect(throws: OpponentReadingError.tooFewPlayers(.theirs(club: "Banbury United"), found: 10)) { /* ten fit */ }
    #expect(throws: OpponentReadingError.tooFewPlayers(.own, found: 10)) { /* the owner's eleventh injured */ }
}

@Test func halfTheRowsBeingTheOwnersIsNotRefused() throws
    // Twelve rows of which six are the owner's players: a reading. Seven of twelve: .ownSquadPasted.
@Test func badLinesAreAnError() throws                // 5 and 5; 0 and 15; 5 and 100
@Test func movingALineChangesTheStep() throws         // strongerFromPercent 10: all at 105 is similar
```

In `SquadBookTests`: `commonClub(among:)` gives the most common club, counts spellings `PlayerID.normalise` makes equal as one club spelt as first seen, breaks a tie to the alphabetically first, and is nil when no player has a club; `ownClub(override:)` gives what it gave before.

In `AdvisorTextTests`:

```swift
let plain = OpponentReading(club: "Banbury United", day: day, theirTotal: 816, ownTotal: 754, strength: .stronger,
                            awayOnLoanAt: [])
#expect(AdvisorText.opponentReading(plain, on: "Sun 15 Nov")
        == "Squad pasted for Banbury United on Sun 15 Nov: their best eleven averages 74.2 ability, yours 68.5, "
         + "which reads as Stronger (this tool's estimate).")
// With awayOnLoanAt ["Wallingford"], the same and then: " Left out as away on loan: players at Wallingford."
// With ["Reading", "Wallingford"]: "… players at Reading and Wallingford."
// With three: "… players at Marlow, Reading and Wallingford."
```

In `ErrorDescriptionsTests`, each case through `ErrorDescriptions.describe(_: Error)`:

| Case | Sentence |
|---|---|
| `.noOwnSquad` | "Import your own squad first, so there is something to compare theirs with." |
| `.ownSquadPasted` | "The rows pasted are your own players. Open the opponent's squad in FMRTE and copy that." |
| `.noClubName` | "Say who the match is against before pasting, so that a player on loan there can be told from one away on loan." |
| `.tooFewPlayers(.theirs(club: "Banbury United"), found: 9)` | "Banbury United has only 9 fit players among the rows pasted who are not away on loan; eleven are needed." |
| `.tooFewPlayers(.own, found: 9)` | "Your own squads have only 9 fit players who are not away on loan; eleven are needed." |

- [x] **Step 2: Run them and see them fail to compile**

Run: `cd LineupEngine && swift test --filter OpponentReadingTests`
Expected: build errors for the new types.

- [x] **Step 3: Implement** the interfaces and the rule above.
  - `commonClub(among:)` is the counting half of `ownClub(override:)`, which now calls it.
  - `opponentStrengthLines` in `EngineParameters.fm27`: 5 and 15, `.derived`, with the source "this design's choice (docs/superpowers/specs/2026-11-15-fm27-league-situation-and-opponent-squad-design.md): no test relates a gap in ability to results; a ratio so the lines mean the same in every division". Add the parameter wherever the other parameters are listed (the initialiser, and any test that counts or names every parameter).
  - The reading's sentence writes each average to one decimal place and the strength with `AdvisorText.name`.
  - `ErrorDescriptions.describe(_: Error)` gains the new error type, with its own exhaustive `describe`.

- [x] **Step 4: Run every engine test**

Run: `cd LineupEngine && swift test`
Expected: all pass, no warnings.

- [x] **Step 5: Commit**, saying that the strength is read from the squad because the owner had nothing to pick it by, and that the lines are the tool's own estimate.

---

### Task 3: The league situation in the app's state

**Files:**
- Modify: `LineupApp/Sources/LineupAppCore/StoredTypes.swift`, `AppModel+Advice.swift`, `AppModel+Fixtures.swift`, `FixturePresentation.swift`
- Test: `LineupApp/Tests/LineupAppCoreTests/FixturePresentationTests.swift`, `StoreTests.swift`

**Interfaces:**
- Consumes: `LeagueSituation`, `AdvisorText.name(_:)`, `ImportanceAdvisor.suggest(… situation: …)` from Task 1.
- Produces:
  - `AppSettings.leagueSituation: LeagueSituation?` (nil in files from before this plan) and `AppSettings.situation: LeagueSituation`, which is `leagueSituation ?? .inContention`.
  - `AppModel.setLeagueSituation(_ situation: LeagueSituation)`
  - `AppModel.leagueSituationChoices: [(value: LeagueSituation, title: String)]` (static, in `allCases` order, titles from the engine) and `AppModel.leagueSituationLabel = "League situation"`.

- [x] **Step 1: Write the failing tests.** Use the suite's existing way of making a model with the captured squads, a tactic and league fixtures.

```swift
@Test func theSituationChangesALeagueFixturesSuggestion() throws
    // A league fixture against a similar side: suggested Medium. After setLeagueSituation(.nothingToPlayFor):
    // Low or Sharpness, and its first reason is "League match, nothing to play for: 20".
@Test func theSituationDoesNotChangeACupFixturesSuggestion() throws
@Test func changingTheSituationDoesNotPlanAgain() throws
    // timesPlanned and timesAdvised are the same before and after; the plan state is equal.
@Test func theSituationIsSavedAndReadBack() throws           // reopened().settings.situation == .midTable
@Test func theEditorsSuggestionFollowsTheSituation() throws  // suggestionNote(for: draft) of a league draft
@Test func aViewReadingTheSuggestionsIsToldWhenTheSituationChanges() throws
    // withObservationTracking { _ = model.suggestions } onChange fires when setLeagueSituation is called.
@Test func settingsFromBeforeThisPlanOpenAsInContention() throws
    // A settings file written without the key: no notice, situation == .inContention.
@Test func aSettingsFileWithAnUnknownSituationIsKeptAsideWithANotice() throws
    // "leagueSituation": "playOffPush" in the file: one notice, a fresh settings state, the file kept aside,
    // as StoreTests checks for any unreadable file.
@Test func theMenuListsTheFourSituationsInTheEnginesWords() throws
```

- [x] **Step 2: Run them and see them fail**

Run: `cd LineupApp && swift test --filter FixturePresentationTests`
Expected: build errors for the new members.

- [x] **Step 3: Implement.**
  - `AppSettings` keeps its synthesised coding; the new optional is absent in old files.
  - Both calls to `ImportanceAdvisor.suggest` pass `settings.situation`.
  - `setLeagueSituation` saves the settings and clears the kept suggestions (`adviceCache?.suggestions = nil`); it does not call `replan()`. Make sure a view that read `suggestions` is told: `suggestions` must read something observed that this action changes. `update(_ settings:)` needs no change, since the situation is not among the things it plans again for; check that a change to it there also clears the kept suggestions, so the two routes agree.

- [x] **Step 4: Run the app's tests**

Run: `cd LineupApp && swift build && swift test`
Expected: all pass, no warnings.

- [x] **Step 5: Commit**, saying the situation is the owner's to say and changes suggestions only.

---

### Task 4: Taking a suggestion from the Fixtures table

**Files:**
- Modify: `LineupApp/Sources/LineupAppCore/AppModel+Fixtures.swift`, `FixturePresentation.swift`, `AppModel.swift` (the time of the last action)
- Test: `LineupApp/Tests/LineupAppCoreTests/FixturePresentationTests.swift`

**Interfaces:**
- Consumes: `AppModel.suggestionLine(for:)`, `AppModel.update(_ fixture:)`, the clock in the environment (`environment.now`), as `AppModel+Training.swift` uses it.
- Produces:
  - `AppModel.useSuggestion(for id: FixtureID)`: sets the fixture's importance to its suggestion's and plans again.
  - `AppModel.suggestionActionInterval: TimeInterval = 0.5` (static).
  - `AppModel.offersUseIt(for fixture: StoredFixture, editing: FixtureID?) -> Bool`
  - `SuggestionNote.useItLabel(opponent: String) -> String`: "Use the suggested importance for the match against Banbury United", for VoiceOver.

- [x] **Step 1: Write the failing tests**

```swift
@Test func useItTakesTheSuggestionAndPlansAgain() throws
    // A fixture chosen Medium and suggested Low: afterwards its importance is .low, it is saved (reopened()),
    // timesPlanned is one more, and suggestionLine(for:) is nil.
@Test func useItDoesNothingWhereNoLineIsShown() throws
    // A confirmed fixture, a past one, one whose suggestion equals its importance, and an id no fixture has:
    // nothing changes and nothing is planned.
@Test func aSecondUseItWithinHalfASecondDoesNothing() throws
    // Two fixtures with suggestion lines. Use the first; 0.4 seconds later on the scripted clock use the second:
    // the second is unchanged. At 0.5 seconds it is taken.
@Test func theTableOffersNoUseItForTheFixtureBeingEdited() throws
    // offersUseIt(for: fixture, editing: fixture.id) is false; with editing nil or another id it is true;
    // false whenever suggestionLine(for:) is nil.
@Test func useItKeepsTheFixturesOtherChoices() throws   // its tactic, overrides, rejections, competition and strength
@Test func theUseItLabelNamesTheMatch() throws
```

- [x] **Step 2: Run them and see them fail**

Run: `cd LineupApp && swift test --filter FixturePresentationTests`
Expected: build errors.

- [x] **Step 3: Implement.** `useSuggestion` is guarded by `suggestionLine(for:)` being present and by the interval, measured from the end of the last one that ran, as the Training guard is; keep its own time, not the Training one's.

- [x] **Step 4: Run the app's tests**

Run: `cd LineupApp && swift build && swift test`
Expected: all pass, no warnings.

- [x] **Step 5: Commit**, saying why: after the situation changes, the owner would otherwise open and save every league fixture.

---

### Task 5: Pasting the opponent's squad into a fixture

**Files:**
- Create: `LineupApp/Sources/LineupAppCore/AppModel+Opponent.swift`
- Modify: `LineupApp/Sources/LineupAppCore/StoredTypes.swift`, `FixturePresentation.swift`, `AppModel+Fixtures.swift` (`save(_ draft:)`), `AppModel+Squad.swift` (share the empty-clipboard sentence and the settings-file reading)
- Test: `LineupApp/Tests/LineupAppCoreTests/FixturePresentationTests.swift`, `StoreTests.swift`, `Support/TestModel.swift` (the capture with FMRTE's `Id` column)

**Interfaces:**
- Consumes: `OpponentAdvisor.read`, `OpponentReading`, `AdvisorText.opponentReading(_:on:)`, `ErrorDescriptions.describe` from Task 2; `Importer.importPlayers(clipboard:fmrteConfig:squad:)`; `DayText.short`.
- Produces:
  - `StoredFixture.opponentReading: OpponentReading?`, a new coding key read with `decodeIfPresent` and written with `encodeIfPresent`.
  - `FixtureDraft.opponentReading: OpponentReading?`, `FixtureDraft.pasteProblem: String?`, `FixtureDraft.opponentReadingText: String?` (the engine's sentence with `DayText.short(reading.day)`), `FixtureDraft.pasteButtonTitle = "Paste their squad"`.
  - `AppModel.pasteOpponentSquad(into draft: inout FixtureDraft)`

**Behaviour:**
- The engine is handed the pasted players, `named: draft.opponent`, the owner's players (`squad.book.allPlayers`), his club (`ownClub`) and `settings.currentDate`.
- Success: `draft.opponentStrength` is the reading's strength, `draft.opponentReading` is the reading, `draft.pasteProblem` is nil.
- Failure: `draft.pasteProblem` is the sentence; the strength and any earlier reading are untouched.
- The sentences: an empty or blank clipboard, "The clipboard is empty. Copy the rows in FMRTE first." (the one the squad import uses; share it); FMRTE's settings file unreadable, what `describeConfigFailure` gives; the importer's and the engine's refusals, `ErrorDescriptions.describe`.
- The rows are imported as `.firstTeam` only to satisfy the importer; the result's warnings and money are dropped.
- Nothing is saved, planned or advised by a paste. `save(_ draft:)` carries the draft's reading to the fixture, new or edited.

- [x] **Step 1: Write the failing tests.** The captures give two sides that read as different players: the owner imports `first-team-with-id.tsv` with its own grids (players keyed by FMRTE's id; fifteen fit), and the opponent's paste is `first-team.tsv` with its grids (the same men keyed by name; sixteen fit). Neither has a club column. Add `Captures.firstTeamWithID` and its grids to the test support if they are not there. The draft's opponent is "Banbury United".

```swift
@Test func aPasteSetsTheStrengthAndTheReading() throws
    // draft.opponentReading equals what OpponentAdvisor.read gives for the same players, name, club and day;
    // its club is "Banbury United" and its day the game's date; draft.opponentStrength is its strength;
    // opponentReadingText is the engine's sentence with DayText.short of the day.
@Test func nothingIsSavedUntilTheFixtureIs() throws
    // After the paste: the fixtures file unchanged, timesPlanned and timesAdvised unchanged. After save(draft):
    // the stored fixture has the strength and the reading, and reopened() reads them back.
@Test func aPasteLeavesTheSquadBookAsItWas() throws
    // squad, marks, mentoring and training state equal before and after; the squad file's bytes unchanged.
@Test func pastingTheOwnSquadIsRefused() throws        // the capture the owner imported: the engine's sentence,
                                                       // the draft otherwise as it was
@Test func withABlankOpponentThePasteIsRefused() throws
@Test func withTooFewOwnPlayersThePasteIsRefused() throws   // only the U21 capture imported: six players
@Test func anEmptyClipboardIsRefused() throws
@Test func rowsTheImporterRefusesGiveItsSentence() throws   // "Oxford City 2 Banbury United 1"
@Test func withNoSquadImportedThePasteIsRefused() throws
@Test func aRefusalKeepsAnEarlierReading() throws
@Test func aLaterPasteReplacesTheReadingAndClearsTheProblem() throws
@Test func pickingAStrengthByHandKeepsTheReading() throws
    // draft.opponentStrength set by hand after a paste: saved as picked, the reading still says what the paste found.
@Test func aPasteWithoutAnIdColumnIsReadWithNoWarning() throws
    // first-team.tsv has no Id column: a reading, and pasteProblem is nil.
@Test func aFixtureFromBeforeThisPlanOpensWithNoReading() throws   // a fixtures file without the key: no notice
@Test func editingAFixtureShowsItsSavedReading() throws            // fixtureDraft(for:) carries it
@Test func useItInTheTableKeepsTheReading() throws                 // useSuggestion(for:) on a fixture with one
```

- [x] **Step 2: Run them and see them fail**

Run: `cd LineupApp && swift test --filter FixturePresentationTests`
Expected: build errors.

- [x] **Step 3: Implement** the interfaces and behaviour above.

- [x] **Step 4: Run the app's tests**

Run: `cd LineupApp && swift build && swift test`
Expected: all pass, no warnings.

- [x] **Step 5: Commit**, saying the opponent's players are read and dropped, and only what the comparison found is kept.

---

### Task 6: The screens

**Files:**
- Modify: `LineupApp/Sources/LineupAppUI/Fixtures/FixturesScreen.swift`, `Fixtures/FixtureEditor.swift`, `Theme.swift` (only if a new measure is needed), `ScreenPictures.swift`, the picture run in `LineupApp/Sources/LineupApp/`, `LineupApp/Sources/LineupAppCore/SampleData.swift` (if the pictures need a scripted paste)

**Interfaces:**
- Consumes: everything Tasks 3 to 5 produce. No new logic: if a view needs an `if` about data, put it in Core with a test.

- [x] **Step 1: The Fixtures screen.**
  - In the heading row, after "Add fixture" and pushed to the trailing edge, the label `AppModel.leagueSituationLabel` and a menu of `AppModel.leagueSituationChoices` bound to `model.settings.situation` and `model.setLeagueSituation`. Shown whenever the table is shown. Style it as the editor's menus are.
  - On a row's suggestion line, a "Use it" button (`SuggestionNote.useItTitle`) where `model.offersUseIt(for:editing:)` is true, calling `model.useSuggestion(for:)`, with `useItLabel` as its accessibility label. It sits beside the line and does not toggle the reasons.

- [x] **Step 2: The editor.** Beside the "Their strength" menu, a button titled `FixtureDraft.pasteButtonTitle` calling `model.pasteOpponentSquad(into: &draft)`. Under the two menus, `draft.opponentReadingText` in muted ink when present, and `draft.pasteProblem` in the style `shownProblem` uses when present. Both wrap; neither widens the card.

- [x] **Step 3: The pictures.** Add to the picture run, in light and dark:
  - `fixtures-situation`: the Fixtures screen with the situation "Nothing to play for", so its league rows show "Suggested: Low" (or Sharpness) with "Use it".
  - `fixtures-editor-reading`: the editor for a fixture with a reading.
  - `fixtures-editor-refused`: the editor after a refused paste (the owner's own squad).
  - The existing `fixtures-*` pictures now show the menu and "Use it" as well.

Run: `cd LineupApp && swift run -q LineupApp --sample-data .. --pictures .build/pictures-opponent`
Expected: the run ends with no error and writes the new files.

- [x] **Step 4: Look at the pictures.** Open `fixtures-light`, `fixtures-dark`, `fixtures-small-*`, `fixtures-narrow-*`, `fixtures-reasons-*`, `fixtures-situation-*`, `fixtures-editor-*`, `fixtures-editor-reading-*` and `fixtures-editor-refused-*`. Check: the menu does not crowd or wrap the heading in the smallest window; "Use it" does not push the importance column out of line; the reading's sentence wraps inside the card; nothing is clipped in dark. Put right what is wrong and draw again. A screen is not done until its pictures have been looked at.

- [x] **Step 5: Run the app's tests**

Run: `cd LineupApp && swift build && swift test`
Expected: all pass, no warnings.

- [x] **Step 6: Commit**, naming the directory the pictures were checked in.

---

### Task 7: Documents and the last check

**Files:**
- Modify: `CLAUDE.md`, this plan

- [x] **Step 1: Run everything once more**

Run: `cd LineupEngine && swift test` and `cd LineupApp && swift build && swift test`
Expected: all pass, no warnings.

- [x] **Step 2: Bring `CLAUDE.md` up to date.**
  - The list of plans at the top: this plan and its design, complete.
  - The Advisors paragraph, at `ImportanceAdvisor`: the league situation and its four bases; that the strength can be read from a pasted squad, how, and that the lines are the tool's own estimate.
  - The `advise` command: `--league-situation`.
  - The app section: the "League situation" menu and "Use it" on the Fixtures table; "Paste their squad" in the editor, what it keeps and what it does not; where the pictures were checked (`.build/pictures-opponent`).

- [x] **Step 3: Add this plan's closing sections**, as the earlier plans have them: what changed during the build, and the limits and small faults left. Among the limits, whatever else the build finds: no real opponent squad has been through the importer; the strength lines have no test behind them; the best eleven are the eleven best fit players whatever their positions, so a side with no fit goalkeeper reads stronger than it is; a name typed differently from the game's leaves a loanee out, which the reading shows but does not put right; a reading is not refreshed when the owner's own squad is imported again; home or away is not recorded.

- [x] **Step 4: Commit** the documents.

- [ ] **Step 5: Leave to the owner**, and say so in the hand-over: installing with `tools/build_app.sh`; the first real paste of an opponent's squad from FMRTE, checked by hand; and, with that squad still on the clipboard, `tools/capture_fmrte_paste.sh opponent` so the tests can use a real opponent.

---

## Changes made while building

- **The design was revised twice before any code, with the owner's word, after the captured squads were checked.** FMRTE's team grid has no club column, so "their club" is the most common club on the rows when they carry one (the search grid) and otherwise the opponent as typed on the fixture; the reading lists the clubs its left-out players are away at. The best eleven became the eleven best fit players whatever their positions, because the owner's only first-team goalkeeper was injured on the day of the capture and the U21 goalkeeper was away on loan, so asking for a fit goalkeeper would have refused every paste. The own-club check became "more than half the pasted players are in the owner's squads", by identity.
- **Task 1: `situation:` is a required argument of `ImportanceAdvisor.suggest`**, so four test call sites in the app were given `.inContention` as well as the two in `AppModel+Advice.swift`.
- **Task 3: `FixturePresentation.swift` needed no change** for the editor's suggestion to follow the situation. `AppModel.suggestions` reads `settings` first on every path so that a view is told when the situation changes, and `update(_ settings:)` clears the kept suggestions too, so both routes agree.
- **Task 5: reading the clipboard and FMRTE's settings file became one helper**, shared by the squad import and the opponent paste. A test for an unreadable FMRTE settings file was added.
- **Task 6: "Use it" sits under a row's suggestion line, not beside it**, since the importance column has no room. The fixture editor's card went from 480 to 520 points wide so "Paste their squad" fits beside the strength menu. The suggestion line's mark now stays with its last word when the line wraps. Two sample-data builders give the pictures a draft with a reading and one with a refused paste.
- **The game plan research arrived during the build** (`docs/Research/fm27-match-simulation-game-plans.md`). It found nothing on how the game judges a favourite, and reports FM27 engine tests in which current ability had no measurable effect on results once attributes were held fixed. The design's Evidence section records this; the measure was built as approved.
- **The pictures were checked** in `LineupApp/.build/pictures-opponent`: `fixtures-*`, `fixtures-situation-*`, `fixtures-editor-reading-*` and `fixtures-editor-refused-*`. Light and dark are the same by design.
- **The app was not clicked through by hand, and was not installed** (Step 5 of this task is the owner's).

## Known limits and small faults left

- No real opponent squad has been through the importer. The tests use the owner's captured first team, keyed two ways.
- The strength lines (5% and 15%) are the tool's own estimate with no test behind them.
- Current ability is a stand-in: FM27 engine tests found results come from attributes, not ability. A measure built from attributes is a possible later change.
- The best eleven are the eleven best fit players whatever their positions, so a side with no fit goalkeeper reads stronger than it is.
- A name typed differently from the game's ("Banbury" for "Banbury United") leaves a loanee there out. The reading lists his club, which shows it but does not put it right.
- A reading is not refreshed when the owner's own squad is imported again, and it keeps the club's name it was read for if the opponent is renamed afterwards. Pasting again puts both right.
- Injuries are as each side's latest paste showed them.
- Home or away is not recorded on a fixture.
- The league situation is one choice for every league fixture; cups have no stage.
- Small faults: the list of clubs in a reading sorts capitals before lower case, and "as first spelt" follows the order of the pasted rows; the league reason lines repeat the situations' names in lower case rather than building on them; the command line's `--league-situation` has no test; `setLeagueSituation` saves even when the value is unchanged; a few tests assert less than their names say (the nil-clipboard case, which refusal the too-few-own-players test gets, the no-`Id` test, the half-second boundary resting on floating-point sums); VoiceOver may read the suggestion line's mark; the look of "Use it" in the live window has not been checked by hand, since pictures draw an inactive window.

## For the owner

- Install with `tools/build_app.sh` from the repository root. It was not run in this build.
- Check the first real paste of an opponent's squad from FMRTE by hand: the club it finds, the players it leaves out, and the strength it gives.
- With that squad still on the clipboard, run `tools/capture_fmrte_paste.sh opponent` so the tests can use a real opponent.
- The two strength lines and the four league bases are in `EngineParameters` (`opponentStrengthLines` and the league bases), one line each to change.
