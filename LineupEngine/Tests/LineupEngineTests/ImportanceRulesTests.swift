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
                 retraining: [Retraining] = [], marks: [PlayerID: SaleMark] = [:], stability: Double = 0,
                 ownClub: String? = "Oxford City", outlooks: [PlayerID: Outlook] = [:],
                 development: Double = 1, successorsFavoured: Set<PlayerID>? = nil,
                 advisedToLeave: Set<PlayerID> = []) -> RuleContext {
        RuleContext(importance: importance, date: date, assignments: assignments, ownClub: ownClub,
                    history: StartHistory(history), tiers: tiers ?? SquadTiers(first: [:], second: [:], ratings: [:]),
                    retraining: retraining, marks: marks, stability: stability, outlooks: outlooks,
                    development: development, successorsFavoured: successorsFavoured, advisedToLeave: advisedToLeave)
    }

    func run(_ player: Player, _ importance: Importance, history: [ConfirmedLineup] = [], tiers: SquadTiers? = nil,
             retraining: [Retraining] = [], marks: [PlayerID: SaleMark] = [:], stability: Double = 0,
             ownClub: String? = "Oxford City", outlooks: [PlayerID: Outlook] = [:], development: Double = 1,
             successorsFavoured: Set<PlayerID>? = nil, advisedToLeave: Set<PlayerID> = [],
             parameters: EngineParameters? = nil)
        -> (everySlot: [Adjustment], bySlot: [SlotID: [Adjustment]]) {
        ImportanceRules.adjustments(
            for: player,
            context: context(importance, history: history, tiers: tiers, retraining: retraining, marks: marks,
                             stability: stability, ownClub: ownClub, outlooks: outlooks, development: development,
                             successorsFavoured: successorsFavoured, advisedToLeave: advisedToLeave),
            parameters: parameters ?? self.parameters)
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
        // A regular: in the first eleven, as the rule asks since 22 November 2026.
        func need(_ sharpness: Double) -> Adjustment? {
            let p = Player.fixture(sharpness: sharpness)
            return every(run(p, .low, tiers: tiers(p, tier: 1)), .needsSharpness)
        }
        let a = need(0.705)
        #expect(abs((a?.factor ?? 0) - 1.25) < 1e-9)
        #expect(a?.reason == "Needs minutes: sharpness 70% (×1.25)")
        #expect(abs((need(0.5)?.factor ?? 0) - 1.50) < 1e-9)
        #expect(abs((need(0.2)?.factor ?? 0) - 1.50) < 1e-9)
        #expect(need(0.91) == nil)
        #expect(need(0.62)?.reason == "Needs minutes: sharpness 62% (×1.35)")
    }

    /// The favour is for an unsharp regular. A player who is unsharp because he never plays is in neither eleven and
    /// gets none, however unsharp he is.
    @Test func aLowFixtureFavoursOnlyTheElevensWhoNeedMinutes() {
        let p = Player.fixture(sharpness: 0.705)
        #expect(abs((every(run(p, .low, tiers: tiers(p, tier: 1)), .needsSharpness)?.factor ?? 0) - 1.25) < 1e-9)
        #expect(abs((every(run(p, .low, tiers: tiers(p, tier: 2)), .needsSharpness)?.factor ?? 0) - 1.25) < 1e-9)
        #expect(every(run(p, .low), .needsSharpness) == nil)
        #expect(every(run(Player.fixture(sharpness: 0.46), .low), .needsSharpness) == nil)
        // Another player's place in the elevens is not his.
        let other = Player.fixture(name: "Somebody Else", sharpness: 0.95)
        #expect(every(run(p, .low, tiers: tiers(other, tier: 1)), .needsSharpness) == nil)
    }

    /// As in a sharpness fixture, a successor the fixture favours counts as in the elevens for the favour.
    @Test func aFavouredSuccessorOutsideTheElevensStillNeedsMinutesInALowFixture() {
        let unsharp = Player.fixture(age: 19, attributes: [.professionalism: 15], currentAbility: 100, potentialAbility: 130,
                                     sharpness: 0.705)
        let need = every(run(unsharp, .low, outlooks: outlooks(unsharp, .couldPassFirst, slots: [at(.D_L, .onCourse)])),
                         .needsSharpness)
        #expect(abs((need?.factor ?? 0) - 1.25) < 1e-9)
        #expect(need?.reason == "Needs minutes: sharpness 70% (×1.25)")
        // No successor and in neither eleven: nothing.
        #expect(every(run(unsharp, .low, outlooks: outlooks(unsharp, .couldMakeSecond, slots: [at(.D_L, .possible)])),
                      .needsSharpness) == nil)
        // A sharp successor needs no minutes, and a low fixture marks nobody down for being sharp.
        let sharp = Player.fixture(age: 19, attributes: [.professionalism: 15], currentAbility: 100, potentialAbility: 130,
                                   sharpness: 0.95)
        #expect(every(run(sharp, .low, outlooks: outlooks(sharp, .couldPassFirst, slots: [at(.D_L, .onCourse)])),
                      .needsSharpness) == nil)
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

    /// A young player with Professionalism `professionalism`.
    func young(_ age: Int, professionalism: Int = 15, current: Int = 100, potential: Int = 130) -> Player {
        Player.fixture(age: age, attributes: [.professionalism: professionalism], currentAbility: current,
                       potentialAbility: potential)
    }

    /// An outlook for `player` at `level`, as the planner hands the rules one: its estimate carries his age, abilities
    /// and Professionalism. With no slots given, the slots he can play are left back and striker, each with Smith as
    /// first choice and a band that makes him nobody's successor; he cannot play any other slot.
    func outlook(_ player: Player, _ level: ReachLevel? = .couldMakeSecond, slots: [SlotOutlook]? = nil) -> Outlook {
        let estimate = ReachEstimate(
            age: player.age, current: player.currentAbility, potential: player.potentialAbility,
            professionalism: player.attributes[.professionalism]!, ambition: 10, determination: 10, seasonGrowth: 10,
            bySeason: [Double(player.currentAbility), Double(player.potentialAbility)], reachesPotential: true,
            ambitionSlows: false, determinationSlows: false, professionalismHoldsBack: false,
            growthFallsLater: true)
        return Outlook(player: player.id, estimate: estimate, slots: slots ?? playable(.D_L, .ST_C), best: nil,
                       level: level, average: nil)
    }

    func outlooks(_ player: Player, _ level: ReachLevel? = .couldMakeSecond, slots: [SlotOutlook]? = nil) -> [PlayerID: Outlook] {
        [player.id: outlook(player, level, slots: slots)]
    }

    /// Slots he can play where he is neither first choice nor a successor: Smith is first choice and his band is possible.
    func playable(_ slots: SlotID...) -> [SlotOutlook] {
        slots.map { at($0, .possible) }
    }

    /// The floor's factor: the same development adjustment at the two slots he can play (left back and striker), none at
    /// a slot he cannot play (goalkeeper, right back), and none in the every-slot list. nil when he has none.
    func floorFactor(_ r: (everySlot: [Adjustment], bySlot: [SlotID: [Adjustment]]),
               sourceLocation: SourceLocation = #_sourceLocation) -> Double? {
        #expect(every(r, .development) == nil, sourceLocation: sourceLocation)
        #expect(slot(r, .GK, .development) == nil, sourceLocation: sourceLocation)
        #expect(slot(r, .D_R, .development) == nil, sourceLocation: sourceLocation)
        let left = slot(r, .D_L, .development), striker = slot(r, .ST_C, .development)
        #expect(left == striker, sourceLocation: sourceLocation)
        return left?.factor
    }

    @Test func theFloorIsOnlyAtTheSlotsHeCanPlay() {
        let p = young(19)
        // At the slots his outlook lists, and nowhere else.
        let r = run(p, .low, outlooks: outlooks(p, slots: playable(.D_L, .AM_C)))
        #expect(slot(r, .D_L, .development)?.factor == 1.07)
        #expect(slot(r, .AM_C, .development)?.factor == 1.07)
        for other in [SlotID.GK, .ST_C, .D_R, .DM_L] {
            #expect(slot(r, other, .development) == nil, "\(other)")
        }
        // An outlook with no slots gives no floor anywhere.
        let none = run(p, .low, outlooks: outlooks(p, slots: []))
        #expect(none.everySlot.isEmpty)
        #expect(none.bySlot.values.allSatisfy { $0.isEmpty })
        // A slot he is first choice at is one he can play.
        let home = run(p, .low, outlooks: outlooks(p, nil, slots: [at(.D_L, nil, isFirstChoice: true)]))
        #expect(slot(home, .D_L, .development)?.factor == 1.07)
        #expect(slot(home, .ST_C, .development) == nil)
    }

    @Test func aProspectIsFavouredInALesserFixture() {
        let p = Player.fixture(age: 21, currentAbility: 100, potentialAbility: 115)
        for importance in [Importance.low, .sharpness] {
            let r = run(p, importance, outlooks: outlooks(p))
            #expect(floorFactor(r) == 1.10)
            #expect(slot(r, .D_L, .development)?.reason == "Young player with room to grow: favoured for minutes (×1.10)")
            #expect(slot(r, .ST_C, .development)?.reason == "Young player with room to grow: favoured for minutes (×1.10)")
        }
        #expect(floorFactor(run(p, .medium, outlooks: outlooks(p))) == nil)
        #expect(floorFactor(run(p, .high, outlooks: outlooks(p))) == nil)
    }

    @Test func anOlderOrLimitedPlayerIsNotAProspect() {
        let older = Player.fixture(age: 24, currentAbility: 100, potentialAbility: 115)
        #expect(floorFactor(run(older, .low, outlooks: outlooks(older))) == nil)
        let limited = Player.fixture(age: 21, currentAbility: 100, potentialAbility: 114)
        #expect(floorFactor(run(limited, .low, outlooks: outlooks(limited))) == nil)
    }

    @Test func aPotentialExactlyAtTheHeadroomCountsDespiteRounding() {
        // 1.10 × 100 is 110.00000000000001 in binary floating point.
        var q = parameters
        q.prospectHeadroom = Parameter(1.10, .derived, source: "test")
        let exact = Player.fixture(age: 21, currentAbility: 100, potentialAbility: 110)
        let found = run(exact, .low, outlooks: outlooks(exact), parameters: q)
        #expect(found.everySlot.isEmpty)
        #expect(floorFactor(found) == 1.10)
        let below = Player.fixture(age: 21, currentAbility: 100, potentialAbility: 109)
        let none = run(below, .low, outlooks: outlooks(below), parameters: q)
        #expect(none.everySlot.isEmpty)
        #expect(none.bySlot.values.allSatisfy { $0.isEmpty })
    }

    @Test func theFavourFollowsHisAge() {
        for (age, factor) in [(17, 1.02), (18, 1.07), (20, 1.07), (21, 1.10), (23, 1.10)] {
            let p = young(age)
            #expect(floorFactor(run(p, .low, outlooks: outlooks(p))) == factor, "aged \(age)")
        }
        let p = young(18)
        #expect(slot(run(p, .sharpness, outlooks: outlooks(p)), .D_L, .development)?.reason
            == "Young player with room to grow: favoured for minutes (×1.07)")
        // At 24 he is no longer developing, even with an outlook handed in.
        let older = young(24)
        #expect(floorFactor(run(older, .low, outlooks: outlooks(older))) == nil)
    }

    @Test func aYoungTeenagerWithLowProfessionalismIsFavouredMore() {
        let low = young(17, professionalism: 14)
        #expect(floorFactor(run(low, .low, outlooks: outlooks(low))) == 1.04)
        let fair = young(17, professionalism: 15)
        #expect(floorFactor(run(fair, .low, outlooks: outlooks(fair))) == 1.02)
        let older = young(18, professionalism: 14)
        #expect(floorFactor(run(older, .low, outlooks: outlooks(older))) == 1.07)
    }

    /// The favour goes to a player Player Removal calls worth developing, and to nobody else: one whose reach is cover
    /// at best is not favoured, as one markedly lower never was.
    @Test func onlyAPlayerWorthDevelopingIsFavoured() {
        let p = young(21)
        for level in [ReachLevel.couldPassFirst, .couldMakeSecond] {
            #expect(floorFactor(run(p, .low, outlooks: outlooks(p, level))) == 1.10, "\(level)")
            #expect(Removal.isWorthDeveloping(outlook(p, level)), "\(level)")
        }
        // No level: first choice wherever he has a slot.
        #expect(floorFactor(run(p, .low, outlooks: outlooks(p, nil))) == 1.10)
        for level in [ReachLevel.couldBeCover, .markedlyLower] {
            #expect(floorFactor(run(p, .low, outlooks: outlooks(p, level))) == nil, "\(level)")
            #expect(floorFactor(run(p, .sharpness, outlooks: outlooks(p, level))) == nil, "\(level)")
            #expect(!Removal.isWorthDeveloping(outlook(p, level)), "\(level)")
        }
    }

    /// A first choice is worth developing whatever his level at his other slots, cover among them.
    @Test func aFirstChoiceWhoseReachElsewhereIsOnlyCoverIsFavoured() {
        let p = young(20)
        let cover = SlotOutlook(slot: .ST_C, rating: 90, reachRating: 96, isFirstChoice: false, firstChoice: smith(),
                                secondChoice: nil, band: .notExpected, pointsNeeded: 20, level: .couldBeCover)
        let first = outlooks(p, .couldBeCover, slots: [at(.D_L, nil, isFirstChoice: true), cover])
        #expect(floorFactor(run(p, .low, outlooks: first)) == 1.07)
        // First choice nowhere, the same outlook gets none.
        let nowhere = outlooks(p, .couldBeCover, slots: [at(.D_L, .possible), cover])
        #expect(floorFactor(run(p, .low, outlooks: nowhere)) == nil)
    }

    @Test func aMarkedlyLowerPlayerIsNotFavoured() {
        let p = young(21)
        #expect(floorFactor(run(p, .low, outlooks: outlooks(p, .markedlyLower))) == nil)
        #expect(floorFactor(run(p, .low, outlooks: outlooks(p, .couldMakeSecond))) == 1.10)
        // With no outlook there is nothing to go on: an ability of 0 gives none, and so does leaving him out.
        #expect(floorFactor(run(p, .low)) == nil)
        let unrated = Player.fixture(age: 19, currentAbility: 0, potentialAbility: 0)
        #expect(floorFactor(run(unrated, .low)) == nil)
    }

    @Test func nothingAtMediumOrHigh() {
        let p = young(21)
        #expect(floorFactor(run(p, .medium, outlooks: outlooks(p))) == nil)
        #expect(floorFactor(run(p, .high, outlooks: outlooks(p))) == nil)
        #expect(floorFactor(run(p, .low, outlooks: outlooks(p))) == 1.10)
        #expect(floorFactor(run(p, .sharpness, outlooks: outlooks(p))) == 1.10)
    }

    @Test func theSettingScalesTheFavourAndZeroGivesNoReason() {
        let p = young(21)
        let half = run(p, .low, outlooks: outlooks(p), development: 0.5)
        #expect(abs((floorFactor(half) ?? 0) - 1.05) < 1e-9)
        #expect(slot(half, .D_L, .development)?.reason == "Young player with room to grow: favoured for minutes (×1.05)")
        #expect(floorFactor(run(p, .low, outlooks: outlooks(p), development: 1)) == 1.10)
        let none = run(p, .low, outlooks: outlooks(p), development: 0)
        #expect(none.everySlot.isEmpty)
        #expect(none.bySlot.values.allSatisfy { $0.isEmpty })
    }

    @Test func afterFourStartsInThirtyDaysHeIsNotFavouredAndAfterThreeHeIs() {
        let p = young(21)
        func favour(_ history: [ConfirmedLineup]) -> Double? { floorFactor(run(p, .low, history: history, outlooks: outlooks(p))) }
        // No history: favoured.
        #expect(favour([]) == 1.10)
        #expect(favour(starts(p, count: 3, spacing: 7)) == 1.10)
        #expect(favour(starts(p, count: 4, spacing: 7)) == nil)
        // The month is the 30 days before the fixture: a start 30 days back counts, one 31 days back does not.
        func start(daysBack: Int) -> ConfirmedLineup {
            ConfirmedLineup(fixture: FixtureID("back \(daysBack)"), date: date.adding(days: -daysBack), starters: [.D_L: p.id])
        }
        #expect(favour(starts(p, count: 3, spacing: 7) + [start(daysBack: 31)]) == 1.10)
        #expect(favour(starts(p, count: 3, spacing: 7) + [start(daysBack: 30)]) == nil)
        // Matches he did not start do not count.
        let others = (1...4).map { i in
            ConfirmedLineup(fixture: FixtureID("o\(i)"), date: date.adding(days: -3 * i), starters: [.D_L: PlayerID(key: "other")])
        }
        #expect(favour(others) == 1.10)
    }

    // MARK: Successor

    /// The first choice a young player is compared with: Smith, 30, rated `rating`.
    func smith(rating: Double = 104) -> Rival {
        Rival(player: PlayerID(key: "smith"), name: "Smith", age: 30, rating: rating, compared: rating, isAgeNamed: true)
    }

    /// His outlook at `slot`, rated `rating` there, compared with Smith with the band given; as first choice there, with
    /// no rival and no band, as `Development.outlooks` makes it.
    func at(_ slot: SlotID, _ band: ReachBand?, rating: Double = 100, rival: Rival? = nil,
            isFirstChoice: Bool = false) -> SlotOutlook {
        let first = isFirstChoice ? nil : rival ?? smith()
        return SlotOutlook(slot: slot, rating: rating, reachRating: rating * 1.1, isFirstChoice: isFirstChoice,
                           firstChoice: first, secondChoice: nil, band: isFirstChoice ? nil : band,
                           pointsNeeded: nil, level: isFirstChoice ? nil : .couldPassFirst)
    }

    func successor(_ factor: Double, _ reason: String) -> Adjustment {
        Adjustment(kind: .successor, factor: factor, reason: reason)
    }

    func floor(_ factor: Double) -> Adjustment {
        Adjustment(kind: .development, factor: factor, reason: AdvisorText.developmentFloor(factor))
    }

    func neverBoth(_ r: (everySlot: [Adjustment], bySlot: [SlotID: [Adjustment]])) -> Bool {
        r.bySlot.values.allSatisfy { list in
            !(list.contains { $0.kind == .development } && list.contains { $0.kind == .successor })
        }
    }

    @Test func aSuccessorIsFavouredAtHisSlotInPlaceOfTheFloor() {
        let p = young(19)
        let found = outlooks(p, .couldPassFirst, slots: [at(.D_L, .onCourse)] + playable(.ST_C, .D_R))
        for importance in [Importance.low, .sharpness] {
            let r = run(p, importance, outlooks: found)
            #expect(r.bySlot[.D_L] == [successor(1.15, "On course to pass Smith at left back: favoured for matches there (×1.15)")],
                    "\(importance)")
            // The floor at his other slots, the same as before.
            #expect(r.bySlot[.ST_C] == [floor(1.07)], "\(importance)")
            #expect(r.bySlot[.D_R] == [floor(1.07)], "\(importance)")
            // Nothing at a slot he cannot play.
            #expect(r.bySlot[.GK] == [], "\(importance)")
            #expect(r.everySlot.isEmpty, "\(importance)")
            #expect(neverBoth(r), "\(importance)")
        }
        // Where he is only possible he is no successor, and the floor is at every slot he can play.
        let none = run(p, .low, outlooks: outlooks(p, .couldPassFirst))
        #expect(none.bySlot[.D_L] == [floor(1.07)])
    }

    @Test func atMediumHeGetsFivePercentAndTheFloorGivesNothing() {
        let p = young(21)
        let r = run(p, .medium, outlooks: outlooks(p, .couldPassFirst, slots: [at(.D_L, .onCourse)]))
        #expect(r.bySlot[.D_L] == [successor(1.05, "On course to pass Smith at left back: favoured for matches there (×1.05)")])
        #expect(r.bySlot[.ST_C] == [])
        #expect(r.everySlot.isEmpty)
        // Without the slot nothing at all, as at medium the floor gives nothing.
        let none = run(p, .medium, outlooks: outlooks(p, .couldPassFirst))
        #expect(none.bySlot.values.allSatisfy { $0.isEmpty })
    }

    @Test func aSuccessorGetsNothingAtHigh() {
        let p = young(21)
        let r = run(p, .high, outlooks: outlooks(p, .couldPassFirst, slots: [at(.D_L, .close)]))
        #expect(r.everySlot.isEmpty)
        #expect(r.bySlot.values.allSatisfy { $0.isEmpty })
    }

    @Test func aSeventeenYearOldNeedsToBeClose() {
        let seventeen = young(17)
        let onCourse = run(seventeen, .low, outlooks: outlooks(seventeen, .couldPassFirst, slots: [at(.D_L, .onCourse)]))
        #expect(onCourse.bySlot[.D_L] == [floor(1.02)])
        let close = run(seventeen, .low, outlooks: outlooks(seventeen, .couldPassFirst,
                                                            slots: [at(.D_L, .close)] + playable(.ST_C)))
        #expect(close.bySlot[.D_L] == [successor(1.15, "Close to passing Smith at left back: favoured for matches there (×1.15)")])
        #expect(close.bySlot[.ST_C] == [floor(1.02)])
        let eighteen = young(18)
        let older = run(eighteen, .low, outlooks: outlooks(eighteen, .couldPassFirst, slots: [at(.D_L, .onCourse)]))
        #expect(older.bySlot[.D_L] == [successor(1.15, "On course to pass Smith at left back: favoured for matches there (×1.15)")])
    }

    @Test func aFirstChoiceIsNotHisOwnSuccessor() {
        // First choice at left back and close at striker: he has his matches, so nobody's successor: the floor at both.
        let p = young(20)
        let home = outlooks(p, .couldPassFirst, slots: [at(.D_L, nil, isFirstChoice: true), at(.ST_C, .close)])
        for importance in [Importance.low, .sharpness] {
            let r = run(p, importance, outlooks: home)
            #expect(r.bySlot[.D_L] == [floor(1.07)], "\(importance)")
            #expect(r.bySlot[.ST_C] == [floor(1.07)], "\(importance)")
        }
        #expect(run(p, .medium, outlooks: home).bySlot.values.allSatisfy { $0.isEmpty })
        // He takes no place among the two at medium.
        #expect(ImportanceRules.successors(players: [p], context: context(.medium, outlooks: home), parameters: parameters)
            .isEmpty)
        // The same player first choice nowhere gets the favour at the slot he is close at.
        let away = outlooks(p, .couldPassFirst, slots: [at(.D_L, .possible), at(.ST_C, .close)])
        let r = run(p, .low, outlooks: away)
        #expect(r.bySlot[.D_L] == [floor(1.07)])
        #expect(r.bySlot[.ST_C] == [successor(1.15, "Close to passing Smith at striker: favoured for matches there (×1.15)")])
        #expect(ImportanceRules.successors(players: [p], context: context(.medium, outlooks: away), parameters: parameters)
            == [p.id])
        // First choice at his only slot: nothing to pass, so the floor.
        let only = run(p, .low, outlooks: outlooks(p, nil, slots: [at(.D_L, nil, isFirstChoice: true)]))
        #expect(only.bySlot[.D_L] == [floor(1.07)])
        // A slot marked as his own with a band and a rival all the same is not one he succeeds at.
        let marked = SlotOutlook(slot: .D_L, rating: 100, reachRating: 110, isFirstChoice: true, firstChoice: smith(),
                                 secondChoice: nil, band: .close, pointsNeeded: 0, level: .couldPassFirst)
        #expect(run(p, .low, outlooks: outlooks(p, .couldPassFirst, slots: [marked])).bySlot[.D_L] == [floor(1.07)])
    }

    @Test func aPossibleOrNotExpectedPlayerGetsOnlyTheFloor() {
        let p = young(20)
        for band in [ReachBand.possible, .notExpected] {
            let r = run(p, .low, outlooks: outlooks(p, .couldMakeSecond, slots: [at(.D_L, band)]))
            #expect(r.bySlot[.D_L] == [floor(1.07)], "\(band)")
            #expect(run(p, .medium, outlooks: outlooks(p, .couldMakeSecond, slots: [at(.D_L, band)]))
                .bySlot.values.allSatisfy { $0.isEmpty }, "\(band)")
        }
        // A markedly lower outlook gets neither favour, whatever a slot says.
        let lower = run(p, .low, outlooks: outlooks(p, .markedlyLower, slots: [at(.D_L, .close)]))
        #expect(lower.bySlot.values.allSatisfy { $0.isEmpty })
    }

    @Test func aFirstChoiceWhoseOtherSlotIsMarkedlyLowerGetsTheFloor() {
        let p = young(20)
        // First choice at left back; at striker, his only other slot, below the bar, so his outlook's level is markedly
        // lower. A first choice is never markedly lower: he gets the floor at both slots.
        let below = SlotOutlook(slot: .ST_C, rating: 60, reachRating: 66, isFirstChoice: false, firstChoice: smith(),
                                secondChoice: nil, band: .notExpected, pointsNeeded: 40, level: .markedlyLower)
        let first = outlooks(p, .markedlyLower, slots: [at(.D_L, nil, isFirstChoice: true), below])
        #expect(floorFactor(run(p, .low, outlooks: first)) == 1.07)
        // First choice nowhere, the same outlook gets none.
        let nowhere = outlooks(p, .markedlyLower, slots: [at(.D_L, .possible), below])
        #expect(floorFactor(run(p, .low, outlooks: nowhere)) == nil)
    }

    /// A 19-year-old with left-back familiarity `familiarity`, being retrained there.
    func retrainee(_ familiarity: Int) -> Player {
        Player.fixture(age: 19, attributes: [.professionalism: 15], familiarity: [.defenderLeft: familiarity],
                       currentAbility: 100, potentialAbility: 130)
    }

    /// His adjustments by slot as a successor on course at left back, who can also play striker, being retrained at
    /// left back.
    func asRetrainingSuccessor(_ p: Player, _ importance: Importance, parameters: EngineParameters? = nil)
        -> [SlotID: [Adjustment]] {
        run(p, importance, retraining: retrain(p, .defenderLeft),
            outlooks: outlooks(p, .couldPassFirst, slots: [at(.D_L, .onCourse)] + playable(.ST_C)),
            parameters: parameters).bySlot
    }

    @Test func theLargerOfRetrainingAndSuccessorIsKept() {
        // Low: the floor and retraining together, 1.07 × 1.15, come to more than the successor's 1.15.
        let low = retrainee(12)
        #expect(asRetrainingSuccessor(low, .low)[.D_L]?.map(\.kind) == [.development, .retraining])
        #expect(asRetrainingSuccessor(low, .low)[.D_L]?.map(\.factor) == [1.07, 1.15])
        // Medium: no floor, so retraining's 1.08 alone over the successor's 1.05.
        let medium = retrainee(15)
        #expect(asRetrainingSuccessor(medium, .medium)[.D_L]?.map(\.kind) == [.retraining])
        #expect(asRetrainingSuccessor(medium, .medium)[.D_L]?.first?.factor == 1.08)
        // A retraining factor small enough that the two together come to less gives way to the successor's.
        var smaller = parameters
        smaller.retrainingFactorLow = Parameter(1.05, .derived, source: "test")
        #expect(asRetrainingSuccessor(low, .low, parameters: smaller)[.D_L]
            == [successor(1.15, "On course to pass Smith at left back: favoured for matches there (×1.15)")])
        // With retraining's familiarity outside its range there is no retraining favour, and the successor's stands.
        #expect(asRetrainingSuccessor(retrainee(18), .low)[.D_L]?.map(\.kind) == [.successor])
        #expect(asRetrainingSuccessor(retrainee(9), .low)[.D_L]?.map(\.kind) == [.successor])
        #expect(asRetrainingSuccessor(retrainee(14), .medium)[.D_L]?.map(\.kind) == [.successor])
    }

    @Test func aRetrainingSuccessorGetsWhicheverTotalIsLargerAndNeverAllThree() {
        let p = retrainee(12)
        // The floor and retraining at left back, as a retrainee who is no successor has them; no successor's favour.
        let larger = asRetrainingSuccessor(p, .low)
        let asNonSuccessor = run(p, .low, retraining: retrain(p, .defenderLeft), outlooks: outlooks(p)).bySlot[.D_L]
        #expect(asNonSuccessor?.map(\.kind) == [.development, .retraining])
        #expect(larger[.D_L] == asNonSuccessor)
        #expect(larger[.D_L]?.contains { $0.kind == .successor } == false)
        // His other slot keeps the floor alone.
        #expect(larger[.ST_C] == [floor(1.07)])
        for importance in [Importance.low, .sharpness, .medium] {
            for familiarity in [9, 12, 15, 18] {
                let kinds = asRetrainingSuccessor(retrainee(familiarity), importance)[.D_L]?.map(\.kind) ?? []
                #expect(!(kinds.contains(.successor) && (kinds.contains(.development) || kinds.contains(.retraining))),
                        "\(importance), familiarity \(familiarity)")
            }
        }
        // Where the successor's favour is larger (here 1.30 against 1.07 × 1.15), he has it alone.
        var bigger = parameters
        bigger.successorFactorLow = Parameter(1.30, .derived, source: "test")
        #expect(asRetrainingSuccessor(p, .low, parameters: bigger)[.D_L]
            == [successor(1.30, "On course to pass Smith at left back: favoured for matches there (×1.30)")])
        #expect(asRetrainingSuccessor(p, .low, parameters: bigger)[.ST_C] == [floor(1.07)])
    }

    @Test func onATieTheFloorAndRetrainingAreKept() {
        // Factors exact in binary: 1.125 × 1.125 is 1.265625, the successor's favour.
        var tie = parameters
        tie.developmentFactors = Parameter([AgeFactor(upToAge: 23, factor: 1.125)], .derived, source: "test")
        tie.retrainingFactorLow = Parameter(1.125, .derived, source: "test")
        tie.successorFactorLow = Parameter(1.265625, .derived, source: "test")
        let kept = asRetrainingSuccessor(retrainee(12), .low, parameters: tie)[.D_L]
        #expect(kept?.map(\.kind) == [.development, .retraining])
        #expect(kept?.map(\.factor) == [1.125, 1.125])
        // A hair more for the successor and his favour is kept alone.
        tie.successorFactorLow = Parameter(1.2657, .derived, source: "test")
        #expect(asRetrainingSuccessor(retrainee(12), .low, parameters: tie)[.D_L]?.map(\.kind) == [.successor])
    }

    @Test func aSuccessorWhoseRetrainingWinsTakesNoPlaceAtMedium() {
        // A is closest, at left back, and retrained there with familiarity `familiarity`; B and C are further off.
        func players(_ familiarity: Int) -> (a: Player, b: Player, c: Player, found: [PlayerID: Outlook]) {
            let a = Player.fixture(name: "Young A", age: 19, attributes: [.professionalism: 15],
                                   familiarity: [.defenderLeft: familiarity], potentialAbility: 130)
            let b = Player.fixture(name: "Young B", age: 19, attributes: [.professionalism: 15], potentialAbility: 130)
            let c = Player.fixture(name: "Young C", age: 19, attributes: [.professionalism: 15], potentialAbility: 130)
            let found: [PlayerID: Outlook] = [
                a.id: outlook(a, .couldPassFirst, slots: [at(.D_L, .close, rating: 103)]),
                b.id: outlook(b, .couldPassFirst, slots: [at(.ST_C, .onCourse, rating: 100)]),
                c.id: outlook(c, .couldPassFirst, slots: [at(.D_R, .onCourse, rating: 98)])]
            return (a, b, c, found)
        }
        // Familiarity 15: retraining's 1.08 beats the successor's 1.05 at his only successor slot, so B and C are the two.
        let won = players(15)
        let wonContext = context(.medium, retraining: retrain(won.a, .defenderLeft), outlooks: won.found)
        #expect(ImportanceRules.successors(players: [won.a, won.b, won.c], context: wonContext, parameters: parameters)
            == [won.b.id, won.c.id])
        let a = run(won.a, .medium, retraining: retrain(won.a, .defenderLeft), outlooks: won.found,
                    successorsFavoured: [won.b.id, won.c.id])
        #expect(a.bySlot[.D_L]?.map(\.kind) == [.retraining])
        // Familiarity 14 is below the medium retraining range: no retraining favour, so he takes his place as before.
        let stands = players(14)
        let standsContext = context(.medium, retraining: retrain(stands.a, .defenderLeft), outlooks: stands.found)
        #expect(ImportanceRules.successors(players: [stands.a, stands.b, stands.c], context: standsContext,
                                           parameters: parameters) == [stands.a.id, stands.b.id])
        // A retraining at a slot he is no successor at leaves his place alone.
        let elsewhere = context(.medium, retraining: retrain(won.a, .defenderRight), outlooks: won.found)
        #expect(ImportanceRules.successors(players: [won.a, won.b, won.c], context: elsewhere, parameters: parameters)
            == [won.a.id, won.b.id])
    }

    @Test func theFloorAndRetrainingStillMultiply() {
        let p = Player.fixture(age: 19, attributes: [.professionalism: 15], familiarity: [.defenderLeft: 12],
                               currentAbility: 100, potentialAbility: 130)
        let r = run(p, .low, retraining: retrain(p, .defenderLeft), outlooks: outlooks(p))
        #expect(r.bySlot[.D_L]?.map(\.kind) == [.development, .retraining])
        #expect(r.bySlot[.D_L]?.map(\.factor) == [1.07, 1.15])
        #expect(r.bySlot[.ST_C] == [floor(1.07)])
    }

    @Test func onlyTheTwoClosestSuccessorsAreFavouredAtMedium() {
        let a = Player.fixture(name: "Young A", age: 19, attributes: [.professionalism: 15], potentialAbility: 130)
        let b = Player.fixture(name: "Young B", age: 19, attributes: [.professionalism: 15], potentialAbility: 130)
        let c = Player.fixture(name: "Young C", age: 19, attributes: [.professionalism: 15], potentialAbility: 130)
        let d = Player.fixture(name: "Young D", age: 19, attributes: [.professionalism: 15], potentialAbility: 130)
        // A is closest, at 100 against 104. B and C tie at 98 against 104 and B has the lower key; C's slot where he
        // is closer is one he is not a successor at. D is closest of all but has had his matches this month.
        let found: [PlayerID: Outlook] = [
            a.id: outlook(a, .couldPassFirst, slots: [at(.D_L, .close, rating: 100)]),
            b.id: outlook(b, .couldPassFirst, slots: [at(.ST_C, .onCourse, rating: 98), at(.D_L, .onCourse, rating: 90)]),
            c.id: outlook(c, .couldPassFirst, slots: [at(.D_R, .onCourse, rating: 98), at(.ST_C, .possible, rating: 103)]),
            d.id: outlook(d, .couldPassFirst, slots: [at(.D_L, .close, rating: 103)])]
        let history = starts(d, count: 4, spacing: 7)
        let favoured = ImportanceRules.successors(players: [d, c, b, a], context: context(.medium, history: history, outlooks: found),
                                                  parameters: parameters)
        #expect(favoured == [a.id, b.id])
        // The order the players come in does not matter.
        #expect(ImportanceRules.successors(players: [a, b, c, d], context: context(.medium, history: history, outlooks: found),
                                           parameters: parameters) == favoured)
        // Only they are favoured at medium.
        func medium(_ p: Player, _ s: SlotID) -> Adjustment? {
            slot(run(p, .medium, history: history, outlooks: found, successorsFavoured: favoured), s, .successor)
        }
        #expect(medium(a, .D_L)?.factor == 1.05)
        #expect(medium(b, .ST_C)?.factor == 1.05)
        #expect(medium(b, .D_L)?.factor == 1.05)
        #expect(medium(c, .D_R) == nil)
        #expect(run(c, .medium, outlooks: found, successorsFavoured: favoured).bySlot.values.allSatisfy { $0.isEmpty })
        // In a low fixture there is no cap: all three are favoured.
        #expect(slot(run(a, .low, outlooks: found), .D_L, .successor)?.factor == 1.15)
        #expect(slot(run(b, .low, outlooks: found), .ST_C, .successor)?.factor == 1.15)
        #expect(slot(run(c, .low, outlooks: found), .D_R, .successor)?.factor == 1.15)
        // With a cap of three, C is favoured at medium too, and D still is not.
        var three = parameters
        three.successorsFavouredAtMedium = Parameter(3, .derived, source: "test")
        #expect(ImportanceRules.successors(players: [a, b, c, d], context: context(.medium, history: history, outlooks: found),
                                           parameters: three) == [a.id, b.id, c.id])
    }

    @Test func aFirstChoiceRatedZeroCountsAsTheClosest() {
        let a = Player.fixture(name: "Young A", age: 19, attributes: [.professionalism: 15], potentialAbility: 130)
        let b = Player.fixture(name: "Young B", age: 19, attributes: [.professionalism: 15], potentialAbility: 130)
        let c = Player.fixture(name: "Young C", age: 19, attributes: [.professionalism: 15], potentialAbility: 130)
        let found: [PlayerID: Outlook] = [
            a.id: outlook(a, .couldPassFirst, slots: [at(.D_L, .close, rating: 103)]),
            b.id: outlook(b, .couldPassFirst, slots: [at(.D_L, .close, rating: 102)]),
            c.id: outlook(c, .couldPassFirst, slots: [at(.ST_C, .close, rating: 0, rival: smith(rating: 0))])]
        #expect(ImportanceRules.successors(players: [a, b, c], context: context(.medium, outlooks: found),
                                           parameters: parameters) == [a.id, c.id])
    }

    @Test func aSuccessorCanBeGotSharpAndIsNotMarkedDownForBeingSharp() {
        let unsharp = Player.fixture(age: 19, attributes: [.professionalism: 15], currentAbility: 100, potentialAbility: 130,
                                     sharpness: 0.705)
        let asSuccessor = outlooks(unsharp, .couldPassFirst, slots: [at(.D_L, .onCourse)])
        // In neither eleven, but a successor: favoured to get sharp.
        let need = every(run(unsharp, .sharpness, outlooks: asSuccessor), .needsSharpness)
        #expect(abs((need?.factor ?? 0) - 1.50) < 1e-9)
        #expect(need?.reason == "Needs minutes: sharpness 70% (×1.50)")
        // Not a successor and in neither eleven: nothing, as before.
        #expect(every(run(unsharp, .sharpness, outlooks: outlooks(unsharp, .couldPassFirst)), .needsSharpness) == nil)
        #expect(every(run(unsharp, .sharpness, outlooks: outlooks(unsharp, .couldMakeSecond, slots: [at(.D_L, .possible)])),
                      .needsSharpness) == nil)
        // Fully sharp: a successor in neither eleven is not marked down; one in the elevens still is.
        let sharp = Player.fixture(age: 19, attributes: [.professionalism: 15], currentAbility: 100, potentialAbility: 130,
                                   sharpness: 0.95)
        let sharpSuccessor = outlooks(sharp, .couldPassFirst, slots: [at(.D_L, .onCourse)])
        #expect(every(run(sharp, .sharpness, outlooks: sharpSuccessor), .needsSharpness) == nil)
        #expect(every(run(sharp, .sharpness, tiers: tiers(sharp, tier: 2), outlooks: sharpSuccessor), .needsSharpness)?.factor
            == 0.60)
    }

    @Test func theSettingAndTheMonthlyStopApplyToTheSuccessorToo() {
        let p = young(19)
        let found = outlooks(p, .couldPassFirst, slots: [at(.D_L, .onCourse)] + playable(.ST_C))
        // The setting scales the favour as it scales the floor.
        let scaled = run(p, .low, outlooks: found, development: 0.4)
        #expect(abs((slot(scaled, .D_L, .successor)?.factor ?? 0) - 1.06) < 1e-9)
        #expect(slot(scaled, .D_L, .successor)?.reason == "On course to pass Smith at left back: favoured for matches there (×1.06)")
        #expect(slot(scaled, .D_L, .development) == nil)
        #expect(abs((slot(scaled, .ST_C, .development)?.factor ?? 0) - 1.028) < 1e-9)
        let mediumScaled = run(p, .medium, outlooks: found, development: 0.4)
        #expect(abs((slot(mediumScaled, .D_L, .successor)?.factor ?? 0) - 1.02) < 1e-9)
        // At 0 there is nothing.
        let off = run(p, .low, outlooks: found, development: 0)
        #expect(off.everySlot.isEmpty)
        #expect(off.bySlot.values.allSatisfy { $0.isEmpty })
        // After three starts in thirty days he is still favoured; after four, neither favour.
        #expect(slot(run(p, .low, history: starts(p, count: 3, spacing: 7), outlooks: found), .D_L, .successor)?.factor == 1.15)
        let stopped = run(p, .low, history: starts(p, count: 4, spacing: 7), outlooks: found)
        #expect(stopped.bySlot.values.allSatisfy { $0.isEmpty })
        #expect(run(p, .medium, history: starts(p, count: 4, spacing: 7), outlooks: found).bySlot.values.allSatisfy { $0.isEmpty })
        // Stopped or switched off, he no longer counts as in the elevens for the sharpness favour.
        let unsharp = Player.fixture(age: 19, attributes: [.professionalism: 15], currentAbility: 100, potentialAbility: 130,
                                     sharpness: 0.705)
        let unsharpFound = outlooks(unsharp, .couldPassFirst, slots: [at(.D_L, .onCourse)])
        #expect(every(run(unsharp, .sharpness, outlooks: unsharpFound), .needsSharpness) != nil)
        #expect(every(run(unsharp, .sharpness, history: starts(unsharp, count: 4, spacing: 7), outlooks: unsharpFound),
                      .needsSharpness) == nil)
        #expect(every(run(unsharp, .sharpness, outlooks: unsharpFound, development: 0), .needsSharpness) == nil)
        // And a stopped successor is left out of the two at medium.
        #expect(ImportanceRules.successors(players: [p], context: context(.medium, history: starts(p, count: 4, spacing: 7),
                                                                          outlooks: found),
                                           parameters: parameters).isEmpty)
        #expect(ImportanceRules.successors(players: [p], context: context(.medium, outlooks: found), parameters: parameters)
            == [p.id])
    }

    @Test func aFactorOfOneSwitchesTheSuccessorRuleOff() {
        var off = parameters
        off.successorFactorLow = Parameter(1, .derived, source: "test")
        off.successorFactorMedium = Parameter(1, .derived, source: "test")
        let p = Player.fixture(age: 19, attributes: [.professionalism: 15], currentAbility: 100, potentialAbility: 130,
                               sharpness: 0.705)
        let found = outlooks(p, .couldPassFirst, slots: [at(.D_L, .onCourse)])
        // Low: the floor stands at his slot, as for anyone who is no successor.
        #expect(run(p, .low, outlooks: found, parameters: off).bySlot[.D_L]?.map(\.kind) == [.development])
        #expect(run(p, .medium, outlooks: found, parameters: off).bySlot.values.allSatisfy { $0.isEmpty })
        #expect(every(run(p, .sharpness, outlooks: found, parameters: off), .needsSharpness) == nil)
    }

    // MARK: Advised to leave

    @Test func aPlayerAdvisedToLeaveLosesTheFloor() {
        let p = young(19)
        let someoneElse = PlayerID(key: "someone else")
        for importance in [Importance.low, .sharpness] {
            #expect(floorFactor(run(p, importance, outlooks: outlooks(p))) == 1.07, "\(importance)")
            #expect(floorFactor(run(p, importance, outlooks: outlooks(p), advisedToLeave: [someoneElse])) == 1.07,
                    "\(importance)")
            let leaving = run(p, importance, outlooks: outlooks(p), advisedToLeave: [p.id])
            #expect(leaving.everySlot.isEmpty, "\(importance)")
            #expect(leaving.bySlot.values.allSatisfy { $0.isEmpty }, "\(importance)")
        }
    }

    @Test func aPlayerAdvisedToLeaveLosesTheSuccessorsFavourAtLowAndMedium() {
        let p = young(19)
        let found = outlooks(p, .couldPassFirst, slots: [at(.D_L, .onCourse)] + playable(.ST_C))
        // Low: neither the successor's favour at left back nor the floor at striker.
        let low = run(p, .low, outlooks: found)
        #expect(low.bySlot[.D_L] == [successor(1.15, "On course to pass Smith at left back: favoured for matches there (×1.15)")])
        #expect(low.bySlot[.ST_C] == [floor(1.07)])
        let lowLeaving = run(p, .low, outlooks: found, advisedToLeave: [p.id])
        #expect(lowLeaving.everySlot.isEmpty)
        #expect(lowLeaving.bySlot.values.allSatisfy { $0.isEmpty })
        // Medium.
        #expect(run(p, .medium, outlooks: found).bySlot[.D_L]
            == [successor(1.05, "On course to pass Smith at left back: favoured for matches there (×1.05)")])
        let mediumLeaving = run(p, .medium, outlooks: found, advisedToLeave: [p.id])
        #expect(mediumLeaving.bySlot.values.allSatisfy { $0.isEmpty })
        // Someone else advised to leave changes nothing.
        #expect(run(p, .low, outlooks: found, advisedToLeave: [PlayerID(key: "someone else")]).bySlot == low.bySlot)
        // Nor is he got sharp as a successor in a sharpness fixture: he is no longer one this fixture favours.
        let unsharp = Player.fixture(age: 19, attributes: [.professionalism: 15], currentAbility: 100, potentialAbility: 130,
                                     sharpness: 0.705)
        let unsharpFound = outlooks(unsharp, .couldPassFirst, slots: [at(.D_L, .onCourse)])
        #expect(every(run(unsharp, .sharpness, outlooks: unsharpFound), .needsSharpness) != nil)
        #expect(every(run(unsharp, .sharpness, outlooks: unsharpFound, advisedToLeave: [unsharp.id]), .needsSharpness) == nil)
        // In the elevens the sharpness rule treats him as it treats anyone there.
        #expect(every(run(unsharp, .sharpness, tiers: tiers(unsharp, tier: 2), outlooks: unsharpFound,
                          advisedToLeave: [unsharp.id]), .needsSharpness) != nil)
    }

    @Test func aSuccessorAdvisedToLeaveTakesNoPlaceAmongTheTwoAtMedium() {
        let a = Player.fixture(name: "Young A", age: 19, attributes: [.professionalism: 15], potentialAbility: 130)
        let b = Player.fixture(name: "Young B", age: 19, attributes: [.professionalism: 15], potentialAbility: 130)
        let c = Player.fixture(name: "Young C", age: 19, attributes: [.professionalism: 15], potentialAbility: 130)
        let found: [PlayerID: Outlook] = [
            a.id: outlook(a, .couldPassFirst, slots: [at(.D_L, .close, rating: 103)]),
            b.id: outlook(b, .couldPassFirst, slots: [at(.ST_C, .onCourse, rating: 100)]),
            c.id: outlook(c, .couldPassFirst, slots: [at(.D_R, .onCourse, rating: 98)])]
        #expect(ImportanceRules.successors(players: [a, b, c], context: context(.medium, outlooks: found),
                                           parameters: parameters) == [a.id, b.id])
        #expect(ImportanceRules.successors(players: [a, b, c],
                                           context: context(.medium, outlooks: found, advisedToLeave: [a.id]),
                                           parameters: parameters) == [b.id, c.id])
        // The other two are favoured at medium; he is not.
        let favoured: Set<PlayerID> = [b.id, c.id]
        func medium(_ p: Player, _ s: SlotID) -> Adjustment? {
            slot(run(p, .medium, outlooks: found, successorsFavoured: favoured, advisedToLeave: [a.id]), s, .successor)
        }
        #expect(medium(b, .ST_C)?.factor == 1.05)
        #expect(medium(c, .D_R)?.factor == 1.05)
        #expect(medium(a, .D_L) == nil)
    }

    @Test func aMarkedPlayerAdvisedToLeaveKeepsTheShopWindowFavour() {
        let p = Player.fixture(age: 19, currentAbility: 100, potentialAbility: 130)
        for importance in [Importance.low, .sharpness] {
            let r = run(p, importance, marks: [p.id: .toSell], outlooks: outlooks(p), advisedToLeave: [p.id])
            #expect(r.everySlot == [Adjustment(kind: .shopWindow, factor: 1.03,
                                               reason: "Marked to sell: favoured for minutes, an untested way to bring offers (×1.03)")],
                    "\(importance)")
            #expect(r.bySlot.values.allSatisfy { $0.isEmpty }, "\(importance)")
        }
    }

    // MARK: Marked to sell or loan out

    @Test func aMarkedPlayerIsFavouredInALowOrSharpnessFixture() {
        let p = Player.fixture(age: 28, currentAbility: 100, potentialAbility: 100)
        for importance in [Importance.low, .sharpness] {
            let sell = every(run(p, importance, marks: [p.id: .toSell]), .shopWindow)
            #expect(sell?.factor == 1.03)
            #expect(sell?.reason == "Marked to sell: favoured for minutes, an untested way to bring offers (×1.03)")
            let loan = every(run(p, importance, marks: [p.id: .toLoanOut]), .shopWindow)
            #expect(loan?.factor == 1.03)
            #expect(loan?.reason == "Marked to loan out: favoured for minutes, an untested way to bring offers (×1.03)")
        }
    }

    @Test func aMarkDoesNothingInAMediumOrHighFixture() {
        let p = Player.fixture(age: 28, currentAbility: 100, potentialAbility: 100)
        #expect(every(run(p, .medium, marks: [p.id: .toSell]), .shopWindow) == nil)
        #expect(every(run(p, .high, marks: [p.id: .toSell]), .shopWindow) == nil)
    }

    @Test func anUnmarkedPlayerIsNotFavoured() {
        let p = Player.fixture(age: 28, currentAbility: 100, potentialAbility: 100)
        let other = Player.fixture(name: "Someone else")
        #expect(every(run(p, .low), .shopWindow) == nil)
        #expect(every(run(p, .low, marks: [other.id: .toSell]), .shopWindow) == nil)
    }

    @Test func aMarkedPlayerOnLoanHereIsNotFavoured() {
        // A mark made before he became a loanee must not favour another club's player.
        let loanee = Player.fixture(age: 28, currentAbility: 100, potentialAbility: 100, club: "Other FC")
        #expect(every(run(loanee, .low, marks: [loanee.id: .toSell]), .shopWindow) == nil)
        // With the club unknown nobody reads as a loanee, so the mark stands.
        #expect(every(run(loanee, .low, marks: [loanee.id: .toSell], ownClub: nil), .shopWindow) != nil)
    }

    @Test func aMarkedProspectGetsBothAndInKindOrder() {
        let p = Player.fixture(age: 19, currentAbility: 100, potentialAbility: 130)
        let r = run(p, .low, marks: [p.id: .toLoanOut], outlooks: outlooks(p))
        // The floor is in every slot's own list and the mark in the every-slot list; the selector applies and names
        // them by kind, the floor first.
        #expect(r.everySlot.map(\.kind) == [.shopWindow])
        #expect(r.bySlot[.D_L]?.map(\.kind) == [.development])
        #expect(r.bySlot[.ST_C]?.map(\.kind) == [.development])
        let order = Adjustment.Kind.allCases
        #expect(order.firstIndex(of: .development)! < order.firstIndex(of: .shopWindow)!)
    }

    @Test func aMarkToSellCountsOnAYouthContractAndAMarkToLoanOutDoesNot() {
        // A player on a youth contract can be sold and cannot be loaned out (the owner's correction of 22 November 2026).
        var p = Player.fixture(age: 18, currentAbility: 100, potentialAbility: 100)
        #expect(every(run(p, .sharpness, marks: [p.id: .toLoanOut]), .shopWindow)?.factor == 1.03)
        p.contractType = .youth
        #expect(every(run(p, .low, marks: [p.id: .toSell]), .shopWindow)?.factor == 1.03)
        #expect(every(run(p, .sharpness, marks: [p.id: .toSell]), .shopWindow)?.factor == 1.03)
        #expect(every(run(p, .low, marks: [p.id: .toLoanOut]), .shopWindow) == nil)
        #expect(every(run(p, .sharpness, marks: [p.id: .toLoanOut]), .shopWindow) == nil)
        // Only in the fixtures where any mark counts.
        #expect(every(run(p, .medium, marks: [p.id: .toSell]), .shopWindow) == nil)
    }

    @Test func aMarkToLoanOutCountsOnAYouthContractWithNoMonthsLeftAndNotOnOneWithMonthsLeft() {
        // A youth contract with 0 months left is no contract, as Player Removal reads it: both marks count.
        var p = Player.fixture(age: 18, currentAbility: 100, potentialAbility: 100)
        p.contractType = .youth
        p.monthsLeft = 0
        #expect(every(run(p, .low, marks: [p.id: .toSell]), .shopWindow)?.factor == 1.03)
        #expect(every(run(p, .sharpness, marks: [p.id: .toLoanOut]), .shopWindow)?.factor == 1.03)
        // With months left, or months unknown, it is a youth contract: a mark to loan out means nothing, a mark to sell
        // counts.
        for months in [1, 24, nil] {
            p.monthsLeft = months
            #expect(every(run(p, .low, marks: [p.id: .toLoanOut]), .shopWindow) == nil, "\(String(describing: months))")
            #expect(every(run(p, .low, marks: [p.id: .toSell]), .shopWindow)?.factor == 1.03,
                    "\(String(describing: months))")
        }
    }

    @Test func aFactorOfOneSwitchesTheRuleOff() {
        var off = EngineParameters.fm27
        off.shopWindowFactor = Parameter(1, .derived, source: "test")
        let p = Player.fixture(age: 28, currentAbility: 100, potentialAbility: 100)
        #expect(every(run(p, .low, marks: [p.id: .toSell], parameters: off), .shopWindow) == nil)
    }

    // MARK: Retraining

    func retrain(_ p: Player, _ position: Position) -> [Retraining] {
        [Retraining(player: p.id, position: position, acceptedOn: date.adding(days: -30))]
    }

    @Test func aRetraineeIsFavouredAtTheNewPositionOnly() {
        let p = Player.fixture(familiarity: [.defenderLeft: 12])
        let r = run(p, .low, retraining: retrain(p, .defenderLeft))
        #expect(slot(r, .D_L, .retraining)?.factor == 1.15)
        #expect(slot(r, .D_L, .retraining)?.reason == "Retraining at left back (familiarity 12): favoured for match experience there (×1.15)")
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
                                   reason: "Retraining at left attacking midfield (familiarity 12): favoured for match experience there (×1.15)")]
        #expect(run(p, .low, retraining: both).bySlot[.AM_L] == expected)
        #expect(run(p, .low, retraining: both.reversed()).bySlot[.AM_L] == expected)
        // When only one of the two is still being learnt, that one counts.
        let learnt = Player.fixture(familiarity: [.attackingMidLeft: 18, .midfielderLeft: 14])
        #expect(run(learnt, .low, retraining: both).bySlot[.AM_L]?.map(\.reason)
            == ["Retraining at left midfield (familiarity 14): favoured for match experience there (×1.15)"])
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
        // Three starts, not four, so the monthly stop leaves the floor in. The planner hands a loanee no outlook; this
        // one is handed in only to see every kind in its place. He is in the first eleven, so that needing minutes
        // counts for him.
        let r = run(p, .low, history: starts(p, count: 3), tiers: tiers(p, tier: 1), retraining: retrain(p, .defenderLeft),
                    stability: 1, outlooks: outlooks(p))
        #expect(r.everySlot.map(\.kind) == [.loanedIn, .consecutiveStarts, .needsSharpness])
        #expect(r.bySlot[.D_L]?.map(\.kind) == [.development, .retraining, .stability])
        #expect(r.bySlot[.ST_C]?.map(\.kind) == [.development])
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
