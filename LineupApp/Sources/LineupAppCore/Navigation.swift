import Foundation
import LineupEngine
import Observation

/// A fixture being added or changed in the Fixtures editor, kept until it is saved or cancelled.
public struct FixtureEditing: Identifiable, Equatable, Sendable {
    /// A new one for each opening of the editor.
    public let id: UUID
    public var draft: FixtureDraft

    public init(draft: FixtureDraft) {
        self.id = UUID(); self.draft = draft
    }
}

/// What the owner has chosen to look at, kept while the app is open so it survives a change of screen: the screen,
/// Match Selection's fixture, selected pick and view, the squad table's filter, search and sort, the tactic shown, and
/// a fixture being edited.
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
    public var squadSort = SquadSort()
    /// Nil: the editor is closed.
    public var fixtureEditing: FixtureEditing?

    public init(screen: Screen? = .squad, matchFixture: FixtureID? = nil, matchSelection: PickSelection? = nil,
                matchView: MatchView = .teamSheet, squadShown: Squad? = nil, squadSearch: String = "",
                tacticID: UUID? = nil) {
        self.screen = screen; self.matchFixture = matchFixture; self.matchSelection = matchSelection
        self.matchView = matchView; self.squadShown = squadShown; self.squadSearch = squadSearch; self.tacticID = tacticID
    }
}
