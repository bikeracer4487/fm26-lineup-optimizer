# FM27 Sale and Loan Marks Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The owner can mark a player "to sell" or "to loan out" on Player Removal, and the planner then favours him slightly in low-importance and sharpness fixtures, saying why on the pick.

**Architecture:** One new importance rule in the engine, with one parameter and its reason sentence; the planner is handed the marks with the rest of its request. The app keeps the marks in a versioned file of their own, hands them to the planner, and shows a control and the mark on each Player Removal row. Match Selection needs no change: it already shows every reason on a pick.

**Tech Stack:** Swift 6, macOS 26, SwiftUI and Observation, Swift Testing, Foundation only. Same packages and conventions as the earlier plans.

**Spec:** `docs/superpowers/specs/2026-11-14-fm27-sale-marks-design.md`. Research: `docs/Research/fm27-selling-and-loans.md`, `docs/Research/fm27-playing-time-and-transfer-interest.md`.

This plan is built before the mentoring plan (`2026-11-14-fm27-mentoring.md`). Both touch `EngineParameters.swift`, `Store.swift`, `AdvisorText.swift`, `ScreenPictures.swift` and `CLAUDE.md`; the changes do not overlap.

## Global Constraints

- Work on branch `fm27-native`. Never commit to `main`, merge, or open a pull request. Say why in every commit message.
- The engine decides; the app shows. A view never computes a rating, a reason or a rule. Every word about the marks (their names, the reason on a pick, the note) comes from the engine and is shown as written.
- Every tunable number lives in `EngineParameters` with an evidence label and a source. The factor is `1.03`, labelled `.derived`.
- Every rule gets a test where it changes an outcome and a test where it does not. Tests are written first.
- The same inputs always give the same lineup.
- Test output must be clean: no build warnings. Every `switch` over an engine enum is exhaustive, with no `default`.
- Logic for a screen lives in `LineupAppCore` with tests. Views hold layout only. Every colour, typeface and measure comes from `Theme`.
- Nothing the owner reads is an id or a code.
- A file that cannot be read gives a notice and a fresh start for that file, and the unreadable file is kept aside. No test, picture run or sample-data run touches `~/Library/Application Support` or the real clipboard.
- The old Python, `ui/` and root-level data files are reference only: do not modify them.
- The rule applies in `.low` and `.sharpness` fixtures only, to both kinds of mark alike, whatever the player's age, and on top of every other rule.

## Review Focus

Conditions the spec does not spell out and that are most likely to bite, most likely first. Each has its test in the task named.

1. **A marked player is sold and leaves every squad.** His mark should go at the next import, not sit in the file to favour him if he ever returns. Task 3, `aMarkGoesWhenThePlayerLeavesEverySquad`.
2. **A player marked to loan out goes out on loan.** The mark has done its work: it should go once an import shows him out on loan, so he is not favoured the day he comes back. A mark to sell stays. Task 3, `aLoanOutMarkGoesOnceHeIsOutOnLoan`.
3. **The marks file holds a word this version does not know** (hand-edited, or written by a later version). The owner should get the usual notice and a fresh start, with the file kept aside, not a crash or a silently dropped mark. Task 3, `aMarksFileWithAnUnknownMarkIsKeptAsideWithANotice`.
4. **Marking while a lineup is confirmed.** A confirmed lineup must not change; only the fixtures still planned are worked out again. Task 3, `markingDoesNotChangeAConfirmedLineup`.
5. **A row read by VoiceOver.** The mark must be part of what the row says, as its stamp and action are. Task 4, `aMarkedRowIsSpokenWithItsMark`.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `LineupEngine/Sources/LineupEngine/Planner/PlanInputs.swift` | modify | `SaleMark`, beside `Retraining` |
| `LineupEngine/Sources/LineupEngine/Selection/Adjustment.swift` | modify | the new kind, `shopWindow` |
| `LineupEngine/Sources/LineupEngine/Parameters/EngineParameters.swift` | modify | `shopWindowFactor` |
| `LineupEngine/Sources/LineupEngine/Planner/ImportanceRules.swift` | modify | `RuleContext.marks` and the rule |
| `LineupEngine/Sources/LineupEngine/Planner/Planner.swift` | modify | `PlanRequest.marks`, handed to the rule context |
| `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText.swift` | modify | the marks' names and the note |
| `LineupApp/Sources/LineupAppCore/Store.swift` | modify | `StoreFile.marks` |
| `LineupApp/Sources/LineupAppCore/AppModel.swift` | modify | loads, holds and saves the marks |
| `LineupApp/Sources/LineupAppCore/AppModel+Marks.swift` | create | setting and clearing a mark; dropping marks at import |
| `LineupApp/Sources/LineupAppCore/AppModel+Plan.swift` | modify | hands the marks to the planner |
| `LineupApp/Sources/LineupAppCore/RemovalPresentation.swift` | modify | the mark on a row, the choices, the labels |
| `LineupApp/Sources/LineupAppUI/Advice/RemovalScreen.swift` | modify | the control and the mark on a row |
| `LineupApp/Sources/LineupAppUI/ScreenPictures.swift` | modify | the `removal-marked` pictures |
| `CLAUDE.md` | modify | what the planner and Player Removal now do |

