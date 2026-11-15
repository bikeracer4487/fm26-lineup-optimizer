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
              settings: PlanSettings = .standard, marks: [PlayerID: SaleMark] = [:]) throws -> Plan {
        try planner.plan(PlanRequest(fixtures: fixtures, players: players, ownClub: "Oxford City", asOf: day0,
                                     confirmed: [], retraining: retraining, marks: marks, settings: settings))
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
        // A 19-year-old with room to grow, 5% below the first-choice striker (familiarity 15 against 20): within what
        // the floor at his age (×1.07) can overturn. Professionalism 1 slows his growth so that he is not expected to pass
        // the first choice soon: he is no successor, and the floor alone favours him.
        var players = try PlannerFixture.squad(first: 14, second: 12)
        let prospect = Player.fixture(name: "ST prospect", age: 19, all: 14, attributes: [.professionalism: 1],
                                      familiarity: [.striker: 15], currentAbility: 100, potentialAbility: 130)
        players.append(prospect)
        let gap = try rating(prospect.id, at: .ST_C, in: players) / rating(id(.ST_C), at: .ST_C, in: players)
        try #require(gap > 1 / 1.07 && gap < 1)

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
        #expect(striker.reason.contains("Young player with room to grow: favoured for minutes (×1.07)"))
        #expect(pick(result.fixtures[2], .ST_C)?.player == id(.ST_C))

        // With the Development setting at 0 the planner gives no floor, and the first-choice striker starts.
        let off = try plan(fixtures, players, settings: PlanSettings(savingPlayers: 0, development: 0))
        let lowOff = try #require(pick(off.fixtures[1], .ST_C))
        #expect(lowOff.player == id(.ST_C))
        #expect(off.fixtures.allSatisfy { $0.lineup.picks.allSatisfy { !$0.adjustments.contains { $0.kind == .development } } })
    }

    @Test func anInjuredYoungPlayersOutlookIsWhatItIsWhenFit() throws {
        var players = try PlannerFixture.squad(first: 14, second: 12)
        let young = Player.fixture(name: "ST young", age: 19, all: 13, familiarity: [.striker: 15],
                                   currentAbility: 100, potentialAbility: 130)
        players.append(young)
        let low = fixture("l", .low, day: 0)
        func outlook(_ squad: [Player]) throws -> Outlook {
            try #require(try planner.developmentOutlooks(for: low, players: squad, ownClub: "Oxford City", retraining: [])[young.id])
        }
        let fit = try outlook(players)
        let level = try #require(fit.level)
        #expect(fit.best?.slot == .ST_C)
        #expect(fit.best?.firstChoice?.player == id(.ST_C))
        // Injured, he is rated and compared as when fit.
        let injured = players.map { player in
            var player = player
            if player.id == young.id { player.isInjured = true }
            return player
        }
        #expect(try outlook(injured) == fit)
        // An injured first choice is still the one he is compared with.
        let firstInjured = changing(players, .ST_C) { $0.isInjured = true }
        let comparedWithInjured = try outlook(firstInjured)
        #expect(comparedWithInjured.level == level)
        #expect(comparedWithInjured.best?.firstChoice?.player == id(.ST_C))
        // The planner's own tiers, which leave injured players out, would not have rated him at all.
        let withoutInjured = try SquadTiers.compute(tactic: tactic, players: injured, ownClub: "Oxford City",
                                                    catalog: RoleCatalog.fm27(), profile: RatingProfile.standard(),
                                                    parameters: parameters)
        let fromThose = try Development.outlooks(players: injured, ownClub: "Oxford City", assignments: assignments,
                                                 tiers: withoutInjured, retraining: [], parameters: parameters)
        #expect(fromThose[young.id]?.slots.isEmpty == true)
    }

    @Test func thePlanHandsTheRulesOutlooksWithInjuredPlayersKeptIn() throws {
        // Both strikers of the elevens are injured, so the young striker is the only one fit to play there. Compared
        // with them, as when they are fit, his reach is markedly lower and he gets no floor; tiers that left them out
        // would make him first choice, with nobody to be markedly lower than, and favour him.
        var players = try PlannerFixture.squad(first: 14, second: 12)
        players = changing(players, .ST_C) { $0.isInjured = true }
        players = changing(players, .ST_C, "second") { $0.isInjured = true }
        let young = Player.fixture(name: "ST young", age: 19, all: 9, familiarity: [.striker: 20],
                                   currentAbility: 100, potentialAbility: 115)
        players.append(young)
        let low = fixture("l", .low, day: 0)
        let outlook = try #require(try planner.developmentOutlooks(for: low, players: players, ownClub: "Oxford City",
                                                                   retraining: [])[young.id])
        try #require(outlook.isMarkedlyLower)
        try #require(try tiers(players).tier(of: young.id) == .first(.ST_C))

        let planned = try plan([low], players, settings: PlanSettings(savingPlayers: 0)).fixtures[0]
        let pick = try #require(pick(planned, .ST_C))
        #expect(pick.player == young.id)
        #expect(!pick.adjustments.contains { $0.kind == .development || $0.kind == .successor })
    }

    @Test func plannedStartsCountTowardsTheMonthlyStop() throws {
        // A 19-year-old with room to grow, 5% below the first-choice striker, whom the floor (×1.07) puts ahead in a low
        // fixture. Professionalism 1 slows his growth, so he is no successor and is favoured by the floor alone. Five low
        // fixtures a week apart: the plan starts him in the first four, and by the fifth he has had four starts in the
        // thirty days before it.
        var players = try PlannerFixture.squad(first: 14, second: 12)
        let prospect = Player.fixture(name: "ST prospect", age: 19, all: 14, attributes: [.professionalism: 1],
                                      familiarity: [.striker: 15], currentAbility: 100, potentialAbility: 130)
        players.append(prospect)
        let fixtures = (0..<5).map { fixture("l\($0)", .low, day: 7 * $0) }
        let result = try plan(fixtures, players, settings: PlanSettings(savingPlayers: 0))
        for planned in result.fixtures.prefix(4) {
            let striker = try #require(pick(planned, .ST_C))
            #expect(striker.player == prospect.id, "\(planned.fixture.raw)")
            #expect(striker.adjustments.contains { $0.kind == .development }, "\(planned.fixture.raw)")
        }
        let fifth = try #require(pick(result.fixtures[4], .ST_C))
        #expect(fifth.player == id(.ST_C))
        #expect(result.fixtures[4].lineup.picks.allSatisfy { pick in
            !pick.adjustments.contains { $0.kind == .development || $0.kind == .successor }
        })

        // With room for a fifth start in the month he would have been favoured and started the fifth too.
        var roomy = parameters
        roomy.developmentStartsPerMonth = Parameter(5, .derived, source: "test")
        let unstopped = try Planner(catalog: RoleCatalog.fm27(), profile: RatingProfile.standard(), parameters: roomy)
            .plan(PlanRequest(fixtures: fixtures, players: players, ownClub: "Oxford City", asOf: day0, confirmed: [],
                              retraining: [], settings: PlanSettings(savingPlayers: 0)))
        let favoured = try #require(pick(unstopped.fixtures[4], .ST_C))
        #expect(favoured.player == prospect.id)
        #expect(favoured.adjustments.contains { $0.kind == .development })
    }

    // MARK: - A successor

    /// A 19-year-old striker, natural there, a little below the first-choice striker and expected to pass him within a
    /// season or a few: a successor at striker.
    func successor(_ attributes: [Attribute: Int]) -> Player {
        Player.fixture(name: "ST young", age: 19, all: 13, attributes: attributes, familiarity: [.striker: 20],
                       currentAbility: 100, potentialAbility: 130)
    }

    /// His rating at striker as a share of the first choice's, after checking that he is a successor there.
    func successorShare(_ young: Player, in players: [Player]) throws -> Double {
        let outlooks = try planner.developmentOutlooks(for: fixture("m", .medium, day: 0), players: players,
                                                       ownClub: "Oxford City", retraining: [])
        let striker = try #require(outlooks[young.id]?.slots.first { $0.slot == .ST_C })
        try #require(striker.firstChoice?.player == id(.ST_C))
        try #require(striker.band == .close || striker.band == .onCourse)
        return try rating(young.id, at: .ST_C, in: players) / rating(id(.ST_C), at: .ST_C, in: players)
    }

    @Test func aSuccessorAtOneHundredAgainstOneHundredAndFourStartsAMediumFixture() throws {
        // On the day of the import, so fitness is level and the match-day values are the ratings.
        let young = successor([.finishing: 15, .composure: 15])
        let players = try PlannerFixture.squad(first: 14, second: 12) + [young]
        let share = try successorShare(young, in: players)
        try #require(abs(share - 100.0 / 104) < 0.005)

        let planned = try plan([fixture("m", .medium, day: 0)], players, settings: PlanSettings(savingPlayers: 0)).fixtures[0]
        let striker = try #require(pick(planned, .ST_C))
        #expect(striker.player == young.id)
        #expect(striker.reasons.contains("Close to passing ST_C first at striker: favoured for matches there (×1.05)"))
        #expect(striker.adjustments.map(\.kind) == [.successor])
        let omitted = try #require(planned.lineup.omissions.first { $0.player == id(.ST_C) })
        guard case .preferred(let by, let kinds) = omitted.cause else {
            Issue.record("expected preferred, got \(omitted.cause)"); return
        }
        #expect(by == [young.id])
        #expect(kinds == [.successor])
    }

    @Test func atNinetyEightHeDoesNot() throws {
        let young = successor([.finishing: 11, .composure: 12])
        let players = try PlannerFixture.squad(first: 14, second: 12) + [young]
        let share = try successorShare(young, in: players)
        try #require(abs(share - 98.0 / 104) < 0.005)

        let planned = try plan([fixture("m", .medium, day: 0)], players, settings: PlanSettings(savingPlayers: 0)).fixtures[0]
        #expect(pick(planned, .ST_C)?.player == id(.ST_C))
        #expect(!starters(planned).contains(young.id))
    }

    @Test func heDoesNotStartAHighFixtureOnIt() throws {
        let young = successor([.finishing: 15, .composure: 15])
        let players = try PlannerFixture.squad(first: 14, second: 12) + [young]
        try #require(abs(try successorShare(young, in: players) - 100.0 / 104) < 0.005)
        let planned = try plan([fixture("h", .high, day: 0)], players, settings: PlanSettings(savingPlayers: 0)).fixtures[0]
        let striker = try #require(pick(planned, .ST_C))
        #expect(striker.player == id(.ST_C))
        #expect(planned.lineup.picks.allSatisfy { $0.adjustments.isEmpty })
    }

    @Test func withDevelopmentAtZeroTheLineupIsTheOneWithoutTheRule() throws {
        // The successor of the medium example, short of sharpness, in a medium, a low and a sharpness fixture, so that
        // each part of the rule has something to change.
        var players = try PlannerFixture.squad(first: 14, second: 12)
        let young = successor([.finishing: 15, .composure: 15])
        players.append(young)
        players = players.map { player in
            var player = player
            if player.id == young.id { player.sharpness = 0.75 }
            return player
        }
        let fixtures = [fixture("m", .medium, day: 0), fixture("l", .low, day: 4), fixture("s", .sharpness, day: 8)]
        let off = try plan(fixtures, players, settings: PlanSettings(savingPlayers: 0, development: 0))

        // Without the rule: the same planner with every development favour's factor at 1.
        var without = parameters
        without.successorFactorLow = Parameter(1, .derived, source: "test")
        without.successorFactorMedium = Parameter(1, .derived, source: "test")
        without.developmentFactors = Parameter([], .derived, source: "test")
        without.developmentFactorLowProfessionalism = Parameter(1, .derived, source: "test")
        let plain = try Planner(catalog: RoleCatalog.fm27(), profile: RatingProfile.standard(), parameters: without)
            .plan(PlanRequest(fixtures: fixtures, players: players, ownClub: "Oxford City", asOf: day0, confirmed: [],
                              retraining: [], settings: PlanSettings(savingPlayers: 0)))
        #expect(off == plain)
        // And the rule changes it at 1.
        let on = try plan(fixtures, players, settings: PlanSettings(savingPlayers: 0))
        #expect(on != off)
        #expect(on.fixtures.contains { planned in planned.lineup.picks.contains { $0.adjustments.contains { $0.kind == .successor } } })
    }

    // MARK: - Marked to sell or loan out

    /// A striker of 28 with no room to grow, so no other rule favours him, a little below the first-choice striker.
    func nearStriker() -> Player {
        Player.fixture(name: "ST near", age: 28, all: 14, attributes: [.finishing: 12, .composure: 12],
                       familiarity: [.striker: 20], currentAbility: 100, potentialAbility: 100)
    }

    @Test func aMarkedPlayerWinsANearTieInALowFixture() throws {
        // Between 97.2% and 100% of the first-choice striker: inside what ×1.03 can overturn.
        var players = try PlannerFixture.squad(first: 14, second: 12)
        let marked = nearStriker()
        players.append(marked)
        let gap = try rating(marked.id, at: .ST_C, in: players) / rating(id(.ST_C), at: .ST_C, in: players)
        try #require(gap > 0.972 && gap < 1)

        // One fixture on the day of the import, so fitness is level and only the mark separates the two.
        let marks: [PlayerID: SaleMark] = [marked.id: .toSell]
        let result = try plan([fixture("l", .low, day: 0)], players, settings: PlanSettings(savingPlayers: 0), marks: marks)
        let low = try #require(pick(result.fixtures[0], .ST_C))
        #expect(low.player == marked.id)
        #expect(low.adjustments.map(\.kind).contains(.shopWindow))
        let striker = try #require(result.fixtures[0].lineup.omissions.first { $0.player == id(.ST_C) })
        #expect(striker.reason.contains("Marked to sell: favoured for minutes, an untested way to bring offers (×1.03)"))
    }

    @Test func aMarkedPlayerDoesNotWinTheNearTieInAMediumOrHighFixture() throws {
        var players = try PlannerFixture.squad(first: 14, second: 12)
        let marked = nearStriker()
        players.append(marked)
        for importance in [Importance.medium, .high] {
            let result = try plan([fixture("f", importance, day: 0)], players, settings: PlanSettings(savingPlayers: 0),
                                  marks: [marked.id: .toSell])
            #expect(pick(result.fixtures[0], .ST_C)?.player == id(.ST_C))
        }
    }

    @Test func withoutTheMarkTheNearTieGoesToTheBetterPlayer() throws {
        var players = try PlannerFixture.squad(first: 14, second: 12)
        players.append(nearStriker())
        let result = try plan([fixture("l", .low, day: 0)], players, settings: PlanSettings(savingPlayers: 0))
        #expect(pick(result.fixtures[0], .ST_C)?.player == id(.ST_C))
    }

    @Test func aMarkedPlayerWhoIsClearlyWorseDoesNotStart() throws {
        // 5% below the first-choice striker (familiarity 15 against 20), as the prospect scenario's player is.
        var players = try PlannerFixture.squad(first: 14, second: 12)
        let marked = Player.fixture(name: "ST marked", age: 28, all: 14, familiarity: [.striker: 15],
                                    currentAbility: 100, potentialAbility: 100)
        players.append(marked)
        let gap = try rating(marked.id, at: .ST_C, in: players) / rating(id(.ST_C), at: .ST_C, in: players)
        try #require(gap < 0.97)
        let result = try plan([fixture("l", .low, day: 0)], players, settings: PlanSettings(savingPlayers: 0),
                              marks: [marked.id: .toLoanOut])
        #expect(pick(result.fixtures[0], .ST_C)?.player == id(.ST_C))
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
        #expect(atLow.reasons.contains { $0.hasPrefix("Retraining at left back (familiarity 12)") })

        let medium = try retrainingPlan(.medium, familiarity: 12)
        #expect(pick(medium, .D_L)?.player == id(.D_L))
        #expect(!starters(medium).contains(player.id))

        let later = try retrainingPlan(.medium, familiarity: 15)
        let atMedium = try #require(pick(later, .D_L))
        #expect(atMedium.player == player.id)
        #expect(atMedium.reasons.contains { $0.hasPrefix("Retraining at left back (familiarity 15)") })
    }
}
