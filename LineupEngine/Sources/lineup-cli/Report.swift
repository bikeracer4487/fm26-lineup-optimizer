import Foundation
import LineupEngine

/// Plain-words text for the command-line tool.
enum Report {
    static func render(imports: [(squad: Squad, result: ImportResult)], book: SquadBook, ownClub: String?, override: String?,
                       tactic: Tactic, importance: Importance, lineup: Lineup) -> String {
        var out: [String] = []
        let players = book.allPlayers
        let squadOf = Dictionary(players.map { ($0.id, $0.squad) }, uniquingKeysWith: { first, _ in first })

        out.append("Tactic: \(tactic.name)   Importance: \(importance.rawValue)")
        out.append("")
        for (squad, result) in imports {
            out.append("\(squadName(squad)): grid \(result.grid), \(result.players.count) players")
        }
        for (squad, result) in imports {
            for warning in result.warnings { out.append("Warning (\(squadName(squad))): \(describe(warning))") }
        }
        for warning in book.warnings(override: override) { out.append("Warning: \(describe(warning))") }
        out.append("Own club: \(ownClub ?? "unknown")")
        let loans = players.compactMap { player -> String? in
            if case .loanedOut(let club) = book.loanStatus(of: player, override: override) { "\(player.name) (at \(club))" } else { nil }
        }
        out.append("Out on loan: \(loans.isEmpty ? "none" : loans.joined(separator: ", "))")

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
        return out.joined(separator: "\n") + "\n"
    }

    static func squadName(_ squad: Squad) -> String {
        switch squad { case .firstTeam: "First team"; case .u21: "U21"; case .u18: "U18" }
    }

    static func describe(_ warning: ImportWarning) -> String {
        switch warning {
        case .duplicateName(let name): "more than one player is called \(name); they were told apart by age"
        case .outOfContract(let name): "\(name) is out of contract"
        }
    }

    static func describe(_ warning: SquadWarning) -> String {
        switch warning {
        case .ownClubUnknown: "Some players are on loan but your club cannot be told from the pasted squads. Pass --own-club <name>."
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
