import Foundation
import Synchronization
import LineupEngine

/// An environment whose clipboard and FMRTE settings file are set by code, for the sample data and the tests.
final class ScriptedInput: Sendable {
    enum Config: Sendable {
        case data(Data)
        /// Reads the file at the path the model asks for, or at `otherwise` when it asks for the usual place.
        case readFile(otherwise: String)
        case failure(any Error)
    }

    private struct State {
        var clipboard: String?
        var config: Config
    }

    let today: Day
    private let state: Mutex<State>

    init(today: Day, clipboard: String? = nil, config: Config = .data(Data())) {
        self.today = today
        self.state = Mutex(State(clipboard: clipboard, config: config))
    }

    var clipboard: String? {
        get { state.withLock { $0.clipboard } }
        set { state.withLock { $0.clipboard = newValue } }
    }

    var config: Config {
        get { state.withLock { $0.config } }
        set { state.withLock { $0.config = newValue } }
    }

    var environment: AppEnvironment {
        AppEnvironment(
            today: { [today] in today },
            clipboard: { self.clipboard },
            fmrteConfig: { path in
                switch self.config {
                case .data(let data): return data
                case .readFile(let otherwise): return try Data(contentsOf: URL(fileURLWithPath: path ?? otherwise))
                case .failure(let error): throw error
                }
            })
    }
}

/// Why the sample data could not be built, in plain words.
public struct SampleDataError: Error, Equatable, CustomStringConvertible {
    public let description: String
}

public enum SampleData {
    /// The date the sample squads were exported, used as today and as the import date.
    static let date = Day(year: 2026, month: 11, day: 13)!
    /// The captures come from a team grid with no club column, so the club is named.
    static let clubName = "Oxford City"

    private struct SampleFixture: Decodable {
        let date: Day
        let opponent: String
        let importance: Importance
    }

    /// A model on a temporary directory, filled from the engine's captures under `repositoryRoot`:
    /// both squads, the sample 4-2-3-1 as the primary tactic, the five sample fixtures and the sample history.
    @MainActor public static func model(repositoryRoot: URL) throws -> AppModel {
        try build(repositoryRoot: repositoryRoot).model
    }

    /// The sample model after an import of text that is not FMRTE rows: the squads are unchanged and
    /// `lastImport` says why the import failed.
    @MainActor public static func modelWithFailedImport(repositoryRoot: URL) throws -> AppModel {
        let (model, input) = try build(repositoryRoot: repositoryRoot)
        input.clipboard = "Oxford City 2 Banbury United 1"
        model.importSquad(.firstTeam)
        return model
    }

    /// The sample model after the first team is imported again from the capture of the same squad taken with
    /// FMRTE's `Id` column, so `lastImport` reports a second import: each player now keyed by his FMRTE id.
    @MainActor public static func modelAfterImport(repositoryRoot: URL) throws -> AppModel {
        let (model, input) = try build(repositoryRoot: repositoryRoot)
        input.clipboard = String(decoding: try fixture("captures/first-team-with-id.tsv", under: repositoryRoot), as: UTF8.self)
        input.config = .data(try fixture("captures/first-team-with-id.grids.json", under: repositoryRoot))
        model.importSquad(.firstTeam)
        if case .failed(_, let reason)? = model.lastImport {
            throw SampleDataError(description: "The sample first-team-with-id.tsv could not be imported: \(reason)")
        }
        return model
    }

    /// The sample model with its tactic saved without the in-possession striker, so the tactic has a problem:
    /// ten in-possession slots, and an out-of-possession striker nothing turns into.
    @MainActor public static func modelWithTacticProblem(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        guard var stored = model.tactics.first else {
            throw SampleDataError(description: "The sample model has no tactic.")
        }
        var draft = TacticDraft(stored.tactic)
        draft.toggle(.ST_C, in: .inPossession, catalog: model.catalog)
        stored.tactic = draft.tactic
        model.update(stored)
        return model
    }

    /// The sample model with an unsaved change to its tactic: the inside forward on the left made a winger.
    @MainActor public static func modelWithUnsavedTacticChange(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        guard let id = model.tactics.first?.id, var draft = model.draft(for: id) else {
            throw SampleDataError(description: "The sample model has no tactic.")
        }
        draft.setRole("Winger", at: .AM_L, in: .inPossession)
        model.setDraft(draft, for: id)
        return model
    }

