import LineupAppCore
import SwiftUI

/// Every player shown, one row each. Numbers are in the number face and right-aligned; every column sorts.
struct PlayerTable: View {
    let rows: [SquadRow]
    @State private var sortOrder: [KeyPathComparator<SquadRow>] = []

    private var sortedRows: [SquadRow] {
        sortOrder.isEmpty ? rows : rows.sorted(using: sortOrder)
    }

    var body: some View {
        Table(sortedRows, sortOrder: $sortOrder) {
            TableColumn("Name", value: \.name) { row in
                Text(row.name)
            }
            .width(min: Theme.TableColumnWidth.nameMinimum, ideal: Theme.TableColumnWidth.nameIdeal)
            TableColumn("Squad", value: \.squadOrder) { row in
                Text(row.squadName)
            }
            .width(Theme.TableColumnWidth.squad)
            TableColumn("Age", value: \.age) { row in
                number(String(row.age))
            }
            .width(Theme.TableColumnWidth.age)
            .alignment(.numeric)
            TableColumn("Positions", value: \.positions) { row in
                Text(row.positions)
            }
            .width(Theme.TableColumnWidth.positions)
            TableColumn("Ability", value: \.currentAbility) { row in
                number(String(row.currentAbility))
            }
            .width(Theme.TableColumnWidth.ability)
            .alignment(.numeric)
            TableColumn("Potential", value: \.potentialAbility) { row in
                number(String(row.potentialAbility))
            }
            .width(Theme.TableColumnWidth.potential)
            .alignment(.numeric)
            TableColumn("Condition", value: \.condition) { row in
                number(row.conditionText)
            }
            .width(Theme.TableColumnWidth.condition)
            .alignment(.numeric)
            TableColumn("Sharpness", value: \.sharpness) { row in
                number(row.sharpnessText)
            }
            .width(Theme.TableColumnWidth.sharpness)
            .alignment(.numeric)
            TableColumn("Jadedness", value: \.jadedness) { row in
                number(String(row.jadedness))
            }
            .width(Theme.TableColumnWidth.jadedness)
            .alignment(.numeric)
            TableColumn("Status", value: \.statusText) { row in
                Text(row.statusText)
                    .foregroundStyle(row.isOut ? Theme.Colour.claret : Color.primary)
            }
            .width(min: Theme.TableColumnWidth.statusMinimum, ideal: Theme.TableColumnWidth.statusIdeal)
        }
        // The table scrolls, so its ideal height is its least: all its rows must not make the window taller.
        .frame(minHeight: Theme.Layout.tableMinimumHeight, idealHeight: Theme.Layout.tableMinimumHeight, maxHeight: .infinity)
    }

    private func number(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typeface.number(Theme.TypeSize.base))
            .offset(y: Theme.Typeface.numberDrop(Theme.TypeSize.base))
            .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
