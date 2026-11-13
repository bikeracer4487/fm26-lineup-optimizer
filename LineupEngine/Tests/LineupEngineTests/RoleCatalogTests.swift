import Foundation
import Testing
@testable import LineupEngine

@Suite struct RoleCatalogTests {
    @Test func fm27CatalogHas79RolesAndFindsThemByPosition() throws {
        let c = try RoleCatalog.fm27()
        let cb = try c.role(named: "Ball-Playing Centre-Back", phase: .inPossession, at: #require(Position(rawValue: "D (C)")))
        #expect(cb.key.map(\.rawValue).contains("Passing"))
        #expect(c.roles(phase: .inPossession, at: try #require(Position(rawValue: "GK"))).count == 3)
        #expect(c.allRoles.filter { $0.phase == .inPossession }.count == 40)
        #expect(c.allRoles.filter { $0.phase == .outOfPossession }.count == 39)
    }

    @Test func rolesAtAPositionAreSortedByName() throws {
        let c = try RoleCatalog.fm27()
        let names = c.roles(phase: .outOfPossession, at: .defenderCentral).map(\.name)
        #expect(names == names.sorted())
        #expect(names.count == 6)
    }

    @Test func unknownRoleIsAnErrorNotADefault() throws {
        let c = try RoleCatalog.fm27()
        let d = try #require(Position(rawValue: "D (L)"))
        #expect(throws: CatalogError.unknownRole(name: "Wing Back", phase: .inPossession, position: d)) {
            try c.role(named: "Wing Back", phase: .inPossession, at: d)
        }
        // The role exists, but only out of possession at another position.
        #expect(throws: CatalogError.self) { try c.role(named: "Sweeper Keeper", phase: .inPossession, at: .goalkeeper) }
    }

    @Test func fm26CatalogLoadsAndKeyWinsOverImportant() throws {
        let c = try RoleCatalog(fm26JSON: Fixtures.data("reference/fm26_roles.json"))
        let wb = try c.role(named: "Wing Back", phase: .inPossession, at: #require(Position(rawValue: "D (L)")))
        #expect(Set(wb.key).isDisjoint(with: wb.preferable))
        #expect(wb.preferable.count == Set(wb.preferable).count)
        #expect(wb.key.count == Set(wb.key).count)
        let hfb = try c.role(named: "Holding Full-Back", phase: .outOfPossession, at: .defenderRight)
        #expect(Set(hfb.key).isDisjoint(with: hfb.preferable))
        #expect(hfb.preferable.count == Set(hfb.preferable).count)
    }

    @Test func fm26GroupsMapToEveryPositionTheyCover() throws {
        let c = try RoleCatalog(fm26JSON: Fixtures.data("reference/fm26_roles.json"))
        let left = try c.role(named: "Winger", phase: .inPossession, at: .attackingMidLeft)
        let right = try c.role(named: "Winger", phase: .inPossession, at: .attackingMidRight)
        #expect(left.key == right.key)
        #expect(left.positions == [.attackingMidLeft, .attackingMidRight])
        #expect(!c.roles(phase: .inPossession, at: .striker).isEmpty)
    }

    @Test func duplicatesAndKeyOverlapAreRemovedWhenLoadingFM27() throws {
        let json = #"""
        {"roles":[{"name":"Test Role","phase":"ip","positions":["GK"],
          "key":["Pace","Pace","Agility"],"preferable":["Agility","Balance","Balance"]}]}
        """#
        let c = try RoleCatalog(fm27JSON: Data(json.utf8))
        let r = try c.role(named: "Test Role", phase: .inPossession, at: .goalkeeper)
        #expect(r.key == [.pace, .agility])
        #expect(r.preferable == [.balance])
    }

    @Test func aRoleFileWithAMisspeltAttributeFailsToLoad() {
        let json = #"""
        {"roles":[{"name":"Test Role","phase":"ip","positions":["GK"],"key":["Workrate"],"preferable":[]}]}
        """#
        #expect(throws: CatalogError.unknownAttribute(role: "Test Role", name: "Workrate")) {
            try RoleCatalog(fm27JSON: Data(json.utf8))
        }
    }

    @Test func malformedFilesAreReported() {
        #expect(throws: CatalogError.self) { try RoleCatalog(fm27JSON: Data("{}".utf8)) }
        let badPhase = #"{"roles":[{"name":"R","phase":"xx","positions":["GK"],"key":[],"preferable":[]}]}"#
        #expect(throws: CatalogError.self) { try RoleCatalog(fm27JSON: Data(badPhase.utf8)) }
        let badPosition = #"{"roles":[{"name":"R","phase":"ip","positions":["XX"],"key":[],"preferable":[]}]}"#
        #expect(throws: CatalogError.self) { try RoleCatalog(fm27JSON: Data(badPosition.utf8)) }
    }
}
