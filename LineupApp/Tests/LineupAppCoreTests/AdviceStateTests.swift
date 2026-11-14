import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

/// The advice is worked out when first read after a change, so a test that never reads it pays nothing for it. Most
/// tests use both captured squads with no fixtures, so the plan is quick; those that need fixtures or history use the
/// sample.
@MainActor @Suite struct AdviceStateTests {
    private func sample() throws -> AppModel { try SampleData.model(repositoryRoot: Captures.repositoryRoot) }

    /// Both captured squads, the club named and the starter tactic as the primary; no fixtures.
    private func squad(_ t: TestModel) throws -> AppModel {
        try t.importFirstTeam()
        try t.importU21()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        t.model.addTactic(named: "4-2-3-1")
        return t.model
    }

    private func report(_ model: AppModel, sourceLocation: SourceLocation = #_sourceLocation) -> AdvisorsReport? {
        guard case .ready(let report) = model.adviceState else {
            Issue.record("expected ready advice, got \(model.adviceState)", sourceLocation: sourceLocation)
            return nil
        }
        return report
    }

    /// The engine's report for the model's state, asked for directly: the primary tactic, the given tactics (every
    /// saved one when nil), and the plan's players, club, date, history, intensity and retrainings.
    private func engineReport(_ model: AppModel, tactics: [Tactic]? = nil) throws -> AdvisorsReport {
        let request = AdvisorsRequest(
            primary: try #require(model.primaryTactic).tactic, tactics: tactics ?? model.tactics.map(\.tactic),
            players: model.squad.book.allPlayers, ownClub: model.ownClub,
            history: StartHistory(model.history.map(\.lineup)), asOf: try #require(model.squad.importedOn.values.max()),
            intensity: model.settings.plan.trainingIntensity, accepted: model.retrainingForPlan,
            rejected: model.training.rejected)
        return try Advisors.report(request, catalog: model.catalog, profile: model.profile, parameters: model.planParameters)
    }

    /// A copy of the primary tactic, saved under another name, with the in-possession striker taken out, so the engine
    /// refuses it.
    private func addRefusedTactic(_ model: AppModel) throws -> UUID {
        let id = model.addTactic(named: model.unusedTacticName("Broken"))
        var stored = try #require(model.tactics.first { $0.id == id })
        var draft = TacticDraft(stored.tactic)
        draft.toggle(.ST_C, in: .inPossession, catalog: model.catalog)
        stored.tactic = draft.tactic
        model.update(stored)
        #expect(!model.problems(of: stored.tactic).isEmpty)
        return id
    }

    /// A second tactic the engine accepts and that differs from the primary: the left inside forward made a winger.
    private func addOtherTactic(_ model: AppModel) throws -> UUID {
        let id = model.addTactic(named: model.unusedTacticName("Wide"))
        var stored = try #require(model.tactics.first { $0.id == id })
        var draft = TacticDraft(stored.tactic)
        draft.setRole("Winger", at: .AM_L, in: .inPossession)
        stored.tactic = draft.tactic
        model.update(stored)
        #expect(model.problems(of: stored.tactic).isEmpty)
        #expect(stored.tactic != model.primaryTactic?.tactic)
        return id
    }

    // MARK: Each state

    @Test func withNoSquadTheAdviceNeedsOne() {
        let model = SampleData.emptyModel()
        #expect(model.adviceState == .needsSquad)
        #expect(model.suggestions.isEmpty)
        #expect(model.elevens(for: nil) == .notReady(.needsSquad))
    }

