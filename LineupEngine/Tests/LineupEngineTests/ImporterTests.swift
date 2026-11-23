import Foundation
import Testing
@testable import LineupEngine

private func importU21() throws -> ImportResult {
    try Importer.importPlayers(clipboard: Fixtures.text("captures/u21.tsv"),
                               fmrteConfig: Fixtures.data("captures/u21.grids.json"), squad: .u21)
}

private func u21() throws -> [Player] { try importU21().players }

/// The search-grid paste with `change` applied to its rows (each a list of fields), re-joined
/// with tabs and CRLF, imported against the real two-grid config, or against `settings` when given.
private func importU21(settings: Data? = nil, changingRows change: ([[String]]) -> [[String]]) throws -> ImportResult {
    let rows = try Fixtures.text("captures/u21.tsv")
        .components(separatedBy: "\r\n").filter { !$0.isEmpty }
        .map { $0.components(separatedBy: "\t") }
    let text = change(rows).map { $0.joined(separator: "\t") }.joined(separator: "\r\n") + "\r\n"
    return try Importer.importPlayers(clipboard: text,
                                      fmrteConfig: settings ?? Fixtures.data("captures/u21.grids.json"), squad: .u21)
}

/// The U21 paste imported with FMRTE set to `wages`, every wage cell's pound sign made `symbol`, and Brayden Daniel's
/// (the first row's) wage `firstWage`.
private func importU21(wages: String, symbol: String, firstWage: String) throws -> ImportResult {
    let wage = try column("Contract.WagePerWeek")
    return try importU21(settings: Fixtures.settings("u21", wages: wages)) { rows in
        var rows = rows.map { row in
            var row = row
            row[wage] = row[wage].replacingOccurrences(of: "£", with: symbol)
            return row
        }
        rows[0][wage] = quoted(firstWage)
        return rows
    }
}

/// Where a column sits in the search grid.
private func column(_ path: String) throws -> Int {
    try #require(Fixtures.gridColumns("u21", grid: "SearchPlayersColumns").firstIndex(of: path))
}

/// The fields of a row are quoted in the capture; keep that when replacing one.
private func quoted(_ value: String) -> String { "\"\(value)\"" }

/// The first-team team-grid paste taken with FMRTE's `Id` column, with `change` applied to its
/// rows, imported against the snapshot taken with it.
private func importFirstTeamWithIDs(changingRows change: ([[String]]) -> [[String]] = { $0 }) throws -> ImportResult {
    let rows = try Fixtures.text("captures/first-team-with-id.tsv")
        .components(separatedBy: "\r\n").filter { !$0.isEmpty }
        .map { $0.components(separatedBy: "\t") }
    let text = change(rows).map { $0.joined(separator: "\t") }.joined(separator: "\r\n") + "\r\n"
    return try Importer.importPlayers(clipboard: text,
                                      fmrteConfig: Fixtures.data("captures/first-team-with-id.grids.json"), squad: .firstTeam)
}

/// Where a column sits in the team grid that has the `Id` column.
private func teamColumn(_ path: String) throws -> Int {
    try #require(Fixtures.gridColumns("first-team-with-id", grid: "TeamPlayersColumns").firstIndex(of: path))
}

/// The three cells FMRTE leaves blank together for a player with no contract.
private let contractPaths = ["Contract.ContractType", "Contract.MonthsLeft", "Contract.WagePerWeek"]

/// The search-grid paste with the contract cells of the rows at `indices` blanked (every row when nil), as FMRTE
/// pastes a player with no contract; `alsoClub` blanks his club too, as it does for one with no club.
private func importU21(withNoContractAt indices: Set<Int>?, alsoClub: Bool = true) throws -> ImportResult {
    let cells = try (contractPaths + (alsoClub ? ["Contract.Club"] : [])).map(column)
    return try importU21 { rows in
        rows.enumerated().map { index, row in
            guard indices?.contains(index) ?? true else { return row }
            var row = row
            for cell in cells { row[cell] = quoted("") }
            return row
        }
    }
}

/// The owner's search result of 19 November 2026: 109 players of other clubs and of none, in dollars a month.
private func importSearch() throws -> ImportResult {
    try Importer.importPlayers(clipboard: Fixtures.text("captures/scouting-search.tsv"),
                               fmrteConfig: Fixtures.settings("scouting-search", wages: "Monthly"), squad: .firstTeam)
}

/// True for the warnings that come from telling namesakes apart, or from having no ids at all.
private func isNameWarning(_ warning: ImportWarning) -> Bool {
    switch warning {
    case .duplicateName, .indistinguishable, .identifiedByName: true
    case .outOfContract: false
    }
}

