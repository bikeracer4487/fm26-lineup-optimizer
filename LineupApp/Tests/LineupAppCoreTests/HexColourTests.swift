import Testing
@testable import LineupAppCore

@Suite struct HexColourTests {
    @Test func channelsComeFromTheHexValue() {
        let hoopBlue = HexColour(0x1F4E9A)
        #expect(hoopBlue.red == 0x1F)
        #expect(hoopBlue.green == 0x4E)
        #expect(hoopBlue.blue == 0x9A)
    }

    @Test func fractionsRunFromZeroToOne() {
        let colour = HexColour(0xFF0080)
        #expect(colour.redFraction == 1)
        #expect(colour.greenFraction == 0)
        #expect(colour.blueFraction == 128.0 / 255.0)
    }

    @Test func darkeningScalesEachChannelAndRounds() {
        // Turf, light: 0x2E6B4E is (46, 107, 78); 6% darker is (43.24, 100.58, 73.32).
        #expect(HexColour(0x2E6B4E).darkened(by: 0.06) == HexColour(0x2B6549))
    }

    @Test func darkeningByNothingLeavesTheColourAlone() {
        #expect(HexColour(0x24523D).darkened(by: 0) == HexColour(0x24523D))
    }
}
