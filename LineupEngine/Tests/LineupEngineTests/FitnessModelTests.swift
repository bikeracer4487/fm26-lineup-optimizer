import Testing
@testable import LineupEngine

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

    @Test(arguments: [(-500, 1.0), (200, 1.0), (201, 0.9), (400, 0.9), (401, 0.7), (700, 0.7), (701, 0.4), (1000, 0.4)])
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

    @Test func aFullyFitPlayerHasProductOne() {
        let factors = FitnessModel.factors(condition: 1, sharpness: 1, jadedness: 0, parameters: .fm27)
        #expect(abs(factors.product - 1.0) < tolerance)
    }

    @Test func theProductMultipliesTheThreeFactors() {
        let factors = FitnessModel.factors(condition: 0.90, sharpness: 0.75, jadedness: 300, parameters: .fm27)
        #expect(abs(factors.product - 0.94 * 0.92 * 0.90) < tolerance)
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

    @Test func unsortedPointsAreSortedBeforeEvaluation() {
        var parameters = EngineParameters.fm27
        parameters.conditionCurve = Parameter([CurvePoint(x: 1, factor: 1), CurvePoint(x: 0, factor: 0.2)], .derived, source: "test")
        let factors = FitnessModel.factors(condition: 0.5, sharpness: 1, jadedness: 0, parameters: parameters)
        #expect(abs(factors.condition - 0.6) < tolerance)
    }
}
