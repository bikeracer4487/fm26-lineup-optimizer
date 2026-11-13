import Foundation
import Testing
@testable import LineupEngine

@Suite struct ClipboardTextTests {
    @Test func splitsTheRealPasteIntoSixRowsOf98Fields() throws {
        let rows = try ClipboardText.rows(Fixtures.text("captures/u21.tsv"))
        #expect(rows.count == 6)
        #expect(rows.allSatisfy { $0.count == 98 })
        #expect(rows[0][1] == "Brayden Daniel")
        #expect(rows[0][0] == "")
    }

    @Test(arguments: ["", "   \n", "https://example.com", "Just a sentence someone copied."])
    func clipboardThatIsNotAPasteIsRejected(_ text: String) {
        #expect(throws: ImportError.self) { try ClipboardText.rows(text) }
    }

    private func line(_ tag: String) -> String { (0..<98).map { "\"\(tag)\($0)\"" }.joined(separator: "\t") }

    @Test(arguments: ["\r\n", "\n", "\r"])
    func eachLineEndingSplitsRows(_ ending: String) throws {
        let rows = try ClipboardText.rows(line("a") + ending + line("b") + ending)
        #expect(rows.count == 2)
        #expect(rows.allSatisfy { $0.count == 98 })
        #expect(rows[0][97] == "a97" && rows[1][0] == "b0")
    }

    @Test func mixedLineEndingsSplitRows() throws {
        let rows = try ClipboardText.rows(line("a") + "\r" + line("b") + "\n" + line("c") + "\r\n" + line("d"))
        #expect(rows.map { $0[0] } == ["a0", "b0", "c0", "d0"])
    }

    @Test func aRowOfOnlyTabsAndSpacesIsDroppedAsBlank() throws {
        let blank = String(repeating: "\t", count: 97) + "  "
        let rows = try ClipboardText.rows(line("a") + "\r\n" + blank + "\r\n" + " \t \r\n" + line("b") + "\r\n")
        #expect(rows.count == 2)
        #expect(rows.map { $0[0] } == ["a0", "b0"])
    }

    @Test func raggedRowsNameTheRow() {
        let line = (0..<98).map { "\"\($0)\"" }.joined(separator: "\t")
        #expect(throws: ImportError.raggedRows(expected: 98, row: 2, found: 97)) {
            try ClipboardText.rows(line + "\r\n" + String(line.dropLast(5)))
        }
    }
}
