import Foundation
import LineupEngine

extension AppModel {
    /// The advisors' report for the saved state, from the plan's players, club, starting day, history and parameters,
    /// the plan settings' training intensity, the retrainings handed to the planner and those turned down, with the
    /// primary tactic and every saved tactic the engine accepts. Worked out when first read after a replan, and kept
    /// until the next. The plan failing does not stop the advice, and the advice failing does not stop the plan.
    public var adviceState: AdviceState {
        _ = adviceGeneration
        if let cache = adviceCache { return cache.state }
        let state = workedOutAdvice()
        adviceCache = AdviceCache(state: state)
        return state
    }

    /// The suggested importance of each saved fixture with no confirmed lineup whose tactic the engine accepts, among
    /// all such fixtures, with the planner's tiers for the fixture's own tactic. Empty while the advice is not ready; a
    /// fixture whose suggestion cannot be worked out has none.
    public var suggestions: [FixtureID: ImportanceSuggestion] {
        guard case .ready = adviceState else { return [:] }
        if let suggestions = adviceCache?.suggestions { return suggestions }
        let suggestions = workedOutSuggestions()
        adviceCache?.suggestions = suggestions
        return suggestions
    }

    /// The elevens and cover for a saved tactic: the advice's own for nil, the primary or an id no tactic has; for any
    /// other saved tactic, worked out for it when first asked for after a replan, with the advice's players and
    /// parameters.
    public func elevens(for tacticID: UUID?) -> ElevensState {
        let state = adviceState
        guard case .ready(let report) = state else { return .notReady(state) }
        guard let tacticID, tacticID != settings.primaryTacticID,
              let stored = tactics.first(where: { $0.id == tacticID }) else {
            return .ready(report.elevens, report.depth)
        }
        if let elevens = adviceCache?.elevens[tacticID] { return elevens }
        let elevens = workedOutElevens(stored.tactic)
        adviceCache?.elevens[tacticID] = elevens
        return elevens
    }

    /// "Advice worked out for N players" while the advice is ready; nil otherwise.
    public var adviceLine: String? {
        guard case .ready = adviceState else { return nil }
        return AdvicePresentation.readyLine(players: squad.book.allPlayers.count)
    }

    // MARK: Working it out

    /// Missing things first, in the order the plan asks for them: a squad, then a usable primary tactic.
    func workedOutAdvice() -> AdviceState {
        timesAdvised += 1
        let players = squad.book.allPlayers
        guard !players.isEmpty, let asOf = planStartDay else { return .needsSquad }
        if tactics.isEmpty { return .needsTactic([]) }
        guard let primary = primaryTactic else { return .needsTactic([Self.noPrimaryTactic]) }
        if let sentence = unusableSentence(primary.tactic) { return .needsTactic([sentence]) }
        let request = AdvisorsRequest(
            primary: primary.tactic, tactics: tactics.map(\.tactic).filter { unusableSentence($0) == nil },
            players: players, ownClub: ownClub, history: StartHistory(history.map(\.lineup)), asOf: asOf,
            intensity: settings.plan.trainingIntensity, accepted: retrainingForPlan, rejected: training.rejected)
        do {
            return .ready(try Advisors.report(request, catalog: catalog, profile: profile, parameters: planParameters))
        } catch {
            return Self.failedAdvice(error)
        }
    }

    /// The engine's sentence for the failure, and the screen that puts it right: a player's data is put right by
    /// importing his squad again; anything else the advisors refuse is in the engine's parameters, which only the
    /// condition floor in Settings changes.
    static func failedAdvice(_ error: any Error) -> AdviceState {
        let fix: Screen = error is RatingError || error is DuplicatePlayerError ? .squad : .settings
        return .failed([ErrorDescriptions.describe(error)], fix: fix)
    }

