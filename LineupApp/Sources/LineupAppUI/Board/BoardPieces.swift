import LineupAppCore
import SwiftUI

/// A magnet: a coloured circle with a short hard shadow below, and letters on it when given.
struct Magnet: View {
    let fill: Color
    var text: Color = Theme.Colour.onMarker
    var letters: String = ""
    var diameter: CGFloat = Theme.Magnet.diameter
    var font: Font = Theme.Typeface.display(Theme.Pitch.initialsSize)
    var shadowOffset: CGFloat = Theme.Magnet.shadowOffset
    var shadowOpacity: Double = Theme.Magnet.shadowOpacity

    var body: some View {
        Circle()
            .fill(fill)
            .shadow(color: Theme.Colour.ink.opacity(shadowOpacity), radius: 0, x: 0, y: shadowOffset)
            .frame(width: diameter, height: diameter)
            .overlay {
                if !letters.isEmpty {
                    Text(letters)
                        .font(font)
                        .foregroundStyle(text)
                        .lineLimit(1)
                        .minimumScaleFactor(Theme.Pitch.labelMinimumScale)
                        .padding(.horizontal, Theme.Spacing.xxs)
                }
            }
    }

    /// A player's magnet on a pitch, in his line's colour.
    static func player(_ line: PitchLine, letters: String) -> Magnet {
        let colours = Theme.Colour.magnet(line)
        return Magnet(fill: colours.fill, text: colours.text, letters: letters)
    }

    /// The small magnet before a position in a table.
    static func table(_ line: PitchLine) -> Magnet {
        Magnet(fill: Theme.Colour.magnet(line).fill, diameter: Theme.Magnet.tableDiameter,
               shadowOffset: Theme.Magnet.tableShadowOffset, shadowOpacity: Theme.Magnet.tableShadowOpacity)
    }

    /// A magnet holding a note or a card to the board.
    static func pin(_ fill: Color, diameter: CGFloat = Theme.Magnet.noteDiameter) -> Magnet {
        Magnet(fill: fill, diameter: diameter, shadowOffset: Theme.Magnet.pinShadowOffset,
               shadowOpacity: Theme.Magnet.pinShadowOpacity)
    }
}

/// An empty place for a magnet: a dashed circle, with letters in muted ink when given.
struct EmptyMagnet: View {
    var letters: String = ""
    var diameter: CGFloat = Theme.Magnet.diameter

    var body: some View {
        Circle()
            .strokeBorder(Theme.Colour.mutedInk,
                          style: StrokeStyle(lineWidth: Theme.Magnet.emptyLineWidth, dash: Theme.Magnet.emptyDash))
            .background(Circle().fill(Theme.Colour.board))
            .frame(width: diameter, height: diameter)
            .overlay {
                Text(letters)
                    .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .bold))
                    .foregroundStyle(Theme.Colour.mutedInk)
                    .lineLimit(1)
                    .minimumScaleFactor(Theme.Pitch.emptySlotMinimumScale)
                    .padding(.horizontal, Theme.Spacing.xs)
            }
    }
}

/// A sticky note: flat paper in a note's colour with a short hard shadow, leaning by `tilt` degrees, its writing in the
/// note's ink.
struct StickyNoteModifier: ViewModifier {
    let paper: Theme.NotePaper
    let tilt: Double

    func body(content: Content) -> some View {
        content
            .foregroundStyle(paper.text)
            .tint(paper.text)
            .background {
                Rectangle()
                    .fill(paper.paper)
                    .shadow(color: Theme.Colour.ink.opacity(Theme.Sticky.shadowOpacity), radius: 0, x: 0,
                            y: Theme.Sticky.shadowOffset)
            }
            .rotationEffect(.degrees(tilt))
    }
}

extension View {
    func stickyNote(_ paper: Theme.NotePaper, tilt: Double) -> some View {
        modifier(StickyNoteModifier(paper: paper, tilt: tilt))
    }

    /// A card on the board: an ink outline, no fill, no shadow.
    func boardCard(cornerRadius: CGFloat = Theme.Card.cornerRadius) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(Theme.Colour.ink, lineWidth: Theme.Card.lineWidth)
        }
    }
}

