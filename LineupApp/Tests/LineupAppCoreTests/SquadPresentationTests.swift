import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

/// A player with ordinary values, changed by the test where it matters.
private func player(
    name: String = "Alfie Potter", squad: Squad = .firstTeam, club: String? = nil, loanedTo: String? = nil,
    isInjured: Bool = false, isBanned: Bool = false, contractType: ContractType = .fullTime,
    condition: Double = 1, sharpness: Double = 0.5538
) -> Player {
    Player(
        id: PlayerID(key: PlayerID.normalise(name)), name: name, squad: squad, age: 20, positionsText: "M/AM RL",
        currentAbility: 58, potentialAbility: 100, attributes: [:], familiarity: [:],
        condition: condition, sharpness: sharpness, jadedness: 13,
        isInjured: isInjured, isBanned: isBanned, club: club, loanedTo: loanedTo,
        contractType: contractType, monthsLeft: 10, wagePerWeek: 510, askingPrice: nil,
        nationalities: ["England"], extras: [:])
}

@Suite struct SquadNameTests {
    @Test func eachSquadHasItsNameAndImportButton() {
        #expect(Squad.allCases.map(\.displayName) == ["First team", "U21s", "U18s"])
        #expect(Squad.allCases.map(\.importButtonTitle) == ["Import first team", "Import U21s", "Import U18s"])
    }
}

@Suite struct PlayerStatusTests {
    @Test func anAvailablePlayerAtHisOwnClubHasNoStatus() {
        let statuses = PlayerStatus.of(player(club: "Oxford City"), loan: .own)
        #expect(statuses.isEmpty)
        #expect(PlayerStatus.text(statuses) == "")
        #expect(!PlayerStatus.isOut(statuses))
    }

    @Test func eachFactBecomesItsWords() {
        #expect(PlayerStatus.of(player(isInjured: true), loan: .own) == [.injured])
        #expect(PlayerStatus.of(player(isBanned: true), loan: .own) == [.banned])
        #expect(PlayerStatus.of(player(contractType: .outOfContract), loan: .own) == [.outOfContract])
        #expect(PlayerStatus.of(player(loanedTo: "Banbury United"), loan: .loanedOut(to: "Banbury United"))
            == [.outOnLoan(to: "Banbury United")])
        #expect(PlayerStatus.of(player(club: "Reading"), loan: .loanedIn(from: "Reading")) == [.onLoan(from: "Reading")])
        #expect([PlayerStatus.injured, .banned, .outOfContract, .outOnLoan(to: "Banbury United"),
                 .onLoan(from: "Reading"), .onLoan(from: nil)].map(\.text)
            == ["injured", "banned", "out of contract", "out on loan to Banbury United", "on loan from Reading", "on loan"])
    }

    @Test func aContractTypeTheToolDoesNotReadIsNotAStatus() {
        #expect(PlayerStatus.of(player(contractType: .other("NonContract")), loan: .own).isEmpty)
    }

    @Test func severalFactsAreListedTogetherLoanFirst() {
        let statuses = PlayerStatus.of(
            player(loanedTo: "Banbury United", isInjured: true, isBanned: true, contractType: .outOfContract),
            loan: .loanedOut(to: "Banbury United"))
        #expect(statuses == [.outOnLoan(to: "Banbury United"), .injured, .banned, .outOfContract])
        #expect(PlayerStatus.text(statuses) == "out on loan to Banbury United, injured, banned, out of contract")
    }

    @Test func injuredBannedAndOutOnLoanMarkAPlayerOut() {
        #expect(PlayerStatus.isOut([.injured]))
        #expect(PlayerStatus.isOut([.banned]))
        #expect(PlayerStatus.isOut([.outOnLoan(to: "Banbury United")]))
        #expect(!PlayerStatus.isOut([.onLoan(from: "Reading"), .outOfContract]))
    }
}

