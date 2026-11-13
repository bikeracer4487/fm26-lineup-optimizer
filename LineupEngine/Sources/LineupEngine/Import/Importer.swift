import Foundation

/// Everything that can stop a paste from FMRTE becoming a squad. Each case names what was
/// wrong so the caller can show it; nothing is repaired silently.
public enum ImportError: Error, Equatable {
    case configUnreadable(reason: String)
    case noPlayerGrids
    case emptyClipboard
    case notAnFMRTEGrid(reason: String)
    case raggedRows(expected: Int, row: Int, found: Int)
    case noGridFits(fieldCount: Int, violationsByGrid: [String: Int])
    case ambiguousGrid(keys: [String])
    case missingColumns(grid: String, columns: [String])
    case invalidValue(player: String, column: String, value: String)
    case unexpectedScale(column: String)
}

public enum ImportWarning: Equatable, Sendable {
    case duplicateName(String)
    case outOfContract(String)
}

public struct ImportResult: Equatable, Sendable {
    public let grid: String
    public let players: [Player]
    public let warnings: [ImportWarning]

    public init(grid: String, players: [Player], warnings: [ImportWarning]) {
        self.grid = grid
        self.players = players
        self.warnings = warnings
    }
}

/// Turns FMRTE clipboard text into players.
public enum Importer {
    /// FMRTE's `Condition` and `MatchSharpness` run from 0 to 10,000. A whole paste at or below
    /// this value was exported as percentages, which this importer does not understand.
    static let percentageScaleCeiling = 100
    /// Divisor from FMRTE's 0 to 10,000 scale to a fraction of 1.
    static let fmrteScale = 10_000.0

    /// Columns the importer reads into a typed field; every other column goes into `extras`.
    private static let modelledColumns: Set<String> = Set(GridDetector.requiredColumns)
        .union(["Contract.Club", "AskingPrice", "Nationalities"])

    /// Text columns that must hold something other than whitespace. The grid detector accepts
    /// any text here, so the importer checks them.
    private static let nonBlankColumns: Set<String> = ["DisplayedName", "Positions.PositionsDesc", "Contract.ContractType"]

    public static func importPlayers(clipboard: String, fmrteConfig: Data, squad: Squad) throws -> ImportResult {
        let rows = try ClipboardText.rows(clipboard)
        let grids = try FMRTEConfig.playerGrids(from: fmrteConfig)
        guard !grids.isEmpty else { throw ImportError.noPlayerGrids }

        let layout = try chooseLayout(rows: rows, grids: grids)
        return try parse(rows: rows, layout: layout, squad: squad)
    }

    /// The detected grid; or, when none fits, the single closest grid if the misfit is small
    /// enough to be a few bad cells, so the caller hears about the first bad cell by name.
    private static func chooseLayout(rows: [[String]], grids: [GridLayout]) throws -> GridLayout {
        do {
            return try GridDetector.detect(rows: rows, grids: grids)
        } catch let error as ImportError {
            guard case .noGridFits = error else { throw error }
            let counts = grids.filter { $0.columns.count == rows[0].count }
                .map { (layout: $0, count: GridDetector.violations(rows: rows, layout: $0)) }
            guard let fewest = counts.map(\.count).min(),
                  fewest <= rows.count,
                  counts.filter({ $0.count == fewest }).count == 1,
                  let closest = counts.first(where: { $0.count == fewest })?.layout
            else { throw error }
            try GridDetector.requireColumns(in: closest)
            return closest
        }
    }

