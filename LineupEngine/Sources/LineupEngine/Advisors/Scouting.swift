import Foundation

/// Why a player is left out of the squad scouting is judged on, in the order the reasons are tried.
public enum GoingReason: String, CaseIterable, Sendable { case onLoanHere, markedToSell, markedToLoanOut, advisedToLeave, notBeingRenewed }

/// A player left out of the squad scouting is judged on.
public struct Going: Equatable, Sendable {
    public let player: PlayerID
    public let name: String
    public let reason: GoingReason

    public init(player: PlayerID, name: String, reason: GoingReason) {
        self.player = player
        self.name = name
        self.reason = reason
    }
}

public struct NamedPlayer: Equatable, Sendable {
    public let player: PlayerID
    public let name: String
    public let age: Int
    /// The club he is out on loan at; nil for a player at the club.
    public let onLoanAt: String?

    init(player: PlayerID, name: String, age: Int, onLoanAt: String? = nil) {
        self.player = player
        self.name = name
        self.age = age
        self.onLoanAt = onLoanAt
    }

    init(_ player: Player, onLoanAt: String? = nil) {
        self.init(player: player.id, name: player.name, age: player.age, onLoanAt: onLoanAt)
    }
}

public enum BetterPlayerKind: String, CaseIterable, Sendable { case nobody, weak, ageing }

/// What a first choice was measured by against the outfield first choices.
public enum NeedMeasure: Equatable, Sendable {
    /// An outfield slot: his rating there and the average rating of the outfield first choices.
    case rating(his: Double, average: Double)
    /// The goalkeeper: his current ability and the average current ability of the outfield first choices.
    case ability(his: Int, average: Double)
}

/// How far under the weak line a player falls, and what he was measured by: by rating at an outfield slot, by ability
/// at the goalkeeper's.
public struct WeakGap: Equatable, Sendable {
    /// As a share: 0.057 for 5.7%.
    public let gap: Double
    public let measure: NeedMeasure
}

public struct BetterPlayerNeed: Equatable, Sendable {
    public let slot: SlotID
    public let kind: BetterPlayerKind
    /// The first choice among those staying; nil when the slot has none.
    public let firstChoice: NamedPlayer?
    /// He is at or over `firstChoiceAgeNamedFrom`, so the weak line names his age: the weak rule comes before the
    /// ageing one and would otherwise hide it.
    public let namesFirstChoiceAge: Bool
    /// nil when the slot has no first choice, he is out of position, or there is no average.
    public let measure: NeedMeasure?
    /// How far under the average he is, as a share: 0.057 for 5.7%. For the goalkeeper both sides go through
    /// `ratingAbilityOffset`: 1 − (offset + his ability) ÷ the average of (offset + ability). nil with no measure.
    public let gap: Double?
    /// Today's first choice at the slot, when he is going.
    public let goingFirstChoice: Going?
    /// `nobody` and `weak` only: the young player of the club's own whose reach clears the weak line, the highest reach
    /// first; one out on loan says where.
    public let easedBy: NamedPlayer?
    public let basis: Evidence
}

public struct Returning: Equatable, Sendable {
    public let player: PlayerID
    public let name: String
    public let club: String
}

public struct DepthNeed: Equatable, Sendable {
    /// The slot's depth among those staying.
    public let depth: SlotDepth
    /// Who counts as cover there today and is going, in Depth's order.
    public let going: [Going]
    /// Players out on loan who are solid there and within the cover share, in Depth's order.
    public let returning: [Returning]
    /// Those staying who would count as cover but for an injury (solid, within the cover share, not first choice at
    /// another slot), in Depth's order.
    public let injured: [NamedPlayer]
    /// `depth.cover` and `injured` together reach `depthThinBelow`: the need lasts only while they are out.
    public let lastsOnlyWhileInjured: Bool
    /// The slot's first choice among those staying; nil when it has none.
    public let firstChoice: NamedPlayer?
    /// How far the next best's rating is under the first choice's, as a share: 0.064 for 6.4%, negative when he rates
    /// above him. nil with no next best or no first choice.
    public let nextBestShareUnder: Double?
}

