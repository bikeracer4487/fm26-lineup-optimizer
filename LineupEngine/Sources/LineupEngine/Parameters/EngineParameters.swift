/// One step of the familiarity table: a player with at least `minimum` familiarity plays at `factor`.
public struct FamiliarityStep: Sendable, Equatable {
    public let minimum: Int
    public let factor: Double

    public init(minimum: Int, factor: Double) {
        self.minimum = minimum
        self.factor = factor
    }
}

/// One step of a consecutive-starts table: a player who has started at least `starts` matches in quick succession plays at `factor`.
public struct ConsecutiveStartStep: Sendable, Equatable {
    public let starts: Int
    public let factor: Double

    public init(starts: Int, factor: Double) {
        self.starts = starts
        self.factor = factor
    }
}

/// How a player's own jadedness limit is worked out: a base by age (the standard jadedness threshold when no age
/// band applies), changed by Natural Fitness, Stamina and Injury Proneness, then kept within `lowest` to `highest`.
public struct RestLimitRules: Sendable, Equatable {
    /// At this age and over the base is `oldestBase`.
    public var oldestFromAge: Int
    public var oldestBase: Int
    /// From this age up to `oldestFromAge` the base is `olderBase`.
    public var olderFromAge: Int
    public var olderBase: Int
    /// Under this age the base is `youngBase`.
    public var youngUnderAge: Int
    public var youngBase: Int
    /// Natural Fitness below `naturalFitnessBelow` changes the limit by `naturalFitnessLowChange`;
    /// at `naturalFitnessFrom` or over, by `naturalFitnessHighChange`.
    public var naturalFitnessBelow: Int
    public var naturalFitnessLowChange: Int
    public var naturalFitnessFrom: Int
    public var naturalFitnessHighChange: Int
    /// Stamina below `staminaBelow` changes the limit by `staminaLowChange`; at `staminaFrom` or over, by `staminaHighChange`.
    public var staminaBelow: Int
    public var staminaLowChange: Int
    public var staminaFrom: Int
    public var staminaHighChange: Int
    /// Injury Proneness at `injuryPronenessFrom` or over changes the limit by `injuryPronenessHighChange`;
    /// at `injuryPronenessUpTo` or under, by `injuryPronenessLowChange`.
    public var injuryPronenessFrom: Int
    public var injuryPronenessHighChange: Int
    public var injuryPronenessUpTo: Int
    public var injuryPronenessLowChange: Int
    public var lowest: Int
    public var highest: Int

    public init(oldestFromAge: Int, oldestBase: Int, olderFromAge: Int, olderBase: Int, youngUnderAge: Int, youngBase: Int,
                naturalFitnessBelow: Int, naturalFitnessLowChange: Int, naturalFitnessFrom: Int, naturalFitnessHighChange: Int,
                staminaBelow: Int, staminaLowChange: Int, staminaFrom: Int, staminaHighChange: Int,
                injuryPronenessFrom: Int, injuryPronenessHighChange: Int, injuryPronenessUpTo: Int, injuryPronenessLowChange: Int,
                lowest: Int, highest: Int) {
        self.oldestFromAge = oldestFromAge; self.oldestBase = oldestBase
        self.olderFromAge = olderFromAge; self.olderBase = olderBase
        self.youngUnderAge = youngUnderAge; self.youngBase = youngBase
        self.naturalFitnessBelow = naturalFitnessBelow; self.naturalFitnessLowChange = naturalFitnessLowChange
        self.naturalFitnessFrom = naturalFitnessFrom; self.naturalFitnessHighChange = naturalFitnessHighChange
        self.staminaBelow = staminaBelow; self.staminaLowChange = staminaLowChange
        self.staminaFrom = staminaFrom; self.staminaHighChange = staminaHighChange
        self.injuryPronenessFrom = injuryPronenessFrom; self.injuryPronenessHighChange = injuryPronenessHighChange
        self.injuryPronenessUpTo = injuryPronenessUpTo; self.injuryPronenessLowChange = injuryPronenessLowChange
        self.lowest = lowest; self.highest = highest
    }
}

/// One step of an age table: a player aged `upTo` or under, and above the step before, takes `factor`.
public struct AgeFactorStep: Sendable, Equatable {
    public let upTo: Int
    public let factor: Double

    public init(upTo: Int, factor: Double) {
        self.upTo = upTo
        self.factor = factor
    }
}

/// How quickly a player is likely to learn a new position, from 0 to 1: a weighted sum of his Versatility, an age
/// factor, his Professionalism and his room to grow. The weights add up to 1.
public struct LearnabilityRules: Sendable, Equatable {
    public var versatilityWeight: Double
    public var ageWeight: Double
    public var professionalismWeight: Double
    public var roomToGrowWeight: Double
    /// Versatility and Professionalism count as their value over this.
    public var attributeMaximum: Double
    /// Versatility below this counts at `lowVersatilityFactor` times its share.
    public var lowVersatilityBelow: Int
    public var lowVersatilityFactor: Double
    /// Youngest first; the first step whose `upTo` is at least his age gives the age factor.
    public var ageSteps: [AgeFactorStep]
    /// The age factor above every step.
    public var ageAbove: Double
    /// Room to grow is potential ability minus current ability over this, kept within 0 to 1.
    public var roomToGrowSpan: Double

    public init(versatilityWeight: Double, ageWeight: Double, professionalismWeight: Double, roomToGrowWeight: Double,
                attributeMaximum: Double, lowVersatilityBelow: Int, lowVersatilityFactor: Double,
                ageSteps: [AgeFactorStep], ageAbove: Double, roomToGrowSpan: Double) {
        self.versatilityWeight = versatilityWeight; self.ageWeight = ageWeight
        self.professionalismWeight = professionalismWeight; self.roomToGrowWeight = roomToGrowWeight
        self.attributeMaximum = attributeMaximum
        self.lowVersatilityBelow = lowVersatilityBelow; self.lowVersatilityFactor = lowVersatilityFactor
        self.ageSteps = ageSteps; self.ageAbove = ageAbove
        self.roomToGrowSpan = roomToGrowSpan
    }
}

/// A move from one position to another, as the retraining table keys it.
public struct PositionTransition: Hashable, Sendable {
    public let from: Position
    public let to: Position

    public init(from: Position, to: Position) {
        self.from = from
        self.to = to
    }
}

/// How hard it is to retrain from one position to another, and which of a player's positions he retrains from.
public struct RetrainingTransitions: Sendable, Equatable {
    /// The classes the table names; a move it does not name takes the default below.
    public var pairs: [PositionTransition: RetrainingDifficulty]
    /// A move between two positions of the same group takes `sameGroupDifficulty`; any other unnamed move `otherDifficulty`.
    public var defensiveGroup: Set<Position>
    public var attackingGroup: Set<Position>
    public var sameGroupDifficulty: RetrainingDifficulty
    public var otherDifficulty: RetrainingDifficulty
    /// A player retrains from one of his positions at this familiarity or over; with none, from his best.
    public var fromFamiliarity: Int

    public init(pairs: [PositionTransition: RetrainingDifficulty], defensiveGroup: Set<Position>, attackingGroup: Set<Position>,
                sameGroupDifficulty: RetrainingDifficulty, otherDifficulty: RetrainingDifficulty, fromFamiliarity: Int) {
        self.pairs = pairs
        self.defensiveGroup = defensiveGroup; self.attackingGroup = attackingGroup
        self.sameGroupDifficulty = sameGroupDifficulty; self.otherDifficulty = otherDifficulty
        self.fromFamiliarity = fromFamiliarity
    }

