import Foundation

/// The terms to propose when the owner sells a player or loans him out. A function of the data it is handed.
public enum Offers {
    /// What is wrong with the rules, in plain words; empty when they can be used.
    static func problems(in rules: OfferRules) -> [String] {
        var found: [String] = []
        if !(rules.saleLine.isFinite && rules.saleLine > 0) {
            found.append("offerRules saleLine is \(rules.saleLine), not a finite number above 0")
        }
        if !(rules.loanLinePerWeek.isFinite && rules.loanLinePerWeek > 0) {
            found.append("offerRules loanLinePerWeek is \(rules.loanLinePerWeek), not a finite number above 0")
        }
        if !(rules.counterStep.isFinite && rules.counterStep > 0) {
            found.append("offerRules counterStep is \(rules.counterStep), not a finite number above 0")
        }
        if rules.wageStepPercent < 1 || rules.wageStepPercent > 100 || 100 % rules.wageStepPercent != 0 {
            found.append("offerRules wageStepPercent is \(rules.wageStepPercent), not a whole number that divides 100")
        }
        if !(0...1).contains(rules.laterInInstalments) {
            found.append("offerRules laterInInstalments is \(rules.laterInInstalments), not between 0 and 1")
        }
        if !(rules.stepDown >= 0 && rules.stepDown < 1) {
            found.append("offerRules stepDown is \(rules.stepDown), not 0 or more and under 1")
        }
        for (name, value) in [("fewestEachWay", rules.fewestEachWay), ("fewestCounterDeals", rules.fewestCounterDeals),
                              ("significantFigures", rules.significantFigures),
                              ("weeksPerMonthInRule", rules.weeksPerMonthInRule)] where value < 1 {
            found.append("offerRules \(name) is \(value), not 1 or more")
        }
        if rules.noInterestBidLow > rules.noInterestBidHigh {
            found.append("offerRules noInterestBidLow is \(rules.noInterestBidLow), over noInterestBidHigh (\(rules.noInterestBidHigh))")
        }
        return found
    }

    /// `amount` to `significantFigures` figures: to nearest, or towards 0 with `down`. An amount with that many
    /// digits or fewer is itself.
    static func rounded(_ amount: Double, down: Bool = false, rules: OfferRules) -> Int {
        guard amount > 0, amount.isFinite else { return 0 }
        let whole = amount.rounded(.towardZero)
        let digits = Int(log10(max(whole, 1)).rounded(.down)) + 1
        let figures = max(1, rules.significantFigures)
        guard digits > figures else { return Int(amount.rounded()) }
        let scale = pow(10, Double(digits - figures))
        let scaled = amount / scale
        return Int((down ? scaled.rounded(.down) : scaled.rounded()) * scale)
    }

    /// Throws when `terms` are not of `kind`, hold a negative amount, or a share over 100%.
    public static func check(_ terms: OfferTerms, kind: OfferKind) throws {
        guard terms.kind == kind else { throw OfferError.wrongKind }
        switch terms {
        case .sale(let t):
            if t.now < 0 { throw OfferError.negative(.feeNow) }
            if t.later < 0 { throw OfferError.negative(.feeLater) }
            if t.nextFeePercent < 0 { throw OfferError.negative(.nextFeePercent) }
            if t.nextFeePercent > 100 { throw OfferError.over100(.nextFeePercent) }
        case .loan(let t):
            if t.wagePercent < 0 { throw OfferError.negative(.wagePercent) }
            if t.wagePercent > 100 { throw OfferError.over100(.wagePercent) }
            if t.feePerMonth < 0 { throw OfferError.negative(.feePerMonth) }
            if let fee = t.futureFee, fee < 0 { throw OfferError.negative(.futureFee) }
        }
    }

    /// The terms to ask of clubs in general: his value's share, lowered after asks that drew no bid.
    public static func ask(_ subject: OfferSubject, kind: OfferKind, earlier: [OfferAsk], measures: OfferMeasures = .none,
                           parameters: EngineParameters) throws -> OfferSuggestion {
        try requireUsable(parameters)
        let rules = measured(parameters.offerRules.value, measures)
        let result: OfferSuggestion
        switch kind {
        case .loan: result = try loanAsk(subject, earlier: earlier, rules: rules, parameters: parameters)
        case .sale: result = try saleAsk(subject, earlier: earlier, rules: rules, parameters: parameters)
        }
        return annotated(result, kind: kind, measures: measures)
    }

