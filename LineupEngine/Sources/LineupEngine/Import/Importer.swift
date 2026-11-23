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
    /// Two rows carry the same FMRTE `Id`; `players` names the earlier row's player, then the later's.
    case duplicateID(id: String, players: [String])
    /// FMRTE's settings file names a wage period this tool does not know; `found` is what it holds, as written.
    case unknownWagePeriod(found: String)
    /// The player's wage carries `symbol` where the paste's first row carries `expected`.
    case mixedCurrency(player: String, symbol: String, expected: String)
}

public enum ImportWarning: Equatable, Sendable {
    /// More than one player in the paste has this name; they were given keys by potential
    /// ability, then first nationality.
    case duplicateName(String)
    /// Players with this name also share potential ability and first nationality, so their keys
    /// end in their order in the paste, which re-sorting the grid can change.
    case indistinguishable(String)
    case outOfContract(String)
    /// The grid has no FMRTE `Id` column, so players are keyed by name. Raised once per import.
    case identifiedByName
}

public struct ImportResult: Equatable, Sendable {
    public let grid: String
    public let players: [Player]
    public let warnings: [ImportWarning]
    /// How the paste wrote money: the currency symbol on its wages and the period FMRTE shows them by.
    public let money: MoneyStyle

    public init(grid: String, players: [Player], warnings: [ImportWarning], money: MoneyStyle) {
        self.grid = grid
        self.players = players
        self.warnings = warnings
        self.money = money
    }
}

/// Turns FMRTE clipboard text into players.
public enum Importer {
    /// FMRTE's `Condition` and `MatchSharpness` run from 0 to 10,000. A whole paste at or below
    /// this value was exported as percentages, which this importer does not understand.
    static let percentageScaleCeiling = 100
    /// Divisor from FMRTE's 0 to 10,000 scale to a fraction of 1.
    static let fmrteScale = 10_000.0
    /// The wage column. FMRTE keeps this name whatever period it shows wages by.
    private static let wagePath = "Contract.WagePerWeek"

    /// The day a contract ends: optional, and in the owner's team grid from 23 November 2026. FMRTE writes it month
    /// first, "6/30/2030".
    private static let expiryPath = "Contract.ContractExpiryDate"

    /// Columns the importer reads into a typed field; every other column goes into `extras`.
    private static let modelledColumns: Set<String> = Set(GridDetector.requiredColumns)
        .union(["Contract.Club", "AskingPrice", "Nationalities", GridDetector.idPath, expiryPath])

