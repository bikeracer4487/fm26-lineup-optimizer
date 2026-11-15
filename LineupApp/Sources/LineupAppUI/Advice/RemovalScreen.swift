import LineupAppCore
import LineupEngine
import SwiftUI

/// How the Player Removal screen opens: as the owner left it, or with every row open.
public struct RemovalStart: Sendable {
    public var allOpen: Bool

    public init(allOpen: Bool = false) {
        self.allOpen = allOpen
    }
}

/// Who to sell, loan out, release or keep, the young players and the loans to the club: a line saying what the advice
/// is judged against, the two figures, the filter, then the table, highest score first, and the two parts under it.
/// Everything under the heading scrolls down, the table's headings staying in view.
public struct RemovalScreen: View {
    let model: AppModel
    @Bindable var navigation: Navigation

    public init(model: AppModel, navigation: Navigation) {
        self.model = model
        self.navigation = navigation
    }

    public var body: some View {
        AdviceGate(screen: .removal, state: model.adviceState, importLine: model.adviceImportLine) { report in
            RemovalBody(sheet: model.removalSheet(report), navigation: navigation) { mark, player in
                model.setMark(mark, for: player)
            }
        }
    }
}

private struct RemovalBody: View {
    let sheet: RemovalSheet
    @Bindable var navigation: Navigation
    /// Marks a player to sell or to loan out, or with nil takes his mark off.
    let setMark: (SaleMark?, PlayerID) -> Void
    @State private var wide = true

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                top
                if let empty = sheet.emptyText {
                    MutedLine(text: empty)
                } else {
                    Section {
                        let rows = sheet.rows(navigation.removalFilter)
                        if let none = sheet.filteredEmptyText(navigation.removalFilter) {
                            MutedLine(text: none)
                                .padding(.vertical, Theme.Spacing.m)
                        }
                        ForEach(rows) { row in
                            RemovalRowView(row: row, wide: wide, isOpen: navigation.removalDisclosure.isOpen(row),
                                           setMark: { setMark($0, row.id) }) {
                                navigation.removalDisclosure.toggle(row)
                            }
                            FaintRule()
                        }
                    } header: {
                        RemovalHeadings(wide: wide)
                    }
                }
                YoungPlayers(sheet: sheet)
                    .padding(.top, Theme.Removal.partGap)
                LoansToTheClub(sheet: sheet)
                    .padding(.top, Theme.Removal.partGap)
                    .padding(.bottom, Theme.Spacing.l)
            }
        }
        .onGeometryChange(for: Bool.self) { $0.size.width >= Theme.Removal.wideTableWidth } action: { wide = $0 }
        // A choice made at a level the player is no longer at is dropped as soon as the rows show the change.
        .onChange(of: sheet.rows, initial: true) { navigation.removalDisclosure.prune(to: sheet.rows) }
    }

    /// The line, the figures and the filter.
    private var top: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                MutedLine(text: RemovalPresentation.explanation)
                MutedLine(text: RemovalPresentation.marksNote)
            }
            HStack(alignment: .top, spacing: Theme.Spacing.m) {
                ForEach(sheet.figures) { FigureCard(label: $0.label, figure: $0.figure) }
            }
            if sheet.emptyText == nil {
                BoardTabs(choices: RemovalFilter.allCases.map { ($0, sheet.filterTitle($0)) },
                          selection: $navigation.removalFilter)
            }
        }
        .padding(.bottom, Theme.Spacing.m)
    }
}

