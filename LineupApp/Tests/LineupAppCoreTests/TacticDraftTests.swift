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
}
