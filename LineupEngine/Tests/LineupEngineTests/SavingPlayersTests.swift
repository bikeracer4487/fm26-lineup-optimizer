import Foundation
import Testing
@testable import LineupEngine

@Suite struct SavingPlayersTests {
    let parameters = EngineParameters.fm27
    let today = Day(year: 2026, month: 11, day: 14)!
    let tactic: Tactic
    let assignments: [SlotAssignment]
    let squad: [Player]
    let tiers: SquadTiers

    init() throws {
        tactic = try PlannerFixture.tactic()
        assignments = try tactic.assignments(catalog: RoleCatalog.fm27())
        squad = try PlannerFixture.squad()
        tiers = try Self.tiers(of: squad, tactic: tactic)
    }

    static func tiers(of players: [Player], tactic: Tactic) throws -> SquadTiers {
        try SquadTiers.compute(tactic: tactic, players: players, ownClub: "Oxford City", catalog: RoleCatalog.fm27(),
                               profile: RatingProfile.standard(), parameters: .fm27)
    }

    func player(_ slot: SlotID, _ tier: String = "first", in players: [Player]? = nil,
                _ change: (inout Player) -> Void = { _ in }) -> Player {
        var p = (players ?? squad).first { $0.id == PlannerFixture.id(slot, tier) }!
        change(&p)
        return p
    }

    func position(_ slot: SlotID) -> Position { assignments.first { $0.slot == slot }!.ipPosition }

    func fixture(_ id: String, _ importance: Importance, inDays days: Int, opponent: String? = nil) -> Fixture {
        Fixture(id: FixtureID(id), date: today.adding(days: days), opponent: opponent ?? "Opponent \(id)",
                importance: importance, tactic: tactic)
    }

    func later(_ id: String, _ importance: Importance, inDays days: Int, opponent: String? = nil,
               tiers: SquadTiers? = nil) -> LaterFixture {
        LaterFixture(fixture: fixture(id, importance, inDays: days, opponent: opponent), tiers: tiers ?? self.tiers)
    }

    func adjustment(_ player: Player, at slot: SlotID, today importance: Importance, _ later: [LaterFixture],
                    settings: PlanSettings = .standard, parameters: EngineParameters? = nil) throws -> Adjustment? {
        try SavingPlayers.adjustment(for: player, fitness: ProjectedFitness(player), position: position(slot),
                                     today: fixture("today", importance, inDays: 0), later: later,
                                     settings: settings, parameters: parameters ?? self.parameters)
    }

    /// Worked by hand: his rating in his slot times the fall in the product of his fitness factors at a fixture
    /// `days` ahead, and his advantage there. No risk rules and no cap.
    func byHand(_ player: Player, at slot: SlotID, days: Int, tiers: SquadTiers? = nil,
                intensity: TrainingIntensity = .medium) throws -> (ratingTimesDrop: Double, advantage: Double) {
        let t = tiers ?? self.tiers
        func product(_ f: ProjectedFitness) -> Double {
            FitnessModel.factors(condition: f.condition, sharpness: f.sharpness, jadedness: Int(f.jadedness.rounded()),
                                 parameters: parameters).product
        }
        let now = ProjectedFitness(player)
        let rest = try FitnessProjection.afterDays(days, now, player: player, intensity: intensity, parameters: parameters)
        let played = try FitnessProjection.afterMatch(now, player: player, position: position(slot), parameters: parameters)
        let play = try FitnessProjection.afterDays(days, played, player: player, intensity: intensity, parameters: parameters)
        let drop = max(0, product(rest) - product(play))
        let rating = try #require(t.ratings[player.id]?[slot])
        let advantage = try #require(t.advantage(of: player.id))
        return (rating * drop, advantage)
    }

    func oneDecimal(_ x: Double) -> String { String(format: "%.1f", x) }

    // MARK: - Proximity and the formula

