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
        case .noThirdFree:
            "\(who): no third player is left free who could join him and a player who could influence him "
                + "without pulling a player down."
        case .influencersTaken: "\(who): the players who could influence him are already in a group."
        }
    }

    /// `names` gives each player's name; a player it lacks is shown by his key. A harmful arrow that is a guess says
    /// "expected to be" before its strength; each value has its player's name before it, so neither can be taken for
    /// the other's.
    public static func warning(_ warning: GroupWarning, names: [PlayerID: String]) -> String {
        func who(_ id: PlayerID) -> String { names[id] ?? id.key }
        return switch warning {
        case .harmfulArrow(let from, let to, let strength, let isRead, let attribute, let fromValue, let toValue):
            "\(who(from))'s influence on \(who(to)) is \(isRead ? "" : "expected to be ")\(name(strength)), and "
                + "\(who(from))'s \(attribute.rawValue) is \(fromValue) against \(who(to))'s \(toValue)."
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

    /// What a recorded group is doing, when that is bad: doing harm, then no influence, then giving nothing to a
    /// player of the club's own who is staying, then stopped; nil otherwise. A group that gives nothing is to be broken
    /// up; while any of its arrows is a guess that is what this tool expects, and recording them comes first. Nothing
    /// is said of what it gives while that is not known.
    public static func state(of review: GroupReview, parameters: EngineParameters) -> String? {
        if review.isDoingHarm {
            return "This group is doing harm: a member is worth less than when he joined. Consider regrouping."
        }
        if review.hasNoInfluence {
            return "The game shows no influence in this group: all six arrows are None. Consider regrouping."
        }
        let isRead = review.unreadArrows == 0
        switch review.gain {
        case .toAMember, .notKnown: break
        case .onlyToAMemberWhoWillGo:
            return isRead
                ? "Only a player on loan here or advised to leave gains from this group. Break it up."
                : "Only a player on loan here or advised to leave is expected to gain from this group. "
                    + "Record its arrows to check, or break it up."
        case .toNobody:
            return isRead
                ? "Nobody in this group has anything to gain from it. Break it up."
                : "Nobody in this group is expected to gain anything from it. Record its arrows to check, or break it up."
        }
        if review.hasStoppedWorking {
            let weeks = parameters.mentoringStoppedAfterWeeks.value
            return "This group has stopped working: nobody it influences has changed in \(weeks) weeks. "
                + "Consider regrouping."
        }
        return nil
    }

    /// The prompt to read a recorded group's arrows in the game; nil when none of them is a guess. The count is of
    /// every pair still guessed, while the card lists only arrows above None, so the prompt says why the two differ.
    public static func arrowsToRead(_ review: GroupReview) -> String? {
        let count = review.unreadArrows
        guard count > 0 else { return nil }
        return "Record this group's arrows from the game: "
            + (count == 1 ? "1 is still a guess." : "\(count) are still guesses.")
            + " An arrow expected to be None is not listed."
    }

    /// Beside the social groups in the hierarchy.
    public static let socialGroupsNotUsed = "Social groups are kept as entered. They do not change the advice."

    /// "Hart, Young and Reid are recorded as a group from today. Set it in the game as well."
    public static func recorded(names: [String]) -> String {
        "\(list(names)) are recorded as a group from today. Set it in the game as well."
    }

    /// "Hart", "Hart and Young", "Hart, Young and Reid".
    private static func list(_ names: [String]) -> String {
        names.count <= 1 ? (names.first ?? "") : names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
    }

    /// The sentences over the groups a regrouping would make: what to break up, who would be left in no group, and
    /// that it rests on a guess when it does. `breakingUp` gives the members' names of each group to break up, in the
    /// regrouping's order. No number is shown: the count behind it only orders groups.
    public static func regrouping(_ regrouping: Regrouping, breakingUp groups: [[String]]) -> [String] {
        let owners = groups.enumerated().map { index, names in index == 0 ? "\(list(names))'s group" : "\(list(names))'s" }
        var sentences = ["Breaking up \(owners.joined(separator: " and ")) and making "
            + "\(regrouping.groups.count == 1 ? "this one" : "these") may do more for your players."]
        if !regrouping.leftOut.isEmpty {
            sentences.append("\(list(regrouping.leftOut.map(\.name))) would be left in no group.")
        }
        if !regrouping.isRead {
            sentences.append("It rests on arrows this tool expects and has not read: the game may show them differently.")
        }
        return sentences
    }

    /// On the card of a recorded group a regrouping would break up. `others` are the members' names of the group
    /// broken up with it; empty when it is the only one.
    public static func regroup(alongside others: [String]) -> String {
        let start = "These players may do more in other groups: this tool would break this group up"
        return others.isEmpty ? "\(start)." : "\(start), and \(list(others))'s with it."
    }
}
