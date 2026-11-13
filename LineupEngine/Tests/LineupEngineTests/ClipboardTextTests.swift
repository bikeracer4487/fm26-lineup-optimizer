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

    @Test func raggedRowsNameTheRow() {
        let line = (0..<98).map { "\"\($0)\"" }.joined(separator: "\t")
        #expect(throws: ImportError.raggedRows(expected: 98, row: 2, found: 97)) {
            try ClipboardText.rows(line + "\r\n" + String(line.dropLast(5)))
        }
    }
}
