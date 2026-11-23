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
                      tier: nil, outlook: nil, matchesHere: nil, keepReason: nil, watchReason: nil,
                      loanOnlyToStart: false, onYouthContract: false,
                      isFalseProspect: false, isMentor: false, releaseCost: release, mutualCost: mutual, basis: basis)
    }

    private func loan(_ key: String, name: String, verdict: LoanVerdict = .keepToEnd, score: Int = 10,
                      reasons: [RemovalReason] = [RemovalReason(text: "In the first eleven at left back", points: -30)],
                      basis: Evidence = .carriedOverFM26) -> LoanReview {
        LoanReview(player: PlayerID(key: key), name: name, verdict: verdict, score: score, reasons: reasons, basis: basis)
    }

    private func report(_ advice: [RemovalAdvice], loans: [LoanReview] = [], wages: Double = 600,
                        average: Double? = 61.6, money: MoneyStyle = .weeklyPounds) -> RemovalReport {
        RemovalReport(advice: advice, loans: loans, weeklyWagesAtStake: wages, squadAverageAbility: average,
                      money: money, advisedToLeave: [])
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
        #expect(row.costsText == "Releasing him costs about £26,000; a mutual termination about £14,300")
        #expect(row.costsText == AdvisorText.costs(of: given, money: .weeklyPounds))
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
                + "Releasing him costs about £26,000; a mutual termination about £14,300")
    }

    // MARK: Ability, salary and contract end

    /// A first-team player of ability 92 and potential 120 on $5,735 a month, kept by the week.
    private func player(_ key: String, contract: ContractType = .fullTime, months: Int? = 28, ends: Day? = nil,
                        perWeek: Double = WagePeriod.monthly.perWeek(5_735)) -> Player {
        Player(id: PlayerID(key: key), name: key, squad: .firstTeam, age: 23, positionsText: "D RC",
               currentAbility: 92, potentialAbility: 120, attributes: [:], familiarity: [:],
               condition: 1, sharpness: 1, jadedness: 0, isInjured: false, isBanned: false, club: nil, loanedTo: nil,
               contractType: contract, monthsLeft: months, wagePerWeek: perWeek, askingPrice: nil, nationalities: [],
               extras: [:], contractEnds: ends)
    }

    private let dollarsMonthly = MoneyStyle(symbol: "$", period: .monthly)

    @Test func aPlayersFactsAreHisAbilitiesHisSalaryByTheYearAndTheDayHisContractEnds() throws {
        let day = Day(iso: "2030-06-30")!
        let given = player("p", ends: day)
        let facts = PlayerFacts(given, money: dollarsMonthly)
        #expect(facts.abilityText == "92")
        #expect(facts.potentialText == "120")
        #expect(facts.salaryText == "$68,820")
        #expect(facts.salaryText == Display.yearlyAmount(perWeek: given.wagePerWeek, dollarsMonthly))
        #expect(facts.contractText == "30 Jun 2030")
        #expect(facts.contractText == AdvisorText.fullDay(day))
        #expect(facts.line == "CA 92 · PA 120 · $68,820 a year · contract ends 30 Jun 2030")
        #expect(facts.spokenText
                == "Current ability 92, potential ability 120, $68,820 a year, contract ends 30 Jun 2030")
    }

    @Test func withoutADayTheContractFallsBackToMonthsLeft() {
        let facts = PlayerFacts(player("p"), money: dollarsMonthly)
        #expect(facts.contractText == "28 months left")
        #expect(facts.line == "CA 92 · PA 120 · $68,820 a year · 28 months left")
        #expect(facts.spokenText == "Current ability 92, potential ability 120, $68,820 a year, 28 months left")
        #expect(PlayerFacts(player("p", months: 1), money: dollarsMonthly).contractText == "1 month left")
        #expect(PlayerFacts(player("p", months: 0), money: dollarsMonthly).contractText == "0 months left")
    }

    @Test func theDayWinsOverMonthsLeft() throws {
        let facts = PlayerFacts(player("p", months: 28, ends: Day(iso: "2030-05-31")!), money: dollarsMonthly)
        #expect(facts.contractText == "31 May 2030")
        #expect(!facts.line.contains("months left"))
    }

    @Test func aPlayerOutOfContractHasNoSalaryAndSaysHeHasNoContract() {
        let facts = PlayerFacts(player("p", contract: .outOfContract, months: nil, perWeek: 0), money: dollarsMonthly)
        #expect(facts.salaryText == nil)
        #expect(facts.contractText == "No contract")
        #expect(facts.line == "CA 92 · PA 120 · no contract")
        #expect(facts.spokenText == "Current ability 92, potential ability 120, no contract")
    }

    @Test func aContractWithNeitherADayNorMonthsLeftShowsNothingForItsEnd() {
        let facts = PlayerFacts(player("p", months: nil), money: dollarsMonthly)
        #expect(facts.salaryText == "$68,820")
        #expect(facts.contractText == nil)
        #expect(facts.line == "CA 92 · PA 120 · $68,820 a year")
    }

    @Test func theSalaryIsInTheSquadsCurrencyWhateverPeriodItShowsWagesBy() {
        #expect(PlayerFacts(player("p", perWeek: 600), money: .weeklyPounds).salaryText == "£31,200")
    }

    @Test func aRowCarriesItsPlayersFactsAndNoneForAPlayerNotHandedIn() throws {
        let facts = PlayerFacts(player("p", ends: Day(iso: "2030-06-30")!), money: dollarsMonthly)
        let sheet = RemovalPresentation.sheet(
            report([advice("p", name: "Josh Ashby", score: 85), advice("gone", name: "Gone")], money: dollarsMonthly),
            squads: [PlayerID(key: "p"): .u21], ages: [PlayerID(key: "p"): 19], facts: [PlayerID(key: "p"): facts])
        #expect(sheet.rows.map(\.facts) == [facts, nil])
        #expect(sheet.rows[0].spokenText == "High, Sell, Josh Ashby, U21s, Age 19, Current ability 92, "
                + "potential ability 120, $68,820 a year, contract ends 30 Jun 2030, Score 85, "
                + "Releasing him costs about $26,000; a mutual termination about $14,300")
        #expect(!sheet.rows[1].spokenText.contains("ability"))
    }

    @Test func aYoungRowCarriesTheFactsLineAndNoneForAPlayerNotHandedIn() throws {
        let facts = PlayerFacts(player("t", ends: Day(iso: "2030-06-30")!), money: dollarsMonthly)
        let sheet = RemovalPresentation.sheet(
            report([young("t", name: "Tom Reed", age: 20), young("n", name: "Nob", age: 18)]),
            squads: [:], ages: [:], facts: [PlayerID(key: "t"): facts])
        let tom = try #require(sheet.young.first { $0.id.key == "t" })
        #expect(tom.factsLine == "CA 92 · PA 120 · $68,820 a year · contract ends 30 Jun 2030")
        #expect(tom.spokenText == "Tom Reed, Age 20, striker, Keep and play. " + facts.spokenText + ". "
                + tom.lines.joined(separator: " "))
        let nob = try #require(sheet.young.first { $0.id.key == "n" })
        #expect(nob.factsLine == nil)
        #expect(nob.spokenText == "Nob, Age 18, striker, Keep and play. " + nob.lines.joined(separator: " "))
    }

    @Test func theTableHasTheFourFactsBetweenAgeAndScoreAndNoCostsColumn() {
        #expect(RemovalPresentation.columns
                == ["Level", "Action", "Name", "Squad", "Age", "CA", "PA", "Salary a year", "Contract ends", "Score"])
    }

    // MARK: Marks

    @Test func aMarkedRowShowsItsMarkInTheEnginesWords() throws {
        let p = PlayerID(key: "p")
        let sell = RemovalPresentation.sheet(report([advice("p", name: "Josh Ashby")]), squads: [:], ages: [:],
                                             marks: [p: .toSell])
        #expect(sell.rows.first?.mark == .toSell)
        #expect(sell.rows.first?.markText == "To sell")
        #expect(sell.rows.first?.markText == AdvisorText.name(SaleMark.toSell))
        let loan = RemovalPresentation.sheet(report([advice("p", name: "Josh Ashby")]), squads: [:], ages: [:],
                                             marks: [p: .toLoanOut])
        #expect(loan.rows.first?.mark == .toLoanOut)
        #expect(loan.rows.first?.markText == "To loan out")
    }

    @Test func anUnmarkedRowHasNoMark() throws {
        let sheet = RemovalPresentation.sheet(report(everyLevel), squads: [:], ages: [:],
                                              marks: [PlayerID(key: "h"): .toSell, PlayerID(key: "gone"): .toLoanOut])
        #expect(sheet.rows.map(\.mark) == [nil, .toSell, nil, nil, nil])
        #expect(sheet.rows.map(\.markText) == [nil, "To sell", nil, nil, nil])
        #expect(sheet.rows == RemovalPresentation.sheet(report(everyLevel), squads: [:], ages: [:],
                                                         marks: [PlayerID(key: "h"): .toSell]).rows)
    }

    @Test func theChoicesAreNoMarkThenEachMark() {
        #expect(RemovalPresentation.markChoices.map(\.title) == ["No mark", "To sell", "To loan out"])
        #expect(RemovalPresentation.markChoices.map(\.mark) == [nil, .toSell, .toLoanOut])
        #expect(RemovalPresentation.markLabel == "Mark")
    }

    @Test func theNoteIsTheEngines() {
        #expect(RemovalPresentation.marksNote == AdvisorText.marksNote)
    }

    @Test func aMarkedRowIsSpokenWithItsMark() throws {
        let squads = [PlayerID(key: "p"): Squad.u21], ages = [PlayerID(key: "p"): 19]
        let marked = RemovalPresentation.sheet(report([advice("p", name: "Josh Ashby", score: 85)]), squads: squads,
                                               ages: ages, marks: [PlayerID(key: "p"): .toSell])
        #expect(try #require(marked.rows.first).spokenText == "High, Sell, To sell, Josh Ashby, U21s, Age 19, Score 85, "
                + "Releasing him costs about £26,000; a mutual termination about £14,300")
        let unmarked = RemovalPresentation.sheet(report([advice("p", name: "Josh Ashby", score: 85)]), squads: squads,
                                                 ages: ages)
        #expect(!(try #require(unmarked.rows.first).spokenText.contains("No mark")))
    }

    @Test func theLoansToTheClubHaveNoMark() {
        let given = loan("l", name: "Kauan Bitencourt de Oliveira")
        let plain = RemovalPresentation.sheet(report(everyLevel, loans: [given]), squads: [:], ages: [:])
        let marked = RemovalPresentation.sheet(report(everyLevel, loans: [given]), squads: [:], ages: [:],
                                               marks: [PlayerID(key: "l"): .toSell])
        #expect(marked.loans == plain.loans)
        #expect(marked.rows == plain.rows)
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
        #expect(sheet.figures[1].figure == Display.wage(perWeek: 12_500, .weeklyPounds))
    }

    @Test func theWagesAndCostsAreWrittenAsTheSquadsWereImported() throws {
        let dollars = MoneyStyle(symbol: "$", period: .monthly)
        let sheet = RemovalPresentation.sheet(report(everyLevel, wages: 807, money: dollars), squads: [:], ages: [:])
        #expect(sheet.figures[1] == RemovalFigure(label: "Wages of the critical and high players", figure: "$3,497 a month"))
        #expect(sheet.figures[1].figure == Display.wage(perWeek: 807, dollars))
        let row = try #require(sheet.rows.first)
        #expect(row.costsText == "Releasing him costs about $26,000; a mutual termination about $14,300")
        #expect(row.costsText == AdvisorText.costs(of: everyLevel[0], money: dollars))
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

    // MARK: Young players

    /// A young player's advice: aged `age`, best at `slot` behind Smith (no slot when nil), his matches here on
    /// `basis`, with `action`, `keepReason` and whether he is on a youth contract.
    private func young(_ key: String, name: String, age: Int, action: RemovalAction = .play, slot: SlotID? = .ST_C,
                       basis: MatchesHereBasis = .startedTooFew, keepReason: KeepReason? = nil,
                       onYouthContract: Bool = false, score: Int = -20, firstAt: [SlotID] = [],
                       tier: SquadTier? = nil, level: RemovalLevel = .keep) -> RemovalAdvice {
        let estimate = ReachEstimate(age: age, current: 55, potential: 140, professionalism: 15, ambition: 10,
                                     determination: 10, seasonGrowth: 13.3, bySeason: [55, 68, 140],
                                     reachesPotential: true, ambitionSlows: false, determinationSlows: false,
                                     professionalismHoldsBack: false, growthFallsLater: true)
        let best = slot.map { slot in
            SlotOutlook(slot: slot, rating: 50, reachRating: 75, isFirstChoice: false,
                        firstChoice: Rival(player: PlayerID(key: "smith"), name: "Smith", age: 31, rating: 70,
                                           compared: 70, isAgeNamed: true),
                        secondChoice: nil, band: .onCourse, pointsNeeded: 14, level: .couldPassFirst)
        }
        // Slots he is first choice at, then his best, as given: the tests give them in the tactic's order.
        let home = firstAt.map { slot in
            SlotOutlook(slot: slot, rating: 70, reachRating: 90, isFirstChoice: true, firstChoice: nil, secondChoice: nil,
                        band: nil, pointsNeeded: nil, level: nil)
        }
        let outlook = Outlook(player: PlayerID(key: key), estimate: estimate, slots: home + (best.map { [$0] } ?? []),
                              best: best, level: .couldPassFirst, average: slot == nil ? 70 : nil)
        return RemovalAdvice(player: PlayerID(key: key), name: name, level: level, action: action, score: score,
                             reasons: [], tier: tier, outlook: outlook,
                             matchesHere: MatchesHere(starts: 1, matches: 9, basis: basis), keepReason: keepReason,
                             watchReason: nil, loanOnlyToStart: false, onYouthContract: onYouthContract,
                             isFalseProspect: false, isMentor: false, releaseCost: nil, mutualCost: nil, basis: .derived)
    }

    /// Positions in sentences, as the engine names them in Player Removal's reasons.
    private let names: (SlotID) -> String = { PositionText.plain($0.position) }

    @Test func theYoungPartListsEveryPlayerWithAnOutlookOldestFirst() {
        let given = [advice("old", name: "Josh Ashby", level: .keep, action: .keep, score: 0),
                     young("b", name: "Bea", age: 19), young("t", name: "Tom Reed", age: 16, action: .develop,
                                                             keepReason: .age),
                     young("a", name: "Abe", age: 19), young("d", name: "Dan", age: 23),
                     young("a2", name: "Abe", age: 19)]
        let sheet = RemovalPresentation.sheet(report(given), squads: [:], ages: [:])
        #expect(sheet.young.map(\.id.key) == ["d", "a", "a2", "b", "t"])
        // The table keeps every row, in the engine's order.
        #expect(sheet.rows.map(\.id.key) == ["old", "b", "t", "a", "d", "a2"])
        #expect(sheet.youngEmptyText == nil)
    }

    @Test func withNoYoungPlayerThePartSaysSo() {
        let sheet = RemovalPresentation.sheet(report(everyLevel), squads: [:], ages: [:])
        #expect(sheet.young.isEmpty)
        #expect(sheet.youngEmptyText == "No player of 23 or under.")
        #expect(sheet.youngEmptyText == RemovalPresentation.youngEmptyText)
    }

    @Test func theYoungPartsWordsReadTheEnginesAge() {
        let age = EngineParameters.fm27.developingUpToAge.value
        #expect(RemovalPresentation.youngHeading == "Young players")
        #expect(RemovalPresentation.youngEmptyText == "No player of \(age) or under.")
        #expect(RemovalPresentation.youngExplanation.contains("\(age) or under"))
        #expect(RemovalPresentation.youngExplanation.contains(AdvisorText.note(for: .derived)!))
        #expect(!RemovalPresentation.youngExplanation.contains("\n"))
    }

    @Test func aYoungRowCarriesTheEnginesSentencesAsWritten() throws {
        let cases = [young("p", name: "Tom Reed", age: 20, action: .play, basis: .firstChoice),
                     young("l", name: "Lee", age: 19, action: .loanForMatches),
                     young("d", name: "Dev", age: 16, action: .develop, keepReason: .age),
                     young("r", name: "Rex", age: 16, action: .release, onYouthContract: true),
                     young("n", name: "Nob", age: 18, action: .play, slot: nil, basis: .solidSecondChoice)]
        let sheet = RemovalPresentation.sheet(report(cases), squads: [:], ages: [:])
        for given in cases {
            let row = try #require(sheet.young.first { $0.id == given.player })
            #expect(row.lines == AdvisorText.youngLines(given, names: names))
            #expect(row.actionText == AdvisorText.name(given.action))
        }
        // Each line is the engine's own sentence.
        let play = try #require(sheet.young.first { $0.id.key == "p" })
        let outlook = try #require(cases[0].outlook)
        #expect(play.lines == [AdvisorText.reachWorking(outlook.estimate),
                               try #require(AdvisorText.standing(outlook, names: names)),
                               AdvisorText.matchesHere(try #require(cases[0].matchesHere)),
                               AdvisorText.why(.play, for: cases[0])])
        #expect(play.lines[1] == "Needs about 14 more ability points to match Smith at striker; this tool expects about "
                + "13 a season. On course. Smith is 31.")
        #expect(play.actionText == "Keep and play")
        #expect(play.spokenText == "Tom Reed, Age 20, striker, Keep and play. " + play.lines.joined(separator: " "))
        // With no standing, no line for it.
        let unplaced = try #require(sheet.young.first { $0.id.key == "n" })
        #expect(unplaced.lines == [AdvisorText.reachWorking(try #require(cases[4].outlook).estimate),
                                   "He is second choice here, and too few matches are confirmed to count his starts."])
        #expect(unplaced.spokenText == "Nob, Age 18, Keep and play. " + unplaced.lines.joined(separator: " "))
    }

    @Test func aYoungRowStampsHisActionInHisLevelsTone() throws {
        let cases: [(RemovalLevel, RemovalAction, StampTone)] = [
            (.critical, .release, .red), (.high, .sell, .amber), (.medium, .monitor, .ink), (.keep, .develop, .muted),
        ]
        let given = cases.enumerated().map { index, item in
            young("y\(index)", name: "Young \(index)", age: 19, action: item.1, level: item.0)
        }
        let sheet = RemovalPresentation.sheet(report(given), squads: [:], ages: [:])
        for (advice, (level, action, tone)) in zip(given, cases) {
            let row = try #require(sheet.young.first { $0.id == advice.player })
            let tableRow = try #require(sheet.rows.first { $0.id == advice.player })
            #expect(row.stamp == StatusStamp(text: AdvisorText.name(action), tone: tone), "\(level)")
            // The same tone as his level's stamp in the table above, so a player advised to go stands out here too.
            #expect(row.stamp.tone == tableRow.stamp.tone, "\(level)")
            #expect(row.stamp.text == row.actionText, "\(level)")
        }
    }

    @Test func aLoanForMatchesRowIsStampedInInkWhereHisLevelWouldBeMuted() throws {
        // A loan for matches asks the owner to do something, so it does not recede as keeping does.
        let given = [young("l", name: "Loa", age: 19, action: .loanForMatches, level: .keep),
                     young("m", name: "Med", age: 19, action: .loanForMatches, level: .medium),
                     young("p", name: "Pla", age: 20, action: .play, level: .keep),
                     young("d", name: "Dev", age: 16, action: .develop, level: .keep)]
        let sheet = RemovalPresentation.sheet(report(given), squads: [:], ages: [:])
        func stamp(_ key: String) throws -> StatusStamp { try #require(sheet.young.first { $0.id.key == key }).stamp }
        #expect(try stamp("l") == StatusStamp(text: "Loan for matches", tone: .ink))
        #expect(try stamp("m") == StatusStamp(text: "Loan for matches", tone: .ink))
        // Every other row keeps his level's tone.
        #expect(try stamp("p") == StatusStamp(text: "Keep and play", tone: .muted))
        #expect(try stamp("d") == StatusStamp(text: "Keep and develop", tone: .muted))
        // The table above keeps the level's stamp.
        #expect(sheet.rows.first { $0.id.key == "l" }?.stamp == StatusStamp(text: "Keep", tone: .muted))
    }

    @Test func aYoungRowNamesHisBestPositionInWordsAndNeverAKey() throws {
        let cases = [young("fmrte:7", name: "Tom Reed", age: 16, slot: .ST_C),
                     young("fmrte:8", name: "Ann Lee", age: 18, slot: .D_CL),
                     young("fmrte:9", name: "Nobody Placed", age: 19, slot: nil)]
        let sheet = RemovalPresentation.sheet(report(cases), squads: [:], ages: [:])
        func title(_ key: String) -> String? { sheet.young.first { $0.id.key == key }?.titleText }
        #expect(title("fmrte:7") == "Tom Reed · 16 · striker")
        // Named as the engine names the position in his lines, so the title and the lines agree.
        #expect(title("fmrte:8") == "Ann Lee · 18 · centre-back")
        #expect(sheet.young.first { $0.id.key == "fmrte:8" }?.lines[1].contains("to match Smith at centre-back;") == true)
        // With no slot, the position is left out.
        #expect(title("fmrte:9") == "Nobody Placed · 19")
        for row in sheet.young {
            #expect(!row.titleText.contains("fmrte") && !row.spokenText.contains("fmrte"))
            for code in SlotID.allCases.map(\.rawValue) {
                #expect(!row.titleText.contains(code) && !row.lines.joined().contains(code))
            }
        }
    }

    @Test func aYoungRowsTitleNamesTheSlotHeIsFirstChoiceAtElseHisBest() throws {
        let cases = [young("first", name: "Deago", age: 20, slot: .AM_R, firstAt: [.D_R], tier: .first(.D_R)),
                     young("nowhere", name: "Brayden", age: 20, slot: .AM_R, tier: .second(.AM_R)),
                     // First choice by the elevens at a slot he is not counted as able to play: that slot still.
                     young("unfamiliar", name: "Stand In", age: 19, slot: .AM_R, tier: .first(.D_L))]
        let sheet = RemovalPresentation.sheet(report(cases), squads: [:], ages: [:])
        func row(_ key: String) throws -> YoungRow { try #require(sheet.young.first { $0.id.key == key }) }
        #expect(try row("first").titleText == "Deago · 20 · right back")
        #expect(try row("first").spokenText.hasPrefix("Deago, Age 20, right back, Keep and play. "))
        // His lines still compare him at his best slot.
        #expect(try row("first").lines[1].hasPrefix("First choice at right back. Needs about 14 more ability points to "
                                                    + "match Smith at right attacking midfield;"))
        #expect(try row("nowhere").titleText == "Brayden · 20 · right attacking midfield")
        #expect(try row("unfamiliar").titleText == "Stand In · 19 · left back")
    }

    @Test func aRowsActionIsTheEnginesNameForEachNewAction() throws {
        let given = [young("d", name: "Dev", age: 16, action: .develop, keepReason: .age),
                     young("p", name: "Pla", age: 20, action: .play, basis: .firstChoice),
                     young("l", name: "Loa", age: 19, action: .loanForMatches)]
        let sheet = RemovalPresentation.sheet(report(given), squads: [:], ages: [:])
        #expect(sheet.rows.map(\.actionText) == ["Keep and develop", "Keep and play", "Loan for matches"])
        #expect(sheet.rows.map(\.actionText) == given.map { AdvisorText.name($0.action) })
        #expect(sheet.rows.map(\.whyText) == given.map { AdvisorText.why($0.action, for: $0) })
    }

    @Test func aYouthContractRowOffersOnlyTheMarkToSellWithTheNote() throws {
        let given = [young("y", name: "Youth Deal", age: 16, action: .release, onYouthContract: true),
                     young("f", name: "Full Time", age: 19, action: .loanForMatches),
                     advice("o", name: "Older One")]
        let sheet = RemovalPresentation.sheet(report(given), squads: [:], ages: [:])
        func row(_ key: String) throws -> RemovalRow { try #require(sheet.rows.first { $0.id.key == key }) }
        #expect(try row("y").markChoices.map(\.title) == ["No mark", "To sell"])
        #expect(try row("y").markChoices.map(\.mark) == [nil, .toSell])
        #expect(try row("y").markNote == AdvisorText.youthContractNotLoaned)
        #expect(try row("y").markNote == "A player on a youth contract cannot be loaned out; he can be sold or released.")
        for key in ["f", "o"] {
            #expect(try row(key).markChoices.map(\.title) == ["No mark", "To sell", "To loan out"], "\(key)")
            #expect(try row(key).markChoices == RemovalPresentation.markChoices, "\(key)")
            #expect(try row(key).markNote == nil, "\(key)")
        }
    }

    @Test func theSampleWithYoungPlayersShowsEachAdvice() throws {
        let model = try SampleData.modelWithYoungPlayers(repositoryRoot: Captures.repositoryRoot)
        guard case .ready(let report) = model.adviceState else {
            Issue.record("expected advice, got \(model.adviceState)")
            return
        }
        let actions = Set(report.removal.advice.map(\.action))
        for action in [RemovalAction.develop, .release, .loanForMatches, .play] {
            #expect(actions.contains(action), "no player is advised to \(AdvisorText.name(action))")
        }
        func advice(_ name: String) throws -> RemovalAdvice {
            try #require(report.removal.advice.first { $0.name == name })
        }
        let develop = try advice(SampleData.youngToDevelopName)
        #expect(develop.action == .develop && develop.onYouthContract && develop.outlook?.estimate.age == 16)
        let release = try advice(SampleData.youngToReleaseName)
        #expect(release.action == .release && release.onYouthContract && release.outlook?.estimate.age == 16)
        // On a youth contract nearly up, where a full-time contract would be terminated: released.
        #expect(release.level == .critical)
        #expect(AdvisorText.why(release.action, for: release)
                == "He is on a youth contract that is nearly up, so releasing him is the way to move him on")
        #expect(release.outlook?.level == .markedlyLower)
        let loan = try advice(SampleData.youngToLoanName)
        #expect(loan.action == .loanForMatches && !loan.onYouthContract && loan.outlook?.estimate.age == 19)
        #expect(loan.matchesHere?.isCounted == true && loan.matchesHere?.starts == 0)
        // Each advice is honest: whoever is kept to develop or loaned for matches is worth developing.
        let worthDeveloping: Set<ReachLevel> = [.couldPassFirst, .couldMakeSecond]
        #expect(loan.outlook?.level.map(worthDeveloping.contains) == true)
        #expect(develop.outlook?.level.map(worthDeveloping.contains) == true)
        for a in report.removal.advice where a.action == .develop || a.action == .loanForMatches {
            #expect(a.outlook?.level.map(worthDeveloping.contains) != false, "\(a.name)")
        }

        let sheet = model.removalSheet(report)
        let young = report.removal.advice.filter { $0.outlook != nil }
            .sorted { ($1.outlook!.estimate.age, $0.name) < ($0.outlook!.estimate.age, $1.name) }
        #expect(sheet.young.map(\.id) == young.map(\.player))
        #expect(Set(sheet.young.map(\.actionText)).isSuperset(of: ["Keep and develop", "Release", "Loan for matches",
                                                                   "Keep and play"]))
        let noted = Set(sheet.rows.filter { $0.markNote != nil }.map(\.name))
        #expect(noted == [SampleData.youngToDevelopName, SampleData.youngToReleaseName])
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
        #expect(RemovalPresentation.columns
                == ["Level", "Action", "Name", "Squad", "Age", "CA", "PA", "Salary a year", "Contract ends", "Score"])
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
            #expect(row.facts == PlayerFacts(player, money: report.removal.money))
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
