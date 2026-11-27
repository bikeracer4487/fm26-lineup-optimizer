import Foundation

/// One step of the decline table: from this age, a season costs this many points of ability.
public struct DeclineStep: Equatable, Sendable {
    public var fromAge: Int
    public var points: Double

    public init(fromAge: Int, points: Double) {
        self.fromAge = fromAge
        self.points = points
    }
}

/// How fast ability is expected to fall with age, and for how many seasons it is counted. See
/// `EngineParameters.declineRules`.
public struct DeclineRules: Equatable, Sendable {
    /// In rising order of age.
    public var steps: [DeclineStep]
    /// The seasons ahead that a player's decline is counted over.
    public var seasons: Int

    public init(steps: [DeclineStep], seasons: Int) {
        self.steps = steps
        self.seasons = seasons
    }
}

/// What the outfield first choices, in position, are measured by: the average of their ratings and of
/// (offset + current ability). Both are nil when there is no such first choice.
public struct SquadStandard: Equatable, Sendable {
    public let rating: Double?
    public let ability: Double?

    public init(rating: Double?, ability: Double?) {
        self.rating = rating
        self.ability = ability
    }
}

/// The ability a player is measured at over a new contract.
public enum WorthAhead: Equatable, Sendable {
    /// He is over `developingUpToAge` and no fall is expected: his ability today.
    case today
    /// He is `developingUpToAge` or under: his reach (`Reach.estimate`), this tool's estimate.
    case reach(Double)
    /// A fall is expected: his ability after `seasons` seasons of decline (`declineRules`), this tool's estimate.
    case decline(to: Double, seasons: Int)
}

/// What a player of the club's own is worth against the first eleven's standard, at the slot where he is worth most.
public struct RenewalWorth: Equatable, Sendable {
    public let player: PlayerID
    public let slot: SlotID
    /// The goalkeeper's slot, measured by ability, since a goalkeeper's rating is on its own scale.
    public let isGoalkeeperSlot: Bool
    public let age: Int
    public let ability: Int
    public let ahead: WorthAhead
    /// His share of the standard today, at `slot`: 0.936 for 6.4% under.
    public let shareToday: Double
    /// His share over a new contract: what he is ordered and judged by.
    public let share: Double
    /// `share` clears the weak line (`Scouting.clearsWeakLine`), so a share exactly 5% under does not.
    public let meetsStandard: Bool
    /// The weakest evidence among the parameters behind it.
    public let basis: Evidence

    public init(player: PlayerID, slot: SlotID, isGoalkeeperSlot: Bool, age: Int, ability: Int, ahead: WorthAhead,
                shareToday: Double, share: Double, meetsStandard: Bool, basis: Evidence) {
        self.player = player
        self.slot = slot
        self.isGoalkeeperSlot = isGoalkeeperSlot
        self.age = age
        self.ability = ability
        self.ahead = ahead
        self.shareToday = shareToday
        self.share = share
        self.meetsStandard = meetsStandard
        self.basis = basis
    }
}

/// Who is worth renewing: the standard a player is held to and the decline he is expected to suffer.
public enum Renewal {
    /// The goalkeeper's slot, whose ratings are on their own scale: its in-possession position is the goalkeeper's.
    private static func isGoalkeeperSlot(_ slot: SlotDepth) -> Bool { slot.ipPosition == .goalkeeper }

    /// Sentences naming what is wrong with the decline rules; none when they are sound.
    static func problems(in rules: DeclineRules) -> [String] {
        var found: [String] = []
        if rules.steps.isEmpty { found.append("declineRules has no steps") }
        for step in rules.steps where !step.points.isFinite || step.points < 0 {
            found.append("declineRules step from age \(step.fromAge) is \(step.points), not a number of 0 or more")
        }
        for (earlier, later) in zip(rules.steps, rules.steps.dropFirst()) where later.fromAge <= earlier.fromAge {
            found.append("declineRules steps do not rise in age: \(later.fromAge) follows \(earlier.fromAge)")
        }
        if rules.seasons < 1 { found.append("declineRules seasons is \(rules.seasons), not 1 or more") }
        return found
    }

    /// The points lost in a season begun at `age`: the last step whose `fromAge` is at or under it, else 0.
    static func fall(at age: Int, rules: DeclineRules) -> Double {
        rules.steps.last { $0.fromAge <= age }?.points ?? 0
    }

    /// Ability after `rules.seasons` seasons begun at `age`, `age + 1`, …; never below 0.
    static func abilityAfterDecline(_ ability: Int, age: Int, rules: DeclineRules) -> Double {
        var value = Double(ability)
        for season in 0..<max(rules.seasons, 0) {
            value -= fall(at: age + season, rules: rules)
        }
        return max(value, 0)
    }

