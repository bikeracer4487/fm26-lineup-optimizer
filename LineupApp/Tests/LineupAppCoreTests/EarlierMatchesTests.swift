import Foundation
import Testing
@testable import LineupEngine
@testable import LineupAppCore

/// Matches from before the days the advice reads are left off Fixtures and Match Selection, and nothing else changes.
/// `TestModel.today` is Friday 13 November 2026, so the window of 60 days starts on Tuesday 15 September 2026.
@MainActor @Suite struct EarlierMatchesTests {
    private func day(_ iso: String) -> Day { Day(iso: iso)! }

    private func record(for id: FixtureID, on date: Day) -> ConfirmedRecord {
        ConfirmedRecord(lineup: ConfirmedLineup(fixture: id, date: date, starters: [:]), names: [:], tacticName: "4-2-3-1")
    }

    private func setToday(_ iso: String, in model: AppModel) {
        var settings = model.settings
        settings.currentDate = day(iso)
        model.update(settings)
    }

    // MARK: The rule, and what the Fixtures table lists

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

    /// "Show" and "Hide" alone tell VoiceOver nothing, so the button says what it shows or hides.
    @Test func theLinesButtonSaysWhatItShowsOrHides() throws {
        let t = try TestModel()
        t.model.addFixture(date: day("2026-08-01"), opponent: "Old", importance: .low)
        #expect(t.model.earlierMatchesLine?.actionLabel == "Show earlier matches")
        t.model.setShowsEarlierMatches(true)
        #expect(t.model.earlierMatchesLine?.actionLabel == "Hide earlier matches")
    }

    /// A fixture whose date is corrected to long ago leaves the table, and the line counts it.
    @Test func aFixtureSavedWithADateBeforeTheWindowJoinsTheEarlierOnes() throws {
        let t = try TestModel()
        let id = t.model.addFixture(date: day("2026-11-15"), opponent: "Moved", importance: .low)
        var draft = t.model.fixtureDraft(for: try #require(t.model.fixtures.first))
        draft.date = day("2026-08-01")
        t.model.save(draft)
        #expect(!t.model.listedFixtures.contains { $0.id == id })
        #expect(t.model.earlierMatchesLine?.text == "1 match from before Tue 15 Sep is not shown.")
    }

    /// With every match shown, deleting the last earlier one takes the line away and leaves the table as it was.
    @Test func deletingTheLastEarlierMatchWhileShownRemovesTheLine() throws {
        let t = try TestModel()
        let old = t.model.addFixture(date: day("2026-08-01"), opponent: "Old", importance: .low)
        t.model.addFixture(date: day("2026-11-15"), opponent: "Next", importance: .low)
        t.model.setShowsEarlierMatches(true)
        t.model.deleteFixture(old)
        #expect(t.model.earlierMatchesLine == nil)
        #expect(t.model.listedFixtures == t.model.fixtures)
    }

    // MARK: The import's warning

    /// An import tells the owner to confirm a missed match in Match Selection. An earlier one is not shown there and
    /// changes no advice, so the import says nothing about it; a missed match inside the window is still named.
    @Test func anImportDoesNotAskForAnEarlierMatchToBeConfirmed() throws {
        let t = try TestModel()
        t.model.addFixture(date: day("2026-09-01"), opponent: "Long ago", importance: .low)
        t.model.addFixture(date: day("2026-11-10"), opponent: "Last week", importance: .low)
        try t.importFirstTeam()
        guard case .imported(let summary)? = t.model.lastImport else {
            Issue.record("expected an import summary, got \(String(describing: t.model.lastImport))")
            return
        }
        let asked = summary.warnings.filter { $0.hasSuffix("Confirm it in Match Selection so its starts count.") }
        #expect(asked == ["The match against Last week on Tue 10 Nov has no confirmed lineup. "
                          + "Confirm it in Match Selection so its starts count."])
        #expect(t.model.shownPlans.map(\.fixture.opponent) == ["Last week"])
    }

    // MARK: What Match Selection shows

    private func earlierSeason() throws -> AppModel {
        try SampleData.modelWithEarlierSeason(repositoryRoot: Captures.repositoryRoot)
    }

    private func summer() throws -> AppModel {
        try SampleData.modelInTheSummer(repositoryRoot: Captures.repositoryRoot)
    }

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

    /// The squad was imported long ago and today has moved far on: the planned matches are before the window, and are
    /// shown until they are confirmed.
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

    /// Every match is earlier and none is entered for the next season.
    @Test func inTheSummerBothScreensSayWhatIsHidden() throws {
        let m = try summer()
        guard case .ready = m.planState else {
            Issue.record("expected a plan, got \(m.planState)")
            return
        }
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

    /// While the plan is stopped Match Selection lists the missed matches, and leaves an old one out of them too.
    @Test func whileThePlanIsStoppedAnEarlierMissedMatchIsNotShown() throws {
        let t = try TestModel()
        try t.importFirstTeam()   // no tactic, so nothing is planned and the missed matches are shown
        t.model.addFixture(date: day("2026-09-01"), opponent: "Long ago", importance: .low)
        let recent = t.model.addFixture(date: day("2026-11-10"), opponent: "Last week", importance: .low)
        #expect(t.model.shownPlans.map(\.id) == [recent])
        t.model.setShowsEarlierMatches(true)
        #expect(t.model.shownPlans.count == 2)
    }
}
