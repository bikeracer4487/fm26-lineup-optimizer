/// What the importance rules need to know about one fixture.
public struct RuleContext: Sendable {
    public var importance: Importance
    public var date: Day
    public var assignments: [SlotAssignment]
    public var ownClub: String?
    public var history: StartHistory
    public var tiers: SquadTiers
    public var retraining: [Retraining]
    /// The manager's stability setting, 0 (none) to 1 (full).
    public var stability: Double

    public init(importance: Importance, date: Day, assignments: [SlotAssignment], ownClub: String?, history: StartHistory,
                tiers: SquadTiers, retraining: [Retraining], stability: Double) {
        self.importance = importance; self.date = date; self.assignments = assignments; self.ownClub = ownClub
        self.history = history; self.tiers = tiers; self.retraining = retraining; self.stability = stability
    }
}

/// The match-importance rules, as adjustments to a player's match-day value with the reason for each.
public enum ImportanceRules {
    /// Every adjustment except saving players for later, for one player on his current fitness.
    /// Both lists are in `Adjustment.Kind` order; `bySlot` covers only the slots in `context.assignments`.
    public static func adjustments(for player: Player, context: RuleContext, parameters: EngineParameters)
        -> (everySlot: [Adjustment], bySlot: [SlotID: [Adjustment]]) {
        var everySlot: [Adjustment] = []
        everySlot += loanedIn(player, context, parameters)
        everySlot += consecutiveStarts(player, context, parameters)
        everySlot += needsSharpness(player, context, parameters)
        everySlot += development(player, context, parameters)

        let recent = context.history.recentSlots(
            of: player.id, before: context.date, limit: parameters.stabilityAnchorRun.value)

        var bySlot: [SlotID: [Adjustment]] = [:]
        for assignment in context.assignments {
            var found: [Adjustment] = []
            found += retraining(player, assignment, context, parameters)
            found += stability(recent, assignment, context, parameters)
            bySlot[assignment.slot] = found.sorted(by: inKindOrder)
        }
        return (everySlot.sorted(by: inKindOrder), bySlot)
    }

    private static func inKindOrder(_ a: Adjustment, _ b: Adjustment) -> Bool {
        Adjustment.Kind.allCases.firstIndex(of: a.kind)! < Adjustment.Kind.allCases.firstIndex(of: b.kind)!
    }

    private static func isLesser(_ importance: Importance) -> Bool {
        switch importance {
        case .high: false
        case .medium, .low, .sharpness: true
        }
    }

    private static func loanedIn(_ player: Player, _ context: RuleContext, _ parameters: EngineParameters) -> [Adjustment] {
        guard case .loanedIn = LoanStatus.of(player, ownClub: context.ownClub),
              let factor = parameters.loanedInFactor.value[context.importance], factor != 1 else { return [] }
        return [Adjustment(kind: .loanedIn, factor: factor,
                           reason: "On loan here: marked down so the club's own players get the minutes (×\(Display.twoDecimals(factor)))")]
    }

    /// The run of starts tires him wherever he plays next, so the factor applies in every slot. Each position he
    /// played during the run gives the highest step the run has reached there; the lowest of those factors applies.
    /// A position with no step reached, or missing from the table, gives none.
    private static func consecutiveStarts(_ player: Player, _ context: RuleContext,
                                          _ parameters: EngineParameters) -> [Adjustment] {
        guard isLesser(context.importance) else { return [] }
        let starts = context.history.consecutiveStarts(
            of: player.id, before: context.date, windowDays: parameters.consecutiveStartWindowDays.value)
        let played = context.history.recentSlots(of: player.id, before: context.date, limit: starts).map(\.position)
        let factors = played.compactMap { position in
            parameters.consecutiveStartSteps.value[position]?
                .filter { $0.starts <= starts }.max { $0.starts < $1.starts }?.factor
        }
        guard let factor = factors.min(), factor != 1 else { return [] }
        return [Adjustment(kind: .consecutiveStarts, factor: factor,
                           reason: "Has started the last \(starts) matches in quick succession (×\(Display.twoDecimals(factor)))")]
    }

