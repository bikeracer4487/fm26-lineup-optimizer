import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

/// Every replan runs the planner on the main actor, about 0.1 seconds a fixture in a debug build, so most tests plan two
/// or three fixtures of their own and only those that need the sample's five fixtures or its history use it.
@MainActor @Suite struct PlanStateTests {
    private func sample() throws -> AppModel { try SampleData.model(repositoryRoot: Captures.repositoryRoot) }

    /// Both captured squads, the club named, `count` medium fixtures three days apart from tomorrow, and the starter
    /// tactic, added last so the fixtures are planned once.
    private func squad(fixtures count: Int, _ t: TestModel) throws -> AppModel {
        try t.importFirstTeam()
        try t.importU21()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        for n in 0..<count {
            t.model.addFixture(date: TestModel.today.adding(days: 1 + 3 * n), opponent: "Opponent \(n + 1)", importance: .medium)
        }
        t.model.addTactic(named: "4-2-3-1")
        return t.model
    }

    private func plans(_ model: AppModel, sourceLocation: SourceLocation = #_sourceLocation) -> [FixturePlan] {
        guard case .ready(let plans) = model.planState else {
            Issue.record("expected a ready plan, got \(model.planState)", sourceLocation: sourceLocation)
            return []
        }
        return plans
    }

    private func plan(_ model: AppModel, _ id: FixtureID, sourceLocation: SourceLocation = #_sourceLocation) -> FixturePlan? {
        plans(model, sourceLocation: sourceLocation).first { $0.id == id }
    }

    private func lineup(_ plan: FixturePlan?, sourceLocation: SourceLocation = #_sourceLocation) -> Lineup? {
        guard case .planned(let lineup, _)? = plan?.body else {
            Issue.record("expected a planned lineup, got \(String(describing: plan?.body))", sourceLocation: sourceLocation)
            return nil
        }
        return lineup
    }

    private func record(_ plan: FixturePlan?, sourceLocation: SourceLocation = #_sourceLocation) -> ConfirmedRecord? {
        guard case .confirmed(let record)? = plan?.body else {
            Issue.record("expected a confirmed lineup, got \(String(describing: plan?.body))", sourceLocation: sourceLocation)
            return nil
        }
        return record
    }

    private func pick(at slot: SlotID, _ plan: FixturePlan?) -> Pick? {
        lineup(plan)?.picks.first { $0.slot == slot }
    }

    private func isBelowTheFloor(_ omission: Omission) -> Bool {
        if case .excluded(.belowConditionFloor) = omission.cause { true } else { false }
    }

    /// For each player whose pick or omission names his run of starts, the run.
    private func runs(_ lineup: Lineup?) -> [PlayerID: Int] {
        let marker = "Has started the last "
        func run(_ reason: String) -> Int? {
            guard let range = reason.range(of: marker) else { return nil }
            return Int(reason[range.upperBound...].prefix { $0.isNumber })
        }
        var found: [PlayerID: Int] = [:]
        for pick in lineup?.picks ?? [] {
            if let n = pick.reasons.compactMap(run).first { found[pick.player] = n }
        }
        for omission in lineup?.omissions ?? [] {
            if let n = run(omission.reason) { found[omission.player] = n }
        }
        return found
    }

    // MARK: What is missing (Review Focus 4)

    @Test func noSquadNeedsASquad() throws {
        let t = try TestModel()
        #expect(t.model.planState == .needsSquad)
        t.model.addTactic(named: "4-2-3-1")
        t.model.addFixture(date: TestModel.today, opponent: "Banbury United", importance: .medium)
        #expect(t.model.planState == .needsSquad)
    }

    @Test func noTacticNeedsATactic() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        #expect(t.model.planState == .needsTactic)
        t.model.addFixture(date: TestModel.today, opponent: "Banbury United", importance: .medium)
        #expect(t.model.planState == .needsTactic)

