import LineupAppCore
import LineupEngine
import SwiftUI

/// Everyone who could be chosen for a slot with his full-fitness rating: those who can play, best first, then those
/// who cannot, greyed with the engine's reason; they cannot be chosen. Choosing one fixes him in the slot.
public struct CandidatePicker: View {
    let title: String
    let rows: [CandidateRow]
    let choose: (PlayerID) -> Void
    let cancel: () -> Void

    public init(title: String, rows: [CandidateRow], choose: @escaping (PlayerID) -> Void,
                cancel: @escaping () -> Void) {
        self.title = title; self.rows = rows; self.choose = choose; self.cancel = cancel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Typeface.text(Theme.TypeSize.step1, weight: .semibold))
                Text("Those who can play, best first at full fitness; then those who cannot, with the reason. Choosing a player fixes him here for this match.")
                    .font(Theme.Typeface.text())
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
                if let reason = row.unavailable {
                    Text(reason)
                        .font(Theme.Typeface.text())
                        .foregroundStyle(Theme.Colour.claret)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Theme.Spacing.m)
            Text(row.ratingText)
                .font(Theme.Typeface.number(Theme.TypeSize.step1))
        }
        .padding(.vertical, Theme.Spacing.s)
        .foregroundStyle(row.canChoose ? .primary : .secondary)
        .contentShape(Rectangle())
    }
}
