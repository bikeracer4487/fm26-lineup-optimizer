/// A playing position as the game's position ratings name it.
public enum Position: String, CaseIterable, Codable, Sendable {
    case goalkeeper = "GK"
    case defenderLeft = "D (L)"
    case defenderCentral = "D (C)"
    case defenderRight = "D (R)"
    case wingBackLeft = "WB (L)"
    case wingBackRight = "WB (R)"
    case defensiveMidfielder = "DM"
    case midfielderLeft = "M (L)"
    case midfielderCentral = "M (C)"
    case midfielderRight = "M (R)"
    case attackingMidLeft = "AM (L)"
    case attackingMidCentral = "AM (C)"
    case attackingMidRight = "AM (R)"
    case striker = "ST (C)"

    /// The key used in position rating tables: the raw value without spaces, with `ST (C)` as `ST`.
    public var tableKey: String {
        self == .striker ? "ST" : rawValue.replacingOccurrences(of: " ", with: "")
    }

    /// True for the goalkeeper, the defenders, the wing backs and the defensive midfielder.
    public var isDefensive: Bool {
        switch self {
        case .goalkeeper, .defenderLeft, .defenderCentral, .defenderRight,
             .wingBackLeft, .wingBackRight, .defensiveMidfielder:
            true
        default:
            false
        }
    }

    private static let fmrteComponents: [String: Position] = [
        "Goalkeeper": .goalkeeper,
        "DefenderLeft": .defenderLeft,
        "DefenderCentral": .defenderCentral,
        "DefenderRight": .defenderRight,
        "WingBackLeft": .wingBackLeft,
        "WingBackRight": .wingBackRight,
        "DefensiveMidfielder": .defensiveMidfielder,
        "MidfielderLeft": .midfielderLeft,
        "MidfielderCentral": .midfielderCentral,
        "MidfielderRight": .midfielderRight,
        "AttackingMidLeft": .attackingMidLeft,
        "AttackingMidCentral": .attackingMidCentral,
        "AttackingMidRight": .attackingMidRight,
        "Striker": .striker,
    ]

    /// The FMRTE grid column path for this position's rating, for example `Positions.Striker`.
    /// The inverse of `fromFMRTEPath`.
    public var fmrtePath: String {
        let component = switch self {
        case .goalkeeper: "Goalkeeper"
        case .defenderLeft: "DefenderLeft"
        case .defenderCentral: "DefenderCentral"
        case .defenderRight: "DefenderRight"
        case .wingBackLeft: "WingBackLeft"
        case .wingBackRight: "WingBackRight"
        case .defensiveMidfielder: "DefensiveMidfielder"
        case .midfielderLeft: "MidfielderLeft"
        case .midfielderCentral: "MidfielderCentral"
        case .midfielderRight: "MidfielderRight"
        case .attackingMidLeft: "AttackingMidLeft"
        case .attackingMidCentral: "AttackingMidCentral"
        case .attackingMidRight: "AttackingMidRight"
        case .striker: "Striker"
        }
        return "Positions." + component
    }

    /// Maps an FMRTE column path such as `Positions.DefenderCentral` to a position.
    public static func fromFMRTEPath(_ path: String) -> Position? {
        let parts = path.split(separator: ".").map(String.init)
        guard parts.count == 2, parts[0] == "Positions" else { return nil }
        return fmrteComponents[parts[1]]
    }
}

/// Whether a role is being played with or without the ball.
public enum Phase: String, Codable, Sendable {
    case inPossession = "ip"
    case outOfPossession = "oop"
}

/// A place on the pitch a tactic can fill. Case order is the tie-break order of selection.
public enum SlotID: String, CaseIterable, Codable, Sendable {
    case GK
    case D_L, D_CL, D_C, D_CR, D_R
    case WB_L, DM_L, DM_C, DM_R, WB_R
    case M_L, M_CL, M_C, M_CR, M_R
    case AM_L, AM_CL, AM_C, AM_CR, AM_R
    case ST_L, ST_C, ST_R

    /// The position whose rating applies to this slot.
    public var position: Position {
        switch self {
        case .GK: .goalkeeper
        case .D_L: .defenderLeft
        case .D_CL, .D_C, .D_CR: .defenderCentral
        case .D_R: .defenderRight
        case .WB_L: .wingBackLeft
        case .WB_R: .wingBackRight
        case .DM_L, .DM_C, .DM_R: .defensiveMidfielder
        case .M_L: .midfielderLeft
        case .M_CL, .M_C, .M_CR: .midfielderCentral
        case .M_R: .midfielderRight
        case .AM_L: .attackingMidLeft
        case .AM_CL, .AM_C, .AM_CR: .attackingMidCentral
        case .AM_R: .attackingMidRight
        case .ST_L, .ST_C, .ST_R: .striker
        }
    }
}

extension Position: CodingKeyRepresentable {
    public var codingKey: any CodingKey { RawStringCodingKey(rawValue) }
    public init?<T: CodingKey>(codingKey: T) { self.init(rawValue: codingKey.stringValue) }
}

/// Lets `[SlotID: V]` encode as a JSON object keyed by the slot id strings.
extension SlotID: CodingKeyRepresentable {
    public var codingKey: any CodingKey { RawStringCodingKey(rawValue) }
    public init?<T: CodingKey>(codingKey: T) { self.init(rawValue: codingKey.stringValue) }
}
