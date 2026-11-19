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
    /// First match wins: injured; out on loan; banned, in the fixture his ban is served in (`isNextFixture`: the
    /// planner's earliest fixture that takes bans); condition below the floor; jaded above the threshold unless the
    /// match is high importance.
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

    /// A loan is a fact the user cannot overrule: the player is at another club. The other exclusions are advice.
    /// An injury is among them (revised 18 November 2026): FMRTE says that a player is injured, not whether he can
    /// play through it, and the game passes some injured players fit to play. Nothing but the owner's choice picks him.
    public static func canBeOverridden(_ exclusion: Exclusion) -> Bool {
        switch exclusion {
        case .outOnLoan: false
        case .injured, .banned, .belowConditionFloor, .jaded, .rejected: true
        }
    }
}
