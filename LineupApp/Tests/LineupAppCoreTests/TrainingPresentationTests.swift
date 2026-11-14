import Foundation
import Testing
@testable import LineupEngine
@testable import LineupAppCore

/// The Training screen: the recommendations as cards, the retrainings under way with their tracks, the slots to recruit
/// for and the pairs turned down, in the engine's words.
@MainActor @Suite struct TrainingPresentationTests {
    private let today = TestModel.today
    private let parameters = EngineParameters.fm27
    private let alice = PlayerID.fmrte(1)
    private let bob = PlayerID.fmrte(2)
    private let sample = "Sample 4-2-3-1"

    private func recommendation(_ player: PlayerID, name: String, position: Position = .defenderLeft, age: Int = 22,
                                familiarity: Int = 9, needs: [RetrainingNeed]? = nil,
                                reasons: [String] = ["First reason", "Second reason"],
                                cautions: [String] = ["One caution", "Another caution"],
                                basis: Evidence = .carriedOverFM26) -> RetrainingRecommendation {
        RetrainingRecommendation(
            choice: RetrainingChoice(player: player, position: position), name: name, age: age,
            currentFamiliarity: familiarity, needs: needs ?? [RetrainingNeed(tactic: sample, slot: .D_L)],
            ratingIfLearnt: 110, shareOfFirstChoice: 0.92, learnability: 0.6, from: .defenderRight,
            difficulty: .structural, weeks: 21, reasons: reasons, cautions: cautions, basis: basis)
    }

    private func report(_ recommendations: [RetrainingRecommendation] = [], without: [RetrainingNeed] = [],
                        beingRetrained: [RetrainingNeed] = []) -> TrainingReport {
        TrainingReport(recommendations: recommendations, needsWithoutCandidates: without, needsBeingRetrained: beingRetrained)
    }

    private func observation(_ days: Int, _ familiarity: Int) -> FamiliarityObservation {
        FamiliarityObservation(day: today.adding(days: days), familiarity: familiarity)
    }

    // MARK: Recommended

    @Test func aCardHasHisNameAgeAndTheEnginesSentences() throws {
        let given = recommendation(alice, name: "Alice Archer", age: 19, familiarity: 7,
                                   needs: [RetrainingNeed(tactic: sample, slot: .D_L), RetrainingNeed(tactic: "Another", slot: .D_CL)])
        let card = try #require(TrainingPresentation.cards(report([given])).first)
        #expect(card.id == RetrainingChoice(player: alice, position: .defenderLeft))
        #expect(card.choice == given.choice)
        #expect(card.name == "Alice Archer")
        #expect(card.ageText == "Age 19")
        #expect(card.headline == "Learn left back")
        #expect(card.headline == AdvisorText.learn(.defenderLeft))
        #expect(card.coversText == "Covers left back in Sample 4-2-3-1 and left centre-back in Another")
        #expect(card.familiarityText == "7")
        #expect(card.timeText == "About 21 weeks: a structural change from right back")
        #expect(card.timeText == AdvisorText.timeToLearn(given))
        #expect(card.noteText == "(FM26-era numbers)")
    }

