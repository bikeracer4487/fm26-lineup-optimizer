import LineupAppCore
import SwiftUI

/// The squad table written on the board: its headings over a heavy rule, then a row for each player with faint rules
/// between. Clicking a heading sorts by it, and clicking it again turns the order round. The screen lays the parts
/// out, so the headings can stay in view as the rows scroll.
enum PlayerTable {
    /// The width every column needs.
    static let leastWidth: CGFloat = {
        typealias C = Theme.Column
        return C.nameMinimum + C.squad + C.age + C.position + C.ability + 2 * C.meter + C.jadedness + C.statusMinimum
    }()

    /// The headings and the heavy rule under them, on the board's white so rows scroll out of sight beneath.
    struct Headings: View {
        @Binding var sort: SquadSort

        var body: some View {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    heading(.name).frame(minWidth: Theme.Column.nameMinimum, maxWidth: .infinity, alignment: .leading)
                    heading(.squad).frame(width: Theme.Column.squad, alignment: .leading)
                    heading(.age).frame(width: Theme.Column.age, alignment: .trailing)
                    heading(.position).padding(.leading, Theme.Table.columnLead)
                        .frame(width: Theme.Column.position, alignment: .leading)
                    heading(.ability).frame(width: Theme.Column.ability, alignment: .leading)
                    heading(.condition).frame(width: Theme.Column.meter, alignment: .leading)
                    heading(.sharpness).frame(width: Theme.Column.meter, alignment: .leading)
                    heading(.jadedness).frame(width: Theme.Column.jadedness, alignment: .trailing)
                    heading(.status).padding(.leading, Theme.Table.columnLead)
                        .frame(minWidth: Theme.Column.statusMinimum, maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: Theme.Table.headingHeight)
                HeavyRule()
            }
            .background(Theme.Colour.board)
        }

        private func heading(_ column: SquadColumn) -> some View {
            Button { sort = sort.choosing(column) } label: {
                HStack(spacing: Theme.Spacing.xxs) {
                    Text(column.title)
                        .lineLimit(1)
                        .minimumScaleFactor(Theme.Pitch.labelMinimumScale)
                    if sort.column == column {
                        Image(systemName: sort.ascending ? "chevron.up" : "chevron.down")
                            .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .bold))
                    }
                }
                .font(Theme.Typeface.text(Theme.TypeSize.caption, weight: .extraBold))
                .foregroundStyle(Theme.Colour.ink)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Sort by \(column.title.lowercased())")
            .accessibilityAddTraits(sort.column == column ? .isSelected : [])
        }
    }

    /// A row for each player, in the sort's order, with a faint rule under each.
    struct Rows: View {
        let rows: [SquadRow]
        let sort: SquadSort

        var body: some View {
            ForEach(SquadRow.sorted(rows, using: sort.comparators)) { row in
                PlayerRow(row: row)
                FaintRule()
            }
        }
    }
}

/// One player's row.
struct PlayerRow: View {
    let row: SquadRow

    var body: some View {
        HStack(spacing: 0) {
            Text(row.name)
                .font(Theme.Typeface.display(Theme.TypeSize.noteHeading, weight: .bold))
                .lineLimit(1)
                .help(row.name)
                .frame(minWidth: Theme.Column.nameMinimum, maxWidth: .infinity, alignment: .leading)
            Text(row.squadName)
                .foregroundStyle(Theme.Colour.mutedInk)
                .frame(width: Theme.Column.squad, alignment: .leading)
            Text(String(row.age))
                .frame(width: Theme.Column.age, alignment: .trailing)
            HStack(spacing: Theme.Spacing.s) {
                if let line = row.line {
                    Magnet.table(line)
                        .accessibilityHidden(true)
                }
                Text(row.positions)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.leading, Theme.Table.columnLead)
            .frame(width: Theme.Column.position, alignment: .leading)
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs + Theme.Spacing.xxs) {
                Text(String(row.currentAbility))
                    .font(Theme.Typeface.text(Theme.TypeSize.button, weight: .extraBold))
                Text("of a possible")
                    .foregroundStyle(Theme.Colour.mutedInk)
                Text(String(row.potentialAbility))
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .semibold))
            }
            .lineLimit(1)
            .frame(width: Theme.Column.ability, alignment: .leading)
            MeterView(meter: row.conditionMeter, text: row.conditionText)
                .frame(width: Theme.Column.meter, alignment: .leading)
            MeterView(meter: row.sharpnessMeter, text: row.sharpnessText)
                .frame(width: Theme.Column.meter, alignment: .leading)
            Text(String(row.jadedness))
                .foregroundStyle(Theme.Colour.mutedInk)
                .frame(width: Theme.Column.jadedness, alignment: .trailing)
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(row.stamps, id: \.self) { StampView(stamp: $0) }
            }
            .padding(.leading, Theme.Table.columnLead)
            .frame(minWidth: Theme.Column.statusMinimum, maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
        .font(Theme.Typeface.text())
        .frame(height: Theme.Table.rowHeight)
        .accessibilityElement(children: .combine)
    }
}
