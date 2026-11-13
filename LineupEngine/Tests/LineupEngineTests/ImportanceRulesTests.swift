import Testing
@testable import LineupEngine

@Suite struct ImportanceRulesTests {
    let parameters = EngineParameters.fm27
    let date = Day(year: 2026, month: 8, day: 10)!
    let assignments: [SlotAssignment]

    init() throws {
        assignments = try PlannerFixture.tactic().assignments(catalog: RoleCatalog.fm27())
    }

    func context(_ importance: Importance, history: [ConfirmedLineup] = [], tiers: SquadTiers? = nil,
                 retraining: [Retraining] = [], stability: Double = 0, ownClub: String? = "Oxford City") -> RuleContext {
        RuleContext(importance: importance, date: date, assignments: assignments, ownClub: ownClub,
                    history: StartHistory(history), tiers: tiers ?? SquadTiers(first: [:], second: [:], ratings: [:]),
                    retraining: retraining, stability: stability)
    }

    func run(_ player: Player, _ importance: Importance, history: [ConfirmedLineup] = [], tiers: SquadTiers? = nil,
             retraining: [Retraining] = [], stability: Double = 0, ownClub: String? = "Oxford City")
        -> (everySlot: [Adjustment], bySlot: [SlotID: [Adjustment]]) {
        ImportanceRules.adjustments(
            for: player,
            context: context(importance, history: history, tiers: tiers, retraining: retraining, stability: stability, ownClub: ownClub),
            parameters: parameters)
    }

    func every(_ r: (everySlot: [Adjustment], bySlot: [SlotID: [Adjustment]]), _ kind: Adjustment.Kind) -> Adjustment? {
        r.everySlot.first { $0.kind == kind }
    }

    func slot(_ r: (everySlot: [Adjustment], bySlot: [SlotID: [Adjustment]]), _ s: SlotID, _ kind: Adjustment.Kind) -> Adjustment? {
        r.bySlot[s]?.first { $0.kind == kind }
    }

    func starts(_ player: Player, count: Int, spacing: Int = 3, slot: SlotID = .D_L) -> [ConfirmedLineup] {
        (1...count).map { i in
            ConfirmedLineup(fixture: FixtureID("f\(i)"), date: date.adding(days: -spacing * i), starters: [slot: player.id])
        }
    }

    func tiers(_ player: Player, tier: Int, slot: SlotID = .D_L) -> SquadTiers {
        SquadTiers(first: tier == 1 ? [slot: player.id] : [:], second: tier == 2 ? [slot: player.id] : [:], ratings: [:])
    }

    // MARK: Loaned in

    @Test func loanedInPlayersAreMarkedDown() {
        let loanee = Player.fixture(club: "Elsewhere FC")
        let medium = every(run(loanee, .medium), .loanedIn)
        #expect(medium?.factor == 0.95)
        #expect(every(run(loanee, .low), .loanedIn)?.factor == 0.85)
        let sharp = every(run(loanee, .sharpness), .loanedIn)
        #expect(sharp?.factor == 0.85)
        #expect(sharp?.reason == "On loan here: marked down so the club's own players get the minutes (×0.85)")
    }

    @Test func loanedInPlayersAreNotMarkedDownInBigMatches() {
        #expect(every(run(Player.fixture(club: "Elsewhere FC"), .high), .loanedIn) == nil)
    }

    @Test func ownPlayersAndUnknownClubsAreNotMarkedDown() {
        #expect(every(run(Player.fixture(), .low), .loanedIn) == nil)
        #expect(every(run(Player.fixture(club: "Elsewhere FC"), .low, ownClub: nil), .loanedIn) == nil)
    }

    // MARK: Consecutive starts

    @Test func aFullBackNeedsTwoStartsToBeMarkedDown() {
        let p = Player.fixture()
        let r = run(p, .medium, history: starts(p, count: 2))
        #expect(slot(r, .D_L, .consecutiveStarts)?.factor == 0.90)
        #expect(slot(r, .D_R, .consecutiveStarts)?.factor == 0.90)
        #expect(slot(r, .ST_C, .consecutiveStarts) == nil)
        #expect(slot(r, .D_CL, .consecutiveStarts) == nil)
        #expect(run(p, .medium, history: starts(p, count: 1)).bySlot[.D_L]?.isEmpty ?? true)
    }

