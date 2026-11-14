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

    @Test func theDepthParametersAreListedWithEvidenceAndSource() {
        let listed = Dictionary(uniqueKeysWithValues: EngineParameters.fm27.all.map { ($0.name, $0) })
        for name in ["depthCoverFamiliarity", "depthSolidFamiliarity", "depthThinBelow"] {
            #expect(listed[name] != nil, "\(name) is not listed")
            #expect(listed[name]?.evidence == .derived)
            #expect(!(listed[name]?.source.isEmpty ?? true), "\(name) has no source")
        }
        #expect(EngineParameters.fm27.depthCoverFamiliarity.value == 10)
        #expect(EngineParameters.fm27.depthSolidFamiliarity.value == 15)
        #expect(EngineParameters.fm27.depthThinBelow.value == 2)
    }

    @Test func theRestParametersAreListedWithEvidenceAndSource() {
        let listed = Dictionary(uniqueKeysWithValues: EngineParameters.fm27.all.map { ($0.name, $0) })
        let expected: [(String, Evidence)] = [("restLimitRules", .carriedOverFM26), ("restWatchShare", .carriedOverFM26),
                                              ("holidayMargin", .derived), ("holidayJadednessRecoveryPerDay", .carriedOverFM26),
                                              ("restConditionEstimateDays", .derived)]
        for (name, evidence) in expected {
            #expect(listed[name]?.evidence == evidence, "\(name)")
            #expect(!(listed[name]?.source.isEmpty ?? true), "\(name) has no source")
        }
        let p = EngineParameters.fm27
        #expect(p.restWatchShare.value == 0.8)
        #expect(p.holidayMargin.value == 200)
        #expect(p.holidayJadednessRecoveryPerDay.value == 50)
        #expect(p.restLimitRules.source.contains("_get_adjusted_fatigue_threshold"))
        #expect(p.restLimitRules.value.lowest == 200 && p.restLimitRules.value.highest == 550)
        #expect(p.restConditionEstimateDays.value == 14)
        #expect(p.restConditionEstimateDays.source == "this design's choice: an estimate is given up to two weeks ahead")
    }

    @Test func aNegativeHolidayMarginIsReported() {
        var q = EngineParameters.fm27
        q.holidayMargin = Parameter(-1, .derived, source: "test")
        #expect(FitnessModel.problems(in: q) == ["holidayMargin is -1, not 0 or more"])
        q.holidayMargin = Parameter(0, .derived, source: "test")
        #expect(FitnessModel.problems(in: q).isEmpty)
    }

    @Test func restLimitBoundsTheWrongWayRoundAreReported() {
        var q = EngineParameters.fm27
        var rules = q.restLimitRules.value
        rules.lowest = 600
        q.restLimitRules = Parameter(rules, .derived, source: "test")
        #expect(FitnessModel.problems(in: q) == ["restLimitRules lowest (600) is above its highest (550)"])
        rules.lowest = 550
        q.restLimitRules = Parameter(rules, .derived, source: "test")
        #expect(FitnessModel.problems(in: q).isEmpty)
    }

    @Test func restLimitAgeBandsOutOfOrderAreReported() {
        var q = EngineParameters.fm27
        var rules = q.restLimitRules.value
        rules.olderFromAge = 32
        q.restLimitRules = Parameter(rules, .derived, source: "test")
        #expect(FitnessModel.problems(in: q) == ["restLimitRules olderFromAge (32) is not below oldestFromAge (32)"])
        rules.olderFromAge = 31
        q.restLimitRules = Parameter(rules, .derived, source: "test")
        #expect(FitnessModel.problems(in: q).isEmpty)
    }

    @Test func aConditionEstimateOfNoDaysIsReported() {
        var q = EngineParameters.fm27
        q.restConditionEstimateDays = Parameter(0, .derived, source: "test")
        #expect(FitnessModel.problems(in: q) == ["restConditionEstimateDays is 0, not 1 or more"])
        q.restConditionEstimateDays = Parameter(1, .derived, source: "test")
        #expect(FitnessModel.problems(in: q).isEmpty)
    }

    @Test func theTrainingParametersAreListedWithEvidenceAndSource() {
        let listed = Dictionary(uniqueKeysWithValues: EngineParameters.fm27.all.map { ($0.name, $0) })
        let expected: [(String, Evidence, String)] = [
            ("learnabilityRules", .carriedOverFM26, "fm_training_advisor.py"),
            ("retrainingMinimumLearnability", .derived, "0.6"),
            ("retrainingMinimumShare", .carriedOverFM26, "docs/Research/lineup-depth-strategy.md"),
            ("retrainingPerPosition", .carriedOverFM26, "fm_training_advisor.py"),
            ("retrainingTransitions", .carriedOverFM26, "POSITION_TRANSITIONS"),
            ("retrainingWeeks", .carriedOverFM26, "RETRAINING_DIFFICULTY"),
            ("retrainingPace", .carriedOverFM26, "ui/api/api_training_advisor.py"),
            ("retrainingStalledAfterWeeks", .derived, "this design's choice"),
        ]
        for (name, evidence, cited) in expected {
            #expect(listed[name]?.evidence == evidence, "\(name)")
            #expect(listed[name]?.source.contains(cited) == true, "\(name) does not cite \(cited)")
        }
        let p = EngineParameters.fm27
        let learn = p.learnabilityRules.value
        #expect([learn.versatilityWeight, learn.ageWeight, learn.professionalismWeight, learn.roomToGrowWeight] == [0.45, 0.25, 0.20, 0.10])
        #expect(learn.lowVersatilityBelow == 10 && learn.lowVersatilityFactor == 0.3)
        #expect(learn.ageSteps == [AgeFactorStep(upTo: 20, factor: 1.0), AgeFactorStep(upTo: 23, factor: 0.95),
                                   AgeFactorStep(upTo: 25, factor: 0.70), AgeFactorStep(upTo: 27, factor: 0.40),
                                   AgeFactorStep(upTo: 29, factor: 0.15)])
        #expect(learn.ageAbove == 0.05 && learn.roomToGrowSpan == 30 && learn.attributeMaximum == 20)
        #expect(p.retrainingMinimumLearnability.value == 0.40)
        #expect(p.retrainingMinimumShare.value == 0.80)
        #expect(p.retrainingPerPosition.value == 2)
        #expect(p.retrainingTransitions.value.fromFamiliarity == 18)
        #expect(p.retrainingTransitions.value.sameGroupDifficulty == .structural)
        #expect(p.retrainingTransitions.value.otherDifficulty == .spatial)
        #expect(p.retrainingTransitions.value.defensiveGroup
                == [.goalkeeper, .defenderLeft, .defenderCentral, .defenderRight, .wingBackLeft, .wingBackRight, .defensiveMidfielder])
        #expect(p.retrainingTransitions.value.attackingGroup == [.attackingMidLeft, .attackingMidCentral, .attackingMidRight, .striker])
        let weeks = p.retrainingWeeks.value
        #expect(weeks.fluid == WeekRange(fewest: 4, most: 8))
        #expect(weeks.structural == WeekRange(fewest: 12, most: 20))
        #expect(weeks.spatial == WeekRange(fewest: 24, most: 36))
        let pace = p.retrainingPace.value
        #expect(pace.ageSteps == [AgeFactorStep(upTo: 21, factor: 1.0), AgeFactorStep(upTo: 26, factor: 1.3),
                                  AgeFactorStep(upTo: 31, factor: 1.6)])
        #expect(pace.ageAbove == 1.9)
        #expect(pace.highVersatilityFrom == 15 && pace.highVersatilityFactor == 0.6)
        #expect(pace.lowVersatilityUpTo == 9 && pace.lowVersatilityFactor == 1.5)
        #expect(pace.headStartSteps == [FamiliarityStep(minimum: 13, factor: 0.5), FamiliarityStep(minimum: 10, factor: 0.7)])
        #expect(pace.minimumWeeks == 4)
        #expect(p.retrainingStalledAfterWeeks.value == 6)
    }

    @Test func anEmptyWeekRangeIsReported() {
        var q = EngineParameters.fm27
        var weeks = q.retrainingWeeks.value
        weeks.structural = WeekRange(fewest: 20, most: 12)
        q.retrainingWeeks = Parameter(weeks, .derived, source: "test")
        #expect(FitnessModel.problems(in: q) == ["retrainingWeeks for structural is 20 to 12, not a range of 0 or more weeks"])
        weeks.structural = WeekRange(fewest: -1, most: 12)
        q.retrainingWeeks = Parameter(weeks, .derived, source: "test")
        #expect(FitnessModel.problems(in: q) == ["retrainingWeeks for structural is -1 to 12, not a range of 0 or more weeks"])
        // A range of one length is allowed.
        weeks.structural = WeekRange(fewest: 12, most: 12)
        q.retrainingWeeks = Parameter(weeks, .derived, source: "test")
        #expect(FitnessModel.problems(in: q).isEmpty)
    }

    @Test func anUnusablePaceFactorIsReported() {
        var q = EngineParameters.fm27
        var pace = q.retrainingPace.value
        pace.ageAbove = .infinity
        pace.lowVersatilityFactor = -1
        pace.headStartSteps = [FamiliarityStep(minimum: 13, factor: .nan), FamiliarityStep(minimum: 10, factor: 0.7)]
        q.retrainingPace = Parameter(pace, .derived, source: "test")
        let found = FitnessModel.problems(in: q)
        #expect(found.contains("retrainingPace age factor above 31 is inf, not a finite number of 0 or more"))
        #expect(found.contains("retrainingPace low Versatility factor is -1.0, not a finite number of 0 or more"))
        #expect(found.contains("retrainingPace head start factor from familiarity 13 is nan, not a finite number of 0 or more"))
        #expect(found.count == 3)
        var r = EngineParameters.fm27
        var other = r.retrainingPace.value
        other.ageSteps = [AgeFactorStep(upTo: 21, factor: -0.5)]
        other.highVersatilityFactor = .nan
        r.retrainingPace = Parameter(other, .derived, source: "test")
        #expect(FitnessModel.problems(in: r) == ["retrainingPace age factor up to 21 is -0.5, not a finite number of 0 or more",
                                                 "retrainingPace high Versatility factor is nan, not a finite number of 0 or more"])
        // Zero is allowed: the minimum number of weeks still applies.
        other.ageSteps = [AgeFactorStep(upTo: 21, factor: 0)]
        other.highVersatilityFactor = 0.6
        r.retrainingPace = Parameter(other, .derived, source: "test")
        #expect(FitnessModel.problems(in: r).isEmpty)
    }

    @Test func learnabilityDivisorsMustBeAboveZero() {
        var q = EngineParameters.fm27
        var rules = q.learnabilityRules.value
        rules.roomToGrowSpan = 0
        rules.attributeMaximum = -20
        q.learnabilityRules = Parameter(rules, .derived, source: "test")
        #expect(FitnessModel.problems(in: q) == ["learnabilityRules roomToGrowSpan is 0.0, not a finite number above 0",
                                                 "learnabilityRules attributeMaximum is -20.0, not a finite number above 0"])
        rules.roomToGrowSpan = 1
        rules.attributeMaximum = 20
        q.learnabilityRules = Parameter(rules, .derived, source: "test")
        #expect(FitnessModel.problems(in: q).isEmpty)
    }

    @Test func restParameterProblemsAreReported() {
        var q = EngineParameters.fm27
        q.restWatchShare = Parameter(1.2, .derived, source: "test")
        q.holidayJadednessRecoveryPerDay = Parameter(0, .derived, source: "test")
        q.jadednessRecoveryPerDay = Parameter(-1, .derived, source: "test")
        let found = FitnessModel.problems(in: q)
        #expect(found.contains("restWatchShare is 1.2, not between 0 and 1"))
        #expect(found.contains("holidayJadednessRecoveryPerDay is 0.0, not a finite number above 0"))
        #expect(found.contains("jadednessRecoveryPerDay is -1.0, not a finite number above 0"))
        var r = EngineParameters.fm27
        r.restWatchShare = Parameter(-0.1, .derived, source: "test")
        #expect(FitnessModel.problems(in: r) == ["restWatchShare is -0.1, not between 0 and 1"])
        // The ends of the range are allowed.
        r.restWatchShare = Parameter(1, .derived, source: "test")
        #expect(FitnessModel.problems(in: r).isEmpty)
    }

    @Test func theRemovalParametersAreListedWithEvidenceAndSource() {
        let listed = Dictionary(uniqueKeysWithValues: EngineParameters.fm27.all.map { ($0.name, $0) })
        let expected: [(String, Evidence, String)] = [
            ("removalRules", .carriedOverFM26, "ui/api/api_player_removal.py"),
            ("removalWageRules", .derived, "median"),
            ("mutualTerminationShare", .carriedOverFM26, "docs/Research/player-management-and-sales.md"),
            ("removalLevels", .carriedOverFM26, "ui/api/api_player_removal.py"),
        ]
        for (name, evidence, cited) in expected {
            #expect(listed[name]?.evidence == evidence, "\(name)")
            #expect(listed[name]?.source.contains(cited) == true, "\(name) does not cite \(cited)")
        }
        let p = EngineParameters.fm27
        let r = p.removalRules.value
        #expect(r.notFullTimePoints == 50)
        #expect([r.firstElevenPoints, r.secondElevenPoints, r.neitherElevenPoints] == [-40, -20, 15])
        #expect(r.weakestShare == 0.30 && r.weakestPoints == 30)
        #expect(r.farBelowAverageShare == 0.85 && r.farBelowAveragePoints == 25 && r.belowAveragePoints == 10)
        #expect(r.contractEndingSoonUpTo == 6 && r.contractEndingSoonPoints == 25)
        #expect(r.contractEndingUpTo == 12 && r.contractEndingPoints == 15)
        #expect(r.consistencyLowBelow == 8 && r.consistencyLowPoints == 25 && r.consistencyFairUpTo == 8 && r.consistencyFairPoints == 15)
        #expect(r.importantMatchesBelow == 8 && r.importantMatchesPoints == 20)
        #expect(r.injuryPronenessAbove == 14 && r.injuryPronenessPoints == 25)
        #expect(r.professionalismLowBelow == 8 && r.professionalismLowPoints == 25)
        #expect(r.professionalismFairUpTo == 9 && r.professionalismFairPoints == 15)
        #expect(r.ambitionBelow == 6 && r.ambitionPoints == 25)
        #expect(r.controversyAbove == 16 && r.controversyPoints == 25)
        #expect(r.temperamentBelow == 8 && r.temperamentPoints == 15)
        #expect(r.falseProspectUpToAge == 20 && r.falseProspectTargetAge == 24 && r.falseProspectRateAbove == 15)
        #expect(r.falseProspectProfessionalismBelow == 14 && r.falseProspectPoints == 35)
        #expect(r.stallingFromAge == 23 && r.stallingUpToAge == 24 && r.stallingRoomBelow == 0.10 && r.stallingPoints == 20)
        #expect(r.prospectUpToAge == 21)
        #expect(r.strongProspectRoomFrom == 0.30 && r.strongProspectPoints == -30)
        #expect(r.prospectRoomFrom == 0.15 && r.prospectPoints == -15)
        #expect(r.mentorFromAge == 30 && r.mentorProfessionalismFrom == 16 && r.mentorDeterminationFrom == 15)
        #expect(r.mentorPoints == -40 && r.lesserMentorPoints == -20)
        #expect(r.noGrowthFromAge == 30 && r.noGrowthRoomBelow == 0.05 && r.noGrowthPoints == 10)
        #expect(r.oldFromAge == 32 && r.oldPoints == 5)
        #expect(r.terminateWithinMonths == 12)
        let l = r.loanReview
        #expect(l.weakestPoints == 30)
        #expect([l.firstElevenPoints, l.secondElevenPoints, l.neitherElevenPoints] == [-30, -15, 20])
        #expect(l.farBelowAveragePoints == 25 && l.belowAveragePoints == 10)
        #expect(l.consistencyLowPoints == 20 && l.importantMatchesPoints == 15 && l.injuryPronenessPoints == 25)
        #expect(l.endEarlyFrom == 50 && l.doNotExtendFrom == 25)
        let w = p.removalWageRules.value
        #expect(w.highMultiple == 1.5 && w.highPoints == 35 && w.abovePoints == 20)
        #expect(p.mutualTerminationShare.value == 0.55)
        let levels = p.removalLevels.value
        #expect(levels.critical == 80 && levels.high == 50 && levels.medium == 30)
    }

    @Test func removalParameterProblemsAreReported() {
        var q = EngineParameters.fm27
        var rules = q.removalRules.value
        rules.weakestShare = -0.1
        rules.falseProspectUpToAge = 24
        q.removalRules = Parameter(rules, .derived, source: "test")
        q.mutualTerminationShare = Parameter(.nan, .derived, source: "test")
        #expect(FitnessModel.problems(in: q) == [
            "removalRules weakestShare is -0.1, not between 0 and 1",
            "removalRules falseProspectUpToAge (24) is not below falseProspectTargetAge (24)",
            "mutualTerminationShare is nan, not between 0 and 1",
        ])
        // The ends of the ranges are allowed, and a false prospect's age may be one below the target age.
        rules.weakestShare = 1
        rules.falseProspectUpToAge = 23
        q.removalRules = Parameter(rules, .derived, source: "test")
        q.mutualTerminationShare = Parameter(0, .derived, source: "test")
        #expect(FitnessModel.problems(in: q).isEmpty)
        q.mutualTerminationShare = Parameter(1.1, .derived, source: "test")
        #expect(FitnessModel.problems(in: q) == ["mutualTerminationShare is 1.1, not between 0 and 1"])
    }
}
