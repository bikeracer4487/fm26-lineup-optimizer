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
        let root: Any
        do {
            root = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ImportError.configUnreadable(reason: "not valid JSON: \(error.localizedDescription)")
        }
        guard let items = ((root as? [String: Any])?["ColumnsSettings"] as? [String: Any])?["Items"] as? [[String: Any]] else {
            throw ImportError.configUnreadable(reason: "ColumnsSettings.Items not found")
        }

        var grids: [GridLayout] = []
        for item in items {
            guard let key = item["SettingsKey"] as? String,
                  let columns = item["Columns"] as? [[String: Any]] else { continue }
            let paths = columns.compactMap { $0["Path"] as? String }
            guard paths.contains(playerNamePath) else { continue }
            if grids.contains(where: { $0.columns == paths }) { continue }
            grids.append(GridLayout(key: key, columns: paths))
        }
        return grids
    }
}
