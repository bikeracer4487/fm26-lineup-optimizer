import LineupAppCore
import LineupEngine
import SwiftUI

/// The fixtures across the top as sticky notes, in date order: each one's date, opponent and importance, and whether
/// it is confirmed or missed. The chosen one's magnet is blue and its note has a blue foot; clicking another chooses
/// it. The notes share the width; when they do not fit, they keep their least width and scroll.
struct FixtureStrip: View {
    let cells: [FixtureCell]
    let chosen: FixtureID?
    let choose: (FixtureID) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            notes(fillsWidth: true)
            ScrollView(.horizontal) {
                notes(fillsWidth: false)
            }
            .scrollIndicators(.automatic)
        }
    }

    private func notes(fillsWidth: Bool) -> some View {
        HStack(alignment: .top, spacing: Theme.Match.noteGap) {
            ForEach(Array(cells.enumerated()), id: \.element.id) { index, cell in
                Button { choose(cell.id) } label: {
                    FixtureNote(cell: cell, isChosen: cell.id == chosen, tilt: NoteTilt.degrees(at: index))
                        .frame(minWidth: Theme.Match.noteMinimumWidth,
                               maxWidth: fillsWidth ? Theme.Match.noteMaximumWidth : Theme.Match.noteMinimumWidth)
                }
                .buttonStyle(.plain)
                .help(cell.id == chosen ? "The match shown" : "Show this match")
            }
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, Theme.Match.notesTopPadding)
        .padding(.horizontal, Theme.Spacing.xs)
        .padding(.bottom, Theme.Spacing.xs)
    }
}

/// One fixture's sticky note, in its importance's colour, held up by a magnet.
struct FixtureNote: View {
    let cell: FixtureCell
    let isChosen: Bool
    let tilt: Double

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(cell.dateText)
                .font(Theme.Typeface.display(Theme.TypeSize.noteHeading))
                .lineLimit(1)
            Text(cell.opponentText)
                .font(Theme.Typeface.text())
                .fixedSize(horizontal: false, vertical: true)
            Text(cell.importance.noteText)
                .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            switch cell.state {
            case .planned:
                EmptyView()
            case .confirmed:
                Label(cell.stateText ?? "", systemImage: "lock.fill")
                    .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .extraBold))
            case .missed:
                Text(cell.stateText ?? "")
                    .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .extraBold))
            }
        }
        .padding(.horizontal, Theme.Match.notePadding)
        .padding(.top, Theme.Sticky.verticalPadding)
        .padding(.bottom, Theme.Sticky.verticalPadding + Theme.Sticky.footHeight)
        // Every note takes the row's height, so a note whose words wrap is not taller than the others.
        .frame(maxWidth: .infinity, minHeight: Theme.Match.noteHeight, maxHeight: .infinity, alignment: .topLeading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isChosen ? Theme.Colour.markerBlue : Color.clear)
                .frame(height: Theme.Sticky.footHeight)
        }
        .overlay(alignment: .top) {
            Magnet.pin(isChosen ? Theme.Colour.markerBlue : Theme.Colour.idleMagnet)
                .offset(y: -Theme.Magnet.noteDiameter / 2)
                .accessibilityHidden(true)
        }
        .stickyNote(Theme.Note.fixture(cell.importance), tilt: tilt)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}
