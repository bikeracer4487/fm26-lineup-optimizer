import Foundation

/// How far a player's contract has run down: what puts him on Contracts and what his timing line says.
public enum ContractPart: String, CaseIterable, Sendable {
    /// `approachMonths` or fewer left: other clubs can approach him now.
    case approachable
    /// `lastYearMonths` or fewer left.
    case lastYear
    /// Out of contract, or months left below zero: no contract to run down.
    case noContract
}

/// Where a player on Contracts stands for the tactic.
public enum ContractStanding: Equatable, Sendable {
    case first(SlotID), second(SlotID), neither
    /// Out on loan at `to`, with his best level at a slot of the tactic against the whole squad's elevens; nil level and
    /// slot when he can play no slot.
    case outOnLoan(to: String, level: CandidateLevel?, slot: SlotID?)
}

/// Why a player in a part may be needed until he is replaced, so the owner should sign someone first.
public enum ReplaceWhy: String, CaseIterable, Sendable {
    /// He is first choice at the slot.
    case firstChoice
    /// He is second choice at the slot.
    case secondChoice
    /// He counts as cover where the slot's cover is at most the line (Player Removal's `RemovalNeedKind.cover`).
    case cover
    /// He is a stand-in where the slot's stand-ins are at most the line (Player Removal's `RemovalNeedKind.standIn`).
    case standIn
}

/// One reason the tool does not recommend renewing a player, in the order they are given.
public enum ContractReason: Equatable, Sendable {
    /// The owner has marked him to sell.
    case markedToSell
    /// Player Removal advises moving him on, with this action.
    case advisedToLeave(RemovalAction)
    /// His worth is under the first eleven's standard.
    case underStandard(RenewalWorth)
    /// He can play no slot of the tactic, so he has no worth.
    case noSlot
    /// The first eleven has no outfield player in position, so nobody can be measured.
    case noStandard
    /// He is needed at `slot` until he is replaced; given only with another reason, and last.
    case replaceFirst(slot: SlotID, why: ReplaceWhy)
}

/// One player on Contracts.
public struct ContractEntry: Equatable, Sendable {
    public let player: PlayerID
    public let name: String
    public let part: ContractPart
    public let ends: Day?
    /// Six months (`approachMonths`) before `ends`, when other clubs may approach him: `lastYear` with an end day only.
    public let approachableFrom: Day?
    public let standing: ContractStanding
    /// Player Removal's action; nil when out on loan, or when Player Removal gave him no advice.
    public let action: RemovalAction?
    public let tier: WageTier
    /// The slot his tier is read at; nil for neither eleven, or out on loan at no slot.
    public let slot: SlotID?
    public let presentWagePerWeek: Double
    /// His worth against the first eleven's standard; nil when he can play no slot or there is no standard.
    public let worth: RenewalWorth?
    /// Why the tool does not recommend renewing him, in the design's order; empty when it does.
    public let reasons: [ContractReason]
    /// The owner chose "Renew anyway" and the tool does not recommend him.
    public let isWanted: Bool
}

public struct ContractsReport: Equatable, Sendable {
    /// The players the tool recommends renewing, and those the owner wants renewed whom it does not, not set aside:
    /// the higher worth first (no worth last), then the earlier end day, then fewer months left, then the order of the
    /// players handed in.
    public let listed: [ContractEntry]
    /// The players the tool does not recommend renewing and the owner has not chosen to renew, whether or not he set
    /// them aside, in the same order.
    public let notRecommended: [ContractEntry]
    /// The players recommended or wanted whom the owner has set aside with "Not renewing", in the same order.
    public let dismissed: [ContractEntry]
    /// The weakest of `wageRangeRules`' evidence, that of the Player Removal advice read and that of the worths.
    public let basis: Evidence

    /// `notRecommended` and `dismissed`: the players Scouting counts as going.
    public var notBeingRenewed: Set<PlayerID> { Set((notRecommended + dismissed).map(\.player)) }
}

