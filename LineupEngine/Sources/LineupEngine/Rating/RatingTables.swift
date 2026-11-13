import Foundation

/// The weight, bonus and threshold tables of the rating formula, loaded from `rating_tables.json`.
public struct RatingTables: Sendable {
    public let positionWeights: [Position: [Attribute: Double]]
    /// Key `"<tableKey>|<role name>"`.
    public let consensusBonuses: [String: [Attribute: Double]]
    /// Key role name.
    public let thresholds: [String: [Attribute: Int]]

    /// The evidence label and source of each table, as `EngineParameters.all` gives them for single numbers.
    public static let evidence: [(name: String, evidence: Evidence, source: String)] = [
        ("positionWeights", .carriedOverFM26,
         "rating_calculator.py POSITION_WEIGHTS (branch customizable-tactics), from FM26 engine testing"),
        ("consensusBonuses", .carriedOverFM26,
         "rating_calculator.py CONSENSUS_BONUSES (branch customizable-tactics)"),
        ("thresholds", .carriedOverFM26,
         "rating_calculator.py THRESHOLDS (branch customizable-tactics); the Python notes they are tuned for elite players "
            + "in top leagues and can be too harsh for lower-league squads"),
    ]

    /// Builds tables directly, without the checks `init(json:)` makes; for tests that need custom tables.
    init(positionWeights: [Position: [Attribute: Double]], consensusBonuses: [String: [Attribute: Double]],
         thresholds: [String: [Attribute: Int]]) {
        self.positionWeights = positionWeights
        self.consensusBonuses = consensusBonuses
        self.thresholds = thresholds
    }

    public init(json: Data) throws {
        struct File: Decodable {
            let positionWeights: [String: [String: Double]]
            let consensusBonuses: [String: [String: Double]]
            let thresholds: [String: [String: Int]]
        }
        let file: File
        do { file = try JSONDecoder().decode(File.self, from: json) } catch {
            throw CatalogError.malformed(reason: "rating tables: \(error)")
        }
        func attributes<V>(_ table: [String: V], owner: String) throws -> [Attribute: V] {
            var result: [Attribute: V] = [:]
            for (name, value) in table {
                guard let attribute = Attribute(catalogName: name) else {
                    throw CatalogError.unknownAttribute(role: owner, name: name)
                }
                result[attribute] = value
            }
            return result
        }
        var weights: [Position: [Attribute: Double]] = [:]
        for (code, table) in file.positionWeights {
            guard let position = Position(rawValue: code) else {
                throw CatalogError.malformed(reason: "rating tables have unknown position \(code)")
            }
            weights[position] = try attributes(table, owner: code)
        }
        for position in Position.allCases {
            guard let table = weights[position] else {
                throw CatalogError.malformed(reason: "rating tables have no position weights for \(position.rawValue)")
            }
            guard table.values.reduce(0, +) > 0 else {
                throw CatalogError.malformed(reason: "rating tables have empty or zero-sum position weights for \(position.rawValue)")
            }
        }
        positionWeights = weights
        // A key whose position half matches no table key would never be looked up, silently.
        let tableKeys = Set(Position.allCases.map(\.tableKey))
        for key in file.consensusBonuses.keys.sorted() {
            let parts = key.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, tableKeys.contains(String(parts[0])) else {
                throw CatalogError.malformed(reason: "rating tables have a consensus bonus for an unknown position: \(key)")
            }
        }
        consensusBonuses = try file.consensusBonuses.reduce(into: [:]) { $0[$1.key] = try attributes($1.value, owner: $1.key) }
        thresholds = try file.thresholds.reduce(into: [:]) { $0[$1.key] = try attributes($1.value, owner: $1.key) }
    }

    /// The tables bundled with the library.
    public static func bundled() throws -> RatingTables {
        guard let url = Bundle.module.url(forResource: "rating_tables", withExtension: "json") else {
            throw CatalogError.malformed(reason: "rating_tables.json is missing from the bundle")
        }
        return try RatingTables(json: Data(contentsOf: url))
    }
}
