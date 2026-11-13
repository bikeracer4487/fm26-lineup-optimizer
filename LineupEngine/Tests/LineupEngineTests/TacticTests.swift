import Foundation
import Testing
@testable import LineupEngine

struct TacticTests {
    func sample() throws -> Tactic {
        try JSONDecoder().decode(Tactic.self, from: Fixtures.data("tactics/sample-4231.json"))
    }

    func problems(_ t: Tactic) throws -> [TacticProblem] {
        t.problems(catalog: try RoleCatalog.fm27())
    }

    @Test func sampleTacticIsValidAndYieldsElevenAssignments() throws {
        let t = try sample()
        let catalog = try RoleCatalog.fm27()
        #expect(t.problems(catalog: catalog).isEmpty)
        let a = try t.assignments(catalog: catalog)
        #expect(a.count == 11)
        #expect(a.first?.slot == .GK)
        #expect(a.map(\.slot) == SlotID.allCases.filter { t.inPossession[$0] != nil })
        let aml = try #require(a.first { $0.slot == .AM_L })
        #expect(aml.oopSlot == .M_L)
        #expect(aml.ipPosition == .attackingMidLeft)
        #expect(aml.oopPosition == .midfielderLeft)
        #expect(aml.ipRole.name == "Inside Forward")
        #expect(aml.oopRole.name == "Wide Midfielder")
    }

    @Test func tenSlotsInPossessionIsReported() throws {
        var t = try sample()
        t.inPossession[.ST_C] = nil
        #expect(try problems(t) == [.wrongSlotCount(.inPossession, 10)])
    }

    @Test func missingGoalkeeperIsReported() throws {
        var t = try sample()
        t.inPossession[.GK] = nil
        t.mapping[.GK] = nil
        t.inPossession[.D_C] = "Ball-Playing Centre-Back"
        t.mapping[.D_C] = .GK
        #expect(try problems(t) == [.missingGoalkeeper(.inPossession)])
    }

    @Test func unmappedSlotIsReported() throws {
        var t = try sample()
        t.mapping[.AM_C] = nil
        #expect(try problems(t) == [.unmapped(.AM_C)])
    }

    @Test func mappingToAnInactiveSlotIsReported() throws {
        var t = try sample()
        t.mapping[.AM_C] = .ST_L
        #expect(try problems(t) == [.mappingTargetInactive(from: .AM_C, to: .ST_L)])
    }

    @Test func twoSlotsMappedToOneTargetIsReported() throws {
        var t = try sample()
        t.mapping[.AM_C] = .DM_L
        #expect(try problems(t) == [.duplicateMappingTarget(.DM_L)])
    }

    @Test func mappingEntriesForInactiveSlotsAreIgnored() throws {
        var t = try sample()
        t.mapping[.ST_L] = .ST_C
        #expect(try problems(t).isEmpty)
    }

    @Test func anFM26RoleNameIsAnUnknownRole() throws {
        var t = try sample()
        t.inPossession[.D_L] = "Wing Back"
        #expect(try problems(t) == [.unknownRole(.inPossession, .D_L, "Wing Back")])
    }

    @Test func assignmentsThrowsWhenInvalid() throws {
        var t = try sample()
        t.mapping[.AM_C] = nil
        #expect(throws: TacticError.self) { try t.assignments(catalog: RoleCatalog.fm27()) }
    }

    @Test func tacticRoundTripsThroughJSON() throws {
        let t = try sample()
        let data = try JSONEncoder().encode(t)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("\"inPossession\":{"))
        #expect(text.contains("\"AM_L\":"))
        #expect(try JSONDecoder().decode(Tactic.self, from: data) == t)
    }
}
