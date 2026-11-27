import Foundation
import Testing
@testable import LineupEngine

@Suite struct ContractsTests {
    let tactic = try! PlannerFixture.tactic()
    let catalog = try! RoleCatalog.fm27()
    let profile = try! RatingProfile.standard()
    let parameters = EngineParameters.fm27
    let today = Day(year: 2026, month: 11, day: 25)!
    let ownClub = "Oxford City"

    func day(_ iso: String) -> Day { Day(iso: iso)! }

    /// The planner's squad with three years left on every contract, so nobody is in his last year until a test says so.
    /// Every first choice meets the first eleven's standard and every outfield second choice is under it.
    func squad(_ extra: [Player] = []) throws -> [Player] {
        try PlannerFixture.squad().map { p in var p = p; p.monthsLeft = 36; return p } + extra
    }

    func squad(changing id: PlayerID, _ change: (inout Player) -> Void) throws -> [Player] {
        try squad().map { p in
            var p = p
            if p.id == id { change(&p) }
            return p
        }
    }

    func squad(changing changes: [PlayerID: (inout Player) -> Void], _ extra: [Player] = []) throws -> [Player] {
        try squad(extra).map { p in
            var p = p
            changes[p.id]?(&p)
            return p
        }
    }

    func id(_ slot: SlotID, _ tier: String) -> PlayerID { PlannerFixture.id(slot, tier) }

    func assignment(_ slot: SlotID) -> SlotAssignment {
        try! tactic.assignments(catalog: catalog).first { $0.slot == slot }!
    }

    /// A player of the club's own at `age`, every attribute `all`, familiarity `familiarity` at both of `slot`'s
    /// positions and 1 elsewhere, a full-time contract with 10 months left.
    func player(_ name: String, age: Int = 28, all: Int = 10, familiarity: Int = 1, slot: SlotID = .D_L,
                currentAbility: Int = 100, potentialAbility: Int = 120,
                change: (inout Player) -> Void = { _ in }) -> Player {
        let positions = [assignment(slot).ipPosition, assignment(slot).oopPosition]
        var p = Player.fixture(name: name, age: age, all: all,
                               familiarity: Dictionary(positions.map { ($0, familiarity) }, uniquingKeysWith: { a, _ in a }),
                               currentAbility: currentAbility, potentialAbility: potentialAbility)
        p.monthsLeft = 10
        change(&p)
        return p
    }

    func removal(_ players: [Player]) throws -> RemovalReport {
        try Removal.report(tactic: tactic, players: players, ownClub: ownClub, money: .weeklyPounds,
                           history: StartHistory([]), asOf: today, retraining: [], catalog: catalog,
                           profile: profile, parameters: parameters)
    }

    func elevens(_ players: [Player]) throws -> ElevensReport {
        try Elevens.report(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog, profile: profile,
                           parameters: parameters)
    }

    func depth(_ players: [Player]) throws -> DepthReport {
        try Depth.report(tactic: tactic, players: players, ownClub: ownClub, elevens: try elevens(players),
                         catalog: catalog, profile: profile, parameters: parameters)
    }

    func worth(_ id: PlayerID, in players: [Player]) throws -> RenewalWorth? {
        try Renewal.worths(players: players, ownClub: ownClub, elevens: try elevens(players), depth: try depth(players),
                           parameters: parameters)[id]
    }

    /// The report on `players` made `today`. Player Removal's advice is worked out on them, unless `removal` is
    /// handed in; with `keepingAll` nobody is advised to leave, so the other rules can be seen alone. `leaving` is
    /// added to those advised to leave.
    func report(_ players: [Player], marks: [PlayerID: SaleMark] = [:], dismissed: Set<PlayerID> = [],
                wanted: Set<PlayerID> = [], keepingAll: Bool = true, leaving: Set<PlayerID> = [],
                removal given: RemovalReport? = nil, today: Day? = nil,
                parameters: EngineParameters? = nil) throws -> ContractsReport {
        var r = try given ?? removal(players)
        if keepingAll { r.advisedToLeave = [] }
        r.advisedToLeave.formUnion(leaving)
        return try Contracts.report(players: players, ownClub: ownClub, marks: marks, removal: r,
                                    elevens: try elevens(players), depth: try depth(players), tactic: tactic,
                                    dismissed: dismissed, wanted: wanted, today: today ?? self.today,
                                    catalog: catalog, profile: profile, parameters: parameters ?? self.parameters)
    }

