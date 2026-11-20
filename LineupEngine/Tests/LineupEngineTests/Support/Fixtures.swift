import Foundation

/// Reads files from the `Fixtures` directory copied into the test bundle.
enum Fixtures {
    struct MissingFixture: Error, CustomStringConvertible {
        let description: String
    }

    static func url(_ name: String) throws -> URL {
        let url = Bundle.module.resourceURL!.appendingPathComponent("Fixtures").appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MissingFixture(description: "Fixture not found: \(name)")
        }
        return url
    }

    static func text(_ name: String) throws -> String {
        try String(contentsOf: url(name), encoding: .utf8)
    }

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: url(name))
    }

    /// The owner's league table of 19 November 2026 (`captures/league-table.tsv`) and its grid layout.
    static var leagueTable: String { get throws { try text("captures/league-table.tsv") } }
    static var leagueTableGrids: Data { get throws { try data("captures/league-table.grids.json") } }

    /// FMRTE's settings file as `captures/<capture>.grids.json` holds it, with a top-level `Wages` entry of `wages`, as
    /// FMRTE writes beside its column layouts. The captures hold only the layouts.
    static func settings(_ capture: String, wages: Any) throws -> Data {
        guard var root = try JSONSerialization.jsonObject(with: data("captures/\(capture).grids.json")) as? [String: Any] else {
            throw MissingFixture(description: "captures/\(capture).grids.json is not a JSON object")
        }
        root["Wages"] = wages
        return try JSONSerialization.data(withJSONObject: root)
    }

    /// The column paths of one grid in `captures/<capture>.grids.json`.
    static func gridColumns(_ capture: String, grid: String) throws -> [String] {
        struct File: Decodable {
            struct Settings: Decodable {
                struct Item: Decodable {
                    struct Column: Decodable { let Path: String }
                    let SettingsKey: String
                    let Columns: [Column]
                }
                let Items: [Item]
            }
            let ColumnsSettings: Settings
        }
        let file = try JSONDecoder().decode(File.self, from: data("captures/\(capture).grids.json"))
        guard let item = file.ColumnsSettings.Items.first(where: { $0.SettingsKey == grid }) else {
            throw MissingFixture(description: "Grid \(grid) not found in \(capture).grids.json")
        }
        return item.Columns.map(\.Path)
    }
}