    @Test func aFirstChoicePlayerCostsMoreToUseTheDayBeforeABigMatchThanAWeekBefore() throws {
        let p = player(.ST_C)
        let soon = try #require(try adjustment(p, at: .ST_C, today: .low, [later("big", .high, inDays: 2)]))
        let week = try #require(try adjustment(p, at: .ST_C, today: .low, [later("big", .high, inDays: 7)]))
        #expect(soon.cost > week.cost)
        #expect(week.cost > 0)
        #expect(soon.kind == .savedForLater && soon.factor == 1)
    }

    @Test func theCostIsTheLossTimesTheRatioOfWeights() throws {
        let p = player(.ST_C)
        let hand = try byHand(p, at: .ST_C, days: 3)
        try #require(hand.ratingTimesDrop > 0 && hand.ratingTimesDrop < hand.advantage)
        let low = try #require(try adjustment(p, at: .ST_C, today: .low, [later("big", .high, inDays: 3)]))
        let medium = try #require(try adjustment(p, at: .ST_C, today: .medium, [later("big", .high, inDays: 3)]))
        #expect(abs(low.cost - hand.ratingTimesDrop * 3.75) < 1e-9)
        #expect(abs(medium.cost - hand.ratingTimesDrop * 2) < 1e-9)
    }

    @Test func theLossIsNeverMoreThanHisAdvantage() throws {
        let close = try PlannerFixture.squad(first: 14, second: 13)
        let closeTiers = try Self.tiers(of: close, tactic: tactic)
        let p = player(.ST_C, in: close)
        let hand = try byHand(p, at: .ST_C, days: 1, tiers: closeTiers)
        try #require(hand.ratingTimesDrop > hand.advantage && hand.advantage > 0)
        let a = try #require(try adjustment(p, at: .ST_C, today: .low, [later("big", .high, inDays: 1, tiers: closeTiers)]))
        #expect(abs(a.cost - hand.advantage * 3.75) < 1e-9)
        #expect(a.reason.hasSuffix("would cost about \(oneDecimal(hand.advantage)) there"))
    }

    @Test func aSecondChoicePlayerCostsNothing() throws {
        let first = player(.ST_C)
        let second = player(.ST_C, "second")
        #expect(try adjustment(first, at: .ST_C, today: .low, [later("big", .high, inDays: 2)]) != nil)
        #expect(try adjustment(second, at: .ST_C, today: .low, [later("big", .high, inDays: 2)]) == nil)
    }

    @Test func aPlayerOutsideTheLaterFixturesFirstElevenCostsNothingThere() throws {
        // In the later fixture the first-choice striker is injured in the tiers, so the second choice is first there.
        let injured = squad.map { var q = $0; if q.id == PlannerFixture.id(.ST_C, "first") { q.isInjured = true }; return q }
        let thereTiers = try Self.tiers(of: injured, tactic: tactic)
        let first = player(.ST_C)
        let second = player(.ST_C, "second")
        #expect(try adjustment(first, at: .ST_C, today: .low, [later("big", .high, inDays: 2, tiers: thereTiers)]) == nil)
        #expect(try adjustment(second, at: .ST_C, today: .low, [later("big", .high, inDays: 2, tiers: thereTiers)]) != nil)
    }

    // MARK: - Importance

    @Test func nothingIsSavedAtAHighFixture() throws {
        let p = player(.ST_C)
        #expect(try adjustment(p, at: .ST_C, today: .high, [later("big", .high, inDays: 2)]) == nil)
        #expect(try adjustment(p, at: .ST_C, today: .high, [later("big", .high, inDays: 1), later("next", .medium, inDays: 3)]) == nil)
    }

    @Test func nothingIsSavedForALesserOrEqualFixture() throws {
        let p = player(.ST_C)
        #expect(try adjustment(p, at: .ST_C, today: .medium, [later("m", .medium, inDays: 2)]) == nil)
        #expect(try adjustment(p, at: .ST_C, today: .medium, [later("l", .low, inDays: 2)]) == nil)
        #expect(try adjustment(p, at: .ST_C, today: .sharpness, [later("s", .sharpness, inDays: 2)]) == nil)
        #expect(try adjustment(p, at: .ST_C, today: .low, [later("l", .low, inDays: 2)]) == nil)
        // A greater one does count.
        #expect(try adjustment(p, at: .ST_C, today: .sharpness, [later("l", .low, inDays: 2)]) != nil)
        #expect(try adjustment(p, at: .ST_C, today: .low, [later("m", .medium, inDays: 2)]) != nil)
    }