public struct ScoutingNeeds: Equatable, Sendable {
    /// Everyone left out, by key.
    public let going: [Going]
    /// Nobody, then weak by gap (largest first), then ageing (oldest first); within nobody and within weak, eased
    /// needs after the others; then the tactic's slot order.
    public let betterPlayers: [BetterPlayerNeed]
    /// Depth's order among those staying, the needs that last only while players are injured after the others.
    public let moreDepth: [DepthNeed]
    /// The slots with neither, in the tactic's order.
    public let fine: [SlotID]
    /// The elevens and depth of the players who stay: what a candidate is measured against.
    public let elevens: ElevensReport
    public let depth: DepthReport
    /// The average rating of the outfield first choices in position; nil when there is none.
    public let outfieldAverageRating: Double?
    /// The average of (offset + current ability) over the same players; nil when there is none.
    public let outfieldAverageAbility: Double?
    public let basis: Evidence
}

/// What a better-player rule found, with the figure it is ordered by.
enum BetterPlayerFinding: Equatable {
    case nobody
    case weak(gap: Double)
    case ageing(age: Int)

    var kind: BetterPlayerKind {
        switch self {
        case .nobody: .nobody
        case .weak: .weak
        case .ageing: .ageing
        }
    }
}

/// A young player of the club's own and his outlook at each slot he can play: one staying at the club, from
/// `Development.outlooks`, or one out on loan, rated at each slot directly as a pasted player is.
struct Prospect {
    let player: Player
    let estimate: ReachEstimate
    let slots: [SlotOutlook]
    /// The club he is out on loan at; nil for a player at the club.
    let onLoanAt: String?
}

public enum Scouting {
    /// Every comparison scouting makes allows for binary floating-point error, as `Development` does.
    static let roundingNoise = 1e-9

    /// Players of `players` who are on loan at the club, marked, in `advisedToLeave` or in `notBeingRenewed` (in his
    /// last year, and the owner is not renewing him), each once, by key, with the first reason in `GoingReason`'s
    /// order. Ids that no player has are ignored.
    public static func going(players: [Player], ownClub: String?, marks: [PlayerID: SaleMark],
                             advisedToLeave: Set<PlayerID>, notBeingRenewed: Set<PlayerID> = []) -> [Going] {
        var found: [Going] = []
        for player in players.sorted(by: { $0.id.key < $1.id.key }) {
            let reason: GoingReason?
            if case .loanedIn = LoanStatus.of(player, ownClub: ownClub) {
                reason = .onLoanHere
            } else if let mark = marks[player.id] {
                switch mark {
                case .toSell: reason = .markedToSell
                case .toLoanOut: reason = .markedToLoanOut
                }
            } else if advisedToLeave.contains(player.id) {
                reason = .advisedToLeave
            } else if notBeingRenewed.contains(player.id) {
                reason = .notBeingRenewed
            } else {
                reason = nil
            }
            if let reason { found.append(Going(player: player.id, name: player.name, reason: reason)) }
        }
        return found
    }

    /// Where a reason stands in `GoingReason`'s order.
    private static func rank(_ reason: GoingReason) -> Int {
        switch reason {
        case .onLoanHere: 0
        case .markedToSell: 1
        case .markedToLoanOut: 2
        case .advisedToLeave: 3
        case .notBeingRenewed: 4
        }
    }

    /// Where a kind of need stands in the list: nobody, weak, ageing.
    private static func rank(_ kind: BetterPlayerKind) -> Int {
        switch kind {
        case .nobody: 0
        case .weak: 1
        case .ageing: 2
        }
    }

