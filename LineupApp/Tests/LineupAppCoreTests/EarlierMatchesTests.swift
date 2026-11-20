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
}