    /// The table's class for the move, or the default for its groups.
    public func difficulty(from: Position, to: Position) -> RetrainingDifficulty {
        if let named = pairs[PositionTransition(from: from, to: to)] { return named }
        let sameGroup = (defensiveGroup.contains(from) && defensiveGroup.contains(to))
            || (attackingGroup.contains(from) && attackingGroup.contains(to))
        return sameGroup ? sameGroupDifficulty : otherDifficulty
    }
}

/// A span of weeks, `fewest` to `most`.
public struct WeekRange: Sendable, Equatable {
    public let fewest: Int
    public let most: Int

    public init(fewest: Int, most: Int) {
        self.fewest = fewest
        self.most = most
    }

    /// Halfway between the ends.
    public var middle: Double { Double(fewest + most) / 2 }
}

/// How long each class of retraining takes. An inversion has no range: it is never recommended.
public struct RetrainingWeeks: Sendable, Equatable {
    public var fluid: WeekRange
    public var structural: WeekRange
    public var spatial: WeekRange

    public init(fluid: WeekRange, structural: WeekRange, spatial: WeekRange) {
        self.fluid = fluid; self.structural = structural; self.spatial = spatial
    }
}

/// What makes one player's retraining quicker or slower than the middle of its class's range: his age, his
/// Versatility and a head start from the familiarity he already has. The weeks are never fewer than `minimumWeeks`.
public struct RetrainingPace: Sendable, Equatable {
    /// Youngest first; the first step whose `upTo` is at least his age gives the factor.
    public var ageSteps: [AgeFactorStep]
    /// The age factor above every step.
    public var ageAbove: Double
    /// Versatility at `highVersatilityFrom` or over takes `highVersatilityFactor`; at `lowVersatilityUpTo` or under,
    /// `lowVersatilityFactor`; between them, no change.
    public var highVersatilityFrom: Int
    public var highVersatilityFactor: Double
    public var lowVersatilityUpTo: Int
    public var lowVersatilityFactor: Double
    /// Highest minimum first; the first step his familiarity at the new position reaches applies. Below every step, no change.
    public var headStartSteps: [FamiliarityStep]
    public var minimumWeeks: Int

    public init(ageSteps: [AgeFactorStep], ageAbove: Double, highVersatilityFrom: Int, highVersatilityFactor: Double,
                lowVersatilityUpTo: Int, lowVersatilityFactor: Double, headStartSteps: [FamiliarityStep], minimumWeeks: Int) {
        self.ageSteps = ageSteps; self.ageAbove = ageAbove
        self.highVersatilityFrom = highVersatilityFrom; self.highVersatilityFactor = highVersatilityFactor
        self.lowVersatilityUpTo = lowVersatilityUpTo; self.lowVersatilityFactor = lowVersatilityFactor
        self.headStartSteps = headStartSteps
        self.minimumWeeks = minimumWeeks
    }
}

/// The points the loan review gives a player on loan at the club. Its thresholds are the removal rules'.
public struct LoanReviewRules: Sendable, Equatable {
    public var weakestPoints: Int
    public var firstElevenPoints: Int
    public var secondElevenPoints: Int
    public var neitherElevenPoints: Int
    public var farBelowAveragePoints: Int
    public var belowAveragePoints: Int
    public var consistencyLowPoints: Int
    public var importantMatchesPoints: Int
    public var injuryPronenessPoints: Int
    /// At this score or over the loan should end early.
    public var endEarlyFrom: Int
    /// At this score or over, and below `endEarlyFrom`, the loan should not be extended.
    public var doNotExtendFrom: Int

    public init(weakestPoints: Int, firstElevenPoints: Int, secondElevenPoints: Int, neitherElevenPoints: Int,
                farBelowAveragePoints: Int, belowAveragePoints: Int, consistencyLowPoints: Int, importantMatchesPoints: Int,
                injuryPronenessPoints: Int, endEarlyFrom: Int, doNotExtendFrom: Int) {
        self.weakestPoints = weakestPoints
        self.firstElevenPoints = firstElevenPoints; self.secondElevenPoints = secondElevenPoints
        self.neitherElevenPoints = neitherElevenPoints
        self.farBelowAveragePoints = farBelowAveragePoints; self.belowAveragePoints = belowAveragePoints
        self.consistencyLowPoints = consistencyLowPoints; self.importantMatchesPoints = importantMatchesPoints
        self.injuryPronenessPoints = injuryPronenessPoints
        self.endEarlyFrom = endEarlyFrom; self.doNotExtendFrom = doNotExtendFrom
    }
}

/// The points Player Removal gives a player of the club's own for each rule that applies, apart from the wage rules,
/// and the loan review's. Of a pair of lines ("under 8 / exactly 8") only the stronger applies. "Room to grow" is
/// potential ability minus current ability over current ability.
public struct RemovalRules: Sendable, Equatable {
    /// A player out of contract, or on a full-time contract with 0 months left: reading 0 months as no contract is the
    /// owner's decision of 13 November 2026, to be double checked against the game. Unknown months left take no points
    /// here. A contract type this tool does not read takes no points.
    public var notFullTimePoints: Int
    public var firstElevenPoints: Int
    public var secondElevenPoints: Int
    public var neitherElevenPoints: Int
    /// This share of the players assessed, rounded down, are the weakest: ranked by their best share of a slot's
    /// first-choice rating (their rating there over the first choice's), not by raw rating.
    public var weakestShare: Double
    public var weakestPoints: Int
    /// Current ability under this share of the squad average takes `farBelowAveragePoints`; under the average,
    /// `belowAveragePoints`.
    public var farBelowAverageShare: Double
    public var farBelowAveragePoints: Int
    public var belowAveragePoints: Int
    /// From 1 month left up to `contractEndingSoonUpTo` takes `contractEndingSoonPoints`; from there up to
    /// `contractEndingUpTo`, `contractEndingPoints`.
    public var contractEndingSoonUpTo: Int
    public var contractEndingSoonPoints: Int
    public var contractEndingUpTo: Int
    public var contractEndingPoints: Int
    /// Consistency below `consistencyLowBelow` takes `consistencyLowPoints`; from there up to `consistencyFairUpTo`,
    /// `consistencyFairPoints`.
    public var consistencyLowBelow: Int
    public var consistencyLowPoints: Int
    public var consistencyFairUpTo: Int
    public var consistencyFairPoints: Int
    public var importantMatchesBelow: Int
    public var importantMatchesPoints: Int
    public var injuryPronenessAbove: Int
    public var injuryPronenessPoints: Int
    /// Professionalism below `professionalismLowBelow` takes `professionalismLowPoints`; from there up to
    /// `professionalismFairUpTo`, `professionalismFairPoints`.
    public var professionalismLowBelow: Int
    public var professionalismLowPoints: Int
    public var professionalismFairUpTo: Int
    public var professionalismFairPoints: Int
    public var ambitionBelow: Int
    public var ambitionPoints: Int
    public var controversyAbove: Int
    public var controversyPoints: Int
    public var temperamentBelow: Int
    public var temperamentPoints: Int
    /// A false prospect: aged `falseProspectUpToAge` or under, needing more than `falseProspectRateAbove` ability points
    /// a year to reach his potential by `falseProspectTargetAge`, with Professionalism below `falseProspectProfessionalismBelow`.
    public var falseProspectUpToAge: Int
    public var falseProspectTargetAge: Int
    public var falseProspectRateAbove: Double
    public var falseProspectProfessionalismBelow: Int
    public var falseProspectPoints: Int
    /// Aged `stallingFromAge` to `stallingUpToAge`, current ability under the squad average, room to grow under
    /// `stallingRoomBelow`.
    public var stallingFromAge: Int
    public var stallingUpToAge: Int
    public var stallingRoomBelow: Double
    public var stallingPoints: Int
    /// A prospect: aged `prospectUpToAge` or under with room to grow of at least `strongProspectRoomFrom`
    /// (`strongProspectPoints`) or at least `prospectRoomFrom` (`prospectPoints`). Separate from the planner's
    /// `EngineParameters.prospectMaxAge` and `prospectHeadroom` on purpose, because Removal has two steps of room to
    /// grow where the planner has one; change them together.
    public var prospectUpToAge: Int
    public var strongProspectRoomFrom: Double
    public var strongProspectPoints: Int
    public var prospectRoomFrom: Double
    public var prospectPoints: Int
    /// A mentor: aged `mentorFromAge` or over with Professionalism `mentorProfessionalismFrom` or over; `mentorPoints`
    /// with Determination `mentorDeterminationFrom` or over, `lesserMentorPoints` with less.
    public var mentorFromAge: Int
    public var mentorProfessionalismFrom: Int
    public var mentorDeterminationFrom: Int
    public var mentorPoints: Int
    public var lesserMentorPoints: Int
    /// Not a mentor, aged `noGrowthFromAge` or over with room to grow under `noGrowthRoomBelow`.
    public var noGrowthFromAge: Int
    public var noGrowthRoomBelow: Double
    public var noGrowthPoints: Int
    /// Not a mentor, aged `oldFromAge` or over.
    public var oldFromAge: Int
    public var oldPoints: Int
    /// A critical player with this many months left or fewer may be released by mutual termination.
    public var terminateWithinMonths: Int
    public var loanReview: LoanReviewRules