    private static func needsSharpness(_ player: Player, _ context: RuleContext, _ parameters: EngineParameters) -> [Adjustment] {
        let full = parameters.sharpnessNeedFull.value
        let need = min(max((full - player.sharpness) / (full - parameters.sharpnessNeedMost.value), 0), 1)
        let strength: Double
        switch context.importance {
        case .high, .medium:
            return []
        case .low:
            strength = parameters.sharpnessNeedStrengthLow.value
        case .sharpness:
            guard context.tiers.slot(of: player.id) != nil else { return [] }
            if player.sharpness >= full {
                let factor = parameters.fullySharpFactor.value
                guard factor != 1 else { return [] }
                return [Adjustment(kind: .needsSharpness, factor: factor,
                                   reason: "Already sharp: others need the minutes more (×\(Display.twoDecimals(factor)))")]
            }
            strength = parameters.sharpnessNeedStrengthBuild.value
        }
        let factor = 1 + strength * need
        guard factor != 1 else { return [] }
        return [Adjustment(kind: .needsSharpness, factor: factor,
                           reason: "Needs minutes: sharpness \(Display.percent(player.sharpness)) (×\(Display.twoDecimals(factor)))")]
    }

    private static func development(_ player: Player, _ context: RuleContext, _ parameters: EngineParameters) -> [Adjustment] {
        switch context.importance {
        case .high, .medium: return []
        case .low, .sharpness: break
        }
        let factor = parameters.developmentFactor.value
        // The margin absorbs binary floating-point error: 1.10 × 100 is 110.00000000000001.
        guard player.age <= parameters.prospectMaxAge.value, factor != 1,
              Double(player.potentialAbility) + 1e-9 >= parameters.prospectHeadroom.value * Double(player.currentAbility)
        else { return [] }
        return [Adjustment(kind: .development, factor: factor,
                           reason: "Young player with room to grow: favoured for minutes (×\(Display.twoDecimals(factor)))")]
    }

    private static func retraining(_ player: Player, _ assignment: SlotAssignment, _ context: RuleContext,
                                   _ parameters: EngineParameters) -> [Adjustment] {
        let from: Int
        let factor: Double
        switch context.importance {
        case .high: return []
        case .medium:
            from = parameters.retrainingFromFamiliarityMedium.value
            factor = parameters.retrainingFactorMedium.value
        case .low, .sharpness:
            from = parameters.retrainingFromFamiliarity.value
            factor = parameters.retrainingFactorLow.value
        }
        guard factor != 1 else { return [] }
        var found: [(position: Position, adjustment: Adjustment)] = []
        for item in context.retraining where item.player == player.id
            && (item.position == assignment.ipPosition || item.position == assignment.oopPosition) {
            guard let familiarity = player.familiarity[item.position],
                  familiarity >= from, familiarity < parameters.retrainingUntilFamiliarity.value else { continue }
            found.append((item.position, Adjustment(
                kind: .retraining, factor: factor,
                reason: "Retraining at \(item.position.rawValue) (familiarity \(familiarity)): favoured for match experience there (×\(Display.twoDecimals(factor)))")))
        }
        // Retraining at both of the slot's positions favours him once: the higher factor, then the lower position.
        let kept = found.min { a, b in
            a.adjustment.factor != b.adjustment.factor ? a.adjustment.factor > b.adjustment.factor
                : a.position.rawValue < b.position.rawValue
        }
        return kept.map { [$0.adjustment] } ?? []
    }

    private static func stability(_ recent: [SlotID], _ assignment: SlotAssignment, _ context: RuleContext,
                                  _ parameters: EngineParameters) -> [Adjustment] {
        guard context.stability > 0, recent.first == assignment.slot else { return [] }
        let run = parameters.stabilityAnchorRun.value
        if recent.count == run, recent.allSatisfy({ $0 == assignment.slot }) {
            let factor = 1 + parameters.stabilityAnchorBonus.value * context.stability
            return [Adjustment(kind: .stability, factor: factor,
                               reason: "Has held this slot in his last \(run) starts (×\(Display.twoDecimals(factor)))")]
        }
        let factor = 1 + parameters.stabilityRecentBonus.value * context.stability
        return [Adjustment(kind: .stability, factor: factor, reason: "Held this slot in his last start (×\(Display.twoDecimals(factor)))")]
    }
}
