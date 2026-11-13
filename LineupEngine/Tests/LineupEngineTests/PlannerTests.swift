import Foundation
import Testing
@testable import LineupEngine

@Suite struct PlannerTests {
    let parameters = EngineParameters.fm27
    let planner: Planner
    let day0 = Day(year: 2026, month: 11, day: 14)!
    let tactic: Tactic
    let squad: [Player]

    init() throws {
        planner = Planner(catalog: try RoleCatalog.fm27(), profile: try RatingProfile.standard(), parameters: .fm27)
        tactic = try PlannerFixture.tactic()
        squad = try PlannerFixture.squad()
    }

    func day(_ n: Int) -> Day { day0.adding(days: n) }

    func fixture(_ id: String, _ importance: Importance = .medium, day n: Int, opponent: String? = nil,
                 overrides: [SlotID: PlayerID] = [:], rejected: Set<PlayerID> = []) -> Fixture {
        Fixture(id: FixtureID(id), date: day(n), opponent: opponent ?? "Opponent \(id)", importance: importance,
                tactic: tactic, overrides: overrides, rejected: rejected)
    }

    func request(_ fixtures: [Fixture], players: [Player]? = nil, asOf: Int = 0, confirmed: [ConfirmedLineup] = [],
                 retraining: [Retraining] = [], settings: PlanSettings = .standard) -> PlanRequest {
        PlanRequest(fixtures: fixtures, players: players ?? squad, ownClub: "Oxford City", asOf: day(asOf),
                    confirmed: confirmed, retraining: retraining, settings: settings)
    }

    func id(_ slot: SlotID, _ tier: String = "first") -> PlayerID { PlannerFixture.id(slot, tier) }

    /// The squad with the named player changed.
    func changing(_ slot: SlotID, _ tier: String = "first", in players: [Player]? = nil,
                  _ change: (inout Player) -> Void) -> [Player] {
        (players ?? squad).map { player in
            var player = player
            if player.id == id(slot, tier) { change(&player) }
            return player
        }
    }

    func pick(_ planned: PlannedFixture, _ slot: SlotID) -> Pick? { planned.lineup.picks.first { $0.slot == slot } }

    func starts(_ planned: PlannedFixture, _ player: PlayerID) -> Bool { planned.lineup.picks.contains { $0.player == player } }

    func assignment(_ slot: SlotID) throws -> SlotAssignment {
        try #require(try tactic.assignments(catalog: RoleCatalog.fm27()).first { $0.slot == slot })
    }

    // MARK: - Checks before planning

