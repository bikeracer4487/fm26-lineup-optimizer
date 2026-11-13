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

    /// Replaces the squad with the import. Each incoming player's key is decided by the first rule
    /// that matches, `isSamePerson` deciding who is the same person:
    /// 1. the same person is in this squad: he keeps that player's key, whatever the importer gave him;
    /// 2. the same person is in another squad: he takes that key and moves here (`movedIn`);
    /// 3. otherwise his importer key, re-keyed by `freeKey` if it is held elsewhere or kept by rule 1 or 2.
    /// Rules 1 and 2 let each existing key be claimed once, by the first incoming player in paste
    /// order, and take candidates in `allPlayers` order. A name held under more than one key is
    /// reported by `warnings(override:)`.
    @discardableResult
    public mutating func apply(_ result: ImportResult, to squad: Squad) -> SquadChange {
        let old = current[squad] ?? []
        let elsewhere = Self.bookOrder.filter { $0 != squad }.flatMap { other in (current[other] ?? []).map { (squad: other, player: $0) } }
        var incoming = result.players
        var claimed: Set<PlayerID> = []
        var movedFrom: [Squad: Set<PlayerID>] = [:]
        var movedIn: [PlayerID] = []
        var unmatched: [Int] = []
        for i in incoming.indices {
            incoming[i].squad = squad
            func unclaimedSamePerson(_ existing: Player) -> Bool {
                !claimed.contains(existing.id) && Self.isSamePerson(existing, incoming[i])
            }
            if let stays = old.first(where: unclaimedSamePerson) {
                incoming[i].id = stays.id
            } else if let mover = elsewhere.first(where: { unclaimedSamePerson($0.player) }) {
                incoming[i].id = mover.player.id
                movedFrom[mover.squad, default: []].insert(mover.player.id)
                movedIn.append(mover.player.id)
            } else {
                unmatched.append(i)
                continue
            }
            claimed.insert(incoming[i].id)
        }
        let taken = claimed.union(elsewhere.map(\.player.id))
        var used = claimed.union(result.players.map(\.id))
        for i in unmatched {
            let id = Self.freeKey(for: incoming[i], taken: taken, used: used)
            used.insert(id)
            incoming[i].id = id
        }

        let oldByID = Dictionary(old.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let newIDs = Set(incoming.map(\.id))
        let change = SquadChange(
            added: incoming.map(\.id).filter { oldByID[$0] == nil },
            removed: old.map(\.id).filter { !newIDs.contains($0) },
            movedIn: movedIn,
            changed: incoming.filter { player in oldByID[player.id].map { $0 != player } ?? false }.map(\.id)
        )

        for (other, ids) in movedFrom {
            current[other]?.removeAll { ids.contains($0.id) }
        }
        if current[squad] != nil { previous[squad] = old }
        current[squad] = incoming
        return change
    }

    /// The key for an incoming player who is not the same person as anyone in the book (rule 3).
    /// Keys are tried in order: his own, `#<potential ability>`, `#<first nationality>`, then `#1`,
    /// `#2` and so on. His own key wins unless `taken` (held in another squad, or kept by rule 1
    /// or 2); a later key also must not be `used` by another player in this import.
    private static func freeKey(for player: Player, taken: Set<PlayerID>, used: Set<PlayerID>) -> PlayerID {
        if !taken.contains(player.id) { return player.id }
        let potential = PlayerID.withPotential(player.id.key, of: player)
        let nationality = PlayerID.withNationality(potential, of: player)
        let free = { (key: String) in !taken.contains(PlayerID(key: key)) && !used.contains(PlayerID(key: key)) }
        if let key = [potential, nationality].first(where: free) { return PlayerID(key: key) }
        var position = 1
        while !free("\(nationality)#\(position)") { position += 1 }
        return PlayerID(key: "\(nationality)#\(position)")
    }

    /// One person: equal names once `PlayerID.normalise`d, equal potential ability, equal nationalities.
    private static func isSamePerson(_ a: Player, _ b: Player) -> Bool {
        PlayerID.normalise(a.name) == PlayerID.normalise(b.name)
            && a.potentialAbility == b.potentialAbility && a.nationalities == b.nationalities
    }

    /// The order of `allPlayers`, which also decides which existing player an incoming one matches.
    private static let bookOrder: [Squad] = [.firstTeam, .u21, .u18]

    /// First team, then U21, then U18, each in import order.
    public var allPlayers: [Player] {
        Self.bookOrder.flatMap { current[$0] ?? [] }
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
