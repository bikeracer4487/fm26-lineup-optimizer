import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

@MainActor @Suite struct LeagueTests {
    private func day(_ offset: Int) -> Day { TestModel.today.adding(days: offset) }

    /// A model with the first team, the club named, a tactic, and `league` fixtures against `opponents`, one a week
    /// from a week after today.
    private func ready(opponents: [String] = []) throws -> (TestModel, [FixtureID]) {
        let t = try ScoutingSetup.ready()
        var ids: [FixtureID] = []
        for (index, name) in opponents.enumerated() {
            let id = t.model.addFixture(date: day(7 * (index + 1)), opponent: name, importance: .medium)
            var fixture = try #require(t.model.fixtures.first { $0.id == id })
            fixture.competition = .league
            t.model.update(fixture)
            ids.append(id)
        }
        return (t, ids)
    }

    private func read(_ t: TestModel) throws {
        try t.pasteLeagueTable()
        t.model.setLeagueFormatDraft(LeagueFormatDraft(promoted: 1, playOffs: 6, relegated: 4))
    }

    @Test func aPasteIsKeptWithItsDayAndSaved() throws {
        let (t, _) = try ready()
        try t.pasteLeagueTable()
        #expect(t.model.league.table?.teams.count == 24)
        #expect(t.model.league.pastedOn == TestModel.today)
        #expect(t.model.leaguePasteProblem == nil)
        let reopened = t.reopened()
        #expect(reopened.league == t.model.league)
        #expect(reopened.notices.isEmpty)
    }

    @Test func aPasteDoesNotPlanAndClearsTheSuggestions() throws {
        let (t, ids) = try ready(opponents: ["Buxton", "Chester"])
        _ = t.model.suggestions
        #expect(t.model.adviceCache?.suggestions != nil)
        let chosen = t.model.fixtures.map(\.importance)
        let planned = t.model.timesPlanned
        try read(t)
        #expect(t.model.timesPlanned == planned)
        #expect(t.model.fixtures.map(\.importance) == chosen)
        #expect(t.model.adviceCache?.suggestions == nil)
        #expect(t.model.suggestions.keys.sorted { $0.raw < $1.raw } == ids.sorted { $0.raw < $1.raw })
        #expect(t.model.adviceCache?.suggestions != nil)
    }

    @Test func aRefusedPasteKeepsTheTableHeld() throws {
        let (t, _) = try ready()
        try t.pasteLeagueTable()
        let held = t.model.league
        t.input.clipboard = try Captures.firstTeam
        t.input.config = .data(try Captures.firstTeamGrids)
        t.model.pasteLeagueTable()
        let problem = try #require(t.model.leaguePasteProblem)
        #expect(problem == ErrorDescriptions.describe(LeagueTableError.noStandingsGrid))
        #expect(t.model.league == held)
        try t.pasteLeagueTable()
        #expect(t.model.leaguePasteProblem == nil)
    }

    @Test func anEmptyClipboardOrMissingSettingsFileIsRefusedInASentence() throws {
        let (t, _) = try ready()
        t.input.clipboard = "  "
        t.model.pasteLeagueTable()
        #expect(t.model.leaguePasteProblem == AppModel.emptyClipboardSentence)
        t.input.clipboard = try Captures.leagueTable
        t.input.config = .failure(CocoaError(.fileReadNoSuchFile))
        t.model.pasteLeagueTable()
        let problem = try #require(t.model.leaguePasteProblem)
        #expect(problem.hasPrefix("FMRTE's settings file was not found"))
        #expect(t.model.league.table == nil)
    }

    @Test func theFormatIsSavedOnlyWhenAllThreeAreEnteredAndFit() throws {
        let (t, _) = try ready()
        try t.pasteLeagueTable()
        t.model.setLeagueFormatDraft(LeagueFormatDraft(promoted: 1, playOffs: 6))
        #expect(t.model.league.format == nil)
        #expect(t.model.leagueFormatProblem == nil)
        t.model.setLeagueFormatDraft(LeagueFormatDraft(promoted: 1, playOffs: 6, relegated: 4))
        #expect(t.model.league.format == LeagueFormat(promoted: 1, playOffs: 6, relegated: 4))
        #expect(t.reopened().league.format == LeagueFormat(promoted: 1, playOffs: 6, relegated: 4))
        t.model.setLeagueFormatDraft(LeagueFormatDraft(promoted: 1, playOffs: 30, relegated: 4))
        let bad = LeagueFormat(promoted: 1, playOffs: 30, relegated: 4)
        #expect(t.model.leagueFormatProblem == ErrorDescriptions.describe(LeagueFormatError.tooMany(format: bad, teams: 24)))
        #expect(t.model.league.format == LeagueFormat(promoted: 1, playOffs: 6, relegated: 4))
        #expect(t.model.leagueFormatDraft.playOffs == 30)
    }

