import LineupAppCore
import LineupEngine
import SwiftUI

/// The eleven on a pitch where they play, an empty outline for a slot nobody could fill, and under it the key to the
/// tokens' marks. Clicking a token selects it.
struct TeamSheet: View {
    let tokens: [TokenContent]
    let unfilled: [SlotID]
    let selected: SlotID?
    var select: (SlotID) -> Void = { _ in }
    var showsKey = true

    var body: some View {
        let byslot = Dictionary(uniqueKeysWithValues: tokens.map { ($0.slot, $0) })
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            PitchGrid(slots: tokens.map(\.slot) + unfilled) { slot in
                if let token = byslot[slot] {
                    PlayerToken(token: token, isSelected: selected == slot) { select(slot) }
                } else {
                    UnfilledSlotToken(slot: slot)
                }
            }
            if showsKey {
                MarkKey()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// What each mark on a token means.
struct MarkKey: View {
    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            ForEach(TokenMark.key, id: \.self) { entry in
                HStack(spacing: Theme.Spacing.xs) {
                    TokenMarkView(mark: entry.mark, onChalk: true)
                    Text(entry.text)
                        .font(Theme.Typeface.text())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
