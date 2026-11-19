import Foundation

/// Why a player is left out of the squad scouting is judged on, in the order the reasons are tried.
public enum GoingReason: String, CaseIterable, Sendable { case onLoanHere, markedToSell, markedToLoanOut, advisedToLeave }

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
}

public enum BetterPlayerKind: String, CaseIterable, Sendable { case nobody, weak, ageing }

/// What a first choice was measured by against the outfield first choices.
public enum NeedMeasure: Equatable, Sendable {
    /// An outfield slot: his rating there and the average rating of the outfield first choices.
    case rating(his: Double, average: Double)
    /// The goalkeeper: his current ability and the average current ability of the outfield first choices.
    case ability(his: Int, average: Double)
}

public struct BetterPlayerNeed: Equatable, Sendable {
    public let slot: SlotID
    public let kind: BetterPlayerKind
    /// The first choice among those staying; nil when the slot has none.
    public let firstChoice: NamedPlayer?
    /// nil when the slot has no first choice, he is out of position, or there is no average.
    public let measure: NeedMeasure?
    /// How far under the average he is, as a share: 0.057 for 5.7%. For the goalkeeper both sides go through
    /// `ratingAbilityOffset`: 1 − (offset + his ability) ÷ the average of (offset + ability). nil with no measure.
    public let gap: Double?
    /// Today's first choice at the slot, when he is going.
    public let goingFirstChoice: Going?
    /// `nobody` and `weak` only: the young player staying whose reach clears the weak line, the highest reach first.
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
}

public struct ScoutingNeeds: Equatable, Sendable {
    /// Everyone left out, by key.
    public let going: [Going]
    /// Nobody, then weak by gap (largest first), then ageing (oldest first); within nobody and within weak, eased
    /// needs after the others; then the tactic's slot order.
    public let betterPlayers: [BetterPlayerNeed]
    /// Depth's order among those staying.
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

public enum Scouting {
    /// Comparisons allow for binary floating-point error, as `Development` does.
    private static let roundingNoise = 1e-9

