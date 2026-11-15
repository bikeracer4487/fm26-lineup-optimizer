import Foundation
import Synchronization
import Testing
@testable import LineupEngine
@testable import LineupAppCore

@Suite struct FixtureWordsTests {
    @Test func eachImportanceAndIntensityHasItsName() {
        #expect(Importance.allCases.map(\.displayName) == ["High", "Medium", "Low", "Sharpness"])
        #expect(TrainingIntensity.allCases.map(\.displayName) == ["Low", "Medium", "High"])
    }

    @Test func eachStateHasItsWords() {
        #expect(FixtureState.toPlay.text == "To play")
        #expect(FixtureState.confirmed.text == "Confirmed")
        #expect(FixtureState.pastNotConfirmed.text == "Past and not confirmed")
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

    // MARK: Competition and opponent

    @Test func theCompetitionAndOpponentMenusStartWithNotSetThenTheEnginesNames() {
        #expect(FixtureDraft.competitionChoices.map(\.value) == [nil] + Competition.allCases.map(Optional.some))
        #expect(FixtureDraft.competitionChoices.map(\.title) == ["Not set", "League", "Cup", "Minor cup", "Friendly"])
        #expect(FixtureDraft.competitionChoices.dropFirst().map(\.title) == Competition.allCases.map { AdvisorText.name($0) })
        #expect(FixtureDraft.opponentChoices.map(\.value) == [nil] + OpponentStrength.allCases.map(Optional.some))
        #expect(FixtureDraft.opponentChoices.map(\.title)
                == ["Not set", "Much stronger", "Stronger", "Similar", "Weaker", "Much weaker"])
        #expect(FixtureDraft.opponentChoices.dropFirst().map(\.title) == OpponentStrength.allCases.map { AdvisorText.name($0) })
    }

    @Test func theImportanceIsNamedAsTheEngineNamesIt() {
        #expect(Importance.allCases.map(\.displayName) == Importance.allCases.map { AdvisorText.name($0) })
    }

    // MARK: The suggestion for a draft

    /// The engine's suggestion for `fixture` among `among`, with the planner's tiers for the primary tactic.
    private func engineSuggestion(_ model: AppModel, for fixture: Fixture, among: [StoredFixture]) throws
        -> ImportanceSuggestion {
        let tactic = try #require(model.primaryTactic).tactic
        let tiers = try SquadTiers.compute(tactic: tactic, players: model.squad.book.allPlayers, ownClub: model.ownClub,
                                           catalog: model.catalog, profile: model.profile, parameters: model.planParameters)
        return try ImportanceAdvisor.suggest(
            for: fixture, among: among.compactMap(model.fixtureForPlanner), confirmed: model.history.map(\.lineup),
            players: model.squad.book.allPlayers, tiers: tiers, situation: .inContention, parameters: model.planParameters)
    }

    /// The draft as the engine sees it, on the primary tactic.
    private func engineFixture(_ model: AppModel, _ draft: FixtureDraft, id: FixtureID) throws -> Fixture {
        Fixture(id: id, date: draft.date, opponent: draft.opponent, importance: draft.importance,
                tactic: try #require(model.primaryTactic).tactic, competition: draft.competition,
                opponentStrength: draft.opponentStrength)
    }

    private func sample() throws -> AppModel {
        try SampleData.model(repositoryRoot: Captures.repositoryRoot)
    }

    @Test func theSuggestionForAFixtureBeingEditedIsTheEnginesAmongTheOtherFixtures() throws {
        let model = try sample()
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let saved = model.fixtures[2]
        let others = model.fixtures.filter { $0.id != saved.id }
        let draft = model.fixtureDraft(for: saved)
        let expected = try engineSuggestion(model, for: try engineFixture(model, draft, id: saved.id), among: others)
        #expect(model.suggestion(for: draft) == expected)
        // Unedited, it is the saved fixture's own suggestion.
        #expect(model.suggestion(for: draft) == model.suggestions[saved.id])
    }

    @Test func editingTheCompetitionTheOpponentAndTheDateEachChangeTheSuggestionAsTheEngineSays() throws {
        let model = try sample()
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let saved = model.fixtures[1]
        let others = model.fixtures.filter { $0.id != saved.id }
        var draft = model.fixtureDraft(for: saved)
        let before = try #require(model.suggestion(for: draft))
        func check(_ what: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> ImportanceSuggestion {
            let found = try #require(model.suggestion(for: draft), sourceLocation: sourceLocation)
            #expect(found == (try engineSuggestion(model, for: try engineFixture(model, draft, id: saved.id), among: others)),
                    "\(what)", sourceLocation: sourceLocation)
            return found
        }

        draft.competition = .friendly
        let friendly = try check("competition")
        #expect(friendly != before)
        draft.opponentStrength = .muchStronger
        let stronger = try check("opponent")
        #expect(stronger != friendly)
        draft.date = Day(iso: "2026-11-19")!
        let moved = try check("date")
        #expect(moved != stronger)
        // Nothing saved: the saved fixture's suggestion is as it was.
        #expect(model.suggestions[saved.id] == before)
    }

