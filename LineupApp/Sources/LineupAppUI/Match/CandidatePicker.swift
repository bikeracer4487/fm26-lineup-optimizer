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
                BoardHeading(text.title)
                Text(text.explanation)
                    .foregroundStyle(Theme.Colour.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let heading = text.ratingHeading, !rows.isEmpty {
                HStack {
                    Spacer()
                    Text(heading)
                        .font(Theme.Typeface.text(Theme.TypeSize.caption, weight: .extraBold))
                }
            }
            if rows.isEmpty {
                Text("Nobody can be chosen for this slot.")
                    .foregroundStyle(Theme.Colour.mutedInk)
            }
            HeavyRule()
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
                        FaintRule()
                    }
                }
            }
            HStack {
                Spacer()
                Button("Cancel", action: cancel)
                    .buttonStyle(.secondary)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .font(Theme.Typeface.text())
        .foregroundStyle(Theme.Colour.ink)
        .padding(Theme.Spacing.l)
        .frame(width: Theme.Match.pickerSize.width, height: Theme.Match.pickerSize.height)
        .background(Theme.Colour.board)
        .boardAppearance()
    }
}

struct CandidateRowView: View {
    let row: CandidateRow

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Text(row.name)
                        .font(Theme.Typeface.display(Theme.TypeSize.noteHeading, weight: .bold))
                    Text(row.squadText)
                        .foregroundStyle(Theme.Colour.mutedInk)
                    if row.isCurrent {
                        Text("In the eleven here now")
                            .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                            .foregroundStyle(Theme.Colour.markerBlue)
                    }
                }
                if let note = row.note {
                    Text(note)
                        .foregroundStyle(Theme.Colour.mutedInk)
                }
                if let reason = row.unavailable {
                    Text(reason)
                        .foregroundStyle(Theme.Colour.redText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Theme.Spacing.m)
            if let rating = row.ratingText {
                Text(rating)
                    .font(Theme.Typeface.text(Theme.TypeSize.button, weight: .extraBold))
            }
        }
        .padding(.vertical, Theme.Spacing.s)
        .opacity(row.canChoose ? 1 : Theme.Button.pressedOpacity)
        .contentShape(Rectangle())
    }
}
