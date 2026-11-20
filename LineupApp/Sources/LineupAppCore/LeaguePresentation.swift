import LineupEngine

/// One team's line in the League screen's table, as the screen shows it.
public struct LeagueRow: Identifiable, Equatable, Sendable {
    /// The place.
    public let id: Int
    public let place, team, played, won, drawn, lost, goalsFor, goalsAgainst, goalDifference, points: String
    /// The club's own line.
    public let isOwn: Bool
    /// A side within the margin of the club, as the engine reads the table.
    public let isBattled: Bool
    /// The key's words for the mark beside a side within the margin ("Within 6 points of you"), for its accessibility
    /// label; nil on a row with no mark.
    public let mark: String?
    /// The engine's name of the line drawn under this row ("promoted", "bye", "play-offs", "relegated").
    public let lineBelow: String?
}

/// What the League screen shows, worked out from the model's state. Every sentence is the engine's.
public struct LeagueScreenContent: Equatable, Sendable {
    public let byeLine: String?
    public let pastedLine: String?
    /// The table is out of date; the paste's warnings; the order was worked out; the table stops. In that order.
    public let cautions: [String]
    public let pasteProblem: String?
    public let formatProblem: String?
    /// "The table is still read with 1 promoted, …": the saved format is in use while the fields show something else.
    public let formatInUseLine: String?
    /// Said with "Use the table" beside it when the owner's choice for league matches differs from the table's.
    public let handChoiceLine: String?
    /// The reading, or the one line saying why there is none.
    public let sentences: [String]
    public let evidenceNote: String?
    /// "Buxton FC on Sat 25 Apr": league fixtures still to play (today's among them, until its lineup is confirmed)
    /// against sides the table does not hold.
    public let fixturesNotInTheTable: [String]
    public let rows: [LeagueRow]
    /// The key under the table to the mark beside sides within the margin; nil when no side is marked.
    public let withinMarginKey: String?
    /// Shown while there is no table.
    public let emptyLines: [String]
    public let offersRemove: Bool
}

extension AppModel {
    public static let pasteTableTitle = "Paste table"
    public static let removeTableTitle = "Remove table"
    public static let useTheTableTitle = "Use the table"
    public static let promotedLabel = "Promoted automatically"
    public static let playOffsLabel = "In the play-offs"
    public static let relegatedLabel = "Relegated"
    public static let leagueColumnHeadings = ["Pl", "W", "D", "L", "F", "A", "GD", "Pts"]
    public static let notInTableHeading = "League fixtures against sides not in the table"
    public static let removeTableAlertTitle = "Remove the league table?"
    public static let removeTableAlertMessage = "The three numbers stay."
    public static let cancelTitle = "Cancel"

    public var leagueScreen: LeagueScreenContent {
        let reading = leagueReading
        var read: LeagueReading?
        var sentences: [String] = []
        switch reading {
        case .noTable: break
        case .noFormat: sentences = [AdvisorText.noFormatLine]
        case .failed(let sentence): sentences = [sentence]
        case .read(let found):
            read = found
            sentences = AdvisorText.standingLines(found)
        }
        let table = league.table
        var cautions: [String] = []
        if leagueTableIsOutOfDate { cautions.append(AdvisorText.tableOutOfDate) }
        if let table {
            cautions += table.warnings.map { ErrorDescriptions.describe($0) }
            if table.orderWorkedOut { cautions.append(AdvisorText.orderWorkedOutLine) }
        }
        // A finished season's own line already says to paste the new table, so the table is not said to stop.
        if let read, !read.seasonIsOver, leagueFixturesBeyondTheTable > 0 {
            cautions.append(AdvisorText.tableStopsLine(matchesLeft: read.matchesLeft, beyond: leagueFixturesBeyondTheTable))
        }
        var handChoice: String?
        if let read, let byHand = settings.leagueSituation, let fromTable = read.situation, byHand != fromTable {
            handChoice = AdvisorText.handChoiceLine(byHand: byHand, table: fromTable)
        }
        var formatInUse: String?
        if let saved = league.format, leagueFormatDraft.format != saved {
            formatInUse = AdvisorText.formatInUseLine(saved)
        }
        let key = read.flatMap { $0.rivals.isEmpty ? nil : AdvisorText.withinMarginKey($0) }
        return LeagueScreenContent(
            byeLine: league.format.flatMap(AdvisorText.byeLine),
            pastedLine: league.pastedOn.map(AdvisorText.tablePastedLine),
            cautions: cautions,
            pasteProblem: leaguePasteProblem,
            formatProblem: leagueFormatProblem,
            formatInUseLine: formatInUse,
            handChoiceLine: handChoice,
            sentences: sentences,
            evidenceNote: read.map { AdvisorText.leagueEvidenceNote($0, rules: planParameters.leagueStandingRules.value) },
            fixturesNotInTheTable: fixturesNotInTheTable(table),
            rows: table.map { leagueRows($0, reading: read, key: key) } ?? [],
            withinMarginKey: key,
            emptyLines: table == nil ? AdvisorText.noTableLines : [],
            offersRemove: table != nil)
    }

    /// The rows. The rules come from the format whenever one is held and fits the table, so a finished season and a
    /// failed reading still draw them; the club's own row is the one with its name, with or without a format.
    private func leagueRows(_ table: LeagueTable, reading: LeagueReading?, key: String?) -> [LeagueRow] {
        let battled = Set((reading?.rivals ?? []).map { PlayerID.normalise($0.name) })
        let lines = (try? league.format?.lines(teams: table.teams.count)) ?? []
        let lineNames = Dictionary(lines.map { ($0.after, AdvisorText.name($0.kind)) }, uniquingKeysWith: { first, _ in first })
        let own = ownClub.map(PlayerID.normalise)
        return table.teams.enumerated().map { index, team in
            let place = index + 1
            let name = PlayerID.normalise(team.name)
            return LeagueRow(
                id: place, place: String(place), team: team.name, played: String(team.played), won: String(team.won),
                drawn: String(team.drawn), lost: String(team.lost), goalsFor: String(team.goalsFor),
                goalsAgainst: String(team.goalsAgainst), goalDifference: Self.signed(team.goalDifference),
                points: AdvisorText.signedNumber(team.points), isOwn: name == own, isBattled: battled.contains(name),
                mark: battled.contains(name) ? key : nil, lineBelow: lineNames[place])
        }
    }

    /// "+32", "0" or "−29" with a true minus.
    private static func signed(_ n: Int) -> String {
        n > 0 ? "+\(n)" : n < 0 ? "\u{2212}\(-n)" : "0"
    }

    private func fixturesNotInTheTable(_ table: LeagueTable?) -> [String] {
        guard let table else { return [] }
        return fixtures.filter {
            $0.competition == .league && state(of: $0) == .toPlay && table.place(of: $0.opponent) == nil
        }.map { "\($0.opponent) on \(DayText.short($0.date))" }
    }
}
