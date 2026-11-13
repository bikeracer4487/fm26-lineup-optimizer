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
}

extension RatingConfiguration {
    /// The FM27 configuration with the FM26 role thresholds switched back on.
    static let thresholdsOn = RatingConfiguration(appliesCurrentAbilityFactor: false, roundsLikeThePythonReference: false,
                                                  appliesRoleThresholds: true)
}
