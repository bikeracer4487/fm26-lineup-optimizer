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

    @Test func acceptingAPlayerNotInTheSquadHasNoFirstObservation() throws {
        let t = try TestModel()
        try t.importFirstTeam()
        let choice = RetrainingChoice(player: PlayerID.fmrte(999_999), position: .goalkeeper)
        t.model.accept(choice)
        #expect(t.model.training.accepted.map(\.player) == [choice.player])
        #expect(t.model.training.observations[choice] == nil)
        #expect(t.model.training.names.isEmpty)
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
