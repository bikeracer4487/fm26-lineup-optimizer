import LineupAppCore
import LineupEngine
import SwiftUI

/// Everyone who could be chosen for a slot: for a planned lineup with his full-fitness rating and, to its right, his
/// current rating, the value he would show there, with what separates the two under his name; those who can play best
/// first, then those a rule leaves out, with the engine's reason; for a missed fixture's remembered eleven, the squad
/// by name with the eleven last. Choosing one puts him in the slot.
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
            if !rows.isEmpty, text.ratingHeading != nil || text.valueHeading != nil {
                HStack(alignment: .lastTextBaseline, spacing: Theme.Spacing.m) {
                    Spacer()
                    ForEach([text.ratingHeading, text.valueHeading].compactMap { $0 }, id: \.self) { heading in
                        Text(heading)
                            .font(Theme.Typeface.text(Theme.TypeSize.caption, weight: .extraBold))
                            .multilineTextAlignment(.trailing)
                            .lineLimit(Theme.Match.pickerHeadingLines)
                            .frame(width: Theme.Match.pickerFigureColumn, alignment: .trailing)
                    }
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
                        // A player who cannot be chosen is not a button, so his reason is not dimmed as a disabled
                        // control's. One a rule leaves out can be chosen: his row is a button, with the reason in red.
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
        // The figures stand beside his name, under their headings; the lines about him run the row's whole width.
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Text(row.name)
                        .font(Theme.Typeface.display(Theme.TypeSize.noteHeading, weight: .bold))
                    Text(row.squadText)
                        .foregroundStyle(Theme.Colour.mutedInk)
                }
                Spacer(minLength: Theme.Spacing.m)
                if let rating = row.ratingText { figure(rating) }
                if let value = row.valueText { figure(value) }
            }
            if row.isCurrent {
                Text("In the eleven here now")
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                    .foregroundStyle(Theme.Colour.markerBlue)
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
            if let working = row.workingText {
                Text(working)
                    .foregroundStyle(Theme.Colour.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Theme.Spacing.s)
        .opacity(row.canChoose ? 1 : Theme.Button.pressedOpacity)
        .contentShape(Rectangle())
    }

    /// One figure in its column, under its heading.
    private func figure(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typeface.text(Theme.TypeSize.button, weight: .extraBold))
            .frame(width: Theme.Match.pickerFigureColumn, alignment: .trailing)
    }
}