    private static func saleAsk(_ subject: OfferSubject, earlier: [OfferAsk], rules: OfferRules,
                                parameters: EngineParameters) throws -> OfferSuggestion {
        if subject.value < 0 { throw OfferError.negative(.value) }
        let total = rounded(rules.saleLine * Double(subject.value), rules: rules)
        var notes: [OfferNote] = []
        if subject.value == 0 { notes.append(.valueIsZero) }
        var terms = SaleTerms(now: total, later: 0, nextFeePercent: rules.nextFeePercent)
        var sales: [SaleTerms] = []
        for item in earlier {
            guard case .sale(let t) = item.terms else { throw OfferError.wrongKind }
            sales.append(t)
        }
        if let latest = earlier.last, latest.noBidCame {
            let run = earlier.reversed().prefix(while: { $0.noBidCame }).count
            if run > rules.stepsDownAtMost {
                return OfferSuggestion(advice: .nothingLower(.noBidThree), notes: notes, basis: parameters.offerRules.evidence)
            }
            let lowered = rounded((1 - rules.stepDown) * Double(sales[sales.count - 1].total), rules: rules)
            terms.now = min(total, lowered)
            notes.append(.steppedDown)
        }
        notes += [.doNotList, .noInterestBids]
        return OfferSuggestion(advice: .propose(.sale(terms), split: nil), notes: notes, basis: parameters.offerRules.evidence)
    }

    /// The terms to propose to a named club, or what to answer to its bid.
    public static func proposal(_ subject: OfferSubject, kind: OfferKind, club: ClubFigures, rounds: [OfferRound],
                                measures: OfferMeasures = .none, parameters: EngineParameters) throws -> OfferSuggestion {
        try requireUsable(parameters)
        let rules = measured(parameters.offerRules.value, measures)
        let result: OfferSuggestion
        switch kind {
        case .loan: result = try loanProposal(subject, club: club, rounds: rounds, rules: rules, parameters: parameters)
        case .sale: result = try saleProposal(subject, club: club, rounds: rounds, rules: rules, parameters: parameters)
        }
        return annotated(result, kind: kind, measures: measures)
    }

    /// The rules with each estimate the record has measured in its place.
    private static func measured(_ rules: OfferRules, _ measures: OfferMeasures) -> OfferRules {
        var rules = rules
        if let line = measures.sale.line { rules.saleLine = line }
        if let line = measures.loan.line { rules.loanLinePerWeek = line }
        if let step = measures.counterStep { rules.counterStep = step }
        return rules
    }

    /// Says on a proposal or a counter which measured figures it used: the line of its kind, then, on a sale's counter,
    /// the counter step. Every other advice used neither.
    private static func annotated(_ suggestion: OfferSuggestion, kind: OfferKind, measures: OfferMeasures) -> OfferSuggestion {
        var result = suggestion
        let isCounter: Bool
        switch suggestion.advice {
        case .propose: isCounter = false
        case .counter: isCounter = true
        case .accept, .acceptOrLeave, .awaitAnswer, .nothingLower: return suggestion
        }
        switch kind {
        case .sale:
            if let line = measures.sale.line { result.notes.append(.measuredLine(line)) }
            if isCounter, let step = measures.counterStep { result.notes.append(.measuredCounterStep(step)) }
        case .loan:
            if let line = measures.loan.line { result.notes.append(.measuredLine(line)) }
        }
        return result
    }