    public init(notFullTimePoints: Int, firstElevenPoints: Int, secondElevenPoints: Int, neitherElevenPoints: Int,
                weakestShare: Double, weakestPoints: Int,
                farBelowAverageShare: Double, farBelowAveragePoints: Int, belowAveragePoints: Int,
                contractEndingSoonUpTo: Int, contractEndingSoonPoints: Int, contractEndingUpTo: Int, contractEndingPoints: Int,
                consistencyLowBelow: Int, consistencyLowPoints: Int, consistencyFairUpTo: Int, consistencyFairPoints: Int,
                importantMatchesBelow: Int, importantMatchesPoints: Int, injuryPronenessAbove: Int, injuryPronenessPoints: Int,
                professionalismLowBelow: Int, professionalismLowPoints: Int,
                professionalismFairUpTo: Int, professionalismFairPoints: Int,
                ambitionBelow: Int, ambitionPoints: Int, controversyAbove: Int, controversyPoints: Int,
                temperamentBelow: Int, temperamentPoints: Int,
                falseProspectUpToAge: Int, falseProspectTargetAge: Int, falseProspectRateAbove: Double,
                falseProspectProfessionalismBelow: Int, falseProspectPoints: Int,
                stallingFromAge: Int, stallingUpToAge: Int, stallingRoomBelow: Double, stallingPoints: Int,
                prospectUpToAge: Int, strongProspectRoomFrom: Double, strongProspectPoints: Int,
                prospectRoomFrom: Double, prospectPoints: Int,
                mentorFromAge: Int, mentorProfessionalismFrom: Int, mentorDeterminationFrom: Int,
                mentorPoints: Int, lesserMentorPoints: Int,
                noGrowthFromAge: Int, noGrowthRoomBelow: Double, noGrowthPoints: Int, oldFromAge: Int, oldPoints: Int,
                terminateWithinMonths: Int, loanReview: LoanReviewRules) {
        self.notFullTimePoints = notFullTimePoints
        self.firstElevenPoints = firstElevenPoints; self.secondElevenPoints = secondElevenPoints
        self.neitherElevenPoints = neitherElevenPoints
        self.weakestShare = weakestShare; self.weakestPoints = weakestPoints
        self.farBelowAverageShare = farBelowAverageShare; self.farBelowAveragePoints = farBelowAveragePoints
        self.belowAveragePoints = belowAveragePoints
        self.contractEndingSoonUpTo = contractEndingSoonUpTo; self.contractEndingSoonPoints = contractEndingSoonPoints
        self.contractEndingUpTo = contractEndingUpTo; self.contractEndingPoints = contractEndingPoints
        self.consistencyLowBelow = consistencyLowBelow; self.consistencyLowPoints = consistencyLowPoints
        self.consistencyFairUpTo = consistencyFairUpTo; self.consistencyFairPoints = consistencyFairPoints
        self.importantMatchesBelow = importantMatchesBelow; self.importantMatchesPoints = importantMatchesPoints
        self.injuryPronenessAbove = injuryPronenessAbove; self.injuryPronenessPoints = injuryPronenessPoints
        self.professionalismLowBelow = professionalismLowBelow; self.professionalismLowPoints = professionalismLowPoints
        self.professionalismFairUpTo = professionalismFairUpTo; self.professionalismFairPoints = professionalismFairPoints
        self.ambitionBelow = ambitionBelow; self.ambitionPoints = ambitionPoints
        self.controversyAbove = controversyAbove; self.controversyPoints = controversyPoints
        self.temperamentBelow = temperamentBelow; self.temperamentPoints = temperamentPoints
        self.falseProspectUpToAge = falseProspectUpToAge; self.falseProspectTargetAge = falseProspectTargetAge
        self.falseProspectRateAbove = falseProspectRateAbove
        self.falseProspectProfessionalismBelow = falseProspectProfessionalismBelow; self.falseProspectPoints = falseProspectPoints
        self.stallingFromAge = stallingFromAge; self.stallingUpToAge = stallingUpToAge
        self.stallingRoomBelow = stallingRoomBelow; self.stallingPoints = stallingPoints
        self.prospectUpToAge = prospectUpToAge
        self.strongProspectRoomFrom = strongProspectRoomFrom; self.strongProspectPoints = strongProspectPoints
        self.prospectRoomFrom = prospectRoomFrom; self.prospectPoints = prospectPoints
        self.mentorFromAge = mentorFromAge; self.mentorProfessionalismFrom = mentorProfessionalismFrom
        self.mentorDeterminationFrom = mentorDeterminationFrom
        self.mentorPoints = mentorPoints; self.lesserMentorPoints = lesserMentorPoints
        self.noGrowthFromAge = noGrowthFromAge; self.noGrowthRoomBelow = noGrowthRoomBelow; self.noGrowthPoints = noGrowthPoints
        self.oldFromAge = oldFromAge; self.oldPoints = oldPoints
        self.terminateWithinMonths = terminateWithinMonths
        self.loanReview = loanReview
    }
}

/// Wage rules for a player of the club's own who is in neither eleven: a wage above `highMultiple` times the squad's
/// median takes `highPoints`; above the median, `abovePoints`. A median of 0 applies neither.
public struct RemovalWageRules: Sendable, Equatable {
    public var highMultiple: Double
    public var highPoints: Int
    public var abovePoints: Int

    public init(highMultiple: Double, highPoints: Int, abovePoints: Int) {
        self.highMultiple = highMultiple; self.highPoints = highPoints; self.abovePoints = abovePoints
    }
}

/// The scores at and above which a removal advice is critical, high or medium; below `medium` it is keep.
public struct RemovalLevels: Sendable, Equatable {
    public var critical: Int
    public var high: Int
    public var medium: Int

    public init(critical: Int, high: Int, medium: Int) {
        self.critical = critical; self.high = high; self.medium = medium
    }
}

/// A bigger match within `withinDays` days after this one multiplies the suggested importance's score by `factor`.
public struct BiggerMatchStep: Sendable, Equatable {
    public var withinDays: Int
    public var factor: Double

    public init(withinDays: Int, factor: Double) {
        self.withinDays = withinDays; self.factor = factor
    }
}

