import Foundation
import Testing
@testable import LineupEngine

@Suite struct RatingEngineTests {
    static let carried = try! RatingProfile.carriedOver()
    static let fm27 = try! RatingProfile.fm27EngineTests()
    let engine = RatingEngine(profile: Self.carried, parameters: .fm27, configuration: .fm27)
    let reference = RatingEngine(profile: Self.carried, parameters: .fm27, configuration: .fm26Reference)
    let thresholdsOn = RatingEngine(profile: Self.carried, parameters: .fm27, configuration: .thresholdsOn)
    let fm27Engine = RatingEngine(profile: Self.fm27, parameters: .fm27, configuration: .fm27)
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
        #expect((try thresholdsOn.rating(for: met, in: s)).inPossession.thresholdFactor == 1.0)
        #expect(abs((try thresholdsOn.rating(for: short, in: s)).inPossession.thresholdFactor - 0.96) < 1e-9)
        #expect(abs((try thresholdsOn.rating(for: broken, in: s)).inPossession.thresholdFactor - 0.80) < 1e-9)
    }

    @Test func thresholdsDoNotApplyInTheFM27Configuration() throws {
        // Channel Forward, Acceleration 12 against a threshold of 14.
        let short = Player.fixture(attributes: [.acceleration: 12, .pace: 14, .offTheBall: 13], familiarity: [.striker: 20])
        let s = try slot(.ST_C)
        #expect(RatingConfiguration.fm27.appliesRoleThresholds == false)
        #expect(RatingConfiguration.fm26Reference.appliesRoleThresholds == true)
        let off = try engine.rating(for: short, in: s), on = try thresholdsOn.rating(for: short, in: s)
        #expect(off.inPossession.thresholdFactor == 1.0)
        #expect(abs(on.inPossession.thresholdFactor - 0.96) < 1e-9)
        #expect(abs(on.inPossession.base - off.inPossession.base * 0.96) < 1e-9)
        // The FM27 profile has no thresholds to apply even when they are switched on.
        let fm27On = RatingEngine(profile: Self.fm27, parameters: .fm27, configuration: .thresholdsOn)
        #expect(try fm27On.rating(for: short, in: s).inPossession.thresholdFactor == 1.0)
    }

    @Test func aPlayerBelowAThresholdNoLongerLosesHisPlaceBecauseOfIt() throws {
        // ST_C: Channel Forward (Acceleration 14, Pace 14, Off The Ball 13) in possession,
        // Centre Forward (Finishing 14, Off The Ball 13) out of it.
        let s = try slot(.ST_C)
        let meets = Player.fixture(name: "Meets", all: 10, attributes: [.acceleration: 14, .pace: 14, .offTheBall: 13, .finishing: 14],
                                   familiarity: [.striker: 20])
        let below = Player.fixture(name: "Below", all: 12, attributes: [.acceleration: 12, .pace: 12, .offTheBall: 12, .finishing: 12],
                                   familiarity: [.striker: 20])
        #expect(try engine.rating(for: below, in: s).inPossession.positionScore > engine.rating(for: meets, in: s).inPossession.positionScore)
        #expect(try engine.rating(for: below, in: s).inPossession.roleScore > engine.rating(for: meets, in: s).inPossession.roleScore)
        #expect(try engine.rating(for: below, in: s).value > engine.rating(for: meets, in: s).value)
        #expect(try thresholdsOn.rating(for: below, in: s).value < thresholdsOn.rating(for: meets, in: s).value)
    }

    @Test func keyOnlyRoleScoreIgnoresPreferableExceptAsATieBreak() throws {
        let catalog = try RoleCatalog.fm27()
        let dlp = try catalog.role(named: "Deep-Lying Playmaker", phase: .inPossession, at: .defensiveMidfielder)
        let s = SlotAssignment(slot: .DM_L, ipPosition: .defensiveMidfielder, ipRole: dlp, oopSlot: .DM_L,
                               oopPosition: .defensiveMidfielder,
                               oopRole: try catalog.role(named: "Defensive Midfielder", phase: .outOfPossession, at: .defensiveMidfielder))
        func roleScore(_ attributes: [Attribute: Int]) throws -> Double {
            try fm27Engine.rating(for: Player.fixture(attributes: attributes, familiarity: [.defensiveMidfielder: 20]), in: s)
                .inPossession.roleScore
        }
        let base = try roleScore([:])
        let preferableUp = try roleScore(Dictionary(uniqueKeysWithValues: dlp.preferable.map { ($0, 20) }))
        let keyUp = try roleScore(Dictionary(uniqueKeysWithValues: dlp.key.map { ($0, 20) }))
        #expect(preferableUp > base)
        #expect(preferableUp - base <= 5)
        #expect(keyUp - base > 5)
        // Equal on key attributes: the preferable attributes decide.
        let better = try roleScore(Dictionary(uniqueKeysWithValues: dlp.preferable.map { ($0, 14) }))
        let worse = try roleScore(Dictionary(uniqueKeysWithValues: dlp.preferable.map { ($0, 11) }))
        #expect(better > worse)
        // The carried-over rule gives preferable attributes far more than a tie-break.
        let carriedBase = try engine.rating(for: Player.fixture(familiarity: [.defensiveMidfielder: 20]), in: s).inPossession.roleScore
        let carriedUp = try engine.rating(for: Player.fixture(attributes: Dictionary(uniqueKeysWithValues: dlp.preferable.map { ($0, 20) }),
                                                              familiarity: [.defensiveMidfielder: 20]), in: s).inPossession.roleScore
        #expect(carriedUp - carriedBase > 5)
    }

    @Test func theTieBreakRuleFallsBackWhenAListIsEmpty() throws {
        let p = Player.fixture(attributes: [.passing: 20, .vision: 1], familiarity: [.attackingMidLeft: 20])
        func score(key: [Attribute], preferable: [Attribute]) throws -> Double {
            try fm27Engine.rating(for: p, in: probe(.attackingMidLeft, key: key, preferable: preferable)).inPossession.roleScore
        }
        #expect(try score(key: [.passing], preferable: []) == 100)          // key mean alone
        #expect(try score(key: [], preferable: [.passing]) == 100)          // preferable mean alone
        #expect(try score(key: [], preferable: []) == 50)                   // the empty-role score
        #expect(abs(try score(key: [.passing], preferable: [.vision]) - 95) < 1e-9)   // 0.95 × 100 + 0.05 × 0
        // A preferable attribute that is also key counts once, as key.
        #expect(try score(key: [.passing], preferable: [.passing]) == 100)
    }

    @Test func theTwoProfilesRateAFastWeakPasserDifferently() throws {
        let catalog = try RoleCatalog.fm27()
        let s = SlotAssignment(
            slot: .DM_L, ipPosition: .defensiveMidfielder,
            ipRole: try catalog.role(named: "Deep-Lying Playmaker", phase: .inPossession, at: .defensiveMidfielder),
            oopSlot: .DM_L, oopPosition: .defensiveMidfielder,
            oopRole: try catalog.role(named: "Defensive Midfielder", phase: .outOfPossession, at: .defensiveMidfielder))
        let fast = Player.fixture(name: "Fast", attributes: [.pace: 18, .acceleration: 18, .passing: 5, .technique: 5],
                                  familiarity: [.defensiveMidfielder: 20])
        let passer = Player.fixture(name: "Passer", attributes: [.pace: 5, .acceleration: 5, .passing: 18, .technique: 18],
                                    familiarity: [.defensiveMidfielder: 20])
        let fm27Gap = try fm27Engine.rating(for: fast, in: s).value - fm27Engine.rating(for: passer, in: s).value
        let carriedGap = try engine.rating(for: fast, in: s).value - engine.rating(for: passer, in: s).value
        #expect(fm27Gap > 0)
        #expect(carriedGap < fm27Gap)
    }

    @Test func positionalEmphasisChangesWhoRatesHigherAtAPosition() throws {
        // Identical but for Heading and Dribbling, rated in a role that reads neither: only the position score differs.
        // FM26 weighs Heading at centre-back and Dribbling out wide, so the emphasis favours the header at D (C)
        // and the dribbler at AM (L). FM27's base table weighs Dribbling above Heading, so without it the dribbler leads at both.
        let header = Player.fixture(name: "Header", attributes: [.heading: 18, .dribbling: 1],
                                    familiarity: [dc: 20, aml: 20])
        let dribbler = Player.fixture(name: "Dribbler", attributes: [.heading: 1, .dribbling: 18],
                                      familiarity: [dc: 20, aml: 20])
        let standard = RatingEngine(profile: try RatingProfile.standard(), parameters: .fm27, configuration: .fm27)
        let flat = RatingEngine(profile: try RatingProfile.fm27(positionalEmphasisShare: 0), parameters: .fm27, configuration: .fm27)
        for position in [dc, aml] {
            let roles = [probe(position).ipRole, probe(position).oopRole]
            try #require(Set(roles.flatMap { $0.key + $0.preferable }).isDisjoint(with: [.heading, .dribbling]))
        }
        func gap(_ engine: RatingEngine, at position: Position) throws -> Double {
            try engine.rating(for: header, in: probe(position)).value - engine.rating(for: dribbler, in: probe(position)).value
        }
        #expect(try gap(standard, at: dc) > 0)
        #expect(try gap(standard, at: aml) < 0)
        #expect(try gap(flat, at: dc) < 0)
        #expect(try gap(flat, at: aml) < 0)
    }

    @Test func curvesScaleThePositionScore() throws {
        // Pace 9 sits higher on the FM27 Pace curve than on the straight line; with the curve removed the score falls.
        let p = Player.fixture(attributes: [.pace: 9], familiarity: [dc: 20])
        let s = try slot(.D_CL)
        let curved = try fm27Engine.rating(for: p, in: s).inPossession.positionScore
        var curves = Self.fm27.curves
        curves[.pace] = nil
        let straight = try RatingEngine(profile: Self.fm27.with(curves: curves), parameters: .fm27, configuration: .fm27)
            .rating(for: p, in: s).inPossession.positionScore
        #expect(Self.fm27.scaled(9, for: .pace) != 8.0 / 19)
        #expect(curved != straight)
        // An attribute the position does not weigh changes nothing, curve or not.
        let q = Player.fixture(attributes: [.passing: 18], familiarity: [dc: 20])
        #expect(try fm27Engine.rating(for: q, in: s).inPossession.positionScore
            == fm27Engine.rating(for: Player.fixture(familiarity: [dc: 20]), in: s).inPossession.positionScore)
    }

    @Test func aGoalkeeperIsRatedWithoutCurves() throws {
        // Agility is a key attribute of the Goalkeeper and Sweeper Keeper roles in GK, and has an outfield curve.
        let s = try slot(.GK)
        try #require(s.ipRole.key.contains(.agility) && s.oopRole.key.contains(.agility))
        let p12 = Player.fixture(attributes: [.agility: 12], familiarity: [.goalkeeper: 20])
        let p18 = Player.fixture(attributes: [.agility: 18], familiarity: [.goalkeeper: 20])
        let a = try fm27Engine.rating(for: p12, in: s).inPossession, b = try fm27Engine.rating(for: p18, in: s).inPossession
        let weight = try #require(Self.fm27.tables.positionWeights[.goalkeeper]?[.agility])
        #expect(abs((b.positionScore - a.positionScore) - weight * 6 / 19 * 100) < 1e-9)
        // Role score: key mean over the role's key attributes, linear in goal.
        let keys = Double(s.ipRole.key.count)
        #expect(abs((b.roleScore - a.roleScore) - 0.95 * 100 * (6.0 / 19) / keys) < 1e-9)
        // The curve would have given a different step.
        #expect(abs((Self.fm27.scaled(18, for: .agility) - Self.fm27.scaled(12, for: .agility)) - 6.0 / 19) > 0.01)
    }

    @Test func anOutfielderStillFollowsTheCurves() throws {
        let s = try slot(.D_CL)
        let p12 = Player.fixture(attributes: [.agility: 12], familiarity: [dc: 20])
        let p18 = Player.fixture(attributes: [.agility: 18], familiarity: [dc: 20])
        let a = try fm27Engine.rating(for: p12, in: s).inPossession, b = try fm27Engine.rating(for: p18, in: s).inPossession
        let weight = try #require(Self.fm27.tables.positionWeights[dc]?[.agility])
        let curved = weight * (Self.fm27.scaled(18, for: .agility) - Self.fm27.scaled(12, for: .agility)) * 100
        #expect(abs((b.positionScore - a.positionScore) - curved) < 1e-9)
        #expect(abs((b.positionScore - a.positionScore) - weight * 6 / 19 * 100) > 1e-3)
    }

    @Test func curvesScaleTheRoleScore() throws {
        // Channel Forward in possession: Work Rate is a key attribute with a curve (flat above 12).
        let s = try slot(.ST_C)
        try #require(s.ipRole.key.contains(.workRate))
        let p = Player.fixture(attributes: [.workRate: 6], familiarity: [.striker: 20])
        let curved = try fm27Engine.rating(for: p, in: s).inPossession.roleScore
        var curves = Self.fm27.curves
        curves[.workRate] = nil
        let straight = try RatingEngine(profile: Self.fm27.with(curves: curves), parameters: .fm27, configuration: .fm27)
            .rating(for: p, in: s).inPossession.roleScore
        // Only Work Rate's scale moved: (curve - line) at 6, over the key count, at the key share.
        let expected = 0.95 * 100 * (Self.fm27.scaled(6, for: .workRate) - 5.0 / 19) / Double(s.ipRole.key.count)
        #expect(abs((curved - straight) - expected) < 1e-9)
        #expect(curved > straight)
        // Where the curve meets the line (at 20) removing it changes nothing.
        let top = Player.fixture(attributes: [.workRate: 20], familiarity: [.striker: 20])
        #expect(try fm27Engine.rating(for: top, in: s).inPossession.roleScore
            == RatingEngine(profile: Self.fm27.with(curves: curves), parameters: .fm27, configuration: .fm27)
                .rating(for: top, in: s).inPossession.roleScore)
    }

    @Test func curvesScaleTheConsensusBonus() throws {
        // Neither shipped profile reaches this (FM27 has no bonuses, carried-over no curves), so a constructed one.
        let tables = RatingTables(positionWeights: [.attackingMidCentral: [.passing: 1]],
                                  consensusBonuses: ["AM(C)|Probe": [.pace: 0.1]], thresholds: [:])
        let engine = RatingEngine(profile: Self.fm27.with(tables: tables), parameters: .fm27, configuration: .fm27)
        let p = Player.fixture(attributes: [.pace: 9, .balance: 1], familiarity: [.attackingMidCentral: 20])
        let bonus = try engine.rating(for: p, in: probe(.attackingMidCentral)).inPossession.consensusBonus
        #expect(abs(bonus - 100 * 0.1 * Self.fm27.scaled(9, for: .pace)) < 1e-9)
        #expect(abs(bonus - 100 * 0.1 * 8 / 19) > 1e-3)
    }

    @Test func theProfileSharesBlendTheScores() throws {
        let p = Player.fixture(attributes: [.pace: 15, .passing: 6], familiarity: [dc: 20])
        let s = try slot(.D_CL)
        let r = try fm27Engine.rating(for: p, in: s).inPossession
        #expect(abs(r.base - (0.70 * r.positionScore + 0.30 * r.roleScore)) < 1e-9)
        let c = try engine.rating(for: p, in: s).inPossession
        #expect(abs(c.base - (0.60 * c.positionScore + 0.35 * c.roleScore + 0.05 * c.consensusBonus)) < 1e-9)
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

    @Test func theInPossessionWeightFollowsTheOutOfPossessionPosition() throws {
        func slot(ip: Position, ipSlot: SlotID, oop: Position, oopSlot: SlotID) -> SlotAssignment {
            SlotAssignment(slot: ipSlot, ipPosition: ip, ipRole: probe(ip).ipRole,
                           oopSlot: oopSlot, oopPosition: oop, oopRole: probe(oop).oopRole)
        }
        let p = Player.fixture(familiarity: [.wingBackLeft: 20, .midfielderLeft: 20])
        // Defensive in possession, not out of it: the other-phase weight, 0.7.
        let wingBackToMidfield = try engine.rating(for: p, in: slot(ip: .wingBackLeft, ipSlot: .WB_L, oop: .midfielderLeft, oopSlot: .M_L))
        #expect(wingBackToMidfield.ipWeight == 0.7)
        // Not defensive in possession, defensive out of it: the defensive weight, 0.5.
        let midfieldToWingBack = try engine.rating(for: p, in: slot(ip: .midfielderLeft, ipSlot: .M_L, oop: .wingBackLeft, oopSlot: .WB_L))
        #expect(midfieldToWingBack.ipWeight == 0.5)
        let r = midfieldToWingBack
        #expect(abs(r.value - 2 * (0.5 * r.inPossession.value + 0.5 * r.outOfPossession.value)) < 1e-9)
    }

    @Test func fm27DoesNotRoundAndTheReferenceDoes() throws {
        let attrs: [Attribute: Int] = [.passing: 13, .pace: 7, .tackling: 16, .vision: 4, .strength: 11, .jumpingReach: 17]
        let p = Player.fixture(attributes: attrs, familiarity: [dc: 20], currentAbility: 100)
        let s = try slot(.D_CL)
        let exact = try engine.rating(for: p, in: s).inPossession
        let blended = 0.60 * exact.positionScore + 0.35 * exact.roleScore + 0.05 * exact.consensusBonus
        #expect(abs(exact.base - blended * exact.thresholdFactor) < 1e-12)
        #expect(exact.base != (exact.base * 10).rounded() / 10)
        // The reference also applies thresholds (and the current-ability factor, 1 at CA 100): compare like with like.
        let unrounded = try thresholdsOn.rating(for: p, in: s).inPossession
        let rounded = try reference.rating(for: p, in: s).inPossession
        #expect(rounded.base == (unrounded.base * 10).rounded(.toNearestOrEven) / 10)
        #expect(rounded.base != unrounded.base)
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
        let capped = RatingEngine(profile: Self.carried.with(tables: tables), parameters: .fm27, configuration: .fm27)
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

    @Test func theEmptyRoleScoreComesFromTheParameters() throws {
        var parameters = EngineParameters.fm27
        parameters.emptyRoleScore = Parameter(40, .derived, source: "test: lowered empty-role score")
        let lowered = RatingEngine(profile: Self.carried, parameters: parameters, configuration: .fm27)
        let p = Player.fixture(attributes: [.passing: 20], familiarity: [.attackingMidLeft: 20])
        #expect(try lowered.rating(for: p, in: probe(.attackingMidLeft, key: [])).inPossession.roleScore == 40)
        // A role with attributes does not read it.
        #expect(try lowered.rating(for: p, in: probe(.attackingMidLeft)).inPossession.roleScore == 100)
    }

    @Test func balanceHasNoEffectUnderTheFM27ProfileBeyondThePositionScore() throws {
        // The Balance bonus is part of the consensus bonus, whose share is 0 in the FM27 profile.
        func rating(balance: Int) throws -> PhaseRating {
            let p = Player.fixture(attributes: [.balance: balance], familiarity: [.attackingMidLeft: 20])
            return try fm27Engine.rating(for: p, in: probe(.attackingMidLeft)).inPossession
        }
        let low = try rating(balance: 1), high = try rating(balance: 20)
        #expect(high.consensusBonus > low.consensusBonus)
        #expect(high.roleScore == low.roleScore)
        #expect(abs((high.base - low.base) - 0.70 * (high.positionScore - low.positionScore)) < 1e-9)
    }

    @Test(arguments: ["carried-over", "fm27-engine-tests"])
    func ratingsDoNotDependOnDictionaryOrder(_ profileID: String) throws {
        let profile = try #require(try RatingProfile.all().first { $0.id == profileID })
        let tables = profile.tables
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
        let rebuiltCurves = Dictionary(uniqueKeysWithValues: profile.curves.sorted { $0.key.rawValue > $1.key.rawValue }
            .map { ($0.key, Array($0.value.reversed())) })
        // Thresholds on, so the reversed threshold table is read too.
        let a = RatingEngine(profile: profile, parameters: .fm27, configuration: .thresholdsOn)
        let b = RatingEngine(profile: profile.with(tables: rebuilt).with(curves: rebuiltCurves), parameters: .fm27, configuration: .thresholdsOn)
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
