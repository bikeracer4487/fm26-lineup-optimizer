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

    /// Whether the screen is under the "More" pill rather than on the top row: the ones the owner visits less often.
    public var isInMenu: Bool {
        switch self {
        case .tactics, .elevens, .rest, .offers, .settings: true
        case .squad, .fixtures, .league, .matchSelection, .training, .removal, .scouting: false
        }
    }

    /// The screens with a pill of their own, in the order of `allCases`.
    public static var rowScreens: [Screen] { allCases.filter { !$0.isInMenu } }

    /// The screens in the "More" menu, in the order of `allCases`.
    public static var menuScreens: [Screen] { allCases.filter(\.isInMenu) }

    /// The name on the pill that opens the menu.
    public static let moreTitle = "More"

    /// What the "More" pill reads: the title of the screen shown when it is in the menu, else "More".
    public static func morePillTitle(current: Screen?) -> String {
        if let current, current.isInMenu { current.title } else { moreTitle }
    }
}
