import Foundation
import Testing
@testable import LineupEngine

@Suite struct AdvisorsTests {
    let tactic = try! PlannerFixture.tactic()
    let catalog = try! RoleCatalog.fm27()
    let profile = try! RatingProfile.standard()
    let asOf = Day(iso: "2026-11-13")!
    let ownClub = "Oxford City"

    func id(_ name: String) -> PlayerID { PlayerID(key: PlayerID.normalise(name)) }

    /// The planner's squad without its second-choice left back, so cover at left back is thin, and slow to retrain
    /// (age 30, Versatility and Professionalism 5, no room to grow), plus `extra`.
    func thinAtLeftBack(_ extra: [Player] = []) throws -> [Player] {
        try PlannerFixture.squad().filter { $0.name != PlannerFixture.name(.D_L, "second") }.map { p in
            var p = p
            p.age = 30
            p.attributes[.versatility] = 5
            p.attributes[.professionalism] = 5
            p.potentialAbility = p.currentAbility
            return p
        } + extra
    }

    /// A natural right back with familiarity 8 at D (L), quick to retrain.
    func rightBack(_ name: String = "Right Back", versatility: Int = 14) -> Player {
        Player.fixture(name: name, age: 20, all: 13, attributes: [.versatility: versatility, .professionalism: 12],
                       familiarity: [.defenderRight: 20, .defenderLeft: 8], currentAbility: 100, potentialAbility: 120)
    }

    /// A squad that gives every advisor something to say: a thin slot with candidates, a jaded player, a player out of
    /// contract and a loanee.
    func busySquad() throws -> [Player] {
        var jaded = Player.fixture(name: "Tired", jadedness: 600)
        jaded.attributes[.naturalFitness] = 10
        var free = Player.fixture(name: "Free Agent")
        free.contractType = .outOfContract
        var loanee = Player.fixture(name: "Loanee", club: "Other FC", loanedTo: ownClub)
        loanee.monthsLeft = 4
        return try thinAtLeftBack([rightBack("Back A", versatility: 14), rightBack("Back B", versatility: 13),
                                   jaded, free, loanee])
    }

    /// The sample tactic as a 4-2-2-2: its attacking midfielder replaced by a second striker, ST L, in both phases.
    /// The planner's squad has two natural strikers, so cover is thin at both striker slots here and at neither in
    /// the sample, and the two tactics' elevens differ.
    static func twoStrikers(from tactic: Tactic, catalog: RoleCatalog) throws -> Tactic {
        var t = tactic
        t.name = "Two Strikers"
        t.inPossession[.AM_C] = nil
        t.outOfPossession[.AM_C] = nil
        t.mapping[.AM_C] = nil
        t.inPossession[.ST_L] = "Channel Forward"
        t.outOfPossession[.ST_L] = "Centre Forward"
        t.mapping[.ST_L] = .ST_L
        try #require(t.problems(catalog: catalog).isEmpty)
        return t
    }

    func request(_ players: [Player], tactics: [Tactic]? = nil, history: [ConfirmedLineup] = [],
                 accepted: [Retraining] = [], rejected: Set<RetrainingChoice> = [],
                 trends: FitnessTrends = .none) -> AdvisorsRequest {
        AdvisorsRequest(primary: tactic, tactics: tactics ?? [tactic], players: players, ownClub: ownClub,
                        history: StartHistory(history), asOf: asOf, intensity: .medium, accepted: accepted,
                        rejected: rejected, trends: trends)
    }

    func report(_ request: AdvisorsRequest, money: MoneyStyle = .weeklyPounds,
                parameters: EngineParameters = .fm27) throws -> AdvisorsReport {
        try Advisors.report(request, money: money, catalog: catalog, profile: profile, parameters: parameters)
    }

    /// Every advisor called on its own, as a caller without `Advisors.report` would.
    static func oneByOne(_ r: AdvisorsRequest, money: MoneyStyle = .weeklyPounds, catalog: RoleCatalog,
                         profile: RatingProfile, parameters: EngineParameters) throws -> AdvisorsReport {
        let elevens = try Elevens.report(tactic: r.primary, players: r.players, ownClub: r.ownClub, catalog: catalog,
                                         profile: profile, parameters: parameters)
        let depth = try Depth.report(tactic: r.primary, players: r.players, ownClub: r.ownClub, catalog: catalog,
                                     profile: profile, parameters: parameters)
        let rest = try Rest.advice(players: r.players, ownClub: r.ownClub, history: r.history, asOf: r.asOf,
                                   intensity: r.intensity, trends: r.trends, parameters: parameters)
        let removal = try Removal.report(tactic: r.primary, players: r.players, ownClub: r.ownClub, money: money,
                                         history: r.history, asOf: r.asOf, retraining: r.accepted,
                                         catalog: catalog, profile: profile, parameters: parameters)
        var tactics = [r.primary]
        for t in r.tactics where !tactics.contains(t) { tactics.append(t) }
        let training = try Training.report(tactics: tactics, players: r.players, ownClub: r.ownClub, accepted: r.accepted,
                                           rejected: r.rejected, leaving: removal.advisedToLeave, catalog: catalog,
                                           profile: profile, parameters: parameters)
        return AdvisorsReport(elevens: elevens, depth: depth, rest: rest, removal: removal, training: training,
                              trends: r.trends)
    }

