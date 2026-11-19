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
    /// His reach at the slot, when he is `developingUpToAge` or under; nil otherwise.
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
    private static let levelOrder = CandidateLevel.allCases

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

// MARK: The list

public enum CandidatePart: String, CaseIterable, Sendable { case answersToday, answersLater, wouldStartElsewhere, rest }
public enum CandidateOrder: String, CaseIterable, Sendable { case today, later }

public struct Candidate: Equatable, Sendable, Identifiable {
    public var id: PlayerID { player.id }
    /// As pasted.
    public let player: Player
    /// The slots he can play, in the tactic's order; each has `later` when he is `developingUpToAge` or under.
    public let slots: [CandidateSlot]
    /// nil when he can play no slot of the tactic.
    public let headline: SlotID?
    /// The need his headline slot answers; nil when it answers none.
    public let headlineAnswer: NeedAnswer?
    public let part: CandidatePart
    /// `developingUpToAge` or under: his estimate, his slots' outlooks, and `best` his headline slot's when it has
    /// a level, so `AdvisorText.reachLine`, `reachWorking` and `standing` read as they do for a squad player.
    public let outlook: Outlook?
    /// At a headline slot with no first choice, for a player with an outlook: whether his reach rating there clears
    /// the weak line. nil otherwise.
    public let reachClearsWeakLine: Bool?
    /// He is at or over `firstChoiceAgeNamedFrom`.
    public let isAgeNamed: Bool
    public let cautions: [CandidateCaution]
    public let basis: Evidence

    var headlineSlot: CandidateSlot? { headline.flatMap { slot in slots.first { $0.slot == slot } } }
}

public struct CandidateGroup: Equatable, Sendable {
    public let part: CandidatePart
    /// nil for `wouldStartElsewhere` and `rest`, which are one group each.
    public let slot: SlotID?
    public let answer: NeedAnswer?
    public let candidates: [Candidate]
}

public struct CandidatesReport: Equatable, Sendable {
    /// In paste order, without the players already held.
    public let candidates: [Candidate]
    /// The names of the pasted players already held, in paste order.
    public let leftOut: [String]
    let betterPlayerSlots: [SlotID]
    let moreDepthSlots: [SlotID]

    /// The groups in order, without empty ones.
    public func groups(orderedBy order: CandidateOrder) -> [CandidateGroup] {
        func members(_ part: CandidatePart, _ slot: SlotID?, _ answer: NeedAnswer?) -> [Candidate] {
            candidates.filter {
                $0.part == part && $0.headlineAnswer == answer && (slot == nil || $0.headline == slot)
            }
        }
        var found: [CandidateGroup] = []
        func add(_ part: CandidatePart, _ slot: SlotID?, _ answer: NeedAnswer?) {
            let list = members(part, slot, answer)
            guard !list.isEmpty else { return }
            found.append(CandidateGroup(part: part, slot: slot, answer: answer,
                                        candidates: Self.sorted(list, part: part, order: order)))
        }
        for slot in betterPlayerSlots { add(.answersToday, slot, .betterPlayerToday) }
        for slot in moreDepthSlots { add(.answersToday, slot, .moreDepth) }
        for slot in betterPlayerSlots { add(.answersLater, slot, .betterPlayerLater) }
        add(.wouldStartElsewhere, nil, nil)
        add(.rest, nil, nil)
        return found
    }

    private static let noise = 1e-9

    /// `value` greatest first, a nil value counting as the greatest; the key breaks every tie.
    private static func sorted(_ list: [Candidate], part: CandidatePart, order: CandidateOrder) -> [Candidate] {
        func value(_ c: Candidate) -> Double? {
            guard let slot = c.headlineSlot else { return -.infinity }
            switch part {
            case .wouldStartElsewhere, .rest:
                return slot.marginOverFirst
            case .answersToday, .answersLater:
                switch order {
                case .today: return slot.rating
                case .later: return slot.later?.reachRating ?? slot.rating
                }
            }
        }
        return list.sorted { a, b in
            let x = value(a), y = value(b)
            switch (x, y) {
            case (nil, nil): break
            case (nil, _?): return true
            case (_?, nil): return false
            case (let x?, let y?):
                if abs(x - y) > noise { return x > y }
            }
            return a.player.id.key < b.player.id.key
        }
    }
}

