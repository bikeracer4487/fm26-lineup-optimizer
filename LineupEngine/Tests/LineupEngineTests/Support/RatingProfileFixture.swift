import Foundation
@testable import LineupEngine

extension RatingProfile {
    /// This profile with its tables replaced, for tests that need custom tables.
    func with(tables: RatingTables) -> RatingProfile {
        RatingProfile(id: id, name: name, tables: tables, curves: curves, positionShare: positionShare, roleShare: roleShare,
                      consensusShare: consensusShare, roleScoreRule: roleScoreRule, evidence: evidence)
    }

    /// This profile with its curves replaced.
    func with(curves: [Attribute: [CurvePoint]]) -> RatingProfile {
        RatingProfile(id: id, name: name, tables: tables, curves: curves, positionShare: positionShare, roleShare: roleShare,
                      consensusShare: consensusShare, roleScoreRule: roleScoreRule, evidence: evidence)
    }

    /// The library's `rating_profile_fm27.json` as a JSON object, read from the source tree.
    static func fm27ResourceObject() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/LineupEngine/Resources/rating_profile_fm27.json")
        return try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
    }

    /// The FM27 profile built from `object` through the same loader as the bundled resource.
    static func fm27(from object: [String: Any]) throws -> RatingProfile {
        try fm27EngineTests(json: JSONSerialization.data(withJSONObject: object), carriedOver: carriedOver())
    }

    /// The FM27 profile loaded with its positional emphasis set to `share` and `cap`.
    static func fm27(positionalEmphasisShare share: Double, cap: Double = 2.0) throws -> RatingProfile {
        var object = try fm27ResourceObject()
        object["positionalEmphasis"] = ["share": share, "cap": cap]
        return try fm27(from: object)
    }
}

extension RatingConfiguration {
    /// The FM27 configuration with the FM26 role thresholds switched back on.
    static let thresholdsOn = RatingConfiguration(appliesCurrentAbilityFactor: false, roundsLikeThePythonReference: false,
                                                  appliesRoleThresholds: true)
}
