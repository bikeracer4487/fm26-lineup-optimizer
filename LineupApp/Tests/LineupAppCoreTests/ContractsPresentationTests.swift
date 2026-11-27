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

    static func listed(_ sheet: ContractsSheet) -> [ContractRow] { sheet.rows }

    /// The engine's report for the sample, worked out by hand from what the model holds.
    static func report(_ model: AppModel) throws -> ContractsReport {
        let advice = try advice(model)
        return try Contracts.report(
            players: model.squad.book.allPlayers, ownClub: model.ownClub, marks: model.marks, removal: advice.removal,
            elevens: advice.elevens, depth: advice.depth, tactic: try #require(model.primaryTactic).tactic,
            dismissed: Set(model.contracts.dismissed.keys), wanted: Set(model.contracts.wanted.keys),
            today: model.settings.currentDate, catalog: model.catalog, profile: model.profile,
            parameters: model.planParameters)
    }

    /// The engine's sentences for an entry's reasons, the one that says to sign a replacement first apart from the
    /// rest.
    static func reasonLines(_ entry: ContractEntry) -> (reasons: [String], replaceFirst: String?) {
        let lines = AdvisorText.contractReasonLines(entry)
        return (lines.lines, lines.replaceFirst)
    }

    /// The first-team player the sample does not recommend renewing who is first choice at central attacking
    /// midfield, at 31, by the decline his age is expected to bring.
    static let notRecommendedName = "Ciaran O'Connor"
}

@MainActor @Suite struct ContractsPresentationTests {
    // MARK: Who is listed

    @Test func theSampleListsOnlyPlayersRunningDownWithTheEnginesIntro() throws {
        let model = try ContractsSample.filled()
        let sheet = try ContractsSample.sheet(model)
        let players = Dictionary(model.squad.book.allPlayers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        #expect(!sheet.rows.isEmpty && !sheet.notRecommended.isEmpty && !sheet.dismissed.isEmpty)
        for row in sheet.rows + sheet.notRecommended + sheet.dismissed {
            let player = try #require(players[row.id])
            #expect(Contracts.part(of: player, today: model.settings.currentDate, parameters: model.planParameters) != nil,
                    "\(row.name)")
        }
        // Every part has a player in the list, and they are not grouped by it.
        let parts = sheet.rows.compactMap { row in
            players[row.id].flatMap {
                Contracts.part(of: $0, today: model.settings.currentDate, parameters: model.planParameters)
            }
        }
        #expect(parts.count == sheet.rows.count)
        #expect(Set(parts) == Set(ContractPart.allCases))
        #expect(parts != parts.sorted { ContractPart.allCases.firstIndex(of: $0)! < ContractPart.allCases.firstIndex(of: $1)! })
        #expect(sheet.intro == AdvisorText.contractsIntro)
        #expect(sheet.ruleLine == AdvisorText.contractsRuleLine(model.planParameters))
        #expect(sheet.ruleLine.hasPrefix("A player is recommended when he would rate within 5% of the average"))
        #expect(sheet.emptyLine == nil)
        #expect(sheet.evidenceNote == AdvisorText.contractsEvidenceNote(model.planParameters.wageRangeRules.value))
    }

    @Test func theListIsInTheEnginesOrderWithEachRowsWorthLine() throws {
        let model = try ContractsSample.filled()
        let report = try ContractsSample.report(model)
        let sheet = try ContractsSample.sheet(model)
        #expect(sheet.rows.map(\.id) == report.listed.map(\.player))
        #expect(sheet.notRecommended.map(\.id) == report.notRecommended.map(\.player))
        #expect(sheet.dismissed.map(\.id) == report.dismissed.map(\.player))
        #expect(sheet.rows.map(\.standingLine) == report.listed.map(AdvisorText.standingLine))
        #expect(sheet.rows.map(\.timingLine) == report.listed.map(AdvisorText.timingLine))
        // The higher worth first.
        let shares = report.listed.compactMap { $0.worth?.share }
        #expect(shares.count == report.listed.count && shares == shares.sorted(by: >))
        // Each recommended row carries the engine's worth line and no reasons.
        for (row, entry) in zip(sheet.rows, report.listed) where entry.reasons.isEmpty {
            #expect(row.worthLine == entry.worth.map(AdvisorText.worthLine), "\(row.name)")
            #expect(row.reasonLines.isEmpty && row.replaceFirstText == nil && row.wantedLine == nil, "\(row.name)")
        }
        #expect(sheet.rows.first?.name == "Jack Thompson")
        #expect(sheet.rows.first?.worthLine == "Ability 109, could reach about 119 (this tool's estimate): that would rate 24.6% above the average of your first eleven by ability, at goalkeeper.")
    }

