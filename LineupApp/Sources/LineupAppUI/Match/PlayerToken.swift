import LineupAppCore
import LineupEngine
import SwiftUI

/// One starter on the pitch: his slot and marks, his surname and, for a planned lineup, his match-day value. A
/// caution outlines the token in amber. The selected token is chalk with turf text.
struct PlayerToken: View {
    let token: TokenContent
    let isSelected: Bool
    let select: () -> Void

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Pitch.tokenCornerRadius)
    }

    private var ink: Color { isSelected ? Theme.Colour.turf : Theme.Colour.chalk }

    var body: some View {
        Button(action: select) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: Theme.Spacing.xs) {
                    Text(token.slotText)
                        .font(Theme.Typeface.number(Theme.Match.tokenSlotSize))
                        .opacity(Theme.Match.tokenSlotOpacity)
                    Spacer(minLength: 0)
                    ForEach(token.marks, id: \.self) { mark in
                        TokenMarkView(mark: mark, onChalk: isSelected)
                    }
                }
                Spacer(minLength: 0)
                Text(token.surname)
                    .font(Theme.Typeface.text(Theme.Match.tokenNameSize, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(Theme.Match.tokenNameMinimumScale)
                if let value = token.value {
                    Text(value)
                        .font(Theme.Typeface.number(Theme.Match.tokenValueSize))
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(ink)
            .padding(Theme.Pitch.tokenPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                // Turf first, so the pitch's markings do not show through the token.
                shape.fill(Theme.Colour.turf)
                shape.fill(isSelected ? Theme.Colour.chalk : Theme.Colour.chalk.opacity(Theme.Pitch.tokenFillOpacity))
            }
            .overlay {
                if token.marks.contains(.caution) {
                    shape.strokeBorder(Theme.Colour.amber, lineWidth: Theme.Match.cautionLineWidth)
                }
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .help(token.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A mark on a token or in the key: a pin for an override, an amber triangle for a caution, the squad for a youth
/// player. `onChalk` draws it for a chalk background (a selected token, or the window) rather than the turf.
struct TokenMarkView: View {
    let mark: TokenMark
    let onChalk: Bool

    var body: some View {
        switch mark {
        case .override:
            Image(systemName: "pin.fill")
                .font(Theme.Typeface.text(Theme.Match.markSize, weight: .bold))
                .foregroundStyle(onChalk ? Theme.Colour.hoopBlue : Theme.Colour.chalk)
                .accessibilityLabel("Chosen by you")
        case .caution:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(Theme.Typeface.text(Theme.Match.markSize, weight: .bold))
                .foregroundStyle(Theme.Colour.amber)
                .accessibilityLabel("Caution")
        case .youth:
            Text(mark.badgeText)
                .font(Theme.Typeface.number(Theme.Match.youthMarkSize))
                .padding(.horizontal, Theme.Match.youthMarkPadding)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Match.youthMarkCornerRadius)
                        .strokeBorder(lineWidth: Theme.Match.youthMarkLineWidth)
                }
                .foregroundStyle(onChalk ? Theme.Colour.teal : Theme.Colour.chalk)
        }
    }
}

/// A slot of the tactic nobody could be picked for: a dashed outline with its code.
struct UnfilledSlotToken: View {
    let slot: SlotID

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Pitch.tokenCornerRadius)
    }

    var body: some View {
        Text(slot.displayName)
            .font(Theme.Typeface.number(Theme.Match.tokenSlotSize))
            .foregroundStyle(Theme.Colour.chalk.opacity(Theme.Pitch.emptyTokenOpacity))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(shape.fill(Theme.Colour.turf))
            .overlay {
                shape.strokeBorder(Theme.Colour.chalk.opacity(Theme.Pitch.emptyTokenOpacity),
                                   style: StrokeStyle(lineWidth: Theme.Pitch.emptyTokenLineWidth,
                                                      dash: Theme.Pitch.emptyTokenDash))
            }
            .help("Nobody could be picked for this slot")
    }
}
