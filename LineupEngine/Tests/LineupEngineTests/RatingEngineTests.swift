import Foundation
import Testing
@testable import LineupEngine

@Suite struct RatingEngineTests {
    let engine = RatingEngine(tables: try! RatingTables.bundled(), parameters: .fm27, configuration: .fm27)
    let reference = RatingEngine(tables: try! RatingTables.bundled(), parameters: .fm27, configuration: .fm26Reference)
    let dc = Position.defenderCentral, aml = Position.attackingMidLeft, ml = Position.midfielderLeft

    func slot(_ id: SlotID) throws -> SlotAssignment {
        let tactic = try JSONDecoder().decode(Tactic.self, from: Fixtures.data("tactics/sample-4231.json"))
        let found = try tactic.assignments(catalog: RoleCatalog.fm27()).first { $0.slot == id }
        return try #require(found)
    }

    @Test func allTensGivesAPositionScoreOfFortySevenPointFour() throws {
        // every attribute 10 gives n = 9/19; a natural centre-back in the sample tactic's D_CL slot
        let cb = Player.fixture(all: 10, familiarity: [dc: 20])
        let r = (try engine.rating(for: cb, in: try slot(.D_CL)))
        #expect(abs(r.inPossession.positionScore - 47.368) < 0.01)
        #expect(r.inPossession.familiarityFactor == 1.0 && r.ipWeight == 0.5)
    }

    @Test func higherKeyAttributeRaisesTheRating() throws {
        let base = Player.fixture(familiarity: [dc: 20])
        let passer = Player.fixture(attributes: [.passing: 15], familiarity: [dc: 20])
        let finisher = Player.fixture(attributes: [.finishing: 15], familiarity: [dc: 20])
        let s = try slot(.D_CL)
        let before = (try engine.rating(for: base, in: s))
        #expect((try engine.rating(for: passer, in: s)).value > before.value)
        #expect((try engine.rating(for: finisher, in: s)).value == before.value)
    }

    @Test func familiarityStepsApplyPerPhase() throws {
        // AM_L slot: in possession AM (L), out of possession M (L)
        let both = Player.fixture(familiarity: [aml: 20, ml: 20])
        let ipOnly = Player.fixture(familiarity: [aml: 20, ml: 9])
        let a = (try engine.rating(for: both, in: try slot(.AM_L))), b = (try engine.rating(for: ipOnly, in: try slot(.AM_L)))
        #expect(b.inPossession.value == a.inPossession.value)
        #expect(b.outOfPossession.familiarityFactor == 0.60)
        #expect(b.value < a.value)
        #expect(a.ipWeight == 0.7)
    }

    @Test(arguments: [(20, 1.0), (18, 1.0), (17, 0.95), (15, 0.95), (14, 0.90), (13, 0.90), (12, 0.80), (10, 0.80),
                      (9, 0.60), (8, 0.60), (7, 0.35), (5, 0.35), (4, 0.10), (1, 0.10)])
    func familiarityFactorAtEachStep(_ familiarity: Int, _ factor: Double) throws {
        let p = Player.fixture(familiarity: [dc: familiarity])
        let r = (try engine.rating(for: p, in: try slot(.D_CL)))
        #expect(r.inPossession.familiarity == familiarity)
        #expect(r.inPossession.familiarityFactor == factor)
        #expect(abs(r.inPossession.value - r.inPossession.base * factor) < 1e-9)
    }

    @Test func thresholdShortfallCostsTwoPercentPerPointDownToEightyPercent() throws {
        // Channel Forward thresholds: Acceleration 14, Pace 14, Off The Ball 13
        let st = Position.striker
        let s = try slot(.ST_C)
        let met = Player.fixture(attributes: [.acceleration: 14, .pace: 14, .offTheBall: 13], familiarity: [st: 20])
        let short = Player.fixture(attributes: [.acceleration: 12, .pace: 14, .offTheBall: 13], familiarity: [st: 20])
        let broken = Player.fixture(attributes: [.acceleration: 1, .pace: 1, .offTheBall: 1], familiarity: [st: 20])
        #expect((try engine.rating(for: met, in: s)).inPossession.thresholdFactor == 1.0)
        #expect(abs((try engine.rating(for: short, in: s)).inPossession.thresholdFactor - 0.96) < 1e-9)
        #expect(abs((try engine.rating(for: broken, in: s)).inPossession.thresholdFactor - 0.80) < 1e-9)
    }

