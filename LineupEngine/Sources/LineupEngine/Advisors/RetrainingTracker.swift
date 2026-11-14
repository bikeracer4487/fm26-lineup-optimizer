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
    public enum State: String, Sendable { case noData, improving, stalled, reached }
    public let state: State
    /// Familiarity at the first counted observation; nil without one.
    public let start: Int?
    /// Familiarity at the last counted observation; nil without one.
    public let latest: Int?
    /// From the first observation to the last.
    public let weeks: Double
    /// Nil with under one week of observations; never below 0.
    public let gainedPerWeek: Double?
    /// Nil unless improving at a rate above 0.
    public let weeksToSolid: Int?
}

public enum RetrainingTracker {
    /// Absorbs binary floating-point error before weeks are rounded up, so an exact division is not a week more.
    private static let roundingNoise = 1e-9

    /// Counts observations on or after the day the retraining was accepted; of two on one day, the later in the list.
    public static func progress(of retraining: Retraining, observations: [FamiliarityObservation],
                                parameters: EngineParameters) -> RetrainingProgress {
        var byDay: [Day: Int] = [:]
        for observation in observations where observation.day >= retraining.acceptedOn {
            byDay[observation.day] = observation.familiarity
        }
        let days = byDay.keys.sorted()
        guard let firstDay = days.first, let lastDay = days.last, let start = byDay[firstDay], let latest = byDay[lastDay] else {
            return RetrainingProgress(state: .noData, start: nil, latest: nil, weeks: 0, gainedPerWeek: nil, weeksToSolid: nil)
        }
        let weeks = Double(firstDay.days(to: lastDay)) / 7
        // A fall counts as no gain: the figures never go below 0.
        let gainedPerWeek: Double? = weeks >= 1 ? max(0, Double(latest - start) / weeks) : nil
        let solid = parameters.depthSolidFamiliarity.value

        let state: RetrainingProgress.State
        var weeksToSolid: Int?
        if latest >= solid {
            state = .reached
        } else if weeks >= Double(parameters.retrainingStalledAfterWeeks.value) && latest <= start {
            state = .stalled
        } else {
            state = .improving
            if let rate = gainedPerWeek, rate > 0 {
                weeksToSolid = Int((Double(solid - latest) / rate - roundingNoise).rounded(.up))
            }
        }
        return RetrainingProgress(state: state, start: start, latest: latest, weeks: weeks,
                                  gainedPerWeek: gainedPerWeek, weeksToSolid: weeksToSolid)
    }
}
