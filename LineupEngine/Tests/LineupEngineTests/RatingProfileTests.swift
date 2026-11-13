import Foundation
import Testing
@testable import LineupEngine

@Suite struct RatingProfileTests {
    let carried = try! RatingProfile.carriedOver()
    let fm27 = try! RatingProfile.fm27EngineTests()

    @Test func bothProfilesLoadAndAreListedCarriedOverFirst() throws {
        let all = try RatingProfile.all()
        #expect(all.count == 2)
        #expect(all.map(\.id) == ["carried-over", "fm27-engine-tests"])
        #expect(all.map(\.name) == ["Carried over from FM26", "FM27 engine tests"])
    }

    @Test func fm27PositionWeightsSumToOneForAllFourteenPositions() {
        #expect(fm27.tables.positionWeights.count == 14)
        for position in Position.allCases {
            let weights = fm27.tables.positionWeights[position] ?? [:]
            #expect(!weights.isEmpty, "\(position.rawValue)")
            #expect(abs(weights.values.reduce(0, +) - 1) < 1e-9, "\(position.rawValue)")
            #expect(weights.values.allSatisfy { $0 > 0 }, "\(position.rawValue)")
        }
    }

    @Test func fm27StrikerWeightsFinishingTwiceAsHeavilyAsItsBaseShare() throws {
        let st = try #require(fm27.tables.positionWeights[.striker])
        let finishing = try #require(st[.finishing]), pace = try #require(st[.pace])
        #expect(abs(finishing / pace - (0.0281 * 2.0) / 0.1668) < 1e-9)
        let dc = try #require(fm27.tables.positionWeights[.defenderCentral])
        #expect(dc[.finishing] == nil && dc[.longShots] == nil)
        // An attribute the research weighs at 0 appears in no outfield table.
        for position in Position.allCases where position != .goalkeeper {
            #expect(fm27.tables.positionWeights[position]?[.passing] == nil, "\(position.rawValue)")
            #expect(fm27.tables.positionWeights[position]?[.tackling] == nil, "\(position.rawValue)")
        }
    }

    @Test func fm27GoalkeeperWeightsDropKicking() throws {
        let gk = try #require(fm27.tables.positionWeights[.goalkeeper])
        let carriedGK = try #require(carried.tables.positionWeights[.goalkeeper])
        #expect(gk[.kicking] == nil)
        #expect(carriedGK[.kicking] != nil)
        #expect(Set(gk.keys) == Set(carriedGK.keys).subtracting([.kicking]))
        let agility = try #require(gk[.agility]), reflexes = try #require(gk[.reflexes])
        #expect(abs(agility / reflexes - 0.140 / 0.130) < 1e-9)
        for (attribute, weight) in gk {
            #expect(abs(weight / agility - carriedGK[attribute]! / carriedGK[.agility]!) < 1e-9, "\(attribute.rawValue)")
        }
    }

    @Test func curvesRunFromZeroAtOneToOneAtTwenty() {
        #expect(fm27.curves.count == 16)
        for (attribute, _) in fm27.curves {
            #expect(abs(fm27.scaled(1, for: attribute)) < 1e-9, "\(attribute.rawValue)")
            #expect(abs(fm27.scaled(20, for: attribute) - 1) < 1e-9, "\(attribute.rawValue)")
            for v in 1..<20 {
                #expect(fm27.scaled(v + 1, for: attribute) >= fm27.scaled(v, for: attribute), "\(attribute.rawValue) \(v)")
            }
        }
    }

    @Test func paceIsSteepestInTheMiddleBand() {
        func step(_ v: Int) -> Double { fm27.scaled(v + 1, for: .pace) - fm27.scaled(v, for: .pace) }
        #expect(step(8) > step(15))
        #expect(step(8) > step(3))
    }

    @Test func workRateIsFlatAboveTwelve() {
        let s = { (v: Int) in fm27.scaled(v, for: .workRate) }
        #expect(s(12) == s(18) && s(18) == s(20))
        // The slopes 3.16, 1.03 and 0 per point put 15.8 of the 21.98 total below 6: about 0.72.
        #expect(s(6) > 0.7)
        #expect(abs(s(6) - 15.8 / 21.98) < 1e-9)
    }

    @Test func anAttributeWithoutACurveIsLinear() {
        for v in 1...20 {
            #expect(abs(fm27.scaled(v, for: .passing) - Double(v - 1) / 19) < 1e-12)
            #expect(carried.scaled(v, for: .pace) == (Double(v) - 1) / 19)
        }
        #expect(carried.curves.isEmpty)
        #expect(fm27.curves[.passing] == nil)
    }

