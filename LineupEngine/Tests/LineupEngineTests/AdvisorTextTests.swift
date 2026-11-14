import Testing
@testable import LineupEngine

@Suite struct AdvisorTextTests {
    let parameters = EngineParameters.fm27

    @Test func levelsActionsAndVerdicts() {
        #expect(RestLevel.allCases.map { AdvisorText.name($0) } == ["Holiday", "Rest", "Watch"])
        #expect(RemovalLevel.allCases.map { AdvisorText.name($0) } == ["Critical", "High", "Medium", "Keep"])
        #expect(RemovalAction.allCases.map { AdvisorText.name($0) } == ["Release", "Loan out", "Terminate", "Sell", "Monitor", "Keep"])
        #expect(LoanVerdict.allCases.map { AdvisorText.name($0) } == ["End early", "Do not extend", "Keep to the end", "Make permanent"])
        #expect(RetrainingDifficulty.allCases.map { AdvisorText.name($0) } == ["Fluid", "Structural", "Spatial", "Inversion"])
        #expect(Competition.allCases.map { AdvisorText.name($0) } == ["League", "Cup", "Minor cup", "Friendly"])
        #expect(OpponentStrength.allCases.map { AdvisorText.name($0) }
                == ["Much stronger", "Stronger", "Similar", "Weaker", "Much weaker"])
    }

    @Test func evidenceNotes() {
        #expect(AdvisorText.note(for: .fm27Measured) == nil)
        #expect(AdvisorText.note(for: .fm27Official) == nil)
        #expect(AdvisorText.note(for: .fm27Observation) == nil)
        #expect(AdvisorText.note(for: .carriedOverFM26) == "FM26-era numbers")
        #expect(AdvisorText.note(for: .derived) == "this tool's estimate")
    }

    func rest(_ level: RestLevel, days: Int?) -> RestAdvice {
        RestAdvice(player: PlayerID(key: "p"), name: "P", level: level, jadedness: 500, limit: 400, limitNotes: [],
                   condition: 0.9, consecutiveStarts: 3, days: days, reasons: [], basis: .derived)
    }

    @Test func clearIn() {
        #expect(AdvisorText.clear(in: rest(.holiday, days: 3)) == "Clear in about 3 days")
        #expect(AdvisorText.clear(in: rest(.rest, days: 1)) == "Clear in about 1 day")
        #expect(AdvisorText.clear(in: rest(.rest, days: nil)) == "Clear in more days than the estimate covers")
        #expect(AdvisorText.clear(in: rest(.holiday, days: nil)) == "Clear in more days than the estimate covers")
        #expect(AdvisorText.clear(in: rest(.watch, days: nil)) == nil)
    }

    func rest(jadedness: Int, limit: Int, notes: [String] = []) -> RestAdvice {
        RestAdvice(player: PlayerID(key: "p"), name: "P", level: .rest, jadedness: jadedness, limit: limit,
                   limitNotes: notes, condition: 0.9, consecutiveStarts: 0, days: nil, reasons: [], basis: .derived)
    }

    @Test func jadednessAgainstHisLimit() {
        #expect(AdvisorText.jadedness(of: rest(jadedness: 450, limit: 400)) == "450 against a limit of 400")
        #expect(AdvisorText.jadedness(of: rest(jadedness: 0, limit: 300)) == "0 against a limit of 300")
    }

    @Test func aNegativeJadednessIsWrittenWithATrueMinusSign() {
        #expect(AdvisorText.jadedness(of: rest(jadedness: -121, limit: 300)) == "\u{2212}121 against a limit of 300")
    }

    @Test func limitNotesJoinedInTheirOrder() {
        #expect(AdvisorText.limitNotes(of: rest(jadedness: 450, limit: 250, notes: ["aged 32 or over", "Stamina below 10"]))
                == "aged 32 or over, Stamina below 10")
        #expect(AdvisorText.limitNotes(of: rest(jadedness: 450, limit: 350, notes: ["under 19"])) == "under 19")
    }

    @Test func noLimitNotesWhenHisLimitIsTheStandardOne() {
        #expect(AdvisorText.limitNotes(of: rest(jadedness: 450, limit: 400)) == nil)
    }

    func removal(action: RemovalAction = .sell, release: Int?, mutual: Int?) -> RemovalAdvice {
        RemovalAdvice(player: PlayerID(key: "p"), name: "P", level: .high, action: action, score: 10, reasons: [],
                      tier: nil, isProspect: false, isFalseProspect: false, isMentor: false,
                      releaseCost: release, mutualCost: mutual, basis: .derived)
    }

    @Test func costs() {
        #expect(AdvisorText.costs(of: removal(release: 26_000, mutual: 14_300))
                == "Releasing him costs £26,000; a mutual termination about £14,300")
        #expect(AdvisorText.costs(of: removal(release: 0, mutual: 0)) == "Releasing him costs nothing")
        #expect(AdvisorText.costs(of: removal(release: nil, mutual: nil)) == "The cost of releasing him is not known")
    }

    @Test func costsWithOnlyOneKnownAreNotKnown() {
        #expect(AdvisorText.costs(of: removal(release: 26_000, mutual: nil)) == "The cost of releasing him is not known")
        #expect(AdvisorText.costs(of: removal(release: nil, mutual: 14_300)) == "The cost of releasing him is not known")
    }

    @Test func whyEachAction() {
        let advice = removal(release: nil, mutual: nil)
        #expect(AdvisorText.why(.release, for: advice) == "He is out of contract, so releasing him costs nothing")
        #expect(AdvisorText.why(.loan, for: advice) == "A young player with room to grow: a loan gives him matches")
        #expect(AdvisorText.why(.terminate, for: advice)
                == "His contract is nearly over and no fee is likely to beat the cost of ending it")
        #expect(AdvisorText.why(.sell, for: advice) == "Selling is the way left: nothing cheaper applies")
        #expect(AdvisorText.why(.monitor, for: advice) == "Not enough against him to act: watch how he does")
        #expect(AdvisorText.why(.keep, for: advice) == "Nothing here says he should go")
    }

    @Test func aReasonsPointsAreSignedWithATrueMinus() {
        #expect(AdvisorText.points(of: RemovalReason(text: "In neither eleven", points: 25)) == "+25")
        #expect(AdvisorText.points(of: RemovalReason(text: "A model professional", points: -40)) == "\u{2212}40")
        #expect(AdvisorText.points(of: RemovalReason(text: "Contract type", points: 0)) == "0")
    }

    @Test func aScoreHasATrueMinusAndNoPlus() {
        #expect(AdvisorText.score(45) == "45")
        #expect(AdvisorText.score(0) == "0")
        #expect(AdvisorText.score(-12) == "\u{2212}12")
    }

    func depth(cover: Int) -> SlotDepth {
        SlotDepth(slot: .D_L, ipPosition: .defenderLeft, oopPosition: .defenderLeft, options: [], onLoan: [], cover: cover,
                  isThin: cover < 2, dropToNextBest: nil, nextBest: nil)
    }

    @Test func coverWords() {
        #expect(parameters.depthThinBelow.value == 2)
        #expect(AdvisorText.cover(depth(cover: 0), parameters: parameters) == "No solid player; 2 needed")
        #expect(AdvisorText.cover(depth(cover: 1), parameters: parameters) == "1 solid player; 2 needed")
        #expect(AdvisorText.cover(depth(cover: 2), parameters: parameters) == "2 solid players")
        #expect(AdvisorText.cover(depth(cover: 4), parameters: parameters) == "4 solid players")
    }

    @Test func recruitFirstNamesTheThinSlotsInTheirOrder() {
        #expect(AdvisorText.recruitFirst(DepthReport(slots: [], thin: [.GK, .D_L], basis: .derived))
                == "Recruit first: goalkeeper, left back")
        #expect(AdvisorText.recruitFirst(DepthReport(slots: [], thin: [.D_CL], basis: .derived))
                == "Recruit first: left centre-back")
        #expect(AdvisorText.recruitFirst(DepthReport(slots: [], thin: [], basis: .derived)) == nil)
    }

    func stepIn(drop: Double?) -> SlotDepth {
        SlotDepth(slot: .D_L, ipPosition: .defenderLeft, oopPosition: .defenderLeft, options: [], onLoan: [], cover: 1,
                  isThin: true, dropToNextBest: drop, nextBest: drop.map { _ in PlayerID(key: "josh ashby") })
    }

    @Test func nextBestSaysWhoStepsInAndHowFarBelow() {
        #expect(AdvisorText.nextBest(stepIn(drop: 6.66), name: "Josh Ashby") == "Next best: Josh Ashby, 6.7 lower")
        #expect(AdvisorText.nextBest(stepIn(drop: 12), name: "Josh Ashby") == "Next best: Josh Ashby, 12.0 lower")
        #expect(AdvisorText.nextBest(stepIn(drop: -1.24), name: "Josh Ashby") == "Next best: Josh Ashby, 1.2 higher")
        #expect(AdvisorText.nextBest(stepIn(drop: 0.02), name: "Josh Ashby") == "Next best: Josh Ashby, rated the same")
        #expect(AdvisorText.nextBest(stepIn(drop: -0.04), name: "Josh Ashby") == "Next best: Josh Ashby, rated the same")
    }

    @Test func nextBestWithNobodyToStepIn() {
        #expect(AdvisorText.nextBest(stepIn(drop: nil), name: nil) == "Nobody else can step in")
        #expect(AdvisorText.nextBest(stepIn(drop: nil), name: "Josh Ashby") == "Nobody else can step in")
    }

    @Test func alsoNeededNamesTheOtherSlotsInTheOrderGiven() {
        #expect(AdvisorText.alsoNeeded(at: []) == nil)
        #expect(AdvisorText.alsoNeeded(at: [.D_L]) == "Also needed at left back")
        #expect(AdvisorText.alsoNeeded(at: [.D_L, .D_C]) == "Also needed at left back and centre-back")
        #expect(AdvisorText.alsoNeeded(at: [.D_L, .D_C, .ST_C]) == "Also needed at left back, centre-back and striker")
    }

    @Test func nobodyCanPlayOnlyWhereTheSlotHasNoOptions() {
        let option = DepthOption(player: PlayerID(key: "p"), name: "P", squad: .firstTeam, rating: 100, ipFamiliarity: 20,
                                 oopFamiliarity: 20, isSolid: true, unavailable: nil, tier: nil, alsoNeededAt: [],
                                 countsAsCover: true)
        func slot(_ options: [DepthOption]) -> SlotDepth {
            SlotDepth(slot: .GK, ipPosition: .goalkeeper, oopPosition: .goalkeeper, options: options, onLoan: [],
                      cover: options.count, isThin: options.count < 2, dropToNextBest: nil, nextBest: nil)
        }
        #expect(AdvisorText.nobodyCanPlay(slot([])) == "Nobody can play here")
        #expect(AdvisorText.nobodyCanPlay(slot([option])) == nil)
    }

    @Test func whatCoverCountsWithItsEvidenceNoteInsideTheSentence() {
        #expect(AdvisorText.whatCoverCounts(parameters, basis: .derived)
                == "Cover counts players solid in the slot (familiarity 15 or over in both phases), not injured and not first choice elsewhere; fewer than 2 is thin (this tool's estimate).")
        #expect(AdvisorText.whatCoverCounts(parameters, basis: .carriedOverFM26)
                == "Cover counts players solid in the slot (familiarity 15 or over in both phases), not injured and not first choice elsewhere; fewer than 2 is thin (FM26-era numbers).")
        #expect(AdvisorText.whatCoverCounts(parameters, basis: .fm27Measured) == AdvisorText.whatCoverCounts(parameters))
    }

    @Test func whatCoverCounts() {
        #expect(AdvisorText.whatCoverCounts(parameters)
                == "Cover counts players solid in the slot (familiarity 15 or over in both phases), not injured and not first choice elsewhere; fewer than 2 is thin.")
    }

    func progress(_ state: RetrainingProgress.State, start: Int?, latest: Int?, weeks: Double,
                  rate: Double? = nil, toSolid: Int? = nil) -> RetrainingProgress {
        RetrainingProgress(state: state, start: start, latest: latest, weeks: weeks, gainedPerWeek: rate, weeksToSolid: toSolid)
    }

    @Test func progressWords() {
        let p = parameters
        #expect(AdvisorText.progress(progress(.noData, start: nil, latest: nil, weeks: 0), toward: .defenderLeft, parameters: p)
                == "No familiarity recorded yet: it is read at each import")
        #expect(AdvisorText.progress(progress(.improving, start: 8, latest: 11, weeks: 3, rate: 1.0, toSolid: 4),
                                     toward: .defenderLeft, parameters: p)
                == "Familiarity at left back 8 to 11 in 3 weeks: about 1.0 a week, 4 weeks to solid")
        #expect(AdvisorText.progress(progress(.improving, start: 8, latest: 8, weeks: 0.4), toward: .defenderLeft, parameters: p)
                == "Familiarity at left back 8 so far: too early to tell")
        #expect(AdvisorText.progress(progress(.improving, start: 8, latest: 8, weeks: 3, rate: 0), toward: .defenderLeft, parameters: p)
                == "Familiarity at left back 8 so far: too early to tell")
        #expect(AdvisorText.progress(progress(.stalled, start: 9, latest: 9, weeks: 6), toward: .defenderLeft, parameters: p)
                == "Familiarity at left back has not moved from 9 in 6 weeks")
        #expect(AdvisorText.progress(progress(.reached, start: 9, latest: 15, weeks: 6, rate: 1, toSolid: nil),
                                     toward: .defenderLeft, parameters: p)
                == "Solid at left back: familiarity 15")
    }

    @Test func progressRoundsWeeksAndRate() {
        #expect(AdvisorText.progress(progress(.improving, start: 8, latest: 11, weeks: 2.6, rate: 1.153, toSolid: 3),
                                     toward: .striker, parameters: parameters)
                == "Familiarity at striker 8 to 11 in 3 weeks: about 1.2 a week, 3 weeks to solid")
    }

    // MARK: Retraining

    @Test func learnAndLearningNameThePositionInWords() {
        #expect(AdvisorText.learn(.defenderLeft) == "Learn left back")
        #expect(AdvisorText.learn(.defensiveMidfielder) == "Learn defensive midfield")
        #expect(AdvisorText.learning(.defenderLeft) == "Learning left back")
        #expect(AdvisorText.learning(.goalkeeper) == "Learning goalkeeper")
        for position in Position.allCases {
            #expect(AdvisorText.learn(position) == "Learn \(PositionText.plain(position))")
            #expect(!AdvisorText.learn(position).contains("("), "\(position)")
        }
    }

    @Test func aNeedIsItsSlotInWordsThenItsTactic() {
        #expect(AdvisorText.need(RetrainingNeed(tactic: "Sample 4-2-3-1", slot: .D_L)) == "Left back in Sample 4-2-3-1")
        #expect(AdvisorText.need(RetrainingNeed(tactic: "Another", slot: .D_CL)) == "Left centre-back in Another")
        #expect(AdvisorText.need(RetrainingNeed(tactic: "Sample 4-2-3-1", slot: .GK)) == "Goalkeeper in Sample 4-2-3-1")
    }

    @Test func coversNamesEachNeedInItsOrder() {
        let a = RetrainingNeed(tactic: "Sample 4-2-3-1", slot: .D_L)
        let b = RetrainingNeed(tactic: "Another", slot: .D_CL)
        let c = RetrainingNeed(tactic: "Third", slot: .WB_L)
        #expect(AdvisorText.covers([]) == nil)
        #expect(AdvisorText.covers([a]) == "Covers left back in Sample 4-2-3-1")
        #expect(AdvisorText.covers([a, b]) == "Covers left back in Sample 4-2-3-1 and left centre-back in Another")
        #expect(AdvisorText.covers([b, a]) == "Covers left centre-back in Another and left back in Sample 4-2-3-1")
        #expect(AdvisorText.covers([a, b, c])
                == "Covers left back in Sample 4-2-3-1, left centre-back in Another and left wing-back in Third")
        // The same need twice is named once.
        #expect(AdvisorText.covers([a, a]) == "Covers left back in Sample 4-2-3-1")
    }

    @Test func alreadyBeingRetrainedNamesTheNeedsOrNothing() {
        let a = RetrainingNeed(tactic: "Sample 4-2-3-1", slot: .D_L)
        let b = RetrainingNeed(tactic: "Another", slot: .GK)
        #expect(AdvisorText.alreadyBeingRetrained([]) == nil)
        #expect(AdvisorText.alreadyBeingRetrained([a]) == "Already being retrained for: left back in Sample 4-2-3-1")
        #expect(AdvisorText.alreadyBeingRetrained([a, b])
                == "Already being retrained for: left back in Sample 4-2-3-1 and goalkeeper in Another")
    }

    @Test func whatAcceptingAndTurningDownSay() {
        #expect(AdvisorText.nowLearning(name: "Keegan Bloom", position: .defenderLeft)
                == "Keegan Bloom is now learning left back. Set it up in the game as well.")
        #expect(AdvisorText.nowLearning(name: "Alice Archer", position: .goalkeeper)
                == "Alice Archer is now learning goalkeeper. Set it up in the game as well.")
        #expect(AdvisorText.notOfferedAgain(name: "Ewan Clark", position: .defenderLeft)
                == "Ewan Clark will not be offered left back again.")
        #expect(AdvisorText.notOfferedAgain(name: "Ewan Clark", position: .midfielderLeft)
                == "Ewan Clark will not be offered left midfield again.")
    }

    @Test func aRealRecommendationsWordsHaveNoCodes() throws {
        // The planner squad without its second-choice left back, so left back is thin, and a right back to learn it.
        let players = try PlannerFixture.squad().filter { $0.name != PlannerFixture.name(.D_L, "second") } + [
            Player.fixture(name: "Right Back", age: 20, all: 13, attributes: [.versatility: 14, .professionalism: 12],
                           familiarity: [.defenderRight: 20, .defenderLeft: 8], currentAbility: 100,
                           potentialAbility: 120, club: "Oxford City")]
        let report = try Training.report(tactics: [try PlannerFixture.tactic()], players: players, ownClub: "Oxford City",
                                         accepted: [], rejected: [], catalog: try RoleCatalog.fm27(),
                                         profile: try RatingProfile.standard(), parameters: parameters)
        let recommendation = try #require(report.recommendations.first { $0.name == "Right Back" })
        #expect(AdvisorText.learn(recommendation.choice.position) == "Learn left back")
        #expect(AdvisorText.covers(recommendation.needs) == "Covers left back in Sample 4-2-3-1")
        for sentence in [AdvisorText.learn(recommendation.choice.position), AdvisorText.covers(recommendation.needs) ?? ""]
            + recommendation.needs.map(AdvisorText.need) {
            for code in ["(", "_", "D L", "D_L"] {
                #expect(!sentence.contains(code), "\(sentence)")
            }
        }
    }

    @Test func aReasonNamesThePositionInWords() throws {
        // A real Player Removal reason for the planner squad's first-choice left back.
        let players = try PlannerFixture.squad()
        let report = try Removal.report(tactic: try PlannerFixture.tactic(), players: players, ownClub: "Oxford City",
                                        catalog: try RoleCatalog.fm27(), profile: try RatingProfile.standard(),
                                        parameters: parameters)
        let advice = try #require(report.advice.first { $0.player == PlannerFixture.id(.D_L, "first") })
        let sentence = try #require(advice.reasons.map(\.text).first { $0.hasPrefix("In the first eleven") })
        #expect(sentence == "In the first eleven at left back")
        for code in [Position.defenderLeft.rawValue, Position.defenderLeft.tableKey, SlotID.D_L.rawValue, "D L", "("] {
            #expect(!sentence.contains(code), "\(code)")
        }
    }
}
