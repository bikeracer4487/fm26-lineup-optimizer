import Foundation

/// Everything needed to plan the next fixtures.
public struct PlanRequest: Sendable {
    /// Not yet confirmed; any order.
    public var fixtures: [Fixture]
    public var players: [Player]
    public var ownClub: String?
    /// The day the squad was imported.
    public var asOf: Day
    public var confirmed: [ConfirmedLineup]
    public var retraining: [Retraining]
    public var settings: PlanSettings

    public init(fixtures: [Fixture], players: [Player], ownClub: String?, asOf: Day, confirmed: [ConfirmedLineup],
                retraining: [Retraining], settings: PlanSettings) {
        self.fixtures = fixtures; self.players = players; self.ownClub = ownClub; self.asOf = asOf
        self.confirmed = confirmed; self.retraining = retraining; self.settings = settings
    }
}

public struct PlannedFixture: Equatable, Sendable {
    public let fixture: FixtureID
    public let lineup: Lineup
    /// Every player, on that day, before the match.
    public let fitness: [PlayerID: ProjectedFitness]
}

public struct Plan: Equatable, Sendable {
    /// In date order.
    public let fixtures: [PlannedFixture]
}

public enum PlanError: Error, Equatable {
    case fixtureBeforeSnapshot(FixtureID, date: Day, asOf: Day)
    /// The two fixtures in fixture-id order.
    case fixturesOnTheSameDay(FixtureID, FixtureID, Day)
    case badSettings([String])
    /// `FitnessModel.problems(in:)` found these in the engine parameters.
    case badParameters([String])
}

/// Chooses the lineups for the next fixtures in date order, carrying each player's projected fitness and the
/// starts so far from one fixture to the next.
public struct Planner: Sendable {
    private let catalog: RoleCatalog
    private let profile: RatingProfile
    private let parameters: EngineParameters
    private let selector: LineupSelector

    public init(catalog: RoleCatalog, profile: RatingProfile, parameters: EngineParameters) {
        self.catalog = catalog
        self.profile = profile
        self.parameters = parameters
        self.selector = LineupSelector(catalog: catalog, profile: profile, parameters: parameters)
    }

    /// Checks, in order: the settings and the parameters (`PlanError`), two players with one identity
    /// (`DuplicatePlayerError`), then the dates of every fixture given (`PlanError`). Then plans the first
    /// `settings.horizon` fixtures. Throws `TacticError` for an unusable tactic and `RatingError` for a player
    /// with missing data.
    public func plan(_ request: PlanRequest) throws -> Plan {
        let settingsProblems = request.settings.problems()
        guard settingsProblems.isEmpty else { throw PlanError.badSettings(settingsProblems) }
        let parameterProblems = FitnessModel.problems(in: parameters)
        guard parameterProblems.isEmpty else { throw PlanError.badParameters(parameterProblems) }
        try DuplicatePlayerError.check(request.players)
        let ordered = request.fixtures.sorted { ($0.date, $0.id.raw) < ($1.date, $1.id.raw) }
        try Self.checkDates(ordered, asOf: request.asOf)

        let fixtures = Array(ordered.prefix(request.settings.horizon))
        guard let firstDate = fixtures.first?.date else { return Plan(fixtures: []) }

        let players = request.players.sorted { $0.id.key < $1.id.key }
        let settings = request.settings
        let retraining = Self.latestRetraining(request.retraining)
        var history = StartHistory(request.confirmed)
        var fitness: [PlayerID: ProjectedFitness] = [:]
        for player in players {
            fitness[player.id] = try FitnessProjection.afterDays(
                request.asOf.days(to: firstDate), ProjectedFitness(player), player: player,
                intensity: settings.trainingIntensity, parameters: parameters)
        }

        var planned: [PlannedFixture] = []
        for (index, fixture) in fixtures.enumerated() {
            let onTheDay = players.map { Self.withFitness($0, fitness[$0.id]!) }
            let assignments = try fixture.tactic.assignments(catalog: catalog)
            let tiers = try squadTiers(for: fixture, onTheDay, ownClub: request.ownClub)
            let later = try fixtures[(index + 1)...].map {
                LaterFixture(fixture: $0, tiers: try squadTiers(for: $0, onTheDay, ownClub: request.ownClub))
            }
            let context = RuleContext(importance: fixture.importance, date: fixture.date, assignments: assignments,
                                      ownClub: request.ownClub, history: history, tiers: tiers, retraining: retraining,
                                      stability: settings.stability)

            var everySlot: [PlayerID: [Adjustment]] = [:]
            var bySlot: [PlayerID: [SlotID: [Adjustment]]] = [:]
            for player in onTheDay {
                let rules = ImportanceRules.adjustments(for: player, context: context, parameters: parameters)
                var slots = rules.bySlot
                for assignment in assignments {
                    if let saving = try SavingPlayers.adjustment(
                        for: player, fitness: fitness[player.id]!, position: assignment.ipPosition, today: fixture,
                        later: later, settings: settings, parameters: parameters) {
                        slots[assignment.slot, default: []].append(saving)
                    }
                }
                if !rules.everySlot.isEmpty { everySlot[player.id] = rules.everySlot }
                if slots.values.contains(where: { !$0.isEmpty }) { bySlot[player.id] = slots }
            }

            let projected = index > 0 || request.asOf < fixture.date
            let lineup = try selector.select(SelectionRequest(
                tactic: fixture.tactic, players: onTheDay, ownClub: request.ownClub, importance: fixture.importance,
                isNextFixture: index == 0, overrides: fixture.overrides, rejected: fixture.rejected,
                adjustments: everySlot, slotAdjustments: bySlot, fitnessIsProjected: projected))
            planned.append(PlannedFixture(fixture: fixture.id, lineup: lineup, fitness: fitness))

            // A fixture id already confirmed is replaced by this lineup.
            history = history.adding(ConfirmedLineup(
                fixture: fixture.id, date: fixture.date,
                starters: Dictionary(uniqueKeysWithValues: lineup.picks.map { ($0.slot, $0.player) })))

            guard index + 1 < fixtures.count else { break }
            fitness = try projectToNext(fitness, players: players, lineup: lineup, assignments: assignments,
                                        days: fixture.date.days(to: fixtures[index + 1].date), intensity: settings.trainingIntensity)
        }
        return Plan(fixtures: planned)
    }

