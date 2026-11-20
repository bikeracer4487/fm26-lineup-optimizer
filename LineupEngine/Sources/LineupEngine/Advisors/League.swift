import Foundation

/// The numbers behind where the club stands in the league table (`League.read`).
public struct LeagueStandingRules: Sendable, Equatable {
    /// A line is close when the gap to the side across it is at most this many points.
    public var marginPoints: Int
    /// The margin with one match left.
    public var marginPointsLastMatch: Int
    /// A line is within reach when the gap is at most this many points for each match left.
    public var reachPointsPerMatch: Int
    /// A close promotion, play-off or relegation line is the top situation only with this many matches left or fewer.
    public var topLevelInLastMatches: Int
    /// Sides within the margin are counted as battled only with this many matches left or fewer.
    public var battlingInLastMatches: Int
    /// What a match against a side he is battling is worth, as a multiple of its ordinary importance.
    public var battlingFactor: Double
    public var pointsForWin: Int
    public var pointsForDraw: Int

    public init(marginPoints: Int, marginPointsLastMatch: Int, reachPointsPerMatch: Int, topLevelInLastMatches: Int,
                battlingInLastMatches: Int, battlingFactor: Double, pointsForWin: Int, pointsForDraw: Int) {
        self.marginPoints = marginPoints
        self.marginPointsLastMatch = marginPointsLastMatch
        self.reachPointsPerMatch = reachPointsPerMatch
        self.topLevelInLastMatches = topLevelInLastMatches
        self.battlingInLastMatches = battlingInLastMatches
        self.battlingFactor = battlingFactor
        self.pointsForWin = pointsForWin
        self.pointsForDraw = pointsForDraw
    }
}

public enum LeagueFormatField: String, Sendable, CaseIterable { case promoted, playOffs, relegated }

public enum LeagueFormatError: Error, Equatable {
    case negative(LeagueFormatField, Int)
    case tooMany(total: Int, teams: Int)
}

public enum LeagueLineKind: String, Codable, CaseIterable, Sendable { case promotion, bye, playOff, relegation }

/// A line in the table: the places up to and including `after` are on one side of it.
public struct LeagueLine: Equatable, Sendable {
    public let kind: LeagueLineKind
    public let after: Int

    public init(kind: LeagueLineKind, after: Int) {
        self.kind = kind
        self.after = after
    }
}

/// How many places are promoted, play off for promotion, and are relegated; the owner enters the three.
public struct LeagueFormat: Equatable, Codable, Sendable {
    public var promoted, playOffs, relegated: Int

    public init(promoted: Int, playOffs: Int, relegated: Int) {
        self.promoted = promoted
        self.playOffs = playOffs
        self.relegated = relegated
    }

    /// The play-offs start from the next power of two: the places that miss that number sit out the first round.
    public var byes: Int {
        guard playOffs > 0 else { return 0 }
        var size = 1
        while size < playOffs { size *= 2 }
        return size - playOffs
    }

    /// Negatives are always refused; the total is checked against `teams` when it is given.
    public func check(teams: Int?) throws {
        for (field, value) in [(LeagueFormatField.promoted, promoted), (.playOffs, playOffs), (.relegated, relegated)]
        where value < 0 {
            throw LeagueFormatError.negative(field, value)
        }
        let total = promoted + playOffs + relegated
        if let teams, total > teams { throw LeagueFormatError.tooMany(total: total, teams: teams) }
    }

    /// The lines that exist, in table order: promotion, bye, play-off, relegation. A line with no side across it
    /// (after the last place) is left out.
    public func lines(teams: Int) throws -> [LeagueLine] {
        try check(teams: teams)
        var found: [LeagueLine] = []
        if promoted > 0 { found.append(LeagueLine(kind: .promotion, after: promoted)) }
        if byes > 0 { found.append(LeagueLine(kind: .bye, after: promoted + byes)) }
        if playOffs > 0 { found.append(LeagueLine(kind: .playOff, after: promoted + playOffs)) }
        if relegated > 0 { found.append(LeagueLine(kind: .relegation, after: teams - relegated)) }
        return found.filter { $0.after < teams }
    }
}

public enum LineState: Equatable, Sendable { case safe, outOfReach, close, withinReach, far }

/// Where the club stands against one line.
public struct LineReading: Equatable, Sendable {
    public let line: LeagueLine
    /// The club's place is at or before `line.after`.
    public let isAbove: Bool
    public let state: LineState
    /// Points to the side across the line; nil when safe or out of reach.
    public let gap: Int?
    /// Above: the side in place after + 1. Below: the side in place after. Nil when safe.
    public let other: LeagueTeam?
    public let otherPlace: Int?
}

/// A side the club is battling: `pointsAhead` is negative when it is behind.
public struct LeagueRival: Equatable, Sendable {
    public let name: String
    public let pointsAhead: Int

    public init(name: String, pointsAhead: Int) {
        self.name = name
        self.pointsAhead = pointsAhead
    }
}

public struct LeagueReading: Equatable, Sendable {
    /// The club's name as the table spells it.
    public let club: String
    public let place, points, matchesLeft, mostReachable, margin: Int
    public let lines: [LineReading]
    /// Nil when the season is over.
    public let situation: LeagueSituation?
    /// The line behind a title-race or in-contention situation.
    public let decidedBy: LineReading?
    /// In table order.
    public let rivals: [LeagueRival]
    public let basis: Evidence