/// A muted sentence that wraps.
private struct MutedLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Typeface.text(Theme.TypeSize.body))
            .foregroundStyle(Theme.Colour.mutedInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The table's headings over a heavy rule, on the board's white so rows scroll out of sight beneath. On a narrow board
/// there is no costs column: the sentence is under each name.
private struct RemovalHeadings: View {
    let wide: Bool

    var body: some View {
        VStack(spacing: 0) {
            RemovalColumns(wide: wide) { column in
                Text(column.title)
                    .font(Theme.Typeface.text(Theme.TypeSize.caption, weight: .extraBold))
                    .foregroundStyle(Theme.Colour.ink)
                    .lineLimit(1)
            } disclosure: {
                Color.clear
            }
            .frame(height: Theme.Table.headingHeight)
            HeavyRule()
        }
        .background(Theme.Colour.board)
        .accessibilityElement(children: .combine)
    }
}

/// The table's columns in their widths, each cell drawn by `cell`; the disclosure mark's room first.
private struct RemovalColumns<Cell: View, Disclosure: View>: View {
    let wide: Bool
    var alignment: VerticalAlignment = .center
    @ViewBuilder let cell: (RemovalColumn) -> Cell
    @ViewBuilder let disclosure: () -> Disclosure

    var body: some View {
        HStack(alignment: alignment, spacing: 0) {
            disclosure()
                .frame(width: Theme.Removal.disclosureColumn, alignment: .leading)
            cell(.level).frame(width: Theme.Removal.stampColumn, alignment: .leading)
            cell(.action).frame(width: Theme.Removal.actionColumn, alignment: .leading)
            if wide {
                cell(.name).frame(width: Theme.Removal.nameColumn, alignment: .leading)
            } else {
                cell(.name).frame(maxWidth: .infinity, alignment: .leading)
            }
            cell(.squad).frame(width: Theme.Removal.squadColumn, alignment: .leading)
            cell(.age).frame(width: Theme.Removal.ageColumn, alignment: .trailing)
            cell(.score).frame(width: Theme.Removal.scoreColumn, alignment: .trailing)
            if wide {
                cell(.costs)
                    .padding(.leading, Theme.Table.columnLead)
                    .frame(minWidth: Theme.Removal.costsMinimum, maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

/// One player: the row, a click on which opens or closes it, and while open his reasons under it.
private struct RemovalRowView: View {
    let row: RemovalRow
    let wide: Bool
    let isOpen: Bool
    let setMark: (SaleMark?) -> Void
    let toggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                RemovalColumns(wide: wide, alignment: .firstTextBaseline) { column in
                    cell(column)
                } disclosure: {
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .bold))
                        .foregroundStyle(Theme.Colour.mutedInk)
                }
                .padding(.vertical, Theme.Spacing.s)
                .frame(minHeight: Theme.Table.rowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(RemovalPresentation.clickHelp(isOpen))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(row.spokenText)
            .accessibilityValue(RemovalPresentation.openText(isOpen))
            .accessibilityAddTraits(.isButton)
            if isOpen {
                RemovalDetail(row: row, setMark: setMark)
                    .padding(.leading, Theme.Removal.disclosureColumn + Theme.Removal.stampColumn)
                    .padding(.bottom, Theme.Spacing.m)
            }
        }
    }

    @ViewBuilder private func cell(_ column: RemovalColumn) -> some View {
        switch column {
        case .level:
            StampView(stamp: row.stamp)
        case .action:
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(row.actionText)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .semibold))
                    .foregroundStyle(Theme.Colour.ink)
                if let mark = row.markText {
                    Text(mark)
                        .font(Theme.Typeface.text(Theme.TypeSize.small))
                        .foregroundStyle(Theme.Colour.mutedInk)
                }
            }
            .padding(.trailing, Theme.Spacing.s)
        case .name:
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(row.name)
                    .font(Theme.Typeface.display(Theme.TypeSize.noteHeading, weight: .bold))
                    .foregroundStyle(Theme.Colour.ink)
                    .lineLimit(Theme.Removal.nameLines)
                    .fixedSize(horizontal: false, vertical: true)
                if !wide {
                    costs
                }
            }
            .padding(.trailing, Theme.Spacing.s)
        case .squad:
            Text(row.squadText ?? "")
                .font(Theme.Typeface.text())
                .foregroundStyle(Theme.Colour.mutedInk)
        case .age:
            Text(row.ageText ?? "")
                .font(Theme.Typeface.text())
                .foregroundStyle(Theme.Colour.ink)
        case .score:
            Text(row.scoreText)
                .font(Theme.Typeface.text(Theme.TypeSize.button, weight: .extraBold))
                .foregroundStyle(Theme.Colour.ink)
        case .costs:
            costs
        }
    }

    private var costs: some View {
        Text(row.costsText)
            .font(Theme.Typeface.text(Theme.TypeSize.small))
            .foregroundStyle(Theme.Colour.mutedInk)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// An open row's reasons with their points, the sentence for why that action, the evidence note, and the control that
/// marks him to sell or to loan out, or, for a player on a youth contract, the engine's sentence saying why he cannot be
/// marked.
private struct RemovalDetail: View {
    let row: RemovalRow
    let setMark: (SaleMark?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            PointedReasons(reasons: row.reasons)
            Text(row.whyText)
                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .semibold))
                .foregroundStyle(Theme.Colour.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Theme.Spacing.xs)
                .padding(.leading, Theme.Removal.pointsColumn + Theme.Spacing.m)
            if let note = row.noteText {
                Text(note)
                    .font(Theme.Typeface.text(Theme.TypeSize.small))
                    .foregroundStyle(Theme.Colour.mutedInk)
                    .padding(.leading, Theme.Removal.pointsColumn + Theme.Spacing.m)
            }
            Group {
                if let refusal = row.markRefusalText {
                    Text(refusal)
                        .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .semibold))
                        .foregroundStyle(Theme.Colour.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    HStack(alignment: .center, spacing: Theme.Spacing.m) {
                        Text(RemovalPresentation.markLabel)
                            .font(Theme.Typeface.text(Theme.TypeSize.small, weight: .semibold))
                            .foregroundStyle(Theme.Colour.mutedInk)
                        BoardTabs(choices: RemovalPresentation.markChoices.map { ($0.mark, $0.title) },
                                  selection: Binding(get: { row.mark }, set: { setMark($0) }))
                    }
                }
            }
            .padding(.top, Theme.Spacing.s)
            .padding(.leading, Theme.Removal.pointsColumn + Theme.Spacing.m)
        }
        .textSelection(.enabled)
    }
}

