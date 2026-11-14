import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

@Suite struct MatchTextTests {
    @Test func aSurnameIsTheLastWordOfAnOrdinaryName() {
        #expect(MatchText.surname("Tyrone Marsh") == "Marsh")
        #expect(MatchText.surname("  Zac   McEachran ") == "McEachran")
        #expect(MatchText.surname("Evan Peter Humphries") == "Humphries")
    }

    @Test func aOneWordNameIsItsOwnSurname() {
        #expect(MatchText.surname("Ronaldinho") == "Ronaldinho")
        #expect(MatchText.surname("") == "")
    }

    @Test func aSurnameKeepsTheParticlesBeforeIt() {
        #expect(MatchText.surname("Dillon De Silva") == "De Silva")
        #expect(MatchText.surname("Kauan Bitencourt de Oliveira") == "de Oliveira")
        #expect(MatchText.surname("Virgil van Dijk") == "van Dijk")
        #expect(MatchText.surname("Jan van der Berg") == "van der Berg")
        #expect(MatchText.surname("Ryan Mac Donald") == "Mac Donald")
    }

    /// A particle that is the whole name before the surname is kept too; a name that is all particles stays whole.
    @Test func aParticleAtTheStartOfTheNameIsKept() {
        #expect(MatchText.surname("De Bruyne") == "De Bruyne")
        #expect(MatchText.surname("van der") == "van der")
    }

    @Test func figuresAreWrittenAsTheOtherScreensWriteThem() {
        #expect(MatchText.oneDecimal(124.44) == "124.4")
        #expect(MatchText.oneDecimal(4.75) == "4.8")
        #expect(MatchText.oneDecimal(100) == "100.0")
        #expect(MatchText.factor(0.95) == "×0.95")
        #expect(MatchText.factor(1) == "×1.00")
        #expect(MatchText.factor(0.798368) == "×0.80")
        #expect(MatchText.percent(0.84) == "84%")
        #expect(MatchText.percent(0.999) == "99%")
    }
}

@Suite struct TokenMarkTests {
    @Test func aPlainFirstTeamPickHasNoMarks() {
        #expect(TokenMark.marks(isOverride: false, warnings: [], squad: .firstTeam) == [])
    }

    @Test func anOverrideIsPinned() {
        #expect(TokenMark.marks(isOverride: true, warnings: [], squad: .firstTeam) == [.override])
    }

    @Test func outOfPositionOrARuleOverriddenIsACaution() {
        #expect(TokenMark.marks(isOverride: false, warnings: [.outOfPosition(.inPossession, familiarity: 1)],
                                squad: .firstTeam) == [.caution])
        #expect(TokenMark.marks(isOverride: true, warnings: [.overridesRule(.injured)], squad: .firstTeam)
            == [.override, .caution])
    }

    @Test func aYouthSquadPlayerIsMarkedWithHisSquad() {
        #expect(TokenMark.marks(isOverride: false, warnings: [], squad: .u21) == [.youth(.u21)])
        #expect(TokenMark.marks(isOverride: true, warnings: [.outOfPosition(.outOfPossession, familiarity: 5)],
                                squad: .u18) == [.override, .caution, .youth(.u18)])
        #expect(TokenMark.youth(.u21).badgeText == "U21")
        #expect(TokenMark.youth(.u18).badgeText == "U18")
    }

    @Test func aPlayerNoLongerInTheSquadsIsNotMarkedYouth() {
        #expect(TokenMark.marks(isOverride: false, warnings: [], squad: nil) == [])
    }

    @Test func theKeyExplainsEveryKindOfMark() {
        #expect(TokenMark.key.map(\.text) == [
            "Chosen by you",
            "Out of position, or a rule overridden",
            "From the U21s or U18s",
        ])
    }

    @Test func outOfPositionWarningsGetTheEnginesSentence() {
        let p = EngineParameters.fm27
        // A rule overridden is already in the engine's reasons ("Chosen by you, overriding: …"), so it gets no line.
        #expect(PickDetail.cautions([.outOfPosition(.inPossession, familiarity: 1),
                                     .outOfPosition(.outOfPossession, familiarity: 7),
                                     .overridesRule(.injured)], parameters: p)
            == [ErrorDescriptions.describe(PickWarning.outOfPosition(.inPossession, familiarity: 1), parameters: p),
                ErrorDescriptions.describe(PickWarning.outOfPosition(.outOfPossession, familiarity: 7), parameters: p)])
        #expect(PickDetail.cautions([.overridesRule(.banned)], parameters: p) == [])
        #expect(PickDetail.cautions([], parameters: p) == [])
    }
}