@Suite struct ImporterTests {
    @Test func importsTheRealU21Paste() throws {
        let r = try importU21()
        #expect(r.grid == "SearchPlayersColumns")
        #expect(r.players.count == 6)
        let daniel = try #require(r.players.first { $0.name == "Brayden Daniel" })
        #expect(daniel.squad == .u21 && daniel.age == 20)
        #expect(daniel.currentAbility == 50 && daniel.potentialAbility == 70)
        #expect(daniel.condition == 0.8167 && daniel.sharpness == 0.725 && daniel.jadedness == -122)
        #expect(daniel.attributes[.init(catalogName: "Balance")!] == 6)          // pasted as "£6"
        #expect(daniel.familiarity[.init(rawValue: "AM (R)")!] == 20)
        #expect(daniel.familiarity[.init(rawValue: "M (R)")!] == 15)
        #expect(daniel.askingPrice == 25_250 && daniel.wagePerWeek == 500)
        #expect(daniel.club == "Oxford City" && daniel.loanedTo == nil)
        #expect(daniel.attributes.count == 62 && daniel.familiarity.count == 14)
    }

    /// FMRTE 27.1.0 build 14 stopped writing Balance as money (the owner's report, 18 November 2026). The capture has
    /// the team and search grids at the same column count, so this also shows the grid is still told apart without it.
    @Test func balanceWithoutACurrencySymbolImportsTheSamePlayers() throws {
        let balance = try column("PhysicalAttributes.Balance")
        let plain = try importU21 { rows in
            rows.map { row in
                var row = row
                row[balance] = row[balance].replacingOccurrences(of: "£", with: "")
                return row
            }
        }
        let captured = try importU21()
        #expect(try Fixtures.text("captures/u21.tsv").contains("\"£6\""))   // the capture does carry the symbol
        #expect(plain.grid == captured.grid && plain.players == captured.players)
        #expect(plain.warnings == captured.warnings && plain.money == captured.money)
    }

    @Test func importsTheSamePlayersFromTheTeamGrid() throws {
        let r = try Importer.importPlayers(clipboard: Fixtures.text("captures/u21-team-grid.tsv"),
                                           fmrteConfig: Fixtures.data("captures/u21-team-grid.grids.json"), squad: .u21)
        #expect(r.grid == "TeamPlayersColumns" && r.players.count == 6)
        let daniel = try #require(r.players.first { $0.name == "Brayden Daniel" })
        #expect(daniel.condition == 0.8167 && daniel.sharpness == 0.725 && daniel.jadedness == -122)
        #expect(daniel.club == nil && daniel.askingPrice == nil)
        #expect(daniel.extras["Contract.AgreedPlayingTime"] == "Breakthrough Prospect")
        #expect(daniel.extras["Number"] == "23")
        #expect(daniel.attributes.count == 62 && daniel.familiarity.count == 14)
        #expect(try #require(r.players.first { $0.name == "Max Treml" }).loanedTo == "Wallingford")
    }

    @Test func loanedOutPlayerKeepsHisLoanClub() throws {
        let treml = try #require(u21().first { $0.name == "Max Treml" })
        #expect(treml.loanedTo == "Wallingford" && treml.jadedness == 0 && treml.condition == 0.978)
    }

    @Test func outOfContractPlayerIsFlaggedAndHasNoMonthsLeft() throws {
        let r = try importU21()
        let ulas = try #require(r.players.first { $0.name == "Aydin Ulas" })
        #expect(ulas.contractType == .outOfContract && ulas.monthsLeft == nil && ulas.wagePerWeek == 0)
        #expect(r.warnings.contains(.outOfContract("Aydin Ulas")))
    }

    @Test func aPlayerWithContractTimeLeftIsNotFlagged() throws {
        let r = try importU21()
        let daniel = try #require(r.players.first { $0.name == "Brayden Daniel" })
        #expect(daniel.contractType == .fullTime && daniel.monthsLeft == 10)
        #expect(!r.warnings.contains(.outOfContract("Brayden Daniel")))
    }

    @Test func severalNationalitiesAreSplit() throws {
        #expect(try #require(u21().first { $0.name.hasPrefix("Kauan") }).nationalities == ["Brazil", "England"])
    }

    @Test func namesAreNormalisedForIdentity() {
        #expect(PlayerID.normalise("  José   MARTÍNEZ ") == "jose martinez")
    }

    @Test func playersWithDistinctNamesKeepPlainKeys() throws {
        let r = try importU21()
        #expect(r.players.contains { $0.id.key == "brayden daniel" })
        #expect(!r.warnings.contains(.duplicateName("Brayden Daniel")))
    }

    // MARK: - Players who share a name in one paste

    /// Brayden Daniel's row (PA 70, England, age 20) followed by copies with the given changes,
    /// appended after the rest of the paste.
    private func brayden(copies changes: [(pa: String?, nationality: String?, age: String?)]) throws -> ImportResult {
        let pa = try column("PA"), nationality = try column("Nationalities"), age = try column("Age")
        return try importU21 { rows in
            rows + changes.map { change in
                var copy = rows[0]
                if let value = change.pa { copy[pa] = quoted(value) }
                if let value = change.nationality { copy[nationality] = quoted(value) }
                if let value = change.age { copy[age] = quoted(value) }
                return copy
            }
        }
    }