The command line does not take marks (the design left this to the builder): the engine's tests cover the rule, and the app is where marks are made.

---

### Task 1: The rule, its number and its words

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Planner/PlanInputs.swift`
- Modify: `LineupEngine/Sources/LineupEngine/Selection/Adjustment.swift`
- Modify: `LineupEngine/Sources/LineupEngine/Parameters/EngineParameters.swift`
- Modify: `LineupEngine/Sources/LineupEngine/Planner/ImportanceRules.swift`
- Modify: `LineupEngine/Sources/LineupEngine/Reporting/AdvisorText.swift`
- Test: `LineupEngine/Tests/LineupEngineTests/ImportanceRulesTests.swift`, `EngineParametersTests.swift`, `AdvisorTextTests.swift`, `PlanInputsTests.swift`

**Interfaces:**
- Produces:
  - `public enum SaleMark: String, Codable, CaseIterable, Sendable { case toSell, toLoanOut }`
  - `Adjustment.Kind.shopWindow`, placed after `development` and before `retraining`
  - `EngineParameters.shopWindowFactor: Parameter<Double>`
  - `RuleContext.marks: [PlayerID: SaleMark]`, a new last-but-one `init` parameter `marks: [PlayerID: SaleMark] = [:]` after `retraining`
  - `AdvisorText.name(_ mark: SaleMark) -> String` and `AdvisorText.marksNote: String`

- [ ] **Step 1: Write the failing tests**

In `ImportanceRulesTests`, give `context` and `run` a `marks: [PlayerID: SaleMark] = [:]` parameter passed through to `RuleContext`, then add:

```swift
// MARK: Marked to sell or loan out

@Test func aMarkedPlayerIsFavouredInALowOrSharpnessFixture() {
    let p = Player.fixture(age: 28, currentAbility: 100, potentialAbility: 100)
    for importance in [Importance.low, .sharpness] {
        let sell = every(run(p, importance, marks: [p.id: .toSell]), .shopWindow)
        #expect(sell?.factor == 1.03)
        #expect(sell?.reason == "Marked to sell: favoured for minutes, an untested way to bring offers (×1.03)")
        let loan = every(run(p, importance, marks: [p.id: .toLoanOut]), .shopWindow)
        #expect(loan?.factor == 1.03)
        #expect(loan?.reason == "Marked to loan out: favoured for minutes, an untested way to bring offers (×1.03)")
    }
}

@Test func aMarkDoesNothingInAMediumOrHighFixture() {
    let p = Player.fixture(age: 28, currentAbility: 100, potentialAbility: 100)
    #expect(every(run(p, .medium, marks: [p.id: .toSell]), .shopWindow) == nil)
    #expect(every(run(p, .high, marks: [p.id: .toSell]), .shopWindow) == nil)
}

@Test func anUnmarkedPlayerIsNotFavoured() {
    let p = Player.fixture(age: 28, currentAbility: 100, potentialAbility: 100)
    let other = Player.fixture(name: "Someone else")
    #expect(every(run(p, .low), .shopWindow) == nil)
    #expect(every(run(p, .low, marks: [other.id: .toSell]), .shopWindow) == nil)
}

