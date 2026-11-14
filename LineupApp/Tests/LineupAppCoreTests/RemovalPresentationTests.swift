import Foundation
import Testing
@testable import LineupEngine
@testable import LineupAppCore

/// The Player Removal screen: a row for each player of the club's own in the engine's order, the figures over them, the
/// filter, which rows are open, and the loans to the club, all in the engine's words.
@MainActor @Suite struct RemovalPresentationTests {
    private func advice(_ key: String, name: String, level: RemovalLevel = .high, action: RemovalAction = .sell,
                        score: Int = 60, reasons: [RemovalReason] = [RemovalReason(text: "In neither eleven", points: 25)],
                        release: Int? = 26_000, mutual: Int? = 14_300, basis: Evidence = .derived) -> RemovalAdvice {
        RemovalAdvice(player: PlayerID(key: key), name: name, level: level, action: action, score: score, reasons: reasons,
                      tier: nil, isProspect: false, isFalseProspect: false, isMentor: false, releaseCost: release,
                      mutualCost: mutual, basis: basis)
    }

    private func loan(_ key: String, name: String, verdict: LoanVerdict = .keepToEnd, score: Int = 10,
                      reasons: [RemovalReason] = [RemovalReason(text: "In the first eleven at left back", points: -30)],
                      basis: Evidence = .carriedOverFM26) -> LoanReview {
        LoanReview(player: PlayerID(key: key), name: name, verdict: verdict, score: score, reasons: reasons, basis: basis)
    }

    private func report(_ advice: [RemovalAdvice], loans: [LoanReview] = [], wages: Int = 600,
                        average: Double? = 61.6) -> RemovalReport {
        RemovalReport(advice: advice, loans: loans, weeklyWagesAtStake: wages, squadAverageAbility: average,
                      advisedToLeave: [])
    }

    /// One row at each level, in the engine's order.
    private var everyLevel: [RemovalAdvice] {
        [advice("c", name: "Critical One", level: .critical, action: .release, score: 120),
         advice("h", name: "High One", level: .high, action: .sell, score: 80),
         advice("m", name: "Medium One", level: .medium, action: .monitor, score: 40),
         advice("k", name: "Keep One", level: .keep, action: .keep, score: -10),
         advice("k2", name: "Keep Two", level: .keep, action: .keep, score: -30)]
    }

    // MARK: Stamps

    @Test func eachLevelsStampHasTheEnginesWordAndItsColour() {
        #expect(RemovalPresentation.stamp(.critical) == StatusStamp(text: "Critical", tone: .red))
        #expect(RemovalPresentation.stamp(.high) == StatusStamp(text: "High", tone: .amber))
        #expect(RemovalPresentation.stamp(.medium) == StatusStamp(text: "Medium", tone: .ink))
        #expect(RemovalPresentation.stamp(.keep) == StatusStamp(text: "Keep", tone: .muted))
        #expect(RemovalLevel.allCases.map { RemovalPresentation.stamp($0).text } == RemovalLevel.allCases.map(AdvisorText.name))
    }

    @Test func eachVerdictsStampHasTheEnginesWordAndItsColour() {
        #expect(RemovalPresentation.stamp(.endEarly) == StatusStamp(text: "End early", tone: .red))
        #expect(RemovalPresentation.stamp(.doNotExtend) == StatusStamp(text: "Do not extend", tone: .amber))
        #expect(RemovalPresentation.stamp(.keepToEnd) == StatusStamp(text: "Keep to the end", tone: .muted))
        #expect(RemovalPresentation.stamp(.makePermanent) == StatusStamp(text: "Make permanent", tone: .ink))
        #expect(LoanVerdict.allCases.map { RemovalPresentation.stamp($0).text } == LoanVerdict.allCases.map(AdvisorText.name))
    }

    @Test func aMutedStampDoesNotSayHeIsOut() {
        #expect(!StatusStamp(text: "Keep", tone: .muted).isOut)
    }

    // MARK: Points

    @Test func pointsAgainstHimAreRedWithAPlus() {
        let line = PointedReason(RemovalReason(text: "In neither eleven", points: 25))
        #expect(line == PointedReason(text: "In neither eleven", pointsText: "+25", tone: .red))
    }

