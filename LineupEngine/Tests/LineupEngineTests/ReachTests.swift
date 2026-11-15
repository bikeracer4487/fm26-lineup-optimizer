import Testing
@testable import LineupEngine

@Suite struct ReachTests {
    let parameters = EngineParameters.fm27

    private func estimate(
        age: Int = 16, professionalism: Int = 20, ambition: Int = 10, determination: Int = 10,
        ability: Int = 55, potential: Int = 140
    ) throws -> ReachEstimate {
        let player = Player.fixture(
            age: age,
            attributes: [.professionalism: professionalism, .ambition: ambition, .determination: determination],
            currentAbility: ability, potentialAbility: potential)
        return try Reach.estimate(for: player, parameters: parameters)
    }

    @Test func theDesignsFirstWorkedPlayerReachesHisPotential() throws {
        let result = try estimate(age: 16, professionalism: 15, ability: 55, potential: 140)
        #expect(abs(result.seasonGrowth - 13.3) <= 0.05)
        #expect(result.reach == 140)
        #expect(result.reachesPotential)
        #expect(result.bySeason.count == 12)
        #expect(result.bySeason.first == 55)
    }

    @Test func theDesignsSecondWorkedPlayerReachesAboutHalf() throws {
        let result = try estimate(age: 16, professionalism: 3, ambition: 4, determination: 10, ability: 40, potential: 130)
        #expect(abs(result.reach - 67) <= 0.6)
        #expect(!result.reachesPotential)
    }

    @Test func eachAgeStepIsUsedAtAndBesideItsBoundary() throws {
        for (age, points) in [(18, 18.0), (19, 14), (20, 14), (21, 12), (26, 12)] {
            let result = try estimate(age: age)
            #expect(abs(result.seasonGrowth - points) < 1e-9, "age \(age)")
            #expect(abs(result.bySeason[1] - (55 + points)) < 1e-9, "age \(age)")
        }
        let old = try estimate(age: 27)
        #expect(old.seasonGrowth == 0)
        #expect(old.bySeason == [55])
        #expect(try estimate(age: 26).bySeason.count == 2)
    }

    @Test func professionalismIsReadOffStraightLines() throws {
        let rates: [Int: Double] = [1: 2.4, 5: 2.4 + 5.8 * 4 / 9, 10: 8.2, 15: 12.6, 20: 17]
        for (level, rate) in rates {
            let result = try estimate(age: 21, professionalism: level)
            #expect(abs(result.seasonGrowth - 12 * rate / 17) < 1e-9, "Professionalism \(level)")
        }
    }

    @Test func ambitionAndDeterminationCountOnlyBelowTen() throws {
        let share: [Int: Double] = [1: 0.731, 5: 0.731 + 0.269 * 4 / 9, 10: 1, 15: 1]
        for (level, expected) in share {
            let ambition = try estimate(age: 21, ambition: level)
            #expect(abs(ambition.seasonGrowth - 12 * expected) < 1e-9, "Ambition \(level)")
        }
        let shareDetermination: [Int: Double] = [1: 0.66, 5: 0.66 + 0.34 * 4 / 9, 10: 1, 15: 1]
        for (level, expected) in shareDetermination {
            let determination = try estimate(age: 21, determination: level)
            #expect(abs(determination.seasonGrowth - 12 * expected) < 1e-9, "Determination \(level)")
        }
    }

    @Test func aFactorOfOneChangesNothing() throws {
        let best = try estimate(age: 21, professionalism: 20, ambition: 10, determination: 10)
        let higher = try estimate(age: 21, professionalism: 20, ambition: 20, determination: 20)
        #expect(best.seasonGrowth == 12)
        #expect(best.bySeason == higher.bySeason)
    }

    @Test func reachIsNeverAbovePotentialNorBelowToday() throws {
        let below = try estimate(age: 18, ability: 120, potential: 100)
        #expect(below.bySeason.allSatisfy { $0 == 120 })
        #expect(!below.reachesPotential)
        let equal = try estimate(age: 18, ability: 100, potential: 100)
        #expect(equal.bySeason.allSatisfy { $0 == 100 })
        #expect(!equal.reachesPotential)
        let nothing = try estimate(age: 18, ability: 0, potential: 100)
        #expect(nothing.reach.isFinite)
        #expect(nothing.reach > 0 && nothing.reach <= 100)
        let capped = try estimate(age: 18, ability: 95, potential: 100)
        #expect(capped.bySeason.allSatisfy { $0 <= 100 })
        #expect(capped.reachesPotential)
    }

    @Test func aMissingPersonalityAttributeIsAnErrorNamingHim() {
        for attribute in [Attribute.professionalism, .ambition, .determination] {
            var player = Player.fixture(name: "Young Lad", age: 17)
            player.attributes[attribute] = nil
            do {
                _ = try Reach.estimate(for: player, parameters: parameters)
                Issue.record("expected an error for \(attribute.rawValue)")
            } catch let RatingError.missingAttribute(name, missing) {
                #expect(name == "Young Lad")
                #expect(missing == attribute)
            } catch {
                Issue.record("wrong error \(error)")
            }
        }
    }
}
