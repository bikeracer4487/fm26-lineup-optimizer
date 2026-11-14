import LineupAppCore
import LineupEngine
import SwiftUI

/// The selected pick, written on the board: who he is and his roles, his match-day value in a hand-drawn ring, his
/// figures on the day as cards, every reason the engine gave in full with a plus or a minus for what it did to his
/// value, and the owner's controls for the slot.
struct PickDetailView: View {
    let model: AppModel
    let fixture: FixtureID
    let detail: PickDetail
    /// Selects the slot's pick after the owner changes it, as Core works it out.
    let select: (PickSelection?) -> Void
    @State private var choosing = false

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            HStack(alignment: .center, spacing: Theme.Spacing.l) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(detail.name)
                        .font(Theme.Typeface.display(Theme.TypeSize.title))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail.positionLine)
                        .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                        .foregroundStyle(Theme.Colour.mutedInk)
                    ForEach(detail.roles, id: \.self) { role in
                        Text(role)
                            .font(Theme.Typeface.text())
                            .foregroundStyle(Theme.Colour.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                ValueRing(text: detail.valueText, label: detail.valueLabel)
            }

            figures

            if !detail.cautions.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(detail.cautions, id: \.self) { CautionLine($0) }
                }
            }

            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                BoardHeading("Why he starts")
                ForEach(Array(detail.markedReasons.enumerated()), id: \.offset) { _, reason in
                    ReasonLine(reason: reason)
                }
            }

            actions
        }
    }

    /// Rating, and fitness on the day with its factors, each on a card: four across, or two by two when narrow.
    private var figures: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Theme.Match.figureGap) { cards(detail.cards) }
                .fixedSize(horizontal: false, vertical: true)
            Grid(horizontalSpacing: Theme.Match.figureGap, verticalSpacing: Theme.Match.figureGap) {
                GridRow { cards(Array(detail.cards.prefix(2))) }
                GridRow { cards(Array(detail.cards.dropFirst(2))) }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func cards(_ cards: [PickFigure]) -> some View {
        ForEach(cards) { card in
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(card.label)
                        .font(Theme.Typeface.text(Theme.TypeSize.small))
                        .foregroundStyle(Theme.Colour.mutedInk)
                        .lineLimit(Theme.Match.figureLabelLines)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xs) {
                        Text(card.figure ?? "")
                            .font(Theme.Typeface.display(Theme.TypeSize.heading))
                            .fixedSize()
                        Spacer(minLength: Theme.Spacing.xs)
                        if let factor = card.factor {
                            Text(factor)
                                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .extraBold))
                                .foregroundStyle(Theme.Colour.factor(card.direction))
                                .fixedSize()
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.m - Theme.Spacing.xxs)
                .padding(.vertical, Theme.Spacing.s)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .boardCard(cornerRadius: Theme.Card.smallCornerRadius)
                .accessibilityElement(children: .combine)
        }
    }

    private var actions: some View {
        FlowLayout(spacing: Theme.Spacing.s + Theme.Spacing.xxs, lineSpacing: Theme.Spacing.s) {
            Button("Choose someone else") { choosing = true }
                .buttonStyle(.primary)
                .popover(isPresented: $choosing, arrowEdge: .leading) {
                    CandidatePicker(text: PickerText.planned(detail.slot),
                                    rows: model.candidateRows(for: detail.slot, in: fixture)) { player in
                        select(model.choose(player, at: detail.slot, in: fixture))
                        choosing = false
                    } cancel: {
                        choosing = false
                    }
                }
            if detail.isOverride {
                Button("Clear this choice") { select(model.clearChoice(at: detail.slot, in: fixture)) }
                    .buttonStyle(.secondary)
            }
            Button("Leave him out of this match") { model.reject(detail.player, in: fixture) }
                .buttonStyle(.secondary)
        }
    }
}

/// A figure that is the point of a panel, in marker blue inside a hand-drawn ring.
struct ValueRing: View {
    let text: String
    /// What it says to assistive technology.
    let label: String

    var body: some View {
        Text(text)
            .font(Theme.Typeface.display(Theme.TypeSize.boardTitle))
            .foregroundStyle(Theme.Colour.markerBlue)
            .fixedSize()
            .padding(.horizontal, Theme.Match.ringPadding.width)
            .padding(.vertical, Theme.Match.ringPadding.height)
            .background {
                Ellipse()
                    .strokeBorder(Theme.Colour.markerBlue, lineWidth: Theme.Match.ringLineWidth)
                    .rotationEffect(.degrees(Theme.Match.ringTilt))
            }
            .accessibilityLabel(label)
    }
}

/// One reason as the engine wrote it, after a green plus if it raised his value, a red minus if it lowered it, or a
/// small ink dot if it did neither.
struct ReasonLine: View {
    let reason: MarkedReason

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m - Theme.Spacing.xxs) {
            sign
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + Theme.TypeSize.body / 3 }
            Text(reason.text)
                .font(Theme.Typeface.text())
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder private var sign: some View {
        let diameter = Theme.Match.signDiameter
        switch reason.direction {
        case .raised:
            Text("+")
                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .extraBold))
                .foregroundStyle(Theme.Colour.onMarker)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(Theme.Colour.greenText))
                .accessibilityLabel("Raised his value")
        case .lowered:
            Text("−")
                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .extraBold))
                .foregroundStyle(Theme.Colour.onMarker)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(Theme.Colour.redText))
                .accessibilityLabel("Lowered his value")
        case .unchanged:
            Circle()
                .fill(Theme.Colour.ink)
                .frame(width: Theme.Match.neutralDotDiameter, height: Theme.Match.neutralDotDiameter)
                .frame(width: diameter, height: diameter)
                .accessibilityHidden(true)
        }
    }
}
