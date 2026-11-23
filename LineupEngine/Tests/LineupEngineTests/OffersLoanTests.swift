import Foundation
import Testing
@testable import LineupEngine

@Suite struct OffersLoanTests {
    static let p = EngineParameters.fm27
    static func subject(value: Int = 50_000, wage: Double = 500, purpose: LoanPurpose = .development, goalkeeper: Bool = false) -> OfferSubject {
        OfferSubject(value: value, wagePerWeek: wage, isGoalkeeper: goalkeeper, purpose: purpose)
    }
    static func club(wageBudget: Double? = 5_000, spent: Double? = 3_000, highest: Double? = nil) -> ClubFigures {
        ClubFigures(name: "Barnet", transferBudget: nil, wageBudgetPerWeek: wageBudget, wagesSpentPerWeek: spent, highestWagePerWeek: highest)
    }
    static let day = Day(iso: "2026-11-22")!
    static func round(_ by: RoundBy, _ terms: LoanTerms, _ answer: RoundAnswer?) -> OfferRound {
        OfferRound(day: day, by: by, terms: .loan(terms), value: 50_000, wagePerWeek: 500, answer: answer)
    }
    static func mine(_ percent: Int, fee: Int = 0, _ answer: RoundAnswer?) -> OfferRound {
        round(.owner, LoanTerms(wagePercent: percent, feePerMonth: fee, playingTime: .startingPlace, recall: true, futureFee: nil), answer)
    }
    static func theirs(_ percent: Int, fee: Int = 0, _ time: PlayingTime) -> OfferRound {
        round(.club, LoanTerms(wagePercent: percent, feePerMonth: fee, playingTime: time, recall: true, futureFee: nil), nil)
    }
    static func terms(_ advice: OfferAdvice) -> LoanTerms? {
        switch advice {
        case .propose(.loan(let t), _), .counter(.loan(let t)): t
        default: nil
        }
    }
    func terms(_ advice: OfferAdvice) -> LoanTerms? { Self.terms(advice) }
    func next(_ purpose: LoanPurpose, _ rounds: [OfferRound], figures: ClubFigures? = Self.club(), value: Int = 50_000) throws -> OfferSuggestion {
        try Offers.proposal(Self.subject(value: value, purpose: purpose), kind: .loan, club: figures ?? Self.club(wageBudget: nil, spent: nil), rounds: rounds, parameters: Self.p)
    }
    typealias S = OffersLoanTests

