import Testing
@testable import LineupEngine

private func searchCapture() throws -> (rows: [[String]], grids: [GridLayout]) {
    (try ClipboardText.rows(Fixtures.text("captures/u21.tsv")),
     try FMRTEConfig.playerGrids(from: Fixtures.data("captures/u21.grids.json")))
}

@Test func realPasteFitsTheSearchGridOnly() throws {
    let rows = try ClipboardText.rows(Fixtures.text("captures/u21.tsv"))
    let grids = try FMRTEConfig.playerGrids(from: Fixtures.data("captures/u21.grids.json"))
    #expect(try GridDetector.detect(rows: rows, grids: grids).key == "SearchPlayersColumns")
    let team = grids.first { $0.key == "TeamPlayersColumns" }!
    #expect(GridDetector.violations(rows: rows, layout: team) > 0)
}

@Test func balanceCurrencySignIsAcceptedOnBalanceAndNowhereElse() {
    let layout = GridLayout(key: "g", columns: ["DisplayedName", "PhysicalAttributes.Balance", "PhysicalAttributes.Pace"])
    #expect(GridDetector.violations(rows: [["A Player", "£11", "9"]], layout: layout) == 0)
    #expect(GridDetector.violations(rows: [["A Player", "11", "9"]], layout: layout) == 0)
    #expect(GridDetector.violations(rows: [["A Player", "11", "£9"]], layout: layout) == 1)
}

@Test func twoLayoutsThatBothFitAreAmbiguous() {
    let a = GridLayout(key: "a", columns: ["DisplayedName", "PhysicalAttributes.Pace", "PhysicalAttributes.Strength"])
    let b = GridLayout(key: "b", columns: ["DisplayedName", "PhysicalAttributes.Strength", "PhysicalAttributes.Pace"])
    #expect(throws: ImportError.ambiguousGrid(keys: ["a", "b"])) {
        try GridDetector.detect(rows: [["A Player", "9", "12"]], grids: [a, b])
    }
}

@Test func aPasteWithTheWrongFieldCountHasNoCandidates() throws {
    let (_, grids) = try searchCapture()
    let rows = [["A", "B", "C", "D", "E"]]
    #expect(throws: ImportError.noGridFits(fieldCount: 5, violationsByGrid: [:])) {
        try GridDetector.detect(rows: rows, grids: grids)
    }
}

@Test func noCandidateReportsViolationCounts() {
    let g = GridLayout(key: "g", columns: ["DisplayedName", "Age", "CA"])
    // empty name, age 5 and CA 500 each violate their column's type
    #expect(throws: ImportError.noGridFits(fieldCount: 3, violationsByGrid: ["g": 3])) {
        try GridDetector.detect(rows: [["", "5", "500"]], grids: [g])
    }
    // a layout of another width is not a candidate and is not counted
    let other = GridLayout(key: "other", columns: ["DisplayedName", "Age"])
    #expect(throws: ImportError.noGridFits(fieldCount: 3, violationsByGrid: ["g": 3])) {
        try GridDetector.detect(rows: [["", "5", "500"]], grids: [g, other])
    }
}

@Test func teamGridPasteFitsTheTeamGridAmongTenGrids() throws {
    let rows = try ClipboardText.rows(Fixtures.text("captures/u21-team-grid.tsv"))
    let grids = try FMRTEConfig.playerGrids(from: Fixtures.data("captures/u21-team-grid.grids.json"))
    #expect(grids.count == 10)
    #expect(try GridDetector.detect(rows: rows, grids: grids).key == "TeamPlayersColumns")
}

@Test func fittingGridWithoutARequiredColumnNamesIt() throws {
    let (rows, grids) = try searchCapture()
    let search = try #require(grids.first { $0.key == "SearchPlayersColumns" })
    let drop = try #require(search.columns.firstIndex(of: "Condition"))
    let layout = GridLayout(key: search.key, columns: search.columns.enumerated().filter { $0.offset != drop }.map(\.element))
    let trimmed = rows.map { row in row.enumerated().filter { $0.offset != drop }.map(\.element) }
    #expect(throws: ImportError.missingColumns(grid: "SearchPlayersColumns", columns: ["Condition"])) {
        try GridDetector.detect(rows: trimmed, grids: [layout])
    }
}

@Test func clubAndAskingPriceAreNotRequired() {
    #expect(!GridDetector.requiredColumns.contains("Contract.Club"))
    #expect(!GridDetector.requiredColumns.contains("AskingPrice"))
    #expect(GridDetector.requiredColumns.count == 14 + 62 + 14)
    #expect(Set(GridDetector.requiredColumns).count == 90)
}

// MARK: - FMRTE's Id column

@Test func aPasteWithAnIdColumnFitsTheTeamGrid() throws {
    let rows = try ClipboardText.rows(Fixtures.text("captures/first-team-with-id.tsv"))
    let grids = try FMRTEConfig.playerGrids(from: Fixtures.data("captures/first-team-with-id.grids.json"))
    let layout = try GridDetector.detect(rows: rows, grids: grids)
    #expect(layout.key == "TeamPlayersColumns")
    #expect(layout.columns.count == 99 && layout.columns.last == "Id")
    // The search grid in the same snapshot has no Id column and one column fewer.
    let search = try #require(grids.first { $0.key == "SearchPlayersColumns" })
    #expect(search.columns.count == 98 && !search.columns.contains("Id"))
}