@MainActor @Suite struct MatchPresentationTests {
    private func day(_ iso: String) -> Day { Day(iso: iso)! }

    private func fixture(_ id: String, _ iso: String, _ opponent: String, _ importance: Importance = .medium) -> StoredFixture {
        StoredFixture(id: FixtureID(id), date: day(iso), opponent: opponent, importance: importance)
    }

    private func planned(_ fixture: StoredFixture) -> FixturePlan {
        FixturePlan(fixture: fixture, tacticName: "4-2-3-1", usesPrimaryBecauseItsTacticWasDeleted: false,
                    body: .planned(Lineup(picks: [], unfilled: [], omissions: [], ignoredOverrides: [:]), fitness: [:]),
                    fitnessIsProjected: false, ignoredOverrides: [])
    }

    private func confirmed(_ fixture: StoredFixture, _ starters: [SlotID: String]) -> FixturePlan {
        let ids = starters.mapValues { PlayerID(key: $0) }
        let names = Dictionary(uniqueKeysWithValues: starters.values.map { (PlayerID(key: $0), "Player \($0)") })
        let record = ConfirmedRecord(lineup: ConfirmedLineup(fixture: fixture.id, date: fixture.date, starters: ids),
                                     names: names, tacticName: "4-2-3-1")
        return FixturePlan(fixture: fixture, tacticName: "4-2-3-1", usesPrimaryBecauseItsTacticWasDeleted: false,
                           body: .confirmed(record), fitnessIsProjected: false, ignoredOverrides: [])
    }

    private func missed(_ fixture: StoredFixture) -> FixturePlan {
        FixturePlan(fixture: fixture, tacticName: "", usesPrimaryBecauseItsTacticWasDeleted: false, body: .missed(nil),
                    fitnessIsProjected: false, ignoredOverrides: [])
    }

    // MARK: Which fixture is chosen

    @Test func theFirstFixtureNeitherConfirmedNorMissedIsChosenToBeginWith() {
        let plans = [missed(fixture("m", "2026-11-10", "M")), confirmed(fixture("c", "2026-11-12", "C"), [:]),
                     planned(fixture("p", "2026-11-14", "P")), planned(fixture("q", "2026-11-17", "Q"))]
        #expect(MatchPresentation.initialFixture(in: plans) == FixtureID("p"))
    }

    @Test func withNothingToPlanTheLastFixtureIsChosen() {
        let plans = [confirmed(fixture("c", "2026-11-12", "C"), [:]), missed(fixture("m", "2026-11-13", "M"))]
        #expect(MatchPresentation.initialFixture(in: plans) == FixtureID("m"))
        #expect(MatchPresentation.initialFixture(in: []) == nil)
    }

    @Test func aChosenFixtureStaysChosenWhileItIsInThePlan() {
        let plans = [planned(fixture("p", "2026-11-14", "P")), planned(fixture("q", "2026-11-17", "Q"))]
        #expect(MatchPresentation.chosen(FixtureID("q"), in: plans)?.id == FixtureID("q"))
        #expect(MatchPresentation.chosen(FixtureID("gone"), in: plans)?.id == FixtureID("p"))
        #expect(MatchPresentation.chosen(nil, in: plans)?.id == FixtureID("p"))
    }

    @Test func afterConfirmingTheNextPlannedFixtureIsShown() {
        let plans = [confirmed(fixture("c", "2026-11-12", "C"), [:]), confirmed(fixture("d", "2026-11-14", "D"), [:]),
                     planned(fixture("p", "2026-11-17", "P")), planned(fixture("q", "2026-11-21", "Q"))]
        #expect(MatchPresentation.fixtureAfterConfirming(FixtureID("d"), in: plans) == FixtureID("p"))
    }