    /// Players of `players` who are on loan at the club, marked, or in `advisedToLeave`, each once, by key, with the
    /// first reason in `GoingReason`'s order. Ids that no player has are ignored.
    public static func going(players: [Player], ownClub: String?, marks: [PlayerID: SaleMark],
                             advisedToLeave: Set<PlayerID>) -> [Going] {
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
            } else {
                reason = nil
            }
            if let reason { found.append(Going(player: player.id, name: player.name, reason: reason)) }
        }
        return found
    }

    /// Solves the elevens and depth for `players` (today) and for `players` without `going` (staying), and reads
    /// the needs off the second. Throws what `Elevens.report`, `Depth.report` and `Development.outlooks` throw.
    public static func needs(tactic: Tactic, players: [Player], ownClub: String?, going: [Going],
                             retraining: [Retraining], catalog: RoleCatalog, profile: RatingProfile,
                             parameters: EngineParameters) throws -> ScoutingNeeds {
        // Each player once, with the reason that comes first in `GoingReason`'s order.
        let reasonOrder = GoingReason.allCases
        let goingByID = Dictionary(going.map { ($0.player, $0) }, uniquingKeysWith: { a, b in
            (reasonOrder.firstIndex(of: b.reason) ?? 0) < (reasonOrder.firstIndex(of: a.reason) ?? 0) ? b : a
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
        let outlooks = try Development.outlooks(players: staying, ownClub: ownClub, assignments: assignments,
                                                tiers: elevens.tiers, retraining: retraining, parameters: parameters)

        // The averages the first choices are measured by: outfield slots whose first choice is in position, summed in
        // the tactic's slot order.
        let offset = parameters.ratingAbilityOffset.value
        var ratings: [Double] = []
        var abilities: [Double] = []
        for assignment in assignments where assignment.ipPosition != .goalkeeper {
            guard let place = elevens.first.first(where: { $0.slot == assignment.slot }), !place.isOutOfPosition,
                  let player = byID[place.player] else { continue }
            ratings.append(place.rating.value)
            abilities.append(offset + Double(player.currentAbility))
        }
        let averageRating: Double? = ratings.isEmpty ? nil : ratings.reduce(0, +) / Double(ratings.count)
        let averageAbility: Double? = abilities.isEmpty ? nil : abilities.reduce(0, +) / Double(abilities.count)

        let weakShare = parameters.scoutingWeakShare.value
        let outlookEvidence: [Evidence] = outlooks.isEmpty ? [] : [
            parameters.growthPerSeason.evidence, parameters.growthProfessionalismRates.evidence,
            parameters.markedlyLowerShare.evidence, parameters.markedlyLowerShareYoungest.evidence]

        // A first choice at another slot cannot fill a second one, so he eases nothing and is nobody's successor.
        func isFirstChoiceElsewhere(_ id: PlayerID, not slot: SlotID) -> Bool {
            if case .first(let other)? = elevens.tiers.tier(of: id), other != slot { return true }
            return false
        }

        // A young player staying whose reach clears the weak line at the slot, the highest reach first.
        func easedBy(_ assignment: SlotAssignment) -> NamedPlayer? {
            let isKeeper = assignment.ipPosition == .goalkeeper
            guard let line = (isKeeper ? averageAbility : averageRating).map({ $0 * weakShare }) else { return nil }
            var best: (reach: Double, player: Player)?
            for (id, outlook) in outlooks.sorted(by: { $0.key.key < $1.key.key }) {
                guard !isFirstChoiceElsewhere(id, not: assignment.slot),
                      let player = byID[id], let slot = outlook.slots.first(where: { $0.slot == assignment.slot }) else { continue }
                let reach = isKeeper ? offset + outlook.estimate.reach : slot.reachRating
                guard reach + roundingNoise >= line else { continue }
                if let current = best, reach <= current.reach { continue }
                best = (reach, player)
            }
            return best.map { NamedPlayer(player: $0.player.id, name: $0.player.name, age: $0.player.age) }
        }

        func hasSuccessor(at slot: SlotID) -> Bool {
            outlooks.contains { id, outlook in
                !isFirstChoiceElsewhere(id, not: slot)
                    && outlook.slots.contains { $0.slot == slot && ($0.band == .close || $0.band == .onCourse) }
            }
        }

        var needs: [(need: BetterPlayerNeed, order: Int)] = []
        for (index, assignment) in assignments.enumerated() {
            let slot = assignment.slot
            let isKeeper = assignment.ipPosition == .goalkeeper
            let place = elevens.first.first { $0.slot == slot }
            let first = place.flatMap { byID[$0.player] }
            var measure: NeedMeasure?
            var gap: Double?
            if let place, let first, !place.isOutOfPosition {
                if isKeeper {
                    if let averageAbility {
                        let his = offset + Double(first.currentAbility)
                        measure = .ability(his: first.currentAbility, average: averageAbility - offset)
                        gap = 1 - his / averageAbility
                    }
                } else if let averageRating {
                    measure = .rating(his: place.rating.value, average: averageRating)
                    gap = 1 - place.rating.value / averageRating
                }
            }
            guard let kind = betterPlayerKind(hasFirstChoice: place != nil, isOutOfPosition: place?.isOutOfPosition ?? false,
                                              gap: gap, age: first?.age, hasSuccessor: hasSuccessor(at: slot),
                                              parameters: parameters) else { continue }
            let eased: NamedPlayer? = kind == .ageing ? nil : easedBy(assignment)
            let basis: Evidence
            switch kind {
            case .nobody, .weak:
                basis = Evidence.weakest([parameters.scoutingWeakShare.evidence, parameters.ratingAbilityOffset.evidence]
                                         + outlookEvidence)!
            case .ageing:
                basis = Evidence.weakest([parameters.firstChoiceAgeNamedFrom.evidence] + outlookEvidence)!
            }
            let leaving = today.tiers.first[slot].flatMap { goingByID[$0] }
            needs.append((BetterPlayerNeed(
                slot: slot, kind: kind,
                firstChoice: first.map { NamedPlayer(player: $0.id, name: $0.name, age: $0.age) },
                measure: measure, gap: gap, goingFirstChoice: leaving, easedBy: eased, basis: basis), index))
        }
        func rank(_ kind: BetterPlayerKind) -> Int {
            switch kind {
            case .nobody: 0
            case .weak: 1
            case .ageing: 2
            }
        }
        needs.sort { a, b in
            if a.need.kind != b.need.kind { return rank(a.need.kind) < rank(b.need.kind) }
            let ae = a.need.easedBy != nil, be = b.need.easedBy != nil
            if ae != be { return !ae }
            switch a.need.kind {
            case .nobody: break
            case .weak:
                let ga = a.need.gap ?? 0, gb = b.need.gap ?? 0
                if ga != gb { return ga > gb }
            case .ageing:
                let aa = a.need.firstChoice?.age ?? 0, ab = b.need.firstChoice?.age ?? 0
                if aa != ab { return aa > ab }
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
            moreDepth.append(DepthNeed(depth: slotDepth, going: leaving, returning: returning))
        }

        let needed = Set(needs.map(\.need.slot)).union(moreDepth.map(\.depth.slot))
        let fine = assignments.map(\.slot).filter { !needed.contains($0) }

        let evidence = [parameters.scoutingWeakShare.evidence, parameters.firstChoiceAgeNamedFrom.evidence,
                        parameters.ratingAbilityOffset.evidence, depth.basis] + outlookEvidence
        return ScoutingNeeds(going: goingByID.values.sorted { $0.player.key < $1.player.key }, betterPlayers: needs.map(\.need),
                             moreDepth: moreDepth, fine: fine, elevens: elevens, depth: depth,
                             outfieldAverageRating: averageRating, outfieldAverageAbility: averageAbility,
                             basis: Evidence.weakest(evidence)!)
    }

    /// The better-player rule from numbers alone, the first that holds: nobody (no first choice, or out of
    /// position), weak (`gap` at or over 1 − `scoutingWeakShare`), ageing (`age` at or over
    /// `firstChoiceAgeNamedFrom` with no successor); nil for none.
    static func betterPlayerKind(hasFirstChoice: Bool, isOutOfPosition: Bool, gap: Double?, age: Int?,
                                 hasSuccessor: Bool, parameters: EngineParameters) -> BetterPlayerKind? {
        if !hasFirstChoice || isOutOfPosition { return .nobody }
        if let gap, gap + roundingNoise >= 1 - parameters.scoutingWeakShare.value { return .weak }
        if let age, age >= parameters.firstChoiceAgeNamedFrom.value, !hasSuccessor { return .ageing }
        return nil
    }
}
