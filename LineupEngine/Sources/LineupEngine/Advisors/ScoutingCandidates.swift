import Foundation

/// Where a pasted player would stand at a slot today, best first.
public enum CandidateLevel: String, CaseIterable, Sendable { case wouldStart, wouldMakeSecond, wouldCountAsCover, belowCover }

/// The needs a pasted player could answer.
public enum NeedAnswer: String, CaseIterable, Sendable { case betterPlayerToday, moreDepth, betterPlayerLater }

/// His reach set against the weak line at a slot with no first choice, as the text gives it.
public enum ReachFigure: Equatable, Sendable {
    /// An outfield slot: his reach rating there.
    case rating(Double)
    /// The goalkeeper's slot, measured by ability: his reach as ability.
    case ability(Double)
}

/// Whether his reach clears the weak line at a slot with no first choice to compare him with.
public struct WeakLineReach: Equatable, Sendable {
    public let reach: ReachFigure
    public let clears: Bool
}

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
    /// The first choice fills in at the slot out of position (familiarity under `depthCoverFamiliarity` in a phase).
    public let firstChoiceIsOutOfPosition: Bool
    /// His rating over the first choice's, minus 1; nil with no first choice.
    public let marginOverFirst: Double?
    /// He would start at a slot with a nobody or weak need and is himself on the weak line: his own gap, measured as
    /// the need's is (by ability at the goalkeeper's slot).
    public let stillWeakBy: WeakGap?
    /// His reach at the slot, when he is `developingUpToAge` or under; nil otherwise.
    public let later: SlotOutlook?
    /// With `later` and no first choice, when the outfield first choices have an average: his reach against the weak
    /// line. nil otherwise.
    public let laterAgainstWeakLine: WeakLineReach?
    /// `betterPlayerToday`: a better-player need at the slot where he would start. `moreDepth`: a depth need at the
    /// slot where Depth would count him as cover (`Depth.isCover`); his level does not decide it. `betterPlayerLater`:
    /// a better-player need at the slot where his reach could pass the first choice.
    public let answers: Set<NeedAnswer>

    /// His reach rating at the slot over what the first choice there is compared at, minus 1; nil without a reach or a
    /// first choice.
    public var reachMargin: Double? {
        guard let later, let first = later.firstChoice else { return nil }
        return later.reachRating / first.compared - 1
    }

    /// The same slot with his reach.
    func with(later: SlotOutlook, against weakLine: WeakLineReach?, answers: Set<NeedAnswer>) -> CandidateSlot {
        CandidateSlot(slot: slot, rating: rating, ipFamiliarity: ipFamiliarity, oopFamiliarity: oopFamiliarity,
                      isSolid: isSolid, level: level, firstChoice: firstChoice, secondChoice: secondChoice,
                      firstChoiceIsOutOfPosition: firstChoiceIsOutOfPosition, marginOverFirst: marginOverFirst,
                      stillWeakBy: stillWeakBy, later: later, laterAgainstWeakLine: weakLine, answers: answers)
    }
}

/// A hidden attribute of a pasted player on the wrong side of its line.
public struct CandidateCaution: Equatable, Sendable {
    public let attribute: Attribute
    public let value: Int
}

/// A pasted player the owner has hidden, as he is known again in a later paste: his name as pasted and his potential
/// ability. The search grid has no id, and his age changes at his birthday, so neither is used. Every key is required
/// when one is read.
public struct HiddenCandidate: Codable, Hashable, Sendable {
    public let name: String
    public let potentialAbility: Int

    public init(name: String, potentialAbility: Int) {
        self.name = name; self.potentialAbility = potentialAbility
    }

    public init(_ player: Player) {
        self.init(name: player.name, potentialAbility: player.potentialAbility)
    }

    /// The same normalised name and the same potential ability. Two namesakes with one potential ability both match.
    public func matches(_ player: Player) -> Bool {
        potentialAbility == player.potentialAbility && PlayerID.normalise(name) == PlayerID.normalise(player.name)
    }
}

extension Scouting {

