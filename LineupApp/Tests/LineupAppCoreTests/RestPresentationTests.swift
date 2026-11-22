import Foundation
import Testing
@testable import LineupEngine
@testable import LineupAppCore

/// The Rest screen: a row for each player the engine lists, in its order, with the engine's words.
@MainActor @Suite struct RestPresentationTests {
    private func advice(_ key: String, name: String, level: RestLevel = .rest, jadedness: Int = 450, limit: Int = 400,
                        notes: [String] = [], condition: Double = 0.72, starts: Int = 3, days: Int? = 3,
                        reasons: [String] = ["Jadedness 450 is above his limit of 400: rest him from training and matches"],
                        basis: Evidence = .derived, trend: RestTrend? = nil) -> RestAdvice {
        RestAdvice(player: PlayerID(key: key), name: name, level: level, jadedness: jadedness, limit: limit,
                   limitNotes: notes, condition: condition, consecutiveStarts: starts, days: days, reasons: reasons,
                   basis: basis, trend: trend ?? unmeasured(imports: 0))
    }

    /// A trend with nothing seen yet, `imports` of the 4 it needs.
    private func unmeasured(imports: Int) -> RestTrend {
        RestTrend(squad: .firstTeam, seen: nil, imports: imports, importsNeeded: 4, passesOn: nil, drift: nil, gain: nil,
                  restWillNotClear: false, basis: .derived)
    }

    // MARK: Stamps

    @Test func eachLevelsStampHasTheEnginesWordAndItsColour() {
        #expect(RestPresentation.stamp(.holiday) == StatusStamp(text: "Holiday", tone: .red))
        #expect(RestPresentation.stamp(.rest) == StatusStamp(text: "Rest", tone: .amber))
        #expect(RestPresentation.stamp(.watch) == StatusStamp(text: "Watch", tone: .ink))
        #expect(RestLevel.allCases.map { RestPresentation.stamp($0).text } == RestLevel.allCases.map(AdvisorText.name))
    }

    @Test func aStatusStampIsRedWhenItKeepsHimOutAndAmberOtherwise() {
        #expect(StatusStamp(text: "Injured", isOut: true).tone == .red)
        #expect(StatusStamp(text: "Out of contract", isOut: false).tone == .amber)
        #expect(StatusStamp(text: "Injured", isOut: true).isOut)
        #expect(!StatusStamp(text: "Out of contract", isOut: false).isOut)
        #expect(!StatusStamp(text: "Watch", tone: .ink).isOut)
    }

    // MARK: Rows