    private func braydenKeys(_ r: ImportResult) -> [String] {
        r.players.filter { $0.name == "Brayden Daniel" }.map(\.id.key)
    }

    @Test func twoPlayersWithOneNameAreToldApartByPotentialAbility() throws {
        let r = try brayden(copies: [(pa: "60", nationality: nil, age: "18")])
        #expect(r.players.count == 7)
        #expect(braydenKeys(r) == ["brayden daniel#70", "brayden daniel#60"])
        #expect(r.warnings == [.identifiedByName, .outOfContract("Aydin Ulas"), .duplicateName("Brayden Daniel")])
    }

    @Test func aDuplicatePairKeepsItsKeysWhenTheRowsSwapAndBothAgesRise() throws {
        let pa = try column("PA"), age = try column("Age")
        func pair(swapped: Bool, ageOffset: Int) throws -> [Int: String] {
            let r = try importU21 { rows in
                var first = rows[0], second = rows[0]
                first[age] = quoted("\(20 + ageOffset)")
                second[age] = quoted("\(18 + ageOffset)")
                second[pa] = quoted("60")
                let pair = swapped ? [second, first] : [first, second]
                return pair + rows.dropFirst()
            }
            let daniels = r.players.filter { $0.name == "Brayden Daniel" }
            #expect(daniels.count == 2)
            return Dictionary(uniqueKeysWithValues: daniels.map { ($0.potentialAbility, $0.id.key) })
        }
        let baseline = try pair(swapped: false, ageOffset: 0)
        #expect(baseline == [70: "brayden daniel#70", 60: "brayden daniel#60"])
        #expect(try pair(swapped: true, ageOffset: 0) == baseline)
        #expect(try pair(swapped: false, ageOffset: 1) == baseline)
        #expect(try pair(swapped: true, ageOffset: 1) == baseline)
    }

    @Test func equalPotentialIsToldApartByFirstNationality() throws {
        let r = try brayden(copies: [(pa: nil, nationality: "Wales,England", age: nil)])
        #expect(braydenKeys(r) == ["brayden daniel#70#england", "brayden daniel#70#wales"])
        #expect(r.warnings == [.identifiedByName, .outOfContract("Aydin Ulas"), .duplicateName("Brayden Daniel")])
    }

    @Test func playersWhoShareNamePotentialAndNationalityAreNumberedAndWarnedAbout() throws {
        let r = try brayden(copies: [(pa: nil, nationality: nil, age: "18"), (pa: nil, nationality: nil, age: "25")])
        #expect(braydenKeys(r) == ["brayden daniel#70#england#1", "brayden daniel#70#england#2", "brayden daniel#70#england#3"])
        #expect(r.warnings == [.identifiedByName, .outOfContract("Aydin Ulas"), .duplicateName("Brayden Daniel"), .indistinguishable("Brayden Daniel")])
    }

    @Test func onlyTheStillCollidingRowsAreNumbered() throws {
        // Three at PA 70: two English, one Welsh. Only the two English are numbered, in paste order.
        let r = try brayden(copies: [(pa: nil, nationality: "Wales", age: nil), (pa: nil, nationality: nil, age: "18")])
        #expect(braydenKeys(r) == ["brayden daniel#70#england#1", "brayden daniel#70#wales", "brayden daniel#70#england#2"])
        #expect(r.warnings.contains(.indistinguishable("Brayden Daniel")))
    }

    // MARK: - FMRTE's Id column

    @Test func playersFromAGridWithIdsAreKeyedById() throws {
        let r = try importFirstTeamWithIDs()
        #expect(r.grid == "TeamPlayersColumns")
        #expect(r.players.count == 18)
        let potter = try #require(r.players.first { $0.name == "Alfie Potter" })
        #expect(potter.id == PlayerID.fmrte(146837))
        #expect(potter.id.key == "fmrte:146837" && potter.id.fmrteID == 146837)
        #expect(r.players.allSatisfy { $0.id.key.hasPrefix("fmrte:") && $0.id.fmrteID != nil })
        #expect(Set(r.players.map(\.id)).count == 18)
        #expect(!r.warnings.contains(where: isNameWarning))
        // The id is identity, not an unmodelled column.
        #expect(potter.extras["Id"] == nil)
    }

    @Test func aNameKeyHasNoFMRTEID() {
        #expect(PlayerID(key: "alfie potter").fmrteID == nil)
        #expect(PlayerID(key: "fmrte:").fmrteID == nil)
        #expect(PlayerID.fmrte(2000482787).fmrteID == 2000482787)
    }

    @Test func twoNamesakesWithDifferentIdsNeedNoNameHandling() throws {
        let id = try teamColumn("Id"), pa = try teamColumn("PA")
        let r = try importFirstTeamWithIDs { rows in
            var copy = rows[0]
            copy[id] = quoted("999999")
            copy[pa] = quoted("100")      // the same potential ability too: by name they could not be told apart
            return rows + [copy]
        }
        #expect(r.players.count == 19)
        let potters = r.players.filter { $0.name == "Alfie Potter" }
        #expect(potters.map(\.id.key) == ["fmrte:146837", "fmrte:999999"])
        #expect(!r.warnings.contains(where: isNameWarning))
    }

