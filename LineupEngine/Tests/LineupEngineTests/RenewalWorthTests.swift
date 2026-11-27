import Foundation
import Testing
@testable import LineupEngine

@Suite struct RenewalWorthTests {
    let rules = EngineParameters.fm27.declineRules.value

    @Test func theFallIsTheLastStepAtOrUnderTheAge() {
        for (age, points) in [(29, 0.0), (30, 3), (31, 3), (32, 6), (34, 6), (35, 9), (40, 9)] {
            #expect(Renewal.fall(at: age, rules: rules) == points, "age \(age)")
        }
    }

    @Test func abilityAfterDeclineTakesEachSeasonAtItsAge() {
        for (ability, age, after) in [(70, 28, 70.0), (70, 29, 67), (70, 30, 64), (70, 31, 61), (70, 34, 55), (70, 35, 52),
                                      (5, 35, 0)] {
            #expect(Renewal.abilityAfterDecline(ability, age: age, rules: rules) == after, "\(ability) at \(age)")
        }
    }

    @Test func problemsAreFoundInTheDeclineRules() {
        #expect(Renewal.problems(in: rules).isEmpty)
        func found(_ edit: (inout DeclineRules) -> Void) -> [String] {
            var r = rules; edit(&r); return Renewal.problems(in: r)
        }
        let cases: [[String]] = [
            found { $0.steps = [DeclineStep(fromAge: 32, points: 6), DeclineStep(fromAge: 30, points: 3)] },
            found { $0.steps[0].points = -1 },
            found { $0.steps[0].points = .nan },
            found { $0.seasons = 0 },
            found { $0.steps = [] },
        ]
        for sentences in cases {
            #expect(sentences.count == 1)
            #expect(sentences.first?.contains("declineRules") == true)
        }
        var bad = EngineParameters.fm27
        bad.declineRules = Parameter(DeclineRules(steps: [], seasons: 2), .derived, source: "test")
        #expect(FitnessModel.problems(in: bad).contains { $0.contains("declineRules") })
        #expect(!FitnessModel.problems(in: .fm27).contains { $0.contains("declineRules") })
    }

    @Test func theStandardIsTheOutfieldFirstChoicesInPosition() throws {
        let tactic = try PlannerFixture.tactic()
        let catalog = try RoleCatalog.fm27()
        let profile = try RatingProfile.standard()
        let players = try PlannerFixture.squad()
        let needs = try Scouting.needs(tactic: tactic, players: players, ownClub: "Oxford City", going: [], retraining: [],
                                       catalog: catalog, profile: profile, parameters: .fm27)
        let standard = Renewal.standard(elevens: needs.elevens, depth: needs.depth, players: players, parameters: .fm27)
        #expect(standard.rating != nil)
        #expect(standard.rating == needs.outfieldAverageRating)
        #expect(standard.ability == needs.outfieldAverageAbility)
    }

    @Test func aSquadOfOneGoalkeeperHasNoStandard() throws {
        let tactic = try PlannerFixture.tactic()
        let catalog = try RoleCatalog.fm27()
        let profile = try RatingProfile.standard()
        let keeper = try #require(try tactic.assignments(catalog: catalog).first { $0.ipPosition == .goalkeeper })
        let players = try PlannerFixture.squad().filter { $0.id == PlannerFixture.id(keeper.slot, "first") }
        #expect(players.count == 1)
        let needs = try Scouting.needs(tactic: tactic, players: players, ownClub: "Oxford City", going: [], retraining: [],
                                       catalog: catalog, profile: profile, parameters: .fm27)
        let standard = Renewal.standard(elevens: needs.elevens, depth: needs.depth, players: players, parameters: .fm27)
        #expect(standard == SquadStandard(rating: nil, ability: nil))
    }
}

/// A player's worth over a new contract against the first eleven's standard (`Renewal.worths`).
@Suite struct RenewalWorthMeasureTests {
    let tactic = try! PlannerFixture.tactic()
    let catalog = try! RoleCatalog.fm27()
    let profile = try! RatingProfile.standard()
    let parameters = EngineParameters.fm27
    let ownClub = "Oxford City"
    var offset: Double { parameters.ratingAbilityOffset.value }

    func assignment(_ slot: SlotID) -> SlotAssignment {
        try! tactic.assignments(catalog: catalog).first { $0.slot == slot }!
    }

    /// A player with every attribute `all` and familiarity 20 at the positions of each of `slots`, 1 elsewhere.
    func player(_ name: String, age: Int = 25, all: Int = 13, slots: [SlotID] = [.D_L], currentAbility: Int = 100,
                potentialAbility: Int = 120, change: (inout Player) -> Void = { _ in }) -> Player {
        let positions = slots.flatMap { [assignment($0).ipPosition, assignment($0).oopPosition] }
        var p = Player.fixture(name: name, age: age, all: all,
                               familiarity: Dictionary(positions.map { ($0, 20) }, uniquingKeysWith: { a, _ in a }),
                               currentAbility: currentAbility, potentialAbility: potentialAbility)
        change(&p)
        return p
    }

