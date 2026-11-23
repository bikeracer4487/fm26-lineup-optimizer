import Foundation

/// The words of the Offers advice: the terms to propose when a player is sold or loaned out, the record of what clubs
/// answered, and what the owner's own offers have shown. Every figure in a sentence comes from the suggestion, the
/// measures or `OfferRules`; nothing is worked out here but plurals, percentages and joins. Every `switch` over the
/// feature's enums is exhaustive.
extension AdvisorText {
    // MARK: Fixed lines

    public static let offersIntro = "Terms to propose for the players you have marked to sell or to loan out. No test in any version of the game shows what a club accepts: every figure here is a place to start, and says what it rests on."
    public static let offersNobodyMarked = "Nobody is marked to sell or to loan out. Mark a player on Player Removal to get terms for him."
    public static let valueHint = "the lower figure of the value on his profile"
    public static let valueCaution = "Read it before you transfer-list him: once he is listed with an asking price, the game stores that price as his value (carried over from FM26, four players)."
    public static let startingPlaceMeans = "A starting place is Regular Starter or anything the game ranks above it, and First-Choice Goalkeeper for a goalkeeper."
    public static let nothingRecorded = "Nothing is recorded yet. Record what you propose and what clubs answer, and this part will say what your own offers show."
    public static let measureOffersAgainQuestion = "Measure again from today? Offers recorded before today stay in the record and are left out of what is measured. This cannot be undone in the app."

    // MARK: Names

    public static func name(_ kind: OfferKind) -> String {
        switch kind {
        case .sale: "Sale"
        case .loan: "Loan"
        }
    }

    public static func name(_ purpose: LoanPurpose) -> String {
        switch purpose {
        case .development: "For his development"
        case .wage: "To move his wage"
        }
    }

    public static func name(_ time: PlayingTime) -> String {
        switch time {
        case .startingPlace: "A starting place"
        case .less: "Less than a starting place"
        }
    }

    public static func enteredOn(_ day: Day) -> String { "entered \(shortDay(day))" }

    public static func openDealBelow(club: String) -> String {
        "You already have an open deal with \(club) for him: its rounds are below."
    }

    // MARK: Small helpers

    private static func numberWord(_ n: Int) -> String {
        let words = ["none", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]
        return n >= 0 && n < words.count ? words[n] : "\(n)"
    }

