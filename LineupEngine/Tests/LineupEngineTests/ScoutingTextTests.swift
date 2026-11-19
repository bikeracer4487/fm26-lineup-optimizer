import Foundation
import Testing
@testable import LineupEngine

@Suite struct ScoutingTextTests {
    let parameters = EngineParameters.fm27

    func id(_ key: String) -> PlayerID { PlayerID(key: key) }
    func named(_ name: String, age: Int) -> NamedPlayer { NamedPlayer(player: id(name.lowercased()), name: name, age: age) }
    func going(_ name: String, _ reason: GoingReason) -> Going { Going(player: id(name.lowercased()), name: name, reason: reason) }

    func need(_ kind: BetterPlayerKind, slot: SlotID = .D_L, first: NamedPlayer? = nil, measure: NeedMeasure? = nil,
              gap: Double? = nil, leaving: Going? = nil, eased: NamedPlayer? = nil, namesAge: Bool = false) -> BetterPlayerNeed {
        BetterPlayerNeed(slot: slot, kind: kind, firstChoice: first, namesFirstChoiceAge: namesAge, measure: measure, gap: gap,
                         goingFirstChoice: leaving, easedBy: eased, basis: .derived)
    }
    func depthNeed(_ depth: SlotDepth, going: [Going] = [], returning: [Returning] = [], injured: [NamedPlayer] = [],
                   lasts: Bool = false, first: NamedPlayer? = nil, shareUnder: Double? = nil) -> DepthNeed {
        DepthNeed(depth: depth, going: going, returning: returning, injured: injured, lastsOnlyWhileInjured: lasts,
                  firstChoice: first, nextBestShareUnder: shareUnder)
    }

    let sam = NamedPlayer(player: PlayerID(key: "sam reed"), name: "Sam Reed", age: 27)
    var rating: NeedMeasure { .rating(his: 90, average: 95.4) }

    @Test func namesOfReasonsAndKinds() {
        #expect(AdvisorText.name(GoingReason.onLoanHere) == "on loan here")
        #expect(AdvisorText.name(GoingReason.markedToSell) == "marked to sell")
        #expect(AdvisorText.name(GoingReason.markedToLoanOut) == "marked to loan out")
        #expect(AdvisorText.name(GoingReason.advisedToLeave) == "advised to leave")
        #expect(AdvisorText.name(BetterPlayerKind.nobody) == "Nobody")
        #expect(AdvisorText.name(BetterPlayerKind.weak) == "Weak")
        #expect(AdvisorText.name(BetterPlayerKind.ageing) == "Ageing")
        #expect(AdvisorText.betterPlayersHeading == "Better players")
        #expect(AdvisorText.moreDepthHeading == "More depth")
    }

    @Test func displayShowsAShareToOneDecimal() {
        #expect(Display.onePercentDecimal(0.0574) == "5.7%")
        #expect(Display.onePercentDecimal(0.05) == "5.0%")
        #expect(Display.onePercentDecimal(-0.031) == "3.1%")
    }