    @Test func twoRowsWithOneIdStopTheImport() throws {
        let id = try teamColumn("Id")
        #expect(throws: ImportError.duplicateID(id: "146837", players: ["Alfie Potter", "Jonny Maxted"])) {
            try importFirstTeamWithIDs { rows in
                var rows = rows
                rows[2][id] = quoted("146837")    // Jonny Maxted, third row, given Alfie Potter's id
                return rows
            }
        }
    }

    @Test(arguments: ["", "abc", "0"])
    func aBlankIdNamesThePlayer(value: String) throws {
        let id = try teamColumn("Id")
        #expect(throws: ImportError.invalidValue(player: "Jonny Maxted", column: "Id", value: value)) {
            try importFirstTeamWithIDs { rows in
                var rows = rows
                rows[2][id] = quoted(value)
                return rows
            }
        }
    }

    @Test func aGridWithoutIdsWarnsThatIdentityIsByName() throws {
        let r = try importU21()
        #expect(r.warnings.filter { $0 == .identifiedByName }.count == 1)
        #expect(r.warnings == [.identifiedByName, .outOfContract("Aydin Ulas")])
        #expect(r.players.map(\.id.key) == ["brayden daniel", "max treml", "tyrae njogu", "caleb moir", "aydin ulas",
                                            "kauan bitencourt de oliveira"])
        #expect(r.players.allSatisfy { $0.id.fmrteID == nil })
    }

    @Test func theU21CaptureWithIdsMatchesTheEarlierCapturesPlayers() throws {
        let r = try Importer.importPlayers(clipboard: Fixtures.text("captures/u21-with-id.tsv"),
                                           fmrteConfig: Fixtures.data("captures/u21-with-id.grids.json"), squad: .u21)
        #expect(r.grid == "TeamPlayersColumns")
        #expect(Set(r.players.map(\.name)) == Set(try u21().map(\.name)))
        #expect(r.players.count == 6)
        #expect(r.players.allSatisfy { $0.id.key.hasPrefix("fmrte:") })
        let treml = try #require(r.players.first { $0.name == "Max Treml" })
        #expect(treml.id == PlayerID(key: "fmrte:2000482787") && treml.loanedTo == "Wallingford")
        #expect(!r.warnings.contains(.identifiedByName))
    }

    @Test func injuredAndBannedEachLandInTheirOwnField() throws {
        let injured = try column("IsInjured"), banned = try column("IsBanned")
        let r = try importU21 { rows in
            var rows = rows
            rows[0][injured] = quoted("True"); rows[0][banned] = quoted("False")
            rows[1][injured] = quoted("False"); rows[1][banned] = quoted("True")
            return rows
        }
        let daniel = try #require(r.players.first { $0.name == "Brayden Daniel" })
        #expect(daniel.isInjured && !daniel.isBanned)
        let treml = try #require(r.players.first { $0.name == "Max Treml" })
        #expect(!treml.isInjured && treml.isBanned)
    }

    @Test func aBlankClubCellGivesNoClub() throws {
        let club = try column("Contract.Club")
        let r = try importU21 { rows in
            var rows = rows
            rows[0][club] = quoted("")
            rows[1][club] = quoted("  ")
            return rows
        }
        #expect(r.players.first { $0.name == "Brayden Daniel" }?.club == nil)
        #expect(r.players.first { $0.name == "Max Treml" }?.club == nil)
        #expect(r.players.first { $0.name == "Tyrae Njogu" }?.club == "Oxford City")
    }

    @Test(arguments: [("£1,234.50", 1235), ("£1.234", 1234), ("£1,234", 1234), ("£1,234.49", 1234)])
    func aWageWithPenceIsRoundedToTheNearestPound(cell: String, pounds: Int) throws {
        let wage = try column("Contract.WagePerWeek"), price = try column("AskingPrice")
        let r = try importU21 { rows in
            var rows = rows
            rows[0][wage] = quoted(cell)
            rows[0][price] = quoted(cell)
            return rows
        }
        let daniel = try #require(r.players.first { $0.name == "Brayden Daniel" })
        #expect(daniel.wagePerWeek == Double(pounds) && daniel.askingPrice == pounds)
    }

    @Test func aMonthlyWageIsKeptPerWeekAndTheStyleIsTheOnePasted() throws {
        let r = try importU21(wages: "Monthly", symbol: "$", firstWage: "$3,497")
        let daniel = try #require(r.players.first { $0.name == "Brayden Daniel" })
        #expect(daniel.wagePerWeek == 807)      // 3,497 × 12 ÷ 52
        #expect(r.money == MoneyStyle(symbol: "$", period: .monthly))
        // A monthly wage that is not a whole number of a week is kept as it is, not rounded.
        let other = try importU21(wages: "Monthly", symbol: "$", firstWage: "$3,500")
        #expect(try #require(other.players.first { $0.name == "Brayden Daniel" }).wagePerWeek == 3_500.0 * 12 / 52)
    }

    @Test func aYearlyWageIsKeptPerWeek() throws {
        let r = try importU21(wages: "Yearly", symbol: "$", firstWage: "$41,964")
        #expect(try #require(r.players.first { $0.name == "Brayden Daniel" }).wagePerWeek == 807)      // 41,964 ÷ 52
        #expect(r.money == MoneyStyle(symbol: "$", period: .yearly))
    }

    @Test func aWeeklyWageIsKeptAsPasted() throws {
        let r = try importU21(wages: "Weekly", symbol: "£", firstWage: "£600")
        #expect(try #require(r.players.first { $0.name == "Brayden Daniel" }).wagePerWeek == 600)
        #expect(r.money == .weeklyPounds)
    }

    @Test func theCapturesAsTheyStandAreWeeklyPounds() throws {
        #expect(try importU21().money == .weeklyPounds)
        let first = try Importer.importPlayers(clipboard: Fixtures.text("captures/first-team.tsv"),
                                               fmrteConfig: Fixtures.data("captures/first-team.grids.json"), squad: .firstTeam)
        #expect(first.money == .weeklyPounds)
        #expect(try #require(first.players.first { $0.name == "Jonny Maxted" }).wagePerWeek == 600)
    }

    @Test func aWageInAnotherCurrencyStopsTheImportAndNamesThePlayer() throws {
        let wage = try column("Contract.WagePerWeek")
        #expect(throws: ImportError.mixedCurrency(player: "Max Treml", symbol: "€", expected: "$")) {
            try importU21(settings: Fixtures.settings("u21", wages: "Monthly")) { rows in
                var rows = rows.map { row in
                    var row = row
                    row[wage] = row[wage].replacingOccurrences(of: "£", with: "$")
                    return row
                }
                rows[1][wage] = quoted("€3,497")
                return rows
            }
        }
    }

    @Test func anUnknownWagePeriodStopsTheImport() throws {
        #expect(throws: ImportError.unknownWagePeriod(found: "Fortnightly")) {
            try importU21(settings: Fixtures.settings("u21", wages: "Fortnightly")) { $0 }
        }
    }

    @Test func aWageWithMoreThanTwoDecimalPlacesStopsTheImport() throws {
        let wage = try column("Contract.WagePerWeek")
        #expect(throws: ImportError.invalidValue(player: "Brayden Daniel", column: "Contract.WagePerWeek", value: "£1.2345")) {
            try importU21 { rows in
                var rows = rows
                rows[0][wage] = quoted("£1.2345")
                return rows
            }
        }
    }

    @Test func jadednessBeyondAThousandImports() throws {
        let jadedness = try column("Jadedness")
        let r = try importU21 { rows in
            var rows = rows
            rows[0][jadedness] = quoted("2500")
            rows[1][jadedness] = quoted("-1500")
            return rows
        }
        #expect(r.players.first { $0.name == "Brayden Daniel" }?.jadedness == 2500)
        #expect(r.players.first { $0.name == "Max Treml" }?.jadedness == -1500)
    }

    @Test func blankConditionStopsTheImportAndNamesThePlayer() throws {
        let condition = try column("Condition")
        #expect(throws: ImportError.invalidValue(player: "Brayden Daniel", column: "Condition", value: "")) {
            try importU21 { rows in
                var rows = rows
                rows[0][condition] = quoted("")
                return rows
            }
        }
    }

    @Test(arguments: ["", "  "])
    func blankPositionsTextNamesThePlayerAndColumn(blank: String) throws {
        let positions = try column("Positions.PositionsDesc")
        #expect(throws: ImportError.invalidValue(player: "Brayden Daniel", column: "Positions.PositionsDesc", value: blank)) {
            try importU21 { rows in
                var rows = rows
                rows[0][positions] = quoted(blank)
                return rows
            }
        }
    }

    @Test(arguments: ["", "  "])
    func blankContractTypeNamesThePlayerAndColumn(blank: String) throws {
        let contract = try column("Contract.ContractType")
        #expect(throws: ImportError.invalidValue(player: "Brayden Daniel", column: "Contract.ContractType", value: blank)) {
            try importU21 { rows in
                var rows = rows
                rows[0][contract] = quoted(blank)
                return rows
            }
        }
    }

    @Test func aYouthContractIsReadAsYouthAndAnUnknownWordIsKeptAsPasted() throws {
        let contract = try column("Contract.ContractType")
        let youth = try importU21 { rows in
            var rows = rows
            rows[0][contract] = quoted("Youth")
            return rows
        }
        #expect(try #require(youth.players.first { $0.name == "Brayden Daniel" }).contractType == .youth)
        let amateur = try importU21 { rows in
            var rows = rows
            rows[0][contract] = quoted("Amateur")
            return rows
        }
        #expect(try #require(amateur.players.first { $0.name == "Brayden Daniel" }).contractType == .other("Amateur"))
    }

    @Test(arguments: ["", "  "])
    func blankNameIsRejectedAndNamedByRow(blank: String) throws {
        let name = try column("DisplayedName")
        #expect(throws: ImportError.invalidValue(player: "row 1", column: "DisplayedName", value: blank)) {
            try importU21 { rows in
                var rows = rows
                rows[0][name] = quoted(blank)
                return rows
            }
        }
    }

    @Test func aNonNumericAttributeNamesThePlayerAndColumn() throws {
        let pace = try column("PhysicalAttributes.Pace")
        #expect(throws: ImportError.invalidValue(player: "Brayden Daniel", column: "PhysicalAttributes.Pace", value: "n/a")) {
            try importU21 { rows in
                var rows = rows
                rows[0][pace] = quoted("n/a")
                return rows
            }
        }
    }

    @Test func aPasteFromAnUnknownLayoutIsNotBlamedOnOneCell() throws {
        do {
            _ = try importU21 { $0.map { Array($0.reversed()) } }
            Issue.record("expected an error")
        } catch let error as ImportError {
            guard case .noGridFits(_, let violations) = error else {
                Issue.record("expected noGridFits, got \(error)")
                return
            }
            #expect(violations.values.allSatisfy { $0 > 6 })
        }
    }

    @Test func percentageScaleConditionIsRejected() throws {
        let condition = try column("Condition")
        #expect(throws: ImportError.unexpectedScale(column: "Condition")) {
            try importU21 { rows in
                rows.map { row in
                    var row = row
                    let value = Int(row[condition].replacingOccurrences(of: "\"", with: ""))! / 100
                    row[condition] = quoted("\(value)")
                    return row
                }
            }
        }
    }

    @Test func percentageScaleSharpnessIsRejected() throws {
        let sharpness = try column("MatchSharpness")
        #expect(throws: ImportError.unexpectedScale(column: "MatchSharpness")) {
            try importU21 { rows in
                rows.map { row in
                    var row = row
                    row[sharpness] = quoted("\(Int(row[sharpness].replacingOccurrences(of: "\"", with: ""))! / 100)")
                    return row
                }
            }
        }
    }

    @Test func oneLowConditionAmongNormalOnesIsNotAScaleError() throws {
        let condition = try column("Condition")
        let r = try importU21 { rows in
            var rows = rows
            rows[0][condition] = quoted("50")
            return rows
        }
        #expect(r.players.first { $0.name == "Brayden Daniel" }?.condition == 0.005)
    }

    @Test func aPlayerRoundTripsThroughJSONWithNamedKeys() throws {
        let player = try #require(u21().first)
        let data = try JSONEncoder().encode(player)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"attributes\":{"))
        #expect(json.contains("\"Pace\""))
        #expect(json.contains("\"familiarity\":{"))
        #expect(try JSONDecoder().decode(Player.self, from: data) == player)
    }

    @Test func theTestFixtureFillsEveryAttributeAndPosition() {
        let p = Player.fixture(all: 12, attributes: [.pace: 18], familiarity: [.striker: 20])
        #expect(p.attributes.count == 62 && p.attributes[.pace] == 18 && p.attributes[.vision] == 12)
        #expect(p.familiarity.count == 14 && p.familiarity[.striker] == 20 && p.familiarity[.goalkeeper] == 1)
        #expect(p.id.key == "test player" && p.club == "Oxford City")
    }

    // A player with no contract: FMRTE leaves his contract type, months left and wage blank together.

    @Test func aPlayerWithNoContractIsReadAsOutOfContractWithNoWage() throws {
        let r = try importU21(withNoContractAt: [0])
        let daniel = try #require(r.players.first { $0.name == "Brayden Daniel" })
        #expect(daniel.contractType == .outOfContract && daniel.monthsLeft == nil && daniel.wagePerWeek == 0)
        #expect(daniel.club == nil)
        #expect(r.warnings.contains(.outOfContract("Brayden Daniel")))
        // The other rows are read as before, and the currency comes from the first row that has a wage.
        #expect(r.players.count == 6 && r.money == .weeklyPounds)
        #expect(try #require(r.players.first { $0.name == "Max Treml" }).contractType == .fullTime)
    }

    @Test func aPlayerWithNoContractKeepsAClubThePasteGivesHim() throws {
        let r = try importU21(withNoContractAt: [0], alsoClub: false)
        let daniel = try #require(r.players.first { $0.name == "Brayden Daniel" })
        #expect(daniel.contractType == .outOfContract && daniel.club == "Oxford City")
    }

    /// One blank contract cell beside filled ones is a fault in the paste, not a player with no contract.
    @Test(arguments: ["Contract.ContractType", "Contract.MonthsLeft", "Contract.WagePerWeek"])
    func oneBlankContractCellAloneStopsTheImportAndNamesTheColumn(path: String) throws {
        let cell = try column(path)
        #expect(throws: ImportError.invalidValue(player: "Brayden Daniel", column: path, value: "")) {
            try importU21 { rows in
                var rows = rows
                rows[0][cell] = quoted("")
                return rows
            }
        }
    }

    @Test func twoBlankContractCellsStopTheImportAndNameTheFirstBlank() throws {
        let cells = try ["Contract.ContractType", "Contract.MonthsLeft"].map(column)
        #expect(throws: ImportError.invalidValue(player: "Brayden Daniel", column: "Contract.ContractType", value: "")) {
            try importU21 { rows in
                var rows = rows
                for cell in cells { rows[0][cell] = quoted("") }
                return rows
            }
        }
    }

    @Test func aPasteOfOnlyPlayersWithNoContractTakesItsCurrencyFromTheAskingPrice() throws {
        let r = try importU21(withNoContractAt: nil)
        #expect(r.players.count == 6 && r.players.allSatisfy { $0.contractType == .outOfContract && $0.wagePerWeek == 0 })
        #expect(r.money == .weeklyPounds)
    }

    /// The team grid has no asking price, so with no wage on any row nothing says what the currency is.
    @Test func withNoWageAndNoAskingPriceTheCurrencyCannotBeTold() throws {
        let cells = try contractPaths.map(teamColumn)
        #expect(throws: ImportError.invalidValue(player: "Alfie Potter", column: "Contract.WagePerWeek", value: "")) {
            try importFirstTeamWithIDs { rows in
                rows.map { row in
                    var row = row
                    for cell in cells { row[cell] = quoted("") }
                    return row
                }
            }
        }
    }

    @Test func aWageInAnotherCurrencyIsStillCaughtAfterAPlayerWithNoContract() throws {
        let wage = try column("Contract.WagePerWeek")
        let cells = try (contractPaths + ["Contract.Club"]).map(column)
        #expect(throws: ImportError.mixedCurrency(player: "Tyrae Njogu", symbol: "$", expected: "£")) {
            try importU21 { rows in
                var rows = rows
                for cell in cells { rows[0][cell] = quoted("") }
                let njogu = try! #require(rows.firstIndex { $0.contains(quoted("Tyrae Njogu")) })
                rows[njogu][wage] = rows[njogu][wage].replacingOccurrences(of: "£", with: "$")
                return rows
            }
        }
    }

    @Test func importsTheRealSearchResult() throws {
        let r = try importSearch()
        #expect(r.grid == "SearchPlayersColumns" && r.players.count == 109)
        #expect(r.money == MoneyStyle(symbol: "$", period: .monthly))
        // The fifteen with no club have no contract; four more are out of contract at a club (FMRTE's "4").
        let noClub = r.players.filter { $0.club == nil }
        #expect(noClub.count == 15)
        #expect(noClub.allSatisfy { $0.contractType == .outOfContract && $0.monthsLeft == nil && $0.wagePerWeek == 0 })
        #expect(r.players.filter { $0.contractType == .outOfContract }.count == 19)
        #expect(r.players.filter { $0.contractType == .other("PartTime") }.count == 41)
        #expect(r.players.filter { $0.contractType == .other("Amateur") }.count == 41)
        #expect(r.players.filter { $0.contractType == .fullTime }.count == 8)
        // An amateur's months left are FMRTE's -1527, read as none; his wage is $0.
        let kerrigan = try #require(r.players.first { $0.name == "Sean Kerrigan" })
        #expect(kerrigan.monthsLeft == nil && kerrigan.wagePerWeek == 0 && kerrigan.club == "Portstewart" && kerrigan.isBanned)
        // $2,040 a month is kept per week.
        let wilson = try #require(r.players.first { $0.name == "George Wilson" })
        #expect(abs(wilson.wagePerWeek - 2040.0 * 12 / 52) < 0.01 && wilson.monthsLeft == 2)
        #expect(r.players.filter { $0.loanedTo != nil }.map(\.name).sorted()
                == ["Ben Woollam", "Destiny Oladipo", "Dylan Graham", "Morgan Owen"])
        #expect(r.players.filter(\.isInjured).count == 2)
        let first = try #require(r.players.first)
        #expect(first.name == "Tobi Adebayo-Rowling" && first.askingPrice == 0 && first.positionsText == "D/WB/M R")
    }
}

