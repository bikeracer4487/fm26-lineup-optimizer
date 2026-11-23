import Foundation
import Testing
@testable import LineupEngine

@Suite struct OffersSaleTests {
    static let p = EngineParameters.fm27
    static func subject(value: Int = 40_000, wage: Double = 450) -> OfferSubject {
        OfferSubject(value: value, wagePerWeek: wage, isGoalkeeper: false, purpose: .wage)
    }
    static func club(_ budget: Int?, wageBudget: Double? = nil, spent: Double? = nil, highest: Double? = nil) -> ClubFigures {
        ClubFigures(name: "Barnet", transferBudget: budget, wageBudgetPerWeek: wageBudget, wagesSpentPerWeek: spent, highestWagePerWeek: highest)
    }

    @Test func toClubsInGeneralTheAskIsHisValueWithAShareOfTheNextFee() throws {
        let s = try Offers.ask(Self.subject(), kind: .sale, earlier: [], parameters: Self.p)
        #expect(s.advice == .propose(.sale(SaleTerms(now: 40_000, later: 0, nextFeePercent: 20)), split: nil))
        #expect(s.notes == [.doNotList, .noInterestBids])
        #expect(s.basis == .derived)
    }
    @Test func aClubThatCanPayItAllIsAskedForItAllNow() throws {
        let s = try Offers.proposal(Self.subject(), kind: .sale, club: Self.club(50_000), rounds: [], parameters: Self.p)
        #expect(s.advice == .propose(.sale(SaleTerms(now: 40_000, later: 0, nextFeePercent: 20)), split: nil))
        #expect(s.notes.isEmpty)
    }
    @Test func moneyNowIsCappedAtTheBudgetAndTheRestSplit() throws {
        let s = try Offers.proposal(Self.subject(), kind: .sale, club: Self.club(35_000), rounds: [], parameters: Self.p)
        #expect(s.advice == .propose(.sale(SaleTerms(now: 35_000, later: 5_000, nextFeePercent: 20)),
                                     split: SaleSplit(instalments: 2_200, afterAppearances: 2_800)))
        #expect(s.notes == [.restAskedLater(budget: 35_000)])
    }
    @Test func moneyNowIsRoundedDownNeverAboveTheBudget() throws {
        let s = try Offers.proposal(Self.subject(), kind: .sale, club: Self.club(9_950), rounds: [], parameters: Self.p)
        guard case .propose(.sale(let t), let split?) = s.advice else { Issue.record("not a proposal"); return }
        #expect(t.now == 9_900 && t.later == 30_100)
        #expect(split.instalments == 13_000 && split.afterAppearances == 17_100)   // 44% of 30,100 is 13,244
    }
    @Test func aClubWithNothingToSpendIsAskedForAllOfItLater() throws {
        let s = try Offers.proposal(Self.subject(), kind: .sale, club: Self.club(0), rounds: [], parameters: Self.p)
        #expect(s.advice == .propose(.sale(SaleTerms(now: 0, later: 40_000, nextFeePercent: 20)),
                                     split: SaleSplit(instalments: 18_000, afterAppearances: 22_000)))
        #expect(s.notes == [.nothingToSpendNow])
    }
    @Test func aWageHeCannotBePaidThereIsACautionAndChangesNoFigure() throws {
        let rich = try Offers.proposal(Self.subject(), kind: .sale, club: Self.club(50_000, wageBudget: 5_000, spent: 4_000, highest: 900), rounds: [], parameters: Self.p)
        let poor = try Offers.proposal(Self.subject(), kind: .sale, club: Self.club(50_000, wageBudget: 5_000, spent: 4_700, highest: 400), rounds: [], parameters: Self.p)
        #expect(rich.notes.isEmpty)
        #expect(poor.notes == [.wageLeftUnderHisWage(left: 300), .highestWageUnderHisWage(highest: 400)])
        #expect(rich.advice == poor.advice)
    }
    @Test func aSaleToAClubNeedsItsTransferBudget() {
        #expect(throws: OfferError.missing(.transferBudget, club: "Barnet")) {
            try Offers.proposal(Self.subject(), kind: .sale, club: Self.club(nil), rounds: [], parameters: Self.p)
        }
    }
    @Test func aValueOfNothingAsksNoFee() throws {
        let s = try Offers.ask(Self.subject(value: 0), kind: .sale, earlier: [], parameters: Self.p)
        #expect(s.advice == .propose(.sale(SaleTerms(now: 0, later: 0, nextFeePercent: 20)), split: nil))
        #expect(s.notes.first == .valueIsZero)
    }
    @Test func aNonZeroValueSaysNothingOfZero() throws {
        let s = try Offers.ask(Self.subject(), kind: .sale, earlier: [], parameters: Self.p)
        #expect(!s.notes.contains(.valueIsZero))
    }
    @Test func amountsAreRoundedToTwoSignificantFigures() {
        let r = Self.p.offerRules.value
        #expect(Offers.rounded(43_700, rules: r) == 44_000)
        #expect(Offers.rounded(5_460, rules: r) == 5_500)
        #expect(Offers.rounded(9_950, down: true, rules: r) == 9_900)
        #expect(Offers.rounded(87, rules: r) == 87 && Offers.rounded(0, rules: r) == 0)
    }
    @Test func theWageLeftIsNeverBelowNothing() {
        #expect(Self.club(0, wageBudget: 5_000, spent: 6_000).wageLeftPerWeek == 0)
        #expect(Self.club(0, wageBudget: 5_000, spent: nil).wageLeftPerWeek == nil)
        #expect(Self.club(0, wageBudget: 5_000, spent: 4_000).wageLeftPerWeek == 1_000)
    }
    @Test func aDealIsAgreedOnceARoundIsAcceptedAndEndedWhenTheOwnerEndsIt() {
        let day = Day(iso: "2026-11-22")!
        func round(_ answer: RoundAnswer?) -> OfferRound {
            OfferRound(day: day, by: .owner, terms: .sale(SaleTerms(now: 1, later: 0, nextFeePercent: 20)),
                       value: 1, wagePerWeek: 1, answer: answer)
        }
        func deal(_ rounds: [OfferRound], ended: Day?) -> OfferDeal {
            OfferDeal(id: UUID(), player: PlayerID(key: "fmrte:1"), playerName: "A", kind: .sale, club: "Barnet",
                      figures: nil, rounds: rounds, endedOn: ended)
        }
        #expect(deal([round(.refused)], ended: nil).state == .open)
        #expect(deal([round(.refused)], ended: day).state == .ended)
        #expect(deal([round(.accepted)], ended: nil).state == .agreed)
        #expect(deal([round(.accepted)], ended: day).state == .agreed)
    }
    @Test func termsOfTheWrongKindOrOver100AreRefused() throws {
        #expect(throws: OfferError.wrongKind) { try Offers.check(.sale(SaleTerms(now: 1, later: 0, nextFeePercent: 20)), kind: .loan) }
        #expect(throws: OfferError.over100(.nextFeePercent)) { try Offers.check(.sale(SaleTerms(now: 1, later: 0, nextFeePercent: 101)), kind: .sale) }
        #expect(throws: OfferError.over100(.wagePercent)) { try Offers.check(.loan(LoanTerms(wagePercent: 110, feePerMonth: 0, playingTime: nil, recall: true, futureFee: nil)), kind: .loan) }
        #expect(throws: OfferError.negative(.feeNow)) { try Offers.check(.sale(SaleTerms(now: -1, later: 0, nextFeePercent: 0)), kind: .sale) }
        try Offers.check(.sale(SaleTerms(now: 1, later: 0, nextFeePercent: 100)), kind: .sale)
    }
    @Test func savedTermsKeepEveryKeyAndRequireThem() throws {
        let loan = OfferTerms.loan(LoanTerms(wagePercent: 50, feePerMonth: 0, playingTime: nil, recall: true, futureFee: nil))
        let data = try JSONEncoder().encode(loan)
        #expect(String(decoding: data, as: UTF8.self).contains("null"))
        #expect(try JSONDecoder().decode(OfferTerms.self, from: data) == loan)
        let bare = Data(#"{"wagePercent":50,"feePerMonth":0,"recall":true}"#.utf8)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(LoanTerms.self, from: bare) }
    }
    @Test func badRulesStopTheTermsWithTheParameterProblem() {
        var q = Self.p
        var r = q.offerRules.value
        r.saleLine = 0
        q.offerRules = Parameter(r, .derived, source: "test")
        #expect(throws: PlanError.self) { try Offers.ask(Self.subject(), kind: .sale, earlier: [], parameters: q) }
    }

    // MARK: A sale's next step
    static let day = Day(iso: "2026-11-21")!
    func mine(_ now: Int, later: Int = 0, _ answer: RoundAnswer?) -> OfferRound {
        OfferRound(day: Self.day, by: .owner, terms: .sale(SaleTerms(now: now, later: later, nextFeePercent: 20)),
                   value: 40_000, wagePerWeek: 450, answer: answer)
    }
    func theirs(_ now: Int, later: Int = 0, fee: Int = 0) -> OfferRound {
        OfferRound(day: Self.day, by: .club, terms: .sale(SaleTerms(now: now, later: later, nextFeePercent: fee)),
                   value: 40_000, wagePerWeek: 450, answer: nil)
    }
    func asked(_ total: Int, noBid: Bool) -> OfferAsk {
        OfferAsk(id: UUID(), player: PlayerID(key: "fmrte:1"), playerName: "A", kind: .sale, day: Self.day,
                 terms: .sale(SaleTerms(now: total, later: 0, nextFeePercent: 20)), value: 40_000, wagePerWeek: 450, noBidCame: noBid)
    }
    func next(_ rounds: [OfferRound], budget: Int = 35_000) throws -> OfferSuggestion {
        try Offers.proposal(Self.subject(), kind: .sale, club: Self.club(budget), rounds: rounds, parameters: Self.p)
    }
    func ask(_ earlier: [OfferAsk]) throws -> OfferSuggestion {
        try Offers.ask(Self.subject(), kind: .sale, earlier: earlier, parameters: Self.p)
    }

    @Test func aBidAtOrAboveTheAskIsAccepted() throws {
        #expect(try next([theirs(40_000)]).advice == .accept)
        #expect(try next([theirs(30_000, later: 12_000)]).advice == .accept)
    }
    @Test func aLowerBidIsCounteredOnceKeepingItsMoneyNow() throws {
        let s = try next([theirs(8_000)])
        #expect(s.advice == .counter(.sale(SaleTerms(now: 8_000, later: 1_600, nextFeePercent: 20))))
    }
    @Test func theCounterIsNeverAboveTheAsk() throws {
        #expect(try next([theirs(36_000)]).advice == .counter(.sale(SaleTerms(now: 36_000, later: 4_000, nextFeePercent: 20))))
    }
    @Test func aCounterKeepsALargerShareOfTheNextFeeTheClubOffered() throws {
        #expect(try next([theirs(8_000, fee: 30)]).advice == .counter(.sale(SaleTerms(now: 8_000, later: 1_600, nextFeePercent: 30))))
    }
    @Test func afterOneCounterIsAnsweredThereIsNoSecond() throws {
        #expect(try next([theirs(8_000), mine(8_000, later: 1_600, nil), theirs(8_500)]).advice == .acceptOrLeave)
    }
    @Test func anOpeningProposalIsNotACounter() throws {
        #expect(try next([mine(40_000, nil), theirs(8_000)]).advice == .counter(.sale(SaleTerms(now: 8_000, later: 1_600, nextFeePercent: 20))))
    }
    @Test func aCounterNeedsNoBudgetButAStepDownDoes() throws {
        let bare = ClubFigures(name: "Barnet", transferBudget: nil, wageBudgetPerWeek: nil, wagesSpentPerWeek: nil, highestWagePerWeek: nil)
        #expect(try Offers.proposal(Self.subject(), kind: .sale, club: bare, rounds: [theirs(8_000)], parameters: Self.p).advice
                == .counter(.sale(SaleTerms(now: 8_000, later: 1_600, nextFeePercent: 20))))
        #expect(throws: OfferError.missing(.transferBudget, club: "Barnet")) {
            try Offers.proposal(Self.subject(), kind: .sale, club: bare, rounds: [mine(40_000, .refused)], parameters: Self.p)
        }
    }
    @Test func whileHisProposalIsUnansweredTheAdviceIsToWait() throws {
        #expect(try next([mine(40_000, nil)]).advice == .awaitAnswer)
    }
    @Test func anAcceptedProposalIsAgreedAndNeedsNoMore() throws {
        #expect(try next([mine(40_000, .accepted)]).advice == .agreed)
        var bid = theirs(30_000); bid.answer = .accepted
        let s = try next([bid])
        #expect(s.advice == .agreed && s.notes.isEmpty)
    }
    @Test func aRefusalLowersTheNextProposalByATenthTwiceAndNoFurther() throws {
        let once = try next([mine(40_000, .refused)], budget: 50_000)
        #expect(once.advice == .propose(.sale(SaleTerms(now: 36_000, later: 0, nextFeePercent: 20)), split: nil))
        #expect(once.notes.first == .steppedDown)
        let twice = try next([mine(40_000, .refused), mine(36_000, .noReply)], budget: 50_000)
        #expect(twice.advice == .propose(.sale(SaleTerms(now: 32_000, later: 0, nextFeePercent: 20)), split: nil))
        #expect(try next([mine(40_000, .refused), mine(36_000, .noReply), mine(32_000, .refused)], budget: 50_000).advice
                == .nothingLower(.clubTurnedDownThree))
    }
    @Test func aSteppedDownProposalIsSplitAsAFirstOneIs() throws {
        let s = try next([mine(40_000, .refused)], budget: 20_000)
        #expect(s.advice == .propose(.sale(SaleTerms(now: 20_000, later: 16_000, nextFeePercent: 20)),
                                     split: SaleSplit(instalments: 7_000, afterAppearances: 9_000)))
        #expect(s.notes == [.steppedDown, .restAskedLater(budget: 20_000)])
    }
    @Test func aStepDownIsTakenFromWhatHeRecordedAndNeverUnderTheirBestBid() throws {
        #expect(try next([mine(30_000, .refused)], budget: 50_000).advice
                == .propose(.sale(SaleTerms(now: 27_000, later: 0, nextFeePercent: 20)), split: nil))
        #expect(try next([theirs(35_000), mine(38_000, .refused)], budget: 50_000).advice
                == .propose(.sale(SaleTerms(now: 35_000, later: 0, nextFeePercent: 20)), split: nil))
    }
    @Test func aStepDownIsCappedAtThePresentAsk() throws {
        let s = try Offers.proposal(Self.subject(value: 20_000), kind: .sale, club: Self.club(50_000), rounds: [mine(40_000, .refused)], parameters: Self.p)
        #expect(s.advice == .propose(.sale(SaleTerms(now: 20_000, later: 0, nextFeePercent: 20)), split: nil))
    }
    @Test func aClubsRoundEndsARunOfRefusals() throws {
        let s = try next([mine(40_000, .refused), mine(36_000, .refused), theirs(5_000), mine(6_000, .refused)], budget: 50_000)
        #expect(s.advice == .propose(.sale(SaleTerms(now: 5_400, later: 0, nextFeePercent: 20)), split: nil))
    }
    @Test func aPlayerOfNoValueStaysAtNothingWhenSteppedDown() throws {
        let s = try Offers.proposal(Self.subject(value: 0), kind: .sale, club: Self.club(0), rounds: [mine(0, .refused)], parameters: Self.p)
        #expect(s.advice == .propose(.sale(SaleTerms(now: 0, later: 0, nextFeePercent: 20)), split: nil))
        #expect(s.notes == [.valueIsZero])                                              // nothing was lowered
        let asked = try Offers.ask(Self.subject(value: 0), kind: .sale,
                                   earlier: [OfferAsk(id: UUID(), player: PlayerID(key: "fmrte:1"), playerName: "A", kind: .sale,
                                                      day: Self.day, terms: .sale(SaleTerms(now: 0, later: 0, nextFeePercent: 20)),
                                                      value: 0, wagePerWeek: 450, noBidCame: true)],
                                   parameters: Self.p)
        #expect(asked.notes == [.valueIsZero, .doNotList, .noInterestBids])
    }
    @Test func aStepDownThatLowersNothingSaysNothingOfLowering() throws {
        // The floor at the club's best bid gives the total he last recorded: nothing was lowered.
        let s = try next([theirs(35_000), mine(35_000, .refused)], budget: 50_000)
        #expect(s.advice == .propose(.sale(SaleTerms(now: 35_000, later: 0, nextFeePercent: 20)), split: nil))
        #expect(!s.notes.contains(.steppedDown))
        // An ask capped at a present ask no lower than the one stepped from: 10% under 20,000 is lower, so it says so.
        let lowered = try ask([asked(20_000, noBid: true)])
        #expect(lowered.advice == .propose(.sale(SaleTerms(now: 18_000, later: 0, nextFeePercent: 20)), split: nil))
        #expect(lowered.notes.first == .steppedDown)
    }
    @Test func moneyNowIsTheWholeTotalWhenTheClubCanPayIt() throws {
        // Bid 8,250, counter 9,900 refused, 8,900 refused: lowered to 8,000 and floored at the bid, 8,250, which the
        // budget covers, so all of it is asked now and nothing later.
        let s = try next([theirs(8_250), mine(8_250, later: 1_650, .refused), mine(8_900, .refused)])
        #expect(s.advice == .propose(.sale(SaleTerms(now: 8_250, later: 0, nextFeePercent: 20)), split: nil))
        #expect(!s.notes.contains { if case .restAskedLater = $0 { true } else { false } })
    }
    @Test func theRestAskedLaterCarriesTheBudgetAsEntered() throws {
        let s = try Offers.proposal(Self.subject(), kind: .sale, club: Self.club(35_400), rounds: [], parameters: Self.p)
        #expect(s.advice == .propose(.sale(SaleTerms(now: 35_000, later: 5_000, nextFeePercent: 20)),
                                     split: SaleSplit(instalments: 2_200, afterAppearances: 2_800)))
        #expect(s.notes == [.restAskedLater(budget: 35_400)])
    }
    @Test func aStepDownIsNeverUnderTheClubsBestBidEvenAboveThePresentAsk() throws {
        // His value was retyped down to 20,000 after Barnet bid 25,000: the step down proposes the bid's total.
        let s = try Offers.proposal(Self.subject(value: 20_000), kind: .sale, club: Self.club(50_000),
                                    rounds: [theirs(25_000), mine(38_000, .refused)], parameters: Self.p)
        #expect(s.advice == .propose(.sale(SaleTerms(now: 25_000, later: 0, nextFeePercent: 20)), split: nil))
        #expect(s.notes == [.steppedDown])
    }
    @Test func aCounterOnAValueAboveNothingSaysNothingOfZeroAndIsCappedAtTheAsk() throws {
        let s = try next([theirs(36_000)])                                              // 1.2 × 36,000 is over 40,000
        #expect(s.advice == .counter(.sale(SaleTerms(now: 36_000, later: 4_000, nextFeePercent: 20))))
        #expect(!s.notes.contains(.valueIsZero))
    }
    @Test func anAskThatDrewNoBidIsLoweredTwiceThenInterestComesFirst() throws {
        #expect(try ask([asked(40_000, noBid: true)]).advice == .propose(.sale(SaleTerms(now: 36_000, later: 0, nextFeePercent: 20)), split: nil))
        #expect(try ask([asked(40_000, noBid: true)]).notes == [.steppedDown, .doNotList, .noInterestBids])
        #expect(try ask([asked(40_000, noBid: true), asked(36_000, noBid: true)]).advice == .propose(.sale(SaleTerms(now: 32_000, later: 0, nextFeePercent: 20)), split: nil))
        #expect(try ask([asked(40_000, noBid: true), asked(36_000, noBid: true), asked(32_000, noBid: true)]).advice == .nothingLower(.noBidThree))
    }
    @Test func anAskStillWaitingLowersNothing() throws {
        #expect(try ask([asked(40_000, noBid: true), asked(36_000, noBid: false)]).advice == .propose(.sale(SaleTerms(now: 40_000, later: 0, nextFeePercent: 20)), split: nil))
    }
    @Test func aBidOfNothingForAPlayerOfNoValueIsAccepted() throws {
        #expect(try Offers.proposal(Self.subject(value: 0), kind: .sale, club: Self.club(0), rounds: [theirs(0)], parameters: Self.p).advice == .accept)
    }
    @Test func aRoundOfLoanTermsInASaleIsRefused() {
        let loan = OfferRound(day: Self.day, by: .club, terms: .loan(LoanTerms(wagePercent: 50, feePerMonth: 0, playingTime: nil, recall: true, futureFee: nil)),
                              value: 40_000, wagePerWeek: 450, answer: nil)
        #expect(throws: OfferError.wrongKind) { try next([loan]) }
        let loanAsk = OfferAsk(id: UUID(), player: PlayerID(key: "fmrte:1"), playerName: "A", kind: .sale, day: Self.day,
                               terms: .loan(LoanTerms(wagePercent: 50, feePerMonth: 0, playingTime: nil, recall: true, futureFee: nil)),
                               value: 40_000, wagePerWeek: 450, noBidCame: true)
        #expect(throws: OfferError.wrongKind) { try ask([loanAsk]) }
    }
    @Test func anAskStillWaitingLowersNothingAndFollowsThePresentValue() throws {
        let same = SaleTerms(now: 40_000, later: 0, nextFeePercent: 20)
        let a = try Offers.ask(Self.subject(), kind: .sale, earlier: [asked(25_000, noBid: false)], parameters: Self.p)
        #expect(a.advice == .propose(.sale(same), split: nil) && a.notes == [.doNotList, .noInterestBids])
        let b = try Offers.ask(Self.subject(), kind: .sale, earlier: [asked(40_000, noBid: true), asked(25_000, noBid: false)], parameters: Self.p)
        #expect(b.advice == .propose(.sale(same), split: nil) && b.notes == [.doNotList, .noInterestBids])
        let c = try Offers.ask(Self.subject(value: 20_000), kind: .sale, earlier: [asked(40_000, noBid: false)], parameters: Self.p)
        #expect(c.advice == .propose(.sale(SaleTerms(now: 20_000, later: 0, nextFeePercent: 20)), split: nil))
    }
    @Test func aLoanAskAnywhereInTheListIsWrongKindForASale() {
        let loan = OfferAsk(id: UUID(), player: PlayerID(key: "fmrte:1"), playerName: "A", kind: .loan, day: Self.day,
                            terms: .loan(LoanTerms(wagePercent: 50, feePerMonth: 0, playingTime: nil, recall: true, futureFee: nil)),
                            value: 1, wagePerWeek: 1, noBidCame: false)
        #expect(throws: OfferError.wrongKind) {
            try Offers.ask(Self.subject(), kind: .sale, earlier: [loan, asked(25_000, noBid: false)], parameters: Self.p)
        }
    }
}
