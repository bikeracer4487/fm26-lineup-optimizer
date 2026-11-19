/// A player's familiarity at the position he is learning, as one import showed it.
public struct FamiliarityObservation: Equatable, Codable, Sendable {
    public let day: Day
    public let familiarity: Int

    public init(day: Day, familiarity: Int) {
        self.day = day
        self.familiarity = familiarity
    }
}

/// How an accepted retraining is going.
public struct RetrainingProgress: Equatable, Sendable {
    /// `behind`: gaining, but at under `retrainingBehindShare` of the pace the estimate needs.
    public enum State: String, Sendable { case noData, improving, behind, stalled, reached }
    public let state: State
    /// Familiarity at the first counted observation; nil without one.
    public let start: Int?
    /// Familiarity at the last counted observation; nil without one.
    public let latest: Int?
    /// From the first observation to the last.
    public let weeks: Double
    /// Nil with under one week of observations; never below 0.
    public let gainedPerWeek: Double?
    /// Nil unless improving or behind at a rate above 0.
    public let weeksToSolid: Int?
    /// The weeks the retraining was estimated to take in all, as handed in; nil when none was.
    public let expectedWeeks: Int?

    init(state: State, start: Int?, latest: Int?, weeks: Double, gainedPerWeek: Double?, weeksToSolid: Int?,
         expectedWeeks: Int? = nil) {
        self.state = state; self.start = start; self.latest = latest; self.weeks = weeks
        self.gainedPerWeek = gainedPerWeek; self.weeksToSolid = weeksToSolid; self.expectedWeeks = expectedWeeks
    }
}

public enum RetrainingTracker {
    /// Absorbs binary floating-point error before weeks are rounded up, so an exact division is not a week more.
    private static let roundingNoise = 1e-9

    /// The same, with the estimate worked out for `player`, who is learning the position, from the familiarity of his
    /// first counted observation (`Training.estimatedWeeks`). There is none before anything is read, for an inversion,
    /// or for a player missing Versatility or a familiarity, and then nothing is behind.
    public static func progress(of retraining: Retraining, observations: [FamiliarityObservation], player: Player,
                                parameters: EngineParameters) -> RetrainingProgress {
        let plain = progress(of: retraining, observations: observations, parameters: parameters)
        guard let start = plain.start,
              let expected = try? Training.estimatedWeeks(for: player, learning: retraining.position, from: start,
                                                          parameters: parameters) else { return plain }
        return progress(of: retraining, observations: observations, expectedWeeks: expected, parameters: parameters)
    }

    /// Counts observations on or after the day the retraining was accepted; of two on one day, the later in the list.
    /// `expectedWeeks` is the estimate for the whole retraining (`Training.estimatedWeeks`, from the familiarity he
    /// started at): with one, a retraining that has gained something over at least `retrainingStalledAfterWeeks` weeks,
    /// but at under `retrainingBehindShare` of the pace that reaches solid in the estimated weeks, is behind. Without
    /// one nothing is.
    public static func progress(of retraining: Retraining, observations: [FamiliarityObservation],
                                expectedWeeks: Int? = nil, parameters: EngineParameters) -> RetrainingProgress {
        var byDay: [Day: Int] = [:]
        for observation in observations where observation.day >= retraining.acceptedOn {
            byDay[observation.day] = observation.familiarity
        }
        let days = byDay.keys.sorted()
        guard let firstDay = days.first, let lastDay = days.last, let start = byDay[firstDay], let latest = byDay[lastDay] else {
            return RetrainingProgress(state: .noData, start: nil, latest: nil, weeks: 0, gainedPerWeek: nil, weeksToSolid: nil,
                                      expectedWeeks: expectedWeeks)
        }
        let weeks = Double(firstDay.days(to: lastDay)) / 7
        // A fall counts as no gain: the figures never go below 0.
        let gainedPerWeek: Double? = weeks >= 1 ? max(0, Double(latest - start) / weeks) : nil
        let solid = parameters.depthSolidFamiliarity.value

        let longEnough = weeks >= Double(parameters.retrainingStalledAfterWeeks.value)
        var state: RetrainingProgress.State
        var weeksToSolid: Int?
        if latest >= solid {
            state = .reached
        } else if longEnough && latest <= start {
            state = .stalled
        } else {
            state = .improving
            if let rate = gainedPerWeek, rate > 0 {
                weeksToSolid = Int((Double(solid - latest) / rate - roundingNoise).rounded(.up))
                // The pace that takes him from where he started to solid in the estimated weeks.
                if longEnough, let expectedWeeks, expectedWeeks > 0,
                   rate < parameters.retrainingBehindShare.value * Double(solid - start) / Double(expectedWeeks) {
                    state = .behind
                }
            }
        }
        return RetrainingProgress(state: state, start: start, latest: latest, weeks: weeks,
                                  gainedPerWeek: gainedPerWeek, weeksToSolid: weeksToSolid, expectedWeeks: expectedWeeks)
    }
}
