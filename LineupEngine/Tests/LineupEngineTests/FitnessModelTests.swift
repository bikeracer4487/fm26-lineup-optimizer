import Testing
@testable import LineupEngine

extension EngineParameters {
    /// The jadedness steps before 21 November 2026 (×0.90 from 201 to 400), for tests that need a factor under 1 on a player
    /// who can still be picked: above 400 a player is left out of every match that is not high importance.
    static var withAMarkDownFrom200: EngineParameters {
        var parameters = EngineParameters.fm27
        parameters.jadednessSteps = Parameter(
            [JadednessStep(upTo: 200, factor: 1.00), JadednessStep(upTo: 400, factor: 0.90), JadednessStep(upTo: 700, factor: 0.70)],
            .derived, source: "test: the steps from before 21 November 2026")
        return parameters
    }
}

@Suite struct FitnessModelTests {
    private let tolerance = 0.0001

    @Test(arguments: [(1.0, 1.0), (0.95, 0.97), (0.90, 0.94), (0.85, 0.88), (0.80, 0.82), (0.70, 0.70), (0.60, 0.58), (0.0, 0.30)])
    func conditionFactor(_ condition: Double, _ expected: Double) {
        let factors = FitnessModel.factors(condition: condition, sharpness: 1, jadedness: -500, parameters: .fm27)
        #expect(abs(factors.condition - expected) < tolerance)
    }

    @Test(arguments: [(1.0, 1.0), (0.75, 0.92), (0.625, 0.85), (0.50, 0.78), (0.35, 0.70), (0.10, 0.70)])
    func sharpnessFactor(_ sharpness: Double, _ expected: Double) {
        let factors = FitnessModel.factors(condition: 1, sharpness: sharpness, jadedness: -500, parameters: .fm27)
        #expect(abs(factors.sharpness - expected) < tolerance)
    }

    @Test(arguments: [(-500, 1.0), (200, 1.0), (201, 1.0), (400, 1.0), (401, 0.7), (700, 0.7), (701, 0.4), (1000, 0.4)])
    func jadednessFactor(_ jadedness: Int, _ expected: Double) {
        let factors = FitnessModel.factors(condition: 1, sharpness: 1, jadedness: jadedness, parameters: .fm27)
        #expect(abs(factors.jadedness - expected) < tolerance)
    }

    @Test func curvesClampBeyondTheirEnds() {
        let high = FitnessModel.factors(condition: 1.2, sharpness: 1.2, jadedness: 0, parameters: .fm27)
        #expect(abs(high.condition - 1.0) < tolerance)
        #expect(abs(high.sharpness - 1.0) < tolerance)
        let low = FitnessModel.factors(condition: -0.5, sharpness: -0.5, jadedness: 0, parameters: .fm27)
        #expect(abs(low.condition - 0.30) < tolerance)
        #expect(abs(low.sharpness - 0.70) < tolerance)
    }

    @Test func aPlayerAt300IsRatedTheSameAsAt100() {
        let at = { FitnessModel.factors(condition: 1, sharpness: 1, jadedness: $0, parameters: .fm27).jadedness }
        #expect(at(100) == 1 && at(300) == 1 && at(400) == 1)
        #expect(at(401) == 0.70 && at(700) == 0.70 && at(701) == 0.40)
    }

    @Test func aFullyFitPlayerHasProductOne() {
        let factors = FitnessModel.factors(condition: 1, sharpness: 1, jadedness: 0, parameters: .fm27)
        #expect(abs(factors.product - 1.0) < tolerance)
    }

    @Test func theProductMultipliesTheThreeFactors() {
        // 450 is above 400, where the factor is 0.70; 300 now costs nothing.
        let factors = FitnessModel.factors(condition: 0.90, sharpness: 0.75, jadedness: 450, parameters: .fm27)
        #expect(abs(factors.product - 0.94 * 0.92 * 0.70) < tolerance)
    }

