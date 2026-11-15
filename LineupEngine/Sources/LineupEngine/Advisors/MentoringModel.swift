import Foundation

/// How much say a player has in the dressing room, as the owner reads it from the game's Dynamics screen.
/// Lowest first, so `<` reads "stands lower".
public enum Standing: String, Codable, CaseIterable, Comparable, Sendable {
    case others, influential, highlyInfluential, teamLeader

    private var rank: Int { Standing.allCases.firstIndex(of: self) ?? 0 }
    public static func < (a: Standing, b: Standing) -> Bool { a.rank < b.rank }
}

/// The social group a player belongs to. Codes as one string: "core", "others", "secondary:A".
public enum SocialGroup: Hashable, Codable, Sendable {
    case core, secondary(String), others

    private static let secondaryPrefix = "secondary:"

    public init(from decoder: any Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        switch text {
        case "core": self = .core
        case "others": self = .others
        case _ where text.hasPrefix(SocialGroup.secondaryPrefix) && text.count > SocialGroup.secondaryPrefix.count:
            self = .secondary(String(text.dropFirst(SocialGroup.secondaryPrefix.count)))
        default:
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath,
                debugDescription: "\"\(text)\" is not a social group; use \"core\", \"others\" or \"secondary:\" and a name."))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .core: try container.encode("core")
        case .others: try container.encode("others")
        case .secondary(let name): try container.encode(SocialGroup.secondaryPrefix + name)
        }
    }
}

/// What the owner has entered about a player's place in the dressing room.
public struct PlayerDynamics: Equatable, Codable, Sendable {
    /// `.others` when nothing is entered.
    public var standing: Standing
    /// Nil: not entered.
    public var socialGroup: SocialGroup?

    public init(standing: Standing = .others, socialGroup: SocialGroup? = nil) {
        self.standing = standing
        self.socialGroup = socialGroup
    }
}

/// A player's personality values on one day, as the squad import gave them.
public struct PersonalityReading: Equatable, Codable, Sendable {
    public let day: Day
    /// Those of `Mentoring.readAttributes` the player has.
    public let values: [Attribute: Int]

    public init(day: Day, values: [Attribute: Int]) {
        self.day = day
        self.values = values
    }

    public init(day: Day, player: Player) {
        self.init(day: day, values: Dictionary(uniqueKeysWithValues: Mentoring.readAttributes.compactMap { attribute in
            player.attributes[attribute].map { (attribute, $0) }
        }))
    }
}

public struct MentoringMember: Equatable, Codable, Sendable {
    public var player: PlayerID
    public var joinedOn: Day
    public var leftOn: Day?

    public init(player: PlayerID, joinedOn: Day, leftOn: Day? = nil) {
        self.player = player
        self.joinedOn = joinedOn
        self.leftOn = leftOn
    }
}

/// A mentoring group the owner has set up in the game, with who was in it and when.
public struct MentoringGroup: Identifiable, Equatable, Codable, Sendable {
    public var id: UUID
    public var squad: Squad
    public var startedOn: Day
    public var endedOn: Day?
    public var members: [MentoringMember]

    public init(id: UUID, squad: Squad, startedOn: Day, endedOn: Day? = nil, members: [MentoringMember]) {
        self.id = id
        self.squad = squad
        self.startedOn = startedOn
        self.endedOn = endedOn
        self.members = members
    }

    public var isLive: Bool { endedOn == nil }

    /// The members who have not left, by player key.
    public var current: [MentoringMember] {
        members.filter { $0.leftOn == nil }.sorted { $0.player.key < $1.player.key }
    }
}

public enum Mentoring {
    /// A mentoring group is exactly this many players: a fact of the game.
    public static let groupSize = 3

    /// Determination and the eight personality attributes, in `Attribute.allCases` order.
    public static let readAttributes: [Attribute] = {
        let wanted: Set<Attribute> = [.determination, .adaptability, .ambition, .controversy, .loyalty, .pressure,
                                      .professionalism, .sportsmanship, .temperament]
        return Attribute.allCases.filter { wanted.contains($0) }
    }()

    /// The attributes with a weight above 0: heaviest first, then in `Attribute.allCases` order.
    public static func counted(_ parameters: EngineParameters) -> [Attribute] {
        let weights = parameters.mentoringWeights.value
        let order = Dictionary(uniqueKeysWithValues: Attribute.allCases.enumerated().map { ($1, $0) })
        return weights.filter { $0.value > 0 }.keys.sorted { a, b in
            let wa = weights[a] ?? 0, wb = weights[b] ?? 0
            return wa != wb ? wa > wb : (order[a] ?? 0) < (order[b] ?? 0)
        }
    }

