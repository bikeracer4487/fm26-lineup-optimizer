import Foundation
import Testing
@testable import LineupEngine

@Suite struct ErrorDescriptionsTests {
    /// A Swift case rendered as `caseName(` is a debug dump, not a sentence.
    private func expectPlain(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let names = ["configUnreadable", "noPlayerGrids", "emptyClipboard", "notAnFMRTEGrid", "raggedRows", "noGridFits",
                     "ambiguousGrid", "missingColumns", "invalidValue", "unexpectedScale", "malformed", "unknownAttribute",
                     "unknownRole", "missingAttribute", "missingFamiliarity", "keyNotFound", "valueNotFound", "typeMismatch",
                     "dataCorrupted", "wrongSlotCount", "missingGoalkeeper", "unmapped", "mappingTargetInactive",
                     "duplicateMappingTarget", "goalkeeperMappedToOutfield", "TacticError", "problems"]
        for name in names { #expect(!text.contains("\(name)("), sourceLocation: sourceLocation) }
    }

    @Test func importErrorsNameTheirSpecifics() {
        let invalid = ErrorDescriptions.describe(ImportError.invalidValue(player: "Jo Bloggs", column: "Condition", value: "abc"))
        #expect(invalid.contains("Jo Bloggs") && invalid.contains("Condition") && invalid.contains("abc"))
        let fits = ErrorDescriptions.describe(ImportError.noGridFits(fieldCount: 42, violationsByGrid: ["GridA": 3, "GridB": 7]))
        #expect(fits.contains("42") && fits.contains("GridA 3") && fits.contains("GridB 7"))
        let ragged = ErrorDescriptions.describe(ImportError.raggedRows(expected: 10, row: 4, found: 9))
        #expect(ragged.contains("4") && ragged.contains("9") && ragged.contains("10"))
        let missing = ErrorDescriptions.describe(ImportError.missingColumns(grid: "G", columns: ["CA", "PA"]))
        #expect(missing.contains("G") && missing.contains("CA, PA"))
        #expect(ErrorDescriptions.describe(ImportError.ambiguousGrid(keys: ["B", "A"])).contains("A, B"))
        #expect(ErrorDescriptions.describe(ImportError.unexpectedScale(column: "Condition")).contains("Condition"))
        #expect(ErrorDescriptions.describe(ImportError.configUnreadable(reason: "not valid JSON"))
            == "FMRTE's configuration cannot be read: not valid JSON")
        #expect(ErrorDescriptions.describe(ImportError.noPlayerGrids) == "FMRTE's configuration has no player grids")
        for error in [ImportError.invalidValue(player: "P", column: "C", value: "v"), .emptyClipboard, .noPlayerGrids,
                      .configUnreadable(reason: "r"), .notAnFMRTEGrid(reason: "r"), .noGridFits(fieldCount: 1, violationsByGrid: ["G": 1])] {
            expectPlain(ErrorDescriptions.describe(error))
        }
    }

    @Test func aPasteNoSavedGridIsWideEnoughForSaysSo() {
        let none = ErrorDescriptions.describe(ImportError.noGridFits(fieldCount: 97, violationsByGrid: [:]))
        #expect(none == "No saved FMRTE grid has 97 columns, as the paste has; FMRTE may not have saved its current layout yet")
        #expect(!none.contains("misfit"))
        let some = ErrorDescriptions.describe(ImportError.noGridFits(fieldCount: 98, violationsByGrid: ["GridA": 3]))
        #expect(some == "No grid fits the paste's 98 columns (misfit cells per grid: GridA 3)")
        expectPlain(none)
    }

    @Test func catalogErrorsNameTheirSpecifics() {
        let malformed = ErrorDescriptions.describe(CatalogError.malformed(reason: "no roles array"))
        #expect(malformed == "The role or rating data is damaged: no roles array")
        let attribute = ErrorDescriptions.describe(CatalogError.unknownAttribute(role: "Poacher", name: "Flair2"))
        #expect(attribute == "Poacher uses an attribute the engine does not know: Flair2")
        let role = ErrorDescriptions.describe(CatalogError.unknownRole(name: "Libero", phase: .outOfPossession, position: .defenderCentral))
        #expect(role.contains("Libero") && role.contains("out-of-possession") && role.contains(Position.defenderCentral.rawValue))
        let ip = ErrorDescriptions.describe(CatalogError.unknownRole(name: "Libero", phase: .inPossession, position: .defenderCentral))
        #expect(ip.contains("in-possession"))
        for text in [malformed, attribute, role] { expectPlain(text) }
    }

