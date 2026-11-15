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

    @Test func theFirstTeamsSuggestionsFromTheReadingsHaveNoHarmfulArrow() throws {
        let (players, dynamics) = try MentoringFixture.squad()
        let readings = try MentoringFixture.readings()
        let q = EngineParameters.fm27
        let report = try Mentoring.report(MentoringRequest(
            squad: .firstTeam, players: players, ownClub: "Oxford City", dynamics: dynamics, dynamicsUpdatedOn: nil,
            groups: [], readings: [:], arrows: readings, names: [:], leaving: [], asOf: MentoringFixture.readOn),
            parameters: q)
        #expect(!report.suggestions.isEmpty)
        let members = report.suggestions.flatMap { $0.members.map(\.player) }
        #expect(Set(members).count == members.count, "no player is in two groups")
        let byID = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
        let counted = Mentoring.counted(q)
        for suggestion in report.suggestions {
            // Every arrow listed is above None, read or guessed; one not listed is None and harms nobody.
            for listed in suggestion.arrows {
                let arrow = listed.arrow
                #expect(arrow.strength > .none)
                for attribute in counted {
                    let source = Mentoring.worth(attribute, byID[arrow.from]!.attributes[attribute]!, parameters: q)
                    let target = Mentoring.worth(attribute, byID[arrow.to]!.attributes[attribute]!, parameters: q)
                    #expect(source >= target, "\(listed.fromName) → \(listed.toName) in \(attribute.rawValue)")
                }
            }
            #expect(suggestion.arrows.contains { !$0.pulls.isEmpty }, "\(suggestion.id) has no arrow with a pull")
        }
    }
}
