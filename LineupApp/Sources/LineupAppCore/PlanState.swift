import Foundation
import LineupEngine

/// One saved fixture in the plan: its confirmed lineup, or the lineup the planner chose.
public struct FixturePlan: Identifiable, Equatable, Sendable {
    public var id: FixtureID { fixture.id }
    public let fixture: StoredFixture
    /// The tactic planned with, or for a confirmed lineup the one it was confirmed with.
    public let tacticName: String
    /// The fixture names a tactic that is no longer saved, so it was planned with the primary.
    public let usesPrimaryBecauseItsTacticWasDeleted: Bool

    public enum Body: Equatable, Sendable {
        /// The planner's lineup and every player's projected fitness on the day.
        case planned(Lineup, fitness: [PlayerID: ProjectedFitness])
        /// As confirmed, whatever has happened to the squad since.
        case confirmed(ConfirmedRecord)
    }

    public let body: Body
    /// One line per override the engine did not use, in slot order: "D_L: <the engine's reason>".
    public let ignoredOverrides: [String]

    public init(fixture: StoredFixture, tacticName: String, usesPrimaryBecauseItsTacticWasDeleted: Bool, body: Body,
                ignoredOverrides: [String]) {
        self.fixture = fixture; self.tacticName = tacticName
        self.usesPrimaryBecauseItsTacticWasDeleted = usesPrimaryBecauseItsTacticWasDeleted
        self.body = body; self.ignoredOverrides = ignoredOverrides
    }
}

/// What Match Selection can show: what is missing before anything can be planned, why the plan stopped, or the plan.
public enum PlanState: Equatable, Sendable {
    case needsSquad, needsTactic, needsFixtures
    /// The engine's sentences.
    case failed([String])
    /// Confirmed and planned fixtures together, in date order.
    case ready([FixturePlan])
}

/// A player who could be chosen for a slot.
public struct Candidate: Identifiable, Equatable, Sendable {
    public var id: PlayerID { player }
    public let player: PlayerID
    public let name: String
    public let squad: Squad
    /// His full-fitness rating in the slot.
    public let rating: Double
    /// Why he cannot play in the fixture, in the engine's words; nil when he can.
    public let unavailable: String?

    public init(player: PlayerID, name: String, squad: Squad, rating: Double, unavailable: String?) {
        self.player = player; self.name = name; self.squad = squad; self.rating = rating; self.unavailable = unavailable
    }
}