    /// Whether a pasted player is one the owner has hidden: some entry of `hidden` matches him.
    public static func isHidden(_ pasted: Player, among hidden: [HiddenCandidate]) -> Bool {
        hidden.contains { $0.matches(pasted) }
    }

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
        let engine = RatingEngine(profile: profile, parameters: parameters, configuration: .fm27)
        let solidFrom = parameters.depthSolidFamiliarity.value
        let averages = WeakLineAverages(needs)
        var slots: [CandidateSlot] = []
        for playable in try playableSlots(for: candidate, assignments: try tactic.assignments(catalog: catalog),
                                          engine: engine, parameters: parameters) {
            let (assignment, ip, oop, rating) = playable
            let slot = assignment.slot
            let rivals = try Development.rivals(at: slot, tiers: needs.elevens.tiers, squad: squad, ownClub: ownClub,
                                                parameters: parameters)
            let secondPlace = needs.elevens.second.first { $0.slot == slot }

            let level: CandidateLevel
            if let first = rivals.first {
                if rating + roundingNoise >= first.rating {
                    level = .wouldStart
                } else if secondPlace == nil || secondPlace?.isOutOfPosition == true
                            || rivals.second.map({ rating + roundingNoise >= $0.rating }) == true {
                    level = .wouldMakeSecond
                } else if Depth.isWithinCoverShare(rating: rating, firstChoiceRating: first.rating, parameters: parameters) {
                    level = .wouldCountAsCover
                } else {
                    level = .belowCover
                }
            } else {
                level = .wouldStart
            }

            var answers: Set<NeedAnswer> = []
            var stillWeakBy: WeakGap?
            if let need = needs.betterPlayers.first(where: { $0.slot == slot }), level == .wouldStart {
                answers.insert(.betterPlayerToday)
                switch need.kind {
                case .nobody, .weak:
                    if let weak = averages.weakGap(isGoalkeeper: isGoalkeeperSlot(assignment), rating: rating,
                                                   ability: candidate.currentAbility, parameters: parameters),
                       isWeak(gap: weak.gap, parameters: parameters) {
                        stillWeakBy = weak
                    }
                case .ageing: break
                }
            }
            let isSolid = ip >= solidFrom && oop >= solidFrom
            if needs.moreDepth.contains(where: { $0.depth.slot == slot }),
               Depth.isCover(isSolid: isSolid, rating: rating, firstChoiceRating: rivals.first?.rating,
                             parameters: parameters) {
                answers.insert(.moreDepth)
            }
            slots.append(CandidateSlot(
                slot: slot, rating: rating, ipFamiliarity: ip, oopFamiliarity: oop, isSolid: isSolid, level: level,
                firstChoice: rivals.first, secondChoice: rivals.second,
                firstChoiceIsOutOfPosition: needs.elevens.first.first { $0.slot == slot }?.isOutOfPosition == true,
                marginOverFirst: rivals.first.map { rating / $0.rating - 1 }, stillWeakBy: stillWeakBy, later: nil,
                laterAgainstWeakLine: nil, answers: answers))
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

public enum CandidatePart: String, CaseIterable, Sendable {
    case answersToday, answersLater, wouldStartElsewhere, couldPassElsewhere, rest
}
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
    /// a level, so `AdvisorText.reachWorking` and `standing` read as they do for a squad player.
    public let outlook: Outlook?
    /// He is at or over `firstChoiceAgeNamedFrom`.
    public let isAgeNamed: Bool
    public let cautions: [CandidateCaution]
    public let basis: Evidence

    var headlineSlot: CandidateSlot? { headline.flatMap { slot in slots.first { $0.slot == slot } } }

    /// At a headline slot with no first choice, for a player with a reach: whether it clears the weak line. nil
    /// otherwise.
    public var reachClearsWeakLine: Bool? { headlineSlot?.laterAgainstWeakLine?.clears }
}

public struct CandidateGroup: Equatable, Sendable {
    public let part: CandidatePart
    /// The slot the group's players are listed under; nil for `rest`, which is one group.
    public let slot: SlotID?
    /// The need they answer there; nil for `wouldStartElsewhere` and `couldPassElsewhere`, which are a group for each
    /// slot and answer none, and for `rest`.
    public let answer: NeedAnswer?
    public let candidates: [Candidate]
}

public struct CandidatesReport: Equatable, Sendable {
    /// In paste order, without the players already held.
    public let candidates: [Candidate]
    /// The names of the pasted players already held, in paste order.
    public let leftOut: [String]
    /// The pasted players left out as hidden by the owner, as pasted and in paste order. A player already held is in
    /// `leftOut` and not here. They are not judged and are in no group.
    public let hidden: [Player]
    /// The weakest evidence among the candidates; nil when there are none.
    public let basis: Evidence?
    let betterPlayerSlots: [SlotID]
    let moreDepthSlots: [SlotID]
    /// The tactic's slots in its own order.
    let slotOrder: [SlotID]

