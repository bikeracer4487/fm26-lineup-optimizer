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
        #expect(row.todayLines == AdvisorText.todayLines(headline))
        #expect(row.laterLines == AdvisorText.laterLines(candidate))
        #expect(row.cautions == candidate.cautions.map(AdvisorText.caution))
        let others = candidate.slots.filter { $0.slot != headline.slot }
        // Each other slot's lines together, as the engine gives them.
        #expect(row.otherSlots == others.map { ScoutingOtherSlot(slot: $0.slot, lines: AdvisorText.otherSlotLines($0)) })
        #expect(row.otherSlots.count == candidate.slots.count - 1)
        #expect(row.otherSlots.allSatisfy { !$0.lines.isEmpty })
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
        // A free agent has no club; the sample's player out of contract is still at one, so his club is taken away.
        let freeIndex = try #require(players.firstIndex { $0.contractType == .outOfContract })
        players[freeIndex].club = nil
        let free = players[freeIndex]
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
        // The evidence note for the candidates shown, as the Needs tab has its own.
        let basis = try #require(report.basis)
        #expect(sheet.evidenceNote == AdvisorText.note(for: basis))
        #expect(sheet.evidenceNote != nil, "a reach is this tool's estimate")
        #expect(t.model.candidatesSheet(report, order: .today) == sheet)

        try t.importU21()
        let after = try ScoutingSetup.report(t.model)
        let left = try #require(t.model.candidatesSheet(after, order: .today))
        #expect(left.readLine == AdvisorText.playersRead(6))
        #expect(left.leftOutLine == AdvisorText.leftOutAlreadyYours(after.leftOut))
        #expect(left.leftOutLine != nil)
        #expect(left.groups.isEmpty)
        #expect(left.evidenceNote == nil, "no candidates, no note")
    }

    @Test func withNothingPastedThereIsNoSheet() throws {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t)
        let report = try ScoutingSetup.report(t.model)
        t.model.clearCandidates()
        #expect(t.model.candidatesSheet(report, order: .today) == nil)
    }

    @Test func aNeedRowAndAFineSlotCarryTheirSlotsLine() throws {
        let t = try ScoutingSetup.ready()
        let needs = try ScoutingSetup.needs(t.model)
        let sheet = ScoutingPresentation.needsSheet(needs, parameters: t.model.planParameters)
        for row in sheet.betterPlayers + sheet.moreDepth { #expect(row.line == PitchLine(row.slot)) }
        #expect(!sheet.fine.isEmpty)
        #expect(sheet.fineTokens.map(\.slot) == sheet.fine)
        for token in sheet.fineTokens {
            #expect(token.slotText == token.slot.displayName)
            #expect(token.line == PitchLine(token.slot))
        }
        #expect(ScoutingSlotToken(.GK).line == .goalkeeper)
        #expect(ScoutingSlotToken(.D_L).slotText == "D L")
    }

    @Test func theRestPartIsMarkedAndCountedForTheLineItIsClosedBehind() throws {
        let t = try ScoutingSetup.ready()
        var players = try pasted().players
        // He can play no slot, so he is in the rest.
        for position in players[0].familiarity.keys { players[0].familiarity[position] = 1 }
        let report = try judged(players, in: t.model)
        let groups = report.groups(orderedBy: .today)
        let sheet = ScoutingPresentation.candidatesSheet(report, order: .today, pasted: players.count, money: .weeklyPounds)
        for (row, group) in zip(sheet.groups, groups) { #expect(row.isRest == (group.part == .rest)) }
        let rest = sheet.groups.filter(\.isRest).flatMap(\.rows)
        #expect(rest.contains { $0.id == players[0].id })
        // The rest says the line it is closed behind; no other group is closed.
        for group in sheet.groups {
            #expect(group.closedLine == (group.isRest ? ScoutingPresentation.restLine(rest.count) : nil))
        }
        #expect(sheet.groups.contains { !$0.isRest }, "the parts before the rest are not closed")
        for group in sheet.groups {
            #expect(group.showsRows(restOpen: true))
            #expect(group.showsRows(restOpen: false) == !group.isRest)
        }

        // With nobody in the rest there is no line.
        let answering = report.candidates.filter { $0.part != .rest }.map(\.player)
        let without = ScoutingPresentation.candidatesSheet(try judged(answering, in: t.model), order: .today,
                                                           pasted: answering.count, money: .weeklyPounds)
        #expect(!without.groups.contains { $0.isRest })
        #expect(without.groups.allSatisfy { $0.closedLine == nil })
        #expect(ScoutingPresentation.restLine(1) == "1 more player")
        #expect(ScoutingPresentation.restLine(12) == "12 more players")
    }

    @Test func aRowsDetailsLeaveOutWhatThePasteDidNotCarry() throws {
        let t = try ScoutingSetup.ready()
        var players = try pasted().players
        let index = try #require(players.firstIndex { $0.contractType != .outOfContract && $0.askingPrice != nil })
        players[index].loanedTo = "Barnet"
        let report = try judged(players, in: t.model)
        let sheet = ScoutingPresentation.candidatesSheet(report, order: .today, pasted: players.count, money: .weeklyPounds)
        let full = try #require(rows(sheet).first { $0.id == players[index].id })
        let price = try #require(full.askingPrice)
        #expect(full.detailsText == ["Age \(full.age)", full.positions, "Banbury United", "On loan at Barnet", price,
                                     full.wage].joined(separator: " · "))

        try ScoutingSetup.paste(t, paste: try Captures.u21TeamGrid, grids: try Captures.u21TeamGridGrids)
        let bare = try #require(t.model.candidatesSheet(try ScoutingSetup.report(t.model), order: .today))
        let plain = try #require(rows(bare).first { $0.club == nil && $0.onLoan == nil })
        #expect(plain.detailsText == "Age \(plain.age) · \(plain.positions) · \(plain.wage)")
    }

    @Test func anInjuredCandidateIsStampedAndNoOtherIs() throws {
        let t = try ScoutingSetup.ready()
        var players = try pasted().players
        for index in players.indices { players[index].isInjured = index == 0 }
        let report = try judged(players, in: t.model)
        let sheet = ScoutingPresentation.candidatesSheet(report, order: .today, pasted: players.count, money: .weeklyPounds)
        let injured = try #require(rows(sheet).first { $0.id == players[0].id })
        #expect(injured.stamps == [ElevensPresentation.injuredStamp])
        #expect(rows(sheet).filter { $0.id != players[0].id }.allSatisfy { $0.stamps.isEmpty })
    }

    @Test func aRowOpensOnlyWhenThereIsMoreToShow() throws {
        let t = try ScoutingSetup.ready()
        var players = try pasted().players
        for position in players[0].familiarity.keys { players[0].familiarity[position] = 1 }
        let report = try judged(players, in: t.model)
        let sheet = ScoutingPresentation.candidatesSheet(report, order: .today, pasted: players.count, money: .weeklyPounds)
        // He plays no slot: one line today and a caution, which a closed row in the rest shows, so there is nothing
        // to open.
        let nowhere = try #require(rows(sheet).first { $0.id == players[0].id })
        #expect(nowhere.todayLines.count == 1)
        #expect(!nowhere.cautions.isEmpty)
        #expect(!nowhere.opens(inRest: false))
        #expect(!nowhere.opens(inRest: true))
        // Other slots open a row anywhere.
        let others = try #require(rows(sheet).first { !$0.otherSlots.isEmpty })
        #expect(others.opens(inRest: false))
        #expect(others.opens(inRest: true))
        // In the rest, a second line today or a line for later opens a row with no other slots.
        let alone = ScoutingCandidateRow(id: nowhere.id, name: nowhere.name, age: 20, positions: "D L", club: nil, onLoan: nil,
                                         askingPrice: nil, wage: "£500 a week", isInjured: false,
                                         todayLines: ["Below cover."], laterLines: [], cautions: [], otherSlots: [])
        #expect(!alone.opens(inRest: true))
        for more in [ScoutingCandidateRow(id: alone.id, name: alone.name, age: 20, positions: "D L", club: nil, onLoan: nil,
                                          askingPrice: nil, wage: alone.wage, isInjured: false,
                                          todayLines: ["Below cover.", "Not yet solid there."], laterLines: [],
                                          cautions: [], otherSlots: []),
                     ScoutingCandidateRow(id: alone.id, name: alone.name, age: 20, positions: "D L", club: nil, onLoan: nil,
                                          askingPrice: nil, wage: alone.wage, isInjured: false,
                                          todayLines: ["Below cover."], laterLines: ["Judged as he is today."],
                                          cautions: [], otherSlots: [])] {
            #expect(!more.opens(inRest: false))
            #expect(more.opens(inRest: true))
        }
    }

    @Test func aClosedRowInTheRestShowsOnlyItsFirstLineTodayAndOtherSlotsShowWhenOpen() {
        let row = ScoutingCandidateRow(id: PlayerID(key: "fmrte:1"), name: "Kofi Mensah", age: 20, positions: "D L",
                                       club: nil, onLoan: nil, askingPrice: nil, wage: "£500 a week", isInjured: false,
                                       todayLines: ["Would start.", "Not yet solid there."],
                                       laterLines: ["Could pass the first choice."], cautions: ["Controversy 18"],
                                       otherSlots: [ScoutingOtherSlot(slot: .D_R, lines: ["Below cover.",
                                                                                          "Later: could become cover."])])
        let all = ScoutingRowLines(today: row.todayLines, later: row.laterLines, otherSlots: [])
        #expect(row.linesShown(inRest: false, isOpen: false) == all)
        #expect(row.linesShown(inRest: true, isOpen: false) == ScoutingRowLines(today: ["Would start."], later: [],
                                                                                otherSlots: []))
        let open = ScoutingRowLines(today: row.todayLines, later: row.laterLines, otherSlots: row.otherSlots)
        #expect(row.linesShown(inRest: false, isOpen: true) == open)
        #expect(row.linesShown(inRest: true, isOpen: true) == open)
    }

    @Test func everyRowCanBeOpenedAtOnce() throws {
        let t = try ScoutingSetup.ready()
        #expect(t.model.allCandidateRowIDs(for: nil).isEmpty, "nothing pasted")
        try ScoutingSetup.paste(t)
        let report = try ScoutingSetup.report(t.model)
        let sheet = try #require(t.model.candidatesSheet(report, order: .today))
        #expect(sheet.rowIDs == Set(report.candidates.map(\.id)))
        #expect(sheet.rowIDs.count == 6)
        #expect(t.model.allCandidateRowIDs(for: nil) == sheet.rowIDs)
        t.model.clearCandidates()
        #expect(t.model.allCandidateRowIDs(for: nil).isEmpty)
    }

    @Test func clearIsOfferedWhilePlayersAreHeldOrARefusalIsShown() throws {
        let t = try ScoutingSetup.ready()
        #expect(!t.model.canClearCandidates)
        // A refusal shown with nothing held can be dismissed.
        t.input.clipboard = ""
        t.model.pasteCandidates()
        #expect(t.model.scoutingPasteProblem != nil && t.model.scoutingPaste == nil)
        #expect(t.model.canClearCandidates, "a refusal alone can be cleared")
        t.model.clearCandidates()
        #expect(t.model.scoutingPasteProblem == nil && !t.model.canClearCandidates)
        try ScoutingSetup.paste(t)
        #expect(t.model.canClearCandidates)
        t.model.clearCandidates()
        #expect(!t.model.canClearCandidates)
    }

    // MARK: Labels

    @Test func theTabsAndLabelsArePlainWords() {
        #expect(ScoutingView.allCases == [.needs, .candidates])
        #expect(ScoutingView.allCases.map(\.title) == ["Needs", "Candidates"])
        #expect(ScoutingPresentation.pasteButton == "Paste players")
        #expect(ScoutingPresentation.clearButton == "Clear")
        #expect(ScoutingPresentation.nothingPasted == "Copy the rows of a search or a shortlist in FMRTE, then paste them here.")
        #expect(ScoutingPresentation.fineHeading == "Fine")
        #expect(ScoutingPresentation.betterPlayersHeading == AdvisorText.betterPlayersHeading)
        #expect(ScoutingPresentation.moreDepthHeading == AdvisorText.moreDepthHeading)
        #expect(ScoutingPresentation.orderChoices.map(\.order) == [.today, .later])
        #expect(ScoutingPresentation.orderChoices.map(\.title) == CandidateOrder.allCases.map(AdvisorText.name))
        #expect(ScoutingPresentation.todayLabel == "Today")
        #expect(ScoutingPresentation.laterLabel == "Later")
        #expect(ScoutingPresentation.otherSlotsLabel == "Other slots")
        #expect(ScoutingPresentation.ageText(19) == "Age 19")
        #expect(ScoutingPresentation.restHelp(false) != ScoutingPresentation.restHelp(true))
        #expect(ScoutingPresentation.rowHelp(false) != ScoutingPresentation.rowHelp(true))
    }

    @Test func theNavigationStartsOnTheNeedsForThePrimaryInTodaysOrder() {
        let navigation = Navigation()
        #expect(navigation.scoutingView == .needs)
        #expect(navigation.scoutingTacticID == nil)
        #expect(navigation.scoutingOrder == .today)
        #expect(navigation.scoutingOpen.isEmpty)
        #expect(!navigation.scoutingRestOpen)
    }

    @Test func aRowIsOpenedAndClosedByItsKey() {
        let navigation = Navigation()
        let id = PlayerID(key: "fmrte:1")
        navigation.toggleScoutingRow(id)
        #expect(navigation.scoutingOpen == [id])
        navigation.toggleScoutingRow(PlayerID(key: "fmrte:2"))
        navigation.toggleScoutingRow(id)
        #expect(navigation.scoutingOpen == [PlayerID(key: "fmrte:2")])
    }
}
