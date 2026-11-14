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

    @Test func aBannedOrTiredSecondChoiceIsListedAsUnavailableButStillCounts() throws {
        let banned = named(.GK, "second"), tired = named(.AM_C, "second")
        let r = try report(squad {
            if $0.name == banned { $0.isBanned = true }
            if $0.name == tired { $0.condition = 0.3 }
        })
        let gk = try #require(try depth(r, .GK).options.first { $0.player == PlannerFixture.id(.GK, "second") })
        #expect(gk.unavailable == .banned)
        let am = try #require(try depth(r, .AM_C).options.first { $0.player == PlannerFixture.id(.AM_C, "second") })
        #expect(am.unavailable == .belowConditionFloor(0.3))
        #expect(try !depth(r, .GK).isThin && !depth(r, .AM_C).isThin)
        #expect(r.thin.isEmpty)
    }

    /// The AM_C second choice changed by `change`, and the AM_C slot.
    func secondAtAttackingMid(_ change: (inout Player) -> Void) throws -> (option: DepthOption, slot: SlotDepth) {
        let name = named(.AM_C, "second")
        let r = try report(squad { if $0.name == name { change(&$0) } })
        let am = try depth(r, .AM_C)
        let option = try #require(am.options.first { $0.player == PlannerFixture.id(.AM_C, "second") })
        return (option, am)
    }

    @Test func aSecondChoiceShortOfConditionStillCounts() throws {
        let short = try secondAtAttackingMid { $0.condition = 0.80 }
        #expect(short.option.unavailable == .belowConditionFloor(0.80))
        #expect(short.slot.cover == 2 && !short.slot.isThin)
    }

    @Test func aJadedSecondChoiceStillCounts() throws {
        let jaded = try secondAtAttackingMid { $0.jadedness = 401 }
        #expect(jaded.option.unavailable == .jaded(401))
        #expect(jaded.slot.cover == 2 && !jaded.slot.isThin)
    }

    @Test func aBannedSecondChoiceStillCounts() throws {
        let banned = try secondAtAttackingMid { $0.isBanned = true }
        #expect(banned.option.unavailable == .banned)
        #expect(banned.slot.cover == 2 && !banned.slot.isThin)
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

    /// Whether `option` could step in at `slot`: not injured and not first choice at another slot.
    func canStepIn(_ option: DepthOption, at slot: SlotID) -> Bool {
        if option.unavailable == .injured { return false }
        if case .first(let other) = option.tier, other != slot { return false }
        return true
    }

    @Test func dropToNextBestIsTheGapToTheBestPlayerWhoCanStepIn() throws {
        let all = try PlannerFixture.squad()
        let firsts = all.filter { $0.name.hasSuffix("first") }
        let seconds = all.filter { $0.name.hasSuffix("second") }.prefix(4)
        let r = try report(firsts + seconds)
        let tiers = try SquadTiers.compute(tactic: tactic, players: firsts + seconds, ownClub: "Oxford City",
                                           catalog: catalog, profile: profile, parameters: .fm27, ignoringInjuries: true)
        var withDrop = 0, without = 0
        for slot in r.slots {
            let first = try #require(tiers.first[slot.slot])
            let others = slot.options.filter { $0.player != first && canStepIn($0, at: slot.slot) }
            if let best = others.map(\.rating).max() {
                let gap = try #require(tiers.ratings[first]?[slot.slot]) - best
                #expect(abs(try #require(slot.dropToNextBest) - gap) < 1e-9)
                withDrop += 1
            } else {
                #expect(slot.dropToNextBest == nil)
                without += 1
            }
        }
        // GK, D_L and the two centre-back slots have a second choice who can step in; the centre-backs and the
        // defensive midfielders are options at each other's slots, but as first choices there they do not step in.
        #expect(withDrop == 4 && without == 7)
    }

    @Test func theDropIsToTheBestOtherOption() throws {
        // Without a second left back, a spare player familiar nowhere fills left back in the second eleven, while the
        // second-choice right back, competent at left back, is an option there.
        let spare = Player.fixture(name: "Spare", all: 10)
        let rightBack = named(.D_R, "second")
        let players = try squad({ if $0.name == rightBack { $0.familiarity[.defenderLeft] = 15 } },
                                without: [named(.D_L, "second")]) + [spare]
        let tiers = try SquadTiers.compute(tactic: tactic, players: players, ownClub: "Oxford City",
                                           catalog: catalog, profile: profile, parameters: .fm27, ignoringInjuries: true)
        try #require(tiers.second[.D_L] == spare.id)
        try #require(tiers.first[.D_L] == PlannerFixture.id(.D_L, "first"))
        try #require(tiers.second[.D_R] == PlannerFixture.id(.D_R, "second"))
        let r = try report(players)
        let left = try depth(r, .D_L)
        #expect(!left.options.contains { $0.player == spare.id })
        let first = try #require(tiers.ratings[PlannerFixture.id(.D_L, "first")]?[.D_L])
        let next = try #require(tiers.ratings[PlannerFixture.id(.D_R, "second")]?[.D_L])
        let byTheSecondEleven = try #require(tiers.ratings[spare.id]?[.D_L])
        #expect(abs(try #require(left.dropToNextBest) - (first - next)) < 1e-9)
        #expect(abs(try #require(left.dropToNextBest) - (first - byTheSecondEleven)) > 1)
    }

    @Test func aFirstChoiceElsewhereIsNotTheNextBest() throws {
        // The first-choice right defensive midfielder is far stronger; at whichever DM slot he is not first choice, he
        // rates above that slot's first choice, but he is needed at his own slot, so the drop is to a second choice.
        let strong = named(.DM_R, "first")
        let players = try squad { if $0.name == strong { for a in Attribute.allCases { $0.attributes[a] = 18 } } }
        let tiers = try SquadTiers.compute(tactic: tactic, players: players, ownClub: "Oxford City",
                                           catalog: catalog, profile: profile, parameters: .fm27, ignoringInjuries: true)
        let r = try report(players)
        let strongID = PlannerFixture.id(.DM_R, "first")
        let other = try #require([SlotID.DM_L, .DM_R].first { tiers.first[$0] != strongID })
        let first = try #require(tiers.first[other])
        let firstRating = try #require(tiers.ratings[first]?[other])
        try #require(try #require(tiers.ratings[strongID]?[other]) > firstRating)
        let seconds = [PlannerFixture.id(.DM_L, "second"), PlannerFixture.id(.DM_R, "second")]
        let best = try seconds.map { try #require(tiers.ratings[$0]?[other]) }.max()!
        let drop = try #require(try depth(r, other).dropToNextBest)
        #expect(drop >= 0)
        #expect(abs(drop - (firstRating - best)) < 1e-9)
    }

    @Test func anInjuredPlayerIsNotTheNextBest() throws {
        // The second-choice AM_C is injured; a third, weaker attacking midfielder is the one who can step in.
        let third = Player.fixture(name: "Third", all: 10, familiarity: [.attackingMidCentral: 20])
        let injured = named(.AM_C, "second")
        let players = try squad { if $0.name == injured { $0.isInjured = true } } + [third]
        let tiers = try SquadTiers.compute(tactic: tactic, players: players, ownClub: "Oxford City",
                                           catalog: catalog, profile: profile, parameters: .fm27, ignoringInjuries: true)
        let am = try depth(report(players), .AM_C)
        try #require(am.options.contains { $0.player == PlannerFixture.id(.AM_C, "second") && $0.unavailable == .injured })
        let first = try #require(tiers.ratings[PlannerFixture.id(.AM_C, "first")]?[.AM_C])
        let next = try #require(tiers.ratings[third.id]?[.AM_C])
        #expect(abs(try #require(am.dropToNextBest) - (first - next)) < 1e-9)
        // Without the third, nobody can step in, and there is no drop.
        let alone = try depth(report(players.filter { $0.id != third.id }), .AM_C)
        #expect(alone.dropToNextBest == nil)
    }

    @Test func theDropIsNilWithNoOtherOption() throws {
        // The second striker is out on loan: he is not an option, and nobody else can play up front.
        let away = named(.ST_C, "second")
        let r = try report(squad { if $0.name == away { $0.loanedTo = "Elsewhere FC" } })
        let st = try depth(r, .ST_C)
        #expect(st.options.map(\.player) == [PlannerFixture.id(.ST_C, "first")])
        #expect(st.onLoan.count == 1)
        #expect(st.dropToNextBest == nil)
        // Ten players for eleven slots: nobody is first choice up front, so there is no drop either.
        let ten = try PlannerFixture.squad().filter { $0.name.hasSuffix("first") && !$0.name.hasPrefix("ST_C") }
        let tiers = try SquadTiers.compute(tactic: tactic, players: ten, ownClub: "Oxford City", catalog: catalog,
                                           profile: profile, parameters: .fm27, ignoringInjuries: true)
        try #require(tiers.first[.ST_C] == nil)
        #expect(try depth(report(ten), .ST_C).dropToNextBest == nil)
    }

    @Test func thinSlotsAreOrderedByNeed() throws {
        // ST_C has nobody (cover 0); AM_C and GK each have one solid player and a second choice short of solid who
        // could still step in, AM_C's much weaker, so AM_C has the larger drop.
        let weak = named(.AM_C, "second"), keeper = named(.GK, "second")
        let players = try PlannerFixture.squad().filter { !$0.name.hasPrefix("ST_C") }.map { p -> Player in
            var p = p
            if p.name == keeper { p.familiarity[.goalkeeper] = 14 }
            if p.name == weak { p = Player.fixture(name: p.name, all: 4, familiarity: [.attackingMidCentral: 14]) }
            return p
        }
        let r = try report(players)
        let am = try depth(r, .AM_C), gk = try depth(r, .GK)
        #expect(am.cover == 1 && gk.cover == 1)
        #expect(try #require(am.dropToNextBest) > #require(gk.dropToNextBest))
        // Without a striker, a wide player is moved up front, which also thins his old slot.
        #expect(r.thin.first == .ST_C)
        let a = try #require(r.thin.firstIndex(of: .AM_C)), g = try #require(r.thin.firstIndex(of: .GK))
        #expect(a < g)
    }

    @Test func slotsTiedOnCoverAndDropGoInSlotOrder() throws {
        // Eleven first choices and nobody else: every slot has cover 1 and nobody who could step in (the centre-backs
        // and the defensive midfielders are options at each other's slots, but first choices there).
        let r = try report(PlannerFixture.squad().filter { $0.name.hasSuffix("first") })
        #expect(r.slots.allSatisfy { $0.cover == 1 && $0.dropToNextBest == nil })
        #expect(r.thin == (try tactic.assignments(catalog: catalog)).map(\.slot))
    }

    @Test func aSlotWithoutASecondChoiceRanksAheadOfOneWithAnyDrop() throws {
        let all = try PlannerFixture.squad()
        let firsts = all.filter { $0.name.hasSuffix("first") }
        // ST_C has no second player; AM_C has one, short of solid, so both have cover 1.
        let seconds = all.filter { $0.name.hasSuffix("second") && !$0.name.hasPrefix("ST_C") }.map { p -> Player in
            var p = p; if p.name.hasPrefix("AM_C") { p.familiarity[.attackingMidCentral] = 14 }; return p
        }
        let r = try report(firsts + seconds)
        let st = try depth(r, .ST_C), am = try depth(r, .AM_C)
        #expect(st.cover == 1 && am.cover == 1)
        try #require(st.dropToNextBest == nil)
        _ = try #require(am.dropToNextBest)
        // AM_C comes first in slot order, so only the rule puts ST_C ahead of it.
        let a = try #require(r.thin.firstIndex(of: .ST_C)), b = try #require(r.thin.firstIndex(of: .AM_C))
        #expect(a < b)
    }

    @Test func aSecondChoiceSolidInOnePhaseOnlyIsNotSolid() throws {
        let name = named(.AM_L, "second")
        func solid(ip: Int, oop: Int) throws -> Bool {
            let r = try report(squad { if $0.name == name {
                $0.familiarity[.attackingMidLeft] = ip; $0.familiarity[.midfielderLeft] = oop } })
            return try #require(try depth(r, .AM_L).options.first { $0.player == PlannerFixture.id(.AM_L, "second") }).isSolid
        }
        #expect(try solid(ip: 15, oop: 14) == false)
        #expect(try solid(ip: 14, oop: 15) == false)
        #expect(try solid(ip: 15, oop: 15) == true)
    }

    @Test func theReportSaysWhatItRestsOn() throws {
        #expect(try report(PlannerFixture.squad()).basis == .derived)
        var parameters = EngineParameters.fm27
        parameters.depthCoverFamiliarity = Parameter(10, .fm27Measured, source: "test")
        parameters.depthSolidFamiliarity = Parameter(15, .fm27Official, source: "test")
        parameters.depthThinBelow = Parameter(2, .carriedOverFM26, source: "test")
        let r = try Depth.report(tactic: tactic, players: PlannerFixture.squad(), ownClub: "Oxford City",
                                 catalog: catalog, profile: profile, parameters: parameters)
        #expect(r.basis == .carriedOverFM26)
        parameters.depthThinBelow = Parameter(2, .fm27Measured, source: "test")
        #expect(try Depth.report(tactic: tactic, players: PlannerFixture.squad(), ownClub: "Oxford City",
                                 catalog: catalog, profile: profile, parameters: parameters).basis == .fm27Official)
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
