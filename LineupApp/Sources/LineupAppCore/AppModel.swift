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
    /// The day the import is dated with: the game's current date when it was made.
    public let date: Day
    /// The FMRTE grid recognised.
    public let grid: String
    public let playerCount: Int
    /// Names of players out on loan, in the order of the paste.
    public let onLoan: [String]
    /// The engine's sentences for the import's warnings, then one for each match before the current date with no
    /// confirmed lineup.
    public let warnings: [String]
    public let change: SquadChange

    public init(squad: Squad, date: Day, grid: String, playerCount: Int, onLoan: [String], warnings: [String],
                change: SquadChange) {
        self.squad = squad; self.date = date; self.grid = grid; self.playerCount = playerCount
        self.onLoan = onLoan; self.warnings = warnings; self.change = change
    }
}

public enum ImportOutcome: Equatable, Sendable {
    case imported(ImportSummary)
    /// The squad that was to be imported, and why it was not.
    case failed(Squad, reason: String)
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
    public internal(set) var planState: PlanState
    /// Unsaved changes to saved tactics, by tactic id, kept in their own file until saved or reverted. Changed only
    /// through `changeDrafts`, which saves them.
    private(set) var tacticDrafts: [UUID: TacticDraft] = [:]
    /// The retrainings accepted and turned down, and how the accepted ones are going. Changed only through
    /// `changeTraining`, which saves it and replans.
    public private(set) var training: TrainingState
    public let catalog: RoleCatalog
    /// The rating profile the plan is made with: the engine's standard one.
    let profile: RatingProfile

    /// The notice showing for each file that could not be saved, so a file that keeps failing is noticed once.
    @ObservationIgnored private var saveFailureNotices: [StoreFile: Notice.ID] = [:]

    /// The advice since the last replan; nil until it is first read after one (see `adviceState`).
    @ObservationIgnored var adviceCache: AdviceCache?
    /// Changed by every replan, so whatever read the advice is drawn again once there is new advice to work out.
    private(set) var adviceGeneration = 0

    /// How many times the plan has been worked out, so tests can tell when a change did not replan.
    @ObservationIgnored var timesPlanned = 0
    /// How many times the advice, and the elevens of a tactic other than the primary, have been worked out.
    @ObservationIgnored var timesAdvised = 0
    @ObservationIgnored var timesElevensWorkedOut = 0
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

