import Foundation
import LineupEngine

extension AppModel {
    /// A "Dismiss" or "Show again" inside this many seconds of the end of the last of either is ignored: each takes a
    /// row away and moves the next row's button under the pointer. One clock for the two, apart from Training's and
    /// Scouting's.
    public static let contractsActionInterval: TimeInterval = 0.5

    /// The Contracts screen for the primary tactic: the engine's list from the squad book's players in its order, the
    /// marks, the advice's Player Removal and elevens, the players not being renewed and today in the game, each listed
    /// player with the range for his tier and the agent's figure. Worked out each time it is read, so a change of
    /// date, mark or figure shows at once.
    public var contractsSheet: ContractsSheetState {
        let state = adviceState
        guard case .ready(let advice) = state, let primary = primaryTactic else { return .notReady(state) }
        let players = squad.book.allPlayers
        let club = ownClub
        let parameters = planParameters
        do {
            let report = try Contracts.report(
                players: players, ownClub: club, marks: marks, removal: advice.removal, elevens: advice.elevens,
                tactic: primary.tactic, dismissed: Set(contracts.dismissed.keys), today: settings.currentDate,
                catalog: catalog, profile: profile, parameters: parameters)
            let wages = WageRange.tierWages(tiers: advice.elevens.tiers, players: players, ownClub: club)
            let byID = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            return .ready(try ContractsPresentation.sheet(report, players: byID, wages: wages,
                                                          state: contracts, money: squad.book.moneyStyle,
                                                          parameters: parameters))
        } catch {
            return .failed([ErrorDescriptions.describe(error)])
        }
    }

    /// The count on the Contracts pill: the players listed in its parts; nil while the list is not ready or cannot be
    /// worked out, and at 0.
    public var contractsCount: Int? {
        guard case .ready(let sheet) = contractsSheet else { return nil }
        let count = sheet.parts.reduce(0) { $0 + $1.rows.count }
        return count > 0 ? count : nil
    }

    /// Sets one of the club's wage figures from what the owner typed, in the period FMRTE shows wages by, kept by the
    /// week. Blank clears it and 0 is a value. The day entered is today in the game, or nil once all three are blank.
    /// Saves the contracts file and nothing else; does not plan.
    public func setWageLimit(_ field: WageLimitField, text: String) {
        let perWeek = TypedNumber.value(text).map { squad.book.moneyStyle.period.perWeek(Double($0)) }
        var limits = contracts.limits
        switch field {
        case .wageBudget: limits.wageBudgetPerWeek = perWeek
        case .wagesSpent: limits.wagesSpentPerWeek = perWeek
        case .highestWage: limits.highestWagePerWeek = perWeek
        }
        guard limits != contracts.limits else { return }
        contracts.limits = limits
        let none = limits.wageBudgetPerWeek == nil && limits.wagesSpentPerWeek == nil && limits.highestWagePerWeek == nil
        contracts.limitsEntered = none ? nil : settings.currentDate
        save(.contracts)
    }

    /// Keeps what an agent asked for a player, typed in FMRTE's wage period; blank removes it. Nothing for a player in
    /// no squad held.
    public func setAgentFigure(text: String, for player: PlayerID) {
        guard squad.book.allPlayers.contains(where: { $0.id == player }) else { return }
        let new = TypedNumber.value(text).map {
            AgentFigure(perWeek: squad.book.moneyStyle.period.perWeek(Double($0)), entered: settings.currentDate)
        }
        guard contracts.figures[player] != new else { return }
        contracts.figures[player] = new
        save(.contracts)
    }

    /// Sets a player aside as not being renewed, today in the game. Nothing for one already set aside, or within
    /// `contractsActionInterval` of the last dismissal or showing.
    public func dismissContract(_ player: PlayerID) {
        contractsAction {
            guard contracts.dismissed[player] == nil else { return false }
            contracts.dismissed[player] = settings.currentDate
            save(.contracts)
            return true
        }
    }

    /// Brings a player set aside back to the list. Nothing for one not set aside, or within the interval.
    public func showContractAgain(_ player: PlayerID) {
        contractsAction {
            guard contracts.dismissed[player] != nil else { return false }
            contracts.dismissed[player] = nil
            save(.contracts)
            return true
        }
    }

    /// Runs `action` unless it arrives within `contractsActionInterval` of the end of the last one that ran; the
    /// first always runs. An action that changed nothing does not start the interval.
    private func contractsAction(_ action: () -> Bool) {
        let start = environment.now()
        if let last = lastContractsAction, start - last < Self.contractsActionInterval { return }
        if action() { lastContractsAction = environment.now() }
    }

    /// Drops the dismissals and figures that have done their work. Called after `target` is imported, and only then:
    /// unlike a mark, no entry turns on the club's name, since neither rule below reads who is on loan. A player's
    /// entries go when he is held and his contract no longer puts him in any part of the list (he was renewed), or
    /// when he is in no squad, once every squad held has been imported without him. A player with no contract is in
    /// the list, so he stays. Saves only when something is dropped; the caller plans.
    func dropSpentContractEntries(imported target: Squad) {
        let players = Dictionary(squad.book.allPlayers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let held = Set(squad.importedOn.keys)
        let today = settings.currentDate
        let parameters = planParameters
        var state = contracts
        for id in Set(contracts.dismissed.keys).union(contracts.figures.keys) {
            guard let player = players[id] else {
                contractsAbsentFrom[id, default: []].insert(target)
                if let seen = contractsAbsentFrom[id], seen.isSuperset(of: held) {
                    state.dismissed[id] = nil
                    state.figures[id] = nil
                    contractsAbsentFrom[id] = nil
                }
                continue
            }
            contractsAbsentFrom[id] = nil
            if Contracts.part(of: player, today: today, parameters: parameters) == nil {
                state.dismissed[id] = nil
                state.figures[id] = nil
            }
        }
        guard state != contracts else { return }
        contracts = state
        save(.contracts)
    }
}
