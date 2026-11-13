import Foundation
import LineupEngine
import Observation

/// What the owner has chosen to look at, kept while the app is open so it survives a change of screen: the screen,
/// Match Selection's fixture, selected pick and view, the squad table's filter and search, and the tactic shown.
@MainActor @Observable public final class Navigation {
    public var screen: Screen?
    /// The fixture shown. While nil, or once it has left the plan, `MatchPresentation.initialFixture`.
    public var matchFixture: FixtureID?
    /// Holds only while its fixture is shown and the same player is in its slot (`MatchPresentation.selectedSlot`).
    public var matchSelection: PickSelection?
    public var matchView: MatchView
    /// Nil: every squad.
    public var squadShown: Squad?
    public var squadSearch: String
    /// Nil: the primary tactic.
    public var tacticID: UUID?

    public init(screen: Screen? = .squad, matchFixture: FixtureID? = nil, matchSelection: PickSelection? = nil,
                matchView: MatchView = .teamSheet, squadShown: Squad? = nil, squadSearch: String = "",
                tacticID: UUID? = nil) {
        self.screen = screen; self.matchFixture = matchFixture; self.matchSelection = matchSelection
        self.matchView = matchView; self.squadShown = squadShown; self.squadSearch = squadSearch; self.tacticID = tacticID
    }
}
