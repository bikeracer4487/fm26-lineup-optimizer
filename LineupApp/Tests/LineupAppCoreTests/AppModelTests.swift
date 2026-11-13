import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

@MainActor @Suite struct AppModelTests {
    private let today = TestModel.today
    private func day(_ iso: String) -> Day { Day(iso: iso)! }

    private func summary(_ outcome: ImportOutcome?, sourceLocation: SourceLocation = #_sourceLocation) -> ImportSummary? {
        guard case .imported(let summary)? = outcome else {
            Issue.record("expected an import summary, got \(String(describing: outcome))", sourceLocation: sourceLocation)
            return nil
        }
        return summary
    }

    private func expectSameState(_ a: AppModel, _ b: AppModel, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(a.squad == b.squad, sourceLocation: sourceLocation)
        #expect(a.tactics == b.tactics, sourceLocation: sourceLocation)
        #expect(a.fixtures == b.fixtures, sourceLocation: sourceLocation)
        #expect(a.history == b.history, sourceLocation: sourceLocation)
        #expect(a.settings == b.settings, sourceLocation: sourceLocation)
    }

    // MARK: Loading

    @Test func aFirstRunStartsEmptyOnTodaysDate() throws {
        let t = try TestModel()
        let model = t.model
        #expect(model.settings == AppSettings(currentDate: today))
        #expect(model.squad == SquadState())
        #expect(model.tactics.isEmpty && model.fixtures.isEmpty && model.history.isEmpty)
        #expect(model.players.isEmpty)
        #expect(model.primaryTactic == nil)
        #expect(model.notices.isEmpty)
        #expect(model.lastImport == nil)
        #expect(model.ownClub == nil)
        #expect(model.squadWarnings.isEmpty)
    }

    @Test func aSecondStartHasNoNoticesWhenOnlyPartOfTheStateChanged() throws {
        let t = try TestModel()
        t.model.addFixture(date: day("2026-11-14"), opponent: "Rovers", importance: .high)
        #expect(t.reopened().notices.isEmpty)
    }

    @Test func aSavedCurrentDateIsKeptOverToday() throws {
        let t = try TestModel()
        var settings = t.model.settings
        settings.currentDate = day("2026-12-01")
        t.model.update(settings)
        #expect(t.reopened().settings.currentDate == day("2026-12-01"))
    }

    @Test func aFileKeptAsideIsWrittenAfreshSoTheNextStartFindsIt() throws {
        let t = try TestModel()
        t.model.addFixture(date: day("2026-11-14"), opponent: "Rovers", importance: .high)
        try Data("{".utf8).write(to: t.directory.appendingPathComponent("fixtures.json"))
        #expect(t.reopened().notices.count == 1)
        // The start that set it aside wrote an empty list in its place, so the next start has nothing to report.
        #expect(t.reopened().notices.isEmpty)
    }

    @Test func aFileKeptAsideByACopyIsNotCopiedAgainAtTheNextStart() throws {
        let t = try TestModel()
        t.model.addFixture(date: day("2026-11-14"), opponent: "Rovers", importance: .high)
        try Data("{".utf8).write(to: t.directory.appendingPathComponent("fixtures.json"))
        struct Refused: Error {}
        func start() -> AppModel {
            AppModel(store: Store(directory: t.directory, move: { _, _ in throw Refused() }), environment: t.input.environment)
        }
        #expect(start().notices.count == 1)
        #expect(start().notices.isEmpty)
        let names = try FileManager.default.contentsOfDirectory(atPath: t.directory.path)
        #expect(names.filter { $0.hasPrefix("fixtures.unreadable-") } == ["fixtures.unreadable-1.json"])
    }

    @Test func anUnreadableFileIsNoticedAndCanBeDismissed() throws {
        let t = try TestModel()
        try Data("{".utf8).write(to: t.directory.appendingPathComponent("fixtures.json"))
        let model = t.reopened()
        #expect(model.notices.count == 1)
        let notice = try #require(model.notices.first)
        #expect(notice.text.contains("Your saved fixtures"))
        model.dismiss(notice)
        #expect(model.notices.isEmpty)
    }

    // MARK: Squad