    // MARK: - Fitness

    @Test func anUnsharpPlayerWhoGainsFromPlayingCostsNothing() throws {
        let unsharp = player(.ST_C) { $0.sharpness = 0.55 }
        #expect(try adjustment(unsharp, at: .ST_C, today: .low, [later("big", .high, inDays: 7)]) == nil)
        let sharp = player(.ST_C)
        #expect(try adjustment(sharp, at: .ST_C, today: .low, [later("big", .high, inDays: 7)]) != nil)
    }

    @Test func aStartThatWouldPutHimBelowTheFloorCostsHisWholeAdvantage() throws {
        let p = player(.D_L) { $0.condition = 0.86 }
        let hand = try byHand(p, at: .D_L, days: 1)
        let a = try #require(try adjustment(p, at: .D_L, today: .low, [later("big", .high, inDays: 1)]))
        #expect(abs(a.cost - hand.advantage * 3.75) < 1e-9)
    }

    @Test func theFloorRuleCostsTheWholeAdvantageEvenWhenTheFitnessDropIsSmaller() throws {
        let wide = try PlannerFixture.squad(first: 16, second: 6)
        let wideTiers = try Self.tiers(of: wide, tactic: tactic)
        let p = player(.D_L, in: wide) { $0.condition = 0.86 }
        let hand = try byHand(p, at: .D_L, days: 1, tiers: wideTiers)
        try #require(hand.ratingTimesDrop < hand.advantage)
        let a = try #require(try adjustment(p, at: .D_L, today: .low, [later("big", .high, inDays: 1, tiers: wideTiers)]))
        #expect(abs(a.cost - hand.advantage * 3.75) < 1e-9)
    }

    @Test func aRuleRestingWouldBreakAnywayDoesNotCostTheWholeAdvantage() throws {
        let wide = try PlannerFixture.squad(first: 16, second: 6)
        let wideTiers = try Self.tiers(of: wide, tactic: tactic)
        // Resting a day takes him only to about 83%, still below the floor.
        let p = player(.D_L, in: wide) { $0.condition = 0.70 }
        let rested = try FitnessProjection.afterDays(1, ProjectedFitness(p), player: p, intensity: .medium, parameters: parameters)
        try #require(rested.condition < parameters.conditionFloor.value)
        let hand = try byHand(p, at: .D_L, days: 1, tiers: wideTiers)
        try #require(hand.ratingTimesDrop > 0 && hand.ratingTimesDrop < hand.advantage)
        let a = try #require(try adjustment(p, at: .D_L, today: .low, [later("big", .high, inDays: 1, tiers: wideTiers)]))
        #expect(abs(a.cost - hand.ratingTimesDrop * 3.75) < 1e-9)
    }

    @Test func aStartThatWouldLeaveHimJadedCostsHisWholeAdvantageUnlessTheFixtureIsHigh() throws {
        let wide = try PlannerFixture.squad(first: 16, second: 6)
        let wideTiers = try Self.tiers(of: wide, tactic: tactic)
        // After a start he is at 420 the next day; resting, at 360.
        let p = player(.ST_C, in: wide) { $0.jadedness = 380 }
        let hand = try byHand(p, at: .ST_C, days: 1, tiers: wideTiers)
        try #require(hand.ratingTimesDrop < hand.advantage)
        let medium = try #require(try adjustment(p, at: .ST_C, today: .low, [later("m", .medium, inDays: 1, tiers: wideTiers)]))
        #expect(abs(medium.cost - hand.advantage * 1.5 / 0.8) < 1e-9)
        let high = try #require(try adjustment(p, at: .ST_C, today: .low, [later("h", .high, inDays: 1, tiers: wideTiers)]))
        #expect(abs(high.cost - hand.ratingTimesDrop * 3.75) < 1e-9)
    }

