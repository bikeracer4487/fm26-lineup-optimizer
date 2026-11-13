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

    @Test func theProfileNumbersAreNotEngineParameters() {
        // The shares and the key and preferable weights belong to a rating profile.
        let names = Set(EngineParameters.fm27.all.map(\.name))
        for moved in ["positionShare", "roleShare", "consensusShare", "keyWeight", "preferableWeight"] {
            #expect(!names.contains(moved), "\(moved)")
        }
        for kept in ["consensusCap", "balanceBonus", "thresholdPenaltyPerPoint", "thresholdPenaltyFloor", "emptyRoleScore",
                     "familiaritySteps", "defensivePhaseWeightIP", "otherPhaseWeightIP"] {
            #expect(names.contains(kept), "\(kept)")
        }
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
        #expect(p.conditionFloor.source.contains("docs/Research/physical-condition-claude.md"))
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

    @Test func theProjectionParametersHaveNoProblems() {
        #expect(FitnessModel.problems(in: .fm27).isEmpty)
    }

    @Test func projectionProblemsAreReported() {
        var q = EngineParameters.fm27
        var load = q.positionConditionLoad.value
        load[.striker] = nil
        q.positionConditionLoad = Parameter(load, .derived, source: "test")
        q.conditionRecoveryPerDay = Parameter([], .derived, source: "test")
        q.sharpnessGainTaper = Parameter([], .derived, source: "test")
        q.trainingIntensityRecovery = Parameter([.low: 1.2, .medium: 1.0], .derived, source: "test")
        let found = FitnessModel.problems(in: q)
        #expect(found.contains { $0.contains("positionConditionLoad") && $0.contains("ST (C)") })
        #expect(found.contains { $0.contains("conditionRecoveryPerDay is empty") })
        #expect(found.contains { $0.contains("sharpnessGainTaper is empty") })
        #expect(found.contains { $0.contains("trainingIntensityRecovery") && $0.contains("high") })
    }

    @Test func theImportanceRuleParametersAreListedWithEvidenceAndSource() {
        let listed = Dictionary(uniqueKeysWithValues: EngineParameters.fm27.all.map { ($0.name, $0) })
        let names = ["loanedInFactor", "consecutiveStartSteps", "sharpnessNeedFull", "sharpnessNeedMost", "sharpnessNeedStrengthLow",
                     "sharpnessNeedStrengthBuild", "fullySharpFactor", "prospectMaxAge", "prospectHeadroom", "developmentFactor",
                     "retrainingFromFamiliarity", "retrainingFromFamiliarityMedium", "retrainingUntilFamiliarity",
                     "retrainingFactorLow", "retrainingFactorMedium", "stabilityAnchorRun", "stabilityAnchorBonus", "stabilityRecentBonus"]
        for name in names {
            #expect(listed[name] != nil, "\(name) is not listed")
            #expect(!(listed[name]?.source.isEmpty ?? true), "\(name) has no source")
        }
        #expect(listed["sharpnessNeedMost"]?.evidence == .derived)
        #expect(listed["loanedInFactor"]?.evidence == .carriedOverFM26)
    }
}