    @Test func aDraftsSuggestionLeavesAConfirmedFixtureOutOfThoseStillToPlay() throws {
        let model = try SampleData.modelAfterConfirmingFirst(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let first = try #require(model.fixtures.first)
        #expect(model.state(of: first) == .confirmed)
        let saved = model.fixtures[1]
        // The confirmed match moved to the day after the draft's and made a high-importance cup match: counted among
        // those still to play, it would be the bigger match that follows a day later.
        var moved = model.fixtureDraft(for: first)
        moved.date = saved.date.adding(days: 1)
        moved.importance = .high
        moved.competition = .cup
        try #require(model.save(moved) == first.id)
        let confirmed = try #require(model.fixtures.first { $0.id == first.id })
        #expect(model.state(of: confirmed) == .confirmed)
        #expect(confirmed.date > saved.date)
        var draft = model.fixtureDraft(for: saved)
        draft.competition = .cup
        let toPlay = model.fixtures.filter { $0.id != confirmed.id && $0.id != saved.id }
        let expected = try engineSuggestion(model, for: try engineFixture(model, draft, id: saved.id), among: toPlay)
        let wronglyIncluded = try engineSuggestion(model, for: try engineFixture(model, draft, id: saved.id),
                                                   among: toPlay + [confirmed])
        #expect(expected != wronglyIncluded)
        #expect(model.suggestion(for: draft) == expected)
        #expect(model.history.map(\.lineup).contains { $0.fixture == confirmed.id })
    }

    @Test func aDraftWithNothingSetIsSuggestedFromTheScheduleAlone() throws {
        let model = try sample()
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        var draft = model.newFixtureDraft()
        draft.opponent = "Opponent F"
        #expect(draft.competition == nil && draft.opponentStrength == nil)
        let found = try #require(model.suggestion(for: draft))
        #expect(found == (try engineSuggestion(model, for: try engineFixture(model, draft, id: FixtureID("any")),
                                               among: model.fixtures)))
        #expect(found.reasons.first?.hasPrefix("No competition set") == true)
    }

    @Test func aDraftOnAnotherTacticIsSuggestedWithThatTacticsTiers() throws {
        let model = try sample()
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let saved = model.fixtures[3]
        let id = model.addTactic(named: model.unusedTacticName("Wide"))
        var stored = try #require(model.tactics.first { $0.id == id })
        var tacticDraft = TacticDraft(stored.tactic)
        tacticDraft.setRole("Winger", at: .AM_L, in: .inPossession)
        stored.tactic = tacticDraft.tactic
        model.update(stored)
        #expect(model.problems(of: stored.tactic).isEmpty)
        #expect(stored.tactic != model.primaryTactic?.tactic)
        var draft = model.fixtureDraft(for: saved)
        draft.tacticID = id
        let tiers = try SquadTiers.compute(tactic: stored.tactic, players: model.squad.book.allPlayers,
                                           ownClub: model.ownClub, catalog: model.catalog, profile: model.profile,
                                           parameters: model.planParameters)
        var fixture = try engineFixture(model, draft, id: saved.id)
        fixture.tactic = stored.tactic
        let expected = try ImportanceAdvisor.suggest(
            for: fixture, among: model.fixtures.filter { $0.id != saved.id }.compactMap(model.fixtureForPlanner),
            confirmed: model.history.map(\.lineup), players: model.squad.book.allPlayers, tiers: tiers,
            situation: .inContention, parameters: model.planParameters)
        #expect(model.suggestion(for: draft) == expected)
    }

    @Test func aDraftHasNoSuggestionWithoutAdviceOrAUsableTacticOrForAConfirmedMatch() throws {
        // No squad: the advice is not ready.
        let t = try TestModel()
        var empty = t.model.newFixtureDraft()
        empty.opponent = "A"
        #expect(t.model.suggestion(for: empty) == nil)
        #expect(t.model.suggestionNote(for: empty) == nil)

        // A tactic the engine refuses.
        let model = try sample()
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let refused = model.addTactic(named: model.unusedTacticName("Broken"))
        var stored = try #require(model.tactics.first { $0.id == refused })
        var tacticDraft = TacticDraft(stored.tactic)
        tacticDraft.toggle(.ST_C, in: .inPossession, catalog: model.catalog)
        stored.tactic = tacticDraft.tactic
        model.update(stored)
        var draft = model.fixtureDraft(for: model.fixtures[0])
        #expect(model.suggestion(for: draft) != nil)
        draft.tacticID = refused
        #expect(model.suggestion(for: draft) == nil)

        // A match already confirmed is played: nothing to suggest.
        let confirmedModel = try SampleData.modelAfterConfirmingFirst(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: confirmedModel.store.directory) }
        let first = try #require(confirmedModel.fixtures.first)
        #expect(confirmedModel.suggestion(for: confirmedModel.fixtureDraft(for: first)) == nil)
        #expect(confirmedModel.suggestionLine(for: first) == nil)
    }

    @Test func aPastFixtureWithNoConfirmedLineupShowsNoSuggestion() throws {
        // Five days on: the first fixture is confirmed and the second, on 17 November, is past and not confirmed.
        let model = try SampleData.modelWithPastFixtures(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let past = model.fixtures[1]
        #expect(model.state(of: past) == .pastNotConfirmed)
        // Made to differ from its suggestion, it would show one if it were still to play.
        var changed = past
        changed.importance = Importance.allCases.first { $0 != model.suggestions[past.id]?.importance } ?? .high
        model.update(changed)
        let differing = try #require(model.fixtures.first { $0.id == past.id })
        #expect(model.suggestionLine(for: differing) == nil)
        #expect(model.suggestion(for: model.fixtureDraft(for: differing)) == nil)
        #expect(model.suggestionNote(for: model.fixtureDraft(for: differing)) == nil)
        // Moved to a day still to play, it shows one again.
        var later = model.fixtureDraft(for: differing)
        later.date = Day(iso: "2026-11-19")!
        #expect(model.suggestion(for: later) != nil)
    }

    @Test func aMissedFixtureShowsNoSuggestion() throws {
        // A fixture on 12 November, the day before the squads were imported, never confirmed: missed in Match Selection.
        let model = try SampleData.modelWithMissedFixture(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let missed = try #require(model.fixtures.first { $0.opponent == "Opponent Z" })
        #expect(model.fixturePlans.first { $0.id == missed.id }?.body == .missed(nil))
        // Today in the game moved back before it, so the Fixtures screen alone would call it still to play.
        var settings = model.settings
        settings.currentDate = Day(iso: "2026-11-11")!
        model.update(settings)
        #expect(model.state(of: missed) == .toPlay)
        for importance in Importance.allCases {
            var changed = try #require(model.fixtures.first { $0.id == missed.id })
            changed.importance = importance
            model.update(changed)
            let shown = try #require(model.fixtures.first { $0.id == missed.id })
            #expect(model.suggestionLine(for: shown) == nil)
            #expect(model.suggestion(for: model.fixtureDraft(for: shown)) == nil)
        }
    }

    // MARK: The league situation

    private func leagueFixture(_ model: AppModel) throws -> StoredFixture {
        try #require(model.fixtures.first { $0.competition == .league && $0.opponentStrength == .weaker })
    }

    @Test func theSituationChangesALeagueFixturesSuggestion() throws {
        let model = try sample()
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let fixture = try leagueFixture(model)
        let before = try #require(model.suggestions[fixture.id])
        model.setLeagueSituation(.nothingToPlayFor)
        let after = try #require(model.suggestions[fixture.id])
        #expect(after.importance != before.importance)
        #expect([Importance.low, .sharpness].contains(after.importance))
        #expect(after.reasons.first == "League match, nothing to play for: 20")
        let expected = try engineSuggestion(model, for: try #require(model.fixtureForPlanner(fixture)),
                                            among: model.fixtures)
        #expect(after.importance != expected.importance || after.reasons.first != expected.reasons.first
                || expected.reasons.first == "League match, nothing to play for: 20")
    }

    @Test func theSituationDoesNotChangeACupFixturesSuggestion() throws {
        let model = try sample()
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let cup = try #require(model.fixtures.first { $0.competition == .cup })
        let before = try #require(model.suggestions[cup.id])
        model.setLeagueSituation(.nothingToPlayFor)
        #expect(model.suggestions[cup.id] == before)
    }

    @Test func changingTheSituationDoesNotPlanAgain() throws {
        let model = try sample()
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        _ = model.suggestions
        let planned = model.timesPlanned, advised = model.timesAdvised, plan = model.planState
        model.setLeagueSituation(.midTable)
        _ = model.suggestions
        #expect(model.timesPlanned == planned)
        #expect(model.timesAdvised == advised)
        #expect(model.planState == plan)
    }

    @Test func theSituationIsSavedAndReadBack() throws {
        let t = try TestModel()
        #expect(t.model.settings.situation == .inContention)
        t.model.setLeagueSituation(.midTable)
        #expect(t.reopened().settings.situation == .midTable)
    }

    @Test func theEditorsSuggestionFollowsTheSituation() throws {
        let model = try sample()
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let draft = model.fixtureDraft(for: try leagueFixture(model))
        let before = try #require(model.suggestionNote(for: draft))
        model.setLeagueSituation(.nothingToPlayFor)
        let after = try #require(model.suggestionNote(for: draft))
        #expect(after.reasons.first == "League match, nothing to play for: 20")
        #expect(after != before)
    }

    @Test func aViewReadingTheSuggestionsIsToldWhenTheSituationChanges() throws {
        let model = try sample()
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        for warm in [false, true] {
            if warm { _ = model.suggestions }   // the kept path as well as the first read
            let told = Mutex(false)
            withObservationTracking { _ = model.suggestions } onChange: { told.withLock { $0 = true } }
            model.setLeagueSituation(model.settings.situation == .midTable ? .inContention : .midTable)
            #expect(told.withLock { $0 })
        }
    }

    /// The settings file as the store writes it, with `leagueSituation` set to `value` (removed for nil).
    private func writeSettings(in t: TestModel, leagueSituation value: String?) throws {
        var settings = AppSettings(currentDate: TestModel.today)
        settings.leagueSituation = .midTable
        try Store(directory: t.directory).save(settings, to: .settings)
        let file = t.directory.appendingPathComponent("settings.json")
        // The store wraps what it saves with a version, so the settings are one level down.
        var wrapper = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any])
        let key = try #require(wrapper.first { $0.value is [String: Any] }?.key)
        var object = try #require(wrapper[key] as? [String: Any])
        #expect(object["leagueSituation"] as? String == "midTable")
        if let value { object["leagueSituation"] = value } else { object.removeValue(forKey: "leagueSituation") }
        wrapper[key] = object
        try JSONSerialization.data(withJSONObject: wrapper).write(to: file)
    }

    @Test func settingsFromBeforeThisPlanOpenAsInContention() throws {
        let t = try TestModel()
        try writeSettings(in: t, leagueSituation: nil)
        let reopened = t.reopened()
        #expect(reopened.settings.situation == .inContention)
        #expect(reopened.settings.leagueSituation == nil)
        #expect(reopened.notices.isEmpty)
    }

    @Test func aSettingsFileWithAnUnknownSituationIsKeptAsideWithANotice() throws {
        let t = try TestModel()
        try writeSettings(in: t, leagueSituation: "playOffPush")
        let reopened = t.reopened()
        #expect(reopened.notices.count == 1)
        #expect(reopened.settings.situation == .inContention)
        #expect(FileManager.default.fileExists(atPath: t.directory.appendingPathComponent("settings.unreadable-1.json").path))
    }

    @Test func theMenuListsTheFourSituationsInTheEnginesWords() {
        #expect(AppModel.leagueSituationChoices.map(\.value) == LeagueSituation.allCases)
        #expect(AppModel.leagueSituationChoices.map(\.title) == LeagueSituation.allCases.map { AdvisorText.name($0) })
        #expect(AppModel.leagueSituationChoices.count == 4)
        #expect(AppModel.leagueSituationLabel == "League situation")
    }

    @Test func aChangeToTheSituationThroughUpdateAlsoClearsTheKeptSuggestions() throws {
        let model = try sample()
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let fixture = try leagueFixture(model)
        let before = try #require(model.suggestions[fixture.id])
        var settings = model.settings
        settings.leagueSituation = .nothingToPlayFor
        model.update(settings)
        #expect(model.suggestions[fixture.id] != before)
        #expect(model.suggestions[fixture.id]?.reasons.first == "League match, nothing to play for: 20")
    }

    // MARK: How the suggestion is shown

    private func suggestion(_ importance: Importance, basis: Evidence = .derived) -> ImportanceSuggestion {
        ImportanceSuggestion(importance: importance, score: 7, reasons: ["League match: 6", "Score 7: High"], basis: basis)
    }

    @Test func theSuggestionSaysWhatItIsWithItsReasonsAndEvidenceNote() {
        let note = SuggestionNote(suggestion(.high), chosen: .medium)
        #expect(note.text == "Suggested: High")
        #expect(note.text == AdvisorText.suggested(suggestion(.high)))
        #expect(note.reasons == ["League match: 6", "Score 7: High"])
        #expect(note.noteText == "(this tool's estimate)")
        #expect(note.importance == .high)
        #expect(SuggestionNote(suggestion(.high, basis: .carriedOverFM26), chosen: .high).noteText == "(FM26-era numbers)")
        #expect(SuggestionNote(suggestion(.high, basis: .fm27Measured), chosen: .high).noteText == nil)
        #expect(SuggestionNote.useItTitle == "Use it")
        #expect(SuggestionNote.clickHelp(false) == "Show the reasons")
        #expect(SuggestionNote.clickHelp(true) == "Hide the reasons")
        #expect(FixtureDraft.competitionLabel == "Competition")
        #expect(FixtureDraft.opponentStrengthLabel == "Their strength")
    }

    @Test func useItShowsOnlyWhenTheSuggestionDiffersFromTheChoice() {
        #expect(SuggestionNote(suggestion(.high), chosen: .medium).showsUseIt)
        #expect(SuggestionNote(suggestion(.sharpness), chosen: .low).showsUseIt)
        #expect(!SuggestionNote(suggestion(.high), chosen: .high).showsUseIt)
    }

    @Test func usingTheSuggestionSetsTheDraftsImportanceAndNothingElse() throws {
        let model = try sample()
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let saved = model.fixtures[0]
        var draft = model.fixtureDraft(for: saved)
        draft.importance = Importance.allCases.first { $0 != model.suggestion(for: draft)?.importance } ?? .high
        let note = try #require(model.suggestionNote(for: draft))
        #expect(note.showsUseIt)
        var taken = draft
        taken.take(note)
        #expect(taken.importance == note.importance)
        var expected = draft
        expected.importance = note.importance
        #expect(taken == expected)
        #expect(model.suggestionNote(for: taken)?.showsUseIt == false)
        // Only the owner's save changes the fixture.
        #expect(model.fixtures.first { $0.id == saved.id }?.importance == saved.importance)
    }

    @Test func theTableShowsASuggestionOnlyWhereItDiffers() throws {
        let model = try sample()
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        #expect(model.suggestions.count == model.fixtures.count)
        for fixture in model.fixtures {
            let suggestion = try #require(model.suggestions[fixture.id])
            let line = model.suggestionLine(for: fixture)
            if suggestion.importance == fixture.importance {
                #expect(line == nil)
            } else {
                #expect(line == SuggestionNote(suggestion, chosen: fixture.importance))
            }
        }
        // The owner taking the suggestion makes the line go.
        let fixture = try #require(model.fixtures.first)
        var changed = fixture
        changed.importance = Importance.allCases.first { $0 != model.suggestions[fixture.id]?.importance } ?? .high
        model.update(changed)
        let differing = try #require(model.fixtures.first { $0.id == fixture.id })
        #expect(model.suggestionLine(for: differing)?.showsUseIt == true)
        var taken = model.fixtureDraft(for: differing)
        taken.take(try #require(model.suggestionLine(for: differing)))
        model.save(taken)
        #expect(model.suggestionLine(for: try #require(model.fixtures.first { $0.id == fixture.id })) == nil)
    }

    @Test func theSuggestionNeverChangesAnImportanceByItself() throws {
        let model = try sample()
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let before = model.fixtures.map(\.importance)
        _ = model.suggestions
        for fixture in model.fixtures { _ = model.suggestionLine(for: fixture) }
        _ = model.suggestion(for: model.fixtureDraft(for: model.fixtures[0]))
        #expect(model.fixtures.map(\.importance) == before)
    }

    @Test func theReasonsShownAreOneFixtureAtATimeAndKeptInTheNavigation() {
        let navigation = Navigation()
        let a = FixtureID("a"), b = FixtureID("b")
        #expect(navigation.fixtureReasons == nil)
        navigation.toggleReasons(of: a)
        #expect(navigation.showsReasons(of: a) && !navigation.showsReasons(of: b))
        navigation.toggleReasons(of: b)
        #expect(navigation.fixtureReasons == b)
        #expect(!navigation.showsReasons(of: a))
        navigation.screen = .squad
        navigation.screen = .fixtures
        #expect(navigation.showsReasons(of: b))
        navigation.toggleReasons(of: b)
        #expect(navigation.fixtureReasons == nil)
    }

    @Test func theSampleWithADifferingSuggestionShowsItOnTheSecondFixtureOnly() throws {
        let model = try SampleData.modelWithDifferingSuggestion(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let second = model.fixtures[1]
        #expect(second.importance == .high)
        #expect(model.suggestionLine(for: second)?.text == "Suggested: Medium")
        #expect(model.fixtures.filter { model.suggestionLine(for: $0) != nil }.map(\.id) == [second.id])
        #expect(second.competition != nil && second.opponentStrength != nil)
    }

    // MARK: Taking a suggestion from the table

    /// A copy of the sample on a scripted clock the test holds still.
    private func clockedSample() throws -> (model: AppModel, input: ScriptedInput, directory: URL) {
        let sampled = try sample()
        defer { try? FileManager.default.removeItem(at: sampled.store.directory) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("use-it-\(UUID().uuidString)")
        try FileManager.default.copyItem(at: sampled.store.directory, to: directory)
        let input = ScriptedInput(today: SampleData.date)
        input.tick = 0
        input.uptime = 1_000
        return (AppModel(store: Store(directory: directory), environment: input.environment), input, directory)
    }

    /// The first `count` fixtures still to play that have a suggestion, each made to differ from it.
    private func fixturesShowingALine(_ model: AppModel, count: Int) throws -> [StoredFixture] {
        let open = model.fixtures.filter { model.suggestions[$0.id] != nil && model.state(of: $0) == .toPlay && !model.isPast($0.date) }
        try #require(open.count >= count)
        for fixture in open.prefix(count) {
            var changed = fixture
            changed.importance = Importance.allCases.first { $0 != model.suggestions[fixture.id]?.importance }!
            model.update(changed)
        }
        let shown = model.fixtures.filter { model.suggestionLine(for: $0) != nil }
        try #require(shown.count >= count)
        return Array(shown.prefix(count))
    }

    @Test func useItTakesTheSuggestionAndPlansAgain() throws {
        let c = try clockedSample()
        defer { try? FileManager.default.removeItem(at: c.directory) }
        let fixture = try fixturesShowingALine(c.model, count: 1)[0]
        let line = try #require(c.model.suggestionLine(for: fixture))
        let planned = c.model.timesPlanned
        c.model.useSuggestion(for: fixture.id)
        let after = try #require(c.model.fixtures.first { $0.id == fixture.id })
        #expect(after.importance == line.importance)
        #expect(after.importance != fixture.importance)
        #expect(c.model.timesPlanned == planned + 1)
        #expect(c.model.suggestionLine(for: after) == nil)
        let reopened = AppModel(store: Store(directory: c.directory), environment: c.input.environment)
        #expect(reopened.fixtures.first { $0.id == fixture.id }?.importance == line.importance)
    }

    @Test func useItDoesNothingWhereNoLineIsShown() throws {
        // Confirmed.
        let confirmed = try SampleData.modelAfterConfirmingFirst(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: confirmed.store.directory) }
        let played = try #require(confirmed.fixtures.first)
        #expect(confirmed.state(of: played) == .confirmed)
        let beforeConfirmed = confirmed.fixtures
        let plannedConfirmed = confirmed.timesPlanned
        confirmed.useSuggestion(for: played.id)
        #expect(confirmed.fixtures == beforeConfirmed)
        #expect(confirmed.timesPlanned == plannedConfirmed)

        // Past and not confirmed, made to differ from its suggestion.
        let past = try SampleData.modelWithPastFixtures(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: past.store.directory) }
        var missed = past.fixtures[1]
        #expect(past.state(of: missed) == .pastNotConfirmed)
        missed.importance = Importance.allCases.first { $0 != past.suggestions[missed.id]?.importance }!
        past.update(missed)
        let beforePast = past.fixtures
        let plannedPast = past.timesPlanned
        past.useSuggestion(for: missed.id)
        #expect(past.fixtures == beforePast)
        #expect(past.timesPlanned == plannedPast)

        // Suggestion equal to the importance chosen, and an id no fixture has.
        let c = try clockedSample()
        defer { try? FileManager.default.removeItem(at: c.directory) }
        let same = try #require(c.model.fixtures.first { c.model.suggestionLine(for: $0) == nil
            && c.model.suggestions[$0.id] != nil && c.model.state(of: $0) == .toPlay })
        let before = c.model.fixtures
        let planned = c.model.timesPlanned
        c.model.useSuggestion(for: same.id)
        c.input.uptime += 10
        c.model.useSuggestion(for: FixtureID("no such fixture"))
        #expect(c.model.fixtures == before)
        #expect(c.model.timesPlanned == planned)
    }

    @Test func aSecondUseItWithinHalfASecondDoesNothing() throws {
        let c = try clockedSample()
        defer { try? FileManager.default.removeItem(at: c.directory) }
        let two = try fixturesShowingALine(c.model, count: 2)
        let lineOfSecond = try #require(c.model.suggestionLine(for: two[1]))
        c.model.useSuggestion(for: two[0].id)
        c.input.uptime += AppModel.suggestionActionInterval - 0.1
        c.model.useSuggestion(for: two[1].id)
        #expect(c.model.fixtures.first { $0.id == two[1].id }?.importance == two[1].importance)
        c.input.uptime += 0.1
        c.model.useSuggestion(for: two[1].id)
        #expect(c.model.fixtures.first { $0.id == two[1].id }?.importance == lineOfSecond.importance)
    }

    @Test func theSuggestionIntervalIsHalfASecondAndItsOwn() throws {
        #expect(AppModel.suggestionActionInterval == 0.5)
        let c = try clockedSample()
        defer { try? FileManager.default.removeItem(at: c.directory) }
        let two = try fixturesShowingALine(c.model, count: 2)
        // A training action just now does not hold up taking a suggestion.
        c.model.lastTrainingAction = c.input.uptime
        c.model.useSuggestion(for: two[0].id)
        #expect(c.model.fixtures.first { $0.id == two[0].id }?.importance != two[0].importance)
    }

    @Test func theTableOffersNoUseItForTheFixtureBeingEdited() throws {
        let c = try clockedSample()
        defer { try? FileManager.default.removeItem(at: c.directory) }
        let fixture = try fixturesShowingALine(c.model, count: 1)[0]
        #expect(!c.model.offersUseIt(for: fixture, editing: fixture.id))
        #expect(c.model.offersUseIt(for: fixture, editing: nil))
        #expect(c.model.offersUseIt(for: fixture, editing: FixtureID("another")))
        let plain = try #require(c.model.fixtures.first { c.model.suggestionLine(for: $0) == nil })
        #expect(!c.model.offersUseIt(for: plain, editing: nil))
        #expect(!c.model.offersUseIt(for: plain, editing: FixtureID("another")))
    }

    @Test func useItKeepsTheFixturesOtherChoices() throws {
        let c = try clockedSample()
        defer { try? FileManager.default.removeItem(at: c.directory) }
        let fixture = try fixturesShowingALine(c.model, count: 1)[0]
        let before = try #require(c.model.fixtures.first { $0.id == fixture.id })
        c.model.useSuggestion(for: fixture.id)
        var after = try #require(c.model.fixtures.first { $0.id == fixture.id })
        #expect(after.importance != before.importance)
        after.importance = before.importance
        after.lastPlanned = before.lastPlanned
        #expect(after == before)
    }

    @Test func theUseItLabelNamesTheMatch() {
        #expect(SuggestionNote.useItLabel(opponent: "Banbury United")
                == "Use the suggested importance for the match against Banbury United")
    }

    // MARK: Today

    @Test func todayMovesByADayAndIsSaved() throws {
        let t = try TestModel()
        t.model.moveToday(by: 1)
        #expect(t.model.settings.currentDate == day("2026-11-14"))
        t.model.moveToday(by: -2)
        #expect(t.model.settings.currentDate == day("2026-11-12"))
        #expect(t.reopened().settings.currentDate == day("2026-11-12"))
        #expect(t.model.todayInTheGameText == "Today in the game: Thursday 12 November 2026")
    }
}

