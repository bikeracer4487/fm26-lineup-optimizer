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

    /// What an amount's field shows (27 November 2026: the amount once, with its commas, and nothing beside it).
    @Test func anAmountIsShownWithACommaBetweenEachGroupOfThreeDigits() {
        #expect(TypedNumber.grouped("") == "" && TypedNumber.grouped("abc") == "")
        #expect(TypedNumber.grouped("0") == "0")
        #expect(TypedNumber.grouped("999") == "999")
        #expect(TypedNumber.grouped("1000") == "1,000")
        #expect(TypedNumber.grouped("241757") == "241,757")
        #expect(TypedNumber.grouped("2901084") == "2,901,084")
        #expect(TypedNumber.grouped("123456789012") == "123,456,789,012")
        #expect(TypedNumber.grouped("1234567890123") == "123,456,789,012")              // twelve digits at most
        #expect(TypedNumber.grouped("40K") == "40")                                     // 40 typed for 40K is seen at once
        #expect(TypedNumber.grouped(40_000) == "40,000" && TypedNumber.grouped(0) == "0")
    }

    @Test func whatAFieldShowsIsReadBackAsTheSameNumber() {
        for text in ["0", "7", "1000", "2901084", "123456789012"] {
            #expect(TypedNumber.digits(TypedNumber.grouped(text)) == text)
            // A digit typed at the end of what is shown is read as that digit added.
            #expect(TypedNumber.digits(TypedNumber.grouped(text) + "5") == TypedNumber.digits(text + "5"))
        }
        // The last digit deleted from what is shown.
        #expect(TypedNumber.grouped(String("1,000".dropLast())) == "100")
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
