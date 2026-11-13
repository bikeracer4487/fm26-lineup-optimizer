import Foundation

/// Splits FMRTE's clipboard text into rows of fields. The text has no header row.
public enum ClipboardText {
    /// A paste with fewer fields than this cannot be a player grid.
    static let minimumFieldCount = 20

    public static func rows(_ text: String) throws -> [[String]] {
        let lines = text
            .split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r\n" })
            .map { $0.hasSuffix("\r") ? String($0.dropLast()) : String($0) }
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard let first = lines.first else { throw ImportError.emptyClipboard }
        let expected = first.split(separator: "\t", omittingEmptySubsequences: false).count
        guard first.contains("\t") else {
            throw ImportError.notAnFMRTEGrid(reason: "first line has no tab separators")
        }
        guard expected >= minimumFieldCount else {
            throw ImportError.notAnFMRTEGrid(reason: "first line has \(expected) fields, fewer than \(minimumFieldCount)")
        }

        return try lines.enumerated().map { index, line in
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(unquote)
            guard fields.count == expected else {
                throw ImportError.raggedRows(expected: expected, row: index + 1, found: fields.count)
            }
            return fields
        }
    }

    private static func unquote(_ field: Substring) -> String {
        if field.count >= 2, field.first == "\"", field.last == "\"" {
            return String(field.dropFirst().dropLast())
        }
        return String(field)
    }
}
