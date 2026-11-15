import Foundation
import Testing
@testable import LineupEngine

@Suite struct RemovalTests {
    let tactic = try! PlannerFixture.tactic()
    let catalog = try! RoleCatalog.fm27()
    let profile = try! RatingProfile.standard()
    let parameters = EngineParameters.fm27

    let asOf = Day(year: 2026, month: 11, day: 14)!

    func report(_ players: [Player], ownClub: String? = "Oxford City", parameters: EngineParameters? = nil,
                money: MoneyStyle = .weeklyPounds, history: [ConfirmedLineup] = [],
                retraining: [Retraining] = []) throws -> RemovalReport {
        try Removal.report(tactic: tactic, players: players, ownClub: ownClub, money: money,
                           history: StartHistory(history), asOf: asOf, retraining: retraining, catalog: catalog,
                           profile: profile, parameters: parameters ?? self.parameters)
    }

    /// A weak player of the club's own, in neither eleven and among the weakest: every attribute 10, familiarity 1
    /// everywhere, current ability 100, potential 120, £500 a week, 12 months left.
    func target(_ name: String = "Target", age: Int = 25, attributes: [Attribute: Int] = [:], currentAbility: Int = 100,
                potentialAbility: Int = 120, change: (inout Player) -> Void = { _ in }) -> Player {
        var player = Player.fixture(name: name, age: age, attributes: attributes, currentAbility: currentAbility,
                                    potentialAbility: potentialAbility)
        change(&player)
        return player
    }

    /// The same, on loan here from another club.
    func loanee(_ name: String = "Loanee", attributes: [Attribute: Int] = [:], currentAbility: Int = 100,
                change: (inout Player) -> Void = { _ in }) -> Player {
        target(name, attributes: attributes, currentAbility: currentAbility) { p in
            p.club = "Other FC"; p.loanedTo = "Oxford City"; change(&p)
        }
    }

    /// The planner's squad: 22 players of current ability 100 on £500 a week with 12 months left, every attribute 14
    /// for the first eleven and 12 for the second.
    func squad(_ extra: [Player] = []) throws -> [Player] { try PlannerFixture.squad() + extra }

    /// The planner's squad with one of its players changed.
    func squad(changing id: PlayerID, _ change: (inout Player) -> Void) throws -> [Player] {
        try PlannerFixture.squad().map { p in
            var p = p
            if p.id == id { change(&p) }
            return p
        }
    }

    /// `player`'s advice in `players` (the planner's squad and him when not given).
    func advice(_ player: Player, in players: [Player]? = nil, parameters: EngineParameters? = nil) throws -> RemovalAdvice {
        let r = try report(players ?? squad([player]), parameters: parameters)
        return try #require(r.advice.first { $0.player == player.id })
    }

    func advice(_ id: PlayerID, in players: [Player]) throws -> RemovalAdvice {
        try #require(try report(players).advice.first { $0.player == id })
    }

    func review(_ player: Player, in players: [Player]? = nil, parameters: EngineParameters? = nil) throws -> LoanReview {
        let r = try report(players ?? squad([player]), parameters: parameters)
        return try #require(r.loans.first { $0.player == player.id })
    }

    func reasons(_ reasons: [RemovalReason], _ prefix: String) -> [RemovalReason] {
        reasons.filter { $0.text.hasPrefix(prefix) }
    }

    func reason(_ text: String, _ points: Int) -> RemovalReason { RemovalReason(text: text, points: points) }

    /// The squad, `player`, and a balancing player of the club's own so the squad average ability is exactly 100.
    func averaging100(_ player: Player) throws -> [Player] {
        try squad([player, Player.fixture(name: "Balancer", currentAbility: 200 - player.currentAbility)])
    }

    let weakest = "Among the weakest 30% of the squad for this tactic"

    func named(_ slot: SlotID, _ tier: String) -> String { PlannerFixture.name(slot, tier) }

    func assignment(_ slot: SlotID) -> SlotAssignment {
        try! tactic.assignments(catalog: catalog).first { $0.slot == slot }!
    }

    /// A player of the club's own, aged 17, with every attribute `all` but Professionalism 20 and Ambition and
    /// Determination 10 (so he grows at the table's full rate: his reach is his potential up to 136 points on),
    /// familiarity `familiarity` at both of `slot`'s positions and 1 elsewhere, current ability 80, unknown months left.
    func youngster(_ name: String = "Young", age: Int = 17, all: Int = 10, familiarity: Int = 12, slot: SlotID = .D_L,
                   potentialAbility: Int, change: (inout Player) -> Void = { _ in }) -> Player {
        let positions = [assignment(slot).ipPosition, assignment(slot).oopPosition]
        var player = Player.fixture(name: name, age: age, all: all, attributes: [.professionalism: 20],
                                    familiarity: Dictionary(positions.map { ($0, familiarity) }, uniquingKeysWith: { a, _ in a }),
                                    currentAbility: 80, potentialAbility: potentialAbility)
        player.monthsLeft = nil
        change(&player)
        return player
    }

