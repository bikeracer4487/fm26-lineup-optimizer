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

/// The app's window: a sidebar listing the screens, and the chosen screen beside it, under the model's notices.
public struct RootView: View {
    let model: AppModel
    let tacticSlot: TacticSlot?
    @State private var selection: Screen?

    /// - Parameters:
    ///   - screen: the screen the sidebar starts on.
    ///   - tacticSlot: the slot the Tactics editor opens with selected.
    public init(model: AppModel, showing screen: Screen = .squad, tacticSlot: TacticSlot? = nil) {
        self.model = model
        self.tacticSlot = tacticSlot
        _selection = State(initialValue: screen)
    }

    public var body: some View {
        let selected = $selection
        NavigationSplitView {
            List(Screen.allCases, selection: $selection) { screen in
                Text(screen.title)
                    .tag(screen)
            }
            .navigationSplitViewColumnWidth(Theme.Layout.sidebarWidth)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                NoticeList(model: model)
                if let selection {
                    ScreenView(screen: selection, model: model, tacticSlot: tacticSlot)
                } else {
                    EmptyState("Choose a screen in the sidebar.")
                        .padding(Theme.Spacing.xl)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .environment(\.showScreen, ShowScreen { selected.wrappedValue = $0 })
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
    let tacticSlot: TacticSlot?

    var body: some View {
        switch screen {
        case .squad: SquadScreen(model: model)
        case .tactics: TacticsScreen(model: model, startingSlot: tacticSlot)
        case .fixtures: FixturesScreen(model: model)
        case .matchSelection: placeholder("No lineup yet. A lineup needs a squad, a tactic and the next fixture.")
        case .settings: SettingsScreen(model: model)
        }
    }

    /// A screen not built yet: its title and what it will hold.
    private func placeholder(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text(screen.title)
                .font(Theme.Typeface.title())
            EmptyState(message)
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