    @Test func tacticProblemsAreEachDescribed() {
        let problems: [(TacticProblem, [String])] = [
            (.wrongSlotCount(.inPossession, 10), ["in-possession", "10"]),
            (.missingGoalkeeper(.outOfPossession), ["out-of-possession", "goalkeeper"]),
            (.unmapped(.D_L), ["D_L"]),
            (.mappingTargetInactive(from: .D_L, to: .D_R), ["D_L", "D_R"]),
            (.duplicateMappingTarget(.GK), ["GK"]),
            (.unknownRole(.inPossession, .AM_C, "Wizard"), ["Wizard", "AM_C", "in-possession"]),
            (.goalkeeperMappedToOutfield(.D_CL), ["GK", "D_CL", "goal"]),
        ]
        for (problem, parts) in problems {
            let text = ErrorDescriptions.describe(problem)
            for part in parts { #expect(text.contains(part), "\(text) should contain \(part)") }
            expectPlain(text)
        }
        #expect(ErrorDescriptions.describe(TacticProblem.unknownRole(.inPossession, .AM_C, "Wizard"))
            == "Wizard is not an in-possession role for AM_C")
        #expect(ErrorDescriptions.describe(TacticProblem.unknownRole(.outOfPossession, .AM_C, "Wizard"))
            == "Wizard is not an out-of-possession role for AM_C")
        #expect(ErrorDescriptions.describe(TacticProblem.goalkeeperMappedToOutfield(.D_CL))
            == "GK turns into D_CL out of possession; the goalkeeper must stay in goal")
        let all = ErrorDescriptions.describe(TacticError(problems: problems.map(\.0)))
        #expect(all.contains("Wizard") && all.contains("10 slots"))
        expectPlain(all)
    }

    @Test func ratingErrorsNameThePlayerAndWhatIsMissing() {
        let attribute = ErrorDescriptions.describe(RatingError.missingAttribute(player: "Jo Bloggs", attribute: Attribute.allCases[0]))
        #expect(attribute.contains("Jo Bloggs") && attribute.contains(Attribute.allCases[0].rawValue))
        let familiarity = ErrorDescriptions.describe(RatingError.missingFamiliarity(player: "Jo Bloggs", position: .defenderCentral))
        #expect(familiarity.contains("Jo Bloggs") && familiarity.contains(Position.defenderCentral.rawValue))
        expectPlain(attribute); expectPlain(familiarity)
    }

    @Test func aTacticMissingAFieldNamesTheField() {
        do {
            _ = try JSONDecoder().decode(Tactic.self, from: Data(#"{"name":"x"}"#.utf8))
            Issue.record("decoding should have failed")
        } catch {
            let text = ErrorDescriptions.describe(error)
            #expect(text == "missing the field 'inPossession'")
        }
    }

    @Test func otherDecodingFailuresCarryTheFieldPath() {
        func failure(_ json: String) -> String {
            do { _ = try JSONDecoder().decode(Tactic.self, from: Data(json.utf8)) } catch { return ErrorDescriptions.describe(error) }
            return "decoded"
        }
        let mismatch = failure(#"{"name":5,"inPossession":{},"outOfPossession":{},"mapping":{}}"#)
        #expect(mismatch.contains("'name'") && mismatch.contains("wrong kind"))
        let corrupted = failure("not json")
        #expect(corrupted.contains("not valid"))
        #expect(ErrorDescriptions.describe(DecodingError.valueNotFound(String.self, .init(codingPath: [], debugDescription: "x"))).contains("no value"))
        for text in [mismatch, corrupted] { expectPlain(text) }
    }

    @Test func foreignErrorsGetAGenericLineNotADump() {
        struct Foreign: Error {}
        #expect(ErrorDescriptions.describe(Foreign()).hasPrefix("Unexpected error:"))
    }
}
