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
        #expect(sentence(.noThirdFree)
                == "Dunn (17): no third player is left free to make a group with him and a player who could influence him.")
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

    func review(harm: Bool = false, noInfluence: Bool = false, stopped: Bool = false, unread: Int = 0) -> GroupReview {
        let group = MentoringGroup(id: UUID(), squad: .firstTeam, startedOn: Day(year: 2026, month: 9, day: 1)!, members: [])
        return GroupReview(group: group, members: [], arrows: [], unreadArrows: unread, hasNoInfluence: noInfluence,
                           warnings: [], isDoingHarm: harm, hasStoppedWorking: stopped, basis: .derived)
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

    @Test func arrowsStillToReadAreCounted() {
        #expect(AdvisorText.arrowsToRead(review(unread: 0)) == nil)
        #expect(AdvisorText.arrowsToRead(review(unread: 1))
                == "Record this group's arrows from the game: 1 of them is still a guess.")
        #expect(AdvisorText.arrowsToRead(review(unread: 4))
                == "Record this group's arrows from the game: 4 of them are still guesses.")
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