    /// Player Removal's report with `id`'s advice needed at `need` in place of its own.
    func removal(_ players: [Player], needing need: RemovalNeed?, for id: PlayerID) throws -> RemovalReport {
        let r = try removal(players)
        let advice = r.advice.map { a in
            a.player != id ? a : RemovalAdvice(
                player: a.player, name: a.name, level: a.level, action: a.action, score: a.score, reasons: a.reasons,
                tier: a.tier, neededAt: need, worth: a.worth, outlook: a.outlook, matchesHere: a.matchesHere,
                keepReason: a.keepReason, watchReason: a.watchReason, loanOnlyToStart: a.loanOnlyToStart,
                onYouthContract: a.onYouthContract, isFalseProspect: a.isFalseProspect, isMentor: a.isMentor,
                releaseCost: a.releaseCost, mutualCost: a.mutualCost, basis: a.basis)
        }
        return RemovalReport(advice: advice, loans: r.loans, weeklyWagesAtStake: r.weeklyWagesAtStake,
                             squadAverageAbility: r.squadAverageAbility, money: r.money,
                             advisedToLeave: r.advisedToLeave)
    }

    func entry(_ id: PlayerID, in report: ContractsReport) -> ContractEntry? { report.listed.first { $0.player == id } }

    func notRecommended(_ id: PlayerID, in report: ContractsReport) -> ContractEntry? {
        report.notRecommended.first { $0.player == id }
    }

    /// Every list's players, so a test can see that a player is in exactly one.
    func everyone(_ report: ContractsReport) -> [PlayerID] {
        (report.listed + report.notRecommended + report.dismissed).map(\.player)
    }

    // MARK: The part

    func part(ends: Day?, months: Int? = 30, type: ContractType = .fullTime) -> ContractPart? {
        var p = Player.fixture()
        p.contractEnds = ends; p.monthsLeft = months; p.contractType = type
        return Contracts.part(of: p, today: today, parameters: parameters)
    }

    @Test func anEndDayInsideSixMonthsIsApproachableAndInsideTwelveIsTheLastYear() {
        #expect(part(ends: day("2027-04-30")) == .approachable)
        #expect(part(ends: day("2027-05-25")) == .approachable)
        #expect(part(ends: day("2027-05-26")) == .lastYear)
        #expect(part(ends: day("2027-06-30")) == .lastYear)
        #expect(part(ends: day("2027-11-25")) == .lastYear)
        #expect(part(ends: day("2027-11-26")) == nil)
        // A day already past is still approachable.
        #expect(part(ends: day("2026-10-01")) == .approachable)
        // The end day wins over months left.
        #expect(part(ends: day("2028-06-30"), months: 3) == nil)
    }

    @Test func withNoEndDayTheMonthsLeftDecide() {
        #expect(part(ends: nil, months: 0) == .approachable)
        #expect(part(ends: nil, months: 6) == .approachable)
        #expect(part(ends: nil, months: 7) == .lastYear)
        #expect(part(ends: nil, months: 12) == .lastYear)
        #expect(part(ends: nil, months: 13) == nil)
        #expect(part(ends: nil, months: nil) == nil)
    }

    @Test func noContractToRunDownIsItsOwnPart() {
        #expect(part(ends: nil, months: nil, type: .outOfContract) == .noContract)
        #expect(part(ends: nil, months: -1) == .noContract)
        #expect(part(ends: nil, months: 0, type: .youth) == .approachable)
    }

