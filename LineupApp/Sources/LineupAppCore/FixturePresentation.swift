import Foundation
import LineupEngine

extension Importance {
    /// The importance's name on a badge or in a menu.
    public var displayName: String {
        switch self {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        case .sharpness: "Sharpness"
        }
    }
}

extension TrainingIntensity {
    public var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

/// Where a fixture stands on the game's current date.
public enum FixtureState: Equatable, Sendable {
    /// On or after today, with no lineup confirmed.
    case toPlay
    /// A lineup is confirmed for it, whatever its date.
    case confirmed
    /// Before today, with no lineup confirmed: the planner does not know who played.
    case pastNotConfirmed

    public var text: String {
        switch self {
        case .toPlay: "to play"
        case .confirmed: "confirmed"
        case .pastNotConfirmed: "past and not confirmed"
        }
    }
}

/// A fixture being added or edited, before it is saved.
public struct FixtureDraft: Equatable, Sendable {
    /// Nil for a fixture not saved yet.
    public let id: FixtureID?
    public var date: Day
    public var opponent: String {
        didSet {
            if !Self.isBlank(oldValue) && Self.isBlank(opponent) { problemIsDue = true }
        }
    }
    public var importance: Importance
    /// Nil: the primary tactic.
    public var tacticID: UUID?

    /// A new fixture of medium importance on the primary tactic.
    public init(date: Day) {
        self.id = nil; self.date = date; self.opponent = ""; self.importance = .medium; self.tacticID = nil
    }

    public init(_ fixture: StoredFixture) {
        self.id = fixture.id; self.date = fixture.date; self.opponent = fixture.opponent
        self.importance = fixture.importance; self.tacticID = fixture.tacticID
    }

    public var isNew: Bool { id == nil }

    public var saveButtonTitle: String { isNew ? "Add fixture" : "Save changes" }

    /// Whether the owner has tried to save, or typed an opponent and cleared it. Until then a blank opponent is not
    /// yet a mistake, so it is not pointed out.
    public private(set) var problemIsDue = false

    /// Why the draft cannot be saved, or nil when it can. Two fixtures on one day are allowed; the planner says so.
    public var problem: String? {
        Self.isBlank(opponent) ? "Say who the match is against." : nil
    }

    /// `problem`, once it is due.
    public var shownProblem: String? {
        problemIsDue ? problem : nil
    }

    public mutating func noteSaveAttempt() {
        problemIsDue = true
    }

    private static func isBlank(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension AppModel {
    public func state(of fixture: StoredFixture) -> FixtureState {
        if history.contains(where: { $0.lineup.fixture == fixture.id }) { return .confirmed }
        return fixture.date < settings.currentDate ? .pastNotConfirmed : .toPlay
    }

    /// Deleting a confirmed fixture deletes its confirmed lineup too, so the owner is asked first.
    public func asksBeforeDeleting(_ fixture: StoredFixture) -> Bool {
        state(of: fixture) == .confirmed
    }

    /// For a fixture with a confirmed lineup, what editing it does to that lineup; nil for any other.
    public func confirmedNote(for draft: FixtureDraft) -> String? {
        guard let id = draft.id, history.contains(where: { $0.lineup.fixture == id }) else { return nil }
        return "A lineup is confirmed for this match. A new date moves it too; to pick the eleven again, "
            + "unlock it in Match Selection."
    }

    /// "Primary: <name>", or what is missing when there is no tactic.
    public var primaryTacticText: String {
        primaryTactic.map { "Primary: \($0.tactic.name)" } ?? "No tactic yet"
    }

    /// The fixture's own tactic by name, else the primary as `primaryTacticText` writes it.
    public func tacticText(for fixture: StoredFixture) -> String {
        if let id = fixture.tacticID, let own = tactics.first(where: { $0.id == id }) {
            return own.tactic.name
        }
        return primaryTacticText
    }

    /// A new fixture on the day after the last fixture from today on, or today in the game when there is none.
    public func newFixtureDraft() -> FixtureDraft {
        let last = fixtures.last { $0.date >= settings.currentDate }
        return FixtureDraft(date: last.map { $0.date.adding(days: 1) } ?? settings.currentDate)
    }

    /// Saves the draft as a new fixture, or over the fixture it was made from, keeping that fixture's choices of
    /// players. The opponent is saved without spaces around it. Nil, with nothing saved, when the draft has a
    /// problem or its fixture has been deleted.
    @discardableResult public func save(_ draft: FixtureDraft) -> FixtureID? {
        guard draft.problem == nil else { return nil }
        let opponent = draft.opponent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let id = draft.id else {
            let id = FixtureID(UUID().uuidString)
            fixtures.append(StoredFixture(id: id, date: draft.date, opponent: opponent, importance: draft.importance,
                                          tacticID: draft.tacticID))
            fixtures.sort(by: Self.dateOrder)
            save(.fixtures)
            replan()
            return id
        }
        guard var fixture = fixtures.first(where: { $0.id == id }) else { return nil }
        fixture.date = draft.date
        fixture.opponent = opponent
        fixture.importance = draft.importance
        fixture.tacticID = draft.tacticID
        update(fixture)
        return id
    }

    /// Moves the game's current date by whole days, back when negative.
    public func moveToday(by days: Int) {
        var changed = settings
        changed.currentDate = settings.currentDate.adding(days: days)
        update(changed)
    }
}
