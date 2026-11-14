import Foundation
import LineupEngine

extension AppModel {
    // MARK: The owner's choices

    /// Fixes `player` in `slot` for the fixture, replacing whoever was fixed there; nil clears the slot.
    public func setOverride(_ player: PlayerID?, at slot: SlotID, in fixture: FixtureID) {
        changeFixture(fixture) { $0.overrides[slot] = player }
    }

    /// Fixes `player` in `slot` for the fixture and returns the selection of that slot as now planned, so the detail
    /// shows whoever the plan put there: him, unless the engine could not use the choice.
    public func choose(_ player: PlayerID, at slot: SlotID, in fixture: FixtureID) -> PickSelection? {
        setOverride(player, at: slot, in: fixture)
        return selection(at: slot, in: fixture)
    }

    /// Clears the owner's choice for `slot` and returns the selection of whoever now holds the slot.
    public func clearChoice(at slot: SlotID, in fixture: FixtureID) -> PickSelection? {
        setOverride(nil, at: slot, in: fixture)
        return selection(at: slot, in: fixture)
    }

    /// The pick in `slot` of the fixture's planned lineup, as a selection; nil when there is none.
    func selection(at slot: SlotID, in fixture: FixtureID) -> PickSelection? {
        fixturePlans.first { $0.id == fixture }.flatMap { MatchPresentation.selection(at: slot, in: $0) }
    }

    /// Leaves the player out of this fixture only.
    public func reject(_ player: PlayerID, in fixture: FixtureID) {
        changeFixture(fixture) { $0.rejected.insert(player) }
    }

    /// Undoes `reject`.
    public func allow(_ player: PlayerID, in fixture: FixtureID) {
        changeFixture(fixture) { $0.rejected.remove(player) }
    }

    /// Whether `confirm` would record the fixture: it is the earliest fixture with a planned lineup, since confirming
    /// says the match has been played and matches are played in order; or it is missed and has a remembered eleven.
    public func canConfirm(_ fixture: FixtureID) -> Bool {
        nextToPlay?.id == fixture || rememberedEleven(fixture) != nil
    }

    /// Why a planned fixture cannot be confirmed yet; nil when it can be, or when it has no planned lineup.
    public func whyNotConfirm(_ fixture: FixtureID) -> String? {
        guard let plan = fixturePlans.first(where: { $0.id == fixture }), case .planned = plan.body,
              let next = nextToPlay, next.id != fixture else { return nil }
        return "Confirm the earlier match against \(next.fixture.opponent) first."
    }

    /// Records the fixture's planned lineup as played: the starters by slot, their names as the squad has them now,
    /// and the tactic's name, with every squad imported so far awaiting an import that includes the match. A missed
    /// fixture is confirmed as `confirmMissed` does. Nothing happens unless `canConfirm` allows it.
    public func confirm(_ fixture: FixtureID) {
        if rememberedEleven(fixture) != nil { return confirmMissed(fixture) }
        guard canConfirm(fixture), let plan = nextToPlay, case .planned(let lineup, _) = plan.body else { return }
        let starters = Dictionary(uniqueKeysWithValues: lineup.picks.map { ($0.slot, $0.player) })
        let names = Dictionary(uniqueKeysWithValues: lineup.picks.map { ($0.player, $0.name) })
        record(ConfirmedRecord(
            lineup: ConfirmedLineup(fixture: fixture, date: plan.fixture.date, starters: starters),
            names: names, tacticName: plan.tacticName, awaitingImport: Set(squad.importedOn.keys)))
    }

    /// Records a missed fixture's remembered eleven as played. A squad imported up to the match day still awaits an
    /// import that includes it, since an import on the day counts as made before kick-off, as `confirm` counts it; one
    /// imported since already has its load. Nothing happens unless the fixture is missed and has a remembered eleven.
    public func confirmMissed(_ fixture: FixtureID) {
        guard let eleven = rememberedEleven(fixture), let stored = fixtures.first(where: { $0.id == fixture }) else { return }
        let awaiting = squad.importedOn.filter { $0.value <= stored.date }.keys
        record(ConfirmedRecord(
            lineup: ConfirmedLineup(fixture: fixture, date: stored.date, starters: eleven.starters),
            names: eleven.names, tacticName: eleven.tacticName, awaitingImport: Set(awaiting)))
    }