        let model = try SampleData.modelWithTacticProblem(repositoryRoot: Captures.repositoryRoot)
        #expect(model.planState == .needsTactic)
    }

    @Test func aTacticWithProblemsStopsThePlanOnlyWhenAFixtureUsesIt() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 2, t)
        let spare = model.addTactic(named: "Spare")
        var broken = model.tactics.first { $0.id == spare }!
        broken.tactic.inPossession[.ST_C] = nil
        model.update(broken)
        #expect(plans(model).count == 2)

        var fixture = model.fixtures[1]
        fixture.tacticID = spare
        model.update(fixture)
        #expect(model.planState == .needsTactic)

        // Confirmed, the fixture needs no tactic.
        fixture.tacticID = nil
        model.update(fixture)
        model.confirm(fixture.id)
        fixture.tacticID = spare
        model.update(fixture)
        #expect(plans(model).count == 2)
    }

    @Test func noFixturesNeedsFixtures() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        t.model.addTactic(named: "4-2-3-1")
        #expect(t.model.planState == .needsFixtures)
        t.model.addFixture(date: TestModel.today, opponent: "Banbury United", importance: .medium)
        #expect(plans(t.model).count == 1)
    }

    // MARK: The plan

    @Test func theSampleDataPlansFiveFixtures() throws {
        let model = try sample()
        let plans = plans(model)
        // The two confirmed matches in the sample's history have no saved fixture: they are history, not plans.
        #expect(model.history.count == 2)
        #expect(plans.count == 5)
        #expect(plans.map(\.id) == model.fixtures.map(\.id))
        #expect(plans.map(\.fixture.date) == plans.map(\.fixture.date).sorted())
        for plan in plans {
            #expect(lineup(plan)?.picks.count == 11)
            #expect(plan.tacticName == model.primaryTactic?.tactic.name)
            #expect(!plan.usesPrimaryBecauseItsTacticWasDeleted)
            #expect(plan.ignoredOverrides.isEmpty)
        }
    }

    @Test func theModelOpenedAgainHasTheSamePlan() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 2, t)
        #expect(plans(model).count == 2)
        #expect(t.reopened().planState == model.planState)
    }

    @Test func onlyTheHorizonIsPlanned() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 3, t)
        var settings = model.settings
        settings.plan.horizon = 2
        model.update(settings)
        #expect(plans(model).map(\.id) == model.fixtures.prefix(2).map(\.id))
    }

    // MARK: Override and reject

    @Test func anOverridePutsThePlayerInTheSlotAndIsSaved() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 2, t)
        let id = model.fixtures[0].id
        guard let first = lineup(plan(model, id)) else { return }
        let benched = model.candidates(for: .ST_C, in: id).first { c in
            c.unavailable == nil && !first.picks.contains { $0.player == c.player }
        }
        guard let benched else { Issue.record("no available player outside the eleven"); return }

        model.setOverride(benched.player, at: .ST_C, in: id)
        #expect(model.fixtures[0].overrides == [.ST_C: benched.player])
        #expect(t.reopened().fixtures[0].overrides == [.ST_C: benched.player])
        let chosen = pick(at: .ST_C, plan(model, id))
        #expect(chosen?.player == benched.player && chosen?.isOverride == true)
        #expect(lineup(plan(model, model.fixtures[1].id))?.picks.contains { $0.isOverride } == false)

        // Setting another replaces him.
        let next = model.candidates(for: .ST_C, in: id).first { $0.unavailable == nil && $0.player != benched.player }!
        model.setOverride(next.player, at: .ST_C, in: id)
        #expect(model.fixtures[0].overrides == [.ST_C: next.player])
        #expect(pick(at: .ST_C, plan(model, id))?.player == next.player)
    }

    @Test func clearingAnOverrideRestoresThePick() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 2, t)
        let id = model.fixtures[0].id
        let before = model.planState
        guard let original = pick(at: .ST_C, plan(model, id)) else { return }
        let other = model.candidates(for: .ST_C, in: id).first { $0.unavailable == nil && $0.player != original.player }!
        model.setOverride(other.player, at: .ST_C, in: id)
        #expect(model.planState != before)
        model.setOverride(nil, at: .ST_C, in: id)
        #expect(model.fixtures[0].overrides.isEmpty)
        #expect(model.planState == before)
    }

    @Test func aRejectedPlayerDoesNotStartThatFixtureOnly() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 2, t)
        let ids = model.fixtures.map(\.id)
        guard let keeper = pick(at: .GK, plan(model, ids[0]))?.player else { return }
        // A goalkeeper keeps his place from one match to the next, so one left out of the first is seen in the second.
        #expect(pick(at: .GK, plan(model, ids[1]))?.player == keeper)

        model.reject(keeper, in: ids[0])
        #expect(model.fixtures[0].rejected == [keeper])
        #expect(t.reopened().fixtures[0].rejected == [keeper])
        #expect(lineup(plan(model, ids[0]))?.picks.contains { $0.player == keeper } == false)
        #expect(pick(at: .GK, plan(model, ids[1]))?.player == keeper)
        #expect(model.fixtures[1].rejected.isEmpty)
    }

    @Test func allowingHimAgainRestoresThePick() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 2, t)
        let id = model.fixtures[0].id
        let before = model.planState
        guard let keeper = pick(at: .GK, plan(model, id))?.player else { return }
        model.reject(keeper, in: id)
        #expect(model.planState != before)
        model.allow(keeper, in: id)
        #expect(model.fixtures[0].rejected.isEmpty)
        #expect(model.planState == before)
    }

    @Test func aRejectedPlayerWhoHasLeftIsKeptWithoutFailing() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 1, t)
        let id = model.fixtures[0].id
        let gone = PlayerID(key: "nobody of that name")
        model.reject(gone, in: id)
        #expect(model.fixtures[0].rejected == [gone])
        #expect(lineup(plan(model, id))?.picks.count == 11)
    }

    @Test func anOverrideNamingAPlayerWhoHasLeftIsReportedAsIgnored() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 1, t)
        let id = model.fixtures[0].id
        let before = pick(at: .D_L, plan(model, id))
        let gone = PlayerID(key: "nobody of that name")
        model.setOverride(gone, at: .D_L, in: id)
        #expect(model.fixtures[0].overrides[.D_L] == gone)
        #expect(plan(model, id)?.ignoredOverrides
            == ["D_L: " + ErrorDescriptions.describe(OverrideProblem.notInSquad, parameters: .fm27)])
        #expect(pick(at: .D_L, plan(model, id)) == before)

        guard let injured = model.players.first(where: \.isInjured) else { Issue.record("no injured player"); return }
        model.setOverride(injured.id, at: .AM_C, in: id)
        #expect(plan(model, id)?.ignoredOverrides
            == ["D_L: who is not in the imported squads", "AM_C: injured, which cannot be overruled"])
    }

    // MARK: Confirm and unlock

    @Test func confirmingLocksTheLineupAndTakesItOutOfReplanning() throws {
        let model = try sample()
        let ids = model.fixtures.map(\.id)
        guard let planned = lineup(plan(model, ids[0])) else { return }

        model.confirm(ids[0])
        guard let record = record(plan(model, ids[0])) else { return }
        #expect(model.history.last == record)
        #expect(record.lineup.fixture == ids[0] && record.lineup.date == model.fixtures[0].date)
        #expect(record.lineup.starters.count == 11)
        #expect(record.lineup.starters == Dictionary(uniqueKeysWithValues: planned.picks.map { ($0.slot, $0.player) }))
        #expect(record.names.count == 11)
        #expect(record.names == Dictionary(uniqueKeysWithValues: planned.picks.map { ($0.player, $0.name) }))
        #expect(record.tacticName == model.primaryTactic?.tactic.name)
        #expect(plans(model).count == 5)
        #expect(plans(model).dropFirst().allSatisfy { lineup($0) != nil })

        var settings = model.settings
        settings.conditionFloor = 0.99
        model.update(settings)
        #expect(self.record(plan(model, ids[0])) == record)

        // The next fixture counts the confirmed match: a run of starts is longer than with that match gone.
        let without = try sample()
        without.deleteFixture(ids[0])
        let counted = runs(lineup(plan(model, ids[1])))
        let uncounted = runs(lineup(plan(without, ids[1])))
        #expect(counted.contains { player, run in record.lineup.starters.values.contains(player) && run > uncounted[player] ?? 0 })
    }

    @Test func confirmingWritesTheHistoryAndOnlyAPlannedLineupCanBeConfirmed() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 3, t)
        let ids = model.fixtures.map(\.id)
        model.confirm(ids[0])
        #expect(model.history.count == 1)
        #expect(t.reopened().history == model.history)

        let history = model.history
        model.confirm(ids[0])   // already confirmed
        #expect(model.history == history)
        var settings = model.settings
        settings.plan.horizon = 1
        model.update(settings)
        model.confirm(ids[2])   // beyond the horizon
        #expect(model.history == history)
        model.confirm(FixtureID("no such fixture"))
        #expect(model.history == history)
        settings.plan.horizon = 0
        model.update(settings)
        model.confirm(ids[1])   // the plan failed
        #expect(model.history == history)
    }

    @Test func unlockingPlansItAgainWithItsChoices() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 2, t)
        let id = model.fixtures[0].id
        guard let keeper = pick(at: .GK, plan(model, id))?.player else { return }
        model.reject(keeper, in: id)
        let before = model.planState
        model.confirm(id)
        #expect(model.planState != before)
        #expect(model.fixtures[0].rejected == [keeper])

        model.unlock(id)
        #expect(model.history.isEmpty)
        #expect(t.reopened().history.isEmpty)
        #expect(model.planState == before)
        #expect(lineup(plan(model, id))?.picks.contains { $0.player == keeper } == false)
    }

    @Test func aConfirmedLineupKeepsItsNamesAfterThePlayersLeave() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 2, t)
        let id = model.fixtures[0].id
        model.confirm(id)
        guard let record = record(plan(model, id)) else { return }

        // The U21 squad imported as the first team: the first team's players are no longer in the squads.
        t.importSquad(.firstTeam, paste: try Captures.u21, grids: try Captures.u21Grids)
        let present = Set(model.players.map(\.id))
        #expect(record.lineup.starters.values.contains { !present.contains($0) })
        #expect(self.record(plan(model, id)) == record)
    }

    // MARK: Things that point at something gone, and failures

    @Test func aFixtureWhoseTacticWasDeletedUsesThePrimaryAndSaysSo() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 2, t)
        guard let primary = model.primaryTactic, let copy = model.duplicateTactic(primary.id) else { return }
        var own = model.fixtures[0]
        own.tacticID = copy
        model.update(own)
        var gone = model.fixtures[1]
        gone.tacticID = UUID()
        model.update(gone)

        let plans = plans(model)
        #expect(plans[0].tacticName == "\(primary.tactic.name) copy" && !plans[0].usesPrimaryBecauseItsTacticWasDeleted)
        #expect(plans[1].tacticName == primary.tactic.name && plans[1].usesPrimaryBecauseItsTacticWasDeleted)
        #expect(lineup(plans[1])?.picks.count == 11)
    }

    @Test func movingTheDatePastAnUnconfirmedFixtureStopsThePlanWithTheEnginesSentence() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 1, t)
        let fixture = model.fixtures[0]
        model.moveToday(by: 2)
        #expect(plans(model).count == 1)   // the plan starts from the import, not from the game's date
        try t.importFirstTeam()
        #expect(model.planState == .failed([ErrorDescriptions.describe(
            PlanError.fixtureBeforeSnapshot(fixture.id, date: fixture.date, asOf: TestModel.today.adding(days: 2)))]))
        #expect(model.candidates(for: .GK, in: fixture.id).isEmpty)
    }

    @Test func aConfirmedFixtureBeforeTheImportDoesNotStopThePlan() throws {
        let model = try SampleData.modelWithPastFixtures(repositoryRoot: Captures.repositoryRoot)
        let plans = plans(model)
        #expect(record(plans.first) != nil)
        #expect(plans.dropFirst().allSatisfy { lineup($0) != nil })
    }

    @Test func aSettingOutOfRangeStopsThePlanWithTheEnginesSentence() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 1, t)
        var settings = model.settings
        settings.plan.horizon = 0
        model.update(settings)
        #expect(model.planState == .failed([ErrorDescriptions.describe(
            PlanError.badSettings(["Horizon must be at least 1 fixture, but is 0"]))]))
        settings.plan.horizon = 5
        model.update(settings)
        #expect(plans(model).count == 1)
    }

    @Test func theConditionFloorSettingChangesWhoIsLeftOut() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 2, t)
        // At the second fixture the first one's starters are below full condition.
        let id = model.fixtures[1].id
        guard let before = lineup(plan(model, id)) else { return }
        #expect(!before.omissions.contains(where: isBelowTheFloor))

        var settings = model.settings
        settings.conditionFloor = 0.99
        model.update(settings)
        guard let after = lineup(plan(model, id)) else { return }
        let floored = after.omissions.filter(isBelowTheFloor)
        #expect(!floored.isEmpty)
        #expect(floored.allSatisfy { $0.reason.hasSuffix("is below the 99% floor") })
        #expect(!after.picks.contains { pick in floored.contains { $0.player == pick.player } })

        settings.conditionFloor = nil
        model.update(settings)
        #expect(lineup(plan(model, id)) == before)
    }

    // MARK: Candidates

    @Test func candidatesAreBestFirstAndSayWhoCannotPlay() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 2, t)
        let id = model.fixtures[0].id
        let candidates = model.candidates(for: .GK, in: id)
        #expect(candidates.map(\.rating) == candidates.map(\.rating).sorted(by: >))
        #expect(Set(candidates.map(\.player)).count == candidates.count)

        let onLoan = model.players.filter {
            if case .loanedOut = model.squad.book.loanStatus(of: $0, override: model.settings.clubOverride) { true } else { false }
        }
        #expect(!onLoan.isEmpty)
        #expect(candidates.count == model.players.count - onLoan.count)
        #expect(!candidates.contains { c in onLoan.contains { $0.id == c.player } })

        guard let injured = model.players.first(where: \.isInjured) else { Issue.record("no injured player"); return }
        let his = candidates.first { $0.player == injured.id }
        #expect(his?.unavailable == "injured")
        #expect(his?.name == injured.name && his?.squad == injured.squad)
        #expect((his?.rating ?? 0) > 0)

        let picked = pick(at: .GK, plan(model, id))
        let pickedCandidate = candidates.first { $0.player == picked?.player }
        #expect(pickedCandidate?.unavailable == nil)
        #expect(pickedCandidate?.rating == picked?.rating.value)
    }

    @Test func aCandidateWhoCannotPlaySaysSoAsHisLeftOutLineWould() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 2, t)
        let ids = model.fixtures.map(\.id)
        guard let keeper = pick(at: .GK, plan(model, ids[0]))?.player else { return }
        model.reject(keeper, in: ids[0])
        #expect(model.candidates(for: .GK, in: ids[0]).first { $0.player == keeper }?.unavailable == "rejected for this fixture")
        #expect(model.candidates(for: .GK, in: ids[1]).first { $0.player == keeper }?.unavailable == nil)

        var settings = model.settings
        settings.conditionFloor = 0.99
        model.update(settings)
        // The second fixture's fitness is projected, so a floor reason says so, as the selector's does.
        guard let second = lineup(plan(model, ids[1])),
              let floored = second.omissions.first(where: isBelowTheFloor) else {
            Issue.record("nobody below the floor at the second fixture"); return
        }
        let candidate = model.candidates(for: floored.slot, in: ids[1]).first { $0.player == floored.player }
        #expect(candidate?.unavailable.map { "Left out: " + $0 } == floored.reason)
        #expect(candidate?.unavailable?.hasPrefix("projected condition") == true)
    }

    @Test func aFixtureWithNoPlannedLineupHasNoCandidates() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 3, t)
        let ids = model.fixtures.map(\.id)
        model.confirm(ids[0])
        #expect(model.candidates(for: .GK, in: ids[0]).isEmpty)   // confirmed
        #expect(model.candidates(for: .M_C, in: ids[1]).isEmpty)  // not a slot of the tactic
        #expect(model.candidates(for: .GK, in: FixtureID("no such fixture")).isEmpty)
        var settings = model.settings
        settings.plan.horizon = 1
        model.update(settings)
        #expect(!model.candidates(for: .GK, in: ids[1]).isEmpty)
        #expect(model.candidates(for: .GK, in: ids[2]).isEmpty)   // beyond the horizon
    }

    // MARK: Following every change

    @Test func thePlanFollowsEveryChange() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 3, t)
        var state = model.planState
        #expect(plans(model).count == 3)

        func changed(_ what: String, sourceLocation: SourceLocation = #_sourceLocation) {
            #expect(model.planState != state, "\(what) did not change the plan", sourceLocation: sourceLocation)
            state = model.planState
        }

        // The game's date alone does not move the plan's starting day; an import on the new date does.
        model.moveToday(by: 1)
        #expect(model.planState == state)
        try t.importFirstTeam()
        changed("An import")

        guard var tactic = model.primaryTactic else { Issue.record("no primary tactic"); return }
        tactic.tactic.inPossession[.AM_L] = "Winger"
        model.update(tactic)
        changed("A tactic edit")

        var fixture = model.fixtures[1]
        fixture.importance = .high
        model.update(fixture)
        changed("A fixture edit")

        var settings = model.settings
        settings.plan.horizon = 2
        model.update(settings)
        changed("A settings change")

        model.deleteFixture(model.fixtures[0].id)
        changed("Deleting a fixture")
        model.addFixture(date: TestModel.today.adding(days: 2), opponent: "Thame United", importance: .low)
        changed("Adding a fixture")
        var draft = FixtureDraft(date: TestModel.today.adding(days: 3))
        draft.opponent = "Kidlington"
        model.save(draft)
        changed("Saving a new fixture")

        let copy = model.duplicateTactic(tactic.id)!
        fixture = model.fixtures[0]
        fixture.tacticID = copy
        model.update(fixture)
        changed("A fixture moved to another tactic")
        model.deleteTactic(copy)
        changed("Deleting the tactic a fixture used")

        let other = model.addTactic(named: "Starter")
        model.makePrimary(other)
        changed("Another tactic made primary")
        #expect(plans(model).allSatisfy { $0.tacticName == "Starter" })
    }

    @Test func anUnsavedTacticChangeDoesNotChangeThePlan() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 1, t)
        let before = model.planState
        guard let id = model.primaryTactic?.id, var draft = model.draft(for: id) else { return }
        draft.setRole("Winger", at: .AM_L, in: .inPossession)
        model.setDraft(draft, for: id)
        #expect(model.hasUnsavedChanges(id))
        #expect(model.planState == before)
        model.saveDraft(id)
        #expect(model.planState != before)
    }
}
