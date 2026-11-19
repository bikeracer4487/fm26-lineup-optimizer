import Foundation

/// The words scouting's needs use, written once here: why a player is counted as going, the kinds of need, and a
/// sentence or more for each need.
extension AdvisorText {
    public static func name(_ reason: GoingReason) -> String {
        switch reason {
        case .onLoanHere: "on loan here"
        case .markedToSell: "marked to sell"
        case .markedToLoanOut: "marked to loan out"
        case .advisedToLeave: "advised to leave"
        }
    }

    public static func name(_ kind: BetterPlayerKind) -> String {
        switch kind {
        case .nobody: "Nobody"
        case .weak: "Weak"
        case .ageing: "Ageing"
        }
    }

    public static let betterPlayersHeading = "Better players"
    public static let moreDepthHeading = "More depth"

    /// "Counted as going: A (on loan here), B (advised to leave)."; nil for nobody.
    public static func countedAsGoing(_ going: [Going]) -> String? {
        guard !going.isEmpty else { return nil }
        return "Counted as going: " + going.map { "\($0.name) (\(name($0.reason)))" }.joined(separator: ", ") + "."
    }

    /// The lines for one better-player need, in order: the first choice who is going, the case's own line, and what
    /// would ease it. A weak first choice of `firstChoiceAgeNamedFrom` or over is named with his age.
    public static func betterPlayerLines(_ need: BetterPlayerNeed) -> [String] {
        var lines: [String] = []
        if let leaving = need.goingFirstChoice {
            lines.append("\(leaving.name), first choice today, is \(name(leaving.reason)).")
        }
        switch need.kind {
        case .nobody:
            if let first = need.firstChoice {
                lines.append("Nobody who stays can play here; \(first.name) would fill in out of position.")
            } else {
                lines.append("Nobody who stays can play here.")
            }
        case .weak:
            if let first = need.firstChoice {
                // "Sam Reed", "Sam Reed, 31,", "Sam Reed, the best who stays,", "Sam Reed, 31, the best who stays,".
                var parts = [first.name]
                if need.namesFirstChoiceAge { parts.append("\(first.age)") }
                if need.goingFirstChoice != nil { parts.append("the best who stays") }
                let subject = parts.count == 1 ? first.name : parts.joined(separator: ", ") + ","
                switch (need.measure, need.gap) {
                case (.rating?, let gap?):
                    lines.append("\(subject) rates \(Display.onePercentDecimal(gap)) under the average of your outfield first choices.")
                case (.ability(let his, let average)?, _):
                    lines.append("\(subject) has ability \(his) against an average of \(String(format: "%.0f", average)) "
                                 + "for your outfield first choices. Goalkeepers are rated on their own scale, so ability is compared.")
                case (.rating?, nil), (nil, _):
                    lines.append("\(subject) rates under the average of your outfield first choices.")
                }
            }
        case .ageing:
            if let first = need.firstChoice {
                lines.append("\(first.name) is \(first.age), and nobody is on course to pass him. "
                             + "Decline is not measured, so this is a prompt to look.")
            }
        }
        if need.kind != .ageing, let eased = need.easedBy {
            let who: String
            if eased.player == need.firstChoice?.player {
                who = "He"
            } else if let club = eased.onLoanAt {
                who = "\(eased.name), out on loan at \(club),"
            } else {
                who = eased.name
            }
            lines.append("\(who) is \(eased.age); his reach would bring him level (this tool's estimate).")
        }
        return lines
    }

