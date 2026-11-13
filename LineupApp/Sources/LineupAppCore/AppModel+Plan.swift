import Foundation
import LineupEngine

extension AppModel {
    // MARK: The owner's choices

    /// Fixes `player` in `slot` for the fixture, replacing whoever was fixed there; nil clears the slot.
    public func setOverride(_ player: PlayerID?, at slot: SlotID, in fixture: FixtureID) {
        changeFixture(fixture) { $0.overrides[slot] = player }
    }

    /// Leaves the player out of this fixture only.
    public func reject(_ player: PlayerID, in fixture: FixtureID) {
        changeFixture(fixture) { $0.rejected.insert(player) }
    }

    /// Undoes `reject`.
    public func allow(_ player: PlayerID, in fixture: FixtureID) {
        changeFixture(fixture) { $0.rejected.remove(player) }
    }

    /// Records the fixture's planned lineup as played: the starters by slot, their names as the squad has them now,
    /// and the tactic's name. Nothing happens unless the fixture has a planned lineup.
    public func confirm(_ fixture: FixtureID) {
        guard let plan = fixturePlans.first(where: { $0.id == fixture }),
              case .planned(let lineup, _) = plan.body else { return }
        let starters = Dictionary(uniqueKeysWithValues: lineup.picks.map { ($0.slot, $0.player) })
        let names = Dictionary(uniqueKeysWithValues: lineup.picks.map { ($0.player, $0.name) })
        history.append(ConfirmedRecord(
            lineup: ConfirmedLineup(fixture: fixture, date: plan.fixture.date, starters: starters),
            names: names, tacticName: plan.tacticName))
        save(.history)
        replan()
    }

    /// Removes the fixture's confirmed lineup, so it is planned again with its saved choices.
    public func unlock(_ fixture: FixtureID) {
        guard history.contains(where: { $0.lineup.fixture == fixture }) else { return }
        history.removeAll { $0.lineup.fixture == fixture }
        save(.history)
        replan()
    }

    /// Every player not out on loan, with his full-fitness rating in the slot for the fixture's tactic, best first,
    /// and why he cannot play in that fixture if he cannot: the engine's rule, judged on the fitness the plan projects
    /// for that day, worded as the selector words it. Empty when the fixture has no planned lineup or its tactic has
    /// no such slot.
    public func candidates(for slot: SlotID, in fixture: FixtureID) -> [Candidate] {
        let planned = fixturePlans.compactMap { plan -> (FixturePlan, [PlayerID: ProjectedFitness])? in
            if case .planned(_, let fitness) = plan.body { (plan, fitness) } else { nil }
        }
        guard let index = planned.firstIndex(where: { $0.0.id == fixture }), let asOf = planStartDay,
              let tactic = tactic(for: planned[index].0.fixture)?.tactic,
              let assignment = try? tactic.assignments(catalog: catalog).first(where: { $0.slot == slot })
        else { return [] }
        let (plan, fitness) = planned[index]
        let parameters = planParameters
        let projected = Self.fitnessIsProjected(at: index, date: plan.fixture.date, asOf: asOf)
        let club = ownClub
        let players = squad.book.allPlayers.filter {
            if case .loanedOut = LoanStatus.of($0, ownClub: club) { false } else { true }
        }
        let engine = RatingEngine(profile: profile, parameters: parameters, configuration: .fm27)
        // The tiers rate everyone but injured players, who are rated here so they can be shown with the reason.
        guard let tiers = try? SquadTiers.compute(tactic: tactic, players: players, ownClub: club, catalog: catalog,
                                                  profile: profile, parameters: parameters) else { return [] }

        var found: [Candidate] = []
        for player in players {
            guard let rating = tiers.ratings[player.id]?[slot] ?? (try? engine.rating(for: player, in: assignment).value)
            else { continue }
            var onTheDay = player
            if let projection = fitness[player.id] {
                onTheDay.condition = projection.condition
                onTheDay.sharpness = projection.sharpness
                onTheDay.jadedness = Int(projection.jadedness.rounded())
            }
            let exclusion = RiskRules.exclusion(
                for: onTheDay, loan: LoanStatus.of(player, ownClub: club), importance: plan.fixture.importance,
                isNextFixture: index == 0, parameters: parameters)
                ?? (plan.fixture.rejected.contains(player.id) ? .rejected : nil)
            found.append(Candidate(
                player: player.id, name: player.name, squad: player.squad, rating: rating,
                unavailable: exclusion.map { ErrorDescriptions.describe($0, parameters: parameters, projected: projected) }))
        }
        return found.sorted { ($1.rating, $0.name, $0.player.key) < ($0.rating, $1.name, $1.player.key) }
    }

