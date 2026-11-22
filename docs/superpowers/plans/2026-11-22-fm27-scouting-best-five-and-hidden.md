# Scouting: the best five at each position, and hidden candidates. Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The Candidates tab shows at most the best five players in each group, lets the owner hide a player until he shows him again, and shows each player's current and potential ability beside his positions.

**Architecture:** The engine learns who is hidden (a name and a potential ability) and leaves those players out of the candidates, returning them apart; it also splits its two mixed parts into one group for each slot. Core saves the hidden players in a file of their own, cuts each group's rows to five with the others behind a line, and builds the hidden list. The views add a button, a line and a list.

**Tech Stack:** Swift 6, macOS 26, SwiftUI and Observation, Swift Testing, Foundation only. Two packages: `LineupEngine/` and `LineupApp/` (targets `LineupAppCore`, `LineupAppUI`, `LineupApp`).

**Spec:** `docs/superpowers/specs/2026-11-22-fm27-scouting-best-five-and-hidden-design.md`. Read it before any task. The project's rules are in `CLAUDE.md`; its Scouting paragraph and its "New code: `LineupApp/`" section describe what exists.

## Global Constraints

- Work on branch `fm27-native`. Commit after each task, with a message that says why, ending with the line `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`. No merge, no pull request, no push unless asked.
- Test output must be clean: no build warnings in either package.
- The engine uses Foundation only, has no UI and reads no files. Every rule gets a test where it changes an outcome and a test where it does not.
- Every word about advice comes from the engine (`AdvisorText`, `PositionText`), shown as written. Core holds only plain labels and headings: here "Hide", "Show again", "3 hidden players", "12 more players", "CA 78 · PA 82".
- A view holds layout only. Every colour, typeface and measure comes from `Theme`. Logic for a screen lives in `LineupAppCore` with tests.
- Nothing in a test, a picture run or a sample-data run touches `~/Library/Application Support` or the real clipboard.
- Do not modify the old Python, `ui/`, the `.bat` files or the root-level data files.
- The five is fixed: `ScoutingPresentation.shownInGroup = 5`. The guard is half a second: `AppModel.scoutingActionInterval = 0.5`.
- The pasted players are still held in memory only. The new file holds, for each hidden player, his name as pasted and his potential ability, and nothing else.
- `scout` on the command line takes no hidden players and prints every candidate.
- The engine's tests take about a minute (`cd LineupEngine && swift test`). The app's take seven minutes or more: during a task run the named suites with `swift test --filter`, and run the whole suite in the background at the end of Tasks 3, 4 and 5.

## Review Focus

Conditions the design implies and a person will meet, each pinned by a test in the task named:

1. The same player hidden twice, or two saved entries for one player: "Show again" brings him back at once, not after a second click (Task 3).
2. One paste holding the same player on two rows, or two namesakes with one potential ability: hiding one hides both, both are listed as hidden, and "Show again" on either returns both (Task 3).
3. "Hide" arriving for a player no longer held (the paste was replaced or cleared while the click waited): nothing happens and nothing is saved (Task 3).
4. `scouting.json` on disk is not readable: the app starts with nobody hidden and a notice, keeps the file aside, and hiding then works and saves (Task 3).
5. A player hidden while one tactic is shown is hidden for every other tactic (Task 3).

## Files

| File | Change |
|---|---|
| `LineupEngine/Sources/LineupEngine/Advisors/ScoutingCandidates.swift` | `HiddenCandidate`; `Scouting.candidates` leaves hidden players out; `CandidatesReport.hidden`; groups by slot in the two mixed parts |
| `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText+Scouting.swift` | `groupHeading(slot:)` |
| `LineupEngine/Sources/lineup-cli/Report.swift` | the heading of the split groups |
| `LineupEngine/Tests/LineupEngineTests/ScoutingCandidatesTests.swift`, `ScoutingTextTests.swift` | new tests |
| `LineupApp/Sources/LineupAppCore/ScoutingState.swift` (new) | `ScoutingState` |
| `LineupApp/Sources/LineupAppCore/Store.swift`, `AppModel.swift` | `StoreFile.scouting`, loading and saving |
| `LineupApp/Sources/LineupAppCore/AppModel+Scouting.swift` | `hideCandidate`, `showCandidateAgain`, the guard, hidden players handed to the engine |
| `LineupApp/Sources/LineupAppCore/ScoutingPresentation.swift` | the cut, the hidden list, the ability figures, the labels |
| `LineupApp/Sources/LineupAppCore/Navigation.swift` | which lines are open |
| `LineupApp/Sources/LineupAppCore/SampleData.swift` | two sample models for the pictures |
| `LineupApp/Sources/LineupAppUI/Advice/ScoutingCandidatesTab.swift`, `ScoutingScreen.swift`, `RootView.swift`, `Theme.swift` | the button, the line, the list, `ScoutingStart` |
| `LineupApp/Sources/LineupApp/main.swift` | the new pictures and their usage text |
| `LineupApp/Tests/LineupAppCoreTests/ScoutingTests.swift`, `ScoutingPresentationTests.swift`, `StoreTests.swift` | new tests |
| `CLAUDE.md`, the two scouting designs, this plan | brought into line (Task 6) |

---