// MARK: - The day a contract ends (the owner's team grid of 23 November 2026, with FMRTE's expiry-date column)

private let expiryPath = "Contract.ContractExpiryDate"

/// The first-team paste taken with the expiry-date column, FMRTE set to dollars a month, with `change` applied to
/// its rows.
private func importFirstTeamWithExpiry(changingRows change: ([[String]]) -> [[String]] = { $0 }) throws -> ImportResult {
    let rows = try Fixtures.text("captures/first-team-with-expiry.tsv")
        .components(separatedBy: "\r\n").filter { !$0.isEmpty }
        .map { $0.components(separatedBy: "\t") }
    let text = change(rows).map { $0.joined(separator: "\t") }.joined(separator: "\r\n") + "\r\n"
    return try Importer.importPlayers(clipboard: text,
                                      fmrteConfig: Fixtures.settings("first-team-with-expiry", wages: "Monthly"),
                                      squad: .firstTeam)
}

private func expiryColumn(_ path: String) throws -> Int {
    try #require(Fixtures.gridColumns("first-team-with-expiry", grid: "TeamPlayersColumns").firstIndex(of: path))
}

/// The paste with the cells at `paths` of Caelan Avenell's row made `value`.
private func importWithAvenell(_ paths: [String], as value: String) throws -> ImportResult {
    let name = try expiryColumn("DisplayedName")
    let cells = try paths.map(expiryColumn)
    return try importFirstTeamWithExpiry { rows in
        rows.map { row in
            guard row[name] == quoted("Caelan Avenell") else { return row }
            var row = row
            for cell in cells { row[cell] = quoted(value) }
            return row
        }
    }
}

