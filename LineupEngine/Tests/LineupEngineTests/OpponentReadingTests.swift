import Foundation
import Testing
@testable import LineupEngine

@Suite struct OpponentReadingTests {
    let today = Day(year: 2026, month: 11, day: 15)!
    let parameters = EngineParameters.fm27

    /// Players with distinct names and the club as given (nil for FMRTE's team grid, which has no club column).
    func side(club: String? = nil, loanedTo: String? = nil, abilities: [Int], prefix: String = "Their",
              injured: Bool = false, banned: Bool = false) -> [Player] {
        abilities.enumerated().map { index, ability in
            .fixture(name: "\(prefix) \(index)", currentAbility: ability, isInjured: injured, isBanned: banned,
                     club: club, loanedTo: loanedTo)
        }
    }

    /// The owner's side: eleven players at 100, club nil.
    var own: [Player] { side(abilities: Array(repeating: 100, count: 11), prefix: "Own") }

    func eleven(all ability: Int, oneAt other: Int? = nil) -> [Player] {
        var abilities = Array(repeating: ability, count: 11)
        if let other { abilities[0] = other }
        return side(abilities: abilities)
    }

    func read(theirs: [Player], named: String = "Banbury United", own ownSquad: [Player]? = nil,
              ownClub: String? = "Oxford City", parameters: EngineParameters? = nil) throws -> OpponentReading {
        try OpponentAdvisor.read(theirs: theirs, named: named, own: ownSquad ?? own, ownClub: ownClub, on: today,
                                 parameters: parameters ?? self.parameters)
    }

    func strength(all: Int, oneAt: Int? = nil) throws -> OpponentStrength {
        try read(theirs: eleven(all: all, oneAt: oneAt)).strength
    }

    @Test func eachLineGivesItsStep() throws {
        #expect(try strength(all: 115) == .muchStronger)
        #expect(try strength(all: 115, oneAt: 114) == .stronger)
        #expect(try strength(all: 105) == .stronger)
        #expect(try strength(all: 105, oneAt: 104) == .similar)
        #expect(try strength(all: 100) == .similar)
        #expect(try strength(all: 95, oneAt: 96) == .similar)
        #expect(try strength(all: 95) == .weaker)
        #expect(try strength(all: 85, oneAt: 86) == .weaker)
        #expect(try strength(all: 85) == .muchWeaker)
    }

