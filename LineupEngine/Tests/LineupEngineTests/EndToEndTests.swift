import Foundation
import Testing
@testable import LineupEngine

@Suite struct EndToEndTests {
    /// The first-team and U21 captures taken without the Id column.
    private func realBook() throws -> SquadBook {
        var book = SquadBook()
        let grids = try Fixtures.data("captures/first-team.grids.json")
        book.apply(try Importer.importPlayers(clipboard: Fixtures.text("captures/first-team.tsv"), fmrteConfig: grids, squad: .firstTeam), to: .firstTeam)
        book.apply(try Importer.importPlayers(clipboard: Fixtures.text("captures/u21.tsv"),
                                              fmrteConfig: Fixtures.data("captures/u21.grids.json"), squad: .u21), to: .u21)
        return book
    }

    /// The first-team capture is from the team grid, which has no club column, so the club is named.
    private let ownClubName = "Oxford City"

    /// The real squads selected for the sample tactic under `profile`.
    private func realLineup(_ profile: RatingProfile) throws -> (lineup: Lineup, book: SquadBook) {
        let book = try realBook()
        let ownClub = book.ownClub(override: ownClubName)
        let tactic = try JSONDecoder().decode(Tactic.self, from: Fixtures.data("tactics/sample-4231.json"))
        let selector = LineupSelector(catalog: try .fm27(), profile: profile, parameters: .fm27)
        let lineup = try selector.select(.init(tactic: tactic, players: book.allPlayers, ownClub: ownClub,
                                               importance: .high, isNextFixture: true, overrides: [:], rejected: []))
        return (lineup, book)
    }

