import Foundation
import LineupEngine

extension Squad {
    /// The squad's name on screen.
    public var displayName: String {
        switch self {
        case .firstTeam: "First team"
        case .u21: "U21s"
        case .u18: "U18s"
        }
    }

    /// The squad in the middle of a sentence: "the first team", "the U21s".
    public var inSentence: String {
        switch self {
        case .firstTeam: "the first team"
        case .u21: "the U21s"
        case .u18: "the U18s"
        }
    }

    /// The button that imports the clipboard as this squad.
    public var importButtonTitle: String {
        switch self {
        case .firstTeam: "Import first team"
        case .u21: "Import U21s"
        case .u18: "Import U18s"
        }
    }
}

/// One fact about a player's availability or standing, in the words the squad table shows.
public enum PlayerStatus: Equatable, Sendable {
    case outOnLoan(to: String)
    case onLoan(from: String?)
    case injured
    case banned
    case outOfContract

    public var text: String {
        switch self {
        case .outOnLoan(let club): "out on loan to \(club)"
        case .onLoan(let club?): "on loan from \(club)"
        case .onLoan(nil): "on loan"
        case .injured: "injured"
        case .banned: "banned"
        case .outOfContract: "out of contract"
        }
    }

    /// Whether the fact keeps him out of a lineup.
    var keepsHimOut: Bool {
        switch self {
        case .outOnLoan, .injured, .banned: true
        case .onLoan, .outOfContract: false
        }
    }

    /// The player's statuses: where he is on loan first, then injured, banned and out of contract.
    public static func of(_ player: Player, loan: LoanStatus) -> [PlayerStatus] {
        var statuses: [PlayerStatus] = []
        switch loan {
        case .own: break
        case .loanedOut(let club): statuses.append(.outOnLoan(to: club))
        case .loanedIn(let club): statuses.append(.onLoan(from: club))
        }
        if player.isInjured { statuses.append(.injured) }
        if player.isBanned { statuses.append(.banned) }
        switch player.contractType {
        case .outOfContract: statuses.append(.outOfContract)
        case .fullTime, .other: break
        }
        return statuses
    }

    public static func text(_ statuses: [PlayerStatus]) -> String {
        statuses.map(\.text).joined(separator: ", ")
    }

    /// Whether any of the statuses keeps him out of a lineup; the table shows such a player in claret.
    public static func isOut(_ statuses: [PlayerStatus]) -> Bool {
        statuses.contains(where: \.keepsHimOut)
    }
}

/// One player as the squad table shows him. Every column's value is here, so the table only lays it out and sorts it.
public struct SquadRow: Identifiable, Equatable, Sendable {
    public let id: PlayerID
    public let name: String
    public let squad: Squad
    public let squadName: String
    /// Sorts the squad column first team, U21s, U18s.
    public let squadOrder: Int
    public let age: Int
    public let positions: String
    public let currentAbility: Int
    public let potentialAbility: Int
    public let condition: Double
    public let conditionText: String
    public let sharpness: Double
    public let sharpnessText: String
    public let jadedness: Int
    public let statuses: [PlayerStatus]
    public let statusText: String
    public let isOut: Bool

    init(_ player: Player, loan: LoanStatus) {
        id = player.id
        name = player.name
        squad = player.squad
        squadName = player.squad.displayName
        squadOrder = Self.order(of: player.squad)
        age = player.age
        positions = player.positionsText
        currentAbility = player.currentAbility
        potentialAbility = player.potentialAbility
        condition = player.condition
        conditionText = Self.percent(player.condition)
        sharpness = player.sharpness
        sharpnessText = Self.percent(player.sharpness)
        jadedness = player.jadedness
        statuses = PlayerStatus.of(player, loan: loan)
        statusText = PlayerStatus.text(statuses)
        isOut = PlayerStatus.isOut(statuses)
    }

    /// The rows in the table's sort order: the first comparator that tells two rows apart decides, and rows
    /// it leaves equal go by name, then by key, so the order never depends on the order they came in.
    /// With no comparator the rows stay as given.
    public static func sorted(_ rows: [SquadRow], using order: [KeyPathComparator<SquadRow>]) -> [SquadRow] {
        guard !order.isEmpty else { return rows }
        return rows.sorted { a, b in
            for comparator in order {
                switch comparator.compare(a, b) {
                case .orderedAscending: return true
                case .orderedDescending: return false
                case .orderedSame: continue
                }
            }
            return (a.name, a.id.key) < (b.name, b.id.key)
        }
    }

    /// A whole percentage rounded down, written as the engine writes it in its reasons.
    static func percent(_ fraction: Double) -> String { Display.percent(fraction) }

    static func order(of squad: Squad) -> Int {
        Squad.allCases.firstIndex(of: squad)!
    }
}

/// What the import panel says after an import that worked.
public struct ImportReport: Equatable, Sendable {
    public let heading: String
    public let lines: [String]
    /// The engine's sentences, as written.
    public let warnings: [String]

