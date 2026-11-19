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
        #expect(slot.answers == [.betterPlayerToday] && (slot.stillWeakBy ?? 0) > 0.05)
    }
    @Test func heAnswersADepthNeedOnlyWhenHeCountsAndIsSolid() throws {
        let players = try PlannerFixture.squad().filter { $0.name != PlannerFixture.name(.D_L, "second") }
        #expect(try #require(today(candidate(.D_L, level: 12), players: players).first).answers == [.moreDepth])
        // The second eleven's place at the slot is empty there, so even a very weak player would make it and count: the
        // fixture's levels give no below-cover player at a thin slot that way. With the second choice injured instead
        // (he keeps his place, is no cover) a player at 4 is below cover and answers nothing.
        let injured = try PlannerFixture.squad().map { p in
            var p = p; if p.name == PlannerFixture.name(.D_L, "second") { p.isInjured = true }; return p
        }
        let weak = try #require(today(candidate(.D_L, level: 4), players: injured).first)
        #expect(try needs(injured).moreDepth.map(\.depth.slot) == [.D_L])
        #expect(weak.level == .belowCover && weak.answers.isEmpty)
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
}
