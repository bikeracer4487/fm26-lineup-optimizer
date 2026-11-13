import Testing
@testable import LineupEngine

@Suite struct FitnessProjectionTests {
    let p = EngineParameters.fm27

    func fitness(_ c: Double = 1, _ s: Double = 1, _ j: Double = -500, since: Int? = nil) -> ProjectedFitness {
        ProjectedFitness(condition: c, sharpness: s, jadedness: j, daysSinceMatch: since)
    }

    func match(_ f: ProjectedFitness, _ position: Position, stamina: Int = 10) throws -> ProjectedFitness {
        let player = Player.fixture(attributes: [.stamina: stamina])
        return try FitnessProjection.afterMatch(f, player: player, position: position, parameters: p)
    }

    func rest(_ days: Int, _ f: ProjectedFitness, nf: Int = 10, _ intensity: TrainingIntensity = .medium) throws -> ProjectedFitness {
        let player = Player.fixture(attributes: [.naturalFitness: nf])
        return try FitnessProjection.afterDays(days, f, player: player, intensity: intensity, parameters: p)
    }

    @Test func initialiserTakesTheImportedValues() {
        let f = ProjectedFitness(Player.fixture(condition: 0.9, sharpness: 0.8, jadedness: 120))
        #expect(f == fitness(0.9, 0.8, 120, since: nil))
    }

    @Test func aFullMatchCostsAQuarterOfConditionAtAverageStamina() throws {
        #expect(abs(try match(fitness(), .midfielderCentral).condition - 0.75) < 1e-9)
        #expect(try match(fitness(), .midfielderCentral).daysSinceMatch == 0)
    }

    @Test func staminaChangesTheCost() throws {
        #expect(abs(try match(fitness(), .midfielderCentral, stamina: 20).condition - 0.7875) < 1e-9)
        #expect(abs(try match(fitness(), .midfielderCentral, stamina: 1).condition - 0.71625) < 1e-9)
    }

    @Test func positionChangesTheCost() throws {
        #expect(abs(try match(fitness(), .defenderLeft).condition - 0.70) < 1e-9)
        #expect(abs(try match(fitness(), .goalkeeper).condition - 0.95) < 1e-9)
        #expect(abs(try match(fitness(), .defenderCentral).condition - 0.80) < 1e-9)
    }

    @Test func conditionNeverGoesBelowZero() throws {
        #expect(try match(fitness(0.10), .defenderLeft).condition == 0)
    }

    @Test func aMatchRaisesSharpnessLessWhenAlreadySharp() throws {
        #expect(abs(try match(fitness(1, 0.50), .striker).sharpness - 0.59) < 1e-9)
        #expect(abs(try match(fitness(1, 0.80), .striker).sharpness - (0.80 + 0.09 * 0.667)) < 1e-9)
        #expect(try match(fitness(1, 0.99), .striker).sharpness == 1.0)
    }

    @Test func aMatchAddsJadedness() throws {
        #expect(abs(try match(fitness(1, 1, -500), .striker).jadedness - (-440)) < 1e-9)
    }

    @Test func aDayOfRestRecoversConditionAlongTheCurve() throws {
        let one = try rest(1, fitness(0.75))
        #expect(abs(one.condition - (0.75 + (0.124 + 0.0813) / 2)) < 1e-9)
        #expect(abs(try rest(2, fitness(0.75)).condition - 0.9056) < 1e-4)
        let seven = try rest(7, fitness(0.75)).condition
        #expect(seven > 0.97 && seven < 1.0)
    }

    @Test func naturalFitnessAndTrainingIntensityScaleRecovery() throws {
        let base = try rest(1, fitness(0.75)).condition - 0.75
        #expect(abs((try rest(1, fitness(0.75), nf: 20).condition - 0.75) / base - 1.167) < 1e-9)
        #expect(abs((try rest(1, fitness(0.75), .low).condition - 0.75) / base - 1.2) < 1e-9)
        #expect(abs((try rest(1, fitness(0.75), .high).condition - 0.75) / base - 0.8) < 1e-9)
        // Below 10 the term is a reduction.
        #expect(abs((try rest(1, fitness(0.75), nf: 1).condition - 0.75) / base - (1 - 9 * 0.0167)) < 1e-9)
    }

    @Test func recoveryStopsAtFull() throws {
        var f = fitness(0.999)
        for _ in 0..<10 {
            let next = try rest(1, f)
            #expect(next.condition <= 1.0 && next.condition >= f.condition)
            f = next
        }
    }

    @Test func sharpnessDecaysHalfAPointADayButNotTheDayAfterAMatch() throws {
        #expect(abs(try rest(4, fitness(1, 0.80)).sharpness - 0.78) < 1e-9)
        #expect(abs(try rest(4, fitness(1, 0.80, since: 0)).sharpness - 0.785) < 1e-9)
    }

    @Test func naturalFitnessSlowsSharpnessDecay() throws {
        #expect(abs(try rest(10, fitness(1, 0.80), nf: 20).sharpness - 0.79) < 1e-9)
    }

    @Test func sharpnessStopsAtItsFloorAndALowerValueIsLeftAlone() throws {
        #expect(abs(try rest(10, fitness(1, 0.36)).sharpness - 0.35) < 1e-9)
        #expect(try rest(10, fitness(1, 0.30)).sharpness == 0.30)
    }

    @Test func jadednessRecoversToItsFloor() throws {
        #expect(abs(try rest(3, fitness(1, 1, 0)).jadedness - (-60)) < 1e-9)
        #expect(try rest(3, fitness(1, 1, -490)).jadedness == -500)
        #expect(abs(try rest(1, fitness(1, 1, 0), .high).jadedness - (-16)) < 1e-9)
    }

    @Test func daysSinceMatchCountsUpOnlyWhenSet() throws {
        #expect(try rest(3, fitness(since: 2)).daysSinceMatch == 5)
        #expect(try rest(3, fitness(since: nil)).daysSinceMatch == nil)
    }

    @Test func zeroDaysChangesNothing() throws {
        let f = fitness(0.7, 0.6, 100, since: 3)
        #expect(try rest(0, f) == f)
    }

    @Test func valuesStayInRangeOverALongRun() throws {
        var f = fitness(1, 0.5, -500)
        for _ in 0..<30 {
            f = try match(f, .defenderLeft, stamina: 1)
            f = try rest(1, f, nf: 1, .high)
            #expect((0...1).contains(f.condition))
            #expect(f.sharpness >= 0.35 && f.sharpness <= 1)
            #expect(f.jadedness >= -500)
        }
    }

    @Test func aMissingStaminaIsAnErrorThatNamesThePlayer() {
        var player = Player.fixture(name: "No Stamina")
        player.attributes[.stamina] = nil
        #expect(throws: RatingError.missingAttribute(player: "No Stamina", attribute: .stamina)) {
            try FitnessProjection.afterMatch(fitness(), player: player, position: .striker, parameters: p)
        }
    }

    @Test func aMissingNaturalFitnessIsAnErrorThatNamesThePlayer() {
        var player = Player.fixture(name: "No NF")
        player.attributes[.naturalFitness] = nil
        #expect(throws: RatingError.missingAttribute(player: "No NF", attribute: .naturalFitness)) {
            try FitnessProjection.afterDays(1, fitness(), player: player, intensity: .medium, parameters: p)
        }
    }
}
