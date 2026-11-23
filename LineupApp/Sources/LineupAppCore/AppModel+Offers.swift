import Foundation
import LineupEngine

extension AppModel {
    /// A recording, "No bid came", an answer, accepting a club's terms and ending a deal are ignored within this long of
    /// the end of the last of them: each changes the rows under the pointer, so a double-click would otherwise record
    /// twice or answer the next round too. One clock for them all, apart from the Training and Scouting screens'.
    public static let offersActionInterval: TimeInterval = 0.5

    /// What the recorded asks and deals show, read from `offers.measureFrom` (all of the record when it is nil).
    public var offerMeasures: OfferMeasures {
        Offers.measures(asks: offers.asks, deals: offers.deals, from: offers.measureFrom, parameters: planParameters)
    }

    /// The terms his block works out, sale or loan: nil for a player with no mark; a sale when a loan cannot be worked
    /// out for him (`loanRefusal(for:)`), whatever is saved; else the kind the owner chose (`setOfferKind`), else his
    /// mark's (a sale for a player marked to sell, a loan for one marked to loan out). The owner asked on 22 November
    /// 2026 to choose either for any marked player; the mark no longer sets the kind.
    public func offerKind(for player: PlayerID) -> OfferKind? {
        guard let mark = markKind(for: player) else { return nil }
        if loanRefusal(for: player) != nil { return .sale }
        return offers.players[player]?.kind ?? mark
    }

    /// The engine's sentence on why loan terms cannot be worked out for him: he is on a youth contract
    /// (`Removal.isOnYouthContract`), or he is out on loan already (as the squad book reads his loan with the club's
    /// name); nil when they can, and for a player not in the squads.
    public func loanRefusal(for player: PlayerID) -> String? {
        guard let held = heldPlayer(player) else { return nil }
        if Removal.isOnYouthContract(held) { return AdvisorText.youthContractNotLoaned }
        switch squad.book.loanStatus(of: held, override: settings.clubOverride) {
        case .loanedOut: return AdvisorText.outOnLoanAlready
        case .own, .loanedIn: return nil
        }
    }

    /// Chooses sale or loan terms for a marked player's block. The choice is saved with his value, as nil when it is
    /// his mark's kind, so that the block follows his mark again; a change of mark clears it (`setMark`). Saves the
    /// offers file and does not plan; nothing for a player with no mark or not in the squads, for a loan when one cannot
    /// be worked out for him, or when the saved choice would not change. Sale terms chosen while a loan is refused, and
    /// so already shown, still clear a saved loan, so it does not come back when he can be loaned again.
    public func setOfferKind(_ kind: OfferKind, for player: PlayerID) {
        guard let mark = markKind(for: player), heldPlayer(player) != nil else { return }
        switch kind {
        case .sale: break
        case .loan: if loanRefusal(for: player) != nil { return }
        }
        let choice: OfferKind? = kind == mark ? nil : kind
        guard offers.players[player]?.kind != choice else { return }
        offers.players[player, default: PlayerOffer()].kind = choice
        save(.offers)
    }

    /// The kind his mark gives: a sale for a player marked to sell, a loan for one marked to loan out; nil with no mark.
    private func markKind(for player: PlayerID) -> OfferKind? {
        switch marks[player] {
        case .toSell?: .sale
        case .toLoanOut?: .loan
        case nil: nil
        }
    }

    /// Sets his value from what was typed, read by `TypedNumber`: its digits, at most twelve, are the value, and text
    /// with no digit is none. When
    /// the value changes its day becomes today in the game (none with no value). Saves the offers file and does not
    /// plan; nothing for a player who is not in the squads, or when the value is unchanged.
    public func setOfferValue(text: String, for player: PlayerID) {
        guard heldPlayer(player) != nil else { return }
        let value = TypedNumber.value(text)
        var entry = offers.players[player] ?? PlayerOffer()
        guard entry.value != value else { return }
        entry.value = value
        entry.valueDay = value == nil ? nil : settings.currentDate
        offers.players[player] = entry
        save(.offers)
    }