    private static func saleProposal(_ subject: OfferSubject, club: ClubFigures, rounds: [OfferRound], rules: OfferRules,
                                     parameters: EngineParameters) throws -> OfferSuggestion {
        if subject.value < 0 { throw OfferError.negative(.value) }
        let ask = rounded(rules.saleLine * Double(subject.value), rules: rules)
        var notes: [OfferNote] = []
        if subject.value == 0 { notes.append(.valueIsZero) }
        let basis = parameters.offerRules.evidence
        func suggestion(_ advice: OfferAdvice) -> OfferSuggestion {
            OfferSuggestion(advice: advice, notes: notes, basis: basis)
        }
        var sales: [SaleTerms] = []
        for round in rounds {
            guard case .sale(let t) = round.terms else { throw OfferError.wrongKind }
            sales.append(t)
        }
        guard let last = rounds.last, let lastTerms = sales.last else {
            return try sale(total: ask, club: club, subject: subject, rules: rules, notes: notes, basis: basis)
        }
        switch last.by {
        case .club:
            let bid = lastTerms.total
            if bid >= ask { return suggestion(.accept) }
            if alreadyCountered(rounds) { return suggestion(.acceptOrLeave) }
            let counter = min(ask, rounded(rules.counterStep * Double(bid), rules: rules))
            if counter <= bid { return suggestion(.acceptOrLeave) }
            let terms = SaleTerms(now: lastTerms.now, later: lastTerms.later + counter - bid,
                                  nextFeePercent: max(lastTerms.nextFeePercent, rules.nextFeePercent))
            return suggestion(.counter(.sale(terms)))
        case .owner:
            switch last.answer {
            case nil: return suggestion(.awaitAnswer)
            case .accepted?: return suggestion(.accept)
            case .refused?, .noReply?: break
            }
            var run = 0
            var index = rounds.count - 1
            while index >= 0, rounds[index].by == .owner, rounds[index].answer == .refused || rounds[index].answer == .noReply {
                run += 1
                index -= 1
            }
            if run > rules.stepsDownAtMost { return suggestion(.nothingLower(.clubTurnedDownThree)) }
            let bestBid = zip(rounds, sales).filter { $0.0.by == .club }.map { $0.1.total }.max() ?? 0
            let lowered = rounded((1 - rules.stepDown) * Double(lastTerms.total), rules: rules)
            let total = min(ask, max(lowered, bestBid))
            notes.append(.steppedDown)
            return try sale(total: total, club: club, subject: subject, rules: rules, notes: notes, basis: basis)
        }
    }

    /// A first proposal or a step down: money now capped at the club's budget and rounded down, the rest later.
    private static func sale(total: Int, club: ClubFigures, subject: OfferSubject, rules: OfferRules, notes start: [OfferNote],
                             basis: Evidence) throws -> OfferSuggestion {
        guard let budget = club.transferBudget else { throw OfferError.missing(.transferBudget, club: club.name) }
        if budget < 0 { throw OfferError.negative(.transferBudget) }
        let now = min(rounded(Double(min(total, budget)), down: true, rules: rules), budget)
        let later = total - now
        var notes = start
        if budget == 0 && total > 0 {
            notes.append(.nothingToSpendNow)
        } else if later > 0 {
            notes.append(.restAskedLater(now: now))
        }
        if let left = club.wageLeftPerWeek, left < subject.wagePerWeek { notes.append(.wageLeftUnderHisWage(left: left)) }
        if let highest = club.highestWagePerWeek, highest < subject.wagePerWeek {
            notes.append(.highestWageUnderHisWage(highest: highest))
        }
        var split: SaleSplit?
        if later > 0 {
            let instalments = rounded(rules.laterInInstalments * Double(later), rules: rules)
            split = SaleSplit(instalments: instalments, afterAppearances: later - instalments)
        }
        return OfferSuggestion(
            advice: .propose(.sale(SaleTerms(now: now, later: later, nextFeePercent: rules.nextFeePercent)), split: split),
            notes: notes, basis: basis)
    }

    private static func requireUsable(_ parameters: EngineParameters) throws {
        let problems = FitnessModel.problems(in: parameters)
        guard problems.isEmpty else { throw PlanError.badParameters(problems) }
    }

    /// True when the club has already answered a counter of the owner's: a club round, then an owner round, before the
    /// last round.
    private static func alreadyCountered(_ rounds: [OfferRound]) -> Bool {
        var seenClub = false
        for round in rounds.dropLast() {
            if round.by == .club { seenClub = true } else if seenClub { return true }
        }
        return false
    }

    // MARK: Loans

    /// Far below the 1/100 a whole percentage resolves to; absorbs binary floating-point error before rounding down.
    private static let shareNoise = 1e-9

    /// The share of his wage a loan asks, the club's limit that set it, and the fee a month.
    private struct LoanFigures {
        var percent: Int
        var limit: ShareLimit?
        var fee: Int
    }

