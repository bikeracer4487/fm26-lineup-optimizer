import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

@MainActor @Suite struct AppModelMentoringTests {
    private let today = TestModel.today

    private func both() throws -> TestModel {
        let t = try TestModel()
        try t.importFirstTeam()
        try t.importU21()
        return t
    }

    private func ids(_ model: AppModel, _ squad: Squad) -> [PlayerID] {
        (model.squad.book.current[squad] ?? []).map(\.id)
    }

    /// The engine's first suggested group for the squad, from the model's players.
    private func suggestion(_ model: AppModel, _ squad: Squad) throws -> SuggestedGroup {
        let request = MentoringRequest(
            squad: squad, players: model.squad.book.allPlayers, ownClub: model.ownClub, dynamics: [:],
            dynamicsUpdatedOn: nil, groups: [], readings: [:], names: [:], leaving: [], asOf: model.settings.currentDate)
        return try #require(try Mentoring.report(request, parameters: .fm27).suggestions.first)
    }

    private func members(_ group: SuggestedGroup) -> [PlayerID] { [group.lead] + group.members.map(\.player) }

    private func live(_ model: AppModel) -> [MentoringGroup] { model.mentoring.groups.filter(\.isLive) }

    // MARK: Readings

    @Test func anImportTakesAReadingForEveryPlayer() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let squad = ids(t.model, .firstTeam)
        #expect(!squad.isEmpty)
        for id in squad { #expect(t.model.mentoring.readings[id]?.map(\.day) == [today]) }
        #expect(t.reopened().mentoring == t.model.mentoring)
    }

    @Test func twoImportsOnOneDayLeaveOneReadingEach() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        try t.importFirstTeam()
        for id in ids(t.model, .firstTeam) { #expect(t.model.mentoring.readings[id]?.count == 1) }
    }

