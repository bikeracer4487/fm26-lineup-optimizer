import Foundation
import LineupEngine

/// The line on the Fixtures table that says how many matches are earlier, with the button that shows or hides them.
public struct EarlierMatchesLine: Equatable, Sendable {
    public let text: String
    /// The button's word: "Show" or "Hide".
    public let action: String
    /// What the button sets `showsEarlierMatches` to.
    public let showsWhenPressed: Bool

    public init(text: String, action: String, showsWhenPressed: Bool) {
        self.text = text; self.action = action; self.showsWhenPressed = showsWhenPressed
    }

    /// What VoiceOver says for the button, which "Show" alone would not name.
    public var actionLabel: String { showsWhenPressed ? "Show earlier matches" : "Hide earlier matches" }
}

/// Earlier matches: those from before the days the advice reads. Fixtures and Match Selection leave them out, so a past
/// season does not bury the next match. It is a rule about what those two screens list and nothing else: `fixtures`,
/// `history` and `planState` stay whole, and the planner, the advisors and the league read them as before.
extension AppModel {
    /// The first day of the window the two screens show: as many days ending today in the game, today included, as the
    /// engine counts confirmed matches over (`matchesHereWindowDays`). The count is the engine's; the days are not
    /// quite, since the advice counts back from the last import and the screens from today in the game.
    public var earlierMatchesBefore: Day {
        settings.currentDate.adding(days: -(planParameters.matchesHereWindowDays.value - 1))
    }

    /// Whether the fixture is from before the window and not still to be planned. Before the window a confirmed match
    /// is earlier and so is one never confirmed; a match the plan still starts from or after is not, whatever its date.
    public func isEarlier(_ fixture: StoredFixture) -> Bool {
        isEarlier(fixture, confirmed: confirmedFixtures)
    }

    /// How many saved fixtures are earlier, whether or not they are shown.
    public var earlierMatchCount: Int {
        let confirmed = confirmedFixtures
        return fixtures.count { isEarlier($0, confirmed: confirmed) }
    }

    /// The fixtures the Fixtures table lists, in `fixtures`' order: those not earlier, or all of them while
    /// `showsEarlierMatches`.
    public var listedFixtures: [StoredFixture] {
        guard !showsEarlierMatches else { return fixtures }
        let confirmed = confirmedFixtures
        return fixtures.filter { !isEarlier($0, confirmed: confirmed) }
    }

    /// What the Fixtures table says about the earlier matches; nil when there is none.
    public var earlierMatchesLine: EarlierMatchesLine? {
        let count = earlierMatchCount
        guard count > 0 else { return nil }
        let matches = "\(count) match\(count == 1 ? "" : "es") from before \(DayText.short(earlierMatchesBefore))"
        if showsEarlierMatches {
            return EarlierMatchesLine(text: "Showing \(matches).", action: "Hide", showsWhenPressed: false)
        }
        return EarlierMatchesLine(text: "\(matches) \(count == 1 ? "is" : "are") not shown.", action: "Show",
                                  showsWhenPressed: true)
    }

    /// Shows or hides the earlier matches on both screens. It changes what is listed and nothing else: no plan, no
    /// advice and no file.
    public func setShowsEarlierMatches(_ shows: Bool) {
        showsEarlierMatches = shows
    }

    /// The plans without those of earlier matches, or all of them while `showsEarlierMatches`. A planned lineup's
    /// fixture is never earlier, so only confirmed and missed matches are left out.
    func withoutEarlierMatches(_ plans: [FixturePlan]) -> [FixturePlan] {
        guard !showsEarlierMatches else { return plans }
        let confirmed = confirmedFixtures
        return plans.filter { !isEarlier($0.fixture, confirmed: confirmed) }
    }

    /// What Match Selection shows in place of a plan: what is missing or why the plan stopped; or, when there is a plan
    /// and every match in it is earlier (the summer, before the next season's fixtures are entered), that there is no
    /// match to play, with the way to Fixtures. Nil when there is something to show.
    public var matchNotReady: NotReady? {
        if let notReady = MatchPresentation.notReady(planState) { return notReady }
        guard shownPlans.isEmpty, earlierMatchCount > 0 else { return nil }
        return NotReady(
            message: "No match to play, and none played since \(DayText.short(earlierMatchesBefore)). "
                + "Add the next matches on the Fixtures screen.",
            problems: [], isFailure: false, action: MatchPresentation.goTo(.fixtures), screen: .fixtures)
    }

    /// The fixtures with a confirmed lineup.
    private var confirmedFixtures: Set<FixtureID> {
        Set(history.map(\.lineup.fixture))
    }

    private func isEarlier(_ fixture: StoredFixture, confirmed: Set<FixtureID>) -> Bool {
        guard fixture.date < earlierMatchesBefore else { return false }
        let stillToBePlanned = planStartDay.map { fixture.date >= $0 } ?? false && !confirmed.contains(fixture.id)
        return !stillToBePlanned
    }
}
