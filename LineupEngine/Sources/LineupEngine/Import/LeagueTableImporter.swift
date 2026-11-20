import Foundation

/// One team's line in a league table. Every number is a whole number, as FMRTE shows it.
public struct LeagueTeam: Equatable, Codable, Sendable {
    public var name: String
    public var played, won, drawn, lost, goalsFor, goalsAgainst, points: Int

    public init(name: String, played: Int, won: Int, drawn: Int, lost: Int, goalsFor: Int, goalsAgainst: Int, points: Int) {
        self.name = name
        self.played = played
        self.won = won
        self.drawn = drawn
        self.lost = lost
        self.goalsFor = goalsFor
        self.goalsAgainst = goalsAgainst
        self.points = points
    }

    public var goalDifference: Int { goalsFor - goalsAgainst }
}

public enum LeagueTableWarning: Equatable, Codable, Sendable {
    /// The team's pasted points are not what its results give; the pasted points are used, since the game deducts points.
    case pointsDoNotFit(team: String, points: Int, fromResults: Int)
}

/// A league table as pasted, in place order.
public struct LeagueTable: Equatable, Codable, Sendable {
    /// In place order: `teams[0]` is first.
    public var teams: [LeagueTeam]
    /// True when the paste had no `Position` column, so the order was worked out here (points, goal difference, goals for,
    /// name) and not taken from the game.
    public var orderWorkedOut: Bool
    public var warnings: [LeagueTableWarning]

    public init(teams: [LeagueTeam], orderWorkedOut: Bool, warnings: [LeagueTableWarning]) {
        self.teams = teams
        self.orderWorkedOut = orderWorkedOut
        self.warnings = warnings
    }

    /// Every team plays every other twice.
    public var seasonMatches: Int { 2 * (teams.count - 1) }

    /// The 1-based place of the team, its name compared by `PlayerID.normalise`.
    public func place(of name: String) -> Int? {
        let wanted = PlayerID.normalise(name)
        return teams.firstIndex { PlayerID.normalise($0.name) == wanted }.map { $0 + 1 }
    }

    public func team(named name: String) -> LeagueTeam? {
        place(of: name).map { teams[$0 - 1] }
    }
}

public enum LeagueTableError: Error, Equatable {
    /// FMRTE's settings file has no standings grid.
    case noStandingsGrid
    case noGridFits(fieldCount: Int)
    case ambiguousGrid(keys: [String])
    case missingColumns(grid: String, columns: [String])
    case invalidValue(team: String, column: String, value: String)
    case tooFewTeams(found: Int)
    case duplicateTeam(String)
    case placesNotInOrder
    case resultsDoNotAddUp(team: String, played: Int, won: Int, drawn: Int, lost: Int)
    case playedTooMany(team: String, played: Int, season: Int)
    case noClubKnown
    case clubNotInTable(club: String, teams: Int)
}

/// Reads the league table FMRTE copies from its standings grid. The text has no header; the column meaning comes from the
/// layout in FMRTE's settings file, as for squads.
public enum LeagueTableImporter {
    /// The paths a standings layout must hold; `Position` is optional.
    private static let positionPath = "Position"
    private static let namePath = "TeamName"
    private static let numberPaths = ["GamesPlayed", "Wins", "Draws", "Loses", "GoalsScored", "GoalsAllowed", "Points"]

    public static func read(clipboard: String, fmrteConfig: Data, ownClub: String?,
                            parameters: EngineParameters) throws -> LeagueTable {
        let points = parameters.leagueStandingRules.value
        let rows = try ClipboardText.rows(clipboard, minimumFields: 2)
        let grids = try FMRTEConfig.standingsGrids(from: fmrteConfig)
        guard !grids.isEmpty else { throw LeagueTableError.noStandingsGrid }
        let fits = grids.filter { $0.columns.count == rows[0].count }
        guard !fits.isEmpty else { throw LeagueTableError.noGridFits(fieldCount: rows[0].count) }
        guard fits.count == 1 else { throw LeagueTableError.ambiguousGrid(keys: fits.map(\.key).sorted()) }
        let layout = fits[0]

        let required = [namePath] + numberPaths
        let missing = required.filter { !layout.columns.contains($0) }
        guard missing.isEmpty else { throw LeagueTableError.missingColumns(grid: layout.key, columns: missing) }
        let index = Dictionary(layout.columns.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })

