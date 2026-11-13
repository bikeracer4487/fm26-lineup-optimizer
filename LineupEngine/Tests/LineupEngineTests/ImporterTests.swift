import Foundation
import Testing
@testable import LineupEngine

private func importU21() throws -> ImportResult {
    try Importer.importPlayers(clipboard: Fixtures.text("captures/u21.tsv"),
                               fmrteConfig: Fixtures.data("captures/u21.grids.json"), squad: .u21)
}

private func u21() throws -> [Player] { try importU21().players }

/// The search-grid paste with `change` applied to its rows (each a list of fields), re-joined
/// with tabs and CRLF, imported against the real two-grid config.
private func importU21(changingRows change: ([[String]]) -> [[String]]) throws -> ImportResult {
    let rows = try Fixtures.text("captures/u21.tsv")
        .components(separatedBy: "\r\n").filter { !$0.isEmpty }
        .map { $0.components(separatedBy: "\t") }
    let text = change(rows).map { $0.joined(separator: "\t") }.joined(separator: "\r\n") + "\r\n"
    return try Importer.importPlayers(clipboard: text,
                                      fmrteConfig: Fixtures.data("captures/u21.grids.json"), squad: .u21)
}

/// Where a column sits in the search grid.
private func column(_ path: String) throws -> Int {
    try #require(Fixtures.gridColumns("u21", grid: "SearchPlayersColumns").firstIndex(of: path))
}

/// The fields of a row are quoted in the capture; keep that when replacing one.
private func quoted(_ value: String) -> String { "\"\(value)\"" }

@Suite struct ImporterTests {
    @Test func importsTheRealU21Paste() throws {
        let r = try importU21()
        #expect(r.grid == "SearchPlayersColumns")
        #expect(r.players.count == 6)
        let daniel = try #require(r.players.first { $0.name == "Brayden Daniel" })
        #expect(daniel.squad == .u21 && daniel.age == 20)
        #expect(daniel.currentAbility == 50 && daniel.potentialAbility == 70)
        #expect(daniel.condition == 0.8167 && daniel.sharpness == 0.725 && daniel.jadedness == -122)
        #expect(daniel.attributes[.init(catalogName: "Balance")!] == 6)          // pasted as "£6"
        #expect(daniel.familiarity[.init(rawValue: "AM (R)")!] == 20)
        #expect(daniel.familiarity[.init(rawValue: "M (R)")!] == 15)
        #expect(daniel.askingPrice == 25_250 && daniel.wagePerWeek == 500)
        #expect(daniel.club == "Oxford City" && daniel.loanedTo == nil)
        #expect(daniel.attributes.count == 62 && daniel.familiarity.count == 14)
    }

    @Test func importsTheSamePlayersFromTheTeamGrid() throws {
        let r = try Importer.importPlayers(clipboard: Fixtures.text("captures/u21-team-grid.tsv"),
                                           fmrteConfig: Fixtures.data("captures/u21-team-grid.grids.json"), squad: .u21)
        #expect(r.grid == "TeamPlayersColumns" && r.players.count == 6)
        let daniel = try #require(r.players.first { $0.name == "Brayden Daniel" })
        #expect(daniel.condition == 0.8167 && daniel.sharpness == 0.725 && daniel.jadedness == -122)
        #expect(daniel.club == nil && daniel.askingPrice == nil)
        #expect(daniel.extras["Contract.AgreedPlayingTime"] == "Breakthrough Prospect")
        #expect(daniel.extras["Number"] == "23")
        #expect(daniel.attributes.count == 62 && daniel.familiarity.count == 14)
        #expect(try #require(r.players.first { $0.name == "Max Treml" }).loanedTo == "Wallingford")
    }

    @Test func loanedOutPlayerKeepsHisLoanClub() throws {
        let treml = try #require(u21().first { $0.name == "Max Treml" })
        #expect(treml.loanedTo == "Wallingford" && treml.jadedness == 0 && treml.condition == 0.978)
    }

    @Test func outOfContractPlayerIsFlaggedAndHasNoMonthsLeft() throws {
        let r = try importU21()
        let ulas = try #require(r.players.first { $0.name == "Aydin Ulas" })
        #expect(ulas.contractType == .outOfContract && ulas.monthsLeft == nil && ulas.wagePerWeek == 0)
        #expect(r.warnings.contains(.outOfContract("Aydin Ulas")))
    }

    @Test func aPlayerWithContractTimeLeftIsNotFlagged() throws {
        let r = try importU21()
        let daniel = try #require(r.players.first { $0.name == "Brayden Daniel" })
        #expect(daniel.contractType == .fullTime && daniel.monthsLeft == 10)
        #expect(!r.warnings.contains(.outOfContract("Brayden Daniel")))
    }

    @Test func severalNationalitiesAreSplit() throws {
        #expect(try #require(u21().first { $0.name.hasPrefix("Kauan") }).nationalities == ["Brazil", "England"])
    }