/// The numbers behind the suggested importance of a fixture: a base for the competition, a factor for the opponent,
/// schedule factors, the lines between the levels and the rule for suggesting Sharpness.
public struct ImportanceSuggestionRules: Sendable, Equatable {
    public var leagueBase: Double
    public var cupBase: Double
    public var minorCupBase: Double
    public var friendlyBase: Double
    public var unsetBase: Double
    public var muchStrongerFactor: Double
    public var strongerFactor: Double
    public var similarFactor: Double
    public var weakerFactor: Double
    public var muchWeakerFactor: Double
    public var unsetOpponentFactor: Double
    /// The next match is "bigger" when its base times its opponent factor is at least this and greater than this one's.
    public var biggerMatchFrom: Double
    /// Tightest first; only the first step that applies is used.
    public var biggerMatchSteps: [BiggerMatchStep]
    /// This many matches or more before the fixture, within a window of `crowdedWindowDays` days that ends on the match
    /// day (so from `crowdedWindowDays − 1` days before up to the day before), take `crowdedFactor`.
    public var crowdedWindowDays: Int
    public var crowdedMatches: Int
    public var crowdedFactor: Double
    /// This many days or more since the last match, with no reduction applying, take `restedFactor`.
    public var restedAfterDays: Int
    public var restedFactor: Double
    public var highFrom: Double
    public var mediumFrom: Double
    /// Sharpness is suggested for a score below `sharpnessBelowScore`, with the next match at least
    /// `sharpnessMinDaysToNext` days later and at least `sharpnessMinPlayers` of the first eleven below `sharpnessBelow`.
    public var sharpnessBelowScore: Double
    public var sharpnessMinDaysToNext: Int
    public var sharpnessMinPlayers: Int
    public var sharpnessBelow: Double

    public init(leagueBase: Double, cupBase: Double, minorCupBase: Double, friendlyBase: Double, unsetBase: Double,
                muchStrongerFactor: Double, strongerFactor: Double, similarFactor: Double, weakerFactor: Double,
                muchWeakerFactor: Double, unsetOpponentFactor: Double, biggerMatchFrom: Double,
                biggerMatchSteps: [BiggerMatchStep], crowdedWindowDays: Int, crowdedMatches: Int, crowdedFactor: Double,
                restedAfterDays: Int, restedFactor: Double, highFrom: Double, mediumFrom: Double,
                sharpnessBelowScore: Double, sharpnessMinDaysToNext: Int, sharpnessMinPlayers: Int, sharpnessBelow: Double) {
        self.leagueBase = leagueBase; self.cupBase = cupBase; self.minorCupBase = minorCupBase
        self.friendlyBase = friendlyBase; self.unsetBase = unsetBase
        self.muchStrongerFactor = muchStrongerFactor; self.strongerFactor = strongerFactor
        self.similarFactor = similarFactor; self.weakerFactor = weakerFactor
        self.muchWeakerFactor = muchWeakerFactor; self.unsetOpponentFactor = unsetOpponentFactor
        self.biggerMatchFrom = biggerMatchFrom; self.biggerMatchSteps = biggerMatchSteps
        self.crowdedWindowDays = crowdedWindowDays; self.crowdedMatches = crowdedMatches; self.crowdedFactor = crowdedFactor
        self.restedAfterDays = restedAfterDays; self.restedFactor = restedFactor
        self.highFrom = highFrom; self.mediumFrom = mediumFrom
        self.sharpnessBelowScore = sharpnessBelowScore; self.sharpnessMinDaysToNext = sharpnessMinDaysToNext
        self.sharpnessMinPlayers = sharpnessMinPlayers; self.sharpnessBelow = sharpnessBelow
    }
}

/// Lets `EngineParameters.all` list every stored `Parameter` whatever its value type.
protocol ParameterProtocol {
    var evidence: Evidence { get }
    var source: String { get }
}

extension Parameter: ParameterProtocol {}

/// Every number a rating or selection rule uses, each with its evidence level and source, apart from the
/// weights, curves and shares that belong to a `RatingProfile`.
public struct EngineParameters: Sendable {
    public var consensusCap: Parameter<Double>
    public var balanceBonus: Parameter<Double>
    public var thresholdPenaltyPerPoint: Parameter<Double>
    public var thresholdPenaltyFloor: Parameter<Double>
    /// The role score of a role that lists no key or preferable attributes.
    public var emptyRoleScore: Parameter<Double>
    /// Highest minimum first. A familiarity below every minimum takes the last step's factor.
    public var familiaritySteps: Parameter<[FamiliarityStep]>
    public var defensivePhaseWeightIP: Parameter<Double>
    public var otherPhaseWeightIP: Parameter<Double>
    public var outOfPositionBelow: Parameter<Int>
    /// Condition (fraction of 1) to rating factor, interpolated between points and clamped at the ends.
    public var conditionCurve: Parameter<[CurvePoint]>
    /// Match sharpness (fraction of 1) to rating factor, interpolated between points and clamped at the ends.
    public var sharpnessCurve: Parameter<[CurvePoint]>
    /// Lowest `upTo` first. The first step with `upTo` at or above the jadedness gives the factor.
    public var jadednessSteps: Parameter<[JadednessStep]>
    /// The factor for a jadedness above every step.
    public var jadednessAbove: Parameter<Double>
    /// A player below this condition is kept out at every match importance.
    public var conditionFloor: Parameter<Double>
    /// A player above this jadedness is kept out of everything except high-importance matches.
    public var jadedThreshold: Parameter<Int>

    /// Condition lost over a full match at average Stamina and a load of 1.
    public var matchConditionCost: Parameter<Double>
    /// How much each Stamina point above 10 cuts the match condition cost (and each point below raises it).
    public var staminaCostPerPoint: Parameter<Double>
    /// Multiplies the match condition cost by position; every position is listed.
    public var positionConditionLoad: Parameter<[Position: Double]>
    /// Condition regained on a rest day at average Natural Fitness and medium training, by current condition.
    public var conditionRecoveryPerDay: Parameter<[CurvePoint]>
    /// Each Natural Fitness point above 10 raises daily condition recovery by this fraction (below 10 it lowers it).
    public var naturalFitnessRecoveryPerPoint: Parameter<Double>
    /// Multiplies daily condition and jadedness recovery by training intensity.
    public var trainingIntensityRecovery: Parameter<[TrainingIntensity: Double]>
    /// Match sharpness gained per minute played before the taper.
    public var sharpnessGainPerMinute: Parameter<Double>
    /// Multiplies the sharpness gain by current sharpness.
    public var sharpnessGainTaper: Parameter<[CurvePoint]>
    /// Sharpness lost per day without a match at Natural Fitness 10, from the second day after a match.
    public var sharpnessDecayPerDay: Parameter<Double>
    /// Each Natural Fitness point above 10 cuts sharpness decay by this fraction.
    public var sharpnessDecayNaturalFitnessPerPoint: Parameter<Double>
    /// Sharpness does not decay below this.
    public var sharpnessFloor: Parameter<Double>
    /// Jadedness gained per match.
    public var jadednessPerMatch: Parameter<Double>
    /// Jadedness lost per rest day at medium training.
    public var jadednessRecoveryPerDay: Parameter<Double>
    /// Jadedness does not fall below this.
    public var jadednessFloor: Parameter<Double>
    /// Minutes a starter is assumed to play.
    public var assumedMinutes: Parameter<Double>
    /// A start extends a run of consecutive starts only when it came within this many days of the next match.
    public var consecutiveStartWindowDays: Parameter<Int>

