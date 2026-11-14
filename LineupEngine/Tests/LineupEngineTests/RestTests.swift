import Testing
@testable import LineupEngine

@Suite struct RestTests {
    let asOf = Day(iso: "2026-11-13")!
    let parameters = EngineParameters.fm27

    func advice(_ players: [Player], history: [ConfirmedLineup] = [], ownClub: String? = "Oxford City",
                intensity: TrainingIntensity = .medium, parameters: EngineParameters? = nil) throws -> [RestAdvice] {
        try Rest.advice(players: players, ownClub: ownClub, history: StartHistory(history), asOf: asOf,
                        intensity: intensity, parameters: parameters ?? self.parameters)
    }

    func one(_ player: Player, history: [ConfirmedLineup] = [], parameters: EngineParameters? = nil) throws -> RestAdvice? {
        let found = try advice([player], history: history, parameters: parameters)
        #expect(found.count <= 1)
        return found.first
    }

    /// One start per day offset from `asOf`, all in `slot`.
    func starts(_ player: Player, daysFromAsOf offsets: [Int], slot: SlotID) -> [ConfirmedLineup] {
        offsets.enumerated().map { i, offset in
            ConfirmedLineup(fixture: FixtureID("f\(i)"), date: asOf.adding(days: offset), starters: [slot: player.id])
        }
    }

    func limit(_ player: Player, parameters: EngineParameters? = nil) throws -> (limit: Int, notes: [String]) {
        try Rest.limit(of: player, parameters: parameters ?? self.parameters)
    }

    // MARK: His limit

    @Test func anAverage25YearOldHasTheStandardLimit() throws {
        let l = try limit(Player.fixture())
        #expect(l.limit == 400)
        #expect(l.notes.isEmpty)
    }

    @Test func ageLowersTheLimit() throws {
        #expect(try limit(Player.fixture(age: 32)) == (300, ["aged 32 or over"]))
        #expect(try limit(Player.fixture(age: 36)) == (300, ["aged 32 or over"]))
        #expect(try limit(Player.fixture(age: 30)) == (350, ["aged 30 or 31"]))
        #expect(try limit(Player.fixture(age: 31)) == (350, ["aged 30 or 31"]))
        #expect(try limit(Player.fixture(age: 18)) == (350, ["under 19"]))
        #expect(try limit(Player.fixture(age: 19)) == (400, []))
        #expect(try limit(Player.fixture(age: 29)) == (400, []))
    }

    @Test func attributesMoveTheLimit() throws {
        let low = Player.fixture(attributes: [.naturalFitness: 8, .injuryProneness: 16])
        #expect(try limit(low) == (250, ["Natural Fitness below 10", "Injury Proneness 15 or over"]))
        let high = Player.fixture(attributes: [.naturalFitness: 18, .stamina: 18, .injuryProneness: 5])
        #expect(try limit(high) == (530, ["Natural Fitness 15 or over", "Stamina 15 or over", "Injury Proneness 8 or under"]))
        #expect(try limit(Player.fixture(attributes: [.stamina: 9])) == (350, ["Stamina below 10"]))
        // At the edges of each band nothing changes.
        let edges = Player.fixture(attributes: [.naturalFitness: 14, .stamina: 14, .injuryProneness: 9])
        #expect(try limit(edges) == (400, []))
        let lowEdges = Player.fixture(attributes: [.naturalFitness: 10, .stamina: 10, .injuryProneness: 14])
        #expect(try limit(lowEdges) == (400, []))
    }

    @Test func theLimitIsKeptWithinItsBoundsAndKeepsItsNotes() throws {
        let worst = Player.fixture(age: 33, attributes: [.naturalFitness: 5, .stamina: 5, .injuryProneness: 20])
        #expect(try limit(worst) == (200, ["aged 32 or over", "Natural Fitness below 10", "Stamina below 10", "Injury Proneness 15 or over"]))
        // The standard base is jadedThreshold: raised to 500, the best attributes would give 630.
        var q = parameters
        q.jadedThreshold = Parameter(500, .derived, source: "test")
        let best = Player.fixture(attributes: [.naturalFitness: 18, .stamina: 18, .injuryProneness: 5])
        #expect(try limit(best, parameters: q) == (550, ["Natural Fitness 15 or over", "Stamina 15 or over", "Injury Proneness 8 or under"]))
        #expect(try limit(Player.fixture(), parameters: q) == (500, []))
    }

