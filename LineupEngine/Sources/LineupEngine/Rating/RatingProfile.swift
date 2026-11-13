import Foundation

/// How a role's key and preferable attributes combine into the role score.
public enum RoleScoreRule: Sendable, Equatable {
    /// Weighted mean over the union of key and preferable attributes (the carried-over rule).
    case weightedUnion(keyWeight: Double, preferableWeight: Double)
    /// Mean of the key attributes, with the preferable attributes' mean blended in at `preferableShare`.
    case keyWithPreferableTieBreak(preferableShare: Double)
}

/// One complete set of rating weights: the tables, how each attribute is scaled, and how the scores blend.
/// The engine takes a profile explicitly; there is no default.
public struct RatingProfile: Sendable {
    public let id: String
    public let name: String
    public let tables: RatingTables
    /// Attribute value 1...20 to 0...1, one point per whole value; no entry means the straight line (v - 1) / 19.
    public let curves: [Attribute: [CurvePoint]]
    public let positionShare: Parameter<Double>
    public let roleShare: Parameter<Double>
    public let consensusShare: Parameter<Double>
    public let roleScoreRule: Parameter<RoleScoreRule>
    /// The evidence label and source of every table and number in the profile.
    public let evidence: [(name: String, evidence: Evidence, source: String)]

    /// The attribute value on the profile's 0...1 scale: its curve, interpolated between whole-number points,
    /// or the straight line (v - 1) / 19.
    public func scaled(_ value: Int, for attribute: Attribute) -> Double {
        guard let curve = curves[attribute] else { return (Double(value) - 1) / 19 }
        return FitnessModel.evaluate(curve, at: Double(value))
    }

    /// The attribute value as rated at `position`. The curves were measured on outfield players only, so a player
    /// rated at the goalkeeper position is rated without them: every attribute on the straight line (v - 1) / 19,
    /// under every profile. Outfield positions use `scaled(_:for:)`.
    public func scaled(_ value: Int, for attribute: Attribute, at position: Position) -> Double {
        position == .goalkeeper ? (Double(value) - 1) / 19 : scaled(value, for: attribute)
    }

    /// Both profiles, carried over first.
    public static func all() throws -> [RatingProfile] {
        let carried = try carriedOver()
        return [carried, try fm27EngineTests(carriedOver: carried)]
    }

    // MARK: - Carried over from FM26

    private static let pythonSource = "rating_calculator.py (branch customizable-tactics)"

    /// Today's rating exactly, from `rating_tables.json`: straight-line scaling, shares 0.60, 0.35 and 0.05,
    /// and the weighted union of key and preferable attributes.
    public static func carriedOver() throws -> RatingProfile {
        func carried<V>(_ value: V, _ source: String = pythonSource) -> Parameter<V> { Parameter(value, .carriedOverFM26, source: source) }
        let positionShare = carried(0.60), roleShare = carried(0.35), consensusShare = carried(0.05)
        let rule = carried(RoleScoreRule.weightedUnion(keyWeight: 1.5, preferableWeight: 1.2),
                           "rating_calculator.py calculate_role_score, key attributes ×1.5 and preferable ×1.2 (branch customizable-tactics)")
        let tables: [(name: String, evidence: Evidence, source: String)] = [
            ("positionWeights", .carriedOverFM26,
             "rating_calculator.py POSITION_WEIGHTS (branch customizable-tactics), from FM26 engine testing"),
            ("consensusBonuses", .carriedOverFM26,
             "rating_calculator.py CONSENSUS_BONUSES (branch customizable-tactics)"),
            ("thresholds", .carriedOverFM26,
             "rating_calculator.py THRESHOLDS (branch customizable-tactics); the Python notes they are tuned for elite players "
                + "in top leagues and can be too harsh for lower-league squads; applied only in the FM26 reference configuration"),
        ]
        return RatingProfile(
            id: "carried-over", name: "Carried over from FM26", tables: try RatingTables.bundled(), curves: [:],
            positionShare: positionShare, roleShare: roleShare, consensusShare: consensusShare, roleScoreRule: rule,
            evidence: tables + entries(positionShare, roleShare, consensusShare, rule))
    }

    // MARK: - FM27 engine tests

    private static let research = "docs/Research/fm27-attribute-weights-and-role-thresholds.md"

    /// Weights and curves from FM27 engine tests, built from `rating_profile_fm27.json`.
    public static func fm27EngineTests() throws -> RatingProfile {
        try fm27EngineTests(carriedOver: carriedOver())
    }

    private static func fm27EngineTests(carriedOver: RatingProfile) throws -> RatingProfile {
        guard let url = Bundle.module.url(forResource: "rating_profile_fm27", withExtension: "json") else {
            throw CatalogError.malformed(reason: "rating_profile_fm27.json is missing from the bundle")
        }
        return try fm27EngineTests(json: Data(contentsOf: url), carriedOver: carriedOver)
    }

