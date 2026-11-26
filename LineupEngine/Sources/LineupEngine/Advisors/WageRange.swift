import Foundation

/// The numbers behind the wage range (`WageRange`). Every share is of the club's wage budget. See
/// `EngineParameters.wageRangeRules`.
public struct WageRangeRules: Equatable, Sendable {
    /// Months left at or under which a contract is in its last year.
    public var lastYearMonths: Int
    /// Months left at or under which the game lets the club approach a player for a new contract.
    public var approachMonths: Int
    /// The most a key player is taken to be paid, as a share of the wage budget.
    public var keyPlayerShare: Double
    /// The same for a starter.
    public var starterShare: Double
    /// The same for a backup.
    public var backupShare: Double
    /// The fewest wages a tier needs before its own range is given.
    public var fewestWages: Int
}

/// Where a player stands for his wage: the first eleven, the second, or neither.
public enum WageTier: String, CaseIterable, Sendable { case firstEleven, secondEleven, neither }

/// The club's three figures, by the week; nil when not entered.
public struct WageLimits: Equatable, Codable, Sendable {
    public var wageBudgetPerWeek: Double?
    public var wagesSpentPerWeek: Double?
    public var highestWagePerWeek: Double?

    public init(wageBudgetPerWeek: Double? = nil, wagesSpentPerWeek: Double? = nil, highestWagePerWeek: Double? = nil) {
        self.wageBudgetPerWeek = wageBudgetPerWeek
        self.wagesSpentPerWeek = wagesSpentPerWeek
        self.highestWagePerWeek = highestWagePerWeek
    }

    public static let none = WageLimits()
}

public struct PlayerWage: Equatable, Sendable {
    public let player: PlayerID
    public let perWeek: Double

    public init(player: PlayerID, perWeek: Double) { self.player = player; self.perWeek = perWeek }
}

/// What a tier is paid: the lower quartile and the highest of its wages, and how many there are.
public struct PaidRange: Equatable, Sendable {
    public let lowerQuartile: Double
    public let highest: Double
    public let count: Int

    public init(lowerQuartile: Double, highest: Double, count: Int) {
        self.lowerQuartile = lowerQuartile; self.highest = highest; self.count = count
    }
}

/// What set the top of a range.
public enum WageCap: Equatable, Sendable { case tierHighest, ceiling, highestWage }

public enum WageShown: Equatable, Sendable {
    case range(low: Double, high: Double, setBy: WageCap)
    case upTo(Double, setBy: WageCap)
    case none
}

public struct WageGuide: Equatable, Sendable {
    public let tier: WageTier
    public let slot: SlotID?
    /// `excluding` was one of the tier's wages, so the range is without him.
    public let leavesHimOut: Bool
    public let paid: PaidRange?
    public let ceilingPerWeek: Double?
    /// The first eleven only.
    public let starterSharePerWeek: Double?
    public let highestWagePerWeek: Double?
    public let budgetLeftPerWeek: Double?
    /// A present wage above 0 was added to the budget left.
    public let countsHisWageBack: Bool
    public let shown: WageShown
    public let basis: Evidence
}

public enum WageVerdict: Equatable, Sendable {
    case overHighestWage(limit: Double)
    case overCeiling(ceiling: Double)
    case aboveTier(highest: Double)
    case withinTier
    case underTier
    case overBudgetLeft(by: Double)
    case timesPresentWage(Double)
}

/// A range of wages to look at for a player, from what his tier is paid and the club's limits. A function of the data
/// it is handed. The research found no formula for what a player asks, so the range is the squad's own.
public enum WageRange {
    private static let noise = 1e-6

    /// A share of the budget, rounded to a millionth so that 20,000 × 0.043 is 860 and not 859.9999999999999.
    private static func share(of budget: Double, _ share: Double) -> Double { (budget * share * 1e6).rounded() / 1e6 }