    @Test func theAdviceCarriesHisLimitAndItsNotes() throws {
        let a = try #require(try one(Player.fixture(age: 32, jadedness: 301)))
        #expect(a.level == .rest)
        #expect(a.limit == 300)
        #expect(a.limitNotes == ["aged 32 or over"])
        #expect(a.reasons == ["Jadedness 301 is above his limit of 300: rest him from training and matches"])
    }

    // MARK: Levels

    @Test func jadednessSetsTheLevel() throws {
        #expect(try one(Player.fixture(jadedness: 610))?.level == .holiday)
        #expect(try one(Player.fixture(jadedness: 600))?.level == .rest)
        #expect(try one(Player.fixture(jadedness: 401))?.level == .rest)
        #expect(try one(Player.fixture(jadedness: 400))?.level == .watch)
        #expect(try one(Player.fixture(jadedness: 321))?.level == .watch)
        #expect(try one(Player.fixture(jadedness: 320)) == nil)
    }

    @Test func conditionBelowTheFloorMeansRest() throws {
        let low = try #require(try one(Player.fixture(condition: 0.84)))
        #expect(low.level == .rest)
        #expect(low.reasons == ["Condition 84% is below the 85% floor"])
        #expect(try one(Player.fixture(condition: 0.85)) == nil)
    }

    @Test func aFullBackOnARunIsWatched() throws {
        let p = Player.fixture(jadedness: -500)
        let a = try #require(try one(p, history: starts(p, daysFromAsOf: [0, -3], slot: .D_L)))
        #expect(a.level == .watch)
        #expect(a.consecutiveStarts == 2)
        #expect(a.reasons == ["Has started the last 2 matches in quick succession"])
        #expect(a.days == nil)
    }

    @Test func aCentreBackOnTheSameRunIsNotListed() throws {
        let p = Player.fixture(jadedness: -500)
        #expect(try one(p, history: starts(p, daysFromAsOf: [0, -3], slot: .D_CL)) == nil)
    }

    @Test func aStartOnTheDayCountsAndALaterOneDoesNot() throws {
        let p = Player.fixture(jadedness: -500)
        // Only the start dated on asOf, three days after the other, makes the run two.
        #expect(try one(p, history: starts(p, daysFromAsOf: [-3], slot: .D_L)) == nil)
        #expect(try one(p, history: starts(p, daysFromAsOf: [0, -3], slot: .D_L))?.consecutiveStarts == 2)
        // A lineup dated after asOf is not counted.
        #expect(try one(p, history: starts(p, daysFromAsOf: [2, -1], slot: .D_L)) == nil)
    }

    @Test func theRunMustReachTheDayAfterWithinTheWindow() throws {
        // The window is 4 days measured from the day after asOf, so the newest start must be on or after asOf − 3.
        #expect(parameters.consecutiveStartWindowDays.value == 4)
        let p = Player.fixture(jadedness: -500)
        let a = try #require(try one(p, history: starts(p, daysFromAsOf: [-3, -6], slot: .D_L)))
        #expect(a.level == .watch)
        #expect(a.reasons == ["Has started the last 2 matches in quick succession"])
        #expect(try one(p, history: starts(p, daysFromAsOf: [-4, -7], slot: .D_L)) == nil)
    }

    @Test func aRunIsACauseWheneverThePlannerWouldAdjustForIt() throws {
        let p = Player.fixture(jadedness: -500)
        let history = starts(p, daysFromAsOf: [0, -3], slot: .D_L)
        func withFullBackFactor(_ factor: Double) -> EngineParameters {
            var q = parameters
            var steps = q.consecutiveStartSteps.value
            steps[.defenderLeft] = [ConsecutiveStartStep(starts: 2, factor: factor)]
            q.consecutiveStartSteps = Parameter(steps, .derived, source: "test")
            return q
        }
        // A factor above 1 is still an adjustment the planner makes for the run.
        let above = try #require(try one(p, history: history, parameters: withFullBackFactor(1.1)))
        #expect(above.level == .watch)
        #expect(above.reasons == ["Has started the last 2 matches in quick succession"])
        // A factor of exactly 1 is no adjustment, so no watch.
        #expect(try one(p, history: history, parameters: withFullBackFactor(1.0)) == nil)
    }