    /// Builds the FM27 profile from the resource's numbers; the goalkeeper table comes from `carriedOver`.
    static func fm27EngineTests(json: Data, carriedOver: RatingProfile) throws -> RatingProfile {
        struct File: Decodable {
            struct Goalkeeper: Decodable { let carriedOverTableWithout: [String] }
            let outfieldBaseWeights: [String: Double]
            let curveSlopesPerPoint: [String: [Double]]
            let curveBands: [[Int]]
            let positionMultipliers: [String: [String: Double]]
            let goalkeeper: Goalkeeper
        }
        let file: File
        do { file = try JSONDecoder().decode(File.self, from: json) } catch let error as DecodingError {
            throw CatalogError.malformed(reason: "the FM27 rating profile cannot be read: \(ErrorDescriptions.describe(error))")
        }

        let base = try attributes(file.outfieldBaseWeights, in: "outfieldBaseWeights")
        if let negative = inFixedOrder(base).first(where: { $0.value < 0 }) {
            throw CatalogError.malformed(reason: "the FM27 rating profile gives \(negative.key.rawValue) a negative base weight")
        }
        var multipliers: [Position: [Attribute: Double]] = [:]
        for (code, table) in file.positionMultipliers.sorted(by: { $0.key < $1.key }) {
            guard let position = Position(rawValue: code), position != .goalkeeper else {
                throw CatalogError.malformed(reason: "the FM27 rating profile has a multiplier for an unknown position, \(code)")
            }
            let factors = try attributes(table, in: "positionMultipliers \(code)")
            // A multiplier of 0 is legal: it drops the attribute at that position.
            for (attribute, factor) in inFixedOrder(factors) {
                guard base[attribute] != nil else {
                    throw CatalogError.malformed(reason: "the FM27 rating profile has a \(code) multiplier for \(attribute.rawValue), "
                                                     + "which has no outfield base weight")
                }
                guard factor >= 0 else {
                    throw CatalogError.malformed(reason: "the FM27 rating profile gives \(attribute.rawValue) a negative multiplier at \(code)")
                }
            }
            multipliers[position] = factors
        }

        var weights: [Position: [Attribute: Double]] = [:]
        for position in Position.allCases where position != .goalkeeper {
            let factors = multipliers[position] ?? [:]
            let scaled = inFixedOrder(base).compactMap { attribute, weight -> (Attribute, Double)? in
                let w = weight * (factors[attribute] ?? 1)
                return w > 0 ? (attribute, w) : nil
            }
            weights[position] = try normalised(scaled, for: position)
        }
        let dropped = try Set(file.goalkeeper.carriedOverTableWithout.map { name in
            guard let attribute = Attribute(catalogName: name) else {
                throw unknownAttribute(name, in: "goalkeeper")
            }
            return attribute
        })
        let carriedGK = carriedOver.tables.positionWeights[.goalkeeper] ?? [:]
        weights[.goalkeeper] = try normalised(inFixedOrder(carriedGK).filter { !dropped.contains($0.key) }.map { ($0.key, $0.value) },
                                              for: .goalkeeper)

        let curves = try curves(slopes: attributes(file.curveSlopesPerPoint, in: "curveSlopesPerPoint"), bands: file.curveBands)

        func derived<V>(_ value: V, _ source: String) -> Parameter<V> { Parameter(value, .derived, source: "\(research), \(source)") }
        let positionShare = derived(0.70, "recommendation C (about 70% engine-weighted position score)")
        let roleShare = derived(0.30, "recommendation C (about 30% role score from key attributes)")
        let consensusShare = derived(0.0, "recommendation C folds the 5% consensus bonus into the role score")
        let rule = derived(RoleScoreRule.keyWithPreferableTieBreak(preferableShare: 0.05),
                            "recommendation C: key attributes only, preferable attributes at most a 5% tie-breaker, "
                                + "following FM27Manager's match with the game's role stars")
        let harvest = "harvestgreen22's FM27 attribute test (Launch Preview build, about 51,000 matches) as tabulated in "
            + "FM-Player-Analyzer issue 17, cross-checked against Fm-Match-Lab"
        let tables: [(name: String, evidence: Evidence, source: String)] = [
            ("outfieldBaseWeights", .fm27Measured, "\(harvest); \(research), recommendation D (zero weights omitted)"),
            ("curveSlopes", .fm27Measured,
             "\(harvest); the per-band table was derived by a third party from harvestgreen22's data and its standard error "
                + "is two to three points per band; \(research), section 2 and recommendation D; the optional 1.5 to 2 times "
                + "uplift for Anticipation and Concentration is not applied"),
            ("positionMultipliers", .derived, "\(research), recommendation D; the research labels them speculative (untested)"),
            ("goalkeeperWeights", .carriedOverFM26,
             "rating_calculator.py POSITION_WEIGHTS GK (branch customizable-tactics) without Kicking, renormalised; \(research), "
                + "recommendation D (no FM27 goalkeeper data; Fm-Match-Lab found Kicking slightly negative)"),
        ]
        return RatingProfile(
            id: "fm27-engine-tests", name: "FM27 engine tests",
            tables: RatingTables(positionWeights: weights, consensusBonuses: [:], thresholds: [:]), curves: curves,
            positionShare: positionShare, roleShare: roleShare, consensusShare: consensusShare, roleScoreRule: rule,
            evidence: tables + entries(positionShare, roleShare, consensusShare, rule))
    }

