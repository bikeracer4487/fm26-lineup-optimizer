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
        #expect(AdvisorText.mentoringNote == "How fast mentoring works in FM27 has not been measured. "
                + "These groups follow the rules of earlier versions.")
        #expect(AdvisorText.mentoringByAgeAlone == "No hierarchy entered for this squad: these groups go by age alone.")
        #expect(AdvisorText.noGroupToSuggest == "No group to suggest.")
        #expect(AdvisorText.makingUpTheGroup == "Making up the group")
        #expect(AdvisorText.noReadingYet == "No reading yet: values are read at each import")
    }

    func report(_ squad: Squad, isStale: Bool) -> MentoringReport {
        MentoringReport(squad: squad, byAgeAlone: false, isStale: isStale, suggestions: [], notPlaced: [], groups: [],
                        basis: .derived)
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
        let group = SuggestedGroup(lead: hart, leadName: "Hart", leadAge: 34, leadStanding: .teamLeader, members: [],
                                   cautions: [], basis: .derived)
        #expect(AdvisorText.lead(group) == "Led by Hart (34, Team Leader)")
        #expect(AdvisorText.pull(Pull(attribute: .professionalism, value: 8, towards: 17))
                == "Professionalism 8, towards 17")
        #expect(AdvisorText.caution(.onLoanHere, leadName: "Hart") == "Hart is on loan here: the group ends when he goes back.")
        #expect(AdvisorText.caution(.advisedToLeave, leadName: "Hart") == "Hart is advised to leave: the group ends when he goes.")
        #expect(AdvisorText.otherSocialGroup(leadName: "Hart")
                == "In a different social group from Hart: likely a weaker influence")
    }

    @Test func eachNotPlacedReasonHasItsOwnSentence() {
        func sentence(_ reason: NotPlacedReason) -> String {
            AdvisorText.notPlaced(NotPlaced(player: PlayerID(key: "dunn"), name: "Dunn", age: 17, reason: reason))
        }
        #expect(sentence(.nobodyAbove) == "Dunn (17): nobody in this squad stands above him.")
        #expect(sentence(.nobodyBetter) == "Dunn (17): nobody who stands above him in this squad is better where it counts.")
        #expect(sentence(.wouldHarm(.pressure))
                == "Dunn (17): those who are better where it counts would do him harm in Pressure.")
        #expect(sentence(.leadsTaken) == "Dunn (17): the players who could lead him are already in a group.")
        #expect(sentence(.noThird) == "Dunn (17): no third player could be found to make up a group with him and his lead.")
    }

    @Test func eachWarningHasItsOwnSentence() {
        func sentence(_ warning: GroupWarning) -> String { AdvisorText.warning(warning, names: names) }
        #expect(sentence(.mayBeDraggedDown(above: hart, below: young, attribute: .professionalism, aboveValue: 6, belowValue: 12))
                == "Hart stands above Young and has Professionalism 6 against 12: Young may be dragged down.")
        #expect(sentence(.nobodyLeads) == "Nobody is clearly leading this group.")
        #expect(sentence(.differentSocialGroup(reid)) == "Reid is in a different social group from the lead: likely a weaker influence.")
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

    func review(harm: Bool, stopped: Bool, lead: PlayerID?) -> GroupReview {
        let group = MentoringGroup(id: UUID(), squad: .firstTeam, startedOn: Day(year: 2026, month: 9, day: 1)!, members: [])
        return GroupReview(group: group, lead: lead, members: [], warnings: [], isDoingHarm: harm,
                           hasStoppedWorking: stopped, basis: .derived)
    }

    @Test func aGroupDoingHarmOrStoppedSaysSoAndOtherwiseNothing() {
        #expect(AdvisorText.state(of: review(harm: true, stopped: false, lead: hart), parameters: parameters)
                == "This group is doing harm: a member is worth less than when he joined. Consider regrouping.")
        #expect(AdvisorText.state(of: review(harm: true, stopped: false, lead: nil), parameters: parameters)
                == "This group is doing harm: a member is worth less than when he joined. Consider regrouping.")
        #expect(AdvisorText.state(of: review(harm: false, stopped: true, lead: hart), parameters: parameters)
                == "This group has stopped working: nobody but the lead has changed in 13 weeks. Consider regrouping.")
        #expect(AdvisorText.state(of: review(harm: false, stopped: true, lead: nil), parameters: parameters)
                == "This group has stopped working: nobody has changed in 13 weeks. Consider regrouping.")
        #expect(AdvisorText.state(of: review(harm: false, stopped: false, lead: hart), parameters: parameters) == nil)
        #expect(AdvisorText.state(of: review(harm: false, stopped: false, lead: nil), parameters: parameters) == nil)
    }

    @Test func recordingAGroupSaysToSetItInTheGame() {
        #expect(AdvisorText.recorded(names: ["Hart", "Young", "Reid"])
                == "Hart, Young and Reid are recorded as a group from today. Set it in the game as well.")
    }
}