// MARK: Pasting the opponent's squad

@MainActor @Suite struct OpponentPasteTests {
    private let today = TestModel.today

    /// A model with the owner's squad imported keyed by FMRTE's id, and the opponent's paste (the same men keyed by name)
    /// on the clipboard.
    private func ready(importOwn: Bool = true) throws -> TestModel {
        let t = try TestModel()
        if importOwn { try t.importFirstTeamWithID() }
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        try putTheirsOnTheClipboard(t)
        return t
    }

    private func putTheirsOnTheClipboard(_ t: TestModel) throws {
        t.input.clipboard = try Captures.firstTeam
        t.input.config = .data(try Captures.firstTeamGrids)
    }

    private func draft(_ t: TestModel, opponent: String = "Banbury United") -> FixtureDraft {
        var draft = t.model.newFixtureDraft()
        draft.opponent = opponent
        return draft
    }

    private func theirs() throws -> [Player] {
        try Importer.importPlayers(clipboard: try Captures.firstTeam, fmrteConfig: try Captures.firstTeamGrids,
                                   squad: .firstTeam).players
    }

    private func expectedReading(_ t: TestModel) throws -> OpponentReading {
        try OpponentAdvisor.read(theirs: try theirs(), named: "Banbury United", own: t.model.squad.book.allPlayers,
                                 ownClub: t.model.ownClub, on: today, parameters: t.model.planParameters)
    }

