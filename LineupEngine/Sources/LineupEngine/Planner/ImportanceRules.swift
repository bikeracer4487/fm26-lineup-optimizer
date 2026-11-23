/// What the importance rules need to know about one fixture.
public struct RuleContext: Sendable {
    public var importance: Importance
    public var date: Day
    public var assignments: [SlotAssignment]
    public var ownClub: String?
    public var history: StartHistory
    public var tiers: SquadTiers
    public var retraining: [Retraining]
    /// The players the owner has marked to sell or to loan out.
    public var marks: [PlayerID: SaleMark]
    /// The manager's stability setting, 0 (none) to 1 (full).
    public var stability: Double
    /// Each developing player's outlook for the fixture's tactic (`Development.outlooks`, from tiers with injured
    /// players kept in). A player without one gets no development favour.
    public var outlooks: [PlayerID: Outlook] = [:]
    /// The manager's Development setting, 0 (no development favour) to 1 (in full).
    public var development: Double = 1
    /// The only successors who may be favoured (`ImportanceRules.successors`), which the planner sets for a medium
    /// fixture; nil means no cap applies.
    public var successorsFavoured: Set<PlayerID>? = nil
    /// The players Player Removal advises to move on (`RemovalReport.advisedToLeave`), as the planner is handed them:
    /// neither development favour goes to them.
    public var advisedToLeave: Set<PlayerID> = []

    public init(importance: Importance, date: Day, assignments: [SlotAssignment], ownClub: String?, history: StartHistory,
                tiers: SquadTiers, retraining: [Retraining], marks: [PlayerID: SaleMark] = [:], stability: Double,
                outlooks: [PlayerID: Outlook] = [:], development: Double = 1, successorsFavoured: Set<PlayerID>? = nil,
                advisedToLeave: Set<PlayerID> = []) {
        self.importance = importance; self.date = date; self.assignments = assignments; self.ownClub = ownClub
        self.history = history; self.tiers = tiers; self.retraining = retraining; self.marks = marks
        self.stability = stability; self.outlooks = outlooks; self.development = development
        self.successorsFavoured = successorsFavoured; self.advisedToLeave = advisedToLeave
    }
}

/// The match-importance rules, as adjustments to a player's match-day value with the reason for each.
public enum ImportanceRules {
    /// Every adjustment except saving players for later, for one player on his current fitness.
    /// Both lists are in `Adjustment.Kind` order; `bySlot` covers only the slots in `context.assignments`.
    public static func adjustments(for player: Player, context: RuleContext, parameters: EngineParameters)
        -> (everySlot: [Adjustment], bySlot: [SlotID: [Adjustment]]) {
        let successor = successorFavour(player, context, parameters)

        var everySlot: [Adjustment] = []
        everySlot += loanedIn(player, context, parameters)
        everySlot += consecutiveStarts(player, context, parameters)
        everySlot += needsSharpness(player, context, parameters, isFavouredSuccessor: !successor.isEmpty)
        everySlot += shopWindow(player, context, parameters)

        let recent = context.history.recentSlots(
            of: player.id, before: context.date, limit: parameters.stabilityAnchorRun.value)
        let floor = developmentFloor(player, context, parameters)
        // The floor goes only to the slots he can play, as his outlook lists them.
        let playable = Set(context.outlooks[player.id]?.slots.map(\.slot) ?? [])

        var bySlot: [SlotID: [Adjustment]] = [:]
        for assignment in context.assignments {
            var found: [Adjustment] = []
            let retrained = retraining(player, assignment, context, parameters)
            // The floor is the same at every slot he can play; it is kept in each slot's own list so the successor's
            // favour can take its place at one. It and retraining multiply.
            let asNonSuccessor = (playable.contains(assignment.slot) ? floor : []) + retrained
            if let favour = successor[assignment.slot] {
                found += atSuccessorSlot(favour, asNonSuccessor: asNonSuccessor, retrained: retrained)
            } else {
                found += asNonSuccessor
            }
            found += stability(recent, assignment, context, parameters)
            bySlot[assignment.slot] = found.sorted(by: inKindOrder)
        }
        return (everySlot.sorted(by: inKindOrder), bySlot)
    }