    @Test func fm27ParametersHaveNoProblems() {
        #expect(FitnessModel.problems(in: .fm27).isEmpty)
    }

    @Test func emptyCurvesAndStepsDoNotTrap() {
        var parameters = EngineParameters.fm27
        parameters.conditionCurve = Parameter([], .derived, source: "test")
        parameters.sharpnessCurve = Parameter([], .derived, source: "test")
        parameters.jadednessSteps = Parameter([], .derived, source: "test")
        let factors = FitnessModel.factors(condition: 0.5, sharpness: 0.5, jadedness: 100, parameters: parameters)
        #expect(factors.condition == 1.0)
        #expect(factors.sharpness == 1.0)
        #expect(factors.jadedness == parameters.jadednessAbove.value)
        #expect(FitnessModel.problems(in: parameters).count == 3)
    }

    @Test func problemsReportUnorderedCurvesAndSteps() {
        var parameters = EngineParameters.fm27
        parameters.conditionCurve = Parameter([CurvePoint(x: 0.5, factor: 0.5), CurvePoint(x: 0.5, factor: 0.6)], .derived, source: "test")
        parameters.jadednessSteps = Parameter([JadednessStep(upTo: 400, factor: 0.9), JadednessStep(upTo: 200, factor: 1)], .derived, source: "test")
        #expect(FitnessModel.problems(in: parameters).count == 2)
    }

    @Test func aSharpnessNeedRangeThatIsEmptyOrReversedIsReported() {
        // The need rule divides by sharpnessNeedFull − sharpnessNeedMost.
        for most in [0.91, 0.95, Double.nan] {
            var parameters = EngineParameters.fm27
            parameters.sharpnessNeedMost = Parameter(most, .derived, source: "test")
            #expect(FitnessModel.problems(in: parameters)
                == ["sharpnessNeedFull (0.91) is not greater than sharpnessNeedMost (\(most))"])
        }
        var below = EngineParameters.fm27
        below.sharpnessNeedMost = Parameter(0.90, .derived, source: "test")
        #expect(FitnessModel.problems(in: below).isEmpty)
    }

    @Test func aFactorThatWouldMakeAnAdjustmentNegativeOrNotFiniteIsReported() {
        for bad in [-0.1, Double.nan, .infinity] {
            func broken(_ change: (inout EngineParameters) -> Void) -> [String] {
                var parameters = EngineParameters.fm27
                change(&parameters)
                return FitnessModel.problems(in: parameters)
            }
            let reason = "is \(bad), not a finite number of 0 or more"
            #expect(broken { $0.fullySharpFactor = Parameter(bad, .derived, source: "test") } == ["fullySharpFactor \(reason)"])
            #expect(broken { $0.shopWindowFactor = Parameter(bad, .derived, source: "test") } == ["shopWindowFactor \(reason)"])
            #expect(broken { $0.retrainingFactorLow = Parameter(bad, .derived, source: "test") } == ["retrainingFactorLow \(reason)"])
            #expect(broken { $0.retrainingFactorMedium = Parameter(bad, .derived, source: "test") } == ["retrainingFactorMedium \(reason)"])
            #expect(broken {
                $0.loanedInFactor = Parameter($0.loanedInFactor.value.merging([.low: bad]) { _, new in new }, .derived, source: "test")
            } == ["loanedInFactor for low \(reason)"])
            #expect(broken {
                let steps = $0.consecutiveStartSteps.value.merging([.striker: [ConsecutiveStartStep(starts: 3, factor: bad)]]) { _, new in new }
                $0.consecutiveStartSteps = Parameter(steps, .derived, source: "test")
            } == ["consecutiveStartSteps for ST (C) at 3 starts \(reason)"])
        }
        // 0 is allowed: it is finite and not negative.
        var zero = EngineParameters.fm27
        zero.fullySharpFactor = Parameter(0, .derived, source: "test")
        #expect(FitnessModel.problems(in: zero).isEmpty)
    }

    @Test func aStrengthOrBonusThatIsNegativeOrNotFiniteIsReported() {
        for bad in [-0.1, Double.nan, -.infinity] {
            func broken(_ change: (inout EngineParameters) -> Void) -> [String] {
                var parameters = EngineParameters.fm27
                change(&parameters)
                return FitnessModel.problems(in: parameters)
            }
            let reason = "is \(bad), not a finite number of 0 or more"
            #expect(broken { $0.sharpnessNeedStrengthLow = Parameter(bad, .derived, source: "test") } == ["sharpnessNeedStrengthLow \(reason)"])
            #expect(broken { $0.sharpnessNeedStrengthBuild = Parameter(bad, .derived, source: "test") } == ["sharpnessNeedStrengthBuild \(reason)"])
            #expect(broken { $0.stabilityAnchorBonus = Parameter(bad, .derived, source: "test") } == ["stabilityAnchorBonus \(reason)"])
            #expect(broken { $0.stabilityRecentBonus = Parameter(bad, .derived, source: "test") } == ["stabilityRecentBonus \(reason)"])
        }
        var zero = EngineParameters.fm27
        zero.stabilityAnchorBonus = Parameter(0, .derived, source: "test")
        #expect(FitnessModel.problems(in: zero).isEmpty)
    }

    @Test func unsortedPointsAreSortedBeforeEvaluation() {
        var parameters = EngineParameters.fm27
        parameters.conditionCurve = Parameter([CurvePoint(x: 1, factor: 1), CurvePoint(x: 0, factor: 0.2)], .derived, source: "test")
        let factors = FitnessModel.factors(condition: 0.5, sharpness: 1, jadedness: 0, parameters: parameters)
        #expect(abs(factors.condition - 0.6) < tolerance)
    }
}

