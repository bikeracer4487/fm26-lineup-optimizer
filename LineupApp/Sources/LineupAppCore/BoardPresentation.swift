import Foundation
import LineupEngine

/// The line of the team a position belongs to. Magnets on the pitch and in tables take its colour.
public enum PitchLine: CaseIterable, Hashable, Sendable {
    case goalkeeper, defence, midfield, attack

    /// Full backs and wing-backs defend; the defensive midfielder is in midfield; attacking midfielders attack.
    public init(_ position: Position) {
        switch position {
        case .goalkeeper:
            self = .goalkeeper
        case .defenderLeft, .defenderCentral, .defenderRight, .wingBackLeft, .wingBackRight:
            self = .defence
        case .defensiveMidfielder, .midfielderLeft, .midfielderCentral, .midfielderRight:
            self = .midfield
        case .attackingMidLeft, .attackingMidCentral, .attackingMidRight, .striker:
            self = .attack
        }
    }

    public init(_ slot: SlotID) {
        self.init(slot.position)
    }

    /// The line of the position a player knows best; positions known as well go by the engine's order of positions,
    /// so the answer never depends on the order of a dictionary. Nil when no position is known.
    public static func main(familiarity: [Position: Int]) -> PitchLine? {
        var best: (position: Position, familiarity: Int)?
        for position in Position.allCases {
            guard let known = familiarity[position] else { continue }
            if best == nil || known > best!.familiarity { best = (position, known) }
        }
        return best.map { PitchLine($0.position) }
    }
}

/// Words the board writes that are not about one screen.
public enum BoardText {
    /// The board's title when the club is not known.
    public static let appTitle = "Lineup Optimizer"

    /// What a magnet shows for a starter whose name is not known.
    public static let unknownInitials = "?"

    /// The club's name, or the app's when the club is not known.
    public static func boardTitle(ownClub: String?) -> String {
        ownClub ?? appTitle
    }

    /// A magnet's letters: the first name's first letter and the first letter of the surname's main word, as
    /// capitals ("Dillon De Silva" is "DS"). The surname is the one `MatchText.surname` finds, less its particles.
    /// A one-word name gives one letter.
    public static func initials(_ name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace).map(String.init)
        guard let first = words.first?.first else { return "" }
        guard words.count > 1 else { return String(first).uppercased() }
        let surname = MatchText.surname(name).split(whereSeparator: \.isWhitespace).map(String.init)
        let main = surname.first { !MatchText.particles.contains($0.lowercased()) } ?? surname.last ?? ""
        return (String(first) + (main.first.map(String.init) ?? "")).uppercased()
    }

    /// The minus sign negative numbers are written with: U+2212, the width of a plus, not a hyphen.
    public static let minus = "\u{2212}"

    /// A whole number, a negative one with a true minus sign: "−168".
    public static func signed(_ value: Int) -> String {
        signed(String(value))
    }

    /// A written number with its leading hyphen, if it has one, made a true minus sign.
    public static func signed(_ number: String) -> String {
        number.hasPrefix("-") ? minus + number.dropFirst() : number
    }

    /// The notice for typefaces that could not be loaded; nil when every one was.
    public static func fontNotice(missing: [String]) -> String? {
        switch missing.count {
        case 0:
            return nil
        case 1:
            return "The typeface \(missing[0]) could not be loaded, so the system typeface is used in its place."
        default:
            let names = missing.dropLast().joined(separator: ", ") + " and " + missing[missing.count - 1]
            return "The typefaces \(names) could not be loaded, so the system typeface is used in their place."
        }
    }
}

/// How a meter's lit blocks are coloured.
public enum MeterLevel: Hashable, Sendable {
    case good, middling, poor
}

/// Condition or sharpness as five blocks: one lit for each twenty from ten, all in one colour by level.
public struct Meter: Equatable, Sendable {
    /// How many blocks a meter has.
    public static let blocks = 5
    /// The percentage the first block lights at, and how much more each further block needs.
    public static let firstBlockFrom = 10
    public static let blockSpan = 20
    /// The level from these percentages up: good, then middling; below, poor.
    public static let goodFrom = 85
    public static let middlingFrom = 70

    /// How many blocks are lit, from the left.
    public let lit: Int
    public let level: MeterLevel

    public init(percent: Int) {
        lit = (0..<Self.blocks).filter { percent >= Self.firstBlockFrom + $0 * Self.blockSpan }.count
        level = percent >= Self.goodFrom ? .good : percent >= Self.middlingFrom ? .middling : .poor
    }

    /// The meter for a fraction, read as the whole percentage written beside it.
    public init(fraction: Double) {
        self.init(percent: Self.wholePercent(fraction))
    }

    public func isLit(_ block: Int) -> Bool { block < lit }

    /// As `Display.percent` writes it: rounded down, after absorbing floating-point error.
    static func wholePercent(_ fraction: Double) -> Int {
        Int((fraction * 100 + 1e-9).rounded(.down))
    }
}

/// What a reason did to a player's match-day value.
public enum ReasonDirection: Hashable, Sendable {
    case raised, lowered, unchanged

    /// An adjustment's: a factor above 1 or a bonus raises it, a factor below 1 or a cost lowers it. One of each, or
    /// neither, is unchanged.
    public init(factor: Double, cost: Double) {
        let raises = factor > 1 || cost < 0
        let lowers = factor < 1 || cost > 0
        self = raises == lowers ? .unchanged : raises ? .raised : .lowered
    }

