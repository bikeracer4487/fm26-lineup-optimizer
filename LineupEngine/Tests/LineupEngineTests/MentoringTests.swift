import Foundation
import Testing
@testable import LineupEngine

@Suite struct MentoringTests {
    let q = EngineParameters.fm27
    let today = Day(year: 2026, month: 11, day: 14)!

    // MARK: Helpers

    /// A player of Oxford City with every attribute 10 unless `values` says otherwise.
    func player(_ name: String, _ age: Int, _ values: [Attribute: Int] = [:], squad: Squad = .firstTeam,
                club: String? = "Oxford City", loanedTo: String? = nil, isInjured: Bool = false) -> Player {
        .fixture(name: name, squad: squad, age: age, attributes: values, isInjured: isInjured, club: club, loanedTo: loanedTo)
    }

    /// A lead aged 34 with Professionalism 20: every player left at 10 gains 30 from him.
    func lead(_ values: [Attribute: Int] = [:], name: String = "Lead", age: Int = 34, club: String? = "Oxford City",
              loanedTo: String? = nil, isInjured: Bool = false) -> Player {
        player(name, age, [.professionalism: 20].merging(values) { _, new in new }, club: club, loanedTo: loanedTo,
               isInjured: isInjured)
    }

    func id(_ name: String) -> PlayerID { PlayerID(key: PlayerID.normalise(name)) }

    func request(_ players: [Player], squad: Squad = .firstTeam, dynamics: [PlayerID: PlayerDynamics] = [:],
                 updatedOn: Day? = nil, groups: [MentoringGroup] = [], leaving: Set<PlayerID> = []) -> MentoringRequest {
        MentoringRequest(squad: squad, players: players, ownClub: "Oxford City", dynamics: dynamics,
                         dynamicsUpdatedOn: updatedOn, groups: groups, readings: [:], names: [:], leaving: leaving,
                         asOf: today)
    }

    func report(_ players: [Player], squad: Squad = .firstTeam, dynamics: [PlayerID: PlayerDynamics] = [:],
                updatedOn: Day? = nil, groups: [MentoringGroup] = [], leaving: Set<PlayerID> = [],
                parameters: EngineParameters? = nil) throws -> MentoringReport {
        try Mentoring.report(request(players, squad: squad, dynamics: dynamics, updatedOn: updatedOn, groups: groups,
                                     leaving: leaving), parameters: parameters ?? q)
    }

    /// The suggested groups as names: the lead's key, then the members' keys in their order.
    func shape(_ report: MentoringReport) -> [[String]] {
        report.suggestions.map { [$0.lead.key] + $0.members.map(\.player.key) }
    }

    /// The not-placed list as (key, reason).
    func notPlaced(_ report: MentoringReport) -> [String: NotPlacedReason] {
        Dictionary(uniqueKeysWithValues: report.notPlaced.map { ($0.player.key, $0.reason) })
    }

    func group(_ keys: [String], squad: Squad = .firstTeam, endedOn: Day? = nil, leftOn: [String: Day] = [:])
        -> MentoringGroup {
        let start = today.adding(days: -60)
        return MentoringGroup(id: UUID(), squad: squad, startedOn: start, endedOn: endedOn, members: keys.map {
            MentoringMember(player: PlayerID(key: $0), joinedOn: start, leftOn: leftOn[$0])
        })
    }

    // MARK: Groups

