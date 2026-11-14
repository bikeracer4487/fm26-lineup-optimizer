import LineupEngine

extension AppModel {
    /// Marks `player` to sell or to loan out, or with nil takes his mark off, then plans again: the planner favours a
    /// marked player slightly in low-importance and sharpness fixtures. Only a player in the squads who is not on loan
    /// here can be marked; for anyone else nothing happens.
    public func setMark(_ mark: SaleMark?, for player: PlayerID) {
        guard let held = squad.book.allPlayers.first(where: { $0.id == player }) else { return }
        if case .loanedIn = squad.book.loanStatus(of: held, override: settings.clubOverride) { return }
        guard marks[player] != mark else { return }
        marks[player] = mark
        save(.marks)
        replan()
    }

    /// Takes off the marks that have done their work, after an import: one whose player is no longer in any squad, and
    /// a mark to loan out whose player is now out on loan. Otherwise he would be favoured again the day he came back.
    /// The import plans again itself.
    func dropSpentMarks() {
        let players = Dictionary(squad.book.allPlayers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let kept = marks.filter { id, mark in
            guard let player = players[id] else { return false }
            switch (mark, squad.book.loanStatus(of: player, override: settings.clubOverride)) {
            case (.toLoanOut, .loanedOut): return false
            case (.toLoanOut, .own), (.toLoanOut, .loanedIn), (.toSell, _): return true
            }
        }
        guard kept != marks else { return }
        marks = kept
        save(.marks)
    }
}