    /// The groups in order, without empty ones: those answering a need today (the better-player slots in their order,
    /// then the depth slots in theirs), those who could answer one later, those who would start where there is no need
    /// (a group for each slot, in the tactic's order), those who could pass a first choice where there is no need (the
    /// same), and the rest, which is one group.
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
        for slot in slotOrder { add(.wouldStartElsewhere, slot, nil) }
        for slot in slotOrder { add(.couldPassElsewhere, slot, nil) }
        add(.rest, nil, nil)
        return found
    }

    /// By the design's table, greatest first, a nil value counting as the greatest; those who play no slot last; the
    /// key breaks every tie. In a "Later" order a candidate with no reach is placed by today's figure.
    ///
    /// | Part | Today | Later |
    /// |---|---|---|
    /// | answers today | rating | reach rating |
    /// | answers later | reach rating | reach rating |
    /// | would start elsewhere | margin | reach margin |
    /// | could pass elsewhere | reach margin | reach margin |
    /// | rest | margin | reach margin |
    private static func sorted(_ list: [Candidate], part: CandidatePart, order: CandidateOrder) -> [Candidate] {
        func value(_ c: Candidate) -> Double? {
            guard let slot = c.headlineSlot else { return -.infinity }
            // Today's figure stands in for a candidate with no reach.
            let reachRating = slot.later?.reachRating ?? slot.rating
            let reachMargin = slot.later == nil ? slot.marginOverFirst : slot.reachMargin
            switch (part, order) {
            case (.answersToday, .today): return slot.rating
            case (.answersToday, .later), (.answersLater, _): return reachRating
            case (.wouldStartElsewhere, .today), (.rest, .today): return slot.marginOverFirst
            case (.wouldStartElsewhere, .later), (.couldPassElsewhere, _), (.rest, .later): return reachMargin
            }
        }
        return list.sorted { a, b in
            let x = value(a), y = value(b)
            switch (x, y) {
            case (nil, nil): break
            case (nil, _?): return true
            case (_?, nil): return false
            case (let x?, let y?):
                if abs(x - y) > Scouting.roundingNoise { return x > y }
            }
            return a.player.id.key < b.player.id.key
        }
    }
}

extension Scouting {
    /// The pasted players judged, without those already held and those the owner has hidden (`hidden`: nobody by
    /// default, the state before players could be hidden), who are returned apart and not judged.
    /// Throws what `slotsToday`, `cautions` and `Reach.estimate` throw.
    public static func candidates(pasted: [Player], held: [Player], hidden: [HiddenCandidate] = [], ownClub: String?,
                                  tactic: Tactic, needs: ScoutingNeeds, catalog: RoleCatalog, profile: RatingProfile,
                                  parameters: EngineParameters) throws -> CandidatesReport {
        let goingIDs = Set(needs.going.map(\.player))
        let staying = held.filter { !goingIDs.contains($0.id) }
        let assignments = try tactic.assignments(catalog: catalog)
        let averages = WeakLineAverages(needs)
        let betterSlots = needs.betterPlayers.map(\.slot)
        let depthSlots = needs.moreDepth.map(\.depth.slot)

        var found: [Candidate] = []
        var leftOut: [String] = []
        var hiddenPlayers: [Player] = []
        for player in pasted {
            if isHeld(player, among: held, ownClub: ownClub) { leftOut.append(player.name); continue }
            if isHidden(player, among: hidden) { hiddenPlayers.append(player); continue }
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
                    var weakLine: WeakLineReach?
                    if later.firstChoice == nil, let assignment = assignments.first(where: { $0.slot == slot.slot }) {
                        let isKeeper = isGoalkeeperSlot(assignment)
                        if let measured = averages.measure(isGoalkeeper: isKeeper, rating: later.reachRating,
                                                           ability: reach.reach, parameters: parameters) {
                            weakLine = WeakLineReach(
                                reach: isKeeper ? .ability(reach.reach) : .rating(later.reachRating),
                                clears: clearsWeakLine(measured.value, average: measured.average, parameters: parameters))
                        }
                    }
                    return slot.with(later: later, against: weakLine, answers: answers)
                }
            }

