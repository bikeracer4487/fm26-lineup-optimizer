import Foundation

/// The words a young player's outlook uses, written once here: the band names and Player Removal's reach line.
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
    /// Player Removal adds it only for an outlook with a level.
    public static func reachLine(_ outlook: Outlook, names: (SlotID) -> String) -> String {
        guard let level = outlook.level else {
            preconditionFailure("A reach line needs an outlook with a level")
        }
        guard let best = outlook.best else {
            // Compared with the first team's average: there is no first choice to pass.
            switch level {
            case .couldPassFirst, .couldMakeSecond: return "Could reach the level of the first team"
            case .couldBeCover: return "Could come close to the level of the first team, no more"
            case .markedlyLower: return "Not expected to reach the level of the first team"
            }
        }
        let position = names(best.slot)
        switch level {
        case .couldPassFirst:
            // `best` always has a first choice who is not him.
            return "Could pass \(best.firstChoice?.name ?? "the first choice") at \(position)"
        case .couldMakeSecond: return "Could make the second eleven at \(position)"
        case .couldBeCover: return "Could become cover at \(position), no more"
        case .markedlyLower: return "Not expected to reach the level of the squad at any position"
        }
    }
}