    // MARK: Working the plan out

    /// The plan for the saved state, in the order Match Selection asks for what is missing: a squad, a usable tactic
    /// for every fixture still to plan, then fixtures.
    func workedOutPlan() -> PlanState {
        let players = squad.book.allPlayers
        guard !players.isEmpty, let asOf = planStartDay else { return .needsSquad }
        let confirmed = Dictionary(history.map { ($0.lineup.fixture, $0) }, uniquingKeysWith: { first, _ in first })
        let toPlan = fixtures.filter { confirmed[$0.id] == nil }
        var tacticOf: [FixtureID: StoredTactic] = [:]
        for fixture in toPlan {
            guard let stored = tactic(for: fixture), problems(of: stored.tactic).isEmpty else { return .needsTactic }
            tacticOf[fixture.id] = stored
        }
        if tactics.isEmpty { return .needsTactic }
        if fixtures.isEmpty { return .needsFixtures }

        let parameters = planParameters
        let request = PlanRequest(
            fixtures: toPlan.map { fixture in
                Fixture(id: fixture.id, date: fixture.date, opponent: fixture.opponent, importance: fixture.importance,
                        tactic: tacticOf[fixture.id]!.tactic, overrides: fixture.overrides, rejected: fixture.rejected)
            },
            players: players, ownClub: ownClub, asOf: asOf, confirmed: history.map(\.lineup), retraining: [],
            settings: settings.plan)
        let plan: Plan
        do {
            plan = try Planner(catalog: catalog, profile: profile, parameters: parameters).plan(request)
        } catch {
            return .failed([ErrorDescriptions.describe(error)])
        }

        let planned = Dictionary(uniqueKeysWithValues: plan.fixtures.enumerated().map { ($1.fixture, (index: $0, $1)) })
        let result = fixtures.compactMap { fixture -> FixturePlan? in
            if let record = confirmed[fixture.id] {
                return FixturePlan(fixture: fixture, tacticName: record.tacticName, usesPrimaryBecauseItsTacticWasDeleted: false,
                                   body: .confirmed(record), ignoredOverrides: [])
            }
            guard let (index, item) = planned[fixture.id], let stored = tacticOf[fixture.id] else { return nil }
            let projected = Self.fitnessIsProjected(at: index, date: fixture.date, asOf: asOf)
            let ignored = SlotID.allCases.compactMap { slot in
                item.lineup.ignoredOverrides[slot].map {
                    "\(slot.rawValue): " + ErrorDescriptions.describe($0, parameters: parameters, projected: projected)
                }
            }
            let tacticGone = fixture.tacticID.map { id in !tactics.contains { $0.id == id } } ?? false
            return FixturePlan(fixture: fixture, tacticName: stored.tactic.name, usesPrimaryBecauseItsTacticWasDeleted: tacticGone,
                               body: .planned(item.lineup, fitness: item.fitness), ignoredOverrides: ignored)
        }
        return .ready(result)
    }

    /// The day the plan starts from: the latest day a squad was imported.
    var planStartDay: Day? {
        squad.importedOn.values.max()
    }

    /// The engine's parameters, with the owner's condition floor when one is set.
    var planParameters: EngineParameters {
        var parameters = EngineParameters.fm27
        if let floor = settings.conditionFloor {
            parameters.conditionFloor = Parameter(floor, .derived, source: "the owner's setting in the app")
        }
        return parameters
    }

    /// The fixtures in the plan, or none when there is no plan.
    private var fixturePlans: [FixturePlan] {
        if case .ready(let plans) = planState { plans } else { [] }
    }

    /// The planner's rule: fitness is projected once a match has been planned before the fixture, or once a day has
    /// passed since the import. `index` is the fixture's place among the planned fixtures.
    private static func fitnessIsProjected(at index: Int, date: Day, asOf: Day) -> Bool {
        index > 0 || asOf < date
    }

    /// Changes the saved fixture, saves the fixtures and replans; nothing happens if the change leaves it as it was.
    private func changeFixture(_ id: FixtureID, _ change: (inout StoredFixture) -> Void) {
        guard let index = fixtures.firstIndex(where: { $0.id == id }) else { return }
        var fixture = fixtures[index]
        change(&fixture)
        guard fixture != fixtures[index] else { return }
        fixtures[index] = fixture
        save(.fixtures)
        replan()
    }
}
