/// A player's condition, sharpness and jadedness as the planner expects them at some point in the plan.
public struct ProjectedFitness: Equatable, Sendable {
    /// 0...1
    public var condition: Double
    /// 0...1
    public var sharpness: Double
    public var jadedness: Double
    /// Nil when he has not played in the plan.
    public var daysSinceMatch: Int?

    public init(condition: Double, sharpness: Double, jadedness: Double, daysSinceMatch: Int?) {
        self.condition = condition
        self.sharpness = sharpness
        self.jadedness = jadedness
        self.daysSinceMatch = daysSinceMatch
    }

    /// The imported values, with no match played yet in the plan.
    public init(_ player: Player) {
        self.init(condition: player.condition, sharpness: player.sharpness,
                  jadedness: Double(player.jadedness), daysSinceMatch: nil)
    }
}

/// Moves a player's fitness across a match and across days of rest.
public enum FitnessProjection {
    /// The effect of starting a match at `position`, assuming the full match.
    public static func afterMatch(
        _ fitness: ProjectedFitness, player: Player, position: Position, parameters: EngineParameters
    ) throws -> ProjectedFitness {
        let stamina = Double(try attribute(.stamina, of: player))
        let load = parameters.positionConditionLoad.value[position] ?? 1.0
        let cost = parameters.matchConditionCost.value * load * (1 - (stamina - 10) * parameters.staminaCostPerPoint.value)
        let taper = FitnessModel.evaluate(parameters.sharpnessGainTaper.value, at: fitness.sharpness)
        let gain = parameters.sharpnessGainPerMinute.value * parameters.assumedMinutes.value * taper
        return ProjectedFitness(
            condition: max(0, fitness.condition - cost),
            sharpness: min(1, fitness.sharpness + gain),
            jadedness: fitness.jadedness + parameters.jadednessPerMatch.value,
            daysSinceMatch: 0)
    }

    /// The effect of `days` nights without a match, one day at a time. 0 days returns the input.
    /// A negative `days` is a programming error and stops the program.
    public static func afterDays(
        _ days: Int, _ fitness: ProjectedFitness, player: Player, intensity: TrainingIntensity, parameters: EngineParameters
    ) throws -> ProjectedFitness {
        precondition(days >= 0, "afterDays needs a day count of 0 or more, not \(days)")
        guard days > 0 else { return fitness }
        let naturalFitness = Double(try attribute(.naturalFitness, of: player))
        let recoveryScale = parameters.trainingIntensityRecovery.value[intensity] ?? 1.0
        let conditionScale = (1 + (naturalFitness - 10) * parameters.naturalFitnessRecoveryPerPoint.value) * recoveryScale
        let decay = parameters.sharpnessDecayPerDay.value
            * (naturalFitness > 10 ? max(0, 1 - (naturalFitness - 10) * parameters.sharpnessDecayNaturalFitnessPerPoint.value) : 1)
        let floor = parameters.sharpnessFloor.value

        var result = fitness
        for _ in 0..<days {
            let start = result
            result.condition = min(1, start.condition
                + FitnessModel.evaluate(parameters.conditionRecoveryPerDay.value, at: start.condition) * conditionScale)
            if start.daysSinceMatch != 0 && start.sharpness > floor {
                result.sharpness = max(floor, start.sharpness - decay)
            }
            result.jadedness = max(parameters.jadednessFloor.value,
                                   start.jadedness - parameters.jadednessRecoveryPerDay.value * recoveryScale)
            result.daysSinceMatch = start.daysSinceMatch.map { $0 + 1 }
        }
        return result
    }

    private static func attribute(_ attribute: Attribute, of player: Player) throws -> Int {
        guard let value = player.attributes[attribute] else {
            throw RatingError.missingAttribute(player: player.name, attribute: attribute)
        }
        return value
    }
}
