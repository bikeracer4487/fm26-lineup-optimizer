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
    /// Matches whose load the imported fitness does not include; any order. Each one's starters take a match in the
    /// projection on its date. One dated before `asOf` is taken from the imported figures, as for starters whose squad
    /// was last imported before it: they take the match, then the days from it to `asOf` as rest days at the plan's
    /// training intensity, and nobody else is moved by those days. They do not count as starts: a played match that
    /// should count towards runs of starts belongs in `confirmed` too.
    public var played: [ConfirmedLineup]
    public var retraining: [Retraining]
    public var settings: PlanSettings

    public init(fixtures: [Fixture], players: [Player], ownClub: String?, asOf: Day, confirmed: [ConfirmedLineup],
                played: [ConfirmedLineup] = [], retraining: [Retraining], settings: PlanSettings) {
        self.fixtures = fixtures; self.players = players; self.ownClub = ownClub; self.asOf = asOf
        self.confirmed = confirmed; self.played = played; self.retraining = retraining; self.settings = settings
    }
}

public struct PlannedFixture: Equatable, Sendable {
    public let fixture: FixtureID
    public let lineup: Lineup
    /// Every player, on that day, before the match.
    public let fitness: [PlayerID: ProjectedFitness]
    /// What the selector was told: true once a day has passed since the import or a match, played or planned, comes
    /// before this fixture; false when the fitness is the imported figures.
    public let fitnessIsProjected: Bool
}

public struct Plan: Equatable, Sendable {
    /// In date order.
    public let fixtures: [PlannedFixture]
}

