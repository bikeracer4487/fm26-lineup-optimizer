import LineupAppCore
import LineupEngine
import SwiftUI

/// The Candidates tab: "Paste players" and "Clear", the Today and Later control, what the paste read and left out, and
/// why a paste was refused; then the candidates part by part, each group under its heading with its best few rows and
/// a line that opens the others, the rest closed behind a line saying how many are in it; then the players the owner
/// has hidden, closed behind a line of their own, and how far to trust it all. Every candidate's row has "Hide", and
/// every hidden player "Show again". With nothing pasted, the sentence saying how to paste.
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
                    CandidateGroups(sheet: sheet, model: model, navigation: navigation)
                    HiddenCandidates(sheet: sheet, model: model, navigation: navigation)
                    if let note = sheet.evidenceNote {
                        ScoutingMutedLine(text: note, size: Theme.TypeSize.small)
                    }
                }
            }
        }
    }

    /// The two buttons, and the order once there are candidates to order.
    private func pasteRow(ordered: Bool) -> some View {
        WrappingRow(alignment: .center, spacing: Theme.Spacing.xl, pushesTrailing: false) {
            HStack(alignment: .center, spacing: Theme.Spacing.m) {
                // The groups are then other players', so their opened lines close.
                Button(ScoutingPresentation.pasteButton) {
                    model.pasteCandidates()
                    navigation.closeScoutingLines()
                }
                    .buttonStyle(.main)
                    .fixedSize()
                Button(ScoutingPresentation.clearButton) {
                    model.clearCandidates()
                    navigation.closeScoutingLines()
                }
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

/// The groups in the engine's order: a part's title over its first group, each group's heading, then its candidates,
/// and under them the line that opens the group's others.
private struct CandidateGroups: View {
    let sheet: CandidatesSheet
    let model: AppModel
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
                    if let line = group.closedLine {
                        RestToggle(line: line, isOpen: navigation.scoutingRestOpen) {
                            navigation.scoutingRestOpen.toggle()
                        }
                    }
                    if group.showsRows(restOpen: navigation.scoutingRestOpen) {
                        rows(group.rows, inRest: group.isRest)
                    }
                    if let line = group.moreLine {
                        let isOpen = navigation.scoutingMoreOpen.contains(group.id)
                        RestToggle(line: line, isOpen: isOpen) {
                            navigation.toggleScoutingMore(group.id)
                        }
                        if isOpen {
                            rows(group.moreRows, inRest: group.isRest)
                        }
                    }
                }
            }
        }
    }

    /// Lazy, so a paste of several hundred rows lays out only those on screen.
    private func rows(_ rows: [ScoutingCandidateRow], inRest: Bool) -> some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                FaintRule()
                ScoutingCandidateRowView(row: row, inRest: inRest, isOpen: navigation.scoutingOpen.contains(row.id)) {
                    navigation.toggleScoutingRow(row.id)
                } hide: {
                    model.hideCandidate(row.id, for: navigation.scoutingTacticID)
                }
            }
        }
    }
}

/// The players the owner has hidden, under a heading of their own and closed behind a line saying how many: each by
/// name over what the paste says of him, with "Show again". Nothing at all when nobody pasted is hidden.
private struct HiddenCandidates: View {
    let sheet: CandidatesSheet
    let model: AppModel
    @Bindable var navigation: Navigation

    var body: some View {
        if let line = sheet.hiddenLine {
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                // Titled as a part is, so the list does not read as part of the rest above it.
                BoardHeading(ScoutingPresentation.hiddenHeading, size: Theme.TypeSize.boardTitle)
                    .padding(.top, Theme.Spacing.s)
                RestToggle(line: line, isOpen: navigation.scoutingHiddenOpen) {
                    navigation.scoutingHiddenOpen.toggle()
                }
                if navigation.scoutingHiddenOpen {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(sheet.hidden) { row in
                            FaintRule()
                            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                                CandidateIdentity(name: row.name, stamps: [], detailsText: row.detailsText)
                                    .accessibilityElement(children: .combine)
                                Button(ScoutingPresentation.showAgainButton) {
                                    model.showCandidateAgain(row.id, for: navigation.scoutingTacticID)
                                }
                                .buttonStyle(.secondary)
                                .fixedSize()
                                .accessibilityLabel(ScoutingPresentation.showAgainLabel(row.name))
                            }
                            .padding(.leading, Theme.Scouting.disclosureColumn)
                            .padding(.vertical, Theme.Spacing.m)
                        }
                    }
                }
            }
        }
    }
}

/// A pasted player's name with any stamp, over what the paste says of him.
private struct CandidateIdentity: View {
    let name: String
    let stamps: [StatusStamp]
    let detailsText: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                Text(name)
                    .font(Theme.Typeface.display(Theme.TypeSize.noteHeading, weight: .bold))
                    .foregroundStyle(Theme.Colour.ink)
                    .lineLimit(Theme.Scouting.nameLines)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(stamps, id: \.self) { StampView(stamp: $0).fixedSize() }
            }
            Text(detailsText)
                .font(Theme.Typeface.text(Theme.TypeSize.small))
                .foregroundStyle(Theme.Colour.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The line the rest part is closed behind: how many are in it, a click opening or closing it. The Offers screen's
/// earlier offers are closed behind one too.
struct RestToggle: View {
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

/// One candidate: his name with any stamp, what the paste says of him, and "Hide" at the trailing end; then his lines
/// and his cautions by label, and, while open, each other slot's lines together. A click on his name opens the row,
/// when he has more to show; "Hide" stands beside that button, never inside it.
private struct ScoutingCandidateRowView: View {
    let row: ScoutingCandidateRow
    let inRest: Bool
    let isOpen: Bool
    let toggle: () -> Void
    let hide: () -> Void

    var body: some View {
        let opens = row.opens(inRest: inRest)
        let lines = row.linesShown(inRest: inRest, isOpen: isOpen)
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
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
                Button(ScoutingPresentation.hideButton, action: hide)
                    .buttonStyle(.secondary)
                    .fixedSize()
                    .accessibilityLabel(ScoutingPresentation.hideLabel(row.name))
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
                if !lines.otherSlots.isEmpty {
                    Labelled(label: ScoutingPresentation.otherSlotsLabel) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            ForEach(lines.otherSlots) { slot in
                                SentenceLines(lines: slot.lines)
                            }
                        }
                    }
                }
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
            CandidateIdentity(name: row.name, stamps: row.stamps, detailsText: row.detailsText)
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
                SentenceLines(lines: lines)
            }
        }
    }
}

/// The engine's sentences, one under another.
private struct SentenceLines: View {
    let lines: [String]

    var body: some View {
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
