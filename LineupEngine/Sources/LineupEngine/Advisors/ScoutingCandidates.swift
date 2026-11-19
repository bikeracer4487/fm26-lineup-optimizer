import Foundation

/// Where a pasted player would stand at a slot today, best first.
public enum CandidateLevel: String, CaseIterable, Sendable { case wouldStart, wouldMakeSecond, wouldCountAsCover, belowCover }

/// The needs a pasted player could answer.
public enum NeedAnswer: String, CaseIterable, Sendable { case betterPlayerToday, moreDepth, betterPlayerLater }

/// A pasted player at one slot he can play.
public struct CandidateSlot: Equatable, Sendable {
    public let slot: SlotID
    public let rating: Double
    public let ipFamiliarity: Int
    public let oopFamiliarity: Int
    /// Both familiarities are at or over `depthSolidFamiliarity`.
    public let isSolid: Bool
    public let level: CandidateLevel
    /// The first and second choice among those staying; nil when the slot has none.
    public let firstChoice: Rival?
    public let secondChoice: Rival?
    /// His rating over the first choice's, minus 1; nil with no first choice.
    public let marginOverFirst: Double?
    /// He would start at a slot with a nobody or weak need and is himself under the weak line: his own gap, worked
    /// out as the need's is (by ability at the goalkeeper's slot).
    public let stillWeakBy: Double?
    /// Task 4 fills this in; nil here.
    public let later: SlotOutlook?
    /// `betterPlayerToday`: a better-player need at the slot where he would start. `moreDepth`: a depth need at the
    /// slot where Depth would count him as cover (solid, and at or over `depthCoverShare` of the first choice's rating,
    /// or solid alone with no first choice); his level does not decide it.
    public let answers: Set<NeedAnswer>
}

/// A hidden attribute of a pasted player on the wrong side of its line.
public struct CandidateCaution: Equatable, Sendable {
    public let attribute: Attribute
    public let value: Int
}

extension Scouting {
    private static let candidateNoise = 1e-9

    /// Whether a pasted player is one the owner holds: both keys are FMRTE ids and equal; or his club or the club he
    /// is loaned to is `ownClub`; or a held player has the same normalised name, age and potential ability.
    public static func isHeld(_ pasted: Player, among held: [Player], ownClub: String?) -> Bool {
        if let id = pasted.id.fmrteID, held.contains(where: { $0.id.fmrteID == id }) { return true }
        if let own = ownClub.map(PlayerID.normalise) {
            if let club = pasted.club, PlayerID.normalise(club) == own { return true }
            if let loanedTo = pasted.loanedTo, PlayerID.normalise(loanedTo) == own { return true }
        }
        let name = PlayerID.normalise(pasted.name)
        return held.contains {
            PlayerID.normalise($0.name) == name && $0.age == pasted.age && $0.potentialAbility == pasted.potentialAbility
        }
    }

