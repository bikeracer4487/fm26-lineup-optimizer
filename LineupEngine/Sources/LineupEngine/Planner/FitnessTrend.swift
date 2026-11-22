/// His jadedness as the readings show it, with no model.
public struct SeenTrend: Equatable, Sendable {
    public let perWeek: Double
    /// The days of the intervals used, their starts, and the readings at their ends, each once.
    public let days: Int, starts: Int, readings: Int

    public init(perWeek: Double, days: Int, starts: Int, readings: Int) {
        self.perWeek = perWeek; self.days = days; self.starts = starts; self.readings = readings
    }
}

/// What the readings show of one player.
public struct PlayerTrend: Equatable, Sendable {
    public let seen: SeenTrend?
    /// The drift and the gain he takes; either may be missing.
    public let drift: MeasuredRate?, gain: MeasuredRate?
    public let usedIntervals: Int

    public init(seen: SeenTrend?, drift: MeasuredRate?, gain: MeasuredRate?, usedIntervals: Int) {
        self.seen = seen; self.drift = drift; self.gain = gain; self.usedIntervals = usedIntervals
    }

    /// Both rates, or nil.
    public var pair: JadednessRates? {
        guard let drift, let gain else { return nil }
        return JadednessRates(drift: drift, gain: gain)
    }
}

/// A squad's drift or the club's gain.
public struct SharedRate: Equatable, Sendable {
    public let value: Double
    /// The readings at the ends of the intervals behind it, each once, and the earliest of their days.
    public let readings: Int
    public let since: Day

    public init(value: Double, readings: Int, since: Day) {
        self.value = value; self.readings = readings; self.since = since
    }
}

/// Every player's trend, each squad's drift and the club's gain, as the readings show them.
public struct FitnessTrends: Equatable, Sendable {
    /// Every player in `squads` with at least one reading.
    public let players: [PlayerID: PlayerTrend]
    public let squadDrift: [Squad: SharedRate]
    public let clubGain: SharedRate?
    /// `measureFrom` when it is later than the window's first day; else the earliest reading in the window; else nil.
    public let measuredFrom: Day?

    public init(players: [PlayerID: PlayerTrend], squadDrift: [Squad: SharedRate], clubGain: SharedRate?,
                measuredFrom: Day?) {
        self.players = players; self.squadDrift = squadDrift; self.clubGain = clubGain
        self.measuredFrom = measuredFrom
    }

    /// Nothing measured: the state before any reading.
    public static let none = FitnessTrends(players: [:], squadDrift: [:], clubGain: nil, measuredFrom: nil)

    /// Each player's measured pair, where he has both rates.
    public var pairs: [PlayerID: JadednessRates] { players.compactMapValues(\.pair) }
}

/// Works each player's jadedness trend out from the readings kept at each import and the confirmed lineups.
public enum FitnessTrend {
    /// Two readings of one player with no reading of his between them, used for a rate.
    private struct Interval {
        let player: PlayerID
        let squad: Squad
        let earlier: Day
        let later: Day
        let change: Int
        let days: Int
        let starts: Int
    }

    /// One interval's rate, with what orders it in a median.
    private struct Rated {
        let value: Double
        let interval: Interval
    }

