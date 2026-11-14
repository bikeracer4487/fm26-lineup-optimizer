import LineupAppCore
import LineupEngine
import SwiftUI

/// One starter on the pitch: a magnet in his line's colour with his initials, his marks on its rim, and beneath it on
/// the board's white his surname and, for a planned lineup, his match-day value, each one line. Every token in a lineup
/// is the same height, centred in its cell, so the magnets along a row line up. The selected magnet has an ink ring.
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
                    .overlay(alignment: .top) { MarksOnRim(marks: token.marks) }
                    .padding(.top, Theme.Magnet.ringWidth)
                PitchLabel(text: token.surname, font: Theme.Typeface.display(Theme.Pitch.nameSize, weight: .bold))
                if let value = token.value {
                    PitchLabel(text: value, font: Theme.Typeface.text(Theme.Pitch.valueSize, weight: .bold))
                        .foregroundStyle(Theme.Colour.markerBlue)
                }
            }
            .foregroundStyle(Theme.Colour.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(token.name)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(token.spokenText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// One line of words beneath a magnet, on the board's white so a pitch line does not run through it, no wider than
/// its cell. It shrinks only if the words cannot fit the cell at their size.
struct PitchLabel: View {
    let text: String
    let font: Font
    var lines = 1

    var body: some View {
        Text(text)
            .font(font)
            .multilineTextAlignment(.center)
            .lineLimit(lines, reservesSpace: true)
            .minimumScaleFactor(Theme.Pitch.labelMinimumScale)
            .padding(.horizontal, Theme.Pitch.labelPadding)
            .background(Theme.Colour.board)
    }
}

/// A magnet's marks, centred on its top rim so they stay within its cell, whichever column it is in.
struct MarksOnRim: View {
    let marks: [TokenMark]

    var body: some View {
        if !marks.isEmpty {
            HStack(spacing: Theme.Spacing.xxs) {
                ForEach(marks, id: \.self) { TokenMarkView(mark: $0) }
            }
            .fixedSize()
            .alignmentGuide(.top) { $0[VerticalAlignment.center] }
        }
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
        case .injured:
            Image(systemName: "cross.circle.fill")
                .font(Theme.Typeface.text(Theme.Pitch.markSize, weight: .bold))
                .foregroundStyle(Theme.Colour.markerRed)
                .padding(Theme.Spacing.xxs)
                .background(Circle().fill(Theme.Colour.board))
                .accessibilityLabel("Injured")
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

/// A slot of the tactic nobody could be picked for: a dashed circle with its code, in a token's place and height so it
/// lines up with the magnets in its row.
struct UnfilledSlotToken: View {
    let slot: SlotID

    var body: some View {
        VStack(spacing: Theme.Spacing.xxs) {
            EmptyMagnet(letters: slot.displayName)
                .padding(.top, Theme.Magnet.ringWidth)
            PitchLabel(text: " ", font: Theme.Typeface.display(Theme.Pitch.nameSize, weight: .bold)).hidden()
            PitchLabel(text: " ", font: Theme.Typeface.text(Theme.Pitch.valueSize, weight: .bold)).hidden()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .help("Nobody could be picked for this slot")
    }
}
