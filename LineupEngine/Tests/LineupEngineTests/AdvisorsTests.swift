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

    func request(_ players: [Player], tactics: [Tactic]? = nil, history: [ConfirmedLineup] = [],
                 accepted: [Retraining] = [], rejected: Set<RetrainingChoice> = []) -> AdvisorsRequest {
        AdvisorsRequest(primary: tactic, tactics: tactics ?? [tactic], players: players, ownClub: ownClub,
                        history: StartHistory(history), asOf: asOf, intensity: .medium, accepted: accepted,
                        rejected: rejected)
    }

    func report(_ request: AdvisorsRequest, parameters: EngineParameters = .fm27) throws -> AdvisorsReport {
        try Advisors.report(request, catalog: catalog, profile: profile, parameters: parameters)
    }

    /// Every advisor called on its own, as a caller without `Advisors.report` would.
    static func oneByOne(_ r: AdvisorsRequest, catalog: RoleCatalog, profile: RatingProfile,
                         parameters: EngineParameters) throws -> AdvisorsReport {
        let elevens = try Elevens.report(tactic: r.primary, players: r.players, ownClub: r.ownClub, catalog: catalog,
                                         profile: profile, parameters: parameters)
        let depth = try Depth.report(tactic: r.primary, players: r.players, ownClub: r.ownClub, catalog: catalog,
                                     profile: profile, parameters: parameters)
        let rest = try Rest.advice(players: r.players, ownClub: r.ownClub, history: r.history, asOf: r.asOf,
                                   intensity: r.intensity, parameters: parameters)
        let removal = try Removal.report(tactic: r.primary, players: r.players, ownClub: r.ownClub, catalog: catalog,
                                         profile: profile, parameters: parameters)
        var tactics = [r.primary]
        for t in r.tactics where !tactics.contains(t) { tactics.append(t) }
        let training = try Training.report(tactics: tactics, players: r.players, ownClub: r.ownClub, accepted: r.accepted,
                                           rejected: r.rejected, leaving: removal.advisedToLeave, catalog: catalog,
                                           profile: profile, parameters: parameters)
        return AdvisorsReport(elevens: elevens, depth: depth, rest: rest, removal: removal, training: training)
    }

    @Test func theReportEqualsTheAdvisorsCalledOneByOne() throws {
        var other = tactic
        other.name = "Second Sample"
        let history = [ConfirmedLineup(fixture: FixtureID("f1"), date: asOf, starters: [.D_R: id("Tired")])]
        let r = request(try busySquad(), tactics: [tactic, other], history: history,
                        accepted: [Retraining(player: id("Back B"), position: .defenderCentral, acceptedOn: asOf)])
        let together = try report(r)
        #expect(together == (try Self.oneByOne(r, catalog: catalog, profile: profile, parameters: .fm27)))
        // Every advisor has something to say, so the comparison means something.
        #expect(!together.training.recommendations.isEmpty)
        #expect(!together.rest.isEmpty)
        #expect(!together.removal.advisedToLeave.isEmpty)
        #expect(!together.removal.loans.isEmpty)
        #expect(!together.depth.thin.isEmpty)
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
        #expect(r.training.needsWithoutCandidates == [RetrainingNeed(tactic: tactic.name, slot: .D_L)])
    }

    @Test func twoSavedTacticsGiveNeedsFromBoth() throws {
        var other = tactic
        other.name = "Second Sample"
        let players = try thinAtLeftBack()
        let primaryNeed = RetrainingNeed(tactic: tactic.name, slot: .D_L)
        let otherNeed = RetrainingNeed(tactic: other.name, slot: .D_L)

        let both = try report(request(players, tactics: [tactic, other]))
        #expect(both.training.needsWithoutCandidates == [primaryNeed, otherNeed])
        // The primary comes first and is not judged twice, even when the saved tactics list it again or leave it out.
        #expect(try report(request(players, tactics: [other, tactic, tactic])).training == both.training)
        #expect(try report(request(players, tactics: [other])).training == both.training)
        #expect(try report(request(players, tactics: [])).training.needsWithoutCandidates == [primaryNeed])
        // Elevens, depth and removal judge against the primary alone.
        let alone = try report(request(players))
        #expect(both.elevens == alone.elevens && both.depth == alone.depth && both.removal == alone.removal)
    }

    @Test func inputOrderDoesNotMatter() throws {
        var other = tactic
        other.name = "Second Sample"
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