    private static func checkLoanSubject(_ subject: OfferSubject) throws {
        if subject.value < 0 { throw OfferError.negative(.value) }
        if subject.wagePerWeek < 0 { throw OfferError.negative(.wage) }
    }

    /// The share, its limit and the fee for the loan of this player, to a club (its wage left and highest wage cap
    /// the share and the fee) or, with no club, to clubs in general.
    private static func loanFigures(_ subject: OfferSubject, club: ClubFigures?, rules: OfferRules) throws -> LoanFigures {
        let tau = rules.loanLinePerWeek * Double(subject.value)
        let wage = subject.wagePerWeek
        var left: Double?
        var highest: Double?
        if let club {
            guard let budget = club.wageBudgetPerWeek else { throw OfferError.missing(.wageBudget, club: club.name) }
            guard let spent = club.wagesSpentPerWeek else { throw OfferError.missing(.wagesSpent, club: club.name) }
            if budget < 0 { throw OfferError.negative(.wageBudget) }
            if spent < 0 { throw OfferError.negative(.wagesSpent) }
            left = max(0, budget - spent)
            if let figure = club.highestWagePerWeek {
                if figure < 0 { throw OfferError.negative(.highestWage) }
                highest = figure
            }
        }
        let bears = min(tau, left ?? tau)
        func fee(atWholeWage whole: Bool) -> Int {
            guard whole else { return 0 }
            return rounded(Double(rules.weeksPerMonthInRule) * (bears - wage), rules: rules)
        }
        guard wage > 0 else { return LoanFigures(percent: 0, limit: nil, fee: fee(atWholeWage: true)) }
        var best: (share: Double, limit: ShareLimit) = (tau / wage, .value)
        if let left, left / wage < best.share { best = (left / wage, .wageLeft(left)) }
        if let highest, highest / wage < best.share { best = (highest / wage, .highestWage(highest)) }
        let whole = best.share * 100 + shareNoise >= 100
        if whole { return LoanFigures(percent: 100, limit: .all, fee: fee(atWholeWage: true)) }
        let steps = Int((best.share * 100 / Double(rules.wageStepPercent) + shareNoise).rounded(.down))
        return LoanFigures(percent: steps * rules.wageStepPercent, limit: best.limit, fee: 0)
    }

    private static func loanTerms(percent: Int, fee: Int, purpose: LoanPurpose) -> LoanTerms {
        let time: PlayingTime? = switch purpose {
        case .development: .startingPlace
        case .wage: nil
        }
        return LoanTerms(wagePercent: percent, feePerMonth: fee, playingTime: time, recall: true, futureFee: nil)
    }

    /// The loan's own notes, in order: the limit, the recall with a fee, the fee that may be offered to buy him, and
    /// that clubs in general are open.
    private static func loanNotes(_ terms: LoanTerms, limit: ShareLimit?, subject: OfferSubject, openToClubs: Bool,
                                  rules: OfferRules) -> [OfferNote] {
        var notes: [OfferNote] = []
        if let limit { notes.append(.shareLimitedBy(limit)) }
        if terms.feePerMonth > 0 && terms.recall { notes.append(.recallWithFee) }
        switch subject.purpose {
        case .development: break
        case .wage:
            let future = rounded(rules.saleLine * Double(subject.value), rules: rules)
            if future > 0 { notes.append(.optionalFutureFee(future)) }
        }
        if openToClubs { notes.append(.clubsOpenLow) }
        return notes
    }

    /// One step down from what the owner last recorded: the fee first, then a step of the share; never above the
    /// present suggestion. Nil when there is nothing lower: no share and no fee.
    private static func steppedDown(from last: LoanTerms, suggested: LoanTerms, rules: OfferRules) -> LoanTerms? {
        if last.wagePercent == 0 && last.feePerMonth == 0 { return nil }
        let share = last.feePerMonth > 0 ? last.wagePercent : max(0, last.wagePercent - rules.wageStepPercent)
        var terms = suggested
        terms.wagePercent = min(share, suggested.wagePercent)
        terms.feePerMonth = 0
        return terms
    }

    private static func loanTerms(of terms: OfferTerms) throws -> LoanTerms {
        guard case .loan(let t) = terms else { throw OfferError.wrongKind }
        return t
    }