    /// Adds the record, moves the game's current date up to the match's when it is earlier, since a match confirmed
    /// as played means the game has reached its day, and replans.
    private func record(_ record: ConfirmedRecord) {
        history.append(record)
        save(.history)
        if settings.currentDate < record.lineup.date {
            settings.currentDate = record.lineup.date
            save(.settings)
        }
        replan()
    }

    /// Removes the fixture's confirmed lineup, keeping its eleven as the fixture's last planned one. A fixture from the
    /// plan's starting day on is planned again with its saved choices; an earlier one shows as missed with that eleven.
    public func unlock(_ fixture: FixtureID) {
        guard let record = history.first(where: { $0.lineup.fixture == fixture }) else { return }
        if let index = fixtures.firstIndex(where: { $0.id == fixture }) {
            fixtures[index].lastPlanned = PlannedEleven(starters: record.lineup.starters, names: record.names,
                                                        tacticName: record.tacticName)
            save(.fixtures)
        }
        history.removeAll { $0.lineup.fixture == fixture }
        save(.history)
        replan()
    }

    /// What unlocking the fixture's lineup will do, as the question that asks for it.
    public func unlockNote(for fixture: FixtureID) -> String {
        let date = fixtures.first { $0.id == fixture }?.date ?? history.first { $0.lineup.fixture == fixture }?.lineup.date
        if let date, let start = planStartDay, date < start {
            return "Unlock this lineup? The squad has been imported since this match, so it cannot be planned again. "
                + "You can change who started and confirm it again."
        }
        return "Unlock this lineup? The match will be planned again."
    }

    // MARK: A missed fixture's remembered eleven

    /// The remembered eleven of a missed fixture; nil for any other fixture, or a missed one with none. Worked out from
    /// the saved fixtures, not the plan, so it is there whether or not the plan could be made.
    private func rememberedEleven(_ fixture: FixtureID) -> PlannedEleven? {
        guard let stored = fixtures.first(where: { $0.id == fixture }), isMissed(stored) else { return nil }
        return stored.lastPlanned
    }

    /// Before the plan's starting day with no confirmed lineup: as `workedOutPlan` shows it.
    private func isMissed(_ fixture: StoredFixture) -> Bool {
        guard let start = planStartDay else { return false }
        return fixture.date < start && !history.contains { $0.lineup.fixture == fixture.id }
    }

    /// The fixtures Match Selection shows: the plan's when it is ready; otherwise the missed fixtures, whose remembered
    /// elevens need no planner and can still be put right and confirmed.
    public var shownPlans: [FixturePlan] {
        if case .ready(let plans) = planState { return plans }
        return fixtures.filter(isMissed).map(missedPlan)
    }

    /// The players not out on loan.
    private var playersNotOnLoan: [Player] {
        let club = ownClub
        return squad.book.allPlayers.filter {
            if case .loanedOut = LoanStatus.of($0, ownClub: club) { false } else { true }
        }
    }

    /// Puts a squad player not out on loan in `slot` of a missed fixture's remembered eleven. If he is already in it at
    /// another slot, he and the one in `slot` swap; otherwise the one in `slot` leaves the eleven. Nothing happens for
    /// any other player or fixture.
    public func setRemembered(_ player: PlayerID, at slot: SlotID, in fixture: FixtureID) {
        guard var eleven = rememberedEleven(fixture),
              let chosen = playersNotOnLoan.first(where: { $0.id == player }),
              let index = fixtures.firstIndex(where: { $0.id == fixture }) else { return }
        let replaced = eleven.starters[slot]
        if let from = SlotID.allCases.first(where: { $0 != slot && eleven.starters[$0] == player }) {
            eleven.starters[from] = replaced
        } else if let replaced {
            eleven.names[replaced] = nil
        }
        eleven.starters[slot] = player
        if eleven.names[player] == nil { eleven.names[player] = chosen.name }
        guard eleven != fixtures[index].lastPlanned else { return }
        fixtures[index].lastPlanned = eleven
        save(.fixtures)
        // A missed fixture is not planned, so only its own entry in the plan changes.
        if case .ready(let plans) = planState {
            planState = .ready(plans.map { $0.id == fixture ? missedPlan(fixtures[index]) : $0 })
        }
    }

