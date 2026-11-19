import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

/// What the Scouting screen's two tabs show, from the engine's values for the captured first team and the U21s pasted
/// as another club's players.
@MainActor @Suite struct ScoutingPresentationTests {
    /// The U21s at another club read through the importer, as the model reads a paste.
    private func pasted(_ paste: String? = nil) throws -> ImportResult {
        try Importer.importPlayers(clipboard: try paste ?? Captures.u21AtAnotherClub, fmrteConfig: try Captures.u21Grids,
                                   squad: .firstTeam)
    }

    /// The engine's judgement of `players` against the model's needs for the primary tactic.
    private func judged(_ players: [Player], in model: AppModel) throws -> CandidatesReport {
        let needs = try ScoutingSetup.needs(model)
        let tactic = try #require(model.primaryTactic).tactic
        return try Scouting.candidates(pasted: players, held: model.squad.book.allPlayers, ownClub: model.ownClub,
                                       tactic: tactic, needs: needs, catalog: model.catalog, profile: model.profile,
                                       parameters: model.planParameters)
    }

    private func rows(_ sheet: CandidatesSheet) -> [ScoutingCandidateRow] { sheet.groups.flatMap(\.rows) }

    // MARK: Needs

    @Test func aNeedRowHoldsTheEnginesLines() throws {
        let t = try ScoutingSetup.ready()
        let needs = try ScoutingSetup.needs(t.model)
        let parameters = t.model.planParameters
        let sheet = ScoutingPresentation.needsSheet(needs, parameters: parameters)
        #expect(!needs.betterPlayers.isEmpty)
        #expect(!needs.moreDepth.isEmpty)
        #expect(sheet.betterPlayers.map(\.slot) == needs.betterPlayers.map(\.slot))
        for (row, need) in zip(sheet.betterPlayers, needs.betterPlayers) {
            #expect(row.lines == AdvisorText.betterPlayerLines(need))
            #expect(row.slotText == need.slot.displayName)
            #expect(row.isEased == (need.easedBy != nil))
        }
        #expect(sheet.moreDepth.map(\.slot) == needs.moreDepth.map(\.depth.slot))
        for (row, need) in zip(sheet.moreDepth, needs.moreDepth) {
            #expect(row.lines == AdvisorText.depthNeedLines(need, parameters: parameters))
            #expect(row.slotText == need.depth.slot.displayName)
            #expect(!row.isEased)
        }
        #expect(sheet.fine == needs.fine)
        let leftBack = try #require((sheet.betterPlayers + sheet.moreDepth).first { $0.slot == .D_L })
        #expect(leftBack.slotText == "D L")
        #expect(t.model.needsSheet(needs) == sheet)
    }

    @Test func aSlotWithBothNeedsHasARowInEachList() throws {
        let t = try ScoutingSetup.ready()
        let needs = try ScoutingSetup.needs(t.model)
        let sheet = ScoutingPresentation.needsSheet(needs, parameters: t.model.planParameters)
        let both = Set(needs.betterPlayers.map(\.slot)).intersection(needs.moreDepth.map(\.depth.slot))
        #expect(!both.isEmpty)
        for slot in both {
            #expect(sheet.betterPlayers.filter { $0.slot == slot }.count == 1)
            #expect(sheet.moreDepth.filter { $0.slot == slot }.count == 1)
        }
        #expect(Set(sheet.fine).isDisjoint(with: both))
    }

    @Test func theGoingLineAndTheEvidenceNoteAreTheEngines() throws {
        let t = try ScoutingSetup.ready()
        let needs = try ScoutingSetup.needs(t.model)
        let sheet = ScoutingPresentation.needsSheet(needs, parameters: t.model.planParameters)
        #expect(sheet.goingLine != nil)
        #expect(sheet.goingLine == AdvisorText.countedAsGoing(needs.going))
        #expect(sheet.evidenceNote == AdvisorText.note(for: needs.basis))
        #expect(sheet.evidenceNote != nil, "the weak line is the tool's own estimate")
    }

    // MARK: Candidates

