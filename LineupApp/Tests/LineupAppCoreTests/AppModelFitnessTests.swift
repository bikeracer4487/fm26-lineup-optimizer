import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

/// The fitness readings kept at each import, and the jadedness rates the plan and the advice are handed from them.
@MainActor @Suite struct AppModelFitnessTests {
    private let today = TestModel.today

    /// The first team imported today, the club named, a medium fixture on each of the days after today given, and the
    /// starter tactic, added last so the fixtures are planned once.
    private func firstTeam(fixturesAfter offsets: [Int], _ t: TestModel) throws -> AppModel {
        try t.importFirstTeam()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        for (n, offset) in offsets.enumerated() {
            t.model.addFixture(date: today.adding(days: offset), opponent: "Opponent \(n + 1)", importance: .medium)
        }
        t.model.addTactic(named: "4-2-3-1")
        return t.model
    }

    private func ids(_ model: AppModel, _ squad: Squad) -> [PlayerID] {
        (model.squad.book.current[squad] ?? []).map(\.id)
    }

    private func moveDate(_ model: AppModel, to day: Day) {
        var settings = model.settings
        settings.currentDate = day
        model.update(settings)
    }

    private func plans(_ model: AppModel, sourceLocation: SourceLocation = #_sourceLocation) -> [FixturePlan] {
        guard case .ready(let plans) = model.planState else {
            Issue.record("expected a ready plan, got \(model.planState)", sourceLocation: sourceLocation)
            return []
        }
        return plans
    }

    /// Seven weekly readings of `player` ending today at `today`'s figures (`last`): three weeks without a start, rising
    /// 2 a day, then three with one start each, rising 2 a day and 40 a start; and a confirmed lineup with him in it
    /// three days before each of the last three readings. So he has his own drift of 2 a day and gain of 40.
    private func measured(_ player: PlayerID, name: String, last: FitnessReading)
        -> (readings: [FitnessReading], records: [ConfirmedRecord]) {
        let changes = [0, 14, 14, 14, 54, 54, 54]
        var readings: [FitnessReading] = []
        var records: [ConfirmedRecord] = []
        for k in 0...6 {
            let day = today.adding(days: -42 + 7 * k)
            let after = changes[(k + 1)...].reduce(0, +)
            readings.append(k == 6 ? last : FitnessReading(
                day: day, jadedness: last.jadedness - after, condition: 0.9, sharpness: 0.8, isInjured: false,
                includes: []))
            if k >= 4 {
                records.append(ConfirmedRecord(
                    lineup: ConfirmedLineup(fixture: FixtureID("past-\(k)"), date: day.adding(days: -3),
                                            starters: [.ST_C: player]),
                    names: [player: name], tacticName: "4-2-3-1", awaitingImport: []))
            }
        }
        return (readings, records)
    }

