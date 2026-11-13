import Foundation

/// Decides which saved FMRTE grid a paste came from. The clipboard text has no header row, so
/// each layout with the right number of columns is tried: it fits when every cell of every row
/// has the type its column promises.
public enum GridDetector {
    // Bounds that validate FMRTE's data format. They are not tuning values.
    static let ratingRange = 1...20
    static let conditionRange = 0...10000
    /// Jadedness is a signed 16-bit field in the game.
    static let jadednessRange = -32768...32767
    static let ageRange = 14...60
    static let abilityRange = 1...200

    static let currencySymbols: Set<Character> = ["£", "$", "€"]
    /// Characters FMRTE puts between groups of digits in a money amount. A full stop is one only
    /// when three digits follow it; see `moneyValue`.
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
            try requireColumns(in: fits[0])
            return fits[0]
        default:
            throw ImportError.ambiguousGrid(keys: fits.map(\.key))
        }
    }

    /// Throws `missingColumns` unless the layout has every column in `requiredColumns`.
    static func requireColumns(in layout: GridLayout) throws {
        let present = Set(layout.columns)
        let missing = requiredColumns.filter { !present.contains($0) }
        if !missing.isEmpty { throw ImportError.missingColumns(grid: layout.key, columns: missing) }
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

    /// True when the cell does not have the type its column promises. Columns the detector knows
    /// nothing about never violate.
    static func violates(_ cell: String, path: String) -> Bool {
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
        case "Contract.WagePerWeek", "AskingPrice": return moneyValue(cell) == nil
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

    /// The amount in whole pounds (or the cell's currency), or nil when the cell is not money: a
    /// currency symbol, then digits and thousands separators. A full stop followed by exactly
    /// three digits separates thousands; a full stop followed by one or two digits at the end is a
    /// decimal point, and the amount is rounded to the nearest whole unit, a half rounding up.
    static func moneyValue(_ cell: String) -> Int? {
        guard let first = cell.first, currencySymbols.contains(first) else { return nil }
        var whole = Substring(cell.dropFirst())
        var fraction: Substring = ""
        if let point = whole.lastIndex(of: ".") {
            let after = whole[whole.index(after: point)...]
            if (1...2).contains(after.count), after.allSatisfy(\.isASCIIDigit) {
                fraction = after
                whole = whole[..<point]
            }
        }
        guard whole.contains(where: \.isASCIIDigit),
              whole.allSatisfy({ $0.isASCIIDigit || thousandsSeparators.contains($0) }) else { return nil }
        // Every full stop left must be followed by exactly three digits.
        for point in whole.indices where whole[point] == "." {
            let group = whole[whole.index(after: point)...].prefix { $0.isASCIIDigit }
            guard group.count == 3 else { return nil }
        }
        guard let units = Int(String(whole.filter(\.isASCIIDigit))) else { return nil }
        // One digit after the point is tenths: ".5" is 50 hundredths.
        let hundredths = fraction.isEmpty ? 0 : Int(fraction.count == 1 ? fraction + "0" : String(fraction))!
        return hundredths >= 50 ? units + 1 : units
    }
}

private extension Character {
    var isASCIIDigit: Bool { isASCII && isNumber }
}