    @Test func aCandidateRowShowsHisHeadlineSlotAndListsTheOthers() throws {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t)
        let report = try ScoutingSetup.report(t.model)
        let money = try #require(t.model.scoutingPaste).money
        let sheet = ScoutingPresentation.candidatesSheet(report, order: .today, pasted: 6, money: money)
        let candidate = try #require(report.candidates.first { $0.headline != nil && $0.slots.count >= 2 })
        let row = try #require(rows(sheet).first { $0.id == candidate.id })
        let headline = try #require(candidate.slots.first { $0.slot == candidate.headline })
        #expect(row.name == candidate.player.name)
        #expect(row.age == candidate.player.age)
        #expect(row.positions == candidate.player.positionsText)
        #expect(row.wage == Display.wage(perWeek: candidate.player.wagePerWeek, money))
        #expect(row.isInjured == candidate.player.isInjured)
        #expect(row.slotText == headline.slot.displayName)
        #expect(row.todayLines == AdvisorText.todayLines(headline))
        #expect(row.laterLines == AdvisorText.laterLines(candidate))
        #expect(row.cautions == candidate.cautions.map(AdvisorText.caution))
        let others = candidate.slots.filter { $0.slot != headline.slot }
        #expect(row.otherSlots == others.map(AdvisorText.otherSlotLine))
        #expect(row.otherSlots.count == candidate.slots.count - 1)
        // The tactic's order.
        let order = try #require(t.model.primaryTactic).tactic.assignments(catalog: t.model.catalog).map(\.slot)
        let indices = others.map { order.firstIndex(of: $0.slot) ?? -1 }
        #expect(indices == indices.sorted())
    }

    @Test func moneyIsShownInThePastesOwnStyle() throws {
        let t = try ScoutingSetup.ready()
        #expect(t.model.squad.book.moneyStyle == .weeklyPounds)
        try ScoutingSetup.paste(t, paste: Captures.inDollars(try Captures.u21AtAnotherClub),
                                grids: try Captures.grids(try Captures.u21Grids, wages: "Monthly"))
        let paste = try #require(t.model.scoutingPaste)
        #expect(paste.money == MoneyStyle(symbol: "$", period: .monthly))
        let report = try ScoutingSetup.report(t.model)
        let sheet = try #require(t.model.candidatesSheet(report, order: .today))
        let all = rows(sheet)
        #expect(all.count == 6)
        for row in all {
            #expect(row.wage.hasPrefix("$"))
            #expect(row.wage.hasSuffix(" a month"))
            if let price = row.askingPrice { #expect(price.hasPrefix("Asking $")) }
        }
        #expect(all.contains { $0.askingPrice != nil })
    }

    @Test func aRowWithoutAClubOrAPriceShowsNeither() throws {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t, paste: try Captures.u21TeamGrid, grids: try Captures.u21TeamGridGrids)
        let report = try ScoutingSetup.report(t.model)
        let sheet = try #require(t.model.candidatesSheet(report, order: .today))
        let byID = Dictionary(report.candidates.map { ($0.id, $0.player) }, uniquingKeysWith: { first, _ in first })
        let all = rows(sheet)
        #expect(!all.isEmpty)
        #expect(all.allSatisfy { $0.askingPrice == nil })
        let underContract = all.filter { byID[$0.id]?.contractType != .outOfContract }
        #expect(!underContract.isEmpty)
        #expect(underContract.allSatisfy { $0.club == nil })
    }

    @Test func aFreeAgentAndALoanAreNamed() throws {
        let t = try ScoutingSetup.ready()
        var players = try pasted().players
        let free = try #require(players.first { $0.contractType == .outOfContract })
        let loanIndex = try #require(players.firstIndex { $0.contractType != .outOfContract && $0.loanedTo == nil })
        players[loanIndex].loanedTo = "Barnet"
        let loaned = players[loanIndex]
        let report = try judged(players, in: t.model)
        let sheet = ScoutingPresentation.candidatesSheet(report, order: .today, pasted: players.count, money: .weeklyPounds)
        let freeRow = try #require(rows(sheet).first { $0.id == free.id })
        #expect(freeRow.club == "Free agent")
        let loanRow = try #require(rows(sheet).first { $0.id == loaned.id })
        #expect(loanRow.onLoan == "On loan at Barnet")
        #expect(loanRow.club == "Banbury United")
        let unloaned = try #require(rows(sheet).first { row in players.first { $0.id == row.id }?.loanedTo == nil })
        #expect(unloaned.onLoan == nil)
    }

    @Test func thePartTitleIsOnTheFirstGroupOfEachPartOnly() throws {
        let t = try ScoutingSetup.ready()
        // Each pasted twice under another name, so most parts have more than one group's worth.
        let renamed = try Captures.u21AtAnotherClub.replacingOccurrences(of: "\"Brayden Daniel\"", with: "\"Kofi Mensah\"")
        var players = try pasted().players + (try pasted(renamed).players)
        // One more slot answered: the first candidate made solid everywhere he can already cover.
        if let index = players.indices.first {
            for (position, value) in players[index].familiarity where value >= 10 { players[index].familiarity[position] = 20 }
        }
        let report = try judged(players, in: t.model)
        for order in CandidateOrder.allCases {
            let groups = report.groups(orderedBy: order)
            let sheet = ScoutingPresentation.candidatesSheet(report, order: order, pasted: players.count, money: .weeklyPounds)
            #expect(sheet.groups.count == groups.count)
            for (index, (row, group)) in zip(sheet.groups, groups).enumerated() {
                let first = !groups[..<index].contains { $0.part == group.part }
                #expect(row.partTitle == (first ? AdvisorText.name(group.part) : nil))
                if let slot = group.slot, let answer = group.answer {
                    #expect(row.heading == AdvisorText.groupHeading(slot: slot, answer: answer))
                } else {
                    #expect(row.heading == nil)
                }
                #expect(row.rows.map(\.id) == group.candidates.map(\.id))
            }
            #expect(Set(sheet.groups.map(\.id)).count == sheet.groups.count)
            #expect(sheet.groups.compactMap(\.partTitle).count == Set(groups.map(\.part)).count)
            #expect(sheet.groups.contains { $0.partTitle == nil }, "a part with a second group, whose title is not repeated")
        }
    }

    @Test func namesakesGetARowEach() throws {
        let t = try ScoutingSetup.ready()
        let paste = try Captures.u21AtAnotherClub.replacingOccurrences(of: "\"Caleb Moir\"", with: "\"Brayden Daniel\"")
        try ScoutingSetup.paste(t, paste: paste)
        let report = try ScoutingSetup.report(t.model)
        let sheet = try #require(t.model.candidatesSheet(report, order: .today))
        let namesakes = rows(sheet).filter { $0.name == "Brayden Daniel" }
        #expect(namesakes.count == 2)
        #expect(Set(namesakes.map(\.id)).count == 2)
    }

    @Test func aPlayerWhoPlaysNoSlotSaysSo() throws {
        let t = try ScoutingSetup.ready()
        var players = try pasted().players
        for position in players[0].familiarity.keys { players[0].familiarity[position] = 1 }
        let report = try judged(players, in: t.model)
        let sheet = ScoutingPresentation.candidatesSheet(report, order: .today, pasted: players.count, money: .weeklyPounds)
        let row = try #require(rows(sheet).first { $0.id == players[0].id })
        #expect(row.slotText == nil)
        #expect(row.todayLines == [AdvisorText.playsNoSlot])
        #expect(row.laterLines.isEmpty)
        #expect(row.otherSlots.isEmpty)
    }

    @Test func theReadLineCountsThePastedRows() throws {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t)
        let report = try ScoutingSetup.report(t.model)
        let paste = try #require(t.model.scoutingPaste)
        let sheet = ScoutingPresentation.candidatesSheet(report, order: .today, pasted: 6, money: paste.money)
        #expect(sheet.readLine == AdvisorText.playersRead(6))
        #expect(sheet.leftOutLine == nil)
        #expect(t.model.candidatesSheet(report, order: .today) == sheet)

        try t.importU21()
        let after = try ScoutingSetup.report(t.model)
        let left = try #require(t.model.candidatesSheet(after, order: .today))
        #expect(left.readLine == AdvisorText.playersRead(6))
        #expect(left.leftOutLine == AdvisorText.leftOutAlreadyYours(after.leftOut))
        #expect(left.leftOutLine != nil)
        #expect(left.groups.isEmpty)
    }

    @Test func withNothingPastedThereIsNoSheet() throws {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t)
        let report = try ScoutingSetup.report(t.model)
        t.model.clearCandidates()
        #expect(t.model.candidatesSheet(report, order: .today) == nil)
    }

    // MARK: Labels

    @Test func theTabsAndLabelsArePlainWords() {
        #expect(ScoutingView.allCases == [.needs, .candidates])
        #expect(ScoutingView.allCases.map(\.title) == ["Needs", "Candidates"])
        #expect(ScoutingPresentation.pasteButton == "Paste players")
        #expect(ScoutingPresentation.clearButton == "Clear")
        #expect(ScoutingPresentation.nothingPasted == "Copy the rows of a search or a shortlist in FMRTE, then paste them here.")
        #expect(ScoutingPresentation.fineHeading == "Fine")
    }

    @Test func theNavigationStartsOnTheNeedsForThePrimaryInTodaysOrder() {
        let navigation = Navigation()
        #expect(navigation.scoutingView == .needs)
        #expect(navigation.scoutingTacticID == nil)
        #expect(navigation.scoutingOrder == .today)
        #expect(navigation.scoutingOpen.isEmpty)
    }
}