    /// Starters take a match at their slot's in-possession position; then everyone takes the days to the next fixture.
    private func projectToNext(_ fitness: [PlayerID: ProjectedFitness], players: [Player], lineup: Lineup,
                               assignments: [SlotAssignment], days: Int, intensity: TrainingIntensity) throws
        -> [PlayerID: ProjectedFitness] {
        var positionOf: [PlayerID: Position] = [:]
        for pick in lineup.picks {
            positionOf[pick.player] = assignments.first { $0.slot == pick.slot }?.ipPosition
        }
        var next: [PlayerID: ProjectedFitness] = [:]
        for player in players {
            var current = fitness[player.id]!
            if let position = positionOf[player.id] {
                current = try FitnessProjection.afterMatch(current, player: player, position: position, parameters: parameters)
            }
            next[player.id] = try FitnessProjection.afterDays(days, current, player: player, intensity: intensity,
                                                              parameters: parameters)
        }
        return next
    }

    /// The first and second elevens for one fixture's tactic. They ignore fitness, so any day's copies give the same tiers.
    private func squadTiers(for fixture: Fixture, _ players: [Player], ownClub: String?) throws -> SquadTiers {
        try SquadTiers.compute(tactic: fixture.tactic, players: players, ownClub: ownClub, catalog: catalog,
                               profile: profile, parameters: parameters)
    }

    /// The player as the selector sees him on the day: projected condition and sharpness, jadedness to the nearest whole number.
    /// Injuries carry through unchanged: FMRTE gives no return date.
    private static func withFitness(_ player: Player, _ fitness: ProjectedFitness) -> Player {
        var copy = player
        copy.condition = fitness.condition
        copy.sharpness = fitness.sharpness
        copy.jadedness = Int(fitness.jadedness.rounded())
        return copy
    }

    /// One entry per player and position, the latest accepted, ordered by player key then position.
    private static func latestRetraining(_ entries: [Retraining]) -> [Retraining] {
        var latest: [PlayerID: [Position: Retraining]] = [:]
        for entry in entries {
            if let held = latest[entry.player]?[entry.position], held.acceptedOn >= entry.acceptedOn { continue }
            latest[entry.player, default: [:]][entry.position] = entry
        }
        return latest.values.flatMap(\.values)
            .sorted { ($0.player.key, $0.position.rawValue) < ($1.player.key, $1.position.rawValue) }
    }

    /// `fixtures` in date then id order. The first problem in that order is reported: a fixture before the
    /// snapshot, or a fixture on the same day as the one after it.
    private static func checkDates(_ fixtures: [Fixture], asOf: Day) throws {
        for (index, fixture) in fixtures.enumerated() {
            if fixture.date < asOf {
                throw PlanError.fixtureBeforeSnapshot(fixture.id, date: fixture.date, asOf: asOf)
            }
            if index + 1 < fixtures.count, fixtures[index + 1].date == fixture.date {
                throw PlanError.fixturesOnTheSameDay(fixture.id, fixtures[index + 1].id, fixture.date)
            }
        }
    }
}