    /// The lines for one depth need, each when it applies: the count and who counts; the next best against the first
    /// choice; who would count but for an injury, and that the need lasts only while they are out; cover that is going;
    /// and players out on loan who would count.
    public static func depthNeedLines(_ need: DepthNeed, parameters: EngineParameters) -> [String] {
        let slot = need.depth
        let counting = slot.options.filter(\.countsAsCover).map(\.name)
        var lines = [cover(slot, parameters: parameters) + (counting.isEmpty ? "" : ": " + andList(counting)) + "."]
        let nextName = slot.nextBest.flatMap { id in slot.options.first { $0.player == id }?.name }
        switch (nextName, need.firstChoice, need.nextBestShareUnder) {
        case (let next?, let first?, let share?):
            let size = Display.onePercentDecimal(share)
            let how = size == Display.onePercentDecimal(0) ? "level with" : share > 0 ? "\(size) under" : "\(size) above"
            lines.append("The next best, \(next), rates \(how) \(first.name).")
        case (let next?, _, _):
            lines.append("The next best is \(next).")
        case (nil, _, _):
            lines.append("Nobody else can step in.")
        }
        if !need.injured.isEmpty {
            let one = need.injured.count == 1
            lines.append("Not counting \(andList(need.injured.map(\.name))), who \(one ? "is" : "are") injured.")
            if need.lastsOnlyWhileInjured {
                lines.append("The need lasts only while \(one ? "he is" : "they are") out.")
            }
        }
        if !need.going.isEmpty {
            lines.append("Not counting \(andList(need.going.map(\.name))), who \(need.going.count == 1 ? "is" : "are") going.")
        }
        for back in need.returning {
            lines.append("\(back.name), out on loan at \(back.club), would count as cover.")
        }
        return lines
    }

    private static func andList(_ names: [String]) -> String {
        names.count <= 1 ? (names.first ?? "") : names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
    }

    // MARK: The candidates

    public static func name(_ level: CandidateLevel) -> String {
        switch level {
        case .wouldStart: "Would start"
        case .wouldMakeSecond: "Would make the second eleven"
        case .wouldCountAsCover: "Would count as cover"
        case .belowCover: "Below cover"
        }
    }

    public static func name(_ part: CandidatePart) -> String {
        switch part {
        case .answersToday: "Answers a need today"
        case .answersLater: "Could answer a need later"
        case .wouldStartElsewhere: "Would start where you have no need"
        case .couldPassElsewhere: "Could pass a first choice where you have no need"
        case .rest: "The rest"
        }
    }

    public static func name(_ order: CandidateOrder) -> String {
        switch order {
        case .today: "Today"
        case .later: "Later"
        }
    }

    /// "Left back · needs a better player", "Goalkeeper · needs more depth".
    public static func groupHeading(slot: SlotID, answer: NeedAnswer) -> String {
        let need: String
        switch answer {
        case .betterPlayerToday, .betterPlayerLater: need = "needs a better player"
        case .moreDepth: need = "needs more depth"
        }
        return "\(capitalised(PositionText.plain(slot))) · \(need)"
    }

    /// How he would stand at the slot today, then whether he is solid there and whether the slot would stay weak.
    public static func todayLines(_ slot: CandidateSlot) -> [String] {
        let position = PositionText.plain(slot.slot)
        var lines: [String] = []
        switch (slot.firstChoice, slot.marginOverFirst) {
        case (let first?, let margin?):
            let size = Display.onePercentDecimal(margin)
            let how = size == Display.onePercentDecimal(0) ? "level with" : margin > 0 ? "\(size) above" : "\(size) under"
            let who = slot.firstChoiceIsOutOfPosition
                ? "\(first.name), who fills in at \(position) out of position"
                : "\(first.name), your first choice at \(position)"
            lines.append("\(name(slot.level)): rates \(how) \(who).")
        case (nil, _), (_, nil):
            lines.append("\(name(slot.level)): nobody who stays can play at \(position).")
        }
        if !slot.isSolid {
            lines.append("Not yet solid there: familiarity \(slot.ipFamiliarity) in possession, \(slot.oopFamiliarity) out.")
        }
        if let weak = slot.stillWeakBy {
            let lead = "The slot would still be weak with him: "
            switch weak.measure {
            case .rating:
                lines.append(lead + "\(Display.onePercentDecimal(weak.gap)) under the average of your outfield first choices.")
            case .ability(let his, let average):
                lines.append(lead + "ability \(his) against an average of \(String(format: "%.0f", average)) "
                             + "for your outfield first choices.")
            }
        }
        return lines
    }