    /// The sample model five days on, on 18 November, with a lineup confirmed for the first fixture (the starters of
    /// the last sample lineup) and none for the second, so one fixture before today is confirmed and one is not.
    @MainActor public static func modelWithPastFixtures(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        guard model.fixtures.count >= 2, let first = model.fixtures.first, var record = model.history.last else {
            throw SampleDataError(description: "The sample model has too few fixtures or no confirmed lineup.")
        }
        // The record holds the last sample lineup's starters, not the planned ones, so it is added to the history directly.
        record.lineup.fixture = first.id
        record.lineup.date = first.date
        model.history.append(record)
        model.save(.history)
        model.replan()
        var settings = model.settings
        settings.currentDate = Day(year: 2026, month: 11, day: 18)!
        model.update(settings)
        return model
    }

    /// The sample model with a lineup confirmed for the first fixture, as Match Selection's "Confirm this lineup"
    /// records it.
    @MainActor public static func modelAfterConfirmingFirst(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        guard let first = model.fixtures.first, model.canConfirm(first.id) else {
            throw SampleDataError(description: "The sample model's first fixture cannot be confirmed.")
        }
        model.confirm(first.id)
        return model
    }

    /// The sample model with the owner's choices in the first fixture: the best available U21 player fixed at AM C,
    /// the injured goalkeeper fixed in goal (an override the engine cannot use) and the striker left out.
    @MainActor public static func modelWithChoices(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        guard let first = model.fixtures.first,
              let youth = model.candidates(for: .AM_C, in: first.id).first(where: { $0.squad == .u21 && $0.unavailable == nil }),
              let injured = model.players.first(where: { $0.name == "Jonny Maxted" && $0.isInjured }),
              let striker = model.players.first(where: { $0.name == "Tyrone Marsh" }) else {
            throw SampleDataError(description: "The sample model lacks a fixture, a U21 player, its injured goalkeeper or its striker.")
        }
        model.setOverride(youth.player, at: .AM_C, in: first.id)
        model.setOverride(injured.id, at: .GK, in: first.id)
        model.reject(striker.id, in: first.id)
        return model
    }

    /// The sample model with an unconfirmed fixture on 12 November, the day before the squads were imported: a
    /// missed fixture.
    @MainActor public static func modelWithMissedFixture(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        model.addFixture(date: Day(year: 2026, month: 11, day: 12)!, opponent: "Opponent Z", importance: .medium)
        return model
    }

    /// The sample model two days on, on 15 November, with both squads imported again that day and the first fixture,
    /// on 14 November, never confirmed: a missed fixture with the eleven last planned for it remembered.
    @MainActor public static func modelWithMissedEleven(repositoryRoot: URL) throws -> AppModel {
        let (model, input) = try build(repositoryRoot: repositoryRoot)
        model.moveToday(by: 2)
        for (squad, paste, grids) in samplePastes {
            input.clipboard = String(decoding: try fixture("captures/\(paste)", under: repositoryRoot), as: UTF8.self)
            input.config = .data(try fixture("captures/\(grids)", under: repositoryRoot))
            model.importSquad(squad)
            if case .failed(_, let reason)? = model.lastImport {
                throw SampleDataError(description: "The sample \(paste) could not be imported: \(reason)")
            }
        }
        model.dismissImport()
        return model
    }

    /// The sample model with a second fixture on 17 November, so the plan stops: a club plays one match a day.
    @MainActor public static func modelWithTwoMatchesOnOneDay(repositoryRoot: URL) throws -> AppModel {
        let model = try build(repositoryRoot: repositoryRoot).model
        model.addFixture(date: Day(year: 2026, month: 11, day: 17)!, opponent: "Opponent F", importance: .low)
        return model
    }

    /// The sample squads' pastes and grid layouts, in the order they are imported.
    private static let samplePastes = [(Squad.firstTeam, "first-team.tsv", "first-team.grids.json"),
                                       (Squad.u21, "u21.tsv", "u21.grids.json")]

    /// A model with nothing in it, on a new temporary directory, whose clipboard is empty.
    @MainActor public static func emptyModel() -> AppModel {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lineup-empty-\(UUID().uuidString)")
        return AppModel(store: Store(directory: directory), environment: ScriptedInput(today: date).environment)
    }