@MainActor @Suite struct SquadRowTests {
    @Test func everyPlayerInEverySquadHasARowInNameOrder() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        try t.importU21()
        let rows = t.model.squadRows(in: nil, matching: "")
        #expect(rows.map(\.id) == t.model.players.map(\.id))
        #expect(rows.count == 24)
    }

    @Test func aRowCarriesThePlayersFactsAndWholePercentagesRoundedDown() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let source = try #require(t.model.players.first { $0.name == "Alfie Potter" })
        let row = try #require(t.model.squadRows(in: nil, matching: "").first { $0.id == source.id })
        #expect(row.name == "Alfie Potter")
        #expect(row.squad == .firstTeam && row.squadName == "First team")
        #expect(row.age == source.age && row.positions == source.positionsText)
        #expect(row.currentAbility == source.currentAbility && row.potentialAbility == source.potentialAbility)
        #expect(row.condition == source.condition && row.sharpness == source.sharpness)
        #expect(row.conditionText == "100%")
        // 0.5538 is 55.38%, shown as 55%.
        #expect(row.sharpness == 0.5538 && row.sharpnessText == "55%")
        #expect(row.jadedness == source.jadedness)
    }

    @Test func percentagesAreRoundedDownAsTheEngineWritesThem() {
        #expect(SquadRow.percent(0.84) == "84%")
        #expect(SquadRow.percent(0.999) == "99%")
        #expect(SquadRow.percent(0.84) == Display.percent(0.84))
    }

    @Test func theSquadPickerKeepsOneSquad() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        try t.importU21()
        let u21 = t.model.squadRows(in: .u21, matching: "")
        #expect(u21.count == 6)
        #expect(u21.allSatisfy { $0.squad == .u21 && $0.squadName == "U21s" })
        #expect(t.model.squadRows(in: .firstTeam, matching: "").count == 18)
        #expect(t.model.squadRows(in: .u18, matching: "").isEmpty)
    }

    @Test func theSearchMatchesPartOfANameIgnoringCaseAndAccents() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        #expect(t.model.squadRows(in: nil, matching: "  POTTER ").map(\.name) == ["Alfie Potter"])
        #expect(t.model.squadRows(in: nil, matching: "fernándo").map(\.name) == ["Fernando Forestieri"])
        #expect(t.model.squadRows(in: nil, matching: "nobody by this name").isEmpty)
        #expect(t.model.squadRows(in: nil, matching: "   ").count == 18)
    }

    @Test func theSquadOrderSortsFirstTeamThenU21ThenU18() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        try t.importU21()
        let orders = t.model.squadRows(in: nil, matching: "").sorted { $0.squadOrder < $1.squadOrder }.map(\.squad)
        #expect(orders == Array(repeating: Squad.firstTeam, count: 18) + Array(repeating: .u21, count: 6))
        #expect(Squad.allCases.map { SquadRow.order(of: $0) } == [0, 1, 2])
    }

    @Test func aPlayerOutOnLoanShowsWhereAndIsMarkedOut() throws {
        let t = try TestModel()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        try t.importU21()
        let rows = t.model.squadRows(in: nil, matching: "")
        let loaned = rows.filter { $0.statuses.contains { if case .outOnLoan = $0 { true } else { false } } }
        #expect(!loaned.isEmpty)
        for row in loaned {
            let source = try #require(t.model.players.first { $0.id == row.id })
            #expect(row.statusText.hasPrefix("out on loan to \(source.loanedTo!)"))
            #expect(row.isOut)
        }
        #expect(rows.contains { !$0.isOut && $0.statusText.isEmpty })
    }
}

@MainActor @Suite struct ImportedOnTests {
    @Test func aSquadNeverImportedSaysSo() throws {
        let t = try TestModel()
        #expect(Squad.allCases.map(t.model.importedText(for:)) == ["Not imported yet", "Not imported yet", "Not imported yet"])
    }

    @Test func anImportedSquadShowsTheDayOfItsLastImport() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        #expect(t.model.importedText(for: .firstTeam) == "Imported 13 Nov, \(t.model.players.filter { $0.squad == .firstTeam }.count) players")
        #expect(t.model.importedText(for: .u21) == "Not imported yet")
    }
}

@MainActor @Suite struct ImportReportTests {
    private func summary(_ t: TestModel) throws -> ImportSummary {
        guard case .imported(let summary)? = t.model.lastImport else {
            throw SampleDataError(description: "expected an import summary, got \(String(describing: t.model.lastImport))")
        }
        return summary
    }

