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
                 played: [ConfirmedLineup] = [], retraining: [Retraining] = [], settings: PlanSettings = .standard) -> PlanRequest {
        PlanRequest(fixtures: fixtures, players: players ?? squad, ownClub: "Oxford City", asOf: day(asOf),
                    confirmed: confirmed, played: played, retraining: retraining, settings: settings)
    }

    func played(_ id: String, day n: Int, _ starters: [SlotID: PlayerID]) -> ConfirmedLineup {
        ConfirmedLineup(fixture: FixtureID(id), date: day(n), starters: starters)
    }

    func expectClose(_ a: ProjectedFitness?, _ b: ProjectedFitness, sourceLocation: SourceLocation = #_sourceLocation) {
        guard let a else { Issue.record("no fitness", sourceLocation: sourceLocation); return }
        #expect(abs(a.condition - b.condition) < 1e-9, sourceLocation: sourceLocation)
        #expect(abs(a.sharpness - b.sharpness) < 1e-9, sourceLocation: sourceLocation)
        #expect(abs(a.jadedness - b.jadedness) < 1e-9, sourceLocation: sourceLocation)
        #expect(a.daysSinceMatch == b.daysSinceMatch, sourceLocation: sourceLocation)
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

    @Test func aFixtureIDUsedTwiceIsRefused() throws {
        #expect(throws: PlanError.duplicateFixtureID(FixtureID("a"))) {
            try planner.plan(request([fixture("a", day: 1), fixture("b", day: 3), fixture("a", day: 5)]))
        }
        // Several repeats: the lowest id, whatever the input order.
        let several = [fixture("c", day: 1), fixture("b", day: 2), fixture("c", day: 3), fixture("b", day: 4)]
        #expect(throws: PlanError.duplicateFixtureID(FixtureID("b"))) { try planner.plan(request(several)) }
        #expect(throws: PlanError.duplicateFixtureID(FixtureID("b"))) { try planner.plan(request(several.reversed())) }
        // Beyond the horizon too.
        #expect(throws: PlanError.duplicateFixtureID(FixtureID("a"))) {
            try planner.plan(request([fixture("a", day: 1), fixture("a", day: 9)], settings: PlanSettings(horizon: 1)))
        }
    }

    @Test func aConfirmedLineupIDUsedTwiceIsRefused() throws {
        func confirmed(_ id: String, _ n: Int) -> ConfirmedLineup {
            ConfirmedLineup(fixture: FixtureID(id), date: day(n), starters: [.D_L: self.id(.D_L)])
        }
        let lineups = [confirmed("y", -6), confirmed("x", -5), confirmed("y", -3), confirmed("x", -1)]
        #expect(throws: PlanError.duplicateFixtureID(FixtureID("x"))) {
            try planner.plan(request([fixture("a", day: 1)], confirmed: lineups))
        }
        #expect(throws: PlanError.duplicateFixtureID(FixtureID("x"))) {
            try planner.plan(request([fixture("a", day: 1)], confirmed: lineups.reversed()))
        }
        #expect(throws: PlanError.duplicateFixtureID(FixtureID("x"))) {
            try planner.plan(request([], confirmed: lineups))
        }
        // The fixtures are checked first.
        #expect(throws: PlanError.duplicateFixtureID(FixtureID("z"))) {
            try planner.plan(request([fixture("z", day: 1), fixture("z", day: 2)], confirmed: lineups))
        }
        // One confirmed lineup sharing an id with a fixture to plan is allowed.
        #expect(throws: Never.self) {
            try planner.plan(request([fixture("a", day: 1)], confirmed: [confirmed("a", -1)]))
        }
    }

    @Test func checksRunInOrderSettingsParametersPlayersFixtureIDsDates() throws {
        var broken = EngineParameters.fm27
        broken.conditionCurve = Parameter([], .derived, source: "test")
        let brokenPlanner = Planner(catalog: try RoleCatalog.fm27(), profile: try RatingProfile.standard(), parameters: broken)
        let badSettings = PlanSettings(horizon: 0)
        let twins = squad + [squad[0]]
        let badDates = [fixture("a", day: -1)]
        let repeated = badDates + [fixture("a", day: 4)]

        #expect(throws: PlanError.badSettings(badSettings.problems())) {
            try brokenPlanner.plan(request(repeated, players: twins, asOf: 0, settings: badSettings))
        }
        #expect(throws: PlanError.badParameters(["conditionCurve is empty"])) {
            try brokenPlanner.plan(request(repeated, players: twins))
        }
        #expect(throws: DuplicatePlayerError.self) { try planner.plan(request(repeated, players: twins)) }
        #expect(throws: PlanError.duplicateFixtureID(FixtureID("a"))) { try planner.plan(request(repeated)) }
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

    @Test func aRunOfStartsCannotBeDodgedByChangingSlot() throws {
        // With no goalkeeper an outfielder must stand in. The first-choice striker has started four in a row, a step
        // that marks him down up front (×0.80) and would not yet in goal; the run tires him wherever he plays.
        let players = squad.filter { $0.id != id(.GK) && $0.id != id(.GK, "second") }
        let striker = id(.ST_C)
        let confirmed = [1, 3, 5, 7].map { n in
            ConfirmedLineup(fixture: FixtureID("played\(n)"), date: day(-n), starters: [.ST_C: striker])
        }
        let expected = [Adjustment(kind: .consecutiveStarts, factor: 0.80,
                                   reason: "Has started the last 4 matches in quick succession (×0.80)")]
        let plan = try planner.plan(request([fixture("a", day: 1)], players: players, confirmed: confirmed))
        #expect(pick(plan.fixtures[0], .GK)?.player != striker)
        if let his = plan.fixtures[0].lineup.picks.first(where: { $0.player == striker }) {
            #expect(his.adjustments.filter { $0.kind == .consecutiveStarts } == expected)
        }

        // Whichever slot he is fixed in, the run's factor goes with him.
        for assignment in try tactic.assignments(catalog: RoleCatalog.fm27()) {
            let fixed = try planner.plan(request([fixture("a", day: 1, overrides: [assignment.slot: striker])],
                                                 players: players, confirmed: confirmed))
            let his = try #require(pick(fixed.fixtures[0], assignment.slot))
            #expect(his.player == striker)
            #expect(his.adjustments.filter { $0.kind == .consecutiveStarts } == expected, "\(assignment.slot.rawValue)")
        }
    }

    @Test func historyThatNoLongerMatchesTheSquadOrTacticIsHandled() throws {
        // The latest confirmed lineup names a player who has left at D_L and the first-choice AM (C) at M_C, a slot the
        // tactic does not use. Before it, he started twice at AM_C. His cover is too weak to rotate in.
        let players = try PlannerFixture.squad(first: 14, second: 6)
        let gone = PlayerID(key: "gone")
        let playmaker = id(.AM_C)
        try #require(!players.contains { $0.id == gone })
        try #require(try tactic.assignments(catalog: RoleCatalog.fm27()).allSatisfy { $0.slot != .M_C })
        let confirmed = [
            ConfirmedLineup(fixture: FixtureID("played5"), date: day(-5), starters: [.AM_C: playmaker]),
            ConfirmedLineup(fixture: FixtureID("played3"), date: day(-3), starters: [.AM_C: playmaker]),
            ConfirmedLineup(fixture: FixtureID("played1"), date: day(-1), starters: [.D_L: gone, .M_C: playmaker]),
        ]
        let plan = try planner.plan(request([fixture("a", day: 1)], players: players, confirmed: confirmed))
        let planned = try #require(plan.fixtures.first)

        // No slot of the tactic is M_C, so no stability adjustment can refer to it: nobody carries one.
        #expect(planned.lineup.picks.allSatisfy { pick in !pick.adjustments.contains { $0.kind == .stability } })
        for omission in planned.lineup.omissions {
            if case .heldBack(let kinds) = omission.cause { #expect(!kinds.contains(.stability), "\(omission.name)") }
        }
        #expect(!planned.lineup.picks.contains { $0.player == gone })

        // The M_C start still extends his run: three in a row, the step that marks an attacking midfielder down.
        let his = try #require(planned.lineup.picks.first { $0.player == playmaker })
        #expect(his.adjustments.filter { $0.kind == .consecutiveStarts }
            == [Adjustment(kind: .consecutiveStarts, factor: 0.90, reason: "Has started the last 3 matches in quick succession (×0.90)")])
    }

    @Test func aPlannedLineupReplacesAConfirmedOneForTheSameFixture() throws {
        // A stale confirmed lineup for fixture "a" says the cover started it; the plan's own lineup for "a" replaces it.
        let stale = [ConfirmedLineup(fixture: FixtureID("a"), date: day(1), starters: [.D_L: id(.D_L, "second")])]
        let plan = try threeInARow(confirmed: stale)
        #expect(plan == (try threeInARow()))
    }

    // MARK: - Matches played since the import

    @Test func aMatchPlayedSinceTheImportLeavesItsStartersLessFresh() throws {
        let players = try PlannerFixture.squad(first: 14, second: 6)
        let starter = id(.ST_C)
        let match = played("p", day: 1, [.ST_C: starter])
        let plan = try planner.plan(request([fixture("a", day: 4)], players: players, played: [match]))
        let without = try planner.plan(request([fixture("a", day: 4)], players: players))

        // By hand: one day from the import, the match at the slot's position, three days to the fixture.
        let player = try #require(players.first { $0.id == starter })
        let before = try FitnessProjection.afterDays(1, ProjectedFitness(player), player: player, intensity: .medium,
                                                     parameters: parameters)
        let after = try FitnessProjection.afterMatch(before, player: player, position: SlotID.ST_C.position, parameters: parameters)
        let byHand = try FitnessProjection.afterDays(3, after, player: player, intensity: .medium, parameters: parameters)
        expectClose(plan.fixtures[0].fitness[starter], byHand)
        #expect(byHand.daysSinceMatch == 3)
        #expect(try #require(plan.fixtures[0].fitness[starter]).condition
            < (try #require(without.fixtures[0].fitness[starter])).condition)

        // Everyone who did not start it is as he would be without it.
        for other in players where other.id != starter {
            #expect(plan.fixtures[0].fitness[other.id] == without.fixtures[0].fitness[other.id], "\(other.name)")
        }
    }

    @Test func aPlayedMatchBeforeTheImportDayRecoversToThatDay() throws {
        // The left back played on day -5; the playmaker on day -5 and on day -2. Both then recover to the import day.
        let players = try PlannerFixture.squad(first: 14, second: 6)
        let back = id(.D_L)
        let playmaker = id(.AM_C)
        let matches = [played("p2", day: -2, [.AM_C: playmaker]), played("p5", day: -5, [.D_L: back, .AM_C: playmaker])]
        let plan = try planner.plan(request([fixture("a", day: 2)], players: players, played: matches))
        let without = try planner.plan(request([fixture("a", day: 2)], players: players))

        func days(_ n: Int, _ fitness: ProjectedFitness, _ player: Player) throws -> ProjectedFitness {
            try FitnessProjection.afterDays(n, fitness, player: player, intensity: .medium, parameters: parameters)
        }
        func match(_ fitness: ProjectedFitness, _ player: Player, _ slot: SlotID) throws -> ProjectedFitness {
            try FitnessProjection.afterMatch(fitness, player: player, position: slot.position, parameters: parameters)
        }
        let backPlayer = try #require(players.first { $0.id == back })
        let backByHand = try days(2, days(5, match(ProjectedFitness(backPlayer), backPlayer, .D_L), backPlayer), backPlayer)
        expectClose(plan.fixtures[0].fitness[back], backByHand)
        #expect(backByHand.daysSinceMatch == 7)

        let playmakerPlayer = try #require(players.first { $0.id == playmaker })
        let twice = try match(days(3, match(ProjectedFitness(playmakerPlayer), playmakerPlayer, .AM_C), playmakerPlayer),
                              playmakerPlayer, .AM_C)
        let playmakerByHand = try days(2, days(2, twice, playmakerPlayer), playmakerPlayer)
        expectClose(plan.fixtures[0].fitness[playmaker], playmakerByHand)
        #expect(playmakerByHand.daysSinceMatch == 4)

        // Those days move nobody else, and the match is not treated as played on the import day.
        for other in players where other.id != back && other.id != playmaker {
            #expect(plan.fixtures[0].fitness[other.id] == without.fixtures[0].fitness[other.id], "\(other.name)")
        }
        let onTheDay = try planner.plan(request([fixture("a", day: 2)], players: players,
                                                played: [played("p5", day: 0, [.D_L: back])]))
        #expect(onTheDay.fixtures[0].fitness[back] != plan.fixtures[0].fitness[back])
    }

    @Test func aPlayedMatchOnAFixturesDayComesFirst() throws {
        let players = try PlannerFixture.squad(first: 14, second: 6)
        let starter = id(.D_L)
        let plan = try planner.plan(request([fixture("a", day: 2), fixture("b", day: 5)], players: players,
                                            played: [played("p", day: 2, [.D_L: starter])]))
        let player = try #require(players.first { $0.id == starter })
        let before = try FitnessProjection.afterDays(2, ProjectedFitness(player), player: player, intensity: .medium,
                                                     parameters: parameters)
        let after = try FitnessProjection.afterMatch(before, player: player, position: SlotID.D_L.position, parameters: parameters)
        // The fixture's figure is from before its own match, so it already includes the played one.
        expectClose(plan.fixtures[0].fitness[starter], after)
        #expect(plan.fixtures[0].fitness[starter]?.daysSinceMatch == 0)
    }

    @Test func aPlayedStarterWhoHasLeftIsIgnored() throws {
        let players = try PlannerFixture.squad(first: 14, second: 6)
        let gone = PlayerID(key: "gone")
        let fixtures = [fixture("a", day: 3), fixture("b", day: 6)]
        let withGone = try planner.plan(request(fixtures, players: players,
                                                played: [played("p", day: 1, [.ST_C: gone, .AM_C: id(.AM_C)])]))
        let withoutGone = try planner.plan(request(fixtures, players: players, played: [played("p", day: 1, [.AM_C: id(.AM_C)])]))
        #expect(withGone == withoutGone)
        #expect(withGone.fixtures.allSatisfy { $0.fitness[gone] == nil })

        // A match whose only starter has left changes nobody's fitness.
        let onlyGone = try planner.plan(request(fixtures, players: players, played: [played("p", day: 1, [.ST_C: gone])]))
        #expect(onlyGone == (try planner.plan(request(fixtures, players: players))))
    }

    @Test func playedMatchesDoNotChangeRunsOfStarts() throws {
        // As `threeInARow`, with the first-choice left back having started a match the day before the first fixture.
        let players = try PlannerFixture.squad(first: 14, second: 6)
        let fixtures = [fixture("a", day: 1), fixture("b", day: 3), fixture("c", day: 5)]
        let plan = try planner.plan(request(fixtures, players: players, played: [played("p", day: 0, [.D_L: id(.D_L)])],
                                            settings: PlanSettings(trainingIntensity: .low)))
        #expect(try consecutive(plan.fixtures[0], .D_L) == nil)
        #expect(try consecutive(plan.fixtures[1], .D_L) == nil)
        #expect(try consecutive(plan.fixtures[2], .D_L)?.factor == 0.90)
        // The same lineup confirmed does start the run.
        let confirmed = try planner.plan(request(fixtures, players: players, confirmed: [played("p", day: 0, [.D_L: id(.D_L)])],
                                                 settings: PlanSettings(trainingIntensity: .low)))
        #expect(try consecutive(confirmed.fixtures[1], .D_L)?.factor == 0.90)
    }

    @Test func aFixtureAfterAPlayedMatchHasProjectedFitnessEvenOnTheImportDay() throws {
        let players = changing(.ST_C) { $0.condition = 0.80 }
        let fixtures = [fixture("a", day: 0), fixture("b", day: 3)]
        let without = try planner.plan(request(fixtures, players: players))
        #expect(without.fixtures.map(\.fitnessIsProjected) == [false, true])
        let reason = without.fixtures[0].lineup.omissions.first { $0.player == id(.ST_C) }?.reason
        #expect(reason == "Left out: below the 85% condition floor at 80%")

        let match = played("p", day: -2, [.AM_C: id(.AM_C)])
        let with = try planner.plan(request(fixtures, players: players, played: [match]))
        #expect(with.fixtures.map(\.fitnessIsProjected) == [true, true])
        // The selector was told the same: the striker's figure is called projected.
        let projected = try #require(with.fixtures[0].lineup.omissions.first { $0.player == id(.ST_C) }?.reason)
        #expect(projected != reason && projected.contains("projected"))

        // A played match after a fixture does not make that fixture's fitness projected.
        let later = try planner.plan(request(fixtures, players: players, played: [played("p", day: 1, [.AM_C: id(.AM_C)])]))
        #expect(later.fixtures.map(\.fitnessIsProjected) == [false, true])
    }

    @Test func inputOrderOfPlayedMatchesDoesNotMatter() throws {
        let players = try PlannerFixture.squad(first: 14, second: 6)
        let fixtures = [fixture("a", day: 2), fixture("b", day: 5)]
        let matches = [
            played("p1", day: -1, [.ST_C: id(.ST_C), .AM_C: id(.AM_C)]),
            played("p2", day: 0, [.ST_C: id(.ST_C, "second")]),
            played("p3", day: 0, [.ST_C: id(.ST_C), .D_L: id(.D_L)]),
            played("p4", day: 3, [.GK: id(.GK)]),
        ]
        let base = try planner.plan(request(fixtures, players: players, played: matches))
        #expect(try planner.plan(request(fixtures, players: players, played: matches.reversed())) == base)
        #expect(try planner.plan(request(fixtures, players: players, played: [matches[2], matches[0], matches[3], matches[1]])) == base)
        #expect(base != (try planner.plan(request(fixtures, players: players))))
        // The keeper's match between the fixtures counts towards the second.
        let keeper = try #require(base.fixtures[1].fitness[id(.GK)])
        #expect(keeper.daysSinceMatch == 2)

        // A match id given twice is refused, as for confirmed lineups.
        #expect(throws: PlanError.duplicateFixtureID(FixtureID("p2"))) {
            try planner.plan(request(fixtures, players: players, played: matches + [matches[1]]))
        }
    }

    @Test func withNothingPlayedFitnessIsProjectedAfterTheFirstMatchOrDay() throws {
        let players = try PlannerFixture.squad(first: 14, second: 6)
        let fixtures = [fixture("a", day: 0), fixture("b", day: 2), fixture("c", day: 5)]
        let base = try planner.plan(request(fixtures, players: players))
        #expect(try planner.plan(request(fixtures, players: players, played: [])) == base)
        #expect(base.fixtures.map(\.fitnessIsProjected) == [false, true, true])
        let later = try planner.plan(request([fixture("a", day: 1)], players: players))
        #expect(later.fixtures.map(\.fitnessIsProjected) == [true])
    }

    @Test func aMatchPlayedAfterTheLastFixtureChangesNothing() throws {
        let players = try PlannerFixture.squad(first: 14, second: 6)
        let fixtures = [fixture("a", day: 0), fixture("b", day: 2), fixture("c", day: 5)]
        let base = try planner.plan(request(fixtures, players: players))
        let beyond = try planner.plan(request(fixtures, players: players, played: [played("p", day: 9, [.ST_C: id(.ST_C)])],
                                              settings: PlanSettings(horizon: 3)))
        #expect(beyond == base)
    }

    @Test func withFitnessAppliesTheProjectionAndRoundsJadedness() {
        let player = squad[0]
        let fitness = ProjectedFitness(condition: 0.81, sharpness: 0.64, jadedness: 212.5, daysSinceMatch: 3)
        let onTheDay = Planner.withFitness(player, fitness)
        #expect(onTheDay.condition == 0.81)
        #expect(onTheDay.sharpness == 0.64)
        #expect(onTheDay.jadedness == 213)
        // Everything else is as imported.
        var expected = player
        expected.condition = 0.81; expected.sharpness = 0.64; expected.jadedness = 213
        #expect(onTheDay == expected)
        // The imported figures come back unchanged.
        #expect(Planner.withFitness(player, ProjectedFitness(player)) == player)
    }

    @Test func aMatchBothToPlanAndPlayedIsRefused() throws {
        let fixtures = [fixture("a", day: 1), fixture("b", day: 3)]
        #expect(throws: PlanError.duplicateFixtureID(FixtureID("b"))) {
            try planner.plan(request(fixtures, played: [played("b", day: 0, [.ST_C: id(.ST_C)])]))
        }
        // Beyond the horizon too, and the lowest such id is named.
        #expect(throws: PlanError.duplicateFixtureID(FixtureID("a"))) {
            try planner.plan(request(fixtures, played: [played("b", day: 0, [:]), played("a", day: 0, [:])],
                                     settings: PlanSettings(horizon: 1)))
        }
        // A played match may share its id with a confirmed lineup: the app passes the same match as both.
        let match = played("p", day: 0, [.ST_C: id(.ST_C)])
        #expect(throws: Never.self) { try planner.plan(request(fixtures, confirmed: [match], played: [match])) }
    }
}
