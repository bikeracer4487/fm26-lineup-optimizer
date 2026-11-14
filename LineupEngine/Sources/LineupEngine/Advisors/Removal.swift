import Foundation

/// How strongly a player of the club's own should be moved on, strongest first.
public enum RemovalLevel: String, CaseIterable, Sendable { case critical, high, medium, keep }

/// What to do with a player of the club's own.
public enum RemovalAction: String, CaseIterable, Sendable { case release, loan, terminate, sell, monitor, keep }

/// One rule that applied, and the points it gave; points may be negative.
public struct RemovalReason: Equatable, Sendable {
    public let text: String
    public let points: Int

    public init(text: String, points: Int) {
        self.text = text
        self.points = points
    }
}

/// Whether to sell, loan out, release or keep one player of the club's own, and why.
public struct RemovalAdvice: Equatable, Sendable {
    public let player: PlayerID
    public let name: String
    public let level: RemovalLevel
    public let action: RemovalAction
    /// The sum of the reasons' points.
    public let score: Int
    /// In the order of the rules.
    public let reasons: [RemovalReason]
    public let tier: SquadTier?
    public let isProspect: Bool
    public let isFalseProspect: Bool
    public let isMentor: Bool
    /// Wages left on the contract, in pounds: nil when months left is unknown, 0 for a player not on a full-time contract.
    public let releaseCost: Int?
    /// The likely cost of a mutual termination, in pounds; nil and 0 as `releaseCost`.
    public let mutualCost: Int?
    /// The weakest evidence among the parameters behind this advice.
    public let basis: Evidence
}

/// What to do about a loan to the club.
public enum LoanVerdict: String, CaseIterable, Sendable { case endEarly, doNotExtend, keepToEnd, makePermanent }

/// The review of one player on loan at the club.
public struct LoanReview: Equatable, Sendable {
    public let player: PlayerID
    public let name: String
    public let verdict: LoanVerdict
    public let score: Int
    public let reasons: [RemovalReason]
    public let basis: Evidence
}

public struct RemovalReport: Equatable, Sendable {
    /// Players of the club's own: highest score first, then key.
    public let advice: [RemovalAdvice]
    /// Players on loan at the club: highest score first, then key.
    public let loans: [LoanReview]
    /// The weekly wages of the critical and high players.
    public let weeklyWagesAtStake: Int
    /// Mean current ability of the club's own players; nil when there are none.
    public let squadAverageAbility: Double?
}

public enum Removal {
    private static let weeksPerYear = 52.0
    private static let monthsPerYear = 12.0
    /// Absorbs binary floating-point error (0.3 × 10 may fall just short of 3) before a count is rounded down.
    private static let roundingNoise = 1e-9

    /// Advice for every player of the club's own and a review of every player on loan at the club; players out on loan
    /// get neither, and injured players are assessed. The squad average ability and the median wage are over the club's
    /// own players. Throws `PlanError.badParameters` when `FitnessModel.problems(in:)` finds problems, what
    /// `Elevens.report` throws, and `RatingError.missingAttribute` for an assessed player without Consistency, Important
    /// Matches, Injury Proneness, Professionalism, Ambition, Controversy, Temperament or Determination.
    public static func report(tactic: Tactic, players: [Player], ownClub: String?, catalog: RoleCatalog,
                              profile: RatingProfile, parameters: EngineParameters) throws -> RemovalReport {
        let problems = FitnessModel.problems(in: parameters)
        guard problems.isEmpty else { throw PlanError.badParameters(problems) }
        let tiers = try Elevens.report(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                                       profile: profile, parameters: parameters).tiers

        // Sorting by key makes every list, and the first error, independent of input order.
        var own: [Player] = []
        var loanedIn: [Player] = []
        var traits: [PlayerID: Traits] = [:]
        for player in players.sorted(by: { $0.id.key < $1.id.key }) {
            switch LoanStatus.of(player, ownClub: ownClub) {
            case .own: own.append(player)
            case .loanedIn: loanedIn.append(player)
            case .loanedOut: continue
            }
            traits[player.id] = try Traits(player)
        }

        let squad = SquadFacts(
            averageAbility: own.isEmpty ? nil : Double(own.map(\.currentAbility).reduce(0, +)) / Double(own.count),
            medianWage: median(own.map(\.wagePerWeek)),
            weakest: weakest(own + loanedIn, tiers: tiers, share: parameters.removalRules.value.weakestShare),
            tiers: tiers)

        var advice: [RemovalAdvice] = []
        var wagesAtStake = 0
        for player in own {
            let one = Self.advice(for: player, traits: traits[player.id]!, squad: squad, parameters: parameters)
            switch one.level {
            case .critical, .high: wagesAtStake += player.wagePerWeek
            case .medium, .keep: break
            }
            advice.append(one)
        }
        let loans = loanedIn.map { review(of: $0, traits: traits[$0.id]!, squad: squad, parameters: parameters) }

        return RemovalReport(
            advice: advice.sorted { $0.score != $1.score ? $0.score > $1.score : $0.player.key < $1.player.key },
            loans: loans.sorted { $0.score != $1.score ? $0.score > $1.score : $0.player.key < $1.player.key },
            weeklyWagesAtStake: wagesAtStake, squadAverageAbility: squad.averageAbility)
    }

