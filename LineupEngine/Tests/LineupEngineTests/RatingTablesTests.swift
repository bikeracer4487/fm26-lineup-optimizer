import Foundation
import Testing
@testable import LineupEngine

@Suite struct RatingTablesTests {
    @Test func bundledTablesCoverEveryPosition() throws {
        let t = try RatingTables.bundled()
        #expect(t.positionWeights.count == 14)
        for position in Position.allCases { #expect(t.positionWeights[position] != nil) }
        for (_, w) in t.positionWeights { #expect(abs(w.values.reduce(0, +) - 1.0) < 0.001) }
        #expect(t.thresholds["Winger"]?[.init(catalogName: "Pace")!] == 15)
        #expect(t.consensusBonuses["ST|Central Outlet Centre Forward"] != nil)
        #expect(t.consensusBonuses["ST|Central Outlet Centre Forward"]?[.pace] == 0.030)
    }

    @Test func everyTableCarriesAnEvidenceLabelAndASource() throws {
        let entries = RatingTables.evidence
        #expect(entries.map(\.name) == ["positionWeights", "consensusBonuses", "thresholds"])
        #expect(entries.allSatisfy { $0.evidence == .carriedOverFM26 && !$0.source.isEmpty })
        for (entry, table) in zip(entries, ["POSITION_WEIGHTS", "CONSENSUS_BONUSES", "THRESHOLDS"]) {
            #expect(entry.source.contains("rating_calculator.py") && entry.source.contains(table), "\(entry.name): \(entry.source)")
        }
        let thresholds = try #require(entries.first { $0.name == "thresholds" })
        #expect(thresholds.source.contains("elite"))
    }

    @Test func anUnknownAttributeInATableFailsToLoad() {
        let json = #"{"positionWeights":{"GK":{"Workrate":1.0}},"consensusBonuses":{},"thresholds":{}}"#
        #expect(throws: CatalogError.unknownAttribute(role: "GK", name: "Workrate")) {
            try RatingTables(json: Data(json.utf8))
        }
    }

    @Test(arguments: ["AM (C)|Advanced Playmaker", "XX|Probe", "Probe", "|Probe"])
    func aConsensusBonusForAnUnknownPositionFailsToLoadAndNamesTheKey(_ key: String) throws {
        let json = try bundledText().replacingOccurrences(of: #""consensusBonuses": {"#,
                                                          with: #""consensusBonuses": {"\#(key)": {"Pace": 0.01}, "#)
        try #require(json.contains(key))
        #expect(throws: CatalogError.malformed(reason: "rating tables have a consensus bonus for an unknown position: \(key)")) {
            try RatingTables(json: Data(json.utf8))
        }
    }

    @Test func aConsensusBonusForEachKnownPositionLoads() throws {
        for position in Position.allCases {
            let key = "\(position.tableKey)|Probe"
            let json = try bundledText().replacingOccurrences(of: #""consensusBonuses": {"#,
                                                              with: #""consensusBonuses": {"\#(key)": {"Pace": 0.01}, "#)
            #expect(try RatingTables(json: Data(json.utf8)).consensusBonuses[key] == [.pace: 0.01])
        }
    }

    /// The library's `rating_tables.json` as text.
    private func bundledText() throws -> String {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/LineupEngine/Resources/rating_tables.json")
        return try String(contentsOf: url, encoding: .utf8)
    }

    @Test func anUnknownPositionFailsToLoad() {
        let json = #"{"positionWeights":{"XX":{"Pace":1.0}},"consensusBonuses":{},"thresholds":{}}"#
        #expect(throws: CatalogError.self) { try RatingTables(json: Data(json.utf8)) }
    }

    private func bundledJSON(editing edit: (inout [String: [String: [String: Double]]]) -> Void) throws -> Data {
        // The library's resource lives in the source tree; the test bundle's own `Bundle.module` is a different bundle.
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/LineupEngine/Resources/rating_tables.json")
        var object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var weights = try #require(object["positionWeights"] as? [String: [String: Double]])
        var wrapper = ["w": weights]
        edit(&wrapper)
        weights = wrapper["w"]!.mapValues { $0 }
        object["positionWeights"] = weights as [String: [String: Double]]
        return try JSONSerialization.data(withJSONObject: object)
    }

    @Test func aPositionWithoutWeightsFailsToLoadAndNamesIt() throws {
        let data = try bundledJSON { $0["w"]?["GK"] = nil }
        #expect(throws: CatalogError.malformed(reason: "rating tables have no position weights for GK")) {
            try RatingTables(json: data)
        }
    }

    @Test func anEmptyOrZeroSumWeightTableFailsToLoadAndNamesThePosition() throws {
        let empty = try bundledJSON { $0["w"]?["D (C)"] = [:] }
        #expect(throws: CatalogError.malformed(reason: "rating tables have empty or zero-sum position weights for D (C)")) {
            try RatingTables(json: empty)
        }
        let zero = try bundledJSON { $0["w"]?["ST (C)"] = ["Pace": 0] }
        #expect(throws: CatalogError.malformed(reason: "rating tables have empty or zero-sum position weights for ST (C)")) {
            try RatingTables(json: zero)
        }
    }
}
