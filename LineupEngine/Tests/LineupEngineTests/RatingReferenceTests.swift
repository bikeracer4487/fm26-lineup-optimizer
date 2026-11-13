import Foundation
import Testing
@testable import LineupEngine

/// The cases `tools/export_rating_reference.py` wrote from `rating_calculator.py`.
struct RatingReference: Decodable {
    struct Case: Decodable {
        let player: String
        let slot: String
        let currentAbility: Int
        let attributes: [String: Int]
        let familiarity: [String: Int]
        let ipPosition: String
        let ipRole: String
        let oopPosition: String
        let oopRole: String
        let ipRating: Double
        let oopRating: Double
        let combinedRating: Double

        struct Invalid: Error, CustomStringConvertible { let description: String }

        var builtPlayer: Player {
            get throws {
                var attrs: [Attribute: Int] = [:]
                for (name, value) in attributes {
                    guard let attribute = Attribute(catalogName: name) else { throw Invalid(description: "attribute \(name)") }
                    attrs[attribute] = value
                }
                var fam: [Position: Int] = [:]
                for (name, value) in familiarity {
                    guard let position = Position(rawValue: name) else { throw Invalid(description: "position \(name)") }
                    fam[position] = value
                }
                return Player.fixture(name: player, all: 10, attributes: attrs, familiarity: fam, currentAbility: currentAbility)
            }
        }

        func assignment(_ catalog: RoleCatalog) throws -> SlotAssignment {
            guard let slotID = SlotID(rawValue: slot), let ip = Position(rawValue: ipPosition),
                  let oop = Position(rawValue: oopPosition) else { throw Invalid(description: "slot or position in \(player)") }
            return SlotAssignment(
                slot: slotID, ipPosition: ip, ipRole: try catalog.role(named: ipRole, phase: .inPossession, at: ip),
                oopSlot: slotID, oopPosition: oop, oopRole: try catalog.role(named: oopRole, phase: .outOfPossession, at: oop))
        }
    }

    let cases: [Case]

    static func load() throws -> RatingReference {
        try JSONDecoder().decode(RatingReference.self, from: Fixtures.data("reference/rating_reference_fm26.json"))
    }
}

@Suite struct RatingReferenceTests {
    @Test func matchesThePythonOnTheFM26Data() throws {
        let ref = try RatingReference.load()
        let catalog = try RoleCatalog(fm26JSON: Fixtures.data("reference/fm26_roles.json"))
        let engine = RatingEngine(tables: try RatingTables.bundled(), parameters: .fm27, configuration: .fm26Reference)
        #expect(ref.cases.count > 400)
        var worst = (ip: 0.0, oop: 0.0, combined: 0.0)
        for c in ref.cases {
            let r = try engine.rating(for: try c.builtPlayer, in: try c.assignment(catalog))
            worst.ip = max(worst.ip, abs(r.inPossession.base - c.ipRating))
            worst.oop = max(worst.oop, abs(r.outOfPossession.base - c.oopRating))
            worst.combined = max(worst.combined, abs(r.value - c.combinedRating))
            #expect(abs(r.inPossession.base - c.ipRating) <= 0.1001, "\(c.player) \(c.slot) IP")
            #expect(abs(r.outOfPossession.base - c.oopRating) <= 0.1001, "\(c.player) \(c.slot) OOP")
            #expect(abs(r.value - c.combinedRating) <= 0.2001, "\(c.player) \(c.slot)")
        }
    }
}
