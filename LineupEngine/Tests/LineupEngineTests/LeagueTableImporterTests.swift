import Foundation
import Testing
@testable import LineupEngine

@Suite struct LeagueTableImporterTests {
    private let paths = ["Position", "TeamName", "GamesPlayed", "Wins", "Draws", "Loses", "GoalsScored", "GoalsAllowed", "Points"]

    private func read(_ clipboard: String, config: Data? = nil, club: String? = "Oxford City") throws -> LeagueTable {
        try LeagueTableImporter.read(clipboard: clipboard, fmrteConfig: config ?? Fixtures.leagueTableGrids, ownClub: club,
                                     parameters: .fm27)
    }

    /// The fixture's lines, each a tab-separated row of quoted fields.
    private func lines() throws -> [String] {
        try Fixtures.leagueTable.split(separator: "\n").map(String.init)
    }

    private func text(_ lines: [String]) -> String { lines.joined(separator: "\n") + "\n" }

    /// One row of unquoted fields, with `fields` replacing the fixture's row for `team`.
    private func row(_ team: String, set column: String, to value: String, in lines: [String]) throws -> [String] {
        let index = paths.firstIndex(of: column)!
        return lines.map { line in
            var fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields[1] == "\"\(team)\"" else { return line }
            fields[index] = "\"\(value)\""
            return fields.joined(separator: "\t")
        }
    }

    private func config(_ columns: [String], key: String = "CompetitionStandings") -> Data {
        Self.config([(key, columns)])
    }

    private static func config(_ grids: [(String, [String])]) -> Data {
        let items = grids.map { key, columns in
            ["SettingsKey": key, "Sort": NSNull(),
             "Columns": columns.map { ["Name": NSNull(), "Path": $0, "IsWritable": true, "Converter": "None",
                                       "StringFormat": "Auto", "Width": NSNull()] as [String: Any] }] as [String: Any]
        }
        return try! JSONSerialization.data(withJSONObject: ["ColumnsSettings": ["Items": items]])
    }

