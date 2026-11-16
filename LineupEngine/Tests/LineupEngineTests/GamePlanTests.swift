import Testing
@testable import LineupEngine

@Suite struct GamePlanTests {
    let parameters = EngineParameters.fm27

    func rules(_ change: (inout GamePlanRules) -> Void) -> EngineParameters {
        var changed = parameters
        var value = changed.gamePlanRules.value
        change(&value)
        changed.gamePlanRules = Parameter(value, .fm27Measured, source: "test")
        return changed
    }

    func advice(_ strength: OpponentStrength?) throws -> GamePlanAdvice {
        try GamePlanAdvisor.advise(against: strength, parameters: parameters)
    }

    @Test func eachStrengthHasItsPlansToUseAndToAvoid() throws {
        #expect(try advice(.muchStronger).use == [.playForTheDraw, .playForTheWin])
        #expect(try advice(.muchStronger).avoid == [.settleForADraw, .strangleTheGame, .smashAndGrab])
        #expect(try advice(.stronger).use == [.playForTheWin, .playForTheDraw])
        #expect(try advice(.stronger).avoid == [.settleForADraw, .strangleTheGame])
        #expect(try advice(.similar).use == [.playForTheWin, .noGamePlan])
        #expect(try advice(.similar).avoid == [.settleForADraw])
        for strength in [OpponentStrength.weaker, .muchWeaker] {
            #expect(try advice(strength).use == [.playForTheWin, .noGamePlan])
            #expect(try advice(strength).avoid == [.settleForADraw, .strangleTheGame])
        }
        #expect(try advice(nil).use == [.playForTheWin])
        #expect(try advice(nil).avoid == [.settleForADraw])
        for strength in OpponentStrength.allCases.map(Optional.some) + [nil] {
            #expect(try advice(strength).strength == strength)
        }
    }

    @Test func onlyTheRuleAgainstAMuchStrongerSideIsAMeasurement() throws {
        #expect(try advice(.muchStronger).isMeasured)
        #expect(try advice(.muchStronger).basis == .carriedOverFM26)
        for strength in [OpponentStrength.stronger, .similar, .weaker, .muchWeaker].map(Optional.some) + [nil] {
            #expect(try advice(strength).isMeasured == false)
            #expect(try advice(strength).basis == .derived)
        }
        // Better evidence for the rule lifts the measured advice only.
        let better = rules { _ in }
        #expect(try GamePlanAdvisor.advise(against: .muchStronger, parameters: better).basis == .fm27Measured)
        #expect(try GamePlanAdvisor.advise(against: .similar, parameters: better).basis == .derived)
    }

    @Test func theAdviceFollowsTheRules() throws {
        let changed = rules {
            $0.similar = GamePlanRule(use: [.leaveItLate], avoid: [.pressureCooker])
            $0.testPoints = [.leaveItLate: 30]
        }
        let similar = try GamePlanAdvisor.advise(against: .similar, parameters: changed)
        #expect(similar.use == [.leaveItLate])
        #expect(similar.avoid == [.pressureCooker])
        #expect(similar.testPoints == [.leaveItLate: 30])
        // Another strength's rule is left as it was.
        #expect(try GamePlanAdvisor.advise(against: .weaker, parameters: changed).use == [.playForTheWin, .noGamePlan])
    }