    @Test func theReadingNeedsATableAndAFormat() throws {
        let (t, _) = try ready()
        #expect(t.model.leagueReading == .noTable)
        try t.pasteLeagueTable()
        #expect(t.model.leagueReading == .noFormat)
        t.model.setLeagueFormatDraft(LeagueFormatDraft(promoted: 1, playOffs: 6, relegated: 4))
        guard case .read(let reading) = t.model.leagueReading else {
            Issue.record("expected a reading, got \(t.model.leagueReading)")
            return
        }
        #expect(reading.place == 5)
        #expect(t.model.leagueContext?.reading == reading)
    }

    @Test func theFirstReadingSwitchesTheMenuToTheTable() throws {
        let (t, _) = try ready()
        t.model.setLeagueSituation(.midTable)
        try read(t)
        #expect(t.model.settings.leagueSituation == nil)
        #expect(t.reopened().settings.leagueSituation == nil)
        #expect(t.model.leagueSituationSelection == nil)
    }

    @Test func aPasteBeforeTheFormatLeavesAChoiceByHand() throws {
        let (t, ids) = try ready(opponents: ["Rovers"])
        t.model.setLeagueSituation(.midTable)
        try t.pasteLeagueTable()
        #expect(t.model.settings.leagueSituation == .midTable)
        #expect(t.model.leagueSituationSelection == .midTable)
        #expect(t.model.suggestions[ids[0]]?.reasons.first == "League match, mid-table: 60")
    }

    @Test func aLaterPasteOrFormatChangeLeavesTheMenuAlone() throws {
        let (t, _) = try ready()
        try read(t)
        t.model.setLeagueSituation(.midTable)
        try t.pasteLeagueTable()
        t.model.setLeagueFormatDraft(LeagueFormatDraft(promoted: 1, playOffs: 4, relegated: 4))
        #expect(t.model.league.format == LeagueFormat(promoted: 1, playOffs: 4, relegated: 4))
        #expect(t.model.settings.leagueSituation == .midTable)
        #expect(t.model.leagueSituationSelection == .midTable)
    }

    @Test func removingTheTableKeepsTheFormatAndTheChoice() throws {
        let (t, _) = try ready()
        try read(t)
        t.model.setLeagueSituation(.midTable)
        t.model.removeLeagueTable()
        #expect(t.model.league.table == nil)
        #expect(t.model.league.pastedOn == nil)
        #expect(t.model.league.format == LeagueFormat(promoted: 1, playOffs: 6, relegated: 4))
        #expect(t.model.settings.leagueSituation == .midTable)
        #expect(t.model.leagueSituationSelection == .midTable)
        #expect(t.model.leagueReading == .noTable)
        try t.pasteLeagueTable()
        #expect(t.model.settings.leagueSituation == nil)
    }

