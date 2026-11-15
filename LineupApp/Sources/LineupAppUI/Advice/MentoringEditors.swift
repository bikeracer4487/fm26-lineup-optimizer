import LineupAppCore
import LineupEngine
import SwiftUI

/// What the Mentoring tab has open, as a sheet over the Training screen: a squad's hierarchy, a group's members, or the
/// arrows of three players. `close` closes it, after a save or on Cancel; `open` puts another in its place, as the
/// arrows of a group just added, or closes it when handed nil. The group editor's Save closes only through `open`, so
/// every caller gives it.
struct MentoringEditorSheet: View {
    let model: AppModel
    let editing: MentoringEditing
    let close: () -> Void
    let open: (MentoringEditing?) -> Void

    var body: some View {
        switch editing {
        case .hierarchy(let squad):
            HierarchyEditor(squad: squad, rows: model.dynamicsRows(for: squad), save: { entries in
                model.setDynamics(entries, for: squad)
                close()
            }, cancel: close)
        case .group(let draft):
            GroupEditor(model: model, draft: draft, done: close) { saved in
                open(model.arrowsDraft(afterSaving: saved).map(MentoringEditing.arrows))
            }
        case .arrows(let draft):
            ArrowsEditor(model: model, draft: draft, done: close)
        }
    }
}

/// A squad's hierarchy as the owner reads it in the game: one ruled row for each player, his name and age, a menu for
/// his level and a menu for his social group. The changes are held here until Save, which hands them all on at once;
/// Cancel drops them.
struct HierarchyEditor: View {
    let squad: Squad
    let save: ([PlayerID: PlayerDynamics]) -> Void
    let cancel: () -> Void
    @State private var rows: [DynamicsRow]

    init(squad: Squad, rows: [DynamicsRow], save: @escaping ([PlayerID: PlayerDynamics]) -> Void,
         cancel: @escaping () -> Void) {
        self.squad = squad
        self.save = save
        self.cancel = cancel
        _rows = State(initialValue: rows)
    }

    var body: some View {
        EditorPanel(title: MentoringPresentation.hierarchyEditorTitle(squad),
                    hint: MentoringPresentation.hierarchyEditorHint(squad),
                    note: MentoringPresentation.hierarchyEditorNote) {
            HStack(spacing: Theme.Spacing.m) {
                Spacer(minLength: 0)
                columnHeading(MentoringPresentation.levelLabel)
                columnHeading(MentoringPresentation.socialGroupLabel)
            }
        } rows: {
            ForEach($rows) { $row in
                HierarchyRow(row: $row)
                FaintRule()
            }
        } footer: {
            Spacer(minLength: 0)
            Button(MentoringPresentation.cancelTitle, role: .cancel, action: cancel)
                .buttonStyle(.secondary)
                .keyboardShortcut(.cancelAction)
            Button(MentoringPresentation.saveTitle) {
                save(Dictionary(rows.map { ($0.id, $0.dynamics) }, uniquingKeysWith: { first, _ in first }))
            }
            .buttonStyle(.primary)
            .keyboardShortcut(.defaultAction)
        }
    }

    private func columnHeading(_ text: String) -> some View {
        Text(text)
            .font(Theme.Typeface.text(Theme.TypeSize.caption, weight: .extraBold))
            .frame(width: Theme.Mentoring.editorMenuWidth, alignment: .leading)
    }
}

/// One player in the hierarchy editor: his name over his age, then the two menus.
private struct HierarchyRow: View {
    @Binding var row: DynamicsRow

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.m) {
            EditorName(name: row.name, detail: row.ageText)
            Spacer(minLength: 0)
            Picker(MentoringPresentation.levelLabel, selection: $row.dynamics.standing) {
                ForEach(MentoringPresentation.standingChoices, id: \.0) { choice in
                    Text(choice.1).tag(choice.0)
                }
            }
            .labelsHidden()
            .frame(width: Theme.Mentoring.editorMenuWidth, alignment: .leading)
            Picker(MentoringPresentation.socialGroupLabel, selection: $row.dynamics.socialGroup) {
                ForEach(MentoringPresentation.socialGroupChoices, id: \.0) { choice in
                    Text(choice.1).tag(choice.0)
                }
            }
            .labelsHidden()
            .frame(width: Theme.Mentoring.editorMenuWidth, alignment: .leading)
        }
        .font(Theme.Typeface.text())
        .padding(.vertical, Theme.Spacing.s)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(row.name)
    }
}

