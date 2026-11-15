import Foundation

/// How strongly a player of the club's own should be moved on, strongest first.
public enum RemovalLevel: String, CaseIterable, Sendable { case critical, high, medium, keep }

/// What to do with a player of the club's own. `develop`, `play` and `loanForMatches` are given only to a player with an
/// outlook (`Development.outlooks`), below the high level.
public enum RemovalAction: String, CaseIterable, Sendable {
    case release, terminate, sell, monitor
    /// Keep him and develop him in training.
    case develop
    /// Keep him: he is getting his matches here.
    case play
    /// Loan him out for the matches he is not getting here. Not a removal: he is not advised to leave.
    case loanForMatches
    case keep
}

/// Why a young player is watched rather than kept to develop, play or be loaned.
public enum WatchReason: String, CaseIterable, Sendable {
    /// His reach is no more than cover, and he is neither kept to play nor needed as cover.
    case notWorthDeveloping
    /// He is needed as cover, whether or not he is worth developing: a loan would leave the squad short, and one not
    /// worth developing stays until the squad has someone better there.
    case neededForCover
}

/// Why a young player worth developing who is not getting matches is kept and not loaned.
public enum KeepReason: String, CaseIterable, Sendable {
    /// Under `loanForMatchesFromAge`: at his age he grows mainly in training.
    case age
    /// A youth contract cannot be loaned out.
    case youthContract
    /// `loanForMatchesMonthsAbove` months or fewer left, or unknown: renew the contract before a loan.
    case shortContract
}

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
    /// His reach against the first and second choice at each slot he can play: nil for a player of 24 or over, with
    /// ability 0, or who is not developing at the club.
    public let outlook: Outlook?
    /// Whether he is getting enough matches here; with an outlook only.
    public let matchesHere: MatchesHere?
    /// Why he is kept to develop and not loaned for matches; with `develop` only.
    public let keepReason: KeepReason?
    /// Why a young player is watched; with `monitor` for a player with an outlook only.
    public let watchReason: WatchReason?
    /// A loan for matches at exactly `loanForMatchesFromAge`: worth it only where he will start regularly.
    public let loanOnlyToStart: Bool
    /// He is on a youth contract that has not run out (one with 0 months left is read as no contract), so he can only
    /// be kept or released.
    public let onYouthContract: Bool
    public let isFalseProspect: Bool
    public let isMentor: Bool
    /// Wages left on the contract, in whole units of the squads' currency: 0 for a player out of contract, or on a
    /// full-time or youth contract with 0 months left; nil when months left is unknown, or for a contract type this
    /// tool does not read.
    public let releaseCost: Int?
    /// The likely cost of a mutual termination, in whole units of the squads' currency; 0 and nil as `releaseCost`.
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
    /// The weekly wages of the players advised to leave (`advisedToLeave`).
    public let weeklyWagesAtStake: Double
    /// Mean current ability of the club's own first-team players; nil when there are none.
    public let squadAverageAbility: Double?
    /// How the report's figures and reasons write money: the squads' currency, and wages in FMRTE's period.
    public let money: MoneyStyle
    /// The players the owner is advised to move on: critical or high, to be released, terminated or sold. A loan for
    /// matches is not among them.
    /// The caller passes them to `Training.report` as `leaving`, so nobody is retrained who is advised to go.
    public var advisedToLeave: Set<PlayerID>
}

public enum Removal {
    private static let weeksPerYear = 52.0
    private static let monthsPerYear = 12.0
    /// Absorbs binary floating-point error (0.3 × 10 may fall just short of 3) before a count is rounded down.
    private static let roundingNoise = 1e-9

    /// Whether `player` is on a youth contract that has not run out: one with 0 months left is read as no contract; one
    /// with months left unknown is still a youth contract. Such a player can only be kept or released, so he is never
    /// marked to sell or to loan out. The one reading of a youth contract: his advice's `onYouthContract` and the
    /// planner's mark rule both take it from here.
    public static func isOnYouthContract(_ player: Player) -> Bool {
        if case .youth = player.contractType { return player.monthsLeft != 0 }
        return false
    }

