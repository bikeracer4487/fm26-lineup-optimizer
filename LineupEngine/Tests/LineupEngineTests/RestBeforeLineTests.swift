import Foundation
import Testing
@testable import LineupEngine

/// The rule that rests a player before he passes the jaded line, on `PlannerFixture`'s squad.
@Suite struct RestBeforeLineTests {
    let parameters = EngineParameters.fm27
    let today = Day(year: 2026, month: 11, day: 14)!
    let tactic: Tactic
    let squad: [Player]
    let tiers: SquadTiers
    /// Falls 2 a day without a start, and a start adds 60.
    let falling = JadednessRates(drift: MeasuredRate(-2, .own(intervals: 5)), gain: MeasuredRate(60, .own(intervals: 5)))

    init() throws {
        tactic = try PlannerFixture.tactic()
        squad = try PlannerFixture.squad()
        tiers = try SquadTiers.compute(tactic: tactic, players: squad, ownClub: "Oxford City", catalog: RoleCatalog.fm27(),
                                       profile: RatingProfile.standard(), parameters: .fm27)
    }

    var advantage: Double { tiers.advantage(of: PlannerFixture.id(.ST_C, "first"))! }

    func player(_ slot: SlotID, _ tier: String = "first") -> Player {
        squad.first { $0.id == PlannerFixture.id(slot, tier) }!
    }

    func fixture(_ id: String, _ importance: Importance, inDays days: Int, opponent: String? = nil,
                 rejected: Set<PlayerID> = []) -> Fixture {
        Fixture(id: FixtureID(id), date: today.adding(days: days), opponent: opponent ?? "Opponent \(id)",
                importance: importance, tactic: tactic, rejected: rejected)
    }

    func later(_ id: String, _ importance: Importance, inDays days: Int, opponent: String? = nil,
               rejected: Set<PlayerID> = []) -> LaterFixture {
        LaterFixture(fixture: fixture(id, importance, inDays: days, opponent: opponent, rejected: rejected), tiers: tiers)
    }

    /// A medium fixture in 7 days, and Buxton, medium, in 14.
    func twoMedium(rejectedFromA: Set<PlayerID> = []) -> [LaterFixture] {
        [later("a", .medium, inDays: 7, rejected: rejectedFromA), later("b", .medium, inDays: 14, opponent: "Buxton")]
    }

    func rest(_ player: Player, jadedness: Double, today importance: Importance = .low, _ later: [LaterFixture],
              rates: JadednessRates?, settings: PlanSettings = .standard, parameters: EngineParameters? = nil) -> RestDue? {
        RestBeforeLine.adjustment(for: player, jadedness: jadedness, today: fixture("today", importance, inDays: 0),
                                  later: later, rates: rates, settings: settings, parameters: parameters ?? self.parameters)
    }

    func rates(drift: Double, gain: Double) -> JadednessRates {
        JadednessRates(drift: MeasuredRate(drift, .own(intervals: 5)), gain: MeasuredRate(gain, .own(intervals: 5)))
    }

    // MARK: - The rule

