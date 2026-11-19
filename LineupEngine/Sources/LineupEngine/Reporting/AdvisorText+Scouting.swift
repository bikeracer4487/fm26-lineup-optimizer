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
}
