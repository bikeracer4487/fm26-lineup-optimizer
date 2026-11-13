import Foundation
import Testing
@testable import LineupEngine

/// The planner scenarios of the design's testing section, on `PlannerFixture`'s squad.
@Suite struct PlannerScenarioTests {
    let parameters = EngineParameters.fm27
    let planner: Planner
    let day0 = Day(year: 2026, month: 11, day: 14)!
    let tactic: Tactic
    let assignments: [SlotAssignment]

    init() throws {
        planner = Planner(catalog: try RoleCatalog.fm27(), profile: try RatingProfile.standard(), parameters: .fm27)
        tactic = try PlannerFixture.tactic()
        assignments = try tactic.assignments(catalog: RoleCatalog.fm27())
    }

    func fixture(_ id: String, _ importance: Importance, day n: Int, opponent: String? = nil) -> Fixture {
        Fixture(id: FixtureID(id), date: day0.adding(days: n), opponent: opponent ?? "Opponent \(id)",
                importance: importance, tactic: tactic)
    }

    func plan(_ fixtures: [Fixture], _ players: [Player], retraining: [Retraining] = [],
              settings: PlanSettings = .standard) throws -> Plan {
        try planner.plan(PlanRequest(fixtures: fixtures, players: players, ownClub: "Oxford City", asOf: day0,
                                     confirmed: [], retraining: retraining, settings: settings))
    }

    func id(_ slot: SlotID, _ tier: String = "first") -> PlayerID { PlannerFixture.id(slot, tier) }

    func firstChoice() -> Set<PlayerID> { Set(assignments.map { id($0.slot) }) }

    func starters(_ planned: PlannedFixture) -> Set<PlayerID> { Set(planned.lineup.picks.map(\.player)) }

    func pick(_ planned: PlannedFixture, _ slot: SlotID) -> Pick? { planned.lineup.picks.first { $0.slot == slot } }

    func changing(_ players: [Player], _ slot: SlotID, _ tier: String = "first", _ change: (inout Player) -> Void) -> [Player] {
        players.map { player in
            var player = player
            if player.id == id(slot, tier) { change(&player) }
            return player
        }
    }

    func tiers(_ players: [Player]) throws -> SquadTiers {
        try SquadTiers.compute(tactic: tactic, players: players, ownClub: "Oxford City", catalog: RoleCatalog.fm27(),
                               profile: RatingProfile.standard(), parameters: parameters)
    }

