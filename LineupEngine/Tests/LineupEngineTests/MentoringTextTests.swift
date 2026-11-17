import Foundation
import Testing
@testable import LineupEngine

@Suite struct MentoringTextTests {
    let parameters = EngineParameters.fm27
    let hart = PlayerID(key: "hart"), young = PlayerID(key: "young"), reid = PlayerID(key: "reid")
    let names: [PlayerID: String] = [PlayerID(key: "hart"): "Hart", PlayerID(key: "young"): "Young",
                                     PlayerID(key: "reid"): "Reid"]

    @Test func standingsAndSocialGroupsHaveTheirNames() {
        #expect(Standing.allCases.map { AdvisorText.name($0) }
                == ["Others", "Influential", "Highly Influential", "Team Leader"])
        #expect(AdvisorText.name(SocialGroup.core) == "Core")
        #expect(AdvisorText.name(SocialGroup.secondary("A")) == "Secondary A")
        #expect(AdvisorText.name(SocialGroup.secondary("B")) == "Secondary B")
        #expect(AdvisorText.name(SocialGroup.others) == "Others")
    }

    @Test func theStandingSentences() {
        #expect(AdvisorText.mentoringNote == "How fast mentoring works in FM27 has not been measured. An arrow is the "
                + "game's own where it has been read, and this tool's guess where it says expected.")
        #expect(AdvisorText.mentoringNeedsHierarchy == "Enter this squad's hierarchy first: mentoring needs each "
                + "player's level, and age alone creates no influence.")
        #expect(AdvisorText.noGroupToSuggest == "No group to suggest.")
        #expect(AdvisorText.expectedNotRead == "expected, not read")
        #expect(AdvisorText.nothingToGain == "nothing to gain")
        #expect(AdvisorText.setAndRecordArrows == "Set this group in the game and record its arrows.")
        #expect(AdvisorText.noReadingYet == "No reading yet: values are read at each import")
    }

    @Test func strengthsHaveTheGamesWords() {
        #expect(ArrowStrength.allCases.map { AdvisorText.name($0) } == ["None", "Light", "Average", "Significant"])
    }

    func report(_ squad: Squad, isStale: Bool) -> MentoringReport {
        MentoringReport(squad: squad, needsHierarchy: false, isStale: isStale, suggestions: [], notPlaced: [], groups: [],
                        regrouping: nil, basis: .derived)
    }

    @Test func aStaleHierarchyPointsToWhereToCheckIt() {
        let asOf = Day(year: 2026, month: 11, day: 14)!
        let updated = Day(year: 2026, month: 10, day: 3)!   // 42 days
        #expect(AdvisorText.staleHierarchy(report(.firstTeam, isStale: true), updatedOn: updated, asOf: asOf)
                == "The hierarchy was last updated 6 weeks ago. Check it against the game's Dynamics screen.")
        #expect(AdvisorText.staleHierarchy(report(.u21, isStale: true), updatedOn: updated, asOf: asOf)
                == "The hierarchy was last updated 6 weeks ago. Check it against each player's own page in the game.")
        #expect(AdvisorText.staleHierarchy(report(.u18, isStale: true), updatedOn: updated, asOf: asOf)
                == "The hierarchy was last updated 6 weeks ago. Check it against each player's own page in the game.")
        let oneWeek = Day(year: 2026, month: 11, day: 6)!
        #expect(AdvisorText.staleHierarchy(report(.firstTeam, isStale: true), updatedOn: oneWeek, asOf: asOf)?
            .hasPrefix("The hierarchy was last updated 1 week ago.") == true)
        #expect(AdvisorText.staleHierarchy(report(.firstTeam, isStale: false), updatedOn: updated, asOf: asOf) == nil)
        #expect(AdvisorText.staleHierarchy(report(.u21, isStale: false), updatedOn: updated, asOf: asOf) == nil)
    }

    @Test func aSuggestedGroupSentences() {
        let arrow = GroupArrow(arrow: Arrow(from: PlayerID(key: "mceachran"), to: PlayerID(key: "clark"), strength: .light,
                                            readOn: nil),
                               fromName: "McEachran", toName: "Clark", pulls: [])
        #expect(AdvisorText.arrowTitle(arrow) == "McEachran → Clark")
        #expect(AdvisorText.pull(Pull(attribute: .professionalism, value: 8, towards: 17))
                == "Professionalism 8, towards 17")
        #expect(AdvisorText.caution(.onLoanHere(hart), names: names) == "Hart is on loan here: the group ends when he goes back.")
        #expect(AdvisorText.caution(.advisedToLeave(hart), names: names) == "Hart is advised to leave: the group ends when he goes.")
        #expect(AdvisorText.caution(.onLoanHere(PlayerID(key: "fmrte:123")), names: names)
                == "A player is on loan here: the group ends when he goes back.")
        #expect(AdvisorText.caution(.advisedToLeave(PlayerID(key: "fmrte:123")), names: [:])
                == "A player is advised to leave: the group ends when he goes.")
        let fell = [AttributeChange(attribute: .professionalism, start: 13, latest: 12, weeks: 5, change: .worse),
                    AttributeChange(attribute: .ambition, start: 10, latest: 8, weeks: 5, change: .worse)]
        #expect(AdvisorText.caution(.fell(hart, with: reid, changes: [fell[0]]), names: names)
                == "Hart's Professionalism fell from 13 to 12 in a group with Reid that you ended. What caused it is not known.")
        #expect(AdvisorText.caution(.fell(hart, with: reid, changes: fell), names: names)
                == "Hart's Professionalism fell from 13 to 12 and Ambition fell from 10 to 8 in a group with Reid that you "
                + "ended. What caused it is not known.")
        #expect(AdvisorText.caution(.fell(PlayerID(key: "fmrte:1"), with: PlayerID(key: "fmrte:2"), changes: [fell[0]]),
                                    names: [:])
                == "A player's Professionalism fell from 13 to 12 in a group with another player that you ended. What "
                + "caused it is not known.")
    }

    @Test func eachNotPlacedReasonHasItsOwnSentence() {
        func sentence(_ reason: NotPlacedReason) -> String {
            AdvisorText.notPlaced(NotPlaced(player: PlayerID(key: "dunn"), name: "Dunn", age: 17, reason: reason))
        }
        #expect(sentence(.takesNothing) == "Dunn (17): he has taken nothing from the players tried with him so far.")
        #expect(sentence(.noInfluence) == "Dunn (17): nobody in this squad is expected to influence him.")
        #expect(sentence(.nothingToGain) == "Dunn (17): nobody who influences him is better where it counts.")
        #expect(sentence(.tooFewFree) == "Dunn (17): there are not three players free to make a group with him.")
        #expect(sentence(.wouldHarm) == "Dunn (17): every group that would help him would pull a player down.")
        #expect(sentence(.noThirdFree) == "Dunn (17): no third player is left free who could join him and a player "
                + "who could influence him without pulling a player down.")
        #expect(sentence(.groupEnded) == "Dunn (17): every group that would help him is one you ended while it was "
                + "doing harm or had stopped working.")
        #expect(sentence(.influencersTaken) == "Dunn (17): the players who could influence him are already in a group.")
    }

    @Test func eachWarningHasItsOwnSentence() {
        func sentence(_ warning: GroupWarning) -> String { AdvisorText.warning(warning, names: names) }
        let ashby = PlayerID(key: "ashby"), nelson = PlayerID(key: "nelson")
        let both: [PlayerID: String] = [ashby: "Ashby", nelson: "Nelson"]
        #expect(AdvisorText.warning(.harmfulArrow(from: ashby, to: nelson, strength: .significant, isRead: true,
                                                  attribute: .ambition, fromValue: 6, toValue: 13), names: both)
                == "Ashby's influence on Nelson is Significant, and Ashby's Ambition is 6 against Nelson's 13.")
        #expect(AdvisorText.warning(.harmfulArrow(from: ashby, to: nelson, strength: .average, isRead: false,
                                                  attribute: .ambition, fromValue: 6, toValue: 13), names: both)
                == "Ashby's influence on Nelson is expected to be Average, and Ashby's Ambition is 6 against Nelson's 13.")
        #expect(sentence(.harmfulArrow(from: hart, to: reid, strength: .light, isRead: true, attribute: .professionalism,
                                       fromValue: 9, toValue: 14))
                == "Hart's influence on Reid is Light, and Hart's Professionalism is 9 against Reid's 14.")
        #expect(sentence(.notInSquad(young)) == "Young is no longer in the squad.")
        #expect(sentence(.outOnLoan(young, club: "Luton")) == "Young is out on loan at Luton.")
        #expect(sentence(.advisedToLeave(hart)) == "Hart is advised to leave.")
        #expect(AdvisorText.warning(.notInSquad(PlayerID(key: "gone")), names: names) == "gone is no longer in the squad.")
    }

    func change(_ attribute: Attribute, _ start: Int?, _ latest: Int?, weeks: Double, _ kind: ValueChange) -> AttributeChange {
        AttributeChange(attribute: attribute, start: start, latest: latest, weeks: weeks, change: kind)
    }

    @Test func whatChangedReadsPlainly() {
        #expect(AdvisorText.change(change(.professionalism, 9, 10, weeks: 5, .improved)) == "Professionalism 9 to 10 in 5 weeks")
        #expect(AdvisorText.change(change(.professionalism, 9, 10, weeks: 1, .improved)) == "Professionalism 9 to 10 in 1 week")
        #expect(AdvisorText.change(change(.professionalism, 9, 10, weeks: 3.0 / 7, .improved))
                == "Professionalism 9 to 10 in under a week")
        #expect(AdvisorText.change(change(.professionalism, 10, 8, weeks: 0, .worse))
                == "Professionalism 10 to 8 in under a week")
        #expect(AdvisorText.change(change(.pressure, 5, 5, weeks: 5, .noChange)) == "Pressure 5, no change")
        #expect(AdvisorText.change(change(.professionalism, 10, 8, weeks: 4, .worse)) == "Professionalism 10 to 8 in 4 weeks")
        #expect(AdvisorText.change(change(.pressure, 14, 13, weeks: 5, .noChange)) == "Pressure 14 to 13, above where it counts")
        #expect(AdvisorText.change(change(.pressure, nil, nil, weeks: 0, .noReading)) == nil)
    }

    func review(harm: Bool = false, noInfluence: Bool = false, stopped: Bool = false, unread: Int = 0,
                gain: GroupGain = .toAMember) -> GroupReview {
        let group = MentoringGroup(id: UUID(), squad: .firstTeam, startedOn: Day(year: 2026, month: 9, day: 1)!, members: [])
        return GroupReview(group: group, members: [], arrows: [], unreadArrows: unread, hasNoInfluence: noInfluence,
                           gain: gain, warnings: [], isDoingHarm: harm, hasStoppedWorking: stopped, basis: .derived)
    }

    @Test func aGroupDoingHarmOrStoppedSaysSoAndOtherwiseNothing() {
        let harm = "This group is doing harm: a member is worth less than when he joined. Consider regrouping."
        let none = "The game shows no influence in this group: all six arrows are None. Consider regrouping."
        #expect(AdvisorText.state(of: review(harm: true), parameters: parameters) == harm)
        // Doing harm comes first: a group can be both.
        #expect(AdvisorText.state(of: review(harm: true, noInfluence: true), parameters: parameters) == harm)
        #expect(AdvisorText.state(of: review(noInfluence: true), parameters: parameters) == none)
        #expect(AdvisorText.state(of: review(stopped: true), parameters: parameters)
                == "This group has stopped working: nobody it influences has changed in 13 weeks. Consider regrouping.")
        var eight = parameters
        eight.mentoringStoppedAfterWeeks = Parameter(8, .derived, source: "test")
        #expect(AdvisorText.state(of: review(stopped: true), parameters: eight)
                == "This group has stopped working: nobody it influences has changed in 8 weeks. Consider regrouping.")
        #expect(AdvisorText.state(of: review(), parameters: parameters) == nil)
        #expect(AdvisorText.state(of: review(unread: 4), parameters: parameters) == nil)
    }

    @Test func aGroupThatGivesNothingSaysToBreakItUp() {
        let nobody = "Nobody in this group has anything to gain from it. Break it up."
        #expect(AdvisorText.state(of: review(gain: .toNobody), parameters: parameters) == nobody)
        #expect(AdvisorText.state(of: review(gain: .onlyToAMemberWhoWillGo), parameters: parameters)
                == "Only a player on loan here or advised to leave gains from this group. Break it up.")
        // While an arrow is still a guess it is what this tool expects, and reading the arrows comes first.
        #expect(AdvisorText.state(of: review(unread: 2, gain: .toNobody), parameters: parameters)
                == "Nobody in this group is expected to gain anything from it. Record its arrows to check, or break it up.")
        #expect(AdvisorText.state(of: review(unread: 1, gain: .onlyToAMemberWhoWillGo), parameters: parameters)
                == "Only a player on loan here or advised to leave is expected to gain from this group. "
                + "Record its arrows to check, or break it up.")
        // Doing harm and showing no influence are said first; that it has stopped is not said as well.
        #expect(AdvisorText.state(of: review(harm: true, gain: .toNobody), parameters: parameters)
                == "This group is doing harm: a member is worth less than when he joined. Consider regrouping.")
        #expect(AdvisorText.state(of: review(noInfluence: true, gain: .toNobody), parameters: parameters)
                == "The game shows no influence in this group: all six arrows are None. Consider regrouping.")
        #expect(AdvisorText.state(of: review(stopped: true, gain: .toNobody), parameters: parameters) == nobody)
        // Not known, with no hierarchy to guess from: nothing is said.
        #expect(AdvisorText.state(of: review(unread: 6, gain: .notKnown), parameters: parameters) == nil)
        // That it has stopped is still said of a group whose gain is not known.
        #expect(AdvisorText.state(of: review(stopped: true, unread: 3, gain: .notKnown), parameters: parameters)
                == "This group has stopped working: nobody it influences has changed in 13 weeks. Consider regrouping.")
    }

    func suggested(_ names: [String], isRead: Bool) -> SuggestedGroup {
        SuggestedGroup(members: names.map { SuggestedMember(player: PlayerID(key: $0.lowercased()), name: $0, age: 18) },
                       arrows: [], isRead: isRead, cautions: [], basis: .derived)
    }

    func regrouping(_ groups: [SuggestedGroup], breakUp: Int = 1, leftOut: [String] = [], isRead: Bool = true) -> Regrouping {
        Regrouping(breakUp: (0..<breakUp).map { _ in UUID() }, groups: groups,
                   leftOut: leftOut.map { SuggestedMember(player: PlayerID(key: $0.lowercased()), name: $0, age: 30) },
                   isRead: isRead, basis: .derived)
    }

    @Test func aRegroupingSaysWhatToBreakUpAndWhatItRestsOn() {
        let one = regrouping([suggested(["Hart", "Young", "Reid"], isRead: true)])
        #expect(one.isRead)
        #expect(AdvisorText.regrouping(one, breakingUp: [["Hart", "Okafor", "Lane"]])
                == ["Breaking up Hart, Okafor and Lane's group and making this one may do more for your players."])

        let two = regrouping([suggested(["Hart", "Young", "Reid"], isRead: true),
                              suggested(["Okafor", "Pike", "Cole"], isRead: false)], breakUp: 2, leftOut: ["Lane"],
                             isRead: false)
        #expect(!two.isRead)
        #expect(AdvisorText.regrouping(two, breakingUp: [["Hart", "Okafor", "Lane"], ["Young", "Reid", "Pike"]]) == [
            "Breaking up Hart, Okafor and Lane's group and Young, Reid and Pike's and making these may do more for your "
                + "players.",
            "Lane would be left in no group.",
            "It rests on arrows this tool expects and has not read: the game may show them differently."])

        let more = regrouping([suggested(["Hart", "Young", "Reid"], isRead: true)], leftOut: ["Lane", "Vic", "Old"])
        #expect(AdvisorText.regrouping(more, breakingUp: [["Hart", "Lane"]]) == [
            "Breaking up Hart and Lane's group and making this one may do more for your players.",
            "Lane, Vic and Old would be left in no group."])
    }

    @Test func aGroupToBreakUpSaysSoOnItsCard() {
        #expect(AdvisorText.regroup(alongside: [])
                == "These players may do more in other groups: this tool would break this group up.")
        #expect(AdvisorText.regroup(alongside: ["Okafor", "Lane", "Pike"])
                == "These players may do more in other groups: this tool would break this group up, and Okafor, Lane and "
                + "Pike's with it.")
    }

    @Test func arrowsStillToReadAreCounted() {
        #expect(AdvisorText.arrowsToRead(review(unread: 0)) == nil)
        #expect(AdvisorText.arrowsToRead(review(unread: 1))
                == "Record this group's arrows from the game: 1 is still a guess. An arrow expected to be None is not listed.")
        #expect(AdvisorText.arrowsToRead(review(unread: 5))
                == "Record this group's arrows from the game: 5 are still guesses. An arrow expected to be None is not listed.")
        #expect(AdvisorText.arrowsToRead(review(noInfluence: true)) == nil)
    }

    @Test func socialGroupsAreNotUsed() {
        #expect(AdvisorText.socialGroupsNotUsed == "Social groups are kept as entered. They do not change the advice.")
    }

    @Test func recordingAGroupSaysToSetItInTheGame() {
        #expect(AdvisorText.recorded(names: ["Hart", "Young", "Reid"])
                == "Hart, Young and Reid are recorded as a group from today. Set it in the game as well.")
    }
}