    @Test func afterConfirmingTheLastFixtureItStaysShown() {
        let plans = [missed(fixture("m", "2026-11-10", "M")), confirmed(fixture("d", "2026-11-14", "D"), [:])]
        #expect(MatchPresentation.fixtureAfterConfirming(FixtureID("d"), in: plans) == FixtureID("d"))
    }

    // MARK: The strip and the heading

    @Test func aStripCellShowsTheDateTheOpponentAndTheState() {
        let cells = [planned(fixture("p", "2026-11-14", "Opponent A", .low)),
                     confirmed(fixture("c", "2026-11-12", "Opponent C"), [:]),
                     missed(fixture("m", "2026-11-10", "Opponent M"))].map(FixtureCell.init)
        #expect(cells.map(\.dateText) == ["Sat 14 Nov", "Thu 12 Nov", "Tue 10 Nov"])
        #expect(cells.map(\.opponentText) == ["v Opponent A", "v Opponent C", "v Opponent M"])
        #expect(cells.map(\.stateText) == [nil, "Confirmed", "Missed"])
        #expect(cells.map(\.state) == [.planned, .confirmed, .missed])
        #expect(cells[0].importance == .low)
    }

    @Test func theHeadingNamesTheMatchAndItsTactic() {
        let plan = planned(fixture("p", "2026-11-14", "Opponent A"))
        #expect(MatchPresentation.heading(plan) == "v Opponent A, Saturday 14 November 2026")
        #expect(MatchPresentation.tacticLine(plan) == "Tactic: 4-2-3-1")
        #expect(MatchPresentation.tacticLine(missed(fixture("m", "2026-11-10", "M"))) == nil)
    }

    @Test func aDeletedTacticGetsAQuietLine() {
        let fixture = fixture("p", "2026-11-14", "Opponent A")
        let plan = FixturePlan(fixture: fixture, tacticName: "4-2-3-1", usesPrimaryBecauseItsTacticWasDeleted: true,
                               body: .missed(nil), fitnessIsProjected: false, ignoredOverrides: [])
        #expect(MatchPresentation.deletedTacticLine(plan) == "This match's tactic was deleted, so the primary tactic is used.")
        #expect(MatchPresentation.deletedTacticLine(planned(fixture)) == nil)
    }

    // MARK: Left out

    @Test func eachOmissionIsShownWithItsSlotAndTheEnginesReason() {
        let rows = LeftOutRow.rows([
            Omission(player: PlayerID(key: "a"), name: "Jonny Maxted", slot: .GK, cause: .excluded(.injured),
                     reason: "Left out: injured"),
            Omission(player: PlayerID(key: "b"), name: "Dejan Tetek", slot: .DM_R, cause: .heldBack([.consecutiveStarts]),
                     reason: "Left out: Has started the last 2 matches in quick succession (×0.90)"),
        ])
        #expect(rows.map(\.name) == ["Jonny Maxted", "Dejan Tetek"])
        #expect(rows.map(\.slotText) == ["GK", "DM R"])
        #expect(rows.map(\.reason) == ["Left out: injured", "Left out: Has started the last 2 matches in quick succession (×0.90)"])
    }

    @Test func thosePlayersYouLeftOutAreListedByName() {
        let rows = RejectedRow.rows([PlayerID(key: "z"), PlayerID(key: "a"), PlayerID(key: "gone")],
                                    names: [PlayerID(key: "z"): "Aaron Zed", PlayerID(key: "a"): "Bob Able"])
        #expect(rows.map(\.name) == ["Aaron Zed", "Bob Able", "A player no longer in the squads"])
        #expect(rows.map(\.player.key) == ["z", "a", "gone"])
    }

    // MARK: Starts

