import Foundation

/// The part of Contracts a player is listed in, in the screen's order.
public enum ContractPart: String, CaseIterable, Sendable {
    /// `approachMonths` or fewer left: other clubs can approach him now.
    case approachable
    /// `lastYearMonths` or fewer left.
    case lastYear
    /// Out of contract, or months left below zero: no contract to run down.
    case noContract
}

/// Where a listed player stands for the tactic.
public enum ContractStanding: Equatable, Sendable {
    case first(SlotID), second(SlotID), neither
    /// Out on loan at `to`, with his best level at a slot of the tactic against the whole squad's elevens; nil level and
    /// slot when he can play no slot.
    case outOnLoan(to: String, level: CandidateLevel?, slot: SlotID?)
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
}

public struct ContractsReport: Equatable, Sendable {
    /// The players to look at renewing, by part, the sooner end first, then the order of the players handed in.
    public let listed: [ContractEntry]
    /// The players the owner has dismissed, in the same order.
    public let dismissed: [ContractEntry]
    /// Players who would be listed but are marked to sell or loan out, or advised to leave.
    public let leftOutAsGoing: Int
    /// The weakest of `wageRangeRules`' evidence and that of the Player Removal advice read.
    public let basis: Evidence
}

/// Who is listed on Contracts: the club's own players, here or out on loan, in their last year or with no contract, who
/// are not going and, on a youth contract or with no contract, are in an eleven or worth developing. A function of the
/// data it is handed.
public enum Contracts {
    /// The first that holds: no contract to run down (out of contract, or months left below zero); with an end day, on
    /// or before `approachMonths` from today (a day already past included), then on or before `lastYearMonths`; with
    /// none and months left known, `approachMonths` or fewer, then `lastYearMonths` or fewer. nil otherwise.
    public static func part(of player: Player, today: Day, parameters: EngineParameters) -> ContractPart? {
        let rules = parameters.wageRangeRules.value
        if player.contractType == .outOfContract { return .noContract }
        if let months = player.monthsLeft, months < 0 { return .noContract }
        if let ends = player.contractEnds {
            if ends <= today.adding(months: rules.approachMonths) { return .approachable }
            if ends <= today.adding(months: rules.lastYearMonths) { return .lastYear }
            return nil
        }
        guard let months = player.monthsLeft else { return nil }
        if months <= rules.approachMonths { return .approachable }
        if months <= rules.lastYearMonths { return .lastYear }
        return nil
    }

    /// `elevens` are the whole squad's for `tactic`, and `removal` is Player Removal's advice for it. Throws
    /// `PlanError.badParameters` while the parameters have problems, and `RatingError` for a player out on loan with a
    /// missing familiarity or attribute.
    public static func report(players: [Player], ownClub: String?, marks: [PlayerID: SaleMark],
                              removal: RemovalReport, elevens: ElevensReport, tactic: Tactic,
                              dismissed: Set<PlayerID>, today: Day, catalog: RoleCatalog, profile: RatingProfile,
                              parameters: EngineParameters) throws -> ContractsReport {
        let problems = FitnessModel.problems(in: parameters)
        guard problems.isEmpty else { throw PlanError.badParameters(problems) }
        let rules = parameters.wageRangeRules.value
        let adviceByID = Dictionary(removal.advice.map { ($0.player, $0) }, uniquingKeysWith: { first, _ in first })
        let engine = RatingEngine(profile: profile, parameters: parameters, configuration: .fm27)
        let assignments = try tactic.assignments(catalog: catalog)

        var evidence = [parameters.wageRangeRules.evidence]
        var kept: [(entry: ContractEntry, months: Int?, index: Int)] = []
        var going = 0
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
            let passesGate: Bool
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
                passesGate = best?.level == .wouldStart || best?.level == .wouldMakeSecond
            } else {
                let advice = adviceByID[player.id]
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
                passesGate = tier != .neither || advice?.outlook.map(Removal.isWorthDeveloping) == true
            }

            if Removal.isOnYouthContract(player) || part == .noContract, !passesGate { continue }
            if marks[player.id] != nil || removal.advisedToLeave.contains(player.id) {
                going += 1
                continue
            }
            let ends = player.contractEnds
            let entry = ContractEntry(
                player: player.id, name: player.name, part: part, ends: ends,
                approachableFrom: part == .lastYear ? ends?.adding(months: -rules.approachMonths) : nil,
                standing: standing, action: action, tier: tier, slot: slot, presentWagePerWeek: player.wagePerWeek)
            kept.append((entry, player.monthsLeft, index))
        }

        // The parts in order; within one the earlier end day, then no end day by fewer months left (unknown last);
        // then the order of `players`.
        let parts = ContractPart.allCases
        let sorted = kept.sorted { a, b in
            let pa = parts.firstIndex(of: a.entry.part)!, pb = parts.firstIndex(of: b.entry.part)!
            if pa != pb { return pa < pb }
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

        return ContractsReport(listed: sorted.filter { !dismissed.contains($0.player) },
                               dismissed: sorted.filter { dismissed.contains($0.player) },
                               leftOutAsGoing: going, basis: Evidence.weakest(evidence)!)
    }
}
