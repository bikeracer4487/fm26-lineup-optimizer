import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

@Suite struct FixtureWordsTests {
    @Test func eachImportanceAndIntensityHasItsName() {
        #expect(Importance.allCases.map(\.displayName) == ["High", "Medium", "Low", "Sharpness"])
        #expect(TrainingIntensity.allCases.map(\.displayName) == ["Low", "Medium", "High"])
    }

    @Test func eachStateHasItsWords() {
        #expect(FixtureState.toPlay.text == "to play")
        #expect(FixtureState.confirmed.text == "confirmed")
        #expect(FixtureState.pastNotConfirmed.text == "past and not confirmed")
    }
}

@MainActor @Suite struct FixturePresentationTests {
    private func day(_ iso: String) -> Day { Day(iso: iso)! }

    private func record(for id: FixtureID, on date: Day) -> ConfirmedRecord {
        ConfirmedRecord(lineup: ConfirmedLineup(fixture: id, date: date, starters: [:]), names: [:], tacticName: "4-2-3-1")
    }

    private func setToday(_ iso: String, in model: AppModel) {
        var settings = model.settings
        settings.currentDate = day(iso)
        model.update(settings)
    }

    // MARK: State

    @Test func aFixtureFromTodayOnIsToPlay() throws {
        let t = try TestModel()
        let today = t.model.addFixture(date: day("2026-11-13"), opponent: "A", importance: .low)
        let later = t.model.addFixture(date: day("2026-11-14"), opponent: "B", importance: .low)
        for id in [today, later] {
            #expect(t.model.state(of: try #require(t.model.fixtures.first { $0.id == id })) == .toPlay)
        }
    }

    @Test func anUnconfirmedFixtureBeforeTodayIsPastAndNotConfirmed() throws {
        let t = try TestModel()
        let id = t.model.addFixture(date: day("2026-11-14"), opponent: "A", importance: .low)
        let fixture = try #require(t.model.fixtures.first { $0.id == id })
        setToday("2026-11-14", in: t.model)
        #expect(t.model.state(of: fixture) == .toPlay)
        setToday("2026-11-15", in: t.model)
        #expect(t.model.state(of: fixture) == .pastNotConfirmed)
    }

    @Test func aFixtureWithARecordIsConfirmedWhateverItsDate() throws {
        let t = try TestModel()
        let past = t.model.addFixture(date: day("2026-11-10"), opponent: "A", importance: .low)
        let coming = t.model.addFixture(date: day("2026-11-20"), opponent: "B", importance: .low)
        t.model.history = [record(for: past, on: day("2026-11-10")), record(for: coming, on: day("2026-11-20"))]
        for id in [past, coming] {
            let fixture = try #require(t.model.fixtures.first { $0.id == id })
            #expect(t.model.state(of: fixture) == .confirmed)
            #expect(t.model.asksBeforeDeleting(fixture))
        }
    }

    @Test func anUnconfirmedFixtureIsDeletedWithoutAsking() throws {
        let t = try TestModel()
        let id = t.model.addFixture(date: day("2026-11-10"), opponent: "A", importance: .low)
        t.model.history = [record(for: FixtureID("another"), on: day("2026-11-10"))]
        #expect(!t.model.asksBeforeDeleting(try #require(t.model.fixtures.first { $0.id == id })))
    }

    // MARK: Tactic

    @Test func aFixtureWithoutItsOwnTacticShowsThePrimary() throws {
        let t = try TestModel()
        let id = t.model.addFixture(date: day("2026-11-14"), opponent: "A", importance: .low)
        #expect(t.model.tacticText(for: try #require(t.model.fixtures.first)) == "No tactic yet")
        #expect(t.model.primaryTacticText == "No tactic yet")
        t.model.addTactic(named: "4-2-3-1")
        let cup = t.model.addTactic(named: "Cup 4-4-2")
        #expect(t.model.tacticText(for: try #require(t.model.fixtures.first)) == "Primary: 4-2-3-1")
        #expect(t.model.primaryTacticText == "Primary: 4-2-3-1")

        var fixture = try #require(t.model.fixtures.first { $0.id == id })
        fixture.tacticID = cup
        t.model.update(fixture)
        #expect(t.model.tacticText(for: fixture) == "Cup 4-4-2")
    }

    // MARK: Editing

    @Test func aNewFixtureStartsTheDayAfterTheLastOneStillToCome() throws {
        let t = try TestModel()
        #expect(t.model.newFixtureDraft() == FixtureDraft(date: day("2026-11-13")))
        t.model.addFixture(date: day("2026-11-10"), opponent: "Past", importance: .low)
        #expect(t.model.newFixtureDraft().date == day("2026-11-13"))
        t.model.addFixture(date: day("2026-11-21"), opponent: "C", importance: .low)
        t.model.addFixture(date: day("2026-11-17"), opponent: "B", importance: .low)
        let draft = t.model.newFixtureDraft()
        #expect(draft.date == day("2026-11-22"))
        #expect(draft.isNew && draft.opponent.isEmpty && draft.importance == .medium && draft.tacticID == nil)
        #expect(draft.saveButtonTitle == "Add fixture")
    }