    /// Everyone who could have started in `slot` of a missed fixture's remembered eleven: every squad player not out on
    /// loan, those already in the eleven last, each group by name, then key. Empty for any other fixture.
    public func rememberedCandidates(for slot: SlotID, in fixture: FixtureID) -> [Candidate] {
        guard let eleven = rememberedEleven(fixture) else { return [] }
        let inEleven = Set(eleven.starters.values)
        let byName = playersNotOnLoan.sorted { ($0.name, $0.id.key) < ($1.name, $1.id.key) }
        func candidate(_ player: Player) -> Candidate {
            Candidate(player: player.id, name: player.name, squad: player.squad, rating: nil, unavailable: nil)
        }
        return byName.filter { !inEleven.contains($0.id) }.map(candidate)
            + byName.filter { inEleven.contains($0.id) }.map(candidate)
    }

    /// Every player not out on loan, with his full-fitness rating in the slot for the fixture's tactic, those who can
    /// play first, best first (see `ranked`), and why he cannot play in that fixture if he cannot: the engine's rule,
    /// judged on the fitness the plan projects for that day, worded as the selector words it. A player who cannot be
    /// rated comes last, with the engine's sentence for why. Empty when the fixture has no planned lineup or its tactic has no such slot.
    public func candidates(for slot: SlotID, in fixture: FixtureID) -> [Candidate] {
        let planned = fixturePlans.compactMap { plan -> (FixturePlan, [PlayerID: ProjectedFitness])? in
            if case .planned(_, let fitness) = plan.body { (plan, fitness) } else { nil }
        }
        guard let index = planned.firstIndex(where: { $0.0.id == fixture }),
              let tactic = tactic(for: planned[index].0.fixture)?.tactic else { return [] }
        let assignments: [SlotAssignment]
        do {
            assignments = try tactic.assignments(catalog: catalog)
        } catch {
            return []   // not reached: the fixture was just planned with this tactic
        }
        guard let assignment = assignments.first(where: { $0.slot == slot }) else { return [] }
        let (plan, fitness) = planned[index]
        let parameters = planParameters
        let projected = plan.fitnessIsProjected
        let club = ownClub
        let players = squad.book.allPlayers.filter {
            if case .loanedOut = LoanStatus.of($0, ownClub: club) { false } else { true }
        }
        let engine = RatingEngine(profile: profile, parameters: parameters, configuration: .fm27)
        return Self.ranked(players, rating: { try engine.rating(for: $0, in: assignment).value }) { player in
            let onTheDay = fitness[player.id].map { Planner.withFitness(player, $0) } ?? player
            let exclusion = RiskRules.exclusion(
                for: onTheDay, loan: LoanStatus.of(player, ownClub: club), importance: plan.fixture.importance,
                isNextFixture: index == 0, parameters: parameters)
                ?? (plan.fixture.rejected.contains(player.id) ? .rejected : nil)
            return exclusion.map { ErrorDescriptions.describe($0, parameters: parameters, projected: projected) }
        }
    }

    /// The players as candidates: those who can play, best first; then those who cannot, best first; each group then by
    /// name and key. Last, those who cannot be rated, by name and key, with the engine's sentence for the failure in
    /// place of any other reason.
    static func ranked(_ players: [Player], rating: (Player) throws -> Double,
                       unavailable: (Player) -> String?) -> [Candidate] {
        var rated: [Candidate] = []
        var unrated: [Candidate] = []
        for player in players {
            do {
                rated.append(Candidate(player: player.id, name: player.name, squad: player.squad,
                                       rating: try rating(player), unavailable: unavailable(player)))
            } catch {
                unrated.append(Candidate(player: player.id, name: player.name, squad: player.squad,
                                         rating: nil, unavailable: ErrorDescriptions.describe(error)))
            }
        }
        func bestFirst(_ candidates: [Candidate]) -> [Candidate] {
            candidates.sorted { ($1.rating ?? 0, $0.name, $0.player.key) < ($0.rating ?? 0, $1.name, $1.player.key) }
        }
        return bestFirst(rated.filter { $0.unavailable == nil }) + bestFirst(rated.filter { $0.unavailable != nil })
            + unrated.sorted { ($0.name, $0.player.key) < ($1.name, $1.player.key) }
    }