    // MARK: Players of the club's own

    private static func advice(for player: Player, traits: Traits, squad: SquadFacts,
                               parameters: EngineParameters) -> RemovalAdvice {
        let rules = parameters.removalRules.value
        var reasons = Reasons()
        var evidence = [parameters.removalRules.evidence, parameters.removalLevels.evidence]

        let notFullTime = switch player.contractType {
        case .fullTime: false
        case .outOfContract, .other: true
        }
        if notFullTime { reasons.add(rules.notFullTimePoints, "Not on a full-time contract") }

        let tier = squad.tiers.tier(of: player.id)
        let inEither = reasons.addTier(tier, first: rules.firstElevenPoints, second: rules.secondElevenPoints,
                                       neither: rules.neitherElevenPoints)
        if squad.weakest.contains(player.id) { reasons.add(rules.weakestPoints, weakestReason(rules)) }
        reasons.addAbility(player, squad: squad, share: rules.farBelowAverageShare,
                           farBelow: rules.farBelowAveragePoints, below: rules.belowAveragePoints)

        let wageRules = parameters.removalWageRules.value
        if let median = squad.medianWage, median > 0, !inEither {
            let wage = Double(player.wagePerWeek)
            let points: Int? = wage > wageRules.highMultiple * median ? wageRules.highPoints
                : wage > median ? wageRules.abovePoints : nil
            if let points {
                reasons.add(points, "Paid \(Display.perWeek(player.wagePerWeek)), against a median of "
                            + "\(Display.pounds(Int(median.rounded()))), and in neither eleven")
                evidence.append(parameters.removalWageRules.evidence)
            }
        }

        if let months = player.monthsLeft, months > 0 {
            let points: Int? = months <= rules.contractEndingSoonUpTo ? rules.contractEndingSoonPoints
                : months <= rules.contractEndingUpTo ? rules.contractEndingPoints : nil
            if let points { reasons.add(points, "Contract ends in \(months) \(months == 1 ? "month" : "months")") }
        }

        if traits.consistency < rules.consistencyLowBelow {
            reasons.add(rules.consistencyLowPoints, "Consistency \(traits.consistency)")
        } else if traits.consistency <= rules.consistencyFairUpTo {
            reasons.add(rules.consistencyFairPoints, "Consistency \(traits.consistency)")
        }
        if traits.importantMatches < rules.importantMatchesBelow {
            reasons.add(rules.importantMatchesPoints, "Important Matches \(traits.importantMatches)")
        }
        if traits.injuryProneness > rules.injuryPronenessAbove {
            reasons.add(rules.injuryPronenessPoints, "Injury Proneness \(traits.injuryProneness)")
        }
        if traits.professionalism < rules.professionalismLowBelow {
            reasons.add(rules.professionalismLowPoints, "Professionalism \(traits.professionalism)")
        } else if traits.professionalism <= rules.professionalismFairUpTo {
            reasons.add(rules.professionalismFairPoints, "Professionalism \(traits.professionalism)")
        }
        if traits.ambition < rules.ambitionBelow { reasons.add(rules.ambitionPoints, "Ambition \(traits.ambition)") }
        if traits.controversy > rules.controversyAbove {
            reasons.add(rules.controversyPoints, "Controversy \(traits.controversy)")
        }
        if traits.temperament < rules.temperamentBelow {
            reasons.add(rules.temperamentPoints, "Temperament \(traits.temperament)")
        }

        let age = player.age
        let gap = player.potentialAbility - player.currentAbility
        // A current ability of 0 gives no room to grow, and no rule that reads it.
        let room: Double? = player.currentAbility > 0 ? Double(gap) / Double(player.currentAbility) : nil

        // `FitnessModel.problems` keeps the target age above every false prospect's age, so the years left are above 0.
        var isFalseProspect = false
        if age <= rules.falseProspectUpToAge {
            let rate = Double(gap) / Double(rules.falseProspectTargetAge - age)
            if rate > rules.falseProspectRateAbove && traits.professionalism < rules.falseProspectProfessionalismBelow {
                isFalseProspect = true
                reasons.add(rules.falseProspectPoints, "Would need \(Int(rate.rounded())) ability points a year to reach his "
                            + "potential by \(rules.falseProspectTargetAge), with Professionalism \(traits.professionalism)")
            }
        }

        if let room, let average = squad.averageAbility, age >= rules.stallingFromAge, age <= rules.stallingUpToAge,
           Double(player.currentAbility) < average, room < rules.stallingRoomBelow {
            reasons.add(rules.stallingPoints, "Aged \(age) with little room to grow")
        }

        var isProspect = false
        if let room, age <= rules.prospectUpToAge {
            let points: Int? = room >= rules.strongProspectRoomFrom ? rules.strongProspectPoints
                : room >= rules.prospectRoomFrom ? rules.prospectPoints : nil
            if let points {
                isProspect = true
                reasons.add(points, "Aged \(age) with \(Display.percent(room)) room to grow")
            }
        }

        let isMentor = age >= rules.mentorFromAge && traits.professionalism >= rules.mentorProfessionalismFrom
        if isMentor {
            reasons.add(traits.determination >= rules.mentorDeterminationFrom ? rules.mentorPoints : rules.lesserMentorPoints,
                        "A model professional for younger players")
        }
        if let room, !isMentor, age >= rules.noGrowthFromAge, room < rules.noGrowthRoomBelow {
            reasons.add(rules.noGrowthPoints, "Aged \(age) with no room to grow")
        }
        if !isMentor, age >= rules.oldFromAge { reasons.add(rules.oldPoints, "Aged \(age)") }

        let score = reasons.score
        let levels = parameters.removalLevels.value
        let level: RemovalLevel = score >= levels.critical ? .critical
            : score >= levels.high ? .high
            : score >= levels.medium ? .medium : .keep

        let releaseCost: Int?
        let mutualCost: Int?
        if notFullTime {
            (releaseCost, mutualCost) = (0, 0)
        } else if let months = player.monthsLeft {
            let release = Int((Double(player.wagePerWeek) * weeksPerYear / monthsPerYear * Double(months)).rounded())
            (releaseCost, mutualCost) = (release, Int((parameters.mutualTerminationShare.value * Double(release)).rounded()))
        } else {
            (releaseCost, mutualCost) = (nil, nil)
        }
        if mutualCost != nil { evidence.append(parameters.mutualTerminationShare.evidence) }

        let action: RemovalAction
        switch level {
        case .keep: action = .keep
        case .medium: action = .monitor
        case .high, .critical:
            if notFullTime {
                action = .release
            } else if isProspect && !isFalseProspect {
                action = .loan
            } else if level == .critical, let months = player.monthsLeft, months <= rules.terminateWithinMonths,
                      let mutualCost, player.askingPrice.map({ $0 < mutualCost }) ?? true {
                action = .terminate
            } else {
                action = .sell
            }
        }

        return RemovalAdvice(player: player.id, name: player.name, level: level, action: action, score: score,
                             reasons: reasons.list, tier: tier, isProspect: isProspect, isFalseProspect: isFalseProspect,
                             isMentor: isMentor, releaseCost: releaseCost, mutualCost: mutualCost,
                             basis: Evidence.weakest(evidence)!)
    }

