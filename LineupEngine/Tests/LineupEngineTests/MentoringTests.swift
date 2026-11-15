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

    /// A senior with Professionalism 20 and every other attribute 10, at every ceiling: a player of 23 or younger left
    /// at 10 is worth 30 less than him, and gains 60 from an Average arrow.
    func senior(_ name: String = "Lead", _ age: Int = 30, _ values: [Attribute: Int] = [:], club: String? = "Oxford City",
                loanedTo: String? = nil, isInjured: Bool = false) -> Player {
        player(name, age, [.professionalism: 20].merging(values) { _, new in new }, club: club, loanedTo: loanedTo,
               isInjured: isInjured)
    }

    func id(_ name: String) -> PlayerID { PlayerID(key: PlayerID.normalise(name)) }

    func levels(_ entries: [String: Standing]) -> [PlayerID: PlayerDynamics] {
        Dictionary(uniqueKeysWithValues: entries.map { (id($0.key), PlayerDynamics(standing: $0.value)) })
    }

    var leader: [PlayerID: PlayerDynamics] { levels(["Lead": .teamLeader]) }

    /// An arrow read in the first team today.
    func reading(_ from: String, _ to: String, _ strength: ArrowStrength) -> ArrowReading {
        ArrowReading(from: id(from), to: id(to), squad: .firstTeam, strength: strength, readOn: today)
    }

    func request(_ players: [Player], squad: Squad = .firstTeam, dynamics: [PlayerID: PlayerDynamics] = [:],
                 updatedOn: Day? = nil, groups: [MentoringGroup] = [], arrows: [ArrowReading] = [],
                 leaving: Set<PlayerID> = []) -> MentoringRequest {
        MentoringRequest(squad: squad, players: players, ownClub: "Oxford City", dynamics: dynamics,
                         dynamicsUpdatedOn: updatedOn, groups: groups, readings: [:], arrows: arrows, names: [:],
                         leaving: leaving, asOf: today)
    }

    func report(_ players: [Player], squad: Squad = .firstTeam, dynamics: [PlayerID: PlayerDynamics] = [:],
                updatedOn: Day? = nil, groups: [MentoringGroup] = [], arrows: [ArrowReading] = [],
                leaving: Set<PlayerID> = [], parameters: EngineParameters? = nil) throws -> MentoringReport {
        try Mentoring.report(request(players, squad: squad, dynamics: dynamics, updatedOn: updatedOn, groups: groups,
                                     arrows: arrows, leaving: leaving), parameters: parameters ?? q)
    }

    /// Each suggestion's three keys.
    func shape(_ report: MentoringReport) -> [[String]] {
        report.suggestions.map { $0.members.map(\.player.key) }
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

    func guessed(_ from: String, _ to: String, _ strength: ArrowStrength) -> Arrow {
        Arrow(from: id(from), to: id(to), strength: strength, readOn: nil)
    }

    func read(_ from: String, _ to: String, _ strength: ArrowStrength) -> Arrow {
        Arrow(from: id(from), to: id(to), strength: strength, readOn: today)
    }

    // MARK: Groups

    @Test func aTeamLeaderAndTwoYoungPlayersMakeAGroup() throws {
        let players = [
            player("Lead", 30, [.professionalism: 17, .pressure: 12, .determination: 15, .ambition: 10]),
            player("Younger", 18, [.professionalism: 8, .pressure: 4, .determination: 10, .ambition: 10]),
            player("Older", 19, [.professionalism: 11, .pressure: 12, .determination: 7, .ambition: 10])]
        let result = try report(players, dynamics: leader)
        #expect(result.suggestions.count == 1)
        let suggestion = try #require(result.suggestions.first)
        #expect(suggestion.members == [SuggestedMember(player: id("Lead"), name: "Lead", age: 30),
                                       SuggestedMember(player: id("Older"), name: "Older", age: 19),
                                       SuggestedMember(player: id("Younger"), name: "Younger", age: 18)])
        #expect(suggestion.id == "lead|older|younger")
        #expect(suggestion.arrows == [
            GroupArrow(arrow: guessed("Lead", "Younger", .average), fromName: "Lead", toName: "Younger",
                       pulls: [Pull(attribute: .professionalism, value: 8, towards: 17),
                               Pull(attribute: .pressure, value: 4, towards: 12)]),
            GroupArrow(arrow: guessed("Lead", "Older", .average), fromName: "Lead", toName: "Older",
                       pulls: [Pull(attribute: .professionalism, value: 11, towards: 17),
                               Pull(attribute: .determination, value: 7, towards: 15)])])
        #expect(!suggestion.isRead)
        #expect(suggestion.cautions.isEmpty)
        #expect(suggestion.basis == .derived)
        #expect(result.notPlaced.isEmpty)
        #expect(!result.needsHierarchy)
        #expect(result.squad == .firstTeam)
        #expect(result.basis == .derived)
    }

    @Test func aReadingStandsInForTheGuess() throws {
        let players = [
            player("Lead", 30, [.professionalism: 17, .pressure: 12, .determination: 15, .ambition: 10]),
            player("Younger", 18, [.professionalism: 8, .pressure: 4, .determination: 10, .ambition: 10]),
            player("Older", 19, [.professionalism: 11, .pressure: 12, .determination: 7, .ambition: 10])]
        let significant = try report(players, dynamics: leader, arrows: [reading("Lead", "Younger", .significant)])
        let arrows = try #require(significant.suggestions.first?.arrows)
        #expect(arrows.map(\.arrow) == [read("Lead", "Younger", .significant), guessed("Lead", "Older", .average)])
        #expect(arrows.first?.pulls == [Pull(attribute: .professionalism, value: 8, towards: 17),
                                        Pull(attribute: .pressure, value: 4, towards: 12)])

        let none = try report(players, dynamics: leader, arrows: [reading("Lead", "Younger", .none)])
        #expect(shape(none) == [["lead", "older", "younger"]])
        #expect(none.suggestions.first?.arrows.map(\.arrow) == [guessed("Lead", "Older", .average)])
        #expect(none.notPlaced.isEmpty)
    }

    @Test func anInfluentialPlayerIsGuessedLightAndOthersNothing() throws {
        let players = [senior("Senior"), player("A", 20), player("B", 20)]
        let influential = try report(players, dynamics: levels(["Senior": .influential]))
        #expect(shape(influential) == [["a", "b", "senior"]])
        #expect(influential.suggestions.first?.arrows.map(\.arrow)
                == [guessed("Senior", "A", .light), guessed("Senior", "B", .light)])
        #expect(!influential.needsHierarchy)

        let others = try report(players, dynamics: levels(["Senior": .others]))
        #expect(others.suggestions.isEmpty)
        #expect(notPlaced(others) == ["a": .noInfluence, "b": .noInfluence])
        #expect(others.needsHierarchy)
    }

    @Test func aPlayerOf24ComesInOnlyByAReading() throws {
        let players = [senior("Lead"), player("Elder", 24), player("Young", 20)]
        let guessedOnly = try report(players, dynamics: leader)
        #expect(shape(guessedOnly) == [["elder", "lead", "young"]])
        #expect(guessedOnly.suggestions.first?.arrows.map(\.arrow) == [guessed("Lead", "Young", .average)])

        let withReading = try report(players, dynamics: leader, arrows: [reading("Lead", "Elder", .light)])
        #expect(withReading.suggestions.first?.arrows == [
            GroupArrow(arrow: guessed("Lead", "Young", .average), fromName: "Lead", toName: "Young",
                       pulls: [Pull(attribute: .professionalism, value: 10, towards: 20)]),
            GroupArrow(arrow: read("Lead", "Elder", .light), fromName: "Lead", toName: "Elder",
                       pulls: [Pull(attribute: .professionalism, value: 10, towards: 20)])])
    }

    @Test func aCandidatesGainIsHisGreatestArrowNotTheSum() throws {
        let seniors = levels(["Lead": .teamLeader, "Second": .influential])
        let equal = try report([senior("Lead"), senior("Second"), player("A", 20), player("B", 20)], dynamics: seniors)
        #expect(shape(equal) == [["a", "b", "lead"]])

        // Low gains 96 from Lead and 48 from Second; High gains 12 from Lead. Adding Low's two arrows (144) would put
        // the two seniors with Low ahead of Lead with both juniors (108); his greatest (96) does not.
        let uneven = try report([senior("Lead"), senior("Second"), player("Low", 20, [.professionalism: 4]),
                                 player("High", 20, [.professionalism: 18])], dynamics: seniors)
        #expect(shape(uneven) == [["high", "lead", "low"]])
        #expect(uneven.notPlaced.isEmpty)
    }

    @Test func noGroupHoldsAHarmfulArrow() throws {
        let harming = try report([senior("Lead", 30, [.ambition: 6]), player("A", 18, [.ambition: 9]),
                                  player("B", 18, [.ambition: 9])], dynamics: leader)
        #expect(harming.suggestions.isEmpty)
        #expect(notPlaced(harming) == ["a": .wouldHarm, "b": .wouldHarm, "lead": .noInfluence])

        // Both values are past the ceiling of 10, so neither is worth more than the other there.
        let pastTheCeiling = try report([senior("Lead", 30, [.ambition: 11]), player("A", 18, [.ambition: 14]),
                                         player("B", 18, [.ambition: 14])], dynamics: leader)
        #expect(shape(pastTheCeiling) == [["a", "b", "lead"]])
        #expect(pastTheCeiling.suggestions.first?.arrows.first?.pulls
                == [Pull(attribute: .professionalism, value: 10, towards: 20)])
    }

    @Test func aHarmfulArrowBetweenTheOtherTwoAlsoStopsTheGroup() throws {
        // Inf would be guessed Light into either junior, and is worth less than both in Pressure.
        let players = [senior("Lead"), player("Inf", 23, [.pressure: 3]), player("Junior", 18, [.pressure: 5]),
                       player("Second", 19)]
        let dynamics = levels(["Lead": .teamLeader, "Inf": .influential])
        let guessedOnly = try report(players, dynamics: dynamics)
        #expect(shape(guessedOnly) == [["junior", "lead", "second"]])
        #expect(notPlaced(guessedOnly) == ["inf": .wouldHarm])

        let readNone = try report(players, dynamics: dynamics, arrows: [reading("Inf", "Junior", .none)])
        #expect(shape(readNone) == [["inf", "junior", "lead"]])
        #expect(notPlaced(readNone) == ["second": .influencersTaken])
    }

    @Test func theMostValuableGroupIsFormedFirst() throws {
        // Gains from Lead: Cole 72, Baker 48, Adams 24; by key Adams would come first.
        let players = [senior("Lead"), player("Adams", 18, [.professionalism: 16]),
                       player("Baker", 18, [.professionalism: 12]), player("Cole", 18, [.professionalism: 8])]
        let result = try report(players, dynamics: leader)
        #expect(shape(result) == [["baker", "cole", "lead"]])
        #expect(result.notPlaced == [NotPlaced(player: id("Adams"), name: "Adams", age: 18, reason: .influencersTaken)])
    }

    @Test func anInfluencerStillFreeIsNotCalledTaken() throws {
        // X leads Y and Z, who gain most; S is left free with K, and no third player is free to join them.
        let dynamics = levels(["X": .teamLeader, "S": .influential])
        let players = [senior("X"), senior("S"), player("Y", 18, [.professionalism: 1]),
                       player("Z", 18, [.professionalism: 1]), player("K", 18)]
        let sFree = try report(players, dynamics: dynamics)
        #expect(shape(sFree) == [["x", "y", "z"]])
        #expect(sFree.notPlaced == [NotPlaced(player: id("K"), name: "K", age: 18, reason: .noThirdFree)])
        #expect(sFree.notPlaced.map(AdvisorText.notPlaced)
                == ["K (18): no third player is left free who could join him and a player who could influence him "
                    + "without pulling a player down."])

        // Two more juniors who gain most give S a group too: then every player who could influence K is taken.
        let sTaken = try report(players + [player("W1", 18, [.professionalism: 1]), player("W2", 18, [.professionalism: 1])],
                                dynamics: dynamics)
        #expect(shape(sTaken) == [["w1", "w2", "x"], ["s", "y", "z"]])
        #expect(notPlaced(sTaken) == ["k": .influencersTaken])
    }

    @Test func anUnusedPlayerWhoseOwnArrowIsHarmfulCannotHelp() throws {
        // U is better than K in Professionalism and worse in Ambition by less: his Light arrow into K has a gain, but it
        // is harmful, so he can never be grouped with K. Only X, who is in a suggested group, could help K.
        let dynamics = levels(["X": .teamLeader, "U": .influential])
        let players = [senior("X"), senior("U", 30, [.ambition: 8]), player("Y", 18, [.professionalism: 1]),
                       player("Z", 18, [.professionalism: 1]), player("K", 18)]
        let result = try report(players, dynamics: dynamics)
        #expect(shape(result) == [["x", "y", "z"]])
        #expect(notPlaced(result) == ["k": .influencersTaken, "u": .noInfluence])
    }

    @Test func aHelperLeftFreeWithOnlyAHarmfulThirdHasNoThirdFree() throws {
        // X leads Y and Z; S could help K and T, but T's arrow into K is harmful, so the three left make no group.
        let dynamics = levels(["X": .teamLeader, "S": .influential])
        let players = [senior("X"), senior("S"), player("Y", 18, [.professionalism: 1]),
                       player("Z", 18, [.professionalism: 1]), player("K", 18), player("T", 18, [.professionalism: 5])]
        let result = try report(players, dynamics: dynamics, arrows: [reading("T", "K", .light)])
        #expect(shape(result) == [["x", "y", "z"]])
        #expect(notPlaced(result) == ["k": .noThirdFree, "t": .noThirdFree])
        #expect(result.notPlaced.map(AdvisorText.notPlaced) == [
            "K (18): no third player is left free who could join him and a player who could influence him "
                + "without pulling a player down.",
            "T (18): no third player is left free who could join him and a player who could influence him "
                + "without pulling a player down."])
    }

    @Test func tiesGoToFewerSeniorsThenMoreArrowsReadThenTheLowestKeys() throws {
        // Kid gains 60 from Lead, and Abel's 32 adds nothing beside it; Zane, at Others, gives and gains nothing. Lead
        // would harm K1 and K2 in Ambition; Abel leads them.
        let players = [senior("Lead", 34, [.ambition: 8]), senior("Abel", 30), player("Zane", 28, [.professionalism: 20]),
                       player("Kid", 18, [.ambition: 8]), player("K1", 18, [.professionalism: 15]),
                       player("K2", 18, [.professionalism: 15])]
        let seniors = try report(players, dynamics: levels(["Lead": .teamLeader, "Abel": .influential]))
        #expect(shape(seniors) == [["kid", "lead", "zane"], ["abel", "k1", "k2"]])

        // Ash and Bell are alike: at every ceiling, at Others and 28, they give and gain nothing.
        let thirds = [senior("Lead"), player("Kid", 18), player("Ash", 28, [.professionalism: 20]),
                      player("Bell", 28, [.professionalism: 20])]
        let byKey = try report(thirds, dynamics: leader)
        #expect(shape(byKey) == [["ash", "kid", "lead"]])
        let byReading = try report(thirds, dynamics: leader, arrows: [reading("Lead", "Bell", .none)])
        #expect(shape(byReading) == [["bell", "kid", "lead"]])
    }

    @Test func aSuggestionIsReadOnlyWhenEveryArrowItRestsOnWasRead() throws {
        let players = [senior("Lead"), player("A", 18), player("B", 18)]
        let both = try report(players, dynamics: leader,
                              arrows: [reading("Lead", "A", .average), reading("Lead", "B", .average)])
        #expect(both.suggestions.first?.isRead == true)
        let one = try report(players, dynamics: leader, arrows: [reading("Lead", "A", .average)])
        #expect(one.suggestions.first?.isRead == false)

        let bothAndNone = try report(players, dynamics: leader, arrows: [
            reading("Lead", "A", .average), reading("Lead", "B", .average), reading("A", "B", .none)])
        #expect(bothAndNone.suggestions == both.suggestions)
        let oneAndNone = try report(players, dynamics: leader,
                                    arrows: [reading("Lead", "A", .average), reading("A", "B", .none)])
        #expect(oneAndNone.suggestions == one.suggestions)
    }

    @Test func aSourceWhoWillGoCarriesTheCaution() throws {
        let juniors = [player("A", 18), player("B", 18)]
        let onLoan = try report([senior("Lead", club: "Banbury United")] + juniors, dynamics: leader)
        #expect(shape(onLoan) == [["a", "b", "lead"]])
        #expect(onLoan.suggestions.first?.cautions == [.onLoanHere(id("Lead"))])

        let going = try report([senior("Lead")] + juniors, dynamics: leader, leaving: [id("Lead")])
        #expect(going.suggestions.first?.cautions == [.advisedToLeave(id("Lead"))])

        let both = try report([senior("Lead", club: "Banbury United")] + juniors, dynamics: leader, leaving: [id("Lead")])
        #expect(both.suggestions.first?.cautions == [.onLoanHere(id("Lead")), .advisedToLeave(id("Lead"))])

        let thirdGoing = try report([senior("Lead"), player("Kid", 18), player("Going", 28, [.professionalism: 20])],
                                    dynamics: leader, leaving: [id("Going")])
        #expect(shape(thirdGoing) == [["going", "kid", "lead"]])
        #expect(thirdGoing.suggestions.first?.cautions == [])
    }

    @Test func aLoaneeOrALeaverIsNeverACandidateAndALoanedOutPlayerIsNowhere() throws {
        let loanee = player("Loanee", 18, club: "Banbury United"), leaver = player("Leaver", 18)
        let noCandidate = try report([senior("Lead"), loanee, leaver], dynamics: leader, leaving: [id("Leaver")])
        #expect(noCandidate.suggestions.isEmpty)
        #expect(noCandidate.notPlaced.isEmpty)

        let withKid = try report([senior("Lead"), loanee, leaver, player("Kid", 18)], dynamics: leader,
                                 leaving: [id("Leaver")])
        #expect(shape(withKid) == [["kid", "lead", "leaver"]])
        #expect(withKid.notPlaced.isEmpty)

        let leadAway = try report([senior("Lead", loanedTo: "Banbury United"), player("A", 18), player("B", 18)],
                                  dynamics: leader)
        #expect(leadAway.suggestions.isEmpty)
        #expect(notPlaced(leadAway) == ["a": .noInfluence, "b": .noInfluence])
        #expect(leadAway.needsHierarchy)

        let youngAway = try report([senior("Lead"), player("Away", 18, loanedTo: "Banbury United"), player("A", 18),
                                    player("B", 18)], dynamics: leader)
        #expect(shape(youngAway) == [["a", "b", "lead"]])
        #expect(youngAway.notPlaced.isEmpty)
    }

    @Test func aPlayerWhoTakesNothingSaysSo() throws {
        let players = [senior("Lead", 34), senior("S1"), senior("S2"), senior("S3"), player("Kid", 18)]
        let arrows = [reading("S1", "Kid", .none), reading("S2", "Kid", .none), reading("S3", "Kid", .none)]
        let three = try report(players, dynamics: levels(["Lead": .teamLeader, "S1": .influential,
                                                          "S2": .highlyInfluential, "S3": .influential]), arrows: arrows)
        #expect(three.suggestions.isEmpty)
        #expect(notPlaced(three) == ["kid": .takesNothing])

        let two = try report(players, dynamics: levels(["Lead": .teamLeader, "S1": .influential,
                                                        "S2": .highlyInfluential, "S3": .others]), arrows: arrows)
        #expect(shape(two) == [["kid", "lead", "s3"]])
        #expect(two.suggestions.first?.arrows.map(\.arrow) == [guessed("Lead", "Kid", .average)])
        #expect(two.notPlaced.isEmpty)
    }

    @Test func eachNotPlacedReason() throws {
        let takesNothing = try report(
            [senior("S1"), senior("S2"), senior("S3"), player("Kid", 18)],
            dynamics: levels(["S1": .influential, "S2": .influential, "S3": .influential]),
            arrows: [reading("S1", "Kid", .none), reading("S2", "Kid", .none), reading("S3", "Kid", .none)])
        #expect(notPlaced(takesNothing) == ["kid": .takesNothing])

        let noInfluence = try report([senior("Old"), player("A", 18), player("B", 18)])
        #expect(notPlaced(noInfluence) == ["a": .noInfluence, "b": .noInfluence])

        // Lead is guessed Average into both, and is worth no more than either anywhere.
        let nothingToGain = try report([player("Lead", 30), player("A", 18), player("B", 18)], dynamics: leader)
        #expect(nothingToGain.suggestions.isEmpty)
        #expect(notPlaced(nothingToGain) == ["a": .nothingToGain, "b": .nothingToGain, "lead": .noInfluence])

        // Lead is worse than both everywhere it counts: still nothing to gain, though his arrows would pull them down.
        let worseEverywhere = try report([player("Lead", 30, [.professionalism: 5, .ambition: 5]), player("A", 18),
                                          player("B", 18)], dynamics: leader)
        #expect(notPlaced(worseEverywhere) == ["a": .nothingToGain, "b": .nothingToGain, "lead": .noInfluence])

        // Lead is better in Ambition and worse in Professionalism by more: he gains them nothing and would pull them
        // down.
        let betterInOne = try report([player("Lead", 30, [.professionalism: 8, .ambition: 10]),
                                      player("A", 18, [.ambition: 5]), player("B", 18, [.ambition: 5])], dynamics: leader)
        #expect(betterInOne.suggestions.isEmpty)
        #expect(notPlaced(betterInOne) == ["a": .wouldHarm, "b": .wouldHarm, "lead": .noInfluence])

        let wouldHarm = try report([senior("Lead", 30, [.ambition: 6]), player("A", 18, [.ambition: 9]),
                                    player("B", 18, [.ambition: 9])], dynamics: leader)
        #expect(notPlaced(wouldHarm)["a"] == .wouldHarm)

        let taken = try report([senior("Lead"), player("A", 18), player("B", 18),
                                player("C", 18, [.professionalism: 15])], dynamics: leader)
        #expect(notPlaced(taken) == ["c": .influencersTaken])
    }

    @Test func aSquadWithNoLevelsNeedsItsHierarchyButArrowsReadStillCount() throws {
        let players = [senior("Eldest"), player("Kid", 18), player("Other", 19)]
        let none = try report(players)
        #expect(none.suggestions.isEmpty)
        #expect(none.needsHierarchy)

        let withReading = try report(players, arrows: [reading("Eldest", "Kid", .light)])
        #expect(withReading.needsHierarchy)
        #expect(shape(withReading) == [["eldest", "kid", "other"]])
        #expect(withReading.suggestions.first?.arrows == [
            GroupArrow(arrow: read("Eldest", "Kid", .light), fromName: "Eldest", toName: "Kid",
                       pulls: [Pull(attribute: .professionalism, value: 10, towards: 20)])])
        #expect(withReading.suggestions.first?.isRead == true)
    }

    @Test func aReadingForAnotherSquadOrAPlayerWhoHasGoneIsNotUsed() throws {
        let players = [senior("Lead", 34), senior("S1"), senior("S2"), senior("S3"), player("Kid", 18),
                       player("Kid Two", 18), senior("Away", 30, loanedTo: "Banbury United")]
        let dynamics = levels(["Lead": .teamLeader, "S1": .influential, "S2": .influential, "S3": .influential,
                               "Away": .influential, "Ghost": .influential])
        let base = [reading("S1", "Kid", .none), reading("S2", "Kid", .none)]
        let baseline = try report(players, dynamics: dynamics, arrows: base)
        func arrowsIntoKid(_ report: MentoringReport) -> [Arrow] {
            report.suggestions.flatMap(\.arrows).map(\.arrow).filter { $0.to == id("Kid") }
        }
        #expect(arrowsIntoKid(baseline) == [guessed("Lead", "Kid", .average)])

        // A third senior of the squad makes Kid one who takes nothing, so nothing is guessed into him: the readings
        // below would do the same if they were used.
        let third = try report(players, dynamics: dynamics, arrows: base + [reading("S3", "Kid", .none)])
        #expect(arrowsIntoKid(third).isEmpty)

        let otherSquad = ArrowReading(from: id("Lead"), to: id("Kid"), squad: .u21, strength: .none, readOn: today)
        for extra in [otherSquad, reading("Away", "Kid", .none), reading("Ghost", "Kid", .none)] {
            #expect(try report(players, dynamics: dynamics, arrows: base + [extra]) == baseline, "\(extra)")
        }

        // A reading above None into him would end his taking nothing, if it were used.
        let lightOtherSquad = ArrowReading(from: id("Lead"), to: id("Kid"), squad: .u21, strength: .light, readOn: today)
        for extra in [lightOtherSquad, reading("Away", "Kid", .light), reading("Ghost", "Kid", .light)] {
            let withLight = try report(players, dynamics: dynamics, arrows: base + [reading("S3", "Kid", .none), extra])
            #expect(arrowsIntoKid(withLight).isEmpty, "\(extra)")
            #expect(withLight == third, "\(extra)")
        }
    }

    @Test func arrowsBothWaysAndARingOfThree() throws {
        // Ann is better in Professionalism, Ben in Ambition.
        let pair = try report([player("Ann", 20, [.professionalism: 20, .ambition: 5]), player("Ben", 20),
                               player("Cal", 18)],
                              arrows: [reading("Ann", "Ben", .light), reading("Ben", "Ann", .light)])
        #expect(pair.suggestions.isEmpty)
        // Ben's arrow into Ann nets nothing, but would pull her down in Professionalism.
        #expect(notPlaced(pair) == ["ann": .wouldHarm, "ben": .wouldHarm, "cal": .noInfluence])

        let ring = try report([player("A", 18), player("B", 18), player("C", 18)],
                              arrows: [reading("A", "B", .light), reading("B", "C", .light), reading("C", "A", .light)])
        #expect(ring.suggestions.isEmpty)
        #expect(notPlaced(ring) == ["a": .nothingToGain, "b": .nothingToGain, "c": .nothingToGain])
    }

    @Test func fewerThanThreeFreePlayersSaySo() throws {
        let two = try report([senior("Lead"), player("Kid", 18)], dynamics: leader)
        #expect(two.suggestions.isEmpty)
        #expect(two.notPlaced == [NotPlaced(player: id("Kid"), name: "Kid", age: 18, reason: .tooFewFree)])
        #expect(two.notPlaced.map(AdvisorText.notPlaced) == ["Kid (18): there are not three players free to make a group with him."])

        let oneAway = try report([senior("Lead"), player("A", 18), player("B", 18, loanedTo: "Banbury United")],
                                 dynamics: leader)
        #expect(oneAway.suggestions.isEmpty)
        #expect(notPlaced(oneAway) == ["a": .tooFewFree])

        // The third player is in a recorded group: only two are free.
        let thirdRecorded = try report([senior("Lead"), player("Kid", 18), player("Taken", 18)], dynamics: leader,
                                       groups: [group(["taken", "x", "y"])])
        #expect(thirdRecorded.suggestions.isEmpty)
        #expect(notPlaced(thirdRecorded) == ["kid": .tooFewFree])

        // The only player with a gain to give is in a recorded group: no free player could help them.
        let leadRecorded = try report([senior("Lead"), player("A", 18), player("B", 18)], dynamics: leader,
                                      groups: [group(["lead", "x", "y"])])
        #expect(leadRecorded.suggestions.isEmpty)
        #expect(notPlaced(leadRecorded) == ["a": .influencersTaken, "b": .influencersTaken])

        // Exactly three free, and the only group of three holds a harmful arrow.
        let threeHarmful = try report([senior("Lead", 30, [.ambition: 6]), player("A", 18, [.ambition: 9]),
                                       player("B", 18, [.ambition: 9])], dynamics: leader)
        #expect(threeHarmful.suggestions.isEmpty)
        #expect(notPlaced(threeHarmful) == ["a": .wouldHarm, "b": .wouldHarm, "lead": .noInfluence])
    }

    @Test func aPlayerAtEveryCeilingAppearsNowhere() throws {
        let atCeiling: [Attribute: Int] = [.professionalism: 20, .pressure: 6, .determination: 10, .ambition: 10]
        let third = player("Other", 28, [.professionalism: 20])
        let full = try report([senior("Lead"), player("Done", 19, atCeiling), third], dynamics: leader)
        #expect(full.suggestions.isEmpty)
        #expect(full.notPlaced.isEmpty)

        let oneShort = try report([senior("Lead"), player("Done", 19, atCeiling.merging([.professionalism: 19]) { _, new in new }),
                                   third], dynamics: leader)
        #expect(shape(oneShort) == [["done", "lead", "other"]])
    }

    @Test func membersOfARecordedGroupAreLeftOut() throws {
        let players = [senior("Lead"), player("A", 18), player("B", 18)]
        let live = try report(players, dynamics: leader, groups: [group(["lead", "x", "y"])])
        #expect(live.suggestions.isEmpty)
        #expect(notPlaced(live) == ["a": .influencersTaken, "b": .influencersTaken])

        let otherSquad = try report(players, dynamics: leader, groups: [group(["lead", "x", "y"], squad: .u21)])
        #expect(otherSquad.suggestions.isEmpty)

        let recordedJunior = try report(players + [player("C", 18)], dynamics: leader, groups: [group(["c", "x", "y"])])
        #expect(shape(recordedJunior) == [["a", "b", "lead"]])
        #expect(recordedJunior.notPlaced.isEmpty)

        let ended = try report(players, dynamics: leader, groups: [group(["lead", "x", "y"], endedOn: today.adding(days: -1))])
        #expect(shape(ended) == [["a", "b", "lead"]])

        let left = try report(players, dynamics: leader,
                              groups: [group(["lead", "x", "y"], leftOn: ["lead": today.adding(days: -1)])])
        #expect(shape(left) == [["a", "b", "lead"]])
    }

    @Test func notPlacedIsByKey() throws {
        let result = try report([player("Cid", 18), player("Abe", 19), player("Bo", 17)])
        #expect(result.notPlaced.map(\.player.key) == ["abe", "bo", "cid"])
    }

    @Test func staleAfterFourWeeks() throws {
        let players = [senior("Lead"), player("A", 18)]
        #expect(try report(players, updatedOn: today.adding(days: -29)).isStale)
        #expect(try !report(players, updatedOn: today.adding(days: -28)).isStale)
        #expect(try !report(players, updatedOn: nil).isStale)
    }

    // MARK: Errors

    @Test func aMissingCountedValueIsAnErrorNamingThePlayer() throws {
        var noPressure = player("Bravo", 18)
        noPressure.attributes[.pressure] = nil
        #expect(throws: RatingError.missingAttribute(player: "Bravo", attribute: .pressure)) {
            try report([senior(), noPressure])
        }

        var away = noPressure
        away.loanedTo = "Banbury United"
        _ = try report([senior(), away])

        var noLoyalty = player("Bravo", 18)
        noLoyalty.attributes[.loyalty] = nil
        _ = try report([senior(), noLoyalty])

        var otherSquad = noPressure
        otherSquad.squad = .u21
        _ = try report([senior(), otherSquad])

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
        #expect(throws: PlanError.badParameters(problems)) { try report([senior(), player("A", 18)], parameters: bad) }

        // Bad parameters are found before any player is read.
        var noPressure = player("A", 18)
        noPressure.attributes[.pressure] = nil
        #expect(throws: PlanError.badParameters(problems)) { try report([noPressure], parameters: bad) }
    }

    // MARK: Regrouping

    /// A player of 30 with every attribute 10: nobody is guessed to influence him, and he has nothing to give a
    /// player left at 10.
    func veteran(_ name: String) -> Player { player(name, 30) }

    /// Each group the regrouping would make, as its three keys.
    func regrouped(_ report: MentoringReport) -> [[String]]? {
        report.regrouping?.groups.map { $0.members.map(\.player.key) }
    }

    @Test func aRecordedGroupWhosePlayersWouldDoClearlyMoreElsewhereIsRegrouped() throws {
        // Lead sits with two veterans he gives nothing; the two juniors free would each gain from him.
        let recorded = group(["lead", "old", "vet"])
        let players = [senior("Lead"), veteran("Vet"), veteran("Old"), player("A", 18), player("B", 18)]
        let result = try report(players, dynamics: leader, groups: [recorded])
        #expect(result.suggestions.isEmpty)
        let regrouping = try #require(result.regrouping)
        #expect(regrouping.breakUp == [recorded.id])
        #expect(regrouped(result) == [["a", "b", "lead"]])
        #expect(regrouping.leftOut == [SuggestedMember(player: id("Old"), name: "Old", age: 30),
                                       SuggestedMember(player: id("Vet"), name: "Vet", age: 30)])
        #expect(!regrouping.isRead)
        #expect(regrouping.basis == .derived)

        // It is read once the arrows the new group rests on and the six of the group broken up are all read.
        let six = ["Lead", "Old", "Vet"].flatMap { from in
            ["Lead", "Old", "Vet"].filter { $0 != from }.map { reading(from, $0, .none) }
        }
        let read = try report(players, dynamics: leader, groups: [recorded],
                              arrows: six + [reading("Lead", "A", .average), reading("Lead", "B", .average)])
        #expect(read.regrouping?.isRead == true)
    }

    @Test func aRegroupingMustBeWorthHalfAsMuchAgain() throws {
        // The recorded group gives A 60 and Near 24: 84. With B in Near's place it would give 120, under 1.5 times.
        let recorded = group(["a", "lead", "near"])
        let near = [senior("Lead"), player("A", 18), player("Near", 18, [.professionalism: 16]), player("B", 18)]
        #expect(try report(near, dynamics: leader, groups: [recorded]).regrouping == nil)

        // Near one higher gains 18: 78, and 120 is over 1.5 times that.
        let further = [senior("Lead"), player("A", 18), player("Near", 18, [.professionalism: 17]), player("B", 18)]
        let result = try report(further, dynamics: leader, groups: [recorded])
        #expect(regrouped(result) == [["a", "b", "lead"]])
        #expect(result.regrouping?.leftOut.map(\.player) == [id("Near")])

        // The factor is the parameter's.
        var looser = q
        looser.mentoringRegroupFactor = Parameter(1.4, .derived, source: "test")
        #expect(regrouped(try report(near, dynamics: leader, groups: [recorded], parameters: looser)) == [["a", "b", "lead"]])
    }

    @Test func aRecordedGroupAsGoodAsAnyOtherIsLeftAlone() throws {
        let recorded = group(["a", "b", "lead"])
        let players = [senior("Lead"), player("A", 18), player("B", 18), player("C", 18), veteran("Vet")]
        #expect(try report(players, dynamics: leader, groups: [recorded]).regrouping == nil)
        // With no group recorded there is nothing to regroup.
        #expect(try report(players, dynamics: leader).regrouping == nil)
    }

    @Test func twoGroupsAreBrokenUpTogetherWhenNeitherAloneWouldDo() throws {
        // The senior is in one group and the two juniors in the other; nobody is free.
        let seniors = group(["lead", "vet", "vic"]), juniors = group(["a", "b", "old"])
        let players = [senior("Lead"), veteran("Vet"), veteran("Vic"), player("A", 18), player("B", 18), veteran("Old")]
        let result = try report(players, dynamics: leader, groups: [seniors, juniors])
        let regrouping = try #require(result.regrouping)
        #expect(Set(regrouping.breakUp) == [seniors.id, juniors.id])
        #expect(regrouping.breakUp == result.groups.map(\.id))
        #expect(regrouped(result) == [["a", "b", "lead"]])
        #expect(regrouping.leftOut.map(\.player.key) == ["old", "vet", "vic"])
    }

    @Test func oneGroupIsBrokenUpRatherThanTwoForTheSameGain() throws {
        // Lead's group gives nothing, and A and B are free: breaking up the veterans' group as well adds nothing.
        let leads = group(["lead", "vet", "vic"]), others = group(["old", "olly", "otto"])
        let players = [senior("Lead"), veteran("Vet"), veteran("Vic"), veteran("Old"), veteran("Olly"), veteran("Otto"),
                       player("A", 18), player("B", 18)]
        let result = try report(players, dynamics: leader, groups: [others, leads])
        #expect(result.regrouping?.breakUp == [leads.id])
        #expect(regrouped(result) == [["a", "b", "lead"]])
    }

    @Test func theRegroupingWithTheGreatestGainIsTheOneShown() throws {
        // Either senior could take the two free juniors; Lead, at Professionalism 20, gives them more than Second at 15.
        let first = group(["second", "vet", "vic"]), second = group(["lead", "old", "olly"])
        let players = [senior("Lead"), senior("Second", 30, [.professionalism: 15]), veteran("Vet"), veteran("Vic"),
                       veteran("Old"), veteran("Olly"), player("A", 18), player("B", 18)]
        let result = try report(players, dynamics: levels(["Lead": .teamLeader, "Second": .teamLeader]),
                                groups: [first, second])
        #expect(result.regrouping?.breakUp == [second.id])
        #expect(regrouped(result) == [["a", "b", "lead"]])
    }

    @Test func aGroupWithAHarmfulArrowCountsForNothing() throws {
        // Lead's Ambition 6 is below Hale's: the arrow guessed into Hale is harmful, so the recorded group counts for
        // nothing, though Kid in it gains. B, free, makes a group with Lead and Kid that harms nobody.
        let recorded = group(["hale", "kid", "lead"])
        let players = [senior("Lead", 30, [.ambition: 6]), player("Hale", 18, [.ambition: 13]),
                       player("Kid", 18, [.ambition: 6]), player("B", 18, [.ambition: 6])]
        let result = try report(players, dynamics: leader, groups: [recorded])
        #expect(result.groups.first?.gain == .toAMember)
        #expect(regrouped(result) == [["b", "kid", "lead"]])
        #expect(result.regrouping?.leftOut.map(\.player) == [id("Hale")])
    }

    @Test func aRegroupingLeavesTheSuggestedGroupsAsTheyAre() throws {
        // C and D are suggested with Second; Lead's group gives nothing, and nobody else is free to join him.
        let recorded = group(["lead", "vet", "vic"])
        let players = [senior("Lead"), veteran("Vet"), veteran("Vic"), senior("Second"), player("C", 18), player("D", 18)]
        let both = levels(["Lead": .teamLeader, "Second": .teamLeader])
        let taken = try report(players, dynamics: both, groups: [recorded])
        #expect(shape(taken) == [["c", "d", "second"]])
        #expect(taken.regrouping == nil)

        // E is in no suggestion: he is free for Lead.
        let spare = try report(players + [player("E", 18)], dynamics: both, groups: [recorded])
        #expect(shape(spare) == [["c", "d", "second"]])
        #expect(regrouped(spare) == [["e", "lead", "vet"]])
        #expect(spare.regrouping?.leftOut.map(\.player) == [id("Vic")])
    }

    @Test func aGroupWhoseGainIsNotKnownIsNeverBrokenUp() throws {
        // No level is entered, so the recorded group's unread arrows are all guessed None and say nothing. One arrow
        // was read from its Lead into a free junior, who with another free player would make a group.
        let recorded = group(["lead", "vet", "vic"])
        let players = [senior("Lead"), veteran("Vet"), veteran("Vic"), player("A", 18), player("B", 18)]
        let read = [reading("Lead", "A", .light)]
        let unknown = try report(players, groups: [recorded], arrows: read)
        #expect(unknown.groups.first?.gain == .notKnown)
        #expect(unknown.regrouping == nil)

        // Its six arrows read as None: it is known to give nothing, and is broken up.
        let none = ["Lead", "Vet", "Vic"].flatMap { from in
            ["Lead", "Vet", "Vic"].filter { $0 != from }.map { reading(from, $0, .none) }
        }
        let known = try report(players, groups: [recorded], arrows: read + none)
        #expect(known.groups.first?.gain == .toNobody)
        // A gains from Lead with either third player; Vet's arrows with Lead were read, B's were not.
        #expect(regrouped(known) == [["a", "lead", "vet"]])
        #expect(known.regrouping?.isRead == true)
    }

    @Test func aRegroupingRestsOnAGuessWhenTheGroupItBreaksUpDoes() throws {
        // The new group rests on two read arrows; the recorded group's own six are still guesses.
        let recorded = group(["lead", "old", "vet"])
        let players = [senior("Lead"), veteran("Vet"), veteran("Old"), player("A", 18), player("B", 18)]
        let arrows = [reading("Lead", "A", .average), reading("Lead", "B", .average)]
        let guessed = try report(players, dynamics: leader, groups: [recorded], arrows: arrows)
        #expect(guessed.regrouping?.groups.allSatisfy(\.isRead) == true)
        #expect(guessed.regrouping?.isRead == false)
    }

    @Test func onlyThisSquadsGroupsAndPresentMembersAreRegrouped() throws {
        let players = [senior("Lead"), veteran("Vet"), player("A", 18), player("B", 18)]
        // A member no longer imported is neither regrouped nor listed as left out.
        let recorded = group(["gone", "lead", "vet"])
        let result = try report(players, dynamics: leader, groups: [recorded])
        #expect(regrouped(result) == [["a", "b", "lead"]])
        #expect(result.regrouping?.leftOut.map(\.player) == [id("Vet")])

        // Another squad's group, though it holds this squad's players, is not this report's to break up.
        let elsewhere = try report(players, dynamics: leader, groups: [group(["gone", "lead", "vet"], squad: .u21)])
        #expect(elsewhere.regrouping == nil)
        // Nor an ended one: its players are free, and are suggested.
        let ended = try report(players, dynamics: leader,
                               groups: [group(["gone", "lead", "vet"], endedOn: today.adding(days: -1))])
        #expect(ended.regrouping == nil)
        #expect(shape(ended) == [["a", "b", "lead"]])
    }

    // MARK: Scope and order

    @Test func onlyTheSquadAskedForIsLookedAt() throws {
        let players = [senior("Lead"), player("A", 18, squad: .u21), player("B", 18, squad: .u21)]
        let u21 = try report(players, squad: .u21, dynamics: leader)
        #expect(u21.squad == .u21)
        #expect(u21.suggestions.isEmpty)
        #expect(notPlaced(u21) == ["a": .noInfluence, "b": .noInfluence])
        #expect(u21.needsHierarchy)

        let firstTeam = try report(players, dynamics: leader)
        #expect(firstTeam.suggestions.isEmpty)
        #expect(firstTeam.notPlaced.isEmpty)
        #expect(!firstTeam.needsHierarchy)
    }

    @Test func inputOrderDoesNotMatter() throws {
        let players = [senior("Lead", 34), senior("Second", 33, [.pressure: 3]), senior("Abel", 30),
                       player("Kid A", 16, [.ambition: 9]), player("Kid B", 16, [.ambition: 9]),
                       player("A", 18), player("B", 19, [.professionalism: 12]), player("C", 20, [.pressure: 2]),
                       player("D", 18, [.determination: 4]), player("E", 22), player("Making Up", 28),
                       player("Recorded", 18), player("Loanee", 19, club: "Banbury United")]
        let groups = [group(["recorded", "x", "y"]), group(["second", "z", "w"], endedOn: today)]
        let dynamics = levels(["Lead": .teamLeader, "Second": .highlyInfluential, "Abel": .influential])
        let arrows = [reading("Abel", "Kid A", .significant), reading("Lead", "E", .none), reading("Second", "C", .light),
                      reading("Lead", "Making Up", .light), reading("Abel", "D", .average)]
        let forward = try report(players, dynamics: dynamics, groups: groups, arrows: arrows)
        #expect(forward.suggestions.count >= 2)
        #expect(!forward.notPlaced.isEmpty)
        #expect(try report(Array(players.reversed()), dynamics: dynamics, groups: Array(groups.reversed()),
                           arrows: Array(arrows.reversed())) == forward)
        let shuffled = [7, 2, 11, 0, 9, 4, 12, 1, 6, 3, 10, 5, 8].map { players[$0] }
        let shuffledArrows = [3, 0, 4, 2, 1].map { arrows[$0] }
        #expect(try report(shuffled, dynamics: dynamics, groups: groups, arrows: shuffledArrows) == forward)
    }

    @Test func anInjuredPlayerIsTreatedLikeAnyOther() throws {
        let fit = try report([senior("Lead"), player("A", 18), player("B", 18)], dynamics: leader)
        let injured = try report([senior("Lead", isInjured: true), player("A", 18, isInjured: true), player("B", 18)],
                                 dynamics: leader)
        #expect(shape(fit) == [["a", "b", "lead"]])
        #expect(injured == fit)
    }
}
