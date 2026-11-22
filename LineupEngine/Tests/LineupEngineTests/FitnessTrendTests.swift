import Foundation
import Testing
@testable import LineupEngine

@Suite struct FitnessTrendTests {
    let p = EngineParameters.fm27
    let start = Day(year: 2026, month: 9, day: 1)!
    func id(_ name: String) -> PlayerID { PlayerID(key: name) }
    func r(_ day: Int, _ jadedness: Int, injured: Bool = false, includes: [String] = []) -> FitnessReading {
        FitnessReading(day: start.adding(days: day), jadedness: jadedness, condition: 0.9, sharpness: 0.9,
                       isInjured: injured, includes: includes.map(FixtureID.init))
    }
    func lineup(_ fixture: String, day: Int, _ starters: String...) -> ConfirmedLineup {
        ConfirmedLineup(fixture: FixtureID(fixture), date: start.adding(days: day),
                        starters: Dictionary(uniqueKeysWithValues: zip(SlotID.allCases, starters.map(id))))
    }
    /// Falls 2 a day with no start: 100, 86, 72, 58 a week apart.
    var resting: [FitnessReading] { [r(0, 100), r(7, 86), r(14, 72), r(21, 58)] }
    /// Rises 17 a week with one start in each: at −2 a day that is 31 a start.
    var starting: [FitnessReading] { [r(0, 100), r(7, 117), r(14, 134), r(21, 151)] }
    func matches(_ names: String...) -> [ConfirmedLineup] {
        [3, 10, 17].map { day in ConfirmedLineup(fixture: FixtureID("m\(day)"), date: start.adding(days: day),
            starters: Dictionary(uniqueKeysWithValues: zip(SlotID.allCases, names.map(id)))) }
    }
    func rates(_ readings: [String: [FitnessReading]], _ confirmed: [ConfirmedLineup] = [],
               squads: [String: Squad]? = nil, asOf: Int = 21, from: Int? = nil) -> FitnessTrends {
        FitnessTrend.rates(
            readings: Dictionary(uniqueKeysWithValues: readings.map { (id($0.key), $0.value) }), confirmed: confirmed,
            squads: Dictionary(uniqueKeysWithValues: (squads ?? readings.mapValues { _ in .firstTeam }).map { (id($0.key), $0.value) }),
            asOf: start.adding(days: asOf), measureFrom: from.map(start.adding(days:)), parameters: p)
    }

    @Test func aRestingPlayersOwnDriftIsHisMedianRate() throws {
        let a = try #require(rates(["a": resting]).players[id("a")])
        #expect(a.drift == MeasuredRate(-2, .own(intervals: 3)))
        #expect(a.seen == SeenTrend(perWeek: -14, days: 21, starts: 0, readings: 4))
        #expect(a.gain == nil)
        #expect(a.pair == nil)
        #expect(a.usedIntervals == 3)
    }

    @Test func twoIntervalsAreNotEnoughForHisOwnRateOrHisTrend() throws {
        let a = try #require(rates(["a": Array(resting.prefix(3))]).players[id("a")])
        #expect(a.drift == nil)
        #expect(a.seen == nil)
        #expect(a.usedIntervals == 2)
    }

