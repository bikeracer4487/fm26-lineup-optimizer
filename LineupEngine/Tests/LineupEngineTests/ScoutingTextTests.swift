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
        #expect(AdvisorText.depthNeedLines(depthNeed(one, going: [], returning: []), parameters: parameters)
                == ["1 player counts as cover; 2 needed: Jonny Maxted.", "Next best: Josh Ashby, 6.7 lower."])
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

    @Test func laterLinesWithNoFirstChoice() {
        let later = slotOutlook(level: nil, first: nil)
        let slot = candidateSlot(margin: nil, later: later)
        let clears = candidate(slot, young: true, level: nil, clearsWeakLine: true)
        #expect(AdvisorText.laterLines(clears) == [
            AdvisorText.reachWorking(clears.outlook!.estimate),
            "His reach would clear the line for a weak slot at left back."])
        let under = candidate(slot, young: true, level: nil, clearsWeakLine: false)
        #expect(AdvisorText.laterLines(under).last == "His reach would still be under the line for a weak slot at left back.")
    }

    @Test func laterLinesWithNoOutlook() {
        #expect(AdvisorText.laterLines(candidate(candidateSlot())) == ["Judged as he is today."])
        #expect(AdvisorText.laterLines(candidate(candidateSlot(), age: 31))
                == ["Judged as he is today. He is 31: decline is not measured."])
        #expect(AdvisorText.laterLines(candidate(candidateSlot(), headline: false)) == [])
        #expect(AdvisorText.laterLines(candidate(candidateSlot(), young: true, headline: false)) == [])
    }

    @Test func otherSlotsCautionsAndTheRest() {
        #expect(AdvisorText.otherSlotLine(candidateSlot(.D_R, level: .wouldMakeSecond)) == "Right back: would make the second eleven.")
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