### Task 1: The engine leaves hidden players out

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/ScoutingCandidates.swift`
- Test: `LineupEngine/Tests/LineupEngineTests/ScoutingCandidatesTests.swift`

**Interfaces:**
- Produces:
  - `public struct HiddenCandidate: Codable, Hashable, Sendable { public let name: String; public let potentialAbility: Int; public init(name: String, potentialAbility: Int); public init(_ player: Player); public func matches(_ player: Player) -> Bool }`
  - `Scouting.isHidden(_ pasted: Player, among hidden: [HiddenCandidate]) -> Bool`
  - `Scouting.candidates(pasted:held:hidden:ownClub:tactic:needs:catalog:profile:parameters:)`: the new parameter is `hidden: [HiddenCandidate] = []`, after `held`. The default means nobody hidden, the state before this plan.
  - `CandidatesReport.hidden: [Player]`: the pasted players left out as hidden, as pasted, in paste order.

- [ ] **Step 1: Write the failing tests** in `ScoutingCandidatesTests`, using the suite's `candidate(_:level:also:edit:)` and a small `report` helper that passes `hidden:`:

```swift
@Test func aHiddenPlayerIsLeftOutAndReturnedApart() throws {
    let players = try PlannerFixture.squad()
    let a = candidate(.D_L, level: 15) { $0.name = "Abdi Sharif"; $0.id = PlayerID(key: "abdi sharif"); $0.potentialAbility = 120 }
    let b = candidate(.D_L, level: 15) { $0.name = "Brad Walker"; $0.id = PlayerID(key: "brad walker"); $0.potentialAbility = 120 }
    let r = try report([a, b], hidden: [HiddenCandidate(a)], players: players)
    #expect(r.candidates.map(\.player.name) == ["Brad Walker"])
    #expect(r.hidden == [a])
    #expect(r.groups(orderedBy: .today).flatMap(\.candidates).map(\.player.name) == ["Brad Walker"])
}
@Test func withNobodyHiddenTheReportIsAsBefore() throws {
    let players = try PlannerFixture.squad()
    let a = candidate(.D_L, level: 15)
    let r = try report([a], hidden: [], players: players)
    #expect(r.candidates.count == 1 && r.hidden.isEmpty)
}
@Test func aHiddenPlayerIsKnownByNameAsNormalisedAndPotentialAbilityOnly() {
    let p = candidate(.D_L, level: 15) { $0.name = "Abdi Sharif"; $0.potentialAbility = 120; $0.age = 26 }
    #expect(HiddenCandidate(name: "abdi  SHARIF", potentialAbility: 120).matches(p))   // as PlayerID.normalise compares
    #expect(!HiddenCandidate(name: "Abdi Sharif", potentialAbility: 121).matches(p))   // a namesake
    #expect(!HiddenCandidate(name: "Abdi Sharifi", potentialAbility: 120).matches(p))
    var older = p; older.age = 27
    #expect(HiddenCandidate(p).matches(older))                                          // a birthday changes nothing
}
@Test func aHeldPlayerWhoIsAlsoHiddenIsLeftOutAsHeld() throws {
    let players = try PlannerFixture.squad()
    let own = try #require(players.first)
    let r = try report([own], hidden: [HiddenCandidate(own)], players: players)
    #expect(r.leftOut == [own.name] && r.hidden.isEmpty)
}
@Test func hiddenPlayersDoNotCountTowardsTheEvidence() throws {
    let players = try PlannerFixture.squad()
    let a = candidate(.D_L, level: 15)
    let r = try report([a], hidden: [HiddenCandidate(a)], players: players)
    #expect(r.candidates.isEmpty && r.basis == nil && r.hidden.count == 1)
}
@Test func aHiddenCandidateRoundTripsAsJSONAndNeedsBothKeys() throws {
    let h = HiddenCandidate(name: "Abdi Sharif", potentialAbility: 120)
    #expect(try JSONDecoder().decode(HiddenCandidate.self, from: JSONEncoder().encode(h)) == h)
    #expect(throws: DecodingError.self) { try JSONDecoder().decode(HiddenCandidate.self, from: Data(#"{"name":"A"}"#.utf8)) }
}
```

If `PlayerID.normalise` does not fold the doubled space or the capitals in the third test, use a spelling it does fold; the assertion is that the comparison is `PlayerID.normalise`'s, whatever that is.

- [ ] **Step 2: Run them and see them fail to compile**

Run: `cd LineupEngine && swift test --filter ScoutingCandidatesTests`
Expected: build error, `HiddenCandidate` not found.

- [ ] **Step 3: Implement** in `ScoutingCandidates.swift`: `HiddenCandidate` beside `CandidateCaution` (`init(_ player:)` takes the name as pasted and `player.potentialAbility`; `matches` compares `PlayerID.normalise` of the two names and the two potential abilities); `Scouting.isHidden` beside `isHeld`; in `Scouting.candidates`, test `isHeld` first, then `isHidden`, appending the player to a `hidden` list and continuing before anything is rated; `CandidatesReport.hidden`, documented as `leftOut` is.

- [ ] **Step 4: Run the suite, then the whole engine**

Run: `cd LineupEngine && swift test --filter ScoutingCandidatesTests && swift test 2>&1 | tail -5`
Expected: all pass, no warnings.

- [ ] **Step 5: Commit**

```bash
git add LineupEngine
git commit -m "Let the engine leave hidden players out of the candidates

The owner wants to put aside a player whose signing fell through. The
search grid has no id and age changes at a birthday, so a hidden player
is known again by his name and potential ability; the engine holds that
rule beside the one for players already his, and returns the hidden
players apart so the app can list them.

Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>"
```

---

### Task 2: One group for each position in the two mixed parts

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Advisors/ScoutingCandidates.swift` (`CandidateGroup`, `CandidatesReport`, `groups(orderedBy:)`, the end of `Scouting.candidates`)
- Modify: `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText+Scouting.swift`
- Modify: `LineupEngine/Sources/lineup-cli/Report.swift` (`candidates(_:read:money:)`, about line 199)
- Modify: `LineupApp/Sources/LineupAppCore/ScoutingPresentation.swift` (the heading in `candidatesSheet`)
- Test: `LineupEngine/Tests/LineupEngineTests/ScoutingCandidatesTests.swift`, `ScoutingTextTests.swift`, `LineupApp/Tests/LineupAppCoreTests/ScoutingPresentationTests.swift`