    @Test func aSquadsDriftNeedsFiveIntervalsOnThreeDays() {
        #expect(rates(["a": resting, "b": resting]).squadDrift[.firstTeam]
            == SharedRate(value: -2, readings: 8, since: start))
        #expect(rates(["a": resting, "b": Array(resting.prefix(2))]).squadDrift[.firstTeam] == nil)
        let short = [r(0, 100), r(7, 86), r(14, 72)]
        #expect(rates(["a": short, "b": short, "c": [r(7, 86), r(14, 72)]]).squadDrift[.firstTeam] == nil)
    }

    @Test func aStarterTakesHisSquadsDriftAndHisOwnGain() throws {
        let trends = rates(["a": resting, "b": resting, "q": starting], matches("q"))
        let q = try #require(trends.players[id("q")])
        #expect(q.drift == MeasuredRate(-2, .squad(.firstTeam)))
        #expect(q.gain == MeasuredRate(31, .own(intervals: 3)))
        #expect(q.pair != nil)
        #expect(q.seen == SeenTrend(perWeek: 17, days: 21, starts: 3, readings: 4))
        #expect(trends.clubGain == nil)
    }

    @Test func theClubsGainNeedsFiveIntervalsOnThreeDays() throws {
        let base = ["a": resting, "b": resting, "q": starting, "q2": starting]
        #expect(rates(base, matches("q", "q2")).clubGain == SharedRate(value: 31, readings: 8, since: start))

        var withY = base
        withY["y"] = [r(14, 0), r(21, 15)]
        var squads = withY.mapValues { _ in Squad.firstTeam }
        squads["y"] = .u18
        let inU18 = try #require(rates(withY, matches("q", "q2", "y"), squads: squads).players[id("y")])
        // No drift for the U18s, but the club's gain is his to take.
        #expect(inU18.drift == nil)
        #expect(inU18.gain == MeasuredRate(31, .club))
        #expect(inU18.pair == nil)

        let inFirstTeam = rates(withY, matches("q", "q2", "y"))
        let y = try #require(inFirstTeam.players[id("y")])
        #expect(y.drift == MeasuredRate(-2, .squad(.firstTeam)))
        // The median of six at 31 and his one at 29.
        #expect(y.gain == MeasuredRate(31, .club))
        #expect(inFirstTeam.clubGain?.readings == 10)
    }

    @Test func aDriftWithNoGainAndAGainWithNoDriftAreNoPair() throws {
        let resting = rates(["a": resting])
        #expect(try #require(resting.players[id("a")]).pair == nil)
        #expect(resting.pairs.isEmpty)

        let starting = rates(["q": starting], matches("q"))
        let q = try #require(starting.players[id("q")])
        #expect(q.drift == nil)
        #expect(q.gain == nil)
        #expect(q.pair == nil)
        #expect(starting.pairs.isEmpty)
    }

    @Test func anIntervalIsKeptOrLeftOutByEachRule() {
        func used(_ readings: [FitnessReading]? = nil, asOf: Int = 21, from: Int? = nil) -> Int? {
            rates(["x": readings ?? resting], asOf: asOf, from: from).players[id("x")]?.usedIntervals
        }
        #expect(used() == 3)
        // The last reading exactly 42 days back, then 43.
        #expect(used(asOf: 63) == 1)
        #expect(used(asOf: 64) == 0)
        #expect(used(from: 7) == 2)
        #expect(used(from: 8) == 1)
        #expect(used([r(0, 100), r(14, 72), r(21, 58)]) == 2)
        #expect(used([r(0, 100), r(15, 70), r(21, 58)]) == 1)
        #expect(used([r(0, 100), r(7, 86, injured: true), r(14, 72), r(21, 58)]) == 1)
        #expect(used([r(0, 100), r(7, -500), r(14, 72), r(21, 58)]) == 1)
        // The last reading is after the day asked for.
        #expect(used(asOf: 20) == 2)
    }

    @Test func aMatchOnAnImportDayCountsByWhatTheReadingIncludes() throws {
        let lineups = [lineup("m7", day: 7, "q"), lineup("m10", day: 10, "q"), lineup("m17", day: 17, "q")]
        let included = rates(
            ["a": resting, "b": resting, "q": [r(0, 100), r(7, 117, includes: ["m7"]), r(14, 134), r(21, 151)]],
            lineups)
        #expect(try #require(included.players[id("q")]).gain == MeasuredRate(31, .own(intervals: 3)))
        #expect(included.squadDrift[.firstTeam]?.readings == 8)

        let notIncluded = rates(["a": resting, "b": resting, "q": starting], lineups)
        let q = try #require(notIncluded.players[id("q")])
        #expect(notIncluded.squadDrift[.firstTeam]?.readings == 10)
        #expect(q.gain == nil)
        #expect(q.seen?.starts == 3)
    }

    @Test func aLineupConfirmedLateCountsByItsDate() throws {
        let readings = ["a": resting, "b": resting, "q": starting]
        let before = try #require(rates(readings, Array(matches("q").dropFirst())).players[id("q")])
        #expect(before.gain == nil)
        #expect(before.seen?.starts == 2)
        let after = try #require(rates(readings, matches("q")).players[id("q")])
        #expect(after.gain == MeasuredRate(31, .own(intervals: 3)))
        #expect(after.seen?.starts == 3)
    }

    @Test func aLineupChangedAfterAnUnlockCountsAsItNowStands() {
        #expect(rates(["q": starting], matches("q")).players[id("q")]?.seen?.starts == 3)
        #expect(rates(["q": starting], matches("other")).players[id("q")]?.seen?.starts == 0)
    }

    @Test func aPlayerNamedInTwoSlotsOrAFixtureConfirmedTwiceCountsOnce() {
        let twoSlots = [lineup("m3", day: 3, "q", "q"), lineup("m10", day: 10, "q", "q"),
                        lineup("m17", day: 17, "q", "q")]
        #expect(rates(["q": starting], twoSlots).players[id("q")]?.seen?.starts == 3)
        let twice = matches("q") + matches("q")
        #expect(rates(["q": starting], twice).players[id("q")]?.seen?.starts == 3)
    }

    @Test func theSameReadingsInAnotherOrderGiveTheSameRates() {
        let readings = ["a": resting, "b": resting, "q": starting, "q2": starting, "y": [r(14, 0), r(21, 15)]]
        let confirmed = matches("q", "q2", "y")
        let ordered = rates(readings, confirmed)
        var generator = SeededGenerator(seed: 21)
        let shuffledReadings = readings.mapValues { Array($0.reversed()).shuffled(using: &generator) }
        let shuffledConfirmed = Array(confirmed.reversed()).shuffled(using: &generator)
        #expect(rates(shuffledReadings, shuffledConfirmed) == ordered)
        #expect(ordered.clubGain != nil)
    }

    @Test func aPlayerInNoSquadIsLeftOutOfEverything() {
        let trends = rates(["a": resting, "b": resting, "gone": resting], squads: ["a": .firstTeam, "b": .firstTeam])
        #expect(trends.players[id("gone")] == nil)
        #expect(trends.squadDrift[.firstTeam]?.readings == 8)
    }

    @Test func readingsCountUnderTheSquadHeIsInNow() {
        // Both were read in the U18s; `a` is in the first team now.
        let trends = rates(["a": resting, "b": resting], squads: ["a": .firstTeam, "b": .u18])
        #expect(trends.squadDrift[.u18] == nil)
        #expect(trends.squadDrift[.firstTeam] == nil)
        #expect(trends.players[id("a")]?.drift?.source == .own(intervals: 3))
    }

    @Test func readingsOutOfDayOrderAreSorted() {
        #expect(rates(["a": resting.reversed()]) == rates(["a": resting]))
    }

    @Test func afterASummerNothingIsMeasured() throws {
        let trends = rates(["a": [r(0, 100), r(7, 86), r(70, -500), r(77, -500), r(84, -480)]], asOf: 84)
        let a = try #require(trends.players[id("a")])
        #expect(a.usedIntervals == 0)
        #expect(a.seen == nil)
        #expect(trends.pairs.isEmpty)
        #expect(trends.measuredFrom == start.adding(days: 70))
    }

    @Test func measuredFromIsTheOwnersDayOrTheEarliestEndOfAUsedInterval() {
        #expect(rates(["a": resting]).measuredFrom == start)
        #expect(rates(["a": resting], from: 10).measuredFrom == start.adding(days: 10))
        // Within 42 days of day 60 only the reading of day 21, but the interval it ends runs from day 14, and a squad's
        // line says "since" its earliest end.
        #expect(rates(["a": resting], asOf: 60).measuredFrom == start.adding(days: 14))
        // The same with a squad's drift: the day is never later than its "since".
        let squad = rates(["a": resting, "b": resting], asOf: 60)
        #expect(squad.measuredFrom == start.adding(days: 14))
        // With no used interval, the earliest reading in the window: see `afterASummerNothingIsMeasured`.
    }

    @Test func aReadingThatCanStillCountIsTold() throws {
        // Readings on days 0 to 21 and the owner's day after all of them: none can count.
        #expect(rates(["a": resting], asOf: 30, from: 25).players[id("a")]?.hasCountedReading == false)
        // A reading on the day itself counts.
        #expect(rates(["a": resting], asOf: 30, from: 21).players[id("a")]?.hasCountedReading == true)
        // No owner's day: any reading in the window, up to the day asked for.
        #expect(rates(["a": resting]).players[id("a")]?.hasCountedReading == true)
        #expect(rates(["a": [r(0, 100)]], asOf: 43).players[id("a")]?.hasCountedReading == false)
        #expect(rates(["a": [r(0, 100)]], asOf: 42).players[id("a")]?.hasCountedReading == true)
        #expect(rates(["a": [r(5, 100)]], asOf: 4).players[id("a")]?.hasCountedReading == false)
    }

    @Test func noReadingsGiveNone() {
        #expect(rates([:]) == .none)
        // The owner's day stands with nothing read since it.
        #expect(rates([:], from: 10)
            == FitnessTrends(players: [:], squadDrift: [:], clubGain: nil, measuredFrom: start.adding(days: 10)))
    }

    @Test func aReadingOfTheSameDayReplacesTheEarlierAndKeepsBothSetsOfFixtures() {
        let earlier = FitnessReading(day: start, jadedness: 100, condition: 0.8, sharpness: 0.7, isInjured: true,
                                     includes: [FixtureID("m2"), FixtureID("m1")])
        let later = FitnessReading(day: start, jadedness: 120, condition: 0.9, sharpness: 0.6, isInjured: false,
                                   includes: [FixtureID("m3"), FixtureID("m1"), FixtureID("m3")])
        #expect(later.includes == [FixtureID("m1"), FixtureID("m3")])
        let replaced = later.replacing(earlier)
        #expect(replaced == FitnessReading(day: start, jadedness: 120, condition: 0.9, sharpness: 0.6,
                                           isInjured: false,
                                           includes: [FixtureID("m1"), FixtureID("m2"), FixtureID("m3")]))
    }

    @Test func twoReadingsOnOneDayAreOneTheLaterInTheListWinning() {
        // The second reading on day 7 replaces the first, so the trend is the resting one.
        let readings = [r(0, 100), r(7, 300), r(7, 86), r(14, 72), r(21, 58)]
        #expect(rates(["a": readings]) == rates(["a": resting]))
    }

    @Test func aReadingIsTakenFromThePlayer() throws {
        let player = Player(
            id: id("a"), name: "A", squad: .firstTeam, age: 25, positionsText: "D (C)", currentAbility: 100,
            potentialAbility: 120, attributes: [:], familiarity: [:], condition: 0.85, sharpness: 0.7,
            jadedness: 240, isInjured: true, isBanned: false, club: nil, loanedTo: nil, contractType: .fullTime,
            monthsLeft: 12, wagePerWeek: 100, askingPrice: nil, nationalities: [], extras: [:])
        #expect(FitnessReading(day: start, player: player, includes: [FixtureID("m1")])
            == FitnessReading(day: start, jadedness: 240, condition: 0.85, sharpness: 0.7, isInjured: true,
                              includes: [FixtureID("m1")]))
    }

    @Test func aReadingIsKeptAsJSONWithItsFixturesAsRawIds() throws {
        let reading = FitnessReading(day: start, jadedness: 120, condition: 0.9, sharpness: 0.6, isInjured: false,
                                     includes: [FixtureID("m3"), FixtureID("m1")])
        let data = try JSONEncoder().encode(reading)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["includes"] as? [String] == ["m1", "m3"])
        #expect(try JSONDecoder().decode(FitnessReading.self, from: data) == reading)

        let unsorted = #"{"day":"2026-09-01","jadedness":1,"condition":0.9,"sharpness":0.9,"isInjured":false,"includes":["m2","m1","m2"]}"#
        #expect(try JSONDecoder().decode(FitnessReading.self, from: Data(unsorted.utf8)).includes
            == [FixtureID("m1"), FixtureID("m2")])
        let missing = #"{"day":"2026-09-01","jadedness":1,"condition":0.9,"sharpness":0.9,"isInjured":false}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(FitnessReading.self, from: Data(missing.utf8))
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
