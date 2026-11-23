import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

/// Sale terms or loan terms for every marked player, whatever his mark (the owner's request of 22 November 2026): the
/// control in his block, the choice saved with his value, who cannot be loaned, and deals of both kinds in his block.
@MainActor @Suite struct OffersKindTests {
    /// The model with the first team imported, one player marked to sell and one to loan out, both with a value, and the
    /// clock stopped.
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
        t.model.setOfferValue(text: "40000", for: seller)
        t.model.setOfferValue(text: "8000", for: loanee)
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

    /// Changes the player in the first team, as an import of the changed squad would.
    private func edit(_ s: Setup, _ id: PlayerID, _ change: (inout Player) -> Void) throws {
        var players = try #require(s.model.squad.book.current[.firstTeam])
        let index = try #require(players.firstIndex { $0.id == id })
        change(&players[index])
        _ = s.model.squad.book.apply(ImportResult(grid: "test", players: players, warnings: [], money: .weeklyPounds),
                                     to: .firstTeam)
    }

    private static let sale = OfferTerms.sale(SaleTerms(now: 30_000, later: 10_000, nextFeePercent: 20))
    private static let loan = OfferTerms.loan(LoanTerms(wagePercent: 50, feePerMonth: 1_000, playingTime: .startingPlace,
                                                        recall: true, futureFee: nil))

    // MARK: The control

    @Test func eachMarkedPlayerIsOfferedBothKindsStartingAtHisMark() throws {
        let s = try ready()
        let sheet = sheet(s.t)
        let seller = try block(sheet, s.seller), loanee = try block(sheet, s.loanee)
        #expect(seller.kindChoices.map(\.title) == ["Sale terms", "Loan terms"])
        #expect(seller.kindChoices.map(\.kind) == [.sale, .loan])
        #expect(loanee.kindChoices == seller.kindChoices)
        #expect(seller.kind == .sale && loanee.kind == .loan)
        #expect(seller.kindNote == nil && loanee.kindNote == nil)
        #expect(OffersPresentation.saleTermsTitle == "Sale terms" && OffersPresentation.loanTermsTitle == "Loan terms")
    }

    @Test func aPlayerToSellSwitchedToLoanTermsGetsLoanTermsAndThePurposeMenuThenSaleTermsAgain() throws {
        let s = try ready()
        s.model.setOfferKind(.loan, for: s.seller)
        #expect(s.model.offerKind(for: s.seller) == .loan)
        var seller = try block(sheet(s.t, clubs: [s.seller: "Barnet"]), s.seller)
        #expect(sheet(s.t).toSell.map(\.id) == [s.seller])                               // the sections stay by mark
        #expect(seller.kind == .loan)
        #expect(seller.purpose == s.model.loanPurpose(for: s.seller))
        guard case .loan? = seller.general?.terms else { Issue.record("no loan terms"); return }
        #expect(seller.clubProblem == "Enter Barnet's wage budget to get terms for them.")
        let draft = try #require(s.model.offerDraft(for: s.seller, club: "", purpose: .ask, filledWith: seller.general?.terms))
        #expect(draft.kind == .loan && draft.loanPurpose == s.model.loanPurpose(for: s.seller))

        s.model.setOfferKind(.sale, for: s.seller)
        #expect(s.model.offerKind(for: s.seller) == .sale)
        #expect(s.model.offers.players[s.seller]?.kind == nil)                           // back to following the mark
        seller = try block(sheet(s.t, clubs: [s.seller: "Barnet"]), s.seller)
        #expect(seller.kind == .sale && seller.purpose == nil)
        guard case .sale? = seller.general?.terms else { Issue.record("no sale terms"); return }
        #expect(seller.clubProblem == "Enter what Barnet can spend on transfers to get terms for them.")
    }

    @Test func thePlayersChoiceSurvivesARestart() throws {
        let s = try ready()
        s.model.setOfferKind(.loan, for: s.seller)
        #expect(s.model.offers.players[s.seller]?.kind == .loan)
        #expect(s.model.offers.players[s.seller]?.value == 40_000)                       // kept with his value
        let reopened = s.t.reopened()
        #expect(reopened.offerKind(for: s.seller) == .loan)
        #expect(reopened.offers == s.model.offers)
    }

