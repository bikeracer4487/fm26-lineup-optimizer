/// One step of the growth table: a player up to `upToAge` gains `points` of ability a season, at best.
public struct GrowthStep: Equatable, Sendable {
    public let upToAge: Int
    public let points: Double

    public init(upToAge: Int, points: Double) {
        self.upToAge = upToAge
        self.points = points
    }
}

/// Where a young player's ability could reach, season by season. It is this tool's estimate, not a fact.
public struct ReachEstimate: Equatable, Sendable {
    public let age: Int, current: Int, potential: Int
    public let professionalism: Int, ambition: Int, determination: Int
    /// The growth expected in the season he is in now, before the cap at his potential.
    public let seasonGrowth: Double
    /// His ability after each coming season: index 0 is today. Never above his potential (or below today's ability).
    public let bySeason: [Double]
    public var reach: Double { bySeason.last! }
    /// True when the cap, not his rate of growth, is what limits him.
    public let reachesPotential: Bool
    /// His Ambition is under `growthPersonalityFullFrom`, so it slows his growth.
    public let ambitionSlows: Bool
    /// His Determination is under `growthPersonalityFullFrom`, so it slows his growth.
    public let determinationSlows: Bool
    /// His Professionalism is under `professionalismHoldsBackBelow`.
    public let professionalismHoldsBack: Bool
}

public enum Reach {
    /// Estimates his ability after each season up to the last age in `growthPerSeason`: the step for his age times a
    /// factor for Professionalism, one for Ambition and one for Determination, never above his potential.
    /// Throws `RatingError.missingAttribute` for a player without Professionalism, Ambition or Determination.
    /// The parameters must have passed `FitnessModel.problems(in:)`.
    public static func estimate(for player: Player, parameters: EngineParameters) throws -> ReachEstimate {
        func value(_ attribute: Attribute) throws -> Int {
            guard let value = player.attributes[attribute] else {
                throw RatingError.missingAttribute(player: player.name, attribute: attribute)
            }
            return value
        }
        let professionalism = try value(.professionalism)
        let ambition = try value(.ambition)
        let determination = try value(.determination)
        let personality = professionalismFactor(professionalism, parameters)
            * personalityFactor(ambition, atOne: parameters.growthAmbitionAtOne.value, parameters)
            * personalityFactor(determination, atOne: parameters.growthDeterminationAtOne.value, parameters)

        let steps = parameters.growthPerSeason.value
        func growth(atAge age: Int) -> Double {
            guard let step = steps.first(where: { $0.upToAge >= age }) else { return 0 }
            return step.points * personality
        }
        let current = Double(player.currentAbility), potential = Double(player.potentialAbility)
        let ceiling = max(current, potential)
        var bySeason = [current]
        var age = player.age
        while let last = steps.last, age <= last.upToAge {
            bySeason.append(min(ceiling, bySeason[bySeason.count - 1] + growth(atAge: age)))
            age += 1
        }
        return ReachEstimate(
            age: player.age, current: player.currentAbility, potential: player.potentialAbility,
            professionalism: professionalism, ambition: ambition, determination: determination,
            seasonGrowth: growth(atAge: player.age), bySeason: bySeason,
            reachesPotential: potential > current && bySeason.last! == potential,
            ambitionSlows: ambition < parameters.growthPersonalityFullFrom.value,
            determinationSlows: determination < parameters.growthPersonalityFullFrom.value,
            professionalismHoldsBack: professionalism < parameters.professionalismHoldsBackBelow.value)
    }

    /// His rate of growth over the rate at Professionalism 20, read off straight lines between the anchors.
    private static func professionalismFactor(_ level: Int, _ parameters: EngineParameters) -> Double {
        let rates = parameters.growthProfessionalismRates.value
        let low = rates[1]!, middle = rates[10]!, high = rates[20]!
        let x = Double(level)
        // Import already keeps Professionalism within 1 to 20; the clamp only guards a player built by hand.
        let rate: Double
        if level <= 1 {
            rate = low
        } else if level <= 10 {
            rate = low + (middle - low) * (x - 1) / 9
        } else if level < 20 {
            rate = middle + (high - middle) * (x - 10) / 10
        } else {
            rate = high
        }
        return rate / high
    }

    /// `atOne` at 1, rising in a straight line to 1 at `growthPersonalityFullFrom`, and 1 from there up.
    private static func personalityFactor(_ level: Int, atOne: Double, _ parameters: EngineParameters) -> Double {
        let full = parameters.growthPersonalityFullFrom.value
        guard level < full else { return 1 }
        // Import already keeps these within 1 to 20; the clamp to 1 only guards a player built by hand.
        return atOne + (1 - atOne) * Double(max(level, 1) - 1) / Double(full - 1)
    }
}
