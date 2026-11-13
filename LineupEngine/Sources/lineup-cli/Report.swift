import Foundation
import LineupEngine

/// Plain-words text for the command-line tool.
enum Report {
    /// What both commands print first: the import summary.
    struct Header {
        let imports: [(squad: Squad, result: ImportResult)]
        let moves: [(name: String, from: Squad, to: Squad)]
        let book: SquadBook
        let ownClub: String?
        let override: String?
        let tactic: Tactic
    }

    /// The import summary, then each profile's lineup under its name, then a comparison when there are two.
    static func render(_ header: Header, importance: Importance, results: [(profile: RatingProfile, lineup: Lineup)]) -> String {
        var out = ["Tactic: \(header.tactic.name)   Importance: \(importance.rawValue)", ""] + summary(header)
        for (profile, lineup) in results {
            out.append("")
            out.append("=== Rating profile: \(profile.name) ===")
            out += render(lineup, book: header.book, tactic: header.tactic)
        }
        if results.count == 2 {
            out.append("")
            out += comparison(results[0], results[1], tactic: header.tactic)
        }
        return out.joined(separator: "\n") + "\n"
    }

    /// The import summary and the plan's settings, then each planned fixture's lineup under a heading,
    /// then a table of who starts where.
    static func render(_ header: Header, plan: Plan, fixtures: [Fixture], history: [ConfirmedLineup], asOf: Day,
                       profile: RatingProfile, parameters: EngineParameters, settings: PlanSettings) -> String {
        var out = ["Tactic: \(header.tactic.name)   Plan as of \(asOf.iso): \(plan.fixtures.count) of \(fixtures.count) fixtures", ""]
        out += summary(header)
        out.append("Rating profile: \(profile.name)")
        out.append("Training \(settings.trainingIntensity.rawValue), stability \(number(settings.stability)), "
                   + "saving players \(number(settings.savingPlayers)), horizon \(settings.horizon)")
        let played = history.sorted { ($0.date, $0.fixture.raw) < ($1.date, $1.fixture.raw) }
        out.append("Confirmed lineups: " + (played.isEmpty ? "none" : played.map { "\($0.fixture.raw) (\($0.date.iso))" }.joined(separator: ", ")))
        let names = Dictionary(header.book.allPlayers.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        for lineup in played {
            for slot in SlotID.allCases {
                guard let id = lineup.starters[slot], names[id] == nil else { continue }
                out.append("Warning: the confirmed lineup \(lineup.fixture.raw) has '\(id.key)' at \(slot.rawValue), "
                           + "who is not in the imported squads; his starts count for nobody here")
            }
        }

        let byID = Dictionary(fixtures.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let planned = plan.fixtures.map { (fixture: byID[$0.fixture]!, lineup: $0.lineup, projected: $0.fitnessIsProjected) }
        for (fixture, lineup, projected) in planned {
            out.append("")
            out.append("=== \(fixture.date.iso)  v \(fixture.opponent)  (\(fixture.importance.rawValue)) ===")
            out += render(lineup, book: header.book, tactic: fixture.tactic)
            for slot in SlotID.allCases {
                guard let problem = lineup.ignoredOverrides[slot] else { continue }
                let who = fixture.overrides[slot].map { names[$0] ?? $0.key } ?? "?"
                out.append("Override ignored: \(who) at \(slot.rawValue), "
                           + ErrorDescriptions.describe(problem, parameters: parameters, projected: projected))
            }
        }
        out.append("")
        out += table(planned.map { ($0.fixture, $0.lineup) }, names: names)
        return out.joined(separator: "\n") + "\n"
    }

    /// One row per player who starts at least once, in the order of his first start (slot order within a fixture),
    /// with his slot or "-" for each fixture.
    private static func table(_ planned: [(fixture: Fixture, lineup: Lineup)], names: [PlayerID: String]) -> [String] {
        var rows: [PlayerID] = []
        for (_, lineup) in planned {
            for pick in lineup.picks where !rows.contains(pick.player) { rows.append(pick.player) }
        }
        let width = 12
        var out = ["Who starts where"]
        out.append("  \(pad("", 26))" + planned.map { pad($0.fixture.date.iso, width) }.joined().trimmingTrailingSpaces)
        out.append("  \(pad("", 26))" + planned.map { pad($0.fixture.importance.rawValue, width) }.joined().trimmingTrailingSpaces)
        for id in rows {
            let cells = planned.map { item in
                pad(item.lineup.picks.first { $0.player == id }?.slot.rawValue ?? "-", width)
            }
            out.append(("  \(pad(names[id] ?? id.key, 26))" + cells.joined()).trimmingTrailingSpaces)
        }
        return out
    }

    private static func summary(_ header: Header) -> [String] {
        var out: [String] = []
        let book = header.book, override = header.override
        let players = book.allPlayers

        for (squad, result) in header.imports {
            out.append("\(squadName(squad)): grid \(result.grid), \(result.players.count) players")
        }
        for (squad, result) in header.imports {
            for warning in result.warnings { out.append("Warning (\(squadName(squad))): \(describe(warning))") }
        }
        for move in header.moves { out.append("\(move.name) moved from \(squadName(move.from)) to \(squadName(move.to))") }
        for warning in book.warnings(override: override) { out.append("Warning: \(describe(warning))") }
        out.append("Own club: \(header.ownClub ?? "unknown")")
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
        out.append("Left out")
        if lineup.omissions.isEmpty { out.append("  none") }
        for omission in lineup.omissions {
            out.append("  \(pad(omission.name, 22)) (expected at \(omission.slot.rawValue)) \(omission.reason)")
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

    /// The engine's sentence; for an unknown club, followed by the option that sets it here.
    static func describe(_ warning: SquadWarning) -> String {
        switch warning {
        case .ownClubUnknown: ErrorDescriptions.describe(warning) + " Pass --own-club <name>."
        case .sharedName: ErrorDescriptions.describe(warning)
        }
    }

    static func describe(_ warning: PickWarning) -> String {
        switch warning {
        case .outOfPosition(let phase, let familiarity):
            "out of position \(phase == .inPossession ? "in possession" : "out of possession") (familiarity \(familiarity))"
        case .overridesRule: "overrides a selection rule"
        }
    }

    /// A setting as typed: no decimals when it is whole.
    private static func number(_ x: Double) -> String { x == x.rounded() ? String(format: "%.0f", x) : String(x) }

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