    @Test func aPlayerToLoanOutCanBeSwitchedToSaleTerms() throws {
        let s = try ready()
        s.model.setOfferKind(.sale, for: s.loanee)
        let loanee = try block(sheet(s.t), s.loanee)
        #expect(sheet(s.t).toLoanOut.map(\.id) == [s.loanee])
        #expect(loanee.kind == .sale && loanee.purpose == nil)
        guard case .sale? = loanee.general?.terms else { Issue.record("no sale terms"); return }
    }

    @Test func settingTheKindSavesOnlyTheOffersFileAndDoesNotPlan() throws {
        let s = try ready()
        let planned = s.model.timesPlanned
        let files = try ScoutingSetup.storeFiles(s.t)
        s.model.setOfferKind(.loan, for: s.seller)
        #expect(s.model.timesPlanned == planned)
        let now = try ScoutingSetup.storeFiles(s.t)
        #expect(now.filter { files[$0.key] != $0.value }.map(\.key) == ["offers.json"])
        // Nothing for a player with no mark or not in the squads, or for the kind already shown.
        let unmarked = try #require(s.model.players.first { s.model.marks[$0.id] == nil }).id
        let offers = s.model.offers
        s.model.setOfferKind(.loan, for: unmarked)
        s.model.setOfferKind(.loan, for: PlayerID(key: "nobody at all"))
        s.model.setOfferKind(.loan, for: s.seller)
        #expect(s.model.offers == offers)
        #expect(try ScoutingSetup.storeFiles(s.t) == now)
        #expect(s.model.offerKind(for: unmarked) == nil)
    }