    @Test func startingTodayWouldLeaveHimJadedForANamedFixture() throws {
        // Starting: 390, 376 before A, 436 after it, 422 before Buxton. Resting: 330, 316, 376, 362.
        let due = try #require(rest(player(.ST_C), jadedness: 330, twoMedium(), rates: falling))
        #expect(due.fixture == FixtureID("b"))
        #expect(abs(due.adjustment.cost - advantage * 1.5 / 0.8) < 1e-9)
        #expect(due.adjustment.kind == .restedBeforeLine)
        #expect(due.adjustment.factor == 1)
        #expect(due.adjustment.reason == "Rested before he passes 400: at about +60 a start, starting today would leave him "
            + "jaded for Buxton on \(AdvisorText.shortDay(today.adding(days: 14)))")
    }

    @Test func theCostIsWeightedByHowMuchEachFixtureMatters() throws {
        let low = try #require(rest(player(.ST_C), jadedness: 330, today: .low, twoMedium(), rates: falling))
        let medium = try #require(rest(player(.ST_C), jadedness: 330, today: .medium, twoMedium(), rates: falling))
        #expect(abs(medium.adjustment.cost - advantage * 1.5 / 1.5) < 1e-9)
        // Starting him costs more in the low fixture, so that is where the plan rests him.
        #expect(low.adjustment.cost > medium.adjustment.cost)
    }

    @Test func noCostWhenAMatchOffDoesNotSaveHim() {
        // Starting: 400, then 421 before the fixture. Resting: 380, then 401: above the line either way.
        #expect(rest(player(.ST_C), jadedness: 380, [later("a", .medium, inDays: 7)], rates: rates(drift: 3, gain: 20)) == nil)
    }

    @Test func noCostWhenTheFixtureHeWouldMissIsHighImportance() {
        // Starting leaves him at 426 before it, but a jaded player still plays a high-importance match.
        #expect(rest(player(.ST_C), jadedness: 380, [later("a", .high, inDays: 7)], rates: falling) == nil)
        // The same fixture at medium importance costs.
        #expect(rest(player(.ST_C), jadedness: 380, [later("a", .medium, inDays: 7)], rates: falling) != nil)
    }

    @Test func noCostWhenHeNeverPassesTheLine() {
        #expect(rest(player(.ST_C), jadedness: 100, twoMedium(), rates: falling) == nil)
    }

    @Test func noCostWithSavingPlayersOff() throws {
        #expect(rest(player(.ST_C), jadedness: 330, twoMedium(), rates: falling, settings: PlanSettings(savingPlayers: 0)) == nil)
        let half = try #require(rest(player(.ST_C), jadedness: 330, twoMedium(), rates: falling,
                                     settings: PlanSettings(savingPlayers: 0.5)))
        #expect(abs(half.adjustment.cost - advantage * 1.5 / 0.8 / 2) < 1e-9)
    }

    @Test func noCostForAPlayerWithNoMeasuredRates() {
        #expect(rest(player(.ST_C), jadedness: 330, twoMedium(), rates: nil) == nil)
    }

    @Test func noCostWhenHeIsNotFirstChoiceThere() {
        #expect(rest(player(.ST_C, "second"), jadedness: 330, twoMedium(), rates: falling) == nil)
    }

    @Test func aFixtureHeIsRejectedForIsOneHeDoesNotStart() {
        let p = player(.ST_C)
        // He takes no match at A: starting is 376 before A and 362 before Buxton.
        #expect(rest(p, jadedness: 330, twoMedium(rejectedFromA: [p.id]), rates: falling) == nil)
        // Another player's rejection changes nothing.
        #expect(rest(p, jadedness: 330, twoMedium(rejectedFromA: [PlannerFixture.id(.D_L, "first")]), rates: falling) != nil)
    }

    @Test func aFixtureHeIsRejectedForCannotBeTheOneHeIsSavedFor() {
        let p = player(.ST_C)
        // Starting leaves him at 426 before A, but he will not play A: nothing to save him for.
        #expect(rest(p, jadedness: 380, [later("a", .medium, inDays: 7, rejected: [p.id])], rates: falling) == nil)
    }

    @Test func theFixtureAfterOneHeIsRejectedForCanBe() throws {
        let p = player(.ST_C)
        // He takes no match at A: starting is 426 before A and 412 before Buxton, resting 366 and 352.
        let fixtures = [later("a", .medium, inDays: 7, rejected: [p.id]), later("b", .medium, inDays: 14, opponent: "Buxton")]
        let due = try #require(rest(p, jadedness: 380, fixtures, rates: falling))
        #expect(due.fixture == FixtureID("b"))
        #expect(abs(due.adjustment.cost - advantage * 1.5 / 0.8) < 1e-9)
        #expect(due.adjustment.reason.hasSuffix("jaded for Buxton on \(AdvisorText.shortDay(today.adding(days: 14)))"))
    }

    @Test func noCostWhenTodaysFixtureRejectsHim() {
        let p = player(.ST_C)
        let rejected = RestBeforeLine.adjustment(
            for: p, jadedness: 330, today: fixture("today", .low, inDays: 0, rejected: [p.id]), later: twoMedium(),
            rates: falling, settings: .standard, parameters: parameters)
        #expect(rejected == nil)
    }

    @Test func noCostWhenTodayHasNoUsableWeight() {
        var weightless = parameters
        weightless.importanceWeights = Parameter([.high: 3.0, .medium: 1.5, .low: 0, .sharpness: 0.1], .derived, source: "test")
        #expect(rest(player(.ST_C), jadedness: 330, twoMedium(), rates: falling, parameters: weightless) == nil)
    }

    @Test func noCostWhenAStartLooksAsIfItLowersJadedness() {
        // In 14 days: with gain 0 both are at 409; with gain −5 starting is at 404 and resting at 409.
        let fixtures = [later("a", .medium, inDays: 14)]
        #expect(rest(player(.ST_C), jadedness: 395, fixtures, rates: rates(drift: 1, gain: -5)) == nil)
        #expect(rest(player(.ST_C), jadedness: 395, fixtures, rates: rates(drift: 1, gain: 0)) == nil)
    }

    @Test func theCostIsCapped() throws {
        var capped = parameters
        capped.savingCostCeiling = Parameter(1, .derived, source: "test")
        let due = try #require(rest(player(.ST_C), jadedness: 330, twoMedium(), rates: falling,
                                    settings: PlanSettings(savingPlayers: 10), parameters: capped))
        #expect(due.adjustment.cost == 1)
    }

    @Test func fixturesInAnyOrderGiveTheSameResult() {
        let inOrder = rest(player(.ST_C), jadedness: 330, twoMedium(), rates: falling)
        #expect(inOrder != nil)
        #expect(rest(player(.ST_C), jadedness: 330, twoMedium().reversed(), rates: falling) == inOrder)
    }

    @Test func aFixtureOnOrBeforeTodayIsLeftOut() {
        // A fixture dated today, which would otherwise be M, is not one after today.
        #expect(rest(player(.ST_C), jadedness: 380, [later("same", .medium, inDays: 0)], rates: falling) == nil)
    }

    // MARK: - The saving rule's fixture

    @Test func theSavingRuleNamesItsFixtureAndHowItsLossCame() throws {
        let wide = try PlannerFixture.squad(first: 16, second: 6)
        let wideTiers = try SquadTiers.compute(tactic: tactic, players: wide, ownClub: "Oxford City", catalog: RoleCatalog.fm27(),
                                               profile: RatingProfile.standard(), parameters: .fm27)
        var p = wide.first { $0.id == PlannerFixture.id(.ST_C, "first") }!
        p.jadedness = 350
        let position = try tactic.assignments(catalog: RoleCatalog.fm27()).first { $0.slot == .ST_C }!.ipPosition
        let measured = rates(drift: -2, gain: 120)
        let m = LaterFixture(fixture: fixture("m", .medium, inDays: 7), tiers: wideTiers)
        // Starting leaves him at 456 before it, resting at 336: the start breaks the jaded rule.
        let broke = try #require(try SavingPlayers.assessment(
            for: p, fitness: ProjectedFitness(p), position: position, today: fixture("today", .low, inDays: 0),
            later: [m], rates: measured, settings: .standard, parameters: parameters))
        #expect(broke.named == FixtureID("m"))
        #expect(broke.brokeRiskRule)
        #expect(try SavingPlayers.adjustment(
            for: p, fitness: ProjectedFitness(p), position: position, today: fixture("today", .low, inDays: 0),
            later: [m], rates: measured, settings: .standard, parameters: parameters) == broke.adjustment)
        // With the fixed figures he is nowhere near 400: the loss is the fall in his factors.
        let fell = try #require(try SavingPlayers.assessment(
            for: p, fitness: ProjectedFitness(p), position: position, today: fixture("today", .low, inDays: 0),
            later: [m], rates: nil, settings: .standard, parameters: parameters))
        #expect(fell.named == FixtureID("m"))
        #expect(!fell.brokeRiskRule)
    }
}