    @Test func theOwnersTableIsReadWhole() throws {
        let table = try read(Fixtures.leagueTable)
        #expect(table.teams.count == 24)
        #expect(table.teams[0] == LeagueTeam(name: "Chester", played: 42, won: 25, drawn: 12, lost: 5, goalsFor: 65,
                                             goalsAgainst: 33, points: 87))
        #expect(table.teams[0].goalDifference == 32)
        #expect(table.teams[4].name == "Oxford City")
        #expect(table.teams[14].name == "King's Lynn")
        #expect(table.orderWorkedOut == false)
        #expect(table.warnings.isEmpty)
        #expect(table.seasonMatches == 46)
        #expect(table.place(of: " oxford  CITY") == 5)
        #expect(table.team(named: "marine")?.points == 35)
        #expect(table.place(of: "Nobody") == nil)
    }

    @Test func rowsOutOfOrderAreSortedByTheirPlace() throws {
        let whole = try read(Fixtures.leagueTable)
        let reversed = try read(text(Array(lines().reversed())))
        #expect(reversed == whole)
    }

    @Test func withoutAPlaceColumnTheOrderIsWorkedOut() throws {
        let without = try lines().map { line in
            line.split(separator: "\t", omittingEmptySubsequences: false).dropFirst().joined(separator: "\t")
        }
        // Oxford City (74, GD 20) and Buxton (74, GD 14) are level on points already; shuffle the rows.
        let shuffled = without.enumerated().sorted { ($0.offset * 7) % 24 < ($1.offset * 7) % 24 }.map(\.element)
        let table = try read(text(shuffled), config: config(Array(paths.dropFirst())))
        #expect(table.orderWorkedOut)
        #expect(table.teams.map(\.name) == (try read(Fixtures.leagueTable)).teams.map(\.name))
        #expect(table.teams[4].name == "Oxford City" && table.teams[5].name == "Buxton")
    }

    @Test func pointsLevelThenGoalDifferenceThenGoalsForThenNameOrderTheTeams() throws {
        func line(_ name: String, gf: Int, ga: Int) -> String {
            ["\(name)", "2", "1", "0", "1", "\(gf)", "\(ga)", "3"].map { "\"\($0)\"" }.joined(separator: "\t")
        }
        // All on 3 points from 2 matches (1 win, 1 loss; the fixture's points rule is 3 and 0 here, so the draw column is 0).
        let rows = [line("Delta", gf: 3, ga: 3), line("Charlie", gf: 4, ga: 4), line("Alpha", gf: 5, ga: 4),
                    line("Bravo", gf: 4, ga: 4)]
        let table = try read(text(rows), config: config(Array(paths.dropFirst())), club: "Delta")
        #expect(table.teams.map(\.name) == ["Alpha", "Bravo", "Charlie", "Delta"])
        #expect(table.orderWorkedOut)
    }

    @Test func placesThatAreNotOneToTheCountAreRefused() throws {
        let changed = try row("Spalding", set: "Position", to: "2", in: lines())
        #expect(throws: LeagueTableError.placesNotInOrder) { try read(text(changed)) }
        let three = try row("Hednesford", set: "Position", to: "3", in: lines())
        #expect(throws: LeagueTableError.placesNotInOrder) { try read(text(three)) }
    }

    @Test(arguments: ["", "x", "-3", "4.5", "+7"])
    func aBlankOrWordyCellNamesTheTeamAndColumn(_ value: String) throws {
        let changed = try row("Buxton", set: "Points", to: value, in: lines())
        #expect(throws: LeagueTableError.invalidValue(team: "Buxton", column: "Points", value: value)) {
            try read(text(changed))
        }
    }

    @Test(arguments: ["", "  "])
    func aBlankTeamNameIsRefused(_ value: String) throws {
        let changed = try row("Buxton", set: "TeamName", to: value, in: lines())
        #expect(throws: LeagueTableError.invalidValue(team: "", column: "TeamName", value: value)) {
            try read(text(changed))
        }
    }

    @Test func aMissingColumnIsNamed() throws {
        let columns = paths.filter { $0 != "GoalsAllowed" }
        let rows = try lines().map { line in
            var fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            fields.remove(at: 7)
            return fields.joined(separator: "\t")
        }
        #expect(throws: LeagueTableError.missingColumns(grid: "CompetitionStandings", columns: ["GoalsAllowed"])) {
            try read(text(rows), config: config(columns))
        }
    }

    @Test func resultsThatDoNotAddUpAreRefused() throws {
        let changed = try row("Chester", set: "GamesPlayed", to: "43", in: lines())
        #expect(throws: LeagueTableError.resultsDoNotAddUp(team: "Chester", played: 43, won: 25, drawn: 12, lost: 5)) {
            try read(text(changed))
        }
    }

    @Test func moreMatchesThanASeasonHoldsIsRefused() throws {
        var changed = try row("Chester", set: "GamesPlayed", to: "47", in: lines())
        changed = try row("Chester", set: "Loses", to: "10", in: changed)
        #expect(throws: LeagueTableError.playedTooMany(team: "Chester", played: 47, season: 46)) { try read(text(changed)) }
    }

    @Test func aFullSeasonIsNotTooMany() throws {
        var changed = try row("Chester", set: "GamesPlayed", to: "46", in: lines())
        changed = try row("Chester", set: "Loses", to: "9", in: changed)
        #expect(try read(text(changed)).teams[0].played == 46)
    }

    @Test func pointsThatDoNotFitResultsAreKeptWithAWarning() throws {
        let changed = try row("Marine", set: "Points", to: "32", in: lines())
        let table = try read(text(changed))
        #expect(table.team(named: "Marine")?.points == 32)
        #expect(table.warnings == [.pointsDoNotFit(team: "Marine", points: 32, fromResults: 35)])
    }

    @Test func aTeamTwiceIsRefused() throws {
        let changed = try row("Marine", set: "TeamName", to: "chester ", in: lines())
        do {
            _ = try read(text(changed))
            Issue.record("expected a refusal")
        } catch let error as LeagueTableError {
            guard case .duplicateTeam = error else { Issue.record("wrong error \(error)"); return }
        }
    }

    @Test func oneTeamIsTooFew() throws {
        let one = try [#require(lines().first)]
        #expect(throws: LeagueTableError.tooFewTeams(found: 1)) { try read(text(one), club: "Chester") }
    }

    @Test func aClubNotInTheTableIsRefused() throws {
        #expect(throws: LeagueTableError.clubNotInTable(club: "Banbury United", teams: 24)) {
            try read(Fixtures.leagueTable, club: "Banbury United")
        }
    }

    @Test func noClubKnownIsRefused() throws {
        #expect(throws: LeagueTableError.noClubKnown) { try read(Fixtures.leagueTable, club: nil) }
    }

    @Test func theClubIsFoundWhateverItsCaseAndSpacing() throws {
        #expect(try read(Fixtures.leagueTable, club: " oxford  city").teams.count == 24)
    }

    @Test func aSquadPasteIsRefusedAsNoStandingsGrid() throws {
        let squad = try Fixtures.text("captures/first-team.tsv")
        #expect(throws: LeagueTableError.noStandingsGrid) {
            try read(squad, config: Fixtures.data("captures/first-team.grids.json"))
        }
        let fields = try ClipboardText.rows(squad)[0].count
        #expect(throws: LeagueTableError.noGridFits(fieldCount: fields)) { try read(squad) }
    }

    @Test func twoStandingsGridsOfTheSameWidthAndDifferentColumnsAreAmbiguous() throws {
        var other = paths
        other.swapAt(2, 3)
        let both = Self.config([("CompetitionStandings", paths), ("CompetitionGroupStandings", other)])
        #expect(throws: LeagueTableError.ambiguousGrid(keys: ["CompetitionGroupStandings", "CompetitionStandings"])) {
            try read(Fixtures.leagueTable, config: both)
        }
        let same = Self.config([("CompetitionStandings", paths), ("CompetitionGroupStandings", paths)])
        #expect(try read(Fixtures.leagueTable, config: same).teams.count == 24)
    }

    @Test func crlfUnquotedFieldsAndATrailingBlankLineAreRead() throws {
        let messy = try Fixtures.leagueTable.replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "\n", with: "\r\n") + "\n\n"
        #expect(try read(messy) == read(Fixtures.leagueTable))
    }

    @Test func theSplitterErrorsPassThrough() throws {
        #expect(throws: ImportError.emptyClipboard) { try read("") }
        #expect(throws: ImportError.self) { try read("no tabs here") }
        #expect(throws: ImportError.raggedRows(expected: 9, row: 2, found: 3)) {
            try read("1\ta\t1\t1\t0\t0\t1\t0\t3\n2\tb\t1")
        }
        #expect(throws: ImportError.self) { try read(Fixtures.leagueTable, config: Data("not json".utf8)) }
    }
}
