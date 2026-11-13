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
        return stored.id
    }

    /// Replaces the saved tactic with the same id; a tactic no longer saved is left out.
    public func update(_ tactic: StoredTactic) {
        guard let index = tactics.firstIndex(where: { $0.id == tactic.id }) else { return }
        tactics[index] = tactic
        save(.tactics)
    }

    /// A copy named "<name> copy" (or "copy 2" and on, if taken), added after the others; nil if `id` is not saved.
    public func duplicateTactic(_ id: UUID) -> UUID? {
        guard let original = tactics.first(where: { $0.id == id }) else { return nil }
        let names = Set(tactics.map(\.tactic.name))
        var name = "\(original.tactic.name) copy"
        var number = 2
        while names.contains(name) {
            name = "\(original.tactic.name) copy \(number)"
            number += 1
        }
        var copy = original
        copy.id = UUID()
        copy.tactic.name = name
        tactics.append(copy)
        save(.tactics)
        return copy.id
    }

    /// Removes the tactic. If it was the primary, the first remaining tactic becomes the primary. Fixtures that
    /// used it fall back to the primary, and a notice names them.
    public func deleteTactic(_ id: UUID) {
        guard let deleted = tactics.first(where: { $0.id == id }) else { return }
        tactics.removeAll { $0.id == id }
        save(.tactics)
        if settings.primaryTacticID == id {
            settings.primaryTacticID = tactics.first?.id
            save(.settings)
        }
        let affected = fixtures.filter { $0.tacticID == id }
        guard !affected.isEmpty else { return }
        for index in fixtures.indices where fixtures[index].tacticID == id {
            fixtures[index].tacticID = nil
        }
        save(.fixtures)

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
    }

    /// The engine's sentence for each problem that stops the tactic being used.
    public func problems(of tactic: Tactic) -> [String] {
        tactic.problems(catalog: catalog).map(ErrorDescriptions.describe)
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
