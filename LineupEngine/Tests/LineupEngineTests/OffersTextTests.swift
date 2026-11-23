import Foundation
import Testing
@testable import LineupEngine

@Suite struct OffersTextTests {
    static let p = EngineParameters.fm27
    static let rules = p.offerRules.value
    static let money = MoneyStyle(symbol: "£", period: .weekly)
    static let monthly = MoneyStyle(symbol: "£", period: .monthly)
    static let day = Day(year: 2026, month: 11, day: 21)!

    static func subject(value: Int = 40_000, wage: Double = 450, purpose: LoanPurpose = .development, goalkeeper: Bool = false) -> OfferSubject {
        OfferSubject(value: value, wagePerWeek: wage, isGoalkeeper: goalkeeper, purpose: purpose)
    }
    static func club(budget: Int? = 50_000, wageBudget: Double? = nil, spent: Double? = nil, highest: Double? = nil) -> ClubFigures {
        ClubFigures(name: "Barnet", transferBudget: budget, wageBudgetPerWeek: wageBudget, wagesSpentPerWeek: spent, highestWagePerWeek: highest)
    }
    static func lines(_ s: OfferSuggestion, kind: OfferKind, subject: OfferSubject, club: String? = nil, style: MoneyStyle = money) -> [String] {
        AdvisorText.offerLines(s, kind: kind, subject: subject, club: club, money: style, rules: rules)
    }
    static func saleRound(_ by: RoundBy, now: Int, later: Int = 0, fee: Int = 0, _ answer: RoundAnswer?, value: Int = 40_000) -> OfferRound {
        OfferRound(day: day, by: by, terms: .sale(SaleTerms(now: now, later: later, nextFeePercent: fee)), value: value, wagePerWeek: 450, answer: answer)
    }
    static func loanRound(_ by: RoundBy, _ percent: Int, fee: Int = 0, time: PlayingTime?, _ answer: RoundAnswer?) -> OfferRound {
        OfferRound(day: day, by: by, terms: .loan(LoanTerms(wagePercent: percent, feePerMonth: fee, playingTime: time, recall: true, futureFee: nil)),
                   value: 50_000, wagePerWeek: 500, answer: answer)
    }
    static func ask(_ subject: OfferSubject, _ kind: OfferKind, earlier: [OfferAsk] = [], measures: OfferMeasures = .none) throws -> OfferSuggestion {
        try Offers.ask(subject, kind: kind, earlier: earlier, measures: measures, parameters: p)
    }
    static func proposal(_ subject: OfferSubject, _ kind: OfferKind, club: ClubFigures, rounds: [OfferRound] = [], measures: OfferMeasures = .none) throws -> OfferSuggestion {
        try Offers.proposal(subject, kind: kind, club: club, rounds: rounds, measures: measures, parameters: p)
    }
    static func noBid(_ terms: SaleTerms) -> OfferAsk {
        OfferAsk(id: UUID(), player: PlayerID(key: "x"), playerName: "X", kind: .sale, day: day, terms: .sale(terms), value: 40_000, wagePerWeek: 450, noBidCame: true)
    }
    static func reading(deals: Int = 0, asks: Int = 0, agreed: Int = 0, paid: Int = 0, down: Int = 0, mp: Double? = nil, md: Double? = nil, line: Double? = nil, since: Day? = nil) -> OfferLineReading {
        OfferLineReading(deals: deals, asks: asks, agreed: agreed, paid: paid, turnedDown: down, medianPaid: mp, medianTurnedDown: md, line: line, since: since)
    }
    static func measures(sale: OfferLineReading = reading(), loan: OfferLineReading = reading(), counterDeals: Int = 0, step: Double? = nil) -> OfferMeasures {
        OfferMeasures(sale: sale, loan: loan, counterDeals: counterDeals, counterStep: step, measuredFrom: nil)
    }

