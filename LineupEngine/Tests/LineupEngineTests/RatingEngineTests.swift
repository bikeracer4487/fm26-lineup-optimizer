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
        let r = engine.rating(for: cb, in: try slot(.D_CL))
        #expect(abs(r.inPossession.positionScore - 47.368) < 0.01)
        #expect(r.inPossession.familiarityFactor == 1.0 && r.ipWeight == 0.5)
    }

    @Test func higherKeyAttributeRaisesTheRating() throws {
        let base = Player.fixture(familiarity: [dc: 20])
        let passer = Player.fixture(attributes: [.passing: 15], familiarity: [dc: 20])
        let finisher = Player.fixture(attributes: [.finishing: 15], familiarity: [dc: 20])
        let s = try slot(.D_CL)
        let before = engine.rating(for: base, in: s)
        #expect(engine.rating(for: passer, in: s).value > before.value)
        #expect(engine.rating(for: finisher, in: s).value == before.value)
    }

    @Test func familiarityStepsApplyPerPhase() throws {
        // AM_L slot: in possession AM (L), out of possession M (L)
        let both = Player.fixture(familiarity: [aml: 20, ml: 20])
        let ipOnly = Player.fixture(familiarity: [aml: 20, ml: 9])
        let a = engine.rating(for: both, in: try slot(.AM_L)), b = engine.rating(for: ipOnly, in: try slot(.AM_L))
        #expect(b.inPossession.value == a.inPossession.value)
        #expect(b.outOfPossession.familiarityFactor == 0.60)
        #expect(b.value < a.value)
        #expect(a.ipWeight == 0.7)
    }

    @Test(arguments: [(20, 1.0), (18, 1.0), (17, 0.95), (15, 0.95), (14, 0.90), (13, 0.90), (12, 0.80), (10, 0.80),
                      (9, 0.60), (8, 0.60), (7, 0.35), (5, 0.35), (4, 0.10), (1, 0.10)])
    func familiarityFactorAtEachStep(_ familiarity: Int, _ factor: Double) throws {
        let p = Player.fixture(familiarity: [dc: familiarity])
        let r = engine.rating(for: p, in: try slot(.D_CL))
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
        #expect(engine.rating(for: met, in: s).inPossession.thresholdFactor == 1.0)
        #expect(abs(engine.rating(for: short, in: s).inPossession.thresholdFactor - 0.96) < 1e-9)
        #expect(abs(engine.rating(for: broken, in: s).inPossession.thresholdFactor - 0.80) < 1e-9)
    }

    @Test func currentAbilityDoesNotChangeAnFM27Rating() throws {
        // same attributes, CA 60 vs CA 140
        let weak = Player.fixture(familiarity: [dc: 20], currentAbility: 60)
        let strong = Player.fixture(familiarity: [dc: 20], currentAbility: 140)
        let s = try slot(.D_CL)
        #expect(engine.rating(for: weak, in: s).value == engine.rating(for: strong, in: s).value)
        #expect(reference.rating(for: weak, in: s).value < reference.rating(for: strong, in: s).value)
    }
}
