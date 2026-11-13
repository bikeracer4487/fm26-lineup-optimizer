import LineupAppCore
import LineupEngine
import SwiftUI

/// The fixtures across the top, in date order: each one's date, opponent and importance, and whether it is confirmed
/// or missed. The chosen one is outlined in hoop blue; clicking another chooses it.
struct FixtureStrip: View {
    let cells: [FixtureCell]
    let chosen: FixtureID?
    let choose: (FixtureID) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: Theme.Spacing.s) {
                ForEach(cells) { cell in
                    Button { choose(cell.id) } label: {
                        FixtureStripCell(cell: cell, isChosen: cell.id == chosen)
                    }
                    .buttonStyle(.plain)
                    .help(cell.id == chosen ? "The match shown" : "Show this match")
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(Theme.Match.chosenLineWidth)
        }
        .scrollIndicators(.automatic)
    }
}

struct FixtureStripCell: View {
    let cell: FixtureCell
    let isChosen: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Match.stripCellCornerRadius)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                Text(cell.dateText)
                    .font(Theme.Typeface.number(Theme.TypeSize.step1))
                    .foregroundStyle(isChosen ? Theme.Colour.hoopBlue : .primary)
                Spacer(minLength: 0)
                switch cell.state {
                case .planned:
                    EmptyView()
                case .confirmed:
                    Image(systemName: "lock.fill")
                        .font(Theme.Typeface.text())
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(cell.stateText ?? "")
                case .missed:
                    Text(cell.stateText ?? "")
                        .font(Theme.Typeface.text(weight: .semibold))
                        .foregroundStyle(Theme.Colour.amber)
                }
            }
            Text(cell.opponentText)
                .font(Theme.Typeface.text(weight: isChosen ? .semibold : .regular))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            ImportanceBadge(cell.importance)
        }
        .padding(Theme.Match.stripCellPadding)
        // Every cell takes the strip's height, so a cell whose opponent takes two lines is not taller than the others.
        .frame(width: Theme.Match.stripCellWidth, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(isChosen ? Theme.Colour.hoopBlue.opacity(Theme.Match.chosenFillOpacity) : Color.clear, in: shape)
        .overlay {
            shape.strokeBorder(isChosen ? Theme.Colour.hoopBlue : Theme.Colour.separator,
                               lineWidth: isChosen ? Theme.Match.chosenLineWidth : Theme.Match.otherLineWidth)
        }
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }
}