            let (headline, headlineAnswer, part) = headline(of: slots, betterSlots: betterSlots, depthSlots: depthSlots,
                                                            parameters: parameters)

            var outlook: Outlook?
            if let estimate {
                let best = headline?.later.flatMap { $0.level == nil ? nil : $0 }
                outlook = Outlook(player: player.id, estimate: estimate, slots: slots.compactMap(\.later), best: best,
                                  level: best?.level, average: nil)
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
                outlook: outlook, isAgeNamed: player.age >= parameters.firstChoiceAgeNamedFrom.value,
                cautions: try cautions(for: player, parameters: parameters), basis: Evidence.weakest(evidence)!))
        }
        return CandidatesReport(candidates: found, leftOut: leftOut, hidden: hiddenPlayers,
                                basis: Evidence.weakest(found.map(\.basis)),
                                betterPlayerSlots: betterSlots, moreDepthSlots: depthSlots,
                                slotOrder: assignments.map(\.slot))
    }

    /// His headline slot, the need it answers and his part: the first of a slot where he answers a better-player need
    /// today (in the needs' order); a depth need (in theirs); a better-player need later; a slot where he would start
    /// (the greatest margin, then the tactic's order); a slot where his reach could pass the first choice (the greatest
    /// reach margin, then the tactic's order); otherwise the best level today, then the greatest margin, then the
    /// tactic's order, where a place in the second eleven held under `depthCoverShare` of the first choice's rating
    /// ranks below cover. No slot: the rest.
    static func headline(of slots: [CandidateSlot], betterSlots: [SlotID], depthSlots: [SlotID],
                         parameters: EngineParameters) -> (slot: CandidateSlot?, answer: NeedAnswer?, part: CandidatePart) {
        func first(in order: [SlotID], answering answer: NeedAnswer) -> CandidateSlot? {
            for slot in order { if let s = slots.first(where: { $0.slot == slot }), s.answers.contains(answer) { return s } }
            return nil
        }
        // The greatest value, nil counting as the greatest; an earlier slot wins a tie.
        func greatest(_ list: [CandidateSlot], by value: (CandidateSlot) -> Double?) -> CandidateSlot? {
            var best: CandidateSlot?
            for s in list {
                guard let current = best else { best = s; continue }
                switch (value(s), value(current)) {
                case (nil, nil), (_?, nil): break
                case (nil, _?): best = s
                case (let x?, let y?): if x > y + roundingNoise { best = s }
                }
            }
            return best
        }
        if let s = first(in: betterSlots, answering: .betterPlayerToday) { return (s, .betterPlayerToday, .answersToday) }
        if let s = first(in: depthSlots, answering: .moreDepth) { return (s, .moreDepth, .answersToday) }
        if let s = first(in: betterSlots, answering: .betterPlayerLater) { return (s, .betterPlayerLater, .answersLater) }
        if let s = greatest(slots.filter { $0.level == .wouldStart }, by: \.marginOverFirst) {
            return (s, nil, .wouldStartElsewhere)
        }
        if let s = greatest(slots.filter { $0.later?.level == .couldPassFirst }, by: \.reachMargin) {
            return (s, nil, .couldPassElsewhere)
        }
        func rank(_ s: CandidateSlot) -> Int {
            switch s.level {
            case .wouldStart: 0
            case .wouldMakeSecond:
                Depth.isWithinCoverShare(rating: s.rating, firstChoiceRating: s.firstChoice?.rating, parameters: parameters)
                    ? 1 : 3
            case .wouldCountAsCover: 2
            case .belowCover: 4
            }
        }
        guard let best = slots.map(rank).min() else { return (nil, nil, .rest) }
        return (greatest(slots.filter { rank($0) == best }, by: \.marginOverFirst), nil, .rest)
    }
}
