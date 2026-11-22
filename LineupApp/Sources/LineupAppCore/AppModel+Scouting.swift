import Foundation
import LineupEngine

extension AppModel {
    /// "Hide" and "Show again" are ignored within this long of the end of the last of either: each takes a row away,
    /// which moves the next row's button under the pointer, so a double-click would otherwise act on the next player
    /// too. One clock for the two, apart from the Training screen's.
    public static let scoutingActionInterval: TimeInterval = 0.5

    /// The needs for the tactic the Scouting screen shows (`scoutingTacticShown`), with the players counted as going
    /// worked out from the ready advice whatever tactic is shown: those on loan here, marked, or advised to leave by
    /// Player Removal. Worked out when first read after a replan and kept until the next.
    public func scoutingNeeds(for chosen: UUID?) -> ScoutingNeedsState {
        let state = adviceState
        guard case .ready(let report) = state else { return .notReady(state) }
        guard let id = scoutingTacticShown(chosen), let stored = tactics.first(where: { $0.id == id }) else {
            return .failed([Self.noPrimaryTactic])   // the advice is ready only with a primary tactic, so never seen
        }
        if let cached = adviceCache?.scoutingNeeds[id] { return cached }
        let needs = workedOutScoutingNeeds(stored.tactic, advice: report)
        adviceCache?.scoutingNeeds[id] = needs
        return needs
    }

    /// The held players judged against the needs for the tactic the Scouting screen shows: as the needs say while
    /// they are not ready or failed, then nothing pasted while no players are held. Judged when first read after a
    /// paste, a "Clear" or a replan (an import, a tactic change, a mark), and kept until the next; so a player since
    /// signed and imported is left out the next time they are read. A hide or a show-again empties what is kept, too.
    public func candidates(for chosen: UUID?) -> CandidatesState {
        // Both read first, before anything kept is returned, so whatever shows this is told of a new paste and of a
        // player hidden or shown again. The kept judgement is not observed, and `scoutingAction` fills it again before
        // a screen next reads it, so a screen that read only the kept one would never hear of the next hide.
        let paste = scoutingPaste
        let hidden = scouting.hidden
        let needs: ScoutingNeeds
        switch scoutingNeeds(for: chosen) {
        case .notReady(let state): return .notReady(state)
        case .failed(let sentences): return .failed(sentences)
        case .ready(let ready): needs = ready
        }
        guard let paste else { return .nothingPasted }
        guard let id = scoutingTacticShown(chosen), let stored = tactics.first(where: { $0.id == id }) else {
            return .failed([Self.noPrimaryTactic])   // as for the needs: never seen
        }
        if let cached = adviceCache?.candidates[id] { return cached }
        let judged = workedOutCandidates(paste, hidden: hidden, tactic: stored.tactic, needs: needs)
        adviceCache?.candidates[id] = judged
        return judged
    }

    /// Reads the players on the clipboard through the squad importer and holds them. On a refusal what was held is
    /// kept and `scoutingPasteProblem` says why, in the engine's sentence: the clipboard or FMRTE's settings file
    /// cannot be read, the importer refuses the rows, or every pasted player is already the owner's. The importer's
    /// warnings are not kept: no identity is kept, and a player out of contract is shown as a free agent by his row.
    /// Saves nothing and does not plan.
    public func pasteCandidates() {
        let text: String, config: Data
        switch readClipboardAndConfig() {
        case .success(let read): (text, config) = read
        case .failure(let failure):
            scoutingPasteProblem = failure.reason
            return
        }
        let result: ImportResult
        do {
            // The importer needs a squad to read for; the pasted players join none.
            result = try Importer.importPlayers(clipboard: text, fmrteConfig: config, squad: .firstTeam)
        } catch {
            scoutingPasteProblem = ErrorDescriptions.describe(error)
            return
        }
        let held = squad.book.allPlayers
        let club = ownClub
        guard result.players.contains(where: { !Scouting.isHeld($0, among: held, ownClub: club) }) else {
            scoutingPasteProblem = AdvisorText.everyPastedPlayerIsYours
            return
        }
        hold(ScoutingPaste(players: result.players, money: result.money))
    }

    /// Lets the held players go, and any refusal with them. Saves nothing and does not plan.
    public func clearCandidates() {
        hold(nil)
    }

    /// Hides the held player with this key: he leaves every group, for every tactic, until `showCandidateAgain`, and
    /// is known again in a later paste by his name and potential ability. The hidden players' file is saved and the
    /// candidates are left to be judged again; nothing plans and no other advice is worked out. Nothing happens for a
    /// key no held player has, for a player already hidden, or within `scoutingActionInterval` of the last "Hide" or
    /// "Show again". `chosen` is the tactic the screen shows, for which the candidates are judged again before the
    /// interval starts.
    public func hideCandidate(_ id: PlayerID, for chosen: UUID?) {
        scoutingAction(for: chosen) {
            guard let player = scoutingPaste?.players.first(where: { $0.id == id }),
                  !Scouting.isHidden(player, among: scouting.hidden) else { return }
            scouting.hidden.append(HiddenCandidate(player))
            hiddenCandidatesChanged()
        }
    }

