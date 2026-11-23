import LineupAppCore
import LineupEngine
import SwiftUI

/// Where the Offers screen starts: the club typed in each player's "To a club" row, and whether "Earlier offers" is
/// open. The app starts with the defaults; the pictures choose.
public struct OffersStart: Sendable {
    public var clubs: [PlayerID: String]
    public var earlierOpen: Bool

    public init(clubs: [PlayerID: String] = [:], earlierOpen: Bool = false) {
        self.clubs = clubs; self.earlierOpen = earlierOpen
    }
}

/// Something the owner has asked to delete from the record, waiting for him to say yes.
enum OfferDeletion: Identifiable, Equatable {
    case deal(UUID)
    case ask(UUID)

    var id: UUID {
        switch self {
        case .deal(let id), .ask(let id): id
        }
    }

    var question: String {
        switch self {
        case .deal: OffersPresentation.deleteDealQuestion
        case .ask: OffersPresentation.deleteAskQuestion
        }
    }
}

/// What the screen's rows hand up: a sheet to open for a round or an ask, and something to delete once asked.
struct OfferActions {
    let open: (OfferRoundDraft?) -> Void
    let delete: (OfferDeletion) -> Void
}

/// Terms to propose for the players marked to sell or to loan out, and the record of what clubs answered: the heading
/// and the intro, then "To sell" and "To loan out", a block for each player; what the offers have shown, with the day
/// it is measured from and "Measure again from today"; the deals and asks of players no longer marked, closed behind a
/// line; and how far to trust it all. With nobody marked, the engine's line and the way to Player Removal. It needs
/// only the squads and the marks, so it stands behind no gate on the advice.
public struct OffersScreen: View {
    let model: AppModel
    @Bindable var navigation: Navigation
    @State private var measuringAgain = false
    @State private var deleting: OfferDeletion?
    @Environment(\.showScreen) private var showScreen

    public init(model: AppModel, navigation: Navigation) {
        self.model = model
        self.navigation = navigation
    }

    public var body: some View {
        let sheet = model.offersSheet(clubs: navigation.offerClub)
        let actions = OfferActions(open: { navigation.offerEditor = $0 }, delete: { deleting = $0 })
        ScrollView(.vertical) {
            // Lazy, so a long record lays out only what is on screen.
            LazyVStack(alignment: .leading, spacing: Theme.Offers.partGap) {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    BoardHeading(Screen.offers.title, size: Theme.TypeSize.title)
                    MutedLines(lines: [sheet.intro])
                }
                if let nobody = sheet.nobodyMarked {
                    EmptyState(nobody, action: MatchPresentation.goTo(.removal)) { showScreen(.removal) }
                } else {
                    PlayersPart(title: OffersPresentation.toSellHeading, blocks: sheet.toSell, sheet: sheet,
                                model: model, navigation: navigation, actions: actions)
                    PlayersPart(title: OffersPresentation.toLoanOutHeading, blocks: sheet.toLoanOut, sheet: sheet,
                                model: model, navigation: navigation, actions: actions)
                }
                ShownPart(sheet: sheet) { measuringAgain = true }
                if let earlier = sheet.earlier {
                    EarlierPart(earlier: earlier, model: model, isOpen: navigation.offersEarlierOpen, actions: actions) {
                        navigation.offersEarlierOpen.toggle()
                    }
                }
                MutedLines(lines: sheet.evidenceNote, size: Theme.TypeSize.small)
            }
            .frame(maxWidth: Theme.Offers.columnMaximumWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Theme.Spacing.l)
        }
        .alert(AdvisorText.measureOffersAgainQuestion, isPresented: $measuringAgain) {
            Button(OffersPresentation.measureAgainConfirm) { model.measureOffersAgain() }
            Button(OffersPresentation.cancelTitle, role: .cancel) {}
        }
        .alert(deleting?.question ?? "", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
               presenting: deleting) { deletion in
            Button(OffersPresentation.deleteTitle, role: .destructive) {
                switch deletion {
                case .deal(let id): model.deleteDeal(id)
                case .ask(let id): model.deleteAsk(id)
                }
            }
            Button(OffersPresentation.cancelTitle, role: .cancel) {}
        }
        .sheet(item: $navigation.offerEditor) { draft in
            OfferRoundEditor(model: model, draft: draft) { navigation.offerEditor = nil }
        }
    }
}

/// "To sell" or "To loan out" over a block for each of its players, separated by faint rules; nothing with none.
private struct PlayersPart: View {
    let title: String
    let blocks: [OfferPlayerBlock]
    let sheet: OffersSheet
    let model: AppModel
    @Bindable var navigation: Navigation
    let actions: OfferActions

    var body: some View {
        if !blocks.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                BoardHeading(title, size: Theme.TypeSize.boardTitle)
                ForEach(blocks) { block in
                    FaintRule()
                    OfferPlayerBlockView(block: block, valueHint: sheet.valueHint, valueCaution: sheet.valueCaution,
                                         model: model, navigation: navigation, actions: actions)
                        .padding(.vertical, Theme.Spacing.s)
                }
            }
        }
    }
}

/// What the owner's own offers have shown: the engine's lines for sales, loans and the counter step, or its line that
/// nothing is recorded; then the day it is measured from, in muted ink, with "Measure again from today" beside it.
private struct ShownPart: View {
    let sheet: OffersSheet
    let measureAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            BoardHeading(OffersPresentation.shownHeading, size: Theme.TypeSize.boardTitle)
            if let nothing = sheet.nothingRecorded {
                MutedLines(lines: [nothing])
            }
            InkLines(lines: sheet.sales + sheet.loans + [sheet.counterStep].compactMap { $0 })
            if sheet.showsMeasuredLine {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.l) {
                    if let measured = sheet.measuredFrom {
                        Text(measured)
                            .font(Theme.Typeface.text())
                            .foregroundStyle(Theme.Colour.mutedInk)
                    }
                    if sheet.offersMeasureAgain {
                        Button(OffersPresentation.measureAgainTitle, action: measureAgain)
                            .buttonStyle(.secondary)
                            .fixedSize()
                    }
                }
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
    }
}

/// The deals and asks of players no longer marked, closed behind the line saying how many; open, their cards and asks.
/// An open deal's card still records its outcome and can be ended; nothing else but the deletion is offered.
private struct EarlierPart: View {
    let earlier: EarlierOffers
    let model: AppModel
    let isOpen: Bool
    let actions: OfferActions
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            BoardHeading(OffersPresentation.earlierHeading, size: Theme.TypeSize.boardTitle)
            RestToggle(line: earlier.line, isOpen: isOpen, toggle: toggle)
            if isOpen {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    ForEach(earlier.deals) { card in
                        OfferDealCardView(card: card, model: model, actions: actions)
                    }
                    ForEach(earlier.asks) { ask in
                        OfferAskRowView(row: ask, noBid: {}) { actions.delete(.ask(ask.id)) }
                    }
                }
                .padding(.leading, Theme.Scouting.disclosureColumn)
            }
        }
    }
}

/// The engine's sentences, one under another, in ink.
struct InkLines: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Keyed by place, so two identical lines are both shown.
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(Theme.Typeface.text())
                    .foregroundStyle(Theme.Colour.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .textSelection(.enabled)
    }
}

/// Sentences, one under another, in muted ink.
struct MutedLines: View {
    let lines: [String]
    var size: CGFloat = Theme.TypeSize.body

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(Theme.Typeface.text(size))
                    .foregroundStyle(Theme.Colour.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
    }
}
