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
    /// Adjustments to a player's value in every slot.
    public var adjustments: [PlayerID: [Adjustment]]
    /// Adjustments to a player's value in one slot only.
    public var slotAdjustments: [PlayerID: [SlotID: [Adjustment]]]
    /// True when the players' condition, sharpness and jadedness are projected to the fixture rather
    /// than read from the game today; the fitness lines then say so.
    public var fitnessIsProjected: Bool

    public init(tactic: Tactic, players: [Player], ownClub: String?, importance: Importance, isNextFixture: Bool,
                overrides: [SlotID: PlayerID], rejected: Set<PlayerID>, adjustments: [PlayerID: [Adjustment]] = [:],
                slotAdjustments: [PlayerID: [SlotID: [Adjustment]]] = [:], fitnessIsProjected: Bool = false) {
        self.tactic = tactic; self.players = players; self.ownClub = ownClub; self.importance = importance
        self.isNextFixture = isNextFixture; self.overrides = overrides; self.rejected = rejected
        self.adjustments = adjustments; self.slotAdjustments = slotAdjustments; self.fitnessIsProjected = fitnessIsProjected
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
    /// `rating.value × fitness.product × (product of the adjustments' factors) − (sum of their costs)`;
    /// negative when the costs outweigh the rest.
    public let value: Double
    public let isOverride: Bool
    public let warnings: [PickWarning]
    /// Plain sentences for the manager: the rating line, then the fitness lines, then each adjustment's
    /// reason, then the override line.
    public let reasons: [String]
    /// The adjustments applied to this player in this slot, in `Adjustment.Kind` order.
    public let adjustments: [Adjustment]

    public init(slot: SlotID, player: PlayerID, name: String, rating: SlotRating, fitness: FitnessFactors,
                value: Double, isOverride: Bool, warnings: [PickWarning], reasons: [String], adjustments: [Adjustment] = []) {
        self.slot = slot; self.player = player; self.name = name; self.rating = rating; self.fitness = fitness
        self.value = value; self.isOverride = isOverride; self.warnings = warnings; self.reasons = reasons
        self.adjustments = adjustments
    }
}

public enum OmissionCause: Equatable, Sendable {
    case excluded(Exclusion)
    /// `ideal` is his full-fitness value in his slot (`Omission.slot`), `today` that value times his fitness product.
    case lowerMatchDayValue(ideal: Double, today: Double, limiting: FactorKind)
    /// He would start without the manager's overrides. `by` is the player chosen for his slot
    /// (`Omission.slot`) when there is one; otherwise every applied override's player, in slot order.
    case displacedByOverride(by: [PlayerID])
    /// Adjustments that lower his value in his slot (`Omission.slot`; a factor below 1 or a cost above 0), by
    /// distinct kind in `Adjustment.Kind` order.
    case heldBack([Adjustment.Kind])
}

/// A first-choice player who is not in the real eleven: one in the ideal eleven (full fitness, nobody excluded),
/// or one in the best available eleven (the same, without the players excluded for this fixture) who is not
/// in the ideal one.
public struct Omission: Equatable, Sendable {
    public let player: PlayerID
    public let name: String
    /// His slot in the ideal eleven, or for a player not in it, his slot in the best available eleven.
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
    /// The ideal eleven's omissions in its slot order, then the best available eleven's in its slot order.
    /// A player is listed at most once.
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

