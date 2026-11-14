import Foundation
import Testing
@testable import LineupEngine
@testable import LineupAppCore

/// The Mentoring tab: the hierarchy lines, the suggested and recorded groups as cards, the players not placed, the
/// hierarchy editor's rows and the group editor's choices, in the engine's words.
@MainActor @Suite struct MentoringPresentationTests {
    private let asOf = Day(year: 2026, month: 11, day: 13)!
    private let parameters = EngineParameters.fm27
    private let club = "Oxford City"

    private let hart = PlayerID.fmrte(1)
    private let okafor = PlayerID.fmrte(2)
    private let mills = PlayerID.fmrte(3)
    private let young = PlayerID.fmrte(4)
    private let reid = PlayerID.fmrte(5)
    private let lane = PlayerID.fmrte(6)
    private let pike = PlayerID.fmrte(7)

    private func player(_ id: PlayerID, _ name: String, age: Int, squad: Squad = .firstTeam,
                        professionalism: Int = 10, pressure: Int = 10, loanedTo: String? = nil) -> Player {
        Player(id: id, name: name, squad: squad, age: age, positionsText: "D C", currentAbility: 100,
               potentialAbility: 120,
               attributes: [.professionalism: professionalism, .pressure: pressure, .determination: 10, .ambition: 10],
               familiarity: [:], condition: 1, sharpness: 1, jadedness: 0, isInjured: false, isBanned: false,
               club: club, loanedTo: loanedTo, contractType: .fullTime, monthsLeft: 10, wagePerWeek: 1,
               askingPrice: nil, nationalities: [], extras: [:])
    }

    /// The engine's advice for the players as given, the squad being the first player's.
    private func advice(_ players: [Player], _ state: MentoringState = MentoringState(), on day: Day? = nil) throws -> MentoringAdvice {
        let squad = players.first?.squad ?? .firstTeam
        let request = MentoringRequest(
            squad: squad, players: players, ownClub: club, dynamics: state.dynamics,
            dynamicsUpdatedOn: state.dynamicsUpdatedOn[squad], groups: state.groups, readings: state.readings,
            names: state.names, leaving: [], asOf: day ?? asOf)
        return .ready(try Mentoring.report(request, parameters: parameters))
    }

    private func sheet(_ players: [Player], _ state: MentoringState = MentoringState(), advice given: MentoringAdvice? = nil,
                       squad: Squad = .firstTeam, names: [PlayerID: String] = [:]) throws -> MentoringSheet {
        let worked = try given ?? advice(players, state)
        let names = names.merging(players.map { ($0.id, $0.name) }, uniquingKeysWith: { _, imported in imported })
        return MentoringPresentation.sheet(squad, advice: worked, players: players, ownClub: club, state: state,
                                           names: names, asOf: asOf, parameters: parameters)
    }

    private func pinned(suggestions: [SuggestedGroup] = [], notPlaced: [NotPlaced] = [], groups: [GroupReview] = [],
                        byAgeAlone: Bool = false) -> MentoringAdvice {
        .ready(MentoringReport(squad: .firstTeam, byAgeAlone: byAgeAlone, isStale: false, suggestions: suggestions,
                               notPlaced: notPlaced, groups: groups, basis: .carriedOverFM26))
    }

    private var hierarchy: MentoringState {
        var state = MentoringState()
        state.dynamics = [hart: PlayerDynamics(standing: .teamLeader), okafor: PlayerDynamics(standing: .teamLeader),
                          mills: PlayerDynamics(standing: .influential)]
        return state
    }

    // MARK: Hierarchy

    @Test func theHierarchyListsEachLevelWithAnyoneInItHighestFirstInSquadOrder() throws {
        // Okafor comes before Hart in the squad.
        let players = [player(okafor, "Okafor", age: 30), player(young, "Young", age: 18),
                       player(hart, "Hart", age: 34), player(mills, "Mills", age: 28)]
        let shown = try sheet(players, hierarchy)
        #expect(shown.hierarchyLines == ["Team Leader: Okafor, Hart.", "Influential: Mills.", "Everyone else: others."])
        #expect(shown.hierarchyLines[0].hasPrefix(AdvisorText.name(Standing.teamLeader) + ":"))
        #expect(shown.byAgeAloneText == nil)
        #expect(shown.notReady == nil)
        #expect(shown.failures.isEmpty)
    }

