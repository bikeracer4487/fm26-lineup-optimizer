import Foundation

/// Which figure a wage verdict is about.
public enum WageFigure: Sendable { case agents, presentWage }

/// The words of the Contracts screen and of the wage range. Every figure in a sentence comes from the entry, the guide
/// or the rules; nothing is worked out here but joins, plurals and percentages. Nothing reads as a forecast of what a
/// player will ask. Every `switch` over the feature's enums is exhaustive.
extension AdvisorText {
    // MARK: Fixed lines

    public static let contractsIntro = "Players worth renewing whose contracts are running down, most important first, with what your own squad is paid as a guide to a reasonable wage."
    public static let nobodyInLastYear = "Nobody worth renewing is in the last year of his contract."
    /// On the row of a player the owner chose to renew anyway, above his reasons.
    public static let listedAtYourChoice = "The tool does not recommend renewing him; he is listed at your choice."
    public static let candidateAskNotKnown = "What he would ask of you is not known; check the agent's figure before you bid."
    public static let candidateWageOtherCurrency = "His wage is in another currency than your squads', so it cannot be compared with them."
    public static let wageEvidenceSentence = "A wage range is what your own players are paid now, not what a player will ask: no test in any version says what a player asks (this tool's estimate)."

    // MARK: The reasons

    /// One reason the tool does not recommend renewing him: "You have marked him to sell.", "Player Removal advises
    /// selling him.", his worth line (`worthLine`), "He is first choice at right defensive midfield: sign a replacement
    /// before he goes." and the rest.
    public static func contractReasonLine(_ reason: ContractReason) -> String {
        switch reason {
        case .markedToSell: return "You have marked him to sell."
        case .advisedToLeave(let action):
            switch action {
            case .sell: return "Player Removal advises selling him."
            case .release: return "Player Removal advises releasing him."
            case .terminate: return "Player Removal advises ending his contract by agreement."
            // Not actions that move a player on; said plainly should one ever be handed in.
            case .monitor, .develop, .play, .loanForMatches, .keep: return "Player Removal advises moving him on."
            }
        case .underStandard(let worth): return worthLine(worth)
        case .noSlot: return "He can play no slot of this tactic."
        case .noStandard: return "Your first eleven has no outfield player in position, so nobody can be measured against it."
        case .replaceFirst(let slot, let why):
            let place = PositionText.plain(slot)
            let then = "sign a replacement before he goes."
            switch why {
            case .firstChoice: return "He is first choice at \(place): \(then)"
            case .secondChoice: return "He is second choice at \(place): \(then)"
            case .cover: return "He counts as cover at \(place): \(then)"
            case .standIn: return "Too few players can step in at \(place) without him: \(then)"
            }
        }
    }

    // MARK: Standing and timing

    /// "he would start at left back".
    private static func wouldBe(_ level: CandidateLevel, at slot: SlotID) -> String {
        let place = PositionText.plain(slot)
        switch level {
        case .wouldStart: return "he would start at \(place)"
        case .wouldMakeSecond: return "he would make the second eleven at \(place)"
        case .wouldCountAsCover: return "he would count as cover at \(place)"
        case .belowCover: return "he would be below cover at \(place)"
        }
    }

    public static func standingLine(_ entry: ContractEntry) -> String {
        switch entry.standing {
        case .first(let slot): return "First choice at \(PositionText.plain(slot))."
        case .second(let slot): return "Second choice at \(PositionText.plain(slot))."
        case .neither:
            guard let action = entry.action else { return "In neither eleven." }
            return "In neither eleven; Player Removal says \(name(action).lowercased())."
        case .outOnLoan(let club, let level, let slot):
            guard let level, let slot else { return "Out on loan at \(club); he can play no slot of this tactic." }
            return "Out on loan at \(club); \(wouldBe(level, at: slot))."
        }
    }

    public static func timingLine(_ entry: ContractEntry) -> String? {
        switch entry.part {
        case .approachable: return "Other clubs can approach him now."
        case .lastYear: return entry.approachableFrom.map { "Other clubs can approach him from \(shortDay($0))." }
        case .noContract: return "He has no contract and can leave at any time."
        }
    }

    // MARK: The wage range

    private static func tierWords(_ tier: WageTier) -> String {
        switch tier {
        case .firstEleven: "first eleven"
        case .secondEleven: "second eleven"
        case .neither: "players in neither eleven"
        }
    }

