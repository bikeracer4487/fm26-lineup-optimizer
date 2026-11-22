import LineupAppCore
import LineupEngine
import SwiftUI

/// Who needs a holiday, a rest or watching: a line saying what the screen is for, then what the readings show of each
/// squad and the club with the day the trend is measured from, then a block for each player the engine lists, most
/// urgent first, separated by faint rules, and what the game's tiredness messages mean at the foot, scrolling down.
public struct RestScreen: View {
    let model: AppModel
    @State private var measuringAgain = false

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        AdviceGate(screen: .rest, state: model.adviceState, importLine: model.adviceImportLine) { report in
            RestList(rows: model.restRows(report), header: model.restTrendHeader(report),
                     gameMessages: model.restGameMessages) { measuringAgain = true }
        }
        .alert(model.restMeasureAgainQuestion, isPresented: $measuringAgain) {
            Button(RestPresentation.measureAgainConfirm) { model.measureTrendAgain() }
            Button(RestPresentation.cancelTitle, role: .cancel) {}
        }
    }
}

private struct RestList: View {
    let rows: [RestRow]
    let header: RestTrendHeader
    let gameMessages: [String]
    let measureAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text(RestPresentation.explanation)
                .font(Theme.Typeface.text(Theme.TypeSize.body))
                .foregroundStyle(Theme.Colour.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    RestTrendLines(header: header, measureAgain: measureAgain)
                        .padding(.bottom, Theme.Spacing.l)
                    if let empty = RestPresentation.emptyText(rows) {
                        EmptyState(empty)
                    } else {
                        FaintRule()
                        ForEach(rows) { row in
                            RestBlock(row: row)
                            FaintRule()
                        }
                    }
                    GameMessages(lines: gameMessages)
                        .padding(.top, Theme.Rest.footGap)
                }
            }
        }
    }
}

/// Each measured squad's line with its caution under it, the club's line, then the day the trend is measured from in
/// muted ink with "Measure again from today" beside it. Nothing when nothing is measured and no reading is kept.
private struct RestTrendLines: View {
    let header: RestTrendHeader
    let measureAgain: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            ForEach(header.squadLines) { line in
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(line.text)
                        .font(Theme.Typeface.text())
                        .foregroundStyle(Theme.Colour.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let caution = line.caution {
                        CautionLine(caution)
                    }
                }
            }
            if let club = header.clubLine {
                Text(club)
                    .font(Theme.Typeface.text())
                    .foregroundStyle(Theme.Colour.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if header.showsMeasuredLine {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.l) {
                    if let measured = header.measuredFromText {
                        Text(measured)
                            .font(Theme.Typeface.text())
                            .foregroundStyle(Theme.Colour.mutedInk)
                    }
                    if header.offersMeasureAgain {
                        Button(RestPresentation.measureAgainTitle, action: measureAgain)
                            .buttonStyle(.secondary)
                            .fixedSize()
                    }
                }
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .frame(maxWidth: Theme.Rest.trendLinesWidth, alignment: .leading)
    }
}

/// What the game's tiredness messages mean: the engine's heading and lines, small and muted.
private struct GameMessages: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(RestPresentation.gameMessagesHeading)
                .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .bold))
            // Keyed by place, so two identical lines are both shown.
            ForEach(Array(lines.enumerated()), id: \.offset) { line in
                Text(line.element)
                    .font(Theme.Typeface.text(Theme.TypeSize.small))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(Theme.Colour.mutedInk)
        .frame(maxWidth: Theme.Rest.trendLinesWidth, alignment: .leading)
        .padding(.bottom, Theme.Spacing.l)
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
                trend
            }
            .foregroundStyle(Theme.Colour.ink)
            .padding(.leading, nameIndent)
        }
        .padding(.vertical, Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.spokenText)
    }

    /// His trend lines, in line with the reasons' sentences, in muted ink, with the trend's evidence note after them.
    @ViewBuilder private var trend: some View {
        if !row.trendLines.isEmpty {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                ForEach(Array(row.trendLines.enumerated()), id: \.offset) { line in
                    Text(line.element)
                        .font(Theme.Typeface.text())
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let note = row.trendNoteText {
                    Text(note)
                        .font(Theme.Typeface.text(Theme.TypeSize.small))
                }
            }
            .foregroundStyle(Theme.Colour.mutedInk)
            .frame(maxWidth: Theme.Rest.trendLinesWidth, alignment: .leading)
            .padding(.leading, Theme.Rest.trendIndent)
            .padding(.top, Theme.Spacing.xs)
        }
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
