import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

/// The samples and what the tests read from them.
@MainActor private enum ContractsSample {
    static func filled() throws -> AppModel { try SampleData.modelWithContracts(repositoryRoot: Captures.repositoryRoot) }
    static func plain() throws -> AppModel {
        try SampleData.modelWithContractsNoFigures(repositoryRoot: Captures.repositoryRoot)
    }

    static func sheet(_ model: AppModel) throws -> ContractsSheet {
        guard case .ready(let sheet) = model.contractsSheet else {
            throw SampleDataError(description: "no contracts sheet: \(model.contractsSheet)")
        }
        return sheet
    }

    static func advice(_ model: AppModel) throws -> AdvisorsReport {
        guard case .ready(let advice) = model.adviceState else {
            throw SampleDataError(description: "no advice: \(model.adviceState)")
        }
        return advice
    }

    static func player(_ name: String, in model: AppModel) throws -> Player {
        try #require(model.squad.book.allPlayers.first { $0.name == name })
    }

    static func listed(_ sheet: ContractsSheet) -> [ContractRow] { sheet.parts.flatMap(\.rows) }
}

@MainActor @Suite struct ContractsPresentationTests {
    // MARK: Who is listed

    @Test func theSampleListsEachPartInTheEnginesOrderAndWordsAndOnlyPlayersRunningDown() throws {
        let model = try ContractsSample.filled()
        let sheet = try ContractsSample.sheet(model)
        #expect(sheet.parts.map(\.heading) == ["Other clubs can approach them now", "In their last year", "No contract"])
        #expect(sheet.parts.map(\.heading) == ContractPart.allCases.map(AdvisorText.contractPartHeading))
        let players = Dictionary(model.squad.book.allPlayers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for (part, rows) in zip(ContractPart.allCases, sheet.parts.map(\.rows)) {
            #expect(!rows.isEmpty)
            for row in rows {
                let player = try #require(players[row.id])
                #expect(Contracts.part(of: player, today: model.settings.currentDate, parameters: model.planParameters) == part,
                        "\(row.name)")
            }
        }
        #expect(sheet.intro == AdvisorText.contractsIntro)
        #expect(sheet.emptyLine == nil)
        #expect(sheet.evidenceNote == AdvisorText.contractsEvidenceNote(model.planParameters.wageRangeRules.value))
    }

    @Test func theSheetIsTheEnginesListForTheBooksPlayersMarksAdviceTacticDismissalsAndToday() throws {
        let model = try ContractsSample.filled()
        let advice = try ContractsSample.advice(model)
        let tactic = try #require(model.primaryTactic).tactic
        let report = try Contracts.report(
            players: model.squad.book.allPlayers, ownClub: model.ownClub, marks: model.marks, removal: advice.removal,
            elevens: advice.elevens, tactic: tactic, dismissed: Set(model.contracts.dismissed.keys),
            today: model.settings.currentDate, catalog: model.catalog, profile: model.profile,
            parameters: model.planParameters)
        let sheet = try ContractsSample.sheet(model)
        #expect(ContractsSample.listed(sheet).map(\.id) == report.listed.map(\.player))
        #expect(sheet.dismissed.map(\.id) == report.dismissed.map(\.player))
        #expect(ContractsSample.listed(sheet).map(\.standingLine) == report.listed.map(AdvisorText.standingLine))
        #expect(ContractsSample.listed(sheet).map(\.timingLine) == report.listed.map(AdvisorText.timingLine))
    }