    private func fixturesBytes(_ t: TestModel) -> Data? {
        try? Data(contentsOf: t.directory.appendingPathComponent("fixtures.json"))
    }

    @Test func aPasteSetsTheStrengthAndTheReading() throws {
        let t = try ready()
        var draft = draft(t)
        t.model.pasteOpponentSquad(into: &draft)
        let expected = try expectedReading(t)
        #expect(draft.opponentReading == expected)
        #expect(expected.club == "Banbury United")
        #expect(expected.day == today)
        #expect(draft.opponentStrength == expected.strength)
        #expect(draft.pasteProblem == nil)
        #expect(draft.opponentReadingText == AdvisorText.opponentReading(expected, on: DayText.short(today)))
        #expect(FixtureDraft.pasteButtonTitle == "Paste their squad")
    }

    @Test func nothingIsSavedUntilTheFixtureIs() throws {
        let t = try ready()
        t.model.addFixture(date: today.adding(days: 3), opponent: "Elsewhere", importance: .low)
        var draft = draft(t)
        let bytes = fixturesBytes(t)
        let fixtures = t.model.fixtures
        let planned = t.model.timesPlanned, advised = t.model.timesAdvised
        t.model.pasteOpponentSquad(into: &draft)
        #expect(fixturesBytes(t) == bytes)
        #expect(t.model.fixtures == fixtures)
        #expect(t.model.timesPlanned == planned)
        #expect(t.model.timesAdvised == advised)

        let id = try #require(t.model.save(draft))
        let stored = try #require(t.model.fixtures.first { $0.id == id })
        #expect(stored.opponentStrength == draft.opponentStrength)
        #expect(stored.opponentReading == draft.opponentReading)
        #expect(stored.opponentReading != nil)
        let reopened = t.reopened().fixtures.first { $0.id == id }
        #expect(reopened?.opponentReading == draft.opponentReading)
        #expect(reopened?.opponentStrength == draft.opponentStrength)
    }