    /// Sets what his loan is for, which then stays whatever his age. Saves the offers file and does not plan; nothing for
    /// a player who is not in the squads, or when it is already his.
    public func setLoanPurpose(_ purpose: LoanPurpose, for player: PlayerID) {
        guard heldPlayer(player) != nil else { return }
        var entry = offers.players[player] ?? PlayerOffer()
        guard entry.purpose != purpose else { return }
        entry.purpose = purpose
        offers.players[player] = entry
        save(.offers)
    }

    /// What his loan is for: as saved, when the owner switched it or a loan ask or round was recorded for him (which
    /// keeps the purpose then in force, so a birthday in the middle of a deal does not change it); else development at
    /// `developingUpToAge` or under and moving his wage when older; and moving his wage for a player not in the squads,
    /// whose age is not known.
    public func loanPurpose(for player: PlayerID) -> LoanPurpose {
        if let own = offers.players[player]?.purpose { return own }
        guard let held = heldPlayer(player) else { return .wage }
        return held.age <= planParameters.developingUpToAge.value ? .development : .wage
    }

    /// Sets one of a club's figures from what was typed, read by `TypedNumber` as a value is. The transfer budget is whole units;
    /// the three wage figures are typed in the period FMRTE shows wages by (the squad book's `moneyStyle`) and kept by
    /// the week. The entry keeps the club's name as last typed, trimmed, and today in the game as its day. Saves the
    /// offers file and does not plan; nothing for a blank name, when the figures are unchanged, or for a blank figure
    /// of a club with no entry.
    public func setClubFigure(_ field: ClubField, text: String, club: String) {
        let name = club.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let key = PlayerID.normalise(name)
        let number = TypedNumber.value(text)
        let old = offers.clubs[key]?.figures
        guard old != nil || number != nil else { return }
        var figures = old ?? ClubFigures(name: name, transferBudget: nil, wageBudgetPerWeek: nil, wagesSpentPerWeek: nil,
                                         highestWagePerWeek: nil)
        figures.name = name
        let perWeek = number.map { squad.book.moneyStyle.period.perWeek(Double($0)) }
        switch field {
        case .transferBudget: figures.transferBudget = number
        case .wageBudget: figures.wageBudgetPerWeek = perWeek
        case .wagesSpent: figures.wagesSpentPerWeek = perWeek
        case .highestWage: figures.highestWagePerWeek = perWeek
        }
        guard figures != old else { return }
        offers.clubs[key] = ClubEntry(figures: figures, enteredOn: settings.currentDate)
        save(.offers)
    }

    /// The figures entered for the club of this name, compared by `PlayerID.normalise`; nil when none are.
    public func clubEntry(named name: String) -> ClubEntry? {
        offers.clubs[PlayerID.normalise(name)]
    }

    /// The player's open deal of `kind` (nil: the kind shown, `offerKind(for:)`) with the club of this name, compared
    /// by `PlayerID.normalise`; nil when there is none, or when he has no mark. A round of that kind recorded for him
    /// joins this deal.
    public func openDeal(for player: PlayerID, club: String, kind: OfferKind? = nil) -> OfferDeal? {
        guard let shown = offerKind(for: player) else { return nil }
        let kind = kind ?? shown
        let key = PlayerID.normalise(club)
        return offers.deals.last {
            $0.player == player && $0.kind == kind && $0.state == .open && PlayerID.normalise($0.club) == key
        }
    }

    /// Records terms of `kind` (nil: the kind shown, `offerKind(for:)`) asked of clubs in general, dated today in the
    /// game with his value and wage as they stand now. A loan ask keeps what his loan is for, when nothing is saved, as
    /// `keepLoanPurpose` says.
    /// Refused, with the engine's sentence and nothing saved, for a loan when one cannot be worked out for him
    /// (`loanRefusal(for:)`), when he has no value typed, or when the terms are not good terms of that kind; nothing for
    /// a player with no mark or not in the squads, or within `offersActionInterval` of the last recording. Saves the
    /// offers file and does not plan.
    @discardableResult public func recordAsk(for player: PlayerID, terms: OfferTerms, kind: OfferKind? = nil) -> String? {
        offersAction {
            let subject: RecordSubject
            switch recordSubject(player, terms: terms, kind: kind) {
            case .refused(let sentence): return sentence
            case .nothing: return nil
            case .ready(let ready): subject = ready
            }
            offers.asks.append(OfferAsk(id: UUID(), player: player, playerName: subject.name, kind: subject.kind,
                                        day: settings.currentDate, terms: terms, value: subject.value,
                                        wagePerWeek: subject.wagePerWeek, noBidCame: false))
            keepLoanPurpose(for: player, kind: subject.kind)
            save(.offers)
            return nil
        }
    }

