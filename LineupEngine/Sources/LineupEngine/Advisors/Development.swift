import Foundation

/// When a young player's rating at a slot is expected to pass the first choice's.
public enum ReachBand: String, CaseIterable, Sendable {
    /// Ahead today or within one season.
    case close
    /// First ahead before `onCourseBeforeAge`.
    case onCourse
    /// His potential is high enough, but he gets there later, or his reach falls short.
    case possible
    /// His potential, as a rating, is below what the first choice is compared at, or his potential is below the first
    /// choice's compared ability; or so against a second choice who overtakes the first.
    case notExpected
}

/// How far a young player's reach could take him at a slot, best first.
public enum ReachLevel: String, CaseIterable, Sendable {
    case couldPassFirst, couldMakeSecond, couldBeCover, markedlyLower
}

/// The player a young player is compared with at a slot.
public struct Rival: Equatable, Sendable {
    public let player: PlayerID
    public let name: String
    public let age: Int
    /// His rating at the slot today.
    public let rating: Double
    /// What the young player must reach: when the rival is developing too, his own reach rating (`rating` scaled from
    /// his ability to his reach, as `SlotOutlook.reachRating` is); `rating` otherwise.
    public let compared: Double
    /// His current ability.
    public let ability: Int
    /// The ability the young player must reach, beside `compared`: when the rival is developing too, his own reach;
    /// `ability` otherwise. A young player whose reach falls below it is not counted as passing him, whatever the
    /// ratings say (the owner's rule of 25 November 2026: a player of ability 54 and potential 72 was called on course
    /// to pass a first choice of ability 83).
    public let comparedAbility: Double
    /// He is at least `firstChoiceAgeNamedFrom`, so the words name his age.
    public let isAgeNamed: Bool
}

/// A young player at one slot he can play.
public struct SlotOutlook: Equatable, Sendable {
    public let slot: SlotID
    /// His full-fitness rating there today.
    public let rating: Double
    /// `rating` scaled from his current ability to his reach: `rating` × (offset + reach) ÷ (offset + current ability),
    /// the offset being `ratingAbilityOffset`, since a rating grows with ability from an offset, not in proportion.
    public let reachRating: Double
    /// He is the first choice at this slot.
    public let isFirstChoice: Bool
    /// nil when he is it, or the slot has none.
    public let firstChoice: Rival?
    /// nil when he is it, or the slot has none.
    public let secondChoice: Rival?
    /// nil when `firstChoice` is nil.
    public let band: ReachBand?
    /// The ability points that would bring his rating level with the first choice's today under the same scaling:
    /// (offset + current ability) × (the first choice's rating ÷ his − 1), rounded up; nil with no first choice or a
    /// rating of 0 here, 0 when already level.
    public let pointsNeeded: Int?
    /// nil when `firstChoice` is nil.
    public let level: ReachLevel?
}

/// A young player's reach against the first and second choice at each slot of a tactic he can play.
public struct Outlook: Equatable, Sendable {
    public let player: PlayerID
    public let estimate: ReachEstimate
    /// The slots he can play, in the tactic's order.
    public let slots: [SlotOutlook]
    /// Among his slots with a first choice who is not him: the one with the best level; among those, the one where
    /// `reachRating` ÷ `firstChoice.compared` is greatest; then the earlier slot.
    public let best: SlotOutlook?
    /// `best`'s level. With no `best` and no slot he is first choice at, from his reach against `average`; nil when the
    /// only slots without a level are ones he is first choice at.
    public let level: ReachLevel?
    /// The first team's average ability he was compared with, when his level comes from it and there is one.
    public let average: Double?
    /// He is first choice at a slot he can play: having more positions never makes a first choice less worth developing.
    public var isFirstChoiceAtASlot: Bool { slots.contains(where: \.isFirstChoice) }
    /// His level is markedly lower and he is first choice at no slot he can play.
    public var isMarkedlyLower: Bool { level == .markedlyLower && !isFirstChoiceAtASlot }
}