    /// The averages the first choices are measured by: the outfield slots whose first choice is in position, taken in
    /// the order of `depth.slots`.
    public static func standard(elevens: ElevensReport, depth: DepthReport, players: [Player],
                                parameters: EngineParameters) -> SquadStandard {
        let offset = parameters.ratingAbilityOffset.value
        let byID = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var ratings: [Double] = []
        var abilities: [Double] = []
        for slot in depth.slots where !isGoalkeeperSlot(slot) {
            guard let place = elevens.first.first(where: { $0.slot == slot.slot }), !place.isOutOfPosition,
                  let player = byID[place.player] else { continue }
            ratings.append(place.rating.value)
            abilities.append(offset + Double(player.currentAbility))
        }
        return SquadStandard(
            rating: ratings.isEmpty ? nil : ratings.reduce(0, +) / Double(ratings.count),
            ability: abilities.isEmpty ? nil : abilities.reduce(0, +) / Double(abilities.count))
    }

    /// The worth of every player of the club's own, here or out on loan, who can play a slot (familiarity 10 or over in
    /// both phases, as `depth` lists him), at the slot where his share is highest, the earlier in `depth.slots` on a
    /// tie. Players on loan at the club get none, and with no standard nobody has one.
    ///
    /// His ability over a new contract is his reach at `developingUpToAge` or under, else his ability after the decline
    /// expected (`abilityAfterDecline`). At an outfield slot his rating is taken to grow or fall with it from the offset
    /// (`ratingAbilityOffset`) and set against the standard's rating; when it rises past today's he is also measured by
    /// ability, (offset + reach) against the standard's, and the share is the lower of the two. The goalkeeper's slot
    /// is measured by ability alone. Throws `RatingError.missingAttribute` for a young player without what his reach
    /// needs.
    public static func worths(players: [Player], ownClub: String?, elevens: ElevensReport, depth: DepthReport,
                              parameters: EngineParameters) throws -> [PlayerID: RenewalWorth] {
        let standard = standard(elevens: elevens, depth: depth, players: players, parameters: parameters)
        guard let standardRating = standard.rating, let standardAbility = standard.ability else { return [:] }
        let offset = parameters.ratingAbilityOffset.value
        let byID = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let common = [parameters.scoutingWeakShare.evidence, parameters.ratingAbilityOffset.evidence]

        // Each player's ratings at the slots he can play, in the order of `depth.slots`.
        var ratings: [PlayerID: [(slot: SlotDepth, rating: Double)]] = [:]
        for slot in depth.slots {
            for option in slot.options + slot.onLoan { ratings[option.player, default: []].append((slot, option.rating)) }
        }

        var worths: [PlayerID: RenewalWorth] = [:]
        for (id, slots) in ratings.sorted(by: { $0.key.key < $1.key.key }) {
            guard let player = byID[id] else { continue }
            if case .loanedIn = LoanStatus.of(player, ownClub: ownClub) { continue }
            let ability = Double(player.currentAbility)
            let ahead: WorthAhead
            let abilityAhead: Double
            var evidence = common
            if player.age <= parameters.developingUpToAge.value {
                let reach = try Reach.estimate(for: player, parameters: parameters).reach
                ahead = .reach(reach)
                abilityAhead = reach
                evidence += [parameters.growthPerSeason.evidence, parameters.growthProfessionalismRates.evidence]
            } else {
                let rules = parameters.declineRules.value
                let after = abilityAfterDecline(player.currentAbility, age: player.age, rules: rules)
                abilityAhead = after
                if after < ability {
                    ahead = .decline(to: after, seasons: rules.seasons)
                    evidence.append(parameters.declineRules.evidence)
                } else {
                    ahead = .today
                }
            }

            // His share at a slot with his ability over the contract at `x`.
            func share(_ slot: SlotDepth, rating: Double, at x: Double) -> Double {
                let byAbility = (offset + x) / standardAbility
                if isGoalkeeperSlot(slot) { return byAbility }
                // The ratio first, so a share at today's ability is his rating over the standard exactly.
                let byRating = rating * ((offset + x) / (offset + ability)) / standardRating
                return x > ability ? min(byRating, byAbility) : byRating
            }

            var best: RenewalWorth?
            for (slot, rating) in slots {
                let over = share(slot, rating: rating, at: abilityAhead)
                if let best, over <= best.share + Scouting.roundingNoise { continue }
                best = RenewalWorth(
                    player: id, slot: slot.slot, isGoalkeeperSlot: isGoalkeeperSlot(slot), age: player.age,
                    ability: player.currentAbility, ahead: ahead, shareToday: share(slot, rating: rating, at: ability),
                    share: over, meetsStandard: Scouting.clearsWeakLine(over, average: 1, parameters: parameters),
                    basis: Evidence.weakest(evidence)!)
            }
            worths[id] = best
        }
        return worths
    }
}
