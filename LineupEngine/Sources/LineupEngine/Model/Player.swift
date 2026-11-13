import Foundation

/// A player's identity across imports: his name, normalised, with an age or row suffix when
/// two players in one paste share a name.
public struct PlayerID: Hashable, Codable, Sendable {
    public let key: String

    public init(key: String) { self.key = key }

    /// Lowercased, diacritics folded, inner whitespace collapsed to single spaces.
    public static func normalise(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

/// Which of the club's squads a paste was taken from.
public enum Squad: String, Codable, CaseIterable, Sendable {
    case firstTeam, u21, u18
}

public enum ContractType: Equatable, Codable, Sendable {
    case fullTime
    case outOfContract
    /// A value FMRTE pasted that this tool does not interpret, kept as pasted.
    case other(String)
}

/// One player as pasted from FMRTE. `condition` and `sharpness` are fractions of 1.
public struct Player: Identifiable, Equatable, Codable, Sendable {
    public var id: PlayerID
    public var name: String
    public var squad: Squad
    public var age: Int
    public var positionsText: String
    public var currentAbility: Int
    public var potentialAbility: Int
    public var attributes: [Attribute: Int]
    public var familiarity: [Position: Int]
    public var condition: Double
    public var sharpness: Double
    public var jadedness: Int
    public var isInjured: Bool
    public var isBanned: Bool
    public var club: String?
    public var loanedTo: String?
    public var contractType: ContractType
    public var monthsLeft: Int?
    public var wagePerWeek: Int
    public var askingPrice: Int?
    public var nationalities: [String]
    /// Optional grid columns this tool does not model, keyed by FMRTE column path.
    public var extras: [String: String]

    public init(
        id: PlayerID, name: String, squad: Squad, age: Int, positionsText: String,
        currentAbility: Int, potentialAbility: Int,
        attributes: [Attribute: Int], familiarity: [Position: Int],
        condition: Double, sharpness: Double, jadedness: Int,
        isInjured: Bool, isBanned: Bool, club: String?, loanedTo: String?,
        contractType: ContractType, monthsLeft: Int?, wagePerWeek: Int, askingPrice: Int?,
        nationalities: [String], extras: [String: String]
    ) {
        self.id = id; self.name = name; self.squad = squad; self.age = age
        self.positionsText = positionsText
        self.currentAbility = currentAbility; self.potentialAbility = potentialAbility
        self.attributes = attributes; self.familiarity = familiarity
        self.condition = condition; self.sharpness = sharpness; self.jadedness = jadedness
        self.isInjured = isInjured; self.isBanned = isBanned
        self.club = club; self.loanedTo = loanedTo
        self.contractType = contractType; self.monthsLeft = monthsLeft
        self.wagePerWeek = wagePerWeek; self.askingPrice = askingPrice
        self.nationalities = nationalities; self.extras = extras
    }
}
