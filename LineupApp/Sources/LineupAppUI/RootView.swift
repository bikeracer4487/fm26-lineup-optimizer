import LineupAppCore
import SwiftUI

/// The app's window: a sidebar listing the screens, and the chosen screen beside it.
public struct RootView: View {
    @State private var selection: Screen?

    /// - Parameter screen: the screen the sidebar starts on.
    public init(showing screen: Screen = .squad) {
        _selection = State(initialValue: screen)
    }

    public var body: some View {
        NavigationSplitView {
            List(Screen.allCases, selection: $selection) { screen in
                Text(screen.title)
                    .tag(screen)
            }
            .navigationSplitViewColumnWidth(Theme.Layout.sidebarWidth)
        } detail: {
            if let selection {
                ScreenView(screen: selection)
            } else {
                EmptyState("Choose a screen in the sidebar.")
                    .padding(Theme.Spacing.xl)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .tint(Theme.Colour.hoopBlue)
        .frame(minWidth: Theme.Layout.minimumWindow.width, minHeight: Theme.Layout.minimumWindow.height)
    }
}

/// One screen: its title, then its content.
struct ScreenView: View {
    let screen: Screen

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text(screen.title)
                .font(Theme.Typeface.title())
            EmptyState(emptyMessage)
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var emptyMessage: String {
        switch screen {
        case .squad: "No squad yet. Copy your first team in FMRTE, then import it here."
        case .tactics: "No tactic yet. Add the formation and roles you play in FM27 here."
        case .fixtures: "No fixtures yet. Add the next few matches and how much each one matters."
        case .matchSelection: "No lineup yet. A lineup needs a squad, a tactic and the next fixture."
        case .settings: "No settings yet."
        }
    }
}