    @Test func theFixedLines() {
        #expect(AdvisorText.offersIntro == "Terms to propose for the players you have marked to sell or to loan out. No test in any version of the game shows what a club accepts: every figure here is a place to start, and says what it rests on.")
        #expect(AdvisorText.offersNobodyMarked == "Nobody is marked to sell or to loan out. Mark a player on Player Removal to get terms for him.")
        #expect(AdvisorText.valueHint == "the lower figure of the value on his profile")
        #expect(AdvisorText.valueCaution == "Read it before you transfer-list him: once he is listed with an asking price, the game stores that price as his value (carried over from FM26, four players).")
        #expect(AdvisorText.startingPlaceMeans == "A starting place is Regular Starter or anything the game ranks above it, and First-Choice Goalkeeper for a goalkeeper.")
        #expect(AdvisorText.nothingRecorded == "Nothing is recorded yet. Record what you propose and what clubs answer, and this part will say what your own offers show.")
        #expect(AdvisorText.measureOffersAgainQuestion == "Measure again from today? Offers recorded before today stay in the record and are left out of what is measured. This cannot be undone in the app.")
        #expect(AdvisorText.name(OfferKind.sale) == "Sale" && AdvisorText.name(OfferKind.loan) == "Loan")
        #expect(AdvisorText.name(LoanPurpose.development) == "For his development" && AdvisorText.name(LoanPurpose.wage) == "To move his wage")
        #expect(AdvisorText.name(PlayingTime.startingPlace) == "A starting place" && AdvisorText.name(PlayingTime.less) == "Less than a starting place")
        #expect(AdvisorText.enteredOn(Self.day) == "entered Sat 21 Nov")
        #expect(AdvisorText.openDealBelow(club: "Barnet") == "You already have an open deal with Barnet for him: its rounds are below.")
    }

    // MARK: sales