**Interfaces:**
- Produces:
  - `groups(orderedBy:)` returns, for `.wouldStartElsewhere` and for `.couldPassElsewhere`, one `CandidateGroup` for each slot that has a player, in the tactic's slot order, with `slot` set and `answer` nil. The order within a group is unchanged. `.rest` stays one group with `slot` nil.
  - `AdvisorText.groupHeading(slot: SlotID) -> String`: the position alone, capitalised: "Right back".
  - `CandidateGroupRows.heading` (Core) is `groupHeading(slot:answer:)` with an answer, `groupHeading(slot:)` with a slot and no answer, nil with neither. A group's `id` is unchanged in form (part, slot and answer joined by "-").

- [ ] **Step 1: Write the failing engine tests**

```swift
// ScoutingCandidatesTests
@Test func wouldStartElsewhereIsOneGroupForEachSlotInTheTacticsOrder() throws {
    let players = try PlannerFixture.squad()                    // no better-player need at these slots
    let ten = candidate(.AM_C, level: 16) { $0.name = "ten"; $0.id = PlayerID(key: "ten") }
    let rightBack = candidate(.D_R, level: 16) { $0.name = "right back"; $0.id = PlayerID(key: "right back") }
    let other = candidate(.AM_C, level: 15) { $0.name = "other ten"; $0.id = PlayerID(key: "other ten") }
    let groups = try report([ten, rightBack, other], players: players).groups(orderedBy: .today)
        .filter { $0.part == .wouldStartElsewhere }
    #expect(groups.map(\.slot) == [.D_R, .AM_C])                // the tactic's slot order, not the paste's
    #expect(groups.allSatisfy { $0.answer == nil })
    #expect(groups.map { $0.candidates.map(\.player.name) } == [["right back"], ["ten", "other ten"]])
}
@Test func couldPassElsewhereIsOneGroupForEachSlotToo() throws { /* two growers of 19 at two fine slots, as
    `couldPassElsewhereIsOrderedByReachMarginInBothOrders` builds them: two groups, each slot set, in the tactic's order */ }
@Test func theRestStaysOneGroupWithNoSlot() throws { /* players below cover at two slots: one `.rest` group, slot nil */ }
```

If the fixture squad has a need at `.D_R` or `.AM_C`, use two slots that `needs(players).fine` lists; the suite's existing tests at lines 214 and 341 show `.AM_C` is one.

```swift
// ScoutingTextTests
@Test func aGroupHeadingWithNoNeedIsThePositionAlone() {
    #expect(AdvisorText.groupHeading(slot: .D_R) == "Right back")
    #expect(AdvisorText.groupHeading(slot: .GK) == "Goalkeeper")
}
```

- [ ] **Step 2: Run and see them fail**

Run: `cd LineupEngine && swift test --filter "ScoutingCandidatesTests|ScoutingTextTests"`
Expected: FAIL (one group where two are expected; `groupHeading(slot:)` not found).

- [ ] **Step 3: Implement.** `CandidatesReport` keeps `let slotOrder: [SlotID]` (the tactic's assignments' slots, in order, set where the report is built); in `groups(orderedBy:)` the two `add(…, nil, nil)` calls for the mixed parts become a loop over `slotOrder`. Update the doc comments on `CandidateGroup.slot` and on `groups`. Add `groupHeading(slot:)`. In `Report.swift`, a group with a slot and no answer prints its part name, " - ", then `groupHeading(slot:)`. Fix the existing tests that counted one group per mixed part only where they now see more than one.

- [ ] **Step 4: Core's heading.** Add to `ScoutingPresentationTests` a test that a `wouldStartElsewhere` group's heading is `AdvisorText.groupHeading(slot:)` for its slot and that only the first group of the part carries `partTitle`; change `candidatesSheet` to give it.

- [ ] **Step 5: Run both packages' scouting tests, then the whole engine**

Run: `cd LineupEngine && swift test 2>&1 | tail -5; cd ../LineupApp && swift test --filter "ScoutingPresentationTests|ScoutingTests" 2>&1 | tail -5`
Expected: all pass, no warnings.

- [ ] **Step 6: Check the command line** with the command under "Judge players pasted" in `CLAUDE.md`, leaving `--u21` off as it says. Expected: any "Would start where you have no need" heading is followed by " - " and a position.

- [ ] **Step 7: Commit** (`git add LineupEngine LineupApp`), saying that the best five are to be the best at a position in every part, so the two parts that mixed positions are split.

---

### Task 3: Hidden players saved, hidden and shown again

**Files:**
- Create: `LineupApp/Sources/LineupAppCore/ScoutingState.swift`
- Modify: `LineupApp/Sources/LineupAppCore/Store.swift`, `AppModel.swift` (stored property, `init`, `save(_:)`), `AppModel+Scouting.swift`
- Test: `LineupApp/Tests/LineupAppCoreTests/ScoutingTests.swift`, `StoreTests.swift`

**Interfaces:**
- Consumes: `HiddenCandidate`, `Scouting.candidates(…hidden:…)`, `CandidatesReport.hidden` (Task 1).
- Produces:
  - `public struct ScoutingState: Equatable, Codable, Sendable { public var hidden: [HiddenCandidate]; public init() }` (empty at `init()`).
  - `StoreFile.scouting`, file `scouting.json`: `description` "your hidden candidates", `startsWith` "the list starts empty", `missingSubject` "hidden candidates", `isNoticedWhenMissing` false.
  - `AppModel.scouting: ScoutingState` (`public internal(set)`).
  - `AppModel.scoutingActionInterval: TimeInterval = 0.5` (static).
  - `AppModel.hideCandidate(_ id: PlayerID, for chosen: UUID?)` and `AppModel.showCandidateAgain(_ id: PlayerID, for chosen: UUID?)`. `id` is the pasted player's key; `chosen` is the tactic the screen shows (`navigation.scoutingTacticID`), used only to judge the candidates again before the guard's clock is read.

