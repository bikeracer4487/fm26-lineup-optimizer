import Foundation
import LineupEngine

extension AppModel {
    /// How soon after one training action has finished another is ignored. Accepting or turning down a recommendation
    /// removes its card at once and the model replans before the click is over, so the next card's buttons move up under
    /// the pointer: without this, the second click of a double-click would accept or turn down the next player. The
    /// interval runs from the end of the last action, after its replan, so a click that waited while a slow replan ran
    /// is ignored too.
    public static let trainingActionInterval: TimeInterval = 0.5

    /// Accepts the retraining, dated with the game's current date, with the player's familiarity at the position in the
    /// squads now as its first observation. A player learns one position at a time, so an earlier acceptance of his is
    /// replaced and its observations forgotten. A rejection of the same pair is cleared. Accepting a pair already
    /// accepted keeps its date and observations and only clears a rejection. A notice says what was accepted. Nothing
    /// happens for a player in no squad, or within `trainingActionInterval` of the last training action.
    public func accept(_ choice: RetrainingChoice) {
        trainingAction {
            guard let player = squad.book.allPlayers.first(where: { $0.id == choice.player }) else { return }
            tellTraining(AdvisorText.nowLearning(name: player.name, position: choice.position))
            guard !training.accepted.contains(where: { TrainingState.choice($0) == choice }) else {
                changeTraining { $0.rejected.remove(choice) }
                return
            }
            let today = settings.currentDate
            changeTraining { state in
                for replaced in state.accepted where replaced.player == choice.player {
                    state.observations[TrainingState.choice(replaced)] = nil
                }
                state.accepted.removeAll { $0.player == choice.player }
                state.accepted.append(Retraining(player: choice.player, position: choice.position, acceptedOn: today))
                state.rejected.remove(choice)
                state.names[choice.player] = player.name
                if let familiarity = player.familiarity[choice.position] {
                    state.record(familiarity, for: choice, on: today)
                }
            }
        }
    }

    /// Turns the retraining down, leaving any acceptance of it alone. A notice says what was turned down. Nothing
    /// happens for a player in no squad, or within `trainingActionInterval` of the last training action.
    public func reject(_ choice: RetrainingChoice) {
        trainingAction {
            guard let player = squad.book.allPlayers.first(where: { $0.id == choice.player }) else { return }
            tellTraining(AdvisorText.notOfferedAgain(name: player.name, position: choice.position))
            changeTraining { state in
                state.rejected.insert(choice)
                state.names[choice.player] = player.name
            }
        }
    }

    /// Forgets the acceptance and its observations, and takes away the notice an accepting or turning down showed, which
    /// may no longer hold; nothing within `trainingActionInterval` of the last training action.
    public func stopRetraining(_ choice: RetrainingChoice) {
        trainingAction {
            clearTrainingNotice()
            changeTraining { state in
                state.accepted.removeAll { TrainingState.choice($0) == choice }
                state.observations[choice] = nil
            }
        }
    }

    /// Undoes `reject`, and takes away the notice an accepting or turning down showed, which may no longer hold; nothing
    /// within `trainingActionInterval` of the last training action.
    public func allowAgain(_ choice: RetrainingChoice) {
        trainingAction {
            clearTrainingNotice()
            changeTraining { $0.rejected.remove(choice) }
        }
    }

    /// Runs `action` unless it arrives within `trainingActionInterval` of the end of the last training action that ran:
    /// the first always runs. Once it has finished, replan and notices included, the advice is worked out again (it is
    /// otherwise worked out when the screen next reads it), then the clock is read again and that time recorded as the
    /// last action's end, so the interval covers the whole recalculation.
    private func trainingAction(_ action: () -> Void) {
        let start = environment.now()
        if let last = lastTrainingAction, start - last < Self.trainingActionInterval { return }
        action()
        _ = adviceState
        lastTrainingAction = environment.now()
    }

    /// Shows `text` as a notice in place of the last one an accepting or turning down showed.
    private func tellTraining(_ text: String) {
        clearTrainingNotice()
        let notice = Notice(text: text)
        notices.append(notice)
        trainingNotice = notice.id
    }

    /// Takes away the notice the last accepting or turning down showed, if it is still showing.
    private func clearTrainingNotice() {
        if let showing = trainingNotice { notices.removeAll { $0.id == showing } }
        trainingNotice = nil
    }

    /// The accepted retrainings of players still in any squad, in the training state's order, as the planner is handed
    /// them. A retraining of a player who has left is kept, so it can be shown and stopped, but not handed on.
    var retrainingForPlan: [Retraining] {
        let inSquads = Set(squad.book.allPlayers.map(\.id))
        return training.accepted.filter { inSquads.contains($0.player) }
    }

    /// Records, for each accepted retraining of a player in the imported squad, his familiarity at the position on the
    /// import's day. Saves without replanning: the import replans after.
    func recordFamiliarity(after squad: Squad, on day: Day) {
        let imported = Dictionary((self.squad.book.current[squad] ?? []).map { ($0.id, $0) },
                                  uniquingKeysWith: { first, _ in first })
        changeTraining(replanning: false) { state in
            for retraining in state.accepted {
                guard let familiarity = imported[retraining.player]?.familiarity[retraining.position] else { continue }
                state.record(familiarity, for: TrainingState.choice(retraining), on: day)
            }
        }
    }
}
