/// How urgently a player needs a break, most urgent first.
public enum RestLevel: String, CaseIterable, Sendable { case holiday, rest, watch }

/// One player who needs a holiday, rest or watching, and why.
public struct RestAdvice: Equatable, Sendable {
    public let player: PlayerID
    public let name: String
    public let level: RestLevel
    public let jadedness: Int
    /// His own jadedness limit.
    public let limit: Int
    /// Why his limit differs from the standard one, one note per adjustment that applied; empty when none did.
    public let limitNotes: [String]
    public let condition: Double
    /// His run of starts in quick succession up to and including the advice day.
    public let consecutiveStarts: Int
    /// Estimated days until he is clear; nil for watch, or when it cannot be told within the estimate's range.
    public let days: Int?
    public let reasons: [String]
    /// The weakest evidence among the parameters behind this advice.
    public let basis: Evidence
}

public enum Rest {
    /// The furthest ahead, in days, the condition estimate looks; beyond it the days are not known.
    private static let longestConditionEstimate = 14
    /// Absorbs binary floating-point error before a day count is rounded up, so an exact division is not a day more.
    private static let roundingNoise = 1e-9

    /// Players who need a holiday, rest or watching: most urgent first.
    /// Players out on loan and injured players are not looked at. Throws `PlanError.badParameters` when
    /// `FitnessModel.problems(in:)` finds problems, and `RatingError.missingAttribute` for a player without
    /// Natural Fitness, Stamina or Injury Proneness.
    public static func advice(players: [Player], ownClub: String?, history: StartHistory, asOf: Day,
                              intensity: TrainingIntensity, parameters: EngineParameters) throws -> [RestAdvice] {
        let problems = FitnessModel.problems(in: parameters)
        guard problems.isEmpty else { throw PlanError.badParameters(problems) }

        var found: [RestAdvice] = []
        for player in players.sorted(by: { $0.id.key < $1.id.key }) {
            if case .loanedOut = LoanStatus.of(player, ownClub: ownClub) { continue }
            guard !player.isInjured else { continue }
            if let advice = try advice(for: player, history: history, asOf: asOf, intensity: intensity, parameters: parameters) {
                found.append(advice)
            }
        }
        let rank = Dictionary(uniqueKeysWithValues: RestLevel.allCases.enumerated().map { ($1, $0) })
        return found.sorted { a, b in
            if a.level != b.level { return rank[a.level]! < rank[b.level]! }
            if a.jadedness != b.jadedness { return a.jadedness > b.jadedness }
            return a.player.key < b.player.key
        }
    }

    private static func advice(for player: Player, history: StartHistory, asOf: Day, intensity: TrainingIntensity,
                               parameters: EngineParameters) throws -> RestAdvice? {
        let (limit, notes) = try Self.limit(of: player, parameters: parameters)
        let jadedness = player.jadedness
        let watchLine = parameters.restWatchShare.value * Double(limit)
        let holidayMargin = parameters.holidayMargin.value
        let floor = parameters.conditionFloor.value
        // A lineup dated on the advice day counts, so the run is the one before the day after.
        let run = ImportanceRules.runOfStarts(of: player.id, before: asOf.adding(days: 1), importance: .medium,
                                              history: history, parameters: parameters)

        let needsHoliday = jadedness > limit + holidayMargin
        let overLimit = jadedness > limit
        let lowCondition = player.condition < floor
        let closeToLimit = Double(jadedness) > watchLine
        let runTells = (run.factor ?? 1) < 1

        let level: RestLevel
        if needsHoliday {
            level = .holiday
        } else if overLimit || lowCondition {
            level = .rest
        } else if closeToLimit || runTells {
            level = .watch
        } else {
            return nil
        }

        var reasons: [String] = []
        var evidence = [notes.isEmpty ? parameters.jadedThreshold.evidence : parameters.restLimitRules.evidence]
        var days: Int?
        switch level {
        case .holiday, .rest:
            var jadednessDays: Int?
            if needsHoliday {
                reasons.append("Jadedness \(jadedness) is more than \(holidayMargin) above his limit of \(limit): a holiday clears it fastest")
                evidence.append(parameters.holidayMargin.evidence)
                jadednessDays = daysDown(from: jadedness, to: watchLine, perDay: parameters.holidayJadednessRecoveryPerDay.value)
            } else if overLimit {
                reasons.append("Jadedness \(jadedness) is above his limit of \(limit): rest him from training and matches")
                jadednessDays = daysDown(from: jadedness, to: watchLine, perDay: parameters.jadednessRecoveryPerDay.value)
            }
            var conditionDays: Int?
            if lowCondition {
                reasons.append("Condition \(Display.percent(player.condition)) is below the \(Display.percent(floor)) floor")
                evidence.append(parameters.conditionFloor.evidence)
                conditionDays = try daysToFloor(player, intensity: intensity, parameters: parameters)
            }
            switch (overLimit, lowCondition) {
            case (true, true): days = jadednessDays.flatMap { j in conditionDays.map { max(j, $0) } }
            case (true, false): days = jadednessDays
            case (false, true): days = conditionDays
            case (false, false): days = nil
            }
        case .watch:
            if closeToLimit { reasons.append("Jadedness \(jadedness) is close to his limit of \(limit)") }
            if runTells { reasons.append("Has started the last \(run.starts) matches in quick succession") }
            evidence += [parameters.restWatchShare.evidence, parameters.consecutiveStartSteps.evidence,
                         parameters.consecutiveStartWindowDays.evidence]
        }

        return RestAdvice(player: player.id, name: player.name, level: level, jadedness: jadedness, limit: limit,
                          limitNotes: notes, condition: player.condition, consecutiveStarts: run.starts, days: days,
                          reasons: reasons, basis: Evidence.weakest(evidence)!)
    }

