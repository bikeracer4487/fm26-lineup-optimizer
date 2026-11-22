import Foundation

/// The cost of starting a player today, and the later fixture a match off would keep him from being jaded for.
public struct RestDue: Equatable, Sendable {
    public let adjustment: Adjustment
    /// M: the first later fixture before which starting today would leave him above `jadedThreshold`.
    public let fixture: FixtureID

    public init(adjustment: Adjustment, fixture: FixtureID) {
        self.adjustment = adjustment; self.fixture = fixture
    }
}

/// Puts a cost on starting a player today when a match off would keep him under the jaded line for a later fixture.
///
/// Only for a player with a measured pair: with the fixed figures nobody is rested by this rule. His jadedness is
/// projected through the later fixtures twice, starting today and resting today, starting every later fixture he is not
/// rejected for in both. M is the first later fixture he is not rejected for, not of high importance, before which the
/// starting projection is above `jadedThreshold`. When resting keeps him under the line there and he is in M's first eleven with an advantage
/// over the second-eleven player, the cost is that advantage weighted by M's importance over today's, scaled by the
/// saving-players setting and capped at `savingCostCeiling`.
public enum RestBeforeLine {
    /// The cost of starting `player` today when a match off would keep him from being jaded for a later fixture.
    /// `jadedness` is his projected jadedness before today's match. Nil when there is none.
    public static func adjustment(for player: Player, jadedness: Double, today: Fixture, later: [LaterFixture],
                                  rates: JadednessRates?, settings: PlanSettings, parameters: EngineParameters) -> RestDue? {
        let weights = parameters.importanceWeights.value
        guard settings.savingPlayers > 0, let rates, let todayWeight = SavingPlayers.usable(weights[today.importance]),
              !today.rejected.contains(player.id) else { return nil }

        let line = parameters.jadedThreshold.value
        func rounded(_ jadedness: Double) -> Int { Int(jadedness.rounded()) }
        // Date then id, so the walk runs in the same order whatever order the fixtures came in.
        let ordered = later.filter { today.date.days(to: $0.fixture.date) > 0 }
            .sorted { ($0.fixture.date, $0.fixture.id.raw) < ($1.fixture.date, $1.fixture.id.raw) }
        var starting = FitnessProjection.jadednessAfterMatch(jadedness, rates: rates, parameters: parameters)
        var resting = jadedness
        var previous = today.date
        var found: LaterFixture?
        for item in ordered {
            let m = item.fixture
            let days = previous.days(to: m.date)
            previous = m.date
            starting = FitnessProjection.jadednessAfterDays(days, starting, intensity: settings.trainingIntensity,
                                                            rates: rates, parameters: parameters)
            resting = FitnessProjection.jadednessAfterDays(days, resting, intensity: settings.trainingIntensity,
                                                           rates: rates, parameters: parameters)
            // A fixture the manager has rejected him for is one he does not start, either way, and being jaded for a
            // match he will not play costs him nothing: it cannot be M.
            guard !m.rejected.contains(player.id) else { continue }
            if m.importance != .high && rounded(starting) > line {
                found = item
                break
            }
            starting = FitnessProjection.jadednessAfterMatch(starting, rates: rates, parameters: parameters)
            resting = FitnessProjection.jadednessAfterMatch(resting, rates: rates, parameters: parameters)
        }

        // A match off now does not save him when he is over the line before M either way.
        guard let found, rounded(resting) <= line else { return nil }
        guard let (_, tier) = found.tiers.slot(of: player.id), tier == 1,
              let advantage = found.tiers.advantage(of: player.id), advantage > 0,
              let weight = SavingPlayers.usable(weights[found.fixture.importance]) else { return nil }

        // Capped, so a match-day value stays far inside the range the assignment solver accepts.
        let cost = min(settings.savingPlayers * (advantage * weight / todayWeight), parameters.savingCostCeiling.value)
        guard cost > 0 else { return nil }
        let gain = Int(rates.gain.value.rounded())
        let reason = "Rested before he passes \(line): at about +\(gain) a start, starting today would leave him jaded for "
            + "\(found.fixture.opponent) on \(AdvisorText.shortDay(found.fixture.date))"
        return RestDue(adjustment: Adjustment(kind: .restedBeforeLine, cost: cost, reason: reason), fixture: found.fixture.id)
    }
}
