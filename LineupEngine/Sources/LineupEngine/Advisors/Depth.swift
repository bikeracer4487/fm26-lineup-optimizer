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
    /// Why he cannot play today (at medium importance); nil when he can. Only an injury stops him counting as cover.
    public let unavailable: Exclusion?
    /// His place in the squad's tiers; nil for a player out on loan.
    public let tier: SquadTier?
    /// The other slots where he is first or second choice.
    public let alsoNeededAt: [SlotID]
    /// He rates under `depthCoverShare` of the slot's first choice's rating there: too far below him to count as cover,
    /// however familiar he is. Never the first choice himself, and never at a slot with no first choice.
    public let isBelowCoverShare: Bool
    /// He could step in at the slot, whatever his rating: solid, not injured and not first choice at another slot.
    /// Player Removal keeps a stand-in the slot would be short without, even one too weak to count as cover.
    public let isStandIn: Bool
    /// He counts towards the slot's `cover`: a stand-in who is not below the cover share. Player Removal protects real
    /// cover by the same rule.
    public let countsAsCover: Bool
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
    /// Options that are solid, not injured, not first choice at another slot and within `depthCoverShare` of the first
    /// choice's rating: how many real options there are if someone is injured, not who can play today.
    public let cover: Int
    /// Options who could step in whatever their rating (`DepthOption.isStandIn`): never fewer than `cover`.
    public let standIns: Int
    public let isThin: Bool
    /// The first choice's rating in this slot minus the highest rating among the slot's other options who could step
    /// in (not injured and not first choice at another slot); nil when the slot has no first choice or no such option.
    public let dropToNextBest: Double?
    /// The option `dropToNextBest` is measured to; nil when it is.
    public let nextBest: PlayerID?
}

public struct DepthReport: Equatable, Sendable {
    /// In slot order.
    public let slots: [SlotDepth]
    /// The thin slots, most in need first: least cover, then the larger drop to the next best (nobody who could step in
    /// counts as the largest), then slot order.
    public let thin: [SlotID]
    /// The weakest evidence among the parameters behind this advice.
    public let basis: Evidence
}

public enum Depth {
    /// Whether an exclusion stops an option counting as cover. An injury or a loan elsewhere does; a ban, condition or
    /// jadedness on the wrong side of its line today does not, since the planner decides who can play today.
    /// `.rejected` is never produced by `RiskRules` and is treated like the short-term ones.
    static func stopsCover(_ exclusion: Exclusion?) -> Bool {
        guard let exclusion else { return false }
        switch exclusion {
        case .injured, .outOnLoan: return true
        case .banned, .belowConditionFloor, .jaded, .rejected: return false
        }
    }

    /// Whether a player could step in at `slot`: nothing stops him counting as cover, and he is not first choice at
    /// another slot.
    static func canStepIn(unavailable: Exclusion?, tier: SquadTier?, at slot: SlotID) -> Bool {
        guard !stopsCover(unavailable) else { return false }
        if case .first(let other) = tier, other != slot { return false }
        return true
    }

    /// Depth's cover test: solid at the slot (`depthSolidFamiliarity` in both phases), and rated at least
    /// `depthCoverShare` of the first choice's rating there; with no first choice there is no such line. Whether he is
    /// injured or first choice at another slot is asked apart (`canStepIn`).
    static func isCover(isSolid: Bool, rating: Double, firstChoiceRating: Double?, parameters: EngineParameters) -> Bool {
        isSolid && isWithinCoverShare(rating: rating, firstChoiceRating: firstChoiceRating, parameters: parameters)
    }

    /// The cover share alone: at or over `depthCoverShare` of the first choice's rating, or no first choice.
    static func isWithinCoverShare(rating: Double, firstChoiceRating: Double?, parameters: EngineParameters) -> Bool {
        firstChoiceRating.map { rating >= $0 * parameters.depthCoverShare.value } ?? true
    }

