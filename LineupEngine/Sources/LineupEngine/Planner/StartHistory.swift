/// Who started which slot in the confirmed lineups, read newest first. Holds one lineup per fixture,
/// kept in date order (fixture id breaks ties), so answers never depend on the order lineups were given.
public struct StartHistory: Sendable {
    /// Oldest first.
    private let lineups: [ConfirmedLineup]

    /// Any order. When two lineups share a fixture id, the later one in `lineups` wins.
    public init(_ lineups: [ConfirmedLineup]) {
        var byFixture: [String: ConfirmedLineup] = [:]
        for lineup in lineups { byFixture[lineup.fixture.raw] = lineup }
        self.lineups = byFixture.values.sorted {
            $0.date != $1.date ? $0.date < $1.date : $0.fixture.raw < $1.fixture.raw
        }
    }

    /// Replaces any lineup already held for the same fixture.
    public func adding(_ lineup: ConfirmedLineup) -> StartHistory {
        StartHistory(lineups + [lineup])
    }

    /// Starts in a row up to but not including `day`, counting back from the most recent lineup.
    /// The run is 0 when the most recent lineup is more than `windowDays` before `day` or he did not
    /// start it; each earlier start extends it only while it is within `windowDays` of the lineup after it.
    public func consecutiveStarts(of player: PlayerID, before day: Day, windowDays: Int) -> Int {
        let earlier = lineups.filter { $0.date < day }
        var count = 0
        var nextDate = day
        for lineup in earlier.reversed() {
            guard lineup.date.days(to: nextDate) <= windowDays, Self.slot(of: player, in: lineup) != nil else { break }
            count += 1
            nextDate = lineup.date
        }
        return count
    }

    /// The slots he started in before `day`, newest first, at most `limit`.
    public func recentSlots(of player: PlayerID, before day: Day, limit: Int) -> [SlotID] {
        var slots: [SlotID] = []
        for lineup in lineups.reversed() where lineup.date < day {
            guard slots.count < limit else { break }
            if let slot = Self.slot(of: player, in: lineup) { slots.append(slot) }
        }
        return slots
    }

    /// The lowest slot, in `SlotID` order, the player started in; nil if he did not start.
    private static func slot(of player: PlayerID, in lineup: ConfirmedLineup) -> SlotID? {
        SlotID.allCases.first { lineup.starters[$0] == player }
    }
}
