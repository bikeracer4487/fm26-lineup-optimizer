import Foundation
import Testing
@testable import LineupEngine

@Suite struct ScoutingTextTests {
    let parameters = EngineParameters.fm27

    func id(_ key: String) -> PlayerID { PlayerID(key: key) }
    func named(_ name: String, age: Int) -> NamedPlayer { NamedPlayer(player: id(name.lowercased()), name: name, age: age) }
    func going(_ name: String, _ reason: GoingReason) -> Going { Going(player: id(name.lowercased()), name: name, reason: reason) }

    func need(_ kind: BetterPlayerKind, slot: SlotID = .D_L, first: NamedPlayer? = nil, measure: NeedMeasure? = nil,
              gap: Double? = nil, leaving: Going? = nil, eased: NamedPlayer? = nil) -> BetterPlayerNeed {
        BetterPlayerNeed(slot: slot, kind: kind, firstChoice: first, measure: measure, gap: gap, goingFirstChoice: leaving,
                         easedBy: eased, basis: .derived)
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
        #expect(AdvisorText.depthNeedLines(DepthNeed(depth: one, going: [], returning: []), parameters: parameters)
                == ["1 player counts as cover; 2 needed: Jonny Maxted.", "Next best: Josh Ashby, 6.7 lower."])
        let none = slotDepth(options: [], cover: 0, drop: nil, next: nil)
        #expect(AdvisorText.depthNeedLines(DepthNeed(depth: none, going: [], returning: []), parameters: parameters)
                == ["Nobody counts as cover; 2 needed.", "Nobody else can step in."])
        let lines = AdvisorText.depthNeedLines(DepthNeed(
            depth: none, going: [going("Lee Hart", .onLoanHere), going("Sam Reed", .advisedToLeave)],
            returning: [Returning(player: id("max treml"), name: "Max Treml", club: "Wallingford")]), parameters: parameters)
        #expect(lines == ["Nobody counts as cover; 2 needed.", "Nobody else can step in.",
                          "Not counting Lee Hart and Sam Reed, who are going.",
                          "Max Treml, out on loan at Wallingford, would count as cover."])
    }

    @Test func twoWhoCountAreJoinedWithAnd() {
        let two = slotDepth(options: [option("A One"), option("B Two")], cover: 2, drop: 1, next: "B Two")
        #expect(AdvisorText.depthNeedLines(DepthNeed(depth: two, going: [], returning: []), parameters: parameters).first
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
            AdvisorText.depthNeedLines(DepthNeed(depth: none, going: going, returning: returning), parameters: parameters)
        }
        #expect(lines(going: [going("Lee Hart", .onLoanHere)]) == base + ["Not counting Lee Hart, who is going."])
        #expect(lines(going: [going("Lee Hart", .onLoanHere), going("Sam Reed", .markedToSell), going("Tom Vale", .advisedToLeave)])
                == base + ["Not counting Lee Hart, Sam Reed and Tom Vale, who are going."])
        #expect(lines(returning: [Returning(player: id("max treml"), name: "Max Treml", club: "Wallingford"),
                                  Returning(player: id("ben cole"), name: "Ben Cole", club: "Didcot")])
                == base + ["Max Treml, out on loan at Wallingford, would count as cover.",
                           "Ben Cole, out on loan at Didcot, would count as cover."])
    }
}