    @Test func pointsForHimAreGreenWithATrueMinus() {
        let line = PointedReason(RemovalReason(text: "A model professional for younger players", points: -40))
        #expect(line == PointedReason(text: "A model professional for younger players", pointsText: "\u{2212}40", tone: .green))
    }

    @Test func noPointsAreMuted() {
        let line = PointedReason(RemovalReason(text: "Contract type Youth is not one this tool reads", points: 0))
        #expect(line.pointsText == "0")
        #expect(line.tone == .muted)
    }

    @Test func pointsAreTheEnginesText() {
        for points in [-15, 0, 7] {
            let reason = RemovalReason(text: "R", points: points)
            #expect(PointedReason(reason).pointsText == AdvisorText.points(of: reason))
        }
    }

    // MARK: Rows

    @Test func aRowHasEveryFigureInTheEnginesWords() throws {
        let given = advice("p", name: "Josh Ashby", level: .high, action: .sell, score: 85,
                           reasons: [RemovalReason(text: "In neither eleven", points: 25),
                                     RemovalReason(text: "Aged 33", points: 60)])
        let sheet = RemovalPresentation.sheet(report([given]), squads: [PlayerID(key: "p"): .firstTeam],
                                              ages: [PlayerID(key: "p"): 33])
        let row = try #require(sheet.rows.first)
        #expect(row.id == PlayerID(key: "p"))
        #expect(row.name == "Josh Ashby")
        #expect(row.level == .high)
        #expect(row.stamp == StatusStamp(text: "High", tone: .amber))
        #expect(row.actionText == "Sell")
        #expect(row.squadText == "First team")
        #expect(row.ageText == "33")
        #expect(row.scoreText == "85")
        #expect(row.costsText == "Releasing him costs £26,000; a mutual termination about £14,300")
        #expect(row.costsText == AdvisorText.costs(of: given))
        #expect(row.reasons == [PointedReason(text: "In neither eleven", pointsText: "+25", tone: .red),
                                PointedReason(text: "Aged 33", pointsText: "+60", tone: .red)])
        #expect(row.whyText == "Selling is the way left: nothing cheaper applies")
        #expect(row.whyText == AdvisorText.why(.sell, for: given))
        #expect(row.noteText == "(this tool's estimate)")
    }

    @Test func aNegativeScoreHasATrueMinus() throws {
        let sheet = RemovalPresentation.sheet(report([advice("p", name: "P", level: .keep, action: .keep, score: -45)]),
                                              squads: [:], ages: [:])
        #expect(try #require(sheet.rows.first).scoreText == "\u{2212}45")
    }

    @Test func aRowWithFM27EvidenceHasNoNote() throws {
        let sheet = RemovalPresentation.sheet(report([advice("p", name: "P", basis: .fm27Measured)]), squads: [:], ages: [:])
        #expect(try #require(sheet.rows.first).noteText == nil)
    }

    @Test func aPlayerNotInTheSquadBookHasNoSquadOrAge() throws {
        let sheet = RemovalPresentation.sheet(report([advice("gone", name: "Gone")]),
                                              squads: [PlayerID(key: "other"): .u21], ages: [PlayerID(key: "other"): 19])
        let row = try #require(sheet.rows.first)
        #expect(row.squadText == nil)
        #expect(row.ageText == nil)
    }

    @Test func rowsKeepTheEnginesOrder() {
        let sheet = RemovalPresentation.sheet(report(everyLevel), squads: [:], ages: [:])
        #expect(sheet.rows.map(\.name) == ["Critical One", "High One", "Medium One", "Keep One", "Keep Two"])
    }

    @Test func aRowIsSpokenWithItsStampActionNameAndFigures() throws {
        let sheet = RemovalPresentation.sheet(report([advice("p", name: "Josh Ashby", score: 85)]),
                                              squads: [PlayerID(key: "p"): .u21], ages: [PlayerID(key: "p"): 19])
        let row = try #require(sheet.rows.first)
        #expect(row.spokenText == "High, Sell, Josh Ashby, U21s, Age 19, Score 85, "
                + "Releasing him costs £26,000; a mutual termination about £14,300")
    }

    // MARK: Open and closed

    @Test func criticalAndHighRowsOpenByDefaultAndMediumAndKeepRowsDoNot() {
        let rows = RemovalPresentation.sheet(report(everyLevel), squads: [:], ages: [:]).rows
        let disclosure = RemovalDisclosure()
        #expect(rows.map(disclosure.isOpen) == [true, true, false, false, false])
        #expect(rows.map(\.opensByDefault) == [true, true, false, false, false])
    }

    @Test func aClickClosesAnOpenRowAndOpensAClosedOne() {
        let rows = RemovalPresentation.sheet(report(everyLevel), squads: [:], ages: [:]).rows
        var disclosure = RemovalDisclosure()
        disclosure.toggle(rows[0])
        disclosure.toggle(rows[2])
        #expect(rows.map(disclosure.isOpen) == [false, true, true, false, false])
        disclosure.toggle(rows[0])
        disclosure.toggle(rows[2])
        #expect(rows.map(disclosure.isOpen) == [true, true, false, false, false])
        #expect(disclosure == RemovalDisclosure())
    }

    @Test func theOwnersChoiceFollowsThePlayerNotHisPlace() {
        var disclosure = RemovalDisclosure()
        let first = RemovalPresentation.sheet(report(everyLevel), squads: [:], ages: [:]).rows
        disclosure.toggle(first[3])
        // Re-ordered advice: the same player is still open, and nobody else is.
        let again = RemovalPresentation.sheet(report(everyLevel.reversed()), squads: [:], ages: [:]).rows
        #expect(again.filter(disclosure.isOpen).map(\.name) == ["Keep One", "High One", "Critical One"])
    }

    @Test func theOwnersChoiceHoldsOnlyAtTheLevelItWasMadeAt() {
        func rows(_ level: RemovalLevel) -> [RemovalRow] {
            RemovalPresentation.sheet(report([advice("p", name: "Josh Ashby", level: level),
                                              advice("q", name: "Ewan Clark", level: .medium)]),
                                      squads: [:], ages: [:]).rows
        }
        var disclosure = RemovalDisclosure()
        let medium = rows(.medium)
        disclosure.toggle(medium[0])
        disclosure.toggle(medium[1])
        #expect(medium.map(disclosure.isOpen) == [true, true])

        // His level changes: his row is as the new level says, and the choice is dropped when the rows are rebuilt.
        let keep = rows(.keep)
        #expect(!disclosure.isOpen(keep[0]))
        disclosure.prune(to: keep)
        #expect(disclosure.isOpen(keep[1]))   // Ewan Clark's level did not change, so his choice stays.

        // Back at the old level, the old choice does not come back.
        disclosure.prune(to: medium)
        #expect(medium.map(disclosure.isOpen) == [false, true])

        // The same for a row open by default that the owner closed.
        let high = rows(.high)
        disclosure.toggle(high[0])
        #expect(!disclosure.isOpen(high[0]))
        disclosure.prune(to: rows(.critical))
        disclosure.prune(to: high)
        #expect(disclosure.isOpen(high[0]))
    }

    @Test func aPlayerNoLongerListedLosesTheOwnersChoice() {
        var disclosure = RemovalDisclosure()
        let rows = RemovalPresentation.sheet(report(everyLevel), squads: [:], ages: [:]).rows
        disclosure.toggle(rows[2])
        disclosure.prune(to: Array(rows.prefix(2)))
        #expect(disclosure == RemovalDisclosure())
    }

    @Test func everyRowCanBeOpenedAtOnce() {
        let rows = RemovalPresentation.sheet(report(everyLevel), squads: [:], ages: [:]).rows
        let disclosure = RemovalDisclosure.allOpen(rows)
        #expect(rows.allSatisfy(disclosure.isOpen))
    }

    @Test func theNavigationKeepsTheOwnersOpeningAndClosingAndTheFilter() {
        let navigation = Navigation()
        #expect(navigation.removalFilter == .all)
        #expect(navigation.removalDisclosure == RemovalDisclosure())
        let rows = RemovalPresentation.sheet(report(everyLevel), squads: [:], ages: [:]).rows
        navigation.removalDisclosure.toggle(rows[4])
        navigation.removalFilter = .keep
        navigation.screen = .rest
        navigation.screen = .removal
        #expect(navigation.removalDisclosure.isOpen(rows[4]))
        #expect(navigation.removalFilter == .keep)
    }

    // MARK: Filter

    @Test func theFiltersShowTheirLevels() {
        let sheet = RemovalPresentation.sheet(report(everyLevel), squads: [:], ages: [:])
        #expect(sheet.rows(.all).map(\.name) == ["Critical One", "High One", "Medium One", "Keep One", "Keep Two"])
        #expect(sheet.rows(.criticalAndHigh).map(\.name) == ["Critical One", "High One"])
        #expect(sheet.rows(.medium).map(\.name) == ["Medium One"])
        #expect(sheet.rows(.keep).map(\.name) == ["Keep One", "Keep Two"])
    }

    @Test func eachFilterIsNamedWithItsCount() {
        let sheet = RemovalPresentation.sheet(report(everyLevel), squads: [:], ages: [:])
        #expect(RemovalFilter.allCases == [.all, .criticalAndHigh, .medium, .keep])
        #expect(RemovalFilter.allCases.map(sheet.filterTitle)
                == ["All (5)", "Critical and high (2)", "Medium (1)", "Keep (2)"])
    }

    @Test func aFilterWithNobodySaysSo() {
        let sheet = RemovalPresentation.sheet(report([advice("k", name: "K", level: .keep, action: .keep, score: 0)]),
                                              squads: [:], ages: [:])
        #expect(sheet.filterTitle(.medium) == "Medium (0)")
        #expect(sheet.filteredEmptyText(.medium) == "No player is at this level.")
        #expect(sheet.filteredEmptyText(.keep) == nil)
        #expect(sheet.filteredEmptyText(.all) == nil)
    }

    // MARK: Figures

    @Test func theFiguresAreTheAverageToAWholeNumberAndTheWagesAWeek() {
        let sheet = RemovalPresentation.sheet(report(everyLevel, wages: 12_500, average: 61.6), squads: [:], ages: [:])
        #expect(sheet.figures == [RemovalFigure(label: "First team's average ability", figure: "62"),
                                  RemovalFigure(label: "Wages of the critical and high players", figure: "£12,500 a week")])
        #expect(sheet.figures[1].figure == Display.perWeek(12_500))
    }

    @Test func theAverageRoundsToTheNearest() {
        let down = RemovalPresentation.sheet(report(everyLevel, average: 61.4), squads: [:], ages: [:])
        #expect(down.figures.first?.figure == "61")
    }

    @Test func withNoFirstTeamPlayerThereIsNoAverage() {
        let sheet = RemovalPresentation.sheet(report(everyLevel, wages: 0, average: nil), squads: [:], ages: [:])
        #expect(sheet.figures == [RemovalFigure(label: "Wages of the critical and high players", figure: "£0 a week")])
    }

    // MARK: Loans to the club

    @Test func aLoaneeHasHisVerdictScoreAndReasons() throws {
        let given = loan("l", name: "Kauan Bitencourt de Oliveira", verdict: .endEarly, score: 55,
                         reasons: [RemovalReason(text: "In neither eleven", points: 40),
                                   RemovalReason(text: "Consistency 6", points: 15)])
        let sheet = RemovalPresentation.sheet(report(everyLevel, loans: [given]), squads: [:], ages: [:])
        let block = try #require(sheet.loans.first)
        #expect(block.id == PlayerID(key: "l"))
        #expect(block.name == "Kauan Bitencourt de Oliveira")
        #expect(block.stamp == StatusStamp(text: "End early", tone: .red))
        #expect(block.scoreText == "55")
        #expect(block.reasons == [PointedReason(text: "In neither eleven", pointsText: "+40", tone: .red),
                                  PointedReason(text: "Consistency 6", pointsText: "+15", tone: .red)])
        #expect(block.noteText == "(FM26-era numbers)")
        #expect(block.spokenText == "End early, Kauan Bitencourt de Oliveira, Score 55, +40 In neither eleven, "
                + "+15 Consistency 6, FM26-era numbers")
        #expect(sheet.loansEmptyText == nil)
    }

    @Test func loansKeepTheEnginesOrder() {
        let sheet = RemovalPresentation.sheet(report([], loans: [loan("b", name: "B", score: 30), loan("a", name: "A", score: 5)]),
                                              squads: [:], ages: [:])
        #expect(sheet.loans.map(\.name) == ["B", "A"])
    }

    @Test func withNobodyOnLoanHereTheSectionSaysSo() {
        let sheet = RemovalPresentation.sheet(report(everyLevel), squads: [:], ages: [:])
        #expect(sheet.loans.isEmpty)
        #expect(sheet.loansEmptyText == "Nobody is on loan here.")
    }

    // MARK: Empty squad and words

    @Test func withNoPlayerOfTheClubsOwnThereIsNobodyToAssess() {
        let sheet = RemovalPresentation.sheet(report([], wages: 0, average: nil), squads: [:], ages: [:])
        #expect(sheet.emptyText == "There is nobody to assess.")
        #expect(RemovalPresentation.sheet(report(everyLevel), squads: [:], ages: [:]).emptyText == nil)
    }

    @Test func theScreensOwnWords() {
        #expect(RemovalPresentation.explanation == "The advice judges players against the primary tactic.")
        #expect(RemovalPresentation.loansHeading == "Loans to the club")
        #expect(RemovalPresentation.scoreLabel == "Score")
        #expect(RemovalPresentation.columns == ["Level", "Action", "Name", "Squad", "Age", "Score", "Costs"])
        #expect(RemovalColumn.allCases.map(\.title) == RemovalPresentation.columns)
    }

    @Test func aRowSaysWhetherItIsOpenAndWhatAClickDoes() {
        #expect(RemovalPresentation.openText(true) == "Open")
        #expect(RemovalPresentation.openText(false) == "Closed")
        #expect(RemovalPresentation.clickHelp(true) == "Hide the reasons")
        #expect(RemovalPresentation.clickHelp(false) == "Show the reasons")
    }

    // MARK: On the captured squads

    private func squad(_ t: TestModel) throws -> AppModel {
        try t.importFirstTeam()
        try t.importU21()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        t.model.addTactic(named: "4-2-3-1")
        return t.model
    }

    @Test func theModelsSheetIsTheReportInItsOrderWithEachPlayersSquadAndAge() throws {
        let t = try TestModel()
        let model = try squad(t)
        guard case .ready(let report) = model.adviceState else {
            Issue.record("expected advice, got \(model.adviceState)")
            return
        }
        #expect(!report.removal.advice.isEmpty)
        let sheet = model.removalSheet(report)
        #expect(sheet.rows.map(\.id) == report.removal.advice.map(\.player))
        let players = Dictionary(model.squad.book.allPlayers.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for (row, advice) in zip(sheet.rows, report.removal.advice) {
            let player = try #require(players[advice.player])
            #expect(row.squadText == player.squad.displayName)
            #expect(row.ageText == String(player.age))
            #expect(row.reasons.map(\.text) == advice.reasons.map(\.text))
        }
        #expect(sheet.loans.map(\.id) == report.removal.loans.map(\.player))
    }

    @Test func theSampleWithALoaneeReviewsHisLoanAndNoLongerAdvisesOnHim() throws {
        let model = try SampleData.modelWithLoanee(repositoryRoot: Captures.repositoryRoot)
        guard case .ready(let report) = model.adviceState else {
            Issue.record("expected advice, got \(model.adviceState)")
            return
        }
        let sheet = model.removalSheet(report)
        let loanee = try #require(sheet.loans.first)
        #expect(sheet.loans.count == 1)
        #expect(loanee.name == SampleData.loaneeName)
        #expect(!loanee.reasons.isEmpty)
        #expect(!sheet.rows.contains { $0.id == loanee.id })
    }
}
