import Foundation
import Testing
@testable import LineupEngine

/// The command line's saved readings and longer history (`plans/sample-fitness-readings.json`,
/// `plans/sample-history-with-readings.json`) must keep measuring what the commands in CLAUDE.md show.
@Suite struct FitnessReadingsFixtureTests {
    private let asOf = Day(iso: "2026-11-13")!

    private func book() throws -> SquadBook {
        var book = SquadBook()
        book.apply(try Importer.importPlayers(clipboard: Fixtures.text("captures/first-team.tsv"),
                                              fmrteConfig: Fixtures.data("captures/first-team.grids.json"),
                                              squad: .firstTeam), to: .firstTeam)
        return book
    }

    private func history() throws -> [ConfirmedLineup] {
        try JSONDecoder().decode([ConfirmedLineup].self, from: Fixtures.data("plans/sample-history-with-readings.json"))
    }

    private func measured(_ book: SquadBook) throws -> FitnessTrends {
        let readings = try JSONDecoder().decode([String: [FitnessReading]].self,
                                                from: Fixtures.data("plans/sample-fitness-readings.json"))
        return FitnessTrend.rates(
            readings: Dictionary(readings.map { (PlayerID(key: $0.key), $0.value) }, uniquingKeysWith: { first, _ in first }),
            confirmed: try history(),
            squads: Dictionary(book.allPlayers.map { ($0.id, $0.squad) }, uniquingKeysWith: { first, _ in first }),
            asOf: asOf, measureFrom: nil, parameters: .fm27)
    }

    @Test func theReadingsMeasureADriftAGainAndAnOwnGain() throws {
        let trends = try measured(book())
        #expect(try #require(trends.squadDrift[.firstTeam]).value < 0)
        #expect(trends.clubGain != nil)
        #expect(trends.players.values.contains { player in
            if case .own? = player.gain?.source { true } else { false }
        })
        #expect(trends.measuredFrom != nil)
    }

    @Test func theLastReadingIsThePaste() throws {
        let book = try book()
        let readings = try JSONDecoder().decode([String: [FitnessReading]].self,
                                                from: Fixtures.data("plans/sample-fitness-readings.json"))
        for player in book.allPlayers {
            let last = try #require(readings[player.id.key]?.last)
            #expect(last.day == asOf)
            #expect(last.jadedness == player.jadedness)
            #expect(abs(last.condition - player.condition) < 1e-9)
            #expect(abs(last.sharpness - player.sharpness) < 1e-9)
            #expect(last.isInjured == player.isInjured)
        }
    }

    @Test func aRegularStarterIsWatchedAsOnCourseFromHisPastedJadedness() throws {
        let book = try book()
        let advice = try Rest.advice(players: book.allPlayers, ownClub: book.ownClub(override: "Oxford City"),
                                     history: StartHistory(history()), asOf: asOf, intensity: .medium,
                                     trends: measured(book), parameters: .fm27)
        let tetek = try #require(advice.first { $0.name == "Dejan Tetek" })
        #expect(tetek.level == .watch)
        let passes = try #require(tetek.trend.passesOn)
        #expect(asOf.days(to: passes) <= 42)
    }
}
