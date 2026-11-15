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

    @Test func growthFallsLaterOnlyWhenALaterSeasonsStepIsLower() throws {
        // 18 a season to 18, 14 to 20, 12 to 26: a later season grows less up to 20, the same from 21 on.
        for age in [16, 18, 19, 20] {
            #expect(try estimate(age: age).growthFallsLater, "age \(age)")
        }
        for age in [21, 23, 25, 26, 27] {
            #expect(try !estimate(age: age).growthFallsLater, "age \(age)")
        }
        // The cap at his potential is not a fall in his growth: at 21, a season from his potential, it still does not.
        #expect(try !estimate(age: 21, ability: 130, potential: 135).growthFallsLater)
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

    /// The working for a 19-year-old of ability 60 and potential 190, who falls short of his potential.
    private func working(professionalism: Int = 15, ambition: Int = 10, determination: Int = 10,
                         parameters: EngineParameters? = nil) throws -> String {
        let player = Player.fixture(
            age: 19, attributes: [.professionalism: professionalism, .ambition: ambition, .determination: determination],
            currentAbility: 60, potentialAbility: 190)
        return AdvisorText.reachWorking(try Reach.estimate(for: player, parameters: parameters ?? self.parameters))
    }

    @Test func aProfessionalismUnderTheLineIsSaidToHoldHimBack() throws {
        let mentoring = "mentoring could change that."
        #expect(try estimate(professionalism: 9).professionalismHoldsBack)
        #expect(try !estimate(professionalism: 10).professionalismHoldsBack)
        #expect(try working(professionalism: 9).hasSuffix(mentoring))
        #expect(try !working(professionalism: 10).hasSuffix(mentoring))
        // The line is the parameter's.
        var q = parameters
        q.professionalismHoldsBackBelow = Parameter(12, .derived, source: "test")
        #expect(try working(professionalism: 11, parameters: q).hasSuffix(mentoring))
        #expect(try !working(professionalism: 12, parameters: q).hasSuffix(mentoring))
    }

    @Test func anAmbitionOrDeterminationThatSlowsGrowthIsNamed() throws {
        #expect(try estimate(ambition: 9).ambitionSlows && !estimate(ambition: 10).ambitionSlows)
        #expect(try estimate(determination: 9).determinationSlows && !estimate(determination: 10).determinationSlows)
        #expect(try working(ambition: 9).contains("with Professionalism 15 and Ambition 9 this tool"))
        #expect(try working(ambition: 10).contains("with Professionalism 15 this tool"))
        #expect(try working(determination: 9).contains("with Professionalism 15 and Determination 9 this tool"))
        // From `growthPersonalityFullFrom`.
        var q = parameters
        q.growthPersonalityFullFrom = Parameter(12, .derived, source: "test")
        #expect(try working(ambition: 11, determination: 12, parameters: q).contains("and Ambition 11 this tool"))
        #expect(try working(ambition: 12, determination: 12, parameters: q).contains("with Professionalism 15 this tool"))
    }
}