@Test func aMarkedProspectGetsBothAndInKindOrder() {
    let p = Player.fixture(age: 19, currentAbility: 100, potentialAbility: 130)
    let kinds = run(p, .low, marks: [p.id: .toLoanOut]).everySlot.map(\.kind)
    #expect(kinds == [.development, .shopWindow])
}
```

A fifth test, `aFactorOfOneSwitchesTheRuleOff`: with a copy of the parameters whose `shopWindowFactor` is `Parameter(1, .derived, source: "test")`, a marked player in a `.low` fixture has no `.shopWindow` adjustment. Build the copy the way the suite's other tests change one parameter.

In `EngineParametersTests.theImportanceRuleParametersAreListedWithEvidenceAndSource`, add `"shopWindowFactor"` to `names` and `#expect(listed["shopWindowFactor"]?.evidence == .derived)`.

In `AdvisorTextTests`:

```swift
@Test func theMarksHaveTheirNamesAndTheNoteSaysItIsUntested() {
    #expect(AdvisorText.name(SaleMark.toSell) == "To sell")
    #expect(AdvisorText.name(SaleMark.toLoanOut) == "To loan out")
    #expect(AdvisorText.marksNote == "A marked player gets a little more playing time in low-importance and "
            + "sharpness fixtures. Whether playing a player brings offers has not been tested.")
}
```

In `PlanInputsTests`, pin the stored words, since the app saves them:

```swift
@Test func aMarkIsStoredByItsWord() throws {
    #expect(String(decoding: try JSONEncoder().encode([SaleMark.toSell, .toLoanOut]), as: UTF8.self) == #"["toSell","toLoanOut"]"#)
}
```

- [ ] **Step 2: Run them and see them fail**

Run: `cd LineupEngine && swift test --filter "ImportanceRulesTests|EngineParametersTests|AdvisorTextTests|PlanInputsTests"`
Expected: does not compile (`SaleMark`, `.shopWindow`, `marks:` unknown).

- [ ] **Step 3: Add `SaleMark`, the kind, the parameter and the context field**

- `SaleMark` in `PlanInputs.swift`, with a doc comment: the owner's mark on a player he means to sell or loan out.
- `shopWindow` in `Adjustment.Kind`, after `development`.
- `shopWindowFactor` in `EngineParameters` beside `developmentFactor`: declared, taken by the initialiser, listed in `all`, and set in `fm27` to

```swift
shopWindowFactor: Parameter(
    1.03, .derived,
    source: "this design's size, a tie-breaker: no test in any version shows that playing a player brings offers "
        + "(docs/Research/fm27-playing-time-and-transfer-interest.md, docs/Research/fm27-selling-and-loans.md)"),
```

- `marks` on `RuleContext`, defaulted to `[:]` in its initialiser so existing callers compile.

- [ ] **Step 4: Add the rule and the words**

`private static func shopWindow(_ player: Player, _ context: RuleContext, _ parameters: EngineParameters) -> [Adjustment]` in `ImportanceRules`, added to `everySlot` after `development`. It gives nothing at `.high` and `.medium` (an exhaustive switch, as `development` has), nothing for an unmarked player, and nothing when the factor is 1. The reason is `"Marked \(words): favoured for minutes, an untested way to bring offers (×\(Display.twoDecimals(factor)))"`, where `words` is `"to sell"` or `"to loan out"` from an exhaustive switch over the mark.

`AdvisorText.name(_:)` and `AdvisorText.marksNote` with the exact strings in the tests.

- [ ] **Step 5: Run the engine's tests**

Run: `cd LineupEngine && swift test`
Expected: all pass, no warnings. If another `switch` over `Adjustment.Kind` exists, the compiler names it; give `shopWindow` the same treatment as `development` there.

- [ ] **Step 6: Commit**

```bash
git add LineupEngine
git commit -m "Favour a player marked to sell or loan out in lesser fixtures

The owner believes minutes bring offers. No test shows it either way, so
the rule is a tie-breaker (×1.03, low and sharpness fixtures only) and
its reason says the effect is untested."
```

---

### Task 2: The planner is handed the marks

**Files:**
- Modify: `LineupEngine/Sources/LineupEngine/Planner/Planner.swift`
- Test: `LineupEngine/Tests/LineupEngineTests/PlannerScenarioTests.swift`

**Interfaces:**
- Consumes: `SaleMark`, `RuleContext.marks`, `Adjustment.Kind.shopWindow`, `EngineParameters.shopWindowFactor` (Task 1).
- Produces: `PlanRequest.marks: [PlayerID: SaleMark]`, with a new `init` parameter `marks: [PlayerID: SaleMark] = [:]` after `retraining`. Task 3 passes the app's marks here.