    @Test func theSuggestionsUseTheTable() throws {
        let (t, ids) = try ready(opponents: ["Buxton", "Chester", "Rovers"])
        let before = ids.map { t.model.suggestions[$0]?.reasons.first }
        #expect(before.allSatisfy { $0 == "League match: 80" })
        try read(t)
        let after = try ids.map { try #require(t.model.suggestions[$0]) }
        let reading = try #require(t.model.leagueContext?.reading)
        let base = AdvisorText.leagueBaseReason(reading)
        for suggestion in after { #expect(suggestion.reasons.first?.hasPrefix(base) == true) }
        // Buxton is level with the club on points; Rovers is not in the table.
        let battling = after.map { $0.reasons.contains { $0.hasPrefix("Buxton are ") } }
        #expect(battling[0] == true)
        #expect(battling[2] == false)
    }

    @Test func fixturesBeyondTheMatchesLeftAreReadWithoutIt() throws {
        let (t, ids) = try ready(opponents: ["Buxton", "Chester", "Rovers", "Town", "City"])
        try read(t)
        let left = try #require(t.model.leagueContext?.reading.matchesLeft)
        #expect(left == 3)
        #expect(t.model.leagueContext?.speaksFor == Set(ids.prefix(3)))
        #expect(t.model.suggestions[ids[3]]?.reasons.first == "League match: 80")
        #expect(t.model.suggestions[ids[4]]?.reasons.first == "League match: 80")
        #expect(t.model.leagueFixturesBeyondTheTable == 2)
    }

    @Test func theDraftsSuggestionUsesTheTableToo() throws {
        let (t, _) = try ready()
        try read(t)
        var draft = t.model.newFixtureDraft()
        draft.opponent = "Buxton"
        draft.date = day(1)
        draft.competition = Competition.league
        let note = try #require(t.model.suggestionNote(for: draft))
        #expect(note.reasons.contains { $0.hasPrefix("Buxton are ") })
        // The same draft with no table is a plain league match.
        t.model.removeLeagueTable()
        #expect(try #require(t.model.suggestionNote(for: draft)).reasons.first == "League match: 80")
    }

    @Test func theTableIsOutOfDateOnceALeagueMatchIsConfirmedAfterIt() throws {
        let (t, ids) = try ready(opponents: ["Buxton"])
        let cup = t.model.addFixture(date: day(3), opponent: "Town", importance: .medium)
        var cupFixture = try #require(t.model.fixtures.first { $0.id == cup })
        cupFixture.competition = .cup
        t.model.update(cupFixture)
        try read(t)
        #expect(!t.model.leagueTableIsOutOfDate)
        var settings = t.model.settings
        settings.currentDate = day(3)
        t.model.update(settings)
        t.model.confirm(cup)
        #expect(!t.model.leagueTableIsOutOfDate)
        settings.currentDate = day(7)
        t.model.update(settings)
        t.model.confirm(ids[0])
        #expect(t.model.history.contains { $0.lineup.fixture == ids[0] })
        #expect(t.model.leagueTableIsOutOfDate)
    }

    @Test func aClubNoLongerInTheTableStopsTheReadingAndSaysSo() throws {
        let (t, ids) = try ready(opponents: ["Buxton"])
        try read(t)
        var settings = t.model.settings
        settings.clubName = "Banbury United"
        t.model.update(settings)
        let table = try #require(t.model.league.table)
        guard case .failed(let sentence) = t.model.leagueReading else {
            Issue.record("expected a failure, got \(t.model.leagueReading)")
            return
        }
        #expect(sentence == ErrorDescriptions.describe(LeagueTableError.clubNotInTable(club: "Banbury United", teams: table.teams.count)))
        #expect(t.model.leagueContext == nil)
        #expect(t.model.suggestions[ids[0]]?.reasons.first == "League match: 80")
        settings.clubName = "Oxford City"
        t.model.update(settings)
        guard case .read = t.model.leagueReading else {
            Issue.record("expected a reading, got \(t.model.leagueReading)")
            return
        }
    }

    @Test func aTableTheFormatDoesNotFitIsKeptAndSaysSo() throws {
        let (t, _) = try ready()
        try read(t)
        // Ten teams, places 1 to 10, each with wins, draws and losses that add up to the matches played.
        var rows: [String] = []
        for place in 1...10 {
            let name = place == 4 ? "Oxford City" : "Team \(place)"
            let (played, wins, draws, losses) = (18, 10 - place / 2, 3, 5 + place / 2)
            #expect(wins + draws + losses == played)
            rows.append(["\(place)", name, "\(played)", "\(wins)", "\(draws)", "\(losses)", "\(wins * 2)", "\(losses)",
                         "\(wins * 3 + draws)"].map { "\"\($0)\"" }.joined(separator: "\t"))
        }
        try t.pasteLeagueTable(rows.joined(separator: "\n"))
        #expect(t.model.leaguePasteProblem == nil)
        #expect(t.model.league.table?.teams.count == 10)
        let format = LeagueFormat(promoted: 1, playOffs: 6, relegated: 4)
        guard case .failed(let sentence) = t.model.leagueReading else {
            Issue.record("expected a failure, got \(t.model.leagueReading)")
            return
        }
        #expect(sentence == ErrorDescriptions.describe(LeagueFormatError.tooMany(format: format, teams: 10)))
        #expect(t.model.leagueContext == nil)
    }

    @Test func theMenuOffersTheTableOnlyWhileThereIsAReading() throws {
        let (t, _) = try ready()
        #expect(t.model.leagueSituationChoices.count == 4)
        t.model.setLeagueSituation(nil)
        #expect(t.model.settings.situation == .inContention)
        try read(t)
        let choices = t.model.leagueSituationChoices
        #expect(choices.count == 5)
        #expect(choices.first?.value == nil)
        let reading = try #require(t.model.leagueContext?.reading)
        #expect(choices.first?.title == AdvisorText.fromTheTable(reading.situation))
        t.model.setLeagueSituation(.midTable)
        t.model.setLeagueSituation(nil)
        #expect(t.model.settings.leagueSituation == nil)
    }

    @Test func anOlderStateOpensWithNoNoticeAndTheSameSuggestions() throws {
        let (t, ids) = try ready(opponents: ["Buxton"])
        try FileManager.default.removeItem(at: t.directory.appendingPathComponent("league.json"))
        let reopened = t.reopened()
        #expect(reopened.notices.isEmpty)
        #expect(reopened.leagueReading == .noTable)
        #expect(reopened.suggestions[ids[0]]?.reasons.first == "League match: 80")
    }
}
