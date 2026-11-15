import Foundation
import LineupEngine

extension AppModel {
    /// Adds a fixture with a new id and the primary tactic, keeping the list in date order.
    @discardableResult public func addFixture(date: Day, opponent: String, importance: Importance) -> FixtureID {
        let id = FixtureID(UUID().uuidString)
        fixtures.append(StoredFixture(id: id, date: date, opponent: opponent, importance: importance))
        fixtures.sort(by: Self.dateOrder)
        save(.fixtures)
        replan()
        return id
    }

    /// Replaces the saved fixture with the same id, keeping the list in date order; a fixture no longer saved is
    /// left out. A lineup confirmed for the fixture moves to its new date, so the history's dates stay those of
    /// its fixtures; its starters, names and tactic name stay as confirmed, being what was played.
    public func update(_ fixture: StoredFixture) {
        guard let index = fixtures.firstIndex(where: { $0.id == fixture.id }) else { return }
        let moved = fixtures[index].date != fixture.date
        fixtures[index] = fixture
        fixtures.sort(by: Self.dateOrder)
        save(.fixtures)
        if moved, let record = history.firstIndex(where: { $0.lineup.fixture == fixture.id }) {
            history[record].lineup.date = fixture.date
            save(.history)
        }
        replan()
    }

    /// How soon after one suggestion has been taken from the table another is ignored. Taking one replans before the
    /// click is over and the table may move under the pointer, so the second click of a double-click would otherwise
    /// take the next fixture's suggestion. The interval runs from the end of the last one taken, after its replan.
    /// It is the Training screen's interval, but kept apart: a training action does not hold this one up.
    public static let suggestionActionInterval: TimeInterval = 0.5

    /// Sets the fixture's importance to its suggestion's and plans again; everything else about it stays. Nothing
    /// happens where the table shows no suggestion for it (confirmed, past, the same as the importance chosen, or no
    /// such fixture), or within `suggestionActionInterval` of the end of the last suggestion taken.
    public func useSuggestion(for id: FixtureID) {
        let start = environment.now()
        if let last = lastSuggestionAction, start - last < Self.suggestionActionInterval { return }
        guard let fixture = fixtures.first(where: { $0.id == id }),
              let line = suggestionLine(for: fixture) else { return }
        var changed = fixture
        changed.importance = line.importance
        update(changed)
        lastSuggestionAction = environment.now()
    }

    /// Whether the table offers "Use it" for the fixture: it shows a suggestion line, and its editor is not the one open
    /// (`editing`), where the editor's own button does the same.
    public func offersUseIt(for fixture: StoredFixture, editing: FixtureID?) -> Bool {
        fixture.id != editing && suggestionLine(for: fixture) != nil
    }

    /// Removes the fixture and any lineup confirmed for it.
    public func deleteFixture(_ id: FixtureID) {
        fixtures.removeAll { $0.id == id }
        save(.fixtures)
        if history.contains(where: { $0.lineup.fixture == id }) {
            history.removeAll { $0.lineup.fixture == id }
            save(.history)
        }
        replan()
    }

    /// Takes the settings as given; the planner reports any plan setting out of range. Replans only when something the
    /// plan reads has changed: the plan settings, the condition floor, the club or the primary tactic.
    public func update(_ settings: AppSettings) {
        let before = self.settings
        self.settings = settings
        save(.settings)
        // The club's name decides who reads as on loan here, and a loanee holds no mark.
        if before.clubOverride != settings.clubOverride { dropSpentMarks() }
        if before.situation != settings.situation { adviceCache?.suggestions = nil }
        if before.plan != settings.plan || before.conditionFloor != settings.conditionFloor
            || before.clubOverride != settings.clubOverride || before.primaryTacticID != settings.primaryTacticID {
            replan()
        }
    }

    /// The owner's word on where the club stands in the league. It changes the suggested importance of league matches
    /// only: the kept suggestions are cleared and worked out again when read, and nothing is planned or advised again.
    public func setLeagueSituation(_ situation: LeagueSituation) {
        settings.leagueSituation = situation
        save(.settings)
        adviceCache?.suggestions = nil
    }

    /// The league situation menu, in the engine's words and order.
    public static var leagueSituationChoices: [(value: LeagueSituation, title: String)] {
        LeagueSituation.allCases.map { ($0, AdvisorText.name($0)) }
    }

    public static let leagueSituationLabel = "League situation"

    /// The fixture's own tactic while it is saved, else the primary.
    public func tactic(for fixture: StoredFixture) -> StoredTactic? {
        fixture.tacticID.flatMap { id in tactics.first { $0.id == id } } ?? primaryTactic
    }
}
