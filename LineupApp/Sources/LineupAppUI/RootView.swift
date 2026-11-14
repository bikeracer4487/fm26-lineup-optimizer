import LineupAppCore
import SwiftUI

/// Shows another screen on the board. `RootView` owns which screen is shown and puts this in the environment, so a
/// button on any screen can go to another.
public struct ShowScreen: Sendable {
    let action: @MainActor @Sendable (Screen) -> Void

    @MainActor public func callAsFunction(_ screen: Screen) {
        action(screen)
    }
}

extension EnvironmentValues {
    @Entry public var showScreen = ShowScreen { _ in }
}

/// The app's window: a board on the wall, with the club's name, the screens as pills and the date in the game across
/// the top, the model's notices under them, and the chosen screen below. It owns what the owner has chosen to look
/// at, so a choice on a screen survives going to another and back. The board is white whatever the system's
/// appearance, so the window is drawn in the light appearance and the system's controls are drawn for it.
public struct RootView: View {
    let model: AppModel
    let tacticSlot: TacticSlot?
    @State private var navigation: Navigation

    /// - Parameters:
    ///   - screen: the screen the board starts on.
    ///   - tacticSlot: the slot the Tactics editor opens with selected.
    ///   - matchStart: the fixture, pick and view Match Selection opens with.
    public init(model: AppModel, showing screen: Screen = .squad, tacticSlot: TacticSlot? = nil,
                matchStart: MatchStart = MatchStart()) {
        self.model = model
        self.tacticSlot = tacticSlot
        var selection: PickSelection?
        if let slot = matchStart.slot, case .ready(let plans) = model.planState,
           let plan = MatchPresentation.chosen(matchStart.fixture, in: plans) {
            selection = MatchPresentation.selection(at: slot, in: plan)
        }
        _navigation = State(initialValue: Navigation(screen: screen, matchFixture: matchStart.fixture,
                                                     matchSelection: selection, matchView: matchStart.view))
    }

    public var body: some View {
        let navigation = navigation
        BoardFrame {
            VStack(alignment: .leading, spacing: Theme.Board.rowGap) {
                TopRow(model: model, navigation: navigation)
                NoticeNotes(model: model)
                if let screen = navigation.screen {
                    ScreenView(screen: screen, model: model, navigation: navigation, tacticSlot: tacticSlot)
                } else {
                    EmptyState("Choose a screen above.")
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .environment(\.showScreen, ShowScreen { navigation.screen = $0 })
        .boardAppearance()
        .frame(minWidth: Theme.Layout.minimumWindow.width, minHeight: Theme.Layout.minimumWindow.height)
    }
}

extension View {
    /// The board's look for anything the system draws: the light appearance, whatever the system is set to, so
    /// fields, menus and pickers are drawn for a white board; marker blue as their accent; the text face.
    public func boardAppearance() -> some View {
        self
            .tint(Theme.Colour.markerBlue)
            .environment(\.colorScheme, .light)
            .preferredColorScheme(.light)
    }
}

/// One screen.
struct ScreenView: View {
    let screen: Screen
    let model: AppModel
    let navigation: Navigation
    let tacticSlot: TacticSlot?

    var body: some View {
        switch screen {
        case .squad: SquadScreen(model: model, navigation: navigation)
        case .tactics: TacticsScreen(model: model, navigation: navigation, startingSlot: tacticSlot)
        case .fixtures: FixturesScreen(model: model, navigation: navigation)
        case .matchSelection: MatchSelectionScreen(model: model, navigation: navigation)
        case .settings: SettingsScreen(model: model)
        }
    }
}
