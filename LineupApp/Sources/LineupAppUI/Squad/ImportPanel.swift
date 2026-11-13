import LineupAppCore
import LineupEngine
import SwiftUI

/// The three import buttons with the day each squad was last imported, and what the last import did.
struct ImportPanel: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text("In FMRTE, select the squad's rows and copy them, then press the button for that squad.")
                .font(Theme.Typeface.text())
                .foregroundStyle(.secondary)
            HStack(alignment: .top, spacing: Theme.Spacing.xl) {
                ForEach(Squad.allCases, id: \.self) { squad in
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Button(squad.importButtonTitle) { model.importSquad(squad) }
                        Text(model.importedText(for: squad))
                            .font(Theme.Typeface.text())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            outcome
        }
    }

    @ViewBuilder private var outcome: some View {
        switch model.lastImport {
        case nil:
            EmptyView()
        case .imported(let summary):
            ImportReportView(report: model.report(of: summary))
        case .failed(let reason):
            Text(reason)
                .font(Theme.Typeface.text())
                .foregroundStyle(Theme.Colour.claret)
                .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
        }
    }
}

/// An import that worked: what was recognised and what changed, then the engine's warnings as written.
struct ImportReportView: View {
    let report: ImportReport

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(report.heading)
                .font(Theme.Typeface.text(weight: .semibold))
            Text(report.lines.joined(separator: " "))
                .font(Theme.Typeface.text())
            ForEach(report.warnings, id: \.self) { warning in
                MarkedText(warning, colour: Theme.Colour.amber)
            }
        }
        .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
    }
}