    struct Measured {
        let worths: [PlayerID: RenewalWorth]
        let standard: SquadStandard
        let depth: DepthReport
        /// His full-fitness rating at `slot`, here or out on loan.
        func rating(_ id: PlayerID, at slot: SlotID) -> Double? {
            depth.slots.first { $0.slot == slot }.flatMap { s in (s.options + s.onLoan).first { $0.player == id } }?.rating
        }
    }

    func measure(_ players: [Player], parameters: EngineParameters = .fm27) throws -> Measured {
        let elevens = try Elevens.report(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                                         profile: profile, parameters: parameters)
        let depth = try Depth.report(tactic: tactic, players: players, ownClub: ownClub, elevens: elevens,
                                     catalog: catalog, profile: profile, parameters: parameters)
        let worths = try Renewal.worths(players: players, ownClub: ownClub, elevens: elevens, depth: depth,
                                        parameters: parameters)
        return Measured(worths: worths,
                        standard: Renewal.standard(elevens: elevens, depth: depth, players: players,
                                                   parameters: parameters),
                        depth: depth)
    }

    func squad(_ extra: [Player]) throws -> [Player] { try PlannerFixture.squad() + extra }

    @Test func aPlayerOfTwentyFourToTwentyEightIsMeasuredAsHeIsToday() throws {
        for age in [24, 26, 28] {
            let p = player("Steady", age: age)
            let m = try measure(try squad([p]))
            let worth = try #require(m.worths[p.id], "age \(age)")
            #expect(worth.ahead == .today)
            #expect(worth.share == worth.shareToday)
            let rating = try #require(m.rating(p.id, at: .D_L))
            #expect(worth.slot == .D_L)
            #expect(abs(worth.shareToday - rating / m.standard.rating!) < 1e-12)
            #expect(worth.age == age)
            #expect(worth.ability == 100)
        }
    }

    @Test func aYoungPlayerIsMeasuredAtHisReachByRatingAndByAbility() throws {
        func young(_ name: String, current: Int, potential: Int) -> Player {
            player(name, age: 20, currentAbility: current, potentialAbility: potential)
        }
        // Scaled up to his reach his rating clears the line, but his reach as ability is well under the first choices',
        // and he is under the line today, so the floor at today's share does not lift him over it.
        let short = young("Short", current: 40, potential: 70)
        // Both clear.
        let clear = young("Clear", current: 90, potential: 140)
        let players = try squad([short, clear])
        let m = try measure(players)
        let standard = m.standard
        for (p, meets) in [(short, false), (clear, true)] {
            let worth = try #require(m.worths[p.id])
            let reach = try Reach.estimate(for: p, parameters: parameters).reach
            #expect(worth.ahead == .reach(reach))
            let rating = try #require(m.rating(p.id, at: .D_L))
            let a = Double(p.currentAbility)
            let byRating = rating * (offset + reach) / (offset + a) / standard.rating!
            let byAbility = (offset + reach) / standard.ability!
            #expect(abs(worth.shareToday - rating / standard.rating!) < 1e-12)
            #expect(abs(worth.share - max(worth.shareToday, min(byRating, byAbility))) < 1e-12)
            #expect(worth.meetsStandard == meets, "\(p.name)")
            if !meets {
                #expect(Scouting.clearsWeakLine(byRating, average: 1, parameters: parameters))
                #expect(!Scouting.clearsWeakLine(byAbility, average: 1, parameters: parameters))
                #expect(!Scouting.clearsWeakLine(worth.shareToday, average: 1, parameters: parameters))
            }
        }
    }

    @Test func aYoungPlayerIsNeverWorthLessThanHeIsToday() throws {
        // The outfield first choices at ability 130 put the standard by ability far above a player of 95.
        let players = try PlannerFixture.squad().map { p in
            var p = p
            if p.name.hasSuffix("first"), p.id != PlannerFixture.id(.GK, "first") { p.currentAbility = 130 }
            return p
        }
        let level = player("Level", age: 22, all: 15, currentAbility: 95, potentialAbility: 95)
        let rising = player("Rising", age: 22, all: 15, currentAbility: 95, potentialAbility: 98)
        let m = try measure(players + [level, rising])
        let same = try #require(m.worths[level.id])
        #expect(same.ahead == .today)
        #expect(same.share == same.shareToday)
        #expect(same.meetsStandard)
        let worth = try #require(m.worths[rising.id])
        let reach = try Reach.estimate(for: rising, parameters: parameters).reach
        #expect(reach == 98)
        #expect(worth.ahead == .reach(98))
        // By ability alone his reach would be under the line, but his share stays at today's.
        #expect(!Scouting.clearsWeakLine((offset + reach) / m.standard.ability!, average: 1, parameters: parameters))
        #expect(worth.shareToday == same.shareToday)
        #expect(worth.share >= worth.shareToday)
        #expect(worth.share == worth.shareToday)
        #expect(worth.meetsStandard)
    }