        var entries: [(place: Int?, team: LeagueTeam)] = []
        for row in rows {
            let name = row[index[namePath]!]
            guard !name.trimmingCharacters(in: .whitespaces).isEmpty else {
                throw LeagueTableError.invalidValue(team: "", column: namePath, value: name)
            }
            /// Digits only; the points alone may carry one leading minus (a hyphen or a true minus, U+2212), since the
            /// game deducts points and an early deduction puts a club below zero.
            func number(_ path: String, mayBeNegative: Bool = false) throws -> Int {
                let cell = row[index[path]!]
                var digits = Substring(cell)
                var negative = false
                if mayBeNegative, let first = digits.first, first == "-" || first == "\u{2212}" {
                    negative = true
                    digits = digits.dropFirst()
                }
                guard !digits.isEmpty, digits.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(digits) else {
                    throw LeagueTableError.invalidValue(team: name, column: path, value: cell)
                }
                return negative ? -value : value
            }
            let place = try index[positionPath].map { _ in try number(positionPath) }
            entries.append((place, LeagueTeam(
                name: name, played: try number("GamesPlayed"), won: try number("Wins"), drawn: try number("Draws"),
                lost: try number("Loses"), goalsFor: try number("GoalsScored"), goalsAgainst: try number("GoalsAllowed"),
                points: try number("Points", mayBeNegative: true))))
        }

        guard entries.count >= 2 else { throw LeagueTableError.tooFewTeams(found: entries.count) }
        var seen = Set<String>()
        for entry in entries where !seen.insert(PlayerID.normalise(entry.team.name)).inserted {
            throw LeagueTableError.duplicateTeam(entry.team.name)
        }

        let hasPlaces = index[positionPath] != nil
        if hasPlaces, entries.compactMap(\.place).sorted() != Array(1...entries.count) {
            throw LeagueTableError.placesNotInOrder
        }

        let season = 2 * (entries.count - 1)
        var warnings: [LeagueTableWarning] = []
        for entry in entries {
            let team = entry.team
            guard team.won + team.drawn + team.lost == team.played else {
                throw LeagueTableError.resultsDoNotAddUp(team: team.name, played: team.played, won: team.won,
                                                         drawn: team.drawn, lost: team.lost)
            }
            guard team.played <= season else {
                throw LeagueTableError.playedTooMany(team: team.name, played: team.played, season: season)
            }
        }

        let ordered: [LeagueTeam]
        if hasPlaces {
            ordered = entries.sorted { $0.place! < $1.place! }.map(\.team)
        } else {
            ordered = entries.map(\.team).sorted {
                if $0.points != $1.points { return $0.points > $1.points }
                if $0.goalDifference != $1.goalDifference { return $0.goalDifference > $1.goalDifference }
                if $0.goalsFor != $1.goalsFor { return $0.goalsFor > $1.goalsFor }
                return $0.name < $1.name
            }
        }
        for team in ordered {
            let fromResults = team.won * points.pointsForWin + team.drawn * points.pointsForDraw
            if team.points != fromResults {
                warnings.append(.pointsDoNotFit(team: team.name, points: team.points, fromResults: fromResults))
            }
        }

        let table = LeagueTable(teams: ordered, orderWorkedOut: !hasPlaces, warnings: warnings)
        guard let club = ownClub else { throw LeagueTableError.noClubKnown }
        guard table.place(of: club) != nil else {
            throw LeagueTableError.clubNotInTable(club: club, teams: table.teams.count)
        }
        return table
    }
}
