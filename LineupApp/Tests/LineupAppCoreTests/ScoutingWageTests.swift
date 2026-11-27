import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

/// The wage line on each pasted player: the range for his tier, for the tactic shown, read from what the whole squad's
/// elevens are paid, and his present wage set beside it, with the closed row's caution.
@MainActor @Suite struct ScoutingWageTests {
    /// The captured first team with the U21s pasted as another club's players.
    private func pasted(_ paste: String? = nil) throws -> TestModel {
        let t = try ScoutingSetup.ready()
        try ScoutingSetup.paste(t, paste: paste)
        return t
    }

    /// Types the club's three figures, each given here by the week and typed for a year, as the fields take them: a
    /// budget so large that no share of it caps a range, 10,000 a week of it left, and a highest wage over any tier's.
    private func typeLimits(_ t: TestModel, budget: Int = 1_000_000, spent: Int = 990_000, highest: Int? = 50_000) {
        t.model.setWageLimit(.wageBudget, text: String(budget * 52))
        t.model.setWageLimit(.wagesSpent, text: String(spent * 52))
        if let highest { t.model.setWageLimit(.highestWage, text: String(highest * 52)) }
    }

    private func sheet(_ t: TestModel, order: CandidateOrder = .today) throws -> CandidatesSheet {
        try #require(t.model.candidatesSheet(try ScoutingSetup.report(t.model), order: order))
    }

    private func rows(_ sheet: CandidatesSheet) -> [ScoutingCandidateRow] { sheet.groups.flatMap { $0.rows + $0.moreRows } }

    /// What the whole squad's elevens for the primary tactic are paid, by tier.
    private func tierWages(_ t: TestModel) throws -> [WageTier: [PlayerWage]] {
        guard case .ready(let elevens, _) = t.model.elevens(for: nil) else {
            Issue.record("expected the elevens")
            throw ScoutingSetup.Unready()
        }
        return WageRange.tierWages(tiers: elevens.tiers, players: t.model.squad.book.allPlayers, ownClub: t.model.ownClub)
    }

