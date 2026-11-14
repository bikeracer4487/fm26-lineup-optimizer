import Foundation
import LineupEngine

extension AppModel {
    public var primaryTactic: StoredTactic? {
        tactics.first { $0.id == settings.primaryTacticID }
    }

    /// Adds a 4-2-3-1 to start from. The first tactic added becomes the primary.
    @discardableResult public func addTactic(named name: String) -> UUID {
        let stored = StoredTactic(id: UUID(), tactic: Self.starterTactic(named: name))
        tactics.append(stored)
        save(.tactics)
        if primaryTactic == nil {
            settings.primaryTacticID = stored.id
            save(.settings)
        }
        replan()
        return stored.id
    }

    /// Replaces the saved tactic with the same id; a tactic no longer saved is left out. An unsaved draft that
    /// now matches the saved tactic is dropped.
    public func update(_ tactic: StoredTactic) {
        guard let index = tactics.firstIndex(where: { $0.id == tactic.id }) else { return }
        tactics[index] = tactic
        save(.tactics)
        if tacticDrafts[tactic.id]?.tactic == tactic.tactic {
            changeDrafts { $0[tactic.id] = nil }
        }
        replan()
    }

    /// A copy of what the owner is looking at, the unsaved draft if there is one, named "<name> copy" (or
    /// "copy 2" and on, if taken) and added after the others; nil if `id` is not saved. The name is the draft's,
    /// or the saved one when the draft's is blank. A draft with no problems is copied and saved as it is; one with
    /// problems cannot be saved, so the saved tactic is copied and the draft's changes become the copy's
    /// unsaved draft. The original keeps its draft.
    public func duplicateTactic(_ id: UUID) -> UUID? {
        guard let original = tactics.first(where: { $0.id == id }), let shown = draft(for: id) else { return nil }
        let shownName = shown.tactic.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = unusedTacticName("\(shownName.isEmpty ? original.tactic.name : shownName) copy")
        let copyID = UUID()
        var copy = shown.tactic
        copy.name = name
        let canBeSaved = problems(saving: StoredTactic(id: copyID, tactic: copy)).isEmpty
        if canBeSaved {
            tactics.append(StoredTactic(id: copyID, tactic: copy))
        } else {
            var saved = original.tactic
            saved.name = name
            tactics.append(StoredTactic(id: copyID, tactic: saved))
        }
        save(.tactics)
        if !canBeSaved {
            changeDrafts { $0[copyID] = TacticDraft(copy) }
        }
        replan()
        return copyID
    }

    // MARK: Unsaved changes

    /// The unsaved draft of the tactic, or a draft of the saved tactic when it has no unsaved changes; nil if
    /// `id` is not saved.
    public func draft(for id: UUID) -> TacticDraft? {
        guard let saved = tactics.first(where: { $0.id == id }) else { return nil }
        return tacticDrafts[id] ?? TacticDraft(saved.tactic)
    }

    /// Keeps `draft` as the tactic's unsaved changes while it differs from the saved tactic; a draft identical to
    /// the saved tactic, or for a tactic not saved, is not kept.
    public func setDraft(_ draft: TacticDraft, for id: UUID) {
        guard let saved = tactics.first(where: { $0.id == id }) else { return }
        changeDrafts { $0[id] = draft.tactic == saved.tactic ? nil : draft }
    }

    public func hasUnsavedChanges(_ id: UUID) -> Bool {
        tacticDrafts[id] != nil
    }

    /// The tactics with unsaved changes, in the order the tactics are listed.
    public var tacticsWithUnsavedChanges: [UUID] {
        tactics.map(\.id).filter { tacticDrafts[$0] != nil }
    }

    /// Saves the tactic's draft, its name trimmed, drops the draft and replans, and returns whether the tactic was
    /// saved. Returns false, changing nothing, when there is no draft or while `problems(saving:)` lists anything for
    /// it; and false when the tactics file could not be written, with the saved tactic put back as it was, so the draft
    /// stays the only copy of the change and the plan is still worked out from the saved tactic.
    @discardableResult public func saveDraft(_ id: UUID) -> Bool {
        guard let draft = tacticDrafts[id] else { return false }
        var tactic = draft.tactic
        tactic.name = tactic.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let stored = StoredTactic(id: id, tactic: tactic)
        guard problems(saving: stored).isEmpty, let index = tactics.firstIndex(where: { $0.id == id }) else { return false }
        // The tactic is saved first, and the draft dropped only once it is on disk, so a failed save loses no edit.
        let previous = tactics[index]
        tactics[index] = stored
        guard save(.tactics) else {
            tactics[index] = previous
            return false
        }
        changeDrafts { $0[id] = nil }
        replan()
        return true
    }

    /// Drops the tactic's unsaved changes.
    public func revertDraft(_ id: UUID) {
        changeDrafts { $0[id] = nil }
    }