    func rating(_ player: PlayerID, at slot: SlotID, in players: [Player]) throws -> Double {
        let engine = RatingEngine(profile: try RatingProfile.standard(), parameters: parameters, configuration: .fm27)
        let p = try #require(players.first { $0.id == player })
        return try engine.rating(for: p, in: try #require(assignments.first { $0.slot == slot })).value
    }

    // MARK: - Fixture congestion

    @Test func congestion() throws {
        let players = try PlannerFixture.squad(first: 14, second: 12)
        let result = try plan([fixture("a", .medium, day: 0), fixture("b", .medium, day: 2), fixture("c", .medium, day: 4)], players)
        for planned in result.fixtures {
            #expect(planned.lineup.picks.count == 11)
            for pick in planned.lineup.picks {
                let condition = try #require(planned.fitness[pick.player]).condition
                #expect(condition >= parameters.conditionFloor.value, "\(pick.name) at \(planned.fixture.raw): \(condition)")
            }
        }
        let elevens = result.fixtures.map(starters)
        #expect(Set(elevens).count > 1)
    }

    // MARK: - A High fixture after two Low ones

    @Test func aHighFixtureAfterTwoLowOnes() throws {
        let players = try PlannerFixture.squad(first: 14, second: 12)
        let fixtures = [fixture("l1", .low, day: 0), fixture("l2", .low, day: 3), fixture("h", .high, day: 5, opponent: "Wealdstone")]
        let off = try plan(fixtures, players, settings: PlanSettings(savingPlayers: 0))
        let on = try plan(fixtures, players, settings: PlanSettings(savingPlayers: 1))
        let first = firstChoice()

        #expect(starters(off.fixtures[1]) == first)
        #expect(starters(on.fixtures[1]).intersection(first).count < first.count)
        #expect(starters(off.fixtures[2]) == first)
        #expect(starters(on.fixtures[2]) == first)

        func averageCondition(_ planned: PlannedFixture) throws -> Double {
            var total = 0.0
            for player in first.sorted(by: { $0.key < $1.key }) { total += try #require(planned.fitness[player]).condition }
            return total / Double(first.count)
        }
        #expect(try averageCondition(on.fixtures[2]) > averageCondition(off.fixtures[2]))

        let heldBack = on.fixtures[1].lineup.omissions.filter { $0.cause == .heldBack([.savedForLater]) }
        try #require(!heldBack.isEmpty)
        for omission in heldBack {
            #expect(omission.reason.hasPrefix("Left out: Kept fresher for Wealdstone on \(day0.adding(days: 5).iso)"))
        }
    }

    // MARK: - A squad with injuries

    @Test func aSquadWithInjuries() throws {
        let players = changing(try PlannerFixture.squad(first: 14, second: 12), .ST_C) { $0.isInjured = true }
        let fixtures = [fixture("l1", .low, day: 0), fixture("m", .medium, day: 3), fixture("h", .high, day: 6)]
        let result = try plan(fixtures, players)
        for planned in result.fixtures {
            #expect(!starters(planned).contains(id(.ST_C)))
            let omission = try #require(planned.lineup.omissions.first { $0.player == id(.ST_C) })
            #expect(omission.cause == .excluded(.injured))
            #expect(omission.reason == "Left out: injured")
        }
        #expect(pick(result.fixtures[2], .ST_C)?.player == id(.ST_C, "second"))
    }

    // MARK: - A Sharpness fixture

    @Test func aSharpnessFixture() throws {
        // ST: the first choice is short of sharpness, his cover fully sharp. AM (C): the reverse.
        // A third striker, in neither eleven, is short of sharpness too.
        var players = try PlannerFixture.squad(first: 14, second: 12)
        players = changing(players, .ST_C) { $0.sharpness = 0.80 }
        players = changing(players, .AM_C, "second") { $0.sharpness = 0.60 }
        let third = Player.fixture(name: "ST third", all: 11, familiarity: [.striker: 20], sharpness: 0.50)
        players.append(third)
        let tiers = try tiers(players)
        try #require(tiers.slot(of: third.id) == nil)

        let result = try plan([fixture("s", .sharpness, day: 0)], players)
        let planned = result.fixtures[0]
        #expect(pick(planned, .ST_C)?.player == id(.ST_C))
        #expect(pick(planned, .AM_C)?.player == id(.AM_C, "second"))
        let omission = try #require(planned.lineup.omissions.first { $0.player == id(.AM_C) })
        // Only both together bring him back: his own ×0.60 and his cover's need for minutes.
        #expect(omission.cause == .heldBack([.needsSharpness]))
        #expect(omission.reason == "Left out: Already sharp: others need the minutes more (×0.60); "
            + "AM_C second is preferred: Needs minutes: sharpness 60% (×1.76)")

        // The third striker would beat the first choice if being unsharp earned him what it earns the elevens; it does not.
        let st = try #require(pick(planned, .ST_C))
        let thirdValue = try rating(third.id, at: .ST_C, in: players)
            * FitnessModel.factors(condition: 1, sharpness: 0.50, jadedness: -500, parameters: parameters).product
        let need = min(max((parameters.sharpnessNeedFull.value - 0.50)
            / (parameters.sharpnessNeedFull.value - parameters.sharpnessNeedMost.value), 0), 1)
        #expect(thirdValue * (1 + parameters.sharpnessNeedStrengthBuild.value * need) > st.value)
        #expect(thirdValue < st.value)
        #expect(!starters(planned).contains(third.id))
    }

    // MARK: - Young prospects

    @Test func youngProspectsGetTheLowFixture() throws {
        // A 19-year-old with room to grow, 5% below the first-choice striker (familiarity 15 against 20).
        var players = try PlannerFixture.squad(first: 14, second: 12)
        let prospect = Player.fixture(name: "ST prospect", age: 19, all: 14, familiarity: [.striker: 15],
                                      currentAbility: 100, potentialAbility: 130)
        players.append(prospect)
        let gap = try rating(prospect.id, at: .ST_C, in: players) / rating(id(.ST_C), at: .ST_C, in: players)
        try #require(gap > 0.9 && gap < 1)

        let fixtures = [fixture("m", .medium, day: 0), fixture("l", .low, day: 4), fixture("h", .high, day: 8)]
        let result = try plan(fixtures, players, settings: PlanSettings(savingPlayers: 0))
        #expect(pick(result.fixtures[0], .ST_C)?.player == id(.ST_C))
        let low = try #require(pick(result.fixtures[1], .ST_C))
        #expect(low.player == prospect.id)
        #expect(low.adjustments.map(\.kind).contains(.development))
        // The first-choice striker is left out because the prospect is favoured.
        let striker = try #require(result.fixtures[1].lineup.omissions.first { $0.player == id(.ST_C) })
        guard case .preferred(let by, let kinds) = striker.cause else {
            Issue.record("expected preferred, got \(striker.cause)"); return
        }
        #expect(by == [prospect.id])
        #expect(kinds.contains(.development))
        #expect(striker.reason.hasPrefix("Left out: ST prospect is preferred: "))
        #expect(striker.reason.contains("Young player with room to grow: favoured for minutes (×1.10)"))
        #expect(pick(result.fixtures[2], .ST_C)?.player == id(.ST_C))
    }

    // MARK: - Retraining

    func retrainee(familiarity: Int) -> Player {
        // Natural nowhere in the tactic; learning D (L).
        Player.fixture(name: "D_L retrainee", all: 17, familiarity: [.defenderLeft: familiarity])
    }

    func retrainingPlan(_ importance: Importance, familiarity: Int) throws -> PlannedFixture {
        let player = retrainee(familiarity: familiarity)
        let players = try PlannerFixture.squad(first: 14, second: 12) + [player]
        let retraining = [Retraining(player: player.id, position: .defenderLeft, acceptedOn: day0.adding(days: -30))]
        return try plan([fixture("f", importance, day: 0)], players, retraining: retraining).fixtures[0]
    }

    @Test func aPlayerBeingRetrainedGetsHisNewPositionInALowFixture() throws {
        let player = retrainee(familiarity: 12)
        let low = try retrainingPlan(.low, familiarity: 12)
        let atLow = try #require(pick(low, .D_L))
        #expect(atLow.player == player.id)
        #expect(atLow.reasons.contains { $0.hasPrefix("Retraining at D (L) (familiarity 12)") })

        let medium = try retrainingPlan(.medium, familiarity: 12)
        #expect(pick(medium, .D_L)?.player == id(.D_L))
        #expect(!starters(medium).contains(player.id))

        let later = try retrainingPlan(.medium, familiarity: 15)
        let atMedium = try #require(pick(later, .D_L))
        #expect(atMedium.player == player.id)
        #expect(atMedium.reasons.contains { $0.hasPrefix("Retraining at D (L) (familiarity 15)") })
    }
}