    @Test func currentAbilityDoesNotChangeAnFM27Rating() throws {
        // same attributes, CA 60 vs CA 140
        let weak = Player.fixture(familiarity: [dc: 20], currentAbility: 60)
        let strong = Player.fixture(familiarity: [dc: 20], currentAbility: 140)
        let s = try slot(.D_CL)
        #expect((try engine.rating(for: weak, in: s)).value == (try engine.rating(for: strong, in: s)).value)
        #expect((try reference.rating(for: weak, in: s)).value < (try reference.rating(for: strong, in: s)).value)
    }

    @Test func aMissingAttributeThePositionReadsThrowsNamingPlayerAndAttribute() throws {
        var p = Player.fixture(name: "Gap Man", familiarity: [dc: 20])
        p.attributes[.tackling] = nil
        #expect(throws: RatingError.missingAttribute(player: "Gap Man", attribute: .tackling)) {
            try engine.rating(for: p, in: try slot(.D_CL))
        }
    }

    @Test func aMissingFamiliarityThrowsNamingPlayerAndPosition() throws {
        var p = Player.fixture(name: "Gap Man", familiarity: [dc: 20])
        p.familiarity[dc] = nil
        #expect(throws: RatingError.missingFamiliarity(player: "Gap Man", position: dc)) {
            try engine.rating(for: p, in: try slot(.D_CL))
        }
    }

    @Test func aMissingAttributeTheSlotDoesNotReadStillRates() throws {
        let full = Player.fixture(familiarity: [dc: 20])
        var p = full
        p.attributes[.finishing] = nil
        let s = try slot(.D_CL)
        #expect(try engine.rating(for: p, in: s).value == engine.rating(for: full, in: s).value)
    }

    // MARK: rules that need a hand-built role or custom tables

    private func probe(_ position: Position, key: [Attribute] = [.passing], preferable: [Attribute] = []) -> SlotAssignment {
        let ip = Role(name: "Probe", phase: .inPossession, positions: [position], key: key, preferable: preferable)
        let oop = Role(name: "Probe", phase: .outOfPossession, positions: [position], key: key, preferable: preferable)
        return SlotAssignment(slot: .AM_C, ipPosition: position, ipRole: ip, oopSlot: .AM_C, oopPosition: position, oopRole: oop)
    }

    @Test func fm27DoesNotRoundAndTheReferenceDoes() throws {
        let attrs: [Attribute: Int] = [.passing: 13, .pace: 7, .tackling: 16, .vision: 4, .strength: 11, .jumpingReach: 17]
        let p = Player.fixture(attributes: attrs, familiarity: [dc: 20], currentAbility: 100)
        let s = try slot(.D_CL)
        let exact = try engine.rating(for: p, in: s).inPossession
        let blended = 0.60 * exact.positionScore + 0.35 * exact.roleScore + 0.05 * exact.consensusBonus
        #expect(abs(exact.base - blended * exact.thresholdFactor) < 1e-12)
        #expect(exact.base != (exact.base * 10).rounded() / 10)
        let rounded = try reference.rating(for: p, in: s).inPossession
        #expect(rounded.base == (exact.base * 10).rounded(.toNearestOrEven) / 10)
        #expect(rounded.base != exact.base)
        let combined = try engine.rating(for: p, in: s).value
        #expect(combined != (combined * 10).rounded() / 10)
    }

    @Test func balanceAddsToAnOutfieldConsensusBonusButNotAGoalkeepers() throws {
        func bonus(_ position: Position, balance: Int, key: [Attribute] = [.passing]) throws -> PhaseRating {
            let p = Player.fixture(attributes: [.balance: balance], familiarity: [position: 20])
            return try engine.rating(for: p, in: probe(position, key: key)).inPossession
        }
        let low = try bonus(.attackingMidLeft, balance: 1), high = try bonus(.attackingMidLeft, balance: 20)
        #expect(low.consensusBonus == 0)
        #expect(abs(high.consensusBonus - 1.0) < 1e-9)
        #expect(high.base > low.base)
        // a goalkeeper phase ignores Balance for the bonus
        let gkLow = try bonus(.goalkeeper, balance: 1), gkHigh = try bonus(.goalkeeper, balance: 20)
        #expect(gkLow.consensusBonus == 0 && gkHigh.consensusBonus == 0)
        #expect(gkLow.base == gkHigh.base)
        // Balance already among the role's attributes: no extra bonus
        let flaggedLow = try bonus(.attackingMidLeft, balance: 1, key: [.balance])
        let flaggedHigh = try bonus(.attackingMidLeft, balance: 20, key: [.balance])
        #expect(flaggedLow.consensusBonus == 0 && flaggedHigh.consensusBonus == 0)
    }

    @Test func theConsensusBonusIsCappedAtTenButLowerBonusesPassThrough() throws {
        let tables = RatingTables(
            positionWeights: [.attackingMidCentral: [.passing: 1]],
            consensusBonuses: ["AM(C)|Probe": [.pace: 0.5]], thresholds: [:])
        let capped = RatingEngine(tables: tables, parameters: .fm27, configuration: .fm27)
        func bonus(pace: Int) throws -> Double {
            let p = Player.fixture(attributes: [.pace: pace, .balance: 1], familiarity: [.attackingMidCentral: 20])
            return try capped.rating(for: p, in: probe(.attackingMidCentral)).inPossession.consensusBonus
        }
        #expect(try bonus(pace: 20) == 10)
        #expect(abs(try bonus(pace: 3) - 100 * 0.5 * 2.0 / 19) < 1e-9)   // 5.26, below the cap
    }

    @Test func aRoleWithNoAttributesScoresFifty() throws {
        let p = Player.fixture(attributes: [.passing: 20], familiarity: [.attackingMidLeft: 20])
        let none = try engine.rating(for: p, in: probe(.attackingMidLeft, key: [])).inPossession
        #expect(none.roleScore == 50)
        let some = try engine.rating(for: p, in: probe(.attackingMidLeft)).inPossession
        #expect(some.roleScore == 100)
    }

    @Test func ratingsDoNotDependOnDictionaryOrder() throws {
        let tables = try RatingTables.bundled()
        func reversed<V>(_ table: [Attribute: V]) -> [Attribute: V] {
            var out: [Attribute: V] = [:]
            for (k, v) in table.sorted(by: { $0.key.rawValue > $1.key.rawValue }) { out[k] = v }
            return out
        }
        func reversedOuter<K: Hashable & Comparable, V>(_ table: [K: V], _ inner: (V) -> V) -> [K: V] {
            var out: [K: V] = [:]
            for (k, v) in table.sorted(by: { $0.key > $1.key }) { out[k] = inner(v) }
            return out
        }
        let rebuilt = RatingTables(
            positionWeights: Dictionary(uniqueKeysWithValues: tables.positionWeights.sorted { $0.key.rawValue > $1.key.rawValue }.map { ($0.key, reversed($0.value)) }),
            consensusBonuses: reversedOuter(tables.consensusBonuses, reversed),
            thresholds: reversedOuter(tables.thresholds, reversed))
        let a = RatingEngine(tables: tables, parameters: .fm27, configuration: .fm27)
        let b = RatingEngine(tables: rebuilt, parameters: .fm27, configuration: .fm27)
        let assignments = try JSONDecoder().decode(Tactic.self, from: Fixtures.data("tactics/sample-4231.json"))
            .assignments(catalog: RoleCatalog.fm27())
        var seed: UInt64 = 12345
        func next() -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int((seed >> 33) % 20) + 1 }
        var compared = 0
        for n in 0..<40 {
            let attrs = Dictionary(uniqueKeysWithValues: Attribute.allCases.map { ($0, next()) })
            let fam = Dictionary(uniqueKeysWithValues: Position.allCases.map { ($0, next()) })
            let p = Player.fixture(name: "P\(n)", attributes: attrs, familiarity: fam)
            for s in assignments {
                #expect(try a.rating(for: p, in: s) == b.rating(for: p, in: s))
                compared += 1
            }
        }
        #expect(compared == 40 * assignments.count)
    }
}
