import Foundation
import LineupEngine

extension AppModel {
    // MARK: Paste, remove, format

    /// Reads the league table off the clipboard and keeps it with today in the game. On a refusal the table held stays,
    /// and `leaguePasteProblem` says why. A paste does not plan: it clears the kept suggestions and nothing else.
    public func pasteLeagueTable() {
        let text: String, config: Data
        switch readClipboardAndConfig() {
        case .success(let read): (text, config) = read
        case .failure(let failure):
            leaguePasteProblem = failure.reason
            return
        }
        let table: LeagueTable
        do {
            table = try LeagueTableImporter.read(clipboard: text, fmrteConfig: config, ownClub: ownClub,
                                                 parameters: planParameters)
        } catch {
            leaguePasteProblem = ErrorDescriptions.describe(error)
            return
        }
        let hadReading = leagueIsRead
        league.table = table
        league.pastedOn = settings.currentDate
        leaguePasteProblem = nil
        save(.league)
        leagueChanged(hadReading: hadReading)
    }

    /// Takes the table off; the format and the choice by hand stay.
    public func removeLeagueTable() {
        guard league.table != nil else { return }
        let hadReading = leagueIsRead
        league.table = nil
        league.pastedOn = nil
        leaguePasteProblem = nil
        save(.league)
        leagueChanged(hadReading: hadReading)
    }

    /// Keeps the draft. With all three entered the format is checked against the held table and saved when it fits;
    /// when it does not, `leagueFormatProblem` says why and the saved format stays.
    public func setLeagueFormatDraft(_ draft: LeagueFormatDraft) {
        leagueFormatDraft = draft
        guard let format = draft.format else {
            leagueFormatProblem = nil
            return
        }
        do {
            try format.check(teams: league.table?.teams.count)
        } catch {
            leagueFormatProblem = ErrorDescriptions.describe(error)
            return
        }
        leagueFormatProblem = nil
        guard league.format != format else { return }
        let hadReading = leagueIsRead
        league.format = format
        save(.league)
        leagueChanged(hadReading: hadReading)
    }

    /// The first reading switches the League situation menu to the table; every change clears the kept suggestions.
    /// It never plans.
    private func leagueChanged(hadReading: Bool) {
        if !hadReading, leagueIsRead, settings.leagueSituation != nil {
            settings.leagueSituation = nil
            save(.settings)
        }
        adviceCache?.suggestions = nil
        // A problem found against the old table says nothing about the new one; a saved format that no longer fits the
        // new table still shows through the reading's own failure.
        leagueFormatProblem = nil
    }

    private var leagueIsRead: Bool {
        if case .read = leagueReading { return true }
        return false
    }

    // MARK: Reading

    /// The reading, worked out from the state each time it is asked for.
    public var leagueReading: LeagueReadingState {
        guard let table = league.table else { return .noTable }
        guard let format = league.format else { return .noFormat }
        guard let club = ownClub else { return .failed(ErrorDescriptions.describe(LeagueTableError.noClubKnown)) }
        do {
            return .read(try League.read(table: table, format: format, club: club, parameters: planParameters))
        } catch {
            return .failed(ErrorDescriptions.describe(error))
        }
    }

    /// The reading and the fixtures it speaks for; nil unless the table and format are read. `draft` stands in for the
    /// saved fixture of its id, or is added when there is none, as the fixture editor's suggestion is worked out.
    func makeLeagueContext(draft: (id: FixtureID, date: Day, competition: Competition?)? = nil) -> LeagueContext? {
        guard case .read(let reading) = leagueReading, let pastedOn = league.pastedOn else { return nil }
        let confirmed = Set(history.map(\.lineup.fixture))
        var fixtures = self.fixtures.filter { $0.id != draft?.id && $0.competition == .league }
            .map { (id: $0.id, date: $0.date, isConfirmed: confirmed.contains($0.id)) }
        if let draft, draft.competition == .league { fixtures.append((id: draft.id, date: draft.date, isConfirmed: false)) }
        return LeagueContext(reading: reading, speaksFor: League.spokenFor(
            matchesLeft: reading.matchesLeft, pastedOn: pastedOn, leagueFixtures: fixtures))
    }

    var leagueContext: LeagueContext? { makeLeagueContext(draft: nil) }

    /// A league match with a confirmed lineup is dated after the day the table was pasted: the table is behind.
    public var leagueTableIsOutOfDate: Bool {
        guard let pastedOn = league.pastedOn else { return false }
        let confirmed = Set(history.map(\.lineup.fixture))
        return fixtures.contains { $0.competition == .league && confirmed.contains($0.id) && $0.date > pastedOn }
    }

    /// League fixtures still to play, from the day of the paste, that the table has no match left for.
    public var leagueFixturesBeyondTheTable: Int {
        guard let context = leagueContext, let pastedOn = league.pastedOn else { return 0 }
        let confirmed = Set(history.map(\.lineup.fixture))
        return fixtures.filter {
            $0.competition == .league && !confirmed.contains($0.id) && $0.date >= pastedOn
                && !context.speaksFor.contains($0.id)
        }.count
    }

    // MARK: The menu

    /// The owner's word on where the club stands; nil takes it from the table, and is accepted only while the table
    /// is read. It changes the suggested importance of league matches only: nothing is planned or advised again.
    public func setLeagueSituation(_ situation: LeagueSituation?) {
        if situation == nil { guard case .read = leagueReading else { return } }
        settings.leagueSituation = situation
        save(.settings)
        adviceCache?.suggestions = nil
    }

    /// The League situation menu: with a reading, "From the table" first, then the four in the engine's words.
    public var leagueSituationChoices: [(value: LeagueSituation?, title: String)] {
        let four: [(value: LeagueSituation?, title: String)] = LeagueSituation.allCases.map { ($0, AdvisorText.name($0)) }
        guard case .read(let reading) = leagueReading else { return four }
        return [(nil, AdvisorText.fromTheTable(reading.situation))] + four
    }

    /// What the menu shows: the owner's choice, nil being "From the table" while there is a reading.
    public var leagueSituationSelection: LeagueSituation? {
        if case .read = leagueReading { return settings.leagueSituation }
        return settings.situation
    }
}