/// A notice, a warning or an import's summary written on a pink note.
struct WarningNote<Content: View>: View {
    var tilt: Double = 0
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            content()
        }
        .font(Theme.Typeface.text())
        .padding(.horizontal, Theme.Sticky.horizontalPadding + Theme.Spacing.xxs)
        .padding(.vertical, Theme.Sticky.verticalPadding + Theme.Spacing.xxs)
        .stickyNote(Theme.Note.warning, tilt: tilt)
    }
}

/// Condition or sharpness: five blocks lit in the level's colour, the percentage beside them.
struct MeterView: View {
    let meter: Meter
    let text: String

    var body: some View {
        HStack(spacing: Theme.Spacing.s) {
            HStack(spacing: Theme.Meter.blockGap) {
                ForEach(0..<Meter.blocks, id: \.self) { block in
                    RoundedRectangle(cornerRadius: Theme.Meter.blockCornerRadius)
                        .fill(meter.isLit(block) ? Theme.Colour.meter(meter.level) : Theme.Colour.unlitBlock)
                        .frame(width: Theme.Meter.blockWidth, height: Theme.Meter.blockHeight)
                }
            }
            .accessibilityHidden(true)
            Text(text)
                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
        }
    }
}

/// A status stamped beside a player: an outlined pill in its tone's colour, leaning.
struct StampView: View {
    let stamp: StatusStamp

    var body: some View {
        let colour = Theme.Colour.stamp(stamp.tone)
        Text(stamp.text)
            .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .extraBold))
            .foregroundStyle(colour)
            .lineLimit(1)
            .padding(.horizontal, Theme.Stamp.horizontalPadding)
            .padding(.vertical, Theme.Stamp.verticalPadding)
            .overlay { RoundedRectangle(cornerRadius: Theme.Stamp.cornerRadius, style: .circular).strokeBorder(colour, lineWidth: Theme.Stamp.lineWidth) }
            .rotationEffect(.degrees(Theme.Stamp.tilt))
            .help(stamp.text)
    }
}

/// A heading written on the board in the display face.
struct BoardHeading: View {
    let text: String
    var size: CGFloat = Theme.TypeSize.heading

    init(_ text: String, size: CGFloat = Theme.TypeSize.heading) {
        self.text = text
        self.size = size
    }

    var body: some View {
        Text(text)
            .font(Theme.Typeface.display(size))
            .foregroundStyle(Theme.Colour.ink)
            .accessibilityAddTraits(.isHeader)
    }
}

/// A heavy ink rule across the board.
struct HeavyRule: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Colour.ink)
            .frame(height: Theme.Rule.heavy)
            .accessibilityHidden(true)
    }
}

/// A faint rule between rows.
struct FaintRule: View {
    var body: some View {
        Rectangle()
            .fill(Theme.Colour.faintRule)
            .frame(height: Theme.Table.rowRule)
            .accessibilityHidden(true)
    }
}

/// A caution in marker amber: a triangle, then the sentence in ink.
struct CautionLine: View {
    let text: String
    /// Whether the triangle takes a reason's sign's room, so the sentence lines up with reasons above or below it.
    let alignsWithReasons: Bool

    init(_ text: String, alignsWithReasons: Bool = false) {
        self.text = text
        self.alignsWithReasons = alignsWithReasons
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: alignsWithReasons ? Theme.Spacing.m - Theme.Spacing.xxs : Theme.Spacing.s) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(Theme.Typeface.text(alignsWithReasons ? Theme.TypeSize.body : Theme.TypeSize.caption, weight: .bold))
                .foregroundStyle(Theme.Colour.markerAmber)
                .frame(width: alignsWithReasons ? Theme.Match.signDiameter : nil)
                .accessibilityLabel("Caution")
            Text(text)
                .font(Theme.Typeface.text())
                .foregroundStyle(Theme.Colour.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Views placed in rows, left to right, starting a new row when the next one does not fit the width given.
struct FlowLayout: Layout {
    var spacing: CGFloat = Theme.Pill.gap
    var lineSpacing: CGFloat = Theme.Pill.gap

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if !row.indices.isEmpty && needed > width {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
