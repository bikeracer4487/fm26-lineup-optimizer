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

    @Test func aHigherStandingStandsAboveWhateverTheAge() {
        #expect(Mentoring.standsAbove((standing: .influential, age: 18), (standing: .others, age: 35), parameters: q))
    }

    @Test func theSameStandingNeedsFiveYears() {
        #expect(Mentoring.standsAbove((standing: .influential, age: 30), (standing: .influential, age: 25), parameters: q))
        #expect(!Mentoring.standsAbove((standing: .influential, age: 29), (standing: .influential, age: 25), parameters: q))
    }

    @Test func aLowerStandingNeverStandsAbove() {
        #expect(!Mentoring.standsAbove((standing: .others, age: 35), (standing: .influential, age: 18), parameters: q))
    }

    @Test func socialGroups() {
        #expect(Mentoring.sameSocialGroup(.core, .core) == true)
        #expect(Mentoring.sameSocialGroup(.secondary("A"), .secondary("A")) == true)
        #expect(Mentoring.sameSocialGroup(.secondary("A"), .secondary("B")) == false)
        #expect(Mentoring.sameSocialGroup(.core, .secondary("A")) == false)
        #expect(Mentoring.sameSocialGroup(.others, .others) == false)
        #expect(Mentoring.sameSocialGroup(nil, .core) == nil)
        #expect(Mentoring.sameSocialGroup(.core, nil) == nil)
        #expect(Mentoring.sameSocialGroup(nil, nil) == nil)
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
        var share = q
        share.mentoringOtherSocialGroupShare = Parameter(1.5, .derived, source: "test")
        #expect(Mentoring.problems(in: share).contains { $0.contains("mentoringOtherSocialGroupShare") })
        var negative = q
        negative.mentoringWeights = Parameter(q.mentoringWeights.value.mapValues { _ in -1 }, .derived, source: "test")
        #expect(!Mentoring.problems(in: negative).isEmpty)
        var age = q
        age.mentoringMenteeMaxAge = Parameter(0, .derived, source: "test")
        #expect(Mentoring.problems(in: age).contains { $0.contains("mentoringMenteeMaxAge") })
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
