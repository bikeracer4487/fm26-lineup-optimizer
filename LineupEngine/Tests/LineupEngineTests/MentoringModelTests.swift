import Foundation
import Testing
@testable import LineupEngine

@Suite struct MentoringModelTests {
    let q = EngineParameters.fm27

    @Test func worthStopsAtTheCeiling() {
        #expect(Mentoring.worth(.pressure, 4, parameters: q) == 8)
        #expect(Mentoring.worth(.pressure, 6, parameters: q) == 12)
        #expect(Mentoring.worth(.pressure, 14, parameters: q) == 12)
        #expect(Mentoring.worth(.professionalism, 17, parameters: q) == 51)
        #expect(Mentoring.worth(.determination, 12, parameters: q) == 10)
        #expect(Mentoring.worth(.ambition, 3, parameters: q) == 3)
        #expect(Mentoring.worth(.loyalty, 15, parameters: q) == 0)
    }

    @Test func countedAreHeaviestFirst() {
        #expect(Mentoring.counted(q) == [.professionalism, .pressure, .determination, .ambition])
        var off = q
        var weights = q.mentoringWeights.value
        weights[.ambition] = 0
        off.mentoringWeights = Parameter(weights, .derived, source: "test")
        #expect(Mentoring.counted(off) == [.professionalism, .pressure, .determination])
    }

    @Test func socialGroupCodesAsOneString() throws {
        let decoder = JSONDecoder(), encoder = JSONEncoder()
        for group in [SocialGroup.core, .others, .secondary("A")] {
            let data = try encoder.encode([group])
            #expect(try decoder.decode([SocialGroup].self, from: data) == [group])
        }
        #expect(String(decoding: try encoder.encode(["x": SocialGroup.secondary("A")]), as: UTF8.self) == "{\"x\":\"secondary:A\"}")
        #expect(throws: DecodingError.self) { try decoder.decode([SocialGroup].self, from: Data("[\"nonsense\"]".utf8)) }
    }

    @Test func standingOrder() {
        #expect(Standing.others < .influential)
        #expect(Standing.influential < .highlyInfluential)
        #expect(Standing.highlyInfluential < .teamLeader)
        #expect(PlayerDynamics().standing == .others)
        #expect(PlayerDynamics().socialGroup == nil)
    }

    @Test func aReadingTakesTheNinePersonalityValues() throws {
        let day = try #require(Day(iso: "2026-11-14"))
        let reading = PersonalityReading(day: day, player: .fixture(all: 10, attributes: [.pressure: 4]))
        #expect(reading.values.count == 9)
        #expect(reading.values[.pressure] == 4)
        var player = Player.fixture(all: 10)
        player.attributes[.loyalty] = nil
        #expect(PersonalityReading(day: day, player: player).values.count == 8)
    }

    @Test func problemsAreFound() {
        #expect(Mentoring.problems(in: q).isEmpty)
        var noCeiling = q
        var ceilings = q.mentoringCeilings.value
        ceilings[.ambition] = nil
        noCeiling.mentoringCeilings = Parameter(ceilings, .derived, source: "test")
        #expect(!Mentoring.problems(in: noCeiling).isEmpty)
        var high = q
        high.mentoringCeilings = Parameter(q.mentoringCeilings.value.mapValues { _ in 21 }, .derived, source: "test")
        #expect(!Mentoring.problems(in: high).isEmpty)
        var negative = q
        negative.mentoringWeights = Parameter(q.mentoringWeights.value.mapValues { _ in -1 }, .derived, source: "test")
        #expect(!Mentoring.problems(in: negative).isEmpty)
        var age = q
        age.mentoringMenteeMaxAge = Parameter(0, .derived, source: "test")
        #expect(Mentoring.problems(in: age).contains { $0.contains("mentoringMenteeMaxAge") })

        var noGuess = q
        var guesses = q.mentoringGuess.value
        guesses[.influential] = nil
        noGuess.mentoringGuess = Parameter(guesses, .derived, source: "test")
        #expect(Mentoring.problems(in: noGuess) == ["mentoringGuess has no strength for influential"])

        func weights(_ edit: (inout [ArrowStrength: Int]) -> Void) -> [String] {
            var changed = q
            var values = q.mentoringStrengthWeights.value
            edit(&values)
            changed.mentoringStrengthWeights = Parameter(values, .derived, source: "test")
            return Mentoring.problems(in: changed)
        }
        #expect(weights { $0[.average] = nil } == ["mentoringStrengthWeights has no weight for average"])
        #expect(weights { $0[.none] = 1 } == ["mentoringStrengthWeights gives none a weight of 1, which is not 0"])
        #expect(weights { $0[.light] = -1 }.contains("mentoringStrengthWeights gives light a weight of -1, which is below 0"))
        #expect(weights { $0[.significant] = 1 }
                == ["mentoringStrengthWeights gives significant (1) less than average (2), a weaker arrow"])
        #expect(weights { $0[.significant] = 2 }.isEmpty)

        var takes = q
        takes.mentoringTakesNothingAfter = Parameter(0, .derived, source: "test")
        #expect(Mentoring.problems(in: takes) == ["mentoringTakesNothingAfter is 0, which is not above 0"])
    }

    @Test func groupsHaveLiveAndCurrentMembers() throws {
        let day = try #require(Day(iso: "2026-11-14"))
        let a = MentoringMember(player: PlayerID(key: "b"), joinedOn: day, leftOn: nil)
        let b = MentoringMember(player: PlayerID(key: "a"), joinedOn: day, leftOn: nil)
        let c = MentoringMember(player: PlayerID(key: "c"), joinedOn: day, leftOn: day)
        var group = MentoringGroup(id: UUID(), squad: .firstTeam, startedOn: day, endedOn: nil, members: [a, c, b])
        #expect(group.isLive)
        #expect(group.current.map(\.player.key) == ["a", "b"])
        group.endedOn = day
        #expect(!group.isLive)
    }
}
