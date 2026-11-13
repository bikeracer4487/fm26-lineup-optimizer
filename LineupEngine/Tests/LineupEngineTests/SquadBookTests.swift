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

    // MARK: - One name in two squads

    private func marsh(_ potential: Int, _ nationalities: [String] = ["England"], age: Int = 25) -> Player {
        var player = Player.fixture(name: "Tyrone Marsh", age: age, potentialAbility: potential)
        player.nationalities = nationalities
        return player
    }

    private func keys(_ book: SquadBook, _ squad: Squad) -> [String] { (book.current[squad] ?? []).map(\.id.key) }

    @Test func aU21PlayerWhoSharesAFirstTeamNameDoesNotDeleteHim() {
        var book = SquadBook()
        book.apply(result([marsh(120), .fixture(name: "B"), .fixture(name: "C")]), to: .firstTeam)
        let change = book.apply(result([marsh(90, age: 18), .fixture(name: "D")]), to: .u21)
        #expect(keys(book, .firstTeam) == ["tyrone marsh", "b", "c"])
        #expect(keys(book, .u21) == ["tyrone marsh#90", "d"])
        #expect(book.allPlayers.filter { $0.name == "Tyrone Marsh" }.map(\.potentialAbility) == [120, 90])
        #expect(change.movedIn.isEmpty)
        #expect(change.added == [PlayerID(key: "tyrone marsh#90"), PlayerID(key: "d")])
        #expect(book.warnings(override: nil) == [.sharedName("Tyrone Marsh")])
    }

    @Test(arguments: [true, false])
    func reimportingEitherSquadKeepsBothKeys(firstTeamFirst: Bool) {
        let senior = result([marsh(120), .fixture(name: "B")])
        let junior = result([marsh(90, age: 18), .fixture(name: "D")])
        var book = SquadBook()
        if firstTeamFirst {
            book.apply(senior, to: .firstTeam); book.apply(junior, to: .u21)
        } else {
            book.apply(junior, to: .u21); book.apply(senior, to: .firstTeam)
        }
        let before = (keys(book, .firstTeam), keys(book, .u21))
        #expect(before.0.contains(firstTeamFirst ? "tyrone marsh" : "tyrone marsh#120"))
        #expect(before.1.contains(firstTeamFirst ? "tyrone marsh#90" : "tyrone marsh"))
        for (squad, paste) in [(Squad.firstTeam, senior), (.u21, junior), (.firstTeam, senior), (.u21, junior)] {
            let change = book.apply(paste, to: squad)
            #expect(keys(book, .firstTeam) == before.0 && keys(book, .u21) == before.1)
            #expect(change.added.isEmpty && change.removed.isEmpty && change.movedIn.isEmpty && change.changed.isEmpty)
        }
        // A birthday does not change either key.
        book.apply(result([marsh(90, age: 19), .fixture(name: "D")]), to: .u21)
        #expect(keys(book, .firstTeam) == before.0 && keys(book, .u21) == before.1)
        #expect(book.warnings(override: nil) == [.sharedName("Tyrone Marsh")])
    }

    @Test func aPlayerWithEqualPotentialAndNationalitiesMoves() {
        var book = SquadBook()
        book.apply(result([marsh(90, ["England", "Jamaica"], age: 18), .fixture(name: "B")]), to: .u21)
        let change = book.apply(result([marsh(90, ["England", "Jamaica"], age: 19)]), to: .firstTeam)
        #expect(keys(book, .u21) == ["b"])
        #expect(keys(book, .firstTeam) == ["tyrone marsh"])
        #expect(change.movedIn == [PlayerID(key: "tyrone marsh")])
        #expect(book.warnings(override: nil).isEmpty)
    }

    @Test func aDifferentSecondNationalityMeansADifferentPlayer() {
        var book = SquadBook()
        book.apply(result([marsh(90, ["England", "Jamaica"])]), to: .u21)
        let change = book.apply(result([marsh(90, ["England"])]), to: .firstTeam)
        #expect(keys(book, .u21) == ["tyrone marsh"])
        #expect(keys(book, .firstTeam) == ["tyrone marsh#90"])
        #expect(change.movedIn.isEmpty)
    }

    @Test func aReKeyTakenBySomeoneElseAddsTheFirstNationality() {
        var book = SquadBook()
        book.apply(result([marsh(120)]), to: .firstTeam)
        book.apply(result([marsh(90, ["Wales"])]), to: .u18)
        #expect(keys(book, .u18) == ["tyrone marsh#90"])
        let change = book.apply(result([marsh(90, ["England"])]), to: .u21)
        #expect(keys(book, .u21) == ["tyrone marsh#90#england"])
        #expect(keys(book, .firstTeam) == ["tyrone marsh"] && keys(book, .u18) == ["tyrone marsh#90"])
        #expect(change.movedIn.isEmpty)
        #expect(book.warnings(override: nil) == [.sharedName("Tyrone Marsh")])
    }

    @Test func aReKeyHeldByTheSamePlayerElsewhereIsAMove() {
        var book = SquadBook()
        book.apply(result([marsh(120)]), to: .firstTeam)
        book.apply(result([marsh(90, ["Wales"]), .fixture(name: "E")]), to: .u18)
        let change = book.apply(result([marsh(90, ["Wales"])]), to: .u21)
        #expect(keys(book, .u21) == ["tyrone marsh#90"])
        #expect(keys(book, .u18) == ["e"])
        #expect(change.movedIn == [PlayerID(key: "tyrone marsh#90")])
    }

    // MARK: - Identity kept when namesakes join, leave or move

    /// The player as the importer keys him when a namesake shares his paste.
    private func keyed(_ player: Player, _ key: String) -> Player {
        var player = player
        player.id = PlayerID(key: key)
        return player
    }

    /// Each player in the book as name and potential ability, sorted.
    private func people(_ book: SquadBook) -> [String] {
        book.allPlayers.map { "\($0.name) \($0.potentialAbility)" }.sorted()
    }

    @Test func aRealMoveIsSeenEvenWhenANamesakeIsInTheDestinationPaste() {
        var book = SquadBook()
        book.apply(result([marsh(90, age: 18), .fixture(name: "D")]), to: .u21)
        book.apply(result([marsh(120), .fixture(name: "B")]), to: .firstTeam)
        #expect(keys(book, .u21) == ["tyrone marsh", "d"])
        #expect(keys(book, .firstTeam) == ["tyrone marsh#120", "b"])
        // The 90 player moves up; the importer keys both Marshes by potential ability.
        let change = book.apply(result([keyed(marsh(120), "tyrone marsh#120"), keyed(marsh(90, age: 18), "tyrone marsh#90"),
                                        .fixture(name: "B")]), to: .firstTeam)
        #expect(change.movedIn == [PlayerID(key: "tyrone marsh")])
        #expect(keys(book, .u21) == ["d"])
        let marshes = book.allPlayers.filter { $0.name == "Tyrone Marsh" }
        #expect(marshes.map(\.potentialAbility) == [120, 90])
        #expect(Set(marshes.map(\.id)).count == 2)
        #expect(keys(book, .firstTeam) == ["tyrone marsh#120", "tyrone marsh", "b"])
    }

    @Test func aNamesakeJoiningThePasteDoesNotChangeAnExistingPlayersKey() {
        var book = SquadBook()
        book.apply(result([marsh(120), .fixture(name: "B")]), to: .firstTeam)
        let change = book.apply(result([keyed(marsh(120), "tyrone marsh#120"), keyed(marsh(90), "tyrone marsh#90"),
                                        .fixture(name: "B")]), to: .firstTeam)
        #expect(keys(book, .firstTeam) == ["tyrone marsh", "tyrone marsh#90", "b"])
        #expect(change.added == [PlayerID(key: "tyrone marsh#90")])
        #expect(change.removed.isEmpty && change.movedIn.isEmpty && change.changed.isEmpty)
    }

    @Test func aNamesakeLeavingDoesNotChangeTheRemainingPlayersKey() {
        // Both Marshes arrive together, so each holds a key with his potential ability.
        var book = SquadBook()
        book.apply(result([keyed(marsh(120), "tyrone marsh#120"), keyed(marsh(90), "tyrone marsh#90"),
                           .fixture(name: "B")]), to: .firstTeam)
        let change = book.apply(result([marsh(120), .fixture(name: "B")]), to: .firstTeam)
        #expect(keys(book, .firstTeam) == ["tyrone marsh#120", "b"])
        #expect(change.removed == [PlayerID(key: "tyrone marsh#90")])
        #expect(change.added.isEmpty && change.movedIn.isEmpty && change.changed.isEmpty)

        // He arrived alone with the plain key; a namesake joins and then leaves again.
        var plain = SquadBook()
        plain.apply(result([marsh(120)]), to: .firstTeam)
        plain.apply(result([keyed(marsh(120), "tyrone marsh#120"), keyed(marsh(90), "tyrone marsh#90")]), to: .firstTeam)
        let left = plain.apply(result([marsh(120)]), to: .firstTeam)
        #expect(keys(plain, .firstTeam) == ["tyrone marsh"])
        #expect(left.removed == [PlayerID(key: "tyrone marsh#90")])
        #expect(left.added.isEmpty && left.changed.isEmpty)
    }

    @Test(arguments: [true, false])
    func theSameSequenceInEitherImportOrderLosesNobody(firstTeamFirst: Bool) {
        let senior = result([marsh(120), .fixture(name: "B")])
        let junior = result([marsh(90, age: 18), .fixture(name: "D")])
        var book = SquadBook()
        if firstTeamFirst {
            book.apply(senior, to: .firstTeam); book.apply(junior, to: .u21)
        } else {
            book.apply(junior, to: .u21); book.apply(senior, to: .firstTeam)
        }
        let everyone = ["B 120", "D 120", "Tyrone Marsh 120", "Tyrone Marsh 90"]
        #expect(people(book) == everyone)
        let seniorKey = keys(book, .firstTeam)[0], juniorKey = keys(book, .u21)[0]

        // The 90 player moves up: the first team is pasted with both Marshes, then the U21 without him.
        book.apply(result([keyed(marsh(120), "tyrone marsh#120"), keyed(marsh(90, age: 18), "tyrone marsh#90"),
                           .fixture(name: "B")]), to: .firstTeam)
        #expect(people(book) == everyone)
        #expect(Set(book.allPlayers.map(\.id)).count == everyone.count)
        book.apply(result([.fixture(name: "D")]), to: .u21)
        #expect(people(book) == everyone)
        #expect(keys(book, .firstTeam) == [seniorKey, juniorKey, "b"])
        #expect(keys(book, .u21) == ["d"])
    }

    @Test(arguments: [Squad.firstTeam, .u21])
    func indistinguishableNamesakesDoNotBothClaimOneExistingKey(existingIn: Squad) {
        var book = SquadBook()
        book.apply(result([marsh(90), .fixture(name: "B")]), to: existingIn)
        // Same name, potential ability and nationalities: the importer numbers them.
        let change = book.apply(result([keyed(marsh(90), "tyrone marsh#90#england#1"),
                                        keyed(marsh(90), "tyrone marsh#90#england#2")]), to: .firstTeam)
        #expect(keys(book, .firstTeam) == ["tyrone marsh", "tyrone marsh#90#england#2"])
        #expect(book.allPlayers.filter { $0.name == "Tyrone Marsh" }.count == 2)
        #expect(change.movedIn == (existingIn == .u21 ? [PlayerID(key: "tyrone marsh")] : []))
    }

    @Test func aPlayerWithNoNationalityStillGetsAStableKey() {
        var book = SquadBook()
        book.apply(result([marsh(120, [])]), to: .firstTeam)
        book.apply(result([marsh(90, ["Wales"])]), to: .u18)
        // His plain key and his potential-ability key are held by others, and with no
        // nationality the next key is the same, so the numbered fallback decides.
        book.apply(result([marsh(90, [])]), to: .u21)
        #expect(keys(book, .u21) == ["tyrone marsh#90#1"])
        #expect(keys(book, .firstTeam) == ["tyrone marsh"] && keys(book, .u18) == ["tyrone marsh#90"])
        #expect(Set(book.allPlayers.map(\.id)).count == 3)

        // The Welsh namesake leaves; the U21 player's key does not follow.
        book.apply(result([.fixture(name: "E")]), to: .u18)
        let change = book.apply(result([marsh(90, [])]), to: .u21)
        #expect(keys(book, .u21) == ["tyrone marsh#90#1"])
        #expect(change.added.isEmpty && change.removed.isEmpty && change.movedIn.isEmpty && change.changed.isEmpty)
    }

    @Test func aKeptKeyThatEqualsANewcomersImporterKeyReKeysTheNewcomer() {
        // Two England-first Marshes of potential 90, numbered by the importer.
        let kept = marsh(90, ["England", "Jamaica"]), leaving = marsh(90, ["England"]), newcomer = marsh(90, ["England", "France"])
        var book = SquadBook()
        book.apply(result([keyed(kept, "tyrone marsh#90#england#1"), keyed(leaving, "tyrone marsh#90#england#2")]), to: .firstTeam)
        // In the next paste the newcomer is first, so the importer gives him the kept player's key.
        let change = book.apply(result([keyed(newcomer, "tyrone marsh#90#england#1"), keyed(kept, "tyrone marsh#90#england#2")]),
                                to: .firstTeam)
        // The existing re-key rules append to his importer key, starting with potential ability.
        #expect(keys(book, .firstTeam) == ["tyrone marsh#90#england#1#90", "tyrone marsh#90#england#1"])
        #expect(book.current[.firstTeam]?.map(\.nationalities) == [newcomer.nationalities, kept.nationalities])
        #expect(change.added == [PlayerID(key: "tyrone marsh#90#england#1#90")])
        #expect(change.removed == [PlayerID(key: "tyrone marsh#90#england#2")])
        #expect(change.changed.isEmpty)
    }

    @Test func oneNameWithOneKeyRaisesNoSharedNameWarning() {
        var book = SquadBook()
        book.apply(result([marsh(120), .fixture(name: "B")]), to: .firstTeam)
        book.apply(result([.fixture(name: "C")]), to: .u21)
        #expect(book.warnings(override: nil).isEmpty)
    }

    @Test func aMoveLeavesTheSourceSquadsPreviousImportAlone() {
        var book = SquadBook()
        let firstU21 = [Player.fixture(name: "A", squad: .u21), .fixture(name: "B", squad: .u21)]
        book.apply(result(firstU21), to: .u21)
        book.apply(result([.fixture(name: "A", squad: .u21), .fixture(name: "C", squad: .u21)]), to: .u21)
        let previous = book.previous[.u21]
        #expect(previous == firstU21)
        book.apply(result([.fixture(name: "A")]), to: .firstTeam)
        #expect(book.current[.u21]?.map(\.name) == ["C"])
        #expect(book.previous[.u21] == previous)
        #expect(book.previous[.firstTeam] == nil)
    }

    @Test func aMovedInPlayerIsNotReportedAsChanged() {
        var book = SquadBook()
        book.apply(result([.fixture(name: "A", condition: 1.0)]), to: .u21)
        book.apply(result([.fixture(name: "B")]), to: .firstTeam)
        let change = book.apply(result([.fixture(name: "A", condition: 0.9), .fixture(name: "B", condition: 0.9)]), to: .firstTeam)
        #expect(change.movedIn == [PlayerID(key: "a")])
        #expect(change.changed == [PlayerID(key: "b")])
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

    // MARK: - Club names compared as names, not as exact strings

    /// Four club-column players at Oxford City and one out on loan.
    private func clubBook() -> SquadBook {
        var book = SquadBook()
        book.apply(result((1...4).map { .fixture(name: "P\($0)", club: "Oxford City") }
                          + [.fixture(name: "Away", club: "Oxford City", loanedTo: "Wallingford")]), to: .firstTeam)
        return book
    }

    @Test(arguments: ["oxford city", "OXFORD CITY", "Oxford  City"])
    func anOverrideInAnotherCaseOrSpacingStillMatchesTheClubColumn(_ override: String) throws {
        let book = clubBook()
        #expect(book.ownClub(override: override) == override)
        let own = try #require(book.allPlayers.first { $0.name == "P1" })
        #expect(book.loanStatus(of: own, override: override) == .own)
        let away = try #require(book.allPlayers.first { $0.name == "Away" })
        #expect(book.loanStatus(of: away, override: override) == .loanedOut(to: "Wallingford"))
        // A genuinely different club still makes the club column a loan.
        #expect(book.loanStatus(of: own, override: "Reading") == .loanedIn(from: "Oxford City"))
    }

    @Test func aTrailingSpaceOverrideIsTrimmedAndMatches() throws {
        let book = clubBook()
        #expect(book.ownClub(override: "Oxford City ") == "Oxford City")
        #expect(book.ownClub(override: "  Reading\t") == "Reading")
        let own = try #require(book.allPlayers.first { $0.name == "P1" })
        #expect(book.loanStatus(of: own, override: "Oxford City ") == .own)
    }

    @Test(arguments: [" ", "   ", "\t"])
    func aWhitespaceOnlyOverrideCountsAsNoOverride(_ blank: String) {
        #expect(clubBook().ownClub(override: blank) == "Oxford City")
        var noClubs = SquadBook()
        noClubs.apply(result([.fixture(name: "A", club: nil, loanedTo: "Wallingford")]), to: .firstTeam)
        #expect(noClubs.ownClub(override: blank) == nil)
        #expect(noClubs.warnings(override: blank) == [.ownClubUnknown])
        #expect(noClubs.warnings(override: "Oxford City").isEmpty)
    }

    @Test func aLoanToTheOwnClubInAnotherCaseIsALoanIn() {
        let loanee = Player.fixture(club: "Reading", loanedTo: "OXFORD CITY")
        #expect(LoanStatus.of(loanee, ownClub: "Oxford City") == .loanedIn(from: "Reading"))
        #expect(LoanStatus.of(.fixture(club: "oxford city ", loanedTo: nil), ownClub: "Oxford City") == .own)
        #expect(LoanStatus.of(.fixture(club: "Reading", loanedTo: "Wallingford"), ownClub: "Oxford City") == .loanedOut(to: "Wallingford"))
    }

    @Test func clubsThatDifferOnlyInCaseCountAsOneClubSpeltAsFirstSeen() {
        var book = SquadBook()
        book.apply(result([.fixture(name: "A", club: "Oxford City"), .fixture(name: "B", club: "oxford city"),
                           .fixture(name: "C", club: "Reading"), .fixture(name: "D", club: "Reading"),
                           .fixture(name: "E", club: "OXFORD CITY ")]), to: .firstTeam)
        #expect(book.ownClub(override: nil) == "Oxford City")
        // Without the variants, Reading is the most common club.
        var plain = SquadBook()
        plain.apply(result([.fixture(name: "A", club: "Oxford City"), .fixture(name: "C", club: "Reading"),
                            .fixture(name: "D", club: "Reading")]), to: .firstTeam)
        #expect(plain.ownClub(override: nil) == "Reading")
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