    /// His judgement at each slot of `tactic` he can play (familiarity at or over `depthCoverFamiliarity` in both
    /// phases), in the tactic's order. `squad` is the staying squad, the held players without `needs.going`.
    /// Throws `RatingError` for a missing familiarity or attribute.
    static func slotsToday(for candidate: Player, tactic: Tactic, needs: ScoutingNeeds, squad: [Player],
                           ownClub: String?, catalog: RoleCatalog, profile: RatingProfile,
                           parameters: EngineParameters) throws -> [CandidateSlot] {
        func familiarity(_ position: Position) throws -> Int {
            guard let value = candidate.familiarity[position] else {
                throw RatingError.missingFamiliarity(player: candidate.name, position: position)
            }
            return value
        }
        let engine = RatingEngine(profile: profile, parameters: parameters, configuration: .fm27)
        let coverFrom = parameters.depthCoverFamiliarity.value
        let solidFrom = parameters.depthSolidFamiliarity.value
        let offset = parameters.ratingAbilityOffset.value
        var slots: [CandidateSlot] = []
        for assignment in try tactic.assignments(catalog: catalog) {
            let ip = try familiarity(assignment.ipPosition), oop = try familiarity(assignment.oopPosition)
            guard ip >= coverFrom, oop >= coverFrom else { continue }
            let slot = assignment.slot
            let rating = try engine.rating(for: candidate, in: assignment).value
            let rivals = try Development.rivals(at: slot, tiers: needs.elevens.tiers, squad: squad, ownClub: ownClub,
                                                parameters: parameters)
            let secondPlace = needs.elevens.second.first { $0.slot == slot }

            let level: CandidateLevel
            if let first = rivals.first {
                if rating + candidateNoise >= first.rating {
                    level = .wouldStart
                } else if secondPlace == nil || secondPlace?.isOutOfPosition == true
                            || rivals.second.map({ rating + candidateNoise >= $0.rating }) == true {
                    level = .wouldMakeSecond
                } else if rating + candidateNoise >= parameters.depthCoverShare.value * first.rating {
                    level = .wouldCountAsCover
                } else {
                    level = .belowCover
                }
            } else {
                level = .wouldStart
            }

            var answers: Set<NeedAnswer> = []
            var stillWeakBy: Double?
            if let need = needs.betterPlayers.first(where: { $0.slot == slot }), level == .wouldStart {
                answers.insert(.betterPlayerToday)
                if need.kind != .ageing {
                    let isKeeper = assignment.ipPosition == .goalkeeper
                    let gap: Double?
                    if isKeeper {
                        gap = needs.outfieldAverageAbility.map {
                            abilityGap(ability: candidate.currentAbility, averageAbility: $0, offset: offset)
                        }
                    } else {
                        gap = needs.outfieldAverageRating.map { ratingGap(rating: rating, average: $0) }
                    }
                    if let gap, gap + candidateNoise >= 1 - parameters.scoutingWeakShare.value { stillWeakBy = gap }
                }
            }
            let isSolid = ip >= solidFrom && oop >= solidFrom
            // Depth would count him as cover: solid, and within the cover share of the first choice (no line without one).
            let countsAsCover = isSolid && (rivals.first.map {
                rating + candidateNoise >= parameters.depthCoverShare.value * $0.rating } ?? true)
            if needs.moreDepth.contains(where: { $0.depth.slot == slot }), countsAsCover {
                answers.insert(.moreDepth)
            }
            slots.append(CandidateSlot(
                slot: slot, rating: rating, ipFamiliarity: ip, oopFamiliarity: oop, isSolid: isSolid, level: level,
                firstChoice: rivals.first, secondChoice: rivals.second,
                marginOverFirst: rivals.first.map { rating / $0.rating - 1 }, stillWeakBy: stillWeakBy, later: nil,
                answers: answers))
        }
        return slots
    }

    /// One caution for each line he is on the wrong side of, in this order: Consistency, Important Matches, Injury
    /// Proneness, Controversy, Temperament, Professionalism. Throws `RatingError.missingAttribute`.
    static func cautions(for candidate: Player, parameters: EngineParameters) throws -> [CandidateCaution] {
        let rules = parameters.removalRules.value
        func value(_ attribute: Attribute) throws -> Int {
            guard let value = candidate.attributes[attribute] else {
                throw RatingError.missingAttribute(player: candidate.name, attribute: attribute)
            }
            return value
        }
        let consistency = try value(.consistency), importantMatches = try value(.importantMatches)
        let injuryProneness = try value(.injuryProneness), controversy = try value(.controversy)
        let temperament = try value(.temperament), professionalism = try value(.professionalism)
        var found: [CandidateCaution] = []
        if consistency < rules.consistencyLowBelow { found.append(CandidateCaution(attribute: .consistency, value: consistency)) }
        if importantMatches < rules.importantMatchesBelow {
            found.append(CandidateCaution(attribute: .importantMatches, value: importantMatches))
        }
        if injuryProneness > rules.injuryPronenessAbove {
            found.append(CandidateCaution(attribute: .injuryProneness, value: injuryProneness))
        }
        if controversy > rules.controversyAbove { found.append(CandidateCaution(attribute: .controversy, value: controversy)) }
        if temperament < rules.temperamentBelow { found.append(CandidateCaution(attribute: .temperament, value: temperament)) }
        if professionalism < rules.professionalismLowBelow {
            found.append(CandidateCaution(attribute: .professionalism, value: professionalism))
        }
        return found
    }
}