    /// The successors a medium fixture may favour: among `players` (the planner hands only those it could pick for the
    /// fixture) who are a successor at some slot of the fixture's tactic and have not had their matches this month, the
    /// `successorsFavouredAtMedium` closest to their first choice. Closest is the greatest of his rating ÷ the first
    /// choice's rating over his successor slots, where a first choice rated 0 counts as already passed (infinitely
    /// close); ties go to the lower key. The planner puts the result in `RuleContext.successorsFavoured` for a medium
    /// fixture; low and sharpness fixtures have no cap.
    /// A player advised to leave takes no place, nor does one who would carry the successor's favour at none of his
    /// successor slots, because the floor and retraining together come to at least as much at each (`atSuccessorSlot`).
    public static func successors(players: [Player], context: RuleContext, parameters: EngineParameters) -> Set<PlayerID> {
        guard let factor = successorFactor(context, parameters) else { return [] }
        let ranked: [(id: PlayerID, closeness: Double)] = players.compactMap { player in
            guard !context.advisedToLeave.contains(player.id) else { return nil }
            let floor = developmentFloor(player, context, parameters)
            let playable = Set(context.outlooks[player.id]?.slots.map(\.slot) ?? [])
            let slots = successorSlots(player, context, parameters).filter { found in
                guard let assignment = context.assignments.first(where: { $0.slot == found.slot.slot }) else { return false }
                let retrained = retraining(player, assignment, context, parameters)
                let asNonSuccessor = (playable.contains(assignment.slot) ? floor : []) + retrained
                return retrained.isEmpty || !keepsTheFloorAndRetraining(factor, asNonSuccessor)
            }
            guard !slots.isEmpty, !hasHadHisMatches(player, context, parameters) else { return nil }
            let closeness = slots.map { $0.rival.rating > 0 ? $0.slot.rating / $0.rival.rating : .infinity }.max()!
            return (player.id, closeness)
        }
        let closestFirst = ranked.sorted { a, b in
            a.closeness != b.closeness ? a.closeness > b.closeness : a.id.key < b.id.key
        }
        return Set(closestFirst.prefix(max(0, parameters.successorsFavouredAtMedium.value)).map(\.id))
    }

    /// At a slot where he is a successor, the successor's favour takes the floor's place. Where he also has a retraining
    /// favour, all three reward matches at the slot, so he gets whichever is larger: the successor's favour alone, or
    /// the floor (where it applies) and retraining together, as a player who is no successor would have them there; the
    /// floor and retraining on a tie. Never all three.
    private static func atSuccessorSlot(_ favour: Adjustment, asNonSuccessor: [Adjustment],
                                        retrained: [Adjustment]) -> [Adjustment] {
        guard !retrained.isEmpty else { return [favour] }
        return keepsTheFloorAndRetraining(favour.factor, asNonSuccessor) ? asNonSuccessor : [favour]
    }

