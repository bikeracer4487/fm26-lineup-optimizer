import Foundation
import Testing
@testable import LineupEngine

@Suite struct LeagueTests {
    /// Rows in place order; wins are points / 3, draws the remainder, the rest losses; no goals.
    private func table(_ rows: [(String, played: Int, points: Int)]) -> LeagueTable {
        LeagueTable(teams: rows.map { name, played, points in
            let won = points / 3, drawn = points % 3
            return LeagueTeam(name: name, played: played, won: won, drawn: drawn, lost: played - won - drawn,
                              goalsFor: 0, goalsAgainst: 0, points: points)
        }, orderWorkedOut: false, warnings: [])
    }

    private func read(_ table: LeagueTable, _ format: LeagueFormat, club: String = "Me",
                      parameters: EngineParameters = .fm27) throws -> LeagueReading {
        try League.read(table: table, format: format, club: club, parameters: parameters)
    }

    private let six = LeagueFormat(promoted: 1, playOffs: 2, relegated: 1)

    /// A league of six, season 10 matches, the club in third place; `d` is the side in fourth place.
    private func sixTable(me: (Int, Int) = (9, 14), a: (Int, Int) = (9, 20), d: (Int, Int) = (9, 10)) -> LeagueTable {
        table([("A", a.0, a.1), ("B", 9, 16), ("Me", me.0, me.1), ("D", d.0, d.1), ("E", 9, 8), ("F", 9, 2)])
    }

    // MARK: the format

    @Test func byesAreTheNextPowerOfTwoLessTheCount() {
        let byes = (0...9).map { LeagueFormat(promoted: 0, playOffs: $0, relegated: 0).byes }
        #expect(byes == [0, 0, 0, 1, 0, 3, 2, 1, 0, 7])
    }

