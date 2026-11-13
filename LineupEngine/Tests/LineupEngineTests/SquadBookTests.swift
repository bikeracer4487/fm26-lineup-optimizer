import Foundation
import Testing
@testable import LineupEngine

private func result(_ players: [Player]) -> ImportResult {
    ImportResult(grid: "test", players: players, warnings: [])
}

private func book(_ capture: String, squad: Squad) throws -> SquadBook {
    var book = SquadBook()
    book.apply(try Importer.importPlayers(clipboard: Fixtures.text("captures/\(capture).tsv"),
                                          fmrteConfig: Fixtures.data("captures/\(capture).grids.json"),
                                          squad: squad), to: squad)
    return book
}

@Suite struct SquadBookTests {
    @Test func importingASquadLeavesOtherSquadsAlone() {
        var book = SquadBook()
        book.apply(result([.fixture(name: "A"), .fixture(name: "B"), .fixture(name: "C")]), to: .firstTeam)
        book.apply(result([.fixture(name: "D"), .fixture(name: "E")]), to: .u21)
        #expect(book.current[.firstTeam]?.count == 3)
        #expect(book.current[.u21]?.count == 2)
    }

    @Test func importStampsTheSquadItWasAppliedTo() {
        var book = SquadBook()
        book.apply(result([.fixture(name: "A", squad: .firstTeam)]), to: .u18)
        #expect(book.current[.u18]?.first?.squad == .u18)
    }

    @Test func reimportReplacesAndKeepsPrevious() {
        var book = SquadBook()
        let first = [Player.fixture(name: "A", squad: .u21), .fixture(name: "B", squad: .u21)]
        book.apply(result(first), to: .u21)
        let change = book.apply(result([.fixture(name: "B"), .fixture(name: "C")]), to: .u21)
        #expect(book.previous[.u21] == first)
        #expect(book.current[.u21]?.map(\.name) == ["B", "C"])
        #expect(change.added == [PlayerID(key: "c")])
        #expect(change.removed == [PlayerID(key: "a")])
        #expect(change.movedIn.isEmpty && change.changed.isEmpty)
    }

    @Test func aFirstImportHasNoPreviousAndEveryoneIsAdded() {
        var book = SquadBook()
        let change = book.apply(result([.fixture(name: "A")]), to: .u21)
        #expect(book.previous[.u21] == nil)
        #expect(change.added == [PlayerID(key: "a")])
        #expect(change.removed.isEmpty)
    }

    @Test func aPlayerInALaterImportOfAnotherSquadMoves() {
        var book = SquadBook()
        book.apply(result([.fixture(name: "A"), .fixture(name: "B")]), to: .firstTeam)
        let change = book.apply(result([.fixture(name: "A")]), to: .u21)
        #expect(book.current[.firstTeam]?.map(\.name) == ["B"])
        #expect(book.current[.u21]?.map(\.name) == ["A"])
        #expect(change.movedIn == [PlayerID(key: "a")])
        #expect(change.added == [PlayerID(key: "a")])
    }

    @Test func changedListsPlayersWhoseFieldsDiffer() {
        var book = SquadBook()
        book.apply(result([.fixture(name: "A", condition: 1.0), .fixture(name: "B")]), to: .firstTeam)
        let change = book.apply(result([.fixture(name: "A", condition: 0.9), .fixture(name: "B")]), to: .firstTeam)
        #expect(change.changed == [PlayerID(key: "a")])
        #expect(change.added.isEmpty && change.removed.isEmpty)
    }

    @Test func listsFollowImportOrder() {
        var book = SquadBook()
        book.apply(result([.fixture(name: "Z"), .fixture(name: "Y"), .fixture(name: "X")]), to: .u21)
        let change = book.apply(result([.fixture(name: "C"), .fixture(name: "B")]), to: .u21)
        #expect(change.added == [PlayerID(key: "c"), PlayerID(key: "b")])
        #expect(change.removed == [PlayerID(key: "z"), PlayerID(key: "y"), PlayerID(key: "x")])
    }

    @Test func allPlayersRunsFirstTeamThenU21ThenU18() {
        var book = SquadBook()
        book.apply(result([.fixture(name: "U18a")]), to: .u18)
        book.apply(result([.fixture(name: "U21a"), .fixture(name: "U21b")]), to: .u21)
        book.apply(result([.fixture(name: "First")]), to: .firstTeam)
        #expect(book.allPlayers.map(\.name) == ["First", "U21a", "U21b", "U18a"])
    }

