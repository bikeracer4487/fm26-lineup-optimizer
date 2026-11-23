import Foundation

extension OfferTerms {
    /// What these terms are worth against his value: a sale's total over his value; a loan's wage the borrower bears a
    /// week plus the fee spread over the weeks of a month in the rule, over his value. Nil when the value is 0.
    public func ratio(value: Int, wagePerWeek: Double, rules: OfferRules) -> Double? {
        guard value > 0 else { return nil }
        let amount: Double
        switch self {
        case .sale(let t):
            amount = Double(t.total)
        case .loan(let t):
            amount = Double(t.wagePercent) / 100 * wagePerWeek + Double(t.feePerMonth) / Double(rules.weeksPerMonthInRule)
        }
        let result = amount / Double(value)
        return result.isFinite ? result : nil
    }
}

extension Offers {
    /// What the recorded deals and asks show of the line clubs pay or turn down, and of how far a club's counter comes up.
    /// Only what is dated on or after `from` is read (all of it when nil). The same record in any order gives the same
    /// measures: every median sorts its figures first.
    public static func measures(asks: [OfferAsk], deals: [OfferDeal], from: Day?, parameters: EngineParameters) -> OfferMeasures {
        let rules = parameters.offerRules.value
        func inWindow(_ day: Day) -> Bool { from.map { day >= $0 } ?? true }
        let windowed: [(deal: OfferDeal, rounds: [OfferRound])] = deals.compactMap { deal in
            let rounds = deal.rounds.filter { inWindow($0.day) }
            return rounds.isEmpty ? nil : (deal, rounds)
        }
        let askList = asks.filter { inWindow($0.day) }

        func reading(of kind: OfferKind) -> OfferLineReading {
            let kindDeals = windowed.filter { $0.deal.kind == kind }
            let kindAsks = askList.filter { $0.kind == kind }
            func ratio(_ round: OfferRound) -> Double? {
                guard round.terms.kind == kind else { return nil }
                return round.terms.ratio(value: round.value, wagePerWeek: round.wagePerWeek, rules: rules)
            }
            var paid: [Double] = []
            var turnedDown: [Double] = []
            var agreed = 0
            for (_, rounds) in kindDeals {
                if rounds.contains(where: { $0.answer == .accepted }) { agreed += 1 }
                var paidHere: [Double] = []
                var downHere: [Double] = []
                for (index, round) in rounds.enumerated() {
                    guard let r = ratio(round) else { continue }
                    switch round.by {
                    case .club:
                        paidHere.append(r)
                    case .owner:
                        switch round.answer {
                        case .accepted?: paidHere.append(r)
                        case .refused?: downHere.append(r)
                        case .noReply?: break
                        case nil:
                            if index + 1 < rounds.count, rounds[index + 1].by == .club,
                               let reply = ratio(rounds[index + 1]), reply < r {
                                downHere.append(r)
                            }
                        }
                    }
                }
                if let best = paidHere.max() { paid.append(best) }
                if let worst = downHere.min() { turnedDown.append(worst) }
            }
            // An ask is turned down when a later first bid from a club, before the player's next ask, was lower.
            for ask in kindAsks {
                guard let r = ask.terms.kind == kind
                    ? ask.terms.ratio(value: ask.value, wagePerWeek: ask.wagePerWeek, rules: rules) : nil else { continue }
                let next = kindAsks.filter { $0.player == ask.player && $0.day > ask.day }.map(\.day).min()
                let lower = kindDeals.contains { entry in
                    guard entry.deal.player == ask.player,
                          let first = entry.rounds.first, first.by == .club,
                          first.day >= ask.day, next.map({ first.day < $0 }) ?? true,
                          let bid = ratio(first) else { return false }
                    return bid < r
                }
                if lower { turnedDown.append(r) }
            }
            let days = kindDeals.flatMap { $0.rounds.map(\.day) } + kindAsks.map(\.day)
            let medianPaid = median(paid)
            let medianDown = median(turnedDown)
            var line: Double?
            if paid.count >= rules.fewestEachWay, turnedDown.count >= rules.fewestEachWay,
               let a = medianPaid, let b = medianDown, a < b {
                line = (a + b) / 2
            }
            return OfferLineReading(deals: kindDeals.count, agreed: agreed, paid: paid.count, turnedDown: turnedDown.count,
                                    medianPaid: medianPaid, medianTurnedDown: medianDown, line: line, since: days.min())
        }

        var steps: [Double] = []
        for (deal, rounds) in windowed where deal.kind == .sale {
            guard let first = rounds.firstIndex(where: { $0.by == .club }),
                  let accepted = rounds.firstIndex(where: { $0.answer == .accepted }), accepted > first,
                  rounds[(first + 1)...accepted].contains(where: { $0.by == .owner }),
                  case .sale(let bid) = rounds[first].terms, case .sale(let final) = rounds[accepted].terms,
                  bid.total > 0 else { continue }
            steps.append(Double(final.total) / Double(bid.total))
        }
        return OfferMeasures(sale: reading(of: .sale), loan: reading(of: .loan), counterDeals: steps.count,
                             counterStep: steps.count >= rules.fewestCounterDeals ? median(steps) : nil, measuredFrom: from)
    }

    /// The median: the figures sorted by value, the mean of the middle two for an even count; nil with none.
    private static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
    }
}
