import Foundation
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
            players: model.squad.book.allPlayers, tiers: tiers, parameters: model.planParameters)
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
            parameters: model.planParameters)
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

    // MARK: How the suggestion is shown

    private func suggestion(_ importance: Importance, basis: Evidence = .derived) -> ImportanceSuggestion {
        ImportanceSuggestion(importance: importance, score: 7, reasons: ["League match: 6", "Score 7: high"], basis: basis)
    }

    @Test func theSuggestionSaysWhatItIsWithItsReasonsAndEvidenceNote() {
        let note = SuggestionNote(suggestion(.high), chosen: .medium)
        #expect(note.text == "Suggested: High")
        #expect(note.text == AdvisorText.suggested(suggestion(.high)))
        #expect(note.reasons == ["League match: 6", "Score 7: high"])
        #expect(note.noteText == "(this tool's estimate)")
        #expect(note.importance == .high)
        #expect(SuggestionNote(suggestion(.high, basis: .carriedOverFM26), chosen: .high).noteText == "(FM26-era numbers)")
        #expect(SuggestionNote(suggestion(.high, basis: .fm27Measured), chosen: .high).noteText == nil)
        #expect(SuggestionNote.useItTitle == "Use it")
        #expect(SuggestionNote.clickHelp(false) == "Show the reasons")
        #expect(SuggestionNote.clickHelp(true) == "Hide the reasons")
        #expect(FixtureDraft.competitionLabel == "Competition")
        #expect(FixtureDraft.opponentStrengthLabel == "Opponent")
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
