import Testing
@testable import LineupAppCore

@Suite struct ScreenTests {
    @Test func theNineScreensComeInPillOrderWithTheAdvisorsAfterMatchSelection() {
        #expect(Screen.allCases == [.squad, .tactics, .fixtures, .matchSelection, .elevens, .rest, .training, .removal,
                                    .settings])
    }

    @Test func eachScreenHasItsTitle() {
        #expect(Screen.allCases.map(\.title) == ["Squad", "Tactics", "Fixtures", "Match Selection", "Elevens", "Rest",
                                                 "Training", "Player Removal", "Settings"])
    }

    @Test func eachPillIsTheTitleExceptPlayerRemovalWhichIsShortened() {
        #expect(Screen.allCases.map(\.pillTitle) == ["Squad", "Tactics", "Fixtures", "Match Selection", "Elevens", "Rest",
                                                     "Training", "Removal", "Settings"])
        #expect(Screen.allCases.filter { $0.pillTitle != $0.title } == [.removal])
    }

    @Test func aScreenIsIdentifiedByItsRawValue() {
        #expect(Screen.matchSelection.id == "matchSelection")
        #expect(Screen.removal.id == "removal")
        #expect(Set(Screen.allCases.map(\.id)).count == Screen.allCases.count)
    }
}
