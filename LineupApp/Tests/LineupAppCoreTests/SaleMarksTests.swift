import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

/// The owner's marks on players to sell or loan out: made, kept, dropped when spent, and handed to the planner.
@MainActor @Suite struct SaleMarksTests {
    private func day(_ iso: String) -> Day { Day(iso: iso)! }

    /// The captured first team's rows, each split into its cells. Cell 2 is the name and cell 96 the club he is
    /// loaned to, both quoted.
    private func rows() throws -> [[String]] {
        try Captures.firstTeam.split(whereSeparator: \.isNewline)
            .map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
    }

    private func paste(_ rows: [[String]]) -> String {
        rows.map { $0.joined(separator: "\t") }.joined(separator: "\n") + "\n"
    }

    private func loaned(_ rows: [[String]], _ indices: [Int], to club: String) -> [[String]] {
        var rows = rows
        for index in indices { rows[index][96] = "\"\(club)\"" }
        return rows
    }

    /// The cells of the captured first team's contract type and months left, both quoted.
    private static let contractCell = 18
    private static let monthsLeftCell = 16

    /// The rows with the players on `indices` on youth contracts, their months left as captured (none is 0).
    private func onYouthContracts(_ rows: [[String]], _ indices: [Int]) -> [[String]] {
        var rows = rows
        for index in indices { rows[index][Self.contractCell] = "\"Youth\"" }
        return rows
    }

    /// The player on the given row of the capture, found by his name.
    private func player(onRow index: Int, _ model: AppModel) throws -> PlayerID {
        let name = try rows()[index][2].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        return try #require(model.players.first { $0.name == name }).id
    }

    /// The club named, the first team imported, a tactic, and a low fixture followed by a high one.
    private func ready() throws -> (t: TestModel, low: FixtureID, high: FixtureID) {
        let t = try TestModel()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        try t.importFirstTeam()
        t.model.addTactic(named: "Main")
        let low = t.model.addFixture(date: day("2026-11-14"), opponent: "Rovers", importance: .low)
        let high = t.model.addFixture(date: day("2026-11-17"), opponent: "United", importance: .high)
        return (t, low, high)
    }

    private func picks(_ model: AppModel, _ fixture: FixtureID,
                       sourceLocation: SourceLocation = #_sourceLocation) -> [Pick] {
        guard case .ready(let plans) = model.planState,
              case .planned(let lineup, _)? = plans.first(where: { $0.id == fixture })?.body else {
            Issue.record("expected a planned lineup, got \(model.planState)", sourceLocation: sourceLocation)
            return []
        }
        return lineup.picks
    }

    // MARK: Making a mark

    @Test func markingAPlayerSavesIt() throws {
        let (t, _, _) = try ready()
        let own = try player(onRow: 0, t.model)
        t.model.setMark(.toSell, for: own)
        #expect(t.model.marks == [own: .toSell])
        #expect(t.reopened().marks == [own: .toSell])
    }

    @Test func clearingAMarkRemovesIt() throws {
        let (t, _, _) = try ready()
        let own = try player(onRow: 0, t.model)
        t.model.setMark(.toSell, for: own)
        t.model.setMark(nil, for: own)
        #expect(t.model.marks.isEmpty)
        #expect(t.reopened().marks.isEmpty)
    }

    @Test func changingAMarkReplacesIt() throws {
        let (t, _, _) = try ready()
        let own = try player(onRow: 0, t.model)
        t.model.setMark(.toSell, for: own)
        t.model.setMark(.toLoanOut, for: own)
        #expect(t.model.marks == [own: .toLoanOut])
    }

    @Test func aPlayerOnLoanHereCannotBeMarked() throws {
        let (t, _, _) = try ready()
        t.importSquad(.firstTeam, paste: paste(loaned(try rows(), [0], to: "Oxford City")), grids: try Captures.firstTeamGrids)
        let loanee = try player(onRow: 0, t.model)
        let status = t.model.squad.book.loanStatus(of: try #require(t.model.players.first { $0.id == loanee }),
                                                   override: t.model.settings.clubOverride)
        guard case .loanedIn = status else { Issue.record("expected a loan in, got \(status)"); return }
        t.model.setMark(.toSell, for: loanee)
        #expect(t.model.marks.isEmpty)
    }

    @Test func aYouthContractPlayerCanBeMarkedToSellAndNotToLoanOut() throws {
        // A player on a youth contract can be sold and cannot be loaned out (the owner's correction of 22 November 2026).
        let (t, _, _) = try ready()
        t.importSquad(.firstTeam, paste: paste(onYouthContracts(try rows(), [0])), grids: try Captures.firstTeamGrids)
        let youth = try player(onRow: 0, t.model)
        let other = try player(onRow: 1, t.model)
        #expect(t.model.players.first { $0.id == youth }?.contractType == .youth)
        t.model.setMark(.toLoanOut, for: youth)
        #expect(t.model.marks.isEmpty)
        t.model.setMark(.toSell, for: youth)
        #expect(t.model.marks == [youth: .toSell])
        #expect(t.reopened().marks == [youth: .toSell])
        // A mark to loan out does not replace his mark to sell.
        t.model.setMark(.toLoanOut, for: youth)
        #expect(t.model.marks == [youth: .toSell])
        // A player on a full-time contract can still be marked either way.
        t.model.setMark(.toLoanOut, for: other)
        #expect(t.model.marks == [youth: .toSell, other: .toLoanOut])
    }

