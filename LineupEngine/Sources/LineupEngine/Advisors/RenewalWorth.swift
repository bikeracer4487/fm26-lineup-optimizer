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

/// Who is worth renewing: the standard a player is held to and the decline he is expected to suffer.
public enum Renewal {
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
        for slot in depth.slots where slot.ipPosition != .goalkeeper {
            guard let place = elevens.first.first(where: { $0.slot == slot.slot }), !place.isOutOfPosition,
                  let player = byID[place.player] else { continue }
            ratings.append(place.rating.value)
            abilities.append(offset + Double(player.currentAbility))
        }
        return SquadStandard(
            rating: ratings.isEmpty ? nil : ratings.reduce(0, +) / Double(ratings.count),
            ability: abilities.isEmpty ? nil : abilities.reduce(0, +) / Double(abilities.count))
    }
}
