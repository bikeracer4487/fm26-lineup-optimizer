import Foundation
import Testing
@testable import LineupEngine

@Suite struct LeagueTextTests {
    /// Rows in place order; wins are points / 3, draws the remainder, the rest losses; no goals.
    private func table(_ rows: [(String, played: Int, points: Int)]) -> LeagueTable {
        LeagueTable(teams: rows.map { name, played, points in
            let won = points / 3, drawn = points % 3
            return LeagueTeam(name: name, played: played, won: won, drawn: drawn, lost: played - won - drawn,
                              goalsFor: 0, goalsAgainst: 0, points: points)
        }, orderWorkedOut: false, warnings: [])
    }

    private let six = LeagueFormat(promoted: 1, playOffs: 2, relegated: 1)

    private func reading(_ rows: [(String, played: Int, points: Int)], _ format: LeagueFormat? = nil) throws -> LeagueReading {
        try League.read(table: table(rows), format: format ?? six, club: "Me", parameters: .fm27)
    }

    private func lines(_ rows: [(String, played: Int, points: Int)], _ format: LeagueFormat? = nil) throws -> [String] {
        AdvisorText.standingLines(try reading(rows, format))
    }

    private func owners() throws -> LeagueReading {
        let t = try LeagueTableImporter.read(clipboard: Fixtures.leagueTable, fmrteConfig: Fixtures.leagueTableGrids,
                                             ownClub: "Oxford City", parameters: .fm27)
        return try League.read(table: t, format: LeagueFormat(promoted: 1, playOffs: 6, relegated: 4), club: "Oxford City",
                               parameters: .fm27)
    }

    // One match left: A 20, B 16, Me 14 (3rd), D 10, E 8, F 2. Everything is settled.
    private let settled: [(String, played: Int, points: Int)] =
        [("A", 9, 20), ("B", 9, 16), ("Me", 9, 14), ("D", 9, 10), ("E", 9, 8), ("F", 9, 2)]
    // Nine matches left: A 40, B 38, C 28, D 27, Me 19 (5th), F 2.
    private let reach: [(String, played: Int, points: Int)] =
        [("A", 1, 40), ("B", 1, 38), ("C", 1, 28), ("D", 1, 27), ("Me", 1, 19), ("F", 1, 2)]

    // MARK: the owner's table

