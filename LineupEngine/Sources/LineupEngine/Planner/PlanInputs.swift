public struct FixtureID: Hashable, Codable, Sendable {
    public let raw: String
    public init(_ raw: String) { self.raw = raw }

    public init(from decoder: any Decoder) throws {
        raw = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
}

/// One match to plan for. Not `Codable`: it embeds an already resolved tactic.
public struct Fixture: Equatable, Sendable {
    public var id: FixtureID
    public var date: Day
    public var opponent: String
    public var importance: Importance
    /// Already resolved; choosing the primary tactic when none is set is the app's job.
    public var tactic: Tactic
    public var overrides: [SlotID: PlayerID]
    public var rejected: Set<PlayerID>

    public init(
        id: FixtureID, date: Day, opponent: String, importance: Importance, tactic: Tactic,
        overrides: [SlotID: PlayerID] = [:], rejected: Set<PlayerID> = []
    ) {
        self.id = id; self.date = date; self.opponent = opponent
        self.importance = importance; self.tactic = tactic
        self.overrides = overrides; self.rejected = rejected
    }
}

/// The starters the manager confirmed for a played fixture.
public struct ConfirmedLineup: Equatable, Codable, Sendable {
    public var fixture: FixtureID
    public var date: Day
    public var starters: [SlotID: PlayerID]

    public init(fixture: FixtureID, date: Day, starters: [SlotID: PlayerID]) {
        self.fixture = fixture; self.date = date; self.starters = starters
    }
}

/// A position change the manager accepted for a player.
public struct Retraining: Equatable, Codable, Sendable {
    public var player: PlayerID
    public var position: Position
    public var acceptedOn: Day

    public init(player: PlayerID, position: Position, acceptedOn: Day) {
        self.player = player; self.position = position; self.acceptedOn = acceptedOn
    }
}

public enum TrainingIntensity: String, Codable, CaseIterable, Sendable { case low, medium, high }

public struct PlanSettings: Equatable, Codable, Sendable {
    public var trainingIntensity: TrainingIntensity
    /// 0...1: how strongly the plan prefers repeating the previous lineup.
    public var stability: Double
    /// 0 turns saving players for later fixtures off.
    public var savingPlayers: Double
    /// How many fixtures ahead to plan.
    public var horizon: Int

    public init(
        trainingIntensity: TrainingIntensity = .medium, stability: Double = 0.5,
        savingPlayers: Double = 1, horizon: Int = 5
    ) {
        self.trainingIntensity = trainingIntensity; self.stability = stability
        self.savingPlayers = savingPlayers; self.horizon = horizon
    }

    public static let standard = PlanSettings()

    /// One plain-words sentence per setting that is out of range.
    public func problems() -> [String] {
        var found: [String] = []
        // A closed range never contains NaN or infinity, so this also requires a finite number.
        if !(0...1).contains(stability) {
            found.append("Stability must be between 0 and 1, but is \(stability)")
        }
        // At most 10 keeps every saving cost far below the selector's solver limit. NaN and infinity fail both checks.
        if !(0...10).contains(savingPlayers) {
            found.append("Saving players must be between 0 and 10, but is \(savingPlayers)")
        }
        if horizon < 1 {
            found.append("Horizon must be at least 1 fixture, but is \(horizon)")
        }
        return found
    }
}
