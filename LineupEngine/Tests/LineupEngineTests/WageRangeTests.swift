import Testing
@testable import LineupEngine

@Suite struct WageRangeTests {
    let parameters = EngineParameters.fm27

    func wage(_ name: String, _ perWeek: Double) -> PlayerWage {
        PlayerWage(player: PlayerID(key: PlayerID.normalise(name)), perWeek: perWeek)
    }

    /// 500, 600, 700, 800, 900 in the second eleven; "Nine" earns the 900.
    var five: [WageTier: [PlayerWage]] {
        [.secondEleven: [wage("One", 500), wage("Two", 600), wage("Three", 700), wage("Four", 800), wage("Nine", 900)]]
    }
    var three: [WageTier: [PlayerWage]] {
        [.secondEleven: [wage("One", 500), wage("Two", 600), wage("Three", 700)]]
    }
    var two: [WageTier: [PlayerWage]] { [.secondEleven: [wage("One", 500), wage("Two", 600)]] }

    func guide(_ wages: [WageTier: [PlayerWage]], tier: WageTier = .secondEleven, excluding: PlayerID? = nil,
               present: Double? = nil, limits: WageLimits = .none) throws -> WageGuide {
        try WageRange.guide(tier: tier, slot: nil, wages: wages, excluding: excluding, presentWagePerWeek: present,
                            limits: limits, parameters: parameters)
    }

    // MARK: The range

    @Test func fiveWagesGiveTheirLowerQuartileAndHighest() throws {
        let g = try guide(five)
        #expect(g.paid == PaidRange(lowerQuartile: 550, highest: 900, count: 5))
        #expect(g.shown == .range(low: 550, high: 900, setBy: .tierHighest))
        #expect(g.basis == .derived)
    }

    @Test func threeWagesAreTheFewestAndTwoGiveNoRange() throws {
        #expect(try guide(three).paid == PaidRange(lowerQuartile: 500, highest: 700, count: 3))
        let g = try guide(two)
        #expect(g.paid == nil)
        #expect(g.shown == .none)
    }

    @Test func excludingAnEarnerLeavesHimOutOnlyWhenHeIsThere() throws {
        let nine = wage("Nine", 0).player
        let without = try guide(five, excluding: nine)
        #expect(without.paid?.highest == 800)
        #expect(without.leavesHimOut)
        let stranger = try guide(five, excluding: wage("Stranger", 0).player)
        #expect(stranger.paid?.highest == 900)
        #expect(!stranger.leavesHimOut)
    }

    @Test func aBudgetSetsACeilingBelowTheTiersHighest() throws {
        let second = try guide(five, limits: WageLimits(wageBudgetPerWeek: 20_000))
        #expect(second.ceilingPerWeek == 540)
        #expect(second.shown == .upTo(540, setBy: .ceiling))
        #expect(second.starterSharePerWeek == nil)
        let first = try guide([.firstEleven: []], tier: .firstEleven, limits: WageLimits(wageBudgetPerWeek: 20_000))
        #expect(first.ceilingPerWeek == 1_500)
        #expect(first.starterSharePerWeek == 860)
    }

    @Test func aCeilingInsideTheRangeCutsItsTop() throws {
        let g = try guide(five, limits: WageLimits(wageBudgetPerWeek: 30_000))
        #expect(g.shown == .range(low: 550, high: 810, setBy: .ceiling))
    }

    @Test func theHighestWageCutsTheTopWithNoBudget() throws {
        let g = try guide(five, limits: WageLimits(highestWagePerWeek: 700))
        #expect(g.shown == .range(low: 550, high: 700, setBy: .highestWage))
    }

    @Test func aTieGoesToTheTierHighestThenTheCeiling() throws {
        let g = try guide(five, limits: WageLimits(wageBudgetPerWeek: 20_000, highestWagePerWeek: 540))
        #expect(g.shown == .upTo(540, setBy: .ceiling))
        let t = try guide(five, limits: WageLimits(highestWagePerWeek: 900))
        #expect(t.shown == .range(low: 550, high: 900, setBy: .tierHighest))
    }

