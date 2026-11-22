import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

@Suite struct FitnessStateTests {
    private let alice = PlayerID.fmrte(1)
    private let bob = PlayerID.fmrte(2)
    private let day = Day(year: 2026, month: 11, day: 13)!
    private let kept = 120

    private func player(_ id: PlayerID, jadedness: Int, squad: Squad = .firstTeam, injured: Bool = false) -> Player {
        Player(id: id, name: "P\(id.key)", squad: squad, age: 24, positionsText: "D C", currentAbility: 100,
               potentialAbility: 120, attributes: [:], familiarity: [:], condition: 0.9, sharpness: 0.8,
               jadedness: jadedness, isInjured: injured, isBanned: false, club: nil, loanedTo: nil,
               contractType: .fullTime, monthsLeft: 10, wagePerWeek: 1, askingPrice: nil, nationalities: [],
               extras: [:])
    }

    @Test func aReadingIsKeptForEachPlayerWithTheFixturesGiven() throws {
        var state = FitnessState()
        state.record([player(alice, jadedness: 120), player(bob, jadedness: -40, injured: true)], on: day,
                     including: [FixtureID("b"), FixtureID("a")], keptDays: kept)
        let a = try #require(state.readings[alice])
        let b = try #require(state.readings[bob])
        #expect(a == [FitnessReading(day: day, jadedness: 120, condition: 0.9, sharpness: 0.8, isInjured: false,
                                     includes: [FixtureID("a"), FixtureID("b")])])
        #expect(b.count == 1)
        #expect(b.first?.jadedness == -40)
        #expect(b.first?.isInjured == true)
        #expect(b.first?.includes == [FixtureID("a"), FixtureID("b")])
        #expect(state.measureFrom == nil)
    }

    @Test func aSecondImportTheSameDayReplacesTheReadingAndKeepsBothSetsOfFixtures() throws {
        var state = FitnessState()
        state.record([player(alice, jadedness: 120)], on: day, including: [FixtureID("a")], keptDays: kept)
        state.record([player(alice, jadedness: 150)], on: day, including: [FixtureID("b")], keptDays: kept)
        let readings = try #require(state.readings[alice])
        #expect(readings.count == 1)
        #expect(readings.first?.jadedness == 150)
        #expect(readings.first?.includes == [FixtureID("a"), FixtureID("b")])
    }

    @Test func aReadingOnAnotherDayKeepsTheEarlierOne() throws {
        var state = FitnessState()
        state.record([player(alice, jadedness: 120)], on: day, including: [FixtureID("a")], keptDays: kept)
        state.record([player(alice, jadedness: 150)], on: day.adding(days: 1), including: [], keptDays: kept)
        let readings = try #require(state.readings[alice])
        #expect(readings.map(\.jadedness) == [120, 150])
        #expect(readings.map(\.includes) == [[FixtureID("a")], []])
    }

    @Test func readingsOlderThanTheDaysKeptAreDropped() throws {
        var state = FitnessState()
        state.record([player(alice, jadedness: 1)], on: day.adding(days: -121), including: [], keptDays: kept)
        state.record([player(alice, jadedness: 2)], on: day.adding(days: -120), including: [], keptDays: kept)
        // Bob's only reading is too old; he is not among the players recorded below.
        state.record([player(bob, jadedness: 3)], on: day.adding(days: -125), including: [], keptDays: kept)
        #expect(state.readings[bob] != nil)
        state.record([player(alice, jadedness: 4)], on: day, including: [], keptDays: kept)
        #expect(try #require(state.readings[alice]).map(\.jadedness) == [2, 4])
        #expect(state.readings[bob] == nil)
        #expect(state.readings.keys.sorted { $0.key < $1.key } == [alice])
    }

    @Test func aPlayerAmongThoseRecordedWhoseOtherReadingsAreTooOldKeepsOnlyTheNewOne() throws {
        var state = FitnessState()
        state.record([player(alice, jadedness: 1)], on: day.adding(days: -200), including: [], keptDays: kept)
        state.record([player(alice, jadedness: 4)], on: day, including: [], keptDays: kept)
        #expect(try #require(state.readings[alice]).map(\.jadedness) == [4])
    }

    @Test func aPlayerImportedInTwoSquadsOnOneDayHasOneReading() throws {
        var state = FitnessState()
        state.record([player(alice, jadedness: 100, squad: .firstTeam)], on: day, including: [FixtureID("a")],
                     keptDays: kept)
        state.record([player(alice, jadedness: 110, squad: .u21)], on: day, including: [FixtureID("b")],
                     keptDays: kept)
        let readings = try #require(state.readings[alice])
        #expect(readings.count == 1)
        #expect(readings.first?.jadedness == 110)
        #expect(readings.first?.includes == [FixtureID("a"), FixtureID("b")])

        // Twice in one paste is one reading too.
        var once = FitnessState()
        once.record([player(alice, jadedness: 100), player(alice, jadedness: 110)], on: day, including: [],
                    keptDays: kept)
        #expect(once.readings[alice]?.count == 1)
    }

    @Test func readingsStayInDayOrderWhenTheDateIsMovedBack() {
        var state = FitnessState()
        let tenth = Day(year: 2026, month: 11, day: 10)!, third = Day(year: 2026, month: 11, day: 3)!
        state.record([player(alice, jadedness: 10)], on: tenth, including: [], keptDays: kept)
        state.record([player(alice, jadedness: 3)], on: third, including: [], keptDays: kept)
        #expect(state.readings[alice]?.map(\.day) == [third, tenth])
    }

    @Test func theStateRoundTripsThroughJSON() throws {
        var state = FitnessState()
        state.record([player(alice, jadedness: 10), player(bob, jadedness: 20)], on: day,
                     including: [FixtureID("a")], keptDays: kept)
        state.measureFrom = day.adding(days: -3)
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(FitnessState.self, from: data) == state)

        var unset = FitnessState()
        unset.record([player(alice, jadedness: 10)], on: day, including: [], keptDays: kept)
        #expect(try JSONDecoder().decode(FitnessState.self, from: JSONEncoder().encode(unset)) == unset)
    }

    @Test func JSONWithNoMeasureFromDecodes() throws {
        let json = #"{"readings": {}}"#
        let state = try JSONDecoder().decode(FitnessState.self, from: Data(json.utf8))
        #expect(state == FitnessState())
        #expect(state.measureFrom == nil)
    }

    @Test func theSameReadingsRecordedInAnotherOrderWriteTheSameBytes() throws {
        func bytes(_ players: [Player]) throws -> Data {
            var state = FitnessState()
            state.record(players, on: day, including: [FixtureID("b"), FixtureID("a")], keptDays: kept)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
            return try encoder.encode(state)
        }
        let players = (1...12).map { player(.fmrte($0), jadedness: $0) }
        let forward = try bytes(players)
        #expect(forward == (try bytes(players.reversed())))
        let text = String(decoding: forward, as: UTF8.self)
        #expect(text.contains(#""fmrte:1""#))
    }
}
