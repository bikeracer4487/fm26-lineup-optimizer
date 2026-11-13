import Foundation
import Testing
@testable import LineupEngine

@Suite struct SquadTiersTests {
    let tactic = try! PlannerFixture.tactic()
    let catalog = try! RoleCatalog.fm27()
    let profile = try! RatingProfile.standard()
    /// Slots whose position and roles no other slot shares, so the player there is not interchangeable.
    let untwinned: [SlotID] = [.GK, .D_L, .D_R, .AM_L, .AM_C, .AM_R, .ST_C]

    func tiers(_ players: [Player], ownClub: String? = "Oxford City") throws -> SquadTiers {
        try SquadTiers.compute(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                               profile: profile, parameters: .fm27)
    }

    func changing(_ slot: SlotID, _ tier: String, in players: [Player], _ change: (inout Player) -> Void) -> [Player] {
        let target = PlannerFixture.id(slot, tier)
        return players.map { var p = $0; if p.id == target { change(&p) }; return p }
    }

    @Test func theFirstElevenIsTheBetterPlayerInEverySlotAndTheSecondTheOther() throws {
        let t = try tiers(PlannerFixture.squad())
        let assignments = try tactic.assignments(catalog: catalog)
        #expect(Set(t.first.values) == Set(assignments.map { PlannerFixture.id($0.slot, "first") }))
        #expect(Set(t.second.values) == Set(assignments.map { PlannerFixture.id($0.slot, "second") }))
        #expect(t.first.count == 11 && t.second.count == 11)
        for a in assignments {
            #expect(t.first[a.slot] != nil && t.second[a.slot] != nil)
            for (tier, map) in [("first", t.first), ("second", t.second)] {
                guard let player = map[a.slot] else { continue }
                // He was built for a slot with the same in-possession position.
                let builtFor = assignments.first { PlannerFixture.id($0.slot, tier) == player }
                #expect(builtFor?.ipPosition == a.ipPosition)
                if untwinned.contains(a.slot) { #expect(player == PlannerFixture.id(a.slot, tier)) }
            }
        }
    }

    @Test func anInjuredFirstChoiceDropsOutAndTheSecondChoiceMovesUp() throws {
        let squad = changing(.ST_C, "first", in: try PlannerFixture.squad()) { $0.isInjured = true }
        let t = try tiers(squad)
        #expect(t.first[.ST_C] == PlannerFixture.id(.ST_C, "second"))
        #expect(t.second[.ST_C] == nil)
        #expect(t.ratings[PlannerFixture.id(.ST_C, "first")] == nil)
        #expect(t.slot(of: PlannerFixture.id(.ST_C, "first")) == nil)
    }

    @Test func aPlayerOutOnLoanIsLeftOut() throws {
        let squad = changing(.AM_C, "first", in: try PlannerFixture.squad()) { $0.loanedTo = "Elsewhere FC" }
        let t = try tiers(squad)
        #expect(t.first[.AM_C] == PlannerFixture.id(.AM_C, "second"))
        #expect(t.ratings[PlannerFixture.id(.AM_C, "first")] == nil)
    }

    @Test func aPlayerLoanedInToTheOwnClubStaysInTheTiers() throws {
        let squad = changing(.AM_C, "first", in: try PlannerFixture.squad()) { $0.loanedTo = "Oxford City"; $0.club = "Elsewhere FC" }
        let t = try tiers(squad)
        #expect(t.first[.AM_C] == PlannerFixture.id(.AM_C, "first"))
        #expect(t.ratings[PlannerFixture.id(.AM_C, "first")] != nil)
    }

    @Test func withNoOwnClubALoanedPlayerIsStillLeftOut() throws {
        // LoanStatus.of treats any loan as a loan out when the own club is unknown.
        let squad = changing(.AM_C, "first", in: try PlannerFixture.squad()) { $0.loanedTo = "Oxford City" }
        let t = try tiers(squad, ownClub: nil)
        #expect(t.ratings[PlannerFixture.id(.AM_C, "first")] == nil)
        #expect(t.first[.AM_C] == PlannerFixture.id(.AM_C, "second"))
    }

    @Test func twoRecordsUnderOneIdentityAreRefusedWhicheverComesFirst() throws {
        let squad = try PlannerFixture.squad()
        var twin = squad.first { $0.id == PlannerFixture.id(.ST_C, "first") }!
        twin.age = 31
        let expected = DuplicatePlayerError(id: PlannerFixture.id(.ST_C, "first"), names: ["ST_C first", "ST_C first"])
        #expect(throws: expected) { try tiers(squad + [twin]) }
        #expect(throws: expected) { try tiers([twin] + squad) }
        #expect(throws: expected) { try tiers(squad.reversed() + [twin]) }
    }

    @Test func theLowestDuplicatedKeyIsReported() throws {
        let squad = try PlannerFixture.squad()
        let dupes = squad.filter { [PlannerFixture.id(.ST_C, "first"), PlannerFixture.id(.D_L, "first")].contains($0.id) }
        #expect(throws: DuplicatePlayerError(id: PlannerFixture.id(.D_L, "first"), names: ["D_L first", "D_L first"])) {
            try tiers(squad + dupes)
        }
    }

    @Test func fitnessDoesNotChangeTheTiers() throws {
        let base = try tiers(PlannerFixture.squad())
        let tired = changing(.GK, "first", in: try PlannerFixture.squad()) { $0.condition = 0.5; $0.sharpness = 0.3; $0.isBanned = true }
        let t = try tiers(tired)
        #expect(t == base)
        #expect(t.first[.GK] == PlannerFixture.id(.GK, "first"))
    }

    @Test func advantageIsTheGapToTheSecondChoiceInThatSlot() throws {
        let t = try tiers(PlannerFixture.squad())
        let f = PlannerFixture.id(.D_L, "first"), s = PlannerFixture.id(.D_L, "second")
        let gap = try #require(t.advantage(of: f))
        #expect(abs(gap - (t.ratings[f]![.D_L]! - t.ratings[s]![.D_L]!)) < 1e-9)
        #expect(gap > 0)
        #expect(t.advantage(of: s) == nil)
        #expect(t.slot(of: f)?.slot == .D_L && t.slot(of: f)?.tier == 1)
        #expect(t.slot(of: s)?.slot == .D_L && t.slot(of: s)?.tier == 2)
        #expect(t.slot(of: PlayerID(key: "nobody")) == nil)
    }

    @Test func advantageIsTheWholeRatingWhenNobodyCovers() throws {
        let squad = try PlannerFixture.squad().filter { $0.id != PlannerFixture.id(.ST_C, "second") }
        let t = try tiers(squad)
        let f = PlannerFixture.id(.ST_C, "first")
        #expect(t.second[.ST_C] == nil)
        #expect(t.advantage(of: f) == t.ratings[f]![.ST_C]!)
    }

    @Test func aSquadOfFewerThanElevenLeavesSlotsOutOfTheTiers() throws {
        let squad = Array(try PlannerFixture.squad().filter { $0.name.hasSuffix("first") }.prefix(4))
        let t = try tiers(squad)
        #expect(t.first.count == 4)
        #expect(t.second.isEmpty)
    }

    @Test func inputOrderDoesNotMatter() throws {
        let squad = try PlannerFixture.squad()
        let a = try tiers(squad)
        // Fixed permutations, so a failure repeats.
        #expect(try tiers(squad.reversed()) == a)
        #expect(try tiers(Array(squad[7...] + squad[..<7])) == a)
    }
}
