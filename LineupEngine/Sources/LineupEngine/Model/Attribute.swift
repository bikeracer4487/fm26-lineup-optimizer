/// A player attribute, named as in the game and in the role data files.
/// The 62 cases are the attribute columns of the FMRTE player grid.
public enum Attribute: String, CaseIterable, Codable, Sendable {
    case aerialReach = "Aerial Reach"
    case commandOfArea = "Command Of Area"
    case communication = "Communication"
    case eccentricity = "Eccentricity"
    case handling = "Handling"
    case kicking = "Kicking"
    case oneOnOnes = "One On Ones"
    case reflexes = "Reflexes"
    case rushingOutTendency = "Rushing Out (Tendency)"
    case punchingTendency = "Punching (Tendency)"
    case throwing = "Throwing"
    case consistency = "Consistency"
    case dirtiness = "Dirtiness"
    case importantMatches = "Important Matches"
    case injuryProneness = "Injury Proneness"
    case versatility = "Versatility"
    case aggression = "Aggression"
    case anticipation = "Anticipation"
    case bravery = "Bravery"
    case composure = "Composure"
    case concentration = "Concentration"
    case decisions = "Decisions"
    case determination = "Determination"
    case flair = "Flair"
    case leadership = "Leadership"
    case offTheBall = "Off The Ball"
    case positioning = "Positioning"
    case teamwork = "Teamwork"
    case vision = "Vision"
    case workRate = "Work Rate"
    case adaptability = "Adaptability"
    case ambition = "Ambition"
    case controversy = "Controversy"
    case loyalty = "Loyalty"
    case pressure = "Pressure"
    case professionalism = "Professionalism"
    case sportsmanship = "Sportsmanship"
    case temperament = "Temperament"
    case acceleration = "Acceleration"
    case agility = "Agility"
    case balance = "Balance"
    case jumpingReach = "Jumping Reach"
    case leftFoot = "Left Foot"
    case naturalFitness = "Natural Fitness"
    case pace = "Pace"
    case rightFoot = "Right Foot"
    case stamina = "Stamina"
    case strength = "Strength"
    case corners = "Corners"
    case crossing = "Crossing"
    case dribbling = "Dribbling"
    case finishing = "Finishing"
    case firstTouch = "First Touch"
    case freeKickTaking = "Free Kick Taking"
    case heading = "Heading"
    case longShots = "Long Shots"
    case longThrows = "Long Throws"
    case marking = "Marking"
    case passing = "Passing"
    case penaltyTaking = "Penalty Taking"
    case tackling = "Tackling"
    case technique = "Technique"

    /// Looks an attribute up by canonical name (the spelling used in a role data file).
    public init?(catalogName: String) {
        self.init(rawValue: catalogName)
    }

    /// Canonical names whose spelling differs from the FMRTE path component split at capitals.
    private static let renamed: [String: String] = [
        "AerialAbility": "Aerial Reach",
        "RushingOut": "Rushing Out (Tendency)",
        "TendencyToPunch": "Punching (Tendency)",
        "Jumping": "Jumping Reach",
        "Workrate": "Work Rate",
        "Freekicks": "Free Kick Taking",
        "Longthrows": "Long Throws",
        "InjuryProness": "Injury Proneness",
        "Professional": "Professionalism",
    ]

    /// Maps an FMRTE column path such as `MentalAttributes.Workrate` to an attribute.
    /// Returns nil unless the first path component ends in `Attributes` and the name is known.
    public static func fromFMRTEPath(_ path: String) -> Attribute? {
        let parts = path.split(separator: ".").map(String.init)
        guard parts.count >= 2, parts[0].hasSuffix("Attributes"), let last = parts.last else { return nil }
        if let name = renamed[last] { return Attribute(rawValue: name) }
        var name = ""
        for character in last {
            if character.isUppercase, !name.isEmpty { name.append(" ") }
            name.append(character)
        }
        return Attribute(rawValue: name)
    }

    /// The FMRTE grid column path for this attribute, for example `MentalAttributes.Workrate`.
    /// The inverse of `fromFMRTEPath`.
    public var fmrtePath: String {
        let category = switch self {
        case .aerialReach, .commandOfArea, .communication, .eccentricity, .handling, .kicking, .oneOnOnes, .reflexes, .rushingOutTendency, .punchingTendency, .throwing: "GoalKeeperAttributes"
        case .consistency, .dirtiness, .importantMatches, .injuryProneness, .versatility: "HiddenAttributes"
        case .aggression, .anticipation, .bravery, .composure, .concentration, .decisions, .determination, .flair, .leadership, .offTheBall, .positioning, .teamwork, .vision, .workRate: "MentalAttributes"
        case .adaptability, .ambition, .controversy, .loyalty, .pressure, .professionalism, .sportsmanship, .temperament: "PersonalityAttributes"
        case .acceleration, .agility, .balance, .jumpingReach, .leftFoot, .naturalFitness, .pace, .rightFoot, .stamina, .strength: "PhysicalAttributes"
        case .corners, .crossing, .dribbling, .finishing, .firstTouch, .freeKickTaking, .heading, .longShots, .longThrows, .marking, .passing, .penaltyTaking, .tackling, .technique: "TechnicalAttributes"
        }
        return category + "." + (Attribute.fmrteComponent[self] ?? rawValue.replacingOccurrences(of: " ", with: ""))
    }

    /// Path components that differ from the attribute name with its spaces removed.
    private static let fmrteComponent: [Attribute: String] = Dictionary(
        uniqueKeysWithValues: renamed.compactMap { component, name in
            Attribute(rawValue: name).map { ($0, component) }
        }
    )
}

/// A string-valued coding key, so dictionaries keyed by raw-value enums encode as JSON objects.
struct RawStringCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init(_ stringValue: String) { self.stringValue = stringValue }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

extension Attribute: CodingKeyRepresentable {
    public var codingKey: any CodingKey { RawStringCodingKey(rawValue) }
    public init?<T: CodingKey>(codingKey: T) { self.init(rawValue: codingKey.stringValue) }
}