    /// "your second eleven", or "the rest of your second eleven" when the player is one of them and left out.
    private static func tierPhrase(_ guide: WageGuide) -> String {
        (guide.leavesHimOut ? "the rest of your " : "your ") + tierWords(guide.tier)
    }

    private static func capitalised(_ text: String) -> String { text.prefix(1).uppercased() + text.dropFirst() }

    private static func shareName(_ guide: WageGuide) -> String {
        guide.tier == .firstEleven ? "a key player's share" : "a backup's share"
    }

    /// What the tier is paid, written once when the two ends are written alike.
    private static func paidText(_ paid: PaidRange, _ money: MoneyStyle) -> String {
        sameText(paid.lowerQuartile, paid.highest, money) ? Display.wage(perWeek: paid.highest, money)
            : "\(Display.wageAmount(perWeek: paid.lowerQuartile, money)) to \(Display.wage(perWeek: paid.highest, money))"
    }

    /// True when two weekly amounts are written as the same amount in this style.
    private static func sameText(_ a: Double, _ b: Double, _ money: MoneyStyle) -> Bool {
        Display.wageAmount(perWeek: a, money) == Display.wageAmount(perWeek: b, money)
    }

    private static func rangeText(low: Double, high: Double, _ money: MoneyStyle) -> String {
        "\(Display.wageAmount(perWeek: low, money)) to \(Display.wage(perWeek: high, money))"
    }

    public static func wageGuideLines(_ guide: WageGuide, money: MoneyStyle) -> [String] {
        let who = tierPhrase(guide)
        let estimate = "(this tool's estimate)"
        var lines: [String] = []

        switch guide.shown {
        case .range(let low, let high, let setBy):
            switch setBy {
            case .tierHighest:
                if sameText(low, high, money) {
                    lines.append("\(capitalised(who)) are all paid \(Display.wage(perWeek: high, money)) (this tool's estimate of a reasonable wage).")
                } else {
                    lines.append("Most of \(who) are paid \(rangeText(low: low, high: high, money)) (this tool's estimate of a reasonable range).")
                }
            case .ceiling where sameText(low, high, money):
                lines.append("A reasonable wage is about \(Display.wage(perWeek: high, money)): what \(who) are paid at the low end is also \(shareName(guide)) of your wage budget \(estimate).")
            case .highestWage where sameText(low, high, money):
                lines.append("A reasonable wage is about \(Display.wage(perWeek: high, money)): what \(who) are paid at the low end is also the most you can offer one player \(estimate).")
            case .ceiling:
                lines.append("A reasonable range is \(rangeText(low: low, high: high, money)): from what most of \(who) are paid up to \(shareName(guide)) of your wage budget \(estimate).")
            case .highestWage:
                lines.append("A reasonable range is \(rangeText(low: low, high: high, money)): from what most of \(who) are paid up to the most you can offer one player \(estimate).")
            }
        case .upTo(let top, let setBy):
            let figure = Display.wage(perWeek: top, money)
            if let paid = guide.paid {
                // "what your second eleven are all paid, $3,269" or "what most of your second eleven are paid, $2,786
                // to $3,905": the lower quartile is not the least any of them is paid.
                let whatPaid = sameText(paid.lowerQuartile, paid.highest, money)
                    ? "\(who) are all paid, \(paidText(paid, money))" : "most of \(who) are paid, \(paidText(paid, money))"
                switch setBy {
                case .ceiling, .tierHighest:
                    lines.append("Up to \(figure): \(shareName(guide)) of your wage budget is below what \(whatPaid) \(estimate).")
                case .highestWage:
                    lines.append("Up to \(figure): the most you can offer one player is below what \(whatPaid).")
                }
            } else {
                // The highest wage and too few wages are both facts; a share of the budget is the rule of thumb's.
                switch setBy {
                case .ceiling, .tierHighest:
                    lines.append("Up to \(figure), \(shareName(guide)) of your wage budget; too few of \(who) are paid a wage to read a range from them \(estimate).")
                case .highestWage:
                    lines.append("Up to \(figure), the most you can offer one player; too few of \(who) are paid a wage to read a range from them.")
                }
            }
        case .none:
            lines.append("No range can be given: too few of \(who) are paid a wage to read one from. Enter your wage budget for a ceiling.")
        }

        if let ceiling = guide.ceilingPerWeek {
            if guide.tier == .firstEleven, let starter = guide.starterSharePerWeek {
                lines.append("By one rule of thumb a key player's share of your wage budget is \(Display.wage(perWeek: ceiling, money)), kept for four players, and a starter's is \(Display.wage(perWeek: starter, money)) \(estimate).")
            } else if guide.tier == .firstEleven {
                lines.append("By one rule of thumb a key player's share of your wage budget is \(Display.wage(perWeek: ceiling, money)), kept for four players \(estimate).")
            } else {
                lines.append("By one rule of thumb a backup's share of your wage budget is \(Display.wage(perWeek: ceiling, money)) \(estimate).")
            }
        }

        let highest = guide.highestWagePerWeek.map { "The most you can offer one player is \(Display.wage(perWeek: $0, money))" }
        let left = guide.budgetLeftPerWeek.map { "\(Display.wage(perWeek: $0, money)) of your wage budget is left" }
        let back = guide.countsHisWageBack ? ", counting his present wage back" : ""
        switch (highest, left) {
        case (let highest?, let left?): lines.append("\(highest), and \(left)\(back).")
        case (let highest?, nil): lines.append("\(highest).")
        case (nil, let left?): lines.append("\(left)\(back).")
        case (nil, nil): break
        }
        return lines
    }

