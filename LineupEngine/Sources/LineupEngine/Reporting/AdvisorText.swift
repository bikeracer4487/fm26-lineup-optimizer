import Foundation

/// The words the advisors' screens and reports use for levels, actions, verdicts and the sentences built from their
/// numbers, written once here.
public enum AdvisorText {
    /// "Sat 14 Nov".
    public static func shortDay(_ day: Day) -> String {
        let weekdays = ["Thu", "Fri", "Sat", "Sun", "Mon", "Tue", "Wed"]
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let sinceEpoch = Day(iso: "1970-01-01")!.days(to: day)
        let weekday = weekdays[((sinceEpoch % 7) + 7) % 7]
        let parts = day.iso.split(separator: "-").compactMap { Int($0) }
        return "\(weekday) \(parts[2]) \(months[parts[1] - 1])"
    }

    /// "30 Jun 2030": a day with its year and no weekday, for a day that may be years off.
    public static func fullDay(_ day: Day) -> String {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let parts = day.iso.split(separator: "-").compactMap { Int($0) }
        return "\(parts[2]) \(months[parts[1] - 1]) \(parts[0])"
    }

    public static func name(_ level: RestLevel) -> String {
        switch level {
        case .holiday: "Holiday"
        case .rest: "Rest"
        case .watch: "Watch"
        }
    }

    public static func name(_ mark: SaleMark) -> String {
        switch mark {
        case .toSell: "To sell"
        case .toLoanOut: "To loan out"
        }
    }

    /// What a mark does and how far to trust it, shown where marks are made.
    public static let marksNote = "A marked player gets a little more playing time in low-importance and "
        + "sharpness fixtures. Whether playing a player brings offers has not been tested."

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
        case .terminate: "Terminate"
        case .sell: "Sell"
        case .monitor: "Monitor"
        case .develop: "Keep and develop"
        case .play: "Keep and play"
        case .loanForMatches: "Loan for matches"
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

