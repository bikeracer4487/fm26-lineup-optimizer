import Foundation
import Testing
@testable import LineupEngine

@Suite struct EndToEndTests {
    /// The first-team and U21 captures taken without the Id column, selected for the sample tactic under `profile`.
    private func realLineup(_ profile: RatingProfile) throws -> (lineup: Lineup, book: SquadBook) {
        var book = SquadBook()
        let grids = try Fixtures.data("captures/first-team.grids.json")
        book.apply(try Importer.importPlayers(clipboard: Fixtures.text("captures/first-team.tsv"), fmrteConfig: grids, squad: .firstTeam), to: .firstTeam)
        book.apply(try Importer.importPlayers(clipboard: Fixtures.text("captures/u21.tsv"),
                                              fmrteConfig: Fixtures.data("captures/u21.grids.json"), squad: .u21), to: .u21)
        let ownClub = book.ownClub(override: "Oxford City")      // the first-team capture is from the team grid, which has no club column
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
        // rates 90.7 up front to Marsh's 89.7, so he leads the line and Clark stands in as goalkeeper.
        let bySlot = Dictionary(uniqueKeysWithValues: lineup.picks.map { ($0.slot, $0.name) })
        #expect(bySlot[.AM_C] == "Zac McEachran")
        #expect(bySlot[.D_L] == "Evan Humphries")
        #expect(bySlot[.GK] == "Ewan Clark")
        #expect(bySlot[.ST_C] == "Matty Taylor")
    }

    @Test func realSquadsProduceAFullExplainedLineupUnderTheFM27Profile() throws {
        let (lineup, book) = try realLineup(try RatingProfile.fm27EngineTests())
        expectSound(lineup, book)
        // Three picks pinned from the real data. Pace and Acceleration weigh heavily here, so the quicker Marsh
        // (12 and 12) leads the line over Taylor (8 and 8), who stands in as goalkeeper.
        let bySlot = Dictionary(uniqueKeysWithValues: lineup.picks.map { ($0.slot, $0.name) })
        #expect(bySlot[.AM_C] == "Zac McEachran")
        #expect(bySlot[.ST_C] == "Tyrone Marsh")
        #expect(bySlot[.GK] == "Matty Taylor")
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
}
