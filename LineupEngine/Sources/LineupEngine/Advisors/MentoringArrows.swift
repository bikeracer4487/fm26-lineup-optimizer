import Foundation

/// The game's four strengths of influence arrow, weakest first, so `<` reads "is weaker".
public enum ArrowStrength: String, Codable, CaseIterable, Comparable, Sendable {
    case none, light, average, significant

    private var rank: Int { ArrowStrength.allCases.firstIndex(of: self) ?? 0 }
    public static func < (a: ArrowStrength, b: ArrowStrength) -> Bool { a.rank < b.rank }
}

/// An arrow the owner read in the game: one for an ordered pair in a squad.
public struct ArrowReading: Equatable, Codable, Sendable {
    public var from: PlayerID
    public var to: PlayerID
    public var squad: Squad
    public var strength: ArrowStrength
    public var readOn: Day

    public init(from: PlayerID, to: PlayerID, squad: Squad, strength: ArrowStrength, readOn: Day) {
        self.from = from
        self.to = to
        self.squad = squad
        self.strength = strength
        self.readOn = readOn
    }
}

/// One way between two players, as the advice uses it: read, or guessed.
public struct Arrow: Equatable, Sendable {
    public let from: PlayerID
    public let to: PlayerID
    public let strength: ArrowStrength
    /// Nil: a guess.
    public let readOn: Day?
    public var isRead: Bool { readOn != nil }
}

extension Mentoring {
    /// What a guess reads about a player.
    public struct Party: Equatable, Sendable {
        public let id: PlayerID
        public let standing: Standing
        public let age: Int

        public init(id: PlayerID, standing: Standing, age: Int) {
            self.id = id
            self.standing = standing
            self.age = age
        }
    }

    /// The guess for a pair with no reading: None into a player who takes nothing, into one at the source's level or
    /// above, and into one older than `mentoringMenteeMaxAge`; otherwise what `mentoringGuess` says for the source's level.
    public static func guess(from: Party, to: Party, toTakesNothing: Bool, parameters: EngineParameters) -> ArrowStrength {
        if toTakesNothing || to.standing >= from.standing || to.age > parameters.mentoringMenteeMaxAge.value {
            return .none
        }
        // A level with no entry is reported by `problems(in:)`; here it guesses nothing.
        return parameters.mentoringGuess.value[from.standing] ?? .none
    }

    /// Readings of None into him from at least `mentoringTakesNothingAfter` different sources whose level, in
    /// `standings`, is Influential or above, and no reading into him above None. Only readings of `squad` count.
    /// A player with no entry in `standings` is at Others.
    public static func takesNothing(_ player: PlayerID, in squad: Squad, readings: [ArrowReading],
                                    standings: [PlayerID: Standing], parameters: EngineParameters) -> Bool {
        let into = readings.filter { $0.squad == squad && $0.to == player }
        if into.contains(where: { $0.strength > .none }) { return false }
        let sources = Set(into.map(\.from).filter { (standings[$0] ?? .others) >= .influential })
        return sources.count >= parameters.mentoringTakesNothingAfter.value
    }

    /// The reading for the pair in `squad` when there is one, otherwise the guess. When the pair was read more than
    /// once, the latest reading counts.
    public static func arrow(from: Party, to: Party, in squad: Squad, readings: [ArrowReading],
                             standings: [PlayerID: Standing], parameters: EngineParameters) -> Arrow {
        let read = readings.filter { $0.squad == squad && $0.from == from.id && $0.to == to.id }.max { $0.readOn < $1.readOn }
        if let read {
            return Arrow(from: from.id, to: to.id, strength: read.strength, readOn: read.readOn)
        }
        let takesNothing = takesNothing(to.id, in: squad, readings: readings, standings: standings, parameters: parameters)
        return Arrow(from: from.id, to: to.id,
                     strength: guess(from: from, to: to, toTakesNothing: takesNothing, parameters: parameters),
                     readOn: nil)
    }
}
