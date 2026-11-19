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
}