    /// The tactic's name as the tactics menu lists it, marked "(primary)" and "— unsaved changes" where they
    /// apply; empty if `id` is not saved.
    public func menuTitle(of id: UUID) -> String {
        guard let stored = tactics.first(where: { $0.id == id }) else { return "" }
        var title = stored.tactic.name
        if id == settings.primaryTacticID { title += " (primary)" }
        if hasUnsavedChanges(id) { title += " — unsaved changes" }
        return title
    }

    // MARK: Removing

    /// Removes the tactic and its unsaved changes. If it was the primary, the first remaining tactic becomes the
    /// primary. Fixtures that used it fall back to the primary, and a notice names them.
    public func deleteTactic(_ id: UUID) {
        guard let deleted = tactics.first(where: { $0.id == id }) else { return }
        tactics.removeAll { $0.id == id }
        save(.tactics)
        changeDrafts { $0[id] = nil }
        if settings.primaryTacticID == id {
            settings.primaryTacticID = tactics.first?.id
            save(.settings)
        }
        let affected = fixtures.filter { $0.tacticID == id }
        guard !affected.isEmpty else { replan(); return }
        for index in fixtures.indices where fixtures[index].tacticID == id {
            fixtures[index].tacticID = nil
        }
        save(.fixtures)
        replan()

        let matches = affected.map { "\($0.opponent) on \($0.date.iso)" }
        let list = matches.count == 1
            ? "the match against \(matches[0])"
            : "the matches against " + matches.dropLast().joined(separator: ", ") + " and " + matches.last!
        let outcome: String
        if let primary = primaryTactic {
            outcome = (affected.count == 1 ? "now uses" : "now use") + " the primary tactic, \(primary.tactic.name)"
        } else {
            outcome = (affected.count == 1 ? "has" : "have") + " no tactic until you add one"
        }
        notice("The tactic \(deleted.tactic.name) was deleted, so \(list) \(outcome).")
    }

    public func makePrimary(_ id: UUID) {
        guard tactics.contains(where: { $0.id == id }) else { return }
        settings.primaryTacticID = id
        save(.settings)
        replan()
    }

    /// The engine's sentence for each problem that stops the tactic being used.
    public func problems(of tactic: Tactic) -> [String] {
        tactic.problems(catalog: catalog).map(ErrorDescriptions.describe)
    }

    /// Everything that stops `stored` being saved: first its name, which must not be blank and must differ from
    /// every other tactic's (ignoring case and the spaces around it), then the engine's problems.
    public func problems(saving stored: StoredTactic) -> [String] {
        let name = stored.tactic.name.trimmingCharacters(in: .whitespacesAndNewlines)
        var found: [String] = []
        if name.isEmpty {
            found.append("Give the tactic a name.")
        } else if let other = tactics.first(where: { $0.id != stored.id && Self.sameName($0.tactic.name, name) }) {
            found.append("Another tactic is already called \(other.tactic.name).")
        }
        return found + problems(of: stored.tactic)
    }

    /// `base`, or "<base> 2" and on when another tactic already has that name.
    public func unusedTacticName(_ base: String) -> String {
        var name = base
        var number = 2
        while tactics.contains(where: { Self.sameName($0.tactic.name, name) }) {
            name = "\(base) \(number)"
            number += 1
        }
        return name
    }

    private static func sameName(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(b.trimmingCharacters(in: .whitespacesAndNewlines))
            == .orderedSame
    }

    /// A 4-2-3-1: wing-backs and ball-playing centre-backs, two defensive midfielders, inside forwards either side
    /// of an attacking midfielder, and a channel forward. Out of possession the wide forwards drop to midfield.
    static func starterTactic(named name: String) -> Tactic {
        Tactic(
            name: name,
            inPossession: [
                .GK: "Goalkeeper",
                .D_L: "Wing-Back", .D_R: "Wing-Back",
                .D_CL: "Ball-Playing Centre-Back", .D_CR: "Ball-Playing Centre-Back",
                .DM_L: "Defensive Midfielder", .DM_R: "Defensive Midfielder",
                .AM_L: "Inside Forward", .AM_R: "Inside Forward",
                .AM_C: "Attacking Midfielder",
                .ST_C: "Channel Forward",
            ],
            outOfPossession: [
                .GK: "Sweeper Keeper",
                .D_L: "Pressing Full-Back", .D_R: "Pressing Full-Back",
                .D_CL: "Centre-Back", .D_CR: "Centre-Back",
                .DM_L: "Defensive Midfielder", .DM_R: "Defensive Midfielder",
                .M_L: "Wide Midfielder", .M_R: "Wide Midfielder",
                .AM_C: "Attacking Midfielder",
                .ST_C: "Centre Forward",
            ],
            mapping: [
                .GK: .GK,
                .D_L: .D_L, .D_R: .D_R, .D_CL: .D_CL, .D_CR: .D_CR,
                .DM_L: .DM_L, .DM_R: .DM_R,
                .AM_L: .M_L, .AM_R: .M_R,
                .AM_C: .AM_C,
                .ST_C: .ST_C,
            ])
    }
}
