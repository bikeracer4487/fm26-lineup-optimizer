import Foundation
import Testing
@testable import LineupEngine

@Suite struct ScoutingCandidatesTests {
    let tactic = try! PlannerFixture.tactic()
    let catalog = try! RoleCatalog.fm27()
    let profile = try! RatingProfile.standard()

    func needs(_ players: [Player], going: [Going] = []) throws -> ScoutingNeeds {
        try Scouting.needs(tactic: tactic, players: players, ownClub: "Oxford City", going: going, retraining: [],
                           catalog: catalog, profile: profile, parameters: .fm27)
    }
    /// Familiarity 20 at the slot's two positions, then `also` at each other slot's two positions, then `edit`.
    func candidate(_ slot: SlotID, level: Int, also: [SlotID: Int] = [:], edit: (inout Player) -> Void = { _ in }) -> Player {
        let assignments = try! tactic.assignments(catalog: catalog)
        func set(_ player: inout Player, _ slot: SlotID, _ value: Int) {
            let a = assignments.first { $0.slot == slot }!
            player.familiarity[a.ipPosition] = value
            player.familiarity[a.oopPosition] = value
        }
        var player = Player.fixture(name: "Candidate", all: level, club: "Wrexham")
        set(&player, slot, 20)
        for (other, value) in also.sorted(by: { $0.key.rawValue < $1.key.rawValue }) { set(&player, other, value) }
        edit(&player)
        return player
    }
    func today(_ candidate: Player, players: [Player], going: [Going] = []) throws -> [CandidateSlot] {
        let goingIDs = Set(going.map(\.player))
        let staying = players.filter { !goingIDs.contains($0.id) }
        return try Scouting.slotsToday(for: candidate, tactic: tactic, needs: needs(players, going: going), squad: staying,
                                       ownClub: "Oxford City", catalog: catalog, profile: profile, parameters: .fm27)
    }
    /// The fixture squad with the left back's two players at the levels given, as in the needs tests.
    func squadWithAWeakLeftBack(first: Int = 12, second: Int = 10) throws -> [Player] {
        try PlannerFixture.squad().map { p in
            var p = p
            if p.name == PlannerFixture.name(.D_L, "first") { p.attributes = p.attributes.mapValues { _ in first } }
            if p.name == PlannerFixture.name(.D_L, "second") { p.attributes = p.attributes.mapValues { _ in second } }
            return p
        }
    }
    /// The ten first-tier players of the other slots, so that the slot has no first choice at all.
    func firstElevenWithout(_ slot: SlotID) throws -> [Player] {
        try PlannerFixture.squad().filter { p in
            SlotID.allCases.contains { $0 != slot && p.name == PlannerFixture.name($0, "first") }
        }
    }