    private static func loanAsk(_ subject: OfferSubject, earlier: [OfferAsk], rules: OfferRules,
                                parameters: EngineParameters) throws -> OfferSuggestion {
        try checkLoanSubject(subject)
        let basis = parameters.offerRules.evidence
        let earlierTerms = try earlier.map { try loanTerms(of: $0.terms) }
        var notes: [OfferNote] = []
        if subject.value == 0 { notes.append(.valueIsZero) }
        let figures = try loanFigures(subject, club: nil, rules: rules)
        let suggested = loanTerms(percent: figures.percent, fee: figures.fee, purpose: subject.purpose)
        func propose(_ terms: LoanTerms, limit: ShareLimit?, extra: [OfferNote] = []) -> OfferSuggestion {
            OfferSuggestion(advice: .propose(.loan(terms), split: nil),
                            notes: notes + extra + loanNotes(terms, limit: limit, subject: subject, openToClubs: true, rules: rules),
                            basis: basis)
        }
        if let latest = earlier.last, latest.noBidCame, let last = earlierTerms.last {
            let run = earlier.reversed().prefix(while: { $0.noBidCame }).count
            if run > rules.stepsDownAtMost {
                return OfferSuggestion(advice: .nothingLower(.noBidThree), notes: notes, basis: basis)
            }
            guard let lowered = steppedDown(from: last, suggested: suggested, rules: rules) else {
                return propose(last, limit: nil)
            }
            return propose(lowered, limit: nil, extra: [.steppedDown])
        }
        return propose(suggested, limit: figures.limit)
    }

    private static func loanProposal(_ subject: OfferSubject, club: ClubFigures, rounds: [OfferRound], rules: OfferRules,
                                     parameters: EngineParameters) throws -> OfferSuggestion {
        try checkLoanSubject(subject)
        let basis = parameters.offerRules.evidence
        var notes: [OfferNote] = []
        if subject.value == 0 { notes.append(.valueIsZero) }
        func suggestion(_ advice: OfferAdvice, extra: [OfferNote] = []) -> OfferSuggestion {
            OfferSuggestion(advice: advice, notes: notes + extra, basis: basis)
        }
        let loans = try rounds.map { try loanTerms(of: $0.terms) }
        guard let last = rounds.last, let lastTerms = loans.last else {
            let figures = try loanFigures(subject, club: club, rules: rules)
            let terms = loanTerms(percent: figures.percent, fee: figures.fee, purpose: subject.purpose)
            return suggestion(.propose(.loan(terms), split: nil),
                              extra: loanNotes(terms, limit: figures.limit, subject: subject, openToClubs: false, rules: rules))
        }
        switch last.by {
        case .club:
            switch subject.purpose {
            case .development:
                if lastTerms.playingTime == .startingPlace { return suggestion(.accept) }
                if alreadyCountered(rounds) { return suggestion(.acceptOrLeave) }
                return suggestion(.counter(.loan(loanTerms(percent: lastTerms.wagePercent, fee: lastTerms.feePerMonth,
                                                           purpose: .development))))
            case .wage:
                let figures = try loanFigures(subject, club: club, rules: rules)
                if lastTerms.wagePercent >= figures.percent { return suggestion(.accept) }
                if alreadyCountered(rounds) { return suggestion(.acceptOrLeave) }
                let share = min(figures.percent, lastTerms.wagePercent + rules.wageStepPercent)
                return suggestion(.counter(.loan(loanTerms(percent: share, fee: lastTerms.feePerMonth, purpose: .wage))))
            }
        case .owner:
            switch last.answer {
            case nil: return suggestion(.awaitAnswer)
            case .accepted?: return suggestion(.accept)
            case .refused?, .noReply?: break
            }
            let figures = try loanFigures(subject, club: club, rules: rules)
            let suggested = loanTerms(percent: figures.percent, fee: figures.fee, purpose: subject.purpose)
            guard let lowered = steppedDown(from: lastTerms, suggested: suggested, rules: rules) else {
                return suggestion(.nothingLower(.clubDoesNotWantHim))
            }
            return suggestion(.propose(.loan(lowered), split: nil),
                              extra: [.steppedDown] + loanNotes(lowered, limit: nil, subject: subject, openToClubs: false, rules: rules))
        }
    }
}
