import LineupAppCore
import LineupEngine
import SwiftUI

/// Where the Contracts screen starts: whether the players not recommended for renewal and those not being renewed are
/// open. The app starts with the default; the pictures choose.
public struct ContractsStart: Sendable {
    public var notRecommendedOpen: Bool
    public var dismissedOpen: Bool

    public init(notRecommendedOpen: Bool = false, dismissedOpen: Bool = false) {
        self.notRecommendedOpen = notRecommendedOpen
        self.dismissedOpen = dismissedOpen
    }
}

/// The players worth renewing whose contracts are running down: the engine's intro; the club's three wage figures, each
/// typed straight into the model; then the list, a row for each player, the most worth first, with "Not renewing" at the
/// trailing end of his name's line ("Follow the advice" on one listed at the owner's choice); the players not
/// recommended for renewal, closed behind a line, each with his reasons and "Renew anyway"; the players not being
/// renewed, closed behind a line, each with "Show again"; and how far to trust it all. It stands behind the same gate as
/// Player Removal, and everything under the heading scrolls.
public struct ContractsScreen: View {
    let model: AppModel
    @Bindable var navigation: Navigation

    public init(model: AppModel, navigation: Navigation) {
        self.model = model
        self.navigation = navigation
    }

    public var body: some View {
        // Worked out on every read, so read once a pass and handed down.
        switch model.contractsSheet {
        case .notReady(let state):
            AdviceGate(screen: .contracts, state: state, importLine: model.adviceImportLine) { _ in EmptyView() }
        case .failed(let problems):
            AdviceGate(screen: .contracts, state: model.adviceState, importLine: model.adviceImportLine) { _ in
                ContractsFailed(problems: problems)
            }
        case .ready(let sheet):
            AdviceGate(screen: .contracts, state: model.adviceState, importLine: model.adviceImportLine) { _ in
                ContractsBody(sheet: sheet, model: model, navigation: navigation)
            }
        }
    }
}

/// The engine's sentences for why the list cannot be worked out, under a muted lead.
private struct ContractsFailed: View {
    let problems: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Text(ContractsPresentation.failedLead)
                .font(Theme.Typeface.text(Theme.TypeSize.noteHeading))
                .foregroundStyle(Theme.Colour.mutedInk)
            ForEach(Array(problems.enumerated()), id: \.offset) { _, problem in CautionLine(problem) }
        }
        .frame(maxWidth: Theme.Layout.readingWidth, alignment: .leading)
    }
}

private struct ContractsBody: View {
    let sheet: ContractsSheet
    let model: AppModel
    @Bindable var navigation: Navigation

    var body: some View {
        ScrollView(.vertical) {
            // Lazy, so a long list lays out only what is on screen.
            LazyVStack(alignment: .leading, spacing: Theme.Contracts.partGap) {
                VStack(alignment: .leading, spacing: Theme.Spacing.m) {
                    MutedLines(lines: [sheet.intro])
                    WageLimitFields(rows: sheet.limitRows) { field, text in model.setWageLimit(field, text: text) }
                    if let entered = sheet.limitsEnteredText {
                        MutedLines(lines: [entered], size: Theme.TypeSize.small)
                    }
                }
                if let empty = sheet.emptyLine {
                    MutedLines(lines: [empty])
                }
                ContractsList(rows: sheet.rows, model: model)
                if let line = sheet.notRecommendedLine {
                    NotRecommended(line: line, rows: sheet.notRecommended, model: model, navigation: navigation)
                }
                if let line = sheet.dismissedLine {
                    NotRenewing(line: line, rows: sheet.dismissed, model: model, navigation: navigation)
                }
                MutedLines(lines: sheet.evidenceNote, size: Theme.TypeSize.small)
            }
            .frame(maxWidth: Theme.Contracts.columnMaximumWidth, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, Theme.Spacing.l)
        }
    }
}

/// The club's three wage figures, each label before its field, so the fields line up: all
/// three on a row when they fit across, one under another when not.
private struct WageLimitFields: View {
    let rows: [WageLimitRow]
    let set: @MainActor @Sendable (WageLimitField, String) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            grid(perRow: rows.count)
            grid(perRow: 1)
        }
    }

    private func grid(perRow: Int) -> some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: Theme.Spacing.s,
             verticalSpacing: Theme.Spacing.s) {
            ForEach(Array(stride(from: 0, to: rows.count, by: perRow)), id: \.self) { start in
                GridRow {
                    ForEach(rows[start..<min(start + perRow, rows.count)], id: \.field) { row in
                        FieldLabel(text: row.label, small: true)
                        AmountField(label: row.label, text: row.text) { set(row.field, $0) }
                            .padding(.trailing, Theme.Contracts.figureGap)
                    }
                }
            }
        }
        .fixedSize()
    }
}

/// The list: a row for each player, separated by faint rules.
private struct ContractsList: View {
    let rows: [ContractRow]
    let model: AppModel

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(rows) { row in
                FaintRule()
                ContractRowView(row: row, model: model)
            }
        }
    }
}