    /// The cumulative curve for each attribute with slopes: per-point slopes within each band, the last band's slope
    /// continued to 20, divided by the value at 20 so the curve runs from 0 at 1 to 1 at 20.
    private static func curves(slopes: [Attribute: [Double]], bands: [[Int]]) throws -> [Attribute: [CurvePoint]] {
        guard !bands.isEmpty else { throw CatalogError.malformed(reason: "the FM27 rating profile has no curve bands") }
        var start = 1
        for band in bands {
            guard band.count == 2, band[0] == start, band[1] > band[0], band[1] <= 20 else {
                throw CatalogError.malformed(reason: "the FM27 rating profile's curve bands must run on from 1 without gaps")
            }
            start = band[1]
        }

        var curves: [Attribute: [CurvePoint]] = [:]
        for (attribute, perPoint) in inFixedOrder(slopes) {
            guard perPoint.count == bands.count else {
                throw CatalogError.malformed(
                    reason: "the FM27 rating profile gives \(attribute.rawValue) \(perPoint.count) slopes for \(bands.count) bands")
            }
            guard perPoint.allSatisfy({ $0 >= 0 }) else {
                throw CatalogError.malformed(reason: "the FM27 rating profile gives \(attribute.rawValue) a negative slope")
            }
            guard perPoint.contains(where: { $0 > 0 }) else { continue }
            var cumulative = [0.0]   // at 1
            for v in 2...20 {
                // The band holding the step from v - 1 to v; past the last band, the last band's slope.
                let band = bands.firstIndex { $0[0] <= v - 1 && v <= $0[1] } ?? bands.count - 1
                cumulative.append(cumulative[cumulative.count - 1] + perPoint[band])
            }
            let top = cumulative[cumulative.count - 1]
            curves[attribute] = cumulative.enumerated().map { CurvePoint(x: Double($0.offset + 1), factor: $0.element / top) }
        }
        return curves
    }

    // MARK: - Helpers

    private static func attributes<V>(_ table: [String: V], in owner: String) throws -> [Attribute: V] {
        var result: [Attribute: V] = [:]
        for (name, value) in table.sorted(by: { $0.key < $1.key }) {
            guard let attribute = Attribute(catalogName: name) else {
                throw unknownAttribute(name, in: owner)
            }
            result[attribute] = value
        }
        return result
    }

    /// Names the resource and the section, so the sentence does not read as though a role were at fault.
    private static func unknownAttribute(_ name: String, in section: String) -> CatalogError {
        .malformed(reason: "rating_profile_fm27.json names an attribute the engine does not know in \(section): \(name)")
    }

    /// Divides each weight by the total, summed in the order given (a fixed order, so the result is reproducible).
    private static func normalised(_ weights: [(Attribute, Double)], for position: Position) throws -> [Attribute: Double] {
        let total = weights.reduce(0) { $0 + $1.1 }
        guard total > 0 else {
            throw CatalogError.malformed(reason: "the FM27 rating profile leaves no weights for \(position.rawValue)")
        }
        return Dictionary(uniqueKeysWithValues: weights.map { ($0.0, $0.1 / total) })
    }

    private static func inFixedOrder<V>(_ table: [Attribute: V]) -> [(key: Attribute, value: V)] {
        table.sorted { $0.key.rawValue < $1.key.rawValue }
    }

    private static func entries(_ positionShare: Parameter<Double>, _ roleShare: Parameter<Double>,
                                _ consensusShare: Parameter<Double>, _ rule: Parameter<RoleScoreRule>)
        -> [(name: String, evidence: Evidence, source: String)] {
        [("positionShare", positionShare.evidence, positionShare.source),
         ("roleShare", roleShare.evidence, roleShare.source),
         ("consensusShare", consensusShare.evidence, consensusShare.source),
         ("roleScoreRule", rule.evidence, rule.source)]
    }
}
