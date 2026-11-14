import Foundation
import Testing
@testable import LineupEngine
@testable import LineupAppCore

/// The Rest screen: a row for each player the engine lists, in its order, with the engine's words.
@MainActor @Suite struct RestPresentationTests {
    private func advice(_ key: String, name: String, level: RestLevel = .rest, jadedness: Int = 450, limit: Int = 400,
                        notes: [String] = [], condition: Double = 0.72, starts: Int = 3, days: Int? = 3,
                        reasons: [String] = ["Jadedness 450 is above his limit of 400: rest him from training and matches"],
                        basis: Evidence = .derived) -> RestAdvice {
        RestAdvice(player: PlayerID(key: key), name: name, level: level, jadedness: jadedness, limit: limit,
                   limitNotes: notes, condition: condition, consecutiveStarts: starts, days: days, reasons: reasons,
                   basis: basis)
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
        let rows = RestPresentation.rows([given], squads: [PlayerID(key: "caleb moir"): .u21])
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
        let row = try #require(RestPresentation.rows([given], squads: [:]).first)
        #expect(row.jadednessText == AdvisorText.jadedness(of: given))
        #expect(row.jadednessText == "\u{2212}121 against a limit of 300")
        #expect(row.limitNotesText == AdvisorText.limitNotes(of: given))
    }

    @Test func aRowWithTheStandardLimitHasNoNotes() throws {
        let row = try #require(RestPresentation.rows([advice("p", name: "P")], squads: [:]).first)
        #expect(row.limitNotesText == nil)
    }

    @Test func aWatchRowHasNoClearSentence() throws {
        let row = try #require(RestPresentation.rows([advice("p", name: "P", level: .watch, days: nil)], squads: [:]).first)
        #expect(row.clearText == nil)
        #expect(row.stamp.tone == .ink)
    }

    @Test func aRowWithFM27EvidenceHasNoNote() throws {
        let row = try #require(RestPresentation.rows([advice("p", name: "P", basis: .fm27Observation)], squads: [:]).first)
        #expect(row.noteText == nil)
        let carried = try #require(RestPresentation.rows([advice("p", name: "P", basis: .carriedOverFM26)], squads: [:]).first)
        #expect(carried.noteText == "(FM26-era numbers)")
    }

    @Test func aPlayerNotInTheSquadBookHasNoSquadText() throws {
        let row = try #require(RestPresentation.rows([advice("gone", name: "Gone")], squads: [PlayerID(key: "other"): .u21]).first)
        #expect(row.squadText == nil)
    }

    @Test func rowsKeepTheEnginesOrder() {
        let given = [advice("b", name: "B", level: .holiday), advice("a", name: "A", level: .rest),
                     advice("c", name: "C", level: .watch)]
        #expect(RestPresentation.rows(given, squads: [:]).map(\.name) == ["B", "A", "C"])
    }

    @Test func aRowIsSpokenWithItsStampNameFiguresAndReasons() throws {
        let given = advice("p", name: "Caleb Moir", notes: ["under 19"], reasons: ["One reason"])
        let row = try #require(RestPresentation.rows([given], squads: [PlayerID(key: "p"): .u21]).first)
        #expect(row.spokenText == "Rest, Caleb Moir, U21s, Jadedness 450 against a limit of 400, under 19, "
                + "Condition 72%, Starts in a row 3, Clear in about 3 days, One reason, this tool's estimate")
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
        #expect(RestPresentation.emptyText(RestPresentation.rows([advice("p", name: "P")], squads: [:])) == nil)
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
        let rows = RestPresentation.rows(given, squads: [:], next: next)
        #expect(rows.map(\.planText) == ["In the plan to start v Opponent A on Sat 14 Nov.", nil])
        #expect(rows[0].spokenText.contains("In the plan to start v Opponent A on Sat 14 Nov."))
        // Without a plan, nothing.
        #expect(RestPresentation.rows(given, squads: [:]).map(\.planText) == [nil, nil])
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
        #expect(RestPresentation.rows([given], squads: [:], next: next).first?.planText
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
            _ = model.squad.book.apply(ImportResult(grid: "test", players: players, warnings: []), to: squad)
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