/// One player: his name over his facts, with "Not renewing" at the trailing end, beside them and never inside a button,
/// or "Follow the advice" on a player listed at the owner's choice; then where he stands, when other clubs can approach
/// him (a caution once they can), on a player listed at the owner's choice the engine's caution saying so with the
/// reasons the tool gave against it, his worth against the first eleven's standard, the wage range for his tier, the
/// agent's figure typed straight into the model with the day it was entered, and what the figure says against the range,
/// the caution first when it is above the most the club can offer.
private struct ContractRowView: View {
    let row: ContractRow
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                ContractIdentity(name: row.name, detailsText: row.detailsText)
                if row.wantedLine == nil {
                    Button(ContractsPresentation.notRenewingButton) { model.dismissContract(row.id) }
                        .buttonStyle(.secondary)
                        .fixedSize()
                        .accessibilityLabel(ContractsPresentation.notRenewingLabel(row.name))
                } else {
                    Button(ContractsPresentation.followAdviceButton) { model.followAdvice(row.id) }
                        .buttonStyle(.secondary)
                        .fixedSize()
                        .accessibilityLabel(ContractsPresentation.followAdviceLabel(row.name))
                }
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                InkLines(lines: [row.standingLine])
                if let timing = row.timingLine {
                    TimingLine(text: timing, isCaution: row.timingIsCaution)
                }
                if let wanted = row.wantedLine {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        CautionLine(wanted)
                        ContractReasons(row: row)
                    }
                }
                if let worth = row.worthLine {
                    InkLines(lines: [worth])
                }
                InkLines(lines: row.guideLines)
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                    FieldLabel(text: row.figureLabel)
                    AmountField(label: row.figureLabel, text: row.figureText) {
                        model.setAgentFigure(text: $0, for: row.id)
                    }
                    if let entered = row.figureEnteredText {
                        MutedLines(lines: [entered], size: Theme.TypeSize.small)
                    }
                }
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    if let caution = row.cautionVerdictLine {
                        CautionLine(caution)
                    }
                    InkLines(lines: row.verdictLines)
                }
            }
            .padding(.leading, Theme.Contracts.rowIndent)
        }
        .padding(.vertical, Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// When other clubs can approach him: a caution once they can, else a plain sentence in ink.
private struct TimingLine: View {
    let text: String
    let isCaution: Bool

    var body: some View {
        if isCaution {
            CautionLine(text)
        } else {
            InkLines(lines: [text])
        }
    }
}

/// The reasons the tool does not recommend renewing him, in ink, and under them the sentence that says to sign a
/// replacement first, as a caution.
private struct ContractReasons: View {
    let row: ContractRow

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            InkLines(lines: row.reasonLines)
            if let replaceFirst = row.replaceFirstText {
                CautionLine(replaceFirst)
            }
        }
    }
}

/// The players the tool does not recommend renewing, under a heading of their own and closed behind the line saying how
/// many: each by name over his facts, with "Renew anyway", then where he stands and the reasons.
private struct NotRecommended: View {
    let line: String
    let rows: [ContractRow]
    let model: AppModel
    @Bindable var navigation: Navigation

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            BoardHeading(ContractsPresentation.notRecommendedHeading, size: Theme.TypeSize.boardTitle)
            RestToggle(line: line, isOpen: navigation.contractsNotRecommendedOpen) {
                navigation.contractsNotRecommendedOpen.toggle()
            }
            if navigation.contractsNotRecommendedOpen {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        FaintRule()
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                                ContractIdentity(name: row.name, detailsText: row.detailsText)
                                Button(ContractsPresentation.renewAnywayButton) { model.renewAnyway(row.id) }
                                    .buttonStyle(.secondary)
                                    .fixedSize()
                                    .accessibilityLabel(ContractsPresentation.renewAnywayLabel(row.name))
                            }
                            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                                InkLines(lines: [row.standingLine])
                                ContractReasons(row: row)
                            }
                            .padding(.leading, Theme.Contracts.rowIndent)
                        }
                        .padding(.vertical, Theme.Spacing.m)
                    }
                }
                .padding(.leading, Theme.Scouting.disclosureColumn)
            }
        }
    }
}

/// A player's name over his facts, in muted ink.
private struct ContractIdentity: View {
    let name: String
    let detailsText: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(name)
                .font(Theme.Typeface.display(Theme.TypeSize.noteHeading, weight: .bold))
                .foregroundStyle(Theme.Colour.ink)
                .lineLimit(Theme.Contracts.nameLines)
                .fixedSize(horizontal: false, vertical: true)
            Text(detailsText)
                .font(Theme.Typeface.text(Theme.TypeSize.small))
                .foregroundStyle(Theme.Colour.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The players not being renewed, under a heading of their own and closed behind the line saying how many: each by name
/// over his facts and where he stands, with "Show again".
private struct NotRenewing: View {
    let line: String
    let rows: [ContractRow]
    let model: AppModel
    @Bindable var navigation: Navigation

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            BoardHeading(ContractsPresentation.notRenewingHeading, size: Theme.TypeSize.boardTitle)
            RestToggle(line: line, isOpen: navigation.contractsDismissedOpen) {
                navigation.contractsDismissedOpen.toggle()
            }
            if navigation.contractsDismissedOpen {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        FaintRule()
                        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                            HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                                ContractIdentity(name: row.name, detailsText: row.detailsText)
                                Button(ContractsPresentation.showAgainButton) { model.showContractAgain(row.id) }
                                    .buttonStyle(.secondary)
                                    .fixedSize()
                                    .accessibilityLabel(ContractsPresentation.showAgainLabel(row.name))
                            }
                            InkLines(lines: [row.standingLine])
                                .padding(.leading, Theme.Contracts.rowIndent)
                        }
                        .padding(.vertical, Theme.Spacing.m)
                    }
                }
                .padding(.leading, Theme.Scouting.disclosureColumn)
            }
        }
    }
}