    /// Under the game's date on the Squad screen.
    public static let datingLine = "Each import is dated with this day. Set it to the day in the game before you import."

    /// What a failed import says first, before the reason: "The U21s were not imported; the squad is as it was."
    public static func notImportedLine(_ squad: Squad) -> String {
        let subject = squad.inSentence.prefix(1).uppercased() + squad.inSentence.dropFirst()
        return "\(subject) \(squad == .firstTeam ? "was" : "were") not imported; the squad is as it was."
    }

    /// How many names a list in the report shows before it says how many more there are.
    static let namesShown = 5

    /// Which FMRTE grid the paste came from, in the owner's words.
    static func gridLine(_ key: String) -> String {
        switch key {
        case "TeamPlayersColumns": "Recognised as FMRTE's squad grid."
        case "SearchPlayersColumns": "Recognised as FMRTE's player search grid."
        default: "Recognised as FMRTE's grid \"\(key)\"."
        }
    }

    static func playerCountLine(_ count: Int) -> String {
        count == 1 ? "1 player." : "\(count) players."
    }

    /// What changed since the squad's last import. New players are those not moved in from another squad;
    /// changed players are counted, not named, since most imports change many players' condition.
    static func changeLine(_ change: SquadChange, firstImport: Bool, name: (PlayerID) -> String) -> String {
        if firstImport { return "This is the first import of this squad." }
        let movedIn = Set(change.movedIn)
        let added = change.added.filter { !movedIn.contains($0) }
        var parts: [String] = []
        if !added.isEmpty { parts.append("\(added.count) added (\(names(added, name)))") }
        if !change.movedIn.isEmpty {
            parts.append("\(change.movedIn.count) moved in from another squad (\(names(change.movedIn, name)))")
        }
        if !change.removed.isEmpty { parts.append("\(change.removed.count) removed (\(names(change.removed, name)))") }
        if !change.changed.isEmpty { parts.append("\(change.changed.count) changed") }
        if parts.isEmpty { return "Nothing changed since the last import." }
        return "Since the last import: \(parts.joined(separator: "; "))."
    }

    private static func names(_ ids: [PlayerID], _ name: (PlayerID) -> String) -> String {
        let shown = ids.prefix(namesShown).map(name).joined(separator: ", ")
        return ids.count > namesShown ? "\(shown) and \(ids.count - namesShown) more" : shown
    }
}

/// The club line on the Squad screen: the club's name, or the engine's warning that it is not known.
public enum ClubLine: Equatable, Sendable {
    case known(String)
    case unknown(warning: String)

    public var text: String {
        switch self {
        case .known(let club): "Club: \(club)"
        case .unknown(let warning): warning
        }
    }

    /// Whether the line offers to set the club's name in Settings.
    public var needsSettings: Bool {
        switch self {
        case .known: false
        case .unknown: true
        }
    }
}

extension AppModel {
    /// The rows of the squad table: every player, or one squad's, whose name contains `search` ignoring case,
    /// accents and spacing at its ends; in `players` order.
    public func squadRows(in squad: Squad?, matching search: String) -> [SquadRow] {
        let wanted = PlayerID.normalise(search)
        return players
            .filter { squad == nil || $0.squad == squad }
            .filter { wanted.isEmpty || PlayerID.normalise($0.name).contains(wanted) }
            .map { SquadRow($0, loan: self.squad.book.loanStatus(of: $0, override: settings.clubOverride)) }
    }

    /// "imported 13 Nov", or "not imported yet".
    public func importedText(for squad: Squad) -> String {
        self.squad.importedOn[squad].map { "imported \(DayText.dayAndMonth($0))" } ?? "not imported yet"
    }

    /// The report of an import that worked. Names come from the squad as imported, and removed players' names
    /// from the import it replaced.
    public func report(of summary: ImportSummary) -> ImportReport {
        let book = squad.book
        let previous = book.previous[summary.squad]
        var names: [PlayerID: String] = [:]
        for player in (previous ?? []) + book.allPlayers { names[player.id] = player.name }
        let loans = summary.onLoan.isEmpty
            ? "No one is out on loan."
            : "Out on loan: \(summary.onLoan.joined(separator: ", "))."
        return ImportReport(
            heading: "\(summary.squad.displayName) imported, dated \(DayText.short(summary.date))",
            lines: [
                ImportReport.gridLine(summary.grid),
                ImportReport.playerCountLine(summary.playerCount),
                loans,
                ImportReport.changeLine(summary.change, firstImport: previous == nil, name: { names[$0] ?? $0.key }),
            ],
            warnings: summary.warnings)
    }

    public var clubLine: ClubLine {
        if let club = ownClub { return .known(club) }
        return .unknown(warning: ErrorDescriptions.describe(SquadWarning.ownClubUnknown))
    }

    /// The squad warnings listed under the club line: all but the unknown club, which the club line says.
    public var listedSquadWarnings: [String] {
        squad.book.warnings(override: settings.clubOverride)
            .filter { $0 != .ownClubUnknown }
            .map(ErrorDescriptions.describe)
    }
}