    /// A fitness line's, from its factor.
    public init(fitnessFactor: Double) {
        self.init(factor: fitnessFactor, cost: 0)
    }
}

/// One of a pick's reasons, as written, with what it did to his value.
public struct MarkedReason: Hashable, Sendable {
    public let text: String
    public let direction: ReasonDirection

    public init(text: String, direction: ReasonDirection) {
        self.text = text; self.direction = direction
    }

    /// The reasons marked in the order the engine writes them: the rating line, then a line for each fitness factor
    /// below 1 (condition, sharpness, jadedness), then each adjustment's reason, then the override line. The rating and
    /// override lines, and any line beyond those, are unchanged.
    public static func marks(reasons: [String], fitness: FitnessFactors, adjustments: [Adjustment]) -> [MarkedReason] {
        let fitnessLines = [fitness.condition, fitness.sharpness, fitness.jadedness]
            .filter { $0 < 1 }
            .map(ReasonDirection.init(fitnessFactor:))
        let directions = [ReasonDirection.unchanged] + fitnessLines
            + adjustments.map { ReasonDirection(factor: $0.factor, cost: $0.cost) }
        return reasons.enumerated().map { index, text in
            MarkedReason(text: text, direction: index < directions.count ? directions[index] : .unchanged)
        }
    }
}

/// How far a sticky note leans, in degrees, by its place in its row: the same place always leans the same way, so
/// pictures repeat, and neighbours lean differently.
public enum NoteTilt {
    public static let pattern: [Double] = [-1.2, 0.8, -0.6, 1.1, -0.9]

    public static func degrees(at index: Int) -> Double {
        pattern[((index % pattern.count) + pattern.count) % pattern.count]
    }
}

/// The colour a stamp is inked in: marker red, marker amber, ink, or muted ink for one that should recede.
public enum StampTone: Hashable, Sendable {
    case red, amber, ink, muted
}

/// A status written as a stamp: in sentence case, in its colour.
public struct StatusStamp: Hashable, Sendable {
    public let text: String
    public let tone: StampTone

    public init(text: String, tone: StampTone) {
        self.text = text; self.tone = tone
    }

    /// A status's stamp: red when it keeps him out of a lineup, amber when it does not.
    public init(text: String, isOut: Bool) {
        self.init(text: text, tone: isOut ? .red : .amber)
    }

    /// Whether the stamp says he is out of a lineup.
    public var isOut: Bool { tone == .red }
}

extension PlayerStatus {
    /// A stamp for each status, in their order.
    public static func stamps(_ statuses: [PlayerStatus]) -> [StatusStamp] {
        statuses.map { status in
            StatusStamp(text: status.text.prefix(1).uppercased() + status.text.dropFirst(), isOut: status.keepsHimOut)
        }
    }
}

extension Importance {
    /// What a fixture's sticky note says about it.
    public var noteText: String {
        switch self {
        case .sharpness: "Sharpness match"
        case .low, .medium, .high: "\(displayName) importance"
        }
    }
}

extension DayText {
    /// "Fri 13 Nov 2026".
    public static func shortWithYear(_ day: Day) -> String {
        "\(short(day)) \(day.iso.prefix(4))"
    }
}

/// A column of the squad table.
public enum SquadColumn: CaseIterable, Hashable, Sendable {
    case name, squad, age, position, ability, condition, sharpness, jadedness, status

    public var title: String {
        switch self {
        case .name: "Name"
        case .squad: "Squad"
        case .age: "Age"
        case .position: "Position"
        case .ability: "Ability now and potential"
        case .condition: "Condition"
        case .sharpness: "Sharpness"
        case .jadedness: "Jadedness"
        case .status: "Status"
        }
    }

    /// What clicking the heading does: "Sort by age".
    public var sortHelp: String { "Sort by \(title.lowercased())" }

    func comparator(_ order: SortOrder) -> KeyPathComparator<SquadRow> {
        switch self {
        case .name: KeyPathComparator(\.name, order: order)
        case .squad: KeyPathComparator(\.squadOrder, order: order)
        case .age: KeyPathComparator(\.age, order: order)
        case .position: KeyPathComparator(\.positions, order: order)
        case .ability: KeyPathComparator(\.currentAbility, order: order)
        case .condition: KeyPathComparator(\.condition, order: order)
        case .sharpness: KeyPathComparator(\.sharpness, order: order)
        case .jadedness: KeyPathComparator(\.jadedness, order: order)
        case .status: KeyPathComparator(\.statusText, order: order)
        }
    }
}

/// How the squad table is sorted: by the column whose heading was clicked last, turned round by clicking it again.
public struct SquadSort: Equatable, Sendable {
    /// Nil: the rows as given.
    public var column: SquadColumn?
    public var ascending: Bool

    public init(column: SquadColumn? = nil, ascending: Bool = true) {
        self.column = column; self.ascending = ascending
    }

    /// The sort after clicking `column`'s heading.
    public func choosing(_ column: SquadColumn) -> SquadSort {
        column == self.column ? SquadSort(column: column, ascending: !ascending) : SquadSort(column: column)
    }

    /// For `SquadRow.sorted`.
    public var comparators: [KeyPathComparator<SquadRow>] {
        column.map { [$0.comparator(ascending ? .forward : .reverse)] } ?? []
    }
}

extension AppModel {
    /// The club's name, or the app's when the club is not known.
    public var boardTitle: String {
        BoardText.boardTitle(ownClub: ownClub)
    }

    /// Adds a notice the owner sees until he dismisses it.
    public func addNotice(_ text: String) {
        notice(text)
    }
}
