import Testing
@testable import LineupAppCore

@Suite struct ScreenTests {
    @Test func theFiveScreensComeInSidebarOrder() {
        #expect(Screen.allCases == [.squad, .tactics, .fixtures, .matchSelection, .settings])
    }

    @Test func eachScreenHasItsTitle() {
        #expect(Screen.allCases.map(\.title) == ["Squad", "Tactics", "Fixtures", "Match Selection", "Settings"])
    }

    @Test func aScreenIsIdentifiedByItsRawValue() {
        #expect(Screen.matchSelection.id == "matchSelection")
        #expect(Set(Screen.allCases.map(\.id)).count == Screen.allCases.count)
    }
}
