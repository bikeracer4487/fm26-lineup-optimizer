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

    /// Lead at Team Leader, everyone else at Others: the review helper's levels unless a test gives its own.
    var leader: [PlayerID: PlayerDynamics] { [id("Lead"): PlayerDynamics(standing: .teamLeader)] }

    /// An arrow read in the first team on day `n`.
    func arrow(_ from: String, _ to: String, _ strength: ArrowStrength, day n: Int = 0) -> ArrowReading {
        ArrowReading(from: id(from), to: id(to), squad: .firstTeam, strength: strength, readOn: day(n))
    }

    /// The six arrows among three players, all read on day 0 at `strength`.
    func six(_ names: [String], _ strength: ArrowStrength = .none) -> [ArrowReading] {
        names.flatMap { from in names.filter { $0 != from }.map { arrow(from, $0, strength) } }
    }

    func read(_ from: String, _ to: String, _ strength: ArrowStrength, day n: Int = 0) -> Arrow {
        Arrow(from: id(from), to: id(to), strength: strength, readOn: day(n))
    }

    func guessed(_ from: String, _ to: String, _ strength: ArrowStrength) -> Arrow {
        Arrow(from: id(from), to: id(to), strength: strength, readOn: nil)
    }

    func request(_ players: [Player], groups: [MentoringGroup] = [], dynamics: [PlayerID: PlayerDynamics] = [:],
                 readings: [String: [PersonalityReading]] = [:], arrows: [ArrowReading] = [],
                 names: [PlayerID: String] = [:], leaving: Set<PlayerID> = [], asOf: Int = 100) -> MentoringRequest {
        MentoringRequest(squad: .firstTeam, players: players, ownClub: "Oxford City", dynamics: dynamics,
                         dynamicsUpdatedOn: nil, groups: groups,
                         readings: Dictionary(uniqueKeysWithValues: readings.map { (id($0.key), $0.value) }),
                         arrows: arrows, names: names, leaving: leaving, asOf: day(asOf))
    }

    /// `dynamics` is `leader` when not given.
    func review(_ group: MentoringGroup, _ players: [Player], dynamics: [PlayerID: PlayerDynamics]? = nil,
                readings: [String: [PersonalityReading]] = [:], arrows: [ArrowReading] = [],
                names: [PlayerID: String] = [:], leaving: Set<PlayerID> = [], asOf: Int = 100) -> GroupReview {
        Mentoring.review(group, request: request(players, groups: [group], dynamics: dynamics ?? leader,
                                                 readings: readings, arrows: arrows, names: names, leaving: leaving,
                                                 asOf: asOf),
                         parameters: q)
    }

    func member(_ review: GroupReview, _ name: String) throws -> MemberReview {
        try #require(review.members.first { $0.player == id(name) })
    }

    func change(_ member: MemberReview, _ attribute: Attribute) throws -> AttributeChange {
        try #require(member.changes.first { $0.attribute == attribute })
    }

    /// Three players: Lead aged 34, at Team Leader by the review helper's levels, and two aged 18. Lead is guessed
    /// Average into each of the other two; nothing else is above None.
    var trio: [Player] { [player("Lead", 34), player("Abel", 18), player("Brook", 18)] }

    // MARK: The six arrows

    @Test func theSixArrowsAreReadOrGuessed() throws {
        let players = [player("Lead", 34), player("Abel", 18, [.professionalism: 8]),
                       player("Brook", 18, [.professionalism: 8])]
        let result = review(group(["Brook", "Lead", "Abel"]), players, arrows: [arrow("Lead", "Abel", .significant)])
        #expect(result.arrows == [
            GroupArrow(arrow: read("Lead", "Abel", .significant), fromName: "Lead", toName: "Abel",
                       pulls: [Pull(attribute: .professionalism, value: 8, towards: 10)]),
            GroupArrow(arrow: guessed("Lead", "Brook", .average), fromName: "Lead", toName: "Brook",
                       pulls: [Pull(attribute: .professionalism, value: 8, towards: 10)])])
        #expect(result.unreadArrows == 5)
        #expect(!result.hasNoInfluence)
        #expect(result.members.map(\.player) == [id("Abel"), id("Brook"), id("Lead")])
        #expect(result.members.map(\.name) == ["Abel", "Brook", "Lead"])
        #expect(result.members.map(\.age) == [18, 18, 34])
        #expect(result.warnings.isEmpty)
        #expect(result.basis == .derived)
        #expect(result.group.id == result.id)

        // Strongest first, then by the source's key, then by the target's.
        let all = [arrow("Lead", "Abel", .significant), arrow("Lead", "Brook", .significant),
                   arrow("Abel", "Brook", .light), arrow("Brook", "Abel", .none), arrow("Abel", "Lead", .none),
                   arrow("Brook", "Lead", .none)]
        let allRead = review(group(["Brook", "Lead", "Abel"]), players, arrows: all)
        #expect(allRead.unreadArrows == 0)
        #expect(allRead.arrows.map(\.arrow) == [read("Lead", "Abel", .significant), read("Lead", "Brook", .significant),
                                                read("Abel", "Brook", .light)])
        #expect(allRead.arrows.last?.pulls == [])
        #expect(!allRead.hasNoInfluence)
        #expect(allRead.warnings.isEmpty)
    }

    @Test func aHarmfulArrowIsAWarningWithItsStrength() throws {
        let levels = [id("Ashby"): PlayerDynamics(standing: .teamLeader)]
        let players = [player("Ashby", 30, [.ambition: 6]), player("Nelson", 20, [.ambition: 13, .professionalism: 8]),
                       player("Cole", 30)]
        let members = group(["Ashby", "Nelson", "Cole"])

        let readSignificant = review(members, players, dynamics: levels, arrows: [arrow("Ashby", "Nelson", .significant)])
        #expect(readSignificant.warnings == [.harmfulArrow(from: id("Ashby"), to: id("Nelson"), strength: .significant,
                                                            isRead: true, attribute: .ambition, fromValue: 6, toValue: 13)])
        // The pull only ever goes upward; the downward pull is the warning.
        #expect(readSignificant.arrows.map(\.pulls) == [[Pull(attribute: .professionalism, value: 8, towards: 10)]])

        let guessedAverage = review(members, players, dynamics: levels)
        #expect(guessedAverage.warnings == [.harmfulArrow(from: id("Ashby"), to: id("Nelson"), strength: .average,
                                                           isRead: false, attribute: .ambition, fromValue: 6, toValue: 13)])

        // Read as None: no influence, so no harm, though Cole's Ambition 10 is also above Ashby's 6.
        let readNone = review(members, players, dynamics: levels, arrows: [arrow("Ashby", "Nelson", .none)])
        #expect(readNone.warnings.isEmpty)
        #expect(readNone.arrows.isEmpty)

        // Judged by worth: Ambition 11 against 13 is past the ceiling on both sides.
        let pastTheCeiling = review(members, [player("Ashby", 30, [.ambition: 11])] + players.dropFirst(),
                                    dynamics: levels, arrows: [arrow("Ashby", "Nelson", .significant)])
        #expect(pastTheCeiling.warnings.isEmpty)

        // A member with no value for a counted attribute has his arrows, but no pulls and no harm judged.
        var noPressure = players[1]
        noPressure.attributes[.pressure] = nil
        let missing = review(members, [players[0], noPressure, players[2]], dynamics: levels,
                             arrows: [arrow("Ashby", "Nelson", .significant)])
        #expect(missing.arrows == [GroupArrow(arrow: read("Ashby", "Nelson", .significant), fromName: "Ashby",
                                              toName: "Nelson", pulls: [])])
        #expect(missing.warnings.isEmpty)
    }

    @Test func noInfluenceAtOnceWhenAllSixAreReadAsNone() throws {
        let names = ["Lead", "Abel", "Brook"]
        let same = ["Lead": [reading(0), reading(98)], "Abel": [reading(0), reading(98)], "Brook": [reading(0), reading(98)]]
        let none = review(group(names), trio, readings: same, arrows: six(names), asOf: 300)
        #expect(none.hasNoInfluence)
        #expect(none.arrows.isEmpty)
        #expect(none.unreadArrows == 0)
        #expect(none.warnings.isEmpty)
        #expect(!none.hasStoppedWorking)
        #expect(!review(group(names), trio, readings: ["Abel": [reading(0), reading(400)]], arrows: six(names), asOf: 400)
            .hasStoppedWorking)
        #expect(review(group(names), trio, arrows: six(names)).hasNoInfluence)

        // Five read: the sixth is a guess, though it is guessed None.
        let five = six(names).filter { !($0.from == id("Abel") && $0.to == id("Brook")) }
        let fiveRead = review(group(names), trio, arrows: five)
        #expect(!fiveRead.hasNoInfluence)
        #expect(fiveRead.unreadArrows == 1)
        #expect(fiveRead.arrows.isEmpty)

        // One of the six read Light.
        let oneLight = five + [arrow("Abel", "Brook", .light)]
        #expect(!review(group(names), trio, arrows: oneLight).hasNoInfluence)

        // One member out on loan: the two left were read None both ways, but not six arrows.
        let away = [player("Lead", 34), player("Abel", 18), player("Brook", 18, loanedTo: "Banbury United")]
        let onLoan = review(group(names), away, arrows: six(names))
        #expect(!onLoan.hasNoInfluence)
        #expect(onLoan.unreadArrows == 0)

        // Four members, every arrow read None: not "all six".
        let four = names + ["Cole"]
        #expect(!review(group(four), trio + [player("Cole", 18)], arrows: six(four)).hasNoInfluence)

        // Doing harm and no influence can be true together; stopped is never true with either.
        let worse = review(group(names), trio, readings: ["Abel": [reading(0), reading(98, [.ambition: 9])]],
                           arrows: six(names), asOf: 300)
        #expect(worse.hasNoInfluence)
        #expect(worse.isDoingHarm)
        #expect(!worse.hasStoppedWorking)
    }

    @Test func arrowsBothWaysAreBothJudged() throws {
        let players = [player("Ashby", 25, [.professionalism: 12, .ambition: 6]), player("Bell", 25, [.ambition: 9]),
                       player("Cole", 18)]
        let names = ["Ashby", "Bell", "Cole"]
        let arrows = [arrow("Ashby", "Bell", .light), arrow("Bell", "Ashby", .light)]
        let result = review(group(names), players, dynamics: [:], arrows: arrows)
        #expect(result.warnings == [
            .harmfulArrow(from: id("Ashby"), to: id("Bell"), strength: .light, isRead: true, attribute: .ambition,
                          fromValue: 6, toValue: 9),
            .harmfulArrow(from: id("Bell"), to: id("Ashby"), strength: .light, isRead: true,
                          attribute: .professionalism, fromValue: 10, toValue: 12)])

        // Both are watched; Cole, with nothing into him, is not.
        func stopped(changed: String?) -> Bool {
            var readings = Dictionary(uniqueKeysWithValues: names.map { ($0, [reading(0), reading(98)]) })
            if let changed {
                readings[changed] = [reading(0), reading(70, [.professionalism: 11]), reading(98, [.professionalism: 11])]
            }
            return review(group(names), players, dynamics: [:], readings: readings, arrows: arrows, asOf: 300)
                .hasStoppedWorking
        }
        #expect(stopped(changed: nil))
        #expect(!stopped(changed: "Ashby"))
        #expect(!stopped(changed: "Bell"))
        #expect(stopped(changed: "Cole"))
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
                     players: [Player]? = nil, dynamics: [PlayerID: PlayerDynamics]? = nil) -> Bool {
            let names = (players ?? trio).map(\.name)
            return review(group(names, joined: joined), players ?? trio, dynamics: dynamics, readings: readings,
                          asOf: 300).hasStoppedWorking
        }
        // Lead is guessed Average into Abel and Brook: they are watched.
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

        // Lead's own change does not restart it: no arrow above None points into him.
        let leadChanged = same91.merging(["Lead": [reading(0), reading(50, [.professionalism: 11]),
                                                   reading(91, [.professionalism: 11])]]) { _, new in new }
        #expect(stopped(leadChanged))

        // A second senior with an arrow into him is watched as well: Lead is guessed Average into Second, 20.
        let two = [player("Lead", 34), player("Second", 20), player("Abel", 18)]
        let twoLevels = [id("Lead"): PlayerDynamics(standing: .teamLeader),
                         id("Second"): PlayerDynamics(standing: .influential)]
        let twoSame = ["Lead": [reading(0), reading(91)], "Second": [reading(0), reading(91)],
                       "Abel": [reading(0), reading(91)]]
        #expect(stopped(twoSame, players: two, dynamics: twoLevels))
        let secondChanged = twoSame.merging(["Second": [reading(0), reading(50, [.professionalism: 11]),
                                                        reading(91, [.professionalism: 11])]]) { _, new in new }
        #expect(!stopped(secondChanged, players: two, dynamics: twoLevels))
    }

    @Test func stoppedWatchesTheMembersWithAnArrowIntoThem() throws {
        // Lead is guessed Average into Abel; nothing is above None into Lead or into Old, who is 30.
        let players = [player("Lead", 34), player("Abel", 18), player("Old", 30)]
        let names = ["Lead", "Abel", "Old"]
        let still = Dictionary(uniqueKeysWithValues: names.map { ($0, [reading(0), reading(98)]) })
        func changed(_ name: String) -> [String: [PersonalityReading]] {
            still.merging([name: [reading(0), reading(70, [.professionalism: 11]),
                                  reading(98, [.professionalism: 11])]]) { _, new in new }
        }
        func result(_ readings: [String: [PersonalityReading]], dynamics: [PlayerID: PlayerDynamics]? = nil,
                    arrows: [ArrowReading] = []) -> GroupReview {
            review(group(names), players, dynamics: dynamics, readings: readings, arrows: arrows, asOf: 300)
        }
        #expect(result(still).hasStoppedWorking)
        #expect(!result(changed("Abel")).hasStoppedWorking)
        #expect(result(changed("Lead")).hasStoppedWorking)
        #expect(result(changed("Old")).hasStoppedWorking)

        // With no arrow above None in the group, and not all six read, it is never called stopped.
        let nothing = result(still, dynamics: [:])
        #expect(!nothing.hasStoppedWorking)
        #expect(!nothing.hasNoInfluence)
        #expect(nothing.unreadArrows == 6)

        // A read arrow counts as much as a guess: Old is watched once Abel's Light into him is read.
        let lightIntoOld = [arrow("Abel", "Old", .light)]
        #expect(result(still, dynamics: [:], arrows: lightIntoOld).hasStoppedWorking)
        #expect(!result(changed("Old"), dynamics: [:], arrows: lightIntoOld).hasStoppedWorking)
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

        let leadIntoAbel = GroupArrow(arrow: guessed("Lead", "Abel", .average), fromName: "Lead", toName: "Abel",
                                      pulls: [Pull(attribute: .professionalism, value: 8, towards: 10)])

        let absent = review(group(["Lead", "Abel", "Gone"]), stayers, readings: gone, names: names)
        #expect(absent.warnings == [.notInSquad(id("Gone"))])
        let left = try member(absent, "Gone")
        #expect(left.name == "Gone Away")
        #expect(left.age == nil)
        #expect(try change(left, .professionalism)
                == AttributeChange(attribute: .professionalism, start: 8, latest: 9, weeks: 5.0, change: .improved))
        #expect(absent.arrows == [leadIntoAbel])

        // Through the report too: a member with no attributes at all is no error.
        let report = try Mentoring.report(request(stayers, groups: [group(["Lead", "Abel", "Gone"])], dynamics: leader,
                                                  readings: gone, names: names), parameters: q)
        #expect(report.groups.first?.warnings == [.notInSquad(id("Gone"))])
        #expect(report.groups.first?.arrows == [leadIntoAbel])

        let moved = review(group(["Lead", "Abel", "Gone"]), stayers + [player("Gone", 19, squad: .u21)],
                           readings: gone, names: names)
        #expect(moved.warnings == [.notInSquad(id("Gone"))])
        #expect(try member(moved, "Gone").age == 19)
        #expect(try member(moved, "Gone").name == "Gone")
        #expect(moved.arrows == [leadIntoAbel])

        // Away on loan he is not read: his Professionalism 15 against Lead's 10 is no harmful arrow.
        let onLoan = review(group(["Lead", "Abel", "Gone"]),
                            stayers + [player("Gone", 19, [.professionalism: 15], loanedTo: "Banbury United")])
        #expect(onLoan.warnings == [.outOnLoan(id("Gone"), club: "Banbury United")])
        #expect(onLoan.arrows == [leadIntoAbel])
        let backFromLoan = review(group(["Lead", "Abel", "Gone"]), stayers + [player("Gone", 19, [.professionalism: 15])])
        #expect(backFromLoan.warnings == [.harmfulArrow(from: id("Lead"), to: id("Gone"), strength: .average,
                                                        isRead: false, attribute: .professionalism, fromValue: 10,
                                                        toValue: 15)])

        let leaving = review(group(["Lead", "Abel", "Gone"]), stayers + [player("Gone", 19)], leaving: [id("Gone")])
        #expect(leaving.warnings == [.advisedToLeave(id("Gone"))])
        // Still in the squad, so still read: Lead's arrow into him pulls him towards Professionalism 10.
        let leavingWithGap = review(group(["Lead", "Abel", "Gone"]),
                                    stayers + [player("Gone", 19, [.professionalism: 7])], leaving: [id("Gone")])
        #expect(leavingWithGap.arrows.first { $0.arrow.to == id("Gone") }?.pulls
                == [Pull(attribute: .professionalism, value: 7, towards: 10)])

        // When Lead goes, the other two are at Others: no arrow is above None.
        let leadGone = review(group(["Lead", "Abel", "Brook"]), [player("Abel", 18), player("Brook", 18)],
                              names: [id("Lead"): "Lead"])
        #expect(leadGone.warnings == [.notInSquad(id("Lead"))])
        #expect(leadGone.arrows.isEmpty)
        #expect(try member(leadGone, "Lead").name == "Lead")
    }

    @Test func aMemberWhoHasGoneHasNoArrows() throws {
        let stayers = [player("Lead", 34), player("Abel", 18)]
        // Readings into and out of Gone, which are not used while he is away.
        let arrows = [arrow("Lead", "Gone", .significant), arrow("Gone", "Abel", .light), arrow("Gone", "Lead", .light)]
        let leadIntoAbel = [guessed("Lead", "Abel", .average)]
        func check(_ players: [Player], _ warning: GroupWarning) throws {
            let result = review(group(["Lead", "Abel", "Gone"]), players, arrows: arrows,
                                names: [id("Gone"): "Gone Away"])
            #expect(result.arrows.map(\.arrow) == leadIntoAbel)
            #expect(result.unreadArrows == 2)
            #expect(!result.hasNoInfluence)
            #expect(result.warnings == [warning])
            let report = try Mentoring.report(request(players, groups: [group(["Lead", "Abel", "Gone"])],
                                                      dynamics: leader, arrows: arrows), parameters: q)
            #expect(report.groups.first?.arrows.map(\.arrow) == leadIntoAbel)
        }
        try check(stayers + [player("Gone", 19, loanedTo: "Banbury United")],
                  .outOnLoan(id("Gone"), club: "Banbury United"))
        try check(stayers + [player("Gone", 19, squad: .u21)], .notInSquad(id("Gone")))
        try check(stayers, .notInSquad(id("Gone")))

        // The pair left, once read, is no longer counted as unread.
        let readPair = review(group(["Lead", "Abel", "Gone"]), stayers,
                              arrows: arrows + [arrow("Lead", "Abel", .light)])
        #expect(readPair.unreadArrows == 1)

        // A reading from him while he is away counts for nothing: Abel takes nothing from three Influential players,
        // so Lead is guessed None into him, and Gone's Light does not undo it.
        let seniors = [player("Sam", 30), player("Tom", 30), player("Uri", 30)]
        let levels = leader.merging(["Sam", "Tom", "Uri"].map { (id($0), PlayerDynamics(standing: .influential)) }) {
            a, _ in a
        }
        let takesNothing = ["Sam", "Tom", "Uri"].map { arrow($0, "Abel", .none) }
        for players in [stayers + seniors, stayers + seniors + [player("Gone", 19, loanedTo: "Banbury United")],
                        stayers + seniors + [player("Gone", 19, squad: .u21)]] {
            let result = review(group(["Lead", "Abel", "Gone"]), players, dynamics: levels,
                                arrows: takesNothing + [arrow("Gone", "Abel", .light)])
            #expect(result.arrows.isEmpty)
        }

        // Back in the squad, his arrows are read and guessed again.
        let back = review(group(["Lead", "Abel", "Gone"]), stayers + [player("Gone", 19)], arrows: arrows)
        #expect(back.unreadArrows == 3)
        #expect(back.arrows.map(\.arrow) == [read("Lead", "Gone", .significant), guessed("Lead", "Abel", .average),
                                             read("Gone", "Abel", .light), read("Gone", "Lead", .light)])
    }

    @Test func everyWarningInOrder() throws {
        let players = [player("Lead", 34, [.ambition: 6, .pressure: 4]),
                       player("Abel", 18, [.ambition: 9, .pressure: 5, .determination: 8]),
                       player("Brook", 18, [.ambition: 9]), player("Cole", 19, loanedTo: "Banbury United")]
        let result = review(group(["Lead", "Abel", "Brook", "Cole", "Dunn"]), players,
                            arrows: [arrow("Abel", "Brook", .light)], leaving: [id("Brook"), id("Abel")])
        func harmful(_ from: String, _ to: String, _ strength: ArrowStrength, read: Bool, _ attribute: Attribute,
                     _ fromValue: Int, _ toValue: Int) -> GroupWarning {
            .harmfulArrow(from: id(from), to: id(to), strength: strength, isRead: read, attribute: attribute,
                          fromValue: fromValue, toValue: toValue)
        }
        #expect(result.warnings == [
            harmful("Abel", "Brook", .light, read: true, .pressure, 5, 10),
            harmful("Abel", "Brook", .light, read: true, .determination, 8, 10),
            harmful("Lead", "Abel", .average, read: false, .pressure, 4, 5),
            harmful("Lead", "Abel", .average, read: false, .ambition, 6, 9),
            harmful("Lead", "Brook", .average, read: false, .pressure, 4, 10),
            harmful("Lead", "Brook", .average, read: false, .ambition, 6, 9),
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
        #expect(result.members.map(\.player) == [id("Abel"), id("Brook"), id("Lead")])
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
        // Young into Elder read twice on one day, None and Light; Lead into Young read twice, the later counting;
        // and readings from players who are away or in another squad.
        let arrows = [arrow("Elder", "Young", .light), arrow("Young", "Elder", .none), arrow("Young", "Elder", .light),
                      arrow("Lead", "Young", .light), arrow("Lead", "Young", .significant, day: 30),
                      arrow("Away", "Young", .significant), arrow("Other", "Elder", .average)]
        let recorded = group(["Lead", "Elder", "Young", "Away"], joined: ["Young": 7])
        let forward = review(recorded, players, dynamics: dynamics, readings: readings, arrows: arrows,
                             leaving: [id("Elder")])
        #expect(!forward.warnings.isEmpty)
        #expect(!forward.arrows.isEmpty)

        var reordered = recorded
        reordered.members.reverse()
        let backward = review(reordered, players.reversed(), dynamics: dynamics,
                              readings: readings.mapValues { $0.reversed() }, arrows: arrows.reversed(),
                              leaving: [id("Elder")])
        #expect(backward.members == forward.members)
        #expect(backward.arrows == forward.arrows)
        #expect(backward.unreadArrows == forward.unreadArrows)
        #expect(backward.hasNoInfluence == forward.hasNoInfluence)
        #expect(backward.warnings == forward.warnings)
        #expect(backward.isDoingHarm == forward.isDoingHarm)
        #expect(backward.hasStoppedWorking == forward.hasStoppedWorking)
    }

    // MARK: What the group still gives

    @Test func aGroupGivesNothingWhenNoMemberHasAnythingToGain() throws {
        // Everyone at 10: Lead's two arrows are above None and give nothing.
        let spent = review(group(["Lead", "Abel", "Brook"]), trio)
        #expect(spent.arrows.count == 2)
        #expect(spent.gain == .toNobody)

        // Abel one below Lead in Professionalism: he has something to gain.
        let working = review(group(["Lead", "Abel", "Brook"]),
                             [player("Lead", 34), player("Abel", 18, [.professionalism: 9]), player("Brook", 18)])
        #expect(working.gain == .toAMember)
    }

    @Test func aGainCountsOnlyThroughAnArrowAboveNone() throws {
        let players = [player("Lead", 34), player("Abel", 18, [.professionalism: 5]), player("Brook", 18)]
        let members = group(["Lead", "Abel", "Brook"])
        // Abel is well below both, and the one arrow guessed into him was read as None.
        #expect(review(members, players, arrows: [arrow("Lead", "Abel", .none)]).gain == .toNobody)
        // Brook's arrow into him read as Light: Brook is worth more than him.
        #expect(review(members, players, arrows: [arrow("Lead", "Abel", .none), arrow("Brook", "Abel", .light)]).gain
                == .toAMember)
    }

    @Test func aGainIsJudgedOverTheCountedAttributesTogether() throws {
        let members = group(["Lead", "Abel", "Brook"])
        // Lead is 2 better in Determination (worth 2) and 1 worse in Professionalism (worth 3): worth less overall.
        let worse = review(members, [player("Lead", 34, [.professionalism: 9]), player("Abel", 18, [.determination: 8]),
                                     player("Brook", 18, [.determination: 8])])
        #expect(worse.gain == .toNobody)
        #expect(!worse.warnings.isEmpty)
        // Level in Professionalism: the Determination is a gain.
        let better = review(members, [player("Lead", 34), player("Abel", 18, [.determination: 8]), player("Brook", 18)])
        #expect(better.gain == .toAMember)
    }

    @Test func aGainToAMemberWhoWillGoIsSaidApart() throws {
        let members = group(["Lead", "Abel", "Brook"])
        let lead = player("Lead", 34), brook = player("Brook", 18)
        // The only member with something to gain is on loan here.
        let onLoan = review(members, [lead, player("Abel", 18, [.professionalism: 8], club: "Banbury United"), brook])
        #expect(onLoan.gain == .onlyToAMemberWhoWillGo)
        // Or advised to leave.
        let own = [lead, player("Abel", 18, [.professionalism: 8]), brook]
        #expect(review(members, own, leaving: [id("Abel")]).gain == .onlyToAMemberWhoWillGo)
        #expect(review(members, own).gain == .toAMember)
        // A second member who gains and stays is a gain to a member.
        let both = [lead, player("Abel", 18, [.professionalism: 8]), player("Brook", 18, [.professionalism: 8])]
        #expect(review(members, both, leaving: [id("Abel")]).gain == .toAMember)
    }

    @Test func withNoHierarchyAGuessSaysNothingAboutWhatTheGroupGives() throws {
        let players = [player("Lead", 34), player("Abel", 18, [.professionalism: 8]), player("Brook", 18)]
        let members = group(["Lead", "Abel", "Brook"])
        // Nobody in the squad has a level: every guess is None, which is no reason to break a group up.
        #expect(review(members, players, dynamics: [:]).gain == .notKnown)
        // Still not known with five of the six read as None.
        let five = six(["Lead", "Abel", "Brook"]).dropLast()
        #expect(review(members, players, dynamics: [:], arrows: Array(five)).gain == .notKnown)
        // An arrow read above None with something to give is the game's own.
        #expect(review(members, players, dynamics: [:], arrows: [arrow("Lead", "Abel", .light)]).gain == .toAMember)
        // All six read, and the one above None gives nothing: nobody gains, hierarchy or not.
        let read = six(["Lead", "Abel", "Brook"]).filter { !($0.from == id("Lead") && $0.to == id("Brook")) }
            + [arrow("Lead", "Brook", .light)]
        #expect(review(members, players, dynamics: [:], arrows: read).gain == .toNobody)
        // A level entered for anyone in the squad makes the guesses count.
        #expect(review(members, players + [player("Chief", 30)],
                       dynamics: [id("Chief"): PlayerDynamics(standing: .influential)]).gain == .toNobody)
    }

    @Test func aMemberWhoHasGoneGivesNothing() throws {
        // Abel had something to gain from Lead, who is no longer imported. Chief keeps a level in the squad.
        let levels = leader.merging([id("Chief"): PlayerDynamics(standing: .influential)]) { first, _ in first }
        let left = [player("Abel", 18, [.professionalism: 8]), player("Brook", 18)]
        let result = review(group(["Lead", "Abel", "Brook"]), left + [player("Chief", 30)], dynamics: levels)
        #expect(result.gain == .toNobody)
        #expect(result.warnings == [.notInSquad(id("Lead"))])
        // With Lead the only player who had a level, the guesses left say nothing.
        #expect(review(group(["Lead", "Abel", "Brook"]), left).gain == .notKnown)
    }
}