    @Test func aSaleAskedOfClubsInGeneral() throws {
        let s = try Self.ask(Self.subject(), .sale)
        #expect(Self.lines(s, kind: .sale, subject: Self.subject()) == [
            "Ask £40,000, with 20% of his next fee.",
            "Offer him to clubs without transfer-listing him (carried over from FM24 and FM26, reports only).",
            "With no club interested, earlier reports are of no bid, or a bid at 5 to 10% of his value (carried over from FM24, one report)."])
    }

    @Test func aSaleProposedToAClubWithEnoughBudget() throws {
        let s = try Self.proposal(Self.subject(), .sale, club: Self.club())
        #expect(Self.lines(s, kind: .sale, subject: Self.subject(), club: "Barnet") == ["Propose £40,000 now, with 20% of his next fee."])
    }

    @Test func theRestAskedLaterNamesTheBudgetAsEntered() throws {
        let s = try Self.proposal(Self.subject(), .sale, club: Self.club(budget: 35_400))
        #expect(Self.lines(s, kind: .sale, subject: Self.subject(), club: "Barnet")[1] ==
                "Barnet can spend £35,400 now; the rest is asked later. Whether a club agrees to money beyond its budget is not known.")
    }

    @Test func aSaleSplitWhenTheBudgetIsShort() throws {
        let s = try Self.proposal(Self.subject(), .sale, club: Self.club(budget: 35_000))
        #expect(Self.lines(s, kind: .sale, subject: Self.subject(), club: "Barnet") == [
            "Propose £35,000 now, £2,200 over 12 months and £2,800 after 50 league appearances, with 20% of his next fee.",
            "Barnet can spend £35,000 now; the rest is asked later. Whether a club agrees to money beyond its budget is not known."])
    }

    @Test func aSaleWithNothingToSpendNow() throws {
        let s = try Self.proposal(Self.subject(), .sale, club: Self.club(budget: 0))
        #expect(Self.lines(s, kind: .sale, subject: Self.subject(), club: "Barnet") == [
            "Propose £18,000 over 12 months and £22,000 after 50 league appearances, with 20% of his next fee.",
            "Barnet have nothing to spend now, so all of it is asked later. Whether a club agrees to money beyond its budget is not known."])
    }

    @Test func theClubsWageFiguresUnderHisWage() throws {
        let subject = Self.subject()
        let left = try Self.proposal(subject, .sale, club: Self.club(wageBudget: 3_300, spent: 3_000))
        #expect(Self.lines(left, kind: .sale, subject: subject, club: "Barnet").contains(
            "Barnet have £300 a week left in their wage budget and he earns £450 a week: he would have to take less to go there."))
        let highest = try Self.proposal(subject, .sale, club: Self.club(highest: 400))
        #expect(Self.lines(highest, kind: .sale, subject: subject, club: "Barnet").contains(
            "The highest wage Barnet can offer is £400 a week and he earns £450 a week: he would have to take less to go there."))
        #expect(Self.lines(left, kind: .sale, subject: subject, club: "Barnet", style: Self.monthly).contains(
            "Barnet have £1,300 a month left in their wage budget and he earns £1,950 a month: he would have to take less to go there."))
    }

    @Test func whatToAnswerToASalesBid() throws {
        let subject = Self.subject()
        let c = Self.club()
        let accept = try Self.proposal(subject, .sale, club: c, rounds: [Self.saleRound(.club, now: 40_000, nil)])
        #expect(Self.lines(accept, kind: .sale, subject: subject, club: "Barnet") == ["Accept: it meets your ask."])
        let agreed = try Self.proposal(subject, .sale, club: c, rounds: [Self.saleRound(.owner, now: 40_000, fee: 20, .accepted)])
        #expect(agreed.advice == .agreed)
        #expect(Self.lines(agreed, kind: .sale, subject: subject, club: "Barnet") == ["The deal is agreed."])
        let counter = try Self.proposal(subject, .sale, club: c, rounds: [Self.saleRound(.club, now: 8_000, nil)])
        #expect(Self.lines(counter, kind: .sale, subject: subject, club: "Barnet") == [
            "Counter once: £8,000 now and £1,600 later, after 50 league appearances, with 20% of his next fee."])
        let again = try Self.proposal(subject, .sale, club: c, rounds: [
            Self.saleRound(.club, now: 8_000, nil), Self.saleRound(.owner, now: 8_000, later: 1_600, fee: 20, nil), Self.saleRound(.club, now: 8_000, nil)])
        #expect(Self.lines(again, kind: .sale, subject: subject, club: "Barnet") == [
            "Accept it or leave it: earlier reports are of two or three chances before a club withdraws (carried over, one report)."])
    }

    @Test func waitingAndNothingLower() throws {
        let subject = Self.subject()
        let c = Self.club()
        let waiting = try Self.proposal(subject, .sale, club: c, rounds: [Self.saleRound(.owner, now: 40_000, fee: 20, nil)])
        #expect(Self.lines(waiting, kind: .sale, subject: subject, club: "Barnet") == ["Waiting for Barnet's answer."])
        #expect(Self.lines(waiting, kind: .sale, subject: subject, club: nil) == ["Waiting for the club's answer."])
        let refused = (0..<3).map { _ in Self.saleRound(.owner, now: 40_000, fee: 20, .refused) }
        let down = try Self.proposal(subject, .sale, club: c, rounds: refused)
        #expect(Self.lines(down, kind: .sale, subject: subject, club: "Barnet") == [
            "Barnet have turned down or not answered three proposals. Leave it, or ask what they would pay."])
        let asks = (0..<3).map { _ in Self.noBid(SaleTerms(now: 40_000, later: 0, nextFeePercent: 20)) }
        let none = try Self.ask(subject, .sale, earlier: asks)
        #expect(Self.lines(none, kind: .sale, subject: subject) == [
            "Three asks have drawn no bid. Earlier reports are that with no club interested no price brings one (carried over from FM24, reports only). Find interest first: ask his agent about interest, or pitch him against a club's stated need."])
    }

    @Test func aValueOfZeroAndASteppedDownAsk() throws {
        let zero = Self.subject(value: 0)
        let s = try Self.ask(zero, .sale)
        let l = Self.lines(s, kind: .sale, subject: zero)
        #expect(l[0] == "Ask no fee, with 20% of his next fee.")
        #expect(l[1] == "The game gives him no value, so no fee is asked.")
        let c = try Self.proposal(zero, .sale, club: Self.club(budget: 1_000))
        #expect(Self.lines(c, kind: .sale, subject: zero, club: "Barnet")[0] == "Propose no fee, with 20% of his next fee.")
        let stepped = try Self.ask(Self.subject(), .sale, earlier: [Self.noBid(SaleTerms(now: 40_000, later: 0, nextFeePercent: 20))])
        #expect(Self.lines(stepped, kind: .sale, subject: Self.subject()).contains(
            "Lowered after the last one was turned down or drew no answer (this tool's own step, with no evidence)."))
    }

    @Test func measuredFiguresUsedAreSaid() throws {
        let line = Self.measures(sale: Self.reading(line: 0.51))
        let s = try Self.ask(Self.subject(), .sale, measures: line)
        #expect(Self.lines(s, kind: .sale, subject: Self.subject()).last == "The line your own offers show is 51% of his value (this tool's estimate).")
        let step = Self.measures(sale: Self.reading(line: 0.51), counterDeals: 3, step: 1.15)
        let counter = try Self.proposal(Self.subject(), .sale, club: Self.club(), rounds: [Self.saleRound(.club, now: 8_000, nil)], measures: step)
        let l = Self.lines(counter, kind: .sale, subject: Self.subject(), club: "Barnet")
        #expect(l.suffix(2) == ["The line your own offers show is 51% of his value (this tool's estimate).",
                                "Your own agreed sales show clubs coming up 15% over a bid (this tool's estimate)."])
    }

    // MARK: loans

    @Test func aLoanAskedOfClubsInGeneral() throws {
        let subject = Self.subject(value: 50_000, wage: 500)
        let s = try Self.ask(subject, .loan)
        #expect(Self.lines(s, kind: .loan, subject: subject) == [
            "Ask 50% of his wage, a starting place (Regular Starter) and no fee, and keep the recall.",
            "50% is within what the loan rule says a borrower bears: his value ÷ 192 a week (carried over from about FM22, no sample).",
            "Clubs are reported to open at none of the wage and Squad Player, and to accept more when you propose the terms yourself (carried over from FM24, one report)."])
    }

    @Test func aLoanLimitedByTheClub() throws {
        let subject = Self.subject(value: 50_000, wage: 500, goalkeeper: true)
        let left = try Self.proposal(subject, .loan, club: Self.club(budget: nil, wageBudget: 5_000, spent: 4_800))
        #expect(Self.lines(left, kind: .loan, subject: subject, club: "Barnet") == [
            "Ask 40% of his wage, a starting place (First-Choice Goalkeeper) and no fee, and keep the recall.",
            "40% is within what Barnet have left in their wage budget: £200 a week."])
        let highest = try Self.proposal(subject, .loan, club: Self.club(budget: nil, wageBudget: 5_000, spent: 3_000, highest: 150))
        #expect(Self.lines(highest, kind: .loan, subject: subject, club: "Barnet").last == "30% is within the highest wage Barnet can offer: £150 a week.")
        let big = Self.subject(value: 120_000, wage: 500)
        let monthly = try Self.proposal(big, .loan, club: Self.club(budget: nil, wageBudget: 5_000, spent: 4_550))
        #expect(Self.lines(monthly, kind: .loan, subject: big, club: "Barnet", style: Self.monthly).contains(
            "90% is within what Barnet have left in their wage budget: £1,950 a month."))
    }

    @Test func aLoanWithAFee() throws {
        let subject = Self.subject(value: 120_000, wage: 500)
        let s = try Self.ask(subject, .loan)
        #expect(Self.lines(s, kind: .loan, subject: subject).prefix(3) == [
            "Ask all of his wage and £500 a month, a starting place (Regular Starter), and keep the recall.",
            "All of his wage is within what the loan rule says a borrower bears: his value ÷ 192 a week (carried over from about FM22, no sample).",
            "Older versions did not allow a recall clause with a loan fee (carried over from FM11 and FM19, reports only): if the game refuses, drop the fee."])
    }

    @Test func aLoanToMoveHisWage() throws {
        let subject = Self.subject(value: 50_000, wage: 500, purpose: .wage)
        let s = try Self.ask(subject, .loan)
        let l = Self.lines(s, kind: .loan, subject: subject)
        #expect(l[0] == "Ask 50% of his wage and no fee, with whatever playing time the club offers, and keep the recall.")
        #expect(l.contains("An optional fee to buy him later can be offered, at £50,000."))
    }

    @Test func aLoanOnAValueOfZero() throws {
        let subject = Self.subject(value: 0, wage: 500)
        let l = Self.lines(try Self.ask(subject, .loan), kind: .loan, subject: subject)
        #expect(l.contains("The game gives him no value, so none of his wage is asked."))
        #expect(l[0].hasPrefix("Ask none of his wage"))
    }

    @Test func whatToAnswerToALoan() throws {
        let c = Self.club(budget: nil, wageBudget: 5_000, spent: 3_000)
        let dev = Self.subject(value: 50_000, wage: 500)
        let wage = Self.subject(value: 50_000, wage: 500, purpose: .wage)
        func go(_ subject: OfferSubject, _ rounds: [OfferRound]) throws -> [String] {
            Self.lines(try Self.proposal(subject, .loan, club: c, rounds: rounds), kind: .loan, subject: subject, club: "Barnet")
        }
        #expect(try go(dev, [Self.loanRound(.club, 20, time: .startingPlace, nil)]) == ["Accept: a starting place is what the loan is for."])
        #expect(try go(wage, [Self.loanRound(.club, 50, time: .less, nil)]) == ["Accept: it meets the share you asked."])
        #expect(try go(dev, [Self.loanRound(.club, 20, time: .less, nil)]) == ["Send back 20% of his wage with a starting place (Regular Starter)."])
        #expect(try go(wage, [Self.loanRound(.club, 20, time: .less, nil)]) == ["Send back 30% of his wage."])
        #expect(try go(wage, [Self.loanRound(.club, 20, fee: 200, time: .less, nil)]) == ["Send back 30% of his wage and £200 a month."])
        #expect(try go(dev, [Self.loanRound(.owner, 0, time: .startingPlace, .refused)]) == ["At none of his wage and turned down, Barnet do not want him on these terms."])
    }

    @Test func aMeasuredLoanLineIsSaidByTheMonthAndNamesNoRule() throws {
        let subject = Self.subject(value: 50_000, wage: 500)
        let m = Self.measures(loan: Self.reading(line: 0.00525))
        let s = try Self.ask(subject, .loan, measures: m)
        let l = Self.lines(s, kind: .loan, subject: subject)
        #expect(l.contains("50% is within what your own offers show a borrower bears."))
        #expect(l.last == "The line your own offers show is 2.1% of his value a month (this tool's estimate)." || l.contains("The line your own offers show is 2.1% of his value a month (this tool's estimate)."))
        let all = Self.subject(value: 120_000, wage: 500)
        let big = try Self.ask(all, .loan, measures: m)
        #expect(Self.lines(big, kind: .loan, subject: all).contains("All of his wage is within what your own offers show a borrower bears."))
    }

    // MARK: record

    @Test func theRecord() {
        let m = Self.money
        let theirBid = Self.saleRound(.club, now: 8_000, nil)
        #expect(AdvisorText.roundLine(theirBid, club: "Barnet", clubFollows: false, money: m) == "Sat 21 Nov: Barnet bid £8,000 now.")
        let mine = Self.saleRound(.owner, now: 35_000, later: 5_000, fee: 20, .refused)
        #expect(AdvisorText.roundLine(mine, club: "Barnet", clubFollows: false, money: m) == "Sat 21 Nov: you proposed £35,000 now and £5,000 later, with 20% of his next fee. Refused.")
        #expect(AdvisorText.roundLine(mine, club: "Barnet", clubFollows: true, money: m) == "Sat 21 Nov: you proposed £35,000 now and £5,000 later, with 20% of his next fee. Refused.")
        let theirLoan = Self.loanRound(.club, 20, time: .less, nil)
        #expect(AdvisorText.roundLine(theirLoan, club: "Barnet", clubFollows: false, money: m) == "Sat 21 Nov: Barnet offered 20% of his wage and less than a starting place.")
        let ask = OfferAsk(id: UUID(), player: PlayerID(key: "x"), playerName: "X", kind: .sale, day: Self.day,
                           terms: .sale(SaleTerms(now: 40_000, later: 0, nextFeePercent: 20)), value: 40_000, wagePerWeek: 450, noBidCame: true)
        #expect(AdvisorText.askLine(ask, money: m) == "Sat 21 Nov: offered to clubs at £40,000, with 20% of his next fee. No bid came.")
        #expect(AdvisorText.termsLine(.sale(SaleTerms(now: 35_000, later: 5_000, nextFeePercent: 20)), money: m) == "£35,000 now and £5,000 later, with 20% of his next fee.")
        #expect(AdvisorText.termsLine(.loan(LoanTerms(wagePercent: 100, feePerMonth: 500, playingTime: .startingPlace, recall: true, futureFee: nil)), money: m)
                == "All of his wage, £500 a month and a starting place.")
    }

    @Test func aProposalTheClubAnsweredWithTermsOfItsOwnReadsCountered() {
        let m = Self.money
        let mine = Self.saleRound(.owner, now: 40_000, fee: 20, nil)
        #expect(AdvisorText.roundLine(mine, club: "Barnet", clubFollows: true, money: m) == "Sat 21 Nov: you proposed £40,000 now, with 20% of his next fee. Countered.")
        #expect(AdvisorText.roundLine(mine, club: "Barnet", clubFollows: false, money: m) == "Sat 21 Nov: you proposed £40,000 now, with 20% of his next fee. No answer yet.")
    }

    // MARK: measures

    @Test func whatTheOffersHaveShown() {
        let r = Self.rules
        let since = Day(year: 2026, month: 11, day: 17)!
        let measured = Self.measures(sale: Self.reading(deals: 7, agreed: 2, paid: 5, down: 6, mp: 0.22, md: 0.80, line: 0.51, since: since))
        #expect(AdvisorText.offerMeasureLines(measured, kind: .sale, rules: r) == [
            "Sales: 7 deals recorded since Tue 17 Nov, 2 agreed.",
            "Clubs have offered or paid about 22% of a player's value and turned down about 80%, so sales are now asked at 51% (from 5 offered or paid and 6 turned down; this tool's estimate)."])
        let few = Self.measures(sale: Self.reading(deals: 3, agreed: 1, paid: 2, down: 1, since: since))
        #expect(AdvisorText.offerMeasureLines(few, kind: .sale, rules: r) == [
            "Sales: 3 deals recorded since Tue 17 Nov, 1 agreed.",
            "The line for sales is not measured yet: it needs 5 offered or paid and 5 turned down, and has 2 and 1. Until then a sale is asked at the player's value."])
        let crossed = Self.measures(sale: Self.reading(deals: 10, agreed: 5, paid: 5, down: 5, mp: 0.6, md: 0.4, since: since))
        #expect(AdvisorText.offerMeasureLines(crossed, kind: .sale, rules: r)[1] ==
                "Your sales show no line: clubs have offered or paid about 60% of value and others turned down about 40%. A sale is still asked at the player's value.")
        let loanSince = Day(year: 2026, month: 11, day: 21)!
        let loan = Self.measures(loan: Self.reading(deals: 1, agreed: 0, paid: 1, down: 0, since: loanSince))
        #expect(AdvisorText.offerMeasureLines(loan, kind: .loan, rules: r) == [
            "Loans: 1 deal recorded since Sat 21 Nov, none agreed.",
            "The line for loans is not measured yet: it needs 5 offered or agreed and 5 turned down, and has 1 and 0. Until then a loan is asked at what the loan rule says a borrower bears."])
        let loanLine = Self.measures(loan: Self.reading(deals: 10, agreed: 5, paid: 5, down: 5, mp: 0.003, md: 0.0075, line: 0.00525, since: since))
        #expect(AdvisorText.offerMeasureLines(loanLine, kind: .loan, rules: r)[1] ==
                "Borrowers have offered or agreed to bear about 1.2% of a player's value a month and turned down about 3.0%, so loans are now asked at 2.1% (from 5 offered or agreed and 5 turned down; this tool's estimate).")
        let loanCrossed = Self.measures(loan: Self.reading(deals: 10, agreed: 5, paid: 5, down: 5, mp: 0.0075, md: 0.003, since: since))
        #expect(AdvisorText.offerMeasureLines(loanCrossed, kind: .loan, rules: r)[1] ==
                "Your loans show no line: borrowers have offered or agreed to bear about 3.0% of value a month and others turned down about 1.2%. A loan is still asked at what the loan rule says a borrower bears.")
        #expect(AdvisorText.offerMeasureLines(.none, kind: .sale, rules: r) == ["Sales: nothing recorded."])
        #expect(AdvisorText.offerMeasureLines(.none, kind: .loan, rules: r) == ["Loans: nothing recorded."])
    }

    @Test func anAskAloneIsRecordedThoughNoDealIs() {
        let r = Self.rules
        let since = Day(year: 2026, month: 11, day: 13)!
        let one = Self.measures(sale: Self.reading(asks: 1, since: since))
        #expect(AdvisorText.offerMeasureLines(one, kind: .sale, rules: r) == [
            "Sales: 1 ask recorded since Fri 13 Nov, and no deal yet.",
            "The line for sales is not measured yet: it needs 5 offered or paid and 5 turned down, and has 0 and 0. Until then a sale is asked at the player's value."])
        let two = Self.measures(loan: Self.reading(asks: 2, since: since))
        #expect(AdvisorText.offerMeasureLines(two, kind: .loan, rules: r)[0] == "Loans: 2 asks recorded since Fri 13 Nov, and no deal yet.")
        // With a deal, the deals' line stands, asks or not.
        let both = Self.measures(sale: Self.reading(deals: 1, asks: 3, since: since))
        #expect(AdvisorText.offerMeasureLines(both, kind: .sale, rules: r)[0] == "Sales: 1 deal recorded since Fri 13 Nov, none agreed.")
    }

    @Test func theCounterStepAndTheDay() {
        let r = Self.rules
        #expect(AdvisorText.counterStepLine(Self.measures(counterDeals: 3, step: 1.15), rules: r) ==
                "Clubs have come up about 15% from a first bid (from 3 agreed sales you countered; this tool's estimate).")
        #expect(AdvisorText.counterStepLine(Self.measures(counterDeals: 1), rules: r) ==
                "How far clubs come up is not measured yet: it needs 3 agreed sales in which you countered a bid, and has 1.")
        #expect(AdvisorText.offersMeasuredFrom(Day(year: 2026, month: 11, day: 17)!) == "Measured from Tue 17 Nov.")
    }

    @Test func theEvidenceNoteTakesItsNumbersFromTheRules() {
        #expect(AdvisorText.offersEvidenceNote(Self.rules) == [
            "A club offers only what it can afford (FM26, official). The club's budget and wage figures are the club's own, as you entered them.",
            "Carried over from reports on older versions, none of them a test: a sale at about his value, 20% of his next fee, the loan rule of his value ÷ 192 a week, and a counter of up to 20% over a bid.",
            "This tool's own, with no evidence: the 12 months of instalments, the step down of 10% after a refusal and its limit of two, and the 5 deals each way and 3 countered sales needed before anything is measured.",
            "What is measured from your own offers shows only what you tried: a line rises only when a higher ask is accepted."])
        var changed = Self.rules
        changed.nextFeePercent = 25
        #expect(AdvisorText.offersEvidenceNote(changed)[1].contains("25% of his next fee"))
    }

    @Test func withNoClubNameTheCautionsAreSentences() throws {
        let subject = Self.subject()
        let s = try Self.proposal(subject, .sale, club: Self.club(wageBudget: 3_300, spent: 3_000, highest: 400))
        let l = Self.lines(s, kind: .sale, subject: subject, club: nil)
        #expect(l.contains("The club has £300 a week left in its wage budget and he earns £450 a week: he would have to take less to go there."))
        #expect(l.contains("The highest wage the club can offer is £400 a week and he earns £450 a week: he would have to take less to go there."))
        let loan = Self.subject(value: 50_000, wage: 500)
        let down = try Self.proposal(loan, .loan, club: Self.club(budget: nil, wageBudget: 5_000, spent: 3_000), rounds: [Self.loanRound(.owner, 0, time: .startingPlace, .refused)])
        #expect(Self.lines(down, kind: .loan, subject: loan, club: nil) == ["At none of his wage and turned down, the club does not want him on these terms."])
    }

    @Test func aLoanRuleOfZeroLeavesTheDivisorOut() throws {
        var r = Self.rules
        r.loanLinePerWeek = 0
        let subject = Self.subject(value: 50_000, wage: 500)
        let s = OfferSuggestion(advice: .propose(.loan(LoanTerms(wagePercent: 50, feePerMonth: 0, playingTime: .startingPlace, recall: true, futureFee: nil)), split: nil),
                                notes: [.shareLimitedBy(.value), .shareLimitedBy(.all)], basis: Self.p.offerRules.evidence)
        let l = AdvisorText.offerLines(s, kind: .loan, subject: subject, club: nil, money: Self.money, rules: r)
        #expect(l[1] == "50% is within what the loan rule says a borrower bears (carried over from about FM22, no sample).")
        #expect(l[2] == "All of his wage is within what the loan rule says a borrower bears (carried over from about FM22, no sample).")
        let note = AdvisorText.offersEvidenceNote(r)
        #expect(note[1] == "Carried over from reports on older versions, none of them a test: a sale at about his value, 20% of his next fee, the loan rule, and a counter of up to 20% over a bid.")
        r.loanLinePerWeek = .infinity
        #expect(!AdvisorText.offersEvidenceNote(r)[1].contains("÷"))
    }

    @Test func noSentenceHoldsNanOrInf() throws {
        var all: [String] = []
        for value in [0, 40_000] {
            for wage in [0.0, 450] {
                let subject = Self.subject(value: value, wage: wage)
                let wsubject = Self.subject(value: value, wage: wage, purpose: .wage)
                for (kind, subj) in [(OfferKind.sale, subject), (.loan, subject), (.loan, wsubject)] {
                    all += Self.lines(try Self.ask(subj, kind), kind: kind, subject: subj)
                    for budget in [0, 1_000] {
                        let c = Self.club(budget: budget, wageBudget: 0, spent: 0, highest: 0)
                        all += Self.lines(try Self.proposal(subj, kind, club: c), kind: kind, subject: subj, club: "Barnet")
                    }
                }
            }
        }
        for line in all {
            let lower = line.lowercased()
            #expect(!lower.contains("nan") && !lower.contains("inf"), "\(line)")
        }
        #expect(!all.isEmpty)
    }
}