    @Test func eachLevelTodayOnEachSideOfItsLine() throws {
        let players = try PlannerFixture.squad()                       // first choices at 14, second at 12
        func level(_ all: Int) throws -> CandidateLevel { try #require(today(candidate(.D_L, level: all), players: players).first).level }
        #expect(try level(15) == .wouldStart)
        #expect(try level(14) == .wouldStart)                          // level with the first choice
        #expect(try level(13) == .wouldMakeSecond)
        #expect(try level(12) == .wouldMakeSecond)                     // level with the second choice
        #expect(try level(4) == .belowCover)
    }
    /// Under the second choice (at 13) he is cover down to 80% of the first choice (at 14), and below cover under it.
    @Test func underTheSecondChoiceHeIsCoverDownToTheCoverShare() throws {
        let players = try PlannerFixture.squad(second: 13)
        let cover = try #require(today(candidate(.D_L, level: 12), players: players).first)
        #expect(cover.level == .wouldCountAsCover)
        #expect(try #require(today(candidate(.D_L, level: 9), players: players).first).level == .belowCover)
        let first = try #require(try needs(players).elevens.first.first { $0.slot == .D_L }).rating.value
        #expect(abs((cover.marginOverFirst ?? 0) - (cover.rating / first - 1)) < 1e-9)
        #expect(cover.firstChoice?.name == PlannerFixture.name(.D_L, "first"))
    }
    @Test func withNoSecondChoiceInPositionHeMakesTheSecondEleven() throws {
        let players = try PlannerFixture.squad().filter { $0.name != PlannerFixture.name(.D_L, "second") }
        #expect(try #require(today(candidate(.D_L, level: 9), players: players).first).level == .wouldMakeSecond)
    }
    @Test func aSlotHeCannotPlayIsNotJudged() throws {
        let c = candidate(.D_L, level: 14, also: [.D_R: 9])
        #expect(try today(c, players: PlannerFixture.squad()).map(\.slot) == [.D_L])
        let both = candidate(.D_L, level: 14, also: [.D_R: 10])
        let slots = try today(both, players: PlannerFixture.squad())
        #expect(slots.map(\.slot) == [.D_L, .D_R])
        #expect(slots[0].isSolid && !slots[1].isSolid && slots[1].ipFamiliarity == 10)
    }
    @Test func atASlotWithNoFirstChoiceAnyoneWouldStart() throws {
        let players = try firstElevenWithout(.D_L)
        #expect(try needs(players).elevens.unfilledFirst == [.D_L])
        let slot = try #require(today(candidate(.D_L, level: 4), players: players).first)
        #expect(slot.level == .wouldStart && slot.firstChoice == nil && slot.marginOverFirst == nil)
        #expect(slot.answers.contains(.betterPlayerToday) && slot.stillWeakBy != nil)
        #expect(try #require(today(candidate(.D_L, level: 14), players: players).first).stillWeakBy == nil)
    }
    /// With the left back's two players gone, someone fills in there out of position: the candidate is compared with him.
    @Test func aFirstChoiceOutOfPositionIsComparedLikeAnyOther() throws {
        let players = try PlannerFixture.squad().filter { !$0.name.hasPrefix(SlotID.D_L.rawValue + " ") }
        let place = try #require(try needs(players).elevens.first.first { $0.slot == .D_L })
        #expect(place.isOutOfPosition)
        let slot = try #require(today(candidate(.D_L, level: 14), players: players).first)
        #expect(slot.level == .wouldStart && slot.firstChoice?.name == place.name && (slot.marginOverFirst ?? 0) > 0)
        #expect(slot.answers.contains(.betterPlayerToday))
    }
    @Test func heAnswersABetterPlayerNeedOnlyWhereHeWouldStart() throws {
        let players = try squadWithAWeakLeftBack()
        #expect(try #require(today(candidate(.D_L, level: 14), players: players).first).answers == [.betterPlayerToday])
        #expect(try #require(today(candidate(.D_L, level: 11), players: players).first).answers.isEmpty)
        // Better than a weak first choice at 10 and still far under the others at 14: he answers it, and the slot stays weak.
        let weaker = try squadWithAWeakLeftBack(first: 10, second: 9)
        let slot = try #require(today(candidate(.D_L, level: 11), players: weaker).first)
        #expect(slot.answers == [.betterPlayerToday] && (slot.stillWeakBy?.gap ?? 0) > 0.05)
    }
    @Test func heAnswersADepthNeedOnlyWhenHeCountsAndIsSolid() throws {
        let players = try PlannerFixture.squad().filter { $0.name != PlannerFixture.name(.D_L, "second") }
        #expect(try #require(today(candidate(.D_L, level: 12), players: players).first).answers == [.moreDepth])
        // With nobody in position second, a level-4 player "would make the second eleven", yet does not count as cover.
        let weak = try #require(today(candidate(.D_L, level: 4), players: players).first)
        #expect(weak.level == .wouldMakeSecond && weak.answers.isEmpty)
        let notSolid = candidate(.D_L, level: 12, also: [.D_L: 14])
        #expect(try #require(today(notSolid, players: players).first).answers.isEmpty)
        // At a slot with no need he answers nothing.
        #expect(try #require(today(candidate(.D_L, level: 15), players: PlannerFixture.squad()).first).answers.isEmpty)
    }
    @Test func aCandidateOnLoanAtAThirdClubIsJudged() throws {
        let c = candidate(.D_L, level: 14) { $0.loanedTo = "Barnet" }
        #expect(try today(c, players: PlannerFixture.squad()).count == 1)
    }
    @Test func aMissingFamiliarityIsAnErrorNamingThePlayer() throws {
        var c = candidate(.D_L, level: 14)
        let position = try #require(try tactic.assignments(catalog: catalog).first { $0.slot == .D_L }?.ipPosition)
        c.familiarity[position] = nil
        #expect(throws: RatingError.missingFamiliarity(player: "Candidate", position: position)) {
            try today(c, players: PlannerFixture.squad())
        }
    }
    @Test func heldPlayersAreToldByIdClubOrNameAgeAndPotential() throws {
        let held = [Player.fixture(name: "Sam Reed", age: 22, potentialAbility: 130)].map { p in var p = p; p.id = .fmrte(7); return p }
        func pasted(_ edit: (inout Player) -> Void) -> Player { var p = Player.fixture(name: "Other", club: "Wrexham"); edit(&p); return p }
        func isHeld(_ p: Player) -> Bool { Scouting.isHeld(p, among: held, ownClub: "Oxford City") }
        #expect(isHeld(pasted { $0.id = .fmrte(7) }))
        #expect(!isHeld(pasted { $0.id = .fmrte(8) }))
        #expect(isHeld(pasted { $0.club = "oxford  city" }))
        #expect(isHeld(pasted { $0.loanedTo = "Oxford City" }))
        #expect(isHeld(pasted { $0.name = "Sam Reed"; $0.age = 22; $0.potentialAbility = 130 }))
        #expect(!isHeld(pasted { $0.name = "Sam Reed"; $0.age = 23; $0.potentialAbility = 130 }))
    }
    /// A squad imported without the Id column and a search paste both key by name: a namesake at another club stays.
    @Test func aNamesakeAtAnotherClubIsNotHeld() {
        let held = [Player.fixture(name: "Sam Reed", age: 22, potentialAbility: 130)]
        let namesake = Player.fixture(name: "Sam Reed", age: 27, potentialAbility: 110, club: "Wrexham")
        #expect(namesake.id == held[0].id)
        #expect(!Scouting.isHeld(namesake, among: held, ownClub: "Oxford City"))
    }
    @Test func eachCautionOnEachSideOfItsLine() throws {
        func cautions(_ attributes: [Attribute: Int]) throws -> [CandidateCaution] {
            try Scouting.cautions(for: Player.fixture(all: 10, attributes: attributes), parameters: .fm27)
        }
        #expect(try cautions([:]).isEmpty)
        #expect(try cautions([.consistency: 7]) == [CandidateCaution(attribute: .consistency, value: 7)])
        #expect(try cautions([.consistency: 8]).isEmpty)
        #expect(try cautions([.importantMatches: 7]).map(\.attribute) == [.importantMatches])
        #expect(try cautions([.injuryProneness: 15]).map(\.attribute) == [.injuryProneness])
        #expect(try cautions([.injuryProneness: 14]).isEmpty)
        #expect(try cautions([.controversy: 17]).map(\.attribute) == [.controversy])
        #expect(try cautions([.temperament: 7]).map(\.attribute) == [.temperament])
        #expect(try cautions([.professionalism: 7]).map(\.attribute) == [.professionalism])
        #expect(try cautions([.professionalism: 7, .consistency: 3]).map(\.attribute) == [.consistency, .professionalism])
    }
    @Test func aCandidateWithoutAHiddenAttributeIsAnError() {
        var c = Player.fixture(name: "No Data"); c.attributes[.consistency] = nil
        #expect(throws: RatingError.missingAttribute(player: "No Data", attribute: .consistency)) {
            try Scouting.cautions(for: c, parameters: .fm27)
        }
    }

    // MARK: Where a candidate could reach, and the list

    func report(_ pasted: [Player], hidden: [HiddenCandidate] = [], players: [Player],
                going: [Going] = []) throws -> CandidatesReport {
        try Scouting.candidates(pasted: pasted, held: players, hidden: hidden, ownClub: "Oxford City", tactic: tactic,
                                       needs: needs(players, going: going), catalog: catalog, profile: profile,
                                       parameters: .fm27)
    }
    @Test func aCandidateOfTwentyThreeHasALaterAndOneOfTwentyFourHasNone() throws {
        let players = try PlannerFixture.squad()
        let young = try #require(report([candidate(.D_L, level: 12) { $0.age = 23; $0.potentialAbility = 160 }], players: players).candidates.first)
        #expect(young.outlook != nil && young.slots[0].later != nil && young.outlook?.best?.slot == .D_L)
        let older = try #require(report([candidate(.D_L, level: 12) { $0.age = 24; $0.potentialAbility = 160 }], players: players).candidates.first)
        #expect(older.outlook == nil && older.slots[0].later == nil && !older.isAgeNamed)
        #expect(try #require(report([candidate(.D_L, level: 12) { $0.age = 30 }], players: players).candidates.first).isAgeNamed)
    }
    /// His outlook at the slot is what a squad player with his numbers would get there.
    @Test func theLaterIsTheOutlookCodesOwn() throws {
        let players = try PlannerFixture.squad()
        let c = candidate(.D_L, level: 12) { $0.age = 19; $0.potentialAbility = 190 }
        let slot = try #require(report([c], players: players).candidates.first?.slots.first)
        let later = try #require(slot.later)
        #expect(later.level == .couldPassFirst && later.firstChoice?.name == PlannerFixture.name(.D_L, "first"))
        #expect(later.rating == slot.rating && later.reachRating > slot.rating)
        let capped = candidate(.D_L, level: 4) { $0.age = 19; $0.potentialAbility = 101 }
        #expect(try #require(report([capped], players: players).candidates.first?.slots.first?.later).level == .markedlyLower)
    }
    @Test func aFirstChoiceWhoIsDevelopingIsComparedAtHisOwnReach() throws {
        let first = PlannerFixture.name(.D_L, "first")
        let players = try PlannerFixture.squad().map { p in var p = p; if p.name == first { p.age = 19; p.potentialAbility = 190 }; return p }
        let c = candidate(.D_L, level: 13) { $0.age = 22; $0.potentialAbility = 110 }
        let rival = try #require(report([c], players: players).candidates.first?.slots.first?.later?.firstChoice)
        #expect(rival.compared > rival.rating)
    }
    @Test func theHeadlineSlotFollowsItsRule() throws {
        // Weak left back (a better-player need) and no second right back (a depth need).
        let players = try squadWithAWeakLeftBack().filter { $0.name != PlannerFixture.name(.D_R, "second") }
        func headline(_ c: Player) throws -> (SlotID?, NeedAnswer?, CandidatePart) {
            let r = try #require(report([c], players: players).candidates.first); return (r.headline, r.headlineAnswer, r.part)
        }
        #expect(try headline(candidate(.D_L, level: 14, also: [.D_R: 20])) == (.D_L, .betterPlayerToday, .answersToday))
        #expect(try headline(candidate(.D_R, level: 12)) == (.D_R, .moreDepth, .answersToday))
        // Under the first choice at 12 today, and expected to pass him.
        let prospect = candidate(.D_L, level: 11) { $0.age = 18; $0.potentialAbility = 190 }
        #expect(try headline(prospect) == (.D_L, .betterPlayerLater, .answersLater))
        #expect(try headline(candidate(.AM_C, level: 15)) == (.AM_C, nil, .wouldStartElsewhere))
        #expect(try headline(candidate(.AM_C, level: 13)) == (.AM_C, nil, .rest))
        let nowhere = Player.fixture(name: "Nowhere", club: "Wrexham")
        #expect(try headline(nowhere) == (nil, nil, .rest))
    }
    @Test func theGroupsComeInTheirOrderWithEachCandidateOnce() throws {
        let players = try squadWithAWeakLeftBack().filter { $0.name != PlannerFixture.name(.D_R, "second") }
        func c(_ name: String, _ slot: SlotID, _ level: Int, _ edit: @escaping (inout Player) -> Void = { _ in }) -> Player {
            candidate(slot, level: level) { $0.name = name; $0.id = PlayerID(key: name); edit(&$0) }
        }
        let pasted = [c("rest", .AM_C, 13), c("elsewhere", .AM_C, 15), c("later", .D_L, 11) { $0.age = 18; $0.potentialAbility = 190 },
                      c("depth", .D_R, 12), c("better b", .D_L, 14), c("better a", .D_L, 15)]
        let groups = try report(pasted, players: players).groups(orderedBy: .today)
        #expect(groups.map(\.part) == [.answersToday, .answersToday, .answersLater, .wouldStartElsewhere, .rest])
        #expect(groups.map(\.slot) == [.D_L, .D_R, .D_L, nil, nil])
        #expect(groups.map(\.answer) == [.betterPlayerToday, .moreDepth, .betterPlayerLater, nil, nil])
        #expect(groups[0].candidates.map(\.player.name) == ["better a", "better b"])
        #expect(groups.flatMap(\.candidates).count == 6)
    }
    @Test func theLaterOrderRanksByReachInsideAGroupAndMovesNobodyBetweenGroups() throws {
        let players = try squadWithAWeakLeftBack()
        let now = candidate(.D_L, level: 15) { $0.name = "now"; $0.id = PlayerID(key: "now"); $0.age = 28 }
        let grower = candidate(.D_L, level: 14) { $0.name = "grower"; $0.id = PlayerID(key: "grower"); $0.age = 19; $0.potentialAbility = 190 }
        let r = try report([now, grower], players: players)
        #expect(r.groups(orderedBy: .today).first?.candidates.map(\.player.name) == ["now", "grower"])
        #expect(r.groups(orderedBy: .later).first?.candidates.map(\.player.name) == ["grower", "now"])
        #expect(r.groups(orderedBy: .later).map(\.part) == r.groups(orderedBy: .today).map(\.part))
    }
    @Test func heldPlayersAreLeftOutAndNamed() throws {
        let players = try PlannerFixture.squad()
        let mine = candidate(.D_L, level: 14) { $0.name = "Mine"; $0.id = PlayerID(key: "mine"); $0.club = "Oxford City" }
        let r = try report([mine, candidate(.D_L, level: 14)], players: players)
        #expect(r.leftOut == ["Mine"] && r.candidates.map(\.player.name) == ["Candidate"])
    }
    @Test func twoPastedNamesakesAreBothJudged() throws {
        let a = candidate(.D_L, level: 14) { $0.id = PlayerID(key: "candidate#120") }
        let b = candidate(.D_L, level: 13) { $0.id = PlayerID(key: "candidate#130"); $0.potentialAbility = 130 }
        let r = try report([a, b], players: PlannerFixture.squad())
        #expect(r.candidates.count == 2 && Set(r.candidates.map(\.id)).count == 2)
        #expect(r.groups(orderedBy: .today).flatMap(\.candidates).count == 2)
    }
    @Test func atASlotWithNoFirstChoiceTheReachIsSetAgainstTheWeakLine() throws {
        let players = try firstElevenWithout(.D_L)
        let grower = candidate(.D_L, level: 12) { $0.age = 19; $0.potentialAbility = 190 }
        let r = try #require(report([grower], players: players).candidates.first)
        #expect(r.slots[0].later?.level == nil && r.reachClearsWeakLine == true)
        let capped = candidate(.D_L, level: 4) { $0.age = 19; $0.potentialAbility = 101 }
        #expect(try #require(report([capped], players: players).candidates.first).reachClearsWeakLine == false)
    }
    @Test func theSameInputsGiveTheSameReport() throws {
        let players = try squadWithAWeakLeftBack()
        let pasted = [candidate(.D_L, level: 14), candidate(.AM_C, level: 15) { $0.name = "B"; $0.id = PlayerID(key: "b") }]
        #expect(try report(pasted, players: players) == (try report(pasted, players: players.reversed())))
    }
    @Test func theLastTwoGroupsAreRankedByMarginAndTiesFallToTheKey() throws {
        let players = try PlannerFixture.squad()
        func c(_ name: String, _ level: Int) -> Player {
            candidate(.AM_C, level: level) { $0.name = name; $0.id = PlayerID(key: name) }
        }
        let nowhere = Player.fixture(name: "Nowhere", club: "Wrexham")
        let pasted = [nowhere, c("b", 13), c("a", 13), c("far", 15), c("near", 14), c("low", 12)]
        for order in CandidateOrder.allCases {
            let groups = try report(pasted, players: players).groups(orderedBy: order)
            #expect(groups.map(\.part) == [.wouldStartElsewhere, .rest])
            #expect(groups[0].candidates.map(\.player.name) == ["far", "near"])
            #expect(groups[1].candidates.map(\.player.name) == ["a", "b", "low", "Nowhere"])
        }
    }
    /// The goalkeeper's reach is taken as ability through the offset (70) against the weak share (0.95) of the outfield
    /// first choices' average of offset + ability (the fixture squad's abilities are 100: 0.95 x 170 = 161.5): a reach
    /// of 92 or more clears it, 91 or less does not. The first goalkeeper reaches exactly 100, which clears it only with
    /// the offset (100 alone is under 161.5); the second is capped at 80, which falls short.
    @Test func atTheGoalkeepersSlotTheReachIsSetAgainstTheWeakLineByAbility() throws {
        let players = try firstElevenWithout(.GK)
        let reaches = candidate(.GK, level: 12) { $0.age = 19; $0.currentAbility = 95; $0.potentialAbility = 100 }
        let r = try #require(report([reaches], players: players).candidates.first)
        #expect(r.headline == .GK && r.slots[0].firstChoice == nil && r.reachClearsWeakLine == true)
        let capped = candidate(.GK, level: 12) { $0.age = 19; $0.currentAbility = 80; $0.potentialAbility = 80 }
        #expect(try #require(report([capped], players: players).candidates.first).reachClearsWeakLine == false)
    }
    // MARK: The headline slot, the five parts and their orders

    /// The fixture squad with the named players' every attribute set to the level given, and those in `without` gone.
    func squad(levels: [String: Int] = [:], without: Set<String> = []) throws -> [Player] {
        try PlannerFixture.squad().filter { !without.contains($0.name) }.map { p in
            var p = p
            if let level = levels[p.name] { p.attributes = p.attributes.mapValues { _ in level } }
            return p
        }
    }
    func named(_ slot: SlotID, _ tier: String) -> String { PlannerFixture.name(slot, tier) }
    func pasted(_ name: String, _ slot: SlotID, _ level: Int, also: [SlotID: Int] = [:], age: Int = 25,
                potential: Int = 120) -> Player {
        candidate(slot, level: level, also: also) {
            $0.name = name; $0.id = PlayerID(key: name); $0.age = age; $0.potentialAbility = potential
        }
    }
    func judged(_ c: Player, players: [Player]) throws -> Candidate {
        try #require(report([c], players: players).candidates.first)
    }

    /// Left back at 13 is weak (the others at 14), and right back has no second choice (a depth need). At 12 he is
    /// under the left back today and could pass him later, and counts as cover at right back: depth comes first.
    @Test func aDepthNeedTodayBeatsABetterPlayerNeedLater() throws {
        let players = try squad(levels: [named(.D_L, "first"): 13], without: [named(.D_R, "second")])
        let needs = try needs(players)
        #expect(needs.betterPlayers.map(\.slot) == [.D_L] && needs.moreDepth.map(\.depth.slot) == [.D_R])
        let c = try judged(pasted("both", .D_L, 12, also: [.D_R: 20], age: 18, potential: 190), players: players)
        #expect(try #require(c.slots.first { $0.slot == .D_L }).answers == [.betterPlayerLater])
        #expect(c.headline == .D_R && c.headlineAnswer == .moreDepth && c.part == .answersToday)
    }
    /// Right back at 11 is the larger gap, so it comes before left back at 12 in the needs, while left back comes first
    /// in the tactic: a candidate who would start at both is headed by right back.
    @Test func theFirstBetterPlayerSlotIsTakenInNeedOrder() throws {
        let players = try squad(levels: [named(.D_L, "first"): 12, named(.D_L, "second"): 10,
                                         named(.D_R, "first"): 11, named(.D_R, "second"): 10])
        #expect(try needs(players).betterPlayers.map(\.slot) == [.D_R, .D_L])
        let c = try judged(pasted("both", .D_L, 14, also: [.D_R: 20]), players: players)
        #expect(c.slots.map(\.slot) == [.D_L, .D_R] && c.headline == .D_R && c.headlineAnswer == .betterPlayerToday)
    }
    /// No needs. At 15 he would start at attacking midfield (first at 14) and could pass the left back (raised to 16)
    /// later: would start comes first.
    @Test func wouldStartBeatsCouldPassElsewhere() throws {
        let players = try squad(levels: [named(.D_L, "first"): 16])
        #expect(try needs(players).betterPlayers.isEmpty)
        let c = try judged(pasted("young", .D_L, 15, also: [.AM_C: 20], age: 19, potential: 190), players: players)
        #expect(try #require(c.slots.first { $0.slot == .D_L }).later?.level == .couldPassFirst)
        #expect(c.headline == .AM_C && c.part == .wouldStartElsewhere)
    }
    /// A young player under the first choice at a slot with no need: could pass him later, or not.
    @Test func aCouldPassLaterWhereThereIsNoNeedIsItsOwnPart() throws {
        let players = try PlannerFixture.squad()
        let grower = try judged(pasted("grower", .AM_C, 13, age: 19, potential: 190), players: players)
        let slot = try #require(grower.slots.first)
        #expect(slot.later?.level == .couldPassFirst && !slot.answers.contains(.betterPlayerLater))
        #expect(grower.headline == .AM_C && grower.headlineAnswer == nil && grower.part == .couldPassElsewhere)
        let capped = try judged(pasted("capped", .AM_C, 13, age: 19, potential: 101), players: players)
        #expect(capped.slots.first?.later?.level != .couldPassFirst && capped.part == .rest)
    }
    /// The fallback: the better level wins over the tactic's order, then the greater margin, then the earlier slot.
    @Test func theFallbackTakesTheBestLevelThenTheMarginThenTheTacticsOrder() throws {
        // At 11 he is under the left back's second (12); the attacking midfielder's second is lowered to 11, still
        // cover there, so the slot needs nothing.
        let players = try squad(levels: [named(.AM_C, "second"): 11])
        #expect(try needs(players).moreDepth.isEmpty && (try needs(players)).betterPlayers.isEmpty)
        let level = try judged(pasted("p", .D_L, 11, also: [.AM_C: 20]), players: players)
        #expect(level.slots.map(\.level) == [.wouldCountAsCover, .wouldMakeSecond])
        #expect(level.headline == .AM_C && level.part == .rest)
        // Level with the second choice at both; the attacking midfielder's first is lowered to 13: the smaller gap.
        let margin = try judged(pasted("p", .D_L, 12, also: [.AM_C: 20]),
                                players: squad(levels: [named(.AM_C, "first"): 13]))
        #expect(margin.slots.map(\.level) == [.wouldMakeSecond, .wouldMakeSecond] && margin.headline == .AM_C)
        // The same at both backs: the earlier slot.
        let tie = try judged(pasted("p", .D_L, 12, also: [.D_R: 20]), players: PlannerFixture.squad())
        #expect(tie.slots.map(\.level) == [.wouldMakeSecond, .wouldMakeSecond] && tie.headline == .D_L)
    }
    /// Left back: first choice raised to 20 and no second choice, so at 12 he makes the second eleven only because
    /// nobody in position is there, rating under the cover share. Right back: second raised to 13, so at 12 he is real
    /// cover. The place he holds only by default ranks below cover.
    @Test func aSecondElevenPlaceUnderTheCoverShareRanksBelowCover() throws {
        let players = try squad(levels: [named(.D_L, "first"): 20, named(.D_R, "second"): 13],
                                without: [named(.D_L, "second")])
        let c = try judged(pasted("p", .D_L, 12, also: [.D_R: 20]), players: players)
        #expect(c.slots.map(\.level) == [.wouldMakeSecond, .wouldCountAsCover])
        #expect(c.headline == .D_R && c.part == .rest)
        // At 17 he is within the share at left back, and its second-eleven place ranks above cover again.
        let near = try judged(pasted("p", .D_L, 17, also: [.D_R: 20]), players: players)
        #expect(near.slots.first?.level == .wouldMakeSecond && near.headline == .D_L)
    }

    func order(_ list: [Player], players: [Player], _ order: CandidateOrder) throws -> [[String]] {
        try report(list, players: players).groups(orderedBy: order).map { $0.candidates.map(\.player.name) }
    }
    /// Part 1: today by rating, later by reach rating.
    @Test func answersTodayIsOrderedByRatingThenByReach() throws {
        let players = try squadWithAWeakLeftBack()
        let list = [pasted("now", .D_L, 15, age: 28), pasted("grower", .D_L, 14, age: 19, potential: 190)]
        #expect(try report(list, players: players).candidates.allSatisfy { $0.part == .answersToday })
        #expect(try order(list, players: players, .today) == [["now", "grower"]])
        #expect(try order(list, players: players, .later) == [["grower", "now"]])
    }
    /// Part 2: by reach rating in both orders, though "b" rates higher today.
    @Test func answersLaterIsOrderedByReachInBothOrders() throws {
        let players = try squadWithAWeakLeftBack()
        let list = [pasted("b", .D_L, 11, age: 18, potential: 130), pasted("a", .D_L, 10, age: 18, potential: 190)]
        let r = try report(list, players: players)
        #expect(r.candidates.allSatisfy { $0.part == .answersLater })
        #expect(r.candidates[0].slots[0].rating > r.candidates[1].slots[0].rating)
        #expect(try order(list, players: players, .today) == [["a", "b"]])
        #expect(try order(list, players: players, .later) == [["a", "b"]])
    }
    /// Part 3: today by margin, later by reach margin.
    @Test func wouldStartElsewhereIsOrderedByMarginThenByReachMargin() throws {
        let players = try PlannerFixture.squad()
        let list = [pasted("now", .AM_C, 16, age: 28), pasted("grower", .AM_C, 15, age: 19, potential: 190)]
        #expect(try report(list, players: players).candidates.allSatisfy { $0.part == .wouldStartElsewhere })
        #expect(try order(list, players: players, .today) == [["now", "grower"]])
        #expect(try order(list, players: players, .later) == [["grower", "now"]])
    }
    /// Part 4: by reach margin in both orders, though "b" rates higher today.
    @Test func couldPassElsewhereIsOrderedByReachMarginInBothOrders() throws {
        let players = try PlannerFixture.squad()
        let list = [pasted("b", .AM_C, 13, age: 19, potential: 130), pasted("a", .AM_C, 12, age: 19, potential: 190)]
        let r = try report(list, players: players)
        #expect(r.candidates.allSatisfy { $0.part == .couldPassElsewhere })
        #expect((r.candidates[0].slots[0].marginOverFirst ?? 0) > (r.candidates[1].slots[0].marginOverFirst ?? 0))
        #expect(try order(list, players: players, .today) == [["a", "b"]])
        #expect(try order(list, players: players, .later) == [["a", "b"]])
    }
    /// Part 5: today by margin, later by reach margin; a young player whose reach stays under the first choice can still
    /// come first by it. Those who play no slot come last in both.
    @Test func theRestIsOrderedByMarginThenByReachMargin() throws {
        let players = try PlannerFixture.squad()
        let list = [Player.fixture(name: "Nowhere", club: "Wrexham"), pasted("steady", .AM_C, 13, age: 28),
                    pasted("grower", .AM_C, 12, age: 19, potential: 114)]
        let r = try report(list, players: players)
        #expect(r.candidates.allSatisfy { $0.part == .rest })
        #expect(try order(list, players: players, .today) == [["steady", "grower", "Nowhere"]])
        #expect(try order(list, players: players, .later) == [["grower", "steady", "Nowhere"]])
    }

    // The one-sided tests.
    @Test func cautionsOnTheirLineAreNotGiven() throws {
        func cautions(_ attributes: [Attribute: Int]) throws -> [CandidateCaution] {
            try Scouting.cautions(for: Player.fixture(all: 10, attributes: attributes), parameters: .fm27)
        }
        #expect(try cautions([.importantMatches: 8]).isEmpty)
        #expect(try cautions([.controversy: 16]).isEmpty)
        #expect(try cautions([.temperament: 8]).isEmpty)
        #expect(try cautions([.professionalism: 8]).isEmpty)
    }
    /// The goalkeeper's slot has nobody; at ability 60 against the outfield's 100 he leaves it weak, by ability.
    @Test func atTheGoalkeepersSlotStillWeakIsByAbility() throws {
        let players = try firstElevenWithout(.GK)
        let weak = try #require(today(candidate(.GK, level: 12) { $0.currentAbility = 60 }, players: players).first)
        #expect(weak.answers.contains(.betterPlayerToday))
        #expect(weak.stillWeakBy == WeakGap(gap: 1 - 130.0 / 170.0, measure: .ability(his: 60, average: 100)))
        #expect(try #require(today(candidate(.GK, level: 12), players: players).first).stillWeakBy == nil)
    }
    @Test func aPastedPlayerOnLoanAtAThirdClubIsNotHeld() throws {
        let c = candidate(.D_L, level: 14) { $0.loanedTo = "Barnet" }
        #expect(!Scouting.isHeld(c, among: try PlannerFixture.squad(), ownClub: "Oxford City"))
        #expect(try report([c], players: PlannerFixture.squad()).candidates.count == 1)
    }
    @Test func atASlotWithNoFirstChoiceOnlyASolidCandidateAnswersTheDepthNeed() throws {
        let players = try firstElevenWithout(.D_L)
        #expect(try needs(players).moreDepth.contains { $0.depth.slot == .D_L })
        #expect(try #require(today(candidate(.D_L, level: 12), players: players).first).answers.contains(.moreDepth))
        let notSolid = candidate(.D_L, level: 12, also: [.D_L: 14])
        let slot = try #require(today(notSolid, players: players).first)
        #expect(!slot.answers.contains(.moreDepth) && slot.answers.contains(.betterPlayerToday))
    }
    @Test func theReportCarriesTheWeakestEvidenceAmongItsCandidates() throws {
        let players = try PlannerFixture.squad()
        let mine = candidate(.D_L, level: 14) { $0.club = "Oxford City" }
        #expect(try report([mine], players: players).basis == nil)
        let r = try report([candidate(.D_L, level: 14), pasted("young", .AM_C, 12, age: 19, potential: 150)], players: players)
        #expect(r.basis == Evidence.weakest(r.candidates.map(\.basis)) && r.basis == .derived)
    }

    // MARK: Hidden players

    @Test func aHiddenPlayerIsLeftOutAndReturnedApart() throws {
        let players = try PlannerFixture.squad()
        let a = candidate(.D_L, level: 15) { $0.name = "Abdi Sharif"; $0.id = PlayerID(key: "abdi sharif"); $0.potentialAbility = 120 }
        let b = candidate(.D_L, level: 15) { $0.name = "Brad Walker"; $0.id = PlayerID(key: "brad walker"); $0.potentialAbility = 120 }
        let r = try report([a, b], hidden: [HiddenCandidate(a)], players: players)
        #expect(r.candidates.map(\.player.name) == ["Brad Walker"])
        #expect(r.hidden == [a])
        #expect(r.groups(orderedBy: .today).flatMap(\.candidates).map(\.player.name) == ["Brad Walker"])
    }
    @Test func withNobodyHiddenTheReportIsAsBefore() throws {
        let players = try PlannerFixture.squad()
        let a = candidate(.D_L, level: 15)
        let r = try report([a], hidden: [], players: players)
        #expect(r.candidates.count == 1 && r.hidden.isEmpty)
        // Hiding somebody else changes nothing for him.
        let other = try report([a], hidden: [HiddenCandidate(name: "Somebody Else", potentialAbility: a.potentialAbility)],
                               players: players)
        #expect(other.candidates == r.candidates && other.hidden.isEmpty)
    }
    @Test func aHiddenPlayerIsKnownByNameAsNormalisedAndPotentialAbilityOnly() {
        let p = candidate(.D_L, level: 15) { $0.name = "Abdi Sharif"; $0.potentialAbility = 120; $0.age = 26 }
        #expect(HiddenCandidate(name: "abdi  SHARIF", potentialAbility: 120).matches(p))   // as PlayerID.normalise compares
        #expect(!HiddenCandidate(name: "Abdi Sharif", potentialAbility: 121).matches(p))   // a namesake
        #expect(!HiddenCandidate(name: "Abdi Sharifi", potentialAbility: 120).matches(p))
        var older = p; older.age = 27
        #expect(HiddenCandidate(p).matches(older))                                          // a birthday changes nothing
        #expect(HiddenCandidate(p) == HiddenCandidate(name: "Abdi Sharif", potentialAbility: 120))   // the name as pasted
        #expect(Scouting.isHidden(p, among: [HiddenCandidate(p)]) && !Scouting.isHidden(p, among: []))
    }
    @Test func aHeldPlayerWhoIsAlsoHiddenIsLeftOutAsHeld() throws {
        let players = try PlannerFixture.squad()
        let own = try #require(players.first)
        let r = try report([own], hidden: [HiddenCandidate(own)], players: players)
        #expect(r.leftOut == [own.name] && r.hidden.isEmpty)
    }
    @Test func hiddenPlayersDoNotCountTowardsTheEvidence() throws {
        let players = try PlannerFixture.squad()
        let a = candidate(.D_L, level: 15)
        let r = try report([a], hidden: [HiddenCandidate(a)], players: players)
        #expect(r.candidates.isEmpty && r.basis == nil && r.hidden.count == 1)
    }
    /// A hidden player is not judged: one who could not be rated stops nothing while he is hidden.
    @Test func aHiddenPlayerIsNotJudged() throws {
        let players = try PlannerFixture.squad()
        let broken = candidate(.D_L, level: 15) { $0.attributes[.consistency] = nil }
        #expect(throws: (any Error).self) { try report([broken], players: players) }
        #expect(try report([broken], hidden: [HiddenCandidate(broken)], players: players).hidden == [broken])
    }
    @Test func aHiddenCandidateRoundTripsAsJSONAndNeedsBothKeys() throws {
        let h = HiddenCandidate(name: "Abdi Sharif", potentialAbility: 120)
        #expect(try JSONDecoder().decode(HiddenCandidate.self, from: JSONEncoder().encode(h)) == h)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(HiddenCandidate.self, from: Data(#"{"name":"A"}"#.utf8)) }
    }
}
