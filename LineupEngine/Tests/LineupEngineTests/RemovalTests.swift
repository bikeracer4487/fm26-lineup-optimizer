import Foundation
import Testing
@testable import LineupEngine

@Suite struct RemovalTests {
    let tactic = try! PlannerFixture.tactic()
    let catalog = try! RoleCatalog.fm27()
    let profile = try! RatingProfile.standard()
    let parameters = EngineParameters.fm27

    func report(_ players: [Player], ownClub: String? = "Oxford City", parameters: EngineParameters? = nil) throws -> RemovalReport {
        try Removal.report(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog, profile: profile,
                           parameters: parameters ?? self.parameters)
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
        let youth = target(attributes: [.controversy: 17]) { $0.contractType = .other("Youth") }
        let a = try advice(youth)
        #expect(a.reasons.first == reason("Contract type Youth is not one this tool reads: no release cost is given", 0))
        #expect(reasons(a.reasons, "Not on").isEmpty)
        #expect(a.score == 85 && a.level == .critical)
        #expect(a.releaseCost == nil && a.mutualCost == nil)
        // Not released by the first step; with the costs unknown he is never terminated, so he is sold.
        #expect(a.action == .sell)
        // A prospect is loaned out.
        let prospect = try advice(target(age: 19, attributes: [.controversy: 17, .temperament: 7], potentialAbility: 134) {
            $0.contractType = .other("Youth")
        })
        #expect(prospect.level == .high && prospect.action == .loan)
        #expect(prospect.releaseCost == nil && prospect.mutualCost == nil)
        // A full-time contract is unchanged: costs from the wage and months left.
        let full = try advice(target(attributes: [.controversy: 17]))
        #expect(full.score == 85 && full.action == .terminate)
        #expect(full.releaseCost == 26_000 && full.mutualCost == 14_300)
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
        let cases: [(Int, RemovalReason?)] = [
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

    @Test func aFalseProspectAddsThirtyFive() throws {
        // 72 points in 4 years is 18 a year.
        let a = try advice(target(age: 20, attributes: [.professionalism: 11], potentialAbility: 172))
        #expect(reasons(a.reasons, "Would need")
                == [reason("Would need 18 ability points a year to reach his potential by 24, with Professionalism 11", 35)])
        #expect(a.isFalseProspect)
        // Just over 15 a year, with Professionalism 13.
        let edge = try advice(target(age: 20, attributes: [.professionalism: 13], potentialAbility: 161))
        #expect(reasons(edge.reasons, "Would need")
                == [reason("Would need 15 ability points a year to reach his potential by 24, with Professionalism 13", 35)])
        // Exactly 15 a year; Professionalism 14; aged 21.
        for t in [target(age: 20, attributes: [.professionalism: 11], potentialAbility: 160),
                  target(age: 20, attributes: [.professionalism: 14], potentialAbility: 172),
                  target(age: 21, attributes: [.professionalism: 11], potentialAbility: 172)] {
            let b = try advice(t)
            #expect(reasons(b.reasons, "Would need").isEmpty, "\(t.age) \(t.potentialAbility)")
            #expect(!b.isFalseProspect)
        }
    }