    /// Solves the elevens and depth for `players` (today) and for `players` without `going` (staying), and reads
    /// the needs off the second. Throws what `Elevens.report`, `Depth.report`, `Development.outlooks` and
    /// `Reach.estimate` throw, and `RatingError` for a young player out on loan with missing data.
    public static func needs(tactic: Tactic, players: [Player], ownClub: String?, going: [Going],
                             retraining: [Retraining], catalog: RoleCatalog, profile: RatingProfile,
                             parameters: EngineParameters) throws -> ScoutingNeeds {
        // Each player once, with the reason that comes first in `GoingReason`'s order.
        let goingByID = Dictionary(going.map { ($0.player, $0) }, uniquingKeysWith: { a, b in
            rank(b.reason) < rank(a.reason) ? b : a
        })
        let staying = players.filter { goingByID[$0.id] == nil }
        let byID = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let assignments = try tactic.assignments(catalog: catalog)

        let today = try Elevens.report(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                                       profile: profile, parameters: parameters)
        let todayDepth = try Depth.report(tactic: tactic, players: players, ownClub: ownClub, elevens: today,
                                          catalog: catalog, profile: profile, parameters: parameters)
        let elevens = going.isEmpty ? today : try Elevens.report(
            tactic: tactic, players: staying, ownClub: ownClub, catalog: catalog, profile: profile,
            parameters: parameters)
        let depth = going.isEmpty ? todayDepth : try Depth.report(
            tactic: tactic, players: staying, ownClub: ownClub, elevens: elevens, catalog: catalog, profile: profile,
            parameters: parameters)
        let prospects = try prospects(staying: staying, ownClub: ownClub, assignments: assignments, tiers: elevens.tiers,
                                      retraining: retraining, profile: profile, parameters: parameters)

        // The averages the first choices are measured by (`Renewal.standard`).
        let standard = Renewal.standard(elevens: elevens, depth: depth, players: players, parameters: parameters)
        let averages = WeakLineAverages(standard)

        let outlookEvidence: [Evidence] = prospects.isEmpty ? [] : [
            parameters.growthPerSeason.evidence, parameters.growthProfessionalismRates.evidence,
            parameters.markedlyLowerShare.evidence, parameters.markedlyLowerShareYoungest.evidence]

        // A first choice at another slot cannot fill a second one, so he eases nothing and is nobody's successor.
        func isFirstChoiceElsewhere(_ id: PlayerID, not slot: SlotID) -> Bool {
            if case .first(let other)? = elevens.tiers.tier(of: id), other != slot { return true }
            return false
        }

        // A young player whose reach clears the weak line at the slot, by rating and by ability
        // (`WeakLineAverages.reachAgainstLine`), and is not below the ability of a first choice in position there
        // (`Development.fallsShort`: he would not pass him), the highest reach first.
        func easedBy(_ assignment: SlotAssignment, firstChoiceInPosition: Bool) -> NamedPlayer? {
            var best: (reach: Double, prospect: Prospect)?
            for prospect in prospects where !isFirstChoiceElsewhere(prospect.player.id, not: assignment.slot) {
                let isKeeper = isGoalkeeperSlot(assignment)
                guard let slot = prospect.slots.first(where: { $0.slot == assignment.slot }),
                      let measured = averages.measure(isGoalkeeper: isKeeper, rating: slot.reachRating,
                                                      ability: prospect.estimate.reach, parameters: parameters),
                      averages.reachAgainstLine(isGoalkeeper: isKeeper, reachRating: slot.reachRating,
                                                reach: prospect.estimate.reach, parameters: parameters)?.clears == true
                else { continue }
                if firstChoiceInPosition, let first = slot.firstChoice,
                   Development.fallsShort(prospect.estimate.reach, of: first) { continue }
                if let current = best, measured.value <= current.reach { continue }
                best = (measured.value, prospect)
            }
            return best.map { NamedPlayer($0.prospect.player, onLoanAt: $0.prospect.onLoanAt) }
        }

        func hasSuccessor(at slot: SlotID) -> Bool {
            prospects.contains { prospect in
                !isFirstChoiceElsewhere(prospect.player.id, not: slot)
                    && prospect.slots.contains { $0.slot == slot && ($0.band == .close || $0.band == .onCourse) }
            }
        }

        var needs: [(need: BetterPlayerNeed, finding: BetterPlayerFinding, order: Int)] = []
        for (index, assignment) in assignments.enumerated() {
            let slot = assignment.slot
            let place = elevens.first.first { $0.slot == slot }
            let first = place.flatMap { byID[$0.player] }
            var weak: WeakGap?
            if let place, let first, !place.isOutOfPosition {
                weak = averages.weakGap(isGoalkeeper: isGoalkeeperSlot(assignment), rating: place.rating.value,
                                        ability: first.currentAbility, parameters: parameters)
            }
            guard let finding = betterPlayerFinding(
                hasFirstChoice: place != nil, isOutOfPosition: place?.isOutOfPosition == true, gap: weak?.gap,
                age: first?.age, hasSuccessor: hasSuccessor(at: slot), parameters: parameters) else { continue }
            let eased: NamedPlayer?
            let basis: Evidence
            switch finding {
            case .nobody, .weak:
                eased = easedBy(assignment, firstChoiceInPosition: place.map { !$0.isOutOfPosition } ?? false)
                basis = Evidence.weakest([parameters.scoutingWeakShare.evidence, parameters.ratingAbilityOffset.evidence]
                                         + outlookEvidence)!
            case .ageing:
                eased = nil
                basis = Evidence.weakest([parameters.firstChoiceAgeNamedFrom.evidence] + outlookEvidence)!
            }
            let leaving = today.tiers.first[slot].flatMap { goingByID[$0] }
            needs.append((BetterPlayerNeed(
                slot: slot, kind: finding.kind, firstChoice: first.map { NamedPlayer($0) },
                namesFirstChoiceAge: first.map { $0.age >= parameters.firstChoiceAgeNamedFrom.value } == true,
                measure: weak?.measure, gap: weak?.gap, goingFirstChoice: leaving, easedBy: eased, basis: basis),
                finding, index))
        }
        needs.sort { a, b in
            if rank(a.need.kind) != rank(b.need.kind) { return rank(a.need.kind) < rank(b.need.kind) }
            let ae = a.need.easedBy != nil, be = b.need.easedBy != nil
            if ae != be { return !ae }
            switch (a.finding, b.finding) {
            case (.weak(let x), .weak(let y)): if x != y { return x > y }
            case (.ageing(let x), .ageing(let y)): if x != y { return x > y }
            case (.nobody, _), (.weak, _), (.ageing, _): break
            }
            return a.order < b.order
        }

        var moreDepth: [DepthNeed] = []
        for slot in depth.thin {
            guard let slotDepth = depth.slots.first(where: { $0.slot == slot }) else { continue }
            let leaving = todayDepth.slots.first { $0.slot == slot }?.options
                .filter { $0.countsAsCover }.compactMap { goingByID[$0.player] } ?? []
            let returning: [Returning] = slotDepth.onLoan.filter { $0.isSolid && !$0.isBelowCoverShare }.compactMap { option in
                guard let player = byID[option.player], case .loanedOut(let club) = LoanStatus.of(player, ownClub: ownClub)
                else { return nil }
                return Returning(player: option.player, name: option.name, club: club)
            }
            // Would count but for an injury: solid, within the cover share, and not first choice at another slot.
            let injured: [NamedPlayer] = slotDepth.options.filter { option in
                option.unavailable == .injured && option.isSolid && !option.isBelowCoverShare
                    && Depth.canStepIn(unavailable: nil, tier: option.tier, at: slot)
            }.compactMap { byID[$0.player].map { NamedPlayer($0) } }
            let firstID = elevens.tiers.first[slot]
            var shareUnder: Double?
            if let firstID, let firstRating = elevens.tiers.ratings[firstID]?[slot], firstRating > 0,
               let next = slotDepth.options.first(where: { $0.player == slotDepth.nextBest }) {
                shareUnder = 1 - next.rating / firstRating
            }
            moreDepth.append(DepthNeed(
                depth: slotDepth, going: leaving, returning: returning, injured: injured,
                lastsOnlyWhileInjured: slotDepth.cover + injured.count >= parameters.depthThinBelow.value,
                firstChoice: firstID.flatMap { byID[$0] }.map { NamedPlayer($0) }, nextBestShareUnder: shareUnder))
        }
        // The needs that rest on an injury after the others, each in Depth's order.
        moreDepth = moreDepth.filter { !$0.lastsOnlyWhileInjured } + moreDepth.filter(\.lastsOnlyWhileInjured)

        let needed = Set(needs.map(\.need.slot)).union(moreDepth.map(\.depth.slot))
        let fine = assignments.map(\.slot).filter { !needed.contains($0) }

        let evidence = [parameters.scoutingWeakShare.evidence, parameters.firstChoiceAgeNamedFrom.evidence,
                        parameters.ratingAbilityOffset.evidence, depth.basis] + outlookEvidence
        return ScoutingNeeds(going: goingByID.values.sorted { $0.player.key < $1.player.key }, betterPlayers: needs.map(\.need),
                             moreDepth: moreDepth, fine: fine, elevens: elevens, depth: depth,
                             outfieldAverageRating: standard.rating, outfieldAverageAbility: standard.ability,
                             basis: Evidence.weakest(evidence)!)
    }

