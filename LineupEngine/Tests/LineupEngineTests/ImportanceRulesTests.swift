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

    /// One start per slot, newest first, `spacing` days apart, the newest `spacing` days before the fixture.
    func run(_ player: Player, newestFirst slots: [SlotID], spacing: Int = 3) -> [ConfirmedLineup] {
        slots.enumerated().map { i, slot in
            ConfirmedLineup(fixture: FixtureID("f\(i + 1)"), date: date.adding(days: -spacing * (i + 1)), starters: [slot: player.id])
        }
    }

    func noSlotHasAConsecutiveStartsAdjustment(_ r: (everySlot: [Adjustment], bySlot: [SlotID: [Adjustment]])) -> Bool {
        r.bySlot.values.allSatisfy { !$0.contains { $0.kind == .consecutiveStarts } }
    }

    @Test func aRunAtFullBackMarksHimDownInEverySlot() {
        let p = Player.fixture()
        let r = run(p, .medium, history: starts(p, count: 2))
        #expect(every(r, .consecutiveStarts)?.factor == 0.90)
        #expect(every(r, .consecutiveStarts)?.reason == "Has started the last 2 matches in quick succession (×0.90)")
        #expect(noSlotHasAConsecutiveStartsAdjustment(r))
        // More starts mark him down further.
        #expect(every(run(p, .low, history: starts(p, count: 3)), .consecutiveStarts)?.reason
                == "Has started the last 3 matches in quick succession (×0.75)")
        let four = run(p, .low, history: starts(p, count: 4))
        #expect(every(four, .consecutiveStarts)?.factor == 0.60)
        #expect(every(four, .consecutiveStarts)?.reason == "Has started the last 4 matches in quick succession (×0.60)")
        #expect(noSlotHasAConsecutiveStartsAdjustment(four))
        // One start is not a run.
        #expect(every(run(p, .medium, history: starts(p, count: 1)), .consecutiveStarts) == nil)
    }

    @Test func aRunAtCentreBackNeedsFiveStarts() {
        let p = Player.fixture()
        #expect(every(run(p, .sharpness, history: starts(p, count: 4, slot: .D_CL)), .consecutiveStarts) == nil)
        #expect(every(run(p, .sharpness, history: starts(p, count: 5, slot: .D_CL)), .consecutiveStarts)?.factor == 0.90)
        #expect(every(run(p, .sharpness, history: starts(p, count: 6, slot: .D_CL)), .consecutiveStarts)?.factor == 0.80)
        // A midfielder or a striker needs three.
        #expect(every(run(p, .sharpness, history: starts(p, count: 2, slot: .AM_C)), .consecutiveStarts) == nil)
        #expect(every(run(p, .sharpness, history: starts(p, count: 3, slot: .AM_C)), .consecutiveStarts)?.factor == 0.90)
        #expect(every(run(p, .sharpness, history: starts(p, count: 3, slot: .ST_C)), .consecutiveStarts)?.factor == 0.90)
    }

    @Test func theMostDemandingPositionOfTheRunDecides() {
        let p = Player.fixture()
        // D_L, then ST_C twice: three starts are ×0.75 at full back and ×0.90 up front.
        let mixed = run(p, .medium, history: run(p, newestFirst: [.ST_C, .ST_C, .D_L]))
        #expect(every(mixed, .consecutiveStarts)?.factor == 0.75)
        #expect(every(mixed, .consecutiveStarts)?.reason == "Has started the last 3 matches in quick succession (×0.75)")
        #expect(noSlotHasAConsecutiveStartsAdjustment(mixed))
        #expect(every(run(p, .medium, history: run(p, newestFirst: [.ST_C, .ST_C, .ST_C])), .consecutiveStarts)?.factor == 0.90)
        // A position whose steps the run has not reached adds nothing: two starts are a step at full back only.
        #expect(every(run(p, .medium, history: run(p, newestFirst: [.D_CL, .D_L])), .consecutiveStarts)?.factor == 0.90)
        #expect(every(run(p, .medium, history: run(p, newestFirst: [.D_CL, .ST_C])), .consecutiveStarts) == nil)
        // Starts before the run do not count: a full-back start a week before two striker starts.
        let broken = run(p, newestFirst: [.ST_C, .ST_C])
            + [ConfirmedLineup(fixture: FixtureID("old"), date: date.adding(days: -13), starters: [.D_L: p.id])]
        #expect(every(run(p, .medium, history: broken), .consecutiveStarts) == nil)
        // A position missing from the table adds nothing; the others still count.
        var q = parameters
        var steps = q.consecutiveStartSteps.value
        steps[.defenderLeft] = nil
        q.consecutiveStartSteps = Parameter(steps, .derived, source: "test")
        let withoutFullBack = ImportanceRules.adjustments(
            for: p, context: context(.medium, history: run(p, newestFirst: [.ST_C, .ST_C, .D_L])), parameters: q)
        #expect(every(withoutFullBack, .consecutiveStarts)?.factor == 0.90)
        let onlyFullBack = ImportanceRules.adjustments(
            for: p, context: context(.medium, history: run(p, newestFirst: [.D_L, .D_L, .D_L])), parameters: q)
        #expect(every(onlyFullBack, .consecutiveStarts) == nil)
    }

    @Test func nothingAtHigh() {
        let p = Player.fixture()
        let r = run(p, .high, history: starts(p, count: 4))
        #expect(every(r, .consecutiveStarts) == nil)
        #expect(noSlotHasAConsecutiveStartsAdjustment(r))
    }

    @Test func nothingWhenTheStartsWereAWeekApart() {
        let p = Player.fixture()
        let r = run(p, .low, history: starts(p, count: 4, spacing: 7))
        #expect(every(r, .consecutiveStarts) == nil)
        #expect(noSlotHasAConsecutiveStartsAdjustment(r))
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

    @Test func aPotentialExactlyAtTheHeadroomCountsDespiteRounding() {
        // 1.10 × 100 is 110.00000000000001 in binary floating point.
        var q = parameters
        q.prospectHeadroom = Parameter(1.10, .derived, source: "test")
        let context = context(.low)
        let exact = Player.fixture(age: 21, currentAbility: 100, potentialAbility: 110)
        #expect(ImportanceRules.adjustments(for: exact, context: context, parameters: q).everySlot.map(\.kind) == [.development])
        let below = Player.fixture(age: 21, currentAbility: 100, potentialAbility: 109)
        #expect(ImportanceRules.adjustments(for: below, context: context, parameters: q).everySlot.isEmpty)
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

    @Test func retrainingAtBothPositionsOfASlotCountsOnce() {
        // AM_L is AM (L) in possession and M (L) out of possession. Both factors are 1.15: the lower position wins.
        let p = Player.fixture(familiarity: [.attackingMidLeft: 12, .midfielderLeft: 14])
        let both = retrain(p, .midfielderLeft) + retrain(p, .attackingMidLeft)
        let expected = [Adjustment(kind: .retraining, factor: 1.15,
                                   reason: "Retraining at AM (L) (familiarity 12): favoured for match experience there (×1.15)")]
        #expect(run(p, .low, retraining: both).bySlot[.AM_L] == expected)
        #expect(run(p, .low, retraining: both.reversed()).bySlot[.AM_L] == expected)
        // When only one of the two is still being learnt, that one counts.
        let learnt = Player.fixture(familiarity: [.attackingMidLeft: 18, .midfielderLeft: 14])
        #expect(run(learnt, .low, retraining: both).bySlot[.AM_L]?.map(\.reason)
            == ["Retraining at M (L) (familiarity 14): favoured for match experience there (×1.15)"])
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
        #expect(r.everySlot.map(\.kind) == [.loanedIn, .consecutiveStarts, .needsSharpness, .development])
        #expect(r.bySlot[.D_L]?.map(\.kind) == [.retraining, .stability])
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