    @Test func aRunWithNoFactorIsNotACauseButIsCounted() throws {
        let p = Player.fixture(jadedness: 330)
        let a = try #require(try one(p, history: starts(p, daysFromAsOf: [0, -3], slot: .D_CL)))
        #expect(a.level == .watch)
        #expect(a.consecutiveStarts == 2)
        #expect(a.reasons == ["Jadedness 330 is close to his limit of 400"])
    }

    // MARK: Days

    @Test func aHolidayCountsDaysAtTheHolidayRate() throws {
        let a = try #require(try one(Player.fixture(jadedness: 640)))
        #expect(a.level == .holiday)
        #expect(a.days == 7)
        #expect(a.reasons == ["Jadedness 640 is more than 200 above his limit of 400: a holiday clears it fastest"])
    }

    @Test func restCountsDaysAtTheRestRate() throws {
        #expect(try one(Player.fixture(jadedness: 450))?.days == 7)
        // Exactly divisible: (420 − 320) / 20 is 5.
        #expect(try one(Player.fixture(jadedness: 420))?.days == 5)
        // Training intensity does not scale it.
        #expect(try advice([Player.fixture(jadedness: 450)], intensity: .high).first?.days == 7)
    }

    @Test func lowConditionCountsTheDaysTheProjectionNeeds() throws {
        let p = Player.fixture(condition: 0.70)
        var fitness = ProjectedFitness(p)
        var expected = 0
        while fitness.condition < parameters.conditionFloor.value {
            fitness = try FitnessProjection.afterDays(1, fitness, player: p, intensity: .medium, parameters: parameters)
            expected += 1
        }
        let a = try #require(try one(p))
        #expect(a.level == .rest)
        #expect(a.days == expected)
        #expect(expected > 0)
        // Low intensity recovers faster, high slower.
        let atLow = try advice([p], intensity: .low).first?.days
        let atHigh = try advice([p], intensity: .high).first?.days
        #expect((atLow ?? 99) <= expected && expected <= (atHigh ?? -1))
    }

    /// Condition regained at a flat 1/64 a day, with the floor at 0.75, so the sums are exact.
    var flatRecovery: EngineParameters {
        var q = parameters
        q.conditionRecoveryPerDay = Parameter([CurvePoint(x: 0, factor: 0.015625), CurvePoint(x: 1, factor: 0.015625)],
                                              .derived, source: "test")
        q.conditionFloor = Parameter(0.75, .derived, source: "test")
        return q
    }

    @Test func conditionDaysStopAtFourteen() throws {
        #expect(try one(Player.fixture(condition: 0.75 - 14 * 0.015625), parameters: flatRecovery)?.days == 14)
        let slow = try #require(try one(Player.fixture(condition: 0.75 - 15 * 0.015625), parameters: flatRecovery))
        #expect(slow.level == .rest)
        #expect(slow.days == nil)
        // The horizon is restConditionEstimateDays.
        var longer = flatRecovery
        longer.restConditionEstimateDays = Parameter(15, .derived, source: "test")
        #expect(try one(Player.fixture(condition: 0.75 - 15 * 0.015625), parameters: longer)?.days == 15)
    }

    @Test func whenBothApplyTheLargerCounts() throws {
        // Jadedness 340 over a limit of 300 needs (340 − 240) / 20 = 5 days; condition needs 14.
        let p = Player.fixture(age: 32, condition: 0.75 - 14 * 0.015625, jadedness: 340)
        #expect(try one(p, parameters: flatRecovery)?.days == 14)
        // Jadedness 480 needs (480 − 240) / 20 = 12; condition needs 1.
        let q = Player.fixture(age: 32, condition: 0.75 - 0.015625, jadedness: 480)
        #expect(try one(q, parameters: flatRecovery)?.days == 12)
        // Condition not clear within fourteen days leaves the whole estimate unknown.
        let r = Player.fixture(age: 32, condition: 0.5, jadedness: 340)
        #expect(try one(r, parameters: flatRecovery)?.days == nil)
    }

    @Test func watchHasNoDays() throws {
        #expect(try one(Player.fixture(jadedness: 350))?.days == nil)
    }

    // MARK: Reasons and basis