    @Test func theNotRecommendedRowsCarryTheirReasonsAndNoWageLines() throws {
        let model = try ContractsSample.filled()
        let report = try ContractsSample.report(model)
        let sheet = try ContractsSample.sheet(model)
        for (row, entry) in zip(sheet.notRecommended, report.notRecommended) {
            #expect(!entry.reasons.isEmpty)
            // The sentence that says to sign a replacement first stands apart, so it can be drawn as a caution.
            let lines = ContractsSample.reasonLines(entry)
            #expect(row.reasonLines == lines.reasons, "\(row.name)")
            #expect(row.replaceFirstText == lines.replaceFirst, "\(row.name)")
            #expect(row.standingLine == AdvisorText.standingLine(entry))
            #expect(!row.detailsText.isEmpty)
            #expect(row.worthLine == nil && row.wantedLine == nil && row.timingLine == nil && !row.timingIsCaution)
            #expect(row.guideLines.isEmpty && row.figureText.isEmpty && row.figureEnteredText == nil)
            #expect(row.cautionVerdictLine == nil && row.verdictLines.isEmpty)
        }
        let oConnor = try #require(sheet.notRecommended.first { $0.name == ContractsSample.notRecommendedName })
        #expect(oConnor.standingLine == "First choice at central attacking midfield.")
        #expect(oConnor.reasonLines == [
            "He is 31. This tool expects him to lose about 9 points of ability over the next two seasons, from 71 to about 62 (its own estimate: no test measures decline): that would rate 6.0% under the average of your first eleven, at central attacking midfield. Rates 0.4% above it today.",
        ])
        #expect(oConnor.replaceFirstText == "He is first choice at central attacking midfield: sign a replacement before he goes.")
        let khaleel = try #require(sheet.notRecommended.first { $0.name == "Rafiq Khaleel" })
        #expect(khaleel.reasonLines.first == "Player Removal advises ending his contract by agreement.")
        // A player not needed until he is replaced has no such sentence.
        #expect(sheet.notRecommended.contains { $0.replaceFirstText == nil })
    }

    @Test func theClosedLineCountsThem() throws {
        let model = try ContractsSample.filled()
        let sheet = try ContractsSample.sheet(model)
        #expect(sheet.notRecommended.count == 5)
        #expect(sheet.notRecommendedLine == "5 players not recommended for renewal")
        #expect(sheet.notRecommendedLine == AdvisorText.notRecommendedLine(sheet.notRecommended.count))
        // Setting one aside changes nothing: he is not recommended whatever the owner set aside.
        let oConnor = try #require(sheet.notRecommended.first { $0.name == ContractsSample.notRecommendedName })
        model.dismissContract(oConnor.id)
        #expect(try ContractsSample.sheet(model).notRecommendedLine == sheet.notRecommendedLine)
        // With every one of them renewed anyway there is no line.
        for row in try ContractsSample.sheet(model).notRecommended { model.renewAnyway(row.id) }
        let after = try ContractsSample.sheet(model)
        #expect(after.notRecommended.isEmpty && after.notRecommendedLine == nil)
    }

    @Test func aWantedRowSaysSoAndKeepsItsReasons() throws {
        let model = try ContractsSample.filled()
        let tetek = try ContractsSample.player(SampleData.contractsWantedName, in: model)
        let sheet = try ContractsSample.sheet(model)
        #expect(!sheet.notRecommended.contains { $0.id == tetek.id })
        let row = try #require(sheet.rows.first { $0.id == tetek.id })
        #expect(row.wantedLine == AdvisorText.listedAtYourChoice)
        #expect(row.reasonLines == ["Rates 5.3% under the average of your first eleven, at left defensive midfield."])
        // Renewed at the owner's choice he is not going, so no replacement is asked for, though his reasons carry one.
        #expect(row.replaceFirstText == nil)
        let entry = try #require(try ContractsSample.report(model).listed.first { $0.player == tetek.id })
        #expect(entry.reasons.contains(.replaceFirst(slot: .DM_R, why: .secondChoice)))
        // His worth is under the standard, so it is said once, among the reasons.
        #expect(row.worthLine == nil)
        // A full row: his timing, his range and the figure field.
        #expect(row.timingLine == "Other clubs can approach him from Sat 30 Dec.")
        #expect(!row.guideLines.isEmpty && row.figureLabel == "The agent's figure, a year")
        // Last, by his worth.
        #expect(sheet.rows.last?.id == tetek.id)

        // "Follow the advice" takes him back, with the same reasons.
        model.followAdvice(tetek.id)
        let back = try ContractsSample.sheet(model)
        #expect(!back.rows.contains { $0.id == tetek.id })
        let notRecommended = try #require(back.notRecommended.first { $0.id == tetek.id })
        #expect(notRecommended.reasonLines == row.reasonLines)
        // Not recommended, he keeps the sentence that says to sign a replacement first.
        #expect(notRecommended.replaceFirstText
                == "He is second choice at right defensive midfield: sign a replacement before he goes.")
        #expect(notRecommended.wantedLine == nil)

        // A player renewed anyway whose worth meets the standard keeps his worth line beside his reason.
        let humphries = try ContractsSample.player(SampleData.contractsFigureName, in: model)
        model.setMark(.toSell, for: humphries.id)
        model.renewAnyway(humphries.id)
        let marked = try #require(try ContractsSample.sheet(model).rows.first { $0.id == humphries.id })
        #expect(marked.wantedLine == AdvisorText.listedAtYourChoice)
        #expect(marked.reasonLines == ["You have marked him to sell."])
        #expect(marked.replaceFirstText == nil)
        #expect(marked.worthLine == "Ability 83, could reach about 95 (this tool's estimate): that would rate 6.2% above the average of your first eleven, at left back.")
    }

    /// Where a player out on loan is says the engine's standing line alone, with where he would stand.
    @Test func aRowsDetailsAreHisAgePositionsAndFactsAndTheStandingLineSaysWhereHeIsOutOnLoan() throws {
        let model = try ContractsSample.plain()
        let rows = ContractsSample.listed(try ContractsSample.sheet(model))
        let humphries = try #require(rows.first { $0.name == SampleData.contractsFigureName })
        #expect(humphries.detailsText == "Age 22 · D L · CA 83 · PA 95 · $39,228 a year · contract ends 30 Jun 2028")
        let johnson = try #require(rows.first { $0.name == "Darnell Johnson" })
        #expect(johnson.standingLine == "Out on loan at Merthyr; he would make the second eleven at right centre-back.")
        #expect(!johnson.detailsText.contains("Merthyr"))
        // Not being renewed: the same.
        model.dismissContract(johnson.id)
        let set = try #require(try ContractsSample.sheet(model).dismissed.first { $0.id == johnson.id })
        #expect(set.detailsText == johnson.detailsText && set.standingLine == johnson.standingLine)
        // Not recommended: the same.
        let clark = try #require(try ContractsSample.sheet(model).notRecommended.first { $0.name == "Ewan Clark" })
        #expect(clark.detailsText == "Age 24 · AM RL · CA 69 · PA 85 · $39,228 a year · contract ends 30 Jun 2028")
        #expect(clark.standingLine.hasPrefix("Out on loan at Hemel Hempstead; "))
        #expect(!clark.detailsText.contains("Hemel Hempstead"))
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
        #expect(row.guideLines.first?.hasPrefix("Most of the rest of your second eleven are paid ") == true)
        #expect(row.verdictLines.isEmpty && row.figureText.isEmpty && row.figureEnteredText == nil, "no figure typed")
    }

    @Test func aFigureAboveTheHighestWageIsFirstSaidToBeAboveIt() throws {
        let model = try ContractsSample.filled()
        let humphries = try ContractsSample.player(SampleData.contractsFigureName, in: model)
        let row = try #require(ContractsSample.listed(try ContractsSample.sheet(model)).first { $0.id == humphries.id })
        #expect(row.figureLabel == "The agent's figure, a year")
        #expect(row.figureText == "114,000")
        #expect(row.figureEnteredText == AdvisorText.enteredOn(SampleData.contractsDate))
        // The over-the-highest-wage sentence stands apart, for the caution style, and is not repeated in the rest.
        let highest = "The agent's figure is above the most you can offer one player, $108,000 a year."
        #expect(row.cautionVerdictLine == highest)
        #expect(!row.verdictLines.contains(highest))
        #expect(row.verdictLines.count == 3)
        // The guide the verdict is read against carries the typed limits.
        let ceiling = Display.wage(perWeek: WagePeriod.monthly.perWeek(130_000 * 0.027), model.squad.book.moneyStyle)
        #expect(row.verdictLines.contains("The agent's figure is above a backup's share of your wage budget, \(ceiling) (this tool's estimate)."))
        #expect(ceiling.hasSuffix(" a year"))
        #expect(row.guideLines.contains { $0.hasPrefix("The most you can offer one player is $108,000 a year") })
    }

    @Test func aFigureUnderTheHighestWageHasNoCautionLineAndKeepsEveryVerdict() throws {
        let model = try ContractsSample.filled()
        let humphries = try ContractsSample.player(SampleData.contractsFigureName, in: model)
        model.setAgentFigure(text: "36000", for: humphries.id)                      // $3,000 a month
        let row = try #require(ContractsSample.listed(try ContractsSample.sheet(model)).first { $0.id == humphries.id })
        #expect(row.cautionVerdictLine == nil)
        #expect(row.verdictLines.first == "The agent's figure is within what the rest of your second eleven are paid.")
        #expect(!row.verdictLines.contains { $0.contains("the most you can offer one player") })
    }

    @Test func onlyTheRowsOtherClubsCanApproachNowHaveTheirTimingAsACaution() throws {
        let model = try ContractsSample.filled()
        let report = try ContractsSample.report(model)
        let sheet = try ContractsSample.sheet(model)
        #expect(Set(report.listed.map(\.part)) == Set(ContractPart.allCases))
        for (row, entry) in zip(sheet.rows, report.listed) {
            #expect(row.timingIsCaution == (entry.part == .approachable), "\(row.name)")
            #expect(row.timingLine == AdvisorText.timingLine(entry))
        }
        #expect(!sheet.dismissed.isEmpty && sheet.dismissed.allSatisfy { !$0.timingIsCaution && $0.cautionVerdictLine == nil })
        #expect(!sheet.notRecommended.isEmpty && sheet.notRecommended.allSatisfy { !$0.timingIsCaution && $0.timingLine == nil })
    }

    @Test func aRowWithNoFigureHasNoVerdict() throws {
        let model = try ContractsSample.filled()
        let rows = ContractsSample.listed(try ContractsSample.sheet(model)).filter { $0.name != SampleData.contractsFigureName }
        #expect(!rows.isEmpty && rows.allSatisfy { $0.verdictLines.isEmpty && $0.cautionVerdictLine == nil
                                                    && $0.figureText.isEmpty })
    }

    // MARK: The players not being renewed

    @Test func aDismissedPlayerIsBehindTheNotRenewingLineWithHisFactsAndStandingOnly() throws {
        let model = try ContractsSample.filled()
        let sheet = try ContractsSample.sheet(model)
        let set = try ContractsSample.player(SampleData.contractsDismissedName, in: model)
        #expect(!ContractsSample.listed(sheet).contains { $0.id == set.id })
        #expect(sheet.dismissed.map(\.id) == [set.id])
        #expect(sheet.dismissedLine == "1 player you are not renewing")
        let row = try #require(sheet.dismissed.first)
        #expect(row.detailsText == "Age 22 · M/AM/ST RL · CA 69 · PA 80 · $33,432 a year · contract ends 30 Jun 2029")
        #expect(row.standingLine == "Second choice at right attacking midfield.")
        #expect(row.timingLine == nil && row.guideLines.isEmpty && row.figureText.isEmpty
                && row.figureEnteredText == nil && row.verdictLines.isEmpty)
        #expect(row.worthLine == nil && row.reasonLines.isEmpty && row.replaceFirstText == nil && row.wantedLine == nil)
        model.showContractAgain(set.id)
        let shown = try ContractsSample.sheet(model)
        #expect(shown.dismissed.isEmpty && shown.dismissedLine == nil)
        #expect(ContractsSample.listed(shown).contains { $0.id == set.id })
    }

    @Test func renewingAnywayAPlayerSetAsideListsHimAgain() throws {
        let model = try ContractsSample.filled()
        let tetek = try ContractsSample.player(SampleData.contractsWantedName, in: model)
        model.followAdvice(tetek.id)
        model.dismissContract(tetek.id)
        #expect(model.contracts.dismissed[tetek.id] != nil)
        // Not recommended whatever was set aside, so "Renew anyway" is offered and takes the setting aside away.
        #expect(try ContractsSample.sheet(model).notRecommended.contains { $0.id == tetek.id })
        model.renewAnyway(tetek.id)
        #expect(model.contracts.dismissed[tetek.id] == nil)
        #expect(try ContractsSample.sheet(model).rows.contains { $0.id == tetek.id && $0.wantedLine != nil })
    }

    // MARK: The count

    @Test func thePillCountsTheListOnly() throws {
        let model = try ContractsSample.filled()
        let sheet = try ContractsSample.sheet(model)
        // The players renewed anyway among them; not those not recommended, nor those set aside.
        #expect(model.contractsCount == sheet.rows.count)
        #expect(sheet.rows.contains { $0.wantedLine != nil })
        #expect(!sheet.notRecommended.isEmpty && !sheet.dismissed.isEmpty)
        // A mark to sell takes a player out of the list and puts him among those not recommended, saying so first.
        let marked = try #require(sheet.rows.first { $0.name == SampleData.contractsFigureName })
        model.setMark(.toSell, for: marked.id)
        #expect(model.contractsCount == sheet.rows.count - 1)
        let after = try ContractsSample.sheet(model)
        #expect(!after.rows.contains { $0.id == marked.id })
        #expect(after.notRecommended.first { $0.id == marked.id }?.reasonLines.first == "You have marked him to sell.")
        #expect(after.notRecommendedLine == AdvisorText.notRecommendedLine(sheet.notRecommended.count + 1))
        // "Renew anyway" puts one back in the count, and "Follow the advice" takes him out again.
        model.renewAnyway(marked.id)
        #expect(model.contractsCount == sheet.rows.count)
        model.followAdvice(marked.id)
        #expect(model.contractsCount == sheet.rows.count - 1)
    }

    @Test func theCountIsTheSheetsRowsAfterEachAction() throws {
        let model = try ContractsSample.filled()
        func rows() throws -> Int { try ContractsSample.sheet(model).rows.count }
        #expect(model.contractsCount == (try rows()))
        let notRecommended = try #require(try ContractsSample.sheet(model).notRecommended.first)
        model.renewAnyway(notRecommended.id)
        #expect(try ContractsSample.sheet(model).rows.contains { $0.id == notRecommended.id })
        #expect(model.contractsCount == (try rows()))
        let listed = try #require(try ContractsSample.sheet(model).rows.first)
        model.dismissContract(listed.id)
        #expect(try !ContractsSample.sheet(model).rows.contains { $0.id == listed.id })
        #expect(model.contractsCount == (try rows()))
    }

    @Test func withNobodyListedThePartsAreEmptyTheEnginesLineShowsAndThereIsNoCount() throws {
        let model = try ContractsSample.plain()
        for row in ContractsSample.listed(try ContractsSample.sheet(model)) { model.dismissContract(row.id) }
        let sheet = try ContractsSample.sheet(model)
        #expect(sheet.rows.isEmpty)
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
        #expect(model.notBeingRenewed.isEmpty)
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
                                                money: model.squad.book.money ?? .weeklyPounds), to: .firstTeam)
        model.replan()
        guard case .failed = model.adviceState else {
            Issue.record("expected the advice to stop, got \(model.adviceState)")
            return
        }
        #expect(model.contractsSheet == .notReady(model.adviceState))
        #expect(model.contractsCount == nil)
        #expect(model.notBeingRenewed.isEmpty)
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

    /// The owner's rule of 27 November 2026: the game shows these figures "p/a", so they are typed and shown by the
    /// year whatever period FMRTE pasted the squad's wages in, and each field shows its amount once, with commas.
    @Test func theClubsFiguresAreLabelledAndShownByTheYearWhateverPeriodFMRTEPasted() throws {
        let filled = try ContractsSample.filled()
        #expect(filled.squad.book.money?.period == .monthly, "the sample's squad was pasted by the month")
        let monthly = try ContractsSample.sheet(filled)
        #expect(monthly.limitRows.map(\.field) == WageLimitField.allCases)
        #expect(monthly.limitRows.map(\.label) == ["Wage budget, a year", "Wages spent, a year",
                                                   "Highest wage you can offer, a year"])
        #expect(monthly.limitRows.map(\.text) == ["1,560,000", "1,416,000", "108,000"])
        #expect(monthly.limitsEnteredText == AdvisorText.enteredOn(SampleData.contractsDate))

        let model = try SampleData.model(repositoryRoot: Captures.repositoryRoot)
        #expect(model.squad.book.money?.period == .weekly, "the standard sample's squads were pasted by the week")
        model.setWageLimit(.wageBudget, text: "1040000")
        let weekly = try ContractsSample.sheet(model)
        #expect(weekly.limitRows.map(\.label) == monthly.limitRows.map(\.label))
        #expect(model.contracts.limits.wageBudgetPerWeek == 20_000)
        #expect(weekly.limitRows.map(\.text) == ["1,040,000", "", ""])
        #expect(ContractsSample.listed(weekly).allSatisfy { $0.figureLabel == "The agent's figure, a year" })
    }

    /// A figure typed before the rule, by the month: it is kept by the week, so it shows as the same worth a year.
    @Test func aFigureKeptFromAMonthlyEntryShowsAsTheSameWorthAYear() throws {
        let model = try ContractsSample.plain()
        model.contracts.limits.wageBudgetPerWeek = WagePeriod.monthly.perWeek(241_757)
        let row = try #require(try ContractsSample.sheet(model).limitRows.first)
        #expect(row.text == "2,901,084")
        // What the field shows, typed back, keeps the same figure.
        let kept = model.contracts.limits
        model.setWageLimit(.wageBudget, text: row.text)
        #expect(try ContractsSample.sheet(model).limitRows.first?.text == "2,901,084")
        #expect(abs((model.contracts.limits.wageBudgetPerWeek ?? 0) - (kept.wageBudgetPerWeek ?? 0)) < 0.01)
    }

    @Test func withNoFigureTypedTheRowsAreBlankAndUndated() throws {
        let sheet = try ContractsSample.sheet(try ContractsSample.plain())
        #expect(sheet.limitRows.map(\.text) == ["", "", ""])
        #expect(sheet.limitsEnteredText == nil)
    }

    // MARK: The sample and the navigation

    @Test func theSampleMakesASecondElevenPlayerOutOfContractAndListsHim() throws {
        let model = try ContractsSample.plain()
        let sheet = try ContractsSample.sheet(model)
        let hughes = try ContractsSample.player(SampleData.contractsOutOfContractName, in: model)
        #expect(hughes.contractType == .outOfContract)
        let row = try #require(sheet.rows.first { $0.id == hughes.id })
        #expect(row.standingLine == "Second choice at right back.")
        #expect(row.detailsText == "Age 25 · D/WB R · CA 76 · PA 93 · no contract")
        #expect(row.timingLine == "He has no contract and can leave at any time.")
        #expect(row.worthLine == "Rates 0.8% above the average of your first eleven, at right back.")
    }

    /// The names the sample's own check holds it to.
    @Test func theSamplesNamesAreAPlayerSetAsideAPlayerRenewedAnywayAndAPlayerWithAFigure() throws {
        for model in [try ContractsSample.plain(), try ContractsSample.filled()] {
            let sheet = try ContractsSample.sheet(model)
            let set = try ContractsSample.player(SampleData.contractsDismissedName, in: model)
            let wanted = try ContractsSample.player(SampleData.contractsWantedName, in: model)
            let figure = try ContractsSample.player(SampleData.contractsFigureName, in: model)
            let report = try ContractsSample.report(model)
            // The one set aside and the one with a figure are players the tool recommends.
            #expect(report.dismissed.first { $0.player == set.id }?.reasons == [])
            #expect(report.listed.first { $0.player == figure.id }?.reasons == [])
            // The one renewed anyway is one it does not.
            #expect(report.listed.first { $0.player == wanted.id }?.isWanted == true)
            #expect(model.contracts.wanted[wanted.id] == SampleData.contractsDate)
            #expect(sheet.rows.map(\.name) == [
                "Jack Thompson", "Mark Tomlinson", "Laolu Omobolaji", "Samuel Onyekachukwu", "Josh Lewis", "Deago Nelson",
                "Kai Payne", "Evan Humphries", "Kieran Petrie", "Iestyn Hughes", "Zack Clarke", "Darnell Johnson",
                "Christian N'Guessan", "Dejan Tetek",
            ])
            #expect(sheet.notRecommended.map(\.name) == [
                "Ciaran O'Connor", "Rafiq Khaleel", "Ewan Clark", "Ayman Benarous", "Ruban Khan",
            ])
            #expect(sheet.dismissed.map(\.name) == ["Sammy Henia-Kamau"])
        }
    }

    @Test func theNotRenewingAndNotRecommendedPartsStartClosed() {
        #expect(Navigation().contractsDismissedOpen == false)
        #expect(Navigation().contractsNotRecommendedOpen == false)
    }

    @Test func theButtonsSayWhoTheyAreForToAssistiveTechnology() {
        #expect(ContractsPresentation.notRenewingButton == "Not renewing")
        #expect(ContractsPresentation.notRenewingLabel("Evan Humphries") == "Not renewing Evan Humphries")
        #expect(ContractsPresentation.showAgainButton == "Show again")
        #expect(ContractsPresentation.showAgainLabel("Dejan Tetek") == "Show Dejan Tetek again")
        #expect(ContractsPresentation.renewAnywayButton == "Renew anyway")
        #expect(ContractsPresentation.renewAnywayLabel("Dejan Tetek") == "Renew Dejan Tetek anyway")
        #expect(ContractsPresentation.followAdviceButton == "Follow the advice")
        #expect(ContractsPresentation.followAdviceLabel("Dejan Tetek") == "Follow the advice on Dejan Tetek")
        #expect(ContractsPresentation.notRecommendedHeading == "Not recommended for renewal")
    }
}
