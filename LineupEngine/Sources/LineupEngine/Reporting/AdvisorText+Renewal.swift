import Foundation

/// The words of a player's worth against the first eleven's standard (`RenewalWorth`). Every figure comes from the
/// worth; nothing is worked out here but the rounding, the percentages and the words for the seasons.
extension AdvisorText {
    /// One sentence on his worth: today's share when nothing is expected to change, else the ability he is measured at
    /// over a new contract and the share it gives, with today's after a fall. A young player held at today's share,
    /// since his reach would rate lower by ability than he rates today, is told so.
    public static func worthLine(_ worth: RenewalWorth) -> String {
        let measure = worth.isGoalkeeperSlot ? "the average of your first eleven by ability" : "the average of your first eleven"
        let place = PositionText.plain(worth.slot)
        func against(_ share: Double) -> String { againstStandard(share, line: worth.line) }
        switch worth.ahead {
        case .today:
            return "Rates \(against(worth.shareToday)) \(measure), at \(place)."
        case .reach(let reach):
            let reaches = "Ability \(worth.ability), could reach about \(Int(reach.rounded())) (this tool's estimate)"
            // `Renewal.worths` gives a reach never below today's share: equal means the floor held him.
            if worth.share == worth.shareToday {
                return "\(reaches), which by ability would rate lower than he rates today: \(against(worth.share)) \(measure), at \(place)."
            }
            return "\(reaches): that would rate \(against(worth.share)) \(measure), at \(place)."
        case .decline(let to, let seasons):
            let after = Int(to.rounded())
            let over = seasons == 1 ? "the next season" : "the next \(numberWord(seasons)) seasons"
            return "He is \(worth.age). This tool expects him to lose about \(worth.ability - after) points of ability over \(over), from \(worth.ability) to about \(after) (its own estimate: no test measures decline): that would rate \(against(worth.share)) \(measure), at \(place). Rates \(against(worth.shareToday)) it today."
        }
    }

    /// "2.9% above", "10.6% under" or "level with" (a gap that rounds to 0.0%) a share of the standard. A gap under it
    /// that reads as the line's own, 1 − `line` ("5.0%"), is written to two decimals ("4.96% under", "5.04% under"), so
    /// the two sides of the line differ.
    private static func againstStandard(_ share: Double, line: Double) -> String {
        let size = Display.onePercentDecimal(share - 1)
        if size == Display.onePercentDecimal(0) { return "level with" }
        if share >= 1 { return "\(size) above" }
        guard size == Display.onePercentDecimal(1 - line) else { return "\(size) under" }
        return "\(String(format: "%.2f%%", (1 - share) * 100)) under"
    }
}
