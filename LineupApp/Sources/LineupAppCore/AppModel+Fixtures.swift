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
        if before.plan != settings.plan || before.conditionFloor != settings.conditionFloor
            || before.clubOverride != settings.clubOverride || before.primaryTacticID != settings.primaryTacticID {
            replan()
        }
    }

    /// The fixture's own tactic while it is saved, else the primary.
    public func tactic(for fixture: StoredFixture) -> StoredTactic? {
        fixture.tacticID.flatMap { id in tactics.first { $0.id == id } } ?? primaryTactic
    }
}
