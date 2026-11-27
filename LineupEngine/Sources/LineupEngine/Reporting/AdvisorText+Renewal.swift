import Foundation

/// The words of a player's worth against the first eleven's standard (`RenewalWorth`). Every figure comes from the
/// worth; nothing is worked out here but the rounding, the percentages and the words for the seasons.
extension AdvisorText {
    /// One sentence on his worth: today's share when nothing is expected to change, else the ability he is measured at
    /// over a new contract and the share it gives, with today's after a fall.
    public static func worthLine(_ worth: RenewalWorth) -> String {
        let measure = worth.isGoalkeeperSlot ? "the average of your first eleven by ability" : "the average of your first eleven"
        let place = PositionText.plain(worth.slot)
        switch worth.ahead {
        case .today:
            return "Rates \(againstStandard(worth.shareToday)) \(measure), at \(place)."
        case .reach(let reach):
            return "Ability \(worth.ability), could reach about \(Int(reach.rounded())) (this tool's estimate): that would rate \(againstStandard(worth.share)) \(measure), at \(place)."
        case .decline(let to, let seasons):
            let after = Int(to.rounded())
            let over = seasons == 1 ? "the next season" : "the next \(numberWord(seasons)) seasons"
            return "He is \(worth.age). This tool expects him to lose about \(worth.ability - after) points of ability over \(over), from \(worth.ability) to about \(after) (its own estimate: no test measures decline): that would rate \(againstStandard(worth.share)) \(measure), at \(place). Rates \(againstStandard(worth.shareToday)) it today."
        }
    }

    /// "2.9% above" or "10.6% under" a share of the standard; exactly the standard is "0.0% above".
    private static func againstStandard(_ share: Double) -> String {
        share >= 1 ? "\(Display.onePercentDecimal(share - 1)) above" : "\(Display.onePercentDecimal(1 - share)) under"
    }
}
