import Foundation
import Testing
@testable import LineupEngine

@Suite struct OfferMeasuresTests {
    static let p = EngineParameters.fm27
    let p = OfferMeasuresTests.p
    static func d(_ n: Int) -> Day { Day(iso: "2026-11-01")!.adding(days: n - 1) }

    static func sale(_ total: Int) -> OfferTerms { .sale(SaleTerms(now: total, later: 0, nextFeePercent: 20)) }
    static func round(_ by: RoundBy, _ total: Int, value: Int = 10_000, _ answer: RoundAnswer? = nil, day: Day = d(21)) -> OfferRound {
        OfferRound(day: day, by: by, terms: sale(total), value: value, wagePerWeek: 450, answer: answer)
    }
    static func deal(_ rounds: [OfferRound]) -> OfferDeal { deal("a", rounds) }
    static func deal(_ player: String, kind: OfferKind = .sale, _ rounds: [OfferRound]) -> OfferDeal {
        OfferDeal(id: UUID(), player: PlayerID(key: player), playerName: player, kind: kind, club: "Barnet", figures: nil,
                  rounds: rounds, endedOn: nil)
    }
    /// A deal on a value of 10,000 with an owner's round at the turned-down ratio (refused), then a club's round at the paid ratio.
    static func saleDeal(_ player: String = "a", paid: Double? = nil, turnedDown: Double? = nil, day: Day = d(21)) -> OfferDeal {
        var rounds: [OfferRound] = []
        if let t = turnedDown { rounds.append(round(.owner, Int((t * 10_000).rounded()), .refused, day: day)) }
        if let r = paid { rounds.append(round(.club, Int((r * 10_000).rounded()), day: day)) }
        return deal(player, rounds)
    }
    static func loanTerms(_ ratio: Double) -> OfferTerms {
        .loan(LoanTerms(wagePercent: 0, feePerMonth: Int((ratio * 400_000).rounded()), playingTime: nil, recall: true, futureFee: nil))
    }
    static func loanDeal(_ player: String = "a", paid: Double? = nil, turnedDown: Double? = nil, day: Day = d(21)) -> OfferDeal {
        var rounds: [OfferRound] = []
        if let t = turnedDown {
            rounds.append(OfferRound(day: day, by: .owner, terms: loanTerms(t), value: 100_000, wagePerWeek: 500, answer: .refused))
        }
        if let r = paid {
            rounds.append(OfferRound(day: day, by: .club, terms: loanTerms(r), value: 100_000, wagePerWeek: 500, answer: nil))
        }
        return deal(player, kind: .loan, rounds)
    }
    static func ask(_ total: Int, day: Day, value: Int = 10_000) -> OfferAsk { ask("a", total, day: day, value: value) }
    static func ask(_ player: String, _ total: Int, day: Day, value: Int = 10_000) -> OfferAsk {
        OfferAsk(id: UUID(), player: PlayerID(key: player), playerName: player, kind: .sale, day: day, terms: sale(total),
                 value: value, wagePerWeek: 450, noBidCame: false)
    }
    func measure(_ deals: [OfferDeal], asks: [OfferAsk] = [], from: Day? = nil) -> OfferMeasures {
        Offers.measures(asks: asks, deals: deals, from: from, parameters: p)
    }

