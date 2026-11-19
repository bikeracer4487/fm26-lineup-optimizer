import Testing
@testable import LineupAppCore

@Suite struct ScreenTests {
    @Test func theTenScreensComeInPillOrderWithTheAdvisorsAfterMatchSelectionAndScoutingAfterPlayerRemoval() {
        #expect(Screen.allCases == [.squad, .tactics, .fixtures, .matchSelection, .elevens, .rest, .training, .removal,
                                    .scouting, .settings])
    }

    @Test func eachScreenHasItsTitle() {
        #expect(Screen.allCases.map(\.title) == ["Squad", "Tactics", "Fixtures", "Match Selection", "Elevens", "Rest",
                                                 "Training", "Player Removal", "Scouting", "Settings"])
    }

    @Test func eachPillIsTheTitleExceptPlayerRemovalWhichIsShortened() {
        #expect(Screen.allCases.map(\.pillTitle) == ["Squad", "Tactics", "Fixtures", "Match Selection", "Elevens", "Rest",
                                                     "Training", "Removal", "Scouting", "Settings"])
        #expect(Screen.allCases.filter { $0.pillTitle != $0.title } == [.removal])
    }

    @Test func aScreenIsIdentifiedByItsRawValue() {
        #expect(Screen.matchSelection.id == "matchSelection")
        #expect(Screen.removal.id == "removal")
        #expect(Screen.scouting.id == "scouting")
        #expect(Set(Screen.allCases.map(\.id)).count == Screen.allCases.count)
    }
}