    public init(catalog: RoleCatalog, profile: RatingProfile, parameters: EngineParameters, configuration: RatingConfiguration = .fm27) {
        self.catalog = catalog
        self.engine = RatingEngine(profile: profile, parameters: parameters, configuration: configuration)
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
        // applied[slot][candidate]: the adjustments to his value in that slot, in Kind order.
        let applied: [[[Adjustment]]] = assignments.map { assignment in
            players.map { adjustments(for: $0.id, in: assignment.slot, request) }
        }

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

        // The real eleven: available players at adjusted match-day value, around the overrides. The
        // solver fills every slot it can before it looks at value, so a player whose adjusted value is
        // zero or negative is still a candidate.
        func solve(around fixed: [Int: Int]) -> [Int: Int] {
            var placed = fixed
            let openSlots = assignments.indices.filter { fixed[$0] == nil }
            let fixedPlayers = Set(fixed.values)
            let candidates = players.indices.filter { !fixedPlayers.contains($0) }
            let values: [[Double?]] = openSlots.map { s in
                candidates.map { i in
                    exclusions[i] == nil ? ratings[s][i].map { adjustedValue(matchDayValue($0, fitness[i]), applied[s][i]) } : nil
                }
            }
            for (row, choice) in AssignmentSolver.maximise(values: values).enumerated() {
                if let c = choice { placed[openSlots[row]] = candidates[c] }
            }
            return placed
        }
        placed = solve(around: placed)

        var picks: [Pick] = []
        var unfilled: [SlotID] = []
        for (s, assignment) in assignments.enumerated() {
            guard let i = placed[s], let rating = ratings[s][i] else { unfilled.append(assignment.slot); continue }
            let isOverride = overridden.contains(s)
            picks.append(pick(assignment, players[i], rating: rating, fitness: fitness[i], adjustments: applied[s][i],
                              isOverride: isOverride, broken: isOverride ? exclusions[i] : nil,
                              projected: request.fitnessIsProjected))
        }

        // Who would start with the same availability but no overrides: an omitted player among them
        // was displaced by the manager's choices, not by his fitness.
        let startsWithoutOverrides = overridden.isEmpty ? [] : Set(solve(around: [:]).values)
        let overridePlayers = overridden.sorted().map { players[placed[$0]!] }

        // The ideal eleven: everyone not out on loan, at full fitness, with no exclusions, overrides or adjustments.
        let ideal = AssignmentSolver.maximise(values: ratings.map { row in row.map { $0?.value } })
        // The best available eleven: the same, over the players not excluded for this fixture. An injured player
        // can hold a slot in the ideal eleven; the first choice among those who can play is in this one.
        let available = AssignmentSolver.maximise(values: ratings.map { row in
            row.indices.map { i in exclusions[i] == nil ? row[i]?.value : nil }
        })
        let inLineup = Set(placed.values)
        var omissions: [Omission] = []
        var omitted = Set<Int>()
        for eleven in [ideal, available] {
            for (s, choice) in eleven.enumerated() {
                guard let i = choice, !inLineup.contains(i), !omitted.contains(i), let rating = ratings[s][i] else { continue }
                let displacement: Displacement? = !startsWithoutOverrides.contains(i) ? nil
                    : overridden.contains(s) ? .inHisSlot(by: players[placed[s]!]) : .elsewhere(by: overridePlayers)
                omissions.append(omission(players[i], assignments[s], rating: rating, fitness: fitness[i], adjustments: applied[s][i],
                                          excluded: exclusions[i], displacement: displacement, projected: request.fitnessIsProjected))
                omitted.insert(i)
            }
        }

        return Lineup(picks: picks, unfilled: unfilled, omissions: omissions, ignoredOverrides: ignored)
    }

    /// What the solver maximises and every explanation reports: the slot rating scaled by condition,
    /// sharpness and jadedness on the day.
    private func matchDayValue(_ rating: SlotRating, _ fitness: FitnessFactors) -> Double {
        rating.value * fitness.product
    }

    /// `value` times the adjustments' factors, less their costs, each taken in the order given. With no
    /// adjustments it is `value` exactly (× 1 and − 0 are exact).
    private func adjustedValue(_ value: Double, _ adjustments: [Adjustment]) -> Double {
        var factor = 1.0
        var cost = 0.0
        for adjustment in adjustments {
            factor *= adjustment.factor
            cost += adjustment.cost
        }
        return value * factor - cost
    }

    /// The player's adjustments in `slot`: by kind in `Adjustment.Kind` order and, within a kind, those
    /// for every slot before those for this slot, each in the order given.
    private func adjustments(for player: PlayerID, in slot: SlotID, _ request: SelectionRequest) -> [Adjustment] {
        let everySlot = request.adjustments[player] ?? []
        let thisSlot = request.slotAdjustments[player]?[slot] ?? []
        guard !everySlot.isEmpty || !thisSlot.isEmpty else { return [] }
        return Adjustment.Kind.allCases.flatMap { kind in
            everySlot.filter { $0.kind == kind } + thisSlot.filter { $0.kind == kind }
        }
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
                      adjustments: [Adjustment], isOverride: Bool, broken: Exclusion?, projected: Bool) -> Pick {
        var warnings: [PickWarning] = []
        for (phase, phaseRating) in [(Phase.inPossession, rating.inPossession), (.outOfPossession, rating.outOfPossession)]
        where phaseRating.familiarity < parameters.outOfPositionBelow.value {
            warnings.append(.outOfPosition(phase, familiarity: phaseRating.familiarity))
        }
        if let broken { warnings.append(.overridesRule(broken)) }

        var reasons = ["Rating \(oneDecimal(rating.value)): "
            + "\(assignment.ipPosition.rawValue) familiarity \(rating.inPossession.familiarity) in possession, "
            + "\(assignment.oopPosition.rawValue) familiarity \(rating.outOfPossession.familiarity) out of possession"]
        func label(_ name: String) -> String { projected ? "Projected " + name.lowercased() : name }
        if fitness.condition < 1 { reasons.append("\(label("Condition")) \(percent(player.condition)) (×\(twoDecimals(fitness.condition)))") }
        if fitness.sharpness < 1 { reasons.append("\(label("Sharpness")) \(percent(player.sharpness)) (×\(twoDecimals(fitness.sharpness)))") }
        if fitness.jadedness < 1 { reasons.append("\(label("Jadedness")) \(player.jadedness) (×\(twoDecimals(fitness.jadedness)))") }
        reasons += adjustments.map(\.reason)
        if isOverride { reasons.append("Chosen by you" + (broken.map { ", overriding: \(rule($0, projected: projected))" } ?? "")) }

        return Pick(slot: assignment.slot, player: player.id, name: player.name, rating: rating, fitness: fitness,
                    value: adjustedValue(matchDayValue(rating, fitness), adjustments), isOverride: isOverride,
                    warnings: warnings, reasons: reasons, adjustments: adjustments)
    }

