import LineupAppCore
import SwiftUI

/// The league table: a heading row, then a row for each team with its figures right-aligned in the body face, and
/// under a row at a line that counts a rule across with the line's name at its trailing end. The club's own row stands
/// in marker blue; a side within the margin of the club carries a small mark.
struct LeagueTable: View {
    let rows: [LeagueRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headings
            HeavyRule()
            ForEach(rows) { row in
                LeagueTableRow(row: row)
                if let line = row.lineBelow {
                    LineRule(name: line)
                } else {
                    FaintRule()
                }
            }
        }
    }

    private var headings: some View {
        HStack(spacing: 0) {
            heading("").frame(width: Theme.League.placeColumn, alignment: .trailing)
            heading("").frame(minWidth: Theme.League.teamMinimum, maxWidth: .infinity, alignment: .leading)
                .padding(.leading, Theme.Spacing.m)
            ForEach(Array(AppModel.leagueColumnHeadings.enumerated()), id: \.offset) { index, text in
                heading(text).frame(width: LeagueTableRow.width(ofColumn: index), alignment: .trailing)
            }
            Color.clear.frame(width: Theme.League.markColumn, height: 0)
        }
        .frame(height: Theme.Table.headingHeight)
    }

    private func heading(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typeface.text(Theme.TypeSize.caption, weight: .extraBold))
    }
}

private struct LeagueTableRow: View {
    let row: LeagueRow

    /// Played, won, drawn, lost, for, against, goal difference, points.
    static func width(ofColumn index: Int) -> CGFloat {
        switch index {
        case 6: Theme.League.goalDifferenceColumn
        case 7: Theme.League.pointsColumn
        default: Theme.League.numberColumn
        }
    }

    var body: some View {
        let figures = [row.played, row.won, row.drawn, row.lost, row.goalsFor, row.goalsAgainst, row.goalDifference,
                       row.points]
        HStack(spacing: 0) {
            Text(row.place).frame(width: Theme.League.placeColumn, alignment: .trailing)
            Text(row.team)
                .lineLimit(Theme.Table.wrappedLines)
                .help(row.team)
                .padding(.horizontal, Theme.Spacing.m)
                .frame(minWidth: Theme.League.teamMinimum, maxWidth: .infinity, alignment: .leading)
            ForEach(Array(figures.enumerated()), id: \.offset) { index, figure in
                Text(figure)
                    .fontWeight(index == figures.count - 1 ? .bold : nil)
                    .frame(width: Self.width(ofColumn: index), alignment: .trailing)
            }
            Circle()
                .fill(Theme.Colour.mutedInk)
                .frame(width: Theme.League.markDiameter, height: Theme.League.markDiameter)
                .opacity(row.isBattled ? 1 : 0)
                .frame(width: Theme.League.markColumn)
                .accessibilityHidden(true)
        }
        .font(Theme.Typeface.text(Theme.TypeSize.body, weight: row.isOwn ? .bold : .regular))
        .foregroundStyle(row.isOwn ? Theme.Colour.markerBlue : Theme.Colour.ink)
        .frame(height: Theme.League.rowHeight)
        .background(row.isOwn ? Theme.Colour.markerBlue.opacity(Theme.League.ownRowOpacity) : Color.clear)
        .accessibilityElement(children: .combine)
    }
}

/// A rule across the table with the line's name, as the engine names it, at its trailing end.
private struct LineRule: View {
    let name: String

    var body: some View {
        HStack(spacing: Theme.League.lineGap) {
            Rectangle()
                .fill(Theme.Colour.ink)
                .frame(height: Theme.League.lineWeight)
            Text(name)
                .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .bold))
                .foregroundStyle(Theme.Colour.mutedInk)
                .fixedSize()
        }
        .padding(.vertical, Theme.Spacing.xxs)
        .accessibilityElement(children: .combine)
    }
}
