/// One step of the familiarity table: a player with at least `minimum` familiarity plays at `factor`.
public struct FamiliarityStep: Sendable, Equatable {
    public let minimum: Int
    public let factor: Double

    public init(minimum: Int, factor: Double) {
        self.minimum = minimum
        self.factor = factor
    }
}

/// One step of a consecutive-starts table: a player who has started at least `starts` matches in quick succession plays at `factor`.
public struct ConsecutiveStartStep: Sendable, Equatable {
    public let starts: Int
    public let factor: Double

    public init(starts: Int, factor: Double) {
        self.starts = starts
        self.factor = factor
    }
}

/// Lets `EngineParameters.all` list every stored `Parameter` whatever its value type.
protocol ParameterProtocol {
    var evidence: Evidence { get }
    var source: String { get }
}

extension Parameter: ParameterProtocol {}

/// Every number a rating or selection rule uses, each with its evidence level and source, apart from the
/// weights, curves and shares that belong to a `RatingProfile`.
public struct EngineParameters: Sendable {
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

    /// Condition lost over a full match at average Stamina and a load of 1.
    public var matchConditionCost: Parameter<Double>
    /// How much each Stamina point above 10 cuts the match condition cost (and each point below raises it).
    public var staminaCostPerPoint: Parameter<Double>
    /// Multiplies the match condition cost by position; every position is listed.
    public var positionConditionLoad: Parameter<[Position: Double]>
    /// Condition regained on a rest day at average Natural Fitness and medium training, by current condition.
    public var conditionRecoveryPerDay: Parameter<[CurvePoint]>
    /// Each Natural Fitness point above 10 raises daily condition recovery by this fraction (below 10 it lowers it).
    public var naturalFitnessRecoveryPerPoint: Parameter<Double>
    /// Multiplies daily condition and jadedness recovery by training intensity.
    public var trainingIntensityRecovery: Parameter<[TrainingIntensity: Double]>
    /// Match sharpness gained per minute played before the taper.
    public var sharpnessGainPerMinute: Parameter<Double>
    /// Multiplies the sharpness gain by current sharpness.
    public var sharpnessGainTaper: Parameter<[CurvePoint]>
    /// Sharpness lost per day without a match at Natural Fitness 10, from the second day after a match.
    public var sharpnessDecayPerDay: Parameter<Double>
    /// Each Natural Fitness point above 10 cuts sharpness decay by this fraction.
    public var sharpnessDecayNaturalFitnessPerPoint: Parameter<Double>
    /// Sharpness does not decay below this.
    public var sharpnessFloor: Parameter<Double>
    /// Jadedness gained per match.
    public var jadednessPerMatch: Parameter<Double>
    /// Jadedness lost per rest day at medium training.
    public var jadednessRecoveryPerDay: Parameter<Double>
    /// Jadedness does not fall below this.
    public var jadednessFloor: Parameter<Double>
    /// Minutes a starter is assumed to play.
    public var assumedMinutes: Parameter<Double>
    /// A start extends a run of consecutive starts only when it came within this many days of the next match.
    public var consecutiveStartWindowDays: Parameter<Int>

    /// Factor on a loaned-in player's match-day value, by match importance.
    public var loanedInFactor: Parameter<[Importance: Double]>
    /// By in-possession position, the steps of a run of consecutive starts; the highest step reached applies.
    public var consecutiveStartSteps: Parameter<[Position: [ConsecutiveStartStep]]>
    /// Sharpness (fraction of 1) at and above which a player needs no minutes for sharpness.
    public var sharpnessNeedFull: Parameter<Double>
    /// Sharpness (fraction of 1) at and below which a player's need for minutes is greatest.
    public var sharpnessNeedMost: Parameter<Double>
    /// The most a lesser fixture favours an unsharp player, as a fraction of his value, at greatest need.
    public var sharpnessNeedStrengthLow: Parameter<Double>
    /// The most a sharpness fixture favours an unsharp first or second eleven player, as a fraction of his value.
    public var sharpnessNeedStrengthBuild: Parameter<Double>
    /// Factor on a first or second eleven player who is already fully sharp in a sharpness fixture.
    public var fullySharpFactor: Parameter<Double>
    /// The oldest age counted as a prospect.
    public var prospectMaxAge: Parameter<Int>
    /// A prospect's potential ability is at least this multiple of his current ability.
    public var prospectHeadroom: Parameter<Double>
    /// Factor on a prospect's value in a lesser fixture.
    public var developmentFactor: Parameter<Double>
    /// Lowest familiarity at which a retrainee is favoured in a low or sharpness fixture.
    public var retrainingFromFamiliarity: Parameter<Int>
    /// Lowest familiarity at which a retrainee is favoured in a medium fixture.
    public var retrainingFromFamiliarityMedium: Parameter<Int>
    /// Familiarity at and above which a retrainee is no longer favoured.
    public var retrainingUntilFamiliarity: Parameter<Int>
    /// Factor on a retrainee's value in a low or sharpness fixture.
    public var retrainingFactorLow: Parameter<Double>
    /// Factor on a retrainee's value in a medium fixture.
    public var retrainingFactorMedium: Parameter<Double>
    /// How many recent starts in one slot count as holding it.
    public var stabilityAnchorRun: Parameter<Int>
    /// Bonus, at stability 1, for having held the slot for the whole anchor run.
    public var stabilityAnchorBonus: Parameter<Double>
    /// Bonus, at stability 1, for having played the slot in the most recent match.
    public var stabilityRecentBonus: Parameter<Double>