@Suite struct SharpnessBelowCheckTests {
    @Test(arguments: [-0.1, 1.5])
    func aSharpnessLineOutsideZeroToOneIsReported(_ line: Double) {
        var parameters = EngineParameters.fm27
        var rules = parameters.importanceRules.value
        rules.sharpnessBelow = line
        parameters.importanceRules = Parameter(rules, .derived, source: "test")
        #expect(FitnessModel.problems(in: parameters)
                == ["importanceRules sharpnessBelow is \(line), not between 0 and 1"])
    }

    @Test(arguments: [0.0, 0.6, 1.0])
    func aSharpnessLineInsideZeroToOneIsNotReported(_ line: Double) {
        var parameters = EngineParameters.fm27
        var rules = parameters.importanceRules.value
        rules.sharpnessBelow = line
        parameters.importanceRules = Parameter(rules, .derived, source: "test")
        #expect(FitnessModel.problems(in: parameters).isEmpty)
    }
}

@Suite struct LeagueBaseCheckTests {
    @Test(arguments: ["leagueTitleRaceBase", "leagueMidTableBase", "leagueNothingToPlayForBase"])
    func aLeagueBaseThatIsNotFiniteIsReported(_ name: String) {
        var parameters = EngineParameters.fm27
        var rules = parameters.importanceRules.value
        switch name {
        case "leagueTitleRaceBase": rules.leagueTitleRaceBase = .infinity
        case "leagueMidTableBase": rules.leagueMidTableBase = .infinity
        default: rules.leagueNothingToPlayForBase = .infinity
        }
        parameters.importanceRules = Parameter(rules, .derived, source: "test")
        #expect(FitnessModel.problems(in: parameters) == ["importanceRules \(name) is inf, not a finite number"])
    }