    @Test func reasonsComeOnePerCauseInOrder() throws {
        let a = try #require(try one(Player.fixture(condition: 0.78, jadedness: 450)))
        #expect(a.level == .rest)
        #expect(a.reasons == ["Jadedness 450 is above his limit of 400: rest him from training and matches",
                              "Condition 78% is below the 85% floor"])
        #expect(a.jadedness == 450)
        #expect(a.condition == 0.78)
        let holiday = try #require(try one(Player.fixture(condition: 0.78, jadedness: 640)))
        #expect(holiday.reasons == ["Jadedness 640 is more than 200 above his limit of 400: a holiday clears it fastest",
                                    "Condition 78% is below the 85% floor"])
        let p = Player.fixture(jadedness: 330)
        let watch = try #require(try one(p, history: starts(p, daysFromAsOf: [0, -3, -6, -9], slot: .D_L)))
        #expect(watch.reasons == ["Jadedness 330 is close to his limit of 400",
                                  "Has started the last 4 matches in quick succession"])
    }

    @Test func theBasisIsTheWeakestEvidenceBehindTheAdvice() throws {
        #expect(try one(Player.fixture(jadedness: 450))?.basis == .fm27Observation)
        #expect(try one(Player.fixture(age: 32, jadedness: 450))?.basis == .carriedOverFM26)
        #expect(try one(Player.fixture(jadedness: 640))?.basis == .derived)
        #expect(try one(Player.fixture(condition: 0.80))?.basis == .carriedOverFM26)
        // Watch rests on restWatchShare and the consecutive-starts parameters.
        #expect(try one(Player.fixture(jadedness: 350))?.basis == .derived)
        var q = parameters
        q.consecutiveStartWindowDays = Parameter(4, .fm27Measured, source: "test")
        #expect(try one(Player.fixture(jadedness: 350), parameters: q)?.basis == .carriedOverFM26)
    }

    // MARK: Who is listed and in what order

    @Test func injuredAndLoanedOutPlayersAreNotListed() throws {
        let injured = Player.fixture(name: "Injured", jadedness: 700, isInjured: true)
        let loanedOut = Player.fixture(name: "Away", jadedness: 700, loanedTo: "Elsewhere FC")
        let loanedIn = Player.fixture(name: "Here", jadedness: 700, club: "Elsewhere FC")
        let found = try advice([injured, loanedOut, loanedIn])
        #expect(found.map(\.name) == ["Here"])
    }

    @Test func aMissingNaturalFitnessIsAnErrorThatNamesThePlayer() throws {
        var p = Player.fixture(name: "No Fitness")
        p.attributes[.naturalFitness] = nil
        #expect(throws: RatingError.missingAttribute(player: "No Fitness", attribute: .naturalFitness)) {
            try advice([p])
        }
        // An injured player is not looked at.
        p.isInjured = true
        #expect(try advice([p]).isEmpty)
    }

    @Test func badParametersAreAnError() throws {
        var q = parameters
        q.holidayJadednessRecoveryPerDay = Parameter(0, .derived, source: "test")
        #expect(throws: PlanError.self) { try advice([Player.fixture(jadedness: 700)], parameters: q) }
    }

    var mixedSquad: (players: [Player], history: [ConfirmedLineup]) {
        let runner = Player.fixture(name: "Runner", jadedness: -500)
        let players = [
            Player.fixture(name: "Watch Close", jadedness: 350),
            Player.fixture(name: "Rest Low Condition", condition: 0.6, jadedness: 0),
            Player.fixture(name: "Holiday", jadedness: 700),
            Player.fixture(name: "Rest B", jadedness: 450),
            Player.fixture(name: "Rest A", jadedness: 450),
            Player.fixture(name: "Rest Higher", jadedness: 500),
            runner,
            Player.fixture(name: "Fresh", jadedness: 100),
        ]
        return (players, starts(runner, daysFromAsOf: [0, -3], slot: .D_R))
    }

    @Test func theListIsMostUrgentFirst() throws {
        let found = try advice(mixedSquad.players, history: mixedSquad.history)
        #expect(found.map(\.name) == ["Holiday", "Rest Higher", "Rest A", "Rest B", "Rest Low Condition", "Watch Close", "Runner"])
        #expect(found.map(\.level) == [.holiday, .rest, .rest, .rest, .rest, .watch, .watch])
    }

    @Test func inputOrderDoesNotMatter() throws {
        let forward = try advice(mixedSquad.players, history: mixedSquad.history)
        let backward = try advice(mixedSquad.players.reversed(), history: mixedSquad.history.reversed())
        #expect(forward == backward)
    }
}
