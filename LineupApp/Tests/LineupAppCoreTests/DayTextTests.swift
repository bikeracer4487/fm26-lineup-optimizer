import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

@Suite struct DayTextTests {
    private func day(_ iso: String) -> Day { Day(iso: iso)! }

    @Test func aDayIsWrittenShortWithItsWeekday() {
        #expect(DayText.short(day("2026-11-14")) == "Sat 14 Nov")
        #expect(DayText.short(day("2026-11-13")) == "Fri 13 Nov")
        #expect(DayText.short(day("2027-01-05")) == "Tue 5 Jan")
        #expect(DayText.short(day("2026-09-07")) == "Mon 7 Sep")
    }

    @Test func aDayIsWrittenInFull() {
        #expect(DayText.long(day("2026-11-14")) == "Saturday 14 November 2026")
        #expect(DayText.long(day("2026-11-13")) == "Friday 13 November 2026")
        #expect(DayText.long(day("2027-12-31")) == "Friday 31 December 2027")
    }

    @Test func aDayIsWrittenAsDayAndShortMonth() {
        #expect(DayText.dayAndMonth(day("2026-11-13")) == "13 Nov")
        #expect(DayText.dayAndMonth(day("2027-01-05")) == "5 Jan")
        #expect(DayText.dayAndMonth(day("2027-12-31")) == "31 Dec")
    }

    @Test func theWeekdayIsWorkedOutFromTheDay() {
        #expect(DayText.weekday(day("2026-11-13")) == 5)
        #expect(DayText.weekday(day("2026-11-14")) == 6)
        #expect(DayText.weekday(day("2026-11-15")) == 7)
        #expect(DayText.weekday(day("2026-11-16")) == 1)
        #expect(DayText.weekday(day("2028-02-29")) == 2)
        #expect(DayText.short(day("2028-02-29")) == "Tue 29 Feb")
        // 1970-01-01, the day the engine counts from, and a day before it.
        #expect(DayText.weekday(day("1970-01-01")) == 4)
        #expect(DayText.weekday(day("1969-12-31")) == 3)
    }

    @Test func everyWeekdayFollowsTheOneBefore() {
        let start = day("2026-01-01")
        for offset in 0..<400 {
            let today = DayText.weekday(start.adding(days: offset))
            let tomorrow = DayText.weekday(start.adding(days: offset + 1))
            #expect(tomorrow == today % 7 + 1)
        }
    }
}

@Suite struct DayDateTests {
    private func day(_ iso: String) -> Day { Day(iso: iso)! }

    @Test func aDayIsNoonInUTC() {
        let d = day("2026-11-13")
        let seconds = Day(year: 1970, month: 1, day: 1)!.days(to: d) * 86_400 + 12 * 3_600
        #expect(DayDate.date(d) == Date(timeIntervalSince1970: TimeInterval(seconds)))
    }

    @Test func aDayComesBackFromItsDate() {
        for iso in ["2026-11-13", "2028-02-29", "2026-12-31", "2027-01-01", "1969-12-31"] {
            #expect(DayDate.day(DayDate.date(day(iso))) == day(iso))
        }
    }

    @Test func anyTimeOnADayInUTCIsThatDay() {
        let midnight = DayDate.date(day("2026-11-14")).addingTimeInterval(-12 * 3_600)
        #expect(DayDate.day(midnight) == day("2026-11-14"))
        #expect(DayDate.day(midnight.addingTimeInterval(86_399)) == day("2026-11-14"))
        #expect(DayDate.day(midnight.addingTimeInterval(86_400)) == day("2026-11-15"))
        #expect(DayDate.day(midnight.addingTimeInterval(-1)) == day("2026-11-13"))
    }

    @Test func theCalendarIsGregorianInUTC() {
        #expect(DayDate.calendar.identifier == .gregorian)
        #expect(DayDate.calendar.timeZone.secondsFromGMT() == 0)
    }
}
