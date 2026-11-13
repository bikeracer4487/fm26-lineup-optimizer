import Foundation

/// Everything needed to choose the starting eleven for one fixture.
public struct SelectionRequest: Sendable {
    public var tactic: Tactic
    public var players: [Player]
    public var ownClub: String?
    public var importance: Importance
    public var isNextFixture: Bool
    /// Players the manager has fixed in a slot for this fixture.
    public var overrides: [SlotID: PlayerID]
    /// Players the manager has ruled out of this fixture.
    public var rejected: Set<PlayerID>

    public init(tactic: Tactic, players: [Player], ownClub: String?, importance: Importance, isNextFixture: Bool,
                overrides: [SlotID: PlayerID], rejected: Set<PlayerID>) {
        self.tactic = tactic; self.players = players; self.ownClub = ownClub; self.importance = importance
        self.isNextFixture = isNextFixture; self.overrides = overrides; self.rejected = rejected
    }
}

public enum PickWarning: Equatable, Sendable {
    case outOfPosition(Phase, familiarity: Int)
    /// The manager chose a player a rule would have kept out.
    case overridesRule(Exclusion)
}

public enum FactorKind: String, Sendable {
    case condition, sharpness, jadedness
}

public struct Pick: Equatable, Sendable {
    public let slot: SlotID
    public let player: PlayerID
    public let name: String
    public let rating: SlotRating
    public let fitness: FitnessFactors
    /// `rating.value × fitness.product`.
    public let value: Double
    public let isOverride: Bool
    public let warnings: [PickWarning]
    /// Plain sentences for the manager: the rating line, then the fitness lines, then the override line.
    public let reasons: [String]

    public init(slot: SlotID, player: PlayerID, name: String, rating: SlotRating, fitness: FitnessFactors,
                value: Double, isOverride: Bool, warnings: [PickWarning], reasons: [String]) {
        self.slot = slot; self.player = player; self.name = name; self.rating = rating; self.fitness = fitness
        self.value = value; self.isOverride = isOverride; self.warnings = warnings; self.reasons = reasons
    }
}

public enum OmissionCause: Equatable, Sendable {
    case excluded(Exclusion)
    /// `ideal` is his full-fitness value in his ideal slot, `today` that value times his fitness product.
    case lowerMatchDayValue(ideal: Double, today: Double, limiting: FactorKind)
}

/// A player in the ideal eleven who is not in the real one.
public struct Omission: Equatable, Sendable {
    public let player: PlayerID
    public let name: String
    /// His slot in the ideal eleven.
    public let slot: SlotID
    public let cause: OmissionCause
    public let reason: String

    public init(player: PlayerID, name: String, slot: SlotID, cause: OmissionCause, reason: String) {
        self.player = player; self.name = name; self.slot = slot; self.cause = cause; self.reason = reason
    }
}

public enum OverrideProblem: Equatable, Sendable {
    case notInSquad, notAllowed(Exclusion), usedTwice
    /// The slot is not one of the tactic's in-possession slots, for example after the fixture's tactic changed.
    case slotNotInTactic
}

public struct Lineup: Equatable, Sendable {
    /// In `SlotID` order.
    public let picks: [Pick]
    public let unfilled: [SlotID]
    /// In the order of the ideal eleven's slots.
    public let omissions: [Omission]
    public let ignoredOverrides: [SlotID: OverrideProblem]

    public init(picks: [Pick], unfilled: [SlotID], omissions: [Omission], ignoredOverrides: [SlotID: OverrideProblem]) {
        self.picks = picks; self.unfilled = unfilled; self.omissions = omissions; self.ignoredOverrides = ignoredOverrides
    }
}

/// Chooses the best available eleven for one fixture and explains every pick and every notable omission.
public struct LineupSelector: Sendable {
    private let catalog: RoleCatalog
    private let engine: RatingEngine
    private let parameters: EngineParameters

    public init(catalog: RoleCatalog, tables: RatingTables, parameters: EngineParameters, configuration: RatingConfiguration = .fm27) {
        self.catalog = catalog
        self.engine = RatingEngine(tables: tables, parameters: parameters, configuration: configuration)
        self.parameters = parameters
    }

