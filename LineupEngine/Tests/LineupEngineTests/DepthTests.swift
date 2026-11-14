import Foundation
import Testing
@testable import LineupEngine

@Suite struct DepthTests {
    let tactic = try! PlannerFixture.tactic()
    let catalog = try! RoleCatalog.fm27()
    let profile = try! RatingProfile.standard()

    func report(_ players: [Player], ownClub: String? = "Oxford City") throws -> DepthReport {
        try Depth.report(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                         profile: profile, parameters: .fm27)
    }

    func squad(_ edit: (inout Player) -> Void = { _ in }, without removed: Set<String> = []) throws -> [Player] {
        try PlannerFixture.squad().filter { !removed.contains($0.name) }.map { p in var p = p; edit(&p); return p }
    }

    func depth(_ r: DepthReport, _ slot: SlotID) throws -> SlotDepth { try #require(r.slots.first { $0.slot == slot }) }

    func named(_ slot: SlotID, _ tier: String) -> String { PlannerFixture.name(slot, tier) }

    @Test func everySlotListsItsOptionsBestFirst() throws {
        let r = try report(PlannerFixture.squad())
        #expect(r.slots.map(\.slot) == (try tactic.assignments(catalog: catalog)).map(\.slot))
        for slot in r.slots {
            let ratings = slot.options.map(\.rating)
            #expect(ratings == ratings.sorted(by: >))
            #expect(!slot.options.isEmpty)
        }
        let am = try depth(r, .AM_C)
        #expect(am.options.map(\.player) == [PlannerFixture.id(.AM_C, "first"), PlannerFixture.id(.AM_C, "second")])
        #expect(am.ipPosition == .attackingMidCentral && am.oopPosition == .attackingMidCentral)
    }

    @Test func aPlayerBelowCompetentInEitherPhaseIsNotAnOption() throws {
        let low = named(.AM_L, "second")
        let r = try report(squad { if $0.name == low { $0.familiarity[.midfielderLeft] = 9 } })
        let am = try depth(r, .AM_L)
        #expect(am.ipPosition == .attackingMidLeft && am.oopPosition == .midfielderLeft)
        #expect(am.options.map(\.player) == [PlannerFixture.id(.AM_L, "first")])
        #expect(am.onLoan.isEmpty)
        #expect(am.cover == 1 && am.isThin)
        // At exactly the Competent step he is an option again.
        let ok = try report(squad { if $0.name == low { $0.familiarity[.midfielderLeft] = 10 } })
        #expect(try depth(ok, .AM_L).options.count == 2)
    }

    @Test func familiarityInBothPhasesIsShown() throws {
        let name = named(.AM_L, "first")
        let r = try report(squad { if $0.name == name { $0.familiarity[.attackingMidLeft] = 18; $0.familiarity[.midfielderLeft] = 12 } })
        let option = try #require(try depth(r, .AM_L).options.first { $0.player == PlannerFixture.id(.AM_L, "first") })
        #expect(option.ipFamiliarity == 18 && option.oopFamiliarity == 12)
        #expect(!option.isSolid)
        #expect(option.name == name && option.squad == .firstTeam)
    }

    @Test func aSlotWithTwoSolidAvailablePlayersIsNotThin() throws {
        let r = try report(PlannerFixture.squad())
        let am = try depth(r, .AM_C)
        #expect(am.cover == 2 && !am.isThin)
        #expect(am.options.allSatisfy { $0.isSolid && $0.unavailable == nil })
        #expect(!r.thin.contains(.AM_C))
    }

    @Test func anInjuredSecondChoiceLeavesTheSlotThin() throws {
        let name = named(.AM_C, "second")
        let r = try report(squad { if $0.name == name { $0.isInjured = true } })
        let am = try depth(r, .AM_C)
        #expect(am.cover == 1 && am.isThin)
        let injured = try #require(am.options.first { $0.player == PlannerFixture.id(.AM_C, "second") })
        #expect(injured.unavailable == .injured)
        #expect(injured.tier == .second(.AM_C))
        #expect(r.thin.contains(.AM_C))
    }

    @Test func aBannedOrTiredSecondChoiceIsListedAsUnavailable() throws {
        let banned = named(.GK, "second"), tired = named(.AM_C, "second")
        let r = try report(squad {
            if $0.name == banned { $0.isBanned = true }
            if $0.name == tired { $0.condition = 0.3 }
        })
        let gk = try #require(try depth(r, .GK).options.first { $0.player == PlannerFixture.id(.GK, "second") })
        #expect(gk.unavailable == .banned)
        let am = try #require(try depth(r, .AM_C).options.first { $0.player == PlannerFixture.id(.AM_C, "second") })
        #expect(am.unavailable == .belowConditionFloor(0.3))
        #expect(try depth(r, .GK).isThin && depth(r, .AM_C).isThin)
    }

    @Test func aSecondChoiceAtFamiliarity14IsNotSolid() throws {
        let name = named(.AM_C, "second")
        let at14 = try report(squad { if $0.name == name { $0.familiarity[.attackingMidCentral] = 14 } })
        let am = try depth(at14, .AM_C)
        #expect(am.options.count == 2 && am.cover == 1 && am.isThin)
        #expect(am.options.last?.isSolid == false)
        let at15 = try report(squad { if $0.name == name { $0.familiarity[.attackingMidCentral] = 15 } })
        #expect(try depth(at15, .AM_C).cover == 2)
    }

    @Test func twoCentreBacksForTwoSlotsLeaveBothThin() throws {
        let r = try report(squad(without: [named(.D_CL, "second"), named(.D_CR, "second")]))
        for slot in [SlotID.D_CL, .D_CR] {
            let d = try depth(r, slot)
            #expect(d.options.count == 2)
            #expect(d.cover == 1 && d.isThin)
        }
        #expect(r.thin.contains(.D_CL) && r.thin.contains(.D_CR))
    }

    @Test func aThirdCentreBackCoversBothAndIsMarkedAsShared() throws {
        let r = try report(squad(without: [named(.D_CR, "second")]))
        let third = PlannerFixture.id(.D_CL, "second")
        let tier = try #require(r.slots.flatMap(\.options).first { $0.player == third }?.tier)
        let home: SlotID, other: SlotID
        switch tier {
        case .second(let s): home = s; other = s == .D_CL ? .D_CR : .D_CL
        case .first, .backup: Issue.record("expected the third centre-back to be a second choice"); return
        }
        let atHome = try #require(try depth(r, home).options.first { $0.player == third })
        let atOther = try #require(try depth(r, other).options.first { $0.player == third })
        #expect(atHome.alsoNeededAt.isEmpty)
        #expect(atOther.alsoNeededAt == [home])
        #expect(try depth(r, .D_CL).cover == 2 && depth(r, .D_CR).cover == 2)
        #expect(!r.thin.contains(.D_CL) && !r.thin.contains(.D_CR))
    }

    @Test func aSlotNobodyCanCoverIsThinWithNoOptions() throws {
        let r = try report(squad(without: [named(.ST_C, "first"), named(.ST_C, "second")]))
        let st = try depth(r, .ST_C)
        #expect(st.options.isEmpty && st.onLoan.isEmpty)
        #expect(st.cover == 0 && st.isThin)
        #expect(r.thin.first == .ST_C)
    }

    @Test func playersOutOnLoanAreShownApart() throws {
        let name = named(.AM_C, "second")
        let r = try report(squad { if $0.name == name { $0.loanedTo = "Elsewhere FC" } })
        let am = try depth(r, .AM_C)
        #expect(am.options.map(\.player) == [PlannerFixture.id(.AM_C, "first")])
        let away = try #require(am.onLoan.first)
        #expect(am.onLoan.count == 1 && away.player == PlannerFixture.id(.AM_C, "second"))
        #expect(away.tier == nil)
        #expect(away.unavailable == .outOnLoan(to: "Elsewhere FC"))
        #expect(am.cover == 1 && am.isThin)
    }

    @Test func dropToSecondIsTheGapBetweenTheTiers() throws {
        let all = try PlannerFixture.squad()
        let firsts = all.filter { $0.name.hasSuffix("first") }
        let seconds = all.filter { $0.name.hasSuffix("second") }.prefix(4)
        let r = try report(firsts + seconds)
        let tiers = try SquadTiers.compute(tactic: tactic, players: firsts + seconds, ownClub: "Oxford City",
                                           catalog: catalog, profile: profile, parameters: .fm27, ignoringInjuries: true)
        var withDrop = 0, without = 0
        for slot in r.slots {
            if let second = tiers.second[slot.slot], let first = tiers.first[slot.slot] {
                let gap = try #require(tiers.ratings[first]?[slot.slot]) - #require(tiers.ratings[second]?[slot.slot])
                #expect(abs(try #require(slot.dropToSecond) - gap) < 1e-9)
                withDrop += 1
            } else {
                #expect(slot.dropToSecond == nil)
                without += 1
            }
        }
        #expect(withDrop == 4 && without == 7)
    }

    @Test func thinSlotsAreOrderedByNeed() throws {
        // ST_C has nobody (cover 0); AM_C and GK each have one fit player, AM_C with the larger drop.
        let weak = named(.AM_C, "second")
        let injured: Set<String> = [named(.AM_C, "second"), named(.GK, "second")]
        let players = try PlannerFixture.squad().filter { !$0.name.hasPrefix("ST_C") }.map { p -> Player in
            var p = p
            if injured.contains(p.name) { p.isInjured = true }
            if p.name == weak {
                p = Player.fixture(name: p.name, all: 4, familiarity: [.attackingMidCentral: 20])
                p.isInjured = true
            }
            return p
        }
        let r = try report(players)
        let am = try depth(r, .AM_C), gk = try depth(r, .GK)
        #expect(am.cover == 1 && gk.cover == 1)
        #expect(try #require(am.dropToSecond) > #require(gk.dropToSecond))
        // Without a striker, a wide player is moved up front, which also thins his old slot.
        #expect(r.thin.first == .ST_C)
        let a = try #require(r.thin.firstIndex(of: .AM_C)), g = try #require(r.thin.firstIndex(of: .GK))
        #expect(a < g)
    }

    @Test func slotsWithTheSameCoverAndNoSecondChoiceGoInSlotOrder() throws {
        let all = try PlannerFixture.squad()
        let r = try report(all.filter { $0.name.hasSuffix("first") })
        // Eleven first choices and nobody else: every slot has no second choice and, apart from the
        // shared positions, one option.
        #expect(r.slots.allSatisfy { $0.dropToSecond == nil })
        let order = SlotID.allCases
        let thin = r.thin
        #expect(thin == thin.sorted { order.firstIndex(of: $0)! < order.firstIndex(of: $1)! })
        #expect(thin.contains(.GK) && thin.contains(.ST_C))
    }

    @Test func aSlotWithoutASecondChoiceRanksAheadOfOneWithAnyDrop() throws {
        let all = try PlannerFixture.squad()
        // Everyone injured-free; AM_C and ST_C each lose their second choice's fitness, but ST_C's
        // second eleven is also missing, so its drop is nil.
        let firsts = all.filter { $0.name.hasSuffix("first") }
        let seconds = all.filter { $0.name.hasSuffix("second") && !$0.name.hasPrefix("ST_C") }.map { p -> Player in
            var p = p; if p.name.hasPrefix("AM_C") { p.isInjured = true }; return p
        }
        let r = try report(firsts + seconds)
        let st = try depth(r, .ST_C), am = try depth(r, .AM_C)
        #expect(st.cover == 1 && am.cover == 1)
        if st.dropToSecond == nil {
            let a = try #require(r.thin.firstIndex(of: .ST_C)), b = try #require(r.thin.firstIndex(of: .AM_C))
            #expect(a < b)
        }
    }

    @Test func inputOrderDoesNotMatter() throws {
        let players = try squad { if $0.name == named(.AM_C, "second") { $0.isInjured = true } }
        let forward = try report(players)
        #expect(try report(players.reversed()) == forward)
        var shuffled = players
        var generator = SeededGenerator(seed: 7)
        shuffled.shuffle(using: &generator)
        #expect(try report(shuffled) == forward)
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