    @Test func aFixtureNeedsAnOpponent() {
        var draft = FixtureDraft(date: day("2026-11-14"))
        #expect(draft.problem == "Say who the match is against.")
        draft.opponent = "   "
        #expect(draft.problem == "Say who the match is against.")
        draft.opponent = "Rovers"
        #expect(draft.problem == nil)
    }

    @Test func theProblemShowsOnlyOnceTheOwnerHasTriedToSave() {
        var draft = FixtureDraft(date: day("2026-11-14"))
        #expect(draft.problem != nil)
        #expect(draft.shownProblem == nil)
        draft.noteSaveAttempt()
        #expect(draft.shownProblem == "Say who the match is against.")
        draft.opponent = "Rovers"
        #expect(draft.shownProblem == nil)
    }

    @Test func theProblemShowsOnceTheOpponentIsTypedAndCleared() {
        var draft = FixtureDraft(date: day("2026-11-14"))
        draft.opponent = "R"
        #expect(draft.shownProblem == nil)
        draft.opponent = " "
        #expect(draft.shownProblem == "Say who the match is against.")
    }

    @Test func aDraftWithAProblemIsNotSaved() throws {
        let t = try TestModel()
        #expect(t.model.save(FixtureDraft(date: day("2026-11-14"))) == nil)
        #expect(t.model.fixtures.isEmpty)
        #expect(t.reopened().fixtures.isEmpty)
    }

    @Test func savingANewDraftAddsTheFixtureInDateOrder() throws {
        let t = try TestModel()
        let cup = t.model.addTactic(named: "Cup 4-4-2")
        let later = t.model.addFixture(date: day("2026-11-21"), opponent: "C", importance: .low)
        var draft = FixtureDraft(date: day("2026-11-14"))
        draft.opponent = "  Rovers "
        draft.importance = .high
        draft.tacticID = cup
        let id = try #require(t.model.save(draft))
        #expect(t.model.fixtures.map(\.id) == [id, later])
        let saved = t.model.fixtures[0]
        #expect(saved.opponent == "Rovers" && saved.importance == .high && saved.tacticID == cup && saved.date == day("2026-11-14"))
        #expect(t.reopened().fixtures == t.model.fixtures)
    }