    @Test func aYouthContractPlayerMarkedToSellIsFavouredInTheLowFixture() throws {
        let (t, low, _) = try ready()
        let starter = try #require(picks(t.model, low).first)
        let row = try #require(try rows().firstIndex { $0[2] == "\"\(starter.name)\"" })
        t.importSquad(.firstTeam, paste: paste(onYouthContracts(try rows(), [row])), grids: try Captures.firstTeamGrids)
        #expect(t.model.players.first { $0.id == starter.player }?.contractType == .youth)
        t.model.setMark(.toSell, for: starter.player)
        let marked = try #require(picks(t.model, low).first { $0.player == starter.player })
        #expect(marked.adjustments.contains {
            $0.kind == .shopWindow
                && $0.reason == "Marked to sell: favoured for minutes, an untested way to bring offers (×1.03)"
        })
    }

    @Test func aPlayerNotInAnySquadCannotBeMarked() throws {
        let (t, _, _) = try ready()
        t.model.setMark(.toSell, for: .fmrte(999_999_999))
        #expect(t.model.marks.isEmpty)
    }

    // MARK: The planner

    @Test func theMarksReachThePlanner() throws {
        let (t, low, high) = try ready()
        #expect(!picks(t.model, low).isEmpty)
        #expect(!picks(t.model, low).contains { $0.adjustments.contains { $0.kind == .shopWindow } })
        let starter = try #require(picks(t.model, low).first).player

        t.model.setMark(.toSell, for: starter)
        let marked = try #require(picks(t.model, low).first { $0.player == starter })
        #expect(marked.adjustments.contains {
            $0.kind == .shopWindow
                && $0.reason == "Marked to sell: favoured for minutes, an untested way to bring offers (×1.03)"
        })
        #expect(!picks(t.model, high).isEmpty)
        #expect(!picks(t.model, high).contains { $0.adjustments.contains { $0.kind == .shopWindow } })

        t.model.setMark(nil, for: starter)
        #expect(!picks(t.model, low).contains { $0.adjustments.contains { $0.kind == .shopWindow } })
    }

    @Test func markingDoesNotChangeAConfirmedLineup() throws {
        let (t, low, _) = try ready()
        t.model.confirm(low)
        let confirmed = try #require(t.model.history.first { $0.lineup.fixture == low })
        let starter = try #require(confirmed.lineup.starters.values.sorted { $0.key < $1.key }.first)
        t.model.setMark(.toSell, for: starter)
        #expect(t.model.marks == [starter: .toSell])
        #expect(t.model.history.first { $0.lineup.fixture == low } == confirmed)
        guard case .ready(let plans) = t.model.planState, let plan = plans.first(where: { $0.id == low }) else {
            Issue.record("expected a ready plan, got \(t.model.planState)"); return
        }
        #expect(plan.body == .confirmed(confirmed))
    }

    // MARK: Marks that are spent

    @Test func aMarkGoesWhenThePlayerLeavesEverySquad() throws {
        let (t, _, _) = try ready()
        let leaver = try player(onRow: 0, t.model)
        let stayer = try player(onRow: 1, t.model)
        t.model.setMark(.toSell, for: leaver)
        t.model.setMark(.toSell, for: stayer)
        t.importSquad(.firstTeam, paste: paste(Array(try rows().dropFirst())), grids: try Captures.firstTeamGrids)
        #expect(!t.model.players.contains { $0.id == leaver })
        #expect(t.model.marks == [stayer: .toSell])
        #expect(t.reopened().marks == [stayer: .toSell])
    }

    @Test func aLoanOutMarkGoesOnceHeIsOutOnLoan() throws {
        let (t, _, _) = try ready()
        let loaned = try player(onRow: 0, t.model)
        let listed = try player(onRow: 1, t.model)
        t.model.setMark(.toLoanOut, for: loaned)
        t.model.setMark(.toSell, for: listed)
        t.importSquad(.firstTeam, paste: paste(self.loaned(try rows(), [0, 1], to: "Elsewhere Town")),
                      grids: try Captures.firstTeamGrids)
        #expect(t.model.marks == [listed: .toSell])
        #expect(t.reopened().marks == [listed: .toSell])
    }

    // MARK: Marks that must not go too soon, or stay too long

    /// The first team with its last two players moved to the U21s, so both squads are held.
    private func twoSquads() throws -> (t: TestModel, rows: [[String]]) {
        let (t, _, _) = try ready()
        let rows = try rows()
        t.importSquad(.u21, paste: paste(Array(rows.suffix(2))), grids: try Captures.firstTeamGrids)
        #expect(t.model.squad.book.current[.u21]?.count == 2)
        return (t, rows)
    }

    @Test func aMarkSurvivesAMoveBetweenSquadsImportedOneAfterTheOther() throws {
        let (t, rows) = try twoSquads()
        let moved = try player(onRow: 0, t.model)
        t.model.setMark(.toSell, for: moved)
        // He is dropped to the U21s in the game. The first team is imported first, so for a moment he is in no squad.
        t.importSquad(.firstTeam, paste: paste(Array(rows[1..<(rows.count - 2)])), grids: try Captures.firstTeamGrids)
        #expect(!t.model.players.contains { $0.id == moved })
        #expect(t.model.marks == [moved: .toSell])
        t.importSquad(.u21, paste: paste([rows[0]] + rows.suffix(2)), grids: try Captures.firstTeamGrids)
        #expect(t.model.players.contains { $0.id == moved })
        #expect(t.model.marks == [moved: .toSell])
    }

    @Test func aMarkGoesOnceEverySquadHasBeenImportedWithoutHim() throws {
        let (t, rows) = try twoSquads()
        let gone = try player(onRow: 0, t.model)
        t.model.setMark(.toSell, for: gone)
        t.importSquad(.firstTeam, paste: paste(Array(rows[1..<(rows.count - 2)])), grids: try Captures.firstTeamGrids)
        #expect(t.model.marks == [gone: .toSell])
        t.importSquad(.u21, paste: paste(Array(rows.suffix(2))), grids: try Captures.firstTeamGrids)
        #expect(t.model.marks.isEmpty)
        #expect(t.reopened().marks.isEmpty)
    }

    @Test func aMarkOnAPlayerInNoSquadCanStillBeTakenOff() throws {
        let (t, rows) = try twoSquads()
        let absent = try player(onRow: 0, t.model)
        t.model.setMark(.toSell, for: absent)
        t.importSquad(.firstTeam, paste: paste(Array(rows[1..<(rows.count - 2)])), grids: try Captures.firstTeamGrids)
        #expect(t.model.marks == [absent: .toSell])
        t.model.setMark(nil, for: absent)
        #expect(t.model.marks.isEmpty)
    }

    @Test func aLoanMarkIsDroppedAndASaleMarkKeptWhenItsPlayerIsImportedOnAYouthContract() throws {
        let (t, _, _) = try ready()
        let youth = try player(onRow: 0, t.model)
        let sold = try player(onRow: 1, t.model)
        let loaned = try player(onRow: 2, t.model)
        let youthSold = try player(onRow: 3, t.model)
        t.model.setMark(.toLoanOut, for: youth)
        t.model.setMark(.toSell, for: sold)
        t.model.setMark(.toLoanOut, for: loaned)
        t.model.setMark(.toSell, for: youthSold)
        t.importSquad(.firstTeam, paste: paste(onYouthContracts(try rows(), [0, 3])), grids: try Captures.firstTeamGrids)
        #expect(t.model.marks == [sold: .toSell, loaned: .toLoanOut, youthSold: .toSell])
        #expect(t.reopened().marks == [sold: .toSell, loaned: .toLoanOut, youthSold: .toSell])
        // A youth contract with no months left is read as no contract: a mark to loan out on that player stays.
        var expired = try rows()
        expired[2][Self.contractCell] = "\"Youth\""
        expired[2][Self.monthsLeftCell] = "\"0\""
        t.importSquad(.firstTeam, paste: paste(expired), grids: try Captures.firstTeamGrids)
        #expect(t.model.players.first { $0.id == loaned }?.contractType == .youth)
        #expect(t.model.marks == [sold: .toSell, loaned: .toLoanOut, youthSold: .toSell])
    }

    @Test func aMarkGoesWhenThePlayerBecomesALoanee() throws {
        let (t, _, _) = try ready()
        let soldAndLoanedBack = try player(onRow: 0, t.model)
        t.model.setMark(.toSell, for: soldAndLoanedBack)
        t.importSquad(.firstTeam, paste: paste(loaned(try rows(), [0], to: "Oxford City")), grids: try Captures.firstTeamGrids)
        #expect(t.model.marks.isEmpty)
        #expect(t.reopened().marks.isEmpty)
    }

    @Test func changingTheClubNameDropsAMarkOnAPlayerItMakesALoanee() throws {
        let (t, _, _) = try ready()
        t.importSquad(.firstTeam, paste: paste(loaned(try rows(), [0], to: "Elsewhere Town")), grids: try Captures.firstTeamGrids)
        let away = try player(onRow: 0, t.model)
        let stays = try player(onRow: 1, t.model)
        t.model.setMark(.toSell, for: away)
        t.model.setMark(.toSell, for: stays)
        #expect(t.model.marks == [away: .toSell, stays: .toSell])
        // Named as the club he is loaned to, the same row reads as a loan here.
        var settings = t.model.settings
        settings.clubName = "Elsewhere Town"
        t.model.update(settings)
        #expect(t.model.marks == [stays: .toSell])
        #expect(t.reopened().marks == [stays: .toSell])
    }
}