    @Test func namesAreNormalisedForIdentity() {
        #expect(PlayerID.normalise("  José   MARTÍNEZ ") == "jose martinez")
    }

    @Test func playersWithDistinctNamesKeepPlainKeys() throws {
        let r = try importU21()
        #expect(r.players.contains { $0.id.key == "brayden daniel" })
        #expect(!r.warnings.contains(.duplicateName("Brayden Daniel")))
    }

    @Test func twoPlayersWithOneNameBothSurvive() throws {
        let age = try column("Age")
        let r = try importU21 { rows in
            var copy = rows[0]
            copy[age] = quoted("18")
            return rows + [copy]
        }
        #expect(r.players.count == 7)
        let keys = r.players.filter { $0.name == "Brayden Daniel" }.map(\.id.key)
        #expect(keys == ["brayden daniel#20", "brayden daniel#18"])
        #expect(r.warnings.filter { $0 == .duplicateName("Brayden Daniel") }.count == 1)
    }

    @Test func twoPlayersWithOneNameAndAgeAreSeparatedByRow() throws {
        let r = try importU21 { $0 + [$0[0]] }
        let keys = r.players.filter { $0.name == "Brayden Daniel" }.map(\.id.key)
        #expect(keys == ["brayden daniel#20#1", "brayden daniel#20#7"])
        #expect(r.warnings == [.outOfContract("Aydin Ulas"), .duplicateName("Brayden Daniel")])
    }

    @Test func blankConditionStopsTheImportAndNamesThePlayer() throws {
        let condition = try column("Condition")
        #expect(throws: ImportError.invalidValue(player: "Brayden Daniel", column: "Condition", value: "")) {
            try importU21 { rows in
                var rows = rows
                rows[0][condition] = quoted("")
                return rows
            }
        }
    }

    @Test func aNonNumericAttributeNamesThePlayerAndColumn() throws {
        let pace = try column("PhysicalAttributes.Pace")
        #expect(throws: ImportError.invalidValue(player: "Brayden Daniel", column: "PhysicalAttributes.Pace", value: "n/a")) {
            try importU21 { rows in
                var rows = rows
                rows[0][pace] = quoted("n/a")
                return rows
            }
        }
    }

    @Test func aPasteFromAnUnknownLayoutIsNotBlamedOnOneCell() throws {
        do {
            _ = try importU21 { $0.map { Array($0.reversed()) } }
            Issue.record("expected an error")
        } catch let error as ImportError {
            guard case .noGridFits(_, let violations) = error else {
                Issue.record("expected noGridFits, got \(error)")
                return
            }
            #expect(violations.values.allSatisfy { $0 > 6 })
        }
    }

    @Test func percentageScaleConditionIsRejected() throws {
        let condition = try column("Condition")
        #expect(throws: ImportError.unexpectedScale(column: "Condition")) {
            try importU21 { rows in
                rows.map { row in
                    var row = row
                    let value = Int(row[condition].replacingOccurrences(of: "\"", with: ""))! / 100
                    row[condition] = quoted("\(value)")
                    return row
                }
            }
        }
    }

    @Test func percentageScaleSharpnessIsRejected() throws {
        let sharpness = try column("MatchSharpness")
        #expect(throws: ImportError.unexpectedScale(column: "MatchSharpness")) {
            try importU21 { rows in
                rows.map { row in
                    var row = row
                    row[sharpness] = quoted("\(Int(row[sharpness].replacingOccurrences(of: "\"", with: ""))! / 100)")
                    return row
                }
            }
        }
    }

    @Test func oneLowConditionAmongNormalOnesIsNotAScaleError() throws {
        let condition = try column("Condition")
        let r = try importU21 { rows in
            var rows = rows
            rows[0][condition] = quoted("50")
            return rows
        }
        #expect(r.players.first { $0.name == "Brayden Daniel" }?.condition == 0.005)
    }

    @Test func aPlayerRoundTripsThroughJSONWithNamedKeys() throws {
        let player = try #require(u21().first)
        let data = try JSONEncoder().encode(player)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"attributes\":{"))
        #expect(json.contains("\"Pace\""))
        #expect(json.contains("\"familiarity\":{"))
        #expect(try JSONDecoder().decode(Player.self, from: data) == player)
    }

    @Test func theTestFixtureFillsEveryAttributeAndPosition() {
        let p = Player.fixture(all: 12, attributes: [.pace: 18], familiarity: [.striker: 20])
        #expect(p.attributes.count == 62 && p.attributes[.pace] == 18 && p.attributes[.vision] == 12)
        #expect(p.familiarity.count == 14 && p.familiarity[.striker] == 20 && p.familiarity[.goalkeeper] == 1)
        #expect(p.id.key == "test player" && p.club == "Oxford City")
    }
}