/// A group's three members chosen from the squad: one ruled row for each player, ticked when chosen. A row that cannot
/// be ticked says why. How many are chosen and why the group cannot be saved yet sit by Save, which waits until it can.
/// Save hands the draft saved to `saved`, which says what opens next.
struct GroupEditor: View {
    let model: AppModel
    let done: () -> Void
    let saved: (MentoringGroupDraft) -> Void
    @State private var draft: MentoringGroupDraft

    init(model: AppModel, draft: MentoringGroupDraft, done: @escaping () -> Void,
         saved: @escaping (MentoringGroupDraft) -> Void) {
        self.model = model
        self.done = done
        self.saved = saved
        _draft = State(initialValue: draft)
    }

    var body: some View {
        let problem = model.mentoringProblem(of: draft)
        EditorPanel(title: MentoringPresentation.groupEditorTitle(draft), hint: nil, note: nil) {
            EmptyView()
        } rows: {
            ForEach(model.memberChoices(for: draft)) { choice in
                MemberChoiceRow(choice: choice) { draft.toggle(choice.id) }
                FaintRule()
            }
        } footer: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(MentoringPresentation.chosenText(draft.members.count))
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                if let problem {
                    Text(problem)
                        .font(Theme.Typeface.text(Theme.TypeSize.small))
                        .foregroundStyle(Theme.Colour.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(MentoringPresentation.cancelTitle, role: .cancel, action: done)
                .buttonStyle(.secondary)
                .keyboardShortcut(.cancelAction)
            Button(MentoringPresentation.saveTitle) {
                model.saveGroup(draft)
                saved(draft)
            }
            .buttonStyle(.primary)
            .keyboardShortcut(.defaultAction)
            .disabled(problem != nil)
        }
    }
}

/// The arrows of three players as the game's Mentoring screen shows them: once three are chosen, a row for each of
/// their six arrows with a menu of its strength, and under them, while any is not read, a button setting those to None,
/// above the heavy rule; under it the squad's players to choose from, as the group editor offers them. How many are
/// chosen and why the arrows cannot be saved yet sit by Save, which waits until they can.
struct ArrowsEditor: View {
    let model: AppModel
    let done: () -> Void
    @State private var draft: ArrowsDraft

    init(model: AppModel, draft: ArrowsDraft, done: @escaping () -> Void) {
        self.model = model
        self.done = done
        _draft = State(initialValue: draft)
    }

    var body: some View {
        let problem = model.arrowsProblem(of: draft)
        EditorPanel(title: MentoringPresentation.arrowsEditorTitle(draft.squad),
                    hint: MentoringPresentation.arrowsEditorHint, note: nil) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(model.arrowRows(for: draft)) { row in
                    ArrowMenuRow(row: row, strength: Binding(get: { draft.strengths[row.id] },
                                                             set: { draft.strengths[row.id] = $0 }))
                }
                if let setTheRest = MentoringPresentation.setTheRestToNoneTitle(draft) {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        Button(setTheRest) { draft = MentoringPresentation.settingTheRestToNone(draft) }
                            .buttonStyle(.secondary)
                    }
                    .padding(.vertical, Theme.Spacing.xs)
                }
            }
        } rows: {
            ForEach(model.arrowChoices(for: draft)) { choice in
                MemberChoiceRow(choice: choice) { draft = model.arrowsDraft(draft, toggling: choice.id) }
                FaintRule()
            }
        } footer: {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(MentoringPresentation.chosenText(draft.members.count))
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                if let problem {
                    Text(problem)
                        .font(Theme.Typeface.text(Theme.TypeSize.small))
                        .foregroundStyle(Theme.Colour.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(MentoringPresentation.cancelTitle, role: .cancel, action: done)
                .buttonStyle(.secondary)
                .keyboardShortcut(.cancelAction)
            Button(MentoringPresentation.saveTitle) {
                model.saveArrows(draft)
                done()
            }
            .buttonStyle(.primary)
            .keyboardShortcut(.defaultAction)
            .disabled(problem != nil)
        }
    }
}

/// One arrow in the arrows sheet: who to whom in the column the cards give an arrow's names, then the menu of its
/// strength, Not read first.
private struct ArrowMenuRow: View {
    let row: ArrowRow
    @Binding var strength: ArrowStrength?

