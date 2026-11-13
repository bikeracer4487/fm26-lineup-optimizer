import Foundation
import Synchronization
import LineupEngine
@testable import LineupAppCore

/// The engine's captured FMRTE pastes and their grid layouts.
enum Captures {
    static let repositoryRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()   // Support
        .deletingLastPathComponent()   // LineupAppCoreTests
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // LineupApp
        .deletingLastPathComponent()

    static let directory = repositoryRoot.appendingPathComponent("LineupEngine/Tests/LineupEngineTests/Fixtures/captures")

    static func text(_ name: String) throws -> String {
        try String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8)
    }

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: directory.appendingPathComponent(name))
    }

    static var firstTeam: String { get throws { try text("first-team.tsv") } }
    static var firstTeamGrids: Data { get throws { try data("first-team.grids.json") } }
    static var u21: String { get throws { try text("u21.tsv") } }
    static var u21Grids: Data { get throws { try data("u21.grids.json") } }
}

/// A model on a new temporary directory with a scripted environment; the directory is removed when this is freed.
@MainActor final class TestModel {
    static let today = Day(year: 2026, month: 11, day: 13)!

    let directory: URL
    let input: ScriptedInput
    let model: AppModel

    init(today: Day = TestModel.today) throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("app-model-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        input = ScriptedInput(today: today)
        model = AppModel(store: Store(directory: directory), environment: input.environment)
    }

    /// A second model on the same directory, as the app would load it on its next start.
    func reopened() -> AppModel {
        AppModel(store: Store(directory: directory), environment: input.environment)
    }

    /// Puts the paste and its grid layout where the model reads them, then imports.
    func importSquad(_ squad: Squad, paste: String, grids: Data) {
        input.clipboard = paste
        input.config = .data(grids)
        model.importSquad(squad)
    }

    func importFirstTeam() throws { importSquad(.firstTeam, paste: try Captures.firstTeam, grids: try Captures.firstTeamGrids) }
    func importU21() throws { importSquad(.u21, paste: try Captures.u21, grids: try Captures.u21Grids) }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }
}

/// Which files a store refuses to save, changed by a test as it goes.
final class Refusals: Sendable {
    struct Refused: Error {}
    private let refused = Mutex<Set<StoreFile>>([])

    var files: Set<StoreFile> {
        get { refused.withLock { $0 } }
        set { refused.withLock { $0 = newValue } }
    }

    func error(for file: StoreFile) -> (any Error)? {
        files.contains(file) ? Refused() : nil
    }
}