    /// `player`'s full-fitness rating at `slot` among `players`, and the first and second choice's there.
    func ratings(of player: PlayerID, at slot: SlotID,
                 in players: [Player]) throws -> (his: Double, first: Double, second: Double) {
        let tiers = try Elevens.report(tactic: tactic, players: players, ownClub: "Oxford City", catalog: catalog,
                                       profile: profile, parameters: parameters).tiers
        let first = try #require(tiers.first[slot]), second = try #require(tiers.second[slot])
        return (try #require(tiers.ratings[player]?[slot]), try #require(tiers.ratings[first]?[slot]),
                try #require(tiers.ratings[second]?[slot]))
    }

    /// The least potential that takes a player of current ability `current`, rated `his` at a slot today, to a reach
    /// rating of at least `rating` there: a rating scales by the offset plus the ability.
    func potential(reaching rating: Double, his: Double, current: Int = 80) -> Int {
        let offset = parameters.ratingAbilityOffset.value
        return Int(((offset + Double(current)) * rating / his - offset).rounded(.up))
    }

    /// His reach rating at a slot where he is rated `his` today at current ability `current`, with this potential.
    func reachRating(his: Double, potential: Int, current: Int = 80) -> Double {
        let offset = parameters.ratingAbilityOffset.value
        return his * (offset + Double(potential)) / (offset + Double(current))
    }

    // MARK: Contract type

    @Test func aPlayerOutOfContractAddsFifty() throws {
        let a = try advice(target { $0.contractType = .outOfContract })
        #expect(a.reasons.first == reason("Not on a full-time contract", 50))
        #expect(reasons(try advice(target()).reasons, "Not on").isEmpty)
        #expect(reasons(try advice(target()).reasons, "Contract type").isEmpty)
    }

    @Test func aContractTypeTheToolDoesNotReadGivesNoPointsAndNoCost() throws {
        // +15 in neither eleven, +30 among the weakest, +15 for 12 months, +25 for Controversy 17: 85, critical.
        // Read as not full time it would have been 135, released at no cost.
        let unread = target(attributes: [.controversy: 17]) { $0.contractType = .other("Amateur") }
        let a = try advice(unread)
        #expect(a.reasons.first == reason("Contract type Amateur is not one this tool reads: no release cost is given", 0))
        #expect(reasons(a.reasons, "Not on").isEmpty)
        #expect(a.score == 85 && a.level == .critical)
        #expect(a.releaseCost == nil && a.mutualCost == nil)
        // Not released by the first step; with the costs unknown he is never terminated, so he is sold.
        #expect(a.action == .sell)
        // A young player is not loaned out: +70 as markedly lower, +15 for 12 months: 85, critical, and sold.
        let young = try advice(target(age: 19, currentAbility: 50, potentialAbility: 50) {
            $0.contractType = .other("Amateur")
        })
        #expect(young.outlook?.level == .markedlyLower)
        #expect(young.score == 85 && young.level == .critical && young.action == .sell)
        #expect(young.releaseCost == nil && young.mutualCost == nil)
        // A full-time contract is unchanged: costs from the wage and months left.
        let full = try advice(target(attributes: [.controversy: 17]))
        #expect(full.score == 85 && full.action == .terminate)
        #expect(full.releaseCost == 27_083 && full.mutualCost == 14_896)
    }

    @Test func aYouthContractHasCostsAndNoContractTypeLine() throws {
        // £50 a week, 22 months: 50 x 52 / 12 x 22.5 = 4,875; mutual 0.55 of that.
        let a = try advice(target(age: 16) { $0.contractType = .youth; $0.wagePerWeek = 50; $0.monthsLeft = 22 })
        #expect(a.releaseCost == 4_875 && a.mutualCost == 2_681)
        #expect(a.reasons.allSatisfy { !$0.text.contains("full-time contract") && !$0.text.contains("is not one this tool reads") })
    }

    @Test func aContractTypeTheToolDoesNotReadStillHasNoCosts() throws {
        let a = try advice(target { $0.contractType = .other("Amateur") })
        #expect(a.releaseCost == nil && a.mutualCost == nil)
        #expect(a.reasons.contains(reason("Contract type Amateur is not one this tool reads: no release cost is given", 0)))
    }

    @Test func aYouthContractWithZeroMonthsLeftIsNoContract() throws {
        let none = try advice(target { $0.contractType = .youth; $0.monthsLeft = 0; $0.wagePerWeek = 50 })
        #expect(none.reasons.first == reason("No contract: 0 months left", 50))
        #expect(none.releaseCost == 0 && none.mutualCost == 0)
    }

    @Test func theReleaseCostAllowsForThePartMonth() throws {
        let player = target { $0.wagePerWeek = 600; $0.monthsLeft = 9 }
        let a = try advice(player)
        #expect(a.releaseCost == 24_700 && a.mutualCost == 13_585)
        var without = parameters
        without.contractMonthsAllowance = Parameter(0, .derived, source: "test")
        let before = try advice(player, parameters: without)
        #expect(before.releaseCost == 23_400 && before.mutualCost == 12_870)
    }

    // MARK: The elevens

    @Test func theElevensSetPointsAndTheTier() throws {
        let players = try squad([target()])
        let first = try advice(PlannerFixture.id(.D_L, "first"), in: players)
        #expect(first.reasons.first == reason("In the first eleven at left back", -40))
        #expect(first.tier == .first(.D_L))
        let second = try advice(PlannerFixture.id(.D_L, "second"), in: players)
        #expect(second.reasons.first == reason("In the second eleven at left back", -20))
        #expect(second.tier == .second(.D_L))
        let neither = try advice(target(), in: players)
        #expect(neither.reasons.first == reason("In neither eleven", 15))
        #expect(neither.tier == .backup)
        #expect(reasons(neither.reasons, "In the").isEmpty)
    }

    // MARK: The weakest

    /// Each player's best share: the highest, over the slots with a first choice rated above 0, of his rating there over
    /// the first choice's; nil with none.
    func bestShares(_ players: [Player]) throws -> [PlayerID: Double?] {
        let tiers = try Elevens.report(tactic: tactic, players: players, ownClub: "Oxford City", catalog: catalog,
                                       profile: profile, parameters: parameters).tiers
        var shares: [PlayerID: Double?] = [:]
        for player in players {
            var best: Double?
            for (slot, first) in tiers.first {
                guard let firstRating = tiers.ratings[first]?[slot], firstRating > 0,
                      let rating = tiers.ratings[player.id]?[slot] else { continue }
                best = max(best ?? -.infinity, rating / firstRating)
            }
            shares[player.id] = best
        }
        return shares
    }

    @Test func theWeakestThirtyPercentOfEveryoneAssessedAddThirty() throws {
        // 23 assessed: 30% of 23 is 6.9, so 6.
        let players = try squad([target()])
        let r = try report(players)
        let flagged = r.advice.filter { $0.reasons.contains(reason(weakest, 30)) }
        #expect(flagged.count == 6)
        #expect(flagged.contains { $0.player == target().id })
        #expect(!flagged.contains { $0.player == PlannerFixture.id(.D_L, "first") })
    }

    @Test func theWeakestAreRankedByShareOfTheFirstChoice() throws {
        // Weaker goalkeepers: their ratings are the lowest in the squad, but the second's is close to the first's.
        let players = try squad([target()]).map { p -> Player in
            var p = p
            let level = p.id == PlannerFixture.id(.GK, "first") ? 9 : p.id == PlannerFixture.id(.GK, "second") ? 8 : nil
            if let level { for attribute in Attribute.allCases { p.attributes[attribute] = level } }
            return p
        }
        let shares = try bestShares(players)
        let byShare = players.map(\.id).sorted { a, b in
            let sa = shares[a]!!, sb = shares[b]!!
            return sa != sb ? sa < sb : a.key < b.key
        }.prefix(6)
        // Ranked by raw best rating instead, the six would differ.
        let ratings = try Elevens.report(tactic: tactic, players: players, ownClub: "Oxford City", catalog: catalog,
                                         profile: profile, parameters: parameters).tiers.ratings
        let byRating = players.map(\.id).sorted { a, b in
            let ra = ratings[a]!.values.max()!, rb = ratings[b]!.values.max()!
            return ra != rb ? ra < rb : a.key < b.key
        }.prefix(6)
        try #require(Set(byShare) != Set(byRating))
        let flagged = try report(players).advice.filter { $0.reasons.contains(reason(weakest, 30)) }
        #expect(Set(flagged.map(\.player)) == Set(byShare))
        // Every first choice has a share of 1, so none is among the weakest here.
        #expect(flagged.allSatisfy { !$0.player.key.hasSuffix("first") })
        #expect(!flagged.contains { $0.player == PlannerFixture.id(.GK, "first") })
    }

    @Test func aFirstChoiceGoalkeeperIsNotAmongTheWeakest() throws {
        // The only goalkeeper, weak enough that his best rating is the lowest in the squad; first choice, his share is 1.
        let keeper = PlannerFixture.id(.GK, "first")
        let players = try PlannerFixture.squad().filter { $0.name != named(.GK, "second") }.map { p -> Player in
            guard p.id == keeper else { return p }
            var p = p
            for attribute in Attribute.allCases { p.attributes[attribute] = 8 }
            return p
        }
        let ratings = try Elevens.report(tactic: tactic, players: players, ownClub: "Oxford City", catalog: catalog,
                                         profile: profile, parameters: parameters).tiers.ratings
        let best = ratings.mapValues { $0.values.max()! }
        try #require(best.filter { $0.key != keeper }.values.allSatisfy { $0 > best[keeper]! })
        let shares = try bestShares(players)
        #expect(abs(shares[keeper]!! - 1) < 1e-9)
        let a = try advice(keeper, in: players)
        #expect(a.tier == .first(.GK))
        #expect(!a.reasons.contains(reason(weakest, 30)))
    }

    @Test func theWeakestShareIsRoundedDown() throws {
        let all = try squad([target()])
        // 10 assessed: 3. 9 assessed: 2.7, so 2. 3 assessed: 0.9, so none.
        for (count, flagged) in [(10, 3), (9, 2), (3, 0)] {
            let r = try report(Array(all.suffix(count)))
            #expect(r.advice.count == count)
            #expect(r.advice.filter { $0.reasons.contains(reason(weakest, 30)) }.count == flagged, "\(count)")
        }
    }

    @Test func playersOnLoanHereCountAmongTheWeakest() throws {
        // 24 assessed, the loanee among them: 7.2, so seven are the weakest, and the loanee is one of them.
        let r = try report(try squad([target(), loanee()]))
        let ownFlagged = r.advice.filter { $0.reasons.contains(reason(weakest, 30)) }.count
        let loanFlagged = r.loans.filter { $0.reasons.contains(reason(weakest, 30)) }.count
        #expect(loanFlagged == 1)
        #expect(ownFlagged + loanFlagged == 7)
    }

    // MARK: Thin cover

    /// His reasons from the thin-cover rule.
    func thinReasons(_ a: RemovalAdvice) -> [RemovalReason] {
        a.reasons.filter { $0.text.hasSuffix("where cover is thin") || $0.text.hasSuffix("would be thin without him") }
    }

    func depth(_ players: [Player], _ slot: SlotID) throws -> SlotDepth {
        try #require(try Depth.report(tactic: tactic, players: players, ownClub: "Oxford City", catalog: catalog,
                                      profile: profile, parameters: parameters).slots.first { $0.slot == slot })
    }

    @Test func aFirstChoiceAtAThinSlotTakesThirtyOff() throws {
        // Without a second goalkeeper, cover in goal is thin.
        let players = try PlannerFixture.squad().filter { $0.name != named(.GK, "second") }
        let a = try advice(PlannerFixture.id(.GK, "first"), in: players)
        #expect(a.reasons.prefix(2) == [reason("In the first eleven at goalkeeper", -40),
                                         reason("First choice at goalkeeper, where cover is thin", -30)])
        #expect(thinReasons(a).count == 1)
        #expect(a.basis == .derived)
        #expect(a.score == a.reasons.map(\.points).reduce(0, +))
    }

    @Test func anInjuredFirstChoiceAtAThinSlotIsProtected() throws {
        // The first-choice left back is injured, so he is not cover: only the second choice counts, and left back is thin.
        let first = PlannerFixture.id(.D_L, "first"), second = PlannerFixture.id(.D_L, "second")
        let players = try squad(changing: first) { $0.isInjured = true }
        try #require(try depth(players, .D_L).cover == 1)
        let a = try advice(first, in: players)
        #expect(a.reasons.prefix(2) == [reason("In the first eleven at left back", -40),
                                         reason("First choice at left back, where cover is thin", -30)])
        #expect(a.basis == .derived)
        // The second choice is the one player who counts as cover there.
        let b = try advice(second, in: players)
        #expect(b.reasons.prefix(2) == [reason("In the second eleven at left back", -20),
                                         reason("Counts as cover at left back, where cover is thin", -30)])
        #expect(b.basis == .derived)
        // The rule comes straight after the elevens row, after the contract row.
        let contract = try advice(first, in: players.map { p -> Player in
            var p = p; if p.id == first { p.contractType = .outOfContract }; return p
        })
        #expect(contract.reasons.prefix(3) == [reason("Not on a full-time contract", 50),
                                               reason("In the first eleven at left back", -40),
                                               reason("First choice at left back, where cover is thin", -30)])
    }

    @Test func coverAtTheLineIsProtected() throws {
        // AM_L has two solid players, exactly the line: without either it would be thin.
        let players = try squad()
        try #require(try depth(players, .AM_L).cover == parameters.depthThinBelow.value)
        for (id, row) in [(PlannerFixture.id(.AM_L, "first"), reason("In the first eleven at left attacking midfield", -40)),
                          (PlannerFixture.id(.AM_L, "second"), reason("In the second eleven at left attacking midfield", -20))] {
            let a = try advice(id, in: players)
            #expect(a.reasons.prefix(2) == [row, reason("Cover at left attacking midfield would be thin without him", -30)], "\(id.key)")
            #expect(a.basis == .derived)
        }
    }

    @Test func coverOneAboveTheLineGivesNothing() throws {
        // The second-choice right centre-back counts at both centre-back slots, so each has cover 3.
        let players = try squad()
        try #require(try depth(players, .D_CL).cover == parameters.depthThinBelow.value + 1)
        try #require(try depth(players, .D_CR).cover == parameters.depthThinBelow.value + 1)
        for id in [PlannerFixture.id(.D_CL, "first"), PlannerFixture.id(.D_CL, "second"), PlannerFixture.id(.D_CR, "second")] {
            let a = try advice(id, in: players)
            #expect(thinReasons(a).isEmpty, "\(id.key)")
            #expect(a.basis == .carriedOverFM26, "\(id.key)")
        }
    }

    @Test func theRuleAppliesOnceAtTheFirstSlotInOrder() throws {
        // Without the second-choice left centre-back, the right one counts as cover at both centre-back slots, each at
        // the line. He is protected once, for D_CL, which comes first.
        let players = try PlannerFixture.squad().filter { $0.name != named(.D_CL, "second") }
        try #require(try depth(players, .D_CL).cover == 2 && depth(players, .D_CR).cover == 2)
        let a = try advice(PlannerFixture.id(.D_CR, "second"), in: players)
        #expect(thinReasons(a) == [reason("Cover at centre-back would be thin without him", -30)])
    }

    @Test func aSecondElevenFillInWhoIsNotSolidGetsNothing() throws {
        // Without a second goalkeeper, or a second left back, the second eleven puts a spare player who is familiar
        // nowhere there. He is second choice at a thin slot but not cover.
        for slot in [SlotID.GK, .D_L] {
            let players = try PlannerFixture.squad().filter { $0.name != named(slot, "second") } + [target("Spare")]
            let a = try advice(target("Spare"), in: players)
            try #require(a.tier == .second(slot))
            try #require(try depth(players, slot).isThin)
            #expect(thinReasons(a).isEmpty, "\(slot.rawValue)")
        }
    }

    @Test func aLoaneeWhoIsFirstChoiceAtAThinSlotTakesThirtyOff() throws {
        let first = PlannerFixture.id(.D_L, "first"), second = PlannerFixture.id(.D_L, "second")
        let players = try PlannerFixture.squad().map { p -> Player in
            var p = p
            if p.id == first { p.club = "Other FC"; p.loanedTo = "Oxford City" }
            if p.id == second { p.isInjured = true }
            return p
        }
        let review = try #require(try report(players).loans.first { $0.player == first })
        #expect(review.reasons == [reason("In the first eleven at left back", -30),
                                   reason("First choice at left back, where cover is thin", -30)])
        #expect(review.score == -60)
        #expect(review.basis == .derived)
        // Where cover is above the line, nothing is added and the basis is the removal rules'.
        let centre = PlannerFixture.id(.D_CL, "first")
        let plain = try #require(try report(try squad(changing: centre) { p in
            p.club = "Other FC"; p.loanedTo = "Oxford City"
        }).loans.first)
        #expect(plain.reasons == [reason("In the first eleven at centre-back", -30)])
        #expect(plain.basis == .carriedOverFM26)
    }

    // MARK: Ability

    @Test func abilityUnderTheSquadAverageAddsPoints() throws {
        let cases: [(Int, RemovalReason?)] = [
            (84, reason("Current ability 84 against a squad average of 100", 25)),
            (85, reason("Current ability 85 against a squad average of 100", 10)),
            (99, reason("Current ability 99 against a squad average of 100", 10)),
            (100, nil),
        ]
        for (ability, expected) in cases {
            let t = target(currentAbility: ability, potentialAbility: 200)
            let a = try advice(t, in: try averaging100(t))
            #expect(reasons(a.reasons, "Current ability") == (expected.map { [$0] } ?? []), "\(ability)")
        }
    }

    @Test func theAverageInAReasonIsRoundedToTheNearestWhole() throws {
        // 22 at 100 and one at 80: 2,280 over 23 is 99.13.
        let a = try advice(target(currentAbility: 80, potentialAbility: 200))
        #expect(reasons(a.reasons, "Current ability") == [reason("Current ability 80 against a squad average of 99", 25)])
        let r = try report(try squad([target(currentAbility: 80, potentialAbility: 200)]))
        #expect(abs(try #require(r.squadAverageAbility) - 2_280.0 / 23) < 1e-9)
    }

    // MARK: Wages

    @Test func aHighWageOutsideBothElevensAddsPoints() throws {
        let cases: [(Double, RemovalReason?)] = [
            (751, reason("Paid £751 a week, against a median of £500, and in neither eleven", 35)),
            (750, reason("Paid £750 a week, against a median of £500, and in neither eleven", 20)),
            (501, reason("Paid £501 a week, against a median of £500, and in neither eleven", 20)),
            (500, nil),
        ]
        for (wage, expected) in cases {
            let a = try advice(target { $0.wagePerWeek = wage })
            #expect(reasons(a.reasons, "Paid") == (expected.map { [$0] } ?? []), "\(wage)")
        }
    }

    @Test func aHighWageInAnElevenAddsNothing() throws {
        let id = PlannerFixture.id(.D_L, "first")
        let a = try advice(id, in: try squad(changing: id) { $0.wagePerWeek = 2_000 })
        #expect(reasons(a.reasons, "Paid").isEmpty)
    }

    @Test func wagesAreWrittenInWholePoundsWithThousands() throws {
        let players = try squad([target { $0.wagePerWeek = 1_250 }]).map { p -> Player in
            var p = p; if p.id != target().id { p.wagePerWeek = 600 }; return p
        }
        let a = try advice(target(), in: players)
        #expect(reasons(a.reasons, "Paid") == [reason("Paid £1,250 a week, against a median of £600, and in neither eleven", 35)])
    }

    @Test func theMedianOfAnEvenCountIsTheMeanOfTheMiddleTwo() throws {
        // First eleven at £700, second at £400, the extra player at £400 and the target at £900: 24 wages,
        // the middle two £400 and £700, so the median is £550 and £900 is above 1.5 × £550.
        let players = try squad([target { $0.wagePerWeek = 900 }, Player.fixture(name: "Extra")]).map { p -> Player in
            var p = p
            if p.name.hasSuffix("first") { p.wagePerWeek = 700 }
            if p.name.hasSuffix("second") || p.name == "Extra" { p.wagePerWeek = 400 }
            return p
        }
        let a = try advice(target(), in: players)
        #expect(reasons(a.reasons, "Paid") == [reason("Paid £900 a week, against a median of £550, and in neither eleven", 35)])
    }

    // MARK: Months left

    @Test func aContractEndingSoonAddsPoints() throws {
        let cases: [(Int?, RemovalReason?)] = [
            (1, reason("Contract ends in 1 month", 25)),
            (6, reason("Contract ends in 6 months", 25)),
            (7, reason("Contract ends in 7 months", 15)),
            (12, reason("Contract ends in 12 months", 15)),
            (13, nil), (0, nil), (nil, nil),
        ]
        for (months, expected) in cases {
            let a = try advice(target { $0.monthsLeft = months })
            #expect(reasons(a.reasons, "Contract") == (expected.map { [$0] } ?? []), "\(String(describing: months))")
        }
    }

    @Test func zeroMonthsLeftIsNoContract() throws {
        // 0 months on a full-time contract: the out-of-contract points, no cost, and release.
        let none = try advice(target { $0.monthsLeft = 0; $0.wagePerWeek = 900 })
        #expect(none.reasons.first == reason("No contract: 0 months left", 50))
        #expect(reasons(none.reasons, "Not on").isEmpty && reasons(none.reasons, "Contract").isEmpty)
        #expect(none.releaseCost == 0 && none.mutualCost == 0)
        #expect([RemovalLevel.high, .critical].contains(none.level))
        #expect(none.action == .release)
        // 1 month: the contract-ends rule as before, and a cost.
        let one = try advice(target { $0.monthsLeft = 1; $0.wagePerWeek = 900 })
        #expect(reasons(one.reasons, "No contract").isEmpty)
        #expect(reasons(one.reasons, "Contract") == [reason("Contract ends in 1 month", 25)])
        #expect(one.releaseCost == 5_850)
        #expect(one.action != .release)
        // Unknown: neither rule, and no cost given.
        let unknown = try advice(target { $0.monthsLeft = nil })
        #expect(reasons(unknown.reasons, "No contract").isEmpty && reasons(unknown.reasons, "Contract").isEmpty)
        #expect(unknown.releaseCost == nil && unknown.mutualCost == nil)
        #expect(unknown.action != .release)
    }

    // MARK: Hidden and personality attributes

    func attributeReasons(_ attribute: Attribute, _ value: Int) throws -> [RemovalReason] {
        reasons(try advice(target(attributes: [attribute: value])).reasons, attribute.rawValue)
    }

    @Test func consistencyUnderEightOrAtEightAddsPoints() throws {
        #expect(try attributeReasons(.consistency, 7) == [reason("Consistency 7", 25)])
        #expect(try attributeReasons(.consistency, 8) == [reason("Consistency 8", 15)])
        #expect(try attributeReasons(.consistency, 9).isEmpty)
    }

    @Test func importantMatchesUnderEightAddsTwenty() throws {
        #expect(try attributeReasons(.importantMatches, 7) == [reason("Important Matches 7", 20)])
        #expect(try attributeReasons(.importantMatches, 8).isEmpty)
    }

    @Test func injuryPronenessOverFourteenAddsTwentyFive() throws {
        #expect(try attributeReasons(.injuryProneness, 15) == [reason("Injury Proneness 15", 25)])
        #expect(try attributeReasons(.injuryProneness, 14).isEmpty)
    }

    @Test func professionalismUnderTenAddsPoints() throws {
        #expect(try attributeReasons(.professionalism, 7) == [reason("Professionalism 7", 25)])
        #expect(try attributeReasons(.professionalism, 8) == [reason("Professionalism 8", 15)])
        #expect(try attributeReasons(.professionalism, 9) == [reason("Professionalism 9", 15)])
        #expect(try attributeReasons(.professionalism, 10).isEmpty)
    }

    @Test func ambitionUnderSixAddsTwentyFive() throws {
        #expect(try attributeReasons(.ambition, 5) == [reason("Ambition 5", 25)])
        #expect(try attributeReasons(.ambition, 6).isEmpty)
    }

    @Test func controversyOverSixteenAddsTwentyFive() throws {
        #expect(try attributeReasons(.controversy, 17) == [reason("Controversy 17", 25)])
        #expect(try attributeReasons(.controversy, 16).isEmpty)
    }

    @Test func temperamentUnderEightAddsFifteen() throws {
        #expect(try attributeReasons(.temperament, 7) == [reason("Temperament 7", 15)])
        #expect(try attributeReasons(.temperament, 8).isEmpty)
    }

    // MARK: Age and growth

    @Test func aFalseProspectIsMarkedAndAddsNoLine() throws {
        // 72 points in 4 years is 18 a year.
        let a = try advice(target(age: 20, attributes: [.professionalism: 11], potentialAbility: 172))
        #expect(a.isFalseProspect)
        #expect(reasons(a.reasons, "Would need").isEmpty)
        // Just over 15 a year, with Professionalism 13.
        let edge = try advice(target(age: 20, attributes: [.professionalism: 13], potentialAbility: 161))
        #expect(edge.isFalseProspect)
        #expect(reasons(edge.reasons, "Would need").isEmpty)
        // Exactly 15 a year; Professionalism 14; aged 21.
        for t in [target(age: 20, attributes: [.professionalism: 11], potentialAbility: 160),
                  target(age: 20, attributes: [.professionalism: 14], potentialAbility: 172),
                  target(age: 21, attributes: [.professionalism: 11], potentialAbility: 172)] {
            let b = try advice(t)
            #expect(reasons(b.reasons, "Would need").isEmpty, "\(t.age) \(t.potentialAbility)")
            #expect(!b.isFalseProspect, "\(t.age) \(t.potentialAbility)")
        }
    }

    @Test func aPlayerOfTwentyFourWithLittleRoomAndUnderTheAverageAddsTwenty() throws {
        // Current 90, potential 98: under 9% room. The squad average is 100.
        let t = target(age: 24, currentAbility: 90, potentialAbility: 98)
        #expect(reasons(try advice(t, in: try averaging100(t)).reasons, "Aged")
                == [reason("Aged 24 with little room to grow", 20)])
        for t in [target(age: 25, currentAbility: 90, potentialAbility: 98),
                  target(age: 24, currentAbility: 90, potentialAbility: 99),     // exactly 10%
                  target(age: 24, currentAbility: 100, potentialAbility: 105)] { // at the average
            #expect(reasons(try advice(t, in: try averaging100(t)).reasons, "Aged").isEmpty, "\(t.age) \(t.currentAbility) \(t.potentialAbility)")
        }
    }

    @Test func stallingAppliesAtTwentyFourAndNotAtTwentyThree() throws {
        let older = target(age: 24, currentAbility: 90, potentialAbility: 98)
        let a = try advice(older, in: try averaging100(older))
        #expect(a.outlook == nil)
        #expect(a.reasons.contains(reason("Aged 24 with little room to grow", 20)))
        // At 23 his reach line already says it.
        let young = target(age: 23, currentAbility: 90, potentialAbility: 98)
        let b = try advice(young, in: try averaging100(young))
        #expect(b.outlook != nil)
        #expect(reasons(b.reasons, "Aged").isEmpty)
    }

    @Test func noYoungPlayerHasARoomToGrowLine() throws {
        // The old prospect lines: every one of these took points off for room to grow.
        for (age, potential) in [(19, 134), (19, 130), (19, 129), (19, 115), (21, 134), (19, 114), (22, 134)] {
            let a = try advice(target(age: age, potentialAbility: potential))
            #expect(reasons(a.reasons, "Aged").isEmpty, "\(age) \(potential)")
            #expect(a.outlook != nil, "\(age) \(potential)")
        }
    }

    @Test func aMentorTakesPointsOff() throws {
        let mentor = try advice(target(age: 30, attributes: [.professionalism: 16, .determination: 15]))
        #expect(mentor.reasons.contains(reason("A model professional for younger players", -40)))
        #expect(mentor.isMentor)
        let lesser = try advice(target(age: 30, attributes: [.professionalism: 16, .determination: 14]))
        #expect(lesser.reasons.contains(reason("A model professional for younger players", -20)))
        #expect(lesser.isMentor)
        for t in [target(age: 30, attributes: [.professionalism: 15, .determination: 15]),
                  target(age: 29, attributes: [.professionalism: 16, .determination: 15])] {
            let a = try advice(t)
            #expect(reasons(a.reasons, "A model").isEmpty)
            #expect(!a.isMentor)
        }
    }

    @Test func aPlayerOfThirtyWithNoRoomToGrowAddsTen() throws {
        #expect(reasons(try advice(target(age: 30, potentialAbility: 104)).reasons, "Aged")
                == [reason("Aged 30 with no room to grow", 10)])
        #expect(reasons(try advice(target(age: 31, potentialAbility: 104)).reasons, "Aged")
                == [reason("Aged 31 with no room to grow", 10)])
        #expect(reasons(try advice(target(age: 31, potentialAbility: 105)).reasons, "Aged").isEmpty)
        #expect(reasons(try advice(target(age: 29, potentialAbility: 104)).reasons, "Aged").isEmpty)
        let mentor = try advice(target(age: 31, attributes: [.professionalism: 16, .determination: 15], potentialAbility: 104))
        #expect(reasons(mentor.reasons, "Aged").isEmpty)
    }

    @Test func aPlayerOfThirtyTwoAddsFive() throws {
        #expect(reasons(try advice(target(age: 32)).reasons, "Aged") == [reason("Aged 32", 5)])
        #expect(reasons(try advice(target(age: 33)).reasons, "Aged") == [reason("Aged 33", 5)])
        #expect(reasons(try advice(target(age: 31)).reasons, "Aged").isEmpty)
        let mentor = try advice(target(age: 33, attributes: [.professionalism: 16, .determination: 15]))
        #expect(reasons(mentor.reasons, "Aged").isEmpty)
    }

    @Test func reasonsComeInTheOrderOfTheTable() throws {
        let t = target(age: 33, attributes: [.consistency: 7, .temperament: 7], potentialAbility: 100) {
            $0.contractType = .outOfContract; $0.monthsLeft = 3; $0.wagePerWeek = 900
        }
        let a = try advice(t)
        #expect(a.reasons == [
            reason("Not on a full-time contract", 50),
            reason("In neither eleven", 15),
            reason(weakest, 30),
            reason("Paid £900 a week, against a median of £500, and in neither eleven", 35),
            reason("Contract ends in 3 months", 25),
            reason("Consistency 7", 25),
            reason("Temperament 7", 15),
            reason("Aged 33 with no room to grow", 10),
            reason("Aged 33", 5),
        ])
    }

    // MARK: Young players

    @Test func aYoungPlayerIsScoredOnOneLineFromHisReach() throws {
        // At left back, behind "D L first" and "D L second". At his ability today he is markedly lower there.
        let probe = youngster(potentialAbility: 80)
        let (his, first, second) = try ratings(of: probe.id, at: .D_L, in: try squad([probe]))
        try #require(his < 0.8 * first)
        let passing = potential(reaching: first, his: his)
        let making = potential(reaching: second, his: his)
        let cover = potential(reaching: 0.8 * first, his: his)
        try #require(reachRating(his: his, potential: cover) < second && reachRating(his: his, potential: making) < first
                     && passing <= 80 + 136)
        let cases: [(potential: Int, line: RemovalReason, level: ReachLevel)] = [
            (passing, reason("Could pass D_L first at left back", -40), .couldPassFirst),
            (making, reason("Could make the second eleven at left back", -20), .couldMakeSecond),
            (cover, reason("Could become cover at left back, no more", 15), .couldBeCover),
            (80, reason("Not expected to reach the level of the squad at any position", 70), .markedlyLower),
        ]
        for (potential, line, level) in cases {
            let a = try advice(youngster(potentialAbility: potential))
            try #require(a.tier == .backup)
            #expect(a.outlook?.level == level, "\(potential)")
            #expect(a.outlook?.best?.slot == .D_L, "\(potential)")
            // Months left unknown, every rated attribute 10, the median wage: nothing else applies, and neither the
            // elevens line, the weakest's nor the ability line is added.
            #expect(a.reasons == [line], "\(potential)")
            #expect(a.score == line.points, "\(potential)")
        }
        // The same player at 24 has no outlook and takes all three lines.
        let older = try advice(youngster(age: 24, potentialAbility: 120))
        #expect(older.outlook == nil && older.matchesHere == nil)
        #expect(older.reasons == [reason("In neither eleven", 15), reason(weakest, 30),
                                  reason("Current ability 80 against a squad average of 99", 25)])
    }

    @Test func aYoungPlayerHasHisMatchesHereFromTheConfirmedLineups() throws {
        let young = youngster(potentialAbility: 120)
        let days = ["2026-10-01", "2026-10-08", "2026-10-15", "2026-10-22", "2026-10-29", "2026-11-05"]
        let history = days.enumerated().map { index, day in
            ConfirmedLineup(fixture: FixtureID("f\(index)"), date: Day(iso: day)!, starters: index < 2 ? [.D_L: young.id] : [:])
        }
        let a = try #require(try report(try squad([young]), history: history).advice.first { $0.player == young.id })
        #expect(a.matchesHere == MatchesHere(starts: 2, matches: 6, isCounted: true, isEnough: true))
        // With none confirmed, a backup is not counted and has not enough.
        let b = try advice(young)
        #expect(b.matchesHere == MatchesHere(starts: 0, matches: 0, isCounted: false, isEnough: false))
    }

    @Test func aSlotHeIsRetrainingForCountsInHisReach() throws {
        // Familiarity 9 at left back: not a slot he can play until he is retraining there.
        let young = youngster(familiarity: 9, potentialAbility: 80)
        let without = try advice(young)
        #expect(without.outlook?.best == nil)
        #expect(without.reasons.first?.text.hasSuffix("the first team") == true)
        let retraining = [Retraining(player: young.id, position: assignment(.D_L).ipPosition, acceptedOn: asOf)]
        let with = try #require(try report(try squad([young]), retraining: retraining).advice.first { $0.player == young.id })
        #expect(with.outlook?.best?.slot == .D_L)
        #expect(with.reasons.first?.text.hasSuffix("at any position") == true)
    }

    @Test func anInjuredYoungPlayerIsScoredAsWhenFit() throws {
        let probe = youngster(potentialAbility: 80)
        let (his, _, second) = try ratings(of: probe.id, at: .D_L, in: try squad([probe]))
        let fit = try advice(youngster(potentialAbility: potential(reaching: second, his: his)))
        let injured = try advice(youngster(potentialAbility: potential(reaching: second, his: his)) { $0.isInjured = true })
        #expect(fit.reasons == [reason("Could make the second eleven at left back", -20)])
        #expect(injured.reasons == fit.reasons && injured.score == fit.score)
        #expect(injured.outlook == fit.outlook)
    }

    @Test func theBetterOfHisPlaceAndHisReachIsUsed() throws {
        let firstID = PlannerFixture.id(.D_L, "first"), secondID = PlannerFixture.id(.D_L, "second")
        let (r2, r1, _) = try ratings(of: secondID, at: .D_L, in: try squad())
        // In the second eleven, aged 19, with a reach past the first choice's: the reach line, −40, in its place.
        let passing = potential(reaching: r1, his: r2, current: 100)
        let rising = try advice(secondID, in: try squad(changing: secondID) { $0.age = 19; $0.potentialAbility = passing })
        #expect(rising.tier == .second(.D_L))
        #expect(rising.outlook?.level == .couldPassFirst)
        #expect(rising.reasons.first == reason("Could pass D_L first at left back", -40))
        #expect(reasons(rising.reasons, "In the").isEmpty)
        // With no growth his reach makes the second eleven, as his place does: on the tie, the elevens line.
        let level = try advice(secondID, in: try squad(changing: secondID) { $0.age = 19; $0.potentialAbility = 100 })
        #expect(level.outlook?.level == .couldMakeSecond)
        #expect(level.reasons.first == reason("In the second eleven at left back", -20))
        #expect(reasons(level.reasons, "Could").isEmpty)
        // In the first eleven at his only slot: no level to compare, and the elevens line.
        let first = try advice(firstID, in: try squad(changing: firstID) { $0.age = 19; $0.potentialAbility = 200 })
        #expect(first.tier == .first(.D_L) && first.outlook != nil && first.outlook?.level == nil)
        #expect(first.reasons.first == reason("In the first eleven at left back", -40))
        // In the first eleven and markedly lower at the other slot he can play: the elevens line, the fewer points.
        let other = assignment(.AM_L)
        let elsewhere = try advice(firstID, in: try squad(changing: firstID) { p in
            p.age = 19; p.potentialAbility = 100
            p.familiarity[other.ipPosition] = 10; p.familiarity[other.oopPosition] = 10
        })
        #expect(elsewhere.tier == .first(.D_L))
        #expect(elsewhere.outlook?.best?.slot == .AM_L)
        #expect(elsewhere.outlook?.level != .couldPassFirst)
        #expect(elsewhere.reasons.first == reason("In the first eleven at left back", -40))
        #expect(reasons(elsewhere.reasons, "Could").isEmpty && reasons(elsewhere.reasons, "Not expected").isEmpty)
    }

    @Test func professionalismAndAmbitionDoNotCountAgainstAYoungPlayerAndStillDoAtTwentyFour() throws {
        for age in [19, 23] {
            let young = try advice(target(age: age, attributes: [.professionalism: 7, .ambition: 5]))
            #expect(young.outlook != nil)
            #expect(reasons(young.reasons, "Professionalism").isEmpty, "\(age)")
            #expect(reasons(young.reasons, "Ambition").isEmpty, "\(age)")
        }
        let older = try advice(target(age: 24, attributes: [.professionalism: 7, .ambition: 5]))
        #expect(reasons(older.reasons, "Professionalism") == [reason("Professionalism 7", 25)])
        #expect(reasons(older.reasons, "Ambition") == [reason("Ambition 5", 25)])
    }

    @Test func aShortContractOnAPlayerWorthKeepingSaysRenewIt() throws {
        // With no slot he can play, a reach of 120 against a first-team average of 100: −20.
        let cases: [(Int?, RemovalReason?)] = [
            (1, reason("Contract ends in 1 month: renew it", 0)),
            (5, reason("Contract ends in 5 months: renew it", 0)),
            (12, reason("Contract ends in 12 months: renew it", 0)),
            (13, nil), (nil, nil),
        ]
        for (months, expected) in cases {
            let a = try advice(target(age: 19) { $0.monthsLeft = months })
            #expect(a.reasons.first == reason("Could reach the level of the first team", -20))
            #expect(reasons(a.reasons, "Contract") == (expected.map { [$0] } ?? []), "\(String(describing: months))")
        }
        // In the first eleven, the elevens line's −40: renew it too.
        let id = PlannerFixture.id(.D_L, "first")
        let first = try advice(id, in: try squad(changing: id) { $0.age = 19; $0.monthsLeft = 5 })
        #expect(reasons(first.reasons, "Contract") == [reason("Contract ends in 5 months: renew it", 0)])
        // A reach of 90 against an average of about 99: +15, and the contract's points as today.
        let close = try advice(target(age: 19, currentAbility: 80, potentialAbility: 90) { $0.monthsLeft = 5 })
        #expect(close.reasons.first == reason("Could come close to the level of the first team, no more", 15))
        #expect(reasons(close.reasons, "Contract") == [reason("Contract ends in 5 months", 25)])
        // Markedly lower: the points as today.
        let lower = try advice(target(age: 19, currentAbility: 50, potentialAbility: 50) { $0.monthsLeft = 9 })
        #expect(lower.reasons.first == reason("Not expected to reach the level of the first team", 70))
        #expect(reasons(lower.reasons, "Contract") == [reason("Contract ends in 9 months", 15)])
    }

    /// The planner's squad with its second-choice left back below solid (familiarity 14), plus a young left back,
    /// solid (familiarity 20) and markedly lower, rated below him so he stays out of both elevens. The young player's
    /// Consistency, Important Matches and Temperament are 10, so no rule reads them.
    func needed(_ secondFamiliarity: Int) throws -> (players: [Player], young: Player) {
        let young = youngster(all: 6, familiarity: 20, potentialAbility: 80) { p in
            for attribute in [Attribute.consistency, .importantMatches, .temperament] { p.attributes[attribute] = 10 }
        }
        let second = PlannerFixture.id(.D_L, "second")
        let players = try squad(changing: second) { p in
            p.familiarity[assignment(.D_L).ipPosition] = secondFamiliarity
            p.familiarity[assignment(.D_L).oopPosition] = secondFamiliarity
        } + [young]
        return (players, young)
    }

    @Test func aMarkedlyLowerPlayerNeededForDepthIsWatched() throws {
        let (players, young) = try needed(14)
        try #require(try depth(players, .D_L).cover == parameters.depthThinBelow.value)
        let a = try advice(young.id, in: players)
        try #require(a.tier == .backup)
        #expect(a.outlook?.level == .markedlyLower)
        #expect(a.reasons == [reason("Not expected to reach the level of the squad at any position", 70),
                              reason("Cover at left back would be thin without him", -30)])
        #expect(a.score == 40 && a.level == .medium && a.action == .monitor)
    }

    @Test func oneNotNeededScoresSeventy() throws {
        let (players, young) = try needed(20)
        try #require(try depth(players, .D_L).cover == parameters.depthThinBelow.value + 1)
        let r = try report(players)
        let a = try #require(r.advice.first { $0.player == young.id })
        try #require(a.tier == .backup)
        #expect(a.reasons == [reason("Not expected to reach the level of the squad at any position", 70)])
        #expect(a.score == 70 && a.level == .high && a.action == .sell)
        #expect(r.advisedToLeave.contains(young.id))
    }

    @Test func aPlayerWithAbilityZeroIsScoredAsAnOlderPlayer() throws {
        let young = try advice(target(age: 19, attributes: [.professionalism: 7], currentAbility: 0, potentialAbility: 100))
        let older = try advice(target(age: 24, attributes: [.professionalism: 7], currentAbility: 0, potentialAbility: 100))
        #expect(young.outlook == nil && young.matchesHere == nil)
        #expect(young.reasons == older.reasons)
        #expect(young.reasons.prefix(3) == [reason("In neither eleven", 15), reason(weakest, 30),
                                            reason("Current ability 0 against a squad average of 96", 25)])
        #expect(young.reasons.contains(reason("Professionalism 7", 25)))
    }

    @Test func aSquadSmallerThanTheTacticStillScoresItsYoungPlayers() throws {
        let firsts = try PlannerFixture.squad().filter { $0.name.hasSuffix("first") }
        // The first eleven and one young left back: no second choice anywhere but where he plays.
        let young = youngster(all: 12, familiarity: 20, potentialAbility: 200)
        let r = try report(firsts + [young])
        let a = try #require(r.advice.first { $0.player == young.id })
        #expect(a.tier == .second(.D_L))
        #expect(a.outlook?.level == .couldPassFirst)
        #expect(a.reasons.first == reason("Could pass D_L first at left back", -40))
        // Without a striker, a young striker is the only one able to play there: first choice, no level, the elevens line.
        let striker = youngster("Striker", all: 12, familiarity: 20, slot: .ST_C, potentialAbility: 200)
        let short = firsts.filter { $0.name != named(.ST_C, "first") } + [striker]
        let s = try #require(try report(short).advice.first { $0.player == striker.id })
        #expect(s.tier == .first(.ST_C))
        #expect(s.outlook != nil && s.outlook?.level == nil)
        #expect(s.reasons.first == reason("In the first eleven at striker", -40))
        // Four players, all U21: no first-team average, and a young player with no slot is "could become cover".
        let few = (firsts.prefix(3) + [target(age: 19)]).map { p -> Player in var p = p; p.squad = .u21; return p }
        let f = try report(Array(few))
        #expect(f.squadAverageAbility == nil)
        let spare = try #require(f.advice.first { $0.player == target().id })
        #expect(spare.outlook?.level == .couldBeCover && spare.outlook?.average == nil)
        #expect(!spare.reasons.contains { $0.text == weakest || $0.text.hasPrefix("Current ability") })
    }

    // MARK: Scores and levels

    @Test func scoresAddUpAndSetTheLevel() throws {
        // With no months left known the target scores "in neither eleven" and the weakest's 30.
        let t = target { $0.monthsLeft = nil }
        for (score, level) in [(80, RemovalLevel.critical), (79, .high), (50, .high), (49, .medium), (30, .medium), (29, .keep)] {
            var q = parameters
            var rules = q.removalRules.value
            rules.neitherElevenPoints = score - 30
            q.removalRules = Parameter(rules, .carriedOverFM26, source: "test")
            let a = try advice(t, parameters: q)
            #expect(a.score == score)
            #expect(a.score == a.reasons.map(\.points).reduce(0, +))
            #expect(a.level == level, "\(score)")
        }
    }

    // MARK: Actions

    @Test func aPlayerOutOfContractAtHighIsReleasedAtNoCost() throws {
        // A centre-back, where cover is above the line, so the thin-cover rule does not apply.
        let id = PlannerFixture.id(.D_CL, "first")
        // −40 in the first eleven, +50, +15 for 12 months, +25 for Controversy 17.
        let a = try advice(id, in: try squad(changing: id) { p in
            p.contractType = .outOfContract; p.attributes[.controversy] = 17
        })
        #expect(a.score == 50 && a.level == .high)
        #expect(a.action == .release)
        #expect(a.releaseCost == 0 && a.mutualCost == 0)
    }

    @Test func aYoungPlayerAtHighOrCriticalIsSoldOrTerminatedLikeAnyOther() throws {
        // Markedly lower, with no slot he can play: +70, and nothing else with months left unknown. High, and sold.
        let high = try advice(target(age: 19, currentAbility: 50, potentialAbility: 50) { $0.monthsLeft = nil })
        #expect(high.score == 70 && high.level == .high)
        #expect(high.action == .sell)
        // +15 for 8 months as well: critical, and with no buyer terminated.
        let critical = try advice(target(age: 19, currentAbility: 50, potentialAbility: 50) { $0.monthsLeft = 8 })
        #expect(critical.score == 85 && critical.level == .critical)
        #expect(critical.action == .terminate)
    }

    @Test func aFalseProspectAtHighIsSold() throws {
        // 120 points in 4 years with Professionalism 11, and a reach of about 76 against a first-team average of
        // about 97: markedly lower, +70.
        let a = try advice(target(age: 20, attributes: [.professionalism: 11], currentAbility: 30, potentialAbility: 150) {
            $0.monthsLeft = nil
        })
        #expect(a.isFalseProspect)
        #expect(a.score == 70 && a.level == .high)
        #expect(a.action == .sell)
    }

    @Test func aCriticalPlayerWithAShortContractAndNoBuyerIsTerminated() throws {
        // 15 + 30 + 15 for 8 months + 25 for Controversy 17. Release £18,417, mutual £10,129.
        func critical(asking: Int?) -> Player {
            target(attributes: [.controversy: 17]) { $0.monthsLeft = 8; $0.askingPrice = asking }
        }
        let a = try advice(critical(asking: nil))
        #expect(a.score == 85 && a.level == .critical)
        #expect(a.releaseCost == 18_417 && a.mutualCost == 10_129)
        #expect(a.action == .terminate)
        #expect(try advice(critical(asking: 10_128)).action == .terminate)
        #expect(try advice(critical(asking: 10_129)).action == .sell)
        #expect(try advice(critical(asking: 10_130)).action == .sell)
        // 12 months left: 15 + 30 + 15 + 25. 13 months: 15 + 30 + 25 + 15 for Temperament 7.
        let twelve = try advice(target(attributes: [.controversy: 17]) { $0.monthsLeft = 12 })
        #expect(twelve.level == .critical && twelve.action == .terminate)
        let thirteen = try advice(target(attributes: [.controversy: 17, .temperament: 7]) { $0.monthsLeft = 13 })
        #expect(thirteen.level == .critical && thirteen.action == .sell)
    }

    @Test func otherwiseAHighOrCriticalPlayerIsSold() throws {
        // Critical with 30 months left: 15 + 30 + 25 + 15.
        let long = try advice(target(attributes: [.controversy: 17, .temperament: 7]) { $0.monthsLeft = 30 })
        #expect(long.level == .critical && long.action == .sell)
        // High with 30 months left: 15 + 30 + 25.
        let high = try advice(target(attributes: [.controversy: 17]) { $0.monthsLeft = 30 })
        #expect(high.score == 70 && high.level == .high && high.action == .sell)
        // High with 8 months left: only a critical player is terminated.
        let short = try advice(target { $0.monthsLeft = 8 })
        #expect(short.score == 60 && short.level == .high && short.action == .sell)
    }

    @Test func mediumIsMonitoredAndKeepIsKept() throws {
        let medium = try advice(target { $0.monthsLeft = nil })
        #expect(medium.score == 45 && medium.level == .medium && medium.action == .monitor)
        let id = PlannerFixture.id(.D_CL, "first")
        let keep = try advice(id, in: try squad(changing: id) { $0.monthsLeft = nil })
        #expect(keep.score == -40 && keep.level == .keep && keep.action == .keep)
    }

    @Test func costsFollowTheWageAndMonthsLeft() throws {
        let a = try advice(target { $0.wagePerWeek = 1_200; $0.monthsLeft = 10 })
        #expect(a.releaseCost == 54_600)
        #expect(a.mutualCost == 30_030)
        let unknown = try advice(target { $0.monthsLeft = nil })
        #expect(unknown.releaseCost == nil && unknown.mutualCost == nil)
    }

    // MARK: Edge cases

    @Test func aCurrentAbilityOfZeroGivesNoRoomToGrowRule() throws {
        let young = try advice(target(age: 19, currentAbility: 0, potentialAbility: 100))
        #expect(reasons(young.reasons, "Aged").isEmpty)
        // The growth a false prospect needs does not divide by his ability: 100 points in 5 years.
        #expect(young.isFalseProspect)
        for age in [23, 31] {
            #expect(reasons(try advice(target(age: age, currentAbility: 0, potentialAbility: 0)).reasons, "Aged").isEmpty)
        }
    }

    @Test func aPotentialBelowCurrentAbilityIsNoRoomToGrow() throws {
        let young = try advice(target(age: 19, currentAbility: 100, potentialAbility: 90))
        #expect(reasons(young.reasons, "Aged").isEmpty)
        #expect(!young.isFalseProspect)
        #expect(reasons(try advice(target(age: 31, currentAbility: 100, potentialAbility: 90)).reasons, "Aged")
                == [reason("Aged 31 with no room to grow", 10)])
    }

    @Test func aTwentyFourYearOldWithALargeGapIsNotAFalseProspect() throws {
        let a = try advice(target(age: 24, attributes: [.professionalism: 5], currentAbility: 60, potentialAbility: 180))
        #expect(reasons(a.reasons, "Would need").isEmpty)
        #expect(!a.isFalseProspect)
    }

    @Test func aMedianWageOfZeroAppliesNoWageRule() throws {
        let players = try squad([target { $0.wagePerWeek = 100 }]).map { p -> Player in
            var p = p; if p.id != target().id { p.wagePerWeek = 0 }; return p
        }
        #expect(reasons(try advice(target(), in: players).reasons, "Paid").isEmpty)
        let allZero = players.map { p -> Player in var p = p; p.wagePerWeek = 0; return p }
        #expect(reasons(try advice(target(), in: allZero).reasons, "Paid").isEmpty)
    }

    @Test func theSquadAverageAndMedianLeaveOutLoanedInPlayers() throws {
        // Own: the first eleven at £400 and the target at £700 (median £400). The second eleven is on loan here at
        // £10,000 and current ability 10; counted, they would move the median to £700 and the average to about 57.
        let players = try squad([target { $0.wagePerWeek = 700 }]).map { p -> Player in
            var p = p
            if p.name.hasSuffix("first") { p.wagePerWeek = 400 }
            if p.name.hasSuffix("second") {
                p.club = "Other FC"; p.loanedTo = "Oxford City"; p.wagePerWeek = 10_000; p.currentAbility = 10
            }
            return p
        }
        let r = try report(players)
        #expect(r.squadAverageAbility == 100)
        #expect(r.advice.count == 12 && r.loans.count == 11)
        let a = try #require(r.advice.first { $0.player == target().id })
        #expect(reasons(a.reasons, "Paid") == [reason("Paid £700 a week, against a median of £400, and in neither eleven", 35)])
        #expect(reasons(a.reasons, "Current ability").isEmpty)
    }

    /// Thirty U21 players of current ability 40 on £50 a week.
    var youthSquad: [Player] {
        (0..<30).map { i in
            var p = Player.fixture(name: "Youth \(i)", squad: .u21, currentAbility: 40)
            p.wagePerWeek = 50
            return p
        }
    }

    @Test func theMedianWageAndAverageAreTheFirstTeams() throws {
        // Over all 53 own players the median would be £50 and the average about 66.
        let players = try squad([target(), target("Weaker", currentAbility: 90, potentialAbility: 200)]) + youthSquad
        let r = try report(players)
        let average = try #require(r.squadAverageAbility)
        let firstTeamAverage = Double(23 * 100 + 90) / 24
        #expect(abs(average - firstTeamAverage) < 1e-9)
        // The target is paid the first team's median, £500: no wage points.
        let a = try #require(r.advice.first { $0.player == target().id })
        #expect(reasons(a.reasons, "Paid").isEmpty)
        // A first-team player below the first team's average is below the squad average.
        let weaker = try #require(r.advice.first { $0.name == "Weaker" })
        #expect(reasons(weaker.reasons, "Current ability") == [reason("Current ability 90 against a squad average of 100", 10)])
        // Above the first team's median, the wage rule still applies.
        let paid = try #require(try report(try squad([target { $0.wagePerWeek = 900 }]) + youthSquad)
            .advice.first { $0.player == target().id })
        #expect(reasons(paid.reasons, "Paid") == [reason("Paid £900 a week, against a median of £500, and in neither eleven", 35)])
    }

    @Test func withNoFirstTeamPlayerNeitherWageNorAverageApplies() throws {
        let players = (try squad([target { $0.wagePerWeek = 900 }]) + youthSquad).map { p -> Player in
            var p = p; p.squad = .u21; return p
        }
        let r = try report(players)
        #expect(r.squadAverageAbility == nil)
        #expect(r.advice.count == 53)
        for a in r.advice {
            #expect(reasons(a.reasons, "Paid").isEmpty, "\(a.name)")
            #expect(reasons(a.reasons, "Current ability").isEmpty, "\(a.name)")
            #expect(!a.reasons.contains { $0.text.hasSuffix("little room to grow") }, "\(a.name)")
        }
    }

    @Test func aHighWageInTheSecondElevenAddsNothing() throws {
        let id = PlannerFixture.id(.D_L, "second")
        let a = try advice(id, in: try squad(changing: id) { $0.wagePerWeek = 2_000 })
        #expect(a.tier == .second(.D_L))
        #expect(reasons(a.reasons, "Paid").isEmpty)
    }

    @Test func noOwnPlayersMeansNoAverage() throws {
        let players = try squad().map { p -> Player in var p = p; p.club = "Other FC"; p.loanedTo = "Oxford City"; return p }
        let r = try report(players + [loanee(currentAbility: 10)])
        #expect(r.squadAverageAbility == nil)
        #expect(r.advice.isEmpty)
        let review = try #require(r.loans.first { $0.player == loanee().id })
        #expect(reasons(review.reasons, "Current ability").isEmpty)
    }

    // MARK: Basis

    @Test func theBasisIsDerivedOnlyWhenAWageRuleContributed() throws {
        #expect(try advice(target { $0.wagePerWeek = 900 }).basis == .derived)
        #expect(try advice(target()).basis == .carriedOverFM26)
        #expect(try review(loanee { $0.wagePerWeek = 900 }).basis == .carriedOverFM26)
    }

    // MARK: Loan review

    @Test func theLoanReviewScoresTheWeakestAndTheElevens() throws {
        let plain = try review(loanee())
        #expect(plain.reasons == [reason(weakest, 30), reason("In neither eleven", 20)])
        #expect(plain.score == 50)
        // Centre-backs, where cover is above the line, so the thin-cover rule does not apply.
        let first = PlannerFixture.id(.D_CL, "first")
        let firstReview = try #require(try report(try squad(changing: first) { p in
            p.club = "Other FC"; p.loanedTo = "Oxford City"
        }).loans.first)
        #expect(firstReview.player == first)
        #expect(firstReview.reasons == [reason("In the first eleven at centre-back", -30)])
        let second = PlannerFixture.id(.D_CL, "second")
        let secondReview = try #require(try report(try squad(changing: second) { p in
            p.club = "Other FC"; p.loanedTo = "Oxford City"
        }).loans.first)
        #expect(reasons(secondReview.reasons, "In") == [reason("In the second eleven at centre-back", -15)])
    }

    @Test func theLoanReviewScoresAbility() throws {
        // The loanee does not count in the average, which stays 100.
        let cases: [(Int, RemovalReason?)] = [
            (84, reason("Current ability 84 against a squad average of 100", 25)),
            (85, reason("Current ability 85 against a squad average of 100", 10)),
            (99, reason("Current ability 99 against a squad average of 100", 10)),
            (100, nil),
        ]
        for (ability, expected) in cases {
            #expect(reasons(try review(loanee(currentAbility: ability)).reasons, "Current ability")
                    == (expected.map { [$0] } ?? []), "\(ability)")
        }
    }

    @Test func theLoanReviewScoresConsistencyImportantMatchesAndInjuryProneness() throws {
        func found(_ attribute: Attribute, _ value: Int) throws -> [RemovalReason] {
            reasons(try review(loanee(attributes: [attribute: value])).reasons, attribute.rawValue)
        }
        #expect(try found(.consistency, 7) == [reason("Consistency 7", 20)])
        #expect(try found(.consistency, 8).isEmpty)
        #expect(try found(.importantMatches, 7) == [reason("Important Matches 7", 15)])
        #expect(try found(.importantMatches, 8).isEmpty)
        #expect(try found(.injuryProneness, 15) == [reason("Injury Proneness 15", 25)])
        #expect(try found(.injuryProneness, 14).isEmpty)
        // The rules for own players that the review does not have.
        let others = try review(loanee(attributes: [.professionalism: 5, .controversy: 20]) { $0.monthsLeft = 2; $0.wagePerWeek = 5_000 })
        #expect(others.reasons == [reason(weakest, 30), reason("In neither eleven", 20)])
    }

    @Test func theLoanVerdictFollowsTheScore() throws {
        // The loanee scores the weakest's 30 plus the points for being in neither eleven.
        for (score, verdict) in [(50, LoanVerdict.endEarly), (49, .doNotExtend), (25, .doNotExtend), (24, .keepToEnd)] {
            var q = parameters
            var rules = q.removalRules.value
            rules.loanReview.neitherElevenPoints = score - 30
            q.removalRules = Parameter(rules, .carriedOverFM26, source: "test")
            let r = try review(loanee(), parameters: q)
            #expect(r.score == score)
            #expect(r.verdict == verdict, "\(score)")
        }
    }

    @Test func aLoaneeInAnElevenAtTheAverageIsWorthMakingPermanent() throws {
        func onLoan(_ id: PlayerID, ability: Int) throws -> LoanReview {
            try #require(try report(try squad(changing: id) { p in
                p.club = "Other FC"; p.loanedTo = "Oxford City"; p.currentAbility = ability
            }).loans.first)
        }
        // Centre-backs, where cover is above the line, so the thin-cover rule does not apply.
        #expect(try onLoan(PlannerFixture.id(.D_CL, "first"), ability: 100).verdict == .makePermanent)
        #expect(try onLoan(PlannerFixture.id(.D_CL, "second"), ability: 100).verdict == .makePermanent)
        // Below the average he is kept to the end.
        let below = try onLoan(PlannerFixture.id(.D_CL, "first"), ability: 99)
        #expect(below.score == -20 && below.verdict == .keepToEnd)
    }

    // MARK: Who is assessed

    @Test func playersOutOnLoanAreNotAssessed() throws {
        var away = target("Away", currentAbility: 0) { $0.loanedTo = "Other FC" }
        away.attributes[.consistency] = nil
        let r = try report(try squad([away]))
        #expect(!r.advice.contains { $0.player == away.id })
        #expect(r.loans.isEmpty)
        #expect(r.advice.count == 22)
        #expect(r.squadAverageAbility == 100)
    }

    @Test func anInjuredFirstChoiceKeepsHisTier() throws {
        let id = PlannerFixture.id(.D_L, "first")
        let a = try advice(id, in: try squad(changing: id) { $0.isInjured = true })
        #expect(a.tier == .first(.D_L))
        #expect(a.reasons.first == reason("In the first eleven at left back", -40))
    }

    // MARK: The report

    @Test func theReportOrdersByScoreAndAddsUpTheWagesAtStake() throws {
        // Alpha: 15 + 30 + 15 + 35 for £1,000 = 95, critical. Bravo: 15 + 30 + 20 for £700 = 65, high.
        // Charlie: 15 + 30 = 45, medium.
        let players = try squad([
            target("Alpha") { $0.wagePerWeek = 1_000 },
            target("Bravo") { $0.wagePerWeek = 700; $0.monthsLeft = nil },
            target("Charlie") { $0.wagePerWeek = 300; $0.monthsLeft = nil },
        ])
        let r = try report(players)
        #expect(r.advice.prefix(3).map(\.name) == ["Alpha", "Bravo", "Charlie"])
        #expect(r.advice.prefix(3).map(\.level) == [.critical, .high, .medium])
        #expect(r.advice.prefix(3).map(\.score) == [95, 65, 45])
        for (a, b) in zip(r.advice, r.advice.dropFirst()) {
            #expect(a.score > b.score || (a.score == b.score && a.player.key < b.player.key))
        }
        #expect(r.weeklyWagesAtStake == 1_700)
        #expect(r.advice.count == 25)
    }

    @Test func thePlayersAdvisedToLeaveAreTheCriticalAndHighOnes() throws {
        // Alpha critical (terminate), Bravo high (sell), Charlie medium, Delta a young player markedly lower and high
        // (sell), Echo critical and out of contract (release), Foxtrot a young player who could make the second eleven
        // (keep); everyone else keep.
        let players = try squad([
            target("Alpha") { $0.wagePerWeek = 1_000 },
            target("Bravo") { $0.wagePerWeek = 700; $0.monthsLeft = nil },
            target("Charlie") { $0.wagePerWeek = 300; $0.monthsLeft = nil },
            target("Delta", age: 19, currentAbility: 50, potentialAbility: 50) { $0.monthsLeft = nil },
            target("Echo") { $0.contractType = .outOfContract },
            target("Foxtrot", age: 19, potentialAbility: 134),
        ])
        let r = try report(players)
        let byName = Dictionary(uniqueKeysWithValues: r.advice.map { ($0.name, $0) })
        #expect(byName["Alpha"]?.action == .terminate && byName["Bravo"]?.action == .sell)
        #expect(byName["Delta"]?.level == .high && byName["Delta"]?.action == .sell)
        #expect(byName["Echo"]?.action == .release)
        #expect(byName["Charlie"]?.level == .medium)
        #expect(byName["Foxtrot"]?.level == .keep)
        #expect(r.advisedToLeave == Set(["Alpha", "Bravo", "Delta", "Echo"].map { target($0).id }))
        #expect(r.advice.filter { $0.level == .keep || $0.level == .medium }.allSatisfy { !r.advisedToLeave.contains($0.player) })
        // Nobody to move on: an empty set.
        #expect(try report(try squad()).advisedToLeave.isEmpty)
    }

    @Test func loansAreOrderedByScore() throws {
        let r = try report(try squad([loanee("Loan A"), loanee("Loan B", attributes: [.consistency: 7]), loanee("Loan C")]))
        #expect(r.loans.map(\.name) == ["Loan B", "Loan A", "Loan C"])
    }

    @Test func inputOrderDoesNotMatter() throws {
        let players = try squad([
            target("Alpha") { $0.wagePerWeek = 1_000 },
            target("Bravo", age: 19, potentialAbility: 140),
            target("Charlie", age: 33, attributes: [.professionalism: 17, .determination: 16]),
            loanee("Loan A"), loanee("Loan B", attributes: [.injuryProneness: 18]),
            youngster("Delta", potentialAbility: 130), youngster("Echo", potentialAbility: 110),
        ])
        let forward = try report(players)
        #expect(forward.advice.filter { $0.outlook != nil }.count == 3)
        #expect(forward.advice.contains { $0.outlook?.best != nil })
        #expect(try report(players.reversed()) == forward)
        #expect(try report(Array(players[9...] + players[..<9])) == forward)
    }

    // MARK: Errors

    @Test func aMissingConsistencyIsAnErrorThatNamesThePlayer() throws {
        var t = target()
        t.attributes[.consistency] = nil
        #expect(throws: RatingError.missingAttribute(player: "Target", attribute: .consistency)) { try report(try squad([t])) }
        var l = loanee()
        l.attributes[.consistency] = nil
        #expect(throws: RatingError.missingAttribute(player: "Loanee", attribute: .consistency)) { try report(try squad([l])) }
    }

    @Test func everyAttributeARuleReadsIsRequired() throws {
        for attribute in [Attribute.consistency, .importantMatches, .injuryProneness, .professionalism, .ambition,
                          .controversy, .temperament, .determination] {
            var t = target()
            t.attributes[attribute] = nil
            #expect(throws: RatingError.missingAttribute(player: "Target", attribute: attribute)) { try report(try squad([t])) }
        }
    }

    @Test func badParametersAreReportedBeforeAnythingElse() throws {
        var q = parameters
        var rules = q.removalRules.value
        rules.weakestShare = 1.5
        q.removalRules = Parameter(rules, .carriedOverFM26, source: "test")
        #expect(throws: PlanError.badParameters(["removalRules weakestShare is 1.5, not between 0 and 1"])) {
            try report(try squad([target()]), parameters: q)
        }
    }

    // MARK: Money

    @Test func poundsAreWholeWithThousandsSeparators() {
        #expect(Display.money(0, symbol: "£") == "£0")
        #expect(Display.money(999, symbol: "£") == "£999")
        #expect(Display.money(1_000, symbol: "£") == "£1,000")
        #expect(Display.money(1_250, symbol: "£") == "£1,250")
        #expect(Display.money(52_000, symbol: "£") == "£52,000")
        #expect(Display.money(1_234_567, symbol: "£") == "£1,234,567")
        #expect(Display.money(-1_250, symbol: "£") == "-£1,250")
        #expect(Display.wage(perWeek: 1_250, .weeklyPounds) == "£1,250 a week")
    }

    /// Scott Pollock, pasted as $3,497 a month (807 a week) with 9 months left, outside both elevens of the planner's
    /// squad, whose other players are on 700 a week. The game quoted $34,000 to release him.
    func pollock(_ money: MoneyStyle) throws -> (report: RemovalReport, advice: RemovalAdvice) {
        let player = target("Scott Pollock") { $0.wagePerWeek = 807; $0.monthsLeft = 9 }
        let players = try squad([player]).map { p -> Player in
            var p = p; if p.id != player.id { p.wagePerWeek = 700 }; return p
        }
        let r = try report(players, money: money)
        return (r, try #require(r.advice.first { $0.player == player.id }))
    }

    @Test func aMonthlyDollarWageIsCostedPerWeekAndWrittenInDollarsAMonth() throws {
        let dollars = MoneyStyle(symbol: "$", period: .monthly)
        let (r, a) = try pollock(dollars)
        #expect(r.money == dollars)
        // 807 × 52 ÷ 12 × (9 + 0.5) is 33,221.5.
        #expect(a.releaseCost == 33_222 && a.mutualCost == 18_272)
        #expect(AdvisorText.costs(of: a, money: r.money)
                == "Releasing him costs about $33,222; a mutual termination about $18,272")
        #expect(reasons(a.reasons, "Paid")
                == [reason("Paid $3,497 a month, against a median of $3,033, and in neither eleven", 20)])
    }

    @Test func theSamePlayerInWeeklyPoundsReadsAsBefore() throws {
        let (r, a) = try pollock(.weeklyPounds)
        #expect(r.money == .weeklyPounds)
        #expect(a.releaseCost == 33_222 && a.mutualCost == 18_272)
        #expect(AdvisorText.costs(of: a, money: r.money)
                == "Releasing him costs about £33,222; a mutual termination about £18,272")
        #expect(reasons(a.reasons, "Paid") == [reason("Paid £807 a week, against a median of £700, and in neither eleven", 20)])
    }

    @Test func theWagesAtStakeNeedNotBeWhole() throws {
        let leaving = try report(try squad([target { $0.wagePerWeek = 807.5; $0.monthsLeft = nil }]))
        let level = try #require(leaving.advice.first { $0.player == target().id }).level
        #expect(level == .critical || level == .high)
        #expect(leaving.weeklyWagesAtStake == 807.5)
    }
}
