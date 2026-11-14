/// One point of a curve: at `x` the curve's value is `factor`. In a fitness curve `x` is a fraction of 1 and `factor`
/// multiplies the rating; in a rating profile's attribute curve `x` is the attribute value and `factor` its 0...1 scale.
public struct CurvePoint: Sendable, Equatable {
    public let x: Double
    public let factor: Double

    public init(x: Double, factor: Double) {
        self.x = x
        self.factor = factor
    }
}

/// One step of the jadedness table: a player at or below `upTo` plays at `factor`.
public struct JadednessStep: Sendable, Equatable {
    public let upTo: Int
    public let factor: Double

    public init(upTo: Int, factor: Double) {
        self.upTo = upTo
        self.factor = factor
    }
}

public struct FitnessFactors: Equatable, Sendable {
    public let condition: Double
    public let sharpness: Double
    public let jadedness: Double
    public var product: Double { condition * sharpness * jadedness }

    public init(condition: Double, sharpness: Double, jadedness: Double) {
        self.condition = condition
        self.sharpness = sharpness
        self.jadedness = jadedness
    }
}

/// How condition, sharpness and jadedness scale a player's slot rating on match day.
public enum FitnessModel {
    public static func factors(condition: Double, sharpness: Double, jadedness: Int, parameters: EngineParameters) -> FitnessFactors {
        FitnessFactors(
            condition: evaluate(parameters.conditionCurve.value, at: condition),
            sharpness: evaluate(parameters.sharpnessCurve.value, at: sharpness),
            jadedness: jadednessFactor(jadedness, parameters: parameters))
    }

    /// Straight-line interpolation between neighbouring points, clamped at the ends.
    /// An empty curve gives 1.0 rather than trapping; `problems(in:)` reports it.
    static func evaluate(_ curve: [CurvePoint], at x: Double) -> Double {
        let points = curve.sorted { $0.x < $1.x }
        guard let first = points.first, let last = points.last else { return 1.0 }
        if x <= first.x { return first.factor }
        if x >= last.x { return last.factor }
        for (low, high) in zip(points, points.dropFirst()) where x <= high.x {
            let span = high.x - low.x
            guard span > 0 else { return high.factor }
            return low.factor + (high.factor - low.factor) * (x - low.x) / span
        }
        return last.factor
    }

    /// The first step whose `upTo` is at least the value; above every step, `jadednessAbove`.
    static func jadednessFactor(_ jadedness: Int, parameters: EngineParameters) -> Double {
        parameters.jadednessSteps.value.first { jadedness <= $0.upTo }?.factor ?? parameters.jadednessAbove.value
    }