    /// What is wrong with the rules, in plain words; empty when they can be used.
    static func problems(in rules: WageRangeRules) -> [String] {
        var found: [String] = []
        for (name, months) in [("lastYearMonths", rules.lastYearMonths), ("approachMonths", rules.approachMonths)] where months < 1 {
            found.append("wageRangeRules \(name) is \(months), not 1 or more")
        }
        if rules.approachMonths > rules.lastYearMonths {
            found.append("wageRangeRules approachMonths is \(rules.approachMonths), more than lastYearMonths, \(rules.lastYearMonths)")
        }
        for (name, share) in [("keyPlayerShare", rules.keyPlayerShare), ("starterShare", rules.starterShare),
                              ("backupShare", rules.backupShare)] where !(share.isFinite && share > 0 && share <= 1) {
            found.append("wageRangeRules \(name) is \(share), not a number above 0 and at most 1")
        }
        if rules.backupShare > rules.starterShare {
            found.append("wageRangeRules backupShare is \(rules.backupShare), more than starterShare, \(rules.starterShare)")
        }
        if rules.starterShare > rules.keyPlayerShare {
            found.append("wageRangeRules starterShare is \(rules.starterShare), more than keyPlayerShare, \(rules.keyPlayerShare)")
        }
        if rules.fewestWages < 1 {
            found.append("wageRangeRules fewestWages is \(rules.fewestWages), not 1 or more")
        }
        return found
    }

    /// The wages of the club's own players the tiers rate, with a wage above 0 and not on a youth contract, by tier;
    /// each list sorted by wage then key. Every tier has an entry.
    public static func tierWages(tiers: SquadTiers, players: [Player], ownClub: String?) -> [WageTier: [PlayerWage]] {
        var result: [WageTier: [PlayerWage]] = Dictionary(uniqueKeysWithValues: WageTier.allCases.map { ($0, []) })
        for player in players {
            guard case .own = LoanStatus.of(player, ownClub: ownClub), player.wagePerWeek > 0,
                  !Removal.isOnYouthContract(player), let found = tier(of: player.id, in: tiers) else { continue }
            result[found.tier, default: []].append(PlayerWage(player: player.id, perWeek: player.wagePerWeek))
        }
        return result.mapValues { list in
            list.sorted { ($0.perWeek, $0.player.key) < ($1.perWeek, $1.player.key) }
        }
    }

    /// His tier and, for a first or second choice, his slot; nil when the tiers did not rate him.
    public static func tier(of player: PlayerID, in tiers: SquadTiers) -> (tier: WageTier, slot: SlotID?)? {
        switch tiers.tier(of: player) {
        case .first(let slot): return (.firstEleven, slot)
        case .second(let slot): return (.secondEleven, slot)
        case .backup: return (.neither, nil)
        case nil: return nil
        }
    }

    public static func tier(of level: CandidateLevel) -> WageTier {
        switch level {
        case .wouldStart: .firstEleven
        case .wouldMakeSecond: .secondEleven
        case .wouldCountAsCover, .belowCover: .neither
        }
    }

    /// The best level in `CandidateLevel`'s order, then the greatest margin (nil above every number), then the earliest.
    public static func bestLevel(_ slots: [(slot: SlotID, level: CandidateLevel, margin: Double?)])
        -> (slot: SlotID, level: CandidateLevel)? {
        let order = CandidateLevel.allCases
        var best: (slot: SlotID, level: CandidateLevel, margin: Double?)?
        for entry in slots {
            guard let current = best else { best = entry; continue }
            let rank = order.firstIndex(of: entry.level)!, currentRank = order.firstIndex(of: current.level)!
            if rank < currentRank { best = entry; continue }
            if rank > currentRank { continue }
            if current.margin == nil { continue }
            if let margin = entry.margin, margin <= current.margin! { continue }
            best = entry
        }
        return best.map { ($0.slot, $0.level) }
    }