    @Test func everyoneElseIsLeftOutWhenNobodyIsLeft() throws {
        let players = [player(hart, "Hart", age: 34), player(okafor, "Okafor", age: 30), player(mills, "Mills", age: 28)]
        #expect(try sheet(players, hierarchy).hierarchyLines == ["Team Leader: Hart, Okafor.", "Influential: Mills."])
    }

    @Test func aPlayerOutOnLoanIsNotInTheHierarchy() throws {
        let players = [player(hart, "Hart", age: 34, loanedTo: "Rovers"), player(okafor, "Okafor", age: 30),
                       player(mills, "Mills", age: 28), player(young, "Young", age: 18)]
        let shown = try sheet(players, hierarchy)
        #expect(shown.hierarchyLines == ["Team Leader: Okafor.", "Influential: Mills.", "Everyone else: others."])
        #expect(shown.socialGroupsLine == "Social groups entered for 0 of 3.")
    }

    @Test func theSocialGroupsLineCountsThoseEntered() throws {
        var state = hierarchy
        state.dynamics[young] = PlayerDynamics(standing: .others, socialGroup: .core)
        state.dynamics[hart] = PlayerDynamics(standing: .teamLeader, socialGroup: .secondary("A"))
        let players = [player(hart, "Hart", age: 34), player(okafor, "Okafor", age: 30),
                       player(mills, "Mills", age: 28), player(young, "Young", age: 18)]
        #expect(try sheet(players, state).socialGroupsLine == "Social groups entered for 2 of 4.")
    }

    @Test func theUpdatedDayAndTheStaleTextAfterFourWeeks() throws {
        let players = [player(hart, "Hart", age: 34), player(young, "Young", age: 18)]
        var state = hierarchy
        state.dynamicsUpdatedOn[.firstTeam] = asOf.adding(days: -29)
        let stale = try sheet(players, state)
        #expect(stale.updatedText == "Updated \(DayText.short(asOf.adding(days: -29)))")
        #expect(stale.updatedText == "Updated Thu 15 Oct")
        guard case .ready(let report) = try advice(players, state) else { Issue.record("expected advice"); return }
        let expected = AdvisorText.staleHierarchy(report, updatedOn: asOf.adding(days: -29), asOf: asOf)
        #expect(expected != nil)
        #expect(stale.staleText == expected)

        state.dynamicsUpdatedOn[.firstTeam] = asOf.adding(days: -28)
        let fresh = try sheet(players, state)
        #expect(fresh.updatedText == "Updated Fri 16 Oct")
        #expect(fresh.staleText == nil)

        let never = try sheet(players, hierarchy)
        #expect(never.updatedText == nil)
        #expect(never.staleText == nil)
    }

    @Test func aSquadOfYoungPlayersWithNothingEnteredGoesByAgeAloneAndPlacesNobody() throws {
        let players = [player(hart, "Hart", age: 16), player(okafor, "Okafor", age: 17), player(mills, "Mills", age: 18),
                       player(young, "Young", age: 18), player(reid, "Reid", age: 17)]
        let shown = try sheet(players)
        #expect(shown.hierarchyLines.isEmpty)
        #expect(shown.byAgeAloneText == AdvisorText.mentoringByAgeAlone)
        #expect(shown.suggested.isEmpty)
        let expected = players.sorted { $0.id.key < $1.id.key }.map {
            AdvisorText.notPlaced(NotPlaced(player: $0.id, name: $0.name, age: $0.age, reason: .nobodyAbove))
        }
        #expect(shown.notPlaced == expected)
        #expect(MentoringPresentation.noSuggestionsText(shown) == AdvisorText.noGroupToSuggest)

        let two = try sheet(Array(players.prefix(2)))
        #expect(two.suggested.isEmpty)
        #expect(two.notPlaced.count == 2)
        #expect(two.byAgeAloneText == AdvisorText.mentoringByAgeAlone)
    }

    @Test func theNoteIsTheEnginesStandingNote() throws {
        #expect(try sheet([player(hart, "Hart", age: 34)]).noteText == AdvisorText.mentoringNote)
    }

    // MARK: Suggested groups