    /// The engine's test fixture at `path` under `repositoryRoot`.
    private static func fixture(_ path: String, under repositoryRoot: URL) throws -> Data {
        let url = repositoryRoot.appendingPathComponent("LineupEngine/Tests/LineupEngineTests/Fixtures").appendingPathComponent(path)
        guard let data = FileManager.default.contents(atPath: url.path) else {
            throw SampleDataError(description: "The sample file \(url.path) could not be read.")
        }
        return data
    }

    /// A sample built and saved, with what the clipboard and FMRTE's settings file held at the end.
    private struct Built {
        let directory: URL
        let clipboard: String?
        let config: ScriptedInput.Config
    }

    /// The sample built from each repository root. Building plans the fixtures after every step, so it is done once
    /// and its files are copied for each model asked for.
    @MainActor private static var built: [URL: Built] = [:]

    /// A model on a new temporary directory holding a copy of the sample's files, with the clipboard and FMRTE's
    /// settings file as the sample's last import left them.
    @MainActor private static func build(repositoryRoot: URL) throws -> (model: AppModel, input: ScriptedInput) {
        let sample = try built[repositoryRoot] ?? buildOnce(repositoryRoot: repositoryRoot)
        built[repositoryRoot] = sample
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lineup-sample-\(UUID().uuidString)")
        do {
            try FileManager.default.copyItem(at: sample.directory, to: directory)
        } catch {
            throw SampleDataError(description: "The sample data could not be copied to \(directory.path): \(error.localizedDescription)")
        }
        let input = ScriptedInput(today: date, clipboard: sample.clipboard, config: sample.config)
        return (AppModel(store: Store(directory: directory), environment: input.environment), input)
    }

    /// Builds the sample on a temporary directory of its own, which `build` copies.
    @MainActor private static func buildOnce(repositoryRoot: URL) throws -> Built {
        func data(_ path: String) throws -> Data { try fixture(path, under: repositoryRoot) }
        func decode<T: Decodable>(_ type: T.Type, _ path: String) throws -> T {
            do {
                return try JSONDecoder().decode(type, from: data(path))
            } catch let error as DecodingError {
                throw SampleDataError(description: "The sample file \(path) is not valid: \(ErrorDescriptions.describe(error))")
            }
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("lineup-sample-\(UUID().uuidString)")
        let store = Store(directory: directory)
        let input = ScriptedInput(today: date)
        let model = AppModel(store: store, environment: input.environment)

        for (squad, paste, grids) in samplePastes {
            input.clipboard = String(decoding: try data("captures/\(paste)"), as: UTF8.self)
            input.config = .data(try data("captures/\(grids)"))
            model.importSquad(squad)
            if case .failed(_, let reason)? = model.lastImport {
                throw SampleDataError(description: "The sample \(paste) could not be imported: \(reason)")
            }
        }
        if model.ownClub == nil {
            var settings = model.settings
            settings.clubName = clubName
            model.update(settings)
        }

        // The fixtures come before the tactic, so the fixtures are planned only once there is a tactic to plan them with.
        for fixture in try decode([SampleFixture].self, "plans/sample-fixtures.json") {
            model.addFixture(date: fixture.date, opponent: fixture.opponent, importance: fixture.importance)
        }
        let tactic = try decode(Tactic.self, "tactics/sample-4231.json")
        let tacticID = model.addTactic(named: tactic.name)
        model.update(StoredTactic(id: tacticID, tactic: tactic))

        // These matches have no saved fixture, so they cannot be confirmed: the history is saved directly, and the
        // models made from these files load it.
        let names = Dictionary(model.players.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let history = try decode([ConfirmedLineup].self, "plans/sample-history.json").map { lineup in
            ConfirmedRecord(
                lineup: lineup,
                names: names.filter { id, _ in lineup.starters.values.contains(id) },
                tacticName: tactic.name)
        }
        try store.save(history, to: .history)
        if let notice = model.notices.first {
            throw SampleDataError(description: "The sample data could not be built: \(notice.text)")
        }
        return Built(directory: directory, clipboard: input.clipboard, config: input.config)
    }
}
