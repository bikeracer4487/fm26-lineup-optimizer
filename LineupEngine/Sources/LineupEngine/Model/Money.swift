import Foundation

/// The period FMRTE shows wages by, from the entry `Wages` in its settings file.
public enum WagePeriod: String, Codable, CaseIterable, Sendable {
    case weekly, monthly, yearly

    /// A year is 52 weeks and 12 months, as the release cost reckons it.
    private static let weeksPerYear = 52.0

    /// How many of this period make a year.
    private var perYear: Double {
        switch self {
        case .weekly: 52
        case .monthly: 12
        case .yearly: 1
        }
    }

    /// An amount for one of this period, per week: a monthly amount × 12 ÷ 52, a yearly one ÷ 52.
    public func perWeek(_ amount: Double) -> Double { amount * perYear / Self.weeksPerYear }

    /// A weekly amount for one of this period: per week × 52 ÷ 12 for a month, × 52 for a year.
    public func amount(perWeek: Double) -> Double { perWeek * Self.weeksPerYear / perYear }

    /// The period after an amount: " a week", " a month", " a year".
    var suffix: String {
        switch self {
        case .weekly: " a week"
        case .monthly: " a month"
        case .yearly: " a year"
        }
    }
}

/// How money is written: a currency symbol and the period wages are given by. An import's style is how FMRTE pasted
/// its wages (FMRTE's symbol and period); the style the tool shows wages in is `byYear` of it. The engine keeps every
/// wage per week; this says how to read one and how to show it again.
public struct MoneyStyle: Equatable, Codable, Sendable {
    public var symbol: String
    public var period: WagePeriod

    public init(symbol: String, period: WagePeriod) {
        self.symbol = symbol
        self.period = period
    }

    /// How a squad imported before the tool read FMRTE's period and currency was read.
    public static let weeklyPounds = MoneyStyle(symbol: "£", period: .weekly)

    /// The same currency with wages by the year: how the tool shows every wage, as the game shows them ("p/a"),
    /// whatever period FMRTE pasted them in (the owner's rule of 27 November 2026).
    public var byYear: MoneyStyle { MoneyStyle(symbol: symbol, period: .yearly) }
}
