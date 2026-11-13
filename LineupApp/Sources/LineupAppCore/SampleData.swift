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
        if case .failed(let reason)? = model.lastImport {
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
        // Nothing confirms a lineup yet, so the record is added to the history directly.
        record.lineup.fixture = first.id
        record.lineup.date = first.date
        model.history.append(record)
        model.save(.history)
        var settings = model.settings
        settings.currentDate = Day(year: 2026, month: 11, day: 18)!
        model.update(settings)
        return model
    }

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

    @MainActor private static func build(repositoryRoot: URL) throws -> (model: AppModel, input: ScriptedInput) {
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

        for (squad, paste, grids) in [(Squad.firstTeam, "first-team.tsv", "first-team.grids.json"),
                                      (.u21, "u21.tsv", "u21.grids.json")] {
            input.clipboard = String(decoding: try data("captures/\(paste)"), as: UTF8.self)
            input.config = .data(try data("captures/\(grids)"))
            model.importSquad(squad)
            if case .failed(let reason)? = model.lastImport {
                throw SampleDataError(description: "The sample \(paste) could not be imported: \(reason)")
            }
        }
        if model.ownClub == nil {
            var settings = model.settings
            settings.clubName = clubName
            model.update(settings)
        }

        let tactic = try decode(Tactic.self, "tactics/sample-4231.json")
        let tacticID = model.addTactic(named: tactic.name)
        model.update(StoredTactic(id: tacticID, tactic: tactic))
        for fixture in try decode([SampleFixture].self, "plans/sample-fixtures.json") {
            model.addFixture(date: fixture.date, opponent: fixture.opponent, importance: fixture.importance)
        }

        // Nothing adds a confirmed lineup yet, so the history is saved directly and the model is loaded again.
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
        return (AppModel(store: store, environment: input.environment), input)
    }
}