    /// The model with two fixtures, a first-team striker chosen to start the first, and readings and confirmed lineups
    /// that measure his own pair (drift 2 a day, gain 40), planned again.
    private func withMeasuredStriker(_ t: TestModel) throws -> (model: AppModel, him: Player) {
        let model = try firstTeam(fixturesAfter: [1, 4], t)
        let first = model.fixtures[0].id
        let him = try #require(model.candidates(for: .ST_C, in: first).compactMap { candidate in
            model.players.first { $0.id == candidate.player && candidate.unavailable == nil }
        }.first { $0.squad == .firstTeam && !$0.isInjured && $0.jadedness > -250 && $0.jadedness < 500 })
        model.setOverride(him.id, at: .ST_C, in: first)
        let (readings, records) = measured(him.id, name: him.name,
                                           last: FitnessReading(day: today, player: him, includes: []))
        var state = FitnessState()
        state.readings = [him.id: readings]
        model.fitness = state
        model.history = records
        model.replan()
        return (model, him)
    }

    // MARK: Recording

    @Test func anImportRecordsAReadingWithTheFixturesThenWaiting() throws {
        let t = try TestModel()
        let model = try firstTeam(fixturesAfter: [1, 4], t)
        let match = model.fixtures[0].id
        model.confirm(match)
        #expect(model.history.first?.awaitingImport == [.firstTeam])
        let later = today.adding(days: 2)
        moveDate(model, to: later)
        try t.importFirstTeam()

        let squad = model.squad.book.current[.firstTeam] ?? []
        #expect(!squad.isEmpty)
        for player in squad {
            let readings = try #require(model.fitness.readings[player.id])
            #expect(readings.map(\.day) == [today, later])
            #expect(readings.first?.includes == [])
            #expect(readings.last == FitnessReading(day: later, player: player, includes: [match]))
        }
        #expect(model.history.first?.awaitingImport.isEmpty == true)
    }

    @Test func aSquadNotImportedIsNotRead() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let firstTeam = ids(t.model, .firstTeam)
        let before = t.model.fitness.readings
        let later = today.adding(days: 3)
        moveDate(t.model, to: later)
        try t.importU21()
        for id in firstTeam { #expect(t.model.fitness.readings[id] == before[id]) }
        let youngsters = ids(t.model, .u21)
        #expect(!youngsters.isEmpty)
        for id in youngsters { #expect(t.model.fitness.readings[id]?.map(\.day) == [later]) }
    }

    @Test func theReadingsAreSavedAndOpenAgain() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        moveDate(t.model, to: today.adding(days: 4))
        try t.importFirstTeam()
        #expect(!t.model.fitness.readings.isEmpty)
        #expect(t.reopened().fitness == t.model.fitness)
    }

    @Test func stateFromBeforeOpensWithNoNoticeAndAFirstReading() throws {
        let t = try TestModel()
        let model = try firstTeam(fixturesAfter: [1, 4], t)
        try t.importU21()
        let match = model.fixtures[0].id
        model.confirm(match)
        let matchDay = today.adding(days: 1)
        #expect(model.settings.currentDate == matchDay)
        // The U21s imported on the match day, after it: their import no longer awaits the match.
        try t.importU21()
        #expect(model.history.first?.awaitingImport == [.firstTeam])
        let plan = model.planState

        try FileManager.default.removeItem(at: t.directory.appendingPathComponent("fitness.json"))
        let reopened = t.reopened()
        #expect(reopened.notices.isEmpty)
        for player in reopened.squad.book.current[.firstTeam] ?? [] {
            #expect(reopened.fitness.readings[player.id] == [FitnessReading(day: today, player: player, includes: [])])
        }
        let youngsters = reopened.squad.book.current[.u21] ?? []
        #expect(!youngsters.isEmpty)
        for player in youngsters {
            #expect(reopened.fitness.readings[player.id] == [FitnessReading(day: matchDay, player: player, includes: [match])])
        }
        #expect(reopened.fitness.measureFrom == nil)
        #expect(reopened.planState == plan)
        // The first reading is saved.
        #expect(t.reopened().fitness == reopened.fitness)
    }

    @Test func anImportAfterTheDateIsMovedBackDropsThatSquadsLaterReadings() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        try t.importU21()
        let week = today.adding(days: 7)
        moveDate(t.model, to: week)
        try t.importFirstTeam()
        try t.importU21()
        // The game reloaded to an earlier save: the date is moved back and only the first team imported again.
        let back = today.adding(days: 3)
        moveDate(t.model, to: back)
        try t.importFirstTeam()
        let firstTeam = ids(t.model, .firstTeam), youngsters = ids(t.model, .u21)
        #expect(!firstTeam.isEmpty && !youngsters.isEmpty)
        for id in firstTeam { #expect(t.model.fitness.readings[id]?.map(\.day) == [today, back]) }
        for id in youngsters { #expect(t.model.fitness.readings[id]?.map(\.day) == [today, week]) }
        #expect(t.reopened().fitness == t.model.fitness)
    }

    @Test func anUnreadableFitnessFileGivesANoticeIsKeptAsideAndAFirstReadingIsTaken() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let week = today.adding(days: 7)
        moveDate(t.model, to: week)
        try t.importU21()
        try Data("{".utf8).write(to: t.directory.appendingPathComponent("fitness.json"))
        let reopened = t.reopened()
        #expect(reopened.notices.count == 1)
        #expect(reopened.notices.first?.text.contains("fitness.unreadable-1.json") == true)
        #expect(try Data(contentsOf: t.directory.appendingPathComponent("fitness.unreadable-1.json")) == Data("{".utf8))
        // A first reading of each squad held, on the day it was last imported.
        let firstTeam = reopened.squad.book.current[.firstTeam] ?? []
        let youngsters = reopened.squad.book.current[.u21] ?? []
        #expect(!firstTeam.isEmpty && !youngsters.isEmpty)
        for player in firstTeam { #expect(reopened.fitness.readings[player.id]?.map(\.day) == [today]) }
        for player in youngsters { #expect(reopened.fitness.readings[player.id]?.map(\.day) == [week]) }
        // Saved in its place, so the next start has nothing to report.
        let again = t.reopened()
        #expect(again.notices.isEmpty)
        #expect(again.fitness == reopened.fitness)
    }

    @Test func aFitnessFileThatCanBeNeitherReadNorMovedAsideTakesNoFirstReadingAndIsNotWrittenOver() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let file = t.directory.appendingPathComponent("fitness.json")
        try Data("{".utf8).write(to: file)
        struct Refused: Error {}
        let store = Store(directory: t.directory, move: { _, _ in throw Refused() }, copy: { _, _ in throw Refused() })
        let model = AppModel(store: store, environment: t.input.environment)
        #expect(model.fitness.readings.isEmpty)
        #expect(model.notices.count == 1)
        #expect(try Data(contentsOf: file) == Data("{".utf8))
    }

    @Test func aStateWithReadingsTakesNoFirstReadingAtLaunch() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let gone = PlayerID(key: "gone")
        var state = FitnessState()
        state.readings = [gone: [FitnessReading(day: today, jadedness: 0, condition: 1, sharpness: 1, isInjured: false,
                                                includes: [])]]
        t.model.fitness = state
        t.model.save(.fitness)
        #expect(t.reopened().fitness == state)
    }

    // MARK: The rates

    @Test func withTooFewReadingsThePlanUsesTheFixedFigures() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        moveDate(t.model, to: today.adding(days: 7))
        let model = try firstTeam(fixturesAfter: [10, 13], t)
        #expect(model.planStartDay == today.adding(days: 7))
        for id in ids(model, .firstTeam) { #expect(model.fitness.readings[id]?.count == 2) }
        #expect(model.fitnessTrends.pairs.isEmpty)
        #expect(!model.fitnessTrends.players.isEmpty)
        let withReadings = model.workedOutPlan()
        guard case .ready = withReadings else { Issue.record("expected a ready plan, got \(withReadings)"); return }
        model.fitness = FitnessState()
        #expect(model.fitnessTrends == .none)
        #expect(model.workedOutPlan() == withReadings)
    }

    @Test func withTooFewReadingsTheAdviceDiffersOnlyInTheImportsCounted() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        try t.importU21()
        moveDate(t.model, to: today.adding(days: 7))
        try t.importU21()
        let model = try firstTeam(fixturesAfter: [10, 13], t)
        guard case .ready(let report) = model.adviceState else {
            Issue.record("expected ready advice, got \(model.adviceState)"); return
        }
        let request = AdvisorsRequest(
            primary: try #require(model.primaryTactic).tactic, tactics: model.tactics.map(\.tactic),
            players: model.squad.book.allPlayers, ownClub: model.ownClub,
            history: StartHistory(model.history.map(\.lineup)), asOf: try #require(model.planStartDay),
            intensity: model.settings.plan.trainingIntensity, accepted: model.retrainingForPlan,
            rejected: model.training.rejected)
        let unmeasured = try Advisors.report(request, money: model.squad.book.moneyStyle, catalog: model.catalog,
                                             profile: model.profile, parameters: model.planParameters)
        #expect(report.elevens == unmeasured.elevens)
        #expect(report.depth == unmeasured.depth)
        #expect(report.removal == unmeasured.removal)
        #expect(report.training == unmeasured.training)
        #expect(report.trends == model.fitnessTrends)
        #expect(!report.rest.isEmpty)
        try #require(report.rest.count == unmeasured.rest.count)
        for (now, before) in zip(report.rest, unmeasured.rest) {
            #expect(now.player == before.player)
            #expect(now.level == before.level)
            #expect(now.days == before.days)
            #expect(now.reasons == before.reasons)
            #expect(now.limit == before.limit)
            #expect(now.basis == before.basis)
            #expect(before.trend.imports == 0)
            #expect(now.trend.imports >= 1)
            #expect(now.trend.seen == nil && now.trend.drift == nil && now.trend.gain == nil)
            #expect(now.trend.passesOn == before.trend.passesOn)
            #expect(now.trend.restWillNotClear == before.trend.restWillNotClear)
        }
    }

    @Test func noTrendsBeforeASquadIsImported() throws {
        let t = try TestModel()
        #expect(t.model.fitnessTrends == .none)
    }

    @Test func measuredRatesReachThePlanAndTheAdvice() throws {
        let t = try TestModel()
        let (model, him) = try withMeasuredStriker(t)
        let pair = try #require(model.fitnessTrends.pairs[him.id])
        #expect(pair.drift == MeasuredRate(2, .own(intervals: 3)))
        #expect(pair.gain == MeasuredRate(40, .own(intervals: 3)))

        let plans = plans(model)
        try #require(plans.count == 2)
        guard case .planned(let first, _) = plans[0].body, case .planned(_, let fitness) = plans[1].body else {
            Issue.record("expected two planned fixtures"); return
        }
        #expect(first.picks.contains { $0.player == him.id && $0.slot == .ST_C })
        let days = today.days(to: plans[1].fixture.date)
        let projected = try #require(fitness[him.id]).jadedness
        #expect(abs(projected - (Double(him.jadedness) + 40 + 2 * Double(days))) < 1e-9)

        guard case .ready(let report) = model.adviceState else {
            Issue.record("expected ready advice, got \(model.adviceState)"); return
        }
        #expect(report.trends == model.fitnessTrends)
        #expect(report.trends.players[him.id]?.pair == pair)
    }

    @Test func measureAgainKeepsTheReadingsAndTakesThemOutOfTheRates() throws {
        let t = try TestModel()
        let (model, him) = try withMeasuredStriker(t)
        #expect(model.fitnessTrends.pairs[him.id] != nil)
        let readings = model.fitness.readings
        let planned = model.timesPlanned
        _ = model.adviceState
        let advised = model.timesAdvised

        model.measureTrendAgain()
        #expect(model.fitness.readings == readings)
        #expect(model.fitness.measureFrom == model.settings.currentDate)
        #expect(model.fitnessTrends.pairs.isEmpty)
        #expect(model.timesPlanned == planned + 1)
        _ = model.adviceState
        #expect(model.timesAdvised == advised + 1)
        let reopened = t.reopened()
        #expect(reopened.fitness.readings == readings)
        #expect(reopened.fitness.measureFrom == model.settings.currentDate)
    }

    @Test func aPlayerWhoLeftEverySquadIsNotMeasured() throws {
        let t = try TestModel()
        let model = try firstTeam(fixturesAfter: [1, 4], t)
        let gone = PlayerID(key: "gone")
        let (readings, records) = measured(gone, name: "Gone", last: FitnessReading(
            day: today, jadedness: 100, condition: 0.9, sharpness: 0.8, isInjured: false, includes: []))
        var state = model.fitness
        state.readings[gone] = readings
        model.fitness = state
        model.history = records
        model.replan()
        #expect(model.fitnessTrends.players[gone] == nil)
        #expect(model.fitnessTrends.pairs[gone] == nil)
        #expect(plans(model).count == 2)
        guard case .ready = model.adviceState else { Issue.record("expected ready advice, got \(model.adviceState)"); return }
    }
}
