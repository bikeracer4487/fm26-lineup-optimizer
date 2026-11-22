import Foundation
import Testing
@testable import LineupEngine

/// The command line's saved readings and longer history (`plans/sample-fitness-readings.json`,
/// `plans/sample-history-with-readings.json`) must keep measuring what the commands in CLAUDE.md show.
@Suite struct FitnessReadingsFixtureTests {
    private func measured() throws -> FitnessTrends {
        let readings = try JSONDecoder().decode([String: [FitnessReading]].self,
                                                from: Fixtures.data("plans/sample-fitness-readings.json"))
        let history = try JSONDecoder().decode([ConfirmedLineup].self,
                                               from: Fixtures.data("plans/sample-history-with-readings.json"))
        var book = SquadBook()
        book.apply(try Importer.importPlayers(clipboard: Fixtures.text("captures/first-team.tsv"),
                                              fmrteConfig: Fixtures.data("captures/first-team.grids.json"),
                                              squad: .firstTeam), to: .firstTeam)
        return FitnessTrend.rates(
            readings: Dictionary(readings.map { (PlayerID(key: $0.key), $0.value) }, uniquingKeysWith: { first, _ in first }),
            confirmed: history, squads: Dictionary(book.allPlayers.map { ($0.id, $0.squad) }, uniquingKeysWith: { first, _ in first }),
            asOf: Day(iso: "2026-11-13")!, measureFrom: nil, parameters: .fm27)
    }

    @Test func theReadingsMeasureADriftAGainAndARisingStarter() throws {
        let trends = try measured()
        #expect(try #require(trends.squadDrift[.firstTeam]).value < 0)
        #expect(trends.clubGain != nil)
        #expect(trends.players.values.contains { player in
            if case .own? = player.gain?.source { true } else { false }
        })
        let tetek = try #require(trends.players[PlayerID(key: "dejan tetek")])
        let seen = try #require(tetek.seen)
        #expect(seen.perWeek > 0)
        let last = try JSONDecoder().decode([String: [FitnessReading]].self,
                                            from: Fixtures.data("plans/sample-fitness-readings.json"))["dejan tetek"]!.last!
        #expect(Double(last.jadedness) + seen.perWeek * 6 >= 400)
        #expect(trends.measuredFrom != nil)
    }
}
