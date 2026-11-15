import Foundation
import Testing
@testable import LineupEngine

@Suite struct MentoringReviewTests {
    let q = EngineParameters.fm27
    /// Day 0 of every group here.
    let start = Day(year: 2026, month: 8, day: 1)!

    // MARK: Helpers

    func day(_ n: Int) -> Day { start.adding(days: n) }

    func id(_ name: String) -> PlayerID { PlayerID(key: PlayerID.normalise(name)) }

    /// A player of Oxford City with every attribute 10 unless `values` says otherwise.
    func player(_ name: String, _ age: Int, _ values: [Attribute: Int] = [:], squad: Squad = .firstTeam,
                club: String? = "Oxford City", loanedTo: String? = nil) -> Player {
        .fixture(name: name, squad: squad, age: age, attributes: values, club: club, loanedTo: loanedTo)
    }

    /// The counted attributes at 10 unless `values` says otherwise.
    func reading(_ n: Int, _ values: [Attribute: Int] = [:]) -> PersonalityReading {
        PersonalityReading(day: day(n), values: [.professionalism: 10, .pressure: 10, .determination: 10, .ambition: 10]
            .merging(values) { _, new in new })
    }

    /// A group of the named players, each joining on day 0 unless `joined` says otherwise.
    func group(_ names: [String], id groupID: UUID = UUID(), squad: Squad = .firstTeam, startedOn: Int = 0,
               endedOn: Day? = nil, joined: [String: Int] = [:], left: [String: Int] = [:]) -> MentoringGroup {
        MentoringGroup(id: groupID, squad: squad, startedOn: day(startedOn), endedOn: endedOn, members: names.map {
            MentoringMember(player: id($0), joinedOn: day(joined[$0] ?? startedOn), leftOn: left[$0].map(day))
        })
    }

    func request(_ players: [Player], groups: [MentoringGroup] = [], dynamics: [PlayerID: PlayerDynamics] = [:],
                 readings: [String: [PersonalityReading]] = [:], names: [PlayerID: String] = [:],
                 leaving: Set<PlayerID> = [], asOf: Int = 100) -> MentoringRequest {
        MentoringRequest(squad: .firstTeam, players: players, ownClub: "Oxford City", dynamics: dynamics,
                         dynamicsUpdatedOn: nil, groups: groups,
                         readings: Dictionary(uniqueKeysWithValues: readings.map { (id($0.key), $0.value) }),
                         arrows: [], names: names, leaving: leaving, asOf: day(asOf))
    }

    func review(_ group: MentoringGroup, _ players: [Player], dynamics: [PlayerID: PlayerDynamics] = [:],
                readings: [String: [PersonalityReading]] = [:], names: [PlayerID: String] = [:],
                leaving: Set<PlayerID> = [], asOf: Int = 100) -> GroupReview {
        Mentoring.review(group, request: request(players, groups: [group], dynamics: dynamics, readings: readings,
                                                 names: names, leaving: leaving, asOf: asOf),
                         parameters: q)
    }

    func member(_ review: GroupReview, _ name: String) throws -> MemberReview {
        try #require(review.members.first { $0.player == id(name) })
    }

    func change(_ member: MemberReview, _ attribute: Attribute) throws -> AttributeChange {
        try #require(member.changes.first { $0.attribute == attribute })
    }

    /// Three players: a lead aged 34 and two aged 18.
    var trio: [Player] { [player("Lead", 34), player("Abel", 18), player("Brook", 18)] }

    // MARK: Who leads

    @Test func theLeadStandsAboveEveryOtherMember() throws {
        let result = review(group(["Brook", "Lead", "Abel"]), trio)
        #expect(result.lead == id("Lead"))
        #expect(result.members.map(\.player) == [id("Lead"), id("Abel"), id("Brook")])
        #expect(result.members.map(\.isLead) == [true, false, false])
        #expect(result.members.map(\.name) == ["Lead", "Abel", "Brook"])
        #expect(result.members.map(\.age) == [34, 18, 18])
        #expect(result.warnings.isEmpty)
        #expect(result.basis == .derived)
        #expect(result.group.id == result.id)

        // A higher standing leads whatever the age.
        let captain = review(group(["Lead", "Abel", "Captain"]), trio + [player("Captain", 19)],
                             dynamics: [id("Captain"): PlayerDynamics(standing: .teamLeader)])
        #expect(captain.lead == id("Captain"))
        #expect(captain.members.map(\.player) == [id("Captain"), id("Abel"), id("Lead")])
    }