    /// Factor on a loaned-in player's match-day value, by match importance.
    public var loanedInFactor: Parameter<[Importance: Double]>
    /// By in-possession position, the steps of a run of consecutive starts; the highest step reached applies.
    public var consecutiveStartSteps: Parameter<[Position: [ConsecutiveStartStep]]>
    /// Sharpness (fraction of 1) at and above which a player needs no minutes for sharpness.
    public var sharpnessNeedFull: Parameter<Double>
    /// Sharpness (fraction of 1) at and below which a player's need for minutes is greatest.
    public var sharpnessNeedMost: Parameter<Double>
    /// The most a lesser fixture favours an unsharp player, as a fraction of his value, at greatest need.
    public var sharpnessNeedStrengthLow: Parameter<Double>
    /// The most a sharpness fixture favours an unsharp first or second eleven player, as a fraction of his value.
    public var sharpnessNeedStrengthBuild: Parameter<Double>
    /// Factor on a first or second eleven player who is already fully sharp in a sharpness fixture.
    public var fullySharpFactor: Parameter<Double>
    /// The oldest age counted as a prospect by the planner. Separate from Player Removal's prospect numbers
    /// (`RemovalRules.prospectUpToAge`, `prospectRoomFrom`, `strongProspectRoomFrom`) on purpose, because Removal has two
    /// steps of room to grow where the planner has one; change them together.
    public var prospectMaxAge: Parameter<Int>
    /// A prospect's potential ability is at least this multiple of his current ability. Change it together with
    /// `RemovalRules.prospectRoomFrom`, as `prospectMaxAge` says.
    public var prospectHeadroom: Parameter<Double>
    /// Factor on a prospect's value in a lesser fixture.
    public var developmentFactor: Parameter<Double>
    /// Lowest familiarity at which a retrainee is favoured in a low or sharpness fixture.
    public var retrainingFromFamiliarity: Parameter<Int>
    /// Lowest familiarity at which a retrainee is favoured in a medium fixture.
    public var retrainingFromFamiliarityMedium: Parameter<Int>
    /// Familiarity at and above which a retrainee is no longer favoured.
    public var retrainingUntilFamiliarity: Parameter<Int>
    /// Factor on a retrainee's value in a low or sharpness fixture.
    public var retrainingFactorLow: Parameter<Double>
    /// Factor on a retrainee's value in a medium fixture.
    public var retrainingFactorMedium: Parameter<Double>
    /// How many recent starts in one slot count as holding it.
    public var stabilityAnchorRun: Parameter<Int>
    /// Bonus, at stability 1, for having held the slot for the whole anchor run.
    public var stabilityAnchorBonus: Parameter<Double>
    /// Bonus, at stability 1, for having played the slot in the most recent match.
    public var stabilityRecentBonus: Parameter<Double>
    /// How much each match importance counts when a start today is weighed against a more important fixture later.
    public var importanceWeights: Parameter<[Importance: Double]>
    /// The most saving a player for later fixtures can cost him in one fixture, in rating points.
    public var savingCostCeiling: Parameter<Double>
    /// An adjustment that costs a left-out player less than this many rating points is not named as the reason,
    /// unless no adjustment that held him back reaches it.
    public var omissionReasonMinimumLoss: Parameter<Double>
    /// The least familiarity, in both phases, at which a player counts as an option for a slot at all.
    public var depthCoverFamiliarity: Parameter<Int>
    /// The least familiarity, in both phases, at which an option counts as solid cover.
    public var depthSolidFamiliarity: Parameter<Int>
    /// A slot with fewer solid options who are not injured (and not first choice elsewhere) than this is thin.
    public var depthThinBelow: Parameter<Int>
    /// How a player's own jadedness limit, for rest advice, differs from the standard `jadedThreshold`.
    public var restLimitRules: Parameter<RestLimitRules>
    /// A player above this share of his jadedness limit is worth watching.
    public var restWatchShare: Parameter<Double>
    /// A player more than this far above his jadedness limit needs a holiday.
    public var holidayMargin: Parameter<Int>
    /// Jadedness lost per day on holiday.
    public var holidayJadednessRecoveryPerDay: Parameter<Double>
    /// The most rest days the rest advice looks ahead for condition to reach the floor; beyond it the days are not known.
    public var restConditionEstimateDays: Parameter<Int>
    /// How quickly a player is likely to learn a new position.
    public var learnabilityRules: Parameter<LearnabilityRules>
    /// A player below this learnability is not recommended for retraining.
    public var retrainingMinimumLearnability: Parameter<Double>
    /// A player is recommended only if, once natural, he would rate at least this share of the slot's first choice.
    public var retrainingMinimumShare: Parameter<Double>
    /// The most retraining recommendations for one position.
    public var retrainingPerPosition: Parameter<Int>
    /// The class of each move between positions, and the positions a player retrains from.
    public var retrainingTransitions: Parameter<RetrainingTransitions>
    /// The weeks each class of retraining takes.
    public var retrainingWeeks: Parameter<RetrainingWeeks>
    /// How age, Versatility and a head start change the weeks.
    public var retrainingPace: Parameter<RetrainingPace>
    /// A retraining that has gained nothing over at least this many weeks has stalled.
    public var retrainingStalledAfterWeeks: Parameter<Int>
    /// The points Player Removal and the loan review give for each rule, apart from the wage rules.
    public var removalRules: Parameter<RemovalRules>
    /// The points Player Removal gives for a high wage outside both elevens.
    public var removalWageRules: Parameter<RemovalWageRules>
    /// A mutual termination's cost as a share of the wages left on the contract.
    public var mutualTerminationShare: Parameter<Double>
    /// The scores that make a removal advice critical, high or medium.
    public var removalLevels: Parameter<RemovalLevels>
    /// The points Player Removal and the loan review give, once per player, to the first choice of a slot where Depth
    /// finds cover thin, or to a player who counts as cover at a slot whose cover is at most `depthThinBelow`.
    public var removalThinCoverPoints: Parameter<Int>
    /// The numbers behind a fixture's suggested importance.
    public var importanceRules: Parameter<ImportanceSuggestionRules>

    private static let pythonSource = "rating_calculator.py (branch customizable-tactics)"
    private static let fitnessSource = "docs/Research/fm27-condition-fatigue-sharpness.md"