    /// His own jadedness limit and a note for each adjustment that made it differ from the standard threshold.
    static func limit(of player: Player, parameters: EngineParameters) throws -> (limit: Int, notes: [String]) {
        let rules = parameters.restLimitRules.value
        func attribute(_ attribute: Attribute) throws -> Int {
            guard let value = player.attributes[attribute] else {
                throw RatingError.missingAttribute(player: player.name, attribute: attribute)
            }
            return value
        }
        let naturalFitness = try attribute(.naturalFitness)
        let stamina = try attribute(.stamina)
        let injuryProneness = try attribute(.injuryProneness)

        var notes: [String] = []
        var limit: Int
        if player.age >= rules.oldestFromAge {
            limit = rules.oldestBase
            notes.append("aged \(rules.oldestFromAge) or over")
        } else if player.age >= rules.olderFromAge {
            limit = rules.olderBase
            notes.append("aged \(rules.olderFromAge) or \(rules.oldestFromAge - 1)")
        } else if player.age < rules.youngUnderAge {
            limit = rules.youngBase
            notes.append("under \(rules.youngUnderAge)")
        } else {
            limit = parameters.jadedThreshold.value
        }

        func adjust(_ applies: Bool, by change: Int, _ note: String) {
            guard applies else { return }
            limit += change
            notes.append(note)
        }
        adjust(naturalFitness < rules.naturalFitnessBelow, by: rules.naturalFitnessLowChange,
               "Natural Fitness below \(rules.naturalFitnessBelow)")
        adjust(naturalFitness >= rules.naturalFitnessFrom, by: rules.naturalFitnessHighChange,
               "Natural Fitness \(rules.naturalFitnessFrom) or over")
        adjust(stamina < rules.staminaBelow, by: rules.staminaLowChange, "Stamina below \(rules.staminaBelow)")
        adjust(stamina >= rules.staminaFrom, by: rules.staminaHighChange, "Stamina \(rules.staminaFrom) or over")
        adjust(injuryProneness >= rules.injuryPronenessFrom, by: rules.injuryPronenessHighChange,
               "Injury Proneness \(rules.injuryPronenessFrom) or over")
        adjust(injuryProneness <= rules.injuryPronenessUpTo, by: rules.injuryPronenessLowChange,
               "Injury Proneness \(rules.injuryPronenessUpTo) or under")
        return (min(max(limit, rules.lowest), rules.highest), notes)
    }

    /// Whole days, rounded up, to bring jadedness down to `line` at `perDay` a day.
    private static func daysDown(from jadedness: Int, to line: Double, perDay: Double) -> Int {
        Int(((Double(jadedness) - line) / perDay - roundingNoise).rounded(.up))
    }

    /// Rest days until his projected condition reaches the floor; nil beyond the longest estimate.
    private static func daysToFloor(_ player: Player, intensity: TrainingIntensity,
                                    parameters: EngineParameters) throws -> Int? {
        var fitness = ProjectedFitness(player)
        for day in 1...longestConditionEstimate {
            fitness = try FitnessProjection.afterDays(1, fitness, player: player, intensity: intensity, parameters: parameters)
            if fitness.condition >= parameters.conditionFloor.value { return day }
        }
        return nil
    }
}