    public static func wageVerdictLine(_ verdict: WageVerdict, figure: WageFigure, guide: WageGuide,
                                       money: MoneyStyle) -> String {
        let subject: String
        switch figure {
        case .agents: subject = "The agent's figure"
        case .presentWage: subject = "His wage now"
        }
        let who = tierPhrase(guide)
        switch verdict {
        case .overHighestWage(let limit):
            return "\(subject) is above the most you can offer one player, \(Display.wage(perWeek: limit, money))."
        case .overCeiling(let ceiling):
            return "\(subject) is above \(shareName(guide)) of your wage budget, \(Display.wage(perWeek: ceiling, money)) (this tool's estimate)."
        case .aboveTier(let highest):
            return "\(subject) is above anything \(who) are paid; the highest is \(Display.wage(perWeek: highest, money))."
        case .withinTier:
            return "\(subject) is within what \(who) are paid."
        case .underTier:
            return "\(subject) is under what most of \(who) are paid."
        case .overBudgetLeft(let by):
            return "\(subject) is \(Display.wage(perWeek: by, money)) more than your wage budget has left; money or wages would have to move."
        case .timesPresentWage(let times):
            return "\(subject) is \(String(format: "%.1f", times)) times his wage now."
        }
    }

    // MARK: A pasted player

    public static func candidateWageLead(level: CandidateLevel, slot: SlotID) -> String {
        let beside = WageRange.tier(of: level)
        return "For wages he is set beside your \(tierWords(beside)): \(wouldBe(level, at: slot))."
    }

    public static func candidatePresentWage(perWeek: Double, money: MoneyStyle) -> String {
        perWeek > 0 ? "He is paid \(Display.wage(perWeek: perWeek, money)) now." : "He is paid no wage now."
    }

    // MARK: Counts and evidence

    /// The closed line over the players not recommended: "1 player not recommended for renewal".
    public static func notRecommendedLine(_ count: Int) -> String {
        count == 1 ? "1 player not recommended for renewal" : "\(count) players not recommended for renewal"
    }

    public static func notRenewingLine(_ count: Int) -> String {
        count == 1 ? "1 player you are not renewing" : "\(count) players you are not renewing"
    }

    public static func contractsEvidenceNote(_ rules: WageRangeRules) -> [String] {
        func percent(_ share: Double) -> String { String(format: "%.1f%%", share * 100) }
        return [
            wageEvidenceSentence,
            "The shares of the wage budget are one author's rule of thumb for FM23: \(percent(rules.keyPlayerShare)) for each of four key players, \(percent(rules.starterShare)) for a starter and \(percent(rules.backupShare)) for a backup.",
            "The wage budget, the wages spent and the most you can offer one player are the figures you typed from FMRTE.",
            "Other clubs can approach a player in his last \(rules.approachMonths) months; that is the game's rule (carried over from FM26).",
        ]
    }
}
