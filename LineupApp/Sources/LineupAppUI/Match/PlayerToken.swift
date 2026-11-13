import LineupAppCore
import LineupEngine
import SwiftUI

/// One starter on the pitch: a magnet in his line's colour with his initials and marks, and beneath it on the board's
/// white his surname and, for a planned lineup, his match-day value. The selected magnet has an ink ring.
struct PlayerToken: View {
    let token: TokenContent
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: Theme.Spacing.xxs) {
                Magnet.player(token.line, letters: token.initials)
                    .overlay {
                        if isSelected {
                            Circle()
                                .strokeBorder(Theme.Colour.ink, lineWidth: Theme.Magnet.ringWidth)
                                .padding(-(Theme.Magnet.ringWidth + Theme.Magnet.ringGap))
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        // Beside the magnet's top right, overlapping its edge a little.
                        if !token.marks.isEmpty {
                            HStack(spacing: Theme.Spacing.xxs) {
                                ForEach(token.marks, id: \.self) { TokenMarkView(mark: $0) }
                            }
                            .fixedSize()
                            .offset(x: Theme.Magnet.diameter - Theme.Pitch.markOffset.width,
                                    y: Theme.Pitch.markOffset.height)
                        }
                    }
                    .padding(.top, Theme.Magnet.ringWidth)
                Text(token.surname)
                    .font(Theme.Typeface.display(Theme.Pitch.nameSize, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(Theme.Pitch.labelMinimumScale)
                    .padding(.horizontal, Theme.Pitch.labelPadding)
                    .background(Theme.Colour.board)
                if let value = token.value {
                    Text(value)
                        .font(Theme.Typeface.text(Theme.Pitch.valueSize, weight: .bold))
                        .foregroundStyle(Theme.Colour.markerBlue)
                        .padding(.horizontal, Theme.Pitch.labelPadding)
                        .background(Theme.Colour.board)
                }
            }
            .foregroundStyle(Theme.Colour.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(token.name)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(token.value.map { "\(token.name), \(token.slotText), \($0)" } ?? "\(token.name), \(token.slotText)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A mark beside a magnet or in the key: a pin for a choice of the owner's, an amber triangle for a caution, the squad
/// for a youth player.
struct TokenMarkView: View {
    let mark: TokenMark

    var body: some View {
        switch mark {
        case .override:
            Image(systemName: "pin.fill")
                .font(Theme.Typeface.text(Theme.Pitch.markSize, weight: .bold))
                .foregroundStyle(Theme.Colour.markerBlue)
                .padding(Theme.Spacing.xxs)
                .background(Circle().fill(Theme.Colour.board))
                .accessibilityLabel("Chosen by you")
        case .caution:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(Theme.Typeface.text(Theme.Pitch.markSize, weight: .bold))
                .foregroundStyle(Theme.Colour.markerAmber)
                .padding(Theme.Spacing.xxs)
                .background(Circle().fill(Theme.Colour.board))
                .accessibilityLabel("Caution")
        case .youth:
            Text(mark.badgeText)
                .font(Theme.Typeface.text(Theme.Pitch.markSize, weight: .extraBold))
                .foregroundStyle(Theme.Colour.ink)
                .padding(.horizontal, Theme.Pitch.youthMarkPadding)
                .background(Theme.Colour.board, in: RoundedRectangle(cornerRadius: Theme.Pitch.youthMarkCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Pitch.youthMarkCornerRadius)
                        .strokeBorder(Theme.Colour.ink, lineWidth: Theme.Table.rowRule)
                }
        }
    }
}

/// A slot of the tactic nobody could be picked for: a dashed circle with its code.
struct UnfilledSlotToken: View {
    let slot: SlotID

    var body: some View {
        EmptyMagnet(letters: slot.displayName)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .help("Nobody could be picked for this slot")
    }
}
