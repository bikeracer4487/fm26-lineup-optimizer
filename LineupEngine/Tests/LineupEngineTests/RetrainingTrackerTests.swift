import Foundation
import Testing
@testable import LineupEngine

@Suite struct RetrainingTrackerTests {
    let start = Day(iso: "2026-11-01")!
    var retraining: Retraining { Retraining(player: PlayerID(key: "right back"), position: .defenderLeft, acceptedOn: start) }

    func seen(_ days: Int, _ familiarity: Int) -> FamiliarityObservation {
        FamiliarityObservation(day: start.adding(days: days), familiarity: familiarity)
    }

    func progress(_ observations: [FamiliarityObservation], expectedWeeks: Int? = nil,
                  parameters: EngineParameters = .fm27) -> RetrainingProgress {
        RetrainingTracker.progress(of: retraining, observations: observations, expectedWeeks: expectedWeeks,
                                   parameters: parameters)
    }

    // MARK: Behind the estimate

    @Test func aGainFarBehindTheEstimateIsBehind() {
        // The owner's left back on 2 January 2027 in the save: 1 to 4 in 21 weeks, against 21 weeks estimated to reach 15.
        let p = progress([seen(0, 1), seen(148, 4)], expectedWeeks: 21)
        #expect(p.state == .behind)
        #expect(p.expectedWeeks == 21)
        // 3 gained over 148 days is 0.142 a week, and (15 − 4) / 0.142 = 77.5.
        #expect(p.weeksToSolid == 78)
    }

    @Test func aGainAtHalfThePaceTheEstimateNeedsIsNotBehind() {
        // 14 to gain in 28 weeks needs 0.5 a week; 2 in 8 weeks is half of that, the line.
        let onTheLine = progress([seen(0, 1), seen(56, 3)], expectedWeeks: 28)
        #expect(onTheLine.state == .improving && onTheLine.expectedWeeks == 28)
        // 2 in 9 weeks is under it.
        #expect(progress([seen(0, 1), seen(63, 3)], expectedWeeks: 28).state == .behind)
    }

    @Test func itIsTooSoonToSayBehindBeforeTheStalledLine() {
        // Far behind an estimate of four weeks, but five weeks of readings are too few; six are enough.
        #expect(progress([seen(0, 1), seen(35, 2)], expectedWeeks: 4).state == .improving)
        #expect(progress([seen(0, 1), seen(42, 2)], expectedWeeks: 4).state == .behind)
    }

    @Test func withoutAnEstimateNothingIsBehind() {
        let p = progress([seen(0, 1), seen(148, 4)])
        #expect(p.state == .improving && p.expectedWeeks == nil && p.weeksToSolid == 78)
    }

    @Test func noGainIsStalledAndSolidIsReachedWhateverTheEstimate() {
        #expect(progress([seen(0, 9), seen(42, 9)], expectedWeeks: 4).state == .stalled)
        #expect(progress([seen(0, 1), seen(148, 15)], expectedWeeks: 4).state == .reached)
    }

    @Test func theEstimateIsWorkedOutForThePlayerFromWhereHeStarted() {
        // A right back of 23 with Versatility 13 learning left back from 1: a structural change, 16 × 1.3 = 21 weeks.
        let back = Player.fixture(name: "Right Back", age: 23, attributes: [.versatility: 13],
                                  familiarity: [.defenderRight: 20, .defenderLeft: 4])
        let observations = [seen(0, 1), seen(148, 4)]
        let p = RetrainingTracker.progress(of: retraining, observations: observations, player: back, parameters: .fm27)
        #expect(p.expectedWeeks == 21 && p.state == .behind)
        #expect(p == progress(observations, expectedWeeks: 21))
        // With nothing read yet there is no start to estimate from.
        let unread = RetrainingTracker.progress(of: retraining, observations: [], player: back, parameters: .fm27)
        #expect(unread.state == .noData && unread.expectedWeeks == nil)
        // A striker learning left back is an inversion, which has no estimate: never behind.
        let striker = Player.fixture(name: "Striker", age: 23, attributes: [.versatility: 13], familiarity: [.striker: 20])
        let inverted = RetrainingTracker.progress(of: retraining, observations: observations, player: striker, parameters: .fm27)
        #expect(inverted.expectedWeeks == nil && inverted.state == .improving)
        // Nor is a player whose Versatility is missing.
        var blank = back
        blank.attributes[.versatility] = nil
        #expect(RetrainingTracker.progress(of: retraining, observations: observations, player: blank, parameters: .fm27)
            == progress(observations))
    }

    @Test func theBehindLineIsTheParameter() {
        var q = EngineParameters.fm27
        q.retrainingBehindShare = Parameter(0.2, .derived, source: "test")
        // 0.142 a week against 0.667 needed is 21%: behind at a half, not at a fifth.
        #expect(progress([seen(0, 1), seen(148, 4)], expectedWeeks: 21, parameters: q).state == .improving)
        #expect(progress([seen(0, 1), seen(148, 4)], expectedWeeks: 21).state == .behind)
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
