import Foundation
import Testing
import LineupEngine
@testable import LineupAppCore

/// The Elevens screen on the captured squads: the first team and the U21s, the club named and the starter tactic as
/// the primary, with no fixtures, so the plan is quick.
@MainActor @Suite struct ElevensPresentationTests {
    private func squad(_ t: TestModel, u21: Bool = true) throws -> AppModel {
        try t.importFirstTeam()
        if u21 { try t.importU21() }
        var settings = t.model.settings
        settings.clubName = "Oxford City"
        t.model.update(settings)
        t.model.addTactic(named: "4-2-3-1")
        return t.model
    }

    private func ready(_ model: AppModel, _ tactic: UUID? = nil,
                       sourceLocation: SourceLocation = #_sourceLocation) throws -> (ElevensReport, DepthReport) {
        guard case .ready(let elevens, let depth) = model.elevens(for: tactic) else {
            Issue.record("expected elevens, got \(model.elevens(for: tactic))", sourceLocation: sourceLocation)
            throw Unready()
        }
        return (elevens, depth)
    }

    private struct Unready: Error {}

    /// Changes every imported player as `edit` says, as an import would, and works the plan and advice out again.
    private func edit(_ model: AppModel, _ edit: (inout Player) -> Void) {
        for squad in Squad.allCases {
            guard var players = model.squad.book.current[squad] else { continue }
            for index in players.indices { edit(&players[index]) }
            _ = model.squad.book.apply(ImportResult(grid: "test", players: players, warnings: []), to: squad)
        }
        model.replan()
    }

    private func player(_ model: AppModel, _ id: PlayerID) throws -> Player {
        try #require(model.squad.book.allPlayers.first { $0.id == id })
    }

    // MARK: The elevens

    @Test func theFirstElevensRowsAreInTheTacticsOrderWithEachPlayersFigures() throws {
        let t = try TestModel()
        let model = try squad(t)
        let (elevens, depth) = try ready(model)
        let sheet = model.elevenSheet(.first, report: elevens, depth: depth)
        #expect(sheet.rows.map(\.slot) == depth.slots.map(\.slot))
        #expect(sheet.unfilled.isEmpty)
        for place in elevens.first {
            let row = try #require(sheet.rows.first { $0.slot == place.slot })
            #expect(row.player == place.player)
            #expect(row.name == place.name)
            #expect(row.slotText == place.slot.longName)
            #expect(row.line == PitchLine(place.slot))
            #expect(row.ratingText == MatchText.oneDecimal(place.rating.value))
            #expect(row.familiarityText == "\(place.ipFamiliarity) / \(place.oopFamiliarity)")
            #expect(row.squadText == (try player(model, place.player)).squad.displayName)
            #expect(row.isFilled)
            #expect(row.placeLine == ElevensPresentation.sentenceCase(place.slot.longName) + ", " + (row.squadText ?? ""))
        }
        let keeper = try #require(sheet.rows.first { $0.slot == .GK })
        #expect(keeper.placeLine.hasPrefix("Goalkeeper, "))
        #expect(sheet.averageText == MatchText.oneDecimal(try #require(elevens.firstAverage)))
    }

