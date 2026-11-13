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

    @Test func anUnknownAttributeInATableFailsToLoad() {
        let json = #"{"positionWeights":{"GK":{"Workrate":1.0}},"consensusBonuses":{},"thresholds":{}}"#
        #expect(throws: CatalogError.unknownAttribute(role: "GK", name: "Workrate")) {
            try RatingTables(json: Data(json.utf8))
        }
    }

    @Test func anUnknownPositionFailsToLoad() {
        let json = #"{"positionWeights":{"XX":{"Pace":1.0}},"consensusBonuses":{},"thresholds":{}}"#
        #expect(throws: CatalogError.self) { try RatingTables(json: Data(json.utf8)) }
    }
}