    /// Marks the ask as one that drew no bid. Nothing when it is already marked or there is no such ask, or within
    /// `offersActionInterval` of the last recording. Saves the offers file and does not plan.
    public func noBidCame(_ ask: UUID) {
        offersAction {
            guard let index = offers.asks.firstIndex(where: { $0.id == ask }), !offers.asks[index].noBidCame else {
                return nil
            }
            offers.asks[index].noBidCame = true
            save(.offers)
            return nil
        }
    }

    /// Records a round of `kind` (nil: the kind shown) with the club of this name, dated today in the game with his
    /// value and wage as they stand now. It joins his open deal of that kind with that club
    /// (`openDeal(for:club:kind:)`), or opens one, which keeps the club's figures as entered now (nil when no figure
    /// is). A round of the club's after one of the owner's leaves that round's answer as it is. A loan round keeps what
    /// his loan is for as a loan ask does. Refused as `recordAsk` is; nothing, too, for a blank club name. Saves the
    /// offers file and does not plan.
    @discardableResult public func recordRound(for player: PlayerID, club: String, by: RoundBy,
                                               terms: OfferTerms, kind: OfferKind? = nil) -> String? {
        offersAction {
            let subject: RecordSubject
            switch recordSubject(player, terms: terms, kind: kind) {
            case .refused(let sentence): return sentence
            case .nothing: return nil
            case .ready(let ready): subject = ready
            }
            let name = club.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let round = OfferRound(day: settings.currentDate, by: by, terms: terms, value: subject.value,
                                   wagePerWeek: subject.wagePerWeek, answer: nil)
            if let open = openDeal(for: player, club: name, kind: subject.kind),
               let index = offers.deals.firstIndex(where: { $0.id == open.id }) {
                offers.deals[index].rounds.append(round)
            } else {
                let figures = clubEntry(named: name)?.figures
                offers.deals.append(OfferDeal(id: UUID(), player: player, playerName: subject.name, kind: subject.kind,
                                              club: name, figures: figures.flatMap { $0.hasAnyFigure ? $0 : nil },
                                              rounds: [round], endedOn: nil))
            }
            keepLoanPurpose(for: player, kind: subject.kind)
            save(.offers)
            return nil
        }
    }

    /// Sets the club's answer on the deal's last round, when the deal is open and that round is the owner's with no
    /// answer yet. Nothing otherwise, or within `offersActionInterval` of the last recording. Saves the offers file and
    /// does not plan.
    public func answer(_ answer: RoundAnswer, deal: UUID) {
        changeLastRound(of: deal) { round in
            guard round.by == .owner, round.answer == nil else { return false }
            round.answer = answer
            return true
        }
    }

    /// Accepts the club's terms: the deal's last round is marked accepted, so the deal is agreed, when the deal is open
    /// and that round is the club's. Nothing otherwise, or within `offersActionInterval` of the last recording. Saves the
    /// offers file and does not plan.
    public func acceptTheirs(deal: UUID) {
        changeLastRound(of: deal) { round in
            guard round.by == .club, round.answer == nil else { return false }
            round.answer = .accepted
            return true
        }
    }

    /// Ends an open deal today in the game. Nothing for a deal that is not open, or within `offersActionInterval` of the
    /// last recording. Saves the offers file and does not plan.
    public func endDeal(_ deal: UUID) {
        offersAction {
            guard let index = offers.deals.firstIndex(where: { $0.id == deal }), offers.deals[index].state == .open else {
                return nil
            }
            offers.deals[index].endedOn = settings.currentDate
            save(.offers)
            return nil
        }
    }

