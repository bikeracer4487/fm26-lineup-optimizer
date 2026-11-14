import LineupAppCore
import LineupEngine
import SwiftUI

/// Depth: what to recruit for on a sticky note and what cover counts, then each slot's magnet on the pitch with its
/// cover count, thin slots ringed in red and stamped, and beside it who could play in the chosen slot.
struct DepthView: View {
    let model: AppModel
    let depth: DepthReport
    let layout: PageLayout
    @Binding var chosen: SlotID?

    var body: some View {
        let selected = ElevensPresentation.selectedSlot(chosen, in: depth)
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            HStack(alignment: .center, spacing: Theme.Spacing.xl) {
                if let note = ElevensPresentation.recruitNote(depth) {
                    RecruitNote(text: note)
                }
                Text(model.coverLine(depth))
                    .font(Theme.Typeface.text(Theme.TypeSize.caption))
                    .foregroundStyle(Theme.Colour.mutedInk)
                    .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            PitchBeside(layout: layout) {
                DepthPitch(tokens: model.depthTokens(depth), selected: selected) { chosen = $0 }
            } detail: {
                if let slot = selected, let detail = model.depthDetail(for: slot, in: depth) {
                    DepthPanel(detail: detail)
                }
            }
        }
    }
}

/// The slots to recruit for, written on a yellow note held up by a magnet.
private struct RecruitNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Typeface.display(Theme.TypeSize.noteHeading))
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Theme.Sticky.horizontalPadding)
            .padding(.vertical, Theme.Sticky.verticalPadding)
            .overlay(alignment: .top) {
                Magnet.pin(Theme.Colour.markerBlue)
                    .offset(y: -Theme.Magnet.noteDiameter / 2)
                    .accessibilityHidden(true)
            }
            .stickyNote(Theme.Note.yellow, tilt: NoteTilt.degrees(at: 0))
            .frame(maxWidth: Theme.Elevens.recruitNoteMaximumWidth, alignment: .leading)
            .padding(.top, Theme.Magnet.noteDiameter / 2)
    }
}

/// Each slot of the tactic as a magnet with its cover count; clicking one chooses it.
private struct DepthPitch: View {
    let tokens: [DepthToken]
    let selected: SlotID?
    let select: (SlotID) -> Void

    var body: some View {
        let bySlot = Dictionary(uniqueKeysWithValues: tokens.map { ($0.slot, $0) })
        PitchGrid(slots: tokens.map(\.slot)) { slot in
            if let token = bySlot[slot] {
                DepthSlotToken(token: token, isSelected: selected == slot) { select(slot) }
            }
        }
    }
}

/// A slot's magnet in its line's colour with its cover count large on it, its short name beneath, and for a thin slot
/// a red ring and a "Thin" stamp beside the name, all within its cell. The chosen slot has the ink ring outside.
private struct DepthSlotToken: View {
    let token: DepthToken
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        let colours = Theme.Colour.magnet(token.line)
        Button(action: select) {
            VStack(spacing: Theme.Spacing.xxs) {
                Magnet(fill: colours.fill, text: colours.text, letters: token.coverText,
                       font: Theme.Typeface.display(Theme.Elevens.coverCountSize))
                    .overlay {
                        if token.isThin {
                            Circle()
                                .strokeBorder(Theme.Colour.markerRed, lineWidth: Theme.Magnet.ringWidth)
                                .padding(-Theme.Elevens.thinRingOffset)
                        }
                    }
                    .overlay {
                        if isSelected {
                            Circle()
                                .strokeBorder(Theme.Colour.ink, lineWidth: Theme.Magnet.ringWidth)
                                .padding(-Theme.Elevens.chosenRingOffset)
                        }
                    }
                    .padding(.vertical, Theme.Elevens.chosenRingOffset - Theme.Magnet.ringGap)
                HStack(spacing: Theme.Spacing.xs) {
                    PitchLabel(text: token.slotText, font: Theme.Typeface.text(Theme.Pitch.nameSize, weight: .bold))
                        .fixedSize()
                    if token.isThin {
                        StampView(stamp: ElevensPresentation.thinStamp)
                            .fixedSize()
                            .background(Theme.Colour.board)
                    }
                }
            }
            .foregroundStyle(Theme.Colour.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(token.spokenText)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(token.spokenText)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// The chosen slot: its name, the engine's words for its cover and for who would step in, then its options best first,
/// and those out on loan apart.
struct DepthPanel: View {
    let detail: DepthDetail

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(detail.title)
                    .font(Theme.Typeface.display(Theme.TypeSize.title))
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail.cover)
                    .font(Theme.Typeface.text(Theme.TypeSize.button, weight: .bold))
                Text(detail.nextBest)
                    .foregroundStyle(Theme.Colour.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let empty = detail.emptyText {
                Text(empty)
                    .font(Theme.Typeface.text(Theme.TypeSize.noteHeading))
                    .foregroundStyle(Theme.Colour.mutedInk)
            } else {
                OptionList(rows: detail.options)
            }
            if !detail.onLoan.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    BoardHeading(ElevensPresentation.onLoanHeading)
                    OptionList(rows: detail.onLoan)
                }
            }
        }
        .font(Theme.Typeface.text())
        .foregroundStyle(Theme.Colour.ink)
    }
}

/// Players who could cover the slot, under the list's headings.
private struct OptionList: View {
    let rows: [DepthOptionRow]

    var body: some View {
        let columns = ElevensPresentation.optionColumns
        VStack(alignment: .leading, spacing: 0) {
            ListHeadings(first: columns[0], others: [(columns[1], Theme.Elevens.ratingColumn),
                                                     (columns[2], Theme.Elevens.familiarityColumn),
                                                     (columns[3], Theme.Elevens.coverColumn)])
            ForEach(rows) { row in
                OptionRow(row: row)
                FaintRule()
            }
        }
    }
}

/// One option: his name and squad, why he cannot play today in red, where else he is needed, his rating, his
/// familiarity in each phase and a tick when he counts as cover.
private struct OptionRow: View {
    let row: DepthOptionRow

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(row.name)
                    .font(Theme.Typeface.display(Theme.TypeSize.noteHeading, weight: .bold))
                    .lineLimit(Theme.Elevens.nameLines)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.squadText)
                    .font(Theme.Typeface.text(Theme.TypeSize.small))
                    .foregroundStyle(Theme.Colour.mutedInk)
                if let unavailable = row.unavailable {
                    Text(unavailable)
                        .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .bold))
                        .foregroundStyle(Theme.Colour.redText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let also = row.alsoNeeded {
                    Text(also)
                        .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .semibold))
                        .foregroundStyle(Theme.Colour.amberText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(row.ratingText)
                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .extraBold))
                .frame(width: Theme.Elevens.ratingColumn, alignment: .trailing)
            Text(row.familiarityText)
                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .semibold))
                .frame(width: Theme.Elevens.familiarityColumn, alignment: .trailing)
            Image(systemName: "checkmark")
                .font(Theme.Typeface.text(Theme.TypeSize.button, weight: .extraBold))
                .foregroundStyle(Theme.Colour.greenText)
                .opacity(row.countsAsCover ? 1 : 0)
                .frame(width: Theme.Elevens.coverColumn, alignment: .trailing)
        }
        .padding(.vertical, Theme.Spacing.s)
        .frame(minHeight: Theme.Table.rowHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.spokenText)
    }
}
