/// A calendar day with no time or time zone. Arithmetic is on whole days since 1970-01-01 in the
/// proleptic Gregorian calendar, so it never depends on the machine's time zone or locale.
public struct Day: Hashable, Comparable, Codable, Sendable {
    /// Days since 1970-01-01 (negative before it).
    private let epochDays: Int

    private init(epochDays: Int) { self.epochDays = epochDays }

    /// Nil for a date that does not exist.
    public init?(year: Int, month: Int, day: Int) {
        guard (1...12).contains(month), day >= 1, day <= Day.daysIn(month: month, year: year) else {
            return nil
        }
        self.epochDays = Day.daysFromCivil(year: year, month: month, day: day)
    }

    /// Accepts exactly `YYYY-MM-DD`; nil otherwise.
    public init?(iso: String) {
        let bytes = Array(iso.utf8)
        guard bytes.count == 10, bytes[4] == UInt8(ascii: "-"), bytes[7] == UInt8(ascii: "-") else {
            return nil
        }
        func number(_ range: Range<Int>) -> Int? {
            var value = 0
            for i in range {
                let b = bytes[i]
                guard b >= UInt8(ascii: "0"), b <= UInt8(ascii: "9") else { return nil }
                value = value * 10 + Int(b - UInt8(ascii: "0"))
            }
            return value
        }
        guard let y = number(0..<4), let m = number(5..<7), let d = number(8..<10) else { return nil }
        self.init(year: y, month: m, day: d)
    }

    public var iso: String {
        let (y, m, d) = Day.civil(fromDays: epochDays)
        func pad(_ n: Int, _ width: Int) -> String {
            let s = String(n)
            return String(repeating: "0", count: max(0, width - s.count)) + s
        }
        return "\(pad(y, 4))-\(pad(m, 2))-\(pad(d, 2))"
    }

    /// Whole days from this day to `later`; negative when `later` is earlier.
    public func days(to later: Day) -> Int { later.epochDays - epochDays }

    public func adding(days: Int) -> Day { Day(epochDays: epochDays + days) }

    public static func < (lhs: Day, rhs: Day) -> Bool { lhs.epochDays < rhs.epochDays }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let day = Day(iso: text) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "\"\(text)\" is not a date in the form YYYY-MM-DD")
        }
        self = day
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso)
    }

    private static func isLeap(_ year: Int) -> Bool {
        (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
    }

    private static func daysIn(month: Int, year: Int) -> Int {
        switch month {
        case 2: isLeap(year) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    /// Floor division, so dates before the epoch work.
    private static func floorDiv(_ a: Int, _ b: Int) -> Int {
        let q = a / b
        return (a % b != 0 && (a < 0) != (b < 0)) ? q - 1 : q
    }

    // Howard Hinnant's days-from-civil algorithm.
    private static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = floorDiv(y, 400)
        let yoe = y - era * 400
        let mp = (month + 9) % 12
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    private static func civil(fromDays days: Int) -> (year: Int, month: Int, day: Int) {
        let z = days + 719_468
        let era = floorDiv(z, 146_097)
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        let y = yoe + era * 400 + (m <= 2 ? 1 : 0)
        return (y, m, d)
    }
}