- [ ] **Step 1: Write the failing tests**

In `PlannerScenarioTests`, give the suite's `plan` helper a `marks: [PlayerID: SaleMark] = [:]` parameter passed to `PlanRequest`, then add three tests modelled on `youngProspectsGetTheLowFixture`. All use `PlanSettings(savingPlayers: 0)` and a striker aged 28 with `currentAbility` equal to `potentialAbility`, so no other rule favours him.

```swift
// MARK: - Marked to sell or loan out

@Test func aMarkedPlayerWinsANearTieInALowFixture() throws {
    // Between 97.2% and 100% of the first-choice striker: inside what ×1.03 can overturn.
    var players = try PlannerFixture.squad(first: 14, second: 12)
    let marked = nearStriker()
    players.append(marked)
    let gap = try rating(marked.id, at: .ST_C, in: players) / rating(id(.ST_C), at: .ST_C, in: players)
    try #require(gap > 0.972 && gap < 1)

    let fixtures = [fixture("m", .medium, day: 0), fixture("l", .low, day: 4)]
    let result = try plan(fixtures, players, settings: PlanSettings(savingPlayers: 0), marks: [marked.id: .toSell])
    #expect(pick(result.fixtures[0], .ST_C)?.player == id(.ST_C))
    let low = try #require(pick(result.fixtures[1], .ST_C))
    #expect(low.player == marked.id)
    #expect(low.adjustments.map(\.kind).contains(.shopWindow))
    let striker = try #require(result.fixtures[1].lineup.omissions.first { $0.player == id(.ST_C) })
    #expect(striker.reason.contains("Marked to sell: favoured for minutes, an untested way to bring offers (×1.03)"))
}

@Test func withoutTheMarkTheNearTieGoesToTheBetterPlayer() throws {
    var players = try PlannerFixture.squad(first: 14, second: 12)
    players.append(nearStriker())
    let result = try plan([fixture("l", .low, day: 0)], players, settings: PlanSettings(savingPlayers: 0))
    #expect(pick(result.fixtures[0], .ST_C)?.player == id(.ST_C))
}

@Test func aMarkedPlayerWhoIsClearlyWorseDoesNotStart() throws {
    // 5% below the first-choice striker (familiarity 15 against 20), as the prospect scenario's player is.
    var players = try PlannerFixture.squad(first: 14, second: 12)
    let marked = Player.fixture(name: "ST marked", age: 28, all: 14, familiarity: [.striker: 15],
                                currentAbility: 100, potentialAbility: 100)
    players.append(marked)
    let gap = try rating(marked.id, at: .ST_C, in: players) / rating(id(.ST_C), at: .ST_C, in: players)
    try #require(gap < 0.97)
    let result = try plan([fixture("l", .low, day: 0)], players, settings: PlanSettings(savingPlayers: 0),
                          marks: [marked.id: .toLoanOut])
    #expect(pick(result.fixtures[0], .ST_C)?.player == id(.ST_C))
}
```

`nearStriker()` is a helper in the suite returning `Player.fixture(name: "ST near", age: 28, …, currentAbility: 100, potentialAbility: 100)` with attributes and striker familiarity chosen so that the `#require` on `gap` in the first test holds. Find the values by running the test; the `#require` is what guards them.

- [ ] **Step 2: Run them and see them fail**

Run: `cd LineupEngine && swift test --filter PlannerScenarioTests`
Expected: does not compile (`PlanRequest` has no `marks`).

- [ ] **Step 3: Add `PlanRequest.marks` and hand it on**

Add the stored property and the defaulted `init` parameter. In `Planner`, where each fixture's `RuleContext` is built (it passes `retraining: retraining` today), pass `marks: request.marks`.

- [ ] **Step 4: Run the engine's tests**

Run: `cd LineupEngine && swift test`
Expected: all pass, no warnings.

- [ ] **Step 5: Commit**

```bash
git add LineupEngine
git commit -m "Hand the owner's sale and loan marks to the planner

The rule needs to know who is marked; the plan request now carries it.
Scenarios show a marked player winning a near-tie in a low fixture and
losing to a clearly better player."
```

---

### Task 3: The app keeps the marks and plans with them