    @Test func aFirstImportNamesTheGridCountsThePlayersAndSaysItIsTheFirst() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let report = t.model.report(of: try summary(t))
        #expect(report.heading == "First team imported, dated Fri 13 Nov")
        #expect(report.lines == [
            "Recognised as FMRTE's squad grid.",
            "18 players.",
            "No one is out on loan.",
            "This is the first import of this squad.",
        ])
        #expect(report.warnings == (try summary(t)).warnings)
        #expect(!report.warnings.isEmpty)
    }

    @Test func playersOutOnLoanAreNamed() throws {
        let t = try TestModel()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        try t.importU21()
        let s = try summary(t)
        #expect(!s.onLoan.isEmpty)
        #expect(t.model.report(of: s).lines[2] == "Out on loan: \(s.onLoan.joined(separator: ", ")).")
    }

    @Test func theSameImportAgainChangesNothing() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        try t.importFirstTeam()
        #expect(t.model.report(of: try summary(t)).lines.last == "Nothing changed since the last import.")
    }

    @Test func aSecondImportNamesWhoWasAddedAndRemoved() throws {
        let t = try TestModel()
        let full = try Captures.firstTeam
        var lines = full.split(separator: "\r\n", omittingEmptySubsequences: true)
        let first = lines.removeFirst()
        t.importSquad(.firstTeam, paste: full, grids: try Captures.firstTeamGrids)
        t.importSquad(.firstTeam, paste: lines.joined(separator: "\r\n") + "\r\n", grids: try Captures.firstTeamGrids)
        #expect(first.contains("Alfie Potter"))
        #expect(t.model.report(of: try summary(t)).lines.last == "Since the last import: 1 removed (Alfie Potter).")

        t.importSquad(.firstTeam, paste: full, grids: try Captures.firstTeamGrids)
        #expect(t.model.report(of: try summary(t)).lines.last == "Since the last import: 1 added (Alfie Potter).")
    }

    @Test func aChangedPlayerIsCountedNotNamed() throws {
        let t = try TestModel()
        let full = try Captures.firstTeam
        t.importSquad(.firstTeam, paste: full, grids: try Captures.firstTeamGrids)
        // Alfie Potter's condition, 10000, becomes 9000.
        let changed = full.replacingOccurrences(of: "\"37\"\t\"10000\"", with: "\"37\"\t\"9000\"")
        #expect(changed != full)
        t.importSquad(.firstTeam, paste: changed, grids: try Captures.firstTeamGrids)
        #expect(t.model.report(of: try summary(t)).lines.last == "Since the last import: 1 changed.")
    }

    @Test func aPlayerFromAnotherSquadIsReportedAsMovedInNotAdded() {
        let summary = ImportSummary(
            squad: .u21, date: TestModel.today, grid: "SearchPlayersColumns", playerCount: 3, onLoan: [], warnings: [],
            change: SquadChange(added: [PlayerID(key: "a"), PlayerID(key: "b")], removed: [], movedIn: [PlayerID(key: "b")], changed: []))
        let names = [PlayerID(key: "a"): "Ann Able", PlayerID(key: "b"): "Ben Best"]
        #expect(ImportReport.changeLine(summary.change, firstImport: false, name: { names[$0] ?? $0.key })
            == "Since the last import: 1 added (Ann Able); 1 moved in from another squad (Ben Best).")
    }

    @Test func everyKindOfChangeIsListedInOneSentence() {
        let ids = (1...9).map { PlayerID(key: "p\($0)") }
        let change = SquadChange(added: Array(ids[0...6]), removed: [ids[7]], movedIn: [], changed: [ids[8]])
        #expect(ImportReport.changeLine(change, firstImport: false, name: { $0.key })
            == "Since the last import: 7 added (p1, p2, p3, p4, p5 and 2 more); 1 removed (p8); 1 changed.")
    }

    @Test func aFirstImportIsNotListedAsAdditions() {
        let change = SquadChange(added: [PlayerID(key: "a")], removed: [], movedIn: [], changed: [])
        #expect(ImportReport.changeLine(change, firstImport: true, name: { $0.key }) == "This is the first import of this squad.")
    }

    @Test func theGridIsNamedInTheOwnersWords() {
        #expect(ImportReport.gridLine("TeamPlayersColumns") == "Recognised as FMRTE's squad grid.")
        #expect(ImportReport.gridLine("SearchPlayersColumns") == "Recognised as FMRTE's player search grid.")
        #expect(ImportReport.gridLine("WonderKidsNotificationColumns")
            == "Recognised as FMRTE's grid \"WonderKidsNotificationColumns\".")
    }

    @Test func aU21ImportFromThePlayerSearchSaysSo() throws {
        let t = try TestModel()
        try t.importU21()
        #expect(t.model.report(of: try summary(t)).lines.first == "Recognised as FMRTE's player search grid.")
    }

    @Test func oneIsOnePlayer() {
        #expect(ImportReport.playerCountLine(1) == "1 player.")
        #expect(ImportReport.playerCountLine(0) == "0 players.")
    }
}