    /// The young players of the club's own who could ease a need or succeed a first choice, by key: those staying at
    /// the club, from `Development.outlooks`, and those of `developingUpToAge` or under out on loan, rated directly at
    /// each slot they can play (as a pasted player is) against the staying rivals.
    private static func prospects(staying: [Player], ownClub: String?, assignments: [SlotAssignment], tiers: SquadTiers,
                                  retraining: [Retraining], profile: RatingProfile,
                                  parameters: EngineParameters) throws -> [Prospect] {
        let outlooks = try Development.outlooks(players: staying, ownClub: ownClub, assignments: assignments, tiers: tiers,
                                                retraining: retraining, parameters: parameters)
        let engine = RatingEngine(profile: profile, parameters: parameters, configuration: .fm27)
        var found: [Prospect] = []
        for player in staying.sorted(by: { $0.id.key < $1.id.key }) {
            if let outlook = outlooks[player.id] {
                found.append(Prospect(player: player, estimate: outlook.estimate, slots: outlook.slots, onLoanAt: nil))
                continue
            }
            guard case .loanedOut(let club) = LoanStatus.of(player, ownClub: ownClub),
                  player.age <= parameters.developingUpToAge.value, player.currentAbility > 0 else { continue }
            let estimate = try Reach.estimate(for: player, parameters: parameters)
            var slots: [SlotOutlook] = []
            for playable in try playableSlots(for: player, assignments: assignments, engine: engine, parameters: parameters) {
                let slot = playable.assignment.slot
                let rivals = try Development.rivals(at: slot, tiers: tiers, squad: staying, ownClub: ownClub,
                                                    parameters: parameters)
                slots.append(Development.slotOutlook(for: player, estimate: estimate, rating: playable.rating, at: slot,
                                                     rivals: rivals, parameters: parameters))
            }
            found.append(Prospect(player: player, estimate: estimate, slots: slots, onLoanAt: club))
        }
        return found
    }

