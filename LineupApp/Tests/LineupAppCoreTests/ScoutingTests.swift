import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

/// The model both scouting suites start from: the first team keyed by FMRTE's id, the club named, and the sample
/// 4-2-3-1 as the primary tactic. The U21s are not imported: they are pasted as another club's players, and once held
/// they would be taken for the owner's own by name, age and potential ability.
@MainActor enum ScoutingSetup {
    static func ready() throws -> TestModel {
        let t = try TestModel()
        try t.importFirstTeamWithID()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        let url = Captures.repositoryRoot.appendingPathComponent("LineupEngine/Tests/LineupEngineTests/Fixtures/tactics/sample-4231.json")
        let tactic = try JSONDecoder().decode(Tactic.self, from: Data(contentsOf: url))
        let id = t.model.addTactic(named: tactic.name)
        t.model.update(StoredTactic(id: id, tactic: tactic))
        return t
    }

    /// Puts `paste` (the U21s at another club unless given) and its grid layouts where the model reads them.
    static func putCandidates(_ t: TestModel, paste: String? = nil, grids: Data? = nil) throws {
        t.input.clipboard = try paste ?? Captures.u21AtAnotherClub
        t.input.config = .data(try grids ?? Captures.u21Grids)
    }

    /// The candidates pasted, through the model.
    static func paste(_ t: TestModel, paste: String? = nil, grids: Data? = nil) throws {
        try putCandidates(t, paste: paste, grids: grids)
        t.model.pasteCandidates()
    }

    static func needs(_ model: AppModel, _ tactic: UUID? = nil,
                      sourceLocation: SourceLocation = #_sourceLocation) throws -> ScoutingNeeds {
        guard case .ready(let needs) = model.scoutingNeeds(for: tactic) else {
            Issue.record("expected needs, got \(model.scoutingNeeds(for: tactic))", sourceLocation: sourceLocation)
            throw Unready()
        }
        return needs
    }

    static func report(_ model: AppModel, _ tactic: UUID? = nil,
                       sourceLocation: SourceLocation = #_sourceLocation) throws -> CandidatesReport {
        guard case .ready(let report) = model.candidates(for: tactic) else {
            Issue.record("expected candidates, got \(model.candidates(for: tactic))", sourceLocation: sourceLocation)
            throw Unready()
        }
        return report
    }

    struct Unready: Error {}

    /// Every file in the store's directory, with its bytes.
    static func storeFiles(_ t: TestModel) throws -> [String: Data] {
        let names = try FileManager.default.contentsOfDirectory(atPath: t.directory.path)
        var files: [String: Data] = [:]
        for name in names {
            files[name] = try Data(contentsOf: t.directory.appendingPathComponent(name))
        }
        return files
    }
}

@MainActor @Suite struct ScoutingTests {
    // MARK: The needs

    @Test func theNeedsAreReadyOnceTheAdviceIs() throws {
        let t = try ScoutingSetup.ready()
        guard case .ready(let advice) = t.model.adviceState else {
            Issue.record("expected advice, got \(t.model.adviceState)")
            return
        }
        let needs = try ScoutingSetup.needs(t.model)
        let players = t.model.squad.book.allPlayers
        #expect(!advice.removal.advisedToLeave.isEmpty, "the captured first team has players advised to leave")
        #expect(Set(needs.going.map(\.player)).isSuperset(of: advice.removal.advisedToLeave))
        let going = Scouting.going(players: players, ownClub: t.model.ownClub, marks: t.model.marks,
                                   advisedToLeave: advice.removal.advisedToLeave)
        #expect(needs.going == going)
        let primary = try #require(t.model.primaryTactic)
        let expected = try Scouting.needs(tactic: primary.tactic, players: players, ownClub: t.model.ownClub, going: going,
                                          retraining: t.model.retrainingForPlan, catalog: t.model.catalog,
                                          profile: t.model.profile, parameters: t.model.planParameters)
        #expect(needs == expected)
    }

