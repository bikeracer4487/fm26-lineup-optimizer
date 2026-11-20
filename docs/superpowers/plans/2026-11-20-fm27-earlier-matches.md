# Earlier Matches Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fixtures and Match Selection show the matches of the last 60 days and those still to play; older ones are counted in one line on Fixtures with a "Show" button, and nothing is deleted.

**Architecture:** A display rule in `LineupAppCore`, in one new file. `AppModel.fixtures`, `history` and `planState` stay whole, so the planner, the advisors and the league read what they read today; the two screens read filtered lists (`listedFixtures`, `shownPlans`). One switch in the model's memory, never saved, shows everything on both screens.

**Tech Stack:** Swift 6, macOS 26, SwiftUI and Observation, Swift Testing. No engine change, no new dependency.

**Spec:** `docs/superpowers/specs/2026-11-20-fm27-earlier-matches-design.md`. Read it with this plan; `CLAUDE.md` at the repository root has the app's rules.

## Global Constraints

- Work on branch `fm27-native`. Commit messages say why. No merge, no pull request.
- `LineupEngine/` is not changed. No saved file's format changes; nothing is deleted from `fixtures` or `history`.
- The window's length is read from `planParameters.matchesHereWindowDays.value` (60), never written as a literal in the app.
- The window is measured from `settings.currentDate` (today in the game), not from `planStartDay`.
- Every `if` about data, and every word the owner reads, is in `LineupAppCore` with a test. Views hold layout only.
- Every colour, typeface and measure in a view comes from `Theme`.
- Test output is clean: no build warnings.
- Nothing in a test, a picture run or a sample-data run touches `~/Library/Application Support` or the real clipboard.
- Exact copy, with "Tue 15 Sep" standing for `DayText.short` of the window's first day:
  - "48 matches from before Tue 15 Sep are not shown." with the button "Show"
  - "1 match from before Tue 15 Sep is not shown." with the button "Show"
  - "Showing 48 matches from before Tue 15 Sep." with the button "Hide"
  - "Showing 1 match from before Tue 15 Sep." with the button "Hide"
  - "No match to play, and none played since Sat 14 Nov. Add the next matches on the Fixtures screen."
- Run tests with `cd LineupApp && swift test --filter <name>`; the whole suite (`swift test`, about four and a half minutes) once before each commit.

## Review Focus

Each of these has its test in the task named.

1. A fixture saved from the editor with a date before the window: it leaves the table and the line's count rises by one (Task 1).
2. "Show" is on and the last earlier match is deleted: the line goes, and the table is unchanged (Task 1).
3. The squad was imported long ago and today has been moved far on: the planned matches are before the window and are still shown on both screens; confirming the first hides it and the screen moves to the next planned one (Task 2).
4. Every match is earlier and none is entered for next season: Fixtures shows the line and no rows, and Match Selection shows its sentence with the button to Fixtures (Task 2, pictures in Task 3).
5. The plan is stopped (no tactic, or a failure) with an old missed match saved: Match Selection, which then lists the missed matches, does not list the old one (Task 2).

## File Structure

- Create `LineupApp/Sources/LineupAppCore/EarlierMatches.swift`: the rule, the two lists' filters, the line's words, the switch's setter, Match Selection's empty state.
- Modify `LineupApp/Sources/LineupAppCore/AppModel.swift`: one stored property (stored properties cannot sit in an extension).
- Modify `LineupApp/Sources/LineupAppCore/AppModel+Plan.swift`: `shownPlans` (line 160).
- Modify `LineupApp/Sources/LineupAppCore/SampleData.swift`: two sample models.
- Create `LineupApp/Tests/LineupAppCoreTests/EarlierMatchesTests.swift`.
- Modify `LineupApp/Sources/LineupAppUI/Fixtures/FixturesScreen.swift`, `Match/MatchSelectionScreen.swift`, `RootView.swift`.
- Modify `LineupApp/Sources/LineupApp/main.swift`: two sample states and six picture variants.
- Modify `CLAUDE.md` and the spec's status line.

---

### Task 1: The rule, and what the Fixtures table lists

**Files:**
- Create: `LineupApp/Sources/LineupAppCore/EarlierMatches.swift`
- Modify: `LineupApp/Sources/LineupAppCore/AppModel.swift` (beside `planState`, line 78)
- Test: `LineupApp/Tests/LineupAppCoreTests/EarlierMatchesTests.swift`