@Test func theExpiryDateColumnIsReadAsTheDayTheContractEnds() throws {
    let players = try importFirstTeamWithExpiry().players
    #expect(players.count == 30)
    let avenell = try #require(players.first { $0.name == "Caelan Avenell" })
    #expect(avenell.contractEnds == Day(iso: "2030-06-30"))
    let waddell = try #require(players.first { $0.name == "Hudson Waddell" })
    #expect(waddell.contractEnds == Day(iso: "2030-05-31"))
    #expect(players.allSatisfy { $0.contractEnds != nil })
    #expect(players.allSatisfy { $0.extras[expiryPath] == nil })
}

@Test func aGridWithoutTheExpiryDateColumnGivesNoDay() throws {
    #expect(try importFirstTeamWithIDs().players.allSatisfy { $0.contractEnds == nil })
}

@Test(arguments: ["", " ", "30/6/2030", "2/30/2030", "6/30", "6/30/2030/1", "June 2030", "6/30/30a", "0/1/2030", "6/30/30"])
func anExpiryDateThatIsNotAMonthDayAndYearIsRefused(cell: String) throws {
    #expect(throws: ImportError.invalidValue(player: "Caelan Avenell", column: expiryPath, value: cell)) {
        try importWithAvenell([expiryPath], as: cell)
    }
}

