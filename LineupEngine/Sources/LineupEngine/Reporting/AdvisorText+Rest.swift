/// One squad's drift, as a line above the Rest screen's rows, with a caution when leaving players out of matches cannot
/// bring jadedness down.
public struct SquadTrendLine: Equatable, Sendable {
    public let text: String
    public let caution: String?

    public init(text: String, caution: String?) {
        self.text = text
        self.caution = caution
    }
}

/// The Rest advisor's words about the jadedness trends the readings show.
extension AdvisorText {
    /// "First team", "U21s", "U18s".
    public static func name(_ squad: Squad) -> String {
        switch squad {
        case .firstTeam: "First team"
        case .u21: "U21s"
        case .u18: "U18s"
        }
    }

    /// The squad as an owner: "the first team's", "the U21s'", "the U18s'".
    public static func possessive(_ squad: Squad) -> String {
        switch squad {
        case .firstTeam: "the first team's"
        case .u21: "the U21s'"
        case .u18: "the U18s'"
        }
    }

    /// A listed player's trend lines, in order: his trend as seen (or that it is not measured yet), when he passes the
    /// line, what a match off would do or that rest from matches will not bring it down, and that a rise with no start
    /// is from training.
    public static func trendLines(of advice: RestAdvice, parameters: EngineParameters) -> [String] {
        let trend = advice.trend
        let steady = parameters.jadednessTrendRules.value.steadyPerWeek
        var lines: [String] = []

        var rising = false
        if let seen = trend.seen {
            rising = seen.perWeek > steady
            let movement = rising ? "Rising about \(whole(seen.perWeek)) a week"
                : seen.perWeek < -steady ? "Falling about \(whole(seen.perWeek)) a week"
                : "Holding steady"
            let weeks = max(1, Int((Double(seen.days) / 7).rounded()))
            let over = weeks == 1 ? "over the last week" : "over the last \(weeks) weeks"
            let started = seen.starts == 0 ? "in which he did not start a match"
                : seen.starts == 1 ? "in which he started 1 match"
                : "in which he started \(seen.starts) matches"
            lines.append("\(movement) \(over), \(started) (from \(seen.readings) readings).")
        } else {
            lines.append("His trend is not measured yet: it needs \(trend.importsNeeded) imports of his squad, and has "
                         + "\(trend.imports).")
        }

        if let day = trend.passesOn {
            lines.append("At that rate he passes \(parameters.jadedThreshold.value) around \(shortDay(day)).")
        }

        var lighterTrainingGiven = false
        if let seen = trend.seen, seen.starts >= 1, let drift = trend.drift, let gain = trend.gain, gain.value > 0 {
            if drift.value < 0 {
                // Within the steady band, inclusive as everywhere, he holds steady; a start still adds.
                let movement = abs(drift.value * 7) <= steady ? "He holds steady without a start"
                    : "Without a start he falls about \(whole(drift.value * 7)) a week"
                lines.append("\(movement), and a start adds about \(whole(gain.value)), so a match off saves about "
                             + "\(whole(gain.value))." + rateBracket(drift: drift, gain: gain))
            } else {
                lines.append(notBroughtDown(drift, steady: steady) + rateBracket(drift: drift, gain: gain))
                lighterTrainingGiven = true
            }
        }
        if trend.restWillNotClear, !lighterTrainingGiven, let drift = trend.drift {
            lines.append(notBroughtDown(drift, steady: steady) + rateBracket(drift: drift, gain: nil))
        }

        if rising, trend.seen?.starts == 0 {
            lines.append("He has not started a match for you in that time: the rise is from training and any matches "
                         + "for another side.")
        }
        return lines
    }

    /// A line for each squad with a measured drift, in `Squad.allCases` order.
    public static func squadTrendLines(_ trends: FitnessTrends, parameters: EngineParameters) -> [SquadTrendLine] {
        let steady = parameters.jadednessTrendRules.value.steadyPerWeek
        return Squad.allCases.compactMap { squad in
            guard let rate = trends.squadDrift[squad] else { return nil }
            let weekly = rate.value * 7
            let movement = weekly > steady ? "rises about \(whole(weekly)) a week"
                : weekly < -steady ? "falls about \(whole(weekly)) a week"
                : "holds steady"
            let text = "\(name(squad)): a player who does not start \(movement) (from \(rate.readings) readings since "
                + "\(shortDay(rate.since)); \(estimate))."
            let caution = rate.value >= 0
                ? "At this training load, leaving players out of matches cannot bring jadedness down." : nil
            return SquadTrendLine(text: text, caution: caution)
        }
    }

    /// "A start adds about 31 (from 14 readings; this tool's estimate)."; nil when the club's gain is not measured.
    public static func clubGainLine(_ trends: FitnessTrends) -> String? {
        trends.clubGain.map { "A start adds about \(whole($0.value)) (from \($0.readings) readings; \(estimate))." }
    }

    /// "Trend measured from Tue 24 Aug."; nil when there is no day to measure from.
    public static func trendMeasuredFrom(_ trends: FitnessTrends) -> String? {
        trends.measuredFrom.map { "Trend measured from \(shortDay($0))." }
    }

    public static let gameMessagesHeading = "What the game's messages mean"

    /// What the game's fitness messages mean, each line with its evidence.
    public static func gameMessages(parameters: EngineParameters) -> [String] {
        let sharpness = (parameters.sharpnessDecayPerDay.value * 1_000).rounded() / 10
        let percent = sharpness == sharpness.rounded() ? String(Int(sharpness)) : String(sharpness)
        return [
            "'Tired after last match' and 'Very tired after last match' describe condition after a match and clear in "
                + "days. They are not a reason for a holiday. (this tool's reading of the wording)",
            "The game calls a player jaded above \(parameters.jadedThreshold.value). No test in any version shows a "
                + "cost below that; above 0, condition comes back more slowly. (FM27 tests)",
            "A holiday costs about \(percent)% of sharpness a day and the matches missed. A full rest day after each "
                + "match, and lighter training below full condition, cost less. (FM27 tests; the holiday's effect is "
                + "carried over from FM24)",
        ]
    }

    private static var estimate: String { note(for: .derived)! }

    /// A measured figure as a whole number of its size; the direction is in the words.
    private static func whole(_ value: Double) -> Int { Int(abs(value).rounded()) }

    /// "He rises about 16 a week without a start, …" or "He holds steady without a start, …" within the steady band.
    private static func notBroughtDown(_ drift: MeasuredRate, steady: Double) -> String {
        let weekly = drift.value * 7
        let movement = abs(weekly) <= steady ? "He holds steady" : "He rises about \(whole(weekly)) a week"
        return "\(movement) without a start, so leaving him out of matches will not bring it down. Lighter training, "
            + "or rest from training, will."
    }

    /// " (the first team's rate without a start; his own rate for a start)" when a rate named is not his own; empty
    /// when every one is.
    private static func rateBracket(drift: MeasuredRate, gain: MeasuredRate?) -> String {
        let rates = [(drift, "without a start")] + (gain.map { [($0, "for a start")] } ?? [])
        if rates.allSatisfy({ if case .own = $0.0.source { true } else { false } }) { return "" }
        let parts = rates.map { rate, use -> String in
            let whose = switch rate.source {
            case .own: "his own"
            case .squad(let squad): possessive(squad)
            case .club: "the club's"
            }
            return "\(whose) rate \(use)"
        }
        return " (" + parts.joined(separator: "; ") + ")"
    }
}