extension Scouting {
    /// Throws what `slotsToday`, `cautions` and `Reach.estimate` throw.
    public static func candidates(pasted: [Player], held: [Player], ownClub: String?, tactic: Tactic,
                                  needs: ScoutingNeeds, catalog: RoleCatalog, profile: RatingProfile,
                                  parameters: EngineParameters) throws -> CandidatesReport {
        let goingIDs = Set(needs.going.map(\.player))
        let staying = held.filter { !goingIDs.contains($0.id) }
        let assignments = try tactic.assignments(catalog: catalog)
        let offset = parameters.ratingAbilityOffset.value
        let weakShare = parameters.scoutingWeakShare.value
        let betterSlots = needs.betterPlayers.map(\.slot)
        let depthSlots = needs.moreDepth.map(\.depth.slot)

        var found: [Candidate] = []
        var leftOut: [String] = []
        for player in pasted {
            if isHeld(player, among: held, ownClub: ownClub) { leftOut.append(player.name); continue }
            var slots = try slotsToday(for: player, tactic: tactic, needs: needs, squad: staying, ownClub: ownClub,
                                       catalog: catalog, profile: profile, parameters: parameters)
            var estimate: ReachEstimate?
            if player.age <= parameters.developingUpToAge.value, player.currentAbility > 0 {
                let reach = try Reach.estimate(for: player, parameters: parameters)
                estimate = reach
                slots = try slots.map { slot in
                    let rivals = try Development.rivals(at: slot.slot, tiers: needs.elevens.tiers, squad: staying,
                                                        ownClub: ownClub, parameters: parameters)
                    let later = Development.slotOutlook(for: player, estimate: reach, rating: slot.rating, at: slot.slot,
                                                        rivals: rivals, parameters: parameters)
                    var answers = slot.answers
                    if betterSlots.contains(slot.slot), later.level == .couldPassFirst { answers.insert(.betterPlayerLater) }
                    return CandidateSlot(
                        slot: slot.slot, rating: slot.rating, ipFamiliarity: slot.ipFamiliarity,
                        oopFamiliarity: slot.oopFamiliarity, isSolid: slot.isSolid, level: slot.level,
                        firstChoice: slot.firstChoice, secondChoice: slot.secondChoice,
                        marginOverFirst: slot.marginOverFirst, stillWeakBy: slot.stillWeakBy, later: later,
                        answers: answers)
                }
            }

            // The headline slot and the answer it gives.
            var headline: CandidateSlot?
            var headlineAnswer: NeedAnswer?
            func first(in order: [SlotID], answering answer: NeedAnswer) -> CandidateSlot? {
                for slot in order { if let s = slots.first(where: { $0.slot == slot }), s.answers.contains(answer) { return s } }
                return nil
            }
            if let s = first(in: betterSlots, answering: .betterPlayerToday) {
                (headline, headlineAnswer) = (s, .betterPlayerToday)
            } else if let s = first(in: depthSlots, answering: .moreDepth) {
                (headline, headlineAnswer) = (s, .moreDepth)
            } else if let s = first(in: betterSlots, answering: .betterPlayerLater) {
                (headline, headlineAnswer) = (s, .betterPlayerLater)
            } else {
                for s in slots {
                    guard let current = headline else { headline = s; continue }
                    let a = levelOrder.firstIndex(of: s.level)!, b = levelOrder.firstIndex(of: current.level)!
                    if a != b { if a < b { headline = s }; continue }
                    // Greatest margin; none counts as greatest. An earlier slot wins a tie.
                    switch (s.marginOverFirst, current.marginOverFirst) {
                    case (nil, nil): break
                    case (nil, _?): headline = s
                    case (_?, nil): break
                    case (let x?, let y?): if x > y + candidateNoise { headline = s }
                    }
                }
            }
            let part: CandidatePart
            switch headlineAnswer {
            case .betterPlayerToday?, .moreDepth?: part = .answersToday
            case .betterPlayerLater?: part = .answersLater
            case nil: part = headline?.level == .wouldStart ? .wouldStartElsewhere : .rest
            }

            var outlook: Outlook?
            if let estimate {
                let best = headline?.later.flatMap { $0.level == nil ? nil : $0 }
                outlook = Outlook(player: player.id, estimate: estimate, slots: slots.compactMap(\.later), best: best,
                                  level: best?.level, average: nil)
            }

            var clearsWeakLine: Bool?
            if let estimate, let headline, headline.firstChoice == nil, let later = headline.later {
                let isKeeper = assignments.first { $0.slot == headline.slot }?.ipPosition == .goalkeeper
                let line = (isKeeper ? needs.outfieldAverageAbility : needs.outfieldAverageRating).map { $0 * weakShare }
                if let line {
                    let reach = isKeeper ? offset + estimate.reach : later.reachRating
                    clearsWeakLine = reach + candidateNoise >= line
                }
            }

            var evidence = [needs.basis, parameters.depthCoverShare.evidence, parameters.depthCoverFamiliarity.evidence,
                            parameters.depthSolidFamiliarity.evidence, parameters.ratingAbilityOffset.evidence,
                            parameters.scoutingWeakShare.evidence, parameters.removalRules.evidence]
            if estimate != nil {
                evidence += [parameters.growthPerSeason.evidence, parameters.growthProfessionalismRates.evidence,
                             parameters.growthAmbitionAtOne.evidence, parameters.growthDeterminationAtOne.evidence,
                             parameters.growthPersonalityFullFrom.evidence, parameters.markedlyLowerShare.evidence,
                             parameters.markedlyLowerShareYoungest.evidence, parameters.firstChoiceAgeNamedFrom.evidence]
            }
            found.append(Candidate(
                player: player, slots: slots, headline: headline?.slot, headlineAnswer: headlineAnswer, part: part,
                outlook: outlook, reachClearsWeakLine: clearsWeakLine,
                isAgeNamed: player.age >= parameters.firstChoiceAgeNamedFrom.value,
                cautions: try cautions(for: player, parameters: parameters), basis: Evidence.weakest(evidence)!))
        }
        return CandidatesReport(candidates: found, leftOut: leftOut, betterPlayerSlots: betterSlots,
                                moreDepthSlots: depthSlots)
    }
}