    @Test func everyProfileNumberHasEvidenceAndASource() {
        for profile in [carried, fm27] {
            #expect(!profile.evidence.isEmpty, "\(profile.id)")
            #expect(profile.evidence.allSatisfy { !$0.source.isEmpty }, "\(profile.id)")
            #expect(Set(profile.evidence.map(\.name)).count == profile.evidence.count, "\(profile.id)")
            for name in ["positionShare", "roleShare", "consensusShare", "roleScoreRule"] {
                #expect(profile.evidence.contains { $0.name == name }, "\(profile.id) \(name)")
            }
        }
        #expect(fm27.evidence.contains { $0.evidence == .fm27Measured })
        #expect(fm27.evidence.contains { $0.evidence == .derived })
        #expect(fm27.evidence.allSatisfy { $0.source.contains("docs/Research/fm27-attribute-weights-and-role-thresholds.md") })
        #expect(carried.evidence.allSatisfy { $0.evidence == .carriedOverFM26 })
    }

    @Test func theCarriedOverProfileKeepsTodaysNumbers() throws {
        #expect(carried.positionShare.value == 0.60 && carried.roleShare.value == 0.35 && carried.consensusShare.value == 0.05)
        #expect(carried.roleScoreRule.value == .weightedUnion(keyWeight: 1.5, preferableWeight: 1.2))
        let bundled = try RatingTables.bundled()
        #expect(carried.tables.positionWeights == bundled.positionWeights)
        #expect(carried.tables.consensusBonuses == bundled.consensusBonuses)
        #expect(carried.tables.thresholds == bundled.thresholds)
    }

    @Test func theCarriedOverTablesCiteThePython() throws {
        let entries = carried.evidence.filter { ["positionWeights", "consensusBonuses", "thresholds"].contains($0.name) }
        #expect(entries.map(\.name) == ["positionWeights", "consensusBonuses", "thresholds"])
        for (entry, table) in zip(entries, ["POSITION_WEIGHTS", "CONSENSUS_BONUSES", "THRESHOLDS"]) {
            #expect(entry.source.contains("rating_calculator.py") && entry.source.contains(table), "\(entry.name): \(entry.source)")
        }
        let thresholds = try #require(entries.first { $0.name == "thresholds" })
        #expect(thresholds.source.contains("elite"))
    }

    @Test func theFM27ProfileHasItsSharesAndNoBonusesOrThresholds() {
        #expect(fm27.positionShare.value == 0.70 && fm27.roleShare.value == 0.30 && fm27.consensusShare.value == 0)
        #expect(fm27.roleScoreRule.value == .keyWithPreferableTieBreak(preferableShare: 0.05))
        #expect(fm27.tables.consensusBonuses.isEmpty)
        #expect(fm27.tables.thresholds.isEmpty)
        let curveSource = fm27.evidence.first { $0.name == "curveSlopes" }?.source ?? ""
        #expect(curveSource.contains("third party") && curveSource.contains("standard error"))
        #expect(fm27.evidence.first { $0.name == "positionMultipliers" }?.evidence == .derived)
        #expect(fm27.evidence.first { $0.name == "goalkeeperWeights" }?.evidence == .carriedOverFM26)
    }

    // MARK: - A damaged resource fails to load and says why

    /// The library's `rating_profile_fm27.json` as a JSON object.
    private func bundledObject() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/LineupEngine/Resources/rating_profile_fm27.json")
        return try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func load(_ object: [String: Any]) throws -> RatingProfile {
        try RatingProfile.fm27EngineTests(json: JSONSerialization.data(withJSONObject: object), carriedOver: carried)
    }

    @Test func theBundledResourceLoadsThroughTheSamePath() throws {
        let loaded = try load(try bundledObject())
        #expect(loaded.tables.positionWeights == fm27.tables.positionWeights)
        #expect(loaded.curves == fm27.curves)
    }

