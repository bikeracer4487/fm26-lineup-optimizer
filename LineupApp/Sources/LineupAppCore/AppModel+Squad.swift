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
        guard let text = environment.clipboard(), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failed(target, reason: "The clipboard is empty. Copy the rows in FMRTE first.")
        }
        let config: Data
        do {
            config = try environment.fmrteConfig(settings.fmrteConfigPath)
        } catch {
            return .failed(target, reason: describeConfigFailure(error))
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
        // The new figures include every match played before the import, for this squad's players.
        if history.contains(where: { $0.awaitingImport.contains(target) }) {
            for index in history.indices { history[index].awaitingImport.remove(target) }
            save(.history)
        }
        replan()

        let onLoan = (state.book.current[target] ?? []).filter { player in
            switch state.book.loanStatus(of: player, override: settings.clubOverride) {
            case .loanedOut: true
            case .own, .loanedIn: false
            }
        }.map(\.name)
        return .imported(ImportSummary(
            squad: target, date: date, grid: result.grid, playerCount: result.players.count, onLoan: onLoan,
            warnings: result.warnings.map(ErrorDescriptions.describe) + unconfirmedBeforeToday, change: change))
    }

    /// A sentence for each fixture before the game's current date with no confirmed lineup, in date order.
    private var unconfirmedBeforeToday: [String] {
        let confirmed = Set(history.map(\.lineup.fixture))
        return fixtures.filter { $0.date < settings.currentDate && !confirmed.contains($0.id) }.map { fixture in
            "The match against \(fixture.opponent) on \(DayText.short(fixture.date)) has no confirmed lineup. "
                + "Confirm it in Match Selection so its starts count."
        }
    }

    /// A file that is not there names the path looked at; any other failure is the engine's sentence for an
    /// unreadable configuration.
    private func describeConfigFailure(_ error: any Error) -> String {
        if let cocoa = error as? CocoaError, cocoa.code == .fileReadNoSuchFile || cocoa.code == .fileNoSuchFile {
            let path = cocoa.filePath ?? cocoa.url?.path ?? settings.fmrteConfigPath
            let place = path.map { "at \($0)" } ?? "in its usual place"
            return "FMRTE's settings file was not found \(place). Open FMRTE once, or set its location in Settings."
        }
        return ErrorDescriptions.describe(ImportError.configUnreadable(reason: error.localizedDescription))
    }
}