    @Test func theStartsGridHasARowPerStarterAndAColumnPerFixtureWithALineup() {
        let plans = [
            confirmed(fixture("c", "2026-11-12", "Opponent C"), [.GK: "k", .ST_C: "s"]),
            missed(fixture("m", "2026-11-13", "Opponent M")),
            confirmed(fixture("d", "2026-11-14", "Opponent D"), [.GK: "k", .D_L: "l", .AM_R: "s"]),
        ]
        let grid = StartsGrid(plans: plans)
        #expect(grid.columns.map(\.id) == [FixtureID("c"), FixtureID("d")])
        #expect(grid.columns.map(\.dateText) == ["Thu 12 Nov", "Sat 14 Nov"])
        #expect(grid.columns.map(\.opponentText) == ["v Opponent C", "v Opponent D"])
        // By the slot of each player's first start, goalkeeper first.
        #expect(grid.rows.map(\.name) == ["Player k", "Player l", "Player s"])
        #expect(grid.rows.map { $0.cells.map(\.text) } == [["GK", "GK"], ["–", "D L"], ["ST", "AM R"]])
        #expect(grid.rows.map { $0.cells.map(\.isStart) } == [[true, true], [false, true], [true, true]])
        #expect(grid.rows.map(\.starts) == [2, 1, 2])
    }

    @Test func playersFirstStartingInTheSameSlotGoByName() {
        let plans = [confirmed(fixture("c", "2026-11-12", "C"), [.GK: "b"]),
                     confirmed(fixture("d", "2026-11-14", "D"), [.GK: "a"])]
        #expect(StartsGrid(plans: plans).rows.map(\.name) == ["Player a", "Player b"])
    }

