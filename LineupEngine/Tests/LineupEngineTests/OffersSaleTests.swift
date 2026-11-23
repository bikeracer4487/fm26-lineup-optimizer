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
        #expect(s.notes == [.restAskedLater(now: 35_000)])
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
}