    @Test func aStateFromBeforeThisPlanStartsWithReadingsFromTheSquadsHeld() throws {
        let t = try both()
        try FileManager.default.removeItem(at: t.directory.appendingPathComponent("mentoring.json"))
        let reopened = t.reopened()
        for squad in [Squad.firstTeam, .u21] {
            for id in ids(reopened, squad) { #expect(reopened.mentoring.readings[id]?.map(\.day) == [today]) }
        }
        #expect(reopened.notices.isEmpty)
        #expect(t.reopened().mentoring == reopened.mentoring)
    }

    // MARK: Hierarchy

    @Test func settingTheHierarchyStampsTheDayAndKeepsOtherSquads() throws {
        let t = try both()
        let first = ids(t.model, .firstTeam)[0], young = ids(t.model, .u21)[0]
        t.model.setDynamics([young: PlayerDynamics(standing: .influential, socialGroup: .core)], for: .u21)
        t.model.setDynamics([first: PlayerDynamics(standing: .teamLeader, socialGroup: .core)], for: .firstTeam)
        #expect(t.model.mentoring.dynamics[young]?.standing == .influential)
        #expect(t.model.mentoring.dynamics[first]?.standing == .teamLeader)
        #expect(t.model.mentoring.dynamicsUpdatedOn == [.firstTeam: today, .u21: today])
        t.model.setDynamics([:], for: .firstTeam)
        #expect(t.model.mentoring.dynamics[first] == nil)
        #expect(t.model.mentoring.dynamics[young]?.standing == .influential)
        #expect(t.reopened().mentoring == t.model.mentoring)
    }

    @Test func savingTheSameHierarchyAgainStampsTheNewDay() throws {
        let t = try both()
        t.model.setDynamics([:], for: .firstTeam)
        var settings = t.model.settings
        settings.currentDate = today.adding(days: 5)
        t.model.update(settings)
        t.model.setDynamics([:], for: .firstTeam)
        #expect(t.model.mentoring.dynamicsUpdatedOn[.firstTeam] == today.adding(days: 5))
    }

    @Test func anEntryOfOthersWithNoGroupIsNotKept() throws {
        let t = try both()
        let ids = ids(t.model, .firstTeam)
        t.model.setDynamics([ids[0]: PlayerDynamics(), ids[1]: PlayerDynamics(standing: .others, socialGroup: .core),
                             ids[2]: PlayerDynamics(standing: .influential)], for: .firstTeam)
        #expect(t.model.mentoring.dynamics[ids[0]] == nil)
        #expect(t.model.mentoring.dynamics[ids[1]] != nil)
        #expect(t.model.mentoring.dynamics[ids[2]] != nil)
    }

    // MARK: Groups

    @Test func recordingASuggestionMakesAGroupFromToday() throws {
        let t = try both()
        let group = try suggestion(t.model, .firstTeam)
        t.model.recordGroup(group, in: .firstTeam)
        let recorded = try #require(live(t.model).first)
        #expect(live(t.model).count == 1)
        #expect(recorded.squad == .firstTeam)
        #expect(recorded.startedOn == today)
        #expect(Set(recorded.members.map(\.player)) == Set(members(group)))
        #expect(recorded.members.allSatisfy { $0.joinedOn == today && $0.leftOn == nil })
        for member in members(group) { #expect(t.model.mentoring.names[member] != nil) }
        let names = [group.leadName] + group.members.map(\.name)
        #expect(t.model.notices.contains { $0.text == AdvisorText.recorded(names: names) })
        #expect(t.reopened().mentoring.groups == t.model.mentoring.groups)
    }

    @Test func aSecondClickWithinHalfASecondIsDropped() throws {
        let t = try both()
        let group = try suggestion(t.model, .firstTeam)
        t.input.tick = 0
        t.input.uptime = 1_000
        t.model.recordGroup(group, in: .firstTeam)
        let other = Array(ids(t.model, .u21).prefix(3))
        t.input.uptime += AppModel.trainingActionInterval / 2
        t.model.saveGroup(MentoringGroupDraft(squad: .u21, members: other))
        t.model.endGroup(live(t.model)[0].id)
        #expect(live(t.model).count == 1)
        #expect(live(t.model)[0].endedOn == nil)
    }

    @Test func recordingItAgainDoesNothingWhileAMemberIsInALiveGroup() throws {
        let t = try both()
        let group = try suggestion(t.model, .firstTeam)
        t.model.recordGroup(group, in: .firstTeam)
        t.model.recordGroup(group, in: .firstTeam)
        #expect(t.model.mentoring.groups.count == 1)
    }

    @Test func aGroupNeedsExactlyThree() throws {
        let t = try both()
        let squad = ids(t.model, .firstTeam)
        let two = MentoringGroupDraft(squad: .firstTeam, members: Array(squad[0..<2]))
        let four = MentoringGroupDraft(squad: .firstTeam, members: Array(squad[0..<4]))
        let three = MentoringGroupDraft(squad: .firstTeam, members: Array(squad[0..<3]))
        #expect(t.model.mentoringProblem(of: two) != nil)
        #expect(t.model.mentoringProblem(of: four) != nil)
        #expect(t.model.mentoringProblem(of: three) == nil)
        t.model.saveGroup(two); t.model.saveGroup(four)
        #expect(t.model.mentoring.groups.isEmpty)
        t.model.saveGroup(three)
        #expect(live(t.model).count == 1)
        #expect(live(t.model)[0].startedOn == today)
    }

    @Test func theSameMemberTwiceIsNotThree() throws {
        let t = try both()
        let squad = ids(t.model, .firstTeam)
        #expect(t.model.mentoringProblem(of: MentoringGroupDraft(squad: .firstTeam, members: [squad[0], squad[0], squad[1]])) != nil)
    }

    @Test func everyMemberMustBeACurrentPlayerOfTheSquad() throws {
        let t = try both()
        let first = ids(t.model, .firstTeam), young = ids(t.model, .u21)
        #expect(t.model.mentoringProblem(of: MentoringGroupDraft(squad: .firstTeam, members: [first[0], first[1], young[0]])) != nil)
        #expect(t.model.mentoringProblem(of: MentoringGroupDraft(squad: .firstTeam, members: [first[0], first[1], .fmrte(999_999)])) != nil)
    }

    @Test func aPlayerInAnotherLiveGroupCannotBeAdded() throws {
        let t = try both()
        let squad = ids(t.model, .firstTeam)
        t.model.saveGroup(MentoringGroupDraft(squad: .firstTeam, members: Array(squad[0..<3])))
        let overlapping = MentoringGroupDraft(squad: .firstTeam, members: [squad[2], squad[3], squad[4]])
        #expect(t.model.mentoringProblem(of: overlapping) != nil)
        t.model.saveGroup(overlapping)
        #expect(t.model.mentoring.groups.count == 1)
        // Once that group has ended its members are free.
        t.input.uptime += 10
        t.model.endGroup(t.model.mentoring.groups[0].id)
        #expect(t.model.mentoringProblem(of: overlapping) == nil)
    }

    @Test func aPlayerOutOnLoanCannotBeInAGroup() throws {
        let t = try TestModel()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        // Cell 96 of a row is the club the player is loaned to.
        var rows = try Captures.firstTeam.split(whereSeparator: \.isNewline)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
        rows[0][96] = "\"Rovers\""
        t.importSquad(.firstTeam, paste: rows.map { $0.joined(separator: "\t") }.joined(separator: "\n") + "\n",
                      grids: try Captures.firstTeamGrids)
        let squad = t.model.squad.book.current[.firstTeam] ?? []
        let away = try #require(squad.first { player in
            if case .loanedOut = t.model.squad.book.loanStatus(of: player, override: "Oxford City") { return true }
            return false
        })
        let others = squad.filter { $0.id != away.id }.prefix(2).map(\.id)
        #expect(t.model.mentoringProblem(of: MentoringGroupDraft(squad: .firstTeam, members: others + [away.id])) == AppModel.MentoringProblemLabel.onLoan)
        #expect(t.model.mentoringProblem(of: MentoringGroupDraft(squad: .firstTeam, members: others + [squad.last!.id])) == nil)
    }

