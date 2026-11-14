import LineupAppCore
import LineupEngine
import SwiftUI

/// Where the Elevens screen starts: which view, and which slot Depth shows. The app starts with the defaults; the
/// pictures choose.
public struct ElevensStart: Sendable {
    public var view: ElevensView
    public var slot: SlotID?

    public init(view: ElevensView = .first, slot: SlotID? = nil) {
        self.view = view; self.slot = slot
    }
}

/// The first and second elevens for a tactic, and the cover for every slot: the tactic menu and the three views beside
/// the heading, then the chosen view. The pitch and the list beside it are laid out as Match Selection's: beside it
/// when there is room, the screen scrolling when short, the list under the pitch when narrow.
public struct ElevensScreen: View {
    let model: AppModel
    @Bindable var navigation: Navigation
    @State private var layout = PageLayout(Theme.Layout.defaultWindow)

    public init(model: AppModel, navigation: Navigation) {
        self.model = model
        self.navigation = navigation
    }

    public var body: some View {
        Group {
            if layout.scrolls {
                ScrollView(.vertical) { page }
            } else {
                page
            }
        }
        .onGeometryChange(for: PageLayout.self) { PageLayout($0.size) } action: { layout = $0 }
    }

    private var page: some View {
        AdviceGate(screen: .elevens, state: model.adviceState) {
            controls
        } content: { _ in
            ElevensContent(model: model, navigation: navigation, layout: layout)
        }
    }

    /// The tactic menu, the primary marked as the Tactics screen marks it, and the three views as tabs.
    private var controls: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.l) {
            Picker(ElevensPresentation.tacticMenuLabel, selection: Binding(
                get: { model.elevensTacticShown(navigation.elevensTacticID) },
                set: { picked in navigation.elevensTacticID = picked.flatMap(model.elevensTacticChoice) })) {
                ForEach(model.elevensTacticChoices, id: \.id) { choice in
                    Text(choice.title)
                        .tag(UUID?.some(choice.id))
                }
            }
            .font(Theme.Typeface.text())
            .fixedSize()
            BoardTabs(choices: ElevensView.allCases.map { ($0, $0.title) }, selection: $navigation.elevensView)
        }
    }
}

/// The chosen view of the chosen tactic, or the engine's sentences when it cannot be used.
private struct ElevensContent: View {
    let model: AppModel
    @Bindable var navigation: Navigation
    let layout: PageLayout
    @Environment(\.showScreen) private var showScreen

    var body: some View {
        switch model.elevens(for: navigation.elevensTacticID) {
        case .notReady:
            // The gate shows why while the advice is not ready.
            EmptyView()
        case .failed(let problems):
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                Text(ElevensPresentation.failedLead)
                    .font(Theme.Typeface.text(Theme.TypeSize.noteHeading))
                    .foregroundStyle(Theme.Colour.mutedInk)
                ForEach(problems, id: \.self) { CautionLine($0) }
                Button(MatchPresentation.goTo(.tactics)) { showScreen(.tactics) }
                    .buttonStyle(.primary)
            }
            .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
        case .ready(let elevens, let depth):
            switch navigation.elevensView {
            case .first:
                ElevenView(sheet: model.elevenSheet(.first, report: elevens, depth: depth), layout: layout)
            case .second:
                ElevenView(sheet: model.elevenSheet(.second, report: elevens, depth: depth), layout: layout)
            case .depth:
                DepthView(model: model, depth: depth, layout: layout, chosen: $navigation.elevensSlot)
            }
        }
    }
}

/// One eleven: its magnets on the pitch, and beside it its average and the list of its places with what the marks mean.
private struct ElevenView: View {
    let sheet: ElevenSheet
    let layout: PageLayout

    var body: some View {
        PitchBeside(layout: layout) {
            TeamSheet(tokens: sheet.tokens, unfilled: sheet.unfilled, selected: nil)
        } detail: {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                FigureCard(label: ElevensPresentation.averageLabel, figure: sheet.averageText)
                ElevenList(rows: sheet.rows)
                MarkKey(key: ElevensPresentation.markKey)
            }
        }
    }
}

/// A figure on a card of its own, its label above it.
struct FigureCard: View {
    let label: String
    let figure: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(label)
                .font(Theme.Typeface.text(Theme.TypeSize.small))
                .foregroundStyle(Theme.Colour.mutedInk)
            Text(figure)
                .font(Theme.Typeface.display(Theme.TypeSize.boardTitle))
                .foregroundStyle(Theme.Colour.ink)
        }
        .padding(.horizontal, Theme.Spacing.m)
        .padding(.vertical, Theme.Spacing.s)
        .boardCard(cornerRadius: Theme.Card.smallCornerRadius)
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

/// The headings over a list beside the pitch, the first taking what the others leave, each other one right-aligned in
/// its width, over a heavy rule.
struct ListHeadings: View {
    let first: String
    let others: [(title: String, width: CGFloat)]

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 0) {
                heading(first)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(others, id: \.title) { other in
                    heading(other.title)
                        .multilineTextAlignment(.trailing)
                        .frame(width: other.width, alignment: .trailing)
                }
            }
            .padding(.bottom, Theme.Spacing.xs)
            .frame(minHeight: Theme.Table.headingHeight, alignment: .bottom)
            HeavyRule()
        }
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typeface.text(Theme.TypeSize.caption, weight: .extraBold))
            .foregroundStyle(Theme.Colour.ink)
            .lineLimit(Theme.Table.wrappedLines)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The eleven's places in the tactic's order: magnet, name, slot and squad, stamps, rating and familiarity.
private struct ElevenList: View {
    let rows: [ElevenRow]

    var body: some View {
        let columns = ElevensPresentation.elevenColumns
        VStack(alignment: .leading, spacing: 0) {
            ListHeadings(first: columns[0], others: [(columns[1], Theme.Elevens.ratingColumn),
                                                     (columns[2], Theme.Elevens.familiarityColumn)])
            ForEach(rows) { row in
                ElevenListRow(row: row)
                FaintRule()
            }
        }
    }
}

private struct ElevenListRow: View {
    let row: ElevenRow

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(alignment: .center, spacing: Theme.Spacing.s) {
                if row.isFilled {
                    Magnet.table(row.line)
                } else {
                    EmptyMagnet(diameter: Theme.Magnet.tableDiameter)
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(row.name)
                        .font(Theme.Typeface.display(Theme.TypeSize.noteHeading, weight: .bold))
                        .foregroundStyle(row.isFilled ? Theme.Colour.ink : Theme.Colour.mutedInk)
                        .lineLimit(Theme.Elevens.nameLines)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(row.placeLine)
                        .font(Theme.Typeface.text(Theme.TypeSize.small))
                        .foregroundStyle(Theme.Colour.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                    if !row.stamps.isEmpty {
                        HStack(spacing: Theme.Spacing.xs) {
                            ForEach(row.stamps, id: \.self) { StampView(stamp: $0) }
                        }
                        .padding(.vertical, Theme.Spacing.xxs)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.ratingText ?? "")
                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .extraBold))
                .frame(width: Theme.Elevens.ratingColumn, alignment: .trailing)
            Text(row.familiarityText ?? "")
                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .semibold))
                .frame(width: Theme.Elevens.familiarityColumn, alignment: .trailing)
        }
        .foregroundStyle(Theme.Colour.ink)
        .padding(.vertical, Theme.Spacing.s)
        .frame(minHeight: Theme.Table.rowHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.spokenText)
    }
}
