import Foundation
import LineupEngine
import Testing
@testable import LineupAppCore

@MainActor struct TacticDraftTests {
    let catalog: RoleCatalog

    init() throws {
        catalog = try RoleCatalog.fm27()
    }

    /// The engine's sample 4-2-3-1.
    func sample() throws -> Tactic {
        let data = try Data(contentsOf: Captures.directory.deletingLastPathComponent()
            .appendingPathComponent("tactics/sample-4231.json"))
        return try JSONDecoder().decode(Tactic.self, from: data)
    }

    @Test func addingASlotGivesItTheFirstAllowedRole() throws {
        var draft = TacticDraft(try sample())
        draft.toggle(.M_C, in: .inPossession, catalog: catalog)
        draft.toggle(.WB_L, in: .outOfPossession, catalog: catalog)
        #expect(draft.tactic.inPossession[.M_C] == catalog.roles(phase: .inPossession, at: .midfielderCentral).first?.name)
        #expect(draft.tactic.inPossession[.M_C] == "Advanced Playmaker")
        #expect(draft.tactic.outOfPossession[.WB_L] == "Holding Wing-Back")
        #expect(draft.tactic.inPossession.count == 12)
        #expect(draft.tactic.outOfPossession.count == 12)
    }

    @Test func removingASlotRemovesItsMapping() throws {
        var draft = TacticDraft(try sample())
        draft.toggle(.AM_L, in: .inPossession, catalog: catalog)
        #expect(draft.tactic.inPossession[.AM_L] == nil)
        #expect(draft.tactic.mapping[.AM_L] == nil)
        // The out-of-possession side is untouched.
        #expect(draft.tactic.outOfPossession[.M_L] == "Wide Midfielder")
        #expect(draft.tactic.mapping[.AM_R] == .M_R)
    }

    @Test func removingAnOutOfPossessionSlotClearsMappingsToIt() throws {
        var draft = TacticDraft(try sample())
        draft.map(.AM_C, to: .M_L)
        draft.toggle(.M_L, in: .outOfPossession, catalog: catalog)
        #expect(draft.tactic.outOfPossession[.M_L] == nil)
        #expect(draft.tactic.mapping[.AM_L] == nil)
        #expect(draft.tactic.mapping[.AM_C] == nil)
        #expect(draft.tactic.inPossession[.AM_L] == "Inside Forward")
        #expect(draft.tactic.mapping[.AM_R] == .M_R)
    }

    @Test func aNewInPossessionSlotMapsToItsOwnSlotWhenActive() throws {
        var draft = TacticDraft(try sample())
        // M_L is active out of possession, so a new in-possession M_L turns into it.
        draft.toggle(.M_L, in: .inPossession, catalog: catalog)
        #expect(draft.tactic.mapping[.M_L] == .M_L)
        // M_C is not active out of possession, so a new in-possession M_C turns into nothing yet.
        draft.toggle(.M_C, in: .inPossession, catalog: catalog)
        #expect(draft.tactic.mapping[.M_C] == nil)
        #expect(draft.tactic.mapping.keys.contains(.M_C) == false)
    }

    @Test func aNewInPossessionSlotDropsAMappingLeftFromBefore() throws {
        var tactic = try sample()
        tactic.mapping[.M_C] = .ST_C
        var draft = TacticDraft(tactic)
        draft.toggle(.M_C, in: .inPossession, catalog: catalog)
        #expect(draft.tactic.mapping[.M_C] == nil)
    }

    @Test func settingARoleAndAMapping() throws {
        var draft = TacticDraft(try sample())
        draft.setRole("Winger", at: .AM_L, in: .inPossession)
        draft.setRole("Tracking Wide Midfielder", at: .M_L, in: .outOfPossession)
        draft.map(.AM_C, to: .ST_C)
        #expect(draft.tactic.inPossession[.AM_L] == "Winger")
        #expect(draft.tactic.outOfPossession[.M_L] == "Tracking Wide Midfielder")
        #expect(draft.tactic.mapping[.AM_C] == .ST_C)
        // The other side of each change is untouched.
        #expect(draft.tactic.outOfPossession[.AM_L] == nil)
        #expect(draft.tactic.inPossession[.M_L] == nil)
    }

    @Test func settingARoleOnAnEmptySlotChangesNothing() throws {
        let tactic = try sample()
        var draft = TacticDraft(tactic)
        draft.setRole("Winger", at: .M_L, in: .inPossession)
        #expect(draft.tactic == tactic)
    }

