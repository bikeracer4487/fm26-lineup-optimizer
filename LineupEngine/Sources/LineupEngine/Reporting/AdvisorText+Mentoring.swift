import Foundation

/// The words mentoring advice uses, written once here: level and group names, the standing notes, and the sentences
/// built from the groups' numbers. No number that reads like a forecast is ever shown, only the two values.
extension AdvisorText {
    public static func name(_ standing: Standing) -> String {
        switch standing {
        case .teamLeader: "Team Leader"
        case .highlyInfluential: "Highly Influential"
        case .influential: "Influential"
        case .others: "Others"
        }
    }

    public static func name(_ group: SocialGroup) -> String {
        switch group {
        case .core: "Core"
        case .secondary(let name): "Secondary \(name)"
        case .others: "Others"
        }
    }

    /// The one standing note on mentoring advice.
    public static let mentoringNote = "How fast mentoring works in FM27 has not been measured. "
        + "These groups follow the rules of earlier versions."

    public static let mentoringByAgeAlone = "No hierarchy entered for this squad: these groups go by age alone."

    /// "No group to suggest." when the report has none.
    public static let noGroupToSuggest = "No group to suggest."

    /// Nil when the hierarchy is not stale. The first team has the game's Dynamics screen; the U21 and U18 squads may
    /// list nobody there, so each player's own page is where to check.
    public static func staleHierarchy(_ report: MentoringReport, updatedOn: Day, asOf: Day) -> String? {
        guard report.isStale else { return nil }
        let weeks = max(0, updatedOn.days(to: asOf)) / 7
        let place = switch report.squad {
        case .firstTeam: "the game's Dynamics screen"
        case .u21, .u18: "each player's own page in the game"
        }
        return "The hierarchy was last updated \(weeks) \(weeks == 1 ? "week" : "weeks") ago. Check it against \(place)."
    }

    /// "Led by Hart (34, Team Leader)".
    public static func lead(_ group: SuggestedGroup) -> String {
        "Led by \(group.leadName) (\(group.leadAge), \(name(group.leadStanding)))"
    }

    /// "Professionalism 8, towards 17".
    public static func pull(_ pull: Pull) -> String {
        "\(pull.attribute.rawValue) \(pull.value), towards \(pull.towards)"
    }

    public static let makingUpTheGroup = "Making up the group"

    public static func caution(_ caution: LeadCaution, leadName: String) -> String {
        switch caution {
        case .onLoanHere: "\(leadName) is on loan here: the group ends when he goes back."
        case .advisedToLeave: "\(leadName) is advised to leave: the group ends when he goes."
        }
    }

    public static func otherSocialGroup(leadName: String) -> String {
        "In a different social group from \(leadName): likely a weaker influence"
    }

    public static func notPlaced(_ player: NotPlaced) -> String {
        let who = "\(player.name) (\(player.age))"
        return switch player.reason {
        case .nobodyAbove: "\(who): nobody in this squad stands above him."
        case .nobodyBetter: "\(who): nobody who stands above him in this squad is better where it counts."
        case .wouldHarm(let attribute):
            "\(who): those who are better where it counts would do him harm in \(attribute.rawValue)."
        case .leadsTaken: "\(who): the leads who suit him are leading others with more to gain."
        case .noThird: "\(who): no third player could be found to make up a group with him and his lead."
        }
    }

    /// `names` gives each player's name; a player it lacks is shown by his key.
    public static func warning(_ warning: GroupWarning, names: [PlayerID: String]) -> String {
        func who(_ id: PlayerID) -> String { names[id] ?? id.key }
        return switch warning {
        case .nobodyLeads: "Nobody is clearly leading this group."
        case .mayBeDraggedDown(let above, let below, let attribute, let aboveValue, let belowValue):
            "\(who(above)) stands above \(who(below)) and has \(attribute.rawValue) \(aboveValue) against "
                + "\(belowValue): \(who(below)) may be dragged down."
        case .differentSocialGroup(let id):
            "\(who(id)) is in a different social group from the lead: likely a weaker influence."
        case .notInSquad(let id): "\(who(id)) is no longer in the squad."
        case .outOnLoan(let id, let club): "\(who(id)) is out on loan at \(club)."
        case .advisedToLeave(let id): "\(who(id)) is advised to leave."
        }
    }

    /// What changed in one attribute since the member joined; nil when there is no reading to compare.
    public static func change(_ change: AttributeChange) -> String? {
        let name = change.attribute.rawValue
        let weeks = Int(change.weeks.rounded())
        switch change.change {
        case .noReading: return nil
        case .improved, .worse:
            guard let start = change.start, let latest = change.latest else { return nil }
            return "\(name) \(start) to \(latest) in \(weeks) \(weeks == 1 ? "week" : "weeks")"
        case .noChange:
            guard let start = change.start, let latest = change.latest else { return nil }
            return start == latest ? "\(name) \(latest), no change" : "\(name) \(start) to \(latest), above where it counts"
        }
    }

    public static let noReadingYet = "No reading yet: values are read at each import"

    /// What a recorded group is doing, when that is bad: doing harm, or stopped; nil otherwise.
    public static func state(of review: GroupReview, parameters: EngineParameters) -> String? {
        if review.isDoingHarm {
            return "This group is doing harm: a member is worth less than when he joined. Consider regrouping."
        }
        if review.hasStoppedWorking {
            let weeks = parameters.mentoringStoppedAfterWeeks.value
            return "This group has stopped working: nobody but the lead has changed in \(weeks) weeks. Consider regrouping."
        }
        return nil
    }

    /// "Hart, Young and Reid are recorded as a group from today. Set it in the game as well."
    public static func recorded(names: [String]) -> String {
        let list = names.count <= 1 ? (names.first ?? "") : names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
        return "\(list) are recorded as a group from today. Set it in the game as well."
    }
}