    @Test func moreStartsMarkDownFurther() {
        let p = Player.fixture()
        let r = run(p, .low, history: starts(p, count: 4))
        #expect(slot(r, .D_L, .consecutiveStarts)?.factor == 0.60)
        #expect(slot(r, .D_L, .consecutiveStarts)?.reason == "Has started the last 4 matches in quick succession (×0.60)")
        #expect(slot(run(p, .low, history: starts(p, count: 3)), .D_L, .consecutiveStarts)?.reason
                == "Has started the last 3 matches in quick succession (×0.75)")
    }

    @Test func aCentreBackNeedsFiveStartsAndAMidfielderThree() {
        let p = Player.fixture()
        #expect(slot(run(p, .sharpness, history: starts(p, count: 4)), .D_CL, .consecutiveStarts) == nil)
        #expect(slot(run(p, .sharpness, history: starts(p, count: 5)), .D_CL, .consecutiveStarts)?.factor == 0.90)
        #expect(slot(run(p, .sharpness, history: starts(p, count: 6)), .D_CL, .consecutiveStarts)?.factor == 0.80)
        #expect(slot(run(p, .sharpness, history: starts(p, count: 3)), .ST_C, .consecutiveStarts)?.factor == 0.90)
        #expect(slot(run(p, .sharpness, history: starts(p, count: 3)), .AM_C, .consecutiveStarts)?.factor == 0.90)
    }

    @Test func consecutiveStartsAreIgnoredInBigMatchesAndWhenSpacedOut() {
        let p = Player.fixture()
        #expect(slot(run(p, .high, history: starts(p, count: 4)), .D_L, .consecutiveStarts) == nil)
        #expect(slot(run(p, .low, history: starts(p, count: 4, spacing: 7)), .D_L, .consecutiveStarts) == nil)
    }

    // MARK: Needs sharpness

    @Test func anUnsharpPlayerIsFavouredInALesserFixture() {
        let p = Player.fixture(sharpness: 0.705)
        let a = every(run(p, .low), .needsSharpness)
        #expect(abs((a?.factor ?? 0) - 1.15) < 1e-9)
        #expect(a?.reason == "Needs minutes: sharpness 70% (×1.15)")
        #expect(abs((every(run(Player.fixture(sharpness: 0.5), .low), .needsSharpness)?.factor ?? 0) - 1.30) < 1e-9)
        #expect(abs((every(run(Player.fixture(sharpness: 0.2), .low), .needsSharpness)?.factor ?? 0) - 1.30) < 1e-9)
        #expect(every(run(Player.fixture(sharpness: 0.91), .low), .needsSharpness) == nil)
        #expect(every(run(Player.fixture(sharpness: 0.62), .low), .needsSharpness)?.reason == "Needs minutes: sharpness 62% (×1.21)")
    }

    @Test func needForSharpnessIsIgnoredAtHighAndMedium() {
        let p = Player.fixture(sharpness: 0.6)
        #expect(every(run(p, .high), .needsSharpness) == nil)
        #expect(every(run(p, .medium), .needsSharpness) == nil)
    }

    @Test func aSharpnessFixtureFavoursOnlyTheElevensWhoNeedIt() {
        let p = Player.fixture(sharpness: 0.705)
        #expect(abs((every(run(p, .sharpness, tiers: tiers(p, tier: 1)), .needsSharpness)?.factor ?? 0) - 1.50) < 1e-9)
        #expect(abs((every(run(p, .sharpness, tiers: tiers(p, tier: 2)), .needsSharpness)?.factor ?? 0) - 1.50) < 1e-9)
        #expect(every(run(p, .sharpness), .needsSharpness) == nil)
    }

    @Test func aSharpPlayerInTheElevensIsHeldBackInASharpnessFixture() {
        let p = Player.fixture(sharpness: 0.95)
        let a = every(run(p, .sharpness, tiers: tiers(p, tier: 1)), .needsSharpness)
        #expect(a?.factor == 0.60)
        #expect(a?.reason == "Already sharp: others need the minutes more (×0.60)")
        #expect(every(run(p, .sharpness), .needsSharpness) == nil)
        #expect(every(run(p, .low, tiers: tiers(p, tier: 1)), .needsSharpness) == nil)
    }

    // MARK: Development

    @Test func aProspectIsFavouredInALesserFixture() {
        let p = Player.fixture(age: 21, currentAbility: 100, potentialAbility: 115)
        for importance in [Importance.low, .sharpness] {
            let a = every(run(p, importance), .development)
            #expect(a?.factor == 1.10)
            #expect(a?.reason == "Young player with room to grow: favoured for minutes (×1.10)")
        }
        #expect(every(run(p, .medium), .development) == nil)
        #expect(every(run(p, .high), .development) == nil)
    }

    @Test func anOlderOrLimitedPlayerIsNotAProspect() {
        #expect(every(run(Player.fixture(age: 22, currentAbility: 100, potentialAbility: 115), .low), .development) == nil)
        #expect(every(run(Player.fixture(age: 21, currentAbility: 100, potentialAbility: 114), .low), .development) == nil)
    }

    // MARK: Retraining

    func retrain(_ p: Player, _ position: Position) -> [Retraining] {
        [Retraining(player: p.id, position: position, acceptedOn: date.adding(days: -30))]
    }

    @Test func aRetraineeIsFavouredAtTheNewPositionOnly() {
        let p = Player.fixture(familiarity: [.defenderLeft: 12])
        let r = run(p, .low, retraining: retrain(p, .defenderLeft))
        #expect(slot(r, .D_L, .retraining)?.factor == 1.15)
        #expect(slot(r, .D_L, .retraining)?.reason == "Retraining at D (L) (familiarity 12): favoured for match experience there (×1.15)")
        #expect(slot(r, .D_R, .retraining) == nil)
        #expect(slot(run(p, .sharpness, retraining: retrain(p, .defenderLeft)), .D_L, .retraining)?.factor == 1.15)
    }

    @Test func theMediumBandStartsHigher() {
        func factor(_ f: Int, _ importance: Importance = .medium) -> Double? {
            let p = Player.fixture(familiarity: [.defenderLeft: f])
            return slot(run(p, importance, retraining: retrain(p, .defenderLeft)), .D_L, .retraining)?.factor
        }
        #expect(factor(14) == nil)
        #expect(factor(15) == 1.08)
        #expect(factor(17) == 1.08)
        #expect(factor(18) == nil)
        #expect(factor(9, .low) == nil)
        #expect(factor(10, .low) == 1.15)
        #expect(factor(17, .low) == 1.15)
        #expect(factor(18, .low) == nil)
        #expect(factor(12, .high) == nil)
    }

    @Test func anOutOfPossessionPositionCounts() {
        let p = Player.fixture(familiarity: [.midfielderLeft: 12])
        let r = run(p, .low, retraining: retrain(p, .midfielderLeft))
        #expect(slot(r, .AM_L, .retraining)?.factor == 1.15)
        #expect(r.bySlot.filter { !$0.value.isEmpty }.keys.sorted { $0.rawValue < $1.rawValue } == [.AM_L])
    }

    @Test func aRetrainingNoSlotUsesGivesNothing() {
        let p = Player.fixture(familiarity: [.wingBackLeft: 12])
        let r = run(p, .low, retraining: retrain(p, .wingBackLeft))
        #expect(r.bySlot.values.allSatisfy { $0.isEmpty })
        let other = Player.fixture(name: "Other", familiarity: [.defenderLeft: 12])
        #expect(slot(run(other, .low, retraining: retrain(p, .defenderLeft)), .D_L, .retraining) == nil)
    }

    // MARK: Stability

    @Test func playingTheSlotLastMatchEarnsASmallBonus() {
        let p = Player.fixture()
        let r = run(p, .medium, history: starts(p, count: 1), stability: 0.5)
        #expect(abs((slot(r, .D_L, .stability)?.factor ?? 0) - 1.01) < 1e-9)
        #expect(slot(r, .D_L, .stability)?.reason == "Held this slot in his last start (×1.01)")
        #expect(slot(r, .D_R, .stability) == nil)
    }

    @Test func threeInARowEarnsMore() {
        let p = Player.fixture()
        let r = run(p, .medium, history: starts(p, count: 3), stability: 0.5)
        #expect(abs((slot(r, .D_L, .stability)?.factor ?? 0) - 1.025) < 1e-9)
        #expect(slot(r, .D_L, .stability)?.reason == "Has held this slot in his last 3 starts (×1.02)")
        let mixed = starts(p, count: 2) + [ConfirmedLineup(fixture: FixtureID("old"), date: date.adding(days: -9), starters: [.D_R: p.id])]
        #expect(abs((slot(run(p, .medium, history: mixed, stability: 0.5), .D_L, .stability)?.factor ?? 0) - 1.01) < 1e-9)
    }

    @Test func theAnchorReasonCountsTheStartsTheParameterNames() {
        var two = EngineParameters.fm27
        two.stabilityAnchorRun = Parameter(2, .derived, source: "test")
        let p = Player.fixture()
        let r = ImportanceRules.adjustments(for: p, context: context(.medium, history: starts(p, count: 2), stability: 0.5),
                                            parameters: two)
        #expect(slot(r, .D_L, .stability)?.reason == "Has held this slot in his last 2 starts (×1.02)")
    }

    @Test func noStabilityMeansNoBonusAndHighImportanceStillGetsIt() {
        let p = Player.fixture()
        #expect(slot(run(p, .medium, history: starts(p, count: 3), stability: 0), .D_L, .stability) == nil)
        #expect(slot(run(p, .high, history: starts(p, count: 1), stability: 1), .D_L, .stability) != nil)
    }

    // MARK: Order and quiet

    @Test func adjustmentsComeBackInKindOrder() {
        let p = Player.fixture(age: 20, familiarity: [.defenderLeft: 12], currentAbility: 100, potentialAbility: 130,
                               sharpness: 0.6, club: "Elsewhere FC")
        let r = run(p, .low, history: starts(p, count: 4), retraining: retrain(p, .defenderLeft), stability: 1)
        #expect(r.everySlot.map(\.kind) == [.loanedIn, .needsSharpness, .development])
        #expect(r.bySlot[.D_L]?.map(\.kind) == [.consecutiveStarts, .retraining, .stability])
    }

    @Test func aPlayerWithNothingSpecialHasNoAdjustments() {
        let r = run(Player.fixture(), .low)
        #expect(r.everySlot.isEmpty)
        #expect(r.bySlot.values.allSatisfy { $0.isEmpty })
    }

    @Test func missingTableEntriesGiveNoAdjustment() {
        var q = parameters
        q.loanedInFactor = Parameter([:], .derived, source: "test")
        q.consecutiveStartSteps = Parameter([:], .derived, source: "test")
        let p = Player.fixture(club: "Elsewhere FC")
        let r = ImportanceRules.adjustments(for: p, context: context(.low, history: starts(p, count: 4)), parameters: q)
        #expect(r.everySlot.isEmpty)
        #expect(r.bySlot.values.allSatisfy { $0.isEmpty })
    }

    @Test func theTablesHaveNoProblemsAndMissingEntriesAreReported() {
        #expect(FitnessModel.problems(in: parameters).isEmpty)
        var q = parameters
        var loaned = q.loanedInFactor.value
        loaned[.low] = nil
        q.loanedInFactor = Parameter(loaned, .derived, source: "test")
        var steps = q.consecutiveStartSteps.value
        steps[.striker] = nil
        q.consecutiveStartSteps = Parameter(steps, .derived, source: "test")
        let found = FitnessModel.problems(in: q)
        #expect(found.contains { $0.contains("loanedInFactor") && $0.contains("low") })
        #expect(found.contains { $0.contains("consecutiveStartSteps") && $0.contains("ST (C)") })
    }
}