    /// The suggested importance for the fixture as `draft` has it: its date, competition, opponent's strength and
    /// tactic (the primary when it names none, or names one no longer saved), among the other saved fixtures with no
    /// confirmed lineup whose tactic the engine accepts, with the history's lineups and the planner's tiers for the
    /// draft's tactic. Nil while the advice is not ready, for a tactic the engine refuses, for a fixture whose lineup
    /// is confirmed (it is played), and when the engine cannot work it out.
    public func suggestion(for draft: FixtureDraft) -> ImportanceSuggestion? {
        guard case .ready = adviceState else { return nil }
        if let id = draft.id, history.contains(where: { $0.lineup.fixture == id }) { return nil }
        let stored = StoredFixture(id: draft.id ?? Self.draftFixtureID, date: draft.date, opponent: draft.opponent,
                                   importance: draft.importance, tacticID: draft.tacticID,
                                   competition: draft.competition, opponentStrength: draft.opponentStrength)
        guard let tactic = tactic(for: stored), unusableSentence(tactic.tactic) == nil,
              let tiers = tiers(for: tactic), let fixture = fixtureForPlanner(stored) else { return nil }
        let among = openFixtures().map(\.fixture).filter { $0.id != draft.id }
        return try? ImportanceAdvisor.suggest(for: fixture, among: among, confirmed: history.map(\.lineup),
                                              players: squad.book.allPlayers, tiers: tiers, parameters: planParameters)
    }

    /// The id a fixture not saved yet is handed to the engine with: no saved fixture's id is blank.
    private static let draftFixtureID = FixtureID("")

    /// Each saved fixture with no confirmed lineup whose tactic the engine accepts, with that tactic, in date order.
    private func openFixtures() -> [(tactic: StoredTactic, fixture: Fixture)] {
        let confirmed = Set(history.map(\.lineup.fixture))
        return fixtures.compactMap { stored -> (tactic: StoredTactic, fixture: Fixture)? in
            guard !confirmed.contains(stored.id), let tactic = tactic(for: stored), unusableSentence(tactic.tactic) == nil,
                  let fixture = fixtureForPlanner(stored) else { return nil }
            return (tactic, fixture)
        }
    }

    /// The planner's tiers for the tactic, worked out when first asked for after a replan and kept until the next;
    /// nil when the engine refuses it.
    private func tiers(for tactic: StoredTactic) -> SquadTiers? {
        if let cached = adviceCache?.tiers[tactic.id] { return cached }
        let tiers = try? SquadTiers.compute(tactic: tactic.tactic, players: squad.book.allPlayers, ownClub: ownClub,
                                            catalog: catalog, profile: profile, parameters: planParameters)
        adviceCache?.tiers[tactic.id] = .some(tiers)
        return tiers
    }

    private func workedOutSuggestions() -> [FixtureID: ImportanceSuggestion] {
        let open = openFixtures()
        let among = open.map(\.fixture)
        let players = squad.book.allPlayers
        let parameters = planParameters
        let lineups = history.map(\.lineup)
        var found: [FixtureID: ImportanceSuggestion] = [:]
        for (tactic, fixture) in open {
            guard let tiers = tiers(for: tactic) else { continue }
            do {
                found[fixture.id] = try ImportanceAdvisor.suggest(for: fixture, among: among, confirmed: lineups,
                                                                  players: players, tiers: tiers, parameters: parameters)
            } catch {
                continue   // that fixture has no suggestion
            }
        }
        return found
    }

    private func workedOutElevens(_ tactic: Tactic) -> ElevensState {
        timesElevensWorkedOut += 1
        let problems = problems(of: tactic)
        guard problems.isEmpty else { return .failed(problems) }
        let players = squad.book.allPlayers
        let club = ownClub
        let parameters = planParameters
        do {
            let elevens = try Elevens.report(tactic: tactic, players: players, ownClub: club, catalog: catalog,
                                             profile: profile, parameters: parameters)
            let depth = try Depth.report(tactic: tactic, players: players, ownClub: club, catalog: catalog,
                                         profile: profile, parameters: parameters)
            return .ready(elevens, depth)
        } catch {
            return .failed([ErrorDescriptions.describe(error)])
        }
    }
}
