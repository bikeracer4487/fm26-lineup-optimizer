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

    private func fitness(_ plan: FixturePlan?, sourceLocation: SourceLocation = #_sourceLocation) -> [PlayerID: ProjectedFitness] {
        guard case .planned(_, let fitness)? = plan?.body else {
            Issue.record("expected a planned lineup, got \(String(describing: plan?.body))", sourceLocation: sourceLocation)
            return [:]
        }
        return fitness
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
        #expect(t.model.planState == .needsTactic([]))
        t.model.addFixture(date: TestModel.today, opponent: "Banbury United", importance: .medium)
        #expect(t.model.planState == .needsTactic([]))

        let model = try SampleData.modelWithTacticProblem(repositoryRoot: Captures.repositoryRoot)
        guard let primary = model.primaryTactic else { Issue.record("no primary tactic"); return }
        let problems = model.problems(of: primary.tactic)
        #expect(!problems.isEmpty)
        #expect(model.planState == .needsTactic(["Sample 4-2-3-1 cannot be used: \(problems.joined(separator: "; "))."]))
    }

    @Test func aTacticWithProblemsStopsThePlanOnlyWhenAFixtureWithinTheHorizonUsesIt() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 3, t)
        let spare = model.addTactic(named: "Spare")
        var broken = model.tactics.first { $0.id == spare }!
        broken.tactic.inPossession[.ST_C] = nil
        model.update(broken)
        #expect(plans(model).count == 3)
        let sentence = "Spare cannot be used: \(model.problems(of: broken.tactic).joined(separator: "; "))."

        for index in [1, 2] {
            var fixture = model.fixtures[index]
            fixture.tacticID = spare
            model.update(fixture)
        }
        #expect(model.planState == .needsTactic([sentence]))   // one sentence for the tactic, not one per fixture

        var settings = model.settings
        settings.plan.horizon = 1
        model.update(settings)
        #expect(plans(model).map(\.id) == [model.fixtures[0].id])

        // Once the first is confirmed, the second is within the horizon.
        model.confirm(model.fixtures[0].id)
        #expect(model.planState == .needsTactic([sentence]))
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
        #expect(plan(model, id)?.ignoredOverrides == ["The player chosen for D L is no longer in the squad."])
        #expect(pick(at: .D_L, plan(model, id)) == before)
    }

    @Test func anIgnoredOverrideNamesThePlayerTheSlotAndTheEnginesReason() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 1, t)
        let id = model.fixtures[0].id
        guard let keeper = model.players.first(where: { $0.name == "Jonny Maxted" }), keeper.isInjured,
              let striker = model.players.first(where: { $0.name == "Tyrone Marsh" }) else {
            Issue.record("the capture's injured keeper or its striker is missing"); return
        }
        model.setOverride(keeper.id, at: .GK, in: id)
        model.setOverride(striker.id, at: .AM_C, in: id)
        model.setOverride(striker.id, at: .ST_C, in: id)
        model.setOverride(PlayerID(key: "nobody of that name"), at: .D_L, in: id)
        #expect(plan(model, id)?.ignoredOverrides == [
            "Jonny Maxted at GK: injured, which cannot be overruled.",
            "The player chosen for D L is no longer in the squad.",
            "Tyrone Marsh at AM C: because he is fixed in another slot too.",
            "Tyrone Marsh at ST: because he is fixed in another slot too.",
        ])
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
        // At 99% the confirmed match's starters, tired by it, would be left out of the next fixture below the floor.
        settings.conditionFloor = nil
        model.update(settings)

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

    @Test func onlyTheEarliestPlannedFixtureCanBeConfirmed() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 3, t)
        let ids = model.fixtures.map(\.id)
        #expect(model.canConfirm(ids[0]) && model.whyNotConfirm(ids[0]) == nil)
        #expect(!model.canConfirm(ids[1]))
        #expect(model.whyNotConfirm(ids[1]) == "Confirm the earlier match against Opponent 1 first.")
        model.confirm(ids[1])
        #expect(model.history.isEmpty)

        model.confirm(ids[0])
        #expect(!model.canConfirm(ids[0]) && model.whyNotConfirm(ids[0]) == nil)   // confirmed, not planned
        #expect(model.canConfirm(ids[1]) && model.whyNotConfirm(ids[1]) == nil)
        #expect(model.whyNotConfirm(ids[2]) == "Confirm the earlier match against Opponent 2 first.")
        #expect(!model.canConfirm(FixtureID("no such fixture")) && model.whyNotConfirm(FixtureID("no such fixture")) == nil)
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
        // Only what the import says about the squads changes: the first team is no longer awaited.
        var kept = record
        kept.awaitingImport = [.u21]
        #expect(self.record(plan(model, id)) == kept)
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

    @Test func anUnconfirmedFixtureBeforeTheImportIsMissedAndThePlanGoesOn() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 2, t)
        let ids = model.fixtures.map(\.id)
        model.moveToday(by: 2)
        #expect(plans(model).allSatisfy { lineup($0) != nil })   // the plan starts from the import, not the game's date
        try t.importFirstTeam()

        let plans = plans(model)
        #expect(plans.map(\.id) == ids)
        #expect(plans[0].body == .missed)
        #expect(plans[0].tacticName == model.primaryTactic?.tactic.name)
        #expect(plans[0].missedNote == "This match is before the squad was last imported and no lineup was confirmed for "
            + "it, so it does not count towards runs of starts. Delete it, or correct its date, on the Fixtures screen.")
        #expect(lineup(plans[1])?.picks.count == 11)
        #expect(plans[1].missedNote == nil)

        // The missed match is not the next to play, is not played, and offers no one to choose.
        #expect(!model.canConfirm(ids[0]) && model.whyNotConfirm(ids[0]) == nil)
        model.confirm(ids[0])
        #expect(model.history.isEmpty)
        #expect(model.candidates(for: .GK, in: ids[0]).isEmpty)
        #expect(model.canConfirm(ids[1]))

        // Moving its date back on makes it a fixture to plan again.
        var fixture = model.fixtures[0]
        fixture.date = TestModel.today.adding(days: 3)
        model.update(fixture)
        #expect(self.plans(model).allSatisfy { lineup($0) != nil })
    }

    @Test func twoFixturesToPlanOnOneDayStopThePlanInTheOwnersWords() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 3, t)
        // A confirmed match is history, so a fixture to plan on its day is no clash.
        model.confirm(model.fixtures[0].id)
        model.addFixture(date: model.fixtures[0].date, opponent: "Opponent E", importance: .low)
        #expect(plans(model).count == 4)

        model.addFixture(date: TestModel.today.adding(days: 7), opponent: "Opponent F", importance: .low)
        let clash = model.addFixture(date: TestModel.today.adding(days: 4), opponent: "Opponent B", importance: .low)
        // The earliest such day, Tue 17 Nov, before Fri 20 Nov; its opponents in alphabetical order.
        #expect(model.planState == .failed(["Two matches are on Tue 17 Nov: against Opponent 2 and against Opponent B. "
            + "A club plays one match a day: change one of the dates on the Fixtures screen."]))
        model.deleteFixture(clash)
        #expect(model.planState == .failed(["Two matches are on Fri 20 Nov: against Opponent 3 and against Opponent F. "
            + "A club plays one match a day: change one of the dates on the Fixtures screen."]))
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
        let ratings = candidates.compactMap(\.rating)
        #expect(ratings.count == candidates.count)
        #expect(ratings == ratings.sorted(by: >))
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

    @Test func aPlayerWhoCannotBeRatedStaysLastWithTheEnginesSentence() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let players = Array(t.model.players.prefix(4))
        let unrated = players[1].name
        let candidates = AppModel.ranked(players, rating: { player in
            if player.name == unrated { throw RatingError.missingAttribute(player: player.name, attribute: .pace) }
            return Double(player.name.count)
        }, unavailable: { _ in nil })
        #expect(candidates.count == 4)
        #expect(candidates.last?.name == unrated)
        #expect(candidates.last?.rating == nil)
        #expect(candidates.last?.unavailable
            == ErrorDescriptions.describe(RatingError.missingAttribute(player: unrated, attribute: .pace)))
        #expect(candidates.dropLast().allSatisfy { $0.rating != nil && $0.unavailable == nil })
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
        let planned = model.timesPlanned
        model.moveToday(by: 1)
        #expect(model.planState == state && model.timesPlanned == planned)
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

    @Test func onlySettingsThePlanReadsReplan() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 1, t)
        let state = model.planState
        var count = model.timesPlanned

        model.moveToday(by: 1)
        var settings = model.settings
        settings.fmrteConfigPath = "/somewhere/else/config.json"
        settings.clubName = "  Oxford City "   // the same club once trimmed
        model.update(settings)
        #expect(model.timesPlanned == count)
        #expect(model.planState == state)

        for change in [{ (s: inout AppSettings) in s.plan.stability = 0.9 },
                       { $0.conditionFloor = 0.9 },
                       { $0.clubName = "Banbury United" },
                       { $0.primaryTacticID = UUID() }] {
            settings = model.settings
            change(&settings)
            model.update(settings)
            #expect(model.timesPlanned == count + 1)
            count = model.timesPlanned
        }
        #expect(model.planState == .needsTactic(["No tactic is the primary one. Make one primary on the Tactics screen."]))
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

    // MARK: A confirmed match before the next import

    @Test func confirmingAMatchKeepsItsLoadInLaterFixtures() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 2, t)
        let ids = model.fixtures.map(\.id)
        guard let first = lineup(plan(model, ids[0])) else { return }
        let before = fitness(plan(model, ids[1]))

        model.confirm(ids[0])
        #expect(model.history.first?.awaitingImport == [.firstTeam, .u21])
        let after = fitness(plan(model, ids[1]))
        #expect(first.picks.count == 11)
        for pick in first.picks {
            guard let was = before[pick.player], let now = after[pick.player] else {
                Issue.record("no fitness for \(pick.name)"); continue
            }
            #expect(abs(now.condition - was.condition) < 1e-9, "\(pick.name)")
            #expect(abs(now.sharpness - was.sharpness) < 1e-9, "\(pick.name)")
            #expect(abs(now.jadedness - was.jadedness) < 1e-9, "\(pick.name)")
            #expect(now.daysSinceMatch == was.daysSinceMatch, "\(pick.name)")
        }
    }

    @Test func importingASquadAgainStopsCountingTheMatchForThatSquadOnly() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 2, t)
        let ids = model.fixtures.map(\.id)
        // A U21 player fixed in the first match, so it has a starter from each squad.
        guard let youngster = model.candidates(for: .ST_C, in: ids[0]).first(where: { $0.squad == .u21 && $0.unavailable == nil }) else {
            Issue.record("no available U21 striker"); return
        }
        model.setOverride(youngster.player, at: .ST_C, in: ids[0])
        guard let first = lineup(plan(model, ids[0])),
              let senior = first.picks.first(where: { pick in model.players.first { $0.id == pick.player }?.squad == .firstTeam }) else {
            Issue.record("no first-team starter"); return
        }
        #expect(first.picks.contains { $0.player == youngster.player })
        model.confirm(ids[0])

        func rested(_ id: PlayerID) throws -> ProjectedFitness {
            let player = try #require(model.players.first { $0.id == id })
            return try FitnessProjection.afterDays(
                TestModel.today.days(to: model.fixtures[1].date), ProjectedFitness(player), player: player,
                intensity: model.settings.plan.trainingIntensity, parameters: model.planParameters)
        }
        let restedSenior = try rested(senior.player)
        let restedYoungster = try rested(youngster.player)
        #expect(try #require(fitness(plan(model, ids[1]))[senior.player]).condition < restedSenior.condition)

        try t.importFirstTeam()
        #expect(model.history.first?.awaitingImport == [.u21])
        #expect(t.reopened().history.first?.awaitingImport == [.u21])
        let afterFirstTeam = fitness(plan(model, ids[1]))
        #expect(afterFirstTeam[senior.player] == restedSenior)
        #expect(try #require(afterFirstTeam[youngster.player]).condition < restedYoungster.condition)
        #expect(model.fitnessNote != nil)

        try t.importU21()
        #expect(model.history.first?.awaitingImport == [])
        #expect(fitness(plan(model, ids[1]))[youngster.player] == restedYoungster)
        #expect(model.fitnessNote == nil)
    }

    @Test func unlockingRemovesTheLoadWithTheRecord() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 2, t)
        let ids = model.fixtures.map(\.id)
        let before = model.planState
        model.confirm(ids[0])
        #expect(model.fitnessNote != nil)
        model.unlock(ids[0])
        #expect(model.planState == before)
        #expect(model.fitnessNote == nil)
        // Confirmed again, the load comes back; deleting the fixture removes it with the record.
        model.confirm(ids[0])
        model.deleteFixture(ids[0])
        #expect(model.fitnessNote == nil)
        guard let second = plans(model).first else { return }
        #expect(fitness(second).values.allSatisfy { $0.daysSinceMatch == nil })
    }

    @Test func theNoteNamesTheMatchesAwaitingAnImport() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 3, t)
        let ids = model.fixtures.map(\.id)
        #expect(model.fitnessNote == nil)
        model.confirm(ids[0])
        #expect(model.fitnessNote == "The match against Opponent 1 was confirmed after the squad was last imported. Its "
            + "starters are counted as having played 90 minutes; import the squad again for their real fitness.")
        model.confirm(ids[1])
        #expect(model.fitnessNote == "The matches against Opponent 1 and Opponent 2 were confirmed after the squad was last "
            + "imported. Their starters are counted as having played 90 minutes; import the squad again for their real fitness.")
        try t.importFirstTeam()
        #expect(model.fitnessNote != nil)   // the U21 squad is still awaited
        try t.importU21()
        #expect(model.fitnessNote == nil)
        #expect(model.history.count == 2)
    }

    @Test func theNoteIsNilWithNothingAwaited() throws {
        // The sample's history was saved without anything awaited, as a file from before the field would be.
        let model = try sample()
        #expect(!model.history.isEmpty)
        #expect(model.history.allSatisfy { $0.awaitingImport.isEmpty })
        #expect(model.fitnessNote == nil)
    }

    @Test func awaitingImportSurvivesAReload() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 2, t)
        model.confirm(model.fixtures[0].id)
        let reopened = t.reopened()
        #expect(reopened.history == model.history)
        #expect(reopened.history.first?.awaitingImport == [.firstTeam, .u21])
        #expect(reopened.planState == model.planState)
        #expect(reopened.fitnessNote == model.fitnessNote)
    }

    @Test func aFixtureOnTheImportDayAfterAConfirmedMatchThereHasProjectedFitness() throws {
        let t = try TestModel()
        let model = try squad(fixtures: 0, t)
        let played = model.addFixture(date: TestModel.today, opponent: "Opponent A", importance: .medium)
        model.confirm(played)
        let replay = model.addFixture(date: TestModel.today, opponent: "Opponent B", importance: .medium)
        var settings = model.settings
        settings.conditionFloor = 0.99
        model.update(settings)
        guard let floored = lineup(plan(model, replay))?.omissions.first(where: isBelowTheFloor) else {
            Issue.record("nobody below the floor after the confirmed match"); return
        }
        #expect(model.history.first?.lineup.starters.values.contains(floored.player) == true)
        let candidate = model.candidates(for: floored.slot, in: replay).first { $0.player == floored.player }
        #expect(candidate?.unavailable.map { "Left out: " + $0 } == floored.reason)
        #expect(candidate?.unavailable?.hasPrefix("projected condition") == true)
    }
}