    @Test func swappingAMemberKeepsTheOthersStart() throws {
        let t = try both()
        let squad = ids(t.model, .firstTeam)
        t.model.saveGroup(MentoringGroupDraft(squad: .firstTeam, members: Array(squad[0..<3])))
        var settings = t.model.settings
        settings.currentDate = today.adding(days: 10)
        t.model.update(settings)
        var draft = MentoringGroupDraft(editing: live(t.model)[0])
        #expect(!draft.isNew)
        draft.members = [squad[0], squad[1], squad[3]]
        t.model.saveGroup(draft)
        let group = try #require(t.model.mentoring.groups.first)
        #expect(t.model.mentoring.groups.count == 1)
        #expect(group.startedOn == today)
        func member(_ id: PlayerID) -> MentoringMember? { group.members.first { $0.player == id } }
        #expect(member(squad[0])?.joinedOn == today && member(squad[0])?.leftOn == nil)
        #expect(member(squad[1])?.joinedOn == today && member(squad[1])?.leftOn == nil)
        #expect(member(squad[2])?.leftOn == today.adding(days: 10))
        #expect(member(squad[3])?.joinedOn == today.adding(days: 10) && member(squad[3])?.leftOn == nil)
        #expect(Set(group.current.map(\.player)) == [squad[0], squad[1], squad[3]])
        #expect(t.model.mentoring.names[squad[3]] != nil)
    }

    @Test func aDraftWithTheSameThreeMembersChangesNothing() throws {
        let t = try both()
        let squad = ids(t.model, .firstTeam)
        t.model.saveGroup(MentoringGroupDraft(squad: .firstTeam, members: Array(squad[0..<3])))
        let before = t.model.mentoring
        t.model.saveGroup(MentoringGroupDraft(editing: live(t.model)[0]))
        #expect(t.model.mentoring == before)
    }

    @Test func endingAGroupKeepsItWithItsEndDay() throws {
        let t = try both()
        let squad = ids(t.model, .firstTeam)
        t.model.saveGroup(MentoringGroupDraft(squad: .firstTeam, members: Array(squad[0..<3])))
        var settings = t.model.settings
        settings.currentDate = today.adding(days: 20)
        t.model.update(settings)
        t.model.endGroup(t.model.mentoring.groups[0].id)
        #expect(t.model.mentoring.groups.count == 1)
        #expect(t.model.mentoring.groups[0].endedOn == today.adding(days: 20))
        #expect(t.reopened().mentoring.groups == t.model.mentoring.groups)
    }