    // MARK: Players on loan here

    private static func review(of player: Player, traits: Traits, squad: SquadFacts,
                               parameters: EngineParameters) -> LoanReview {
        let rules = parameters.removalRules.value
        let loan = rules.loanReview
        var reasons = Reasons()
        if squad.weakest.contains(player.id) { reasons.add(loan.weakestPoints, weakestReason(rules)) }
        let inEither = reasons.addTier(squad.tiers.tier(of: player.id), first: loan.firstElevenPoints,
                                       second: loan.secondElevenPoints, neither: loan.neitherElevenPoints)
        reasons.addAbility(player, squad: squad, share: rules.farBelowAverageShare,
                           farBelow: loan.farBelowAveragePoints, below: loan.belowAveragePoints)
        if traits.consistency < rules.consistencyLowBelow {
            reasons.add(loan.consistencyLowPoints, "Consistency \(traits.consistency)")
        }
        if traits.importantMatches < rules.importantMatchesBelow {
            reasons.add(loan.importantMatchesPoints, "Important Matches \(traits.importantMatches)")
        }
        if traits.injuryProneness > rules.injuryPronenessAbove {
            reasons.add(loan.injuryPronenessPoints, "Injury Proneness \(traits.injuryProneness)")
        }

        let score = reasons.score
        let atLeastAverage = squad.averageAbility.map { Double(player.currentAbility) >= $0 } ?? false
        let verdict: LoanVerdict = score >= loan.endEarlyFrom ? .endEarly
            : score >= loan.doNotExtendFrom ? .doNotExtend
            : atLeastAverage && inEither ? .makePermanent : .keepToEnd
        return LoanReview(player: player.id, name: player.name, verdict: verdict, score: score, reasons: reasons.list,
                          basis: Evidence.weakest([parameters.removalRules.evidence])!)
    }