    @Test func aPasteLeavesTheSquadBookAsItWas() throws {
        let t = try ready()
        let squad = t.model.squad, marks = t.model.marks, mentoring = t.model.mentoring, training = t.model.training
        let squadFile = try Data(contentsOf: t.directory.appendingPathComponent("squad.json"))
        var draft = draft(t)
        t.model.pasteOpponentSquad(into: &draft)
        #expect(draft.opponentReading != nil)
        #expect(t.model.squad == squad)
        #expect(t.model.marks == marks)
        #expect(t.model.mentoring == mentoring)
        #expect(t.model.training == training)
        #expect(try Data(contentsOf: t.directory.appendingPathComponent("squad.json")) == squadFile)
    }

    @Test func pastingTheOwnSquadIsRefused() throws {
        let t = try ready()
        t.input.clipboard = try Captures.firstTeamWithID
        t.input.config = .data(try Captures.firstTeamWithIDGrids)
        var draft = draft(t)
        let before = draft
        t.model.pasteOpponentSquad(into: &draft)
        #expect(draft.pasteProblem == ErrorDescriptions.describe(OpponentReadingError.ownSquadPasted))
        var cleared = draft
        cleared.pasteProblem = nil
        #expect(cleared == before)
    }

    @Test func withABlankOpponentThePasteIsRefused() throws {
        let t = try ready()
        var draft = draft(t, opponent: "   ")
        t.model.pasteOpponentSquad(into: &draft)
        #expect(draft.pasteProblem == ErrorDescriptions.describe(OpponentReadingError.noClubName))
        #expect(draft.opponentReading == nil)
        #expect(draft.opponentStrength == nil)
    }