    /// For his headline slot: his reach and where it leaves him there, or that he is judged as he is. Empty when he
    /// can play no slot. Every sentence about his reach names the slot.
    public static func laterLines(_ candidate: Candidate) -> [String] {
        guard let slot = candidate.headlineSlot else { return [] }
        guard let outlook = candidate.outlook else {
            return ["Judged as he is today." + (candidate.isAgeNamed ? " He is \(candidate.player.age): decline is not measured." : "")]
        }
        let names: (SlotID) -> String = { PositionText.plain($0) }
        if let later = slot.later, let reach = reachAt(later) {
            var lines = [reach + ".", reachWorking(outlook.estimate)]
            if let standing = standing(outlook, names: names) { lines.append(standing) }
            switch slot.level {
            case .wouldCountAsCover, .belowCover:
                lines.append("The estimate assumes regular matches, which he may not get here.")
            case .wouldStart, .wouldMakeSecond: break
            }
            return lines
        }
        var lines = [reachWorking(outlook.estimate)]
        if let weakLine = slot.laterAgainstWeakLine { lines.append(reachAgainst(weakLine, at: slot.slot) + ".") }
        return lines
    }

    /// For a slot that is not his headline: his lines for today there, then, with a reach, one line for later.
    public static func otherSlotLines(_ slot: CandidateSlot) -> [String] {
        var lines = todayLines(slot)
        if let later = slot.later, let reach = reachAt(later) {
            lines.append("Later: " + lowerFirst(reach) + ".")
        } else if let weakLine = slot.laterAgainstWeakLine {
            lines.append("Later: " + lowerFirst(reachAgainst(weakLine, at: slot.slot)) + ".")
        }
        return lines
    }

    /// A candidate's reach at one slot by its level, naming the slot: "Could pass Smith at left back". Player Removal's
    /// `reachLine` speaks of a squad player's best slot and of "any position"; a candidate's other slots may differ, so
    /// his is his own. nil for a slot with no first choice, which has no level.
    static func reachAt(_ later: SlotOutlook) -> String? {
        guard let level = later.level, let first = later.firstChoice else { return nil }
        let position = PositionText.plain(later.slot)
        switch level {
        case .couldPassFirst: return "Could pass \(first.name) at \(position)"
        case .couldMakeSecond: return "Could make the second eleven at \(position)"
        case .couldBeCover: return "Could become cover at \(position), no more"
        case .markedlyLower: return "Not expected to reach the level of cover at \(position)"
        }
    }

    /// "His reach would rate about 112 at left back, which clears the line for a weak slot"; at the goalkeeper's slot,
    /// "His reach of about 100 ability at goalkeeper clears the line for a weak slot".
    static func reachAgainst(_ weakLine: WeakLineReach, at slot: SlotID) -> String {
        let position = PositionText.plain(slot)
        switch weakLine.reach {
        case .rating(let reach):
            return "His reach would rate about \(Int(reach.rounded())) at \(position), which "
                + (weakLine.clears ? "clears the line for a weak slot" : "is still under the line for a weak slot")
        case .ability(let reach):
            return "His reach of about \(Int(reach.rounded())) ability at \(position) "
                + (weakLine.clears ? "clears the line for a weak slot" : "is still under the line for a weak slot")
        }
    }

    private static func lowerFirst(_ words: String) -> String { words.prefix(1).lowercased() + words.dropFirst() }

    /// "Injury Proneness 16".
    public static func caution(_ caution: CandidateCaution) -> String { "\(caution.attribute.rawValue) \(caution.value)" }

    /// "Free agent" for a player out of contract, else his club; nil when the paste carried none.
    public static func club(of player: Player) -> String? {
        switch player.contractType {
        case .outOfContract: "Free agent"
        case .fullTime, .youth, .other: player.club
        }
    }

    public static func onLoan(at club: String) -> String { "On loan at \(club)" }

    public static func askingPrice(_ amount: Int, _ style: MoneyStyle) -> String {
        "Asking " + Display.money(amount, symbol: style.symbol)
    }

    public static func playersRead(_ count: Int) -> String { "\(count) \(count == 1 ? "player" : "players") read." }

    /// "Left out, already yours: A and B."; nil for none.
    public static func leftOutAlreadyYours(_ names: [String]) -> String? {
        guard !names.isEmpty else { return nil }
        let list = names.count == 1 ? names[0] : names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
        return "Left out, already yours: \(list)."
    }

    public static let everyPastedPlayerIsYours = "Every pasted player is already yours, so there is nobody to judge."
    public static let playsNoSlot = "He can play no slot of this tactic."

    private static func capitalised(_ words: String) -> String { words.prefix(1).uppercased() + words.dropFirst() }
}
