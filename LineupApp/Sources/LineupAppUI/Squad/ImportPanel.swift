import LineupAppCore
import LineupEngine
import SwiftUI

/// The three import buttons with the day each squad was last imported, and what the last import did, which can be
/// dismissed.
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
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                ImportReportView(report: model.report(of: summary))
                Button("Dismiss") { model.dismissImport() }
            }
        case .failed(let squad, let reason):
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(ImportReport.notImportedLine(squad))
                        .font(Theme.Typeface.text(weight: .semibold))
                    Text(reason)
                        .font(Theme.Typeface.text())
                }
                .foregroundStyle(Theme.Colour.claret)
                .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
                Button("Dismiss") { model.dismissImport() }
            }
        }
    }
}

/// An import that worked, a line each: the grid, the count, who is out on loan, what changed, then the engine's
/// warnings as written.
struct ImportReportView: View {
    let report: ImportReport

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(report.heading)
                .font(Theme.Typeface.text(weight: .semibold))
            ForEach(report.lines, id: \.self) { line in
                Text(line)
                    .font(Theme.Typeface.text())
            }
            ForEach(report.warnings, id: \.self) { warning in
                MarkedText(warning, colour: Theme.Colour.amber)
            }
        }
        .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
    }
}