    @Test func aRuleThatContradictsItselfIsAParameterProblem() {
        let cases: [(EngineParameters, String)] = [
            (rules { $0.similar.use = [] }, "gamePlanRules similar names no plan to use"),
            (rules { $0.weaker.avoid = [.playForTheWin] }, "gamePlanRules weaker lists Play for the win to use and to avoid"),
            (rules { $0.unset.avoid = [.settleForADraw, .settleForADraw] },
             "gamePlanRules unset lists Settle for a draw twice among the plans to avoid"),
            (rules { $0.muchStronger.use = [.playForTheWin, .playForTheWin] },
             "gamePlanRules muchStronger lists Play for the win twice among the plans to use"),
        ]
        for (bad, problem) in cases {
            #expect(FitnessModel.problems(in: bad) == [problem])
            #expect(throws: PlanError.badParameters([problem])) {
                try GamePlanAdvisor.advise(against: .similar, parameters: bad)
            }
        }
        #expect(FitnessModel.problems(in: parameters) == [])
    }

    @Test func theRulesAreListedWithTheirEvidenceSourceAndTheTestsPoints() {
        let listed = Dictionary(uniqueKeysWithValues: parameters.all.map { ($0.name, $0) })
        #expect(listed["gamePlanRules"]?.evidence == .carriedOverFM26)
        #expect(listed["gamePlanRules"]?.source.contains("docs/Research/fm26-match-simulation-game-plans.md") == true)
        #expect(listed["gamePlanRules"]?.source.contains("docs/Research/fm27-match-simulation-game-plans.md") == true)
        #expect(parameters.gamePlanRules.value.testPoints == [
            .playForTheDraw: 10, .playForTheWin: 9, .leaveItLate: 8, .goForABigWin: 7, .pressureCooker: 6,
            .smashAndGrab: 2, .strangleTheGame: 2, .settleForADraw: 1])
    }

    @Test func eachPlanHasItsName() {
        #expect(GamePlan.allCases.map { AdvisorText.name($0) } == [
            "No game plan", "Play for the win", "Play for the draw", "Settle for a draw", "Go for a big win",
            "Smash and grab", "Leave it late", "Pressure cooker", "Strangle the game"])
    }

    @Test func theLineNamesThePlansToUse() throws {
        #expect(AdvisorText.gamePlanLine(try advice(.muchStronger)) == "If you simulate this match: Play for the draw or Play for the win")
        #expect(AdvisorText.gamePlanLine(try advice(.similar)) == "If you simulate this match: Play for the win or No game plan")
        #expect(AdvisorText.gamePlanLine(try advice(nil)) == "If you simulate this match: Play for the win")
        let three = try GamePlanAdvisor.advise(against: .similar, parameters: rules {
            $0.similar.use = [.playForTheWin, .noGamePlan, .leaveItLate]
        })
        #expect(AdvisorText.gamePlanLine(three) == "If you simulate this match: Play for the win, No game plan or Leave it late")
    }

    @Test func againstAMuchStrongerSideTheSentencesGiveTheTestsPoints() throws {
        #expect(AdvisorText.gamePlanSentences(try advice(.muchStronger)) == [
            "The one test of the game plans (FM26, ten matches a plan) was against a much stronger side like this one: "
                + "Play for the draw (10 points) and Play for the win (9 points) came out best, too close to tell apart.",
            "Avoid Settle for a draw (1 point), Strangle the game (2 points) and Smash and grab (2 points): they came out "
                + "worst in that test.",
            "No game plan was not in the test, so how your own tactic compares is not known.",
        ])
    }

    @Test func againstAStrongerSideTheSentencesSayItIsReasoning() throws {
        #expect(AdvisorText.gamePlanSentences(try advice(.stronger)) == [
            "No test covers a stronger side like this one. The one test of the game plans (FM26, ten matches a plan) was "
                + "against a much stronger side, where Play for the win (9 points) and Play for the draw (10 points) came "
                + "out best; using them here is reasoning from that, not a measurement.",
            "Avoid Settle for a draw (1 point) and Strangle the game (2 points): they came out worst in that test, and "
                + "sitting deep costs points in FM27 engine tests.",
            "No game plan was not in the test, so how your own tactic compares is not known.",
        ])
    }

    @Test func againstASimilarOrWeakerSideTheSentencesSayNothingIsMeasured() throws {
        #expect(AdvisorText.gamePlanSentences(try advice(.similar)) == [
            "No test covers a side of similar strength like this one, and none sets No game plan (your tactic as you set "
                + "it) against a plan. Play for the win and No game plan are reasoned choices, not measured ones, and "
                + "nothing separates them.",
            "Avoid Settle for a draw (1 point): it came out worst in the one test of the game plans (FM26, ten matches a "
                + "plan, against a much stronger side), and sitting deep costs points in FM27 engine tests.",
        ])
        let weaker = AdvisorText.gamePlanSentences(try advice(.weaker))
        #expect(weaker.first?.hasPrefix("No test covers a weaker side like this one, and none sets No game plan") == true)
        #expect(weaker.last == "Avoid Settle for a draw (1 point) and Strangle the game (2 points): they came out worst in "
                + "the one test of the game plans (FM26, ten matches a plan, against a much stronger side), and sitting "
                + "deep costs points in FM27 engine tests.")
        #expect(AdvisorText.gamePlanSentences(try advice(.muchWeaker)).first?
            .hasPrefix("No test covers a much weaker side like this one") == true)
    }

    @Test func withNoStrengthSetTheSentencesSayHowToGetAdviceThatFits() throws {
        #expect(AdvisorText.gamePlanSentences(try advice(nil)) == [
            "This fixture has no strength set for the opponent, so this is what is advised against every strength. Set "
                + "their strength on the Fixtures screen, or paste their squad there, for advice that fits the match.",
            "Avoid Settle for a draw (1 point): it came out worst in the one test of the game plans (FM26, ten matches a "
                + "plan, against a much stronger side), and sitting deep costs points in FM27 engine tests.",
        ])
    }

    @Test func theSentencesFollowChangedRules() throws {
        let one = try GamePlanAdvisor.advise(against: .similar, parameters: rules {
            $0.similar = GamePlanRule(use: [.leaveItLate], avoid: [])
        })
        #expect(AdvisorText.gamePlanSentences(one) == [
            "No test covers a side of similar strength like this one. Leave it late is a reasoned choice, not a measured one."])
        let strong = try GamePlanAdvisor.advise(against: .muchStronger, parameters: rules {
            $0.muchStronger = GamePlanRule(use: [.noGamePlan], avoid: [.pressureCooker])
        })
        #expect(AdvisorText.gamePlanSentences(strong) == [
            "The one test of the game plans (FM26, ten matches a plan) was against a much stronger side like this one: "
                + "No game plan came out best.",
            "Avoid Pressure cooker (6 points): it came out worst in that test."])
    }
}
