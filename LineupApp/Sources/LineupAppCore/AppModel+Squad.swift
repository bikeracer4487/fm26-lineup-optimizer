import Foundation
import LineupEngine

extension AppModel {
    /// Every player in every squad, by name (then by key, for players who share one).
    public var players: [Player] {
        squad.book.allPlayers.sorted { ($0.name, $0.id.key) < ($1.name, $1.id.key) }
    }

    /// The club named in Settings, or else the one the squads show most.
    public var ownClub: String? {
        squad.book.ownClub(override: settings.clubOverride)
    }

    public var squadWarnings: [String] {
        squad.book.warnings(override: settings.clubOverride).map(ErrorDescriptions.describe)
    }

    /// Imports the rows on the clipboard as `squad`. On success the book takes them and `lastImport` summarises
    /// them; on any failure nothing changes and `lastImport` says why.
    public func importSquad(_ squad: Squad) {
        lastImport = attemptImport(squad)
    }

    private func attemptImport(_ target: Squad) -> ImportOutcome {
        let text: String, config: Data
        switch readClipboardAndConfig() {
        case .success(let read): (text, config) = read
        case .failure(let failure): return .failed(target, reason: failure.reason)
        }
        let result: ImportResult
        do {
            result = try Importer.importPlayers(clipboard: text, fmrteConfig: config, squad: target)
        } catch {
            return .failed(target, reason: ErrorDescriptions.describe(error))
        }

        var state = squad
        let change = state.book.apply(result, to: target)
        let date = settings.currentDate
        state.importedOn[target] = date
        squad = state
        save(.squad)
        // Read before the marks below are cleared: the reading includes the confirmed matches still awaiting this squad.
        recordFitness(after: target, on: date)
        // The new figures include every match played before the import, for this squad's players.
        if history.contains(where: { $0.awaitingImport.contains(target) }) {
            for index in history.indices { history[index].awaitingImport.remove(target) }
            save(.history)
        }
        recordFamiliarity(after: target, on: date)
        recordPersonality(after: target, on: date)
        dropSpentMarks(imported: target)
        replan()

        let onLoan = (state.book.current[target] ?? []).filter { player in
            switch state.book.loanStatus(of: player, override: settings.clubOverride) {
            case .loanedOut: true
            case .own, .loanedIn: false
            }
        }.map(\.name)
        return .imported(ImportSummary(
            squad: target, date: date, grid: result.grid, playerCount: result.players.count, money: result.money,
            onLoan: onLoan,
            warnings: result.warnings.map(ErrorDescriptions.describe) + unconfirmedBeforeToday, change: change))
    }

    /// A sentence for each fixture before the game's current date with no confirmed lineup, in date order. One from
    /// before the days Match Selection shows (`earlierMatchesBefore`) is left out: it is not there to be confirmed,
    /// and its starts would no longer count.
    private var unconfirmedBeforeToday: [String] {
        let confirmed = Set(history.map(\.lineup.fixture))
        let shownFrom = earlierMatchesBefore
        return fixtures.filter {
            $0.date < settings.currentDate && $0.date >= shownFrom && !confirmed.contains($0.id)
        }.map { fixture in
            "The match against \(fixture.opponent) on \(DayText.short(fixture.date)) has no confirmed lineup. "
                + "Confirm it in Match Selection so its starts count."
        }
    }

    /// A reason the clipboard rows and FMRTE's settings file could not be read, in plain words.
    struct ReadFailure: Error { let reason: String }

    static let emptyClipboardSentence = "The clipboard is empty. Copy the rows in FMRTE first."

    /// The rows on the clipboard and FMRTE's settings file, or why either could not be read. Shared by the squad
    /// import and the opponent's paste.
    func readClipboardAndConfig() -> Result<(text: String, config: Data), ReadFailure> {
        guard let text = environment.clipboard(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(ReadFailure(reason: Self.emptyClipboardSentence))
        }
        do {
            return .success((text, try environment.fmrteConfig(settings.fmrteConfigPath)))
        } catch {
            return .failure(ReadFailure(reason: describeConfigFailure(error)))
        }
    }

    /// A file that is not there names the path looked at; any other failure is the engine's sentence for an
    /// unreadable configuration.
    func describeConfigFailure(_ error: any Error) -> String {
        if let cocoa = error as? CocoaError, cocoa.code == .fileReadNoSuchFile || cocoa.code == .fileNoSuchFile {
            let path = cocoa.filePath ?? cocoa.url?.path ?? settings.fmrteConfigPath
            let place = path.map { "at \($0)" } ?? "in its usual place"
            return "FMRTE's settings file was not found \(place). Open FMRTE once, or set its location in Settings."
        }
        return ErrorDescriptions.describe(ImportError.configUnreadable(reason: error.localizedDescription))
    }
}