    @Test func aPlayerOfTwentyThreeOrFourWithLittleRoomAndUnderTheAverageAddsTwenty() throws {
        // Current 90, potential 98: under 9% room. The squad average is 100.
        for age in [23, 24] {
            let t = target(age: age, currentAbility: 90, potentialAbility: 98)
            #expect(reasons(try advice(t, in: try averaging100(t)).reasons, "Aged")
                    == [reason("Aged \(age) with little room to grow", 20)])
        }
        for t in [target(age: 22, currentAbility: 90, potentialAbility: 98),
                  target(age: 25, currentAbility: 90, potentialAbility: 98),
                  target(age: 23, currentAbility: 90, potentialAbility: 99),     // exactly 10%
                  target(age: 23, currentAbility: 100, potentialAbility: 105)] { // at the average
            #expect(reasons(try advice(t, in: try averaging100(t)).reasons, "Aged").isEmpty, "\(t.age) \(t.currentAbility) \(t.potentialAbility)")
        }
    }

    @Test func aProspectTakesPointsOff() throws {
        let cases: [(Int, Int, RemovalReason?)] = [
            (19, 134, reason("Aged 19 with 34% room to grow", -30)),
            (19, 130, reason("Aged 19 with 30% room to grow", -30)),
            (19, 129, reason("Aged 19 with 29% room to grow", -15)),
            (19, 115, reason("Aged 19 with 15% room to grow", -15)),
            (21, 134, reason("Aged 21 with 34% room to grow", -30)),
            (19, 114, nil), (22, 134, nil),
        ]
        for (age, potential, expected) in cases {
            let a = try advice(target(age: age, potentialAbility: potential))
            #expect(reasons(a.reasons, "Aged") == (expected.map { [$0] } ?? []), "\(age) \(potential)")
            #expect(a.isProspect == (expected != nil))
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

    @Test func aProspectAtHighIsLoanedOut() throws {
        // 15 + 30 + 15 for 12 months, −30 as a prospect, +25 for Controversy 17.
        let a = try advice(target(age: 19, attributes: [.controversy: 17], potentialAbility: 134))
        #expect(a.score == 55 && a.level == .high)
        #expect(a.isProspect && !a.isFalseProspect)
        #expect(a.action == .loan)
    }

    @Test func aFalseProspectAtHighIsNotLoanedOut() throws {
        // 15 + 30 + 15, −30 as a prospect, +35 as a false one.
        let a = try advice(target(age: 20, attributes: [.professionalism: 11], potentialAbility: 172))
        #expect(a.score == 65 && a.level == .high)
        #expect(a.isProspect && a.isFalseProspect)
        #expect(a.action == .sell)
    }

    @Test func aCriticalPlayerWithAShortContractAndNoBuyerIsTerminated() throws {
        // 15 + 30 + 15 for 8 months + 25 for Controversy 17. Release £17,333, mutual £9,533.
        func critical(asking: Int?) -> Player {
            target(attributes: [.controversy: 17]) { $0.monthsLeft = 8; $0.askingPrice = asking }
        }
        let a = try advice(critical(asking: nil))
        #expect(a.score == 85 && a.level == .critical)
        #expect(a.releaseCost == 17_333 && a.mutualCost == 9_533)
        #expect(a.action == .terminate)
        #expect(try advice(critical(asking: 9_532)).action == .terminate)
        #expect(try advice(critical(asking: 9_533)).action == .sell)
        #expect(try advice(critical(asking: 9_534)).action == .sell)
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
        #expect(a.releaseCost == 52_000)
        #expect(a.mutualCost == 28_600)
        let unknown = try advice(target { $0.monthsLeft = nil })
        #expect(unknown.releaseCost == nil && unknown.mutualCost == nil)
    }

    // MARK: Edge cases

    @Test func aCurrentAbilityOfZeroGivesNoRoomToGrowRule() throws {
        let young = try advice(target(age: 19, currentAbility: 0, potentialAbility: 100))
        #expect(reasons(young.reasons, "Aged").isEmpty)
        #expect(!young.isProspect)
        // The growth a false prospect needs does not divide by his ability: 100 points in 5 years.
        #expect(reasons(young.reasons, "Would need")
                == [reason("Would need 20 ability points a year to reach his potential by 24, with Professionalism 10", 35)])
        for age in [23, 31] {
            #expect(reasons(try advice(target(age: age, currentAbility: 0, potentialAbility: 0)).reasons, "Aged").isEmpty)
        }
    }

    @Test func aPotentialBelowCurrentAbilityIsNoRoomToGrow() throws {
        let young = try advice(target(age: 19, currentAbility: 100, potentialAbility: 90))
        #expect(reasons(young.reasons, "Aged").isEmpty && !young.isProspect)
        #expect(reasons(young.reasons, "Would need").isEmpty)
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
        // Alpha critical (terminate), Bravo high (sell), Charlie medium, Delta a high prospect (loan), Echo critical and
        // out of contract (release); everyone else keep.
        let players = try squad([
            target("Alpha") { $0.wagePerWeek = 1_000 },
            target("Bravo") { $0.wagePerWeek = 700; $0.monthsLeft = nil },
            target("Charlie") { $0.wagePerWeek = 300; $0.monthsLeft = nil },
            target("Delta", age: 19, attributes: [.controversy: 17], potentialAbility: 134),
            target("Echo") { $0.contractType = .outOfContract },
        ])
        let r = try report(players)
        let byName = Dictionary(uniqueKeysWithValues: r.advice.map { ($0.name, $0) })
        #expect(byName["Alpha"]?.action == .terminate && byName["Bravo"]?.action == .sell)
        #expect(byName["Delta"]?.action == .loan && byName["Echo"]?.action == .release)
        #expect(byName["Charlie"]?.level == .medium)
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
        ])
        let forward = try report(players)
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
        #expect(Display.pounds(0) == "£0")
        #expect(Display.pounds(999) == "£999")
        #expect(Display.pounds(1_000) == "£1,000")
        #expect(Display.pounds(1_250) == "£1,250")
        #expect(Display.pounds(52_000) == "£52,000")
        #expect(Display.pounds(1_234_567) == "£1,234,567")
        #expect(Display.pounds(-1_250) == "-£1,250")
        #expect(Display.perWeek(1_250) == "£1,250 a week")
    }
}
