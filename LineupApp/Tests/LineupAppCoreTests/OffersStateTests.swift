import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

/// The saved record of offers and the actions that change it: values, clubs' figures, asks and deals.
@MainActor @Suite struct OffersStateTests {
    /// The model with the first team imported, one player marked to sell and one to loan out, and the clock stopped, so
    /// that it moves only when a test moves it.
    private struct Setup {
        let t: TestModel
        let seller: PlayerID
        let loanee: PlayerID
        var model: AppModel { t.model }
    }

    private func ready() throws -> Setup {
        let t = try TestModel()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        try t.importFirstTeam()
        let markable = t.model.players.filter { player in
            if case .loanedIn = t.model.squad.book.loanStatus(of: player, override: t.model.settings.clubOverride) {
                return false
            }
            return !Removal.isOnYouthContract(player)
        }
        let seller = try #require(markable.first).id
        let loanee = try #require(markable.dropFirst().first).id
        t.model.setMark(.toSell, for: seller)
        t.model.setMark(.toLoanOut, for: loanee)
        #expect(t.model.marks[seller] == .toSell && t.model.marks[loanee] == .toLoanOut)
        t.input.tick = 0
        t.input.uptime = 1_000
        return Setup(t: t, seller: seller, loanee: loanee)
    }

    /// Moves the clock past the guard, so the next recording is not taken for a double click.
    private func advance(_ t: TestModel) {
        t.input.uptime += AppModel.offersActionInterval + 1
    }

    /// Moves today in the game on by `days`.
    private func moveDate(_ t: TestModel, by days: Int) {
        var settings = t.model.settings
        settings.currentDate = settings.currentDate.adding(days: days)
        t.model.update(settings)
    }

    private static let sale = OfferTerms.sale(SaleTerms(now: 30_000, later: 10_000, nextFeePercent: 20))
    private static let loan = OfferTerms.loan(LoanTerms(wagePercent: 50, feePerMonth: 1_000, playingTime: .startingPlace,
                                                        recall: true, futureFee: nil))

    private func wage(_ id: PlayerID, _ model: AppModel) throws -> Double {
        try #require(model.players.first { $0.id == id }).wagePerWeek
    }

    private func name(_ id: PlayerID, _ model: AppModel) throws -> String {
        try #require(model.players.first { $0.id == id }).name
    }

    // MARK: Values

    @Test func aTypedValueIsKeptWithItsDayAndSavedWithoutPlanning() throws {
        let s = try ready()
        let planned = s.model.timesPlanned
        let files = try ScoutingSetup.storeFiles(s.t)
        s.model.setOfferValue(text: "£40,000", for: s.seller)
        #expect(s.model.offers.players[s.seller]?.value == 40_000)
        #expect(s.model.offers.players[s.seller]?.valueDay == s.model.settings.currentDate)
        #expect(s.model.timesPlanned == planned)
        let now = try ScoutingSetup.storeFiles(s.t)
        #expect(now.filter { files[$0.key] != $0.value }.map(\.key) == ["offers.json"])
        #expect(s.t.reopened().offers == s.model.offers)
    }

