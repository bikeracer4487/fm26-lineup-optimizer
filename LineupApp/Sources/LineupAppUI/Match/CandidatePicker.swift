import LineupAppCore
import LineupEngine
import SwiftUI

/// Everyone who could be chosen for a slot: for a planned lineup with his full-fitness rating, those who can play best
/// first, then those who cannot, greyed with the engine's reason, who cannot be chosen; for a missed fixture's
/// remembered eleven, the squad by name with the eleven last. Choosing one puts him in the slot.
public struct CandidatePicker: View {
    let text: PickerText
    let rows: [CandidateRow]
    let choose: (PlayerID) -> Void
    let cancel: () -> Void

    public init(text: PickerText, rows: [CandidateRow], choose: @escaping (PlayerID) -> Void,
                cancel: @escaping () -> Void) {
        self.text = text; self.rows = rows; self.choose = choose; self.cancel = cancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(text.title)
                    .font(Theme.Typeface.text(Theme.TypeSize.step1, weight: .semibold))
                Text(text.explanation)
                    .font(Theme.Typeface.text())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let heading = text.ratingHeading, !rows.isEmpty {
                HStack {
                    Spacer()
                    Text(heading)
                        .font(Theme.Typeface.text(weight: .semibold))
                        .foregroundStyle(.secondary)
                }
            }
            if rows.isEmpty {
                Text("Nobody can be chosen for this slot.")
                    .font(Theme.Typeface.text())
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        // A player who cannot play is not a button, so his reason is not dimmed as a disabled control's.
                        if row.canChoose {
                            Button { choose(row.player) } label: {
                                CandidateRowView(row: row)
                            }
                            .buttonStyle(.plain)
                        } else {
                            CandidateRowView(row: row)
                        }
                        Divider()
                    }
                }
            }
            HStack {
                Spacer()
                Button("Cancel", action: cancel)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(Theme.Spacing.l)
        .frame(width: Theme.Match.pickerSize.width, height: Theme.Match.pickerSize.height)
    }
}

struct CandidateRowView: View {
    let row: CandidateRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs / 2) {
                HStack(spacing: Theme.Spacing.s) {
                    Text(row.name)
                        .font(Theme.Typeface.text(weight: .semibold))
                    Text(row.squadText)
                        .font(Theme.Typeface.text())
                        .foregroundStyle(.secondary)
                    if row.isCurrent {
                        Text("In the eleven here now")
                            .font(Theme.Typeface.text())
                            .foregroundStyle(Theme.Colour.hoopBlue)
                    }
                }
                if let note = row.note {
                    Text(note)
                        .font(Theme.Typeface.text())
                        .foregroundStyle(.secondary)
                }
                if let reason = row.unavailable {
                    Text(reason)
                        .font(Theme.Typeface.text())
                        .foregroundStyle(Theme.Colour.claret)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Theme.Spacing.m)
            if let rating = row.ratingText {
                Text(rating)
                    .font(Theme.Typeface.number(Theme.TypeSize.step1))
            }
        }
        .padding(.vertical, Theme.Spacing.s)
        .foregroundStyle(row.canChoose ? .primary : .secondary)
        .contentShape(Rectangle())
    }
}