    @Test func anOlderPlayerIsMeasuredAfterTheFallExpected() throws {
        let older = player("Older", age: 30, currentAbility: 70)
        let younger = player("Younger", age: 28, currentAbility: 70)
        let m = try measure(try squad([older, younger]))
        let worth = try #require(m.worths[older.id])
        #expect(worth.ahead == .decline(to: 64, seasons: 2))
        #expect(worth.share < worth.shareToday)
        let rating = try #require(m.rating(older.id, at: .D_L))
        // By rating alone, since his ability falls.
        #expect(abs(worth.share - rating * (offset + 64) / (offset + 70) / m.standard.rating!) < 1e-12)
        let same = try #require(m.worths[younger.id])
        #expect(same.ahead == .today)
        #expect(same.share == same.shareToday)
    }

    @Test func anOlderPlayerFarAboveTheStandardStillMeetsIt() throws {
        let veteran = player("Veteran", age: 36, all: 18, currentAbility: 150)
        let m = try measure(try squad([veteran]))
        let worth = try #require(m.worths[veteran.id])
        #expect(worth.ahead == .decline(to: 132, seasons: 2))
        #expect(worth.share < worth.shareToday)
        #expect(worth.share > 0.95)
        #expect(worth.meetsStandard)
    }

    @Test func theGoalkeeperIsMeasuredByAbility() throws {
        let keeper = player("Keeper", all: 10, slots: [.GK], currentAbility: 110)
        let better = player("Better Hands", all: 18, slots: [.GK], currentAbility: 110)
        let m = try measure(try squad([keeper, better]))
        for p in [keeper, better] {
            let worth = try #require(m.worths[p.id])
            #expect(worth.slot == .GK)
            #expect(worth.isGoalkeeperSlot)
            // His rating plays no part: (offset + ability) against the outfield first choices' (offset + ability).
            #expect(abs(worth.share - (offset + 110) / (offset + 100)) < 1e-12)
            #expect(worth.share == worth.shareToday)
        }
        let outfield = try #require(m.worths[PlannerFixture.id(.D_L, "first")])
        #expect(!outfield.isGoalkeeperSlot)
    }

    @Test func aYoungGoalkeeperIsMeasuredAtHisReachAsAbility() throws {
        let keeper = player("Young Keeper", age: 20, all: 10, slots: [.GK], currentAbility: 60, potentialAbility: 90)
        let m = try measure(try squad([keeper]))
        let worth = try #require(m.worths[keeper.id])
        let reach = try Reach.estimate(for: keeper, parameters: parameters).reach
        #expect(abs(worth.share - (offset + reach) / (offset + 100)) < 1e-12)
        #expect(abs(worth.shareToday - (offset + 60) / (offset + 100)) < 1e-12)
    }

