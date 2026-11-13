import Foundation

/// Decides which saved FMRTE grid a paste came from. The clipboard text has no header row, so
/// each layout with the right number of columns is tried: it fits when every cell of every row
/// has the type its column promises.
public enum GridDetector {
    // Bounds that validate FMRTE's data format. They are not tuning values.
    static let ratingRange = 1...20
    static let conditionRange = 0...10000
    static let jadednessRange = -1000...1000
    static let ageRange = 14...60
    static let abilityRange = 1...200

    static let currencySymbols: Set<Character> = ["£", "$", "€"]
    /// Characters FMRTE puts between groups of digits in a money amount.
    static let thousandsSeparators: Set<Character> = [",", ".", " ", "\u{00A0}", "\u{202F}"]

    /// The one attribute whose FMRTE column can carry a currency symbol in front of the rating.
    static let balancePath = "PhysicalAttributes.Balance"

    /// Columns a layout must contain before a paste can be imported. `Contract.Club` and
    /// `AskingPrice` are left out because the owner's team grid has neither.
    public static let requiredColumns: [String] = [
        "DisplayedName", "Age", "CA", "PA", "Positions.PositionsDesc",
        "IsInjured", "IsBanned", "Condition", "Jadedness", "MatchSharpness",
        "Contract.ContractType", "Contract.MonthsLeft", "Contract.WagePerWeek",
        "LoanContract.LoanedToTeam",
    ] + Attribute.allCases.map(\.fmrtePath) + Position.allCases.map(\.fmrtePath)

    /// The layout the rows came from, or the reason none could be chosen.
    public static func detect(rows: [[String]], grids: [GridLayout]) throws -> GridLayout {
        let fieldCount = rows.first?.count ?? 0
        let candidates = grids.filter { $0.columns.count == fieldCount }
        let counts = candidates.map { (layout: $0, count: violations(rows: rows, layout: $0)) }
        let fits = counts.filter { $0.count == 0 }.map(\.layout)

        switch fits.count {
        case 0:
            var byGrid: [String: Int] = [:]
            for entry in counts { byGrid[entry.layout.key] = entry.count }
            throw ImportError.noGridFits(fieldCount: fieldCount, violationsByGrid: byGrid)
        case 1:
            let present = Set(fits[0].columns)
            let missing = requiredColumns.filter { !present.contains($0) }
            if !missing.isEmpty { throw ImportError.missingColumns(grid: fits[0].key, columns: missing) }
            return fits[0]
        default:
            throw ImportError.ambiguousGrid(keys: fits.map(\.key))
        }
    }

    /// How many cells, over all rows, do not have the type their column promises.
    public static func violations(rows: [[String]], layout: GridLayout) -> Int {
        var total = 0
        for row in rows {
            for (path, cell) in zip(layout.columns, row) where violates(cell, path: path) {
                total += 1
            }
        }
        return total
    }

    private static func violates(_ cell: String, path: String) -> Bool {
        if Attribute.fromFMRTEPath(path) != nil {
            var digits = Substring(cell)
            if path == balancePath, let first = digits.first, currencySymbols.contains(first) {
                digits = digits.dropFirst()
            }
            return !isWholeNumber(digits, in: ratingRange)
        }
        if Position.fromFMRTEPath(path) != nil {
            return !isWholeNumber(cell, in: ratingRange)
        }
        switch path {
        case "IsInjured", "IsBanned": return cell != "True" && cell != "False"
        case "Condition", "MatchSharpness": return !isWholeNumber(cell, in: conditionRange)
        case "Jadedness": return !isWholeNumber(cell, in: jadednessRange)
        case "Age": return !isWholeNumber(cell, in: ageRange)
        case "CA", "PA": return !isWholeNumber(cell, in: abilityRange)
        case "Contract.WagePerWeek", "AskingPrice": return !isMoney(cell)
        case "DisplayedName": return cell.isEmpty || cell.allSatisfy(\.isASCIIDigit)
        default: return false
        }
    }

    /// An optional minus sign and ASCII digits only, with a value inside `range`.
    private static func isWholeNumber(_ text: some StringProtocol, in range: ClosedRange<Int>) -> Bool {
        let unsigned = text.hasPrefix("-") ? text.dropFirst() : text[...]
        guard !unsigned.isEmpty, unsigned.allSatisfy(\.isASCIIDigit), let value = Int(text) else { return false }
        return range.contains(value)
    }

    /// A currency symbol, then at least one digit, with only digits and thousands separators after.
    private static func isMoney(_ cell: String) -> Bool {
        guard let first = cell.first, currencySymbols.contains(first) else { return false }
        let rest = cell.dropFirst()
        return rest.contains(where: \.isASCIIDigit)
            && rest.allSatisfy { $0.isASCIIDigit || thousandsSeparators.contains($0) }
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
