import LineupAppCore
import LineupEngine
import SwiftUI

/// Where the club stands in the league: "Paste table" beside the heading, the three numbers that say what the places
/// are worth, what the last paste read or why it was refused, the engine's reading of the table, and the table with a
/// rule at each line that counts. With no table, the empty state says how to get one. All of its words are the engine's
/// or Core's; the screen lays them out.
public struct LeagueScreen: View {
    let model: AppModel
    @State private var removing = false

    public init(model: AppModel) {
        self.model = model
    }

    public var body: some View {
        let content = model.leagueScreen
        return ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                HStack(alignment: .center, spacing: Theme.Spacing.l) {
                    BoardHeading(Screen.league.title, size: Theme.TypeSize.title)
                    Button(AppModel.pasteTableTitle) { model.pasteLeagueTable() }
                        .buttonStyle(.primary)
                }
                format(content)
                if let line = content.pastedLine {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.l) {
                        Text(line)
                            .font(Theme.Typeface.text())
                            .foregroundStyle(Theme.Colour.mutedInk)
                        if content.offersRemove {
                            Button(AppModel.removeTableTitle) { removing = true }
                                .buttonStyle(.secondary)
                                .fixedSize()
                        }
                    }
                }
                cautions(content)
                if let line = content.handChoiceLine {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.l) {
                        Text(line)
                            .font(Theme.Typeface.text())
                            .foregroundStyle(Theme.Colour.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Button(AppModel.useTheTableTitle) { model.setLeagueSituation(nil) }
                            .buttonStyle(.secondary)
                            .fixedSize()
                    }
                    .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
                }
                reading(content)
                if !content.fixturesNotInTheTable.isEmpty {
                    notInTable(content.fixturesNotInTheTable)
                }
                if content.rows.isEmpty {
                    EmptyState(content.emptyLines.joined(separator: " "))
                } else {
                    LeagueTable(rows: content.rows)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.bottom, Theme.Spacing.l)
        }
        .alert("Remove the league table?", isPresented: $removing) {
            Button(AppModel.removeTableTitle, role: .destructive) { model.removeLeagueTable() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The three numbers stay.")
        }
    }

    /// The three numbers, each with its label, and the bye line under them.
    private func format(_ content: LeagueScreenContent) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.xl) {
                numberField(AppModel.promotedLabel, \.promoted)
                numberField(AppModel.playOffsLabel, \.playOffs)
                numberField(AppModel.relegatedLabel, \.relegated)
            }
            if let bye = content.byeLine {
                Text(bye)
                    .font(Theme.Typeface.text(Theme.TypeSize.small))
                    .foregroundStyle(Theme.Colour.mutedInk)
            }
            if let problem = content.formatProblem {
                CautionLine(problem)
            }
        }
    }

    private func numberField(_ label: String, _ field: WritableKeyPath<LeagueFormatDraft, Int?>) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.s) {
            Text(label)
                .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .semibold))
                .foregroundStyle(Theme.Colour.mutedInk)
                .fixedSize()
            TextField(label, value: Binding(
                get: { model.leagueFormatDraft[keyPath: field] },
                set: { picked in
                    var draft = model.leagueFormatDraft
                    draft[keyPath: field] = picked
                    model.setLeagueFormatDraft(draft)
                }), format: .number.grouping(.never), prompt: Text(""))
                .labelsHidden()
                .boardField()
                .multilineTextAlignment(.trailing)
                .frame(width: Theme.League.numberFieldWidth)
        }
    }

    /// The table's cautions and the paste's refusal, as the Training cards draw theirs.
    @ViewBuilder
    private func cautions(_ content: LeagueScreenContent) -> some View {
        if !content.cautions.isEmpty || content.pasteProblem != nil {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                ForEach(Array(content.cautions.enumerated()), id: \.offset) { _, text in
                    CautionLine(text)
                }
                if let problem = content.pasteProblem {
                    CautionLine(problem, isWarning: true)
                }
            }
            .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
        }
    }

    /// The reading's sentences, one to a line, and the evidence note.
    @ViewBuilder
    private func reading(_ content: LeagueScreenContent) -> some View {
        if !content.sentences.isEmpty || content.evidenceNote != nil {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                ForEach(Array(content.sentences.enumerated()), id: \.offset) { _, sentence in
                    Text(sentence)
                        .font(Theme.Typeface.text())
                        .foregroundStyle(Theme.Colour.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let note = content.evidenceNote {
                    Text(note)
                        .font(Theme.Typeface.text(Theme.TypeSize.small))
                        .foregroundStyle(Theme.Colour.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Theme.Spacing.xs)
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
        }
    }

    private func notInTable(_ fixtures: [String]) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(AppModel.notInTableHeading)
                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
            ForEach(fixtures, id: \.self) { fixture in
                Text(fixture)
                    .font(Theme.Typeface.text())
                    .foregroundStyle(Theme.Colour.mutedInk)
            }
        }
    }
}