    /// The weight times the value, the value stopping at the ceiling; 0 for an attribute that is not counted.
    public static func worth(_ attribute: Attribute, _ value: Int, parameters: EngineParameters) -> Int {
        guard let weight = parameters.mentoringWeights.value[attribute], weight > 0 else { return 0 }
        let ceiling = parameters.mentoringCeilings.value[attribute] ?? value
        return weight * min(value, ceiling)
    }

    /// Nil when either has no group entered; false when they differ or either is in `.others`.
    public static func sameSocialGroup(_ a: SocialGroup?, _ b: SocialGroup?) -> Bool? {
        guard let a, let b else { return nil }
        if a == .others || b == .others { return false }
        return a == b
    }

    /// A higher standing, or the same standing and at least `mentoringSeniorityYears` older.
    /// A lower standing never stands above, whatever the age.
    public static func standsAbove(_ a: (standing: Standing, age: Int), _ b: (standing: Standing, age: Int),
                                   parameters: EngineParameters) -> Bool {
        if a.standing != b.standing { return a.standing > b.standing }
        return a.age - b.age >= parameters.mentoringSeniorityYears.value
    }

    /// Problems in the mentoring parameters, in plain words; empty when they can be used.
    public static func problems(in parameters: EngineParameters) -> [String] {
        var found: [String] = []
        let weights = parameters.mentoringWeights.value, ceilings = parameters.mentoringCeilings.value
        for attribute in weights.keys.sorted(by: { $0.rawValue < $1.rawValue }) where ceilings[attribute] == nil {
            found.append("mentoringCeilings has no ceiling for \(attribute.rawValue), which mentoringWeights counts")
        }
        for attribute in ceilings.keys.sorted(by: { $0.rawValue < $1.rawValue }) where weights[attribute] == nil {
            found.append("mentoringWeights has no weight for \(attribute.rawValue), which mentoringCeilings has a ceiling for")
        }
        for (attribute, weight) in weights.sorted(by: { $0.key.rawValue < $1.key.rawValue }) where weight < 0 {
            found.append("mentoringWeights gives \(attribute.rawValue) a weight of \(weight), which is below 0")
        }
        for (attribute, ceiling) in ceilings.sorted(by: { $0.key.rawValue < $1.key.rawValue }) where !(1...20).contains(ceiling) {
            found.append("mentoringCeilings gives \(attribute.rawValue) a ceiling of \(ceiling), which is not from 1 to 20")
        }
        let positives: [(String, Int)] = [
            ("mentoringMenteeMaxAge", parameters.mentoringMenteeMaxAge.value),
            ("mentoringSeniorityYears", parameters.mentoringSeniorityYears.value),
            ("mentoringStoppedAfterWeeks", parameters.mentoringStoppedAfterWeeks.value),
            ("mentoringDynamicsStaleAfterDays", parameters.mentoringDynamicsStaleAfterDays.value),
            ("mentoringTakesNothingAfter", parameters.mentoringTakesNothingAfter.value)]
        for (name, value) in positives where value <= 0 {
            found.append("\(name) is \(value), which is not above 0")
        }
        let guesses = parameters.mentoringGuess.value
        for standing in Standing.allCases where guesses[standing] == nil {
            found.append("mentoringGuess has no strength for \(standing.rawValue)")
        }
        let strengthWeights = parameters.mentoringStrengthWeights.value
        for strength in ArrowStrength.allCases where strengthWeights[strength] == nil {
            found.append("mentoringStrengthWeights has no weight for \(strength.rawValue)")
        }
        if let none = strengthWeights[.none], none != 0 {
            found.append("mentoringStrengthWeights gives none a weight of \(none), which is not 0")
        }
        for strength in ArrowStrength.allCases {
            if let weight = strengthWeights[strength], weight < 0 {
                found.append("mentoringStrengthWeights gives \(strength.rawValue) a weight of \(weight), which is below 0")
            }
        }
        let weighed = ArrowStrength.allCases.filter { strengthWeights[$0] != nil }
        for (weaker, stronger) in zip(weighed, weighed.dropFirst()) {
            if let low = strengthWeights[weaker], let high = strengthWeights[stronger], high < low {
                found.append("mentoringStrengthWeights gives \(stronger.rawValue) (\(high)) less than \(weaker.rawValue) (\(low)), a weaker arrow")
            }
        }
        return found
    }
}