    @Test func withTooFewOwnPlayersThePasteIsRefused() throws {
        let t = try ready(importOwn: false)
        try t.importU21()
        try putTheirsOnTheClipboard(t)
        var draft = draft(t)
        t.model.pasteOpponentSquad(into: &draft)
        var expected: String?
        do { _ = try expectedReading(t) } catch { expected = ErrorDescriptions.describe(error) }
        #expect(expected != nil)
        #expect(draft.pasteProblem == expected)
        #expect(draft.pasteProblem?.isEmpty == false)
        #expect(draft.opponentReading == nil)
    }

    @Test func anEmptyClipboardIsRefused() throws {
        let t = try ready()
        t.input.clipboard = "  \n "
        var draft = draft(t)
        t.model.pasteOpponentSquad(into: &draft)
        #expect(draft.pasteProblem == "The clipboard is empty. Copy the rows in FMRTE first.")
        #expect(draft.opponentReading == nil)
        t.input.clipboard = nil
        t.model.pasteOpponentSquad(into: &draft)
        #expect(draft.pasteProblem == "The clipboard is empty. Copy the rows in FMRTE first.")
    }

    @Test func rowsTheImporterRefusesGiveItsSentence() throws {
        let t = try ready()
        t.input.clipboard = "Oxford City 2 Banbury United 1"
        var draft = draft(t)
        t.model.pasteOpponentSquad(into: &draft)
        var expected: String?
        do {
            _ = try Importer.importPlayers(clipboard: "Oxford City 2 Banbury United 1",
                                           fmrteConfig: try Captures.firstTeamGrids, squad: .firstTeam)
        } catch { expected = ErrorDescriptions.describe(error) }
        #expect(expected != nil)
        #expect(draft.pasteProblem == expected)
        #expect(draft.opponentReading == nil)
    }

