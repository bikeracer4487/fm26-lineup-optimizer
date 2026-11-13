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

    /// Whether `confirm` would record the fixture: it is the earliest fixture with a planned lineup, since confirming
    /// says the match has been played and matches are played in order.
    public func canConfirm(_ fixture: FixtureID) -> Bool {
        nextToPlay?.id == fixture
    }

    /// Why a planned fixture cannot be confirmed yet; nil when it can be, or when it has no planned lineup.
    public func whyNotConfirm(_ fixture: FixtureID) -> String? {
        guard let plan = fixturePlans.first(where: { $0.id == fixture }), case .planned = plan.body,
              let next = nextToPlay, next.id != fixture else { return nil }
        return "Confirm the earlier match against \(next.fixture.opponent) first."
    }

    /// Records the fixture's planned lineup as played: the starters by slot, their names as the squad has them now,
    /// and the tactic's name. Nothing happens unless `canConfirm` allows it.
    public func confirm(_ fixture: FixtureID) {
        guard canConfirm(fixture), let plan = nextToPlay, case .planned(let lineup, _) = plan.body else { return }
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
    /// for that day, worded as the selector words it. A player who cannot be rated comes last, with the engine's
    /// sentence for why. Empty when the fixture has no planned lineup or its tactic has no such slot.
    public func candidates(for slot: SlotID, in fixture: FixtureID) -> [Candidate] {
        let planned = fixturePlans.compactMap { plan -> (FixturePlan, [PlayerID: ProjectedFitness])? in
            if case .planned(_, let fitness) = plan.body { (plan, fitness) } else { nil }
        }
        guard let index = planned.firstIndex(where: { $0.0.id == fixture }), let asOf = planStartDay,
              let tactic = tactic(for: planned[index].0.fixture)?.tactic else { return [] }
        let assignments: [SlotAssignment]
        do {
            assignments = try tactic.assignments(catalog: catalog)
        } catch {
            return []   // not reached: the fixture was just planned with this tactic
        }
        guard let assignment = assignments.first(where: { $0.slot == slot }) else { return [] }
        let (plan, fitness) = planned[index]
        let parameters = planParameters
        let projected = Self.fitnessIsProjected(at: index, date: plan.fixture.date, asOf: asOf)
        let club = ownClub
        let players = squad.book.allPlayers.filter {
            if case .loanedOut = LoanStatus.of($0, ownClub: club) { false } else { true }
        }
        let engine = RatingEngine(profile: profile, parameters: parameters, configuration: .fm27)
        return Self.ranked(players, rating: { try engine.rating(for: $0, in: assignment).value }) { player in
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
            return exclusion.map { ErrorDescriptions.describe($0, parameters: parameters, projected: projected) }
        }
    }

    /// The players as candidates: those rated best first (then by name and key), then those who cannot be rated, by
    /// name and key, with the engine's sentence for the failure in place of any other reason.
    static func ranked(_ players: [Player], rating: (Player) throws -> Double,
                       unavailable: (Player) -> String?) -> [Candidate] {
        var rated: [Candidate] = []
        var unrated: [Candidate] = []
        for player in players {
            do {
                rated.append(Candidate(player: player.id, name: player.name, squad: player.squad,
                                       rating: try rating(player), unavailable: unavailable(player)))
            } catch {
                unrated.append(Candidate(player: player.id, name: player.name, squad: player.squad,
                                         rating: nil, unavailable: ErrorDescriptions.describe(error)))
            }
        }
        let best = rated.sorted { ($1.rating ?? 0, $0.name, $0.player.key) < ($0.rating ?? 0, $1.name, $1.player.key) }
        return best + unrated.sorted { ($0.name, $0.player.key) < ($1.name, $1.player.key) }
    }

    // MARK: Working the plan out

    /// The plan for the saved state. Missing things come first, in the order Match Selection asks for them: a squad,
    /// a usable tactic for every fixture within the horizon, then fixtures. Then two fixtures to plan on one day, then
    /// the planner. Unconfirmed fixtures before the plan's starting day are not planned: they are shown as missed.
    func workedOutPlan() -> PlanState {
        let players = squad.book.allPlayers
        guard !players.isEmpty, let asOf = planStartDay else { return .needsSquad }
        if tactics.isEmpty { return .needsTactic([]) }
        let confirmed = Dictionary(history.map { ($0.lineup.fixture, $0) }, uniquingKeysWith: { first, _ in first })
        let toPlan = fixtures.filter { confirmed[$0.id] == nil && $0.date >= asOf }
        // `fixtures` is in the planner's order, date then id, so these are the fixtures it plans.
        let withinReach = Array(toPlan.prefix(max(0, settings.plan.horizon)))
        let tacticProblems = unusableTactics(withinReach)
        if !tacticProblems.isEmpty { return .needsTactic(tacticProblems) }
        if fixtures.isEmpty { return .needsFixtures }
        if let clash = Self.sameDayProblem(toPlan) { return .failed([clash]) }

        let parameters = planParameters
        let request = PlanRequest(
            fixtures: withinReach.map { fixture in
                Fixture(id: fixture.id, date: fixture.date, opponent: fixture.opponent, importance: fixture.importance,
                        tactic: tactic(for: fixture)!.tactic, overrides: fixture.overrides, rejected: fixture.rejected)
            },
            players: players, ownClub: ownClub, asOf: asOf, confirmed: history.map(\.lineup), retraining: [],
            settings: settings.plan)
        let plan: Plan
        do {
            plan = try Planner(catalog: catalog, profile: profile, parameters: parameters).plan(request)
        } catch {
            return .failed([ErrorDescriptions.describe(error)])
        }

        let names = Dictionary(players.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let planned = Dictionary(uniqueKeysWithValues: plan.fixtures.enumerated().map { ($1.fixture, (index: $0, $1)) })
        let result = fixtures.compactMap { fixture -> FixturePlan? in
            if let record = confirmed[fixture.id] {
                return FixturePlan(fixture: fixture, tacticName: record.tacticName, usesPrimaryBecauseItsTacticWasDeleted: false,
                                   body: .confirmed(record), ignoredOverrides: [])
            }
            let tacticName = tactic(for: fixture)?.tactic.name ?? ""
            let tacticGone = fixture.tacticID.map { id in !tactics.contains { $0.id == id } } ?? false
            if fixture.date < asOf {
                return FixturePlan(fixture: fixture, tacticName: tacticName, usesPrimaryBecauseItsTacticWasDeleted: tacticGone,
                                   body: .missed, ignoredOverrides: [])
            }
            guard let (index, item) = planned[fixture.id] else { return nil }
            let projected = Self.fitnessIsProjected(at: index, date: fixture.date, asOf: asOf)
            let ignored = SlotID.allCases.compactMap { slot in
                item.lineup.ignoredOverrides[slot].map { problem in
                    if let chosen = fixture.overrides[slot], let name = names[chosen] {
                        "\(name) at \(slot.displayName): "
                            + ErrorDescriptions.describe(problem, parameters: parameters, projected: projected) + "."
                    } else {
                        "The player chosen for \(slot.displayName) is no longer in the squad."
                    }
                }
            }
            return FixturePlan(fixture: fixture, tacticName: tacticName, usesPrimaryBecauseItsTacticWasDeleted: tacticGone,
                               body: .planned(item.lineup, fitness: item.fitness), ignoredOverrides: ignored)
        }
        return .ready(result)
    }

    /// One sentence per tactic the fixtures would be planned with that cannot be used, in the order the fixtures
    /// first use them.
    private func unusableTactics(_ fixtures: [StoredFixture]) -> [String] {
        var found: [String] = []
        var seen = Set<UUID>()
        for fixture in fixtures {
            guard let stored = tactic(for: fixture) else {
                let sentence = "No tactic is the primary one. Make one primary on the Tactics screen."
                if !found.contains(sentence) { found.append(sentence) }
                continue
            }
            guard seen.insert(stored.id).inserted else { continue }
            let problems = problems(of: stored.tactic)
            if !problems.isEmpty {
                found.append("\(stored.tactic.name) cannot be used: \(problems.joined(separator: "; ")).")
            }
        }
        return found
    }

    /// The earliest day with more than one of the fixtures, in words, its opponents in alphabetical order; nil when every
    /// fixture has a day of its own.
    /// The app says this itself because the engine's sentence names the fixtures by their ids.
    static func sameDayProblem(_ fixtures: [StoredFixture]) -> String? {
        let byDay = Dictionary(grouping: fixtures, by: \.date)
        guard let day = byDay.filter({ $0.value.count > 1 }).keys.min(), let matches = byDay[day] else { return nil }
        let counts = [2: "Two", 3: "Three", 4: "Four", 5: "Five"]
        let against = matches.sorted { ($0.opponent, $0.id.raw) < ($1.opponent, $1.id.raw) }.map { "against \($0.opponent)" }
        let listed = against.dropLast().joined(separator: ", ") + " and " + against.last!
        return "\(counts[matches.count] ?? "\(matches.count)") matches are on \(DayText.short(day)): \(listed). "
            + "A club plays one match a day: change one of the dates on the Fixtures screen."
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

    /// The earliest fixture with a planned lineup.
    private var nextToPlay: FixturePlan? {
        fixturePlans.first { if case .planned = $0.body { true } else { false } }
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
