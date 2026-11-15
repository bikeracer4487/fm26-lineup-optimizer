import Foundation
import LineupEngine

extension AppModel {
    /// Reads the opponent's squad off the clipboard and sets the draft's strength from it. The pasted players are read
    /// and dropped: they enter no squad, mark, plan or advice, and nothing is saved here (the draft is saved with the
    /// fixture). On a refusal the draft keeps its strength and any earlier reading, and `pasteProblem` says why.
    public func pasteOpponentSquad(into draft: inout FixtureDraft) {
        let text: String, config: Data
        switch readClipboardAndConfig() {
        case .success(let read): (text, config) = read
        case .failure(let failure):
            draft.pasteProblem = failure.reason
            return
        }
        do {
            // The importer needs a squad to read for; the opponent's rows are only the first team's shape.
            let result = try Importer.importPlayers(clipboard: text, fmrteConfig: config, squad: .firstTeam)
            let reading = try OpponentAdvisor.read(
                theirs: result.players, named: draft.opponent, own: squad.book.allPlayers, ownClub: ownClub,
                on: settings.currentDate, parameters: planParameters)
            draft.opponentStrength = reading.strength
            draft.opponentReading = reading
            draft.pasteProblem = nil
        } catch {
            draft.pasteProblem = ErrorDescriptions.describe(error)
        }
    }
}