    public static func rates(readings: [PlayerID: [FitnessReading]], confirmed: [ConfirmedLineup],
                             squads: [PlayerID: Squad], asOf: Day, measureFrom: Day?,
                             parameters: EngineParameters) -> FitnessTrends {
        let rules = parameters.jadednessTrendRules.value
        let floor = parameters.jadednessFloor.value
        let windowStart = asOf.adding(days: -rules.windowDays)
        let keys = readings.keys
            .filter { squads[$0] != nil && !(readings[$0] ?? []).isEmpty }
            .sorted { $0.key < $1.key }

        let starts = startsByPlayer(confirmed)

        // One pass: every player's readings in day order and his used intervals with their starts.
        var intervalsByPlayer: [PlayerID: [Interval]] = [:]
        var earliestInWindow: Day?
        for player in keys {
            guard let squad = squads[player] else { continue }
            let own = inDayOrder(readings[player] ?? [])
            for reading in own where reading.day <= asOf && reading.day >= windowStart {
                earliestInWindow = min(earliestInWindow ?? reading.day, reading.day)
            }
            var startsAt = Array(repeating: 0, count: own.count)
            for (fixture, date) in starts[player] ?? [:] {
                if let index = own.firstIndex(where: { $0.day > date || $0.includes.contains(fixture) }) {
                    startsAt[index] += 1
                }
            }
            var used: [Interval] = []
            for index in own.indices.dropFirst() {
                let earlier = own[index - 1], later = own[index]
                let days = earlier.day.days(to: later.day)
                guard later.day <= asOf, later.day.days(to: asOf) <= rules.windowDays,
                      measureFrom.map({ earlier.day >= $0 && later.day >= $0 }) ?? true,
                      (1...rules.longestGapDays).contains(days),
                      !earlier.isInjured, !later.isInjured,
                      Double(earlier.jadedness) > floor, Double(later.jadedness) > floor
                else { continue }
                used.append(Interval(player: player, squad: squad, earlier: earlier.day, later: later.day,
                                     change: later.jadedness - earlier.jadedness, days: days,
                                     starts: startsAt[index]))
            }
            intervalsByPlayer[player] = used
        }

        // Own drifts.
        var restRates: [PlayerID: [Rated]] = [:]
        var ownDrift: [PlayerID: MeasuredRate] = [:]
        for player in keys {
            let rated = (intervalsByPlayer[player] ?? []).filter { $0.starts == 0 }
                .map { Rated(value: Double($0.change) / Double($0.days), interval: $0) }
            restRates[player] = rated
            if rated.count >= rules.fewestOwnIntervals, let value = median(rated) {
                ownDrift[player] = MeasuredRate(value, .own(intervals: rated.count))
            }
        }

        // Squad drifts.
        var squadDrift: [Squad: SharedRate] = [:]
        for squad in Squad.allCases {
            let rated = keys.filter { squads[$0] == squad }.flatMap { restRates[$0] ?? [] }
            if let shared = shared(rated, rules: rules) { squadDrift[squad] = shared }
        }

        // The drift each player takes.
        var drift: [PlayerID: MeasuredRate] = [:]
        for player in keys {
            guard let squad = squads[player] else { continue }
            if let own = ownDrift[player] {
                drift[player] = own
            } else if let shared = squadDrift[squad] {
                drift[player] = MeasuredRate(shared.value, .squad(squad))
            }
        }

        // Each start interval's gain, own gains and the club's gain.
        var gains: [PlayerID: [Rated]] = [:]
        var ownGain: [PlayerID: MeasuredRate] = [:]
        for player in keys {
            guard let taken = drift[player] else { continue }
            let rated = (intervalsByPlayer[player] ?? []).filter { $0.starts > 0 }.map {
                Rated(value: (Double($0.change) - taken.value * Double($0.days)) / Double($0.starts), interval: $0)
            }
            gains[player] = rated
            if rated.count >= rules.fewestOwnIntervals, let value = median(rated) {
                ownGain[player] = MeasuredRate(value, .own(intervals: rated.count))
            }
        }
        let clubGain = shared(keys.flatMap { gains[$0] ?? [] }, rules: rules)

        var players: [PlayerID: PlayerTrend] = [:]
        for player in keys {
            let used = intervalsByPlayer[player] ?? []
            players[player] = PlayerTrend(
                seen: seen(used, rules: rules), drift: drift[player],
                gain: ownGain[player] ?? clubGain.map { MeasuredRate($0.value, .club) },
                usedIntervals: used.count)
        }

        let measuredFrom: Day?
        if let measureFrom, measureFrom > windowStart {
            measuredFrom = measureFrom
        } else {
            measuredFrom = earliestInWindow
        }
        return FitnessTrends(players: players, squadDrift: squadDrift, clubGain: clubGain, measuredFrom: measuredFrom)
    }

    /// Each player's starts, by fixture: a fixture confirmed twice counts once, at the earlier of its dates.
    private static func startsByPlayer(_ confirmed: [ConfirmedLineup]) -> [PlayerID: [FixtureID: Day]] {
        var starts: [PlayerID: [FixtureID: Day]] = [:]
        for lineup in confirmed {
            for player in Set(lineup.starters.values) {
                let date = starts[player]?[lineup.fixture].map { min($0, lineup.date) } ?? lineup.date
                starts[player, default: [:]][lineup.fixture] = date
            }
        }
        return starts
    }

    /// In day order; two on one day are one, the later in the list replacing the earlier.
    private static func inDayOrder(_ readings: [FitnessReading]) -> [FitnessReading] {
        let sorted = readings.enumerated()
            .sorted { ($0.element.day, $0.offset) < ($1.element.day, $1.offset) }
            .map(\.element)
        var merged: [FitnessReading] = []
        for reading in sorted {
            if let last = merged.last, last.day == reading.day {
                merged[merged.count - 1] = reading.replacing(last)
            } else {
                merged.append(reading)
            }
        }
        return merged
    }

    private static func seen(_ used: [Interval], rules: JadednessTrendRules) -> SeenTrend? {
        guard used.count >= rules.fewestOwnIntervals else { return nil }
        var change = 0, days = 0, starts = 0
        for interval in used {
            change += interval.change; days += interval.days; starts += interval.starts
        }
        return SeenTrend(perWeek: Double(change) / Double(days) * 7, days: days, starts: starts,
                         readings: ends(used).count)
    }

    /// A squad's or the club's rate: at least `fewestSharedIntervals`, ending on at least `fewestSharedDays` days.
    private static func shared(_ rated: [Rated], rules: JadednessTrendRules) -> SharedRate? {
        guard rated.count >= rules.fewestSharedIntervals,
              Set(rated.map(\.interval.later)).count >= rules.fewestSharedDays,
              let value = median(rated)
        else { return nil }
        let ends = ends(rated.map(\.interval))
        guard let since = ends.map(\.day).min() else { return nil }
        return SharedRate(value: value, readings: ends.count, since: since)
    }

    private struct End: Hashable {
        let player: PlayerID
        let day: Day
    }

    /// The readings at the ends of these intervals, each once.
    private static func ends(_ intervals: [Interval]) -> Set<End> {
        var ends = Set<End>()
        for interval in intervals {
            ends.insert(End(player: interval.player, day: interval.earlier))
            ends.insert(End(player: interval.player, day: interval.later))
        }
        return ends
    }

    /// Sorted by value, then player key, then the later reading's day; an even count takes the mean of the middle two.
    private static func median(_ rated: [Rated]) -> Double? {
        guard !rated.isEmpty else { return nil }
        let sorted = rated.sorted {
            ($0.value, $0.interval.player.key, $0.interval.later)
                < ($1.value, $1.interval.player.key, $1.interval.later)
        }
        let middle = sorted.count / 2
        if sorted.count % 2 == 1 { return sorted[middle].value }
        return (sorted[middle - 1].value + sorted[middle].value) / 2
    }
}