/// Who is worth renewing: every player of the club's own, here or out on loan, in his last year or with no contract, is
/// recommended when his worth meets the first eleven's standard, he is not marked to sell and Player Removal does not
/// advise moving him on; every other is not recommended, with the reasons. A function of the data it is handed.
public enum Contracts {
    /// The first that holds: no contract to run down (out of contract, or months left below zero); with an end day,
    /// today on or after the end day less `approachMonths` (a day already past included), then on or after the end day
    /// less `lastYearMonths`, each clamped to its month as `approachableFrom` is, so the day named is the day he moves;
    /// with none and months left known, `approachMonths` or fewer, then `lastYearMonths` or fewer. nil otherwise.
    public static func part(of player: Player, today: Day, parameters: EngineParameters) -> ContractPart? {
        let rules = parameters.wageRangeRules.value
        if player.contractType == .outOfContract { return .noContract }
        if let months = player.monthsLeft, months < 0 { return .noContract }
        if let ends = player.contractEnds {
            if today >= ends.adding(months: -rules.approachMonths) { return .approachable }
            if today >= ends.adding(months: -rules.lastYearMonths) { return .lastYear }
            return nil
        }
        guard let months = player.monthsLeft else { return nil }
        if months <= rules.approachMonths { return .approachable }
        if months <= rules.lastYearMonths { return .lastYear }
        return nil
    }