    /// Throws `TacticError` for an unusable tactic and `RatingError` for a player with missing data.
    public func select(_ request: SelectionRequest) throws -> Lineup {
        let assignments = try request.tactic.assignments(catalog: catalog)
        // A repeated PlayerID is a caller error: keep the first. Sorting by key makes the result
        // independent of input order.
        var seen = Set<PlayerID>()
        let players = request.players.filter { seen.insert($0.id).inserted }.sorted { $0.id.key < $1.id.key }
        let index = Dictionary(uniqueKeysWithValues: players.enumerated().map { ($1.id, $0) })
        let loanedOut = players.map { player in
            if case .loanedOut = LoanStatus.of(player, ownClub: request.ownClub) { true } else { false }
        }
        let exclusions = players.map { exclusion(for: $0, request) }
        let fitness = players.map {
            FitnessModel.factors(condition: $0.condition, sharpness: $0.sharpness, jadedness: $0.jadedness, parameters: parameters)
        }
        // ratings[slot][candidate]; nil only for players out on loan, who are never rated.
        let ratings: [[SlotRating?]] = try assignments.map { assignment in
            try players.indices.map { loanedOut[$0] ? nil : try engine.rating(for: players[$0], in: assignment) }
        }

        // Overrides
        // Overrides, first problem wins: slot not in the tactic, not in the squad, used twice, not allowed.
        // An override for a slot the tactic does not use does not count as a use.
        let slotIndex = Dictionary(uniqueKeysWithValues: assignments.enumerated().map { ($1.slot, $0) })
        let active = request.overrides.compactMap { slot, id in slotIndex[slot].map { (s: $0, slot: slot, id: id) } }
        let uses = Dictionary(active.map { ($0.id, 1) }, uniquingKeysWith: +)
        var ignored: [SlotID: OverrideProblem] = [:]
        for slot in request.overrides.keys where slotIndex[slot] == nil { ignored[slot] = .slotNotInTactic }
        var placed: [Int: Int] = [:]   // slot index -> player index
        for (s, slot, id) in active {
            guard let i = index[id] else { ignored[slot] = .notInSquad; continue }
            if uses[id, default: 0] > 1 {
                ignored[slot] = .usedTwice
            } else if let excluded = exclusions[i], !RiskRules.canBeOverridden(excluded) {
                ignored[slot] = .notAllowed(excluded)
            } else {
                placed[s] = i
            }
        }
        let overridden = Set(placed.keys)

        // The real eleven: available players at match-day value, around the overrides.
        let openSlots = assignments.indices.filter { placed[$0] == nil }
        let fixedPlayers = Set(placed.values)
        let candidates = players.indices.filter { !fixedPlayers.contains($0) }
        let values: [[Double?]] = openSlots.map { s in
            candidates.map { i in exclusions[i] == nil ? ratings[s][i].map { $0.value * fitness[i].product } : nil }
        }
        for (row, choice) in AssignmentSolver.maximise(values: values).enumerated() {
            if let c = choice { placed[openSlots[row]] = candidates[c] }
        }

        var picks: [Pick] = []
        var unfilled: [SlotID] = []
        for (s, assignment) in assignments.enumerated() {
            guard let i = placed[s], let rating = ratings[s][i] else { unfilled.append(assignment.slot); continue }
            let isOverride = overridden.contains(s)
            picks.append(pick(assignment, players[i], rating: rating, fitness: fitness[i],
                              isOverride: isOverride, broken: isOverride ? exclusions[i] : nil))
        }

        // The ideal eleven: everyone not out on loan, at full fitness, with no exclusions or overrides.
        let ideal = AssignmentSolver.maximise(values: ratings.map { row in row.map { $0?.value } })
        let inLineup = Set(placed.values)
        var omissions: [Omission] = []
        for (s, choice) in ideal.enumerated() {
            guard let i = choice, !inLineup.contains(i), let rating = ratings[s][i] else { continue }
            omissions.append(omission(players[i], slot: assignments[s].slot, rating: rating,
                                      fitness: fitness[i], excluded: exclusions[i]))
        }

        return Lineup(picks: picks, unfilled: unfilled, omissions: omissions, ignoredOverrides: ignored)
    }

    /// A risk rule's exclusion, else `.rejected` if the manager rejected him, else nil.
    private func exclusion(for player: Player, _ request: SelectionRequest) -> Exclusion? {
        let loan = LoanStatus.of(player, ownClub: request.ownClub)
        if let ruled = RiskRules.exclusion(for: player, loan: loan, importance: request.importance,
                                           isNextFixture: request.isNextFixture, parameters: parameters) {
            return ruled
        }
        return request.rejected.contains(player.id) ? .rejected : nil
    }