    /// Removes the deal, after the screen has asked. Saves the offers file and does not plan; nothing for no such deal.
    public func deleteDeal(_ deal: UUID) {
        guard offers.deals.contains(where: { $0.id == deal }) else { return }
        offers.deals.removeAll { $0.id == deal }
        save(.offers)
    }

    /// Removes the ask, after the screen has asked. Saves the offers file and does not plan; nothing for no such ask.
    public func deleteAsk(_ ask: UUID) {
        guard offers.asks.contains(where: { $0.id == ask }) else { return }
        offers.asks.removeAll { $0.id == ask }
        save(.offers)
    }

    /// Reads the measures from today in the game on; every ask and deal stays in the record. Saves the offers file and
    /// does not plan.
    public func measureOffersAgain() {
        guard offers.measureFrom != settings.currentDate else { return }
        offers.measureFrom = settings.currentDate
        save(.offers)
    }

    // MARK: Working it out

    /// The first time a loan ask or a loan round is recorded for a player with no purpose saved, saves the purpose then
    /// in force, so that it no longer follows his age in the middle of a deal. The caller saves the file.
    private func keepLoanPurpose(for player: PlayerID, kind: OfferKind) {
        switch kind {
        case .sale: return
        case .loan: break
        }
        guard offers.players[player]?.purpose == nil else { return }
        let purpose = loanPurpose(for: player)
        offers.players[player, default: PlayerOffer()].purpose = purpose
    }

    func heldPlayer(_ id: PlayerID) -> Player? {
        squad.book.allPlayers.first { $0.id == id }
    }

    /// What a recording for a player is made with: his kind, his name, his value and his wage now.
    private struct RecordSubject {
        let kind: OfferKind
        let name: String
        let value: Int
        let wagePerWeek: Double
    }

    private enum RecordCheck {
        case ready(RecordSubject)
        /// The engine's sentence.
        case refused(String)
        /// No mark, or not in the squads: there is nothing to record against.
        case nothing
    }

    /// Whether terms of `kind` (nil: the kind shown) can be recorded for the player: he is marked and in the squads, a
    /// loan can be worked out for him when it is a loan, he has a value, and the terms pass `Offers.check` for the kind.
    private func recordSubject(_ player: PlayerID, terms: OfferTerms, kind asked: OfferKind?) -> RecordCheck {
        guard let shown = offerKind(for: player), let held = heldPlayer(player) else { return .nothing }
        let kind = asked ?? shown
        switch kind {
        case .sale: break
        case .loan: if let refusal = loanRefusal(for: player) { return .refused(refusal) }
        }
        guard let value = offers.players[player]?.value else {
            return .refused(ErrorDescriptions.describe(OfferError.missing(.value, club: nil)))
        }
        do {
            try Offers.check(terms, kind: kind)
        } catch {
            return .refused(ErrorDescriptions.describe(error))
        }
        return .ready(RecordSubject(kind: kind, name: held.name, value: value, wagePerWeek: held.wagePerWeek))
    }

    /// Changes the last round of an open deal through `change`, which says whether it changed it, and saves; guarded as a
    /// recording is.
    private func changeLastRound(of deal: UUID, _ change: (inout OfferRound) -> Bool) {
        offersAction {
            guard let index = offers.deals.firstIndex(where: { $0.id == deal }), offers.deals[index].state == .open,
                  let last = offers.deals[index].rounds.indices.last,
                  change(&offers.deals[index].rounds[last]) else { return nil }
            save(.offers)
            return nil
        }
    }

    /// Runs `action` unless it arrives within `offersActionInterval` of the end of the last one that ran: the first always
    /// runs. The clock is read again once it has finished and that time recorded as the last action's end. Returns what
    /// the action returned, or nil when it was ignored.
    @discardableResult private func offersAction(_ action: () -> String?) -> String? {
        let start = environment.now()
        if let last = lastOffersAction, start - last < Self.offersActionInterval { return nil }
        let result = action()
        lastOffersAction = environment.now()
        return result
    }
}

extension ClubFigures {
    /// Whether any of the four figures is entered.
    var hasAnyFigure: Bool {
        transferBudget != nil || wageBudgetPerWeek != nil || wagesSpentPerWeek != nil || highestWagePerWeek != nil
    }
}
