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

    /// The engine's first suggested group for the squad, from the model's players, with the squad's oldest player
    /// handed to the engine as its Team Leader (and nothing saved): with no level entered nothing is suggested.
    private func suggestion(_ model: AppModel, _ squad: Squad) throws -> SuggestedGroup {
        let oldest = try #require((model.squad.book.current[squad] ?? []).max { ($0.age, $1.name) < ($1.age, $0.name) })
        let request = MentoringRequest(
            squad: squad, players: model.squad.book.allPlayers, ownClub: model.ownClub,
            dynamics: [oldest.id: PlayerDynamics(standing: .teamLeader)], dynamicsUpdatedOn: nil, groups: [],
            readings: [:], arrows: [], names: [:], leaving: [], asOf: model.settings.currentDate)
        return try #require(try Mentoring.report(request, parameters: .fm27).suggestions.first)
    }

    private func members(_ group: SuggestedGroup) -> [PlayerID] { group.members.map(\.player) }

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
        #expect(t.model.mentoring.dynamics(for: .u21)[young]?.standing == .influential)
        #expect(t.model.mentoring.dynamics(for: .firstTeam)[first]?.standing == .teamLeader)
        #expect(t.model.mentoring.dynamicsUpdatedOn == [.firstTeam: today, .u21: today])
        t.model.setDynamics([first: PlayerDynamics()], for: .firstTeam)
        #expect(t.model.mentoring.dynamics(for: .firstTeam)[first] == nil)
        #expect(t.model.mentoring.dynamics(for: .u21)[young]?.standing == .influential)
        #expect(t.reopened().mentoring == t.model.mentoring)
    }

    /// The rows of a captured paste, its line endings kept.
    private func rows(_ paste: String) -> [String] {
        paste.components(separatedBy: "\r\n").filter { !$0.isEmpty }
    }

    /// The first team, and the U21 squad from its team-grid capture, which has the first team's column layout, so a row
    /// of one can be pasted with the other.
    private func bothTeamGrids() throws -> TestModel {
        let t = try TestModel()
        try t.importFirstTeam()
        t.importSquad(.u21, paste: try Captures.text("u21-team-grid.tsv"), grids: try Captures.firstTeamGrids)
        return t
    }

    private func paste(_ rows: [String]) -> String { rows.joined(separator: "\r\n") + "\r\n" }

    /// The U21 team-grid capture's rows, and the first team's.
    private func youthRows() throws -> [String] { rows(try Captures.text("u21-team-grid.tsv")) }
    private func firstRows() throws -> [String] { rows(try Captures.firstTeam) }

    private func importU21(_ t: TestModel, _ rows: [String]) throws {
        t.importSquad(.u21, paste: paste(rows), grids: try Captures.firstTeamGrids)
    }

    private func importFirstTeam(_ t: TestModel, _ rows: [String]) throws {
        t.importSquad(.firstTeam, paste: paste(rows), grids: try Captures.firstTeamGrids)
    }

    private func lastChange(_ model: AppModel) -> SquadChange? {
        if case .imported(let summary)? = model.lastImport { summary.change } else { nil }
    }

    /// The entries the engine is handed for the squad's own players.
    private func inUse(_ model: AppModel, _ squad: Squad) -> [PlayerID: PlayerDynamics] {
        let players = Set(ids(model, squad))
        let request = model.mentoringRequest(for: squad, asOf: model.settings.currentDate)
        return request.dynamics.filter { players.contains($0.key) }
    }

    /// The squads from their team grids, with the U21 player in the capture's second row (the one to be promoted)
    /// entered as Team Leader and another as Influential, and two first-team players entered.
    private struct Promotion {
        let t: TestModel
        let promoted: Player
        let staysYoung: Player
        let u21Entries: [PlayerID: PlayerDynamics]
        let firstEntries: [PlayerID: PlayerDynamics]
    }

    private func promotion() throws -> Promotion {
        let t = try bothTeamGrids()
        let youth = try youthRows()
        let promoted = try #require(t.model.squad.book.current[.u21]?.first { youth[1].contains("\"\($0.name)\"") })
        let staysYoung = try #require(t.model.squad.book.current[.u21]?.first { $0.id != promoted.id })
        let first = ids(t.model, .firstTeam)
        let u21Entries = [promoted.id: PlayerDynamics(standing: .teamLeader, socialGroup: .core),
                          staysYoung.id: PlayerDynamics(standing: .influential, socialGroup: .core)]
        let firstEntries = [first[0]: PlayerDynamics(standing: .influential, socialGroup: .core),
                            first[1]: PlayerDynamics(standing: .others, socialGroup: .secondary("A"))]
        t.model.setDynamics(u21Entries, for: .u21)
        t.model.setDynamics(firstEntries, for: .firstTeam)
        return Promotion(t: t, promoted: promoted, staysYoung: staysYoung, u21Entries: u21Entries,
                         firstEntries: firstEntries)
    }

    /// He reads as Others with no social group in the squad: in what the engine is handed, the advice, the hierarchy
    /// lines and the editor's row; and the squad's own entries are those given.
    private func expectOthers(_ model: AppModel, _ player: Player, in squad: Squad,
                              entries: [PlayerID: PlayerDynamics]) throws {
        #expect(ids(model, squad).contains(player.id))
        let request = model.mentoringRequest(for: squad, asOf: model.settings.currentDate)
        #expect(request.dynamics[player.id] == nil)
        #expect(inUse(model, squad) == entries)
        var expected = request
        expected.dynamics = entries
        #expect(model.mentoringAdvice(for: squad) == .ready(try Mentoring.report(expected, parameters: .fm27)))
        #expect(!model.mentoringSheet(for: squad).hierarchyLines.contains { $0.contains(player.name) })
        #expect(model.dynamicsRows(for: squad).first { $0.id == player.id }?.dynamics == PlayerDynamics())
    }

    @Test func anEntryIsNotUsedInAnotherSquadWhenTheOldSquadIsImportedFirst() throws {
        let p = try promotion()
        let youth = try youthRows()
        try importU21(p.t, youth.enumerated().filter { $0.offset != 1 }.map(\.element))
        try importFirstTeam(p.t, try firstRows() + [youth[1]])
        // He left the U21s and joined the first team: the squad book sees no move.
        #expect(lastChange(p.t.model)?.movedIn == [])
        #expect(lastChange(p.t.model)?.added == [p.promoted.id])

        for model in [p.t.model, p.t.reopened()] {
            try expectOthers(model, p.promoted, in: .firstTeam, entries: p.firstEntries)
            #expect(inUse(model, .u21) == [p.staysYoung.id: p.u21Entries[p.staysYoung.id]!])
        }
    }

    @Test func anEntryIsNotUsedInAnotherSquadWhenTheNewSquadIsImportedFirst() throws {
        let p = try promotion()
        let youth = try youthRows()
        try importFirstTeam(p.t, try firstRows() + [youth[1]])
        #expect(lastChange(p.t.model)?.movedIn == [p.promoted.id])
        try importU21(p.t, youth.enumerated().filter { $0.offset != 1 }.map(\.element))

        for model in [p.t.model, p.t.reopened()] {
            try expectOthers(model, p.promoted, in: .firstTeam, entries: p.firstEntries)
            #expect(inUse(model, .u21) == [p.staysYoung.id: p.u21Entries[p.staysYoung.id]!])
        }
    }

    @Test func enteringHimInHisNewSquadGivesHimTheLevelEnteredThere() throws {
        let p = try promotion()
        let youth = try youthRows()
        try importFirstTeam(p.t, try firstRows() + [youth[1]])
        var entries = Dictionary(p.t.model.dynamicsRows(for: .firstTeam).map { ($0.id, $0.dynamics) },
                                 uniquingKeysWith: { first, _ in first })
        let entered = PlayerDynamics(standing: .highlyInfluential, socialGroup: .secondary("B"))
        entries[p.promoted.id] = entered
        p.t.model.setDynamics(entries, for: .firstTeam)
        for model in [p.t.model, p.t.reopened()] {
            #expect(inUse(model, .firstTeam)[p.promoted.id] == entered)
            #expect(model.mentoringSheet(for: .firstTeam).hierarchyLines
                .contains("Highly Influential: \(p.promoted.name)."))
        }

        // His entry is now the first team's: back in the U21s he reads as Others until entered there again.
        try importU21(p.t, youth)
        #expect(lastChange(p.t.model)?.movedIn == [p.promoted.id])
        for model in [p.t.model, p.t.reopened()] {
            try expectOthers(model, p.promoted, in: .u21, entries: [p.staysYoung.id: p.u21Entries[p.staysYoung.id]!])
        }
    }

    @Test func anEntryIsInUseAgainWhenItsPlayerComesBackToItsSquad() throws {
        let p = try promotion()
        let youth = try youthRows()
        try importFirstTeam(p.t, try firstRows() + [youth[1]])
        try importU21(p.t, youth)
        #expect(lastChange(p.t.model)?.movedIn == [p.promoted.id])
        for model in [p.t.model, p.t.reopened()] {
            #expect(inUse(model, .u21) == p.u21Entries)
            #expect(model.mentoringSheet(for: .u21).hierarchyLines.contains("Team Leader: \(p.promoted.name)."))
            #expect(inUse(model, .firstTeam) == p.firstEntries)
        }
    }

    @Test func aPartialPasteThenTheFullOneLosesNoEntry() throws {
        let p = try promotion()
        let first = try firstRows()
        try importFirstTeam(p.t, Array(first.dropFirst(2)))
        #expect(lastChange(p.t.model)?.removed.count == 2)
        try importFirstTeam(p.t, first)
        for model in [p.t.model, p.t.reopened()] {
            #expect(inUse(model, .firstTeam) == p.firstEntries)
            #expect(inUse(model, .u21) == p.u21Entries)
        }
    }

    @Test func aPlayerWhoStaysInHisSquadAcrossAnImportKeepsHisEntry() throws {
        let p = try promotion()
        try importFirstTeam(p.t, try firstRows())
        for model in [p.t.model, p.t.reopened()] {
            #expect(inUse(model, .firstTeam) == p.firstEntries)
            #expect(inUse(model, .u21) == p.u21Entries)
        }
    }

    @Test func aMentoringFileWhoseEntriesHaveNoSquadOpensWithNoNoticeAndUsesNone() throws {
        let p = try promotion()
        // The file as written before each entry kept its squad: the entries under "dynamics", with no squad.
        let file = p.t.directory.appendingPathComponent("mentoring.json")
        var root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        var value = try #require(root["value"] as? [String: Any])
        value.removeValue(forKey: "hierarchy")
        let old = p.u21Entries.merging(p.firstEntries) { first, _ in first }
        value["dynamics"] = try JSONSerialization.jsonObject(with: JSONEncoder().encode(old))
        root["value"] = value
        try JSONSerialization.data(withJSONObject: root).write(to: file)

        let reopened = p.t.reopened()
        #expect(reopened.notices.isEmpty)
        #expect(inUse(reopened, .firstTeam).isEmpty)
        #expect(inUse(reopened, .u21).isEmpty)
        #expect(reopened.mentoring.readings == p.t.model.mentoring.readings)
        #expect(reopened.mentoring.dynamicsUpdatedOn == p.t.model.mentoring.dynamicsUpdatedOn)

        // The next save drops them.
        let first = try #require(ids(reopened, .firstTeam).first)
        reopened.setDynamics([first: PlayerDynamics(standing: .teamLeader)], for: .firstTeam)
        let saved = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        #expect((saved["value"] as? [String: Any])?["dynamics"] == nil)
        #expect(p.t.reopened().mentoring.dynamics(for: .firstTeam) == [first: PlayerDynamics(standing: .teamLeader)])
    }

    @Test func savingAHierarchyKeepsTheEntryOfAPlayerOutOnLoan() throws {
        let t = try TestModel()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        // Cell 96 of a row is the club the player is loaned to.
        var cells = rows(try Captures.firstTeam)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
        cells[0][96] = "\"Rovers\""
        t.importSquad(.firstTeam, paste: cells.map { $0.joined(separator: "\t") }.joined(separator: "\r\n") + "\r\n",
                      grids: try Captures.firstTeamGrids)
        let squad = t.model.squad.book.current[.firstTeam] ?? []
        let away = try #require(squad.first { player in
            if case .loanedOut = t.model.squad.book.loanStatus(of: player, override: "Oxford City") { return true }
            return false
        })
        let home = try #require(squad.first { $0.id != away.id })
        t.model.setDynamics([away.id: PlayerDynamics(standing: .teamLeader, socialGroup: .core),
                             home.id: PlayerDynamics(standing: .influential)], for: .firstTeam)

        // The editor's rows leave him out; saving them as the editor does keeps his entry.
        let rows = t.model.dynamicsRows(for: .firstTeam)
        #expect(!rows.contains { $0.id == away.id })
        var entries = Dictionary(rows.map { ($0.id, $0.dynamics) }, uniquingKeysWith: { first, _ in first })
        entries[home.id] = PlayerDynamics()
        t.model.setDynamics(entries, for: .firstTeam)

        #expect(t.model.mentoring.dynamics(for: .firstTeam)[away.id]
                == PlayerDynamics(standing: .teamLeader, socialGroup: .core))
        #expect(t.model.mentoring.dynamics(for: .firstTeam)[home.id] == nil)
        #expect(t.reopened().mentoring.hierarchy == t.model.mentoring.hierarchy)
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
        #expect(t.model.mentoring.dynamics(for: .firstTeam)[ids[0]] == nil)
        #expect(t.model.mentoring.dynamics(for: .firstTeam)[ids[1]] != nil)
        #expect(t.model.mentoring.dynamics(for: .firstTeam)[ids[2]] != nil)
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
        let names = group.members.map(\.name)
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
            dynamics: model.mentoring.dynamics(for: squad), dynamicsUpdatedOn: model.mentoring.dynamicsUpdatedOn[squad],
            groups: model.mentoring.groups, readings: model.mentoring.readings, arrows: model.mentoring.arrows,
            names: model.mentoring.names, leaving: leaving, asOf: model.settings.currentDate)
        return try Mentoring.report(request, parameters: .fm27)
    }

    private func isReady(_ advice: MentoringAdvice) -> Bool {
        if case .ready = advice { true } else { false }
    }

    @Test func mentoringWorksWithNoTactic() throws {
        let t = try both()
        // With no level entered nothing would be suggested: the oldest first-team player is entered as Team Leader.
        let oldest = try #require((t.model.squad.book.current[.firstTeam] ?? []).max { ($0.age, $1.name) < ($1.age, $0.name) })
        t.model.setDynamics([oldest.id: PlayerDynamics(standing: .teamLeader)], for: .firstTeam)
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
            t.model.squad.book.current[.u21] ?? [], ownClub: t.model.ownClub,
            dynamics: t.model.mentoring.dynamics(for: .u21)))
        #expect(rows.first { $0.id == chosen }?.dynamics.standing == .influential)
        #expect(rows.filter { $0.id != chosen }.allSatisfy { $0.dynamics == PlayerDynamics() })
        t.model.saveGroup(MentoringGroupDraft(squad: .firstTeam, members: Array(ids(t.model, .firstTeam)[0..<3])))
        let choices = t.model.memberChoices(for: MentoringGroupDraft(squad: .firstTeam))
        #expect(choices.map(\.id) == MentoringPresentation.dynamicsRows(
            t.model.squad.book.current[.firstTeam] ?? [], ownClub: t.model.ownClub, dynamics: [:]).map(\.id))
        #expect(choices.prefix(3).allSatisfy { $0.unavailableText != nil })
        #expect(choices.dropFirst(3).allSatisfy { $0.unavailableText == nil })
    }

    // MARK: Arrows

    private typealias Pair = ArrowsDraft.Pair

    /// The six ordered pairs of three players, in member order.
    private func pairs(_ members: [PlayerID]) -> [Pair] {
        members.flatMap { from in members.filter { $0 != from }.map { Pair(from: from, to: $0) } }
    }

    /// A draft of the three with every one of their six arrows set to `strength`.
    private func everyArrow(_ model: AppModel, _ squad: Squad, _ members: [PlayerID],
                            _ strength: ArrowStrength) -> ArrowsDraft {
        var draft = model.arrowsDraft(for: squad, members: members)
        for pair in pairs(members) { draft.strengths[pair] = strength }
        return draft
    }

    private func setDate(_ model: AppModel, _ day: Day) {
        var settings = model.settings
        settings.currentDate = day
        model.update(settings)
    }

    private func reading(_ model: AppModel, _ pair: Pair, in squad: Squad = .firstTeam) -> ArrowReading? {
        model.mentoring.arrows.first { $0.from == pair.from && $0.to == pair.to && $0.squad == squad }
    }

    /// The first team with its first player loaned to Rovers, the club named.
    private func withOneOutOnLoan() throws -> (t: TestModel, away: Player) {
        let t = try TestModel()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        // Cell 96 of a row is the club the player is loaned to.
        var cells = rows(try Captures.firstTeam)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
        cells[0][96] = "\"Rovers\""
        t.importSquad(.firstTeam, paste: cells.map { $0.joined(separator: "\t") }.joined(separator: "\r\n") + "\r\n",
                      grids: try Captures.firstTeamGrids)
        let away = try #require((t.model.squad.book.current[.firstTeam] ?? []).first { player in
            if case .loanedOut = t.model.squad.book.loanStatus(of: player, override: "Oxford City") { return true }
            return false
        })
        return (t, away)
    }

    @Test func aMentoringFileFromTheInstalledAppOpensWithNoNoticeAndLosesNothing() throws {
        let t = try both()
        let squad = ids(t.model, .firstTeam)
        t.model.setDynamics([squad[0]: PlayerDynamics(standing: .teamLeader, socialGroup: .core)], for: .firstTeam)
        t.model.saveGroup(MentoringGroupDraft(squad: .firstTeam, members: Array(squad[0..<3])))
        let saved = t.model.mentoring
        #expect(!saved.hierarchy.isEmpty && !saved.groups.isEmpty && !saved.readings.isEmpty && !saved.names.isEmpty)
        #expect(saved.arrows.isEmpty)

        // The file as the installed app writes it: no "arrows" key.
        let file = t.directory.appendingPathComponent("mentoring.json")
        var root = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        var value = try #require(root["value"] as? [String: Any])
        #expect(value["arrows"] != nil)
        value.removeValue(forKey: "arrows")
        root["value"] = value
        try JSONSerialization.data(withJSONObject: root).write(to: file)

        let reopened = t.reopened()
        #expect(reopened.notices.isEmpty)
        #expect(reopened.mentoring == saved)
        #expect(reopened.mentoring.hierarchy == saved.hierarchy)
        #expect(reopened.mentoring.dynamicsUpdatedOn == saved.dynamicsUpdatedOn)
        #expect(reopened.mentoring.groups == saved.groups)
        #expect(reopened.mentoring.readings == saved.readings)
        #expect(reopened.mentoring.names == saved.names)
        #expect(reopened.mentoring.arrows.isEmpty)

        // Its next change writes the key.
        reopened.saveArrows(everyArrow(reopened, .firstTeam, Array(squad[0..<3]), .light))
        let written = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        #expect(((written["value"] as? [String: Any])?["arrows"] as? [Any])?.count == 6)
        let again = t.reopened()
        #expect(again.notices.isEmpty)
        #expect(again.mentoring == reopened.mentoring)
        #expect(again.mentoring.groups == saved.groups && again.mentoring.readings == saved.readings)
    }

    @Test func savingTheSheetKeepsSixReadingsFromToday() throws {
        let t = try both()
        let trio = Array(ids(t.model, .firstTeam)[0..<3])
        var draft = t.model.arrowsDraft(for: .firstTeam, members: trio)
        #expect(draft.strengths.isEmpty)
        let strengths: [ArrowStrength] = [.none, .light, .average, .significant, .light, .none]
        for (pair, strength) in zip(pairs(trio), strengths) { draft.strengths[pair] = strength }
        #expect(t.model.arrowsProblem(of: draft) == nil)
        t.model.saveArrows(draft)
        #expect(t.model.mentoring.arrows.count == 6)
        for (pair, strength) in zip(pairs(trio), strengths) {
            #expect(reading(t.model, pair) == ArrowReading(from: pair.from, to: pair.to, squad: .firstTeam,
                                                           strength: strength, readOn: today))
        }
        #expect(t.reopened().mentoring.arrows == t.model.mentoring.arrows)
    }

    @Test func savingItAgainUnchangedKeepsEveryDay() throws {
        let t = try both()
        let trio = Array(ids(t.model, .firstTeam)[0..<3])
        t.model.saveArrows(everyArrow(t.model, .firstTeam, trio, .average))
        let first = t.model.mentoring.arrows
        let generation = t.model.mentoringGeneration
        setDate(t.model, today.adding(days: 7))
        t.model.saveArrows(t.model.arrowsDraft(for: .firstTeam, members: trio))
        #expect(t.model.mentoring.arrows == first)
        #expect(t.model.mentoringGeneration == generation)

        // One arrow changed takes the new day; the others keep theirs.
        var changed = t.model.arrowsDraft(for: .firstTeam, members: trio)
        let pair = pairs(trio)[2]
        changed.strengths[pair] = .significant
        t.model.saveArrows(changed)
        #expect(reading(t.model, pair)?.readOn == today.adding(days: 7))
        #expect(t.model.mentoring.arrows.filter { $0.readOn == today }.count == 5)
    }

    @Test func settingAnArrowBackToNotReadRemovesIt() throws {
        let t = try both()
        let trio = Array(ids(t.model, .firstTeam)[0..<3])
        t.model.saveArrows(everyArrow(t.model, .firstTeam, trio, .light))
        var draft = t.model.arrowsDraft(for: .firstTeam, members: trio)
        let pair = pairs(trio)[4]
        draft.strengths[pair] = nil
        t.model.saveArrows(draft)
        #expect(t.model.mentoring.arrows.count == 5)
        #expect(reading(t.model, pair) == nil)
        #expect(t.reopened().mentoring.arrows.count == 5)
    }

    @Test func theDraftIsFilledFromEarlierReadings() throws {
        let t = try both()
        let trio = Array(ids(t.model, .firstTeam)[0..<3])
        var draft = t.model.arrowsDraft(for: .firstTeam, members: trio)
        let read = Array(pairs(trio).prefix(3))
        for pair in read { draft.strengths[pair] = .significant }
        t.model.saveArrows(draft)

        let reopened = t.reopened().arrowsDraft(for: .firstTeam, members: trio)
        #expect(reopened.strengths == Dictionary(uniqueKeysWithValues: read.map { ($0, ArrowStrength.significant) }))
        #expect(reopened.members == trio)
        #expect(reopened.id != draft.id)
        // In another order the same pairs are filled.
        let shuffled = [trio[2], trio[0], trio[1]]
        #expect(t.model.arrowsDraft(for: .firstTeam, members: shuffled).strengths == reopened.strengths)
        // Readings are the squad's: the same three in another squad have none.
        #expect(t.model.arrowsDraft(for: .u21, members: trio).strengths.isEmpty)
    }

    @Test func aTrioNeedsThreeCurrentPlayersNotOutOnLoan() throws {
        let t = try both()
        let first = ids(t.model, .firstTeam), young = ids(t.model, .u21)
        func draft(_ members: [PlayerID]) -> ArrowsDraft { everyArrow(t.model, .firstTeam, members, .light) }
        let problems: [([PlayerID], String)] = [
            (Array(first[0..<2]), AppModel.ArrowsProblemLabel.notThree),
            (Array(first[0..<4]), AppModel.ArrowsProblemLabel.notThree),
            ([first[0], first[0], first[1]], AppModel.ArrowsProblemLabel.notThree),
            ([first[0], first[1], young[0]], AppModel.MentoringProblemLabel.notInSquad),
            ([first[0], first[1], .fmrte(999_999)], AppModel.MentoringProblemLabel.notInSquad)]
        for (members, sentence) in problems {
            #expect(t.model.arrowsProblem(of: draft(members)) == sentence)
            t.model.saveArrows(draft(members))
        }
        #expect(t.model.mentoring.arrows.isEmpty)
        #expect(t.model.arrowsProblem(of: draft(Array(first[0..<3]))) == nil)
        // The group editor keeps its own sentence for the same two.
        #expect(t.model.mentoringProblem(of: MentoringGroupDraft(squad: .firstTeam, members: Array(first[0..<2])))
            == AppModel.MentoringProblemLabel.notThree)

        let (loaned, away) = try withOneOutOnLoan()
        let others = (loaned.model.squad.book.current[.firstTeam] ?? []).filter { $0.id != away.id }.prefix(2).map(\.id)
        let withAway = everyArrow(loaned.model, .firstTeam, others + [away.id], .light)
        #expect(loaned.model.arrowsProblem(of: withAway) == AppModel.MentoringProblemLabel.onLoan)
        loaned.model.saveArrows(withAway)
        #expect(loaned.model.mentoring.arrows.isEmpty)
    }

    @Test func aPlayerInAGroupCanStillHaveHisArrowsRecorded() throws {
        let t = try both()
        let squad = ids(t.model, .firstTeam)
        t.model.saveGroup(MentoringGroupDraft(squad: .firstTeam, members: Array(squad[0..<3])))
        // His own group's three, and a trio with one of them and two players in no group.
        for trio in [Array(squad[0..<3]), [squad[0], squad[3], squad[4]]] {
            let draft = everyArrow(t.model, .firstTeam, trio, .average)
            #expect(t.model.arrowsProblem(of: draft) == nil)
            t.model.saveArrows(draft)
        }
        #expect(t.model.mentoring.arrows.count == 12)
    }

    @Test func aReadingStaysWhenItsPlayerMovesSquadAndIsNotUsed() throws {
        let t = try bothTeamGrids()
        let youth = try youthRows()
        func u21Player(_ row: Int) throws -> Player {
            try #require(t.model.squad.book.current[.u21]?.first { youth[row].contains("\"\($0.name)\"") })
        }
        let moving = [try u21Player(1), try u21Player(2)].map(\.id)
        // One who stays, chosen as the sheet offers him: not out on loan.
        let stays = try #require(t.model.arrowChoices(for: t.model.arrowsDraft(for: .u21, members: moving))
            .first { !$0.isChosen && $0.canToggle }).id
        let trio = moving + [stays]
        #expect(t.model.arrowsProblem(of: everyArrow(t.model, .u21, trio, .significant)) == nil)
        t.model.saveArrows(everyArrow(t.model, .u21, trio, .significant))
        let readings = t.model.mentoring.arrows
        #expect(readings.count == 6)

        // Both move to the first team.
        try importFirstTeam(t, try firstRows() + [youth[1], youth[2]])
        #expect(Set(lastChange(t.model)?.movedIn ?? []) == Set(moving))
        try importU21(t, youth.enumerated().filter { ![1, 2].contains($0.offset) }.map(\.element))
        #expect(t.reopened().mentoring.arrows == readings)

        // A first-team group of the two: their arrows there are guesses.
        let firstTrio = moving + [ids(t.model, .firstTeam)[0]]
        let firstGroup = MentoringGroupDraft(squad: .firstTeam, members: firstTrio)
        #expect(t.model.mentoringProblem(of: firstGroup) == nil)
        t.model.saveGroup(firstGroup)
        let there = try #require(try report(t.model, .firstTeam).groups.first { $0.id == firstGroup.id })
        #expect(there.unreadArrows == 6)
        #expect(!there.arrows.contains { $0.arrow.isRead })
        #expect(t.model.mentoringSheet(for: .firstTeam).yours.allSatisfy { $0.arrows.allSatisfy(\.isGuess) })

        // Back in the U21s, the readings are used again.
        t.input.uptime += 10
        t.model.endGroup(firstGroup.id)
        try importU21(t, youth)
        #expect(Set(lastChange(t.model)?.movedIn ?? []) == Set(moving))
        let youthGroup = MentoringGroupDraft(squad: .u21, members: trio)
        #expect(t.model.mentoringProblem(of: youthGroup) == nil)
        t.model.saveGroup(youthGroup)
        let back = try #require(try report(t.model, .u21).groups.first { $0.id == youthGroup.id })
        #expect(back.unreadArrows == 0)
        #expect(back.arrows.count == 6)
        #expect(back.arrows.allSatisfy { $0.arrow.readOn == today && $0.arrow.strength == .significant })
        #expect(t.model.mentoring.arrows == readings)
    }

    @Test func theAdviceUsesTheReadings() throws {
        let t = try both()
        let players = t.model.squad.book.current[.firstTeam] ?? []
        let lead = try #require(players.max { ($0.age, $1.name) < ($1.age, $0.name) })
        let juniors = Array(players.filter { $0.id != lead.id && $0.age <= 23 }.prefix(2))
        try #require(juniors.count == 2)
        let (one, two) = (juniors[0], juniors[1])
        t.model.setDynamics([lead.id: PlayerDynamics(standing: .teamLeader)], for: .firstTeam)
        t.model.saveGroup(MentoringGroupDraft(squad: .firstTeam, members: [lead.id, one.id, two.id]))

        func line(_ junior: Player) throws -> ArrowLine? {
            try #require(t.model.mentoringSheet(for: .firstTeam).yours.first).arrows
                .first { $0.titleText == "\(lead.name) → \(junior.name)" }
        }
        // Before: both arrows are the Team Leader's guessed Average.
        let guessed = "\(AdvisorText.name(ArrowStrength.average)) · \(AdvisorText.expectedNotRead)"
        #expect(try line(one)?.strengthText == guessed)
        #expect(try line(two)?.strengthText == guessed)

        var draft = t.model.arrowsDraft(for: .firstTeam, members: [lead.id, one.id, two.id])
        draft.strengths[Pair(from: lead.id, to: one.id)] = .significant
        draft.strengths[Pair(from: lead.id, to: two.id)] = ArrowStrength.none
        t.model.saveArrows(draft)

        #expect(try line(one)?.strengthText == "Significant · read \(DayText.short(today))")
        #expect(try line(one)?.isGuess == false)
        // Read as None: the guessed arrow is gone.
        #expect(try line(two) == nil)
        #expect(t.model.mentoringRequest(for: .firstTeam, asOf: today).arrows == t.model.mentoring.arrows)
        #expect(t.model.mentoringAdvice(for: .firstTeam) == .ready(try engineReport(t.model, .firstTeam, leaving: [])))
    }

    @Test func recordingArrowsDoesNotReplan() throws {
        let t = try both()
        let planned = t.model.timesPlanned
        let generation = t.model.mentoringGeneration
        t.model.saveArrows(everyArrow(t.model, .firstTeam, Array(ids(t.model, .firstTeam)[0..<3]), .light))
        #expect(t.model.timesPlanned == planned)
        #expect(t.model.mentoringGeneration > generation)
    }

    @Test func savingANewGroupLeadsToItsArrowsAndAChangeDoesNot() throws {
        let t = try both()
        let squad = ids(t.model, .firstTeam)
        let trio = [squad[2], squad[0], squad[1]]
        var earlier = t.model.arrowsDraft(for: .firstTeam, members: trio)
        earlier.strengths[Pair(from: squad[0], to: squad[2])] = .average
        t.model.saveArrows(earlier)

        let new = MentoringGroupDraft(squad: .firstTeam, members: trio)
        t.model.saveGroup(new)
        let next = try #require(t.model.arrowsDraft(afterSaving: new))
        #expect(next.squad == .firstTeam)
        #expect(next.members == trio)
        #expect(next.strengths == [Pair(from: squad[0], to: squad[2]): .average])
        #expect(next == t.model.arrowsDraft(for: .firstTeam, members: trio).withID(next.id))

        // A change to the group leads nowhere.
        var change = MentoringGroupDraft(editing: try #require(live(t.model).first))
        change.toggle(squad[1])
        change.toggle(squad[3])
        t.model.saveGroup(change)
        #expect(t.model.arrowsDraft(afterSaving: change) == nil)
        // Nor does a new group that could not be saved.
        let two = MentoringGroupDraft(squad: .firstTeam, members: [squad[4], squad[5]])
        t.model.saveGroup(two)
        #expect(t.model.arrowsDraft(afterSaving: two) == nil)
    }

    @Test func namesAreKeptForPlayersInReadings() throws {
        let t = try both()
        let players = Array((t.model.squad.book.current[.firstTeam] ?? []).prefix(3))
        t.model.saveArrows(everyArrow(t.model, .firstTeam, players.map(\.id), .light))
        for player in players { #expect(t.model.mentoring.names[player.id] == player.name) }
        #expect(t.reopened().mentoring.names == t.model.mentoring.names)
    }

    @Test func togglingAPlayerKeepsTheDraftAndTheStrengthsSetForPairsThatStay() throws {
        let t = try both()
        let squad = ids(t.model, .firstTeam)
        var draft = t.model.arrowsDraft(for: .firstTeam, members: Array(squad[0..<3]))
        draft.strengths[Pair(from: squad[0], to: squad[1])] = .significant
        draft.strengths[Pair(from: squad[2], to: squad[0])] = .light
        let out = t.model.arrowsDraft(draft, toggling: squad[2])
        #expect(out.id == draft.id)
        #expect(out.squad == draft.squad)
        #expect(out.members == [squad[0], squad[1]])
        // His pairs' strengths go; the pair that stays keeps what was set in the sheet.
        #expect(out.strengths == [Pair(from: squad[0], to: squad[1]): .significant])
        let back = t.model.arrowsDraft(out, toggling: squad[3])
        #expect(back.id == draft.id)
        #expect(back.members == [squad[0], squad[1], squad[3]])
        #expect(back.strengths == [Pair(from: squad[0], to: squad[1]): .significant])
    }

    @Test func aPlayerPutBackHasHisPairsFilledFromTheKeptReadings() throws {
        let t = try both()
        let squad = ids(t.model, .firstTeam)
        let trio = Array(squad[0..<3])
        var kept = t.model.arrowsDraft(for: .firstTeam, members: trio)
        kept.strengths[Pair(from: squad[0], to: squad[2])] = .average
        t.model.saveArrows(kept)

        var draft = t.model.arrowsDraft(for: .firstTeam, members: trio)
        draft.strengths[Pair(from: squad[0], to: squad[2])] = .significant
        draft.strengths[Pair(from: squad[2], to: squad[1])] = .light
        let out = t.model.arrowsDraft(draft, toggling: squad[2])
        let back = t.model.arrowsDraft(out, toggling: squad[2])
        #expect(back.members == [squad[0], squad[1], squad[2]])
        #expect(back.strengths == [Pair(from: squad[0], to: squad[2]): .average])
        // And it agrees with a draft opened afresh.
        #expect(back == t.model.arrowsDraft(for: .firstTeam, members: back.members).withID(back.id))
    }

    @Test func aFourthPlayerIsNotPutIn() throws {
        let t = try both()
        let squad = ids(t.model, .firstTeam)
        let draft = everyArrow(t.model, .firstTeam, Array(squad[0..<3]), .light)
        #expect(t.model.arrowsDraft(draft, toggling: squad[3]) == draft)
    }

    @Test func theArrowsChooserLeavesOutPlayersOutOnLoanAndOfAnotherSquad() throws {
        let (t, away) = try withOneOutOnLoan()
        try t.importU21()
        let squad = ids(t.model, .firstTeam)
        let draft = t.model.arrowsDraft(for: .firstTeam, members: [])
        let choices = t.model.arrowChoices(for: draft)
        #expect(choices.map(\.id) == squad.filter { $0 != away.id })
        #expect(!choices.contains { ids(t.model, .u21).contains($0.id) })
        #expect(choices == MentoringPresentation.arrowChoices(
            draft, players: t.model.squad.book.current[.firstTeam] ?? [], ownClub: t.model.ownClub,
            state: t.model.mentoring))
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
        let raised = model.mentoring.dynamics(for: .firstTeam).filter { $0.value.standing != .others }
        #expect(raised.count == 3)
        #expect(Set(raised.values.map(\.standing)) == [.teamLeader, .highlyInfluential, .influential])
        #expect(Set(raised.keys).isSubset(of: Set(firstTeam(model).map(\.id))))
        // Social groups for some players, not all.
        #expect(model.mentoring.dynamics(for: .firstTeam).values.contains { $0.socialGroup != nil })
        #expect(model.mentoring.dynamics(for: .firstTeam).count < firstTeam(model).count)
        #expect(model.mentoring.hierarchy.values.allSatisfy { $0.squad == .firstTeam })
        #expect(model.mentoring.dynamicsUpdatedOn == [.firstTeam: model.settings.currentDate])
        let report = try report(model)
        #expect(!report.needsHierarchy && !report.isStale)
        #expect(!report.suggestions.isEmpty)
        #expect(model.mentoring.groups.isEmpty)
        #expect(model.mentoringSheet(for: .firstTeam).hierarchyLines.count == 4)
        #expect(model.notices.isEmpty)
    }

    @Test func theStaleSampleHasTheFirstTeamsHierarchyEnteredFiveWeeksAgo() throws {
        let model = try SampleData.modelWithStaleHierarchy(repositoryRoot: Captures.repositoryRoot)
        let fresh = try SampleData.modelWithHierarchy(repositoryRoot: Captures.repositoryRoot)
        #expect(model.mentoring.hierarchy == fresh.mentoring.hierarchy)
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
        #expect(!review.arrows.isEmpty)
        let improved = review.members.flatMap { member in member.changes.map { (member, $0) } }.filter { $0.1.change == .improved }
        #expect(improved.count == 1)
        let (member, change) = try #require(improved.first)
        // He is one the group influences.
        #expect(review.arrows.contains { $0.arrow.to == member.player })
        #expect(change.attribute == .professionalism)
        #expect(change.latest == change.start.map { $0 + 1 })
        #expect(change.weeks == 5)
        #expect(!review.isDoingHarm && !review.hasStoppedWorking)
        #expect(!review.warnings.contains { if case .harmfulArrow = $0 { true } else { false } })
        let card = try #require(model.mentoringSheet(for: .firstTeam).yours.first)
        #expect(card.stateText == nil)
        #expect(card.members.contains { $0.detailText?.contains(AdvisorText.change(change)!) == true })
        #expect(model.notices.isEmpty)
    }

    @Test func theWarningSampleHasATeamLeaderWhoseArrowIntoAJuniorIsHarmfulInAmbition() throws {
        let model = try SampleData.modelWithMentoringWarning(repositoryRoot: Captures.repositoryRoot)
        let review = try #require(try report(model).groups.first)
        let levels = model.mentoring.dynamics(for: .firstTeam)
        let harmful = review.warnings.filter { warning in
            if case .harmfulArrow(let from, _, let strength, _, .ambition, let fromValue, let toValue) = warning {
                return levels[from]?.standing == .teamLeader && strength > .none && fromValue < toValue
            }
            return false
        }
        #expect(!harmful.isEmpty)
        // The Team Leader's Ambition was the same at both readings: the group is not doing harm.
        #expect(!review.isDoingHarm)
        let card = try #require(model.mentoringSheet(for: .firstTeam).yours.first)
        #expect(card.stateText == nil)
        #expect(!card.warnings.isEmpty)
    }

    @Test func theArrowsReadSampleHasAFirstSuggestionRestingOnReadingsAndAnotherOnGuesses() throws {
        let model = try SampleData.modelWithArrowsRead(repositoryRoot: Captures.repositoryRoot)
        let report = try report(model)
        let first = try #require(report.suggestions.first)
        #expect(first.isRead)
        #expect(!first.arrows.isEmpty)
        #expect(first.arrows.allSatisfy { $0.arrow.readOn == model.settings.currentDate })
        // The same three the hierarchy sample suggests first: reading the guesses as they were changed no choice.
        let plain = try self.report(try SampleData.modelWithHierarchy(repositoryRoot: Captures.repositoryRoot))
        #expect(first.members == plain.suggestions.first?.members)
        // Another suggestion still rests on guesses, so a read arrow and a guess show on one screen.
        #expect(report.suggestions.dropFirst().contains { !$0.isRead && $0.arrows.contains { !$0.arrow.isRead } })
        let cards = model.mentoringSheet(for: .firstTeam).suggested
        #expect(cards.first?.arrows.allSatisfy { !$0.isGuess } == true)
        #expect(cards.dropFirst().contains { $0.arrows.contains { $0.isGuess } })
        #expect(model.mentoring.groups.isEmpty)
        #expect(model.notices.isEmpty)
    }

    @Test func theHarmSampleHasAReadSignificantArrowFromAMemberWithALowerAmbition() throws {
        let model = try SampleData.modelWithHarmfulArrow(repositoryRoot: Captures.repositoryRoot)
        let review = try #require(try report(model).groups.first)
        let read = review.warnings.filter { warning in
            if case .harmfulArrow(_, _, .significant, true, .ambition, let fromValue, let toValue) = warning {
                return fromValue < toValue
            }
            return false
        }
        #expect(read.count == 1)
        // His Ambition was the same at both readings: the group is not doing harm.
        #expect(!review.isDoingHarm)
        let card = try #require(model.mentoringSheet(for: .firstTeam).yours.first)
        #expect(card.stateText == nil)
        #expect(!card.warnings.isEmpty)
        #expect(card.arrows.contains { !$0.isGuess } && card.arrows.contains { $0.isGuess })
        #expect(model.notices.isEmpty)
    }

    @Test func theNoInfluenceSampleHasAGroupWhoseSixArrowsAreReadAsNone() throws {
        let model = try SampleData.modelWithNoInfluence(repositoryRoot: Captures.repositoryRoot)
        let review = try #require(try report(model).groups.first)
        #expect(review.hasNoInfluence)
        #expect(!review.hasStoppedWorking && !review.isDoingHarm)
        #expect(review.unreadArrows == 0)
        #expect(review.arrows.isEmpty)
        let card = try #require(model.mentoringSheet(for: .firstTeam).yours.first)
        #expect(card.stateText == AdvisorText.state(of: review, parameters: model.planParameters))
        #expect(card.stateText != nil)
        #expect(card.arrowsPromptText == nil)
        #expect(model.notices.isEmpty)
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

private extension ArrowsDraft {
    /// The same draft under another id, to compare a draft changed in the sheet with one opened afresh.
    func withID(_ id: UUID) -> ArrowsDraft {
        ArrowsDraft(id: id, squad: squad, members: members, strengths: strengths)
    }
}
