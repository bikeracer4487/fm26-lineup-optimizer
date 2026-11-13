import LineupAppCore
import LineupEngine
import SwiftUI

/// The eleven as magnets on a pitch where they play, and a dashed circle for a slot nobody could fill. Clicking a
/// magnet selects it.
struct TeamSheet: View {
    let tokens: [TokenContent]
    let unfilled: [SlotID]
    let selected: SlotID?
    var select: (SlotID) -> Void = { _ in }

    var body: some View {
        let byslot = Dictionary(uniqueKeysWithValues: tokens.map { ($0.slot, $0) })
        PitchGrid(slots: tokens.map(\.slot) + unfilled) { slot in
            if let token = byslot[slot] {
                PlayerToken(token: token, isSelected: selected == slot) { select(slot) }
            } else {
                UnfilledSlotToken(slot: slot)
            }
        }
    }
}

/// What each mark beside a magnet means.
struct MarkKey: View {
    var body: some View {
        FlowLayout(spacing: Theme.Spacing.m, lineSpacing: Theme.Spacing.xs) { entries }
        .accessibilityElement(children: .combine)
    }

    private var entries: some View {
        ForEach(TokenMark.key, id: \.self) { entry in
            HStack(spacing: Theme.Spacing.xs) {
                TokenMarkView(mark: entry.mark)
                Text(entry.text)
                    .font(Theme.Typeface.text(Theme.TypeSize.caption))
                    .foregroundStyle(Theme.Colour.mutedInk)
            }
        }
    }
}
