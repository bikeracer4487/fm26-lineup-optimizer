import Testing
@testable import LineupEngine

@Suite struct EngineParametersTests {
    @Test func everyParameterHasEvidenceAndASource() {
        #expect(EngineParameters.fm27.all.allSatisfy { !$0.source.isEmpty })
        #expect(EngineParameters.fm27.all.count >= 13)
    }

    @Test func allListsEveryStoredParameter() {
        // Unfiltered: a stored property that is not a Parameter (no evidence label) fails here.
        let stored = Mirror(reflecting: EngineParameters.fm27).children.count
        #expect(EngineParameters.fm27.all.count == stored)
        #expect(Set(EngineParameters.fm27.all.map(\.name)).count == stored)
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
