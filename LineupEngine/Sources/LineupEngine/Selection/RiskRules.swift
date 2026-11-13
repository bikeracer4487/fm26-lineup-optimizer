public enum Importance: String, Codable, CaseIterable, Sendable {
    case high, medium, low, sharpness
}

/// Why a player is kept out of a lineup whatever his rating.
public enum Exclusion: Equatable, Sendable {
    case injured
    case outOnLoan(to: String)
    case banned
    case belowConditionFloor(Double)
    case jaded(Int)
    /// Produced by the selector when the user rejects a player, never by `RiskRules`.
    case rejected
}

public enum RiskRules {
    /// First match wins: injured; out on loan; banned for the next fixture; condition below the
    /// floor; jaded above the threshold unless the match is high importance.
    public static func exclusion(
        for player: Player, loan: LoanStatus, importance: Importance,
        isNextFixture: Bool, parameters: EngineParameters
    ) -> Exclusion? {
        if player.isInjured { return .injured }
        if case .loanedOut(let club) = loan { return .outOnLoan(to: club) }
        if player.isBanned && isNextFixture { return .banned }
        if player.condition < parameters.conditionFloor.value { return .belowConditionFloor(player.condition) }
        if player.jadedness > parameters.jadedThreshold.value && importance != .high { return .jaded(player.jadedness) }
        return nil
    }

    /// An injury or a loan is a fact the user cannot overrule; the other exclusions are advice.
    public static func canBeOverridden(_ exclusion: Exclusion) -> Bool {
        switch exclusion {
        case .injured, .outOnLoan: false
        case .banned, .belowConditionFloor, .jaded, .rejected: true
        }
    }
}