    /// Advice for every player of the club's own and a review of every player on loan at the club; players out on loan
    /// get neither, and injured players are assessed. The squad average ability and the median wage are over the club's
    /// own first-team players, so a large youth squad on low wages does not move them; with no first-team player, the
    /// rules that need them do not apply. Money is written in `money`, the style of the squads the players came from.
    /// A player with an outlook (`Development.outlooks`, from `retraining` and the elevens with injured players kept in)
    /// is scored on his reach, and whether he gets matches here is read from `history` up to `asOf`.
    /// Throws `PlanError.badParameters` when `FitnessModel.problems(in:)` finds problems, what
    /// `Elevens.report` throws, and `RatingError.missingAttribute` for an assessed player without Consistency, Important
    /// Matches, Injury Proneness, Professionalism, Ambition, Controversy, Temperament or Determination. Throws what
    /// `Depth.report`, `Tactic.assignments(catalog:)`, `Development.outlooks` and `Development.matchesHere` throw.
    public static func report(tactic: Tactic, players: [Player], ownClub: String?, money: MoneyStyle,
                              history: StartHistory, asOf: Day, retraining: [Retraining],
                              catalog: RoleCatalog, profile: RatingProfile,
                              parameters: EngineParameters) throws -> RemovalReport {
        let problems = FitnessModel.problems(in: parameters)
        guard problems.isEmpty else { throw PlanError.badParameters(problems) }
        let elevens = try Elevens.report(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                                         profile: profile, parameters: parameters)
        let depth = try Depth.report(tactic: tactic, players: players, ownClub: ownClub, elevens: elevens, catalog: catalog,
                                     profile: profile, parameters: parameters)
        return try report(players: players, ownClub: ownClub, money: money, history: history, asOf: asOf,
                          retraining: retraining, assignments: try tactic.assignments(catalog: catalog),
                          elevens: elevens, depth: depth, parameters: parameters)
    }

    /// The same, from `elevens` and `depth` already worked out for the tactic and these players (`Elevens.report`
    /// keeps injured players in), and the tactic's `assignments`. The caller has checked the parameters with
    /// `FitnessModel.problems(in:)`. Throws `RatingError.missingAttribute` as above, and what `Development.outlooks`
    /// and `Development.matchesHere` throw.
    static func report(players: [Player], ownClub: String?, money: MoneyStyle, history: StartHistory, asOf: Day,
                       retraining: [Retraining], assignments: [SlotAssignment], elevens: ElevensReport,
                       depth depthReport: DepthReport, parameters: EngineParameters) throws -> RemovalReport {
        let tiers = elevens.tiers
        let depth = depthReport.slots

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
        let outlooks = try Development.outlooks(players: players, ownClub: ownClub, assignments: assignments, tiers: tiers,
                                                retraining: retraining, parameters: parameters)

        let firstTeam = own.filter { $0.squad == .firstTeam }
        let squad = SquadFacts(
            averageAbility: Development.averageAbility(of: players, ownClub: ownClub),
            medianWage: median(firstTeam.map(\.wagePerWeek)),
            weakest: weakest(own + loanedIn, tiers: tiers, share: parameters.removalRules.value.weakestShare),
            tiers: tiers, depth: depth, thinBelow: parameters.depthThinBelow.value)

        var advice: [RemovalAdvice] = []
        var wagesAtStake = 0.0
        var leaving: Set<PlayerID> = []
        for player in own {
            let outlook = outlooks[player.id]
            let matchesHere = outlook == nil ? nil
                : try Development.matchesHere(for: player, assignments: assignments, tiers: tiers, history: history,
                                              asOf: asOf, parameters: parameters)
            let one = Self.advice(for: player, traits: traits[player.id]!, outlook: outlook, matchesHere: matchesHere,
                                  squad: squad, money: money, parameters: parameters)
            switch (one.level, one.action) {
            case (.critical, .release), (.critical, .terminate), (.critical, .sell),
                 (.high, .release), (.high, .terminate), (.high, .sell):
                leaving.insert(player.id)
                wagesAtStake += player.wagePerWeek
            case (.critical, .monitor), (.critical, .develop), (.critical, .play), (.critical, .loanForMatches),
                 (.critical, .keep), (.high, .monitor), (.high, .develop), (.high, .play), (.high, .loanForMatches),
                 (.high, .keep), (.medium, _), (.keep, _):
                break
            }
            advice.append(one)
        }
        let loans = loanedIn.map { review(of: $0, traits: traits[$0.id]!, squad: squad, parameters: parameters) }

        return RemovalReport(
            advice: advice.sorted { $0.score != $1.score ? $0.score > $1.score : $0.player.key < $1.player.key },
            loans: loans.sorted { $0.score != $1.score ? $0.score > $1.score : $0.player.key < $1.player.key },
            weeklyWagesAtStake: wagesAtStake, squadAverageAbility: squad.averageAbility, money: money,
            advisedToLeave: leaving)
    }

