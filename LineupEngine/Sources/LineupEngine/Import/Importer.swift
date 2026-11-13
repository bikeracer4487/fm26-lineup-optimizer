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
