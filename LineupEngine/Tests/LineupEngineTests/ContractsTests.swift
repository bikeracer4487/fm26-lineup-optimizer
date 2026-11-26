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

    /// The report on `players`. Player Removal's advice is worked out on them; with `keepingAll` nobody is advised to
    /// leave, so the other rules can be seen alone. `leaving` is added to those advised to leave.
    func report(_ players: [Player], marks: [PlayerID: SaleMark] = [:], dismissed: Set<PlayerID> = [],
                keepingAll: Bool = true, leaving: Set<PlayerID> = []) throws -> ContractsReport {
        var r = try removal(players)
        if keepingAll { r.advisedToLeave = [] }
        r.advisedToLeave.formUnion(leaving)
        return try Contracts.report(players: players, ownClub: ownClub, marks: marks, removal: r,
                                    elevens: try elevens(players), tactic: tactic, dismissed: dismissed, today: today,
                                    catalog: catalog, profile: profile, parameters: parameters)
    }

    func entry(_ id: PlayerID, in report: ContractsReport) -> ContractEntry? { report.listed.first { $0.player == id } }

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
        let r = try Contracts.report(players: players, ownClub: ownClub, marks: [:], removal: try removal(players),
                                     elevens: try elevens(players), tactic: tactic, dismissed: [],
                                     today: day("2027-02-27"), catalog: catalog, profile: profile,
                                     parameters: parameters)
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

    // MARK: Who is listed

    @Test func aFirstChoiceInHisLastYearIsListed() throws {
        let target = id(.D_L, "first")
        let players = try squad(changing: target) { $0.monthsLeft = 10 }
        let r = try report(players)
        #expect(r.listed.map(\.player) == [target])
        let e = try #require(entry(target, in: r))
        #expect(e.standing == .first(.D_L) && e.tier == .firstEleven && e.slot == .D_L)
        #expect(e.name == "D_L first" && e.presentWagePerWeek == 500)
        let advice = try #require(try removal(players).advice.first { $0.player == target })
        #expect(e.action == advice.action)
        #expect(r.dismissed.isEmpty && r.leftOutAsGoing == 0)
        #expect(r.basis == .derived)
        // Nobody in his last year: nobody listed.
        let none = try report(try squad())
        #expect(none.listed.isEmpty && none.dismissed.isEmpty && none.leftOutAsGoing == 0)
    }

    @Test func aSecondChoiceIsListedAtHisSlot() throws {
        let target = id(.ST_C, "second")
        let e = try #require(entry(target, in: try report(try squad(changing: target) { $0.monthsLeft = 4 })))
        #expect(e.part == .approachable && e.standing == .second(.ST_C) && e.tier == .secondEleven && e.slot == .ST_C)
    }

    @Test func aPlayerMarkedOrAdvisedToLeaveIsCountedAndNotListed() throws {
        let target = id(.D_L, "first")
        let players = try squad(changing: target) { $0.monthsLeft = 10 }
        for mark in SaleMark.allCases {
            let r = try report(players, marks: [target: mark])
            #expect(r.listed.isEmpty && r.dismissed.isEmpty && r.leftOutAsGoing == 1)
        }
        let leaving = try report(players, leaving: [target])
        #expect(leaving.listed.isEmpty && leaving.dismissed.isEmpty && leaving.leftOutAsGoing == 1)
        // Going and dismissed: counted as going, in neither list.
        let both = try report(players, marks: [target: .toSell], dismissed: [target])
        #expect(both.listed.isEmpty && both.dismissed.isEmpty && both.leftOutAsGoing == 1)
    }

    @Test func aPlayerOnLoanHereIsInNoListAndNotCounted() throws {
        let target = id(.D_L, "first")
        let players = try squad(changing: target) { $0.monthsLeft = 10; $0.club = "Other FC"; $0.loanedTo = "Oxford City" }
        let r = try report(players, marks: [target: .toSell])
        #expect(r.listed.isEmpty && r.dismissed.isEmpty && r.leftOutAsGoing == 0)
    }

    @Test func aDismissedPlayerIsInDismissedAndNotListed() throws {
        let target = id(.D_L, "first")
        let r = try report(try squad(changing: target) { $0.monthsLeft = 10 }, dismissed: [target])
        #expect(r.listed.isEmpty)
        #expect(r.dismissed.map(\.player) == [target])
        #expect(r.leftOutAsGoing == 0)
    }

    /// A young left back on a youth contract with 10 months left, a backup, whose reach at left back is just short of
    /// the second choice's rating there (`making` − 1) or reaches it (`making`).
    func youngster(potentialAbility: Int) -> Player {
        player("Young", age: 17, all: 10, familiarity: 12, currentAbility: 80, potentialAbility: potentialAbility) { p in
            p.attributes[.professionalism] = 20
            p.contractType = .youth
        }
    }

    /// The least potential that takes the youngster's reach at left back to the second choice's rating there.
    func makingPotential() throws -> Int {
        let probe = youngster(potentialAbility: 80)
        let players = try squad([probe])
        let tiers = try elevens(players).tiers
        let his = try #require(tiers.ratings[probe.id]?[.D_L])
        let second = try #require(tiers.ratings[id(.D_L, "second")]?[.D_L])
        let offset = parameters.ratingAbilityOffset.value
        return Int(((offset + 80) * second / his - offset).rounded(.up))
    }

    @Test func aYoungPlayerOnAYouthContractIsListedOnlyWhenWorthDeveloping() throws {
        let making = try makingPotential()
        let cover = youngster(potentialAbility: making - 1)
        let coverPlayers = try squad([cover])
        let coverAdvice = try #require(try removal(coverPlayers).advice.first { $0.player == cover.id })
        try #require(coverAdvice.tier == .backup && coverAdvice.outlook?.level == .couldBeCover)
        let notListed = try report(coverPlayers, keepingAll: false)
        #expect(entry(cover.id, in: notListed) == nil && notListed.dismissed.isEmpty && notListed.leftOutAsGoing == 0)

        let second = youngster(potentialAbility: making)
        let secondPlayers = try squad([second])
        let secondAdvice = try #require(try removal(secondPlayers).advice.first { $0.player == second.id })
        try #require(secondAdvice.tier == .backup && secondAdvice.outlook?.level == .couldMakeSecond)
        let e = try #require(entry(second.id, in: try report(secondPlayers)))
        #expect(e.standing == .neither && e.tier == .neither && e.slot == nil && e.action == secondAdvice.action)
    }

    /// FMRTE rounds months down, so a youth contract in its last month reads 0 months left; the gate still holds.
    @Test func aYouthContractAtNoMonthsLeftPassesTheGateOnlyInAnEleven() throws {
        let making = try makingPotential()
        var last = youngster(potentialAbility: making - 1)
        last.monthsLeft = 0
        let players = try squad([last])
        let advice = try #require(try removal(players).advice.first { $0.player == last.id })
        try #require(advice.tier == .backup && advice.outlook.map(Removal.isWorthDeveloping) != true)
        for keepingAll in [true, false] {
            let r = try report(players, keepingAll: keepingAll)
            #expect(entry(last.id, in: r) == nil && r.dismissed.isEmpty && r.leftOutAsGoing == 0)
        }
        // In the second eleven at 0 months left: listed.
        let target = id(.D_L, "second")
        let second = try #require(entry(target, in: try report(try squad(changing: target) {
            $0.contractType = .youth; $0.monthsLeft = 0
        })))
        #expect(second.part == .approachable && second.standing == .second(.D_L))
    }

    @Test func aPlayerTheGateLeavesOutIsNotCountedAsGoing() throws {
        func outOfContract(_ p: inout Player) { p.contractType = .outOfContract; p.monthsLeft = nil; p.wagePerWeek = 0 }
        let backup = player("Backup", change: outOfContract)
        let players = try squad([backup])
        for mark in SaleMark.allCases {
            let r = try report(players, marks: [backup.id: mark])
            #expect(entry(backup.id, in: r) == nil && r.leftOutAsGoing == 0)
        }
        #expect(try report(players, leaving: [backup.id]).leftOutAsGoing == 0)
    }

    @Test func aFullTimeBackupIsListedWhateverHisStanding() throws {
        let backup = player("Backup")
        let players = try squad([backup])
        try #require(try removal(players).advice.first { $0.player == backup.id }?.outlook == nil)
        let e = try #require(entry(backup.id, in: try report(players)))
        #expect(e.standing == .neither && e.tier == .neither && e.part == .lastYear)
    }

    @Test func aPlayerWithNoContractIsListedOnlyInAnEleven() throws {
        func outOfContract(_ p: inout Player) { p.contractType = .outOfContract; p.monthsLeft = nil; p.wagePerWeek = 0 }
        let backup = player("Backup", change: outOfContract)
        let r = try report(try squad([backup]))
        #expect(entry(backup.id, in: r) == nil && r.leftOutAsGoing == 0)
        let target = id(.D_L, "second")
        let second = try #require(entry(target, in: try report(try squad(changing: target, outOfContract))))
        #expect(second.part == .noContract && second.standing == .second(.D_L) && second.ends == nil)
        #expect(second.presentWagePerWeek == 0)
        // Months left below zero is no contract too.
        let lapsed = try #require(entry(target, in: try report(try squad(changing: target) { $0.monthsLeft = -1 })))
        #expect(lapsed.part == .noContract)
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
    }

    @Test func aPlayerOutOnLoanWhoCanPlayNoSlotStandsNowhere() throws {
        let away = player("Away") { p in p.loanedTo = "Wallingford" }
        let e = try #require(entry(away.id, in: try report(try squad([away]))))
        #expect(e.standing == .outOnLoan(to: "Wallingford", level: nil, slot: nil))
        #expect(e.tier == .neither && e.slot == nil && e.action == nil)
    }

    @Test func aPlayerOutOnLoanOnAYouthContractIsListedOnlyInAnEleven() throws {
        let full = loanedOut(all: 11)
        let e = try #require(entry(full.id, in: try report(try squad([full]))))
        try #require(e.standing == .outOnLoan(to: "Wallingford", level: .wouldCountAsCover, slot: .D_L))
        #expect(e.tier == .neither)
        let youth = loanedOut(all: 11) { $0.contractType = .youth }
        let r = try report(try squad([youth]))
        #expect(entry(youth.id, in: r) == nil && r.leftOutAsGoing == 0)
        // On a youth contract at a level that would start: listed.
        let starter = loanedOut(all: 18) { $0.contractType = .youth }
        #expect(entry(starter.id, in: try report(try squad([starter])))?.tier == .firstEleven)
    }

    @Test func aPlayerOutOnLoanWithNoContractIsListedOnlyInAnEleven() throws {
        func outOfContract(_ p: inout Player) { p.contractType = .outOfContract; p.monthsLeft = nil; p.wagePerWeek = 0 }
        let cover = loanedOut(all: 11, change: outOfContract)
        let players = try squad([cover])
        let r = try report(players)
        #expect(entry(cover.id, in: r) == nil && r.dismissed.isEmpty && r.leftOutAsGoing == 0)
        // At a level that would start: listed, in the part with no contract.
        let starter = loanedOut(all: 18, change: outOfContract)
        let e = try #require(entry(starter.id, in: try report(try squad([starter]))))
        #expect(e.part == .noContract && e.tier == .firstEleven)
    }

    // MARK: Order

    @Test func thePartsComeInOrderAndTheSoonerEndFirst() throws {
        // Approachable up to 25 May 2027, the last year up to 25 Nov 2027.
        let ends: [PlayerID: (Day?, Int?)] = [
            id(.GK, "second"): (nil, 8),
            id(.D_L, "second"): (day("2027-04-30"), 5),
            id(.D_R, "second"): (day("2027-03-31"), 4),
            id(.D_CL, "second"): (nil, -1),
            id(.D_CR, "second"): (day("2027-04-30"), 5),
            id(.DM_L, "second"): (day("2027-06-30"), 7),
            id(.AM_L, "second"): (nil, 7),
            id(.AM_C, "second"): (nil, 4),
            id(.ST_C, "second"): (day("2027-05-31"), 6),
        ]
        let players = try squad().map { p in
            var p = p
            if let (end, months) = ends[p.id] { p.contractEnds = end; p.monthsLeft = months }
            return p
        }
        let tied = [id(.D_L, "second"), id(.D_CR, "second")]
        func expected(_ tie: [PlayerID]) -> [PlayerID] {
            [id(.D_R, "second")] + tie + [id(.AM_C, "second"), id(.ST_C, "second"), id(.DM_L, "second"),
                                          id(.AM_L, "second"), id(.GK, "second"), id(.D_CL, "second")]
        }
        // D_L and D_CR end on one day and keep the order of `players`.
        let order = players.map(\.id).filter(tied.contains)
        let r = try report(players)
        #expect(r.listed.map(\.player) == expected(order))
        #expect(r.listed.map(\.part) == [.approachable, .approachable, .approachable, .approachable,
                                         .lastYear, .lastYear, .lastYear, .lastYear, .noContract])
        // Reversing the players changes only the tie.
        let reversed = try report(players.reversed())
        #expect(reversed.listed.map(\.player) == expected(order.reversed()))
    }

    @Test func dismissedPlayersAreOrderedAsTheListIs() throws {
        let a = id(.D_L, "second"), b = id(.D_R, "second")
        let players = try squad().map { p in
            var p = p
            if p.id == a { p.monthsLeft = 11 }
            if p.id == b { p.monthsLeft = 3 }
            return p
        }
        let r = try report(players, dismissed: [a, b])
        #expect(r.listed.isEmpty && r.dismissed.map(\.player) == [b, a])
    }

    @Test func badParametersAreRefused() throws {
        var bad = parameters
        bad.wageRangeRules = Parameter(WageRangeRules(lastYearMonths: 0, approachMonths: 6, keyPlayerShare: 0.075,
                                                      starterShare: 0.043, backupShare: 0.027, fewestWages: 3),
                                       .derived, source: "test")
        let players = try squad()
        #expect(throws: PlanError.self) {
            try Contracts.report(players: players, ownClub: ownClub, marks: [:], removal: try removal(players),
                                 elevens: try elevens(players), tactic: tactic, dismissed: [], today: today,
                                 catalog: catalog, profile: profile, parameters: bad)
        }
    }
}