    @Test func theReadingCarriesWhatItCompared() throws {
        let reading = try read(theirs: eleven(all: 105))
        #expect(reading == OpponentReading(club: "Banbury United", day: today, theirTotal: 1155, ownTotal: 1100,
                                           strength: .stronger, awayOnLoanAt: []))
        #expect(reading.ownAverage == 100)
        #expect(reading.theirAverage == 105)
    }

    @Test func aCarriedReadingKeepsTheirSideAndMeasuresTheOwnersAgain() throws {
        let earlier = try read(theirs: eleven(all: 105) + side(loanedTo: "Wallingford", abilities: [120], prefix: "Away"))
        #expect(earlier.strength == .stronger)
        #expect(earlier.ownDay == nil)
        let later = Day(year: 2026, month: 11, day: 25)!
        // The owner's side has grown to 110 a man: the same 105 now reads as similar.
        let grown = side(abilities: Array(repeating: 110, count: 11), prefix: "Own")
        let carried = try OpponentAdvisor.carry(earlier, own: grown, ownClub: "Oxford City", on: later,
                                                parameters: parameters)
        #expect(carried == OpponentReading(club: earlier.club, day: today, theirTotal: earlier.theirTotal, ownTotal: 1210,
                                           strength: .similar, awayOnLoanAt: earlier.awayOnLoanAt, ownDay: later))
        // With the owner's side as it was, only the day measured changes.
        let same = try OpponentAdvisor.carry(earlier, own: own, ownClub: "Oxford City", on: later, parameters: parameters)
        #expect(same.strength == earlier.strength)
        #expect(same.ownTotal == earlier.ownTotal)
        #expect(same.ownDay == later)
        #expect(same.day == today)
    }

    @Test func carryingRefusesAsReadingDoesForTheOwnersSideAndTheLines() throws {
        let earlier = try read(theirs: eleven(all: 105))
        #expect(throws: OpponentReadingError.noOwnSquad) {
            try OpponentAdvisor.carry(earlier, own: [], ownClub: nil, on: today, parameters: parameters)
        }
        #expect(throws: OpponentReadingError.tooFewPlayers(.own, found: 10)) {
            try OpponentAdvisor.carry(earlier, own: Array(own.prefix(10)), ownClub: nil, on: today, parameters: parameters)
        }
        var bad = parameters
        bad.opponentStrengthLines = Parameter(
            OpponentStrengthLines(strongerFromPercent: 20, muchStrongerFromPercent: 10), .derived, source: "test")
        #expect(throws: PlanError.self) {
            try OpponentAdvisor.carry(earlier, own: own, ownClub: nil, on: today, parameters: bad)
        }
    }

    @Test func aReadingSavedBeforeTheDayMeasuredOpensAsPasted() throws {
        let json = #"{"club":"Banbury United","day":"2026-11-15","theirTotal":816,"ownTotal":754,"strength":"stronger","awayOnLoanAt":[]}"#
        let reading = try JSONDecoder().decode(OpponentReading.self, from: Data(json.utf8))
        #expect(reading.ownDay == nil)
        let carried = OpponentReading(club: "B", day: today, theirTotal: 1, ownTotal: 1, strength: .similar,
                                      awayOnLoanAt: [], ownDay: today)
        #expect(try JSONDecoder().decode(OpponentReading.self, from: JSONEncoder().encode(carried)) == carried)
    }

    @Test func onlyTheBestElevenCount() throws {
        let base = try read(theirs: eleven(all: 105))
        let withExtraTheirs = try read(theirs: eleven(all: 105) + side(abilities: [60], prefix: "Extra"))
        #expect(withExtraTheirs == base)
        let withExtraOwn = try read(theirs: eleven(all: 105), own: own + side(abilities: [60], prefix: "OwnExtra"))
        #expect(withExtraOwn == base)
    }

    @Test func anInjuredPlayerIsLeftOut() throws {
        var theirs = eleven(all: 100)
        theirs[0] = .fixture(name: "Their 0", currentAbility: 160, isInjured: true, club: nil)
        let reading = try read(theirs: theirs + side(abilities: [60], prefix: "Extra"))
        #expect(reading.theirTotal == 1000 + 60)  // the twelfth at 60 takes his place
        // Not injured, he counts: 160 and ten at 100.
        theirs[0] = .fixture(name: "Their 0", currentAbility: 160, club: nil)
        #expect(try read(theirs: theirs + side(abilities: [60], prefix: "Extra")).theirTotal == 1160)
    }

    @Test func aBannedPlayerStillCounts() throws {
        var theirs = eleven(all: 100)
        theirs[0] = .fixture(name: "Their 0", currentAbility: 160, isBanned: true, club: nil)
        #expect(try read(theirs: theirs).theirTotal == 1160)
    }

    @Test func positionsDoNotMatter() throws {
        // The fixture players have no positions and no goalkeeper among them.
        #expect(try read(theirs: eleven(all: 100)).strength == .similar)
    }

    @Test func withNoClubOnTheRowsTheNameGivenIsTheirClub() throws {
        let theirs = eleven(all: 100) + side(loanedTo: "banbury united", abilities: [190], prefix: "Loanee")
        let reading = try read(theirs: theirs, named: " Banbury United ")
        #expect(reading.club == "Banbury United")
        // A loan to the club itself is a loan in: he counts.
        #expect(reading.theirTotal == 1000 + 190)
        #expect(reading.awayOnLoanAt == [])
    }

    @Test func theirClubComesFromTheRowsWhenTheyCarryOne() throws {
        let theirs = side(club: "Banbury United", abilities: Array(repeating: 100, count: 11))
        #expect(try read(theirs: theirs, named: "Banbury").club == "Banbury United")
    }

    @Test func aPlayerAwayOnLoanIsLeftOutAndHisClubListed() throws {
        let away = ["Wallingford", "Reading", "reading"].enumerated().flatMap { index, club in
            side(loanedTo: club, abilities: [190], prefix: "Away\(index)")
        }
        let reading = try read(theirs: eleven(all: 100) + away)
        #expect(reading.theirTotal == 1100)
        #expect(reading.awayOnLoanAt == ["Reading", "Wallingford"])
    }

    @Test func aNameTypedDifferentlyLeavesTheLoaneeOutAndListsHisClub() throws {
        let theirs = eleven(all: 100) + side(loanedTo: "Banbury United", abilities: [190], prefix: "Loanee")
        let reading = try read(theirs: theirs, named: "Banbury")
        #expect(reading.theirTotal == 1100)
        #expect(reading.awayOnLoanAt == ["Banbury United"])
    }

    @Test func aPlayerOnLoanBetweenTheClubsCountsForTheClubHePlaysFor() throws {
        let loanee = Player.fixture(name: "Shared", currentAbility: 190, club: nil, loanedTo: "Banbury United")
        let reading = try read(theirs: eleven(all: 100) + [loanee], own: own + [loanee])
        #expect(reading.ownTotal == 1100)
        #expect(reading.theirTotal == 1000 + 190)
        #expect(reading.awayOnLoanAt == [])
    }

    @Test func theOwnersInjuredAndLoanedOutPlayersAreLeftOut() throws {
        let injured = Player.fixture(name: "Own Hurt", currentAbility: 190, isInjured: true, club: nil)
        let away = Player.fixture(name: "Own Away", currentAbility: 190, club: nil, loanedTo: "Wallingford")
        let reading = try read(theirs: eleven(all: 100), own: own + [injured, away])
        #expect(reading.ownTotal == 1100)
        // The owner's loans out are not listed: only the opponent's are.
        #expect(reading.awayOnLoanAt == [])
    }

    @Test func aPlayerOnLoanAtTheOwnersClubCountsForTheOwner() throws {
        let loanee = Player.fixture(name: "Own Loanee", currentAbility: 190, club: nil, loanedTo: "Oxford City")
        #expect(try read(theirs: eleven(all: 100), own: own + [loanee]).ownTotal == 1000 + 190)
    }

    @Test func withNoOwnClubKnownEveryLoanOfTheOwnersReadsAsAway() throws {
        let loanee = Player.fixture(name: "Own Loanee", currentAbility: 190, club: nil, loanedTo: "Oxford City")
        #expect(try read(theirs: eleven(all: 100), own: own + [loanee], ownClub: nil).ownTotal == 1100)
    }

    @Test func inputOrderDoesNotMatter() throws {
        let theirs = side(abilities: [90, 120, 100, 70, 110, 105, 95, 99, 101, 80, 130, 60])
            + side(loanedTo: "Reading", abilities: [150], prefix: "Away")
        let mine = side(abilities: [100, 101, 99, 120, 80, 70, 110, 90, 95, 100, 105, 100], prefix: "Own")
        let straight = try read(theirs: theirs, own: mine)
        let shuffled = try read(theirs: theirs.reversed().shuffledDeterministically(), own: mine.reversed().shuffledDeterministically())
        #expect(straight == shuffled)
    }

    @Test func refusals() throws {
        #expect(throws: OpponentReadingError.noOwnSquad) { try read(theirs: eleven(all: 100), own: []) }
        #expect(throws: OpponentReadingError.ownSquadPasted) { try read(theirs: own) }
        #expect(throws: OpponentReadingError.noClubName) { try read(theirs: eleven(all: 100), named: "  ") }
        #expect(throws: OpponentReadingError.tooFewPlayers(.theirs(club: "Banbury United"), found: 10)) {
            try read(theirs: Array(eleven(all: 100).dropLast()))
        }
        var hurt = own
        hurt[10] = .fixture(name: "Own 10", currentAbility: 100, isInjured: true, club: nil)
        #expect(throws: OpponentReadingError.tooFewPlayers(.own, found: 10)) { try read(theirs: eleven(all: 100), own: hurt) }
        // Their side is checked first.
        #expect(throws: OpponentReadingError.tooFewPlayers(.theirs(club: "Banbury United"), found: 10)) {
            try read(theirs: Array(eleven(all: 100).dropLast()), own: hurt)
        }
    }

    @Test func rowsCarryingTheOwnersClubAreRefused() throws {
        let rows = side(club: "oxford city", abilities: Array(repeating: 100, count: 11))
        #expect(throws: OpponentReadingError.ownSquadPasted) { try read(theirs: rows, ownClub: "Oxford City") }
    }

    @Test func rowsCarryingAnotherClubAreNotRefusedByClub() throws {
        let rows = side(club: "Banbury United", abilities: Array(repeating: 100, count: 11))
        #expect(try read(theirs: rows, ownClub: "Oxford City").club == "Banbury United")
    }

    @Test func withNoOwnClubKnownRowsCarryingAClubAreRead() throws {
        let rows = side(club: "Oxford City", abilities: Array(repeating: 100, count: 11))
        #expect(try read(theirs: rows, ownClub: nil).club == "Oxford City")
    }

    @Test func aNameTypedAsTheOwnersClubIsNotRefusedByClub() throws {
        // Only a club on the rows refuses; the typed name is the owner's to get wrong, and the sentence shows it.
        let reading = try read(theirs: eleven(all: 100), named: "Oxford City", ownClub: "Oxford City")
        #expect(reading.club == "Oxford City")
    }

    @Test func theOwnSquadRefusalComesBeforeTheClubName() throws {
        #expect(throws: OpponentReadingError.ownSquadPasted) { try read(theirs: own, named: "") }
    }

    @Test func halfTheRowsBeingTheOwnersIsNotRefused() throws {
        let twelveWithSix = side(abilities: Array(repeating: 100, count: 6)) + Array(own.prefix(6))
        #expect(try read(theirs: twelveWithSix).theirTotal == 1100)
        let twelveWithSeven = side(abilities: Array(repeating: 100, count: 5)) + Array(own.prefix(7))
        #expect(throws: OpponentReadingError.ownSquadPasted) { try read(theirs: twelveWithSeven) }
    }

    @Test func badLinesAreAnError() throws {
        for (stronger, much) in [(5, 5), (0, 15), (5, 100)] {
            var bad = parameters
            bad.opponentStrengthLines = Parameter(
                OpponentStrengthLines(strongerFromPercent: stronger, muchStrongerFromPercent: much), .derived, source: "test")
            do {
                _ = try read(theirs: eleven(all: 100), parameters: bad)
                Issue.record("lines \(stronger) and \(much) were accepted")
            } catch PlanError.badParameters(let problems) {
                #expect(problems.count == 1)
                #expect(problems.first?.contains("opponentStrengthLines") == true)
            }
        }
    }

    @Test func movingALineChangesTheStep() throws {
        #expect(try strength(all: 105) == .stronger)
        var moved = parameters
        moved.opponentStrengthLines = Parameter(
            OpponentStrengthLines(strongerFromPercent: 10, muchStrongerFromPercent: 15), .derived, source: "test")
        #expect(try read(theirs: eleven(all: 105), parameters: moved).strength == .similar)
    }
}

private extension Array {
    /// A fixed reordering, so the test needs no random numbers.
    func shuffledDeterministically() -> [Element] {
        let odd = enumerated().filter { $0.offset % 2 == 1 }.map(\.element)
        let even = enumerated().filter { $0.offset % 2 == 0 }.map(\.element)
        return odd + even
    }
}
