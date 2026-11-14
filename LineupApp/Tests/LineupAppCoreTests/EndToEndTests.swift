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

    // MARK: The advisor screens

    private func report(_ model: AppModel, sourceLocation: SourceLocation = #_sourceLocation) -> AdvisorsReport? {
        guard case .ready(let report) = model.adviceState else {
            Issue.record("expected ready advice, got \(model.adviceState)", sourceLocation: sourceLocation)
            return nil
        }
        return report
    }

    /// The advisors' report for the model's saved state, asked of the engine directly: every saved tactic, every
    /// accepted retraining and every pair turned down.
    private func engineReport(_ model: AppModel) throws -> AdvisorsReport {
        let primary = try #require(model.primaryTactic)
        let request = AdvisorsRequest(
            primary: primary.tactic, tactics: model.tactics.map(\.tactic), players: model.squad.book.allPlayers,
            ownClub: model.ownClub, history: StartHistory(model.history.map(\.lineup)), asOf: try #require(model.planStartDay),
            intensity: model.settings.plan.trainingIntensity, accepted: model.training.accepted,
            rejected: model.training.rejected)
        return try Advisors.report(request, catalog: model.catalog, profile: model.profile, parameters: model.planParameters)
    }

    private func recommended(_ model: AppModel) -> [RecommendationCard] {
        for part in model.trainingParts { if case .recommended(let cards) = part { return cards } }
        return []
    }

    private func underWay(_ model: AppModel) -> [RetrainingRow] {
        for part in model.trainingParts { if case .underWay(let rows) = part { return rows } }
        return []
    }

    private func turnedDown(_ model: AppModel) -> [TurnedDownRow] {
        for part in model.trainingParts { if case .turnedDown(let rows) = part { return rows } }
        return []
    }

    private func recruit(_ model: AppModel) -> [String]? {
        for part in model.trainingParts { if case .recruit(let needs, _) = part { return needs } }
        return nil
    }

    @Test func theAdvisorScreensWorkOnTheRealSquad() throws {
        let model = try SampleData.modelBeforeRetraining(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        #expect(model.training.accepted.isEmpty)

        // The advice is ready, and is what the engine gives for the saved state.
        let before = try #require(report(model))
        #expect(before == (try engineReport(model)))
        #expect(model.adviceLine == AdvicePresentation.readyLine(players: model.squad.book.allPlayers.count))

        // Elevens: the primary tactic's elevens, as the engine solves them alone; a row for every slot, each place's
        // player, rating and familiarity on the row for his slot, and "Nobody" in each slot left unfilled.
        let primary = try #require(model.primaryTactic)
        let alone = try Elevens.report(tactic: primary.tactic, players: model.squad.book.allPlayers, ownClub: model.ownClub,
                                       catalog: model.catalog, profile: model.profile, parameters: model.planParameters)
        #expect(before.elevens == alone)
        #expect(model.elevens(for: nil) == .ready(before.elevens, before.depth))
        #expect(model.elevens(for: primary.id) == .ready(before.elevens, before.depth))
        for (eleven, places, unfilled) in [(Eleven.first, alone.first, alone.unfilledFirst),
                                           (Eleven.second, alone.second, alone.unfilledSecond)] {
            let sheet = model.elevenSheet(eleven, report: before.elevens, depth: before.depth)
            #expect(sheet.rows.map(\.slot) == before.depth.slots.map(\.slot))
            #expect(sheet.tokens.map(\.player) == places.map(\.player))
            #expect(sheet.unfilled == unfilled)
            for place in places {
                let row = try #require(sheet.rows.first { $0.slot == place.slot })
                #expect(row.player == place.player && row.name == place.name)
                #expect(row.ratingText == MatchText.oneDecimal(place.rating.value))
                #expect(row.familiarityText == ElevensPresentation.familiarityText(ip: place.ipFamiliarity,
                                                                                   oop: place.oopFamiliarity))
            }
            for slot in unfilled {
                #expect(sheet.rows.first { $0.slot == slot }?.name == ElevensPresentation.nobody)
            }
        }
        #expect(model.depthTokens(before.depth).map(\.slot) == before.depth.slots.map(\.slot))
        #expect(model.depthTokens(before.depth).filter(\.isThin).map(\.slot) == before.depth.thin)

        // Rest and Player Removal: a row for every piece of the engine's advice, in its order.
        #expect(model.restRows(before).map(\.id) == before.rest.map(\.player))
        #expect(model.removalSheet(before).rows.map(\.id) == before.removal.advice.map(\.player))
        #expect(model.removalSheet(before).loans.map(\.id) == before.removal.loans.map(\.player))

        // Fixtures: every fixture still to play has a suggested importance, in the engine's words.
        let suggestions = model.suggestions
        #expect(!model.fixtures.isEmpty)
        for fixture in model.fixtures {
            let suggestion = try #require(suggestions[fixture.id], "no suggestion for \(fixture.opponent)")
            let draft = model.fixtureDraft(for: fixture)
            #expect(model.suggestionNote(for: draft)?.text == AdvisorText.suggested(suggestion))
            #expect((model.suggestionLine(for: fixture) != nil) == (suggestion.importance != fixture.importance))
        }

        // Training: the engine's recommendations as cards; accepting the first moves it to "being retrained" and hands
        // it to the planner. The sample's scripted clock moves on a second at each reading, so no training action here
        // falls within the click guard's interval of the last.
        #expect(recommended(model) == TrainingPresentation.cards(before.training))
        let first = try #require(recommended(model).first)
        model.accept(first.choice)
        let retraining = Retraining(player: first.choice.player, position: first.choice.position,
                                    acceptedOn: model.settings.currentDate)
        #expect(model.training.accepted == [retraining])
        #expect(underWay(model).map(\.choice) == [first.choice])
        #expect(underWay(model).first?.positionText == AdvisorText.learning(first.choice.position))
        #expect(!recommended(model).contains { $0.choice == first.choice })
        // A player learns one position at a time: he is offered nothing else.
        #expect(!recommended(model).contains { $0.choice.player == first.choice.player })
        #expect(model.retrainingForPlan == [retraining])
        let afterAccepting = try #require(report(model))
        #expect(afterAccepting == (try engineReport(model)))
        #expect(recommended(model) == TrainingPresentation.cards(afterAccepting.training))

        // Turning down the next recommendation made before the acceptance, another player's: it is listed as turned
        // down and not offered, and each need it covered is covered by another recommendation or listed as a need, as
        // the engine's report says. On the captured squad the acceptance already covers the slot, so nobody else is
        // recommended for it and it is listed as being retrained for.
        let next = try #require(before.training.recommendations.first { $0.choice.player != first.choice.player })
        model.reject(next.choice)
        #expect(model.training.rejected == [next.choice])
        #expect(model.training.accepted == [retraining])
        #expect(turnedDown(model).map(\.choice) == [next.choice])
        #expect(turnedDown(model).first?.name == next.name)
        let afterRejecting = try #require(report(model))
        #expect(afterRejecting == (try engineReport(model)))
        #expect(recommended(model) == TrainingPresentation.cards(afterRejecting.training))
        #expect(!recommended(model).contains { $0.choice == next.choice })
        #expect(recruit(model) == afterRejecting.training.needsWithoutCandidates.map(AdvisorText.need))
        #expect(model.trainingParts.contains(.recruit(
            needs: afterRejecting.training.needsWithoutCandidates.map(AdvisorText.need),
            alreadyRetraining: AdvisorText.alreadyBeingRetrained(afterRejecting.training.needsBeingRetrained))))
        for need in next.needs {
            let offered = afterRejecting.training.recommendations.contains { $0.needs.contains(need) }
            let listed = afterRejecting.training.needsWithoutCandidates.contains(need)
                || afterRejecting.training.needsBeingRetrained.contains(need)
            #expect(offered || listed, "\(need) is neither offered nor listed")
        }

        // The app opened again on what it saved, then the accepted player's squad imported a day later: the import
        // reads his familiarity at the position.
        let input = ScriptedInput(today: SampleData.date)
        let reopened = AppModel(store: Store(directory: model.store.directory), environment: input.environment)
        #expect(reopened.notices.isEmpty)
        #expect(reopened.training == model.training)
        #expect(reopened.retrainingForPlan == [retraining])
        #expect(reopened.adviceState == model.adviceState)
        #expect(reopened.planState == model.planState)
        #expect(underWay(reopened) == underWay(model))
        #expect(turnedDown(reopened) == turnedDown(model))

        let learner = try #require(reopened.players.first { $0.id == first.choice.player })
        let observedBefore = try #require(reopened.training.observations[first.choice])
        reopened.moveToday(by: 1)
        switch learner.squad {
        case .firstTeam:
            input.clipboard = try Captures.firstTeam
            input.config = .data(try Captures.firstTeamGrids)
        case .u21:
            input.clipboard = try Captures.u21
            input.config = .data(try Captures.u21Grids)
        case .u18:
            Issue.record("the sample has no U18 squad"); return
        }
        reopened.importSquad(learner.squad)
        expectImported(reopened)
        let observedAfter = try #require(reopened.training.observations[first.choice])
        #expect(observedAfter.count == observedBefore.count + 1)
        #expect(observedAfter.last == FamiliarityObservation(day: SampleData.date.adding(days: 1),
                                                             familiarity: try #require(learner.familiarity[first.choice.position])))
        #expect(reopened.retrainingForPlan == [retraining])
        #expect(report(reopened) != nil)
    }
}
