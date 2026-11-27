import Foundation
import Testing
@testable import LineupEngine

@Suite struct ScoutingNeedsTests {
    let tactic = try! PlannerFixture.tactic()
    let catalog = try! RoleCatalog.fm27()
    let profile = try! RatingProfile.standard()

    func needs(_ players: [Player], going: [Going] = [], retraining: [Retraining] = []) throws -> ScoutingNeeds {
        try Scouting.needs(tactic: tactic, players: players, ownClub: "Oxford City", going: going, retraining: retraining,
                           catalog: catalog, profile: profile, parameters: .fm27)
    }
    /// The fixture squad with every attribute of the named players set to the level given.
    func squad(levels: [String: Int] = [:], edit: (inout Player) -> Void = { _ in }) throws -> [Player] {
        try PlannerFixture.squad().map { p in
            var p = p
            if let level = levels[p.name] { p.attributes = p.attributes.mapValues { _ in level } }
            edit(&p); return p
        }
    }
    func named(_ slot: SlotID, _ tier: String) -> String { PlannerFixture.name(slot, tier) }
    func kind(hasFirstChoice: Bool = true, isOutOfPosition: Bool = false, gap: Double? = 0, age: Int? = 25,
              hasSuccessor: Bool = false) -> BetterPlayerKind? {
        Scouting.betterPlayerKind(hasFirstChoice: hasFirstChoice, isOutOfPosition: isOutOfPosition, gap: gap, age: age,
                                  hasSuccessor: hasSuccessor, parameters: .fm27)
    }

    // The rule from numbers.
    @Test func aGapOfFivePercentOrMoreIsWeak() {
        #expect(kind(gap: 0.05) == .weak)
        #expect(kind(gap: 0.0499) == nil)
        #expect(kind(gap: -0.10) == nil)
    }
    @Test func aFirstChoiceOfThirtyWithNoSuccessorIsAgeing() {
        #expect(kind(age: 30) == .ageing)
        #expect(kind(age: 29) == nil)
        #expect(kind(age: 34, hasSuccessor: true) == nil)
    }
    @Test func noFirstChoiceOrOneOutOfPositionIsNobody() {
        #expect(kind(hasFirstChoice: false, gap: nil, age: nil) == .nobody)
        #expect(kind(isOutOfPosition: true, gap: nil) == .nobody)
    }
    @Test func theFirstRuleThatHoldsWins() {
        #expect(kind(isOutOfPosition: true, gap: 0.2, age: 35) == .nobody)
        #expect(kind(gap: 0.2, age: 35) == .weak)
    }

    // Who is going.
    @Test func loaneesMarksAndAdviceAreGoing() throws {
        var players = try squad()
        players[0].club = "Banbury United"                      // on loan here
        let marked = players[1].id, advised = players[2].id
        let going = Scouting.going(players: players, ownClub: "Oxford City",
                                   marks: [marked: .toSell, players[3].id: .toLoanOut], advisedToLeave: [advised])
        #expect(Set(going.map(\.player)) == [players[0].id, marked, players[3].id, advised])
        #expect(going.first { $0.player == players[0].id }?.reason == .onLoanHere)
        #expect(going.first { $0.player == players[3].id }?.reason == .markedToLoanOut)
        #expect(going.map(\.player.key) == going.map(\.player.key).sorted())
    }
    @Test func aPlayerNotBeingRenewedIsGoingUnderTheLastReason() throws {
        let players = try squad()
        let alone = players[0].id, marked = players[1].id, advised = players[2].id
        let going = Scouting.going(players: players, ownClub: "Oxford City", marks: [marked: .toSell],
                                   advisedToLeave: [advised], notBeingRenewed: [alone, marked, advised])
        #expect(going.first { $0.player == alone }?.reason == .notBeingRenewed)
        #expect(going.first { $0.player == marked }?.reason == .markedToSell)
        #expect(going.first { $0.player == advised }?.reason == .advisedToLeave)
        #expect(going.count == 3)
    }
    @Test func withNobodyNotBeingRenewedTheGoingAreAsBefore() throws {
        let players = try squad()
        let marks: [PlayerID: SaleMark] = [players[1].id: .toSell]
        let before = Scouting.going(players: players, ownClub: "Oxford City", marks: marks, advisedToLeave: [players[2].id])
        let after = Scouting.going(players: players, ownClub: "Oxford City", marks: marks, advisedToLeave: [players[2].id],
                                   notBeingRenewed: [])
        #expect(before == after && before.count == 2)
    }
    @Test func aFirstChoiceNotBeingRenewedMakesHisSlotANeed() throws {
        let players = try squad(levels: [named(.ST_C, "second"): 10])
        let first = try #require(players.first { $0.name == named(.ST_C, "first") })
        let going = Scouting.going(players: players, ownClub: "Oxford City", marks: [:], advisedToLeave: [],
                                   notBeingRenewed: [first.id])
        let need = try #require(try needs(players, going: going).betterPlayers.first { $0.slot == .ST_C })
        #expect(need.goingFirstChoice == Going(player: first.id, name: first.name, reason: .notBeingRenewed))
    }
    @Test func aMarkOnAPlayerNotHeldIsIgnored() throws {
        let going = Scouting.going(players: try squad(), ownClub: "Oxford City",
                                   marks: [PlayerID(key: "gone"): .toSell], advisedToLeave: [PlayerID(key: "also gone")])
        #expect(going.isEmpty)
    }
    @Test func aPlayerWithTwoReasonsIsListedOnceWithTheFirst() throws {
        let players = try squad()
        let id = players[0].id
        let going = Scouting.going(players: players, ownClub: "Oxford City", marks: [id: .toSell], advisedToLeave: [id])
        #expect(going == [Going(player: id, name: players[0].name, reason: .markedToSell)])
    }

