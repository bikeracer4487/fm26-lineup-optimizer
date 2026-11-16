import Testing
@testable import LineupEngine

@Suite struct GamePlanTests {
    let parameters = EngineParameters.fm27

    func rules(_ change: (inout GamePlanRules) -> Void) -> EngineParameters {
        var changed = parameters
        var value = changed.gamePlanRules.value
        change(&value)
        changed.gamePlanRules = Parameter(value, .derived, source: "test")
        return changed
    }

    @Test func noGamePlanIsRecommendedWhateverTheOpponent() throws {
        for strength in OpponentStrength.allCases.map(Optional.some) + [nil] {
            let advice = try GamePlanAdvisor.advise(against: strength, parameters: parameters)
            #expect(advice.recommended == .noGamePlan)
            #expect(advice.avoid == [.settleForADraw, .smashAndGrab, .strangleTheGame])
            #expect(advice.basis == .carriedOverFM26)
        }
    }

    @Test func onlyAMuchStrongerOpponentAddsThePlansThatCameOutBest() throws {
        #expect(try GamePlanAdvisor.advise(against: .muchStronger, parameters: parameters).level
                == [.playForTheDraw, .playForTheWin])
        for strength in [OpponentStrength.stronger, .similar, .weaker, .muchWeaker].map(Optional.some) + [nil] {
            #expect(try GamePlanAdvisor.advise(against: strength, parameters: parameters).level == [])
        }
    }

    @Test func theAdviceFollowsTheRule() throws {
        let changed = rules {
            $0.recommended = .playForTheWin
            $0.avoid = [.settleForADraw]
            $0.levelAgainstMuchStronger = [.leaveItLate]
        }
        let advice = try GamePlanAdvisor.advise(against: .muchStronger, parameters: changed)
        #expect(advice.recommended == .playForTheWin)
        #expect(advice.avoid == [.settleForADraw])
        #expect(advice.level == [.leaveItLate])
        #expect(advice.basis == .derived)
    }

    @Test func aRuleThatContradictsItselfIsAParameterProblem() {
        let cases: [(EngineParameters, String)] = [
            (rules { $0.avoid = [.noGamePlan] },
             "gamePlanRules recommends No game plan and also says to avoid it"),
            (rules { $0.levelAgainstMuchStronger = [.noGamePlan] },
             "gamePlanRules lists No game plan as level with the recommended plan, which it is"),
            (rules { $0.levelAgainstMuchStronger = [.smashAndGrab] },
             "gamePlanRules lists Smash and grab as level with the recommended plan and also says to avoid it"),
            (rules { $0.avoid = [.smashAndGrab, .smashAndGrab] },
             "gamePlanRules lists Smash and grab twice among the plans to avoid"),
            (rules { $0.levelAgainstMuchStronger = [.playForTheWin, .playForTheWin] },
             "gamePlanRules lists Play for the win twice among the plans level with the recommended plan"),
        ]
        for (bad, problem) in cases {
            #expect(FitnessModel.problems(in: bad) == [problem])
            #expect(throws: PlanError.badParameters([problem])) {
                try GamePlanAdvisor.advise(against: .similar, parameters: bad)
            }
        }
        #expect(FitnessModel.problems(in: parameters) == [])
    }

    @Test func theRuleIsListedWithItsEvidenceAndSource() {
        let listed = Dictionary(uniqueKeysWithValues: parameters.all.map { ($0.name, $0) })
        #expect(listed["gamePlanRules"]?.evidence == .carriedOverFM26)
        #expect(listed["gamePlanRules"]?.source.contains("docs/Research/fm27-match-simulation-game-plans.md") == true)
        #expect(parameters.gamePlanRules.value == GamePlanRules(
            recommended: .noGamePlan, avoid: [.settleForADraw, .smashAndGrab, .strangleTheGame],
            levelAgainstMuchStronger: [.playForTheDraw, .playForTheWin]))
    }

    @Test func eachPlanHasItsName() {
        #expect(GamePlan.allCases.map { AdvisorText.name($0) } == [
            "No game plan", "Play for the win", "Play for the draw", "Settle for a draw", "Go for a big win",
            "Smash and grab", "Leave it late", "Pressure cooker", "Strangle the game"])
    }

    @Test func theLineNamesThePlan() throws {
        let advice = try GamePlanAdvisor.advise(against: .similar, parameters: parameters)
        #expect(AdvisorText.gamePlanLine(advice) == "If you simulate this match: No game plan")
    }

    @Test func theSentencesSayWhyWhatToAvoidAndHowThinTheEvidenceIs() throws {
        let advice = try GamePlanAdvisor.advise(against: .similar, parameters: parameters)
        #expect(AdvisorText.gamePlanSentences(advice) == [
            "No game plan plays your tactic as you set it. No test of FM27's game plans exists, so nothing shows that "
                + "any of them does better.",
            "Avoid Settle for a draw, Smash and grab and Strangle the game: they sit deep, which did worst in the one "
                + "FM26 test of the plans and costs points in FM27 engine tests.",
        ])
    }

    @Test func aMuchStrongerOpponentAddsItsSentence() throws {
        let advice = try GamePlanAdvisor.advise(against: .muchStronger, parameters: parameters)
        let sentences = AdvisorText.gamePlanSentences(advice)
        #expect(sentences.count == 3)
        #expect(sentences.last == "Against a much stronger side like this one, Play for the draw and Play for the win "
                + "came out best of the plans in the one FM26 test, too close to call between them.")
    }

    @Test func theSentencesFollowAChangedRule() throws {
        let one = try GamePlanAdvisor.advise(against: .muchStronger, parameters: rules {
            $0.recommended = .playForTheWin
            $0.avoid = [.settleForADraw]
            $0.levelAgainstMuchStronger = [.leaveItLate]
        })
        #expect(AdvisorText.gamePlanLine(one) == "If you simulate this match: Play for the win")
        #expect(AdvisorText.gamePlanSentences(one) == [
            "Avoid Settle for a draw: it sits deep, which did worst in the one FM26 test of the plans and costs points "
                + "in FM27 engine tests.",
            "Against a much stronger side like this one, Leave it late came out best of the plans in the one FM26 test.",
        ])
        let none = try GamePlanAdvisor.advise(against: .similar, parameters: rules {
            $0.avoid = []
            $0.levelAgainstMuchStronger = []
        })
        #expect(AdvisorText.gamePlanSentences(none) == [
            "No game plan plays your tactic as you set it. No test of FM27's game plans exists, so nothing shows that "
                + "any of them does better."])
    }
}
