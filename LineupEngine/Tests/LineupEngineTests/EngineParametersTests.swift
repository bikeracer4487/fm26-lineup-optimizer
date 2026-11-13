import Testing
@testable import LineupEngine

@Suite struct EngineParametersTests {
    @Test func everyParameterHasEvidenceAndASource() {
        #expect(EngineParameters.fm27.all.allSatisfy { !$0.source.isEmpty })
    }

    @Test func allListsEveryStoredParameter() {
        // Unfiltered: a stored property that is not a Parameter (no evidence label) fails here.
        let stored = Mirror(reflecting: EngineParameters.fm27).children.count
        #expect(EngineParameters.fm27.all.count == stored)
        #expect(Set(EngineParameters.fm27.all.map(\.name)).count == stored)
    }

    @Test func theEmptyRoleScoreIsCarriedOverFromCalculateRoleScore() {
        let p = EngineParameters.fm27.emptyRoleScore
        #expect(p.value == 50)
        #expect(p.evidence == .carriedOverFM26)
        #expect(p.source.contains("rating_calculator.py") && p.source.contains("calculate_role_score"))
    }

    @Test func fitnessStepsAndFloorCiteTheFilesTheyCameFrom() {
        let p = EngineParameters.fm27
        #expect(p.jadednessSteps.source.contains("scoring_parameters.py"))
        #expect(p.jadednessSteps.source.contains("JADEDNESS_THRESHOLDS") && p.jadednessSteps.source.contains("JADEDNESS_MULTIPLIERS"))
        #expect(p.jadednessAbove.source.contains("scoring_parameters.py") && p.jadednessAbove.source.contains("JADEDNESS_MULTIPLIERS"))
        #expect(p.conditionFloor.source.contains("fm_match_ready_selector.py"))
        #expect(p.conditionFloor.source.contains("docs/Research/physical-condition.md"))
        for source in [p.jadednessSteps.source, p.jadednessAbove.source, p.conditionFloor.source] {
            #expect(!source.contains("rating_calculator.py"), "\(source)")
        }
        #expect([p.jadednessSteps.evidence, p.jadednessAbove.evidence, p.conditionFloor.evidence].allSatisfy { $0 == .carriedOverFM26 })
    }

    @Test func familiarityStepsAreDescendingAndLabelled() {
        let steps = EngineParameters.fm27.familiaritySteps.value
        #expect(steps.map(\.minimum) == steps.map(\.minimum).sorted(by: >))
        #expect(EngineParameters.fm27.familiaritySteps.evidence == .carriedOverFM26)
        #expect(EngineParameters.fm27.familiaritySteps.source.contains("Study 5"))
        #expect(EngineParameters.fm27.outOfPositionBelow.value == 10)
        #expect(EngineParameters.fm27.outOfPositionBelow.evidence == .derived)
    }
}