    @Test func ownClubIsTheMostCommonClubUnlessOverridden() {
        var book = SquadBook()
        #expect(book.ownClub(override: nil) == nil)
        book.apply(result((1...4).map { .fixture(name: "P\($0)", club: "Oxford City") }
                          + [.fixture(name: "R", club: "Reading")]), to: .firstTeam)
        #expect(book.ownClub(override: nil) == "Oxford City")
        #expect(book.ownClub(override: "Reading") == "Reading")
        #expect(book.ownClub(override: "") == "Oxford City")
    }

    @Test func ownClubTiesGoToTheAlphabeticallyFirst() {
        var book = SquadBook()
        book.apply(result([.fixture(name: "A", club: "Reading"), .fixture(name: "B", club: "Oxford City")]), to: .firstTeam)
        #expect(book.ownClub(override: nil) == "Oxford City")
    }

    @Test func loanStatusFromClubAndLoanFields() {
        let own = "Oxford City"
        func status(club: String?, loanedTo: String?, ownClub: String? = own) -> LoanStatus {
            LoanStatus.of(.fixture(club: club, loanedTo: loanedTo), ownClub: ownClub)
        }
        #expect(status(club: "Oxford City", loanedTo: "Wallingford") == .loanedOut(to: "Wallingford"))
        #expect(status(club: "Reading", loanedTo: "Oxford City") == .loanedIn(from: "Reading"))
        #expect(status(club: nil, loanedTo: "Oxford City") == .loanedIn(from: nil))
        #expect(status(club: "Reading", loanedTo: nil) == .loanedIn(from: "Reading"))
        #expect(status(club: "Oxford City", loanedTo: nil) == .own)
        #expect(status(club: nil, loanedTo: nil) == .own)
        #expect(status(club: nil, loanedTo: "Wallingford", ownClub: nil) == .loanedOut(to: "Wallingford"))
        #expect(status(club: "Reading", loanedTo: nil, ownClub: nil) == .own)
        #expect(status(club: nil, loanedTo: nil, ownClub: nil) == .own)
    }

    @Test func teamGridBookHasNoClubUntilOverridden() throws {
        let book = try book("u21-team-grid", squad: .u21)
        #expect(book.ownClub(override: nil) == nil)
        #expect(book.warnings(override: nil) == [.ownClubUnknown])
        let treml = try #require(book.allPlayers.first { $0.name == "Max Treml" })
        #expect(book.loanStatus(of: treml, override: nil) == .loanedOut(to: "Wallingford"))
        #expect(book.ownClub(override: "Oxford City") == "Oxford City")
        #expect(book.warnings(override: "Oxford City").isEmpty)
    }

    @Test func noLoanMeansNoWarningEvenWithoutAClub() {
        var book = SquadBook()
        book.apply(result([.fixture(name: "A", club: nil)]), to: .firstTeam)
        #expect(book.warnings(override: nil).isEmpty)
    }

    @Test func realU21BookFindsOxfordCityAndOneLoan() throws {
        let book = try book("u21", squad: .u21)
        #expect(book.ownClub(override: nil) == "Oxford City")
        let statuses = book.allPlayers.map { book.loanStatus(of: $0, override: nil) }
        #expect(statuses.filter { if case .loanedOut = $0 { true } else { false } }.count == 1)
        #expect(book.warnings(override: nil).isEmpty)
    }

    @Test func roundTripsThroughJSONWithSquadsAsObjectKeys() throws {
        var book = SquadBook()
        book.apply(result([.fixture(name: "A")]), to: .firstTeam)
        book.apply(result([.fixture(name: "B")]), to: .u21)
        book.apply(result([.fixture(name: "C")]), to: .u21)
        let data = try JSONEncoder().encode(book)
        #expect(try JSONDecoder().decode(SquadBook.self, from: data) == book)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let current = try #require(object["current"] as? [String: Any])
        #expect(Set(current.keys) == ["firstTeam", "u21"])
        let previous = try #require(object["previous"] as? [String: Any])
        #expect(Set(previous.keys) == ["u21"])
    }
}