    private static func capitalised(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    private static func count(_ n: Int, _ noun: String) -> String { "\(n) \(noun)\(n == 1 ? "" : "s")" }

    private static func joined(_ parts: [String]) -> String {
        switch parts.count {
        case 0: ""
        case 1: parts[0]
        default: parts.dropLast().joined(separator: ", ") + " and " + parts[parts.count - 1]
        }
    }

    /// The loan rule's divisor, as the rule is spoken of: his value ÷ 192 a week.
    /// Nil when the rule's figure is 0 or not finite, so that the clause is left out rather than written wrongly.
    private static func loanDivisor(_ rules: OfferRules) -> String? {
        let divisor = 1 / rules.loanLinePerWeek
        guard rules.loanLinePerWeek > 0, rules.loanLinePerWeek.isFinite, divisor.isFinite, divisor >= 0.5, divisor < 1e9 else { return nil }
        return "\(Int(divisor.rounded()))"
    }

    /// "his value ÷ 192 a week" with its leading ": ", or nothing.
    private static func loanDivisorClause(_ rules: OfferRules) -> String {
        loanDivisor(rules).map { ": his value ÷ \($0) a week" } ?? ""
    }

    /// "the loan rule of his value ÷ 192 a week", or "the loan rule".
    private static func loanRuleOf(_ rules: OfferRules) -> String {
        loanDivisor(rules).map { "the loan rule of his value ÷ \($0) a week" } ?? "the loan rule"
    }

    private static func startingPlaceName(goalkeeper: Bool) -> String {
        goalkeeper ? "First-Choice Goalkeeper" : "Regular Starter"
    }

    private static func share(_ percent: Int) -> String {
        switch percent {
        case 0: "none of his wage"
        case 100: "all of his wage"
        default: "\(percent)% of his wage"
        }
    }

    private static func nextFeeClause(_ percent: Int) -> String { percent > 0 ? ", with \(percent)% of his next fee" : "" }

    private static func feePerMonth(_ fee: Int, _ money: MoneyStyle) -> String { "\(Display.money(fee, symbol: money.symbol)) a month" }

    // MARK: Terms as recorded

    /// A sale's money: "£35,000 now and £5,000 later", "£8,000 now", "£5,000 later" or "no fee", with the share of his
    /// next fee after it.
    private static func saleRecord(_ t: SaleTerms, _ money: MoneyStyle) -> String {
        var parts: [String] = []
        if t.now > 0 { parts.append("\(Display.money(t.now, symbol: money.symbol)) now") }
        if t.later > 0 { parts.append("\(Display.money(t.later, symbol: money.symbol)) later") }
        let amount = parts.isEmpty ? "no fee" : parts.joined(separator: " and ")
        return amount + nextFeeClause(t.nextFeePercent)
    }

    private static func timeRecord(_ time: PlayingTime) -> String {
        switch time {
        case .startingPlace: "a starting place"
        case .less: "less than a starting place"
        }
    }

    private static func loanRecord(_ t: LoanTerms, _ money: MoneyStyle) -> String {
        var parts = [share(t.wagePercent)]
        if t.feePerMonth > 0 { parts.append(feePerMonth(t.feePerMonth, money)) }
        if let time = t.playingTime { parts.append(timeRecord(time)) }
        var text = joined(parts)
        if let future = t.futureFee { text += ", with an optional fee of \(Display.money(future, symbol: money.symbol)) to buy him" }
        if !t.recall { text += ", without a recall" }
        return text
    }

    private static func record(_ terms: OfferTerms, _ money: MoneyStyle) -> String {
        switch terms {
        case .sale(let t): saleRecord(t, money)
        case .loan(let t): loanRecord(t, money)
        }
    }

    /// Recorded terms on one line, with no advice.
    public static func termsLine(_ terms: OfferTerms, money: MoneyStyle) -> String {
        capitalised(record(terms, money)) + "."
    }

    /// An owner's round's answer; one with none that a round of the club's follows was countered.
    private static func answerWords(_ answer: RoundAnswer?, clubFollows: Bool) -> String {
        switch answer {
        case .accepted?: " Accepted."
        case .refused?: " Refused."
        case .noReply?: " No answer."
        case nil: clubFollows ? " Countered." : " No answer yet."
        }
    }

    /// A round as recorded. `clubFollows`: a round of the club's comes after this one in the deal, so an owner's round
    /// with no answer was countered.
    public static func roundLine(_ round: OfferRound, club: String, clubFollows: Bool, money: MoneyStyle) -> String {
        let day = shortDay(round.day)
        switch round.by {
        case .club:
            let verb: String
            switch round.terms {
            case .sale: verb = "bid"
            case .loan: verb = "offered"
            }
            let accepted = round.answer == .accepted ? " You accepted." : ""
            return "\(day): \(club) \(verb) \(record(round.terms, money)).\(accepted)"
        case .owner:
            return "\(day): you proposed \(record(round.terms, money)).\(answerWords(round.answer, clubFollows: clubFollows))"
        }
    }

    public static func askLine(_ ask: OfferAsk, money: MoneyStyle) -> String {
        let terms: String
        switch ask.terms {
        case .sale(let t):
            var amount = t.now + t.later > 0 ? "at \(Display.money(t.now + t.later, symbol: money.symbol))" : "with no fee"
            amount += nextFeeClause(t.nextFeePercent)
            terms = amount
        case .loan(let t):
            terms = "at " + loanRecord(t, money)
        }
        return "\(shortDay(ask.day)): offered to clubs \(terms).\(ask.noBidCame ? " No bid came." : "")"
    }

    // MARK: Advice

    /// The advice's sentence first, then one sentence for each note, in the notes' order.
    public static func offerLines(_ suggestion: OfferSuggestion, kind: OfferKind, subject: OfferSubject, club: String?,
                                  money: MoneyStyle, rules: OfferRules) -> [String] {
        var lines = [adviceLine(suggestion.advice, kind: kind, subject: subject, club: club, money: money, rules: rules)]
        let measuredLine = suggestion.notes.contains { if case .measuredLine = $0 { true } else { false } }
        let percent = adviceTerms(suggestion.advice).flatMap { terms -> Int? in
            if case .loan(let t) = terms { return t.wagePercent }
            return nil
        }
        for note in suggestion.notes {
            lines.append(noteLine(note, kind: kind, subject: subject, club: club, money: money, rules: rules,
                                  measuredLine: measuredLine, percent: percent))
        }
        return lines
    }

    private static func adviceTerms(_ advice: OfferAdvice) -> OfferTerms? {
        switch advice {
        case .propose(let terms, _), .counter(let terms): terms
        case .accept, .agreed, .acceptOrLeave, .awaitAnswer, .nothingLower: nil
        }
    }

    private static func adviceLine(_ advice: OfferAdvice, kind: OfferKind, subject: OfferSubject, club: String?, money: MoneyStyle,
                                   rules: OfferRules) -> String {
        let name = club ?? "the club"
        switch advice {
        case .propose(.sale(let t), let split):
            let verb = club == nil ? "Ask" : "Propose"
            return "\(verb) \(saleAmount(t, split: split, club: club != nil, money: money, rules: rules))\(nextFeeClause(t.nextFeePercent))."
        case .propose(.loan(let t), _):
            return "Ask " + loanAsk(t, goalkeeper: subject.isGoalkeeper, money: money) + "."
        case .counter(.sale(let t)):
            var parts: [String] = []
            if t.now > 0 { parts.append("\(Display.money(t.now, symbol: money.symbol)) now") }
            if t.later > 0 { parts.append("\(Display.money(t.later, symbol: money.symbol)) later") }
            var amount = parts.isEmpty ? "no fee" : parts.joined(separator: " and ")
            if t.later > 0 { amount += ", after \(rules.appearancesForLater) league appearances" }
            return "Counter once: \(amount)\(nextFeeClause(t.nextFeePercent))."
        case .counter(.loan(let t)):
            var parts = [share(t.wagePercent)]
            if t.feePerMonth > 0 { parts.append(feePerMonth(t.feePerMonth, money)) }
            var text = "Send back " + joined(parts)
            if let time = t.playingTime {
                switch time {
                case .startingPlace: text += " with a starting place (\(startingPlaceName(goalkeeper: subject.isGoalkeeper)))"
                case .less: text += " with less than a starting place"
                }
            }
            return text + "."
        case .accept:
            switch kind {
            case .sale: return "Accept: it meets your ask."
            case .loan:
                switch subject.purpose {
                case .development: return "Accept: a starting place is what the loan is for."
                case .wage: return "Accept: it meets the share you asked."
                }
            }
        case .agreed:
            return "The deal is agreed."
        case .acceptOrLeave:
            return "Accept it or leave it: earlier reports are of two or three chances before a club withdraws (carried over, one report)."
        case .awaitAnswer:
            return "Waiting for \(name)'s answer."
        case .nothingLower(let reason):
            switch reason {
            case .clubTurnedDownThree:
                return "\(club.map { "\($0) have" } ?? "The club has") turned down or not answered \(numberWord(rules.stepsDownAtMost + 1)) proposals. Leave it, or ask what they would pay."
            case .noBidThree:
                return "\(capitalised(numberWord(rules.stepsDownAtMost + 1))) asks have drawn no bid. Earlier reports are that with no club interested no price brings one (carried over from FM24, reports only). Find interest first: ask his agent about interest, or pitch him against a club's stated need."
            case .clubDoesNotWantHim:
                return "At none of his wage and turned down, \(club.map { "\($0) do" } ?? "the club does") not want him on these terms."
            }
        }
    }

    /// A sale's money as proposed: now, then what is asked later in instalments and after appearances.
    private static func saleAmount(_ t: SaleTerms, split: SaleSplit?, club: Bool, money: MoneyStyle, rules: OfferRules) -> String {
        if t.total == 0 { return "no fee" }
        let symbol = money.symbol
        if t.later == 0 { return club ? "\(Display.money(t.now, symbol: symbol)) now" : Display.money(t.now, symbol: symbol) }
        var parts: [String] = []
        if t.now > 0 { parts.append("\(Display.money(t.now, symbol: symbol)) now") }
        if let split {
            if split.instalments > 0 {
                parts.append("\(Display.money(split.instalments, symbol: symbol)) over \(count(rules.instalmentMonths, "month"))")
            }
            if split.afterAppearances > 0 {
                parts.append("\(Display.money(split.afterAppearances, symbol: symbol)) after \(rules.appearancesForLater) league appearances")
            }
        } else {
            parts.append("\(Display.money(t.later, symbol: symbol)) later")
        }
        return joined(parts)
    }

    /// A loan as asked: "50% of his wage, a starting place (Regular Starter) and no fee, and keep the recall".
    private static func loanAsk(_ t: LoanTerms, goalkeeper: Bool, money: MoneyStyle) -> String {
        let time: String? = t.playingTime.map { time in
            switch time {
            case .startingPlace: "a starting place (\(startingPlaceName(goalkeeper: goalkeeper)))"
            case .less: "less than a starting place"
            }
        }
        let recall = t.recall ? ", and keep the recall" : ""
        let wage = share(t.wagePercent)
        if t.feePerMonth > 0 {
            if let time { return "\(wage) and \(feePerMonth(t.feePerMonth, money)), \(time)\(recall)" }
            return "\(wage) and \(feePerMonth(t.feePerMonth, money)), with whatever playing time the club offers\(recall)"
        }
        if let time { return "\(wage), \(time) and no fee\(recall)" }
        return "\(wage) and no fee, with whatever playing time the club offers\(recall)"
    }

    private static func noteLine(_ note: OfferNote, kind: OfferKind, subject: OfferSubject, club: String?, money: MoneyStyle,
                                 rules: OfferRules, measuredLine: Bool, percent: Int?) -> String {
        let name = club ?? "The club"
        let beyondBudget = "Whether a club agrees to money beyond its budget is not known."
        switch note {
        case .valueIsZero:
            switch kind {
            case .sale: return "The game gives him no value, so no fee is asked."
            case .loan: return "The game gives him no value, so none of his wage is asked."
            }
        case .steppedDown:
            return "Lowered after the last one was turned down or drew no answer (this tool's own step, with no evidence)."
        case .doNotList:
            return "Offer him to clubs without transfer-listing him (carried over from FM24 and FM26, reports only)."
        case .noInterestBids:
            return "With no club interested, earlier reports are of no bid, or a bid at \(Display.percent(rules.noInterestBidLow).dropLast()) to \(Display.percent(rules.noInterestBidHigh)) of his value (carried over from FM24, one report)."
        case .clubsOpenLow:
            return "Clubs are reported to open at none of the wage and Squad Player, and to accept more when you propose the terms yourself (carried over from FM24, one report)."
        case .nothingToSpendNow:
            return "\(name) have nothing to spend now, so all of it is asked later. \(beyondBudget)"
        case .restAskedLater(let budget):
            return "\(name) can spend \(Display.money(budget, symbol: money.symbol)) now; the rest is asked later. \(beyondBudget)"
        case .wageLeftUnderHisWage(let left):
            return "\(club.map { "\($0) have" } ?? "The club has") \(Display.wage(perWeek: left, money)) left in \(club == nil ? "its" : "their") wage budget and he earns \(Display.wage(perWeek: subject.wagePerWeek, money)): he would have to take less to go there."
        case .highestWageUnderHisWage(let highest):
            return "The highest wage \(club ?? "the club") can offer is \(Display.wage(perWeek: highest, money)) and he earns \(Display.wage(perWeek: subject.wagePerWeek, money)): he would have to take less to go there."
        case .shareLimitedBy(let limit):
            let lead = percent.map { "\($0)%" } ?? "The share"
            let rule = measuredLine
                ? "what your own offers show a borrower bears"
                : "what the loan rule says a borrower bears\(loanDivisorClause(rules)) (carried over from about FM22, no sample)"
            switch limit {
            case .all: return "All of his wage is within \(rule)."
            case .value: return "\(lead) is within \(rule)."
            case .wageLeft(let left):
                return "\(lead) is within what \(club.map { "\($0) have" } ?? "the club has") left in \(club == nil ? "its" : "their") wage budget: \(Display.wage(perWeek: left, money))."
            case .highestWage(let highest):
                return "\(lead) is within the highest wage \(club ?? "the club") can offer: \(Display.wage(perWeek: highest, money))."
            }
        case .recallWithFee:
            return "Older versions did not allow a recall clause with a loan fee (carried over from FM11 and FM19, reports only): if the game refuses, drop the fee."
        case .optionalFutureFee(let fee):
            return "An optional fee to buy him later can be offered, at \(Display.money(fee, symbol: money.symbol))."
        case .measuredLine(let line):
            switch kind {
            case .sale:
                return "The line your own offers show is \(Display.percent(line)) of his value (this tool's estimate)."
            case .loan:
                return "The line your own offers show is \(Display.onePercentDecimal(line * Double(rules.weeksPerMonthInRule))) of his value a month (this tool's estimate)."
            }
        case .measuredCounterStep(let step):
            return "Your own agreed sales show clubs coming up \(Display.percent(step - 1)) over a bid (this tool's estimate)."
        }
    }

    // MARK: What the offers have shown

    public static func offerMeasureLines(_ measures: OfferMeasures, kind: OfferKind, rules: OfferRules) -> [String] {
        let reading: OfferLineReading
        let heading: String
        switch kind {
        case .sale: reading = measures.sale; heading = "Sales"
        case .loan: reading = measures.loan; heading = "Loans"
        }
        guard let since = reading.since,
              reading.deals > 0 || reading.asks > 0 || reading.paid > 0 || reading.turnedDown > 0 else {
            return ["\(heading): nothing recorded."]
        }
        let agreed = reading.agreed == 0 ? "none agreed" : "\(reading.agreed) agreed"
        let first = reading.deals == 0 && reading.asks > 0
            ? "\(heading): \(count(reading.asks, "ask")) recorded since \(shortDay(since)), and no deal yet."
            : "\(heading): \(count(reading.deals, "deal")) recorded since \(shortDay(since)), \(agreed)."
        let weeks = Double(rules.weeksPerMonthInRule)
        let noun = kind == .sale ? "sale" : "loan"
        let fallback = kind == .sale ? "the player's value" : "what the loan rule says a borrower bears"
        // A club's bid counts whether or not it was accepted, so a "paid" is said as offered or paid.
        let offered = kind == .sale ? "offered or paid" : "offered or agreed"
        if let line = reading.line, let paid = reading.medianPaid, let down = reading.medianTurnedDown {
            let basis = "(from \(reading.paid) \(offered) and \(reading.turnedDown) turned down; this tool's estimate)"
            switch kind {
            case .sale:
                return [first, "Clubs have offered or paid about \(Display.percent(paid)) of a player's value and turned down about \(Display.percent(down)), so sales are now asked at \(Display.percent(line)) \(basis)."]
            case .loan:
                return [first, "Borrowers have offered or agreed to bear about \(Display.onePercentDecimal(paid * weeks)) of a player's value a month and turned down about \(Display.onePercentDecimal(down * weeks)), so loans are now asked at \(Display.onePercentDecimal(line * weeks)) \(basis)."]
            }
        }
        if reading.paid >= rules.fewestEachWay, reading.turnedDown >= rules.fewestEachWay,
           let paid = reading.medianPaid, let down = reading.medianTurnedDown {
            switch kind {
            case .sale:
                return [first, "Your sales show no line: clubs have offered or paid about \(Display.percent(paid)) of value and others turned down about \(Display.percent(down)). A sale is still asked at \(fallback)."]
            case .loan:
                return [first, "Your loans show no line: borrowers have offered or agreed to bear about \(Display.onePercentDecimal(paid * weeks)) of value a month and others turned down about \(Display.onePercentDecimal(down * weeks)). A loan is still asked at \(fallback)."]
            }
        }
        return [first, "The line for \(noun)s is not measured yet: it needs \(rules.fewestEachWay) \(offered) and \(rules.fewestEachWay) turned down, and has \(reading.paid) and \(reading.turnedDown). Until then a \(noun) is asked at \(fallback)."]
    }

    public static func counterStepLine(_ measures: OfferMeasures, rules: OfferRules) -> String {
        if let step = measures.counterStep {
            return "Clubs have come up about \(Display.percent(step - 1)) from a first bid (from \(count(measures.counterDeals, "agreed sale")) you countered; this tool's estimate)."
        }
        return "How far clubs come up is not measured yet: it needs \(rules.fewestCounterDeals) agreed sales in which you countered a bid, and has \(measures.counterDeals)."
    }

    public static func offersMeasuredFrom(_ day: Day) -> String { "Measured from \(shortDay(day))." }

    public static func offersEvidenceNote(_ rules: OfferRules) -> [String] {
        [
            "A club offers only what it can afford (FM26, official). The club's budget and wage figures are the club's own, as you entered them.",
            "Carried over from reports on older versions, none of them a test: a sale at about his value, \(rules.nextFeePercent)% of his next fee, \(loanRuleOf(rules)), and a counter of up to \(Display.percent(rules.counterStep - 1)) over a bid.",
            "This tool's own, with no evidence: the \(rules.instalmentMonths) months of instalments, the step down of \(Display.percent(rules.stepDown)) after a refusal and its limit of \(numberWord(rules.stepsDownAtMost)), and the \(rules.fewestEachWay) deals each way and \(rules.fewestCounterDeals) countered sales needed before anything is measured.",
            "What is measured from your own offers shows only what you tried: a line rises only when a higher ask is accepted.",
        ]
    }
}
