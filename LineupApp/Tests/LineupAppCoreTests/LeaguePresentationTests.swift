import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

@MainActor @Suite struct LeaguePresentationTests {
    private func day(_ offset: Int) -> Day { TestModel.today.adding(days: offset) }

    @discardableResult
    private func addLeague(_ t: TestModel, _ opponent: String, on date: Day, competition: Competition? = .league) -> FixtureID {
        let id = t.model.addFixture(date: date, opponent: opponent, importance: .medium)
        var fixture = t.model.fixtures.first { $0.id == id }!
        fixture.competition = competition
        t.model.update(fixture)
        return id
    }

    private func read(_ t: TestModel) throws {
        try t.pasteLeagueTable()
        t.model.setLeagueFormatDraft(LeagueFormatDraft(promoted: 1, playOffs: 6, relegated: 4))
    }

    private func readReady() throws -> TestModel {
        let t = try ScoutingSetup.ready()
        try read(t)
        return t
    }

    @Test func theOwnersTableHasItsLinesAndMarks() throws {
        let t = try readReady()
        let rows = t.model.leagueScreen.rows
        #expect(rows.count == 24)
        #expect(rows[4].isOwn)
        #expect(rows.filter(\.isOwn).count == 1)
        #expect(rows.filter(\.isBattled).map(\.id) == [3, 4, 6, 7, 8])
        #expect(rows.filter { $0.lineBelow != nil }.map { "\($0.id) \($0.lineBelow!)" }
                == ["1 promoted", "3 bye", "7 play-offs", "20 relegated"])
        #expect(rows[0].goalDifference == "+32")
        #expect(rows[0].place == "1" && rows[0].team == "Chester" && rows[0].points == "87")
        let negative = try #require(rows.first { $0.goalDifference.hasPrefix("\u{2212}") })
        #expect(negative.goalDifference.dropFirst().allSatisfy { $0.isNumber })
    }

    @Test func aGoalDifferenceOfZeroIsZero() throws {
        let t = try readReady()
        var table = try #require(t.model.league.table)
        table.teams[0].goalsFor = table.teams[0].goalsAgainst
        t.model.league.table = table
        #expect(t.model.leagueScreen.rows[0].goalDifference == "0")
    }

    @Test func theSentencesAreTheEngines() throws {
        let t = try readReady()
        let reading = try #require(t.model.leagueContext?.reading)
        let screen = t.model.leagueScreen
        #expect(screen.sentences == AdvisorText.standingLines(reading))
        #expect(screen.evidenceNote == AdvisorText.leagueEvidenceNote(reading, rules: EngineParameters.fm27.leagueStandingRules.value))
        #expect(screen.byeLine == "2nd and 3rd get a bye.")
        #expect(screen.pastedLine == AdvisorText.tablePastedLine(on: TestModel.today))
        #expect(screen.offersRemove)
        #expect(screen.emptyLines.isEmpty)
    }

    @Test func withNoTableThereAreOnlyTheEmptyLines() throws {
        let t = try ScoutingSetup.ready()
        let screen = t.model.leagueScreen
        #expect(screen.rows.isEmpty)
        #expect(screen.emptyLines == AdvisorText.noTableLines)
        #expect(!screen.offersRemove)
        #expect(screen.sentences.isEmpty)
        #expect(screen.evidenceNote == nil)
        #expect(screen.pastedLine == nil)
    }

    @Test func withATableAndNoFormatTheRowsHaveNoLines() throws {
        let t = try ScoutingSetup.ready()
        try t.pasteLeagueTable()
        let screen = t.model.leagueScreen
        #expect(screen.rows.count == 24)
        #expect(screen.rows.allSatisfy { $0.lineBelow == nil && !$0.isBattled })
        // The club's own row is marked by its name, with no format and so no reading.
        #expect(screen.rows.filter(\.isOwn).map(\.id) == [5])
        #expect(screen.withinMarginKey == nil)
        #expect(screen.sentences == [AdvisorText.noFormatLine])
        #expect(screen.evidenceNote == nil)
        #expect(screen.byeLine == nil)
        #expect(screen.offersRemove)
        #expect(screen.emptyLines.isEmpty)
    }

    @Test func aFailedReadingShowsItsSentenceAndThePlainTable() throws {
        let t = try readReady()
        var settings = t.model.settings
        settings.clubName = "Banbury United"
        t.model.update(settings)
        let table = try #require(t.model.league.table)
        let screen = t.model.leagueScreen
        #expect(screen.sentences == [ErrorDescriptions.describe(
            LeagueTableError.clubNotInTable(club: "Banbury United", teams: table.teams.count))])
        #expect(screen.rows.count == 24)
        #expect(screen.rows.allSatisfy { !$0.isOwn && !$0.isBattled })
        // The format fits the table, so its rules are drawn though there is no reading.
        #expect(screen.rows.filter { $0.lineBelow != nil }.map { "\($0.id) \($0.lineBelow!)" }
                == ["1 promoted", "3 bye", "7 play-offs", "20 relegated"])
        #expect(screen.evidenceNote == nil)
    }

    /// The owner's table with every team's season played out.
    private func finishSeason(_ t: TestModel) throws {
        var table = try #require(t.model.league.table)
        for index in table.teams.indices { table.teams[index].played = 46 }
        t.model.league.table = table
    }

    @Test func aFinishedSeasonDrawsItsRulesAndDoesNotSayTheTableStops() throws {
        let t = try readReady()
        try finishSeason(t)
        addLeague(t, "Next season", on: day(30))
        let reading = try #require(t.model.leagueContext?.reading)
        #expect(reading.seasonIsOver)
        #expect(t.model.leagueFixturesBeyondTheTable > 0)
        let screen = t.model.leagueScreen
        #expect(!screen.cautions.contains { $0.hasPrefix("The table has") })
        #expect(screen.rows.filter { $0.lineBelow != nil }.map { "\($0.id) \($0.lineBelow!)" }
                == ["1 promoted", "3 bye", "7 play-offs", "20 relegated"])
        #expect(screen.rows.filter(\.isOwn).map(\.id) == [5])
    }

    @Test func aSeasonStillOnSaysTheTableStops() throws {
        let t = try readReady()
        let left = try #require(t.model.leagueContext?.reading.matchesLeft)
        for week in 1...(left + 1) { addLeague(t, "Team \(week)", on: day(7 * week)) }
        #expect(t.model.leagueScreen.cautions == [AdvisorText.tableStopsLine(matchesLeft: left, beyond: 1)])
    }

    @Test func pointsBelowZeroAreWrittenWithATrueMinus() throws {
        let t = try readReady()
        var table = try #require(t.model.league.table)
        table.teams[23].points = -10
        t.model.league.table = table
        #expect(t.model.leagueScreen.rows[23].points == "\u{2212}10")
        #expect(t.model.leagueScreen.rows[22].points.allSatisfy { $0.isNumber })
    }

    @Test func theMarkOnSidesWithinTheMarginHasAKey() throws {
        let t = try readReady()
        let reading = try #require(t.model.leagueContext?.reading)
        let screen = t.model.leagueScreen
        let key = AdvisorText.withinMarginKey(reading)
        #expect(screen.withinMarginKey == key)
        #expect(screen.rows.filter(\.isBattled).allSatisfy { $0.mark == key })
        #expect(screen.rows.filter { !$0.isBattled }.allSatisfy { $0.mark == nil })
    }

    @Test func withNoSideWithinTheMarginThereIsNoKey() throws {
        let t = try readReady()
        var table = try #require(t.model.league.table)
        for index in table.teams.indices { table.teams[index].played = 0 }
        t.model.league.table = table
        let reading = try #require(t.model.leagueContext?.reading)
        #expect(reading.rivals.isEmpty)
        #expect(t.model.leagueScreen.withinMarginKey == nil)
        #expect(t.model.leagueScreen.rows.allSatisfy { $0.mark == nil })
    }

    @Test func theFormatInUseIsSaidWhileTheFieldsShowSomethingElse() throws {
        let t = try readReady()
        let saved = LeagueFormat(promoted: 1, playOffs: 6, relegated: 4)
        #expect(t.model.leagueScreen.formatInUseLine == nil)
        t.model.setLeagueFormatDraft(LeagueFormatDraft(promoted: 1, playOffs: nil, relegated: 4))
        #expect(t.model.league.format == saved)
        #expect(t.model.leagueScreen.formatInUseLine == AdvisorText.formatInUseLine(saved))
        #expect(t.model.leagueScreen.formatProblem == nil)
        t.model.setLeagueFormatDraft(LeagueFormatDraft(promoted: 1, playOffs: 30, relegated: 4))
        #expect(t.model.leagueScreen.formatProblem != nil)
        #expect(t.model.leagueScreen.formatInUseLine == AdvisorText.formatInUseLine(saved))
        t.model.setLeagueFormatDraft(LeagueFormatDraft(saved))
        #expect(t.model.leagueScreen.formatInUseLine == nil)
    }

    @Test func withNoFormatSavedNothingIsInUse() throws {
        let t = try ScoutingSetup.ready()
        try t.pasteLeagueTable()
        t.model.setLeagueFormatDraft(LeagueFormatDraft(promoted: 1, playOffs: 6))
        #expect(t.model.leagueScreen.formatInUseLine == nil)
        t.model.setLeagueFormatDraft(LeagueFormatDraft(promoted: 20, playOffs: 20, relegated: 20))
        #expect(t.model.leagueScreen.formatInUseLine == nil)
    }

    @Test func theCautionsComeInOrder() throws {
        let t = try ScoutingSetup.ready()
        // The table has 3 matches left for the club; a fourth league fixture is beyond it. A confirmed league match
        // after the paste day puts the table out of date, and a team's points are made not to fit.
        try t.pasteLeagueTable()
        var table = try #require(t.model.league.table)
        table.warnings = [.pointsDoNotFit(team: "Chester", points: 87, fromResults: 90)]
        t.model.league.table = table
        t.model.setLeagueFormatDraft(LeagueFormatDraft(promoted: 1, playOffs: 6, relegated: 4))
        let left = try #require(t.model.leagueContext?.reading.matchesLeft)
        var ids: [FixtureID] = []
        for week in 1...(left + 2) { ids.append(addLeague(t, "Team \(week)", on: day(7 * week))) }
        t.model.history = [ConfirmedRecord(
            lineup: ConfirmedLineup(fixture: ids[0], date: day(7), starters: [:]), names: [:], tacticName: "x")]
        let beyond = t.model.leagueFixturesBeyondTheTable
        #expect(beyond > 0)
        #expect(t.model.leagueTableIsOutOfDate)
        #expect(t.model.leagueScreen.cautions == [
            AdvisorText.tableOutOfDate,
            ErrorDescriptions.describe(LeagueTableWarning.pointsDoNotFit(team: "Chester", points: 87, fromResults: 90)),
            AdvisorText.tableStopsLine(matchesLeft: left, beyond: beyond),
        ])
    }

    @Test func theOrderWorkedOutIsSaidBetweenTheWarningsAndTheStop() throws {
        let t = try readReady()
        var table = try #require(t.model.league.table)
        table.orderWorkedOut = true
        t.model.league.table = table
        #expect(t.model.leagueScreen.cautions == [AdvisorText.orderWorkedOutLine])
    }

    @Test func aTableWithNothingWrongHasNoCautions() throws {
        let t = try readReady()
        #expect(t.model.leagueScreen.cautions.isEmpty)
    }

    @Test func aChoiceByHandThatDiffersIsSaidWithTheTables() throws {
        let t = try readReady()
        let tableSays = try #require(t.model.leagueContext?.reading.situation)
        #expect(t.model.leagueScreen.handChoiceLine == nil)
        let other: LeagueSituation = tableSays == .midTable ? .titleRaceOrRelegationFight : .midTable
        t.model.setLeagueSituation(other)
        #expect(t.model.leagueScreen.handChoiceLine == AdvisorText.handChoiceLine(byHand: other, table: tableSays))
        t.model.setLeagueSituation(tableSays)
        #expect(t.model.leagueScreen.handChoiceLine == nil)
        t.model.setLeagueSituation(nil)
        #expect(t.model.leagueScreen.handChoiceLine == nil)
    }

    @Test func leagueFixturesAgainstSidesNotInTheTableAreNamed() throws {
        let t = try ScoutingSetup.ready()
        try read(t)
        addLeague(t, "Buxton FC", on: day(7))
        addLeague(t, "buxton", on: day(8))
        let confirmed = addLeague(t, "Rovers", on: day(9))
        addLeague(t, "Town", on: day(-3))
        addLeague(t, "City", on: day(10), competition: .cup)
        addLeague(t, "Rangers", on: day(11), competition: nil)
        addLeague(t, "Athletic", on: day(0))
        let confirmedToday = addLeague(t, "Wanderers", on: day(0))
        t.model.history = [
            ConfirmedRecord(lineup: ConfirmedLineup(fixture: confirmed, date: day(9), starters: [:]), names: [:],
                            tacticName: "x"),
            ConfirmedRecord(lineup: ConfirmedLineup(fixture: confirmedToday, date: day(0), starters: [:]), names: [:],
                            tacticName: "x"),
        ]
        // Today's match is still to play until its lineup is confirmed.
        #expect(t.model.leagueScreen.fixturesNotInTheTable
                == ["Athletic on \(DayText.short(day(0)))", "Buxton FC on \(DayText.short(day(7)))"])
    }

    @Test func withNoTableNoFixtureIsNamed() throws {
        let t = try ScoutingSetup.ready()
        addLeague(t, "Buxton FC", on: day(7))
        #expect(t.model.leagueScreen.fixturesNotInTheTable.isEmpty)
    }

    @Test func theProblemsAreCarriedToTheScreen() throws {
        let t = try ScoutingSetup.ready()
        t.input.clipboard = try Captures.firstTeam
        t.input.config = .data(try Captures.firstTeamGrids)
        t.model.pasteLeagueTable()
        #expect(t.model.leagueScreen.pasteProblem == t.model.leaguePasteProblem)
        #expect(t.model.leagueScreen.pasteProblem != nil)
        try t.pasteLeagueTable()
        t.model.setLeagueFormatDraft(LeagueFormatDraft(promoted: 20, playOffs: 20, relegated: 20))
        #expect(t.model.leagueScreen.formatProblem == t.model.leagueFormatProblem)
        #expect(t.model.leagueScreen.formatProblem != nil)
    }

    @Test func theSampleModelWithALeagueReadsAndNamesTheSideNotInTheTable() throws {
        let model = try SampleData.modelWithLeague(repositoryRoot: Captures.repositoryRoot)
        guard case .read = model.leagueReading else {
            Issue.record("expected a reading, got \(model.leagueReading)")
            return
        }
        #expect(model.leagueScreen.rows.count == 24)
        // The sample's own league fixtures are against sides the table does not hold; Buxton and Chester are in it.
        let named = model.leagueScreen.fixturesNotInTheTable
        #expect(named.contains { $0.hasPrefix("Buxton FC on ") })
        #expect(!named.contains { $0.hasPrefix("Buxton on ") || $0.hasPrefix("Chester on ") })
        let bare = try SampleData.modelWithLeague(repositoryRoot: Captures.repositoryRoot, format: false)
        #expect(bare.leagueScreen.sentences == [AdvisorText.noFormatLine])
    }

    @Test func theSamplesBuxtonFixtureCarriesTheTablesBaseAndTheBattlingLine() throws {
        let made = try SampleData.draftWithLeagueOpponent(repositoryRoot: Captures.repositoryRoot, opponent: "Buxton")
        let suggestion = try #require(made.model.suggestion(for: made.draft))
        #expect(suggestion.reasons.first?.hasSuffix(": 100") == true)
        #expect(suggestion.reasons.contains("Buxton are level on points with you (\u{00D7}1.2)"))
    }

    @Test func theLabelsAreThePlainWords() {
        #expect(AppModel.pasteTableTitle == "Paste table")
        #expect(AppModel.removeTableTitle == "Remove table")
        #expect(AppModel.useTheTableTitle == "Use the table")
        #expect(AppModel.leagueColumnHeadings == ["Pl", "W", "D", "L", "F", "A", "GD", "Pts"])
        #expect(AppModel.removeTableAlertTitle == "Remove the league table?")
        #expect(AppModel.removeTableAlertMessage == "The three numbers stay.")
        #expect(AppModel.cancelTitle == "Cancel")
    }
}