    /// `elevens` and `depth` are the whole squad's for `tactic`, and `removal` is Player Removal's advice for it.
    /// `dismissed` are the players the owner set aside with "Not renewing", `wanted` those he chose to renew anyway.
    /// Each player in a part is in exactly one list: not recommended and not wanted, `notRecommended`; otherwise
    /// `dismissed` when set aside, else `listed`. A player on loan at the club is in none. Throws
    /// `PlanError.badParameters` while the parameters have problems, and `RatingError` for a player out on loan in a
    /// part with a missing familiarity or attribute, or for one whose worth cannot be measured (`Renewal.worths`).
    public static func report(players: [Player], ownClub: String?, marks: [PlayerID: SaleMark],
                              removal: RemovalReport, elevens: ElevensReport, depth: DepthReport, tactic: Tactic,
                              dismissed: Set<PlayerID>, wanted: Set<PlayerID>, today: Day, catalog: RoleCatalog,
                              profile: RatingProfile, parameters: EngineParameters) throws -> ContractsReport {
        let problems = FitnessModel.problems(in: parameters)
        guard problems.isEmpty else { throw PlanError.badParameters(problems) }
        let rules = parameters.wageRangeRules.value
        let adviceByID = Dictionary(removal.advice.map { ($0.player, $0) }, uniquingKeysWith: { first, _ in first })
        let engine = RatingEngine(profile: profile, parameters: parameters, configuration: .fm27)
        let assignments = try tactic.assignments(catalog: catalog)

        // Measured: every player at the club (the standard looks its first choices up among them) and those out on
        // loan in a part, so one out on loan who is not in his last year cannot stop the list.
        let measured = players.filter { player in
            guard case .loanedOut = LoanStatus.of(player, ownClub: ownClub) else { return true }
            return part(of: player, today: today, parameters: parameters) != nil
        }
        let worths = try Renewal.worths(players: measured, ownClub: ownClub, elevens: elevens, depth: depth,
                                        parameters: parameters)
        let hasStandard = Renewal.standard(elevens: elevens, depth: depth, players: players,
                                           parameters: parameters).rating != nil

        var evidence = [parameters.wageRangeRules.evidence]
        var kept: [(entry: ContractEntry, months: Int?, index: Int)] = []
        for (index, player) in players.enumerated() {
            let loan = LoanStatus.of(player, ownClub: ownClub)
            let club: String?
            switch loan {
            case .own: club = nil
            case .loanedOut(let to): club = to
            case .loanedIn: continue
            }
            guard let part = part(of: player, today: today, parameters: parameters) else { continue }

            let standing: ContractStanding, tier: WageTier, slot: SlotID?, action: RemovalAction?
            let advice: RemovalAdvice?
            if let club {
                var rated: [(slot: SlotID, level: CandidateLevel, margin: Double?)] = []
                for playable in try Scouting.playableSlots(for: player, assignments: assignments, engine: engine,
                                                           parameters: parameters) {
                    let at = playable.assignment.slot
                    let rivals = try Development.rivals(at: at, tiers: elevens.tiers, squad: players, ownClub: ownClub,
                                                        parameters: parameters)
                    let level = Scouting.level(rating: playable.rating, first: rivals.first, second: rivals.second,
                                               secondPlaceIsOpen: Scouting.secondPlaceIsOpen(at: at, in: elevens),
                                               parameters: parameters)
                    rated.append((at, level, rivals.first.map { playable.rating / $0.rating - 1 }))
                }
                let best = WageRange.bestLevel(rated)
                standing = .outOnLoan(to: club, level: best?.level, slot: best?.slot)
                tier = best.map { WageRange.tier(of: $0.level) } ?? .neither
                slot = best?.slot
                action = nil
                advice = nil
            } else {
                advice = adviceByID[player.id]
                if let advice { evidence.append(advice.basis) }
                let found = WageRange.tier(of: player.id, in: elevens.tiers)
                tier = found?.tier ?? .neither
                slot = found?.slot
                switch found {
                case (.firstEleven, let at?)?: standing = .first(at)
                case (.secondEleven, let at?)?: standing = .second(at)
                case (.firstEleven, nil)?, (.secondEleven, nil)?, (.neither, _)?, nil: standing = .neither
                }
                action = advice?.action
            }

            let worth = worths[player.id]
            if let worth { evidence.append(worth.basis) }
            let reasons = reasons(marked: marks[player.id] == .toSell,
                                  // Advised to go only by Player Removal's own advice on him.
                                  advisedTo: removal.advisedToLeave.contains(player.id) ? advice?.action : nil,
                                  worth: worth, hasStandard: hasStandard, standing: standing, need: advice?.neededAt)
            let ends = player.contractEnds
            let entry = ContractEntry(
                player: player.id, name: player.name, part: part, ends: ends,
                approachableFrom: part == .lastYear ? ends?.adding(months: -rules.approachMonths) : nil,
                standing: standing, action: action, tier: tier, slot: slot, presentWagePerWeek: player.wagePerWeek,
                worth: worth, reasons: reasons, isWanted: !reasons.isEmpty && wanted.contains(player.id))
            kept.append((entry, player.monthsLeft, index))
        }

        // The higher worth first, no worth last; then the earlier end day, then no end day by fewer months left
        // (unknown last); then the order of `players`.
        let sorted = kept.sorted { a, b in
            switch (a.entry.worth?.share, b.entry.worth?.share) {
            case (let x?, let y?): if x != y { return x > y }
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): break
            }
            switch (a.entry.ends, b.entry.ends) {
            case (let x?, let y?): if x != y { return x < y }
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil):
                switch (a.months, b.months) {
                case (let x?, let y?): if x != y { return x < y }
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): break
                }
            }
            return a.index < b.index
        }.map(\.entry)

        let notRecommended = sorted.filter { !$0.reasons.isEmpty && !$0.isWanted }
        let renewing = sorted.filter { $0.reasons.isEmpty || $0.isWanted }
        return ContractsReport(listed: renewing.filter { !dismissed.contains($0.player) },
                               notRecommended: notRecommended,
                               dismissed: renewing.filter { dismissed.contains($0.player) },
                               basis: Evidence.weakest(evidence)!)
    }

    /// Every reason that applies, in order: marked to sell; advised to go by Player Removal; under the standard, or no
    /// slot he can play, or no standard at all; and last, only with another, where he is needed until he is replaced:
    /// first or second choice by his standing, else Player Removal's need for him as cover or a stand-in (a player out
    /// on loan has none).
    static func reasons(marked: Bool, advisedTo action: RemovalAction?, worth: RenewalWorth?, hasStandard: Bool,
                        standing: ContractStanding, need: RemovalNeed?) -> [ContractReason] {
        var reasons: [ContractReason] = []
        if marked { reasons.append(.markedToSell) }
        if let action { reasons.append(.advisedToLeave(action)) }
        if !hasStandard {
            reasons.append(.noStandard)
        } else if let worth {
            if !worth.meetsStandard { reasons.append(.underStandard(worth)) }
        } else {
            reasons.append(.noSlot)
        }
        guard !reasons.isEmpty else { return [] }
        switch standing {
        case .first(let slot): reasons.append(.replaceFirst(slot: slot, why: .firstChoice))
        case .second(let slot): reasons.append(.replaceFirst(slot: slot, why: .secondChoice))
        case .neither:
            guard let need else { break }
            switch need.kind {
            case .cover: reasons.append(.replaceFirst(slot: need.slot, why: .cover))
            case .standIn: reasons.append(.replaceFirst(slot: need.slot, why: .standIn))
            // First choice where cover is thin goes with a standing of first choice, given above.
            case .firstChoiceWhereThin: break
            }
        case .outOnLoan: break
        }
        return reasons
    }
}
