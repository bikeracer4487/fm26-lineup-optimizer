import Foundation
import LineupEngine

/// Days as the screens write them, in English whatever the Mac's language, region or time zone.
public enum DayText {
    private static let months = ["January", "February", "March", "April", "May", "June", "July", "August",
                                 "September", "October", "November", "December"]
    /// Monday first, so `weekday` 1 is index 0.
    private static let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    /// 1970-01-01, the day the engine counts from, was a Thursday.
    private static let knownThursday = Day(year: 1970, month: 1, day: 1)!

    /// "Sat 14 Nov".
    public static func short(_ day: Day) -> String {
        "\(weekdays[weekday(day) - 1].prefix(3)) \(dayAndMonth(day))"
    }

    /// "Saturday 14 November 2026".
    public static func long(_ day: Day) -> String {
        let (year, month, date) = parts(day)
        return "\(weekdays[weekday(day) - 1]) \(date) \(months[month - 1]) \(year)"
    }

    /// "14 Nov".
    public static func dayAndMonth(_ day: Day) -> String {
        let (_, month, date) = parts(day)
        return "\(date) \(months[month - 1].prefix(3))"
    }

    /// 1 for Monday to 7 for Sunday, counted in whole weeks from a known Thursday.
    public static func weekday(_ day: Day) -> Int {
        let sinceThursday = ((knownThursday.days(to: day) % 7) + 7) % 7
        return (sinceThursday + 3) % 7 + 1
    }

    private static func parts(_ day: Day) -> (year: Int, month: Int, day: Int) {
        // `Day.iso` is always YYYY-MM-DD.
        let numbers = day.iso.split(separator: "-").map { Int($0)! }
        return (numbers[0], numbers[1], numbers[2])
    }
}

/// Converts between the engine's `Day` and Foundation's `Date` for the date pickers. Both ways use a Gregorian
/// calendar fixed to UTC, and a day is noon there, so the day never shifts with the Mac's time zone.
public enum DayDate {
    /// The calendar the date pickers are shown in, so they show the day `date` stands for.
    public static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    /// Noon in UTC on the day.
    public static func date(_ day: Day) -> Date {
        let numbers = day.iso.split(separator: "-").map { Int($0)! }
        let parts = DateComponents(year: numbers[0], month: numbers[1], day: numbers[2], hour: 12)
        guard let date = calendar.date(from: parts) else {
            preconditionFailure("A Gregorian calendar has every day the engine can name.")
        }
        return date
    }

    /// The day in UTC that `date` falls on.
    public static func day(_ date: Date) -> Day {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let date = parts.day,
              let day = Day(year: year, month: month, day: date) else {
            preconditionFailure("A Gregorian calendar gives only days that exist.")
        }
        return day
    }
}