    /// The slots of `assignments` a player can play (familiarity at or over `depthCoverFamiliarity` in both phases,
    /// Depth's line for an option), in their order, with his familiarities and his full-fitness rating there.
    /// Throws `RatingError` for a missing familiarity or attribute.
    static func playableSlots(for player: Player, assignments: [SlotAssignment], engine: RatingEngine,
                              parameters: EngineParameters) throws
        -> [(assignment: SlotAssignment, ip: Int, oop: Int, rating: Double)] {
        func familiarity(_ position: Position) throws -> Int {
            guard let value = player.familiarity[position] else {
                throw RatingError.missingFamiliarity(player: player.name, position: position)
            }
            return value
        }
        let coverFrom = parameters.depthCoverFamiliarity.value
        var found: [(assignment: SlotAssignment, ip: Int, oop: Int, rating: Double)] = []
        for assignment in assignments {
            let ip = try familiarity(assignment.ipPosition), oop = try familiarity(assignment.oopPosition)
            guard ip >= coverFrom, oop >= coverFrom else { continue }
            found.append((assignment, ip, oop, try engine.rating(for: player, in: assignment).value))
        }
        return found
    }

    // MARK: One place for each rule

    /// The goalkeeper's slot, whose ratings are on their own scale, so it is measured by ability: its in-possession
    /// position is the goalkeeper's.
    static func isGoalkeeperSlot(_ assignment: SlotAssignment) -> Bool { assignment.ipPosition == .goalkeeper }

    /// How far under `average` a value is, as a share: 0.057 for 5.7%.
    static func gap(of value: Double, under average: Double) -> Double { 1 - value / average }

    /// The weak line: a gap at or over 1 − `scoutingWeakShare`.
    static func isWeak(gap: Double, parameters: EngineParameters) -> Bool {
        gap + roundingNoise >= 1 - parameters.scoutingWeakShare.value
    }

    /// A value clears the weak line against `average` when its gap under it is not weak.
    static func clearsWeakLine(_ value: Double, average: Double, parameters: EngineParameters) -> Bool {
        !isWeak(gap: gap(of: value, under: average), parameters: parameters)
    }

