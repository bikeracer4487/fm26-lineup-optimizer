import Foundation
import Testing
@testable import LineupEngine

@Suite struct EndToEndTests {
    @Test func realSquadsProduceAFullExplainedLineup() throws {
        var book = SquadBook()
        let grids = try Fixtures.data("captures/first-team.grids.json")
        book.apply(try Importer.importPlayers(clipboard: Fixtures.text("captures/first-team.tsv"), fmrteConfig: grids, squad: .firstTeam), to: .firstTeam)
        book.apply(try Importer.importPlayers(clipboard: Fixtures.text("captures/u21.tsv"),
                                              fmrteConfig: Fixtures.data("captures/u21.grids.json"), squad: .u21), to: .u21)
        let ownClub = book.ownClub(override: "Oxford City")      // the first-team capture is from the team grid, which has no club column
        let tactic = try JSONDecoder().decode(Tactic.self, from: Fixtures.data("tactics/sample-4231.json"))
        let selector = LineupSelector(catalog: try .fm27(), tables: try .bundled(), parameters: .fm27)
        let lineup = try selector.select(.init(tactic: tactic, players: book.allPlayers, ownClub: ownClub,
                                               importance: .high, isNextFixture: true, overrides: [:], rejected: []))
        #expect(lineup.picks.count + lineup.unfilled.count == 11)
        #expect(Set(lineup.picks.map(\.player)).count == lineup.picks.count)
        let names = Set(lineup.picks.map(\.name))
        #expect(!names.contains("Max Treml"))                                   // out on loan
        for p in book.allPlayers where p.isInjured { #expect(!names.contains(p.name)) }
        #expect(lineup.picks.allSatisfy { !$0.reasons.isEmpty })

        // Three picks pinned from the real data.
        let bySlot = Dictionary(uniqueKeysWithValues: lineup.picks.map { ($0.slot, $0.name) })
        #expect(bySlot[.AM_C] == "Zac McEachran")
        #expect(bySlot[.D_L] == "Evan Humphries")
        #expect(bySlot[.GK] == "Matty Taylor")

        // Both goalkeepers are unavailable (Maxted injured, Treml on loan), so an outfield player stands in.
        let keeper = try #require(lineup.picks.first { $0.slot == .GK })
        #expect(keeper.warnings.contains { if case .outOfPosition(.inPossession, _) = $0 { true } else { false } })
    }
}