    var body: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.m) {
            Text(row.titleText)
                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                .foregroundStyle(Theme.Colour.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: Theme.Mentoring.arrowTitleWidth, alignment: .leading)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            Picker(row.spokenTitle, selection: $strength) {
                ForEach(MentoringPresentation.strengthChoices, id: \.0) { choice in
                    Text(choice.1).tag(choice.0)
                }
            }
            .labelsHidden()
            .frame(width: Theme.Mentoring.editorMenuWidth, alignment: .leading)
        }
        .font(Theme.Typeface.text())
        .padding(.vertical, Theme.Spacing.xs)
    }
}

/// One player the group editor or the arrows sheet offers: the box, his name over his age and level, and why he cannot
/// be ticked when he cannot. A row that cannot be ticked is not a button, so its words are not dimmed as a disabled
/// control's.
private struct MemberChoiceRow: View {
    let choice: MemberChoice
    let toggle: () -> Void

    var body: some View {
        if choice.canToggle {
            Button(action: toggle) { content }
                .buttonStyle(.plain)
                .accessibilityAddTraits(choice.isChosen ? .isSelected : [])
        } else {
            content
        }
    }

    private var content: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.m) {
            TickBox(isTicked: choice.isChosen, isEnabled: choice.canToggle)
            EditorName(name: choice.name, detail: choice.detailText)
            Spacer(minLength: Theme.Spacing.m)
            if let unavailable = choice.unavailableText {
                Text(unavailable)
                    .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .semibold))
                    .foregroundStyle(Theme.Colour.mutedInk)
                    .fixedSize()
            }
        }
        .padding(.vertical, Theme.Spacing.s)
        .contentShape(Rectangle())
    }
}

/// The box before a player in the group editor and the arrows sheet: an ink outline, filled in marker blue with a tick
/// when he is chosen; faint when it cannot be ticked.
private struct TickBox: View {
    let isTicked: Bool
    let isEnabled: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Mentoring.tickBoxCornerRadius)
        ZStack {
            if isTicked {
                shape.fill(Theme.Colour.markerBlue)
                Image(systemName: "checkmark")
                    .font(Theme.Typeface.text(Theme.TypeSize.caption, weight: .extraBold))
                    .foregroundStyle(Theme.Colour.onMarker)
            } else {
                shape.strokeBorder(Theme.Colour.ink, lineWidth: Theme.Card.lineWidth)
            }
        }
        .frame(width: Theme.Mentoring.tickBox, height: Theme.Mentoring.tickBox)
        .opacity(isEnabled ? 1 : Theme.Button.disabledOpacity)
        .accessibilityHidden(true)
    }
}

/// A player's name in bold over a muted line about him, in the column the editors' rows share.
private struct EditorName: View {
    let name: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(name)
                .font(Theme.Typeface.text(Theme.TypeSize.body, weight: .bold))
                .foregroundStyle(Theme.Colour.ink)
                .lineLimit(Theme.Mentoring.nameLines)
                .fixedSize(horizontal: false, vertical: true)
            if let detail {
                Text(detail)
                    .font(Theme.Typeface.text(Theme.TypeSize.small))
                    .foregroundStyle(Theme.Colour.mutedInk)
            }
        }
        .frame(width: Theme.Mentoring.editorNameWidth, alignment: .leading)
    }
}

/// An editor's frame: its title, its hint and a second muted line under it, the headings over its rows, a heavy rule,
/// the rows scrolling, and the row of what sits by its buttons and the buttons at the foot, on the board's white at the
/// editors' size.
private struct EditorPanel<Headings: View, Rows: View, Footer: View>: View {
    let title: String
    let hint: String?
    let note: String?
    @ViewBuilder let headings: () -> Headings
    @ViewBuilder let rows: () -> Rows
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                BoardHeading(title, size: Theme.TypeSize.boardTitle)
                if let hint {
                    Text(hint)
                        .font(Theme.Typeface.text(Theme.TypeSize.body))
                        .foregroundStyle(Theme.Colour.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let note {
                    Text(note)
                        .font(Theme.Typeface.text(Theme.TypeSize.body))
                        .foregroundStyle(Theme.Colour.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                headings()
                HeavyRule()
            }
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 0) {
                    rows()
                }
            }
            HStack(alignment: .center, spacing: Theme.Spacing.s) {
                footer()
            }
        }
        .font(Theme.Typeface.text())
        .foregroundStyle(Theme.Colour.ink)
        .padding(Theme.Card.padding + Theme.Spacing.xs)
        .frame(width: Theme.Mentoring.editorSize.width, height: Theme.Mentoring.editorSize.height, alignment: .topLeading)
        .background(Theme.Colour.board)
        .boardAppearance()
    }
}
