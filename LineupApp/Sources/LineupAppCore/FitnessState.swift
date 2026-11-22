import LineupEngine

/// What the app keeps for measuring each player's jadedness trend: a fitness reading of every player at each import of
/// his squad, and the day the owner said to measure from. Kept in a file of its own; the rates are worked out from it
/// each time the plan or the advice is (`AppModel.fitnessTrends`) and never saved.
public struct FitnessState: Equatable, Codable, Sendable {
    /// Each player's readings in day order, one a day.
    public var readings: [PlayerID: [FitnessReading]]
    /// The day the owner said to measure from; nil until he does.
    public var measureFrom: Day?

    public init() {
        readings = [:]; measureFrom = nil
    }

    /// Takes a reading of each player on `day`, which replaces one of the same day and keeps its fixtures; then drops,
    /// for every player, readings more than `keptDays` before `day`, and players left with none. A player recorded
    /// loses his readings dated after `day` first: the date was moved back, and they are from a timeline the game no
    /// longer has. Other players' readings are untouched.
    mutating func record(_ players: [Player], on day: Day, including fixtures: [FixtureID], keptDays: Int) {
        for player in players {
            let reading = FitnessReading(day: day, player: player, includes: fixtures)
            var list = readings[player.id, default: []].filter { $0.day <= day }
            if let index = list.firstIndex(where: { $0.day == day }) {
                list[index] = reading.replacing(list[index])
            } else {
                list.append(reading)
                list.sort { $0.day < $1.day }
            }
            readings[player.id] = list
        }
        let oldest = day.adding(days: -keptDays)
        for player in Array(readings.keys) {
            let kept = (readings[player] ?? []).filter { $0.day >= oldest }
            readings[player] = kept.isEmpty ? nil : kept
        }
    }
}