**Files:**
- Modify: `LineupApp/Sources/LineupAppCore/Store.swift`
- Modify: `LineupApp/Sources/LineupAppCore/AppModel.swift`
- Create: `LineupApp/Sources/LineupAppCore/AppModel+Marks.swift`
- Modify: `LineupApp/Sources/LineupAppCore/AppModel+Plan.swift`
- Modify: `LineupApp/Sources/LineupAppCore/AppModel+Squad.swift` (the import, where `recordFamiliarity(after:on:)` is called)
- Test: `LineupApp/Tests/LineupAppCoreTests/AppModelTests.swift`, `StoreTests.swift`

**Interfaces:**
- Consumes: `SaleMark`, `PlanRequest.marks` (Tasks 1 and 2).
- Produces:
  - `StoreFile.marks`
  - `AppModel.marks: [PlayerID: SaleMark]` (`public private(set)`)
  - `public func setMark(_ mark: SaleMark?, for player: PlayerID)` on `AppModel`; `nil` clears
  - `func dropSpentMarks()` on `AppModel`, called after every import

- [ ] **Step 1: Write the failing tests**

In `AppModelTests`, using `TestModel` and its `importFirstTeam()`, `importU21()` and `reopened()` as the neighbouring tests do. Pick a player of the club's own and a player on loan at the club from the captured first team by `squad.book.loanStatus(of:override:)`, not by name.