    @Test func eachPlaceIsAMagnetWithHisSurnameAndRating() throws {
        let t = try TestModel()
        let model = try squad(t)
        let (elevens, depth) = try ready(model)
        let sheet = model.elevenSheet(.second, report: elevens, depth: depth)
        #expect(sheet.tokens.map(\.slot) == elevens.second.map(\.slot))
        for (token, place) in zip(sheet.tokens, elevens.second) {
            #expect(token.player == place.player)
            #expect(token.surname == MatchText.surname(place.name))
            #expect(token.initials == BoardText.initials(place.name))
            #expect(token.value == MatchText.oneDecimal(place.rating.value))
            let squad = try player(model, place.player).squad
            #expect(token.marks == TokenMark.marks(isInjured: place.isInjured, isOutOfPosition: place.isOutOfPosition,
                                                   squad: squad))
        }
        #expect(sheet.averageText == MatchText.oneDecimal(try #require(elevens.secondAverage)))
    }

    @Test func theSecondElevensPlayersOutOfPositionAreStampedAndMarked() throws {
        let t = try TestModel()
        let model = try squad(t)
        let (elevens, depth) = try ready(model)
        let out = elevens.second.filter(\.isOutOfPosition)
        #expect(!out.isEmpty, "the captured squads put someone out of position in the second eleven")
        let sheet = model.elevenSheet(.second, report: elevens, depth: depth)
        for row in sheet.rows {
            let isOut = out.contains { $0.slot == row.slot }
            #expect(row.stamps.contains(ElevensPresentation.outOfPositionStamp) == isOut, "\(row.slot)")
            let token = sheet.tokens.first { $0.slot == row.slot }
            #expect(token?.marks.contains(.caution) == isOut, "\(row.slot)")
        }
        #expect(ElevensPresentation.outOfPositionStamp == StatusStamp(text: "Out of position", isOut: false))
    }

    @Test func anInjuredPlayerKeepsHisPlaceAndIsStampedAndMarked() throws {
        let t = try TestModel()
        let model = try squad(t)
        let (before, _) = try ready(model)
        let striker = try #require(before.first.last { !$0.isInjured }).player
        edit(model) { if $0.id == striker { $0.isInjured = true } }
        let (elevens, depth) = try ready(model)
        let sheet = model.elevenSheet(.first, report: elevens, depth: depth)
        let row = try #require(sheet.rows.first { $0.player == striker })
        #expect(row.stamps.first == ElevensPresentation.injuredStamp)
        #expect(ElevensPresentation.injuredStamp == StatusStamp(text: "Injured", isOut: true))
        #expect(sheet.tokens.first { $0.player == striker }?.marks.first == .injured)
        #expect(sheet.rows.filter { $0.stamps.contains(ElevensPresentation.injuredStamp) }.count
                == elevens.first.filter(\.isInjured).count)
        #expect(elevens.first.filter(\.isInjured).count == before.first.filter(\.isInjured).count + 1)
    }

    @Test func marksGoInjuredThenOutOfPositionThenSquad() {
        #expect(TokenMark.marks(isInjured: false, isOutOfPosition: false, squad: .firstTeam) == [])
        #expect(TokenMark.marks(isInjured: true, isOutOfPosition: true, squad: .u21) == [.injured, .caution, .youth(.u21)])
        #expect(TokenMark.marks(isInjured: false, isOutOfPosition: true, squad: .u18) == [.caution, .youth(.u18)])
        #expect(TokenMark.injured.badgeText == "")
        #expect(ElevensPresentation.markKey.map(\.mark) == [.injured, .caution, .youth(.u21)])
        #expect(ElevensPresentation.markKey.map(\.text) == ["Injured", "Out of position", "From the U21s or U18s"])
    }

    @Test func anUnfilledSlotIsADashedCircleAndItsRowSaysNobody() throws {
        let t = try TestModel()
        let model = try squad(t, u21: false)
        let (elevens, depth) = try ready(model)
        #expect(!elevens.unfilledSecond.isEmpty, "the first team alone cannot fill a second eleven")
        let sheet = model.elevenSheet(.second, report: elevens, depth: depth)
        #expect(sheet.unfilled == elevens.unfilledSecond)
        #expect(sheet.rows.map(\.slot) == depth.slots.map(\.slot))
        for slot in elevens.unfilledSecond {
            let row = try #require(sheet.rows.first { $0.slot == slot })
            #expect(row.name == "Nobody")
            #expect(row.player == nil && !row.isFilled)
            #expect(row.squadText == nil && row.ratingText == nil && row.familiarityText == nil)
            #expect(row.stamps.isEmpty)
            #expect(row.slotText == slot.longName)
            #expect(row.placeLine == ElevensPresentation.sentenceCase(slot.longName))
        }
    }

    @Test func anElevenWithNobodyInItHasNoAverage() {
        #expect(ElevensPresentation.averageText(nil) == "—")
        #expect(ElevensPresentation.averageText(112.46) == "112.5")
        #expect(ElevensPresentation.averageLabel == "Average rating")
        #expect(ElevensPresentation.familiarityText(ip: 20, oop: 14) == "20 / 14")
    }

    // MARK: Depth

    @Test func eachSlotsMagnetShowsItsCoverAndWhetherItIsThin() throws {
        let t = try TestModel()
        let model = try squad(t)
        let (_, depth) = try ready(model)
        let tokens = ElevensPresentation.depthTokens(depth, parameters: model.planParameters)
        #expect(tokens.map(\.slot) == depth.slots.map(\.slot))
        for (token, slot) in zip(tokens, depth.slots) {
            #expect(token.coverText == String(slot.cover))
            #expect(token.isThin == slot.isThin)
            #expect(token.line == PitchLine(slot.slot))
            #expect(token.spokenText == "\(slot.slot.longName): \(AdvisorText.cover(slot, parameters: model.planParameters))")
        }
        #expect(ElevensPresentation.thinStamp == StatusStamp(text: "Thin", isOut: true))
    }

    @Test func theChosenSlotIsTheOwnersElseTheThinnestElseTheFirst() {
        let slots: [SlotID] = [.GK, .D_L, .D_C, .ST_C]
        #expect(ElevensPresentation.selectedSlot(nil, slots: slots, thin: [.D_C, .GK]) == .D_C)
        #expect(ElevensPresentation.selectedSlot(.ST_C, slots: slots, thin: [.D_C, .GK]) == .ST_C)
        #expect(ElevensPresentation.selectedSlot(nil, slots: slots, thin: []) == .GK)
        #expect(ElevensPresentation.selectedSlot(.AM_L, slots: slots, thin: [.D_L]) == .D_L, "a slot this tactic lacks")
        #expect(ElevensPresentation.selectedSlot(nil, slots: [], thin: []) == nil)
        #expect(ElevensPresentation.sentenceCase("left back") == "Left back")
    }

    @Test func theThinCoverNoteAndTheCoverLineAreTheEnginesWords() throws {
        let t = try TestModel()
        let model = try squad(t)
        let (_, depth) = try ready(model)
        #expect(!depth.thin.isEmpty)
        #expect(ElevensPresentation.selectedSlot(nil, in: depth) == depth.thin.first)
        #expect(ElevensPresentation.selectedSlot(depth.slots.last?.slot, in: depth) == depth.slots.last?.slot)
        #expect(ElevensPresentation.thinCoverNote(depth) == AdvisorText.thinCover(depth))
        #expect(ElevensPresentation.thinCoverNote(depth)?.hasPrefix("Thin cover: ") == true)
        let parameters = model.planParameters
        #expect(ElevensPresentation.coverLine(parameters, basis: .derived)
                == AdvisorText.whatCoverCounts(parameters, basis: .derived))
        #expect(ElevensPresentation.coverLine(parameters, basis: .derived).hasSuffix("is thin (this tool's estimate)."))
        #expect(model.coverLine(depth) == AdvisorText.whatCoverCounts(parameters, basis: depth.basis))
    }

    @Test func theGoalkeepersDetailSaysNobodyElseCanStepIn() throws {
        let t = try TestModel()
        let model = try squad(t)
        let (_, depth) = try ready(model)
        let keeper = try #require(depth.slots.first { $0.slot == .GK })
        let detail = try #require(model.depthDetail(for: .GK, in: depth))
        #expect(detail.title == "Goalkeeper")
        #expect(detail.cover == AdvisorText.cover(keeper, parameters: model.planParameters))
        #expect(detail.nextBest == AdvisorText.nextBest(keeper, name: nil))
        #expect(detail.options.map(\.player) == keeper.options.map(\.player))
        #expect(detail.emptyText == nil || keeper.options.isEmpty)
    }

    @Test func aSlotsDetailListsItsOptionsBestFirstWithTheirFigures() throws {
        let t = try TestModel()
        let model = try squad(t)
        let (_, depth) = try ready(model)
        let slot = try #require(depth.slots.first { $0.nextBest != nil })
        let detail = try #require(model.depthDetail(for: slot.slot, in: depth))
        let next = try #require(slot.options.first { $0.player == slot.nextBest })
        #expect(detail.nextBest == AdvisorText.nextBest(slot, name: next.name))
        #expect(detail.title == slot.slot.longName.prefix(1).uppercased() + slot.slot.longName.dropFirst())
        #expect(detail.options.map(\.player) == slot.options.map(\.player))
        for (row, option) in zip(detail.options, slot.options) {
            #expect(row.name == option.name)
            #expect(row.squadText == option.squad.displayName)
            #expect(row.ratingText == MatchText.oneDecimal(option.rating))
            #expect(row.familiarityText == "\(option.ipFamiliarity) / \(option.oopFamiliarity)")
            #expect(row.countsAsCover == option.countsAsCover)
            #expect(row.unavailable == option.unavailable.map {
                ElevensPresentation.sentenceCase(ErrorDescriptions.describe($0, parameters: model.planParameters))
            })
        }
        #expect(detail.emptyText == nil)
        #expect(detail.onLoan.isEmpty)
    }

    @Test func anOptionNeededElsewhereSaysWhere() throws {
        let t = try TestModel()
        let model = try squad(t)
        let (_, depth) = try ready(model)
        var found = false
        for slot in depth.slots {
            let detail = try #require(model.depthDetail(for: slot.slot, in: depth))
            for (row, option) in zip(detail.options, slot.options) {
                #expect(row.alsoNeeded == AdvisorText.alsoNeeded(at: option.alsoNeededAt))
                if !option.alsoNeededAt.isEmpty { found = true }
            }
        }
        #expect(found, "a first or second choice is an option at another slot")
    }

    @Test func anOptionWhoCannotPlayTodaySaysWhyInTheEnginesWords() throws {
        let t = try TestModel()
        let model = try squad(t)
        let (before, _) = try ready(model)
        let striker = try #require(before.first.last)
        edit(model) { if $0.id == striker.player { $0.isInjured = true } }
        let (_, depth) = try ready(model)
        let slot = try #require(depth.slots.first { $0.slot == striker.slot })
        let option = try #require(slot.options.first { $0.player == striker.player })
        let exclusion = try #require(option.unavailable)
        let detail = try #require(model.depthDetail(for: striker.slot, in: depth))
        let row = try #require(detail.options.first { $0.player == striker.player })
        let phrase = ErrorDescriptions.describe(exclusion, parameters: model.planParameters)
        #expect(row.unavailable == phrase.prefix(1).uppercased() + phrase.dropFirst())
        #expect(row.unavailable == "Injured")
        #expect(!row.countsAsCover)
    }

    @Test func playersOutOnLoanAreListedApart() throws {
        let t = try TestModel()
        let model = try squad(t)
        let (before, _) = try ready(model)
        let striker = try #require(before.first.last)
        edit(model) { if $0.id == striker.player { $0.loanedTo = "Elsewhere FC" } }
        let (_, depth) = try ready(model)
        let detail = try #require(model.depthDetail(for: striker.slot, in: depth))
        #expect(detail.onLoan.map(\.player) == [striker.player])
        #expect(!detail.options.contains { $0.player == striker.player })
        #expect(detail.onLoan.first?.unavailable == "On loan at Elsewhere FC")
        #expect(ElevensPresentation.onLoanHeading == "Out on loan")
    }

    @Test func aSlotNobodyCanPlaySaysSo() throws {
        let t = try TestModel()
        let model = try squad(t)
        edit(model) { $0.familiarity[.goalkeeper] = 1 }
        let (elevens, depth) = try ready(model)
        let detail = try #require(model.depthDetail(for: .GK, in: depth))
        #expect(detail.options.isEmpty)
        #expect(detail.emptyText == "Nobody can play here")
        #expect(detail.nextBest == "Nobody else can step in")
        let token = try #require(ElevensPresentation.depthTokens(depth, parameters: model.planParameters).first { $0.slot == .GK })
        #expect(token.coverText == "0" && token.isThin)
        #expect(elevens.first.first { $0.slot == .GK }?.isOutOfPosition == true)
        #expect(model.depthDetail(for: .AM_CL, in: depth) == nil, "a slot the tactic lacks has no detail")
    }

    @Test func theOptionsTableNamesItsColumns() {
        #expect(ElevensPresentation.optionColumns == ["Player", "Rating", "Familiarity in / out of possession", "Cover"])
        #expect(ElevensPresentation.elevenColumns == ["Player", "Rating", "Familiarity in / out of possession"])
    }

    // MARK: The tactic menu

    @Test func theMenuListsSavedTacticsAsTheTacticsScreenNamesThemAndShowsThePrimaryByDefault() throws {
        let t = try TestModel()
        let model = try squad(t)
        let primary = try #require(model.primaryTactic).id
        let other = model.addTactic(named: model.unusedTacticName("Wide"))
        #expect(model.elevensTacticChoices.map(\.id) == model.tactics.map(\.id))
        #expect(model.elevensTacticChoices.map(\.title) == model.tactics.map { model.menuTitle(of: $0.id) })
        #expect(model.elevensTacticChoices.first { $0.id == primary }?.title == "4-2-3-1 (primary)")
        #expect(model.elevensTacticChoices.first { $0.id == other }?.title == "Wide")
        #expect(model.elevensTacticShown(nil) == primary)
        #expect(model.elevensTacticShown(other) == other)
        #expect(model.elevensTacticShown(UUID()) == primary, "a tactic since deleted")
        #expect(model.elevensTacticChoice(primary) == nil)
        #expect(model.elevensTacticChoice(other) == other)
    }

    @Test func aTacticWithUnsavedChangesIsShownSavedAndSaysSo() throws {
        let t = try TestModel()
        let model = try squad(t)
        let primary = try #require(model.primaryTactic).id
        let other = model.addTactic(named: model.unusedTacticName("Wide"))
        #expect(model.elevensUnsavedLine(nil) == nil)
        #expect(model.elevensUnsavedLine(other) == nil)
        var draft = try #require(model.draft(for: primary))
        draft.setRole("Winger", at: .AM_L, in: .inPossession)
        model.setDraft(draft, for: primary)
        #expect(model.hasUnsavedChanges(primary))
        #expect(model.menuTitle(of: primary).hasSuffix("— unsaved changes"), "the Tactics screen still marks it")
        #expect(model.elevensTacticChoices.first { $0.id == primary }?.title == "4-2-3-1 (primary)")
        #expect(model.elevensUnsavedLine(nil) == "Showing the saved version of this tactic; it has unsaved changes.")
        #expect(model.elevensUnsavedLine(primary) == model.elevensUnsavedLine(nil))
        #expect(model.elevensUnsavedLine(other) == nil, "the tactic shown has none")
        model.revertDraft(primary)
        #expect(model.elevensUnsavedLine(nil) == nil)
    }

    @Test func aFirstElevenRowAndADepthOptionReadAsWritten() throws {
        let t = try TestModel()
        let model = try squad(t)
        let (elevens, depth) = try ready(model)
        let sheet = model.elevenSheet(.first, report: elevens, depth: depth)
        let back = try #require(sheet.rows.first { $0.slot == .D_L })
        #expect(back.name == "Evan Humphries")
        #expect(back.placeLine == "Left back, First team")
        #expect(back.familiarityText == "20 / 20")
        #expect(back.ratingText == "106.9")
        #expect(back.stamps.isEmpty)
        let centre = try #require(model.depthDetail(for: .D_CL, in: depth))
        #expect(centre.title == "Left centre-back")
        #expect(centre.cover == "3 solid players")
        let carroll = try #require(centre.options.first { $0.name == "Canice Carroll" })
        #expect(carroll.squadText == "First team")
        #expect(carroll.ratingText == "108.0")
        #expect(carroll.familiarityText == "20 / 20")
        #expect(carroll.alsoNeeded == "Also needed at left defensive midfield")
        #expect(carroll.unavailable == nil)
        #expect(!carroll.countsAsCover)
    }

    @Test func aTacticTheEngineRefusesHasItsOwnLead() {
        #expect(ElevensPresentation.failedLead == "This tactic cannot be used, so there are no elevens for it.")
    }

    // MARK: Advice not ready

    @Test func withNoPrimaryTheAdviceSaysSoInItsOwnWords() throws {
        let t = try TestModel()
        let model = try squad(t)
        var settings = model.settings
        settings.primaryTacticID = nil
        model.update(settings)
        let notReady = try #require(AdvicePresentation.notReady(model.adviceState))
        #expect(notReady.message == "No tactic is the primary one, so there is no advice.")
        #expect(notReady.problems.isEmpty)
        #expect(notReady.screen == .tactics && notReady.action == "Go to Tactics")
        // A primary the engine refuses keeps its lead.
        #expect(AdvicePresentation.notReady(.needsTactic(["A cannot be used: B."]))?.message
                == "The primary tactic cannot be used, so there is no advice.")
    }
}
