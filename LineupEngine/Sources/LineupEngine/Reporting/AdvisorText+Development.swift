import Foundation

/// The words a young player's outlook and advice use, written once here: the band names, Player Removal's reach line,
/// the working behind a reach, where he stands at his best slot and whether he gets matches here.
extension AdvisorText {
    public static func name(_ band: ReachBand) -> String {
        switch band {
        case .close: "Close"
        case .onCourse: "On course"
        case .possible: "Possible"
        case .notExpected: "Not expected"
        }
    }

    /// Player Removal's one line from his reach, for his level: "Could pass Smith at left back", naming his best slot
    /// through `names`; with no best slot, against the first team's average: "Could reach the level of the first team".
    /// nil for an outlook with no level.
    public static func reachLine(_ outlook: Outlook, names: (SlotID) -> String) -> String? {
        guard let level = outlook.level else { return nil }
        if let best = outlook.best {
            let position = names(best.slot)
            switch level {
            case .couldPassFirst:
                // `best` always has a first choice who is not him; without one the sentences below apply.
                if let first = best.firstChoice { return "Could pass \(first.name) at \(position)" }
            case .couldMakeSecond: return "Could make the second eleven at \(position)"
            case .couldBeCover: return "Could become cover at \(position), no more"
            case .markedlyLower: return "Not expected to reach the level of the squad at any position"
            }
        }
        // Compared with the first team's average: there is no first choice to pass.
        switch level {
        case .couldPassFirst, .couldMakeSecond: return "Could reach the level of the first team"
        case .couldBeCover: return "Could come close to the level of the first team, no more"
        case .markedlyLower: return "Not expected to reach the level of the first team"
        }
    }

    /// The reason on the planner's development floor: "Young player with room to grow: favoured for minutes (×1.07)",
    /// the factor to two decimals as the other reasons show theirs.
    public static func developmentFloor(_ factor: Double) -> String {
        "Young player with room to grow: favoured for minutes (×\(Display.twoDecimals(factor)))"
    }

    /// The reason on the planner's successor favour, at a slot where he is expected to pass the first choice: "On course
    /// to pass Smith at left back: favoured for matches there (×1.05)", or "Close to passing Smith at left back: …" when
    /// he is close. `position` is the slot in words; the factor is to two decimals, as the floor's is.
    public static func successor(isClose: Bool, passing rival: String, at position: String, factor: Double) -> String {
        let passing = isClose ? "Close to passing" : "On course to pass"
        return "\(passing) \(rival) at \(position): favoured for matches there (×\(Display.twoDecimals(factor)))"
    }

    /// Said where a player on a youth contract would be marked to sell or to loan out.
    public static let youthContractNotMarked = "A player on a youth contract cannot be sold or loaned out, only released."

    /// How his reach was worked out, as a reach figure is never shown without it: "Ability 55, potential 140. At 16 with
    /// Professionalism 15 this tool expects about 13 points a season now, fewer later: could reach his potential." An
    /// Ambition or Determination that slows his growth is named after the Professionalism, and a Professionalism that
    /// holds him back is said to, as the estimate's flags say. Figures are whole numbers.
    public static func reachWorking(_ estimate: ReachEstimate) -> String {
        let figures = "Ability \(estimate.current), potential \(estimate.potential)."
        // Past the last growth step there are no seasons ahead.
        guard estimate.bySeason.count > 1 else { return "\(figures) At \(estimate.age) this tool expects no more growth." }
        var traits = ["Professionalism \(estimate.professionalism)"]
        if estimate.ambitionSlows { traits.append("Ambition \(estimate.ambition)") }
        if estimate.determinationSlows { traits.append("Determination \(estimate.determination)") }
        let named = traits.count == 1 ? traits[0] : traits.dropLast().joined(separator: ", ") + " and " + traits.last!
        let rate = "about \(points(estimate.seasonGrowth)) a season"
        let expects = "\(figures) At \(estimate.age) with \(named) this tool expects \(rate) now, fewer later"
        if Double(estimate.potential - estimate.current) < estimate.seasonGrowth {
            return "\(expects). His potential is the limit."
        }
        if estimate.reachesPotential { return "\(expects): could reach his potential." }
        let reach = "\(expects): could reach about \(whole(estimate.reach))."
        guard estimate.professionalismHoldsBack else { return reach }
        return "\(reach) At his Professionalism this tool expects \(rate); mentoring could change that."
    }

