import LineupAppCore
import SwiftUI

/// Shows another screen beside the sidebar. `RootView` owns which screen is shown and puts this in the
/// environment, so a button on any screen can go to another.
public struct ShowScreen: Sendable {
    let action: @MainActor @Sendable (Screen) -> Void

    @MainActor public func callAsFunction(_ screen: Screen) {
        action(screen)
    }
}

extension EnvironmentValues {
    @Entry public var showScreen = ShowScreen { _ in }
}

/// The app's window: a sidebar listing the screens, and the chosen screen beside it, under the model's notices. It owns
/// what the owner has chosen to look at, so a choice on a screen survives going to another and back.
public struct RootView: View {
    let model: AppModel
    let tacticSlot: TacticSlot?
    @State private var navigation: Navigation

    /// - Parameters:
    ///   - screen: the screen the sidebar starts on.
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
        NavigationSplitView {
            List(Screen.allCases, selection: Bindable(navigation).screen) { screen in
                Text(screen.title)
                    .tag(screen)
            }
            .navigationSplitViewColumnWidth(Theme.Layout.sidebarWidth)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                NoticeList(model: model)
                if let screen = navigation.screen {
                    ScreenView(screen: screen, model: model, navigation: navigation, tacticSlot: tacticSlot)
                } else {
                    EmptyState("Choose a screen in the sidebar.")
                        .padding(Theme.Spacing.xl)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .environment(\.showScreen, ShowScreen { navigation.screen = $0 })
        .tint(Theme.Colour.hoopBlue)
        .frame(minWidth: Theme.Layout.minimumWindow.width, minHeight: Theme.Layout.minimumWindow.height)
    }
}

/// The model's notices, each with a button that dismisses it.
struct NoticeList: View {
    let model: AppModel

    var body: some View {
        if !model.notices.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                ForEach(model.notices) { notice in
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                        MarkedText(notice.text, colour: Theme.Colour.amber)
                        Spacer(minLength: Theme.Spacing.m)
                        Button("Dismiss") { model.dismiss(notice) }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.xl)
            .padding(.vertical, Theme.Spacing.m)
            Divider()
        }
    }
}

/// One screen: its title, then its content.
struct ScreenView: View {
    let screen: Screen
    let model: AppModel
    let navigation: Navigation
    let tacticSlot: TacticSlot?

    var body: some View {
        switch screen {
        case .squad: SquadScreen(model: model, navigation: navigation)
        case .tactics: TacticsScreen(model: model, navigation: navigation, startingSlot: tacticSlot)
        case .fixtures: FixturesScreen(model: model)
        case .matchSelection: MatchSelectionScreen(model: model, navigation: navigation)
        case .settings: SettingsScreen(model: model)
        }
    }
}

/// A sentence with a coloured bar beside it: amber for a caution such as a warning or a notice.
struct MarkedText: View {
    let text: String
    let colour: Color

    init(_ text: String, colour: Color) {
        self.text = text
        self.colour = colour
    }

    var body: some View {
        Text(text)
            .font(Theme.Typeface.text())
            .padding(.leading, Theme.Layout.markerWidth + Theme.Spacing.s)
            .background(alignment: .leading) {
                Rectangle()
                    .fill(colour)
                    .frame(width: Theme.Layout.markerWidth)
            }
    }
}