    @Test func unmappedTargetsAreListed() throws {
        var draft = TacticDraft(try sample())
        #expect(draft.unmappedTargets.isEmpty)
        // AM_C now turns into M_L as well as AM_L does, so nothing turns into AM_C.
        draft.map(.AM_C, to: .M_L)
        #expect(draft.unmappedTargets == [.AM_C])
        // A mapping from an empty in-possession slot does not count.
        draft.tactic.mapping[.M_C] = .AM_C
        #expect(draft.unmappedTargets == [.AM_C])
        draft.toggle(.ST_C, in: .inPossession, catalog: catalog)
        #expect(draft.unmappedTargets == [.AM_C, .ST_C])
    }

    @Test func filledCountsEachPhase() throws {
        var draft = TacticDraft(try sample())
        #expect(draft.filled(in: .inPossession) == 11)
        draft.toggle(.ST_C, in: .inPossession, catalog: catalog)
        #expect(draft.filled(in: .inPossession) == 10)
        #expect(draft.filled(in: .outOfPossession) == 11)
        #expect(draft.role(at: .ST_C, in: .outOfPossession) == "Centre Forward")
        #expect(draft.role(at: .ST_C, in: .inPossession) == nil)
    }

    @Test func aSlotIsLinkedToWhatItTurnsIntoAndWhatTurnsIntoIt() throws {
        var draft = TacticDraft(try sample())
        #expect(draft.linked(to: TacticSlot(.AM_L, in: .inPossession)) == [TacticSlot(.M_L, in: .outOfPossession)])
        #expect(draft.linked(to: TacticSlot(.M_L, in: .outOfPossession)) == [TacticSlot(.AM_L, in: .inPossession)])
        draft.map(.AM_C, to: .M_L)
        #expect(draft.linked(to: TacticSlot(.M_L, in: .outOfPossession))
            == [TacticSlot(.AM_L, in: .inPossession), TacticSlot(.AM_C, in: .inPossession)])
        #expect(draft.linked(to: TacticSlot(.AM_C, in: .outOfPossession)).isEmpty)
        // An empty slot, and a mapping from an empty in-possession slot, link nothing.
        draft.tactic.mapping[.M_C] = .ST_C
        #expect(draft.linked(to: TacticSlot(.ST_C, in: .outOfPossession)) == [TacticSlot(.ST_C, in: .inPossession)])
        #expect(draft.linked(to: TacticSlot(.M_C, in: .inPossession)).isEmpty)
    }

    @Test func aSlotCanTurnIntoAnyFilledOutOfPossessionSlot() throws {
        var draft = TacticDraft(try sample())
        let filled: [SlotID] = [.GK, .D_L, .D_CL, .D_CR, .D_R, .DM_L, .DM_R, .M_L, .M_R, .AM_C, .ST_C]
        #expect(draft.targetChoices(for: .AM_L) == filled)
        // A target left from before is offered too, so the menu can show it.
        draft.tactic.mapping[.AM_L] = .M_C
        #expect(draft.targetChoices(for: .AM_L) == [.GK, .D_L, .D_CL, .D_CR, .D_R, .DM_L, .DM_R, .M_L, .M_C, .M_R, .AM_C, .ST_C])
    }

    @Test func theSampleTacticHasNoProblemsAndBreakingItGivesTheEnginesSentence() throws {
        let t = try TestModel()
        var draft = TacticDraft(try sample())
        #expect(t.model.problems(of: draft.tactic).isEmpty)
        draft.toggle(.ST_C, in: .inPossession, catalog: catalog)
        #expect(t.model.problems(of: draft.tactic) == [ErrorDescriptions.describe(TacticProblem.wrongSlotCount(.inPossession, 10))])
        #expect(t.model.problems(of: draft.tactic) == ["The in-possession side has 10 slots, not 11"])
        draft.toggle(.ST_C, in: .inPossession, catalog: catalog)
        #expect(t.model.problems(of: draft.tactic).isEmpty)
    }

    @Test func theSampleWithATacticProblemLacksItsStriker() throws {
        let model = try SampleData.modelWithTacticProblem(repositoryRoot: Captures.repositoryRoot)
        let stored = try #require(model.tactics.first)
        #expect(model.tactics.count == 1)
        #expect(model.problems(saving: stored) == ["The in-possession side has 10 slots, not 11"])
        #expect(TacticDraft(stored.tactic).unmappedTargets == [.ST_C])
    }

    // MARK: Names

    @Test func aTacticNeedsANameNoOtherTacticHas() throws {
        let t = try TestModel()
        let main = t.model.addTactic(named: "Main")
        let cup = t.model.addTactic(named: "Cup")
        var stored = try #require(t.model.tactics.first { $0.id == cup })
        #expect(t.model.problems(saving: stored).isEmpty)

        stored.tactic.name = "  "
        #expect(t.model.problems(saving: stored) == ["Give the tactic a name."])
        stored.tactic.name = "main "
        #expect(t.model.problems(saving: stored) == ["Another tactic is already called Main."])
        // A tactic keeps its own name.
        let own = try #require(t.model.tactics.first { $0.id == main })
        #expect(t.model.problems(saving: own).isEmpty)
    }

    @Test func aNameProblemComesBeforeTheEnginesProblems() throws {
        let t = try TestModel()
        let id = t.model.addTactic(named: "Main")
        var stored = try #require(t.model.tactics.first { $0.id == id })
        stored.tactic.name = ""
        stored.tactic.inPossession[.ST_C] = nil
        #expect(t.model.problems(saving: stored)
            == ["Give the tactic a name.", "The in-possession side has 10 slots, not 11"])
    }

    @Test func aNewTacticTakesAnUnusedName() throws {
        let t = try TestModel()
        #expect(t.model.unusedTacticName("New tactic") == "New tactic")
        t.model.addTactic(named: "New tactic")
        #expect(t.model.unusedTacticName("New tactic") == "New tactic 2")
        t.model.addTactic(named: "New tactic 2")
        #expect(t.model.unusedTacticName("New tactic") == "New tactic 3")
    }

    @Test func aSideHasTheEnginesNumberOfSlots() throws {
        // The engine reports a wrong count exactly when a side does not have `slotsPerSide` slots.
        var draft = TacticDraft(try sample())
        #expect(draft.filled(in: .inPossession) == TacticDraft.slotsPerSide)
        #expect(!draft.tactic.problems(catalog: catalog).contains(.wrongSlotCount(.inPossession, TacticDraft.slotsPerSide)))
        draft.toggle(.M_C, in: .inPossession, catalog: catalog)
        #expect(draft.tactic.problems(catalog: catalog).contains(.wrongSlotCount(.inPossession, TacticDraft.slotsPerSide + 1)))
    }

    // MARK: Unsaved drafts

    /// The model's draft of `id` with AM L in possession made a winger.
    func changedDraft(_ model: AppModel, _ id: UUID) throws -> TacticDraft {
        var draft = try #require(model.draft(for: id))
        draft.setRole("Winger", at: .AM_L, in: .inPossession)
        return draft
    }

    @Test func aDraftIsTheSavedTacticUntilChanged() throws {
        let t = try TestModel()
        let id = t.model.addTactic(named: "Main")
        let saved = try #require(t.model.tactics.first { $0.id == id })
        #expect(t.model.draft(for: id) == TacticDraft(saved.tactic))
        #expect(t.model.draft(for: UUID()) == nil)
        #expect(!t.model.hasUnsavedChanges(id))
        #expect(t.model.tacticsWithUnsavedChanges.isEmpty)
    }

    @Test func aDraftSurvivesChoosingAnotherTacticAndComingBack() throws {
        let t = try TestModel()
        let main = t.model.addTactic(named: "Main")
        let cup = t.model.addTactic(named: "Cup")
        let changed = try changedDraft(t.model, main)
        t.model.setDraft(changed, for: main)
        // Looking at the other tactic leaves the first one's changes alone.
        #expect(t.model.draft(for: cup) == TacticDraft(try #require(t.model.tactics.first { $0.id == cup }).tactic))
        #expect(t.model.draft(for: main) == changed)
        #expect(t.model.hasUnsavedChanges(main))
        #expect(!t.model.hasUnsavedChanges(cup))
        #expect(t.model.tacticsWithUnsavedChanges == [main])
        // The saved tactic is unchanged until the draft is saved.
        #expect(t.model.tactics.first { $0.id == main }?.tactic.inPossession[.AM_L] == "Inside Forward")
    }

    @Test func anIdenticalDraftIsNotKept() throws {
        let t = try TestModel()
        let id = t.model.addTactic(named: "Main")
        let original = try #require(t.model.draft(for: id))
        t.model.setDraft(try changedDraft(t.model, id), for: id)
        #expect(t.model.hasUnsavedChanges(id))
        // Changing it back is the same as having no changes.
        t.model.setDraft(original, for: id)
        #expect(!t.model.hasUnsavedChanges(id))
        #expect(t.model.tacticsWithUnsavedChanges.isEmpty)
        // A draft for a tactic that is not saved is not kept.
        let stray = UUID()
        t.model.setDraft(original, for: stray)
        #expect(t.model.draft(for: stray) == nil)
    }

    @Test func savingRefusesADraftWithAProblemAndSavesOneWithout() throws {
        let t = try TestModel()
        let id = t.model.addTactic(named: "Main")
        var broken = try changedDraft(t.model, id)
        broken.toggle(.ST_C, in: .inPossession, catalog: catalog)
        t.model.setDraft(broken, for: id)
        #expect(t.model.saveDraft(id) == false)
        #expect(t.model.hasUnsavedChanges(id))
        #expect(t.model.tactics.first { $0.id == id }?.tactic.inPossession[.ST_C] == "Channel Forward")

        let fixed = try changedDraft(t.model, id)
        var mended = try #require(t.model.draft(for: id))
        mended.toggle(.ST_C, in: .inPossession, catalog: catalog)
        mended.map(.ST_C, to: .ST_C)
        t.model.setDraft(mended, for: id)
        #expect(t.model.saveDraft(id))
        #expect(!t.model.hasUnsavedChanges(id))
        let saved = try #require(t.model.tactics.first { $0.id == id })
        #expect(saved.tactic.inPossession[.AM_L] == fixed.tactic.inPossession[.AM_L])
        #expect(saved.tactic.inPossession[.AM_L] == "Winger")
        #expect(t.reopened().tactics.first { $0.id == id }?.tactic.inPossession[.AM_L] == "Winger")
        // With nothing to save, nothing is saved.
        #expect(t.model.saveDraft(id) == false)
    }

    @Test func savingTrimsTheName() throws {
        let t = try TestModel()
        let id = t.model.addTactic(named: "Main")
        var draft = try #require(t.model.draft(for: id))
        draft.tactic.name = "  Cup run "
        t.model.setDraft(draft, for: id)
        #expect(t.model.saveDraft(id))
        #expect(t.model.tactics.first { $0.id == id }?.tactic.name == "Cup run")
        #expect(!t.model.hasUnsavedChanges(id))
    }

    @Test func aNameWithSpacesAroundItIsKeptAndSavedTrimmed() throws {
        let t = try TestModel()
        let id = t.model.addTactic(named: "Main")
        var draft = try #require(t.model.draft(for: id))
        draft.tactic.name = "Main "
        t.model.setDraft(draft, for: id)
        // Kept, so the field shows what was typed, and saving gives back the saved tactic.
        #expect(t.model.hasUnsavedChanges(id))
        #expect(t.model.saveDraft(id))
        #expect(t.model.tactics.first { $0.id == id }?.tactic.name == "Main")
        #expect(!t.model.hasUnsavedChanges(id))
    }

    @Test func revertingDropsTheDraft() throws {
        let t = try TestModel()
        let id = t.model.addTactic(named: "Main")
        let saved = try #require(t.model.tactics.first { $0.id == id })
        t.model.setDraft(try changedDraft(t.model, id), for: id)
        t.model.revertDraft(id)
        #expect(!t.model.hasUnsavedChanges(id))
        #expect(t.model.draft(for: id) == TacticDraft(saved.tactic))
        #expect(t.model.tactics.first { $0.id == id } == saved)
    }

    @Test func deletingATacticDropsItsDraft() throws {
        let t = try TestModel()
        let main = t.model.addTactic(named: "Main")
        let cup = t.model.addTactic(named: "Cup")
        t.model.setDraft(try changedDraft(t.model, cup), for: cup)
        t.model.deleteTactic(cup)
        #expect(t.model.tacticsWithUnsavedChanges.isEmpty)
        #expect(t.model.draft(for: cup) == nil)
        #expect(!t.model.hasUnsavedChanges(main))
    }

    @Test func unsavedChangesSurviveQuitting() throws {
        let t = try TestModel()
        let id = t.model.addTactic(named: "Main")
        let changed = try changedDraft(t.model, id)
        t.model.setDraft(changed, for: id)
        let reopened = t.reopened()
        #expect(reopened.tacticsWithUnsavedChanges == [id])
        #expect(reopened.draft(for: id) == changed)
        #expect(reopened.notices.isEmpty)
        // The saved tactic stays as it was.
        #expect(reopened.tactics.first { $0.id == id }?.tactic.inPossession[.AM_L] == "Inside Forward")

        // Reverting, saving and deleting are kept too.
        t.model.revertDraft(id)
        #expect(t.reopened().tacticsWithUnsavedChanges.isEmpty)
        t.model.setDraft(changed, for: id)
        #expect(t.model.saveDraft(id))
        #expect(t.reopened().tacticsWithUnsavedChanges.isEmpty)
        let cup = t.model.addTactic(named: "Cup")
        t.model.setDraft(try changedDraft(t.model, cup), for: cup)
        #expect(t.reopened().tacticsWithUnsavedChanges == [cup])
        t.model.deleteTactic(cup)
        #expect(t.reopened().tacticsWithUnsavedChanges.isEmpty)
    }

    @Test func aDraftForATacticNoLongerSavedIsDroppedAtLoad() throws {
        let t = try TestModel()
        let id = t.model.addTactic(named: "Main")
        let changed = try changedDraft(t.model, id)
        let stray = UUID()
        try Store(directory: t.directory).save([StoredTactic(id: stray, tactic: changed.tactic),
                                                StoredTactic(id: id, tactic: changed.tactic)], to: .drafts)
        let reopened = t.reopened()
        #expect(reopened.tacticsWithUnsavedChanges == [id])
        #expect(reopened.draft(for: stray) == nil)
        #expect(reopened.notices.isEmpty)
        let onDisk = Store(directory: t.directory).load(.drafts, as: [StoredTactic].self, otherwise: []).value
        #expect(onDisk.map(\.id) == [id])
    }

    @Test func aDraftIsKeptWhenSavingItsTacticFails() throws {
        let t = try TestModel()
        let id = t.model.addTactic(named: "Main")
        let changed = try changedDraft(t.model, id)
        t.model.setDraft(changed, for: id)
        let refusals = Refusals()
        let model = AppModel(store: Store(directory: t.directory, refuse: { refusals.error(for: $0) }),
                             environment: t.input.environment)
        refusals.files = [.tactics]
        model.saveDraft(id)
        #expect(model.notices.contains { $0.text.hasPrefix("Your tactics could not be saved") })
        #expect(model.hasUnsavedChanges(id))
        // The tactics file still holds the old tactic, and the edit is still saved as a draft.
        let reopened = t.reopened()
        #expect(reopened.draft(for: id)?.tactic == changed.tactic)
        #expect(reopened.hasUnsavedChanges(id))
    }

    @Test func draftsAreKeptWhenTheTacticsFileCouldNotBeReadOrKeptAside() throws {
        let t = try TestModel()
        let id = t.model.addTactic(named: "Main")
        let changed = try changedDraft(t.model, id)
        t.model.setDraft(changed, for: id)
        let draftsFile = t.directory.appendingPathComponent("drafts.json")
        let draftsBefore = try Data(contentsOf: draftsFile)
        try Data("{".utf8).write(to: t.directory.appendingPathComponent("tactics.json"))
        struct Refused: Error {}
        let store = Store(directory: t.directory, move: { _, _ in throw Refused() }, copy: { _, _ in throw Refused() })
        let model = AppModel(store: store, environment: t.input.environment)
        #expect(model.tactics.isEmpty)
        #expect(model.tacticDrafts[id]?.tactic == changed.tactic)
        #expect(try Data(contentsOf: draftsFile) == draftsBefore)

        // Changing another tactic saves the drafts with the one whose tactic could not be read still in them.
        let other = model.addTactic(named: "Other")
        model.setDraft(try changedDraft(model, other), for: other)
        let onDisk = Store(directory: t.directory).load(.drafts, as: [StoredTactic].self, otherwise: []).value
        #expect(Set(onDisk.map(\.id)) == [id, other])
    }

    // MARK: The editor's words

    @Test func theEditorsWordsAreWorkedOutFromTheDraft() throws {
        var draft = TacticDraft(try sample())
        #expect(draft.filledText(in: .inPossession) == "11 of 11 slots filled")
        #expect(Phase.inPossession.title == "In possession")
        #expect(Phase.outOfPossession.title == "Out of possession")
        #expect(TacticDraft.inspectorTitle(TacticSlot(.AM_L, in: .inPossession)) == "AM L, in possession")
        #expect(TacticDraft.inspectorTitle(TacticSlot(.M_L, in: .outOfPossession)) == "M L, out of possession")
        #expect(draft.targetName(.M_L) == "M L")
        #expect(draft.targetName(.M_C) == "M C (empty)")
        #expect(TacticDraft.slotHelp(.AM_L, role: "Winger") == "AM L: Winger")
        #expect(TacticDraft.slotHelp(.AM_L, role: nil) == "Add a slot at AM L")

        // Remove the left inside forward: one fewer in possession, and M L has nothing turning into it.
        draft.toggle(.AM_L, in: .inPossession, catalog: catalog)
        #expect(draft.filledText(in: .inPossession) == "10 of 11 slots filled")
        #expect(draft.targetName(.M_L) == "M L (nothing turns into it yet)")
    }

    @Test func theRoleMenuListsTheAllowedRolesWithTheCurrentOneFirstWhenItIsNotAllowed() throws {
        var draft = TacticDraft(try sample())
        let place = TacticSlot(.AM_L, in: .inPossession)
        let allowed = catalog.roles(phase: .inPossession, at: SlotID.AM_L.position).map(\.name)
        #expect(draft.roleChoices(at: place, catalog: catalog) == allowed)
        draft.setRole("Not A Role", at: .AM_L, in: .inPossession)
        #expect(draft.roleChoices(at: place, catalog: catalog) == ["Not A Role"] + allowed)
        #expect(draft.roleChoices(at: TacticSlot(.M_C, in: .inPossession), catalog: catalog).isEmpty)
    }

    @Test func duplicatingCopiesTheDraftAndSavesItWhenItHasNoProblems() throws {
        let t = try TestModel()
        let id = t.model.addTactic(named: "Main")
        var draft = try changedDraft(t.model, id)
        draft.tactic.name = "Cup"
        t.model.setDraft(draft, for: id)
        let copy = try #require(t.model.duplicateTactic(id))
        let saved = try #require(t.model.tactics.first { $0.id == copy })
        // Named after what the owner is looking at, and saved as it is.
        #expect(saved.tactic.name == "Cup copy")
        #expect(saved.tactic.inPossession[.AM_L] == "Winger")
        #expect(!t.model.hasUnsavedChanges(copy))
        // The original keeps its unsaved changes.
        #expect(t.model.draft(for: id) == draft)
        #expect(t.model.tactics.first { $0.id == id }?.tactic.name == "Main")
    }

    @Test func duplicatingADraftWithAProblemSavesTheSavedTacticAndKeepsTheChangesUnsaved() throws {
        let t = try TestModel()
        let id = t.model.addTactic(named: "Main")
        var draft = try changedDraft(t.model, id)
        draft.toggle(.ST_C, in: .inPossession, catalog: catalog)
        t.model.setDraft(draft, for: id)
        let copy = try #require(t.model.duplicateTactic(id))
        let saved = try #require(t.model.tactics.first { $0.id == copy })
        let original = try #require(t.model.tactics.first { $0.id == id })
        #expect(saved.tactic.name == "Main copy")
        #expect(saved.tactic.inPossession == original.tactic.inPossession)
        // The copy opens with the draft's changes, unsaved.
        #expect(t.model.hasUnsavedChanges(copy))
        var expected = draft
        expected.tactic.name = "Main copy"
        #expect(t.model.draft(for: copy) == expected)
    }

    @Test func aTacticsMenuTitleMarksThePrimaryAndUnsavedChanges() throws {
        let t = try TestModel()
        let main = t.model.addTactic(named: "Main")
        let cup = t.model.addTactic(named: "Cup")
        #expect(t.model.menuTitle(of: main) == "Main (primary)")
        #expect(t.model.menuTitle(of: cup) == "Cup")
        t.model.setDraft(try changedDraft(t.model, main), for: main)
        t.model.setDraft(try changedDraft(t.model, cup), for: cup)
        #expect(t.model.menuTitle(of: main) == "Main (primary) — unsaved changes")
        #expect(t.model.menuTitle(of: cup) == "Cup — unsaved changes")
        #expect(t.model.menuTitle(of: UUID()) == "")
    }

    @Test func theSampleWithAnUnsavedChangeHasOne() throws {
        let model = try SampleData.modelWithUnsavedTacticChange(repositoryRoot: Captures.repositoryRoot)
        let id = try #require(model.tactics.first?.id)
        #expect(model.tacticsWithUnsavedChanges == [id])
        #expect(model.draft(for: id)?.tactic.inPossession[.AM_L] == "Winger")
        #expect(model.problems(saving: StoredTactic(id: id, tactic: try #require(model.draft(for: id)).tactic)).isEmpty)
    }
}
