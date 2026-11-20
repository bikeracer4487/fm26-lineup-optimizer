import Foundation

/// One saved FMRTE grid: its settings key and the column paths in display order.
public struct GridLayout: Sendable, Equatable {
    public let key: String
    public let columns: [String]

    public init(key: String, columns: [String]) {
        self.key = key
        self.columns = columns
    }
}

/// Reads FMRTE's saved grid configuration. The caller supplies the file's bytes.
public enum FMRTEConfig {
    /// Path of the column that holds the player's name; marks a grid as a player grid.
    static let playerNamePath = "DisplayedName"

    /// Every grid whose columns include `DisplayedName`. Grids with identical column lists
    /// are returned once, under the first key. Unknown keys in the file are ignored.
    public static func playerGrids(from data: Data) throws -> [GridLayout] {
        try grids(from: data) { $0.contains(playerNamePath) }
    }

    private static func grids(from data: Data, where keep: ([String]) -> Bool) throws -> [GridLayout] {
        let root = try object(from: data)
        guard let items = ((root as? [String: Any])?["ColumnsSettings"] as? [String: Any])?["Items"] as? [[String: Any]] else {
            throw ImportError.configUnreadable(reason: "ColumnsSettings.Items not found")
        }

        var grids: [GridLayout] = []
        for item in items {
            guard let key = item["SettingsKey"] as? String,
                  let columns = item["Columns"] as? [[String: Any]] else { continue }
            let paths = columns.compactMap { $0["Path"] as? String }
            guard keep(paths) else { continue }
            if grids.contains(where: { $0.columns == paths }) { continue }
            grids.append(GridLayout(key: key, columns: paths))
        }
        return grids
    }

    /// Paths that mark a grid as a standings grid: it has both.
    static let standingsMarkerPaths = ["TeamName", "Points"]

    /// Every grid whose columns include both `TeamName` and `Points`. Grids with identical column lists are returned
    /// once, under the first key.
    public static func standingsGrids(from data: Data) throws -> [GridLayout] {
        try grids(from: data) { paths in standingsMarkerPaths.allSatisfy(paths.contains) }
    }

    /// The words FMRTE writes for its wage period, under the top-level entry `Wages`.
    private static let wagePeriods: [String: WagePeriod] = ["Weekly": .weekly, "Monthly": .monthly, "Yearly": .yearly]

    /// The period FMRTE shows wages by: its top-level entry `Wages`. A file with no such entry is weekly, FMRTE's own
    /// default. Any other value, a word it does not write or not a word at all, throws `unknownWagePeriod` with what was
    /// found.
    public static func wagePeriod(from data: Data) throws -> WagePeriod {
        guard let root = try object(from: data) as? [String: Any] else {
            throw ImportError.configUnreadable(reason: "the file is not a JSON object")
        }
        guard let value = root["Wages"] else { return .weekly }
        guard let word = value as? String, let period = wagePeriods[word] else {
            throw ImportError.unknownWagePeriod(found: "\(value)")
        }
        return period
    }

    private static func object(from data: Data) throws -> Any {
        do {
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ImportError.configUnreadable(reason: "not valid JSON: \(error.localizedDescription)")
        }
    }
}