    @Test func nothingRecordedMeasuresNothing() {
        #expect(Offers.measures(asks: [], deals: [], from: nil, parameters: p) == .none)
    }
    @Test func fiveEachWayGiveALineMidwayBetweenTheMedians() {
        let deals = zip([0.10, 0.20, 0.22, 0.30, 0.40], [0.60, 0.70, 0.80, 0.90, 1.00]).map { Self.saleDeal(paid: $0, turnedDown: $1) }
        let m = Offers.measures(asks: [], deals: deals, from: nil, parameters: p)
        #expect(m.sale.paid == 5 && m.sale.turnedDown == 5 && m.sale.deals == 5 && m.sale.agreed == 0)
        #expect(abs(m.sale.medianPaid! - 0.22) < 1e-9 && abs(m.sale.medianTurnedDown! - 0.80) < 1e-9 && abs(m.sale.line! - 0.51) < 1e-9)
        #expect(m.sale.since == Self.d(21))
        #expect(m.loan == OfferMeasures.none.loan)
    }
    @Test func fourOneWayGiveNoLineButTheCountsAndMedians() {
        let paid = [0.1, 0.2, 0.3, 0.4, 0.5]
        let down: [Double?] = [0.8, 0.9, 1.0, 1.1, nil]
        let m = measure(zip(paid, down).map { Self.saleDeal(paid: $0, turnedDown: $1) })
        #expect(m.sale.paid == 5 && m.sale.turnedDown == 4)
        #expect(m.sale.line == nil && m.sale.medianTurnedDown != nil && m.sale.medianPaid != nil)
    }
    @Test func mediansTheWrongWayRoundGiveNoLine() {
        let m = measure(zip([0.6, 0.7, 0.8, 0.9, 1.0], [0.4, 0.5, 0.45, 0.35, 0.3]).map { Self.saleDeal(paid: $0, turnedDown: $1) })
        #expect(m.sale.line == nil)
        #expect(m.sale.medianPaid != nil && m.sale.medianTurnedDown != nil)
        #expect(m.sale.paid == 5 && m.sale.turnedDown == 5)
    }
    @Test func anEvenCountTakesTheMeanOfTheMiddleTwo() {
        let m = measure([0.1, 0.2, 0.3, 0.4, 0.5, 0.6].map { Self.saleDeal(paid: $0) })
        #expect(abs(m.sale.medianPaid! - 0.35) < 1e-9)
    }
    @Test func theSameRecordInAnyOrderGivesTheSameMeasures() {
        let deals = zip([0.10, 0.20, 0.22, 0.30, 0.40, 0.5], [0.60, 0.70, 0.80, 0.90, 1.00, 0.95]).enumerated().map {
            Self.saleDeal("p\($0.offset)", paid: $0.element.0, turnedDown: $0.element.1, day: Self.d(20 + $0.offset))
        }
        let asks = [Self.ask("p0", 10_000, day: Self.d(19)), Self.ask("p1", 9_000, day: Self.d(19)), Self.ask("p2", 8_000, day: Self.d(19))]
        let a = measure(deals, asks: asks)
        let b = measure(Array(deals.reversed()), asks: Array(asks.reversed()))
        let c = measure([deals[3], deals[0], deals[5], deals[1], deals[4], deals[2]], asks: [asks[1], asks[2], asks[0]])
        #expect(a == b && a == c)
    }
    @Test func aDealGivesAtMostOnePaidTheHighestAndOneTurnedDownTheLowest() {
        let rounds = [Self.round(.owner, 10_000, .refused), Self.round(.club, 2_000), Self.round(.owner, 5_000, .refused),
                      Self.round(.club, 3_000), Self.round(.owner, 3_500, .accepted)]
        let m = measure([Self.deal(rounds)])
        #expect(m.sale.paid == 1 && m.sale.turnedDown == 1 && m.sale.deals == 1 && m.sale.agreed == 1)
        #expect(abs(m.sale.medianPaid! - 0.35) < 1e-9 && abs(m.sale.medianTurnedDown! - 0.5) < 1e-9)
    }
    @Test func aRoundAnsweredByALowerOfferCountsAsTurnedDown() {
        let m = measure([Self.deal([Self.round(.owner, 9_000), Self.round(.club, 3_000)])])
        #expect(m.sale.turnedDown == 1 && abs(m.sale.medianTurnedDown! - 0.9) < 1e-9)
        #expect(m.sale.paid == 1 && abs(m.sale.medianPaid! - 0.3) < 1e-9)
    }
    @Test func aRoundAnsweredByAHigherOfferDoesNot() {
        let m = measure([Self.deal([Self.round(.owner, 2_000), Self.round(.club, 3_000)])])
        #expect(m.sale.turnedDown == 0 && m.sale.medianTurnedDown == nil)
    }
    @Test func noReplyCountsForNeither() {
        let m = measure([Self.deal([Self.round(.owner, 9_000, .noReply)])])
        #expect(m.sale.paid == 0 && m.sale.turnedDown == 0 && m.sale.deals == 1)
        let followed = measure([Self.deal([Self.round(.owner, 9_000, .noReply), Self.round(.club, 3_000)])])
        #expect(followed.sale.turnedDown == 0)
    }
    @Test func eachRatioUsesTheValueItsOwnRoundWasMadeOn() {
        let rounds = [Self.round(.club, 2_000, value: 10_000), Self.round(.owner, 3_000, value: 20_000, .refused)]
        let m = measure([Self.deal(rounds)])
        #expect(abs(m.sale.medianPaid! - 0.2) < 1e-9 && abs(m.sale.medianTurnedDown! - 0.15) < 1e-9)
    }
    @Test func aRoundOnAValueOfNothingCountsForNothing() {
        let rounds = [Self.round(.owner, 3_000, value: 0, .refused), Self.round(.club, 1_000, value: 0)]
        let m = measure([Self.deal(rounds)], asks: [Self.ask(5_000, day: Self.d(20), value: 0)])
        #expect(m.sale.paid == 0 && m.sale.turnedDown == 0 && m.sale.deals == 1)
        #expect(m.sale.line == nil)
    }
    @Test func anAskIsTurnedDownByALaterLowerFirstBidForThatPlayer() {
        let ask = Self.ask("a", 10_000, day: Self.d(20))
        let low = Self.round(.club, 2_000, day: Self.d(21))
        let m = measure([Self.deal("a", [low])], asks: [ask])
        #expect(m.sale.turnedDown == 1 && abs(m.sale.medianTurnedDown! - 1.0) < 1e-9)
        #expect(m.sale.deals == 1)
        // another player's bid
        #expect(measure([Self.deal("b", [low])], asks: [ask]).sale.turnedDown == 0)
        // dated before the ask
        #expect(measure([Self.deal("a", [Self.round(.club, 2_000, day: Self.d(19))])], asks: [ask]).sale.turnedDown == 0)
        // after his next ask
        let later = Self.ask("a", 9_000, day: Self.d(22))
        let after = measure([Self.deal("a", [Self.round(.club, 2_000, day: Self.d(23))])], asks: [ask, later])
        #expect(after.sale.turnedDown == 1 && abs(after.sale.medianTurnedDown! - 0.9) < 1e-9)
        // a deal whose first round is the owner's
        #expect(measure([Self.deal("a", [Self.round(.owner, 5_000, .noReply, day: Self.d(21)), low])], asks: [ask]).sale.turnedDown == 0)
        // a higher first bid
        #expect(measure([Self.deal("a", [Self.round(.club, 12_000)])], asks: [ask]).sale.turnedDown == 0)
        // a loan deal for the same player
        #expect(measure([Self.loanDeal("a", paid: 0.001)], asks: [ask]).sale.turnedDown == 0)
    }
    @Test func roundsBeforeTheDayToMeasureFromAreLeftOut() {
        let m = measure([Self.saleDeal(paid: 0.3, turnedDown: 0.9, day: Self.d(20))], asks: [Self.ask(10_000, day: Self.d(19))], from: Self.d(21))
        #expect(m.sale.deals == 0 && m.sale.paid == 0 && m.sale.turnedDown == 0 && m.sale.since == nil)
        #expect(m.measuredFrom == Self.d(21))
        let kept = measure([Self.saleDeal(paid: 0.3, turnedDown: 0.9, day: Self.d(21))], from: Self.d(21))
        #expect(kept.sale.deals == 1 && kept.sale.paid == 1 && kept.sale.turnedDown == 1)
        #expect(measure([Self.saleDeal(paid: 0.3)]).measuredFrom == nil)
    }
    @Test func aLoansRatioIsWhatTheBorrowerBearsAWeekOverHisValue() {
        #expect(OfferTerms.loan(LoanTerms(wagePercent: 50, feePerMonth: 400, playingTime: nil, recall: true, futureFee: nil))
            .ratio(value: 100_000, wagePerWeek: 500, rules: p.offerRules.value) == 0.0035)
        #expect(OfferTerms.sale(SaleTerms(now: 3_000, later: 1_000, nextFeePercent: 20)).ratio(value: 10_000, wagePerWeek: 0, rules: p.offerRules.value) == 0.4)
        #expect(OfferTerms.sale(SaleTerms(now: 3_000, later: 1_000, nextFeePercent: 20)).ratio(value: 0, wagePerWeek: 0, rules: p.offerRules.value) == nil)
    }
    @Test func loansAreMeasuredApartFromSales() {
        let deals = zip([0.001, 0.002, 0.003, 0.004, 0.005], [0.01, 0.02, 0.03, 0.04, 0.05]).map { Self.loanDeal(paid: $0, turnedDown: $1) }
        let m = measure(deals)
        #expect(m.loan.paid == 5 && m.loan.turnedDown == 5 && abs(m.loan.line! - (0.003 + 0.03) / 2) < 1e-9)
        #expect(m.sale == OfferMeasures.none.sale)
    }
    static func counterDeal(_ first: Int, _ rest: [OfferRound], player: String = "a") -> OfferDeal {
        Self.deal(player, [Self.round(.club, first)] + rest)
    }
    func threeCountered() -> [OfferDeal] {
        [Self.counterDeal(10_000, [Self.round(.owner, 12_000, .accepted)], player: "a"),
         Self.counterDeal(10_000, [Self.round(.owner, 11_000, .accepted)], player: "b"),
         Self.counterDeal(10_000, [Self.round(.owner, 15_000, .refused), Self.round(.club, 13_000, .accepted)], player: "c")]
    }
    @Test func theCounterStepIsTheMedianOverAgreedSalesHeCountered() {
        let m = measure(threeCountered())
        #expect(m.counterDeals == 3)
        #expect(abs(m.counterStep! - 1.2) < 1e-9)
    }
    @Test func aBidAcceptedOutrightIsNoCounter() {
        let deals = ["a", "b", "c"].map { Self.counterDeal(10_000, [], player: $0) }
        let accepted = deals.map { d -> OfferDeal in var d = d; d.rounds[0].answer = .accepted; return d }
        let m = measure(accepted)
        #expect(m.counterDeals == 0 && m.counterStep == nil)
        // and they do not switch off three counters
        #expect(measure(threeCountered() + accepted).counterStep != nil)
    }
    @Test func twoCounteredSalesAreTooFew() {
        let m = measure(Array(threeCountered().prefix(2)))
        #expect(m.counterDeals == 2 && m.counterStep == nil)
    }
    @Test func aCounterThatWasNeverAcceptedOrAFirstBidOfNothingIsLeftOut() {
        let unaccepted = Self.counterDeal(10_000, [Self.round(.owner, 12_000, .refused)], player: "x")
        let zero = Self.counterDeal(0, [Self.round(.owner, 12_000, .accepted)], player: "y")
        let m = measure(threeCountered() + [unaccepted, zero])
        #expect(m.counterDeals == 3)
    }
    @Test func aMeasuredLineReplacesTheEstimateAndSaysSo() throws {
        var m = OfferMeasures.none; m.sale.line = 0.5
        let s = try Offers.ask(OffersSaleTests.subject(), kind: .sale, earlier: [], measures: m, parameters: p)
        #expect(s.advice == .propose(.sale(SaleTerms(now: 20_000, later: 0, nextFeePercent: 20)), split: nil))
        #expect(s.notes.last == .measuredLine(0.5))
        let to = try Offers.proposal(OffersSaleTests.subject(), kind: .sale, club: OffersSaleTests.club(50_000), rounds: [], measures: m, parameters: p)
        #expect(to.advice == .propose(.sale(SaleTerms(now: 20_000, later: 0, nextFeePercent: 20)), split: nil))
        #expect(to.notes == [.measuredLine(0.5)])
    }
    @Test func noMeasureAddsNoNote() throws {
        let s = try Offers.ask(OffersSaleTests.subject(), kind: .sale, earlier: [], measures: .none, parameters: p)
        #expect(!s.notes.contains(.measuredLine(0.5)) && s.notes == [.doNotList, .noInterestBids])
        var m = OfferMeasures.none; m.loan.line = 0.01                 // a loan's line says nothing of a sale
        let sale = try Offers.ask(OffersSaleTests.subject(), kind: .sale, earlier: [], measures: m, parameters: p)
        #expect(sale.notes == [.doNotList, .noInterestBids])
    }
    @Test func aMeasuredLoanLineReplacesTheRule() throws {
        var m = OfferMeasures.none; m.loan.line = 1.0 / 96
        let s = try Offers.ask(OffersLoanTests.subject(value: 50_000, wage: 500), kind: .loan, earlier: [], measures: m, parameters: p)
        guard case .propose(.loan(let t), _) = s.advice else { Issue.record("not a proposal"); return }
        #expect(t.wagePercent == 100)
        #expect(s.notes.last == .measuredLine(1.0 / 96))
        // without it the rule's own line gives another share
        let plain = try Offers.ask(OffersLoanTests.subject(value: 50_000, wage: 500), kind: .loan, earlier: [], parameters: p)
        #expect(plain.advice != s.advice)
        #expect(!plain.notes.contains(.measuredLine(1.0 / 96)))
    }
    @Test func aMeasuredCounterStepReplacesTheEstimate() throws {
        var m = OfferMeasures.none; m.counterStep = 1.5
        let s = try Offers.proposal(OffersSaleTests.subject(), kind: .sale, club: OffersSaleTests.club(35_000),
                                    rounds: [Self.round(.club, 8_000, value: 40_000)], measures: m, parameters: p)
        #expect(s.advice == .counter(.sale(SaleTerms(now: 8_000, later: 4_000, nextFeePercent: 20))))
        #expect(s.notes.last == .measuredCounterStep(1.5))
    }
    @Test func aMeasuredCounterStepOfOneOrLessMeansAcceptOrLeave() throws {
        var m = OfferMeasures.none; m.counterStep = 1.0
        let s = try Offers.proposal(OffersSaleTests.subject(), kind: .sale, club: OffersSaleTests.club(35_000),
                                    rounds: [Self.round(.club, 8_000, value: 40_000)], measures: m, parameters: p)
        #expect(s.advice == .acceptOrLeave)
        #expect(!s.notes.contains(.measuredCounterStep(1.0)))
    }
    @Test func bothMeasuresAreNotedInOrderOnACounter() throws {
        var m = OfferMeasures.none; m.counterStep = 1.5; m.sale.line = 0.5
        let s = try Offers.proposal(OffersSaleTests.subject(), kind: .sale, club: OffersSaleTests.club(35_000),
                                    rounds: [Self.round(.club, 8_000, value: 40_000)], measures: m, parameters: p)
        #expect(s.advice == .counter(.sale(SaleTerms(now: 8_000, later: 4_000, nextFeePercent: 20))))
        #expect(Array(s.notes.suffix(2)) == [.measuredLine(0.5), .measuredCounterStep(1.5)])
    }
    @Test func acceptingABidAddsNoMeasureNote() throws {
        var m = OfferMeasures.none; m.sale.line = 0.5; m.counterStep = 1.5
        let s = try Offers.proposal(OffersSaleTests.subject(), kind: .sale, club: OffersSaleTests.club(35_000),
                                    rounds: [Self.round(.club, 25_000, value: 40_000)], measures: m, parameters: p)
        #expect(s.advice == .accept && s.notes.isEmpty)
    }
}