    @Test func importingTheFirstTeamFillsTheSquadAndSummarisesIt() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let model = t.model
        let summary = try #require(summary(model.lastImport))
        #expect(summary.squad == .firstTeam)
        #expect(summary.grid == "TeamPlayersColumns")
        #expect(summary.playerCount == 18)
        #expect(summary.change.added.count == 18)
        #expect(summary.change.removed.isEmpty)
        #expect(summary.warnings.contains(ErrorDescriptions.describe(ImportWarning.identifiedByName)))
        #expect(model.squad.book.current[.firstTeam]?.count == 18)
        #expect(model.squad.importedOn == [.firstTeam: today])
        #expect(model.players.count == 18)
        #expect(model.players.map(\.name) == model.players.map(\.name).sorted())
    }

    @Test func theImportDateIsTheCurrentDateNotToday() throws {
        let t = try TestModel()
        var settings = t.model.settings
        settings.currentDate = day("2027-01-05")
        t.model.update(settings)
        try t.importFirstTeam()
        #expect(t.model.squad.importedOn[.firstTeam] == day("2027-01-05"))
    }

    @Test func importingTheU21sLeavesTheFirstTeamAlone() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let firstTeam = t.model.squad.book.current[.firstTeam]
        try t.importU21()
        let summary = try #require(summary(t.model.lastImport))
        #expect(summary.squad == .u21)
        #expect(summary.grid == "SearchPlayersColumns")
        #expect(summary.playerCount == 6)
        #expect(t.model.squad.book.current[.firstTeam] == firstTeam)
        #expect(t.model.squad.book.current[.u21]?.count == 6)
        #expect(t.model.squad.importedOn == [.firstTeam: today, .u21: today])
        #expect(t.model.players.count == 24)
    }

    @Test func playersOutOnLoanAreNamedInTheSummary() throws {
        let t = try TestModel()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        try t.importU21()
        let summary = try #require(summary(t.model.lastImport))
        let expected = t.model.squad.book.current[.u21]!.filter {
            if case .loanedOut = LoanStatus.of($0, ownClub: "Oxford City") { true } else { false }
        }.map(\.name)
        #expect(!expected.isEmpty)
        #expect(summary.onLoan == expected)
    }

    @Test func aSecondImportReportsWhatChanged() throws {
        let t = try TestModel()
        let full = try Captures.firstTeam
        var lines = full.split(separator: "\r\n", omittingEmptySubsequences: true)
        let last = lines.removeLast()
        t.importSquad(.firstTeam, paste: lines.joined(separator: "\r\n") + "\r\n", grids: try Captures.firstTeamGrids)
        #expect(t.model.squad.book.current[.firstTeam]?.count == 17)
        t.importSquad(.firstTeam, paste: full, grids: try Captures.firstTeamGrids)
        let summary = try #require(summary(t.model.lastImport))
        #expect(summary.change.added.count == 1)
        #expect(summary.change.removed.isEmpty)
        #expect(summary.change.changed.isEmpty)
        let added = try #require(t.model.players.first { $0.id == summary.change.added.first })
        #expect(last.contains(added.name))
    }

    @Test func anEmptyClipboardChangesNothingAndSaysSo() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let before = t.model.squad
        for empty in [nil, "", "  \r\n\t\n"] as [String?] {
            t.input.clipboard = empty
            t.model.importSquad(.firstTeam)
            #expect(t.model.lastImport == .failed(.firstTeam, reason: "The clipboard is empty. Copy the rows in FMRTE first."))
            #expect(t.model.squad == before)
        }
        #expect(t.reopened().squad == before)
    }

    @Test func textThatIsNotFMRTERowsChangesNothingAndSaysWhy() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let before = t.model.squad
        t.input.clipboard = "Dear manager, the board would like a word."
        t.model.importSquad(.u21)
        #expect(t.model.lastImport == .failed(.u21, reason: ErrorDescriptions.describe(
            ImportError.notAnFMRTEGrid(reason: "first line has no tab separators"))))
        #expect(t.model.squad == before)
        #expect(t.reopened().squad == before)
    }

    @Test func aMissingFMRTEFileChangesNothingAndSaysWhere() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let before = t.model.squad
        let usual = t.directory.appendingPathComponent("FMRTE27/config.json").path
        t.input.config = .readFile(otherwise: usual)
        t.model.importSquad(.firstTeam)
        #expect(t.model.lastImport == .failed(.firstTeam, reason:
            "FMRTE's settings file was not found at \(usual). Open FMRTE once, or set its location in Settings."))
        #expect(t.model.squad == before)

        let chosen = t.directory.appendingPathComponent("elsewhere/config.json").path
        var settings = t.model.settings
        settings.fmrteConfigPath = chosen
        t.model.update(settings)
        t.model.importSquad(.firstTeam)
        #expect(t.model.lastImport == .failed(.firstTeam, reason:
            "FMRTE's settings file was not found at \(chosen). Open FMRTE once, or set its location in Settings."))
        #expect(t.model.squad == before)
    }

    @Test func anFMRTEFileThatCannotBeReadGivesTheEnginesSentence() throws {
        let t = try TestModel()
        struct Locked: Error, LocalizedError { var errorDescription: String? { "the file is locked" } }
        t.input.clipboard = try Captures.firstTeam
        t.input.config = .failure(Locked())
        t.model.importSquad(.firstTeam)
        #expect(t.model.lastImport == .failed(.firstTeam, reason: ErrorDescriptions.describe(ImportError.configUnreadable(reason: "the file is locked"))))
        #expect(t.model.squad == SquadState())
    }

    @Test func aFailedImportSaysWhichSquadWasNotImported() {
        #expect(ImportReport.notImportedLine(.firstTeam) == "The first team was not imported; the squad is as it was.")
        #expect(ImportReport.notImportedLine(.u21) == "The U21s were not imported; the squad is as it was.")
        #expect(ImportReport.notImportedLine(.u18) == "The U18s were not imported; the squad is as it was.")
    }

    @Test func theImportSummaryCanBeDismissed() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        #expect(t.model.lastImport != nil)
        t.model.dismissImport()
        #expect(t.model.lastImport == nil)
    }

    @Test func anImportIsDatedWithTheCurrentDateAndSaysSo() throws {
        let t = try TestModel()
        t.model.moveToday(by: 1)
        try t.importFirstTeam()
        let summary = try #require(summary(t.model.lastImport))
        #expect(summary.date == day("2026-11-14"))
        #expect(t.model.report(of: summary).heading == "First team imported, dated Sat 14 Nov")
        #expect(ImportReport.datingLine == "Each import is dated with this day. Set it to the day in the game before you import.")
    }

    @Test func anImportListsTheMatchesBeforeTodayWithNoConfirmedLineup() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        t.model.addTactic(named: "Main")
        t.model.addFixture(date: day("2026-11-14"), opponent: "Opponent A", importance: .medium)
        let confirmed = t.model.addFixture(date: day("2026-11-15"), opponent: "Opponent B", importance: .medium)
        t.model.addFixture(date: day("2026-11-16"), opponent: "Opponent C", importance: .medium)
        t.model.addFixture(date: day("2026-11-20"), opponent: "Opponent D", importance: .medium)
        let engine = try #require(summary(t.model.lastImport)).warnings
        // Opponent B is confirmed; Opponent A was confirmed and then unlocked, so it is not.
        let first = t.model.fixtures[0].id
        t.model.confirm(first)
        t.model.confirm(confirmed)
        t.model.unlock(first)
        #expect(t.model.history.map(\.lineup.fixture) == [confirmed])
        var settings = t.model.settings
        settings.currentDate = day("2026-11-17")
        t.model.update(settings)
        try t.importFirstTeam()
        let summary = try #require(summary(t.model.lastImport))
        #expect(summary.warnings == engine + [
            "The match against Opponent A on Sat 14 Nov has no confirmed lineup. Confirm it in Match Selection so its starts count.",
            "The match against Opponent C on Mon 16 Nov has no confirmed lineup. Confirm it in Match Selection so its starts count.",
        ])
    }

    @Test func theClubNameSettingOverridesTheSquads() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        try t.importU21()
        #expect(t.model.ownClub == t.model.squad.book.ownClub(override: nil))
        var settings = t.model.settings
        settings.clubName = "  Wallingford Town  "
        t.model.update(settings)
        #expect(t.model.ownClub == "Wallingford Town")
        #expect(t.model.squadWarnings == t.model.squad.book.warnings(override: "Wallingford Town").map(ErrorDescriptions.describe))
    }

    @Test func squadWarningsAreTheEnginesSentences() throws {
        // A team grid has no club column, and this capture has a player out on loan, so the club is unknown.
        let t = try TestModel()
        t.importSquad(.u21, paste: try Captures.text("u21-with-id.tsv"), grids: try Captures.data("u21-with-id.grids.json"))
        #expect(t.model.ownClub == nil)
        #expect(t.model.squadWarnings == [ErrorDescriptions.describe(SquadWarning.ownClubUnknown)])
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        #expect(t.model.squadWarnings.isEmpty)
    }

    // MARK: Tactics

    @Test func theFirstTacticIsPrimary() throws {
        let t = try TestModel()
        let first = t.model.addTactic(named: "Main")
        let second = t.model.addTactic(named: "Cup")
        #expect(t.model.settings.primaryTacticID == first)
        #expect(t.model.primaryTactic?.id == first)
        #expect(t.model.tactics.map(\.id) == [first, second])
        #expect(t.model.tactics.map(\.tactic.name) == ["Main", "Cup"])
        #expect(t.model.problems(of: t.model.tactics[0].tactic).isEmpty)
        t.model.makePrimary(second)
        #expect(t.model.primaryTactic?.id == second)
    }

    @Test func aNewTacticIsTheSample4231() throws {
        let t = try TestModel()
        let id = t.model.addTactic(named: "Main")
        let data = try Data(contentsOf: Captures.directory.deletingLastPathComponent()
            .appendingPathComponent("tactics/sample-4231.json"))
        var sample = try JSONDecoder().decode(Tactic.self, from: data)
        sample.name = "Main"
        #expect(t.model.tactics.first { $0.id == id }?.tactic == sample)
    }

    @Test func deletingThePrimaryPromotesTheNext() throws {
        let t = try TestModel()
        let first = t.model.addTactic(named: "Main")
        let second = t.model.addTactic(named: "Cup")
        t.model.deleteTactic(first)
        #expect(t.model.primaryTactic?.id == second)
        t.model.deleteTactic(second)
        #expect(t.model.primaryTactic == nil)
        #expect(t.model.settings.primaryTacticID == nil)
        #expect(t.model.tactics.isEmpty)
    }

    @Test func deletingATacticThatIsNotPrimaryKeepsThePrimary() throws {
        let t = try TestModel()
        let first = t.model.addTactic(named: "Main")
        let second = t.model.addTactic(named: "Cup")
        t.model.deleteTactic(second)
        #expect(t.model.primaryTactic?.id == first)
        #expect(t.model.notices.isEmpty)
    }

    @Test func deletingATacticAFixtureUsesFallsBackToThePrimaryAndSaysSo() throws {
        let t = try TestModel()
        let main = t.model.addTactic(named: "Main")
        let cup = t.model.addTactic(named: "Cup")
        let id = t.model.addFixture(date: day("2026-11-14"), opponent: "Rovers", importance: .high)
        let other = t.model.addFixture(date: day("2026-11-17"), opponent: "United", importance: .low)
        var fixture = try #require(t.model.fixtures.first { $0.id == id })
        fixture.tacticID = cup
        t.model.update(fixture)
        #expect(t.model.tactic(for: fixture)?.id == cup)

        t.model.deleteTactic(cup)
        let after = try #require(t.model.fixtures.first { $0.id == id })
        #expect(after.tacticID == nil)
        #expect(t.model.tactic(for: after)?.id == main)
        #expect(t.model.fixtures.first { $0.id == other }?.tacticID == nil)
        #expect(t.model.notices.map(\.text)
            == ["The tactic Cup was deleted, so the match against Rovers on 2026-11-14 now uses the primary tactic, Main."])
        #expect(t.reopened().fixtures.first { $0.id == id }?.tacticID == nil)
    }

    @Test func deletingTheLastTacticSaysTheFixturesHaveNone() throws {
        let t = try TestModel()
        let only = t.model.addTactic(named: "Main")
        let a = t.model.addFixture(date: day("2026-11-14"), opponent: "Rovers", importance: .high)
        let b = t.model.addFixture(date: day("2026-11-17"), opponent: "United", importance: .low)
        for id in [a, b] {
            var fixture = try #require(t.model.fixtures.first { $0.id == id })
            fixture.tacticID = only
            t.model.update(fixture)
        }
        t.model.deleteTactic(only)
        #expect(t.model.notices.map(\.text) == [
            "The tactic Main was deleted, so the matches against Rovers on 2026-11-14 and United on 2026-11-17 "
                + "have no tactic until you add one."])
        #expect(t.model.tactic(for: t.model.fixtures[0]) == nil)
    }

    @Test func aTacticWithTenPlayersReportsTheEnginesSentence() throws {
        let t = try TestModel()
        let id = t.model.addTactic(named: "Main")
        var stored = try #require(t.model.tactics.first { $0.id == id })
        stored.tactic.inPossession[.D_L] = nil
        t.model.update(stored)
        let tactic = try #require(t.model.tactics.first { $0.id == id }).tactic
        #expect(t.model.problems(of: tactic) == [ErrorDescriptions.describe(TacticProblem.wrongSlotCount(.inPossession, 10))])
        #expect(t.model.problems(of: tactic) == ["The in-possession side has 10 slots, not 11"])
    }

    @Test func duplicatingCopiesUnderANewName() throws {
        let t = try TestModel()
        let id = t.model.addTactic(named: "Main")
        let copy = try #require(t.model.duplicateTactic(id))
        #expect(copy != id)
        let original = try #require(t.model.tactics.first { $0.id == id })
        let duplicate = try #require(t.model.tactics.first { $0.id == copy })
        #expect(duplicate.tactic.name == "Main copy")
        #expect(duplicate.tactic.inPossession == original.tactic.inPossession)
        #expect(duplicate.tactic.outOfPossession == original.tactic.outOfPossession)
        #expect(duplicate.tactic.mapping == original.tactic.mapping)
        #expect(t.model.primaryTactic?.id == id)
        let again = try #require(t.model.duplicateTactic(id))
        #expect(t.model.tactics.first { $0.id == again }?.tactic.name == "Main copy 2")
        #expect(t.model.duplicateTactic(UUID()) == nil)
    }

    // MARK: Fixtures

    @Test func fixturesStayInDateOrder() throws {
        let t = try TestModel()
        let late = t.model.addFixture(date: day("2026-11-28"), opponent: "E", importance: .medium)
        let early = t.model.addFixture(date: day("2026-11-14"), opponent: "A", importance: .low)
        let middle = t.model.addFixture(date: day("2026-11-21"), opponent: "C", importance: .high)
        #expect(t.model.fixtures.map(\.id) == [early, middle, late])
        #expect(Set([late, early, middle].map(\.raw)).count == 3)
        #expect([late, early, middle].allSatisfy { UUID(uuidString: $0.raw) != nil })

        var moved = try #require(t.model.fixtures.first { $0.id == early })
        moved.date = day("2026-12-01")
        t.model.update(moved)
        #expect(t.model.fixtures.map(\.id) == [middle, late, early])
    }

    @Test func fixturesOnOneDayAreOrderedById() throws {
        let t = try TestModel()
        let a = t.model.addFixture(date: day("2026-11-14"), opponent: "A", importance: .low)
        let b = t.model.addFixture(date: day("2026-11-14"), opponent: "B", importance: .low)
        #expect(t.model.fixtures.map(\.id) == [a, b].sorted { $0.raw < $1.raw })
    }

    @Test func deletingAFixtureRemovesItsRecord() throws {
        let t = try TestModel()
        let kept = ConfirmedRecord(lineup: ConfirmedLineup(fixture: FixtureID("kept"), date: day("2026-11-07"), starters: [:]),
                                   names: [:], tacticName: "Main")
        let gone = ConfirmedRecord(lineup: ConfirmedLineup(fixture: FixtureID("gone"), date: day("2026-11-10"), starters: [:]),
                                   names: [:], tacticName: "Main")
        try Store(directory: t.directory).save([kept, gone], to: .history)
        try Store(directory: t.directory).save(
            [StoredFixture(id: FixtureID("gone"), date: day("2026-11-10"), opponent: "Rovers", importance: .high),
             StoredFixture(id: FixtureID("kept"), date: day("2026-11-07"), opponent: "United", importance: .high)],
            to: .fixtures)
        let model = t.reopened()
        #expect(model.fixtures.map(\.id.raw) == ["kept", "gone"])
        #expect(model.history.count == 2)
        model.deleteFixture(FixtureID("gone"))
        #expect(model.fixtures.map(\.id.raw) == ["kept"])
        #expect(model.history == [kept])
        #expect(t.reopened().history == [kept])
    }

    // MARK: Saving

    @Test func everyChangeIsSaved() throws {
        let t = try TestModel()
        let model = t.model
        func check(_ what: String, sourceLocation: SourceLocation = #_sourceLocation) {
            let again = t.reopened()
            expectSameState(model, again, sourceLocation: sourceLocation)
            #expect(again.notices.isEmpty, "\(what)", sourceLocation: sourceLocation)
        }
        try t.importFirstTeam(); check("import")
        try t.importU21(); check("second import")
        let main = model.addTactic(named: "Main"); check("add tactic")
        var stored = model.tactics[0]
        stored.tactic.name = "Main 2"
        model.update(stored); check("update tactic")
        let copy = try #require(model.duplicateTactic(main)); check("duplicate tactic")
        model.makePrimary(copy); check("make primary")
        let fixture = model.addFixture(date: day("2026-11-14"), opponent: "Rovers", importance: .high); check("add fixture")
        var saved = try #require(model.fixtures.first { $0.id == fixture })
        saved.tacticID = main
        saved.overrides = [.GK: model.players[0].id]
        saved.rejected = [model.players[1].id]
        model.update(saved); check("update fixture")
        model.deleteTactic(main); check("delete tactic")
        var settings = model.settings
        settings.clubName = "Oxford City"
        settings.plan.horizon = 8
        settings.conditionFloor = 80
        model.update(settings); check("update settings")
        model.deleteFixture(fixture); check("delete fixture")
    }

    @Test func aSaveThatFailsIsNoticed() throws {
        let t = try TestModel()
        let fm = FileManager.default
        try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: t.directory.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: t.directory.path) }
        let id = t.model.addFixture(date: day("2026-11-14"), opponent: "Rovers", importance: .high)
        #expect(t.model.fixtures.map(\.id) == [id])
        #expect(t.model.notices.count == 1)
        let text = try #require(t.model.notices.first?.text)
        #expect(text.hasPrefix("Your saved fixtures could not be saved"))
        #expect(text.hasSuffix("The change is kept while the app is open and is saved the next time that part of the app changes."))
    }

    @Test func aSaveThatKeepsFailingIsNoticedOnceUntilDismissed() throws {
        let t = try TestModel()
        let fm = FileManager.default
        try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: t.directory.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: t.directory.path) }
        t.model.addFixture(date: day("2026-11-14"), opponent: "Rovers", importance: .high)
        t.model.addFixture(date: day("2026-11-17"), opponent: "United", importance: .low)
        #expect(t.model.notices.count == 1)
        // Dismissed, the next failure is noticed again.
        t.model.dismiss(try #require(t.model.notices.first))
        t.model.addFixture(date: day("2026-11-20"), opponent: "City", importance: .low)
        #expect(t.model.notices.count == 1)
    }

    @Test func failuresOfDifferentFilesAreEachNoticed() throws {
        let t = try TestModel()
        let fm = FileManager.default
        try fm.setAttributes([.posixPermissions: 0o555], ofItemAtPath: t.directory.path)
        defer { try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: t.directory.path) }
        t.model.addFixture(date: day("2026-11-14"), opponent: "Rovers", importance: .high)
        t.model.addTactic(named: "Main")
        // Adding the first tactic saves the settings too, as it becomes the primary.
        #expect(t.model.notices.map { $0.text.prefix(24) }.sorted()
                == ["Your saved fixtures coul", "Your settings could not ", "Your tactics could not b"])
    }

    // MARK: Sample data

    @Test func sampleDataLoadsBothSquadsATacticAndFiveFixtures() throws {
        let model = try SampleData.model(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        #expect(model.notices.isEmpty)
        #expect(model.squad.book.current[.firstTeam]?.count == 18)
        #expect(model.squad.book.current[.u21]?.count == 6)
        #expect(model.squad.importedOn == [.firstTeam: today, .u21: today])
        #expect(model.settings.currentDate == today)
        #expect(model.ownClub == "Oxford City")
        #expect(model.tactics.count == 1)
        #expect(model.primaryTactic?.tactic.name == "Sample 4-2-3-1")
        #expect(model.problems(of: try #require(model.primaryTactic).tactic).isEmpty)
        #expect(model.fixtures.map(\.opponent) == ["Opponent A", "Opponent B", "Opponent C", "Opponent D", "Opponent E"])
        #expect(model.fixtures.map(\.importance) == [.low, .medium, .high, .sharpness, .medium])
        #expect(model.fixtures.first?.date == day("2026-11-14"))
        #expect(model.history.map(\.lineup.fixture.raw) == ["2026-11-07-played", "2026-11-10-played"])
        for record in model.history {
            #expect(record.tacticName == "Sample 4-2-3-1")
            #expect(record.lineup.starters.count == 11)
            #expect(Set(record.names.keys) == Set(record.lineup.starters.values))
        }
        #expect(model.history[0].names[PlayerID(key: "jonny maxted")] == "Jonny Maxted")
    }
}