    /// One rule for the part and the day "can approach him from": an end day on the 29th to 31st is approachable on the
    /// day six months before it, clamped to the month, and not before.
    @Test func aContractEndingLateInTheMonthIsApproachableOnTheDayNamed() throws {
        var p = Player.fixture()
        p.contractEnds = day("2027-08-31"); p.monthsLeft = 9
        #expect(Contracts.part(of: p, today: day("2027-02-27"), parameters: parameters) == .lastYear)
        #expect(p.contractEnds?.adding(months: -parameters.wageRangeRules.value.approachMonths) == day("2027-02-28"))
        #expect(Contracts.part(of: p, today: day("2027-02-28"), parameters: parameters) == .approachable)
        // In his last year from the day twelve months before the end.
        #expect(Contracts.part(of: p, today: day("2026-08-30"), parameters: parameters) == nil)
        #expect(Contracts.part(of: p, today: day("2026-08-31"), parameters: parameters) == .lastYear)
        // The day named on a report made on 27 Feb 2027 is the day he moves.
        let target = id(.D_L, "first")
        let players = try squad(changing: target) { $0.contractEnds = day("2027-08-31"); $0.monthsLeft = 6 }
        let r = try report(players, keepingAll: false, today: day("2027-02-27"))
        let e = try #require(entry(target, in: r))
        #expect(e.part == .lastYear && e.approachableFrom == day("2027-02-28"))
    }

    @Test func approachableFromIsSixMonthsBeforeTheEnd() throws {
        let target = id(.D_L, "first")
        let ends = try report(try squad(changing: target) { $0.contractEnds = day("2027-06-30"); $0.monthsLeft = 7 })
        let e = try #require(entry(target, in: ends))
        #expect(e.part == .lastYear && e.ends == day("2027-06-30"))
        #expect(e.approachableFrom == day("2026-12-30"))
        // Approachable already, or with no end day: no day.
        let now = try report(try squad(changing: target) { $0.contractEnds = day("2027-04-30"); $0.monthsLeft = 5 })
        #expect(try #require(entry(target, in: now)).approachableFrom == nil)
        let months = try report(try squad(changing: target) { $0.monthsLeft = 10 })
        let m = try #require(entry(target, in: months))
        #expect(m.part == .lastYear && m.ends == nil && m.approachableFrom == nil)
    }

    // MARK: Recommended or not

    @Test func aPlayerWhoMeetsTheStandardIsListedAndOneUnderItIsNotRecommended() throws {
        let first = id(.D_L, "first"), second = id(.D_L, "second")
        let players = try squad(changing: [first: { $0.monthsLeft = 10 }, second: { $0.monthsLeft = 4 }])
        let firstWorth = try #require(try worth(first, in: players))
        let secondWorth = try #require(try worth(second, in: players))
        try #require(firstWorth.meetsStandard && !secondWorth.meetsStandard)

        let r = try report(players)
        #expect(r.listed.map(\.player) == [first])
        let e = try #require(entry(first, in: r))
        #expect(e.standing == .first(.D_L) && e.tier == .firstEleven && e.slot == .D_L)
        #expect(e.name == "D_L first" && e.presentWagePerWeek == 500)
        #expect(e.worth == firstWorth && e.reasons.isEmpty && !e.isWanted)
        let advice = try #require(try removal(players).advice.first { $0.player == first })
        #expect(e.action == advice.action)

        #expect(r.notRecommended.map(\.player) == [second])
        let n = try #require(notRecommended(second, in: r))
        #expect(n.part == .approachable && n.standing == .second(.D_L) && n.tier == .secondEleven && n.slot == .D_L)
        #expect(n.worth == secondWorth && !n.isWanted)
        #expect(n.reasons == [.underStandard(secondWorth), .replaceFirst(slot: .D_L, why: .secondChoice)])
        #expect(r.dismissed.isEmpty)
        #expect(r.basis == .derived)

        // Nobody in his last year: nobody in any list.
        let none = try report(try squad())
        #expect(everyone(none).isEmpty)
    }

