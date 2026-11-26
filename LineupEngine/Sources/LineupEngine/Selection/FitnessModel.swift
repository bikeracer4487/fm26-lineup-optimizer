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
                              ("shopWindowFactor", parameters.shopWindowFactor.value),
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
        // The development floor favours a young player and never holds him back, so its factors are 1 or more. Its
        // steps are read youngest first; an empty table gives no floor at any age.
        func favouring(_ x: Double) -> Bool { x.isFinite && x >= 1 }
        let notFavouring = "not a finite number of 1 or more"
        let floorSteps = parameters.developmentFactors.value
        if !zip(floorSteps, floorSteps.dropFirst()).allSatisfy({ $0.upToAge < $1.upToAge }) {
            found.append("developmentFactors upToAge values are not strictly increasing")
        }
        for step in floorSteps where !favouring(step.factor) {
            found.append("developmentFactors at up to age \(step.upToAge) is \(step.factor), \(notFavouring)")
        }
        let lowProfessionalism = parameters.developmentFactorLowProfessionalism.value
        if !favouring(lowProfessionalism) {
            found.append("developmentFactorLowProfessionalism is \(lowProfessionalism), \(notFavouring)")
        }
        // Professionalism runs from 1 to 20; 0 means nobody counts as low.
        let lowUpTo = parameters.developmentLowProfessionalismUpTo.value
        if !(0...20).contains(lowUpTo) {
            found.append("developmentLowProfessionalismUpTo is \(lowUpTo), not between 0 and 20")
        }
        for (name, count) in [("developmentLowProfessionalismUpToAge", parameters.developmentLowProfessionalismUpToAge.value),
                              ("developmentStartsPerMonth", parameters.developmentStartsPerMonth.value),
                              ("developmentMonthDays", parameters.developmentMonthDays.value)] where count < 1 {
            found.append("\(name) is \(count), not 1 or more")
        }
        // The successor's favour takes the floor's place, so it too favours and never holds back. Nobody favoured at
        // medium, and no age that needs to be close, are allowed.
        for (name, value) in [("successorFactorLow", parameters.successorFactorLow.value),
                              ("successorFactorMedium", parameters.successorFactorMedium.value)] where !favouring(value) {
            found.append("\(name) is \(value), \(notFavouring)")
        }
        for (name, count) in [("successorsFavouredAtMedium", parameters.successorsFavouredAtMedium.value),
                              ("successorCloseOnlyUpToAge", parameters.successorCloseOnlyUpToAge.value)] where count < 0 {
            found.append("\(name) is \(count), not 0 or more")
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
        // Age steps are read youngest first and head-start steps highest first: the first that fits applies.
        for (name, steps) in [("learnabilityRules", learnability.ageSteps), ("retrainingPace", pace.ageSteps)]
            where !zip(steps, steps.dropFirst()).allSatisfy({ $0.upTo < $1.upTo }) {
            found.append("\(name) ageSteps upTo values are not strictly increasing")
        }
        if !zip(pace.headStartSteps, pace.headStartSteps.dropFirst()).allSatisfy({ $0.minimum > $1.minimum }) {
            found.append("retrainingPace headStartSteps minimum values are not strictly decreasing")
        }
        // The estimate of where a young player's ability could reach.
        let growth = parameters.growthPerSeason.value
        if growth.isEmpty {
            found.append("growthPerSeason is empty")
        } else {
            if !zip(growth, growth.dropFirst()).allSatisfy({ $0.upToAge < $1.upToAge }) {
                found.append("growthPerSeason upToAge values are not strictly increasing")
            }
            for step in growth where !usable(step.points) {
                found.append("growthPerSeason at up to age \(step.upToAge) is \(step.points), \(notUsable)")
            }
        }
        let rates = parameters.growthProfessionalismRates.value
        let anchorLevels = rates.keys.sorted()
        if anchorLevels != [1, 10, 20] {
            let list = anchorLevels.map(String.init)
            let named = list.count > 1 ? list.dropLast().joined(separator: ", ") + " and " + list.last! : (list.first ?? "none")
            found.append("growthProfessionalismRates has anchors at \(named), not at exactly 1, 10 and 20")
        } else {
            let values = anchorLevels.map { rates[$0]! }
            if !values.allSatisfy({ $0.isFinite && $0 > 0 }) {
                found.append("growthProfessionalismRates has a rate that is not a finite number above 0")
            } else if !(values[0] < values[1] && values[1] < values[2]) {
                found.append("growthProfessionalismRates does not rise from Professionalism 1 to 10 to 20")
            }
        }
        for (name, share) in [("growthAmbitionAtOne", parameters.growthAmbitionAtOne.value),
                              ("growthDeterminationAtOne", parameters.growthDeterminationAtOne.value)]
            where !(share >= 0 && share <= 1) {
            found.append("\(name) is \(share), not between 0 and 1")
        }
        let fullFrom = parameters.growthPersonalityFullFrom.value
        if !(2...20).contains(fullFrom) {
            found.append("growthPersonalityFullFrom is \(fullFrom), not between 2 and 20")
        }
        let developing = parameters.developingUpToAge.value
        if developing < 1 {
            found.append("developingUpToAge is \(developing), not 1 or more")
        }
        // A young player's outlook: his reach against these shares of the first choice's rating.
        let lowerShare = parameters.markedlyLowerShare.value, youngestShare = parameters.markedlyLowerShareYoungest.value
        for (name, share) in [("markedlyLowerShare", lowerShare), ("markedlyLowerShareYoungest", youngestShare)]
            where !(share >= 0 && share <= 1) {
            found.append("\(name) is \(share), not between 0 and 1")
        }
        if youngestShare > lowerShare {
            found.append("markedlyLowerShareYoungest (\(youngestShare)) is above markedlyLowerShare (\(lowerShare))")
        }
        // A rating is scaled by (offset + ability): a negative offset could divide by zero.
        let offset = parameters.ratingAbilityOffset.value
        if !usable(offset) {
            found.append("ratingAbilityOffset is \(offset), \(notUsable)")
        }
        for (name, age) in [("onCourseBeforeAge", parameters.onCourseBeforeAge.value),
                            ("youngestUpToAge", parameters.youngestUpToAge.value)] where age < 1 {
            found.append("\(name) is \(age), not 1 or more")
        }
        let hereShare = parameters.matchesHereShare.value
        if !(hereShare >= 0 && hereShare <= 1) {
            found.append("matchesHereShare is \(hereShare), not between 0 and 1")
        }
        for (name, count) in [("matchesHereWindowDays", parameters.matchesHereWindowDays.value),
                              ("matchesHereMinimumConfirmed", parameters.matchesHereMinimumConfirmed.value)] where count < 1 {
            found.append("\(name) is \(count), not 1 or more")
        }
        // Player Removal's advice for a young player.
        let loanFromAge = parameters.loanForMatchesFromAge.value
        if loanFromAge < 1 {
            found.append("loanForMatchesFromAge is \(loanFromAge), not 1 or more")
        }
        let loanMonths = parameters.loanForMatchesMonthsAbove.value
        if loanMonths < 0 {
            found.append("loanForMatchesMonthsAbove is \(loanMonths), not 0 or more")
        }
        // The lines the words are drawn at. Professionalism runs from 1 to 20, so "under 21" is the highest that means
        // anything.
        let holdsBack = parameters.professionalismHoldsBackBelow.value
        if !(1...21).contains(holdsBack) {
            found.append("professionalismHoldsBackBelow is \(holdsBack), not between 1 and 21")
        }
        let weakShare = parameters.scoutingWeakShare.value
        if !(weakShare.isFinite && weakShare > 0 && weakShare < 1) {
            found.append("scoutingWeakShare is \(weakShare), not between 0 and 1")
        }
        let namedFrom = parameters.firstChoiceAgeNamedFrom.value
        if namedFrom < 1 {
            found.append("firstChoiceAgeNamedFrom is \(namedFrom), not 1 or more")
        }
        // Learnability is a weighted sum that should stay within 0 to 1.
        for (name, weight) in [("versatilityWeight", learnability.versatilityWeight), ("ageWeight", learnability.ageWeight),
                               ("professionalismWeight", learnability.professionalismWeight),
                               ("roomToGrowWeight", learnability.roomToGrowWeight)] where !usable(weight) {
            found.append("learnabilityRules \(name) is \(weight), \(notUsable)")
        }
        let perPosition = parameters.retrainingPerPosition.value
        if perPosition < 1 {
            found.append("retrainingPerPosition is \(perPosition), not 1 or more")
        }
        for (name, line) in [("depthCoverShare", parameters.depthCoverShare.value),
                             ("retrainingMinimumShare", parameters.retrainingMinimumShare.value),
                             ("retrainingMinimumLearnability", parameters.retrainingMinimumLearnability.value)]
            where !line.isFinite {
            found.append("\(name) is \(line), not a finite number")
        }
        // Player Removal counts this share of the players assessed, rounded down, as the weakest.
        let removal = parameters.removalRules.value
        if !(removal.weakestShare >= 0 && removal.weakestShare <= 1) {
            found.append("removalRules weakestShare is \(removal.weakestShare), not between 0 and 1")
        }
        // The growth a false prospect needs divides by the years left before the target age.
        if !(removal.falseProspectUpToAge < removal.falseProspectTargetAge) {
            found.append("removalRules falseProspectUpToAge (\(removal.falseProspectUpToAge)) is not below "
                + "falseProspectTargetAge (\(removal.falseProspectTargetAge))")
        }
        // A mutual termination's cost is this share of the release cost, rounded to whole pounds.
        let mutualShare = parameters.mutualTerminationShare.value
        if !(mutualShare >= 0 && mutualShare <= 1) {
            found.append("mutualTerminationShare is \(mutualShare), not between 0 and 1")
        }
        // The part-month added to the months left is less than a month.
        let allowance = parameters.contractMonthsAllowance.value
        if !(allowance >= 0 && allowance <= 1) {
            found.append("contractMonthsAllowance is \(allowance), not between 0 and 1")
        }
        // The levels are tried highest first, so a lower level above a higher one is never reached.
        let levels = parameters.removalLevels.value
        if levels.critical < levels.high {
            found.append("removalLevels critical (\(levels.critical)) is below high (\(levels.high))")
        }
        if levels.high < levels.medium {
            found.append("removalLevels high (\(levels.high)) is below medium (\(levels.medium))")
        }
        // The higher wage line is a multiple of the median; the lower is the median itself.
        let highMultiple = parameters.removalWageRules.value.highMultiple
        if !(highMultiple.isFinite && highMultiple >= 1) {
            found.append("removalWageRules highMultiple is \(highMultiple), not a finite number of 1 or more")
        }
        // The suggested importance multiplies a base by these factors and counts days back and ahead.
        let importance = parameters.importanceRules.value
        for (name, base) in [("leagueBase", importance.leagueBase), ("leagueTitleRaceBase", importance.leagueTitleRaceBase),
                             ("leagueMidTableBase", importance.leagueMidTableBase),
                             ("leagueNothingToPlayForBase", importance.leagueNothingToPlayForBase), ("cupBase", importance.cupBase),
                             ("minorCupBase", importance.minorCupBase), ("friendlyBase", importance.friendlyBase),
                             ("unsetBase", importance.unsetBase)] where !base.isFinite {
            found.append("importanceRules \(name) is \(base), not a finite number")
        }
        for (name, factor) in [("muchStrongerFactor", importance.muchStrongerFactor),
                               ("strongerFactor", importance.strongerFactor), ("similarFactor", importance.similarFactor),
                               ("weakerFactor", importance.weakerFactor), ("muchWeakerFactor", importance.muchWeakerFactor),
                               ("unsetOpponentFactor", importance.unsetOpponentFactor),
                               ("crowdedFactor", importance.crowdedFactor), ("restedFactor", importance.restedFactor)]
            where !(factor.isFinite && factor > 0) {
            found.append("importanceRules \(name) is \(factor), not a finite number above 0")
        }
        for step in importance.biggerMatchSteps {
            if step.withinDays < 1 {
                found.append("importanceRules biggerMatchSteps withinDays is \(step.withinDays), not 1 or more")
            }
            if !(step.factor.isFinite && step.factor > 0) {
                found.append("importanceRules biggerMatchSteps factor within \(step.withinDays) days is \(step.factor), "
                    + "not a finite number above 0")
            }
        }
        for (name, line) in [("biggerMatchFrom", importance.biggerMatchFrom), ("highFrom", importance.highFrom),
                             ("mediumFrom", importance.mediumFrom), ("sharpnessBelowScore", importance.sharpnessBelowScore),
                             ("sharpnessBelow", importance.sharpnessBelow)] where !line.isFinite {
            found.append("importanceRules \(name) is \(line), not a finite number")
        }
        if importance.sharpnessBelow.isFinite && !(0...1).contains(importance.sharpnessBelow) {
            found.append("importanceRules sharpnessBelow is \(importance.sharpnessBelow), not between 0 and 1")
        }
        for (name, days) in [("crowdedWindowDays", importance.crowdedWindowDays),
                             ("restedAfterDays", importance.restedAfterDays),
                             ("sharpnessMinDaysToNext", importance.sharpnessMinDaysToNext)] where days < 1 {
            found.append("importanceRules \(name) is \(days), not 1 or more")
        }
        found += GamePlanAdvisor.problems(in: parameters.gamePlanRules.value)
        found += League.problems(in: parameters.leagueStandingRules.value)
        found += Offers.problems(in: parameters.offerRules.value)
        found += WageRange.problems(in: parameters.wageRangeRules.value)
        found += jadednessProblems(in: parameters)
        return found
    }

    private static func jadednessProblems(in parameters: EngineParameters) -> [String] {
        var found: [String] = []
        let rules = parameters.jadednessTrendRules.value
        for (name, count) in [("fewestOwnIntervals", rules.fewestOwnIntervals), ("fewestSharedIntervals", rules.fewestSharedIntervals),
                              ("fewestSharedDays", rules.fewestSharedDays)] where count < 1 {
            found.append("jadednessTrendRules \(name) is \(count), not 1 or more")
        }
        for (name, days) in [("windowDays", rules.windowDays), ("longestGapDays", rules.longestGapDays),
                             ("onCourseDays", rules.onCourseDays), ("keptDays", rules.keptDays),
                             ("passDateWithinDays", rules.passDateWithinDays)] where days < 1 {
            found.append("jadednessTrendRules \(name) is \(days), not 1 or more")
        }
        if !(rules.steadyPerWeek.isFinite && rules.steadyPerWeek >= 0) {
            found.append("jadednessTrendRules steadyPerWeek is \(rules.steadyPerWeek), not a finite number of 0 or more")
        }
        let curve = parameters.conditionRecoveryByJadedness.value.sorted { $0.x < $1.x }
        if curve.isEmpty {
            found.append("conditionRecoveryByJadedness has no points")
        }
        if zip(curve, curve.dropFirst()).contains(where: { $0.1.factor > $0.0.factor }) {
            found.append("conditionRecoveryByJadedness rises with jadedness; condition cannot come back faster when more jaded")
        }
        if curve.contains(where: { !(0...1).contains($0.factor) }) {
            found.append("conditionRecoveryByJadedness has a factor outside 0 to 1")
        }
        let ceiling = parameters.jadednessCeiling.value
        if !(ceiling > parameters.jadednessFloor.value) {
            found.append("jadednessCeiling (\(ceiling)) is not above jadednessFloor (\(parameters.jadednessFloor.value))")
        }
        return found
    }
}