**Behaviour:**
- `hideCandidate`: finds the player with that key in `scoutingPaste`; with none held, does nothing and saves nothing. Appends `HiddenCandidate(player)` unless an entry already matches him. Saves `.scouting`, clears `adviceCache?.candidates` for every tactic, does not plan.
- `showCandidateAgain`: finds the player the same way; removes every entry that matches him; saves; clears the same cache; does not plan.
- Both run through one guard, `scoutingAction(for:_:)`, shaped as `trainingAction` is (`AppModel+Training.swift`): ignored within `scoutingActionInterval` of the end of the last of either that ran; after the action it reads `candidates(for: chosen)` and then the clock, into `@ObservationIgnored var lastScoutingAction: TimeInterval?`. Its clock is apart from Training's.
- `workedOutCandidates` hands `scouting.hidden` to the engine.
- `pasteCandidates`, `clearCandidates` and `hold` leave `scouting` alone.
- `init` loads the file as the league's is loaded, adds its notice, and writes it when missing or kept aside.

- [ ] **Step 1: Write the failing tests.** In `StoreTests`, beside the fitness file's tests (about line 380): the case exists, its raw value is "scouting", it is not noticed when missing; an unreadable `scouting.json` loads as `ScoutingState()` with a notice starting "Your hidden candidates could not be read as saved data" and is kept aside as `scouting.unreadable-1.json`. In `ScoutingTests`, with `ScoutingSetup.ready()` and `ScoutingSetup.paste(t)`, and a helper `advance(_ t:)` that moves the scripted clock past the interval (see how the Training tests do it):

```swift
@Test func hidingLeavesThePlayerOutSavesTheFileAndDoesNotPlan() throws {
    let t = try ScoutingSetup.ready(); try ScoutingSetup.paste(t)
    let before = try ScoutingSetup.report(t.model)
    let victim = try #require(before.candidates.first)
    let planned = t.model.timesPlanned
    t.model.hideCandidate(victim.id, for: nil)
    let after = try ScoutingSetup.report(t.model)
    #expect(after.candidates.map(\.id) == before.candidates.map(\.id).filter { $0 != victim.id })
    #expect(after.hidden.map(\.id) == [victim.id])
    #expect(t.model.scouting.hidden == [HiddenCandidate(victim.player)])
    #expect(t.model.timesPlanned == planned)
    #expect(t.reopened().scouting.hidden == [HiddenCandidate(victim.player)])       // across a restart
}
@Test func aHiddenPlayerStaysHiddenAfterClearAndANewPaste() throws { /* hide, clearCandidates, paste again: still in report.hidden */ }
@Test func showAgainBringsHimBackAndSaves() throws { /* hide, advance, showCandidateAgain: candidates as before, scouting.hidden empty, reopened() empty */ }
@Test func aSecondClickInsideHalfASecondDoesNothing() throws {
    /* two candidates a, b: hide a then hide b with the clock moved by less than 0.5 s: only a hidden;
       then showCandidateAgain(a) inside the interval of that hide: still hidden (one clock for the two);
       after advance, hide b: both hidden */
}
@Test func hidingChangesNoOtherFileAndNoOtherAdvice() throws {
    /* ScoutingSetup.storeFiles before and after a hide differ only in "scouting.json"; adviceState is the same value;
       the squad book and marks are equal */
}
@Test func statesSavedBeforeThisPlanOpenWithNoNoticeAndNobodyHidden() throws {
    /* delete scouting.json from t.directory, reopened(): notices empty, scouting == ScoutingState(), and the file exists again */
}
// Review Focus
@Test func hidingAHiddenPlayerAgainAddsNoSecondEntryAndTwoEntriesAreBothRemoved() throws {
    /* write scouting.json holding the same HiddenCandidate twice, reopened(), paste: hidden once in report.hidden;
       showCandidateAgain: scouting.hidden empty and he is a candidate. Separately: hide, advance, hide the same id
       (still found in the paste): one entry */
}
@Test func theSamePlayerOnTwoRowsIsHiddenAndShownTogether() throws {
    /* a paste whose first row is repeated (ScoutingSetup.paste(t, paste:)); if the importer refuses a repeated row,
       build the ScoutingPaste by hand with the player twice under two keys and `t.model.hold(_:)`:
       hide one key: report.hidden has both; showCandidateAgain on the other key: both are candidates */
}
@Test func hidingAPlayerNoLongerHeldDoesNothing() throws {
    /* take an id, clearCandidates(), hideCandidate(id): scouting.hidden empty and storeFiles unchanged */
}
@Test func anUnreadableFileStartsEmptyWithANoticeAndHidingThenSaves() throws {
    /* write "{" to scouting.json, reopened(): one notice, hidden empty, scouting.unreadable-1.json exists;
       paste and hide on that model: a third model on the directory has the entry */
}
@Test func aPlayerHiddenUnderOneTacticIsHiddenUnderEveryTactic() throws {
    /* add a second saved tactic (a copy of the sample under another name); read candidates for both; hide while the
       first is chosen; candidates(for: second) no longer has him and lists him as hidden */
}
```

- [ ] **Step 2: Run and see them fail to compile**

Run: `cd LineupApp && swift test --filter "ScoutingTests|StoreTests" 2>&1 | tail -20`
Expected: build errors for `scouting`, `hideCandidate`, `StoreFile.scouting`.

- [ ] **Step 3: Implement** as under Interfaces and Behaviour. Every `switch` over `StoreFile` is exhaustive with no `default`, so the compiler lists each place; extend the comment on `isNoticedWhenMissing`.

- [ ] **Step 4: Run the two suites, then the whole app suite in the background**

Run: `cd LineupApp && swift test --filter "ScoutingTests|StoreTests" 2>&1 | tail -5`, then `swift test 2>&1 | tail -5` in the background.
Expected: all pass, no warnings. Existing tests that list the store's files or `StoreFile.allCases` may need the new file added.

- [ ] **Step 5: Commit** (`git add LineupApp`), saying the owner chose hidden players that stay hidden across pastes and restarts, so they are the one thing about a pasted player that is saved.