@Test func aPlayerWithNoContractHasNoDayWhateverTheCellHolds() throws {
    let players = try importWithAvenell(contractPaths, as: "").players
    let avenell = try #require(players.first { $0.name == "Caelan Avenell" })
    #expect(avenell.contractType == .outOfContract)
    #expect(avenell.contractEnds == nil)
}

@Test func aPlayerSavedBeforeTheDayWasReadStillOpens() throws {
    let avenell = try #require(try importFirstTeamWithExpiry().players.first { $0.name == "Caelan Avenell" })
    var object = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(avenell)) as? [String: Any])
    #expect(object.removeValue(forKey: "contractEnds") != nil)
    let old = try JSONDecoder().decode(Player.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(old.contractEnds == nil)
    #expect(old.monthsLeft == avenell.monthsLeft)
}

/// The paste with Caelan Avenell's contract type, months left, wage and expiry-date cells made the four given.
private func importWithAvenell(type: String, months: String, wage: String, expiry: String) throws -> Player {
    let name = try expiryColumn("DisplayedName")
    let cells = try zip(contractPaths + [expiryPath], [type, months, wage, expiry]).map { (try expiryColumn($0), $1) }
    let players = try importFirstTeamWithExpiry { rows in
        rows.map { row in
            guard row[name] == quoted("Caelan Avenell") else { return row }
            var row = row
            for (cell, value) in cells { row[cell] = quoted(value) }
            return row
        }
    }.players
    return try #require(players.first { $0.name == "Caelan Avenell" })
}