    @Test func countedAsGoing() {
        #expect(AdvisorText.countedAsGoing([]) == nil)
        #expect(AdvisorText.countedAsGoing([going("Lee Hart", .onLoanHere), going("Sam Reed", .advisedToLeave)])
                == "Counted as going: Lee Hart (on loan here), Sam Reed (advised to leave).")
    }

    @Test func nobodyLines() {
        #expect(AdvisorText.betterPlayerLines(need(.nobody)) == ["Nobody who stays can play here."])
        #expect(AdvisorText.betterPlayerLines(need(.nobody, first: sam))
                == ["Nobody who stays can play here; Sam Reed would fill in out of position."])
    }

    @Test func weakLines() {
        #expect(AdvisorText.betterPlayerLines(need(.weak, first: sam, measure: rating, gap: 0.0574))
                == ["Sam Reed rates 5.7% under the average of your outfield first choices."])
        #expect(AdvisorText.betterPlayerLines(need(.weak, slot: .GK, first: sam, measure: .ability(his: 60, average: 104.6), gap: 0.4))
                == ["Sam Reed has ability 60 against an average of 105 for your outfield first choices. Goalkeepers are rated on their own scale, so ability is compared."])
    }

    @Test func ageingLine() {
        let old = named("Sam Reed", age: 32)
        #expect(AdvisorText.betterPlayerLines(need(.ageing, first: old))
                == ["Sam Reed is 32, and nobody is on course to pass him. Decline is not measured, so this is a prompt to look."])
    }

    @Test func aGoingFirstChoiceComesFirst() {
        let lee = going("Lee Hart", .onLoanHere)
        let goingLine = "Lee Hart, first choice today, is on loan here."
        #expect(AdvisorText.betterPlayerLines(need(.weak, first: sam, measure: rating, gap: 0.0574, leaving: lee))
                == [goingLine, "Sam Reed, the best who stays, rates 5.7% under the average of your outfield first choices."])
        #expect(AdvisorText.betterPlayerLines(need(.nobody, leaving: lee))
                == [goingLine, "Nobody who stays can play here."])
        #expect(AdvisorText.betterPlayerLines(need(.ageing, first: named("Sam Reed", age: 32), leaving: going("Lee Hart", .markedToSell)))
                == ["Lee Hart, first choice today, is marked to sell.",
                    "Sam Reed is 32, and nobody is on course to pass him. Decline is not measured, so this is a prompt to look."])
    }

    @Test func easedNeeds() {
        let weak = "Sam Reed rates 5.7% under the average of your outfield first choices."
        let himself = NamedPlayer(player: sam.player, name: "Sam Reed", age: 20)
        #expect(AdvisorText.betterPlayerLines(need(.weak, first: himself, measure: rating, gap: 0.0574, eased: himself))
                == [weak, "He is 20; his reach would bring him level (this tool's estimate)."])
        #expect(AdvisorText.betterPlayerLines(need(.weak, first: sam, measure: rating, gap: 0.0574, eased: named("Tom Vale", age: 19)))
                == [weak, "Tom Vale is 19; his reach would bring him level (this tool's estimate)."])
    }

    func option(_ name: String, cover: Bool = true) -> DepthOption {
        DepthOption(player: id(name.lowercased()), name: name, squad: .firstTeam, rating: 80, ipFamiliarity: 20,
                    oopFamiliarity: 20, isSolid: true, unavailable: nil, tier: nil, alsoNeededAt: [],
                    isBelowCoverShare: !cover, isStandIn: true, countsAsCover: cover)
    }

    func slotDepth(options: [DepthOption], cover: Int, drop: Double?, next: String?) -> SlotDepth {
        SlotDepth(slot: .D_L, ipPosition: .defenderLeft, oopPosition: .defenderLeft, options: options, onLoan: [],
                  cover: cover, standIns: options.count, isThin: cover < 2, dropToNextBest: drop, nextBest: next.map { id($0.lowercased()) })
    }

    @Test func depthLines() {
        let one = slotDepth(options: [option("Jonny Maxted"), option("Josh Ashby", cover: false)], cover: 1, drop: 6.66, next: "Josh Ashby")
        #expect(AdvisorText.depthNeedLines(depthNeed(one, first: named("Jonny Maxted", age: 30), shareUnder: 0.0666),
                                           parameters: parameters)
                == ["1 player counts as cover; 2 needed: Jonny Maxted.", "The next best, Josh Ashby, rates 6.7% under Jonny Maxted."])
        let none = slotDepth(options: [], cover: 0, drop: nil, next: nil)
        #expect(AdvisorText.depthNeedLines(depthNeed(none, going: [], returning: []), parameters: parameters)
                == ["Nobody counts as cover; 2 needed.", "Nobody else can step in."])
        let lines = AdvisorText.depthNeedLines(depthNeed(none, going: [going("Lee Hart", .onLoanHere), going("Sam Reed", .advisedToLeave)],
            returning: [Returning(player: id("max treml"), name: "Max Treml", club: "Wallingford")]), parameters: parameters)
        #expect(lines == ["Nobody counts as cover; 2 needed.", "Nobody else can step in.",
                          "Not counting Lee Hart and Sam Reed, who are going.",
                          "Max Treml, out on loan at Wallingford, would count as cover."])
    }

    @Test func twoWhoCountAreJoinedWithAnd() {
        let two = slotDepth(options: [option("A One"), option("B Two")], cover: 2, drop: 1, next: "B Two")
        #expect(AdvisorText.depthNeedLines(depthNeed(two, going: [], returning: []), parameters: parameters).first
                == "2 players count as cover: A One and B Two.")
    }

    @Test func aWeakNeedWithoutAGapPrintsNoNumber() {
        let line = "Sam Reed rates under the average of your outfield first choices."
        #expect(AdvisorText.betterPlayerLines(need(.weak, first: sam, measure: rating, gap: nil)) == [line])
        #expect(AdvisorText.betterPlayerLines(need(.weak, first: sam, measure: nil, gap: 0.06)) == [line])
        #expect(AdvisorText.betterPlayerLines(need(.weak, first: sam, measure: rating, gap: nil, leaving: going("Lee Hart", .onLoanHere)))
                == ["Lee Hart, first choice today, is on loan here.",
                    "Sam Reed, the best who stays, rates under the average of your outfield first choices."])
    }

    @Test func depthNeedsNameWhoIsGoingAndWhoReturns() {
        let none = slotDepth(options: [], cover: 0, drop: nil, next: nil)
        let base = ["Nobody counts as cover; 2 needed.", "Nobody else can step in."]
        func lines(going: [Going] = [], returning: [Returning] = []) -> [String] {
            AdvisorText.depthNeedLines(depthNeed(none, going: going, returning: returning), parameters: parameters)
        }
        #expect(lines(going: [going("Lee Hart", .onLoanHere)]) == base + ["Not counting Lee Hart, who is going."])
        #expect(lines(going: [going("Lee Hart", .onLoanHere), going("Sam Reed", .markedToSell), going("Tom Vale", .advisedToLeave)])
                == base + ["Not counting Lee Hart, Sam Reed and Tom Vale, who are going."])
        #expect(lines(returning: [Returning(player: id("max treml"), name: "Max Treml", club: "Wallingford"),
                                  Returning(player: id("ben cole"), name: "Ben Cole", club: "Didcot")])
                == base + ["Max Treml, out on loan at Wallingford, would count as cover.",
                           "Ben Cole, out on loan at Didcot, would count as cover."])
    }

    @Test func theNextBestIsGivenAgainstTheFirstChoice() {
        let fernando = named("Fernando Forestieri", age: 28)
        let slot = slotDepth(options: [option("Fernando Forestieri"), option("Zac McEachran", cover: false)], cover: 1,
                             drop: 9, next: "Zac McEachran")
        func second(_ need: DepthNeed) -> String { AdvisorText.depthNeedLines(need, parameters: parameters)[1] }
        #expect(second(depthNeed(slot, first: fernando, shareUnder: 0.064))
                == "The next best, Zac McEachran, rates 6.4% under Fernando Forestieri.")
        let reed = slotDepth(options: [option("Lee Hart"), option("Sam Reed", cover: false)], cover: 1, drop: -2, next: "Sam Reed")
        #expect(second(depthNeed(reed, first: named("Lee Hart", age: 25), shareUnder: -0.02))
                == "The next best, Sam Reed, rates 2.0% above Lee Hart.")
        #expect(second(depthNeed(slot, first: fernando, shareUnder: 0.0001))
                == "The next best, Zac McEachran, rates level with Fernando Forestieri.")
        #expect(second(depthNeed(slot, first: nil, shareUnder: nil)) == "The next best is Zac McEachran.")
        let nobody = slotDepth(options: [option("Fernando Forestieri")], cover: 1, drop: nil, next: nil)
        #expect(second(depthNeed(nobody, first: fernando, shareUnder: nil)) == "Nobody else can step in.")
    }

    @Test func aDepthNeedNamesWhoIsInjuredAndWhetherItLastsOnlyWhileTheyAreOut() {
        let fernando = named("Fernando Forestieri", age: 28)
        let slot = slotDepth(options: [option("Zac McEachran"), option("Fernando Forestieri", cover: false)], cover: 1,
                             drop: nil, next: nil)
        let base = ["1 player counts as cover; 2 needed: Zac McEachran.", "Nobody else can step in."]
        func lines(_ need: DepthNeed) -> [String] { AdvisorText.depthNeedLines(need, parameters: parameters) }
        #expect(lines(depthNeed(slot, injured: [fernando], lasts: true))
                == base + ["Not counting Fernando Forestieri, who is injured.", "The need lasts only while he is out."])
        #expect(lines(depthNeed(slot, injured: [fernando], lasts: false))
                == base + ["Not counting Fernando Forestieri, who is injured."])
        #expect(lines(depthNeed(slot, going: [going("Lee Hart", .onLoanHere)],
                                returning: [Returning(player: id("max treml"), name: "Max Treml", club: "Wallingford")],
                                injured: [fernando, named("Ben Cole", age: 22)], lasts: true))
                == base + ["Not counting Fernando Forestieri and Ben Cole, who are injured.",
                           "The need lasts only while they are out.",
                           "Not counting Lee Hart, who is going.",
                           "Max Treml, out on loan at Wallingford, would count as cover."])
        #expect(lines(depthNeed(slot)) == base)
    }

    @Test func aWeakFirstChoiceOfThirtyOrOverIsNamedWithHisAge() {
        let alfie = named("Alfie Potter", age: 37)
        #expect(AdvisorText.betterPlayerLines(need(.weak, first: alfie, measure: rating, gap: 0.059, namesAge: true))
                == ["Alfie Potter, 37, rates 5.9% under the average of your outfield first choices."])
        #expect(AdvisorText.betterPlayerLines(need(.weak, first: named("Sam Reed", age: 31), measure: rating, gap: 0.0574,
                                                   leaving: going("Lee Hart", .onLoanHere), namesAge: true))
                == ["Lee Hart, first choice today, is on loan here.",
                    "Sam Reed, 31, the best who stays, rates 5.7% under the average of your outfield first choices."])
        #expect(AdvisorText.betterPlayerLines(need(.weak, slot: .GK, first: alfie, measure: .ability(his: 60, average: 104.6),
                                                   gap: 0.4, namesAge: true))
                == ["Alfie Potter, 37, has ability 60 against an average of 105 for your outfield first choices. Goalkeepers are rated on their own scale, so ability is compared."])
        // Under 30 the line names no age.
        #expect(AdvisorText.betterPlayerLines(need(.weak, first: sam, measure: rating, gap: 0.0574, namesAge: false))
                == ["Sam Reed rates 5.7% under the average of your outfield first choices."])
    }

    @Test func aNeedEasedByAPlayerOutOnLoanSaysWhere() {
        let max = NamedPlayer(player: id("max treml"), name: "Max Treml", age: 18, onLoanAt: "Wallingford")
        #expect(AdvisorText.betterPlayerLines(need(.weak, first: sam, measure: rating, gap: 0.0574, eased: max)).last
                == "Max Treml, out on loan at Wallingford, is 18; his reach would bring him level (this tool's estimate).")
    }

    // MARK: The candidates

    func rival(_ name: String = "Evan Humphries", age: Int = 27) -> Rival {
        Rival(player: id(name.lowercased()), name: name, age: age, rating: 70, compared: 70, isAgeNamed: age >= 30)
    }

    func candidateSlot(_ slot: SlotID = .D_L, level: CandidateLevel = .wouldStart, margin: Double? = 0.06,
                       first: Rival? = nil, solid: Bool = true, ip: Int = 15, oop: Int = 15, stillWeakBy: WeakGap? = nil,
                       later: SlotOutlook? = nil, outOfPosition: Bool = false,
                       weakLine: WeakLineReach? = nil) -> CandidateSlot {
        CandidateSlot(slot: slot, rating: 70, ipFamiliarity: ip, oopFamiliarity: oop, isSolid: solid, level: level,
                      firstChoice: margin == nil ? nil : (first ?? rival()), secondChoice: nil,
                      firstChoiceIsOutOfPosition: outOfPosition, marginOverFirst: margin, stillWeakBy: stillWeakBy,
                      later: later, laterAgainstWeakLine: weakLine, answers: [])
    }

    func estimate() -> ReachEstimate {
        ReachEstimate(age: 19, current: 80, potential: 150, professionalism: 15, ambition: 10, determination: 10,
                      seasonGrowth: 12.3, bySeason: [80, 92, 104], reachesPotential: false, ambitionSlows: false,
                      determinationSlows: false, professionalismHoldsBack: false, growthFallsLater: true)
    }

    func slotOutlook(level: ReachLevel?, first: Rival?) -> SlotOutlook {
        SlotOutlook(slot: .D_L, rating: 50, reachRating: 75, isFirstChoice: false, firstChoice: first, secondChoice: nil,
                    band: first == nil ? nil : .onCourse, pointsNeeded: first == nil ? nil : 14, level: level)
    }

    /// A candidate whose headline slot is `slot` (left back by default).
    func candidate(_ slot: CandidateSlot, young: Bool = false, level: ReachLevel? = .couldPassFirst, age: Int = 27,
                   clearsWeakLine: Bool? = nil, headline: Bool = true) -> Candidate {
        var slot = slot
        if let clearsWeakLine, let later = slot.later {
            slot = slot.with(later: later, against: WeakLineReach(reach: .rating(112), clears: clearsWeakLine), answers: [])
        }
        var outlook: Outlook?
        if young {
            let best = slot.later.flatMap { $0.level == nil ? nil : $0 }
            outlook = Outlook(player: id("young"), estimate: estimate(), slots: slot.later.map { [$0] } ?? [], best: best,
                              level: best?.level, average: nil)
        }
        return Candidate(player: .fixture(name: "Young", age: age), slots: [slot], headline: headline ? slot.slot : nil,
                         headlineAnswer: nil, part: .rest, outlook: outlook, isAgeNamed: age >= 30, cautions: [], basis: .derived)
    }

    @Test func candidateNames() {
        #expect(CandidateLevel.allCases.map { AdvisorText.name($0) } == [
            "Would start", "Would make the second eleven", "Would count as cover", "Below cover"])
        #expect(CandidatePart.allCases.map { AdvisorText.name($0) } == [
            "Answers a need today", "Could answer a need later", "Would start where you have no need",
            "Could pass a first choice where you have no need", "The rest"])
        #expect(CandidateOrder.allCases.map { AdvisorText.name($0) } == ["Today", "Later"])
    }

    @Test func groupHeadings() {
        #expect(AdvisorText.groupHeading(slot: .D_L, answer: .betterPlayerToday) == "Left back · needs a better player")
        #expect(AdvisorText.groupHeading(slot: .D_L, answer: .betterPlayerLater) == "Left back · needs a better player")
        #expect(AdvisorText.groupHeading(slot: .GK, answer: .moreDepth) == "Goalkeeper · needs more depth")
    }

    @Test func todayLinesNameTheMarginAndTheFirstChoice() {
        #expect(AdvisorText.todayLines(candidateSlot(margin: 0.06))
                == ["Would start: rates 6.0% above Evan Humphries, your first choice at left back."])
        #expect(AdvisorText.todayLines(candidateSlot(level: .wouldCountAsCover, margin: -0.12))
                == ["Would count as cover: rates 12.0% under Evan Humphries, your first choice at left back."])
        #expect(AdvisorText.todayLines(candidateSlot(margin: 0))
                == ["Would start: rates level with Evan Humphries, your first choice at left back."])
        #expect(AdvisorText.todayLines(candidateSlot(margin: nil))
                == ["Would start: nobody who stays can play at left back."])
        // A first choice who fills in out of position is not called "your first choice".
        let ellis = rival("Ellis Brown")
        #expect(AdvisorText.todayLines(candidateSlot(margin: 0.06, first: ellis, outOfPosition: true))
                == ["Would start: rates 6.0% above Ellis Brown, who fills in at left back out of position."])
        #expect(AdvisorText.todayLines(candidateSlot(level: .wouldMakeSecond, margin: 0, first: ellis, outOfPosition: true))
                == ["Would make the second eleven: rates level with Ellis Brown, who fills in at left back out of position."])
        #expect(AdvisorText.todayLines(candidateSlot(level: .belowCover, margin: -0.3, first: ellis, outOfPosition: true))
                == ["Below cover: rates 30.0% under Ellis Brown, who fills in at left back out of position."])
    }

    @Test func todayLinesSayWhenHeIsNotSolidOrTheSlotStaysWeak() {
        #expect(AdvisorText.todayLines(candidateSlot(solid: false, ip: 12, oop: 14)) == [
            "Would start: rates 6.0% above Evan Humphries, your first choice at left back.",
            "Not yet solid there: familiarity 12 in possession, 14 out."])
        #expect(AdvisorText.todayLines(candidateSlot(stillWeakBy: WeakGap(gap: 0.031, measure: .rating(his: 90, average: 92.9)))) == [
            "Would start: rates 6.0% above Evan Humphries, your first choice at left back.",
            "The slot would still be weak with him: 3.1% under the average of your outfield first choices."])
        // The goalkeeper's slot is measured by ability, as the value carries it; the text asks nothing about the slot.
        #expect(AdvisorText.todayLines(candidateSlot(.GK, stillWeakBy: WeakGap(gap: 0.4, measure: .ability(his: 60, average: 104.6)))) == [
            "Would start: rates 6.0% above Evan Humphries, your first choice at goalkeeper.",
            "The slot would still be weak with him: ability 60 against an average of 105 for your outfield first choices."])
    }

    @Test func laterLinesWithAnOutlookAndALevel() {
        let first = rival("Smith", age: 28)
        let later = slotOutlook(level: .couldPassFirst, first: first)
        let slot = candidateSlot(level: .wouldMakeSecond, first: first, later: later)
        let young = candidate(slot, young: true)
        let outlook = young.outlook!
        let names: (SlotID) -> String = { PositionText.plain($0) }
        let base = [AdvisorText.reachLine(outlook, names: names)! + ".", AdvisorText.reachWorking(outlook.estimate),
                    AdvisorText.standing(outlook, names: names)!]
        #expect(base[0] == "Could pass Smith at left back.")
        #expect(AdvisorText.laterLines(young) == base)
        // Cover or below adds the assumption last.
        let caveat = "The estimate assumes regular matches, which he may not get here."
        for level in [CandidateLevel.wouldCountAsCover, .belowCover] {
            let low = candidate(candidateSlot(level: level, first: first, later: later), young: true)
            #expect(AdvisorText.laterLines(low) == base + [caveat])
        }
        #expect(!AdvisorText.laterLines(candidate(candidateSlot(level: .wouldStart, first: first, later: later), young: true))
            .contains(caveat))
    }

    @Test func laterLinesNameTheSlotAtEveryLevel() {
        let first = rival("Smith", age: 28)
        func reachLine(_ level: ReachLevel) -> String? {
            let later = slotOutlook(level: level, first: first)
            return AdvisorText.laterLines(candidate(candidateSlot(level: .wouldMakeSecond, first: first, later: later), young: true)).first
        }
        #expect(reachLine(.couldPassFirst) == "Could pass Smith at left back.")
        #expect(reachLine(.couldMakeSecond) == "Could make the second eleven at left back.")
        #expect(reachLine(.couldBeCover) == "Could become cover at left back, no more.")
        #expect(reachLine(.markedlyLower) == "Not expected to reach the level of cover at left back.")
    }

    @Test func laterLinesWithNoFirstChoice() {
        let later = slotOutlook(level: nil, first: nil)
        func lines(_ slot: SlotID, _ reach: ReachFigure, clears: Bool) -> [String] {
            let s = candidateSlot(slot, margin: nil, later: later, weakLine: WeakLineReach(reach: reach, clears: clears))
            return AdvisorText.laterLines(candidate(s, young: true, level: nil))
        }
        let working = AdvisorText.reachWorking(estimate())
        #expect(lines(.D_L, .rating(112.4), clears: true)
                == [working, "His reach would rate about 112 at left back, which clears the line for a weak slot."])
        #expect(lines(.D_L, .rating(98.6), clears: false)
                == [working, "His reach would rate about 99 at left back, which is still under the line for a weak slot."])
        #expect(lines(.GK, .ability(100.2), clears: true)
                == [working, "His reach of about 100 ability at goalkeeper clears the line for a weak slot."])
        #expect(lines(.GK, .ability(80), clears: false)
                == [working, "His reach of about 80 ability at goalkeeper is still under the line for a weak slot."])
        // With no average to set it against, only the working.
        #expect(AdvisorText.laterLines(candidate(candidateSlot(margin: nil, later: later), young: true, level: nil)) == [working])
    }

    @Test func laterLinesWithNoOutlook() {
        #expect(AdvisorText.laterLines(candidate(candidateSlot())) == ["Judged as he is today."])
        #expect(AdvisorText.laterLines(candidate(candidateSlot(), age: 31))
                == ["Judged as he is today. He is 31: decline is not measured."])
        #expect(AdvisorText.laterLines(candidate(candidateSlot(), headline: false)) == [])
        #expect(AdvisorText.laterLines(candidate(candidateSlot(), young: true, headline: false)) == [])
    }

    @Test func otherSlotLinesAreTheTodayLinesThenOneForLater() {
        let deago = Rival(player: id("deago nelson"), name: "Deago Nelson", age: 26, rating: 70, compared: 70, isAgeNamed: false)
        let today = AdvisorText.todayLines(candidateSlot(.D_R, level: .wouldMakeSecond, margin: -0.03, first: deago, solid: false,
                                                         ip: 12, oop: 14))
        #expect(today == ["Would make the second eleven: rates 3.0% under Deago Nelson, your first choice at right back.",
                          "Not yet solid there: familiarity 12 in possession, 14 out."])
        #expect(AdvisorText.otherSlotLines(candidateSlot(.D_R, level: .wouldMakeSecond, margin: -0.03, first: deago, solid: false,
                                                         ip: 12, oop: 14)) == today)
        func later(_ level: ReachLevel) -> String? {
            let outlook = SlotOutlook(slot: .D_R, rating: 50, reachRating: 75, isFirstChoice: false, firstChoice: deago,
                                      secondChoice: nil, band: .onCourse, pointsNeeded: 14, level: level)
            return AdvisorText.otherSlotLines(candidateSlot(.D_R, margin: -0.03, first: deago, later: outlook)).last
        }
        #expect(later(.couldPassFirst) == "Later: could pass Deago Nelson at right back.")
        #expect(later(.couldMakeSecond) == "Later: could make the second eleven at right back.")
        #expect(later(.couldBeCover) == "Later: could become cover at right back, no more.")
        #expect(later(.markedlyLower) == "Later: not expected to reach the level of cover at right back.")
        let open = SlotOutlook(slot: .D_R, rating: 50, reachRating: 112, isFirstChoice: false, firstChoice: nil,
                               secondChoice: nil, band: nil, pointsNeeded: nil, level: nil)
        let lines = AdvisorText.otherSlotLines(candidateSlot(.D_R, margin: nil, later: open,
                                                             weakLine: WeakLineReach(reach: .rating(112), clears: true)))
        #expect(lines == ["Would start: nobody who stays can play at right back.",
                          "Later: his reach would rate about 112 at right back, which clears the line for a weak slot."])
        let keeper = AdvisorText.otherSlotLines(candidateSlot(.GK, margin: nil, later: open,
                                                              weakLine: WeakLineReach(reach: .ability(100), clears: false)))
        #expect(keeper.last == "Later: his reach of about 100 ability at goalkeeper is still under the line for a weak slot.")
    }

    @Test func otherSlotsCautionsAndTheRest() {
        #expect(AdvisorText.caution(CandidateCaution(attribute: .consistency, value: 6)) == "Consistency 6")
        #expect(AdvisorText.caution(CandidateCaution(attribute: .injuryProneness, value: 16)) == "Injury Proneness 16")
        #expect(AdvisorText.club(of: .fixture(name: "A", club: "Wrexham")) == "Wrexham")
        #expect(AdvisorText.club(of: .fixture(name: "A", club: nil)) == nil)
        var free = Player.fixture(name: "A", club: "Wrexham")
        free.contractType = .outOfContract
        #expect(AdvisorText.club(of: free) == "Free agent")
        #expect(AdvisorText.onLoan(at: "Barnet") == "On loan at Barnet")
        #expect(AdvisorText.askingPrice(350000, .weeklyPounds) == "Asking £350,000")
        #expect(AdvisorText.playersRead(1) == "1 player read.")
        #expect(AdvisorText.playersRead(42) == "42 players read.")
        #expect(AdvisorText.leftOutAlreadyYours([]) == nil)
        #expect(AdvisorText.leftOutAlreadyYours(["Keegan Bloom", "Ellis Brown"]) == "Left out, already yours: Keegan Bloom and Ellis Brown.")
        #expect(AdvisorText.leftOutAlreadyYours(["Keegan Bloom"]) == "Left out, already yours: Keegan Bloom.")
        #expect(AdvisorText.everyPastedPlayerIsYours == "Every pasted player is already yours, so there is nobody to judge.")
        #expect(AdvisorText.playsNoSlot == "He can play no slot of this tactic.")
    }
}
