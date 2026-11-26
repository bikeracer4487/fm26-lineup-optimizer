import Foundation
import Testing
@testable import LineupEngine
@testable import LineupAppCore

/// A new league fixture against a club with a saved squad reading takes that reading, with the owner's side measured
/// again: the owner's request of 25 November 2026.
@MainActor @Suite struct CarriedReadingTests {
    /// The sample model with its second fixture saved with the reading a paste gave, and that reading.
    private func savedReading() throws -> (model: AppModel, fixture: StoredFixture, reading: OpponentReading) {
        let (model, pasted) = try SampleData.draftWithOpponentReading(repositoryRoot: Captures.repositoryRoot)
        let id = try #require(model.save(pasted))
        let fixture = try #require(model.fixtures.first { $0.id == id })
        return (model, fixture, try #require(fixture.opponentReading))
    }

    /// A new draft with `competition` and then `opponent` set, the model asked after each change as the editor does.
    private func newDraft(_ model: AppModel, competition: Competition?, opponent: String) -> FixtureDraft {
        var draft = model.newFixtureDraft()
        draft.competition = competition
        model.carryEarlierReading(into: &draft)
        draft.opponent = opponent
        model.carryEarlierReading(into: &draft)
        return draft
    }

    private func remove(_ model: AppModel) { try? FileManager.default.removeItem(at: model.store.directory) }

    @Test func aNewLeagueFixtureTakesTheReadingWithTheOwnersSideMeasuredToday() throws {
        let (model, fixture, saved) = try savedReading()
        defer { remove(model) }
        let draft = newDraft(model, competition: .league, opponent: fixture.opponent)
        let expected = try OpponentAdvisor.carry(saved, own: model.squad.book.allPlayers, ownClub: model.ownClub,
                                                 on: model.settings.currentDate, parameters: model.planParameters)
        #expect(draft.opponentReading == expected)
        #expect(expected.ownDay == model.settings.currentDate)
        #expect(expected.day == saved.day)
        #expect(expected.theirTotal == saved.theirTotal)
        #expect(draft.opponentStrength == expected.strength)
        #expect(draft.pasteProblem == nil)
        // As after a paste, the importance is the one suggested with that strength.
        #expect(draft.importance == model.suggestion(for: draft)?.importance)
        #expect(draft.opponentReadingText?.contains(", against yours ") == true)
        #expect(draft.opponentReadingText?.hasSuffix("Paste their squad again if it has changed.") == true)
    }

    @Test func theNameMatchesAsTheTableDoes() throws {
        let (model, fixture, _) = try savedReading()
        defer { remove(model) }
        let draft = newDraft(model, competition: .league, opponent: "  " + fixture.opponent.uppercased() + " ")
        #expect(draft.opponentReading?.ownDay != nil)
    }

    @Test func onlyALeagueMatchTakesIt() throws {
        let (model, fixture, saved) = try savedReading()
        defer { remove(model) }
        for competition in [nil, Competition.cup, .minorCup, .friendly] {
            let draft = newDraft(model, competition: competition, opponent: fixture.opponent)
            #expect(draft.opponentReading == nil, "\(String(describing: competition))")
            #expect(draft.opponentStrength == nil)
        }
        // Made a league match afterwards, it takes it; made a cup match again, the reading and its strength go.
        var draft = newDraft(model, competition: .cup, opponent: fixture.opponent)
        draft.competition = .league
        model.carryEarlierReading(into: &draft)
        #expect(draft.opponentReading?.theirTotal == saved.theirTotal)
        let importance = draft.importance
        draft.competition = .cup
        model.carryEarlierReading(into: &draft)
        #expect(draft.opponentReading == nil)
        #expect(draft.opponentStrength == nil)
        #expect(draft.importance == importance)
    }

    @Test func aClubWithNoReadingTakesNothingAndTakesTheCarriedOneAway() throws {
        let (model, fixture, _) = try savedReading()
        defer { remove(model) }
        let other = try #require(model.fixtures.first { $0.id != fixture.id && $0.opponentReading == nil })
        #expect(newDraft(model, competition: .league, opponent: other.opponent).opponentReading == nil)
        #expect(newDraft(model, competition: .league, opponent: "Nobody Town").opponentReading == nil)

        var draft = newDraft(model, competition: .league, opponent: fixture.opponent)
        #expect(draft.opponentReading != nil)
        draft.opponent = "Nobody Town"
        model.carryEarlierReading(into: &draft)
        #expect(draft.opponentReading == nil)
        #expect(draft.opponentStrength == nil)
    }

    @Test func aStrengthPickedByHandAfterwardsStaysWhenTheReadingGoes() throws {
        let (model, fixture, _) = try savedReading()
        defer { remove(model) }
        var draft = newDraft(model, competition: .league, opponent: fixture.opponent)
        let carried = try #require(draft.opponentStrength)
        let byHand = try #require(OpponentStrength.allCases.first { $0 != carried })
        draft.opponentStrength = byHand
        draft.opponent = "Nobody Town"
        model.carryEarlierReading(into: &draft)
        #expect(draft.opponentReading == nil)
        #expect(draft.opponentStrength == byHand)
    }

    @Test func theOwnerCanStillChooseAnotherImportanceAndPasteAgain() throws {
        let (model, fixture, _) = try savedReading()
        defer { remove(model) }
        var draft = newDraft(model, competition: .league, opponent: fixture.opponent)
        let other = try #require(Importance.allCases.first { $0 != draft.importance })
        draft.importance = other
        // Asked again with the same club (a change of competition back to the league, say), the choice stands.
        model.carryEarlierReading(into: &draft)
        #expect(draft.importance == other)
        let id = try #require(model.save(draft))
        let stored = try #require(model.fixtures.first { $0.id == id })
        #expect(stored.importance == other)
        #expect(stored.opponentReading == draft.opponentReading)
        #expect(stored.opponentReading?.ownDay != nil)
    }

    @Test func aPastedReadingIsNeverReplaced() throws {
        let (model, fixture, _) = try savedReading()
        defer { remove(model) }
        // A paste on a new draft, then the opponent typed: the paste stands.
        let (pastedModel, pastedDraft) = try SampleData.draftWithOpponentReading(repositoryRoot: Captures.repositoryRoot)
        defer { remove(pastedModel) }
        var draft = model.newFixtureDraft()
        draft.opponentReading = pastedDraft.opponentReading
        draft.opponentStrength = pastedDraft.opponentStrength
        draft.competition = .league
        draft.opponent = fixture.opponent
        model.carryEarlierReading(into: &draft)
        #expect(draft.opponentReading == pastedDraft.opponentReading)
        #expect(draft.opponentReading?.ownDay == nil)
    }

    @Test func aFixtureBeingEditedIsLeftAlone() throws {
        let (model, fixture, _) = try savedReading()
        defer { remove(model) }
        let other = try #require(model.fixtures.first { $0.id != fixture.id && $0.opponentReading == nil })
        var draft = model.fixtureDraft(for: other)
        draft.competition = .league
        draft.opponent = fixture.opponent
        model.carryEarlierReading(into: &draft)
        #expect(draft.opponentReading == nil)
    }

    @Test func theLatestReadingIsTaken() throws {
        let (model, fixture, saved) = try savedReading()
        defer { remove(model) }
        let other = try #require(model.fixtures.first { $0.id != fixture.id })
        let later = OpponentReading(club: saved.club, day: saved.day.adding(days: 2), theirTotal: saved.theirTotal + 55,
                                    ownTotal: saved.ownTotal, strength: .stronger, awayOnLoanAt: [])
        let earlier = OpponentReading(club: saved.club, day: saved.day.adding(days: -2), theirTotal: saved.theirTotal - 55,
                                      ownTotal: saved.ownTotal, strength: .weaker, awayOnLoanAt: [])
        var updated = other
        updated.opponent = "Renamed Opponent"  // matched by the club the reading names
        updated.opponentReading = later
        model.update(updated)
        var oldest = try #require(model.fixtures.first { $0.id != fixture.id && $0.id != other.id })
        oldest.opponentReading = earlier
        model.update(oldest)
        let draft = newDraft(model, competition: .league, opponent: fixture.opponent)
        #expect(draft.opponentReading?.theirTotal == later.theirTotal)
        #expect(draft.opponentReading?.day == later.day)
    }

    @Test func withNoOwnSquadTheEnginesSentenceIsShown() throws {
        let t = try TestModel()
        let id = t.model.addFixture(date: TestModel.today.adding(days: 3), opponent: "Banbury United", importance: .medium)
        var stored = try #require(t.model.fixtures.first { $0.id == id })
        stored.opponentReading = OpponentReading(club: "Banbury United", day: TestModel.today, theirTotal: 816,
                                                 ownTotal: 754, strength: .stronger, awayOnLoanAt: [])
        t.model.update(stored)
        var draft = t.model.newFixtureDraft()
        draft.competition = .league
        draft.opponent = "Banbury United"
        t.model.carryEarlierReading(into: &draft)
        #expect(draft.opponentReading == nil)
        #expect(draft.opponentStrength == nil)
        #expect(draft.pasteProblem == ErrorDescriptions.describe(OpponentReadingError.noOwnSquad))
    }

    @Test func theSampleDraftForThePicturesCarriesAReading() throws {
        let (model, draft) = try SampleData.draftWithCarriedReading(repositoryRoot: Captures.repositoryRoot)
        defer { remove(model) }
        #expect(draft.isNew)
        #expect(draft.opponentReading?.ownDay == model.settings.currentDate)
    }
}
