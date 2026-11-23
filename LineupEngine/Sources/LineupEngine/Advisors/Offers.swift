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
        guard kind == .sale else { throw OfferError.wrongKind }
        if subject.value < 0 { throw OfferError.negative(.value) }
        let rules = parameters.offerRules.value
        let total = rounded(rules.saleLine * Double(subject.value), rules: rules)
        var notes: [OfferNote] = []
        if subject.value == 0 { notes.append(.valueIsZero) }
        var terms = SaleTerms(now: total, later: 0, nextFeePercent: rules.nextFeePercent)
        if let latest = earlier.last, latest.noBidCame {
            var sales: [SaleTerms] = []
            for item in earlier {
                guard case .sale(let t) = item.terms else { throw OfferError.wrongKind }
                sales.append(t)
            }
            let run = earlier.reversed().prefix(while: { $0.noBidCame }).count
            if run > rules.stepsDownAtMost {
                return OfferSuggestion(advice: .nothingLower(.noBidThree), notes: notes, basis: parameters.offerRules.evidence)
            }
            let lowered = rounded((1 - rules.stepDown) * Double(sales[sales.count - 1].total), rules: rules)
            terms.now = min(total, lowered)
            notes.append(.steppedDown)
        } else if let first = earlier.first {
            guard case .sale(let t) = first.terms else { throw OfferError.wrongKind }
            terms = t
        }
        notes += [.doNotList, .noInterestBids]
        return OfferSuggestion(advice: .propose(.sale(terms), split: nil), notes: notes, basis: parameters.offerRules.evidence)
    }

    /// The terms to propose to a named club, or what to answer to its bid.
    public static func proposal(_ subject: OfferSubject, kind: OfferKind, club: ClubFigures, rounds: [OfferRound],
                                measures: OfferMeasures = .none, parameters: EngineParameters) throws -> OfferSuggestion {
        try requireUsable(parameters)
        guard kind == .sale else { throw OfferError.wrongKind }
        if subject.value < 0 { throw OfferError.negative(.value) }
        let rules = parameters.offerRules.value
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
            var seenClub = false
            for round in rounds.dropLast() {
                if round.by == .club { seenClub = true } else if seenClub { return suggestion(.acceptOrLeave) }
            }
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
}
