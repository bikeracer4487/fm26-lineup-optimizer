import Foundation

/// The engine's own errors, and the importer's warnings, in plain words for the manager. Every known error type is described
/// by an exhaustive switch; only a type the engine does not define falls through to a generic line.
public enum ErrorDescriptions {
    public static func describe(_ error: Error) -> String {
        switch error {
        case let e as ImportError: describe(e)
        case let e as CatalogError: describe(e)
        case let e as TacticError: describe(e)
        case let e as RatingError: describe(e)
        case let e as DecodingError: describe(e)
        case let e as DuplicatePlayerError: describe(e)
        default: "Unexpected error: \(error.localizedDescription)"
        }
    }

    public static func describe(_ error: ImportError) -> String {
        switch error {
        case .configUnreadable(let reason): "FMRTE's configuration cannot be read: \(reason)"
        case .noPlayerGrids: "FMRTE's configuration has no player grids"
        case .emptyClipboard: "The paste is empty"
        case .notAnFMRTEGrid(let reason): "The paste is not an FMRTE grid: \(reason)"
        case .raggedRows(let expected, let row, let found):
            "Row \(row) of the paste has \(found) cells where \(expected) were expected"
        case .noGridFits(let count, let violations) where violations.isEmpty:
            "No saved FMRTE grid has \(count) columns, as the paste has; FMRTE may not have saved its current layout yet"
        case .noGridFits(let count, let violations):
            "No grid fits the paste's \(count) columns (misfit cells per grid: "
                + violations.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", ") + ")"
        case .ambiguousGrid(let keys): "More than one grid fits the paste: \(keys.sorted().joined(separator: ", "))"
        case .missingColumns(let grid, let columns): "Grid \(grid) lacks the columns: \(columns.joined(separator: ", "))"
        case .invalidValue(let player, let column, let value): "\(player): the value '\(value)' in column \(column) is not valid"
        case .unexpectedScale(let column): "Column \(column) looks like percentages; FMRTE's 0 to 10000 scale is expected"
        case .duplicateID(let id, let players):
            "Two rows have the same FMRTE Id \(id): \(players.joined(separator: " and "))"
        }
    }

    /// An import warning in plain words; the caller says which squad it came from.
    public static func describe(_ warning: ImportWarning) -> String {
        switch warning {
        case .duplicateName(let name):
            "more than one player is called \(name); they were told apart by potential ability, then nationality"
        case .indistinguishable(let name):
            "players called \(name) also share potential ability and nationality, so they were told apart by their order "
                + "in the paste; re-sorting the grid in FMRTE can swap them"
        case .outOfContract(let name): "\(name) is out of contract"
        case .identifiedByName:
            "This grid has no Id column, so players are identified by name. Add the Id column in FMRTE for exact identity."
        }
    }

    public static func describe(_ error: CatalogError) -> String {
        switch error {
        case .malformed(let reason): "The role or rating data is damaged: \(reason)"
        case .unknownAttribute(let role, let name): "\(role) uses an attribute the engine does not know: \(name)"
        case .unknownRole(let name, let phase, let position):
            "\(name) is not an \(phaseName(phase)) role for \(position.rawValue)"
        }
    }

    public static func describe(_ error: TacticError) -> String {
        "The tactic cannot be used:\n" + error.problems.map { "  - " + describe($0) }.joined(separator: "\n")
    }

    public static func describe(_ problem: TacticProblem) -> String {
        switch problem {
        case .wrongSlotCount(let phase, let n): "The \(phaseName(phase)) side has \(n) slots, not 11"
        case .missingGoalkeeper(let phase): "The \(phaseName(phase)) side has no goalkeeper"
        case .unmapped(let slot): "\(slot.rawValue) has no out-of-possession slot to turn into"
        case .mappingTargetInactive(let from, let to): "\(from.rawValue) turns into \(to.rawValue), which has no out-of-possession role"
        case .duplicateMappingTarget(let slot): "More than one slot turns into \(slot.rawValue)"
        case .unknownRole(let phase, let slot, let role): "\(role) is not an \(phaseName(phase)) role for \(slot.rawValue)"
        case .goalkeeperMappedToOutfield(let slot):
            "GK turns into \(slot.rawValue) out of possession; the goalkeeper must stay in goal"
        }
    }

    public static func describe(_ error: RatingError) -> String {
        switch error {
        case .missingAttribute(let player, let attribute): "\(player) has no value for the attribute \(attribute.rawValue)"
        case .missingFamiliarity(let player, let position): "\(player) has no familiarity for the position \(position.rawValue)"
        }
    }

    public static func describe(_ error: DuplicatePlayerError) -> String {
        "Two players share the identity \(error.id.key): \(error.names.joined(separator: " and ")). "
            + "Import the squad again so each player has his own identity."
    }

    public static func describe(_ error: DecodingError) -> String {
        func path(_ codingPath: [CodingKey], adding key: CodingKey? = nil) -> String {
            let parts = (codingPath + (key.map { [$0] } ?? [])).map(\.stringValue)
            return parts.isEmpty ? "the top level" : "'" + parts.joined(separator: ".") + "'"
        }
        switch error {
        case .keyNotFound(let key, let context): return "missing the field \(path(context.codingPath, adding: key))"
        case .valueNotFound(_, let context): return "the field \(path(context.codingPath)) has no value"
        case .typeMismatch(_, let context): return "the field \(path(context.codingPath)) has the wrong kind of value: \(context.debugDescription)"
        case .dataCorrupted(let context): return "the data at \(path(context.codingPath)) is not valid: \(context.debugDescription)"
        @unknown default: return "the file could not be decoded: \(error.localizedDescription)"
        }
    }

    private static func phaseName(_ phase: Phase) -> String { phase == .inPossession ? "in-possession" : "out-of-possession" }
}
