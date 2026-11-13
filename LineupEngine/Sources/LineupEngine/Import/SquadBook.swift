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
    /// More than one player in the book has this name, each under his own key.
    case sharedName(String)
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

    /// Replaces the squad with the import. An incoming key already held in another squad is the
    /// same person, who moves here, only when potential ability and nationalities are equal;
    /// otherwise the player elsewhere keeps his key and squad and the incoming player is re-keyed
    /// (see `identity(of:elsewhere:used:)`), and `warnings(override:)` reports the shared name.
    @discardableResult
    public mutating func apply(_ result: ImportResult, to squad: Squad) -> SquadChange {
        let elsewhere = Dictionary(Squad.allCases.filter { $0 != squad }.flatMap { current[$0] ?? [] }.map { ($0.id, $0) },
                                   uniquingKeysWith: { first, _ in first })
        var incoming = result.players
        var used = Set(incoming.map(\.id))
        var movedIn: [PlayerID] = []
        for i in incoming.indices {
            incoming[i].squad = squad
            let (id, moves) = Self.identity(of: incoming[i], elsewhere: elsewhere, used: used)
            used.insert(id)
            incoming[i].id = id
            if moves { movedIn.append(id) }
        }

        let old = current[squad] ?? []
        let oldByID = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let newIDs = Set(incoming.map(\.id))
        let change = SquadChange(
            added: incoming.map(\.id).filter { oldByID[$0] == nil },
            removed: old.map(\.id).filter { !newIDs.contains($0) },
            movedIn: movedIn,
            changed: incoming.filter { player in oldByID[player.id].map { $0 != player } ?? false }.map(\.id)
        )

        let moved = Set(movedIn)
        for other in Squad.allCases where other != squad {
            current[other]?.removeAll { moved.contains($0.id) }
        }
        if current[squad] != nil { previous[squad] = old }
        current[squad] = incoming
        return change
    }

    /// The incoming player's key, and whether he moves from another squad. Keys are tried in
    /// order: his own, `#<potential ability>`, `#<first nationality>`, then `#1`, `#2` and so on.
    /// The first key held elsewhere by the same person (a move), or held by no one, wins; a key
    /// held elsewhere by someone else, or already used by another player in this import, is skipped.
    private static func identity(of player: Player, elsewhere: [PlayerID: Player], used: Set<PlayerID>) -> (PlayerID, moves: Bool) {
        func attempt(_ key: String, isOwn: Bool) -> (PlayerID, moves: Bool)? {
            let id = PlayerID(key: key)
            if let holder = elsewhere[id] { return isSamePerson(holder, player) ? (id, true) : nil }
            return isOwn || !used.contains(id) ? (id, false) : nil
        }
        if let found = attempt(player.id.key, isOwn: true) { return found }
        let potential = PlayerID.withPotential(player.id.key, of: player)
        let nationality = PlayerID.withNationality(potential, of: player)
        for key in [potential, nationality] {
            if let found = attempt(key, isOwn: false) { return found }
        }
        var position = 1
        while true {
            if let found = attempt("\(nationality)#\(position)", isOwn: false) { return found }
            position += 1
        }
    }

    /// Two players with one key are one person when neither potential ability nor nationalities differ.
    private static func isSamePerson(_ a: Player, _ b: Player) -> Bool {
        a.potentialAbility == b.potentialAbility && a.nationalities == b.nationalities
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

    /// `ownClubUnknown` first, then one `sharedName` for each name held under more than one key,
    /// in `allPlayers` order and spelt as first seen there.
    public func warnings(override: String?) -> [SquadWarning] {
        var found: [SquadWarning] = []
        if ownClub(override: override) == nil && allPlayers.contains(where: { $0.loanedTo != nil }) {
            found.append(.ownClubUnknown)
        }
        var keysByName: [String: Set<PlayerID>] = [:]
        var names: [(normalised: String, spelling: String)] = []
        for player in allPlayers {
            let normalised = PlayerID.normalise(player.name)
            if keysByName[normalised] == nil { names.append((normalised, player.name)) }
            keysByName[normalised, default: []].insert(player.id)
        }
        found += names.filter { keysByName[$0.normalised]!.count > 1 }.map { .sharedName($0.spelling) }
        return found
    }
}
