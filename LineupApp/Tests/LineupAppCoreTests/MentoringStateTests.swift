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
        state.hierarchy = [
            alice: HierarchyEntry(squad: .firstTeam,
                                  dynamics: PlayerDynamics(standing: .teamLeader, socialGroup: .secondary("A"))),
            bob: HierarchyEntry(squad: .u21, dynamics: PlayerDynamics(standing: .others, socialGroup: .core))]
        state.dynamicsUpdatedOn = [.firstTeam: first, .u21: first.adding(days: 3)]
        state.groups = [MentoringGroup(id: UUID(), squad: .firstTeam, startedOn: first,
                                       members: [MentoringMember(player: alice, joinedOn: first, leftOn: first.adding(days: 2))])]
        state.names = [alice: "Alice"]
        state.record([player(alice, professionalism: 8)], on: first)
        state.setArrow(from: alice, to: bob, in: .firstTeam, strength: .significant, on: first)
        state.setArrow(from: bob, to: alice, in: .u21, strength: ArrowStrength.none, on: first.adding(days: 1))
        #expect(state.arrows.count == 2)
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(MentoringState.self, from: data) == state)
    }

    @Test func aSquadReadsOnlyTheEntriesEnteredForIt() {
        var state = MentoringState()
        let leader = PlayerDynamics(standing: .teamLeader), core = PlayerDynamics(standing: .others, socialGroup: .core)
        state.hierarchy = [alice: HierarchyEntry(squad: .firstTeam, dynamics: leader),
                           bob: HierarchyEntry(squad: .u21, dynamics: core)]
        #expect(state.dynamics(for: .firstTeam) == [alice: leader])
        #expect(state.dynamics(for: .u21) == [bob: core])
        #expect(state.dynamics(for: .u18).isEmpty)
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

    // MARK: Arrows

    private let carol = PlayerID.fmrte(3)

    private func reading(_ state: MentoringState, _ from: PlayerID, _ to: PlayerID,
                         in squad: Squad = .firstTeam) -> ArrowReading? {
        state.arrows.first { $0.from == from && $0.to == to && $0.squad == squad }
    }

    @Test func settingAnArrowReplacesThePairsReading() {
        var state = MentoringState()
        state.setArrow(from: alice, to: bob, in: .firstTeam, strength: .light, on: first)
        state.setArrow(from: alice, to: bob, in: .firstTeam, strength: .significant, on: first.adding(days: 7))
        #expect(state.arrows == [ArrowReading(from: alice, to: bob, squad: .firstTeam, strength: .significant,
                                              readOn: first.adding(days: 7))])
        // The other way round is another pair.
        state.setArrow(from: bob, to: alice, in: .firstTeam, strength: .average, on: first)
        #expect(state.arrows.count == 2)
        #expect(reading(state, alice, bob)?.strength == .significant)
        #expect(reading(state, bob, alice)?.strength == .average)
    }

    @Test func theSameStrengthKeepsItsDay() {
        var state = MentoringState()
        state.setArrow(from: alice, to: bob, in: .firstTeam, strength: .average, on: first)
        state.setArrow(from: alice, to: bob, in: .firstTeam, strength: .average, on: first.adding(days: 7))
        #expect(reading(state, alice, bob)?.readOn == first)
        #expect(state.arrows.count == 1)
        // A different strength takes the new day.
        state.setArrow(from: alice, to: bob, in: .firstTeam, strength: .light, on: first.adding(days: 7))
        #expect(reading(state, alice, bob)?.readOn == first.adding(days: 7))
    }

    @Test func notReadTakesTheReadingAway() {
        var state = MentoringState()
        state.setArrow(from: alice, to: bob, in: .firstTeam, strength: ArrowStrength.none, on: first)
        state.setArrow(from: bob, to: alice, in: .firstTeam, strength: .light, on: first)
        state.setArrow(from: alice, to: bob, in: .firstTeam, strength: nil, on: first.adding(days: 1))
        #expect(reading(state, alice, bob) == nil)
        #expect(reading(state, bob, alice)?.strength == .light)
        // Taking away a pair with no reading changes nothing.
        let before = state
        state.setArrow(from: alice, to: carol, in: .firstTeam, strength: nil, on: first)
        #expect(state == before)
    }

    @Test func readingsAreKeptInOrderWhateverOrderTheyWereSet() throws {
        let sets: [(PlayerID, PlayerID, Squad)] = [(carol, alice, .firstTeam), (alice, carol, .u21), (bob, alice, .firstTeam),
                                                   (alice, bob, .firstTeam), (alice, carol, .firstTeam), (bob, carol, .u18)]
        var forwards = MentoringState(), backwards = MentoringState()
        for (from, to, squad) in sets {
            forwards.setArrow(from: from, to: to, in: squad, strength: .light, on: first)
        }
        for (from, to, squad) in sets.reversed() {
            backwards.setArrow(from: from, to: to, in: squad, strength: .light, on: first)
        }
        #expect(forwards == backwards)
        // Encoded as the store encodes, the same bytes.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        #expect(try encoder.encode(forwards) == encoder.encode(backwards))
        // By squad in book order, then from key, then to key.
        #expect(forwards.arrows.map { [$0.squad.rawValue, $0.from.key, $0.to.key] } == [
            ["firstTeam", alice.key, bob.key], ["firstTeam", alice.key, carol.key], ["firstTeam", bob.key, alice.key],
            ["firstTeam", carol.key, alice.key], ["u21", alice.key, carol.key], ["u18", bob.key, carol.key]])
    }

    @Test func aPairHasOneReadingInEachSquad() {
        var state = MentoringState()
        state.setArrow(from: alice, to: bob, in: .firstTeam, strength: .light, on: first)
        state.setArrow(from: alice, to: bob, in: .u21, strength: .significant, on: first)
        #expect(state.arrows.count == 2)
        state.setArrow(from: alice, to: bob, in: .u21, strength: .average, on: first.adding(days: 2))
        #expect(state.arrows.count == 2)
        #expect(reading(state, alice, bob, in: .firstTeam)?.strength == .light)
        #expect(reading(state, alice, bob, in: .u21)?.strength == .average)
        state.setArrow(from: alice, to: bob, in: .u21, strength: nil, on: first)
        #expect(state.arrows.map(\.squad) == [.firstTeam])
    }
}
