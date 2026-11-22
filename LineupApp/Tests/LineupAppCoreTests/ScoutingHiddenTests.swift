import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

/// Hiding a pasted player and showing him again: what is left out, what is saved, and what is left alone.
@MainActor @Suite struct ScoutingHiddenTests {
    /// The model with the U21s pasted as another club's players, and the clock stopped, so that it moves only when a
    /// test moves it (left alone it moves a second at each reading, and no click would ever be a double click).
    private func pasted() throws -> TestModel {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t)
        t.input.tick = 0
        t.input.uptime = 1_000
        return t
    }

    /// Moves the clock past the guard, so the next "Hide" or "Show again" is not taken for a double click.
    private func advance(_ t: TestModel) {
        t.input.uptime += AppModel.scoutingActionInterval + 1
    }

    private func write(_ text: String, to t: TestModel) throws {
        try Data(text.utf8).write(to: t.directory.appendingPathComponent("scouting.json"))
    }

    // MARK: Hiding

    @Test func hidingLeavesThePlayerOutSavesTheFileAndDoesNotPlan() throws {
        let t = try pasted()
        let before = try ScoutingSetup.report(t.model)
        let victim = try #require(before.candidates.first)
        let planned = t.model.timesPlanned
        t.model.hideCandidate(victim.id, for: nil)
        let after = try ScoutingSetup.report(t.model)
        #expect(after.candidates.map(\.id) == before.candidates.map(\.id).filter { $0 != victim.id })
        #expect(after.hidden.map(\.id) == [victim.id])
        #expect(t.model.scouting.hidden == [HiddenCandidate(victim.player)])
        #expect(t.model.timesPlanned == planned)
        #expect(t.reopened().scouting.hidden == [HiddenCandidate(victim.player)])       // across a restart
    }

    @Test func aHiddenPlayerStaysHiddenAfterClearAndANewPaste() throws {
        let t = try pasted()
        let victim = try #require(try ScoutingSetup.report(t.model).candidates.first)
        t.model.hideCandidate(victim.id, for: nil)
        t.model.clearCandidates()
        #expect(t.model.scouting.hidden == [HiddenCandidate(victim.player)])
        try ScoutingSetup.paste(t)
        let report = try ScoutingSetup.report(t.model)
        #expect(report.hidden.map(\.id) == [victim.id])
        #expect(!report.candidates.contains { $0.id == victim.id })
    }

    @Test func showAgainBringsHimBackAndSaves() throws {
        let t = try pasted()
        let before = try ScoutingSetup.report(t.model)
        let victim = try #require(before.candidates.first)
        t.model.hideCandidate(victim.id, for: nil)
        advance(t)
        let planned = t.model.timesPlanned
        t.model.showCandidateAgain(victim.id, for: nil)
        #expect(try ScoutingSetup.report(t.model) == before)
        #expect(t.model.scouting.hidden.isEmpty)
        #expect(t.model.timesPlanned == planned)
        #expect(t.reopened().scouting.hidden.isEmpty)
    }

    @Test func aSecondClickInsideHalfASecondDoesNothing() throws {
        let t = try pasted()
        let candidates = try ScoutingSetup.report(t.model).candidates
        let a = try #require(candidates.first), b = try #require(candidates.dropFirst().first)
        t.model.hideCandidate(a.id, for: nil)
        t.input.uptime += AppModel.scoutingActionInterval / 2
        t.model.hideCandidate(b.id, for: nil)                                           // the row that moved up
        #expect(t.model.scouting.hidden == [HiddenCandidate(a.player)])
        t.input.uptime += AppModel.scoutingActionInterval / 4
        t.model.showCandidateAgain(a.id, for: nil)                                      // one clock for the two
        #expect(t.model.scouting.hidden == [HiddenCandidate(a.player)])
        advance(t)
        t.model.hideCandidate(b.id, for: nil)
        #expect(t.model.scouting.hidden == [HiddenCandidate(a.player), HiddenCandidate(b.player)])
        #expect(AppModel.scoutingActionInterval == 0.5)
    }

    /// The guard's clock is read after the candidates are judged again, so a click that waited for that is ignored too.
    @Test func theGuardRunsFromTheEndOfTheJudging() throws {
        let t = try pasted()
        let victim = try #require(try ScoutingSetup.report(t.model).candidates.first)
        let judged = t.model.timesCandidatesJudged
        t.model.hideCandidate(victim.id, for: nil)
        #expect(t.model.timesCandidatesJudged == judged + 1)
        #expect(t.model.lastScoutingAction == t.input.uptime)
    }

    @Test func hidingChangesNoOtherFileAndNoOtherAdvice() throws {
        let t = try pasted()
        let victim = try #require(try ScoutingSetup.report(t.model).candidates.first)
        let files = try ScoutingSetup.storeFiles(t)
        let squad = t.model.squad, marks = t.model.marks, plan = t.model.planState, advice = t.model.adviceState
        let paste = t.model.scoutingPaste
        t.model.hideCandidate(victim.id, for: nil)
        let now = try ScoutingSetup.storeFiles(t)
        #expect(Set(now.keys) == Set(files.keys))
        #expect(now.filter { files[$0.key] != $0.value }.map(\.key) == ["scouting.json"])
        #expect(t.model.squad == squad && t.model.marks == marks && t.model.planState == plan)
        #expect(t.model.adviceState == advice)
        #expect(t.model.scoutingPaste == paste)                                         // the paste itself is untouched
    }

    @Test func theFileHoldsOnlyANameAndAPotentialAbilityForEachHiddenPlayer() throws {
        let t = try pasted()
        let victim = try #require(try ScoutingSetup.report(t.model).candidates.first)
        t.model.hideCandidate(victim.id, for: nil)
        let data = try Data(contentsOf: t.directory.appendingPathComponent("scouting.json"))
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.contains(victim.player.name))
        #expect(!text.contains("Banbury United"))                                       // his club is not kept
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let value = try #require(json["value"] as? [String: Any])
        let hidden = try #require(value["hidden"] as? [[String: Any]])
        #expect(hidden.count == 1 && Set(hidden[0].keys) == ["name", "potentialAbility"])
    }

    @Test func statesSavedBeforeThisOpenWithNoNoticeAndNobodyHidden() throws {
        let t = try ScoutingSetup.ready()
        let file = t.directory.appendingPathComponent("scouting.json")
        #expect(FileManager.default.fileExists(atPath: file.path))                      // written at the first start
        try FileManager.default.removeItem(at: file)
        let reopened = t.reopened()
        #expect(reopened.notices.isEmpty)
        #expect(reopened.scouting == ScoutingState())
        #expect(FileManager.default.fileExists(atPath: file.path))
    }

    // MARK: What a person will meet (the plan's review focus)

    @Test func twoSavedEntriesForOnePlayerAreBothRemovedAtOnce() throws {
        let t = try pasted()
        let victim = try #require(try ScoutingSetup.report(t.model).candidates.first)
        t.model.hideCandidate(victim.id, for: nil)
        // The file as an earlier fault, or an edit by hand, could leave it: the same player twice.
        t.model.scouting.hidden.append(HiddenCandidate(victim.player))
        #expect(t.model.save(.scouting))
        let reopened = t.reopened()
        #expect(reopened.scouting.hidden.count == 2)
        #expect(t.model.scoutingPaste != nil)
        reopened.hold(t.model.scoutingPaste)
        guard case .ready(let report) = reopened.candidates(for: nil) else { Issue.record("not ready"); return }
        #expect(report.hidden.map(\.id) == [victim.id])                                 // listed once
        reopened.showCandidateAgain(victim.id, for: nil)
        #expect(reopened.scouting.hidden.isEmpty)
        guard case .ready(let after) = reopened.candidates(for: nil) else { Issue.record("not ready"); return }
        #expect(after.candidates.contains { $0.id == victim.id } && after.hidden.isEmpty)
    }

    @Test func hidingAHiddenPlayerAgainAddsNoSecondEntry() throws {
        let t = try pasted()
        let victim = try #require(try ScoutingSetup.report(t.model).candidates.first)
        t.model.hideCandidate(victim.id, for: nil)
        advance(t)
        t.model.hideCandidate(victim.id, for: nil)                                      // he is still in the paste
        #expect(t.model.scouting.hidden == [HiddenCandidate(victim.player)])
    }

    @Test func theSamePlayerOnTwoRowsIsHiddenAndShownTogether() throws {
        let t = try pasted()
        let paste = try #require(t.model.scoutingPaste)
        var twin = try #require(paste.players.first)
        twin.id = PlayerID(key: twin.id.key + " again")
        t.model.hold(ScoutingPaste(players: paste.players + [twin], money: paste.money))
        let first = try #require(paste.players.first)
        #expect(try ScoutingSetup.report(t.model).candidates.filter { $0.player.name == first.name }.count == 2)
        t.model.hideCandidate(first.id, for: nil)
        let hidden = try ScoutingSetup.report(t.model)
        #expect(hidden.hidden.map(\.id) == [first.id, twin.id])
        #expect(!hidden.candidates.contains { $0.player.name == first.name })
        #expect(t.model.scouting.hidden.count == 1)
        advance(t)
        t.model.showCandidateAgain(twin.id, for: nil)                                   // on the other row
        let shown = try ScoutingSetup.report(t.model)
        #expect(shown.hidden.isEmpty && shown.candidates.filter { $0.player.name == first.name }.count == 2)
    }

    @Test func hidingAPlayerNoLongerHeldDoesNothing() throws {
        let t = try pasted()
        let victim = try #require(try ScoutingSetup.report(t.model).candidates.first)
        t.model.clearCandidates()
        let files = try ScoutingSetup.storeFiles(t)
        t.model.hideCandidate(victim.id, for: nil)
        t.model.showCandidateAgain(victim.id, for: nil)
        #expect(t.model.scouting.hidden.isEmpty)
        #expect(try ScoutingSetup.storeFiles(t) == files)
        // And a key the paste never held.
        try ScoutingSetup.paste(t)
        advance(t)
        t.model.hideCandidate(PlayerID(key: "nobody at all"), for: nil)
        #expect(t.model.scouting.hidden.isEmpty)
    }

    @Test func anUnreadableFileStartsEmptyWithANoticeAndHidingThenSaves() throws {
        let t = try ScoutingSetup.ready()
        try write("{", to: t)
        let reopened = t.reopened()
        #expect(reopened.notices.count == 1)
        #expect(try #require(reopened.notices.first).text.hasPrefix("Your hidden candidates could not be read as saved data"))
        #expect(reopened.scouting == ScoutingState())
        #expect(FileManager.default.fileExists(atPath: t.directory.appendingPathComponent("scouting.unreadable-1.json").path))
        try ScoutingSetup.putCandidates(t)
        reopened.pasteCandidates()
        guard case .ready(let report) = reopened.candidates(for: nil) else { Issue.record("not ready"); return }
        let victim = try #require(report.candidates.first)
        reopened.hideCandidate(victim.id, for: nil)
        #expect(t.reopened().scouting.hidden == [HiddenCandidate(victim.player)])
    }

    @Test func aPlayerHiddenUnderOneTacticIsHiddenUnderEveryTactic() throws {
        let t = try pasted()
        let primary = try #require(t.model.primaryTactic)
        let second = t.model.addTactic(named: "Another")
        t.model.update(StoredTactic(id: second, tactic: primary.tactic))
        let victim = try #require(try ScoutingSetup.report(t.model, primary.id).candidates.first)
        #expect(try ScoutingSetup.report(t.model, second).candidates.contains { $0.id == victim.id })   // judged and kept
        t.model.hideCandidate(victim.id, for: primary.id)
        let other = try ScoutingSetup.report(t.model, second)
        #expect(!other.candidates.contains { $0.id == victim.id })
        #expect(other.hidden.map(\.id) == [victim.id])
    }
}
