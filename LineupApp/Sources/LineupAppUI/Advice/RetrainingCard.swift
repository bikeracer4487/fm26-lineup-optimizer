import LineupAppCore
import SwiftUI

/// One recommended retraining on a card: his name and age, what to learn, what it covers, his familiarity now, how
/// long it takes, his reasons with a green plus, his cautions, the evidence note, and the buttons to accept it or turn
/// it down beside the words, or under them when the card is narrow.
struct RetrainingCard: View {
    let card: RecommendationCard
    let accept: () -> Void
    let notHim: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                details
                Spacer(minLength: 0)
                buttons
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                details
                buttons
            }
        }
        .padding(Theme.Card.padding + Theme.Spacing.xxs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .boardCard()
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                Text(card.name)
                    .font(Theme.Typeface.display(Theme.TypeSize.heading, weight: .bold))
                    .lineLimit(Theme.Training.nameLines)
                    .fixedSize(horizontal: false, vertical: true)
                Text(card.ageText)
                    .font(Theme.Typeface.text(Theme.TypeSize.body))
                    .foregroundStyle(Theme.Colour.mutedInk)
                    .fixedSize()
            }
            Text(card.headline)
                .font(Theme.Typeface.text(Theme.TypeSize.noteHeading, weight: .extraBold))
                .foregroundStyle(Theme.Colour.markerBlue)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                if let covers = card.coversText {
                    Text(covers)
                        .font(Theme.Typeface.text())
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
                    Text(TrainingPresentation.familiarityLabel)
                        .font(Theme.Typeface.text(Theme.TypeSize.body))
                        .foregroundStyle(Theme.Colour.mutedInk)
                    Text(card.familiarityText)
                        .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                }
                Text(card.timeText)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // Keyed by place, so two identical sentences are both shown.
                ForEach(Array(card.reasons.enumerated()), id: \.offset) { ReasonLine(reason: $0.element) }
                ForEach(Array(card.cautions.enumerated()), id: \.offset) {
                    CautionLine($0.element, alignsWithReasons: true)
                }
            }
            .padding(.top, Theme.Spacing.xs)
            if let note = card.noteText {
                Text(note)
                    .font(Theme.Typeface.text(Theme.TypeSize.small))
                    .foregroundStyle(Theme.Colour.mutedInk)
            }
        }
        .foregroundStyle(Theme.Colour.ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.spokenText)
    }

    private var buttons: some View {
        HStack(spacing: Theme.Spacing.s) {
            Button(TrainingPresentation.acceptTitle, action: accept)
                .buttonStyle(.main)
            Button(TrainingPresentation.notHimTitle, action: notHim)
                .buttonStyle(.secondary)
        }
        .fixedSize()
    }
}

/// Where a retraining stands from 1 to 20: a bar, a hollow ring where he started, a blue dot where he is now, the solid
/// line across it, and a key under it naming each mark with its figure.
struct RetrainingTrackView: View {
    let track: RetrainingTrack

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(alignment: .center, spacing: Theme.Spacing.s) {
                Text(track.lowestText)
                    .font(Theme.Typeface.text(Theme.TypeSize.small))
                    .foregroundStyle(Theme.Colour.mutedInk)
                bar
                Text(track.highestText)
                    .font(Theme.Typeface.text(Theme.TypeSize.small))
                    .foregroundStyle(Theme.Colour.mutedInk)
            }
            FlowLayout(spacing: Theme.Spacing.l, lineSpacing: Theme.Spacing.xs) {
                if let started = track.startText {
                    key(started) { ring(Theme.Training.keyMark) }
                }
                if let now = track.latestText {
                    key(now) { dot(Theme.Training.keyMark) }
                }
                key(track.solidText) { solidLine(Theme.Training.keySolidHeight) }
            }
        }
        .accessibilityHidden(true)
    }

    /// The bar with the progress since the start in green and the three marks, each centred on its figure.
    private var bar: some View {
        let width = Theme.Training.trackWidth
        let mark = Theme.Training.trackMark
        let inner = mark - Theme.Training.trackMarkLine * 2
        func x(_ fraction: Double) -> CGFloat { CGFloat(fraction) * width }
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Theme.Colour.unlitBlock)
                .frame(width: width, height: Theme.Training.trackHeight)
            if let gained = track.gained {
                Capsule()
                    .fill(Theme.Colour.markerGreen)
                    .frame(width: x(gained.upperBound) - x(gained.lowerBound), height: Theme.Training.trackHeight)
                    .offset(x: x(gained.lowerBound))
            }
            solidLine(Theme.Training.solidLineHeight)
                .offset(x: x(track.solidFraction) - Theme.Training.solidLineWidth / 2)
            if let start = track.startFraction {
                ring(mark).offset(x: x(start) - mark / 2)
            }
            // The dot sits inside the ring when he has not moved.
            if let latest = track.latestFraction {
                dot(inner).offset(x: x(latest) - inner / 2)
            }
        }
        .frame(width: width, height: Theme.Training.solidLineHeight, alignment: .leading)
        .padding(.horizontal, mark / 2)
    }

    private func key(_ text: String, @ViewBuilder mark: () -> some View) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            mark()
            Text(text)
                .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .semibold))
                .foregroundStyle(Theme.Colour.ink)
                .fixedSize()
        }
    }

    private func ring(_ diameter: CGFloat) -> some View {
        Circle()
            .strokeBorder(Theme.Colour.ink, lineWidth: Theme.Training.trackMarkLine)
            .background(Circle().fill(Theme.Colour.board))
            .frame(width: diameter, height: diameter)
    }

    private func dot(_ diameter: CGFloat) -> some View {
        Circle()
            .fill(Theme.Colour.markerBlue)
            .frame(width: diameter, height: diameter)
    }

    private func solidLine(_ height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: Theme.Training.solidLineWidth / 2)
            .fill(Theme.Colour.ink)
            .frame(width: Theme.Training.solidLineWidth, height: height)
    }
}