- `markingAPlayerSavesItAndReplans`: after `setMark(.toSell, for: own)`, `model.marks[own] == .toSell`; `reopened().marks[own] == .toSell`; and the plan was worked out again (assert the way the suite's override tests assert a replan).
- `clearingAMarkRemovesIt`: `setMark(nil, for: own)` after marking leaves `model.marks[own] == nil`, and reopening agrees.
- `changingAMarkReplacesIt`: `.toSell` then `.toLoanOut` leaves `.toLoanOut`.
- `aPlayerOnLoanHereCannotBeMarked`: `setMark(.toSell, for: loanee)` leaves `model.marks` empty.
- `aPlayerNotInAnySquadCannotBeMarked`: `setMark(.toSell, for: PlayerID("fmrte:999999999"))` (use the suite's way of making an id) leaves `model.marks` empty.
- `theMarksReachThePlanner`: with a low-importance fixture planned, marking a player who is the plan's next-best at a slot within the factor's reach changes that slot's pick, and the pick's adjustments contain `.shopWindow`. If the captured squad has no such near-tie, assert instead that a marked starter's pick in a low fixture carries a `.shopWindow` adjustment and that the same pick in a high fixture does not.
- `aMarkGoesWhenThePlayerLeavesEverySquad` (Review Focus 1): mark a first-team player, then import a first-team paste without his row (drop his line from the capture's text); `model.marks` is empty and the reopened model agrees.
- `aLoanOutMarkGoesOnceHeIsOutOnLoan` (Review Focus 2): mark one player `.toLoanOut` and another `.toSell`, then import a paste in which both are shown out on loan (set the loaned-to column of their rows, as the squad-book tests build a loaned-out player); the `.toLoanOut` mark is gone and the `.toSell` mark remains.
- `markingDoesNotChangeAConfirmedLineup` (Review Focus 4): confirm the earliest fixture, record its starters, mark a non-starter who is close at some slot; the confirmed record's starters are unchanged.

In `StoreTests`, following the tests for the training file:

- `theMarksFileIsNotNoticedWhenMissing`: `StoreFile.marks.isNoticedWhenMissing == false`.
- `aMarksFileWithAnUnknownMarkIsKeptAsideWithANotice` (Review Focus 3): write a marks file of the current version whose value is `{"fmrte:1":"toSwap"}`; loading it as `[PlayerID: SaleMark]` gives the fresh value `[:]`, a notice that names "your sale and loan marks", and the file kept aside, exactly as the suite's unreadable-file test asserts for another file.

- [ ] **Step 2: Run them and see them fail**

Run: `cd LineupApp && swift test --filter "AppModelTests|StoreTests"`
Expected: does not compile.

- [ ] **Step 3: Add the file to `Store`**

`case marks` in `StoreFile`, with a doc comment (the players the owner has marked to sell or loan out). Its three wordings, in the three exhaustive switches: `"your sale and loan marks"`, `"the list starts empty"`, `"sale and loan marks"`. `isNoticedWhenMissing` is `false`, with `drafts` and `training`.

- [ ] **Step 4: Hold, load and save the marks in `AppModel`**

`public private(set) var marks: [PlayerID: SaleMark]`, loaded in `init` with `store.load(.marks, as: [PlayerID: SaleMark].self, otherwise: [:])`, its notice added to `notices`, its `replaceOnDisk` added to `replaced`, and `case .marks: try store.save(marks, to: .marks)` in `save(_:)`.

- [ ] **Step 5: Add the actions in `AppModel+Marks.swift`**

- `setMark(_:for:)`: does nothing unless the player is in the squad book and his loan status (`squad.book.loanStatus(of:override:)` with the club-name override the model already uses) is not `.loanedIn`. Otherwise sets or clears the mark, and, if anything changed, saves `.marks` and calls `replan()`.
- `dropSpentMarks()`: removes every mark whose player is in no squad of the book, and every `.toLoanOut` mark whose player's loan status is `.loanedOut`; saves if anything changed. It does not replan itself: the import that calls it replans.

Call `dropSpentMarks()` in the import, beside `recordFamiliarity(after:on:)` and before the import's replan.

- [ ] **Step 6: Hand the marks to the planner**

In `workedOutPlan()`, pass `marks: marks` to `PlanRequest`.

- [ ] **Step 7: Run the app's tests**

Run: `cd LineupApp && swift build && swift test`
Expected: all pass, no warnings. They take about a minute.

- [ ] **Step 8: Commit**

```bash
git add LineupApp
git commit -m "Keep the owner's sale and loan marks and plan with them

Marks are saved in their own file, refused for a player on loan here,
and dropped at import once a player has left or his loan has begun, so
a spent mark never favours anyone."
```

---

### Task 4: Marking on Player Removal

**Files:**
- Modify: `LineupApp/Sources/LineupAppCore/RemovalPresentation.swift`
- Modify: `LineupApp/Sources/LineupAppUI/Advice/RemovalScreen.swift`
- Modify: `LineupApp/Sources/LineupAppUI/ScreenPictures.swift`
- Test: `LineupApp/Tests/LineupAppCoreTests/RemovalPresentationTests.swift`

**Interfaces:**
- Consumes: `AppModel.marks`, `AppModel.setMark(_:for:)` (Task 3); `AdvisorText.name(_: SaleMark)`, `AdvisorText.marksNote` (Task 1).
- Produces:
  - `RemovalRow.mark: SaleMark?` and `RemovalRow.markText: String?` (the engine's name for the mark; nil when unmarked)
  - `public struct MarkChoice: Identifiable, Equatable, Sendable { public let mark: SaleMark?; public let title: String }`, identified by its title
  - `RemovalPresentation.markChoices: [MarkChoice]`: `"No mark"`, then each `SaleMark.allCases` by `AdvisorText.name`
  - `RemovalPresentation.markLabel = "Mark"` and `RemovalPresentation.marksNote = AdvisorText.marksNote`
  - `RemovalPresentation.sheet(_:squads:ages:marks:)`, with `marks: [PlayerID: SaleMark]` a new last parameter; `AppModel.removalSheet(_:)` passes `marks`

- [ ] **Step 1: Write the failing tests**

In `RemovalPresentationTests`, building reports and sheets as the suite's row tests do:

- `aMarkedRowShowsItsMarkInTheEnginesWords`: with `marks: [id: .toSell]`, that row has `mark == .toSell` and `markText == "To sell"`; with `.toLoanOut`, `"To loan out"`.
- `anUnmarkedRowHasNoMark`: `mark == nil`, `markText == nil`, and a mark for a player with no row changes no row.
- `theChoicesAreNoMarkThenEachMark`: `RemovalPresentation.markChoices.map(\.title) == ["No mark", "To sell", "To loan out"]` and `.map(\.mark) == [nil, .toSell, .toLoanOut]`.
- `theNoteIsTheEngines`: `RemovalPresentation.marksNote == AdvisorText.marksNote`.
- `aMarkedRowIsSpokenWithItsMark` (Review Focus 5): the marked row's `spokenText` contains `"To sell"`; the unmarked row's does not contain `"No mark"`.
- `theLoansToTheClubHaveNoMark`: `LoanBlock` is unchanged by `marks` (a mark for a loanee's id leaves the loan block equal to the one built without marks).

- [ ] **Step 2: Run them and see them fail**

Run: `cd LineupApp && swift test --filter RemovalPresentationTests`
Expected: does not compile.

- [ ] **Step 3: Put the mark on the row**

Add the two fields to `RemovalRow`, include `markText` in the parts `spokenText` joins (after `actionText`), add `MarkChoice`, the three statics and the `marks` parameter. `AppModel.removalSheet(_:)` passes `marks`.

- [ ] **Step 4: Run the tests**

Run: `cd LineupApp && swift test --filter RemovalPresentationTests`
Expected: pass.

- [ ] **Step 5: Draw it**

In `RemovalScreen.swift`:

- Under the explanation line, a second muted line with `RemovalPresentation.marksNote`.
- On a row, when `row.markText` is not nil, show it beside the action text, in the muted stamp style the screen already uses, so a closed row shows its mark.
- In the opened row's detail (`RemovalDetail`), a labelled control: `RemovalPresentation.markLabel`, then a segmented picker over `RemovalPresentation.markChoices` whose selection is `row.mark` and whose change calls `model.setMark(choice.mark, for: row.id)`. The loans block gets no control.

Every colour, typeface and measure from `Theme`; no `if` about data beyond showing or hiding the mark text.

- [ ] **Step 6: Add the pictures**

In `ScreenPictures.swift`, add a `removal-marked` variant, light and dark, beside the existing removal pictures: the sample model with one of the club's own players marked to sell and another to loan out before the picture is drawn, and those two rows open (use `RemovalStart` as the existing variants do to say which rows start open).

- [ ] **Step 7: Look at the pictures**

Run: `cd LineupApp && swift run -q LineupApp --sample-data .. --pictures .build/pictures-marks`
Open `removal-marked-light.png` and `removal-marked-dark.png` and the unmarked removal pictures. Check: the note reads cleanly under the explanation; a marked closed row shows its mark without crowding the action; the control sits inside the opened detail and its three choices fit; nothing is clipped in either theme. Fix what is wrong and draw again. The pictures draw the picker as an inactive window would.

- [ ] **Step 8: Run everything and commit**

Run: `cd LineupApp && swift build && swift test`
Expected: all pass, no warnings.

```bash
git add LineupApp
git commit -m "Mark a player to sell or loan out on Player Removal

The owner chooses the mark where the app already advises on who to move
on. A marked row shows its mark closed and says it aloud, and the note
says the effect on offers is untested."
```

---

### Task 5: The app, built and checked, and the plan closed

**Files:**
- Modify: `CLAUDE.md`
- Modify: `docs/superpowers/plans/2026-11-14-fm27-sale-marks.md` (this file)

- [ ] **Step 1: Try it on the sample data**

Run: `cd LineupApp && swift run LineupApp --sample-data ..`
On Player Removal, open a row, mark the player to sell, and check on Match Selection that a low-importance fixture's pick or omission shows "Marked to sell: favoured for minutes, an untested way to bring offers (×1.03)" where he is within reach of a starter, and that no high or medium fixture mentions it. Clear the mark and check the plan goes back. If the sample fixtures have no low-importance fixture, change one on Fixtures first.

- [ ] **Step 2: Run both suites**

Run: `cd LineupEngine && swift test && cd ../LineupApp && swift build && swift test`
Expected: all pass, no warnings.

- [ ] **Step 3: Update `CLAUDE.md`**

- In "How the engine works", **Planning**: add marked to sell or loan out to the list of importance rules, and one sentence: a player the owner has marked is favoured slightly in low and sharpness fixtures; the size is the tool's own estimate and the effect on offers is untested.
- In "New code: `LineupApp/`": Player Removal lets the owner mark a player to sell or loan out; a mark is dropped at import once the player has left every squad, or, for a loan mark, once he is out on loan.
- In the list of plans at the top, add this plan as complete with a one-line pointer to its closing sections, and the two research files under Research if the wording there needs it.

- [ ] **Step 4: Close this plan**

Add three sections at the end of this file, as the earlier plans have: **Changes made while building** (every place the build departed from this plan, and why), **Known limits and small faults left** (start with: a marked player can still be recommended for retraining; the app cannot see ratings, so a marked player in poor form is still favoured; the factor is untested), and **For the owner** (the test in `docs/Research/fm27-playing-time-and-transfer-interest.md` that would settle the factor, and that it is one line in `EngineParameters` to change).

- [ ] **Step 5: Build the app**

Run, from the repository root: `tools/build_app.sh`
Expected: it builds, checks the engine's resources, and installs `/Applications/FM27 Lineup Optimizer.app`. This replaces the installed app and closes any open copy, as the earlier plans' last tasks did.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md docs/superpowers/plans/2026-11-14-fm27-sale-marks.md
git commit -m "Close the sale marks plan: record what changed and what is left

CLAUDE.md now says the planner favours marked players and where marks
are made, so the next session does not have to rediscover it."
```

---

## Changes made while building

- **The factor is checked with the other factors.** `FitnessModel.problems(in:)` reports a `shopWindowFactor` that is negative or not finite. The plan did not list it; without it a bad number would stop the program inside `Adjustment` instead of being reported.
- **The near-tie scenarios use one fixture on the day of the import.** The plan's scenario put a medium fixture four days before the low one. There the first-choice striker's tiredness alone gave the low fixture to the other player, so the test passed without the rule. With level fitness only the mark separates the two, and a separate test covers medium and high.
- **The app's marks tests are their own suite**, `SaleMarksTests.swift`, with helpers that edit the captured paste (drop a row, set the club a player is loaned to).
- **The marked-players pictures are drawn in `Sources/LineupApp/main.swift`**, where the other Player Removal variants are, not in `ScreenPictures.swift`.
- **The mark on a closed row is small muted text under the action**, and the control in an opened row is the app's own tabs ("No mark", "To sell", "To loan out").
- **The app was not clicked through by hand.** Task 5's first step asked for that. The chain it would have shown is covered by `SaleMarksTests.theMarksReachThePlanner` on the captured squad (the reason appears on a low fixture's pick when the player is marked, is absent from the high fixture, and goes when the mark is cleared) and by the pictures.
- **The app is installed after the final review**, not before it, so what is installed is what was reviewed.
- **After the final review, two faults in how long a mark lives were put right.**
  - A mark was dropped the moment its player was in no squad. A marked player demoted from the first team to the U21s is in neither between the two imports, so he lost his mark. A mark now goes only once every squad held has been imported without him.
  - A marked player who became a loanee here (sold and loaned back, or the club's name changed in Settings) kept a mark that favoured him and that no screen could clear. Such a mark is now dropped at import and when the club's name changes, the engine's rule ignores a loanee, and taking a mark off works for anyone.
- **The confirmed-lineup test was strengthened**: it marks a starter of the confirmed lineup and checks the fixture is still shown as confirmed, unchanged.

## Known limits and small faults left

- Whether playing a player brings offers is untested; the factor is this tool's estimate.
- The app cannot see match ratings, so a marked player in poor form is still favoured.
- A marked player can still be recommended for retraining.
- A mark can only be made on Player Removal, which needs a usable primary tactic and a squad; with the advice unavailable there is nowhere to mark or unmark a player.
- A player marked to sell who goes out on loan keeps his mark and is favoured again when he returns.
- The marked pictures, like every picture, are the same file in light and dark; this was so before this plan.
- If the squad file cannot be read and starts fresh, the first squad imported afterwards counts as every squad held, so marks on players of the other squads are dropped.
- The count of squads imported without a marked player is not saved, so closing the app starts it again; this only keeps a mark longer.
- A paste without FMRTE's Id column followed by one with it changes a player's key, and his mark is dropped with the old key.
- Both marked rows in the pictures are open; a closed marked row is not pictured. "Release" with "To sell" under it can read as a second action.
- Changing a mark works the advice out again although the advice does not use marks.
- No test at the model's level shows an unreadable marks file giving its notice; the store's own test does.
- The words "to sell" and "to loan out" are written in the planner's rule as well as in `AdvisorText`.

## For the owner

- The test that would settle the factor is in `docs/Research/fm27-playing-time-and-transfer-interest.md` ("Cheapest test to settle it"): the same players started in one save and left out in another, counting offers.
- The factor is one line, `shopWindowFactor` in `LineupEngine/Sources/LineupEngine/Parameters/EngineParameters.swift`. Setting it to 1 switches the rule off and leaves the marks in place.
