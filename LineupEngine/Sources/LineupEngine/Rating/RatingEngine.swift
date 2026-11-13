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

    public func rating(for player: Player, in assignment: SlotAssignment) -> SlotRating {
        let ip = phaseRating(player, position: assignment.ipPosition, role: assignment.ipRole)
        let oop = phaseRating(player, position: assignment.oopPosition, role: assignment.oopRole)
        let w = assignment.oopPosition.isDefensive ? parameters.defensivePhaseWeightIP.value : parameters.otherPhaseWeightIP.value
        let combined = 2 * (w * ip.value + (1 - w) * oop.value)
        return SlotRating(inPossession: ip, outOfPossession: oop, ipWeight: w,
                          value: configuration.roundsLikeThePythonReference ? roundedToOneDecimal(combined) : combined)
    }

    private func phaseRating(_ player: Player, position: Position, role: Role) -> PhaseRating {
        let positionScore = positionScore(player, position)
        let roleScore = roleScore(player, role)
        let consensus = consensusBonus(player, position, role)
        let thresholdFactor = thresholdFactor(player, role)
        var base = (parameters.positionShare.value * positionScore + parameters.roleShare.value * roleScore
                    + parameters.consensusShare.value * consensus) * thresholdFactor
        if configuration.appliesCurrentAbilityFactor { base *= currentAbilityFactor(player.currentAbility) }
        if configuration.roundsLikeThePythonReference { base = roundedToOneDecimal(base) }
        let familiarity = player.familiarity[position] ?? 1
        return PhaseRating(positionScore: positionScore, roleScore: roleScore, consensusBonus: consensus,
                           thresholdFactor: thresholdFactor, base: base, familiarity: familiarity,
                           familiarityFactor: familiarityFactor(familiarity))
    }

    /// An attribute missing from the player reads as 10, as in the Python.
    private func normalised(_ player: Player, _ attribute: Attribute) -> Double {
        (Double(player.attributes[attribute] ?? 10) - 1) / 19
    }

    private func positionScore(_ player: Player, _ position: Position) -> Double {
        guard let weights = tables.positionWeights[position] else { return 50 }
        let total = weights.values.reduce(0, +)
        guard total > 0 else { return 0 }
        return 100 * weights.reduce(0) { $0 + normalised(player, $1.key) * $1.value } / total
    }

    private func roleScore(_ player: Player, _ role: Role) -> Double {
        let weighted = role.key.map { ($0, parameters.keyWeight.value) }
            + role.preferable.filter { !role.key.contains($0) }.map { ($0, parameters.preferableWeight.value) }
        guard !weighted.isEmpty else { return 50 }
        let sum = weighted.reduce(0) { $0 + normalised(player, $1.0) * $1.1 }
        return 100 * sum / weighted.reduce(0) { $0 + $1.1 }
    }

    private func consensusBonus(_ player: Player, _ position: Position, _ role: Role) -> Double {
        let flagged = Set(role.key).union(role.preferable)
        var bonus = 0.0
        for (attribute, weight) in tables.consensusBonuses["\(position.tableKey)|\(role.name)"] ?? [:] where !flagged.contains(attribute) {
            bonus += normalised(player, attribute) * weight
        }
        if !flagged.contains(.balance), position != .goalkeeper {
            bonus += normalised(player, .balance) * parameters.balanceBonus.value
        }
        return min(bonus * 100, parameters.consensusCap.value)
    }

    private func thresholdFactor(_ player: Player, _ role: Role) -> Double {
        var factor = 1.0
        for (attribute, minimum) in tables.thresholds[role.name] ?? [:] {
            let value = player.attributes[attribute] ?? 10
            if value < minimum { factor *= 1 - parameters.thresholdPenaltyPerPoint.value * Double(minimum - value) }
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
