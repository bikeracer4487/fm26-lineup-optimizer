import Foundation
import LineupEngine

/// Plain-words text for the command-line tool.
enum Report {
    /// The import summary, then each profile's lineup under its name, then a comparison when there are two.
    static func render(imports: [(squad: Squad, result: ImportResult)], moves: [(name: String, from: Squad, to: Squad)],
                       book: SquadBook, ownClub: String?, override: String?,
                       tactic: Tactic, importance: Importance, results: [(profile: RatingProfile, lineup: Lineup)]) -> String {
        var out = header(imports: imports, moves: moves, book: book, ownClub: ownClub, override: override,
                         tactic: tactic, importance: importance)
        for (profile, lineup) in results {
            out.append("")
            out.append("=== Rating profile: \(profile.name) ===")
            out += render(lineup, book: book, tactic: tactic)
        }
        if results.count == 2 {
            out.append("")
            out += comparison(results[0], results[1], tactic: tactic)
        }
        return out.joined(separator: "\n") + "\n"
    }

    private static func header(imports: [(squad: Squad, result: ImportResult)], moves: [(name: String, from: Squad, to: Squad)],
                               book: SquadBook, ownClub: String?, override: String?,
                               tactic: Tactic, importance: Importance) -> [String] {
        var out: [String] = []
        let players = book.allPlayers

        out.append("Tactic: \(tactic.name)   Importance: \(importance.rawValue)")
        out.append("")
        for (squad, result) in imports {
            out.append("\(squadName(squad)): grid \(result.grid), \(result.players.count) players")
        }
        for (squad, result) in imports {
            for warning in result.warnings { out.append("Warning (\(squadName(squad))): \(describe(warning))") }
        }
        for move in moves { out.append("\(move.name) moved from \(squadName(move.from)) to \(squadName(move.to))") }
        for warning in book.warnings(override: override) { out.append("Warning: \(describe(warning))") }
        out.append("Own club: \(ownClub ?? "unknown")")
        let loans = players.compactMap { player -> String? in
            if case .loanedOut(let club) = book.loanStatus(of: player, override: override) { "\(player.name) (at \(club))" } else { nil }
        }
        out.append("Out on loan: \(loans.isEmpty ? "none" : loans.joined(separator: ", "))")
        return out
    }

    private static func render(_ lineup: Lineup, book: SquadBook, tactic: Tactic) -> [String] {
        var out: [String] = []
        let squadOf = Dictionary(book.allPlayers.map { ($0.id, $0.squad) }, uniquingKeysWith: { first, _ in first })
        out.append("")
        out.append("Lineup")
        for pick in lineup.picks {
            let ip = tactic.inPossession[pick.slot] ?? "?"
            let oop = tactic.mapping[pick.slot].flatMap { tactic.outOfPossession[$0] } ?? "?"
            let squad = squadOf[pick.player].map(squadName) ?? "?"
            let f = pick.fitness
            out.append("  \(pad(pick.slot.rawValue, 5)) \(pad("\(ip) / \(oop)", 52)) \(pad(pick.name, 22)) \(pad(squad, 10))"
                + " rating \(fixed(pick.rating.value, 1))  fitness cond \(fixed(f.condition, 2)) sharp \(fixed(f.sharpness, 2))"
                + " jaded \(fixed(f.jadedness, 2))  value \(fixed(pick.value, 1))")
            for warning in pick.warnings { out.append("        ! \(describe(warning))") }
            for reason in pick.reasons { out.append("        - \(reason)") }
        }

        out.append("")
        if lineup.unfilled.isEmpty {
            out.append("Unfilled slots: none")
        } else {
            out.append("Unfilled slots: " + lineup.unfilled.map(\.rawValue).joined(separator: ", "))
        }

        out.append("")
        out.append("Left out of the ideal eleven")
        if lineup.omissions.isEmpty { out.append("  none") }
        for omission in lineup.omissions {
            out.append("  \(pad(omission.name, 22)) (ideal slot \(omission.slot.rawValue)) \(omission.reason)")
        }
        return out
    }

    /// One line per slot with the player each profile picks, `*` where they differ, then the count.
    private static func comparison(_ a: (profile: RatingProfile, lineup: Lineup), _ b: (profile: RatingProfile, lineup: Lineup),
                                   tactic: Tactic) -> [String] {
        func picked(_ lineup: Lineup, _ slot: SlotID) -> (id: PlayerID?, name: String) {
            let pick = lineup.picks.first { $0.slot == slot }
            return (pick?.player, pick?.name ?? "(unfilled)")
        }
        var out = ["Comparison", "  \(pad("Slot", 6)) \(pad(a.profile.name, 26)) \(b.profile.name)"]
        var differ = 0
        let slots = SlotID.allCases.filter { tactic.inPossession[$0] != nil }
        for slot in slots {
            let x = picked(a.lineup, slot), y = picked(b.lineup, slot)
            let marker = x.id == y.id ? "" : "  *"
            if x.id != y.id { differ += 1 }
            out.append("  \(pad(slot.rawValue, 6)) \(pad(x.name, 26)) \(pad(y.name, 22))\(marker)".trimmingTrailingSpaces)
        }
        out.append("\(differ) of \(slots.count) slots differ" + (differ > 0 ? " (marked *)" : ""))
        return out
    }

    static func squadName(_ squad: Squad) -> String {
        switch squad { case .firstTeam: "First team"; case .u21: "U21"; case .u18: "U18" }
    }

    static func describe(_ warning: ImportWarning) -> String { ErrorDescriptions.describe(warning) }

    static func describe(_ warning: SquadWarning) -> String {
        switch warning {
        case .ownClubUnknown: "Some players are on loan but your club cannot be told from the pasted squads. Pass --own-club <name>."
        case .sharedName(let name):
            "More than one player is called \(name); they are kept as separate players, told apart by potential ability, then nationality."
        }
    }

    static func describe(_ warning: PickWarning) -> String {
        switch warning {
        case .outOfPosition(let phase, let familiarity):
            "out of position \(phase == .inPossession ? "in possession" : "out of possession") (familiarity \(familiarity))"
        case .overridesRule: "overrides a selection rule"
        }
    }

    private static func pad(_ s: String, _ n: Int) -> String { s.count >= n ? s : s + String(repeating: " ", count: n - s.count) }
    private static func fixed(_ x: Double, _ digits: Int) -> String { String(format: "%.\(digits)f", x) }
}

private extension String {
    var trimmingTrailingSpaces: String {
        var s = self
        while s.hasSuffix(" ") { s.removeLast() }
        return s
    }
}
