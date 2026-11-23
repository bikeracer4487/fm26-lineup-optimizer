import Testing
@testable import LineupAppCore

/// How a typed amount is read, by every field that takes one: its ASCII digits, at most twelve, blank with none.
@Suite struct TypedNumberTests {
    @Test func theDigitsOfTheTextAreTheNumberAndNoLetterIsRead() {
        #expect(TypedNumber.digits("£40,000") == "40000")
        #expect(TypedNumber.value("£40,000") == 40_000)
        #expect(TypedNumber.value("40K") == 40)                                         // no K or M is read
        #expect(TypedNumber.value("1.5M") == 15)
        #expect(TypedNumber.value("") == nil && TypedNumber.value("abc") == nil)
        #expect(TypedNumber.digits("abc") == "")
        #expect(TypedNumber.value("٤٠") == nil)                                          // only ASCII digits
    }

    @Test func digitsBeyondTheTwelfthAreDropped() {
        #expect(TypedNumber.maximumDigits == 12)
        #expect(TypedNumber.digits("1234567890123") == "123456789012")
        #expect(TypedNumber.value("£1,234,567,890,123,456,789") == 123_456_789_012)
    }

    @Test func theLeagueFormatsFieldsReadTheSameWay() {
        var draft = LeagueFormatDraft()
        draft.set(.promoted, text: "1234567890123")
        #expect(draft.promoted == 123_456_789_012)
        draft.set(.playOffs, text: "6 teams")
        #expect(draft.playOffs == 6)
        draft.set(.relegated, text: "none")
        #expect(draft.relegated == nil)
    }
}
