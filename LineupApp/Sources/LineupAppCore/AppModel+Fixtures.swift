import Foundation
import LineupEngine

extension AppModel {
    /// Adds a fixture with a new id and the primary tactic, keeping the list in date order.
    @discardableResult public func addFixture(date: Day, opponent: String, importance: Importance) -> FixtureID {
        let id = FixtureID(UUID().uuidString)
        fixtures.append(StoredFixture(id: id, date: date, opponent: opponent, importance: importance))
        fixtures.sort(by: Self.dateOrder)
        save(.fixtures)
        return id
    }

    /// Replaces the saved fixture with the same id, keeping the list in date order; a fixture no longer saved is
    /// left out.
    public func update(_ fixture: StoredFixture) {
        guard let index = fixtures.firstIndex(where: { $0.id == fixture.id }) else { return }
        fixtures[index] = fixture
        fixtures.sort(by: Self.dateOrder)
        save(.fixtures)
    }

    /// Removes the fixture and any lineup confirmed for it.
    public func deleteFixture(_ id: FixtureID) {
        fixtures.removeAll { $0.id == id }
        save(.fixtures)
        if history.contains(where: { $0.lineup.fixture == id }) {
            history.removeAll { $0.lineup.fixture == id }
            save(.history)
        }
    }

    /// Takes the settings as given; the planner reports any plan setting out of range.
    public func update(_ settings: AppSettings) {
        self.settings = settings
        save(.settings)
    }

    /// The fixture's own tactic while it is saved, else the primary.
    public func tactic(for fixture: StoredFixture) -> StoredTactic? {
        fixture.tacticID.flatMap { id in tactics.first { $0.id == id } } ?? primaryTactic
    }
}