    @Test func aRowHasHisNameSquadAndFiguresInTheEnginesWords() throws {
        let given = advice("caleb moir", name: "Caleb Moir", notes: ["under 19", "Stamina below 10"], condition: 0.761,
                           starts: 4, days: 2, reasons: ["First reason", "Second reason"])
        let rows = RestPresentation.rows([given], squads: [PlayerID(key: "caleb moir"): .u21], parameters: .fm27)
        let row = try #require(rows.first)
        #expect(row.id == PlayerID(key: "caleb moir"))
        #expect(row.name == "Caleb Moir")
        #expect(row.squadText == "U21s")
        #expect(row.stamp == StatusStamp(text: "Rest", tone: .amber))
        #expect(row.jadednessText == "450 against a limit of 400")
        #expect(row.limitNotesText == "under 19, Stamina below 10")
        #expect(row.conditionText == "76%")
        #expect(row.conditionMeter == Meter(fraction: 0.761))
        #expect(row.startsText == "4")
        #expect(row.clearText == "Clear in about 2 days")
        #expect(row.reasons == [MarkedReason(text: "First reason", direction: .unchanged),
                                MarkedReason(text: "Second reason", direction: .unchanged)])
        #expect(row.noteText == "(this tool's estimate)")
    }

    @Test func aRowsJadednessAndLimitNotesAreTheEnginesSentences() throws {
        let given = advice("p", name: "P", jadedness: -121, limit: 300, notes: ["aged 32 or over"])
        let row = try #require(RestPresentation.rows([given], squads: [:], parameters: .fm27).first)
        #expect(row.jadednessText == AdvisorText.jadedness(of: given))
        #expect(row.jadednessText == "\u{2212}121 against a limit of 300")
        #expect(row.limitNotesText == AdvisorText.limitNotes(of: given))
    }

    @Test func aRowWithTheStandardLimitHasNoNotes() throws {
        let row = try #require(RestPresentation.rows([advice("p", name: "P")], squads: [:], parameters: .fm27).first)
        #expect(row.limitNotesText == nil)
    }

    @Test func aWatchRowHasNoClearSentence() throws {
        let row = try #require(RestPresentation.rows([advice("p", name: "P", level: .watch, days: nil)], squads: [:], parameters: .fm27).first)
        #expect(row.clearText == nil)
        #expect(row.stamp.tone == .ink)
    }

    @Test func aRowWithFM27EvidenceHasNoNote() throws {
        let row = try #require(RestPresentation.rows([advice("p", name: "P", basis: .fm27Observation)], squads: [:], parameters: .fm27).first)
        #expect(row.noteText == nil)
        let carried = try #require(RestPresentation.rows([advice("p", name: "P", basis: .carriedOverFM26)], squads: [:], parameters: .fm27).first)
        #expect(carried.noteText == "(FM26-era numbers)")
    }

    @Test func aPlayerNotInTheSquadBookHasNoSquadText() throws {
        let row = try #require(RestPresentation.rows([advice("gone", name: "Gone")], squads: [PlayerID(key: "other"): .u21], parameters: .fm27).first)
        #expect(row.squadText == nil)
    }

    @Test func rowsKeepTheEnginesOrder() {
        let given = [advice("b", name: "B", level: .holiday), advice("a", name: "A", level: .rest),
                     advice("c", name: "C", level: .watch)]
        #expect(RestPresentation.rows(given, squads: [:], parameters: .fm27).map(\.name) == ["B", "A", "C"])
    }

    @Test func aRowIsSpokenWithItsStampNameFiguresAndReasons() throws {
        let given = advice("p", name: "Caleb Moir", notes: ["under 19"], reasons: ["One reason"])
        let row = try #require(RestPresentation.rows([given], squads: [PlayerID(key: "p"): .u21], parameters: .fm27).first)
        #expect(row.spokenText == "Rest, Caleb Moir, U21s, Jadedness 450 against a limit of 400, under 19, "
                + "Condition 72%, Starts in a row 3, Clear in about 3 days, One reason, His trend is not measured yet: "
                + "it needs 4 imports of his squad, and has 0., this tool's estimate, this tool's estimate")
    }

    // MARK: Trends

    @Test func aRowCarriesTheEnginesTrendLinesAsWritten() throws {
        let trend = RestTrend(squad: .firstTeam, seen: SeenTrend(perWeek: 45, days: 35, starts: 6, readings: 6),
                              imports: 6, importsNeeded: 4, passesOn: Day(year: 2026, month: 11, day: 29),
                              drift: MeasuredRate(-30.0 / 7, .squad(.firstTeam)), gain: MeasuredRate(61, .own(intervals: 3)),
                              restWillNotClear: false, basis: .derived)
        let given = advice("p", name: "P", level: .watch, days: nil, reasons: ["One reason"], trend: trend)
        let row = try #require(RestPresentation.rows([given], squads: [:], parameters: .fm27).first)
        #expect(row.trendLines == AdvisorText.trendLines(of: given, parameters: .fm27))
        #expect(row.trendLines.count == 3)
        #expect(row.trendLines.first == "Rising about 45 a week over the last 5 weeks, in which he started 6 matches "
                + "(from 6 readings).")
        #expect(row.trendNoteText == "(this tool's estimate)")
        for line in row.trendLines { #expect(row.spokenText.contains(line)) }
        // After the reasons.
        let reason = try #require(row.spokenText.range(of: "One reason"))
        let first = try #require(row.spokenText.range(of: row.trendLines[0]))
        #expect(reason.upperBound <= first.lowerBound)
    }

    @Test func anUnmeasuredRowSaysHowManyImportsItHas() throws {
        let row = try #require(RestPresentation.rows([advice("p", name: "P", trend: unmeasured(imports: 2))], squads: [:],
                                                     parameters: .fm27).first)
        #expect(row.trendLines == ["His trend is not measured yet: it needs 4 imports of his squad, and has 2."])
        #expect(row.trendNoteText == "(this tool's estimate)")
    }

    @Test func theTrendsNoteIsTheEnginesForItsEvidence() throws {
        let trend = RestTrend(squad: .firstTeam, seen: nil, imports: 1, importsNeeded: 4, passesOn: nil, drift: nil,
                              gain: nil, restWillNotClear: false, basis: .fm27Measured)
        let row = try #require(RestPresentation.rows([advice("p", name: "P", trend: trend)], squads: [:],
                                                     parameters: .fm27).first)
        #expect(row.trendNoteText == AdvisorText.note(for: .fm27Measured).map { "(\($0))" })
    }

    private let since = Day(year: 2026, month: 8, day: 25)!

    @Test func theHeaderHasALineForEachMeasuredSquadAndTheClub() {
        let trends = FitnessTrends(
            players: [:],
            squadDrift: [.u18: SharedRate(value: 0, readings: 9, since: since),
                         .firstTeam: SharedRate(value: -2, readings: 38, since: since),
                         .u21: SharedRate(value: 16.0 / 7, readings: 12, since: since)],
            clubGain: SharedRate(value: 31, readings: 14, since: since), measuredFrom: since)
        let header = RestPresentation.trendHeader(trends, readingsKept: true, parameters: .fm27)
        let engine = AdvisorText.squadTrendLines(trends, parameters: .fm27)
        #expect(header.squadLines.map(\.text) == engine.map(\.text))
        #expect(header.squadLines.map(\.id) == [0, 1, 2])
        #expect(header.squadLines.map(\.text) == [
            "First team: a player who does not start falls about 14 a week (from 38 readings since Tue 25 Aug; this "
                + "tool's estimate).",
            "U21s: a player who does not start rises about 16 a week (from 12 readings since Tue 25 Aug; this tool's "
                + "estimate).",
            "U18s: a player who does not start holds steady (from 9 readings since Tue 25 Aug; this tool's estimate).",
        ])
        // The caution only under a squad whose drift is 0 or above.
        let caution = "At this training load, leaving players out of matches cannot bring jadedness down."
        #expect(header.squadLines.map(\.caution) == [nil, caution, caution])
        #expect(header.clubLine == "A start adds about 31 (from 14 readings; this tool's estimate).")
        #expect(header.measuredFromText == "Trend measured from Tue 25 Aug.")
    }

    @Test func aHeaderWithNothingMeasuredHasNoLines() {
        let header = RestPresentation.trendHeader(.none, readingsKept: false, parameters: .fm27)
        #expect(header.squadLines.isEmpty)
        #expect(header.clubLine == nil)
        #expect(header.measuredFromText == nil)
        #expect(!header.offersMeasureAgain)
    }

    @Test func measureAgainIsOfferedOnceAReadingIsKept() throws {
        let kept = RestPresentation.trendHeader(.none, readingsKept: true, parameters: .fm27)
        #expect(kept.offersMeasureAgain)
        // With no day measured from, the button still shows on its own.
        #expect(kept.measuredFromText == nil)
        #expect(kept.showsMeasuredLine)
        let none = RestPresentation.trendHeader(.none, readingsKept: false, parameters: .fm27)
        #expect(!none.offersMeasureAgain)
        #expect(!none.showsMeasuredLine)
        // The sample's imports took a reading of every player.
        let model = try SampleData.model(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        guard case .ready(let report) = model.adviceState else {
            Issue.record("expected advice, got \(model.adviceState)")
            return
        }
        #expect(model.restTrendHeader(report).offersMeasureAgain)
        // Before any reading is kept, not offered.
        model.fitness = FitnessState()
        #expect(!model.restTrendHeader(report).offersMeasureAgain)
    }

    @Test func theModelsHeaderIsTheEnginesOnItsTrends() throws {
        let model = try SampleData.modelWithFallingTrends(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        guard case .ready(let report) = model.adviceState else {
            Issue.record("expected advice, got \(model.adviceState)")
            return
        }
        let header = model.restTrendHeader(report)
        #expect(header == RestPresentation.trendHeader(report.trends, readingsKept: true, parameters: model.planParameters))
        #expect(!header.squadLines.isEmpty)
        #expect(header.clubLine != nil)
        #expect(header.measuredFromText != nil)
    }

    @Test func theQuestionSaysHowManyImports() throws {
        #expect(RestPresentation.measureAgainQuestion(imports: 4)
                == "Measure the trend again from today? Nothing is measured until a squad has been imported 4 more times.")
        #expect(RestPresentation.measureAgainTitle == "Measure again from today")
        #expect(RestPresentation.measureAgainConfirm == "Measure again")
        #expect(RestPresentation.cancelTitle == "Cancel")
        // The model's number is the engine's.
        let model = try SampleData.model(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let imports = model.planParameters.jadednessTrendRules.value.fewestOwnIntervals + 1
        #expect(model.restMeasureAgainQuestion == RestPresentation.measureAgainQuestion(imports: imports))
    }

    @Test func theGameMessagesAreTheEngines() throws {
        #expect(RestPresentation.gameMessagesHeading == AdvisorText.gameMessagesHeading)
        #expect(RestPresentation.gameMessagesHeading == "What the game's messages mean")
        #expect(RestPresentation.gameMessages(.fm27) == AdvisorText.gameMessages(parameters: .fm27))
        #expect(RestPresentation.gameMessages(.fm27).count == 3)
        let model = try SampleData.model(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        #expect(model.restGameMessages == AdvisorText.gameMessages(parameters: model.planParameters))
    }

    // MARK: The sample models with readings

    @Test func theRisingSampleHasASquadCaution() throws {
        let model = try SampleData.modelWithRisingTrends(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        guard case .ready(let report) = model.adviceState else {
            Issue.record("expected advice, got \(model.adviceState)")
            return
        }
        #expect(model.restTrendHeader(report).squadLines.contains { $0.caution != nil })
    }

    @Test func theSampleBeforeTrendsSaysEachRowHasTwoImports() throws {
        let model = try SampleData.modelBeforeTrends(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        guard case .ready(let report) = model.adviceState else {
            Issue.record("expected advice, got \(model.adviceState)")
            return
        }
        let header = model.restTrendHeader(report)
        #expect(header.squadLines.isEmpty)
        #expect(header.clubLine == nil)
        #expect(header.offersMeasureAgain)
        let rows = model.restRows(report)
        #expect(!rows.isEmpty)
        #expect(rows.allSatisfy { $0.trendLines == ["His trend is not measured yet: it needs 4 imports of his squad, and has 2."] })
    }

    @Test func theRestedSampleLeavesAPlayerOutOfItsNextMatchBeforeHePassesTheLine() throws {
        let model = try SampleData.modelWithPlayerRestedBeforeLine(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let (next, _) = try nextPlanned(model)
        guard case .planned(let lineup, _) = next.body else { throw CancellationError() }
        let rested = try #require(lineup.omissions.first { $0.reason.contains("Rested before he passes 400") })
        #expect(LeftOutRow.rows(lineup.omissions).contains { $0.player == rested.player && $0.reason == rested.reason })
    }

    // MARK: Words

    @Test func theScreensOwnWords() {
        #expect(RestPresentation.explanation == "The planner decides who starts. This screen says who needs a break.")
        #expect(RestPresentation.nobody == "Nobody needs rest today.")
        #expect(RestPresentation.jadednessLabel == "Jadedness")
        #expect(RestPresentation.conditionLabel == "Condition")
        #expect(RestPresentation.startsLabel == "Starts in a row")
    }

    @Test func theEmptyStateShowsOnlyWhenNobodyIsListed() {
        #expect(RestPresentation.emptyText([]) == RestPresentation.nobody)
        #expect(RestPresentation.emptyText(RestPresentation.rows([advice("p", name: "P")], squads: [:], parameters: .fm27)) == nil)
    }

    // MARK: On the captured squads

    private func squad(_ t: TestModel) throws -> AppModel {
        try t.importFirstTeam()
        try t.importU21()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        t.model.addTactic(named: "4-2-3-1")
        return t.model
    }

    @Test func theModelsRowsAreTheAdvicesInItsOrderWithEachPlayersSquad() throws {
        let t = try TestModel()
        let model = try squad(t)
        guard case .ready(let report) = model.adviceState else {
            Issue.record("expected advice, got \(model.adviceState)")
            return
        }
        #expect(!report.rest.isEmpty)
        let rows = model.restRows(report)
        #expect(rows.map(\.id) == report.rest.map(\.player))
        let squads = Dictionary(model.squad.book.allPlayers.map { ($0.id, $0.squad) }, uniquingKeysWith: { a, _ in a })
        for (row, advice) in zip(rows, report.rest) {
            #expect(row.squadText == squads[advice.player]?.displayName)
            #expect(row.squadText != nil)
            #expect(row.stamp == RestPresentation.stamp(advice.level))
            #expect(row.reasons.map(\.text) == advice.reasons)
        }
    }

    // MARK: The plan

    /// The earliest fixture the plan has a lineup for, and that lineup's starters.
    private func nextPlanned(_ model: AppModel) throws -> (plan: FixturePlan, starters: [Pick]) {
        let plan = try #require(model.fixturePlans.first { if case .planned = $0.body { true } else { false } })
        guard case .planned(let lineup, _) = plan.body else { throw CancellationError() }
        return (plan, lineup.picks)
    }

    @Test func aRowSaysWhenThePlanStartsHimInItsNextFixture() throws {
        let model = try SampleData.model(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let (next, starters) = try nextPlanned(model)
        #expect(next.fixture.opponent == "Opponent A")
        let starter = try #require(starters.first)
        let benched = try #require(model.squad.book.allPlayers.first { player in !starters.contains { $0.player == player.id } })
        let given = [advice(starter.player.key, name: starter.name), advice(benched.id.key, name: benched.name)]
        let rows = RestPresentation.rows(given, squads: [:], next: next, parameters: .fm27)
        #expect(rows.map(\.planText) == ["In the plan to start v Opponent A on Sat 14 Nov.", nil])
        #expect(rows[0].spokenText.contains("In the plan to start v Opponent A on Sat 14 Nov."))
        // Said where the screen shows it: after the reasons, before the trend lines.
        let plan = try #require(rows[0].spokenText.range(of: "In the plan to start"))
        let trend = try #require(rows[0].spokenText.range(of: "His trend is not measured yet"))
        #expect(plan.upperBound <= trend.lowerBound)
        // Without a plan, nothing.
        #expect(RestPresentation.rows(given, squads: [:], parameters: .fm27).map(\.planText) == [nil, nil])
        #expect(RestPresentation.planText(for: starter.player, next: nil) == nil)
    }

    @Test func theModelsRowsSayWhoTheNextPlannedFixtureStarts() throws {
        // With the first fixture confirmed, the next planned fixture is the second.
        let model = try SampleData.modelAfterConfirmingFirst(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let (next, starters) = try nextPlanned(model)
        #expect(next.fixture.opponent == "Opponent B")
        guard case .ready(let report) = model.adviceState else {
            Issue.record("expected advice, got \(model.adviceState)")
            return
        }
        let rows = model.restRows(report)
        #expect(!rows.isEmpty)
        let starting = Set(starters.map(\.player))
        for row in rows {
            #expect(row.planText == (starting.contains(row.id) ? "In the plan to start v Opponent B on Tue 17 Nov." : nil))
        }
        // A player the engine lists who starts it says so.
        let given = advice(try #require(starters.first).player.key, name: "Starter")
        #expect(RestPresentation.rows([given], squads: [:], next: next, parameters: .fm27).first?.planText
                == "In the plan to start v Opponent B on Tue 17 Nov.")
    }

    @Test func noRowSaysAnythingAboutThePlanWhileThereIsNone() throws {
        // No fixtures: the plan is not ready.
        let t = try TestModel()
        let model = try squad(t)
        #expect(model.planState == .needsFixtures)
        guard case .ready(let report) = model.adviceState else {
            Issue.record("expected advice, got \(model.adviceState)")
            return
        }
        #expect(!model.restRows(report).isEmpty)
        #expect(model.restRows(report).allSatisfy { $0.planText == nil })
    }

    @Test func theModelListsNobodyWhenNobodyNeedsABreak() throws {
        let t = try TestModel()
        let model = try squad(t)
        // Everyone fresh, fit and with no run of starts.
        for squad in Squad.allCases {
            guard var players = model.squad.book.current[squad] else { continue }
            for index in players.indices {
                players[index].jadedness = 0
                players[index].condition = 1
            }
            _ = model.squad.book.apply(ImportResult(grid: "test", players: players, warnings: [], money: .weeklyPounds), to: squad)
        }
        model.replan()
        guard case .ready(let report) = model.adviceState else {
            Issue.record("expected advice, got \(model.adviceState)")
            return
        }
        #expect(model.restRows(report).isEmpty)
        #expect(RestPresentation.emptyText(model.restRows(report)) == "Nobody needs rest today.")
    }
}
