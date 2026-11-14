import Foundation

/// One player who could cover a slot, with how well he fits it and whether he is already needed elsewhere.
public struct DepthOption: Equatable, Sendable {
    public let player: PlayerID
    public let name: String
    public let squad: Squad
    /// Full-fitness slot rating: condition, sharpness and jadedness play no part.
    public let rating: Double
    public let ipFamiliarity: Int
    public let oopFamiliarity: Int
    /// Both familiarities are at or above `depthSolidFamiliarity`.
    public let isSolid: Bool
    /// Why he cannot play today (at medium importance); nil when he can.
    public let unavailable: Exclusion?
    /// His place in the squad's tiers; nil for a player out on loan.
    public let tier: SquadTier?
    /// The other slots where he is first or second choice.
    public let alsoNeededAt: [SlotID]
}

/// Who can cover one slot of the tactic, and whether the cover is thin.
public struct SlotDepth: Equatable, Sendable {
    public let slot: SlotID
    public let ipPosition: Position
    public let oopPosition: Position
    /// Best first.
    public let options: [DepthOption]
    /// Players out on loan who would qualify, ranked the same way.
    public let onLoan: [DepthOption]
    /// Options that are solid, available today and not first choice at another slot.
    public let cover: Int
    public let isThin: Bool
    /// The first choice's rating in this slot minus the second choice's; nil without both.
    public let dropToSecond: Double?
}

public struct DepthReport: Equatable, Sendable {
    /// In slot order.
    public let slots: [SlotDepth]
    /// The thin slots, most in need first: least cover, then the larger drop to second (no second choice
    /// counts as the largest), then slot order.
    public let thin: [SlotID]
}

public enum Depth {
    /// Throws what `Elevens.report` throws, and `RatingError` for a player with missing data.
    public static func report(tactic: Tactic, players: [Player], ownClub: String?, catalog: RoleCatalog,
                              profile: RatingProfile, parameters: EngineParameters) throws -> DepthReport {
        let tiers = try Elevens.report(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                                       profile: profile, parameters: parameters).tiers
        let assignments = try tactic.assignments(catalog: catalog)
        let engine = RatingEngine(profile: profile, parameters: parameters, configuration: .fm27)
        // Sorting by key makes every list independent of input order.
        let sorted = players.sorted { $0.id.key < $1.id.key }
        let coverFrom = parameters.depthCoverFamiliarity.value
        let solidFrom = parameters.depthSolidFamiliarity.value

        func familiarity(_ player: Player, _ position: Position) throws -> Int {
            guard let value = player.familiarity[position] else {
                throw RatingError.missingFamiliarity(player: player.name, position: position)
            }
            return value
        }

        var slots: [SlotDepth] = []
        for assignment in assignments {
            var options: [DepthOption] = []
            var onLoan: [DepthOption] = []
            for player in sorted {
                let ip = try familiarity(player, assignment.ipPosition)
                let oop = try familiarity(player, assignment.oopPosition)
                guard ip >= coverFrom, oop >= coverFrom else { continue }
                let loan = LoanStatus.of(player, ownClub: ownClub)
                let tier = tiers.tier(of: player.id)
                var also: [SlotID] = []
                switch tier {
                case .first(let other), .second(let other): if other != assignment.slot { also = [other] }
                case .backup, nil: break
                }
                let option = DepthOption(
                    player: player.id, name: player.name, squad: player.squad,
                    rating: try engine.rating(for: player, in: assignment).value,
                    ipFamiliarity: ip, oopFamiliarity: oop, isSolid: ip >= solidFrom && oop >= solidFrom,
                    unavailable: RiskRules.exclusion(for: player, loan: loan, importance: .medium,
                                                     isNextFixture: true, parameters: parameters),
                    tier: tier, alsoNeededAt: also)
                if case .loanedOut = loan { onLoan.append(option) } else { options.append(option) }
            }
            func ranked(_ list: [DepthOption]) -> [DepthOption] {
                list.sorted { $0.rating != $1.rating ? $0.rating > $1.rating : $0.player.key < $1.player.key }
            }
            options = ranked(options)
            onLoan = ranked(onLoan)

            let cover = options.filter { option in
                guard option.isSolid, option.unavailable == nil else { return false }
                if case .first(let other) = option.tier, other != assignment.slot { return false }
                return true
            }.count

            var drop: Double?
            if let first = tiers.first[assignment.slot], let second = tiers.second[assignment.slot],
               let firstRating = tiers.ratings[first]?[assignment.slot],
               let secondRating = tiers.ratings[second]?[assignment.slot] {
                drop = firstRating - secondRating
            }
            slots.append(SlotDepth(slot: assignment.slot, ipPosition: assignment.ipPosition,
                                   oopPosition: assignment.oopPosition, options: options, onLoan: onLoan,
                                   cover: cover, isThin: cover < parameters.depthThinBelow.value, dropToSecond: drop))
        }

        let order = Dictionary(uniqueKeysWithValues: SlotID.allCases.enumerated().map { ($1, $0) })
        let thin = slots.filter(\.isThin).sorted { a, b in
            if a.cover != b.cover { return a.cover < b.cover }
            let da = a.dropToSecond ?? .infinity, db = b.dropToSecond ?? .infinity
            if da != db { return da > db }
            return order[a.slot]! < order[b.slot]!
        }.map(\.slot)
        return DepthReport(slots: slots, thin: thin)
    }
}