---

### Task 4: The sheet: five rows, the line, the hidden list and the two abilities

**Files:**
- Modify: `LineupApp/Sources/LineupAppCore/ScoutingPresentation.swift`, `Navigation.swift`, `AppModel+Scouting.swift` (`allCandidateRowIDs`, and `allCandidateGroupIDs` below)
- Test: `LineupApp/Tests/LineupAppCoreTests/ScoutingPresentationTests.swift`, and `Captures` in the tests' `Support` folder for the captured search

**Interfaces:**
- Consumes: `CandidatesReport.hidden` (Task 1), the groups by slot (Task 2), `AppModel.scouting` (Task 3).
- Produces, in `ScoutingPresentation.swift`:
  - `ScoutingPresentation.shownInGroup = 5`, `hideButton = "Hide"`, `showAgainButton = "Show again"`.
  - `ScoutingPresentation.hiddenLine(_ count: Int) -> String`: "3 hidden players", "1 hidden player".
  - `ScoutingPresentation.abilityText(current: Int, potential: Int) -> String`: "CA 78 · PA 82".
  - `ScoutingPresentation.details(of player: Player, money: MoneyStyle) -> String`: the whole details line, used by a row and by the hidden list: age, positions, the two abilities, then club, on loan, asking price and wage as now, joined by " · ".
  - `ScoutingCandidateRow.detailsText` is that line (a stored `let`, no longer assembled from the row's parts; drop the fields only it used if nothing else reads them).
  - `CandidateGroupRows.rows`: the rows always shown: the first `shownInGroup` for a group that is not the rest, every row for the rest.
  - `CandidateGroupRows.moreRows: [ScoutingCandidateRow]`: those after them, in order; empty for the rest.
  - `CandidateGroupRows.moreLine: String?`: `restLine(moreRows.count)`; nil when `moreRows` is empty. (`closedLine` stays the rest's.)
  - `public struct ScoutingHiddenRow: Identifiable, Equatable, Sendable { public let id: PlayerID; public let name: String; public let detailsText: String }`
  - `CandidatesSheet.hidden: [ScoutingHiddenRow]` in paste order, and `CandidatesSheet.hiddenLine: String?`, nil with none.
  - `CandidatesSheet.rowIDs` covers `rows` and `moreRows`; `CandidatesSheet.groupIDs: Set<String>` is the ids of the groups that have a `moreLine`.
  - `AppModel.allCandidateGroupIDs(for chosen: UUID?) -> Set<String>`, beside `allCandidateRowIDs`.
- Produces, in `Navigation.swift`:
  - `public var scoutingMoreOpen: Set<String> = []`, `public func toggleScoutingMore(_ id: String)`, `public func closeScoutingLines()` (empties `scoutingMoreOpen`), `public var scoutingHiddenOpen = false`.

- [ ] **Step 1: Write the failing tests** in `ScoutingPresentationTests`. Build reports the way the suite already does; for groups over five, paste the captured search (`scouting-search.tsv` with `scouting-search.grids.json`; add both to `Captures`) through `ScoutingSetup.paste(t, paste:grids:)`.

```swift
@Test func aGroupOverFiveShowsItsBestFiveAndCountsTheOthers() throws {
    let t = try ScoutingSetup.ready(); try ScoutingSetup.paste(t, paste: Captures.search, grids: Captures.searchGrids)
    let report = try ScoutingSetup.report(t.model)
    for order in CandidateOrder.allCases {
        let sheet = try #require(t.model.candidatesSheet(report, order: order))
        let groups = report.groups(orderedBy: order)
        #expect(sheet.groups.count == groups.count)
        for (shown, group) in zip(sheet.groups, groups) {
            let ids = group.candidates.map(\.id)
            if shown.isRest {
                #expect(shown.rows.map(\.id) == ids && shown.moreRows.isEmpty && shown.moreLine == nil)
            } else {
                #expect(shown.rows.map(\.id) == Array(ids.prefix(5)))                 // the engine's order decides the five
                #expect(shown.moreRows.map(\.id) == Array(ids.dropFirst(5)))
                #expect(shown.moreLine == (ids.count > 5 ? ScoutingPresentation.restLine(ids.count - 5) : nil))
            }
        }
        #expect(sheet.groups.contains { $0.moreLine != nil })                          // the capture does have such a group
        #expect(sheet.groupIDs == Set(sheet.groups.filter { $0.moreLine != nil }.map(\.id)))
        #expect(sheet.rowIDs == Set(report.candidates.map(\.id)))
    }
}
@Test func aGroupOfFiveHasNoLineAndOneOfSixSaysOneMorePlayer() throws {
    /* from the captured search, hold only the first 6 players of its largest non-rest group (t.model.hold):
       moreLine == "1 more player", rows.count == 5; hide one (hideCandidate, Task 3): rows.count == 5, moreLine nil,
       and the sixth is now the fifth row */
}
@Test func changingTheOrderChangesWhichFiveAreShown() throws {
    /* a group of the captured search whose Today and Later orders differ in their first five (find one; #require it):
       the two sheets' rows for that group id differ, and each is the prefix of its own order */
}
@Test func theHiddenListNamesEachHiddenPlayerWithHisDetails() throws {
    /* sample paste, hide two: sheet.hidden.map(\.id) is the two in paste order; hiddenLine == "2 hidden players";
       each detailsText == ScoutingPresentation.details(of: player, money: paste.money); with one, "1 hidden player";
       with none, hidden empty and hiddenLine nil */
}
@Test func aPasteWithEveryPlayerHiddenShowsTheLinesAndTheHiddenListAndNoGroups() throws {
    /* hide every candidate (advancing the clock between): candidates(for:) is .ready, sheet.groups empty,
       sheet.hidden.count == the candidates', readLine unchanged, evidenceNote nil */
}
@Test func theDetailsLineCarriesTheTwoAbilitiesAfterThePositions() throws {
    /* extend the existing detailsText test (about line 300): "Age 19 · D/WB L · CA 112 · PA 140 · Banbury United · …"
       with the player's own numbers; and ScoutingPresentation.abilityText(current: 78, potential: 82) == "CA 78 · PA 82" */
}
@Test func theOpenLinesAreKeptByGroupAndClosedTogether() {
    let n = Navigation()
    n.toggleScoutingMore("answersToday-D_L-moreDepth"); #expect(n.scoutingMoreOpen == ["answersToday-D_L-moreDepth"])
    n.scoutingOrder = .later; #expect(n.scoutingMoreOpen.count == 1)                   // a change of order leaves it
    n.toggleScoutingMore("answersToday-D_L-moreDepth"); #expect(n.scoutingMoreOpen.isEmpty)
    n.toggleScoutingMore("a"); n.closeScoutingLines(); #expect(n.scoutingMoreOpen.isEmpty)
    #expect(n.scoutingHiddenOpen == false)                                             // closed at launch
}
```

- [ ] **Step 2: Run and see them fail**

Run: `cd LineupApp && swift test --filter ScoutingPresentationTests 2>&1 | tail -20`
Expected: build errors for the new names.

- [ ] **Step 3: Implement** as under Interfaces. `candidatesSheet` takes what it needs to build the hidden rows from `report.hidden` with the paste's money. The views still compile: `rows` keeps its name and now holds five.

- [ ] **Step 4: Run the suite, then the whole app suite in the background**

Run: `cd LineupApp && swift test --filter "ScoutingPresentationTests|ScoutingTests" 2>&1 | tail -5`, then `swift test 2>&1 | tail -5` in the background.
Expected: all pass, no warnings. The existing test that counts `rowIDs` as 6 still holds on the sample paste.

- [ ] **Step 5: Commit** (`git add LineupApp`), saying the owner pastes 100 players or more and asked for the best five at a position with the others one click away, and for the two abilities on every player's line.

---

### Task 5: The button, the line, the hidden list, and their pictures

**Files:**
- Modify: `LineupApp/Sources/LineupAppUI/Advice/ScoutingCandidatesTab.swift`, `ScoutingScreen.swift` (`ScoutingStart`), `RootView.swift`, `Theme.swift` (only if a new measure is needed)
- Modify: `LineupApp/Sources/LineupAppCore/SampleData.swift`, `ScoutingPresentation.swift` (the two VoiceOver labels), `LineupApp/Sources/LineupApp/main.swift` (`SampleState`, `sampleModel`, `drawScouting`, the usage text at the top)
- Test: `LineupApp/Tests/LineupAppCoreTests/` wherever `SampleData`'s other models are tested, and `ScoutingPresentationTests.swift` for the two labels ("Hide Brad Walker", "Show Brad Walker again")

**Interfaces:**
- Consumes: everything Tasks 3 and 4 produce.
- Produces:
  - `ScoutingStart` gains `moreOpen: Bool = false` (every group's line open) and `hiddenOpen: Bool = false`; `RootView` sets `navigation.scoutingMoreOpen = model.allCandidateGroupIDs(for: nil)` and `navigation.scoutingHiddenOpen` from them. `allOpen` also opens both.
  - `SampleData.modelWithCrowdedGroup(repositoryRoot:) throws -> AppModel`: the sample model holding, of the captured search (`captures/scouting-search.tsv`, read with `captures/scouting-search.grids.json`), only the players of its largest group outside the rest for the primary tactic in the Today order (the earliest on a tie). It throws `SampleDataError` when that group has fewer than seven players, so the line reads "more players".
  - `SampleData.modelWithHiddenCandidates(repositoryRoot:) throws -> AppModel`: `modelWithCandidates` with two of its candidates hidden through `hideCandidate` (the scripted clock moves a second at each reading, so neither is ignored). It throws when two are not hidden.

**The views** (layout only; the design's "Left to the builder" leaves the look to you, within `Theme` and the Tactics board direction in `docs/superpowers/specs/2026-11-13-fm27-app-visual-direction.md`):
- A candidate's row: a "Hide" button (`.buttonStyle(.secondary)`, `fixedSize`) at the trailing end of the name's line, in every part and in the opened lines. It is a sibling of the button that opens the row, never inside it. It calls `model.hideCandidate(row.id, for: navigation.scoutingTacticID)`. For VoiceOver its label names the player; the labels are built in Core: `ScoutingPresentation.hideLabel(_ name: String) -> String` ("Hide Brad Walker") and `showAgainLabel(_ name: String) -> String` ("Show Brad Walker again").
- Under a group's rows, when `group.moreLine` is not nil: the line drawn as `RestToggle` is (reuse it), toggling `navigation.toggleScoutingMore(group.id)`; while open, `group.moreRows` under it in the same lazy stack style.
- Under the groups and above the evidence note, when `sheet.hiddenLine` is not nil: the line as a `RestToggle` on `navigation.scoutingHiddenOpen`; while open, each `ScoutingHiddenRow` as a name over its details line (the faces a candidate's row uses) with "Show again" at the trailing end, calling `model.showCandidateAgain(row.id, for: navigation.scoutingTacticID)`.
- "Paste players" and "Clear" also call `navigation.closeScoutingLines()`.
- `ScoutingCandidatesTab`'s doc comment is brought up to date.

- [ ] **Step 1: Write the failing tests** for the two sample models: `modelWithCrowdedGroup` gives a sheet with exactly one group, at least seven candidates, five `rows` and a `moreLine`; `modelWithHiddenCandidates` gives `sheet.hidden.count == 2` and four rows across its groups. Both leave `~/Library` untouched as the other sample models do.

- [ ] **Step 2: Run and see them fail**, then implement the two sample models and run again.

Run: `cd LineupApp && swift test --filter SampleData 2>&1 | tail -5`
Expected: PASS after the implementation.

- [ ] **Step 3: Build the views**, and `swift build` with no warnings.

- [ ] **Step 4: Add the pictures** to `drawScouting`, and to the usage text at the top of `main.swift`:

| Variant | Model | Start | Shows |
|---|---|---|---|
| `candidates-crowded` | crowded group | Candidates | five rows with "Hide", then "N more players" closed |
| `candidates-crowded-open` | crowded group | `moreOpen: true`, a taller size | the same with the others under the line |
| `candidates-hidden` | hidden candidates | Candidates, tall | "2 hidden players" closed at the foot |
| `candidates-hidden-open` | hidden candidates | `hiddenOpen: true`, tall | the two with their details and "Show again" |

The existing `candidates-*` pictures are drawn again by the same run and now carry "Hide" and the abilities.

- [ ] **Step 5: Draw and look at the pictures**

Run: `cd LineupApp && swift run -q LineupApp --sample-data .. --pictures .build/pictures-hidden`
Then read, light and dark: `scouting-candidates-crowded-*`, `-crowded-open-*`, `-hidden-*`, `-hidden-open-*`, and again `scouting-candidates-*`, `-later-*`, `-open-*`, `-small-*`, `-refused-*`, `-empty-*`. Check: "Hide" lines up at the trailing end on every row and does not crowd a long name or the injury stamp; the details line reads "… · CA n · PA n · …" and wraps cleanly in the smallest window; the line under a group reads as the rest's line does; the hidden list is plainly apart from the groups; nothing overlaps. Fix and redraw until they are right. A screen is not done until its pictures have been looked at; the pictures draw buttons as an inactive window would.

- [ ] **Step 6: Run the whole app suite in the background**

Run: `cd LineupApp && swift test 2>&1 | tail -5`
Expected: all pass, no warnings.

- [ ] **Step 7: Commit** (`git add LineupApp`), saying what the owner can now do on the tab and which pictures were checked.

---

### Task 6: Bring the notes and the designs into line

**Files:**
- Modify: `CLAUDE.md`, `docs/superpowers/specs/2026-11-18-fm27-scouting-design.md`, `docs/superpowers/specs/2026-11-22-fm27-scouting-best-five-and-hidden-design.md`, this plan

- [ ] **Step 1: Count what the captured search shows.** With a throwaway test or print that is not committed, on `ScoutingSetup.ready()` with the captured search pasted: the rows shown outside the rest before this plan (every candidate not in the rest) and now (the sum of `rows` over the groups that are not the rest), and how many groups have a line.

- [ ] **Step 2: `CLAUDE.md`.** Add an entry for this plan to the list under "What this project is", in the form of its neighbours (plan, design, complete, what it does, what is left to the owner: the install, the first real paste of 100 players, hiding and showing a player in the running app, and the look of "Hide", which the pictures draw as an inactive window would). In the engine's Scouting paragraph: the two mixed parts are a group for each slot; a hidden player is known by name and potential ability and is returned apart; `scout` takes no hidden players. In the app's Scouting paragraph: the five and the line, "Hide" and "Show again" with their guard, the hidden list, the abilities on the details line, `scouting.json` and what it holds, that the pasted players are still never saved, and where the pictures were checked (`.build/pictures-hidden`). Update the two test counts and times with the numbers this build printed. Keep the file's plain style.

- [ ] **Step 3: The designs.** In the first scouting design's status line, one sentence pointing to the new design for the Candidates tab's cut and the hidden players, which wins where they differ. In the new design, set the status to built, with this plan's path, and replace "about 47" with the numbers from Step 1.

- [ ] **Step 4: This plan's closing sections.** Add "What the build showed on the captured search" (Step 1's numbers), "What changed during the build" and "Limits and small faults left" (the design's five limits, and anything found).

- [ ] **Step 5: Run both suites once more** (the app's in the background) and confirm they pass with no warnings.

- [ ] **Step 6: Commit** (`git add CLAUDE.md docs`), saying the notes now describe the tab as built.

---

## Added on 22 November 2026: two planner fixes

The owner asked for these while Task 6 was under way, from another session's findings on why his plan started a fringe young player in a low cup match. They are not scouting; they are built here because this was the work in hand. **Spec:** `docs/superpowers/specs/2026-11-22-fm27-minutes-and-development-favours-design.md`.

### Task 7: "Needs minutes" in a low fixture only for the elevens and favoured successors

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Planner/ImportanceRules.swift` (`needsSharpness`)
- Test: `LineupEngine/Tests/LineupEngineTests/ImportanceRulesTests.swift`

**Interfaces:**
- Produces: no new name. `needsSharpness` gives a `.low` fixture the gate a `.sharpness` fixture has: `context.tiers.slot(of: player.id) != nil`, or `isFavouredSuccessor` with sharpness under `sharpnessNeedFull`. The "Already sharp" mark-down stays a sharpness fixture's alone.

- [ ] **Step 1: Write the failing tests**

```swift
@Test func aLowFixtureFavoursOnlyTheElevensWhoNeedMinutes() {
    let p = Player.fixture(sharpness: 0.705)
    #expect(abs((every(run(p, .low, tiers: tiers(p, tier: 1)), .needsSharpness)?.factor ?? 0) - 1.25) < 1e-9)
    #expect(abs((every(run(p, .low, tiers: tiers(p, tier: 2)), .needsSharpness)?.factor ?? 0) - 1.25) < 1e-9)
    #expect(every(run(p, .low), .needsSharpness) == nil)                       // in neither eleven: none
    #expect(every(run(Player.fixture(sharpness: 0.46), .low), .needsSharpness) == nil)   // however unsharp
}
@Test func aFavouredSuccessorOutsideTheElevensStillNeedsMinutesInALowFixture() {
    /* as `aSuccessorCanBeGotSharpAndIsNotMarkedDownForBeingSharp` builds one: ×1.25 at 70.5% in `.low`;
       the same player with a band of `.possible` (no successor) gets none; a sharp successor gets none and is not marked down */
}
```

Existing tests of the low fixture's favour hand the player a place in an eleven where they mean a regular.

- [ ] **Step 2: Run and see them fail** — `cd LineupEngine && swift test --filter ImportanceRulesTests`; expected: the player in neither eleven is still favoured.
- [ ] **Step 3: Implement** the gate, and bring the function's comment into line.
- [ ] **Step 4: Run the whole engine suite**; fix tests that relied on a fringe player's favour, each with a line saying why its expectation moved.
- [ ] **Step 5: Commit**, saying the rule was for unsharp regulars and was favouring players for never playing.

### Task 8: The favour by age only for a player worth developing, and the notes

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Planner/ImportanceRules.swift` (`developmentFloor`)
- Test: `LineupEngine/Tests/LineupEngineTests/ImportanceRulesTests.swift`
- Modify: `CLAUDE.md`, `docs/superpowers/plans/2026-11-14-fm27-young-players-development.md` (the fault this closes), this plan's closing sections

**Interfaces:**
- Consumes: `Removal.isWorthDeveloping(_ outlook: Outlook) -> Bool` (exists, internal to the engine).
- Produces: no new name. `developmentFloor` asks `Removal.isWorthDeveloping(outlook)` where it asked `!outlook.isMarkedlyLower`. `successorSlots` is unchanged.

- [ ] **Step 1: Write the failing test**

```swift
@Test func onlyAPlayerWorthDevelopingIsFavoured() {
    let p = young(21)
    for level in [ReachLevel.couldPassFirst, .couldMakeSecond] {
        #expect(floorFactor(run(p, .low, outlooks: outlooks(p, level))) == 1.10, "\(level)")
    }
    #expect(floorFactor(run(p, .low, outlooks: outlooks(p, nil))) == 1.10)        // no level: first choice wherever he has a slot
    for level in [ReachLevel.couldBeCover, .markedlyLower] {
        #expect(floorFactor(run(p, .low, outlooks: outlooks(p, level))) == nil, "\(level)")
    }
}
@Test func aFirstChoiceWhoseReachElsewhereIsOnlyCoverIsFavoured() {
    /* as `aFirstChoiceWhoseOtherSlotIsMarkedlyLowerGetsTheFloor`, with the outlook's level `.couldBeCover` */
}
```

`aMarkedlyLowerPlayerIsNotFavoured` loses its `.couldBeCover` case to the first of these.

- [ ] **Step 2: Run and see it fail** — expected: the cover-level player is still favoured at 1.10.
- [ ] **Step 3: Implement**, and bring the function's comment into line.
- [ ] **Step 4: Run both whole suites** (the app's in the background); fix tests whose plans changed, each with a line saying why. Run the `plan` command from `CLAUDE.md` on the captured squad and note whether its lineups changed.
- [ ] **Step 5: The notes.** `CLAUDE.md`: the Planning paragraph's sentence on who is favoured by age, a sentence on "Needs minutes", the entry in the list at the top, and the test counts. The young players plan: mark its fault closed. This plan's closing sections: what changed.
- [ ] **Step 6: Commit.**

---

## What the build showed on the captured search

The owner's captured search of 109 players, read with its own layouts.

- Against the first team alone (the squad the app's tests use), for the sample 4-2-3-1: 13 groups outside the rest. Before this plan 65 rows were open; now 48 are, and three groups carry a line (12, 14 and 6 players, each showing five). 44 players are in the rest, closed as before.
- Against the first team and the U21s, by the command line's output: 76 rows were open in 12 groups; with every group cut to five, 47 are, in 13 groups (the three who would start where there is no need are now under right back and left attacking midfield), and five groups carry a line.
- On the sample squad the largest group is central attacking midfield, needing more depth, with 17 players: five shown and "12 more players". That group is what the `scouting-candidates-crowded-*` pictures draw.

No test is pinned to these numbers.

## What changed during the build

- **A heading over the hidden list.** The plan had the line "3 hidden players" under the groups. In the first picture it sat straight under "The rest" and read as part of it, so the list has a part's title, "Hidden" (`ScoutingPresentation.hiddenHeading`), over its line.
- **Two new test suites.** The hidden players' tests and the best-five tests are suites of their own (`ScoutingHiddenTests.swift`, `ScoutingBestFiveTests.swift`), not added to `ScoutingTests.swift` and `ScoutingPresentationTests.swift`: they stop the scripted clock, which otherwise moves a second at each reading, so that a double click can be told from two clicks.
- **The row keeps its fields.** The plan allowed the row's club, loan, price, wage, age and positions to be dropped once the details line was stored whole. Existing tests read them, so they stay beside it.
- **Core's heading test uses one slot.** The plan's test for the position-only heading used two slots with no need. In the tests' squad the second of them shares its position with a slot that has a need, so the test uses one slot no other shares; that a part's title is not repeated was already tested for every part.
- **A hidden player is not judged**, as the design says, and the engine has a test for it: one who cannot be rated stops the others only while he is not hidden.

## Limits and small faults left

The design's limits, as built:

- Two players with the same name and the same potential ability are hidden together, and shown again together.
- A hidden player whose potential ability changes in the game, or whose name FMRTE writes differently beyond case, accents and spacing, shows again.
- A hidden player can be shown again only while he is among the players pasted. One who is in no paste stays in the file and is shown nowhere.
- A player a best five leaves out is not offered at another position he could answer, short of opening the line or his row.
- A hidden player the owner later signs stays in the file, to no effect.

Found while building:

- The pictures draw buttons as an inactive window would, so the look of "Hide" and "Show again" in a live window is not checked, nor is where the list sits after a row is hidden, since a picture does not scroll.
- "Order by" changes which five a group shows while its line is closed. Nothing on screen says the five changed.
- The command line's `scout` prints every candidate and takes no hidden players.