**Interfaces:**
- Consumes: `AppModel.fixtures`, `history`, `settings.currentDate`, `planStartDay`, `planParameters`, `DayText.short`.
- Produces:
  - `AppModel.showsEarlierMatches: Bool` (`public internal(set)`, false at init, never saved)
  - `AppModel.setShowsEarlierMatches(_ shows: Bool)` (sets the property; does not plan, save or clear the advice)
  - `AppModel.earlierMatchesBefore: Day` (today less `matchesHereWindowDays − 1` days)
  - `AppModel.isEarlier(_ fixture: StoredFixture) -> Bool`
  - `AppModel.earlierMatchCount: Int` (whatever the switch says)
  - `AppModel.listedFixtures: [StoredFixture]` (in `fixtures`' order)
  - `AppModel.earlierMatchesLine: EarlierMatchesLine?`
  - `public struct EarlierMatchesLine: Equatable, Sendable { public let text: String; public let action: String; public let showsWhenPressed: Bool }`

The rule: a fixture is earlier when `fixture.date < earlierMatchesBefore` and it is not still to be planned. It is still to be planned when a squad has been imported, its date is on or after `planStartDay`, and no record in `history` is for it. So before the window a confirmed fixture is earlier, a missed one is earlier, and with no squad imported every one is.

- [ ] **Step 1: Write the failing tests**

In a `@MainActor @Suite struct EarlierMatchesTests`, with the helpers `day(_:)`, `record(for:on:)` and `setToday(_:in:)` copied from `FixturePresentationTests` (they are private there). `TestModel.today` is Friday 13 November 2026, so the window's first day is Tuesday 15 September 2026.

```swift
@Test func aMatchOnTheWindowsFirstDayIsListedAndOneTheDayBeforeIsNot() throws {
    let t = try TestModel()
    let inside = t.model.addFixture(date: day("2026-09-15"), opponent: "Inside", importance: .low)
    let before = t.model.addFixture(date: day("2026-09-14"), opponent: "Before", importance: .low)
    t.model.history = [record(for: inside, on: day("2026-09-15")), record(for: before, on: day("2026-09-14"))]
    #expect(t.model.earlierMatchesBefore == day("2026-09-15"))
    #expect(t.model.earlierMatchesBefore
            == TestModel.today.adding(days: -(EngineParameters.fm27.matchesHereWindowDays.value - 1)))
    #expect(t.model.listedFixtures.map(\.id) == [inside])
    #expect(t.model.earlierMatchCount == 1)
}

@Test func aMatchNeverConfirmedBeforeTheWindowIsEarlierToo() throws {
    let t = try TestModel()
    t.model.addFixture(date: day("2026-09-01"), opponent: "Never confirmed", importance: .low)
    let next = t.model.addFixture(date: day("2026-11-15"), opponent: "Next", importance: .low)
    #expect(t.model.listedFixtures.map(\.id) == [next])
}

@Test func aMatchStillToBePlannedIsListedWhateverItsDate() throws {
    let t = try TestModel()
    try t.importFirstTeam()   // the plan starts on 13 November
    let missed = t.model.addFixture(date: day("2026-11-10"), opponent: "Missed", importance: .low)
    let planned = t.model.addFixture(date: day("2026-11-20"), opponent: "Planned", importance: .low)
    setToday("2027-03-01", in: t.model)   // the window now starts on 1 January 2027
    #expect(t.model.earlierMatchesBefore == day("2027-01-01"))
    #expect(t.model.isEarlier(try #require(t.model.fixtures.first { $0.id == missed })))
    #expect(t.model.listedFixtures.map(\.id) == [planned])
    t.model.history = [record(for: planned, on: day("2026-11-20"))]
    #expect(t.model.listedFixtures.isEmpty)
    #expect(t.model.earlierMatchCount == 2)
}

@Test func movingTodayMovesTheWindow() throws {
    let t = try TestModel()
    let played = t.model.addFixture(date: day("2026-09-15"), opponent: "Played", importance: .low)
    t.model.history = [record(for: played, on: day("2026-09-15"))]
    t.model.moveToday(by: 1)
    #expect(t.model.listedFixtures.isEmpty)
    t.model.moveToday(by: -1)
    #expect(t.model.listedFixtures.map(\.id) == [played])
}

@Test func withNothingEarlierEveryFixtureIsListedAndThereIsNoLine() throws {
    let t = try TestModel()
    let played = t.model.addFixture(date: day("2026-11-07"), opponent: "Played", importance: .low)
    t.model.addFixture(date: day("2026-11-10"), opponent: "Missed", importance: .low)
    t.model.addFixture(date: day("2026-11-15"), opponent: "Next", importance: .low)
    t.model.history = [record(for: played, on: day("2026-11-07"))]
    #expect(t.model.listedFixtures == t.model.fixtures)
    #expect(t.model.earlierMatchesLine == nil)
    t.model.setShowsEarlierMatches(true)
    #expect(t.model.earlierMatchesLine == nil)
}

@Test func showListsEveryMatchAndIsNeitherSavedNorAReasonToPlan() throws {
    let t = try TestModel()
    t.model.addFixture(date: day("2026-08-01"), opponent: "Old", importance: .low)
    t.model.addFixture(date: day("2026-11-15"), opponent: "Next", importance: .low)
    let planned = t.model.timesPlanned
    t.model.setShowsEarlierMatches(true)
    #expect(t.model.listedFixtures == t.model.fixtures)
    #expect(t.model.earlierMatchCount == 1)
    #expect(t.model.timesPlanned == planned)
    #expect(!t.reopened().showsEarlierMatches)
}

@Test func theLineSaysHowManyAndFromBeforeWhen() throws {
    let t = try TestModel()
    t.model.addFixture(date: day("2026-08-01"), opponent: "Old", importance: .low)
    #expect(t.model.earlierMatchesLine == EarlierMatchesLine(
        text: "1 match from before Tue 15 Sep is not shown.", action: "Show", showsWhenPressed: true))
    t.model.addFixture(date: day("2026-08-08"), opponent: "Older", importance: .low)
    #expect(t.model.earlierMatchesLine?.text == "2 matches from before Tue 15 Sep are not shown.")
    t.model.setShowsEarlierMatches(true)
    #expect(t.model.earlierMatchesLine == EarlierMatchesLine(
        text: "Showing 2 matches from before Tue 15 Sep.", action: "Hide", showsWhenPressed: false))
    t.model.deleteFixture(t.model.fixtures[0].id)
    #expect(t.model.earlierMatchesLine?.text == "Showing 1 match from before Tue 15 Sep.")
}

// Review Focus 1
@Test func aFixtureSavedWithADateBeforeTheWindowJoinsTheEarlierOnes() throws {
    let t = try TestModel()
    let id = t.model.addFixture(date: day("2026-11-15"), opponent: "Moved", importance: .low)
    var draft = t.model.fixtureDraft(for: try #require(t.model.fixtures.first))
    draft.date = day("2026-08-01")
    _ = t.model.save(draft)
    #expect(!t.model.listedFixtures.contains { $0.id == id })
    #expect(t.model.earlierMatchesLine?.text == "1 match from before Tue 15 Sep is not shown.")
}

// Review Focus 2
@Test func deletingTheLastEarlierMatchWhileShownRemovesTheLine() throws {
    let t = try TestModel()
    let old = t.model.addFixture(date: day("2026-08-01"), opponent: "Old", importance: .low)
    t.model.addFixture(date: day("2026-11-15"), opponent: "Next", importance: .low)
    t.model.setShowsEarlierMatches(true)
    t.model.deleteFixture(old)
    #expect(t.model.earlierMatchesLine == nil)
    #expect(t.model.listedFixtures == t.model.fixtures)
}
```

`FixtureDraft`'s date field and the model's save method are in `FixturePresentation.swift` (the save returns the fixture's id, around line 300); use their real names if they differ from `draft.date` and `save(_:)`.

- [ ] **Step 2: Run them and see them fail**

Run: `cd LineupApp && swift test --filter EarlierMatchesTests`
Expected: does not compile, `showsEarlierMatches` and the rest not found.

- [ ] **Step 3: Implement the Produces list**

`showsEarlierMatches` goes in `AppModel.swift`; everything else in `EarlierMatches.swift` as an extension of `AppModel`, each member with a doc comment saying what it is for. `listedFixtures` and `earlierMatchCount` build the set of confirmed fixture ids once, not once a fixture. The line is nil when the count is 0, whatever the switch says.

- [ ] **Step 4: Run the tests and see them pass**

Run: `cd LineupApp && swift test --filter EarlierMatchesTests`
Expected: 9 tests pass, no warnings.

- [ ] **Step 5: Run the whole suite, then commit**

```bash
cd LineupApp && swift test
git add LineupApp/Sources/LineupAppCore/EarlierMatches.swift LineupApp/Sources/LineupAppCore/AppModel.swift LineupApp/Tests/LineupAppCoreTests/EarlierMatchesTests.swift
git commit -m "Work out which matches are earlier than the advice reads, so the Fixtures table can leave them out and say how many"
```

---

### Task 2: What Match Selection shows, and two samples

**Files:**
- Modify: `LineupApp/Sources/LineupAppCore/AppModel+Plan.swift:158-163` (`shownPlans`)
- Modify: `LineupApp/Sources/LineupAppCore/EarlierMatches.swift`
- Modify: `LineupApp/Sources/LineupAppCore/SampleData.swift` (after `modelMidSeason`)
- Test: `LineupApp/Tests/LineupAppCoreTests/EarlierMatchesTests.swift`

**Interfaces:**
- Consumes: Task 1's `isEarlier`, `showsEarlierMatches`, `earlierMatchCount`, `earlierMatchesBefore`; `MatchPresentation.notReady(_:)`, `MatchPresentation.goTo(_:)`, `NotReady`, `fixturePlans`.
- Produces:
  - `AppModel.shownPlans: [FixturePlan]`: as today, less the plans whose fixture `isEarlier`, unless `showsEarlierMatches`. Both of its branches are filtered: the ready plan's, and the missed fixtures shown while the plan is stopped.
  - `AppModel.matchNotReady: NotReady?`: `MatchPresentation.notReady(planState)` when that is not nil; else, when `shownPlans` is empty and `earlierMatchCount > 0`, `NotReady(message: "No match to play, and none played since \(DayText.short(earlierMatchesBefore)). Add the next matches on the Fixtures screen.", problems: [], isFailure: false, action: MatchPresentation.goTo(.fixtures), screen: .fixtures)`; else nil.
  - `SampleData.modelWithEarlierSeason(repositoryRoot: URL) throws -> AppModel`: the sample model with eight more fixtures, all confirmed. Their dates are `earlierMatchesBefore` plus −42, −35, −28, −21, −14, −7, +7 and +14 days, against "Opponent M" to "Opponent T", importance medium. Each is confirmed the way `modelWithPastFixtures` confirms one: a copy of `model.history.last` with the fixture and date changed, appended to `history`, saved, then one `replan()`. Six are earlier and two are inside the window.
  - `SampleData.modelInTheSummer(repositoryRoot: URL) throws -> AppModel`: `modelWithEarlierSeason` with every fixture that has no record in `history` deleted (`deleteFixture`), then `moveToday(by: 60)`. Today is then 12 January 2027, the window starts on Saturday 14 November 2026, and all eight matches are earlier.

- [ ] **Step 1: Write the failing tests**

Add to `EarlierMatchesTests`, with `private func earlierSeason() throws -> AppModel { try SampleData.modelWithEarlierSeason(repositoryRoot: Captures.repositoryRoot) }` and the same for `summer()`.

```swift
@Test func matchSelectionShowsNoEarlierMatch() throws {
    let m = try earlierSeason()
    #expect(m.earlierMatchCount == 6)
    #expect(m.fixturePlans.count - m.shownPlans.count == 6)
    #expect(m.shownPlans.allSatisfy { !m.isEarlier($0.fixture) })
    #expect(m.startsGrid(for: m.shownPlans).columns.count == m.shownPlans.count)
}

@Test func showBringsEarlierMatchesBackToMatchSelection() throws {
    let m = try earlierSeason()
    m.setShowsEarlierMatches(true)
    #expect(m.shownPlans == m.fixturePlans)
}

@Test func hidingMatchesChangesNoPlanAndNoSuggestion() throws {
    let m = try earlierSeason()
    let plan = m.planState, planned = m.timesPlanned
    let lines = m.fixtures.map { m.suggestionLine(for: $0) }
    m.setShowsEarlierMatches(true)
    #expect(m.planState == plan)
    #expect(m.timesPlanned == planned)
    #expect(m.fixtures.map { m.suggestionLine(for: $0) } == lines)
}

@Test func aHiddenFixtureThatWasChosenGivesWayToTheNextToPlay() throws {
    let m = try earlierSeason()
    let hidden = try #require(m.fixtures.first { m.isEarlier($0) })
    let chosen = MatchPresentation.chosen(hidden.id, in: m.shownPlans)
    #expect(chosen?.id == MatchPresentation.initialFixture(in: m.shownPlans))
    #expect(chosen.map { !m.isEarlier($0.fixture) } == true)
}

// Review Focus 3
@Test func plannedMatchesBeforeTheWindowAreShownUntilConfirmed() throws {
    let m = try SampleData.model(repositoryRoot: Captures.repositoryRoot)
    m.moveToday(by: 120)   // no import since: the plan still starts in November
    let first = try #require(m.fixtures.first)
    #expect(first.date < m.earlierMatchesBefore)
    #expect(m.shownPlans == m.fixturePlans)
    #expect(m.listedFixtures == m.fixtures)
    m.confirm(first.id)
    #expect(!m.shownPlans.contains { $0.id == first.id })
    #expect(MatchPresentation.fixtureAfterConfirming(first.id, in: m.shownPlans) == m.shownPlans.first?.id)
}

// Review Focus 4
@Test func inTheSummerBothScreensSayWhatIsHidden() throws {
    let m = try summer()
    guard case .ready = m.planState else { Issue.record("expected a plan, got \(m.planState)"); return }
    #expect(m.listedFixtures.isEmpty)
    #expect(m.earlierMatchesLine?.text == "8 matches from before Sat 14 Nov are not shown.")
    #expect(m.shownPlans.isEmpty)
    #expect(m.matchNotReady == NotReady(
        message: "No match to play, and none played since Sat 14 Nov. Add the next matches on the Fixtures screen.",
        problems: [], isFailure: false, action: "Go to Fixtures", screen: .fixtures))
    m.setShowsEarlierMatches(true)
    #expect(m.matchNotReady == nil)
    #expect(m.shownPlans.count == 8)
}

@Test func otherwiseMatchSelectionsEmptyStateIsThePlansOwn() throws {
    let t = try TestModel()
    #expect(t.model.matchNotReady == MatchPresentation.notReady(.needsSquad))
    #expect(try SampleData.model(repositoryRoot: Captures.repositoryRoot).matchNotReady == nil)
}

// Review Focus 5
@Test func whileThePlanIsStoppedAnEarlierMissedMatchIsNotShown() throws {
    let t = try TestModel()
    try t.importFirstTeam()   // no tactic, so nothing is planned and the missed matches are shown
    t.model.addFixture(date: day("2026-09-01"), opponent: "Long ago", importance: .low)
    let recent = t.model.addFixture(date: day("2026-11-10"), opponent: "Last week", importance: .low)
    #expect(t.model.shownPlans.map(\.id) == [recent])
    t.model.setShowsEarlierMatches(true)
    #expect(t.model.shownPlans.count == 2)
}
```

If `suggestionLine(for:)` returns a type that is not `Equatable`, compare its text.

- [ ] **Step 2: Run them and see them fail**

Run: `cd LineupApp && swift test --filter EarlierMatchesTests`
Expected: does not compile, `modelWithEarlierSeason`, `modelInTheSummer` and `matchNotReady` not found.

- [ ] **Step 3: Implement the Produces list**

If `modelInTheSummer`'s plan is not `.ready` (the planner refusing a request with no fixture to plan), stop and report it; do not work round it in the sample.

- [ ] **Step 4: Run the tests and see them pass**

Run: `cd LineupApp && swift test --filter EarlierMatchesTests`
Expected: 17 tests pass, no warnings.

- [ ] **Step 5: Run the whole suite, then commit**

`PlanStateTests` holds the existing `shownPlans` tests (around line 1117); they must pass unchanged.

```bash
cd LineupApp && swift test
git add LineupApp/Sources/LineupAppCore LineupApp/Tests/LineupAppCoreTests/EarlierMatchesTests.swift
git commit -m "Leave earlier matches out of Match Selection's notes and starts grid, and say so when none is left to show, so a past season does not push the next match off the screen"
```

---

### Task 3: The two screens, the pictures and the guide

**Files:**
- Modify: `LineupApp/Sources/LineupAppUI/Fixtures/FixturesScreen.swift` (`rows(actionsBeside:)`, line 102)
- Modify: `LineupApp/Sources/LineupAppUI/Match/MatchSelectionScreen.swift:37,54,106`
- Modify: `LineupApp/Sources/LineupAppUI/RootView.swift:45`
- Modify: `LineupApp/Sources/LineupApp/main.swift` (`SampleState`, `sampleModel`, `drawFixtures`, `drawMatchSelection`)
- Modify: `CLAUDE.md`, `docs/superpowers/specs/2026-11-20-fm27-earlier-matches-design.md` (status line)

**Interfaces:**
- Consumes: `model.listedFixtures`, `model.earlierMatchesLine`, `model.setShowsEarlierMatches(_:)`, `model.shownPlans`, `model.matchNotReady`, `SampleData.modelWithEarlierSeason`, `SampleData.modelInTheSummer`.
- Produces: nothing later tasks use.

- [ ] **Step 1: The Fixtures table**

In `rows(actionsBeside:)`, the `ForEach` runs over `model.listedFixtures`. Between the `HeavyRule()` and the `ScrollViewReader`, when `model.earlierMatchesLine` is not nil: its `text` in the small text face in muted ink, its `action` as a button drawn as "Use it" is drawn under a suggestion line, calling `model.setShowsEarlierMatches(line.showsWhenPressed)`, then a `FaintRule()`. The line does not scroll with the rows. The screen's own tests of `model.fixtures.isEmpty` (the heading's buttons and the empty state) stay as they are, so with every match earlier the table shows its headings, the line and no rows.

- [ ] **Step 2: Match Selection**

`MatchSelectionScreen` reads `model.matchNotReady` where it reads `MatchPresentation.notReady(model.planState)` (lines 37 and 54), and `model.shownPlans` where it reads `model.planState`'s plans after confirming (line 106). `RootView.swift:45` reads `model.shownPlans` too.

- [ ] **Step 3: Build**

Run: `cd LineupApp && swift build`
Expected: builds with no warnings.

- [ ] **Step 4: The pictures**

In `main.swift`, add `earlierSeason` and `summer` to `SampleState` and `sampleModel`. In `drawFixtures`, write variants "earlier" (the earlier-season sample), "earlier-shown" (the same after `setShowsEarlierMatches(true)`) and "summer", each `screens: [.fixtures]`. In `drawMatchSelection`, write "earlier", "earlier-starts" (`matchStart: MatchStart(view: .starts)`) and "summer", each `screens: [.matchSelection]`.

Run: `cd LineupApp && swift run -q LineupApp --sample-data .. --pictures .build/pictures-earlier`
Expected: exits 0 and writes `fixtures-earlier-*`, `fixtures-earlier-shown-*`, `fixtures-summer-*`, `match-earlier-*`, `match-earlier-starts-*` and `match-summer-*` among the rest.

- [ ] **Step 5: Look at the pictures**

Open each of the six, light. Check: the line sits under the column headings and reads as a note, not a row; "Show" and "Hide" read as buttons; `fixtures-earlier` lists seven matches and `fixtures-earlier-shown` thirteen; the starts grid has seven columns; both summer pictures say what is hidden and Match Selection's has "Go to Fixtures". Check `fixtures-midseason-*` and `match-midseason-*` are as before (nothing in them is earlier). Fix what is wrong and draw again.

- [ ] **Step 6: The guide**

In `CLAUDE.md`: add a bullet for this plan after the League table plan's, in the same form; in the `LineupApp/` section, a short paragraph saying what an earlier match is, the line and "Show" on Fixtures, that Match Selection follows the same switch, the empty state's sentence, and the names `EarlierMatches.swift`, `isEarlier`, `listedFixtures`, `shownPlans`, `matchNotReady`; and in the paragraph on pictures, that these were checked in `.build/pictures-earlier` with the six names. Change the spec's status line to say it was built and when.

- [ ] **Step 7: Run the whole suite, then commit**

```bash
cd LineupApp && swift test
git add LineupApp/Sources CLAUDE.md docs/superpowers/specs/2026-11-20-fm27-earlier-matches-design.md docs/superpowers/plans/2026-11-20-fm27-earlier-matches.md
git commit -m "Show only the last two months and the matches to play on Fixtures and Match Selection, with a line to show the rest, so the owner's second season starts on clean screens"
```

The install (`tools/build_app.sh`) and the check of the real app on the owner's 50 fixtures are left to the owner.
