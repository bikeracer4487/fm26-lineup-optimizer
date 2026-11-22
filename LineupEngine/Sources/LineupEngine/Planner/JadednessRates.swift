/// Where a measured rate came from.
public enum RateSource: Equatable, Sendable { case own(intervals: Int), squad(Squad), club }

/// One measured rate and where it came from.
public struct MeasuredRate: Equatable, Sendable {
    public let value: Double
    public let source: RateSource

    public init(_ value: Double, _ source: RateSource) {
        self.value = value
        self.source = source
    }
}

/// A player's measured pair: used together or not at all.
public struct JadednessRates: Equatable, Sendable {
    /// The change for each day without a start; above or below 0.
    public let drift: MeasuredRate
    /// The change for each start.
    public let gain: MeasuredRate

    public init(drift: MeasuredRate, gain: MeasuredRate) {
        self.drift = drift
        self.gain = gain
    }
}

/// The numbers behind measuring each player's jadedness trend from the imports.
public struct JadednessTrendRules: Sendable, Equatable {
    /// How far back a trend is read, in days.
    public var windowDays: Int
    /// An interval between two imports longer than this is not used.
    public var longestGapDays: Int
    /// Intervals of his own that a player needs for a rate of his own.
    public var fewestOwnIntervals: Int
    /// Intervals a squad or the club needs to speak for a player with too few of his own.
    public var fewestSharedIntervals: Int
    /// Days a squad's intervals must cover to speak for a player.
    public var fewestSharedDays: Int
    /// The weeks, in days, over which a trend is shown as the last weeks.
    public var onCourseDays: Int
    /// A drift within this many points a week of nothing is steady.
    public var steadyPerWeek: Double
    /// Readings older than this many days are dropped.
    public var keptDays: Int
    /// A date a player passes the jaded line is given only within this many days.
    public var passDateWithinDays: Int

    public init(windowDays: Int, longestGapDays: Int, fewestOwnIntervals: Int, fewestSharedIntervals: Int,
                fewestSharedDays: Int, onCourseDays: Int, steadyPerWeek: Double, keptDays: Int, passDateWithinDays: Int) {
        self.windowDays = windowDays; self.longestGapDays = longestGapDays
        self.fewestOwnIntervals = fewestOwnIntervals; self.fewestSharedIntervals = fewestSharedIntervals
        self.fewestSharedDays = fewestSharedDays; self.onCourseDays = onCourseDays
        self.steadyPerWeek = steadyPerWeek; self.keptDays = keptDays; self.passDateWithinDays = passDateWithinDays
    }
}