    private var suggestion: SuggestedGroup {
        SuggestedGroup(
            lead: hart, leadName: "Hart", leadAge: 34, leadStanding: .teamLeader,
            members: [
                SuggestedMember(player: young, name: "Young", age: 18, isMakingUp: false,
                                pulls: [Pull(attribute: .professionalism, value: 8, towards: 17),
                                        Pull(attribute: .pressure, value: 4, towards: 6)],
                                inDifferentSocialGroup: false),
                SuggestedMember(player: reid, name: "Reid", age: 19, isMakingUp: true, pulls: [],
                                inDifferentSocialGroup: true)],
            cautions: [.onLoanHere, .advisedToLeave], basis: .carriedOverFM26)
    }

    @Test func aSuggestedCardHasTheLeadTheMembersAndTheCautions() throws {
        let shown = try sheet([], advice: pinned(suggestions: [suggestion]))
        let card = try #require(shown.suggested.first)
        #expect(shown.suggested.count == 1)
        #expect(card.id == hart)
        #expect(card.suggestion == suggestion)
        #expect(card.leadText == "Led by Hart (34, Team Leader)")
        #expect(card.leadText == AdvisorText.lead(suggestion))
        #expect(card.members.map(\.id) == [young, reid])
        #expect(card.members[0].nameText == "Young (18)")
        #expect(card.members[0].detailText == "Professionalism 8, towards 17 · Pressure 4, towards 6")
        #expect(card.members[0].notes.isEmpty)
        #expect(card.members[1].nameText == "Reid (19)")
        #expect(card.members[1].detailText == nil)
        #expect(card.members[1].notes == [AdvisorText.makingUpTheGroup, AdvisorText.otherSocialGroup(leadName: "Hart")])
        #expect(card.cautions == [AdvisorText.caution(.onLoanHere, leadName: "Hart"),
                                  AdvisorText.caution(.advisedToLeave, leadName: "Hart")])
        #expect(card.noteText == "(FM26-era numbers)")
        #expect(MentoringPresentation.noSuggestionsText(shown) == nil)
    }

    @Test func aSuggestedCardIsSpokenWithEverythingOnIt() throws {
        let card = try #require(try sheet([], advice: pinned(suggestions: [suggestion])).suggested.first)
        #expect(card.spokenText == "Led by Hart (34, Team Leader), "
                + "Young (18), Professionalism 8, towards 17 · Pressure 4, towards 6, "
                + "Reid (19), Making up the group, In a different social group from Hart: likely a weaker influence, "
                + "Caution: Hart is on loan here: the group ends when he goes back., "
                + "Caution: Hart is advised to leave: the group ends when he goes., FM26-era numbers")
    }

    @Test func aCardWithFM27EvidenceHasNoNote() throws {
        let given = SuggestedGroup(lead: hart, leadName: "Hart", leadAge: 34, leadStanding: .teamLeader,
                                   members: suggestion.members, cautions: [], basis: .fm27Observation)
        #expect(try #require(try sheet([], advice: pinned(suggestions: [given])).suggested.first).noteText == nil)
    }

    @Test func notPlacedAreTheEnginesSentences() throws {
        let missing = NotPlaced(player: pike, name: "Pike", age: 17, reason: .wouldHarm(.pressure))
        let shown = try sheet([], advice: pinned(notPlaced: [missing]))
        #expect(shown.notPlaced == [AdvisorText.notPlaced(missing)])
        #expect(shown.notPlaced == ["Pike (17): those who are better where it counts would do him harm in Pressure."])
    }

    // MARK: Recorded groups

    private let started = Day(year: 2026, month: 10, day: 12)!

    private var recorded: MentoringGroup {
        MentoringGroup(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, squad: .firstTeam,
                       startedOn: started,
                       members: [MentoringMember(player: okafor, joinedOn: started),
                                 MentoringMember(player: lane, joinedOn: started),
                                 MentoringMember(player: pike, joinedOn: started)])
    }

    private func change(_ attribute: Attribute, _ start: Int?, _ latest: Int?, weeks: Double = 5,
                        _ change: ValueChange) -> AttributeChange {
        AttributeChange(attribute: attribute, start: start, latest: latest, weeks: weeks, change: change)
    }

    private func review(doingHarm: Bool = true, stopped: Bool = false) -> GroupReview {
        let none = Mentoring.counted(parameters).map { change($0, nil, nil, weeks: 0, .noReading) }
        return GroupReview(
            group: recorded, lead: okafor,
            members: [
                MemberReview(player: okafor, name: "Okafor", age: 30, isLead: true, pulls: [],
                             changes: [change(.professionalism, 15, 15, .noChange)]),
                MemberReview(player: lane, name: "Lane", age: 20, isLead: false, pulls: [],
                             changes: [change(.professionalism, 9, 10, .improved), change(.pressure, 5, 5, .noChange)]),
                MemberReview(player: pike, name: "Pike", age: 17, isLead: false, pulls: [], changes: none)],
            warnings: [.mayBeDraggedDown(above: okafor, below: pike, attribute: .ambition, aboveValue: 6, belowValue: 9)],
            isDoingHarm: doingHarm, hasStoppedWorking: stopped, basis: .derived)
    }

    @Test func aRecordedCardHasItsTitleSinceChangesWarningsAndState() throws {
        let shown = try sheet([], advice: pinned(groups: [review()]))
        let card = try #require(shown.yours.first)
        #expect(card.id == recorded.id)
        #expect(card.titleText == "Okafor, Lane, Pike")
        #expect(card.sinceText == "since Mon 12 Oct")
        #expect(card.stateText == AdvisorText.state(of: review(), parameters: parameters))
        #expect(card.stateText?.hasPrefix("This group is doing harm") == true)
        #expect(card.members.map(\.nameText) == ["Okafor (30)", "Lane (20)", "Pike (17)"])
        #expect(card.members[0].detailText == "Professionalism 15, no change")
        #expect(card.members[1].detailText == "Professionalism 9 to 10 in 5 weeks · Pressure 5, no change")
        #expect(card.members[1].notes.isEmpty)
        #expect(card.members[2].detailText == nil)
        #expect(card.members[2].notes == [AdvisorText.noReadingYet])
        #expect(card.warnings == ["Okafor stands above Pike and has Ambition 6 against 9: Pike may be dragged down."])
        #expect(card.noteText == "(this tool's estimate)")
        #expect(card.draft == MentoringGroupDraft(editing: recorded))
        #expect(!card.draft.isNew)
    }

    @Test func aGroupThatHasStoppedSaysSoAndAHealthyOneSaysNothing() throws {
        let stopped = try #require(try sheet([], advice: pinned(groups: [review(doingHarm: false, stopped: true)])).yours.first)
        #expect(stopped.stateText == AdvisorText.state(of: review(doingHarm: false, stopped: true), parameters: parameters))
        #expect(stopped.stateText?.hasPrefix("This group has stopped working") == true)
        let healthy = try #require(try sheet([], advice: pinned(groups: [review(doingHarm: false)])).yours.first)
        #expect(healthy.stateText == nil)
    }

    @Test func aRecordedCardIsSpokenWithEverythingOnIt() throws {
        let card = try #require(try sheet([], advice: pinned(groups: [review(doingHarm: false)])).yours.first)
        #expect(card.spokenText == "Okafor, Lane, Pike, since Mon 12 Oct, "
                + "Okafor (30), Professionalism 15, no change, "
                + "Lane (20), Professionalism 9 to 10 in 5 weeks · Pressure 5, no change, "
                + "Pike (17), No reading yet: values are read at each import, "
                + "Warning: Okafor stands above Pike and has Ambition 6 against 9: Pike may be dragged down., "
                + "this tool's estimate")
    }

    @Test func aMemberNoLongerImportedIsShownByNameWithoutAnAge() throws {
        let gone = MemberReview(player: pike, name: "Pike", age: nil, isLead: false, pulls: [], changes: [])
        let given = GroupReview(group: recorded, lead: okafor, members: [review().members[0], review().members[1], gone],
                                warnings: [.notInSquad(pike)], isDoingHarm: false, hasStoppedWorking: false, basis: .derived)
        let card = try #require(try sheet([], advice: pinned(groups: [given])).yours.first)
        #expect(card.members[2].nameText == "Pike")
        #expect(card.warnings == ["Pike is no longer in the squad."])
    }

    // MARK: Not ready and failed

    @Test func aSquadNotImportedShowsOnlyThatItIsNot() throws {
        let shown = try sheet([], advice: .needsSquad, squad: .u21)
        #expect(shown.squad == .u21)
        #expect(shown.notReady == "The U21s have not been imported yet.")
        #expect(shown.failures.isEmpty)
        #expect(shown.hierarchyLines.isEmpty)
        #expect(shown.socialGroupsLine == nil)
        #expect(shown.updatedText == nil && shown.staleText == nil && shown.byAgeAloneText == nil)
        #expect(shown.suggested.isEmpty && shown.yours.isEmpty && shown.notPlaced.isEmpty)
        #expect(MentoringPresentation.noSuggestionsText(shown) == nil)
        #expect(try sheet([], advice: .needsSquad).notReady == "The first team has not been imported yet.")
        #expect(try sheet([], advice: .needsSquad, squad: .u18).notReady == "The U18s have not been imported yet.")
    }

    @Test func aFailedSquadKeepsItsHierarchyAndItsGroupsNames() throws {
        let players = [player(okafor, "Okafor", age: 30), player(lane, "Lane", age: 20), player(hart, "Hart", age: 34),
                       player(mills, "Mills", age: 28)]
        var state = hierarchy
        state.dynamicsUpdatedOn[.firstTeam] = asOf.adding(days: -3)
        // Pike has left every squad: his name is the saved one.
        state.names = [okafor: "Okafor", lane: "Lane", pike: "Pike"]
        let other = MentoringGroup(id: UUID(), squad: .u21, startedOn: started,
                                   members: [MentoringMember(player: young, joinedOn: started)])
        var ended = recorded
        ended.id = UUID()
        ended.endedOn = asOf
        state.groups = [recorded, other, ended]
        let sentence = ErrorDescriptions.describe(RatingError.missingAttribute(player: "Hart", attribute: .pressure))
        let shown = try sheet(players, state, advice: .failed([sentence]))
        #expect(shown.failures == [sentence])
        #expect(shown.notReady == nil)
        #expect(shown.hierarchyLines == ["Team Leader: Okafor, Hart.", "Influential: Mills.", "Everyone else: others."])
        #expect(shown.socialGroupsLine == "Social groups entered for 0 of 4.")
        #expect(shown.updatedText == "Updated \(DayText.short(asOf.adding(days: -3)))")
        #expect(shown.suggested.isEmpty)
        #expect(shown.notPlaced.isEmpty)
        #expect(MentoringPresentation.noSuggestionsText(shown) == nil)
        let card = try #require(shown.yours.first)
        #expect(shown.yours.count == 1)
        #expect(card.id == recorded.id)
        #expect(card.titleText == "Okafor, Lane, Pike")
        #expect(card.sinceText == "since Mon 12 Oct")
        #expect(card.members.isEmpty && card.warnings.isEmpty)
        #expect(card.stateText == nil && card.noteText == nil)
        #expect(card.draft == MentoringGroupDraft(editing: recorded))
    }

    @Test func aFailedSquadWithNothingEnteredSaysItGoesByAgeAlone() throws {
        let shown = try sheet([player(hart, "Hart", age: 34)], advice: .failed(["Something"]))
        #expect(shown.hierarchyLines.isEmpty)
        #expect(shown.byAgeAloneText == AdvisorText.mentoringByAgeAlone)
    }

    @Test func aMemberWithNoNameKnownIsNeverShownByHisKey() throws {
        var state = MentoringState()
        state.groups = [recorded]
        let shown = try sheet([], state, advice: .failed(["Something"]))
        let title = try #require(shown.yours.first).titleText
        #expect(!title.contains(okafor.key) && !title.contains(lane.key) && !title.contains(pike.key))
    }

    // MARK: Long names

    @Test func aLongNameIsCarriedWhole() throws {
        let long = "Maximilian-Alexander Bartholomew Featherstonehaugh-Montgomery"
        let players = [player(hart, long, age: 34), player(young, "Young", age: 18)]
        var state = MentoringState()
        state.dynamics[hart] = PlayerDynamics(standing: .teamLeader)
        let shown = try sheet(players, state)
        #expect(shown.hierarchyLines.first == "Team Leader: \(long).")
        let given = SuggestedGroup(lead: hart, leadName: long, leadAge: 34, leadStanding: .teamLeader,
                                   members: suggestion.members, cautions: [], basis: .derived)
        let card = try #require(try sheet([], advice: pinned(suggestions: [given])).suggested.first)
        #expect(card.leadText == "Led by \(long) (34, Team Leader)")
        #expect(MentoringPresentation.dynamicsRows(players, ownClub: club, dynamics: [:]).first?.name == long)
    }

    // MARK: Choosing the squad

    @Test func theSquadShownIsTheOneAskedForWhenImported() {
        #expect(MentoringPresentation.squadShown(.u21, imported: [.firstTeam, .u21]) == .u21)
        #expect(MentoringPresentation.squadShown(.firstTeam, imported: [.u18, .u21]) == .u21)
        #expect(MentoringPresentation.squadShown(.u21, imported: [.u18]) == .u18)
        #expect(MentoringPresentation.squadShown(.u18, imported: []) == .firstTeam)
        #expect(MentoringPresentation.squadShown(.u21, imported: []) == .firstTeam)
    }

    @Test func eachSquadHasItsTitle() {
        #expect(Squad.allCases.map(MentoringPresentation.squadTitle) == ["First team", "U21s", "U18s"])
    }

    // MARK: The editors

    @Test func dynamicsRowsAreTheSquadsPlayersNotOutOnLoanWithTheirEntries() {
        let players = [player(young, "Young", age: 18), player(hart, "Hart", age: 34, loanedTo: "Rovers"),
                       player(okafor, "Okafor", age: 30)]
        let entry = PlayerDynamics(standing: .influential, socialGroup: .core)
        let rows = MentoringPresentation.dynamicsRows(players, ownClub: club, dynamics: [okafor: entry, hart: entry])
        #expect(rows.map(\.id) == [young, okafor])
        #expect(rows.map(\.name) == ["Young", "Okafor"])
        #expect(rows.map(\.ageText) == ["Age 18", "Age 30"])
        #expect(rows.map(\.dynamics) == [PlayerDynamics(), entry])
    }

    @Test func memberChoicesMarkAPlayerInAnotherGroup() {
        let players = [player(okafor, "Okafor", age: 30), player(lane, "Lane", age: 20), player(pike, "Pike", age: 17),
                       player(young, "Young", age: 18), player(reid, "Reid", age: 19, loanedTo: "Rovers"),
                       player(hart, "Hart", age: 34)]
        var state = MentoringState()
        state.dynamics[hart] = PlayerDynamics(standing: .teamLeader)
        var ended = MentoringGroup(id: UUID(), squad: .firstTeam, startedOn: started,
                                   members: [MentoringMember(player: hart, joinedOn: started)])
        ended.endedOn = asOf
        state.groups = [recorded, ended]

        let new = MentoringGroupDraft(squad: .firstTeam, members: [young])
        let choices = MentoringPresentation.memberChoices(new, players: players, ownClub: club, state: state)
        #expect(choices.map(\.id) == [okafor, lane, pike, young, hart])
        #expect(choices.map(\.name) == ["Okafor", "Lane", "Pike", "Young", "Hart"])
        #expect(choices.map(\.detailText) == ["30 · Others", "20 · Others", "17 · Others", "18 · Others", "34 · Team Leader"])
        #expect(choices.map(\.isChosen) == [false, false, false, true, false])
        #expect(choices.map(\.unavailableText) == ["In another group", "In another group", "In another group", nil, nil])

        // Editing the group itself: its own members are free.
        let editing = MentoringGroupDraft(editing: recorded)
        let own = MentoringPresentation.memberChoices(editing, players: players, ownClub: club, state: state)
        #expect(own.map(\.isChosen) == [true, true, true, false, false])
        #expect(own.allSatisfy { $0.unavailableText == nil })
    }

    @Test func theTwoChoiceLists() {
        #expect(MentoringPresentation.standingChoices.map(\.0) == [.teamLeader, .highlyInfluential, .influential, .others])
        #expect(MentoringPresentation.standingChoices.map(\.1) == Standing.allCases.reversed().map(AdvisorText.name))
        #expect(MentoringPresentation.socialGroupChoices.map(\.0)
                == [nil, .core, .secondary("A"), .secondary("B"), .secondary("C"), .secondary("D"), .others])
        #expect(MentoringPresentation.socialGroupChoices.map(\.1)
                == ["Not entered", "Core", "Secondary A", "Secondary B", "Secondary C", "Secondary D", "Others"])
    }

    @Test func theLabels() {
        let headings = MentoringPresentation.headings
        #expect([headings.hierarchy, headings.suggested, headings.yours, headings.notPlaced]
                == ["Hierarchy", "Suggested groups", "Your groups", "Not placed"])
        #expect(TrainingView.allCases.map(\.title) == ["Retraining", "Mentoring"])
        #expect(MentoringEditing.hierarchy(.u21).id != MentoringEditing.hierarchy(.firstTeam).id)
        let draft = MentoringGroupDraft(squad: .firstTeam)
        #expect(MentoringEditing.group(draft).id != MentoringEditing.hierarchy(.firstTeam).id)
    }
}