    @Test func nobodyLeadsWhenTwoAreLevel() throws {
        let result = review(group(["Lead", "Second", "Abel"]), [player("Lead", 34), player("Second", 33), player("Abel", 18)])
        #expect(result.lead == nil)
        #expect(result.warnings == [.nobodyLeads])
        #expect(result.members.map(\.player) == [id("Abel"), id("Lead"), id("Second")])
        #expect(result.members.allSatisfy { !$0.isLead && $0.pulls.isEmpty })
    }

    // MARK: Pulls and warnings

    @Test func pullsShowBothDirections() throws {
        let players = [player("Lead", 34, [.professionalism: 6, .pressure: 14]),
                       player("Abel", 18, [.professionalism: 12, .pressure: 12]),
                       player("Brook", 18, [.professionalism: 4])]
        let result = review(group(["Lead", "Abel", "Brook"]), players)
        #expect(try member(result, "Abel").pulls == [Pull(attribute: .professionalism, value: 12, towards: 6)])
        // Brook's Pressure 10 against 14 is past the ceiling on both sides: no pull.
        #expect(try member(result, "Brook").pulls == [Pull(attribute: .professionalism, value: 4, towards: 6)])
        #expect(try member(result, "Lead").pulls == [])
        #expect(result.warnings == [.mayBeDraggedDown(above: id("Lead"), below: id("Abel"), attribute: .professionalism,
                                                      aboveValue: 6, belowValue: 12)])

        // Between two members as well as from the lead: at 23 Elder stands above Young and has less Ambition.
        let between = review(group(["Lead", "Elder", "Young"]),
                             [player("Lead", 34), player("Elder", 23, [.ambition: 6]), player("Young", 18, [.ambition: 9])])
        #expect(between.warnings == [.mayBeDraggedDown(above: id("Elder"), below: id("Young"), attribute: .ambition,
                                                       aboveValue: 6, belowValue: 9)])
        let fourYears = review(group(["Lead", "Elder", "Young"]),
                               [player("Lead", 34), player("Elder", 22, [.ambition: 6]), player("Young", 18, [.ambition: 9])])
        #expect(fourYears.warnings.isEmpty)
    }

    @Test func aDifferentSocialGroupIsACaution() throws {
        let apart = review(group(["Lead", "Abel", "Brook"]), trio,
                           dynamics: [id("Lead"): PlayerDynamics(socialGroup: .core),
                                      id("Abel"): PlayerDynamics(socialGroup: .secondary("A")),
                                      id("Brook"): PlayerDynamics(socialGroup: .core)])
        #expect(apart.warnings == [.differentSocialGroup(id("Abel"))])

        let leadNotEntered = review(group(["Lead", "Abel", "Brook"]), trio,
                                    dynamics: [id("Abel"): PlayerDynamics(socialGroup: .secondary("A"))])
        #expect(leadNotEntered.warnings.isEmpty)
        let memberNotEntered = review(group(["Lead", "Abel", "Brook"]), trio,
                                      dynamics: [id("Lead"): PlayerDynamics(socialGroup: .core)])
        #expect(memberNotEntered.warnings.isEmpty)
    }

    // MARK: What changed

    @Test func startingValuesAreTheLastReadingOnOrBeforeJoining() throws {
        let onTheDay = review(group(["Lead", "Abel", "Brook"], joined: ["Abel": 28]), trio, readings: [
            "Abel": [reading(63, [.professionalism: 10]), reading(0, [.professionalism: 7]),
                     reading(28, [.professionalism: 8])]])
        let abel = try change(try member(onTheDay, "Abel"), .professionalism)
        #expect(abel == AttributeChange(attribute: .professionalism, start: 8, latest: 10, weeks: 5.0, change: .improved))

        // A reading before he joined gives his values, but the weeks run from the day he joined.
        let before = review(group(["Lead", "Abel", "Brook"], joined: ["Abel": 30]), trio, readings: [
            "Abel": [reading(0, [.professionalism: 7]), reading(21, [.professionalism: 8]),
                     reading(65, [.professionalism: 10])]])
        #expect(try change(try member(before, "Abel"), .professionalism)
                == AttributeChange(attribute: .professionalism, start: 8, latest: 10, weeks: 5.0, change: .improved))
    }

    @Test func orTheFirstAfterWhenThereIsNoneBefore() throws {
        let result = review(group(["Lead", "Abel", "Brook"]), trio, readings: [
            "Abel": [reading(42, [.professionalism: 10]), reading(7, [.professionalism: 8])]])
        #expect(try change(try member(result, "Abel"), .professionalism)
                == AttributeChange(attribute: .professionalism, start: 8, latest: 10, weeks: 5.0, change: .improved))
    }

    @Test func aMemberAddedLaterIsMeasuredFromThatDay() throws {
        let readings = [reading(0, [.professionalism: 5]), reading(49, [.professionalism: 7]),
                        reading(84, [.professionalism: 9])]
        let result = review(group(["Lead", "Abel", "Brook"], joined: ["Brook": 49]), trio,
                            readings: ["Abel": readings, "Brook": readings])
        #expect(try change(try member(result, "Brook"), .professionalism)
                == AttributeChange(attribute: .professionalism, start: 7, latest: 9, weeks: 5.0, change: .improved))
        #expect(try change(try member(result, "Abel"), .professionalism)
                == AttributeChange(attribute: .professionalism, start: 5, latest: 9, weeks: 12.0, change: .improved))
    }

    @Test func changeIsJudgedByWorth() throws {
        let result = review(group(["Lead", "Abel", "Brook"]), trio, readings: [
            "Abel": [reading(0, [.professionalism: 9, .pressure: 14, .ambition: 9]),
                     reading(35, [.professionalism: 10, .pressure: 13, .ambition: 8])]])
        let abel = try member(result, "Abel")
        #expect(abel.changes.map(\.attribute) == Mentoring.counted(q))
        #expect(try change(abel, .professionalism)
                == AttributeChange(attribute: .professionalism, start: 9, latest: 10, weeks: 5.0, change: .improved))
        #expect(try change(abel, .pressure)
                == AttributeChange(attribute: .pressure, start: 14, latest: 13, weeks: 5.0, change: .noChange))
        #expect(try change(abel, .determination)
                == AttributeChange(attribute: .determination, start: 10, latest: 10, weeks: 5.0, change: .noChange))
        #expect(try change(abel, .ambition)
                == AttributeChange(attribute: .ambition, start: 9, latest: 8, weeks: 5.0, change: .worse))
    }

    @Test func oneReadingIsNoReadingYet() throws {
        let result = review(group(["Lead", "Abel", "Brook"], joined: ["Brook": 10]), trio, readings: [
            "Abel": [reading(0, [.professionalism: 8])],
            // Both readings are from before he joined: the later is both his start and his latest.
            "Brook": [reading(0, [.professionalism: 7]), reading(5, [.professionalism: 8])]])
        #expect(try change(try member(result, "Abel"), .professionalism)
                == AttributeChange(attribute: .professionalism, start: 8, latest: 8, weeks: 0, change: .noReading))
        #expect(try change(try member(result, "Brook"), .professionalism)
                == AttributeChange(attribute: .professionalism, start: 8, latest: 8, weeks: 0, change: .noReading))
        let lead = try member(result, "Lead")
        #expect(lead.changes.count == Mentoring.counted(q).count)
        #expect(lead.changes.allSatisfy { $0.start == nil && $0.latest == nil && $0.weeks == 0 && $0.change == .noReading })
        #expect(!result.isDoingHarm)
        #expect(!result.hasStoppedWorking)
    }

    @Test func doingHarmWhenAnyMemberIsWorthLess() throws {
        func harm(_ name: String, _ from: [Attribute: Int], _ to: [Attribute: Int]) -> Bool {
            review(group(["Lead", "Abel", "Brook"]), trio, readings: [name: [reading(0, from), reading(35, to)]])
                .isDoingHarm
        }
        #expect(harm("Abel", [.ambition: 9], [.ambition: 8]))
        #expect(harm("Lead", [.ambition: 10], [.ambition: 9]))
        #expect(!harm("Abel", [.pressure: 14], [.pressure: 13]))
        #expect(!harm("Abel", [.professionalism: 9], [.professionalism: 10]))
        #expect(!harm("Abel", [:], [:]))
    }

    // MARK: Stopped working

    @Test func stoppedAfterThirteenWeeksWithNoChange() throws {
        func stopped(_ readings: [String: [PersonalityReading]], joined: [String: Int] = [:],
                     players: [Player]? = nil) -> Bool {
            let names = (players ?? trio).map(\.name)
            return review(group(names, joined: joined), players ?? trio, readings: readings, asOf: 300).hasStoppedWorking
        }
        let same91 = ["Abel": [reading(0), reading(91)], "Brook": [reading(0), reading(91)]]
        #expect(stopped(same91))
        #expect(!stopped(["Abel": [reading(0), reading(90)], "Brook": [reading(0), reading(90)]]))

        let changedOn28 = ["Abel": [reading(0), reading(28, [.professionalism: 11]), reading(100, [.professionalism: 11])],
                           "Brook": [reading(0), reading(100)]]
        #expect(!stopped(changedOn28))
        let changedOn9 = ["Abel": [reading(0), reading(9, [.professionalism: 11]), reading(100, [.professionalism: 11])],
                          "Brook": [reading(0), reading(100)]]
        #expect(stopped(changedOn9))
        // A move above the ceiling is no change.
        let pastTheCeiling = ["Abel": [reading(0, [.pressure: 14]), reading(28, [.pressure: 13]), reading(100, [.pressure: 13])],
                              "Brook": [reading(0), reading(100)]]
        #expect(stopped(pastTheCeiling))

        // A member added on day 50 restarts the clock.
        #expect(!stopped(same91, joined: ["Brook": 50]))
        #expect(stopped(["Abel": [reading(0), reading(141)], "Brook": [reading(0), reading(141)]], joined: ["Brook": 50]))
        // So does a group started later than its readings.
        #expect(!review(group(["Lead", "Abel", "Brook"], startedOn: 10), trio, readings: same91).hasStoppedWorking)

        // The lead's own change does not restart it.
        let leadChanged = same91.merging(["Lead": [reading(0), reading(50, [.professionalism: 11]),
                                                   reading(91, [.professionalism: 11])]]) { _, new in new }
        #expect(stopped(leadChanged))

        // With nobody leading, any member's change does.
        let level = [player("Lead", 34), player("Second", 33), player("Abel", 18)]
        let levelSame = ["Lead": [reading(0), reading(91)], "Second": [reading(0), reading(91)],
                         "Abel": [reading(0), reading(91)]]
        #expect(stopped(levelSame, players: level))
        let leadOfLevelChanged = levelSame.merging(["Lead": [reading(0), reading(50, [.professionalism: 11]),
                                                             reading(91, [.professionalism: 11])]]) { _, new in new }
        #expect(!stopped(leadOfLevelChanged, players: level))
    }

    @Test func aGroupDoingHarmIsNotAlsoStopped() throws {
        let readings = ["Abel": [reading(0), reading(7, [.ambition: 9]), reading(100, [.ambition: 9])],
                        "Brook": [reading(0), reading(100)]]
        let result = review(group(["Lead", "Abel", "Brook"]), trio, readings: readings)
        #expect(result.isDoingHarm)
        #expect(!result.hasStoppedWorking)

        let improving = ["Abel": [reading(0), reading(7, [.ambition: 11]), reading(100, [.ambition: 11])],
                         "Brook": [reading(0), reading(100)]]
        #expect(!review(group(["Lead", "Abel", "Brook"]), trio, readings: improving).isDoingHarm)
        // Ambition 10 to 11 stays at the ceiling: no change since day 0.
        #expect(review(group(["Lead", "Abel", "Brook"]), trio, readings: improving).hasStoppedWorking)
    }

    @Test func aGapBetweenImportsIsNotNoChange() throws {
        let gap = review(group(["Lead", "Abel", "Brook"]), trio,
                         readings: ["Abel": [reading(0)], "Brook": [reading(0)]], asOf: 200)
        #expect(!gap.hasStoppedWorking)
        let read = review(group(["Lead", "Abel", "Brook"]), trio,
                          readings: ["Abel": [reading(0), reading(200)], "Brook": [reading(0), reading(200)]], asOf: 200)
        #expect(read.hasStoppedWorking)
    }

    // MARK: Members who have gone

    @Test func aMemberWhoHasLeftIsAWarningNotAnError() throws {
        let gone = ["Gone": [reading(0, [.professionalism: 8]), reading(35, [.professionalism: 9])]]
        let names = [id("Gone"): "Gone Away"]
        let stayers = [player("Lead", 34), player("Abel", 18, [.professionalism: 8])]

        let absent = review(group(["Lead", "Abel", "Gone"]), stayers, readings: gone, names: names)
        #expect(absent.warnings == [.notInSquad(id("Gone"))])
        let left = try member(absent, "Gone")
        #expect(left.name == "Gone Away")
        #expect(left.age == nil)
        #expect(left.pulls.isEmpty)
        #expect(!left.isLead)
        #expect(try change(left, .professionalism)
                == AttributeChange(attribute: .professionalism, start: 8, latest: 9, weeks: 5.0, change: .improved))
        #expect(absent.lead == id("Lead"))
        #expect(try member(absent, "Abel").pulls == [Pull(attribute: .professionalism, value: 8, towards: 10)])

        // Through the report too: a member with no attributes at all is no error.
        let report = try Mentoring.report(request(stayers, groups: [group(["Lead", "Abel", "Gone"])], readings: gone,
                                                  names: names), parameters: q)
        #expect(report.groups.first?.warnings == [.notInSquad(id("Gone"))])

        let moved = review(group(["Lead", "Abel", "Gone"]), stayers + [player("Gone", 19, squad: .u21)],
                           readings: gone, names: names)
        #expect(moved.warnings == [.notInSquad(id("Gone"))])
        #expect(try member(moved, "Gone").age == 19)
        #expect(try member(moved, "Gone").name == "Gone")
        #expect(try member(moved, "Gone").pulls.isEmpty)

        // Away on loan he is not read: his Professionalism 15 against the lead's 10 is no dragged-down warning.
        let onLoan = review(group(["Lead", "Abel", "Gone"]),
                            stayers + [player("Gone", 19, [.professionalism: 15], loanedTo: "Banbury United")])
        #expect(onLoan.warnings == [.outOnLoan(id("Gone"), club: "Banbury United")])
        let backFromLoan = review(group(["Lead", "Abel", "Gone"]), stayers + [player("Gone", 19, [.professionalism: 15])])
        #expect(backFromLoan.warnings == [.mayBeDraggedDown(above: id("Lead"), below: id("Gone"),
                                                            attribute: .professionalism, aboveValue: 10, belowValue: 15)])
        #expect(try member(onLoan, "Gone").pulls.isEmpty)

        let leaving = review(group(["Lead", "Abel", "Gone"]), stayers + [player("Gone", 19)], leaving: [id("Gone")])
        #expect(leaving.warnings == [.advisedToLeave(id("Gone"))])
        // Still in the squad, so still read: he is pulled towards the lead's Professionalism.
        let leavingWithGap = review(group(["Lead", "Abel", "Gone"]),
                                    stayers + [player("Gone", 19, [.professionalism: 7])], leaving: [id("Gone")])
        #expect(try member(leavingWithGap, "Gone").pulls == [Pull(attribute: .professionalism, value: 7, towards: 10)])

        // When the lead goes, the other two are level: nobody leads.
        let leadGone = review(group(["Lead", "Abel", "Brook"]), [player("Abel", 18), player("Brook", 18)],
                              names: [id("Lead"): "Lead"])
        #expect(leadGone.lead == nil)
        #expect(leadGone.warnings == [.nobodyLeads, .notInSquad(id("Lead"))])
        #expect(try member(leadGone, "Lead").name == "Lead")
    }

    @Test func aMemberWithAMissingValueHasNoPulls() throws {
        var noPressure = player("Abel", 18, [.professionalism: 8])
        noPressure.attributes[.pressure] = nil
        let result = review(group(["Lead", "Abel", "Brook"]), [player("Lead", 34), noPressure, player("Brook", 18)])
        #expect(try member(result, "Abel").pulls.isEmpty)
        #expect(try member(result, "Brook").pulls.isEmpty)
        #expect(result.lead == id("Lead"))
    }

    @Test func everyWarningInOrder() throws {
        let players = [player("Lead", 34, [.ambition: 6]), player("Abel", 18, [.ambition: 9]),
                       player("Brook", 18, [.ambition: 9]), player("Cole", 19, loanedTo: "Banbury United")]
        let result = review(group(["Lead", "Abel", "Brook", "Cole", "Dunn"]), players,
                            dynamics: [id("Lead"): PlayerDynamics(socialGroup: .core),
                                       id("Abel"): PlayerDynamics(socialGroup: .others),
                                       id("Brook"): PlayerDynamics(socialGroup: .secondary("B"))],
                            leaving: [id("Brook"), id("Abel")])
        #expect(result.warnings == [
            .mayBeDraggedDown(above: id("Lead"), below: id("Abel"), attribute: .ambition, aboveValue: 6, belowValue: 9),
            .mayBeDraggedDown(above: id("Lead"), below: id("Brook"), attribute: .ambition, aboveValue: 6, belowValue: 9),
            .differentSocialGroup(id("Abel")), .differentSocialGroup(id("Brook")),
            .notInSquad(id("Dunn")), .outOnLoan(id("Cole"), club: "Banbury United"),
            .advisedToLeave(id("Abel")), .advisedToLeave(id("Brook"))])
    }

    // MARK: Which groups and members

    @Test func endedGroupsAndOtherSquadsGroupsAreNotReviewed() throws {
        let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let second = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let third = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let groups = [group(["Lead", "Abel", "Brook"], id: third, startedOn: 5),
                      group(["Lead", "Abel", "Brook"], id: second, startedOn: 10),
                      group(["Lead", "Abel", "Brook"], id: first, startedOn: 10),
                      group(["Lead", "Abel", "Brook"], endedOn: day(20)),
                      group(["Lead", "Abel", "Brook"], squad: .u21)]
        let report = try Mentoring.report(request(trio, groups: groups), parameters: q)
        #expect(report.groups.map(\.id) == [third, first, second])
        #expect(try Mentoring.report(request(trio, groups: groups.reversed()), parameters: q).groups.map(\.id)
                == [third, first, second])
        #expect(try Mentoring.report(request(trio), parameters: q).groups.isEmpty)
    }

    @Test func aMemberTakenOutIsNotRead() throws {
        let readings = ["Gone": [reading(0, [.ambition: 9]), reading(35, [.ambition: 8])]]
        let result = review(group(["Lead", "Abel", "Gone", "Brook"], joined: ["Brook": 40], left: ["Gone": 40]), trio,
                            readings: readings)
        #expect(result.members.map(\.player) == [id("Lead"), id("Abel"), id("Brook")])
        #expect(result.warnings.isEmpty)
        #expect(!result.isDoingHarm)
    }

    @Test func inputOrderDoesNotMatter() throws {
        let players = [player("Lead", 34, [.ambition: 6]), player("Elder", 23, [.ambition: 9, .pressure: 4]),
                       player("Young", 18, [.ambition: 9, .pressure: 5]), player("Other", 20, squad: .u21),
                       player("Away", 19, loanedTo: "Banbury United")]
        let readings = ["Elder": [reading(0, [.professionalism: 8]), reading(35, [.professionalism: 9]),
                                  reading(70, [.professionalism: 9])],
                        "Young": [reading(0), reading(14, [.pressure: 5]), reading(84, [.pressure: 5])],
                        "Lead": [reading(0), reading(84)]]
        let dynamics = [id("Lead"): PlayerDynamics(standing: .teamLeader, socialGroup: .core),
                        id("Young"): PlayerDynamics(socialGroup: .secondary("A"))]
        let recorded = group(["Lead", "Elder", "Young", "Away"], joined: ["Young": 7])
        let forward = review(recorded, players, dynamics: dynamics, readings: readings, leaving: [id("Elder")])
        #expect(!forward.warnings.isEmpty)

        var reordered = recorded
        reordered.members.reverse()
        let backward = review(reordered, players.reversed(), dynamics: dynamics,
                              readings: readings.mapValues { $0.reversed() }, leaving: [id("Elder")])
        #expect(backward.members == forward.members)
        #expect(backward.warnings == forward.warnings)
        #expect(backward.lead == forward.lead)
        #expect(backward.isDoingHarm == forward.isDoingHarm)
        #expect(backward.hasStoppedWorking == forward.hasStoppedWorking)
    }
}