    /// Throws what `Elevens.report` throws, and `RatingError` for a player with missing data.
    public static func report(tactic: Tactic, players: [Player], ownClub: String?, catalog: RoleCatalog,
                              profile: RatingProfile, parameters: EngineParameters) throws -> DepthReport {
        let elevens = try Elevens.report(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                                         profile: profile, parameters: parameters)
        return try report(tactic: tactic, players: players, ownClub: ownClub, elevens: elevens, catalog: catalog,
                          profile: profile, parameters: parameters)
    }

    /// The same, from `elevens` already worked out for `tactic` and these players, so they are not solved again.
    /// Throws `RatingError` for a player with missing data.
    static func report(tactic: Tactic, players: [Player], ownClub: String?, elevens: ElevensReport, catalog: RoleCatalog,
                       profile: RatingProfile, parameters: EngineParameters) throws -> DepthReport {
        let tiers = elevens.tiers
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
            // The first choice's rating here, which cover is measured against; nil with none.
            let firstRating: Double? = tiers.first[assignment.slot].flatMap { tiers.ratings[$0]?[assignment.slot] }
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
                let isSolid = ip >= solidFrom && oop >= solidFrom
                let unavailable = RiskRules.exclusion(for: player, loan: loan, importance: .medium,
                                                      isNextFixture: true, parameters: parameters)
                let rating = try engine.rating(for: player, in: assignment).value
                let canStep = canStepIn(unavailable: unavailable, tier: tier, at: assignment.slot)
                // The first choice himself is never below his own share.
                let isFirst = tier == .first(assignment.slot)
                let isBelowShare = !isFirst
                    && !isWithinCoverShare(rating: rating, firstChoiceRating: firstRating, parameters: parameters)
                let option = DepthOption(
                    player: player.id, name: player.name, squad: player.squad, rating: rating,
                    ipFamiliarity: ip, oopFamiliarity: oop, isSolid: isSolid, unavailable: unavailable,
                    tier: tier, alsoNeededAt: also, isBelowCoverShare: isBelowShare,
                    isStandIn: isSolid && canStep,
                    countsAsCover: canStep && isCover(isSolid: isSolid, rating: rating,
                                                      firstChoiceRating: isFirst ? nil : firstRating,
                                                      parameters: parameters))
                if case .loanedOut = loan { onLoan.append(option) } else { options.append(option) }
            }
            func ranked(_ list: [DepthOption]) -> [DepthOption] {
                list.sorted { $0.rating != $1.rating ? $0.rating > $1.rating : $0.player.key < $1.player.key }
            }
            options = ranked(options)
            onLoan = ranked(onLoan)

            let cover = options.filter(\.countsAsCover).count

            var drop: Double?
            var nextBest: PlayerID?
            if let first = tiers.first[assignment.slot], let firstRating = tiers.ratings[first]?[assignment.slot],
               let next = options.first(where: {
                   $0.player != first && canStepIn(unavailable: $0.unavailable, tier: $0.tier, at: assignment.slot)
               }) {
                drop = firstRating - next.rating
                nextBest = next.player
            }
            slots.append(SlotDepth(slot: assignment.slot, ipPosition: assignment.ipPosition,
                                   oopPosition: assignment.oopPosition, options: options, onLoan: onLoan,
                                   cover: cover, standIns: options.filter(\.isStandIn).count,
                                   isThin: cover < parameters.depthThinBelow.value, dropToNextBest: drop,
                                   nextBest: nextBest))
        }

        // Ties fall back to the slot's index in `slots`, the tactic's slot order.
        let thin = slots.enumerated().filter { $0.element.isThin }.sorted { a, b in
            if a.element.cover != b.element.cover { return a.element.cover < b.element.cover }
            let da = a.element.dropToNextBest ?? .infinity, db = b.element.dropToNextBest ?? .infinity
            if da != db { return da > db }
            return a.offset < b.offset
        }.map(\.element.slot)
        let basis = Evidence.weakest([parameters.depthCoverFamiliarity.evidence, parameters.depthSolidFamiliarity.evidence,
                                      parameters.depthThinBelow.evidence, parameters.depthCoverShare.evidence])!
        return DepthReport(slots: slots, thin: thin, basis: basis)
    }
}
