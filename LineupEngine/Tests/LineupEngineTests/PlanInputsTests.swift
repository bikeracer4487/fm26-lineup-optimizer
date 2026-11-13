import Testing
import Foundation
@testable import LineupEngine

@Suite struct PlanInputsTests {
    @Test func standardSettingsHaveNoProblems() {
        let s = PlanSettings.standard
        #expect(s.problems().isEmpty)
        #expect(s.trainingIntensity == .medium)
        #expect(s.stability == 0.5)
        #expect(s.savingPlayers == 1)
        #expect(s.horizon == 5)
        #expect(s == PlanSettings())
    }

    @Test func settingsOutOfRangeAreReported() {
        let s = PlanSettings(stability: 1.2, savingPlayers: -1, horizon: 0)
        let problems = s.problems()
        #expect(problems.count == 3)
        #expect(problems.contains("Stability must be between 0 and 1, but is 1.2"))
        #expect(problems.contains { $0.hasPrefix("Saving players") })
        #expect(problems.contains { $0.hasPrefix("Horizon") })
        #expect(PlanSettings(stability: 0).problems().isEmpty)
        #expect(PlanSettings(stability: 1).problems().isEmpty)
        #expect(PlanSettings(savingPlayers: 0).problems().isEmpty)
    }

    @Test func confirmedLineupAndRetrainingRoundTripThroughJSON() throws {
        let day = try #require(Day(iso: "2026-11-14"))
        let lineup = ConfirmedLineup(
            fixture: FixtureID("f1"), date: day,
            starters: [SlotID.allCases[0]: .fmrte(7), SlotID.allCases[1]: PlayerID(key: "some name")])
        let data = try JSONEncoder().encode(lineup)
        #expect(try JSONDecoder().decode(ConfirmedLineup.self, from: data) == lineup)
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains(#""fmrte:7""#))
        #expect(!text.contains(#""key""#))

        let retraining = Retraining(player: .fmrte(9), position: Position.allCases[0], acceptedOn: day)
        let data2 = try JSONEncoder().encode(retraining)
        #expect(try JSONDecoder().decode(Retraining.self, from: data2) == retraining)

        let settings = PlanSettings(trainingIntensity: .high, stability: 0.3, savingPlayers: 2, horizon: 8)
        let data3 = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(PlanSettings.self, from: data3) == settings)
    }
}
