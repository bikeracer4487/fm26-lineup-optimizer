import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

@Suite struct MentoringStateTests {
    private let alice = PlayerID.fmrte(1)
    private let bob = PlayerID.fmrte(2)
    private let first = Day(year: 2026, month: 11, day: 1)!

    private func player(_ id: PlayerID, professionalism: Int) -> Player {
        Player(id: id, name: "P\(id.key)", squad: .firstTeam, age: 20, positionsText: "D C", currentAbility: 100,
               potentialAbility: 120, attributes: [.professionalism: professionalism, .determination: 10],
               familiarity: [:], condition: 1, sharpness: 1, jadedness: 0, isInjured: false, isBanned: false,
               club: nil, loanedTo: nil, contractType: .fullTime, monthsLeft: 10, wagePerWeek: 1, askingPrice: nil,
               nationalities: [], extras: [:])
    }

    @Test func theStateEqualsItsOwnJSONRoundTrip() throws {
        var state = MentoringState()
        state.dynamics = [alice: PlayerDynamics(standing: .teamLeader, socialGroup: .secondary("A")),
                          bob: PlayerDynamics(standing: .others, socialGroup: .core)]
        state.dynamicsUpdatedOn = [.firstTeam: first, .u21: first.adding(days: 3)]
        state.groups = [MentoringGroup(id: UUID(), squad: .firstTeam, startedOn: first,
                                       members: [MentoringMember(player: alice, joinedOn: first, leftOn: first.adding(days: 2))])]
        state.names = [alice: "Alice"]
        state.record([player(alice, professionalism: 8)], on: first)
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(MentoringState.self, from: data) == state)
    }

    @Test func aSecondReadingOnOneDayReplacesTheFirst() {
        var state = MentoringState()
        state.record([player(alice, professionalism: 8)], on: first)
        state.record([player(alice, professionalism: 9)], on: first)
        #expect(state.readings[alice]?.count == 1)
        #expect(state.readings[alice]?.first?.values[.professionalism] == 9)
    }

    @Test func readingsStayInDayOrderWhenTheDateMovesBack() {
        var state = MentoringState()
        let thirteenth = Day(year: 2026, month: 11, day: 13)!, tenth = Day(year: 2026, month: 11, day: 10)!
        state.record([player(alice, professionalism: 8)], on: thirteenth)
        state.record([player(alice, professionalism: 9)], on: tenth)
        #expect(state.readings[alice]?.map(\.day) == [tenth, thirteenth])
    }

    @Test func theMiddleOfThreeEqualReadingsIsDropped() {
        var state = MentoringState()
        for days in [0, 7, 14] { state.record([player(alice, professionalism: 8)], on: first.adding(days: days)) }
        #expect(state.readings[alice]?.map(\.day) == [first, first.adding(days: 14)])
    }

    @Test func aChangeInTheMiddleKeepsAllThree() {
        var state = MentoringState()
        state.record([player(alice, professionalism: 8)], on: first)
        state.record([player(alice, professionalism: 9)], on: first.adding(days: 7))
        state.record([player(alice, professionalism: 8)], on: first.adding(days: 14))
        #expect(state.readings[alice]?.count == 3)
    }

    @Test func eachPlayerHasHisOwnReadings() {
        var state = MentoringState()
        state.record([player(alice, professionalism: 8), player(bob, professionalism: 12)], on: first)
        #expect(state.readings[alice]?.first?.values[.professionalism] == 8)
        #expect(state.readings[bob]?.first?.values[.professionalism] == 12)
    }
}
