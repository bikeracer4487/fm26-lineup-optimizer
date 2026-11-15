import Foundation

/// When a young player's rating at a slot is expected to pass the first choice's.
public enum ReachBand: String, CaseIterable, Sendable {
    /// Ahead today or within one season.
    case close
    /// First ahead before `onCourseBeforeAge`.
    case onCourse
    /// His potential is high enough, but he gets there later, or his reach falls short.
    case possible
    /// His potential, as a rating, is below what the first choice is compared at.
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
    /// What the young player must reach: the rival's own reach rating when he is developing too, `rating` otherwise.
    public let compared: Double
}

/// A young player at one slot he can play.
public struct SlotOutlook: Equatable, Sendable {
    public let slot: SlotID
    /// His full-fitness rating there today.
    public let rating: Double
    /// `rating` × his reach ÷ his current ability.
    public let reachRating: Double
    /// He is the first choice at this slot.
    public let isFirstChoice: Bool
    /// nil when he is it, or the slot has none.
    public let firstChoice: Rival?
    /// nil when he is it, or the slot has none.
    public let secondChoice: Rival?
    /// nil when `firstChoice` is nil.
    public let band: ReachBand?
    /// The ability points he needs to match the first choice today, rounded up; nil with no first choice or a rating of
    /// 0 here, 0 when already level.
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
    public var isMarkedlyLower: Bool { level == .markedlyLower }
}

public enum Development {
    /// Comparisons allow for binary floating-point error, as `ImportanceRules.development` does.
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

        func rival(_ id: PlayerID?, at slot: SlotID) -> Rival? {
            guard let id, let player = byID[id], let rating = tiers.ratings[id]?[slot] else { return nil }
            let compared = estimates[id].map { rating * $0.reach / Double($0.current) } ?? rating
            return Rival(player: id, name: player.name, age: player.age, rating: rating, compared: compared)
        }

        var found: [PlayerID: Outlook] = [:]
        for player in sorted {
            guard let estimate = estimates[player.id] else { continue }
            var slots: [SlotOutlook] = []
            for assignment in assignments {
                guard try canPlay(player, assignment, retraining: retraining, parameters: parameters),
                      let rating = tiers.ratings[player.id]?[assignment.slot] else { continue }
                let first = tiers.first[assignment.slot]
                let second = tiers.second[assignment.slot]
                slots.append(slotOutlook(
                    player, estimate, assignment.slot, rating: rating, isFirstChoice: first == player.id,
                    firstChoice: first == player.id ? nil : rival(first, at: assignment.slot),
                    secondChoice: second == player.id ? nil : rival(second, at: assignment.slot),
                    firstChoiceEstimate: first.flatMap { estimates[$0] }, parameters: parameters))
            }
            found[player.id] = outlook(player, estimate, slots, average: average, parameters: parameters)
        }
        return found
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

    private static func slotOutlook(_ player: Player, _ estimate: ReachEstimate, _ slot: SlotID, rating: Double,
                                    isFirstChoice: Bool, firstChoice: Rival?, secondChoice: Rival?,
                                    firstChoiceEstimate: ReachEstimate?, parameters: EngineParameters) -> SlotOutlook {
        let current = Double(estimate.current)
        let reachRating = rating * estimate.reach / current
        guard let firstChoice else {
            return SlotOutlook(slot: slot, rating: rating, reachRating: reachRating, isFirstChoice: isFirstChoice,
                               firstChoice: nil, secondChoice: secondChoice, band: nil, pointsNeeded: nil, level: nil)
        }
        let pointsNeeded: Int? = rating > 0
            ? max(0, Int((current * (firstChoice.rating / rating - 1) - roundingNoise).rounded(.up)))
            : nil
        return SlotOutlook(
            slot: slot, rating: rating, reachRating: reachRating, isFirstChoice: isFirstChoice,
            firstChoice: firstChoice, secondChoice: secondChoice,
            band: band(player, estimate, rating: rating, firstChoice: firstChoice, firstChoiceEstimate: firstChoiceEstimate,
                       parameters: parameters),
            pointsNeeded: pointsNeeded,
            level: level(player, reachRating: reachRating, firstChoice: firstChoice, secondChoice: secondChoice,
                         parameters: parameters))
    }

    private static func level(_ player: Player, reachRating: Double, firstChoice: Rival, secondChoice: Rival?,
                              parameters: EngineParameters) -> ReachLevel {
        if reachRating + roundingNoise >= firstChoice.compared { return .couldPassFirst }
        // No second choice, or he is the second choice himself: there is nobody else to make the second eleven past.
        if secondChoice.map({ reachRating + roundingNoise >= $0.compared }) ?? true { return .couldMakeSecond }
        let bar = player.age <= parameters.youngestUpToAge.value
            ? parameters.markedlyLowerShareYoungest.value : parameters.markedlyLowerShare.value
        return reachRating + roundingNoise >= bar * firstChoice.compared ? .couldBeCover : .markedlyLower
    }

    /// Walks both players forward a season at a time: index k of `bySeason` is k seasons on. A first choice who is
    /// developing too grows as his own estimate says and holds his last value once his seasons run out.
    private static func band(_ player: Player, _ estimate: ReachEstimate, rating: Double, firstChoice: Rival,
                             firstChoiceEstimate: ReachEstimate?, parameters: EngineParameters) -> ReachBand {
        let current = Double(estimate.current)
        func theirs(_ k: Int) -> Double {
            guard let rivalEstimate = firstChoiceEstimate else { return firstChoice.rating }
            let ability = rivalEstimate.bySeason[min(k, rivalEstimate.bySeason.count - 1)]
            return firstChoice.rating * ability / Double(rivalEstimate.current)
        }
        let ahead = estimate.bySeason.indices.first { k in
            rating * estimate.bySeason[k] / current + roundingNoise >= theirs(k)
        }
        if let ahead {
            if ahead <= 1 { return .close }
            if player.age + ahead < parameters.onCourseBeforeAge.value { return .onCourse }
        }
        let atPotential = rating * Double(estimate.potential) / current
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
