import Testing
@testable import LineupEngine

@Suite struct RiskRulesTests {
    private func exclusion(
        _ player: Player, loan: LoanStatus = .own, importance: Importance = .medium, isNextFixture: Bool = true
    ) -> Exclusion? {
        RiskRules.exclusion(for: player, loan: loan, importance: importance, isNextFixture: isNextFixture, parameters: .fm27)
    }

    @Test func injuryComesFirstAndCannotBeOverridden() {
        let player = Player.fixture(condition: 0.50, jadedness: 600, isInjured: true, isBanned: true)
        let result = exclusion(player, loan: .loanedOut(to: "Wallingford"))
        #expect(result == .injured)
        #expect(!RiskRules.canBeOverridden(.injured))
    }

    @Test func loanedOutPlayerIsExcluded() {
        let result = exclusion(.fixture(), loan: .loanedOut(to: "Wallingford"))
        #expect(result == .outOnLoan(to: "Wallingford"))
        #expect(!RiskRules.canBeOverridden(.outOnLoan(to: "Wallingford")))
    }

    @Test func aLoanedInPlayerIsNotExcluded() {
        #expect(exclusion(.fixture(), loan: .loanedIn(from: "Wallingford")) == nil)
        #expect(exclusion(.fixture(), loan: .loanedIn(from: nil)) == nil)
    }

    @Test func aBanOnlyCountsForTheNextFixture() {
        let player = Player.fixture(isBanned: true)
        #expect(exclusion(player, isNextFixture: true) == .banned)
        #expect(exclusion(player, isNextFixture: false) == nil)
        #expect(RiskRules.canBeOverridden(.banned))
    }

    @Test func conditionFloorAppliesAtEveryImportance() {
        for importance in Importance.allCases {
            #expect(exclusion(.fixture(condition: 0.84), importance: importance) == .belowConditionFloor(0.84))
            #expect(exclusion(.fixture(condition: 0.85), importance: importance) == nil)
        }
        #expect(RiskRules.canBeOverridden(.belowConditionFloor(0.84)))
    }

    @Test func aJadedPlayerSitsOutEverythingExceptHigh() {
        for importance in [Importance.medium, .low, .sharpness] {
            #expect(exclusion(.fixture(jadedness: 401), importance: importance) == .jaded(401))
        }
        #expect(exclusion(.fixture(jadedness: 401), importance: .high) == nil)
        for importance in Importance.allCases {
            #expect(exclusion(.fixture(jadedness: 400), importance: importance) == nil)
        }
        #expect(RiskRules.canBeOverridden(.jaded(401)))
    }

    @Test func rejectedCanBeOverridden() {
        #expect(RiskRules.canBeOverridden(.rejected))
    }

    @Test func aFitOwnPlayerIsNotExcluded() {
        for importance in Importance.allCases {
            #expect(exclusion(.fixture(condition: 1, sharpness: 1, jadedness: 0), importance: importance) == nil)
        }
    }
}