    // The needs.
    @Test func withNobodyGoingTheElevensAreTheElevensScreens() throws {
        let players = try squad()
        let r = try needs(players)
        #expect(r.elevens == (try Elevens.report(tactic: tactic, players: players, ownClub: "Oxford City",
                                                 catalog: catalog, profile: profile, parameters: .fm27)))
        #expect(r.going.isEmpty && r.betterPlayers.isEmpty && r.moreDepth.isEmpty)
        #expect(r.fine == (try tactic.assignments(catalog: catalog)).map(\.slot))
    }
    /// The left back's two players are lowered so that the better of them, at 12, is well under the others at 14.
    @Test func aFirstChoiceWellUnderTheOutfieldAverageIsWeak() throws {
        let r = try needs(squad(levels: [named(.D_L, "first"): 12, named(.D_L, "second"): 10]))
        let need = try #require(r.betterPlayers.first)
        #expect(r.betterPlayers.count == 1 && need.slot == .D_L && need.kind == .weak)
        #expect(need.firstChoice?.name == named(.D_L, "first"))
        guard case .rating(let his, let average)? = need.measure else { Issue.record("no rating measure"); return }
        #expect(his < average && abs((need.gap ?? 0) - (1 - his / average)) < 1e-9)
        #expect(need.goingFirstChoice == nil && need.easedBy == nil)
    }
    /// The goalkeeper's rating is on its own scale, so lowering his attributes alone must not make him weak;
    /// lowering his current ability does.
    @Test func theGoalkeeperIsComparedByAbilityNeverByRating() throws {
        let keeper = named(.GK, "first")
        let lowRated = try needs(squad(levels: [keeper: 13]))        // still first choice over the second at 12
        #expect(!lowRated.betterPlayers.contains { $0.slot == .GK })
        let lowAbility = try needs(squad { if $0.name == keeper { $0.currentAbility = 60 } })
        let need = try #require(lowAbility.betterPlayers.first { $0.slot == .GK })
        #expect(need.kind == .weak)
        #expect(need.measure == .ability(his: 60, average: 100))
        #expect(abs((need.gap ?? 0) - (1 - 130.0 / 170.0)) < 1e-9)   // both sides through the offset of 70
    }
    @Test func aGoalkeepersNeedIsEasedByAbility() throws {
        let keeper = named(.GK, "first")
        func players(potential: Int) throws -> [Player] {
            try squad { if $0.name == keeper { $0.currentAbility = 60; $0.age = 19; $0.potentialAbility = potential } }
        }
        #expect(try #require(try needs(players(potential: 190)).betterPlayers.first { $0.slot == .GK }).easedBy?.name == keeper)
        #expect(try #require(try needs(players(potential: 61)).betterPlayers.first { $0.slot == .GK }).easedBy == nil)
    }
    @Test func aGoingFirstChoiceIsNamedAndTheBestWhoStaysIsJudged() throws {
        let players = try squad(levels: [named(.ST_C, "second"): 10])
        let first = try #require(players.first { $0.name == named(.ST_C, "first") })
        let going = [Going(player: first.id, name: first.name, reason: .onLoanHere)]
        let need = try #require(try needs(players, going: going).betterPlayers.first { $0.slot == .ST_C })
        #expect(need.kind == .weak && need.firstChoice?.name == named(.ST_C, "second"))
        #expect(need.goingFirstChoice == going[0])
        // With a second choice as good as the rest, his going leaves no need.
        #expect(!(try needs(squad(levels: [named(.ST_C, "second"): 14]), going: going)).betterPlayers.contains { $0.slot == .ST_C })
    }
    @Test func aWeakNeedIsEasedByAYoungPlayerWhoseReachClearsTheLine() throws {
        let young = named(.D_L, "first")
        func players(potential: Int) throws -> [Player] {
            try squad(levels: [young: 12, named(.D_L, "second"): 10]) {
                if $0.name == young { $0.age = 19; $0.potentialAbility = potential }
            }
        }
        let eased = try #require(try needs(players(potential: 190)).betterPlayers.first)
        #expect(eased.kind == .weak && eased.easedBy?.name == young && eased.easedBy?.age == 19)
        let notEased = try #require(try needs(players(potential: 101)).betterPlayers.first)
        #expect(notEased.kind == .weak && notEased.easedBy == nil)
    }
    @Test func aReachClearsTheWeakLineByRatingAndByAbility() {
        // Lines of 95 by rating and 0.95 × 170 − 70 = 91.5 by ability.
        let averages = WeakLineAverages(rating: 100, ability: 170)
        func against(_ rating: Double, _ reach: Double, keeper: Bool = false) -> WeakLineReach? {
            averages.reachAgainstLine(isGoalkeeper: keeper, reachRating: rating, reach: reach, parameters: .fm27)
        }
        let short = against(96, 91)
        #expect(short?.clears == false && short?.reach == .rating(96))
        #expect(short?.shortByAbility?.reach == 91 && abs((short?.shortByAbility?.line ?? 0) - 91.5) < 1e-9)
        #expect(against(96, 92) == WeakLineReach(reach: .rating(96), clears: true, shortByAbility: nil))
        // Under by rating: not cleared, and nothing said of ability.
        #expect(against(94, 92) == WeakLineReach(reach: .rating(94), clears: false, shortByAbility: nil))
        // The goalkeeper's slot is measured by ability alone, as before.
        #expect(against(0, 92, keeper: true) == WeakLineReach(reach: .ability(92), clears: true, shortByAbility: nil))
        #expect(against(200, 91, keeper: true) == WeakLineReach(reach: .ability(91), clears: false, shortByAbility: nil))
        #expect(WeakLineAverages(rating: nil, ability: nil).reachAgainstLine(isGoalkeeper: false, reachRating: 96, reach: 92,
                                                                             parameters: .fm27) == nil)
    }
    /// Left back made weak (its first choice at level 12, of ability 100); its second choice is a young player of 19 at
    /// level 11, ability 60 and potential `potential`.
    func weakLeftBackBehind(potential: Int) throws -> BetterPlayerNeed? {
        let young = named(.D_L, "second")
        let players = try squad(levels: [named(.D_L, "first"): 12, young: 11]) {
            if $0.name == young { $0.age = 19; $0.currentAbility = 60; $0.potentialAbility = potential }
        }
        return try needs(players).betterPlayers.first { $0.slot == .D_L }
    }
    @Test func aWeakNeedIsNotEasedByAReachBelowTheFirstChoicesAbility() throws {
        // A potential of 100 reaches the first choice's ability; 95 clears the line by ability (about 91.5) but would not
        // pass him (the owner's rule of 25 November 2026).
        let reached = try #require(try weakLeftBackBehind(potential: 100))
        #expect(reached.kind == .weak && reached.easedBy?.name == named(.D_L, "second"))
        let short = try #require(try weakLeftBackBehind(potential: 95))
        #expect(short.kind == .weak && short.easedBy == nil)
    }
    @Test func aWeakNeedIsNotEasedByAReachUnderTheLineByAbility() throws {
        // As the young first choice of `aWeakNeedIsEasedByAYoungPlayerWhoseReachClearsTheLine`, but of ability 60: a
        // potential of 85 lifts his rating over the line (by 155 ÷ 130) and leaves his ability under it.
        let young = named(.D_L, "first")
        func need(potential: Int) throws -> (need: BetterPlayerNeed, needs: ScoutingNeeds) {
            let r = try needs(try squad(levels: [young: 12, named(.D_L, "second"): 10]) {
                if $0.name == young { $0.age = 19; $0.currentAbility = 60; $0.potentialAbility = potential }
            })
            return (try #require(r.betterPlayers.first { $0.slot == .D_L }), r)
        }
        let (short, r) = try need(potential: 85)
        let line = 0.95 * (try #require(r.outfieldAverageAbility)) - 70
        #expect(85 < line && short.kind == .weak && short.easedBy == nil)
        let rating = try #require(r.elevens.first.first { $0.slot == .D_L }?.rating.value)
        #expect(Scouting.clearsWeakLine(rating * 155 / 130, average: try #require(r.outfieldAverageRating), parameters: .fm27))
        #expect(try need(potential: 130).need.easedBy?.name == young)
    }
    @Test func ageingIsNotRaisedWhenAYoungPlayerIsOnCourse() throws {
        let old = named(.AM_C, "first"), young = named(.AM_C, "second")
        let alone = try needs(squad { if $0.name == old { $0.age = 32 } })
        #expect(alone.betterPlayers.map(\.kind) == [.ageing] && alone.betterPlayers[0].firstChoice?.age == 32)
        let withSuccessor = try needs(squad(levels: [young: 13]) {
            if $0.name == old { $0.age = 32 }
            if $0.name == young { $0.age = 19; $0.potentialAbility = 190 }
        })
        #expect(withSuccessor.betterPlayers.isEmpty)
    }
    /// Familiarity 20 at both positions of the slot, as the fixture gives its own players.
    func playsAt(_ slot: SlotID, _ player: inout Player) throws {
        let assignment = try #require(try tactic.assignments(catalog: catalog).first { $0.slot == slot })
        for position in Set([assignment.ipPosition, assignment.oopPosition]) { player.familiarity[position] = 20 }
    }
    /// The left back's pair is lowered (12 and 10) so that left back is weak. The young player is the right back's
    /// first choice at level 14 (his second choice is lowered to 10, so he stays at right back), or, in the second
    /// arrangement, the right back's second choice at level 11 in place of the fixture's own second choice (who is
    /// dropped); at 11 he is under the left back's first choice, so he is first choice nowhere.
    func youngRightBack(asFirst: Bool) throws -> ScoutingNeeds {
        let young = named(.D_R, asFirst ? "first" : "second")
        var levels = [named(.D_L, "first"): 12, named(.D_L, "second"): 10]
        levels[young] = asFirst ? 14 : 11
        if asFirst { levels[named(.D_R, "second")] = 10 }
        var players = try squad(levels: levels) {
            if $0.name == young { $0.age = 19; $0.potentialAbility = 190 }
        }
        if !asFirst { players.removeAll { $0.name == named(.D_R, "second") && $0.name != young } }
        let index = try #require(players.firstIndex { $0.name == young })
        try playsAt(.D_L, &players[index])
        return try needs(players)
    }
    @Test func aFirstChoiceAtAnotherSlotEasesNothing() throws {
        let first = try youngRightBack(asFirst: true)
        #expect(first.elevens.tiers.first[.D_R] == PlannerFixture.id(.D_R, "first"))
        let blocked = try #require(first.betterPlayers.first { $0.slot == .D_L })
        #expect(blocked.kind == .weak && blocked.easedBy == nil)

        let second = try youngRightBack(asFirst: false)
        #expect(second.elevens.tiers.tier(of: PlannerFixture.id(.D_R, "second")).map { if case .first = $0 { true } else { false } } == false)
        let eased = try #require(second.betterPlayers.first { $0.slot == .D_L })
        #expect(eased.kind == .weak && eased.easedBy?.name == named(.D_R, "second"))
    }
    @Test func aFirstChoiceAtAnotherSlotIsNobodysSuccessor() throws {
        let old = named(.AM_C, "first"), young = named(.ST_C, "first")
        let r = try needs(squad(levels: [young: 15, named(.ST_C, "second"): 10]) {
            if $0.name == old { $0.age = 32 }
        }.map { p in
            var p = p
            if p.name == young { p.age = 19; p.potentialAbility = 190; try! playsAt(.AM_C, &p) }
            return p
        })
        #expect(r.elevens.tiers.first[.ST_C] == PlannerFixture.id(.ST_C, "first"))
        let need = try #require(r.betterPlayers.first { $0.slot == .AM_C })
        #expect(need.kind == .ageing && need.firstChoice?.age == 32)
    }
    @Test func anEasedWeakNeedComesAfterOneThatIsNot() throws {
        // Left back (12 against the others at 14) is the larger gap and is eased by its first choice at 19 with a
        // high potential; right back (12) is the smaller gap and is not.
        let young = named(.D_L, "first")
        let players = try squad(levels: [young: 11, named(.D_L, "second"): 10, named(.D_R, "first"): 12,
                                         named(.D_R, "second"): 10]) {
            if $0.name == young { $0.age = 19; $0.potentialAbility = 190 }
        }
        let r = try needs(players)
        #expect(r.betterPlayers.map(\.slot) == [.D_R, .D_L])
        let left = try #require(r.betterPlayers.first { $0.slot == .D_L }), right = try #require(r.betterPlayers.first { $0.slot == .D_R })
        #expect(left.easedBy != nil && right.easedBy == nil && (left.gap ?? 0) > (right.gap ?? 0))
        // Without the easing the larger gap comes first.
        let plain = try needs(squad(levels: [young: 11, named(.D_L, "second"): 10, named(.D_R, "first"): 12,
                                             named(.D_R, "second"): 10]))
        #expect(plain.betterPlayers.map(\.slot) == [.D_L, .D_R] && plain.betterPlayers.allSatisfy { $0.easedBy == nil })
    }
    @Test func aPlayerOutOnLoanWhoWouldNotCountIsNotNamed() throws {
        let away = named(.GK, "second")
        // (a) Every attribute at 4: under the cover share.
        let weak = try needs(squad(levels: [away: 4]) { if $0.name == away { $0.loanedTo = "Wallingford" } })
        #expect(try #require(weak.moreDepth.first { $0.depth.slot == .GK }).returning == [])
        // (b) His normal level with familiarity 14 at the goalkeeper position: not solid.
        let notSolid = try needs(squad {
            if $0.name == away { $0.loanedTo = "Wallingford"; $0.familiarity[.goalkeeper] = 14 }
        })
        #expect(try #require(notSolid.moreDepth.first { $0.depth.slot == .GK }).returning == [])
    }
    @Test func aRepeatedGoingEntryIsCountedOnce() throws {
        let players = try squad()
        let p = players[0]
        let sell = Going(player: p.id, name: p.name, reason: .markedToSell)
        let advised = Going(player: p.id, name: p.name, reason: .advisedToLeave)
        let one = try needs(players, going: [sell])
        let a = try needs(players, going: [advised, sell]), b = try needs(players, going: [sell, advised])
        #expect(a.going == [sell] && b.going == [sell])
        #expect(a == b && a == one)
    }
    @Test func moreDepthCountsOnlyCoverThatStaysAndNamesWhoIsGoing() throws {
        let players = try squad()
        let second = try #require(players.first { $0.name == named(.D_R, "second") })
        let going = [Going(player: second.id, name: second.name, reason: .advisedToLeave)]
        let r = try needs(players, going: going)
        let need = try #require(r.moreDepth.first { $0.depth.slot == .D_R })
        #expect(need.depth.cover == 1 && need.going == going && need.returning.isEmpty)
        #expect(r.moreDepth.count == 1 && !r.fine.contains(.D_R))
        #expect(try needs(players).moreDepth.isEmpty)
    }
    @Test func aPlayerOutOnLoanWhoWouldCountIsNamedAsReturning() throws {
        let away = named(.GK, "second")
        let r = try needs(squad { if $0.name == away { $0.loanedTo = "Wallingford" } })
        let need = try #require(r.moreDepth.first { $0.depth.slot == .GK })
        #expect(need.returning.map(\.name) == [away] && need.returning[0].club == "Wallingford")
    }
    @Test func aSlotCanHaveBothNeedsAndIsThenNotFine() throws {
        let players = try squad(levels: [named(.D_L, "first"): 12]).filter { $0.name != named(.D_L, "second") }
        let r = try needs(players)
        #expect(r.betterPlayers.map(\.slot) == [.D_L] && r.moreDepth.map(\.depth.slot) == [.D_L])
        #expect(!r.fine.contains(.D_L) && r.fine.count == 10)
    }
    @Test func betterPlayersComeNobodyThenWeakByGapThenAgeingOldestFirst() throws {
        let players = try squad(levels: [named(.D_L, "first"): 12, named(.D_L, "second"): 10,
                                         named(.D_R, "first"): 11, named(.D_R, "second"): 10]) {
            if $0.name == named(.AM_C, "first") { $0.age = 31 }
            if $0.name == named(.ST_C, "first") { $0.age = 34 }
        }.filter { !$0.name.hasPrefix(SlotID.AM_L.rawValue + " ") }
        let r = try needs(players)
        #expect(r.betterPlayers.map(\.slot) == [.AM_L, .D_R, .D_L, .ST_C, .AM_C])
        #expect(r.betterPlayers.map(\.kind) == [.nobody, .weak, .weak, .ageing, .ageing])
    }
    @Test func withNoOutfieldFirstChoiceInPositionNothingIsCalledWeak() throws {
        let keepers = try squad().filter { $0.name.hasPrefix(SlotID.GK.rawValue + " ") }
        let r = try needs(keepers)
        #expect(r.outfieldAverageRating == nil && r.outfieldAverageAbility == nil)
        #expect(!r.betterPlayers.contains { $0.kind == .weak })
        #expect(r.betterPlayers.filter { $0.kind == .nobody }.count == 10)
    }
    @Test func theSameInputsGiveTheSameNeeds() throws {
        let players = try squad(levels: [named(.D_L, "first"): 12, named(.D_L, "second"): 10])
        #expect(try needs(players) == (try needs(players.reversed())))
    }

    // One place for each rule.
    @Test func theWeakLineIsOneRuleForAGapAndForAValue() {
        let p = EngineParameters.fm27
        #expect(Scouting.isWeak(gap: 0.05, parameters: p) && !Scouting.isWeak(gap: 0.0499, parameters: p))
        // A value at 95% of the average is on the line: weak, so it does not clear it; just over clears it.
        #expect(Scouting.gap(of: 95, under: 100) == 1 - 95.0 / 100)
        #expect(!Scouting.clearsWeakLine(95, average: 100, parameters: p))
        #expect(Scouting.clearsWeakLine(95.01, average: 100, parameters: p))
    }
    @Test func depthsCoverTestIsOneRule() {
        let p = EngineParameters.fm27
        #expect(Depth.isCover(isSolid: true, rating: 80, firstChoiceRating: 100, parameters: p))
        #expect(!Depth.isCover(isSolid: true, rating: 79.9, firstChoiceRating: 100, parameters: p))
        #expect(!Depth.isCover(isSolid: false, rating: 100, firstChoiceRating: 100, parameters: p))
        #expect(Depth.isCover(isSolid: true, rating: 1, firstChoiceRating: nil, parameters: p))
    }

    // A young player of the club's own out on loan.
    /// A player out on loan at Wallingford, familiarity 20 at the slot's positions, every attribute at `level`.
    func loanee(_ slot: SlotID, level: Int, age: Int, potential: Int) throws -> Player {
        var p = Player.fixture(name: "Max Treml", age: age, all: level, potentialAbility: potential, loanedTo: "Wallingford")
        try playsAt(slot, &p)
        return p
    }
    @Test func aYoungPlayerOutOnLoanEasesAWeakNeed() throws {
        let weakLeftBack = try squad(levels: [named(.D_L, "first"): 12, named(.D_L, "second"): 10])
        let eased = try #require(try needs(weakLeftBack + [loanee(.D_L, level: 12, age: 19, potential: 190)])
            .betterPlayers.first { $0.slot == .D_L })
        #expect(eased.kind == .weak && eased.easedBy?.name == "Max Treml" && eased.easedBy?.age == 19)
        #expect(eased.easedBy?.onLoanAt == "Wallingford")
        // His potential caps him under the line.
        let capped = try #require(try needs(weakLeftBack + [loanee(.D_L, level: 12, age: 19, potential: 101)])
            .betterPlayers.first { $0.slot == .D_L })
        #expect(capped.kind == .weak && capped.easedBy == nil)
    }
    @Test func aYoungPlayerOutOnLoanIsASuccessor() throws {
        let old = named(.AM_C, "first")
        let players = try squad { if $0.name == old { $0.age = 32 } }
        #expect(try needs(players).betterPlayers.map(\.kind) == [.ageing])
        #expect(try needs(players + [loanee(.AM_C, level: 13, age: 19, potential: 190)]).betterPlayers.isEmpty)
    }
    @Test func aPlayerOfTwentyFourOutOnLoanNeitherEasesNorSucceeds() throws {
        let weakLeftBack = try squad(levels: [named(.D_L, "first"): 12, named(.D_L, "second"): 10]) {
            if $0.name == named(.AM_C, "first") { $0.age = 32 }
        }
        let r = try needs(weakLeftBack + [loanee(.D_L, level: 12, age: 24, potential: 190),
                                          loanee(.AM_C, level: 13, age: 24, potential: 190).renamed("Ben Cole")])
        #expect(try #require(r.betterPlayers.first { $0.slot == .D_L }).easedBy == nil)
        #expect(r.betterPlayers.contains { $0.slot == .AM_C && $0.kind == .ageing })
    }

    // A depth need and injuries.
    @Test func anInjuredFirstChoiceIsNamedAndTheNeedLastsOnlyWhileHeIsOut() throws {
        let first = named(.D_L, "first")
        let r = try needs(squad { if $0.name == first { $0.isInjured = true } })
        let need = try #require(r.moreDepth.first { $0.depth.slot == .D_L })
        #expect(need.depth.cover == 1 && need.injured.map(\.name) == [first] && need.lastsOnlyWhileInjured)
        #expect(need.firstChoice?.name == first)
        // With his second choice also gone, the need would stay when he is back.
        let alone = try needs(squad { if $0.name == first { $0.isInjured = true } }.filter { $0.name != named(.D_L, "second") })
        let lasting = try #require(alone.moreDepth.first { $0.depth.slot == .D_L })
        #expect(lasting.injured.map(\.name) == [first] && !lasting.lastsOnlyWhileInjured)
    }
    @Test func anInjuredPlayerBelowTheCoverShareIsNotNamed() throws {
        let second = named(.D_L, "second")
        let r = try needs(squad(levels: [second: 4]) { if $0.name == second { $0.isInjured = true } })
        let need = try #require(r.moreDepth.first { $0.depth.slot == .D_L })
        #expect(need.injured.isEmpty && !need.lastsOnlyWhileInjured)
        // A healthy second choice who counts leaves no need.
        #expect(try needs(squad()).moreDepth.isEmpty)
    }
    /// Left back: both players injured, so nobody counts (Depth puts it first), but both would. Right back: its second
    /// choice gone, so one counts. The need that rests on injuries comes after the other.
    @Test func aNeedThatRestsOnAnInjuryComesLast() throws {
        let players = try squad { if $0.name.hasPrefix(SlotID.D_L.rawValue + " ") { $0.isInjured = true } }
            .filter { $0.name != named(.D_R, "second") }
        let r = try needs(players)
        #expect(r.depth.thin == [.D_L, .D_R])
        #expect(r.moreDepth.map(\.depth.slot) == [.D_R, .D_L])
        #expect(r.moreDepth.map(\.lastsOnlyWhileInjured) == [false, true])
        #expect(r.moreDepth[1].injured.count == 2)
        // Without the injuries Depth's order stands: left back has no need, right back has.
        #expect(try needs(squad().filter { $0.name != named(.D_R, "second") }).moreDepth.map(\.depth.slot) == [.D_R])
    }
    @Test func theNextBestIsGivenAsAShareUnderTheFirstChoice() throws {
        let first = named(.D_L, "first")
        let r = try needs(squad { if $0.name == first { $0.isInjured = true } })
        let need = try #require(r.moreDepth.first { $0.depth.slot == .D_L })
        let firstRating = try #require(need.depth.options.first { $0.name == first }).rating
        let next = try #require(need.depth.options.first { $0.player == need.depth.nextBest })
        let share = try #require(need.nextBestShareUnder)
        #expect(abs(share - (1 - next.rating / firstRating)) < 1e-12 && share > 0)
        // With nobody else who can step in there is no next best.
        let alone = try needs(squad { if $0.name == first { $0.isInjured = true } }.filter { $0.name != named(.D_L, "second") })
        #expect(try #require(alone.moreDepth.first { $0.depth.slot == .D_L }).nextBestShareUnder == nil)
    }
}

private extension Player {
    /// The same player under another name and key.
    func renamed(_ name: String) -> Player {
        var p = self
        p.name = name
        p.id = PlayerID(key: PlayerID.normalise(name))
        return p
    }
}