    private static func parse(rows: [[String]], layout: GridLayout, squad: Squad) throws -> ImportResult {
        let index = Dictionary(layout.columns.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        var players: [Player] = []
        var warnings: [ImportWarning] = []
        var rawCondition: [Int] = []
        var rawSharpness: [Int] = []

        for (rowIndex, row) in rows.enumerated() {
            let name = row[index["DisplayedName"]!].trimmingCharacters(in: .whitespaces)
            let display = name.isEmpty ? "row \(rowIndex + 1)" : name

            func fail(_ path: String) -> ImportError {
                .invalidValue(player: display, column: path, value: row[index[path]!])
            }
            for (path, cell) in zip(layout.columns, row) where GridDetector.violates(cell, path: path)
                || (nonBlankColumns.contains(path) && cell.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                throw fail(path)
            }
            func cell(_ path: String) -> String { row[index[path]!] }
            func int(_ path: String) throws -> Int {
                guard let value = Int(cell(path)) else { throw fail(path) }
                return value
            }
            func money(_ path: String) throws -> Int {
                guard let value = Int(cell(path).filter(\.isASCII).filter(\.isNumber)) else { throw fail(path) }
                return value
            }
            func rating(_ path: String) throws -> Int {
                var digits = Substring(cell(path))
                if let first = digits.first, GridDetector.currencySymbols.contains(first) { digits = digits.dropFirst() }
                guard let value = Int(digits) else { throw fail(path) }
                return value
            }

            var attributes: [Attribute: Int] = [:]
            var familiarity: [Position: Int] = [:]
            var extras: [String: String] = [:]
            for path in layout.columns {
                if let attribute = Attribute.fromFMRTEPath(path) {
                    attributes[attribute] = try rating(path)
                } else if let position = Position.fromFMRTEPath(path) {
                    familiarity[position] = try rating(path)
                } else if !modelledColumns.contains(path) {
                    extras[path] = cell(path)
                }
            }

            let contractType: ContractType
            switch cell("Contract.ContractType") {
            case "FullTime": contractType = .fullTime
            case "4":
                contractType = .outOfContract
                warnings.append(.outOfContract(display))
            case let other: contractType = .other(other)
            }
            let months = try int("Contract.MonthsLeft")
            let loan = cell("LoanContract.LoanedToTeam").trimmingCharacters(in: .whitespaces)
            let club = index["Contract.Club"].map { row[$0].trimmingCharacters(in: .whitespaces) }
            let conditionRaw = try int("Condition")
            let sharpnessRaw = try int("MatchSharpness")
            rawCondition.append(conditionRaw)
            rawSharpness.append(sharpnessRaw)

            players.append(Player(
                id: PlayerID(key: PlayerID.normalise(name)), name: name, squad: squad,
                age: try int("Age"), positionsText: cell("Positions.PositionsDesc").trimmingCharacters(in: .whitespaces),
                currentAbility: try int("CA"), potentialAbility: try int("PA"),
                attributes: attributes, familiarity: familiarity,
                condition: Double(conditionRaw) / fmrteScale, sharpness: Double(sharpnessRaw) / fmrteScale,
                jadedness: try int("Jadedness"),
                isInjured: cell("IsInjured") == "True", isBanned: cell("IsBanned") == "True",
                club: club.flatMap { $0.isEmpty ? nil : $0 }, loanedTo: loan.isEmpty ? nil : loan,
                contractType: contractType, monthsLeft: months < 0 ? nil : months,
                wagePerWeek: try money("Contract.WagePerWeek"),
                askingPrice: index["AskingPrice"] == nil ? nil : try money("AskingPrice"),
                nationalities: index["Nationalities"].map {
                    row[$0].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                } ?? [],
                extras: extras
            ))
        }

        if rawCondition.allSatisfy({ $0 <= percentageScaleCeiling }) { throw ImportError.unexpectedScale(column: "Condition") }
        if rawSharpness.allSatisfy({ $0 <= percentageScaleCeiling }) { throw ImportError.unexpectedScale(column: "MatchSharpness") }

        warnings += disambiguateDuplicates(&players)
        return ImportResult(grid: layout.key, players: players, warnings: warnings)
    }

    /// Gives players who share a normalised name distinct keys: `<name>#<age>`, and
    /// `<name>#<age>#<row>` where age does not separate them. One warning per name.
    private static func disambiguateDuplicates(_ players: inout [Player]) -> [ImportWarning] {
        var warnings: [ImportWarning] = []
        let groups = Dictionary(grouping: players.indices, by: { players[$0].id.key })
        for key in groups.keys.sorted() {
            let members = groups[key]!
            guard members.count > 1 else { continue }
            warnings.append(.duplicateName(players[members[0]].name))
            let byAge = Dictionary(grouping: members, by: { players[$0].age })
            for i in members {
                let withAge = "\(key)#\(players[i].age)"
                players[i].id = PlayerID(key: byAge[players[i].age]!.count > 1 ? "\(withAge)#\(i + 1)" : withAge)
            }
        }
        return warnings
    }
}