    @Test func aStarterWithNoNameIsNotShownByHisId() {
        let fixture = fixture("c", "2026-11-12", "C")
        let record = ConfirmedRecord(
            lineup: ConfirmedLineup(fixture: fixture.id, date: fixture.date, starters: [.GK: PlayerID(key: "fmrte:123")]),
            names: [:], tacticName: "4-2-3-1")
        let plan = FixturePlan(fixture: fixture, tacticName: "4-2-3-1", usesPrimaryBecauseItsTacticWasDeleted: false,
                               body: .confirmed(record), fitnessIsProjected: false, ignoredOverrides: [])
        #expect(StartsGrid(plans: [plan]).rows.map(\.name) == ["A player no longer in the squads"])
        #expect(StartsGrid(plans: [plan], names: [PlayerID(key: "fmrte:123"): "Jonny Maxted"]).rows.map(\.name)
            == ["Jonny Maxted"])
        let token = SampleData.emptyModel().tokens(for: plan).first
        #expect(token?.name == "A player no longer in the squads")
        #expect(token?.surname == "Unknown")
    }

    @Test func noLineupGivesAnEmptyGrid() {
        let grid = StartsGrid(plans: [missed(fixture("m", "2026-11-13", "M"))])
        #expect(grid.columns.isEmpty)
        #expect(grid.rows.isEmpty)
    }

    // MARK: Candidates

    @Test func aCandidateRowShowsHisRatingOrADashAndWhetherHeCanBeChosen() {
        let rows = CandidateRow.rows([
            Candidate(player: PlayerID(key: "a"), name: "Able", squad: .firstTeam, rating: 106.94, unavailable: nil),
            Candidate(player: PlayerID(key: "b"), name: "Baker", squad: .u21, rating: 99.0, unavailable: "injured"),
            Candidate(player: PlayerID(key: "c"), name: "Cole", squad: .u18, rating: nil,
                      unavailable: "Cole has no value for the attribute Pace"),
        ], current: PlayerID(key: "b"))
        #expect(rows.map(\.ratingText) == ["106.9", "99.0", "—"])
        #expect(rows.map(\.squadText) == ["First team", "U21s", "U18s"])
        #expect(rows.map(\.canChoose) == [true, false, false])
        #expect(rows.map(\.isCurrent) == [false, true, false])
        #expect(rows.map(\.unavailable) == [nil, "injured", "Cole has no value for the attribute Pace"])
    }

    // MARK: Not ready

    @Test func eachMissingThingSaysWhatIsMissingAndGoesToItsScreen() throws {
        let squad = try #require(MatchPresentation.notReady(.needsSquad))
        #expect(squad.message == "No squad yet. Import your first team on the Squad screen to get a lineup.")
        #expect(squad.action == "Go to Squad")
        #expect(squad.screen == .squad)
        #expect(squad.problems.isEmpty)

        let tactic = try #require(MatchPresentation.notReady(.needsTactic([])))
        #expect(tactic.message == "No tactic yet. Add one on the Tactics screen to get a lineup.")
        #expect(tactic.screen == .tactics)

        let fixtures = try #require(MatchPresentation.notReady(.needsFixtures))
        #expect(fixtures.message == "No fixtures yet. Add the next few matches on the Fixtures screen.")
        #expect(fixtures.action == "Go to Fixtures")
        #expect(fixtures.screen == .fixtures)

        #expect(MatchPresentation.notReady(.ready([])) == nil)
    }

    @Test func anUnusableTacticShowsItsSentences() throws {
        let tactic = try #require(MatchPresentation.notReady(.needsTactic(["Sample cannot be used: it has 10 slots."])))
        #expect(tactic.message == "A tactic the fixtures use cannot be used, so nothing is planned.")
        #expect(tactic.problems == ["Sample cannot be used: it has 10 slots."])
        #expect(tactic.isFailure == false)
        #expect(tactic.action == "Go to Tactics")
    }

    @Test func aFailureGoesToTheScreenThatFixesIt() throws {
        let clash = try #require(AppModel.sameDayProblem([fixture("a", "2026-11-14", "A"), fixture("b", "2026-11-14", "B")]))
        let settings = "The plan settings cannot be used: the horizon must be at least 1."

        let failedOnClash = try #require(MatchPresentation.notReady(.failed([clash], fix: .fixtures)))
        #expect(failedOnClash.isFailure)
        #expect(failedOnClash.problems == [clash])
        #expect(failedOnClash.message == "The plan could not be worked out.")
        #expect(failedOnClash.screen == .fixtures)
        #expect(failedOnClash.action == "Go to Fixtures")

        let failedOnSettings = try #require(MatchPresentation.notReady(.failed([settings], fix: .settings)))
        #expect(failedOnSettings.screen == .settings)
        #expect(failedOnSettings.action == "Go to Settings")
    }

    @Test func thePickerAndAConfirmedLineupSayWhatTheyAre() {
        #expect(MatchPresentation.pickerTitle(.D_L) == "Choose who plays at left back")
        #expect(MatchPresentation.pickerTitle(.ST_C) == "Choose who plays at striker")
        #expect(PickerText.planned(.ST_C).title == "Choose who plays at striker")
        #expect(PickerText.planned(.ST_C).ratingHeading == "Rating at full fitness")
        #expect(PickerText.remembered(.D_L).title == "Who started at left back?")
        #expect(PickerText.remembered(.D_L).ratingHeading == nil)
        #expect(MatchPresentation.confirmButton(for: missed(fixture("m", "2026-11-10", "M"))).title
            == "Confirm this eleven as played")
        #expect(MatchPresentation.confirmButton(for: planned(fixture("p", "2026-11-14", "P"))).title == "Confirm this lineup")
        #expect(MatchPresentation.confirmedLine(confirmed(fixture("c", "2026-11-12", "C"), [:]))
            == "Confirmed as played, with 4-2-3-1.")
        #expect(MatchPresentation.confirmedLine(planned(fixture("p", "2026-11-14", "P"))) == nil)
    }

    @Test func everySlotHasALongNameOfItsOwnForSentences() {
        let names = SlotID.allCases.map(\.longName)
        #expect(Set(names).count == SlotID.allCases.count)
        #expect(names.allSatisfy { !$0.contains("(") && $0 == $0.lowercased() })
        #expect(SlotID.GK.longName == "goalkeeper")
        #expect(SlotID.D_L.longName == "left back")
        #expect(SlotID.D_CL.longName == "left centre-back")
        #expect(SlotID.D_C.longName == "centre-back")
        #expect(SlotID.WB_R.longName == "right wing-back")
        #expect(SlotID.DM_L.longName == "left defensive midfield")
        #expect(SlotID.DM_C.longName == "defensive midfield")
        #expect(SlotID.M_CR.longName == "right-centre midfield")
        #expect(SlotID.AM_C.longName == "central attacking midfield")
        #expect(SlotID.AM_L.longName == "left attacking midfield")
        #expect(SlotID.ST_C.longName == "striker")
        #expect(SlotID.ST_R.longName == "right striker")
    }

    @Test func theTwoViewsHaveTheirNames() {
        #expect(MatchView.allCases.map(\.title) == ["Team sheet", "Starts"])
    }
}