    /// The better-player rule from numbers alone, the first that holds: nobody (no first choice, or out of
    /// position), weak (`gap` on the weak line), ageing (`age` at or over `firstChoiceAgeNamedFrom` with no
    /// successor); nil for none.
    static func betterPlayerFinding(hasFirstChoice: Bool, isOutOfPosition: Bool, gap: Double?, age: Int?,
                                    hasSuccessor: Bool, parameters: EngineParameters) -> BetterPlayerFinding? {
        if !hasFirstChoice || isOutOfPosition { return .nobody }
        if let gap, isWeak(gap: gap, parameters: parameters) { return .weak(gap: gap) }
        if let age, age >= parameters.firstChoiceAgeNamedFrom.value, !hasSuccessor { return .ageing(age: age) }
        return nil
    }

    static func betterPlayerKind(hasFirstChoice: Bool, isOutOfPosition: Bool, gap: Double?, age: Int?,
                                 hasSuccessor: Bool, parameters: EngineParameters) -> BetterPlayerKind? {
        betterPlayerFinding(hasFirstChoice: hasFirstChoice, isOutOfPosition: isOutOfPosition, gap: gap, age: age,
                            hasSuccessor: hasSuccessor, parameters: parameters)?.kind
    }
}

/// The two averages of the outfield first choices that a slot is measured against: their rating, and, for the
/// goalkeeper's slot, their (offset + current ability).
struct WeakLineAverages {
    let rating: Double?
    let ability: Double?

    init(rating: Double?, ability: Double?) {
        self.rating = rating
        self.ability = ability
    }

    init(_ standard: SquadStandard) {
        self.init(rating: standard.rating, ability: standard.ability)
    }

    init(_ needs: ScoutingNeeds) {
        self.init(rating: needs.outfieldAverageRating, ability: needs.outfieldAverageAbility)
    }

    /// What a player at a slot is measured by and the average it is set against: his rating at an outfield slot, and
    /// at the goalkeeper's (offset + `ability`), `ability` being his current ability or a reach. nil with no average.
    func measure(isGoalkeeper: Bool, rating: Double, ability: Double,
                 parameters: EngineParameters) -> (value: Double, average: Double)? {
        if isGoalkeeper {
            return self.ability.map { (parameters.ratingAbilityOffset.value + ability, $0) }
        }
        return self.rating.map { (rating, $0) }
    }

    /// A young player's reach set against the weak line at a slot, by `measure` at the goalkeeper's (as ability); at an
    /// outfield slot by rating and by ability too, (offset + reach) against the outfield first choices' average (offset +
    /// ability), since a rating scaled up to a reach can clear the line on a potential no first choice is near (the
    /// owner's rule of 25 November 2026: a player of potential 72 was called a successor to one of ability 83). nil with
    /// no average.
    func reachAgainstLine(isGoalkeeper: Bool, reachRating: Double, reach: Double,
                          parameters: EngineParameters) -> WeakLineReach? {
        let offset = parameters.ratingAbilityOffset.value
        guard let measured = measure(isGoalkeeper: isGoalkeeper, rating: reachRating, ability: reach,
                                     parameters: parameters) else { return nil }
        let byMeasure = Scouting.clearsWeakLine(measured.value, average: measured.average, parameters: parameters)
        if isGoalkeeper { return WeakLineReach(reach: .ability(reach), clears: byMeasure, shortByAbility: nil) }
        let byAbility = self.ability.map {
            Scouting.clearsWeakLine(offset + reach, average: $0, parameters: parameters)
        } ?? true
        let short = byMeasure && !byAbility
            ? self.ability.map { (reach: reach, line: parameters.scoutingWeakShare.value * $0 - offset) } : nil
        return WeakLineReach(reach: .rating(reachRating), clears: byMeasure && byAbility, shortByAbility: short)
    }

    /// His gap under the average and what it was measured by; nil with no average.
    func weakGap(isGoalkeeper: Bool, rating: Double, ability: Int, parameters: EngineParameters) -> WeakGap? {
        guard let measured = measure(isGoalkeeper: isGoalkeeper, rating: rating, ability: Double(ability),
                                     parameters: parameters) else { return nil }
        let measure: NeedMeasure = isGoalkeeper
            ? .ability(his: ability, average: measured.average - parameters.ratingAbilityOffset.value)
            : .rating(his: rating, average: measured.average)
        return WeakGap(gap: Scouting.gap(of: measured.value, under: measured.average), measure: measure)
    }
}
