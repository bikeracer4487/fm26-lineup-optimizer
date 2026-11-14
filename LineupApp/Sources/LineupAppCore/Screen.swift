/// The app's screens, in the order the top row lists them: the advisors after Match Selection, Settings last.
public enum Screen: String, CaseIterable, Identifiable, Sendable {
    case squad, tactics, fixtures, matchSelection, elevens, rest, training, removal, settings

    public var id: String { rawValue }

    /// The screen's name as its heading shows it.
    public var title: String {
        switch self {
        case .squad: "Squad"
        case .tactics: "Tactics"
        case .fixtures: "Fixtures"
        case .matchSelection: "Match Selection"
        case .elevens: "Elevens"
        case .rest: "Rest"
        case .training: "Training"
        case .removal: "Player Removal"
        case .settings: "Settings"
        }
    }

    /// The screen's name on its pill in the top row: the title, shortened where nine pills need the room.
    public var pillTitle: String {
        switch self {
        case .removal: "Removal"
        case .squad, .tactics, .fixtures, .matchSelection, .elevens, .rest, .training, .settings: title
        }
    }
}