    // MARK: Working the plan out

    /// The plan for the saved state. Missing things come first, in the order Match Selection asks for them: a squad,
    /// a usable tactic for every fixture within the horizon, then fixtures. Then two fixtures to plan on one day, then
    /// the planner. Unconfirmed fixtures before the plan's starting day are not planned: they are shown as missed.
    func workedOutPlan() -> PlanState {
        let players = squad.book.allPlayers
        guard !players.isEmpty, let asOf = planStartDay else { return .needsSquad }
        if tactics.isEmpty { return .needsTactic([]) }
        let confirmed = Dictionary(history.map { ($0.lineup.fixture, $0) }, uniquingKeysWith: { first, _ in first })
        let toPlan = fixtures.filter { confirmed[$0.id] == nil && $0.date >= asOf }
        // `fixtures` is in the planner's order, date then id, so these are the fixtures it plans.
        let withinReach = Array(toPlan.prefix(max(0, settings.plan.horizon)))
        let tacticProblems = unusableTactics(withinReach)
        if !tacticProblems.isEmpty { return .needsTactic(tacticProblems) }
        if fixtures.isEmpty { return .needsFixtures }
        if let clash = Self.sameDayProblem(toPlan) { return .failed([clash], fix: .fixtures) }

        let parameters = planParameters
        let request = PlanRequest(
            fixtures: withinReach.compactMap(fixtureForPlanner),   // every one has a tactic: checked above
            players: players, ownClub: ownClub, asOf: asOf, confirmed: history.map(\.lineup),
            played: countedSinceImport(players).map(\.lineup), retraining: retrainingForPlan, settings: settings.plan)
        let plan: Plan
        do {
            plan = try Planner(catalog: catalog, profile: profile, parameters: parameters).plan(request)
        } catch {
            // The checks before this leave the planner only the settings and the parameters to refuse.
            return .failed([ErrorDescriptions.describe(error)], fix: .settings)
        }

        let names = Dictionary(players.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let planned = Dictionary(uniqueKeysWithValues: plan.fixtures.map { ($0.fixture, $0) })
        let result = fixtures.compactMap { fixture -> FixturePlan? in
            if let record = confirmed[fixture.id] {
                return FixturePlan(fixture: fixture, tacticName: record.tacticName, usesPrimaryBecauseItsTacticWasDeleted: false,
                                   body: .confirmed(record), fitnessIsProjected: false, ignoredOverrides: [])
            }
            if fixture.date < asOf { return missedPlan(fixture) }
            let tacticName = tactic(for: fixture)?.tactic.name ?? ""
            let tacticGone = fixture.tacticID.map { id in !tactics.contains { $0.id == id } } ?? false
            guard let item = planned[fixture.id] else { return nil }
            let projected = item.fitnessIsProjected
            let ignored = SlotID.allCases.compactMap { slot in
                item.lineup.ignoredOverrides[slot].map { problem in
                    if let chosen = fixture.overrides[slot], let name = names[chosen] {
                        IgnoredOverride(slot: slot, sentence: "\(name) at \(slot.longName): "
                            + ErrorDescriptions.describe(problem, parameters: parameters, projected: projected) + ".")
                    } else {
                        IgnoredOverride(slot: slot, sentence: "The player chosen for \(slot.longName) is no longer in the squads.")
                    }
                }
            }
            return FixturePlan(fixture: fixture, tacticName: tacticName, usesPrimaryBecauseItsTacticWasDeleted: tacticGone,
                               body: .planned(item.lineup, fitness: item.fitness), fitnessIsProjected: projected,
                               ignoredOverrides: ignored)
        }
        return .ready(result)
    }

    /// The saved fixture as the planner is handed it, with its tactic resolved; nil when it has no tactic to use.
    func fixtureForPlanner(_ fixture: StoredFixture) -> Fixture? {
        tactic(for: fixture).map { stored in
            Fixture(id: fixture.id, date: fixture.date, opponent: fixture.opponent, importance: fixture.importance,
                    tactic: stored.tactic, overrides: fixture.overrides, rejected: fixture.rejected,
                    competition: fixture.competition, opponentStrength: fixture.opponentStrength)
        }
    }

    /// A fixture before the plan's starting day with no confirmed lineup, with its remembered eleven if it has one.
    func missedPlan(_ fixture: StoredFixture) -> FixturePlan {
        let tacticName = fixture.lastPlanned?.tacticName ?? tactic(for: fixture)?.tactic.name ?? ""
        let tacticGone = fixture.lastPlanned == nil
            && (fixture.tacticID.map { id in !tactics.contains { $0.id == id } } ?? false)
        return FixturePlan(fixture: fixture, tacticName: tacticName, usesPrimaryBecauseItsTacticWasDeleted: tacticGone,
                           body: .missed(fixture.lastPlanned), fitnessIsProjected: false, ignoredOverrides: [])
    }

    /// Writes each planned lineup's eleven into its fixture's `lastPlanned`, saving the fixtures once if any changed,
    /// and returns the plan with the fixtures as saved.
    func rememberingElevens(_ state: PlanState) -> PlanState {
        guard case .ready(let plans) = state else { return state }
        var changed = false
        for plan in plans {
            guard case .planned(let lineup, _) = plan.body, let index = fixtures.firstIndex(where: { $0.id == plan.id })
            else { continue }
            let eleven = PlannedEleven(
                starters: Dictionary(uniqueKeysWithValues: lineup.picks.map { ($0.slot, $0.player) }),
                names: Dictionary(uniqueKeysWithValues: lineup.picks.map { ($0.player, $0.name) }),
                tacticName: plan.tacticName)
            if fixtures[index].lastPlanned != eleven {
                fixtures[index].lastPlanned = eleven
                changed = true
            }
        }
        guard changed else { return state }
        save(.fixtures)
        let saved = Dictionary(uniqueKeysWithValues: fixtures.map { ($0.id, $0) })
        return .ready(plans.map { plan in
            guard let fixture = saved[plan.id], fixture != plan.fixture else { return plan }
            return FixturePlan(fixture: fixture, tacticName: plan.tacticName,
                               usesPrimaryBecauseItsTacticWasDeleted: plan.usesPrimaryBecauseItsTacticWasDeleted,
                               body: plan.body, fitnessIsProjected: plan.fitnessIsProjected,
                               ignoredOverrides: plan.ignoredOverrides)
        })
    }

    /// A confirmed match whose load the imported fitness does not include, as the planner is handed it.
    private struct CountedMatch {
        let record: ConfirmedRecord
        /// The record's lineup with only the counted starters.
        let lineup: ConfirmedLineup
        /// The squads those starters are in now.
        let squads: Set<Squad>
    }

    /// Each record still awaiting an import, with its starters cut down to those in `players` whose squad it awaits. A
    /// record left with no starters is dropped, since it changes nobody's fitness. In history order.
    private func countedSinceImport(_ players: [Player]) -> [CountedMatch] {
        let squadOf = Dictionary(players.map { ($0.id, $0.squad) }, uniquingKeysWith: { first, _ in first })
        return history.compactMap { record in
            guard !record.awaitingImport.isEmpty else { return nil }
            var lineup = record.lineup
            lineup.starters = lineup.starters.filter { _, player in
                squadOf[player].map(record.awaitingImport.contains) ?? false
            }
            guard !lineup.starters.isEmpty else { return nil }
            return CountedMatch(record: record, lineup: lineup, squads: Set(lineup.starters.values.compactMap { squadOf[$0] }))
        }
    }

    /// While the plan counts confirmed matches the imported fitness does not include: which ones, by opponent in date
    /// order, and which squads to import again, those of their counted starters. Nil when it counts none.
    public var fitnessNote: String? {
        let counted = countedSinceImport(squad.book.allPlayers)
            .sorted { ($0.lineup.date, $0.lineup.fixture.raw) < ($1.lineup.date, $1.lineup.fixture.raw) }
        guard !counted.isEmpty else { return nil }
        let opponents = counted.map { match in
            fixtures.first { $0.id == match.lineup.fixture }?.opponent
                ?? "an opponent on \(DayText.short(match.lineup.date))"
        }
        let awaited = Squad.allCases.filter { squad in counted.contains { $0.squads.contains(squad) } }
        let squads = awaited.map(\.inSentence)
        let matches = opponents.count == 1
            ? "The match against \(opponents[0]) was"
            : "The matches against \(Self.listed(opponents)) were"
        let starters = opponents.count == 1 ? "Its starters" : "Their starters"
        let imported = squads.count == 1
            ? "\(squads[0]) \(awaited == [.firstTeam] ? "was" : "were") last imported. \(starters) from that squad are counted as having played 90 minutes; "
                + "import \(squads[0]) again"
            : "\(Self.listed(squads)) were last imported. \(starters) from those squads are counted as having played 90 "
                + "minutes; import them again"
        return "\(matches) confirmed after \(imported) for their real fitness."
    }

    /// "A", "A and B", "A, B and C".
    private static func listed(_ items: [String]) -> String {
        guard items.count > 1 else { return items.first ?? "" }
        return items.dropLast().joined(separator: ", ") + " and " + items.last!
    }

    /// One sentence per tactic the fixtures would be planned with that cannot be used, in the order the fixtures
    /// first use them.
    private func unusableTactics(_ fixtures: [StoredFixture]) -> [String] {
        var found: [String] = []
        var seen = Set<UUID>()
        for fixture in fixtures {
            guard let stored = tactic(for: fixture) else {
                if !found.contains(Self.noPrimaryTactic) { found.append(Self.noPrimaryTactic) }
                continue
            }
            guard seen.insert(stored.id).inserted else { continue }
            if let sentence = unusableSentence(stored.tactic) { found.append(sentence) }
        }
        return found
    }

    nonisolated static let noPrimaryTactic = "No tactic is the primary one. Make one primary on the Tactics screen."

    /// "<name> cannot be used: <the engine's problems>."; nil when the engine accepts the tactic.
    func unusableSentence(_ tactic: Tactic) -> String? {
        let problems = problems(of: tactic)
        return problems.isEmpty ? nil : "\(tactic.name) cannot be used: \(problems.joined(separator: "; "))."
    }

    /// The earliest day with more than one of the fixtures, in words, its opponents in alphabetical order; nil when every
    /// fixture has a day of its own.
    /// The app says this itself because the engine's sentence names the fixtures by their ids.
    static func sameDayProblem(_ fixtures: [StoredFixture]) -> String? {
        let byDay = Dictionary(grouping: fixtures, by: \.date)
        guard let day = byDay.filter({ $0.value.count > 1 }).keys.min(), let matches = byDay[day] else { return nil }
        let counts = [2: "Two", 3: "Three", 4: "Four", 5: "Five"]
        let against = matches.sorted { ($0.opponent, $0.id.raw) < ($1.opponent, $1.id.raw) }.map { "against \($0.opponent)" }
        let listed = against.dropLast().joined(separator: ", ") + " and " + against.last!
        return "\(counts[matches.count] ?? "\(matches.count)") matches are on \(DayText.short(day)): \(listed). "
            + "A club plays one match a day: change one of the dates on the Fixtures screen."
    }

    /// The day the plan starts from: the latest day a squad was imported.
    var planStartDay: Day? {
        squad.importedOn.values.max()
    }

    /// The engine's parameters, with the owner's condition floor when one is set.
    var planParameters: EngineParameters {
        var parameters = EngineParameters.fm27
        if let floor = settings.conditionFloor {
            parameters.conditionFloor = Parameter(floor, .derived, source: "the owner's setting in the app")
        }
        return parameters
    }

    /// The fixtures in the plan, or none when there is no plan.
    var fixturePlans: [FixturePlan] {
        if case .ready(let plans) = planState { plans } else { [] }
    }

    /// The earliest fixture with a planned lineup.
    private var nextToPlay: FixturePlan? {
        fixturePlans.first { if case .planned = $0.body { true } else { false } }
    }

    /// Changes the saved fixture, saves the fixtures and replans; nothing happens if the change leaves it as it was.
    private func changeFixture(_ id: FixtureID, _ change: (inout StoredFixture) -> Void) {
        guard let index = fixtures.firstIndex(where: { $0.id == id }) else { return }
        var fixture = fixtures[index]
        change(&fixture)
        guard fixture != fixtures[index] else { return }
        fixtures[index] = fixture
        save(.fixtures)
        replan()
    }
}
