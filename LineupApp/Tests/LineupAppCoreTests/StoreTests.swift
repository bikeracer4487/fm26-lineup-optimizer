import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

@Suite struct StoreTests {
    private func withStore(_ body: (Store, URL) throws -> Void) throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("store-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        try body(Store(directory: dir), dir)
    }

    private let day = Day(year: 2026, month: 11, day: 13)!
    private let tacticID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private let alice = PlayerID.fmrte(1)
    private let bob = PlayerID.fmrte(2)

    private var tactic: Tactic {
        Tactic(name: "Test", inPossession: [.GK: "Goalkeeper"], outOfPossession: [.GK: "Goalkeeper"],
               mapping: [.GK: .GK])
    }
    private var fixture: StoredFixture {
        StoredFixture(id: FixtureID("f1"), date: day, opponent: "Rovers", importance: .high,
                      tacticID: tacticID, overrides: [.GK: alice], rejected: [bob])
    }
    private var record: ConfirmedRecord {
        ConfirmedRecord(lineup: ConfirmedLineup(fixture: FixtureID("f1"), date: day, starters: [.GK: alice]),
                        names: [alice: "Alice"], tacticName: "Test", awaitingImport: [.firstTeam, .u21])
    }
    private var settings: AppSettings {
        var s = AppSettings(currentDate: day)
        s.clubName = "Oxford City"; s.primaryTacticID = tacticID; s.conditionFloor = 80
        s.fmrteConfigPath = "/tmp/config.json"
        return s
    }
    private var squad: SquadState {
        var s = SquadState()
        s.importedOn = [.firstTeam: day]
        return s
    }

    @Test func everyStoredTypeRoundTrips() throws {
        try withStore { store, _ in
            try store.save(settings, to: .settings)
            try store.save([StoredTactic(id: tacticID, tactic: tactic)], to: .tactics)
            try store.save([fixture], to: .fixtures)
            try store.save([record], to: .history)
            try store.save(squad, to: .squad)
            #expect(store.load(.settings, as: AppSettings.self, otherwise: AppSettings(currentDate: day)).value == settings)
            #expect(store.load(.tactics, as: [StoredTactic].self, otherwise: []).value == [StoredTactic(id: tacticID, tactic: tactic)])
            #expect(store.load(.fixtures, as: [StoredFixture].self, otherwise: []).value == [fixture])
            #expect(store.load(.history, as: [ConfirmedRecord].self, otherwise: []).value == [record])
            let loaded = store.load(.squad, as: SquadState.self, otherwise: SquadState())
            #expect(loaded.value == squad)
            #expect(loaded.notice == nil)
        }
    }

    @Test func savingTheSameStateBuiltInADifferentOrderWritesTheSameBytes() throws {
        func state(reversed: Bool) -> ([StoredFixture], [ConfirmedRecord]) {
            var slots: [(SlotID, PlayerID)] = [(.GK, PlayerID.fmrte(1)), (.D_C, PlayerID.fmrte(2)),
                                               (.M_C, PlayerID.fmrte(3)), (.ST_C, PlayerID.fmrte(4)),
                                               (.AM_L, PlayerID.fmrte(5)), (.D_L, PlayerID.fmrte(6))]
            var rejected = (10...30).map { PlayerID.fmrte($0) }
            if reversed { slots.reverse(); rejected.reverse() }
            var overrides: [SlotID: PlayerID] = [:]
            var names: [PlayerID: String] = [:]
            for (slot, id) in slots { overrides[slot] = id; names[id] = "P\(id.key)" }
            let fixture = StoredFixture(id: FixtureID("f1"), date: day, opponent: "Rovers", importance: .high,
                                        overrides: overrides, rejected: Set(rejected))
            let awaited: [Squad] = reversed ? [.u18, .u21, .firstTeam] : [.firstTeam, .u21, .u18]
            let record = ConfirmedRecord(
                lineup: ConfirmedLineup(fixture: FixtureID("f1"), date: day, starters: overrides),
                names: names, tacticName: "T", awaitingImport: Set(awaited))
            return ([fixture], [record])
        }
        var bytes: [Data] = []
        var texts: [String] = []
        for reversed in [false, true] {
            try withStore { store, dir in
                let (fixtures, history) = state(reversed: reversed)
                try store.save(fixtures, to: .fixtures)
                try store.save(history, to: .history)
                let data = try Data(contentsOf: dir.appendingPathComponent("fixtures.json"))
                    + Data(contentsOf: dir.appendingPathComponent("history.json"))
                bytes.append(data)
                texts.append(String(decoding: data, as: UTF8.self))
            }
        }
        #expect(bytes[0] == bytes[1])
        let text = texts[0]
        func position(_ needle: String) -> Int { text.range(of: needle)!.lowerBound.utf16Offset(in: text) }
        // Slot keys appear in sorted order (D_C < D_L < GK < M_C < ST_C ... "AM_L" first).
        #expect(position("\"AM_L\"") < position("\"D_C\""))
        #expect(position("\"D_C\"") < position("\"D_L\""))
        #expect(position("\"D_L\"") < position("\"GK\""))
        #expect(position("\"GK\"") < position("\"M_C\""))
        #expect(position("\"M_C\"") < position("\"ST_C\""))
        // Rejected players are listed in key order.
        #expect(position("fmrte:10") < position("fmrte:11"))
        #expect(position("fmrte:11") < position("fmrte:12"))
        // Awaited squads are listed by their raw values.
        #expect(position("\"firstTeam\"") < position("\"u18\""))
        #expect(position("\"u18\"") < position("\"u21\""))
    }