    private func expectSound(_ lineup: Lineup, _ book: SquadBook, sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(lineup.picks.count + lineup.unfilled.count == 11, sourceLocation: sourceLocation)
        #expect(Set(lineup.picks.map(\.player)).count == lineup.picks.count, sourceLocation: sourceLocation)
        let names = Set(lineup.picks.map(\.name))
        #expect(!names.contains("Max Treml"), sourceLocation: sourceLocation)                // out on loan
        for p in book.allPlayers {
            if case .loanedOut = book.loanStatus(of: p, override: ownClubName) { #expect(!names.contains(p.name), sourceLocation: sourceLocation) }
        }
        for p in book.allPlayers where p.isInjured { #expect(!names.contains(p.name), sourceLocation: sourceLocation) }
        #expect(lineup.picks.allSatisfy { !$0.reasons.isEmpty }, sourceLocation: sourceLocation)
        // Both goalkeepers are unavailable (Maxted injured, Treml on loan), so an outfield player stands in.
        let keeper = lineup.picks.first { $0.slot == .GK }
        #expect(keeper?.warnings.contains { if case .outOfPosition(.inPossession, _) = $0 { true } else { false } } == true,
                sourceLocation: sourceLocation)
    }

    @Test func realSquadsProduceAFullExplainedLineupUnderTheCarriedOverProfile() throws {
        let (lineup, book) = try realLineup(try RatingProfile.carriedOver())
        expectSound(lineup, book)
        // Three picks pinned from the real data, without role thresholds. With them, Taylor (Acceleration and Pace 8)
        // fell to the 0.80 floor as a Channel Forward, Marsh led the line and Taylor went in goal. Without them Taylor
        // rates 90.7 up front to Marsh's 89.7, so he leads the line. The stand-in goalkeeper is a near tie between
        // outfielders, so it is not pinned; `expectSound` checks that he is flagged out of position.
        let bySlot = Dictionary(uniqueKeysWithValues: lineup.picks.map { ($0.slot, $0.name) })
        #expect(bySlot[.AM_C] == "Zac McEachran")
        #expect(bySlot[.D_L] == "Evan Humphries")
        #expect(bySlot[.ST_C] == "Matty Taylor")
    }

    @Test func realSquadsProduceAFullExplainedLineupUnderTheFM27Profile() throws {
        let (lineup, book) = try realLineup(try RatingProfile.standard())
        expectSound(lineup, book)
        // Three picks pinned from the real data, each with a clear margin under the FM26 positional emphasis.
        // Pace and Acceleration weigh heavily here, so the quicker Marsh (12 and 12) leads the line over Taylor
        // (8 and 8): match-day value 95.0 to 89.0. McEachran keeps AM_C: moving Marsh there and Taylor up front
        // would total 5.7 less. Humphries, the natural left back, leads D_L clearly (86.0 to Nelson's 74.0).
        // The stand-in goalkeeper is a near tie, so it is not pinned.
        let bySlot = Dictionary(uniqueKeysWithValues: lineup.picks.map { ($0.slot, $0.name) })
        #expect(bySlot[.AM_C] == "Zac McEachran")
        #expect(bySlot[.ST_C] == "Tyrone Marsh")
        #expect(bySlot[.D_L] == "Evan Humphries")
    }

    /// One entry of a fixtures file, in the shape the command-line tool reads.
    private struct FixtureEntry: Decodable {
        let id: FixtureID
        let date: Day
        let opponent: String
        let importance: Importance
        let overrides: [SlotID: PlayerID]?
        let rejected: [PlayerID]?
        let competition: Competition?
        let opponentStrength: OpponentStrength?
    }

    /// The sample fixtures, each with the sample tactic, and the sample history, planned for the real squads as of
    /// 2026-11-13 under the FM27 profile.
    private func realPlan(savingPlayers: Double) throws -> (plan: Plan, fixtures: [Fixture], book: SquadBook) {
        let book = try realBook()
        let tactic = try JSONDecoder().decode(Tactic.self, from: Fixtures.data("tactics/sample-4231.json"))
        let entries = try JSONDecoder().decode([FixtureEntry].self, from: Fixtures.data("plans/sample-fixtures.json"))
        let fixtures = entries.map {
            Fixture(id: $0.id, date: $0.date, opponent: $0.opponent, importance: $0.importance, tactic: tactic,
                    overrides: $0.overrides ?? [:], rejected: Set($0.rejected ?? []))
        }
        let history = try JSONDecoder().decode([ConfirmedLineup].self, from: Fixtures.data("plans/sample-history.json"))
        let planner = Planner(catalog: try .fm27(), profile: try RatingProfile.standard(), parameters: .fm27)
        let plan = try planner.plan(PlanRequest(
            fixtures: fixtures, players: book.allPlayers, ownClub: book.ownClub(override: ownClubName),
            asOf: try #require(Day(iso: "2026-11-13")), confirmed: history, retraining: [],
            settings: PlanSettings(savingPlayers: savingPlayers)))
        return (plan, fixtures, book)
    }

    @Test func theRealSquadPlansFiveFixtures() throws {
        let (plan, fixtures, book) = try realPlan(savingPlayers: 1)
        let ordered = fixtures.sorted { $0.date < $1.date }
        #expect(ordered.count == 5)
        #expect(plan.fixtures.map(\.fixture) == ordered.map(\.id))
        for planned in plan.fixtures { expectSound(planned.lineup, book) }

        // The history names real players of the first-team capture.
        let history = try JSONDecoder().decode([ConfirmedLineup].self, from: Fixtures.data("plans/sample-history.json"))
        let firstTeam = Set(book.allPlayers.filter { $0.squad == .firstTeam }.map(\.id))
        for lineup in history { #expect(lineup.starters.count == 11 && Set(lineup.starters.values).isSubset(of: firstTeam)) }

        let high = try #require(ordered.firstIndex { $0.importance == .high })
        let strength = plan.fixtures.map { $0.lineup.picks.reduce(0.0) { $0 + $1.rating.value } }
        for (index, total) in strength.enumerated() {
            #expect(strength[high] >= total, "\(ordered[index].id.raw) totals \(total), more than the high fixture's \(strength[high])")
        }

        // Saving players changes no pick before the high fixture on this squad. There must be a fixture before it, or the
        // loops below check nothing.
        #expect(high > 0)
        let unsaved = try realPlan(savingPlayers: 0).plan
        func picks(_ plan: Plan, _ index: Int) -> [SlotID: PlayerID] {
            Dictionary(uniqueKeysWithValues: plan.fixtures[index].lineup.picks.map { ($0.slot, $0.player) })
        }
        for index in 0..<high { #expect(picks(plan, index) == picks(unsaved, index), "\(ordered[index].id.raw)") }

        // Why: the first team is at 49 to 59% sharpness, the U21 players at 69 to 73%. Before the high fixture, for every player in the first eleven
        // (the same for every fixture: one tactic), in any slot, starting gains more sharpness by each later fixture that
        // weighs more than today than it costs in condition, so he is fitter there than if he rested. Saving him would
        // lose nothing, so no saving cost is put on anyone, and the plans are the same.
        let parameters = EngineParameters.fm27
        let catalog = try RoleCatalog.fm27()
        let intensity = PlanSettings.standard.trainingIntensity
        let tiers = try SquadTiers.compute(tactic: ordered[high].tactic, players: book.allPlayers,
                                           ownClub: book.ownClub(override: ownClubName), catalog: catalog,
                                           profile: try RatingProfile.standard(), parameters: parameters)
        let assignments = try ordered[high].tactic.assignments(catalog: catalog)
        let byID = Dictionary(uniqueKeysWithValues: book.allPlayers.map { ($0.id, $0) })
        let weights = parameters.importanceWeights.value
        func product(_ f: ProjectedFitness) -> Double {
            FitnessModel.factors(condition: f.condition, sharpness: f.sharpness, jadedness: Int(f.jadedness.rounded()),
                                 parameters: parameters).product
        }
        for index in 0..<high {
            let fixture = ordered[index]
            let later = ordered[(index + 1)...]
            for heavier in later where weights[heavier.importance]! > weights[fixture.importance]! {
                let gap = fixture.date.days(to: heavier.date)
                for id in tiers.first.values.sorted(by: { $0.key < $1.key }) {
                    let player = try #require(byID[id])
                    let today = try #require(plan.fixtures[index].fitness[id])
                    let rest = try FitnessProjection.afterDays(gap, today, player: player, intensity: intensity, parameters: parameters)
                    for assignment in assignments {
                        let played = try FitnessProjection.afterMatch(today, player: player, position: assignment.ipPosition,
                                                                      parameters: parameters)
                        let play = try FitnessProjection.afterDays(gap, played, player: player, intensity: intensity,
                                                                   parameters: parameters)
                        #expect(product(play) > product(rest),
                                "\(player.name) at \(assignment.slot.rawValue) in \(fixture.id.raw), for \(heavier.id.raw)")
                    }
                }
            }
            for player in book.allPlayers.sorted(by: { $0.id.key < $1.id.key }) {
                let today = try #require(plan.fixtures[index].fitness[player.id])
                for assignment in assignments {
                    let cost = try SavingPlayers.adjustment(
                        for: player, fitness: today, position: assignment.ipPosition, today: fixture,
                        later: later.map { LaterFixture(fixture: $0, tiers: tiers) }, settings: .standard, parameters: parameters)
                    #expect(cost == nil, "\(player.name) at \(assignment.slot.rawValue) in \(fixture.id.raw)")
                }
            }
        }
    }

    @Test func aRunOfStartsFollowsThePlayerInTheRealPlan() throws {
        let (plan, fixtures, _) = try realPlan(savingPlayers: 1)
        let ordered = fixtures.sorted { $0.date < $1.date }
        let parameters = EngineParameters.fm27
        var history = StartHistory(try JSONDecoder().decode([ConfirmedLineup].self, from: Fixtures.data("plans/sample-history.json")))
        var checked = 0
        for (fixture, planned) in zip(ordered, plan.fixtures) {
            // A player whose run carries a factor at the slot of his last start carries at least that factor wherever he starts.
            for pick in planned.lineup.picks where fixture.importance != .high {
                let run = history.consecutiveStarts(of: pick.player, before: fixture.date,
                                                    windowDays: parameters.consecutiveStartWindowDays.value)
                guard let usual = history.recentSlots(of: pick.player, before: fixture.date, limit: 1).first,
                      let step = parameters.consecutiveStartSteps.value[usual.position]?
                          .filter({ $0.starts <= run }).max(by: { $0.starts < $1.starts }),
                      step.factor < 1 else { continue }
                checked += 1
                let factor = pick.adjustments.first { $0.kind == .consecutiveStarts }?.factor
                #expect(factor.map { $0 <= step.factor } == true,
                        "\(pick.name) at \(pick.slot.rawValue) in \(fixture.id.raw), after \(run) starts, last at \(usual.rawValue)")
            }
            history = history.adding(ConfirmedLineup(
                fixture: fixture.id, date: fixture.date,
                starters: Dictionary(uniqueKeysWithValues: planned.lineup.picks.map { ($0.slot, $0.player) })))
        }
        #expect(checked > 0)
    }

    @Test func theRegularAttackingMidfielderIsPickedOrToldWhyInTheRealPlan() throws {
        let (plan, fixtures, book) = try realPlan(savingPlayers: 1)
        let day = try #require(Day(iso: "2026-11-24"))
        let index = try #require(fixtures.sorted { $0.date < $1.date }.firstIndex { $0.date == day })
        let lineup = plan.fixtures[index].lineup
        let zac = try #require(book.allPlayers.first { $0.name == "Zac McEachran" }).id
        let picked = lineup.picks.contains { $0.player == zac }
        let omission = lineup.omissions.first { $0.player == zac }
        #expect(picked || omission.map { $0.reason.hasPrefix("Left out: ") && $0.reason.count > "Left out: ".count } == true)
    }

    @Test(arguments: ["carried-over", "fm27-engine-tests"])
    func thePostMatchSnapshotFieldsWhoItCan(_ profileID: String) throws {
        var book = SquadBook()
        let firstTeam = try Importer.importPlayers(clipboard: Fixtures.text("captures/first-team-with-id.tsv"),
                                                   fmrteConfig: Fixtures.data("captures/first-team-with-id.grids.json"), squad: .firstTeam)
        let u21 = try Importer.importPlayers(clipboard: Fixtures.text("captures/u21-with-id.tsv"),
                                             fmrteConfig: Fixtures.data("captures/u21-with-id.grids.json"), squad: .u21)
        book.apply(firstTeam, to: .firstTeam)
        book.apply(u21, to: .u21)
        #expect(!(firstTeam.warnings + u21.warnings).contains(.identifiedByName))
        #expect(book.allPlayers.count == 24)

        let ownClub = book.ownClub(override: "Oxford City")
        let tactic = try JSONDecoder().decode(Tactic.self, from: Fixtures.data("tactics/sample-4231.json"))
        let parameters = EngineParameters.fm27
        let profile = try #require(try RatingProfile.all().first { $0.id == profileID })
        let selector = LineupSelector(catalog: try .fm27(), profile: profile, parameters: parameters)
        let lineup = try selector.select(.init(tactic: tactic, players: book.allPlayers, ownClub: ownClub,
                                               importance: .high, isNextFixture: true, overrides: [:], rejected: []))

        #expect(lineup.picks.count + lineup.unfilled.count == 11)
        #expect(Set(lineup.picks.map(\.player)).count == lineup.picks.count)
        #expect(lineup.picks.allSatisfy { $0.player.key.hasPrefix("fmrte:") })
        let byID = Dictionary(uniqueKeysWithValues: book.allPlayers.map { ($0.id, $0) })
        for pick in lineup.picks {
            let player = try #require(byID[pick.player])
            #expect(!player.isInjured, "\(player.name) is injured")
            #expect(player.loanedTo == nil, "\(player.name) is out on loan")
            #expect(player.condition >= parameters.conditionFloor.value, "\(player.name) is below the condition floor")
        }
        #expect(!lineup.picks.map(\.name).contains("Max Treml"))
    }

    @Test func theReportEqualsTheAdvisorsCalledOneByOne() throws {
        let book = try realBook()
        let tactic = try JSONDecoder().decode(Tactic.self, from: Fixtures.data("tactics/sample-4231.json"))
        var other = tactic
        other.name = "Second Sample"
        let catalog = try RoleCatalog.fm27()
        let profile = try RatingProfile.standard()
        let history = try JSONDecoder().decode([ConfirmedLineup].self, from: Fixtures.data("plans/sample-history.json"))
        let request = AdvisorsRequest(primary: tactic, tactics: [tactic, other], players: book.allPlayers,
                                      ownClub: book.ownClub(override: ownClubName), history: StartHistory(history),
                                      asOf: try #require(Day(iso: "2026-11-13")), intensity: .medium, accepted: [],
                                      rejected: [])
        let together = try Advisors.report(request, catalog: catalog, profile: profile, parameters: .fm27)
        #expect(together == (try AdvisorsTests.oneByOne(request, catalog: catalog, profile: profile, parameters: .fm27)))
        #expect(!together.removal.advisedToLeave.isEmpty && !together.depth.thin.isEmpty)
    }

    @Test func theAdvisorsRunOnTheRealSquad() throws {
        let book = try realBook()
        let players = book.allPlayers
        let ownClub = book.ownClub(override: ownClubName)
        let tactic = try JSONDecoder().decode(Tactic.self, from: Fixtures.data("tactics/sample-4231.json"))
        let catalog = try RoleCatalog.fm27()
        let profile = try RatingProfile.standard()
        let parameters = EngineParameters.fm27
        let asOf = try #require(Day(iso: "2026-11-13"))
        let history = try JSONDecoder().decode([ConfirmedLineup].self, from: Fixtures.data("plans/sample-history.json"))

        let onLoan = Set(players.filter { if case .loanedOut = LoanStatus.of($0, ownClub: ownClub) { true } else { false } }.map(\.id))
        let own = Set(players.filter { LoanStatus.of($0, ownClub: ownClub) == .own }.map(\.id))
        #expect(!onLoan.isEmpty)

        // The elevens: a full first eleven, nobody twice, nobody out on loan.
        let elevens = try Elevens.report(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                                         profile: profile, parameters: parameters)
        #expect(elevens.first.count == 11)
        let placed = (elevens.first + elevens.second).map(\.player)
        #expect(Set(placed).count == placed.count)
        #expect(onLoan.isDisjoint(with: placed))

        // Depth: nobody out on loan among the options; the goalkeeper's slot is thin with no cover, because one
        // goalkeeper is injured and the other is out on loan, where he is listed.
        let depth = try Depth.report(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                                     profile: profile, parameters: parameters)
        for slot in depth.slots { #expect(onLoan.isDisjoint(with: slot.options.map(\.player)), "\(slot.slot.rawValue)") }
        let keeper = try #require(depth.slots.first { $0.slot == .GK })
        #expect(keeper.isThin && keeper.cover == 0)
        #expect(depth.thin.contains(.GK))
        #expect(keeper.onLoan.map(\.name).contains("Max Treml"))
        #expect(keeper.options.contains { $0.name == "Jonny Maxted" && $0.unavailable == .injured })
        // The two U21 centre-backs a day short of the condition floor still count as cover.
        for slot in [SlotID.D_CL, .D_CR] {
            #expect(depth.slots.first { $0.slot == slot }?.isThin == false, "\(slot.rawValue)")
        }

        // Rest: nobody out on loan.
        let rest = try Rest.advice(players: players, ownClub: ownClub, history: StartHistory(history), asOf: asOf,
                                   intensity: PlanSettings.standard.trainingIntensity, parameters: parameters)
        #expect(onLoan.isDisjoint(with: rest.map(\.player)))
        #expect(rest.allSatisfy { !$0.reasons.isEmpty })

        // Training: every thin slot is covered by a recommendation, already being retrained, or a need nobody suits;
        // every recommendation is explained and names one of the club's own players, and none a player Player
        // Removal advises moving on.
        let removal = try Removal.report(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                                         profile: profile, parameters: parameters)
        let training = try Training.report(tactics: [tactic], players: players, ownClub: ownClub, accepted: [], rejected: [],
                                           leaving: removal.advisedToLeave, catalog: catalog, profile: profile,
                                           parameters: parameters)
        #expect(!removal.advisedToLeave.isEmpty)
        for recommendation in training.recommendations {
            #expect(!removal.advisedToLeave.contains(recommendation.choice.player), "\(recommendation.name)")
        }
        let recommended = Set(training.recommendations.flatMap(\.needs).map(\.slot))
        for slot in depth.thin {
            let need = RetrainingNeed(tactic: tactic.name, slot: slot)
            #expect(recommended.contains(slot) || training.needsBeingRetrained.contains(need)
                    || training.needsWithoutCandidates.contains(need), "\(slot.rawValue)")
        }
        // Nobody recommended is first choice at another slot, and each is solid at the slot's other position.
        let firstAt = Dictionary(uniqueKeysWithValues: elevens.tiers.first.map { ($0.value, $0.key) })
        let assignments = Dictionary(uniqueKeysWithValues: try tactic.assignments(catalog: catalog).map { ($0.slot, $0) })
        let byID = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
        for recommendation in training.recommendations {
            #expect(!recommendation.reasons.isEmpty && !recommendation.cautions.isEmpty, "\(recommendation.name)")
            #expect(own.contains(recommendation.choice.player), "\(recommendation.name)")
            let player = try #require(byID[recommendation.choice.player])
            for need in recommendation.needs {
                if let home = firstAt[player.id] { #expect(home == need.slot, "\(recommendation.name)") }
                let assignment = try #require(assignments[need.slot])
                for other in [assignment.ipPosition, assignment.oopPosition] where other != recommendation.choice.position {
                    #expect(try #require(player.familiarity[other]) >= parameters.depthSolidFamiliarity.value,
                            "\(recommendation.name) at \(other.rawValue)")
                }
            }
        }

        // Player Removal: nobody out on loan; every piece of advice has a reason, and its score is their sum.
        #expect(onLoan.isDisjoint(with: removal.advice.map(\.player) + removal.loans.map(\.player)))
        for advice in removal.advice {
            #expect(!advice.reasons.isEmpty, "\(advice.name)")
            #expect(advice.score == advice.reasons.map(\.points).reduce(0, +), "\(advice.name)")
        }
        // The first-choice goalkeeper, with nobody behind him, is not told to go.
        let goalkeeper = try #require(elevens.tiers.first[.GK])
        let keeperAdvice = try #require(removal.advice.first { $0.player == goalkeeper })
        #expect(keeperAdvice.level == .keep || keeperAdvice.level == .medium, "\(keeperAdvice.name): \(keeperAdvice.level)")

        // The importance suggestion: every fixture gets one, with reasons.
        let entries = try JSONDecoder().decode([FixtureEntry].self,
                                               from: Fixtures.data("plans/sample-fixtures-with-competitions.json"))
        #expect(entries.count == 5)
        #expect(entries.allSatisfy { $0.competition != nil && $0.opponentStrength != nil })
        let fixtures = entries.map {
            Fixture(id: $0.id, date: $0.date, opponent: $0.opponent, importance: $0.importance, tactic: tactic,
                    overrides: $0.overrides ?? [:], rejected: Set($0.rejected ?? []),
                    competition: $0.competition, opponentStrength: $0.opponentStrength)
        }
        let tiers = try SquadTiers.compute(tactic: tactic, players: players, ownClub: ownClub, catalog: catalog,
                                           profile: profile, parameters: parameters)
        for fixture in fixtures {
            let suggestion = try ImportanceAdvisor.suggest(for: fixture, among: fixtures, confirmed: history, players: players,
                                                           tiers: tiers, parameters: parameters)
            #expect(!suggestion.reasons.isEmpty, "\(fixture.id.raw)")
            // A league match against a much stronger side, with only one match in the six days before it.
            if fixture.date == Day(iso: "2026-11-21") { #expect(suggestion.importance == .high, "\(suggestion.reasons)") }
        }
        #expect(fixtures.contains { $0.date == Day(iso: "2026-11-21") })
    }
}
