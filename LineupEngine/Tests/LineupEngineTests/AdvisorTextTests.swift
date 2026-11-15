import Testing
@testable import LineupEngine

@Suite struct AdvisorTextTests {
    let parameters = EngineParameters.fm27

    @Test func levelsActionsAndVerdicts() {
        #expect(RestLevel.allCases.map { AdvisorText.name($0) } == ["Holiday", "Rest", "Watch"])
        #expect(RemovalLevel.allCases.map { AdvisorText.name($0) } == ["Critical", "High", "Medium", "Keep"])
        #expect(RemovalAction.allCases.map { AdvisorText.name($0) }
                == ["Release", "Terminate", "Sell", "Monitor", "Keep and develop", "Keep and play", "Loan for matches", "Keep"])
        #expect(LoanVerdict.allCases.map { AdvisorText.name($0) } == ["End early", "Do not extend", "Keep to the end", "Make permanent"])
        #expect(RetrainingDifficulty.allCases.map { AdvisorText.name($0) } == ["Fluid", "Structural", "Spatial", "Inversion"])
        #expect(Competition.allCases.map { AdvisorText.name($0) } == ["League", "Cup", "Minor cup", "Friendly"])
        #expect(OpponentStrength.allCases.map { AdvisorText.name($0) }
                == ["Much stronger", "Stronger", "Similar", "Weaker", "Much weaker"])
    }

    @Test func theMarksHaveTheirNamesAndTheNoteSaysItIsUntested() {
        #expect(AdvisorText.name(SaleMark.toSell) == "To sell")
        #expect(AdvisorText.name(SaleMark.toLoanOut) == "To loan out")
        #expect(AdvisorText.marksNote == "A marked player gets a little more playing time in low-importance and "
                + "sharpness fixtures. Whether playing a player brings offers has not been tested.")
    }

    @Test func eachImportanceHasItsName() {
        #expect(Importance.allCases.map { AdvisorText.name($0) } == ["High", "Medium", "Low", "Sharpness"])
    }

    @Test func aSuggestionNamesItsImportance() {
        func suggestion(_ importance: Importance) -> ImportanceSuggestion {
            ImportanceSuggestion(importance: importance, score: 6, reasons: ["League match: 6"], basis: .derived)
        }
        #expect(AdvisorText.suggested(suggestion(.high)) == "Suggested: High")
        #expect(AdvisorText.suggested(suggestion(.sharpness)) == "Suggested: Sharpness")
        #expect(Importance.allCases.map { AdvisorText.suggested(suggestion($0)) }
                == Importance.allCases.map { "Suggested: \(AdvisorText.name($0))" })
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

    func removal(action: RemovalAction = .sell, release: Int?, mutual: Int?, matchesHere: MatchesHere? = nil,
                 keepReason: KeepReason? = nil, watchReason: WatchReason? = nil, loanOnlyToStart: Bool = false,
                 onYouthContract: Bool = false) -> RemovalAdvice {
        RemovalAdvice(player: PlayerID(key: "p"), name: "P", level: .high, action: action, score: 10, reasons: [],
                      tier: nil, outlook: nil, matchesHere: matchesHere, keepReason: keepReason, watchReason: watchReason,
                      loanOnlyToStart: loanOnlyToStart, onYouthContract: onYouthContract, isFalseProspect: false,
                      isMentor: false, releaseCost: release, mutualCost: mutual, basis: .derived)
    }

    @Test func costs() {
        #expect(AdvisorText.costs(of: removal(release: 24_700, mutual: 13_585), money: .weeklyPounds)
                == "Releasing him costs about £24,700; a mutual termination about £13,585")
        #expect(AdvisorText.costs(of: removal(release: 0, mutual: 0), money: .weeklyPounds) == "Releasing him costs nothing")
        #expect(AdvisorText.costs(of: removal(release: nil, mutual: nil), money: .weeklyPounds)
                == "The cost of releasing him is not known")
    }

    @Test func costsTakeTheSymbolOfTheSquads() {
        let dollars = MoneyStyle(symbol: "$", period: .monthly)
        #expect(AdvisorText.costs(of: removal(release: 33_222, mutual: 18_272), money: dollars)
                == "Releasing him costs about $33,222; a mutual termination about $18,272")
        #expect(AdvisorText.costs(of: removal(release: 0, mutual: 0), money: dollars) == "Releasing him costs nothing")
    }

    @Test func costsWithOnlyOneKnownAreNotKnown() {
        #expect(AdvisorText.costs(of: removal(release: 26_000, mutual: nil), money: .weeklyPounds)
                == "The cost of releasing him is not known")
        #expect(AdvisorText.costs(of: removal(release: nil, mutual: 14_300), money: .weeklyPounds)
                == "The cost of releasing him is not known")
    }

    @Test func whyEachAction() {
        let advice = removal(release: nil, mutual: nil)
        #expect(AdvisorText.why(.release, for: advice) == "He is out of contract, so releasing him costs nothing")
        // The contract decides, not the cost.
        for (release, mutual) in [(Int?.none, Int?.none), (0, 0), (24_700, 13_585)] {
            #expect(AdvisorText.why(.release, for: removal(release: release, mutual: mutual, onYouthContract: true))
                    == "He is on a youth contract, so he cannot be sold or loaned out: releasing him is the only way to "
                        + "move him on")
        }
        #expect(AdvisorText.why(.terminate, for: advice)
                == "His contract is nearly over and no fee is likely to beat the cost of ending it")
        #expect(AdvisorText.why(.sell, for: advice) == "Selling is the way left: nothing cheaper applies")
        #expect(AdvisorText.why(.monitor, for: advice) == "Not enough against him to act: watch how he does")
        #expect(AdvisorText.why(.keep, for: advice) == "Nothing here says he should go")
    }

    @Test func whyAYoungPlayerIsKeptPlayedOrLoaned() {
        func why(_ action: RemovalAction, _ keepReason: KeepReason? = nil, loanOnlyToStart: Bool = false) -> String {
            AdvisorText.why(action, for: removal(action: action, release: nil, mutual: nil, keepReason: keepReason,
                                                 loanOnlyToStart: loanOnlyToStart))
        }
        #expect(why(.develop, .age) == "At his age he grows mainly in training; a loan would add little.")
        #expect(why(.develop, .youthContract)
                == "He is not getting matches here, and a loan needs a full-time contract.")
        #expect(why(.develop, .shortContract) == "He is not getting matches here: renew his contract before a loan.")
        #expect(why(.develop) == "He is worth developing here.")
        func play(_ basis: MatchesHereBasis) -> String {
            AdvisorText.why(.play, for: removal(action: .play, release: nil, mutual: nil,
                                                matchesHere: MatchesHere(starts: 0, matches: 0, basis: basis)))
        }
        #expect(play(.firstChoice) == "He is first choice here.")
        #expect(play(.startedEnough) == "He is getting his matches here.")
        #expect(play(.solidSecondChoice) == "He is second choice here, and too few matches are confirmed to count his starts.")
        #expect(why(.loanForMatches)
                == "He is worth developing and is not getting matches here: a loan gives him matches.")
        #expect(why(.loanForMatches, loanOnlyToStart: true)
                == "He is worth developing and is not getting matches here: a loan gives him matches. "
                    + "Only where he will start regularly; otherwise he grows nearly as well here.")
    }

    @Test func whenHisStartsWereNotCountedTheWhySaysSo() {
        func why(_ action: RemovalAction, _ keepReason: KeepReason? = nil, _ basis: MatchesHereBasis,
                 loanOnlyToStart: Bool = false) -> String {
            AdvisorText.why(action, for: removal(action: action, release: nil, mutual: nil,
                                                 matchesHere: MatchesHere(starts: 1, matches: 2, basis: basis),
                                                 keepReason: keepReason, loanOnlyToStart: loanOnlyToStart))
        }
        // Too few matches confirmed: his starts were not counted.
        #expect(why(.develop, .youthContract, .tooFewConfirmed)
                == "He has no solid place in the first or second eleven, and a loan needs a full-time contract. "
                    + "Too few matches are confirmed to count his starts.")
        #expect(why(.develop, .shortContract, .tooFewConfirmed)
                == "He has no solid place in the first or second eleven: renew his contract before a loan. "
                    + "Too few matches are confirmed to count his starts.")
        #expect(why(.loanForMatches, nil, .tooFewConfirmed)
                == "He is worth developing and has no solid place in the first or second eleven: a loan gives him "
                    + "matches. Too few matches are confirmed to count his starts.")
        #expect(why(.loanForMatches, nil, .tooFewConfirmed, loanOnlyToStart: true)
                == "He is worth developing and has no solid place in the first or second eleven: a loan gives him "
                    + "matches. Too few matches are confirmed to count his starts. "
                    + "Only where he will start regularly; otherwise he grows nearly as well here.")
        // Counted, and he started too few: today's sentences.
        #expect(why(.develop, .youthContract, .startedTooFew)
                == "He is not getting matches here, and a loan needs a full-time contract.")
        #expect(why(.develop, .shortContract, .startedTooFew)
                == "He is not getting matches here: renew his contract before a loan.")
        #expect(why(.loanForMatches, nil, .startedTooFew)
                == "He is worth developing and is not getting matches here: a loan gives him matches.")
        #expect(why(.loanForMatches, nil, .startedTooFew, loanOnlyToStart: true)
                == "He is worth developing and is not getting matches here: a loan gives him matches. "
                    + "Only where he will start regularly; otherwise he grows nearly as well here.")
        // At his age the matches do not come into it.
        #expect(why(.develop, .age, .tooFewConfirmed) == "At his age he grows mainly in training; a loan would add little.")
    }

    @Test func whyAYoungPlayerIsWatched() {
        func why(_ reason: WatchReason?) -> String {
            AdvisorText.why(.monitor, for: removal(action: .monitor, release: nil, mutual: nil, watchReason: reason))
        }
        #expect(why(.neededForCover) == "He is needed as cover here, so a loan would leave the squad short.")
        #expect(why(nil) == "Not enough against him to act: watch how he does")
    }

    /// Why a young player at `level` (best at `slot`, or compared with the average when nil) is watched for `reason`.
    func whyWatched(_ reason: WatchReason, _ level: ReachLevel?, at slot: SlotID? = .D_L) -> String {
        let watched = RemovalAdvice(
            player: PlayerID(key: "young"), name: "Young", level: .keep, action: .monitor, score: 0, reasons: [],
            tier: nil, outlook: outlook(level, at: slot), matchesHere: MatchesHere(starts: 0, matches: 6, basis: .startedTooFew),
            keepReason: nil, watchReason: reason, loanOnlyToStart: false, onYouthContract: false,
            isFalseProspect: false, isMentor: false, releaseCost: nil, mutualCost: nil, basis: .derived)
        return AdvisorText.why(.monitor, for: watched)
    }

    @Test func whyAYoungPlayerKeptToPlayFollowsHisLevel() {
        func why(_ basis: MatchesHereBasis, _ level: ReachLevel?) -> String {
            let playing = RemovalAdvice(
                player: PlayerID(key: "young"), name: "Young", level: .keep, action: .play, score: 0, reasons: [],
                tier: nil, outlook: outlook(level), matchesHere: MatchesHere(starts: 3, matches: 6, basis: basis),
                keepReason: nil, watchReason: nil, loanOnlyToStart: false, onYouthContract: false,
                isFalseProspect: false, isMentor: false, releaseCost: nil, mutualCost: nil, basis: .derived)
            return AdvisorText.why(.play, for: playing)
        }
        let cases: [(MatchesHereBasis, String)] = [
            (.firstChoice, "He is first choice here."),
            (.startedEnough, "He is getting his matches here."),
            (.solidSecondChoice, "He is second choice here, and too few matches are confirmed to count his starts."),
        ]
        for (basis, sentence) in cases {
            // Worth developing, or with no level: as before.
            for level in [ReachLevel.couldPassFirst, .couldMakeSecond, nil] {
                #expect(why(basis, level) == sentence, "\(basis) \(String(describing: level))")
            }
            // Not worth developing: told why he keeps the place.
            for level in [ReachLevel.couldBeCover, .markedlyLower] {
                #expect(why(basis, level) == sentence + " He keeps the place until the squad has someone better there.",
                        "\(basis) \(level)")
            }
        }
    }

    @Test func whyAYoungPlayerNeededForCoverIsWatchedFollowsHisLevel() {
        let loan = "He is needed as cover here, so a loan would leave the squad short."
        let stays = "He is needed as cover here: he stays until the squad has someone better there."
        // Worth developing, or with no level: a loan would leave the squad short.
        for level in [ReachLevel.couldPassFirst, .couldMakeSecond, nil] {
            #expect(whyWatched(.neededForCover, level) == loan, "\(String(describing: level))")
        }
        // Not worth developing: never considered for a loan, so the sentence does not speak of one.
        for level in [ReachLevel.couldBeCover, .markedlyLower] {
            #expect(whyWatched(.neededForCover, level) == stays, "\(level)")
            #expect(whyWatched(.neededForCover, level, at: nil) == stays, "\(level)")
        }
    }

    @Test func whyAYoungPlayerNotWorthDevelopingIsWatchedFollowsHisLevel() {
        func why(_ level: ReachLevel?, at slot: SlotID? = .D_L) -> String { whyWatched(.notWorthDeveloping, level, at: slot) }
        #expect(why(.couldBeCover) == "This tool expects him to become cover at best: watch how he does.")
        #expect(why(.markedlyLower) == "This tool does not expect him to reach the level of the squad: watch how he does.")
        // Compared with the first team's average, the same sentences.
        #expect(why(.couldBeCover, at: nil) == "This tool expects him to become cover at best: watch how he does.")
        #expect(why(.markedlyLower, at: nil)
                == "This tool does not expect him to reach the level of the squad: watch how he does.")
        // Player Removal watches only a player at those two levels for this reason; built otherwise, said plainly.
        for level in [ReachLevel.couldPassFirst, .couldMakeSecond, nil] {
            #expect(why(level) == "Not enough against him to act: watch how he does", "\(String(describing: level))")
        }
    }

    @Test func aYouthContractCannotBeMarked() {
        #expect(AdvisorText.youthContractNotMarked == "A player on a youth contract cannot be sold or loaned out, only released.")
    }

    // MARK: Development

    /// A young player's outlook at `level`: best at `slot` behind Smith, or with no slot and compared with the first
    /// team's average when `slot` is nil.
    func outlook(_ level: ReachLevel?, at slot: SlotID? = .D_L) -> Outlook {
        let estimate = ReachEstimate(age: 19, current: 80, potential: 120, professionalism: 15, ambition: 10,
                                     determination: 10, seasonGrowth: 10, bySeason: [80, 90, 100, 110, 120],
                                     reachesPotential: true, ambitionSlows: false, determinationSlows: false,
                                     professionalismHoldsBack: false)
        let best = slot.map { slot in
            SlotOutlook(slot: slot, rating: 50, reachRating: 75, isFirstChoice: false,
                        firstChoice: Rival(player: PlayerID(key: "smith"), name: "Smith", age: 28, rating: 70, compared: 70,
                                           isAgeNamed: false),
                        secondChoice: nil, band: .onCourse, pointsNeeded: 32, level: level)
        }
        return Outlook(player: PlayerID(key: "young"), estimate: estimate, slots: best.map { [$0] } ?? [], best: best,
                       level: level, average: slot == nil ? 100 : nil)
    }

    @Test func aReachLineForEachLevelNamesHisBestSlot() {
        let names: (SlotID) -> String = { PositionText.plain($0.position) }
        #expect(AdvisorText.reachLine(outlook(.couldPassFirst), names: names) == "Could pass Smith at left back")
        #expect(AdvisorText.reachLine(outlook(.couldMakeSecond), names: names) == "Could make the second eleven at left back")
        #expect(AdvisorText.reachLine(outlook(.couldBeCover), names: names) == "Could become cover at left back, no more")
        #expect(AdvisorText.reachLine(outlook(.markedlyLower), names: names)
                == "Not expected to reach the level of the squad at any position")
        // The slot is named by the function handed in, and it is the best slot's.
        #expect(AdvisorText.reachLine(outlook(.couldPassFirst, at: .AM_L), names: names)
                == "Could pass Smith at left attacking midfield")
        #expect(AdvisorText.reachLine(outlook(.couldMakeSecond), names: { _ in "the wing" })
                == "Could make the second eleven at the wing")
    }

    @Test func withNoSlotTheReachLineComparesWithTheFirstTeam() {
        let names: (SlotID) -> String = { PositionText.plain($0.position) }
        #expect(AdvisorText.reachLine(outlook(.couldMakeSecond, at: nil), names: names)
                == "Could reach the level of the first team")
        #expect(AdvisorText.reachLine(outlook(.couldBeCover, at: nil), names: names)
                == "Could come close to the level of the first team, no more")
        #expect(AdvisorText.reachLine(outlook(.markedlyLower, at: nil), names: names)
                == "Not expected to reach the level of the first team")
    }

    @Test func anOutlookWithNoLevelHasNoReachLine() {
        #expect(AdvisorText.reachLine(outlook(nil), names: { PositionText.plain($0.position) }) == nil)
        #expect(AdvisorText.reachLine(outlook(nil, at: nil), names: { PositionText.plain($0.position) }) == nil)
    }

    /// An estimate as `Reach.estimate` would give it under the fm27 parameters, with `bySeason` running from `current`
    /// to `reach`: a value under 10 slows growth or holds him back.
    func estimate(age: Int, current: Int, potential: Int, professionalism: Int, ambition: Int = 10,
                  determination: Int = 10, seasonGrowth: Double, reach: Double, reachesPotential: Bool) -> ReachEstimate {
        ReachEstimate(age: age, current: current, potential: potential, professionalism: professionalism,
                      ambition: ambition, determination: determination, seasonGrowth: seasonGrowth,
                      bySeason: [Double(current), reach], reachesPotential: reachesPotential,
                      ambitionSlows: ambition < 10, determinationSlows: determination < 10,
                      professionalismHoldsBack: professionalism < 10)
    }

    @Test func theReachWorkingForEachEnding() {
        // The design's first worked player: his reach is his potential.
        #expect(AdvisorText.reachWorking(estimate(age: 16, current: 55, potential: 140, professionalism: 15,
                                                  seasonGrowth: 13.3, reach: 140, reachesPotential: true))
                == "Ability 55, potential 140. At 16 with Professionalism 15 this tool expects about 13 points a season "
                    + "now, fewer later: could reach his potential.")
        // The second: Professionalism under 10, and Ambition 4 named after it.
        #expect(AdvisorText.reachWorking(estimate(age: 16, current: 40, potential: 130, professionalism: 3, ambition: 4,
                                                  seasonGrowth: 3.2, reach: 66.9, reachesPotential: false))
                == "Ability 40, potential 130. At 16 with Professionalism 3 and Ambition 4 this tool expects about 3 points "
                    + "a season now, fewer later: could reach about 67. At his Professionalism this tool expects about 3 "
                    + "points a season; mentoring could change that.")
        // Short of his potential at Professionalism 10 or over.
        #expect(AdvisorText.reachWorking(estimate(age: 21, current: 70, potential: 130, professionalism: 12,
                                                  seasonGrowth: 6.4, reach: 95.6, reachesPotential: false))
                == "Ability 70, potential 130. At 21 with Professionalism 12 this tool expects about 6 points a season "
                    + "now, fewer later: could reach about 96.")
        // Less than a season's growth to his potential.
        #expect(AdvisorText.reachWorking(estimate(age: 20, current: 130, potential: 135, professionalism: 15,
                                                  seasonGrowth: 10.4, reach: 135, reachesPotential: true))
                == "Ability 130, potential 135. At 20 with Professionalism 15 this tool expects about 10 points a season "
                    + "now, fewer later. His potential is the limit.")
        // Past the last growth step.
        #expect(AdvisorText.reachWorking(ReachEstimate(age: 27, current: 90, potential: 95, professionalism: 15,
                                                       ambition: 10, determination: 10, seasonGrowth: 0, bySeason: [90],
                                                       reachesPotential: false, ambitionSlows: false,
                                                       determinationSlows: false, professionalismHoldsBack: false))
                == "Ability 90, potential 95. At 27 this tool expects no more growth.")
    }

    @Test func theReachWorkingNamesAWeakAmbitionAndDetermination() {
        func working(ambition: Int, determination: Int) -> String {
            AdvisorText.reachWorking(estimate(age: 19, current: 80, potential: 150, professionalism: 15, ambition: ambition,
                                              determination: determination, seasonGrowth: 7.6, reach: 140,
                                              reachesPotential: false))
        }
        #expect(working(ambition: 10, determination: 9)
                == "Ability 80, potential 150. At 19 with Professionalism 15 and Determination 9 this tool expects about 8 "
                    + "points a season now, fewer later: could reach about 140.")
        #expect(working(ambition: 4, determination: 6)
                == "Ability 80, potential 150. At 19 with Professionalism 15, Ambition 4 and Determination 6 this tool "
                    + "expects about 8 points a season now, fewer later: could reach about 140.")
        #expect(working(ambition: 10, determination: 10)
                == "Ability 80, potential 150. At 19 with Professionalism 15 this tool expects about 8 points a season "
                    + "now, fewer later: could reach about 140.")
    }

    @Test func theReachWorkingSaysOnePoint() {
        #expect(AdvisorText.reachWorking(estimate(age: 22, current: 60, potential: 120, professionalism: 1, ambition: 1,
                                                  determination: 1, seasonGrowth: 0.8, reach: 64.8, reachesPotential: false))
                == "Ability 60, potential 120. At 22 with Professionalism 1, Ambition 1 and Determination 1 this tool "
                    + "expects about 1 point a season now, fewer later: could reach about 65. At his Professionalism this "
                    + "tool expects about 1 point a season; mentoring could change that.")
    }

    /// An outlook whose best slot is left back behind `smith`, needing `points`, with the band On course; with
    /// `firstAt`, a slot he is first choice at, before it.
    func standingOutlook(smith: Rival?, points: Int? = 14, firstAt: SlotID? = nil) -> Outlook {
        let estimate = ReachEstimate(age: 19, current: 80, potential: 150, professionalism: 15, ambition: 10,
                                     determination: 10, seasonGrowth: 12.3, bySeason: [80, 92, 104],
                                     reachesPotential: false, ambitionSlows: false, determinationSlows: false,
                                     professionalismHoldsBack: false)
        let best = smith.map { smith in
            SlotOutlook(slot: .D_L, rating: 50, reachRating: 75, isFirstChoice: false, firstChoice: smith,
                        secondChoice: nil, band: .onCourse, pointsNeeded: points, level: .couldPassFirst)
        }
        let first = firstAt.map { slot in
            SlotOutlook(slot: slot, rating: 70, reachRating: 90, isFirstChoice: true, firstChoice: nil, secondChoice: nil,
                        band: nil, pointsNeeded: nil, level: nil)
        }
        return Outlook(player: PlayerID(key: "young"), estimate: estimate, slots: [first, best].compactMap { $0 },
                       best: best, level: best?.level, average: nil)
    }

    /// Smith, named with his age when the engine says so (at 30 or over under the fm27 parameters).
    func smith(age: Int, rating: Double = 70, compared: Double = 70) -> Rival {
        Rival(player: PlayerID(key: "smith"), name: "Smith", age: age, rating: rating, compared: compared,
              isAgeNamed: age >= 30)
    }

    @Test func theStandingAtHisBestSlot() {
        let names: (SlotID) -> String = { PositionText.plain($0.position) }
        #expect(AdvisorText.standing(standingOutlook(smith: smith(age: 28)), names: names)
                == "Needs about 14 more ability points to match Smith at left back; this tool expects about 12 a season. "
                    + "On course.")
        #expect(AdvisorText.standing(standingOutlook(smith: smith(age: 31)), names: names)
                == "Needs about 14 more ability points to match Smith at left back; this tool expects about 12 a season. "
                    + "On course. Smith is 31.")
        #expect(AdvisorText.standing(standingOutlook(smith: smith(age: 29)), names: names)?.hasSuffix("On course.") == true)
        #expect(AdvisorText.standing(standingOutlook(smith: smith(age: 30)), names: names)?.hasSuffix(" Smith is 30.") == true)
        // A first choice still growing is compared at his reach.
        #expect(AdvisorText.standing(standingOutlook(smith: smith(age: 20, compared: 78)), names: names)
                == "Needs about 14 more ability points to match Smith at left back; this tool expects about 12 a season. "
                    + "On course. Smith is 20 and still growing.")
        #expect(AdvisorText.standing(standingOutlook(smith: smith(age: 20)), names: names)?.hasSuffix("On course.") == true)
        // The position is named by the function handed in.
        #expect(AdvisorText.standing(standingOutlook(smith: smith(age: 28)), names: { _ in "the flank" })?
                    .contains("to match Smith at the flank;") == true)
        #expect(AdvisorText.standing(standingOutlook(smith: smith(age: 28), points: 1), names: names)?
                    .hasPrefix("Needs about 1 more ability point to match Smith") == true)
    }

    @Test func theStandingOfAFirstChoice() {
        let names: (SlotID) -> String = { PositionText.plain($0.position) }
        #expect(AdvisorText.standing(standingOutlook(smith: nil, firstAt: .ST_C), names: names) == "First choice at striker.")
        #expect(AdvisorText.standing(standingOutlook(smith: smith(age: 28), firstAt: .ST_C), names: names)
                == "First choice at striker. Needs about 14 more ability points to match Smith at left back; this tool "
                    + "expects about 12 a season. On course.")
    }

    @Test func aFirstChoiceAtASlotOfTheSameNameIsNotComparedWithTheOther() {
        let names: (SlotID) -> String = { PositionText.plain($0.position) }
        // First choice at one left-back-named slot, best at the other: only the first sentence.
        #expect(AdvisorText.standing(standingOutlook(smith: smith(age: 28), firstAt: .D_L), names: names)
                == "First choice at left back.")
        // Named the same by the function handed in.
        #expect(AdvisorText.standing(standingOutlook(smith: smith(age: 28), firstAt: .ST_C), names: { _ in "the middle" })
                == "First choice at the middle.")
        // Different words: the comparison is kept.
        #expect(AdvisorText.standing(standingOutlook(smith: smith(age: 28), firstAt: .ST_C), names: names)?
                    .hasPrefix("First choice at striker. Needs about 14") == true)
    }

    @Test func noStandingWithNoSlotToPass() {
        #expect(AdvisorText.standing(standingOutlook(smith: nil), names: { PositionText.plain($0.position) }) == nil)
        #expect(AdvisorText.standing(outlook(.couldMakeSecond, at: nil), names: { PositionText.plain($0.position) }) == nil)
    }

    @Test func matchesHereCountedOrNot() {
        #expect(AdvisorText.matchesHere(MatchesHere(starts: 1, matches: 9, basis: .startedTooFew))
                == "He has started 1 of the last 9 matches here.")
        #expect(AdvisorText.matchesHere(MatchesHere(starts: 0, matches: 3, basis: .solidSecondChoice))
                == "Too few matches are confirmed to count his starts.")
        // A first choice is counted whatever is confirmed; with nothing confirmed there is nothing to count.
        #expect(AdvisorText.matchesHere(MatchesHere(starts: 0, matches: 0, basis: .firstChoice))
                == "Too few matches are confirmed to count his starts.")
    }

    // MARK: A young player's lines

    /// A young player's advice: `action`, with the standing outlook behind Smith (or with no slot to pass when `smith`
    /// is nil), his matches here on `basis` (none when nil), and `keepReason`.
    func young(_ action: RemovalAction, _ basis: MatchesHereBasis?, keepReason: KeepReason? = nil,
               smith rival: Rival? = Rival(player: PlayerID(key: "smith"), name: "Smith", age: 28, rating: 70,
                                           compared: 70, isAgeNamed: false)) -> RemovalAdvice {
        RemovalAdvice(player: PlayerID(key: "young"), name: "Young", level: .keep, action: action, score: 0, reasons: [],
                      tier: nil, outlook: standingOutlook(smith: rival),
                      matchesHere: basis.map { MatchesHere(starts: 1, matches: 9, basis: $0) }, keepReason: keepReason,
                      watchReason: nil, loanOnlyToStart: false, onYouthContract: false, isFalseProspect: false,
                      isMentor: false, releaseCost: nil, mutualCost: nil, basis: .derived)
    }

    /// What `youngLines` should give for `advice`: the working, the standing, the matches line when `showsMatches`,
    /// then why, ending with a full stop.
    func expectedLines(_ advice: RemovalAdvice, showsMatches: Bool) throws -> [String] {
        let outlook = try #require(advice.outlook)
        let names: (SlotID) -> String = { PositionText.plain($0.position) }
        let why = AdvisorText.why(advice.action, for: advice)
        return [AdvisorText.reachWorking(outlook.estimate), AdvisorText.standing(outlook, names: names),
                showsMatches ? advice.matchesHere.map(AdvisorText.matchesHere) : nil,
                why.hasSuffix(".") ? why : why + "."].compactMap { $0 }
    }

    @Test func everyLineOfAYoungPlayerEndsWithAFullStop() throws {
        let names: (SlotID) -> String = { PositionText.plain($0.position) }
        // A why without one gains one in the lines; the table's own why keeps its form.
        let released = young(.release, .startedTooFew)
        #expect(AdvisorText.why(.release, for: released) == "He is out of contract, so releasing him costs nothing")
        #expect(AdvisorText.youngLines(released, names: names).last
                == "He is out of contract, so releasing him costs nothing.")
        // One with a full stop is unchanged.
        let playing = young(.play, .firstChoice)
        #expect(AdvisorText.youngLines(playing, names: names).last == "He is first choice here.")
        for action in RemovalAction.allCases {
            for line in AdvisorText.youngLines(young(action, .startedTooFew), names: names) {
                #expect(line.hasSuffix("."), "\(action): \(line)")
                #expect(!line.hasSuffix(".."), "\(action): \(line)")
            }
        }
    }

    @Test func aYoungPlayersLinesShowHisMatchesWhereTheWhyDoesNotSayThem() throws {
        let names: (SlotID) -> String = { PositionText.plain($0.position) }
        let shown: [RemovalAdvice] = [
            young(.play, .firstChoice), young(.play, .startedEnough),
            young(.loanForMatches, .startedTooFew),
            young(.develop, .startedTooFew, keepReason: .youthContract),
            young(.develop, .startedTooFew, keepReason: .shortContract),
        ]
        for advice in shown {
            let lines = AdvisorText.youngLines(advice, names: names)
            #expect(lines == (try expectedLines(advice, showsMatches: true)))
            #expect(lines.contains("He has started 1 of the last 9 matches here."))
        }
        // The lines in full, in their order.
        let counted = young(.play, .firstChoice)
        #expect(AdvisorText.youngLines(counted, names: names) == [
            AdvisorText.reachWorking(try #require(counted.outlook).estimate),
            "Needs about 14 more ability points to match Smith at left back; this tool expects about 12 a season. "
                + "On course.",
            "He has started 1 of the last 9 matches here.",
            "He is first choice here."])
    }

    @Test func aYoungPlayersLinesLeaveOutTheMatchesWhereTheWhySaysThemOrTheyDoNotCount() throws {
        let names: (SlotID) -> String = { PositionText.plain($0.position) }
        let hidden: [RemovalAdvice] = [
            // When his starts were not counted the why says so.
            young(.play, .solidSecondChoice),
            young(.loanForMatches, .tooFewConfirmed),
            young(.develop, .tooFewConfirmed, keepReason: .youthContract),
            young(.develop, .tooFewConfirmed, keepReason: .shortContract),
            // At his age the matches do not come into it.
            young(.develop, .startedTooFew, keepReason: .age),
            // Any other action says nothing about matches.
            young(.release, .startedTooFew), young(.terminate, .startedTooFew), young(.sell, .startedTooFew),
            young(.monitor, .startedTooFew), young(.keep, .startedTooFew),
            // No matches worked out: none to show.
            young(.play, nil),
        ]
        for advice in hidden {
            let lines = AdvisorText.youngLines(advice, names: names)
            #expect(lines == (try expectedLines(advice, showsMatches: false)))
            #expect(!lines.contains("He has started 1 of the last 9 matches here."))
        }
        // The why still says the starts were not counted, once.
        let solid = AdvisorText.youngLines(young(.play, .solidSecondChoice), names: names)
        #expect(solid.last == "He is second choice here, and too few matches are confirmed to count his starts.")
        #expect(solid.filter { $0.contains("too few matches are confirmed") || $0.contains("Too few matches") }.count == 1)
    }

    @Test func aYoungPlayersLinesLeaveOutAStandingHeHasNot() throws {
        let advice = young(.play, .firstChoice, smith: nil)
        let lines = AdvisorText.youngLines(advice, names: { PositionText.plain($0.position) })
        #expect(lines == [AdvisorText.reachWorking(try #require(advice.outlook).estimate),
                          "He has started 1 of the last 9 matches here.", "He is first choice here."])
    }

    @Test func aYoungPlayersLinesNameHisPositionThroughTheFunctionHandedIn() {
        let lines = AdvisorText.youngLines(young(.play, .firstChoice), names: { _ in "the flank" })
        #expect(lines[1].contains("to match Smith at the flank;"))
    }

    @Test func aPlayerWithNoOutlookHasNoYoungLines() {
        #expect(AdvisorText.youngLines(removal(action: .keep, release: nil, mutual: nil), names: { _ in "x" }).isEmpty)
    }

    @Test func eachReachBandHasItsName() {
        #expect(ReachBand.allCases.map { AdvisorText.name($0) } == ["Close", "On course", "Possible", "Not expected"])
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

    @Test func thinCoverNamesTheThinSlotsInTheirOrderWithoutSayingToRecruit() {
        #expect(AdvisorText.thinCover(DepthReport(slots: [], thin: [.GK, .D_L], basis: .derived))
                == "Thin cover: goalkeeper, left back")
        #expect(AdvisorText.thinCover(DepthReport(slots: [], thin: [.D_CL], basis: .derived))
                == "Thin cover: left centre-back")
        #expect(AdvisorText.thinCover(DepthReport(slots: [], thin: [], basis: .derived)) == nil)
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

    func trainingReport(recommending needs: [[RetrainingNeed]] = [], withoutCandidates: [RetrainingNeed] = [],
                        beingRetrained: [RetrainingNeed] = []) -> TrainingReport {
        let recommendations = needs.enumerated().map { index, needs in
            RetrainingRecommendation(
                choice: RetrainingChoice(player: PlayerID(key: "p\(index)"), position: .defenderLeft), name: "P\(index)",
                age: 20, currentFamiliarity: 8, needs: needs, ratingIfLearnt: 100, shareOfFirstChoice: 0.95,
                learnability: 0.7, from: .defenderRight, difficulty: .fluid, weeks: 12, reasons: [], cautions: [],
                basis: .derived)
        }
        return TrainingReport(recommendations: recommendations, needsWithoutCandidates: withoutCandidates,
                              needsBeingRetrained: beingRetrained)
    }

    @Test func nothingRecommendedOnlyWhenTheReportRecommendsNobody() {
        let a = RetrainingNeed(tactic: "Sample 4-2-3-1", slot: .D_L)
        #expect(AdvisorText.nothingRecommended(trainingReport()) == "No retraining is recommended today.")
        #expect(AdvisorText.nothingRecommended(trainingReport(withoutCandidates: [a], beingRetrained: [a]))
                == "No retraining is recommended today.")
        #expect(AdvisorText.nothingRecommended(trainingReport(recommending: [[a]])) == nil)
    }

    @Test func nothingToRecruitTellsNoThinSlotFromThinSlotsAllCovered() {
        let a = RetrainingNeed(tactic: "Sample 4-2-3-1", slot: .D_L)
        let b = RetrainingNeed(tactic: "Sample 4-2-3-1", slot: .GK)
        // No thin slot in any tactic.
        #expect(AdvisorText.nothingToRecruit(trainingReport()) == "No slot is thin.")
        // Thin slots, each with someone recommended for it or already learning it.
        let covered = "Every thin slot has someone learning it or recommended for it."
        #expect(AdvisorText.nothingToRecruit(trainingReport(recommending: [[a]])) == covered)
        #expect(AdvisorText.nothingToRecruit(trainingReport(beingRetrained: [a])) == covered)
        #expect(AdvisorText.nothingToRecruit(trainingReport(recommending: [[a]], beingRetrained: [b])) == covered)
        // A thin slot nobody suits: the list names it, so there is no sentence in its place.
        #expect(AdvisorText.nothingToRecruit(trainingReport(withoutCandidates: [b])) == nil)
        #expect(AdvisorText.nothingToRecruit(trainingReport(recommending: [[a]], withoutCandidates: [b])) == nil)
    }

    @Test func advisedToLeaveSaysPlayerRemovalWouldMoveHimOn() {
        #expect(AdvisorText.advisedToLeave("Keegan Bloom") == "Player Removal advises moving him on.")
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
                                        money: .weeklyPounds, history: StartHistory([]),
                                        asOf: Day(year: 2026, month: 11, day: 14)!, retraining: [],
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
