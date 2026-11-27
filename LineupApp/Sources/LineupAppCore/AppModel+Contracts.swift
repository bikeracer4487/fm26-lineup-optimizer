import Foundation
import LineupEngine

extension AppModel {
    /// "Not renewing", "Show again", "Renew anyway" and "Follow the advice" inside this many seconds of the end of the
    /// last of them are ignored: each takes a row away and moves the next row's button under the pointer. One clock for
    /// the four, apart from Training's and Scouting's.
    public static let contractsActionInterval: TimeInterval = 0.5

    /// The engine's list for the primary tactic, from the squad book's players in its order, the marks, the advice's
    /// Player Removal, elevens and depth, the players not being renewed, those wanted and today in the game; nil while
    /// the advice is not ready or there is no primary tactic. Worked out each time it is asked for and not kept.
    private func contractsReport() -> (advice: AdvisorsReport, report: Result<ContractsReport, any Error>)? {
        guard case .ready(let advice) = adviceState, let primary = primaryTactic else { return nil }
        return (advice, Result {
            try Contracts.report(
                players: squad.book.allPlayers, ownClub: ownClub, marks: marks, removal: advice.removal,
                elevens: advice.elevens, depth: advice.depth, tactic: primary.tactic,
                dismissed: Set(contracts.dismissed.keys), wanted: Set(contracts.wanted.keys),
                today: settings.currentDate, catalog: catalog, profile: profile, parameters: planParameters)
        })
    }

    /// The Contracts screen for the primary tactic: the engine's list (`contractsReport`), each listed player with his
    /// worth, the range for his tier and the agent's figure, and each player not recommended with his reasons. Worked
    /// out each time it is read, so a change of date, mark, figure or choice shows at once.
    public var contractsSheet: ContractsSheetState {
        guard let found = contractsReport() else { return .notReady(adviceState) }
        let players = squad.book.allPlayers
        let parameters = planParameters
        do {
            let report = try found.report.get()
            let wages = WageRange.tierWages(tiers: found.advice.elevens.tiers, players: players, ownClub: ownClub)
            let byID = Dictionary(players.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            return .ready(try ContractsPresentation.sheet(report, players: byID, wages: wages,
                                                          state: contracts, money: squad.book.moneyStyle,
                                                          parameters: parameters))
        } catch {
            return .failed([ErrorDescriptions.describe(error)])
        }
    }

    /// The count on the Contracts pill: the players in the list, those renewed anyway among them; nil while the list is
    /// not ready or cannot be worked out, and at 0.
    public var contractsCount: Int? {
        guard case .ready(let sheet) = contractsSheet else { return nil }
        return sheet.rows.isEmpty ? nil : sheet.rows.count
    }

    /// The players the Contracts list for the primary tactic says are not being renewed: those it does not recommend
    /// and the owner has not chosen to renew, and those he set aside. Scouting counts them as going. Nobody while the
    /// advice is not ready or the list cannot be worked out.
    public var notBeingRenewed: Set<PlayerID> {
        guard let report = try? contractsReport()?.report.get() else { return [] }
        return report.notBeingRenewed
    }

    /// Sets one of the club's wage figures from what the owner typed, for a year as every wage is shown, kept by the
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

    /// Keeps what an agent asked for a player, typed for a year as every wage is shown; blank removes it. Nothing for a player in
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
    /// `contractsActionInterval` of the last of the four actions.
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

    /// "Renew anyway": lists a player the tool does not recommend renewing, at the owner's choice, today in the game,
    /// and takes away any setting aside of his. Nothing for a player who is not among those not recommended (already
    /// wanted, recommended, or not on the list), while the list is not ready, or within the interval.
    public func renewAnyway(_ player: PlayerID) {
        contractsAction {
            guard let report = try? contractsReport()?.report.get(),
                  report.notRecommended.contains(where: { $0.player == player }) else { return false }
            contracts.wanted[player] = settings.currentDate
            contracts.dismissed[player] = nil
            save(.contracts)
            return true
        }
    }

    /// "Follow the advice": undoes "Renew anyway". Nothing for a player not chosen, or within the interval.
    public func followAdvice(_ player: PlayerID) {
        contractsAction {
            guard contracts.wanted[player] != nil else { return false }
            contracts.wanted[player] = nil
            save(.contracts)
            return true
        }
    }

    /// Runs `action` unless it arrives within `contractsActionInterval` of the end of the last one that ran; the
    /// first always runs. An action that changed nothing does not start the interval. One that did changes who
    /// Scouting counts as going, so the kept needs and candidates are left to be worked out again when next read.
    private func contractsAction(_ action: () -> Bool) {
        let start = environment.now()
        if let last = lastContractsAction, start - last < Self.contractsActionInterval { return }
        guard action() else { return }
        adviceCache?.scoutingNeeds = [:]
        adviceCache?.candidates = [:]
        lastContractsAction = environment.now()
    }

    /// Drops the dismissals, the choices to renew anyway and the figures that have done their work. Called after `target` is imported, and only then:
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
        for id in Set(contracts.dismissed.keys).union(contracts.wanted.keys).union(contracts.figures.keys) {
            guard let player = players[id] else {
                contractsAbsentFrom[id, default: []].insert(target)
                if let seen = contractsAbsentFrom[id], seen.isSuperset(of: held) {
                    state.dismissed[id] = nil
                    state.wanted[id] = nil
                    state.figures[id] = nil
                    contractsAbsentFrom[id] = nil
                }
                continue
            }
            contractsAbsentFrom[id] = nil
            if Contracts.part(of: player, today: today, parameters: parameters) == nil {
                state.dismissed[id] = nil
                state.wanted[id] = nil
                state.figures[id] = nil
            }
        }
        guard state != contracts else { return }
        contracts = state
        save(.contracts)
    }
}