    /// The engine's guide for `candidate` with the model's limits.
    private func guide(for candidate: LineupEngine.Candidate, in t: TestModel) throws
        -> (level: CandidateLevel, slot: SlotID, guide: WageGuide) {
        try #require(try WageRange.candidateGuide(candidate, wages: try tierWages(t), limits: t.model.contracts.limits,
                                                  parameters: t.model.planParameters))
    }

    /// The paste held again with one player's wage set to what `wage` makes of his guide.
    private func repaid(_ t: TestModel, _ wage: (WageGuide) -> Double?) throws
        -> (id: PlayerID, guide: (level: CandidateLevel, slot: SlotID, guide: WageGuide), perWeek: Double) {
        let report = try ScoutingSetup.report(t.model)
        for candidate in report.candidates {
            guard let found = try WageRange.candidateGuide(candidate, wages: try tierWages(t),
                                                           limits: t.model.contracts.limits,
                                                           parameters: t.model.planParameters),
                  let perWeek = wage(found.guide) else { continue }
            let paste = try #require(t.model.scoutingPaste)
            var players = paste.players
            let index = try #require(players.firstIndex { $0.id == candidate.id })
            players[index].wagePerWeek = perWeek
            t.model.hold(ScoutingPaste(players: players, money: paste.money))
            return (candidate.id, found, perWeek)
        }
        Issue.record("no candidate has a guide that fits")
        throw ScoutingSetup.Unready()
    }

    /// The captures are pounds by the week; every wage is shown by the year.
    private var money: MoneyStyle { MoneyStyle(symbol: "£", period: .yearly) }

    // MARK: The lines

    @Test func anOpenedRowsWageLinesStartWithTheLeadAndEndWithTheAskNotKnown() throws {
        let t = try pasted()
        typeLimits(t)
        let report = try ScoutingSetup.report(t.model)
        let sheet = try sheet(t)
        #expect(t.model.squad.book.moneyStyle == money)
        let withSlots = report.candidates.filter { !$0.slots.isEmpty }
        #expect(!withSlots.isEmpty)
        for candidate in withSlots {
            let row = try #require(rows(sheet).first { $0.id == candidate.id })
            let found = try guide(for: candidate, in: t)
            #expect(row.wageLines.first == AdvisorText.candidateWageLead(level: found.level, slot: found.slot))
            #expect(row.wageLines.last == AdvisorText.candidateAskNotKnown)
            let guideLines = AdvisorText.wageGuideLines(found.guide, money: money)
            #expect(Array(row.wageLines.dropFirst().prefix(guideLines.count)) == guideLines)
            #expect(row.wageLines.contains(AdvisorText.candidatePresentWage(perWeek: candidate.player.wagePerWeek,
                                                                           money: money)))
        }
        #expect(sheet.wageEvidenceNote == AdvisorText.wageEvidenceSentence)
        #expect(sheet.evidenceLines.last == AdvisorText.wageEvidenceSentence)
        #expect(sheet.evidenceLines.first == sheet.evidenceNote)
    }

    @Test func aPlayerPaidAboveHisTiersHighestIsCautionedOnTheClosedRow() throws {
        let t = try pasted()
        typeLimits(t)
        let found = try repaid(t) { guide in guide.paid.map { $0.highest + 100 } }
        let row = try #require(rows(try sheet(t)).first { $0.id == found.id })
        let paid = try #require(found.guide.guide.paid)
        let expected = AdvisorText.wageVerdictLine(.aboveTier(highest: paid.highest), figure: .presentWage,
                                                   guide: found.guide.guide, money: money)
        #expect(row.wageCaution == expected)
        #expect(expected.hasPrefix("His wage now"))
        #expect(row.wageLines.contains(expected))
        // Shown on the closed row, and in the wage lines once opened, not twice.
        #expect(row.linesShown(inRest: false, isOpen: false).wageCaution == expected)
        #expect(row.linesShown(inRest: true, isOpen: false).wageCaution == expected)
        #expect(row.linesShown(inRest: false, isOpen: false).wage.isEmpty)
        #expect(row.linesShown(inRest: false, isOpen: true).wageCaution == nil)
        #expect(row.linesShown(inRest: false, isOpen: true).wage == row.wageLines)
        #expect(row.opens(inRest: false))
    }

    @Test func aPlayerPaidAboveTheHighestWageIsCautionedWithThatFirst() throws {
        let t = try pasted()
        typeLimits(t)
        let found = try repaid(t) { guide in guide.highestWagePerWeek.map { $0 + 100 } }
        let row = try #require(rows(try sheet(t)).first { $0.id == found.id })
        let limit = try #require(found.guide.guide.highestWagePerWeek)
        let expected = AdvisorText.wageVerdictLine(.overHighestWage(limit: limit), figure: .presentWage,
                                                   guide: found.guide.guide, money: money)
        #expect(row.wageCaution == expected)
        #expect(expected == "His wage now is above the most you can offer one player, \(Display.wage(perWeek: limit, money)).")
    }

    @Test func aPlayerPaidAboveTheCeilingButNotTheHighestWageIsCautionedWithTheCeiling() throws {
        let t = try pasted()
        // A highest wage above every tier's share of the budget, so a wage can sit between the two.
        typeLimits(t, highest: 100_000)
        let found = try repaid(t) { guide in
            guard let ceiling = guide.ceilingPerWeek, let highest = guide.highestWagePerWeek,
                  ceiling + 100 < highest else { return nil }
            return ceiling + 100
        }
        let row = try #require(rows(try sheet(t)).first { $0.id == found.id })
        let ceiling = try #require(found.guide.guide.ceilingPerWeek)
        let expected = AdvisorText.wageVerdictLine(.overCeiling(ceiling: ceiling), figure: .presentWage,
                                                   guide: found.guide.guide, money: money)
        #expect(row.wageCaution == expected)
        #expect(expected.hasPrefix("His wage now is above a "))
        #expect(expected.hasSuffix("of your wage budget, \(Display.wage(perWeek: ceiling, money)) (this tool's estimate)."))
    }

    @Test func aPlayerPaidWithinTheRangeHasNoCautionAndAWithinLine() throws {
        let t = try pasted()
        typeLimits(t)
        let found = try repaid(t) { guide in guide.paid.map { ($0.lowerQuartile + $0.highest) / 2 } }
        let row = try #require(rows(try sheet(t)).first { $0.id == found.id })
        #expect(row.wageCaution == nil)
        #expect(row.wageLines.contains(AdvisorText.wageVerdictLine(.withinTier, figure: .presentWage,
                                                                   guide: found.guide.guide, money: money)))
        #expect(row.wageLines.contains(AdvisorText.candidatePresentWage(perWeek: found.perWeek, money: money)))
    }

    @Test func aPlayerPaidNothingGetsTheRangeAndNoVerdict() throws {
        let t = try pasted()
        typeLimits(t)
        let found = try repaid(t) { _ in 0 }
        let row = try #require(rows(try sheet(t)).first { $0.id == found.id })
        let guide = found.guide
        #expect(row.wageLines == [AdvisorText.candidateWageLead(level: guide.level, slot: guide.slot)]
                + AdvisorText.wageGuideLines(guide.guide, money: money)
                + [AdvisorText.candidatePresentWage(perWeek: 0, money: money), AdvisorText.candidateAskNotKnown])
        #expect(row.wageLines.contains("He is paid no wage now."))
        #expect(row.wageCaution == nil)
    }

    @Test func aPasteInAnotherCurrencyGetsTheRangeAndNoComparison() throws {
        let t = try pasted(try Captures.u21AtAnotherClub.replacingOccurrences(of: "£", with: "€"))
        typeLimits(t, highest: 1)
        #expect(t.model.scoutingPaste?.money.symbol == "€")
        let report = try ScoutingSetup.report(t.model)
        let sheet = try sheet(t)
        let withSlots = report.candidates.filter { !$0.slots.isEmpty }
        #expect(!withSlots.isEmpty)
        for candidate in withSlots {
            let row = try #require(rows(sheet).first { $0.id == candidate.id })
            let found = try guide(for: candidate, in: t)
            #expect(row.wageLines == [AdvisorText.candidateWageLead(level: found.level, slot: found.slot)]
                    + AdvisorText.wageGuideLines(found.guide, money: money)
                    + [AdvisorText.candidateWageOtherCurrency, AdvisorText.candidateAskNotKnown])
            // A highest wage of 1 a week is under every wage, and still no caution: the two cannot be compared.
            #expect(row.wageCaution == nil)
        }
        // The range is in the squads' style, the paste's own lines in its own.
        #expect(rows(sheet).allSatisfy { $0.wage.hasPrefix("€") })
    }

    @Test func noBudgetLeftPutsNoCautionOnAnyClosedRow() throws {
        let t = try pasted()
        typeLimits(t, budget: 1_000_000, spent: 1_000_000, highest: nil)
        let all = rows(try sheet(t))
        let paid = all.filter { row in t.model.scoutingPaste?.players.first { $0.id == row.id }.map { $0.wagePerWeek > 0 } == true }
        #expect(!paid.isEmpty)
        for row in all { #expect(row.wageCaution == nil) }
        // The budget left of nothing is said in the opened row.
        #expect(paid.filter { !$0.wageLines.isEmpty }.allSatisfy { row in
            row.wageLines.contains { $0.contains("more than your wage budget has left") }
        })
    }

    // MARK: What is left alone

    @Test func thePartsGroupsAndOrderAreTheSameWithAndWithoutLimits() throws {
        let t = try pasted()
        let report = try ScoutingSetup.report(t.model)
        let judged = t.model.timesCandidatesJudged
        func shape(_ sheet: CandidatesSheet) -> [[String]] {
            sheet.groups.map { group in
                [group.id, group.partTitle ?? "", group.heading ?? "", group.closedLine ?? ""]
                    + (group.rows + group.moreRows).map { row in
                        ([row.id.key] + row.todayLines + row.laterLines + row.cautions
                         + row.otherSlots.flatMap(\.lines)).joined(separator: "|")
                    }
            }
        }
        var before: [CandidateOrder: [[String]]] = [:]
        for order in CandidateOrder.allCases { before[order] = shape(try sheet(t, order: order)) }
        typeLimits(t, budget: 1_000, spent: 5_000, highest: 1)
        #expect(try ScoutingSetup.report(t.model) == report)
        for order in CandidateOrder.allCases {
            let after = try sheet(t, order: order)
            #expect(shape(after) == before[order])
            #expect(shape(ScoutingPresentation.candidatesSheet(report, order: order, pasted: 6,
                                                               money: try #require(t.model.scoutingPaste).money.byYear))
                    == before[order])
            #expect(rows(after).contains { $0.wageCaution != nil }, "a highest wage of 1 a week is under every wage")
        }
        #expect(t.model.timesCandidatesJudged == judged)
    }

    @Test func withTheAdviceNotReadyTheSheetIsAsBeforeAndNoRowHasWageLines() throws {
        let t = try pasted()
        typeLimits(t)
        let report = try ScoutingSetup.report(t.model)
        #expect(rows(try sheet(t)).contains { !$0.wageLines.isEmpty })
        let primary = try #require(t.model.primaryTactic).id
        t.model.deleteTactic(primary)
        guard case .needsTactic = t.model.adviceState else {
            Issue.record("expected the advice not to be ready, got \(t.model.adviceState)")
            return
        }
        let paste = try #require(t.model.scoutingPaste)
        let shown = try #require(t.model.candidatesSheet(report, order: .today))
        #expect(shown == ScoutingPresentation.candidatesSheet(report, order: .today, pasted: paste.players.count,
                                                              money: paste.money.byYear))
        #expect(rows(shown).allSatisfy { $0.wageLines.isEmpty && $0.wageCaution == nil })
        #expect(shown.wageEvidenceNote == nil)
        #expect(shown.evidenceLines == [shown.evidenceNote].compactMap { $0 })
    }

    @Test func typingALimitChangesTheRowsTheNextTimeTheyAreReadWithNoPasteOrReplan() throws {
        let t = try pasted()
        let first = try sheet(t)
        let judged = t.model.timesCandidatesJudged
        let planned = t.model.timesPlanned
        let advised = t.model.timesAdvised
        let pasted = t.model.scoutingPaste
        t.model.setWageLimit(.highestWage, text: "52")
        let second = try sheet(t)
        #expect(second != first)
        let line = "The most you can offer one player is \(Display.wage(perWeek: 1, money))."
        #expect(rows(second).filter { !$0.wageLines.isEmpty }.allSatisfy { $0.wageLines.contains(line) })
        #expect(rows(second).contains { $0.wageCaution?.hasPrefix("His wage now is above the most you can offer") == true })
        #expect(!rows(first).contains { $0.wageLines.contains(line) })
        #expect(t.model.timesCandidatesJudged == judged)
        #expect(t.model.timesPlanned == planned)
        #expect(t.model.timesAdvised == advised)
        #expect(t.model.scoutingPaste == pasted)
    }

    @Test func aPlayerWhoPlaysNoSlotHasNeither() throws {
        let t = try pasted()
        typeLimits(t)
        let paste = try #require(t.model.scoutingPaste)
        var players = paste.players
        for position in players[0].familiarity.keys { players[0].familiarity[position] = 1 }
        t.model.hold(ScoutingPaste(players: players, money: paste.money))
        let row = try #require(rows(try sheet(t)).first { $0.id == players[0].id })
        #expect(row.todayLines == [AdvisorText.playsNoSlot])
        #expect(row.wageLines.isEmpty && row.wageCaution == nil)
    }

    @Test func theRangeIsReadFromTheElevensOfTheTacticShown() throws {
        let t = try pasted()
        typeLimits(t)
        let second = t.model.addTactic(named: t.model.unusedTacticName("Wide"))
        let report = try ScoutingSetup.report(t.model, second)
        guard case .ready(let elevens, _) = t.model.elevens(for: second) else {
            Issue.record("expected the elevens for the second tactic")
            return
        }
        let wages = WageRange.tierWages(tiers: elevens.tiers, players: t.model.squad.book.allPlayers,
                                        ownClub: t.model.ownClub)
        let basis = CandidateWageBasis(wages: wages, limits: t.model.contracts.limits, money: money,
                                       parameters: t.model.planParameters)
        let paste = try #require(t.model.scoutingPaste)
        let shown = try #require(t.model.candidatesSheet(report, order: .today, for: second))
        #expect(shown == ScoutingPresentation.candidatesSheet(report, order: .today, pasted: paste.players.count,
                                                              money: paste.money.byYear, wages: basis))
        #expect(rows(shown).contains { !$0.wageLines.isEmpty })
    }

    @Test func theSampleCarriesTheWageCautionOnOneRowAndTheNoteItsLastLine() throws {
        let model = try SampleData.modelWithCandidates(repositoryRoot: Captures.repositoryRoot)
        defer { try? FileManager.default.removeItem(at: model.store.directory) }
        let sheet = try #require(model.candidatesSheet(try ScoutingSetup.report(model), order: .today))
        let cautioned = rows(sheet).filter { $0.wageCaution != nil }
        #expect(cautioned.map(\.name) == [SampleData.candidatePaidAboveTierName])
        #expect(cautioned.first?.wageCaution?.hasPrefix("His wage now is above anything your") == true)
        #expect(sheet.evidenceLines.last == AdvisorText.wageEvidenceSentence)
    }

    @Test func theLabelAndTheHelpArePlainWords() {
        #expect(ScoutingPresentation.wageLabel == "Wage")
        #expect(ScoutingPresentation.rowHelp(false) == "Show more")
        #expect(ScoutingPresentation.rowHelp(true) == "Show less")
    }
}
