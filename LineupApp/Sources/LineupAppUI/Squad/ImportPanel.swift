import LineupAppCore
import LineupEngine
import SwiftUI

/// The three imports as cards on the board, each with its magnet, when it was last imported and its button; what the
/// last import did on a pink note beside them, which can be dismissed; and how to import, under them.
struct ImportPanel: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: Theme.Spacing.m + Theme.Spacing.xxs) {
                    cardRow
                    if model.lastImport != nil {
                        outcome
                            .frame(width: Theme.Sticky.summaryWidth, alignment: .leading)
                    }
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                    cardRow
                    if model.lastImport != nil {
                        outcome
                            .frame(maxWidth: Theme.Sticky.noticeMaximumWidth, alignment: .leading)
                    }
                }
            }
            .padding(.top, Theme.Magnet.cardDiameter / 2)
            Text("In FMRTE, select the squad's rows and copy them, then press Import on that squad's card. "
                 + ImportReport.datingLine)
                .font(Theme.Typeface.text(Theme.TypeSize.caption))
                .foregroundStyle(Theme.Colour.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The cards side by side, as tall as the tallest of them.
    private var cardRow: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.m + Theme.Spacing.xxs) { cards }
            .fixedSize(horizontal: false, vertical: true)
    }

    private var cards: some View {
        ForEach(Squad.allCases, id: \.self) { squad in
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                BoardHeading(squad.displayName)
                Text(model.importedText(for: squad))
                    .font(Theme.Typeface.text(Theme.TypeSize.caption))
                    .foregroundStyle(Theme.Colour.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("Import") { model.importSquad(squad) }
                    .buttonStyle(.primary)
                    .accessibilityLabel(squad.importButtonTitle)
            }
            .padding(Theme.Card.padding)
            // A small ideal width, so the cards stay beside the import's note on a narrow board, their words wrapping.
            .frame(minWidth: Theme.Card.importMinimumWidth, idealWidth: Theme.Card.importMinimumWidth,
                   maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .boardCard()
            .overlay(alignment: .topLeading) {
                Magnet.pin(Theme.Colour.squad(squad), diameter: Theme.Magnet.cardDiameter)
                    .offset(x: Theme.Card.padding + Theme.Spacing.xxs, y: -Theme.Magnet.cardDiameter / 2)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder private var outcome: some View {
        switch model.lastImport {
        case nil:
            EmptyView()
        case .imported(let summary):
            let report = model.report(of: summary)
            WarningNote(tilt: Theme.Sticky.warningTilt) {
                Text(report.heading)
                    .font(Theme.Typeface.display(Theme.TypeSize.noteHeading))
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(report.lines, id: \.self) { line in
                    Text(line)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach(report.warnings, id: \.self) { warning in
                    Text(warning)
                        .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button("Dismiss") { model.dismissImport() }
                    .buttonStyle(.onNote)
            }
        case .failed(let squad, let reason):
            WarningNote(tilt: Theme.Sticky.warningTilt) {
                Text(ImportReport.notImportedLine(squad))
                    .font(Theme.Typeface.display(Theme.TypeSize.noteHeading))
                    .fixedSize(horizontal: false, vertical: true)
                Text(reason)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Dismiss") { model.dismissImport() }
                    .buttonStyle(.onNote)
            }
        }
    }
}
