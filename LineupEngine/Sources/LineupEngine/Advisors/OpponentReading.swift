import Foundation

/// What a pasted opponent squad was found to be worth beside the owner's. The players themselves are not kept.
public struct OpponentReading: Equatable, Codable, Sendable {
    /// Their club's name as used: from the rows, or as the owner typed it.
    public let club: String
    /// The game's date when it was pasted.
    public let day: Day
    /// Current ability summed over their best eleven.
    public let theirTotal: Int
    /// The same for the owner's.
    public let ownTotal: Int
    public let strength: OpponentStrength
    /// The clubs their left-out players are at: each once, as first spelt, A to Z.
    public let awayOnLoanAt: [String]

    public var theirAverage: Double { Double(theirTotal) / 11 }
    public var ownAverage: Double { Double(ownTotal) / 11 }

    public init(club: String, day: Day, theirTotal: Int, ownTotal: Int, strength: OpponentStrength, awayOnLoanAt: [String]) {
        self.club = club; self.day = day; self.theirTotal = theirTotal; self.ownTotal = ownTotal
        self.strength = strength; self.awayOnLoanAt = awayOnLoanAt
    }
}

public enum OpponentSide: Equatable, Sendable { case theirs(club: String), own }

public enum OpponentReadingError: Error, Equatable, Sendable {
    case noOwnSquad
    case ownSquadPasted
    case noClubName
    case tooFewPlayers(OpponentSide, found: Int)
}

/// The two lines, as whole percentages of the owner's best-eleven total, between similar and stronger (or weaker) and
/// between those and much stronger (or much weaker).
public struct OpponentStrengthLines: Sendable, Equatable {
    public var strongerFromPercent: Int
    public var muchStrongerFromPercent: Int

    public init(strongerFromPercent: Int, muchStrongerFromPercent: Int) {
        self.strongerFromPercent = strongerFromPercent; self.muchStrongerFromPercent = muchStrongerFromPercent
    }
}

public enum OpponentAdvisor {
    /// `named` is the opponent as the owner typed it on the fixture, used when the rows carry no club. Throws
    /// `PlanError.badParameters` when the strength lines are not `0 < stronger < much stronger < 100`.
    public static func read(theirs: [Player], named: String, own: [Player], ownClub: String?, on day: Day,
                            parameters: EngineParameters) throws -> OpponentReading {
        let lines = parameters.opponentStrengthLines.value
        let s = lines.strongerFromPercent, m = lines.muchStrongerFromPercent
        guard 0 < s, s < m, m < 100 else {
            throw PlanError.badParameters([
                "opponentStrengthLines has lines of \(s) and \(m) percent, which are not 0 < stronger < much stronger < 100"])
        }
        guard !own.isEmpty else { throw OpponentReadingError.noOwnSquad }
        let ownIDs = Set(own.map(\.id))
        let shared = theirs.filter { ownIDs.contains($0.id) }.count
        guard shared * 2 <= theirs.count else { throw OpponentReadingError.ownSquadPasted }

        let trimmedName = named.trimmingCharacters(in: .whitespacesAndNewlines)
        let club: String
        if let common = SquadBook.commonClub(among: theirs) {
            club = common
        } else if !trimmedName.isEmpty {
            club = trimmedName
        } else {
            throw OpponentReadingError.noClubName
        }

        let theirTotal = try bestElevenTotal(theirs, club: club, side: .theirs(club: club))
        let ownTotal = try bestElevenTotal(own, club: ownClub, side: .own)

        let strength: OpponentStrength
        if theirTotal * 100 >= ownTotal * (100 + m) { strength = .muchStronger }
        else if theirTotal * 100 >= ownTotal * (100 + s) { strength = .stronger }
        else if theirTotal * 100 <= ownTotal * (100 - m) { strength = .muchWeaker }
        else if theirTotal * 100 <= ownTotal * (100 - s) { strength = .weaker }
        else { strength = .similar }

        var firstSpelt: [String: String] = [:]
        for player in theirs {
            if case .loanedOut(let to) = LoanStatus.of(player, ownClub: club) {
                let key = PlayerID.normalise(to)
                if firstSpelt[key] == nil { firstSpelt[key] = to }
            }
        }
        let away = firstSpelt.values.sorted()
        return OpponentReading(club: club, day: day, theirTotal: theirTotal, ownTotal: ownTotal,
                               strength: strength, awayOnLoanAt: away)
    }

    /// Current ability summed over the eleven highest among the players who are not injured and not out on loan.
    private static func bestElevenTotal(_ players: [Player], club: String?, side: OpponentSide) throws -> Int {
        let available = players.filter { player in
            if player.isInjured { return false }
            if case .loanedOut = LoanStatus.of(player, ownClub: club) { return false }
            return true
        }
        guard available.count >= 11 else { throw OpponentReadingError.tooFewPlayers(side, found: available.count) }
        return available.map(\.currentAbility).sorted(by: >).prefix(11).reduce(0, +)
    }
}