        let settings = store.load(.settings, as: AppSettings.self, otherwise: AppSettings(currentDate: environment.today()))
        let tactics = store.load(.tactics, as: [StoredTactic].self, otherwise: [])
        let fixtures = store.load(.fixtures, as: [StoredFixture].self, otherwise: [])
        let history = store.load(.history, as: [ConfirmedRecord].self, otherwise: [])
        let squad = store.load(.squad, as: SquadState.self, otherwise: SquadState())
        let drafts = store.load(.drafts, as: [StoredTactic].self, otherwise: [])
        let training = store.load(.training, as: TrainingState.self, otherwise: TrainingState())
        self.settings = settings.value
        self.tactics = tactics.value
        self.fixtures = fixtures.value.sorted(by: Self.dateOrder)
        self.history = history.value
        self.squad = squad.value
        self.training = training.value
        // A draft is kept only for a saved tactic it differs from. When the tactics file could not be read and was left
        // where it is, its tactics are still on disk, so every draft is kept for them.
        let saved = Dictionary(tactics.value.map { ($0.id, $0.tactic) }, uniquingKeysWith: { first, _ in first })
        let tacticsLeftUnread = store.isLeftUnread(.tactics)
        let kept = tacticsLeftUnread
            ? drafts.value
            : drafts.value.filter { saved[$0.id] != nil && saved[$0.id] != $0.tactic }
        self.tacticDrafts = Dictionary(kept.map { ($0.id, TacticDraft($0.tactic)) }, uniquingKeysWith: { first, _ in first })
        self.notices = [settings.notice, tactics.notice, fixtures.notice, history.notice, squad.notice, drafts.notice,
                        training.notice]
            .compactMap { $0 }.map(Notice.init(text:))
        self.lastImport = nil
        self.planState = .needsSquad
        // A file that was missing, or was unreadable and kept aside, is written now, so the next start neither reports
        // it missing nor keeps it aside again.
        let replaced: [(StoreFile, Bool)] = [(.settings, settings.replaceOnDisk), (.tactics, tactics.replaceOnDisk),
                                            (.fixtures, fixtures.replaceOnDisk), (.history, history.replaceOnDisk),
                                            (.squad, squad.replaceOnDisk),
                                            (.drafts, drafts.replaceOnDisk || kept.count != drafts.value.count),
                                            (.training, training.replaceOnDisk)]
        for (file, replace) in replaced where replace { save(file) }
        replan()
    }

    public func dismiss(_ notice: Notice) {
        notices.removeAll { $0.id == notice.id }
    }

    /// Clears what the last import said.
    public func dismissImport() {
        lastImport = nil
    }

    /// Fixtures by date, then by id, so the order never depends on how they were added.
    static func dateOrder(_ a: StoredFixture, _ b: StoredFixture) -> Bool {
        (a.date, a.id.raw) < (b.date, b.id.raw)
    }

    /// Writes the file from the state in memory, and whether it was written. A failure becomes a notice, unless one
    /// for the same file is still showing, and the state is kept.
    @discardableResult func save(_ file: StoreFile) -> Bool {
        do {
            switch file {
            case .settings: try store.save(settings, to: .settings)
            case .tactics: try store.save(tactics, to: .tactics)
            case .fixtures: try store.save(fixtures, to: .fixtures)
            case .history: try store.save(history, to: .history)
            case .squad: try store.save(squad, to: .squad)
            case .drafts: try store.save(savedDrafts, to: .drafts)
            case .training: try store.save(training, to: .training)
            }
            return true
        } catch {
            if let showing = saveFailureNotices[file], notices.contains(where: { $0.id == showing }) { return false }
            let subject = file.description.prefix(1).uppercased() + file.description.dropFirst()
            let text = (error as? StoreError)?.description
                ?? "\(subject) could not be saved: \(error.localizedDescription) "
                + "The change is kept while the app is open and is saved the next time that part of the app changes."
            let notice = Notice(text: text)
            notices.append(notice)
            saveFailureNotices[file] = notice.id
            return false
        }
    }

    /// Works the plan out again from the saved state, and leaves the advice to be worked out again when next read.
    /// Every action that changes the squad, the saved tactics, the fixtures, the history, the settings or the
    /// retrainings calls this after saving.
    func replan() {
        timesPlanned += 1
        planState = rememberingElevens(workedOutPlan())
        adviceCache = nil
        adviceGeneration &+= 1
    }

    /// The drafts as saved: each with its tactic's id, in the order the tactics are listed; then, by id, those kept for
    /// tactics in a file that could not be read.
    private var savedDrafts: [StoredTactic] {
        let listed = tactics.compactMap { stored in
            tacticDrafts[stored.id].map { StoredTactic(id: stored.id, tactic: $0.tactic) }
        }
        let known = Set(tactics.map(\.id))
        let unread = tacticDrafts.filter { !known.contains($0.key) }
            .sorted { $0.key.uuidString < $1.key.uuidString }
            .map { StoredTactic(id: $0.key, tactic: $0.value.tactic) }
        return listed + unread
    }

    /// Applies `change` to the unsaved drafts and saves them if it changed anything.
    func changeDrafts(_ change: (inout [UUID: TacticDraft]) -> Void) {
        var drafts = tacticDrafts
        change(&drafts)
        guard drafts != tacticDrafts else { return }
        tacticDrafts = drafts
        save(.drafts)
    }

    /// Applies `change` to the retrainings and, if it changed anything, keeps the accepted ones in their fixed order,
    /// drops names no pair needs, saves them and replans unless `replanning` is false.
    func changeTraining(replanning: Bool = true, _ change: (inout TrainingState) -> Void) {
        var state = training
        change(&state)
        state.accepted.sort { TrainingState.order(TrainingState.choice($0), TrainingState.choice($1)) }
        state.forgetUnusedNames()
        guard state != training else { return }
        training = state
        save(.training)
        if replanning { replan() }
    }

    func notice(_ text: String) {
        notices.append(Notice(text: text))
    }
}