    @Test func aSettingsFileThatCannotBeReadGivesItsSentence() throws {
        let t = try ready()
        t.input.config = .failure(CocoaError(.fileReadNoSuchFile))
        var draft = draft(t)
        t.model.pasteOpponentSquad(into: &draft)
        let problem = try #require(draft.pasteProblem)
        #expect(problem.hasPrefix("FMRTE's settings file was not found"))
        #expect(draft.opponentReading == nil)
    }

    @Test func withNoSquadImportedThePasteIsRefused() throws {
        let t = try ready(importOwn: false)
        var draft = draft(t)
        t.model.pasteOpponentSquad(into: &draft)
        #expect(draft.pasteProblem == ErrorDescriptions.describe(OpponentReadingError.noOwnSquad))
        #expect(draft.opponentReading == nil)
    }

    @Test func aRefusalKeepsAnEarlierReading() throws {
        let t = try ready()
        var draft = draft(t)
        t.model.pasteOpponentSquad(into: &draft)
        let reading = try #require(draft.opponentReading)
        draft.opponentStrength = .muchStronger
        t.input.clipboard = ""
        t.model.pasteOpponentSquad(into: &draft)
        #expect(draft.pasteProblem != nil)
        #expect(draft.opponentReading == reading)
        #expect(draft.opponentStrength == .muchStronger)
    }

