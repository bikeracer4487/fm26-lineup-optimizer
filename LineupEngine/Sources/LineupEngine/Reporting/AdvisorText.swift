import Foundation

/// The words the advisors' screens and reports use for levels, actions, verdicts and the sentences built from their
/// numbers, written once here.
public enum AdvisorText {
    public static func name(_ level: RestLevel) -> String {
        switch level {
        case .holiday: "Holiday"
        case .rest: "Rest"
        case .watch: "Watch"
        }
    }

    public static func name(_ level: RemovalLevel) -> String {
        switch level {
        case .critical: "Critical"
        case .high: "High"
        case .medium: "Medium"
        case .keep: "Keep"
        }
    }

    public static func name(_ action: RemovalAction) -> String {
        switch action {
        case .release: "Release"
        case .loan: "Loan out"
        case .terminate: "Terminate"
        case .sell: "Sell"
        case .monitor: "Monitor"
        case .keep: "Keep"
        }
    }

    public static func name(_ verdict: LoanVerdict) -> String {
        switch verdict {
        case .endEarly: "End early"
        case .doNotExtend: "Do not extend"
        case .keepToEnd: "Keep to the end"
        case .makePermanent: "Make permanent"
        }
    }

    public static func name(_ difficulty: RetrainingDifficulty) -> String {
        switch difficulty {
        case .fluid: "Fluid"
        case .structural: "Structural"
        case .spatial: "Spatial"
        case .inversion: "Inversion"
        }
    }

    public static func name(_ competition: Competition) -> String {
        switch competition {
        case .league: "League"
        case .cup: "Cup"
        case .minorCup: "Minor cup"
        case .friendly: "Friendly"
        }
    }

    public static func name(_ strength: OpponentStrength) -> String {
        switch strength {
        case .muchStronger: "Much stronger"
        case .stronger: "Stronger"
        case .similar: "Similar"
        case .weaker: "Weaker"
        case .muchWeaker: "Much weaker"
        }
    }

    /// How well backed a piece of advice is, as a note after it; nil for FM27 evidence.
    public static func note(for basis: Evidence) -> String? {
        switch basis {
        case .fm27Measured, .fm27Official, .fm27Observation: nil
        case .carriedOverFM26: "FM26-era numbers"
        case .derived: "this tool's estimate"
        }
    }

    /// "Clear in about 3 days"; nil for watch, which has nothing to clear.
    public static func clear(in advice: RestAdvice) -> String? {
        switch advice.level {
        case .holiday, .rest:
            guard let days = advice.days else { return "Clear in more days than the estimate covers" }
            return "Clear in about \(days) \(days == 1 ? "day" : "days")"
        case .watch:
            return nil
        }
    }

    /// "450 against a limit of 400"; a negative jadedness with a true minus sign (U+2212), as the app writes it.
    public static func jadedness(of advice: RestAdvice) -> String {
        let figure = advice.jadedness < 0 ? "\u{2212}\(advice.jadedness.magnitude)" : String(advice.jadedness)
        return "\(figure) against a limit of \(advice.limit)"
    }

    /// Why his limit differs from the standard one, the notes in their order: "aged 32 or over, Stamina below 10";
    /// nil when it does not.
    public static func limitNotes(of advice: RestAdvice) -> String? {
        advice.limitNotes.isEmpty ? nil : advice.limitNotes.joined(separator: ", ")
    }

    public static func costs(of advice: RemovalAdvice) -> String {
        guard let release = advice.releaseCost, let mutual = advice.mutualCost else {
            return "The cost of releasing him is not known"
        }
        if release == 0 && mutual == 0 { return "Releasing him costs nothing" }
        return "Releasing him costs \(Display.pounds(release)); a mutual termination about \(Display.pounds(mutual))"
    }

    /// The rule that chose the action, in one sentence. The termination line is a parameter, so it is not named in
    /// months here.
    public static func why(_ action: RemovalAction, for advice: RemovalAdvice) -> String {
        switch action {
        case .release: "He is out of contract, so releasing him costs nothing"
        case .loan: "A young player with room to grow: a loan gives him matches"
        case .terminate: "His contract is nearly over and no fee is likely to beat the cost of ending it"
        case .sell: "Selling is the way left: nothing cheaper applies"
        case .monitor: "Not enough against him to act: watch how he does"
        case .keep: "Nothing here says he should go"
        }
    }

    /// "No solid player; 2 needed", "1 solid player; 2 needed", "2 solid players".
    public static func cover(_ slot: SlotDepth, parameters: EngineParameters) -> String {
        let line = parameters.depthThinBelow.value
        let count = slot.cover == 0 ? "No solid player" : slot.cover == 1 ? "1 solid player" : "\(slot.cover) solid players"
        return slot.cover < line ? "\(count); \(line) needed" : count
    }

    /// "Recruit first: goalkeeper, left back": the thin slots, most in need first; nil when no slot is thin.
    public static func recruitFirst(_ depth: DepthReport) -> String? {
        guard !depth.thin.isEmpty else { return nil }
        return "Recruit first: " + depth.thin.map { PositionText.plain($0) }.joined(separator: ", ")
    }

