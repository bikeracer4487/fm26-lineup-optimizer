import Foundation
import Testing
@testable import LineupEngine

@Suite struct ErrorDescriptionsTests {
    /// A Swift case rendered as `caseName(` is a debug dump, not a sentence.
    private func expectPlain(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let names = ["configUnreadable", "noPlayerGrids", "emptyClipboard", "notAnFMRTEGrid", "raggedRows", "noGridFits",
                     "ambiguousGrid", "missingColumns", "invalidValue", "unexpectedScale", "duplicateID", "malformed", "unknownAttribute",
                     "unknownRole", "missingAttribute", "missingFamiliarity", "keyNotFound", "valueNotFound", "typeMismatch",
                     "dataCorrupted", "wrongSlotCount", "missingGoalkeeper", "unmapped", "mappingTargetInactive",
                     "duplicateMappingTarget", "goalkeeperMappedToOutfield", "TacticError", "problems", "fixtureBeforeSnapshot",
                     "fixturesOnTheSameDay", "duplicateFixtureID", "badSettings", "badParameters", "FixtureID", "Day"]
        for name in names { #expect(!text.contains("\(name)("), sourceLocation: sourceLocation) }
    }

    @Test func aDuplicatePlayerErrorNamesThePlayersAndSaysToImportAgain() {
        let text = ErrorDescriptions.describe(DuplicatePlayerError(id: PlayerID(key: "jo bloggs"), names: ["Jo Bloggs", "Jo Bloggs"]))
        #expect(text.contains("jo bloggs") && text.contains("Jo Bloggs and Jo Bloggs") && text.contains("Import the squad again"))
        let viaGeneric = ErrorDescriptions.describe(DuplicatePlayerError(id: PlayerID(key: "k"), names: ["A", "B"]) as Error)
        #expect(viaGeneric.contains("A and B") && !viaGeneric.hasPrefix("Unexpected error"))
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

    @Test func twoRowsWithOneIdNameTheIdAndBothPlayers() {
        let text = ErrorDescriptions.describe(ImportError.duplicateID(id: "146837", players: ["Alfie Potter", "Jonny Maxted"]))
        #expect(text == "Two rows have the same FMRTE Id 146837: Alfie Potter and Jonny Maxted")
        expectPlain(text)
    }

    @Test func importWarningsAreSentences() {
        #expect(ErrorDescriptions.describe(ImportWarning.identifiedByName)
            == "This grid has no Id column, so players are identified by name. Add the Id column in FMRTE for exact identity.")
        #expect(ErrorDescriptions.describe(ImportWarning.outOfContract("Aydin Ulas")) == "Aydin Ulas is out of contract")
        #expect(ErrorDescriptions.describe(ImportWarning.duplicateName("Jo Bloggs"))
            == "more than one player is called Jo Bloggs; they were told apart by potential ability, then nationality")
        #expect(ErrorDescriptions.describe(ImportWarning.indistinguishable("Jo Bloggs"))
            == "players called Jo Bloggs also share potential ability and nationality, so they were told apart by their order "
                + "in the paste; re-sorting the grid in FMRTE can swap them")
    }

    @Test func anUnknownClubSaysWhatIsAssumedAndHowToFixIt() {
        #expect(ErrorDescriptions.describe(SquadWarning.ownClubUnknown)
            == "Your club cannot be told from the squads pasted, so every player with a club under 'loaned to' is treated "
                + "as out on loan. Set your club's name.")
    }

    @Test func aSharedNameNamesThePlayersAndHowTheyAreToldApart() {
        #expect(ErrorDescriptions.describe(SquadWarning.sharedName("Jo Bloggs"))
            == "More than one player is called Jo Bloggs; they are kept as separate players, told apart by potential "
                + "ability, then nationality.")
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
        #expect(role == "Libero is not an out-of-possession role for centre-back")
        #expect(!role.contains(Position.defenderCentral.rawValue))
        let ip = ErrorDescriptions.describe(CatalogError.unknownRole(name: "Libero", phase: .inPossession, position: .defenderCentral))
        #expect(ip.contains("in-possession"))
        for text in [malformed, attribute, role] { expectPlain(text) }
    }

    @Test func tacticProblemsAreEachDescribed() {
        let problems: [(TacticProblem, [String])] = [
            (.wrongSlotCount(.inPossession, 10), ["in-possession", "10"]),
            (.missingGoalkeeper(.outOfPossession), ["out-of-possession", "goalkeeper"]),
            (.unmapped(.D_L), ["Left back"]),
            (.mappingTargetInactive(from: .D_L, to: .D_R), ["Left back", "right back"]),
            (.duplicateMappingTarget(.GK), ["goalkeeper"]),
            (.unknownRole(.inPossession, .AM_C, "Wizard"), ["Wizard", "central attacking midfield", "in-possession"]),
            (.goalkeeperMappedToOutfield(.D_CL), ["Goalkeeper", "left centre-back", "goal"]),
        ]
        for (problem, parts) in problems {
            let text = ErrorDescriptions.describe(problem)
            for part in parts { #expect(text.contains(part), "\(text) should contain \(part)") }
            for code in SlotID.allCases.map(\.rawValue) where code.contains("_") || code == "GK" {
                #expect(!text.contains(code), "\(text) should name no slot by its code")
            }
            expectPlain(text)
        }
        #expect(ErrorDescriptions.describe(TacticProblem.unmapped(.D_L))
            == "Left back has no out-of-possession slot to turn into")
        #expect(ErrorDescriptions.describe(TacticProblem.mappingTargetInactive(from: .D_L, to: .D_R))
            == "Left back turns into right back, which has no out-of-possession role")
        #expect(ErrorDescriptions.describe(TacticProblem.duplicateMappingTarget(.GK))
            == "More than one slot turns into goalkeeper")
        #expect(ErrorDescriptions.describe(TacticProblem.unknownRole(.inPossession, .AM_C, "Wizard"))
            == "Wizard is not an in-possession role for central attacking midfield")
        #expect(ErrorDescriptions.describe(TacticProblem.unknownRole(.outOfPossession, .AM_C, "Wizard"))
            == "Wizard is not an out-of-possession role for central attacking midfield")
        #expect(ErrorDescriptions.describe(TacticProblem.goalkeeperMappedToOutfield(.D_CL))
            == "Goalkeeper turns into left centre-back out of possession; the goalkeeper must stay in goal")
        let all = ErrorDescriptions.describe(TacticError(problems: problems.map(\.0)))
        #expect(all.contains("Wizard") && all.contains("10 slots"))
        expectPlain(all)
    }

    @Test func ratingErrorsNameThePlayerAndWhatIsMissing() {
        let attribute = ErrorDescriptions.describe(RatingError.missingAttribute(player: "Jo Bloggs", attribute: Attribute.allCases[0]))
        #expect(attribute.contains("Jo Bloggs") && attribute.contains(Attribute.allCases[0].rawValue))
        let familiarity = ErrorDescriptions.describe(RatingError.missingFamiliarity(player: "Jo Bloggs", position: .defenderCentral))
        #expect(familiarity == "Jo Bloggs has no familiarity for the position centre-back")
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

    @Test func aFixtureBeforeTheSnapshotNamesItAndBothDates() {
        let error = PlanError.fixtureBeforeSnapshot(FixtureID("cup-3"), date: Day(iso: "2026-11-10")!, asOf: Day(iso: "2026-11-12")!)
        let text = ErrorDescriptions.describe(error)
        #expect(text == "The fixture cup-3 on 2026-11-10 is before the squad was imported on 2026-11-12. "
            + "Confirm its lineup if it has been played, or correct its date.")
        #expect(ErrorDescriptions.describe(error as Error) == text)
        expectPlain(text)
    }

    @Test func twoFixturesOnOneDayNamesBothAndTheDay() {
        let text = ErrorDescriptions.describe(PlanError.fixturesOnTheSameDay(FixtureID("a"), FixtureID("b"), Day(iso: "2026-11-15")!))
        #expect(text == "The fixtures a and b are both on 2026-11-15. A club plays one match a day: correct one of the dates.")
        expectPlain(text)
    }

    @Test func aRepeatedFixtureIDNamesIt() {
        let error = PlanError.duplicateFixtureID(FixtureID("cup-3"))
        let text = ErrorDescriptions.describe(error)
        #expect(text == "More than one fixture, confirmed lineup or played match has the id cup-3. "
            + "Each fixture needs its own id.")
        #expect(ErrorDescriptions.describe(error as Error) == text)
        expectPlain(text)
    }

    @Test func badPlanSettingsListEveryProblem() {
        let text = ErrorDescriptions.describe(PlanError.badSettings(["Stability must be between 0 and 1, but is 2.0", "Horizon must be at least 1 fixture, but is 0"]))
        #expect(text == "The plan settings cannot be used: Stability must be between 0 and 1, but is 2.0; "
            + "Horizon must be at least 1 fixture, but is 0.")
        expectPlain(text)
    }

    @Test func badParametersListEveryProblem() {
        let text = ErrorDescriptions.describe(PlanError.badParameters(["conditionCurve is empty", "jadednessSteps is empty"]))
        #expect(text == "The engine's parameters cannot be used: conditionCurve is empty; jadednessSteps is empty.")
        expectPlain(text)
    }

    @Test func eachExclusionIsAPhraseNamingItsFigures() {
        let p = EngineParameters.fm27
        #expect(ErrorDescriptions.describe(Exclusion.injured, parameters: p) == "injured")
        #expect(ErrorDescriptions.describe(Exclusion.outOnLoan(to: "Banbury United"), parameters: p) == "on loan at Banbury United")
        #expect(ErrorDescriptions.describe(Exclusion.banned, parameters: p) == "banned")
        #expect(ErrorDescriptions.describe(Exclusion.belowConditionFloor(0.78), parameters: p) == "condition 78% is below the 85% floor")
        #expect(ErrorDescriptions.describe(Exclusion.jaded(450), parameters: p) == "jadedness 450 is above 400")
        #expect(ErrorDescriptions.describe(Exclusion.rejected, parameters: p) == "rejected for this fixture")
    }

    @Test func aProjectedFitnessExclusionSaysProjectedAndTheOthersDoNot() {
        let p = EngineParameters.fm27
        #expect(ErrorDescriptions.describe(Exclusion.belowConditionFloor(0.78), parameters: p, projected: true)
            == "projected condition 78% is below the 85% floor")
        #expect(ErrorDescriptions.describe(Exclusion.jaded(450), parameters: p, projected: true) == "projected jadedness 450 is above 400")
        #expect(ErrorDescriptions.describe(Exclusion.injured, parameters: p, projected: true) == "injured")
        #expect(ErrorDescriptions.describe(Exclusion.outOnLoan(to: "Banbury United"), parameters: p, projected: true)
            == "on loan at Banbury United")
        #expect(ErrorDescriptions.describe(Exclusion.banned, parameters: p, projected: true) == "banned")
        #expect(ErrorDescriptions.describe(Exclusion.rejected, parameters: p, projected: true) == "rejected for this fixture")
    }

    @Test func theConditionFloorIsReadFromTheParametersAndRoundedDown() {
        var p = EngineParameters.fm27
        p.conditionFloor = Parameter(0.9, .derived, source: "test")
        #expect(ErrorDescriptions.describe(Exclusion.belowConditionFloor(0.846), parameters: p) == "condition 84% is below the 90% floor")
    }

    @Test func outOfPositionNamesThePhaseTheFamiliarityAndTheThreshold() {
        let p = EngineParameters.fm27
        #expect(ErrorDescriptions.describe(PickWarning.outOfPosition(.inPossession, familiarity: 1), parameters: p)
            == "Out of position in possession: familiarity 1, below 10.")
        #expect(ErrorDescriptions.describe(PickWarning.outOfPosition(.outOfPossession, familiarity: 8), parameters: p)
            == "Out of position out of possession: familiarity 8, below 10.")
        var lower = p
        lower.outOfPositionBelow = Parameter(6, .derived, source: "test")
        #expect(ErrorDescriptions.describe(PickWarning.outOfPosition(.inPossession, familiarity: 5), parameters: lower)
            == "Out of position in possession: familiarity 5, below 6.")
    }

    @Test func aRuleOverriddenSaysSoWithTheRulesPhrase() {
        let p = EngineParameters.fm27
        #expect(ErrorDescriptions.describe(PickWarning.overridesRule(.rejected), parameters: p)
            == "Chosen by you over a rule: rejected for this fixture.")
        #expect(ErrorDescriptions.describe(PickWarning.overridesRule(.belowConditionFloor(0.78)), parameters: p)
            == "Chosen by you over a rule: condition 78% is below the 85% floor.")
        #expect(ErrorDescriptions.describe(PickWarning.overridesRule(.belowConditionFloor(0.78)), parameters: p, projected: true)
            == "Chosen by you over a rule: projected condition 78% is below the 85% floor.")
    }

    @Test func eachOverrideProblemSaysWhyTheChoiceWasNotUsed() {
        let p = EngineParameters.fm27
        #expect(ErrorDescriptions.describe(OverrideProblem.notInSquad, parameters: p) == "who is not in the imported squads")
        #expect(ErrorDescriptions.describe(OverrideProblem.notAllowed(.injured), parameters: p) == "injured, which cannot be overruled")
        #expect(ErrorDescriptions.describe(OverrideProblem.notAllowed(.outOnLoan(to: "Banbury United")), parameters: p)
            == "on loan at Banbury United, which cannot be overruled")
        #expect(ErrorDescriptions.describe(OverrideProblem.usedTwice, parameters: p) == "because he is fixed in another slot too")
        #expect(ErrorDescriptions.describe(OverrideProblem.slotNotInTactic, parameters: p) == "because the tactic has no such slot")
    }

    @Test func anOverrideProblemCarriesTheProjectedForm() {
        let p = EngineParameters.fm27
        #expect(ErrorDescriptions.describe(OverrideProblem.notAllowed(.belowConditionFloor(0.78)), parameters: p, projected: true)
            == "projected condition 78% is below the 85% floor, which cannot be overruled")
        #expect(ErrorDescriptions.describe(OverrideProblem.notAllowed(.belowConditionFloor(0.78)), parameters: p)
            == "condition 78% is below the 85% floor, which cannot be overruled")
        #expect(ErrorDescriptions.describe(OverrideProblem.notInSquad, parameters: p, projected: true) == "who is not in the imported squads")
    }

    @Test func foreignErrorsGetAGenericLineNotADump() {
        struct Foreign: Error {}
        #expect(ErrorDescriptions.describe(Foreign()).hasPrefix("Unexpected error:"))
    }
}