    @Test func theBestSlotIsHisAndTheEarlierWinsATie() throws {
        // Familiar at both centre-back slots and both defensive midfield slots, which have the same roles in pairs.
        let p = player("Versatile", all: 15, slots: [.D_CL, .D_CR, .DM_L, .DM_R])
        let m = try measure(try squad([p]))
        let worth = try #require(m.worths[p.id])
        let order = m.depth.slots.map(\.slot)
        let ratings = try [SlotID.D_CL, .D_CR, .DM_L, .DM_R].map { try #require(m.rating(p.id, at: $0)) }
        #expect(ratings[0] == ratings[1])
        #expect(ratings[2] == ratings[3])
        #expect(ratings[0] != ratings[2])
        let pair: [SlotID] = ratings[0] > ratings[2] ? [.D_CL, .D_CR] : [.DM_L, .DM_R]
        let earlier = pair.min { order.firstIndex(of: $0)! < order.firstIndex(of: $1)! }!
        #expect(worth.slot == earlier)
        #expect(abs(worth.share - max(ratings[0], ratings[2]) / m.standard.rating!) < 1e-12)
    }

    @Test func aPlayerOnLoanHereHasNoWorthAndOneOutOnLoanHasOne() throws {
        let borrowed = player("Borrowed") { $0.club = "Banbury United"; $0.loanedTo = "Oxford City" }
        let lent = player("Lent") { $0.loanedTo = "Wallingford" }
        let m = try measure(try squad([borrowed, lent]))
        #expect(m.rating(borrowed.id, at: .D_L) != nil)
        #expect(m.worths[borrowed.id] == nil)
        let worth = try #require(m.worths[lent.id])
        #expect(m.depth.slots.first { $0.slot == .D_L }!.onLoan.contains { $0.player == lent.id })
        #expect(worth.slot == .D_L)
    }

    @Test func aPlayerWhoCanPlayNoSlotHasNoWorth() throws {
        let nowhere = player("Nowhere", slots: [])
        let m = try measure(try squad([nowhere]))
        #expect(m.worths[nowhere.id] == nil)
    }

    @Test func exactlyFivePercentUnderDoesNotMeetTheStandardAndJustOverItDoes() throws {
        // The outfield first choices at ability 130 make the standard by ability 70 + 130 = 200; a goalkeeper of 120 is
        // 190, exactly 5% under it, and one of 121 is 4.5% under.
        let goalkeeperSlot = SlotID.GK
        let players = try PlannerFixture.squad().map { p in
            var p = p
            if p.name.hasSuffix("first"), p.id != PlannerFixture.id(goalkeeperSlot, "first") { p.currentAbility = 130 }
            return p
        }
        let exactly = player("Exactly", slots: [.GK], currentAbility: 120)
        let justOver = player("Just Over", slots: [.GK], currentAbility: 121)
        let m = try measure(players + [exactly, justOver])
        #expect(m.standard.ability == 200)
        let under = try #require(m.worths[exactly.id])
        #expect(abs(under.share - 0.95) < 1e-12)
        #expect(!under.meetsStandard)
        #expect(try #require(m.worths[justOver.id]).meetsStandard)
    }

    @Test func withNoStandardNobodyHasAWorth() throws {
        let keeper = try PlannerFixture.squad().filter { $0.id == PlannerFixture.id(.GK, "first") }
        #expect(keeper.count == 1)
        let m = try measure(keeper)
        #expect(m.standard == SquadStandard(rating: nil, ability: nil))
        #expect(m.rating(keeper[0].id, at: .GK) != nil)
        #expect(m.worths.isEmpty)
    }

    @Test func anAbilityOfZeroAndAPotentialBelowTheAbilityAreMeasuredWithoutGoingBelowTodayOrZero() throws {
        let zero = player("Zero", age: 35, currentAbility: 0, potentialAbility: 0)
        let capped = player("Capped", age: 20, currentAbility: 100, potentialAbility: 80)
        let m = try measure(try squad([zero, capped]))
        let none = try #require(m.worths[zero.id])
        #expect(none.ahead == .today)
        #expect(none.share == none.shareToday)
        #expect(none.share.isFinite && none.share > 0)
        // A reach that is not above his ability changes nothing: he is measured as he is today.
        let young = try #require(m.worths[capped.id])
        #expect(young.ahead == .today)
        #expect(young.share == young.shareToday)
    }

    @Test func aYoungPlayerMissingAnAttributeIsAnErrorNamingHimAndIt() throws {
        let young = player("Unknown Mind", age: 20) { $0.attributes[.professionalism] = nil }
        #expect(throws: RatingError.missingAttribute(player: "Unknown Mind", attribute: .professionalism)) {
            try measure(try squad([young]))
        }
        // An older player is not asked for it.
        let older = player("Older Mind", age: 26) { $0.attributes[.professionalism] = nil }
        #expect(try measure(try squad([older])).worths[older.id] != nil)
    }

    @Test func theEvidenceIsTheWeakestOfTheRulesEachWorthRestsOn() throws {
        func label<T: Sendable>(_ p: Parameter<T>, _ evidence: Evidence) -> Parameter<T> {
            Parameter(p.value, evidence, source: "test")
        }
        var strong = EngineParameters.fm27
        strong.scoutingWeakShare = label(strong.scoutingWeakShare, .fm27Measured)
        strong.ratingAbilityOffset = label(strong.ratingAbilityOffset, .fm27Measured)
        strong.growthPerSeason = label(strong.growthPerSeason, .fm27Observation)
        strong.growthProfessionalismRates = label(strong.growthProfessionalismRates, .fm27Measured)
        strong.declineRules = label(strong.declineRules, .carriedOverFM26)
        let today = player("Today", age: 26)
        let young = player("Young", age: 20)
        let old = player("Old", age: 31)
        let m = try measure(try squad([today, young, old]), parameters: strong)
        #expect(m.worths[today.id]?.basis == .fm27Measured)
        #expect(m.worths[young.id]?.basis == .fm27Observation)
        #expect(m.worths[old.id]?.basis == .carriedOverFM26)
        #expect(try measure(try squad([today])).worths[today.id]?.basis == .derived)
    }
}