    @Test func theTrainingIntensityIsTheSettingsOne() throws {
        let p = player(.ST_C)
        let lowTraining = PlanSettings(trainingIntensity: .low)
        let hand = try byHand(p, at: .ST_C, days: 3, intensity: .low)
        try #require(hand.ratingTimesDrop < hand.advantage)
        let a = try #require(try adjustment(p, at: .ST_C, today: .low, [later("big", .high, inDays: 3)], settings: lowTraining))
        #expect(abs(a.cost - hand.ratingTimesDrop * 3.75) < 1e-9)
        let medium = try #require(try adjustment(p, at: .ST_C, today: .low, [later("big", .high, inDays: 3)]))
        #expect(a.cost != medium.cost)
    }

    @Test func aFixtureOnOrBeforeTodayIsIgnored() throws {
        let p = player(.ST_C)
        #expect(try adjustment(p, at: .ST_C, today: .low, [later("same", .high, inDays: 0), later("past", .high, inDays: -2)]) == nil)
    }

    @Test func aMissingStaminaIsAnError() throws {
        let p = player(.ST_C) { $0.attributes[.stamina] = nil }
        #expect(throws: RatingError.missingAttribute(player: p.name, attribute: .stamina)) {
            try adjustment(p, at: .ST_C, today: .low, [later("big", .high, inDays: 2)])
        }
    }

    @Test func aMissingNaturalFitnessIsAnError() throws {
        let p = player(.ST_C) { $0.attributes[.naturalFitness] = nil }
        #expect(throws: RatingError.missingAttribute(player: p.name, attribute: .naturalFitness)) {
            try adjustment(p, at: .ST_C, today: .low, [later("big", .high, inDays: 2)])
        }
    }

    // MARK: - Advantage

    @Test func aFirstChoiceWhoseCoverRatesHigherCostsNothing() throws {
        let p = player(.ST_C)
        let cover = PlannerFixture.id(.ST_C, "second")
        func handBuilt(coverRating: Double) -> SquadTiers {
            SquadTiers(first: [.ST_C: p.id], second: [.ST_C: cover], ratings: [p.id: [.ST_C: 60], cover: [.ST_C: coverRating]])
        }
        #expect(try adjustment(p, at: .ST_C, today: .low, [later("big", .high, inDays: 2, tiers: handBuilt(coverRating: 61))]) == nil)
        #expect(try adjustment(p, at: .ST_C, today: .low, [later("big", .high, inDays: 2, tiers: handBuilt(coverRating: 50))]) != nil)
        // Nor does it take anything off what another fixture costs.
        let alone = try #require(try adjustment(p, at: .ST_C, today: .low, [later("next", .high, inDays: 3)]))
        let both = try #require(try adjustment(p, at: .ST_C, today: .low,
                                               [later("big", .high, inDays: 2, tiers: handBuilt(coverRating: 61)), later("next", .high, inDays: 3)]))
        #expect(both == alone)
    }

    // MARK: - Setting

    @Test func aSettingOfZeroTurnsItOff() throws {
        let p = player(.ST_C)
        let off = PlanSettings(savingPlayers: 0)
        #expect(try adjustment(p, at: .ST_C, today: .low, [later("big", .high, inDays: 2)], settings: off) == nil)
    }

    @Test func theSettingScalesTheCost() throws {
        let p = player(.ST_C)
        let one = try #require(try adjustment(p, at: .ST_C, today: .low, [later("big", .high, inDays: 2)]))
        let two = try #require(try adjustment(p, at: .ST_C, today: .low, [later("big", .high, inDays: 2)],
                                              settings: PlanSettings(savingPlayers: 2)))
        #expect(abs(two.cost - 2 * one.cost) < 1e-9)
        #expect(two.reason == one.reason)
    }

    // MARK: - Several fixtures and the reason

    @Test func theReasonNamesTheFixtureThatMattersMost() throws {
        let p = player(.ST_C)
        let fixtures = [later("barnet", .medium, inDays: 5, opponent: "Barnet"), later("wealdstone", .high, inDays: 2, opponent: "Wealdstone")]
        let a = try #require(try adjustment(p, at: .ST_C, today: .low, fixtures))
        let near = try byHand(p, at: .ST_C, days: 2)
        let far = try byHand(p, at: .ST_C, days: 5)
        try #require(near.ratingTimesDrop < near.advantage && far.ratingTimesDrop < far.advantage)
        #expect(a.reason == "Kept fresher for Wealdstone on \(today.adding(days: 2).iso): "
            + "starting today would cost about \(oneDecimal(near.ratingTimesDrop)) there")
        #expect(abs(a.cost - (near.ratingTimesDrop * 3.75 + far.ratingTimesDrop * 1.5 / 0.8)) < 1e-9)
    }

    @Test func theOrderOfTheLaterFixturesDoesNotMatter() throws {
        let p = player(.ST_C)
        let fixtures = [later("c", .medium, inDays: 5), later("a", .high, inDays: 2), later("b", .high, inDays: 9)]
        let forward = try adjustment(p, at: .ST_C, today: .low, fixtures)
        let reversed = try adjustment(p, at: .ST_C, today: .low, fixtures.reversed())
        #expect(forward != nil)
        #expect(forward == reversed)
    }

    @Test func whenTwoFixturesMatterEquallyTheReasonNamesTheEarlier() throws {
        let p = player(.ST_C)
        // Same day, same importance: equal contributions, so the fixture id decides.
        let fixtures = [later("b", .high, inDays: 2, opponent: "Barnet"), later("a", .high, inDays: 2, opponent: "Aldershot")]
        let a = try #require(try adjustment(p, at: .ST_C, today: .low, fixtures))
        #expect(a.reason.hasPrefix("Kept fresher for Aldershot on "))
        let b = try #require(try adjustment(p, at: .ST_C, today: .low, fixtures.reversed()))
        #expect(b.reason == a.reason)
    }

    // MARK: - Weights

    @Test func theWeightsAreListedWithEvidenceAndSource() {
        let w = parameters.importanceWeights
        #expect(w.value == [.high: 3.0, .medium: 1.5, .low: 0.8, .sharpness: 0.1])
        #expect(w.evidence == .carriedOverFM26)
        #expect(w.source.contains("scoring_parameters.py"))
        #expect(w.source.contains("customizable-tactics"))
        #expect(parameters.all.contains { $0.name == "importanceWeights" })
    }

    @Test func aMissingOrNonPositiveWeightGivesNoAdjustment() throws {
        let p = player(.ST_C)
        let fixtures = [later("big", .high, inDays: 2)]
        #expect(try adjustment(p, at: .ST_C, today: .low, fixtures) != nil)
        for broken in [[Importance.high: 3.0, .medium: 1.5, .sharpness: 0.1],
                       [.high: 3.0, .medium: 1.5, .low: 0, .sharpness: 0.1],
                       [.medium: 1.5, .low: 0.8, .sharpness: 0.1],
                       [.high: -3.0, .medium: 1.5, .low: 0.8, .sharpness: 0.1],
                       [.high: .infinity, .medium: 1.5, .low: 0.8, .sharpness: 0.1],
                       [.high: 3.0, .medium: 1.5, .low: .nan, .sharpness: 0.1]] {
            var q = parameters
            q.importanceWeights = Parameter(broken, .derived, source: "test")
            #expect(try adjustment(p, at: .ST_C, today: .low, fixtures, parameters: q) == nil, "\(broken)")
        }
    }

    @Test func missingAndNonPositiveWeightsAreReported() {
        #expect(FitnessModel.problems(in: parameters).isEmpty)
        var q = parameters
        q.importanceWeights = Parameter([.high: .infinity, .medium: 0, .sharpness: -1], .derived, source: "test")
        let found = FitnessModel.problems(in: q).filter { $0.contains("importanceWeights") }
        #expect(found.count == 4)
        #expect(found.contains { $0.contains("high") })
        #expect(found.contains { $0.contains("low") })
        #expect(found.contains { $0.contains("medium") })
        #expect(found.contains { $0.contains("sharpness") })
    }
}
