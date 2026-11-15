import Foundation
import Testing
@testable import LineupEngine

@Suite struct MentoringFixtureTests {
    @Test func theReadingsAreTwentyFourGroupsOfThree() throws {
        let groups = try MentoringFixture.groups()
        #expect(groups.count == 24)
        for group in groups {
            #expect(group.members.count == 3)
            #expect(Set(group.members).count == 3)
            for arrow in group.arrows {
                #expect(group.members.contains(arrow.from) && group.members.contains(arrow.to) && arrow.from != arrow.to)
            }
        }
        #expect(groups.map(\.arrows.count).reduce(0, +) == 30)
    }

    @Test func noPairWasReadTwoWays() throws {
        var strengths: [String: Set<ArrowStrength>] = [:]
        for group in try MentoringFixture.groups() {
            for from in group.members {
                for to in group.members where to != from {
                    let strength = group.arrows.first { $0.from == from && $0.to == to }?.strength ?? .none
                    strengths["\(from)>\(to)", default: []].insert(strength)
                }
            }
        }
        #expect(strengths.values.allSatisfy { $0.count == 1 })
        let pairs = try MentoringFixture.pairs()
        #expect(pairs.count == 124)
        #expect(pairs.filter { $0.strength > .none }.count == 27)
    }

    @Test func everyoneInTheReadingsIsInTheSquad() throws {
        let names = Set(try MentoringFixture.squad().players.map(\.name))
        #expect(names.count == 20)
        for group in try MentoringFixture.groups() {
            for member in group.members { #expect(names.contains(member), "\(member) is not in the squad") }
        }
    }

    @Test func theGuessAgainstEveryReading() throws {
        let (players, dynamics) = try MentoringFixture.squad()
        let byName = Dictionary(uniqueKeysWithValues: players.map { ($0.name, $0) })
        let q = EngineParameters.fm27
        func party(_ name: String) -> Mentoring.Party {
            let player = byName[name]!
            return Mentoring.Party(id: player.id, standing: dynamics[player.id]!.standing, age: player.age)
        }
        var exact = 0, sameSideOfNone = 0
        let pairs = try MentoringFixture.pairs()
        for pair in pairs {
            let guess = Mentoring.guess(from: party(pair.from), to: party(pair.to), toTakesNothing: false, parameters: q)
            if guess == pair.strength { exact += 1 }
            if (guess > .none) == (pair.strength > .none) { sameSideOfNone += 1 }
        }
        #expect(pairs.count == 124)
        #expect(exact == 104)
        #expect(sameSideOfNone == 111)
    }
}