/// What decided whether a young player is getting enough matches here.
public enum MatchesHereBasis: String, CaseIterable, Sendable {
    /// He is first choice at a slot: enough, whatever he started.
    case firstChoice
    /// Enough matches were confirmed to count, and he started enough of them.
    case startedEnough
    /// Enough matches were confirmed to count, and he started too few of them.
    case startedTooFew
    /// Too few matches were confirmed to count, and he is second choice at a slot he is solid at: enough.
    case solidSecondChoice
    /// Too few matches were confirmed to count, and he is not a solid second choice: not enough.
    case tooFewConfirmed
}

/// Whether a young player is getting enough matches at this club.
public struct MatchesHere: Equatable, Sendable {
    public let starts: Int
    public let matches: Int
    public let basis: MatchesHereBasis

    public init(starts: Int, matches: Int, basis: MatchesHereBasis) {
        self.starts = starts
        self.matches = matches
        self.basis = basis
    }

    /// False when too few matches were confirmed to judge by, and his place in the elevens decided it.
    public var isCounted: Bool {
        switch basis {
        case .firstChoice, .startedEnough, .startedTooFew: true
        case .solidSecondChoice, .tooFewConfirmed: false
        }
    }

    public var isEnough: Bool {
        switch basis {
        case .firstChoice, .startedEnough, .solidSecondChoice: true
        case .startedTooFew, .tooFewConfirmed: false
        }
    }
}

public enum Development {
    /// Comparisons allow for binary floating-point error, as `ImportanceRules.developmentFloor` does.
    private static let roundingNoise = 1e-9

    /// The mean current ability of the club's own first-team players; nil when there is none.
    public static func averageAbility(of players: [Player], ownClub: String?) -> Double? {
        let firstTeam = players.filter { player in
            guard player.squad == .firstTeam else { return false }
            if case .own = LoanStatus.of(player, ownClub: ownClub) { return true }
            return false
        }
        guard !firstTeam.isEmpty else { return nil }
        return Double(firstTeam.map(\.currentAbility).reduce(0, +)) / Double(firstTeam.count)
    }