    @Test func aHistoryFileWithoutTheNewFieldLoadsWithNothingAwaited() throws {
        try withStore { store, dir in
            let saved = #"""
            {"version": 1, "value": [{"lineup": {"fixture": "f1", "date": "2026-11-13", "starters": {"GK": "fmrte:1"}},
              "names": {"fmrte:1": "Alice"}, "tacticName": "Test"}]}
            """#
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data(saved.utf8).write(to: dir.appendingPathComponent("history.json"))
            let loaded = store.load(.history, as: [ConfirmedRecord].self, otherwise: [])
            #expect(loaded.notice == nil)
            var expected = record
            expected.awaitingImport = []
            #expect(loaded.value == [expected])
        }
    }

    @Test func rejectedPlayersRoundTripAsASet() throws {
        let data = try JSONEncoder().encode(fixture)
        #expect(try JSONDecoder().decode(StoredFixture.self, from: data) == fixture)
    }

    @Test func aVersionBelowOneOrNoVersionIsKeptAside() throws {
        for (name, body) in [("zero", #"{"version": 0, "value": []}"#), ("negative", #"{"version": -1, "value": []}"#),
                             ("missing", #"{"value": []}"#)] {
            try withStore { store, dir in
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try Data(body.utf8).write(to: dir.appendingPathComponent("fixtures.json"))
                let loaded = store.load(.fixtures, as: [StoredFixture].self, otherwise: [])
                #expect(loaded.value.isEmpty, "\(name)")
                #expect(loaded.notice != nil, "\(name)")
                expectKeptAside(dir, original: "fixtures.json", kept: "fixtures.unreadable-1.json")
            }
        }
    }

    @Test func theNoticeForAnUnreadableFileSaysWhatWasLostAndWhereItWentWords() throws {
        try withStore { store, dir in
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data("{".utf8).write(to: dir.appendingPathComponent("fixtures.json"))
            let loaded = store.load(.fixtures, as: [StoredFixture].self, otherwise: [])
            #expect(loaded.notice == "Your saved fixtures could not be read as saved data (the file may have been cut short), so the list starts empty. The unreadable file was kept as fixtures.unreadable-1.json.")
        }
    }

    @Test func aFailedMoveFallsBackToACopyAndTheBadFileIsNotLeftToBeOverwritten() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("store-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        struct Refused: Error {}
        let store = Store(directory: dir, move: { _, _ in throw Refused() })
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: dir.appendingPathComponent("fixtures.json"))
        let loaded = store.load(.fixtures, as: [StoredFixture].self, otherwise: [])
        #expect(try #require(loaded.notice).contains("fixtures.unreadable-1.json"))
        #expect(try Data(contentsOf: dir.appendingPathComponent("fixtures.unreadable-1.json")) == Data("{".utf8))
    }

    @Test func whenNothingCanKeepTheFileAsideTheNoticeSaysItWillBeReplaced() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("store-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        struct Refused: Error {}
        let store = Store(directory: dir, move: { _, _ in throw Refused() }, copy: { _, _ in throw Refused() })
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{".utf8).write(to: dir.appendingPathComponent("fixtures.json"))
        let loaded = store.load(.fixtures, as: [StoredFixture].self, otherwise: [])
        #expect(try #require(loaded.notice).contains("will be replaced the next time"))
    }

    @Test func aFirstRunHasNoNotices() throws {
        try withStore { store, _ in
            #expect(store.load(.settings, as: AppSettings.self, otherwise: AppSettings(currentDate: day)).notice == nil)
            #expect(store.load(.tactics, as: [StoredTactic].self, otherwise: []).notice == nil)
            #expect(store.load(.fixtures, as: [StoredFixture].self, otherwise: []).notice == nil)
            #expect(store.load(.history, as: [ConfirmedRecord].self, otherwise: []).notice == nil)
            let squad = store.load(.squad, as: SquadState.self, otherwise: SquadState())
            #expect(squad.notice == nil)
            #expect(squad.value == SquadState())
        }
    }

    @Test func aMissingFileBesideOthersIsNoticed() throws {
        try withStore { store, _ in
            try store.save(settings, to: .settings)
            let loaded = store.load(.fixtures, as: [StoredFixture].self, otherwise: [])
            #expect(loaded.value.isEmpty)
            #expect(loaded.notice == "No saved fixtures were found, so the list starts empty.")
        }
    }

    private func expectKeptAside(_ dir: URL, original: String, kept: String) {
        let fm = FileManager.default
        #expect(!fm.fileExists(atPath: dir.appendingPathComponent(original).path))
        #expect(fm.fileExists(atPath: dir.appendingPathComponent(kept).path))
    }

    @Test func aFileCutShortIsKeptAsideAndStartsFresh() throws {
        try withStore { store, dir in
            try store.save([fixture], to: .fixtures)
            let path = dir.appendingPathComponent("fixtures.json")
            let data = try Data(contentsOf: path)
            try data.prefix(data.count / 2).write(to: path)
            let loaded = store.load(.fixtures, as: [StoredFixture].self, otherwise: [])
            #expect(loaded.value.isEmpty)
            let notice = try #require(loaded.notice)
            #expect(notice.contains("Your saved fixtures"))
            #expect(notice.contains("cut short"))
            #expect(notice.contains("fixtures.unreadable-1.json"))
            expectKeptAside(dir, original: "fixtures.json", kept: "fixtures.unreadable-1.json")
        }
    }

    @Test func aFileThatIsNotJSONIsKeptAsideAndStartsFresh() throws {
        try withStore { store, dir in
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data("hello".utf8).write(to: dir.appendingPathComponent("tactics.json"))
            let loaded = store.load(.tactics, as: [StoredTactic].self, otherwise: [])
            #expect(loaded.value.isEmpty)
            #expect(try #require(loaded.notice).contains("Your tactics"))
            expectKeptAside(dir, original: "tactics.json", kept: "tactics.unreadable-1.json")
        }
    }

    @Test func aFileFromANewerVersionIsKeptAsideAndStartsFresh() throws {
        try withStore { store, dir in
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data(#"{"version": 2, "value": []}"#.utf8).write(to: dir.appendingPathComponent("history.json"))
            let loaded = store.load(.history, as: [ConfirmedRecord].self, otherwise: [])
            #expect(loaded.value.isEmpty)
            let notice = try #require(loaded.notice)
            #expect(notice.contains("the confirmed lineups"))
            #expect(notice.contains("newer version"))
            expectKeptAside(dir, original: "history.json", kept: "history.unreadable-1.json")
        }
    }

    @Test func aFileThatDoesNotDecodeIsKeptAside() throws {
        try withStore { store, dir in
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data(#"{"version": 1, "value": "wrong"}"#.utf8).write(to: dir.appendingPathComponent("squad.json"))
            let loaded = store.load(.squad, as: SquadState.self, otherwise: SquadState())
            #expect(try #require(loaded.notice).contains("the squad"))
            expectKeptAside(dir, original: "squad.json", kept: "squad.unreadable-1.json")
        }
    }

    @Test func aSecondUnreadableFileGetsTheNextNumber() throws {
        try withStore { store, dir in
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for _ in 0..<2 {
                try Data("{".utf8).write(to: dir.appendingPathComponent("settings.json"))
                _ = store.load(.settings, as: AppSettings.self, otherwise: AppSettings(currentDate: day))
            }
            #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("settings.unreadable-1.json").path))
            #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("settings.unreadable-2.json").path))
        }
    }

    @Test func theOtherFilesStillLoad() throws {
        try withStore { store, dir in
            try store.save([fixture], to: .fixtures)
            try store.save(settings, to: .settings)
            try Data("{".utf8).write(to: dir.appendingPathComponent("settings.json"))
            _ = store.load(.settings, as: AppSettings.self, otherwise: AppSettings(currentDate: day))
            let fixtures = store.load(.fixtures, as: [StoredFixture].self, otherwise: [])
            #expect(fixtures.value == [fixture])
            #expect(fixtures.notice == nil)
        }
    }

    @Test func dictionariesKeyedBySlotAndPlayerAreJSONObjects() throws {
        try withStore { store, dir in
            try store.save([fixture], to: .fixtures)
            try store.save([record], to: .history)
            try store.save(squad, to: .squad)
            func value(_ name: String) throws -> Any {
                let object = try JSONSerialization.jsonObject(
                    with: Data(contentsOf: dir.appendingPathComponent("\(name).json"))) as! [String: Any]
                return object["value"]!
            }
            let fixtures = try value("fixtures") as! [[String: Any]]
            #expect(fixtures[0]["overrides"] is [String: Any])
            let history = try value("history") as! [[String: Any]]
            #expect(history[0]["names"] is [String: Any])
            let lineup = history[0]["lineup"] as! [String: Any]
            #expect(lineup["starters"] is [String: Any])
            let state = try value("squad") as! [String: Any]
            #expect(state["importedOn"] is [String: Any])
        }
    }
}
