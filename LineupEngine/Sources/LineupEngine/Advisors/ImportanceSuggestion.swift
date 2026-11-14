import Foundation

/// A suggested importance for one fixture, and why. The manager's own choice (`Fixture.importance`) always wins.
public struct ImportanceSuggestion: Equatable, Sendable {
    public let importance: Importance
    public let score: Double
    public let reasons: [String]
    /// The weakest evidence among the parameters behind this suggestion.
    public let basis: Evidence
}

public enum ImportanceAdvisor {
    /// The suggestion for `fixture`, given every fixture still to play (`fixture` itself may be among them), the
    /// confirmed lineups (for the dates of matches already played), the squad and its tiers for the fixture's tactic.
    /// A first-eleven player missing from `players` is not counted as unsharp.
    public static func suggest(for fixture: Fixture, among fixtures: [Fixture], confirmed: [ConfirmedLineup],
                               players: [Player], tiers: SquadTiers,
                               parameters: EngineParameters) -> ImportanceSuggestion {
        let rules = parameters.importanceRules.value
        let others = fixtures.filter { $0.id != fixture.id }
        var reasons: [String] = []

        let base = baseScore(competition: fixture.competition, rules: rules)
        reasons.append(base.reason)
        var score = base.value
        let opponent = opponentFactor(fixture.opponentStrength, rules: rules)
        score *= opponent.value
        if let reason = opponent.reason { reasons.append(reason) }
        let ownSize = score

        // The next match after this one, earliest first, lowest id on a tie.
        let next = others.filter { $0.date > fixture.date }
            .min { ($0.date, $0.id.raw) < ($1.date, $1.id.raw) }
        var reduced = false
        if let next {
            let nextScore = baseScore(competition: next.competition, rules: rules).value
                * opponentFactor(next.opponentStrength, rules: rules).value
            let gap = fixture.date.days(to: next.date)
            // The next match must reach the line and be bigger than this one, by base times opponent.
            if nextScore >= rules.biggerMatchFrom, nextScore > ownSize,
               let step = rules.biggerMatchSteps.sorted(by: { $0.withinDays < $1.withinDays }).first(where: { gap <= $0.withinDays }) {
                score *= step.factor
                reduced = true
                reasons.append("A bigger match follows in \(gap) day\(gap == 1 ? "" : "s") (×\(factorText(step.factor)))")
            }
        }

        // Matches already played or planned in the window before this one; one match counts once. The window is the
        // match day and the days before it, `crowdedWindowDays` in all.
        let windowStart = fixture.date.adding(days: -(rules.crowdedWindowDays - 1))
        var inWindow = Set<String>()
        for lineup in confirmed where lineup.fixture != fixture.id && lineup.date >= windowStart && lineup.date < fixture.date {
            inWindow.insert(lineup.fixture.raw)
        }
        for other in others where other.date >= windowStart && other.date < fixture.date { inWindow.insert(other.id.raw) }
        if inWindow.count >= rules.crowdedMatches {
            score *= rules.crowdedFactor
            reduced = true
            reasons.append("\(ordinalMatch(inWindow.count + 1)) in \(rules.crowdedWindowDays) days (×\(factorText(rules.crowdedFactor)))")
        }

        let earlier = confirmed.filter { $0.fixture != fixture.id }.map(\.date) + others.map(\.date)
        if !reduced, let last = earlier.filter({ $0 < fixture.date }).max(),
           last.days(to: fixture.date) >= rules.restedAfterDays {
            score *= rules.restedFactor
            reasons.append("A week or more since the last match (×\(factorText(rules.restedFactor)))")
        }

        let level: Importance = score >= rules.highFrom ? .high : score >= rules.mediumFrom ? .medium : .low
        reasons.append("Score \(Int(score.rounded())): \(level.rawValue)")

        var importance = level
        if score < rules.sharpnessBelowScore {
            let daysToNext = next.map { fixture.date.days(to: $0.date) }
            let late = daysToNext.map { $0 >= rules.sharpnessMinDaysToNext } ?? true
            let byID = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            let unsharp = tiers.first.values.filter { id in byID[id].map { $0.sharpness < rules.sharpnessBelow } ?? false }.count
            if late, unsharp >= rules.sharpnessMinPlayers {
                importance = .sharpness
                let when = daysToNext.map { "the next match is \($0) day\($0 == 1 ? "" : "s") later" } ?? "no match follows"
                reasons.append("\(unsharp) of the first eleven are under \(Display.percent(rules.sharpnessBelow)) sharpness, and \(when)")
            }
        }

        return ImportanceSuggestion(importance: importance, score: score, reasons: reasons,
                                    basis: Evidence.weakest([parameters.importanceRules.evidence])!)
    }

    private static func baseScore(competition: Competition?, rules: ImportanceSuggestionRules) -> (value: Double, reason: String) {
        let (value, name): (Double, String)
        switch competition {
        case .league: (value, name) = (rules.leagueBase, "League match")
        case .cup: (value, name) = (rules.cupBase, "Cup match")
        case .minorCup: (value, name) = (rules.minorCupBase, "Minor cup match")
        case .friendly: (value, name) = (rules.friendlyBase, "Friendly")
        case nil: (value, name) = (rules.unsetBase, "No competition set")
        }
        return (value, "\(name): \(Int(value.rounded()))")
    }

    private static func opponentFactor(_ strength: OpponentStrength?, rules: ImportanceSuggestionRules) -> (value: Double, reason: String?) {
        let (value, name): (Double, String?)
        switch strength {
        case .muchStronger: (value, name) = (rules.muchStrongerFactor, "Much stronger opponent")
        case .stronger: (value, name) = (rules.strongerFactor, "Stronger opponent")
        case .similar: (value, name) = (rules.similarFactor, nil)
        case .weaker: (value, name) = (rules.weakerFactor, "Weaker opponent")
        case .muchWeaker: (value, name) = (rules.muchWeakerFactor, "Much weaker opponent")
        case nil: (value, name) = (rules.unsetOpponentFactor, nil)
        }
        return (value, name.map { "\($0) (×\(factorText(value)))" })
    }

    private static func ordinalMatch(_ number: Int) -> String {
        switch number {
        case 3: "Third match"
        case 4: "Fourth match"
        case 5: "Fifth match"
        default: "Match \(number)"
        }
    }

    private static func factorText(_ factor: Double) -> String { String(format: "%.1f", factor) }
}