    @Test func aRetypedValueMovesItsDayOnlyWhenItChanges() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        let first = s.model.settings.currentDate
        moveDate(s.t, by: 3)
        s.model.setOfferValue(text: "40,000", for: s.seller)                            // the same value
        #expect(s.model.offers.players[s.seller]?.valueDay == first)
        s.model.setOfferValue(text: "45,000", for: s.seller)
        #expect(s.model.offers.players[s.seller]?.valueDay == first.adding(days: 3))
    }

    @Test func aBlankValueIsNoValue() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.setOfferValue(text: "", for: s.seller)
        #expect(s.model.offers.players[s.seller]?.value == nil)
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.setOfferValue(text: "abc", for: s.seller)
        #expect(s.model.offers.players[s.seller]?.value == nil)
        #expect(s.t.reopened().offers.players[s.seller]?.value == nil)
    }

    @Test func thirteenDigitsTypedKeepTheFirstTwelveAndTheValueIsNotCleared() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.setOfferValue(text: "1234567890123", for: s.seller)
        #expect(s.model.offers.players[s.seller]?.value == 123_456_789_012)
        s.model.setClubFigure(.transferBudget, text: "9876543210987", club: "Barnet")
        #expect(s.model.clubEntry(named: "Barnet")?.figures.transferBudget == 987_654_321_098)
    }

    @Test func aValueOfZeroIsAValue() throws {
        let s = try ready()
        s.model.setOfferValue(text: "0", for: s.seller)
        #expect(s.model.offers.players[s.seller]?.value == 0)
    }

    @Test func aValueForAPlayerNotInTheSquadsDoesNothing() throws {
        let s = try ready()
        let files = try ScoutingSetup.storeFiles(s.t)
        s.model.setOfferValue(text: "40000", for: PlayerID(key: "nobody at all"))
        s.model.setLoanPurpose(.wage, for: PlayerID(key: "nobody at all"))
        #expect(s.model.offers == OffersState())
        #expect(try ScoutingSetup.storeFiles(s.t) == files)
    }

    @Test func theLoansPurposeFollowsHisAgeUntilHeSwitchesIt() throws {
        let s = try ready()
        let young = try #require(s.model.players.first { $0.age == 23 }).id
        let older = try #require(s.model.players.first { $0.age == 24 }).id
        #expect(s.model.loanPurpose(for: young) == .development)
        #expect(s.model.loanPurpose(for: older) == .wage)
        let planned = s.model.timesPlanned
        s.model.setLoanPurpose(.wage, for: young)
        s.model.setLoanPurpose(.development, for: older)
        #expect(s.model.loanPurpose(for: young) == .wage)
        #expect(s.model.loanPurpose(for: older) == .development)
        #expect(s.model.timesPlanned == planned)
        let reopened = s.t.reopened()
        #expect(reopened.loanPurpose(for: young) == .wage)
        #expect(reopened.loanPurpose(for: older) == .development)
    }

    /// A markable player of `age` in the first team.
    private func markable(age: Int, _ s: Setup) throws -> PlayerID {
        try #require(s.model.players.first { player in
            if case .loanedIn = s.model.squad.book.loanStatus(of: player, override: s.model.settings.clubOverride) {
                return false
            }
            return player.age == age && !Removal.isOnYouthContract(player) && player.id != s.seller
        }).id
    }

    /// Makes the player a year older in the first team, as his birthday and the next import would.
    private func birthday(_ id: PlayerID, _ s: Setup) throws {
        var players = try #require(s.model.squad.book.current[.firstTeam])
        let index = try #require(players.firstIndex { $0.id == id })
        players[index].age += 1
        _ = s.model.squad.book.apply(ImportResult(grid: "test", players: players, warnings: [], money: .weeklyPounds),
                                     to: .firstTeam)
    }

    @Test func aLoansPurposeIsKeptOnceALoanRoundIsRecorded() throws {
        let s = try ready()
        let young = try markable(age: 23, s)
        s.model.setMark(.toLoanOut, for: young)
        s.model.setOfferValue(text: "8000", for: young)
        #expect(s.model.offers.players[young]?.purpose == nil)
        s.model.recordRound(for: young, club: "Barnet", by: .club, terms: Self.loan)
        #expect(s.model.offers.players[young]?.purpose == .development)
        #expect(s.t.reopened().offers.players[young]?.purpose == .development)
        try birthday(young, s)
        #expect(s.model.squad.book.allPlayers.first { $0.id == young }?.age == 24)
        #expect(s.model.loanPurpose(for: young) == .development)
    }

    @Test func aLoansPurposeIsKeptOnceALoanAskIsRecordedAndASavedOneIsLeftAsItIs() throws {
        let s = try ready()
        let young = try markable(age: 23, s)
        s.model.setMark(.toLoanOut, for: young)
        s.model.setOfferValue(text: "8000", for: young)
        s.model.recordAsk(for: young, terms: Self.loan)
        #expect(s.model.offers.players[young]?.purpose == .development)
        try birthday(young, s)
        #expect(s.model.loanPurpose(for: young) == .development)
        // One the owner switched stays as he set it.
        advance(s.t)
        s.model.setLoanPurpose(.wage, for: s.loanee)
        s.model.setOfferValue(text: "8000", for: s.loanee)
        s.model.recordAsk(for: s.loanee, terms: Self.loan)
        #expect(s.model.offers.players[s.loanee]?.purpose == .wage)
        // A sale keeps no purpose.
        advance(s.t)
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordAsk(for: s.seller, terms: Self.sale)
        #expect(s.model.offers.players[s.seller]?.purpose == nil)
    }

    @Test func theKindFollowsTheMark() throws {
        let s = try ready()
        #expect(s.model.offerKind(for: s.seller) == .sale)
        #expect(s.model.offerKind(for: s.loanee) == .loan)
        let unmarked = try #require(s.model.players.first { s.model.marks[$0.id] == nil }).id
        #expect(s.model.offerKind(for: unmarked) == nil)
    }

    // MARK: Clubs' figures

    @Test func aClubsFiguresAreKeptUnderItsNameHoweverItIsTyped() throws {
        let s = try ready()
        let planned = s.model.timesPlanned
        s.model.setClubFigure(.transferBudget, text: "35,000", club: "Barnet")
        #expect(s.model.clubEntry(named: " barnet ")?.figures.transferBudget == 35_000)
        #expect(s.model.clubEntry(named: "BARNET")?.enteredOn == s.model.settings.currentDate)
        s.model.setClubFigure(.highestWage, text: "900", club: "BARNET ")
        let entry = try #require(s.model.clubEntry(named: "Barnet"))
        #expect(entry.figures.transferBudget == 35_000 && entry.figures.highestWagePerWeek == 900)
        #expect(entry.figures.name == "BARNET")                                          // as last typed
        #expect(s.model.offers.clubs.count == 1)
        #expect(s.model.clubEntry(named: "Wealdstone") == nil)
        #expect(s.model.timesPlanned == planned)
        #expect(s.t.reopened().offers == s.model.offers)
        s.model.setClubFigure(.transferBudget, text: "", club: "Barnet")                 // blank is no figure
        #expect(s.model.clubEntry(named: "Barnet")?.figures.transferBudget == nil)
    }

    @Test func aClubsWageFiguresAreSavedByTheWeekFromFMRTEsPeriod() throws {
        let s = try ready()
        try s.t.importFirstTeamInDollarsMonthly()
        #expect(s.model.squad.book.moneyStyle.period == .monthly)
        s.model.setClubFigure(.wageBudget, text: "5,200", club: "Barnet")
        s.model.setClubFigure(.wagesSpent, text: "2,600", club: "Barnet")
        s.model.setClubFigure(.highestWage, text: "520", club: "Barnet")
        s.model.setClubFigure(.transferBudget, text: "35,000", club: "Barnet")
        let figures = try #require(s.model.clubEntry(named: "Barnet")).figures
        #expect(figures.wageBudgetPerWeek == 1_200)
        #expect(figures.wagesSpentPerWeek == 600)
        #expect(figures.highestWagePerWeek == 120)
        #expect(figures.transferBudget == 35_000)                                        // whole units, no period
    }

    @Test func aBlankClubNameSavesNothing() throws {
        let s = try ready()
        let files = try ScoutingSetup.storeFiles(s.t)
        s.model.setClubFigure(.transferBudget, text: "35,000", club: "")
        s.model.setClubFigure(.transferBudget, text: "35,000", club: "   ")
        #expect(s.model.offers.clubs.isEmpty)
        #expect(try ScoutingSetup.storeFiles(s.t) == files)
    }

    @Test func aBlankFigureForAClubWithNoEntrySavesNothing() throws {
        let s = try ready()
        let files = try ScoutingSetup.storeFiles(s.t)
        s.model.setClubFigure(.transferBudget, text: "", club: "Barnet")
        s.model.setClubFigure(.wageBudget, text: "abc", club: "Barnet")
        #expect(s.model.offers.clubs.isEmpty)
        #expect(s.model.clubEntry(named: "Barnet") == nil)
        #expect(try ScoutingSetup.storeFiles(s.t) == files)
        // A figure typed for it is saved as before.
        s.model.setClubFigure(.transferBudget, text: "35,000", club: "Barnet")
        #expect(s.model.clubEntry(named: "Barnet")?.figures.transferBudget == 35_000)
    }

    @Test func aDealOpenedForAClubWithNoFigureEnteredTakesNone() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.setClubFigure(.transferBudget, text: "35,000", club: "Barnet")
        s.model.setClubFigure(.transferBudget, text: "", club: "Barnet")                 // every figure blank again
        #expect(s.model.clubEntry(named: "Barnet")?.figures.transferBudget == nil)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale)
        #expect(try #require(s.model.offers.deals.first).figures == nil)
    }

    // MARK: Recording

    @Test func anOpenDealIsFoundOnlyForHisPresentKind() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale)
        let sale = try #require(s.model.offers.deals.first)
        #expect(s.model.openDeal(for: s.seller, club: "Barnet") == sale)
        s.model.setMark(.toLoanOut, for: s.seller)
        #expect(s.model.openDeal(for: s.seller, club: "Barnet") == nil)                  // the open sale is not a loan
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .owner, terms: Self.loan)
        #expect(s.model.offers.deals.count == 2)
        #expect(s.model.openDeal(for: s.seller, club: "Barnet")?.kind == .loan)
        #expect(s.model.offers.deals.first?.rounds.count == 1)                           // the sale was not joined
        s.model.setMark(.toSell, for: s.seller)
        #expect(s.model.openDeal(for: s.seller, club: "barnet")?.id == sale.id)
        s.model.setMark(nil, for: s.seller)
        #expect(s.model.openDeal(for: s.seller, club: "Barnet") == nil)                  // no mark, no kind
    }

    @Test func recordingAnAskNeedsAMarkAValueAndTermsOfHisKind() throws {
        let s = try ready()
        #expect(s.model.recordAsk(for: s.seller, terms: Self.sale) == "Enter his value to get terms.")
        #expect(s.model.offers.asks.isEmpty)
        advance(s.t)
        s.model.setOfferValue(text: "40000", for: s.seller)
        #expect(s.model.recordAsk(for: s.seller, terms: Self.loan) == "These are not the terms of this kind of deal.")
        advance(s.t)
        let negative = OfferTerms.sale(SaleTerms(now: -1, later: 0, nextFeePercent: 0))
        #expect(s.model.recordAsk(for: s.seller, terms: negative) == "The money now cannot be below 0.")
        #expect(s.model.offers.asks.isEmpty)
        advance(s.t)
        let unmarked = try #require(s.model.players.first { s.model.marks[$0.id] == nil }).id
        s.model.setOfferValue(text: "10000", for: unmarked)
        #expect(s.model.recordAsk(for: unmarked, terms: Self.sale) == nil)
        #expect(s.model.offers.asks.isEmpty)
        advance(s.t)
        let planned = s.model.timesPlanned
        let files = try ScoutingSetup.storeFiles(s.t)
        #expect(s.model.recordAsk(for: s.seller, terms: Self.sale) == nil)
        let ask = try #require(s.model.offers.asks.first)
        #expect(s.model.offers.asks.count == 1)
        #expect(ask.player == s.seller && ask.kind == .sale && ask.terms == Self.sale && !ask.noBidCame)
        #expect(ask.day == s.model.settings.currentDate && ask.value == 40_000)
        let wagePerWeek = try wage(s.seller, s.model), playerName = try name(s.seller, s.model)
        #expect(ask.wagePerWeek == wagePerWeek && ask.playerName == playerName)
        #expect(s.model.timesPlanned == planned)
        let now = try ScoutingSetup.storeFiles(s.t)
        #expect(now.filter { files[$0.key] != $0.value }.map(\.key) == ["offers.json"])
        #expect(s.t.reopened().offers == s.model.offers)
    }

    @Test func aRecordedRoundOpensADealWithTheClubsFiguresAndTheValueOfTheDay() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.setClubFigure(.transferBudget, text: "35,000", club: "Barnet")
        let planned = s.model.timesPlanned
        #expect(s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale) == nil)
        let deal = try #require(s.model.offers.deals.first)
        #expect(s.model.offers.deals.count == 1)
        #expect(deal.player == s.seller && deal.kind == .sale && deal.club == "Barnet" && deal.endedOn == nil)
        let wagePerWeek = try wage(s.seller, s.model), playerName = try name(s.seller, s.model)
        #expect(deal.playerName == playerName)
        #expect(deal.figures == s.model.clubEntry(named: "Barnet")?.figures)
        #expect(deal.rounds == [OfferRound(day: s.model.settings.currentDate, by: .club, terms: Self.sale, value: 40_000,
                                           wagePerWeek: wagePerWeek, answer: nil)])
        #expect(s.model.openDeal(for: s.seller, club: "barnet") == deal)
        #expect(s.model.timesPlanned == planned)
        #expect(s.t.reopened().offers == s.model.offers)
        // A club with no figures entered opens a deal with none.
        advance(s.t)
        s.model.setOfferValue(text: "8000", for: s.loanee)
        #expect(s.model.recordRound(for: s.loanee, club: "Wealdstone", by: .owner, terms: Self.loan) == nil)
        #expect(s.model.openDeal(for: s.loanee, club: "Wealdstone")?.figures == nil)
    }

    @Test func recordingARoundIsRefusedAsAnAskIs() throws {
        let s = try ready()
        #expect(s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale)
                == "Enter his value to get terms.")
        advance(s.t)
        s.model.setOfferValue(text: "40000", for: s.seller)
        #expect(s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.loan)
                == "These are not the terms of this kind of deal.")
        advance(s.t)
        #expect(s.model.recordRound(for: s.seller, club: "  ", by: .club, terms: Self.sale) == nil)   // blank club
        #expect(s.model.offers.deals.isEmpty)
    }

    @Test func aSecondRoundJoinsTheOpenDealHoweverTheClubIsTyped() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .owner, terms: Self.sale)
        advance(s.t)
        let counter = OfferTerms.sale(SaleTerms(now: 25_000, later: 5_000, nextFeePercent: 10))
        s.model.recordRound(for: s.seller, club: "BARNET", by: .club, terms: counter)
        #expect(s.model.offers.deals.count == 1)
        let deal = try #require(s.model.offers.deals.first)
        #expect(deal.rounds.map(\.by) == [.owner, .club])
        #expect(deal.rounds[0].answer == nil)                                            // read as countered
        #expect(deal.club == "Barnet")
        // Another club opens another deal.
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Wealdstone", by: .club, terms: counter)
        #expect(s.model.offers.deals.count == 2)
    }

    @Test func aRoundAfterTheDealIsAgreedOrEndedOpensANewDeal() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale)
        let first = try #require(s.model.offers.deals.first).id
        advance(s.t)
        s.model.acceptTheirs(deal: first)
        #expect(s.model.openDeal(for: s.seller, club: "Barnet") == nil)
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale)
        #expect(s.model.offers.deals.count == 2)
        let second = try #require(s.model.offers.deals.last).id
        #expect(second != first)
        advance(s.t)
        s.model.endDeal(second)
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .owner, terms: Self.sale)
        #expect(s.model.offers.deals.count == 3)
        #expect(s.model.offers.deals.map(\.state) == [.agreed, .ended, .open])
        #expect(s.model.offers.deals.map { $0.rounds.count } == [1, 1, 1])
    }

    @Test func aValueRetypedLeavesEarlierRoundsOnTheValueTheyWereMadeOn() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .owner, terms: Self.sale)
        s.model.recordAsk(for: s.seller, terms: Self.sale)                               // within the guard: ignored
        advance(s.t)
        s.model.recordAsk(for: s.seller, terms: Self.sale)
        s.model.setOfferValue(text: "60000", for: s.seller)
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale)
        let rounds = try #require(s.model.offers.deals.first).rounds
        #expect(rounds.map(\.value) == [40_000, 60_000])
        #expect(s.model.offers.asks.map(\.value) == [40_000])
    }

    @Test func anAnswerGoesOnHisLastRoundOnlyAndOnlyOnce() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale)
        let id = try #require(s.model.offers.deals.first).id
        advance(s.t)
        s.model.answer(.refused, deal: id)                                               // the last round is the club's
        #expect(s.model.offers.deals[0].rounds.map(\.answer) == [nil])
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .owner, terms: Self.sale)
        advance(s.t)
        let planned = s.model.timesPlanned
        s.model.answer(.refused, deal: id)
        #expect(s.model.offers.deals[0].rounds.map(\.answer) == [nil, .refused])
        #expect(s.model.timesPlanned == planned)
        #expect(s.t.reopened().offers == s.model.offers)
        advance(s.t)
        s.model.answer(.accepted, deal: id)                                              // it has one already
        #expect(s.model.offers.deals[0].rounds.map(\.answer) == [nil, .refused])
        advance(s.t)
        s.model.answer(.accepted, deal: UUID())                                          // no such deal
        #expect(s.model.offers.deals[0].rounds.map(\.answer) == [nil, .refused])
    }

    @Test func acceptingTheirsAgreesTheDealAndEndingClosesIt() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .owner, terms: Self.sale)
        let barnet = try #require(s.model.offers.deals.first).id
        advance(s.t)
        s.model.acceptTheirs(deal: barnet)                                               // the last round is his
        #expect(s.model.offers.deals[0].state == .open)
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale)
        advance(s.t)
        s.model.acceptTheirs(deal: barnet)
        #expect(s.model.offers.deals[0].rounds.map(\.answer) == [nil, .accepted])
        #expect(s.model.offers.deals[0].state == .agreed)
        advance(s.t)
        s.model.endDeal(barnet)                                                          // not open: nothing
        #expect(s.model.offers.deals[0].endedOn == nil)

        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Wealdstone", by: .club, terms: Self.sale)
        let wealdstone = try #require(s.model.offers.deals.last).id
        moveDate(s.t, by: 2)
        advance(s.t)
        s.model.endDeal(wealdstone)
        #expect(s.model.offers.deals[1].endedOn == s.model.settings.currentDate)
        #expect(s.model.offers.deals[1].state == .ended)
        advance(s.t)
        s.model.acceptTheirs(deal: wealdstone)                                           // ended: nothing
        #expect(s.model.offers.deals[1].state == .ended)
        #expect(s.t.reopened().offers == s.model.offers)
    }

    @Test func noBidCameMarksTheAsk() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordAsk(for: s.seller, terms: Self.sale)
        let id = try #require(s.model.offers.asks.first).id
        advance(s.t)
        let planned = s.model.timesPlanned
        s.model.noBidCame(id)
        #expect(s.model.offers.asks[0].noBidCame)
        #expect(s.model.timesPlanned == planned)
        #expect(s.t.reopened().offers.asks[0].noBidCame)
    }

    @Test func deletingADealOrAnAskRemovesOnlyThatOne() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordAsk(for: s.seller, terms: Self.sale)
        advance(s.t)
        s.model.recordAsk(for: s.seller, terms: Self.sale)
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale)
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Wealdstone", by: .club, terms: Self.sale)
        let asks = s.model.offers.asks, deals = s.model.offers.deals
        #expect(asks.count == 2 && deals.count == 2)
        let planned = s.model.timesPlanned
        s.model.deleteAsk(asks[0].id)
        s.model.deleteDeal(deals[1].id)                                                  // no guard: each asks first
        #expect(s.model.offers.asks == [asks[1]])
        #expect(s.model.offers.deals == [deals[0]])
        #expect(s.model.timesPlanned == planned)
        #expect(s.t.reopened().offers == s.model.offers)
    }

    @Test func aSecondClickWithinHalfASecondIsIgnored() throws {
        let s = try ready()
        #expect(AppModel.offersActionInterval == 0.5)
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .owner, terms: Self.sale)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .owner, terms: Self.sale)
        #expect(s.model.offers.deals.first?.rounds.count == 1)
        let id = try #require(s.model.offers.deals.first).id
        s.t.input.uptime += AppModel.offersActionInterval / 2
        s.model.answer(.refused, deal: id)                                               // one clock for them all
        #expect(s.model.offers.deals[0].rounds[0].answer == nil)
        advance(s.t)
        s.model.answer(.refused, deal: id)
        #expect(s.model.offers.deals[0].rounds[0].answer == .refused)
    }

    @Test func measuringAgainSetsTheDayAndTheMeasuresLeaveEarlierRoundsOut() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale)
        #expect(s.model.offerMeasures.sale.deals == 1)
        #expect(s.model.offerMeasures.measuredFrom == nil)
        moveDate(s.t, by: 5)
        let planned = s.model.timesPlanned
        s.model.measureOffersAgain()
        let today = s.model.settings.currentDate
        #expect(s.model.offers.measureFrom == today)
        #expect(s.model.offerMeasures.measuredFrom == today)
        #expect(s.model.offerMeasures.sale.deals == 0)
        #expect(s.model.timesPlanned == planned)
        #expect(s.t.reopened().offers.measureFrom == today)
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Wealdstone", by: .club, terms: Self.sale)
        #expect(s.model.offerMeasures.sale.deals == 1)
    }

    @Test func takingTheMarkOffKeepsHisValueAndHisDeals() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordAsk(for: s.seller, terms: Self.sale)
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale)
        let before = s.model.offers
        s.model.setMark(nil, for: s.seller)
        #expect(s.model.offerKind(for: s.seller) == nil)
        #expect(s.model.offers == before)
        #expect(s.t.reopened().offers == before)
        s.model.setMark(.toSell, for: s.seller)
        #expect(s.model.offers.players[s.seller]?.value == 40_000)
    }

    // MARK: The file

    @Test func stateSavedBeforeTheFileOpensWithNoNoticeAndNothingRecorded() throws {
        let s = try ready()
        let file = s.t.directory.appendingPathComponent("offers.json")
        #expect(FileManager.default.fileExists(atPath: file.path))                      // written at the first start
        try FileManager.default.removeItem(at: file)
        let reopened = s.t.reopened()
        #expect(reopened.notices.isEmpty)
        #expect(reopened.offers == OffersState())
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    @Test func anUnreadableFileGivesANoticeAFreshStartAndIsKeptAside() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        try Data("{".utf8).write(to: s.t.directory.appendingPathComponent("offers.json"))
        let reopened = s.t.reopened()
        #expect(reopened.notices.count == 1)
        let notice = try #require(reopened.notices.first).text
        #expect(notice.hasPrefix("Your recorded offers could not be read as saved data"))
        #expect(notice.contains("the record starts empty"))
        #expect(reopened.offers == OffersState())
        #expect(FileManager.default.fileExists(atPath: s.t.directory.appendingPathComponent("offers.unreadable-1.json").path))
        reopened.setOfferValue(text: "40000", for: s.seller)
        #expect(reopened.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale) == nil)
        #expect(s.t.reopened().offers.deals.count == 1)
    }

    @Test func theFileRoundTripsWithEveryKindOfTerms() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.setOfferValue(text: "8000", for: s.loanee)
        s.model.setLoanPurpose(.wage, for: s.loanee)
        s.model.setClubFigure(.wageBudget, text: "5000", club: "Barnet")
        s.model.recordAsk(for: s.seller, terms: Self.sale)
        let loans: [LoanTerms] = [
            LoanTerms(wagePercent: 50, feePerMonth: 1_000, playingTime: .startingPlace, recall: true, futureFee: nil),
            LoanTerms(wagePercent: 75, feePerMonth: 0, playingTime: .less, recall: false, futureFee: 100_000),
            LoanTerms(wagePercent: 100, feePerMonth: 500, playingTime: nil, recall: true, futureFee: 0),
        ]
        for loan in loans {
            advance(s.t)
            s.model.recordRound(for: s.loanee, club: "Barnet", by: .owner, terms: .loan(loan))
            advance(s.t)
            s.model.answer(.noReply, deal: try #require(s.model.offers.deals.first).id)
        }
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Wealdstone", by: .club, terms: Self.sale)
        advance(s.t)
        s.model.endDeal(try #require(s.model.offers.deals.last).id)
        s.model.measureOffersAgain()
        #expect(s.model.offers.deals.first?.rounds.map(\.terms) == loans.map(OfferTerms.loan))
        #expect(s.model.offers.deals.first?.figures?.wageBudgetPerWeek == 5_000)
        let reopened = s.t.reopened()
        #expect(reopened.offers == s.model.offers)
        #expect(reopened.notices.isEmpty)
    }
}
