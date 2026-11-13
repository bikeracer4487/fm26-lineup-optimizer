import Foundation
@testable import LineupEngine

/// A squad and tactic for the planner's tests.
enum PlannerFixture {
    static func tactic() throws -> Tactic {
        try JSONDecoder().decode(Tactic.self, from: Fixtures.data("tactics/sample-4231.json"))
    }

    /// Two natural players for each of the tactic's eleven slots: "<slot> first" with every attribute at
    /// `first` and "<slot> second" with every attribute at `second`, familiarity 20 at the slot's
    /// in-possession and out-of-possession positions.
    static func squad(first: Int = 14, second: Int = 12) throws -> [Player] {
        let assignments = try tactic().assignments(catalog: RoleCatalog.fm27())
        return assignments.flatMap { assignment in
            [("first", first), ("second", second)].map { tier, level in
                Player.fixture(name: name(assignment.slot, tier), all: level,
                               familiarity: Dictionary(uniqueKeysWithValues: Set([assignment.ipPosition, assignment.oopPosition]).map { ($0, 20) }))
            }
        }
    }

    static func name(_ slot: SlotID, _ tier: String) -> String { "\(slot.rawValue) \(tier)" }

    static func id(_ slot: SlotID, _ tier: String) -> PlayerID {
        PlayerID(key: PlayerID.normalise(name(slot, tier)))
    }
}
