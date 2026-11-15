import Foundation
import Testing
@testable import LineupEngine

@Suite struct MentoringArrowsTests {
    let q = EngineParameters.fm27
    let day = Day(iso: "2026-11-14")!

    func party(_ name: String, _ standing: Standing, _ age: Int) -> Mentoring.Party {
        Mentoring.Party(id: PlayerID(key: name), standing: standing, age: age)
    }

    func reading(_ from: String, _ to: String, _ strength: ArrowStrength, squad: Squad = .firstTeam) -> ArrowReading {
        ArrowReading(from: PlayerID(key: from), to: PlayerID(key: to), squad: squad, strength: strength, readOn: day)
    }

    @Test func theGuessCellByCell() {
        func guess(_ from: Standing, _ fromAge: Int, _ toAge: Int) -> ArrowStrength {
            Mentoring.guess(from: party("a", from, fromAge), to: party("b", .others, toAge), toTakesNothing: false, parameters: q)
        }
        #expect(guess(.teamLeader, 33, 23) == .average)
        #expect(guess(.teamLeader, 33, 24) == .none)
        #expect(guess(.highlyInfluential, 30, 23) == .light)
        #expect(guess(.highlyInfluential, 30, 24) == .none)
        #expect(guess(.influential, 30, 23) == .light)
        #expect(guess(.influential, 30, 24) == .none)
        #expect(guess(.others, 30, 18) == .none)
    }

    @Test func noGuessIntoAPlayerAtTheSameLevelOrAbove() {
        func guess(_ from: Standing, _ to: Standing) -> ArrowStrength {
            Mentoring.guess(from: party("a", from, 30), to: party("b", to, 20), toTakesNothing: false, parameters: q)
        }
        #expect(guess(.influential, .influential) == .none)
        #expect(guess(.influential, .teamLeader) == .none)
        #expect(guess(.teamLeader, .teamLeader) == .none)
        #expect(guess(.highlyInfluential, .influential) == .light)
    }

    @Test func aPlayerWhoTakesNothingIsGuessedNone() {
        let from = party("a", .teamLeader, 33), to = party("b", .others, 20)
        #expect(Mentoring.guess(from: from, to: to, toTakesNothing: true, parameters: q) == .none)
        #expect(Mentoring.guess(from: from, to: to, toTakesNothing: false, parameters: q) == .average)
    }

    @Test func takingNothingNeedsThreeSeniorsAndNoArrow() {
        let standings: [PlayerID: Standing] = [
            PlayerID(key: "i"): .influential, PlayerID(key: "h"): .highlyInfluential,
            PlayerID(key: "t"): .teamLeader, PlayerID(key: "o"): .others]
        let target = PlayerID(key: "x")
        func takes(_ readings: [ArrowReading], _ standings: [PlayerID: Standing]) -> Bool {
            Mentoring.takesNothing(target, in: .firstTeam, readings: readings, standings: standings, parameters: q)
        }
        let three = [reading("i", "x", .none), reading("h", "x", .none), reading("t", "x", .none)]
        #expect(takes(three, standings))
        #expect(!takes(Array(three.prefix(2)), standings))
        #expect(!takes([reading("i", "x", .none), reading("h", "x", .none), reading("o", "x", .none)], standings))
        #expect(!takes(three + [reading("o", "x", .light)], standings))
        #expect(!takes(three.map { reading($0.from.key, "x", .none, squad: .u21) }, standings))
        var changed = standings
        changed[PlayerID(key: "t")] = .others
        #expect(!takes(three, changed))
        // The same source read twice is one source.
        #expect(!takes([reading("i", "x", .none), reading("i", "x", .none), reading("h", "x", .none)], standings))
        // A player with no entry is at Others.
        #expect(!takes(three, [PlayerID(key: "i"): .influential, PlayerID(key: "h"): .highlyInfluential]))
    }

    @Test func aReadingStandsInForTheGuess() {
        let from = party("a", .teamLeader, 33), to = party("b", .others, 20)
        func arrow(_ readings: [ArrowReading]) -> Arrow {
            Mentoring.arrow(from: from, to: to, in: .firstTeam, readings: readings, standings: [:], parameters: q)
        }
        let read = arrow([reading("a", "b", .significant)])
        #expect(read.strength == .significant)
        #expect(read.readOn == day)
        #expect(read.isRead)
        let guessed = arrow([])
        #expect(guessed.strength == .average)
        #expect(guessed.readOn == nil)
        #expect(!guessed.isRead)
        #expect(arrow([reading("a", "b", .significant, squad: .u21)]).readOn == nil)
        let none = arrow([reading("a", "b", .none)])
        #expect(none.strength == .none)
        #expect(none.isRead)
    }

    @Test func theGuessUsesWhatTakesNothingSaysOfTheTarget() {
        let from = party("a", .teamLeader, 33), to = party("x", .others, 20)
        let standings: [PlayerID: Standing] = [
            PlayerID(key: "i"): .influential, PlayerID(key: "h"): .highlyInfluential, PlayerID(key: "t"): .teamLeader]
        let nones = [reading("i", "x", .none), reading("h", "x", .none), reading("t", "x", .none)]
        let arrow = Mentoring.arrow(from: from, to: to, in: .firstTeam, readings: nones, standings: standings, parameters: q)
        #expect(arrow.strength == .none)
        #expect(!arrow.isRead)
    }

    @Test func strengthsAreOrderedAndStoredByTheirWords() throws {
        #expect(ArrowStrength.allCases == [.none, .light, .average, .significant])
        #expect(ArrowStrength.light < ArrowStrength.average)
        #expect(!(ArrowStrength.significant < ArrowStrength.none))
        let json = try JSONEncoder().encode([ArrowStrength.none, .significant])
        #expect(String(decoding: json, as: UTF8.self) == "[\"none\",\"significant\"]")
        let r = reading("a", "b", .light)
        let back = try JSONDecoder().decode(ArrowReading.self, from: JSONEncoder().encode(r))
        #expect(back == r)
    }
}
