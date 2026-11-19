import Foundation
import LineupEngine

extension AppModel {
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
    /// signed and imported is left out the next time they are read.
    public func candidates(for chosen: UUID?) -> CandidatesState {
        let paste = scoutingPaste   // read first, so whatever shows this is told of a new paste
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
        let judged = workedOutCandidates(paste, tactic: stored.tactic, needs: needs)
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

    /// Whether "Clear" has anything to clear: players are held, or a refusal is shown, which it dismisses.
    public var canClearCandidates: Bool { scoutingPaste != nil || scoutingPasteProblem != nil }

    /// Every held candidate's row for the tactic the Scouting screen shows, so all can be opened at once; none while
    /// no candidates are judged.
    public func allCandidateRowIDs(for chosen: UUID?) -> Set<PlayerID> {
        guard case .ready(let report) = candidates(for: chosen) else { return [] }
        return candidatesSheet(report, order: .today)?.rowIDs ?? []
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

    private func workedOutCandidates(_ paste: ScoutingPaste, tactic: Tactic, needs: ScoutingNeeds) -> CandidatesState {
        timesCandidatesJudged += 1
        do {
            return .ready(try Scouting.candidates(pasted: paste.players, held: squad.book.allPlayers, ownClub: ownClub,
                                                  tactic: tactic, needs: needs, catalog: catalog, profile: profile,
                                                  parameters: planParameters))
        } catch {
            return .failed([ErrorDescriptions.describe(error)])
        }
    }
}
