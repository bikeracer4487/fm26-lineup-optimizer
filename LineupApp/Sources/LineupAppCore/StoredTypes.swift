import Foundation
import LineupEngine

/// A tactic the owner has imported, with a stable identity the fixtures refer to.
public struct StoredTactic: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var tactic: Tactic

    public init(id: UUID, tactic: Tactic) {
        self.id = id; self.tactic = tactic
    }
}

/// An eleven as it was last planned for a fixture, or as it was confirmed before being unlocked: the starters by
/// slot, their names then, and the tactic's name. Kept so a match that was played but never confirmed can be put right.
public struct PlannedEleven: Equatable, Codable, Sendable {
    public var starters: [SlotID: PlayerID]
    public var names: [PlayerID: String]
    public var tacticName: String

    public init(starters: [SlotID: PlayerID], names: [PlayerID: String], tacticName: String) {
        self.starters = starters; self.names = names; self.tacticName = tacticName
    }
}

/// A match to plan for, as saved. The tactic is referred to by id; nil means the primary tactic.
public struct StoredFixture: Identifiable, Equatable, Codable, Sendable {
    public var id: FixtureID
    public var date: Day
    public var opponent: String
    public var importance: Importance
    public var tacticID: UUID?
    public var overrides: [SlotID: PlayerID]
    public var rejected: Set<PlayerID>
    /// The eleven last planned for it; nil until it has been planned.
    public var lastPlanned: PlannedEleven?
    /// The kind of competition; nil until the owner says.
    public var competition: Competition?
    /// How strong the opponent is compared with the club; nil until the owner says.
    public var opponentStrength: OpponentStrength?

    public init(
        id: FixtureID, date: Day, opponent: String, importance: Importance, tacticID: UUID? = nil,
        overrides: [SlotID: PlayerID] = [:], rejected: Set<PlayerID> = [], lastPlanned: PlannedEleven? = nil,
        competition: Competition? = nil, opponentStrength: OpponentStrength? = nil
    ) {
        self.id = id; self.date = date; self.opponent = opponent; self.importance = importance
        self.tacticID = tacticID; self.overrides = overrides; self.rejected = rejected; self.lastPlanned = lastPlanned
        self.competition = competition; self.opponentStrength = opponentStrength
    }

    private enum CodingKeys: String, CodingKey {
        case id, date, opponent, importance, tacticID, overrides, rejected, lastPlanned, competition, opponentStrength
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(FixtureID.self, forKey: .id)
        date = try c.decode(Day.self, forKey: .date)
        opponent = try c.decode(String.self, forKey: .opponent)
        importance = try c.decode(Importance.self, forKey: .importance)
        tacticID = try c.decodeIfPresent(UUID.self, forKey: .tacticID)
        overrides = try c.decode([SlotID: PlayerID].self, forKey: .overrides)
        rejected = Set(try c.decode([PlayerID].self, forKey: .rejected))
        // A fixture saved before elevens were remembered has none.
        lastPlanned = try c.decodeIfPresent(PlannedEleven.self, forKey: .lastPlanned)
        // A fixture saved before competitions were kept has neither.
        competition = try c.decodeIfPresent(Competition.self, forKey: .competition)
        opponentStrength = try c.decodeIfPresent(OpponentStrength.self, forKey: .opponentStrength)
    }

    /// `rejected` is written as an array in key order, because a set has no fixed order of its own.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(date, forKey: .date)
        try c.encode(opponent, forKey: .opponent)
        try c.encode(importance, forKey: .importance)
        try c.encodeIfPresent(tacticID, forKey: .tacticID)
        try c.encode(overrides, forKey: .overrides)
        try c.encode(rejected.sorted { $0.key < $1.key }, forKey: .rejected)
        try c.encodeIfPresent(lastPlanned, forKey: .lastPlanned)
        try c.encodeIfPresent(competition, forKey: .competition)
        try c.encodeIfPresent(opponentStrength, forKey: .opponentStrength)
    }
}

/// A lineup the owner confirmed, with the names and tactic as they were at the time.
public struct ConfirmedRecord: Equatable, Codable, Sendable {
    public var lineup: ConfirmedLineup
    public var names: [PlayerID: String]
    public var tacticName: String
    /// The squads not imported since this lineup was confirmed: their imported fitness does not include the match.
    public var awaitingImport: Set<Squad>

    public init(lineup: ConfirmedLineup, names: [PlayerID: String], tacticName: String, awaitingImport: Set<Squad> = []) {
        self.lineup = lineup; self.names = names; self.tacticName = tacticName; self.awaitingImport = awaitingImport
    }

    private enum CodingKeys: String, CodingKey {
        case lineup, names, tacticName, awaitingImport
    }

