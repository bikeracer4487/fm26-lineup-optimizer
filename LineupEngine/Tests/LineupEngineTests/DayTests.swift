import Testing
import Foundation
@testable import LineupEngine

@Suite struct DayTests {
    @Test func isoRoundTrips() throws {
        let day = try #require(Day(iso: "2026-11-14"))
        #expect(day.iso == "2026-11-14")
        #expect(day == Day(year: 2026, month: 11, day: 14))
    }

    @Test func rejectsDatesThatDoNotExist() {
        #expect(Day(year: 2026, month: 2, day: 30) == nil)
        #expect(Day(year: 2026, month: 13, day: 1) == nil)
        #expect(Day(year: 2027, month: 2, day: 29) == nil)
        #expect(Day(year: 2028, month: 2, day: 29) != nil)
        #expect(Day(iso: "2026-02-30") == nil)
        #expect(Day(iso: "2026-13-01") == nil)
        #expect(Day(iso: "14/11/2026") == nil)
        #expect(Day(iso: "2026-1-4") == nil)
        #expect(Day(iso: "") == nil)
    }

    @Test func countsDaysAcrossMonthsYearsAndLeapDays() throws {
        let a = try #require(Day(iso: "2026-12-30"))
        let b = try #require(Day(iso: "2027-01-02"))
        #expect(a.days(to: b) == 3)
        #expect(b.days(to: a) == -3)
        let c = try #require(Day(iso: "2028-02-28"))
        let d = try #require(Day(iso: "2028-03-01"))
        #expect(c.days(to: d) == 2)
        #expect(d.days(to: c) == -2)
    }

    @Test func addingDaysIsTheInverseOfCounting() throws {
        let start = try #require(Day(iso: "2026-11-14"))
        for n in [-800, -366, -1, 0, 1, 17, 59, 365, 1500] {
            let moved = start.adding(days: n)
            #expect(start.days(to: moved) == n)
            #expect(moved.adding(days: -n) == start)
        }
        #expect(start.adding(days: 47).iso == "2026-12-31")
    }

    @Test func ordersByDate() throws {
        let a = try #require(Day(iso: "2026-11-14"))
        let b = try #require(Day(iso: "2026-12-01"))
        let c = try #require(Day(iso: "2027-01-01"))
        #expect(a < b && b < c)
        #expect([c, a, b].sorted() == [a, b, c])
    }

    @Test func encodesAsTheISOString() throws {
        let day = try #require(Day(iso: "2026-11-14"))
        let data = try JSONEncoder().encode([day])
        #expect(String(decoding: data, as: UTF8.self) == #"["2026-11-14"]"#)
        #expect(try JSONDecoder().decode([Day].self, from: data) == [day])
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode([Day].self, from: Data(#"["nope"]"#.utf8))
        }
    }
}