    /// An outlook for each player of the club's own, not out on loan, aged `developingUpToAge` or under, with a current
    /// ability above 0.
    ///
    /// A slot he can play is one where his familiarity is at least `depthCoverFamiliarity` at both of its positions, or
    /// he has a retraining entry for either. `tiers` must be worked out from these players with injured players kept in
    /// (`ignoringInjuries: true`), so that every player here is rated at every slot; a slot the tiers did not rate him
    /// at is passed over, and so is a first or second choice who is not among `players` or not rated there.
    /// Throws `RatingError.missingAttribute` for a player of the outlooks without Professionalism, Ambition or
    /// Determination, and `RatingError.missingFamiliarity` for one without a familiarity at a slot's position.
    /// The parameters must have passed `FitnessModel.problems(in:)`.
    public static func outlooks(players: [Player], ownClub: String?, assignments: [SlotAssignment], tiers: SquadTiers,
                                retraining: [Retraining], parameters: EngineParameters) throws -> [PlayerID: Outlook] {
        // Sorting by key makes the first error independent of input order.
        let sorted = players.sorted { $0.id.key < $1.id.key }
        let byID = Dictionary(sorted.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var estimates: [PlayerID: ReachEstimate] = [:]
        for player in sorted where isDeveloping(player, ownClub: ownClub, parameters: parameters) {
            estimates[player.id] = try Reach.estimate(for: player, parameters: parameters)
        }
        let average = averageAbility(of: players, ownClub: ownClub)

        var found: [PlayerID: Outlook] = [:]
        for player in sorted {
            guard let estimate = estimates[player.id] else { continue }
            var slots: [SlotOutlook] = []
            for assignment in assignments {
                guard try canPlay(player, assignment, retraining: retraining, parameters: parameters),
                      let rating = tiers.ratings[player.id]?[assignment.slot] else { continue }
                let first = tiers.first[assignment.slot]
                let second = tiers.second[assignment.slot]
                let pair = rivals(at: assignment.slot, tiers: tiers, byID: byID, estimates: estimates, parameters: parameters)
                slots.append(slotOutlook(
                    player, estimate, assignment.slot, rating: rating, isFirstChoice: first == player.id,
                    firstChoice: first == player.id ? nil : pair.first,
                    secondChoice: second == player.id ? nil : pair.second,
                    estimates: (pair.firstEstimate, pair.secondEstimate), parameters: parameters))
            }
            found[player.id] = outlook(player, estimate, slots, average: average, parameters: parameters)
        }
        return found
    }

    /// The first and second choice at `slot` by `tiers`, as the outlooks name them (a rival who is developing is
    /// compared at his own reach), and the estimate of each who is developing. `squad` are the players the tiers were
    /// worked out from; a choice who is not among them, or not rated there, is nil.
    /// Throws `RatingError.missingAttribute` for a developing choice without Professionalism, Ambition or Determination.
    static func rivals(at slot: SlotID, tiers: SquadTiers, squad: [Player], ownClub: String?,
                       parameters: EngineParameters) throws -> Rivals {
        let byID = Dictionary(squad.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var estimates: [PlayerID: ReachEstimate] = [:]
        for id in [tiers.first[slot], tiers.second[slot]].compactMap({ $0 }) {
            if let player = byID[id], isDeveloping(player, ownClub: ownClub, parameters: parameters) {
                estimates[id] = try Reach.estimate(for: player, parameters: parameters)
            }
        }
        return rivals(at: slot, tiers: tiers, byID: byID, estimates: estimates, parameters: parameters)
    }

    /// What `outlooks` and the public `rivals` share, with the estimates already worked out.
    private static func rivals(at slot: SlotID, tiers: SquadTiers, byID: [PlayerID: Player],
                               estimates: [PlayerID: ReachEstimate],
                               parameters: EngineParameters) -> Rivals {
        func rival(_ id: PlayerID?) -> Rival? {
            guard let id, let player = byID[id], let rating = tiers.ratings[id]?[slot] else { return nil }
            let estimate = estimates[id]
            let compared = estimate.map { scaled(rating, from: Double($0.current), to: $0.reach, parameters) } ?? rating
            return Rival(player: id, name: player.name, age: player.age, rating: rating, compared: compared,
                         ability: player.currentAbility,
                         comparedAbility: estimate?.reach ?? Double(player.currentAbility),
                         isAgeNamed: player.age >= parameters.firstChoiceAgeNamedFrom.value)
        }
        let first = tiers.first[slot], second = tiers.second[slot]
        return (rival(first), rival(second), first.flatMap { estimates[$0] }, second.flatMap { estimates[$0] })
    }

    /// The first and second choice at a slot, and the estimate of each who is developing.
    typealias Rivals = (first: Rival?, second: Rival?, firstEstimate: ReachEstimate?, secondEstimate: ReachEstimate?)

    /// A young player whose ability `ability` is below `rival.comparedAbility` cannot be counted as passing him, whatever
    /// the ratings say.
    static func fallsShort(_ ability: Double, of rival: Rival) -> Bool {
        ability + roundingNoise < rival.comparedAbility
    }

    /// The second choice is expected to pass the first choice himself, by the same tests a young player must meet: his
    /// compared rating above the first choice's, and his compared ability not below the first choice's. A young player
    /// must then pass the second choice too before he is counted as passing the first, since the second choice gets
    /// there first.
    static func overtakes(_ second: Rival?, _ first: Rival) -> Bool {
        guard let second else { return false }
        return second.compared > first.compared + roundingNoise && !fallsShort(second.comparedAbility, of: first)
    }

    /// A first choice at any slot has enough, whatever he has started. Otherwise, with at least
    /// `matchesHereMinimumConfirmed` matches confirmed in the last `matchesHereWindowDays` days up to and including
    /// `asOf`, he has enough when he started `matchesHereShare` of them. With fewer, they are not counted: a second choice
    /// at a slot he is solid at (`depthSolidFamiliarity` in both phases, Depth's line) has enough, and anyone else does
    /// not: a stand-in, such as an outfield player who is the second eleven's goalkeeper, a backup, or a player the tiers
    /// did not rate. `assignments` are the tactic's.
    /// Throws `RatingError.missingFamiliarity` for a second choice without a familiarity at his slot's positions.
    /// The parameters must have passed `FitnessModel.problems(in:)`.
    public static func matchesHere(for player: Player, assignments: [SlotAssignment], tiers: SquadTiers,
                                   history: StartHistory, asOf: Day, parameters: EngineParameters) throws -> MatchesHere {
        let window = parameters.matchesHereWindowDays.value
        let starts = history.starts(of: player.id, inDays: window, endingOn: asOf)
        let matches = history.matches(inDays: window, endingOn: asOf)
        let tier = tiers.tier(of: player.id)
        if case .first = tier { return MatchesHere(starts: starts, matches: matches, basis: .firstChoice) }
        guard matches >= parameters.matchesHereMinimumConfirmed.value else {
            var isSolidSecond = false
            if case .second(let slot)? = tier, let assignment = assignments.first(where: { $0.slot == slot }) {
                func familiarity(_ position: Position) throws -> Int {
                    guard let value = player.familiarity[position] else {
                        throw RatingError.missingFamiliarity(player: player.name, position: position)
                    }
                    return value
                }
                let solidFrom = parameters.depthSolidFamiliarity.value
                let ip = try familiarity(assignment.ipPosition), oop = try familiarity(assignment.oopPosition)
                isSolidSecond = ip >= solidFrom && oop >= solidFrom
            }
            return MatchesHere(starts: starts, matches: matches, basis: isSolidSecond ? .solidSecondChoice : .tooFewConfirmed)
        }
        let enough = Double(starts) + roundingNoise >= parameters.matchesHereShare.value * Double(matches)
        return MatchesHere(starts: starts, matches: matches, basis: enough ? .startedEnough : .startedTooFew)
    }

    private static func isDeveloping(_ player: Player, ownClub: String?, parameters: EngineParameters) -> Bool {
        guard player.age <= parameters.developingUpToAge.value, player.currentAbility > 0 else { return false }
        if case .own = LoanStatus.of(player, ownClub: ownClub) { return true }
        return false
    }

    /// An option in both phases, or retraining at either position, matched as `ImportanceRules` matches a retraining.
    private static func canPlay(_ player: Player, _ assignment: SlotAssignment, retraining: [Retraining],
                                parameters: EngineParameters) throws -> Bool {
        func familiarity(_ position: Position) throws -> Int {
            guard let value = player.familiarity[position] else {
                throw RatingError.missingFamiliarity(player: player.name, position: position)
            }
            return value
        }
        let coverFrom = parameters.depthCoverFamiliarity.value
        let ip = try familiarity(assignment.ipPosition), oop = try familiarity(assignment.oopPosition)
        if ip >= coverFrom && oop >= coverFrom { return true }
        return retraining.contains { item in
            item.player == player.id && (item.position == assignment.ipPosition || item.position == assignment.oopPosition)
        }
    }

    /// The outlook at one slot of a player who need not be in the squad, from his rating there and the rivals
    /// `rivals(at:)` gave: what `outlooks` works out for a squad player, by the same code.
    static func slotOutlook(for player: Player, estimate: ReachEstimate, rating: Double, at slot: SlotID,
                            rivals: Rivals, parameters: EngineParameters) -> SlotOutlook {
        slotOutlook(player, estimate, slot, rating: rating, isFirstChoice: false, firstChoice: rivals.first,
                    secondChoice: rivals.second, estimates: (rivals.firstEstimate, rivals.secondEstimate),
                    parameters: parameters)
    }

    private static func slotOutlook(_ player: Player, _ estimate: ReachEstimate, _ slot: SlotID, rating: Double,
                                    isFirstChoice: Bool, firstChoice: Rival?, secondChoice: Rival?,
                                    estimates: (first: ReachEstimate?, second: ReachEstimate?),
                                    parameters: EngineParameters) -> SlotOutlook {
        let current = Double(estimate.current)
        let reachRating = scaled(rating, from: current, to: estimate.reach, parameters)
        guard let firstChoice else {
            return SlotOutlook(slot: slot, rating: rating, reachRating: reachRating, isFirstChoice: isFirstChoice,
                               firstChoice: nil, secondChoice: secondChoice, band: nil, pointsNeeded: nil, level: nil)
        }
        let pointsNeeded: Int? = rating > 0
            ? max(0, Int(((parameters.ratingAbilityOffset.value + current) * (firstChoice.rating / rating - 1)
                          - roundingNoise).rounded(.up)))
            : nil
        return SlotOutlook(
            slot: slot, rating: rating, reachRating: reachRating, isFirstChoice: isFirstChoice,
            firstChoice: firstChoice, secondChoice: secondChoice,
            band: band(player, estimate, rating: rating, firstChoice: firstChoice, secondChoice: secondChoice,
                       estimates: estimates, parameters: parameters),
            pointsNeeded: pointsNeeded,
            level: level(player, estimate, reachRating: reachRating, firstChoice: firstChoice, secondChoice: secondChoice,
                         parameters: parameters))
    }

    /// A rating at ability `current` taken to ability `ability`: a rating grows as (offset + ability), not in proportion
    /// to ability, so a low ability is not multiplied into a high rating. With an offset of 0 it is in proportion.
    private static func scaled(_ rating: Double, from current: Double, to ability: Double,
                               _ parameters: EngineParameters) -> Double {
        let offset = parameters.ratingAbilityOffset.value
        return rating * (offset + ability) / (offset + current)
    }

    /// He reaches a rival when his reach rating is at least the rival's compared rating and his reach is not below the
    /// rival's compared ability (`fallsShort`). He could pass the first choice when he reaches him and, if the second
    /// choice overtakes the first (`overtakes`), the second choice too. Below the bar (a share of the first choice's
    /// compared rating) he is markedly lower whoever the second choice is, so a weak second choice, or none, does not
    /// lift a weak young player; at or above it, he could make the second eleven when he reaches the second choice or
    /// there is none, or reaches the first choice behind a second choice who overtakes them both, and could become
    /// cover otherwise.
    private static func level(_ player: Player, _ estimate: ReachEstimate, reachRating: Double, firstChoice: Rival,
                              secondChoice: Rival?, parameters: EngineParameters) -> ReachLevel {
        func reaches(_ rival: Rival) -> Bool {
            reachRating + roundingNoise >= rival.compared && !fallsShort(estimate.reach, of: rival)
        }
        let passesFirst = reaches(firstChoice)
        // No second choice, or he is the second choice himself: there is nobody else to make the second eleven past.
        let passesSecond = secondChoice.map(reaches) ?? true
        if passesFirst && (passesSecond || !overtakes(secondChoice, firstChoice)) { return .couldPassFirst }
        let bar = player.age <= parameters.youngestUpToAge.value
            ? parameters.markedlyLowerShareYoungest.value : parameters.markedlyLowerShare.value
        if reachRating + roundingNoise < bar * firstChoice.compared { return .markedlyLower }
        return passesFirst || passesSecond ? .couldMakeSecond : .couldBeCover
    }

    /// Walks the players forward a season at a time: index k of `bySeason` is k seasons on. The rivals are the first
    /// choice and, when he overtakes the first choice (`overtakes`), the second choice too. A potential below a rival's
    /// compared ability (`fallsShort`) never passes him, and nor does a potential that rates below the compared rating
    /// of a second choice who overtakes the first, since that rival ends ahead whenever the young player might draw
    /// level: either is not expected. Otherwise he is ahead in a season when, against each rival, his rating is at least
    /// the rival's and his ability not below the rival's. A rival who is developing too grows as his own estimate says
    /// and holds his last value once his seasons run out.
    private static func band(_ player: Player, _ estimate: ReachEstimate, rating: Double, firstChoice: Rival,
                             secondChoice: Rival?, estimates: (first: ReachEstimate?, second: ReachEstimate?),
                             parameters: EngineParameters) -> ReachBand {
        let current = Double(estimate.current)
        let potential = Double(estimate.potential)
        let atPotential = scaled(rating, from: current, to: potential, parameters)
        var rivals: [(rival: Rival, estimate: ReachEstimate?)] = [(firstChoice, estimates.first)]
        if let secondChoice, overtakes(secondChoice, firstChoice) {
            if atPotential + roundingNoise < secondChoice.compared { return .notExpected }
            rivals.append((secondChoice, estimates.second))
        }
        if rivals.contains(where: { fallsShort(potential, of: $0.rival) }) { return .notExpected }
        func ability(of rival: Rival, _ rivalEstimate: ReachEstimate?, season k: Int) -> Double {
            guard let rivalEstimate else { return Double(rival.ability) }
            return rivalEstimate.bySeason[min(k, rivalEstimate.bySeason.count - 1)]
        }
        func isAhead(_ k: Int) -> Bool {
            let mine = estimate.bySeason[k]
            let myRating = scaled(rating, from: current, to: mine, parameters)
            return rivals.allSatisfy { rival, rivalEstimate in
                let theirAbility = ability(of: rival, rivalEstimate, season: k)
                let theirRating = rivalEstimate.map {
                    scaled(rival.rating, from: Double($0.current), to: theirAbility, parameters)
                } ?? rival.rating
                return myRating + roundingNoise >= theirRating && mine + roundingNoise >= theirAbility
            }
        }
        if let ahead = estimate.bySeason.indices.first(where: isAhead) {
            if ahead <= 1 { return .close }
            if player.age + ahead < parameters.onCourseBeforeAge.value { return .onCourse }
        }
        return atPotential + roundingNoise >= firstChoice.compared ? .possible : .notExpected
    }

    private static func outlook(_ player: Player, _ estimate: ReachEstimate, _ slots: [SlotOutlook], average: Double?,
                                parameters: EngineParameters) -> Outlook {
        func rank(_ level: ReachLevel) -> Int {
            switch level {
            case .couldPassFirst: 0
            case .couldMakeSecond: 1
            case .couldBeCover: 2
            case .markedlyLower: 3
            }
        }
        func share(_ slot: SlotOutlook) -> Double {
            guard let compared = slot.firstChoice?.compared, compared > 0 else { return .infinity }
            return slot.reachRating / compared
        }
        var best: SlotOutlook?
        // Slots are in the tactic's order, so a later slot replaces the best only when strictly better.
        for slot in slots {
            guard let level = slot.level else { continue }
            guard let current = best, let currentLevel = current.level else { best = slot; continue }
            if rank(level) < rank(currentLevel) || (rank(level) == rank(currentLevel) && share(slot) > share(current)) {
                best = slot
            }
        }
        if let best {
            return Outlook(player: player.id, estimate: estimate, slots: slots, best: best, level: best.level, average: nil)
        }
        if slots.contains(where: \.isFirstChoice) {
            return Outlook(player: player.id, estimate: estimate, slots: slots, best: nil, level: nil, average: nil)
        }
        let level: ReachLevel
        if let average {
            if estimate.reach + roundingNoise >= average {
                level = .couldMakeSecond
            } else if estimate.reach + roundingNoise >= parameters.removalRules.value.farBelowAverageShare * average {
                level = .couldBeCover
            } else {
                level = .markedlyLower
            }
        } else {
            level = .couldBeCover
        }
        return Outlook(player: player.id, estimate: estimate, slots: slots, best: nil, level: level, average: average)
    }
}
