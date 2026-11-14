import Foundation

/// A player and a position he could learn.
public struct RetrainingChoice: Hashable, Codable, Sendable {
    public let player: PlayerID
    public let position: Position

    public init(player: PlayerID, position: Position) {
        self.player = player
        self.position = position
    }
}

/// A thin slot in one saved tactic.
public struct RetrainingNeed: Equatable, Sendable {
    /// The tactic's name.
    public let tactic: String
    public let slot: SlotID

    public init(tactic: String, slot: SlotID) {
        self.tactic = tactic
        self.slot = slot
    }
}

/// How hard a move between two positions is, easiest first.
public enum RetrainingDifficulty: String, CaseIterable, Sendable { case fluid, structural, spatial, inversion }

/// One player the owner could retrain in a position, and why.
public struct RetrainingRecommendation: Equatable, Sendable {
    public let choice: RetrainingChoice
    public let name: String
    public let age: Int
    /// His familiarity now at the position to learn.
    public let currentFamiliarity: Int
    /// The thin slots he would cover, most in need first.
    public let needs: [RetrainingNeed]
    /// His rating in the first of those slots at familiarity 20 in both phases.
    public let ratingIfLearnt: Double
    /// That rating over the slot's first choice's.
    public let shareOfFirstChoice: Double
    /// From 0 to 1.
    public let learnability: Double
    /// The position he retrains from.
    public let from: Position
    public let difficulty: RetrainingDifficulty
    /// Estimated weeks to reach `depthSolidFamiliarity`.
    public let weeks: Int
    public let reasons: [String]
    public let cautions: [String]
    /// The weakest evidence among the parameters behind this advice.
    public let basis: Evidence
}

public struct TrainingReport: Equatable, Sendable {
    /// Most needed first.
    public let recommendations: [RetrainingRecommendation]
    /// Thin slots no recommendation covers and no accepted retraining covers: places to recruit. Most in need first.
    public let needsWithoutCandidates: [RetrainingNeed]
    /// Thin slots no recommendation covers that a player of the club's own is already being retrained for: an accepted
    /// retraining at the slot's in-possession or out-of-possession position where he is not yet solid. Most in need first.
    public let needsBeingRetrained: [RetrainingNeed]
}

public enum Training {
    /// Absorbs binary floating-point error before weeks are rounded up, so an exact product is not a week more.
    private static let roundingNoise = 1e-9
    /// The game's highest familiarity: a natural.
    private static let naturalFamiliarity = 20

