import LineupEngine

extension AppModel {
    /// Marks `player` to sell or to loan out, or with nil takes his mark off, then plans again: the planner favours a
    /// marked player slightly in low-importance and sharpness fixtures. Only a player in the squads who is not on loan
    /// here can be marked, and a player on a youth contract (as the engine reads one: `Removal.isOnYouthContract`) only
    /// to sell, since he cannot be loaned out (the owner's correction of 22 November 2026); for anything else nothing
    /// happens. A mark can be taken off whoever holds it.
    public func setMark(_ mark: SaleMark?, for player: PlayerID) {
        if mark != nil {
            guard let held = squad.book.allPlayers.first(where: { $0.id == player }) else { return }
            if case .loanedIn = squad.book.loanStatus(of: held, override: settings.clubOverride) { return }
            if mark == .toLoanOut, Removal.isOnYouthContract(held) { return }
        }
        guard marks[player] != mark else { return }
        marks[player] = mark
        if mark == nil { marksAbsentFrom[player] = nil }
        save(.marks)
        replan()
    }

    /// Takes off the marks that have done their work or no longer apply. Called after `target` is imported, and with
    /// nil when the club's name changes. A mark goes when its player:
    /// - is on loan here (he was sold and loaned back, or the club's name now reads him so);
    /// - was marked to loan out and is now out on loan, so he is not favoured again the day he comes back;
    /// - was marked to loan out and is on a youth contract, which cannot be loaned out (a mark to sell stays);
    /// - is in no squad, once every squad held has been imported without him.
    /// The caller plans again.
    func dropSpentMarks(imported target: Squad? = nil) {
        let players = Dictionary(squad.book.allPlayers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let held = Set(squad.importedOn.keys)
        var kept = marks
        for (id, mark) in marks {
            guard let player = players[id] else {
                if let target { marksAbsentFrom[id, default: []].insert(target) }
                if let seen = marksAbsentFrom[id], seen.isSuperset(of: held) {
                    kept[id] = nil
                    marksAbsentFrom[id] = nil
                }
                continue
            }
            marksAbsentFrom[id] = nil
            if mark == .toLoanOut, Removal.isOnYouthContract(player) {
                kept[id] = nil
                continue
            }
            switch (mark, squad.book.loanStatus(of: player, override: settings.clubOverride)) {
            case (_, .loanedIn), (.toLoanOut, .loanedOut): kept[id] = nil
            case (.toLoanOut, .own), (.toSell, .own), (.toSell, .loanedOut): break
            }
        }
        guard kept != marks else { return }
        marks = kept
        save(.marks)
    }
}