    @Test func theListsAreOrderedByWorthThenEndDay() throws {
        let players0 = try squad()
        func share(_ id: PlayerID) throws -> Double { try #require(try worth(id, in: players0)).share }
        // The shares the order rests on: the attacking midfielder and the striker highest, then the goalkeeper, the
        // two defensive midfielders level, the full backs level and the centre-backs level.
        try #require(try share(id(.AM_C, "first")) > share(id(.ST_C, "first")))
        try #require(try share(id(.ST_C, "first")) > share(id(.GK, "first")))
        try #require(try share(id(.GK, "first")) > share(id(.DM_L, "first")))
        try #require(try share(id(.DM_L, "first")) == share(id(.DM_R, "first")))
        try #require(try share(id(.DM_R, "first")) > share(id(.D_L, "first")))
        try #require(try share(id(.D_L, "first")) == share(id(.D_R, "first")))
        try #require(try share(id(.D_R, "first")) > share(id(.D_CL, "first")))
        try #require(try share(id(.D_CL, "first")) == share(id(.D_CR, "first")))
        try #require(try share(id(.AM_C, "second")) > share(id(.D_L, "second")))

        let nowhere = player("Nowhere")
        let ends: [PlayerID: (inout Player) -> Void] = [
            // The striker's end day is the sooner, and his worth still puts him second.
            id(.AM_C, "first"): { $0.monthsLeft = 10 },
            id(.ST_C, "first"): { $0.contractEnds = self.day("2027-03-31"); $0.monthsLeft = 4 },
            id(.GK, "first"): { $0.monthsLeft = 11 },
            // Level in worth and in months: the order handed in.
            id(.DM_L, "first"): { $0.monthsLeft = 7 },
            id(.DM_R, "first"): { $0.monthsLeft = 7 },
            // Level in worth: an end day before none.
            id(.D_L, "first"): { $0.monthsLeft = 5 },
            id(.D_R, "first"): { $0.contractEnds = self.day("2027-04-30"); $0.monthsLeft = 5 },
            // Level in worth, neither with an end day: fewer months first.
            id(.D_CL, "first"): { $0.monthsLeft = 8 },
            id(.D_CR, "first"): { $0.monthsLeft = 4 },
            // Not recommended, in the same order, and one with no worth last.
            id(.AM_C, "second"): { $0.monthsLeft = 12 },
            id(.D_L, "second"): { $0.contractEnds = self.day("2027-01-31"); $0.monthsLeft = 2 },
        ]
        let players = try squad(changing: ends, [nowhere])
        let tied = [id(.DM_L, "first"), id(.DM_R, "first")]
        func expected(_ tie: [PlayerID]) -> [PlayerID] {
            [id(.AM_C, "first"), id(.ST_C, "first"), id(.GK, "first")] + tie
                + [id(.D_R, "first"), id(.D_L, "first"), id(.D_CR, "first"), id(.D_CL, "first")]
        }
        let order = players.map(\.id).filter(tied.contains)
        let r = try report(players)
        #expect(r.listed.map(\.player) == expected(order))
        #expect(r.notRecommended.map(\.player) == [id(.AM_C, "second"), id(.D_L, "second"), nowhere.id])
        // Reversing the players changes only the tie.
        let reversed = try report(players.reversed())
        #expect(reversed.listed.map(\.player) == expected(order.reversed()))
        #expect(reversed.notRecommended.map(\.player) == r.notRecommended.map(\.player))
        // The players set aside keep the same order.
        let aside = try report(players, dismissed: Set(r.listed.map(\.player)))
        #expect(aside.listed.isEmpty && aside.dismissed.map(\.player) == expected(order))
    }

    @Test func aPlayerMarkedToSellIsNotRecommendedAndOneMarkedToLoanOutIsJudgedLikeAnyone() throws {
        let target = id(.D_L, "first")
        let players = try squad(changing: target) { $0.monthsLeft = 10 }
        let sold = try report(players, marks: [target: .toSell])
        #expect(sold.listed.isEmpty && sold.dismissed.isEmpty)
        let e = try #require(notRecommended(target, in: sold))
        #expect(e.reasons == [.markedToSell, .replaceFirst(slot: .D_L, why: .firstChoice)])
        // Marked to sell and set aside: not recommended all the same.
        let both = try report(players, marks: [target: .toSell], dismissed: [target])
        #expect(both.notRecommended.map(\.player) == [target] && both.dismissed.isEmpty)

        let loaned = try report(players, marks: [target: .toLoanOut])
        #expect(loaned.listed.map(\.player) == [target] && loaned.notRecommended.isEmpty)
        #expect(try #require(entry(target, in: loaned)).reasons.isEmpty)
        // Under the standard, a mark to loan out adds nothing.
        let second = id(.D_L, "second")
        let under = try report(try squad(changing: second) { $0.monthsLeft = 10 }, marks: [second: .toLoanOut])
        #expect(try #require(notRecommended(second, in: under)).reasons.first.map {
            if case .underStandard = $0 { true } else { false }
        } == true)
    }

    /// The left back's second choice out of contract with a poor character, his potential at his ability: under the
    /// standard, and advised to go.
    func poorCharacter(_ p: inout Player) {
        p.contractType = .outOfContract
        p.monthsLeft = nil
        p.potentialAbility = p.currentAbility
        for (attribute, value) in [(Attribute.controversy, 20), (.ambition, 1), (.temperament, 1), (.consistency, 1)] {
            p.attributes[attribute] = value
        }
    }

    @Test func aPlayerAdvisedToLeaveIsNotRecommendedWithTheAction() throws {
        let target = id(.D_L, "second")
        let players = try squad(changing: target, poorCharacter)
        let advised = try removal(players)
        try #require(advised.advisedToLeave.contains(target))
        let advice = try #require(advised.advice.first { $0.player == target })
        let w = try #require(try worth(target, in: players))
        let r = try report(players, keepingAll: false)
        let e = try #require(notRecommended(target, in: r))
        #expect(e.part == .noContract)
        #expect(e.reasons == [.advisedToLeave(advice.action), .underStandard(w),
                              .replaceFirst(slot: .D_L, why: .secondChoice)])
        // Not advised to go: the same player keeps the other reasons alone.
        let kept = try report(players)
        #expect(try #require(notRecommended(target, in: kept)).reasons
                == [.underStandard(w), .replaceFirst(slot: .D_L, why: .secondChoice)])
        // A player who meets the standard and is advised to go is not recommended either.
        let first = id(.D_L, "first")
        let leaving = try report(try squad(changing: first) { $0.monthsLeft = 10 }, leaving: [first])
        let f = try #require(notRecommended(first, in: leaving))
        let action = try #require(try removal(try squad(changing: first) { $0.monthsLeft = 10 }).advice
            .first { $0.player == first }?.action)
        #expect(f.reasons == [.advisedToLeave(action), .replaceFirst(slot: .D_L, why: .firstChoice)])
    }

    @Test func everyReasonThatAppliesIsGivenInOrder() throws {
        // A first choice at left back who is under the standard: the left backs weakened.
        let first = id(.D_L, "first"), second = id(.D_L, "second")
        let players = try squad(changing: [
            first: { p in p.monthsLeft = 10; for a in Attribute.allCases { p.attributes[a] = 12 } },
            second: { p in for a in Attribute.allCases { p.attributes[a] = 10 } },
        ])
        let w = try #require(try worth(first, in: players))
        try #require(!w.meetsStandard && w.slot == .D_L)
        let r = try report(players, marks: [first: .toSell], leaving: [first])
        let e = try #require(notRecommended(first, in: r))
        try #require(e.standing == .first(.D_L))
        let action = try #require(try removal(players).advice.first { $0.player == first }?.action)
        #expect(e.reasons == [.markedToSell, .advisedToLeave(action), .underStandard(w),
                              .replaceFirst(slot: .D_L, why: .firstChoice)])
    }

    @Test func aFirstChoiceNotRecommendedIsToReplaceFirstAndOneInNeitherElevenIsNot() throws {
        let first = id(.D_L, "first")
        let backup = player("Backup", all: 10, familiarity: 20)
        let players = try squad(changing: first, { $0.monthsLeft = 10 }) + [backup]
        let backupAdvice = try #require(try removal(players).advice.first { $0.player == backup.id })
        try #require(backupAdvice.tier == .backup && backupAdvice.neededAt == nil)
        let r = try report(players, marks: [first: .toSell])
        #expect(try #require(notRecommended(first, in: r)).reasons.last == .replaceFirst(slot: .D_L, why: .firstChoice))
        let b = try #require(notRecommended(backup.id, in: r))
        #expect(b.standing == .neither)
        #expect(b.reasons.count == 1 && b.reasons.allSatisfy { if case .underStandard = $0 { true } else { false } })

        // In neither eleven and needed as cover or as a stand-in: Player Removal's need says so.
        for (kind, why) in [(RemovalNeedKind.cover, ReplaceWhy.cover), (.standIn, .standIn)] {
            let needed = try removal(players, needing: RemovalNeed(slot: .D_L, kind: kind), for: backup.id)
            let n = try #require(notRecommended(backup.id, in: try report(players, removal: needed)))
            #expect(n.reasons.last == .replaceFirst(slot: .D_L, why: why))
            #expect(n.reasons.count == 2)
        }
        // A player the tool recommends gets no replacement reason, however he is needed.
        let needed = try removal(players, needing: RemovalNeed(slot: .D_L, kind: .cover), for: first)
        #expect(try #require(entry(first, in: try report(players, removal: needed))).reasons.isEmpty)
    }

    @Test func aPlayerOutOnLoanUnderTheStandardHasNoReplacementReason() throws {
        let away = loanedOut(all: 11)
        let players = try squad([away])
        let w = try #require(try worth(away.id, in: players))
        try #require(!w.meetsStandard)
        let e = try #require(notRecommended(away.id, in: try report(players)))
        #expect(e.standing == .outOnLoan(to: "Wallingford", level: .wouldCountAsCover, slot: .D_L))
        #expect(e.reasons == [.underStandard(w)] && e.action == nil)
    }

    @Test func aYouthContractPlayerIsJudgedOnHisWorthAlone() throws {
        // A seventeen-year-old left back in neither eleven whose reach meets the standard.
        let young = player("Young", age: 17, all: 12, familiarity: 14, currentAbility: 80, potentialAbility: 200) { p in
            p.attributes[.professionalism] = 20
            p.contractType = .youth
        }
        let players = try squad([young])
        let advice = try #require(try removal(players).advice.first { $0.player == young.id })
        try #require(advice.tier == .backup)
        let w = try #require(try worth(young.id, in: players))
        try #require(w.meetsStandard)
        let e = try #require(entry(young.id, in: try report(players)))
        #expect(e.standing == .neither && e.tier == .neither && e.worth == w && e.reasons.isEmpty)

        // The second choice at left back on a youth contract, under the standard: not recommended, his place in the
        // second eleven notwithstanding.
        let second = id(.D_L, "second")
        let youth = try squad(changing: second) { $0.contractType = .youth; $0.monthsLeft = 0 }
        let n = try #require(notRecommended(second, in: try report(youth)))
        #expect(n.part == .approachable && n.standing == .second(.D_L))
        // With no contract and under the standard, the same.
        let lapsed = try squad(changing: second) { $0.contractType = .outOfContract; $0.monthsLeft = nil }
        #expect(notRecommended(second, in: try report(lapsed))?.part == .noContract)
    }

    @Test func aPlayerWhoCanPlayNoSlotIsNotRecommendedAndSaysSo() throws {
        let nowhere = player("Nowhere")
        let r = try report(try squad([nowhere]))
        let e = try #require(notRecommended(nowhere.id, in: r))
        #expect(e.worth == nil && e.reasons == [.noSlot] && e.standing == .neither)
    }

    @Test func aPlayerOnLoanHereIsInNoList() throws {
        let target = id(.D_L, "first")
        let players = try squad(changing: target) { $0.monthsLeft = 10; $0.club = "Other FC"; $0.loanedTo = "Oxford City" }
        #expect(everyone(try report(players, marks: [target: .toSell])).isEmpty)
        #expect(everyone(try report(players, wanted: [target])).isEmpty)
    }

    // MARK: The owner's choices

    @Test func aDismissedPlayerIsInDismissedAndNotListed() throws {
        let target = id(.D_L, "first")
        let r = try report(try squad(changing: target) { $0.monthsLeft = 10 }, dismissed: [target])
        #expect(r.listed.isEmpty && r.notRecommended.isEmpty)
        #expect(r.dismissed.map(\.player) == [target])
        #expect(r.dismissed.first?.reasons == [] && r.dismissed.first?.isWanted == false)
    }

    @Test func renewAnywayListsHimAsWantedWithHisReasons() throws {
        let second = id(.D_L, "second")
        let players = try squad(changing: second) { $0.monthsLeft = 10 }
        let w = try #require(try worth(second, in: players))
        let r = try report(players, wanted: [second])
        #expect(r.notRecommended.isEmpty && r.dismissed.isEmpty)
        let e = try #require(entry(second, in: r))
        #expect(e.isWanted)
        #expect(e.reasons == [.underStandard(w), .replaceFirst(slot: .D_L, why: .secondChoice)])
        // Wanted and then set aside: with the players set aside, still wanted.
        let aside = try report(players, dismissed: [second], wanted: [second])
        #expect(aside.listed.isEmpty && aside.notRecommended.isEmpty)
        #expect(aside.dismissed.map(\.player) == [second] && aside.dismissed.first?.isWanted == true)
    }

    @Test func aWantedPlayerTheToolNowRecommendsIsAnOrdinaryRow() throws {
        let first = id(.D_L, "first")
        let r = try report(try squad(changing: first) { $0.monthsLeft = 10 }, wanted: [first])
        let e = try #require(entry(first, in: r))
        #expect(!e.isWanted && e.reasons.isEmpty)
        #expect(r.listed.count == 1 && r.notRecommended.isEmpty && r.dismissed.isEmpty)
    }

    @Test func aDismissedPlayerTheToolNoLongerRecommendsIsUnderNotRecommended() throws {
        let second = id(.D_L, "second")
        let r = try report(try squad(changing: second) { $0.monthsLeft = 10 }, dismissed: [second])
        #expect(r.listed.isEmpty && r.dismissed.isEmpty)
        #expect(r.notRecommended.map(\.player) == [second])
    }

    @Test func notBeingRenewedIsTheNotRecommendedAndTheDismissed() throws {
        let players = try squad(changing: [
            id(.D_L, "first"): { $0.monthsLeft = 10 },
            id(.D_R, "first"): { $0.monthsLeft = 10 },
            id(.D_L, "second"): { $0.monthsLeft = 10 },
            id(.D_R, "second"): { $0.monthsLeft = 10 },
        ])
        let r = try report(players, dismissed: [id(.D_L, "first")], wanted: [id(.D_R, "second")])
        #expect(r.listed.map(\.player).sorted { $0.key < $1.key } == [id(.D_R, "first"), id(.D_R, "second")])
        #expect(r.notBeingRenewed == [id(.D_L, "first"), id(.D_L, "second")])
    }

    // MARK: No standard, and errors

    @Test func withNoStandardEveryoneIsNotRecommendedAndSaysWhy() throws {
        // A goalkeeper and a player who can play no slot: the first eleven has no outfield player in position.
        var keeper = try #require(try PlannerFixture.squad().first { $0.id == id(.GK, "first") })
        keeper.monthsLeft = 10
        let nowhere = player("Nowhere")
        let players = [keeper, nowhere]
        let standard = Renewal.standard(elevens: try elevens(players), depth: try depth(players), players: players,
                                        parameters: parameters)
        try #require(standard.rating == nil)
        let r = try report(players, marks: [nowhere.id: .toSell])
        #expect(r.listed.isEmpty && r.dismissed.isEmpty)
        #expect(Set(r.notRecommended.map(\.player)) == [keeper.id, nowhere.id])
        let k = try #require(notRecommended(keeper.id, in: r))
        #expect(k.worth == nil && k.reasons == [.noStandard, .replaceFirst(slot: .GK, why: .firstChoice)])
        let n = try #require(notRecommended(nowhere.id, in: r))
        #expect(n.reasons.prefix(2) == [.markedToSell, .noStandard])
        // Wanted all the same: listed at the owner's choice.
        let wanted = try report(players, wanted: [keeper.id])
        #expect(wanted.listed.map(\.player) == [keeper.id] && wanted.listed.first?.isWanted == true)
    }

    @Test func aYoungPlayerOutOnLoanMissingAnAttributeStopsTheListNamingHim() throws {
        let away = loanedOut(all: 14) { p in p.age = 20; p.attributes[.professionalism] = nil }
        let players = try squad([away])
        // Player Removal does not review a player out on loan, so its report on the others is the one handed in.
        let others = try removal(try squad())
        #expect(throws: RatingError.missingAttribute(player: "Away", attribute: .professionalism)) {
            try report(players, removal: others)
        }
        // Not in his last year: not measured, so the list stands.
        let later = loanedOut(all: 14) { p in p.age = 20; p.attributes[.professionalism] = nil; p.monthsLeft = 30 }
        #expect(everyone(try report(try squad([later]), removal: others)).isEmpty)
    }

    // MARK: A player out on loan

    /// A left back out on loan at Wallingford with 10 months left, familiarity 20 at left back, every attribute `all`.
    func loanedOut(all: Int, change: (inout Player) -> Void = { _ in }) -> Player {
        player("Away", all: all, familiarity: 20) { p in p.loanedTo = "Wallingford"; change(&p) }
    }

    @Test func aPlayerOutOnLoanIsRatedAgainstTheWholeSquad() throws {
        let away = loanedOut(all: 18)
        let e = try #require(entry(away.id, in: try report(try squad([away]))))
        #expect(e.standing == .outOnLoan(to: "Wallingford", level: .wouldStart, slot: .D_L))
        #expect(e.tier == .firstEleven && e.slot == .D_L && e.action == nil && e.part == .lastYear)
        #expect(e.worth?.meetsStandard == true)
    }

    @Test func aPlayerOutOnLoanWhoCanPlayNoSlotStandsNowhere() throws {
        let away = player("Away") { p in p.loanedTo = "Wallingford" }
        let e = try #require(notRecommended(away.id, in: try report(try squad([away]))))
        #expect(e.standing == .outOnLoan(to: "Wallingford", level: nil, slot: nil))
        #expect(e.tier == .neither && e.slot == nil && e.action == nil && e.reasons == [.noSlot])
    }

    @Test func aPlayerOutOnLoanOnAYouthContractOrWithNoneIsJudgedOnHisWorth() throws {
        let youth = loanedOut(all: 18) { $0.contractType = .youth }
        #expect(entry(youth.id, in: try report(try squad([youth])))?.tier == .firstEleven)
        let lapsed = loanedOut(all: 18) { p in p.contractType = .outOfContract; p.monthsLeft = nil; p.wagePerWeek = 0 }
        let e = try #require(entry(lapsed.id, in: try report(try squad([lapsed]))))
        #expect(e.part == .noContract && e.tier == .firstEleven)
    }

    @Test func badParametersAreRefused() throws {
        var bad = parameters
        bad.wageRangeRules = Parameter(WageRangeRules(lastYearMonths: 0, approachMonths: 6, keyPlayerShare: 0.075,
                                                      starterShare: 0.043, backupShare: 0.027, fewestWages: 3),
                                       .derived, source: "test")
        let players = try squad()
        #expect(throws: PlanError.self) {
            try report(players, parameters: bad)
        }
    }
}