    @Test func aMemberWhoLeavesTheSquadStaysInTheGroup() throws {
        let t = try both()
        let group = try suggestion(t.model, .firstTeam)
        t.model.recordGroup(group, in: .firstTeam)
        let gone = group.members[0]
        // The first team imported again without him.
        let rows = try Captures.firstTeam.split(whereSeparator: \.isNewline).map(String.init)
        let kept = rows.filter { !$0.contains("\t\(gone.name)\t") && !$0.contains("\"\(gone.name)\"") }
        #expect(kept.count < rows.count)
        t.importSquad(.firstTeam, paste: kept.joined(separator: "\n") + "\n", grids: try Captures.firstTeamGrids)
        #expect(!t.model.players.contains { $0.id == gone.player })
        let recorded = try #require(live(t.model).first)
        #expect(recorded.current.map(\.player).contains(gone.player))
        #expect(t.model.mentoring.names[gone.player] == gone.name)
        #expect(t.reopened().mentoring.names[gone.player] == gone.name)
    }

    @Test func aGroupWithAMemberWhoHasLeftCanBeChangedBySwappingHimOut() throws {
        let t = try both()
        let group = try suggestion(t.model, .firstTeam)
        t.model.recordGroup(group, in: .firstTeam)
        let gone = group.members[0]
        let rows = try Captures.firstTeam.split(whereSeparator: \.isNewline).map(String.init)
        let kept = rows.filter { !$0.contains("\t\(gone.name)\t") && !$0.contains("\"\(gone.name)\"") }
        t.importSquad(.firstTeam, paste: kept.joined(separator: "\n") + "\n", grids: try Captures.firstTeamGrids)
        var settings = t.model.settings
        settings.currentDate = today.adding(days: 7)
        t.model.update(settings)

        var draft = MentoringGroupDraft(editing: try #require(live(t.model).first))
        #expect(t.model.mentoringProblem(of: draft) == AppModel.MentoringProblemLabel.notInSquad)
        let row = try #require(t.model.memberChoices(for: draft).first { $0.id == gone.player })
        #expect(row.name == gone.name)
        #expect(row.isChosen && row.canToggle)
        #expect(row.unavailableText == "No longer in the squad")

        draft.toggle(gone.player)
        let free = try #require(t.model.memberChoices(for: draft).first { !$0.isChosen && $0.canToggle })
        draft.toggle(free.id)
        #expect(t.model.mentoringProblem(of: draft) == nil)
        t.model.saveGroup(draft)

        let saved = try #require(live(t.model).first)
        #expect(Set(saved.current.map(\.player)) == Set(members(group).filter { $0 != gone.player } + [free.id]))
        #expect(saved.members.first { $0.player == gone.player }?.leftOn == today.adding(days: 7))
        #expect(saved.members.first { $0.player == free.id }?.joinedOn == today.adding(days: 7))
    }

    @Test func aGroupBeingChangedIsCheckedAgainstItsOwnSquad() throws {
        let t = try both()
        let young = ids(t.model, .u21), first = ids(t.model, .firstTeam)
        let choosable = t.model.memberChoices(for: MentoringGroupDraft(squad: .u21)).filter(\.canToggle).map(\.id)
        t.model.saveGroup(MentoringGroupDraft(squad: .u21, members: Array(choosable.prefix(3))))
        let group = try #require(live(t.model).first)
        #expect(group.squad == .u21)

        var draft = MentoringGroupDraft(editing: group)
        #expect(draft.squad == .u21)
        #expect(t.model.memberChoices(for: draft).map(\.id).allSatisfy(young.contains))
        // A first-team player put in is not a player of the group's squad.
        draft.toggle(draft.members[0])
        draft.toggle(first[0])
        #expect(t.model.mentoringProblem(of: draft) == AppModel.MentoringProblemLabel.notInSquad)
    }

    @Test func changingMentoringDoesNotReplan() throws {
        let t = try both()
        let planned = t.model.timesPlanned
        let squad = ids(t.model, .firstTeam)
        t.model.setDynamics([squad[0]: PlayerDynamics(standing: .teamLeader)], for: .firstTeam)
        t.model.saveGroup(MentoringGroupDraft(squad: .firstTeam, members: Array(squad[0..<3])))
        t.model.endGroup(t.model.mentoring.groups[0].id)
        #expect(t.model.timesPlanned == planned)
    }

    @Test func everyChangeBumpsTheGeneration() throws {
        let t = try both()
        let before = t.model.mentoringGeneration
        t.model.setDynamics([ids(t.model, .firstTeam)[0]: PlayerDynamics(standing: .teamLeader)], for: .firstTeam)
        #expect(t.model.mentoringGeneration > before)
    }

    // MARK: The advice

    /// Both squads, the club named and a tactic, so the other advisors' advice is ready.
    private func advised() throws -> TestModel {
        let t = try both()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        t.model.addTactic(named: "4-2-3-1")
        return t
    }

    /// The engine's report for the squad from the model's saved state, with `leaving` handed on.
    private func engineReport(_ model: AppModel, _ squad: Squad, leaving: Set<PlayerID>) throws -> MentoringReport {
        let request = MentoringRequest(
            squad: squad, players: model.squad.book.allPlayers, ownClub: model.ownClub,
            dynamics: model.mentoring.dynamics, dynamicsUpdatedOn: model.mentoring.dynamicsUpdatedOn[squad],
            groups: model.mentoring.groups, readings: model.mentoring.readings, names: model.mentoring.names,
            leaving: leaving, asOf: model.settings.currentDate)
        return try Mentoring.report(request, parameters: .fm27)
    }

    private func isReady(_ advice: MentoringAdvice) -> Bool {
        if case .ready = advice { true } else { false }
    }

    @Test func mentoringWorksWithNoTactic() throws {
        let t = try both()
        #expect(t.model.adviceState == .needsTactic([]))
        let advice = t.model.mentoringAdvice(for: .firstTeam)
        #expect(advice == .ready(try engineReport(t.model, .firstTeam, leaving: [])))
        guard case .ready(let report) = advice else { Issue.record("expected advice, got \(advice)"); return }
        #expect(!report.suggestions.isEmpty)
        #expect(isReady(t.model.mentoringAdvice(for: .u21)))
    }

    @Test func aSquadNotImportedNeedsItsSquad() throws {
        let t = try TestModel()
        #expect(t.model.mentoringAdvice(for: .firstTeam) == .needsSquad)
        try t.importFirstTeam()
        #expect(isReady(t.model.mentoringAdvice(for: .firstTeam)))
        #expect(t.model.mentoringAdvice(for: .u21) == .needsSquad)
        #expect(t.model.mentoringAdvice(for: .u18) == .needsSquad)
        #expect(t.model.mentoringSheet(for: .u21).notReady == "The U21s have not been imported yet.")
    }

    @Test func theAdviceIsKeptUntilSomethingChanges() throws {
        let t = try both()
        let before = t.model.mentoringAdvice(for: .firstTeam)
        let times = t.model.timesMentoringWorkedOut
        #expect(t.model.mentoringAdvice(for: .firstTeam) == before)
        _ = t.model.mentoringSheet(for: .firstTeam)
        #expect(t.model.timesMentoringWorkedOut == times)

        let lead = ids(t.model, .firstTeam)[0]
        t.model.setDynamics([lead: PlayerDynamics(standing: .teamLeader)], for: .firstTeam)
        let after = t.model.mentoringAdvice(for: .firstTeam)
        #expect(t.model.timesMentoringWorkedOut == times + 1)
        #expect(after != before)
        #expect(after == .ready(try engineReport(t.model, .firstTeam, leaving: [])))
        _ = t.model.mentoringAdvice(for: .firstTeam)
        #expect(t.model.timesMentoringWorkedOut == times + 1)

        // Each squad is worked out on its own.
        _ = t.model.mentoringAdvice(for: .u21)
        #expect(t.model.timesMentoringWorkedOut == times + 2)

        t.model.replan()
        _ = t.model.mentoringAdvice(for: .firstTeam)
        #expect(t.model.timesMentoringWorkedOut == times + 3)
    }

    @Test func aNewDateWorksTheAdviceOutAgain() throws {
        let t = try both()
        t.model.setDynamics([ids(t.model, .firstTeam)[0]: PlayerDynamics(standing: .teamLeader)], for: .firstTeam)
        #expect(t.model.mentoringSheet(for: .firstTeam).staleText == nil)
        let times = t.model.timesMentoringWorkedOut
        var settings = t.model.settings
        settings.currentDate = today.adding(days: 29)
        t.model.update(settings)
        let sheet = t.model.mentoringSheet(for: .firstTeam)
        #expect(t.model.timesMentoringWorkedOut == times + 1)
        #expect(sheet.staleText != nil)
        #expect(sheet.updatedText == "Updated \(DayText.short(today))")
    }

    @Test func playerRemovalsLeaversAreHandedOnWhenTheAdviceIsReady() throws {
        let t = try advised()
        guard case .ready(let advice) = t.model.adviceState else { Issue.record("expected advice"); return }
        let leaving = advice.removal.advisedToLeave
        #expect(!leaving.isEmpty)
        var differs = false
        for squad in [Squad.firstTeam, .u21] {
            let withLeavers = try engineReport(t.model, squad, leaving: leaving)
            #expect(t.model.mentoringAdvice(for: squad) == .ready(withLeavers))
            let withNone = try engineReport(t.model, squad, leaving: [])
            differs = differs || withLeavers != withNone
        }
        // Otherwise the test could not tell the two apart.
        #expect(differs)
    }

    @Test func withNoAdviceNobodyIsHandedOnAsLeaving() throws {
        let t = try both()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        #expect(t.model.adviceState == .needsTactic([]))
        for squad in [Squad.firstTeam, .u21] {
            #expect(t.model.mentoringAdvice(for: squad) == .ready(try engineReport(t.model, squad, leaving: [])))
        }
    }

    @Test func oneSquadsMissingValueDoesNotStopTheOthers() throws {
        let t = try advised()
        guard case .ready = t.model.adviceState else { Issue.record("expected advice"); return }
        var players = try #require(t.model.squad.book.current[.firstTeam])
        let club = t.model.ownClub
        let index = try #require(players.firstIndex { LoanStatus.of($0, ownClub: club) == .own })
        let name = players[index].name
        players[index].attributes[.pressure] = nil
        _ = t.model.squad.book.apply(ImportResult(grid: "test", players: players, warnings: [], money: .weeklyPounds), to: .firstTeam)
        t.model.replan()

        let sentence = ErrorDescriptions.describe(RatingError.missingAttribute(player: name, attribute: .pressure))
        #expect(t.model.mentoringAdvice(for: .firstTeam) == .failed([sentence]))
        #expect(t.model.mentoringSheet(for: .firstTeam).failures == [sentence])
        #expect(isReady(t.model.mentoringAdvice(for: .u21)))
        guard case .ready = t.model.adviceState else { Issue.record("expected advice, got \(t.model.adviceState)"); return }
    }

    @Test func aMemberWhoHasLeftEverySquadIsShownByHisName() throws {
        let t = try both()
        let group = try suggestion(t.model, .firstTeam)
        t.model.recordGroup(group, in: .firstTeam)
        let gone = group.members[0]
        let rows = try Captures.firstTeam.split(whereSeparator: \.isNewline).map(String.init)
        let kept = rows.filter { !$0.contains("\t\(gone.name)\t") && !$0.contains("\"\(gone.name)\"") }
        t.importSquad(.firstTeam, paste: kept.joined(separator: "\n") + "\n", grids: try Captures.firstTeamGrids)
        #expect(!t.model.players.contains { $0.id == gone.player })

        let card = try #require(t.model.mentoringSheet(for: .firstTeam).yours.first)
        #expect(card.titleText.contains(gone.name))
        #expect(card.members.contains { $0.nameText == gone.name })
        #expect(card.warnings.contains(AdvisorText.warning(.notInSquad(gone.player), names: [gone.player: gone.name])))
        let everything = [card.titleText] + card.members.map(\.nameText) + card.warnings
        #expect(!everything.contains { $0.contains(gone.player.key) })
    }

    @Test func dynamicsRowsAndMemberChoicesAreTheSquadsPlayers() throws {
        let t = try both()
        let chosen = try #require(t.model.dynamicsRows(for: .u21).last).id
        t.model.setDynamics([chosen: PlayerDynamics(standing: .influential)], for: .u21)
        let rows = t.model.dynamicsRows(for: .u21)
        #expect(rows == MentoringPresentation.dynamicsRows(
            t.model.squad.book.current[.u21] ?? [], ownClub: t.model.ownClub, dynamics: t.model.mentoring.dynamics))
        #expect(rows.first { $0.id == chosen }?.dynamics.standing == .influential)
        #expect(rows.filter { $0.id != chosen }.allSatisfy { $0.dynamics == PlayerDynamics() })
        t.model.saveGroup(MentoringGroupDraft(squad: .firstTeam, members: Array(ids(t.model, .firstTeam)[0..<3])))
        let choices = t.model.memberChoices(for: MentoringGroupDraft(squad: .firstTeam))
        #expect(choices.map(\.id) == MentoringPresentation.dynamicsRows(
            t.model.squad.book.current[.firstTeam] ?? [], ownClub: t.model.ownClub, dynamics: [:]).map(\.id))
        #expect(choices.prefix(3).allSatisfy { $0.unavailableText != nil })
        #expect(choices.dropFirst(3).allSatisfy { $0.unavailableText == nil })
    }

    // MARK: The squads imported

    @Test func theSquadsImportedAreThoseWithPlayers() throws {
        let t = try TestModel()
        #expect(t.model.importedSquads.isEmpty)
        try t.importU21()
        #expect(t.model.importedSquads == [.u21])
        try t.importFirstTeam()
        #expect(t.model.importedSquads == [.firstTeam, .u21])
        #expect(t.reopened().importedSquads == [.firstTeam, .u21])
    }

    // MARK: The sample states the pictures draw

    private func report(_ model: AppModel, _ squad: Squad = .firstTeam) throws -> MentoringReport {
        let advice = model.mentoringAdvice(for: squad)
        guard case .ready(let report) = advice else {
            Issue.record("expected advice for \(squad), got \(advice)")
            throw SampleDataError(description: "no advice")
        }
        return report
    }

    private func firstTeam(_ model: AppModel) -> [Player] { model.squad.book.current[.firstTeam] ?? [] }

    @Test func theHierarchySampleRaisesThreeFirstTeamPlayersAndHasSuggestions() throws {
        let model = try SampleData.modelWithHierarchy(repositoryRoot: Captures.repositoryRoot)
        let raised = model.mentoring.dynamics.filter { $0.value.standing != .others }
        #expect(raised.count == 3)
        #expect(Set(raised.values.map(\.standing)) == [.teamLeader, .highlyInfluential, .influential])
        #expect(Set(raised.keys).isSubset(of: Set(firstTeam(model).map(\.id))))
        // Social groups for some players, not all.
        #expect(model.mentoring.dynamics.values.contains { $0.socialGroup != nil })
        #expect(model.mentoring.dynamics.count < firstTeam(model).count)
        #expect(model.mentoring.dynamicsUpdatedOn == [.firstTeam: model.settings.currentDate])
        let report = try report(model)
        #expect(!report.byAgeAlone && !report.isStale)
        #expect(!report.suggestions.isEmpty)
        #expect(model.mentoring.groups.isEmpty)
        #expect(model.mentoringSheet(for: .firstTeam).hierarchyLines.count == 4)
        #expect(model.notices.isEmpty)
    }

    @Test func theStaleSampleHasTheFirstTeamsHierarchyEnteredFiveWeeksAgo() throws {
        let model = try SampleData.modelWithStaleHierarchy(repositoryRoot: Captures.repositoryRoot)
        let fresh = try SampleData.modelWithHierarchy(repositoryRoot: Captures.repositoryRoot)
        #expect(model.mentoring.dynamics == fresh.mentoring.dynamics)
        #expect(model.mentoring.dynamicsUpdatedOn == [.firstTeam: model.settings.currentDate.adding(days: -35)])
        #expect(model.settings.currentDate == fresh.settings.currentDate)
        #expect(try report(model).isStale)
        let sheet = model.mentoringSheet(for: .firstTeam)
        #expect(sheet.staleText?.contains("Dynamics screen") == true)
        #expect(model.notices.isEmpty)
    }

    @Test func theGroupSampleHasAMemberWhoseProfessionalismRoseByOneInFiveWeeks() throws {
        let model = try SampleData.modelWithMentoringGroup(repositoryRoot: Captures.repositoryRoot)
        let report = try report(model)
        let review = try #require(report.groups.first)
        #expect(report.groups.count == 1)
        #expect(review.group.startedOn == model.settings.currentDate.adding(days: -35))
        #expect(review.lead != nil)
        let improved = review.members.flatMap { member in member.changes.map { (member, $0) } }.filter { $0.1.change == .improved }
        #expect(improved.count == 1)
        let (member, change) = try #require(improved.first)
        #expect(!member.isLead)
        #expect(change.attribute == .professionalism)
        #expect(change.latest == change.start.map { $0 + 1 })
        #expect(change.weeks == 5)
        #expect(!review.isDoingHarm && !review.hasStoppedWorking)
        #expect(!review.warnings.contains { if case .mayBeDraggedDown = $0 { true } else { false } })
        let card = try #require(model.mentoringSheet(for: .firstTeam).yours.first)
        #expect(card.stateText == nil)
        #expect(card.members.contains { $0.detailText?.contains(AdvisorText.change(change)!) == true })
        #expect(model.notices.isEmpty)
    }

    @Test func theWarningSampleHasALeadWhoMayDragAMemberDownInAmbition() throws {
        let model = try SampleData.modelWithMentoringWarning(repositoryRoot: Captures.repositoryRoot)
        let review = try #require(try report(model).groups.first)
        let dragged = review.warnings.filter { warning in
            if case .mayBeDraggedDown(let above, _, .ambition, let aboveValue, let belowValue) = warning {
                return above == review.lead && aboveValue < belowValue
            }
            return false
        }
        #expect(!dragged.isEmpty)
        // The lead's Ambition was the same at both readings: the group is not doing harm.
        #expect(!review.isDoingHarm)
        let card = try #require(model.mentoringSheet(for: .firstTeam).yours.first)
        #expect(card.stateText == nil)
        #expect(!card.warnings.isEmpty)
    }

    @Test func theStoppedSampleIsFourteenWeeksOldWithNoChange() throws {
        let model = try SampleData.modelWithStoppedGroup(repositoryRoot: Captures.repositoryRoot)
        let review = try #require(try report(model).groups.first)
        #expect(review.group.startedOn == model.settings.currentDate.adding(days: -98))
        #expect(review.hasStoppedWorking && !review.isDoingHarm)
        #expect(review.members.allSatisfy { $0.changes.allSatisfy { $0.change == .noChange } })
        let card = try #require(model.mentoringSheet(for: .firstTeam).yours.first)
        #expect(card.stateText == AdvisorText.state(of: review, parameters: model.planParameters))
        #expect(card.stateText != nil)
    }

    @Test func theFailureSampleStopsTheFirstTeamOnAMissingPressureValue() throws {
        let model = try SampleData.modelWithMentoringFailure(repositoryRoot: Captures.repositoryRoot)
        let missing = firstTeam(model).filter { $0.attributes[.pressure] == nil }
        #expect(missing.count == 1)
        let player = try #require(missing.first)
        let sentence = ErrorDescriptions.describe(RatingError.missingAttribute(player: player.name, attribute: .pressure))
        #expect(model.mentoringAdvice(for: .firstTeam) == .failed([sentence]))
        let sheet = model.mentoringSheet(for: .firstTeam)
        #expect(sheet.failures == [sentence])
        #expect(!sheet.hierarchyLines.isEmpty)
        #expect(!sheet.yours.isEmpty)
        #expect(isReady(model.mentoringAdvice(for: .u21)))
        guard case .ready = model.adviceState else { Issue.record("expected advice, got \(model.adviceState)"); return }
    }
}
