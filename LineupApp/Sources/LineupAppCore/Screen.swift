/// The app's screens, in the order the top row lists them: the advisors after Match Selection, Settings last.
public enum Screen: String, CaseIterable, Identifiable, Sendable {
    case squad, tactics, fixtures, league, matchSelection, elevens, rest, training, removal, scouting, offers, settings

    public var id: String { rawValue }

    /// The screen's name as its heading shows it.
    public var title: String {
        switch self {
        case .squad: "Squad"
        case .tactics: "Tactics"
        case .fixtures: "Fixtures"
        case .league: "League"
        case .matchSelection: "Match Selection"
        case .elevens: "Elevens"
        case .rest: "Rest"
        case .training: "Training"
        case .removal: "Player Removal"
        case .scouting: "Scouting"
        case .offers: "Offers"
        case .settings: "Settings"
        }
    }

    /// The screen's name on its pill in the top row: the title, shortened where twelve pills need the room.
    public var pillTitle: String {
        switch self {
        case .removal: "Removal"
        case .squad, .tactics, .fixtures, .league, .matchSelection, .elevens, .rest, .training, .scouting, .offers,
             .settings: title
        }
    }
}
