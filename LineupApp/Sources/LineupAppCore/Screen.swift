/// The app's screens, in the order the sidebar lists them.
public enum Screen: String, CaseIterable, Identifiable, Sendable {
    case squad, tactics, fixtures, matchSelection, settings

    public var id: String { rawValue }

    /// The screen's name as the sidebar and the screen's heading show it.
    public var title: String {
        switch self {
        case .squad: "Squad"
        case .tactics: "Tactics"
        case .fixtures: "Fixtures"
        case .matchSelection: "Match Selection"
        case .settings: "Settings"
        }
    }
}
