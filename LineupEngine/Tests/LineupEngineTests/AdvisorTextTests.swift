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
