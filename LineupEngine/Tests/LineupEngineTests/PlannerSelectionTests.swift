import Foundation
import Testing
@testable import LineupEngine

/// What the planner keeps of each fixture's selection, so any player can be valued in a slot of it.
extension PlannerScenarioTests {
    @Test func eachPlannedFixtureKeepsWhatTheSelectorWasTold() throws {
        // Three matches in a week: the later ones are picked on projected fitness and with the importance rules' adjustments.
        let players = try PlannerFixture.squad()
        let fixtures = [fixture("a", .medium, day: 0), fixture("b", .medium, day: 3), fixture("c", .low, day: 6)]
        let result = try plan(fixtures, players)
        let selector = LineupSelector(catalog: try RoleCatalog.fm27(), profile: try RatingProfile.standard(), parameters: parameters)
        #expect(result.fixtures.count == 3)
        for planned in result.fixtures {
            #expect(try selector.select(planned.selection) == planned.lineup)
            #expect(planned.selection.fitnessIsProjected == planned.fitnessIsProjected)
            for pick in planned.lineup.picks {
                let player = try #require(planned.selection.players.first { $0.id == pick.player })
                let worth = try selector.worth(of: player, in: try #require(assignments.first { $0.slot == pick.slot }),
                                               planned.selection)
                #expect(worth.value == pick.value)
                #expect(worth.working == Array(pick.reasons.dropFirst()))
            }
        }
        #expect(result.fixtures.contains { $0.lineup.picks.contains { !$0.adjustments.isEmpty } },
                "the scenario must carry an adjustment, or it shows nothing about them")
    }

    @Test func aPlayerLeftOutOfALaterFixtureIsWorthWhatHisPickShowsOnceChosen() throws {
        let players = try PlannerFixture.squad()
        let fixtures = [fixture("a", .medium, day: 0), fixture("b", .medium, day: 3), fixture("c", .low, day: 6)]
        let before = try plan(fixtures, players).fixtures[1]
        let selector = LineupSelector(catalog: try RoleCatalog.fm27(), profile: try RatingProfile.standard(), parameters: parameters)
        // Whoever holds the striker's slot in the second match, the other striker is left out of it.
        let holder = try #require(pick(before, .ST_C)?.player)
        let benched = holder == id(.ST_C) ? id(.ST_C, "second") : id(.ST_C)
        #expect(!starters(before).contains(benched))
        let onTheDay = try #require(before.selection.players.first { $0.id == benched })
        let worth = try selector.worth(of: onTheDay, in: try #require(assignments.first { $0.slot == .ST_C }), before.selection)

        var chosen = fixtures
        chosen[1].overrides = [.ST_C: benched]
        let after = try plan(chosen, players).fixtures[1]
        let his = try #require(pick(after, .ST_C))
        #expect(his.player == benched && his.isOverride)
        #expect(his.value == worth.value)
        #expect(Array(his.reasons.dropFirst()) == worth.working + ["Chosen by you"])
    }
}