    /// The day in an expiry-date cell: a month, a day and a four-digit year, digits only, with "/" between, that
    /// name a day that exists. Nil for anything else, a date written day first with a day over 12 among them.
    static func expiryDay(_ cell: String) -> Day? {
        let parts = cell.trimmingCharacters(in: .whitespaces).split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[2].count == 4,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }),
              let month = Int(parts[0]), let day = Int(parts[1]), let year = Int(parts[2]) else { return nil }
        return Day(year: year, month: month, day: day)
    }

    /// Text columns that must hold something other than whitespace. The grid detector accepts
    /// any text here, so the importer checks them.
    private static let nonBlankColumns: Set<String> = ["DisplayedName", "Positions.PositionsDesc", "Contract.ContractType"]

    /// The cells FMRTE leaves blank, all together, for a player with no contract (one with no club, in the search
    /// grid): his contract type, months left and wage. Blank together they are read as out of contract, with no months
    /// left and no wage; one blank beside one filled is a fault in the paste. In the order a fault is named.
    private static let contractColumns = ["Contract.ContractType", "Contract.MonthsLeft", wagePath]

    public static func importPlayers(clipboard: String, fmrteConfig: Data, squad: Squad) throws -> ImportResult {
        let rows = try ClipboardText.rows(clipboard)
        let grids = try FMRTEConfig.playerGrids(from: fmrteConfig)
        guard !grids.isEmpty else { throw ImportError.noPlayerGrids }
        let period = try FMRTEConfig.wagePeriod(from: fmrteConfig)

        let layout = try chooseLayout(rows: rows, grids: grids)
        return try parse(rows: rows, layout: layout, squad: squad, period: period)
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

    /// Every wage must carry the first row's currency symbol, and is kept per week from FMRTE's `period`.
    private static func parse(rows: [[String]], layout: GridLayout, squad: Squad, period: WagePeriod) throws -> ImportResult {
        let index = Dictionary(layout.columns.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        // With FMRTE's Id column every player is keyed by it; without, by name, which the warning says.
        let idColumn = index[GridDetector.idPath]
        var players: [Player] = []
        var warnings: [ImportWarning] = idColumn == nil ? [.identifiedByName] : []
        var rawCondition: [Int] = []
        var rawSharpness: [Int] = []
        // The name on the first row that carried each FMRTE id.
        var nameByID: [Int: String] = [:]
        // The currency symbol on the first row's wage, which every other row's must match.
        var currency: String?

        for (rowIndex, row) in rows.enumerated() {
            let name = row[index["DisplayedName"]!].trimmingCharacters(in: .whitespaces)
            let display = name.isEmpty ? "row \(rowIndex + 1)" : name

            func fail(_ path: String) -> ImportError {
                .invalidValue(player: display, column: path, value: row[index[path]!])
            }
            func cell(_ path: String) -> String { row[index[path]!] }
            let blankContractCells = contractColumns.filter { GridDetector.isBlank(cell($0)) }
            let hasNoContract = blankContractCells.count == contractColumns.count
            if let blank = blankContractCells.first, !hasNoContract { throw fail(blank) }
            for (path, cell) in zip(layout.columns, row) where GridDetector.violates(cell, path: path)
                || (nonBlankColumns.contains(path) && GridDetector.isBlank(cell)
                    && !(hasNoContract && contractColumns.contains(path))) {
                throw fail(path)
            }
            // A wage cell that fits its column starts with its currency symbol; a player with no contract has none.
            if !hasNoContract {
                let symbol = String(cell(wagePath).prefix(1))
                if let currency, symbol != currency {
                    throw ImportError.mixedCurrency(player: display, symbol: symbol, expected: currency)
                }
                currency = symbol
            }
            func int(_ path: String) throws -> Int {
                guard let value = Int(cell(path)) else { throw fail(path) }
                return value
            }
            func money(_ path: String) throws -> Int {
                guard let value = GridDetector.moneyValue(cell(path)) else { throw fail(path) }
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
            case "Youth": contractType = .youth
            case "4":
                contractType = .outOfContract
                warnings.append(.outOfContract(display))
            case _ where hasNoContract:
                contractType = .outOfContract
                warnings.append(.outOfContract(display))
            case let other: contractType = .other(other)
            }
            // FMRTE writes a negative number for a contract that has run out; a player with none has no cell at all.
            let months = hasNoContract ? -1 : try int("Contract.MonthsLeft")
            // A grid without the column gives no day; with it, every player with months left must have one. A player
            // with no contract, and one whose months left are below zero (a contract that has run out, or a kind with
            // no end, an amateur's), has no day, and his cell is not read: what FMRTE writes there is not known.
            var contractEnds: Day?
            if index[expiryPath] != nil, months >= 0 {
                guard let day = expiryDay(cell(expiryPath)) else { throw fail(expiryPath) }
                contractEnds = day
            }
            let loan = cell("LoanContract.LoanedToTeam").trimmingCharacters(in: .whitespaces)
            let club = index["Contract.Club"].map { row[$0].trimmingCharacters(in: .whitespaces) }
            let conditionRaw = try int("Condition")
            let sharpnessRaw = try int("MatchSharpness")
            rawCondition.append(conditionRaw)
            rawSharpness.append(sharpnessRaw)

            let id: PlayerID
            if let idColumn {
                guard let fmrteID = GridDetector.fmrteID(row[idColumn]) else { throw fail(GridDetector.idPath) }
                if let earlier = nameByID[fmrteID] {
                    throw ImportError.duplicateID(id: String(fmrteID), players: [earlier, display])
                }
                nameByID[fmrteID] = display
                id = .fmrte(fmrteID)
            } else {
                id = PlayerID(key: PlayerID.normalise(name))
            }

            players.append(Player(
                id: id, name: name, squad: squad,
                age: try int("Age"), positionsText: cell("Positions.PositionsDesc").trimmingCharacters(in: .whitespaces),
                currentAbility: try int("CA"), potentialAbility: try int("PA"),
                attributes: attributes, familiarity: familiarity,
                condition: Double(conditionRaw) / fmrteScale, sharpness: Double(sharpnessRaw) / fmrteScale,
                jadedness: try int("Jadedness"),
                isInjured: cell("IsInjured") == "True", isBanned: cell("IsBanned") == "True",
                club: club.flatMap { $0.isEmpty ? nil : $0 }, loanedTo: loan.isEmpty ? nil : loan,
                contractType: contractType, monthsLeft: months < 0 ? nil : months,
                wagePerWeek: hasNoContract ? 0 : period.perWeek(Double(try money(wagePath))),
                askingPrice: index["AskingPrice"] == nil ? nil : try money("AskingPrice"),
                nationalities: index["Nationalities"].map {
                    row[$0].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                } ?? [],
                extras: extras, contractEnds: contractEnds
            ))
        }

        if rawCondition.allSatisfy({ $0 <= percentageScaleCeiling }) { throw ImportError.unexpectedScale(column: "Condition") }
        if rawSharpness.allSatisfy({ $0 <= percentageScaleCeiling }) { throw ImportError.unexpectedScale(column: "MatchSharpness") }

        // FMRTE's ids already tell every player apart; only name keys need the namesake handling.
        if idColumn == nil { warnings += disambiguateDuplicates(&players) }
        // With no wage on any row (a paste of players with no contract), the asking price says what the currency is;
        // with neither, nothing does, and the first row's blank wage is named.
        let askingSymbol = index["AskingPrice"].flatMap { rows.first?[$0].first }.map(String.init)
        guard let currency = currency ?? askingSymbol else {
            let name = rows.first.map { $0[index["DisplayedName"]!].trimmingCharacters(in: .whitespaces) } ?? ""
            throw ImportError.invalidValue(player: name, column: wagePath, value: "")
        }
        return ImportResult(grid: layout.key, players: players, warnings: warnings,
                            money: MoneyStyle(symbol: currency, period: period))
    }

    /// Gives players who share a normalised name distinct keys that neither a birthday nor a
    /// re-sorted grid changes: `<name>#<potential ability>`; then, among those still alike,
    /// `#<first nationality>`; then, as a last resort, `#<position among the still-alike rows>`,
    /// which warns because the grid's order decides it. One `duplicateName` per name.
    private static func disambiguateDuplicates(_ players: inout [Player]) -> [ImportWarning] {
        var warnings: [ImportWarning] = []
        let groups = Dictionary(grouping: players.indices, by: { players[$0].id.key })
        for key in groups.keys.sorted() {
            let members = groups[key]!
            guard members.count > 1 else { continue }
            let name = players[members[0]].name
            warnings.append(.duplicateName(name))
            var keys = Dictionary(uniqueKeysWithValues: members.map { ($0, PlayerID.withPotential(key, of: players[$0])) })
            for alike in collisions(keys) {
                for i in alike { keys[i] = PlayerID.withNationality(keys[i]!, of: players[i]) }
            }
            let stillAlike = collisions(keys)
            for alike in stillAlike {
                for (position, i) in alike.enumerated() { keys[i] = "\(keys[i]!)#\(position + 1)" }
            }
            if !stillAlike.isEmpty { warnings.append(.indistinguishable(name)) }
            for i in members { players[i].id = PlayerID(key: keys[i]!) }
        }
        return warnings
    }

    /// The groups of row indices, each in paste order, that share a key.
    private static func collisions(_ keys: [Int: String]) -> [[Int]] {
        Dictionary(grouping: keys.keys.sorted(), by: { keys[$0]! }).values.filter { $0.count > 1 }
    }
}

extension PlayerID {
    /// `key#<potential ability>`: what first tells apart two players who share a name.
    static func withPotential(_ key: String, of player: Player) -> String { "\(key)#\(player.potentialAbility)" }

    /// `key#<first nationality, normalised>`; `key` unchanged when he has no nationality.
    static func withNationality(_ key: String, of player: Player) -> String {
        guard let first = player.nationalities.first.map(PlayerID.normalise), !first.isEmpty else { return key }
        return "\(key)#\(first)"
    }
}
