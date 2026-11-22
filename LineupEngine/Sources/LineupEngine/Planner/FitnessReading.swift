/// One player on one import day, kept so that his jadedness trend can be measured (`FitnessTrend.rates`).
public struct FitnessReading: Equatable, Codable, Sendable {
    public var day: Day
    public var jadedness: Int
    public var condition: Double
    public var sharpness: Double
    public var isInjured: Bool
    /// The fixtures of the confirmed lineups that awaited his squad's import when this was taken: by raw id, each once.
    public private(set) var includes: [FixtureID]

    public init(day: Day, jadedness: Int, condition: Double, sharpness: Double, isInjured: Bool, includes: [FixtureID]) {
        self.day = day; self.jadedness = jadedness; self.condition = condition; self.sharpness = sharpness
        self.isInjured = isInjured
        self.includes = Self.normalised(includes)
    }

    public init(day: Day, player: Player, includes: [FixtureID]) {
        self.init(day: day, jadedness: player.jadedness, condition: player.condition, sharpness: player.sharpness,
                  isInjured: player.isInjured, includes: includes)
    }

    /// This reading in place of `earlier` of the same day: its own figures, and both sets of fixtures.
    public func replacing(_ earlier: FitnessReading) -> FitnessReading {
        FitnessReading(day: day, jadedness: jadedness, condition: condition, sharpness: sharpness,
                       isInjured: isInjured, includes: includes + earlier.includes)
    }

    private enum CodingKeys: String, CodingKey { case day, jadedness, condition, sharpness, isInjured, includes }

    /// Every key is required: a reading with no `includes` is an error, not an empty set.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(day: try container.decode(Day.self, forKey: .day),
                  jadedness: try container.decode(Int.self, forKey: .jadedness),
                  condition: try container.decode(Double.self, forKey: .condition),
                  sharpness: try container.decode(Double.self, forKey: .sharpness),
                  isInjured: try container.decode(Bool.self, forKey: .isInjured),
                  includes: try container.decode([FixtureID].self, forKey: .includes))
    }

    /// `includes` is written as an array of raw ids, sorted.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(day, forKey: .day)
        try container.encode(jadedness, forKey: .jadedness)
        try container.encode(condition, forKey: .condition)
        try container.encode(sharpness, forKey: .sharpness)
        try container.encode(isInjured, forKey: .isInjured)
        try container.encode(includes, forKey: .includes)
    }

    private static func normalised(_ fixtures: [FixtureID]) -> [FixtureID] {
        Set(fixtures.map(\.raw)).sorted().map(FixtureID.init)
    }
}