    // MARK: Shared

    private static func weakestReason(_ rules: RemovalRules) -> String {
        "Among the weakest \(Display.percent(rules.weakestShare)) of the squad for this tactic"
    }

    /// The attributes the rules read, each required.
    private struct Traits {
        let consistency, importantMatches, injuryProneness, professionalism: Int
        let ambition, controversy, temperament, determination: Int

        init(_ player: Player) throws {
            func value(_ attribute: Attribute) throws -> Int {
                guard let value = player.attributes[attribute] else {
                    throw RatingError.missingAttribute(player: player.name, attribute: attribute)
                }
                return value
            }
            consistency = try value(.consistency)
            importantMatches = try value(.importantMatches)
            injuryProneness = try value(.injuryProneness)
            professionalism = try value(.professionalism)
            ambition = try value(.ambition)
            controversy = try value(.controversy)
            temperament = try value(.temperament)
            determination = try value(.determination)
        }
    }

    private struct SquadFacts {
        let averageAbility: Double?
        /// nil when the club has no players of its own.
        let medianWage: Double?
        let weakest: Set<PlayerID>
        let tiers: SquadTiers
    }

    private struct Reasons {
        var list: [RemovalReason] = []
        var score: Int { list.map(\.points).reduce(0, +) }

        mutating func add(_ points: Int, _ text: String) { list.append(RemovalReason(text: text, points: points)) }

        /// Adds the points for his tier and says whether he is in either eleven.
        mutating func addTier(_ tier: SquadTier?, first: Int, second: Int, neither: Int) -> Bool {
            switch tier {
            case .first(let slot)?:
                add(first, "In the first eleven at \(slot.position.rawValue)")
                return true
            case .second(let slot)?:
                add(second, "In the second eleven at \(slot.position.rawValue)")
                return true
            case .backup?, nil:
                add(neither, "In neither eleven")
                return false
            }
        }

        /// Of the two ability lines only the stronger applies; neither does without a squad average.
        mutating func addAbility(_ player: Player, squad: SquadFacts, share: Double, farBelow: Int, below: Int) {
            guard let average = squad.averageAbility else { return }
            let ability = Double(player.currentAbility)
            let points: Int? = ability < share * average ? farBelow : ability < average ? below : nil
            if let points {
                add(points, "Current ability \(player.currentAbility) against a squad average of \(Int(average.rounded()))")
            }
        }
    }

    /// The players whose best slot rating is among the lowest `share` of `pool`, rounded down; ties go by key.
    private static func weakest(_ pool: [Player], tiers: SquadTiers, share: Double) -> Set<PlayerID> {
        // Every assessed player is rated (the tiers rate everyone not out on loan); one who was not would count as weakest.
        let best = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, tiers.ratings[$0.id]?.values.max()) })
        let ordered = pool.map(\.id).sorted { a, b in
            switch (best[a]!, best[b]!) {
            case let (ra?, rb?) where ra != rb: return ra < rb
            case (nil, _?): return true
            case (_?, nil): return false
            default: return a.key < b.key
            }
        }
        let count = Int((share * Double(pool.count) + roundingNoise).rounded(.down))
        return Set(ordered.prefix(count))
    }

    /// The middle wage, or the mean of the middle two for an even count; nil for none.
    private static func median(_ wages: [Int]) -> Double? {
        guard !wages.isEmpty else { return nil }
        let sorted = wages.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? Double(sorted[middle]) : (Double(sorted[middle - 1]) + Double(sorted[middle])) / 2
    }
}