    @Test func aCardsReasonsAreMarkedWithAPlusAndItsCautionsKeptInTheirOrder() throws {
        // Two identical reasons stay two.
        let given = recommendation(alice, name: "A", reasons: ["Same", "Same", "Other"], cautions: ["C1", "C2"])
        let card = try #require(TrainingPresentation.cards(report([given])).first)
        #expect(card.reasons == [MarkedReason(text: "Same", direction: .raised), MarkedReason(text: "Same", direction: .raised),
                                 MarkedReason(text: "Other", direction: .raised)])
        #expect(card.cautions == ["C1", "C2"])
    }

    @Test func aCardWithFM27EvidenceHasNoNote() throws {
        let card = try #require(TrainingPresentation.cards(report([recommendation(alice, name: "A", basis: .fm27Observation)])).first)
        #expect(card.noteText == nil)
    }

    @Test func cardsKeepTheEnginesOrder() {
        let given = [recommendation(bob, name: "Bob"), recommendation(alice, name: "Alice", position: .goalkeeper)]
        #expect(TrainingPresentation.cards(report(given)).map(\.name) == ["Bob", "Alice"])
    }

    @Test func aCardIsSpokenWithEverythingOnIt() throws {
        let given = recommendation(alice, name: "Alice Archer", reasons: ["One reason"], cautions: ["One caution"])
        let card = try #require(TrainingPresentation.cards(report([given])).first)
        #expect(card.spokenText == "Alice Archer, Age 22, Learn left back, Covers left back in Sample 4-2-3-1, "
                + "Familiarity now 9, About 21 weeks: a structural change from right back, One reason, Caution: One caution, "
                + "FM26-era numbers")
    }

    // MARK: Being retrained

    @Test func aRowUnderWayHasHisNameThePositionTheDayAndTheTrack() throws {
        let choice = RetrainingChoice(player: alice, position: .defenderLeft)
        let retraining = Retraining(player: alice, position: .defenderLeft, acceptedOn: today.adding(days: -28))
        let observations = [observation(-28, 8), observation(-14, 10), observation(0, 12)]
        let state = TrainingState(accepted: [retraining], observations: [choice: observations],
                                  names: [alice: "Old Name"])
        let row = try #require(TrainingPresentation.underWay(state, inSquads: [alice: "Alice Archer"],
                                                             parameters: parameters).first)
        #expect(row.id == choice)
        #expect(row.name == "Alice Archer")   // the squad's name before the one saved
        #expect(row.positionText == "Learning left back")
        #expect(row.acceptedText == "Accepted on 16 Oct")
        #expect(row.track == RetrainingTrack(start: 8, latest: 12, solid: parameters.depthSolidFamiliarity.value))
        #expect(row.track?.solid == 15)
        let progress = RetrainingTracker.progress(of: retraining, observations: observations, parameters: parameters)
        #expect(row.progressText == AdvisorText.progress(progress, toward: .defenderLeft, parameters: parameters))
        #expect(row.progressText == "Familiarity at left back 8 to 12 in 4 weeks: about 1.0 a week, 3 weeks to solid")
        #expect(row.departedStamp == nil)
    }

    @Test func theTrackCountsOnlyObservationsFromTheDayItWasAccepted() throws {
        let choice = RetrainingChoice(player: alice, position: .striker)
        let state = TrainingState(accepted: [Retraining(player: alice, position: .striker, acceptedOn: today)],
                                  observations: [choice: [observation(-7, 3), observation(0, 6), observation(7, 7)]])
        let row = try #require(TrainingPresentation.underWay(state, inSquads: [alice: "A"], parameters: parameters).first)
        #expect(row.track?.start == 6)
        #expect(row.track?.latest == 7)
    }

    @Test func aRowWithNoObservationHasAnEmptyTrackAndTheEnginesSentence() throws {
        let state = TrainingState(accepted: [Retraining(player: alice, position: .striker, acceptedOn: today)])
        let row = try #require(TrainingPresentation.underWay(state, inSquads: [alice: "A"], parameters: parameters).first)
        #expect(row.track == RetrainingTrack(start: nil, latest: nil, solid: 15))
        #expect(row.progressText == "No familiarity recorded yet: it is read at each import")
    }

    @Test func aPlayerNoLongerInAnySquadIsShownAsSuchWithHisSavedName() throws {
        let choice = RetrainingChoice(player: bob, position: .goalkeeper)
        let state = TrainingState(accepted: [Retraining(player: bob, position: .goalkeeper, acceptedOn: today)],
                                  observations: [choice: [observation(0, 4)]], names: [bob: "Bob Baker"])
        let row = try #require(TrainingPresentation.underWay(state, inSquads: [alice: "A"], parameters: parameters).first)
        #expect(row.name == "Bob Baker")
        #expect(row.positionText == "Learning goalkeeper")
        #expect(row.acceptedText == "Accepted on 13 Nov")
        #expect(row.track == nil)
        #expect(row.progressText == nil)
        #expect(row.departedStamp == StatusStamp(text: "No longer in the squad", isOut: true))
        #expect(row.spokenText == "Bob Baker, Learning goalkeeper, Accepted on 13 Nov, No longer in the squad")
    }

    @Test func rowsUnderWayKeepTheSavedOrder() {
        let state = TrainingState(accepted: [Retraining(player: bob, position: .striker, acceptedOn: today),
                                             Retraining(player: alice, position: .goalkeeper, acceptedOn: today)])
        let rows = TrainingPresentation.underWay(state, inSquads: [alice: "Alice", bob: "Bob"], parameters: parameters)
        #expect(rows.map(\.id.player) == state.accepted.map(\.player))
    }

    @Test func aRowUnderWayIsSpokenWithItsProgress() throws {
        let choice = RetrainingChoice(player: alice, position: .defenderLeft)
        let state = TrainingState(accepted: [Retraining(player: alice, position: .defenderLeft, acceptedOn: today)],
                                  observations: [choice: [observation(0, 8)]])
        let row = try #require(TrainingPresentation.underWay(state, inSquads: [alice: "Alice"], parameters: parameters).first)
        #expect(row.spokenText == "Alice, Learning left back, Accepted on 13 Nov, Started at 8, Now 8, Solid at 15, "
                + "Familiarity at left back 8 so far: too early to tell")
    }

    // MARK: The track

    @Test func theTrackPlacesEachValueBetweenOneAndTwenty() {
        let track = RetrainingTrack(start: 8, latest: 12, solid: 15)
        #expect(RetrainingTrack.lowest == 1)
        #expect(RetrainingTrack.highest == 20)
        #expect(RetrainingTrack.fraction(1) == 0)
        #expect(RetrainingTrack.fraction(20) == 1)
        #expect(abs(RetrainingTrack.fraction(15) - 14.0 / 19.0) < 1e-12)
        // A figure outside the scale stays on the track.
        #expect(RetrainingTrack.fraction(0) == 0)
        #expect(RetrainingTrack.fraction(25) == 1)
        #expect(track.startText == "Started at 8")
        #expect(track.latestText == "Now 12")
        #expect(track.solidText == "Solid at 15")
        #expect(track.lowestText == "1")
        #expect(track.highestText == "20")
        #expect(track.startFraction == RetrainingTrack.fraction(8))
        #expect(track.latestFraction == RetrainingTrack.fraction(12))
        #expect(track.solidFraction == RetrainingTrack.fraction(15))
        #expect(track.gained == RetrainingTrack.fraction(8)...RetrainingTrack.fraction(12))
        // No gain drawn when he has not moved or has fallen back.
        #expect(RetrainingTrack(start: 8, latest: 8, solid: 15).gained == nil)
        #expect(RetrainingTrack(start: 9, latest: 7, solid: 15).gained == nil)
        let empty = RetrainingTrack(start: nil, latest: nil, solid: 15)
        #expect(empty.startFraction == nil)
        #expect(empty.latestFraction == nil)
        #expect(empty.gained == nil)
        #expect(empty.startText == nil)
        #expect(empty.latestText == nil)
        #expect(empty.solidText == "Solid at 15")
    }

    // MARK: Recruit instead

    @Test func theRecruitPartListsTheNeedsNobodySuitsAndThoseBeingRetrainedFor() {
        let part = TrainingPresentation.recruit(report(
            without: [RetrainingNeed(tactic: sample, slot: .GK), RetrainingNeed(tactic: "Another", slot: .D_CL)],
            beingRetrained: [RetrainingNeed(tactic: sample, slot: .D_L)]))
        #expect(part == .recruit(needs: ["Goalkeeper in Sample 4-2-3-1", "Left centre-back in Another"],
                                 alreadyRetraining: "Already being retrained for: left back in Sample 4-2-3-1"))
        #expect(part.emptyText == nil)
    }

    @Test func theRecruitPartWithNothingToRecruitSaysSoAndStillNamesThoseBeingRetrainedFor() {
        let part = TrainingPresentation.recruit(report(beingRetrained: [RetrainingNeed(tactic: sample, slot: .D_L)]))
        #expect(part == .recruit(needs: [], alreadyRetraining: "Already being retrained for: left back in Sample 4-2-3-1"))
        #expect(part.emptyText == "Every thin slot has someone who could learn it.")
        #expect(TrainingPresentation.recruit(report()) == .recruit(needs: [], alreadyRetraining: nil))
    }

    // MARK: Turned down

    @Test func turnedDownRowsNameThePlayerAndPositionInTheSavedOrder() {
        let state = TrainingState(rejected: [RetrainingChoice(player: bob, position: .goalkeeper),
                                             RetrainingChoice(player: alice, position: .defenderLeft),
                                             RetrainingChoice(player: alice, position: .goalkeeper)],
                                  names: [alice: "Saved Alice", bob: "Bob Baker"])
        let rows = TrainingPresentation.turnedDown(state, inSquads: [alice: "Alice Archer"])
        #expect(rows.map(\.name) == ["Alice Archer", "Alice Archer", "Bob Baker"])
        #expect(rows.map(\.positionText) == ["Learn goalkeeper", "Learn left back", "Learn goalkeeper"])
        #expect(rows.map(\.id) == [RetrainingChoice(player: alice, position: .goalkeeper),
                                   RetrainingChoice(player: alice, position: .defenderLeft),
                                   RetrainingChoice(player: bob, position: .goalkeeper)])
    }

    // MARK: The parts

    @Test func withTheAdviceReadyAllFourPartsShowInOrderEachWithItsEmptyLine() {
        let parts = TrainingPresentation.parts(report: report(), underWay: [], turnedDown: [])
        #expect(parts.map(\.heading) == ["Recommended", "Being retrained", "Recruit instead", "Turned down"])
        #expect(parts.map(\.emptyText) == ["No retraining is recommended today.", "Nobody is being retrained.",
                                           "Every thin slot has someone who could learn it.", "Nothing has been turned down."])
    }

    @Test func aPartWithEntriesHasNoEmptyLine() {
        let state = TrainingState(accepted: [Retraining(player: alice, position: .striker, acceptedOn: today)],
                                  rejected: [RetrainingChoice(player: bob, position: .goalkeeper)])
        let underWay = TrainingPresentation.underWay(state, inSquads: [alice: "A", bob: "B"], parameters: parameters)
        let turnedDown = TrainingPresentation.turnedDown(state, inSquads: [alice: "A", bob: "B"])
        let parts = TrainingPresentation.parts(report: report([recommendation(bob, name: "B")],
                                                              without: [RetrainingNeed(tactic: sample, slot: .GK)]),
                                               underWay: underWay, turnedDown: turnedDown)
        #expect(parts.map(\.emptyText) == [nil, nil, nil, nil])
    }

    @Test func withoutTheAdviceOnlyTheSavedPartsWithEntriesShow() {
        #expect(TrainingPresentation.parts(report: nil, underWay: [], turnedDown: []).isEmpty)
        let state = TrainingState(accepted: [Retraining(player: alice, position: .striker, acceptedOn: today)],
                                  rejected: [RetrainingChoice(player: bob, position: .goalkeeper)])
        let underWay = TrainingPresentation.underWay(state, inSquads: [:], parameters: parameters)
        let turnedDown = TrainingPresentation.turnedDown(state, inSquads: [:])
        #expect(TrainingPresentation.parts(report: nil, underWay: underWay, turnedDown: []).map(\.heading) == ["Being retrained"])
        #expect(TrainingPresentation.parts(report: nil, underWay: [], turnedDown: turnedDown).map(\.heading) == ["Turned down"])
        #expect(TrainingPresentation.parts(report: nil, underWay: underWay, turnedDown: turnedDown).map(\.heading)
                == ["Being retrained", "Turned down"])
    }

    @Test func theScreensOwnWords() {
        #expect(TrainingPresentation.explanation
                == "Accepting a retraining records it and reads his familiarity there at each import. Set it up in the game as well.")
        #expect(TrainingPresentation.familiarityLabel == "Familiarity now")
        #expect(TrainingPresentation.acceptTitle == "Accept")
        #expect(TrainingPresentation.notHimTitle == "Not him")
        #expect(TrainingPresentation.stopTitle == "Stop")
        #expect(TrainingPresentation.offerAgainTitle == "Offer again")
    }

    // MARK: On the captured squads

    private func squad(_ t: TestModel) throws -> AppModel {
        try t.importFirstTeam()
        try t.importU21()
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        t.model.addTactic(named: "4-2-3-1")
        return t.model
    }

    private func readyReport(_ model: AppModel, sourceLocation: SourceLocation = #_sourceLocation) throws -> AdvisorsReport {
        guard case .ready(let report) = model.adviceState else {
            Issue.record("expected advice, got \(model.adviceState)", sourceLocation: sourceLocation)
            throw CancellationError()
        }
        return report
    }

    private func cards(_ model: AppModel) -> [RecommendationCard] {
        model.trainingParts.compactMap { if case .recommended(let cards) = $0 { cards } else { nil } }.first ?? []
    }

    private func underWay(_ model: AppModel) -> [RetrainingRow] {
        model.trainingParts.compactMap { if case .underWay(let rows) = $0 { rows } else { nil } }.first ?? []
    }

    private func turnedDown(_ model: AppModel) -> [TurnedDownRow] {
        model.trainingParts.compactMap { if case .turnedDown(let rows) = $0 { rows } else { nil } }.first ?? []
    }

    @Test func theModelsCardsAreTheAdvicesRecommendationsInItsOrder() throws {
        let t = try TestModel()
        let model = try squad(t)
        let report = try readyReport(model)
        #expect(!report.training.recommendations.isEmpty)
        #expect(cards(model).map(\.choice) == report.training.recommendations.map(\.choice))
        #expect(model.trainingParts.map(\.heading) == ["Recommended", "Being retrained", "Recruit instead", "Turned down"])
    }

    @Test func acceptMovesHimFromTheCardsToTheRetrainingsUnderWay() throws {
        let t = try TestModel()
        let model = try squad(t)
        let card = try #require(cards(model).first)
        model.accept(card.choice)
        #expect(!cards(model).map(\.choice).contains(card.choice))
        #expect(!cards(model).map(\.choice.player).contains(card.choice.player))
        let row = try #require(underWay(model).first)
        #expect(underWay(model).count == 1)
        #expect(row.id == card.choice)
        #expect(row.name == card.name)
        #expect(row.positionText == card.headline.replacingOccurrences(of: "Learn ", with: "Learning "))
        #expect(row.acceptedText == "Accepted on 13 Nov")
        let familiarity = try #require(card.familiarityText.split(separator: " ").first.flatMap { Int($0) })
        #expect(row.track == RetrainingTrack(start: familiarity, latest: familiarity, solid: 15))
        #expect(row.departedStamp == nil)

        // Stop forgets it, and he is offered again.
        model.stopRetraining(card.choice)
        #expect(underWay(model).isEmpty)
        #expect(cards(model).map(\.choice).contains(card.choice))
    }

    @Test func notHimTurnsThePairDownAndOfferAgainBringsItBack() throws {
        let t = try TestModel()
        let model = try squad(t)
        let card = try #require(cards(model).first)
        model.reject(card.choice)
        #expect(!cards(model).map(\.choice).contains(card.choice))
        #expect(turnedDown(model).map(\.id) == [card.choice])
        #expect(turnedDown(model).first?.name == card.name)
        #expect(turnedDown(model).first?.positionText == card.headline)
        model.allowAgain(card.choice)
        #expect(turnedDown(model).isEmpty)
        #expect(cards(model).map(\.choice).contains(card.choice))
    }

    @Test func theRecruitPartIsTheAdvicesNeeds() throws {
        let t = try TestModel()
        let model = try squad(t)
        let report = try readyReport(model)
        let recruit = try #require(model.trainingParts.first { $0.heading == "Recruit instead" })
        #expect(recruit == TrainingPresentation.recruit(report.training))
    }

    @Test func aRetrainingOfAPlayerWhoHasLeftShowsWithoutTheAdviceAndCanBeStopped() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let player = try #require(t.model.players.first { $0.squad == .firstTeam })
        let position = try #require(Position.allCases.min { (player.familiarity[$0] ?? 0) < (player.familiarity[$1] ?? 0) })
        let choice = RetrainingChoice(player: player.id, position: position)
        t.model.accept(choice)
        // No tactic, so no advice: the saved part still shows.
        #expect(t.model.trainingParts.map(\.heading) == ["Being retrained"])
        #expect(underWay(t.model).first?.departedStamp == nil)

        // The first team pasted without his row: he has left.
        let rows = try Captures.firstTeam.components(separatedBy: "\r\n")
        let kept = rows.filter { !$0.contains(player.name) }
        try #require(kept.count == rows.count - 1)
        t.importSquad(.firstTeam, paste: kept.joined(separator: "\r\n"), grids: try Captures.firstTeamGrids)
        let row = try #require(underWay(t.model).first)
        #expect(row.name == player.name)
        #expect(row.track == nil)
        #expect(row.progressText == nil)
        #expect(row.departedStamp == StatusStamp(text: "No longer in the squad", isOut: true))
        t.model.stopRetraining(row.id)
        #expect(t.model.trainingParts.isEmpty)
    }
}
