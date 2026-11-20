import Testing
@testable import LineupAppCore

@Suite struct ScreenTests {
    @Test func theElevenScreensComeInPillOrderWithTheAdvisorsAfterMatchSelectionAndScoutingAfterPlayerRemoval() {
        #expect(Screen.allCases == [.squad, .tactics, .fixtures, .league, .matchSelection, .elevens, .rest, .training, .removal,
                                    .scouting, .settings])
    }

    @Test func eachScreenHasItsTitle() {
        #expect(Screen.allCases.map(\.title) == ["Squad", "Tactics", "Fixtures", "League", "Match Selection", "Elevens", "Rest",
                                                 "Training", "Player Removal", "Scouting", "Settings"])
    }

    @Test func eachPillIsTheTitleExceptPlayerRemovalWhichIsShortened() {
        #expect(Screen.allCases.map(\.pillTitle) == ["Squad", "Tactics", "Fixtures", "League", "Match Selection", "Elevens", "Rest",
                                                     "Training", "Removal", "Scouting", "Settings"])
        #expect(Screen.allCases.filter { $0.pillTitle != $0.title } == [.removal])
    }

    @Test func theLeagueScreenComesStraightAfterFixtures() throws {
        let index = try #require(Screen.allCases.firstIndex(of: .fixtures))
        #expect(Screen.allCases[index + 1] == .league)
        #expect(Screen.league.title == "League" && Screen.league.pillTitle == "League")
    }

    @Test func aScreenIsIdentifiedByItsRawValue() {
        #expect(Screen.matchSelection.id == "matchSelection")
        #expect(Screen.removal.id == "removal")
        #expect(Screen.scouting.id == "scouting")
        #expect(Set(Screen.allCases.map(\.id)).count == Screen.allCases.count)
    }
}