    @Test func theOwnersLeagueHasFourLines() throws {
        let lines = try LeagueFormat(promoted: 1, playOffs: 6, relegated: 4).lines(teams: 24)
        #expect(lines == [LeagueLine(kind: .promotion, after: 1), LeagueLine(kind: .bye, after: 3),
                          LeagueLine(kind: .playOff, after: 7), LeagueLine(kind: .relegation, after: 20)])
    }

    @Test func aLineThatDoesNotExistIsLeftOut() throws {
        #expect(try LeagueFormat(promoted: 0, playOffs: 4, relegated: 0).lines(teams: 24) == [LeagueLine(kind: .playOff, after: 4)])
        #expect(try LeagueFormat(promoted: 0, playOffs: 0, relegated: 0).lines(teams: 24).isEmpty)
    }

    @Test func aFormatLargerThanTheTableIsRefused() throws {
        #expect(throws: LeagueFormatError.tooMany(format: LeagueFormat(promoted: 1, playOffs: 6, relegated: 4), teams: 10)) {
            try LeagueFormat(promoted: 1, playOffs: 6, relegated: 4).lines(teams: 10)
        }
        _ = try LeagueFormat(promoted: 1, playOffs: 6, relegated: 3).lines(teams: 10)
    }

    @Test func aNegativeNumberIsRefused() throws {
        let format = LeagueFormat(promoted: 1, playOffs: -1, relegated: 4)
        #expect(throws: LeagueFormatError.negative(.playOffs, -1)) { try format.check(teams: nil) }
        #expect(throws: LeagueFormatError.negative(.playOffs, -1)) { try format.lines(teams: 24) }
        try LeagueFormat(promoted: 1, playOffs: 30, relegated: 4).check(teams: nil)
    }

    // MARK: the owner's table

    @Test func theOwnersTableReadsAsTheDesignSays() throws {
        let t = try LeagueTableImporter.read(clipboard: Fixtures.leagueTable, fmrteConfig: Fixtures.leagueTableGrids,
                                             ownClub: "Oxford City", parameters: .fm27)
        let r = try read(t, LeagueFormat(promoted: 1, playOffs: 6, relegated: 4), club: "Oxford City")
        #expect(r.place == 5 && r.points == 74 && r.matchesLeft == 3 && r.mostReachable == 83 && r.margin == 6)
        #expect(r.lines.map(\.state) == [.outOfReach, .close, .close, .safe])
        #expect(r.lines.map(\.isAbove) == [false, false, true, true])
        #expect(r.lines.map(\.gap) == [nil, 3, 6, nil])
        #expect(r.lines.map { $0.other?.name } == ["Chester", "Spalding", "Morecambe", nil])
        #expect(r.situation == .titleRaceOrRelegationFight)
        #expect(r.decidedBy?.line.kind == .playOff)
        #expect(r.rivals == [.init(name: "Spalding", pointsAhead: 3), .init(name: "Hednesford", pointsAhead: 1),
                             .init(name: "Buxton", pointsAhead: 0), .init(name: "Macclesfield", pointsAhead: -1),
                             .init(name: "Morecambe", pointsAhead: -6)])
        #expect(r.basis == .derived)
        #expect(!r.seasonIsOver)
    }

    // MARK: each rule, in a league of six

    @Test func aPlaceIsSafeWhenTooFewCanStillCatchHim() throws {
        let r = try read(sixTable(), six)
        #expect(r.lines[1].line.kind == .playOff && r.lines[1].state == .safe && r.lines[1].gap == nil && r.lines[1].other == nil)
    }

    @Test func aSideThatCanOnlyDrawLevelCanStillCatchHim() throws {
        let r = try read(sixTable(d: (9, 11)), six)
        let line = r.lines[1]
        #expect(line.line.kind == .playOff && line.state == .close && line.gap == 3 && line.other?.name == "D")
    }

    @Test func aLineIsOutOfReachWhenEnoughSidesAreBeyondHisMost() throws {
        let t = table([("A", 9, 20), ("Me", 9, 16), ("C", 9, 12), ("D", 9, 10), ("E", 9, 8), ("F", 9, 2)])
        let r = try read(t, six)
        #expect(r.mostReachable == 19)
        #expect(r.lines[0].line.kind == .promotion && r.lines[0].state == .outOfReach && r.lines[0].gap == nil)
        #expect(r.lines[0].other?.name == "A")
    }

    @Test func levelWithHisMostIsNotOutOfReach() throws {
        let t = table([("A", 9, 19), ("Me", 9, 16), ("C", 9, 12), ("D", 9, 10), ("E", 9, 8), ("F", 9, 2)])
        let r = try read(t, six)
        #expect(r.lines[0].state == .close && r.lines[0].gap == 3)
    }

    @Test func theMarginIsThreeWithOneMatchLeft() throws {
        let far = try read(sixTable(d: (8, 10)), six)
        #expect(far.margin == 3)
        #expect(far.lines[1].state == .far && far.lines[1].gap == 4)
        let close = try read(sixTable(d: (8, 11)), six)
        #expect(close.lines[1].state == .close && close.lines[1].gap == 3 && close.margin == 3)
    }

    @Test func theMarginIsSixWithTwoMatchesLeft() throws {
        func league(d: (Int, Int)) -> LeagueTable {
            table([("A", 8, 20), ("B", 8, 16), ("Me", 8, 14), ("D", d.0, d.1), ("E", 8, 5), ("F", 8, 2)])
        }
        let close = try read(league(d: (8, 8)), six)
        #expect(close.margin == 6 && close.lines[1].state == .close && close.lines[1].gap == 6)
        let far = try read(league(d: (7, 7)), six)
        #expect(far.lines[1].state == .far && far.lines[1].gap == 7)
    }

    @Test func everythingSettledIsNothingToPlayFor() throws {
        let t = table([("A", 9, 30), ("B", 9, 25), ("C", 9, 20), ("Me", 9, 15), ("E", 9, 4), ("F", 9, 1)])
        let r = try read(t, LeagueFormat(promoted: 1, playOffs: 1, relegated: 1))
        #expect(r.lines.allSatisfy { $0.state == .safe || $0.state == .outOfReach })
        #expect(r.situation == .nothingToPlayFor && r.decidedBy == nil)
    }

    @Test func aSeasonThatIsOverHasNoSituationAndNobodyBattled() throws {
        let t = table([("A", 10, 20), ("B", 10, 16), ("Me", 10, 14), ("D", 10, 14), ("E", 10, 8), ("F", 10, 2)])
        let r = try read(t, six)
        #expect(r.matchesLeft == 0 && r.seasonIsOver)
        #expect(r.situation == nil && r.rivals.isEmpty && r.lines.isEmpty && r.decidedBy == nil)
    }

    @Test func noLinesIsNothingToPlayFor() throws {
        let r = try read(sixTable(), LeagueFormat(promoted: 0, playOffs: 0, relegated: 0))
        #expect(r.situation == .nothingToPlayFor && r.lines.isEmpty && r.decidedBy == nil)
    }

    // MARK: a league of 24

    private let owners = LeagueFormat(promoted: 1, playOffs: 6, relegated: 4)

    /// 24 teams, the club "Me" in place 7 (the last play-off place) on 50 points, "Next" in place 8 `gap` points behind;
    /// the six above are far ahead and the rest far behind. Every side has played 46 - `left` matches.
    private func league(left: Int, gapToPlayOff gap: Int) -> LeagueTable {
        let played = 46 - left
        var rows: [(String, played: Int, points: Int)] = []
        for place in 1...24 {
            switch place {
            case 1...6: rows.append(("T\(place)", played, 200 - place))
            case 7: rows.append(("Me", played, 50))
            case 8: rows.append(("Next", played, 50 - gap))
            default: rows.append(("T\(place)", played, max(0, 20 - place)))
            }
        }
        return table(rows)
    }

    @Test func aCloseLineIsTheTopSituationOnlyInTheLastTen() throws {
        // Me is in 7th, last place in the play-offs; the side behind is 3 points back with a match left to play.
        let ten = try read(league(left: 10, gapToPlayOff: 3), owners)
        #expect(ten.lines.first { $0.line.kind == .playOff }?.state == .close)
        #expect(ten.situation == .titleRaceOrRelegationFight)
        let eleven = try read(league(left: 11, gapToPlayOff: 3), owners)
        #expect(eleven.situation == .inContention)
    }

    @Test func theByeLineAloneLiftsOnlyToInContention() throws {
        var rows: [(String, played: Int, points: Int)] = []
        for place in 1...24 {
            switch place {
            case 1: rows.append(("T1", 43, 200))
            case 2: rows.append(("T2", 43, 150))
            case 3: rows.append(("Me", 43, 100))
            case 4: rows.append(("Next", 43, 97))
            case 5...7: rows.append(("T\(place)", 43, 60 - place))
            default: rows.append(("T\(place)", 43, max(0, 20 - place)))
            }
        }
        // With T5 to T7 ten or more behind and the others far off, only the bye line is close.
        let r = try read(table(rows), owners, club: "Me")
        let bye = try #require(r.lines.first { $0.line.kind == .bye })
        #expect(bye.state == .close)
        #expect(r.lines.filter { $0.state == .close }.count == 1)
        #expect(r.situation == .inContention)
        #expect(r.decidedBy?.line.kind == .bye)
    }

    @Test func aLineWithinAPointAMatchIsInContention() throws {
        let within = try read(league(left: 9, gapToPlayOff: 9), owners)
        let playOff = try #require(within.lines.first { $0.line.kind == .playOff })
        #expect(playOff.state == .withinReach && playOff.gap == 9)
        #expect(within.situation == .inContention)
        let far = try read(league(left: 9, gapToPlayOff: 10), owners)
        #expect(far.lines.first { $0.line.kind == .playOff }?.state == .far)
        #expect(far.situation == .midTable)
    }

    @Test func theNearestLineDecides() throws {
        // Club in place 2 of six: promotion is one place above, relegation after place 4.
        let t = table([("A", 8, 21), ("Me", 8, 16), ("C", 8, 14), ("D", 8, 12), ("E", 8, 12), ("F", 8, 2)])
        let promotionAndRelegation = LeagueFormat(promoted: 1, playOffs: 0, relegated: 2)
        let r = try read(t, promotionAndRelegation)
        let gaps = r.lines.map(\.gap)
        #expect(r.lines.map(\.state) == [.close, .close])
        #expect(gaps == [5, 4])
        #expect(r.decidedBy?.line.kind == .relegation)
        // Equal gaps: the earlier line.
        let same = table([("A", 8, 21), ("Me", 8, 16), ("C", 8, 14), ("D", 8, 11), ("E", 8, 11), ("F", 8, 2)])
        let tie = try read(same, promotionAndRelegation)
        #expect(tie.lines.map(\.gap) == [5, 5])
        #expect(tie.decidedBy?.line.kind == .promotion)
    }

    private func battleTable(left: Int, aheadAndBehind offset: Int) -> LeagueTable {
        let played = 46 - left
        var rows: [(String, played: Int, points: Int)] = []
        for place in 1...24 {
            switch place {
            case 1...9: rows.append(("T\(place)", played, 300 - place))
            case 10: rows.append(("Ahead", played, 100 + offset))
            case 11: rows.append(("Me", played, 100))
            case 12: rows.append(("Behind", played, 100 - offset))
            default: rows.append(("T\(place)", played, max(0, 10 - place)))
            }
        }
        return table(rows)
    }

    @Test func sidesWithinTheMarginAreBattledEitherWay() throws {
        let inside = try read(battleTable(left: 3, aheadAndBehind: 6), owners)
        #expect(inside.rivals == [.init(name: "Ahead", pointsAhead: 6), .init(name: "Behind", pointsAhead: -6)])
        let outside = try read(battleTable(left: 3, aheadAndBehind: 7), owners)
        #expect(outside.rivals.isEmpty)
    }

    @Test func withOneMatchLeftOnlySidesWithinThreeAreBattled() throws {
        let inside = try read(battleTable(left: 1, aheadAndBehind: 3), owners)
        #expect(inside.rivals.map(\.name) == ["Ahead", "Behind"])
        let outside = try read(battleTable(left: 1, aheadAndBehind: 4), owners)
        #expect(outside.rivals.isEmpty)
    }

    @Test func nobodyIsBattledBeforeTheLastTen() throws {
        let eleven = try read(battleTable(left: 11, aheadAndBehind: 0), owners)
        #expect(eleven.rivals.isEmpty)
        let ten = try read(battleTable(left: 10, aheadAndBehind: 0), owners)
        #expect(ten.rivals.map(\.name) == ["Ahead", "Behind"])
    }

    @Test func atTheStartOfTheSeasonNobodyIsBattledAndTheSituationIsInContention() throws {
        let t = table((1...24).map { place in (place == 5 ? "Me" : "T\(place)", played: 0, points: 0) })
        let r = try read(t, owners)
        #expect(r.situation == .inContention)
        #expect(r.rivals.isEmpty)
    }

    @Test func aLineWithNoSideAcrossItIsLeftOutAndTheReadingStillWorks() throws {
        let full = LeagueFormat(promoted: 1, playOffs: 5, relegated: 0)
        #expect(try full.lines(teams: 6) == [LeagueLine(kind: .promotion, after: 1), LeagueLine(kind: .bye, after: 4)])
        let r = try read(sixTable(), full)
        #expect(r.lines.map(\.line.kind) == [.promotion, .bye])
    }

    @Test func aClubNotInTheTableIsRefused() throws {
        let t = table((1...24).map { ("T\($0)", played: 0, points: 0) })
        #expect(throws: LeagueTableError.clubNotInTable(club: "Nobody", teams: 24)) {
            try read(t, owners, club: "Nobody")
        }
    }

    @Test func aFormatThatDoesNotFitTheTableIsRefused() throws {
        let t = table((1...10).map { (place: Int) in (place == 3 ? "Me" : "T\(place)", played: 0, points: 0) })
        #expect(throws: LeagueFormatError.tooMany(format: LeagueFormat(promoted: 1, playOffs: 6, relegated: 4), teams: 10)) { try read(t, owners) }
    }

    @Test func badParametersAreRefused() throws {
        var q = EngineParameters.fm27
        var rules = q.leagueStandingRules.value
        rules.marginPoints = -1
        q.leagueStandingRules = Parameter(rules, .derived, source: "test")
        #expect(throws: PlanError.self) { try read(sixTable(), six, parameters: q) }
    }

    // MARK: which fixtures the table speaks for

    private func fx(_ id: String, _ iso: String, confirmed: Bool = false) -> (id: FixtureID, date: Day, isConfirmed: Bool) {
        (FixtureID(id), Day(iso: iso)!, confirmed)
    }

    private let pasted = Day(iso: "2026-11-19")!

    @Test func aTableSpeaksForAsManyFixturesAsItHasMatchesLeft() {
        let fixtures = [fx("e", "2026-12-20"), fx("a", "2026-11-21"), fx("c", "2026-12-05"), fx("b", "2026-11-28"),
                        fx("d", "2026-12-12")]
        #expect(League.spokenFor(matchesLeft: 3, pastedOn: pasted, leagueFixtures: fixtures)
                == [FixtureID("a"), FixtureID("b"), FixtureID("c")])
    }

    @Test func aFixtureOnTheDayCountsUnlessItWasConfirmed() {
        let open = [fx("today", "2026-11-19"), fx("a", "2026-11-21"), fx("b", "2026-11-28")]
        #expect(League.spokenFor(matchesLeft: 2, pastedOn: pasted, leagueFixtures: open) == [FixtureID("today"), FixtureID("a")])
        let played = [fx("today", "2026-11-19", confirmed: true), fx("a", "2026-11-21"), fx("b", "2026-11-28")]
        #expect(League.spokenFor(matchesLeft: 2, pastedOn: pasted, leagueFixtures: played) == [FixtureID("a"), FixtureID("b")])
    }

    @Test func aConfirmedFixtureAfterTheDayUsesUpAMatch() {
        let fixtures = [fx("a", "2026-11-21", confirmed: true), fx("b", "2026-11-28"), fx("c", "2026-12-05"), fx("d", "2026-12-12")]
        #expect(League.spokenFor(matchesLeft: 3, pastedOn: pasted, leagueFixtures: fixtures)
                == [FixtureID("a"), FixtureID("b"), FixtureID("c")])
    }

    @Test func fixturesBeforeTheDayAreNeverSpokenFor() {
        let fixtures = [fx("a", "2026-11-01"), fx("b", "2026-11-18", confirmed: true)]
        #expect(League.spokenFor(matchesLeft: 3, pastedOn: pasted, leagueFixtures: fixtures).isEmpty)
    }

    @Test func noMatchesLeftSpeaksForNothing() {
        #expect(League.spokenFor(matchesLeft: 0, pastedOn: pasted, leagueFixtures: [fx("a", "2026-11-21")]).isEmpty)
    }

    @Test func fixturesOnOneDayAreTakenByIdOrder() {
        let fixtures = [fx("b", "2026-11-21"), fx("a", "2026-11-21")]
        #expect(League.spokenFor(matchesLeft: 1, pastedOn: pasted, leagueFixtures: fixtures) == [FixtureID("a")])
    }
}
