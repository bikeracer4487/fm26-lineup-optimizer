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
    /// The role score of a role that lists no key or preferable attributes.
    public var emptyRoleScore: Parameter<Double>
    /// Highest minimum first. A familiarity below every minimum takes the last step's factor.
    public var familiaritySteps: Parameter<[FamiliarityStep]>
    public var defensivePhaseWeightIP: Parameter<Double>
    public var otherPhaseWeightIP: Parameter<Double>
    public var outOfPositionBelow: Parameter<Int>
    /// Condition (fraction of 1) to rating factor, interpolated between points and clamped at the ends.
    public var conditionCurve: Parameter<[CurvePoint]>
    /// Match sharpness (fraction of 1) to rating factor, interpolated between points and clamped at the ends.
    public var sharpnessCurve: Parameter<[CurvePoint]>
    /// Lowest `upTo` first. The first step with `upTo` at or above the jadedness gives the factor.
    public var jadednessSteps: Parameter<[JadednessStep]>
    /// The factor for a jadedness above every step.
    public var jadednessAbove: Parameter<Double>
    /// A player below this condition is kept out at every match importance.
    public var conditionFloor: Parameter<Double>
    /// A player above this jadedness is kept out of everything except high-importance matches.
    public var jadedThreshold: Parameter<Int>

    private static let pythonSource = "rating_calculator.py (branch customizable-tactics)"
    private static let fitnessSource = "docs/Research/fm27-condition-fatigue-sharpness.md"

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
            emptyRoleScore: Parameter(50, .carriedOverFM26, source: "rating_calculator.py calculate_role_score (branch customizable-tactics)"),
            familiaritySteps: Parameter(
                [FamiliarityStep(minimum: 18, factor: 1.00), FamiliarityStep(minimum: 15, factor: 0.95),
                 FamiliarityStep(minimum: 13, factor: 0.90), FamiliarityStep(minimum: 10, factor: 0.80),
                 FamiliarityStep(minimum: 8, factor: 0.60), FamiliarityStep(minimum: 5, factor: 0.35),
                 FamiliarityStep(minimum: 0, factor: 0.10)],
                .carriedOverFM26,
                source: "\(pythonSource); FM27 Match Lab Study 5 (cap 15 costs 0.26 points per game, cap 10 costs 0.85) is consistent with 0.95 and 0.80"),
            defensivePhaseWeightIP: carried(0.5),
            otherPhaseWeightIP: carried(0.7),
            outOfPositionBelow: Parameter(10, .derived, source: "the Competent step of the familiarity table: below it a player is out of position"),
            conditionCurve: Parameter(
                [CurvePoint(x: 1.00, factor: 1.00), CurvePoint(x: 0.90, factor: 0.94), CurvePoint(x: 0.80, factor: 0.82),
                 CurvePoint(x: 0.60, factor: 0.58), CurvePoint(x: 0.00, factor: 0.30)],
                .derived,
                source: "\(fitnessSource); anchors 90% and 80% from FM27 Match Lab (0.28 and 0.80 points per game)"),
            sharpnessCurve: Parameter(
                [CurvePoint(x: 1.00, factor: 1.00), CurvePoint(x: 0.75, factor: 0.92), CurvePoint(x: 0.50, factor: 0.78),
                 CurvePoint(x: 0.35, factor: 0.70), CurvePoint(x: 0.00, factor: 0.70)],
                .derived,
                source: "\(fitnessSource); anchors 75% and 50% from FM27 Match Lab (0.37 and 1.00 points per game)"),
            jadednessSteps: Parameter(
                [JadednessStep(upTo: 200, factor: 1.00), JadednessStep(upTo: 400, factor: 0.90), JadednessStep(upTo: 700, factor: 0.70)],
                .carriedOverFM26,
                source: "scoring_parameters.py JADEDNESS_THRESHOLDS and JADEDNESS_MULTIPLIERS: fresh to 200 ×1.00, fit to 400 ×0.90, tired to 700 ×0.70"),
            jadednessAbove: Parameter(
                0.40, .carriedOverFM26,
                source: "scoring_parameters.py JADEDNESS_MULTIPLIERS: jaded (701 and above) ×0.40"),
            conditionFloor: Parameter(
                0.85, .carriedOverFM26,
                source: "fm_match_ready_selector.py (\"NEVER field players below 85% condition\"; it cuts the rating below 85% "
                    + "rather than leaving the player out); docs/Research/physical-condition.md (85% condition minimum for starting players)"),
            jadedThreshold: Parameter(400, .fm27Observation, source: "\(fitnessSource); FM Lens labels players \"Jaded\" above 400"))
    }()

    /// Every stored parameter, found by reflection so a new one cannot be left out.
    public var all: [(name: String, evidence: Evidence, source: String)] {
        Mirror(reflecting: self).children.compactMap { child in
            guard let label = child.label, let parameter = child.value as? any ParameterProtocol else { return nil }
            return (label, parameter.evidence, parameter.source)
        }
    }
}
