import Foundation
import LineupEngine

extension AppModel {
    /// How soon after one training action another is ignored. Accepting or turning down a recommendation removes its
    /// card at once and the model replans before the click is over, so the next card's buttons move up under the
    /// pointer: without this, the second click of a double-click would accept or turn down the next player.
    public static let trainingActionInterval: TimeInterval = 0.5

    /// Accepts the retraining, dated with the game's current date, with the player's familiarity at the position in the
    /// squads now as its first observation. A player learns one position at a time, so an earlier acceptance of his is
    /// replaced and its observations forgotten. A rejection of the same pair is cleared. Accepting a pair already
    /// accepted keeps its date and observations and only clears a rejection. A notice says what was accepted. Nothing
    /// happens for a player in no squad, or within `trainingActionInterval` of the last training action.
    public func accept(_ choice: RetrainingChoice) {
        guard mayTakeTrainingAction(),
              let player = squad.book.allPlayers.first(where: { $0.id == choice.player }) else { return }
        tellTraining(AdvisorText.nowLearning(name: player.name, position: choice.position))
        guard !training.accepted.contains(where: { TrainingState.choice($0) == choice }) else {
            return changeTraining { $0.rejected.remove(choice) }
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

    /// Turns the retraining down, leaving any acceptance of it alone. A notice says what was turned down. Nothing
    /// happens for a player in no squad, or within `trainingActionInterval` of the last training action.
    public func reject(_ choice: RetrainingChoice) {
        guard mayTakeTrainingAction(),
              let player = squad.book.allPlayers.first(where: { $0.id == choice.player }) else { return }
        tellTraining(AdvisorText.notOfferedAgain(name: player.name, position: choice.position))
        changeTraining { state in
            state.rejected.insert(choice)
            state.names[choice.player] = player.name
        }
    }

    /// Forgets the acceptance and its observations; nothing within `trainingActionInterval` of the last training action.
    public func stopRetraining(_ choice: RetrainingChoice) {
        guard mayTakeTrainingAction() else { return }
        changeTraining { state in
            state.accepted.removeAll { TrainingState.choice($0) == choice }
            state.observations[choice] = nil
        }
    }

    /// Undoes `reject`; nothing within `trainingActionInterval` of the last training action.
    public func allowAgain(_ choice: RetrainingChoice) {
        guard mayTakeTrainingAction() else { return }
        changeTraining { $0.rejected.remove(choice) }
    }

    /// Whether a training action arriving now goes ahead: the first always does, a later one only once
    /// `trainingActionInterval` has passed since the last that went ahead, whose time this then records.
    private func mayTakeTrainingAction() -> Bool {
        let now = environment.now()
        if let last = lastTrainingAction, now - last < Self.trainingActionInterval { return false }
        lastTrainingAction = now
        return true
    }

    /// Shows `text` as a notice in place of the last one an accepting or turning down showed.
    private func tellTraining(_ text: String) {
        if let showing = trainingNotice { notices.removeAll { $0.id == showing } }
        let notice = Notice(text: text)
        notices.append(notice)
        trainingNotice = notice.id
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
