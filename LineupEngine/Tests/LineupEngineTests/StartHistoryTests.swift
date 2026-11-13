import Testing
@testable import LineupEngine

@Suite struct StartHistoryTests {
    let a = PlayerID(key: "a")
    let b = PlayerID(key: "b")
    let base = Day(year: 2026, month: 8, day: 1)!

    func day(_ n: Int) -> Day { base.adding(days: n) }

    func lineup(_ n: Int, _ players: [PlayerID], slot: SlotID = .D_L, fixture: String? = nil) -> ConfirmedLineup {
        var starters: [SlotID: PlayerID] = [:]
        for (i, player) in players.enumerated() {
            starters[SlotID.allCases[SlotID.allCases.firstIndex(of: slot)! + i]] = player
        }
        return ConfirmedLineup(fixture: FixtureID(fixture ?? "f\(n)"), date: day(n), starters: starters)
    }

    func run(_ days: [Int], missed: Set<Int> = [], fixture: Int, window: Int = 4) -> Int {
        let lineups = days.map { lineup($0, missed.contains($0) ? [b] : [a]) }
        return StartHistory(lineups).consecutiveStarts(of: a, before: day(fixture), windowDays: window)
    }

    @Test func countsARunOfStartsThreeDaysApart() {
        #expect(run([0, 3, 6], fixture: 9) == 3)
    }

    @Test func aMissedMatchEndsTheRun() {
        #expect(run([0, 3, 6], missed: [3], fixture: 9) == 1)
    }

    @Test func notStartingTheLastMatchGivesZero() {
        #expect(run([0, 3, 6], missed: [6], fixture: 9) == 0)
    }

    @Test func aWeekBetweenMatchesEndsTheRun() {
        #expect(run([0, 7, 10], fixture: 13) == 2)
    }

    @Test func aWeekSinceTheLastMatchGivesZero() {
        #expect(run([0], fixture: 7) == 0)
    }

    @Test func aGapOfExactlyTheWindowStillCounts() {
        #expect(run([0, 4], fixture: 8) == 2)
        #expect(run([0, 4], fixture: 9) == 0)
    }

    @Test func lineupsOnOrAfterTheDayAreIgnored() {
        let history = StartHistory([lineup(0, [a]), lineup(3, [a]), lineup(6, [a]), lineup(9, [a])])
        #expect(history.consecutiveStarts(of: a, before: day(6), windowDays: 4) == 2)
        #expect(history.recentSlots(of: a, before: day(3), limit: 5) == [.D_L])
    }

    @Test func recentSlotsAreNewestFirstAndSkipMatchesHeMissed() {
        let history = StartHistory([
            lineup(0, [a], slot: .D_L), lineup(3, [b], slot: .D_L), lineup(6, [a], slot: .D_R),
        ])
        #expect(history.recentSlots(of: a, before: day(9), limit: 5) == [.D_R, .D_L])
        #expect(history.recentSlots(of: a, before: day(9), limit: 1) == [.D_R])
    }

    @Test func inputOrderDoesNotMatter() {
        let lineups = [lineup(0, [a]), lineup(3, [a]), lineup(6, [b]), lineup(7, [a], fixture: "x"), lineup(7, [a], slot: .ST_C, fixture: "w")]
        let forward = StartHistory(lineups)
        let backward = StartHistory(lineups.reversed())
        let shuffled = StartHistory([lineups[3], lineups[0], lineups[4], lineups[2], lineups[1]])
        for other in [backward, shuffled] {
            #expect(other.consecutiveStarts(of: a, before: day(10), windowDays: 4)
                == forward.consecutiveStarts(of: a, before: day(10), windowDays: 4))
            #expect(other.recentSlots(of: a, before: day(10), limit: 10) == forward.recentSlots(of: a, before: day(10), limit: 10))
        }
        #expect(forward.recentSlots(of: a, before: day(10), limit: 10) == [.D_L, .ST_C, .D_L, .D_L])
    }

    @Test func aSecondEntryForAFixtureReplacesTheFirst() {
        let first = lineup(0, [a], fixture: "same")
        let second = lineup(0, [b], fixture: "same")
        #expect(StartHistory([first, second]).consecutiveStarts(of: a, before: day(2), windowDays: 4) == 0)
        #expect(StartHistory([second, first]).consecutiveStarts(of: a, before: day(2), windowDays: 4) == 1)
        let added = StartHistory([first]).adding(second)
        #expect(added.consecutiveStarts(of: a, before: day(2), windowDays: 4) == 0)
        #expect(added.consecutiveStarts(of: b, before: day(2), windowDays: 4) == 1)
    }

    @Test func aPlayerInTwoSlotsCountsOnceAndReportsTheLowerSlot() {
        let both = ConfirmedLineup(fixture: FixtureID("f"), date: day(0), starters: [.ST_C: a, .D_R: a])
        let history = StartHistory([both])
        #expect(history.consecutiveStarts(of: a, before: day(2), windowDays: 4) == 1)
        #expect(history.recentSlots(of: a, before: day(2), limit: 5) == [.D_R])
    }

    @Test func sameDateLineupsAreOrderedByFixtureId() {
        let history = StartHistory([lineup(0, [a], slot: .D_L, fixture: "b"), lineup(0, [a], slot: .D_R, fixture: "a")])
        #expect(history.recentSlots(of: a, before: day(1), limit: 5) == [.D_L, .D_R])
    }

    @Test func anUnknownPlayerHasNoHistory() {
        let history = StartHistory([lineup(0, [a])])
        let stranger = PlayerID(key: "nobody")
        #expect(history.consecutiveStarts(of: stranger, before: day(2), windowDays: 4) == 0)
        #expect(history.recentSlots(of: stranger, before: day(2), limit: 5).isEmpty)
    }

    @Test func theWindowParameterIsDerivedAndCitesTheRotationGuide() {
        let parameter = EngineParameters.fm27.consecutiveStartWindowDays
        #expect(parameter.value == 4)
        #expect(parameter.evidence == .derived)
        #expect(parameter.source.contains("player-rotation-guide.md"))
    }
}