    /// Curves may be listed in any order (evaluation sorts them) but need distinct x values; steps must ascend.
    /// Misconfigurations the evaluation tolerates but should never ship with.
    public static func problems(in parameters: EngineParameters) -> [String] {
        var found: [String] = []
        for (name, curve) in [("conditionCurve", parameters.conditionCurve.value), ("sharpnessCurve", parameters.sharpnessCurve.value)] {
            if curve.isEmpty {
                found.append("\(name) is empty")
            } else if !zip(curve.map(\.x).sorted(), curve.map(\.x).sorted().dropFirst()).allSatisfy({ $0 < $1 }) {
                found.append("\(name) has two points at the same x")
            }
        }
        let steps = parameters.jadednessSteps.value
        if steps.isEmpty {
            found.append("jadednessSteps is empty")
        } else if !zip(steps, steps.dropFirst()).allSatisfy({ $0.upTo < $1.upTo }) {
            found.append("jadednessSteps upTo values are not strictly increasing")
        }
        for (name, curve) in [("conditionRecoveryPerDay", parameters.conditionRecoveryPerDay.value),
                              ("sharpnessGainTaper", parameters.sharpnessGainTaper.value)] where curve.isEmpty {
            found.append("\(name) is empty")
        }
        let load = parameters.positionConditionLoad.value
        for position in Position.allCases where load[position] == nil {
            found.append("positionConditionLoad has no entry for \(position.rawValue)")
        }
        let recovery = parameters.trainingIntensityRecovery.value
        for intensity in TrainingIntensity.allCases where recovery[intensity] == nil {
            found.append("trainingIntensityRecovery has no entry for \(intensity.rawValue)")
        }
        let loaned = parameters.loanedInFactor.value
        for importance in Importance.allCases where loaned[importance] == nil {
            found.append("loanedInFactor has no entry for \(importance.rawValue)")
        }
        let consecutive = parameters.consecutiveStartSteps.value
        for position in Position.allCases where consecutive[position] == nil {
            found.append("consecutiveStartSteps has no entry for \(position.rawValue)")
        }
        // The need for sharpness divides by their difference.
        let full = parameters.sharpnessNeedFull.value, most = parameters.sharpnessNeedMost.value
        if !(full > most) {
            found.append("sharpnessNeedFull (\(full)) is not greater than sharpnessNeedMost (\(most))")
        }
        // Each of these becomes an adjustment's factor, or 1 plus a multiple of it; an adjustment's factor must be
        // finite and not negative.
        func usable(_ x: Double) -> Bool { x.isFinite && x >= 0 }
        let notUsable = "not a finite number of 0 or more"
        for (name, value) in [("fullySharpFactor", parameters.fullySharpFactor.value),
                              ("developmentFactor", parameters.developmentFactor.value),
                              ("retrainingFactorLow", parameters.retrainingFactorLow.value),
                              ("retrainingFactorMedium", parameters.retrainingFactorMedium.value),
                              ("sharpnessNeedStrengthLow", parameters.sharpnessNeedStrengthLow.value),
                              ("sharpnessNeedStrengthBuild", parameters.sharpnessNeedStrengthBuild.value),
                              ("stabilityAnchorBonus", parameters.stabilityAnchorBonus.value),
                              ("stabilityRecentBonus", parameters.stabilityRecentBonus.value)] where !usable(value) {
            found.append("\(name) is \(value), \(notUsable)")
        }
        for importance in Importance.allCases {
            if let factor = loaned[importance], !usable(factor) {
                found.append("loanedInFactor for \(importance.rawValue) is \(factor), \(notUsable)")
            }
        }
        for position in Position.allCases {
            for step in consecutive[position] ?? [] where !usable(step.factor) {
                found.append("consecutiveStartSteps for \(position.rawValue) at \(step.starts) starts is \(step.factor), \(notUsable)")
            }
        }
        let weights = parameters.importanceWeights.value
        for importance in Importance.allCases {
            if let weight = weights[importance] {
                if !(weight.isFinite && weight > 0) {
                    found.append("importanceWeights for \(importance.rawValue) is \(weight), not a finite number above 0")
                }
            } else {
                found.append("importanceWeights has no entry for \(importance.rawValue)")
            }
        }
        // Rest advice draws its watch line at this share of a player's limit.
        let watchShare = parameters.restWatchShare.value
        if !(watchShare >= 0 && watchShare <= 1) {
            found.append("restWatchShare is \(watchShare), not between 0 and 1")
        }
        // Rest advice divides by these to count days.
        for (name, rate) in [("jadednessRecoveryPerDay", parameters.jadednessRecoveryPerDay.value),
                             ("holidayJadednessRecoveryPerDay", parameters.holidayJadednessRecoveryPerDay.value)]
            where !(rate.isFinite && rate > 0) {
            found.append("\(name) is \(rate), not a finite number above 0")
        }
        let margin = parameters.holidayMargin.value
        if margin < 0 {
            found.append("holidayMargin is \(margin), not 0 or more")
        }
        let limits = parameters.restLimitRules.value
        if limits.lowest > limits.highest {
            found.append("restLimitRules lowest (\(limits.lowest)) is above its highest (\(limits.highest))")
        }
        // The age bands are tried oldest first, so an older band that starts at or above the oldest is never reached.
        if !(limits.olderFromAge < limits.oldestFromAge) {
            found.append("restLimitRules olderFromAge (\(limits.olderFromAge)) is not below oldestFromAge (\(limits.oldestFromAge))")
        }
        let estimateDays = parameters.restConditionEstimateDays.value
        if estimateDays < 1 {
            found.append("restConditionEstimateDays is \(estimateDays), not 1 or more")
        }
        // Learnability divides by these.
        let learnability = parameters.learnabilityRules.value
        for (name, divisor) in [("roomToGrowSpan", learnability.roomToGrowSpan), ("attributeMaximum", learnability.attributeMaximum)]
            where !(divisor.isFinite && divisor > 0) {
            found.append("learnabilityRules \(name) is \(divisor), not a finite number above 0")
        }
        // Retraining weeks are the middle of a range times these factors, rounded to a whole number.
        let weeks = parameters.retrainingWeeks.value
        for (name, range) in [("fluid", weeks.fluid), ("structural", weeks.structural), ("spatial", weeks.spatial)]
            where !(range.fewest >= 0 && range.fewest <= range.most) {
            found.append("retrainingWeeks for \(name) is \(range.fewest) to \(range.most), not a range of 0 or more weeks")
        }
        let pace = parameters.retrainingPace.value
        var paceFactors = pace.ageSteps.map { ("age factor up to \($0.upTo)", $0.factor) }
        paceFactors.append((pace.ageSteps.last.map { "age factor above \($0.upTo)" } ?? "age factor", pace.ageAbove))
        paceFactors.append(("high Versatility factor", pace.highVersatilityFactor))
        paceFactors.append(("low Versatility factor", pace.lowVersatilityFactor))
        paceFactors += pace.headStartSteps.map { ("head start factor from familiarity \($0.minimum)", $0.factor) }
        for (name, factor) in paceFactors where !usable(factor) {
            found.append("retrainingPace \(name) is \(factor), \(notUsable)")
        }
        return found
    }
}
