import LineupAppCore
import SwiftUI

/// Who to retrain for the thin slots, and how the retrainings under way are going: four parts down the screen,
/// scrolling down. While the advice is not ready, the retrainings under way and those turned down still show under
/// what is missing, as they come from the owner's saved choices.
public struct TrainingScreen: View {
    let model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Theme.Training.partGap) {
                AdviceGate(screen: .training, state: model.adviceState, importLine: model.adviceImportLine) { _ in
                    Text(TrainingPresentation.explanation)
                        .font(Theme.Typeface.text(Theme.TypeSize.body))
                        .foregroundStyle(Theme.Colour.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(model.trainingParts) { part in
                    TrainingPartView(part: part, model: model)
                        .frame(maxWidth: Theme.Training.columnMaximumWidth, alignment: .leading)
                }
            }
            .padding(.bottom, Theme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// One part: its heading, then its rows, or the muted line saying it has none.
private struct TrainingPartView: View {
    let part: TrainingPart
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            BoardHeading(part.heading, size: Theme.TypeSize.boardTitle)
            if let empty = part.emptyText {
                Text(empty)
                    .font(Theme.Typeface.text(Theme.TypeSize.body))
                    .foregroundStyle(Theme.Colour.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            switch part {
            case .recommended(let cards, _):
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    ForEach(cards) { card in
                        RetrainingCard(card: card, accept: { model.accept(card.choice) },
                                       notHim: { model.reject(card.choice) })
                    }
                }
            case .underWay(let rows):
                RuledRows(rows) { row in
                    UnderWayRow(row: row) { model.stopRetraining(row.choice) }
                }
            case .recruit(let needs, let alreadyRetraining, _):
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    ForEach(Array(needs.enumerated()), id: \.offset) { need in
                        ReasonLine(reason: MarkedReason(text: need.element, direction: .unchanged))
                            .foregroundStyle(Theme.Colour.ink)
                    }
                    if let alreadyRetraining {
                        Text(alreadyRetraining)
                            .font(Theme.Typeface.text(Theme.TypeSize.body))
                            .foregroundStyle(Theme.Colour.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, Theme.Spacing.xs)
                    }
                }
            case .turnedDown(let rows):
                RuledRows(rows) { row in
                    TurnedDownRowView(row: row) { model.allowAgain(row.choice) }
                }
            }
        }
    }
}

/// Rows, each with a faint rule under it; nothing at all for no rows.
private struct RuledRows<Row: Identifiable, Content: View>: View {
    let rows: [Row]
    @ViewBuilder let content: (Row) -> Content

    init(_ rows: [Row], @ViewBuilder content: @escaping (Row) -> Content) {
        self.rows = rows
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                content(row)
                FaintRule()
            }
        }
    }
}

/// A player's name in the column the rows under way and turned down share.
private struct RowName: View {
    let name: String

    var body: some View {
        Text(name)
            .font(Theme.Typeface.display(Theme.TypeSize.heading, weight: .bold))
            .foregroundStyle(Theme.Colour.ink)
            .lineLimit(Theme.Training.nameLines)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// One retraining under way: his name, what he is learning and since when; the track and the engine's progress
/// sentence, or that he is no longer in the squad; and Stop, at the end of the row or under the rest when narrow.
private struct UnderWayRow: View {
    let row: RetrainingRow
    let stop: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                identity
                    .frame(width: Theme.Training.nameWidth, alignment: .leading)
                progress
                Spacer(minLength: 0)
                stopButton
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                identity
                progress
                stopButton
            }
        }
        .padding(.vertical, Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            RowName(name: row.name)
            Text(row.positionText)
                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                .foregroundStyle(Theme.Colour.markerBlue)
            Text(row.acceptedText)
                .font(Theme.Typeface.text(Theme.TypeSize.small))
                .foregroundStyle(Theme.Colour.mutedInk)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.spokenText)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if let stamp = row.departedStamp {
                // The row's spoken text already says it.
                StampView(stamp: stamp)
                    .padding(.top, Theme.Spacing.xs)
                    .accessibilityHidden(true)
            }
            if let track = row.track {
                RetrainingTrackView(track: track)
            }
            if let progress = row.progressText {
                Text(progress)
                    .font(Theme.Typeface.text(Theme.TypeSize.body))
                    .foregroundStyle(Theme.Colour.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
            if let leaving = row.leavingText {
                // The row's spoken text already says it.
                CautionLine(leaving)
                    .accessibilityHidden(true)
            }
        }
    }

    private var stopButton: some View {
        Button(TrainingPresentation.stopTitle, action: stop)
            .buttonStyle(.secondary)
            .fixedSize()
    }
}

/// One pair turned down: his name, what he was offered, that he has left when he has, and Offer again.
private struct TurnedDownRowView: View {
    let row: TurnedDownRow
    let offerAgain: () -> Void

    var body: some View {
        WrappingRow(alignment: .center, spacing: Theme.Spacing.xl) {
            HStack(alignment: .center, spacing: Theme.Spacing.xl) {
                RowName(name: row.name)
                    .frame(width: Theme.Training.nameWidth, alignment: .leading)
                Text(row.positionText)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                    .foregroundStyle(Theme.Colour.ink)
                    .fixedSize()
                if let stamp = row.departedStamp {
                    StampView(stamp: stamp)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(row.spokenText)
        } trailing: {
            Button(TrainingPresentation.offerAgainTitle, action: offerAgain)
                .buttonStyle(.secondary)
                .fixedSize()
        }
        .padding(.vertical, Theme.Spacing.s)
    }
}