    /// How the manager's overrides cost a first-choice player his place.
    private enum Displacement {
        /// His slot holds the player chosen for it.
        case inHisSlot(by: Player)
        /// The overrides, in slot order, moved others into his place.
        case elsewhere(by: [Player])
    }

    /// The cause, first that applies: an exclusion, a displacement by an override, adjustments that
    /// lower his value in `assignment`'s slot, his fitness on the day. With `projected`, fitness figures are called projected.
    private func omission(_ player: Player, _ assignment: SlotAssignment, rating: SlotRating, fitness: FitnessFactors,
                          adjustments: [Adjustment], excluded: Exclusion?, displacement: Displacement?, projected: Bool) -> Omission {
        let holding = adjustments.filter(\.holdsBack)
        let cause: OmissionCause
        let reason: String
        if let excluded {
            cause = .excluded(excluded)
            reason = "Left out: " + leftOutText(excluded, projected: projected)
        } else if let displacement {
            switch displacement {
            case .inHisSlot(let chosen):
                cause = .displacedByOverride(by: [chosen.id])
                reason = "Left out: you chose \(chosen.name) for \(assignment.ipPosition.rawValue)"
            case .elsewhere(let chosen):
                cause = .displacedByOverride(by: chosen.map(\.id))
                reason = "Left out: your choice of \(listed(chosen.map(\.name))) moved others into his place"
            }
        } else if !holding.isEmpty {
            let kinds = Adjustment.Kind.allCases.filter { kind in holding.contains { $0.kind == kind } }
            cause = .heldBack(kinds)
            reason = "Left out: " + holding.map(\.reason).joined(separator: "; ")
        } else {
            let today = matchDayValue(rating, fitness)
            cause = .lowerMatchDayValue(ideal: rating.value, today: today, limiting: limitingFactor(fitness))
            let below = [(FactorKind.condition, fitness.condition), (.sharpness, fitness.sharpness), (.jadedness, fitness.jadedness)]
                .filter { $0.1 < 1 }
                .map { kind, _ in
                    switch kind {
                    case .condition: "condition \(percent(player.condition))"
                    case .sharpness: "sharpness \(percent(player.sharpness))"
                    case .jadedness: "jadedness \(player.jadedness)"
                    }
                }
            let fall = "lowers him from \(oneDecimal(rating.value)) to \(oneDecimal(today))"
            let figures = projected ? "projected " : ""
            reason = switch below.count {
            case 0: "Left out: others are a better fit today"
            case 1: "Left out: \(figures)\(below[0]) \(fall)"
            default: "Left out: \(figures)fitness \(fall) (\(below.joined(separator: ", ")))"
            }
        }
        return Omission(player: player.id, name: player.name, slot: assignment.slot, cause: cause, reason: reason)
    }

    /// "A", "A and B", "A, B and C".
    private func listed(_ names: [String]) -> String {
        guard let last = names.last, names.count > 1 else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " and " + last
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

    /// The broken rule, in plain words, as it follows "overriding: ". With `projected`, a fitness figure is called projected.
    private func rule(_ exclusion: Exclusion, projected: Bool) -> String {
        let figure = projected ? "projected " : ""
        return switch exclusion {
        case .injured: "injured"
        case .outOnLoan(let club): "on loan at \(club)"
        case .banned: "banned"
        case .belowConditionFloor(let condition):
            "\(figure)condition \(percent(condition)) is below the \(percent(parameters.conditionFloor.value)) floor"
        case .jaded(let jadedness): "\(figure)jadedness \(jadedness) is above \(parameters.jadedThreshold.value)"
        case .rejected: "rejected for this fixture"
        }
    }

    /// The exclusion as it follows "Left out: ". A projected condition leads with the figure, so "projected" sits beside it.
    private func leftOutText(_ exclusion: Exclusion, projected: Bool) -> String {
        switch exclusion {
        case .banned: "banned for this fixture"
        case .belowConditionFloor(let condition) where !projected:
            "below the \(percent(parameters.conditionFloor.value)) condition floor at \(percent(condition))"
        case .injured, .outOnLoan, .belowConditionFloor, .jaded, .rejected: rule(exclusion, projected: projected)
        }
    }

    private func percent(_ fraction: Double) -> String { Display.percent(fraction) }
    private func oneDecimal(_ x: Double) -> String { String(format: "%.1f", x) }
    private func twoDecimals(_ x: Double) -> String { Display.twoDecimals(x) }
}

/// How figures are written in the reasons the engine gives.
enum Display {
    /// Absorbs binary floating-point error (0.84 × 100 is 83.999…) before rounding down; far below
    /// the importer's 1/10,000 resolution.
    private static let displayNoise = 1e-9

    /// A whole percentage rounded down, so a value shown never reaches a threshold or 100% it has not reached.
    static func percent(_ fraction: Double) -> String { "\(Int((fraction * 100 + displayNoise).rounded(.down)))%" }
    static func twoDecimals(_ x: Double) -> String { String(format: "%.2f", x) }
}