@Test func idIsNotARequiredColumn() throws {
    #expect(!GridDetector.requiredColumns.contains("Id"))
    // A grid without it still detects.
    let (rows, grids) = try searchCapture()
    #expect(try GridDetector.detect(rows: rows, grids: grids).key == "SearchPlayersColumns")
}

@Test func anIdMustBeAWholePositiveNumber() {
    for value in ["146837", "1", "2000482787"] { #expect(violations("Id", value) == 0, "Id accepts \(value)") }
    for value in ["", "0", "-5", "12a", "£12", "1,234", "+5", " 12", "1.5"] {
        #expect(violations("Id", value) == 1, "Id rejects \(value)")
    }
}

@Test func reorderedColumnsStillDetect() throws {
    let (rows, grids) = try searchCapture()
    let search = try #require(grids.first { $0.key == "SearchPlayersColumns" })
    let reversed = GridLayout(key: "Reversed", columns: search.columns.reversed())
    let reversedRows = rows.map { Array($0.reversed()) }
    #expect(try GridDetector.detect(rows: reversedRows, grids: [reversed]).key == "Reversed")
}

// MARK: - One test per type rule: a value that fits, and values that do not.

private func violations(_ column: String, _ value: String) -> Int {
    GridDetector.violations(rows: [[value]], layout: GridLayout(key: "g", columns: [column]))
}

@Test(arguments: [
    ("MentalAttributes.Flair", ["1", "20", "13"], ["0", "21", "", "x", "1.5", "-3", "£5", "5£"]),
    ("Positions.Striker", ["1", "20"], ["0", "21", "", "£5"]),
    ("IsInjured", ["True", "False"], ["true", "1", ""]),
    ("IsBanned", ["True", "False"], ["yes", ""]),
    ("Condition", ["0", "10000", "8167"], ["-1", "10001", "", "99.5"]),
    ("MatchSharpness", ["0", "10000"], ["-1", "10001", "abc"]),
    // A signed 16-bit field in the game.
    ("Jadedness", ["-32768", "32767", "-1001", "1001", "-122", "0"], ["-32769", "32768", "", "x", "1.5"]),
    ("Age", ["14", "60", "20"], ["13", "61", "", "x"]),
    ("CA", ["1", "200"], ["0", "201", ""]),
    ("PA", ["1", "200"], ["0", "201", ""]),
    ("Contract.WagePerWeek", ["£500", "€1,200", "$12.000", "£1,234.50", "£1,234.5", "£1.234"],
     ["500", "£", "£abc", "", "£5 00x", "£1.2345", "£1.", "£1.2.3", "£12.34.56", "£.50", "£1.23,4"]),
    ("AskingPrice", ["£25,250"], ["25,250", ""]),
    ("DisplayedName", ["Brayden Daniel", "R2D2 Jr"], ["", "12345"]),
    ("Contract.Club", ["", "Oxford City", "123"], []),
])
func typeRule(column: String, good: [String], bad: [String]) {
    for value in good { #expect(violations(column, value) == 0, "\(column) accepts \(value)") }
    for value in bad { #expect(violations(column, value) == 1, "\(column) rejects \(value)") }
}

@Test func balanceAcceptsEachCurrencySymbolButStillNeedsARating() {
    for symbol in ["£", "$", "€"] { #expect(violations("PhysicalAttributes.Balance", symbol + "11") == 0) }
    #expect(violations("PhysicalAttributes.Balance", "£") == 1)
    #expect(violations("PhysicalAttributes.Balance", "££11") == 1)
    #expect(violations("PhysicalAttributes.Balance", "£21") == 1)
}

@Test func violationsCountEveryBadCellInEveryRow() {
    let layout = GridLayout(key: "g", columns: ["Age", "CA"])
    #expect(GridDetector.violations(rows: [["20", "50"], ["5", "500"], ["61", "60"]], layout: layout) == 3)
}

@Test func requiredColumnsAreBuiltFromTheEnums() {
    let required = Set(GridDetector.requiredColumns)
    for attribute in Attribute.allCases { #expect(required.contains(attribute.fmrtePath)) }
    for position in Position.allCases { #expect(required.contains(position.fmrtePath)) }
}

@Test(arguments: [("£1,234.50", 1235), ("£1,234.49", 1234), ("£1,234.5", 1235), ("£1.234", 1234), ("£1,234", 1234),
                  ("$12.000", 12000), ("€1.234.567", 1_234_567), ("£0.50", 1), ("£0.49", 0), ("£500", 500),
                  ("£25,250", 25250), ("£1 234", 1234)])
func moneyIsReadToTheNearestPound(cell: String, pounds: Int) {
    #expect(GridDetector.moneyValue(cell) == pounds)
}

@Test(arguments: ["£1.2345", "£1.", "£1.2.3", "500", "£", "£.5"])
func moneyThatIsNotAnAmountHasNoValue(cell: String) {
    #expect(GridDetector.moneyValue(cell) == nil)
}
