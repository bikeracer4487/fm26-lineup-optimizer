import Foundation
import Testing
@testable import LineupEngine

@Suite struct RatingProfileTests {
    let carried = try! RatingProfile.carriedOver()
    let fm27 = try! RatingProfile.fm27EngineTests()

    @Test func theStandardProfileIsTheFM27EngineTests() throws {
        let standard = try RatingProfile.standard()
        #expect(standard.id == "fm27-engine-tests")
        #expect(standard.tables.positionWeights == fm27.tables.positionWeights)
        let all = try RatingProfile.all()
        #expect(all.map(\.id) == ["fm27-engine-tests", "carried-over"])
        #expect(all.map(\.name) == ["FM27 engine tests", "Carried over from FM26"])
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

    @Test func positionalEmphasisFollowsTheFM26Tables() throws {
        // Each as a ratio to Natural Fitness, which FM26 weighs nowhere (multiplier 1), so normalising cancels.
        func ratio(_ attribute: Attribute, at position: Position) throws -> Double {
            let weights = try #require(fm27.tables.positionWeights[position])
            return try #require(weights[attribute]) / #require(weights[.naturalFitness])
        }
        // FM26: Finishing 0.100 for strikers against an average of 0.235 / 13, so r is capped at 2.
        #expect(abs(try ratio(.finishing, at: .striker) - (0.0281 * 1.5) / 0.0432) < 1e-9)
        // FM26 gives centre-backs no Finishing weight: r = 0.
        #expect(abs(try ratio(.finishing, at: .defenderCentral) - (0.0281 * 0.5) / 0.0432) < 1e-9)
        // r = 0.115 × 13 / 0.80 = 1.86875, under the cap.
        #expect(abs(try ratio(.jumpingReach, at: .defenderCentral) - (0.0938 * 1.434375) / 0.0432) < 1e-9)
        // An attribute the research weighs at 0 appears in no outfield table.
        for position in Position.allCases where position != .goalkeeper {
            #expect(fm27.tables.positionWeights[position]?[.passing] == nil, "\(position.rawValue)")
            #expect(fm27.tables.positionWeights[position]?[.tackling] == nil, "\(position.rawValue)")
        }
    }

    @Test func withAShareOfZeroEveryOutfieldPositionHasTheBaseTable() throws {
        let flat = try RatingProfile.fm27(positionalEmphasisShare: 0)
        let base = try #require(RatingProfile.fm27ResourceObject()["outfieldBaseWeights"] as? [String: Double])
        let total = base.sorted { $0.key < $1.key }.reduce(0) { $0 + $1.value }
        for position in Position.allCases where position != .goalkeeper {
            let weights = try #require(flat.tables.positionWeights[position])
            #expect(weights.count == base.count, "\(position.rawValue)")
            for (name, weight) in base {
                let attribute = try #require(Attribute(catalogName: name))
                #expect(abs((weights[attribute] ?? 0) - weight / total) < 1e-12, "\(position.rawValue) \(name)")
            }
        }
        // The emphasis is what differs: the standard profile's centre-back table is not the base table.
        #expect(flat.tables.positionWeights[.defenderCentral] != fm27.tables.positionWeights[.defenderCentral])
        #expect(flat.tables.positionWeights[.goalkeeper] == fm27.tables.positionWeights[.goalkeeper])
    }

    @Test func aShareOfOneDropsAnAttributeFM26DoesNotWeighAtAPosition() throws {
        let full = try RatingProfile.fm27(positionalEmphasisShare: 1)
        // FM26 gives centre-backs no Finishing weight, so with share 1 the multiplier is 0 and the weight is dropped.
        #expect(full.tables.positionWeights[.defenderCentral]?[.finishing] == nil)
        #expect(full.tables.positionWeights[.striker]?[.finishing] != nil)
        // At the standard share it stays, at half.
        #expect(fm27.tables.positionWeights[.defenderCentral]?[.finishing] != nil)
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
        #expect(fm27.evidence.contains { $0.name == "positionalEmphasis" && $0.evidence == .carriedOverFM26 })
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
        #expect(!fm27.evidence.contains { $0.name == "positionMultipliers" })
        let emphasis = fm27.evidence.first { $0.name == "positionalEmphasis" }
        #expect(emphasis?.evidence == .carriedOverFM26)
        #expect(emphasis?.source.contains("rating_tables.json") == true && emphasis?.source.contains("spec 8.4") == true)
        for name in ["positionalEmphasisShare", "positionalEmphasisCap"] {
            let entry = fm27.evidence.first { $0.name == name }
            #expect(entry?.evidence == .derived, "\(name)")
            #expect(entry?.source.contains("spec 8.4") == true, "\(name)")
        }
        #expect(fm27.evidence.first { $0.name == "goalkeeperWeights" }?.evidence == .carriedOverFM26)
    }

    // MARK: - A damaged resource fails to load and says why

    /// The library's `rating_profile_fm27.json` as a JSON object.
    private func bundledObject() throws -> [String: Any] {
        try RatingProfile.fm27ResourceObject()
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

    @Test(arguments: [("share", -0.1), ("share", 1.1), ("cap", 0.5)])
    func aBadPositionalEmphasisFailsToLoad(_ field: String, _ value: Double) throws {
        var object = try bundledObject()
        var emphasis = try #require(object["positionalEmphasis"] as? [String: Double])
        emphasis[field] = value
        object["positionalEmphasis"] = emphasis
        do {
            _ = try load(object)
            Issue.record("expected a load failure for \(field) \(value)")
        } catch let error as CatalogError {
            let text = ErrorDescriptions.describe(error)
            #expect(text.contains("positionalEmphasis"), "\(text)")
            #expect(text.contains(field), "\(text)")
        }
    }

    @Test func positionalEmphasisAtItsLimitsLoads() throws {
        var object = try bundledObject()
        object["positionalEmphasis"] = ["share": 1.0, "cap": 1.0]
        #expect(throws: Never.self) { try load(object) }
        object["positionalEmphasis"] = ["share": 0.0, "cap": 1.0]
        #expect(throws: Never.self) { try load(object) }
    }

    @Test func goalkeepersAreScaledWithoutCurves() {
        for v in 1...20 {
            #expect(fm27.scaled(v, for: .agility, at: .goalkeeper) == (Double(v) - 1) / 19)
            #expect(fm27.scaled(v, for: .agility, at: .defenderCentral) == fm27.scaled(v, for: .agility))
        }
        #expect(fm27.scaled(9, for: .agility) != 8.0 / 19)
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
