import Foundation

/// A fixture after today, with the first and second elevens for its tactic.
public struct LaterFixture: Sendable {
    public var fixture: Fixture
    /// For that fixture's tactic.
    public var tiers: SquadTiers

    public init(fixture: Fixture, tiers: SquadTiers) {
        self.fixture = fixture; self.tiers = tiers
    }
}

/// Puts a cost on starting a player today when a more important fixture is coming soon after.
///
/// For each later fixture that weighs more than today, and only where he is in that fixture's first eleven,
/// the loss is his rating in his slot there times the fall in his fitness factors that today's start causes by
/// then, at most his advantage over the second-eleven player in that slot. A start that would break a risk rule
/// there which resting would not costs the whole advantage. Each loss is weighted by the ratio of importance
/// weights; the sum, scaled by the saving-players setting and capped at `savingCostCeiling`, is the cost. A later
/// fixture the manager has rejected him for counts for nothing.
public enum SavingPlayers {
    /// The cost, in rating points, of starting `player` today at `position`, given the fixtures still to come.
    /// nil when there is none.
    ///
    /// `fitness` is his fitness today, before today's match. Later fixtures dated on or before today, and any
    /// importance with no weight or a weight that is not a finite number above 0, are left out. Throws the
    /// projection's `RatingError` for a missing Stamina or Natural Fitness.
    public static func adjustment(for player: Player, fitness: ProjectedFitness, position: Position,
                                  today: Fixture, later: [LaterFixture], settings: PlanSettings,
                                  parameters: EngineParameters) throws -> Adjustment? {
        let weights = parameters.importanceWeights.value
        guard settings.savingPlayers > 0, let todayWeight = usable(weights[today.importance]) else { return nil }

        // Date then id, so the sum runs in the same order whatever order the fixtures came in.
        let ordered = later.sorted { ($0.fixture.date, $0.fixture.id.raw) < ($1.fixture.date, $1.fixture.id.raw) }
        var total = 0.0
        var largest: (fixture: Fixture, loss: Double, contribution: Double)?
        for item in ordered {
            let m = item.fixture
            let gap = today.date.days(to: m.date)
            // The manager has already ruled him out of that fixture: nothing to save him for.
            guard gap > 0, !m.rejected.contains(player.id),
                  let weight = usable(weights[m.importance]), weight > todayWeight else { continue }
            guard let (slot, tier) = item.tiers.slot(of: player.id), tier == 1,
                  let rating = item.tiers.ratings[player.id]?[slot],
                  let advantage = item.tiers.advantage(of: player.id) else { continue }

            let intensity = settings.trainingIntensity
            let rest = try FitnessProjection.afterDays(gap, fitness, player: player, intensity: intensity, parameters: parameters)
            let played = try FitnessProjection.afterMatch(fitness, player: player, position: position, parameters: parameters)
            let play = try FitnessProjection.afterDays(gap, played, player: player, intensity: intensity, parameters: parameters)

            let loss: Double
            if breaksRiskRule(play, of: player, importance: m.importance, parameters: parameters)
                && !breaksRiskRule(rest, of: player, importance: m.importance, parameters: parameters) {
                loss = advantage
            } else {
                let drop = max(0, product(rest, parameters: parameters) - product(play, parameters: parameters))
                loss = min(advantage, rating * drop)
            }
            // A cover who rates higher in the slot makes the advantage, and so the loss, 0 or less: no cost.
            guard loss > 0 else { continue }

            let contribution = loss * weight / todayWeight
            total += contribution
            // Strictly greater, so on a tie the earlier fixture is named.
            if largest.map({ contribution > $0.contribution }) ?? true {
                largest = (m, loss, contribution)
            }
        }

        // Capped, so a match-day value stays far inside the range the assignment solver accepts.
        let cost = min(settings.savingPlayers * total, parameters.savingCostCeiling.value)
        guard cost > 0, let largest else { return nil }
        let figure = String(format: "%.1f", largest.loss)
        return Adjustment(
            kind: .savedForLater, cost: cost,
            reason: "Kept fresher for \(largest.fixture.opponent) on \(largest.fixture.date.iso): starting today would cost about \(figure) there")
    }

    /// The weight when it is a finite number above 0; nil otherwise.
    private static func usable(_ weight: Double?) -> Double? {
        guard let weight, weight.isFinite, weight > 0 else { return nil }
        return weight
    }

    private static func jadedness(_ fitness: ProjectedFitness) -> Int { Int(fitness.jadedness.rounded()) }

    private static func product(_ fitness: ProjectedFitness, parameters: EngineParameters) -> Double {
        FitnessModel.factors(condition: fitness.condition, sharpness: fitness.sharpness,
                             jadedness: jadedness(fitness), parameters: parameters).product
    }

    /// Whether `RiskRules` would keep him out of a fixture of `importance` at the projected fitness for a
    /// reason fitness causes: condition below the floor, or jaded. Injury, loan and ban are not projected.
    private static func breaksRiskRule(_ fitness: ProjectedFitness, of player: Player, importance: Importance,
                                       parameters: EngineParameters) -> Bool {
        var projected = player
        projected.condition = fitness.condition
        projected.jadedness = jadedness(fitness)
        projected.isInjured = false
        projected.isBanned = false
        switch RiskRules.exclusion(for: projected, loan: .own, importance: importance, isNextFixture: false, parameters: parameters) {
        case .belowConditionFloor, .jaded: return true
        case .injured, .outOnLoan, .banned, .rejected, nil: return false
        }
    }
}