    @Test func theReportCarriesTheTrendsItWasHanded() throws {
        let squad = try busySquad()
        let fresh = try #require(squad.first { $0.jadedness <= 0 && !$0.isInjured })
        // Rising fast enough to pass the line in exactly six weeks, so Rest lists him.
        let perWeek = Double(400 - fresh.jadedness) / 6
        let trends = FitnessTrends(
            players: [fresh.id: PlayerTrend(seen: SeenTrend(perWeek: perWeek, days: 35, starts: 3, readings: 6),
                                            drift: nil, gain: nil, usedIntervals: 5, hasCountedReading: true)],
            squadDrift: [.firstTeam: SharedRate(value: 2, readings: 30, since: asOf.adding(days: -40))],
            clubGain: SharedRate(value: 31, readings: 14, since: asOf.adding(days: -40)),
            measuredFrom: asOf.adding(days: -40))
        let r = request(squad, trends: trends)
        let together = try report(r)
        #expect(together.trends == trends)
        #expect(together.rest.contains { $0.player == fresh.id && $0.level == .watch })
        #expect(together == (try Self.oneByOne(r, catalog: catalog, profile: profile, parameters: .fm27)))
        // A request with none reports none, and lists him no more.
        let without = try report(request(squad))
        #expect(without.trends == .none)
        #expect(!without.rest.contains { $0.player == fresh.id })
    }

    @Test func theReportEqualsTheAdvisorsCalledOneByOne() throws {
        let other = try Self.twoStrikers(from: tactic, catalog: catalog)
        let history = [ConfirmedLineup(fixture: FixtureID("f1"), date: asOf, starters: [.D_R: id("Tired")])]
        let r = request(try busySquad(), tactics: [tactic, other], history: history,
                        accepted: [Retraining(player: id("Back B"), position: .defenderCentral, acceptedOn: asOf)])
        let together = try report(r)
        #expect(together == (try Self.oneByOne(r, catalog: catalog, profile: profile, parameters: .fm27)))
        // Every advisor has something to say, so the comparison means something.
        #expect(!together.training.recommendations.isEmpty)
        // Player Removal writes money in the style handed in.
        let dollars = MoneyStyle(symbol: "$", period: .monthly)
        let inDollars = try report(r, money: dollars)
        #expect(inDollars.removal.money == dollars && together.removal.money == .weeklyPounds)
        #expect(inDollars == (try Self.oneByOne(r, money: dollars, catalog: catalog, profile: profile, parameters: .fm27)))
        #expect(!together.rest.isEmpty)
        #expect(!together.removal.advisedToLeave.isEmpty)
        #expect(!together.removal.loans.isEmpty)
        #expect(!together.depth.thin.isEmpty)
        // The other tactic's needs are its own: the striker slots, thin there and not in the primary.
        let t = together.training
        let needs = t.recommendations.flatMap(\.needs) + t.needsWithoutCandidates + t.needsBeingRetrained
        #expect(needs.contains(RetrainingNeed(tactic: other.name, slot: .ST_L)))
        #expect(!together.depth.thin.contains(.ST_C))
    }

    @Test func playerRemovalIsHandedTheHistoryTheDateAndTheAcceptedRetraining() throws {
        // The right back, 20, cannot play left back (familiarity 8) until he is retraining there. Six confirmed
        // matches in the last 60 days, two of them started by him.
        let back = rightBack()
        let days = ["2026-10-01", "2026-10-08", "2026-10-15", "2026-10-22", "2026-10-29", "2026-11-05"]
        let history = days.enumerated().map { index, day in
            ConfirmedLineup(fixture: FixtureID("f\(index)"), date: Day(iso: day)!,
                            starters: index < 2 ? [.D_R: back.id] : [:])
        }
        let retraining = Retraining(player: back.id, position: .defenderLeft, acceptedOn: asOf)
        func advice(_ request: AdvisorsRequest) throws -> RemovalAdvice {
            try #require(try report(request).removal.advice.first { $0.player == back.id })
        }
        let players = try thinAtLeftBack([back])
        let handed = try advice(request(players, history: history, accepted: [retraining]))
        #expect(handed.outlook?.slots.map(\.slot).contains(.D_L) == true)
        #expect(handed.matchesHere == MatchesHere(starts: 2, matches: 6, basis: .startedEnough))
        // Without them: no left back among his slots, and no matches to count.
        let without = try advice(request(players))
        #expect(without.outlook?.slots.map(\.slot).contains(.D_L) == false)
        #expect(without.matchesHere?.isCounted == false && without.matchesHere?.matches == 0)
    }