    /// Undoes `hideCandidate` for the held player with this key: every saved entry that matches him is removed, so a
    /// player saved twice comes back at once, and so does a second pasted row of the same player. Saves and judges as
    /// `hideCandidate` does; nothing for a key no held player has, or within `scoutingActionInterval` of the last
    /// "Hide" or "Show again".
    public func showCandidateAgain(_ id: PlayerID, for chosen: UUID?) {
        scoutingAction(for: chosen) {
            guard let player = scoutingPaste?.players.first(where: { $0.id == id }),
                  Scouting.isHidden(player, among: scouting.hidden) else { return }
            scouting.hidden.removeAll { $0.matches(player) }
            hiddenCandidatesChanged()
        }
    }

    /// Whether "Clear" has anything to clear: players are held, or a refusal is shown, which it dismisses.
    public var canClearCandidates: Bool { scoutingPaste != nil || scoutingPasteProblem != nil }

    /// Every held candidate's row for the tactic the Scouting screen shows, so all can be opened at once; none while
    /// no candidates are judged.
    public func allCandidateRowIDs(for chosen: UUID?) -> Set<PlayerID> {
        guard case .ready(let report) = candidates(for: chosen) else { return [] }
        return candidatesSheet(report, order: .today)?.rowIDs ?? []
    }

    /// Every group with a "more players" line for the tactic the Scouting screen shows, so all can be opened at once;
    /// none while no candidates are judged. The groups with a line are the same in either order.
    public func allCandidateGroupIDs(for chosen: UUID?) -> Set<String> {
        guard case .ready(let report) = candidates(for: chosen) else { return [] }
        return candidatesSheet(report, order: .today)?.groupIDs ?? []
    }

    /// The tactic the Scouting screen shows for the owner's choice: that tactic while it is saved, else the primary.
    public func scoutingTacticShown(_ chosen: UUID?) -> UUID? {
        elevensTacticShown(chosen)
    }

    /// What the Needs tab shows for `needs`, with the plan's parameters.
    public func needsSheet(_ needs: ScoutingNeeds) -> NeedsSheet {
        ScoutingPresentation.needsSheet(needs, parameters: planParameters)
    }

    /// What the Candidates tab shows for `report` in `order`, counting the held players and writing money as their
    /// paste did; nil while no players are held.
    public func candidatesSheet(_ report: CandidatesReport, order: CandidateOrder) -> CandidatesSheet? {
        guard let paste = scoutingPaste else { return nil }
        return ScoutingPresentation.candidatesSheet(report, order: order, pasted: paste.players.count, money: paste.money)
    }

    // MARK: Working it out

    /// Holds `paste` (nil: nobody), clears the refusal, and leaves the candidates to be judged again when next read.
    /// Nothing else is worked out again.
    func hold(_ paste: ScoutingPaste?) {
        scoutingPaste = paste
        scoutingPasteProblem = nil
        adviceCache?.candidates = [:]
    }

    /// Saves the hidden players and leaves the candidates to be judged again, for every tactic, when next read.
    private func hiddenCandidatesChanged() {
        save(.scouting)
        adviceCache?.candidates = [:]
    }

    /// Runs `action` unless it arrives within `scoutingActionInterval` of the end of the last one that ran: the first
    /// always runs. Once it has finished the candidates for `chosen` are judged again (they are otherwise judged when
    /// the screen next reads them), then the clock is read again and that time recorded as the last action's end, so
    /// the interval covers the judging.
    private func scoutingAction(for chosen: UUID?, _ action: () -> Void) {
        let start = environment.now()
        if let last = lastScoutingAction, start - last < Self.scoutingActionInterval { return }
        action()
        _ = candidates(for: chosen)
        lastScoutingAction = environment.now()
    }

    private func workedOutScoutingNeeds(_ tactic: Tactic, advice: AdvisorsReport) -> ScoutingNeedsState {
        let problems = problems(of: tactic)
        guard problems.isEmpty else { return .failed(problems) }
        let players = squad.book.allPlayers
        let club = ownClub
        let going = Scouting.going(players: players, ownClub: club, marks: marks,
                                   advisedToLeave: advice.removal.advisedToLeave)
        do {
            return .ready(try Scouting.needs(tactic: tactic, players: players, ownClub: club, going: going,
                                             retraining: retrainingForPlan, catalog: catalog, profile: profile,
                                             parameters: planParameters))
        } catch {
            return .failed([ErrorDescriptions.describe(error)])
        }
    }

    private func workedOutCandidates(_ paste: ScoutingPaste, hidden: [HiddenCandidate], tactic: Tactic,
                                     needs: ScoutingNeeds) -> CandidatesState {
        timesCandidatesJudged += 1
        do {
            return .ready(try Scouting.candidates(pasted: paste.players, held: squad.book.allPlayers,
                                                  hidden: hidden, ownClub: ownClub, tactic: tactic,
                                                  needs: needs, catalog: catalog, profile: profile,
                                                  parameters: planParameters))
        } catch {
            return .failed([ErrorDescriptions.describe(error)])
        }
    }
}
