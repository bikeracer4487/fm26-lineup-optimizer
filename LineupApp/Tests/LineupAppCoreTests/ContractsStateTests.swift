import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

/// What the app keeps for the Contracts screen: the club's wage figures, the agents' figures and the players set aside.
@MainActor @Suite struct ContractsStateTests {
    private static let monthsLeftCell = 16

    private func rows() throws -> [[String]] {
        try Captures.firstTeam.split(whereSeparator: \.isNewline)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
    }

    private func paste(_ rows: [[String]]) -> String {
        rows.map { $0.joined(separator: "\t") }.joined(separator: "\n") + "\n"
    }

    private func name(onRow index: Int) throws -> String {
        try rows()[index][2].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    private func id(of name: String, _ model: AppModel) throws -> PlayerID {
        try #require(model.players.first { $0.name == name }).id
    }

    /// The first team imported, the clock stopped.
    private func ready() throws -> TestModel {
        let t = try TestModel()
        try t.importFirstTeam()
        t.input.tick = 0
        t.input.uptime = 1_000
        return t
    }

    /// The first team imported, the club named and the sample 4-2-3-1 its primary tactic, so the list is ready; the clock
    /// stopped.
    private func listing() throws -> TestModel {
        let t = try ready()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        let url = Captures.repositoryRoot
            .appendingPathComponent("LineupEngine/Tests/LineupEngineTests/Fixtures/tactics/sample-4231.json")
        let tactic = try JSONDecoder().decode(Tactic.self, from: Data(contentsOf: url))
        let id = t.model.addTactic(named: tactic.name)
        t.model.update(StoredTactic(id: id, tactic: tactic))
        return t
    }

    /// The row in the paste of a player the tool does not recommend renewing: Matty Taylor, 36, in his last year.
    private static let notRecommendedRow = 5
    /// The row of one it recommends: Deago Nelson, 22.
    private static let recommendedRow = 16

    private func sheet(_ model: AppModel) throws -> ContractsSheet {
        guard case .ready(let sheet) = model.contractsSheet else {
            Issue.record("expected a list, got \(model.contractsSheet)")
            throw Unlisted()
        }
        return sheet
    }

    /// The first team pasted in dollars by the month, the clock stopped.
    private func monthly() throws -> TestModel {
        let t = try TestModel()
        try t.importFirstTeamInDollarsMonthly()
        t.input.tick = 0
        t.input.uptime = 1_000
        return t
    }

    private func advance(_ t: TestModel) {
        t.input.uptime += AppModel.contractsActionInterval + 0.1
    }

    /// Every file in the model's directory but the contracts file, by name and contents.
    private func others(_ t: TestModel) throws -> [String: Data] {
        let urls = try FileManager.default.contentsOfDirectory(at: t.directory, includingPropertiesForKeys: nil)
        return try Dictionary(uniqueKeysWithValues: urls.filter { $0.lastPathComponent != "contracts.json" }
            .map { ($0.lastPathComponent, try Data(contentsOf: $0)) })
    }

    private func reimportFirstTeam(_ t: TestModel, changing edit: (inout [[String]]) -> Void) throws {
        var rows = try rows()
        edit(&rows)
        t.importSquad(.firstTeam, paste: paste(rows), grids: try Captures.firstTeamGrids)
    }

    // MARK: The club's figures

    /// Typed for a year, as the game shows it (27 November 2026), whatever period FMRTE pasted the squad in.
    @Test func aTypedLimitIsReadAsAYearsAndKeptByTheWeekWithTodaysDay() throws {
        let t = try monthly()
        let model = t.model
        #expect(model.squad.book.money?.period == .monthly)
        model.setWageLimit(.wageBudget, text: "192000")
        #expect(model.contracts.limits.wageBudgetPerWeek == WagePeriod.yearly.perWeek(192_000))
        #expect(model.contracts.limits.wageBudgetPerWeek == WagePeriod.monthly.perWeek(16_000))
        #expect(model.contracts.limitsEntered == model.settings.currentDate)
        #expect(t.reopened().contracts == model.contracts)
    }

    @Test func aLaterChangeOfPeriodLeavesTheKeptFigureAlone() throws {
        let t = try monthly()
        t.model.setWageLimit(.wagesSpent, text: "9000")
        let kept = t.model.contracts.limits.wagesSpentPerWeek
        try t.importFirstTeam()                                                    // back to weekly pounds
        #expect(t.model.squad.book.money?.period == .weekly)
        #expect(t.model.squad.book.moneyStyle.period == .yearly)
        #expect(t.model.contracts.limits.wagesSpentPerWeek == kept)
        // It was typed for a year and is still read as that.
        t.model.setWageLimit(.wagesSpent, text: "9000")
        #expect(t.model.contracts.limits.wagesSpentPerWeek == kept)
    }

    @Test func blankingTheOnlyFigureClearsItAndTheDay() throws {
        let t = try ready()
        t.model.setWageLimit(.highestWage, text: "500")
        #expect(t.model.contracts.limitsEntered != nil)
        t.model.setWageLimit(.highestWage, text: "")
        #expect(t.model.contracts.limits == .none)
        #expect(t.model.contracts.limitsEntered == nil)
    }

    @Test func blankingOneOfTwoKeepsTheDay() throws {
        let t = try ready()
        t.model.setWageLimit(.highestWage, text: "500")
        t.model.setWageLimit(.wageBudget, text: "468000")
        t.model.setWageLimit(.highestWage, text: "")
        #expect(t.model.contracts.limits.wageBudgetPerWeek == 9_000)
        #expect(t.model.contracts.limitsEntered == t.model.settings.currentDate)
    }

    @Test func onlyDigitsAreReadAndZeroIsAValue() throws {
        let t = try ready()
        t.model.setWageLimit(.wageBudget, text: "64abc168")
        #expect(t.model.contracts.limits.wageBudgetPerWeek == 1_234)
        t.model.setWageLimit(.wagesSpent, text: "0")
        #expect(t.model.contracts.limits.wagesSpentPerWeek == 0)
    }

    // MARK: The agents' figures

    @Test func anAgentsFigureIsKeptForAHeldPlayerAndRemovedWhenBlank() throws {
        let t = try ready()
        let held = try id(of: try name(onRow: 0), t.model)
        t.model.setAgentFigure(text: "46,800", for: held)
        #expect(t.model.contracts.figures[held] == AgentFigure(perWeek: 900, entered: t.model.settings.currentDate))
        #expect(t.reopened().contracts.figures[held]?.perWeek == 900)
        t.model.setAgentFigure(text: "", for: held)
        #expect(t.model.contracts.figures.isEmpty)
    }

    @Test func aFigureForAPlayerNobodyHoldsChangesNothingAndSavesNothing() throws {
        let t = try ready()
        let before = t.model.contracts
        let file = t.directory.appendingPathComponent("contracts.json")
        let bytes = try Data(contentsOf: file)
        try FileManager.default.removeItem(at: file)
        t.model.setAgentFigure(text: "900", for: PlayerID(key: "fmrte:nobody"))
        #expect(t.model.contracts == before)
        #expect(!FileManager.default.fileExists(atPath: file.path))
        try bytes.write(to: file)
    }

    // MARK: Setting a player aside

    @Test func aSecondActionInsideHalfASecondIsIgnoredAndLaterOneIsTaken() throws {
        let t = try ready()
        let held = try id(of: try name(onRow: 0), t.model)
        t.model.dismissContract(held)
        #expect(t.model.contracts.dismissed[held] == t.model.settings.currentDate)
        t.input.uptime += AppModel.contractsActionInterval / 2
        t.model.showContractAgain(held)
        #expect(t.model.contracts.dismissed[held] != nil)
        t.input.uptime += AppModel.contractsActionInterval * 0.6
        t.model.showContractAgain(held)
        #expect(t.model.contracts.dismissed.isEmpty)
    }

    @Test func dismissingTwiceOrShowingOneNotSetAsideDoesNothing() throws {
        let t = try ready()
        let held = try id(of: try name(onRow: 0), t.model)
        t.model.showContractAgain(held)
        #expect(t.model.contracts == ContractsState())
        t.model.dismissContract(held)
        let day = t.model.contracts.dismissed[held]
        advance(t)
        t.model.settings.currentDate = t.model.settings.currentDate.adding(days: 3)
        t.model.dismissContract(held)
        #expect(t.model.contracts.dismissed[held] == day)
    }

    // MARK: Renewing anyway

    @Test func renewAnywayIsSavedWithTodaysDayAndClearsADismissal() throws {
        let t = try listing()
        let taylor = try id(of: try name(onRow: Self.notRecommendedRow), t.model)
        #expect(try sheet(t.model).notRecommended.contains { $0.id == taylor })
        t.model.dismissContract(taylor)
        #expect(t.model.contracts.dismissed[taylor] != nil)
        advance(t)
        t.model.renewAnyway(taylor)
        #expect(t.model.contracts.wanted == [taylor: t.model.settings.currentDate])
        #expect(t.model.contracts.dismissed[taylor] == nil)
        #expect(t.reopened().contracts.wanted == [taylor: t.model.settings.currentDate])
        let row = try #require(try sheet(t.model).rows.first { $0.id == taylor })
        #expect(row.wantedLine == AdvisorText.listedAtYourChoice)
    }

    @Test func renewAnywayDoesNothingForAPlayerTheToolRecommendsOrNobodyHolds() throws {
        let t = try listing()
        let nelson = try id(of: try name(onRow: Self.recommendedRow), t.model)
        #expect(try sheet(t.model).rows.contains { $0.id == nelson })
        t.model.renewAnyway(nelson)
        t.model.renewAnyway(PlayerID(key: "fmrte:nobody"))
        #expect(t.model.contracts == ContractsState())
        // Neither started the clock.
        let taylor = try id(of: try name(onRow: Self.notRecommendedRow), t.model)
        t.model.renewAnyway(taylor)
        #expect(t.model.contracts.wanted[taylor] != nil)
        // Nor does it do anything while the list is not ready.
        let plain = try ready()
        plain.model.renewAnyway(try id(of: try name(onRow: Self.notRecommendedRow), plain.model))
        #expect(plain.model.contracts == ContractsState())
    }

    @Test func followAdviceRemovesIt() throws {
        let t = try listing()
        let taylor = try id(of: try name(onRow: Self.notRecommendedRow), t.model)
        t.model.renewAnyway(taylor)
        advance(t)
        t.model.followAdvice(taylor)
        #expect(t.model.contracts.wanted.isEmpty)
        #expect(t.reopened().contracts.wanted.isEmpty)
        #expect(try sheet(t.model).notRecommended.contains { $0.id == taylor })
        // Nothing for a player not chosen, and it does not start the clock.
        let nelson = try id(of: try name(onRow: Self.recommendedRow), t.model)
        advance(t)
        t.model.followAdvice(nelson)
        t.model.renewAnyway(taylor)
        #expect(t.model.contracts.wanted[taylor] != nil)
    }

    @Test func theFourActionsShareOneClock() throws {
        let t = try listing()
        let taylor = try id(of: try name(onRow: Self.notRecommendedRow), t.model)
        let nelson = try id(of: try name(onRow: Self.recommendedRow), t.model)
        t.model.dismissContract(nelson)
        #expect(t.model.contracts.dismissed[nelson] != nil)
        t.input.uptime += AppModel.contractsActionInterval / 2
        t.model.renewAnyway(taylor)
        #expect(t.model.contracts.wanted.isEmpty, "inside the interval of a dismissal")
        t.input.uptime += AppModel.contractsActionInterval * 0.6
        t.model.renewAnyway(taylor)
        #expect(t.model.contracts.wanted[taylor] != nil)
        t.input.uptime += AppModel.contractsActionInterval / 2
        t.model.showContractAgain(nelson)
        #expect(t.model.contracts.dismissed[nelson] != nil, "inside the interval of a renewal")
        t.model.followAdvice(taylor)
        #expect(t.model.contracts.wanted[taylor] != nil)
        t.input.uptime += AppModel.contractsActionInterval * 0.6
        t.model.followAdvice(taylor)
        #expect(t.model.contracts.wanted.isEmpty)
        t.input.uptime += AppModel.contractsActionInterval / 2
        t.model.dismissContract(taylor)
        #expect(t.model.contracts.dismissed[taylor] == nil, "inside the interval of following the advice")
    }

    @Test func everyActionWritesTheContractsFileAndNoOtherAndDoesNotPlan() throws {
        let t = try listing()
        let held = try id(of: try name(onRow: 0), t.model)
        let taylor = try id(of: try name(onRow: Self.notRecommendedRow), t.model)
        let planned = t.model.timesPlanned
        let generation = t.model.adviceGeneration
        let state = t.model.planState
        let steps: [() -> Void] = [
            { t.model.setWageLimit(.wageBudget, text: "9000") },
            { t.model.setAgentFigure(text: "700", for: held) },
            { t.model.dismissContract(held) },
            { t.model.showContractAgain(held) },
            { t.model.renewAnyway(taylor) },
            { t.model.followAdvice(taylor) },
        ]
        for step in steps {
            let before = try others(t)
            let saved = try? Data(contentsOf: t.directory.appendingPathComponent("contracts.json"))
            advance(t)
            step()
            #expect(try others(t) == before)
            #expect(try Data(contentsOf: t.directory.appendingPathComponent("contracts.json")) != saved)
        }
        #expect(t.model.timesPlanned == planned)
        #expect(t.model.adviceGeneration == generation)
        #expect(t.model.planState == state)
    }

    // MARK: At an import

    /// The row and name of a player the list would show (a contract in its last year or less).
    private func listed(_ t: TestModel) throws -> (row: Int, name: String) {
        let parameters = t.model.planParameters
        let today = t.model.settings.currentDate
        for index in try rows().indices {
            let player = try #require(t.model.players.first { $0.name == (try? name(onRow: index)) })
            if Contracts.part(of: player, today: today, parameters: parameters) != nil { return (index, player.name) }
        }
        throw Unlisted()
    }
    private struct Unlisted: Error {}

    @Test func aRenewedContractDropsTheDismissalAndTheFigure() throws {
        let t = try ready()
        let (row, who) = try listed(t)
        let key = try id(of: who, t.model)
        t.model.dismissContract(key)
        t.model.setAgentFigure(text: "900", for: key)
        try reimportFirstTeam(t) { $0[row][Self.monthsLeftCell] = "\"40\"" }
        #expect(t.model.contracts.dismissed[key] == nil)
        #expect(t.model.contracts.figures[key] == nil)
        #expect(t.reopened().contracts.dismissed.isEmpty)
    }

    @Test func aContractStillRunningDownKeepsBoth() throws {
        let t = try ready()
        let (_, who) = try listed(t)
        let key = try id(of: who, t.model)
        t.model.dismissContract(key)
        t.model.setAgentFigure(text: "900", for: key)
        try t.importFirstTeam()
        #expect(t.model.contracts.dismissed[key] != nil)
        #expect(t.model.contracts.figures[key] != nil)
    }

    @Test func aPlayerMissingFromOneSquadIsDroppedOnlyOnceEverySquadHasBeenImportedWithoutHim() throws {
        let t = try ready()
        try t.importU21()
        let key = try id(of: try name(onRow: 0), t.model)
        t.model.dismissContract(key)
        t.model.setAgentFigure(text: "900", for: key)
        try reimportFirstTeam(t) { $0.remove(at: 0) }
        #expect(t.model.contracts.dismissed[key] != nil)            // the U21s have not been imported since
        try t.importU21()
        #expect(t.model.contracts.dismissed[key] == nil)
        #expect(t.model.contracts.figures[key] == nil)
    }

    @Test func aWantedEntryIsDroppedAtAnImportOnceHeIsRenewedOrGone() throws {
        let t = try listing()
        try t.importU21()
        let row = Self.notRecommendedRow
        let taylor = try id(of: try name(onRow: row), t.model)
        t.model.renewAnyway(taylor)
        try t.importFirstTeam()
        #expect(t.model.contracts.wanted[taylor] != nil, "still in his last year")
        try reimportFirstTeam(t) { $0[row][Self.monthsLeftCell] = "\"40\"" }
        #expect(t.model.contracts.wanted[taylor] == nil, "renewed")
        #expect(t.reopened().contracts.wanted.isEmpty)

        // Gone: once every squad held has been imported without him.
        try t.importFirstTeam()
        advance(t)
        t.model.renewAnyway(taylor)
        #expect(t.model.contracts.wanted[taylor] != nil)
        try reimportFirstTeam(t) { $0.remove(at: row) }
        #expect(t.model.contracts.wanted[taylor] != nil, "the U21s have not been imported since")
        try t.importU21()
        #expect(t.model.contracts.wanted[taylor] == nil)
    }

    @Test func aPlayerWithNoContractSurvivesAnImport() throws {
        let t = try ready()
        let who = try name(onRow: 1)
        try reimportFirstTeam(t) { $0[1][Self.monthsLeftCell] = "\"-1\"" }
        let key = try id(of: who, t.model)
        let player = try #require(t.model.players.first { $0.id == key })
        #expect(Contracts.part(of: player, today: t.model.settings.currentDate, parameters: t.model.planParameters) == .noContract)
        t.model.dismissContract(key)
        t.model.setAgentFigure(text: "900", for: key)
        try reimportFirstTeam(t) { $0[1][Self.monthsLeftCell] = "\"-1\"" }
        #expect(t.model.contracts.dismissed[key] != nil)
        #expect(t.model.contracts.figures[key] != nil)
    }

    // MARK: The file

    @Test func savedStateWithoutTheFileOpensWithNoNoticeAndNothingEntered() throws {
        let t = try ready()
        try FileManager.default.removeItem(at: t.directory.appendingPathComponent("contracts.json"))
        let reopened = t.reopened()
        #expect(reopened.contracts == ContractsState())
        #expect(!reopened.notices.contains { $0.text.contains("contract figures") })
    }

    @Test func aFileWithKeysMissingReadsAsTheDefaults() throws {
        let t = try ready()
        try Data("{\"version\":1,\"value\":{\"limits\":{\"wageBudgetPerWeek\":9000}}}".utf8)
            .write(to: t.directory.appendingPathComponent("contracts.json"))
        let reopened = t.reopened()
        #expect(reopened.contracts.limits.wageBudgetPerWeek == 9_000)
        #expect(reopened.contracts.dismissed.isEmpty)
        #expect(reopened.contracts.limitsEntered == nil)
    }

    @Test func aFileFromBeforeWantedOpensWithNoNoticeAndNobodyWanted() throws {
        let t = try ready()
        let held = try id(of: try name(onRow: 0), t.model)
        let file = "{\"version\":1,\"value\":{\"limits\":{},\"dismissed\":{\"\(held.key)\":\"2026-11-13\"},\"figures\":{}}}"
        try Data(file.utf8).write(to: t.directory.appendingPathComponent("contracts.json"))
        let reopened = t.reopened()
        #expect(reopened.contracts.wanted.isEmpty)
        #expect(reopened.contracts.dismissed == [held: Day(iso: "2026-11-13")!])
        #expect(!reopened.notices.contains { $0.text.contains("contract figures") })
    }

    @Test func aCorruptFileGivesANoticeAndIsKeptAside() throws {
        let t = try ready()
        try Data("not json".utf8).write(to: t.directory.appendingPathComponent("contracts.json"))
        let reopened = t.reopened()
        #expect(reopened.contracts == ContractsState())
        #expect(reopened.notices.contains { $0.text.contains("our contract figures") })
        let files = try FileManager.default.contentsOfDirectory(atPath: t.directory.path)
        #expect(files.contains { $0.hasPrefix("contracts") && $0 != "contracts.json" })
    }
}
