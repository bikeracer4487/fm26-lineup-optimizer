import Foundation

/// The first and second elevens at full fitness: who the first-choice players are and who covers them.
public struct SquadTiers: Equatable, Sendable {
    public let first: [SlotID: PlayerID]
    public let second: [SlotID: PlayerID]
    /// Full-fitness slot rating of every rated player at every slot of the tactic.
    public let ratings: [PlayerID: [SlotID: Double]]

    /// His slot and tier (1 for the first eleven, 2 for the second), or nil when he is in neither.
    public func slot(of player: PlayerID) -> (slot: SlotID, tier: Int)? {
        for slot in SlotID.allCases {
            if first[slot] == player { return (slot, 1) }
            if second[slot] == player { return (slot, 2) }
        }
        return nil
    }

    /// For a first-eleven player: his rating in his slot minus the second eleven's player in that
    /// slot (minus nothing when the slot has no second player). nil for everyone else.
    public func advantage(of player: PlayerID) -> Double? {
        guard let (slot, tier) = slot(of: player), tier == 1, let own = ratings[player]?[slot] else { return nil }
        guard let cover = second[slot], let covering = ratings[cover]?[slot] else { return own }
        return own - covering
    }

    /// Injured players and players out on loan are left out; condition, sharpness, jadedness and bans
    /// are ignored. The second eleven is the best assignment from the players the first did not use.
    /// Throws `TacticError` for an unusable tactic and `RatingError` for a player with missing data.
    public static func compute(tactic: Tactic, players: [Player], ownClub: String?, catalog: RoleCatalog,
                               profile: RatingProfile, parameters: EngineParameters) throws -> SquadTiers {
        let assignments = try tactic.assignments(catalog: catalog)
        let engine = RatingEngine(profile: profile, parameters: parameters, configuration: .fm27)
        // A repeated PlayerID is a caller error: keep the first. Sorting by key makes the result
        // independent of input order.
        var seen = Set<PlayerID>()
        let eligible = players.filter { seen.insert($0.id).inserted }
            .sorted { $0.id.key < $1.id.key }
            .filter { player in
                if player.isInjured { return false }
                if case .loanedOut = LoanStatus.of(player, ownClub: ownClub) { return false }
                return true
            }

        // values[slot][candidate], slots in SlotID order (as `assignments` is).
        var values: [[Double]] = []
        var ratings: [PlayerID: [SlotID: Double]] = [:]
        for assignment in assignments {
            var row: [Double] = []
            for player in eligible {
                let value = try engine.rating(for: player, in: assignment).value
                row.append(value)
                ratings[player.id, default: [:]][assignment.slot] = value
            }
            values.append(row)
        }

        let firstChoice = AssignmentSolver.maximise(values: values.map { $0.map { Optional($0) } })
        var usedIndices = Set<Int>()
        var first: [SlotID: PlayerID] = [:]
        for (s, choice) in firstChoice.enumerated() {
            guard let c = choice else { continue }
            first[assignments[s].slot] = eligible[c].id
            usedIndices.insert(c)
        }

        let remaining = eligible.indices.filter { !usedIndices.contains($0) }
        let secondChoice = AssignmentSolver.maximise(values: values.map { row in remaining.map { Optional(row[$0]) } })
        var second: [SlotID: PlayerID] = [:]
        for (s, choice) in secondChoice.enumerated() {
            guard let c = choice else { continue }
            second[assignments[s].slot] = eligible[remaining[c]].id
        }
        return SquadTiers(first: first, second: second, ratings: ratings)
    }
}