    @Test func aSecondMatchOnOneDayIsRefusedAtOnce() throws {
        let t = try TestModel()
        let first = t.model.addFixture(date: day("2026-11-14"), opponent: "A", importance: .low)
        var draft = t.model.newFixtureDraft()
        draft.date = day("2026-11-14")
        // Shown before any attempt to save, and after a blank opponent once that is due.
        #expect(draft.shownProblem == "There is already a match on that day, against A.")
        #expect(draft.problem == "Say who the match is against.")
        draft.opponent = "B"
        #expect(draft.problem == "There is already a match on that day, against A.")
        #expect(t.model.save(draft) == nil)
        #expect(t.model.fixtures.count == 1)
        draft.date = day("2026-11-15")
        #expect(draft.problem == nil)
        #expect(t.model.save(draft) != nil)

        // The fixture being edited does not count against itself; a confirmed match counts like any other.
        var edited = t.model.fixtureDraft(for: try #require(t.model.fixtures.first { $0.id == first }))
        #expect(edited.problem == nil)
        edited.date = day("2026-11-15")
        #expect(edited.problem == "There is already a match on that day, against B.")
        t.model.history.append(ConfirmedRecord(
            lineup: ConfirmedLineup(fixture: first, date: day("2026-11-14"), starters: [:]), names: [:], tacticName: "T"))
        var another = t.model.newFixtureDraft()
        another.date = day("2026-11-14")
        another.opponent = "C"
        #expect(another.problem == "There is already a match on that day, against A.")
    }

    @Test func savingChecksTheDayAgainstTheFixturesSavedNow() throws {
        let t = try TestModel()
        var draft = FixtureDraft(date: day("2026-11-14"))
        draft.opponent = "B"
        t.model.addFixture(date: day("2026-11-14"), opponent: "A", importance: .low)
        #expect(draft.problem == nil)   // made before A was added
        #expect(t.model.save(draft) == nil)
        #expect(t.model.fixtures.count == 1)
    }

    @Test func savingAnEditedDraftKeepsTheFixturesChoicesOfPlayers() throws {
        let t = try TestModel()
        let id = t.model.addFixture(date: day("2026-11-14"), opponent: "A", importance: .low)
        let other = t.model.addFixture(date: day("2026-11-17"), opponent: "B", importance: .low)
        var fixture = try #require(t.model.fixtures.first { $0.id == id })
        fixture.overrides = [.GK: PlayerID(key: "jonny maxted")]
        fixture.rejected = [PlayerID(key: "alfie potter")]
        t.model.update(fixture)

        var draft = t.model.fixtureDraft(for: fixture)
        #expect(!draft.isNew && draft.saveButtonTitle == "Save changes")
        draft.date = day("2026-11-20")
        draft.opponent = "Rovers"
        draft.importance = .sharpness
        #expect(t.model.save(draft) == id)
        let saved = try #require(t.model.fixtures.first { $0.id == id })
        #expect(saved.opponent == "Rovers" && saved.importance == .sharpness && saved.date == day("2026-11-20"))
        #expect(saved.overrides == fixture.overrides && saved.rejected == fixture.rejected)
        #expect(t.model.fixtures.map(\.id) == [other, id])
    }

    @Test func savingADraftForADeletedFixtureDoesNothing() throws {
        let t = try TestModel()
        let id = t.model.addFixture(date: day("2026-11-14"), opponent: "A", importance: .low)
        var draft = FixtureDraft(try #require(t.model.fixtures.first))
        t.model.deleteFixture(id)
        draft.opponent = "B"
        #expect(t.model.save(draft) == nil)
        #expect(t.model.fixtures.isEmpty)
    }

    // MARK: A confirmed fixture

    /// A model with two fixtures, the first confirmed with a record whose starters and tactic name are set.
    private func confirmedModel() throws -> (TestModel, confirmed: FixtureID, other: FixtureID, record: ConfirmedRecord) {
        let t = try TestModel()
        let confirmed = t.model.addFixture(date: day("2026-11-14"), opponent: "A", importance: .low)
        let other = t.model.addFixture(date: day("2026-11-17"), opponent: "B", importance: .low)
        let record = ConfirmedRecord(
            lineup: ConfirmedLineup(fixture: confirmed, date: day("2026-11-14"), starters: [.GK: PlayerID(key: "jonny maxted")]),
            names: [PlayerID(key: "jonny maxted"): "Jonny Maxted"], tacticName: "4-2-3-1")
        t.model.history = [record]
        t.model.save(.history)
        return (t, confirmed, other, record)
    }

    @Test func aConfirmedFixturesNewDateMovesItsLineup() throws {
        let (t, confirmed, _, record) = try confirmedModel()
        var fixture = try #require(t.model.fixtures.first { $0.id == confirmed })
        fixture.date = day("2026-11-15")
        t.model.update(fixture)
        var expected = record
        expected.lineup.date = day("2026-11-15")
        #expect(t.model.history == [expected])
        #expect(t.reopened().history == [expected])
    }

    @Test func aConfirmedFixturesOtherChangesLeaveItsLineupAsConfirmed() throws {
        let (t, confirmed, _, record) = try confirmedModel()
        let cup = t.model.addTactic(named: "Cup 4-4-2")
        var draft = FixtureDraft(try #require(t.model.fixtures.first { $0.id == confirmed }))
        draft.opponent = "Rovers"
        draft.importance = .high
        draft.tacticID = cup
        #expect(t.model.save(draft) == confirmed)
        #expect(t.model.history == [record])
        #expect(t.reopened().history == [record])
    }

    @Test func movingAnUnconfirmedFixtureTouchesNoLineup() throws {
        let (t, _, other, record) = try confirmedModel()
        var fixture = try #require(t.model.fixtures.first { $0.id == other })
        fixture.date = day("2026-11-20")
        t.model.update(fixture)
        #expect(t.model.history == [record])
    }

    @Test func theEditorSaysWhenALineupIsConfirmed() throws {
        let (t, confirmed, other, _) = try confirmedModel()
        let note = "A lineup is confirmed for this match. A new date moves it too; to pick the eleven again, "
            + "unlock it in Match Selection."
        #expect(t.model.confirmedNote(for: FixtureDraft(try #require(t.model.fixtures.first { $0.id == confirmed }))) == note)
        #expect(t.model.confirmedNote(for: FixtureDraft(try #require(t.model.fixtures.first { $0.id == other }))) == nil)
        #expect(t.model.confirmedNote(for: t.model.newFixtureDraft()) == nil)
    }

    // MARK: Sample

    @Test func theSampleWithPastFixturesHasOneConfirmedAndOneNot() throws {
        let model = try SampleData.modelWithPastFixtures(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        #expect(model.notices.isEmpty)
        #expect(model.settings.currentDate == day("2026-11-18"))
        #expect(model.fixtures.map(model.state(of:)) == [.confirmed, .pastNotConfirmed, .toPlay, .toPlay, .toPlay])
    }

    // MARK: Today

    @Test func todayMovesByADayAndIsSaved() throws {
        let t = try TestModel()
        t.model.moveToday(by: 1)
        #expect(t.model.settings.currentDate == day("2026-11-14"))
        t.model.moveToday(by: -2)
        #expect(t.model.settings.currentDate == day("2026-11-12"))
        #expect(t.reopened().settings.currentDate == day("2026-11-12"))
    }
}
