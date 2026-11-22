import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

/// What the Candidates tab lists: the best five of each group with the others behind a line, the hidden players apart,
/// and each player's two abilities on his line of details.
@MainActor @Suite struct ScoutingBestFiveTests {
    /// The model holding the owner's captured search of 109 players, the clock stopped.
    private func withTheSearch() throws -> TestModel {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t, paste: Captures.scoutingSearch, grids: Captures.scoutingSearchGrids)
        t.input.tick = 0
        t.input.uptime = 1_000
        return t
    }

    private func withTheSample() throws -> TestModel {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t)
        t.input.tick = 0
        t.input.uptime = 1_000
        return t
    }

    private func sheet(_ t: TestModel, _ order: CandidateOrder = .today) throws -> CandidatesSheet {
        try #require(t.model.candidatesSheet(try ScoutingSetup.report(t.model), order: order))
    }

    private func hide(_ id: PlayerID, in t: TestModel) {
        t.model.hideCandidate(id, for: nil)
        t.input.uptime += AppModel.scoutingActionInterval + 1
    }

    // MARK: The best five

    @Test func theFiveIsFive() {
        #expect(ScoutingPresentation.shownInGroup == 5)
    }

    @Test func aGroupOverFiveShowsItsBestFiveAndCountsTheOthers() throws {
        let t = try withTheSearch()
        let report = try ScoutingSetup.report(t.model)
        for order in CandidateOrder.allCases {
            let sheet = try #require(t.model.candidatesSheet(report, order: order))
            let groups = report.groups(orderedBy: order)
            #expect(sheet.groups.count == groups.count)
            for (shown, group) in zip(sheet.groups, groups) {
                let ids = group.candidates.map(\.id)
                if shown.isRest {
                    #expect(shown.rows.map(\.id) == ids && shown.moreRows.isEmpty && shown.moreLine == nil)
                    #expect(shown.closedLine == ScoutingPresentation.restLine(ids.count))
                } else {
                    #expect(shown.rows.map(\.id) == Array(ids.prefix(5)))             // the engine's order decides the five
                    #expect(shown.moreRows.map(\.id) == Array(ids.dropFirst(5)))
                    #expect(shown.moreLine == (ids.count > 5 ? ScoutingPresentation.restLine(ids.count - 5) : nil))
                    #expect(shown.closedLine == nil)
                }
            }
            #expect(sheet.groups.contains { $0.moreLine != nil })                      // the capture does have such a group
            #expect(sheet.groups.contains { !$0.isRest && $0.moreLine == nil })        // and one that is shown whole
            #expect(sheet.groupIDs == Set(sheet.groups.filter { $0.moreLine != nil }.map(\.id)))
            #expect(sheet.rowIDs == Set(report.candidates.map(\.id)))
        }
        #expect(t.model.allCandidateGroupIDs(for: nil) == (try sheet(t)).groupIDs)
    }

    @Test func aGroupOfFiveHasNoLineAndOneOfSixSaysOneMorePlayer() throws {
        let t = try withTheSearch()
        let paste = try #require(t.model.scoutingPaste)
        let largest = try #require(try ScoutingSetup.report(t.model).groups(orderedBy: .today)
            .filter { $0.part != .rest }.max { $0.candidates.count < $1.candidates.count })
        try #require(largest.candidates.count >= 6)
        t.model.hold(ScoutingPaste(players: largest.candidates.prefix(6).map(\.player), money: paste.money))
        let six = try sheet(t)
        let group = try #require(six.groups.first)
        #expect(six.groups.count == 1)
        #expect(group.rows.count == 5 && group.moreRows.count == 1)
        #expect(group.moreLine == "1 more player")
        let sixth = try #require(group.moreRows.first)

        hide(try #require(group.rows.first).id, in: t)                               // the sixth moves up
        let five = try #require(try sheet(t).groups.first)
        #expect(five.rows.count == 5 && five.moreRows.isEmpty && five.moreLine == nil)
        #expect(five.rows.last?.id == sixth.id)
        #expect(five.rows.map(\.id) == Array(group.rows.dropFirst().map(\.id)) + [sixth.id])
        #expect(try sheet(t).groupIDs.isEmpty)
    }

    @Test func changingTheOrderChangesWhichFiveAreShown() throws {
        let t = try withTheSearch()
        let today = try sheet(t, .today), later = try sheet(t, .later)
        #expect(today.groups.map(\.id) == later.groups.map(\.id))                    // nobody changes heading
        let differing = try #require(zip(today.groups, later.groups).first { a, b in
            !a.isRest && a.moreLine != nil && Set(a.rows.map(\.id)) != Set(b.rows.map(\.id))
        }, "a group of the capture whose best five differ between the two orders")
        #expect(differing.0.rows.count == 5 && differing.1.rows.count == 5)
        #expect(Set((differing.0.rows + differing.0.moreRows).map(\.id)) == Set((differing.1.rows + differing.1.moreRows).map(\.id)))
        #expect(differing.0.moreLine == differing.1.moreLine)
    }

    @Test func aSmallPasteIsShownWholeWithNoLine() throws {
        let t = try withTheSample()
        let sheet = try sheet(t)
        #expect(sheet.groups.allSatisfy { $0.moreRows.isEmpty && $0.moreLine == nil })
        #expect(sheet.groupIDs.isEmpty)
        #expect(sheet.rowIDs.count == 6)
        #expect(t.model.allCandidateGroupIDs(for: nil).isEmpty)
    }

    // MARK: The hidden list

    @Test func theHiddenListNamesEachHiddenPlayerWithHisDetails() throws {
        let t = try withTheSample()
        let paste = try #require(t.model.scoutingPaste)
        #expect(try sheet(t).hidden.isEmpty)
        #expect(try sheet(t).hiddenLine == nil)

        // Hidden in the other order than pasted: the list is in paste order.
        let second = paste.players[1], first = paste.players[0]
        hide(second.id, in: t)
        let one = try sheet(t)
        #expect(one.hidden.map(\.id) == [second.id])
        #expect(one.hiddenLine == "1 hidden player")
        hide(first.id, in: t)
        let two = try sheet(t)
        #expect(two.hidden.map(\.id) == [first.id, second.id])
        #expect(two.hidden.map(\.name) == [first.name, second.name])
        #expect(two.hiddenLine == "2 hidden players")
        #expect(two.hidden.map(\.detailsText) == [first, second].map { ScoutingPresentation.details(of: $0, money: paste.money) })
        #expect(!two.rowIDs.contains(first.id) && !two.rowIDs.contains(second.id))
        #expect(two.readLine == AdvisorText.playersRead(6))                          // still six read
        #expect(ScoutingPresentation.hiddenLine(1) == "1 hidden player" && ScoutingPresentation.hiddenLine(3) == "3 hidden players")
    }

    @Test func aPasteWithEveryPlayerHiddenShowsTheLinesAndTheHiddenListAndNoGroups() throws {
        let t = try withTheSample()
        let all = try ScoutingSetup.report(t.model).candidates.map(\.id)
        for id in all { hide(id, in: t) }
        guard case .ready(let report) = t.model.candidates(for: nil) else {
            Issue.record("expected candidates, got \(t.model.candidates(for: nil))")
            return
        }
        let sheet = try #require(t.model.candidatesSheet(report, order: .today))
        #expect(sheet.groups.isEmpty)
        #expect(sheet.hidden.count == all.count && sheet.hiddenLine == "6 hidden players")
        #expect(sheet.readLine == AdvisorText.playersRead(6))
        #expect(sheet.evidenceNote == nil)
        #expect(t.model.scoutingPasteProblem == nil)
    }

    // MARK: The two abilities

    @Test func theDetailsLineCarriesTheTwoAbilitiesAfterThePositions() throws {
        let t = try withTheSample()
        let paste = try #require(t.model.scoutingPaste)
        let sheet = try sheet(t)
        for row in sheet.groups.flatMap({ $0.rows + $0.moreRows }) {
            let player = try #require(paste.players.first { $0.id == row.id })
            let ability = "CA \(player.currentAbility) · PA \(player.potentialAbility)"
            #expect(row.detailsText.hasPrefix("Age \(player.age) · \(player.positionsText) · \(ability) · "))
            #expect(row.detailsText == ScoutingPresentation.details(of: player, money: paste.money))
        }
        #expect(ScoutingPresentation.abilityText(current: 78, potential: 82) == "CA 78 · PA 82")
    }

    // MARK: The samples the pictures are drawn from, and what VoiceOver says

    @Test func theCrowdedSampleHoldsOneGroupOverFive() throws {
        let model = try SampleData.modelWithCrowdedGroup(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let report = try ScoutingSetup.report(model)
        let sheet = try #require(model.candidatesSheet(report, order: .today))
        #expect(sheet.groups.count == 1)
        let group = try #require(sheet.groups.first)
        #expect(!group.isRest && group.rows.count == 5)
        #expect(group.moreRows.count >= 2)                                               // "more players", in the plural
        #expect(group.moreLine == ScoutingPresentation.restLine(group.moreRows.count))
        #expect(sheet.hidden.isEmpty)
        #expect(model.allCandidateGroupIDs(for: nil) == [group.id])
    }

    @Test func theHiddenSampleHasTwoPlayersHiddenAndTheOthersShown() throws {
        let model = try SampleData.modelWithHiddenCandidates(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let report = try ScoutingSetup.report(model)
        let sheet = try #require(model.candidatesSheet(report, order: .today))
        #expect(sheet.hidden.count == 2 && sheet.hiddenLine == "2 hidden players")
        #expect(sheet.rowIDs.count == 4)
        #expect(report.leftOut == [SampleData.candidateAlreadyHeldName])                 // still left out as the club's own
        // The group whose order the Today and Later pictures turn round is left whole.
        #expect(!sheet.hidden.contains { [SampleData.candidateWhoStartsName, SampleData.candidateOlderStarterName].contains($0.name) })
    }

    @Test func voiceOverNamesThePlayerAButtonActsOn() {
        #expect(ScoutingPresentation.hideLabel("Brad Walker") == "Hide Brad Walker")
        #expect(ScoutingPresentation.showAgainLabel("Brad Walker") == "Show Brad Walker again")
        #expect(ScoutingPresentation.hideButton == "Hide" && ScoutingPresentation.showAgainButton == "Show again")
        #expect(ScoutingPresentation.hiddenHeading == "Hidden")
    }

    // MARK: Which lines are open

    @Test func theOpenLinesAreKeptByGroupAndClosedTogether() {
        let n = Navigation()
        #expect(n.scoutingMoreOpen.isEmpty && n.scoutingHiddenOpen == false)             // closed at launch
        n.toggleScoutingMore("answersToday-D_L-moreDepth")
        #expect(n.scoutingMoreOpen == ["answersToday-D_L-moreDepth"])
        n.scoutingOrder = .later
        n.scoutingTacticID = UUID()
        #expect(n.scoutingMoreOpen.count == 1)                                           // a change of order or tactic leaves it
        n.toggleScoutingMore("answersToday-D_L-moreDepth")
        #expect(n.scoutingMoreOpen.isEmpty)
        n.toggleScoutingMore("a"); n.toggleScoutingMore("b")
        n.scoutingHiddenOpen = true
        n.closeScoutingLines()
        #expect(n.scoutingMoreOpen.isEmpty)
        #expect(n.scoutingHiddenOpen)                                                    // the hidden list is not one of them
    }
}
