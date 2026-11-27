import LineupEngine

/// What the owner was told an agent wants for a player, by the week, with the day in the game it was typed.
public struct AgentFigure: Equatable, Codable, Sendable {
    public var perWeek: Double
    public var entered: Day

    public init(perWeek: Double, entered: Day) {
        self.perWeek = perWeek; self.entered = entered
    }
}

/// What the Contracts screen keeps: the club's three wage figures, the players the owner is not renewing, those he
/// chose to renew anyway, and the figures agents asked. Kept in a file of its own. Every wage is by the week, whatever period it is typed and shown in.
public struct ContractsState: Equatable, Codable, Sendable {
    public var limits: WageLimits = .none
    /// The day in the game a limit was last changed; nil with none entered.
    public var limitsEntered: Day?
    /// The players not being renewed, with the day they were set aside.
    public var dismissed: [PlayerID: Day] = [:]
    /// The players the owner chose to renew though the tool does not recommend it ("Renew anyway"), with the day he
    /// chose; absent in files from before it, and read as nobody.
    public var wanted: [PlayerID: Day] = [:]
    public var figures: [PlayerID: AgentFigure] = [:]

    public init() {}

    private enum CodingKeys: String, CodingKey { case limits, limitsEntered, dismissed, wanted, figures }

    /// A file with a key missing reads that key as its default.
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        limits = try values.decodeIfPresent(WageLimits.self, forKey: .limits) ?? .none
        limitsEntered = try values.decodeIfPresent(Day.self, forKey: .limitsEntered)
        dismissed = try values.decodeIfPresent([PlayerID: Day].self, forKey: .dismissed) ?? [:]
        wanted = try values.decodeIfPresent([PlayerID: Day].self, forKey: .wanted) ?? [:]
        figures = try values.decodeIfPresent([PlayerID: AgentFigure].self, forKey: .figures) ?? [:]
    }
}

/// One of the club's three wage figures the owner types.
public enum WageLimitField: CaseIterable, Sendable { case wageBudget, wagesSpent, highestWage }
