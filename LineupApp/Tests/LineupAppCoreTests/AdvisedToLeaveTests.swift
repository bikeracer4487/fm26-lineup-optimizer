import Foundation
import Testing
@testable import LineupEngine
@testable import LineupAppCore

/// The plan gives no development favour to a player Player Removal advises to move on, worked out from the inputs the
/// advice uses. Each test uses the sample with young players, whose plan favours some of them.
@MainActor @Suite struct AdvisedToLeaveTests {
    private func sample() throws -> AppModel { try SampleData.modelWithYoungPlayers(repositoryRoot: Captures.repositoryRoot) }

    /// Every pick of every planned fixture, in fixture order.
    private func picks(_ model: AppModel, sourceLocation: SourceLocation = #_sourceLocation) -> [Pick] {
        guard case .ready(let plans) = model.planState else {
            Issue.record("expected a ready plan, got \(model.planState)", sourceLocation: sourceLocation)
            return []
        }
        return plans.flatMap { plan -> [Pick] in
            if case .planned(let lineup, _) = plan.body { lineup.picks } else { [] }
        }
    }

    private func isFavoured(_ pick: Pick) -> Bool {
        pick.adjustments.contains { $0.kind == .development || $0.kind == .successor }
    }

    private func report(_ model: AppModel, sourceLocation: SourceLocation = #_sourceLocation) -> AdvisorsReport? {
        guard case .ready(let report) = model.adviceState else {
            Issue.record("expected ready advice, got \(model.adviceState)", sourceLocation: sourceLocation)
            return nil
        }
        return report
    }

    /// Changes the player in every squad held, as an import of the changed squads would, and replans.
    private func edit(_ model: AppModel, _ player: PlayerID, _ change: (inout Player) -> Void) {
        for squad in Squad.allCases {
            guard var players = model.squad.book.current[squad] else { continue }
            for index in players.indices where players[index].id == player { change(&players[index]) }
            _ = model.squad.book.apply(ImportResult(grid: "test", players: players, warnings: [],
                                                    money: model.squad.book.money ?? .weeklyPounds), to: squad)
        }
        model.replan()
    }

    @Test func theSetHandedToThePlannerIsTheAdvicesOwn() throws {
        let model = try sample()
        let advice = try #require(report(model))
        #expect(!advice.removal.advisedToLeave.isEmpty)
        #expect(model.advisedToLeaveForPlan == advice.removal.advisedToLeave)
        for pick in picks(model) where advice.removal.advisedToLeave.contains(pick.player) {
            #expect(!isFavoured(pick), "\(pick.name)")
        }
    }

    @Test func aYoungPlayerTheAdviceSendsAwayIsPlannedWithoutHisFavour() throws {
        let model = try sample()
        let favoured = try #require(picks(model).first(where: isFavoured))
        let young = favoured.player
        #expect(report(model)?.removal.advisedToLeave.contains(young) == false)
        // No contract, Injury Proneness 20, Controversy 20, Important Matches 1 and Temperament 1: Player Removal
        // advises him to go, and nothing the plan reads about him changes.
        edit(model, young) { player in
            player.monthsLeft = 0
            player.attributes[.injuryProneness] = 20
            player.attributes[.controversy] = 20
            player.attributes[.importantMatches] = 1
            player.attributes[.temperament] = 1
        }
        let advice = try #require(report(model)?.removal.advice.first { $0.player == young })
        #expect(advice.level == .high || advice.level == .critical)
        #expect(report(model)?.removal.advisedToLeave.contains(young) == true)
        #expect(model.advisedToLeaveForPlan.contains(young))
        #expect(!picks(model).contains { $0.player == young && isFavoured($0) })
    }

    @Test func whenTheAdviceCannotBeWorkedOutThePlanIsMadeWithNobodyLeftOut() throws {
        let model = try sample()
        let before = picks(model)
        let favoured = try #require(before.first(where: isFavoured))
        // A player with no Controversy: Player Removal cannot read him, and the planner does not need it.
        let other = try #require(model.squad.book.allPlayers.first { $0.id != favoured.player && $0.squad == .firstTeam })
        edit(model, other.id) { $0.attributes[.controversy] = nil }
        guard case .failed = model.adviceState else {
            Issue.record("expected the advice to stop, got \(model.adviceState)")
            return
        }
        #expect(model.advisedToLeaveForPlan.isEmpty)
        // The plan is made, the same as before, the favoured young player still favoured.
        #expect(picks(model) == before)
        #expect(picks(model).contains { $0.player == favoured.player && isFavoured($0) })
    }

    @Test func withDevelopmentAtZeroWhoIsAdvisedToLeaveIsNotWorkedOut() throws {
        let model = try sample()
        var count = model.timesAdvisedToLeaveWorkedOut
        model.replan()
        #expect(model.timesAdvisedToLeaveWorkedOut == count + 1)
        var settings = model.settings
        settings.plan.development = 0
        model.update(settings)
        count = model.timesAdvisedToLeaveWorkedOut
        model.replan()
        #expect(model.timesAdvisedToLeaveWorkedOut == count)
        #expect(model.advisedToLeaveForPlan.isEmpty)
        #expect(!picks(model).contains(where: isFavoured))
    }
}
