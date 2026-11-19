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
    /// would ease it.
    public static func betterPlayerLines(_ need: BetterPlayerNeed) -> [String] {
        var lines: [String] = []
        if let leaving = need.goingFirstChoice {
            lines.append("\(leaving.name), first choice today, is \(name(leaving.reason)).")
        }
        let subject = need.goingFirstChoice == nil ? need.firstChoice?.name : need.firstChoice.map { "\($0.name), the best who stays," }
        switch need.kind {
        case .nobody:
            if let first = need.firstChoice {
                lines.append("Nobody who stays can play here; \(first.name) would fill in out of position.")
            } else {
                lines.append("Nobody who stays can play here.")
            }
        case .weak:
            if let subject {
                switch need.measure {
                case .rating? where need.gap != nil:
                    lines.append("\(subject) rates \(Display.onePercentDecimal(need.gap ?? 0)) under the average of your outfield first choices.")
                case .ability(let his, let average)?:
                    lines.append("\(subject) has ability \(his) against an average of \(String(format: "%.0f", average)) "
                                 + "for your outfield first choices. Goalkeepers are rated on their own scale, so ability is compared.")
                case .rating?, nil:
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
            let who = eased.player == need.firstChoice?.player ? "He" : eased.name
            lines.append("\(who) is \(eased.age); his reach would bring him level (this tool's estimate).")
        }
        return lines
    }

    /// The lines for one depth need: the count and who counts, the next best, cover that is going, and players out on
    /// loan who would count.
    public static func depthNeedLines(_ need: DepthNeed, parameters: EngineParameters) -> [String] {
        let slot = need.depth
        let counting = slot.options.filter(\.countsAsCover).map(\.name)
        var lines = [cover(slot, parameters: parameters) + (counting.isEmpty ? "" : ": " + andList(counting)) + "."]
        let nextName = slot.nextBest.flatMap { id in slot.options.first { $0.player == id }?.name }
        lines.append(nextBest(slot, name: nextName) + ".")
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
            lines.append("\(name(slot.level)): rates \(how) \(first.name), your first choice at \(position).")
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

    /// For his headline slot: his reach and where it leaves him, or that he is judged as he is. Empty when he can play
    /// no slot.
    public static func laterLines(_ candidate: Candidate) -> [String] {
        guard let slot = candidate.headlineSlot else { return [] }
        guard let outlook = candidate.outlook else {
            return ["Judged as he is today." + (candidate.isAgeNamed ? " He is \(candidate.player.age): decline is not measured." : "")]
        }
        let names: (SlotID) -> String = { PositionText.plain($0) }
        if slot.later?.level != nil, let reach = reachLine(outlook, names: names) {
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
        if let clears = candidate.reachClearsWeakLine {
            let position = PositionText.plain(slot.slot)
            lines.append(clears
                ? "His reach would clear the line for a weak slot at \(position)."
                : "His reach would still be under the line for a weak slot at \(position).")
        }
        return lines
    }

    /// "Right back: would make the second eleven." for a slot that is not his headline.
    public static func otherSlotLine(_ slot: CandidateSlot) -> String {
        "\(capitalised(PositionText.plain(slot.slot))): \(name(slot.level).lowercased())."
    }

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