    public static func name(_ situation: LeagueSituation) -> String {
        switch situation {
        case .titleRaceOrRelegationFight: "Title race or relegation fight"
        case .inContention: "In contention"
        case .midTable: "Mid-table"
        case .nothingToPlayFor: "Nothing to play for"
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

    /// Under a fixture's left-out list while it is the match the bans are served in: who is banned, that FMRTE does
    /// not say which matches a ban is for, and what saying so does. `names` are the banned players, in the order given.
    public static func bansServedHere(_ names: [String]) -> String {
        let one = names.count == 1
        return "\(nameList(names)) \(one ? "is" : "are") banned and left out of this match. FMRTE shows a ban but not "
            + "which matches it is for. If \(one ? "his ban is" : "their bans are") not for this match, say so: "
            + "\(one ? "he is" : "they are") then picked as usual here and left out of the next match that takes bans."
    }

    /// Under a fixture's left-out list when bans do not count in it and somebody is banned. `isFriendly`: nobody said
    /// so, it is a friendly.
    public static func bansNotApplied(_ names: [String], isFriendly: Bool) -> String {
        let one = names.count == 1
        return "Bans are not applied to this match, \(isFriendly ? "a friendly" : "as you said"): \(nameList(names)) "
            + "\(one ? "is" : "are") banned and can be picked here. \(one ? "He is" : "They are") left out of the next "
            + "match that takes bans."
    }

    private static func nameList(_ names: [String]) -> String {
        names.count <= 1 ? (names.first ?? "") : names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
    }

    /// A game plan by the name the game gives it when a match is simulated.
    public static func name(_ plan: GamePlan) -> String {
        switch plan {
        case .noGamePlan: "No game plan"
        case .playForTheWin: "Play for the win"
        case .playForTheDraw: "Play for the draw"
        case .settleForADraw: "Settle for a draw"
        case .goForABigWin: "Go for a big win"
        case .smashAndGrab: "Smash and grab"
        case .leaveItLate: "Leave it late"
        case .pressureCooker: "Pressure cooker"
        case .strangleTheGame: "Strangle the game"
        }
    }

    /// "If you simulate this match: Play for the win or No game plan": the plans to use, which nothing separates.
    public static func gamePlanLine(_ advice: GamePlanAdvice) -> String {
        let names = advice.use.map(name)
        let list = names.count <= 1 ? (names.first ?? "") : names.dropLast().joined(separator: ", ") + " or " + names[names.count - 1]
        return "If you simulate this match: \(list)"
    }

    /// What the advice rests on, which plans to avoid and why, and what is not known. Each sentence says whether it
    /// is a measurement or reasoning, and names the one test of the plans.
    public static func gamePlanSentences(_ advice: GamePlanAdvice) -> [String] {
        let test = "the one test of the game plans (FM26, ten matches a plan, against a much stronger side)"
        let many = advice.use.count > 1
        var sentences: [String] = []
        // Whether the test has been described by the time the plans to avoid are named.
        var testNamed = false
        switch advice.strength {
        case .muchStronger:
            sentences.append("The one test of the game plans (FM26, ten matches a plan) was against a much stronger side "
                + "like this one: \(planList(advice.use, points: advice.testPoints)) came out best"
                + "\(many ? ", too close to tell apart" : "").")
            testNamed = true
        case .stronger:
            sentences.append("No test covers a stronger side like this one. The one test of the game plans (FM26, ten "
                + "matches a plan) was against a much stronger side, where "
                + "\(planList(advice.use, points: advice.testPoints)) came out best; using \(many ? "them" : "it") here is "
                + "reasoning from that, not a measurement.")
            testNamed = true
        case .similar, .weaker, .muchWeaker:
            let kind = switch advice.strength {
            case .weaker: "a weaker side"
            case .muchWeaker: "a much weaker side"
            case .similar, .muchStronger, .stronger, nil: "a side of similar strength"
            }
            let noPlan = advice.use.contains(.noGamePlan)
                ? ", and none sets No game plan (your tactic as you set it) against a plan" : ""
            sentences.append("No test covers \(kind) like this one\(noPlan). \(planList(advice.use, points: [:])) "
                + "\(many ? "are reasoned choices, not measured ones, and nothing separates them" : "is a reasoned choice, not a measured one").")
        case nil:
            sentences.append("This fixture has no strength set for the opponent, so this is what is advised against every "
                + "strength. Set their strength on the Fixtures screen, or paste their squad there, for advice that fits "
                + "the match.")
        }
        if !advice.avoid.isEmpty {
            let they = advice.avoid.count == 1 ? "it" : "they"
            let deep = advice.isMeasured ? "" : ", and sitting deep costs points in FM27 engine tests"
            sentences.append("Avoid \(planList(advice.avoid, points: advice.testPoints)): \(they) came out worst in "
                + "\(testNamed ? "that test" : test)\(deep).")
        }
        switch advice.strength {
        case .muchStronger, .stronger:
            if !advice.use.contains(.noGamePlan) {
                sentences.append("No game plan was not in the test, so how your own tactic compares is not known.")
            }
        case .similar, .weaker, .muchWeaker, nil:
            break
        }
        return sentences
    }

    /// "A (10 points), B (9 points) and C"; a plan with no points in `points` is named alone.
    private static func planList(_ plans: [GamePlan], points: [GamePlan: Int]) -> String {
        let names = plans.map { plan in
            points[plan].map { "\(name(plan)) (\($0) point\($0 == 1 ? "" : "s"))" } ?? name(plan)
        }
        return names.count <= 1 ? (names.first ?? "") : names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
    }

    /// A fixture's importance by name, as a menu or a badge shows it.
    public static func name(_ importance: Importance) -> String {
        switch importance {
        case .high: "High"
        case .medium: "Medium"
        case .low: "Low"
        case .sharpness: "Sharpness"
        }
    }

    /// "Suggested: High": the importance the advice suggests for a fixture.
    public static func suggested(_ suggestion: ImportanceSuggestion) -> String {
        "Suggested: \(name(suggestion.importance))"
    }

    /// How well backed a piece of advice is, as a note after it; nil for FM27 evidence.
    public static func note(for basis: Evidence) -> String? {
        switch basis {
        case .fm27Measured, .fm27Official, .fm27Observation: nil
        case .carriedOverFM26: "FM26-era numbers"
        case .derived: "this tool's estimate"
        }
    }

    /// "Clear in about 3 days"; nil for watch, which has nothing to clear, and when rest from matches will not clear
    /// it (his trend lines say so).
    public static func clear(in advice: RestAdvice) -> String? {
        switch advice.level {
        case .holiday, .rest:
            if advice.trend.restWillNotClear { return nil }
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

    /// What releasing him costs, in the squads' currency: "Releasing him costs about $33,222; a mutual termination about
    /// $18,272".
    public static func costs(of advice: RemovalAdvice, money: MoneyStyle) -> String {
        guard let release = advice.releaseCost, let mutual = advice.mutualCost else {
            return "The cost of releasing him is not known"
        }
        if release == 0 && mutual == 0 { return "Releasing him costs nothing" }
        return "Releasing him costs about \(Display.money(release, symbol: money.symbol)); "
            + "a mutual termination about \(Display.money(mutual, symbol: money.symbol))"
    }

    /// A reason's points with their sign: "+25" against him, "−40" (a true minus, U+2212) for him, "0" for neither.
    public static func points(of reason: RemovalReason) -> String {
        reason.points > 0 ? "+\(reason.points)" : signed(reason.points)
    }

    /// A removal or loan score: "45", "0", or "−12" with a true minus sign (U+2212).
    public static func score(_ score: Int) -> String {
        signed(score)
    }

    /// A negative number with a true minus sign (U+2212), as the app writes it; any other as it is.
    private static func signed(_ number: Int) -> String {
        signedNumber(number)
    }

    /// A whole number as the owner reads it: "12", "0", or "−10" with a true minus sign (U+2212), never a hyphen.
    public static func signedNumber(_ number: Int) -> String {
        number < 0 ? "\u{2212}\(number.magnitude)" : String(number)
    }

    /// The rule that chose the action, in one sentence. The termination line is a parameter, so it is not named in
    /// months here. A release is said from his contract: out of contract, or on a youth contract nearly up, where a
    /// full-time contract would be terminated. A young player kept to develop, kept to play or watched is told why from `advice.keepReason`,
    /// `advice.matchesHere` and `advice.watchReason`, and a loan for matches at the youngest age for one says it is
    /// worth it only where he will start.
    public static func why(_ action: RemovalAction, for advice: RemovalAdvice) -> String {
        switch action {
        case .release:
            advice.onYouthContract
                ? "He is on a youth contract that is nearly up, so releasing him is the way to move him on"
                : "He is out of contract, so releasing him costs nothing"
        case .develop: whyDevelop(advice.keepReason, advice.matchesHere?.basis)
        case .play:
            whyPlay(advice.matchesHere?.basis, isWorthDeveloping: advice.outlook.map(Removal.isWorthDeveloping) ?? true)
        case .loanForMatches: whyLoanForMatches(advice.matchesHere?.basis, onlyToStart: advice.loanOnlyToStart)
        case .terminate: "His contract is nearly over and no fee is likely to beat the cost of ending it"
        case .sell: "Selling is the way left: nothing cheaper applies"
        case .monitor:
            whyWatch(advice.watchReason, level: advice.outlook?.level,
                     isWorthDeveloping: advice.outlook.map(Removal.isWorthDeveloping) ?? true)
        case .keep: "Nothing here says he should go"
        }
    }

    /// What to do before a player who is needed at a slot goes, and why he is needed: "Sign a replacement at goalkeeper
    /// before he goes: he is first choice there and cover is thin."
    public static func replaceFirst(_ need: RemovalNeed) -> String {
        let why = switch need.kind {
        case .firstChoiceWhereThin: "he is first choice there and cover is thin"
        case .cover: "cover there would be thin without him"
        case .standIn: "too few players can step in there without him"
        }
        return "Sign a replacement at \(PositionText.plain(need.slot.position)) before he goes: \(why)."
    }

    /// "Nobody counts as cover; 2 needed", "1 player counts as cover; 2 needed", "2 players count as cover".
    public static func cover(_ slot: SlotDepth, parameters: EngineParameters) -> String {
        let line = parameters.depthThinBelow.value
        let count = slot.cover == 0 ? "Nobody counts as cover" : slot.cover == 1 ? "1 player counts as cover"
            : "\(slot.cover) players count as cover"
        return slot.cover < line ? "\(count); \(line) needed" : count
    }

    /// "Thin cover: goalkeeper, left back": the thin slots, most in need first; nil when no slot is thin. It names them
    /// without saying what to do: whether to retrain or recruit is Training's advice.
    public static func thinCover(_ depth: DepthReport) -> String? {
        guard !depth.thin.isEmpty else { return nil }
        return "Thin cover: " + depth.thin.map { PositionText.plain($0) }.joined(separator: ", ")
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
        "Cover counts players solid in the slot (familiarity \(parameters.depthSolidFamiliarity.value) or over in both phases) "
            + "who rate at least \(Display.percent(parameters.depthCoverShare.value)) of the first choice there, "
            + "not injured and not first choice elsewhere; fewer than \(parameters.depthThinBelow.value) is thin"
    }

    /// "Under 80% of the first choice: not counted as cover", for an option Depth marks `isBelowCoverShare`.
    public static func belowCoverShare(_ parameters: EngineParameters) -> String {
        "Under \(Display.percent(parameters.depthCoverShare.value)) of the first choice: not counted as cover"
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

    /// "Left back in Sample 4-2-3-1": a thin slot in words, then its tactic; and, where cover there is advised to
    /// leave, "(not counting Jonny Maxted, whom Player Removal advises moving on)", since Depth still counts him.
    public static func need(_ need: RetrainingNeed) -> String {
        let slot = PositionText.plain(need.slot)
        return slot.prefix(1).uppercased() + slot.dropFirst() + " in \(need.tactic)"
            + (notCounting(need.going).map { " (\($0))" } ?? "")
    }

    /// "not counting A, B and C, whom Player Removal advises moving on"; nil for nobody.
    static func notCounting(_ names: [String]) -> String? {
        guard let last = names.last else { return nil }
        let list = names.count == 1 ? last : names.dropLast().joined(separator: ", ") + " and " + last
        return "not counting \(list), whom Player Removal advises moving on"
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

    /// "No retraining is recommended today." when the report recommends nobody; nil when it recommends someone.
    public static func nothingRecommended(_ report: TrainingReport) -> String? {
        report.recommendations.isEmpty ? "No retraining is recommended today." : nil
    }

    /// What the list of slots to recruit for says when it names none: "No slot is thin." when no saved tactic has a
    /// thin slot; "Every thin slot has someone learning it or recommended for it." when each thin slot has a
    /// recommendation or a retraining under way; nil when some thin slot has neither, since the list names it. Every
    /// thin slot is in the report: covered by a recommendation, or among the needs without candidates or being retrained.
    public static func nothingToRecruit(_ report: TrainingReport) -> String? {
        guard report.needsWithoutCandidates.isEmpty else { return nil }
        if report.recommendations.isEmpty && report.needsBeingRetrained.isEmpty { return "No slot is thin." }
        return "Every thin slot has someone learning it or recommended for it."
    }

    /// "No saved tactic is thin at left back now: this retraining is not needed for cover", for a retraining in
    /// `TrainingReport.retrainingsNotNeeded`.
    public static func notNeededForCover(_ position: Position) -> String {
        "No saved tactic is thin at \(PositionText.plain(position)) now: this retraining is not needed for cover"
    }

    /// "Player Removal advises moving him on.", for a player being retrained whom Player Removal advises moving on;
    /// `name` is the player's.
    public static func advisedToLeave(_ name: String) -> String {
        "Player Removal advises moving him on."
    }

    /// What accepting a retraining did: "Keegan Bloom is now learning left back. Set it up in the game as well."
    public static func nowLearning(name: String, position: Position) -> String {
        "\(name) is now learning \(PositionText.plain(position)). Set it up in the game as well."
    }

    /// What turning a retraining down did: "Ewan Clark will not be offered left back again."
    public static func notOfferedAgain(name: String, position: Position) -> String {
        "\(name) will not be offered \(PositionText.plain(position)) again."
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
        case .behind:
            guard let rate = progress.gainedPerWeek, let toSolid = progress.weeksToSolid,
                  let expected = progress.expectedWeeks else {
                return "Familiarity at \(place) \(start) to \(latest) in \(weeks) \(weeks == 1 ? "week" : "weeks"): well behind its estimate"
            }
            return "Familiarity at \(place) \(start) to \(latest) in \(weeks) \(weeks == 1 ? "week" : "weeks"): "
                + "about \(String(format: "%.1f", rate)) a week, \(toSolid) \(toSolid == 1 ? "week" : "weeks") to solid. "
                + "That is well behind the estimate of about \(expected) \(expected == 1 ? "week" : "weeks") in all: "
                + "check in the game that he is training there"
        case .stalled:
            return "Familiarity at \(place) has not moved from \(start) in \(weeks) \(weeks == 1 ? "week" : "weeks")"
        case .reached:
            return "Solid at \(place): familiarity \(latest)"
        }
    }

    /// One sentence on what a pasted opponent squad was found to be worth, with the clubs of the players left out as away
    /// on loan when there are any. `day` is the date as the owner reads it. A reading carried from an earlier paste names
    /// the day the owner's side was measured and asks for the squad again if it has changed.
    public static func opponentReading(_ reading: OpponentReading, on day: String) -> String {
        let yours = reading.ownDay.map { $0 == reading.day ? ", against yours that day" : ", against yours on \(shortDay($0))" } ?? ""
        var text = "Squad pasted for \(reading.club) on \(day)\(yours): their best eleven averages "
            + "\(String(format: "%.1f", reading.theirAverage)) ability, yours \(String(format: "%.1f", reading.ownAverage)), "
            + "which reads as \(name(reading.strength)) (this tool's estimate)."
        if !reading.awayOnLoanAt.isEmpty {
            let clubs = reading.awayOnLoanAt
            let list = clubs.count == 1 ? clubs[0] : clubs.dropLast().joined(separator: ", ") + " and " + clubs[clubs.count - 1]
            text += " Left out as away on loan: players at \(list)."
        }
        if reading.ownDay != nil { text += " Paste their squad again if it has changed." }
        return text
    }
}
