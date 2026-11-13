import LineupAppCore
import LineupEngine
import SwiftUI

/// The plan as starts, as a table on the board: a row for each player who starts at least once with his magnet, a
/// column for each fixture with a lineup showing his slot or a dash, and his number of starts. The chosen fixture's
/// column is headed in marker blue.
struct StartsGridView: View {
    let grid: StartsGrid
    let chosen: FixtureID?

    var body: some View {
        if grid.rows.isEmpty {
            EmptyState("No fixture has a lineup yet.")
            Spacer(minLength: 0)
        } else {
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    heading
                    HeavyRule()
                    ForEach(grid.rows) { row in
                        HStack(spacing: 0) {
                            Text(row.name)
                                .font(Theme.Typeface.display(Theme.TypeSize.noteHeading, weight: .bold))
                                .lineLimit(1)
                                .frame(width: Theme.Match.startsNameWidth, alignment: .leading)
                                .help(row.name)
                            ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                                Text(cell.text)
                                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: cell.isStart ? .bold : .regular))
                                    .foregroundStyle(cell.isStart ? Theme.Colour.ink : Theme.Colour.mutedInk)
                                    .frame(width: Theme.Match.startsCellWidth)
                            }
                            Text("\(row.starts)")
                                .font(Theme.Typeface.text(Theme.TypeSize.button, weight: .extraBold))
                                .frame(width: Theme.Match.startsCountWidth, alignment: .trailing)
                        }
                        .frame(height: Theme.Table.rowHeight)
                        FaintRule()
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .padding(.bottom, Theme.Spacing.m)
            }
            // Content smaller than the view would otherwise sit in its middle.
            .defaultScrollAnchor(.topLeading)
        }
    }

    private var heading: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text("Player")
                .font(Theme.Typeface.text(Theme.TypeSize.caption, weight: .extraBold))
                .frame(width: Theme.Match.startsNameWidth, alignment: .leading)
            ForEach(grid.columns) { column in
                VStack(spacing: Theme.Spacing.xxs) {
                    HStack(spacing: Theme.Spacing.xs) {
                        if column.isConfirmed {
                            Image(systemName: "lock.fill")
                                .font(Theme.Typeface.text(Theme.TypeSize.small))
                                .accessibilityLabel("Confirmed")
                        }
                        Text(column.dateText)
                            .font(Theme.Typeface.display(Theme.TypeSize.body))
                    }
                    Text(column.opponentText)
                        .font(Theme.Typeface.text(Theme.TypeSize.caption))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(column.id == chosen ? Theme.Colour.markerBlue : Theme.Colour.ink)
                .frame(width: Theme.Match.startsCellWidth)
            }
            Text("Starts")
                .font(Theme.Typeface.text(Theme.TypeSize.caption, weight: .extraBold))
                .frame(width: Theme.Match.startsCountWidth, alignment: .trailing)
        }
        .padding(.bottom, Theme.Spacing.s)
    }
}
