import Foundation

/// A preset the game offers when a match is simulated, by the names FM26 used; `noGamePlan` plays the tactic as set.
public enum GamePlan: String, CaseIterable, Codable, Sendable {
    case noGamePlan, playForTheWin, playForTheDraw, settleForADraw, goForABigWin, smashAndGrab, leaveItLate
    case pressureCooker, strangleTheGame
}

/// Which game plan to use when a match is simulated: one for every match, the plans never to use, and the plans that
/// came out best in the one test there is, which was against a much stronger side.
public struct GamePlanRules: Sendable, Equatable {
    public var recommended: GamePlan
    public var avoid: [GamePlan]
    public var levelAgainstMuchStronger: [GamePlan]

    public init(recommended: GamePlan, avoid: [GamePlan], levelAgainstMuchStronger: [GamePlan]) {
        self.recommended = recommended; self.avoid = avoid; self.levelAgainstMuchStronger = levelAgainstMuchStronger
    }
}

/// The game plan advised for one match, and what it rests on.
public struct GamePlanAdvice: Equatable, Sendable {
    public let recommended: GamePlan
    /// The plans that came out best in the one test, against a much stronger side; empty against any other opponent.
    public let level: [GamePlan]
    public let avoid: [GamePlan]
    /// The evidence behind the rule.
    public let basis: Evidence
}

public enum GamePlanAdvisor {
    /// The advice for a match against an opponent of `strength` (nil when the fixture has none). Only a much stronger
    /// opponent changes it. Throws `PlanError.badParameters` when `FitnessModel.problems(in:)` finds problems.
    public static func advise(against strength: OpponentStrength?, parameters: EngineParameters) throws -> GamePlanAdvice {
        let problems = FitnessModel.problems(in: parameters)
        guard problems.isEmpty else { throw PlanError.badParameters(problems) }
        let rules = parameters.gamePlanRules.value
        let level: [GamePlan]
        switch strength {
        case .muchStronger: level = rules.levelAgainstMuchStronger
        case .stronger, .similar, .weaker, .muchWeaker, nil: level = []
        }
        return GamePlanAdvice(recommended: rules.recommended, level: level, avoid: rules.avoid,
                              basis: parameters.gamePlanRules.evidence)
    }

    /// What is wrong with the rule: a plan recommended and avoided, or listed twice. In the order found.
    static func problems(in rules: GamePlanRules) -> [String] {
        var found: [String] = []
        let recommended = AdvisorText.name(rules.recommended)
        if rules.avoid.contains(rules.recommended) {
            found.append("gamePlanRules recommends \(recommended) and also says to avoid it")
        }
        for plan in repeated(in: rules.avoid) {
            found.append("gamePlanRules lists \(AdvisorText.name(plan)) twice among the plans to avoid")
        }
        var seen: [GamePlan] = []
        for plan in rules.levelAgainstMuchStronger where !seen.contains(plan) {
            seen.append(plan)
            if plan == rules.recommended {
                found.append("gamePlanRules lists \(recommended) as level with the recommended plan, which it is")
            } else if rules.avoid.contains(plan) {
                found.append("gamePlanRules lists \(AdvisorText.name(plan)) as level with the recommended plan and also says to avoid it")
            }
        }
        for plan in repeated(in: rules.levelAgainstMuchStronger) {
            found.append("gamePlanRules lists \(AdvisorText.name(plan)) twice among the plans level with the recommended plan")
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