    @Test func anUnknownAttributeFailsToLoadAndNamesIt() throws {
        var object = try bundledObject()
        var base = try #require(object["outfieldBaseWeights"] as? [String: Double])
        base["JumpingReach"] = 0.1
        object["outfieldBaseWeights"] = base
        let expected = CatalogError.malformed(
            reason: "rating_profile_fm27.json names an attribute the engine does not know in outfieldBaseWeights: JumpingReach")
        #expect(throws: expected) { try load(object) }
        #expect(ErrorDescriptions.describe(expected) == "The role or rating data is damaged: rating_profile_fm27.json names an "
            + "attribute the engine does not know in outfieldBaseWeights: JumpingReach")
    }

    @Test func aNegativeMultiplierFailsToLoad() throws {
        var object = try bundledObject()
        var multipliers = try #require(object["positionMultipliers"] as? [String: [String: Double]])
        multipliers["DM"]?["Heading"] = -0.5
        object["positionMultipliers"] = multipliers
        #expect(throws: CatalogError.malformed(reason: "the FM27 rating profile gives Heading a negative multiplier at DM")) {
            try load(object)
        }
    }

    @Test func aMultiplierForAnAttributeWithNoBaseWeightFailsToLoad() throws {
        var object = try bundledObject()
        var multipliers = try #require(object["positionMultipliers"] as? [String: [String: Double]])
        multipliers["ST (C)"]?["Passing"] = 1.5
        object["positionMultipliers"] = multipliers
        #expect(throws: CatalogError.malformed(
            reason: "the FM27 rating profile has a ST (C) multiplier for Passing, which has no outfield base weight")) {
            try load(object)
        }
    }

    @Test func aMultiplierOfZeroDropsTheAttributeAtThatPositionOnly() throws {
        var object = try bundledObject()
        var multipliers = try #require(object["positionMultipliers"] as? [String: [String: Double]])
        multipliers["DM"]?["Pace"] = 0
        object["positionMultipliers"] = multipliers
        let loaded = try load(object)
        #expect(loaded.tables.positionWeights[.defensiveMidfielder]?[.pace] == nil)
        #expect(loaded.tables.positionWeights[.midfielderCentral]?[.pace] != nil)
        #expect(fm27.tables.positionWeights[.defensiveMidfielder]?[.pace] != nil)
    }

    @Test func goalkeepersAreScaledWithoutCurves() {
        for v in 1...20 {
            #expect(fm27.scaled(v, for: .agility, at: .goalkeeper) == (Double(v) - 1) / 19)
            #expect(fm27.scaled(v, for: .agility, at: .defenderCentral) == fm27.scaled(v, for: .agility))
        }
        #expect(fm27.scaled(9, for: .agility) != 8.0 / 19)
    }

    @Test func anUnknownPositionFailsToLoadAndNamesIt() throws {
        var object = try bundledObject()
        var multipliers = try #require(object["positionMultipliers"] as? [String: [String: Double]])
        multipliers["DC"] = ["Heading": 1.5]
        object["positionMultipliers"] = multipliers
        #expect(throws: CatalogError.malformed(reason: "the FM27 rating profile has a multiplier for an unknown position, DC")) {
            try load(object)
        }
    }

    @Test func aSlopeListThatDoesNotMatchTheBandsFailsToLoad() throws {
        var object = try bundledObject()
        var slopes = try #require(object["curveSlopesPerPoint"] as? [String: [Double]])
        slopes["Pace"] = [2.64, 4.47]
        object["curveSlopesPerPoint"] = slopes
        let expected = CatalogError.malformed(reason: "the FM27 rating profile gives Pace 2 slopes for 3 bands")
        #expect(throws: expected) { try load(object) }
        #expect(ErrorDescriptions.describe(expected)
            == "The role or rating data is damaged: the FM27 rating profile gives Pace 2 slopes for 3 bands")
    }

    @Test func aNegativeSlopeFailsToLoad() throws {
        var object = try bundledObject()
        var slopes = try #require(object["curveSlopesPerPoint"] as? [String: [Double]])
        slopes["Heading"] = [1.04, -0.27, 0]
        object["curveSlopesPerPoint"] = slopes
        #expect(throws: CatalogError.malformed(reason: "the FM27 rating profile gives Heading a negative slope")) {
            try load(object)
        }
    }

    @Test func bandsWithAGapFailToLoad() throws {
        var object = try bundledObject()
        object["curveBands"] = [[1, 6], [7, 12], [12, 18]]
        #expect(throws: CatalogError.malformed(reason: "the FM27 rating profile's curve bands must run on from 1 without gaps")) {
            try load(object)
        }
    }

    @Test func aMissingFieldFailsToLoadInPlainWords() throws {
        var object = try bundledObject()
        object["curveBands"] = nil
        do {
            _ = try load(object)
            Issue.record("expected a load failure")
        } catch let error as CatalogError {
            let text = ErrorDescriptions.describe(error)
            #expect(text == "The role or rating data is damaged: the FM27 rating profile cannot be read: missing the field 'curveBands'")
            #expect(text.contains("curveBands"))
            #expect(!text.contains("keyNotFound("))
        }
    }
}
