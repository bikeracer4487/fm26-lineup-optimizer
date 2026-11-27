import Foundation
import Testing
@testable import LineupEngine

/// What a player would be worth in a slot, as the candidate picker shows it before he is chosen.
extension LineupSelectorTests {
    func assignment(_ slot: SlotID) throws -> SlotAssignment {
        try #require(try tactic.assignments(catalog: RoleCatalog.fm27()).first { $0.slot == slot })
    }

    func player(_ name: String, in request: SelectionRequest) throws -> Player {
        try #require(request.players.first { $0.name == name })
    }

    @Test func everyPickIsWorthWhatItsPickShows() throws {
        let players = changing("Striker", in: squad()) { $0.condition = 0.90; $0.sharpness = 0.75 }
        let held = Adjustment(kind: .consecutiveStarts, factor: 0.9, reason: "Has started the last 2 matches in quick succession (×0.90)")
        let saved = Adjustment(kind: .savedForLater, cost: 2, reason: "Kept fresher for Buxton")
        let req = adjusted(request(players), every: [id("Striker"): [held]], slots: [id("Left Back"): [.D_L: [saved]]])
        let lineup = try selector.select(req)
        #expect(lineup.picks.count == 11)
        for pick in lineup.picks {
            let worth = try selector.worth(of: try player(pick.name, in: req), in: try assignment(pick.slot), req)
            #expect(worth.player == pick.player && worth.name == pick.name)
            #expect(worth.rating == pick.rating)
            #expect(worth.fitness == pick.fitness)
            #expect(worth.adjustments == pick.adjustments)
            #expect(worth.value == pick.value, "\(pick.name)")
            #expect(worth.working == Array(pick.reasons.dropFirst()), "\(pick.name)")
            #expect(worth.exclusion == nil)
        }
    }

    @Test func aFitPlayerWithNoAdjustmentIsWorthHisRatingAndHasNoWorking() throws {
        let req = request(squad())
        let worth = try selector.worth(of: try player("Striker", in: req), in: try assignment(.ST_C), req)
        #expect(worth.value == worth.rating.value)
        #expect(worth.working.isEmpty)
    }

    @Test func aPlayerLeftOutIsWorthWhatHisPickShowsOnceChosen() throws {
        // Unfit and held back, so the cover starts; the picker must show what choosing him would put on the pitch.
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 17])
        let players = changing("Striker", in: squad(cover)) { $0.condition = 0.93; $0.sharpness = 0.94 }
        let held = Adjustment(kind: .consecutiveStarts, factor: 0.9, reason: "Has started the last 2 matches in quick succession (×0.90)")
        let req = adjusted(request(players), every: [id("Striker"): [held]])
        #expect(pick(try selector.select(req), .ST_C)?.player == id("Cover Striker"))

        let worth = try selector.worth(of: try player("Striker", in: req), in: try assignment(.ST_C), req)
        #expect(worth.value < worth.rating.value * 0.9)
        #expect(worth.working == ["Condition 93% (×0.96)", "Sharpness 94% (×0.98)",
                                  "Has started the last 2 matches in quick succession (×0.90)"])

        var chosen = req
        chosen.overrides = [.ST_C: id("Striker")]
        let st = try #require(pick(try selector.select(chosen), .ST_C))
        #expect(st.player == id("Striker"))
        #expect(st.value == worth.value)
        #expect(st.reasons == ["Rating \(oneDecimal(st.rating.value)): striker familiarity 20 in possession, striker familiarity 20 out of possession"]
                + worth.working + ["Chosen by you"])
    }

    @Test func anAdjustmentForAnotherSlotIsNotCountedInThisOne() throws {
        let saved = Adjustment(kind: .savedForLater, cost: 2, reason: "Kept fresher for Buxton")
        let req = adjusted(request(squad()), slots: [id("Left Centre Back"): [.D_CL: [saved]]])
        let centreBack = try player("Left Centre Back", in: req)
        let left = try selector.worth(of: centreBack, in: try assignment(.D_CL), req)
        let right = try selector.worth(of: centreBack, in: try assignment(.D_CR), req)
        #expect(left.value == left.rating.value - 2 && left.working == ["Kept fresher for Buxton"])
        #expect(right.value == right.rating.value && right.working.isEmpty)
    }

    @Test func projectedFitnessIsCalledProjectedInTheWorking() throws {
        let players = changing("Striker", in: squad()) { $0.condition = 0.90 }
        let req = adjusted(request(players), projected: true)
        let worth = try selector.worth(of: try player("Striker", in: req), in: try assignment(.ST_C), req)
        #expect(worth.working == ["Projected condition 90% (×0.94)"])
    }

    @Test func aPlayerARuleLeavesOutCarriesTheRuleAndWhatHeWouldBeWorthIfChosen() throws {
        let cover = Player.fixture(name: "Cover Striker", familiarity: [.striker: 17])
        let players = changing("Striker", in: squad(cover)) { $0.condition = 0.80 }
        let req = request(players, rejected: [id("Cover Striker")])
        let floored = try selector.worth(of: try player("Striker", in: req), in: try assignment(.ST_C), req)
        #expect(floored.exclusion == .belowConditionFloor(0.80))
        var chosen = req
        chosen.overrides = [.ST_C: id("Striker")]
        #expect(pick(try selector.select(chosen), .ST_C)?.value == floored.value)

        let rejected = try selector.worth(of: try player("Cover Striker", in: req), in: try assignment(.ST_C), req)
        #expect(rejected.exclusion == .rejected)
        #expect(rejected.value == rejected.rating.value)

        // A ban counts only in the fixture it is served in, as for the selector.
        let banned = changing("Striker", in: squad()) { $0.isBanned = true }
        let served = request(banned, isNextFixture: true), later = request(banned, isNextFixture: false)
        #expect(try selector.worth(of: try player("Striker", in: served), in: try assignment(.ST_C), served).exclusion == .banned)
        #expect(try selector.worth(of: try player("Striker", in: later), in: try assignment(.ST_C), later).exclusion == nil)
    }

    @Test func aPlayerOutOnLoanCarriesThatExclusion() throws {
        let away = Player.fixture(name: "Away Striker", familiarity: [.striker: 20], loanedTo: "Wallingford")
        let req = request(squad(away))
        let worth = try selector.worth(of: away, in: try assignment(.ST_C), req)
        #expect(worth.exclusion == .outOnLoan(to: "Wallingford"))
    }

    @Test func aPlayerWithMissingDataThrows() throws {
        let players = changing("Striker", in: squad()) { $0.attributes = [:] }
        let req = request(players)
        #expect(throws: RatingError.self) {
            try selector.worth(of: try player("Striker", in: req), in: try assignment(.ST_C), req)
        }
    }
}
