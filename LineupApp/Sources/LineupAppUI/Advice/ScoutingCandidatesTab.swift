import LineupAppCore
import LineupEngine
import SwiftUI

/// The Candidates tab: "Paste players" and "Clear", the Today and Later control, what the paste read and left out, and
/// why a paste was refused; then the candidates part by part, each group under its heading, the rest closed behind a
/// line saying how many are in it. With nothing pasted, the sentence saying how to paste.
struct ScoutingCandidatesTab: View {
    let model: AppModel
    @Bindable var navigation: Navigation

    var body: some View {
        switch model.candidates(for: navigation.scoutingTacticID) {
        case .notReady:
            // The gate shows why while the advice is not ready.
            EmptyView()
        case .failed(let problems):
            ScoutingFailed(problems: problems)
        case .nothingPasted:
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                pasteRow(ordered: false)
                refusal
                EmptyState(ScoutingPresentation.nothingPasted)
            }
        case .ready(let report):
            if let sheet = model.candidatesSheet(report, order: navigation.scoutingOrder) {
                VStack(alignment: .leading, spacing: Theme.Scouting.partGap) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                        pasteRow(ordered: true)
                        refusal
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            ScoutingMutedLine(text: sheet.readLine)
                            if let leftOut = sheet.leftOutLine {
                                ScoutingMutedLine(text: leftOut)
                            }
                        }
                    }
                    CandidateGroups(sheet: sheet, navigation: navigation)
                }
            }
        }
    }

    /// The two buttons, and the order once there are candidates to order.
    private func pasteRow(ordered: Bool) -> some View {
        WrappingRow(alignment: .center, spacing: Theme.Spacing.xl, pushesTrailing: false) {
            HStack(alignment: .center, spacing: Theme.Spacing.m) {
                Button(ScoutingPresentation.pasteButton) { model.pasteCandidates() }
                    .buttonStyle(.main)
                    .fixedSize()
                Button(ScoutingPresentation.clearButton) { model.clearCandidates() }
                    .buttonStyle(.secondary)
                    .fixedSize()
                    .disabled(!model.canClearCandidates)
            }
        } trailing: {
            if ordered {
                // Labelled as the tactic menu is, so it does not read as a second pair of tabs.
                HStack(alignment: .center, spacing: Theme.Spacing.m) {
                    Text(ScoutingPresentation.orderLabel)
                        .font(Theme.Typeface.text())
                        .foregroundStyle(Theme.Colour.ink)
                        .fixedSize()
                    BoardTabs(choices: ScoutingPresentation.orderChoices.map { ($0.order, $0.title) },
                              selection: $navigation.scoutingOrder)
                }
            }
        }
    }

    /// Why the last paste was refused, in the engine's sentence.
    @ViewBuilder private var refusal: some View {
        if let problem = model.scoutingPasteProblem {
            CautionLine(problem)
                .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
        }
    }
}

/// The groups in the engine's order: a part's title over its first group, each group's heading, then its candidates.
private struct CandidateGroups: View {
    let sheet: CandidatesSheet
    @Bindable var navigation: Navigation

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
            ForEach(sheet.groups) { group in
                VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                    if let title = group.partTitle {
                        BoardHeading(title, size: Theme.TypeSize.boardTitle)
                            .padding(.top, Theme.Spacing.s)
                    }
                    if let heading = group.heading {
                        BoardHeading(heading)
                    }
                    if group.isRest, let line = sheet.restLine {
                        RestToggle(line: line, isOpen: navigation.scoutingRestOpen) {
                            navigation.scoutingRestOpen.toggle()
                        }
                    }
                    if group.showsRows(restOpen: navigation.scoutingRestOpen) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(group.rows) { row in
                                FaintRule()
                                ScoutingCandidateRowView(row: row, inRest: group.isRest,
                                                 isOpen: navigation.scoutingOpen.contains(row.id)) {
                                    navigation.toggleScoutingRow(row.id)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

/// The line the rest part is closed behind: how many are in it, a click opening or closing it.
private struct RestToggle: View {
    let line: String
    let isOpen: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Disclosure(isOpen: isOpen)
                Text(line)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                    .foregroundStyle(Theme.Colour.ink)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(ScoutingPresentation.restHelp(isOpen))
        .accessibilityValue(RemovalPresentation.openText(isOpen))
    }
}

/// The mark before something that opens: pointing right while closed, down while open.
private struct Disclosure: View {
    let isOpen: Bool

    var body: some View {
        Image(systemName: isOpen ? "chevron.down" : "chevron.right")
            .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .bold))
            .foregroundStyle(Theme.Colour.mutedInk)
            .frame(width: Theme.Scouting.disclosureColumn, alignment: .leading)
            .accessibilityHidden(true)
    }
}

/// One candidate: his name with any stamp, what the paste says of him, then his lines and his cautions by label. A click
/// on his name opens the row to show his other slots, when he has more to show.
private struct ScoutingCandidateRowView: View {
    let row: ScoutingCandidateRow
    let inRest: Bool
    let isOpen: Bool
    let toggle: () -> Void

    var body: some View {
        let opens = row.opens(inRest: inRest)
        let lines = row.linesShown(inRest: inRest, isOpen: isOpen)
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            if opens {
                Button(action: toggle) {
                    identity(opens: true)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(ScoutingPresentation.rowHelp(isOpen))
                .accessibilityValue(RemovalPresentation.openText(isOpen))
                .accessibilityAddTraits(.isButton)
            } else {
                identity(opens: false)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                LabelledLines(label: ScoutingPresentation.todayLabel, lines: lines.today)
                LabelledLines(label: ScoutingPresentation.laterLabel, lines: lines.later)
                if !row.cautions.isEmpty {
                    Labelled(label: ScoutingPresentation.cautionsLabel) {
                        FlowLayout(spacing: Theme.Scouting.cautionGap, lineSpacing: Theme.Spacing.xs) {
                            ForEach(Array(row.cautions.enumerated()), id: \.offset) { _, caution in
                                CautionLine(caution)
                            }
                        }
                    }
                }
                LabelledLines(label: ScoutingPresentation.otherSlotsLabel, lines: lines.otherSlots)
            }
            .padding(.leading, Theme.Scouting.disclosureColumn)
            .textSelection(.enabled)
        }
        .padding(.vertical, Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The disclosure mark, or its room, then his name and stamps over what the paste says of him.
    private func identity(opens: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if opens {
                Disclosure(isOpen: isOpen)
            } else {
                // Its room kept, so every name lines up.
                Disclosure(isOpen: isOpen)
                    .hidden()
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                    Text(row.name)
                        .font(Theme.Typeface.display(Theme.TypeSize.noteHeading, weight: .bold))
                        .foregroundStyle(Theme.Colour.ink)
                        .lineLimit(Theme.Scouting.nameLines)
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(row.stamps, id: \.self) { StampView(stamp: $0).fixedSize() }
                }
                Text(row.detailsText)
                    .font(Theme.Typeface.text(Theme.TypeSize.small))
                    .foregroundStyle(Theme.Colour.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Lines under a label in the column before them; nothing at all for no lines.
private struct LabelledLines: View {
    let label: String
    let lines: [String]

    var body: some View {
        if !lines.isEmpty {
            Labelled(label: label) {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    // Keyed by place, so two identical lines are both shown.
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(Theme.Typeface.text())
                            .foregroundStyle(Theme.Colour.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

/// A label in the column the row's labels share, then what it labels beside it.
private struct Labelled<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(label)
                .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .bold))
                .foregroundStyle(Theme.Colour.mutedInk)
                .frame(width: Theme.Scouting.labelColumn, alignment: .leading)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