    public static let fm27: EngineParameters = {
        func carried(_ value: Double) -> Parameter<Double> { Parameter(value, .carriedOverFM26, source: pythonSource) }
        let matchSelectorSource = "ui/api/api_match_selector.py (branch customizable-tactics)"
        let readySelectorSource = "fm_match_ready_selector.py (branch customizable-tactics)"
        let retrainingSource = "\(readySelectorSource); docs/Research/position-retraining.md"
        let sharpnessNeedSource = "docs/Research/match-sharpness.md"
        func steps(_ pairs: [(Int, Double)]) -> [ConsecutiveStartStep] { pairs.map { ConsecutiveStartStep(starts: $0.0, factor: $0.1) } }
        return EngineParameters(
            consensusCap: carried(10),
            balanceBonus: carried(0.01),
            thresholdPenaltyPerPoint: carried(0.02),
            thresholdPenaltyFloor: carried(0.80),
            emptyRoleScore: Parameter(50, .carriedOverFM26, source: "rating_calculator.py calculate_role_score (branch customizable-tactics)"),
            familiaritySteps: Parameter(
                [FamiliarityStep(minimum: 18, factor: 1.00), FamiliarityStep(minimum: 15, factor: 0.95),
                 FamiliarityStep(minimum: 13, factor: 0.90), FamiliarityStep(minimum: 10, factor: 0.80),
                 FamiliarityStep(minimum: 8, factor: 0.60), FamiliarityStep(minimum: 5, factor: 0.35),
                 FamiliarityStep(minimum: 0, factor: 0.10)],
                .carriedOverFM26,
                source: "\(pythonSource); FM27 Match Lab Study 5 (cap 15 costs 0.26 points per game, cap 10 costs 0.85) is consistent with 0.95 and 0.80"),
            defensivePhaseWeightIP: carried(0.5),
            otherPhaseWeightIP: carried(0.7),
            outOfPositionBelow: Parameter(10, .derived, source: "the Competent step of the familiarity table: below it a player is out of position"),
            conditionCurve: Parameter(
                [CurvePoint(x: 1.00, factor: 1.00), CurvePoint(x: 0.90, factor: 0.94), CurvePoint(x: 0.80, factor: 0.82),
                 CurvePoint(x: 0.60, factor: 0.58), CurvePoint(x: 0.00, factor: 0.30)],
                .derived,
                source: "\(fitnessSource); anchors 90% and 80% from FM27 Match Lab (0.28 and 0.80 points per game)"),
            sharpnessCurve: Parameter(
                [CurvePoint(x: 1.00, factor: 1.00), CurvePoint(x: 0.75, factor: 0.92), CurvePoint(x: 0.50, factor: 0.78),
                 CurvePoint(x: 0.35, factor: 0.70), CurvePoint(x: 0.00, factor: 0.70)],
                .derived,
                source: "\(fitnessSource); anchors 75% and 50% from FM27 Match Lab (0.37 and 1.00 points per game)"),
            jadednessSteps: Parameter(
                [JadednessStep(upTo: 200, factor: 1.00), JadednessStep(upTo: 400, factor: 0.90), JadednessStep(upTo: 700, factor: 0.70)],
                .carriedOverFM26,
                source: "scoring_parameters.py JADEDNESS_THRESHOLDS and JADEDNESS_MULTIPLIERS: fresh to 200 ×1.00, fit to 400 ×0.90, tired to 700 ×0.70"),
            jadednessAbove: Parameter(
                0.40, .carriedOverFM26,
                source: "scoring_parameters.py JADEDNESS_MULTIPLIERS: jaded (701 and above) ×0.40"),
            conditionFloor: Parameter(
                0.85, .carriedOverFM26,
                source: "fm_match_ready_selector.py (\"NEVER field players below 85% condition\"; it cuts the rating below 85% "
                    + "rather than leaving the player out); docs/Research/physical-condition-claude.md (85% condition minimum for starting players)"),
            jadedThreshold: Parameter(400, .fm27Observation, source: "\(fitnessSource); FM Lens labels players \"Jaded\" above 400"),
            matchConditionCost: Parameter(
                0.25, .carriedOverFM26,
                source: "docs/Research/physical-condition.md: 100% to about 75% over 90 minutes"),
            staminaCostPerPoint: Parameter(
                0.015, .derived,
                source: "SI says Stamina is a stronger factor in FM27 (\(fitnessSource)); the size is this design's guess, three times the branch's slope"),
            positionConditionLoad: Parameter(
                Dictionary(uniqueKeysWithValues: Position.allCases.map { position in
                    switch position {
                    case .goalkeeper: (position, 0.2)
                    case .defenderCentral: (position, 0.8)
                    case .defenderLeft, .defenderRight, .wingBackLeft, .wingBackRight, .defensiveMidfielder: (position, 1.2)
                    case .midfielderLeft, .midfielderCentral, .midfielderRight, .attackingMidLeft, .attackingMidCentral,
                         .attackingMidRight, .striker: (position, 1.0)
                    }
                }),
                .carriedOverFM26,
                source: "fm_match_ready_selector.py (1.2 and 0.8) and ui/api/state_simulation.py (goalkeeper), branch customizable-tactics; no FM27 evidence"),
            conditionRecoveryPerDay: Parameter(
                [CurvePoint(x: 0.70, factor: 0.124), CurvePoint(x: 0.80, factor: 0.0813),
                 CurvePoint(x: 0.90, factor: 0.0275), CurvePoint(x: 1.00, factor: 0)],
                .carriedOverFM26,
                source: "fm-arena rest-day test quoted in \(fitnessSource) (7,000 to 8,240; 8,000 to 8,813; 9,000 to 9,275)"),
            naturalFitnessRecoveryPerPoint: Parameter(
                0.0167, .carriedOverFM26,
                source: "state_simulation.py (0.5 + NF/100, relative to Natural Fitness 10), branch customizable-tactics"),
            trainingIntensityRecovery: Parameter(
                [.low: 1.2, .medium: 1.0, .high: 0.8], .carriedOverFM26,
                source: "scoring_parameters.py, branch customizable-tactics; FM27 testers report the same direction without numbers"),
            sharpnessGainPerMinute: Parameter(
                0.001, .fm27Measured, source: "ZaZ, \(fitnessSource)"),
            sharpnessGainTaper: Parameter(
                [CurvePoint(x: 0.65, factor: 1.0), CurvePoint(x: 0.80, factor: 0.667), CurvePoint(x: 0.90, factor: 0.222)],
                .carriedOverFM26,
                source: "docs/Research/physical-condition-claude.md: 9%, 6% and 2% per 90 minutes; FM27 did not test high sharpness"),
            sharpnessDecayPerDay: Parameter(
                0.005, .fm27Measured, source: "ZaZ, \(fitnessSource); none on the day after a match"),
            sharpnessDecayNaturalFitnessPerPoint: Parameter(
                0.08, .carriedOverFM26,
                source: "docs/Research/physical-condition-claude.md: Natural Fitness 20 loses about a fifth of what 10 loses"),
            sharpnessFloor: Parameter(0.35, .fm27Observation, source: fitnessSource),
            jadednessPerMatch: Parameter(60, .carriedOverFM26, source: "fm-arena, +50 to +70 per match"),
            jadednessRecoveryPerDay: Parameter(20, .carriedOverFM26, source: "fm-arena, one rest day removes about 20"),
            jadednessFloor: Parameter(
                -500, .fm27Observation, source: "editor range; rested players sit at exactly -500 (\(fitnessSource))"),
            assumedMinutes: Parameter(90, .derived, source: "the planner does not model substitutions"),
            consecutiveStartWindowDays: Parameter(
                4, .derived,
                source: "docs/Research/player-rotation-guide.md: one match a week needs little rotation; rotation matters when matches come two or three a week"),
            loanedInFactor: Parameter(
                [.high: 1.0, .medium: 0.95, .low: 0.85, .sharpness: 0.85], .carriedOverFM26, source: matchSelectorSource),
            consecutiveStartSteps: Parameter(
                Dictionary(uniqueKeysWithValues: Position.allCases.map { position in
                    switch position {
                    case .defenderLeft, .defenderRight, .wingBackLeft, .wingBackRight, .defensiveMidfielder:
                        (position, steps([(2, 0.90), (3, 0.75), (4, 0.60)]))
                    case .midfielderLeft, .midfielderCentral, .midfielderRight, .attackingMidLeft, .attackingMidCentral,
                         .attackingMidRight, .striker:
                        (position, steps([(3, 0.90), (4, 0.80), (5, 0.70)]))
                    case .defenderCentral, .goalkeeper:
                        (position, steps([(5, 0.90), (6, 0.80)]))
                    }
                }),
                .carriedOverFM26, source: readySelectorSource),
            sharpnessNeedFull: Parameter(0.91, .carriedOverFM26, source: "\(sharpnessNeedSource): 91% and above is full sharpness"),
            sharpnessNeedMost: Parameter(
                0.50, .derived, source: "the sharpness curve's 50% anchor (FM27 Match Lab), below which the need is treated as greatest"),
            sharpnessNeedStrengthLow: Parameter(
                0.50, .derived,
                source: "the owner's decision of 13 November 2026 that an unsharp regular should get the low fixtures: at 50% sharpness a player is worth about a sixth more than a fully sharp one of the same rating once his sharpness factor (×0.78) is counted. The branch boosted by ×1.2 to ×1.4 (\(matchSelectorSource))"),
            sharpnessNeedStrengthBuild: Parameter(
                1.0, .derived, source: "a sharpness fixture exists to build sharpness, so need counts fully; this design's choice"),
            fullySharpFactor: Parameter(0.60, .carriedOverFM26, source: matchSelectorSource),
            prospectMaxAge: Parameter(21, .carriedOverFM26, source: "ui/api/api_player_removal.py (branch customizable-tactics)"),
            prospectHeadroom: Parameter(1.15, .carriedOverFM26, source: "ui/api/api_player_removal.py (branch customizable-tactics)"),
            developmentFactor: Parameter(
                1.10, .derived,
                source: "this design's size; the premise, that growth comes mainly from match time, is one FM27 tester's report in docs/Research/fm27-training-and-retraining.md"),
            retrainingFromFamiliarity: Parameter(10, .carriedOverFM26, source: retrainingSource),
            retrainingFromFamiliarityMedium: Parameter(15, .carriedOverFM26, source: retrainingSource),
            retrainingUntilFamiliarity: Parameter(18, .carriedOverFM26, source: retrainingSource),
            retrainingFactorLow: Parameter(1.15, .carriedOverFM26, source: retrainingSource),
            retrainingFactorMedium: Parameter(1.08, .carriedOverFM26, source: retrainingSource),
            stabilityAnchorRun: Parameter(
                3, .derived, source: "rescaled from ui/api/stability.py (branch customizable-tactics); three matches running counts as holding a slot"),
            stabilityAnchorBonus: Parameter(
                0.05, .derived, source: "rescaled from ui/api/stability.py (branch customizable-tactics), which moved a rating by up to about 2 to 5 points"),
            stabilityRecentBonus: Parameter(
                0.02, .derived, source: "rescaled from ui/api/stability.py (branch customizable-tactics), which moved a rating by up to about 2 to 5 points"),
            importanceWeights: Parameter(
                [.high: 3.0, .medium: 1.5, .low: 0.8, .sharpness: 0.1], .carriedOverFM26,
                source: "scoring_parameters.py IMPORTANCE_WEIGHTS, branch customizable-tactics"),
            savingCostCeiling: Parameter(
                1_000, .derived,
                source: "five times the highest possible rating: at that cost a player starts only when nobody else can, "
                    + "and values stay far below the assignment solver's empty-slot cost"),
            omissionReasonMinimumLoss: Parameter(
                1.0, .derived,
                source: "an adjustment that costs a player less than one rating point is not given as the reason he was left out"),
            depthCoverFamiliarity: Parameter(
                10, .derived, source: "the Competent step of the familiarity table: below it a player is out of position"),
            depthSolidFamiliarity: Parameter(
                15, .derived,
                source: "design spec 8.7's starting rule; FM27 Match Lab Study 5 puts a cap of 15 at 0.26 points a game and a cap of 10 at 0.85 (docs/Research/fm27-tactical-effectiveness-and-roles.md)"),
            depthThinBelow: Parameter(2, .derived, source: "design spec 8.7's starting rule: fewer than two is thin"),
            restLimitRules: Parameter(
                RestLimitRules(
                    oldestFromAge: 32, oldestBase: 300, olderFromAge: 30, olderBase: 350, youngUnderAge: 19, youngBase: 350,
                    naturalFitnessBelow: 10, naturalFitnessLowChange: -50, naturalFitnessFrom: 15, naturalFitnessHighChange: 50,
                    staminaBelow: 10, staminaLowChange: -50, staminaFrom: 15, staminaHighChange: 30,
                    injuryPronenessFrom: 15, injuryPronenessHighChange: -100, injuryPronenessUpTo: 8, injuryPronenessLowChange: 50,
                    lowest: 200, highest: 550),
                .carriedOverFM26,
                source: "\(readySelectorSource) _get_adjusted_fatigue_threshold; no FM27 evidence beyond the 400 line"),
            restWatchShare: Parameter(
                0.8, .carriedOverFM26, source: "ui/api/api_rest_advisor.py (branch customizable-tactics): a warning at 80% of the limit"),
            holidayMargin: Parameter(
                200, .derived,
                source: "docs/Research/physical-condition-claude.md: warnings at 400 to 500, the rest icon near 600"),
            holidayJadednessRecoveryPerDay: Parameter(
                50, .carriedOverFM26,
                source: "docs/Research/jadedness-fatigue.md: rest sessions with a holiday recovered 152 in three days"),
            restConditionEstimateDays: Parameter(
                14, .derived, source: "this design's choice: an estimate is given up to two weeks ahead"),
            learnabilityRules: Parameter(
                LearnabilityRules(
                    versatilityWeight: 0.45, ageWeight: 0.25, professionalismWeight: 0.20, roomToGrowWeight: 0.10,
                    attributeMaximum: 20, lowVersatilityBelow: 10, lowVersatilityFactor: 0.3,
                    ageSteps: [AgeFactorStep(upTo: 20, factor: 1.0), AgeFactorStep(upTo: 23, factor: 0.95),
                               AgeFactorStep(upTo: 25, factor: 0.70), AgeFactorStep(upTo: 27, factor: 0.40),
                               AgeFactorStep(upTo: 29, factor: 0.15)],
                    ageAbove: 0.05, roomToGrowSpan: 30),
                .carriedOverFM26,
                source: "\(trainingAdvisorSource): the training score and calculate_age_factor_strategic's general age steps"),
            retrainingMinimumLearnability: Parameter(
                0.40, .derived,
                source: "\(trainingAdvisorSource) asked for a training score above 0.6 or an age under 24; one line between them"),
            retrainingMinimumShare: Parameter(
                0.80, .carriedOverFM26,
                source: "docs/Research/lineup-depth-strategy.md and docs/Research/player-rotation-guide.md: cover can be about 20% worse than the first choice"),
            retrainingPerPosition: Parameter(
                2, .carriedOverFM26, source: "\(trainingAdvisorSource): quotas of one or two per position"),
            retrainingTransitions: Parameter(
                RetrainingTransitions(
                    pairs: transitions([
                        // Fluid
                        (.defenderLeft, .wingBackLeft, .fluid), (.defenderRight, .wingBackRight, .fluid),
                        (.wingBackLeft, .defenderLeft, .fluid), (.wingBackRight, .defenderRight, .fluid),
                        (.defensiveMidfielder, .midfielderCentral, .fluid), (.midfielderCentral, .defensiveMidfielder, .fluid),
                        (.attackingMidLeft, .midfielderLeft, .fluid), (.attackingMidRight, .midfielderRight, .fluid),
                        (.midfielderLeft, .attackingMidLeft, .fluid), (.midfielderRight, .attackingMidRight, .fluid),
                        (.attackingMidCentral, .midfielderCentral, .fluid), (.midfielderCentral, .attackingMidCentral, .fluid),
                        (.striker, .attackingMidCentral, .fluid), (.attackingMidCentral, .striker, .fluid),
                        // Structural
                        (.defensiveMidfielder, .defenderCentral, .structural), (.defenderCentral, .defensiveMidfielder, .structural),
                        (.attackingMidCentral, .defensiveMidfielder, .structural), (.defensiveMidfielder, .attackingMidCentral, .structural),
                        (.wingBackLeft, .midfielderLeft, .structural), (.wingBackRight, .midfielderRight, .structural),
                        (.midfielderLeft, .wingBackLeft, .structural), (.midfielderRight, .wingBackRight, .structural),
                        (.wingBackLeft, .attackingMidLeft, .structural), (.wingBackRight, .attackingMidRight, .structural),
                        // Spatial
                        (.attackingMidRight, .midfielderCentral, .spatial), (.attackingMidLeft, .midfielderCentral, .spatial),
                        (.striker, .attackingMidRight, .spatial), (.striker, .attackingMidLeft, .spatial),
                        (.defenderCentral, .striker, .spatial), (.striker, .defenderCentral, .spatial),
                        // Inversion
                        (.striker, .defenderRight, .inversion), (.striker, .defenderLeft, .inversion),
                        (.goalkeeper, .defenderCentral, .inversion), (.defenderCentral, .goalkeeper, .inversion),
                        (.midfielderCentral, .goalkeeper, .inversion),
                    ]),
                    defensiveGroup: [.goalkeeper, .defenderLeft, .defenderRight, .defenderCentral, .wingBackLeft, .wingBackRight,
                                     .defensiveMidfielder],
                    attackingGroup: [.striker, .attackingMidLeft, .attackingMidRight, .attackingMidCentral],
                    sameGroupDifficulty: .structural, otherDifficulty: .spatial, fromFamiliarity: 18),
                .carriedOverFM26,
                source: "scoring_parameters.py POSITION_TRANSITIONS and get_retraining_difficulty (branch customizable-tactics); "
                    + "retraining from a position at 18 or over is this design's choice"),
            retrainingWeeks: Parameter(
                RetrainingWeeks(fluid: WeekRange(fewest: 4, most: 8), structural: WeekRange(fewest: 12, most: 20),
                                spatial: WeekRange(fewest: 24, most: 36)),
                .carriedOverFM26,
                source: "scoring_parameters.py RETRAINING_DIFFICULTY (branch customizable-tactics); an inversion is not recommended"),
            retrainingPace: Parameter(
                RetrainingPace(
                    ageSteps: [AgeFactorStep(upTo: 21, factor: 1.0), AgeFactorStep(upTo: 26, factor: 1.3),
                               AgeFactorStep(upTo: 31, factor: 1.6)],
                    ageAbove: 1.9, highVersatilityFrom: 15, highVersatilityFactor: 0.6, lowVersatilityUpTo: 9,
                    lowVersatilityFactor: 1.5,
                    headStartSteps: [FamiliarityStep(minimum: 13, factor: 0.5), FamiliarityStep(minimum: 10, factor: 0.7)],
                    minimumWeeks: 4),
                .carriedOverFM26,
                source: "ui/api/api_training_advisor.py (branch customizable-tactics): age plasticity 1.0, 0.7, 0.4 and 0.1 "
                    + "taken as 2 − plasticity, and the head start; docs/Research/position-retraining-strategy.md: three to six "
                    + "months with high Versatility, 18 months or never with low. The floor of 4 weeks is the fluid class's shortest"),
            retrainingStalledAfterWeeks: Parameter(6, .derived, source: "this design's choice"),
            removalRules: Parameter(
                RemovalRules(
                    notFullTimePoints: 50, firstElevenPoints: -40, secondElevenPoints: -20, neitherElevenPoints: 15,
                    weakestShare: 0.30, weakestPoints: 30,
                    farBelowAverageShare: 0.85, farBelowAveragePoints: 25, belowAveragePoints: 10,
                    contractEndingSoonUpTo: 6, contractEndingSoonPoints: 25, contractEndingUpTo: 12, contractEndingPoints: 15,
                    consistencyLowBelow: 8, consistencyLowPoints: 25, consistencyFairUpTo: 8, consistencyFairPoints: 15,
                    importantMatchesBelow: 8, importantMatchesPoints: 20, injuryPronenessAbove: 14, injuryPronenessPoints: 25,
                    professionalismLowBelow: 8, professionalismLowPoints: 25,
                    professionalismFairUpTo: 9, professionalismFairPoints: 15,
                    ambitionBelow: 6, ambitionPoints: 25, controversyAbove: 16, controversyPoints: 25,
                    temperamentBelow: 8, temperamentPoints: 15,
                    falseProspectUpToAge: 20, falseProspectTargetAge: 24, falseProspectRateAbove: 15,
                    falseProspectProfessionalismBelow: 14, falseProspectPoints: 35,
                    stallingFromAge: 23, stallingUpToAge: 24, stallingRoomBelow: 0.10, stallingPoints: 20,
                    prospectUpToAge: 21, strongProspectRoomFrom: 0.30, strongProspectPoints: -30,
                    prospectRoomFrom: 0.15, prospectPoints: -15,
                    mentorFromAge: 30, mentorProfessionalismFrom: 16, mentorDeterminationFrom: 15,
                    mentorPoints: -40, lesserMentorPoints: -20,
                    noGrowthFromAge: 30, noGrowthRoomBelow: 0.05, noGrowthPoints: 10, oldFromAge: 32, oldPoints: 5,
                    terminateWithinMonths: 12,
                    loanReview: LoanReviewRules(
                        weakestPoints: 30, firstElevenPoints: -30, secondElevenPoints: -15, neitherElevenPoints: 20,
                        farBelowAveragePoints: 25, belowAveragePoints: 10, consistencyLowPoints: 20, importantMatchesPoints: 15,
                        injuryPronenessPoints: 25, endEarlyFrom: 50, doNotExtendFrom: 25)),
                .carriedOverFM26,
                source: "\(removalSource); a full-time contract with 0 months left is read as no contract, the owner's "
                    + "decision of 13 November 2026, to be double checked against the game"),
            removalWageRules: Parameter(
                RemovalWageRules(highMultiple: 1.5, highPoints: 35, abovePoints: 20),
                .derived,
                source: "\(removalSource) compared wages with fixed amounts, which depend on the currency unit; "
                    + "here a wage is compared with the squad's median"),
            mutualTerminationShare: Parameter(
                0.55, .carriedOverFM26,
                source: "docs/Research/player-management-and-sales.md: a mutual termination often costs 50% to 60% of the remaining contract; "
                    + "\(removalSource) used 0.55"),
            removalLevels: Parameter(
                RemovalLevels(critical: 80, high: 50, medium: 30), .carriedOverFM26, source: removalSource),
            removalThinCoverPoints: Parameter(
                -30, .derived,
                source: "this design's choice after the advisors were run on the real squad: Player Removal told the only goalkeeper to leave"),
            importanceRules: Parameter(
                ImportanceSuggestionRules(
                    leagueBase: 80, cupBase: 60, minorCupBase: 30, friendlyBase: 10, unsetBase: 50,
                    muchStrongerFactor: 1.2, strongerFactor: 1.1, similarFactor: 1.0, weakerFactor: 0.8,
                    muchWeakerFactor: 0.6, unsetOpponentFactor: 1.0, biggerMatchFrom: 80,
                    biggerMatchSteps: [BiggerMatchStep(withinDays: 2, factor: 0.6), BiggerMatchStep(withinDays: 3, factor: 0.7),
                                       BiggerMatchStep(withinDays: 4, factor: 0.9)],
                    crowdedWindowDays: 7, crowdedMatches: 2, crowdedFactor: 0.8, restedAfterDays: 7, restedFactor: 1.1,
                    highFrom: 85, mediumFrom: 50,
                    sharpnessBelowScore: 50, sharpnessMinDaysToNext: 4, sharpnessMinPlayers: 3, sharpnessBelow: 0.70),
                .carriedOverFM26,
                source: "scoring_parameters.py (branch customizable-tactics; its automatic importance tables, never called by the old app); "
                    + "docs/Research/player-rotation-guide.md. Nothing is published for FM27. The branch's table needed the stage of the "
                    + "competition and the state of the title race, which a fixture does not carry: league is its in-contention value, "
                    + "cup lies between its early round and quarter-final"))
    }()

    private static let removalSource = "ui/api/api_player_removal.py (branch customizable-tactics)"

    private static let trainingAdvisorSource = "fm_training_advisor.py (branch customizable-tactics)"

    private static func transitions(_ list: [(Position, Position, RetrainingDifficulty)]) -> [PositionTransition: RetrainingDifficulty] {
        Dictionary(uniqueKeysWithValues: list.map { (PositionTransition(from: $0.0, to: $0.1), $0.2) })
    }

    /// Every stored parameter, found by reflection so a new one cannot be left out.
    public var all: [(name: String, evidence: Evidence, source: String)] {
        Mirror(reflecting: self).children.compactMap { child in
            guard let label = child.label, let parameter = child.value as? any ParameterProtocol else { return nil }
            return (label, parameter.evidence, parameter.source)
        }
    }
}
