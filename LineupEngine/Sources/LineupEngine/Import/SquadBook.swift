import Foundation

/// Whether a player belongs to the owner's club, is out on loan, or is on loan from elsewhere.
public enum LoanStatus: Equatable, Sendable {
    case own
    case loanedOut(to: String)
    case loanedIn(from: String?)

    /// First match wins: a loan to the own club is a loan in; any other loan is a loan out
    /// (also when the own club is unknown); a known, different `club` is a loan in; else own.
    /// Club names are compared as `PlayerID.normalise` leaves them, so case and spacing do not matter.
    public static func of(_ player: Player, ownClub: String?) -> LoanStatus {
        let own = ownClub.map(PlayerID.normalise)
        if let loanedTo = player.loanedTo {
            return PlayerID.normalise(loanedTo) == own ? .loanedIn(from: player.club) : .loanedOut(to: loanedTo)
        }
        if let own, let club = player.club, PlayerID.normalise(club) != own { return .loanedIn(from: club) }
        return .own
    }
}

public enum SquadWarning: Equatable, Sendable {
    /// Loans were pasted but the owner's club cannot be told from the squads.
    case ownClubUnknown
}

/// What one import changed in its squad, each list in the order of the new import
/// (`removed` in the order of the old list).
public struct SquadChange: Equatable, Sendable {
    public let added: [PlayerID]
    public let removed: [PlayerID]
    /// Players who were in a different squad before this import; they are also in `added`.
    public let movedIn: [PlayerID]
    /// Players present before and after whose values differ in any field.
    public let changed: [PlayerID]

    public init(added: [PlayerID], removed: [PlayerID], movedIn: [PlayerID], changed: [PlayerID]) {
        self.added = added; self.removed = removed; self.movedIn = movedIn; self.changed = changed
    }
}

/// The latest import of each squad, and the import it replaced.
public struct SquadBook: Equatable, Codable, Sendable {
    public private(set) var current: [Squad: [Player]] = [:]
    public private(set) var previous: [Squad: [Player]] = [:]

    public init() {}

    @discardableResult
    public mutating func apply(_ result: ImportResult, to squad: Squad) -> SquadChange {
        var incoming = result.players
        for i in incoming.indices { incoming[i].squad = squad }
        let old = current[squad] ?? []
        let oldByID = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let newIDs = Set(incoming.map(\.id))

        let inOtherSquad = Set(Squad.allCases.filter { $0 != squad }.flatMap { current[$0] ?? [] }.map(\.id))
        let movedIn = incoming.map(\.id).filter { inOtherSquad.contains($0) }
        let change = SquadChange(
            added: incoming.map(\.id).filter { oldByID[$0] == nil },
            removed: old.map(\.id).filter { !newIDs.contains($0) },
            movedIn: movedIn,
            changed: incoming.filter { player in oldByID[player.id].map { $0 != player } ?? false }.map(\.id)
        )

        for other in Squad.allCases where other != squad {
            current[other]?.removeAll { newIDs.contains($0.id) }
        }
        if current[squad] != nil { previous[squad] = old }
        current[squad] = incoming
        return change
    }

    /// First team, then U21, then U18, each in import order.
    public var allPlayers: [Player] {
        [Squad.firstTeam, .u21, .u18].flatMap { current[$0] ?? [] }
    }

    /// The override, trimmed, unless it is only whitespace; otherwise the most common club across
    /// all squads, counting names that `PlayerID.normalise` makes equal as one club spelt as first
    /// seen (ties to the alphabetically first); nil when no player has a club.
    public func ownClub(override: String?) -> String? {
        if let trimmed = override?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty { return trimmed }
        var counts: [String: (spelling: String, count: Int)] = [:]
        for club in allPlayers.compactMap(\.club) {
            counts[PlayerID.normalise(club), default: (club, 0)].count += 1
        }
        return counts.max { ($0.value.count, $1.key) < ($1.value.count, $0.key) }?.value.spelling
    }

    public func loanStatus(of player: Player, override: String?) -> LoanStatus {
        LoanStatus.of(player, ownClub: ownClub(override: override))
    }

    public func warnings(override: String?) -> [SquadWarning] {
        ownClub(override: override) == nil && allPlayers.contains { $0.loanedTo != nil } ? [.ownClubUnknown] : []
    }
}