    @Test func leagueStandingRuleProblemsAreReported() {
        var q = EngineParameters.fm27
        var r = q.leagueStandingRules.value
        r.marginPoints = -1
        r.battlingFactor = .nan
        r.pointsForWin = 1
        q.leagueStandingRules = Parameter(r, .derived, source: "test")
        #expect(FitnessModel.problems(in: q) == [
            "leagueStandingRules marginPoints is -1, not 0 or more",
            "leagueStandingRules battlingFactor is nan, not a finite number above 0",
            "leagueStandingRules pointsForWin is 1, not over pointsForDraw (1)",
        ])
        var last = EngineParameters.fm27.leagueStandingRules.value
        last.marginPointsLastMatch = 7
        q.leagueStandingRules = Parameter(last, .derived, source: "test")
        #expect(FitnessModel.problems(in: q) == ["leagueStandingRules marginPointsLastMatch is 7, over marginPoints (6)"])
        #expect(FitnessModel.problems(in: .fm27).isEmpty)
    }

    @Test(arguments: ["fewestOwnIntervals", "fewestSharedIntervals", "fewestSharedDays"])
    func aCountOfZeroInTheTrendRulesIsReported(name: String) {
        var q = EngineParameters.fm27
        var r = q.jadednessTrendRules.value
        switch name {
        case "fewestOwnIntervals": r.fewestOwnIntervals = 0
        case "fewestSharedIntervals": r.fewestSharedIntervals = 0
        default: r.fewestSharedDays = 0
        }
        q.jadednessTrendRules = Parameter(r, .derived, source: "test")
        #expect(FitnessModel.problems(in: q) == ["jadednessTrendRules \(name) is 0, not 1 or more"])
    }

    @Test(arguments: ["windowDays", "longestGapDays", "onCourseDays", "keptDays", "passDateWithinDays"])
    func aDayCountOfZeroInTheTrendRulesIsReported(name: String) {
        var q = EngineParameters.fm27
        var r = q.jadednessTrendRules.value
        switch name {
        case "windowDays": r.windowDays = 0
        case "longestGapDays": r.longestGapDays = 0
        case "onCourseDays": r.onCourseDays = 0
        case "keptDays": r.keptDays = 0
        default: r.passDateWithinDays = 0
        }
        q.jadednessTrendRules = Parameter(r, .derived, source: "test")
        #expect(FitnessModel.problems(in: q) == ["jadednessTrendRules \(name) is 0, not 1 or more"])
    }

    @Test func aNegativeSteadyFigureIsReported() {
        var q = EngineParameters.fm27
        var r = q.jadednessTrendRules.value
        r.steadyPerWeek = -1
        q.jadednessTrendRules = Parameter(r, .derived, source: "test")
        #expect(FitnessModel.problems(in: q) == ["jadednessTrendRules steadyPerWeek is -1.0, not a finite number of 0 or more"])
    }

    @Test func theRecoveryCurveByJadednessIsChecked() {
        var q = EngineParameters.fm27
        q.conditionRecoveryByJadedness = Parameter([], .derived, source: "test")
        #expect(FitnessModel.problems(in: q) == ["conditionRecoveryByJadedness has no points"])
        q.conditionRecoveryByJadedness = Parameter(
            [CurvePoint(x: 0, factor: 0.5), CurvePoint(x: 500, factor: 0.8)], .derived, source: "test")
        let rising = FitnessModel.problems(in: q)
        #expect(rising.count == 1)
        #expect(rising.first?.contains("conditionRecoveryByJadedness rises with jadedness") == true)
        q.conditionRecoveryByJadedness = Parameter(
            [CurvePoint(x: 0, factor: 1.5), CurvePoint(x: 500, factor: 0.8)], .derived, source: "test")
        #expect(FitnessModel.problems(in: q) == ["conditionRecoveryByJadedness has a factor outside 0 to 1"])
    }

    @Test func aCeilingNotAboveTheFloorIsReported() {
        var q = EngineParameters.fm27
        q.jadednessCeiling = Parameter(-500, .fm27Observation, source: "test")
        #expect(FitnessModel.problems(in: q) == ["jadednessCeiling (-500.0) is not above jadednessFloor (-500.0)"])
        #expect(FitnessModel.problems(in: .fm27).isEmpty)
    }
}