    // MARK: Players of the club's own

    /// A player with an outlook is scored on one line in place of the elevens, weakest and ability lines: the better of
    /// his place in the elevens and his reach. His Professionalism and Ambition add no line, since his reach already
    /// counts them, and a short contract on a player worth keeping says to renew it, at no points. His advice is the
    /// young players' (`youngAction`), and rests also on the evidence of the estimate behind his outlook.
    private static func advice(for player: Player, traits: Traits, outlook: Outlook?, matchesHere: MatchesHere?,
                               squad: SquadFacts, money: MoneyStyle, parameters: EngineParameters) -> RemovalAdvice {
        let rules = parameters.removalRules.value
        var reasons = Reasons()
        var evidence = [parameters.removalRules.evidence, parameters.removalLevels.evidence]

        // Only a player out of contract can go at no cost. A youth contract is read and costed like a full-time one; a
        // type this tool does not read (a part-time contract, say) says nothing about the cost either way. A full-time
        // or youth contract with 0 months left is read as no contract (the owner's decision of 13 November 2026, to be
        // checked against the game); unknown months are not.
        let outOfContract: Bool
        let costsKnown: Bool
        let onYouthContract = isOnYouthContract(player)
        switch player.contractType {
        case .fullTime where player.monthsLeft == 0, .youth where player.monthsLeft == 0:
            (outOfContract, costsKnown) = (true, true)
            reasons.add(rules.notFullTimePoints, "No contract: 0 months left")
        case .fullTime, .youth:
            (outOfContract, costsKnown) = (false, true)
        case .outOfContract:
            (outOfContract, costsKnown) = (true, true)
            reasons.add(rules.notFullTimePoints, "Not on a full-time contract")
        case .other(let type):
            (outOfContract, costsKnown) = (false, false)
            reasons.add(0, "Contract type \(type) is not one this tool reads: no release cost is given")
        }

        let tier = squad.tiers.tier(of: player.id)
        let place = tierLine(tier, first: rules.firstElevenPoints, second: rules.secondElevenPoints,
                             neither: rules.neitherElevenPoints)
        let inEither = place.inEither
        // Whether the line added says he is worth keeping: in either eleven, or a reach that could take him there.
        var worthKeeping = inEither
        if let outlook, let level = outlook.level,
           let line = AdvisorText.reachLine(outlook, names: { PositionText.plain($0.position) }) {
            let reach = reachPoints(level, rules)
            // Only a place in the elevens competes with his reach; on a tie, the place.
            if inEither && place.reason.points <= reach.points {
                reasons.list.append(place.reason)
            } else {
                reasons.add(reach.points, line)
                worthKeeping = reach.worthKeeping
            }
        } else {
            reasons.list.append(place.reason)
        }
        if outlook != nil {
            evidence += [parameters.growthPerSeason.evidence, parameters.growthProfessionalismRates.evidence,
                         parameters.ratingAbilityOffset.evidence, parameters.markedlyLowerShare.evidence]
            if player.age <= parameters.youngestUpToAge.value {
                evidence.append(parameters.markedlyLowerShareYoungest.evidence)
            }
        }
        let thinCover = reasons.addThinCover(player.id, tier: tier, squad: squad,
                                             points: parameters.removalThinCoverPoints.value)
        if thinCover {
            evidence.append(parameters.removalThinCoverPoints.evidence)
        }
        if outlook == nil {
            if squad.weakest.contains(player.id) { reasons.add(rules.weakestPoints, weakestReason(rules)) }
            reasons.addAbility(player, squad: squad, share: rules.farBelowAverageShare,
                               farBelow: rules.farBelowAveragePoints, below: rules.belowAveragePoints)
        }

        let wageRules = parameters.removalWageRules.value
        if let median = squad.medianWage, median > 0, !inEither {
            let wage = player.wagePerWeek
            let points: Int? = wage > wageRules.highMultiple * median ? wageRules.highPoints
                : wage > median ? wageRules.abovePoints : nil
            if let points {
                reasons.add(points, "Paid \(Display.wage(perWeek: wage, money)), against a median of "
                            + "\(Display.wageAmount(perWeek: median, money)), and in neither eleven")
                evidence.append(parameters.removalWageRules.evidence)
            }
        }

        if let months = player.monthsLeft, months > 0 {
            let points: Int? = months <= rules.contractEndingSoonUpTo ? rules.contractEndingSoonPoints
                : months <= rules.contractEndingUpTo ? rules.contractEndingPoints : nil
            let ends = "Contract ends in \(months) \(months == 1 ? "month" : "months")"
            if points != nil, outlook != nil, worthKeeping {
                reasons.add(0, "\(ends): renew it")
            } else if let points {
                reasons.add(points, ends)
            }
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
        if outlook == nil {
            if traits.professionalism < rules.professionalismLowBelow {
                reasons.add(rules.professionalismLowPoints, "Professionalism \(traits.professionalism)")
            } else if traits.professionalism <= rules.professionalismFairUpTo {
                reasons.add(rules.professionalismFairPoints, "Professionalism \(traits.professionalism)")
            }
            if traits.ambition < rules.ambitionBelow { reasons.add(rules.ambitionPoints, "Ambition \(traits.ambition)") }
        }
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
        // A false prospect is marked and adds no line.
        var isFalseProspect = false
        if age <= rules.falseProspectUpToAge {
            let rate = Double(gap) / Double(rules.falseProspectTargetAge - age)
            isFalseProspect = rate > rules.falseProspectRateAbove
                && traits.professionalism < rules.falseProspectProfessionalismBelow
        }

        if let room, let average = squad.averageAbility, age >= rules.stallingFromAge, age <= rules.stallingUpToAge,
           Double(player.currentAbility) < average, room < rules.stallingRoomBelow {
            reasons.add(rules.stallingPoints, "Aged \(age) with little room to grow")
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
        if outOfContract {
            (releaseCost, mutualCost) = (0, 0)
        } else if costsKnown, let months = player.monthsLeft {
            let monthsOfWages = Double(months) + parameters.contractMonthsAllowance.value
            let release = Int((player.wagePerWeek * weeksPerYear / monthsPerYear * monthsOfWages).rounded())
            (releaseCost, mutualCost) = (release, Int((parameters.mutualTerminationShare.value * Double(release)).rounded()))
        } else {
            (releaseCost, mutualCost) = (nil, nil)
        }
        if mutualCost != nil {
            evidence.append(parameters.mutualTerminationShare.evidence)
            evidence.append(parameters.contractMonthsAllowance.evidence)
        }

        // A player on a youth contract can only be kept or released, at any age (the owner's statement; FM27
        // observation), and a young false prospect is sold, not terminated: buyers still pay for his potential.
        let action: RemovalAction
        var keepReason: KeepReason?
        var watchReason: WatchReason?
        var loanOnlyToStart = false
        switch level {
        case .high, .critical:
            if outOfContract || onYouthContract {
                action = .release
            } else if outlook != nil && isFalseProspect {
                action = .sell
            } else if level == .critical, let months = player.monthsLeft, months <= rules.terminateWithinMonths,
                      let mutualCost, player.askingPrice.map({ $0 < mutualCost }) ?? true {
                action = .terminate
            } else {
                action = .sell
            }
        case .medium, .keep:
            if let outlook, let matchesHere {
                let young = youngAction(player, outlook: outlook, matchesHere: matchesHere, inEither: inEither,
                                        thinCover: thinCover, onYouthContract: onYouthContract, parameters: parameters)
                (action, keepReason, watchReason, loanOnlyToStart)
                    = (young.action, young.keepReason, young.watchReason, young.loanOnlyToStart)
                evidence += young.evidence
            } else {
                action = level == .keep ? .keep : .monitor
            }
        }

        return RemovalAdvice(player: player.id, name: player.name, level: level, action: action, score: score,
                             reasons: reasons.list, tier: tier, outlook: outlook, matchesHere: matchesHere,
                             keepReason: keepReason, watchReason: watchReason, loanOnlyToStart: loanOnlyToStart,
                             onYouthContract: onYouthContract, isFalseProspect: isFalseProspect,
                             isMentor: isMentor, releaseCost: releaseCost, mutualCost: mutualCost,
                             basis: Evidence.weakest(evidence)!)
    }

    /// The advice for a player with an outlook below the high level, the first rule that applies winning.
    /// One not worth developing (his reach no more than cover) is never kept to develop or loaned for matches: in
    /// either eleven and getting his matches here he is kept to play; otherwise he is watched, as needed for cover when
    /// he is, and as not worth developing when not. For anyone else: under `loanForMatchesFromAge` he is kept to
    /// develop; one getting his matches here is kept to play; one needed for cover is watched; a youth contract cannot
    /// be loaned, nor a contract with `loanForMatchesMonthsAbove` months or fewer left (or unknown), so he is kept to
    /// develop; otherwise he is loaned for matches. With the evidence of the parameters the rules read.
    private static func youngAction(_ player: Player, outlook: Outlook, matchesHere: MatchesHere, inEither: Bool,
                                    thinCover: Bool, onYouthContract: Bool, parameters: EngineParameters)
        -> (action: RemovalAction, keepReason: KeepReason?, watchReason: WatchReason?, loanOnlyToStart: Bool,
            evidence: [Evidence]) {
        let matchesEvidence = [parameters.matchesHereShare.evidence, parameters.matchesHereWindowDays.evidence,
                               parameters.matchesHereMinimumConfirmed.evidence, parameters.depthSolidFamiliarity.evidence]
        let notWorthDeveloping: Bool
        switch outlook.level {
        case .couldBeCover?, .markedlyLower?: notWorthDeveloping = true
        case .couldPassFirst?, .couldMakeSecond?, nil: notWorthDeveloping = false
        }
        if notWorthDeveloping {
            // Whether he gets his matches is read only for a player in either eleven.
            let evidence = inEither ? matchesEvidence : []
            if inEither && matchesHere.isEnough { return (.play, nil, nil, false, evidence) }
            return (.monitor, nil, thinCover ? .neededForCover : .notWorthDeveloping, false, evidence)
        }

        let fromAge = parameters.loanForMatchesFromAge
        var evidence = [fromAge.evidence]
        if player.age < fromAge.value { return (.develop, .age, nil, false, evidence) }
        evidence += matchesEvidence
        if matchesHere.isEnough { return (.play, nil, nil, false, evidence) }
        if thinCover { return (.monitor, nil, .neededForCover, false, evidence) }
        if onYouthContract { return (.develop, .youthContract, nil, false, evidence) }
        let monthsAbove = parameters.loanForMatchesMonthsAbove
        evidence.append(monthsAbove.evidence)
        guard let months = player.monthsLeft, months > monthsAbove.value else {
            return (.develop, .shortContract, nil, false, evidence)
        }
        return (.loanForMatches, nil, nil, player.age == fromAge.value, evidence)
    }

    // MARK: Players on loan here

    private static func review(of player: Player, traits: Traits, squad: SquadFacts,
                               parameters: EngineParameters) -> LoanReview {
        let rules = parameters.removalRules.value
        let loan = rules.loanReview
        var reasons = Reasons()
        if squad.weakest.contains(player.id) { reasons.add(loan.weakestPoints, weakestReason(rules)) }
        let tier = squad.tiers.tier(of: player.id)
        let place = tierLine(tier, first: loan.firstElevenPoints, second: loan.secondElevenPoints,
                             neither: loan.neitherElevenPoints)
        reasons.list.append(place.reason)
        let inEither = place.inEither
        var evidence = [parameters.removalRules.evidence]
        if reasons.addThinCover(player.id, tier: tier, squad: squad, points: parameters.removalThinCoverPoints.value) {
            evidence.append(parameters.removalThinCoverPoints.evidence)
        }
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
                          basis: Evidence.weakest(evidence)!)
    }

    // MARK: Shared

    private static func weakestReason(_ rules: RemovalRules) -> String {
        "Among the weakest \(Display.percent(rules.weakestShare)) of the squad for this tactic"
    }

    /// The line for his tier, and whether he is in either eleven.
    private static func tierLine(_ tier: SquadTier?, first: Int, second: Int,
                                 neither: Int) -> (reason: RemovalReason, inEither: Bool) {
        switch tier {
        case .first(let slot)?:
            (RemovalReason(text: "In the first eleven at \(PositionText.plain(slot.position))", points: first), true)
        case .second(let slot)?:
            (RemovalReason(text: "In the second eleven at \(PositionText.plain(slot.position))", points: second), true)
        case .backup?, nil:
            (RemovalReason(text: "In neither eleven", points: neither), false)
        }
    }

    /// The points for his reach at `level`, from the rules for the elevens, the weakest and far below the average, and
    /// whether that level says he is worth keeping.
    private static func reachPoints(_ level: ReachLevel, _ rules: RemovalRules) -> (points: Int, worthKeeping: Bool) {
        switch level {
        case .couldPassFirst: (rules.firstElevenPoints, true)
        case .couldMakeSecond: (rules.secondElevenPoints, true)
        case .couldBeCover: (rules.neitherElevenPoints, false)
        case .markedlyLower: (rules.neitherElevenPoints + rules.weakestPoints + rules.farBelowAveragePoints, false)
        }
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
        /// Over the club's own first-team players; nil when there are none.
        let averageAbility: Double?
        /// Over the club's own first-team players; nil when there are none.
        let medianWage: Double?
        let weakest: Set<PlayerID>
        let tiers: SquadTiers
        /// Depth's report for each slot, in slot order.
        let depth: [SlotDepth]
        /// `depthThinBelow`: a slot whose cover is at most this would be thin without one of its cover.
        let thinBelow: Int
    }

    private struct Reasons {
        var list: [RemovalReason] = []
        var score: Int { list.map(\.points).reduce(0, +) }

        mutating func add(_ points: Int, _ text: String) { list.append(RemovalReason(text: text, points: points)) }

        /// Adds the points for protecting real cover, once, at the first slot in slot order where he is first choice
        /// and cover is thin (injured or not), or where he counts as cover by Depth's rule and the slot's cover is at
        /// most the line; the first of the two is checked first at each slot. Says whether it added them.
        mutating func addThinCover(_ player: PlayerID, tier: SquadTier?, squad: SquadFacts, points: Int) -> Bool {
            for slot in squad.depth {
                let position = PositionText.plain(slot.slot.position)
                if case .first(let home)? = tier, home == slot.slot, slot.isThin {
                    add(points, "First choice at \(position), where cover is thin")
                    return true
                }
                guard slot.cover <= squad.thinBelow,
                      let option = slot.options.first(where: { $0.player == player }),
                      option.countsAsCover else { continue }
                add(points, slot.isThin ? "Counts as cover at \(position), where cover is thin"
                                        : "Cover at \(position) would be thin without him")
                return true
            }
            return false
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

    /// The players whose best share is among the lowest `share` of `pool`, rounded down; ties go by key. A player's best
    /// share is the highest, over the tactic's slots, of his rating there over the slot's first choice's: a slot with no
    /// first choice, or one rated 0 or less, is skipped, and a player with no share at all ranks lowest. Measuring against
    /// the first choice keeps a goalkeeper, whose ratings are on a lower scale than outfield players', comparable.
    private static func weakest(_ pool: [Player], tiers: SquadTiers, share: Double) -> Set<PlayerID> {
        var firstRatings: [(slot: SlotID, rating: Double)] = []
        for slot in SlotID.allCases {
            guard let first = tiers.first[slot], let rating = tiers.ratings[first]?[slot], rating > 0 else { continue }
            firstRatings.append((slot, rating))
        }
        var best: [PlayerID: Double] = [:]
        for player in pool {
            for (slot, firstRating) in firstRatings {
                guard let rating = tiers.ratings[player.id]?[slot] else { continue }
                best[player.id] = max(best[player.id] ?? -.infinity, rating / firstRating)
            }
        }
        let ordered = pool.map(\.id).sorted { a, b in
            switch (best[a], best[b]) {
            case let (sa?, sb?) where sa != sb: return sa < sb
            case (nil, _?): return true
            case (_?, nil): return false
            default: return a.key < b.key
            }
        }
        let count = Int((share * Double(pool.count) + roundingNoise).rounded(.down))
        return Set(ordered.prefix(count))
    }

    /// The middle wage, or the mean of the middle two for an even count; nil for none.
    private static func median(_ wages: [Double]) -> Double? {
        guard !wages.isEmpty else { return nil }
        let sorted = wages.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
    }
}
