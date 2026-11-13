import Foundation
import Testing
@testable import LineupEngine

@Suite struct FMRTEConfigTests {
    @Test func readsBothPlayerGridsFromTheSnapshot() throws {
        let grids = try FMRTEConfig.playerGrids(from: Fixtures.data("captures/u21.grids.json"))
        #expect(grids.map(\.key).sorted() == ["SearchPlayersColumns", "TeamPlayersColumns"])
        #expect(grids.allSatisfy { $0.columns.count == 98 })
        #expect(grids.first { $0.key == "SearchPlayersColumns" }?.columns[1] == "DisplayedName")
    }

    @Test func configWithANewShapeNamesWhatWasExpected() {
        #expect(throws: ImportError.configUnreadable(reason: "ColumnsSettings.Items not found")) {
            try FMRTEConfig.playerGrids(from: Data(#"{"Theme":"Dark"}"#.utf8))
        }
        #expect(throws: ImportError.self) { try FMRTEConfig.playerGrids(from: Data("not json".utf8)) }
    }
}