    @Test func aFileWrittenBeforeTheChoiceOpensWithNoNoticeAndNobodysChoiceSet() throws {
        let s = try ready()
        s.model.setOfferKind(.loan, for: s.seller)
        let file = s.t.directory.appendingPathComponent("offers.json")
        let saved = try String(contentsOf: file, encoding: .utf8)
        #expect(saved.contains("\"kind\""))
        // The file as written before the key existed: every "kind" taken out (nothing else here carries one).
        func strip(_ value: Any) -> Any {
            if let dictionary = value as? [String: Any] {
                return dictionary.filter { $0.key != "kind" }.mapValues(strip)
            }
            if let array = value as? [Any] { return array.map(strip) }
            return value
        }
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: file))
        try JSONSerialization.data(withJSONObject: strip(json)).write(to: file)
        #expect(!(try String(contentsOf: file, encoding: .utf8)).contains("\"kind\""))
        let reopened = s.t.reopened()
        #expect(reopened.notices.isEmpty)
        #expect(reopened.offers.players[s.seller]?.kind == nil)
        #expect(reopened.offers.players[s.seller]?.value == 40_000)
        #expect(reopened.offerKind(for: s.seller) == .sale)
    }

    // MARK: Who cannot be loaned

    @Test func aPlayerOnAYouthContractIsOfferedOnlySaleTerms() throws {
        let s = try ready()
        try edit(s, s.seller) { $0.contractType = .youth; $0.monthsLeft = 24 }
        #expect(s.model.loanRefusal(for: s.seller) == AdvisorText.youthContractNotLoaned)
        s.model.setOfferKind(.loan, for: s.seller)
        #expect(s.model.offers.players[s.seller]?.kind == nil)
        // A loan choice saved before is not followed.
        s.model.offers.players[s.seller]?.kind = .loan
        #expect(s.model.offerKind(for: s.seller) == .sale)
        let seller = try block(sheet(s.t), s.seller)
        #expect(seller.kindChoices.map(\.title) == ["Sale terms"])
        #expect(seller.kindNote == "A player on a youth contract cannot be loaned out; he can be sold or released.")
        #expect(seller.kind == .sale && seller.purpose == nil)
        guard case .sale? = seller.general?.terms else { Issue.record("no sale terms"); return }
        // A loan ask or round for him is refused with the sentence, and nothing is saved.
        let files = try ScoutingSetup.storeFiles(s.t)
        #expect(s.model.recordAsk(for: s.seller, terms: Self.loan, kind: .loan) == AdvisorText.youthContractNotLoaned)
        advance(s.t)
        #expect(s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.loan, kind: .loan)
                == AdvisorText.youthContractNotLoaned)
        #expect(s.model.offers.asks.isEmpty && s.model.offers.deals.isEmpty)
        #expect(try ScoutingSetup.storeFiles(s.t) == files)
        // A youth contract with 0 months left is no contract: both kinds.
        try edit(s, s.seller) { $0.monthsLeft = 0 }
        #expect(s.model.loanRefusal(for: s.seller) == nil)
        #expect(try block(sheet(s.t), s.seller).kindChoices.count == 2)
    }

    @Test func aPlayerOutOnLoanIsOfferedOnlySaleTerms() throws {
        let s = try ready()
        try edit(s, s.seller) { $0.loanedTo = "Elsewhere Town" }
        #expect(s.model.marks[s.seller] == .toSell)
        #expect(s.model.loanRefusal(for: s.seller) == AdvisorText.outOnLoanAlready)
        s.model.offers.players[s.seller]?.kind = .loan
        #expect(s.model.offerKind(for: s.seller) == .sale)
        let seller = try block(sheet(s.t), s.seller)
        #expect(seller.kindChoices.map(\.kind) == [.sale])
        #expect(seller.kindNote == "He is out on loan already, so only a sale can be worked out.")
        #expect(seller.kind == .sale)
        let draft = OfferRoundDraft(player: s.seller, kind: .loan, club: "Barnet", purpose: .mine, loanPurpose: .wage,
                                    filledWith: Self.loan)
        #expect(s.model.record(draft) == .refused(AdvisorText.outOnLoanAlready))
        #expect(s.model.offers.deals.isEmpty)
        // A player not out on loan and on a full-time contract can be loaned.
        #expect(s.model.loanRefusal(for: s.loanee) == nil)
    }

    // MARK: Deals and asks of both kinds

    @Test func aLoanDealRecordedUnderLoanTermsStaysInHisBlockUnderSaleTermsAndFollowsItsOwnKind() throws {
        let s = try ready()
        s.model.setClubFigure(.wageBudget, text: "9000", club: "Barnet")
        s.model.setClubFigure(.wagesSpent, text: "8000", club: "Barnet")
        s.model.setOfferKind(.loan, for: s.seller)
        #expect(s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.loan) == nil)
        #expect(s.model.offers.deals.first?.kind == .loan)
        s.model.setOfferKind(.sale, for: s.seller)
        let sheet = sheet(s.t)
        #expect(sheet.earlier == nil)
        let card = try #require(try block(sheet, s.seller).deals.first)
        #expect(card.heading == "Barnet · loan · open")
        #expect(card.kind == .loan && card.isOpen)
        // The next step is the loan's, as the engine works it out from the deal's rounds.
        let deal = try #require(s.model.offers.deals.first)
        let held = try #require(s.model.players.first { $0.id == s.seller })
        let subject = OfferSubject(value: 40_000, wagePerWeek: held.wagePerWeek, isGoalkeeper: false,
                                   purpose: s.model.loanPurpose(for: s.seller))
        let club = try #require(s.model.clubEntry(named: "Barnet")).figures
        let expected = try Offers.proposal(subject, kind: .loan, club: club, rounds: deal.rounds,
                                           measures: s.model.offerMeasures, parameters: .fm27)
        #expect(card.next?.lines == AdvisorText.offerLines(expected, kind: .loan, subject: subject, club: "Barnet",
                                                          money: s.model.squad.book.moneyStyle,
                                                          rules: EngineParameters.fm27.offerRules.value))
        #expect(card.next != nil && card.problem == nil)
        // Recording from the card's buttons adds to that deal, though sale terms are shown.
        let draft = try #require(s.model.offerDraft(for: s.seller, club: card.club, purpose: .mine,
                                                    filledWith: Self.loan, kind: card.kind))
        #expect(draft.kind == .loan && draft.loanPurpose != nil && draft.wagePercent == "50")
        advance(s.t)
        #expect(s.model.record(draft) == .recorded)
        #expect(s.model.offers.deals.count == 1)
        #expect(s.model.offers.deals.first?.rounds.map(\.by) == [.club, .owner])
        #expect(s.model.openDeal(for: s.seller, club: "Barnet") == nil)                  // no open sale there
        #expect(s.model.openDeal(for: s.seller, club: "Barnet", kind: .loan)?.id == card.id)
    }

    @Test func aSaleDealAndALoanDealWithOneClubCanBothBeOpen() throws {
        let s = try ready()
        s.model.setClubFigure(.transferBudget, text: "35000", club: "Barnet")
        s.model.setClubFigure(.wageBudget, text: "9000", club: "Barnet")
        s.model.setClubFigure(.wagesSpent, text: "8000", club: "Barnet")
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale)
        #expect(try block(sheet(s.t, clubs: [s.seller: "Barnet"]), s.seller).clubHasOpenDeal != nil)
        s.model.setOfferKind(.loan, for: s.seller)
        // The open sale does not stop a loan proposal to the same club.
        let loanShown = try block(sheet(s.t, clubs: [s.seller: "Barnet"]), s.seller)
        #expect(loanShown.clubHasOpenDeal == nil && loanShown.offersClubRecording)
        guard case .loan? = loanShown.clubBlock?.terms else { Issue.record("no loan proposal"); return }
        advance(s.t)
        #expect(s.model.recordRound(for: s.seller, club: "Barnet", by: .owner, terms: Self.loan) == nil)
        #expect(s.model.offers.deals.count == 2)
        #expect(s.model.offers.deals.map(\.state) == [.open, .open])
        #expect(s.model.offers.deals.map(\.kind) == [.sale, .loan])
        let both = try block(sheet(s.t, clubs: [s.seller: "Barnet"]), s.seller)
        #expect(Set(both.deals.map(\.heading)) == ["Barnet · sale · open", "Barnet · loan · open"])
        #expect(both.clubHasOpenDeal != nil)
    }

    @Test func asksOfBothKindsStayInHisBlockEachLatestOfferingNoBidCame() throws {
        let s = try ready()
        s.model.recordAsk(for: s.seller, terms: Self.sale)
        advance(s.t)
        s.model.recordAsk(for: s.seller, terms: Self.sale)
        advance(s.t)
        s.model.setOfferKind(.loan, for: s.seller)
        s.model.recordAsk(for: s.seller, terms: Self.loan)
        #expect(s.model.offers.asks.map(\.kind) == [.sale, .sale, .loan])
        var seller = try block(sheet(s.t), s.seller)
        #expect(seller.asks.map(\.id) == s.model.offers.asks.map(\.id))
        #expect(seller.asks.map(\.offersNoBid) == [false, true, true])
        // His general loan terms are worked out from his loan asks alone.
        let held = try #require(s.model.players.first { $0.id == s.seller })
        let subject = OfferSubject(value: 40_000, wagePerWeek: held.wagePerWeek, isGoalkeeper: false,
                                   purpose: s.model.loanPurpose(for: s.seller))
        let loanAsks = s.model.offers.asks.filter { $0.kind == .loan }
        let expected = try Offers.ask(subject, kind: .loan, earlier: loanAsks, measures: s.model.offerMeasures,
                                      parameters: .fm27)
        #expect(seller.general?.terms == OffersPresentation.terms(of: expected.advice))
        advance(s.t)
        s.model.noBidCame(try #require(s.model.offers.asks.last).id)
        seller = try block(sheet(s.t), s.seller)
        #expect(seller.asks.map(\.offersNoBid) == [false, true, false])
    }

    @Test func earlierOffersHoldOnlyPlayersWithNoMarkOrInNoSquad() throws {
        let s = try ready()
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale)
        advance(s.t)
        s.model.recordAsk(for: s.seller, terms: Self.sale)
        // Marked the other way, his sale deal and ask stay in his block.
        s.model.setMark(.toLoanOut, for: s.seller)
        var sheet = sheet(s.t)
        #expect(sheet.earlier == nil)
        let seller = try block(sheet, s.seller)
        #expect(sheet.toLoanOut.contains { $0.id == s.seller })
        #expect(seller.kind == .loan)
        #expect(seller.deals.map(\.heading) == ["Barnet · sale · open"])
        #expect(seller.asks.count == 1)
        // With no mark they go under "Earlier offers".
        s.model.setMark(nil, for: s.seller)
        sheet = self.sheet(s.t)
        #expect(sheet.earlier?.line == "1 deal and 1 ask for players no longer marked")
        #expect(sheet.earlier?.deals.map(\.heading) == ["\(try #require(s.model.players.first { $0.id == s.seller }).name) · Barnet · sale · open"])
    }

    // MARK: The sample data the pictures are drawn from

    @Test func theSampleWithAPlayerOutOnLoanOffersHimSaleTermsAlone() throws {
        let model = try SampleData.modelWithOfferOutOnLoan(repositoryRoot: Captures.repositoryRoot)
        let sheet = model.offersSheet(clubs: [:])
        let away = try #require(sheet.toSell.first { $0.name == SampleData.offerNoValueName })
        #expect(away.kindChoices.map(\.kind) == [.sale] && away.kind == .sale)
        #expect(away.kindNote == AdvisorText.outOnLoanAlready)
        let seller = try #require(sheet.toSell.first { $0.name == SampleData.offerSellerName })
        #expect(seller.kindChoices.count == 2 && seller.kindNote == nil)
        // Switched to loan terms, the first seller keeps his sale deal in his block.
        model.setOfferKind(.loan, for: seller.id)
        let toggled = try #require(model.offersSheet(clubs: [:]).toSell.first { $0.id == seller.id })
        #expect(toggled.kind == .loan && toggled.purpose != nil)
        #expect(toggled.deals.map(\.heading) == ["Barnet · sale · open"])
    }

    // MARK: The choice follows a change of mark

    @Test func aSavedChoiceIsClearedWhenHisMarkChanges() throws {
        let s = try ready()
        s.model.setLoanPurpose(.wage, for: s.seller)
        s.model.setOfferKind(.loan, for: s.seller)
        #expect(s.model.offers.players[s.seller]?.kind == .loan)
        // A mark set again unchanged clears nothing and writes nothing.
        let files = try ScoutingSetup.storeFiles(s.t)
        s.model.setMark(.toSell, for: s.seller)
        #expect(s.model.offers.players[s.seller]?.kind == .loan)
        #expect(try ScoutingSetup.storeFiles(s.t) == files)
        // Re-marked to loan out, then to sell: his block opens on his mark's kind each time.
        s.model.setMark(.toLoanOut, for: s.seller)
        #expect(s.model.offers.players[s.seller]?.kind == nil)
        #expect(s.model.offerKind(for: s.seller) == .loan)
        s.model.setMark(.toSell, for: s.seller)
        #expect(s.model.offerKind(for: s.seller) == .sale)
        #expect(s.t.reopened().offerKind(for: s.seller) == .sale)
        // His value and his loan's purpose stay.
        #expect(s.model.offers.players[s.seller]?.value == 40_000)
        #expect(s.model.offers.players[s.seller]?.purpose == .wage)
        // Taking the mark off clears it too.
        s.model.setOfferKind(.loan, for: s.seller)
        s.model.setMark(nil, for: s.seller)
        #expect(s.model.offers.players[s.seller]?.kind == nil)
        #expect(s.t.reopened().offers.players[s.seller]?.kind == nil)
    }

    @Test func pressingSaleTermsClearsASavedLoanWhileALoanIsRefused() throws {
        let s = try ready()
        s.model.setOfferKind(.loan, for: s.seller)
        try edit(s, s.seller) { $0.contractType = .youth; $0.monthsLeft = 24 }
        #expect(s.model.offerKind(for: s.seller) == .sale)                               // sale already shown
        #expect(s.model.offers.players[s.seller]?.kind == .loan)
        s.model.setOfferKind(.sale, for: s.seller)
        #expect(s.model.offers.players[s.seller]?.kind == nil)
        #expect(s.t.reopened().offers.players[s.seller]?.kind == nil)
        // Back on a full-time contract he opens on his mark's kind, not the old loan choice.
        try edit(s, s.seller) { $0.contractType = .fullTime }
        #expect(s.model.offerKind(for: s.seller) == .sale)
    }

    // MARK: An open deal stays answerable wherever its card is shown

    /// The first team pasted again without the player, as an import after he was sold: his mark is dropped.
    private func importWithout(_ id: PlayerID, _ s: Setup) throws {
        let name = try #require(s.model.players.first { $0.id == id }).name
        let rows = try Captures.firstTeam.split(whereSeparator: \.isNewline).map(String.init)
            .filter { !$0.contains("\t\"\(name)\"\t") }
        s.t.importSquad(.firstTeam, paste: rows.joined(separator: "\n") + "\n", grids: try Captures.firstTeamGrids)
        #expect(!s.model.players.contains { $0.id == id })
        #expect(s.model.marks[id] == nil)
    }

    private func earlierCard(_ s: Setup) throws -> OfferDealCard {
        try #require(sheet(s.t).earlier?.deals.first)
    }

    /// A card that records outcomes and offers no terms: no next step and no "Record…" buttons.
    private func expectOutcomesOnly(_ card: OfferDealCard, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(card.isOpen, sourceLocation: sourceLocation)
        #expect(!card.offersRecording && card.next == nil && card.problem == nil, sourceLocation: sourceLocation)
    }

    @Test func anOpenDealOfAPlayerWhoLeftCanBeAnsweredFromEarlierOffers() throws {
        let s = try ready()
        s.model.recordRound(for: s.seller, club: "Barnet", by: .owner, terms: Self.sale)
        try importWithout(s.seller, s)
        var card = try earlierCard(s)
        expectOutcomesOnly(card)
        #expect(card.rounds.map(\.offersAnswers) == [true])
        advance(s.t)
        s.model.answer(.accepted, deal: card.id)
        #expect(s.model.offers.deals.first?.state == .agreed)
        #expect(s.model.offerMeasures.sale.paid == 1 && s.model.offerMeasures.sale.agreed == 1)
        // Agreed, it offers nothing but the deletion.
        card = try earlierCard(s)
        #expect(!card.isOpen && !card.offersRecording)
        #expect(card.rounds.allSatisfy { !$0.offersAnswers && !$0.offersAccept })
    }

    @Test func theClubsLastRoundCanBeAcceptedAndADealEndedFromEarlierOffers() throws {
        let s = try ready()
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale)
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Wealdstone", by: .club, terms: Self.sale)
        try importWithout(s.seller, s)
        let cards = try #require(sheet(s.t).earlier?.deals)
        #expect(cards.count == 2)
        for card in cards {
            expectOutcomesOnly(card)
            #expect(card.rounds.map(\.offersAccept) == [true])
        }
        let barnet = try #require(cards.first { $0.club == "Barnet" })
        let wealdstone = try #require(cards.first { $0.club == "Wealdstone" })
        advance(s.t)
        s.model.acceptTheirs(deal: barnet.id)
        advance(s.t)
        s.model.endDeal(wealdstone.id)
        #expect(s.model.offers.deals.first { $0.id == barnet.id }?.state == .agreed)
        #expect(s.model.offers.deals.first { $0.id == wealdstone.id }?.state == .ended)
        let after = try #require(sheet(s.t).earlier?.deals)
        #expect(after.allSatisfy { !$0.isOpen && !$0.offersRecording })
        #expect(after.allSatisfy { $0.rounds.allSatisfy { !$0.offersAnswers && !$0.offersAccept } })
    }

    @Test func aLoanDealOfAPlayerNowOutOnLoanStaysAnswerableInHisBlock() throws {
        let s = try ready()
        s.model.setClubFigure(.wageBudget, text: "9000", club: "Barnet")
        s.model.setClubFigure(.wagesSpent, text: "8000", club: "Barnet")
        s.model.setOfferKind(.loan, for: s.seller)
        s.model.recordRound(for: s.seller, club: "Barnet", by: .owner, terms: Self.loan)
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Hendon", by: .club, terms: Self.loan)
        advance(s.t)
        s.model.recordRound(for: s.seller, club: "Wealdstone", by: .club, terms: Self.loan)
        try edit(s, s.seller) { $0.loanedTo = "Elsewhere Town" }
        #expect(s.model.marks[s.seller] == .toSell)
        let cards = try block(sheet(s.t), s.seller).deals
        #expect(cards.count == 3 && cards.allSatisfy { $0.kind == .loan })
        for card in cards { expectOutcomesOnly(card) }
        let barnet = try #require(cards.first { $0.club == "Barnet" })
        let hendon = try #require(cards.first { $0.club == "Hendon" })
        let wealdstone = try #require(cards.first { $0.club == "Wealdstone" })
        #expect(barnet.rounds.map(\.offersAnswers) == [true])
        #expect(hendon.rounds.map(\.offersAccept) == [true])
        advance(s.t)
        s.model.answer(.accepted, deal: barnet.id)
        advance(s.t)
        s.model.acceptTheirs(deal: hendon.id)
        advance(s.t)
        s.model.endDeal(wealdstone.id)
        let states = Dictionary(uniqueKeysWithValues: s.model.offers.deals.map { ($0.club, $0.state) })
        #expect(states == ["Barnet": .agreed, "Hendon": .agreed, "Wealdstone": .ended])
        #expect(try block(sheet(s.t), s.seller).deals.allSatisfy { !$0.isOpen && !$0.offersRecording })
    }

    @Test func aCardOfAMarkedPlayerWhoseKindCanBeWorkedOutOffersRecording() throws {
        let s = try ready()
        s.model.recordRound(for: s.seller, club: "Barnet", by: .club, terms: Self.sale)
        let card = try #require(try block(sheet(s.t), s.seller).deals.first)
        #expect(card.isOpen && card.offersRecording && card.next != nil)
    }
}
