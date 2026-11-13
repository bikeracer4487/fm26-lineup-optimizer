import LineupAppCore
import LineupEngine
import SwiftUI

/// The plan as starts: a row for each player who starts at least once, a column for each fixture with a lineup
/// showing his slot or a dash, and his number of starts. The chosen fixture's column is headed in hoop blue.
struct StartsGridView: View {
    let grid: StartsGrid
    let chosen: FixtureID?

    var body: some View {
        if grid.rows.isEmpty {
            EmptyState("No fixture has a lineup yet.")
            Spacer(minLength: 0)
        } else {
            ScrollView([.horizontal, .vertical]) {
                Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.s, verticalSpacing: Theme.Spacing.xs) {
                    GridRow(alignment: .bottom) {
                        Text("Player")
                            .font(Theme.Typeface.text(weight: .semibold))
                            .frame(width: Theme.Match.startsNameWidth, alignment: .leading)
                        ForEach(grid.columns) { column in
                            VStack(spacing: Theme.Spacing.xs / 2) {
                                HStack(spacing: Theme.Spacing.xs) {
                                    if column.isConfirmed {
                                        Image(systemName: "lock.fill")
                                            .font(Theme.Typeface.text(Theme.Match.markSize))
                                            .accessibilityLabel("Confirmed")
                                    }
                                    Text(column.dateText)
                                        .font(Theme.Typeface.number(Theme.TypeSize.step1))
                                }
                                Text(column.opponentText)
                                    .font(Theme.Typeface.text())
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundStyle(column.id == chosen ? Theme.Colour.hoopBlue : .primary)
                            .frame(width: Theme.Match.startsCellWidth)
                        }
                        Text("Starts")
                            .font(Theme.Typeface.text(weight: .semibold))
                            .frame(width: Theme.Match.startsCountWidth, alignment: .trailing)
                    }
                    Divider()
                        .gridCellUnsizedAxes(.horizontal)
                    ForEach(grid.rows) { row in
                        GridRow {
                            Text(row.name)
                                .font(Theme.Typeface.text())
                                .lineLimit(1)
                                .frame(width: Theme.Match.startsNameWidth, alignment: .leading)
                                .help(row.name)
                            ForEach(Array(row.cells.enumerated()), id: \.offset) { _, cell in
                                Text(cell.text)
                                    .font(Theme.Typeface.number(Theme.TypeSize.step1))
                                    .foregroundStyle(cell.isStart ? .primary : .secondary)
                                    .offset(y: Theme.Typeface.numberDrop(Theme.TypeSize.step1))
                                    .frame(width: Theme.Match.startsCellWidth)
                            }
                            Text("\(row.starts)")
                                .font(Theme.Typeface.number(Theme.TypeSize.step1))
                                .offset(y: Theme.Typeface.numberDrop(Theme.TypeSize.step1))
                                .frame(width: Theme.Match.startsCountWidth, alignment: .trailing)
                        }
                    }
                }
                .padding(.bottom, Theme.Spacing.m)
            }
            // Content smaller than the view would otherwise sit in its middle.
            .defaultScrollAnchor(.topLeading)
        }
    }
}