    /// Whether the floor and retraining, `asNonSuccessor`, multiplied in their order, come to at least the successor's
    /// `factor`.
    private static func keepsTheFloorAndRetraining(_ factor: Double, _ asNonSuccessor: [Adjustment]) -> Bool {
        asNonSuccessor.map(\.factor).reduce(1, *) >= factor
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

    /// The run of starts tires him wherever he plays next, so the factor applies in every slot.
    private static func consecutiveStarts(_ player: Player, _ context: RuleContext,
                                          _ parameters: EngineParameters) -> [Adjustment] {
        let run = runOfStarts(of: player.id, before: context.date, importance: context.importance,
                              history: context.history, parameters: parameters)
        guard let factor = run.factor else { return [] }
        return [Adjustment(kind: .consecutiveStarts, factor: factor,
                           reason: "Has started the last \(run.starts) matches in quick succession (×\(Display.twoDecimals(factor)))")]
    }

    /// His run of consecutive starts before `day`, and the factor the consecutive-starts rule gives it at `importance`:
    /// nil when the rule gives none (a high-importance match, no step reached, or a factor of 1). Each position he
    /// played during the run gives the highest step the run has reached there; the lowest of those factors applies.
    /// A position with no step reached, or missing from the table, gives none.
    static func runOfStarts(of player: PlayerID, before day: Day, importance: Importance, history: StartHistory,
                            parameters: EngineParameters) -> (starts: Int, factor: Double?) {
        let starts = history.consecutiveStarts(of: player, before: day, windowDays: parameters.consecutiveStartWindowDays.value)
        guard isLesser(importance) else { return (starts, nil) }
        let played = history.recentSlots(of: player, before: day, limit: starts).map(\.position)
        let factors = played.compactMap { position in
            parameters.consecutiveStartSteps.value[position]?
                .filter { $0.starts <= starts }.max { $0.starts < $1.starts }?.factor
        }
        guard let factor = factors.min(), factor != 1 else { return (starts, nil) }
        return (starts, factor)
    }

    /// The favour is for a regular who has lost his sharpness, so in a low or a sharpness fixture it goes only to a player
    /// in the first or second eleven for the fixture's tactic: one who is unsharp because he never plays is not favoured
    /// for it. A successor this fixture favours counts as in them for the favour, so he can be got sharp. Only a
    /// sharpness fixture marks down a player in the elevens who is already sharp, and not such a successor. (Until
    /// 22 November 2026 a low fixture favoured every unsharp player, and at 46% sharpness a fringe player was worth more
    /// unsharp than sharp.)
    private static func needsSharpness(_ player: Player, _ context: RuleContext, _ parameters: EngineParameters,
                                       isFavouredSuccessor: Bool) -> [Adjustment] {
        let full = parameters.sharpnessNeedFull.value
        let need = min(max((full - player.sharpness) / (full - parameters.sharpnessNeedMost.value), 0), 1)
        // A sharpness fixture is there to build sharpness: a larger favour, and a mark-down for the sharp.
        let buildsSharpness: Bool
        switch context.importance {
        case .high, .medium: return []
        case .low: buildsSharpness = false
        case .sharpness: buildsSharpness = true
        }
        let inElevens = context.tiers.slot(of: player.id) != nil
        guard inElevens || (isFavouredSuccessor && player.sharpness < full) else { return [] }
        if buildsSharpness, player.sharpness >= full {
            let factor = parameters.fullySharpFactor.value
            guard factor != 1 else { return [] }
            return [Adjustment(kind: .needsSharpness, factor: factor,
                               reason: "Already sharp: others need the minutes more (×\(Display.twoDecimals(factor)))")]
        }
        let strength = buildsSharpness ? parameters.sharpnessNeedStrengthBuild.value : parameters.sharpnessNeedStrengthLow.value
        let factor = 1 + strength * need
        guard factor != 1 else { return [] }
        return [Adjustment(kind: .needsSharpness, factor: factor,
                           reason: "Needs minutes: sharpness \(Display.percent(player.sharpness)) (×\(Display.twoDecimals(factor)))")]
    }

    /// The floor every developing prospect gets in a low or sharpness fixture, at each slot his outlook says he can play:
    /// aged `developingUpToAge` or under, with potential at least `prospectHeadroom` times his ability and an outlook
    /// Player Removal calls worth developing (`Removal.isWorthDeveloping`: first choice at a slot he can play, a reach
    /// that could pass the first choice or make the second eleven, or no level), so the plan favours nobody the advice
    /// would not develop. (Until 22 November 2026 only a markedly lower outlook was left out, and a player whose reach
    /// was cover at best was favoured.) Its size is what a match is worth to his growth at his age (`developmentFactors`, or
    /// `developmentFactorLowProfessionalism` for a young teenager with low Professionalism), scaled by the Development
    /// setting. He has none once he has had his matches for the month (`hasHadHisMatches`), nor when he is advised to
    /// leave (`RuleContext.advisedToLeave`).
    private static func developmentFloor(_ player: Player, _ context: RuleContext,
                                         _ parameters: EngineParameters) -> [Adjustment] {
        switch context.importance {
        case .high, .medium: return []
        case .low, .sharpness: break
        }
        // The margin absorbs binary floating-point error: 1.10 × 100 is 110.00000000000001.
        guard context.development > 0, !context.advisedToLeave.contains(player.id),
              player.age <= parameters.developingUpToAge.value,
              Double(player.potentialAbility) + 1e-9 >= parameters.prospectHeadroom.value * Double(player.currentAbility),
              let outlook = context.outlooks[player.id], Removal.isWorthDeveloping(outlook),
              !hasHadHisMatches(player, context, parameters)
        else { return [] }
        let base: Double
        // His Professionalism as his outlook's estimate read it, so a missing value was already an error there.
        if player.age <= parameters.developmentLowProfessionalismUpToAge.value,
           outlook.estimate.professionalism <= parameters.developmentLowProfessionalismUpTo.value {
            base = parameters.developmentFactorLowProfessionalism.value
        } else if let step = parameters.developmentFactors.value.first(where: { player.age <= $0.upToAge }) {
            base = step.factor
        } else {
            return []
        }
        let factor = 1 + (base - 1) * context.development
        guard factor != 1 else { return [] }
        return [Adjustment(kind: .development, factor: factor, reason: AdvisorText.developmentFloor(factor))]
    }

    /// The successor's favour at each slot of the fixture's tactic where he is a successor (`successorSlots`):
    /// `successorFactorLow` in a low or sharpness fixture, `successorFactorMedium` in a medium one and nothing in a high
    /// one, scaled by the Development setting as the floor is. None once he has had his matches for the month, nor in a
    /// fixture whose cap (`RuleContext.successorsFavoured`) leaves him out, nor when he is advised to leave.
    private static func successorFavour(_ player: Player, _ context: RuleContext,
                                        _ parameters: EngineParameters) -> [SlotID: Adjustment] {
        guard let factor = successorFactor(context, parameters), !context.advisedToLeave.contains(player.id),
              context.successorsFavoured?.contains(player.id) ?? true,
              !hasHadHisMatches(player, context, parameters) else { return [:] }
        var found: [SlotID: Adjustment] = [:]
        for (slot, rival, isClose) in successorSlots(player, context, parameters) {
            found[slot.slot] = Adjustment(
                kind: .successor, factor: factor,
                reason: AdvisorText.successor(isClose: isClose, passing: rival.name, at: PositionText.plain(slot.slot),
                                              factor: factor))
        }
        return found
    }

    /// The successor's favour in the fixture, scaled by the Development setting; nil in a high fixture, with the setting
    /// at 0, or where it comes to 1.
    private static func successorFactor(_ context: RuleContext, _ parameters: EngineParameters) -> Double? {
        let base: Double
        switch context.importance {
        case .high: return nil
        case .medium: base = parameters.successorFactorMedium.value
        case .low, .sharpness: base = parameters.successorFactorLow.value
        }
        guard context.development > 0 else { return nil }
        let factor = 1 + (base - 1) * context.development
        return factor != 1 ? factor : nil
    }

    /// The slots of the fixture's tactic where he is a successor, in his outlook's order, each with the first choice he
    /// is expected to pass and whether he is close. He is aged `developingUpToAge` or under with an outlook that is not
    /// markedly lower; he is first choice at no slot of the tactic (he has his matches already, and a favour would only
    /// move him between slots); and his band against the slot's first choice is close, or on course for a player older
    /// than `successorCloseOnlyUpToAge`. The band already compares a first choice who is developing too at his own reach.
    private static func successorSlots(_ player: Player, _ context: RuleContext, _ parameters: EngineParameters)
        -> [(slot: SlotOutlook, rival: Rival, isClose: Bool)] {
        guard player.age <= parameters.developingUpToAge.value,
              let outlook = context.outlooks[player.id], !outlook.isMarkedlyLower else { return [] }
        let inTactic = Set(context.assignments.map(\.slot))
        let slots = outlook.slots.filter { inTactic.contains($0.slot) }
        guard !slots.contains(where: \.isFirstChoice) else { return [] }
        return slots.compactMap { slot in
            guard let rival = slot.firstChoice, let band = slot.band else { return nil }
            switch band {
            case .close:
                return (slot, rival, true)
            case .onCourse:
                return player.age > parameters.successorCloseOnlyUpToAge.value ? (slot, rival, false) : nil
            case .possible, .notExpected:
                return nil
            }
        }
    }

    /// He has started `developmentStartsPerMonth` matches in the `developmentMonthDays` days before the fixture, planned
    /// starts included: the game reads only so much match time a month, so neither development favour applies.
    private static func hasHadHisMatches(_ player: Player, _ context: RuleContext, _ parameters: EngineParameters) -> Bool {
        context.history.starts(of: player.id, inDays: parameters.developmentMonthDays.value,
                               endingOn: context.date.adding(days: -1)) >= parameters.developmentStartsPerMonth.value
    }

    /// The owner's belief that minutes bring offers is untested, so the factor only breaks near-ties, and only where
    /// the result matters least.
    private static func shopWindow(_ player: Player, _ context: RuleContext, _ parameters: EngineParameters) -> [Adjustment] {
        switch context.importance {
        case .high, .medium: return []
        case .low, .sharpness: break
        }
        let factor = parameters.shopWindowFactor.value
        guard let mark = context.marks[player.id], factor != 1 else { return [] }
        // A mark made before he became a loanee must not favour another club's player.
        if case .loanedIn = LoanStatus.of(player, ownClub: context.ownClub) { return [] }
        // A player on a youth contract can be sold and cannot be loaned out (the owner's correction of 22 November
        // 2026), so a mark to sell favours him as it does anyone, and a mark to loan out held from a file means nothing.
        // Read as Player Removal reads it: one with 0 months left is no contract.
        let words: String
        switch mark {
        case .toSell: words = "to sell"
        case .toLoanOut:
            if Removal.isOnYouthContract(player) { return [] }
            words = "to loan out"
        }
        return [Adjustment(kind: .shopWindow, factor: factor,
                           reason: "Marked \(words): favoured for minutes, an untested way to bring offers (×\(Display.twoDecimals(factor)))")]
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
                reason: "Retraining at \(PositionText.plain(item.position)) (familiarity \(familiarity)): favoured for match experience there (×\(Display.twoDecimals(factor)))")))
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
