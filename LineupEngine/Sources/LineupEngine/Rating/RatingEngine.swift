import Foundation

public struct RatingConfiguration: Sendable, Equatable {
    public var appliesCurrentAbilityFactor: Bool
    public var roundsLikeThePythonReference: Bool

    public init(appliesCurrentAbilityFactor: Bool, roundsLikeThePythonReference: Bool) {
        self.appliesCurrentAbilityFactor = appliesCurrentAbilityFactor
        self.roundsLikeThePythonReference = roundsLikeThePythonReference
    }

    public static let fm27 = RatingConfiguration(appliesCurrentAbilityFactor: false, roundsLikeThePythonReference: false)
    /// Reproduces `rating_calculator.py` exactly, for the test that proves the port.
    public static let fm26Reference = RatingConfiguration(appliesCurrentAbilityFactor: true, roundsLikeThePythonReference: true)
}

public struct PhaseRating: Equatable, Sendable {
    public let positionScore: Double
    public let roleScore: Double
    public let consensusBonus: Double
    public let thresholdFactor: Double
    /// 0...100 before familiarity.
    public let base: Double
    public let familiarity: Int
    public let familiarityFactor: Double
    public var value: Double { base * familiarityFactor }
}

public struct SlotRating: Equatable, Sendable {
    public let inPossession: PhaseRating
    public let outOfPossession: PhaseRating
    public let ipWeight: Double
    /// 0...200.
    public let value: Double
}

public enum RatingError: Error, Equatable {
    case missingAttribute(player: String, attribute: Attribute)
    case missingFamiliarity(player: String, position: Position)
}

public struct RatingEngine: Sendable {
    // The current-ability factor is an FM26 rule, not an FM27 one: it exists only so the
    // port can be compared with the Python, so these numbers stay out of `EngineParameters`.
    private static let referenceCurrentAbility = 100.0
    private static let currentAbilityStep = 0.005
    private static let currentAbilityFloor = 0.85
    private static let currentAbilityCeiling = 1.15

    private let tables: RatingTables
    private let parameters: EngineParameters
    private let configuration: RatingConfiguration

    public init(tables: RatingTables, parameters: EngineParameters, configuration: RatingConfiguration) {
        self.tables = tables
        self.parameters = parameters
        self.configuration = configuration
    }

    public func rating(for player: Player, in assignment: SlotAssignment) throws -> SlotRating {
        let ip = try phaseRating(player, position: assignment.ipPosition, role: assignment.ipRole)
        let oop = try phaseRating(player, position: assignment.oopPosition, role: assignment.oopRole)
        let w = assignment.oopPosition.isDefensive ? parameters.defensivePhaseWeightIP.value : parameters.otherPhaseWeightIP.value
        let combined = 2 * (w * ip.value + (1 - w) * oop.value)
        return SlotRating(inPossession: ip, outOfPossession: oop, ipWeight: w,
                          value: configuration.roundsLikeThePythonReference ? roundedToOneDecimal(combined) : combined)
    }

    private func phaseRating(_ player: Player, position: Position, role: Role) throws -> PhaseRating {
        let positionScore = try positionScore(player, position)
        let roleScore = try roleScore(player, role)
        let consensus = try consensusBonus(player, position, role)
        let thresholdFactor = try thresholdFactor(player, role)
        var base = (parameters.positionShare.value * positionScore + parameters.roleShare.value * roleScore
                    + parameters.consensusShare.value * consensus) * thresholdFactor
        if configuration.appliesCurrentAbilityFactor { base *= currentAbilityFactor(player.currentAbility) }
        if configuration.roundsLikeThePythonReference { base = roundedToOneDecimal(base) }
        guard let familiarity = player.familiarity[position] else {
            throw RatingError.missingFamiliarity(player: player.name, position: position)
        }
        return PhaseRating(positionScore: positionScore, roleScore: roleScore, consensusBonus: consensus,
                           thresholdFactor: thresholdFactor, base: base, familiarity: familiarity,
                           familiarityFactor: familiarityFactor(familiarity))
    }

    /// Floating-point sums depend on order and dictionary order changes between launches, so every
    /// accumulation over a table goes through this fixed order.
    private static func inFixedOrder<V>(_ table: [Attribute: V]) -> [(key: Attribute, value: V)] {
        table.sorted { $0.key.rawValue < $1.key.rawValue }
    }

    private func value(_ player: Player, _ attribute: Attribute) throws -> Int {
        guard let value = player.attributes[attribute] else {
            throw RatingError.missingAttribute(player: player.name, attribute: attribute)
        }
        return value
    }

    private func normalised(_ player: Player, _ attribute: Attribute) throws -> Double {
        (Double(try value(player, attribute)) - 1) / 19
    }

    private func positionScore(_ player: Player, _ position: Position) throws -> Double {
        // `RatingTables` guarantees a non-empty, positive-sum table for every position.
        let weights = tables.positionWeights[position] ?? [:]
        let total = Self.inFixedOrder(weights).reduce(0) { $0 + $1.value }
        var sum = 0.0
        for (attribute, weight) in Self.inFixedOrder(weights) { sum += try normalised(player, attribute) * weight }
        return 100 * sum / total
    }

    private func roleScore(_ player: Player, _ role: Role) throws -> Double {
        let weighted = role.key.map { ($0, parameters.keyWeight.value) }
            + role.preferable.filter { !role.key.contains($0) }.map { ($0, parameters.preferableWeight.value) }
        guard !weighted.isEmpty else { return parameters.emptyRoleScore.value }
        var sum = 0.0
        for (attribute, weight) in weighted { sum += try normalised(player, attribute) * weight }
        return 100 * sum / weighted.reduce(0) { $0 + $1.1 }
    }

    private func consensusBonus(_ player: Player, _ position: Position, _ role: Role) throws -> Double {
        let flagged = Set(role.key).union(role.preferable)
        var bonus = 0.0
        for (attribute, weight) in Self.inFixedOrder(tables.consensusBonuses["\(position.tableKey)|\(role.name)"] ?? [:]) where !flagged.contains(attribute) {
            bonus += try normalised(player, attribute) * weight
        }
        if !flagged.contains(.balance), position != .goalkeeper {
            bonus += try normalised(player, .balance) * parameters.balanceBonus.value
        }
        return min(bonus * 100, parameters.consensusCap.value)
    }

    private func thresholdFactor(_ player: Player, _ role: Role) throws -> Double {
        var factor = 1.0
        for (attribute, minimum) in Self.inFixedOrder(tables.thresholds[role.name] ?? [:]) {
            let have = try value(player, attribute)
            if have < minimum { factor *= 1 - parameters.thresholdPenaltyPerPoint.value * Double(minimum - have) }
        }
        return max(factor, parameters.thresholdPenaltyFloor.value)
    }

    private func familiarityFactor(_ familiarity: Int) -> Double {
        let steps = parameters.familiaritySteps.value
        return (steps.first { familiarity >= $0.minimum } ?? steps[steps.count - 1]).factor
    }

    private func currentAbilityFactor(_ currentAbility: Int) -> Double {
        let adjustment = 1 + (Double(currentAbility) - Self.referenceCurrentAbility) * Self.currentAbilityStep
        return max(Self.currentAbilityFloor, min(Self.currentAbilityCeiling, adjustment))
    }

    /// Python's `round(x, 1)`: ties to even.
    private func roundedToOneDecimal(_ x: Double) -> Double { (x * 10).rounded(.toNearestOrEven) / 10 }
}
