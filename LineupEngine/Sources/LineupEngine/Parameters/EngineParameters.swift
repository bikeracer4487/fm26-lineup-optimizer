/// One step of the familiarity table: a player with at least `minimum` familiarity plays at `factor`.
public struct FamiliarityStep: Sendable, Equatable {
    public let minimum: Int
    public let factor: Double

    public init(minimum: Int, factor: Double) {
        self.minimum = minimum
        self.factor = factor
    }
}

/// Lets `EngineParameters.all` list every stored `Parameter` whatever its value type.
protocol ParameterProtocol {
    var evidence: Evidence { get }
    var source: String { get }
}

extension Parameter: ParameterProtocol {}

/// Every number a rating or selection rule uses, each with its evidence level and source.
public struct EngineParameters: Sendable {
    public var positionShare: Parameter<Double>
    public var roleShare: Parameter<Double>
    public var consensusShare: Parameter<Double>
    public var keyWeight: Parameter<Double>
    public var preferableWeight: Parameter<Double>
    public var consensusCap: Parameter<Double>
    public var balanceBonus: Parameter<Double>
    public var thresholdPenaltyPerPoint: Parameter<Double>
    public var thresholdPenaltyFloor: Parameter<Double>
    /// Highest minimum first. A familiarity below every minimum takes the last step's factor.
    public var familiaritySteps: Parameter<[FamiliarityStep]>
    public var defensivePhaseWeightIP: Parameter<Double>
    public var otherPhaseWeightIP: Parameter<Double>
    public var outOfPositionBelow: Parameter<Int>
    // Task 11 adds the fitness and risk parameters

    private static let pythonSource = "rating_calculator.py (branch customizable-tactics)"

    public static let fm27: EngineParameters = {
        func carried(_ value: Double) -> Parameter<Double> { Parameter(value, .carriedOverFM26, source: pythonSource) }
        return EngineParameters(
            positionShare: carried(0.60),
            roleShare: carried(0.35),
            consensusShare: carried(0.05),
            keyWeight: carried(1.5),
            preferableWeight: carried(1.2),
            consensusCap: carried(10),
            balanceBonus: carried(0.01),
            thresholdPenaltyPerPoint: carried(0.02),
            thresholdPenaltyFloor: carried(0.80),
            familiaritySteps: Parameter(
                [FamiliarityStep(minimum: 18, factor: 1.00), FamiliarityStep(minimum: 15, factor: 0.95),
                 FamiliarityStep(minimum: 13, factor: 0.90), FamiliarityStep(minimum: 10, factor: 0.80),
                 FamiliarityStep(minimum: 8, factor: 0.60), FamiliarityStep(minimum: 5, factor: 0.35),
                 FamiliarityStep(minimum: 0, factor: 0.10)],
                .carriedOverFM26,
                source: "\(pythonSource); FM27 Match Lab Study 5 (cap 15 costs 0.26 points per game, cap 10 costs 0.85) is consistent with 0.95 and 0.80"),
            defensivePhaseWeightIP: carried(0.5),
            otherPhaseWeightIP: carried(0.7),
            outOfPositionBelow: Parameter(10, .derived, source: "the Competent step of the familiarity table: below it a player is out of position"))
    }()

    /// Every stored parameter, found by reflection so a new one cannot be left out.
    public var all: [(name: String, evidence: Evidence, source: String)] {
        Mirror(reflecting: self).children.compactMap { child in
            guard let label = child.label, let parameter = child.value as? any ParameterProtocol else { return nil }
            return (label, parameter.evidence, parameter.source)
        }
    }
}