    /// Where he stands at his best slot: "Needs about 14 more ability points to match Smith at left back; this tool
    /// expects about 12 a season. On course.", with " Smith is 31." for a first choice the engine names with his age
    /// (`Rival.isAgeNamed`) and " Smith is 20 and
    /// still growing." for one compared at his own reach. Begins "First choice at striker." at a slot he is first choice
    /// at; when that slot's words are his best slot's (two defensive midfield slots), that is all it says. nil when he
    /// is first choice nowhere and has no slot with a first choice to pass.
    public static func standing(_ outlook: Outlook, names: (SlotID) -> String) -> String? {
        var parts: [String] = []
        let home = outlook.slots.first(where: \.isFirstChoice).map { names($0.slot) }
        if let home { parts.append("First choice at \(home).") }
        if let best = outlook.best, names(best.slot) != home, let first = best.firstChoice,
           let needed = best.pointsNeeded, let band = best.band {
            let need = needed == 0 ? "Needs no more ability points"
                : "Needs about \(needed) more ability \(needed == 1 ? "point" : "points")"
            var sentence = "\(need) to match \(first.name) at \(names(best.slot)); this tool expects about "
                + "\(whole(outlook.estimate.seasonGrowth)) a season. \(name(band))."
            if first.compared > first.rating {
                sentence += " \(first.name) is \(first.age) and still growing."
            } else if first.isAgeNamed {
                sentence += " \(first.name) is \(first.age)."
            }
            parts.append(sentence)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// "He has started 1 of the last 9 matches here."; when they are not counted, or none is confirmed, that too few are.
    public static func matchesHere(_ matches: MatchesHere) -> String {
        guard matches.isCounted, matches.matches > 0 else { return tooFewToCount }
        return "He has started \(matches.starts) of the last \(matches.matches) "
            + "\(matches.matches == 1 ? "match" : "matches") here."
    }

    /// The lines that show a young player's outlook and advice, in order: how his reach was worked out, where he stands
    /// at his best slot when he has a standing, whether he gets matches here when that line adds something, and why the
    /// action. The matches line is shown for a player kept to play, loaned for matches or kept to develop, except where
    /// the why already says his starts were not counted (a second choice kept to play, or too few matches confirmed) or
    /// where matches do not come into it (kept to develop at his age). Positions are named through `names`. Empty for a
    /// player without an outlook.
    public static func youngLines(_ advice: RemovalAdvice, names: (SlotID) -> String) -> [String] {
        guard let outlook = advice.outlook else { return [] }
        var lines = [reachWorking(outlook.estimate)]
        if let standing = standing(outlook, names: names) { lines.append(standing) }
        let basis = advice.matchesHere?.basis
        let showsMatches: Bool
        switch advice.action {
        case .play: showsMatches = basis != .solidSecondChoice
        case .loanForMatches: showsMatches = basis != .tooFewConfirmed
        case .develop: showsMatches = advice.keepReason != .age && basis != .tooFewConfirmed
        case .release, .terminate, .sell, .monitor, .keep: showsMatches = false
        }
        if showsMatches, let matches = advice.matchesHere { lines.append(matchesHere(matches)) }
        lines.append(why(advice.action, for: advice))
        return lines
    }

    /// Why a young player is kept to develop, for `why(_:for:)`. When his starts were not counted (`basis` is too few
    /// confirmed), it says he has no solid place in the elevens, not that he is not getting matches.
    static func whyDevelop(_ reason: KeepReason?, _ basis: MatchesHereBasis?) -> String {
        let uncounted = startsNotCounted(basis)
        switch reason {
        case .age?: return "At his age he grows mainly in training; a loan would add little."
        case .youthContract?:
            return uncounted
                ? "He has no solid place in the first or second eleven, and a loan needs a full-time contract. "
                    + tooFewToCount
                : "He is not getting matches here, and a loan needs a full-time contract."
        case .shortContract?:
            return uncounted
                ? "He has no solid place in the first or second eleven: renew his contract before a loan. " + tooFewToCount
                : "He is not getting matches here: renew his contract before a loan."
        // Player Removal gives every advice to develop a reason; one built without is said plainly.
        case nil: return "He is worth developing here."
        }
    }

    /// Why a young player is loaned for matches, read from `basis` as `whyDevelop` reads it, with the sentence for a
    /// loan at the youngest age for one after it.
    static func whyLoanForMatches(_ basis: MatchesHereBasis?, onlyToStart: Bool) -> String {
        let reason = startsNotCounted(basis)
            ? "He is worth developing and has no solid place in the first or second eleven: a loan gives him matches. "
                + tooFewToCount
            : "He is worth developing and is not getting matches here: a loan gives him matches."
        return reason + (onlyToStart ? " Only where he will start regularly; otherwise he grows nearly as well here." : "")
    }

    private static let tooFewToCount = "Too few matches are confirmed to count his starts."

    /// His starts were not counted: too few matches confirmed, and no solid place to decide it for him.
    private static func startsNotCounted(_ basis: MatchesHereBasis?) -> Bool {
        switch basis {
        case .tooFewConfirmed?: true
        case .firstChoice?, .startedEnough?, .startedTooFew?, .solidSecondChoice?, nil: false
        }
    }

    /// Why a young player is kept to play, from what decided that he gets his matches here.
    static func whyPlay(_ basis: MatchesHereBasis?) -> String {
        switch basis {
        case .firstChoice?: "He is first choice here."
        case .startedEnough?: "He is getting his matches here."
        case .solidSecondChoice?: "He is second choice here, and too few matches are confirmed to count his starts."
        // Player Removal keeps a player to play only on the three above; an advice built otherwise is said plainly.
        case .startedTooFew?, .tooFewConfirmed?, nil: "Nothing here says he should go"
        }
    }

    /// Why a player is watched; a player without an outlook keeps the general sentence.
    static func whyWatch(_ reason: WatchReason?) -> String {
        switch reason {
        case .notWorthDeveloping?: "This tool does not expect him to reach the second eleven: watch how he does."
        case .neededForCover?: "He is needed as cover here, so a loan would leave the squad short."
        case nil: "Not enough against him to act: watch how he does"
        }
    }

    /// A figure rounded to the nearest whole number.
    private static func whole(_ x: Double) -> Int { Int(x.rounded()) }

    /// "13 points", "1 point".
    private static func points(_ x: Double) -> String {
        let n = whole(x)
        return n == 1 ? "1 point" : "\(n) points"
    }
}