    @Test func withTooFewWagesTheCeilingAloneSpeaksAndTheHighestWageAloneDoesNot() throws {
        #expect(try guide(two, limits: WageLimits(wageBudgetPerWeek: 20_000)).shown == .upTo(540, setBy: .ceiling))
        #expect(try guide(two, limits: WageLimits(highestWagePerWeek: 700)).shown == .none)
        #expect(try guide(two, limits: WageLimits(wageBudgetPerWeek: 20_000, highestWagePerWeek: 300)).shown
                == .upTo(300, setBy: .highestWage))
    }

    @Test func theBudgetLeftCountsHisWageBackAndNeverGoesBelowZero() throws {
        let g = try guide(five, present: 600, limits: WageLimits(wageBudgetPerWeek: 20_000, wagesSpentPerWeek: 19_000))
        #expect(g.budgetLeftPerWeek == 1_600)
        #expect(g.countsHisWageBack)
        let over = try guide(five, present: 600, limits: WageLimits(wageBudgetPerWeek: 20_000, wagesSpentPerWeek: 25_000))
        #expect(over.budgetLeftPerWeek == 0)
        let none = try guide(five, limits: WageLimits(wageBudgetPerWeek: 20_000, wagesSpentPerWeek: 19_000))
        #expect(none.budgetLeftPerWeek == 1_000)
        #expect(!none.countsHisWageBack)
        #expect(try guide(five, limits: WageLimits(wageBudgetPerWeek: 20_000)).budgetLeftPerWeek == nil)
    }

    @Test func aSingleWageIsItsOwnRangeWhenOneWageIsEnough() throws {
        var one = parameters
        var rules = one.wageRangeRules.value
        rules.fewestWages = 1
        one.wageRangeRules = Parameter(rules, .derived, source: "test")
        let wages: [WageTier: [PlayerWage]] = [.secondEleven: [wage("Only", 600)]]
        let g = try WageRange.guide(tier: .secondEleven, slot: nil, wages: wages, excluding: nil,
                                    presentWagePerWeek: nil, limits: .none, parameters: one)
        #expect(g.paid == PaidRange(lowerQuartile: 600, highest: 600, count: 1))
        #expect(g.shown == .range(low: 600, high: 600, setBy: .tierHighest))
        #expect(try guide(wages).paid == nil)
    }

    @Test func excludingAnEarnerCanTakeTheTierBelowTheFewest() throws {
        let g = try guide(three, excluding: wage("One", 0).player)
        #expect(g.leavesHimOut)
        #expect(g.paid == nil)
    }

    @Test func badParametersThrow() {
        var bad = parameters
        bad.wageRangeRules = Parameter(WageRangeRules(lastYearMonths: 12, approachMonths: 6, keyPlayerShare: 0.075,
                                                      starterShare: 0.043, backupShare: 0.027, fewestWages: 0),
                                       .derived, source: "test")
        #expect(throws: PlanError.self) {
            try WageRange.guide(tier: .neither, slot: nil, wages: [:], excluding: nil, presentWagePerWeek: nil,
                                limits: .none, parameters: bad)
        }
    }

    // MARK: The verdict

    @Test func aFigureOverEveryLimitSaysSoInOrder() throws {
        let limits = WageLimits(wageBudgetPerWeek: 20_000, wagesSpentPerWeek: 19_800, highestWagePerWeek: 700)
        let g = try guide(five, present: 400, limits: limits)
        #expect(WageRange.verdict(figurePerWeek: 1_000, guide: g, presentWagePerWeek: 400)
                == [.overHighestWage(limit: 700), .overCeiling(ceiling: 540), .aboveTier(highest: 900),
                    .overBudgetLeft(by: 400), .timesPresentWage(2.5)])
    }

    @Test func aFigureEqualToALineIsNotOverIt() throws {
        let g = try guide(five, limits: WageLimits(highestWagePerWeek: 700))
        let verdicts = WageRange.verdict(figurePerWeek: 700, guide: g, presentWagePerWeek: nil)
        #expect(verdicts == [.withinTier])
    }

    @Test func aHighestWageOfZeroIsOverForAnyFigure() throws {
        let g = try guide(five, limits: WageLimits(highestWagePerWeek: 0))
        #expect(WageRange.verdict(figurePerWeek: 1, guide: g, presentWagePerWeek: nil).first == .overHighestWage(limit: 0))
    }

    @Test func withinAndUnderTheTierAndNothingWithoutARange() throws {
        let g = try guide(five)
        #expect(WageRange.verdict(figurePerWeek: 600, guide: g, presentWagePerWeek: nil) == [.withinTier])
        #expect(WageRange.verdict(figurePerWeek: 500, guide: g, presentWagePerWeek: nil) == [.underTier])
        let short = try guide(two)
        #expect(WageRange.verdict(figurePerWeek: 600, guide: short, presentWagePerWeek: nil) == [])
    }

    @Test func aPresentWageOfZeroGivesNoMultiple() throws {
        let g = try guide(five)
        #expect(WageRange.verdict(figurePerWeek: 600, guide: g, presentWagePerWeek: 0) == [.withinTier])
    }

    @Test func theCautionIsTheFirstOfTheThreeOverVerdicts() {
        #expect(WageRange.caution(in: [.withinTier, .overBudgetLeft(by: 5)]) == nil)
        #expect(WageRange.caution(in: [.overCeiling(ceiling: 540), .aboveTier(highest: 900)]) == .overCeiling(ceiling: 540))
        #expect(WageRange.caution(in: [.underTier, .timesPresentWage(2)]) == nil)
    }

    // MARK: Levels

    @Test func theBestLevelWinsThenTheMarginThenTheEarlier() {
        let best = WageRange.bestLevel([(.D_L, .wouldCountAsCover, 0.1), (.D_R, .wouldStart, 0.02), (.D_C, .wouldStart, 0.05)])
        #expect(best?.slot == .D_C)
        #expect(best?.level == .wouldStart)
        let nilMargin = WageRange.bestLevel([(.D_L, .wouldStart, 0.05), (.D_R, .wouldStart, nil)])
        #expect(nilMargin?.slot == .D_R)
        let tie = WageRange.bestLevel([(.D_L, .wouldStart, 0.05), (.D_R, .wouldStart, 0.05)])
        #expect(tie?.slot == .D_L)
        let nilTie = WageRange.bestLevel([(.D_L, .wouldStart, nil), (.D_R, .wouldStart, nil)])
        #expect(nilTie?.slot == .D_L)
        #expect(WageRange.bestLevel([]) == nil)
    }

    @Test func eachLevelHasATier() {
        #expect(WageRange.tier(of: .wouldStart) == .firstEleven)
        #expect(WageRange.tier(of: .wouldMakeSecond) == .secondEleven)
        #expect(WageRange.tier(of: .wouldCountAsCover) == .neither)
        #expect(WageRange.tier(of: .belowCover) == .neither)
    }

    // MARK: Tier wages

    func owned(_ name: String, wage: Double = 500) -> Player {
        var p = Player.fixture(name: name)
        p.wagePerWeek = wage
        return p
    }

    @Test func tierWagesLeaveOutLoansYouthContractsAndNoWage() {
        let first = owned("First", wage: 900), second = owned("Second", wage: 600), backup = owned("Backup", wage: 300)
        let backup2 = owned("Aback", wage: 300)
        let loanedIn = Player.fixture(name: "Loaned In", club: "Other FC")
        let loanedOut = Player.fixture(name: "Loaned Out", loanedTo: "Other FC")
        var youth = owned("Youth"); youth.contractType = .youth
        let unpaid = owned("Unpaid", wage: 0)
        let all = [first, second, backup, backup2, loanedIn, loanedOut, youth, unpaid]
        let tiers = SquadTiers(first: [.GK: first.id], second: [.GK: second.id],
                               ratings: Dictionary(uniqueKeysWithValues: all.map { ($0.id, [SlotID.GK: 1.0]) }))
        let wages = WageRange.tierWages(tiers: tiers, players: all, ownClub: "Oxford City")
        #expect(wages[.firstEleven] == [PlayerWage(player: first.id, perWeek: 900)])
        #expect(wages[.secondEleven] == [PlayerWage(player: second.id, perWeek: 600)])
        #expect(wages[.neither] == [PlayerWage(player: backup2.id, perWeek: 300), PlayerWage(player: backup.id, perWeek: 300)])
        let reversed = WageRange.tierWages(tiers: tiers, players: all.reversed(), ownClub: "Oxford City")
        #expect(reversed == wages)
    }

    @Test func aPlayerTheTiersDidNotRateIsInNoTier() {
        let rated = owned("Rated"), unrated = owned("Unrated")
        let tiers = SquadTiers(first: [:], second: [:], ratings: [rated.id: [.GK: 1.0]])
        let wages = WageRange.tierWages(tiers: tiers, players: [rated, unrated], ownClub: "Oxford City")
        #expect(wages[.neither]?.count == 1)
        #expect(WageRange.tier(of: unrated.id, in: tiers) == nil)
        #expect(WageRange.tier(of: rated.id, in: tiers)?.tier == .neither)
    }

    // MARK: The rules

    @Test func theStandardRulesHaveNoProblemsAndEachBreakageGivesOne() {
        let ok = parameters.wageRangeRules.value
        #expect(WageRange.problems(in: ok).isEmpty)
        func breaking(_ change: (inout WageRangeRules) -> Void) -> [String] {
            var r = ok; change(&r); return WageRange.problems(in: r)
        }
        #expect(breaking { $0.starterShare = 0.1 }.count == 1)
        #expect(breaking { $0.backupShare = 0 }.count >= 1)
        #expect(breaking { $0.fewestWages = 0 }.count == 1)
        #expect(breaking { $0.approachMonths = 13 }.count == 1)
        #expect(breaking { $0.lastYearMonths = 0 }.count >= 1)
        #expect(breaking { $0.keyPlayerShare = .nan }.count >= 1)
    }

    @Test func badRulesAreAFitnessModelProblem() {
        var bad = parameters
        var rules = bad.wageRangeRules.value
        rules.fewestWages = 0
        bad.wageRangeRules = Parameter(rules, .derived, source: "test")
        #expect(!FitnessModel.problems(in: bad).isEmpty)
        #expect(FitnessModel.problems(in: parameters).isEmpty)
    }
}