    @Test func theOwnersTableIsReadInSevenLines() throws {
        #expect(AdvisorText.standingLines(try owners()) == [
            "You are 5th on 74 points with 3 matches left.",
            "Automatic promotion is out of reach: Chester have 87 points and the most you can reach is 83.",
            "A bye in the play-offs is 3 points away: Spalding, in 3rd, have 77.",
            "Your play-off place is not safe: Morecambe, in 8th, are 6 points behind you.",
            "You cannot be relegated.",
            "League matches read as Title race or relegation fight: your play-off place is within 6 points with 3 matches left "
                + "(this tool's estimate).",
            "Within 6 points of you: Spalding, Hednesford, Buxton, Macclesfield and Morecambe.",
        ])
    }

    @Test func theOwnersBaseReason() throws {
        #expect(AdvisorText.leagueBaseReason(try owners()) == "League match, your play-off place is within 6 points")
    }

    @Test func theRivalsAreNamedWithTheirGap() {
        #expect(AdvisorText.battlingReason(LeagueRival(name: "Buxton", pointsAhead: 0), factor: 1.2)
                == "Buxton are level on points with you (\u{00D7}1.2)")
        #expect(AdvisorText.battlingReason(LeagueRival(name: "Spalding", pointsAhead: 3), factor: 1.2)
                == "Spalding are 3 points ahead of you (\u{00D7}1.2)")
        #expect(AdvisorText.battlingReason(LeagueRival(name: "Morecambe", pointsAhead: -6), factor: 1.2)
                == "Morecambe are 6 points behind you (\u{00D7}1.2)")
        #expect(AdvisorText.battlingReason(LeagueRival(name: "Spalding", pointsAhead: 1), factor: 1.2)
                == "Spalding are 1 point ahead of you (\u{00D7}1.2)")
    }

    // MARK: each case of each line

    @Test func aLineSafeAboveIsSaidWithNothingToName() throws {
        let rows: [(String, played: Int, points: Int)] =
            [("Me", 9, 30), ("B", 9, 16), ("C", 9, 12), ("D", 9, 10), ("E", 9, 8), ("F", 9, 2)]
        let l = try lines(rows)
        #expect(l[1] == "Promotion is certain.")
        #expect(l[2] == "Your play-off place is safe.")
        #expect(l[3] == "You cannot be relegated.")
        let byes = try lines(rows, LeagueFormat(promoted: 0, playOffs: 3, relegated: 0))
        #expect(byes[1] == "Your bye is safe.")
        #expect(byes[2] == "Your play-off place is safe.")
    }

    @Test func aLineAboveAndCloseNamesTheSideBelow() throws {
        let rows: [(String, played: Int, points: Int)] =
            [("A", 9, 20), ("B", 9, 16), ("Me", 9, 14), ("D", 9, 14), ("E", 9, 13), ("F", 9, 12)]
        let l = try lines(rows)
        #expect(l[2] == "Your play-off place is not safe: D, in 4th, are level on points with you.")
        #expect(l[3] == "You can still be relegated: F, in 6th, are 2 points behind you.")
    }

    @Test func aLineAboveAndWithinReachOrFarSaysHowFarBehind() throws {
        let rows: [(String, played: Int, points: Int)] =
            [("A", 1, 30), ("B", 1, 28), ("Me", 1, 25), ("D", 1, 16), ("E", 1, 8), ("F", 1, 2)]
        let l = try lines(rows)
        #expect(l[2] == "D, in 4th, are 9 points behind your play-off place.")
        #expect(l[3] == "F, in 6th, are 23 points behind you, across the relegation line.")
    }

    @Test func aLineBelowAndOutOfReachNamesTheLastSideAboveAndHisMost() throws {
        let l = try lines(settled)
        #expect(l[1] == "Automatic promotion is out of reach: A have 20 points and the most you can reach is 17.")
        let bye = try lines([("A", 9, 20), ("B", 9, 20), ("C", 9, 20), ("Me", 9, 14), ("E", 9, 8), ("F", 9, 2)],
                            LeagueFormat(promoted: 0, playOffs: 3, relegated: 0))
        #expect(bye[1] == "A bye in the play-offs is out of reach: A have 20 points and the most you can reach is 17.")
    }

    @Test func aLineBelowAndOpenNamesTheSideAndItsPoints() throws {
        let l = try lines(reach)
        #expect(l[1] == "Automatic promotion is 21 points away: A, in 1st, have 40.")
        #expect(l[2] == "A play-off place is 9 points away: C, in 3rd, have 28.")
    }

    @Test func aPointAndAMatchAreSingular() throws {
        let rows: [(String, played: Int, points: Int)] =
            [("A", 9, 20), ("B", 9, 16), ("C", 9, 15), ("Me", 9, 14), ("E", 9, 8), ("F", 9, 2)]
        let l = try lines(rows)
        #expect(l[0] == "You are 4th on 14 points with 1 match left.")
        #expect(l[2] == "A play-off place is 1 point away: C, in 3rd, have 15.")
        let level = try lines([("A", 9, 20), ("B", 9, 16), ("C", 9, 14), ("Me", 9, 14), ("E", 9, 8), ("F", 9, 2)])
        #expect(level[2] == "A play-off place is level on points: C, in 3rd, have 14.")
    }

    @Test func theSituationLineNamesWhatDecidedIt() throws {
        let within = AdvisorText.standingLines(try reading(reach)).dropFirst(3)
        #expect(within.contains("League matches read as In contention: a play-off place is 9 points away with 9 matches left "
                                + "(this tool's estimate)."))
        let mid = try lines([("A", 1, 40), ("B", 1, 38), ("C", 1, 30), ("D", 1, 28), ("Me", 1, 15), ("F", 1, 2)], noDrop)
        #expect(mid.contains("League matches read as Mid-table: nothing is within reach (this tool's estimate)."))
        let nothing = try lines(settled)
        #expect(nothing.contains("League matches read as Nothing to play for: nothing can change for you."))
        #expect(!nothing.joined().contains("estimate"))
    }

    /// Five matches left: Me 20 (1st), B 13, C 12, D 5, E 4, F 0. B is 7 points behind, over the margin of 6 and the 5
    /// within reach, so the promotion line is far; so is the play-off line (D, 15 behind); the drop is safe, since only
    /// three sides can reach 20. Nothing is close or within reach: Mid-table.
    private let clear: [(String, played: Int, points: Int)] =
        [("Me", 5, 20), ("B", 5, 13), ("C", 5, 12), ("D", 5, 5), ("E", 5, 4), ("F", 5, 0)]
    /// The six-team format with nobody relegated, so a club in mid-table is above no line.
    private let noDrop = LeagueFormat(promoted: 1, playOffs: 2, relegated: 0)

    @Test func aClubFarClearOfALineSaysWhatHeHolds() throws {
        let r = try reading(clear)
        #expect(r.situation == .midTable)
        #expect(r.lines.map(\.state) == [.far, .far, .safe])
        #expect(AdvisorText.standingLines(r).contains(
            "League matches read as Mid-table: your promotion place is 7 points clear with 5 matches left, and nothing else is "
                + "within reach (this tool's estimate)."))
        #expect(AdvisorText.leagueBaseReason(r) == "League match, your promotion place is 7 points clear with 5 matches left")
    }

    @Test func aMidTableClubFarAboveTheDropAloneIsToldSo() throws {
        let r = try reading([("A", 1, 40), ("B", 1, 38), ("C", 1, 30), ("D", 1, 28), ("Me", 1, 15), ("F", 1, 2)])
        #expect(r.situation == .midTable)
        #expect(AdvisorText.leagueBaseReason(r) == "League match, the drop is 13 points clear with 9 matches left")
    }

    @Test func aMidTableClubAboveNoFarLineSaysNothingIsWithinReach() throws {
        let r = try reading([("A", 1, 40), ("B", 1, 38), ("C", 1, 30), ("D", 1, 28), ("Me", 1, 15), ("F", 1, 2)], noDrop)
        #expect(r.situation == .midTable && r.lines.allSatisfy { !$0.isAbove })
        #expect(AdvisorText.standingLines(r).last == "League matches read as Mid-table: nothing is within reach (this tool's estimate).")
        #expect(AdvisorText.leagueBaseReason(r) == "League match, nothing within reach")
    }

    @Test func negativePointsAreWrittenWithATrueMinus() throws {
        let r = try reading([("A", 1, 40), ("B", 1, 38), ("C", 1, 30), ("D", 1, 28), ("E", 1, -2), ("Me", 1, -10)])
        let l = AdvisorText.standingLines(r)
        #expect(l[0] == "You are 6th on \u{2212}10 points with 9 matches left.")
        #expect(l[3] == "Safety is 8 points away: E, in 5th, have \u{2212}2.")
        let deducted = ErrorDescriptions.describe(LeagueTableWarning.pointsDoNotFit(team: "Marine", points: -10, fromResults: 35))
        #expect(deducted == "Marine have \u{2212}10 points where their results give 35; the table's points are used.")
    }

    @Test func noRivalsLeavesTheLastLineOut() throws {
        let l = try lines([("A", 1, 40), ("B", 1, 38), ("C", 1, 30), ("D", 1, 28), ("Me", 1, 15), ("F", 1, 2)])
        #expect(!l.contains { $0.hasPrefix("Within") })
    }

    @Test func theBaseReasonsFollowTheSituation() throws {
        #expect(AdvisorText.leagueBaseReason(try reading(reach)) == "League match, a play-off place is 9 points away with 9 matches left")
        let mid = try reading([("A", 1, 40), ("B", 1, 38), ("C", 1, 30), ("D", 1, 28), ("Me", 1, 15), ("F", 1, 2)], noDrop)
        #expect(AdvisorText.leagueBaseReason(mid) == "League match, nothing within reach")
        #expect(AdvisorText.leagueBaseReason(try reading(settled)) == "League match, nothing left to settle")
    }

    @Test func aSeasonThatIsOverSaysSoAndNothingElse() throws {
        let over = try reading([("A", 10, 20), ("B", 10, 16), ("Me", 10, 14), ("D", 10, 10), ("E", 10, 8), ("F", 10, 2)])
        #expect(AdvisorText.standingLines(over) == [
            "You are 3rd on 14 points.",
            "The season in this table is over. Paste the new season's table when it starts.",
        ])
    }

    // MARK: ordinals

    @Test func ordinalsAreRightForEveryPlace() throws {
        let words = ["1st", "2nd", "3rd", "4th", "5th", "6th", "7th", "8th", "9th", "10th", "11th", "12th", "13th", "14th",
                     "15th", "16th", "17th", "18th", "19th", "20th", "21st", "22nd", "23rd", "24th"]
        for place in 1...24 {
            let rows: [(String, played: Int, points: Int)] = (1...24).map { (i: Int) in (i == place ? "Me" : "T\(i)", 1, 100 - i) }
            let r = try League.read(table: table(rows), format: LeagueFormat(promoted: 0, playOffs: 0, relegated: 0), club: "Me",
                                    parameters: .fm27)
            #expect(AdvisorText.standingLines(r)[0] == "You are \(words[place - 1]) on \(100 - place) points with 45 matches left.")
        }
    }

    // MARK: the rest of the words

    @Test func theLineKindsHaveNames() {
        #expect(LeagueLineKind.allCases.map { AdvisorText.name($0) } == ["promoted", "bye", "play-offs", "relegated"])
    }

    @Test func theByeLineNamesWhoGetsOne() {
        #expect(AdvisorText.byeLine(LeagueFormat(promoted: 1, playOffs: 6, relegated: 4)) == "2nd and 3rd get a bye.")
        #expect(AdvisorText.byeLine(LeagueFormat(promoted: 0, playOffs: 3, relegated: 0)) == "1st gets a bye.")
        #expect(AdvisorText.byeLine(LeagueFormat(promoted: 1, playOffs: 5, relegated: 0)) == "2nd, 3rd and 4th get a bye.")
        #expect(AdvisorText.byeLine(LeagueFormat(promoted: 1, playOffs: 4, relegated: 4)) == nil)
    }

    @Test func theDayIsSaidAsTheOwnerReadsIt() {
        #expect(AdvisorText.tablePastedLine(on: Day(iso: "2026-04-18")!) == "Table pasted on Sat 18 Apr.")
        #expect(AdvisorText.tablePastedLine(on: Day(iso: "2026-11-19")!) == "Table pasted on Thu 19 Nov.")
    }

    @Test func theFixedSentences() {
        #expect(AdvisorText.tableOutOfDate == "A league match has been played since; paste the table again.")
        #expect(AdvisorText.tableStopsLine(matchesLeft: 3, beyond: 2)
                == "The table has 3 matches left, so it is used for your next 3 league fixtures; the 2 after them are read without it.")
        #expect(AdvisorText.tableStopsLine(matchesLeft: 1, beyond: 1)
                == "The table has 1 match left, so it is used for your next league fixture; the 1 after it is read without it.")
        #expect(AdvisorText.notInTheTable("Buxton FC") == "Buxton FC is not in the league table.")
        #expect(AdvisorText.handChoiceLine(byHand: .midTable, table: .inContention)
                == "You have set league matches to Mid-table; the table reads In contention. Your choice is used.")
        #expect(AdvisorText.fromTheTable(.inContention) == "From the table (In contention)")
        #expect(AdvisorText.fromTheTable(nil) == "From the table")
        #expect(!AdvisorText.orderWorkedOutLine.isEmpty && !AdvisorText.noFormatLine.isEmpty && !AdvisorText.noTableLines.isEmpty)
    }

    @Test func theFormatInUseIsSaidInTheWordsOfTheRefusal() {
        #expect(AdvisorText.formatInUseLine(LeagueFormat(promoted: 1, playOffs: 6, relegated: 4))
                == "The table is still read with 1 promoted, 6 in the play-offs and 4 relegated.")
        #expect(AdvisorText.formatInUseLine(LeagueFormat(promoted: 0, playOffs: 0, relegated: 3))
                == "The table is still read with 0 promoted, 0 in the play-offs and 3 relegated.")
    }

    @Test func theKeyToTheMarkNamesTheMargin() throws {
        #expect(AdvisorText.withinMarginKey(try owners()) == "Within 6 points of you")
        let last = try reading([("A", 9, 20), ("B", 9, 16), ("Me", 9, 14), ("D", 9, 12), ("E", 9, 8), ("F", 9, 2)])
        #expect(last.matchesLeft == 1 && !last.rivals.isEmpty)
        #expect(AdvisorText.withinMarginKey(last) == "Within 3 points of you")
    }

    @Test func theEvidenceNoteSaysWhatTheReadingRestsOn() throws {
        #expect(AdvisorText.leagueEvidenceNote(try owners(), rules: EngineParameters.fm27.leagueStandingRules.value)
                == "The places and points are the table's own. The margin of 6 points is your rule (3 with one match left). "
                + "Which lines are within reach or far, and the \u{00D7}1.2 for a side within the margin, are this tool's "
                + "estimate, with no test behind them.")
        // One match left: the reading's margin is 3, and the note still names the rule's 6.
        let last = try reading(settled)
        #expect(last.margin == 3)
        #expect(AdvisorText.leagueEvidenceNote(last, rules: EngineParameters.fm27.leagueStandingRules.value)
                .contains("The margin of 6 points is your rule (3 with one match left)."))
    }
}