    private static let pythonSource = "rating_calculator.py (branch customizable-tactics)"
    private static let fitnessSource = "docs/Research/fm27-condition-fatigue-sharpness.md"

    public static let fm27: EngineParameters = {
        func carried(_ value: Double) -> Parameter<Double> { Parameter(value, .carriedOverFM26, source: pythonSource) }
        let matchSelectorSource = "ui/api/api_match_selector.py (branch customizable-tactics)"
        let readySelectorSource = "fm_match_ready_selector.py (branch customizable-tactics)"
        let retrainingSource = "\(readySelectorSource); docs/Research/position-retraining.md"
        let sharpnessNeedSource = "docs/Research/match-sharpness.md"
        func steps(_ pairs: [(Int, Double)]) -> [ConsecutiveStartStep] { pairs.map { ConsecutiveStartStep(starts: $0.0, factor: $0.1) } }
        return EngineParameters(
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
                    + "rather than leaving the player out); docs/Research/physical-condition-claude.md (85% condition minimum for starting players)"),
            jadedThreshold: Parameter(400, .fm27Observation, source: "\(fitnessSource); FM Lens labels players \"Jaded\" above 400"),
            matchConditionCost: Parameter(
                0.25, .carriedOverFM26,
                source: "docs/Research/physical-condition.md: 100% to about 75% over 90 minutes"),
            staminaCostPerPoint: Parameter(
                0.015, .derived,
                source: "SI says Stamina is a stronger factor in FM27 (\(fitnessSource)); the size is this design's guess, three times the branch's slope"),
            positionConditionLoad: Parameter(
                Dictionary(uniqueKeysWithValues: Position.allCases.map { position in
                    switch position {
                    case .goalkeeper: (position, 0.2)
                    case .defenderCentral: (position, 0.8)
                    case .defenderLeft, .defenderRight, .wingBackLeft, .wingBackRight, .defensiveMidfielder: (position, 1.2)
                    case .midfielderLeft, .midfielderCentral, .midfielderRight, .attackingMidLeft, .attackingMidCentral,
                         .attackingMidRight, .striker: (position, 1.0)
                    }
                }),
                .carriedOverFM26,
                source: "fm_match_ready_selector.py (1.2 and 0.8) and ui/api/state_simulation.py (goalkeeper), branch customizable-tactics; no FM27 evidence"),
            conditionRecoveryPerDay: Parameter(
                [CurvePoint(x: 0.70, factor: 0.124), CurvePoint(x: 0.80, factor: 0.0813),
                 CurvePoint(x: 0.90, factor: 0.0275), CurvePoint(x: 1.00, factor: 0)],
                .carriedOverFM26,
                source: "fm-arena rest-day test quoted in \(fitnessSource) (7,000 to 8,240; 8,000 to 8,813; 9,000 to 9,275)"),
            naturalFitnessRecoveryPerPoint: Parameter(
                0.0167, .carriedOverFM26,
                source: "state_simulation.py (0.5 + NF/100, relative to Natural Fitness 10), branch customizable-tactics"),
            trainingIntensityRecovery: Parameter(
                [.low: 1.2, .medium: 1.0, .high: 0.8], .carriedOverFM26,
                source: "scoring_parameters.py, branch customizable-tactics; FM27 testers report the same direction without numbers"),
            sharpnessGainPerMinute: Parameter(
                0.001, .fm27Measured, source: "ZaZ, \(fitnessSource)"),
            sharpnessGainTaper: Parameter(
                [CurvePoint(x: 0.65, factor: 1.0), CurvePoint(x: 0.80, factor: 0.667), CurvePoint(x: 0.90, factor: 0.222)],
                .carriedOverFM26,
                source: "docs/Research/physical-condition-claude.md: 9%, 6% and 2% per 90 minutes; FM27 did not test high sharpness"),
            sharpnessDecayPerDay: Parameter(
                0.005, .fm27Measured, source: "ZaZ, \(fitnessSource); none on the day after a match"),
            sharpnessDecayNaturalFitnessPerPoint: Parameter(
                0.08, .carriedOverFM26,
                source: "docs/Research/physical-condition-claude.md: Natural Fitness 20 loses about a fifth of what 10 loses"),
            sharpnessFloor: Parameter(0.35, .fm27Observation, source: fitnessSource),
            jadednessPerMatch: Parameter(60, .carriedOverFM26, source: "fm-arena, +50 to +70 per match"),
            jadednessRecoveryPerDay: Parameter(20, .carriedOverFM26, source: "fm-arena, one rest day removes about 20"),
            jadednessFloor: Parameter(
                -500, .fm27Observation, source: "editor range; rested players sit at exactly -500 (\(fitnessSource))"),
            assumedMinutes: Parameter(90, .derived, source: "the planner does not model substitutions"),
            consecutiveStartWindowDays: Parameter(
                4, .derived,
                source: "docs/Research/player-rotation-guide.md: one match a week needs little rotation; rotation matters when matches come two or three a week"),
            loanedInFactor: Parameter(
                [.high: 1.0, .medium: 0.95, .low: 0.85, .sharpness: 0.85], .carriedOverFM26, source: matchSelectorSource),
            consecutiveStartSteps: Parameter(
                Dictionary(uniqueKeysWithValues: Position.allCases.map { position in
                    switch position {
                    case .defenderLeft, .defenderRight, .wingBackLeft, .wingBackRight, .defensiveMidfielder:
                        (position, steps([(2, 0.90), (3, 0.75), (4, 0.60)]))
                    case .midfielderLeft, .midfielderCentral, .midfielderRight, .attackingMidLeft, .attackingMidCentral,
                         .attackingMidRight, .striker:
                        (position, steps([(3, 0.90), (4, 0.80), (5, 0.70)]))
                    case .defenderCentral, .goalkeeper:
                        (position, steps([(5, 0.90), (6, 0.80)]))
                    }
                }),
                .carriedOverFM26, source: readySelectorSource),
            sharpnessNeedFull: Parameter(0.91, .carriedOverFM26, source: "\(sharpnessNeedSource): 91% and above is full sharpness"),
            sharpnessNeedMost: Parameter(
                0.50, .derived, source: "the sharpness curve's 50% anchor (FM27 Match Lab), below which the need is treated as greatest"),
            sharpnessNeedStrengthLow: Parameter(
                0.30, .derived,
                source: "the branch's ×1.2 to ×1.4 boosts (\(matchSelectorSource)), sized so an unsharp player is about level with a sharp one once his sharpness factor is counted"),
            sharpnessNeedStrengthBuild: Parameter(
                1.0, .derived, source: "a sharpness fixture exists to build sharpness, so need counts fully; this design's choice"),
            fullySharpFactor: Parameter(0.60, .carriedOverFM26, source: matchSelectorSource),
            prospectMaxAge: Parameter(21, .carriedOverFM26, source: "ui/api/api_player_removal.py (branch customizable-tactics)"),
            prospectHeadroom: Parameter(1.15, .carriedOverFM26, source: "ui/api/api_player_removal.py (branch customizable-tactics)"),
            developmentFactor: Parameter(
                1.10, .derived,
                source: "this design's size; the premise, that growth comes mainly from match time, is one FM27 tester's report in docs/Research/fm27-training-and-retraining.md"),
            retrainingFromFamiliarity: Parameter(10, .carriedOverFM26, source: retrainingSource),
            retrainingFromFamiliarityMedium: Parameter(15, .carriedOverFM26, source: retrainingSource),
            retrainingUntilFamiliarity: Parameter(18, .carriedOverFM26, source: retrainingSource),
            retrainingFactorLow: Parameter(1.15, .carriedOverFM26, source: retrainingSource),
            retrainingFactorMedium: Parameter(1.08, .carriedOverFM26, source: retrainingSource),
            stabilityAnchorRun: Parameter(
                3, .derived, source: "rescaled from ui/api/stability.py (branch customizable-tactics); three matches running counts as holding a slot"),
            stabilityAnchorBonus: Parameter(
                0.05, .derived, source: "rescaled from ui/api/stability.py (branch customizable-tactics), which moved a rating by up to about 2 to 5 points"),
            stabilityRecentBonus: Parameter(
                0.02, .derived, source: "rescaled from ui/api/stability.py (branch customizable-tactics), which moved a rating by up to about 2 to 5 points"))
    }()

    /// Every stored parameter, found by reflection so a new one cannot be left out.
    public var all: [(name: String, evidence: Evidence, source: String)] {
        Mirror(reflecting: self).children.compactMap { child in
            guard let label = child.label, let parameter = child.value as? any ParameterProtocol else { return nil }
            return (label, parameter.evidence, parameter.source)
        }
    }
}