/// The parts of the screen that need a planned lineup, from the sample: five fixtures planned from the captured squads.
@MainActor @Suite struct MatchPresentationOnTheSampleTests {
    private func sample() throws -> AppModel { try SampleData.model(repositoryRoot: Captures.repositoryRoot) }

    private func firstPlan(_ model: AppModel) throws -> FixturePlan {
        guard case .ready(let plans) = model.planState else {
            Issue.record("expected a ready plan, got \(model.planState)")
            throw SampleDataError(description: "no plan")
        }
        return try #require(plans.first)
    }

    @Test func aPlannedLineupGivesATokenPerPickWithItsSurnameValueAndMarks() throws {
        let model = try sample()
        let plan = try firstPlan(model)
        guard case .planned(let lineup, _) = plan.body else { Issue.record("not planned"); return }
        let tokens = model.tokens(for: plan)
        #expect(tokens.map(\.slot) == lineup.picks.map(\.slot))
        #expect(tokens.count == 11)
        for (token, pick) in zip(tokens, lineup.picks) {
            #expect(token.surname == MatchText.surname(pick.name))
            #expect(token.name == pick.name)
            #expect(token.value == MatchText.oneDecimal(pick.value))
            let squad = model.players.first { $0.id == pick.player }?.squad
            #expect(token.marks == TokenMark.marks(isOverride: pick.isOverride, warnings: pick.warnings, squad: squad))
        }
    }

    @Test func aConfirmedLineupGivesTokensWithNamesOnly() throws {
        let model = try sample()
        let plan = try firstPlan(model)
        model.confirm(plan.id)
        guard case .ready(let plans) = model.planState, let after = plans.first(where: { $0.id == plan.id }),
              case .confirmed(let record) = after.body else { Issue.record("not confirmed"); return }
        let tokens = model.tokens(for: after)
        #expect(Set(tokens.map(\.slot)) == Set(record.lineup.starters.keys))
        #expect(tokens.map(\.slot) == SlotID.allCases.filter { record.lineup.starters[$0] != nil })
        #expect(tokens.allSatisfy { $0.value == nil && $0.marks.isEmpty })
        for token in tokens {
            #expect(token.slotText == token.slot.displayName)
            #expect(token.surname == MatchText.surname(record.names[token.player] ?? ""))
        }
    }