    @Test func withASquadAndNoTacticTheAdviceNeedsOne() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        #expect(t.model.adviceState == .needsTactic([]))
        #expect(t.model.elevens(for: nil) == .notReady(.needsTactic([])))
    }

    @Test func withTacticsButNoPrimaryTheAdviceSaysSoAsThePlanDoes() throws {
        let t = try TestModel()
        let model = try squad(t)
        var settings = model.settings
        settings.primaryTacticID = nil
        model.update(settings)
        #expect(model.adviceState == .needsTactic(["No tactic is the primary one. Make one primary on the Tactics screen."]))
    }

    @Test func aPrimaryTheEngineRefusesGivesTheEnginesSentencesAndNoSuggestions() throws {
        let model = try SampleData.modelWithTacticProblem(repositoryRoot: Captures.repositoryRoot)
        let primary = try #require(model.primaryTactic)
        let problems = model.problems(of: primary.tactic)
        #expect(!problems.isEmpty)
        let expected = AdviceState.needsTactic(["\(primary.tactic.name) cannot be used: \(problems.joined(separator: "; "))."])
        #expect(model.adviceState == expected)
        #expect(model.planState == .needsTactic(["\(primary.tactic.name) cannot be used: \(problems.joined(separator: "; "))."]))
        #expect(model.suggestions.isEmpty)
        #expect(model.elevens(for: primary.id) == .notReady(expected))
    }

    @Test func aPlayerWithMissingDataStopsTheAdviceAndPointsToTheSquad() throws {
        let t = try TestModel()
        let model = try squad(t)
        var players = try #require(model.squad.book.current[.firstTeam])
        let name = players[0].name
        players[0].attributes[.consistency] = nil
        _ = model.squad.book.apply(ImportResult(grid: "test", players: players, warnings: []), to: .firstTeam)
        model.replan()
        #expect(model.adviceState == .failed(
            [ErrorDescriptions.describe(RatingError.missingAttribute(player: name, attribute: .consistency))], fix: .squad))
        #expect(model.elevens(for: nil) == .notReady(model.adviceState))
    }

    @Test func eachFailurePointsToTheScreenThatPutsItRight() {
        let missing = RatingError.missingFamiliarity(player: "Alice Smith", position: .goalkeeper)
        #expect(AppModel.failedAdvice(missing) == .failed([ErrorDescriptions.describe(missing)], fix: .squad))
        let attribute = RatingError.missingAttribute(player: "Alice Smith", attribute: .naturalFitness)
        #expect(AppModel.failedAdvice(attribute) == .failed([ErrorDescriptions.describe(attribute)], fix: .squad))
        let parameters = PlanError.badParameters(["conditionCurve is empty"])
        #expect(AppModel.failedAdvice(parameters) == .failed([ErrorDescriptions.describe(parameters)], fix: .settings))
    }

    @Test func theAdviceIsTheEnginesReportForThePlansSquadDateHistoryAndRetrainings() throws {
        let model = try sample()
        // The sample's retraining fills the slot it was recommended for, so it is stopped to see the recommendations.
        let sampled = try #require(model.training.accepted.first)
        model.stopRetraining(RetrainingChoice(player: sampled.player, position: sampled.position))
        let recommended = try #require(report(model)?.training.recommendations)
        try #require(recommended.count >= 2)
        // Turning one down and accepting another changes what is handed on.
        model.reject(recommended[1].choice)
        #expect(!(try #require(report(model))).training.recommendations.contains { $0.choice == recommended[1].choice })
        model.accept(recommended[0].choice)
        let other = try addOtherTactic(model)
        let advice = try #require(report(model))
        #expect(advice == (try engineReport(model)))
        #expect(model.tactics.contains { $0.id == other })
        #expect(model.training.accepted.map(\.player) == [recommended[0].choice.player])
        #expect(model.training.rejected == [recommended[1].choice])
    }

    @Test func aSavedTacticTheEngineRefusesIsLeftOutWithoutStoppingTheAdvice() throws {
        let t = try TestModel()
        let model = try squad(t)
        let refused = try addRefusedTactic(model)
        let usable = model.tactics.filter { $0.id != refused }.map(\.tactic)
        #expect(report(model) == (try engineReport(model, tactics: usable)))
    }

    @Test func thePlansFailureDoesNotStopTheAdvice() throws {
        let model = try SampleData.modelWithTwoMatchesOnOneDay(repositoryRoot: Captures.repositoryRoot)
        guard case .failed = model.planState else {
            Issue.record("expected the plan to stop, got \(model.planState)")
            return
        }
        #expect(report(model) == (try engineReport(model)))
    }

    @Test func theAdvicesFailureDoesNotStopThePlan() throws {
        let t = try TestModel()
        let model = try squad(t)
        model.addFixture(date: TestModel.today.adding(days: 1), opponent: "Rovers", importance: .medium)
        var players = try #require(model.squad.book.current[.firstTeam])
        players[0].attributes[.consistency] = nil
        _ = model.squad.book.apply(ImportResult(grid: "test", players: players, warnings: []), to: .firstTeam)
        model.replan()
        guard case .failed = model.adviceState else {
            Issue.record("expected the advice to stop, got \(model.adviceState)")
            return
        }
        guard case .ready(let plans) = model.planState else {
            Issue.record("expected a plan, got \(model.planState)")
            return
        }
        #expect(plans.count == 1)
    }

    // MARK: When it is worked out

    @Test func theAdviceIsWorkedOutOnceAfterEachChangeAndNotAgainUntilTheNext() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        t.model.addTactic(named: "4-2-3-1")
        let model = t.model
        var count = model.timesAdvised
        var last = model.adviceState
        func workedOut(_ what: String, changed: Bool?, sourceLocation: SourceLocation = #_sourceLocation) {
            let now = model.adviceState
            _ = model.adviceState
            #expect(model.timesAdvised == count + 1, "\(what): worked out once", sourceLocation: sourceLocation)
            if let changed { #expect((now != last) == changed, "\(what): changed", sourceLocation: sourceLocation) }
            count = model.timesAdvised
            last = now
        }
        #expect(model.timesAdvised == count + 1)
        count = model.timesAdvised
        _ = model.adviceState
        #expect(model.timesAdvised == count, "a second read works nothing out")

        try t.importU21()
        workedOut("an import", changed: true)

        let primary = try #require(model.primaryTactic)
        var edited = primary
        var draft = TacticDraft(edited.tactic)
        draft.setRole("Winger", at: .AM_L, in: .inPossession)
        edited.tactic = draft.tactic
        model.update(edited)
        workedOut("a tactic edit", changed: true)

        let choice = try #require(report(model)?.training.recommendations.first?.choice)
        count = model.timesAdvised
        model.accept(choice)
        workedOut("an accepted retraining", changed: true)

        settings = model.settings
        settings.plan.trainingIntensity = settings.plan.trainingIntensity == .high ? .low : .high
        model.update(settings)
        workedOut("a change of training intensity", changed: nil)

        settings = model.settings
        settings.fmrteConfigPath = "/elsewhere/config.json"
        model.update(settings)
        _ = model.adviceState
        #expect(model.timesAdvised == count, "a setting the advice does not read works nothing out")
    }

    @Test func aConfirmedLineupWorksTheAdviceOutAgainAndTakesItsFixturesSuggestionAway() throws {
        let model = try sample()
        let first = try #require(model.fixtures.first)
        #expect(model.suggestions[first.id] != nil)
        let count = model.timesAdvised
        model.confirm(first.id)
        #expect(model.history.contains { $0.lineup.fixture == first.id })
        #expect(model.suggestions[first.id] == nil)
        #expect(model.timesAdvised == count + 1)
    }

    @Test func aChangeOfTrainingIntensityChangesRestsDayEstimates() throws {
        let model = try sample()
        func days(_ intensity: TrainingIntensity) throws -> [PlayerID: Int?] {
            var settings = model.settings
            settings.plan.trainingIntensity = intensity
            model.update(settings)
            let rest = try #require(report(model)?.rest)
            return Dictionary(uniqueKeysWithValues: rest.map { ($0.player, $0.days) })
        }
        let low = try days(.low)
        let high = try days(.high)
        #expect(Set(low.keys) == Set(high.keys))
        let changed = low.keys.filter { low[$0]! != high[$0]! }
        #expect(!changed.isEmpty, "a player short of condition clears it sooner with lighter training")
        for player in changed {
            if let l = low[player]!, let h = high[player]! { #expect(l < h) }
        }
    }

    @Test func unlockingAConfirmedFixtureWorksTheAdviceOutAgain() throws {
        let model = try SampleData.modelAfterConfirmingFirst(repositoryRoot: Captures.repositoryRoot)
        let confirmed = try #require(model.history.first).lineup.fixture
        _ = model.adviceState
        let count = model.timesAdvised
        model.unlock(confirmed)
        #expect(!model.history.contains { $0.lineup.fixture == confirmed })
        let after = model.adviceState
        #expect(model.timesAdvised == count + 1)
        #expect(after == (try .ready(engineReport(model))))
    }

    @Test func changingThePrimaryTacticWorksTheAdviceOutAgainForTheNewOne() throws {
        let t = try TestModel()
        let model = try squad(t)
        let other = try addOtherTactic(model)
        let before = try #require(report(model))
        let count = model.timesAdvised
        model.makePrimary(other)
        let after = try #require(report(model))
        #expect(model.timesAdvised == count + 1)
        #expect(after == (try engineReport(model)))
        #expect(model.primaryTactic?.id == other)
        #expect(after.elevens != before.elevens)
    }

    // MARK: Suggestions

    /// The engine's suggestion for `fixture` among `among`, with the planner's tiers for `tactic`.
    private func engineSuggestion(_ model: AppModel, for fixture: StoredFixture, among: [StoredFixture],
                                  tactic: Tactic) throws -> ImportanceSuggestion {
        let tiers = try SquadTiers.compute(tactic: tactic, players: model.squad.book.allPlayers, ownClub: model.ownClub,
                                           catalog: model.catalog, profile: model.profile, parameters: model.planParameters)
        return try ImportanceAdvisor.suggest(
            for: try #require(model.fixtureForPlanner(fixture)), among: among.compactMap(model.fixtureForPlanner),
            confirmed: model.history.map(\.lineup), players: model.squad.book.allPlayers, tiers: tiers,
            parameters: model.planParameters)
    }

    @Test func suggestionsAreForUnconfirmedFixturesOnlyAndAreTheEngines() throws {
        let model = try SampleData.modelAfterConfirmingFirst(repositoryRoot: Captures.repositoryRoot)
        let confirmed = Set(model.history.map(\.lineup.fixture))
        let open = model.fixtures.filter { !confirmed.contains($0.id) }
        #expect(open.count == 4)
        #expect(Set(model.suggestions.keys) == Set(open.map(\.id)))
        let primary = try #require(model.primaryTactic).tactic
        for fixture in open {
            #expect(model.suggestions[fixture.id] == (try engineSuggestion(model, for: fixture, among: open, tactic: primary)))
        }
    }

    @Test func aSuggestionUsesItsFixturesOwnTactic() throws {
        let model = try sample()
        let other = try addOtherTactic(model)
        var fixture = model.fixtures[1]
        fixture.tacticID = other
        model.update(fixture)
        let tactic = try #require(model.tactics.first { $0.id == other }).tactic
        let saved = try #require(model.fixtures.first { $0.id == fixture.id })
        #expect(model.suggestions[fixture.id]
            == (try engineSuggestion(model, for: saved, among: model.fixtures, tactic: tactic)))
    }

    @Test func aFixtureWhoseTacticTheEngineRefusesHasNoSuggestion() throws {
        let model = try sample()
        let refused = try addRefusedTactic(model)
        var fixture = model.fixtures[2]
        fixture.tacticID = refused
        model.update(fixture)
        #expect(model.suggestions[fixture.id] == nil)
        #expect(model.suggestions.count == model.fixtures.count - 1)
    }

    // MARK: Elevens for a tactic

    @Test func elevensForThePrimaryOrNoTacticOrOneNotSavedAreTheAdvicesOwn() throws {
        let t = try TestModel()
        let model = try squad(t)
        let advice = try #require(report(model))
        let expected = ElevensState.ready(advice.elevens, advice.depth)
        #expect(model.elevens(for: nil) == expected)
        #expect(model.elevens(for: try #require(model.primaryTactic).id) == expected)
        #expect(model.elevens(for: UUID()) == expected)
    }

    @Test func elevensForAnotherTacticAreWorkedOutForItOnceUntilTheNextChange() throws {
        let t = try TestModel()
        let model = try squad(t)
        let other = try addOtherTactic(model)
        let tactic = try #require(model.tactics.first { $0.id == other }).tactic
        let players = model.squad.book.allPlayers
        let elevens = try Elevens.report(tactic: tactic, players: players, ownClub: model.ownClub, catalog: model.catalog,
                                         profile: model.profile, parameters: model.planParameters)
        let depth = try Depth.report(tactic: tactic, players: players, ownClub: model.ownClub, catalog: model.catalog,
                                     profile: model.profile, parameters: model.planParameters)
        let shown = model.elevens(for: other)
        #expect(shown == .ready(elevens, depth))
        #expect(shown != model.elevens(for: nil))
        let count = model.timesElevensWorkedOut
        _ = model.elevens(for: other)
        #expect(model.timesElevensWorkedOut == count)
        var settings = model.settings
        settings.fmrteConfigPath = "/elsewhere/config.json"
        model.update(settings)
        _ = model.elevens(for: other)
        #expect(model.timesElevensWorkedOut == count, "a change that does not replan keeps them")
        settings = model.settings
        settings.plan.trainingIntensity = settings.plan.trainingIntensity == .high ? .low : .high
        model.update(settings)
        _ = model.elevens(for: other)
        #expect(model.timesElevensWorkedOut == count + 1)
    }

    @Test func elevensForATacticTheEngineRefusesGiveItsSentences() throws {
        let t = try TestModel()
        let model = try squad(t)
        let refused = try addRefusedTactic(model)
        let tactic = try #require(model.tactics.first { $0.id == refused }).tactic
        #expect(model.elevens(for: refused) == .failed(model.problems(of: tactic)))
    }

    // MARK: What the screens show

    @Test func eachAdviceStateThatIsNotReadySaysWhatIsMissingAndWhereToPutItRight() {
        #expect(AdvicePresentation.notReady(.needsSquad) == NotReady(
            message: "No squad yet. Import your first team on the Squad screen to get advice.",
            problems: [], isFailure: false, action: "Go to Squad", screen: .squad))
        #expect(AdvicePresentation.notReady(.needsTactic([])) == NotReady(
            message: "No tactic yet. Add one on the Tactics screen to get advice.",
            problems: [], isFailure: false, action: "Go to Tactics", screen: .tactics))
        #expect(AdvicePresentation.notReady(.needsTactic(["A cannot be used: B."])) == NotReady(
            message: "The primary tactic cannot be used, so there is no advice.",
            problems: ["A cannot be used: B."], isFailure: false, action: "Go to Tactics", screen: .tactics))
        #expect(AdvicePresentation.notReady(.failed(["Bad."], fix: .settings)) == NotReady(
            message: "The advice could not be worked out.",
            problems: ["Bad."], isFailure: true, action: "Go to Settings", screen: .settings))
        #expect(AdvicePresentation.notReady(.failed(["Bad."], fix: .squad))?.action == "Go to Squad")
    }

    @Test func readyAdviceSaysWhichDaysImportItRestsOn() throws {
        let t = try TestModel()
        let model = try squad(t)
        #expect(AdvicePresentation.notReady(model.adviceState) == nil)
        #expect(AdvicePresentation.report(model.adviceState) == report(model))
        #expect(AdvicePresentation.report(.needsSquad) == nil)
        // The plan's own starting day, the latest import, in the app's words for a day.
        #expect(model.planStartDay == TestModel.today)
        #expect(model.adviceImportLine == "From the squad as imported on Fri 13 Nov.")
        #expect(AdvicePresentation.importLine(Day(iso: "2026-11-14")!) == "From the squad as imported on Sat 14 Nov.")
        #expect(SampleData.emptyModel().adviceImportLine == nil)
    }

    @Test func theImportLineFollowsTheLatestImportAndGoesWhileTheAdviceIsNotReady() throws {
        let t = try TestModel()
        let model = try squad(t)
        // The U21s imported again two days on: the advice rests on that day.
        model.moveToday(by: 2)
        try t.importU21()
        #expect(model.planStartDay == Day(iso: "2026-11-15")!)
        #expect(model.adviceImportLine == "From the squad as imported on Sun 15 Nov.")
        // Without a primary tactic there is no advice, and no line about it.
        var settings = model.settings
        settings.primaryTacticID = nil
        model.update(settings)
        #expect(AdvicePresentation.report(model.adviceState) == nil)
        #expect(model.adviceImportLine == nil)
    }

    @Test func theElevensScreenStartsOnTheFirstElevenOfThePrimaryWithNoSlotChosen() {
        let navigation = Navigation()
        #expect(navigation.elevensView == .first)
        #expect(navigation.elevensTacticID == nil)
        #expect(navigation.elevensSlot == nil)
        #expect(ElevensView.allCases.map(\.title) == ["First XI", "Second XI", "Depth"])
    }

    // MARK: The sample

    @Test func theSampleHasOneAcceptedRetrainingAndCompetitionsOnItsFixtures() throws {
        let model = try sample()
        #expect(model.training.accepted.count == 1)
        #expect(model.fixtures.map(\.competition) == [.minorCup, .league, .league, .friendly, .cup])
        #expect(model.fixtures.map(\.opponentStrength) == [.similar, .weaker, .muchStronger, .similar, .stronger])
        #expect(model.suggestions.count == 5)
        guard case .ready = model.planState else {
            Issue.record("expected a plan, got \(model.planState)")
            return
        }
    }
}