    @Test func theShareIsWhatTheValueRuleBearsRoundedDownToAStep() throws {
        let s = try Offers.ask(Self.subject(), kind: .loan, earlier: [], parameters: Self.p)
        #expect(terms(s.advice) == LoanTerms(wagePercent: 50, feePerMonth: 0, playingTime: .startingPlace, recall: true, futureFee: nil))
        #expect(s.notes == [.shareLimitedBy(.value), .clubsOpenLow])
    }
    @Test func theClubsWageLeftCapsTheShare() throws {
        let s = try Offers.proposal(Self.subject(), kind: .loan, club: Self.club(wageBudget: 5_000, spent: 4_800), rounds: [], parameters: Self.p)
        #expect(terms(s.advice)?.wagePercent == 40 && s.notes == [.shareLimitedBy(.wageLeft(200))])
    }
    @Test func theWageLeftChangesNothingWhenItIsAmple() throws {
        let s = try Offers.proposal(Self.subject(), kind: .loan, club: Self.club(wageBudget: 5_000, spent: 3_000), rounds: [], parameters: Self.p)
        #expect(terms(s.advice)?.wagePercent == 50 && s.notes == [.shareLimitedBy(.value)])
    }
    @Test func theHighestWageCapsTheShareWhenEnteredAndIsIgnoredWhenNot() throws {
        let capped = try Offers.proposal(Self.subject(), kind: .loan, club: Self.club(highest: 150), rounds: [], parameters: Self.p)
        #expect(terms(capped.advice)?.wagePercent == 30 && capped.notes == [.shareLimitedBy(.highestWage(150))])
        let none = try Offers.proposal(Self.subject(), kind: .loan, club: Self.club(highest: nil), rounds: [], parameters: Self.p)
        #expect(terms(none.advice)?.wagePercent == 50)
    }
    @Test func aShareOnAStepIsNotRoundedBelowIt() throws {
        let s = try Offers.proposal(Self.subject(), kind: .loan, club: Self.club(highest: 150), rounds: [], parameters: Self.p)
        #expect(terms(s.advice)?.wagePercent == 30)   // 150 / 500 is 29.999… in binary
    }
    @Test func aTieBetweenLimitsNamesTheValueFirstThenTheWageLeft() throws {
        // value limit 260.4 / 500; wage left 260.4 is not a whole figure, so tie the two club limits instead
        let s = try Offers.proposal(Self.subject(), kind: .loan, club: Self.club(wageBudget: 5_000, spent: 4_850, highest: 150), rounds: [], parameters: Self.p)
        #expect(s.notes == [.shareLimitedBy(.wageLeft(150))])
    }
    @Test func aFeeIsAskedOnlyAtTheWholeWageAndIsTheRest() throws {
        let s = try Offers.ask(Self.subject(value: 120_000), kind: .loan, earlier: [], parameters: Self.p)
        #expect(terms(s.advice) == LoanTerms(wagePercent: 100, feePerMonth: 500, playingTime: .startingPlace, recall: true, futureFee: nil))
        #expect(s.notes == [.shareLimitedBy(.all), .recallWithFee, .clubsOpenLow])
    }
    @Test func theClubsWageLeftCapsTheFeeToo() throws {
        let some = try Offers.proposal(Self.subject(value: 120_000), kind: .loan, club: Self.club(wageBudget: 5_000, spent: 4_450), rounds: [], parameters: Self.p)
        #expect(terms(some.advice)?.wagePercent == 100 && terms(some.advice)?.feePerMonth == 200)
        let short = try Offers.proposal(Self.subject(value: 120_000), kind: .loan, club: Self.club(wageBudget: 5_000, spent: 4_600), rounds: [], parameters: Self.p)
        #expect(terms(short.advice)?.wagePercent == 80 && terms(short.advice)?.feePerMonth == 0)
    }
    @Test func noFeeIsAskedBelowTheWholeWage() throws {
        let s = try Offers.ask(Self.subject(), kind: .loan, earlier: [], parameters: Self.p)
        #expect(terms(s.advice)?.feePerMonth == 0 && !s.notes.contains(.recallWithFee))
    }
    @Test func aLoanToMoveAWageAsksNoPlayingTimeAndMayOfferAFeeToBuy() throws {
        let s = try Offers.ask(Self.subject(purpose: .wage), kind: .loan, earlier: [], parameters: Self.p)
        #expect(terms(s.advice) == LoanTerms(wagePercent: 50, feePerMonth: 0, playingTime: nil, recall: true, futureFee: nil))
        #expect(s.notes == [.shareLimitedBy(.value), .optionalFutureFee(50_000), .clubsOpenLow])
    }
    @Test func aPlayerOfNoValueIsOfferedForNoneOfHisWage() throws {
        let s = try Offers.ask(Self.subject(value: 0, purpose: .wage), kind: .loan, earlier: [], parameters: Self.p)
        #expect(terms(s.advice)?.wagePercent == 0 && terms(s.advice)?.feePerMonth == 0)
        #expect(s.notes.first == .valueIsZero && !s.notes.contains(.optionalFutureFee(0)))
        let other = try Offers.ask(Self.subject(), kind: .loan, earlier: [], parameters: Self.p)
        #expect(!other.notes.contains(.valueIsZero))
    }
    @Test func aPlayerWithNoWageHasNoShareAndTheFeeRuleStillApplies() throws {
        let s = try Offers.ask(Self.subject(value: 19_200, wage: 0), kind: .loan, earlier: [], parameters: Self.p)
        #expect(terms(s.advice)?.wagePercent == 0 && terms(s.advice)?.feePerMonth == 400)
        #expect(s.notes == [.recallWithFee, .clubsOpenLow])
    }
    @Test func aNegativeValueOrWageIsRefused() {
        #expect(throws: OfferError.negative(.value)) { try Offers.ask(Self.subject(value: -1), kind: .loan, earlier: [], parameters: Self.p) }
        #expect(throws: OfferError.negative(.wage)) { try Offers.ask(Self.subject(wage: -1), kind: .loan, earlier: [], parameters: Self.p) }
    }
    @Test func aLoanToAClubNeedsItsWageBudgetAndWagesSpent() {
        #expect(throws: OfferError.missing(.wageBudget, club: "Barnet")) {
            try Offers.proposal(Self.subject(), kind: .loan, club: Self.club(wageBudget: nil, spent: nil), rounds: [], parameters: Self.p)
        }
        #expect(throws: OfferError.missing(.wagesSpent, club: "Barnet")) {
            try Offers.proposal(Self.subject(), kind: .loan, club: Self.club(wageBudget: 5_000, spent: nil), rounds: [], parameters: Self.p)
        }
    }
    @Test func forDevelopmentAStartingPlaceIsAcceptedWhateverTheShare() throws {
        #expect(try next(.development, [Self.theirs(0, .startingPlace)]).advice == .accept)
    }
    @Test func forDevelopmentLessIsSentBackWithTheirShareAndAStartingPlace() throws {
        #expect(try next(.development, [Self.theirs(20, .less)]).advice
                == .counter(.loan(LoanTerms(wagePercent: 20, feePerMonth: 0, playingTime: .startingPlace, recall: true, futureFee: nil))))
    }
    @Test func aDevelopmentAnswerNeedsNoWageFigures() throws {
        let blank = Self.club(wageBudget: nil, spent: nil)
        #expect(try next(.development, [Self.theirs(0, .startingPlace)], figures: blank).advice == .accept)
        #expect(throws: OfferError.missing(.wageBudget, club: "Barnet")) { try next(.wage, [Self.theirs(0, .less)], figures: blank) }
    }
    @Test func toMoveAWageTheirShareIsAcceptedAtTheSuggestionAndRaisedAStepBelowIt() throws {
        #expect(try next(.wage, [Self.theirs(50, .less)]).advice == .accept)
        #expect(try next(.wage, [Self.theirs(60, .less)]).advice == .accept)
        #expect(try next(.wage, [Self.theirs(20, .less)]).advice
                == .counter(.loan(LoanTerms(wagePercent: 30, feePerMonth: 0, playingTime: nil, recall: true, futureFee: nil))))
        #expect(try next(.wage, [Self.theirs(40, .less)]).advice
                == .counter(.loan(LoanTerms(wagePercent: 50, feePerMonth: 0, playingTime: nil, recall: true, futureFee: nil))))
        #expect(terms(try next(.wage, [Self.theirs(45, .less)]).advice)?.wagePercent == 50)
    }
    @Test func aLoanGetsOneCounterToo() throws {
        #expect(try next(.development, [Self.theirs(20, .less), Self.mine(20, nil), Self.theirs(30, .less)]).advice == .acceptOrLeave)
        #expect(try next(.wage, [Self.theirs(20, .less), Self.mine(30, nil), Self.theirs(30, .less)]).advice == .acceptOrLeave)
        #expect(try next(.development, [Self.theirs(20, .less), Self.mine(20, nil), Self.theirs(30, .startingPlace)]).advice == .accept)
    }
    @Test func theOwnersRoundWaitsForTheAnswerAndIsAcceptedWhenAccepted() throws {
        #expect(try next(.development, [Self.mine(50, nil)]).advice == .awaitAnswer)
        #expect(try next(.development, [Self.mine(50, .accepted)]).advice == .accept)
    }
    @Test func aRefusalDropsTheFeeFirstThenAStepOfTheShare() throws {
        let a = try next(.development, [Self.mine(100, fee: 500, .refused)], value: 120_000)
        #expect(terms(a.advice)?.wagePercent == 100 && terms(a.advice)?.feePerMonth == 0 && a.notes == [.steppedDown])
        let b = try next(.development, [Self.mine(100, fee: 500, .refused), Self.mine(100, .noReply)], value: 120_000)
        #expect(terms(b.advice)?.wagePercent == 90)
    }
    @Test func aStepDownIsNeverAboveThePresentSuggestion() throws {
        #expect(terms(try next(.development, [Self.mine(90, .refused)]).advice)?.wagePercent == 50)
        #expect(terms(try next(.development, [Self.mine(100, fee: 500, .refused)]).advice)?.feePerMonth == 0)
    }
    @Test func inADealTheShareGoesDownToNothingAndThenTheClubDoesNotWantHim() throws {
        #expect(terms(try next(.development, [Self.mine(10, .refused)]).advice)?.wagePercent == 0)
        #expect(try next(.development, [Self.mine(10, .refused), Self.mine(0, .refused)]).advice == .nothingLower(.clubDoesNotWantHim))
        #expect(try next(.development, [Self.mine(0, .noReply)]).advice == .nothingLower(.clubDoesNotWantHim))
        #expect(terms(try next(.development, [Self.mine(50, .refused), Self.mine(40, .refused), Self.mine(30, .noReply), Self.mine(20, .refused)]).advice)?.wagePercent == 10)
    }
    @Test func aLoanRoundMustBeALoan() {
        let sale = OfferRound(day: Self.day, by: .club, terms: .sale(SaleTerms(now: 1, later: 0, nextFeePercent: 0)), value: 1, wagePerWeek: 1, answer: nil)
        #expect(throws: OfferError.wrongKind) { try next(.development, [sale]) }
    }
    static func ask(_ percent: Int, fee: Int = 0, noBid: Bool) -> OfferAsk {
        OfferAsk(id: UUID(), player: PlayerID(key: "fmrte:1"), playerName: "A", kind: .loan, day: day,
                 terms: .loan(LoanTerms(wagePercent: percent, feePerMonth: fee, playingTime: .startingPlace, recall: true, futureFee: nil)),
                 value: 50_000, wagePerWeek: 500, noBidCame: noBid)
    }
    func asks(_ earlier: [OfferAsk]) throws -> OfferSuggestion {
        try Offers.ask(Self.subject(), kind: .loan, earlier: earlier, parameters: Self.p)
    }
    @Test func anAskThatDrewNoBidIsLoweredTwiceThenInterestComesFirst() throws {
        let one = try asks([Self.ask(50, noBid: true)])
        #expect(terms(one.advice)?.wagePercent == 40 && one.notes.first == .steppedDown)
        #expect(terms(try asks([Self.ask(50, noBid: true), Self.ask(40, noBid: true)]).advice)?.wagePercent == 30)
        #expect(try asks([Self.ask(50, noBid: true), Self.ask(40, noBid: true), Self.ask(30, noBid: true)]).advice == .nothingLower(.noBidThree))
    }
    @Test func anAskWithABidOrNoneYetIsRepeated() throws {
        let s = try asks([Self.ask(50, noBid: false)])
        #expect(terms(s.advice)?.wagePercent == 50 && !s.notes.contains(.steppedDown))
    }
    @Test func anAskOfNothingStaysAtNothingUntilTheRunIsTooLong() throws {
        let s = try asks([Self.ask(0, noBid: true)])
        #expect(terms(s.advice)?.wagePercent == 0 && terms(s.advice)?.feePerMonth == 0)
        #expect(try asks([Self.ask(0, noBid: true), Self.ask(0, noBid: true), Self.ask(0, noBid: true)]).advice == .nothingLower(.noBidThree))
    }
    @Test func anAskStepsDownByDroppingTheFeeFirst() throws {
        let s = try Offers.ask(Self.subject(value: 120_000), kind: .loan, earlier: [Self.ask(100, fee: 500, noBid: true)], parameters: Self.p)
        #expect(terms(s.advice)?.wagePercent == 100 && terms(s.advice)?.feePerMonth == 0)
    }
    @Test func aSaleAskIsStillRefusedAsALoan() {
        #expect(throws: OfferError.wrongKind) { try Offers.ask(Self.subject(), kind: .loan, earlier: [Self.saleAsk()], parameters: Self.p) }
    }
    static func saleAsk() -> OfferAsk {
        OfferAsk(id: UUID(), player: PlayerID(key: "fmrte:1"), playerName: "A", kind: .sale, day: day,
                 terms: .sale(SaleTerms(now: 1, later: 0, nextFeePercent: 0)), value: 1, wagePerWeek: 1, noBidCame: false)
    }
}