    private func pick(_ assignment: SlotAssignment, _ player: Player, rating: SlotRating, fitness: FitnessFactors,
                      isOverride: Bool, broken: Exclusion?) -> Pick {
        var warnings: [PickWarning] = []
        for (phase, phaseRating) in [(Phase.inPossession, rating.inPossession), (.outOfPossession, rating.outOfPossession)]
        where phaseRating.familiarity < parameters.outOfPositionBelow.value {
            warnings.append(.outOfPosition(phase, familiarity: phaseRating.familiarity))
        }
        if let broken { warnings.append(.overridesRule(broken)) }

        var reasons = ["Rating \(oneDecimal(rating.value)): "
            + "\(assignment.ipPosition.rawValue) familiarity \(rating.inPossession.familiarity) in possession, "
            + "\(assignment.oopPosition.rawValue) familiarity \(rating.outOfPossession.familiarity) out of possession"]
        if fitness.condition < 1 { reasons.append("Condition \(percent(player.condition)) (×\(twoDecimals(fitness.condition)))") }
        if fitness.sharpness < 1 { reasons.append("Sharpness \(percent(player.sharpness)) (×\(twoDecimals(fitness.sharpness)))") }
        if fitness.jadedness < 1 { reasons.append("Jadedness \(player.jadedness) (×\(twoDecimals(fitness.jadedness)))") }
        if isOverride { reasons.append("Chosen by you" + (broken.map { ", overriding: \(rule($0))" } ?? "")) }

        return Pick(slot: assignment.slot, player: player.id, name: player.name, rating: rating, fitness: fitness,
                    value: rating.value * fitness.product, isOverride: isOverride, warnings: warnings, reasons: reasons)
    }

    private func omission(_ player: Player, slot: SlotID, rating: SlotRating, fitness: FitnessFactors,
                          excluded: Exclusion?) -> Omission {
        let cause: OmissionCause
        let reason: String
        if let excluded {
            cause = .excluded(excluded)
            reason = "Left out: " + leftOutText(excluded)
        } else {
            let today = rating.value * fitness.product
            let limiting = limitingFactor(fitness)
            cause = .lowerMatchDayValue(ideal: rating.value, today: today, limiting: limiting)
            if fitness.condition == 1 && fitness.sharpness == 1 && fitness.jadedness == 1 {
                reason = "Left out: others are a better fit today"
            } else {
                let input = switch limiting {
                case .condition: "condition \(percent(player.condition))"
                case .sharpness: "sharpness \(percent(player.sharpness))"
                case .jadedness: "jadedness \(player.jadedness)"
                }
                reason = "Left out: \(input) lowers him from \(oneDecimal(rating.value)) to \(oneDecimal(today))"
            }
        }
        return Omission(player: player.id, name: player.name, slot: slot, cause: cause, reason: reason)
    }

    /// The smallest factor; ties go to condition, then sharpness, then jadedness.
    private func limitingFactor(_ fitness: FitnessFactors) -> FactorKind {
        var limiting = (kind: FactorKind.condition, factor: fitness.condition)
        for candidate in [(kind: FactorKind.sharpness, factor: fitness.sharpness), (.jadedness, fitness.jadedness)]
        where candidate.factor < limiting.factor {
            limiting = candidate
        }
        return limiting.kind
    }

    /// The broken rule, in plain words, as it follows "overriding: ".
    private func rule(_ exclusion: Exclusion) -> String {
        switch exclusion {
        case .injured: "injured"
        case .outOnLoan(let club): "on loan at \(club)"
        case .banned: "banned"
        case .belowConditionFloor(let condition):
            "condition \(percent(condition)) is below the \(percent(parameters.conditionFloor.value)) floor"
        case .jaded(let jadedness): "jadedness \(jadedness) is above \(parameters.jadedThreshold.value)"
        case .rejected: "rejected for this fixture"
        }
    }

    /// The exclusion as it follows "Left out: ".
    private func leftOutText(_ exclusion: Exclusion) -> String {
        switch exclusion {
        case .banned: "banned for this fixture"
        case .belowConditionFloor(let condition):
            "below the \(percent(parameters.conditionFloor.value)) condition floor at \(percent(condition))"
        default: rule(exclusion)
        }
    }

    private func percent(_ fraction: Double) -> String { "\(Int((fraction * 100).rounded()))%" }
    private func oneDecimal(_ x: Double) -> String { String(format: "%.1f", x) }
    private func twoDecimals(_ x: Double) -> String { String(format: "%.2f", x) }
}