    public static func guide(tier: WageTier, slot: SlotID?, wages: [WageTier: [PlayerWage]], excluding: PlayerID?,
                             presentWagePerWeek: Double?, limits: WageLimits,
                             parameters: EngineParameters) throws -> WageGuide {
        let problems = FitnessModel.problems(in: parameters)
        guard problems.isEmpty else { throw PlanError.badParameters(problems) }
        let rules = parameters.wageRangeRules.value
        let all = wages[tier] ?? []
        let leavesHimOut = excluding.map { id in all.contains { $0.player == id } } ?? false
        let values = all.filter { $0.player != excluding }.map(\.perWeek).sorted()

        var paid: PaidRange?
        if values.count >= rules.fewestWages, let highest = values.last {
            let lower = Array(values.prefix(values.count / 2))
            let middle = lower.count / 2
            let quartile = lower.count % 2 == 1 ? lower[middle] : (lower[middle - 1] + lower[middle]) / 2
            paid = PaidRange(lowerQuartile: quartile, highest: highest, count: values.count)
        }

        let ceiling = limits.wageBudgetPerWeek.map { share(of: $0, tier == .firstEleven ? rules.keyPlayerShare : rules.backupShare) }
        let starterShare = tier == .firstEleven ? limits.wageBudgetPerWeek.map { share(of: $0, rules.starterShare) } : nil
        var budgetLeft: Double?
        var countsBack = false
        if let budget = limits.wageBudgetPerWeek, let spent = limits.wagesSpentPerWeek {
            let present = presentWagePerWeek ?? 0
            budgetLeft = max(0, budget - spent + present)
            countsBack = present > 0
        }

        let shown: WageShown
        if let paid {
            var top = (paid.highest, WageCap.tierHighest)
            if let ceiling, ceiling < top.0 { top = (ceiling, .ceiling) }
            if let highestWage = limits.highestWagePerWeek, highestWage < top.0 { top = (highestWage, .highestWage) }
            shown = top.0 >= paid.lowerQuartile ? .range(low: paid.lowerQuartile, high: top.0, setBy: top.1)
                                                : .upTo(top.0, setBy: top.1)
        } else if let ceiling {
            if let highestWage = limits.highestWagePerWeek, highestWage < ceiling {
                shown = .upTo(highestWage, setBy: .highestWage)
            } else {
                shown = .upTo(ceiling, setBy: .ceiling)
            }
        } else {
            shown = .none
        }

        let evidence = parameters.wageRangeRules.evidence
        return WageGuide(tier: tier, slot: slot, leavesHimOut: leavesHimOut, paid: paid, ceilingPerWeek: ceiling,
                         starterSharePerWeek: starterShare, highestWagePerWeek: limits.highestWagePerWeek,
                         budgetLeftPerWeek: budgetLeft, countsHisWageBack: countsBack, shown: shown, basis: evidence)
    }

    public static func verdict(figurePerWeek: Double, guide: WageGuide, presentWagePerWeek: Double?) -> [WageVerdict] {
        var found: [WageVerdict] = []
        if let limit = guide.highestWagePerWeek, figurePerWeek > limit + noise { found.append(.overHighestWage(limit: limit)) }
        if let ceiling = guide.ceilingPerWeek, figurePerWeek > ceiling + noise { found.append(.overCeiling(ceiling: ceiling)) }
        if let paid = guide.paid {
            if figurePerWeek > paid.highest + noise { found.append(.aboveTier(highest: paid.highest)) }
            else if figurePerWeek < paid.lowerQuartile - noise { found.append(.underTier) }
            else { found.append(.withinTier) }
        }
        if let left = guide.budgetLeftPerWeek, figurePerWeek > left + noise { found.append(.overBudgetLeft(by: figurePerWeek - left)) }
        if let present = presentWagePerWeek, present > 0 { found.append(.timesPresentWage(figurePerWeek / present)) }
        return found
    }

    /// The first verdict that says the figure is over a limit or above what the tier is paid.
    public static func caution(in verdicts: [WageVerdict]) -> WageVerdict? {
        verdicts.first { verdict in
            switch verdict {
            case .overHighestWage, .overCeiling, .aboveTier: true
            case .withinTier, .underTier, .overBudgetLeft, .timesPresentWage: false
            }
        }
    }
}
