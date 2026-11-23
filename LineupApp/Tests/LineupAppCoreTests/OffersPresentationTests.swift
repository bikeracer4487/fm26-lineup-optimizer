import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

/// What the Offers screen shows, worked out from the marks, the squads and the record of offers, and the sheet a round
/// is recorded in.
@MainActor @Suite struct OffersPresentationTests {
    /// The model with the first team imported, one player marked to sell and one to loan out, and the clock stopped.
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
        let markable = t.model.squad.book.allPlayers.filter { player in
            if case .loanedIn = t.model.squad.book.loanStatus(of: player, override: t.model.settings.clubOverride) {
                return false
            }
            return !Removal.isOnYouthContract(player)
        }
        let seller = try #require(markable.first).id
        let loanee = try #require(markable.dropFirst().first).id
        t.model.setMark(.toSell, for: seller)
        t.model.setMark(.toLoanOut, for: loanee)
        t.input.tick = 0
        t.input.uptime = 1_000
        return Setup(t: t, seller: seller, loanee: loanee)
    }

    private func sheet(_ t: TestModel, clubs: [PlayerID: String] = [:]) -> OffersSheet {
        t.model.offersSheet(clubs: clubs)
    }

    private func block(_ sheet: OffersSheet, _ id: PlayerID) throws -> OfferPlayerBlock {
        try #require((sheet.toSell + sheet.toLoanOut).first { $0.id == id })
    }

    /// Moves the clock past the guard, so the next recording is not taken for a double click.
    private func advance(_ t: TestModel) {
        t.input.uptime += AppModel.offersActionInterval + 1
    }

    private func moveDate(_ t: TestModel, by days: Int) {
        var settings = t.model.settings
        settings.currentDate = settings.currentDate.adding(days: days)
        t.model.update(settings)
    }

    private func player(_ id: PlayerID, _ model: AppModel) throws -> Player {
        try #require(model.squad.book.allPlayers.first { $0.id == id })
    }

    private static func sale(_ now: Int, later: Int = 0, nextFee: Int = 20) -> OfferTerms {
        .sale(SaleTerms(now: now, later: later, nextFeePercent: nextFee))
    }

    private static let loan = OfferTerms.loan(LoanTerms(wagePercent: 50, feePerMonth: 1_000, playingTime: .startingPlace,
                                                        recall: true, futureFee: nil))

    private var rules: OfferRules { EngineParameters.fm27.offerRules.value }

    // MARK: The players

    @Test func withNobodyMarkedTheSheetSaysSoAndHasNoBlocks() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let sheet = sheet(t)
        #expect(sheet.nobodyMarked == AdvisorText.offersNobodyMarked)
        #expect(sheet.toSell.isEmpty && sheet.toLoanOut.isEmpty)
        #expect(sheet.intro == AdvisorText.offersIntro)
        #expect(sheet.valueHint == AdvisorText.valueHint && sheet.valueCaution == AdvisorText.valueCaution)
        #expect(sheet.evidenceNote == AdvisorText.offersEvidenceNote(rules))
        #expect(sheet.earlier == nil)
        let s = try ready()
        #expect(self.sheet(s.t).nobodyMarked == nil)
    }

    @Test func aMarkedPlayerWithNoValueIsAskedForItAndGetsNoTerms() throws {
        let s = try ready()
        let seller = try block(sheet(s.t, clubs: [s.seller: "Barnet"]), s.seller)
        #expect(seller.needsValue == "Enter his value to get terms.")
        #expect(seller.general == nil && seller.clubBlock == nil && seller.clubProblem == nil)
        #expect(seller.valueText == "" && seller.valueNote == nil)
    }

    @Test func aPlayerMarkedToSellGetsSaleTermsAndOneToLoanOutGetsLoanTerms() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.setOfferValue(text: "8000", for: s.loanee)
        let sheet = sheet(s.t)
        #expect(sheet.toSell.map(\.id) == [s.seller])
        #expect(sheet.toLoanOut.map(\.id) == [s.loanee])
        let seller = try block(sheet, s.seller), loanee = try block(sheet, s.loanee)
        #expect(seller.kind == .sale && seller.purpose == nil && seller.needsValue == nil)
        #expect(loanee.kind == .loan && loanee.purpose == s.model.loanPurpose(for: s.loanee))
        guard case .sale? = seller.general?.terms else { Issue.record("no sale terms"); return }
        guard case .loan? = loanee.general?.terms else { Issue.record("no loan terms"); return }
        #expect(seller.valueText == "40000")
        #expect(seller.valueNote == "entered Fri 13 Nov")
        let held = try player(s.seller, s.model)
        let parts = ["Age \(held.age)", held.positionsText, Display.wage(perWeek: held.wagePerWeek, s.model.squad.book.moneyStyle)]
            + [held.monthsLeft.map { "\($0) \($0 == 1 ? "month" : "months") left" }].compactMap { $0 }
        #expect(seller.details == parts.filter { !$0.isEmpty }.joined(separator: " · "))
        #expect(seller.name == held.name)
    }

    @Test func theGeneralBlockOpensTheEditorWithItsTerms() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        let general = try #require(try block(sheet(s.t), s.seller).general)
        #expect(general.terms == .sale(SaleTerms(now: 40_000, later: 0, nextFeePercent: 20)))
        #expect(general.lines.first == "Ask £40,000, with 20% of his next fee.")
        let held = try player(s.seller, s.model)
        let subject = OfferSubject(value: 40_000, wagePerWeek: held.wagePerWeek, isGoalkeeper: false,
                                   purpose: s.model.loanPurpose(for: s.seller))
        let suggestion = try Offers.ask(subject, kind: .sale, earlier: [], parameters: .fm27)
        #expect(general.lines == AdvisorText.offerLines(suggestion, kind: .sale, subject: subject, club: nil,
                                                       money: s.model.squad.book.moneyStyle, rules: rules))
    }

    // MARK: To a club

    @Test func aTypedClubWithNoFiguresNamesTheFieldItNeeds() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        let seller = try block(sheet(s.t, clubs: [s.seller: "Barnet"]), s.seller)
        #expect(seller.clubName == "Barnet")
        #expect(seller.clubProblem == "Enter what Barnet can spend on transfers to get terms for them.")
        #expect(seller.clubBlock == nil && seller.clubHasOpenDeal == nil)
        #expect(seller.clubFields.map(\.text) == ["", "", "", ""])
        #expect(seller.clubNote == nil)
        // With no club typed there is nothing to work out.
        let none = try block(sheet(s.t), s.seller)
        #expect(none.clubName == "" && none.clubProblem == nil && none.clubBlock == nil)
        #expect(none.clubFields.map(\.field) == ClubField.allCases)
        // A loan names the wage budget.
        s.model.setOfferValue(text: "8000", for: s.loanee)
        let loanee = try block(sheet(s.t, clubs: [s.loanee: "Wealdstone"]), s.loanee)
        #expect(loanee.clubProblem == "Enter Wealdstone's wage budget to get terms for them.")
    }

    @Test func aClubsSavedFiguresFillTheFieldsHoweverItIsTyped() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.setClubFigure(.transferBudget, text: "35,000", club: "Barnet")
        moveDate(s.t, by: 2)
        let seller = try block(sheet(s.t, clubs: [s.seller: "BARNET"]), s.seller)
        #expect(seller.clubFields[0].field == .transferBudget)
        #expect(seller.clubFields[0].text == "35000")
        #expect(seller.clubFields.dropFirst().map(\.text) == ["", "", ""])
        #expect(seller.clubNote == "entered Fri 13 Nov")
        let club = try #require(seller.clubBlock)
        #expect(club.terms == .sale(SaleTerms(now: 35_000, later: 5_000, nextFeePercent: 20)))
        #expect(club.lines.contains("BARNET can spend £35,000 now; the rest is asked later. Whether a club agrees to money beyond its budget is not known."))
        #expect(seller.clubProblem == nil)
    }

    @Test func wageFieldsAreLabelledAndShownInFMRTEsPeriod() throws {
        let s = try ready()
        #expect(try block(sheet(s.t), s.seller).clubFields.map(\.label)
                == ["Can spend on transfers", "Wage budget, a week", "Wages spent, a week", "Highest wage it can offer, a week"])
        try s.t.importFirstTeamInDollarsMonthly()
        s.model.setClubFigure(.wageBudget, text: "5,200", club: "Barnet")
        #expect(s.model.clubEntry(named: "Barnet")?.figures.wageBudgetPerWeek == 1_200)
        let seller = try block(sheet(s.t, clubs: [s.seller: "Barnet"]), s.seller)
        #expect(seller.clubFields.map(\.label)
                == ["Can spend on transfers", "Wage budget, a month", "Wages spent, a month", "Highest wage it can offer, a month"])
        #expect(seller.clubFields[1].text == "5200")
        #expect(seller.details.contains("$"))
    }

    @Test func aClubWithAnOpenDealPointsToItAndOffersNoSecondProposal() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.setClubFigure(.transferBudget, text: "35,000", club: "Barnet")
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale(8_000))
        let seller = try block(sheet(s.t, clubs: [s.seller: "barnet "]), s.seller)
        #expect(seller.clubHasOpenDeal == AdvisorText.openDealBelow(club: "Barnet"))
        #expect(seller.clubBlock == nil && seller.clubProblem == nil)
        #expect(seller.deals.count == 1)
        // Another club gets its proposal.
        let other = try block(sheet(s.t, clubs: [s.seller: "Wealdstone"]), s.seller)
        #expect(other.clubHasOpenDeal == nil)
        #expect(other.clubProblem == "Enter what Wealdstone can spend on transfers to get terms for them.")
    }

    // MARK: Deals

    @Test func aDealCardShowsItsRoundsAndTheNextStep() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale(8_000))
        let card = try #require(try block(sheet(s.t), s.seller).deals.first)
        #expect(card.heading == "Barnet · open")
        #expect(card.isOpen)
        #expect(card.player == s.seller && card.club == "Barnet")
        let round = try #require(s.model.offers.deals.first?.rounds.first)
        #expect(card.rounds.map(\.line) == [AdvisorText.roundLine(round, club: "Barnet", clubFollows: false,
                                                                  money: s.model.squad.book.moneyStyle)])
        let next = try #require(card.next)
        #expect(next.lines.first?.hasPrefix("Counter once: £8,000 now") == true)
        #expect(next.terms == .sale(SaleTerms(now: 8_000, later: 1_600, nextFeePercent: 20)))
        #expect(card.problem == nil)
    }

    @Test func theOwnersUnansweredRoundOffersTheThreeAnswersAndTheClubsOffersAccept() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .owner, terms: Self.sale(40_000))
        var card = try #require(try block(sheet(s.t), s.seller).deals.first)
        #expect(card.rounds.map(\.offersAnswers) == [true])
        #expect(card.rounds.map(\.offersAccept) == [false])
        #expect(card.next?.lines.first == "Waiting for Barnet's answer.")
        #expect(card.next?.terms == nil)
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale(30_000))
        card = try #require(try block(sheet(s.t), s.seller).deals.first)
        #expect(card.rounds.map(\.offersAnswers) == [false, false])
        #expect(card.rounds.map(\.offersAccept) == [false, true])
        // A refused round offers nothing more to answer.
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .owner, terms: Self.sale(36_000))
        advance(s.t)
        s.model.answer(.refused, deal: try #require(s.model.offers.deals.first).id)
        card = try #require(try block(sheet(s.t), s.seller).deals.first)
        #expect(card.rounds.map(\.offersAnswers) == [false, false, false])
        #expect(card.rounds.map(\.offersAccept) == [false, false, false])
    }

    @Test func hisProposalTheClubAnsweredWithItsOwnTermsReadsCountered() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .owner, terms: Self.sale(40_000))
        var card = try #require(try block(sheet(s.t), s.seller).deals.first)
        #expect(card.rounds[0].line.hasSuffix(" No answer yet."))
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale(30_000))
        card = try #require(try block(sheet(s.t), s.seller).deals.first)
        #expect(card.rounds[0].line.hasSuffix(" Countered."))
        let rounds = try #require(s.model.offers.deals.first?.rounds)
        let money = s.model.squad.book.moneyStyle
        #expect(card.rounds.map(\.line) == [AdvisorText.roundLine(rounds[0], club: "Barnet", clubFollows: true, money: money),
                                            AdvisorText.roundLine(rounds[1], club: "Barnet", clubFollows: false, money: money)])
        #expect(s.model.offers.deals.first?.rounds.first?.answer == nil)                 // nothing stored changes
    }

    @Test func anAgreedOrEndedDealHasNoNextStepAndNothingToPress() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale(30_000))
        advance(s.t)
        s.model.acceptTheirs(deal: try #require(s.model.offers.deals.first).id)
        moveDate(s.t, by: 1)
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Wealdstone", by: .owner, terms: Self.sale(40_000))
        advance(s.t)
        s.model.endDeal(try #require(s.model.offers.deals.last).id)
        moveDate(s.t, by: 1)
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Hendon", by: .club, terms: Self.sale(10_000))
        let deals = try block(sheet(s.t), s.seller).deals
        #expect(deals.map(\.heading) == ["Hendon · open", "Wealdstone · ended", "Barnet · agreed"])
        #expect(deals.map(\.isOpen) == [true, false, false])
        for card in deals.dropFirst() {
            #expect(card.next == nil && card.problem == nil)
            #expect(card.rounds.allSatisfy { !$0.offersAnswers && !$0.offersAccept })
        }
    }

    @Test func anAskStillWaitingOffersNoBidCame() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordAsk(for: s.seller, terms: Self.sale(40_000))
        advance(s.t)
        s.model.recordAsk(for: s.seller, terms: Self.sale(36_000))
        var seller = try block(sheet(s.t), s.seller)
        #expect(seller.asks.map(\.offersNoBid) == [false, true])
        let money = s.model.squad.book.moneyStyle
        #expect(seller.asks.map(\.line) == s.model.offers.asks.map { AdvisorText.askLine($0, money: money) })
        #expect(seller.asks.map(\.id) == s.model.offers.asks.map(\.id))
        advance(s.t)
        s.model.noBidCame(try #require(s.model.offers.asks.last).id)
        seller = try block(sheet(s.t), s.seller)
        #expect(seller.asks.map(\.offersNoBid) == [false, false])
        // The ask that drew no bid lowers the next.
        #expect(seller.general?.terms == Self.sale(32_000))
    }

    // MARK: Earlier offers

    @Test func dealsForAPlayerNoLongerMarkedAreUnderEarlierOffersAndStillCount() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale(30_000))
        s.model.setMark(nil, for: s.seller)
        let sheet = sheet(s.t)
        #expect(sheet.toSell.isEmpty)
        let earlier = try #require(sheet.earlier)
        #expect(earlier.line == "1 deal for players no longer marked")
        #expect(earlier.deals.count == 1 && earlier.asks.isEmpty)
        #expect(sheet.sales.first?.hasPrefix("Sales: 1 deal recorded since") == true)
        #expect(sheet.nothingRecorded == nil)
    }

    @Test func dealsForAPlayerWhoHasLeftTheSquadsAreUnderEarlierOffersAndNothingBreaks() throws {
        let s = try ready()
        let gone = PlayerID(key: "fmrte:999999")
        let day = s.model.settings.currentDate
        s.model.offers.deals.append(OfferDeal(
            id: UUID(), player: gone, playerName: "Old Boy", kind: .sale, club: "Barnet", figures: nil,
            rounds: [OfferRound(day: day, by: .club, terms: Self.sale(9_000), value: 10_000, wagePerWeek: 300, answer: nil)],
            endedOn: nil))
        s.model.offers.deals.append(OfferDeal(
            id: UUID(), player: gone, playerName: "Old Boy", kind: .sale, club: "Hendon", figures: nil,
            rounds: [OfferRound(day: day, by: .owner, terms: Self.sale(9_000), value: 10_000, wagePerWeek: 300,
                                answer: .refused)],
            endedOn: day))
        s.model.offers.asks.append(OfferAsk(id: UUID(), player: gone, playerName: "Old Boy", kind: .sale, day: day,
                                            terms: Self.sale(10_000), value: 10_000, wagePerWeek: 300, noBidCame: false))
        s.model.offers.asks.append(OfferAsk(id: UUID(), player: gone, playerName: "Old Boy", kind: .sale, day: day,
                                            terms: Self.sale(9_000), value: 10_000, wagePerWeek: 300, noBidCame: false))
        s.model.offers.asks.append(OfferAsk(id: UUID(), player: gone, playerName: "Old Boy", kind: .loan, day: day,
                                            terms: Self.loan, value: 10_000, wagePerWeek: 300, noBidCame: true))
        s.model.marks[gone] = .toSell                                                    // marked, but in no squad
        let sheet = sheet(s.t)
        #expect(!(sheet.toSell + sheet.toLoanOut).contains { $0.id == gone })
        let earlier = try #require(sheet.earlier)
        #expect(earlier.line == "2 deals and 3 asks for players no longer marked")
        #expect(earlier.deals.count == 2 && earlier.asks.count == 3)
        #expect(earlier.deals.allSatisfy { $0.heading.hasPrefix("Old Boy · ") })
        #expect(earlier.asks.allSatisfy { $0.line.hasPrefix("Old Boy · ") && !$0.offersNoBid })
        #expect(sheet.sales.first == "Sales: 2 deals recorded since Fri 13 Nov, none agreed.")
    }

    @Test func aSaleDealForAPlayerNowMarkedToLoanOutIsUnderEarlierOffers() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale(30_000))
        s.model.setMark(.toLoanOut, for: s.seller)
        let sheet = sheet(s.t)
        let now = try block(sheet, s.seller)
        #expect(now.kind == .loan && now.deals.isEmpty)
        #expect(sheet.toLoanOut.contains { $0.id == s.seller })
        #expect(sheet.earlier?.deals.count == 1)
        #expect(sheet.earlier?.line == "1 deal for players no longer marked")
        // A loan to Barnet is a new deal: the open sale is not his present kind.
        let loanTo = try block(self.sheet(s.t, clubs: [s.seller: "Barnet"]), s.seller)
        #expect(loanTo.clubHasOpenDeal == nil)
    }

    @Test func anOpenDealUnderEarlierOffersHasNoNextStepAndNothingToAnswer() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .owner, terms: Self.sale(40_000))
        advance(s.t)
        s.model.recordAsk(for: s.seller, terms: Self.sale(40_000))
        s.model.setMark(nil, for: s.seller)
        let earlier = try #require(sheet(s.t).earlier)
        let card = try #require(earlier.deals.first)
        #expect(card.next == nil && card.problem == nil)
        #expect(!card.isOpen)                                                            // only the deletion is offered
        #expect(card.rounds.allSatisfy { !$0.offersAnswers && !$0.offersAccept })
        #expect(card.heading.hasSuffix("Barnet · open"))
        #expect(earlier.asks.map(\.offersNoBid) == [false])
        #expect(earlier.line == "1 deal and 1 ask for players no longer marked")
    }

    // MARK: What the offers have shown

    @Test func withNothingRecordedThePartSaysSoAndOffersNoMeasureAgain() throws {
        let s = try ready()
        let sheet = sheet(s.t)
        #expect(sheet.nothingRecorded == AdvisorText.nothingRecorded)
        #expect(sheet.sales.isEmpty && sheet.loans.isEmpty && sheet.counterStep == nil)
        #expect(!sheet.offersMeasureAgain)
        #expect(sheet.measuredFrom == nil)
        #expect(!sheet.showsMeasuredLine)
    }

    @Test func anAskAloneIsSaidToBeRecorded() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordAsk(for: s.seller, terms: Self.sale(40_000))
        let sheet = sheet(s.t)
        #expect(sheet.sales.first == "Sales: 1 ask recorded since Fri 13 Nov, and no deal yet.")
        #expect(sheet.loans == ["Loans: nothing recorded."])
    }

    @Test func recordedDealsGiveTheEnginesLinesAndOfferMeasureAgain() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale(30_000))
        var sheet = sheet(s.t)
        let measures = s.model.offerMeasures
        #expect(sheet.nothingRecorded == nil)
        #expect(sheet.sales == AdvisorText.offerMeasureLines(measures, kind: .sale, rules: rules))
        #expect(sheet.loans == AdvisorText.offerMeasureLines(measures, kind: .loan, rules: rules))
        #expect(sheet.counterStep == AdvisorText.counterStepLine(measures, rules: rules))
        #expect(sheet.offersMeasureAgain)
        #expect(sheet.measuredFrom == nil)
        #expect(sheet.showsMeasuredLine)
        moveDate(s.t, by: 1)
        s.model.measureOffersAgain()
        sheet = self.sheet(s.t)
        #expect(sheet.measuredFrom == "Measured from Sat 14 Nov.")
        #expect(sheet.offersMeasureAgain)
        #expect(sheet.sales == ["Sales: nothing recorded."])
    }

    @Test func aMeasuredLineChangesEveryBlocksTerms() throws {
        let s = try ready()
        let day = s.model.settings.currentDate
        // Five deals in which a club paid 22% of value and five in which one turned down 80%: a line of 51%.
        for index in 0..<10 {
            let paid = index < 5
            let round = OfferRound(day: day, by: paid ? .club : .owner, terms: Self.sale(paid ? 2_200 : 8_000),
                                   value: 10_000, wagePerWeek: 300, answer: paid ? nil : .refused)
            s.model.offers.deals.append(OfferDeal(id: UUID(), player: PlayerID(key: "fmrte:\(900_000 + index)"),
                                                  playerName: "Player \(index)", kind: .sale, club: "Club \(index)",
                                                  figures: nil, rounds: [round], endedOn: day))
        }
        #expect(abs(try #require(s.model.offerMeasures.sale.line) - 0.51) < 1e-9)
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.setClubFigure(.transferBudget, text: "35,000", club: "Barnet")
        let seller = try block(sheet(s.t, clubs: [s.seller: "Barnet"]), s.seller)
        #expect(seller.general?.terms == Self.sale(20_000))                             // 20,400 rounded
        #expect(seller.clubBlock?.terms == Self.sale(20_000))
        let measured = "The line your own offers show is 51% of his value (this tool's estimate)."
        #expect(seller.general?.lines.contains(measured) == true)
        #expect(seller.clubBlock?.lines.contains(measured) == true)
    }

    @Test func badParametersReplaceEverySuggestionWithTheirSentenceOnce() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.setOfferValue(text: "8000", for: s.loanee)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale(8_000))
        var parameters = EngineParameters.fm27
        var broken = parameters.offerRules.value
        broken.saleLine = 0
        parameters.offerRules = Parameter(broken, .derived, source: "a test")
        let sentence = ErrorDescriptions.describe(PlanError.badParameters(FitnessModel.problems(in: parameters)))
        let sheet = s.model.offersSheet(clubs: [s.seller: "Wealdstone", s.loanee: "Wealdstone"], parameters: parameters)
        for block in sheet.toSell + sheet.toLoanOut {
            #expect(block.needsValue == sentence)
            #expect(block.general == nil && block.clubBlock == nil && block.clubProblem == nil)
            #expect(block.deals.allSatisfy { $0.next == nil && $0.problem == nil })
        }
        #expect(try block(sheet, s.seller).deals.count == 1)
    }

    // MARK: The sheet a round is recorded in

    @Test func theDraftOpensFilledAndGivesBackTheTerms() throws {
        let id = PlayerID(key: "fmrte:1")
        let terms = OfferTerms.sale(SaleTerms(now: 35_000, later: 5_000, nextFeePercent: 20))
        var draft = OfferRoundDraft(player: id, kind: .sale, club: "Barnet", purpose: .mine, loanPurpose: nil,
                                    filledWith: terms)
        #expect((draft.now, draft.later, draft.nextFee) == ("35000", "5000", "20"))
        #expect(try draft.terms() == terms)
        #expect(draft.title == "Record my proposal")
        #expect(draft.loanPurpose == nil)
        draft.set(.feeNow, text: "£12,500")
        #expect(draft.now == "12500")
        #expect(try draft.terms() == .sale(SaleTerms(now: 12_500, later: 5_000, nextFeePercent: 20)))
        draft.set(.wagePercent, text: "50")                                              // not a sale's field
        #expect(draft.wagePercent == "")

        let none = OfferRoundDraft(player: id, kind: .sale, club: "", purpose: .ask, loanPurpose: nil,
                                   filledWith: Self.sale(40_000))
        #expect((none.now, none.later, none.nextFee) == ("40000", "0", "20"))
        #expect(none.title == "Record this ask")

        let blank = OfferRoundDraft(player: id, kind: .sale, club: "Barnet", purpose: .mine, loanPurpose: nil,
                                    filledWith: nil)
        #expect((blank.now, blank.later, blank.nextFee) == ("", "", ""))
        let theirs = OfferRoundDraft(player: id, kind: .sale, club: "Barnet", purpose: .theirs, loanPurpose: nil,
                                     filledWith: nil)
        #expect(theirs.title == "Record their bid")

        let loan = LoanTerms(wagePercent: 50, feePerMonth: 1_000, playingTime: .startingPlace, recall: true, futureFee: nil)
        var mine = OfferRoundDraft(player: id, kind: .loan, club: "Barnet", purpose: .mine, loanPurpose: .development,
                                   filledWith: .loan(loan))
        #expect((mine.wagePercent, mine.feePerMonth, mine.futureFee) == ("50", "1000", ""))
        #expect(mine.playingTime == .startingPlace && mine.recall)
        #expect(mine.loanPurpose == .development)
        #expect(try mine.terms() == .loan(loan))
        mine.set(.futureFee, text: "100,000")
        mine.recall = false
        mine.playingTime = nil
        #expect(try mine.terms() == .loan(LoanTerms(wagePercent: 50, feePerMonth: 1_000, playingTime: nil, recall: false,
                                                    futureFee: 100_000)))
        var wageLoan = loan
        wageLoan.playingTime = nil
        wageLoan.futureFee = 0
        let withFee = OfferRoundDraft(player: id, kind: .loan, club: "Barnet", purpose: .mine, loanPurpose: .wage,
                                      filledWith: .loan(wageLoan))
        #expect(withFee.futureFee == "0")
        #expect(try withFee.terms() == .loan(wageLoan))
    }

    @Test func theirOfferForADevelopmentLoanStartsAtLessThanAStartingPlaceAndForAWageLoanAtNone() throws {
        let id = PlayerID(key: "fmrte:1")
        let development = LoanTerms(wagePercent: 50, feePerMonth: 0, playingTime: .startingPlace, recall: true,
                                    futureFee: nil)
        var wage = development
        wage.playingTime = nil
        for terms in [OfferTerms.loan(development), .loan(wage), nil] {
            let theirs = OfferRoundDraft(player: id, kind: .loan, club: "Barnet", purpose: .theirs,
                                         loanPurpose: .development, filledWith: terms)
            #expect(theirs.playingTime == .less)
            let theirsWage = OfferRoundDraft(player: id, kind: .loan, club: "Barnet", purpose: .theirs,
                                             loanPurpose: .wage, filledWith: terms)
            #expect(theirsWage.playingTime == nil)
        }
        // The owner's own round opened with no terms asks what the loan is for asks.
        #expect(OfferRoundDraft(player: id, kind: .loan, club: "Barnet", purpose: .mine, loanPurpose: .development,
                                filledWith: nil).playingTime == .startingPlace)
        #expect(OfferRoundDraft(player: id, kind: .loan, club: "Barnet", purpose: .mine, loanPurpose: .wage,
                                filledWith: nil).playingTime == nil)
    }

    @Test func aDraftForAPlayerTakesHisKindFromHisMarkAndHisLoansPurpose() throws {
        let s = try ready()
        let sale = try #require(s.model.offerDraft(for: s.seller, club: "", purpose: .ask, filledWith: Self.sale(40_000)))
        #expect(sale.kind == .sale && sale.loanPurpose == nil && sale.player == s.seller && sale.purpose == .ask)
        #expect(sale.now == "40000")
        s.model.setLoanPurpose(.development, for: s.loanee)
        let development = try #require(s.model.offerDraft(for: s.loanee, club: "Barnet", purpose: .theirs, filledWith: nil))
        #expect(development.kind == .loan && development.loanPurpose == .development && development.club == "Barnet")
        #expect(development.playingTime == .less)
        s.model.setLoanPurpose(.wage, for: s.loanee)
        let wage = try #require(s.model.offerDraft(for: s.loanee, club: "Barnet", purpose: .theirs, filledWith: Self.loan))
        #expect(wage.loanPurpose == .wage && wage.playingTime == nil)
        #expect(wage.wagePercent == "")
        let unmarked = try #require(s.model.players.first { s.model.marks[$0.id] == nil }).id
        #expect(s.model.offerDraft(for: unmarked, club: "", purpose: .ask, filledWith: nil) == nil)
    }

    @Test func theirBidNeverOpensWithTheSuggestion() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        let sale = try #require(s.model.offerDraft(for: s.seller, club: "Barnet", purpose: .theirs,
                                                   filledWith: Self.sale(35_000, later: 5_000)))
        #expect((sale.now, sale.later, sale.nextFee) == ("", "0", "0"))
        // A stray Save records nothing: the money now is blank and named.
        #expect(s.model.record(sale) == .refused("Enter the money now to record this."))
        #expect(s.model.offers.deals.isEmpty)
        let loanTerms = LoanTerms(wagePercent: 50, feePerMonth: 1_000, playingTime: .startingPlace, recall: false,
                                  futureFee: 9_000)
        s.model.setLoanPurpose(.development, for: s.loanee)
        let development = try #require(s.model.offerDraft(for: s.loanee, club: "Barnet", purpose: .theirs,
                                                          filledWith: .loan(loanTerms)))
        #expect((development.wagePercent, development.feePerMonth, development.futureFee) == ("", "0", ""))
        #expect(development.playingTime == .less && development.recall)
        s.model.setLoanPurpose(.wage, for: s.loanee)
        let wage = try #require(s.model.offerDraft(for: s.loanee, club: "Barnet", purpose: .theirs,
                                                   filledWith: .loan(loanTerms)))
        #expect((wage.wagePercent, wage.feePerMonth, wage.futureFee) == ("", "0", ""))
        #expect(wage.playingTime == nil && wage.recall)
        // His own proposal still opens with the suggestion.
        let mine = try #require(s.model.offerDraft(for: s.seller, club: "Barnet", purpose: .mine,
                                                   filledWith: Self.sale(35_000, later: 5_000)))
        #expect((mine.now, mine.later, mine.nextFee) == ("35000", "5000", "20"))
    }

    @Test func eachAmountIsReadBackBesideItsFieldInTheMoneyStyle() throws {
        let s = try ready()
        #expect(try block(sheet(s.t), s.seller).valueReading == nil)                    // nothing beside a blank field
        s.model.setOfferValue(text: "40K", for: s.seller)
        #expect(try block(sheet(s.t), s.seller).valueReading == "£40")                  // 40 typed for 40K is seen at once
        s.model.setOfferValue(text: "40,000", for: s.seller)
        #expect(try block(sheet(s.t), s.seller).valueReading == "£40,000")
        s.model.setClubFigure(.transferBudget, text: "15000", club: "Barnet")
        s.model.setClubFigure(.wageBudget, text: "9000", club: "Barnet")
        let fields = try block(sheet(s.t, clubs: [s.seller: "Barnet"]), s.seller).clubFields
        #expect(fields.map(\.reading) == ["£15,000", "£9,000 a week", nil, nil])
        // A monthly save reads its wage figures by the month.
        try s.t.importFirstTeamInDollarsMonthly()
        s.model.setClubFigure(.wagesSpent, text: "5,200", club: "Barnet")
        let monthly = try block(sheet(s.t, clubs: [s.seller: "Barnet"]), s.seller).clubFields
        #expect(monthly[2].reading == "$5,200 a month")
    }

    @Test func theSheetsMoneyFieldsAreReadBackAndItsPercentagesAreNot() throws {
        let s = try ready()
        var sale = try #require(s.model.offerDraft(for: s.seller, club: "Barnet", purpose: .mine,
                                                   filledWith: Self.sale(35_000, later: 5_000)))
        #expect(s.model.offerReading(.feeNow, in: sale) == "£35,000")
        #expect(s.model.offerReading(.feeLater, in: sale) == "£5,000")
        #expect(s.model.offerReading(.nextFeePercent, in: sale) == nil)
        sale.set(.feeNow, text: "")
        #expect(s.model.offerReading(.feeNow, in: sale) == nil)
        sale.set(.feeNow, text: "1234567890123")
        #expect(sale.now == "123456789012")                                             // twelve digits at most
        var loan = try #require(s.model.offerDraft(for: s.loanee, club: "Barnet", purpose: .mine, filledWith: Self.loan))
        #expect(s.model.offerReading(.feePerMonth, in: loan) == "£1,000")
        #expect(s.model.offerReading(.wagePercent, in: loan) == nil)
        #expect(s.model.offerReading(.futureFee, in: loan) == nil)
        loan.set(.futureFee, text: "100000")
        #expect(s.model.offerReading(.futureFee, in: loan) == "£100,000")
        #expect(s.model.offerReading(.feeNow, in: loan) == nil)                          // not a loan's field
    }

    @Test func clubsInGeneralAreShownWithTermsOrWithAsks() throws {
        let s = try ready()
        #expect(!(try block(sheet(s.t), s.seller)).showsGeneral)                        // no value, no asks
        s.model.setOfferValue(text: "40000", for: s.seller)
        #expect(try block(sheet(s.t), s.seller).showsGeneral)
        s.model.recordAsk(for: s.seller, terms: Self.sale(40_000))
        s.model.setOfferValue(text: "", for: s.seller)
        let asksOnly = try block(sheet(s.t), s.seller)
        #expect(asksOnly.general == nil && !asksOnly.asks.isEmpty && asksOnly.showsGeneral)
    }

    @Test func aBlankFieldInTheDraftIsNamed() throws {
        let id = PlayerID(key: "fmrte:1")
        var sale = OfferRoundDraft(player: id, kind: .sale, club: "Barnet", purpose: .mine, loanPurpose: nil,
                                   filledWith: Self.sale(40_000))
        sale.set(.feeNow, text: "")
        #expect(throws: OfferError.missing(.feeNow, club: nil)) { try sale.terms() }
        sale.set(.feeNow, text: "1")
        sale.set(.feeLater, text: "abc")
        #expect(throws: OfferError.missing(.feeLater, club: nil)) { try sale.terms() }
        sale.set(.feeLater, text: "0")
        sale.set(.nextFeePercent, text: "")
        #expect(throws: OfferError.missing(.nextFeePercent, club: nil)) { try sale.terms() }
        #expect(ErrorDescriptions.describe(OfferError.missing(.feeNow, club: nil)) == "Enter the money now to record this.")

        var loan = OfferRoundDraft(player: id, kind: .loan, club: "Barnet", purpose: .mine, loanPurpose: .development,
                                   filledWith: Self.loan)
        loan.set(.wagePercent, text: "")
        #expect(throws: OfferError.missing(.wagePercent, club: nil)) { try loan.terms() }
        loan.set(.wagePercent, text: "25")
        loan.set(.feePerMonth, text: "")
        #expect(throws: OfferError.missing(.feePerMonth, club: nil)) { try loan.terms() }
    }

    @Test func savingADraftRecordsItAndARefusalIsReturnedWithNothingSaved() throws {
        let s = try ready()
        func draft(_ club: String, _ purpose: OfferRoundDraft.Purpose, _ terms: OfferTerms) throws -> OfferRoundDraft {
            try #require(s.model.offerDraft(for: s.seller, club: club, purpose: purpose, filledWith: terms))
        }
        #expect(s.model.record(try draft("", .ask, Self.sale(40_000))) == .refused("Enter his value to get terms."))
        #expect(s.model.offers.asks.isEmpty)
        advance(s.t)
        s.model.setOfferValue(text: "40000", for: s.seller)
        var blank = try draft("Barnet", .mine, Self.sale(40_000))
        blank.set(.feeNow, text: "")
        let files = try ScoutingSetup.storeFiles(s.t)
        #expect(s.model.record(blank) == .refused("Enter the money now to record this."))
        #expect(try ScoutingSetup.storeFiles(s.t) == files)
        #expect(s.model.offers.deals.isEmpty)

        let planned = s.model.timesPlanned
        let general = try #require(try block(sheet(s.t), s.seller).general?.terms)
        #expect(s.model.record(try draft("", .ask, general)) == .recorded)
        #expect(s.model.offers.asks.map(\.terms) == [general])
        // A second click within the guard is ignored, and says so, so the sheet stays open.
        #expect(s.model.record(try draft("", .ask, general)) == .ignored)
        #expect(s.model.offers.asks.count == 1)
        advance(s.t)
        #expect(s.model.record(try draft("  ", .mine, Self.sale(40_000))) == .ignored)    // a blank club
        #expect(s.model.offers.deals.isEmpty)
        advance(s.t)
        #expect(s.model.record(try draft("Barnet", .mine, Self.sale(40_000))) == .recorded)
        advance(s.t)
        var bid = try draft("barnet", .theirs, Self.sale(40_000))                         // opens blank, not at his terms
        bid.set(.feeNow, text: "30,000")
        #expect(s.model.record(bid) == .recorded)
        #expect(s.model.offers.deals.count == 1)
        #expect(s.model.offers.deals.first?.rounds.map(\.by) == [.owner, .club])
        #expect(s.model.offers.deals.first?.rounds.map(\.terms) == [Self.sale(40_000), Self.sale(30_000, nextFee: 0)])
        #expect(s.model.timesPlanned == planned)
    }

    // MARK: Goalkeepers

    /// Marks the player to loan out for his development, with a value, and gives back his loan block's general lines.
    private func developmentLoanLines(_ s: Setup, _ id: PlayerID) throws -> [String] {
        s.model.setMark(.toLoanOut, for: id)
        #expect(s.model.marks[id] == .toLoanOut)
        s.model.setLoanPurpose(.development, for: id)
        s.model.setOfferValue(text: "200000", for: id)
        return try #require(try block(sheet(s.t), id).general?.lines)
    }

    @Test func aGoalkeeperIsAPlayerWhosePositionsAreGoalkeeperOnly() throws {
        let s = try ready()
        let keeper = try #require(s.model.squad.book.allPlayers.first { $0.name == "Jonny Maxted" })
        #expect(keeper.positionsText == "GK")
        let lines = try developmentLoanLines(s, keeper.id)
        #expect(lines.first?.contains("a starting place (First-Choice Goalkeeper)") == true)
    }

    @Test func anOutfieldPlayerSolidInGoalIsNotAGoalkeeper() throws {
        let s = try ready()
        var players = try #require(s.model.squad.book.current[.firstTeam])
        let index = try #require(players.firstIndex { $0.id == s.loanee })
        #expect(players[index].positionsText.uppercased() != "GK")
        players[index].familiarity[.goalkeeper] = 20
        _ = s.model.squad.book.apply(ImportResult(grid: "test", players: players, warnings: [], money: .weeklyPounds),
                                     to: .firstTeam)
        let lines = try developmentLoanLines(s, s.loanee)
        #expect(lines.first?.contains("a starting place (Regular Starter)") == true)
    }

    @Test func buildingTheSheetChangesNothingAndSavesNothing() throws {
        let s = try ready()
        s.model.setOfferValue(text: "40000", for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale(8_000))
        let files = try ScoutingSetup.storeFiles(s.t)
        let planned = s.model.timesPlanned, offers = s.model.offers
        _ = sheet(s.t, clubs: [s.seller: "Wealdstone"])
        #expect(try ScoutingSetup.storeFiles(s.t) == files)
        #expect(s.model.timesPlanned == planned && s.model.offers == offers)
    }

    // MARK: The sample data the pictures are drawn from

    @Test func theSampleOffersHoldAPlayerOfEachKindADealWithABidAndAnAsk() throws {
        let model = try SampleData.modelWithOffers(repositoryRoot: Captures.repositoryRoot)
        let sheet = model.offersSheet(clubs: [:])
        #expect(sheet.nobodyMarked == nil)
        #expect(sheet.toSell.count == 2 && sheet.toLoanOut.count == 1)
        let seller = try #require(sheet.toSell.first { !$0.valueText.isEmpty })
        #expect(seller.needsValue == nil && seller.general != nil)
        #expect(seller.asks.count == 1 && seller.asks.first?.offersNoBid == true)
        let deal = try #require(seller.deals.first)
        #expect(seller.deals.count == 1 && deal.heading == "Barnet · open" && deal.isOpen)
        #expect(deal.rounds.last?.offersAccept == true)
        #expect(deal.next?.terms != nil)
        let noValue = try #require(sheet.toSell.first { $0.valueText.isEmpty })
        #expect(noValue.needsValue == "Enter his value to get terms.")
        #expect(noValue.deals.isEmpty && noValue.asks.isEmpty)
        let loanee = try #require(sheet.toLoanOut.first)
        #expect(!loanee.valueText.isEmpty && loanee.general != nil)
        #expect(loanee.purpose == .development)
        #expect(sheet.earlier == nil)
        #expect(sheet.offersMeasureAgain)
    }

    @Test func theMeasuredSampleGivesASaleLine() throws {
        let model = try SampleData.modelWithMeasuredOffers(repositoryRoot: Captures.repositoryRoot)
        #expect(model.offerMeasures.sale.line != nil)
        let sheet = model.offersSheet(clubs: [:])
        #expect(sheet.toSell.count == 2 && sheet.toLoanOut.count == 1)
        #expect(sheet.earlier?.deals.count == 10)
        #expect(sheet.earlier?.deals.allSatisfy { $0.heading.hasSuffix("ended") } == true)
    }

    // MARK: What the screen offers

    @Test func aClubWithNoOpenDealOffersRecordingWithOrWithoutTerms() throws {
        let s = try ready()
        // No value: nothing can be recorded, so nothing is offered.
        #expect(!(try block(sheet(s.t, clubs: [s.seller: "Barnet"]), s.seller)).offersClubRecording)
        s.model.setOfferValue(text: "40000", for: s.seller)
        // No club typed: nothing to record, and no figures to enter.
        #expect(!(try block(sheet(s.t), s.seller)).offersClubRecording)
        #expect(!(try block(sheet(s.t), s.seller)).showsClubFields)
        #expect(!(try block(sheet(s.t, clubs: [s.seller: "  "]), s.seller)).showsClubFields)
        #expect(try block(sheet(s.t, clubs: [s.seller: "Barnet"]), s.seller).showsClubFields)
        // A club with no figures: its problem, and a bid or a proposal can still be recorded.
        let problem = try block(sheet(s.t, clubs: [s.seller: "Barnet"]), s.seller)
        #expect(problem.clubProblem != nil && problem.offersClubRecording)
        s.model.setClubFigure(.transferBudget, text: "35000", club: "Barnet")
        #expect(try block(sheet(s.t, clubs: [s.seller: "Barnet"]), s.seller).offersClubRecording)
        // An open deal there takes its rounds below, in its card.
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale(8_000))
        let open = try block(sheet(s.t, clubs: [s.seller: "Barnet"]), s.seller)
        #expect(open.clubHasOpenDeal != nil && !open.offersClubRecording)
        #expect(open.showsClubFields)
    }

    @Test func theSheetSaysWhoseRoundItIs() throws {
        let s = try ready()
        let name = try player(s.seller, s.model).name
        let round = try #require(s.model.offerDraft(for: s.seller, club: " Barnet ", purpose: .theirs, filledWith: nil))
        #expect(s.model.offerEditorLine(round) == "\(name) · Barnet")
        let ask = try #require(s.model.offerDraft(for: s.seller, club: "", purpose: .ask, filledWith: nil))
        #expect(s.model.offerEditorLine(ask) == name)
        let gone = OfferRoundDraft(player: PlayerID(key: "fmrte:999999"), kind: .sale, club: "", purpose: .ask,
                                   loanPurpose: nil, filledWith: nil)
        #expect(s.model.offerEditorLine(gone) == "")
    }

    @Test func thePlayingTimeIsAskedForADevelopmentLoanOrOneThatHasIt() {
        let id = PlayerID(key: "fmrte:1")
        let sale = OfferRoundDraft(player: id, kind: .sale, club: "", purpose: .ask, loanPurpose: nil,
                                   filledWith: Self.sale(40_000))
        #expect(!sale.showsPlayingTime)
        let development = OfferRoundDraft(player: id, kind: .loan, club: "Barnet", purpose: .theirs,
                                          loanPurpose: .development, filledWith: nil)
        #expect(development.showsPlayingTime)
        var wage = OfferRoundDraft(player: id, kind: .loan, club: "Barnet", purpose: .theirs, loanPurpose: .wage,
                                   filledWith: nil)
        #expect(!wage.showsPlayingTime)
        wage.playingTime = .startingPlace
        #expect(wage.showsPlayingTime)
        #expect(OffersPresentation.playingTimeChoices.map(\.title) == ["A starting place", "Less than a starting place"])
        #expect(OffersPresentation.loanPurposeChoices.map(\.title) == ["For his development", "To move his wage"])
    }

    // MARK: Navigation

    @Test func theScreensChoicesStartClosedAndEmpty() {
        let navigation = Navigation()
        #expect(navigation.offerClub.isEmpty)
        #expect(!navigation.offersEarlierOpen)
        #expect(navigation.offerEditor == nil)
    }
}
