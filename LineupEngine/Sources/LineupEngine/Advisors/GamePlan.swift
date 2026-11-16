import Foundation

/// A preset the game offers when a match is simulated, by the names FM26 used; `noGamePlan` plays the tactic as set.
public enum GamePlan: String, CaseIterable, Codable, Sendable {
    case noGamePlan, playForTheWin, playForTheDraw, settleForADraw, goForABigWin, smashAndGrab, leaveItLate
    case pressureCooker, strangleTheGame
}

/// The plans to use against one kind of opponent, and the plans to avoid.
public struct GamePlanRule: Sendable, Equatable {
    /// The first is named first; nothing separates them.
    public var use: [GamePlan]
    public var avoid: [GamePlan]

    public init(use: [GamePlan], avoid: [GamePlan]) {
        self.use = use; self.avoid = avoid
    }
}

/// Which game plans to use and to avoid when a match is simulated, by how strong the opponent is. Only the rule
/// against a much stronger side rests on a test of the plans; the others are reasoned from it.
public struct GamePlanRules: Sendable, Equatable {
    public var muchStronger: GamePlanRule
    public var stronger: GamePlanRule
    public var similar: GamePlanRule
    public var weaker: GamePlanRule
    public var muchWeaker: GamePlanRule
    /// For a fixture with no opponent strength set.
    public var unset: GamePlanRule
    /// Each plan's points from ten matches in the one test of the plans (FM26, against a much stronger side). A plan
    /// that was not in the test has none.
    public var testPoints: [GamePlan: Int]

    public init(muchStronger: GamePlanRule, stronger: GamePlanRule, similar: GamePlanRule, weaker: GamePlanRule,
                muchWeaker: GamePlanRule, unset: GamePlanRule, testPoints: [GamePlan: Int]) {
        self.muchStronger = muchStronger; self.stronger = stronger; self.similar = similar; self.weaker = weaker
        self.muchWeaker = muchWeaker; self.unset = unset; self.testPoints = testPoints
    }

    public func rule(against strength: OpponentStrength?) -> GamePlanRule {
        switch strength {
        case .muchStronger: muchStronger
        case .stronger: stronger
        case .similar: similar
        case .weaker: weaker
        case .muchWeaker: muchWeaker
        case nil: unset
        }
    }
}

/// The game plans advised for one match, and what the advice rests on.
public struct GamePlanAdvice: Equatable, Sendable {
    /// The opponent's strength on the fixture; nil when none is set.
    public let strength: OpponentStrength?
    /// The plans to use, the first named first; nothing separates them. Never empty.
    public let use: [GamePlan]
    public let avoid: [GamePlan]
    /// The one test of the plans was against a side of this strength. Otherwise the advice is reasoned from that test.
    public let isMeasured: Bool
    /// Each plan's points from ten matches in that test.
    public let testPoints: [GamePlan: Int]
    /// The rule's evidence when the advice is measured; this tool's estimate when it is reasoned.
    public let basis: Evidence
}

public enum GamePlanAdvisor {
    /// The advice for a match against an opponent of `strength` (nil when the fixture has none). Throws
    /// `PlanError.badParameters` when `FitnessModel.problems(in:)` finds problems.
    public static func advise(against strength: OpponentStrength?, parameters: EngineParameters) throws -> GamePlanAdvice {
        let problems = FitnessModel.problems(in: parameters)
        guard problems.isEmpty else { throw PlanError.badParameters(problems) }
        let rules = parameters.gamePlanRules.value
        let rule = rules.rule(against: strength)
        // The test was against a much stronger side, so only that rule is a measurement.
        let isMeasured = strength == .muchStronger
        let evidence = parameters.gamePlanRules.evidence
        return GamePlanAdvice(strength: strength, use: rule.use, avoid: rule.avoid, isMeasured: isMeasured,
                              testPoints: rules.testPoints,
                              basis: isMeasured ? evidence : Evidence.weakest([evidence, .derived])!)
    }

    /// What is wrong with the rules: a rule with no plan to use, a plan to use and to avoid, or a plan listed twice.
    /// In the order of the rules, then as found.
    static func problems(in rules: GamePlanRules) -> [String] {
        let named: [(String, GamePlanRule)] = [
            ("muchStronger", rules.muchStronger), ("stronger", rules.stronger), ("similar", rules.similar),
            ("weaker", rules.weaker), ("muchWeaker", rules.muchWeaker), ("unset", rules.unset)]
        var found: [String] = []
        for (name, rule) in named {
            if rule.use.isEmpty { found.append("gamePlanRules \(name) names no plan to use") }
            for plan in repeated(in: rule.use) {
                found.append("gamePlanRules \(name) lists \(AdvisorText.name(plan)) twice among the plans to use")
            }
            for plan in repeated(in: rule.avoid) {
                found.append("gamePlanRules \(name) lists \(AdvisorText.name(plan)) twice among the plans to avoid")
            }
            var seen: [GamePlan] = []
            for plan in rule.use where rule.avoid.contains(plan) && !seen.contains(plan) {
                seen.append(plan)
                found.append("gamePlanRules \(name) lists \(AdvisorText.name(plan)) to use and to avoid")
            }
        }
        return found
    }

    /// Each plan that appears more than once, once, in the order of its first appearance.
    private static func repeated(in plans: [GamePlan]) -> [GamePlan] {
        var seen: [GamePlan] = [], twice: [GamePlan] = []
        for plan in plans {
            if !seen.contains(plan) { seen.append(plan) } else if !twice.contains(plan) { twice.append(plan) }
        }
        return twice
    }
}