public enum PlanError: Error, Equatable {
    case fixtureBeforeSnapshot(FixtureID, date: Day, asOf: Day)
    /// The two fixtures in fixture-id order.
    case fixturesOnTheSameDay(FixtureID, FixtureID, Day)
    /// Two fixtures to plan, two confirmed lineups, two played matches, or a fixture to plan and a played match share this
    /// id (the lowest such id).
    case duplicateFixtureID(FixtureID)
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
    /// (`DuplicatePlayerError`), then a fixture id repeated among the fixtures, among the confirmed lineups, among the
    /// played matches or between the fixtures and the played matches, and the dates of every fixture given (`PlanError`). A fixture to plan may share its id with one
    /// confirmed lineup, which its planned lineup then replaces. Then plans the first `settings.horizon` fixtures, with
    /// the played matches in the fitness projection. Throws `TacticError` for an unusable tactic and `RatingError` for a player
    /// with missing data.
    public func plan(_ request: PlanRequest) throws -> Plan {
        let settingsProblems = request.settings.problems()
        guard settingsProblems.isEmpty else { throw PlanError.badSettings(settingsProblems) }
        let parameterProblems = FitnessModel.problems(in: parameters)
        guard parameterProblems.isEmpty else { throw PlanError.badParameters(parameterProblems) }
        try DuplicatePlayerError.check(request.players)
        try Self.checkUnique(request.fixtures.map(\.id))
        try Self.checkUnique(request.confirmed.map(\.fixture))
        try Self.checkUnique(request.played.map(\.fixture))
        // A match both to plan and played would be counted twice.
        try Self.checkUnique(request.fixtures.map(\.id) + request.played.map(\.fixture))
        let ordered = request.fixtures.sorted { ($0.date, $0.id.raw) < ($1.date, $1.id.raw) }
        try Self.checkDates(ordered, asOf: request.asOf)

        let fixtures = Array(ordered.prefix(request.settings.horizon))
        guard !fixtures.isEmpty else { return Plan(fixtures: []) }

        let players = request.players.sorted { $0.id.key < $1.id.key }
        let assignmentsByFixture = try fixtures.map { try $0.tactic.assignments(catalog: catalog) }
        // Tiers ignore fitness, and injury and loan status do not change during a plan, so each is computed once.
        let tiersByFixture = try fixtures.map { try squadTiers(for: $0, players, ownClub: request.ownClub) }
        let settings = request.settings
        let retraining = Self.latestRetraining(request.retraining)
        var history = StartHistory(request.confirmed)
        let known = Set(players.map(\.id))
        let (imported, anyEarlyMatch) = try afterEarlyMatches(
            request.played.filter { $0.date < request.asOf }, players: players, known: known, asOf: request.asOf,
            intensity: settings.trainingIntensity)
        var fitness = imported
        var projectedTo = request.asOf
        var anyMatchSoFar = anyEarlyMatch

        // Played matches and planned fixtures in one walk, so both take the days between them alike.
        var planned: [PlannedFixture] = []
        for event in Self.events(fixtures, played: request.played, asOf: request.asOf) {
            fitness = try advance(fitness, players: players, days: projectedTo.days(to: event.date),
                                  intensity: settings.trainingIntensity)
            projectedTo = event.date
            let index: Int
            switch event {
            case .played(let match):
                let positionOf = Self.positions(in: match, known: known)
                if !positionOf.isEmpty {
                    fitness = try afterMatch(fitness, players: players, positionOf: positionOf)
                    anyMatchSoFar = true
                }
                continue
            case .fixture(let position, _):
                index = position
            }
            let fixture = fixtures[index]
            let onTheDay = players.map { Self.withFitness($0, fitness[$0.id]!) }
            let assignments = assignmentsByFixture[index]
            let later = fixtures.indices.dropFirst(index + 1).map {
                LaterFixture(fixture: fixtures[$0], tiers: tiersByFixture[$0])
            }
            let context = RuleContext(importance: fixture.importance, date: fixture.date, assignments: assignments,
                                      ownClub: request.ownClub, history: history, tiers: tiersByFixture[index], retraining: retraining,
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

            let projected = anyMatchSoFar || request.asOf < fixture.date
            let lineup = try selector.select(SelectionRequest(
                tactic: fixture.tactic, players: onTheDay, ownClub: request.ownClub, importance: fixture.importance,
                isNextFixture: index == 0, overrides: fixture.overrides, rejected: fixture.rejected,
                adjustments: everySlot, slotAdjustments: bySlot, fitnessIsProjected: projected))
            planned.append(PlannedFixture(fixture: fixture.id, lineup: lineup, fitness: fitness, fitnessIsProjected: projected))

            // A fixture id already confirmed is replaced by this lineup.
            history = history.adding(ConfirmedLineup(
                fixture: fixture.id, date: fixture.date,
                starters: Dictionary(uniqueKeysWithValues: lineup.picks.map { ($0.slot, $0.player) })))

            guard index + 1 < fixtures.count else { break }
            // Starters take the match at their slot's in-possession position.
            let assignmentOf = Dictionary(uniqueKeysWithValues: assignments.map { ($0.slot, $0) })
            var positionOf: [PlayerID: Position] = [:]
            for pick in lineup.picks {
                guard let assignment = assignmentOf[pick.slot] else {
                    preconditionFailure("A pick at \(pick.slot.rawValue) is not in the fixture's tactic; the selector only picks for the tactic's slots")
                }
                positionOf[pick.player] = assignment.ipPosition
            }
            fitness = try afterMatch(fitness, players: players, positionOf: positionOf)
            anyMatchSoFar = true
        }
        return Plan(fixtures: planned)
    }

    /// Something that moves fitness on a day: a fixture to plan, by its index in the planned fixtures, or a match played
    /// since the import.
    private enum Event {
        case fixture(Int, Day)
        case played(ConfirmedLineup)

        var date: Day {
            switch self {
            case .fixture(_, let day): day
            case .played(let match): match.date
            }
        }
    }

    /// The fixtures and the played matches from `asOf` on, in date order, a played match before a fixture on the same day
    /// and played matches on one day in id order. Those before `asOf` are left to `afterEarlyMatches`, and those after the
    /// last fixture are left out, since nothing is planned after them.
    private static func events(_ fixtures: [Fixture], played: [ConfirmedLineup], asOf: Day) -> [Event] {
        guard let last = fixtures.last?.date else { return [] }
        let matches = played
            .filter { asOf <= $0.date && $0.date <= last }
            .sorted { ($0.date, $0.fixture.raw) < ($1.date, $1.fixture.raw) }
            .map(Event.played)
        let planned = fixtures.indices.map { Event.fixture($0, fixtures[$0].date) }
        var merged: [Event] = []
        var next = 0
        for match in matches {
            while next < planned.count, planned[next].date < match.date {
                merged.append(planned[next]); next += 1
            }
            merged.append(match)
        }
        return merged + planned[next...]
    }

    /// The imported figures, with the matches played before `asOf` taken by their starters: in date then id order, each
    /// starter takes the days since his previous such match, then the match; then the days from his last such match to
    /// `asOf`. Nobody else moves. Also whether any match moved anyone.
    private func afterEarlyMatches(_ matches: [ConfirmedLineup], players: [Player], known: Set<PlayerID>, asOf: Day,
                                   intensity: TrainingIntensity) throws -> ([PlayerID: ProjectedFitness], Bool) {
        var fitness = Dictionary(uniqueKeysWithValues: players.map { ($0.id, ProjectedFitness($0)) })
        var lastMatch: [PlayerID: Day] = [:]
        for match in matches.sorted(by: { ($0.date, $0.fixture.raw) < ($1.date, $1.fixture.raw) }) {
            let positionOf = Self.positions(in: match, known: known)
            for player in players {
                guard let position = positionOf[player.id] else { continue }
                var current = fitness[player.id]!
                if let since = lastMatch[player.id] {
                    current = try FitnessProjection.afterDays(since.days(to: match.date), current, player: player,
                                                              intensity: intensity, parameters: parameters)
                }
                fitness[player.id] = try FitnessProjection.afterMatch(current, player: player, position: position,
                                                                      parameters: parameters)
                lastMatch[player.id] = match.date
            }
        }
        for player in players {
            guard let since = lastMatch[player.id] else { continue }
            fitness[player.id] = try FitnessProjection.afterDays(since.days(to: asOf), fitness[player.id]!, player: player,
                                                                 intensity: intensity, parameters: parameters)
        }
        return (fitness, !lastMatch.isEmpty)
    }

    /// Where each starter of a played match takes it: his slot's position, the lowest slot in `SlotID` order for a player
    /// named twice. A starter not in the squad is left out, so a match with none left moves nothing.
    private static func positions(in match: ConfirmedLineup, known: Set<PlayerID>) -> [PlayerID: Position] {
        var positionOf: [PlayerID: Position] = [:]
        for slot in SlotID.allCases {
            guard let player = match.starters[slot], known.contains(player), positionOf[player] == nil else { continue }
            positionOf[player] = slot.position
        }
        return positionOf
    }

    /// Everyone takes `days` nights without a match.
    private func advance(_ fitness: [PlayerID: ProjectedFitness], players: [Player], days: Int,
                         intensity: TrainingIntensity) throws -> [PlayerID: ProjectedFitness] {
        guard days > 0 else { return fitness }
        var next = fitness
        for player in players {
            next[player.id] = try FitnessProjection.afterDays(days, fitness[player.id]!, player: player, intensity: intensity,
                                                              parameters: parameters)
        }
        return next
    }

    /// Each player in `positionOf` takes a match at his position; everyone else is unchanged.
    private func afterMatch(_ fitness: [PlayerID: ProjectedFitness], players: [Player],
                            positionOf: [PlayerID: Position]) throws -> [PlayerID: ProjectedFitness] {
        var next = fitness
        for player in players {
            guard let position = positionOf[player.id] else { continue }
            next[player.id] = try FitnessProjection.afterMatch(fitness[player.id]!, player: player, position: position,
                                                               parameters: parameters)
        }
        return next
    }

    /// The first and second elevens for one fixture's tactic.
    private func squadTiers(for fixture: Fixture, _ players: [Player], ownClub: String?) throws -> SquadTiers {
        try SquadTiers.compute(tactic: fixture.tactic, players: players, ownClub: ownClub, catalog: catalog,
                               profile: profile, parameters: parameters)
    }

    /// The player as the selector sees him on the day: projected condition and sharpness, jadedness to the nearest whole number.
    /// Injuries carry through unchanged: FMRTE gives no return date.
    public static func withFitness(_ player: Player, _ fitness: ProjectedFitness) -> Player {
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

    /// Throws `duplicateFixtureID` for the lowest id that appears more than once.
    private static func checkUnique(_ ids: [FixtureID]) throws {
        var seen = Set<String>()
        let repeated = ids.map(\.raw).filter { !seen.insert($0).inserted }
        if let lowest = repeated.min() { throw PlanError.duplicateFixtureID(FixtureID(lowest)) }
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