    @Test func aRowsDetailsAreHisAgePositionsAndFactsWithWhereHeIsOutOnLoanLast() throws {
        let model = try ContractsSample.plain()
        let rows = ContractsSample.listed(try ContractsSample.sheet(model))
        let humphries = try #require(rows.first { $0.name == SampleData.contractsFigureName })
        #expect(humphries.detailsText == "Age 22 · D L · CA 83 · PA 95 · $39,228 a year · contract ends 30 Jun 2028")
        let clark = try #require(rows.first { $0.name == "Ewan Clark" })
        #expect(clark.detailsText == "Age 24 · AM RL · CA 69 · PA 85 · $39,228 a year · contract ends 30 Jun 2028 · "
                + "Out on loan at Hemel Hempstead")
        #expect(clark.standingLine.hasPrefix("Out on loan at Hemel Hempstead; "))
    }

    // MARK: The range and the verdict

    @Test func aRowsGuideIsTheRangeForHisTierWorkedOutFromTheSecondElevensWages() throws {
        let model = try ContractsSample.plain()
        let advice = try ContractsSample.advice(model)
        let humphries = try ContractsSample.player(SampleData.contractsFigureName, in: model)
        let row = try #require(ContractsSample.listed(try ContractsSample.sheet(model)).first { $0.id == humphries.id })
        // The second eleven's wages by hand: his own players in it, paid a wage and not on a youth contract, without him.
        let players = Dictionary(model.squad.book.allPlayers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let second = advice.elevens.second.compactMap { players[$0.player] }
            .filter { $0.id != humphries.id && $0.wagePerWeek > 0 && $0.contractType != .youth && $0.loanedTo == nil }
        let wages = second.map(\.wagePerWeek).sorted()
        try #require(wages.count >= 3)
        let lower = Array(wages.prefix(wages.count / 2))
        let quartile = lower.count % 2 == 1 ? lower[lower.count / 2] : (lower[lower.count / 2 - 1] + lower[lower.count / 2]) / 2
        let byHand = [WageTier.secondEleven: ([humphries] + second).map { PlayerWage(player: $0.id, perWeek: $0.wagePerWeek) }]
        let guide = try WageRange.guide(tier: .secondEleven, slot: .D_L, wages: byHand, excluding: humphries.id,
                                        presentWagePerWeek: humphries.wagePerWeek, limits: .none,
                                        parameters: model.planParameters)
        #expect(guide.paid?.lowerQuartile == quartile)
        #expect(guide.paid?.highest == wages.last)
        #expect(row.guideLines == AdvisorText.wageGuideLines(guide, money: model.squad.book.moneyStyle))
        #expect(row.guideLines.first?.hasPrefix("The rest of your second eleven are paid ") == true)
        #expect(row.verdictLines.isEmpty && row.figureText.isEmpty && row.figureReading == nil
                && row.figureEnteredText == nil, "no figure typed")
    }

    @Test func aFigureAboveTheHighestWageIsFirstSaidToBeAboveIt() throws {
        let model = try ContractsSample.filled()
        let humphries = try ContractsSample.player(SampleData.contractsFigureName, in: model)
        let row = try #require(ContractsSample.listed(try ContractsSample.sheet(model)).first { $0.id == humphries.id })
        #expect(row.figureLabel == "The agent's figure, a month")
        #expect(row.figureText == "9500")
        #expect(row.figureReading == "$9,500 a month")
        #expect(row.figureEnteredText == AdvisorText.enteredOn(SampleData.contractsDate))
        // The over-the-highest-wage sentence stands apart, for the caution style, and is not repeated in the rest.
        let highest = "The agent's figure is above the most you can offer one player, $9,000 a month."
        #expect(row.cautionVerdictLine == highest)
        #expect(!row.verdictLines.contains(highest))
        #expect(row.verdictLines.count == 3)
        // The guide the verdict is read against carries the typed limits.
        let ceiling = Display.wage(perWeek: WagePeriod.monthly.perWeek(130_000 * 0.027), model.squad.book.moneyStyle)
        #expect(row.verdictLines.contains("The agent's figure is above a backup's share of your wage budget, \(ceiling) (this tool's estimate)."))
        #expect(row.guideLines.contains { $0.hasPrefix("The most you can offer one player is $9,000 a month") })
    }

    @Test func aFigureUnderTheHighestWageHasNoCautionLineAndKeepsEveryVerdict() throws {
        let model = try ContractsSample.filled()
        let humphries = try ContractsSample.player(SampleData.contractsFigureName, in: model)
        model.setAgentFigure(text: "3000", for: humphries.id)
        let row = try #require(ContractsSample.listed(try ContractsSample.sheet(model)).first { $0.id == humphries.id })
        #expect(row.cautionVerdictLine == nil)
        #expect(row.verdictLines.first == "The agent's figure is within what the rest of your second eleven are paid.")
        #expect(!row.verdictLines.contains { $0.contains("the most you can offer one player") })
    }

    @Test func onlyTheRowsOtherClubsCanApproachNowHaveTheirTimingAsACaution() throws {
        let sheet = try ContractsSample.sheet(try ContractsSample.filled())
        let heading = AdvisorText.contractPartHeading(.approachable)
        for part in sheet.parts {
            #expect(!part.rows.isEmpty)
            #expect(part.rows.allSatisfy { $0.timingIsCaution == (part.heading == heading) }, "\(part.heading)")
        }
        #expect(!sheet.dismissed.isEmpty && sheet.dismissed.allSatisfy { !$0.timingIsCaution && $0.cautionVerdictLine == nil })
    }

    @Test func aRowWithNoFigureHasNoVerdict() throws {
        let model = try ContractsSample.filled()
        let rows = ContractsSample.listed(try ContractsSample.sheet(model)).filter { $0.name != SampleData.contractsFigureName }
        #expect(!rows.isEmpty && rows.allSatisfy { $0.verdictLines.isEmpty && $0.cautionVerdictLine == nil
                                                    && $0.figureReading == nil })
    }

    // MARK: The players not being renewed

    @Test func aDismissedPlayerIsBehindTheNotRenewingLineWithHisFactsAndStandingOnly() throws {
        let model = try ContractsSample.filled()
        let sheet = try ContractsSample.sheet(model)
        let tetek = try ContractsSample.player(SampleData.contractsDismissedName, in: model)
        #expect(!ContractsSample.listed(sheet).contains { $0.id == tetek.id })
        #expect(sheet.dismissed.map(\.id) == [tetek.id])
        #expect(sheet.dismissedLine == "1 player you are not renewing")
        let row = try #require(sheet.dismissed.first)
        #expect(row.detailsText == "Age 25 · DM/M C · CA 74 · PA 113 · $47,064 a year · contract ends 30 Jun 2029")
        #expect(row.standingLine == "Second choice at right defensive midfield.")
        #expect(row.timingLine == nil && row.guideLines.isEmpty && row.figureText.isEmpty && row.figureReading == nil
                && row.figureEnteredText == nil && row.verdictLines.isEmpty)
        model.showContractAgain(tetek.id)
        let shown = try ContractsSample.sheet(model)
        #expect(shown.dismissed.isEmpty && shown.dismissedLine == nil)
        #expect(ContractsSample.listed(shown).contains { $0.id == tetek.id })
    }

    // MARK: The count

    @Test func theCountIsTheRowsInThePartsAndAMarkToSellTakesOneOut() throws {
        let model = try ContractsSample.filled()
        let sheet = try ContractsSample.sheet(model)
        let rows = ContractsSample.listed(sheet)
        #expect(model.contractsCount == rows.count)
        // Player Removal advises two players in their last six months to go: Ayman Benarous and Rafiq Khaleel.
        let going = 2
        #expect(sheet.leftOutLine == AdvisorText.leftOutAsGoingLine(going))
        let marked = try #require(rows.first { $0.name == SampleData.contractsFigureName })
        model.setMark(.toSell, for: marked.id)
        #expect(model.contractsCount == rows.count - 1)
        let after = try ContractsSample.sheet(model)
        #expect(!ContractsSample.listed(after).contains { $0.id == marked.id })
        #expect(after.leftOutLine == AdvisorText.leftOutAsGoingLine(going + 1))
    }

    @Test func withNobodyListedThePartsAreEmptyTheEnginesLineShowsAndThereIsNoCount() throws {
        let model = try ContractsSample.plain()
        for row in ContractsSample.listed(try ContractsSample.sheet(model)) { model.dismissContract(row.id) }
        let sheet = try ContractsSample.sheet(model)
        #expect(sheet.parts.isEmpty)
        #expect(sheet.emptyLine == AdvisorText.nobodyInLastYear)
        #expect(model.contractsCount == nil)
        #expect(!sheet.dismissed.isEmpty)
    }

    @Test func movingTodayOnAYearListsAPlayerWhoseContractThenEndsWithinTheYearWithoutAnImport() throws {
        let model = try ContractsSample.plain()
        let avenell = try ContractsSample.player("Caelan Avenell", in: model)
        #expect(avenell.contractEnds == Day(iso: "2030-06-30"))
        #expect(!ContractsSample.listed(try ContractsSample.sheet(model)).contains { $0.id == avenell.id })
        let imported = model.squad.importedOn
        model.moveToday(by: 365)
        #expect(model.settings.currentDate == Day(iso: "2029-06-30"))
        let row = try #require(ContractsSample.listed(try ContractsSample.sheet(model)).first { $0.id == avenell.id })
        #expect(row.timingLine == "Other clubs can approach him from \(AdvisorText.shortDay(Day(iso: "2029-12-30")!)).")
        #expect(model.squad.importedOn == imported)
    }

    // MARK: Not ready

    @Test func withNoSquadTheListWaitsAndThereIsNoCount() {
        let model = SampleData.emptyModel()
        #expect(model.contractsSheet == .notReady(.needsSquad))
        #expect(model.contractsCount == nil)
    }

    @Test func withNoTacticTheListWaitsAndThereIsNoCount() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        #expect(t.model.contractsSheet == .notReady(.needsTactic([])))
        #expect(t.model.contractsCount == nil)
    }

    @Test func whenTheAdviceStopsTheListWaitsAsTheAdviceSaysAndThereIsNoCount() throws {
        let model = try ContractsSample.plain()
        var players = try #require(model.squad.book.current[.firstTeam])
        let index = try #require(players.firstIndex { $0.name == "Josh Lewis" })
        players[index].attributes[.consistency] = nil
        _ = model.squad.book.apply(ImportResult(grid: "test", players: players, warnings: [],
                                                money: model.squad.book.moneyStyle), to: .firstTeam)
        model.replan()
        guard case .failed = model.adviceState else {
            Issue.record("expected the advice to stop, got \(model.adviceState)")
            return
        }
        #expect(model.contractsSheet == .notReady(model.adviceState))
        #expect(model.contractsCount == nil)
    }

    // MARK: The pill

    @Test func theContractsPillCarriesTheCountAndNoOtherPillDoes() {
        #expect(AppModel.pillTitle(.contracts, count: 3) == "Contracts 3")
        #expect(AppModel.pillTitle(.contracts, count: nil) == "Contracts")
        #expect(AppModel.pillTitle(.squad, count: 3) == "Squad")
        #expect(AppModel.pillTitle(.removal, count: nil) == "Removal")
        #expect(AppModel.pillAccessibilityLabel(.contracts, count: 3) == "Contracts, 3 players")
        #expect(AppModel.pillAccessibilityLabel(.contracts, count: 1) == "Contracts, 1 player")
        #expect(AppModel.pillAccessibilityLabel(.contracts, count: nil) == "Contracts")
        #expect(AppModel.pillAccessibilityLabel(.scouting, count: 3) == "Scouting")
    }

    @Test func theSamplesCountIsOnItsPill() throws {
        let model = try ContractsSample.filled()
        let count = try #require(model.contractsCount)
        #expect(AppModel.pillTitle(.contracts, count: model.contractsCount) == "Contracts \(count)")
    }

    // MARK: The club's figures

    @Test func theClubsFiguresAreLabelledInTheSquadsPeriodAndReadInTheMoneyStyle() throws {
        let monthly = try ContractsSample.sheet(try ContractsSample.filled())
        #expect(monthly.limitRows.map(\.field) == WageLimitField.allCases)
        #expect(monthly.limitRows.map(\.label) == ["Wage budget, a month", "Wages spent, a month",
                                                   "Highest wage you can offer, a month"])
        #expect(monthly.limitRows.map(\.text) == ["130000", "118000", "9000"])
        #expect(monthly.limitRows.map(\.reading) == ["$130,000 a month", "$118,000 a month", "$9,000 a month"])
        #expect(monthly.limitsEnteredText == AdvisorText.enteredOn(SampleData.contractsDate))

        let model = try SampleData.model(repositoryRoot: Captures.repositoryRoot)
        model.setWageLimit(.wageBudget, text: "20000")
        let weekly = try ContractsSample.sheet(model)
        #expect(weekly.limitRows.map(\.label) == ["Wage budget, a week", "Wages spent, a week",
                                                  "Highest wage you can offer, a week"])
        let kept = try #require(model.contracts.limits.wageBudgetPerWeek)
        #expect(weekly.limitRows.map(\.text) == ["20000", "", ""])
        #expect(weekly.limitRows.map(\.reading) == [Display.wage(perWeek: kept, model.squad.book.moneyStyle), nil, nil])
        #expect(weekly.limitRows.first?.reading == "£20,000 a week")
        #expect(ContractsSample.listed(weekly).allSatisfy { $0.figureLabel == "The agent's figure, a week" })
    }

    @Test func withNoFigureTypedTheRowsAreBlankAndUndated() throws {
        let sheet = try ContractsSample.sheet(try ContractsSample.plain())
        #expect(sheet.limitRows.map(\.text) == ["", "", ""])
        #expect(sheet.limitRows.allSatisfy { $0.reading == nil })
        #expect(sheet.limitsEnteredText == nil)
    }

    // MARK: The sample and the navigation

    @Test func theSampleMakesASecondElevenPlayerOutOfContractAndListsHimUnderNoContract() throws {
        let model = try ContractsSample.plain()
        let sheet = try ContractsSample.sheet(model)
        let hughes = try ContractsSample.player(SampleData.contractsOutOfContractName, in: model)
        #expect(hughes.contractType == .outOfContract)
        let row = try #require(sheet.parts.last?.rows.first { $0.id == hughes.id })
        #expect(row.standingLine == "Second choice at right back.")
        #expect(row.detailsText == "Age 25 · D/WB R · CA 76 · PA 93 · no contract")
        #expect(row.timingLine == "He has no contract and can leave at any time.")
    }

    @Test func theNotRenewingPartStartsClosed() {
        #expect(Navigation().contractsDismissedOpen == false)
    }

    @Test func theButtonsSayWhoTheyAreForToAssistiveTechnology() {
        #expect(ContractsPresentation.notRenewingButton == "Not renewing")
        #expect(ContractsPresentation.notRenewingLabel("Evan Humphries") == "Not renewing Evan Humphries")
        #expect(ContractsPresentation.showAgainButton == "Show again")
        #expect(ContractsPresentation.showAgainLabel("Dejan Tetek") == "Show Dejan Tetek again")
    }
}