    /// "Next best: Josh Ashby, 6.7 lower": who would step in at the slot, `name` being the next best's, and how far his
    /// rating there is below the first choice's, to one decimal; "Nobody else can step in" when nobody could.
    public static func nextBest(_ slot: SlotDepth, name: String?) -> String {
        guard let drop = slot.dropToNextBest, let name else { return "Nobody else can step in" }
        let gap = String(format: "%.1f", abs(drop))
        if gap == String(format: "%.1f", 0.0) { return "Next best: \(name), rated the same" }
        return "Next best: \(name), \(gap) \(drop > 0 ? "lower" : "higher")"
    }

    public static func whatCoverCounts(_ parameters: EngineParameters) -> String {
        coverRule(parameters) + "."
    }

    /// The same sentence with the note for `basis` in brackets before its full stop: "…fewer than 2 is thin (this
    /// tool's estimate)."; without one for FM27 evidence.
    public static func whatCoverCounts(_ parameters: EngineParameters, basis: Evidence) -> String {
        coverRule(parameters) + (note(for: basis).map { " (\($0))" } ?? "") + "."
    }

    private static func coverRule(_ parameters: EngineParameters) -> String {
        "Cover counts players solid in the slot (familiarity \(parameters.depthSolidFamiliarity.value) or over in both phases), "
            + "not injured and not first choice elsewhere; fewer than \(parameters.depthThinBelow.value) is thin"
    }

    /// "Also needed at left back, centre-back and striker": the other slots where an option is first or second
    /// choice, in the order given; nil for none.
    public static func alsoNeeded(at slots: [SlotID]) -> String? {
        let names = slots.map { PositionText.plain($0) }
        guard let last = names.last else { return nil }
        let list = names.count == 1 ? last : names.dropLast().joined(separator: ", ") + " and " + last
        return "Also needed at \(list)"
    }

    /// "Nobody can play here" for a slot with no options; nil otherwise.
    public static func nobodyCanPlay(_ slot: SlotDepth) -> String? {
        slot.options.isEmpty ? "Nobody can play here" : nil
    }

    /// "Learn left back".
    public static func learn(_ position: Position) -> String {
        "Learn \(PositionText.plain(position))"
    }

    /// "Learning left back", for a retraining under way.
    public static func learning(_ position: Position) -> String {
        "Learning \(PositionText.plain(position))"
    }

    /// "Left back in Sample 4-2-3-1": a thin slot in words, then its tactic.
    public static func need(_ need: RetrainingNeed) -> String {
        let slot = PositionText.plain(need.slot)
        return slot.prefix(1).uppercased() + slot.dropFirst() + " in \(need.tactic)"
    }

    /// "Covers left back in Sample 4-2-3-1 and left centre-back in Another": the thin slots a retraining would cover,
    /// in the order given, each named once; nil for none.
    public static func covers(_ needs: [RetrainingNeed]) -> String? {
        list(needs).map { "Covers \($0)" }
    }

    /// "Already being retrained for: left back in Sample 4-2-3-1": the thin slots a retraining under way is meant to
    /// fill, in the order given; nil for none.
    public static func alreadyBeingRetrained(_ needs: [RetrainingNeed]) -> String? {
        list(needs).map { "Already being retrained for: \($0)" }
    }

    /// "About 21 weeks: a structural change from right back".
    public static func timeToLearn(_ recommendation: RetrainingRecommendation) -> String {
        let weeks = recommendation.weeks
        let change = name(recommendation.difficulty).lowercased()
        let article = change.first.map { "aeiou".contains($0) } == true ? "an" : "a"
        return "About \(weeks) \(weeks == 1 ? "week" : "weeks"): \(article) \(change) change from "
            + PositionText.plain(recommendation.from)
    }

    /// "left back in X, goalkeeper in Y and striker in Z", each need named once in the order given; nil for none.
    private static func list(_ needs: [RetrainingNeed]) -> String? {
        var names: [String] = []
        for need in needs {
            let name = "\(PositionText.plain(need.slot)) in \(need.tactic)"
            if !names.contains(name) { names.append(name) }
        }
        guard let last = names.last else { return nil }
        return names.count == 1 ? last : names.dropLast().joined(separator: ", ") + " and " + last
    }

    public static func progress(_ progress: RetrainingProgress, toward position: Position,
                                parameters: EngineParameters) -> String {
        let place = PositionText.plain(position)
        guard let start = progress.start, let latest = progress.latest else {
            return "No familiarity recorded yet: it is read at each import"
        }
        let weeks = Int(progress.weeks.rounded())
        switch progress.state {
        case .noData:
            return "No familiarity recorded yet: it is read at each import"
        case .improving:
            guard let rate = progress.gainedPerWeek, rate > 0, let toSolid = progress.weeksToSolid else {
                return "Familiarity at \(place) \(latest) so far: too early to tell"
            }
            return "Familiarity at \(place) \(start) to \(latest) in \(weeks) \(weeks == 1 ? "week" : "weeks"): "
                + "about \(String(format: "%.1f", rate)) a week, \(toSolid) \(toSolid == 1 ? "week" : "weeks") to solid"
        case .stalled:
            return "Familiarity at \(place) has not moved from \(start) in \(weeks) \(weeks == 1 ? "week" : "weeks")"
        case .reached:
            return "Solid at \(place): familiarity \(latest)"
        }
    }
}