/// Reasons, each on its own line after its points: red against him, green for him, muted for none, right-aligned so
/// the figures line up.
private struct PointedReasons: View {
    let reasons: [PointedReason]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            // Keyed by place, so two identical reasons are both shown.
            ForEach(Array(reasons.enumerated()), id: \.offset) { _, reason in
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.m) {
                    Text(reason.pointsText)
                        .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .extraBold))
                        .foregroundStyle(Theme.Colour.points(reason.tone))
                        .frame(width: Theme.Removal.pointsColumn, alignment: .trailing)
                    Text(reason.text)
                        .font(Theme.Typeface.text())
                        .foregroundStyle(Theme.Colour.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// "Young players": the line saying who is listed and how far to trust the figures, then a block for each young player,
/// separated by faint rules, or the line saying there is nobody of that age.
private struct YoungPlayers: View {
    let sheet: RemovalSheet

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                BoardHeading(RemovalPresentation.youngHeading, size: Theme.TypeSize.boardTitle)
                MutedLine(text: RemovalPresentation.youngExplanation)
            }
            if let none = sheet.youngEmptyText {
                MutedLine(text: none)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(sheet.young) { row in
                    FaintRule()
                    YoungRowView(row: row)
                }
            }
        }
    }
}

/// One young player: who he is in the name's face with the action stamped at the right, then the engine's lines on how
/// far he could grow, where he stands, whether he gets matches here and why that action.
private struct YoungRowView: View {
    let row: YoungRow

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Removal.youngActionGap) {
                Text(row.titleText)
                    .font(Theme.Typeface.display(Theme.TypeSize.noteHeading, weight: .bold))
                    .foregroundStyle(Theme.Colour.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                StampView(stamp: row.stamp)
                    .fixedSize()
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                // Keyed by place, so two identical lines are both shown.
                ForEach(Array(row.lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(Theme.Typeface.text())
                        .foregroundStyle(Theme.Colour.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: Theme.Removal.youngLinesWidth, alignment: .leading)
            .padding(.leading, Theme.Removal.youngLinesIndent)
        }
        .padding(.vertical, Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.spokenText)
    }
}

/// "Loans to the club": a block for each loanee, separated by faint rules, or the line saying nobody is on loan here.
private struct LoansToTheClub: View {
    let sheet: RemovalSheet

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            BoardHeading(RemovalPresentation.loansHeading, size: Theme.TypeSize.boardTitle)
            if let none = sheet.loansEmptyText {
                MutedLine(text: none)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(sheet.loans) { block in
                    FaintRule()
                    LoanBlockView(block: block)
                }
            }
        }
    }
}

/// One loanee: the verdict's stamp, his name and score, then his reasons with their points in line with his name.
private struct LoanBlockView: View {
    let block: LoanBlock

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                StampView(stamp: block.stamp)
                    .frame(width: Theme.Removal.verdictColumn, alignment: .leading)
                Text(block.name)
                    .font(Theme.Typeface.display(Theme.TypeSize.noteHeading, weight: .bold))
                    .foregroundStyle(Theme.Colour.ink)
                    .lineLimit(Theme.Removal.nameLines)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.trailing, Theme.Spacing.l)
                Text(RemovalPresentation.scoreLabel)
                    .font(Theme.Typeface.text(Theme.TypeSize.small))
                    .foregroundStyle(Theme.Colour.mutedInk)
                    .padding(.trailing, Theme.Spacing.xs)
                Text(block.scoreText)
                    .font(Theme.Typeface.text(Theme.TypeSize.button, weight: .extraBold))
                    .foregroundStyle(Theme.Colour.ink)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                PointedReasons(reasons: block.reasons)
                if let note = block.noteText {
                    Text(note)
                        .font(Theme.Typeface.text(Theme.TypeSize.small))
                        .foregroundStyle(Theme.Colour.mutedInk)
                        .padding(.leading, Theme.Removal.pointsColumn + Theme.Spacing.m)
                }
            }
            .padding(.leading, Theme.Removal.verdictColumn - Theme.Removal.pointsColumn - Theme.Spacing.m)
        }
        .padding(.vertical, Theme.Spacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(block.spokenText)
    }
}