    public var seasonIsOver: Bool { matchesLeft == 0 }
}

public enum League {
    /// What is wrong with the rules, in plain words; empty when they can be used.
    static func problems(in rules: LeagueStandingRules) -> [String] {
        var found: [String] = []
        for (name, value) in [("marginPoints", rules.marginPoints), ("marginPointsLastMatch", rules.marginPointsLastMatch),
                              ("reachPointsPerMatch", rules.reachPointsPerMatch),
                              ("topLevelInLastMatches", rules.topLevelInLastMatches),
                              ("battlingInLastMatches", rules.battlingInLastMatches)] where value < 0 {
            found.append("leagueStandingRules \(name) is \(value), not 0 or more")
        }
        if rules.marginPoints >= 0 && rules.marginPointsLastMatch > rules.marginPoints {
            found.append("leagueStandingRules marginPointsLastMatch is \(rules.marginPointsLastMatch), over marginPoints (\(rules.marginPoints))")
        }
        if !(rules.battlingFactor.isFinite && rules.battlingFactor > 0) {
            found.append("leagueStandingRules battlingFactor is \(rules.battlingFactor), not a finite number above 0")
        }
        if rules.pointsForWin <= rules.pointsForDraw {
            found.append("leagueStandingRules pointsForWin is \(rules.pointsForWin), not over pointsForDraw (\(rules.pointsForDraw))")
        }
        return found
    }

    /// Reads where `club` stands against each line of `format`. Every number is a whole number of points.
    public static func read(table: LeagueTable, format: LeagueFormat, club: String,
                            parameters: EngineParameters) throws -> LeagueReading {
        let problems = FitnessModel.problems(in: parameters)
        guard problems.isEmpty else { throw PlanError.badParameters(problems) }
        let rules = parameters.leagueStandingRules.value
        guard let place = table.place(of: club) else {
            throw LeagueTableError.clubNotInTable(club: club, teams: table.teams.count)
        }
        let leagueLines = try format.lines(teams: table.teams.count)

        let teams = table.teams
        let me = teams[place - 1]
        let season = table.seasonMatches
        let left = max(0, season - me.played)
        let most = me.points + rules.pointsForWin * left
        let margin = left == 1 ? rules.marginPointsLastMatch : rules.marginPoints

        func mostReachable(_ team: LeagueTeam) -> Int {
            team.points + rules.pointsForWin * max(0, season - team.played)
        }
        let others = teams.enumerated().filter { $0.offset != place - 1 }.map(\.element)

        func state(gap: Int) -> LineState {
            if gap <= margin { return .close }
            if gap <= rules.reachPointsPerMatch * left { return .withinReach }
            return .far
        }

        let readings: [LineReading] = left == 0 ? [] : leagueLines.map { line in
            let k = line.after
            let isAbove = place <= k
            if isAbove {
                let reaching = others.filter { mostReachable($0) >= me.points }.count
                if reaching < k {
                    return LineReading(line: line, isAbove: true, state: .safe, gap: nil, other: nil, otherPlace: nil)
                }
                let across = teams[k]
                let gap = me.points - across.points
                return LineReading(line: line, isAbove: true, state: state(gap: gap), gap: gap, other: across,
                                   otherPlace: k + 1)
            }
            let across = teams[k - 1]
            let beyond = others.filter { $0.points > most }.count
            if beyond >= k {
                return LineReading(line: line, isAbove: false, state: .outOfReach, gap: nil, other: across, otherPlace: k)
            }
            let gap = across.points - me.points
            return LineReading(line: line, isAbove: false, state: state(gap: gap), gap: gap, other: across, otherPlace: k)
        }

        func nearest(_ candidates: [LineReading]) -> LineReading? {
            var best: LineReading?
            for reading in candidates {
                if best == nil || reading.gap! < best!.gap! { best = reading }
            }
            return best
        }

        var situation: LeagueSituation?
        var decidedBy: LineReading?
        if left > 0 {
            let settled = readings.allSatisfy { $0.state == .safe || $0.state == .outOfReach }
            let topClose = readings.filter { $0.state == .close && $0.line.kind != .bye }
            if settled {
                situation = .nothingToPlayFor
            } else if !topClose.isEmpty && left <= rules.topLevelInLastMatches {
                situation = .titleRaceOrRelegationFight
                decidedBy = nearest(topClose)
            } else if readings.contains(where: { $0.state == .close || $0.state == .withinReach }) {
                situation = .inContention
                let close = readings.filter { $0.state == .close }
                decidedBy = nearest(close.isEmpty ? readings.filter { $0.state == .withinReach } : close)
            } else {
                situation = .midTable
            }
        }

        var rivals: [LeagueRival] = []
        if left >= 1 && left <= rules.battlingInLastMatches {
            for team in others where abs(team.points - me.points) <= margin {
                rivals.append(LeagueRival(name: team.name, pointsAhead: team.points - me.points))
            }
        }

        return LeagueReading(
            club: me.name, place: place, points: me.points, matchesLeft: left, mostReachable: most, margin: margin,
            lines: readings, situation: situation, decidedBy: decidedBy, rivals: rivals,
            basis: parameters.leagueStandingRules.evidence)
    }
}
