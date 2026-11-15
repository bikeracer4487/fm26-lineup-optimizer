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
                        professionalism: Int = 10, pressure: Int = 10, ambition: Int = 10,
                        loanedTo: String? = nil) -> Player {
        Player(id: id, name: name, squad: squad, age: age, positionsText: "D C", currentAbility: 100,
               potentialAbility: 120,
               attributes: [.professionalism: professionalism, .pressure: pressure, .determination: 10,
                            .ambition: ambition],
               familiarity: [:], condition: 1, sharpness: 1, jadedness: 0, isInjured: false, isBanned: false,
               club: club, loanedTo: loanedTo, contractType: .fullTime, monthsLeft: 10, wagePerWeek: 1,
               askingPrice: nil, nationalities: [], extras: [:])
    }

    /// The engine's advice for the players as given, the squad being the first player's.
    private func advice(_ players: [Player], _ state: MentoringState = MentoringState(), on day: Day? = nil) throws -> MentoringAdvice {
        let squad = players.first?.squad ?? .firstTeam
        let request = MentoringRequest(
            squad: squad, players: players, ownClub: club, dynamics: state.dynamics(for: squad),
            dynamicsUpdatedOn: state.dynamicsUpdatedOn[squad], groups: state.groups, readings: state.readings,
            arrows: [], names: state.names, leaving: [], asOf: day ?? asOf)
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
                        needsHierarchy: Bool = false) -> MentoringAdvice {
        .ready(MentoringReport(squad: .firstTeam, needsHierarchy: needsHierarchy, isStale: false,
                               suggestions: suggestions, notPlaced: notPlaced, groups: groups, basis: .carriedOverFM26))
    }

    /// Enters each player's level and group for the squad, as its hierarchy editor would.
    private func enter(_ entries: [PlayerID: PlayerDynamics], into state: inout MentoringState,
                       squad: Squad = .firstTeam) {
        for (id, entry) in entries { state.hierarchy[id] = HierarchyEntry(squad: squad, dynamics: entry) }
    }

    private var hierarchy: MentoringState {
        var state = MentoringState()
        enter([hart: PlayerDynamics(standing: .teamLeader), okafor: PlayerDynamics(standing: .teamLeader),
               mills: PlayerDynamics(standing: .influential)], into: &state)
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
        #expect(shown.needsHierarchyText == nil)
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

    @Test func anEntryEnteredForAnotherSquadIsNotShown() throws {
        let players = [player(hart, "Hart", age: 34), player(young, "Young", age: 18)]
        let entry = PlayerDynamics(standing: .teamLeader, socialGroup: .core)
        var elsewhere = MentoringState()
        enter([hart: entry], into: &elsewhere, squad: .u21)
        var here = MentoringState()
        enter([hart: entry], into: &here)

        let hidden = try sheet(players, elsewhere)
        #expect(hidden.hierarchyLines.isEmpty)
        #expect(hidden.socialGroupsLine == "Social groups entered for 0 of 2.")
        let shown = try sheet(players, here)
        #expect(shown.hierarchyLines.first == "Team Leader: Hart.")
        #expect(shown.socialGroupsLine == "Social groups entered for 1 of 2.")

        let draft = MentoringGroupDraft(squad: .firstTeam)
        func detail(_ state: MentoringState) -> String? {
            MentoringPresentation.memberChoices(draft, players: players, ownClub: club, state: state)
                .first { $0.id == hart }?.detailText
        }
        #expect(detail(elsewhere) == "34 · Others")
        #expect(detail(here) == "34 · Team Leader")
    }

    @Test func theSocialGroupsLineCountsThoseEntered() throws {
        var state = hierarchy
        enter([young: PlayerDynamics(standing: .others, socialGroup: .core),
               hart: PlayerDynamics(standing: .teamLeader, socialGroup: .secondary("A"))], into: &state)
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

    @Test func aSquadOfYoungPlayersWithNothingEnteredNeedsItsHierarchyAndPlacesNobody() throws {
        let players = [player(hart, "Hart", age: 16), player(okafor, "Okafor", age: 17), player(mills, "Mills", age: 18),
                       player(young, "Young", age: 18), player(reid, "Reid", age: 17)]
        let shown = try sheet(players)
        #expect(shown.hierarchyLines.isEmpty)
        #expect(shown.needsHierarchyText == AdvisorText.mentoringNeedsHierarchy)
        #expect(shown.suggested.isEmpty)
        let expected = players.sorted { $0.id.key < $1.id.key }.map {
            AdvisorText.notPlaced(NotPlaced(player: $0.id, name: $0.name, age: $0.age, reason: .noInfluence))
        }
        #expect(shown.notPlaced == expected)
        #expect(MentoringPresentation.noSuggestionsText(shown) == AdvisorText.noGroupToSuggest)

        let two = try sheet(Array(players.prefix(2)))
        #expect(two.suggested.isEmpty)
        #expect(two.notPlaced.count == 2)
        #expect(two.needsHierarchyText == AdvisorText.mentoringNeedsHierarchy)

        // One level entered, and the sentence goes.
        var state = MentoringState()
        enter([hart: PlayerDynamics(standing: .influential)], into: &state)
        #expect(try sheet(players, state).needsHierarchyText == nil)
    }

    @Test func theNoteIsTheEnginesStandingNote() throws {
        #expect(try sheet([player(hart, "Hart", age: 34)]).noteText == AdvisorText.mentoringNote)
        #expect(try sheet([], advice: .needsSquad).noteText == AdvisorText.mentoringNote)
        #expect(try sheet([], advice: .failed(["Something"])).noteText == AdvisorText.mentoringNote)
    }

    // MARK: Arrows

    private let readDay = Day(year: 2026, month: 11, day: 14)!

    private func arrow(_ from: PlayerID, _ fromName: String, _ to: PlayerID, _ toName: String,
                       _ strength: ArrowStrength, readOn: Day? = nil, pulls: [Pull] = []) -> GroupArrow {
        GroupArrow(arrow: Arrow(from: from, to: to, strength: strength, readOn: readOn), fromName: fromName,
                   toName: toName, pulls: pulls)
    }

    @Test func anArrowLineSaysReadWithItsDayOrExpected() {
        let pulls = [Pull(attribute: .professionalism, value: 10, towards: 12),
                     Pull(attribute: .determination, value: 7, towards: 12)]
        let read = ArrowLine(arrow(hart, "McEachran", young, "Clark", .significant, readOn: readDay, pulls: pulls))
        #expect(read.titleText == "McEachran → Clark")
        #expect(read.strengthText == "Significant · read Sat 14 Nov")
        #expect(read.detailText == "Professionalism 10, towards 12 · Determination 7, towards 12")
        #expect(!read.isGuess)
        #expect(read.id == "\(hart.key)→\(young.key)")

        let guess = ArrowLine(arrow(hart, "McEachran", young, "Clark", .light, pulls: pulls))
        #expect(guess.strengthText == "Light · expected, not read")
        #expect(guess.strengthText == AdvisorText.name(ArrowStrength.light) + " · " + AdvisorText.expectedNotRead)
        #expect(guess.isGuess)
        // The other way round is another arrow.
        #expect(ArrowLine(arrow(young, "Clark", hart, "McEachran", .light)).id != guess.id)
    }

    @Test func anArrowWithNothingToGainSaysSo() {
        let line = ArrowLine(arrow(hart, "McEachran", reid, "Humphries", .average, readOn: readDay))
        #expect(line.detailText == "nothing to gain")
        #expect(line.detailText == AdvisorText.nothingToGain)
        #expect(line.strengthText == "Average · read Sat 14 Nov")
    }

    // MARK: Suggested groups

    private var suggestion: SuggestedGroup {
        SuggestedGroup(
            members: [SuggestedMember(player: hart, name: "Hart", age: 34),
                      SuggestedMember(player: young, name: "Young", age: 18),
                      SuggestedMember(player: reid, name: "Reid", age: 19)],
            arrows: [arrow(hart, "Hart", young, "Young", .average,
                           pulls: [Pull(attribute: .professionalism, value: 8, towards: 17),
                                   Pull(attribute: .pressure, value: 4, towards: 6)]),
                     arrow(hart, "Hart", reid, "Reid", .average)],
            isRead: false, cautions: [.onLoanHere(hart), .advisedToLeave(hart)], basis: .carriedOverFM26)
    }

    @Test func aSuggestedCardHasItsTitleItsArrowsThePromptAndTheCautions() throws {
        let shown = try sheet([], advice: pinned(suggestions: [suggestion]))
        let card = try #require(shown.suggested.first)
        #expect(shown.suggested.count == 1)
        #expect(card.id == suggestion.id)
        #expect(card.suggestion == suggestion)
        #expect(card.titleText == "Hart, Young, Reid")
        #expect(card.arrows.map(\.titleText) == ["Hart → Young", "Hart → Reid"])
        #expect(card.arrows.map(\.strengthText) == ["Average · expected, not read", "Average · expected, not read"])
        #expect(card.arrows.map(\.detailText) == ["Professionalism 8, towards 17 · Pressure 4, towards 6",
                                                  "nothing to gain"])
        #expect(card.arrows.allSatisfy { $0.isGuess })
        #expect(card.promptText == "Set this group in the game and record its arrows.")
        #expect(card.promptText == AdvisorText.setAndRecordArrows)
        let names = [hart: "Hart", young: "Young", reid: "Reid"]
        #expect(card.cautions == [AdvisorText.caution(.onLoanHere(hart), names: names),
                                  AdvisorText.caution(.advisedToLeave(hart), names: names)])
        #expect(card.cautions.first == "Hart is on loan here: the group ends when he goes back.")
        #expect(card.noteText == "(FM26-era numbers)")
        #expect(MentoringPresentation.noSuggestionsText(shown) == nil)
    }

    @Test func aSuggestionThatWasReadHasNoPrompt() throws {
        let given = SuggestedGroup(members: suggestion.members, arrows: suggestion.arrows, isRead: true, cautions: [],
                                   basis: .derived)
        let card = try #require(try sheet([], advice: pinned(suggestions: [given])).suggested.first)
        #expect(card.promptText == nil)
        #expect(card.cautions.isEmpty)
    }

    @Test func aSuggestedCardIsSpokenWithEverythingOnIt() throws {
        let card = try #require(try sheet([], advice: pinned(suggestions: [suggestion])).suggested.first)
        #expect(card.spokenText == "Hart, Young, Reid, "
                + "Hart → Young, Average · expected, not read, Professionalism 8, towards 17 · Pressure 4, towards 6, "
                + "Hart → Reid, Average · expected, not read, nothing to gain, "
                + "Set this group in the game and record its arrows., "
                + "Caution: Hart is on loan here: the group ends when he goes back., "
                + "Caution: Hart is advised to leave: the group ends when he goes., FM26-era numbers")
    }

    @Test func aCardWithFM27EvidenceHasNoNote() throws {
        let given = SuggestedGroup(members: suggestion.members, arrows: suggestion.arrows, isRead: false, cautions: [],
                                   basis: .fm27Observation)
        #expect(try #require(try sheet([], advice: pinned(suggestions: [given])).suggested.first).noteText == nil)
    }

    /// Every reason: a new case stops this from building until it is added below.
    private func listed(_ reason: NotPlacedReason) -> Bool {
        switch reason {
        case .takesNothing, .noInfluence, .nothingToGain, .tooFewFree, .wouldHarm, .noThirdFree, .influencersTaken: true
        }
    }

    @Test func notPlacedAreTheEnginesSentences() throws {
        let reasons: [NotPlacedReason] = [.takesNothing, .noInfluence, .nothingToGain, .tooFewFree, .wouldHarm,
                                          .noThirdFree, .influencersTaken]
        #expect(reasons.allSatisfy(listed))
        let missing = reasons.map { NotPlaced(player: pike, name: "Pike", age: 17, reason: $0) }
        let shown = try sheet([], advice: pinned(notPlaced: missing))
        #expect(shown.notPlaced == missing.map(AdvisorText.notPlaced))
        #expect(Set(shown.notPlaced).count == reasons.count)
        #expect(shown.notPlaced[0] == "Pike (17): he has taken nothing from the players tried with him so far.")
        #expect(shown.notPlaced[4] == "Pike (17): every group that would help him would pull a player down.")
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

    private var recordedArrows: [GroupArrow] {
        [arrow(okafor, "Okafor", lane, "Lane", .significant, readOn: readDay,
               pulls: [Pull(attribute: .professionalism, value: 10, towards: 15)]),
         arrow(okafor, "Okafor", pike, "Pike", .light)]
    }

    private func review(doingHarm: Bool = true, stopped: Bool = false, noInfluence: Bool = false,
                        unread: Int = 5) -> GroupReview {
        let none = Mentoring.counted(parameters).map { change($0, nil, nil, weeks: 0, .noReading) }
        return GroupReview(
            group: recorded,
            members: [
                MemberReview(player: okafor, name: "Okafor", age: 30,
                             changes: [change(.professionalism, 15, 15, .noChange)]),
                MemberReview(player: lane, name: "Lane", age: 20,
                             changes: [change(.professionalism, 9, 10, .improved), change(.pressure, 5, 5, .noChange)]),
                MemberReview(player: pike, name: "Pike", age: 17, changes: none)],
            arrows: noInfluence ? [] : recordedArrows, unreadArrows: unread, hasNoInfluence: noInfluence,
            warnings: [.harmfulArrow(from: okafor, to: pike, strength: .light, isRead: false, attribute: .ambition,
                                     fromValue: 6, toValue: 9)],
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
        #expect(card.arrows == recordedArrows.map(ArrowLine.init))
        #expect(card.arrows.map(\.titleText) == ["Okafor → Lane", "Okafor → Pike"])
        #expect(card.arrows.map(\.strengthText) == ["Significant · read Sat 14 Nov", "Light · expected, not read"])
        #expect(card.arrows.map(\.detailText) == ["Professionalism 10, towards 15", "nothing to gain"])
        #expect(card.arrowsPromptText == "Record this group's arrows from the game: 5 of them are still guesses.")
        #expect(card.members.map(\.nameText) == ["Okafor (30)", "Lane (20)", "Pike (17)"])
        #expect(card.members[0].detailText == "Professionalism 15, no change")
        #expect(card.members[1].detailText == "Professionalism 9 to 10 in 5 weeks · Pressure 5, no change")
        #expect(card.members[1].notes.isEmpty)
        #expect(card.members[2].detailText == nil)
        #expect(card.members[2].notes == [AdvisorText.noReadingYet])
        #expect(card.warnings == ["Okafor's influence on Pike is expected to be Light, and Okafor's Ambition is 6 "
                                  + "against Pike's 9."])
        #expect(card.warnings == review().warnings.map {
            AdvisorText.warning($0, names: [okafor: "Okafor", lane: "Lane", pike: "Pike"])
        })
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

    @Test func aGroupWithNoInfluenceSaysSo() throws {
        let given = review(doingHarm: false, noInfluence: true, unread: 0)
        let card = try #require(try sheet([], advice: pinned(groups: [given])).yours.first)
        #expect(card.stateText == AdvisorText.state(of: given, parameters: parameters))
        #expect(card.stateText == "The game shows no influence in this group: all six arrows are None. Consider regrouping.")
        #expect(card.arrows.isEmpty)
        #expect(card.arrowsPromptText == nil)
    }

    @Test func aRecordedCardAsksForItsArrowsUntilAllAreRead() throws {
        func prompt(_ unread: Int) throws -> String? {
            try #require(try sheet([], advice: pinned(groups: [review(unread: unread)])).yours.first).arrowsPromptText
        }
        #expect(try prompt(6) == AdvisorText.arrowsToRead(review(unread: 6)))
        #expect(try prompt(6) == "Record this group's arrows from the game: 6 of them are still guesses.")
        #expect(try prompt(1) == "Record this group's arrows from the game: 1 of them is still a guess.")
        #expect(try prompt(0) == nil)
    }

    @Test func aRecordedCardIsSpokenWithEverythingOnIt() throws {
        let card = try #require(try sheet([], advice: pinned(groups: [review(stopped: false)])).yours.first)
        #expect(card.spokenText == "Okafor, Lane, Pike, since Mon 12 Oct, "
                + "Okafor → Lane, Significant · read Sat 14 Nov, Professionalism 10, towards 15, "
                + "Okafor → Pike, Light · expected, not read, nothing to gain, "
                + "Record this group's arrows from the game: 5 of them are still guesses., "
                + "Warning: Okafor's influence on Pike is expected to be Light, and Okafor's Ambition is 6 against "
                + "Pike's 9., "
                + "This group is doing harm: a member is worth less than when he joined. Consider regrouping., "
                + "Okafor (30), Professionalism 15, no change, "
                + "Lane (20), Professionalism 9 to 10 in 5 weeks · Pressure 5, no change, "
                + "Pike (17), No reading yet: values are read at each import, "
                + "this tool's estimate")
    }

    @Test func aSquadWithNoGroupRecordedSaysSo() throws {
        let none = try sheet([player(hart, "Hart", age: 34)])
        #expect(none.yours.isEmpty)
        #expect(MentoringPresentation.noRecordedGroupsText(none) == "No group recorded yet.")
        // Nor when the advice stopped and nothing is saved.
        #expect(MentoringPresentation.noRecordedGroupsText(try sheet([], advice: .failed(["Something"])))
                == "No group recorded yet.")
        #expect(MentoringPresentation.noRecordedGroupsText(try sheet([], advice: pinned(groups: [review()]))) == nil)
        #expect(MentoringPresentation.noRecordedGroupsText(try sheet([], advice: .needsSquad)) == nil)
    }

    @Test func aMemberNoLongerImportedIsShownByNameWithoutAnAge() throws {
        let gone = MemberReview(player: pike, name: "Pike", age: nil, changes: [])
        let given = GroupReview(group: recorded, members: [review().members[0], review().members[1], gone],
                                arrows: [], unreadArrows: 2, hasNoInfluence: false, warnings: [.notInSquad(pike)],
                                isDoingHarm: false, hasStoppedWorking: false, basis: .derived)
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
        #expect(shown.updatedText == nil && shown.staleText == nil && shown.needsHierarchyText == nil)
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
        #expect(card.arrows.isEmpty && card.arrowsPromptText == nil)
        #expect(card.stateText == nil && card.noteText == nil)
        #expect(shown.needsHierarchyText == nil)
        #expect(card.draft == MentoringGroupDraft(editing: recorded))
    }

    @Test func aFailedSquadWithNothingEnteredSaysItNeedsItsHierarchy() throws {
        let shown = try sheet([player(hart, "Hart", age: 34)], advice: .failed(["Something"]))
        #expect(shown.hierarchyLines.isEmpty)
        #expect(shown.needsHierarchyText == AdvisorText.mentoringNeedsHierarchy)
        // A level entered only for a player out on loan is not one the advice uses.
        var state = MentoringState()
        enter([okafor: PlayerDynamics(standing: .teamLeader)], into: &state)
        let away = [player(hart, "Hart", age: 34), player(okafor, "Okafor", age: 30, loanedTo: "Rovers")]
        #expect(try sheet(away, state, advice: .failed(["Something"])).needsHierarchyText
                == AdvisorText.mentoringNeedsHierarchy)
        enter([hart: PlayerDynamics(standing: .influential)], into: &state)
        #expect(try sheet(away, state, advice: .failed(["Something"])).needsHierarchyText == nil)
    }

    @Test func aMemberWithNoNameKnownIsNeverShownByHisKey() throws {
        var state = MentoringState()
        state.groups = [recorded]
        let shown = try sheet([], state, advice: .failed(["Something"]))
        let title = try #require(shown.yours.first).titleText
        #expect(!title.contains(okafor.key) && !title.contains(lane.key) && !title.contains(pike.key))
    }

    // MARK: Every sentence the engine's

    @Test func noSentenceAboutAdviceIsWrittenInCore() throws {
        // Hart leads a group with Young and Reid; Mills, 28, has nobody to influence him; Okafor's recorded group with
        // Lane and Pike has a harmful arrow, his Ambition below theirs, and none of its arrows read.
        let players = [player(hart, "Hart", age: 34, professionalism: 18), player(young, "Young", age: 18, professionalism: 8),
                       player(reid, "Reid", age: 19, professionalism: 9), player(mills, "Mills", age: 28),
                       player(okafor, "Okafor", age: 30, ambition: 4), player(lane, "Lane", age: 20, ambition: 9),
                       player(pike, "Pike", age: 17, ambition: 9)]
        var state = MentoringState()
        enter([hart: PlayerDynamics(standing: .teamLeader), okafor: PlayerDynamics(standing: .influential)], into: &state)
        state.groups = [recorded]
        guard case .ready(let report) = try advice(players, state) else { Issue.record("expected advice"); return }
        // Otherwise the test would check nothing.
        #expect(!report.suggestions.isEmpty && !report.notPlaced.isEmpty && !report.groups.isEmpty)
        #expect(report.groups.allSatisfy { !$0.warnings.isEmpty && !$0.arrows.isEmpty && $0.unreadArrows > 0 })
        #expect(report.groups.contains { $0.warnings.contains { if case .harmfulArrow = $0 { true } else { false } } })

        func expected(_ arrow: GroupArrow) -> [String] {
            let read = arrow.arrow.readOn.map(MentoringPresentation.readOn) ?? AdvisorText.expectedNotRead
            let pulls = arrow.pulls.map(AdvisorText.pull)
            return [AdvisorText.arrowTitle(arrow), AdvisorText.name(arrow.arrow.strength) + " · " + read,
                    pulls.isEmpty ? AdvisorText.nothingToGain : pulls.joined(separator: " · ")]
        }
        func shown(_ line: ArrowLine) -> [String] { [line.titleText, line.strengthText, line.detailText] }

        let sheet = try sheet(players, state, advice: .ready(report))
        #expect(sheet.noteText == AdvisorText.mentoringNote)
        #expect(sheet.needsHierarchyText == nil)
        #expect(sheet.notPlaced == report.notPlaced.map(AdvisorText.notPlaced))
        #expect(sheet.suggested.count == report.suggestions.count)
        for (card, suggestion) in zip(sheet.suggested, report.suggestions) {
            #expect(card.arrows.map(shown) == suggestion.arrows.map(expected))
            #expect(card.promptText == (suggestion.isRead ? nil : AdvisorText.setAndRecordArrows))
            let names = Dictionary(uniqueKeysWithValues: suggestion.members.map { ($0.player, $0.name) })
            #expect(card.cautions == suggestion.cautions.map { AdvisorText.caution($0, names: names) })
        }
        #expect(sheet.yours.count == report.groups.count)
        for (card, review) in zip(sheet.yours, report.groups) {
            #expect(card.arrows.map(shown) == review.arrows.map(expected))
            #expect(card.arrowsPromptText == AdvisorText.arrowsToRead(review))
            #expect(card.stateText == AdvisorText.state(of: review, parameters: parameters))
            let names = Dictionary(uniqueKeysWithValues: review.members.map { ($0.player, $0.name) })
            #expect(card.warnings == review.warnings.map { AdvisorText.warning($0, names: names) })
        }
    }

    // MARK: Long names

    @Test func aLongNameIsCarriedWhole() throws {
        let long = "Maximilian-Alexander Bartholomew Featherstonehaugh-Montgomery"
        let players = [player(hart, long, age: 34), player(young, "Young", age: 18)]
        var state = MentoringState()
        enter([hart: PlayerDynamics(standing: .teamLeader)], into: &state)
        let shown = try sheet(players, state)
        #expect(shown.hierarchyLines.first == "Team Leader: \(long).")
        let given = SuggestedGroup(
            members: [SuggestedMember(player: hart, name: long, age: 34)] + suggestion.members.dropFirst(),
            arrows: [arrow(hart, long, young, "Young", .average)], isRead: false, cautions: [.advisedToLeave(hart)],
            basis: .derived)
        let card = try #require(try sheet([], advice: pinned(suggestions: [given])).suggested.first)
        #expect(card.titleText == "\(long), Young, Reid")
        #expect(card.arrows.first?.titleText == "\(long) → Young")
        #expect(card.cautions == ["\(long) is advised to leave: the group ends when he goes."])
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
        #expect(MentoringPresentation.squadMenuLabel == "Squad")
    }

    @Test func theSquadMenuOffersTheSquadsImportedInBookOrder() {
        #expect(MentoringPresentation.squadChoices(imported: [.u21, .firstTeam]) == [.firstTeam, .u21])
        #expect(MentoringPresentation.squadChoices(imported: [.u18]) == [.u18])
        // With none imported, the squad shown.
        #expect(MentoringPresentation.squadChoices(imported: []) == [.firstTeam])
        #expect(MentoringPresentation.squadChoices(imported: []) == [MentoringPresentation.squadShown(.u21, imported: [])])
    }

    // MARK: Not placed

    @Test func theNotPlacedHeadingShowsOnlyWithSomeoneToList() throws {
        let players = [player(hart, "Hart", age: 34), player(young, "Young", age: 18)]
        let placed = try sheet(players, advice: pinned(notPlaced: []))
        #expect(MentoringPresentation.notPlacedHeading(placed) == nil)
        let left = try sheet(players, advice: pinned(notPlaced: [NotPlaced(player: young, name: "Young", age: 18,
                                                                             reason: .noInfluence)]))
        #expect(MentoringPresentation.notPlacedHeading(left) == "Not placed")
        #expect(MentoringPresentation.notPlacedHeading(try sheet([], advice: .needsSquad)) == nil)
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
        enter([hart: PlayerDynamics(standing: .teamLeader)], into: &state)
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

    @Test func aGroupBeingChangedListsItsMembersWhoHaveGoneFirstWithWhy() {
        // Pike has left the squad; Lane is out on loan.
        let players = [player(okafor, "Okafor", age: 30), player(lane, "Lane", age: 20, loanedTo: "Rovers"),
                       player(young, "Young", age: 18)]
        var state = MentoringState()
        state.groups = [recorded]
        state.names = [okafor: "Okafor", lane: "Lane", pike: "Pike"]
        var draft = MentoringGroupDraft(editing: recorded)
        let choices = MentoringPresentation.memberChoices(draft, players: players, ownClub: club, state: state)
        #expect(choices.map(\.id) == [lane, pike, okafor, young])
        #expect(choices.map(\.name) == ["Lane", "Pike", "Okafor", "Young"])
        #expect(choices.map(\.detailText) == ["20 · Others", nil, "30 · Others", "18 · Others"])
        #expect(choices.map(\.unavailableText) == ["Out on loan", "No longer in the squad", nil, nil])
        #expect(choices.map(\.isChosen) == [true, true, true, false])
        // A member who has gone can be taken out; with three chosen nobody else can be put in.
        #expect(choices.map(\.canToggle) == [true, true, true, false])

        // Pike taken out: his row stays, and he cannot be put back.
        draft.toggle(pike)
        let after = MentoringPresentation.memberChoices(draft, players: players, ownClub: club, state: state)
        #expect(after.map(\.id) == [lane, pike, okafor, young])
        #expect(after.map(\.isChosen) == [true, false, true, false])
        #expect(after.map(\.canToggle) == [true, false, true, true])
    }

    @Test func aGoneMemberWithNoSavedNameIsNeverShownByHisKey() {
        var state = MentoringState()
        state.groups = [recorded]
        let choices = MentoringPresentation.memberChoices(MentoringGroupDraft(editing: recorded), players: [],
                                                          ownClub: club, state: state)
        #expect(choices.map(\.id) == [okafor, lane, pike])
        #expect(choices.allSatisfy { $0.name == TrainingPresentation.unnamed })
    }

    @Test func aNewGroupListsOnlyTheSquadsPlayers() {
        // Pike is in another group and has left: he is nowhere in a new group's list.
        var state = MentoringState()
        state.groups = [recorded]
        let players = [player(okafor, "Okafor", age: 30), player(young, "Young", age: 18)]
        let choices = MentoringPresentation.memberChoices(MentoringGroupDraft(squad: .firstTeam), players: players,
                                                          ownClub: club, state: state)
        #expect(choices.map(\.id) == [okafor, young])
        #expect(choices.map(\.canToggle) == [false, true])
    }

    @Test func aRowCanBeTickedOnlyWhileFewerThanThreeAreChosen() {
        let players = [player(okafor, "Okafor", age: 30), player(lane, "Lane", age: 20), player(pike, "Pike", age: 17),
                       player(young, "Young", age: 18)]
        var draft = MentoringGroupDraft(squad: .firstTeam)
        func toggles() -> [Bool] {
            MentoringPresentation.memberChoices(draft, players: players, ownClub: club, state: MentoringState()).map(\.canToggle)
        }
        #expect(toggles() == [true, true, true, true])
        draft.toggle(okafor); draft.toggle(lane)
        #expect(toggles() == [true, true, true, true])
        draft.toggle(pike)
        #expect(draft.members == [okafor, lane, pike])
        #expect(toggles() == [true, true, true, false])
        draft.toggle(lane)
        #expect(draft.members == [okafor, pike])
        #expect(toggles() == [true, true, true, true])
    }

    @Test func theEditorsLabels() {
        #expect(Squad.allCases.map(MentoringPresentation.hierarchyEditorTitle)
                == ["First team hierarchy", "U21 hierarchy", "U18 hierarchy"])
        let first = MentoringPresentation.hierarchyEditorHint(.firstTeam)
        #expect(first.contains("Dynamics screen"))
        #expect(!first.contains("own page"))
        for squad in [Squad.u21, .u18] {
            #expect(MentoringPresentation.hierarchyEditorHint(squad).contains("own page"))
        }
        #expect(MentoringPresentation.hierarchyEditorHint(.u21).contains("U21s"))
        #expect(MentoringPresentation.hierarchyEditorHint(.u18).contains("U18s"))

        #expect(MentoringPresentation.groupEditorTitle(MentoringGroupDraft(squad: .firstTeam)) == "Add a first-team group")
        #expect(MentoringPresentation.groupEditorTitle(MentoringGroupDraft(squad: .u21)) == "Add a U21 group")
        #expect(MentoringPresentation.groupEditorTitle(MentoringGroupDraft(squad: .u18)) == "Add a U18 group")
        #expect(MentoringPresentation.groupEditorTitle(MentoringGroupDraft(editing: recorded)) == "Change the group")

        #expect((0...3).map(MentoringPresentation.chosenText)
                == ["0 of 3 chosen", "1 of 3 chosen", "2 of 3 chosen", "3 of 3 chosen"])

        #expect(MentoringPresentation.hierarchyEditorNote == AdvisorText.socialGroupsNotUsed)
        #expect(MentoringPresentation.hierarchyEditorNote
                == "Social groups are kept as entered. They do not change the advice.")
    }

    @Test func aDraftBeingChangedKeepsItsGroupsSquad() {
        var group = recorded
        group.squad = .u21
        #expect(MentoringGroupDraft(editing: group).squad == .u21)
        #expect(MentoringGroupDraft(squad: .u18).squad == .u18)
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
        #expect(MentoringPresentation.readOn(readDay) == "read Sat 14 Nov")
        #expect(MentoringPresentation.readOn(readDay) == "read \(DayText.short(readDay))")
        #expect([MentoringPresentation.recordTitle, MentoringPresentation.addTitle, MentoringPresentation.editTitle,
                 MentoringPresentation.endTitle] == ["Record as set", "Add a group", "Edit", "End group"])
        #expect(TrainingView.allCases.map(\.title) == ["Retraining", "Mentoring"])
        #expect(MentoringEditing.hierarchy(.u21).id != MentoringEditing.hierarchy(.firstTeam).id)
        let draft = MentoringGroupDraft(squad: .firstTeam)
        #expect(MentoringEditing.group(draft).id != MentoringEditing.hierarchy(.firstTeam).id)
    }
}
