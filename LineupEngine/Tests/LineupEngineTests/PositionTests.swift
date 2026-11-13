import Testing
@testable import LineupEngine

@Test func fourteenPositionsWithTableKeys() {
    #expect(Position.allCases.count == 14)
    #expect(Position(rawValue: "AM (L)")?.tableKey == "AM(L)")
    #expect(Position(rawValue: "ST (C)")?.tableKey == "ST")
    #expect(Position.fromFMRTEPath("Positions.DefenderCentral") == .init(rawValue: "D (C)"))
    #expect(Position.fromFMRTEPath("Positions.PositionsDesc") == nil)
    #expect(Position.allCases.filter(\.isDefensive).count == 7)
}

@Test func twentyFourSlotsMapToPositions() {
    #expect(SlotID.allCases.count == 24)
    #expect(SlotID.allCases.first == .GK)
    #expect(SlotID.D_CL.position.rawValue == "D (C)")
    #expect(SlotID.DM_L.position.rawValue == "DM")
    #expect(SlotID.M_R.position.rawValue == "M (R)")
    #expect(SlotID.ST_L.position.rawValue == "ST (C)")
}

@Test func slotOrderIsTheTieBreakOrder() {
    #expect(SlotID.allCases.map(\.rawValue).joined(separator: ",") ==
        "GK,D_L,D_CL,D_C,D_CR,D_R,WB_L,DM_L,DM_C,DM_R,WB_R,M_L,M_CL,M_C,M_CR,M_R,AM_L,AM_CL,AM_C,AM_CR,AM_R,ST_L,ST_C,ST_R")
}

@Test func everyFMRTEPositionPathMapsToADistinctPosition() {
    let paths = ["Goalkeeper", "DefenderLeft", "DefenderCentral", "DefenderRight", "WingBackLeft", "WingBackRight",
                 "DefensiveMidfielder", "MidfielderLeft", "MidfielderCentral", "MidfielderRight",
                 "AttackingMidLeft", "AttackingMidCentral", "AttackingMidRight", "Striker"].map { "Positions.\($0)" }
    #expect(Set(paths.compactMap(Position.fromFMRTEPath)).count == 14)
    #expect(Phase(rawValue: "oop") == .outOfPossession)
}
