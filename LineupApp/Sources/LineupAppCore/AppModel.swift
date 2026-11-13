import Foundation
import Observation
import LineupEngine

/// A message for the owner that stays until dismissed.
public struct Notice: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let text: String

    public init(text: String) {
        self.id = UUID(); self.text = text
    }
}

/// What one successful import did.
public struct ImportSummary: Equatable, Sendable {
    public let squad: Squad
    /// The FMRTE grid recognised.
    public let grid: String
    public let playerCount: Int
    /// Names of players out on loan, in the order of the paste.
    public let onLoan: [String]
    /// The engine's sentences for the import's warnings.
    public let warnings: [String]
    public let change: SquadChange

    public init(squad: Squad, grid: String, playerCount: Int, onLoan: [String], warnings: [String], change: SquadChange) {
        self.squad = squad; self.grid = grid; self.playerCount = playerCount
        self.onLoan = onLoan; self.warnings = warnings; self.change = change
    }
}

public enum ImportOutcome: Equatable, Sendable {
    case imported(ImportSummary)
    case failed(String)
}

/// What the model reads from outside its files: the date, the clipboard and FMRTE's settings file.
/// Not called "Environment", which SwiftUI already uses.
public struct AppEnvironment: Sendable {
    public var today: @Sendable () -> Day
    public var clipboard: @Sendable () -> String?
    /// The contents of FMRTE's settings file at the path, or at its usual place when the path is nil.
    public var fmrteConfig: @Sendable (_ path: String?) throws -> Data

    public init(
        today: @escaping @Sendable () -> Day,
        clipboard: @escaping @Sendable () -> String?,
        fmrteConfig: @escaping @Sendable (_ path: String?) throws -> Data
    ) {
        self.today = today; self.clipboard = clipboard; self.fmrteConfig = fmrteConfig
    }
}

/// The app's state, which every screen reads and changes through its actions. Each action that changes
/// state saves the file concerned before it returns.
@MainActor @Observable public final class AppModel {
    public internal(set) var squad: SquadState
    public internal(set) var tactics: [StoredTactic]
    /// In date order, then by id.
    public internal(set) var fixtures: [StoredFixture]
    public internal(set) var history: [ConfirmedRecord]
    public internal(set) var settings: AppSettings
    public internal(set) var notices: [Notice]
    public internal(set) var lastImport: ImportOutcome?
    /// The plan for the saved fixtures, worked out again by every action that changes what it depends on.
    public private(set) var planState: PlanState
    /// Unsaved changes to saved tactics, by tactic id: held only while the app is open, never written to disk.
    var tacticDrafts: [UUID: TacticDraft] = [:]
    public let catalog: RoleCatalog
    /// The rating profile the plan is made with: the engine's standard one.
    let profile: RatingProfile

    @ObservationIgnored let store: Store
    @ObservationIgnored let environment: AppEnvironment

    public init(store: Store, environment: AppEnvironment) {
        self.store = store
        self.environment = environment
        let catalog: RoleCatalog
        do {
            catalog = try RoleCatalog.fm27()
        } catch {
            fatalError("The engine's role list could not be loaded: the app was built without the engine's resources.")
        }
        self.catalog = catalog
        do {
            profile = try RatingProfile.standard()
        } catch {
            fatalError("The engine's rating profile could not be loaded: the app was built without the engine's resources.")
        }

        // Files not on disk are written once loaded, so a later start does not report them missing.
        let missing = StoreFile.allCases.filter { !store.exists($0) }
        let settings = store.load(.settings, as: AppSettings.self, otherwise: AppSettings(currentDate: environment.today()))
        let tactics = store.load(.tactics, as: [StoredTactic].self, otherwise: [])
        let fixtures = store.load(.fixtures, as: [StoredFixture].self, otherwise: [])
        let history = store.load(.history, as: [ConfirmedRecord].self, otherwise: [])
        let squad = store.load(.squad, as: SquadState.self, otherwise: SquadState())
        self.settings = settings.value
        self.tactics = tactics.value
        self.fixtures = fixtures.value.sorted(by: Self.dateOrder)
        self.history = history.value
        self.squad = squad.value
        self.notices = [settings.notice, tactics.notice, fixtures.notice, history.notice, squad.notice]
            .compactMap { $0 }.map(Notice.init(text:))
        self.lastImport = nil
        self.planState = .needsSquad
        for file in missing { save(file) }
        replan()
    }

    public func dismiss(_ notice: Notice) {
        notices.removeAll { $0.id == notice.id }
    }

    /// Fixtures by date, then by id, so the order never depends on how they were added.
    static func dateOrder(_ a: StoredFixture, _ b: StoredFixture) -> Bool {
        (a.date, a.id.raw) < (b.date, b.id.raw)
    }

    /// Writes the file from the state in memory; a failure becomes a notice and the state is kept.
    func save(_ file: StoreFile) {
        do {
            switch file {
            case .settings: try store.save(settings, to: .settings)
            case .tactics: try store.save(tactics, to: .tactics)
            case .fixtures: try store.save(fixtures, to: .fixtures)
            case .history: try store.save(history, to: .history)
            case .squad: try store.save(squad, to: .squad)
            }
        } catch {
            let subject = file.description.prefix(1).uppercased() + file.description.dropFirst()
            notices.append(Notice(text: "\(subject) could not be saved: \(error.localizedDescription) "
                + "The change is kept while the app is open and is saved with the next change that succeeds."))
        }
    }

    /// Works the plan out again from the saved state. Every action that changes the squad, the saved tactics, the
    /// fixtures, the history or the settings calls this after saving.
    func replan() {
        planState = workedOutPlan()
    }

    func notice(_ text: String) {
        notices.append(Notice(text: text))
    }
}
