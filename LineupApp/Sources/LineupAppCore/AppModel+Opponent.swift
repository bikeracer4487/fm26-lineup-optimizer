import Foundation
import LineupEngine

extension AppModel {
    /// Reads the opponent's squad off the clipboard and sets the draft's strength from it, then its importance to the one
    /// suggested for the draft with that strength (the owner's request of 25 November 2026), which he can then change;
    /// with no suggestion (the advice not ready, a past day, a confirmed match) the importance stays as it was. The
    /// pasted players are read and dropped: they enter no squad, mark, plan or advice, and nothing is saved here (the
    /// draft is saved with the fixture). On a refusal the draft keeps its strength, importance and any earlier reading,
    /// and `pasteProblem` says why.
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
            if let suggestion = suggestion(for: draft) { draft.importance = suggestion.importance }
        } catch {
            draft.pasteProblem = ErrorDescriptions.describe(error)
        }
    }

    /// For a new league fixture whose opponent has a squad reading on a saved fixture, carries the latest such reading
    /// to the draft (the owner's request of 25 November 2026): their side as it was pasted, his own measured again from
    /// the squads today (`OpponentAdvisor.carry`), the strength from the two and, as after a paste, the importance
    /// suggested with that strength. Called when the draft's opponent or competition changes.
    ///
    /// A pasted reading on the draft is never replaced. A carried one is replaced when the opponent becomes another
    /// club with a reading, and taken away when it becomes one with none or the match stops being a league match,
    /// with the strength it set (not one picked by hand since); the importance is left as it is. A fixture being
    /// edited is left alone. When the owner's side cannot be measured, the engine's sentence is shown where a paste's
    /// refusal is.
    public func carryEarlierReading(into draft: inout FixtureDraft) {
        guard draft.isNew else { return }
        let carried = draft.opponentReading.flatMap { $0.ownDay == nil ? nil : $0 }
        guard draft.opponentReading == nil || carried != nil else { return }
        guard draft.competition == .league, let earlier = latestOpponentReading(for: draft.opponent) else {
            if let carried {
                draft.opponentReading = nil
                if draft.opponentStrength == carried.strength { draft.opponentStrength = nil }
            }
            return
        }
        if let carried, carried.club == earlier.club, carried.day == earlier.day,
           carried.theirTotal == earlier.theirTotal { return }
        do {
            let reading = try OpponentAdvisor.carry(earlier, own: squad.book.allPlayers, ownClub: ownClub,
                                                    on: settings.currentDate, parameters: planParameters)
            draft.opponentStrength = reading.strength
            draft.opponentReading = reading
            draft.pasteProblem = nil
            if let suggestion = suggestion(for: draft) { draft.importance = suggestion.importance }
        } catch {
            if let carried {
                draft.opponentReading = nil
                if draft.opponentStrength == carried.strength { draft.opponentStrength = nil }
            }
            draft.pasteProblem = ErrorDescriptions.describe(error)
        }
    }

    /// The latest squad reading on a saved fixture against `opponent` (by `PlayerID.normalise`, matching the fixture's
    /// opponent or the club the reading names): the latest paste, then the later fixture. Nil for a blank name.
    func latestOpponentReading(for opponent: String) -> OpponentReading? {
        let wanted = PlayerID.normalise(opponent)
        guard !wanted.isEmpty else { return nil }
        return fixtures
            .compactMap { fixture -> (fixture: StoredFixture, reading: OpponentReading)? in
                guard let reading = fixture.opponentReading,
                      PlayerID.normalise(fixture.opponent) == wanted || PlayerID.normalise(reading.club) == wanted
                else { return nil }
                return (fixture, reading)
            }
            .max { ($0.reading.day, $0.fixture.date) < ($1.reading.day, $1.fixture.date) }?
            .reading
    }
}