    @Test func aLaterPasteReplacesTheReadingAndClearsTheProblem() throws {
        let t = try ready()
        var draft = draft(t)
        t.model.pasteOpponentSquad(into: &draft)
        t.input.clipboard = ""
        t.model.pasteOpponentSquad(into: &draft)
        #expect(draft.pasteProblem != nil)

        var settings = t.model.settings
        settings.currentDate = today.adding(days: 2)
        t.model.update(settings)
        try putTheirsOnTheClipboard(t)
        t.model.pasteOpponentSquad(into: &draft)
        #expect(draft.pasteProblem == nil)
        #expect(draft.opponentReading?.day == today.adding(days: 2))
    }

    @Test func pickingAStrengthByHandKeepsTheReading() throws {
        let t = try ready()
        var draft = draft(t)
        t.model.pasteOpponentSquad(into: &draft)
        let reading = try #require(draft.opponentReading)
        let picked = OpponentStrength.allCases.first { $0 != reading.strength }!
        draft.opponentStrength = picked
        let id = try #require(t.model.save(draft))
        let stored = try #require(t.model.fixtures.first { $0.id == id })
        #expect(stored.opponentStrength == picked)
        #expect(stored.opponentReading == reading)
    }

    @Test func aPasteWithoutAnIdColumnIsReadWithNoWarning() throws {
        let t = try ready()
        var draft = draft(t)
        t.model.pasteOpponentSquad(into: &draft)
        #expect(draft.opponentReading != nil)
        #expect(draft.pasteProblem == nil)
    }

    @Test func aFixtureFromBeforeThisPlanOpensWithNoReading() throws {
        let t = try TestModel()
        let saved = #"""
        {"version": 1, "value": [{"id": "f1", "date": "2026-11-13", "opponent": "Rovers", "importance": "high",
          "overrides": {}, "rejected": [], "opponentStrength": "weaker"}]}
        """#
        try Data(saved.utf8).write(to: t.directory.appendingPathComponent("fixtures.json"))
        let reopened = t.reopened()
        #expect(reopened.notices.isEmpty)
        #expect(reopened.fixtures.first?.opponentReading == nil)
        #expect(reopened.fixtures.first?.opponentStrength == .weaker)
    }

    @Test func editingAFixtureShowsItsSavedReading() throws {
        let t = try ready()
        var draft = draft(t)
        t.model.pasteOpponentSquad(into: &draft)
        let id = try #require(t.model.save(draft))
        let stored = try #require(t.model.fixtures.first { $0.id == id })
        let editing = t.model.fixtureDraft(for: stored)
        #expect(editing.opponentReading == draft.opponentReading)
        #expect(editing.opponentReadingText == draft.opponentReadingText)
        #expect(editing.pasteProblem == nil)
    }
}

extension FixturePresentationTests {
    @Test func useItInTheTableKeepsTheReading() throws {
        let c = try clockedSample()
        defer { try? FileManager.default.removeItem(at: c.directory) }
        let fixture = try fixturesShowingALine(c.model, count: 1)[0]
        // The sample squad is keyed by name, so the paste keyed by FMRTE's id reads as another club's.
        c.input.clipboard = try Captures.firstTeamWithID
        c.input.config = .data(try Captures.firstTeamWithIDGrids)
        var draft = c.model.fixtureDraft(for: fixture)
        c.model.pasteOpponentSquad(into: &draft)
        #expect(draft.pasteProblem == nil, "\(draft.pasteProblem ?? "")")
        let reading = try #require(draft.opponentReading)
        // The paste moved nothing in the saved fixture; saving the draft keeps its importance and adds the reading.
        c.model.save(draft)
        let current = try #require(c.model.fixtures.first { $0.id == fixture.id })
        let line = try #require(c.model.suggestionLine(for: current))
        c.model.useSuggestion(for: fixture.id)
        let after = try #require(c.model.fixtures.first { $0.id == fixture.id })
        #expect(after.importance == line.importance)
        #expect(after.importance != fixture.importance)
        #expect(after.opponentReading == reading)
        #expect(after.opponentStrength == reading.strength)
    }
}
