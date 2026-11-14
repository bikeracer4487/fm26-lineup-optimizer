import Foundation
import Testing
@testable import LineupEngine

@Suite struct ElevensTests {
    let tactic = try! PlannerFixture.tactic()
    let catalog = try! RoleCatalog.fm27()
    let profile = try! RatingProfile.standard()

    func report(_ players: [Player], ownClub: String? = "Oxford City") throws -> ElevensReport {
        try Elevens.report(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                           profile: profile, parameters: .fm27)
    }

    @Test func theReportListsBothElevensInSlotOrderWithTheirRatings() throws {
        let r = try report(PlannerFixture.squad())
        let assignments = try tactic.assignments(catalog: catalog)
        #expect(r.first.map(\.slot) == assignments.map(\.slot))
        #expect(r.second.map(\.slot) == assignments.map(\.slot))
        #expect(r.unfilledFirst.isEmpty && r.unfilledSecond.isEmpty)
        let engine = RatingEngine(profile: profile, parameters: .fm27, configuration: .fm27)
        let squad = try PlannerFixture.squad()
        for place in r.first + r.second {
            let player = try #require(squad.first { $0.id == place.player })
            let assignment = try #require(assignments.first { $0.slot == place.slot })
            #expect(place.rating == (try engine.rating(for: player, in: assignment)))
            #expect(place.name == player.name)
            #expect(!place.isInjured)
        }
        #expect(r.first.map(\.player) == assignments.map { r.tiers.first[$0.slot]! })
        #expect(r.second.map(\.player) == assignments.map { r.tiers.second[$0.slot]! })
    }

    @Test func anInjuredFirstChoiceIsListedAndMarked() throws {
        let squad = try PlannerFixture.squad().map { p -> Player in
            var p = p; if p.id == PlannerFixture.id(.ST_C, "first") { p.isInjured = true }; return p
        }
        let r = try report(squad)
        let place = try #require(r.first.first { $0.slot == .ST_C })
        #expect(place.player == PlannerFixture.id(.ST_C, "first"))
        #expect(place.isInjured)
        #expect(r.first.filter(\.isInjured).count == 1)
        #expect(r.second.allSatisfy { !$0.isInjured })
    }

    @Test func averagesAreTheMeanOfTheRatings() throws {
        let r = try report(PlannerFixture.squad())
        let f = r.first.map(\.rating.value), s = r.second.map(\.rating.value)
        #expect(abs(try #require(r.firstAverage) - f.reduce(0, +) / Double(f.count)) < 1e-9)
        #expect(abs(try #require(r.secondAverage) - s.reduce(0, +) / Double(s.count)) < 1e-9)
        #expect(try #require(r.firstAverage) > #require(r.secondAverage))
    }

    @Test func aSquadOfFifteenLeavesSecondElevenSlotsUnfilled() throws {
        let all = try PlannerFixture.squad()
        let firsts = all.filter { $0.name.hasSuffix("first") }
        let seconds = all.filter { $0.name.hasSuffix("second") }.prefix(4)
        let r = try report(firsts + seconds)
        #expect(r.first.count == 11 && r.unfilledFirst.isEmpty)
        #expect(r.second.count == 4)
        #expect(r.unfilledSecond.count == 7)
        #expect(Set(r.unfilledSecond).isDisjoint(with: r.second.map(\.slot)))
        let mean = r.second.map(\.rating.value).reduce(0, +) / 4
        #expect(abs(try #require(r.secondAverage) - mean) < 1e-9)
    }

    @Test func noPlayersGivesEmptyElevensAndNoAverages() throws {
        let r = try report([])
        #expect(r.first.isEmpty && r.second.isEmpty)
        #expect(r.firstAverage == nil && r.secondAverage == nil)
        #expect(r.unfilledFirst.count == 11 && r.unfilledSecond.count == 11)
    }

    @Test func aPlayerOutOnLoanIsNotInTheElevens() throws {
        let squad = try PlannerFixture.squad().map { p -> Player in
            var p = p; if p.id == PlannerFixture.id(.AM_C, "first") { p.loanedTo = "Elsewhere FC"; p.isInjured = true }; return p
        }
        let r = try report(squad)
        #expect(!r.first.contains { $0.player == PlannerFixture.id(.AM_C, "first") })
        #expect(!r.second.contains { $0.player == PlannerFixture.id(.AM_C, "first") })
    }

    @Test func inputOrderDoesNotMatter() throws {
        let squad = try PlannerFixture.squad()
        let a = try report(squad)
        #expect(try report(squad.reversed()) == a)
        #expect(try report(Array(squad[7...] + squad[..<7])) == a)
    }
}
