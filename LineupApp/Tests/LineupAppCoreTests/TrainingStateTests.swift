import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

@MainActor @Suite struct TrainingStateTests {
    private let today = TestModel.today
    private let alice = PlayerID.fmrte(1)
    private let bob = PlayerID.fmrte(2)

    private func observation(_ days: Int, _ familiarity: Int) -> FamiliarityObservation {
        FamiliarityObservation(day: today.adding(days: days), familiarity: familiarity)
    }

    /// The player's familiarity at the position in the model's squads; nil when he is not in them.
    private func familiarity(_ model: AppModel, _ player: PlayerID, _ position: Position) -> Int? {
        model.squad.book.allPlayers.first { $0.id == player }?.familiarity[position]
    }

    /// The first-team player first by name, and the position he is least familiar with, first in `Position.allCases`
    /// among equals.
    private func learner(_ model: AppModel) throws -> RetrainingChoice {
        try leastFamiliar(try #require(model.players.first { $0.squad == .firstTeam }))
    }

    private func leastFamiliar(_ player: Player) throws -> RetrainingChoice {
        let position = try #require(Position.allCases.min { (player.familiarity[$0] ?? 0) < (player.familiarity[$1] ?? 0) })
        return RetrainingChoice(player: player.id, position: position)
    }

    private func withDirectory(_ body: (URL) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("training-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try body(dir)
    }

    // MARK: The file

    @Test func theTrainingFileRoundTrips() throws {
        let state = TrainingState(
            accepted: [Retraining(player: alice, position: .defenderLeft, acceptedOn: today)],
            rejected: [RetrainingChoice(player: bob, position: .goalkeeper)],
            observations: [RetrainingChoice(player: alice, position: .defenderLeft): [observation(0, 8), observation(7, 10)]],
            names: [alice: "Alice", bob: "Bob"])
        try withDirectory { dir in
            let store = Store(directory: dir)
            try store.save(state, to: .training)
            #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("training.json").path))
            let loaded = store.load(.training, as: TrainingState.self, otherwise: TrainingState())
            #expect(loaded.value == state)
            #expect(loaded.notice == nil)
        }
    }

    @Test func theSameStateBuiltInADifferentOrderWritesTheSameBytes() throws {
        let players = (1...6).map { PlayerID.fmrte($0) }
        func state(reversed: Bool) -> TrainingState {
            var state = TrainingState()
            for player in reversed ? players.reversed() : players {
                let rejected: [Position] = reversed ? [.defenderLeft, .goalkeeper] : [.goalkeeper, .defenderLeft]
                for position in rejected { state.rejected.insert(RetrainingChoice(player: player, position: position)) }
                state.accepted.append(Retraining(player: player, position: .striker, acceptedOn: today))
                state.observations[RetrainingChoice(player: player, position: .striker)] = [observation(0, 5), observation(3, 6)]
                state.names[player] = "P\(player.key)"
            }
            return state
        }
        var bytes: [Data] = []
        for reversed in [false, true] {
            try withDirectory { dir in
                try Store(directory: dir).save(state(reversed: reversed), to: .training)
                bytes.append(try Data(contentsOf: dir.appendingPathComponent("training.json")))
            }
        }
        #expect(bytes[0] == bytes[1])
        let text = String(decoding: bytes[0], as: UTF8.self)
        func position(_ needle: String, after start: String.Index? = nil) -> Int {
            let range = text.range(of: needle, range: (start ?? text.startIndex)..<text.endIndex)!
            return range.lowerBound.utf16Offset(in: text)
        }
        // Rejected pairs by player key, then by place in `Position.allCases`: goalkeeper before left back.
        let rejectedStart = text.range(of: "\"rejected\"")!.upperBound
        #expect(position("\"fmrte:1\"", after: rejectedStart) < position("\"fmrte:2\"", after: rejectedStart))
        #expect(position("\"GK\"", after: rejectedStart) < position("\"D (L)\"", after: rejectedStart))
        // Accepted and observed pairs by player key.
        let acceptedStart = text.range(of: "\"accepted\"")!.upperBound
        #expect(position("\"fmrte:1\"", after: acceptedStart) < position("\"fmrte:2\"", after: acceptedStart))
        let observedStart = text.range(of: "\"observations\"")!.upperBound
        #expect(position("\"fmrte:1\"", after: observedStart) < position("\"fmrte:2\"", after: observedStart))
    }

    @Test func aMissingTrainingFileMeansNothingAcceptedAndNoNotice() throws {
        try withDirectory { dir in
            let store = Store(directory: dir)
            try store.save(AppSettings(currentDate: today), to: .settings)
            let loaded = store.load(.training, as: TrainingState.self, otherwise: TrainingState())
            #expect(loaded.value == TrainingState())
            #expect(loaded.notice == nil)
            #expect(loaded.replaceOnDisk)
        }
        let t = try TestModel()
        t.model.addFixture(date: today, opponent: "Rovers", importance: .medium)
        try FileManager.default.removeItem(at: t.directory.appendingPathComponent("training.json"))
        let model = t.reopened()
        #expect(model.training == TrainingState())
        #expect(model.notices.isEmpty)
    }

    @Test func anUnreadableTrainingFileGivesANoticeAFreshStartAndIsKept() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        t.model.accept(try learner(t.model))
        try Data("{".utf8).write(to: t.directory.appendingPathComponent("training.json"))
        let model = t.reopened()
        #expect(model.training == TrainingState())
        #expect(model.notices.map(\.text) == [
            "Your retraining choices could not be read as saved data (the file may have been cut short), so the list "
                + "starts empty. The unreadable file was kept as training.unreadable-1.json."])
        #expect(try Data(contentsOf: t.directory.appendingPathComponent("training.unreadable-1.json")) == Data("{".utf8))
        // The fresh start is written in its place, so the next start has nothing to report.
        #expect(t.reopened().notices.isEmpty)
    }

    @Test func aTrainingFileThatCouldNotBeReadOrMovedAsideIsNeverSavedOver() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let file = t.directory.appendingPathComponent("training.json")
        try Data("not json".utf8).write(to: file)
        struct Refused: Error {}
        let store = Store(directory: t.directory, move: { _, _ in throw Refused() }, copy: { _, _ in throw Refused() })
        let model = AppModel(store: store, environment: t.input.environment)
        model.accept(try learner(model))
        #expect(model.training.accepted.count == 1)
        #expect(try Data(contentsOf: file) == Data("not json".utf8))
        #expect(model.notices.contains { $0.text == StoreError.leftUnread(.training, path: file.path).description })
    }

    // MARK: Recording observations

    @Test func oneObservationADayTheLaterReplacingTheEarlierAndNoneBeforeTheAcceptance() {
        let choice = RetrainingChoice(player: alice, position: .defenderLeft)
        var state = TrainingState(accepted: [Retraining(player: alice, position: .defenderLeft, acceptedOn: today)],
                                  rejected: [], observations: [:], names: [alice: "Alice"])
        state.record(8, for: choice, on: today)
        state.record(9, for: choice, on: today.adding(days: 7))
        state.record(10, for: choice, on: today.adding(days: 7))   // the later one that day replaces the earlier
        state.record(5, for: choice, on: today.adding(days: -1))   // before the acceptance: not recorded
        state.record(11, for: choice, on: today.adding(days: 3))   // kept in day order
        #expect(state.observations[choice] == [observation(0, 8), observation(3, 11), observation(7, 10)])
        // A pair that is not accepted records nothing.
        state.record(12, for: RetrainingChoice(player: alice, position: .goalkeeper), on: today)
        state.record(12, for: RetrainingChoice(player: bob, position: .defenderLeft), on: today)
        #expect(state.observations.count == 1)
    }

    // MARK: The owner's choices

    @Test func acceptingRecordsTheAcceptanceTheFirstObservationAndTheNameAndSavesThem() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        var settings = t.model.settings
        settings.currentDate = today.adding(days: 2)
        t.model.update(settings)
        let choice = try learner(t.model)
        let name = try #require(t.model.players.first { $0.id == choice.player }).name
        let familiarity = try #require(familiarity(t.model, choice.player, choice.position))
        t.model.accept(choice)
        #expect(t.model.training.accepted == [Retraining(player: choice.player, position: choice.position,
                                                         acceptedOn: today.adding(days: 2))])
        #expect(t.model.training.observations == [choice: [FamiliarityObservation(day: today.adding(days: 2),
                                                                                  familiarity: familiarity)]])
        #expect(t.model.training.names == [choice.player: name])
        #expect(t.model.training.rejected.isEmpty)
        let again = t.reopened()
        #expect(again.training == t.model.training)
        #expect(again.notices.isEmpty)
    }

    @Test func acceptingOrRejectingAPlayerInNoSquadDoesNothing() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let choice = RetrainingChoice(player: PlayerID.fmrte(999_999), position: .goalkeeper)
        let planned = t.model.timesPlanned
        t.model.accept(choice)
        #expect(t.model.training == TrainingState())
        t.model.reject(choice)
        #expect(t.model.training == TrainingState())
        #expect(t.model.timesPlanned == planned)
        #expect(t.reopened().training == TrainingState())
    }

    @Test func aStateBuiltUnsortedEqualsItsOwnRoundTrip() throws {
        let unsorted = TrainingState(
            accepted: [Retraining(player: bob, position: .striker, acceptedOn: today),
                       Retraining(player: alice, position: .defenderLeft, acceptedOn: today)],
            names: [alice: "Alice", bob: "Bob"])
        #expect(unsorted.accepted.map(\.player) == [alice, bob])
        let data = try JSONEncoder().encode(unsorted)
        #expect(try JSONDecoder().decode(TrainingState.self, from: data) == unsorted)
    }

    @Test func aPlayerTrainsOnePositionAtATime() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let first = try learner(t.model)
        let second = RetrainingChoice(
            player: first.player, position: try #require(Position.allCases.first { $0 != first.position }))
        t.model.accept(first)
        t.model.accept(second)
        #expect(t.model.training.accepted.map(\.position) == [second.position])
        #expect(t.model.training.observations[first] == nil)
        #expect(t.model.training.observations[second]?.count == 1)
        // Accepting the same pair again changes nothing.
        let planned = t.model.timesPlanned
        let before = t.model.training
        t.model.accept(second)
        #expect(t.model.training == before)
        #expect(t.model.timesPlanned == planned)
    }

    @Test func acceptRejectStopAndAllowAgainAndTheirEffectOnEachOther() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let model = t.model
        let choice = try learner(model)
        let name = try #require(model.players.first { $0.id == choice.player }).name

        // A rejection is undone by accepting the same pair.
        model.reject(choice)
        #expect(model.training.rejected == [choice])
        #expect(model.training.accepted.isEmpty)
        #expect(model.training.names == [choice.player: name])
        model.accept(choice)
        #expect(model.training.rejected.isEmpty)
        #expect(model.training.accepted.map(\.player) == [choice.player])

        // A rejection leaves an acceptance alone; allowing again undoes only the rejection.
        model.reject(choice)
        #expect(model.training.rejected == [choice])
        #expect(model.training.accepted.map(\.player) == [choice.player])
        #expect(model.training.observations[choice]?.count == 1)
        model.allowAgain(choice)
        #expect(model.training.rejected.isEmpty)
        #expect(model.training.accepted.map(\.player) == [choice.player])

        // Stopping forgets the acceptance and its observations, and the name with them.
        model.stopRetraining(choice)
        #expect(model.training == TrainingState())

        // Allowing again a rejected pair that is all the state holds of him drops his name too.
        model.reject(choice)
        model.allowAgain(choice)
        #expect(model.training == TrainingState())
        #expect(t.reopened().training == TrainingState())
    }

    @Test func eachChangeReplansAndAChangeThatChangesNothingDoesNot() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let model = t.model
        let choice = try learner(model)
        var count = model.timesPlanned
        func replanned(_ what: String, _ expected: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
            #expect((model.timesPlanned > count) == expected, "\(what)", sourceLocation: sourceLocation)
            count = model.timesPlanned
        }
        model.accept(choice); replanned("accept", true)
        model.reject(choice); replanned("reject", true)
        model.reject(choice); replanned("reject again", false)
        model.allowAgain(choice); replanned("allow again", true)
        model.allowAgain(choice); replanned("allow again twice", false)
        model.stopRetraining(choice); replanned("stop", true)
        model.stopRetraining(choice); replanned("stop again", false)
    }

    // MARK: A second click

    /// The first two first-team players by name and the positions they are least familiar with.
    private func twoLearners(_ model: AppModel) throws -> (RetrainingChoice, RetrainingChoice) {
        let players = model.players.filter { $0.squad == .firstTeam }
        try #require(players.count >= 2)
        return (try leastFamiliar(players[0]), try leastFamiliar(players[1]))
    }

    @Test func aTrainingActionWithinTheIntervalOfThePreviousOneIsIgnored() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let (first, second) = try twoLearners(t.model)
        t.input.tick = 0
        t.input.uptime = 1_000
        t.model.accept(first)
        #expect(t.model.training.accepted.map(\.player) == [first.player])
        // The second click of a double-click lands on the next player: ignored, whatever the action.
        t.input.uptime += AppModel.trainingActionInterval / 2
        t.model.accept(second)
        t.model.reject(second)
        t.model.stopRetraining(first)
        #expect(t.model.training.accepted.map(\.player) == [first.player])
        #expect(t.model.training.rejected.isEmpty)
    }

    @Test func aTrainingActionAfterTheIntervalGoesAhead() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let (first, second) = try twoLearners(t.model)
        t.input.tick = 0
        t.input.uptime = 1_000
        t.model.accept(first)
        t.input.uptime += AppModel.trainingActionInterval
        t.model.accept(second)
        #expect(Set(t.model.training.accepted.map(\.player)) == [first.player, second.player])
        t.input.uptime += AppModel.trainingActionInterval + 1
        t.model.reject(second)
        #expect(t.model.training.rejected == [second])
    }

    @Test func theIntervalRunsFromTheEndOfTheLastActionNotItsStart() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let (first, second) = try twoLearners(t.model)
        t.input.tick = 0
        // The accept starts at 1000.2 and, replanning, finishes 0.8 s later at 1001. (Times whose differences are exact.)
        t.input.readings = [1_000.2, 1_001]
        t.model.accept(first)
        #expect(t.model.training.accepted.map(\.player) == [first.player])
        // A click queued during the replan arrives 0.2 s after it finished: ignored.
        t.input.uptime = 1_001.2
        t.model.accept(second)
        t.model.reject(second)
        #expect(t.model.training.accepted.map(\.player) == [first.player])
        #expect(t.model.training.rejected.isEmpty)
        // Half a second after the end, the next action goes ahead.
        t.input.uptime = 1_001.5
        t.model.reject(second)
        #expect(t.model.training.rejected == [second])
    }

    @Test func eachKindOfTrainingActionIsTimedFromItsEnd() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let (first, second) = try twoLearners(t.model)
        t.input.tick = 0
        // Turning down, 0.8 s long; offering again 0.2 s after it is ignored, 0.5 s after it goes ahead.
        t.input.readings = [1_000.2, 1_001]
        t.model.reject(second)
        t.input.uptime = 1_001.2
        t.model.allowAgain(second)
        #expect(t.model.training.rejected == [second])
        // Accepting, 0.8 s long, starting 0.7 s after the turning down ended; stopping 0.2 s after it is ignored, 0.5 s
        // after it goes ahead.
        t.input.readings = [1_001.7, 1_002.5]
        t.model.accept(first)
        #expect(t.model.training.accepted.map(\.player) == [first.player])
        t.input.uptime = 1_002.7
        t.model.stopRetraining(first)
        #expect(t.model.training.accepted.map(\.player) == [first.player])
        t.input.uptime = 1_003
        t.model.stopRetraining(first)
        #expect(t.model.training.accepted.isEmpty)
    }

    @Test func allowingAgainWithinTheIntervalIsIgnored() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let choice = try learner(t.model)
        t.input.tick = 0
        t.input.uptime = 1_000
        t.model.reject(choice)
        t.input.uptime += AppModel.trainingActionInterval / 2
        t.model.allowAgain(choice)
        #expect(t.model.training.rejected == [choice])
    }

    @Test func anIgnoredActionDoesNotMoveTheWindow() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let (first, second) = try twoLearners(t.model)
        t.input.tick = 0
        t.input.uptime = 1_000
        t.model.accept(first)
        t.input.uptime = 1_000.25
        t.model.accept(second)
        #expect(t.model.training.accepted.map(\.player) == [first.player])
        // Half a second after the last action that went ahead, not after the one ignored.
        t.input.uptime = 1_000.5
        t.model.reject(second)
        #expect(t.model.training.rejected == [second])
    }

    @Test func theSampleWindowUsesTheMacsMonotonicClockAndThePicturesTheScriptedOne() throws {
        // Two readings with nothing between them: the real clock barely moves, inside the interval, so a second click
        // is ignored. (Each action replans, which in a debug build can itself take longer than the interval.)
        let model = try SampleData.interactiveModel(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let before = model.environment.now()
        let real = ProcessInfo.processInfo.systemUptime
        let after = model.environment.now()
        #expect(before <= real && real <= after)
        #expect(after - before < AppModel.trainingActionInterval)
        // The scripted clock of the picture run and the tests moves a second at each reading.
        let scripted = try SampleData.model(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: scripted.store.directory) }
        let first = scripted.environment.now()
        #expect(scripted.environment.now() - first == 1)
    }

    @Test func theFirstTrainingActionIsNeverIgnored() throws {
        // A model whose clock reads 0 on its first training action, as a monotonic clock may soon after starting.
        let t = try TestModel()
        try t.importFirstTeam()
        let choice = try learner(t.model)
        t.input.tick = 0
        t.input.uptime = 0
        t.model.reject(choice)
        #expect(t.model.training.rejected == [choice])
        #expect(AppModel.trainingActionInterval == 0.5)
    }

    // MARK: What the owner is told

    @Test func acceptingAndTurningDownSayWhatHappenedInTheEnginesWords() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let (first, second) = try twoLearners(t.model)
        let names = Dictionary(t.model.players.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        let before = t.model.notices
        t.model.accept(first)
        let accepted = AdvisorText.nowLearning(name: try #require(names[first.player]), position: first.position)
        #expect(t.model.notices.map(\.text) == before.map(\.text) + [accepted])
        // A new training notice replaces the previous one.
        t.model.reject(second)
        let turnedDown = AdvisorText.notOfferedAgain(name: try #require(names[second.player]), position: second.position)
        #expect(t.model.notices.map(\.text) == before.map(\.text) + [turnedDown])
        // A notice about something else stays; the next training notice still replaces only its own.
        t.model.addNotice("Something else")
        t.model.accept(second)
        #expect(t.model.notices.map(\.text) == before.map(\.text) + ["Something else",
            AdvisorText.nowLearning(name: try #require(names[second.player]), position: second.position)])
        // Dismissed, it is gone, and the next one is shown again.
        let showing = try #require(t.model.notices.last)
        t.model.dismiss(showing)
        #expect(!t.model.notices.contains(showing))
        t.model.reject(first)
        #expect(t.model.notices.last?.text
                == AdvisorText.notOfferedAgain(name: try #require(names[first.player]), position: first.position))
    }

    @Test func anIgnoredOrEmptyTrainingActionSaysNothing() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let (first, second) = try twoLearners(t.model)
        t.model.accept(RetrainingChoice(player: PlayerID.fmrte(999_999), position: .goalkeeper))
        #expect(t.model.notices.isEmpty)
        t.input.tick = 0
        t.input.uptime = 1_000
        t.model.accept(first)
        t.model.accept(second)
        #expect(t.model.notices.count == 1)
    }

    @Test func stoppingOrAllowingAgainTakesAwayTheTrainingNoticeAndSaysNothingNew() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let (first, second) = try twoLearners(t.model)
        t.model.addNotice("Something else")
        t.model.accept(first)
        #expect(t.model.notices.count == 2)
        // "… is now learning …" no longer holds once the retraining is stopped; the other notice stays.
        t.model.stopRetraining(RetrainingChoice(player: first.player, position: first.position))
        #expect(t.model.notices.map(\.text) == ["Something else"])
        #expect(t.model.trainingNotice == nil)

        t.model.reject(second)
        #expect(t.model.notices.count == 2)
        t.model.allowAgain(second)
        #expect(t.model.notices.map(\.text) == ["Something else"])

        // With no training notice showing, stopping leaves the notices alone.
        t.model.accept(first)
        let showing = try #require(t.model.notices.last)
        t.model.dismiss(showing)
        t.model.stopRetraining(first)
        #expect(t.model.notices.map(\.text) == ["Something else"])
    }

    @Test func anIgnoredStopLeavesTheTrainingNotice() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let choice = try learner(t.model)
        t.input.tick = 0
        t.input.uptime = 1_000
        t.model.accept(choice)
        t.input.uptime += AppModel.trainingActionInterval / 2
        t.model.stopRetraining(choice)
        #expect(t.model.notices.count == 1)
        #expect(t.model.training.accepted.map(\.player) == [choice.player])
    }

    // MARK: Observations at each import

    @Test func anImportOnTheSameDayReplacesThatDaysObservation() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let choice = try learner(t.model)
        t.model.accept(choice)
        let first = t.model.training.observations[choice]
        try t.importFirstTeam()
        #expect(t.model.training.observations[choice] == first)
        #expect(first?.count == 1)
    }

    @Test func anImportOnALaterDayAddsAnObservationAndOneDatedBeforeTheAcceptanceAddsNone() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let choice = try learner(t.model)
        t.model.accept(choice)
        let familiarity = try #require(familiarity(t.model, choice.player, choice.position))

        // The game's date moved back before the acceptance: the import is dated before it, so it records nothing.
        t.model.moveToday(by: -2)
        try t.importFirstTeam()
        #expect(t.model.training.observations[choice]?.map(\.day) == [today])

        t.model.moveToday(by: 9)
        try t.importFirstTeam()
        #expect(t.model.training.observations[choice] == [
            FamiliarityObservation(day: today, familiarity: familiarity),
            FamiliarityObservation(day: today.adding(days: 7), familiarity: familiarity)])
        #expect(t.reopened().training == t.model.training)
    }

    @Test func anImportOfAnotherSquadRecordsNothingForHim() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let choice = try learner(t.model)
        t.model.accept(choice)
        t.model.moveToday(by: 1)
        try t.importU21()
        #expect(t.model.training.observations[choice]?.map(\.day) == [today])
        try t.importFirstTeam()
        #expect(t.model.training.observations[choice]?.map(\.day) == [today, today.adding(days: 1)])
    }

    @Test func aFailedImportRecordsNothing() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let choice = try learner(t.model)
        t.model.accept(choice)
        t.model.moveToday(by: 1)
        t.importSquad(.firstTeam, paste: "", grids: try Captures.firstTeamGrids)
        guard case .failed? = t.model.lastImport else { Issue.record("expected a failed import"); return }
        #expect(t.model.training.observations[choice]?.count == 1)
    }

    /// The first team pasted without its first row: the player in that row has left.
    private func importFirstTeamWithoutOneRow(_ t: TestModel) throws -> PlayerID {
        let rows = try Captures.firstTeam.components(separatedBy: "\r\n")
        t.importSquad(.firstTeam, paste: rows.dropFirst().joined(separator: "\r\n"), grids: try Captures.firstTeamGrids)
        guard case .imported(let summary)? = t.model.lastImport else {
            Issue.record("expected an import, got \(String(describing: t.model.lastImport))")
            return PlayerID(key: "")
        }
        return try #require(summary.change.removed.first)
    }

    @Test func aPlayerWhoHasLeftKeepsHisRetrainingButGetsNoObservationAndIsNotHandedToThePlanner() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        try t.importU21()
        // The player in the first row of the paste leaves; another first-team player stays.
        let firstRow = try #require(t.model.squad.book.current[.firstTeam]?.first)
        let leaves = try leastFamiliar(firstRow)
        let stays = try leastFamiliar(try #require(t.model.players.first { $0.squad == .firstTeam && $0.id != firstRow.id }))
        t.model.accept(stays)
        t.model.accept(leaves)
        let handed: Set<PlayerID> = Set(t.model.retrainingForPlan.map(\.player))
        #expect(handed == [stays.player, leaves.player])

        t.model.moveToday(by: 3)
        let left = try importFirstTeamWithoutOneRow(t)
        #expect(left == leaves.player)
        #expect(t.model.training.accepted.count == 2)
        #expect(t.model.training.observations[leaves]?.map(\.day) == [today])
        #expect(t.model.training.observations[stays]?.map(\.day) == [today, today.adding(days: 3)])
        #expect(t.model.retrainingForPlan.map(\.player) == [stays.player])
        #expect(t.model.training.names[leaves.player] != nil)
    }
}
