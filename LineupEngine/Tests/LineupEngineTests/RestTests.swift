import Testing
@testable import LineupEngine

@Suite struct RestTests {
    let asOf = Day(iso: "2026-11-13")!
    let parameters = EngineParameters.fm27

    func advice(_ players: [Player], history: [ConfirmedLineup] = [], ownClub: String? = "Oxford City",
                intensity: TrainingIntensity = .medium, trends: FitnessTrends = .none,
                parameters: EngineParameters? = nil) throws -> [RestAdvice] {
        try Rest.advice(players: players, ownClub: ownClub, history: StartHistory(history), asOf: asOf,
                        intensity: intensity, trends: trends, parameters: parameters ?? self.parameters)
    }

    func one(_ player: Player, history: [ConfirmedLineup] = [], trends: FitnessTrends = .none,
             parameters: EngineParameters? = nil) throws -> RestAdvice? {
        let found = try advice([player], history: history, trends: trends, parameters: parameters)
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
        // Jadedness 340 over a limit of 300 needs (340 − 240) / 20 = 5 days; condition needs 10 at the full rate, and 11
        // while jadedness above 0 slows its return (the factor is 0.886 at 340, rising to 1 as jadedness falls).
        let p = Player.fixture(age: 32, condition: 0.75 - 10 * 0.015625, jadedness: 340)
        #expect(try one(p, parameters: flatRecovery)?.days == 11)
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

    // MARK: The lineup's jadedness line

    /// A 25-year-old with a limit of 530: Natural Fitness 18, Stamina 18, Injury Proneness 5.
    func hardy(jadedness: Int, condition: Double = 1) -> Player {
        Player.fixture(attributes: [.naturalFitness: 18, .stamina: 18, .injuryProneness: 5], condition: condition,
                       jadedness: jadedness)
    }

    @Test func aboveTheLineupsLineHeIsRestedWhateverHisLimit() throws {
        try #require(try limit(hardy(jadedness: 410)).limit == 530)
        let a = try #require(try one(hardy(jadedness: 410)))
        #expect(a.level == .rest)
        #expect(a.reasons == ["Jadedness 410 is above 400: the lineup leaves him out of all but high-importance matches"])
        // Down to 400, the lower of his watch line (424) and the lineup's line: (410 − 400) / 20 rounds up to 1.
        #expect(a.days == 1)
        // At 450, down to 400 takes 3 days; down to his watch line would take 2.
        #expect(try one(hardy(jadedness: 450))?.days == 3)
    }

    @Test func atTheLineupsLineHeIsNotListedForIt() throws {
        #expect(try one(hardy(jadedness: 400)) == nil)
    }

    @Test func withTheStandardLimitTheLineIsNamedOnce() throws {
        let a = try #require(try one(Player.fixture(jadedness: 410)))
        #expect(a.reasons == ["Jadedness 410 is above his limit of 400: rest him from training and matches"])
        #expect(a.days == 5)
    }

    @Test func belowTheLineupsLineHisOwnLimitDecides() throws {
        // Aged 32, a limit of 300: (350 − 240) / 20 rounds up to 6.
        let a = try #require(try one(Player.fixture(age: 32, jadedness: 350)))
        #expect(a.level == .rest)
        #expect(a.reasons == ["Jadedness 350 is above his limit of 300: rest him from training and matches"])
        #expect(a.days == 6)
    }

    @Test func overBothLinesBothAreNamedAndTheLowerLineSetsTheDays() throws {
        // A limit of 300, so his watch line (240) is lower than 400: (450 − 240) / 20 rounds up to 11.
        let a = try #require(try one(Player.fixture(age: 32, condition: 0.78, jadedness: 450)))
        #expect(a.reasons == ["Jadedness 450 is above his limit of 300: rest him from training and matches",
                              "Jadedness 450 is above 400: the lineup leaves him out of all but high-importance matches",
                              "Condition 78% is below the 85% floor"])
        let b = try #require(try one(Player.fixture(age: 32, jadedness: 450)))
        #expect(b.days == 11)
        // The reason comes after the holiday reason and before the condition reason.
        let holiday = try #require(try one(hardy(jadedness: 740, condition: 0.78)))
        #expect(holiday.level == .holiday)
        #expect(holiday.reasons == ["Jadedness 740 is more than 200 above his limit of 530: a holiday clears it fastest",
                                    "Jadedness 740 is above 400: the lineup leaves him out of all but high-importance matches",
                                    "Condition 78% is below the 85% floor"])
        // A holiday too runs down to 400: (740 − 400) / 50 rounds up to 7.
        #expect(try one(hardy(jadedness: 740))?.days == 7)
    }

    @Test func theLineIsJadedThreshold() throws {
        var q = parameters
        q.jadedThreshold = Parameter(420, .fm27Observation, source: "test")
        // The standard limit moves with it: his becomes 550, and 421 is under his watch line of 440.
        #expect(try one(hardy(jadedness: 410), parameters: q) == nil)
        #expect(try one(hardy(jadedness: 421), parameters: q)?.reasons
                == ["Jadedness 421 is above 420: the lineup leaves him out of all but high-importance matches"])
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
        // Over the standard 400 line, with days: the days rest on restWatchShare and jadednessRecoveryPerDay.
        #expect(try one(Player.fixture(jadedness: 450))?.basis == .carriedOverFM26)
        #expect(try one(Player.fixture(age: 32, jadedness: 450))?.basis == .carriedOverFM26)
        #expect(try one(Player.fixture(jadedness: 640))?.basis == .derived)
        #expect(try one(Player.fixture(condition: 0.80))?.basis == .carriedOverFM26)
        // Watch rests on restWatchShare and the consecutive-starts parameters.
        #expect(try one(Player.fixture(jadedness: 350))?.basis == .derived)
        var q = parameters
        q.consecutiveStartWindowDays = Parameter(4, .fm27Measured, source: "test")
        #expect(try one(Player.fixture(jadedness: 350), parameters: q)?.basis == .carriedOverFM26)
    }

    /// The parameters with `names` given `evidence`, values unchanged.
    func relabelled(_ names: Set<String>, _ evidence: Evidence, in base: EngineParameters? = nil) -> EngineParameters {
        var q = base ?? parameters
        func relabel<T>(_ p: Parameter<T>) -> Parameter<T> { Parameter(p.value, evidence, source: "test") }
        if names.contains("restWatchShare") { q.restWatchShare = relabel(q.restWatchShare) }
        if names.contains("jadednessRecoveryPerDay") { q.jadednessRecoveryPerDay = relabel(q.jadednessRecoveryPerDay) }
        if names.contains("holidayJadednessRecoveryPerDay") { q.holidayJadednessRecoveryPerDay = relabel(q.holidayJadednessRecoveryPerDay) }
        if names.contains("holidayMargin") { q.holidayMargin = relabel(q.holidayMargin) }
        if names.contains("conditionFloor") { q.conditionFloor = relabel(q.conditionFloor) }
        if names.contains("conditionRecoveryPerDay") { q.conditionRecoveryPerDay = relabel(q.conditionRecoveryPerDay) }
        if names.contains("naturalFitnessRecoveryPerPoint") { q.naturalFitnessRecoveryPerPoint = relabel(q.naturalFitnessRecoveryPerPoint) }
        if names.contains("trainingIntensityRecovery") { q.trainingIntensityRecovery = relabel(q.trainingIntensityRecovery) }
        if names.contains("restConditionEstimateDays") { q.restConditionEstimateDays = relabel(q.restConditionEstimateDays) }
        return q
    }

    @Test func theParametersBehindTheDaysJoinTheBasis() throws {
        // A rest for jadedness: restWatchShare and jadednessRecoveryPerDay.
        let measured = relabelled(["restWatchShare", "jadednessRecoveryPerDay"], .fm27Measured)
        #expect(try one(Player.fixture(jadedness: 450), parameters: measured)?.basis == .fm27Observation)
        let slow = relabelled(["jadednessRecoveryPerDay"], .derived, in: measured)
        #expect(try one(Player.fixture(jadedness: 450), parameters: slow)?.basis == .derived)
        // A holiday: holidayJadednessRecoveryPerDay, not jadednessRecoveryPerDay.
        let holiday = relabelled(["restWatchShare", "holidayMargin", "holidayJadednessRecoveryPerDay"], .fm27Measured, in: slow)
        #expect(try one(Player.fixture(jadedness: 640), parameters: holiday)?.basis == .fm27Observation)
        let slowHoliday = relabelled(["holidayJadednessRecoveryPerDay"], .derived, in: holiday)
        #expect(try one(Player.fixture(jadedness: 640), parameters: slowHoliday)?.basis == .derived)
        // Low condition: the condition-recovery parameters, while the days are known.
        let condition = relabelled(["conditionFloor", "naturalFitnessRecoveryPerPoint", "trainingIntensityRecovery",
                                    "restConditionEstimateDays"], .fm27Measured)
        #expect(try one(Player.fixture(condition: 0.80), parameters: condition)?.basis == .carriedOverFM26)
        var oneDay = relabelled(["conditionRecoveryPerDay"], .derived, in: condition)
        #expect(try one(Player.fixture(condition: 0.80), parameters: oneDay)?.basis == .derived)
        // Looking one day ahead, 80% is clear in a day but 70% is not: with no days, the recovery is not behind it.
        oneDay.restConditionEstimateDays = Parameter(1, .fm27Measured, source: "test")
        #expect(try one(Player.fixture(condition: 0.80), parameters: oneDay)?.days == 1)
        let unknown = try #require(try one(Player.fixture(condition: 0.70), parameters: oneDay))
        #expect(unknown.days == nil)
        #expect(unknown.basis == .fm27Observation)
    }

    @Test func theMiddleAgeBandIsNamedForItsWidth() throws {
        var rules = parameters.restLimitRules.value
        rules.olderFromAge = 30
        rules.oldestFromAge = 33
        var wide = parameters
        wide.restLimitRules = Parameter(rules, .carriedOverFM26, source: "test")
        #expect(try limit(Player.fixture(age: 32), parameters: wide) == (350, ["aged 30 to 32"]))
        #expect(try limit(Player.fixture(age: 33), parameters: wide) == (300, ["aged 33 or over"]))
        // Two years: "or".
        #expect(try limit(Player.fixture(age: 31)) == (350, ["aged 30 or 31"]))
        // One year: just the age.
        rules.oldestFromAge = 31
        var narrow = parameters
        narrow.restLimitRules = Parameter(rules, .carriedOverFM26, source: "test")
        #expect(try limit(Player.fixture(age: 30), parameters: narrow) == (350, ["aged 30"]))
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

    // MARK: His trend

    /// Trends for one player, built by hand.
    func trends(_ player: Player, seen: SeenTrend? = nil, drift: MeasuredRate? = nil, gain: MeasuredRate? = nil,
                used: Int = 0, squadDrift: [Squad: SharedRate] = [:]) -> FitnessTrends {
        FitnessTrends(players: [player.id: PlayerTrend(seen: seen, drift: drift, gain: gain, usedIntervals: used,
                                                       hasCountedReading: true)],
                      squadDrift: squadDrift, clubGain: nil, measuredFrom: nil)
    }

    func rising(_ perWeek: Double, starts: Int = 3) -> SeenTrend {
        SeenTrend(perWeek: perWeek, days: 35, starts: starts, readings: 6)
    }

    @Test func aPlayerOnCourseToPassTheLineWithinSixWeeksIsWatched() throws {
        // (400 − 190) ÷ (35 ÷ 7) = 42 days.
        let p = Player.fixture(jadedness: 190)
        let a = try #require(try one(p, trends: trends(p, seen: rising(35), used: 5)))
        #expect(a.level == .watch)
        #expect(a.trend.passesOn == asOf.adding(days: 42))
        #expect(a.reasons.isEmpty)
        #expect(a.basis == .derived)
        #expect(a.days == nil)
        #expect(a.trend.seen == rising(35))
        // The basis takes in the line's evidence as well as the trend rules'.
        var q = parameters
        q.jadednessTrendRules = Parameter(q.jadednessTrendRules.value, .fm27Measured, source: "test")
        #expect(try one(p, trends: trends(p, seen: rising(35), used: 5), parameters: q)?.basis
                == parameters.jadedThreshold.evidence)
        // With nothing measured he is not listed.
        #expect(try one(p) == nil)
    }

    @Test func atFortyThreeDaysHeIsNotListed() throws {
        let p = Player.fixture(jadedness: 185)
        #expect(try one(p, trends: trends(p, seen: rising(35), used: 5)) == nil)
    }

    @Test func aSquadsRateAloneListsNobody() throws {
        let p = Player.fixture(jadedness: 190)
        let squad = SharedRate(value: 10, readings: 20, since: asOf.adding(days: -30))
        #expect(try one(p, trends: trends(p, drift: MeasuredRate(10, .squad(.firstTeam)), used: 2,
                                          squadDrift: [.firstTeam: squad])) == nil)
        // Nor the club's gain with it.
        #expect(try one(p, trends: trends(p, drift: MeasuredRate(10, .squad(.firstTeam)), gain: MeasuredRate(60, .club),
                                          used: 2)) == nil)
    }

    @Test func aFallingTrendListsNobody() throws {
        let p = Player.fixture(jadedness: 300)
        #expect(try one(p, trends: trends(p, seen: rising(-20), used: 5)) == nil)
        // A steady one neither: 5 a week is within the band.
        #expect(try one(p, trends: trends(p, seen: rising(5), used: 5)) == nil)
        let a = try #require(try one(p, trends: trends(p, seen: rising(35), used: 5)))
        #expect(a.level == .watch)
        // (400 − 300) ÷ 5 = 20 days.
        #expect(a.trend.passesOn == asOf.adding(days: 20))
    }

    @Test func aPlayerAboveTheLineIsNotOnCourseButKeepsHisLevel() throws {
        // Over the line, rising: listed at rest as before, with no date to pass a line he has passed.
        let p = Player.fixture(jadedness: 450)
        let a = try #require(try one(p, trends: trends(p, seen: rising(35), used: 5)))
        #expect(a.level == .rest)
        #expect(a.trend.passesOn == nil)
        #expect(a.reasons == ["Jadedness 450 is above his limit of 400: rest him from training and matches"])
    }

    @Test func thePassDateIsGivenOnlyWithinItsDays() throws {
        // Aged 32, limit 300 (watch line 240): listed for being close, whatever his trend.
        let near = Player.fixture(age: 32, jadedness: 250)
        // (400 − 250) ÷ (6 ÷ 7) = 175 days: beyond 120.
        let far = try #require(try one(near, trends: trends(near, seen: rising(6), used: 5)))
        #expect(far.trend.passesOn == nil)
        #expect(far.reasons == ["Jadedness 250 is close to his limit of 300"])
        // (400 − 250) ÷ (10 ÷ 7) = 105 days, rounded up from 105.
        let within = try #require(try one(near, trends: trends(near, seen: rising(10), used: 5)))
        #expect(within.trend.passesOn == asOf.adding(days: 105))
        // A day count that is not whole is rounded up: 150 ÷ (8 ÷ 7) = 131.25, beyond; 150 ÷ (9 ÷ 7) = 116.7, 117.
        #expect(try one(near, trends: trends(near, seen: rising(9), used: 5))?.trend.passesOn == asOf.adding(days: 117))
        var q = parameters
        var rules = q.jadednessTrendRules.value
        rules.passDateWithinDays = 116
        q.jadednessTrendRules = Parameter(rules, .derived, source: "test")
        #expect(try one(near, trends: trends(near, seen: rising(9), used: 5), parameters: q)?.trend.passesOn == nil)
    }

    @Test func aListedPlayerCarriesHisTrend() throws {
        let p = Player.fixture(name: "Young", squad: .u21, jadedness: 450)
        let drift = MeasuredRate(-10, .squad(.u21)), gain = MeasuredRate(55, .club)
        let a = try #require(try one(p, trends: trends(p, seen: rising(-14), drift: drift, gain: gain, used: 4)))
        #expect(a.trend == RestTrend(squad: .u21, seen: rising(-14), imports: 5, importsNeeded: 4, passesOn: nil,
                                     drift: drift, gain: gain, restWillNotClear: false, basis: .derived))
        // A reading and no used interval counts as one import.
        let b = try #require(try one(p, trends: trends(p, used: 0)))
        #expect(b.trend.imports == 1)
        #expect(b.trend.seen == nil)
    }

    @Test func aListedPlayerWithNoReadingsHasNoImports() throws {
        let a = try #require(try one(Player.fixture(jadedness: 450)))
        #expect(a.trend.imports == 0)
        #expect(a.trend.importsNeeded == 4)
        #expect(a.trend.seen == nil && a.trend.drift == nil && a.trend.gain == nil && a.trend.passesOn == nil)
        #expect(!a.trend.restWillNotClear)
        #expect(a.trend.basis == parameters.jadednessTrendRules.evidence)
        #expect(a.trend.squad == .firstTeam)
    }

    @Test func daysUntilClearUseTheDriftHeTakes() throws {
        // Jadedness 450, limit 400, watch line 320: 130 ÷ 10 = 13 days.
        let p = Player.fixture(jadedness: 450)
        let a = try #require(try one(p, trends: trends(p, drift: MeasuredRate(-10, .squad(.firstTeam)), used: 2)))
        #expect(a.days == 13)
        #expect(!a.trend.restWillNotClear)
        #expect(a.basis == .derived)
        // With nothing measured: 130 ÷ 20, rounded up, as before.
        #expect(try one(p)?.days == 7)
        // His own drift counts the same.
        #expect(try one(p, trends: trends(p, drift: MeasuredRate(-26, .own(intervals: 3)), used: 4))?.days == 5)
    }

    @Test func theDriftsEvidenceJoinsTheBasisOfTheDays() throws {
        // Every label FM27 measured but the trend rules': the days rest on them, so the basis is theirs.
        let p = Player.fixture(jadedness: 450)
        var q = relabelled(["restWatchShare", "jadednessRecoveryPerDay"], .fm27Measured)
        q.jadedThreshold = Parameter(q.jadedThreshold.value, .fm27Measured, source: "test")
        q.jadednessTrendRules = Parameter(q.jadednessTrendRules.value, .carriedOverFM26, source: "test")
        let measured = try #require(try one(p, trends: trends(p, drift: MeasuredRate(-10, .squad(.firstTeam)), used: 2),
                                            parameters: q))
        #expect(measured.basis == .carriedOverFM26)
        #expect(try one(p, parameters: q)?.basis == .fm27Measured)
    }

    @Test func aMeasuredDriftGivesDaysOnlyWithinTheDaysAheadADateIsGiven() throws {
        // Jadedness 450, limit 400, watch line 320: 130 to fall.
        let p = Player.fixture(jadedness: 450)
        func withDrift(_ perDay: Double) throws -> RestAdvice {
            try #require(try one(p, trends: trends(p, drift: MeasuredRate(perDay, .squad(.firstTeam)), used: 2)))
        }
        // 130 ÷ (130 ÷ 120) = 120 days: still given.
        #expect(try withDrift(-130.0 / 120).days == 120)
        // 121 days: no estimate, and rest from matches still clears it.
        let beyond = try withDrift(-130.0 / 121)
        #expect(beyond.days == nil)
        #expect(!beyond.trend.restWillNotClear)
        #expect(AdvisorText.clear(in: beyond) == "Clear in more days than the estimate covers")
        // −0.1 a day would take 1,300 days.
        let slow = try withDrift(-0.1)
        #expect(slow.days == nil && !slow.trend.restWillNotClear)
        // The fixed figure and the holiday estimate are not capped by it.
        var q = parameters
        var rules = q.jadednessTrendRules.value
        rules.passDateWithinDays = 5
        q.jadednessTrendRules = Parameter(rules, .derived, source: "test")
        #expect(try one(p, parameters: q)?.days == 7)
        let tired = Player.fixture(jadedness: 650)
        let holiday = try #require(try one(tired, trends: trends(tired, drift: MeasuredRate(-0.1, .squad(.firstTeam)),
                                                                 used: 2), parameters: q))
        let unmeasured = try one(tired)?.days
        #expect(holiday.level == .holiday && holiday.days == unmeasured && holiday.days != nil)
    }

    @Test func noDaysWhenRestFromMatchesWillNotClearIt() throws {
        let p = Player.fixture(jadedness: 450)
        let a = try #require(try one(p, trends: trends(p, drift: MeasuredRate(2, .squad(.firstTeam)), used: 2)))
        #expect(a.days == nil)
        #expect(a.trend.restWillNotClear)
        #expect(AdvisorText.clear(in: a) == nil)
        #expect(a.level == .rest)
        // A drift of exactly 0 will not clear it either.
        let zero = try #require(try one(p, trends: trends(p, drift: MeasuredRate(0, .own(intervals: 3)), used: 4)))
        #expect(zero.days == nil && zero.trend.restWillNotClear)
        // Above the lineup's line with a higher limit of his own, the same.
        let h = hardy(jadedness: 450)
        let over = try #require(try one(h, trends: trends(h, drift: MeasuredRate(2, .squad(.firstTeam)), used: 2)))
        #expect(over.level == .rest && over.days == nil && over.trend.restWillNotClear)
    }

    @Test func restWillNotClearOnlyForAPlayerOverALine() throws {
        // Watched for being close, with a rising drift: there is nothing to clear.
        let p = Player.fixture(jadedness: 350)
        let a = try #require(try one(p, trends: trends(p, drift: MeasuredRate(2, .squad(.firstTeam)), used: 2)))
        #expect(a.level == .watch && !a.trend.restWillNotClear)
        // Rested for low condition alone, the same.
        let low = Player.fixture(condition: 0.6, jadedness: 0)
        let b = try #require(try one(low, trends: trends(low, drift: MeasuredRate(2, .squad(.firstTeam)), used: 2)))
        #expect(b.level == .rest && !b.trend.restWillNotClear && b.days != nil)
    }

    @Test func aPlayerNeedingAHolidayKeepsTheHolidayEstimate() throws {
        let p = Player.fixture(jadedness: 650)
        let before = try #require(try one(p))
        let a = try #require(try one(p, trends: trends(p, drift: MeasuredRate(2, .squad(.firstTeam)), used: 2)))
        #expect(a.level == .holiday)
        #expect(a.days == before.days)
        #expect(a.days != nil)
        #expect(!a.trend.restWillNotClear)
        #expect(a.basis == before.basis)
    }

    @Test func conditionDaysMoveJadednessByHisMeasuredPair() throws {
        // Condition below the floor at jadedness 390, under his limit: rest days bring condition back more slowly while
        // jadedness is above 0, and his pair takes it up where the fixed figures bring it down.
        let p = Player.fixture(condition: 0.75 - 8 * 0.015625, jadedness: 390)
        let pair = JadednessRates(drift: MeasuredRate(60, .own(intervals: 3)), gain: MeasuredRate(60, .own(intervals: 3)))
        func expected(_ rates: JadednessRates?) throws -> Int {
            var fitness = ProjectedFitness(p)
            var days = 0
            while fitness.condition < flatRecovery.conditionFloor.value {
                fitness = try FitnessProjection.afterDays(1, fitness, player: p, intensity: .medium, rates: rates,
                                                          parameters: flatRecovery)
                days += 1
            }
            return days
        }
        let withPair = try expected(pair), without = try expected(nil)
        #expect(withPair > without)
        let measured = trends(p, seen: rising(10), drift: pair.drift, gain: pair.gain, used: 5)
        let a = try #require(try one(p, trends: measured, parameters: flatRecovery))
        #expect(a.level == .rest && a.days == withPair)
        #expect(try one(p, parameters: flatRecovery)?.days == without)
        // A drift with no gain is no pair: the fixed figures, as before.
        #expect(try one(p, trends: trends(p, drift: pair.drift, used: 2), parameters: flatRecovery)?.days == without)
    }

    @Test func aTrendTheAdviceDoesNotFollowChangesOnlyHisTrend() throws {
        // A player who needs a holiday keeps his holiday estimate whatever his trend, and the other players are not his.
        let holiday = try #require(mixedSquad.players.first { $0.name == "Holiday" })
        let measured = trends(holiday, seen: rising(35), drift: MeasuredRate(5, .own(intervals: 3)),
                              gain: MeasuredRate(60, .own(intervals: 3)), used: 5)
        let before = try advice(mixedSquad.players, history: mixedSquad.history)
        let after = try advice(mixedSquad.players, history: mixedSquad.history, trends: measured)
        try #require(after.count == before.count)
        for (now, then) in zip(after, before) {
            #expect(now.player == then.player)
            #expect(now.level == then.level)
            #expect(now.days == then.days)
            #expect(now.reasons == then.reasons)
            #expect(now.basis == then.basis)
            if now.player == holiday.id {
                #expect(now.trend.seen == rising(35))
                #expect(now.trend != then.trend)
            } else {
                #expect(now == then)
            }
        }
        #expect(after.first?.player == holiday.id && after.first?.level == .holiday && after.first?.days != nil)
    }

    // MARK: The imports that count

    /// What `FitnessTrend.rates` makes of `player`'s readings on the days given, counted back from `asOf`, with the
    /// owner's measure-from day `from` days back.
    func measured(_ player: Player, readingsDaysBack: [Int], from: Int?) -> FitnessTrends {
        let readings = readingsDaysBack.map {
            FitnessReading(day: asOf.adding(days: -$0), jadedness: 450, condition: 1, sharpness: 1, isInjured: false,
                           includes: [])
        }
        return FitnessTrend.rates(readings: [player.id: readings], confirmed: [], squads: [player.id: player.squad],
                                  asOf: asOf, measureFrom: from.map { asOf.adding(days: -$0) }, parameters: parameters)
    }

    @Test func aReadingBeforeTheMeasureFromDayIsNotCounted() throws {
        let p = Player.fixture(jadedness: 450)
        // His only reading is before the day the owner said to measure from.
        let none = try #require(try one(p, trends: measured(p, readingsDaysBack: [10], from: 5)))
        #expect(none.trend.imports == 0)
        #expect(AdvisorText.trendLines(of: none, parameters: parameters).first
                == "His trend is not measured yet: it needs 4 imports of his squad, and has 0.")
        // One reading on or after it counts as one import; the interval from before it does not.
        let one = try #require(try self.one(p, trends: measured(p, readingsDaysBack: [10, 3], from: 5)))
        #expect(one.trend.imports == 1)
        #expect(AdvisorText.trendLines(of: one, parameters: parameters).first
                == "His trend is not measured yet: it needs 4 imports of his squad, and has 1.")
        // A reading on the day itself counts.
        let onTheDay = try #require(try self.one(p, trends: measured(p, readingsDaysBack: [5], from: 5)))
        #expect(onTheDay.trend.imports == 1)
        // With no measure-from day his reading counts.
        #expect(try self.one(p, trends: measured(p, readingsDaysBack: [10], from: nil))?.trend.imports == 1)
    }
}
