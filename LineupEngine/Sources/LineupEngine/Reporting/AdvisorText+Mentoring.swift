import Foundation

/// The words mentoring advice uses, written once here: level, group and strength names, the standing notes, and the
/// sentences built from the groups' arrows and numbers. No number that reads like a forecast is ever shown, only the
/// two values.
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

    /// The game's word for each strength of arrow.
    public static func name(_ strength: ArrowStrength) -> String {
        switch strength {
        case .none: "None"
        case .light: "Light"
        case .average: "Average"
        case .significant: "Significant"
        }
    }

    /// The one standing note on mentoring advice.
    public static let mentoringNote = "How fast mentoring works in FM27 has not been measured. "
        + "An arrow is the game's own where it has been read, and this tool's guess where it says expected."

    /// When no player of the squad has a level above Others.
    public static let mentoringNeedsHierarchy = "Enter this squad's hierarchy first: mentoring needs each player's "
        + "level, and age alone creates no influence."

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

    /// "McEachran → Clark".
    public static func arrowTitle(_ arrow: GroupArrow) -> String {
        "\(arrow.fromName) → \(arrow.toName)"
    }

    /// Beside an arrow that is this tool's guess.
    public static let expectedNotRead = "expected, not read"

    /// Beside an arrow with no pull.
    public static let nothingToGain = "nothing to gain"

    /// Under a suggestion that rests on a guess.
    public static let setAndRecordArrows = "Set this group in the game and record its arrows."

    /// "Professionalism 8, towards 17".
    public static func pull(_ pull: Pull) -> String {
        "\(pull.attribute.rawValue) \(pull.value), towards \(pull.towards)"
    }

    /// `names` gives each player's name; a player it lacks is "A player", never his key.
    public static func caution(_ caution: MemberCaution, names: [PlayerID: String]) -> String {
        switch caution {
        case .onLoanHere(let id): "\(names[id] ?? "A player") is on loan here: the group ends when he goes back."
        case .advisedToLeave(let id): "\(names[id] ?? "A player") is advised to leave: the group ends when he goes."
        }
    }

    public static func notPlaced(_ player: NotPlaced) -> String {
        let who = "\(player.name) (\(player.age))"
        return switch player.reason {
        case .takesNothing: "\(who): he has taken nothing from the players tried with him so far."
        case .noInfluence: "\(who): nobody in this squad is expected to influence him."
        case .nothingToGain: "\(who): nobody who influences him is better where it counts."
        case .tooFewFree: "\(who): there are not three players free to make a group with him."
        case .wouldHarm: "\(who): every group that would help him would pull a player down."
        case .influencersTaken: "\(who): the players who could influence him are already in a group."
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

    /// What changed in one attribute since the member joined; nil when there is no reading to compare. A change read
    /// within a few days, whose weeks round to 0, reads "in under a week".
    public static func change(_ change: AttributeChange) -> String? {
        let name = change.attribute.rawValue
        let weeks = Int(change.weeks.rounded())
        let span = switch weeks {
        case 0: "under a week"
        case 1: "1 week"
        default: "\(weeks) weeks"
        }
        switch change.change {
        case .noReading: return nil
        case .improved, .worse:
            guard let start = change.start, let latest = change.latest else { return nil }
            return "\(name) \(start) to \(latest) in \(span)"
        case .noChange:
            guard let start = change.start, let latest = change.latest else { return nil }
            return start == latest ? "\(name) \(latest), no change" : "\(name) \(start) to \(latest), above where it counts"
        }
    }

    public static let noReadingYet = "No reading yet: values are read at each import"

    /// What a recorded group is doing, when that is bad: doing harm, or stopped; nil otherwise. A stopped group with
    /// nobody clearly leading says nobody has changed, since there is no lead to set apart.
    public static func state(of review: GroupReview, parameters: EngineParameters) -> String? {
        if review.isDoingHarm {
            return "This group is doing harm: a member is worth less than when he joined. Consider regrouping."
        }
        if review.hasStoppedWorking {
            let weeks = parameters.mentoringStoppedAfterWeeks.value
            let who = review.lead == nil ? "nobody" : "nobody but the lead"
            return "This group has stopped working: \(who) has changed in \(weeks) weeks. Consider regrouping."
        }
        return nil
    }

    /// "Hart, Young and Reid are recorded as a group from today. Set it in the game as well."
    public static func recorded(names: [String]) -> String {
        let list = names.count <= 1 ? (names.first ?? "") : names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
        return "\(list) are recorded as a group from today. Set it in the game as well."
    }
}
