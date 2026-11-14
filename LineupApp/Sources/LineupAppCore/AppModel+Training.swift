import Foundation
import LineupEngine

extension AppModel {
    /// Accepts the retraining, dated with the game's current date, with the player's familiarity at the position in the
    /// squads now as its first observation (none when he is not in them). A player learns one position at a time, so an
    /// earlier acceptance of his is replaced and its observations forgotten. A rejection of the same pair is cleared.
    /// Accepting a pair already accepted keeps its date and observations and only clears a rejection.
    public func accept(_ choice: RetrainingChoice) {
        guard !training.accepted.contains(where: { TrainingState.choice($0) == choice }) else {
            return changeTraining { $0.rejected.remove(choice) }
        }
        let player = squad.book.allPlayers.first { $0.id == choice.player }
        let today = settings.currentDate
        changeTraining { state in
            for replaced in state.accepted where replaced.player == choice.player {
                state.observations[TrainingState.choice(replaced)] = nil
            }
            state.accepted.removeAll { $0.player == choice.player }
            state.accepted.append(Retraining(player: choice.player, position: choice.position, acceptedOn: today))
            state.rejected.remove(choice)
            if let player {
                state.names[choice.player] = player.name
                if let familiarity = player.familiarity[choice.position] {
                    state.record(familiarity, for: choice, on: today)
                }
            }
        }
    }

    /// Turns the retraining down, leaving any acceptance of it alone.
    public func reject(_ choice: RetrainingChoice) {
        let name = squad.book.allPlayers.first { $0.id == choice.player }?.name
        changeTraining { state in
            state.rejected.insert(choice)
            if let name { state.names[choice.player] = name }
        }
    }

    /// Forgets the acceptance and its observations.
    public func stopRetraining(_ choice: RetrainingChoice) {
        changeTraining { state in
            state.accepted.removeAll { TrainingState.choice($0) == choice }
            state.observations[choice] = nil
        }
    }

    /// Undoes `reject`.
    public func allowAgain(_ choice: RetrainingChoice) {
        changeTraining { $0.rejected.remove(choice) }
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
