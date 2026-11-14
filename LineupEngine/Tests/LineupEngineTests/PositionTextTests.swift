import Testing
@testable import LineupEngine

@Suite struct PositionTextTests {
    @Test func everyPositionHasItsOwnWords() {
        let names = Position.allCases.map { PositionText.plain($0) }
        #expect(Set(names).count == Position.allCases.count)
        #expect(names.allSatisfy { !$0.isEmpty && !$0.contains("(") })
    }

    @Test(arguments: [
        (Position.goalkeeper, "goalkeeper"), (.defenderLeft, "left back"), (.defenderCentral, "centre-back"),
        (.defenderRight, "right back"), (.wingBackLeft, "left wing-back"), (.wingBackRight, "right wing-back"),
        (.defensiveMidfielder, "defensive midfield"), (.midfielderLeft, "left midfield"),
        (.midfielderCentral, "central midfield"), (.midfielderRight, "right midfield"),
        (.attackingMidLeft, "left attacking midfield"), (.attackingMidCentral, "central attacking midfield"),
        (.attackingMidRight, "right attacking midfield"), (.striker, "striker"),
    ])
    func positionWords(_ position: Position, _ words: String) {
        #expect(PositionText.plain(position) == words)
    }

    @Test func noTwoSlotsShareAName() {
        let names = SlotID.allCases.map { PositionText.plain($0) }
        #expect(Set(names).count == SlotID.allCases.count)
    }

    @Test(arguments: [
        (SlotID.GK, "goalkeeper"), (.D_L, "left back"), (.D_CL, "left centre-back"), (.D_C, "centre-back"),
        (.D_CR, "right centre-back"), (.D_R, "right back"), (.WB_L, "left wing-back"), (.DM_L, "left defensive midfield"),
        (.DM_C, "defensive midfield"), (.DM_R, "right defensive midfield"), (.WB_R, "right wing-back"),
        (.M_L, "left midfield"), (.M_CL, "left-centre midfield"), (.M_C, "central midfield"),
        (.M_CR, "right-centre midfield"), (.M_R, "right midfield"), (.AM_L, "left attacking midfield"),
        (.AM_CL, "left-centre attacking midfield"), (.AM_C, "central attacking midfield"),
        (.AM_CR, "right-centre attacking midfield"), (.AM_R, "right attacking midfield"), (.ST_L, "left striker"),
        (.ST_C, "striker"), (.ST_R, "right striker"),
    ])
    func slotWords(_ slot: SlotID, _ words: String) {
        #expect(PositionText.plain(slot) == words)
    }
}