    @Test func trainingNeverRecommendsAPlayerRemovalWouldMoveOn() throws {
        // The right back is the only candidate for left back, and out of contract with a poor character.
        var back = rightBack()
        back.contractType = .outOfContract
        for (attribute, value) in [(Attribute.controversy, 20), (.ambition, 1), (.temperament, 1), (.consistency, 1)] {
            back.attributes[attribute] = value
        }
        let players = try thinAtLeftBack([back])
        let alone = try Training.report(tactics: [tactic], players: players, ownClub: ownClub, accepted: [], rejected: [],
                                        catalog: catalog, profile: profile, parameters: .fm27)
        try #require(alone.recommendations.map(\.choice.player) == [back.id])

        let r = try report(request(players))
        #expect(r.removal.advisedToLeave.contains(back.id))
        #expect(r.training.recommendations.isEmpty)
        // Left back, thin whoever goes, comes first; every other need is thin only because its cover is advised to
        // leave, and names him.
        let needs = r.training.needsWithoutCandidates
        #expect(needs.first == RetrainingNeed(tactic: tactic.name, slot: .D_L))
        #expect(needs.dropFirst().allSatisfy { !$0.going.isEmpty })
        #expect(needs.contains { $0.slot == .D_R && $0.going.contains(back.name) })
    }

    @Test func twoSavedTacticsGiveNeedsFromBoth() throws {
        let other = try Self.twoStrikers(from: tactic, catalog: catalog)
        let players = try thinAtLeftBack()
        // The two shapes really are judged differently: the other is thin at both striker slots, the primary at neither.
        let primaryDepth = try Depth.report(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                                            profile: profile, parameters: .fm27)
        let otherDepth = try Depth.report(tactic: other, players: players, ownClub: ownClub, catalog: catalog,
                                          profile: profile, parameters: .fm27)
        try #require(primaryDepth.thin == [.D_L])
        try #require(Set(otherDepth.thin) == [.D_L, .ST_L, .ST_C])
        let primaryNeed = RetrainingNeed(tactic: tactic.name, slot: .D_L)
        let otherNeeds = otherDepth.thin.map { RetrainingNeed(tactic: other.name, slot: $0) }

        // Training also lists the slots thin once the players Removal advises moving on have gone; those name who.
        func thinToday(_ r: AdvisorsReport) -> [RetrainingNeed] { r.training.needsWithoutCandidates.filter { $0.going.isEmpty } }
        let both = try report(request(players, tactics: [tactic, other]))
        #expect(thinToday(both) == [primaryNeed] + otherNeeds)
        let tactics = both.training.needsWithoutCandidates.map(\.tactic)
        #expect(tactics == tactics.filter { $0 == tactic.name } + tactics.filter { $0 == other.name })
        // The primary comes first and is not judged twice, even when the saved tactics list it again or leave it out.
        #expect(try report(request(players, tactics: [other, tactic, tactic])).training == both.training)
        #expect(try report(request(players, tactics: [other])).training == both.training)
        #expect(thinToday(try report(request(players, tactics: []))) == [primaryNeed])
        // Elevens, depth and removal judge against the primary alone.
        let alone = try report(request(players))
        #expect(both.elevens == alone.elevens && both.depth == alone.depth && both.removal == alone.removal)
        #expect(both.depth == primaryDepth)
        // With the other shape as primary, its own elevens and depth are reported.
        let swapped = try Advisors.report(
            AdvisorsRequest(primary: other, tactics: [tactic], players: players, ownClub: ownClub, history: StartHistory([]),
                            asOf: asOf, intensity: .medium, accepted: [], rejected: []),
            money: .weeklyPounds, catalog: catalog, profile: profile, parameters: .fm27)
        #expect(swapped.depth == otherDepth)
        #expect(swapped.elevens.first.map(\.slot).contains(.ST_L))
        #expect(thinToday(swapped) == otherNeeds + [primaryNeed])
    }

    @Test func inputOrderDoesNotMatter() throws {
        let other = try Self.twoStrikers(from: tactic, catalog: catalog)
        let players = try busySquad()
        let accepted = [Retraining(player: id("Back B"), position: .defenderCentral, acceptedOn: asOf),
                        Retraining(player: id("Tired"), position: .defenderLeft, acceptedOn: asOf)]
        let history = [ConfirmedLineup(fixture: FixtureID("f1"), date: asOf, starters: [.D_R: id("Tired")]),
                       ConfirmedLineup(fixture: FixtureID("f0"), date: asOf.adding(days: -3), starters: [.D_R: id("Tired")])]
        let forward = try report(request(players, tactics: [tactic, other], history: history, accepted: accepted))
        #expect(!forward.training.recommendations.isEmpty)
        var shuffled = players
        var generator = SeededGenerator(seed: 7)
        shuffled.shuffle(using: &generator)
        for list in [Array(players.reversed()), shuffled] {
            let again = try report(request(list, tactics: [tactic, other], history: Array(history.reversed()),
                                           accepted: Array(accepted.reversed())))
            #expect(again == forward)
        }
    }

    @Test func aBadParameterThrowsBadParametersOnce() throws {
        var q = EngineParameters.fm27
        var rules = q.removalRules.value
        rules.weakestShare = 1.5
        q.removalRules = Parameter(rules, .carriedOverFM26, source: "test")
        #expect(throws: PlanError.badParameters(["removalRules weakestShare is 1.5, not between 0 and 1"])) {
            try report(request(try busySquad()), parameters: q)
        }
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
