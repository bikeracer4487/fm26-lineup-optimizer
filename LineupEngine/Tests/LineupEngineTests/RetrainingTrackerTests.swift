import Foundation
import Testing
@testable import LineupEngine

@Suite struct RetrainingTrackerTests {
    let start = Day(iso: "2026-11-01")!
    var retraining: Retraining { Retraining(player: PlayerID(key: "right back"), position: .defenderLeft, acceptedOn: start) }

    func seen(_ days: Int, _ familiarity: Int) -> FamiliarityObservation {
        FamiliarityObservation(day: start.adding(days: days), familiarity: familiarity)
    }

    func progress(_ observations: [FamiliarityObservation], parameters: EngineParameters = .fm27) -> RetrainingProgress {
        RetrainingTracker.progress(of: retraining, observations: observations, parameters: parameters)
    }

    @Test func noObservationsIsNoData() {
        let p = progress([])
        #expect(p.state == .noData)
        #expect(p.start == nil && p.latest == nil && p.weeks == 0 && p.gainedPerWeek == nil && p.weeksToSolid == nil)
    }

    @Test func oneObservationIsImprovingWithNoRate() {
        let p = progress([seen(0, 8)])
        #expect(p.state == .improving)
        #expect(p.start == 8 && p.latest == 8 && p.weeks == 0)
        #expect(p.gainedPerWeek == nil && p.weeksToSolid == nil)
    }

    @Test func under1WeekGivesNoRate() {
        let p = progress([seen(0, 8), seen(6, 9)])
        #expect(p.state == .improving)
        #expect(p.gainedPerWeek == nil && p.weeksToSolid == nil)
        #expect(abs(p.weeks - 6.0 / 7.0) < 1e-9)
    }

    @Test func steadyGainGivesARateAndWeeksToSolid() {
        let p = progress([seen(0, 8), seen(10, 10), seen(21, 11)])
        #expect(p.state == .improving)
        #expect(p.start == 8 && p.latest == 11)
        #expect(abs(p.weeks - 3) < 1e-9)
        #expect(abs((p.gainedPerWeek ?? -1) - 1.0) < 1e-9)
        // (15 − 11) / 1.0
        #expect(p.weeksToSolid == 4)
        // A part week counts as a whole one: 3 gained over 24 days is 0.875 a week, and (15 − 11) / 0.875 = 4.57.
        let slower = progress([seen(0, 8), seen(24, 11)])
        #expect(slower.weeksToSolid == 5)
    }

    @Test func solidFamiliarityIsReached() {
        let p = progress([seen(0, 8), seen(28, 15)])
        #expect(p.state == .reached)
        #expect(p.latest == 15 && p.weeksToSolid == nil)
        #expect(progress([seen(0, 15)]).state == .reached)
        // One short of solid is still improving.
        #expect(progress([seen(0, 8), seen(28, 14)]).state == .improving)
    }

    @Test func noGainOverSixWeeksIsStalled() {
        let p = progress([seen(0, 9), seen(42, 9)])
        #expect(p.state == .stalled)
        #expect(p.gainedPerWeek == 0 && p.weeksToSolid == nil)
        // At five weeks it is too soon to say.
        let early = progress([seen(0, 9), seen(35, 9)])
        #expect(early.state == .improving && early.weeksToSolid == nil)
        // Any gain over six weeks is not stalled.
        #expect(progress([seen(0, 9), seen(42, 10)]).state == .improving)
    }

    @Test func aFallIsNeverANegativeFigure() {
        let early = progress([seen(0, 10), seen(14, 9)])
        #expect(early.state == .improving)
        #expect(early.gainedPerWeek == 0)
        #expect(early.weeksToSolid == nil)
        let late = progress([seen(0, 10), seen(42, 9)])
        #expect(late.state == .stalled)
        #expect(late.gainedPerWeek == 0 && late.weeksToSolid == nil)
        #expect(late.weeks >= 0)
    }

    @Test func theStalledLineIsTheParameter() {
        var q = EngineParameters.fm27
        q.retrainingStalledAfterWeeks = Parameter(5, .derived, source: "test")
        #expect(progress([seen(0, 9), seen(35, 9)], parameters: q).state == .stalled)
        #expect(progress([seen(0, 9), seen(35, 9)]).state == .improving)
    }

    @Test func observationsBeforeAcceptanceAreIgnored() {
        let p = progress([seen(-14, 3), seen(-1, 7), seen(0, 8), seen(21, 11)])
        #expect(p.start == 8 && abs(p.weeks - 3) < 1e-9)
        #expect(progress([seen(-14, 3), seen(-1, 7)]).state == .noData)
    }

    @Test func twoOnOneDayCountTheLaterInTheList() {
        let p = progress([seen(0, 8), seen(21, 10), seen(21, 11)])
        #expect(p.latest == 11)
    }

    @Test func inputOrderDoesNotMatter() {
        let observations = [seen(0, 8), seen(7, 9), seen(14, 9), seen(21, 11), seen(-3, 2)]
        let forward = progress(observations)
        #expect(progress(observations.reversed()) == forward)
        #expect(progress([observations[3], observations[0], observations[4], observations[2], observations[1]]) == forward)
    }
}