    @Test func aLeadAndTwoYoungPlayersMakeAGroup() throws {
        let players = [
            player("Lead", 34, [.professionalism: 17, .pressure: 12, .determination: 15, .ambition: 10]),
            player("Older", 19, [.professionalism: 11, .pressure: 12, .determination: 7, .ambition: 10]),
            player("Younger", 18, [.professionalism: 8, .pressure: 4, .determination: 10, .ambition: 10])]
        let result = try report(players, dynamics: [id("Lead"): PlayerDynamics(standing: .teamLeader)])
        #expect(result.suggestions.count == 1)
        let suggestion = try #require(result.suggestions.first)
        #expect(suggestion.lead == id("Lead"))
        #expect(suggestion.leadName == "Lead")
        #expect(suggestion.leadAge == 34)
        #expect(suggestion.leadStanding == .teamLeader)
        #expect(suggestion.cautions.isEmpty)
        #expect(suggestion.basis == .derived)
        #expect(suggestion.members.map(\.player) == [id("Younger"), id("Older")])
        #expect(suggestion.members.map(\.age) == [18, 19])
        #expect(suggestion.members.map(\.name) == ["Younger", "Older"])
        #expect(suggestion.members.allSatisfy { !$0.isMakingUp && !$0.inDifferentSocialGroup })
        #expect(suggestion.members[0].pulls == [Pull(attribute: .professionalism, value: 8, towards: 17),
                                                 Pull(attribute: .pressure, value: 4, towards: 12)])
        #expect(suggestion.members[1].pulls == [Pull(attribute: .professionalism, value: 11, towards: 17),
                                                 Pull(attribute: .determination, value: 7, towards: 15)])
        #expect(result.notPlaced.isEmpty)
        #expect(result.squad == .firstTeam)
        #expect(result.basis == .derived)
    }

    @Test func aPlayerOver23IsNotACandidate() throws {
        // At 24 "Elder" stands five years above "Young" and would drag his Professionalism down, so he cannot make up.
        let at24 = try report([lead(), player("Young", 19), player("Elder", 24, [.professionalism: 5])])
        #expect(at24.suggestions.isEmpty)
        #expect(notPlaced(at24) == [id("Young").key: .noThird])

        let at23 = try report([lead(), player("Young", 19), player("Elder", 23, [.professionalism: 5])])
        #expect(shape(at23) == [["lead", "elder", "young"]])
        #expect(at23.notPlaced.isEmpty)
    }

    @Test func aPlayerAtEveryCeilingAppearsNowhere() throws {
        let atCeiling: [Attribute: Int] = [.professionalism: 20, .pressure: 6, .determination: 10, .ambition: 10]
        let full = try report([lead(), player("Done", 19, atCeiling)])
        #expect(full.suggestions.isEmpty)
        #expect(full.notPlaced.isEmpty)

        let oneShort = try report([lead(), player("Done", 19, atCeiling.merging([.professionalism: 19]) { _, new in new })])
        #expect(notPlaced(oneShort) == ["done": .noThird])
    }

    @Test func aPlayerAdvisedToLeaveIsNotMentored() throws {
        let players = [lead(), player("Going", 18), player("Staying", 18)]
        let advised = try report(players, leaving: [id("Going")])
        #expect(advised.suggestions.isEmpty)
        #expect(notPlaced(advised) == ["staying": .noThird])

        let notAdvised = try report(players)
        #expect(shape(notAdvised) == [["lead", "going", "staying"]])
    }

    @Test func canStillLeadWithTheCaution() throws {
        let result = try report([lead(), player("A", 18), player("B", 18)], leaving: [id("Lead")])
        #expect(shape(result) == [["lead", "a", "b"]])
        #expect(result.suggestions.first?.cautions == [.advisedToLeave])
    }

    @Test func aLoaneeIsNotMentoredButCanLeadWithTheCaution() throws {
        let asMentee = try report([lead(), player("Loanee", 18, club: "Banbury United"), player("A", 18)])
        #expect(asMentee.suggestions.isEmpty)
        #expect(notPlaced(asMentee) == ["a": .noThird])

        let asLead = try report([lead(club: "Banbury United"), player("A", 18), player("B", 18)])
        #expect(shape(asLead) == [["lead", "a", "b"]])
        #expect(asLead.suggestions.first?.cautions == [.onLoanHere])

        let both = try report([lead(club: "Banbury United"), player("A", 18), player("B", 18)], leaving: [id("Lead")])
        #expect(both.suggestions.first?.cautions == [.onLoanHere, .advisedToLeave])
    }

    @Test func aPlayerOutOnLoanIsNeitherLeadNorMentee() throws {
        let leadAway = try report([lead(loanedTo: "Banbury United"), player("A", 18), player("B", 18)])
        #expect(leadAway.suggestions.isEmpty)
        #expect(notPlaced(leadAway) == ["a": .nobodyAbove, "b": .nobodyAbove])

        let youngAway = try report([lead(), player("Away", 18, loanedTo: "Banbury United"), player("A", 18)])
        #expect(youngAway.suggestions.isEmpty)
        #expect(notPlaced(youngAway) == ["a": .noThird])
    }

    @Test func aLeadWhoWouldHarmIsNotSuggested() throws {
        let harming = try report([lead([.ambition: 6]), player("A", 18, [.ambition: 9]), player("B", 18, [.ambition: 9])])
        #expect(harming.suggestions.isEmpty)
        #expect(notPlaced(harming) == ["a": .wouldHarm(.ambition), "b": .wouldHarm(.ambition)])

        // Both values are past the ceiling of 10, so neither is worth more than the other there.
        let pastTheCeiling = try report([lead([.ambition: 11]), player("A", 18, [.ambition: 14]),
                                         player("B", 18, [.ambition: 14])])
        #expect(shape(pastTheCeiling) == [["lead", "a", "b"]])
        #expect(pastTheCeiling.suggestions.first?.members.first?.pulls
                == [Pull(attribute: .professionalism, value: 10, towards: 20)])
    }

    @Test func twoMenteesMustNotHarmEachOther() throws {
        // Five years apart, "Elder" stands above "Young" and is worth less in Pressure.
        let fiveYears = try report([lead(), player("Elder", 23, [.pressure: 3]), player("Young", 18, [.pressure: 5])])
        #expect(fiveYears.suggestions.isEmpty)
        #expect(notPlaced(fiveYears) == ["elder": .noThird, "young": .noThird])

        let fourYears = try report([lead(), player("Elder", 22, [.pressure: 3]), player("Young", 18, [.pressure: 5])])
        #expect(shape(fourYears) == [["lead", "elder", "young"]])
    }

    @Test func mostToGainGetsFirstCallOnTheLead() throws {
        // Gains from the lead: Cole 30, Baker 20, Adams 10; by key Adams would come first.
        let players = [lead(), player("Adams", 19, [.professionalism: 17, .ambition: 9]),
                       player("Baker", 20, [.professionalism: 14, .ambition: 8]), player("Cole", 18)]
        let result = try report(players)
        #expect(shape(result) == [["lead", "cole", "baker"]])
        #expect(notPlaced(result) == ["adams": .leadsTaken])
    }

    @Test func aDifferentSocialGroupCountsForHalf() throws {
        // Abel and Brook each gain 30 from the lead; Cole gains 21.
        let lead = lead(), abel = player("Abel", 18), brook = player("Brook", 18)
        let cole = player("Cole", 18, [.professionalism: 13])
        let apart: [PlayerID: PlayerDynamics] = [id("Lead"): PlayerDynamics(socialGroup: .core),
                                                 id("Abel"): PlayerDynamics(socialGroup: .secondary("A"))]

        let noGroups = try report([lead, abel, brook])
        #expect(shape(noGroups) == [["lead", "abel", "brook"]])
        #expect(noGroups.suggestions.first?.members.map(\.inDifferentSocialGroup) == [false, false])

        let halved = try report([lead, abel, brook], dynamics: apart)
        #expect(shape(halved) == [["lead", "brook", "abel"]])
        #expect(halved.suggestions.first?.members.map(\.inDifferentSocialGroup) == [false, true])

        let sameGroup = try report([lead, abel, brook], dynamics: [id("Lead"): PlayerDynamics(socialGroup: .core),
                                                                   id("Abel"): PlayerDynamics(socialGroup: .core)])
        #expect(sameGroup == noGroups)
        let onlyOneEntered = try report([lead, abel, brook], dynamics: [id("Abel"): PlayerDynamics(socialGroup: .core)])
        #expect(shape(onlyOneEntered) == shape(noGroups))

        let threeNoGroups = try report([lead, abel, brook, cole])
        #expect(shape(threeNoGroups) == [["lead", "abel", "brook"]])
        #expect(notPlaced(threeNoGroups) == ["cole": .leadsTaken])

        let threeHalved = try report([lead, abel, brook, cole], dynamics: apart)
        #expect(shape(threeHalved) == [["lead", "brook", "cole"]])
        #expect(notPlaced(threeHalved) == ["abel": .leadsTaken])
    }

    @Test func aLeadWithOneMenteeNeedsAThird() throws {
        let lead = lead(), young = player("Young", 18)
        // "Senior" is Influential: the lead does not stand above him, so he cannot make up although he is youngest.
        let senior = player("Senior", 24)
        let standings = [id("Senior"): PlayerDynamics(standing: .influential)]
        // "Aaron" would drag Young's Professionalism down; "Loanee" is not the club's; "Going" is advised to leave.
        let aaron = player("Aaron", 25, [.professionalism: 8])
        let loanee = player("Loanee", 25, club: "Banbury United")
        let going = player("Going", 25)
        let adams = player("Adams", 29), baker = player("Baker", 27)

        let result = try report([lead, young, senior, aaron, loanee, going, adams, baker], dynamics: standings,
                                leaving: [id("Going")])
        #expect(shape(result) == [["lead", "young", "baker"]])
        let members = try #require(result.suggestions.first?.members)
        #expect(members.map(\.isMakingUp) == [false, true])
        #expect(members[1].pulls == [Pull(attribute: .professionalism, value: 10, towards: 20)])
        #expect(result.notPlaced.isEmpty)

        let onlyAdams = try report([lead, young, senior, adams], dynamics: standings)
        #expect(shape(onlyAdams) == [["lead", "young", "adams"]])

        let noThird = try report([lead, young, senior, aaron, loanee, going], dynamics: standings,
                                 leaving: [id("Going")])
        #expect(noThird.suggestions.isEmpty)
        #expect(notPlaced(noThird) == ["young": .noThird])
    }

    @Test func tiesGoToAFullGroupThenTheLowestKeys() throws {
        // Abe (made up with Old) and Zed (with A and B) offer the same gain, 30; the full group is formed first although
        // Abe's key is lower. Abe would drag A and B's Ambition down; Zed does not stand above C.
        let fullFirst = try report([
            player("Abe", 34, [.professionalism: 20, .ambition: 9]), player("Zed", 25, [.professionalism: 15]),
            player("A", 18), player("B", 18), player("C", 21, [.ambition: 9]), player("Old", 28, [.ambition: 9])])
        #expect(shape(fullFirst) == [["zed", "a", "b"], ["abe", "c", "old"]])
        #expect(fullFirst.suggestions.map { $0.members.map(\.isMakingUp) } == [[false, false], [false, true]])

        let equalLeads = try report([lead(name: "Lead B"), lead(name: "Lead A"),
                                     player("D", 18), player("C", 18), player("B", 18), player("A", 18)])
        #expect(shape(equalLeads) == [["lead a", "a", "b"], ["lead b", "c", "d"]])

        let equalThirds = try report([lead(), player("Young", 18), player("Bee", 28), player("Ace", 28)])
        #expect(shape(equalThirds) == [["lead", "young", "ace"]])
    }

    @Test func aThirdWithNothingToGainHasNoPulls() throws {
        let result = try report([lead(), player("Young", 18), player("Equal", 28, [.professionalism: 20])])
        #expect(shape(result) == [["lead", "young", "equal"]])
        #expect(result.suggestions.first?.members.last?.pulls == [])
        #expect(result.suggestions.first?.members.last?.isMakingUp == true)
    }

    @Test func aCandidateCanLead() throws {
        // By age alone: Leader is 21, five years above the two 16-year-olds, and below the Ambition ceiling himself.
        let result = try report([player("Leader", 21, [.professionalism: 20, .ambition: 9]),
                                 player("Kid A", 16, [.ambition: 9]), player("Kid B", 16, [.ambition: 9])])
        #expect(result.byAgeAlone)
        #expect(shape(result) == [["leader", "kid a", "kid b"]])
        #expect(result.notPlaced.isEmpty)
    }

    @Test func membersOfARecordedGroupAreLeftOut() throws {
        let players = [lead(), player("A", 18), player("B", 18)]
        let live = try report(players, groups: [group(["lead", "x", "y"])])
        #expect(live.suggestions.isEmpty)
        #expect(notPlaced(live) == ["a": .leadsTaken, "b": .leadsTaken])

        let otherSquad = try report(players, groups: [group(["lead", "x", "y"], squad: .u21)])
        #expect(otherSquad.suggestions.isEmpty)

        let recordedMentee = try report(players + [player("C", 18)], groups: [group(["c", "x", "y"])])
        #expect(shape(recordedMentee) == [["lead", "a", "b"]])
        #expect(recordedMentee.notPlaced.isEmpty)

        let ended = try report(players, groups: [group(["lead", "x", "y"], endedOn: today.adding(days: -1))])
        #expect(shape(ended) == [["lead", "a", "b"]])

        let left = try report(players, groups: [group(["lead", "x", "y"], leftOn: ["lead": today.adding(days: -1)])])
        #expect(shape(left) == [["lead", "a", "b"]])
    }

    @Test func notPlacedReasons() throws {
        let nobodyAbove = try report([player("A", 18), player("B", 20)])
        #expect(notPlaced(nobodyAbove) == ["a": .nobodyAbove, "b": .nobodyAbove])

        let nobodyBetter = try report([player("Old", 34), player("A", 18)])
        #expect(notPlaced(nobodyBetter) == ["a": .nobodyBetter])

        // Zed gives the greater gain (25, against Abe's 7), so his harm is named although Abe's key is lower and
        // Pressure comes before Ambition.
        let wouldHarm = try report([player("Zed", 34, [.professionalism: 20, .ambition: 5]),
                                    player("Abe", 34, [.professionalism: 15, .pressure: 2]), player("A", 18)])
        #expect(notPlaced(wouldHarm) == ["a": .wouldHarm(.ambition)])

        let leadsTaken = try report([lead(), player("A", 18), player("B", 18), player("C", 18, [.professionalism: 15])])
        #expect(notPlaced(leadsTaken) == ["c": .leadsTaken])

        let noThird = try report([lead(), player("A", 18)])
        #expect(notPlaced(noThird) == ["a": .noThird])
        #expect(noThird.notPlaced.first == NotPlaced(player: id("A"), name: "A", age: 18, reason: .noThird))
    }

    @Test func notPlacedIsByKey() throws {
        let result = try report([player("Cid", 18), player("Abe", 19), player("Bo", 17)])
        #expect(result.notPlaced.map(\.player.key) == ["abe", "bo", "cid"])
    }

    @Test func byAgeAloneAndStale() throws {
        let players = [lead(), player("A", 18)]
        #expect(try report(players).byAgeAlone)
        #expect(try report(players, dynamics: [id("A"): PlayerDynamics(standing: .others)]).byAgeAlone)
        #expect(try report(players, dynamics: [id("Elsewhere"): PlayerDynamics(standing: .teamLeader)]).byAgeAlone)
        #expect(try !report(players, dynamics: [id("A"): PlayerDynamics(standing: .influential)]).byAgeAlone)

        #expect(try report(players, updatedOn: today.adding(days: -29)).isStale)
        #expect(try !report(players, updatedOn: today.adding(days: -28)).isStale)
        #expect(try !report(players, updatedOn: nil).isStale)
    }

    @Test func aSquadWithNobodyOlderHasNoSuggestions() throws {
        let five = try report([player("A", 16), player("B", 16), player("C", 17), player("D", 18), player("E", 18)])
        #expect(five.suggestions.isEmpty)
        #expect(notPlaced(five) == ["a": .nobodyAbove, "b": .nobodyAbove, "c": .nobodyAbove, "d": .nobodyAbove,
                                    "e": .nobodyAbove])

        let two = try report([player("A", 16), player("B", 18)])
        #expect(two.suggestions.isEmpty)
        #expect(notPlaced(two) == ["a": .nobodyAbove, "b": .nobodyAbove])

        let none = try report([])
        #expect(none.suggestions.isEmpty)
        #expect(none.notPlaced.isEmpty)
    }

    // MARK: Errors

    @Test func aMissingCountedValueIsAnErrorNamingThePlayer() throws {
        var noPressure = player("Bravo", 18)
        noPressure.attributes[.pressure] = nil
        #expect(throws: RatingError.missingAttribute(player: "Bravo", attribute: .pressure)) {
            try report([lead(), noPressure])
        }

        var away = noPressure
        away.loanedTo = "Banbury United"
        _ = try report([lead(), away])

        var noLoyalty = player("Bravo", 18)
        noLoyalty.attributes[.loyalty] = nil
        _ = try report([lead(), noLoyalty])

        var otherSquad = noPressure
        otherSquad.squad = .u21
        _ = try report([lead(), otherSquad])

        var alsoMissing = player("Alpha", 18)
        alsoMissing.attributes[.ambition] = nil
        for players in [[noPressure, alsoMissing], [alsoMissing, noPressure]] {
            #expect(throws: RatingError.missingAttribute(player: "Alpha", attribute: .ambition)) {
                try report(players)
            }
        }
    }

    @Test func badParametersThrow() throws {
        var bad = q
        var ceilings = q.mentoringCeilings.value
        ceilings[.ambition] = nil
        bad.mentoringCeilings = Parameter(ceilings, .derived, source: "test")
        let problems = Mentoring.problems(in: bad)
        #expect(!problems.isEmpty)
        #expect(throws: PlanError.badParameters(problems)) { try report([lead(), player("A", 18)], parameters: bad) }

        // Bad parameters are found before any player is read.
        var noPressure = player("A", 18)
        noPressure.attributes[.pressure] = nil
        #expect(throws: PlanError.badParameters(problems)) { try report([noPressure], parameters: bad) }
    }

    // MARK: Scope and order

    @Test func onlyTheSquadAskedForIsLookedAt() throws {
        let players = [lead(), player("A", 18, squad: .u21), player("B", 18, squad: .u21)]
        let u21 = try report(players, squad: .u21)
        #expect(u21.squad == .u21)
        #expect(u21.suggestions.isEmpty)
        #expect(notPlaced(u21) == ["a": .nobodyAbove, "b": .nobodyAbove])

        let firstTeam = try report(players)
        #expect(firstTeam.suggestions.isEmpty)
        #expect(firstTeam.notPlaced.isEmpty)
    }

    @Test func inputOrderDoesNotMatter() throws {
        let players = [lead(), lead([.pressure: 3], name: "Second", age: 33), player("Leader", 21, [.professionalism: 20, .ambition: 9]),
                       player("Kid A", 16, [.ambition: 9]), player("Kid B", 16, [.ambition: 9]),
                       player("A", 18), player("B", 19, [.professionalism: 12]), player("C", 20, [.pressure: 2]),
                       player("D", 18, [.determination: 4]), player("E", 22), player("Making Up", 28),
                       player("Recorded", 18), player("Loanee", 19, club: "Banbury United")]
        let groups = [group(["recorded", "x", "y"]), group(["second", "z", "w"], endedOn: today)]
        let dynamics = [id("Lead"): PlayerDynamics(standing: .teamLeader, socialGroup: .core),
                        id("B"): PlayerDynamics(socialGroup: .secondary("A"))]
        let forward = try report(players, dynamics: dynamics, groups: groups)
        #expect(!forward.suggestions.isEmpty)
        #expect(!forward.notPlaced.isEmpty)
        #expect(try report(Array(players.reversed()), dynamics: dynamics, groups: Array(groups.reversed())) == forward)
        let shuffled = [7, 2, 11, 0, 9, 4, 12, 1, 6, 3, 10, 5, 8].map { players[$0] }
        #expect(try report(shuffled, dynamics: dynamics, groups: groups) == forward)
    }

    @Test func anInjuredPlayerIsTreatedLikeAnyOther() throws {
        let fit = try report([lead(), player("A", 18), player("B", 18)])
        let injured = try report([lead(isInjured: true), player("A", 18, isInjured: true), player("B", 18)])
        #expect(shape(fit) == [["lead", "a", "b"]])
        #expect(injured == fit)
    }
}
