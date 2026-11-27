import Foundation
import Testing
@testable import LineupEngine

@Suite struct RenewalWorthTests {
    let rules = EngineParameters.fm27.declineRules.value

    @Test func theFallIsTheLastStepAtOrUnderTheAge() {
        for (age, points) in [(29, 0.0), (30, 3), (31, 3), (32, 6), (34, 6), (35, 9), (40, 9)] {
            #expect(Renewal.fall(at: age, rules: rules) == points, "age \(age)")
        }
    }

    @Test func abilityAfterDeclineTakesEachSeasonAtItsAge() {
        for (ability, age, after) in [(70, 28, 70.0), (70, 29, 67), (70, 30, 64), (70, 31, 61), (70, 34, 55), (70, 35, 52),
                                      (5, 35, 0)] {
            #expect(Renewal.abilityAfterDecline(ability, age: age, rules: rules) == after, "\(ability) at \(age)")
        }
    }

    @Test func problemsAreFoundInTheDeclineRules() {
        #expect(Renewal.problems(in: rules).isEmpty)
        func found(_ edit: (inout DeclineRules) -> Void) -> [String] {
            var r = rules; edit(&r); return Renewal.problems(in: r)
        }
        let cases: [[String]] = [
            found { $0.steps = [DeclineStep(fromAge: 32, points: 6), DeclineStep(fromAge: 30, points: 3)] },
            found { $0.steps[0].points = -1 },
            found { $0.steps[0].points = .nan },
            found { $0.seasons = 0 },
            found { $0.steps = [] },
        ]
        for sentences in cases {
            #expect(sentences.count == 1)
            #expect(sentences.first?.contains("declineRules") == true)
        }
        var bad = EngineParameters.fm27
        bad.declineRules = Parameter(DeclineRules(steps: [], seasons: 2), .derived, source: "test")
        #expect(FitnessModel.problems(in: bad).contains { $0.contains("declineRules") })
        #expect(!FitnessModel.problems(in: .fm27).contains { $0.contains("declineRules") })
    }

    @Test func theStandardIsTheOutfieldFirstChoicesInPosition() throws {
        let tactic = try PlannerFixture.tactic()
        let catalog = try RoleCatalog.fm27()
        let profile = try RatingProfile.standard()
        let players = try PlannerFixture.squad()
        let needs = try Scouting.needs(tactic: tactic, players: players, ownClub: "Oxford City", going: [], retraining: [],
                                       catalog: catalog, profile: profile, parameters: .fm27)
        let standard = Renewal.standard(elevens: needs.elevens, depth: needs.depth, players: players, parameters: .fm27)
        #expect(standard.rating != nil)
        #expect(standard.rating == needs.outfieldAverageRating)
        #expect(standard.ability == needs.outfieldAverageAbility)
    }

    @Test func aSquadOfOneGoalkeeperHasNoStandard() throws {
        let tactic = try PlannerFixture.tactic()
        let catalog = try RoleCatalog.fm27()
        let profile = try RatingProfile.standard()
        let keeper = try #require(try tactic.assignments(catalog: catalog).first { $0.ipPosition == .goalkeeper })
        let players = try PlannerFixture.squad().filter { $0.id == PlannerFixture.id(keeper.slot, "first") }
        #expect(players.count == 1)
        let needs = try Scouting.needs(tactic: tactic, players: players, ownClub: "Oxford City", going: [], retraining: [],
                                       catalog: catalog, profile: profile, parameters: .fm27)
        let standard = Renewal.standard(elevens: needs.elevens, depth: needs.depth, players: players, parameters: .fm27)
        #expect(standard == SquadStandard(rating: nil, ability: nil))
    }
}