    /// A record saved before `awaitingImport` existed has nothing awaited.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lineup = try c.decode(ConfirmedLineup.self, forKey: .lineup)
        names = try c.decode([PlayerID: String].self, forKey: .names)
        tacticName = try c.decode(String.self, forKey: .tacticName)
        awaitingImport = Set(try c.decodeIfPresent([Squad].self, forKey: .awaitingImport) ?? [])
    }

    /// `awaitingImport` is written as an array in raw-value order, because a set has no fixed order of its own.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(lineup, forKey: .lineup)
        try c.encode(names, forKey: .names)
        try c.encode(tacticName, forKey: .tacticName)
        try c.encode(awaitingImport.sorted { $0.rawValue < $1.rawValue }, forKey: .awaitingImport)
    }
}

public struct AppSettings: Equatable, Codable, Sendable {
    public var currentDate: Day
    public var plan: PlanSettings
    /// Overrides the club worked out from the squad.
    public var clubName: String?
    public var primaryTacticID: UUID?
    /// Nil: the engine's value.
    public var conditionFloor: Double?
    /// Nil: FMRTE's usual location under Application Support.
    public var fmrteConfigPath: String?

    public init(currentDate: Day) {
        self.currentDate = currentDate
        self.plan = .standard
        self.clubName = nil
        self.primaryTacticID = nil
        self.conditionFloor = nil
        self.fmrteConfigPath = nil
    }
}

public struct SquadState: Equatable, Codable, Sendable {
    public var book: SquadBook
    public var importedOn: [Squad: Day]

    public init() {
        self.book = SquadBook()
        self.importedOn = [:]
    }
}

/// The position retrainings the owner has accepted or turned down, and how each accepted one is going.
public struct TrainingState: Equatable, Codable, Sendable {
    /// In `order`; the model keeps at most one per player, since a player learns one position at a time.
    public var accepted: [Retraining]
    public var rejected: Set<RetrainingChoice>
    /// For each accepted retraining, the player's familiarity at the position, one a day, in day order.
    public var observations: [RetrainingChoice: [FamiliarityObservation]]
    /// Each player's name as it was when a retraining of his was last accepted or turned down.
    public var names: [PlayerID: String]

    /// `accepted` is kept in `order`, as decoding keeps it, so a state equals its own round trip.
    public init(accepted: [Retraining] = [], rejected: Set<RetrainingChoice> = [],
                observations: [RetrainingChoice: [FamiliarityObservation]] = [:], names: [PlayerID: String] = [:]) {
        self.accepted = accepted.sorted { Self.order(Self.choice($0), Self.choice($1)) }
        self.rejected = rejected; self.observations = observations; self.names = names
    }

    /// By the player's key, then by the position's place in `Position.allCases`.
    static func order(_ a: RetrainingChoice, _ b: RetrainingChoice) -> Bool {
        (a.player.key, place(a.position)) < (b.player.key, place(b.position))
    }

    private static func place(_ position: Position) -> Int {
        Position.allCases.firstIndex(of: position) ?? Position.allCases.count
    }

    static func choice(_ retraining: Retraining) -> RetrainingChoice {
        RetrainingChoice(player: retraining.player, position: retraining.position)
    }

    /// Records the familiarity for an accepted pair on the day: a second one that day replaces the first, and none is
    /// recorded before the day the pair was accepted or for a pair that is not accepted.
    mutating func record(_ familiarity: Int, for choice: RetrainingChoice, on day: Day) {
        guard let retraining = accepted.first(where: { Self.choice($0) == choice }), day >= retraining.acceptedOn else {
            return
        }
        var list = observations[choice, default: []].filter { $0.day != day }
        list.append(FamiliarityObservation(day: day, familiarity: familiarity))
        list.sort { $0.day < $1.day }
        observations[choice] = list
    }

    /// Keeps a name only for a player in an accepted or rejected pair.
    mutating func forgetUnusedNames() {
        let held = Set(accepted.map(\.player)).union(rejected.map(\.player))
        names = names.filter { held.contains($0.key) }
    }

    /// One pair's observations, as saved.
    private struct Observed: Codable {
        var choice: RetrainingChoice
        var observations: [FamiliarityObservation]
    }

    private enum CodingKeys: String, CodingKey {
        case accepted, rejected, observations, names
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accepted = try c.decode([Retraining].self, forKey: .accepted).sorted { Self.order(Self.choice($0), Self.choice($1)) }
        rejected = Set(try c.decode([RetrainingChoice].self, forKey: .rejected))
        let observed = try c.decode([Observed].self, forKey: .observations)
        observations = Dictionary(observed.map { ($0.choice, $0.observations) }, uniquingKeysWith: { first, _ in first })
        names = try c.decode([PlayerID: String].self, forKey: .names)
    }

    /// Every list is written in `order`, because neither a set nor a dictionary keyed by pairs has a fixed order.
    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(accepted.sorted { Self.order(Self.choice($0), Self.choice($1)) }, forKey: .accepted)
        try c.encode(rejected.sorted(by: Self.order), forKey: .rejected)
        let observed = observations.sorted { Self.order($0.key, $1.key) }
            .map { Observed(choice: $0.key, observations: $0.value) }
        try c.encode(observed, forKey: .observations)
        try c.encode(names, forKey: .names)
    }
}
