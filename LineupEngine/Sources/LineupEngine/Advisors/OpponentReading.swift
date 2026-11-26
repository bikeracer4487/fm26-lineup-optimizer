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
    /// The day the owner's side was measured when the reading was carried to another fixture from an earlier paste of
    /// their squad (`OpponentAdvisor.carry`); nil when both sides were measured at the paste. Absent in readings saved
    /// before it, which were all pasted.
    public let ownDay: Day?

    public var theirAverage: Double { Double(theirTotal) / 11 }
    public var ownAverage: Double { Double(ownTotal) / 11 }

    public init(club: String, day: Day, theirTotal: Int, ownTotal: Int, strength: OpponentStrength, awayOnLoanAt: [String],
                ownDay: Day? = nil) {
        self.club = club; self.day = day; self.theirTotal = theirTotal; self.ownTotal = ownTotal
        self.strength = strength; self.awayOnLoanAt = awayOnLoanAt; self.ownDay = ownDay
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
        let lines = try checkedLines(parameters)
        guard !own.isEmpty else { throw OpponentReadingError.noOwnSquad }
        let ownIDs = Set(own.map(\.id))
        let shared = theirs.filter { ownIDs.contains($0.id) }.count
        guard shared * 2 <= theirs.count else { throw OpponentReadingError.ownSquadPasted }
        // Rows that carry the owner's own club are his squad, whatever keys they have.
        if let ownClub, let rowsClub = SquadBook.commonClub(among: theirs),
           PlayerID.normalise(rowsClub) == PlayerID.normalise(ownClub) {
            throw OpponentReadingError.ownSquadPasted
        }

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

        let strength = Self.strength(theirTotal: theirTotal, ownTotal: ownTotal, lines: lines)

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

    /// An earlier reading carried to another fixture against the same club: their side as it was pasted, the owner's
    /// measured again from `own` on `day`, and the strength from the two. The reading keeps the day their squad was
    /// pasted and says the day the owner's was measured (`ownDay`). Throws as `read` does for the owner's side and
    /// the lines.
    public static func carry(_ earlier: OpponentReading, own: [Player], ownClub: String?, on day: Day,
                             parameters: EngineParameters) throws -> OpponentReading {
        let lines = try checkedLines(parameters)
        guard !own.isEmpty else { throw OpponentReadingError.noOwnSquad }
        let ownTotal = try bestElevenTotal(own, club: ownClub, side: .own)
        return OpponentReading(club: earlier.club, day: earlier.day, theirTotal: earlier.theirTotal, ownTotal: ownTotal,
                               strength: strength(theirTotal: earlier.theirTotal, ownTotal: ownTotal, lines: lines),
                               awayOnLoanAt: earlier.awayOnLoanAt, ownDay: day)
    }

    /// The strength lines, when they are `0 < stronger < much stronger < 100`.
    private static func checkedLines(_ parameters: EngineParameters) throws -> OpponentStrengthLines {
        let lines = parameters.opponentStrengthLines.value
        let s = lines.strongerFromPercent, m = lines.muchStrongerFromPercent
        guard 0 < s, s < m, m < 100 else {
            throw PlanError.badParameters([
                "opponentStrengthLines has lines of \(s) and \(m) percent, which are not 0 < stronger < much stronger < 100"])
        }
        return lines
    }

    private static func strength(theirTotal: Int, ownTotal: Int, lines: OpponentStrengthLines) -> OpponentStrength {
        let s = lines.strongerFromPercent, m = lines.muchStrongerFromPercent
        if theirTotal * 100 >= ownTotal * (100 + m) { return .muchStronger }
        if theirTotal * 100 >= ownTotal * (100 + s) { return .stronger }
        if theirTotal * 100 <= ownTotal * (100 - m) { return .muchWeaker }
        if theirTotal * 100 <= ownTotal * (100 - s) { return .weaker }
        return .similar
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