/// FMRTE pastes a player whose contract has run out, and one on a kind of contract with no end (an amateur), with a
/// contract type, a wage and months left below zero (the search capture has "Amateur", "-1527", "$0" and "4", "-1527",
/// "$0"). What it writes for his expiry date is not known, so the cell is not read: blank or a date, he has no day.
@Test(arguments: [("Amateur", "-1527", ""), ("Amateur", "-1527", "1/1/1900"), ("4", "-1527", ""), ("4", "-1", "12/31/1899"),
                  ("FullTime", "-1", ""), ("FullTime", "-2", "not a date")])
func aPlayerWhoseMonthsLeftAreBelowZeroHasNoDayAndHisCellIsNotRead(type: String, months: String, expiry: String) throws {
    let player = try importWithAvenell(type: type, months: months, wage: "$0", expiry: expiry)
    #expect(player.monthsLeft == nil)
    #expect(player.contractEnds == nil)
}

@Test func aPlayerWithMonthsLeftStillNeedsHisDay() throws {
    #expect(throws: ImportError.invalidValue(player: "Caelan Avenell", column: expiryPath, value: "")) {
        try importWithAvenell(type: "FullTime", months: "0", wage: "$5,735", expiry: "")
    }
    #expect(try importWithAvenell(type: "FullTime", months: "0", wage: "$5,735", expiry: "3/1/2028").contractEnds
            == Day(iso: "2028-03-01"))
}
