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

/// A match to plan for, as saved. The tactic is referred to by id; nil means the primary tactic.
public struct StoredFixture: Identifiable, Equatable, Codable, Sendable {
    public var id: FixtureID
    public var date: Day
    public var opponent: String
    public var importance: Importance
    public var tacticID: UUID?
    public var overrides: [SlotID: PlayerID]
    public var rejected: Set<PlayerID>

    public init(
        id: FixtureID, date: Day, opponent: String, importance: Importance, tacticID: UUID? = nil,
        overrides: [SlotID: PlayerID] = [:], rejected: Set<PlayerID> = []
    ) {
        self.id = id; self.date = date; self.opponent = opponent; self.importance = importance
        self.tacticID = tacticID; self.overrides = overrides; self.rejected = rejected
    }
}

/// A lineup the owner confirmed, with the names and tactic as they were at the time.
public struct ConfirmedRecord: Equatable, Codable, Sendable {
    public var lineup: ConfirmedLineup
    public var names: [PlayerID: String]
    public var tacticName: String

    public init(lineup: ConfirmedLineup, names: [PlayerID: String], tacticName: String) {
        self.lineup = lineup; self.names = names; self.tacticName = tacticName
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
