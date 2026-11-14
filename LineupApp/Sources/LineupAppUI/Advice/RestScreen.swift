import LineupAppCore
import LineupEngine
import SwiftUI

/// Who needs a holiday, a rest or watching: a line saying what the screen is for, then a block for each player the
/// engine lists, most urgent first, separated by faint rules, scrolling down.
public struct RestScreen: View {
    let model: AppModel

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        AdviceGate(screen: .rest, state: model.adviceState, importLine: model.adviceImportLine) { report in
            RestList(rows: model.restRows(report))
        }
    }
}

private struct RestList: View {
    let rows: [RestRow]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text(RestPresentation.explanation)
                .font(Theme.Typeface.text(Theme.TypeSize.body))
                .foregroundStyle(Theme.Colour.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            if let empty = RestPresentation.emptyText(rows) {
                EmptyState(empty)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        FaintRule()
                        ForEach(rows) { row in
                            RestBlock(row: row)
                            FaintRule()
                        }
                    }
                }
            }
        }
    }
}

/// One player: his stamp, name and squad, then his figures beside them, or under his name when the row is narrow;
/// his reasons underneath, in line with his name. The figures keep the same columns in every block.
private struct RestBlock: View {
    let row: RestRow

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                    identity
                    figures
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    identity
                    figures
                        .padding(.leading, nameIndent)
                }
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // Keyed by place, so two identical reasons are both shown.
                ForEach(Array(row.reasons.enumerated()), id: \.offset) { ReasonLine(reason: $0.element) }
                if let plan = row.planText {
                    CautionLine(plan, alignsWithReasons: true)
                }
            }
            .foregroundStyle(Theme.Colour.ink)
            .padding(.leading, nameIndent)
        }
        .padding(.vertical, Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.spokenText)
    }

    /// Where the name starts: past the stamp's room.
    private var nameIndent: CGFloat { Theme.Rest.stampWidth + Theme.Spacing.m }

    /// The stamp, then his name, his squad and the evidence note.
    private var identity: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
            StampView(stamp: row.stamp)
                .frame(width: Theme.Rest.stampWidth, alignment: .leading)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(row.name)
                    .font(Theme.Typeface.display(Theme.TypeSize.heading, weight: .bold))
                    .foregroundStyle(Theme.Colour.ink)
                    .lineLimit(Theme.Rest.nameLines)
                    .fixedSize(horizontal: false, vertical: true)
                if let squad = row.squadText {
                    Text(squad)
                        .font(Theme.Typeface.text(Theme.TypeSize.small))
                        .foregroundStyle(Theme.Colour.mutedInk)
                }
                if let note = row.noteText {
                    Text(note)
                        .font(Theme.Typeface.text(Theme.TypeSize.small))
                        .foregroundStyle(Theme.Colour.mutedInk)
                }
            }
            .frame(width: Theme.Rest.nameWidth, alignment: .leading)
        }
    }

    /// The figures in their columns, the sentence saying when he is clear after them, or under them when they would
    /// not fit across.
    private var figures: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                columns
                clear
                    .padding(.top, Theme.Rest.clearTopPadding)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                columns
                clear
            }
        }
        .foregroundStyle(Theme.Colour.ink)
    }

    private var columns: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.xl) {
            RestFigure(label: RestPresentation.jadednessLabel) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                    Text(row.jadednessText)
                        .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                    if let notes = row.limitNotesText {
                        Text(notes)
                            .font(Theme.Typeface.text(Theme.TypeSize.small))
                            .foregroundStyle(Theme.Colour.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .frame(width: Theme.Rest.jadednessColumn, alignment: .leading)
            RestFigure(label: RestPresentation.conditionLabel) {
                MeterView(meter: row.conditionMeter, text: row.conditionText)
            }
            .frame(width: Theme.Rest.conditionColumn, alignment: .leading)
            RestFigure(label: RestPresentation.startsLabel) {
                Text(row.startsText)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
            }
            .frame(width: Theme.Rest.startsColumn, alignment: .leading)
        }
    }

    @ViewBuilder private var clear: some View {
        if let clear = row.clearText {
            Text(clear)
                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .semibold))
                .fixedSize()
        }
    }
}

/// A figure under its small muted label.
private struct RestFigure<Figure: View>: View {
    let label: String
    @ViewBuilder let figure: () -> Figure

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(label)
                .font(Theme.Typeface.text(Theme.TypeSize.small))
                .foregroundStyle(Theme.Colour.mutedInk)
            figure()
        }
    }
}
