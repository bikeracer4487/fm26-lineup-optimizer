import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

/// The owner's first session, from an empty directory to a confirmed match and an import after it, on the engine's
/// captured squads, then the app opened again on what it saved.
@MainActor @Suite struct EndToEndTests {
    private struct SampleFixture: Decodable {
        let date: Day
        let opponent: String
        let importance: Importance
    }

    private func plans(_ model: AppModel, sourceLocation: SourceLocation = #_sourceLocation) -> [FixturePlan] {
        guard case .ready(let plans) = model.planState else {
            Issue.record("expected a ready plan, got \(model.planState)", sourceLocation: sourceLocation)
            return []
        }
        return plans
    }

    private func lineup(_ plan: FixturePlan?, sourceLocation: SourceLocation = #_sourceLocation) -> Lineup? {
        guard case .planned(let lineup, _)? = plan?.body else {
            Issue.record("expected a planned lineup, got \(String(describing: plan?.body))", sourceLocation: sourceLocation)
            return nil
        }
        return lineup
    }

    private func fitness(_ plan: FixturePlan?, sourceLocation: SourceLocation = #_sourceLocation) -> [PlayerID: ProjectedFitness] {
        guard case .planned(_, let fitness)? = plan?.body else {
            Issue.record("expected a planned lineup, got \(String(describing: plan?.body))", sourceLocation: sourceLocation)
            return [:]
        }
        return fitness
    }

    private func expectImported(_ model: AppModel, sourceLocation: SourceLocation = #_sourceLocation) {
        guard case .imported? = model.lastImport else {
            Issue.record("expected an import, got \(String(describing: model.lastImport))", sourceLocation: sourceLocation)
            return
        }
    }

    @Test func theWholeFlowOnTheRealCaptures() throws {
        let t = try TestModel()
        let model = t.model
        #expect(model.planState == .needsSquad)

        // Both squads through the clipboard, and the club named in Settings, since the captured grid has no club column.
        try t.importFirstTeam()
        expectImported(model)
        try t.importU21()
        expectImported(model)
        #expect(model.squad.book.current[.firstTeam]?.count == 18)
        #expect(model.squad.book.current[.u21]?.count == 6)
        var settings = model.settings
        settings.clubName = "Oxford City"
        model.update(settings)
        #expect(model.ownClub == "Oxford City")
        #expect(model.planState == .needsTactic([]))

        model.addTactic(named: "4-2-3-1")
        #expect(model.primaryTactic?.tactic.name == "4-2-3-1")
        #expect(model.planState == .needsFixtures)

        let sampleFixtures = try JSONDecoder().decode([SampleFixture].self, from: Data(contentsOf: Captures.repositoryRoot
            .appendingPathComponent("LineupEngine/Tests/LineupEngineTests/Fixtures/plans/sample-fixtures.json")))
        for fixture in sampleFixtures {
            model.addFixture(date: fixture.date, opponent: fixture.opponent, importance: fixture.importance)
        }
        #expect(model.fixtures.map(\.opponent) == ["Opponent A", "Opponent B", "Opponent C", "Opponent D", "Opponent E"])
        #expect(model.notices.isEmpty)
        let planned = plans(model).compactMap { lineup($0) }
        #expect(planned.count == 5)
        #expect(planned.allSatisfy { $0.picks.count == 11 && $0.unfilled.isEmpty })

        // The owner's choices in the first fixture: a player outside the eleven fixed up front, then the left back left out.
        let ids = model.fixtures.map(\.id)
        let planBefore = try #require(lineup(plans(model).first))
        let striker = try #require(model.candidates(for: .ST_C, in: ids[0]).first { candidate in
            candidate.unavailable == nil && !planBefore.picks.contains { $0.player == candidate.player }
        })
        model.setOverride(striker.player, at: .ST_C, in: ids[0])
        let leftBack = try #require(lineup(plans(model).first)?.picks.first { $0.slot == .D_L })
        #expect(leftBack.player != striker.player)
        model.reject(leftBack.player, in: ids[0])

        let first = try #require(lineup(plans(model).first))
        let fixedStriker = first.picks.first { $0.slot == .ST_C }
        #expect(fixedStriker?.player == striker.player && fixedStriker?.isOverride == true)
        #expect(!first.picks.contains { $0.player == leftBack.player })
        #expect(first.omissions.first { $0.player == leftBack.player }?.cause == .excluded(.rejected))
        #expect(plans(model).first?.ignoredOverrides == [])

        // Confirming the first fixture: its starters carry the match into the second, until their squads are imported.
        #expect(model.canConfirm(ids[0]))
        model.confirm(ids[0])
        #expect(model.history.map(\.lineup.fixture) == [ids[0]])
        #expect(model.history.first?.lineup.starters == Dictionary(uniqueKeysWithValues: first.picks.map { ($0.slot, $0.player) }))
        #expect(model.history.first?.awaitingImport == [.firstTeam, .u21])
        guard case .confirmed? = plans(model).first?.body else {
            Issue.record("the first fixture is not confirmed"); return
        }
        let noteAfterConfirming = try #require(model.fitnessNote)
        #expect(noteAfterConfirming.hasPrefix("The match against Opponent A was confirmed after "))

        /// Rested from the plan's starting day: today until an import, then the day it is dated, which confirming
        /// moved up to the match's.
        func rested(_ id: PlayerID) throws -> ProjectedFitness {
            let player = try #require(model.players.first { $0.id == id })
            let start = try #require(model.planStartDay)
            return try FitnessProjection.afterDays(
                start.days(to: model.fixtures[1].date), ProjectedFitness(player), player: player,
                intensity: model.settings.plan.trainingIntensity, parameters: model.planParameters)
        }
        let squadOf = Dictionary(uniqueKeysWithValues: model.players.map { ($0.id, $0.squad) })
        let starter = try #require(first.picks.first { squadOf[$0.player] == .firstTeam && $0.player != striker.player })
        let atSecond = fitness(plans(model)[1])
        let starterThen = try #require(atSecond[starter.player])
        let restedThen = try #require(atSecond[leftBack.player])
        #expect(starterThen.condition < (try rested(starter.player)).condition)
        #expect(starterThen.daysSinceMatch == model.fixtures[0].date.days(to: model.fixtures[1].date))
        #expect(restedThen == (try rested(leftBack.player)))
        #expect(restedThen.daysSinceMatch == nil)

        // The first team imported again: its starters' figures are the imported ones; any U21 starter is still counted.
        try t.importFirstTeam()
        expectImported(model)
        #expect(model.history.first?.awaitingImport == [.u21])
        #expect(fitness(plans(model)[1])[starter.player] == (try rested(starter.player)))
        let youngStarters = first.picks.filter { squadOf[$0.player] == .u21 }
        if youngStarters.isEmpty {
            #expect(model.fitnessNote == nil)
        } else {
            #expect(model.fitnessNote == "The match against Opponent A was confirmed after the U21s were last imported. Its "
                + "starters from that squad are counted as having played 90 minutes; import the U21s again for their real fitness.")
        }
        #expect(model.fitnessNote != noteAfterConfirming)

        // The app opened again on what it saved.
        let reopened = t.reopened()
        #expect(reopened.notices.isEmpty)
        #expect(reopened.squad == model.squad)
        #expect(reopened.tactics == model.tactics)
        #expect(reopened.fixtures == model.fixtures)
        #expect(reopened.history == model.history)
        #expect(reopened.settings == model.settings)
        #expect(reopened.planState == model.planState)
        #expect(reopened.fitnessNote == model.fitnessNote)
    }
}
