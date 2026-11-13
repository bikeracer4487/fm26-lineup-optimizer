import Foundation
import LineupEngine

/// One saved fixture in the plan: its confirmed lineup, or the lineup the planner chose.
public struct FixturePlan: Identifiable, Equatable, Sendable {
    public var id: FixtureID { fixture.id }
    public let fixture: StoredFixture
    /// The tactic planned with, or for a confirmed lineup the one it was confirmed with; for a missed fixture the one
    /// it would use, empty when there is none.
    public let tacticName: String
    /// The fixture names a tactic that is no longer saved, so it was planned with the primary.
    public let usesPrimaryBecauseItsTacticWasDeleted: Bool

    public enum Body: Equatable, Sendable {
        /// The planner's lineup and every player's projected fitness on the day.
        case planned(Lineup, fitness: [PlayerID: ProjectedFitness])
        /// As confirmed, whatever has happened to the squad since.
        case confirmed(ConfirmedRecord)
        /// Before the plan's starting day with no lineup confirmed: not planned, and not counted as played.
        case missed
    }

    public let body: Body
    /// For a planned lineup, the planner's word on whether the fitness it was chosen on is projected rather than the
    /// imported figures; false for any other.
    public let fitnessIsProjected: Bool
    /// One sentence per override the engine did not use, in slot order: "<Name> at D L: <the engine's reason>.", or
    /// "The player chosen for D L is no longer in the squad."
    public let ignoredOverrides: [String]

    /// For a missed fixture, what that means and what to do about it; nil for any other.
    public var missedNote: String? {
        guard case .missed = body else { return nil }
        return "This match is before the squad was last imported and no lineup was confirmed for it, so it does not "
            + "count towards runs of starts. Delete it, or correct its date, on the Fixtures screen."
    }

    public init(fixture: StoredFixture, tacticName: String, usesPrimaryBecauseItsTacticWasDeleted: Bool, body: Body,
                fitnessIsProjected: Bool = false, ignoredOverrides: [String]) {
        self.fixture = fixture; self.tacticName = tacticName
        self.usesPrimaryBecauseItsTacticWasDeleted = usesPrimaryBecauseItsTacticWasDeleted
        self.body = body; self.fitnessIsProjected = fitnessIsProjected; self.ignoredOverrides = ignoredOverrides
    }
}

/// What Match Selection can show: what is missing before anything can be planned, why the plan stopped, or the plan.
public enum PlanState: Equatable, Sendable {
    case needsSquad, needsFixtures
    /// Empty when no tactic is saved; otherwise one sentence per tactic that a fixture within the horizon would use
    /// and that cannot be used, naming its problems.
    case needsTactic([String])
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
    /// His full-fitness rating in the slot; nil when it cannot be worked out, and `unavailable` then says why.
    public let rating: Double?
    /// Why he cannot play in the fixture, in the engine's words; nil when he can.
    public let unavailable: String?

    public init(player: PlayerID, name: String, squad: Squad, rating: Double?, unavailable: String?) {
        self.player = player; self.name = name; self.squad = squad; self.rating = rating; self.unavailable = unavailable
    }
}