    /// Who should learn a position to cover the thin slots of `tactics`. Throws `PlanError.badParameters` when
    /// `FitnessModel.problems(in:)` finds problems, what `Depth.report` throws, `RatingError.missingAttribute` for a
    /// candidate without Versatility or Professionalism, and `RatingError.missingFamiliarity` for a missing position.
    public static func report(tactics: [Tactic], players: [Player], ownClub: String?,
                              accepted: [Retraining], rejected: Set<RetrainingChoice>,
                              catalog: RoleCatalog, profile: RatingProfile,
                              parameters: EngineParameters) throws -> TrainingReport {
        let problems = FitnessModel.problems(in: parameters)
        guard problems.isEmpty else { throw PlanError.badParameters(problems) }

        let engine = RatingEngine(profile: profile, parameters: parameters, configuration: .fm27)
        // Sorting by key makes every list independent of input order.
        let sorted = players.sorted { $0.id.key < $1.id.key }
        let skipped = rejected.union(accepted.map { RetrainingChoice(player: $0.player, position: $0.position) })
        var needs: [NeedFacts] = []
        var pairs: [RetrainingChoice: Pair] = [:]
        var learnabilities: [PlayerID: Double] = [:]
        let byID = Dictionary(sorted.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let solidFrom = parameters.depthSolidFamiliarity.value

        /// An accepted retraining of one of the club's own players at a position of the slot where he is not yet solid.
        func isBeingRetrained(_ assignment: SlotAssignment) throws -> Bool {
            for retraining in accepted {
                guard let player = byID[retraining.player], case .own = LoanStatus.of(player, ownClub: ownClub) else { continue }
                for position in [assignment.ipPosition, assignment.oopPosition] where retraining.position == position {
                    if try familiarity(player, position) < solidFrom { return true }
                }
            }
            return false
        }

        for tactic in tactics {
            let depth = try Depth.report(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                                         profile: profile, parameters: parameters)
            let firstEleven = try Elevens.report(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                                                 profile: profile, parameters: parameters).first
            let firstChoice = Dictionary(uniqueKeysWithValues: firstEleven.map { ($0.slot, $0) })
            let firstAt = Dictionary(uniqueKeysWithValues: firstEleven.map { ($0.player, $0.slot) })
            let assignments = Dictionary(uniqueKeysWithValues: try tactic.assignments(catalog: catalog).map { ($0.slot, $0) })
            let slots = Dictionary(uniqueKeysWithValues: depth.slots.map { ($0.slot, $0) })

            for slot in depth.thin {
                guard let assignment = assignments[slot], let slotDepth = slots[slot] else { continue }
                let index = needs.count
                needs.append(NeedFacts(need: RetrainingNeed(tactic: tactic.name, slot: slot), ipPosition: assignment.ipPosition,
                                       cover: slotDepth.cover,
                                       isBeingRetrained: try isBeingRetrained(assignment)))
                // Without a first choice there is nothing to measure a candidate against.
                guard let first = firstChoice[slot], first.rating.value > 0 else { continue }
                for player in sorted {
                    guard let candidate = try candidate(player, for: assignment, firstRating: first.rating.value,
                                                        firstAt: firstAt, ownClub: ownClub, engine: engine,
                                                        learnabilities: &learnabilities, parameters: parameters)
                    else { continue }
                    let choice = RetrainingChoice(player: player.id, position: candidate.position)
                    guard !skipped.contains(choice) else { continue }
                    if pairs[choice] == nil {
                        pairs[choice] = Pair(choice: choice, player: player, needs: [index], candidate: candidate)
                    } else {
                        pairs[choice]?.needs.append(index)
                    }
                }
            }
        }

        let chosen = choose(Array(pairs.values), perPosition: parameters.retrainingPerPosition.value)
        let basis = Evidence.weakest([
            parameters.depthCoverFamiliarity.evidence, parameters.depthSolidFamiliarity.evidence,
            parameters.depthThinBelow.evidence, parameters.learnabilityRules.evidence,
            parameters.retrainingMinimumLearnability.evidence, parameters.retrainingMinimumShare.evidence,
            parameters.retrainingPerPosition.evidence, parameters.retrainingTransitions.evidence,
            parameters.retrainingWeeks.evidence, parameters.retrainingPace.evidence,
        ])!
        let recommendations = chosen.map { recommendation($0, needs: needs, basis: basis, parameters: parameters) }
        let covered = Set(chosen.flatMap(\.needs))
        let uncovered = needs.indices.filter { !covered.contains($0) }.map { needs[$0] }
        return TrainingReport(recommendations: recommendations,
                              needsWithoutCandidates: uncovered.filter { !$0.isBeingRetrained }.map(\.need),
                              needsBeingRetrained: uncovered.filter(\.isBeingRetrained).map(\.need))
    }

    /// From 0 to 1: how quickly he is likely to learn a new position. Throws `RatingError.missingAttribute` without
    /// Versatility or Professionalism.
    static func learnability(of player: Player, parameters: EngineParameters) throws -> Double {
        let rules = parameters.learnabilityRules.value
        let versatility = try attribute(player, .versatility)
        let professionalism = try attribute(player, .professionalism)
        var versatilityShare = Double(versatility) / rules.attributeMaximum
        if versatility < rules.lowVersatilityBelow { versatilityShare *= rules.lowVersatilityFactor }
        let ageFactor = rules.ageSteps.first { player.age <= $0.upTo }?.factor ?? rules.ageAbove
        let professionalismShare = Double(professionalism) / rules.attributeMaximum
        let room = min(max(Double(player.potentialAbility - player.currentAbility) / rules.roomToGrowSpan, 0), 1)
        return rules.versatilityWeight * versatilityShare + rules.ageWeight * ageFactor
            + rules.professionalismWeight * professionalismShare + rules.roomToGrowWeight * room
    }

    // MARK: Candidates

    /// One thin slot and what the reasons say about it.
    private struct NeedFacts {
        let need: RetrainingNeed
        let ipPosition: Position
        let cover: Int
        let isBeingRetrained: Bool
    }

    /// A player who suits one thin slot.
    private struct Candidate {
        let position: Position
        let currentFamiliarity: Int
        let isOutOfPossessionOnly: Bool
        let rating: Double
        let share: Double
        let learnability: Double
        let versatility: Int
        let from: Position
        let difficulty: RetrainingDifficulty
        let weeks: Int
        var product: Double { share * learnability }
    }

    /// A (player, position) pair, the needs it covers in need order, and the figures for the first of them.
    private struct Pair {
        let choice: RetrainingChoice
        let player: Player
        var needs: [Int]
        let candidate: Candidate
    }

    /// Nil when he does not suit the slot; the filters run cheapest first. A first choice at another slot is never a
    /// candidate: Depth would not count him as cover here. He must already be solid at the slot's other position, so that
    /// learning one position makes him solid in both phases.
    private static func candidate(_ player: Player, for assignment: SlotAssignment, firstRating: Double,
                                  firstAt: [PlayerID: SlotID], ownClub: String?, engine: RatingEngine,
                                  learnabilities: inout [PlayerID: Double], parameters: EngineParameters) throws -> Candidate? {
        guard case .own = LoanStatus.of(player, ownClub: ownClub) else { return nil }
        let solidFrom = parameters.depthSolidFamiliarity.value
        // A goalkeeper is a player who is solid in goal, by the same line Depth uses for solid cover.
        let isGoalkeeper = try familiarity(player, .goalkeeper) >= solidFrom
        guard isGoalkeeper == (assignment.ipPosition == .goalkeeper) else { return nil }
        let ip = try familiarity(player, assignment.ipPosition)
        let oop = try familiarity(player, assignment.oopPosition)
        guard ip < solidFrom || oop < solidFrom else { return nil }
        // With both positions the same, one familiarity covers both phases; otherwise exactly one may be short.
        guard assignment.ipPosition == assignment.oopPosition || ip >= solidFrom || oop >= solidFrom else { return nil }
        if let home = firstAt[player.id], home != assignment.slot { return nil }

        var learnt = player
        learnt.familiarity[assignment.ipPosition] = naturalFamiliarity
        learnt.familiarity[assignment.oopPosition] = naturalFamiliarity
        let rating = try engine.rating(for: learnt, in: assignment).value
        let share = rating / firstRating
        guard share >= parameters.retrainingMinimumShare.value else { return nil }

        let learnability: Double
        if let known = learnabilities[player.id] {
            learnability = known
        } else {
            learnability = try Self.learnability(of: player, parameters: parameters)
            learnabilities[player.id] = learnability
        }
        guard learnability >= parameters.retrainingMinimumLearnability.value else { return nil }

        let position = ip < solidFrom ? assignment.ipPosition : assignment.oopPosition
        let current = ip < solidFrom ? ip : oop
        let (from, difficulty) = try origin(of: player, learning: position, parameters: parameters)
        let versatility = try attribute(player, .versatility)
        guard let weeks = try weeks(difficulty, age: player.age, versatility: versatility, familiarity: current,
                                    parameters: parameters) else { return nil }
        return Candidate(position: position, currentFamiliarity: current,
                         isOutOfPossessionOnly: position == assignment.oopPosition && position != assignment.ipPosition,
                         rating: rating, share: share, learnability: learnability, versatility: versatility,
                         from: from, difficulty: difficulty, weeks: weeks)
    }

    /// The position he retrains from and the class of the move: among his positions at `fromFamiliarity` or over the
    /// easiest move, or with none his best position; ties go to the earlier position in `Position.allCases`.
    private static func origin(of player: Player, learning target: Position,
                               parameters: EngineParameters) throws -> (Position, RetrainingDifficulty) {
        let transitions = parameters.retrainingTransitions.value
        let rank = Dictionary(uniqueKeysWithValues: RetrainingDifficulty.allCases.enumerated().map { ($1, $0) })
        var easiest: (position: Position, difficulty: RetrainingDifficulty)?
        var best: (position: Position, familiarity: Int)?
        for position in Position.allCases where position != target {
            let value = try familiarity(player, position)
            if value >= transitions.fromFamiliarity {
                let difficulty = transitions.difficulty(from: position, to: target)
                if easiest == nil || rank[difficulty]! < rank[easiest!.difficulty]! { easiest = (position, difficulty) }
            }
            if best == nil || value > best!.familiarity { best = (position, value) }
        }
        if let easiest { return easiest }
        // Every position but the target is looked at, so there is always a best one.
        let from = best!.position
        return (from, transitions.difficulty(from: from, to: target))
    }

    /// The middle of the class's range times his age, Versatility and head-start factors, rounded up, at least
    /// `minimumWeeks`; nil for an inversion.
    static func weeks(_ difficulty: RetrainingDifficulty, age: Int, versatility: Int, familiarity: Int,
                      parameters: EngineParameters) throws -> Int? {
        let ranges = parameters.retrainingWeeks.value
        let range: WeekRange
        switch difficulty {
        case .fluid: range = ranges.fluid
        case .structural: range = ranges.structural
        case .spatial: range = ranges.spatial
        case .inversion: return nil
        }
        let pace = parameters.retrainingPace.value
        let ageFactor = pace.ageSteps.first { age <= $0.upTo }?.factor ?? pace.ageAbove
        let versatilityFactor = versatility >= pace.highVersatilityFrom ? pace.highVersatilityFactor
            : versatility <= pace.lowVersatilityUpTo ? pace.lowVersatilityFactor : 1.0
        let headStart = pace.headStartSteps.first { familiarity >= $0.minimum }?.factor ?? 1.0
        let raw = (range.middle * ageFactor * versatilityFactor * headStart - roundingNoise).rounded(.up)
        guard raw.isFinite, raw < Double(Int.max) else {
            throw PlanError.badParameters(["retraining weeks for a \(difficulty.rawValue) change come to \(raw), too many to count"])
        }
        return max(pace.minimumWeeks, Int(raw))
    }

    // MARK: Choosing and wording

    /// Every pair, highest product first (then key, then position order), taken while its player has no recommendation
    /// and its position has fewer than `perPosition`; so a player whose best position is full is offered his next best.
    /// Returned in the order of the first need each covers, then the product, highest first, then key.
    private static func choose(_ pairs: [Pair], perPosition: Int) -> [Pair] {
        let positionIndex = Dictionary(uniqueKeysWithValues: Position.allCases.enumerated().map { ($1, $0) })
        let byProduct = pairs.sorted { a, b in
            if a.candidate.product != b.candidate.product { return a.candidate.product > b.candidate.product }
            if a.choice.player.key != b.choice.player.key { return a.choice.player.key < b.choice.player.key }
            return positionIndex[a.choice.position]! < positionIndex[b.choice.position]!
        }
        var placed: Set<PlayerID> = []
        var taken: [Position: Int] = [:]
        var kept: [Pair] = []
        for pair in byProduct where !placed.contains(pair.choice.player) && taken[pair.choice.position, default: 0] < perPosition {
            placed.insert(pair.choice.player)
            taken[pair.choice.position, default: 0] += 1
            kept.append(pair)
        }
        return kept.sorted { a, b in
            if a.needs[0] != b.needs[0] { return a.needs[0] < b.needs[0] }
            if a.candidate.product != b.candidate.product { return a.candidate.product > b.candidate.product }
            return a.choice.player.key < b.choice.player.key
        }
    }

    private static func recommendation(_ pair: Pair, needs: [NeedFacts], basis: Evidence,
                                       parameters: EngineParameters) -> RetrainingRecommendation {
        let c = pair.candidate
        var reasons: [String] = []
        for index in pair.needs {
            let facts = needs[index]
            let available = switch facts.cover {
            case 0: "no solid player available"
            case 1: "1 solid player available"
            default: "\(facts.cover) solid players available"
            }
            let sentence = "Cover at \(facts.ipPosition.rawValue) is thin in \(facts.need.tactic) (\(available))"
            if !reasons.contains(sentence) { reasons.append(sentence) }
        }
        reasons.append("He would rate \(String(format: "%.1f", c.rating)) there once learnt, \(Display.percent(c.share)) of the first choice")
        reasons.append("From \(c.from.rawValue): a \(c.difficulty.rawValue) change, about \(c.weeks) weeks at his age and Versatility")

        var cautions = [
            "Timings are estimates from earlier versions of the game; none is published for FM27",
            "His familiarity at \(c.from.rawValue) may fall while he learns a new position",
        ]
        if c.currentFamiliarity < parameters.depthCoverFamiliarity.value { cautions.append("He may never become natural there") }
        if c.versatility < parameters.learnabilityRules.value.lowVersatilityBelow {
            cautions.append("Low Versatility: this may take 18 months or more")
        }
        if c.isOutOfPossessionOnly {
            cautions.append("Needed out of possession only: reports say out-of-possession familiarity was hard to train in FM26")
        }

        return RetrainingRecommendation(
            choice: pair.choice, name: pair.player.name, age: pair.player.age, currentFamiliarity: c.currentFamiliarity,
            needs: pair.needs.map { needs[$0].need }, ratingIfLearnt: c.rating, shareOfFirstChoice: c.share,
            learnability: c.learnability, from: c.from, difficulty: c.difficulty, weeks: c.weeks,
            reasons: reasons, cautions: cautions, basis: basis)
    }

    // MARK: Data

    private static func attribute(_ player: Player, _ attribute: Attribute) throws -> Int {
        guard let value = player.attributes[attribute] else {
            throw RatingError.missingAttribute(player: player.name, attribute: attribute)
        }
        return value
    }

    private static func familiarity(_ player: Player, _ position: Position) throws -> Int {
        guard let value = player.familiarity[position] else {
            throw RatingError.missingFamiliarity(player: player.name, position: position)
        }
        return value
    }
}