    @Test func aMarkPutsAPlayerAmongThoseGoing() throws {
        let t = try ScoutingSetup.ready()
        let before = try ScoutingSetup.needs(t.model)
        let player = try #require(t.model.squad.book.allPlayers.sorted { $0.id.key < $1.id.key }.first { player in
            !before.going.contains { $0.player == player.id } && !Removal.isOnYouthContract(player)
        })
        t.model.setMark(.toSell, for: player.id)
        let marked = try ScoutingSetup.needs(t.model)
        #expect(marked.going.contains(Going(player: player.id, name: player.name, reason: .markedToSell)))
        t.model.setMark(nil, for: player.id)
        let unmarked = try ScoutingSetup.needs(t.model)
        #expect(!unmarked.going.contains { $0.player == player.id })
        #expect(unmarked == before)
    }

    @Test func withNoSquadTheNeedsAreNotReady() throws {
        let t = try TestModel()
        #expect(t.model.scoutingNeeds(for: nil) == .notReady(.needsSquad))
        #expect(t.model.candidates(for: nil) == .notReady(.needsSquad))
        try ScoutingSetup.paste(t)
        #expect(t.model.candidates(for: nil) == .notReady(.needsSquad), "held players wait for the squad")
    }

    // MARK: The paste

    @Test func beforeAnyPasteNothingIsPasted() throws {
        let t = try ScoutingSetup.ready()
        #expect(t.model.candidates(for: nil) == .nothingPasted)
        #expect(t.model.scoutingPaste == nil)
        #expect(t.model.scoutingPasteProblem == nil)
    }

    /// The paste that was refused on 19 November 2026 for the blank contract cells of its players with no club.
    @Test func theOwnersRealSearchResultIsReadAndJudged() throws {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t, paste: Captures.scoutingSearch, grids: Captures.scoutingSearchGrids)
        #expect(t.model.scoutingPasteProblem == nil)
        #expect(t.model.scoutingPaste?.players.count == 109)
        #expect(t.model.scoutingPaste?.money == MoneyStyle(symbol: "$", period: .monthly))
        let report = try ScoutingSetup.report(t.model)
        #expect(report.candidates.count == 109 && report.leftOut.isEmpty)
        let sheet = try #require(t.model.candidatesSheet(report, order: .today))
        let rows = sheet.groups.flatMap(\.rows)
        #expect(rows.count == 109)
        #expect(rows.filter { $0.club == "Free agent" }.count == 15)
        #expect(rows.first { $0.name == "Brad Walker" }?.club == "Darlington, out of contract")
        #expect(rows.first { $0.name == "George Wilson" }?.wage == "$2,040 a month")
    }

    @Test func aPasteHoldsThePlayersAndSavesNothing() throws {
        let t = try ScoutingSetup.ready()
        _ = t.model.adviceState
        let files = try ScoutingSetup.storeFiles(t)
        let squad = t.model.squad, marks = t.model.marks, plan = t.model.planState, mentoring = t.model.mentoring
        let training = t.model.training
        try ScoutingSetup.paste(t)
        #expect(t.model.scoutingPaste?.players.count == 6)
        #expect(t.model.scoutingPaste?.money == .weeklyPounds)
        #expect(t.model.scoutingPasteProblem == nil)
        let report = try ScoutingSetup.report(t.model)
        #expect(report.candidates.count == 6)
        #expect(report.leftOut.isEmpty)
        #expect(try ScoutingSetup.storeFiles(t) == files)
        #expect(t.model.squad == squad)
        #expect(t.model.marks == marks)
        #expect(t.model.planState == plan)
        #expect(t.model.mentoring == mentoring)
        #expect(t.model.training == training)
    }

    @Test func aPasteOfMyOwnPlayersIsRefusedAndKeepsWhatWasHeld() throws {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t)
        let held = try #require(t.model.scoutingPaste)
        try ScoutingSetup.paste(t, paste: try Captures.u21)
        #expect(t.model.scoutingPasteProblem == AdvisorText.everyPastedPlayerIsYours)
        #expect(t.model.scoutingPaste == held)
        #expect(try ScoutingSetup.report(t.model).candidates.count == 6)
    }

    @Test func anEmptyClipboardIsRefused() throws {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t, paste: "  \n")
        let problem = try #require(t.model.scoutingPasteProblem)
        #expect(t.model.scoutingPaste == nil)
        t.model.importSquad(.u18)
        #expect(t.model.lastImport == .failed(.u18, reason: problem), "the Squad screen's sentence")
    }

    @Test func rowsTheImporterRefusesAreRefused() throws {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t)
        let held = try #require(t.model.scoutingPaste)
        try ScoutingSetup.paste(t, paste: "Oxford City 2 Banbury United 1")
        let problem = try #require(t.model.scoutingPasteProblem)
        #expect(t.model.scoutingPaste == held)
        t.model.importSquad(.u18)
        #expect(t.model.lastImport == .failed(.u18, reason: problem), "the Squad screen's sentence")
    }

    @Test func aSettingsFileThatCannotBeReadIsRefused() throws {
        let t = try ScoutingSetup.ready()
        t.input.clipboard = try Captures.u21AtAnotherClub
        t.input.config = .failure(CocoaError(.fileReadNoSuchFile))
        t.model.pasteCandidates()
        let problem = try #require(t.model.scoutingPasteProblem)
        #expect(t.model.scoutingPaste == nil)
        t.model.importSquad(.u18)
        #expect(t.model.lastImport == .failed(.u18, reason: problem))
    }

    @Test func aGoodPasteClearsTheProblem() throws {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t, paste: "")
        #expect(t.model.scoutingPasteProblem != nil)
        try ScoutingSetup.paste(t)
        #expect(t.model.scoutingPasteProblem == nil)
        #expect(t.model.scoutingPaste?.players.count == 6)
    }

    @Test func clearRemovesThePlayers() throws {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t)
        _ = try ScoutingSetup.report(t.model)
        t.model.clearCandidates()
        #expect(t.model.scoutingPaste == nil)
        #expect(t.model.candidates(for: nil) == .nothingPasted)
    }

    @Test func clearAlsoTakesAwayARefusal() throws {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t)
        try ScoutingSetup.paste(t, paste: try Captures.u21)
        #expect(t.model.scoutingPasteProblem != nil)
        t.model.clearCandidates()
        #expect(t.model.scoutingPasteProblem == nil)
    }

    @Test func aNewPasteReplacesTheOld() throws {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t)
        let renamed = try Captures.u21AtAnotherClub.replacingOccurrences(of: "Brayden Daniel", with: "Kofi Mensah")
        try ScoutingSetup.paste(t, paste: renamed)
        let report = try ScoutingSetup.report(t.model)
        #expect(report.candidates.contains { $0.player.name == "Kofi Mensah" })
        #expect(!report.candidates.contains { $0.player.name == "Brayden Daniel" })
        #expect(report.candidates.count == 6)
    }

    @Test func candidatesAreJudgedOnceUntilSomethingChanges() throws {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t)
        let start = t.model.timesCandidatesJudged
        for _ in 0..<5 { _ = t.model.candidates(for: nil) }
        #expect(t.model.timesCandidatesJudged == start + 1)

        try ScoutingSetup.paste(t)
        _ = t.model.candidates(for: nil)
        _ = t.model.candidates(for: nil)
        #expect(t.model.timesCandidatesJudged == start + 2)

        let needs = try ScoutingSetup.needs(t.model)
        let player = try #require(t.model.squad.book.allPlayers.sorted { $0.id.key < $1.id.key }.first { player in
            !needs.going.contains { $0.player == player.id } && !Removal.isOnYouthContract(player)
        })
        t.model.setMark(.toSell, for: player.id)
        _ = t.model.candidates(for: nil)
        _ = t.model.candidates(for: nil)
        #expect(t.model.timesCandidatesJudged == start + 3)

        try t.importFirstTeamWithID()
        _ = t.model.candidates(for: nil)
        _ = t.model.candidates(for: nil)
        #expect(t.model.timesCandidatesJudged == start + 4)
    }

    @Test func candidatesSignedAndImportedDropOut() throws {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t)
        let pasted = try ScoutingSetup.report(t.model).candidates.map(\.player.name)
        try t.importU21()
        let report = try ScoutingSetup.report(t.model)
        #expect(report.candidates.isEmpty)
        #expect(report.leftOut == pasted)
        #expect(report.leftOut.count == 6)
        #expect(t.model.scoutingPaste?.players.count == 6)
    }

    @Test func aDeletedTacticFallsBackToThePrimary() throws {
        let t = try ScoutingSetup.ready()
        let primary = try #require(t.model.primaryTactic).id
        let second = t.model.addTactic(named: t.model.unusedTacticName("Wide"))
        try ScoutingSetup.paste(t)
        #expect(t.model.scoutingTacticShown(nil) == primary)
        #expect(t.model.scoutingTacticShown(second) == second)
        guard case .ready = t.model.scoutingNeeds(for: second) else {
            Issue.record("expected needs for the second tactic, got \(t.model.scoutingNeeds(for: second))")
            return
        }
        guard case .ready = t.model.candidates(for: second) else {
            Issue.record("expected candidates for the second tactic, got \(t.model.candidates(for: second))")
            return
        }
        t.model.deleteTactic(second)
        #expect(t.model.scoutingTacticShown(second) == primary)
        #expect(t.model.candidates(for: second) == t.model.candidates(for: nil))
        #expect(t.model.scoutingNeeds(for: second) == t.model.scoutingNeeds(for: nil))
    }

    @Test func anotherTacticsNeedsAreTheEnginesForIt() throws {
        let t = try ScoutingSetup.ready()
        let second = t.model.addTactic(named: t.model.unusedTacticName("Wide"))
        let needs = try ScoutingSetup.needs(t.model, second)
        let primaryNeeds = try ScoutingSetup.needs(t.model)
        let stored = try #require(t.model.tactics.first { $0.id == second })
        let expected = try Scouting.needs(tactic: stored.tactic, players: t.model.squad.book.allPlayers,
                                          ownClub: t.model.ownClub, going: primaryNeeds.going,
                                          retraining: t.model.retrainingForPlan, catalog: t.model.catalog,
                                          profile: t.model.profile, parameters: t.model.planParameters)
        #expect(needs == expected)
    }

    @Test func aTacticTheEngineRefusesGivesItsSentences() throws {
        let t = try ScoutingSetup.ready()
        // The in-possession striker taken out, so the engine refuses it.
        let id = t.model.addTactic(named: t.model.unusedTacticName("Broken"))
        var stored = try #require(t.model.tactics.first { $0.id == id })
        var draft = TacticDraft(stored.tactic)
        draft.toggle(.ST_C, in: .inPossession, catalog: t.model.catalog)
        stored.tactic = draft.tactic
        t.model.update(stored)
        let problems = t.model.problems(of: stored.tactic)
        #expect(!problems.isEmpty)
        #expect(t.model.scoutingNeeds(for: id) == .failed(problems))
        try ScoutingSetup.paste(t)
        #expect(t.model.candidates(for: id) == .failed(problems))
    }

    @Test func aPasteDoesNotPlan() throws {
        let t = try ScoutingSetup.ready()
        let planned = t.model.timesPlanned, advised = t.model.timesAdvised
        try ScoutingSetup.paste(t)
        t.model.clearCandidates()
        #expect(t.model.timesPlanned == planned)
        #expect(t.model.timesAdvised == advised)
    }

    @Test func savedStateFromBeforeScoutingOpensWithNoNotice() throws {
        let t = try ScoutingSetup.ready()
        let reopened = t.reopened()
        #expect(reopened.notices.isEmpty)
        #expect(reopened.candidates(for: nil) == .nothingPasted)
        #expect(reopened.scoutingPaste == nil)
        guard case .ready = reopened.scoutingNeeds(for: nil) else {
            Issue.record("expected needs, got \(reopened.scoutingNeeds(for: nil))")
            return
        }
    }

    @Test func aPasteIsNotKeptAcrossAReopening() throws {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t)
        #expect(t.model.scoutingPaste != nil)
        #expect(t.reopened().scoutingPaste == nil)
    }

    // MARK: The sample

    @Test func theSampleCandidatesAnswerANeedTodayAndOneHasACaution() throws {
        let model = try SampleData.modelWithCandidates(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let report = try ScoutingSetup.report(model)
        // One of the sample's own U21s is pasted as he is, so the row saying who was left out shows.
        #expect(report.leftOut == [SampleData.candidateAlreadyHeldName])
        #expect(report.candidates.count == (model.scoutingPaste?.players.count ?? 0) - 1)
        // A group of two, open from the start (not the rest), whose order the Today and Later control changes, so a
        // picture shows it: the older starter rates higher today, the young one reaches higher.
        func shown(_ order: CandidateOrder) -> [[String]] {
            report.groups(orderedBy: order).filter { $0.part != .rest }.map { $0.candidates.map(\.player.name) }
        }
        #expect(shown(.today).contains([SampleData.candidateOlderStarterName, SampleData.candidateWhoStartsName]))
        #expect(shown(.later).contains([SampleData.candidateWhoStartsName, SampleData.candidateOlderStarterName]))
        #expect(report.groups(orderedBy: .today).map(\.part) == report.groups(orderedBy: .later).map(\.part))
        let starter = try #require(report.candidates.first { $0.player.name == SampleData.candidateWhoStartsName })
        #expect(starter.part == .answersToday)
        #expect(starter.headlineAnswer == .betterPlayerToday)
        let cautioned = try #require(report.candidates.first { $0.player.name == SampleData.candidateWithCautionsName })
        #expect(!cautioned.cautions.isEmpty)
        for candidate in report.candidates {
            #expect(AdvisorText.club(of: candidate.player) != SampleData.clubName)
        }
    }

    @Test func theSampleRefusalKeepsTheCandidates() throws {
        let model = try SampleData.modelWithRefusedCandidates(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        #expect(model.scoutingPasteProblem == AdvisorText.everyPastedPlayerIsYours)
        #expect(try ScoutingSetup.report(model).candidates.isEmpty == false)
    }
}