    @Test func thePickDetailGivesEveryFigureTheRolesAndEveryReasonAsWritten() throws {
        let model = try sample()
        let plan = try firstPlan(model)
        guard case .planned(let lineup, let fitness) = plan.body else { Issue.record("not planned"); return }
        let pick = try #require(lineup.picks.first { $0.slot == .AM_L })
        let detail = try #require(model.pickDetail(at: .AM_L, in: plan))
        #expect(detail.name == pick.name)
        #expect(detail.player == pick.player)
        #expect(detail.squadText == "First team")
        #expect(detail.slotText == "AM L")
        // The sample 4-2-3-1's inside forward on the left becomes a wide midfielder out of possession.
        #expect(detail.roles == ["In possession: Inside Forward (left attacking midfield)",
                                 "Out of possession: Wide Midfielder (left midfield)"])
        #expect(detail.reasons == pick.reasons)
        #expect(detail.isOverride == pick.isOverride)

        let onTheDay = try #require(fitness[pick.player])
        #expect(plan.fitnessIsProjected)
        #expect(detail.figures == [
            PickFigure(label: "Rating", figure: MatchText.oneDecimal(pick.rating.value), factor: nil),
            PickFigure(label: "Projected condition", figure: MatchText.percent(onTheDay.condition),
                       factor: MatchText.factor(pick.fitness.condition),
                       direction: ReasonDirection(fitnessFactor: pick.fitness.condition)),
            PickFigure(label: "Projected sharpness", figure: MatchText.percent(onTheDay.sharpness),
                       factor: MatchText.factor(pick.fitness.sharpness),
                       direction: ReasonDirection(fitnessFactor: pick.fitness.sharpness)),
            PickFigure(label: "Projected jadedness", figure: BoardText.signed(Int(onTheDay.jadedness.rounded())),
                       factor: MatchText.factor(pick.fitness.jadedness),
                       direction: ReasonDirection(fitnessFactor: pick.fitness.jadedness)),
            PickFigure(label: "Match-day value", figure: MatchText.oneDecimal(pick.value), factor: nil),
        ])
        #expect(model.pickDetail(at: .M_C, in: plan) == nil)
    }

    @Test func thePickAndOmissionReasonsNamePositionsInWords() throws {
        let model = try sample()
        let plan = try firstPlan(model)
        guard case .planned(let lineup, _) = plan.body else { Issue.record("not planned"); return }
        let codes = Position.allCases.map(\.rawValue).filter { $0.contains("(") }
        for pick in lineup.picks {
            let detail = try #require(model.pickDetail(at: pick.slot, in: plan))
            for reason in detail.reasons {
                for code in codes { #expect(!reason.contains(code), "\(reason)") }
            }
        }
        for omission in lineup.omissions {
            for code in codes { #expect(!omission.reason.contains(code), "\(omission.reason)") }
        }
        let wide = try #require(model.pickDetail(at: .AM_L, in: plan))
        let rating = try #require(wide.reasons.first)
        #expect(rating.hasPrefix("Rating "))
        #expect(rating.contains(": left attacking midfield familiarity "))
        #expect(rating.contains(", left midfield familiarity "))
    }

    @Test func aPlayerWithNoFitnessForTheDayShowsDashesNotTodaysFigures() throws {
        let model = try sample()
        let plan = try firstPlan(model)
        guard case .planned(let lineup, _) = plan.body else { Issue.record("not planned"); return }
        let bare = FixturePlan(fixture: plan.fixture, tacticName: plan.tacticName, usesPrimaryBecauseItsTacticWasDeleted: false,
                               body: .planned(lineup, fitness: [:]), fitnessIsProjected: true, ignoredOverrides: [])
        let detail = try #require(model.pickDetail(at: .AM_L, in: bare))
        #expect(detail.figures.map(\.figure) == [detail.figures[0].figure, "—", "—", "—", detail.figures[4].figure])
        #expect(detail.figures[1].factor != nil)
    }

    @Test func aSelectionHoldsWhileTheSamePlayerIsInTheSlotOfTheSameFixture() throws {
        let model = try sample()
        guard case .ready(let plans) = model.planState, plans.count >= 2 else { Issue.record("no plan"); return }
        let first = plans[0]
        let selection = try #require(MatchPresentation.selection(at: .D_L, in: first))
        #expect(MatchPresentation.selectedSlot(selection, in: first) == .D_L)
        // Another fixture: the selection does not carry over.
        #expect(MatchPresentation.selectedSlot(selection, in: plans[1]) == nil)
        // Another player in the slot after a replan: the selection is dropped.
        let moved = PickSelection(fixture: selection.fixture, slot: selection.slot, player: PlayerID(key: "someone else"))
        #expect(MatchPresentation.selectedSlot(moved, in: first) == nil)
        #expect(MatchPresentation.selectedSlot(nil, in: first) == nil)
        #expect(MatchPresentation.selection(at: .M_C, in: first) == nil)
    }

    @Test func theGoalkeeperOutOfPositionHasACautionLine() throws {
        let model = try sample()
        let plan = try firstPlan(model)
        guard case .planned(let lineup, _) = plan.body else { Issue.record("not planned"); return }
        let keeper = try #require(lineup.picks.first { $0.slot == .GK })
        let detail = try #require(model.pickDetail(at: .GK, in: plan))
        #expect(detail.cautions == PickDetail.cautions(keeper.warnings, parameters: .fm27, projected: plan.fitnessIsProjected))
        #expect(detail.cautions.first == "Out of position in possession: familiarity 1, below 10.")
        #expect(!keeper.warnings.isEmpty, "the sample's real goalkeeper is injured, so an outfielder is in goal")
    }

    @Test func theCurrentPickIsMarkedAmongTheCandidates() throws {
        let model = try sample()
        let plan = try firstPlan(model)
        guard case .planned(let lineup, _) = plan.body else { Issue.record("not planned"); return }
        let pick = try #require(lineup.picks.first { $0.slot == .ST_C })
        let rows = model.candidateRows(for: .ST_C, in: plan.id)
        #expect(rows.map(\.id) == model.candidates(for: .ST_C, in: plan.id).map(\.id))
        #expect(rows.filter(\.isCurrent).map(\.id) == [pick.player])
    }

    // MARK: The sample's variants for the pictures

    @Test func theSampleWithAMissedFixtureShowsItAndChoosesTheFirstPlannedOne() throws {
        let model = try SampleData.modelWithMissedFixture(repositoryRoot: Captures.repositoryRoot)
        guard case .ready(let plans) = model.planState else { Issue.record("not ready: \(model.planState)"); return }
        #expect(plans.first?.body == .missed(nil))
        #expect(plans.first?.fixture.opponent == "Opponent Z")
        #expect(MatchPresentation.initialFixture(in: plans) == plans.dropFirst().first?.id)
    }

    @Test func theSampleWithAMissedElevenHasTheFirstFixtureMissedWithItsElevenAndNothingCountedTwice() throws {
        let sample = try SampleData.model(repositoryRoot: Captures.repositoryRoot)
        let model = try SampleData.modelWithMissedEleven(repositoryRoot: Captures.repositoryRoot)
        guard case .ready(let plans) = model.planState else { Issue.record("not ready: \(model.planState)"); return }
        let first = try #require(plans.first)
        #expect(first.id == sample.fixtures.first?.id)
        #expect(first.body == .missed(sample.fixtures.first?.lastPlanned))
        #expect(model.canConfirm(first.id))
        #expect(model.notices.isEmpty)
    }

    @Test func theSampleWithTwoMatchesOnOneDayFailsWithAWayToFixtures() throws {
        let model = try SampleData.modelWithTwoMatchesOnOneDay(repositoryRoot: Captures.repositoryRoot)
        let shown = try #require(MatchPresentation.notReady(model.planState))
        #expect(shown.isFailure)
        #expect(shown.screen == .fixtures)
        #expect(shown.problems.count == 1)
    }

    @Test func theSampleWithChoicesHasAPinnedYouthAnIgnoredOverrideAndARejection() throws {
        let model = try SampleData.modelWithChoices(repositoryRoot: Captures.repositoryRoot)
        let plan = try firstPlan(model)
        let midfielder = try #require(model.tokens(for: plan).first { $0.slot == .AM_C })
        #expect(midfielder.marks.contains(.override))
        #expect(midfielder.marks.contains(.youth(.u21)))
        #expect(plan.ignoredOverrides.map(\.slot) == [.GK])
        #expect(plan.ignoredOverrides.first?.sentence.hasPrefix("Jonny Maxted at goalkeeper: injured") == true)
        #expect(model.rejectedRows(in: plan).map(\.name) == ["Tyrone Marsh"])
    }

    @Test func theSampleAfterConfirmingHasTheFirstFixtureConfirmedAndTheFitnessNote() throws {
        let model = try SampleData.modelAfterConfirmingFirst(repositoryRoot: Captures.repositoryRoot)
        guard case .ready(let plans) = model.planState else { Issue.record("not ready: \(model.planState)"); return }
        #expect(plans.first?.body.isConfirmed == true)
        #expect(MatchPresentation.initialFixture(in: plans) == plans.dropFirst().first?.id)
        #expect(model.fitnessNote != nil)
    }
}