    @Test func noFixturesGivesAnEmptyPlan() throws {
        #expect(try planner.plan(request([])) == Plan(fixtures: []))
        // The settings, parameter and duplicate checks still run.
        #expect(throws: PlanError.badSettings(PlanSettings(horizon: 0).problems())) {
            try planner.plan(request([], settings: PlanSettings(horizon: 0)))
        }
        #expect(throws: DuplicatePlayerError.self) { try planner.plan(request([], players: squad + [squad[0]])) }
    }

    @Test func aFixtureBeforeTheSnapshotIsAnErrorThatNamesIt() throws {
        #expect(throws: PlanError.fixtureBeforeSnapshot(FixtureID("early"), date: day(1), asOf: day(2))) {
            try planner.plan(request([fixture("later", day: 5), fixture("early", day: 1)], asOf: 2))
        }
        // A fixture on the snapshot day is allowed.
        let plan = try planner.plan(request([fixture("today", day: 2)], asOf: 2))
        #expect(plan.fixtures.map(\.fixture) == [FixtureID("today")])
    }

    @Test func twoFixturesOnOneDayIsAnErrorThatNamesBoth() throws {
        // Named in fixture-id order, whatever order they were given in.
        #expect(throws: PlanError.fixturesOnTheSameDay(FixtureID("a"), FixtureID("b"), day(3))) {
            try planner.plan(request([fixture("b", day: 3), fixture("x", day: 6), fixture("a", day: 3)]))
        }
        // With several problems, the earliest date is reported.
        #expect(throws: PlanError.fixturesOnTheSameDay(FixtureID("c"), FixtureID("d"), day(1))) {
            try planner.plan(request([fixture("b", day: 3), fixture("a", day: 3), fixture("d", day: 1), fixture("c", day: 1)]))
        }
        #expect(throws: PlanError.fixtureBeforeSnapshot(FixtureID("p"), date: day(-2), asOf: day(0))) {
            try planner.plan(request([fixture("b", day: 3), fixture("a", day: 3), fixture("q", day: -2), fixture("p", day: -2)]))
        }
    }

    @Test func datesAreCheckedBeyondTheHorizon() throws {
        let fixtures = [fixture("a", day: 1), fixture("b", day: 4), fixture("c", day: 4)]
        #expect(throws: PlanError.fixturesOnTheSameDay(FixtureID("b"), FixtureID("c"), day(4))) {
            try planner.plan(request(fixtures, settings: PlanSettings(horizon: 1)))
        }
    }

    @Test func badSettingsAreReported() throws {
        let settings = PlanSettings(stability: 2, savingPlayers: .infinity, horizon: 0)
        #expect(settings.problems().count == 3)
        #expect(throws: PlanError.badSettings(settings.problems())) {
            try planner.plan(request([fixture("a", day: 1)], settings: settings))
        }
    }

    @Test func badParametersAreReported() throws {
        var broken = EngineParameters.fm27
        broken.positionConditionLoad = Parameter([:], .derived, source: "test")
        let expected = FitnessModel.problems(in: broken)
        try #require(!expected.isEmpty)
        let brokenPlanner = Planner(catalog: try RoleCatalog.fm27(), profile: try RatingProfile.standard(), parameters: broken)
        #expect(throws: PlanError.badParameters(expected)) { try brokenPlanner.plan(request([fixture("a", day: 1)])) }
        #expect(throws: PlanError.badParameters(expected)) { try brokenPlanner.plan(request([])) }
    }

    @Test func twoPlayersWithOneIdentityAreRefused() throws {
        var twin = squad[0]
        twin.name = "Someone Else"
        #expect(throws: DuplicatePlayerError(id: twin.id, names: [squad[0].name, "Someone Else"].sorted())) {
            try planner.plan(request([fixture("a", day: 1)], players: squad + [twin]))
        }
    }

    @Test func checksRunInOrderSettingsParametersPlayersDates() throws {
        var broken = EngineParameters.fm27
        broken.conditionCurve = Parameter([], .derived, source: "test")
        let brokenPlanner = Planner(catalog: try RoleCatalog.fm27(), profile: try RatingProfile.standard(), parameters: broken)
        let badSettings = PlanSettings(horizon: 0)
        let twins = squad + [squad[0]]
        let badDates = [fixture("a", day: -1)]

        #expect(throws: PlanError.badSettings(badSettings.problems())) {
            try brokenPlanner.plan(request(badDates, players: twins, asOf: 0, settings: badSettings))
        }
        #expect(throws: PlanError.badParameters(["conditionCurve is empty"])) {
            try brokenPlanner.plan(request(badDates, players: twins))
        }
        #expect(throws: DuplicatePlayerError.self) { try planner.plan(request(badDates, players: twins)) }
        #expect(throws: PlanError.fixtureBeforeSnapshot(FixtureID("a"), date: day(-1), asOf: day(0))) {
            try planner.plan(request(badDates))
        }
    }

    // MARK: - Which fixtures, in which order

    @Test func onlyTheHorizonIsPlanned() throws {
        let fixtures = [6, 2, 12, 0, 8, 4, 10].map { fixture("f\($0)", day: $0) }
        let plan = try planner.plan(request(fixtures, settings: PlanSettings(horizon: 5)))
        #expect(plan.fixtures.map(\.fixture.raw) == ["f0", "f2", "f4", "f6", "f8"])
        let all = try planner.plan(request(fixtures, settings: PlanSettings(horizon: 9)))
        #expect(all.fixtures.count == 7)
    }

    @Test func thePlanDoesNotDependOnInputOrder() throws {
        let fixtures = [fixture("a", .low, day: 1), fixture("b", .medium, day: 3), fixture("c", .high, day: 5),
                        fixture("d", .sharpness, day: 8)]
        let confirmed = [
            ConfirmedLineup(fixture: FixtureID("old1"), date: day(-4),
                            starters: [.D_L: id(.D_L), .ST_C: id(.ST_C), .AM_C: id(.AM_C, "second")]),
            ConfirmedLineup(fixture: FixtureID("old2"), date: day(-2),
                            starters: [.D_L: id(.D_L), .ST_C: id(.ST_C, "second"), .AM_C: id(.AM_C)]),
        ]
        let retraining = [
            Retraining(player: id(.AM_L, "second"), position: .defenderLeft, acceptedOn: day(-10)),
            Retraining(player: id(.AM_R, "second"), position: .striker, acceptedOn: day(-9)),
        ]
        let players = changing(.AM_L, "second") { $0.familiarity[.defenderLeft] = 12 }
        let base = try planner.plan(request(fixtures, players: players, confirmed: confirmed, retraining: retraining))
        // Players rotated by seven, fixtures and lists reversed: fixed permutations, so a failure repeats.
        let rotated = Array(players[7...] + players[..<7])
        let other = try planner.plan(request(fixtures.reversed(), players: rotated.reversed(), confirmed: confirmed.reversed(),
                                             retraining: retraining.reversed()))
        #expect(other == base)
        #expect(base.fixtures.map(\.fixture.raw) == ["a", "b", "c", "d"])
    }

    @Test func theSamePlanTwiceIsIdentical() throws {
        let fixtures = [fixture("a", .low, day: 1), fixture("b", .medium, day: 3), fixture("c", .high, day: 5)]
        #expect(try planner.plan(request(fixtures)) == planner.plan(request(fixtures)))
    }

    @Test func aDuplicateRetrainingEntryCountsOnceWhateverItsOrder() throws {
        let players = changing(.AM_L, "second") { $0.familiarity[.defenderLeft] = 12 }
        let entry = Retraining(player: id(.AM_L, "second"), position: .defenderLeft, acceptedOn: day(-10))
        let newer = Retraining(player: id(.AM_L, "second"), position: .defenderLeft, acceptedOn: day(-3))
        let fixtures = [fixture("a", .low, day: 1)]
        let once = try planner.plan(request(fixtures, players: players, retraining: [entry]))
        let twice = try planner.plan(request(fixtures, players: players, retraining: [entry, newer, entry]))
        let reversed = try planner.plan(request(fixtures, players: players, retraining: [newer, entry, entry]))
        #expect(twice == once)
        #expect(reversed == once)
    }

    // MARK: - Projection

    @Test func startersArriveAtTheNextFixtureLessFreshThanThoseWhoRested() throws {
        // Weak cover, so the first eleven starts the first fixture whatever happens.
        let players = try PlannerFixture.squad(first: 14, second: 6)
        let plan = try planner.plan(request([fixture("a", day: 1), fixture("b", day: 4)], players: players))
        let first = plan.fixtures[0]
        let second = plan.fixtures[1]
        let starter = id(.ST_C)
        let rested = id(.ST_C, "second")
        try #require(starts(first, starter) && !starts(first, rested))

        let starterAfter = try #require(second.fitness[starter])
        let restedAfter = try #require(second.fitness[rested])
        #expect(starterAfter.condition < restedAfter.condition)

        // By hand: one day from the snapshot, the match at ST, three days to the next fixture.
        let player = try #require(players.first { $0.id == starter })
        let atFirst = try FitnessProjection.afterDays(1, ProjectedFitness(player), player: player, intensity: .medium,
                                                      parameters: parameters)
        #expect(first.fitness[starter] == atFirst)
        let played = try FitnessProjection.afterMatch(atFirst, player: player, position: try assignment(.ST_C).ipPosition,
                                                      parameters: parameters)
        let byHand = try FitnessProjection.afterDays(3, played, player: player, intensity: .medium, parameters: parameters)
        #expect(abs(starterAfter.condition - byHand.condition) < 1e-9)
        #expect(abs(starterAfter.sharpness - byHand.sharpness) < 1e-9)
        #expect(abs(starterAfter.jadedness - byHand.jadedness) < 1e-9)
        #expect(starterAfter.daysSinceMatch == 3)
        #expect(restedAfter.daysSinceMatch == nil)
        // Every player has a figure at every fixture.
        #expect(plan.fixtures.allSatisfy { Set($0.fitness.keys) == Set(players.map(\.id)) })
    }

    @Test func theTrainingIntensityScalesRecovery() throws {
        let players = try PlannerFixture.squad(first: 14, second: 6)
        let fixtures = [fixture("a", day: 0), fixture("b", day: 2)]
        let low = try planner.plan(request(fixtures, players: players, settings: PlanSettings(trainingIntensity: .low)))
        let high = try planner.plan(request(fixtures, players: players, settings: PlanSettings(trainingIntensity: .high)))
        let st = id(.ST_C)
        #expect(try #require(low.fixtures[1].fitness[st]).condition > #require(high.fixtures[1].fitness[st]).condition)
    }

    @Test func daysBetweenTheSnapshotAndTheFirstFixtureAreProjected() throws {
        let players = changing(.ST_C) { $0.condition = 0.80 }
        let later = try planner.plan(request([fixture("a", day: 4)], players: players))
        let fitness = try #require(later.fixtures[0].fitness[id(.ST_C)])
        #expect(fitness.condition > 0.80)
        let st = try #require(pick(later.fixtures[0], .ST_C))
        #expect(st.player == id(.ST_C))
        #expect(st.reasons.contains { $0.hasPrefix("Projected condition") })

        // On the snapshot day nothing is projected: he is below the floor, and the reasons say so plainly.
        let today = try planner.plan(request([fixture("a", day: 0)], players: players))
        #expect(today.fixtures[0].fitness[id(.ST_C)]?.condition == 0.80)
        #expect(!starts(today.fixtures[0], id(.ST_C)))
        #expect(today.fixtures[0].lineup.omissions.first { $0.player == id(.ST_C) }?.reason
            == "Left out: below the 85% condition floor at 80%")
    }

    @Test func projectedJadednessIsRoundedForTheSelector() throws {
        // 7 rest days from 401 at 20 a day is 261; a fractional rate would give a fraction.
        var params = EngineParameters.fm27
        params.jadednessRecoveryPerDay = Parameter(20.4, .derived, source: "test")
        let custom = Planner(catalog: try RoleCatalog.fm27(), profile: try RatingProfile.standard(), parameters: params)
        let players = changing(.AM_C, in: try PlannerFixture.squad(first: 14, second: 6)) { $0.jadedness = 401 }
        let plan = try custom.plan(request([fixture("a", day: 7)], players: players))
        let projected = try #require(plan.fixtures[0].fitness[id(.AM_C)]).jadedness
        #expect(abs(projected - (401 - 7 * 20.4)) < 1e-9)
        let am = try #require(pick(plan.fixtures[0], .AM_C))
        #expect(am.player == id(.AM_C))
        #expect(am.reasons.contains("Projected jadedness \(Int(projected.rounded())) (×0.90)"))
    }

    // MARK: - The manager's choices

    @Test func aBanAppliesToTheFirstFixtureOnly() throws {
        let players = changing(.ST_C) { $0.isBanned = true }
        let plan = try planner.plan(request([fixture("a", day: 1), fixture("b", day: 5)], players: players))
        #expect(!starts(plan.fixtures[0], id(.ST_C)))
        #expect(plan.fixtures[0].lineup.omissions.first { $0.player == id(.ST_C) }?.cause == .excluded(.banned))
        #expect(starts(plan.fixtures[1], id(.ST_C)))
    }

    @Test func anInjuredPlayerMissesEveryFixture() throws {
        let players = changing(.ST_C) { $0.isInjured = true }
        let plan = try planner.plan(request([fixture("a", day: 1), fixture("b", day: 30)], players: players))
        for planned in plan.fixtures {
            #expect(!starts(planned, id(.ST_C)))
            #expect(planned.lineup.omissions.first { $0.player == id(.ST_C) }?.cause == .excluded(.injured))
        }
    }

    @Test func anOverrideAndARejectionApplyToTheirOwnFixtureOnly() throws {
        let players = try PlannerFixture.squad(first: 14, second: 6)
        let fixtures = [fixture("a", day: 1, overrides: [.ST_C: id(.ST_C, "second")], rejected: [id(.AM_C)]),
                        fixture("b", day: 8)]
        let plan = try planner.plan(request(fixtures, players: players, settings: PlanSettings(stability: 0)))
        let first = plan.fixtures[0]
        let second = plan.fixtures[1]
        let st = try #require(pick(first, .ST_C))
        #expect(st.player == id(.ST_C, "second") && st.isOverride)
        #expect(!starts(first, id(.AM_C)))
        #expect(first.lineup.omissions.first { $0.player == id(.AM_C) }?.cause == .excluded(.rejected))
        #expect(pick(second, .ST_C)?.player == id(.ST_C))
        #expect(pick(second, .AM_C)?.player == id(.AM_C))
        #expect(pick(second, .ST_C)?.isOverride == false)

        // The overridden starter is projected as a starter.
        let player = try #require(players.first { $0.id == id(.ST_C, "second") })
        let atFirst = try #require(first.fitness[player.id])
        let played = try FitnessProjection.afterMatch(atFirst, player: player, position: .striker, parameters: parameters)
        let byHand = try FitnessProjection.afterDays(7, played, player: player, intensity: .medium, parameters: parameters)
        #expect(second.fitness[player.id] == byHand)
        #expect(second.fitness[player.id]?.daysSinceMatch == 7)
        #expect(second.fitness[id(.ST_C)]?.daysSinceMatch == nil)
    }

    // MARK: - History

    /// Three medium fixtures two days apart, with cover too weak to rotate in and low training so condition stays clear
    /// of the floor.
    func threeInARow(confirmed: [ConfirmedLineup] = []) throws -> Plan {
        let players = try PlannerFixture.squad(first: 14, second: 6)
        let fixtures = [fixture("a", day: 1), fixture("b", day: 3), fixture("c", day: 5)]
        return try planner.plan(request(fixtures, players: players, confirmed: confirmed,
                                        settings: PlanSettings(trainingIntensity: .low)))
    }

    func consecutive(_ planned: PlannedFixture, _ slot: SlotID) throws -> Adjustment? {
        let p = try #require(pick(planned, slot))
        #expect(p.player == id(slot), "\(planned.fixture.raw)")
        return p.adjustments.first { $0.kind == .consecutiveStarts }
    }

    @Test func plannedLineupsCountTowardsLaterConsecutiveStarts() throws {
        let plan = try threeInARow()
        #expect(try consecutive(plan.fixtures[0], .D_L) == nil)
        #expect(try consecutive(plan.fixtures[1], .D_L) == nil)
        let third = try #require(try consecutive(plan.fixtures[2], .D_L))
        #expect(third.factor == 0.90)
        #expect(third.reason.hasPrefix("Has started the last 2 matches"))
    }

    @Test func confirmedLineupsSeedTheRun() throws {
        let one = [ConfirmedLineup(fixture: FixtureID("played1"), date: day(-1), starters: [.D_L: id(.D_L)])]
        let seededOnce = try threeInARow(confirmed: one)
        #expect(try consecutive(seededOnce.fixtures[0], .D_L) == nil)
        #expect(try consecutive(seededOnce.fixtures[1], .D_L)?.factor == 0.90)

        let two = one + [ConfirmedLineup(fixture: FixtureID("played0"), date: day(-3), starters: [.D_L: id(.D_L)])]
        let seededTwice = try threeInARow(confirmed: two)
        #expect(try consecutive(seededTwice.fixtures[0], .D_L)?.factor == 0.90)
        #expect(try consecutive(seededTwice.fixtures[1], .D_L)?.factor == 0.75)
    }

    @Test func aPlannedLineupReplacesAConfirmedOneForTheSameFixture() throws {
        // A stale confirmed lineup for fixture "a" says the cover started it; the plan's own lineup for "a" replaces it.
        let stale = [ConfirmedLineup(fixture: FixtureID("a"), date: day(1), starters: [.D_L: id(.D_L, "second")])]
        let plan = try threeInARow(confirmed: stale)
        #expect(plan == (try threeInARow()))
    }
}
