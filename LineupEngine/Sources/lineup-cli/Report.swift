import Foundation
import LineupEngine

/// Plain-words text for the command-line tool.
enum Report {
    /// What every command prints first: the import summary.
    struct Header {
        let imports: [(squad: Squad, result: ImportResult)]
        let moves: [(name: String, from: Squad, to: Squad)]
        let book: SquadBook
        let ownClub: String?
        let override: String?
        let tactic: Tactic
    }

    /// The import summary, then each profile's lineup under its name, then a comparison when there are two.
    static func render(_ header: Header, importance: Importance, results: [(profile: RatingProfile, lineup: Lineup)],
                       parameters: EngineParameters) -> String {
        var out = ["Tactic: \(header.tactic.name)   Importance: \(importance.rawValue)", ""] + summary(header)
        for (profile, lineup) in results {
            out.append("")
            out.append("=== Rating profile: \(profile.name) ===")
            out += render(lineup, book: header.book, tactic: header.tactic, parameters: parameters, projected: false)
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
        out += confirmed(history, book: header.book)
        let names = Dictionary(header.book.allPlayers.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })

        let byID = Dictionary(fixtures.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let planned = plan.fixtures.map { (fixture: byID[$0.fixture]!, lineup: $0.lineup, projected: $0.fitnessIsProjected) }
        for (fixture, lineup, projected) in planned {
            out.append("")
            out.append("=== \(fixture.date.iso)  v \(fixture.opponent)  (\(fixture.importance.rawValue)) ===")
            out += render(lineup, book: header.book, tactic: fixture.tactic, parameters: parameters, projected: projected)
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

    /// The confirmed lineups in date order, then a warning for each starter the imported squads do not have.
    private static func confirmed(_ history: [ConfirmedLineup], book: SquadBook) -> [String] {
        let played = history.sorted { ($0.date, $0.fixture.raw) < ($1.date, $1.fixture.raw) }
        var out = ["Confirmed lineups: " + (played.isEmpty ? "none" : played.map { "\($0.fixture.raw) (\($0.date.iso))" }.joined(separator: ", "))]
        let known = Set(book.allPlayers.map(\.id))
        for lineup in played {
            for slot in SlotID.allCases {
                guard let id = lineup.starters[slot], !known.contains(id) else { continue }
                out.append("Warning: the confirmed lineup \(lineup.fixture.raw) has '\(id.key)' at \(slot.rawValue), "
                           + "who is not in the imported squads; his starts count for nobody here")
            }
        }
        return out
    }

    // MARK: Advice

    /// Everything the advisors said, for one tactic as of one day.
    struct Advice {
        let asOf: Day
        let profile: RatingProfile
        let intensity: TrainingIntensity
        let history: [ConfirmedLineup]
        let elevens: ElevensReport
        let depth: DepthReport
        let rest: [RestAdvice]
        let training: TrainingReport
        let removal: RemovalReport
        /// In date order; nil when no fixtures were given.
        let suggestions: [(fixture: Fixture, suggestion: ImportanceSuggestion)]?
    }

    /// The import summary, then each advisor's report under its heading.
    static func render(_ header: Header, advice: Advice, parameters: EngineParameters) -> String {
        var out = ["Tactic: \(header.tactic.name)   Advice as of \(advice.asOf.iso)", ""]
        out += summary(header)
        out.append("Rating profile: \(advice.profile.name)")
        out.append("Training \(advice.intensity.rawValue) (for rest estimates)")
        out += confirmed(advice.history, book: header.book)
        let squadOf = Dictionary(header.book.allPlayers.map { ($0.id, $0.squad) }, uniquingKeysWith: { first, _ in first })

        out += eleven("First XI", advice.elevens.first, average: advice.elevens.firstAverage,
                      unfilled: advice.elevens.unfilledFirst, squadOf: squadOf)
        out += eleven("Second XI", advice.elevens.second, average: advice.elevens.secondAverage,
                      unfilled: advice.elevens.unfilledSecond, squadOf: squadOf)
        out += depth(advice.depth, parameters: parameters)
        out += rest(advice.rest)
        out += training(advice.training)
        out += removal(advice.removal)
        if let suggestions = advice.suggestions { out += importance(suggestions) }
        return out.joined(separator: "\n") + "\n"
    }

    private static func eleven(_ title: String, _ places: [ElevenPlace], average: Double?, unfilled: [SlotID],
                               squadOf: [PlayerID: Squad]) -> [String] {
        var out = ["", "=== \(title) ==="]
        for place in places {
            let squad = squadOf[place.player].map(squadName) ?? "?"
            let rating = place.rating
            out.append(("  \(pad(place.slot.rawValue, 6)) \(pad(place.name, 22)) \(pad(squad, 10)) rating \(fixed(rating.value, 1))"
                        + "  familiarity \(rating.inPossession.familiarity) in possession, \(rating.outOfPossession.familiarity) out"
                        + (place.isInjured ? "  INJURED" : "")).trimmingTrailingSpaces)
        }
        out.append("Average rating: " + (average.map { fixed($0, 1) } ?? "none"))
        out.append("Unfilled slots: " + (unfilled.isEmpty ? "none" : unfilled.map(\.rawValue).joined(separator: ", ")))
        return out
    }

    private static func depth(_ report: DepthReport, parameters: EngineParameters) -> [String] {
        var out = ["", "=== Depth ===\(mark(report.basis))"]
        out.append("Cover counts players solid in the slot (familiarity \(parameters.depthSolidFamiliarity.value) or over in both phases), "
                   + "available today and not first choice elsewhere; fewer than \(parameters.depthThinBelow.value) is thin.")
        for slot in report.slots {
            let drop = slot.dropToSecond.map { "drop to second \(fixed($0, 1))" } ?? "no second choice"
            let options = slot.options.isEmpty ? "nobody" : slot.options.map { option(slot.slot, $0, parameters: parameters) }
                .joined(separator: ", ")
            let loans = slot.onLoan.isEmpty ? "" : "; out on loan: "
                + slot.onLoan.map { "\($0.name) \(fixed($0.rating, 1))" }.joined(separator: ", ")
            out.append("  \(pad(slot.slot.rawValue, 6)) cover \(slot.cover), \(drop)\(slot.isThin ? ", THIN" : ""): \(options)\(loans)")
        }
        out.append("Recruit first: " + (report.thin.isEmpty ? "none" : report.thin.map(\.rawValue).joined(separator: ", ")))
        return out
    }

    /// One option with his rating and, in brackets, what stops him counting as cover or what else he is.
    private static func option(_ slot: SlotID, _ option: DepthOption, parameters: EngineParameters) -> String {
        var marks: [String] = []
        if option.squad != .firstTeam { marks.append(squadName(option.squad)) }
        if let unavailable = option.unavailable { marks.append(ErrorDescriptions.describe(unavailable, parameters: parameters)) }
        if !option.isSolid { marks.append("familiarity \(option.ipFamiliarity)/\(option.oopFamiliarity)") }
        switch option.tier {
        case .first(let other)?: marks.append(other == slot ? "first choice" : "first choice at \(other.rawValue)")
        case .second(let other)?: marks.append(other == slot ? "second choice" : "second choice at \(other.rawValue)")
        case .backup?, nil: break
        }
        return "\(option.name) \(fixed(option.rating, 1))" + (marks.isEmpty ? "" : " (\(marks.joined(separator: "; ")))")
    }

    private static func rest(_ advice: [RestAdvice]) -> [String] {
        var out = ["", "=== Rest ==="]
        if advice.isEmpty { out.append("  nobody") }
        for one in advice {
            let limit = "limit \(one.limit)" + (one.limitNotes.isEmpty ? "" : " (\(one.limitNotes.joined(separator: ", ")))")
            let days: String
            switch one.level {
            case .holiday, .rest: days = one.days.map { ", clear in about \($0) \($0 == 1 ? "day" : "days")" } ?? ", clear in more days than the estimate covers"
            case .watch: days = ""
            }
            out.append("  \(pad(one.level.rawValue.uppercased(), 8)) \(pad(one.name, 22)) jadedness \(one.jadedness), \(limit), "
                       + "condition \(Display.percent(one.condition)), \(one.consecutiveStarts) in a row\(days)\(mark(one.basis))")
            for reason in one.reasons { out.append("        - \(reason)") }
        }
        return out
    }

    private static func training(_ report: TrainingReport) -> [String] {
        var out = ["", "=== Training ==="]
        out.append("Recommendations")
        if report.recommendations.isEmpty { out.append("  none") }
        for one in report.recommendations {
            let slots = one.needs.map { "\($0.slot.rawValue) in \($0.tactic)" }.joined(separator: ", ")
            out.append("  \(one.name) (\(one.age)): learn \(one.choice.position.rawValue), familiarity \(one.currentFamiliarity) now, "
                       + "for \(slots); learnability \(fixed(one.learnability, 2))\(mark(one.basis))")
            for reason in one.reasons { out.append("        - \(reason)") }
            for caution in one.cautions { out.append("        ! \(caution)") }
        }
        func needs(_ list: [RetrainingNeed]) -> String {
            list.isEmpty ? "none" : list.map { "\($0.slot.rawValue) in \($0.tactic)" }.joined(separator: ", ")
        }
        out.append("Already being retrained for: \(needs(report.needsBeingRetrained))")
        out.append("Needs nobody suits (recruit): \(needs(report.needsWithoutCandidates))")
        return out
    }

    private static func removal(_ report: RemovalReport) -> [String] {
        var out = ["", "=== Player Removal ==="]
        out.append("Squad average ability: " + (report.squadAverageAbility.map { fixed($0, 1) } ?? "none")
                   + "   Wages of the critical and high players: \(Display.perWeek(report.weeklyWagesAtStake))")
        var medium = 0, keep = 0
        for one in report.advice {
            switch one.level {
            case .critical, .high: break
            case .medium: medium += 1; continue
            case .keep: keep += 1; continue
            }
            var cost = "release cost unknown"
            if let release = one.releaseCost, let mutual = one.mutualCost {
                cost = "release costs \(Display.pounds(release)), a mutual termination about \(Display.pounds(mutual))"
            }
            out.append("  \(pad(one.level.rawValue.uppercased(), 8)) \(pad(action(one.action), 9)) \(pad(one.name, 22)) "
                       + "score \(one.score); \(cost)\(mark(one.basis))")
            for reason in one.reasons { out.append("        \(points(reason.points)) \(reason.text)") }
        }
        out.append("Medium (monitor): \(count(medium))   Keep: \(count(keep))")
        out.append("Loan review")
        if report.loans.isEmpty { out.append("  nobody on loan here") }
        for loan in report.loans {
            out.append("  \(pad(verdict(loan.verdict), 16)) \(pad(loan.name, 22)) score \(loan.score)\(mark(loan.basis))")
            for reason in loan.reasons { out.append("        \(points(reason.points)) \(reason.text)") }
        }
        return out
    }

    private static func importance(_ suggestions: [(fixture: Fixture, suggestion: ImportanceSuggestion)]) -> [String] {
        var out = ["", "=== Importance ==="]
        if suggestions.isEmpty { out.append("  no fixtures") }
        for (fixture, suggestion) in suggestions {
            let about = [fixture.competition.map(competition), fixture.opponentStrength.map(strength)].compactMap { $0 }
            out.append("  \(fixture.date.iso)  v \(fixture.opponent)" + (about.isEmpty ? "" : " (\(about.joined(separator: ", ")))")
                       + ": set \(fixture.importance.rawValue), suggested \(suggestion.importance.rawValue)"
                       + (fixture.importance == suggestion.importance ? "" : "  *") + mark(suggestion.basis))
            for reason in suggestion.reasons { out.append("        - \(reason)") }
        }
        return out
    }

    /// How well backed a piece of advice is, as a note after it; nothing for FM27 evidence.
    private static func mark(_ basis: Evidence) -> String {
        switch basis {
        case .fm27Measured, .fm27Official, .fm27Observation: ""
        case .carriedOverFM26: " (FM26-era numbers)"
        case .derived: " (this tool's estimate)"
        }
    }

    private static func action(_ action: RemovalAction) -> String {
        switch action {
        case .release: "release"
        case .loan: "loan out"
        case .terminate: "terminate"
        case .sell: "sell"
        case .monitor: "monitor"
        case .keep: "keep"
        }
    }

    private static func verdict(_ verdict: LoanVerdict) -> String {
        switch verdict {
        case .endEarly: "end early"
        case .doNotExtend: "do not extend"
        case .keepToEnd: "keep to the end"
        case .makePermanent: "make permanent"
        }
    }

    private static func competition(_ competition: Competition) -> String {
        switch competition {
        case .league: "league"
        case .cup: "cup"
        case .minorCup: "minor cup"
        case .friendly: "friendly"
        }
    }

    private static func strength(_ strength: OpponentStrength) -> String {
        switch strength {
        case .muchStronger: "much stronger"
        case .stronger: "stronger"
        case .similar: "similar"
        case .weaker: "weaker"
        case .muchWeaker: "much weaker"
        }
    }

    private static func count(_ n: Int) -> String { n == 1 ? "1 player" : "\(n) players" }
    private static func points(_ n: Int) -> String { n > 0 ? "+\(n)" : "\(n)" }

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

    private static func render(_ lineup: Lineup, book: SquadBook, tactic: Tactic, parameters: EngineParameters,
                               projected: Bool) -> [String] {
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
            for warning in pick.warnings {
                out.append("        ! " + ErrorDescriptions.describe(warning, parameters: parameters, projected: projected))
            }
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