@MainActor @Suite struct ClubLineTests {
    @Test func aKnownClubIsNamed() throws {
        let t = try TestModel()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        #expect(t.model.clubLine == .known("Oxford City"))
        #expect(t.model.clubLine.text == "Club: Oxford City")
        #expect(!t.model.clubLine.needsSettings)
    }

    @Test func anUnknownClubShowsTheEnginesWarningAndIsNotListedTwice() throws {
        let t = try TestModel()
        t.importSquad(.u21, paste: try Captures.text("u21-with-id.tsv"), grids: try Captures.data("u21-with-id.grids.json"))
        let warning = ErrorDescriptions.describe(SquadWarning.ownClubUnknown)
        #expect(t.model.clubLine == .unknown(warning: warning))
        #expect(t.model.clubLine.text == warning)
        #expect(t.model.clubLine.needsSettings)
        #expect(t.model.squadWarnings == [warning])
        #expect(t.model.listedSquadWarnings.isEmpty)
    }

    @Test func otherSquadWarningsAreListed() throws {
        let t = try TestModel()
        // The same name-keyed paste in two squads with a changed potential makes two players of one name.
        let paste = try Captures.firstTeam
        t.importSquad(.firstTeam, paste: paste, grids: try Captures.firstTeamGrids)
        let renamed = paste.replacingOccurrences(of: "\"Alfie Potter\"\t\"M/AM RL\"\t\"England\"\t\"58\"\t\"100\"",
                                                 with: "\"Alfie Potter\"\t\"M/AM RL\"\t\"England\"\t\"58\"\t\"101\"")
        #expect(renamed != paste)
        t.importSquad(.u18, paste: renamed, grids: try Captures.firstTeamGrids)
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        #expect(t.model.listedSquadWarnings.contains(ErrorDescriptions.describe(SquadWarning.sharedName("Alfie Potter"))))
        #expect(t.model.listedSquadWarnings == t.model.squadWarnings)
    }
}

@Suite struct SquadSortTests {
    private func row(_ name: String, key: String? = nil, squad: Squad = .firstTeam, condition: Double = 1) -> SquadRow {
        var p = player(name: name, squad: squad, condition: condition)
        if let key { p.id = PlayerID(key: key) }
        return SquadRow(p, loan: .own)
    }

    @Test func noSortOrderKeepsTheRowsAsGiven() {
        let rows = [row("Zac"), row("Alfie")]
        #expect(SquadRow.sorted(rows, using: []).map(\.name) == ["Zac", "Alfie"])
    }

    @Test func aColumnSortsItsValuesEitherWay() {
        let rows = [row("Ann", condition: 0.9), row("Ben", condition: 0.7), row("Cal", condition: 0.8)]
        #expect(SquadRow.sorted(rows, using: [KeyPathComparator(\.condition)]).map(\.name) == ["Ben", "Cal", "Ann"])
        #expect(SquadRow.sorted(rows, using: [KeyPathComparator(\.condition, order: .reverse)]).map(\.name)
            == ["Ann", "Cal", "Ben"])
    }

    @Test func tiesBreakOnNameThenKeyWhicheverWayTheColumnRuns() {
        let rows = [row("Zac", condition: 1), row("Ann", key: "b", condition: 1), row("Ann", key: "a", condition: 1),
                    row("Max", condition: 0.5)]
        let up = SquadRow.sorted(rows, using: [KeyPathComparator(\.condition)])
        #expect(up.map(\.name) == ["Max", "Ann", "Ann", "Zac"])
        #expect(up.map(\.id.key) == ["max", "a", "b", "zac"])
        let down = SquadRow.sorted(rows, using: [KeyPathComparator(\.condition, order: .reverse)])
        #expect(down.map(\.id.key) == ["a", "b", "zac", "max"])
    }

    @Test func theSquadColumnSortsFirstTeamU21sU18s() {
        let rows = [row("Ann", squad: .u18), row("Ben", squad: .firstTeam), row("Cal", squad: .u21)]
        #expect(SquadRow.sorted(rows, using: [KeyPathComparator(\.squadOrder)]).map(\.squad) == [.firstTeam, .u21, .u18])
    }
}
