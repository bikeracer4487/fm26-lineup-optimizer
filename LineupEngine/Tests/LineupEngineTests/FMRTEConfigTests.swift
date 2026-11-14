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

    @Test(arguments: [("Weekly", WagePeriod.weekly), ("Monthly", .monthly), ("Yearly", .yearly)])
    func theWagePeriodIsTheOneFMRTEIsSetTo(word: String, period: WagePeriod) throws {
        #expect(try FMRTEConfig.wagePeriod(from: Fixtures.settings("u21", wages: word)) == period)
    }

    @Test func aSettingsFileWithNoWagesEntryIsWeeklyAsFMRTEsDefault() throws {
        #expect(try FMRTEConfig.wagePeriod(from: Fixtures.data("captures/u21.grids.json")) == .weekly)
        #expect(try FMRTEConfig.wagePeriod(from: Fixtures.data("captures/first-team.grids.json")) == .weekly)
    }

    @Test func aPeriodTheToolDoesNotKnowStopsTheImportAndNamesWhatWasFound() throws {
        #expect(throws: ImportError.unknownWagePeriod(found: "Fortnightly")) {
            try FMRTEConfig.wagePeriod(from: Fixtures.settings("u21", wages: "Fortnightly"))
        }
        #expect(throws: ImportError.unknownWagePeriod(found: "2")) {
            try FMRTEConfig.wagePeriod(from: Fixtures.settings("u21", wages: 2))
        }
        // The words are FMRTE's own, written as it writes them.
        #expect(throws: ImportError.unknownWagePeriod(found: "monthly")) {
            try FMRTEConfig.wagePeriod(from: Fixtures.settings("u21", wages: "monthly"))
        }
    }

    @Test func aFileThatIsNotJSONCannotBeRead() {
        #expect(throws: ImportError.self) { try FMRTEConfig.wagePeriod(from: Data("not json".utf8)) }
    }
}
